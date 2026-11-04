---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local IsPreviewing, PreviewDuration = CDM.IsPreviewingLayer, CDM.PreviewDuration
local PREVIEW_LENGTH = CDM.PREVIEW_LENGTH
local L = NRSKNUI.Libs.AL

local pairs, ipairs = pairs, ipairs
local type = type
local select = select
local hooksecurefunc = hooksecurefunc
local GetTime = GetTime
local format = string.format
local CreateFrame = CreateFrame

local IsSpellOverlayed = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed
local GetSpellCooldownDuration = C_Spell and C_Spell.GetSpellCooldownDuration
local GetSpellChargeDuration = C_Spell and C_Spell.GetSpellChargeDuration
local EnableSpellRangeCheck = C_Spell and C_Spell.EnableSpellRangeCheck
local CreateDuration = C_DurationUtil and C_DurationUtil.CreateDuration
local IsSpellKnown = C_SpellBook and C_SpellBook.IsSpellKnown
local GetSpellCooldown = C_Spell and C_Spell.GetSpellCooldown
local GetOverrideSpell = C_Spell and C_Spell.GetOverrideSpell
local GetSpellCharges = C_Spell and C_Spell.GetSpellCharges
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture
local IsSpellInRange = C_Spell and C_Spell.IsSpellInRange
local IsSpellUsable = C_Spell and C_Spell.IsSpellUsable

local GLOBAL_RECOVERY_CATEGORY = Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY
local GCD_SPELL = 61304

local inCooldownEvent = false
local gcdEnds = 0 -- steps each time OnGCDEnd sees the GCD end
local gcdPassTime
local changedSpell, changedBase -- the spell the running SPELL_UPDATE_COOLDOWN names
local gcdAtEvent = false
local namedAt = {} ---@type table<number, number> spellID -> when a SPELL_UPDATE_COOLDOWN last named it
local recheck = {} ---@type table<CDMLayer, true> layers read mid-GCD outside the cooldown event
local rangeState = {} ---@type table<number, boolean> spellID -> in range, for spells a condition range-checks

--[[
Spell triggers: cooldown, charges, usability, range and proc glow.
The game only tells a GCD from a real cooldown inside SPELL_UPDATE_COOLDOWN, so much of this keeps that apart.
]]

-- GCD --

-- No event fires when the GCD ends, so the layers last read on a guess are re-read then.
local gcdEndFrame ---@type Frame

---@param frame Frame
local function OnGCDEnd(frame)
    if GetSpellCooldown(GCD_SPELL).isActive then
        return frame:NUIScheduleUpdate()
    end

    gcdEnds = gcdEnds + 1
    for layer in pairs(recheck) do
        recheck[layer] = nil
        CDM:UpdateLayer(layer)
    end
end

-- Blizzard's charge verdict --

-- Blizzard's own viewer tells a charge left from none with currentCharges, secret to us in combat; it leaves the
-- answer on its icon as a plain wasSetFromCharges (CooldownViewer.lua CheckCacheCooldownValuesFromCharges, live).
-- Shadow Dance needs it: through the Dance buff a charge left and none read exactly alike to us.
local CHARGE_VIEWERS = { 'EssentialCooldownViewer', 'UtilityCooldownViewer' }
local hookedItems = {} ---@type table<table, true>
local chargeLayers = {} ---@type table<CDMLayer, true> layers reading a viewer item's verdict

---@param item table
local function OnItemCached(item)
    for layer in pairs(chargeLayers) do
        if layer.chargeItem == item and item.wasSetFromCharges ~= layer.fromCharges then
            CDM:UpdateLayer(layer)
        end
    end
end

---The viewer icon Blizzard draws for this layer's spell, nil when the spell isn't in its Cooldown Manager.
---@param layer CDMLayer
---@return table? item
local function ChargeItem(layer)
    local cooldownID = CDM.Catalogue:FindBySpell(layer.baseSpellID, 'cooldown') or CDM.Catalogue:FindBySpell(layer.spellID, 'cooldown')
    local item = layer.chargeItem
    local id = item and item.cooldownID
    -- a pooled frame can be handed to another entry, so the cached one is checked first
    if item and id ~= nil and not NRSKNUI:IsSecretValue(id) and id == cooldownID then
        return item
    end

    layer.chargeItem = nil
    if not cooldownID then return nil end

    for _, name in ipairs(CHARGE_VIEWERS) do
        local pool = _G[name] and _G[name].itemFramePool
        if pool and pool.EnumerateActive then
            for child in pool:EnumerateActive() do
                local childID = child.cooldownID
                if childID ~= nil and not NRSKNUI:IsSecretValue(childID) and childID == cooldownID then
                    if not hookedItems[child] and child.CacheCooldownValues then
                        hookedItems[child] = true
                        hooksecurefunc(child, 'CacheCooldownValues', OnItemCached)
                    end
                    layer.chargeItem = child
                    return child
                end
            end
        end
    end
end

---Blizzard's word on whether a charge is left: true while one is, false otherwise, nil when it has none to give.
---@param layer CDMLayer
---@return boolean?
local function ChargesLeft(layer)
    chargeLayers[layer] = true
    local item = ChargeItem(layer)
    local fromCharges = item and item.wasSetFromCharges
    layer.fromCharges = fromCharges
    if type(fromCharges) ~= 'boolean' or NRSKNUI:IsSecretValue(fromCharges) then return nil end

    return fromCharges
end

---A zero duration: texts keep counting the last one they were given, so "ready" is handed one explicitly.
---@param layer CDMLayer
---@return LuaDurationObject
local function ReadyDuration(layer)
    if not layer.readyDuration then
        layer.readyDuration = CreateDuration()
        layer.readyDuration:SetTimeFromStart(0, 0)
    end
    return layer.readyDuration
end

---@param layer CDMLayer
local function WatchRange(layer)
    local spellID = layer.spellID
    local display = layer.owner.id and CDM:Get(layer.owner.id)
    if not spellID or not display or rangeState[spellID] ~= nil or not CDM:ConditionsUse(display, layer.index, 'inRange') then return end
    EnableSpellRangeCheck(spellID, true)
    rangeState[spellID] = IsSpellInRange(spellID) ~= false
end

-- Trigger --

CDM.TriggerTypes.spell = {
    ---@param trigger table
    ---@return boolean
    IsKnown = function(trigger)
        local base = trigger.SpellID
        if not base then return false end
        return IsSpellKnown(base) or IsSpellKnown(GetOverrideSpell(base) or base)
    end,

    ---@param layer CDMLayer
    ---@param trigger table
    Resolve = function(layer, trigger)
        local base = trigger.SpellID
        layer.baseSpellID = base
        -- found again on the next update, for whichever spell the layer tracks now
        chargeLayers[layer], layer.chargeItem, layer.fromCharges = nil, nil, nil
        local display = layer.owner.id and CDM:Get(layer.owner.id)
        layer.watchUsable = display ~= nil and (CDM:ConditionsUse(display, layer.index, 'usable') or CDM:ConditionsUse(display, layer.index, 'noPower'))
        CDM:WatchSpell(base, layer.owner.id)

        -- read even when the icon ignores the override, so an Overridden condition can still follow it
        local override = base and GetOverrideSpell(base)
        layer.overridden = override ~= nil and override ~= base

        if trigger.IgnoreOverride then
            layer.spellID = base
            CDM:SetIconTexture(layer, base and select(2, GetSpellTexture(base)))
            WatchRange(layer)
            return
        end

        local before = layer.spellID
        layer.spellID = base and (GetOverrideSpell(base) or base)
        if layer.spellID ~= before then
            -- The copied cooldown, its GCD hold and the GCD flag were the old spell's, e.g. Rising Sun Kick's when it turns into Rushing Wind Kick.
            layer.realCooldown, layer.heldGCD = nil, nil
            local named = namedAt[layer.spellID]
            local gcd = GetSpellCooldown(GCD_SPELL).isActive
            layer.state.onGCD = gcd and not (named and gcdPassTime and named >= gcdPassTime) -- cast this GCD before the swap: Flying Serpent Kick cancelled mid-GCD
            layer.readInGCD = gcd
        end
        CDM:WatchSpell(layer.spellID, layer.owner.id)
        CDM:SetIconTexture(layer, layer.spellID and GetSpellTexture(layer.spellID))
        WatchRange(layer)
    end,

    ---@param layer CDMLayer
    ---@param style table
    Update = function(layer, style)
        local spellID = layer.spellID
        if not spellID then
            if IsPreviewing(layer) then -- an empty trigger still previews, so a new display shows while it's set up
                layer.state.onCooldown = true
                layer.count = 1
                layer.duration = PreviewDuration(layer, PREVIEW_LENGTH)
                CDM:SetLayerTimer(layer, layer.duration)
                CDM:UpdateTexts(layer)
            end
            return
        end
        local state = layer.state
        local cooldown = GetSpellCooldown(spellID)
        local charges = GetSpellCharges(spellID)

        state.hasCharges = charges ~= nil and charges.maxCharges > 1
        local active = cooldown ~= nil and cooldown.isActive
        local gcdRunning = false
        if inCooldownEvent then
            local onGCD = active and cooldown.isOnGCD == true
            -- A GCD outlasting a short cooldown (Berserk Thrash) reads "on GCD", so the real one is held; an event naming the spell (Sharp Reflexes) makes that copy stale.
            local changed = changedSpell ~= nil and (spellID == changedSpell or layer.baseSpellID == changedSpell or spellID == changedBase)
            if changed then
                layer.realCooldown = nil
            end
            -- Charge spells aren't held: a reset no event names reads exactly like this, so they count as ready once the GCD outlasts the recharge.
            if not onGCD or changed or state.hasCharges then
                layer.heldGCD = nil
            elseif not layer.heldGCD and layer.realCooldown then
                layer.heldGCD = gcdEnds
            end
            state.onGCD = onGCD
            layer.readInGCD = gcdAtEvent
            if layer.heldGCD then
                recheck[layer] = true
                gcdEndFrame:NUIScheduleUpdate()
            else
                recheck[layer] = nil
            end
        else
            gcdRunning = GetSpellCooldown(GCD_SPELL).isActive
            if gcdRunning then
                if active and not state.onCooldown and not layer.readInGCD then
                    state.onGCD = true -- a GCD its cooldown event hasn't reached yet: SPELL_UPDATE_CHARGES fires before it
                end
                recheck[layer] = true
                gcdEndFrame:NUIScheduleUpdate()
            else
                -- the API can still read active the frame its swipe ends; Blizzard's viewer trusts its end time there (IsExpired)
                if layer.timerDone then
                    active = false
                end
                state.onGCD, layer.readInGCD = false, false
            end
        end
        if layer.heldGCD ~= gcdEnds then -- the real cooldown was shorter than that GCD, so it's over too
            layer.heldGCD = nil
        end
        local held = layer.heldGCD ~= nil
        -- Without Blizzard's verdict (the spell isn't in its lists): Roll with charges left reads no category; when
        -- the category is secret the lockout still shows as isOnGCD left nil, where a spell out of charges reads false
        local category = state.hasCharges and active and cooldown.activeCategory
        local chargesLeft = state.hasCharges and ChargesLeft(layer)
        local lockout
        if chargesLeft ~= nil then
            -- Blizzard's verdict wins when it gives one: a charge left is never No Charges Left, none is the real cooldown
            lockout = chargesLeft
        elseif NRSKNUI:IsSecretValue(category) then
            lockout = cooldown.isOnGCD == nil
        else
            lockout = state.hasCharges and active and category == nil
        end
        state.onCooldown = held or (active and not state.onGCD and not lockout)
        state.recharging = state.hasCharges and charges.isActive

        -- Texts never count down the GCD, the swipe only shows it when the style asks for it.
        local duration, swipe
        if held then
            duration, swipe = layer.realCooldown, layer.realCooldown
        elseif state.recharging and not state.onCooldown then
            duration = GetSpellChargeDuration(spellID)
            swipe = duration
        elseif lockout or not active then
            duration, swipe = ReadyDuration(layer), nil
        else
            -- Mid-GCD this read can mistake the GCD for the cooldown outside the cooldown event, so reuse the copy from that event.
            local cached = gcdRunning and layer.realCooldown
            duration = cached or GetSpellCooldownDuration(spellID, true)
            swipe = style.ShowGCD and GetSpellCooldownDuration(spellID) or duration
        end
        if not state.onCooldown then
            layer.realCooldown = nil
        elseif not held and duration and duration ~= layer.realCooldown then -- a fresh read keeps a moderated cooldown's rate current
            layer.realCooldown = duration:Copy()
        end
        local preview = IsPreviewing(layer) and not state.onCooldown and not state.recharging
        if preview then
            duration = PreviewDuration(layer, PREVIEW_LENGTH)
            swipe = duration
            state.onCooldown = true -- the preview's fake cooldown shows the on-cooldown conditions too
        end
        -- only for a condition that reads it, as RefreshUsable
        if layer.watchUsable then
            local usable, noPower = IsSpellUsable(spellID)
            state.usable = usable
            -- unusable for another reason (Roll's lockout, a stun) says nothing about power
            if usable or noPower then
                state.noPower = noPower
            end
        end
        state.proc = IsSpellOverlayed(spellID)
        state.inRange = rangeState[spellID]
        CDM:SetLayerTimer(layer, swipe)
        if not layer.isBar then -- a GCD-only swipe would count the GCD
            layer.Cooldown:SetHideCountdownNumbers(not CDM:ShowsTimerText(layer, style) or not (state.onCooldown or state.recharging))
        end
        layer.duration = duration
        CDM:UpdateTexts(layer)
        -- Hide %p on very short cooldowns: lockouts like Felblade after Vengeful Retreat look exactly like a real one.
        if duration then
            local alpha = 1
            if state.onCooldown or state.recharging then
                alpha = duration:EvaluateTotalDuration(NRSKNUI.curves.CountdownAlpha, Enum.DurationTimeModifier.RealTime) --[[@as number]]
            end
            for i = 1, layer.textCount or 0 do
                local text = layer.texts[i]
                if text.kind == 'duration' and not text.source then
                    text.fs:SetAlpha(alpha)
                end
            end
        end
    end,

    ---@param layer CDMLayer
    ---@param trigger table
    ---@return boolean
    IsActive = function(layer, trigger)
        if IsPreviewing(layer) then return true end
        if not layer.spellID then return false end
        local showOn = trigger.ShowOn
        if not showOn then return true end
        local busy = layer.state.onCooldown == true or layer.state.recharging == true
        return busy == (showOn == 'cooldown')
    end,

    ---@param layer CDMLayer
    IsStandby = function(layer)
        return layer.spellID ~= nil
    end,
}

---@param i number
---@param trigger table
---@param warnings string[]
CDM.TriggerTypes.spell.Warnings = function(i, trigger, warnings)
    if trigger.SpellID then
        CDM:WarnUnknownSpell(warnings, i, trigger.SpellID)
    else
        warnings[#warnings + 1] = format(L['Trigger %d: no spell chosen.'], i)
    end
end

---@param layer CDMLayer
---@return boolean changed
CDM.TriggerTypes.spell.RefreshUsable = function(layer)
    if not layer.spellID then return false end
    local state = layer.state
    local usable, noPower = IsSpellUsable(layer.spellID)
    local changed = usable ~= state.usable
    state.usable = usable
    if (usable or noPower) and noPower ~= state.noPower then
        state.noPower = noPower
        changed = true
    end
    return changed
end

-- Events --

-- isOnGCD is only trustworthy inside the SPELL_UPDATE_COOLDOWN handler (SpellSharedDocumentation.lua, live),
-- so cooldown updates run in the handler rather than being coalesced to the next frame.
local handlers = {
    SPELL_UPDATE_COOLDOWN = function(spellID, baseSpellID, _, startRecoveryCategory)
        inCooldownEvent = true
        changedSpell, changedBase = spellID, baseSpellID
        gcdAtEvent = GetSpellCooldown(GCD_SPELL).isActive
        local gcd = startRecoveryCategory == GLOBAL_RECOVERY_CATEGORY
        local now = GetTime()
        if spellID then
            namedAt[spellID] = now
        end
        -- One press fires a burst of GCD events in the same frame; the first one's pass already read every spell.
        if not spellID or (gcd and now ~= gcdPassTime) then
            if gcd then
                gcdPassTime = now
            end
            CDM:UpdateAllTriggers(CDM.SPELL_TYPES)
        else
            CDM:UpdateWatchers(spellID)
            if baseSpellID ~= spellID then
                CDM:UpdateWatchers(baseSpellID)
            end
        end
        inCooldownEvent = false
        changedSpell, changedBase = nil, nil
    end,
    SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = function(spellID) CDM:UpdateWatchers(spellID) end,
    SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = function(spellID) CDM:UpdateWatchers(spellID) end,
    SPELL_RANGE_CHECK_UPDATE = function(spellID, inRange, checksRange)
        if rangeState[spellID] == nil then return end
        rangeState[spellID] = not checksRange or inRange == true
        CDM:UpdateWatchers(spellID)
    end,
}

local eventFrame ---@type Frame?

local function OnEvent(_, event, ...)
    handlers[event](...)
end

CDM.TriggerTypes.spell.RegisterEvents = function()
    if not eventFrame then
        eventFrame = CreateFrame('Frame')
        eventFrame:SetScript('OnEvent', OnEvent)
        gcdEndFrame = CreateFrame('Frame')
        gcdEndFrame:NUISetScheduledUpdate(OnGCDEnd)
    end

    for event in pairs(handlers) do
        eventFrame:RegisterEvent(event)
    end
end

CDM.TriggerTypes.spell.UnregisterEvents = function()
    eventFrame:UnregisterAllEvents()
end

-- Conditions --

CDM.ConditionChecks.spell = {
    active     = { type = 'bool', get = function(layer, trigger) return CDM.TriggerTypes.spell.IsActive(layer, trigger) end },
    onCooldown = { type = 'bool', get = function(layer) return layer.state.onCooldown == true end },
    onGCD      = { type = 'bool', get = function(layer) return layer.state.onGCD == true end },
    recharging = { type = 'bool', get = function(layer) return layer.state.recharging == true end },
    noCharges  = { type = 'bool', get = function(layer) return layer.state.onCooldown == true end },
    usable     = { type = 'bool', get = function(layer) return layer.state.usable == true end },
    noPower    = { type = 'bool', get = function(layer) return layer.state.noPower == true end },
    inRange    = { type = 'bool', get = function(layer) return layer.state.inRange ~= false end },
    proc       = { type = 'bool', get = function(layer) return layer.state.proc == true end },
    overridden = { type = 'bool', get = function(layer) return layer.overridden == true end },
    remaining  = { type = 'number', curve = true }, -- secret in combat, so only a %p text's colour follows it
}

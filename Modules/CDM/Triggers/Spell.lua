---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

local pairs = pairs
local format = string.format
local CreateFrame = CreateFrame
local GetSpellCooldown = C_Spell.GetSpellCooldown
local GetSpellCharges = C_Spell.GetSpellCharges
local GetSpellCooldownDuration = C_Spell.GetSpellCooldownDuration
local GetSpellChargeDuration = C_Spell.GetSpellChargeDuration
local GetSpellTexture = C_Spell.GetSpellTexture
local GetOverrideSpell = C_Spell.GetOverrideSpell
local IsSpellKnown = C_SpellBook.IsSpellKnown
local IsSpellUsable = C_Spell.IsSpellUsable
local IsSpellInRange = C_Spell.IsSpellInRange
local EnableSpellRangeCheck = C_Spell.EnableSpellRangeCheck
local IsSpellOverlayed = C_SpellActivationOverlay.IsSpellOverlayed
local CreateDuration = C_DurationUtil.CreateDuration
local GLOBAL_RECOVERY_CATEGORY = Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY

local IsPreviewing, PreviewDuration = CDM.IsPreviewingLayer, CDM.PreviewDuration
local PREVIEW_LENGTH = CDM.PREVIEW_LENGTH

local inCooldownEvent = false
local gcdCount = 0
local rangeState = {} ---@type table<number, boolean> spellID -> in range, for spells a condition range-checks

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
        CDM:WatchSpell(base, layer.owner.id)
        if trigger.IgnoreOverride then
            -- A spell ID is never resolved to its override by the C_Spell queries; only its icon is.
            layer.spellID = base
            CDM:SetIconTexture(layer, base and select(2, GetSpellTexture(base)))
            WatchRange(layer)
            return
        end
        layer.spellID = base and (GetOverrideSpell(base) or base)
        CDM:WatchSpell(layer.spellID, layer.owner.id)
        CDM:SetIconTexture(layer, layer.spellID and GetSpellTexture(layer.spellID))
        WatchRange(layer)
    end,

    ---@param layer CDMLayer
    ---@param style table
    Update = function(layer, style)
        local spellID = layer.spellID
        if not spellID then return end
        local state = layer.state
        local cooldown = GetSpellCooldown(spellID)
        local charges = GetSpellCharges(spellID)

        state.hasCharges = charges ~= nil and charges.maxCharges > 1
        local active = cooldown ~= nil and cooldown.isActive
        if inCooldownEvent then
            local onGCD = active and cooldown.isOnGCD == true
            -- When a GCD outlasts a short cooldown e.g. Berserk Thrash, the client calls it "on GCD", so keep showing the real one.
            if not onGCD or (layer.heldGCD and layer.heldGCD ~= gcdCount) then -- it always ends before the next GCD starts
                layer.heldGCD = nil
            elseif not layer.heldGCD and layer.realCooldown then
                layer.heldGCD = gcdCount
            end
            state.onGCD = onGCD
        end
        local held = layer.heldGCD ~= nil
        local category = state.hasCharges and active and cooldown.activeCategory
        local lockout = state.hasCharges and active and not NRSKNUI:IsSecretValue(category) and category == nil -- Roll with charges left
        state.onCooldown = held or (active and not state.onGCD and not lockout)
        state.recharging = state.hasCharges and charges.isActive

        -- Texts never count down the GCD, the swipe only shows it when the style asks for it.
        local duration, swipe
        if held then
            duration, swipe = layer.realCooldown, layer.realCooldown
        elseif state.recharging and not state.onCooldown then
            duration = GetSpellChargeDuration(spellID)
            swipe = duration
        elseif lockout then
            duration, swipe = ReadyDuration(layer), nil
        else
            -- Outside the cooldown event this read can mistake the GCD for the cooldown, so reuse the copy from that event.
            duration = (not inCooldownEvent and layer.realCooldown) or GetSpellCooldownDuration(spellID, true)
            swipe = style.ShowGCD and GetSpellCooldownDuration(spellID) or duration
        end
        if not state.onCooldown then
            layer.realCooldown = nil
        elseif inCooldownEvent and not held and duration then -- the cooldown event is the only read we trust
            layer.realCooldown = duration:Copy()
        end
        local preview = IsPreviewing(layer) and not state.onCooldown and not state.recharging
        if preview then
            duration = PreviewDuration(layer, PREVIEW_LENGTH)
            swipe = duration
            state.onCooldown = true -- the preview's fake cooldown shows the on-cooldown conditions too
        end
        local usable, noPower = IsSpellUsable(spellID)
        state.usable = usable
        if usable or noPower then state.noPower = noPower end -- unusable for another reason e.g. Roll and stuns, says nothing about power
        state.proc = IsSpellOverlayed(spellID)
        state.inRange = rangeState[spellID]
        CDM:SetLayerTimer(layer, swipe)
        layer.duration = duration
        CDM:UpdateTexts(layer)
        -- Hide %p on very short cooldowns: lockouts like Felblade after Vengeful Retreat look exactly like a real one.
        if duration then
            local alpha = 1 -- ready: a text's Ready Text shows
            if state.onCooldown or state.recharging then
                alpha = duration:EvaluateTotalDuration(NRSKNUI.curves.CountdownAlpha, Enum.DurationTimeModifier.RealTime) --[[@as number]]
            end
            for i = 1, layer.textCount or 0 do
                local text = layer.texts[i]
                if text.kind == 'duration' and not text.source then text.fs:SetAlpha(alpha) end
            end
        end
    end,

    ---@param layer CDMLayer
    IsActive = function(layer) return layer.spellID ~= nil end,
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

-- isOnGCD is only trustworthy inside the SPELL_UPDATE_COOLDOWN handler (SpellSharedDocumentation.lua, live),
-- so cooldown updates run in the handler rather than being coalesced to the next frame.
local handlers = {
    SPELL_UPDATE_COOLDOWN = function(spellID, baseSpellID, _, startRecoveryCategory)
        inCooldownEvent = true
        if not spellID or startRecoveryCategory == GLOBAL_RECOVERY_CATEGORY then
            if startRecoveryCategory == GLOBAL_RECOVERY_CATEGORY then gcdCount = gcdCount + 1 end
            CDM:UpdateAll()
        else
            CDM:UpdateWatchers(spellID)
            if baseSpellID ~= spellID then CDM:UpdateWatchers(baseSpellID) end
        end
        inCooldownEvent = false
    end,
    SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = function(spellID) CDM:UpdateWatchers(spellID) end,
    SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = function(spellID) CDM:UpdateWatchers(spellID) end,
    SPELL_RANGE_CHECK_UPDATE = function(spellID, inRange, checksRange)
        if rangeState[spellID] == nil then return end
        rangeState[spellID] = not checksRange or inRange == true
        CDM:UpdateWatchers(spellID)
    end,
}

local eventFrame = CreateFrame('Frame')
eventFrame:SetScript('OnEvent', function(_, event, ...) handlers[event](...) end)

CDM.TriggerTypes.spell.RegisterEvents = function()
    for event in pairs(handlers) do eventFrame:RegisterEvent(event) end
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
    noCharges  = { type = 'bool', get = function(layer) return layer.state.hasCharges == true and layer.state.onCooldown == true end },
    usable     = { type = 'bool', get = function(layer) return layer.state.usable == true end },
    noPower    = { type = 'bool', get = function(layer) return layer.state.noPower == true end },
    inRange    = { type = 'bool', get = function(layer) return layer.state.inRange ~= false end },
    proc       = { type = 'bool', get = function(layer) return layer.state.proc == true end },
}

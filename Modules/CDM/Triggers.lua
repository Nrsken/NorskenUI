---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local pairs, ipairs = pairs, ipairs
local unpack = unpack
local next = next
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
local GetSpellName = C_Spell.GetSpellName
local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemCooldown = GetInventoryItemCooldown
local GetItemCooldown = C_Item.GetItemCooldown
local GetItemCount = C_Item.GetItemCount
local GetItemIconByID = C_Item.GetItemIconByID
local GetItemNameByID = C_Item.GetItemNameByID
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetItemSpell = C_Item.GetItemSpell
local IsUsableItem = C_Item.IsUsableItem
local CreateDuration = C_DurationUtil.CreateDuration
local GetTime = GetTime
local NewTimer = C_Timer.NewTimer
local UnitPower, UnitPowerMax, UnitPowerMissing, UnitPowerType = UnitPower, UnitPowerMax, UnitPowerMissing, UnitPowerType
local UnitPowerPercent = UnitPowerPercent
local GetRuneCooldown = GetRuneCooldown
local UnitPartialPower, UnitPowerDisplayMod = UnitPartialPower, UnitPowerDisplayMod
local GetPowerRegenForPowerType = GetPowerRegenForPowerType
local huge = math.huge
local GetSpecialization, GetSpecializationInfo = GetSpecialization, GetSpecializationInfo
local GLOBAL_RECOVERY_CATEGORY = Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY

local spellIndex = {} ---@type table<number, table<string, true>> spellID -> icon ids watching it
local tconcat, tsort, tostring = table.concat, table.sort, tostring
local format = string.format
local AuraKey
local inCooldownEvent = false
local gcdCount = 0
local itemWatchers = {} ---@type table<string, true> icon ids with an item trigger
local rangeState = {} ---@type table<number, boolean> spellID -> in range, for spells a condition range-checks
local timerIndex = {} ---@type table<number, table<CDMLayer, true>> cast spellID -> timer layers it starts
local powerLayers = {} ---@type table<CDMLayer, table> power layers -> their trigger

local L = NRSKNUI.Libs.AL
local PowerType = Enum.PowerType
-- What a power trigger can follow; 'primary' is whatever the current form or spec uses.
CDM.POWER_TYPES = {
    { value = 'primary',               text = L['Primary Power'] },
    { value = PowerType.Mana,          text = L['Mana'] },
    { value = PowerType.Rage,          text = L['Rage'] },
    { value = PowerType.Focus,         text = L['Focus'] },
    { value = PowerType.Energy,        text = L['Energy'] },
    { value = PowerType.RunicPower,    text = L['Runic Power'] },
    { value = PowerType.LunarPower,    text = L['Astral Power'] },
    { value = PowerType.Maelstrom,     text = L['Maelstrom'] },
    { value = PowerType.Insanity,      text = L['Insanity'] },
    { value = PowerType.Fury,          text = L['Fury'] },
    { value = PowerType.ComboPoints,   text = L['Combo Points'] },
    { value = PowerType.HolyPower,     text = L['Holy Power'] },
    { value = PowerType.SoulShards,    text = L['Soul Shards'] },
    { value = PowerType.Chi,           text = L['Chi'] },
    { value = PowerType.ArcaneCharges, text = L['Arcane Charges'] },
    { value = PowerType.Essence,       text = L['Essence'] },
    { value = PowerType.Runes,         text = L['Runes'] },
}
-- Resources counted in whole points, which Automatic ticks split and a bar's Static or Progress mode draws one pip each.
CDM.SEGMENTED_POWER = {
    [PowerType.ComboPoints] = true,
    [PowerType.HolyPower] = true,
    [PowerType.SoulShards] = true,
    [PowerType.Chi] = true,
    [PowerType.ArcaneCharges] = true,
    [PowerType.Essence] = true,
    [PowerType.Runes] = true,
}
local SEGMENTED_POWER = CDM.SEGMENTED_POWER
-- One of each, for "Each Rune" and the like.
CDM.PIP_NAMES = {
    [PowerType.ComboPoints] = L['Combo Point'],
    [PowerType.HolyPower] = L['Holy Power'],
    [PowerType.SoulShards] = L['Soul Shard'],
    [PowerType.Chi] = L['Chi'],
    [PowerType.ArcaneCharges] = L['Arcane Charge'],
    [PowerType.Essence] = L['Essence'],
    [PowerType.Runes] = L['Rune'],
}
local POWER_NAMES = {}
for _, entry in ipairs(CDM.POWER_TYPES) do POWER_NAMES[entry.value] = entry.text end
CDM.POWER_NAMES = POWER_NAMES

local ITEM_SLOTS = { trinket1 = INVSLOT_TRINKET1, trinket2 = INVSLOT_TRINKET2 }
-- Items that share one cooldown, so any of them reads it; the first one in the bags is shown.
local ITEM_FAMILIES = {
    healthstone = { 5512, 224464 }, -- Healthstone, Demonic Healthstone
    combatPotion = { 241308 },      -- Light's Potential; every combat potion shares its cooldown
}
local MIN_ITEM_COOLDOWN = 1.5       -- shorter is the item's global cooldown, not its own
local QUESTION_MARK = 134400
local PREVIEW_LENGTH = 7            -- WeakAuras' options preview: anything not already running gets a 7s timer
local PREVIEW_PANDEMIC = 0.3        -- most auras' refresh window: the last 30% carries over
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
---@return boolean
local function IsPreviewing(layer)
    return CDM.previewing == true and layer.owner.shown == true
end

---A lone aura layer's own parts, the preview stand-in or its placeholder: the style, with `changes` over it.
---@param layer CDMLayer
---@param display table
---@param style table
---@param changes table<string, any> a placeholder's While Missing changes, empty for the plain style
---@param textsShown boolean whether texts nothing changes show by their own Enabled (a placeholder's start hidden)
local function PaintStandIn(layer, display, style, changes, textsShown)
    local alpha = changes.alpha or 1
    local desaturate = changes.desaturate
    if desaturate == nil then desaturate = style.Desaturate end
    layer.Icon:SetVertexColor(unpack(changes.color or style.Color))
    layer.Icon:SetDesaturated(desaturate == true)
    layer.Icon:SetAlpha(alpha)
    layer.borderHost:SetAlpha(alpha)
    layer.textHost:SetAlpha(alpha)
    if layer.isBar then
        layer.Bar:SetAlpha(alpha)
        layer.Bar.bg:SetVertexColor(unpack(changes.backgroundColor or style.BackgroundColor))
    end
    local borders, texts = 0, 0
    for n, element in ipairs(display.SubRegions or {}) do
        local visible = changes['sub.' .. n .. '.visible']
        local color = changes['sub.' .. n .. '.color'] or element.Color
        if element.type == 'border' then
            borders = borders + 1
            local border = layer.borders[borders]
            if border then
                if visible == nil then visible = element.Enabled end
                border:SetShown(visible == true)
                for _, edge in ipairs(border.edges) do edge:SetColorTexture(unpack(color)) end
            end
        elseif element.type == 'text' then
            texts = texts + 1
            local text = layer.texts[texts]
            if text then
                if visible == nil then visible = textsShown and element.Enabled end
                text.fs:SetShown(visible == true)
                text.fs:SetTextColor(unpack(color))
            end
        end
    end
end

---A looping fake timer for the options preview; OnCooldownDone re-arms it through UpdateIcon.
---@param layer CDMLayer
---@param length number
---@return LuaDurationObject
local function PreviewDuration(layer, length)
    local now = GetTime()
    if not layer.previewEnd or now >= layer.previewEnd - 0.05 then layer.previewEnd = now + length end
    layer.previewDuration = layer.previewDuration or CreateDuration()
    layer.previewDuration:SetTimeFromStart(layer.previewEnd - length, length)
    return layer.previewDuration
end

CDM.IsPreviewingLayer, CDM.PreviewDuration = IsPreviewing, PreviewDuration

---The item IDs an item trigger can read: the equipped trinket, a family, or a custom ID.
---@param trigger table
---@return number[]
local function ItemIDs(trigger)
    local slot = ITEM_SLOTS[trigger.Item]
    if slot then return { GetInventoryItemID('player', slot) } end
    if trigger.Item == 'custom' then return { trigger.ItemID } end
    return ITEM_FAMILIES[trigger.Item] or {}
end

---@param spellID number?
---@param id string
local function Index(spellID, id)
    if not spellID then return end
    local watchers = spellIndex[spellID]
    if not watchers then
        watchers = {}
        spellIndex[spellID] = watchers
    end
    watchers[id] = true
end

---@param id string
function CDM:UnwatchIcon(id)
    itemWatchers[id] = nil
    for layer in pairs(powerLayers) do
        if layer.owner.id == id then powerLayers[layer] = nil end
    end
    for _, triggerType in pairs(self.TriggerTypes) do
        if triggerType.Unwatch then triggerType.Unwatch(id) end
    end
    for spellID, layers in pairs(timerIndex) do
        for layer in pairs(layers) do
            if layer.owner.id == id then layers[layer] = nil end
        end
        if not next(layers) then timerIndex[spellID] = nil end
    end
    for spellID, watchers in pairs(spellIndex) do
        watchers[id] = nil
        if not next(watchers) then spellIndex[spellID] = nil end
    end
end

-- Split resource bars: one pip per rune or point, ready ones first. --

local runeOrder, runeRemaining = {}, {}
local RUNE_START_SLACK = 0.1 -- so a rune spent this frame never reads as queued

---Runes ready first, then by time left (RuneFrame.lua, live); one frame's rune events change it between calls. Rune timings are never secret.
---@return number[]
local function SortedRunes()
    local now = GetTime()
    for i = 1, 6 do
        local start, duration, ready = GetRuneCooldown(i)
        runeOrder[i] = i
        -- A rune waiting its turn has no start yet, so it sorts after every running one.
        local remaining = start and duration and duration > 0 and start + duration - now or huge
        -- Run out but not yet reported ready (that waits for RUNE_POWER_UPDATE), it must not sort ahead of the ready runes.
        runeRemaining[i] = ready and -1 or remaining > 0 and remaining or 0
    end
    for i = 2, 6 do
        local key, j = runeOrder[i], i - 1
        while j > 0 and runeRemaining[runeOrder[j]] > runeRemaining[key] do
            runeOrder[j + 1] = runeOrder[j]
            j = j - 1
        end
        runeOrder[j + 1] = key
    end
    return runeOrder
end

local PROGRESS_HOLD = 0.3 -- longest a filled progress pip waits for the power its swing grants
local SECRET_MAX_PIPS = 5 -- a split bar's pips while the resource's maximum reads secret
local essenceRate = 0.2   -- points a second, Blizzard's fallback in EssenceFramePlayer.lua; regen reads secret while stats are restricted

---The filling Essence's start and length, from its elapsed share in thousandths and the regen rate (EssenceFramePlayer.lua, live).
---@return number? start, number? length
local function EssenceFill()
    local partial = UnitPartialPower('player', PowerType.Essence)
    local rate = GetPowerRegenForPowerType(PowerType.Essence)
    if rate and not NRSKNUI:IsSecretValue(rate) and rate > 0 then essenceRate = rate end
    if NRSKNUI:IsSecretValue(partial) then return nil end
    local length = 1 / essenceRate
    return GetTime() - partial / 1000 * length, length
end

---Every pip of a split bar (EllesmereUI's rune modes): Static fills only what is ready, Progress also fills each
---recharging rune, the filling Essence and a partial Soul Shard. Points use an (N-1, N) range fed the value,
---which the widget compares, so a secret count still draws.
---@param layer CDMLayer
---@param trigger table
local function UpdatePips(layer, trigger)
    local powerType, count, state = layer.powerType --[[@as Enum.PowerType]], layer.pipCount --[[@as number]], layer.state
    local progress = trigger.Mode == 'progress'
    state.recharging, state.waiting = false, false
    layer.duration = nil

    if powerType == PowerType.Runes then
        local order, ready, now = SortedRunes(), 0, GetTime()
        for n = 1, count do
            local rune = order[n]
            local start, duration, isReady = GetRuneCooldown(rune)
            if isReady then ready = ready + 1 end
            CDM:SetLayerPipSlot(layer, rune, n)
            local running = not isReady and start and duration and duration > 0
            -- Three runes regenerate at once; a queued one reports the start of its turn, still ahead.
            local waiting = not isReady and not (running and start <= now + RUNE_START_SLACK)
            layer.pips[rune].waiting = waiting
            state.waiting = state.waiting or waiting
            if progress and running then
                CDM:SetLayerPipTimer(layer, rune, start, duration)
            else
                CDM:SetLayerPipValue(layer, rune, isReady and 1 or 0, 1, 0, not isReady, running and start or nil, running and duration or nil)
            end
            state.recharging = state.recharging or not isReady
        end
        layer.value, layer.max = ready, count
        return
    end

    -- Soul Shards move in tenths: Progress feeds the unmodified value against a scaled range, so a partial shard fills.
    local mod = progress and UnitPowerDisplayMod(powerType) or 1
    if mod <= 0 then mod = 1 end
    local value = UnitPower('player', powerType, progress)
    for n = 1, count do CDM:SetLayerPipValue(layer, n, value, n * mod, (n - 1) * mod, false) end

    local current, max = UnitPower('player', powerType), UnitPowerMax('player', powerType)
    layer.value, layer.max = current, max
    if not progress then return end
    local filling = not NRSKNUI:IsSecretValue(current) and not NRSKNUI:IsSecretValue(max)
        and current < max and current < count and current + 1 or nil
    if filling and powerType == PowerType.Essence then
        local start, length = EssenceFill()
        if start then
            CDM:SetLayerPipTimer(layer, filling, start, length)
            state.recharging = true
        end
    end
    if trigger.ProgressCooldownID then
        layer.viewerHold = filling == nil
        local running = CDM:MirrorViewerBar(layer)
        -- The tracked bar ends a frame or so before the power it grants arrives; hold the fill full until then.
        local held = false
        if running then
            layer.progressPip, layer.progressHoldEnd = filling, nil
        elseif filling and layer.progressPip == filling then
            local now = GetTime()
            if not layer.progressHoldEnd then
                layer.progressHoldEnd = now + PROGRESS_HOLD
                if layer.progressHoldTimer then layer.progressHoldTimer:Cancel() end
                layer.progressHoldTimer = NewTimer(PROGRESS_HOLD, function()
                    layer.progressHoldTimer = nil
                    if layer.owner.id then CDM:UpdateIcon(layer.owner.id) end
                end)
            end
            held = now < layer.progressHoldEnd
            if held then
                local source = CDM:GetLayerProgress(layer)
                source:SetValue((source:GetMinMaxValues()))
            else
                layer.progressPip = nil
            end
        else
            layer.progressPip, layer.progressHoldEnd = nil, nil
        end
        local shown = filling ~= nil and (running or held)
        if shown then layer.pips[filling].recharging = true end
        CDM:ShowLayerProgress(layer, shown, filling and layer.pips[filling] or nil)
        state.recharging = state.recharging or shown
    end
end

-- Trigger types. Resolve runs on build and on spell changes, Update on every relevant event,
-- IsActive picks the layer on show: the first active trigger wins.
CDM.TriggerTypes = {
    spell = {
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
            Index(base, layer.owner.id)
            if trigger.IgnoreOverride then
                -- A spell ID is never resolved to its override by the C_Spell queries; only its icon is.
                layer.spellID = base
                CDM:SetIconTexture(layer, base and select(2, GetSpellTexture(base)))
                return
            end
            layer.spellID = base and (GetOverrideSpell(base) or base)
            Index(layer.spellID, layer.owner.id)
            CDM:SetIconTexture(layer, layer.spellID and GetSpellTexture(layer.spellID))
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
    },

    item = {
        ---@param trigger table
        ---@return boolean
        IsKnown = function(trigger)
            local itemID = ItemIDs(trigger)[1]
            if not itemID then return false end
            -- A blacklisted trinket, or a passive one when the trigger hides those, never loads.
            if ITEM_SLOTS[trigger.Item] then
                if CDM.db.TrinketBlacklist[itemID] then return false end
                if trigger.HidePassive and not GetItemSpell(itemID) then return false end
            end
            return true
        end,

        ---@param layer CDMLayer
        ---@param trigger table
        Resolve = function(layer, trigger)
            local ids = ItemIDs(trigger)
            local owned
            for _, itemID in ipairs(ids) do
                if ITEM_SLOTS[trigger.Item] or GetItemCount(itemID, false, true) > 0 then
                    owned = itemID
                    break
                end
            end
            layer.itemID = owned or ids[1]
            layer.itemSlot = ITEM_SLOTS[trigger.Item]
            layer.itemFamily = not layer.itemSlot and ids or nil
            layer.spellID, layer.baseSpellID = nil, nil
            itemWatchers[layer.owner.id] = true
            CDM:SetIconTexture(layer, layer.itemID and GetItemIconByID(layer.itemID))
        end,

        -- Item cooldowns are plain numbers, so the duration object is built here.
        ---@param layer CDMLayer
        ---@param style table
        Update = function(layer, style)
            local itemID = layer.itemID
            if not itemID then return end

            local start, duration, enabled
            if layer.itemSlot then
                start, duration, enabled = GetInventoryItemCooldown('player', layer.itemSlot)
            else
                start, duration, enabled = GetItemCooldown(itemID)
            end
            local onCooldown = enabled ~= false and enabled ~= 0 and (duration or 0) > MIN_ITEM_COOLDOWN
                and start + duration > GetTime()
            local preview = not onCooldown and IsPreviewing(layer)

            layer.itemDuration = layer.itemDuration or CreateDuration()
            if onCooldown then
                layer.itemDuration:SetTimeFromStart(start, duration)
                layer.duration = layer.itemDuration
            elseif preview then
                layer.duration = PreviewDuration(layer, PREVIEW_LENGTH)
            else
                layer.itemDuration:SetTimeFromStart(0, 0)
                layer.duration = layer.itemDuration
            end
            CDM:SetLayerTimer(layer, (onCooldown or preview) and layer.duration or nil)
            layer.endTime = (onCooldown and start + duration) or (preview and layer.previewEnd) or nil

            local count
            if layer.itemFamily then
                count = 0
                for _, familyID in ipairs(layer.itemFamily) do count = count + GetItemCount(familyID, false, true) end
            end
            layer.count = count
            layer.state.onCooldown = onCooldown or preview
            layer.state.owned = layer.itemSlot ~= nil or (count or 0) > 0
            layer.state.usable = IsUsableItem(itemID) == true

            CDM:UpdateTexts(layer)
        end,

        -- An item not in the bags only shows with Show When Not in Bags, or a condition's Show Display.
        ---@param layer CDMLayer
        ---@param trigger table
        IsActive = function(layer, trigger)
            return layer.itemID ~= nil and (layer.state.owned ~= false or trigger.ShowNotOwned == true or IsPreviewing(layer))
        end,

        ---@param layer CDMLayer
        IsStandby = function(layer) return layer.itemID ~= nil and layer.state.owned == false end,
    },

    -- A fixed-length timer started by the player's own cast, for spells with no aura to follow.
    timer = {
        ---@param trigger table
        ---@return boolean
        IsKnown = function(trigger)
            local spellID = trigger.SpellID
            if not spellID then return false end
            return IsSpellKnown(spellID) or IsSpellKnown(GetOverrideSpell(spellID) or spellID)
        end,

        ---@param layer CDMLayer
        ---@param trigger table
        Resolve = function(layer, trigger)
            local spellID = trigger.SpellID
            layer.spellID, layer.baseSpellID = spellID, spellID
            layer.timerLength = trigger.Duration
            if spellID then
                for _, castID in ipairs({ spellID, GetOverrideSpell(spellID) }) do
                    timerIndex[castID] = timerIndex[castID] or {}
                    timerIndex[castID][layer] = true
                end
            end
            CDM:SetIconTexture(layer, spellID and GetSpellTexture(spellID))
        end,

        ---@param layer CDMLayer
        ---@param style table
        Update = function(layer, style)
            local running = layer.timerEnd ~= nil and GetTime() < layer.timerEnd
            layer.timerDuration = layer.timerDuration or CreateDuration()
            if running then
                layer.timerDuration:SetTimeFromStart(layer.timerEnd - layer.timerLength, layer.timerLength)
                layer.duration = layer.timerDuration
            else
                layer.timerEnd = nil
                layer.timerDuration:SetTimeFromStart(0, 0)
                layer.duration = layer.timerDuration
                if IsPreviewing(layer) and (layer.timerLength or 0) > 0 then
                    layer.duration = PreviewDuration(layer, layer.timerLength)
                    running = true
                end
            end
            CDM:SetLayerTimer(layer, running and layer.duration or nil)
            layer.endTime = running and (layer.timerEnd or layer.previewEnd) or nil
            CDM:UpdateTexts(layer)
        end,

        ---@param layer CDMLayer
        IsActive = function(layer)
            return (layer.timerEnd ~= nil and GetTime() < layer.timerEnd) or (IsPreviewing(layer) and (layer.timerLength or 0) > 0)
        end,
    },

    -- The player's power; the values only ever reach widgets, so a restricted (secret) one still draws.
    power = {
        Value = true, -- %p is the value and %t the max, not a time
        IsKnown = function() return true end,

        ---@param layer CDMLayer
        ---@param trigger table
        Resolve = function(layer, trigger)
            local powerType = trigger.PowerType
            if powerType == nil or powerType == 'primary' then powerType = UnitPowerType('player') end
            layer.powerType = powerType
            layer.spellID, layer.baseSpellID = nil, nil
            layer.max = UnitPowerMax('player', powerType)
            local plainMax = not NRSKNUI:IsSecretValue(layer.max)
            local split = layer.isBar and trigger.Mode ~= nil and SEGMENTED_POWER[powerType] == true
            if split then
                CDM:SetLayerPips(layer, powerType == PowerType.Runes and 6 or plainMax and layer.max or SECRET_MAX_PIPS)
            end
            if split and trigger.Mode == 'progress' and trigger.ProgressCooldownID then
                CDM:WatchViewerBar(layer, trigger.ProgressCooldownID, CDM:GetLayerProgress(layer))
            else
                CDM:ShowLayerProgress(layer, false)
            end
            local ticks
            local segments = split and layer.pipCount or SEGMENTED_POWER[powerType] and plainMax and layer.max or 0
            if segments > 1 then
                ticks = {}
                for i = 1, segments - 1 do ticks[i] = i / segments end
            end
            layer.autoTicks = ticks
            CDM:DrawTicks(layer)
            powerLayers[layer] = trigger
            local specIndex = GetSpecialization()
            CDM:SetIconTexture(layer, specIndex and select(4, GetSpecializationInfo(specIndex)))
            if layer.owner.style.BarColorMode == 'power' then
                -- The global palette the unit frames use; runes take their spec's colour, as oUF's runes do.
                local palette = NRSKNUI.Colors
                local color = powerType == PowerType.Runes and specIndex and palette.runes[specIndex] or palette.power[powerType]
                if color then CDM:PaintBar(layer, { color:GetRGB() }) end
            end
        end,

        ---@param layer CDMLayer
        ---@param style table
        Update = function(layer, style, trigger)
            local powerType = layer.powerType
            if (layer.pipCount or 0) > 0 then
                UpdatePips(layer, trigger)
                CDM:UpdateTexts(layer)
                return
            end
            if powerType == PowerType.Runes then
                -- Runes never fire UNIT_POWER_*; each rune reports its own cooldown instead (RuneFrame.lua, live).
                local ready = 0
                for i = 1, layer.max do
                    if select(3, GetRuneCooldown(i)) then ready = ready + 1 end
                end
                layer.value = ready
                local shown = style.Inverse and layer.max - ready or ready
                CDM:SetLayerValue(layer, shown, layer.max, (shown > 0 and shown < layer.max) and 1 or 0)
                CDM:UpdateTexts(layer)
                return
            end
            layer.value = UnitPower('player', powerType)
            layer.max = UnitPowerMax('player', powerType)
            CDM:SetLayerValue(layer, style.Inverse and UnitPowerMissing('player', powerType) or layer.value, layer.max,
                UnitPowerPercent('player', powerType, false, NRSKNUI.curves.BarSparkAlpha) --[[@as number]])
            CDM:UpdateTexts(layer)
        end,

        IsActive = function() return true end,
    },

    -- Secret: whether the aura is up never reaches Lua, the layer's slot shows itself while it is.
    aura = {
        Secret = true,

        ---@param trigger table
        ---@return boolean
        IsKnown = function(trigger) return CDM:GetAuraSpellIDs(trigger) ~= nil end,

        ---@param layer CDMLayer
        ---@param trigger table
        Resolve = function(layer, trigger)
            local spellIDs = CDM:GetAuraSpellIDs(trigger)
            if not spellIDs then return CDM:ReleaseAuraLayer(layer) end

            local key = AuraKey(trigger, spellIDs)
            local configured = layer.auraKey == key
            layer.auraKey = key
            local function Restyle()
                if layer.auraKey == key then CDM:StyleAuraButton(layer, trigger) end
            end
            local function Apply()
                if layer.auraKey ~= key then return end
                if not configured then CDM:ConfigureAuraLayer(layer, trigger, spellIDs) end
                -- Existing aura buttons deny tainted access while auras are secret, not just in combat; new ones style on creation.
                if NRSKNUI:AreAurasSecret() then
                    -- The restriction queue keeps every entry, so a layer waits there once with its latest restyle.
                    layer.restyleAura = Restyle
                    if NRSKNUI:IsRestricted() and not layer.restyleQueued then
                        layer.restyleQueued = true
                        NRSKNUI:DeferUntilUnrestricted(0, function()
                            layer.restyleQueued = nil
                            local restyle = layer.restyleAura
                            layer.restyleAura = nil
                            if restyle then restyle() end
                        end)
                    end
                elseif configured then
                    Restyle()
                end
            end
            -- Re-resolved on every SPELLS_CHANGED: a fresh closure each time would pile up in the combat queue.
            layer.applyAura = Apply
            layer.runAura = layer.runAura or function()
                local apply = layer.applyAura
                layer.applyAura = nil
                if apply then apply() end
            end
            NRSKNUI:RunWhenSafe(layer.runAura)
        end,

        -- The container only shows real auras; the options preview fakes one with the layer's own spare parts.
        ---@param layer CDMLayer
        ---@param style table
        ---@param trigger table
        Update = function(layer, style, trigger)
            local preview = IsPreviewing(layer)
            local display = layer.owner.id and CDM:Get(layer.owner.id)
            local active, pandemicColor, pandemic = {}, nil, {}
            if display then active, pandemicColor, pandemic = CDM:GetAuraConditionChanges(display, layer.index) end
            local overlay = trigger.Type == 'auraoverlay'
            local showIcon = not overlay or active.auraIcon == true
            layer.Icon:SetShown(preview and showIcon and not (layer.isBar and not style.IconShow))
            layer.Cooldown:SetShown(preview and showIcon)
            layer.textHost:SetShown(preview)
            layer.borderHost:SetShown(preview and not overlay)
            if layer.isBar then layer.Bar:SetShown(preview) end
            if layer.auraHost then layer.auraHost:SetShown(not preview and layer.auraKey ~= nil) end
            if overlay and display and display.type == 'bar' and (preview or layer.previewOverlayShown) then
                layer.previewOverlay = layer.previewOverlay or {}
                CDM:PaintBarOverlay(layer, layer.previewOverlay, layer, preview and active or {})
                layer.previewOverlayShown = preview
            end
            if layer.previewPandemicTimer then
                layer.previewPandemicTimer:Cancel()
                layer.previewPandemicTimer = nil
            end
            if not preview then
                if layer.previewPandemic then layer.previewPandemic:Hide() end
                for _, glow in ipairs(layer.glows) do glow:Stop() end
                if trigger.Placeholder and not overlay and display then
                    -- The layer's own parts under the aura button, which covers them while it's up; While Missing is read onto them once.
                    local missing = select(4, CDM:GetAuraConditionChanges(display, layer.index))
                    CDM:SetIconTexture(layer, CDM:GetTriggerTexture(trigger))
                    layer.Icon:SetShown(not (layer.isBar and not style.IconShow))
                    PaintStandIn(layer, display, style, missing, false)
                    layer.Cooldown:Clear()
                    layer.borderHost:Show()
                    layer.textHost:Show()
                    if layer.isBar then
                        layer.Bar:SetMinMaxValues(0, 1)
                        layer.Bar:SetValue(0)
                        layer.Bar.spark:SetAlpha(0)
                        layer.Bar:Show()
                    end
                end
                return
            end

            if overlay then
                layer.Icon:SetAlpha(1)
                layer.Icon:SetTexture(active.auraTexture or CDM:GetTriggerTexture(trigger) or QUESTION_MARK)
            else
                CDM:SetIconTexture(layer, CDM:GetTriggerTexture(trigger))
                if display then PaintStandIn(layer, display, style, {}, true) end
            end
            layer.duration = PreviewDuration(layer, PREVIEW_LENGTH)
            CDM:SetLayerTimer(layer, layer.duration)
            layer.Cooldown:SetShown(showIcon) -- setting a timer shows a Cooldown frame again
            layer.count = 1
            if layer.isBar and trigger.BarMode == 'stacks' then
                -- An explicit value takes the bar off the preview timer; the timer still loops the stand-in.
                local maxStacks = trigger.MaxStacks or 10
                layer.count = math.ceil(maxStacks * 0.6)
                layer.Bar:SetMinMaxValues(0, maxStacks)
                layer.Bar:SetValue(layer.count)
                layer.Bar.spark:SetAlpha(1)
            end
            if overlay and showIcon then
                local desaturate, swipe, reverse = active.auraDesaturate, active.auraSwipe, active.auraInverse
                if desaturate == nil then desaturate = style.Desaturate end
                if swipe == nil then swipe = style.DrawSwipe end
                if reverse == nil then reverse = style.Reverse end
                layer.Icon:SetVertexColor(unpack(active.auraColor or style.Color))
                layer.Icon:SetDesaturated(desaturate == true)
                layer.Cooldown:SetDrawSwipe(swipe == true)
                layer.Cooldown:SetReverse(reverse == true)
            end
            CDM:UpdateTexts(layer)
            if overlay and display then
                local ordinal = 0
                for index, element in ipairs(display.SubRegions or {}) do
                    if element.type == 'text' then
                        ordinal = ordinal + 1
                        local text = layer.texts[ordinal]
                        if text then text.fs:SetShown(active['sub.' .. index .. '.visible'] == true) end
                    end
                end
            end

            local window = PREVIEW_LENGTH * PREVIEW_PANDEMIC
            local remaining = layer.previewEnd - GetTime()
            local inWindow = remaining <= window

            -- The stand-in shows a glow element as the aura would: its own Enabled, while active, in the window.
            local hasPandemicGlow = false
            for key in pairs(pandemic) do
                if key:find('%.visible$') then hasPandemicGlow = true end
            end
            if display then
                for index, element in ipairs(display.SubRegions or {}) do
                    if element.type == 'glow' then
                        local key = 'sub.' .. index .. '.visible'
                        local shown = active[key]
                        if shown == nil then shown = not overlay and element.Enabled end
                        if inWindow and pandemic[key] then shown = true end
                        local glow = layer.glows[CDM:GlowOrdinal(display, index)]
                        if glow and shown then glow:Start(element, style.Width, style.Height) elseif glow then glow:Stop() end
                    end
                end
            end
            if (pandemicColor or hasPandemicGlow) and not inWindow then
                layer.previewPandemicTimer = NewTimer(remaining - window, function()
                    layer.previewPandemicTimer = nil
                    if layer.owner.id then CDM:UpdateIcon(layer.owner.id) end
                end)
            end

            local border = layer.previewPandemic
            if not pandemicColor then
                if border then border:Hide() end
                return
            end
            if not border then
                local host = CreateFrame('Frame', nil, layer)
                host:SetAllPoints()
                border = host:CreateTexture(nil, 'OVERLAY')
                border:SetTexture(CDM.PANDEMIC_TEXTURE)
                border:NUISetPixelInside(layer)
                layer.previewPandemic = border
            end
            border:GetParent():SetFrameLevel(layer:GetFrameLevel() + 2) -- over the swipe, under the sub elements
            border:SetVertexColor(unpack(pandemicColor))
            border:SetShown(inWindow)
        end,

        IsActive = function() return false end,
    },
}
CDM.TriggerTypes.auraoverlay = CDM.TriggerTypes.aura

---The spell a trigger stands for; a custom aura goes by its own first ID, not one left from a Cooldown Manager pick.
---@param trigger table
---@return number?
function CDM:GetTriggerSpell(trigger)
    if (trigger.Type == 'aura' or trigger.Type == 'auraoverlay') and trigger.Source == 'custom' then return trigger.SpellIDs and trigger.SpellIDs[1] end
    return trigger.SpellID or (trigger.SpellIDs and trigger.SpellIDs[1])
end

---@param trigger table
---@return number? texture
function CDM:GetTriggerTexture(trigger)
    if trigger.Type == 'power' or trigger.Type == 'stat' then
        local specIndex = GetSpecialization()
        return specIndex and select(4, GetSpecializationInfo(specIndex))
    end
    if trigger.Type == 'item' then
        local itemID = ItemIDs(trigger)[1]
        return itemID and GetItemIconByID(itemID)
    end
    local spellID = self:GetTriggerSpell(trigger)
    return spellID and GetSpellTexture(spellID)
end

---@param trigger table
---@return string? name
function CDM:GetTriggerName(trigger)
    if trigger.Type == 'power' then return POWER_NAMES[trigger.PowerType or 'primary'] end
    if trigger.Type == 'cast' then return L['Cast Bar'] end
    if trigger.Type == 'stat' then return self:GetStat(trigger).name end
    if trigger.Type == 'item' then
        local itemID = ItemIDs(trigger)[1]
        return itemID and GetItemNameByID(itemID)
    end
    local spellID = self:GetTriggerSpell(trigger)
    return spellID and GetSpellName(spellID)
end

---Problems found from the settings alone, for the Information tab.
---@param id string
---@return string[]
function CDM:GetWarnings(id)
    local display = self:Get(id)
    local warnings = {}
    if not display then return warnings end

    if self:IsGroup(id) then
        if #self:GetChildren(id) == 0 then warnings[1] = L['This group is empty.'] end
        return warnings
    end

    local function CheckSpell(i, spellID)
        if not GetSpellName(spellID) then warnings[#warnings + 1] = format(L['Trigger %d: spell ID %d does not exist.'], i, spellID) end
    end

    local triggers = display.Triggers or {}
    for i, trigger in ipairs(triggers) do
        local triggerType = trigger.Type
        if triggerType == 'spell' or triggerType == 'timer' then
            if trigger.SpellID then
                CheckSpell(i, trigger.SpellID)
            else
                warnings[#warnings + 1] = format(L['Trigger %d: no spell chosen.'], i)
            end
        elseif triggerType == 'aura' or triggerType == 'auraoverlay' then
            if trigger.Source == 'custom' then
                if not (trigger.SpellIDs and trigger.SpellIDs[1]) then warnings[#warnings + 1] = format(L['Trigger %d: no aura spell IDs.'], i) end
                for _, spellID in ipairs(trigger.SpellIDs or {}) do CheckSpell(i, spellID) end
            elseif not (trigger.CooldownID or trigger.SpellID) then
                warnings[#warnings + 1] = format(L['Trigger %d: no aura chosen.'], i)
            end
        elseif triggerType == 'cast' then
            for _, spellID in ipairs(trigger.SpellIDs or {}) do CheckSpell(i, spellID) end
        elseif triggerType == 'item' and trigger.Item == 'custom' then
            if not trigger.ItemID then
                warnings[#warnings + 1] = format(L['Trigger %d: no item ID.'], i)
            elseif not GetItemInfoInstant(trigger.ItemID) then
                warnings[#warnings + 1] = format(L['Trigger %d: item ID %d does not exist.'], i, trigger.ItemID)
            end
        end
    end

    local textIndex = 0
    for _, element in ipairs(display.SubRegions or {}) do
        if element.type == 'text' then
            textIndex = textIndex + 1
            for source in (element.Text or ''):gmatch('%%(%d+)%.[pts]') do
                local n = tonumber(source)
                if not triggers[n] then warnings[#warnings + 1] = format(L['Text %d reads trigger %d, which does not exist.'], textIndex, n) end
            end
        end
    end
    return warnings
end

---The aura spell IDs a trigger watches: a Cooldown Manager entry's spell and its linked spells, or a custom list.
---@param trigger table
---@return table<number, true>? spellIDs
function CDM:GetAuraSpellIDs(trigger)
    local ids = {}
    if trigger.Source == 'custom' then
        for _, spellID in ipairs(trigger.SpellIDs or {}) do ids[spellID] = true end
    else
        local info = trigger.CooldownID and self.Catalogue:GetEntry(trigger.CooldownID)
        if info then
            if info.spellID then ids[info.spellID] = true end
            if info.overrideSpellID then ids[info.overrideSpellID] = true end
            for _, linked in ipairs(info.linkedSpellIDs or {}) do ids[linked] = true end
        elseif trigger.SpellID then
            ids[trigger.SpellID] = true
        end
    end
    if next(ids) == nil then return nil end
    return ids
end

---What an aura slot is configured for, so an unchanged trigger skips the out-of-combat rebuild.
---@param trigger table
---@param spellIDs table<number, true>
---@return string
function AuraKey(trigger, spellIDs)
    local ids = {}
    for spellID in pairs(spellIDs) do ids[#ids + 1] = spellID end
    tsort(ids)
    return tconcat(ids, ',') .. '|' .. tostring(trigger.Unit) .. '|' .. tostring(trigger.OwnOnly)
end

---@param layer CDMLayer
---@param display table
---@param index number
local function WatchRange(layer, display, index)
    local spellID = layer.spellID
    if not spellID or rangeState[spellID] ~= nil or not CDM:ConditionsUse(display, index, 'inRange') then return end
    EnableSpellRangeCheck(spellID, true)
    rangeState[spellID] = IsSpellInRange(spellID) ~= false
end

---Resolve every trigger of an icon and start watching what they need.
---@param frame CDMIcon
---@param display table
function CDM:ResolveTriggers(frame, display)
    self:UnwatchIcon(frame.id)
    for i, trigger in ipairs(display.Triggers) do
        local layer = frame.layers[i]
        local triggerType = self.TriggerTypes[trigger.Type]
        local secret = triggerType ~= nil and triggerType.Secret == true
        layer.Icon:SetShown(not secret and not layer.isText and not (layer.isBar and not frame.style.IconShow))
        if layer.isBar then layer.Bar:SetShown(not secret) end -- an aura bar draws inside its aura button
        layer.Cooldown:SetShown(not secret)
        layer.textHost:SetShown(not secret)
        layer.borderHost:SetShown(not secret)
        if not secret then self:ReleaseAuraLayer(layer) end
        if triggerType then triggerType.Resolve(layer, trigger) end
        if trigger.Type == 'spell' then WatchRange(layer, display, i) end
    end
end

---Re-resolve only the spell and timer triggers built on `baseSpellID`, all of them when nil; an override never changes what loads.
---@param baseSpellID number?
function CDM:ResolveOverrides(baseSpellID)
    local ids = baseSpellID and spellIndex[baseSpellID] or self.icons
    for id in pairs(ids) do
        local frame, display = self.icons[id], self:Get(id)
        if frame and display then
            local changed = false
            for i, trigger in ipairs(display.Triggers) do
                if (trigger.Type == 'spell' or trigger.Type == 'timer') and (not baseSpellID or trigger.SpellID == baseSpellID) then
                    local layer = frame.layers[i]
                    local before = layer.spellID
                    self.TriggerTypes[trigger.Type].Resolve(layer, trigger)
                    if trigger.Type == 'spell' then WatchRange(layer, display, i) end
                    changed = changed or layer.spellID ~= before
                end
            end
            if changed then self:UpdateIcon(id) end
        end
    end
end

---WeakAuras' trigger combination: Any or All triggers activate the icon, and it shows the first active
---trigger's layer or the one Dynamic Information pins. An aura layer shows itself while its aura is up, so
---aura triggers can't count toward All; an overlay stays over whichever layer shows.
---@param frame CDMIcon
---@param display table
function CDM:SelectLayer(frame, display)
    local triggers = display.Triggers
    local requireAll = display.Activation == 'all' and not self.previewing -- WeakAuras ignores the combination while editing
    local first, blocked, standby = nil, false, nil
    for i, trigger in ipairs(triggers) do
        local triggerType = self.TriggerTypes[trigger.Type]
        if not (triggerType and triggerType.Secret) then
            if triggerType and triggerType.IsActive(frame.layers[i], trigger) then
                first = first or i
            else
                if requireAll then blocked = true end
                if not standby and triggerType and triggerType.IsStandby and triggerType.IsStandby(frame.layers[i], trigger) then standby = i end
            end
        end
    end
    if blocked then first = nil end
    -- Hidden but ready to show: a condition's Show Display brings it up when nothing else is active.
    frame.standbyLayer = not blocked and standby and frame.layers[standby] or nil

    local pin = display.DynamicTrigger
    local pinType = pin and triggers[pin] and self.TriggerTypes[triggers[pin].Type]
    if not pinType then pin = nil end
    local pinSecret = pinType and pinType.Secret == true
    local pinned = pin ~= nil and (first ~= nil or pinSecret)

    local maybeAura, placeholder = false, false
    for i, trigger in ipairs(triggers) do
        local triggerType = self.TriggerTypes[trigger.Type]
        local secret = triggerType ~= nil and triggerType.Secret == true
        local show
        if blocked then
            show = false
        elseif trigger.Type == 'auraoverlay' then
            show = true
        elseif pinned then
            show = i == pin
        elseif secret then
            show = first == nil or i < first -- above whatever is active below
        else
            show = i == first
        end
        if secret and show then maybeAura = true end
        if secret and show and trigger.Placeholder and trigger.Type == 'aura' then placeholder = true end
        frame.layers[i]:SetShown(show)
    end
    frame.placeholder = placeholder

    if pinned then
        frame.activeLayer = not pinSecret and frame.layers[pin] or nil
    else
        frame.activeLayer = first and frame.layers[first] or nil
    end
    frame.hasActive = frame.activeLayer ~= nil or maybeAura
end

---An icon shows while it's loaded and a trigger is active, as in WeakAuras; in a dynamic group a hidden
---one frees its slot. Previewed icons show regardless, so the options page can edit them.
---@param id string
---@param frame CDMIcon
function CDM:ApplyVisibility(id, frame)
    local visible = frame.shown and (self.previewing or (frame.hasActive and not frame.forceHidden)) or false
    local group = frame.groupId and self.containers[frame.groupId]
    if group and group.isChain then
        ---@cast group CDMChainGroup
        local logic = frame.activeLayer ~= nil or frame.placeholder -- a placeholder keeps its slot open while the aura is missing
        group:SetChildVisible(id, frame.shown == true, frame.shown == true and (self.previewing or (logic and not frame.forceHidden)))
        return
    end
    ---@cast group NRSKNUI.DynamicGroup?
    if group then
        if visible then group:ActivateChild(id) else group:DeactivateChild(id) end
    else
        frame:SetShown(visible)
    end
end

---@param id string
function CDM:UpdateIcon(id)
    local frame = self.icons[id]
    local display = self:Get(id)
    if not (frame and display and frame.shown) then return end

    for i, trigger in ipairs(display.Triggers) do
        local triggerType = self.TriggerTypes[trigger.Type]
        if triggerType then triggerType.Update(frame.layers[i], frame.style, trigger) end
        -- Conditions put their own over it after; an aura layer's icon is only its preview or placeholder, set by Update.
        if not (triggerType and triggerType.Secret) then frame.layers[i].Icon:SetDesaturated(frame.style.Desaturate == true) end
    end
    -- A %N.p text reads a trigger that may have updated after its own.
    for i = 1, #display.Triggers do
        local layer = frame.layers[i]
        if layer.sourced or layer.auraSourced then self:UpdateTexts(layer) end
    end
    self:SelectLayer(frame, display)
    self:EvaluateConditions(id, frame, display)
    self:ApplyVisibility(id, frame)
end

---@param spellID number?
local function UpdateWatchers(spellID)
    local watchers = spellID and spellIndex[spellID]
    if not watchers then return end
    for id in pairs(watchers) do CDM:UpdateIcon(id) end
end

local function UpdateAll()
    for id in pairs(CDM.icons) do CDM:UpdateIcon(id) end
end

local function UpdateItems()
    for id in pairs(itemWatchers) do CDM:UpdateIcon(id) end
end

-- A swapped trinket or a bag change can change which item a trigger shows, and whether it loads at all.
local function ResolveItems()
    local itemType = CDM.TriggerTypes.item
    for id in pairs(itemWatchers) do
        local frame, display = CDM.icons[id], CDM:Get(id)
        if frame and display then
            for i, trigger in ipairs(display.Triggers) do
                if trigger.Type == 'item' then itemType.Resolve(frame.layers[i], trigger) end
            end
        end
    end
    CDM:RefreshLoad()
end

local resolveAllFrame = CreateFrame('Frame')
resolveAllFrame:NUISetScheduledUpdate(function() CDM:ResolveAll() end)

-- isOnGCD is only trustworthy inside the SPELL_UPDATE_COOLDOWN handler (SpellSharedDocumentation.lua, live),
-- so cooldown updates run in the handler rather than being coalesced to the next frame.
local handlers = {
    SPELL_UPDATE_COOLDOWN = function(spellID, baseSpellID, _, startRecoveryCategory)
        inCooldownEvent = true
        if not spellID or startRecoveryCategory == GLOBAL_RECOVERY_CATEGORY then
            if startRecoveryCategory == GLOBAL_RECOVERY_CATEGORY then gcdCount = gcdCount + 1 end
            UpdateAll()
        else
            UpdateWatchers(spellID)
            if baseSpellID ~= spellID then UpdateWatchers(baseSpellID) end
        end
        inCooldownEvent = false
    end,
    SPELL_UPDATE_CHARGES = UpdateAll,
    SPELL_UPDATE_USES = UpdateAll,
    PLAYER_REGEN_DISABLED = function()
        CDM.inCombat = true
        UpdateAll()
    end,
    PLAYER_REGEN_ENABLED = function()
        CDM.inCombat = false
        UpdateAll()
    end,
    PLAYER_TARGET_CHANGED = UpdateAll,
    GROUP_ROSTER_UPDATE = UpdateAll,
    SPELL_UPDATE_USABLE = UpdateAll,
    SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = UpdateWatchers,
    SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = UpdateWatchers,
    SPELL_RANGE_CHECK_UPDATE = function(spellID, inRange, checksRange)
        if rangeState[spellID] == nil then return end
        rangeState[spellID] = not checksRange or inRange == true
        UpdateWatchers(spellID)
    end,
    BAG_UPDATE_COOLDOWN = UpdateItems,
    BAG_UPDATE_DELAYED = ResolveItems,
    PLAYER_EQUIPMENT_CHANGED = ResolveItems,
    SPELL_UPDATE_ICON = function(spellID) CDM:ResolveOverrides(spellID) end,
    COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED = function(baseSpellID) CDM:ResolveOverrides(baseSpellID) end,
    SPELLS_CHANGED = function() resolveAllFrame:NUIScheduleUpdate() end,
}

local eventFrame = CreateFrame('Frame')
eventFrame:SetScript('OnEvent', function(_, event, ...) handlers[event](...) end)

---@param layer CDMLayer
local function StartTimer(layer)
    local length = layer.timerLength
    if not (length and length > 0) then return end
    layer.timerEnd = GetTime() + length
    if layer.timerTicker then layer.timerTicker:Cancel() end
    layer.timerTicker = NewTimer(length, function()
        layer.timerTicker = nil
        if layer.owner.id then CDM:UpdateIcon(layer.owner.id) end
    end)
    if layer.owner.id then CDM:UpdateIcon(layer.owner.id) end
end

-- A whole-resource tick only moves the bar and its texts; a split bar's Recharging condition moves too.
local powerFrame = CreateFrame('Frame')
powerFrame:SetScript('OnEvent', function(_, event)
    local powerType = CDM.TriggerTypes.power
    for layer, trigger in pairs(powerLayers) do
        if layer.owner.shown then
            if event ~= 'UNIT_POWER_FREQUENT' and event ~= 'RUNE_POWER_UPDATE' then powerType.Resolve(layer, trigger) end
            if (layer.pipCount or 0) > 0 then
                CDM:UpdateIcon(layer.owner.id)
            else
                powerType.Update(layer, layer.owner.style, trigger)
            end
        end
    end
end)

-- The player's own casts are normally not secret; one that is can't be matched, so it is skipped.
local castFrame = CreateFrame('Frame')
castFrame:SetScript('OnEvent', function(_, _, _, _, spellID)
    if NRSKNUI:IsSecretValue(spellID) then return end
    local layers = timerIndex[spellID]
    if not layers then return end
    for layer in pairs(layers) do StartTimer(layer) end
end)

function CDM:RegisterTriggerEvents()
    self.inCombat = InCombatLockdown() -- a reload mid-fight misses the REGEN_DISABLED edge
    for event in pairs(handlers) do eventFrame:RegisterEvent(event) end
    castFrame:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player')
    for _, event in ipairs({ 'UNIT_POWER_FREQUENT', 'UNIT_MAXPOWER', 'UNIT_DISPLAYPOWER' }) do
        powerFrame:RegisterUnitEvent(event, 'player')
    end
    powerFrame:RegisterEvent('RUNE_POWER_UPDATE')
    for _, triggerType in pairs(self.TriggerTypes) do
        if triggerType.RegisterEvents then triggerType.RegisterEvents() end
    end
end

function CDM:UnregisterTriggerEvents()
    eventFrame:UnregisterAllEvents()
    castFrame:UnregisterAllEvents()
    powerFrame:UnregisterAllEvents()
    for _, triggerType in pairs(self.TriggerTypes) do
        if triggerType.UnregisterEvents then triggerType.UnregisterEvents() end
    end
end

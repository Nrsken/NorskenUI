---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local pairs, ipairs = pairs, ipairs
local CreateFrame = CreateFrame
local GetTime = GetTime
local NewTimer = C_Timer.NewTimer
local UnitPower, UnitPowerMax, UnitPowerMissing, UnitPowerType = UnitPower, UnitPowerMax, UnitPowerMissing, UnitPowerType
local UnitPowerPercent = UnitPowerPercent
local GetRuneCooldown = GetRuneCooldown
local UnitPartialPower, UnitPowerDisplayMod = UnitPartialPower, UnitPowerDisplayMod
local GetPowerRegenForPowerType = GetPowerRegenForPowerType
local huge = math.huge
local GetSpecialization, GetSpecializationInfo = GetSpecialization, GetSpecializationInfo

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

    -- The player's power; the values only ever reach widgets, so a restricted (secret) one still draws.
CDM.TriggerTypes.power = {
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
}

---@param trigger table
---@return string? name
CDM.TriggerTypes.power.Name = function(trigger)
    return POWER_NAMES[trigger.PowerType or 'primary']
end

---@return number? texture
CDM.TriggerTypes.power.Texture = function()
    local specIndex = GetSpecialization()
    return specIndex and select(4, GetSpecializationInfo(specIndex))
end

---@param id string
CDM.TriggerTypes.power.Unwatch = function(id)
    for layer in pairs(powerLayers) do
        if layer.owner.id == id then powerLayers[layer] = nil end
    end
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

CDM.TriggerTypes.power.RegisterEvents = function()
    for _, event in ipairs({ 'UNIT_POWER_FREQUENT', 'UNIT_MAXPOWER', 'UNIT_DISPLAYPOWER' }) do
        powerFrame:RegisterUnitEvent(event, 'player')
    end
    powerFrame:RegisterEvent('RUNE_POWER_UPDATE')
end

CDM.TriggerTypes.power.UnregisterEvents = function()
    powerFrame:UnregisterAllEvents()
end

-- Conditions --

-- The value can be secret, so nothing compares it; a split bar's Recharging is plain, and per rune for Bar Color.
CDM.ConditionChecks.power = {
    active     = { type = 'bool', get = function(layer, trigger) return CDM.TriggerTypes.power.IsActive(layer, trigger) end },
    recharging = {
        type = 'bool',
        get = function(layer, _, pip)
            if pip then return pip.recharging == true end
            return layer.state.recharging == true
        end,
    },
    waiting = {
        type = 'bool',
        get = function(layer, _, pip)
            if pip then return pip.waiting == true end
            return layer.state.waiting == true
        end,
    },
}

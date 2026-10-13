---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

local pairs, ipairs = pairs, ipairs
local next = next
local format = string.format
local CreateFrame = CreateFrame
local GetSpellTexture = C_Spell.GetSpellTexture
local GetOverrideSpell = C_Spell.GetOverrideSpell
local IsSpellKnown = C_SpellBook.IsSpellKnown
local CreateDuration = C_DurationUtil.CreateDuration
local GetTime = GetTime
local NewTimer = C_Timer.NewTimer

local IsPreviewing, PreviewDuration = CDM.IsPreviewingLayer, CDM.PreviewDuration

local timerIndex = {} ---@type table<number, table<CDMLayer, true>> cast spellID -> timer layers it starts

    -- A fixed-length timer started by the player's own cast, for spells with no aura to follow.
CDM.TriggerTypes.timer = {
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
}

---@param i number
---@param trigger table
---@param warnings string[]
CDM.TriggerTypes.timer.Warnings = function(i, trigger, warnings)
    if trigger.SpellID then
        CDM:WarnUnknownSpell(warnings, i, trigger.SpellID)
    else
        warnings[#warnings + 1] = format(L['Trigger %d: no spell chosen.'], i)
    end
end

---@param id string
CDM.TriggerTypes.timer.Unwatch = function(id)
    for spellID, layers in pairs(timerIndex) do
        for layer in pairs(layers) do
            if layer.owner.id == id then layers[layer] = nil end
        end
        if not next(layers) then timerIndex[spellID] = nil end
    end
end

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

-- The player's own casts are normally not secret; one that is can't be matched, so it is skipped.
local castFrame = CreateFrame('Frame')
castFrame:SetScript('OnEvent', function(_, _, _, _, spellID)
    if NRSKNUI:IsSecretValue(spellID) then return end
    local layers = timerIndex[spellID]
    if not layers then return end
    for layer in pairs(layers) do StartTimer(layer) end
end)

CDM.TriggerTypes.timer.RegisterEvents = function()
    castFrame:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player')
end

CDM.TriggerTypes.timer.UnregisterEvents = function()
    castFrame:UnregisterAllEvents()
end

-- Conditions --

CDM.ConditionChecks.timer = {
    active    = { type = 'bool', get = function(layer, trigger) return CDM.TriggerTypes.timer.IsActive(layer, trigger) end },
    remaining = { type = 'number', get = function(layer) return layer.endTime and layer.endTime - GetTime() or 0 end },
}

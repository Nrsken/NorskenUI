---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local IsPreviewing = CDM.IsPreviewingLayer
local PreviewDuration = CDM.PreviewDuration
local L = NRSKNUI.Libs.AL

local pairs, ipairs = pairs, ipairs
local CreateFrame = CreateFrame
local format = string.format
local GetTime = GetTime
local next = next

local CreateDuration = C_DurationUtil and C_DurationUtil.CreateDuration
local IsSpellKnown = C_SpellBook and C_SpellBook.IsSpellKnown
local GetOverrideSpell = C_Spell and C_Spell.GetOverrideSpell
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture
local NewTimer = C_Timer and C_Timer.NewTimer

local timerIndex = {} ---@type table<number, table<CDMLayer, true>> cast spellID -> timer layers it starts

--[[
Cast Timer triggers: a fixed-length timer started by the player's own cast, for spells with no aura to follow.
]]

-- Trigger --

CDM.TriggerTypes.timer = {
    ---@param trigger table
    ---@return boolean
    IsKnown = function(trigger)
        local spellID = trigger.SpellID
        if not spellID then return false end

        return IsSpellKnown(spellID) or IsSpellKnown(GetOverrideSpell(spellID) or spellID) -- a talent-replaced spell is only known as its override
    end,

    ---Which casts start this layer's timer and its icon.
    ---@param layer CDMLayer
    ---@param trigger table
    Resolve = function(layer, trigger)
        local base = trigger.SpellID
        local spellID = base and not trigger.IgnoreOverride and GetOverrideSpell(base) or base

        -- An override swap re-resolves without Unwatch, so the old override would still start the timer.
        for _, oldID in ipairs(layer.castIDs or {}) do
            local layers = timerIndex[oldID]
            if layers then
                layers[layer] = nil
                if not next(layers) then
                    timerIndex[oldID] = nil
                end
            end
        end

        layer.spellID, layer.baseSpellID = spellID, base
        layer.timerLength = trigger.Duration

        -- Casting the base spell, its override or one of the extra spells starts the timer.
        local castIDs = {}
        if base then
            castIDs[1], castIDs[2] = base, spellID
            for _, extraID in ipairs(trigger.AlsoSpellIDs or {}) do
                castIDs[#castIDs + 1] = extraID
            end
        end
        for _, castID in ipairs(castIDs) do
            timerIndex[castID] = timerIndex[castID] or {}
            timerIndex[castID][layer] = true
        end
        layer.castIDs = castIDs

        CDM:WatchSpell(base, layer.owner.id) -- ResolveOverrides finds the displays to re-resolve through the spell index
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
            layer.timerDuration:SetTimeFromStart(0, 0) -- texts keep counting the last duration they got, so an ended timer hands them a zero one
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

---Warning text for Information tab's problem list.
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
            if layer.owner.id == id then
                layers[layer] = nil
            end
        end

        if not next(layers) then
            timerIndex[spellID] = nil
        end
    end
end

-- Events --

---@param layer CDMLayer
---@param endTime number
local function RunTimer(layer, endTime)
    layer.timerEnd = endTime

    -- Recasting restarts the timer instead of stacking a second one.
    if layer.timerTicker then
        layer.timerTicker:Cancel()
    end

    -- No event fires when our own timer runs out, so the layer is woken up to go inactive.
    layer.timerTicker = NewTimer(endTime - GetTime(), function()
        layer.timerTicker = nil
        CDM:UpdateLayer(layer)
    end)

    CDM:UpdateLayer(layer)
end

local castFrame ---@type Frame?

local function OnCast(spellID)
    if NRSKNUI:IsSecretValue(spellID) then return end -- a secret cast can't be matched, so it's skipped
    local layers = timerIndex[spellID]
    if not layers then return end -- every cast lands here, nearly all of them on spells no timer watches

    for layer in pairs(layers) do
        local length = layer.timerLength
        if length and length > 0 then
            RunTimer(layer, GetTime() + length)
        end
    end
end

CDM.TriggerTypes.timer.RegisterEvents = function()
    if not castFrame then
        castFrame = CreateFrame('Frame')
        castFrame:SetScript('OnEvent', function(_, _, _, _, spellID) OnCast(spellID) end)
    end

    castFrame:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player')
end

CDM.TriggerTypes.timer.UnregisterEvents = function()
    castFrame:UnregisterAllEvents()
end

-- Conditions --

CDM.ConditionChecks.timer = {
    active    = { type = 'bool', get = function(layer) return CDM.TriggerTypes.timer.IsActive(layer) end },
    remaining = { type = 'number', get = function(layer) return layer.endTime and layer.endTime - GetTime() or 0 end },
}

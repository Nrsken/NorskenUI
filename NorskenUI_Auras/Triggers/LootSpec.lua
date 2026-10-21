---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

--[[
The Loot Specialization trigger: the spec's icon, its name as %n, active while it passes the spec and Current Specialization filters.
Loot spec 0 is Current Specialization, which follows the active spec (EncounterJournalLinkButtonMixin:OnClick, GroupLootFrame.lua).
]]

local GetSpecializationInfoByID = GetSpecializationInfoByID
local GetLootSpecialization = GetLootSpecialization
local LoadConditions = NRSKNUI.LoadConditions
local CreateFrame = CreateFrame
local select = select
local ipairs = ipairs

-- Trigger --

---@return number? specID nil before the character has a specialization
---@return boolean isCurrentSpec
local function GetLootSpec()
    local currentID = LoadConditions:GetSpecID()
    local specID = GetLootSpecialization()
    if specID == 0 then
        specID = currentID
    end
    return specID, specID == currentID
end

CDM.TriggerTypes.lootSpec = {
    IsKnown = function() return true end,

    ---@param layer CDMLayer
    Resolve = function(layer)
        layer.spellID, layer.baseSpellID = nil, nil
    end,

    ---@param layer CDMLayer
    Update = function(layer)
        local specID, isCurrentSpec = GetLootSpec()
        local _, name, icon
        if specID then
            _, name, _, icon = GetSpecializationInfoByID(specID)
        end
        layer.state.lootSpecID, layer.state.isCurrentSpec = specID, isCurrentSpec
        CDM:SetIconTexture(layer, icon)
        CDM:SetLayerName(layer, name or '')
        CDM:UpdateTexts(layer)
    end,

    ---@param layer CDMLayer
    ---@param trigger table
    ---@return boolean
    IsActive = function(layer, trigger)
        if CDM.IsPreviewingLayer(layer) then return true end
        if trigger.CurrentSpec and (trigger.CurrentSpec == 'current') ~= layer.state.isCurrentSpec then return false end

        -- no spec picked is any spec
        local specIDs = trigger.SpecIDs
        if not (specIDs and specIDs[1]) then return true end
        for _, specID in ipairs(specIDs) do
            if specID == layer.state.lootSpecID then return true end
        end
        return false
    end,

    ---@return string? name
    Name = function()
        local specID = GetLootSpec()
        return specID and (select(2, GetSpecializationInfoByID(specID)))
    end,

    ---@return number? icon
    Texture = function()
        local specID = GetLootSpec()
        return specID and (select(4, GetSpecializationInfoByID(specID)))
    end,
}

-- Events --

local eventFrame ---@type Frame?
local LOOT_SPEC_TYPES = { lootSpec = true }

local function OnLootSpecEvent()
    CDM:UpdateAllTriggers(LOOT_SPEC_TYPES) -- through Settle, so the filters and conditions re-derive
end

CDM.TriggerTypes.lootSpec.RegisterEvents = function()
    if not eventFrame then
        eventFrame = CreateFrame('Frame')
        eventFrame:SetScript('OnEvent', OnLootSpecEvent)
    end

    eventFrame:RegisterEvent('PLAYER_LOOT_SPEC_UPDATED')
    eventFrame:RegisterUnitEvent('PLAYER_SPECIALIZATION_CHANGED', 'player')
end

CDM.TriggerTypes.lootSpec.UnregisterEvents = function()
    eventFrame:UnregisterAllEvents()
end

-- Conditions --

CDM.ConditionChecks.lootSpec = {
    active = { type = 'bool', get = function(layer, trigger) return CDM.TriggerTypes.lootSpec.IsActive(layer, trigger) end },
    isCurrentSpec = { type = 'bool', get = function(layer) return layer.state.isCurrentSpec == true end },
    lootSpecID = { type = 'select', options = 'spec', match = function(specID, layer) return layer.state.lootSpecID == specID end },
}

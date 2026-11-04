---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

--[[
The Prey Hunt trigger: active while a hunt runs, its progress as Cold, Warm, Hot and Final.
Progress only lives on a UI widget and no API names that widget, so it's found by its type (Blizzard_UIWidgetTemplatePreyHuntProgress.lua).
A hunt has no widget outside its zone, so it can be active without a state.
]]

local GetPreyHuntInfo = C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo
local GetPowerBarWidgetSetID = C_UIWidgetManager.GetPowerBarWidgetSetID
local GetAllWidgetsBySetID = C_UIWidgetManager.GetAllWidgetsBySetID
local GetActivePreyQuest = C_QuestLog.GetActivePreyQuest
local GetTitleForQuestID = C_QuestLog.GetTitleForQuestID
local CreateFrame = CreateFrame
local ipairs, pairs = ipairs, pairs
local next = next

local PREY_WIDGET = Enum.UIWidgetVisualizationType.PreyHuntProgress
local HIDDEN = Enum.WidgetShownState.Hidden
local PREY_ICON = 'Interface\\Icons\\Ability_Hunter_MarkedForDeath'
local STEPS = 4 -- a bar's fill, nothing returns finer progress than the state

local STATE_NAMES = {
    [Enum.PreyHuntProgressState.Cold] = L['Cold'],
    [Enum.PreyHuntProgressState.Warm] = L['Warm'],
    [Enum.PreyHuntProgressState.Hot] = L['Hot'],
    [Enum.PreyHuntProgressState.Final] = L['Final'],
}

local preyLayers = {} ---@type table<CDMLayer, true>
local hunt = {}       -- what the layers read: questID, title, state, hint
local widgetID        ---@type number?

-- Hunt --

---@return number?
local function FindWidget()
    for _, widget in ipairs(GetAllWidgetsBySetID(GetPowerBarWidgetSetID())) do
        if widget.widgetType == PREY_WIDGET then
            return widget.widgetID
        end
    end
end

---@return boolean changed
local function ReadHunt()
    local questID = GetActivePreyQuest()
    local title = questID and GetTitleForQuestID(questID)
    local info = widgetID and GetPreyHuntInfo(widgetID)
    if info and info.shownState == HIDDEN then
        info = nil
    end

    local state, hint = info and info.progressState, info and info.tooltip
    -- UPDATE_UI_WIDGET repeats with the same values
    if questID == hunt.questID and title == hunt.title and state == hunt.state and hint == hunt.hint then return false end

    hunt.questID, hunt.title, hunt.state, hunt.hint = questID, title, state, hint
    return true
end

---What a trigger's %n reads.
---@param trigger table
---@return string?
local function HuntText(trigger)
    if trigger.Text == 'state' then
        return STATE_NAMES[hunt.state]
    elseif trigger.Text == 'hint' then
        return hunt.hint
    end
    return hunt.title
end

-- Events --

local eventFrame ---@type Frame?
local PREY_TYPES = { prey = true }

local function OnPreyEvent(_, event, widget)
    if event == 'UPDATE_UI_WIDGET' then
        if widget.widgetType ~= PREY_WIDGET then return end
        widgetID = widget.widgetID
    elseif event == 'UPDATE_ALL_UI_WIDGETS' then
        widgetID = FindWidget()
    end

    if ReadHunt() then
        CDM:UpdateAllTriggers(PREY_TYPES)
    end
end

-- RegisterTriggerEvents runs for every trigger type, so these go by the layers in use instead: UPDATE_UI_WIDGET fires for every widget in the world
local function StartWatching()
    if not eventFrame then
        eventFrame = CreateFrame('Frame')
        eventFrame:SetScript('OnEvent', OnPreyEvent)
    end

    eventFrame:RegisterEvent('UPDATE_UI_WIDGET')
    eventFrame:RegisterEvent('UPDATE_ALL_UI_WIDGETS')
    eventFrame:RegisterEvent('QUEST_LOG_UPDATE') -- accept, abandon, turn in and the title loading in
    widgetID = FindWidget()
    ReadHunt()
end

local function StopWatching()
    eventFrame:UnregisterAllEvents()
end

-- Trigger --

CDM.TriggerTypes.prey = {
    IsKnown = function() return true end,

    ---@param layer CDMLayer
    Resolve = function(layer)
        layer.spellID, layer.baseSpellID = nil, nil
        if not next(preyLayers) then
            StartWatching()
        end
        preyLayers[layer] = true
        CDM:SetIconTexture(layer, PREY_ICON)
    end,

    ---@param layer CDMLayer
    ---@param _ table
    ---@param trigger table
    Update = function(layer, _, trigger)
        layer.state.preyState = hunt.state
        CDM:SetLayerName(layer, HuntText(trigger) or (CDM.IsPreviewingLayer(layer) and L['Prey Hunt']) or '')
        CDM:SetLayerValue(layer, hunt.state and hunt.state + 1 or 0, STEPS)
        CDM:UpdateTexts(layer)
    end,

    ---@param layer CDMLayer
    ---@return boolean
    IsActive = function(layer)
        return hunt.questID ~= nil or CDM.IsPreviewingLayer(layer)
    end,

    ---@param id string
    Unwatch = function(id)
        local watching = next(preyLayers) ~= nil
        for layer in pairs(preyLayers) do
            if layer.owner.id == id then
                preyLayers[layer] = nil
            end
        end

        if watching and not next(preyLayers) then
            StopWatching()
        end
    end,

    Name = HuntText,

    ---@return string icon
    Texture = function() return PREY_ICON end,
}

-- Conditions --

CDM.ConditionChecks.prey = {
    active = { type = 'bool', get = function(layer) return CDM.TriggerTypes.prey.IsActive(layer) end },
    inHuntZone = { type = 'bool', get = function(layer) return layer.state.preyState ~= nil end },
    preyState = { type = 'select', options = 'preyState', match = function(state, layer) return layer.state.preyState == state end },
}

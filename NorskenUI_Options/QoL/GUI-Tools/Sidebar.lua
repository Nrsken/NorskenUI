---@class NorskenUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_QoL') then return end
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'tools_section',
    order = 90,
    type = 'header',
    text = L['Tools'],
    defaultExpanded = false,
    items = {
        { id = 'miscVars',     text = L['CVars'] },
        { id = 'cdmStrings',   text = L['CDM Profile Backup'], module = 'CooldownStrings' },
        { id = 'questTracker', text = L['Quest Tracker'],      module = 'QuestTracker' },
    }
})

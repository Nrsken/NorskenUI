---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_QoL') then return end
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'dungeons_section',
    order = 80,
    type = 'header',
    text = L['Dungeons'],
    defaultExpanded = false,
    items = {
        { id = 'dungeonCasts',   text = L['Dungeon Casts'], module = 'DungeonCasts' },
        { id = 'rerollKeystone', text = L['Reroll Keystone'], module = 'RerollKeystone' },
    }
})

GUIFrame:AddSidebarEntry({
    id = 'bwtimers_section',
    order = 90,
    type = 'header',
    text = L['BigWigs Timers'],
    defaultExpanded = false,
    module = 'BigWigsTimers',
    items = {
        { id = 'bwTimersDisplay',  text = L['Display'] },
        { id = 'bwTimersDungeons', text = L['Dungeons'] },
        { id = 'bwTimersRaids',    text = L['Raids'] },
    }
})

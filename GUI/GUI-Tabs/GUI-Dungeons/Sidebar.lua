---@class NRSKNUI
local NRSKNUI = select(2, ...)
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
        { id = 'dungeonCasts',   text = L['Dungeon Casts'] },
        { id = 'rerollKeystone', text = L['Reroll Keystone'] },
    }
})

GUIFrame:AddSidebarEntry({
    id = 'bwtimers_section',
    order = 90,
    type = 'header',
    text = L['BigWigs Timers'],
    defaultExpanded = false,
    items = {
        { id = 'bwTimers',         text = L['General'] },
        { id = 'bwTimersBars',     text = L['Bar Settings'] },
        { id = 'bwTimersTexts',    text = L['Text Settings'] },
        { id = 'bwTimersDungeons', text = L['Dungeons'] },
        { id = 'bwTimersRaids',    text = L['Raids'] },
    }
})

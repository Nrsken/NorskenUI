---@class NorskenUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Combat') then return end
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'bwtimers_section',
    order = 160,
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

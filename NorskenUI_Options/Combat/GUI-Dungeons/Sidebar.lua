---@class NorskenUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Combat') then return end
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'dungeons_section',
    order = 150,
    type = 'header',
    text = L['Dungeons'],
    defaultExpanded = false,
    items = {
        { id = 'dungeonCasts',   text = L['Dungeon Casts'], module = 'DungeonCasts' },
        { id = 'rerollKeystone', text = L['Reroll Keystone'], module = 'RerollKeystone' },
    }
})

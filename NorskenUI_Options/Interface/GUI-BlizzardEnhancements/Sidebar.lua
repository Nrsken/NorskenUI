---@class NorskenUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Interface') then return end
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'blizzardEnhancements_section',
    order = 110,
    type = 'header',
    text = L['Blizzard Enhancements'],
    defaultExpanded = false,
    items = {
        { id = 'vendor',         text = L['Vendor'],          module = 'Vendor' },
        { id = 'characterPanel', text = L['Character Panel'], module = 'CharacterPanel' },
        { id = 'groupFinder',    text = L['Group Finder'],    module = 'GroupFinder' },
    }
})

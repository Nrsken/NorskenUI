---@class NorskenUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Combat') then return end
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'combat_section',
    order = 120,
    type = 'header',
    text = L['Combat'],
    defaultExpanded = false,
    items = {
        { id = 'combatCross',   text = L['Combat Cross'],   module = 'CombatCross' },
        { id = 'combatMessage', text = L['Combat Message'], module = 'CombatMessage' },
    }
})

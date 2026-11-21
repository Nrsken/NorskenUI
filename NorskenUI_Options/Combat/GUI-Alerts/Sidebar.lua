---@class NorskenUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Combat') then return end
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'alerts_section',
    order = 130,
    type = 'header',
    text = L['Alerts'],
    defaultExpanded = false,
    items = {
        { id = 'combatRes',  text = L['Combat Res Tracker'], module = 'CombatRes' },
        { id = 'spellAlert', text = L['Spell Alerts'],       module = 'SpellAlert' },
    }
})

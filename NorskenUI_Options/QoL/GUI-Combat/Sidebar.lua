---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_QoL') then return end
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'combat_section',
    order = 50,
    type = 'header',
    text = L['Combat Util'],
    defaultExpanded = false,
    items = {
        { id = 'combatTimer',   text = L['Combat Timer'],       module = 'CombatTimer' },
        { id = 'combatCross',   text = L['Combat Cross'],       module = 'CombatCross' },
        { id = 'combatRes',     text = L['Combat Res Tracker'], module = 'CombatRes' },
        { id = 'combatMessage', text = L['Combat Message'],     module = 'CombatMessage' },
        { id = 'cursorCircle',  text = L['Cursor Circle'],      module = 'CursorCircle' },
        { id = 'focusCastbar',  text = L['Focus Castbar'],      module = 'FocusCastbar' },
        { id = 'rangeChecker',  text = L['Range Checker'],      module = 'RangeChecker' },
        { id = 'potionReady',   text = L['Potion Ready'],       module = 'PotionReady' },
    }
})

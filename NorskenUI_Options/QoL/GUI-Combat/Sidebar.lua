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
        { id = 'combatTimer',   text = L['Combat Timer'] },
        { id = 'combatCross',   text = L['Combat Cross'] },
        { id = 'combatRes',     text = L['Combat Res Tracker'] },
        { id = 'combatMessage', text = L['Combat Message'] },
        { id = 'cursorCircle',  text = L['Cursor Circle'] },
        { id = 'focusCastbar',  text = L['Focus Castbar'] },
        { id = 'rangeChecker',  text = L['Range Checker'] },
        { id = 'potionReady',   text = L['Potion Ready'] },
    }
})

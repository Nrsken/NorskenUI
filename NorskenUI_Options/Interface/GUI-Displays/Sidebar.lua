---@class NorskenUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Interface') then return end
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'displays_section',
    order = 100,
    type = 'header',
    text = L['Displays'],
    defaultExpanded = false,
    items = {
        { id = 'XPBar',          text = L['XP Bar'],            module = 'XPBar' },
        { id = 'recuperate',     text = L['Recuperate Button'], module = 'Recuperate' },
        { id = 'skyRiding',      text = L['Skyriding UI'],      module = 'SkyRiding' },
        { id = 'buffsDebuffs',   text = L['Buffs & Debuffs'],   module = 'PlayerAuras' },
        { id = 'combatTimer',    text = L['Combat Timer'],      module = 'CombatTimer' },
        { id = 'cursorCircle',   text = L['Cursor Circle'],     module = 'CursorCircle' },
        { id = 'focusCastbar',   text = L['Focus Castbar'],     module = 'FocusCastbar' },
        { id = 'rangeChecker',   text = L['Range Checker'],     module = 'RangeChecker' },
    }
})

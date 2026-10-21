---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'missingBuffs_section',
    order = 110,
    type = 'header',
    text = L['Missing Buffs'],
    defaultExpanded = false,
    items = {
        { id = 'missingBuffsRaid', text = L['Buffs'] },
        { id = 'missingBuffsTargeted', text = L['Targeted Buffs'] },
    }
})

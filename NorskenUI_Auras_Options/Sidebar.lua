---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'cooldownManager',
    order = 20,
    type = 'item',
    text = L['Cooldown & Aura Manager'],
})

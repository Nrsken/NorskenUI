---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'class_section',
    order = 100,
    type = 'header',
    text = L['Class Utility'],
    defaultExpanded = false,
    items = {
        { id = 'petTexts', text = L['Pet Status Texts'] },
        { id = 'gateway',  text = L['Gateway Alert'] },
    }
})

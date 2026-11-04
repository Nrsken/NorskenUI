---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_QoL') then return end
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
        { id = 'petTexts', text = L['Pet Status Texts'], module = 'PetTexts' },
        { id = 'gateway',  text = L['Gateway Alert'], module = 'Gateway' },
    }
})

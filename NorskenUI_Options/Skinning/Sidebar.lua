---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Skinning') then return end
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'skinning_section',
    order = 70,
    type = 'header',
    text = L['Skinning'],
    defaultExpanded = false,
    items = {
        { id = 'actionBars',        text = L['Action Bars'] },
        { id = 'blizzardMouseover', text = L['Blizzard Mouseover'], elvUIDisabled = true },
        { id = 'buffsDebuffs',      text = L['Buffs & Debuffs'] },
        { id = 'chat',              text = L['Chat'] },
        { id = 'detailsBackdrop',   text = L['Details Backdrop'] },
        { id = 'frameSkins',        text = L['Frames'],             elvUIDisabled = true },
        { id = 'microMenu',         text = L['Micro Menu'] },
        { id = 'minimap',           text = L['Minimap'] },
        { id = 'objectiveTracker',  text = L['Objective Tracker'],  elvUIDisabled = true },
        { id = 'tooltip',           text = L['Tooltips'] },
    }
})

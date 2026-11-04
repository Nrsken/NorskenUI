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
        { id = 'actionBars',        text = L['Action Bars'], module = 'ActionBars' },
        { id = 'blizzardFonts',     text = L['Blizzard UI Font'], module = 'BlizzardMessages' },
        { id = 'blizzardMouseover', text = L['Blizzard Mouseover'], elvUIDisabled = true, module = 'BlizzardMouseover' },
        { id = 'buffsDebuffs',      text = L['Buffs & Debuffs'], module = 'PlayerAuras' },
        { id = 'chat',              text = L['Chat'], module = 'Chatv2' },
        { id = 'detailsBackdrop',   text = L['Details Backdrop'], module = 'DetailsBackdrop' },
        { id = 'frameSkins',        text = L['Frames'],             elvUIDisabled = true, module = 'Skinning' },
        { id = 'microMenu',         text = L['Micro Menu'], module = 'MicroMenu' },
        { id = 'minimap',           text = L['Minimap'], module = 'Minimap' },
        { id = 'objectiveTracker',  text = L['Objective Tracker'],  elvUIDisabled = true, module = 'BlizzObjectiveTracker' },
        { id = 'tooltip',           text = L['Tooltips'], module = 'Tooltips' },
    }
})

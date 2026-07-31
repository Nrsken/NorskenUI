---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

--[[
#Sidebar Registry Rules

* id:               Must be unique across all entries in the sidebar and use moduleType_id format for module entries.
* type:             Can be either 'header' or 'item'. Headers can contain child items, while items are leaf nodes.
* text:             The display text for the sidebar entry.

* 'header' entries can have the following optional properties:
* defaultExpanded:  Optional boolean for headers to indicate if they should be expanded by default.
* items:            Optional array of child entries for headers. Each child must follow the same structure.

]]

GUIFrame.SidebarConfig = {
    systems = {
        {
            id = 'profilePage',
            type = 'item',
            text = L['Profile Settings'],
        },
        {
            id = 'globalPage',
            type = 'item',
            text = L['Global Settings'],
        },
        {
            id = 'globalFonts',
            type = 'item',
            text = L['Font Settings'],
        },
        {
            id = 'aurafilters_section',
            type = 'header',
            text = L['Aura Filters'],
            defaultExpanded = false,
            items = {
                { id = 'filterBuilder',  text = L['Filter Builder'] },
                { id = 'spellIDFilters', text = L['SpellID Filters'] },
            }
        },
        {
            id = 'auras_section',
            type = 'header',
            text = L['Auras'],
            defaultExpanded = false,
            items = {
                { id = 'advancedDebuffs', text = L['Advanced Debuffs'] },
                { id = 'defensives',      text = L['Defensives'] },
                { id = 'standardBuffs',   text = L['Standard Buffs'] },
                { id = 'standardDebuffs', text = L['Standard Debuffs'] },
            }
        },
        {
            id = 'unitframes_section',
            type = 'header',
            text = L['Unit Frames'],
            defaultExpanded = false,
            items = {
                { id = 'unitFramesGeneral',       text = L['General'] },
                { id = 'unitFrames_player',       text = L['Player'] },
                { id = 'unitFrames_target',       text = L['Target'] },
                { id = 'unitFrames_targettarget', text = L['Target of Target'] },
                { id = 'unitFrames_focus',        text = L['Focus'] },
                { id = 'unitFrames_focustarget',  text = L['Focus Target'] },
                { id = 'unitFrames_pet',          text = L['Pet'] },
                { id = 'unitFrames_pettarget',    text = L['Pet Target'] },
                { id = 'unitFrames_boss',         text = L['Boss'] },
            }
        },
        {
            id = 'combat_section',
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
        },
        {
            id = 'qol_section',
            type = 'header',
            text = L['Quality of Life'],
            defaultExpanded = false,
            items = {
                { id = 'XPBar',              text = L['XP Bar'] },
                { id = 'miscVars',           text = L['CVars'] },
                { id = 'auctionHouseFilter', text = L['Auction House Filter'] },
                { id = 'copyAnything',       text = L['Copy Anything'] },
                { id = 'automation',         text = L['Automation'] },
                { id = 'recuperate',         text = L['Recuperate Button'] },
                { id = 'tweaks',             text = L['Tweaks'] },
                { id = 'durabilityUtil',     text = L['Durability Util'] },
            }
        },
        {
            id = 'skinning_section',
            type = 'header',
            text = L['Skinning'],
            defaultExpanded = false,
            items = {
                { id = 'tooltip', text = L['Tooltips'] },
                { id = 'minimap', text = L['Minimap'] },
            }
        },
        {
            id = 'class_section',
            type = 'header',
            text = L['Class Utility'],
            defaultExpanded = false,
            items = {
                { id = 'petTexts', text = L['Pet Status Texts'] },
                { id = 'gateway',  text = L['Gateway Alert'] },
            }
        },
    },
}

-- Hand the config to the window, it builds the sidebar + search box and drives ShowPage on selection.
GUIFrame:SetSidebar(GUIFrame.SidebarConfig.systems, {
    isDisabled = function(entry)
        return entry.elvUIDisabled and NRSKNUI.ShouldNotLoadModule and NRSKNUI:ShouldNotLoadModule() or false
    end,
})

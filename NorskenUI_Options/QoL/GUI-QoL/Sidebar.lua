---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'qol_section',
    order = 60,
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
        { id = 'characterPanel',     text = L['Character Panel'] },
        { id = 'skyRiding',          text = L['Skyriding UI'] },
        { id = 'spellAlert',         text = L['Spell Alerts'] },
        { id = 'cdmStrings',         text = L['CDM Profile Backup'] },
        { id = 'groupFinder',        text = L['Group Finder'] },
        { id = 'questTracker',       text = L['Quest Tracker'] },
    }
})

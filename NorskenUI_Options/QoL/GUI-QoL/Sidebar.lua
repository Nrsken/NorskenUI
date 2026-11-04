---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_QoL') then return end
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
        { id = 'XPBar',              text = L['XP Bar'], module = 'XPBar' },
        { id = 'miscVars',           text = L['CVars'] },
        { id = 'auctionHouseFilter', text = L['Auction House Filter'], module = 'AuctionHouseFilter' },
        { id = 'copyAnything',       text = L['Copy Anything'], module = 'CopyAnything' },
        { id = 'automation',         text = L['Automation'], module = 'Automation' },
        { id = 'recuperate',         text = L['Recuperate Button'], module = 'Recuperate' },
        { id = 'tweaks',             text = L['Tweaks'], module = 'Tweaks' },
        { id = 'durabilityUtil',     text = L['Durability Util'], module = 'Durability' },
        { id = 'characterPanel',     text = L['Character Panel'], module = 'CharacterPanel' },
        { id = 'skyRiding',          text = L['Skyriding UI'], module = 'SkyRiding' },
        { id = 'spellAlert',         text = L['Spell Alerts'], module = 'SpellAlert' },
        { id = 'cdmStrings',         text = L['CDM Profile Backup'], module = 'CooldownStrings' },
        { id = 'groupFinder',        text = L['Group Finder'], module = 'GroupFinder' },
        { id = 'questTracker',       text = L['Quest Tracker'], module = 'QuestTracker' },
    }
})

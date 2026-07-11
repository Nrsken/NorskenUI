---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame

GUIFrame.SidebarConfig = {
    systems = {
        {
            id = "profiles_section",
            type = "header",
            text = "Profiles",
            defaultExpanded = false,
            items = {
                { id = "ProfileSelector",     text = "Profile Selector" },
                { id = "ProfileActions",      text = "Profile Actions" },
                { id = "ProfileImportExport", text = "Import / Export" },
            }
        },
        {
            id = "combat_section",
            type = "header",
            text = "Combat Util",
            defaultExpanded = false,
            items = {
                { id = "combatTimer",   text = "Combat Timer" },
                { id = "combatCross",   text = "Combat Cross" },
                { id = "battleRes",     text = "Combat Res" },
                { id = "combatMessage", text = "Combat Texts" },
                { id = "cursorCircle",  text = "Cursor Circle" },
                { id = "FocusCastbar",  text = "Focus Castbar" },
                { id = "RangeChecker",  text = "Range Checker Text" },
                { id = "TimeSpiral",    text = "Time Spiral" },
                { id = "PotionReady",   text = "Potion Ready" },
            }
        },
        {
            id = "missingBuffs_section",
            type = "header",
            text = "Missing Buffs & Stances",
            defaultExpanded = false,
            items = {
                { id = "missingBuffs",  text = "Missing Buffs" },
                { id = "targetedBuffs", text = "Targeted Buffs" },
                { id = "stanceIcons",   text = "Stance Icons" },
                { id = "stanceTexts",   text = "Stance Texts" },
            }
        },
        {
            id = "buffs_section",
            type = "header",
            text = "Aura Tracking",
            defaultExpanded = false,
            items = {
                { id = "CustomSkin_Buffs",          text = "Default Buffs",             elvUIDisabled = true },
                { id = "CustomSkin_DebuffsDefault", text = "Default Debuffs",           elvUIDisabled = true },
                { id = "CustomSkin_Debuffs",        text = "Advanced Debuffs" },
                { id = "CustomSkin_Externals",      text = "External & Defensive Buffs" },
            }
        },
        {
            id = "class_section",
            type = "header",
            text = "Class Util",
            defaultExpanded = false,
            items = {
                { id = "BurningRush",      text = NRSKNUI:ColorTextByClass("Warlock: Burning Rush", "WARLOCK") },
                { id = "IncarnStacks",     text = NRSKNUI:ColorTextByClass("Guardian Druid: Incarn Stacks", "DRUID") },
                { id = "HuntersMark",      text = NRSKNUI:ColorTextByClass("Hunter: Mark Missing", "HUNTER") },
                { id = "ReckonTracker",    text = NRSKNUI:ColorTextByClass("Dev DH: Reckon Tracker", "DEMONHUNTER") },
                { id = "PetTexts",         text = "Pet Status Texts" },
                { id = "gateway",          text = "Gateway Alert" },
                { id = "TotemTracker",     text = "Totem Tracker" },
                { id = "SpellAlert",       text = "Spell Alert Overlay" },
                { id = "BloodlustTracker", text = "Bloodlust Tracker" },
            }
        },
        {
            id = "qol_section",
            type = "header",
            text = "Quality of Life",
            defaultExpanded = false,
            items = {
                { id = "missingItems",       text = "Missing Items" },
                { id = "MiscVars",           text = "CVar Browser" },
                { id = "Automation",         text = "Automation" },
                { id = "CopyAnything",       text = "Copy Anything" },
                { id = "CooldownStrings",    text = "CDM Profile Strings" },
                { id = "DragonRiding",       text = "Dragon Riding UI" },
                { id = "XPBar",              text = "XP Bar" },
                { id = "Durability",         text = "Durability Util" },
                { id = "AuctionHouseFilter", text = "AH Current Expansion Filter" },
                { id = "Recuperate",         text = "Recuperate Button" },
                { id = "CharacterPanel",     text = "Character Panel Improvements" },
                { id = "DetailsBackdrop",    text = "Details Backdrop" },
            }
        },
        {
            id = "advanced_skinning_section",
            type = "header",
            text = "Advanced Skinning",
            defaultExpanded = false,
            elvUIDisabled = true,
            items = {
                { id = "Chatv2",     text = "Chat" },
                { id = "ActionBars", text = "Action Bars" },
                { id = "Minimap",    text = "Minimap" },
                { id = "MicroMenu",  text = "Micro Menu" },
                { id = "tooltips",   text = "Tooltips" },
            }
        },
        {
            id = "skinning_section",
            type = "header",
            text = "Skinning",
            defaultExpanded = false,
            elvUIDisabled = true,
            items = {
                { id = "UICleanup",           text = "General UI Cleanup" },
                { id = "BlizzardMouseover",   text = "Blizzard Mouseover" },
                { id = "messages",            text = "Blizzard Texts" },
                { id = "BlizzardElementsTab", text = "Blizzard Elements" },
                { id = "BlizzardRM",          text = "Raid Manager" },
                { id = "UIWidgets",           text = "UI Widgets" },
                { id = "Battlenet",           text = "Battlenet Popup" },
            }
        },
        {
            id = "dungeons_section",
            type = "header",
            text = "Dungeon & Party Util",
            defaultExpanded = false,
            items = {
                { id = "InstanceReset",  text = "Instance Reset" },
                { id = "HealerMana",     text = "Healer Mana" },
                { id = "DungeonCasts",   text = "Dungeon Casts" },
                { id = "RerollKeystone", text = "Reroll Keystone" },
            }
        },
        {
            id = "bigwigs_section",
            type = "header",
            text = "BigWigs Timers",
            defaultExpanded = false,
            items = {
                { id = "DT_General",                text = "General" },
                { id = "DT_Bars",                   text = "Bar Settings" },
                { id = "DT_Texts",                  text = "Text Settings" },
                { id = "Dungeon_MagistersTerrace",  text = "Magisters' Terrace" },
                { id = "Dungeon_MaisaraCaverns",    text = "Maisara Caverns" },
                { id = "Dungeon_NexusPointXenas",   text = "Nexus-Point Xenas" },
                { id = "Dungeon_WindrunnerSpire",   text = "Windrunner Spire" },
                { id = "Dungeon_AlgetharAcademy",   text = "Algeth'ar Academy" },
                { id = "Dungeon_PitOfSaron",        text = "Pit of Saron" },
                { id = "Dungeon_SeatOfTriumvirate", text = "Seat of the Triumvirate" },
                { id = "Dungeon_Skyreach",          text = "Skyreach" },
                { id = "Raid_TheDreamrift",         text = "The Dreamrift" },
                { id = "Raid_TheVoidspire",         text = "The Voidspire" },
                { id = "Raid_MarchOnQuelDanas",     text = "March on Quel'Danas" },
            }
        },
        {
            id = "misc_section",
            type = "header",
            text = "Random Utility",
            defaultExpanded = false,
            items = {
                { id = "BenchAlert", text = "Bench Alert" },
                { id = "WayFinder",  text = "Waypoint Finder" },
                --{ id = "TestTab",    text = "Test Tab" },
            }
        },
    },
}

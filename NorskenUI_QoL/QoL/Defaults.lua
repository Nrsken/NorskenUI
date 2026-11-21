---@class NorskenUI
local NRSKNUI = _G.NorskenUI

local CopyAnything = NRSKNUI:GetModule('CopyAnything')
CopyAnything.dbKey = 'Miscellaneous.CopyAnything'
CopyAnything.Defaults = {
    Enabled = true,
    key = "C",
    modifier = "ctrl", -- 'ctrl' | 'shift' | 'alt'
}

local Automation = NRSKNUI:GetModule('Automation')
Automation.dbKey = 'Miscellaneous.Automation'
Automation.Defaults = {
    Enabled = true,
    -- Global override key for all automation (merchant, role check, quests).
    OverrideKey = 'Shift',  -- 'Shift' | 'Alt' | 'Ctrl' | 'Cmd'
    OverrideMode = 'Block', -- 'Block' (hold to skip) | 'Require' (hold to run)
    SkipCinematics = true,
    AutoHideHelptips = true,
    AutoSellJunk = true,
    AutoRepair = true,
    UseGuildFunds = true,
    AutoRoleCheck = true,
    AutoFillDelete = true,
    AutoLoot = true,
    FastLoot = true,
    -- Quest Automation
    AutoCompleteQuest = false,
    AutoQuestGossip = false,
    AutoAcceptRegular = false,
    AutoAcceptDaily = false,
    AutoAcceptWeekly = false,
    AutoAcceptEvent = false,
    AutoBonusRollQuest = false,
    AutoBonusRollMode = 'Gold', -- 'Gold' | 'Marl' | 'Crest'
}

local Tweaks = NRSKNUI:GetModule('Tweaks')
Tweaks.dbKey = 'Miscellaneous.Tweaks'
Tweaks.Defaults = {
    Enabled = true,
    HideTalkingHead = true,
    HideBossBanner = true,
    EnterAccept = false,
    FixBlizzardBugs = true,

    WhisperSounds = {
        Enabled = false,
        WhisperSound = "|cffe51039NorskenWhisper|r",
        BNetWhisperSound = "|cffe51039NorskenWhisper|r",
    },
}

local AuctionHouseFilter = NRSKNUI:GetModule('AuctionHouseFilter')
AuctionHouseFilter.dbKey = 'Miscellaneous.AuctionHouseFilter'
AuctionHouseFilter.Defaults = {
    Enabled = true,
    AuctionHouse = {
        CurrentExpansion = true,
        FocusSearchBar = true,
    },
    CraftOrders = {
        CurrentExpansion = true,
        FocusSearchBar = false,
    },
    Auctionator = {
        FocusSearchBar = false,
    },
}

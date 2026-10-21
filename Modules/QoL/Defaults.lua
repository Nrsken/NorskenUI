---@class NRSKNUI
local NRSKNUI = select(2, ...)

local CharacterPanel = NRSKNUI:GetModule('CharacterPanel')
CharacterPanel.Defaults = {
    Enabled = true,
    -- Panel texts
    DecimalItemLevel = true,
    FactionTag = true,
    ShowRaceText = false,
    CategoryColorMode = "class",
    CategoryColor = { 1, 1, 1, 1 },
    -- Fonts
    UseGlobalFont = true,
    FontFace = "Expressway",
    FontOutline = "OUTLINE",
    FontShadow = {
        Enabled = false,
        Color = { 0, 0, 0, 1 },
        OffsetX = 1,
        OffsetY = -1,
    },
    NameTextSize = 12,
    LevelTextSize = 12,
    CategoryFontSize = 13,
    IlvlValueSize = 18,
    StatsFontSize = 11,
    TrackIndicators = {
        Enabled = true,
    },
    Sockets = {
        Enabled = true,
        ButtonSize = 24,
        ButtonSpacing = 1,
        ShowOnlyEmpty = false,
    },
    Enchants = {
        Enabled = true,
    },
}

local SpellAlert = NRSKNUI:GetModule('SpellAlert')
SpellAlert.dbKey = 'Miscellaneous.SpellAlert'
SpellAlert.Defaults = {
    Enabled = false,
    UseGlobal = true,
    Global = {
        Scale = 1.0,
        Alpha = 1.0,
    },
    Specs = {},
}

local Recuperate = NRSKNUI:GetModule('Recuperate')
Recuperate.dbKey = 'Miscellaneous.Recuperate'
Recuperate.Defaults = {
    Enabled = true,
    LoadInRaid = true,
    LoadInParty = false,
    Size = 54,
    Strata = "HIGH",
    anchorFrameType = "UIPARENT",
    ParentFrame = "UIParent",
    Position = {
        AnchorFrom = "CENTER",
        AnchorTo = "CENTER",
        XOffset = 0,
        YOffset = -480,
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

local GroupFinder = NRSKNUI:GetModule('GroupFinder')
GroupFinder.dbKey = 'Miscellaneous.GroupFinder'
GroupFinder.Defaults = {
    Enabled = true,
    ShowPanel = true,
    PanelWidth = 176,
    ShowLeaderScore = true,
    ScoreColorSource = "blizzard", -- "blizzard" | "raiderio"
    RoleIconStyle = "bar",         -- "bar" | "circle"
    SortBy = "default",            -- "default" | "overallScore" | "dungeonScore"
    SortDescending = true,
    AccentMode = "theme",          -- "theme" | "class" | "custom"
    CustomAccentColor = { 0, 1, 0.17, 1 },
    -- Font settings
    UseGlobalFont = true,
    FontFace = "Expressway",
    FontSize = 11,
    FontOutline = "OUTLINE",
}

local MiscVars = NRSKNUI:GetModule('MiscVars')
MiscVars.dbKey = 'Miscellaneous.MiscVars'
MiscVars.Defaults = {
    Enabled = true,

    -- Spell Queue Window per position (these are the only persisted values)
    SpellQueueWindowMelee = nil,
    SpellQueueWindowRanged = nil,
}

local Durability = NRSKNUI:GetModule('Durability')
Durability.dbKey = 'Miscellaneous.Durability'
Durability.Defaults = {
    -- General Settings
    Enabled = true,
    ShowPercent = 30,
    CombatShowPercent = 0,
    -- Font settings
    UseGlobalFont = true,
    FontFace = "Expressway",
    FontOutline = "OUTLINE",
    FontSize = 18,
    TextBroken = "GEAR BROKEN",
    TextColorBroken = { 1, 0, 0, 1 },
    TextLow = "REPAIR NOW",
    TextColorLow = { 1, 0.537, 0.2, 1 },
    -- Frame settings
    Strata = "HIGH",
    anchorFrameType = "UIPARENT",
    ParentFrame = "UIParent",
    Position = {
        AnchorFrom = "CENTER",
        AnchorTo = "CENTER",
        XOffset = 0,
        YOffset = 105,
    },
}

local XPBar = NRSKNUI:GetModule('XPBar')
XPBar.dbKey = 'Miscellaneous.XPBar'
XPBar.Defaults = {
    -- General Settings
    Enabled = true,
    HideBlizzardBar = true,
    hideWhenMax = true,
    -- Font settings
    UseGlobalFont = true,
    FontFace = "Expressway",
    FontOutline = "OUTLINE",
    FontSize = 12,
    TextColor = { 1, 1, 1, 1 },
    FontShadow = {
        Enabled = false,
        Color = { 0, 0, 0, 1 },
        OffsetX = 1,
        OffsetY = -1,
    },
    -- Frame settings
    Strata = "HIGH",
    anchorFrameType = "UIPARENT",
    ParentFrame = "UIParent",
    Position = {
        AnchorFrom = "TOP",
        AnchorTo = "TOP",
        XOffset = 0,
        YOffset = -1,
    },
    width = 477,
    height = 30,
    -- Texture settings
    UseGlobalBar = false,
    StatusBarTexture = "NorskenUI",
    RestedTexture = "StripesThick",
    QuestTexture = "StripesThick",
    -- Statusbar coloring
    ColorMode = "theme",
    StatusColor = { 0.58, 0, 0.55, 1 },
    -- Quest coloring
    ColorModeQuest = "custom",
    QuestColor = { 1, 0.82, 0.12, 0.8 },
    QuestShow = true,
    -- Rested Coloring
    ColorModeRested = "theme",
    RestedColor = { 0, 0.39, 0.88, 0.25 },
    RestedShow = true,
    -- Backdrop
    UseGlobalBorder = true,
    UseGlobalBackdrop = true,
    BackgroundColor = { 0, 0, 0, 0.8 },
    BorderColor = { 0, 0, 0, 1 },
}

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
    AutoAcceptRegular = false,
    AutoAcceptDaily = false,
    AutoAcceptWeekly = false,
    AutoAcceptEvent = false,
    AutoBonusRollQuest = false,
    AutoBonusRollMode = 'Gold', -- 'Gold' | 'Marl' | 'Crest'
}

local SkyRiding = NRSKNUI:GetModule('SkyRiding')
SkyRiding.dbKey = 'Miscellaneous.SkyRiding'
SkyRiding.Defaults = {
    -- General Settings
    Enabled = true,
    -- Frame settings
    Strata = "MEDIUM",
    Position = {
        AnchorFrom = "BOTTOM",
        AnchorTo = "CENTER",
        XOffset = 0,
        YOffset = 346,
    },
    Width = 270,
    BarHeight = 8,
    Grow = "UP",
    Spacing = 1,
    PillSpacing = 1,
    -- Texture settings
    UseGlobalBar = true,
    StatusBarTexture = "NorskenUI",
    -- Backdrop
    UseGlobalBorder = true,
    UseGlobalBackdrop = true,
    BackgroundColor = { 0, 0, 0, 0.8 },
    BorderEnabled = true,
    BorderColor = { 0, 0, 0, 1 },
    -- Vigor row
    Vigor = {
        Enabled = true,
        ColorMode = "class",
        Color = { 0.898, 0.063, 0.224, 1 },
        ThrillEnabled = true,
        ThrillColorMode = "custom",
        ThrillColor = { 0, 1, 0.14, 1 },
    },
    -- Whirling Surge row
    WhirlingSurge = {
        Enabled = true,
        ColorMode = "custom",
        Color = { 0.74, 0.74, 0.74, 1 },
    },
    -- Second Wind row
    SecondWind = {
        Enabled = true,
        ColorMode = "custom",
        Color = { 1, 1, 1, 1 },
    },
    -- Speed text
    SpeedText = {
        Enabled = false,
        UseGlobalFont = true,
        FontFace = "Expressway",
        FontSize = 16,
        FontOutline = "OUTLINE",
        TextColor = { 1, 1, 1, 1 },
        XOffset = 0,
        YOffset = 2,
        FontShadow = {
            Enabled = false,
            Color = { 0, 0, 0, 1 },
            OffsetX = 1,
            OffsetY = -1,
        },
    },
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

local CooldownStrings = NRSKNUI:GetModule('CooldownStrings')
CooldownStrings.dbKey = 'Miscellaneous.CooldownStrings'
CooldownStrings.Defaults = {
    Enabled = true,
    Profiles = {},
}

local QuestTracker = NRSKNUI:GetModule('QuestTracker')
QuestTracker.dbKey = 'Miscellaneous.QuestTracker'
QuestTracker.Defaults = {
    Enabled = false,
    CharacterTabOnly = false,
}

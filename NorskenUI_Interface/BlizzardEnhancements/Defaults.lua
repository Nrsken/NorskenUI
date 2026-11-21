---@class NorskenUI
local NRSKNUI = _G.NorskenUI

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

local Vendor = NRSKNUI:GetModule('Vendor')
Vendor.dbKey = 'Miscellaneous.Vendor'
Vendor.Defaults = {
    Enabled = true,
    HideCollected = false,
    Expanded = false,
    Blocks = 2,
    Hidden = {
        Housing = false,
        Mounts = false,
        Pets = false,
        Toys = false,
        Transmog = false,
        Tabards = false,
        Recipes = false,
        Profession = false,
        Consumables = false,
        Gear = false,
        Other = false,
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

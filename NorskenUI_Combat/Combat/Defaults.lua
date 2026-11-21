---@class NorskenUI
local NRSKNUI = _G.NorskenUI

local CombatMessage = NRSKNUI:GetModule('CombatMessage')
CombatMessage.Defaults = {
    -- General Settings
    Enabled = true,
    Duration = 2.5,
    -- Config for DynamicGroup
    Config = {
        Spacing = 0,
        Grow = "DOWN",
        Align = "CENTER",
        RowSpacing = 0,
        GridType = "RD",
        GridWidth = 5,
        UseLimit = false,
        Limit = 5,
    },
    -- Frame Settings
    Strata = "HIGH",
    anchorFrameType = "UIPARENT",
    ParentFrame = "UIParent",
    Position = {
        AnchorFrom = "CENTER",
        AnchorTo = "CENTER",
        XOffset = 0,
        YOffset = 205,
    },
    -- Font settings
    UseGlobalFont = true,
    FontFace = "Expressway",
    FontSize = 16,
    FontOutline = "OUTLINE",
    FontShadow = {
        Enabled = false,
        Color = { 0, 0, 0, 0 },
        OffsetX = 0,
        OffsetY = 0,
    },
    -- Enter Combat Message
    EnterCombat = {
        Enabled = true,
        Text = "+ COMBAT +",
        Color = { 0.929, 0.259, 0, 1 },
        FontSize = 16,
    },
    -- Exit Combat Message
    ExitCombat = {
        Enabled = true,
        Text = "- COMBAT -",
        Color = { 0.788, 1, 0.627, 1 },
        FontSize = 16,
    },
    -- No Target Warning
    NoTarget = {
        Enabled = true,
        Text = "NO TARGET",
        Color = { 1, 0.4, 0, 1 },
        FontSize = 18,
    },
    -- Party/Raid Death Announcement
    PartyDeath = {
        Enabled = true,
        Text = "{rt8} %name Died {rt8}",
        Color = { 1, 1, 1, 1 },
        FontSize = 18,
        LoadCondition = "ANYGROUP",
        UseClassColor = true,
        -- Per-role alert sounds
        SoundTank = "None",
        SoundHealer = "None",
        SoundDamager = "None",
    },
}

local CombatCross = NRSKNUI:GetModule('CombatCross')
CombatCross.Defaults = {
    -- General Settings
    Enabled = true,
    CrossGap = 0,
    CrossThickness = 5,
    CrossLength = 18,
    Outline = true,
    -- Style Settings
    Mode = "cross", -- "cross"| "dot" | "diamond"
    CrossCenterDotEnabled = true,
    CenterDotSize = 20,
    DiamondSize = 32,
    -- Color Settings
    ColorMode = "custom",
    Color = { 0, 1, 0.169, 1 },
    -- Frame Settings
    Strata = "HIGH",
    anchorFrameType = "UIPARENT",
    ParentFrame = "UIParent",
    Position = {
        AnchorFrom = "CENTER",
        AnchorTo = "CENTER",
        XOffset = 0,
        YOffset = -10,
    },
    -- Range Indicator Settings
    RangeColorMeleeEnabled = true,
    RangeColorRangedEnabled = true,
    OutOfRangeColor = { 1, 0, 0, 1 },
}

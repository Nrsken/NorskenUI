---@class NRSKNUI
local NRSKNUI = select(2, ...)

local RerollKeystone = NRSKNUI:GetModule('RerollKeystone')
RerollKeystone.Defaults = {
    Enabled = true,
    Size = 60,
    UseGlobalFont = true,
    FontFace = "Expressway",
    FontSize = 18,
    FontColor = { 1, 0.58, 0, 1 },
    FontColorKey = { 1, 0.83, 0.69, 1 },
    FontSizeKey = 18,
    FontOutline = "OUTLINE",
    Strata = "HIGH",
    anchorFrameType = "UIPARENT",
    ParentFrame = "UIParent",
    Position = {
        AnchorFrom = "CENTER",
        AnchorTo = "CENTER",
        XOffset = 300,
        YOffset = 0,
    },
    GlowEnabled = true,
    GlowType = "pixel",
    GlowColor = { 0, 1, 0, 1 },
    GlowLines = 5,
    GlowFrequency = 0.25,
    GlowLength = 10,
    GlowThickness = 2,
    GlowBorder = true,
    GlowScale = 1,
    GlowStartAnim = false,
    GlowDuration = 1,
}

local DungeonCasts = NRSKNUI:GetModule('DungeonCasts')
DungeonCasts.Defaults = {
    Enabled = true,
    Width = 266,
    Height = 28,
    -- Layout
    Config = {
        Grow = "UP",
        Align = "CENTER",
        Spacing = 1,
        UseLimit = true,
        Limit = 5,
    },
    Strata = "HIGH",
    anchorFrameType = "UIPARENT",
    ParentFrame = "UIParent",
    Position = {
        AnchorFrom = "CENTER",
        AnchorTo = "CENTER",
        XOffset = -360,
        YOffset = 90,
    },
    -- Font
    UseGlobalFont = true,
    FontFace = "Expressway",
    FontSize = 12,
    FontOutline = "OUTLINE",
    FontShadow = {
        Enabled = false,
        Color = { 0, 0, 0, 1 },
        OffsetX = 1,
        OffsetY = -1,
    },
    -- Statusbar
    UseGlobalBar = true,
    StatusBarTexture = "NorskenUI",
    -- Spark
    UseGlobalSpark = true,
    SparkTexture = "Solid",
    SparkScale = 1,
    SparkWidth = 2,
    SparkColor = { 1, 1, 1, 1 },
    -- Colors
    CastColor = { 0.623, 0.749, 1.0, 1 },
    ChannelColor = { 0.8, 0.4, 1.0, 1 },
    NotInterruptibleColor = { 0.780, 0.250, 0.250, 1 },
    TextColor = { 1, 1, 1, 1 },
    UseGlobalBorder = true,
    UseGlobalBackdrop = true,
    BackdropColor = { 0, 0, 0, 0.8 },
    BorderColor = { 0, 0, 0, 1 },
    ShowTime = true,
    RequireCombat = true,
    Icon = {
        Enabled = true,
    },
    -- Raid target icon
    RaidIcon = {
        Enabled = true,
        Size = 21,
        Anchor = "LEFT",
        XOffset = -25,
        YOffset = 0,
    },
    -- Spell target
    Target = {
        Enabled = true,
        ShowClassColor = true,
        Position = "LEFT",
        Separator = "»",
    },
}

---@class NRSKNUI
local NRSKNUI = select(2, ...)

local RangeChecker = NRSKNUI:GetModule('RangeChecker')
RangeChecker.Defaults = {
    Enabled = true,
    CombatOnly = false,
    UpdateThrottle = 0.1,
    MaxRange = 40,

    -- Colors
    ColorOne = { 1, 0, 0 },
    ColorTwo = { 1, 0.42, 0 },
    ColorThree = { 1, 0.82, 0 },
    ColorFour = { 0, 1, 0 },

    UseGlobalFont = true,
    FontFace = "Expressway",
    FontSize = 28,
    FontOutline = "SOFTOUTLINE",
    FontShadow = {
        Enabled = false,
        Color = { 0, 0, 0, 1 },
        OffsetX = 1,
        OffsetY = -1,
    },

    Strata = "HIGH",
    anchorFrameType = "SELECTFRAME",
    ParentFrame = "UIParent",
    Position = {
        AnchorFrom = "CENTER",
        AnchorTo = "CENTER",
        XOffset = 0,
        YOffset = -340,
    },
}

local CombatTimer = NRSKNUI:GetModule('CombatTimer')
CombatTimer.Defaults = {
    Enabled = true,                      -- Enable/disable combat timer
    CombatOnly = false,                  -- Only show timer during combat
    Format = "MM:SS",                    -- Time format
    FontSize = 28,                       -- Font size
    UseGlobalFont = true,
    FontFace = "Expressway",             -- Font face
    FontOutline = "SOFTOUTLINE",         -- Font outline
    FontShadow = {                       -- Font shadow settings
        Enabled = false,                 -- Enable font shadow
        OffsetX = 0,                     -- X offset
        OffsetY = 0,                     -- Y offset
        Color = { 0, 0, 0, 0 },          -- Shadow color (alpha 1 when enabled)
    },
    ColorInCombat = { 1, 1, 1, 1 },      -- Color when in combat
    ColorOutOfCombat = { 1, 1, 1, 0.7 }, -- Color when out of combat
    anchorFrameType = "SELECTFRAME",     -- Anchor type: SCREEN, UIPARENT, SELECTFRAME
    ParentFrame = "UIParent",            -- Parent frame
    Strata = "HIGH",                     -- Frame strata
    Position = {                         -- Position settings
        AnchorFrom = "CENTER",           -- Anchor point from
        AnchorTo = "CENTER",             -- Anchor point to
        XOffset = 794,                   -- X offset
        YOffset = -433,                  -- Y offset
    },
    BackdropEnabled = false,             -- Enable/disable backdrop
    UseGlobalBorder = true,
    UseGlobalBackdrop = true,
    BackgroundColor = { 0, 0, 0, 0.8 },
    BorderColor = { 0, 0, 0, 1 },
    BackdropWidth = 4,
    BackdropHeight = 4,
    PrintEnd = false,
}

local PotionReady = NRSKNUI:GetModule('PotionReady')
PotionReady.Defaults = {
    Enabled = true,
    Text = "POT READY",
    Color = { 1, 1, 1, 1 },
    UseGlobalFont = true,
    FontFace = "Expressway",
    FontSize = 14,
    FontOutline = "SOFTOUTLINE",
    FontShadow = {
        Enabled = false,
        Color = { 0, 0, 0, 1 },
        OffsetX = 1,
        YOffset = -1,
    },
    Strata = "HIGH",
    anchorFrameType = "UIPARENT",
    ParentFrame = "UIParent",
    Position = {
        AnchorFrom = "CENTER",
        AnchorTo = "CENTER",
        XOffset = 0,
        YOffset = 0,
    },
    LoadConditions = {
        Enabled = false,
        SelectedCategory = "Instance",
        Instance = { Types = {} },
        Group = { Types = {} },
        Combat = {},
    },
}

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

local CombatRes = NRSKNUI:GetModule('CombatRes')
CombatRes.dbKey = 'BattleRes' -- its old profile key, which keeps saved profiles and export strings working
CombatRes.Defaults = {
    -- General Settings
    Enabled = true,
    -- Text Settings
    TextSeparator = "%sep",
    TextCharge = "%s",
    TextTimer = "%p",
    TextFormat = "CR: %s %sep %p",
    Separator = "||",
    TimeFormat = "MM:SS",
    -- Color Settings
    ColorSeparator = { 1, 1, 1, 1 },
    ColorChargeAvailable = { 0.3, 1, 0.3, 1 },
    ColorChargeUnavailable = { 1, 0.3, 0.3, 1 },
    ColorTimer = { 1, 1, 1, 1 },
    ColorFormat = { 1, 1, 1, 1 },
    -- Frame Settings
    Strata = "HIGH",
    anchorFrameType = "UIPARENT",
    ParentFrame = "UIParent",
    Position = {
        AnchorFrom = "CENTER",
        AnchorTo = "CENTER",
        XOffset = 814,
        YOffset = -465,
    },
    -- Font Settings
    UseGlobalFont = true,
    FontFace = "Expressway",
    FontSize = 18,
    FontOutline = "OUTLINE",
    FontShadow = {
        Enabled = false,
        Color = { 0, 0, 0, 1 },
        OffsetX = 1,
        OffsetY = -1,
    },
    -- Backdrop Settings
    BackdropEnabled = true,
    UseGlobalBorder = true,
    UseGlobalBackdrop = true,
    BackgroundColor = { 0, 0, 0, 0.8 },
    BorderColor = { 0, 0, 0, 1 },
    BackdropWidth = 4,
    BackdropHeight = 4,
}

local CursorCircle = NRSKNUI:GetModule('CursorCircle')
CursorCircle.dbKey = 'Miscellaneous.CursorCircle'
CursorCircle.Defaults = {
    -- General Settings
    Enabled = true,
    Size = 40,
    VisibilityMode = "always",
    Texture = "Circle 3",
    -- Color Settings
    Color = { 1, 1, 1, 1 },
    ColorMode = "theme",
    -- GCD Settings
    GCD = {
        Mode = "integrated",
        Size = 25,
        Texture = "Circle 5",
        SwipeColorMode = "custom",
        SwipeColor = { 1, 1, 1, 1 },
        Reverse = true,
        HideOutOfCombat = false,
        RingColorMode = "theme",
        RingColor = { 1, 1, 1, 1 },
    },
}

local FocusCastbar = NRSKNUI:GetModule('FocusCastbar')
FocusCastbar.dbKey = 'Miscellaneous.FocusCastbar'
FocusCastbar.Defaults = {
    Enabled = true,
    TargetMarker = {
        Enabled = true,
        Size = 26,
        XOffset = -30,
        YOffset = 0,
        Anchor = "LEFT",
    },

    Width = 367,
    Height = 29,

    UseGlobalFont = true,
    FontFace = "Expressway",
    FontSize = 14,
    FontOutline = "SOFTOUTLINE",
    FontShadow = {
        Enabled = false,
        Color = { 0, 0, 0, 1 },
        OffsetX = 1,
        OffsetY = -1,
    },

    Strata = "HIGH",
    anchorFrameType = "UIPARENT",
    ParentFrame = "UIParent",
    Position = {
        AnchorFrom = "CENTER",
        AnchorTo = "CENTER",
        XOffset = 0,
        YOffset = 262,
    },

    -- Colors
    CastColor = { 0.623, 0.749, 1, 1 },
    NotInterruptibleColor = { 0.780, 0.250, 0.250, 1 },
    HideNotInterruptible = false,
    TextColor = { 1, 1, 1, 1 },

    -- Backdrop
    UseGlobalBorder = true,
    UseGlobalBackdrop = true,
    BackdropColor = { 0, 0, 0, 0.8 },
    BorderColor = { 0, 0, 0, 1 },

    -- Statusbar
    UseGlobalBar = true,
    StatusBarTexture = "NorskenUI",

    -- Spark
    UseGlobalSpark = true,
    SparkTexture = "Solid",
    SparkScale = 1,
    SparkWidth = 2,
    SparkColor = { 1, 1, 1, 1 },

    -- Hold Timer
    HoldTimer = {
        Enabled = true,
        Duration = 1,
        InterruptedColor = { 0.1, 0.8, 0.1, 1 },
        SuccessColor = { 0.780, 0.250, 0.250, 1 },
    },
    timeToHold = 0.5,

    -- Kick Indicator
    KickIndicator = {
        Enabled = true,
        TickWidth = 2,
        NotReadyColor = { 0.5, 0.5, 0.5, 1 },
        TickColor = { 0.1, 0.8, 0.1, 1 },
    },

    -- Target Names
    TargetNames = {
        Anchor = "RIGHT",
        XOffset = 0,
        YOffset = -22,
        FontSize = 14,
    },

    -- Important Spell Glow
    ImportantGlow = {
        GlowEnabled = true,
        GlowType = "pixel",
        GlowColor = { 1, 0.8, 0, 1 },
        GlowLines = 8,
        GlowFrequency = 0.25,
        GlowLength = 18,
        GlowThickness = 2,
        GlowBorder = true,
        GlowScale = 1,
    },
}

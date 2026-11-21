---@class NorskenUI
local NRSKNUI = _G.NorskenUI

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

local PlayerAuras = NRSKNUI:GetModule('PlayerAuras')
PlayerAuras.dbKey = 'Auras' -- its old profile key, which keeps saved profiles and export strings working

-- Each frame is an aura group. Sub elements are a list, which AceDB would refill after a
-- delete, so they are seeded on first build (PlayerAuras.Looks).
PlayerAuras.Defaults = {
    Enabled = true,
    Buffs = {
        Trigger = { Type = 'AuraFilter', Base = 'HELPFUL', branches = { {} } },
        maxFrameCount = 38,
        previewLimit = 40,
        sortMethod = "AuraInstanceIDOnly",
        sortDirection = "Normal",
        showWeaponEnchants = true,
        groupSpacing = 0, -- seam between the weapon enchants and the buff group
        groupLineSpacing = 0,
        Layout = { Grow = "GRID", Align = "CENTER", GridType = "LD", GridWidth = 10, Spacing = 1, RowSpacing = 1 },
        Style = {
            Width = 40,
            Height = 40,
            DrawSwipe = true,
            Reverse = true,
            Tooltip = true,
            TooltipHideInCombat = false,
            DispelIcon = false,
            DispelIconSize = 16,
        },
        anchorFrameType = "SCREEN",
        Position = {
            AnchorFrom = "TOPRIGHT",
            AnchorTo = "TOPRIGHT",
            XOffset = -234,
            YOffset = -1,
        },
    },
    Debuffs = {
        Trigger = { Type = 'AuraFilter', Base = 'HARMFUL', branches = { {} } },
        maxFrameCount = 8,
        previewLimit = 8,
        sortMethod = "ExpirationOnly",
        sortDirection = "Normal",
        Layout = { Grow = "GRID", Align = "CENTER", GridType = "LD", GridWidth = 8, Spacing = 1, RowSpacing = 1 },
        Style = {
            Width = 46,
            Height = 46,
            DrawSwipe = false,
            Reverse = true,
            Tooltip = true,
            TooltipHideInCombat = false,
            DispelIcon = true,
            DispelIconSize = 16,
        },
        anchorFrameType = "SCREEN",
        Position = {
            AnchorFrom = "TOPRIGHT",
            AnchorTo = "TOPRIGHT",
            XOffset = -234,
            YOffset = -218,
        },
    },
}

-- How each frame's texts and border start, for Core:DefaultAuraGroupSubRegions: the way the
-- frames drew before they were aura groups.
PlayerAuras.Looks = {
    -- buffs aren't coloured by type, but a weapon enchant draws its border through it
    Buffs = { auraType = { ShowHelpful = false }, timer = { FontSize = 12, GlobalTimeColor = true }, stacks = { FontSize = 12 } },
    Debuffs = { auraType = { DispelUntyped = true }, timer = { FontSize = 14, GlobalTimeColor = true }, stacks = { FontSize = 12 } },
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

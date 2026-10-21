---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

Skinning.Defaults = {
    -- The module folder is Skinning/FrameSkins, the key stays so existing profiles keep their settings.
    BlizzardElements = {
        Enabled = true,
        UseGlobalFont = true,
        FontFace = "Expressway",
        FontOutline = "OUTLINE",
        FontShadow = {
            Enabled = false,
            Color = { 0, 0, 0, 1 },
            OffsetX = 1,
            OffsetY = -1,
        },

        FontEditBoxSize = 12,

        FontTabSize = 11,
        FontButtonSize = 11,

        FontSmallSize = 11,
        FontMediumSize = 12,
        FontLargeSize = 13,

        ObjectiveTracker = {
            Enabled = true,
            FontStyling = true,
            QuestTextSize = 12,
            QuestTitleSize = 13,
            ColorMode = "theme",
            CustomColor = { 0, 1, 0.17, 1 },
        },
        General = {
            UseGlobalBorder = true,
            UseGlobalBackdrop = true,
            BorderColor = { 0, 0, 0, 1 },
            BackgroundColor = { 0, 0, 0, 0.8 },
            WidgetBorderColor = { 0, 0, 0, 1 },
            WidgetBackgroundColor = { 0.11, 0.11, 0.11, 1 },
            WidgetGlowColor = { 1, 1, 1, 0.11 },
            PanelColor = { 0.2, 0.2, 0.2, 1 },
            DisabledColor = { 0, 0, 0, 0.4 },
            AccentMode = "theme", -- "theme" | "class" | "custom"
            CustomAccentColor = { 0, 1, 0.17, 1 },
            HighlightColor = { 0.5, 0.5, 0.5, 0.1 },
        },
        Frames = {
            Ace3 = true,
            BigWigsKeystones = true,
            BigWigsPopups = true,
            BugSack = true,
            CharacterFrame = true,
            GameMenu = true,
            GossipFrame = true,
            GroupFinder = true,
            InspectFrame = true,
            KeystoneLoot = true,
            Menus = true,
            MerchantFrame = true,
            PlayerSpells = true,
            Professions = true,
            QuestFrame = true,
            RaiderIO = true,
            ReadyCheck = true,
            Runeforge = true,
            SimpleAddonManager = true,
            StaticPopups = true,
            TalentLoadoutsEx = true,
            TeleportMenu = true,
        },
    },

    BlizzardRM = {
        Enabled = true,
        -- Position Settings
        Position = {        -- Position settings
            YOffset = -650, -- Y offset
        },
        Strata = "HIGH",
        FadeOnMouseOut = true,
        FadeInDuration = 0.3,
        FadeOutDuration = 3,
        Alpha = 0,
    },

    Battlenet = {
        Enabled = true,
        -- Position Settings
        anchorFrameType = "UIPARENT",  -- Anchor frame type
        ParentFrame = "UIParent",      -- Parent frame name
        Position = {                   -- Position settings
            AnchorFrom = "BOTTOMLEFT", -- Anchor point from
            AnchorTo = "BOTTOMLEFT",   -- Anchor point to
            XOffset = 1,               -- X offset
            YOffset = 247,             -- Y offset
        },
    },

    UICleanup = {
        Enabled = true,
    },

    -- Custom Chat (Chatv2)
    Chatv2 = {
        Enabled = true,
        Width = 448,
        Height = 245,
        UseGlobalFont = true,
        FontFace = "Expressway",
        FontOutline = "OUTLINE",
        FontSize = 14,
        TabFontSize = 12,
        EditBoxFontSize = 14,
        FontShadow = {
            Enabled = false,
            Color = { 0, 0, 0, 1 },
            OffsetX = 1,
            OffsetY = -1,
        },
        ShortChannels = true,                           -- Use short channel names
        FadeEnabled = true,                             -- Enable text fading
        FadeTime = 30,                                  -- Seconds before chat fades
        FadeAlpha = 0,                                  -- Alpha when faded
        MaxLines = 500,                                 -- Max lines to keep in history
        TimestampFormat = "[%H:%M] ",                   -- Timestamp format (NONE = disabled)
        UseLocalTime = true,                            -- Use local time for timestamps
        TimestampColorEnabled = true,                   -- Use custom timestamp color
        TimestampColor = { r = 0.6, g = 0.6, b = 0.6 }, -- Custom timestamp color
        Backdrop = {
            Enabled = true,
            UseGlobalBorder = true,
            UseGlobalBackdrop = true,
            Color = { 0, 0, 0, 0.8 },
            BorderColor = { 0, 0, 0, 1 },
        },
        EditBox = {
            UseGlobalBorder = true,
            UseGlobalBackdrop = true,
            BackdropColor = { 0, 0, 0, 0.8 },
            BorderColor = { 0, 0, 0, 1 },
        },
        TabBackdrop = {
            Enabled = true,
            UseGlobalBorder = true,
            UseGlobalBackdrop = false, -- tabs are a lighter tint than the panel on purpose
            Color = { 0, 0, 0, 0.2 },
            BorderColor = { 0, 0, 0, 1 },
        },
        FadeTabs = true,                                  -- Fade tab text when not hovered
        EditBoxPosition = "ABOVE_CHAT_INSIDE",            -- BELOW_CHAT or ABOVE_CHAT
        NumScrollMessages = 3,                            -- Number of messages to scroll per wheel tick
        -- Tab Styling
        TabSelector = "NONE",                             -- Tab selector style: NONE, ARROW, ARROW1, ARROW2, ARROW3, BOX, BOX1, CURLY, CURLY1, CURVE, CURVE1
        TabSelectorColor = { r = 1, g = 1, b = 1 },       -- Tab selector color
        TabSelectedTextEnabled = true,                    -- Use custom color for selected tab text
        TabSelectedTextColor = { r = 1, g = 0.5, b = 0 }, -- Selected tab text color
        TabTextColor = { r = 0.57, g = 0.57, b = 0.57 },  -- Default tab text color
        TabTextColorMode = "custom",                      -- class | custom | theme
        TabFontFace = nil,                                -- Tab font face (nil = use STANDARD_TEXT_FONT)
        TabFontOutline = "OUTLINE",                       -- Tab font outline
        anchorFrameType = "UIPARENT",
        ParentFrame = "UIParent",
        Position = {
            AnchorFrom = "BOTTOMLEFT",
            AnchorTo = "BOTTOMLEFT",
            XOffset = 1,
            YOffset = 1,
        },
    },

    -- Actionbars
    ActionBars = {
        Enabled = true,            -- Master toggle for action bar skinning
        HideProfTexture = true,    -- Hide profession quality textures
        HideMacroText = false,     -- Hide macro name text
        HideKeybindText = false,   -- Hide keybind text
        HideChargeText = false,    -- Hide charge/stack text
        MouseoverOverride = false, -- Mouseover override when dragonriding for example
        Mouseover = {              -- Global mouseover settings (used when bar's globalOverride is true)
            Enabled = true,
            FadeInDuration = 0.3,
            FadeOutDuration = 1,
            Alpha = 0,
        },
        UseGlobalFont = true,
        FontFace = "Expressway",
        FontOutline = "OUTLINE",

        RangeOverlayColor = { 1, 0, 0, 0.2 },
        DesaturateOnCooldown = false,

        -- Global Font Sizes (used when bar's FontSizes.GlobalOverride is true)
        FontSizes = {
            KeybindSize = 12,
            CooldownSize = 14,
            ChargeSize = 12,
            MacroSize = 10,
        },

        -- Text Anchor Settings
        KeybindAnchor = "TOPRIGHT",
        KeybindXOffset = -2,
        KeybindYOffset = -2,

        ChargeAnchor = "BOTTOMRIGHT",
        ChargeXOffset = -2,
        ChargeYOffset = 2,

        MacroAnchor = "BOTTOM",
        MacroXOffset = 0,
        MacroYOffset = 2,

        CooldownAnchor = "CENTER",
        CooldownXOffset = 0,
        CooldownYOffset = 0,
        -- Per-bar settings (all bars use same structure)
        Bars = {
            Bar1 = {
                Enabled = true,
                Spacing = 1,
                ButtonSize = 40,
                TotalButtons = 12,
                Layout = "HORIZONTAL",
                GrowthDirection = "RIGHT",
                FlyoutDirection = "AUTO",
                ButtonsPerLine = 12,
                ParentFrame = "UIParent",
                HideEmptyBackdrops = false,
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackdropColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                Position = {
                    AnchorPoint = "BOTTOM",
                    XOffset = 0,
                    YOffset = 1,
                },
                Mouseover = {
                    GlobalOverride = true,
                    Enabled = true,
                    Alpha = 0,
                },
                FontSizes = {
                    GlobalOverride = true,
                    KeybindSize = 12,
                    CooldownSize = 14,
                    ChargeSize = 12,
                    MacroSize = 10,
                },
                TextPositions = {
                    GlobalOverride = true,
                    KeybindAnchor = "TOPRIGHT",
                    KeybindXOffset = -2,
                    KeybindYOffset = -2,
                    ChargeAnchor = "BOTTOMRIGHT",
                    ChargeXOffset = -2,
                    ChargeYOffset = 2,
                    MacroAnchor = "BOTTOM",
                    MacroXOffset = 0,
                    MacroYOffset = -2,
                },
                TextVisibility = {
                    GlobalOverride = true,
                    HideMacroText = false,
                    HideKeybindText = false,
                    HideChargeText = false,
                    HideProfTexture = false,
                },
            },
            Bar2 = {
                Enabled = true,
                Spacing = 1,
                ButtonSize = 40,
                TotalButtons = 12,
                Layout = "HORIZONTAL",
                GrowthDirection = "RIGHT",
                FlyoutDirection = "AUTO",
                ButtonsPerLine = 6,
                ParentFrame = "UIParent",
                HideEmptyBackdrops = false,
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackdropColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                Position = {
                    AnchorPoint = "BOTTOM",
                    XOffset = 369,
                    YOffset = 1,
                },
                Mouseover = {
                    GlobalOverride = true,
                    Enabled = true,
                    Alpha = 0,
                },
                FontSizes = {
                    GlobalOverride = true,
                    KeybindSize = 12,
                    CooldownSize = 14,
                    ChargeSize = 12,
                    MacroSize = 10,
                },
                TextPositions = {
                    GlobalOverride = true,
                    KeybindAnchor = "TOPRIGHT",
                    KeybindXOffset = -2,
                    KeybindYOffset = -2,
                    ChargeAnchor = "BOTTOMRIGHT",
                    ChargeXOffset = -2,
                    ChargeYOffset = 2,
                    MacroAnchor = "BOTTOM",
                    MacroXOffset = 0,
                    MacroYOffset = -2,
                },
                TextVisibility = {
                    GlobalOverride = true,
                    HideMacroText = false,
                    HideKeybindText = false,
                    HideChargeText = false,
                    HideProfTexture = false,
                },
            },
            Bar3 = {
                Enabled = true,
                Spacing = 1,
                ButtonSize = 40,
                TotalButtons = 12,
                Layout = "HORIZONTAL",
                GrowthDirection = "RIGHT",
                FlyoutDirection = "AUTO",
                ButtonsPerLine = 12,
                ParentFrame = "UIParent",
                HideEmptyBackdrops = false,
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackdropColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                Position = {
                    AnchorPoint = "BOTTOM",
                    XOffset = 0,
                    YOffset = 42,
                },
                Mouseover = {
                    GlobalOverride = true,
                    Enabled = true,
                    Alpha = 0,
                },
                FontSizes = {
                    GlobalOverride = true,
                    KeybindSize = 12,
                    CooldownSize = 14,
                    ChargeSize = 12,
                    MacroSize = 10,
                },
                TextPositions = {
                    GlobalOverride = true,
                    KeybindAnchor = "TOPRIGHT",
                    KeybindXOffset = -2,
                    KeybindYOffset = -2,
                    ChargeAnchor = "BOTTOMRIGHT",
                    ChargeXOffset = -2,
                    ChargeYOffset = 2,
                    MacroAnchor = "BOTTOM",
                    MacroXOffset = 0,
                    MacroYOffset = -2,
                },
                TextVisibility = {
                    GlobalOverride = true,
                    HideMacroText = false,
                    HideKeybindText = false,
                    HideChargeText = false,
                    HideProfTexture = false,
                },
            },
            Bar4 = {
                Enabled = true,
                Spacing = 1,
                ButtonSize = 40,
                TotalButtons = 12,
                Layout = "VERTICAL",
                GrowthDirection = "RIGHT",
                FlyoutDirection = "AUTO",
                ButtonsPerLine = 2,
                ParentFrame = "UIParent",
                HideEmptyBackdrops = false,
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackdropColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                Position = {
                    AnchorPoint = "BOTTOMLEFT",
                    XOffset = 450,
                    YOffset = 1,
                },
                Mouseover = {
                    GlobalOverride = true,
                    Enabled = true,
                    Alpha = 0,
                },
                FontSizes = {
                    GlobalOverride = true,
                    KeybindSize = 12,
                    CooldownSize = 14,
                    ChargeSize = 12,
                    MacroSize = 10,
                },
                TextPositions = {
                    GlobalOverride = true,
                    KeybindAnchor = "TOPRIGHT",
                    KeybindXOffset = -2,
                    KeybindYOffset = -2,
                    ChargeAnchor = "BOTTOMRIGHT",
                    ChargeXOffset = -2,
                    ChargeYOffset = 2,
                    MacroAnchor = "BOTTOM",
                    MacroXOffset = 0,
                    MacroYOffset = -2,
                },
                TextVisibility = {
                    GlobalOverride = true,
                    HideMacroText = false,
                    HideKeybindText = false,
                    HideChargeText = false,
                    HideProfTexture = false,
                },
            },
            Bar5 = {
                Enabled = true,
                Spacing = 1,
                ButtonSize = 40,
                TotalButtons = 12,
                Layout = "HORIZONTAL",
                GrowthDirection = "RIGHT",
                FlyoutDirection = "AUTO",
                ButtonsPerLine = 6,
                ParentFrame = "UIParent",
                HideEmptyBackdrops = false,
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackdropColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                Position = {
                    AnchorPoint = "BOTTOM",
                    XOffset = -369,
                    YOffset = 1,
                },
                Mouseover = {
                    GlobalOverride = true,
                    Enabled = true,
                    Alpha = 0,
                },
                FontSizes = {
                    GlobalOverride = true,
                    KeybindSize = 12,
                    CooldownSize = 14,
                    ChargeSize = 12,
                    MacroSize = 10,
                },
                TextPositions = {
                    GlobalOverride = true,
                    KeybindAnchor = "TOPRIGHT",
                    KeybindXOffset = -2,
                    KeybindYOffset = -2,
                    ChargeAnchor = "BOTTOMRIGHT",
                    ChargeXOffset = -2,
                    ChargeYOffset = 2,
                    MacroAnchor = "BOTTOM",
                    MacroXOffset = 0,
                    MacroYOffset = -2,
                },
                TextVisibility = {
                    GlobalOverride = true,
                    HideMacroText = false,
                    HideKeybindText = false,
                    HideChargeText = false,
                    HideProfTexture = false,
                },
            },
            Bar6 = {
                Enabled = true,
                Spacing = 1,
                ButtonSize = 40,
                TotalButtons = 12,
                Layout = "VERTICAL",
                GrowthDirection = "RIGHT",
                FlyoutDirection = "AUTO",
                ButtonsPerLine = 2,
                ParentFrame = "UIParent",
                HideEmptyBackdrops = false,
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackdropColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                Position = {
                    AnchorPoint = "BOTTOMLEFT",
                    XOffset = 532,
                    YOffset = 1,
                },
                Mouseover = {
                    GlobalOverride = true,
                    Enabled = true,
                    Alpha = 0,
                },
                FontSizes = {
                    GlobalOverride = true,
                    KeybindSize = 12,
                    CooldownSize = 14,
                    ChargeSize = 12,
                    MacroSize = 10,
                },
                TextPositions = {
                    GlobalOverride = true,
                    KeybindAnchor = "TOPRIGHT",
                    KeybindXOffset = -2,
                    KeybindYOffset = -2,
                    ChargeAnchor = "BOTTOMRIGHT",
                    ChargeXOffset = -2,
                    ChargeYOffset = 2,
                    MacroAnchor = "BOTTOM",
                    MacroXOffset = 0,
                    MacroYOffset = -2,
                },
                TextVisibility = {
                    GlobalOverride = true,
                    HideMacroText = false,
                    HideKeybindText = false,
                    HideChargeText = false,
                    HideProfTexture = false,
                },
            },
            Bar7 = {
                Enabled = true,
                Spacing = 1,
                ButtonSize = 40,
                TotalButtons = 12,
                Layout = "VERTICAL",
                GrowthDirection = "RIGHT",
                FlyoutDirection = "AUTO",
                ButtonsPerLine = 1,
                ParentFrame = "UIParent",
                HideEmptyBackdrops = false,
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackdropColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                Position = {
                    AnchorPoint = "LEFT",
                    XOffset = 1,
                    YOffset = 0,
                },
                Mouseover = {
                    GlobalOverride = true,
                    Enabled = false,
                    Alpha = 1,
                },
                FontSizes = {
                    GlobalOverride = true,
                    KeybindSize = 12,
                    CooldownSize = 14,
                    ChargeSize = 12,
                    MacroSize = 10,
                },
                TextPositions = {
                    GlobalOverride = true,
                    KeybindAnchor = "TOPRIGHT",
                    KeybindXOffset = -2,
                    KeybindYOffset = -2,
                    ChargeAnchor = "BOTTOMRIGHT",
                    ChargeXOffset = -2,
                    ChargeYOffset = 2,
                    MacroAnchor = "BOTTOM",
                    MacroXOffset = 0,
                    MacroYOffset = -2,
                },
                TextVisibility = {
                    GlobalOverride = true,
                    HideMacroText = false,
                    HideKeybindText = false,
                    HideChargeText = false,
                    HideProfTexture = false,
                },
            },
            Bar8 = {
                Enabled = true,
                Spacing = 1,
                ButtonSize = 40,
                TotalButtons = 12,
                Layout = "VERTICAL",
                GrowthDirection = "RIGHT",
                FlyoutDirection = "AUTO",
                ButtonsPerLine = 1,
                ParentFrame = "UIParent",
                HideEmptyBackdrops = false,
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackdropColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                Position = {
                    AnchorPoint = "LEFT",
                    XOffset = 42,
                    YOffset = 0,
                },
                Mouseover = {
                    GlobalOverride = true,
                    Enabled = false,
                    Alpha = 1,
                },
                FontSizes = {
                    GlobalOverride = true,
                    KeybindSize = 12,
                    CooldownSize = 14,
                    ChargeSize = 12,
                    MacroSize = 10,
                },
                TextPositions = {
                    GlobalOverride = true,
                    KeybindAnchor = "TOPRIGHT",
                    KeybindXOffset = -2,
                    KeybindYOffset = -2,
                    ChargeAnchor = "BOTTOMRIGHT",
                    ChargeXOffset = -2,
                    ChargeYOffset = 2,
                    MacroAnchor = "BOTTOM",
                    MacroXOffset = 0,
                    MacroYOffset = -2,
                },
                TextVisibility = {
                    GlobalOverride = true,
                    HideMacroText = false,
                    HideKeybindText = false,
                    HideChargeText = false,
                    HideProfTexture = false,
                },
            },
            PetBar = {
                Enabled = true,
                Spacing = 1,
                ButtonSize = 32,
                TotalButtons = 10,
                Layout = "HORIZONTAL",
                GrowthDirection = "RIGHT",
                ButtonsPerLine = 2,
                ParentFrame = "UIParent",
                HideEmptyBackdrops = false,
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackdropColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                Position = {
                    AnchorPoint = "BOTTOMLEFT",
                    XOffset = 614,
                    YOffset = 82,
                },
                Mouseover = {
                    GlobalOverride = false,
                    Enabled = false,
                    Alpha = 0,
                },
                FontSizes = {
                    GlobalOverride = true,
                    KeybindSize = 10,
                    CooldownSize = 12,
                    ChargeSize = 10,
                    MacroSize = 8,
                },
                TextPositions = {
                    GlobalOverride = true,
                    KeybindAnchor = "TOPRIGHT",
                    KeybindXOffset = -2,
                    KeybindYOffset = -2,
                    ChargeAnchor = "BOTTOMRIGHT",
                    ChargeXOffset = -2,
                    ChargeYOffset = 2,
                    MacroAnchor = "BOTTOM",
                    MacroXOffset = 0,
                    MacroYOffset = -2,
                },
                TextVisibility = {
                    GlobalOverride = true,
                    HideMacroText = false,
                    HideKeybindText = false,
                    HideChargeText = false,
                    HideProfTexture = false,
                },
            },
            StanceBar = {
                Enabled = true,
                Spacing = 1,
                ButtonSize = 32,
                TotalButtons = 10,
                Layout = "HORIZONTAL",
                GrowthDirection = "RIGHT",
                ButtonsPerLine = 10,
                ParentFrame = "UIParent",
                HideEmptyBackdrops = true,
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackdropColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                Position = {
                    AnchorPoint = "BOTTOMLEFT",
                    XOffset = 120,
                    YOffset = 247,
                },
                Mouseover = {
                    GlobalOverride = false,
                    Enabled = false,
                    Alpha = 0,
                },
                FontSizes = {
                    GlobalOverride = true,
                    KeybindSize = 10,
                    CooldownSize = 12,
                    ChargeSize = 10,
                    MacroSize = 8,
                },
                TextPositions = {
                    GlobalOverride = true,
                    KeybindAnchor = "TOPRIGHT",
                    KeybindXOffset = -2,
                    KeybindYOffset = -2,
                    ChargeAnchor = "BOTTOMRIGHT",
                    ChargeXOffset = -2,
                    ChargeYOffset = 2,
                    MacroAnchor = "BOTTOM",
                    MacroXOffset = 0,
                    MacroYOffset = -2,
                },
                TextVisibility = {
                    GlobalOverride = true,
                    HideMacroText = false,
                    HideKeybindText = false,
                    HideChargeText = false,
                    HideProfTexture = false,
                },
            },
        },
    },

    -- Minimap Skinning
    Minimap = {
        Enabled = true, -- Master toggle for minimap skinning
        Size = 232,     -- Minimap size (square)
        Scale = 1,      -- Minimap scale

        UseGlobalFont = true,
        FontFace = "Expressway",
        FontOutline = "OUTLINE",
        FontShadow = {
            Enabled = false,
            Color = { 0, 0, 0, 0 },
            OffsetX = 0,
            OffsetY = 0,
        },

        Position = {                 -- Position
            AnchorFrom = "TOPRIGHT", -- Anchor point
            AnchorTo = "TOPRIGHT",
            X = -1,                  -- X offset from anchor
            Y = -1,                  -- Y offset from anchor
        },
        Border = {                   -- Border settings
            Thickness = 1,           -- Border thickness
            Color = { 0, 0, 0, 1 },  -- Border color
        },

        -- MiniMap Elements
        Mail = {
            Enabled = true,
            Scale = 1,
            Anchor = "TOPRIGHT",
            X = -4,
            Y = -4,
        },
        InstanceDifficulty = {
            Enabled = true,
            Scale = 0.8,
            Anchor = "TOPLEFT",
            X = 2,
            Y = -2,
        },
        QueueStatus = {
            Enabled = true,
            Scale = 0.7,
            Anchor = "BOTTOMLEFT",
            X = 2,
            Y = 50,
        },
        LandingPage = {
            Enabled = true,
            Size = 36,
            Anchor = "BOTTOMRIGHT",
            X = -2,
            Y = 2,
        },
        AddOnComp = {
            Enabled = false,
            Size = 26,
            Anchor = "RIGHT",
            X = -1,
            Y = 0,
        },
        BugSack = {
            Enabled = true,
            Size = 16,
            Anchor = "BOTTOMLEFT",
            X = 2,
            Y = 2,
        },
    },

    -- MicroMenu Skinning
    MicroMenu = {
        Enabled = true,
        ButtonWidth = 23,
        ButtonHeight = 31,
        ButtonSpacing = -4,
        BackdropSpacing = 0,
        ShowBackdrop = true,
        UseGlobalBorder = true,
        UseGlobalBackdrop = true,
        BackdropColor = { 0, 0, 0, 0.8 },
        BackdropBorderColor = { 0, 0, 0, 1 },
        anchorFrameType = "SELECTFRAME",
        ParentFrame = "Minimap",
        Strata = "HIGH",
        Position = {
            AnchorFrom = "TOP",
            AnchorTo = "BOTTOM",
            XOffset = 0,
            YOffset = -1,
        },
        Mouseover = {
            Enabled = false,
            Alpha = 0.0,
            FadeInDuration = 0.2,
            FadeOutDuration = 0.2,
        },
    },
    -- Blizzard Element Mouseover
    BlizzardMouseover = {
        -- General Settings
        Enabled = true,
        Alpha = 0.0,
        FadeInDuration = 0.2,
        FadeOutDuration = 1,
        -- Elements
        mouseoverElements = {
            Bags = {
                Enabled = true,
                Hide = false,
            },
        },
    },

    -- UI Widgets Skinning (M+ timer, power bars, etc.)
    UIWidgets = {
        Enabled = true,
        FontFace = "Expressway",
        FontOutline = "OUTLINE",
        -- Status bar widgets (M+ timer, power bars)
        StatusBar = {
            Enabled = true,
            Width = 0,            -- Custom width (0 = use default)
            StyleLabel = true,    -- Style the label above bars
            StyleBarText = true,  -- Style text on the bar
            LabelSize = 14,       -- Font size for labels
            BarTextSize = 12,     -- Font size for bar text
            StripTextures = true, -- Remove Blizzard textures and add backdrop
            BackdropColor = { 0, 0, 0, 0.8 },
            BorderColor = { 0, 0, 0, 1 },
        },
        -- Text widgets
        TextWidget = {
            Enabled = true,
            Width = 400, -- Custom width (0 = use default)
            StyleText = true,
            Size = 17,
        },
    },

    -- Tooltip Skinning
    Tooltips = {
        Enabled = true,
        -- General Settings
        HideThreatLine = true,
        ShowItemQualityBorder = true,
        ShowMountInfo = true,
        SkinAuraContainer = true,
        ShowAuraContainerSpellID = true,
        -- Hide in combat settings
        HideInCombat = true,
        Mod = "SHIFT", -- "SHIFT", "CTRL" or "ALT"
        HideInCombatTypes = {
            Units = true,
            Items = true,
            Spells = true,
            Auras = true,
        },
        -- Statusbar Settings
        ShowStatusBar = true,
        StatusBarTexture = "NorskenUI",
        UseGlobalBar = true,
        -- Coloring
        UseGlobalBorder = true,
        UseGlobalBackdrop = true,
        BackgroundColor = { 0, 0, 0, 0.8 },
        BorderColor = { 0, 0, 0, 1 },
        MinionColor = { 0.5, 0.5, 0.5 },
        NameRealmColor = { 0.5, 0.5, 0.5 },
        GuildNameColor = { 0.25, 1.0, 0.25 }, -- Standard guild green
        GuildRankColor = { 0.25, 1.0, 0.25 }, -- Standard guild green
        -- General font settings
        UseGlobalFont = true,
        FontFace = "Expressway",
        FontOutline = "OUTLINE",
        FontShadow = {
            Enabled = false,
            Color = { 0, 0, 0, 0 },
            OffsetX = 0,
            OffsetY = 0,
        },
        -- Font size settings
        HeaderTextSize = 16,
        TextSize = 14,
        TextSmallSize = 12,
        -- Pos settings
        Position = {
            AnchorFrom = "BOTTOMRIGHT",
            AnchorTo = "BOTTOMRIGHT",
            XOffset = 0,
            YOffset = 239,
        },
    },

    -- Details Backdrop Settings
    DetailsBackdrop = {
        Enabled = true,
        backdrops = {
            [1] = {
                Enabled = true,
                autoSize = false,
                detailsBars = 8,
                width = 260,
                height = 240,
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackgroundColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                anchorFrameType = "UIPARENT",
                ParentFrame = "UIParent",
                Strata = "LOW",
                Position = {
                    AnchorFrom = "BOTTOMRIGHT",
                    AnchorTo = "BOTTOMRIGHT",
                    XOffset = -1,
                    YOffset = 1,
                },
            },
            [2] = {
                Enabled = true,
                autoSize = false,
                detailsBars = 8,
                width = 260,
                height = 240,
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackgroundColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                anchorFrameType = "UIPARENT",
                ParentFrame = "UIParent",
                Strata = "LOW",
                Position = {
                    AnchorFrom = "BOTTOMRIGHT",
                    AnchorTo = "BOTTOMRIGHT",
                    XOffset = -263,
                    YOffset = 1,
                },
            },
            [3] = {
                Enabled = false,
                autoSize = false,
                detailsBars = 8,
                width = 260,
                height = 240,
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackgroundColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                anchorFrameType = "UIPARENT",
                ParentFrame = "UIParent",
                Strata = "LOW",
                Position = {
                    AnchorFrom = "BOTTOMRIGHT",
                    AnchorTo = "BOTTOMRIGHT",
                    XOffset = -525,
                    YOffset = 1,
                },
            },
            [4] = {
                Enabled = false,
                autoSize = false,
                detailsBars = 8,
                width = 260,
                height = 240,
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackgroundColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                anchorFrameType = "UIPARENT",
                ParentFrame = "UIParent",
                Strata = "LOW",
                Position = {
                    AnchorFrom = "BOTTOMRIGHT",
                    AnchorTo = "BOTTOMRIGHT",
                    XOffset = -787,
                    YOffset = 1,
                },
            },
            [5] = {
                Enabled = false,
                autoSize = false,
                detailsBars = 8,
                width = 260,
                height = 240,
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackgroundColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                anchorFrameType = "UIPARENT",
                ParentFrame = "UIParent",
                Strata = "LOW",
                Position = {
                    AnchorFrom = "BOTTOMRIGHT",
                    AnchorTo = "BOTTOMRIGHT",
                    XOffset = -1049,
                    YOffset = 1,
                },
            },
        },
    }
}

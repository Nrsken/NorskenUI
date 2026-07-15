---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Default settings table
local Defaults = {
    global = {
        UseGlobalProfile = false,  -- Switch to global profile
        GlobalProfile = "Default", -- Name of global profile to use
        XPTable = {},              -- Table i can store xp per level data for math.
        -- Theme settings
        -- Mode: "preset", "class", or "custom"
        -- All theme presets are defined in AddonTheme.lua
        Theme = {
            mode           = "preset", -- Theme mode: preset, class, or custom
            selectedPreset = "NUI v2", -- Selected preset theme name
            customColors   = {},       -- Custom color overrides (used in custom mode)

            -- Font settings (shared across all modes)
            fontFace       = "Interface\\AddOns\\NorskenUI\\Media\\Fonts\\Expressway.TTF",
            fontSizeNormal = 12,
            fontSizeSmall  = 12,
            fontSizeLarge  = 16,
            fontOutline    = "OUTLINE",
            fontShadow     = false,
        },

        -- Global UIParent scale.
        UIScale = {
            Enabled = true,
            Scale   = 0.71,
        },

        -- GUI State (only frame position/size persists across logins)
        GUIState = {
            GUIFrameLayoutVersion = 67, -- Bump this to force a one-time frame size reset for all users
            frame = {
                point = nil,            -- Anchor point
                relativePoint = nil,    -- Relative anchor point
                xOffset = nil,          -- Frame X offset
                yOffset = nil,          -- Frame Y offset
                width = nil,            -- Frame width
                height = nil,           -- Frame height
            },
            selectedGroupId = nil,      -- Currently selected sidebar item
            selectedTab = nil,          -- Currently selected tab in content
            minimized = false,          -- Is frame minimized
        },
    },
    profile = {
        globalMedia = {
            Enabled = true,
            profileFont = { Enabled = true, FontFace = "Expressway", },
            profileBar = { Enabled = true, statusBar = "NorskenUI", },
            blizzardFonts = {
                Enabled = true,
                Outline = "OUTLINE",
                Slug = true,
                HideShadow = true,
                Families = {},
                Overrides = {},
                Specials = {
                    ZoneText = {
                        Enabled = true,
                        Size = 40,
                        Hide = false,
                        Position = { Anchor = "TOP", X = 0, Y = -200 },
                    },
                    SubZoneText = { Enabled = true, Size = 20 },
                    PvPZoneText = { Enabled = true, Size = 20 },
                    ErrorText = {
                        Enabled = true,
                        Size = 14,
                        Hide = false,
                        Position = { Anchor = "TOP", X = 0, Y = -281 },
                    },
                    ActionStatus = {
                        Enabled = true,
                        Size = 14,
                        Hide = false,
                        Position = { Anchor = "TOP", X = 0, Y = -251 },
                    },
                    ChatBubbles = { Enabled = true, Size = 8 },
                    Nameplates = { Enabled = false },
                    CombatText = { Enabled = false },
                    CombatFont = { Enabled = false }, -- DAMAGE_TEXT_FONT, relog to apply/revert
                    NameFont = { Enabled = false },   -- UNIT_NAME_FONT, relog to apply/revert
                },
            },
        },

        RerollKeystone = {
            Enabled = true,
            Size = 60,
            UseGlobalFont = true,
            FontFace = "Expressway",

            FontSize = 18,
            FontColor = { 1, 1, 1, 1 },

            FontColorKey = { 1, 1, 1, 1 },
            FontSizeKey = 20,

            FontOutline = "SOFTOUTLINE",
            Strata = "HIGH",
            anchorFrameType = "UIPARENT",
            ParentFrame = "UIParent",
            Position = {
                AnchorFrom = "CENTER",
                AnchorTo = "CENTER",
                XOffset = 0,
                YOffset = -200,
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
        },

        CharacterPanel = {
            Enabled = true,
            DecimalItemLevel = true,
            ShowRaceText = true,
            UseGlobalFont = true,
            FontFace = "Expressway",
            FontOutline = "OUTLINE",
            StatsFontSize = 11,
            LevelTextSize = 12,
            NameTextSize = 12,
            CategoryFontSize = 12,
            IlvlValueSize = 16,
            FontShadow = {
                Enabled = false,
                Color = { 0, 0, 0, 1 },
                OffsetX = 1,
                OffsetY = -1,
            },
            GemSocketHelper = {
                Enabled = true,
                SocketButtonSize = 24,
                SocketButtonSpacing = 1,
                ShowOnlyEmpty = false,
                EnchantHelper = true,
            },
            TrackIndicators = {
                Enabled = true,
            },
        },
        RangeChecker = {
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

        -- ElvUI Integration
        UseElvUI = {
            Enabled = true, -- Master toggle for ElvUI integration (disables my skins when true to avoid conflicts)
        },
        -- Minimap Icon Settings
        Minimap = {
            hide = false,        -- Show/hide minimap icon
            LoginMessage = true, -- Show login chat message
        },
        -- Combat Timer Settings
        CombatTimer = {
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
            BackgroundColor = { 0, 0, 0, 0.8 },
            BorderColor = { 0, 0, 0, 1 },
            BackdropWidth = 8,
            BackdropHeight = 5,
            PrintEnd = false,
        },

        PotionReady = {
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
        },

        -- Combat Message Settings
        CombatMessage = {
            Enabled = true,               -- Enable/disable combat messages
            Strata = "HIGH",              -- Frame strata
            anchorFrameType = "UIPARENT", -- Anchor frame type (SCREEN, UIPARENT, SELECTFRAME)
            ParentFrame = "UIParent",     -- Parent frame name (when SELECTFRAME)
            UseGlobalFont = true,         -- Use global font settings
            FontFace = "Expressway",      -- Font face
            FontSize = 16,                -- Font size
            FontOutline = "SOFTOUTLINE",  -- Font outline: NONE, OUTLINE, THICKOUTLINE, SOFTOUTLINE, SLUG, SLUG,OUTLINE
            FontShadow = {                -- Font shadow settings (disabled for SOFTOUTLINE/SLUG variants)
                Enabled = false,          -- Enable font shadow
                Color = { 0, 0, 0, 0 },   -- Shadow color
                OffsetX = 0,              -- Shadow X offset
                OffsetY = 0,              -- Shadow Y offset
            },
            Position = {                  -- Position settings
                AnchorFrom = "CENTER",    -- Anchor point from
                AnchorTo = "CENTER",      -- Anchor point to
                XOffset = 0,              -- X offset
                YOffset = 205,            -- Y offset
            },
            Spacing = 0,                  -- Vertical spacing between messages
            Grow = "DOWN",                -- Grow direction: DOWN or UP
            Duration = 2.5,               -- How long messages are shown (seconds)
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
            -- No Target Warning (persistent while in combat with no target)
            NoTarget = {
                Enabled = true,
                Text = "NO TARGET",
                Color = { 1, 0.4, 0, 1 },
                FontSize = 18,
            },
            -- Focus Target Died
            FocusDeath = {
                Enabled = true,
                Text = "FOCUS DIED",
                Color = { 1, 0.3, 0.3, 1 },
                FontSize = 18,
            },
            -- Party/Raid Death Announcement
            PartyDeath = {
                Enabled = true,
                UseClassColor = true,
                TextFormat = "%name died",
                TextColor = { 1, 1, 1, 1 },
                CombatOnly = true,
                LoadCondition = "ANYGROUP",
                FontSize = 18,
            },
        },

        -- Combat Cross Settings
        CombatCross = {
            Enabled = true,                   -- Enable/disable combat cross
            Strata = "HIGH",                  -- Frame strata
            anchorFrameType = "UIPARENT",     -- Anchor frame type (SCREEN, UIPARENT, SELECTFRAME)
            ParentFrame = "UIParent",         -- Parent frame name (when SELECTFRAME)
            Position = {                      -- Position settings
                AnchorFrom = "CENTER",        -- Anchor point from
                AnchorTo = "CENTER",          -- Anchor point to
                XOffset = 0,                  -- X offset
                YOffset = -10,                -- Y offset
            },
            ColorMode = "custom",             -- Color mode: "class" | "custom" | "theme"
            Color = { 0, 1, 0.169, 1 },       -- Cross color (used when ColorMode = "custom")
            Thickness = 22,                   -- Cross thickness (font size)
            Outline = true,                   -- Outline enabled
            RangeColorMeleeEnabled = false,   -- Color cross when out of melee range
            RangeColorRangedEnabled = false,  -- Color cross when out of ranged casting range
            OutOfRangeColor = { 1, 0, 0, 1 }, -- Color used when out of range
        },

        -- Battle Res Tracker Settings
        BattleRes = {
            Enabled = true,
            Strata = "HIGH",
            anchorFrameType = "UIPARENT",
            ParentFrame = "UIParent",
            Position = {
                AnchorFrom = "CENTER",
                AnchorTo = "CENTER",
                XOffset = 814,
                YOffset = -465,
            },
            UseGlobalFont = true,
            FontFace = "Expressway",
            FontSize = 18,
            FontOutline = "SOFTOUTLINE",
            FontShadow = {
                Enabled = false,
                Color = { 0, 0, 0, 1 },
                OffsetX = 1,
                OffsetY = -1,
            },
            TextSpacing = 4,
            GrowthDirection = "RIGHT",
            Separator = "|",
            SeparatorCharges = "CR:",
            SeparatorColor = { 1, 1, 1, 1 },
            TimerColor = { 1, 1, 1, 1 },
            ChargeAvailableColor = { 0.3, 1, 0.3, 1 },
            ChargeUnavailableColor = { 1, 0.3, 0.3, 1 },
            Backdrop = {
                Enabled = true,
                Color = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
                FrameWidth = 112,
                FrameHeight = 27,
            },
        },

        -- Burning Rush Tracker (Warlock)
        BurningRush = {
            Enabled = false,
            IconSize = 40,

            -- Glow
            GlowEnabled = true,
            GlowType = "pixel",
            GlowColor = { 1, 0.5, 0, 1 },

            -- Glow Shared Settings
            GlowXOffset = 0,
            GlowYOffset = 0,

            -- Pixel Glow Specific
            GlowLines = 5,
            GlowFrequency = 0.25,
            GlowLength = 10,
            GlowThickness = 2,
            GlowBorder = true,

            -- AutoCast Specific
            GlowScale = 1,

            -- Proc Specific
            GlowDuration = 1,
            GlowStartAnim = false,

            -- Position
            Strata = "HIGH",
            anchorFrameType = "UIPARENT",
            ParentFrame = "UIParent",
            Position = {
                AnchorFrom = "CENTER",
                AnchorTo = "CENTER",
                XOffset = 0,
                YOffset = -50,
            },
        },

        -- Reap Free Cast
        ReckonTracker = {
            Enabled = false,
            IconSize = 40,

            -- Glow
            GlowEnabled = true,
            GlowType = "pixel",
            GlowColor = { 0, 1, 0, 1 },
            GlowXOffset = 0,
            GlowYOffset = 0,
            GlowLines = 5,
            GlowFrequency = 0.25,
            GlowLength = 10,
            GlowThickness = 2,
            GlowBorder = true,
            GlowScale = 1,
            GlowDuration = 1,
            GlowStartAnim = false,

            -- Position
            Strata = "HIGH",
            anchorFrameType = "UIPARENT",
            ParentFrame = "UIParent",
            Position = {
                AnchorFrom = "CENTER",
                AnchorTo = "CENTER",
                XOffset = 0,
                YOffset = -50,
            },
        },

        -- Incarnation Stack Tracker
        IncarnStacks = {
            Enabled = false,
            IconSize = 40,
            UseGlobalFont = true,

            -- Stack Text (shows stack count)
            ShowStacks = true,
            StackTextColor = { 1, 1, 1, 1 },
            StackFontFace = "Expressway",
            StackFontSize = 16,
            StackFontOutline = "OUTLINE",

            -- Timer Text (on icon)
            ShowTimer = true,
            TimerTextColor = { 1, 1, 1, 1 },
            TimerFontFace = "Expressway",
            TimerFontSize = 15,
            TimerFontOutline = "SOFTOUTLINE",

            -- Glow
            GlowEnabled = true,
            GlowType = "pixel",
            GlowColor = { 1, 0.678, 0, 1 },

            -- Glow Shared Settings
            GlowXOffset = 0,
            GlowYOffset = 0,

            -- Pixel Glow Specific
            GlowLines = 7,
            GlowFrequency = 0.25,
            GlowLength = 8,
            GlowThickness = 1,
            GlowBorder = true,

            -- AutoCast Specific
            GlowScale = 1,

            -- Proc Specific
            GlowDuration = 1,
            GlowStartAnim = false,

            -- Position
            Strata = "HIGH",
            anchorFrameType = "UIPARENT",
            ParentFrame = "UIParent",
            Position = {
                AnchorFrom = "CENTER",
                AnchorTo = "CENTER",
                XOffset = 0,
                YOffset = -50,
            },
        },

        -- Totem Tracker
        TotemTracker = {
            Enabled = true,
            IconSize = 44,
            IconSpacing = 1,
            GrowDirection = "RIGHT",
            ShowTimer = true,
            Swipe = false,
            Reverse = false,

            -- Font settings
            UseGlobalFont = true,
            FontFace = "Expressway",
            FontOutline = "OUTLINE",
            TimerFontSize = 18,

            -- Position
            Strata = "HIGH",
            anchorFrameType = "UIPARENT",
            ParentFrame = "UIParent",
            Position = {
                AnchorFrom = "CENTER",
                AnchorTo = "CENTER",
                XOffset = -500,
                YOffset = -450,
            },
        },

        PetTexts = {
            Enabled = true, -- Master toggle
            -- State texts
            PetMissing = "PET MISSING",
            PetPassive = "PET PASSIVE",
            PetDead = "PET DEAD",
            -- State colors (RGBA)
            MissingColor = { 1, 0.82, 0, 1 },  -- Gold/yellow for missing
            PassiveColor = { 0.3, 0.7, 1, 1 }, -- Light blue for passive
            DeadColor = { 1, 0.2, 0.2, 1 },    -- Red for dead
            -- Font settings
            UseGlobalFont = true,
            FontFace = "Expressway",
            FontSize = 27,
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
            Position = {               -- Position settings
                AnchorFrom = "CENTER", -- Anchor point from
                AnchorTo = "CENTER",   -- Anchor point to
                XOffset = 0,           -- X offset
                YOffset = 220,         -- Y offset
            },
        },

        -- Healer Mana Tracker
        HealerMana = {
            Enabled = true,
            EnableInRaid = true,
            MaxHealers = 6,
            FrameSpacing = 4,
            GrowDirection = "DOWN",
            -- Frame settings
            IconSize = 38,
            FrameWidth = 120,
            -- Text settings
            NameFontSize = 18,
            NameYOffset = 3,
            ManaFontSize = 24,
            ManaYOffset = 4,
            -- Font settings
            UseGlobalFont = true,
            FontFace = "Expressway",
            FontOutline = "SOFTOUTLINE",
            FontShadow = {
                Enabled = false,
                Color = { 0, 0, 0, 1 },
                OffsetX = 1,
                OffsetY = -1,
            },
            HighManaColor = { 1, 1, 1, 1 },
            -- Position settings
            Strata = "HIGH",
            anchorFrameType = "UIPARENT",
            ParentFrame = "UIParent",
            SplitPositioning = false,
            PartyPosition = {
                AnchorFrom = "CENTER",
                AnchorTo = "CENTER",
                XOffset = -584,
                YOffset = -72,
            },
            RaidPosition = {
                AnchorFrom = "CENTER",
                AnchorTo = "CENTER",
                XOffset = -584,
                YOffset = -72,
            },
        },

        -- Miscellaneous Settings
        Miscellaneous = {
            BenchAlert = {
                Enabled = false,
                Text = "BENCH CUH",
                Color = { 1, 0.3, 0.3, 1 },
                UseGlobalFont = true,
                FontFace = "Expressway",
                FontSize = 36,
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
                    YOffset = 41,
                },
            },

            WayFinder = {
                Enabled = true,
            },

            SpellAlert = {
                Enabled = true,
                UseGlobal = true,
                Global = {
                    Scale = 1.0,
                    Alpha = 1.0,
                },
                Specs = {},
            },

            Recuperate = {
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
            },

            AuctionHouseFilter = {
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
            },

            MiscVars = {
                Enabled = true,

                -- Spell Queue Window per position (these are the only persisted values)
                SpellQueueWindowMelee = nil,
                SpellQueueWindowRanged = nil,
            },

            Gateway = {
                Enabled = true,
                Text = "GATE USABLE CUH",
                Color = { 0, 1, 0 },
                -- Font settings
                UseGlobalFont = true,
                FontFace = "Expressway",      -- Font face
                FontSize = 36,                -- Font size
                FontOutline = "SOFTOUTLINE",  -- Font outline (NONE, OUTLINE, THICKOUTLINE, SOFTOUTLINE, SLUG, SLUG,OUTLINE)
                -- Position settings
                Strata = "HIGH",              -- Frame strata
                anchorFrameType = "UIPARENT", -- Anchor frame type
                ParentFrame = "UIParent",     -- Parent frame name
                Position = {                  -- Position settings
                    AnchorFrom = "CENTER",    -- Anchor point from
                    AnchorTo = "CENTER",      -- Anchor point to
                    XOffset = 0,              -- X offset
                    YOffset = -427,           -- Y offset
                },
            },
            Durability = {
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
            },
            XPBar = {
                -- General Settings
                Enabled = true,
                HideBlizzardBar = true,
                hideWhenMax = true,
                -- Font settings
                UseGlobalFont = true,
                FontFace = "Expressway",
                FontOutline = "OUTLINE",
                FontSize = 14,
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
                height = 26,
                -- Texture settings
                UseGlobalBar = true,
                StatusBarTexture = "NorskenUI",
                RestedTexture = "NorskenUI",
                QuestTexture = "NorskenUI",
                -- Statusbar coloring
                ColorMode = "theme",
                StatusColor = { 0.58, 0, 0.55, 1 },
                -- Quest coloring
                ColorModeQuest = "custom",
                QuestColor = { 1, 0.82, 0.12, 1 },
                QuestShow = true,
                -- Rested Coloring
                ColorModeRested = "theme",
                RestedColor = { 0, 0.39, 0.88, 0.25 },
                RestedShow = true,
                -- Backdrop
                BackgroundColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
            },
            CopyAnything = {
                Enabled = true,
                key = "C",
                modifier = "ctrl", -- 'ctrl' | 'shift' | 'alt'
            },
            CursorCircle = {
                Enabled = true,            -- Enable cursor circle
                Size = 40,                 -- Circle size
                Texture = "Circle 3",      -- Selected texture
                Color = { 1, 1, 1, 1 },    -- Circle color (RGBA) - used when ColorMode = "custom"
                ColorMode = "theme",       -- Color mode: "class" | "custom" | "theme"
                VisibilityMode = "always", -- Visibility mode: "always" | "mouseDown"
                UseUpdateInterval = false, -- Use throttled updates (saves CPU but less smooth)
                UpdateInterval = 0.016,    -- Update interval in seconds (0.016 = ~60 FPS, lower = smoother but higher CPU)
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
            },
            Automation = {
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
            },

            Tweaks = {
                Enabled = true,
                HideTalkingHead = true,
                HideBossBanner = true,
                EnterAccept = false,
            },

            CooldownStrings = {
                Enabled = true,
                Profiles = {},
            },
            FocusCastbar = {
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
                BackdropColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },

                -- Statusbar
                UseGlobalBar = true,
                StatusBarTexture = "NorskenUI",

                -- Hold Timer
                HoldTimer = {
                    Enabled = true,
                    Duration = 1,
                    InterruptedColor = { 0.1, 0.8, 0.1, 1 },
                    FailedColor = { 0.780, 0.250, 0.250, 1 },
                    SuccessColor = { 0.780, 0.250, 0.250, 1 },
                },
                timeToHold = 0.5,

                -- Kick Indicator
                KickIndicator = {
                    Enabled = true,
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
            },
        },
        -- Skinning Settings
        Skinning = {
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
                    SkinHeaders = true,
                    SkinProgressBars = true,
                    SkinMinimizeButton = true,
                    SkinQuestIcons = true,
                    FontStyling = true,
                    QuestTextSize = 12,
                    QuestTitleSize = 13,
                    ColorMode = "Theme",
                    CustomColor = { 0, 1, 0.17, 1 },
                },
                General = {
                    BorderColor = { 0, 0, 0, 1 },
                    BackgroundColor = { 0, 0, 0, 0.8 },
                    WidgetColor = { 0.078, 0.078, 0.078, 1 },
                    PanelColor = { 0.2, 0.2, 0.2, 1 },
                    DisabledColor = { 0, 0, 0, 0.4 },
                    AccentMode = "Theme", -- "Theme" | "Class" | "Custom"
                    CustomAccentColor = { 0, 1, 0.17, 1 },
                    HighlightColor = { 0.5, 0.5, 0.5, 0.1 },
                },
                Frames = {
                    CharacterFrame = true,
                    InspectFrame = true,
                    PlayerSpells = true,
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
                    Color = { 0, 0, 0, 0.8 },
                    BorderColor = { 0, 0, 0, 1 },
                },
                EditBox = {
                    BackdropColor = { 0, 0, 0, 0.8 },
                    BorderColor = { 0, 0, 0, 1 },
                },
                TabBackdrop = {
                    Enabled = true,
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
                WhisperSounds = {
                    Enabled = false,
                    WhisperSound = "|cffe51039NorskenWhisper|r",
                    BNetWhisperSound = "|cffe51039NorskenWhisper|r",
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
                Enabled = true,       -- Master toggle for bags bar skinning
                Alpha = 0.0,          -- Alpha when not hovered (0 = fully hidden)
                FadeInDuration = 0.2, -- Fade in duration
                FadeOutDuration = 1,  -- Fade out duration
                BagMouseover = {
                    Enabled = true,   -- Enable mouseover fading
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
                currentEdit = 1,
                backdrops = {
                    [1] = {
                        Enabled = true,
                        autoSize = false,
                        detailsBars = 8,
                        width = 260,
                        height = 240,
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
        },

        -- Instance Reset Message
        InstanceReset = {
            Enabled = true,
            Message = "Instance reset!",
        },

        -- Dungeon Timers (BigWigs Integration)
        DungeonTimers = {
            Enabled = true,

            -- Global display settings for Bars
            BarDisplay = {
                barWidth = 220,
                barHeight = 24,
                barTexture = "NorskenUI", -- LSM statusbar texture key
                FontFace = "Expressway",
                FontSize = 14,
                FontOutline = "OUTLINE", -- NONE, OUTLINE, THICKOUTLINE, SOFTOUTLINE, SLUG, SLUG,OUTLINE
                FontShadow = {
                    Enabled = false,
                    Color = { 0, 0, 0, 1 },
                    OffsetX = 1,
                    OffsetY = -1,
                },
                iconEnabled = true,
                UseGlobalFont = true,
                UseGlobalBar = true,
            },

            -- Global display settings for Texts
            TextDisplay = {
                UseGlobalFont = true,
                FontFace = "Expressway",
                FontSize = 24,
                FontOutline = "SOFTOUTLINE", -- NONE, OUTLINE, THICKOUTLINE, SOFTOUTLINE, SLUG, SLUG,OUTLINE
                FontShadow = {
                    Enabled = false,
                    Color = { 0, 0, 0, 1 },
                    OffsetX = 1,
                    OffsetY = -1,
                },
                textAlign = "CENTER", -- LEFT, CENTER, RIGHT
            },

            -- Global group settings (applies to all dungeons)
            BarGroup = {
                Position = {
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    XOffset = 0,
                    YOffset = -128,
                },
                GrowthDirection = "UP",
                Spacing = 1,
            },
            TextGroup = {
                Position = {
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    XOffset = 0,
                    YOffset = 75,
                },
                GrowthDirection = "DOWN",
                Spacing = 0,
            },

            -- Per-dungeon triggers (instanceId maps to BigWigs/LittleWigs boss modules)
            Dungeons = {
                MagistersTerrace  = { Enabled = true, instanceId = 2811, Triggers = {} },
                MaisaraCaverns    = { Enabled = true, instanceId = 2874, Triggers = {} },
                NexusPointXenas   = { Enabled = true, instanceId = 2915, Triggers = {} },
                WindrunnerSpire   = { Enabled = true, instanceId = 2805, Triggers = {} },
                AlgetharAcademy   = { Enabled = true, instanceId = 2526, Triggers = {} },
                PitOfSaron        = { Enabled = true, instanceId = 658, Triggers = {} },
                SeatOfTriumvirate = { Enabled = true, instanceId = 1753, Triggers = {} },
                Skyreach          = { Enabled = true, instanceId = 1209, Triggers = {} },
            },

            -- Default values for new triggers (template)
            -- Per-trigger defaults (text content, colors)
            TriggerDefaults = {
                enabled = true,
                triggerType = "timer",
                spellId = "",
                message = "",
                messageOperator = "find",
                remainingEnabled = true,
                remainingOperator = "<=",
                remainingValue = 5,
                countEnabled = false,
                countOperator = "==",
                countValue = 1,
                extendTimer = 0,
                displayType = "bar",
                -- Colors
                useBigWigsColors = true,
                barColor = { 0.772, 0.168, 0.168, 1 },
                backgroundColor = { 0, 0, 0, 0.8 },
                textColor = { 1, 1, 1, 1 },
                -- Bar text settings
                barText1Format = "Tank Hit",
                barText1Justify = "LEFT",
                barText1XOffset = 3,
                barText1YOffset = 0,
                barText2Format = "%p",
                barText2Justify = "RIGHT",
                barText2XOffset = -3,
                barText2YOffset = 0,
                -- Text mode settings
                textFormat = "%n » %p",
                textJustify = "LEFT",
                showDecimals = true,
                decimalThreshold = 1,
                -- Custom text (Lua code for %c placeholder)
                -- Function signature: function(expirationTime, duration, remaining, name, icon, stacks)
                customText = "",
                -- Load conditions
                loadRoleEnabled = false,
                loadRoleTank = true,
                loadRoleHealer = true,
                loadRoleDPS = true,
                loadPosEnabled = false,
                loadPosMelee = true,
                loadPosRanged = true,
                -- Actions
                actionOnShowSound = "None",
                actionOnHideSound = "None",
            },
        },

        -- Dungeon Casts (Enemy Nameplate Casting Monitor)
        DungeonCasts = {
            Enabled = true,

            -- Frame settings
            Frame = {
                MaxBars = 5,
                Width = 265,
                Height = 28,
                Spacing = 1,
                GrowthDirection = "UP", -- UP or DOWN
                Strata = "HIGH",
                anchorFrameType = "UIPARENT",
                ParentFrame = "UIParent",
                Position = {
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    XOffset = -360,
                    YOffset = 90,
                },
            },

            -- Bar appearance
            BarDisplay = {
                StatusBarTexture = "NorskenUI",
                UseGlobalFont = true,
                UseGlobalBar = true,
                FontFace = "Expressway",
                FontSize = 13,
                FontOutline = "OUTLINE",
                SparkEnabled = false,
            },

            -- Icon settings
            Icon = {
                Enabled = true,
                Size = 28,
                Zoom = 0.3,
            },

            -- Colors
            CastingColor = { 0.623, 0.749, 1.0, 1 },
            ChannelingColor = { 0.8, 0.4, 1.0, 1 },
            NotInterruptibleColor = { 0.780, 0.250, 0.250, 1 },
            BackgroundColor = { 0, 0, 0, 0.8 },
            BorderColor = { 0, 0, 0, 1 },

            -- Raid target icon
            RaidIcon = {
                Enabled = true,
                Size = 21,
            },

            -- Text settings
            Text = {
                NameAlign = "LEFT",
                TimeAlign = "RIGHT",
                ShowTime = true,
                TextColor = { 1, 1, 1, 1 },
            },

            -- Target display settings
            Target = {
                Enabled = true,
                ShowClassColor = true,
                Position = "LEFT", -- LEFT or RIGHT
                Separator = "»",   -- Separator between spell name and target
            },
        },
        -- Missing Items Tracker (bag item warnings)
        MissingItems = {
            Enabled = false,
            ActiveGroup = "Default",
            Groups = { "Default" },
            Items = {},
            Display = {
                UseGlobalFont = true,
                FontFace = "Expressway",
                FontSize = 14,
                FontOutline = "SOFTOUTLINE",
                LineSpacing = 4,
                DefaultColor = { 1, 0.2, 0.2, 1 },
                Strata = "HIGH",
                anchorFrameType = "UIPARENT",
                ParentFrame = "UIParent",
                Position = {
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    XOffset = 0,
                    YOffset = -200,
                },
            },
        },
    },
    char = {
        XPBar = {
            XPLast = 0,
            XPGained = 0,
            XPMax = 0,
            SessionAccumulationTime = 0,
            LevelAccumulationTime = 0,
            TotalAccumulationTime = 0,
            StartTime = 0,
            StartTimeLevel = 0,
        },
    },
}

-- Returns the Default Table.
function NRSKNUI:GetDefaultDB()
    return Defaults
end

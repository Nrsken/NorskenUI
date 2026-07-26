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
        -- All theme presets are defined in Libs/LibKaji-1.0/Theme.lua
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
            sidebarExpanded = nil,      -- Expanded sidebar groups
        },
        -- Aura Filters
        AuraFilters = {},
        AuraBlocklist = {},
        AuraSpellLists = {},
    },
    profile = {
        -- Shared color palette, pushed into oUF.colors + NRSKNUI.Colors by NRSKNUI:LoadCustomColors().
        -- Mainly consumed by UnitFrames, but any module can read NRSKNUI.db.profile.Colors.
        Colors = {
            -- Original power colors from blizzard's PowerBarColor table.
            Power = {
                [0] = { 0, 0, 1 },                 -- Mana
                [1] = { 1, 0, 0 },                 -- Rage
                [2] = { 1, 0.5, 0.25 },            -- Focus
                [3] = { 1, 1, 0 },                 -- Energy
                [6] = { 0, 0.82, 1 },              -- Runic Power
                [8] = { 0.3, 0.52, 0.9 },          -- Lunar / Astral Power
                [11] = { 0, 0.5, 1 },              -- Maelstrom
                [13] = { 0.4, 0, 0.8 },            -- Insanity
                [17] = { 0.788, 0.259, 0.992 },    -- Fury
                [18] = { 1, 0.61176470588235, 0 }, -- Pain
            },
            -- Original reaction colors from blizzard's FACTION_BAR_COLORS table.
            Reaction = {
                [1] = { 0.80000007152557, 0.30196079611778, 0.21960785984993 }, -- Hated
                [2] = { 0.80000007152557, 0.30196079611778, 0.21960785984993 }, -- Hostile
                [3] = { 0.74901962280273, 0.27058824896812, 0 },                -- Unfriendly
                [4] = { 0.90196084976196, 0.70196080207825, 0 },                -- Neutral
                [5] = { 0, 0.60000002384186, 0.10196079313755 },                -- Friendly
                [6] = { 0, 0.60000002384186, 0.10196079313755 },                -- Honored
                [7] = { 0, 0.60000002384186, 0.10196079313755 },                -- Revered
                [8] = { 0, 0.60000002384186, 0.10196079313755 },                -- Exalted
            },
            -- Original class colors from blizzard.
            Class = {
                DEATHKNIGHT = { 0.76862752437592, 0.11764706671238, 0.22745099663734 },
                DEMONHUNTER = { 0.63921570777893, 0.18823531270027, 0.78823536634445 },
                DRUID = { 1, 0.48627454042435, 0.039215687662363 },
                EVOKER = { 0.20000001788139, 0.57647061347961, 0.49803924560547 },
                HUNTER = { 0.66666668653488, 0.82745105028152, 0.44705885648727 },
                MAGE = { 0.24705883860588, 0.78039222955704, 0.9215686917305 },
                MONK = { 0, 1, 0.59607845544815 },
                PALADIN = { 0.95686280727386, 0.54901963472366, 0.7294117808342 },
                PRIEST = { 1, 1, 1 },
                ROGUE = { 1, 0.95686280727386, 0.4078431725502 },
                SHAMAN = { 0, 0.43921571969986, 0.8666667342186 },
                WARLOCK = { 0.52941179275513, 0.53333336114883, 0.93333339691162 },
                WARRIOR = { 0.77647066116333, 0.60784316062927, 0.42745101451874 },
            },
            -- Custom status colors for various unit states
            Status = {
                Tapped = { 0.6, 0.6, 0.6, 1 },
                Disconnected = { 0.5, 0.5, 0.5, 1 },
                Dead = { 0.35, 0, 0.05, 1 },
            },
            -- Custom dispel colors
            Dispel = {
                None = { 0.80000007152557, 0, 0, 0 },
                Magic = { 0, 0.50588238239288, 1, 1 },
                Curse = { 0.6235294342041, 0.023529414087534, 0.89411771297455, 1 },
                Disease = { 0.94509810209274, 0.41568630933762, 0.035294119268656, 1 },
                Poison = { 0.48235297203064, 0.78039222955704, 0, 1 },
                Bleed = { 0.72156864404678, 0, 0.05882353335619, 1 },
                Enrage = { 0.95294117927551, 0.37254902720451, 0.95686280727386, 1 },
            },
        },
        globalMedia = {
            Enabled = true,
            profileFont = { Enabled = true, FontFace = "Expressway", },
            profileBar = { Enabled = true, statusBar = "NorskenUI" },
            -- Addons global formatter defaults.
            durationBreakpointColors = true,
            durationCurveColors = false,
            durationSingleColor = false,
            profileBreakPoints = {
                pointOne = { threshold = 0, step = 0.1, format = '%0.1f', },
                pointTwo = { threshold = 3, step = 1, format = '%d', },
                pointThree = { threshold = 10, step = 1, format = '%d', },
                pointFour = { threshold = 60, format = '%dm', },
                pointFive = { threshold = 3600, format = '%dh', },
            },
            profileColorCurve = {
                colorOne = { 1, 0.25, 0.25, 1 },
                colorTwo = { 1.00, 0.25, 0.25, 1 },
                colorThree = { 1.00, 0.75, 0.20, 1 },
                colorFour = { 1.00, 0.95, 0.70, 1 },
                colorFive = { 1.00, 0.95, 0.70, 1 },
            },
            profileColorBreakPoint = {
                colorOne = { 1, 0.25, 0.25, 1 },
                colorTwo = { 1, 1, 1, 1 },
                colorThree = { 1, 1, 1, 1 },
                colorFour = { 1, 1, 1, 1 },
                colorFive = { 1, 1, 1, 1 },
            },
            durationSingleColorValue = { 1, 1, 1, 1 },
            -- Blizzard Fonts
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
            hide = true,        -- Show/hide minimap icon
            hideMessage = true, -- Show login chat message
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
            BackdropWidth = 4,
            BackdropHeight = 4,
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
        },
        CombatCross = {
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
        },
        -- Battle Res Tracker Settings
        BattleRes = {
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
            BackgroundColor = { 0, 0, 0, 0.8 },
            BorderColor = { 0, 0, 0, 1 },
            BackdropWidth = 4,
            BackdropHeight = 4,
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
            PetWrong = "WRONG PET!",
            -- State colors (RGBA)
            MissingColor = { 1, 0.82, 0, 1 },  -- Gold/yellow for missing
            PassiveColor = { 0.3, 0.7, 1, 1 }, -- Light blue for passive
            DeadColor = { 1, 0.2, 0.2, 1 },    -- Red for dead
            WrongColor = { 1, 0, 1, 1 },       -- Magenta for wrong pet
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
            Config = {
                Spacing = 10,
                Grow = "HORIZONTAL",
                Align = "CENTER",
                RowSpacing = 0,
                GridType = "RD",
                GridWidth = 5,
                UseLimit = true,
                Limit = 1,
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

        -- Player Auras (top-right buffs/debuffs)
        Auras = {
            Enabled = true,
            Buffs = {
                Enabled = true,
                -- Aura container options, names match Blizzard's (see Core/AuraContainer.lua).
                size = 40,
                perRow = 10,
                maxFrameCount = 40,
                elementSpacing = 1,
                lineSpacing = 1,
                groupSpacing = 0, -- seam between the weapon enchants and the buff group
                groupLineSpacing = 0,
                horizontalGrowthDirection = "LEFT",
                verticalGrowthDirection = "DOWN",
                -- Enum key names, resolved against AuraContainerSortMethod/SortDirection at use time.
                sortMethod = "ExpirationOnly",
                sortDirection = "Normal",
                showApplicationCount = true,
                showDurationText = true,
                drawSwipe = true,
                drawEdge = false,
                reverseSwipe = true,
                tooltipHideInCombat = false,
                showWeaponEnchants = true,
                UseGlobalFont = true,
                FontFace = "Expressway",
                FontOutline = "OUTLINE",
                FontShadow = {
                    Enabled = false,
                    Color = { 0, 0, 0, 1 },
                    OffsetX = 1,
                    OffsetY = -1,
                },
                -- Per-string size and placement inside the aura button, face/outline/shadow are shared.
                StackFont = {
                    FontSize = 12,
                    Position = {
                        AnchorFrom = "BOTTOMRIGHT",
                        XOffset = -1,
                        YOffset = 1,
                    },
                },
                DurationFont = {
                    FontSize = 12,
                    Position = {
                        AnchorFrom = "CENTER",
                        XOffset = 0,
                        YOffset = 0,
                    },
                },
                anchorFrameType = "SCREEN",
                Position = {
                    AnchorFrom = "TOPRIGHT",
                    AnchorTo = "TOPRIGHT",
                    XOffset = -233,
                    YOffset = 0,
                },
            },
            Debuffs = {
                Enabled = true,
                -- Aura container options, names match Blizzard's (see Core/AuraContainer.lua).
                size = 50,
                perRow = 10,
                maxFrameCount = 10,
                elementSpacing = 1,
                lineSpacing = 1,
                horizontalGrowthDirection = "LEFT",
                verticalGrowthDirection = "DOWN",
                -- Enum key names, resolved against AuraContainerSortMethod/SortDirection at use time.
                sortMethod = "ExpirationOnly",
                sortDirection = "Normal",
                showApplicationCount = true,
                showDurationText = true,
                drawSwipe = false,
                drawEdge = false,
                reverseSwipe = true,
                showBorder = true,
                showDebuffDispelIcon = true,
                dispelIconSize = 12,
                tooltipHideInCombat = false,
                UseGlobalFont = true,
                FontFace = "Expressway",
                FontOutline = "OUTLINE",
                FontShadow = {
                    Enabled = false,
                    Color = { 0, 0, 0, 1 },
                    OffsetX = 1,
                    OffsetY = -1,
                },
                -- Per-string size and placement inside the aura button, face/outline/shadow are shared.
                StackFont = {
                    FontSize = 12,
                    Position = {
                        AnchorFrom = "BOTTOMRIGHT",
                        XOffset = -1,
                        YOffset = 1,
                    },
                },
                DurationFont = {
                    FontSize = 14,
                    Position = {
                        AnchorFrom = "CENTER",
                        XOffset = 0,
                        YOffset = 0,
                    },
                },
                anchorFrameType = "SCREEN",
                Position = {
                    AnchorFrom = "TOPRIGHT",
                    AnchorTo = "TOPRIGHT",
                    XOffset = -13,
                    YOffset = -120,
                },
            },
        },

        AdvancedDebuffs = {
            Enabled = true,
            -- Name into db.global.AuraFilters, or a bare filter string. That table ships empty, so the
            -- default is the plain HARMFUL the GUI's "None" entry also stores (see Core/AuraFilters.lua).
            Filter = 'HARMFUL',
            -- Aura container options, names match Blizzard's (see Core/AuraContainer.lua).
            size = 50,
            perRow = 10,
            maxFrameCount = 10,
            elementSpacing = 1,
            lineSpacing = 1,
            horizontalGrowthDirection = "LEFT",
            verticalGrowthDirection = "UP",
            -- Enum key names, resolved against AuraContainerSortMethod/SortDirection at use time so
            -- this table stays free of Blizzard load-order dependencies (same reason filters use strings).
            sortMethod = "ExpirationOnly",
            sortDirection = "Normal",
            showApplicationCount = true,
            showDurationText = true,
            drawSwipe = false,
            drawEdge = false,
            reverseSwipe = true,
            showBorder = true,
            showDebuffDispelIcon = true,
            dispelIconSize = 12,
            tooltipHideInCombat = false,
            UseGlobalFont = true,
            FontFace = "Expressway",
            FontOutline = "OUTLINE",

            -- Per-string size and placement inside the aura button. Face/outline/shadow above are
            -- shared by both. AnchorFrom doubles as the relative point (see FontCore SetFontJustify).
            StackFont = {
                FontSize = 14,
                Position = {
                    AnchorFrom = "BOTTOMRIGHT",
                    XOffset = -1,
                    YOffset = 1
                },
            },
            DurationFont = {
                FontSize = 18,
                Position = {
                    AnchorFrom = "CENTER",
                    XOffset = 0,
                    YOffset = 0
                },
            },

            FontShadow = {
                Enabled = false,
                Color = { 0, 0, 0, 1 },
                OffsetX = 1,
                OffsetY = -1,
            },
            anchorFrameType = "SELECTFRAME",
            ParentFrame = "NUF_Player",
            Position = {
                AnchorFrom = "BOTTOMRIGHT",
                AnchorTo = "TOPRIGHT",
                XOffset = 0,
                YOffset = 120
            },
        },

        Defensives = {
            Enabled = true,
            Filter = 'HELPFUL',
            -- Aura container options, names match Blizzard's (see Core/AuraContainer.lua).
            size = 50,
            perRow = 10,
            maxFrameCount = 10,
            elementSpacing = 1,
            lineSpacing = 1,
            horizontalGrowthDirection = "LEFT",
            verticalGrowthDirection = "UP",
            -- Enum key names, resolved against AuraContainerSortMethod/SortDirection at use time so
            -- this table stays free of Blizzard load-order dependencies (same reason filters use strings).
            sortMethod = "ExpirationOnly",
            sortDirection = "Normal",
            showApplicationCount = true,
            showDurationText = true,
            drawSwipe = false,
            drawEdge = false,
            reverseSwipe = true,
            tooltipHideInCombat = false,
            UseGlobalFont = true,
            FontFace = "Expressway",
            FontOutline = "OUTLINE",

            -- Per-string size and placement inside the aura button. Face/outline/shadow above are
            -- shared by both. AnchorFrom doubles as the relative point (see FontCore SetFontJustify).
            StackFont = {
                FontSize = 14,
                Position = {
                    AnchorFrom = "BOTTOMRIGHT",
                    XOffset = -1,
                    YOffset = 1
                },
            },
            DurationFont = {
                FontSize = 18,
                Position = {
                    AnchorFrom = "CENTER",
                    XOffset = 0,
                    YOffset = 0
                },
            },

            FontShadow = {
                Enabled = false,
                Color = { 0, 0, 0, 1 },
                OffsetX = 1,
                OffsetY = -1,
            },
            anchorFrameType = "SELECTFRAME",
            ParentFrame = "NUF_Player",
            Position = {
                AnchorFrom = "BOTTOMRIGHT",
                AnchorTo = "TOPRIGHT",
                XOffset = 0,
                YOffset = 90
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
            -- Cursor Circle Settings
            CursorCircle = {
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
        UnitFrames = {
            Enabled = true,
            General = {
                UseGlobalBar = true,
                statusBar = "NorskenUI",
                BackgroundTexture = "", -- "" = match the foreground texture
                UseGlobalFont = true,
                FontFace = "Expressway",
                FontOutline = "OUTLINE",
                Smooth = true,
                Range = {
                    Enabled = true,
                    InsideAlpha = 1,
                    OutsideAlpha = 0.6,
                },
                ColorByClass = false,
                ColorByPower = true,
                CastbarColorByClass = true,
                ForegroundAlphaWhenColorByClass = 1,
                Colors = {
                    Foreground = { 0, 0, 0, 0.8 },
                    Background = { 0.5, 0.5, 0.5, 1 },
                    BackgroundWhenColorByClass = { 0, 0, 0, 0.8 },
                    Power = { 0.3, 0.5, 0.8, 1 },
                    Castbar = { 0.35, 0.55, 0.85, 1 },
                    CastbarNonInterruptible = { 0.7, 0.6, 0.2, 1 },
                    CastbarFail = { 0.8, 0.25, 0.2, 1 },
                    CastbarBackground = { 0, 0, 0, 0.8 },
                },
                SafeZone = {
                    Enabled = true,
                    Color = { 0.8, 0.1, 0.1, 0.35 },
                },
                HealAbsorb = {
                    Enabled = true,
                    UseGlobalBar = false,
                    StatusBarTexture = "StripesThick",
                    Color = { 0.4, 0, 0.8, 0.5 },
                },
                DamageAbsorb = {
                    Enabled = true,
                    UseGlobalBar = false,
                    StatusBarTexture = "StripesThick",
                    Color = { 0, 0.39, 0.88, 0.81 },
                },
                Highlight = {
                    Enabled = false,
                    UseGlobalBar = false,
                    StatusBarTexture = "NorskenUI",
                    Color = { 1, 1, 1, 0.1 },
                },
            },
            TagSettings = {
                Separator = "»",
                UpdateInterval = 0.5,
            },
            Units = {
                ["**"] = {
                    Enabled = true,
                    Width = 220,
                    Height = 42,
                    anchorFrameType = "UIPARENT",
                    ParentFrame = "UIParent",
                    Strata = "MEDIUM",
                    Position = { AnchorFrom = "CENTER", AnchorTo = "CENTER", XOffset = 0, YOffset = 0 },
                    Health = {
                        Enabled = true,
                        StatusBarTexture = nil,
                        BackgroundTexture = "", -- "" = follow General.BackgroundTexture
                        UseGlobalColors = true,
                        ColorByClass = false,
                        UseGlobalSmooth = true,
                        Smooth = false,
                        Inverse = false,
                        Foreground = { 0, 0, 0, 0.8 },
                        Background = { 0.5, 0.5, 0.5, 1 },
                        BackgroundWhenColorByClass = { 0, 0, 0, 0.8 },
                        ForegroundAlphaWhenColorByClass = 1,
                        HealAbsorb = {
                            UseGlobal = true,
                            Enabled = true,
                            UseGlobalBar = false,
                            StatusBarTexture = "StripesThick",
                            Color = { 0.4, 0, 0.8, 0.5 },
                        },
                        DamageAbsorb = {
                            UseGlobal = true,
                            Enabled = true,
                            UseGlobalBar = false,
                            StatusBarTexture = "StripesThick",
                            Color = { 0, 0.39, 0.88, 0.81 },
                        },
                    },
                    Power = {
                        Enabled = true,
                        Height = 8,
                        StatusBarTexture = nil,
                        UseGlobalColors = true,
                        ColorByPower = true,
                        Color = { 0.3, 0.5, 0.8, 1 },
                        UseGlobalSmooth = true,
                        Smooth = true,
                    },
                    Tags = {
                        TagOne = {
                            Enabled = true,
                            Tag = "[nrsknuf:unit:smartcolor][nrsknuf:name<$|r]",
                            UseGlobalFont = true,
                            FontFace = "Expressway",
                            FontSize = 12,
                            FontOutline = "OUTLINE",
                            Color = { 1, 1, 1 },
                            BoundTo = "",
                            Position = { AnchorFrom = "TOPLEFT", AnchorTo = "TOPLEFT", XOffset = 4, YOffset = -6 },
                        },
                        TagTwo = {
                            Enabled = true,
                            Tag = "[nrsknuf:curhp:perhp]",
                            UseGlobalFont = true,
                            FontFace = "Expressway",
                            FontSize = 12,
                            FontOutline = "OUTLINE",
                            Color = { 1, 1, 1 },
                            BoundTo = "",
                            Position = { AnchorFrom = "BOTTOMLEFT", AnchorTo = "BOTTOMLEFT", XOffset = 4, YOffset = 6 },
                        },
                        TagThree = {
                            Enabled = true,
                            Tag = "[nrsknuf:perpower:smartcolor]",
                            UseGlobalFont = true,
                            FontFace = "Expressway",
                            FontSize = 12,
                            FontOutline = "OUTLINE",
                            Color = { 1, 1, 1 },
                            BoundTo = "",
                            Position = { AnchorFrom = "BOTTOMRIGHT", AnchorTo = "BOTTOMRIGHT", XOffset = -4, YOffset = 6 },
                        },
                        TagFour = {
                            Enabled = false,
                            Tag = "",
                            UseGlobalFont = true,
                            FontFace = "Expressway",
                            FontSize = 12,
                            FontOutline = "OUTLINE",
                            Color = { 1, 1, 1 },
                            BoundTo = "",
                            Position = { AnchorFrom = "CENTER", AnchorTo = "CENTER", XOffset = 0, YOffset = 0 },
                        },
                        TagFive = {
                            Enabled = false,
                            Tag = "",
                            UseGlobalFont = true,
                            FontFace = "Expressway",
                            FontSize = 12,
                            FontOutline = "OUTLINE",
                            Color = { 1, 1, 1 },
                            BoundTo = "",
                            Position = { AnchorFrom = "CENTER", AnchorTo = "CENTER", XOffset = 0, YOffset = 0 },
                        },
                    },
                    Indicators = {
                        Resting = {
                            Enabled = false,
                            Size = 20,
                            Position = { AnchorFrom = "TOPLEFT", AnchorTo = "TOPLEFT", XOffset = -4, YOffset = 16 },
                        },
                        Combat = {
                            Enabled = false,
                            Size = 20,
                            Position = { AnchorFrom = "TOPRIGHT", AnchorTo = "TOPRIGHT", XOffset = 4, YOffset = 16 },
                        },
                        ReadyCheck = {
                            Enabled = false,
                            Size = 20,
                            Position = { AnchorFrom = "CENTER", AnchorTo = "CENTER", XOffset = 0, YOffset = 0 },
                        },
                        Summon = {
                            Enabled = false,
                            Size = 24,
                            Position = { AnchorFrom = "BOTTOMLEFT", AnchorTo = "BOTTOMLEFT", XOffset = 2, YOffset = 2 },
                        },
                        Resurrect = {
                            Enabled = false,
                            Size = 24,
                            Position = { AnchorFrom = "CENTER", AnchorTo = "CENTER", XOffset = 0, YOffset = 0 },
                        },
                        Quest = {
                            Enabled = false,
                            Size = 16,
                            Position = { AnchorFrom = "TOPRIGHT", AnchorTo = "TOPRIGHT", XOffset = -4, YOffset = 0 },
                        },
                        PvP = {
                            Enabled = false,
                            Size = 24,
                            Position = { AnchorFrom = "TOPLEFT", AnchorTo = "TOPLEFT", XOffset = -8, YOffset = 8 },
                        },
                        Phase = {
                            Enabled = false,
                            Size = 20,
                            Position = { AnchorFrom = "CENTER", AnchorTo = "CENTER", XOffset = 0, YOffset = 0 },
                        },
                    },
                    Castbar = {
                        Enabled = true,
                        Height = 24,
                        StatusBarTexture = nil,
                        ShowIcon = true,
                        ShowSpellName = true,
                        ShowTime = true,
                        TimeToHold = 0.5,
                        UseGlobalColors = true,
                        ColorByClass = true,
                        Color = { 0.35, 0.55, 0.85, 1 },              -- interruptible / normal
                        NonInterruptibleColor = { 0.7, 0.6, 0.2, 1 }, -- shielded cast
                        FailColor = { 0.8, 0.25, 0.2, 1 },            -- interrupted / failed
                        Background = { 0, 0, 0, 0.8 },
                        SafeZone = {
                            UseGlobal = true, -- own override: the safe zone is a feature toggle, not a colour
                            Enabled = true,
                            Color = { 0.8, 0.1, 0.1, 0.35 },
                        },
                        Position = { AnchorFrom = "TOPLEFT", AnchorTo = "BOTTOMLEFT", XOffset = 0, YOffset = -10 },
                    },
                    RaidIcon = {
                        Enabled = true,
                        Size = 24,
                        Position = {
                            AnchorFrom = "CENTER",
                            AnchorTo = "TOP",
                            XOffset = 0,
                            YOffset = 0
                        },
                    },
                    LeaderIndicator = {
                        Enabled = false,
                        Size = 14,
                        Position = {
                            AnchorFrom = "BOTTOMLEFT",
                            AnchorTo = "TOPLEFT",
                            XOffset = 0,
                            YOffset = -2
                        },
                    },
                },
                player = {
                    Tags = {
                        TagThree = {
                            Enabled = false,
                        },
                    },

                    Indicators = {
                        Resting = {
                            Enabled = true,
                        },
                        Summon = {
                            Enabled = true,
                        },
                    },
                    anchorFrameType = "SELECTFRAME",
                    ParentFrame = "NRSKNUF_CDMAnchor",
                    Position = {
                        AnchorFrom = "RIGHT",
                        AnchorTo = "LEFT",
                        XOffset = -30,
                        YOffset = 0
                    },
                    LeaderIndicator = {
                        Enabled = true,
                    },
                    Power = {
                        Enabled = false,
                    },
                    Castbar = {
                        Enabled = false,
                    },
                },
                target = {
                    Indicators = {
                        Summon = {
                            Enabled = true,
                        },
                        Quest = {
                            Enabled = true,
                        },
                    },
                    anchorFrameType = "SELECTFRAME",
                    ParentFrame = "NRSKNUF_CDMAnchor",
                    Position = {
                        AnchorFrom = "LEFT",
                        AnchorTo = "RIGHT",
                        XOffset = 30,
                        YOffset = 0
                    },
                    LeaderIndicator = {
                        Enabled = true,
                    },
                    Power = {
                        Enabled = false,
                    },
                    Castbar = {
                        Position = {
                            AnchorFrom = "TOPLEFT",
                            AnchorTo = "BOTTOMLEFT",
                            XOffset = 0,
                            YOffset = -1,
                        },
                    },
                },
                targettarget = {
                    Width = 110,
                    Height = 22,
                    Power = {
                        Enabled = false,
                    },
                    Castbar = {
                        Enabled = false,
                    },
                    Tags = {
                        TagOne = {
                            BoundTo = "frame",
                            Position = {
                                AnchorFrom = "LEFT",
                                AnchorTo = "LEFT",
                                XOffset = 4,
                                YOffset = 0
                            }
                        },
                        TagTwo = {
                            Enabled = false
                        },
                        TagThree = {
                            Enabled = false
                        },

                    },
                    anchorFrameType = "SELECTFRAME",
                    ParentFrame = "NUF_Target",
                    Position = {
                        AnchorFrom = "LEFT",
                        AnchorTo = "RIGHT",
                        XOffset = 1,
                        YOffset = 10
                    },
                },
                focus = {
                    Position = {
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        XOffset = 560,
                        YOffset = -130
                    },
                    Power = {
                        Enabled = false,
                    },
                    Castbar = {
                        Enabled = true,
                        Position = {
                            AnchorFrom = "TOPLEFT",
                            AnchorTo = "BOTTOMLEFT",
                            XOffset = 0,
                            YOffset = -1,
                        },
                    },
                },
                focustarget = {
                    Width = 110,
                    Height = 22,
                    Power = {
                        Enabled = false,
                    },
                    Castbar = {
                        Enabled = false,
                    },
                    Tags = {
                        TagOne = {
                            BoundTo = "frame",
                            Position = {
                                AnchorFrom = "LEFT",
                                AnchorTo = "LEFT",
                                XOffset = 4,
                                YOffset = 0
                            }
                        },
                        TagTwo = {
                            Enabled = false,
                        },
                        TagThree = {
                            Enabled = false
                        },
                    },
                    anchorFrameType = "SELECTFRAME",
                    ParentFrame = "NUF_Focus",
                    Position = {
                        AnchorFrom = "LEFT",
                        AnchorTo = "RIGHT",
                        XOffset = 1,
                        YOffset = 10
                    }
                },
                pet = {
                    Width = 110,
                    Height = 22,
                    anchorFrameType = "SELECTFRAME",
                    ParentFrame = "NUF_Player",
                    Position = {
                        AnchorFrom = "TOPLEFT",
                        AnchorTo = "BOTTOMLEFT",
                        XOffset = 0,
                        YOffset = -20
                    },
                    Tags = {
                        TagOne = {
                            BoundTo = "frame",
                            Position = {
                                AnchorFrom = "LEFT",
                                AnchorTo = "LEFT",
                                XOffset = 4,
                                YOffset = 0
                            }
                        },
                        TagTwo = {
                            Enabled = false
                        },
                        TagThree = {
                            Enabled = false
                        },
                    },
                    Power = {
                        Enabled = false,
                    },
                },
                pettarget = {
                    Width = 109,
                    Height = 22,
                    Power = {
                        Enabled = false,
                    },
                    Castbar = {
                        Enabled = false,
                    },
                    Tags = {
                        TagOne = {
                            BoundTo = "frame",
                            Position = {
                                AnchorFrom = "LEFT",
                                AnchorTo = "LEFT",
                                XOffset = 4,
                                YOffset = 0
                            }
                        },
                        TagTwo = {
                            Enabled = false
                        },
                        TagThree = {
                            Enabled = false
                        },
                    },
                    anchorFrameType = "SELECTFRAME",
                    ParentFrame = "NUF_Pet",
                    Position = {
                        AnchorFrom = "LEFT",
                        AnchorTo = "RIGHT",
                        XOffset = 1,
                        YOffset = 0
                    },
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

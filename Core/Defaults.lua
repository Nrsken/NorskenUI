---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Default settings table
---@type NRSKNUI.DBDefaults
local Defaults = {
    global = {
        UseGlobalProfile = false,
        GlobalProfile = "Default",
        GUIState = {
            frame = {
                point = nil,
                relativePoint = nil,
                xOffset = nil,
                yOffset = nil,
                width = nil,
                height = nil,
            },
            sidebarExpanded = nil,
        },
        XPTable = {},
        SpellAlertCVars = {},
        CDMLayoutCache = {},
        SidebarCollapsed = { ['*'] = {} }, -- [page][section key] = true, closed mini sidebar sections
        QuestTracker = {
            quests = {},     -- ordered { questID, title?, name?, account? }
            characters = {}, -- [GUID] = { guid, name, realm, classFile, level, enabled, lastUpdate, quests = { [questID] = state } }
        },
    },
    profile = {
        Theme = {
            mode           = "preset",
            selectedPreset = "NUI Neon",
            customColors   = {},
            fontFace       = "Interface\\AddOns\\NorskenUI\\Media\\Fonts\\Expressway.TTF",
            fontSizeNormal = 12,
            fontSizeSmall  = 12,
            fontSizeLarge  = 16,
            fontOutline    = "OUTLINE",
            fontShadow     = false,
            windowOpacity  = 1,     -- how solid the settings window is, 0.3-1
            zoneContrast   = 1,     -- spacing between the window zones' tones, 0.5-2
            surfaceTint    = 1,     -- how much of the base hue the surfaces carry, 0-3
        },
        -- UIParent scale.
        UIScale = {
            Enabled = false,
            Scale   = 0.71,
        },
        -- Aura indicator definitions, referenced by key from each unit's placements.
        AuraIndicators = {
            ['builtin:defensives'] = { name = "Defensives", Trigger = { Type = 'Preset', Preset = 'preset:defensives' }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.25, 0.78, 0.92, 1 }, },
            ['builtin:renewingmist'] = { name = "|cFF00ff96Renewing Mist|r", Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [119611] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0, 0.9, 0.5, 1 }, },
            ['builtin:envelopingmist'] = { name = "|cFF00ff96Enveloping Mist|r", Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [124682] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0.78, 0, 1 }, },
            ['builtin:rejuvenation'] = { name = "|cFFff7c0aRejuvenation|r", Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [774] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0, 0.85, 1 }, },
            ['builtin:rejuvgermination'] = { name = "|cFFff7c0aRejuvenation (Germination)|r", Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [155777] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0, 0.78, 0.9, 1 }, },
            ['builtin:regrowth'] = { name = "|cFFff7c0aRegrowth|r", Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [8936] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.7, 0.9, 0, 1 }, },
            ['builtin:lifebloom'] = { name = "|cFFff7c0aLifebloom|r", Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [33763] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.47, 0.9, 0, 1 }, },
            ['builtin:wildGrowth'] = { name = "|cFFff7c0aWild Growth|r", Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [48438] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0, 0.9, 0.6, 1 }, },
            ['builtin:echo'] = { name = "|cFF33937fEcho|r", Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [364343] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0.47, 0, 1 }, },
            ['builtin:reversion'] = { name = "|cFF33937fReversion|r", Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [367364] = true, [366155] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0.79, 0, 1 }, },
            ['builtin:lifebind'] = { name = "|cFF33937fLifebind|r", Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [373267] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0, 0, 1 }, },
            ['builtin:dreambreath'] = { name = "|cFF33937fDream Breath|r", Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [355941] = true, [376788] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0, 0.9, 0.6, 1 }, },
            ['builtin:riptide'] = { name = "|cFF0070ddRiptide|r", Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [61295] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0, 0.51, 0.9, 1 }, },
            ['builtin:eternalflame'] = { name = "|cFFf48cbaEternal Flame|r", Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [156322] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0.7, 0, 1 }, },
        },
        AuraIndicatorGroups = {},
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
                [4] = { 1, 0.96, 0.41 },           -- Combo Points
                [5] = { 0.5, 0.5, 0.5 },           -- Runes
                [7] = { 0.5, 0.32, 0.55 },         -- Soul Shards
                [9] = { 0.95, 0.9, 0.6 },          -- Holy Power
                [12] = { 0.71, 1, 0.92 },          -- Chi
                [16] = { 0.1, 0.1, 0.98 },         -- Arcane Charges
                [19] = { 0.392, 0.678, 0.808 },    -- Essence (oUF's, Blizzard has none)
            },
            -- oUF's rune colors per Death Knight spec: Blood, Frost, Unholy.
            Runes = {
                [1] = { 0.969, 0.255, 0.224 },
                [2] = { 0.580, 0.796, 0.969 },
                [3] = { 0.678, 0.922, 0.259 },
            },
            -- Blizzard's PowerBarColor.STAGGER: light, moderate, heavy.
            Stagger = {
                [1] = { 0.52, 1, 0.52 },
                [2] = { 1, 0.98, 0.72 },
                [3] = { 1, 0.42, 0.42 },
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
            profileBar = { statusBar = "NorskenUI" },
            profileSpark = { sparkTexture = "Solid", Scale = 1, Width = 2, color = { 1, 1, 1, 1 } },
            profileBorder = { BorderColor = { 0, 0, 0, 1 }, BackdropColor = { 0, 0, 0, 0.8 } },
            -- Addons global formatter defaults.
            durationBreakpointColors = true,
            durationCurveColors = false,
            durationSingleColor = false,
            profileBreakPoints = {
                pointOne = { threshold = 0, step = 0.1, format = '%0.1f', },
                pointTwo = { threshold = 1, step = 1, format = '%d', },
                pointThree = { threshold = 60, format = '%d:%02d', },
                pointFour = { threshold = 600, format = '%dm', },
                pointFive = { threshold = 3600, format = '%dh', },
                pointSix = { threshold = 86400, format = '%dd', },
            },
            profileColorCurve = {
                colorOne = { 1, 0.25, 0.25, 1 },
                colorTwo = { 1.00, 0.25, 0.25, 1 },
                colorThree = { 1.00, 0.75, 0.20, 1 },
                colorFour = { 1.00, 0.95, 0.70, 1 },
                colorFive = { 1.00, 0.95, 0.70, 1 },
                colorSix = { 1.00, 0.95, 0.70, 1 },
            },
            profileColorBreakPoint = {
                colorOne = { 1, 0.25, 0.25, 1 },
                colorTwo = { 1, 1, 1, 1 },
                colorThree = { 1, 1, 1, 1 },
                colorFour = { 1, 1, 1, 1 },
                colorFive = { 1, 1, 1, 1 },
                colorSix = { 1, 1, 1, 1 },
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
        -- Reroll Keystone
        RerollKeystone = {
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
        },
        CharacterPanel = {
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
        -- UnitFrame Integration
        UseOtherUF = {
            Enabled = true,
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
            UseGlobalBorder = true,
            UseGlobalBackdrop = true,
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
            UseGlobalBorder = true,
            UseGlobalBackdrop = true,
            BackgroundColor = { 0, 0, 0, 0.8 },
            BorderColor = { 0, 0, 0, 1 },
            BackdropWidth = 4,
            BackdropHeight = 4,
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
                size = 40,
                perRow = 10,
                maxFrameCount = 38,
                previewLimit = 40,
                elementSpacing = 1,
                lineSpacing = 1,
                groupSpacing = 0, -- seam between the weapon enchants and the buff group
                groupLineSpacing = 0,
                horizontalGrowthDirection = "LEFT",
                verticalGrowthDirection = "DOWN",
                sortMethod = "AuraInstanceIDOnly",
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
                StackFont = {
                    FontSize = 12,
                    Position = {
                        AnchorFrom = "BOTTOMRIGHT",
                        XOffset = 0,
                        YOffset = 2,
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
                    XOffset = -234,
                    YOffset = -1,
                },
            },
            Debuffs = {
                Enabled = true,
                -- Aura container options, names match Blizzard's (see Core/AuraContainer.lua).
                size = 46,
                perRow = 8,
                maxFrameCount = 8,
                previewLimit = 8,
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
                showBorderWithoutDispelType = true,
                showDebuffDispelIcon = true,
                dispelIconSize = 16,
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
                        XOffset = 0,
                        YOffset = 2,
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
                    XOffset = -234,
                    YOffset = -218,
                },
            },
        },

        -- Miscellaneous Settings
        Miscellaneous = {
            SpellAlert = {
                Enabled = false,
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

            GroupFinder = {
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
            SkyRiding = {
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
            },
            Tweaks = {
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
            },

            CooldownStrings = {
                Enabled = true,
                Profiles = {},
            },
            QuestTracker = {
                Enabled = false,
                CharacterTabOnly = false,
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
            },
        },

        -- Instance Reset Message
        InstanceReset = {
            Enabled = true,
            Message = "Instance reset!",
        },
        BigWigsTimers = {
            Enabled = false,
            -- Bar group
            Bars = {
                Width = 180,
                Height = 22,
                Config = {
                    Grow = "UP",
                    Align = "CENTER",
                    Spacing = 1,
                    UseLimit = true,
                    Limit = 2,
                },
                Strata = "HIGH",
                anchorFrameType = "UIPARENT",
                ParentFrame = "UIParent",
                Position = {
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    XOffset = 0,
                    YOffset = -128,
                },
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
                UseGlobalBar = true,
                StatusBarTexture = "NorskenUI",
                Icon = {
                    Enabled = true,
                },
                UseGlobalBorder = true,
                UseGlobalBackdrop = true,
                BackdropColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },
            },
            -- Text group
            Texts = {
                Config = {
                    Grow = "DOWN",
                    Align = "CENTER",
                    Spacing = 0,
                    UseLimit = true,
                    Limit = 3,
                },
                Strata = "HIGH",
                anchorFrameType = "UIPARENT",
                ParentFrame = "UIParent",
                Position = {
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    XOffset = 0,
                    YOffset = 136,
                },
                UseGlobalFont = true,
                FontFace = "Expressway",
                FontSize = 20,
                FontOutline = "OUTLINE",
                FontShadow = {
                    Enabled = false,
                    Color = { 0, 0, 0, 1 },
                    OffsetX = 1,
                    OffsetY = -1,
                },
            },
            -- Per-instance triggers, keyed by the instance ID BigWigs menus use
            Instances = {},
            -- Template copied on every new trigger
            TriggerDefaults = {
                Enabled = true,
                Name = "New Timer",
                TriggerType = "timer",
                -- Match
                BossId = 0,
                SpellId = "",
                Message = "",
                MessageOperator = "find",
                UseRemaining = true,
                RemainingOperator = "<",
                Remaining = 5,
                Offset = 0,
                Count = "",
                ShowCasts = "show",
                -- Announce
                Duration = 3,
                -- Display
                DisplayType = "bar",
                UseBigWigsColors = true,
                BarColor = { 0.772, 0.168, 0.168, 1 },
                TextColor = { 1, 1, 1, 1 },
                LeftText = "%n",
                RightText = "%t",
                Text = "%n » %t",
                ShowDecimals = true,
                DecimalThreshold = 1,
                -- Actions
                ActionOnShowSound = "None",
                ActionOnHideSound = "None",
                LoadConditions = {
                    Enabled = false,
                    SelectedCategory = "Instance",
                    Instance = { Types = {} },
                    Group = { Types = {} },
                    Combat = {},
                    Role = { Types = {} },
                    Position = { Types = {} },
                },
            },
        },
        -- Dungeon enemy cast bars
        DungeonCasts = {
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
        MissingBuffs = {
            Enabled = true,
            RaidBuffMode = "group",
            ClickToCast = true,
            FlyoutModifier = "shift",
            FlyoutDirection = "UP",
            -- Consumable item each spec picked, per item list
            Remembered = {
                ['*'] = {},
            },
            Groups = {
                Raid = {
                    IconSize = 40,
                    UseGlobalBorder = true,
                    BorderColor = { 0, 0, 0, 1 },
                    Config = {
                        Grow = "HORIZONTAL",
                        Align = "CENTER",
                        Spacing = 1,
                    },
                    Strata = "HIGH",
                    anchorFrameType = "UIPARENT",
                    ParentFrame = "UIParent",
                    Position = {
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        XOffset = 0,
                        YOffset = 220,
                    },
                    UseGlobalFont = true,
                    FontFace = "Expressway",
                    FontSize = 13,
                    FontOutline = "OUTLINE",
                    FontShadow = {
                        Enabled = false,
                        Color = { 0, 0, 0, 1 },
                        OffsetX = 1,
                        OffsetY = -1,
                    },
                    CountText = {
                        Position = { AnchorFrom = "CENTER", XOffset = 0, YOffset = 0 },
                    },
                    TimerText = {
                        Position = { AnchorFrom = "CENTER", XOffset = 0, YOffset = 0 },
                    },
                },
                Targeted = {
                    IconSize = 40,
                    UseGlobalBorder = true,
                    BorderColor = { 0, 0, 0, 1 },
                    Config = {
                        Grow = "HORIZONTAL",
                        Align = "CENTER",
                        Spacing = 1,
                    },
                    Strata = "HIGH",
                    anchorFrameType = "UIPARENT",
                    ParentFrame = "UIParent",
                    Position = {
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        XOffset = 0,
                        YOffset = 170,
                    },
                    UseGlobalFont = true,
                    FontFace = "Expressway",
                    FontSize = 13,
                    FontOutline = "OUTLINE",
                    FontShadow = {
                        Enabled = false,
                        Color = { 0, 0, 0, 1 },
                        OffsetX = 1,
                        OffsetY = -1,
                    },
                    CountText = {
                        Position = { AnchorFrom = "CENTER", XOffset = 0, YOffset = 0 },
                    },
                    TimerText = {
                        Position = { AnchorFrom = "CENTER", XOffset = 0, YOffset = 0 },
                    },
                },
            },
            -- Accepted runeforge enchantIDs per specID, empty = any rune
            -- Accepted runes per spec, TwoHand or dual wield MainHand + OffHand, none ticked accepts any rune
            Runeforge = {
                ['**'] = {
                    TwoHand = {},
                    MainHand = {},
                    OffHand = {},
                },
                [250] = { TwoHand = { [6241] = true, [3368] = true } },                   -- Blood: Sanguination, Fallen Crusader
                [251] = {                                                                -- Frost
                    TwoHand = { [3368] = true },                                         -- Fallen Crusader
                    MainHand = { [3370] = true, [3847] = true },                         -- Razorice, Stoneskin Gargoyle
                    OffHand = { [3368] = true },                                         -- Fallen Crusader
                },
                [252] = { TwoHand = { [6245] = true } },                                 -- Unholy: Apocalypse
            },
            -- Per buff settings, '**' reaches the keys listed below as well
            Buffs = {
                ['**'] = {
                    Enabled = true,
                    Expiring = 5, -- minutes left before a present buff shows, 0 = off
                    EmptyBagMode = "desaturate", -- item picker entries only
                    GlowEnabled = false,
                    GlowMode = "always",
                    GlowType = "pixel",
                    GlowColor = { 1, 0.8, 0, 1 },
                    GlowLines = 5,
                    GlowFrequency = 0.2,
                    GlowLength = 15,
                    GlowThickness = 2,
                    GlowBorder = true,
                    GlowScale = 1,
                    GlowStartAnim = false,
                    GlowDuration = 1,
                    LoadConditions = {
                        Enabled = false,
                        SelectedCategory = "Instance",
                        Instance = { Types = {} },
                        Group = { Types = {} },
                        Combat = {},
                        Role = { Types = {} },
                        Position = { Types = {} },
                    },
                },
                -- Raid
                MarkOfTheWild = { GlowEnabled = true, GlowColor = { 1, 0.04, 0.98, 1 } },
                ArcaneIntellect = { GlowEnabled = true, GlowColor = { 0.41, 0.8, 0.94, 1 } },
                BattleShout = { GlowEnabled = true, GlowColor = { 1, 0.78, 0, 1 } },
                PowerWordFortitude = { GlowEnabled = true, GlowColor = { 1, 1, 1, 1 } },
                Skyfury = { GlowEnabled = true, GlowColor = { 0, 1, 0.96, 1 } },
                BlessingOfTheBronze = { GlowEnabled = true, GlowColor = { 1, 0.8, 0.41, 1 } },
                -- Targeted
                BeaconOfLight = { GlowEnabled = true, GlowColor = { 1, 0.48, 0, 1 }, GlowLength = 10 },
                BeaconOfFaith = { GlowEnabled = true, GlowColor = { 0, 1, 1, 1 }, GlowLength = 10 },
                BlisteringScales = { GlowEnabled = true, GlowColor = { 1, 0.5, 0, 1 }, GlowLength = 10 },
                Timelessness = { GlowEnabled = true, GlowColor = { 1, 0.8, 0, 1 }, GlowLength = 10 },
                SourceOfMagic = { GlowEnabled = true, GlowColor = { 0, 0.82, 1, 1 }, GlowLength = 10 },
                EarthShield = { GlowEnabled = true, GlowColor = { 0.78, 1, 0, 1 }, GlowLength = 10 },
                SymbioticRelationship = { GlowEnabled = true, GlowColor = { 0.12, 1, 0, 1 }, GlowLength = 10 },
                LinkedSpirits = { GlowEnabled = true, GlowColor = { 0.12, 1, 0, 1 }, GlowLength = 10 },
                Weyrnstone = { GlowLength = 10 },
                -- Self
                RoguePoisons = { GlowEnabled = true, GlowColor = { 0.3, 1, 0, 1 } },
                GrimoireOfSacrifice = { GlowEnabled = true },
                -- Consumable
                Flask = { Expiring = 10, GlowEnabled = true, GlowColor = { 1, 0, 0, 1 } },
                AugmentRune = { Expiring = 10 },
                DelveFood = { Expiring = 10 },
                Food = { Expiring = 10 },
                Healthstone = { Expiring = 10 },
                MageFood = { Enabled = false, Expiring = 10 },
                InkyBlackPotion = { Enabled = false, EmptyBagMode = "hide" },
                WeaponOil = { Expiring = 10 },
                WeaponOilOffHand = { Expiring = 10 },
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
---@return NRSKNUI.DBDefaults
function NRSKNUI:GetDefaultDB()
    return Defaults
end

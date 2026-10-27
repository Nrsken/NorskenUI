---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Default settings table
---@type NRSKNUI.DBDefaults
local Defaults = {
    global = {
        UseGlobalProfile = false,
        GlobalProfile = "Default",
        Language = "auto", -- 'auto' follows the client, otherwise a locale from NRSKNUI.LANGUAGES
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
        NamespacePaths = {}, -- [namespace] = where its settings sat in the profile, when that isn't its name
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
        -- Shared color palette, built into NRSKNUI.Colors by NRSKNUI:LoadCustomColors().
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

        -- Instance Reset Message
        InstanceReset = {
            Enabled = true,
            Message = "Instance reset!",
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
---@return NRSKNUI.DBDefaults
function NRSKNUI:GetDefaultDB()
    return Defaults
end

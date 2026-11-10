---@class NRSKNUI
local NRSKNUI = _G.NorskenUI

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
        NamespacePaths = {}, -- [namespace] = where its settings sat in the profile, when that isn't its name
        SidebarCollapsed = { ['*'] = {} }, -- [page][section key] = true, closed mini sidebar sections
        QuestTracker = {
            quests = {},     -- ordered { questID, title?, name?, account? }
            characters = {}, -- [GUID] = { guid, name, realm, classFile, level, enabled, lastUpdate, quests = { [questID] = state } }
        },
    },
    profile = {
        Theme = CopyTable(NRSKNUI.ThemeDefaults),
        -- UIParent scale.
        UIScale = {
            Enabled = false,
            Scale   = 0.71,
        },
        -- Aura indicator definitions, referenced by key from each unit's placements.
        -- A shipped one's `category` is its folder under Presets in the GUI sidebar, a class token or a preset group.
        AuraIndicators = {
            ['builtin:defensives'] = { name = "Defensives", Trigger = { Type = 'Preset', Preset = 'preset:defensives' }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.25, 0.78, 0.92, 1 }, },
            -- Druid
            ['builtin:rejuvenation'] = { name = "Rejuvenation", category = 'DRUID', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [774] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0, 0.85, 1 }, },
            ['builtin:rejuvgermination'] = { name = "Rejuvenation (Germination)", category = 'DRUID', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [155777] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0, 0.78, 0.9, 1 }, },
            ['builtin:regrowth'] = { name = "Regrowth", category = 'DRUID', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [8936] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.7, 0.9, 0, 1 }, },
            ['builtin:lifebloom'] = { name = "Lifebloom", category = 'DRUID', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [33763] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.47, 0.9, 0, 1 }, },
            ['builtin:wildGrowth'] = { name = "Wild Growth", category = 'DRUID', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [48438] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0, 0.9, 0.6, 1 }, },
            ['builtin:symbioticblooms'] = { name = "Symbiotic Blooms", category = 'DRUID', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [439530] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0.35, 0.6, 1 }, },
            -- Evoker
            ['builtin:echo'] = { name = "Echo", category = 'EVOKER', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [364343] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0.47, 0, 1 }, },
            ['builtin:reversion'] = { name = "Reversion", category = 'EVOKER', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [367364] = true, [366155] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0.79, 0, 1 }, },
            ['builtin:lifebind'] = { name = "Lifebind", category = 'EVOKER', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [373267] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0, 0, 1 }, },
            ['builtin:dreambreath'] = { name = "Dream Breath", category = 'EVOKER', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [355941] = true, [376788] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0, 0.9, 0.6, 1 }, },
            ['builtin:dreamflight'] = { name = "Dream Flight", category = 'EVOKER', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [363502] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.3, 0.6, 0.9, 1 }, },
            -- Monk
            ['builtin:renewingmist'] = { name = "Renewing Mist", category = 'MONK', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [119611] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0, 0.9, 0.5, 1 }, },
            ['builtin:envelopingmist'] = { name = "Enveloping Mist", category = 'MONK', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [124682] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0.78, 0, 1 }, },
            ['builtin:soothingmist'] = { name = "Soothing Mist", category = 'MONK', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [115175] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.4, 0.9, 0.8, 1 }, },
            ['builtin:aspectofharmony'] = { name = "Aspect of Harmony", category = 'MONK', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [450769] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.6, 0.4, 0.9, 1 }, },
            ['builtin:strengthoftheblackox'] = { name = "Strength of the Black Ox", category = 'MONK', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [443113] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0.5, 0.2, 1 }, },
            -- Paladin
            ['builtin:eternalflame'] = { name = "Eternal Flame", category = 'PALADIN', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [156322] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0.7, 0, 1 }, },
            ['builtin:holybulwark'] = { name = "Holy Bulwark", category = 'PALADIN', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [432496] = true, [432607] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.95, 0.85, 0.4, 1 }, },
            ['builtin:sacredweapon'] = { name = "Sacred Weapon", category = 'PALADIN', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [432502] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0.3, 0.3, 1 }, },
            ['builtin:dawnlight'] = { name = "Dawnlight", category = 'PALADIN', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [431381] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0.55, 0.1, 1 }, },
            -- Priest
            ['builtin:powerwordshield'] = { name = "Power Word: Shield", category = 'PRIEST', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [17] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0.9, 0.5, 1 }, },
            ['builtin:atonement'] = { name = "Atonement", category = 'PRIEST', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [194384] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0.6, 0.2, 1 }, },
            ['builtin:voidshield'] = { name = "Void Shield", category = 'PRIEST', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [1253593] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.6, 0.3, 0.9, 1 }, },
            ['builtin:renew'] = { name = "Renew", category = 'PRIEST', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [139] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.3, 0.9, 0.4, 1 }, },
            ['builtin:echooflight'] = { name = "Echo of Light", category = 'PRIEST', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [77489] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.95, 0.85, 0.55, 1 }, },
            ['builtin:prayerofmending'] = { name = "Prayer of Mending", category = 'PRIEST', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [41635] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.4, 0.75, 0.95, 1 }, },
            -- Shaman
            ['builtin:riptide'] = { name = "Riptide", category = 'SHAMAN', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [61295] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0, 0.51, 0.9, 1 }, },
            ['builtin:earthshield'] = { name = "Earth Shield", category = 'SHAMAN', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [974] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.6, 0.45, 0.25, 1 }, },
            ['builtin:earthlivingweapon'] = { name = "Earthliving Weapon", category = 'SHAMAN', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [382024] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.35, 0.85, 0.3, 1 }, },
            ['builtin:ancestralvigor'] = { name = "Ancestral Vigor", category = 'SHAMAN', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [207400] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.9, 0.4, 0.2, 1 }, },
            ['builtin:hydrobubble'] = { name = "Hydrobubble", category = 'SHAMAN', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [444490] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.3, 0.8, 0.95, 1 }, },
            -- Trinkets
            ['builtin:soulcoiler'] = { name = "Soulcoiler Ritual Vessel", category = 'TRINKETS', Trigger = { Base = 'HELPFUL', Type = 'SpellIDs', OnlyMine = true, SpellIDs = { [1307578] = true } }, sortMethod = "ExpirationOnly", sortDirection = "Normal", Color = { 0.7, 0.4, 0.9, 1 }, },
        },
        AuraIndicatorGroups = {},
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

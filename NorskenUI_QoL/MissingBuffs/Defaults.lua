---@class NRSKNUI
local NRSKNUI = _G.NorskenUI

local MissingBuffs = NRSKNUI:GetModule('MissingBuffs')
MissingBuffs.Defaults = {
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
}

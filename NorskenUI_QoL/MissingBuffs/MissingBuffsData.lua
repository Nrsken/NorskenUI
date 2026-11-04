---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class MissingBuffsModule
local MissingBuffs = NRSKNUI:GetModule('MissingBuffs')

MissingBuffs.BronzeByClass = {
    DEATHKNIGHT = 381732,
    DEMONHUNTER = 381741,
    DRUID = 381746,
    EVOKER = 381748,
    HUNTER = 381749,
    MAGE = 381750,
    MONK = 381751,
    PALADIN = 381752,
    PRIEST = 381753,
    ROGUE = 381754,
    SHAMAN = 381756,
    WARLOCK = 381757,
    WARRIOR = 381758,
}

MissingBuffs.ClassBeneficiaries = {
    intellect = {
        MAGE = true,
        WARLOCK = true,
        PRIEST = true,
        DRUID = true,
        SHAMAN = true,
        MONK = true,
        EVOKER = true,
        PALADIN = true,
        DEMONHUNTER = true, -- Devourer
    },
    attackPower = {
        WARRIOR = true,
        ROGUE = true,
        HUNTER = true,
        DEATHKNIGHT = true,
        PALADIN = true,
        MONK = true,
        DRUID = true,
        DEMONHUNTER = true,
        SHAMAN = true,
    },
}

MissingBuffs.SpecBeneficiaries = {
    intellect = {
        [62] = true,
        [63] = true,
        [64] = true, -- Mage
        [256] = true,
        [257] = true,
        [258] = true, -- Priest
        [265] = true,
        [266] = true,
        [267] = true, -- Warlock
        [102] = true,
        [105] = true, -- Balance, Restoration Druid
        [262] = true,
        [264] = true, -- Elemental, Restoration Shaman
        [270] = true, -- Mistweaver
        [65] = true,  -- Holy Paladin
        [1467] = true,
        [1468] = true,
        [1473] = true, -- Evoker
        [1480] = true, -- Devourer
    },
    attackPower = {
        [71] = true,
        [72] = true,
        [73] = true, -- Warrior
        [259] = true,
        [260] = true,
        [261] = true, -- Rogue
        [253] = true,
        [254] = true,
        [255] = true, -- Hunter
        [250] = true,
        [251] = true,
        [252] = true, -- Death Knight
        [577] = true,
        [581] = true, -- Havoc, Vengeance
        [103] = true,
        [104] = true, -- Feral, Guardian
        [263] = true, -- Enhancement
        [268] = true,
        [269] = true, -- Brewmaster, Windwalker
        [66] = true,
        [70] = true,  -- Protection, Retribution
    },
}

-- Priority order: a kind short of poisons shows its first known missing ones.
MissingBuffs.Poisons = {
    lethal = {
        381664, -- Amplifying
        2823,   -- Deadly
        315584, -- Instant
        8679,   -- Wound
    },
    nonLethal = {
        381637, -- Atrophic
        5761,   -- Numbing
        3408,   -- Crippling
    },
}
MissingBuffs.DragonTemperedBlades = 381801

MissingBuffs.Runeforges = {
    { enchantID = 3368, spellID = 53344 },  -- Fallen Crusader
    { enchantID = 3370, spellID = 53343 },  -- Razorice
    { enchantID = 3847, spellID = 62158 },  -- Stoneskin Gargoyle
    { enchantID = 6241, spellID = 326805 }, -- Sanguination
    { enchantID = 6242, spellID = 326855 }, -- Spellwarding
    { enchantID = 6244, spellID = 326977 }, -- Unending Thirst
    { enchantID = 6245, spellID = 327082 }, -- Apocalypse
}

-- Classes whose weapon imbue replaces an oil or stone.
MissingBuffs.WeaponImbueSpells = {
    382021, -- Earthliving Weapon
    318038, -- Flametongue Weapon
    33757,  -- Windfury Weapon
    433583, -- Rite of Adjuration
    433568, -- Rite of Sanctification
}

-- Hero choice nodes the spellbook reports both sides of, even after the hero tree is swapped away.
MissingBuffs.HeroChoiceSpells = {
    PALADIN = {
        433583, -- Rite of Adjuration
        433568, -- Rite of Sanctification
    },
}

-- Items a consumable click uses, first one in the bags wins. Feasts and recovery-only food are left out.
MissingBuffs.ConsumableItems = {
    Flask = {
        245926, 245927, -- Fleeting Thalassian Resistance
        245928, 245929, -- Fleeting Shattered Sun
        245930, 245931, -- Fleeting Blood Knights
        245932, 245933, -- Fleeting Magisters
        241321, 241320, -- Thalassian Resistance
        241327, 241326, -- Shattered Sun
        241325, 241324, -- Blood Knights
        241323, 241322, -- Magisters
        241335, 241334, -- Vicious Thalassian Flask of Honor
    },
    AugmentRune = {
        274797, -- Tidesworn
        259085, -- Void-Touched
        243191, -- Ethereal
        246492, -- Soulgorged
        224572, -- Crystallized
    },
    Food = {
        -- Hearty, persists through death
        268679, 268680, 267000, 266986, 242747, 242744, 242745, 242746,
        242748, 242749, 242750, 242751, 242752, 242753, 242754, 242755, 242756, 242757, 242758, 242759,
        242760, 242761, 242762, 242763, 242764, 242765, 242766, 242767, 242768, 242769, 242770, 242771,
        242772, 242773, 242774, 242775, 242776,
        -- Regular
        275258, 275260, 275261, 255847, 255848, 242275, 242272, 242273, 242274,
        242276, 242277, 242278, 242279, 242280, 242281, 242282, 242283, 242284, 242285, 242286, 242287,
        242288, 242289, 242290, 242291, 242292, 242293, 242294, 242295, 242296, 242302, 242303, 242304,
        242305, 242306, 242307, 242308, 242309,
    },
    InkyBlackPotion = {
        124640,
    },
    WeaponOil = {
        { itemID = 243734 }, { itemID = 243733 },                                               -- Thalassian Phoenix Oil
        { itemID = 243736 }, { itemID = 243735 },                                               -- Oil of Dawn
        { itemID = 243738 }, { itemID = 243737 },                                               -- Smuggler's Enchanted Edge
        { itemID = 237371, weaponType = 'bladed' }, { itemID = 237370, weaponType = 'bladed' }, -- Refulgent Whetstone
        { itemID = 237369, weaponType = 'blunt' }, { itemID = 237367, weaponType = 'blunt' },   -- Refulgent Weightstone
        { itemID = 257750, weaponType = 'ranged' }, { itemID = 257749, weaponType = 'ranged' }, -- Laced Zoomshots
        { itemID = 257752, weaponType = 'ranged' }, { itemID = 257751, weaponType = 'ranged' }, -- Weighted Boomshots
    },
}

-- Free cauldron flasks: used first when present, never remembered as a spec's choice.
MissingBuffs.FleetingItems = {
    [245926] = true,
    [245927] = true,
    [245928] = true,
    [245929] = true,
    [245930] = true,
    [245931] = true,
    [245932] = true,
    [245933] = true,
}

do
    local W = Enum.ItemWeaponSubclass
    MissingBuffs.WeaponTypes = {
        [W.Axe1H] = 'bladed',
        [W.Axe2H] = 'bladed',
        [W.Sword1H] = 'bladed',
        [W.Sword2H] = 'bladed',
        [W.Dagger] = 'bladed',
        [W.Polearm] = 'bladed',
        [W.Warglaive] = 'bladed',
        [W.Mace1H] = 'blunt',
        [W.Mace2H] = 'blunt',
        [W.Staff] = 'blunt',
        [W.Unarmed] = 'blunt',
        [W.Bows] = 'ranged',
        [W.Guns] = 'ranged',
        [W.Crossbow] = 'ranged',
        [W.Wand] = 'ranged',
    }
end

MissingBuffs.FoodIcon = 136000
MissingBuffs.EatingIcon = 133950
MissingBuffs.DelveDifficulty = 208
MissingBuffs.FollowerDifficulty = 205

---@type table<MissingBuffs.Category, MissingBuffs.Entry[]>
MissingBuffs.Data = {
    Raid = {
        { key = 'ArcaneIntellect', nameSpellID = 1459, spellID = { 1459, 432778 }, class = 'MAGE',    levelRequired = 8,  benefit = 'intellect' },
        { key = 'BattleShout', nameSpellID = 6673,     spellID = 6673,             class = 'WARRIOR', levelRequired = 10, benefit = 'attackPower' },
        {
            key = 'BlessingOfTheBronze', nameSpellID = 364342,
            spellID = { 381732, 381741, 381746, 381748, 381749, 381750, 381751, 381752, 381753, 381754, 381756, 381757, 381758 },
            castSpellID = 364342,
            class = 'EVOKER',
            levelRequired = 30,
            perClass = MissingBuffs.BronzeByClass,
            playersOnly = true,
        },
        { key = 'MarkOfTheWild', nameSpellID = 1126,      spellID = { 1126, 432661 }, class = 'DRUID',  levelRequired = 10 },
        { key = 'PowerWordFortitude', nameSpellID = 21562, spellID = 21562,            class = 'PRIEST', levelRequired = 10 },
        { key = 'Skyfury', nameSpellID = 462854,            spellID = 462854,           class = 'SHAMAN', levelRequired = 16 },
    },

    Presence = {
        {
            key = 'AtrophicNumbingPoison',
            spellID = { 381637, 5761 },
            class = 'ROGUE',
            levelRequired = 80,
            groupOnly = true,
            suppressedBy = { 'AtrophicPoison', 'NumbingPoison' },
        },
        {
            key = 'DevotionAura', nameSpellID = 465,
            spellID = 465,
            outdoorSpellID = { 465, 32223, 317920 }, -- Crusader and Concentration Aura do outside instances
            class = 'PALADIN',
            levelRequired = 10,
            unsafeRestricted = true,
        },
        {
            key = 'Soulstone', nameSpellID = 20707,
            spellID = 20707,
            class = 'WARLOCK',
            levelRequired = 13,
            readyCheckOnly = true,
            hideOnCooldown = true,
            noExpiry = true,
            targeted = true,
        },
    },

    Targeted = {
        {
            key = 'BeaconOfLight', nameSpellID = 53563,
            spellID = 53563,
            class = 'PALADIN',
            specID = 65,
            excludeSpellID = 200025, -- Beacon of Virtue
            icon = 236247,
            glowDetectable = true,
        },
        { key = 'BeaconOfFaith', nameSpellID = 156910,         spellID = 156910,             class = 'PALADIN',     specID = 65,             excludeSpellID = 200025, glowDetectable = true },
        { key = 'BlisteringScales', nameSpellID = 360827,      spellID = 360827,             class = 'EVOKER',      specID = 1473 },
        { key = 'EarthShield', nameSpellID = 974,           spellID = 974,                class = 'SHAMAN' },
        { key = 'LinkedSpirits', nameSpellID = 434774,         spellID = 434763,             class = 'MONK',        requiresSpellID = 434774 },
        { key = 'SourceOfMagic', nameSpellID = 369459,         spellID = 369459,             class = 'EVOKER',      role = 'HEALER' },
        { key = 'SymbioticRelationship', nameSpellID = 474750, spellID = 474750,             casterBuffID = 474754, class = 'DRUID' },
        { key = 'Timelessness', nameSpellID = 412710,          spellID = 412710,             class = 'EVOKER',      specID = 1473 },
        { key = 'Weyrnstone',            spellID = { 408233, 410318 }, castSpellID = 408233,  casterBuffID = 410318,   class = 'EVOKER' },
    },

    Self = {
        { key = 'ArcaneFamiliar', nameSpellID = 205022,       spellID = 210126,                 castSpellID = 1459,   requiresSpellID = 205022, class = 'MAGE' }, -- summoned by Arcane Intellect
        { key = 'Attunement',           spellID = { 403264, 403265 },     class = 'EVOKER',     specID = 1473,            requiresSpellID = 403208 },
        { key = 'GrimoireOfSacrifice', nameSpellID = 108503,  spellID = 196099,                 castSpellID = 108503, class = 'WARLOCK' },
        { key = 'RiteOfAdjuration', nameSpellID = 433583,     spellID = 433584,                 castSpellID = 433583, class = 'PALADIN',        enchantID = 7144,         noExpiry = true,                useWeapon = true },
        { key = 'RiteOfSanctification', nameSpellID = 433568, spellID = 433550,                 castSpellID = 433568, class = 'PALADIN',        enchantID = 7143,         noExpiry = true,                useWeapon = true },
        -- One icon per poison, so a refresh shows the one running out; all configured as Rogue Poisons.
        { key = 'AmplifyingPoison',     castSpellID = 381664,             class = 'ROGUE',      poison = 'lethal',        check = 'Poisons',        settingsKey = 'RoguePoisons' },
        { key = 'DeadlyPoison',         castSpellID = 2823,               class = 'ROGUE',      poison = 'lethal',        check = 'Poisons',        settingsKey = 'RoguePoisons' },
        { key = 'RoguePoisons',         castSpellID = 315584,             class = 'ROGUE',      poison = 'lethal',        check = 'Poisons' }, -- Instant
        { key = 'WoundPoison',          castSpellID = 8679,               class = 'ROGUE',      poison = 'lethal',        check = 'Poisons',        settingsKey = 'RoguePoisons' },
        { key = 'AtrophicPoison',       castSpellID = 381637,             class = 'ROGUE',      poison = 'nonLethal',     check = 'Poisons',        settingsKey = 'RoguePoisons' },
        { key = 'NumbingPoison',        castSpellID = 5761,               class = 'ROGUE',      poison = 'nonLethal',     check = 'Poisons',        settingsKey = 'RoguePoisons' },
        { key = 'CripplingPoison',      castSpellID = 3408,               class = 'ROGUE',      poison = 'nonLethal',     check = 'Poisons',        settingsKey = 'RoguePoisons' },
        { key = 'Runeforge',            castSpellID = 53428,              class = 'DEATHKNIGHT', icon = 237523,       check = 'Runeforge',      noExpiry = true },
        -- Only Frost dual wields. Its own icon, but configured on the Runeforge page.
        { key = 'RuneforgeOffHand',     castSpellID = 53428,              class = 'DEATHKNIGHT', specID = 251,        icon = 237523,            check = 'Runeforge',      enchantSlot = 'offhand',  noExpiry = true, settingsKey = 'Runeforge' },
        -- Shaman imbues
        { key = 'EarthlivingWeapon', nameSpellID = 382021,    castSpellID = 382021,             class = 'SHAMAN',     enchantID = 6498 },
        { key = 'FlametongueWeapon', nameSpellID = 318038,    castSpellID = 318038,             class = 'SHAMAN',     enchantID = 5400 },
        { key = 'TidecallersGuard', nameSpellID = 457481,     castSpellID = 457481,             class = 'SHAMAN',     specID = 264,             enchantID = 7528,         enchantSlot = 'offhand',        requiresShield = true },
        { key = 'ThunderstrikeWard', nameSpellID = 462757,    castSpellID = 462757,             class = 'SHAMAN',     enchantID = 7587,         enchantSlot = 'offhand',  requiresShield = true },
        { key = 'WindfuryWeapon', nameSpellID = 33757,       castSpellID = 33757,              class = 'SHAMAN',     enchantID = 5401 },
        -- Shaman shields, Elemental Orbit (383010) splits them
        { key = 'EarthShieldSelf',      spellID = 383648,                 castSpellID = 974,    class = 'SHAMAN',         requiresSpellID = 383010, unsafeRestricted = true, selfCast = true },
        { key = 'ElementalShield',      spellID = { 192106, 52127 },      castSpellID = 192106, class = 'SHAMAN',         requiresSpellID = 383010, roleSpell = { HEALER = 52127 }, unsafeRestricted = true, },
        { key = 'ShamanShield',         spellID = { 974, 192106, 52127 }, castSpellID = 192106, class = 'SHAMAN',         excludeSpellID = 383010,  roleSpell = { HEALER = 52127 }, unsafeRestricted = true, },
    },

    Consumable = {
        {
            key = 'AugmentRune',
            itemList = 'AugmentRune',
            spellID = {
                1264426, -- Void-Touched (Midnight)
                1295329, -- Tidesworn (Midnight)
                1234969, -- Ethereal (TWW)
                1242347, -- Soulgorged (TWW)
                453250,  -- Crystallized (TWW)
                393438,  -- Draconic
                347901,  -- Veiled
            },
        },
        {
            key = 'Flask',
            itemList = 'Flask',
            spellID = {
                -- Midnight
                1235111,                            -- Shattered Sun
                1235110,                            -- Blood Knights
                1235108,                            -- Magisters
                1235057,                            -- Thalassian Resistance
                1239355,                            -- Vicious Thalassian Flask of Honor
                1235113, 1235114, 1235115, 1235116, -- PvP morphs of the above
                -- The War Within
                432021, 431971, 431972, 431973, 431974, 432473,
            },
        },
        { key = 'DelveFood',        spellID = 442522,             check = 'DelveFood',  noExpiry = true,         noClick = true },
        { key = 'Food',             icon = MissingBuffs.FoodIcon, check = 'Food',       itemList = 'Food' },
        { key = 'InkyBlackPotion',  spellID = 185394,             itemList = 'InkyBlackPotion' }, -- zone gated through its load conditions
        { key = 'Healthstone',     itemID = { 5512, 224464 },    castSpellID = 6201,   casterClass = 'WARLOCK', icon = 538745,          check = 'Healthstone', noExpiry = true, maxCharges = 3 },
        { key = 'MageFood',         itemID = { 113509 },          casterClass = 'MAGE', castSpellID = 190336,    check = 'MageFood',     readyCheckOnly = true, noExpiry = true },
        { key = 'WeaponOil',        icon = 7548987,               check = 'WeaponOil',  itemList = 'WeaponOil',  useWeapon = true },
        { key = 'WeaponOilOffHand', icon = 7548987,               check = 'WeaponOil',  enchantSlot = 'offhand', itemList = 'WeaponOil', useWeapon = true },
    },

    Utility = {
        { key = 'Soulwell',         castSpellID = 29893,  class = 'WARLOCK', hideOnCooldown = true, noExpiry = true },
        { key = 'RefreshmentTable', castSpellID = 190336, class = 'MAGE',    hideOnCooldown = true, check = 'RefreshmentTable', noExpiry = true },
    },
}

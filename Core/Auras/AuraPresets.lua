---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AuraFiltersPremade
local Premade = {}
NRSKNUI.AuraFiltersPremade = Premade
local L = NRSKNUI.Libs.AL

local ipairs, pairs = ipairs, pairs
local tsort = table.sort

local Filters = AuraUtil.AuraFilters

local BL_DEBUFFS = NRSKNUI.AuraFilters.BloodlustDebuffs
local MISC_DEBUFFS = NRSKNUI.AuraFilters.Misc

-- Display order: classes, then shared groups.
Premade.Groups = {
    'DEATHKNIGHT', 'DEMONHUNTER', 'DRUID', 'EVOKER', 'HUNTER', 'MAGE', 'MONK', 'PALADIN', 'PRIEST', 'ROGUE',
    'SHAMAN', 'WARLOCK', 'WARRIOR', 'EXTERNALS', 'RAIDCDS', 'RACIALS', 'TRINKETS', 'BLOODLUST', 'LOCKOUTS', 'OTHER',
}

local SHARED_GROUP_NAMES = {
    EXTERNALS = L['Externals'],
    RAIDCDS = L['Raid Cooldowns'],
    RACIALS = L['Racials'],
    TRINKETS = L['Trinkets'],
    BLOODLUST = L['Bloodlust'],
    LOCKOUTS = L['Lockouts'],
    OTHER = L['Other'],
}

---@param group string
---@return string
function Premade:GetGroupName(group)
    return LOCALIZED_CLASS_NAMES_MALE[group] or SHARED_GROUP_NAMES[group] or group
end

---@param group string?
---@return boolean
function Premade:IsClassGroup(group)
    return group ~= nil and LOCALIZED_CLASS_NAMES_MALE[group] ~= nil
end

---@param map table<number, boolean>
---@return number[]
local function SortedIds(map)
    local ids = {}
    for id in pairs(map) do ids[#ids + 1] = id end
    tsort(ids)
    return ids
end

-- Presets with `spells` are editable: triggers layer Added/Removed on top of the shipped list.
Premade.Presets = {
    {
        key = 'preset:advancedDebuffs',
        name = L['Advanced Debuffs'],
        spellField = 'excludeSpellIDs',
        spells = {
            { group = 'BLOODLUST', ids = SortedIds(BL_DEBUFFS) },
            { group = 'LOCKOUTS',  ids = SortedIds(MISC_DEBUFFS) },
        },
        branches = {
            {
                type = Filters.Harmful,
                tokens = { [Filters.Player] = false },
                candidates = { isFromPlayerOrPlayerPet = false },
            },
        },
    },
    {
        key = 'preset:debuffsNoBloodlust',
        name = L['Debuffs (No Bloodlust)'],
        branches = {
            {
                type = Filters.Harmful,
                candidates = {
                    excludeSpellIDs = BL_DEBUFFS,
                }
            },
        },
    },
    {
        key = 'preset:defensives',
        name = L['Defensive Buffs'],
        spellField = 'includeSpellIDs',
        spells = {
            {
                group = 'DEATHKNIGHT',
                ids = {
                    55233, -- Vampiric Blood
                    48792, -- Icebound Fortitude
                    48707, -- Anti-Magic Shell
                }
            },
            {
                group = 'DEMONHUNTER',
                ids = {
                    187827,  -- Metamorphosis
                    1266616, -- Demon Muzzle
                    212800,  -- Blur
                    207771,  -- Fiery Brand
                }
            },
            {
                group = 'DRUID',
                ids = {
                    22812,   -- Barkskin
                    61336,   -- Survival Instincts
                    1261872, -- Heart of the wild bearform
                }
            },
            {
                group = 'EVOKER',
                ids = {
                    363916, -- Obsidian Scales
                }
            },
            {
                group = 'HUNTER',
                ids = {
                    186265, -- Aspect of the Turtle
                    264735, -- Survival of the Fittest
                }
            },
            {
                group = 'MAGE',
                ids = {
                    114267,  -- Ice Barrier
                    235450,  -- Prismatic Barrier
                    235313,  -- Blazing Barrier
                    414658,  -- Ice Cold
                    45438,   -- Ice Block
                    342246,  -- Alter Time
                    1309793, -- Amplified Refraction
                    449336,  -- Merely a Setback
                }
            },
            {
                group = 'MONK',
                ids = {
                    132578,  -- Invoke Niuzao, the Black Ox
                    1241059, -- Celestial Infusion
                    125174,  -- Touch of karma
                    120954,  -- Fortifying Brew
                }
            },
            {
                group = 'PALADIN',
                ids = {
                    432607, -- Holy Bulwark
                    86659,  -- Guardian of Ancient Kings
                    31850,  -- Ardent Defender
                    642,    -- Divine Shield
                    403876, -- Divine Protection
                    184662, -- Shield of Vengeance
                    498,    -- Divine Protection
                }
            },
            {
                group = 'PRIEST',
                ids = {
                    19236, -- Desperate Prayer
                    47585, -- Dispersion
                    586,   -- Fade
                }
            },
            {
                group = 'ROGUE',
                ids = {
                    1966,   -- Feint
                    31224,  -- Cloak of Shadows
                    5277,   -- Evasion
                    45182,  -- Cheating Death
                    185311, -- Crimson Vial
                }
            },
            {
                group = 'SHAMAN',
                ids = {
                    198103, -- Earth Elemental
                    108271, -- Astral Shift
                    260881, -- Spirit Wolf
                }
            },
            {
                group = 'WARLOCK',
                ids = {
                    108416, -- Dark Pact
                    104773, -- Unending Resolve
                }
            },
            {
                group = 'WARRIOR',
                ids = {
                    23920,  -- Spell Reflection
                    118038, -- Die by the Sword
                    871,    -- Shield Wall
                    184364, -- Enraged Regeneration
                    386398, -- Battle-Scarred Veteran
                }
            },
            {
                group = 'RAIDCDS',
                ids = {
                    97463,  -- Rallying Cry
                    145629, -- Anti-Magic Zone
                    209426, -- Darkness
                    374227, -- Zephyr
                    325174, -- Spirit Link Totem
                    81772,  -- Power World: Barrier
                }
            },
            {
                group = 'EXTERNALS',
                ids = {
                    116849, -- Life Cocoon
                    6940,   -- Blessing of Sacrifice
                    1022,   -- Blessing of Protection
                    204018, -- Blessing of Spellwarding
                    47788,  -- Guardian Spirit
                    102342, -- Ironbark
                    357170, -- Time Dilation
                    33206,  -- Pain Suppression
                }
            },
            {
                group = 'RACIALS',
                ids = {
                    65116,  -- Stoneform
                    273104, -- Fireblood
                }
            },
            {
                group = 'TRINKETS',
                ids = {
                    1307578, -- Soulcoiler Ritual Vessel
                }
            },
        },
        branches = {
            { type = Filters.Helpful },
        },
    },
    {
        key = 'preset:speed',
        name = L['Speed Buffs'],
        spellField = 'includeSpellIDs',
        spells = {
            {
                group = 'DEATHKNIGHT',
                ids = {
                    48265,  -- Death's Advance
                    444347, -- Death Charge
                }
            },
            {
                group = 'DEMONHUNTER',
                ids = {
                    389847, -- Felfire Haste
                }
            },
            {
                group = 'DRUID',
                ids = {
                    61684,  -- Dash
                    1850,   -- Dash
                    77761,  -- Stampeding Roar
                    106898, -- Stampeding Roar
                }
            },
            {
                group = 'EVOKER',
                ids = {
                    358267, -- Hover
                    370667, -- Rescue
                }
            },
            {
                group = 'HUNTER',
                ids = {
                    186257, -- Aspect of the Cheetah
                    186258, -- Aspect of the Cheetah
                    118922, -- Posthaste
                }
            },
            {
                group = 'MONK',
                ids = {
                    116841, -- Tiger's Lust
                    449609, -- Lighter than air
                }
            },
            {
                group = 'PALADIN',
                ids = {
                    1044,   -- Blessing of freedom
                    221885, -- Divine Steed
                    276111, -- Divine Steed
                    221883, -- Divine Steed
                }
            },
            {
                group = 'PRIEST',
                ids = {
                    121557, -- Angelic Feather
                }
            },
            {
                group = 'ROGUE',
                ids = {
                    2983, -- Sprint
                }
            },
            {
                group = 'SHAMAN',
                ids = {
                    192082, -- Wind Rush Totem
                    58875,  -- Spirit Walk
                }
            },
            {
                group = 'WARRIOR',
                ids = {
                    202164,  -- Bounding Stride
                    1244157, -- Piercing Howl
                }
            },
            {
                group = 'RACIALS',
                ids = {
                    256948, -- Spatial Rift
                }
            },
        },
        branches = {
            { type = Filters.Helpful },
        },
    },
    {
        key = 'preset:generalBuffs',
        name = L['General Buffs'],
        spellField = 'includeSpellIDs',
        spells = {
            {
                group = 'BLOODLUST',
                ids = {
                    2825,    -- Bloodlust
                    32182,   -- Heroism
                    80353,   -- Time Warp
                    390386,  -- Fury of the Aspects
                    466904,  -- Harrier's Cry
                    1243972, -- Void-touched Drums
                }
            },
            {
                group = 'EXTERNALS',
                ids = {
                    10060, -- Power Infusion
                    29166, -- Innervate
                }
            },
            {
                group = 'RACIALS',
                ids = {
                    26297, -- Berserking
                }
            },
            {
                group = 'OTHER',
                ids = {
                    271107,  -- Golden Luster
                    431932,  -- Tempered Potion
                    1236994, -- Potion of Recklessness
                    1250533, -- Freightrunner's Flask
                    1293316, -- Empowering Venom
                    1297761, -- Voracious Heart of Ula'tek
                }
            },
        },
        branches = {
            { type = Filters.Helpful },
        },
    },
    {
        key = 'preset:healerhots',
        name = L['Healer HoTs'],
        spellField = 'includeSpellIDs',
        spells = {
            {
                group = 'DRUID',
                ids = {
                    774,    -- Rejuvenation
                    8936,   -- Regrowth
                    33763,  -- Lifebloom
                    155777, -- Rejuvenation (Germination)
                    48438,  -- Wild Growth
                    439530, -- Symbiotic Blooms
                }
            },
            {
                group = 'PRIEST',
                ids = {
                    17,      -- Power Word: Shield
                    194384,  -- Atonement
                    1253593, -- Void Shield
                    139,     -- Renew
                    77489,   -- Echo of Light
                    41635,   -- Prayer of Mending
                }
            },
            {
                group = 'MONK',
                ids = {
                    119611, -- Renewing Mist
                    124682, -- Enveloping Mist
                    115175, -- Soothing Mist
                    450769, -- Aspect of Harmony
                    443113, -- Strength of the Black Ox
                }
            },
            {
                group = 'SHAMAN',
                ids = {
                    61295,  -- Riptide
                    974,    -- Earth Shield
                    382024, -- Earthliving Weapon
                    207400, -- Ancestral Vigor
                    444490, -- Hydrobubble
                }
            },
            {
                group = 'PALADIN',
                ids = {
                    432496, -- Holy Bulwark
                    432607, -- Holy Bulwark
                    432502, -- Sacred Weapon
                    156322, -- Eternal Flame
                    431381, -- Dawnlight
                }
            },
            {
                group = 'EVOKER',
                ids = {
                    364343, -- Echo
                    366155, -- Reversion
                    367364, -- Echo Reversion
                    355941, -- Dream Breath
                    376788, -- Echo Dream Breath
                    363502, -- Dream Flight
                    373267, -- Lifebind
                }
            },
            {
                group = 'TRINKETS',
                ids = {
                    1307578, -- Soulcoiler Ritual Vessel
                }
            },
        },
        branches = {
            {
                type = Filters.Helpful,
                tokens = { [Filters.Player] = true },
            },
        },
    },
    -- Defensives and control --
    {
        key = 'preset:externalDefensives',
        name = L['External Defensives'],
        branches = {
            {
                type = Filters.Helpful,
                tokens = { [Filters.ExternalDefensive] = true },
            },
        },
    },
    {
        key = 'preset:bigDefensives',
        name = L['Big Defensives'],
        branches = {
            {
                type = Filters.Helpful,
                tokens = {
                    [Filters.BigDefensive] = true,
                    [Filters.ExternalDefensive] = false,
                },
            },
        },
    },
    {
        key = 'preset:crowdControl',
        name = L['Crowd Control'],
        branches = {
            {
                type = Filters.Harmful,
                tokens = { [Filters.CrowdControl] = true },
            },
        },
    },
    {
        key = 'preset:roleDebuffs',
        name = L['Boss / Role Debuffs'],
        branches = {
            {
                type = Filters.Harmful,
                candidates = { isBossOrRoleAura = true },
            },
        },
    },
    -- Target and boss --
    {
        key = 'preset:enemyBuffs',
        name = L['Enemy Buffs'],
        branches = {
            {
                type = Filters.Helpful,
                tokens = { [Filters.Player] = true },
            },
            {
                type = Filters.Helpful,
                tokens = { [Filters.Player] = false, [Filters.Important] = true },
            },
            {
                type = Filters.Helpful,
                tokens = { [Filters.Player] = false, [Filters.Important] = false, [Filters.Dispellable] = true },
            },
            {
                type = Filters.Helpful,
                tokens = { [Filters.Player] = false, [Filters.Important] = false, [Filters.Dispellable] = false },
                candidates = { isBossOrRoleAura = true },
            },
        },
    },
    {
        key = 'preset:targetBuffs',
        name = L['Target Buffs'],
        branches = {
            {
                type = Filters.Helpful,
                candidates = { isBossOrRoleAura = true },
            },
            {
                type = Filters.Helpful,
                tokens = { [Filters.RaidPlayerDispellable] = true }
            },
        },
    },
    {
        key = 'preset:targetDebuffs',
        name = L['Target Debuffs'],
        branches = {
            {
                type = Filters.Harmful,
                candidates = {
                    includeSpellIDs = {
                        [164815] = true, -- Sunfire
                    },
                    excludeSpellIDs = BL_DEBUFFS,
                },
            },
        },
    },
    {
        key = 'preset:bossBuffs',
        name = L['Boss Buffs'],
        branches = {
            {
                type = Filters.Helpful,
                candidates = { isBossAura = true }
            },
        },
    },
    {
        key = 'preset:bossDebuffs',
        name = L['Boss Debuffs'],
        branches = {
            {
                type = Filters.Harmful,
                tokens = { [Filters.Player] = true },
                candidates = { nameplateShowPersonal = true }
            },
        },
    },
    -- Group frames --
    {
        key = 'preset:partyBuffs',
        name = L['Party Buffs'],
        branches = {
            {
                type = Filters.Helpful,
                tokens = {
                    [Filters.Important] = true,
                    [Filters.BigDefensive] = false
                }
            },
        },
    },
    {
        key = 'preset:partyDebuffs',
        name = L['Party Debuffs'],
        branches = {
            {
                type = Filters.Harmful,
                candidates = {
                    isFromPlayerOrPlayerPet = false,
                    excludeSpellIDs = BL_DEBUFFS,
                }
            },
        },
    },
    {
        key = 'preset:raidBuffs',
        name = L['Raid Buffs'],
        branches = {
            {
                type = Filters.Helpful,
                tokens = {
                    [Filters.Important] = true,
                    [Filters.BigDefensive] = false
                }
            },
        },
    },
    {
        key = 'preset:raidDebuffs',
        name = L['Raid Debuffs'],
        branches = {
            {
                type = Filters.Harmful,
                candidates = {
                    isFromPlayerOrPlayerPet = false,
                    excludeSpellIDs = BL_DEBUFFS,
                }
            },
        },
    },
}

-- Keyed for lookup, the array above stays the display order. Editable presets get their spell map here.
local ByKey = {}
for _, preset in ipairs(Premade.Presets) do
    ByKey[preset.key] = preset

    if preset.spells then
        local map = {}
        for _, group in ipairs(preset.spells) do
            for _, id in ipairs(group.ids) do map[id] = group.group end
        end
        local branch = preset.branches[1]
        branch.candidates = branch.candidates or {}
        branch.candidates[preset.spellField] = map
    end
end

---The spec behind a preset key, in the branch shape AuraFilters:Compile reads.
---@param key string?
---@return table? spec
function Premade:Get(key)
    return key and ByKey[key] or nil
end

---An editable preset's shipped spells, { [spellID] = group }. Read only.
---@param key string?
---@return table? map
---@return string? field the candidate field the list fills
function Premade:GetShippedSpells(key)
    local preset = self:Get(key)
    if not (preset and preset.spells) then return nil end
    return preset.branches[1].candidates[preset.spellField], preset.spellField
end

---{ key, text } entries for the dropdowns, flagged so the GUI can group them and refuse rename/delete.
---@return table[]
function Premade:GetList()
    local list = {}

    for index, preset in ipairs(Premade.Presets) do
        list[index] = { key = preset.key, text = preset.name, isPreset = true }
    end

    return list
end

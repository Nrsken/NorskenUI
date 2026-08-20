---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AuraFiltersPremade
local Premade = {}
NRSKNUI.AuraFiltersPremade = Premade
local L = NRSKNUI.Libs.AL

local ipairs = ipairs

local Filters = AuraUtil.AuraFilters

local BL_DEBUFFS = {
    [160455] = true, -- Hunter Pet Fatigued
    [26013] = true,  -- Deserter
    [264689] = true, -- Hunter Pet Fatigued
    [390435] = true, -- Exhaustion
    [57723] = true,  -- Exhaustion
    [57724] = true,  -- Sated
    [71041] = true,  -- Dungeon Deserter
    [80354] = true,  -- Temporal Displacement
    [95809] = true,  -- Hunter Pet Insanity
}

Premade.Presets = {
    {
        key = 'preset:advancedDebuffs',
        name = L['Advanced Debuffs'],
        branches = {
            {
                type = Filters.Harmful,
                tokens = { [Filters.Player] = false },
                candidates = {
                    excludeSpellIDs = BL_DEBUFFS,
                    --maxDuration = 200000,
                }
            },
        },
    },
    {
        key = 'preset:defensives',
        name = L['Defensive Buffs'],
        branches = {
            {
                type = Filters.Helpful,
                candidates = {
                    includeSpellIDs = {
                        -- Death Knight
                        [55233] = true,   -- Vampiric Blood
                        [48792] = true,   -- Icebound Fortitude
                        [48707] = true,   -- Anti-Magic Shell
                        -- Demon Hunter
                        [187827] = true,  -- Metamorphosis
                        [203819] = true,  -- Demon Spikes
                        [1266616] = true, -- Demon Muzzle
                        [212800] = true,  -- Blur
                        [207771] = true,  -- Fiery Brand
                        -- Druid
                        [22812] = true,   -- Barkskin
                        [1261872] = true, -- Heart of the wild bearform
                        -- Evoker
                        [363916] = true,  -- Obsidian Scales
                        -- Hunter
                        [186265] = true,  -- Aspect of the Turtle
                        [264735] = true,  -- Survival of the Fittest
                        -- Mage
                        [114267] = true,  -- Ice Barrier
                        [414658] = true,  -- Ice Cold
                        [342246] = true,  -- Alter Time
                        [55342] = true,   -- Mirror Image
                        -- Monk
                        [132578] = true,  -- Invoke Niuzao, the Black Ox
                        [1241059] = true, -- Celestial Infusion
                        [125174] = true,  -- Touch of karma
                        [120954] = true,  -- Fortifying Brew
                        -- Paladin
                        [432607] = true,  -- Holy Bulwark
                        [86659] = true,   -- Guardian of Ancient Kings
                        [31850] = true,   -- Ardent Defender
                        [642] = true,     -- Divine Shield
                        [403876] = true,  -- Divine Protection
                        [184662] = true,  -- Shield of Vengeance
                        -- Priest
                        [19236] = true,   -- Desperate Prayer
                        [47585] = true,   -- Dispersion
                        [586] = true,     -- Fade
                        -- Rogue
                        [1966] = true,    -- Feint
                        [31224] = true,   -- Cloak of Shadows
                        [5277] = true,    -- Evasion
                        [45182] = true,   -- Cheating Death
                        [185311] = true,  -- Crimson Vial
                        -- Shaman
                        [198103] = true,  -- Earth Elemental
                        [108271] = true,  -- Astral Shift
                        [260881] = true,  -- Spirit Wolf
                        -- Warlock
                        [108416] = true,  -- Dark Pact
                        [104773] = true,  -- Unending Resolve
                        -- Warrior
                        [23920] = true,   -- Spell Reflection
                        [118038] = true,  -- Die by the Sword
                        [871] = true,     -- Shield Wall
                        [184364] = true,  -- Enraged Regeneration
                        [386398] = true,  -- Battle-Scarred Veteran

                        -- Raid CDS
                        [97463] = true,  -- Rallying Cry
                        [145629] = true, -- Anti-Magic Zone
                        [209426] = true, -- Darkness
                        [374227] = true, -- Zephyr
                        [325174] = true, -- Spirit Link Totem
                        [81772] = true,  -- Power World: Barrier

                        -- Externals
                        [116849] = true, -- Life Cocoon
                        [6940] = true,   -- Blessing of Sacrifice
                        [1022] = true,   -- Blessing of Protection
                        [204018] = true, -- Blessing of Spellwarding
                        [47788] = true,  -- Guardian Spirit
                        [102342] = true, -- Ironbark
                        [357170] = true, -- Time Dilation
                        [33206] = true,  -- Pain Suppression

                        -- Racials
                        [65116] = true,  -- Stoneform
                        [273104] = true, -- Fireblood
                    },
                },
            },
        },
    },
    {
        key = 'preset:speed',
        name = L['Speed Buffs'],
        branches = {
            {
                type = Filters.Helpful,
                candidates = {
                    includeSpellIDs = {
                        -- Death Knight
                        [48265] = true,   -- Death's Advance
                        [444347] = true,  -- Death Charge
                        -- Demon Hunter
                        [389847] = true,  -- Felfire Haste
                        -- Druid
                        [61684] = true,   -- Dash
                        [1850] = true,    -- Dash
                        [77761] = true,   -- Stampeding Roar
                        [106898] = true,  -- Stampeding Roar
                        -- Evoker
                        [358267] = true,  -- Hover
                        [370667] = true,  -- Rescue
                        -- Hunter
                        [186257] = true,  -- Aspect of the Cheetah
                        [186258] = true,  -- Aspect of the Cheetah
                        [118922] = true,  -- Posthaste
                        -- Monk
                        [116841] = true,  -- Tiger's Lust
                        [449609] = true,  -- Lighter than air
                        -- Paladin
                        [1044] = true,    -- Blessing of freedom
                        [221885] = true,  -- Divine Steed
                        [276111] = true,  -- Divine Steed
                        -- Priest
                        [121557] = true,  -- Angelic Feather
                        -- Rogue
                        [2983] = true,    -- Sprint
                        -- Shaman
                        [192082] = true,  -- Wind Rush Totem
                        [58875] = true,   -- Spirit Walk
                        -- Warrior
                        [202164] = true,  -- Bounding Stride
                        [1244157] = true, -- Piercing Howl

                        -- Racials
                        [256948] = true, -- Spatial Rift
                    },
                },
            },
        },
    },
    -- Target and boss --
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

-- Keyed for lookup, the array above stays the display order.
local ByKey = {}
for _, preset in ipairs(Premade.Presets) do
    ByKey[preset.key] = preset
end

---The spec behind a preset key, in the branch shape AuraFilters:Compile reads.
---@param key string?
---@return table? spec
function Premade:Get(key)
    return key and ByKey[key] or nil
end

---@param key string?
---@return boolean
function Premade:Exists(key)
    return self:Get(key) ~= nil
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

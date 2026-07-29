---@class NRSKNUI
local NRSKNUI = select(2, ...)

function NRSKNUI:TestEnv()
    --local frame = CreateFrame('Frame', 'NRSKNUI_TestenvFrame', UIParent)
    --frame:SetPixelSize(300, 300)
    --frame:SetPixelPoint('CENTER', UIParent, 'CENTER', 0, 0)
    --frame:Show()

    --[[ Safe auras
        [160455] = true, -- Hunter Pet Fatigued
        [26013] = true,  -- Deserter
        [264689] = true, -- Hunter Pet Fatigued
        [377234] = true, -- Thrill of the Skies
        [390435] = true, -- Exhaustion
        [57723] = true,  -- Exhaustion
        [57724] = true,  -- Sated
        [71041] = true,  -- Dungeon Deserter
        [80354] = true,  -- Temporal Displacement
        [95809] = true,  -- Hunter Pet Insanity

        -- Skyriding
        [404464] = true, -- Flight Style: Skyriding
        [404468] = true, -- Flight Style: Steady
        [427490] = true, -- Ride Along
        [447959] = true, -- Ride Along - Enabled
        [447960] = true, -- Ride Along - Inactive
    ]]

    NRSKNUI.AuraData = {}
    local Data = NRSKNUI.AuraData

    local DataT = {
        -- Raid Buffs
        {
            key = 'markofthewild',
            sourceClass = 'DRUID',
            category = 'raid',
            secret = false,
            spellId = 1126
        },
        {
            key = 'arcaneintellect',
            sourceClass = 'MAGE',
            category = 'raid',
            secret = false,
            spellId = 1459,
            statType = 'intellect'
        },
        {
            key = 'battleshout',
            sourceClass = 'WARRIOR',
            category = 'raid',
            secret = false,
            spellId = 6673,
            statType = 'physical'
        },
        {
            key = 'powerwordfortitude',
            sourceClass = 'PRIEST',
            category = 'raid',
            secret = false,
            spellId = 21562
        },
        {
            key = 'skyfury',
            sourceClass = 'SHAMAN',
            category = 'raid',
            secret = false,
            spellId = 462854
        },
        {
            key = 'blessingofthebronze',
            sourceClass = 'EVOKER',
            category = 'raid',
            secret = false,
            spellId = 381748,
            extraSpellIds = { 381732, 381741, 381746, 381749, 381750, 381751, 381752, 381753, 381754, 381755, 381756, 381757, 381758 }
        },

        -- Self Buffs
        {
            key = 'flasks',
            sourceClass = 'ANY',
            category = 'flask',
            secret = true,
            spellIds = { 1235111, 1235110, 1235057, 1235108, 432021, 431971, 431972, 431974, 431973, 1264426 }
        },

        -- Self Food
        {
            key = 'heartywellfed',
            sourceClass = 'ANY',
            category = 'food',
            secret = true,
            spellName = C_Spell.GetSpellName(462187)
        },
        {
            key = 'wellfed',
            sourceClass = 'ANY',
            category = 'food',
            secret = true,
            spellName = C_Spell.GetSpellName(19705)
        },

        -- Targeted Buffs
        {
            key = 'sourceofmagic',
            sourceClass = 'EVOKER',
            sourceTalent = 369459,
            category = 'targetbuff',
            secret = false,
            spellId = 369459,
            targetType = 'healer'
        },

        -- Rogue Poisons
        {
            key = 'poisons',
            sourceClass = 'ROGUE',
            category = 'poison',
            secret = false,
            dtbTalent = 381801,
            poisonIds = {
                { key = 'instant',    spellId = 8679,   poisonType = 'lethal' },
                { key = 'wound',      spellId = 315584, poisonType = 'lethal' },
                { key = 'deadly',     spellId = 2823,   poisonType = 'lethal',    specId = 259,   talent = 2823 },
                { key = 'amplifying', spellId = 381664, poisonType = 'lethal',    specId = 259,   talent = 381664 },
                { key = 'crippling',  spellId = 3408,   poisonType = 'nonlethal' },
                { key = 'atrophic',   spellId = 381637, poisonType = 'nonlethal', talent = 381637 },
                { key = 'numbing',    spellId = 5761,   poisonType = 'nonlethal', talent = 5761 },
            },
        },
    }

    -- Non secret data.
    Data.Safe = {
        -- Raid Buffs
        [1126] = true,                                                                                                                  -- Mark of the Wild
        [1459] = true,                                                                                                                  -- Arcane Intellect
        [6673] = true,                                                                                                                  -- Battle Shout
        [21562] = true,                                                                                                                 -- Power Word: Fortitude
        [462854] = true,                                                                                                                -- Skyfury

        [381748] = true,                                                                                                                -- Blessing of the Bronze
        extraBuffSpellIds = { 381732, 381741, 381746, 381749, 381750, 381751, 381752, 381753, 381754, 381755, 381756, 381757, 381758 }, -- For each class.

        -- Evoker source
        [369459] = true, -- Source of Magic

        -- Rogue Poisons
        [2823] = true,   -- Deadly Poison
        [315584] = true, -- Instant Poison
        [3408] = true,   -- Crippling Poison
        [381637] = true, -- Atrophic Poison
        [381664] = true, -- Amplifying Poison
        [8679] = true,   -- Wound Poison
        [5761] = true,   -- Numbing Poison

        -- Shaman Imbuements
        [319773] = true, -- Windfury Weapon
        [319778] = true, -- Flametongue Weapon
        [382021] = true, -- Earthliving Weapon
        [382022] = true, -- Earthliving Weapon
        [457496] = true, -- Tidecaller's Guard
        [457481] = true, -- Tidecaller's Guard
        [462757] = true, -- Thunderstrike Ward
        [462742] = true, -- Thunderstrike Ward

        -- Paladin Rites
        [433568] = true, -- Rite of Sanctification
        [433583] = true, -- Rite of Adjuration
    }

    -- Secret ids/data.
    Data.WELL_FED_NAME = C_Spell.GetSpellName(19705)         -- Well Fed
    Data.HEARTY_WELL_FED_NAME = C_Spell.GetSpellName(462187) -- Hearty Well Fed

    Data.Restricted = {
        -- Flasks
        [1235111] = true, -- Flask of the Shattered Sun
        [1235110] = true, -- Flask of the Blood Knights
        [1235057] = true, -- Flask of Thalassian Resistance
        [1235108] = true, -- Flask of the Magisters
        [432021] = true,  -- Flask of Alchemical Chaos
        [431971] = true,  -- Flask of Tempered Aggression
        [431972] = true,  -- Flask of Tempered Swiftness
        [431974] = true,  -- Flask of Tempered Mastery
        [431973] = true,  -- Flask of Tempered Versatility
        [1264426] = true, -- Void-Touched

        -- Targeted Buffs --

        -- Paladin
        [53563] = true,  -- Beacon of Light
        [156910] = true, -- Beacon of Faith

        -- Evoker
        [360827] = true, -- Blistering Scales
        [412710] = true, -- Timelessness

        -- Druid
        [474750] = true, -- Symbiotic Relationship

        -- Monk
        [434763] = true, -- Linked Spirits

        -- Self Buffs --

        -- Mage
        [210126] = true, -- Arcane Familiar

        -- Warlock
        [196099] = true, -- Grimoire Sacrifice

        -- Shaman
        [192106] = true, -- Lightning Shield
        [52127] = true,  -- Water Shield

        -- Self & Targeted --

        -- Shaman
        [974] = true, -- Earth Shield

        -- Group Presence Buffs --

        [465] = true,   -- Devotion Aura
        [20707] = true, -- Soulstone
    }
end

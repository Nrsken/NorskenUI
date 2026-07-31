---@class NRSKNUI
local NRSKNUI = select(2, ...)

function NRSKNUI:TestEnv()
    --local frame = CreateFrame('Frame', 'NRSKNUI_TestenvFrame', UIParent)
    --frame:NUISetPixelSize(300, 300)
    --frame:NUISetPixelPoint('CENTER', UIParent, 'CENTER', 0, 0)
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
    local GetSpellName = C_Spell and C_Spell.GetSpellName
    local heartyWellFedName = GetSpellName(462187)
    local wellFedName = GetSpellName(19705)

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
        {
            key = 'arcanefamiliar',
            sourceClass = 'MAGE',
            specId = 62,
            sourceTalent = 205022,
            category = 'selfbuff',
            secret = true,
            spellId = 210126,
        },
        {
            key = 'grimoiresacrifice',
            sourceClass = 'WARLOCK',
            specId = { 265, 267 },
            sourceTalent = 108503,
            category = 'selfbuff',
            secret = true,
            spellId = 196099,
        },
        -- Self Food
        {
            key = 'heartywellfed',
            sourceClass = 'ANY',
            category = 'food',
            secret = true,
            spellName = heartyWellFedName
        },
        {
            key = 'wellfed',
            sourceClass = 'ANY',
            category = 'food',
            secret = true,
            spellName = wellFedName
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
        {
            key = 'beaconoflight',
            sourceClass = 'PALADIN',
            specId = 65,
            negatorTalent = 200025,
            category = 'targetbuff',
            secret = true,
            spellId = 53563,
            targetType = 'any'
        },
        {
            key = 'beaconoffaith',
            sourceClass = 'PALADIN',
            specId = 65,
            sourceTalent = 156910,
            category = 'targetbuff',
            secret = true,
            spellId = 156910,
            targetType = 'any'
        },
        {
            key = 'symbioticrelationship',
            sourceClass = 'DRUID',
            sourceTalent = 474750,
            category = 'targetbuff',
            secret = true,
            spellId = 474750,
            targetType = 'any'
        },
        {
            key = 'linkedspirits',
            sourceClass = 'MONK',
            sourceTalent = 434774,
            category = 'targetbuff',
            secret = true,
            spellId = 434763,
            targetType = 'any'
        },
        {
            key = 'timelessness',
            sourceClass = 'EVOKER',
            specId = 1473,
            sourceTalent = 412710,
            category = 'targetbuff',
            secret = true,
            spellId = 412710,
            targetType = 'any'
        },
        {
            key = 'blisteringscales',
            sourceClass = 'EVOKER',
            specId = 1473,
            sourceTalent = 360827,
            category = 'targetbuff',
            secret = true,
            spellId = 360827,
            targetType = 'any'
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
        -- Paladin Rites
        {
            key = 'rites',
            sourceClass = 'PALADIN',
            category = 'enchants',
            secret = false,
            riteIds = {
                { key = 'sanctification', spellId = 433568, specId = { 65, 66 }, talent = 433568 },
                { key = 'adjuration',     spellId = 433583, specId = { 65, 66 }, talent = 433583 },
            },
        },
        -- Shaman Imbuements
        {
            key = 'imbuements',
            sourceClass = 'SHAMAN',
            category = 'enchants',
            secret = false,
            imbuementIds = {
                {},
            },
        },
    }
    -- Non secret data.
    Data.Safe = {
        -- Shaman Imbuements

        -- Enha talent: 33757
        [319773] = true, -- Windfury Weapon, enchantID: 5401

        -- Enha/Ele talent: 318038
        [319778] = true, -- Flametongue Weapon, enchantID: 5400

        -- Resto talent: 382021
        [382021] = true, -- Earthliving Weapon, enchantID: 6498
        [382022] = true, -- Earthliving Weapon, enchantID: 6498

        -- Totemic talent, resto only: 445033
        [457496] = true, -- Tidecaller's Guard, enchantID: 7528
        [457481] = true, -- Tidecaller's Guard, enchantID: 7528

        -- Ele talent: 462757
        [462757] = true, -- Thunderstrike Ward, enchantID: 7587
        [462742] = true, -- Thunderstrike Ward, enchantID: 7587
    }

    Data.Restricted = {
        -- Self Buffs --

        -- Enha/Ele/Resto
        [192106] = true, -- Lightning Shield

        -- Resto
        [52127] = true, -- Water Shield

        -- Self & Targeted --

        -- Shaman, orbit talent: 383010
        [383648] = true, -- Earth Shield self
        [974] = true,    -- Earth Shield target

        -- Shaman, NO orbit talent
        [974] = true, -- Earth Shield self

        -- Group Presence Buffs --

        [465] = true,   -- Devotion Aura
        [20707] = true, -- Soulstone
    }
end

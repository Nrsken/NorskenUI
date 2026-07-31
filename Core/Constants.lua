---@class NRSKNUI
local NRSKNUI = select(2, ...)

NRSKNUI.MELEE_RANGE_ABILITIES = {
    -- Melee DPS
    [71]  = 6552,   -- Arms Warrior: Pummel
    [72]  = 6552,   -- Fury Warrior: Pummel
    [251] = 49020,  -- Frost DK: Obliterate
    [252] = 49998,  -- Unholy DK: Death Strike
    [577] = 162794, -- Havoc DH: Chaos Strike
    [103] = 22568,  -- Feral Druid: Ferocious Bite
    [255] = 186270, -- Survival Hunter: Raptor Strike
    [259] = 1329,   -- Assassination Rogue: Mutilate
    [260] = 193315, -- Outlaw Rogue: Sinister Strike
    [261] = 53,     -- Subtlety Rogue: Backstab
    [263] = 17364,  -- Enhancement Shaman: Stormstrike
    [269] = 100780, -- Windwalker Monk: Tiger Palm
    [70]  = 96231,  -- Retribution Paladin: Rebuke
    -- Tanks
    [73]  = 6552,   -- Protection Warrior: Pummel
    [250] = 49998,  -- Blood DK: Death Strike
    [581] = 225921, -- Vengeance DH: Shear
    [104] = 22568,  -- Guardian Druid: Mangle
    [268] = 100780, -- Brewmaster Monk: Tiger Palm
    [66]  = 35395,  -- Protection Paladin: Crusader Strike
}

NRSKNUI.RANGED_RANGE_ABILITIES = {
    [102]  = 5176,   -- Balance Druid: Wrath (40yd)
    [1467] = 361469, -- Devastation Evoker: Living Flame (25yd)
    [1473] = 361469, -- Augmentation Evoker: Living Flame (25yd)
    [253]  = 77767,  -- Beast Mastery Hunter: Cobra Shot (40yd)
    [254]  = 185358, -- Marksmanship Hunter: Arcane Shot (40yd)
    [62]   = 30451,  -- Arcane Mage: Arcane Blast (40yd)
    [63]   = 133,    -- Fire Mage: Fireball (40yd)
    [64]   = 116,    -- Frost Mage: Frostbolt (40yd)
    [258]  = 589,    -- Shadow Priest: Shadow Word: Pain (40yd)
    [262]  = 188196, -- Elemental Shaman: Lightning Bolt (40yd)
    [265]  = 686,    -- Affliction Warlock: Shadow Bolt (40yd)
    [266]  = 686,    -- Demonology Warlock: Shadow Bolt (40yd)
    [267]  = 29722,  -- Destruction Warlock: Incinerate (40yd)
    [1480] = 473662, -- Devourer Demon Hunter: Consume (25yd)
}

NRSKNUI.MOVEMENT_SPELLS = {
    -- Death Knight
    [250]  = { spellID = 48265, iconID = 237561 },    -- Blood: Death's Advance
    [251]  = { spellID = 48265, iconID = 237561 },    -- Frost: Death's Advance
    [252]  = { spellID = 48265, iconID = 237561 },    -- Unholy: Death's Advance
    -- Demon Hunter
    [577]  = { spellID = 195072, iconID = 1247261 },  -- Havoc: Fel Rush
    [581]  = { spellID = 189110, iconID = 1344650 },  -- Vengeance: Infernal Strike
    [1480] = { spellID = 1234796, iconID = 7554213 }, -- Devourer: Shift
    -- Druid
    [102]  = { spellID = 1850, iconID = 132120 },     -- Balance: Dash
    [103]  = { spellID = 1850, iconID = 132120 },     -- Feral: Dash
    [104]  = { spellID = 1850, iconID = 132120 },     -- Guardian: Dash
    [105]  = { spellID = 1850, iconID = 132120 },     -- Restoration: Dash
    -- Evoker
    [1467] = { spellID = 358267, iconID = 4622463 },  -- Devastation: Hover
    [1468] = { spellID = 358267, iconID = 4622463 },  -- Preservation: Hover
    [1473] = { spellID = 358267, iconID = 4622463 },  -- Augmentation: Hover
    -- Hunter
    [253]  = { spellID = 186257, iconID = 132242 },   -- Beast Mastery: Aspect of the Cheetah
    [254]  = { spellID = 186257, iconID = 132242 },   -- Marksmanship: Aspect of the Cheetah
    [255]  = { spellID = 186257, iconID = 132242 },   -- Survival: Aspect of the Cheetah
    -- Mage
    [62]   = { spellID = 1953, iconID = 135736 },     -- Arcane: Blink
    [63]   = { spellID = 1953, iconID = 135736 },     -- Fire: Blink
    [64]   = { spellID = 1953, iconID = 135736 },     -- Frost: Blink
    -- Monk
    [268]  = { spellID = 109132, iconID = 574574 },   -- Brewmaster: Roll
    [270]  = { spellID = 109132, iconID = 574574 },   -- Mistweaver: Roll
    [269]  = { spellID = 109132, iconID = 574574 },   -- Windwalker: Roll
    -- Paladin
    [65]   = { spellID = 190784, iconID = 1360759 },  -- Holy: Divine Steed
    [66]   = { spellID = 190784, iconID = 1360759 },  -- Protection: Divine Steed
    [70]   = { spellID = 190784, iconID = 1360759 },  -- Retribution: Divine Steed
    -- Priest
    [256]  = { spellID = 73325, iconID = 463835 },    -- Discipline: Leap of Faith
    [257]  = { spellID = 73325, iconID = 463835 },    -- Holy: Leap of Faith
    [258]  = { spellID = 73325, iconID = 463835 },    -- Shadow: Leap of Faith
    -- Rogue
    [259]  = { spellID = 2983, iconID = 132307 },     -- Assassination: Sprint
    [260]  = { spellID = 2983, iconID = 132307 },     -- Outlaw: Sprint
    [261]  = { spellID = 2983, iconID = 132307 },     -- Subtlety: Sprint
    -- Shaman
    [262]  = { spellID = 192063, iconID = 463565 },   -- Elemental: Gust of Wind
    [263]  = { spellID = 58875, iconID = 132328 },    -- Enhancement: Spirit Walk
    [264]  = { spellID = 192063, iconID = 463565 },   -- Restoration: Gust of Wind
    -- Warlock
    [265]  = { spellID = 48020, iconID = 607512 },    -- Affliction: Demonic Circle: Teleport
    [266]  = { spellID = 48020, iconID = 607512 },    -- Demonology: Demonic Circle: Teleport
    [267]  = { spellID = 48020, iconID = 607512 },    -- Destruction: Demonic Circle: Teleport
    -- Warrior
    [71]   = { spellID = 6544, iconID = 236171 },     -- Arms: Heroic Leap
    [72]   = { spellID = 6544, iconID = 236171 },     -- Fury: Heroic Leap
    [73]   = { spellID = 6544, iconID = 236171 },     -- Protection: Heroic Leap
}

NRSKNUI.CLASS_INTERRUPTS = {
    [1] = { 6552 },                                  -- Warrior
    [2] = { 96231, 31935 },                          -- Paladin
    [3] = { 147362, 187707 },                        -- Hunter
    [4] = { 1766 },                                  -- Rogue
    [5] = { 15487 },                                 -- Priest
    [6] = { 47528 },                                 -- Death Knight
    [7] = { 57994 },                                 -- Shaman
    [8] = { 2139 },                                  -- Mage
    [9] = { 19647, 89766, 119910, 1276467, 132409 }, -- Warlock
    [10] = { 116705 },                               -- Monk
    [11] = { 38675, 78675, 106839 },                 -- Druid
    [12] = { 183752 },                               -- Demon Hunter
    [13] = { 351338 },                               -- Evoker
}

NRSKNUI.BIGWIGS_EVENTS = {
    'BigWigs_Timer',
    'BigWigs_TargetTimer',
    'BigWigs_CastTimer',
    'BigWigs_StartBreak',
    'BigWigs_StartPull',
    'BigWigs_StopBar',
    'BigWigs_StopBars',
    'BigWigs_PauseBar',
    'BigWigs_ResumeBar',
    'BigWigs_OnBossDisable',
}

NRSKNUI.DUNGEON_INFO = {
    -- Dungeons
    MagistersTerrace  = { instanceId = 2811, name = 'Magisters\' Terrace', type = 'dungeon' },
    MaisaraCaverns    = { instanceId = 2874, name = 'Maisara Caverns', type = 'dungeon' },
    NexusPointXenas   = { instanceId = 2915, name = 'Nexus-Point Xenas', type = 'dungeon' },
    WindrunnerSpire   = { instanceId = 2805, name = 'Windrunner Spire', type = 'dungeon' },
    AlgetharAcademy   = { instanceId = 2526, name = 'Algeth\'ar Academy', type = 'dungeon' },
    PitOfSaron        = { instanceId = 658, name = 'Pit of Saron', type = 'dungeon' },
    SeatOfTriumvirate = { instanceId = 1753, name = 'Seat of the Triumvirate', type = 'dungeon' },
    Skyreach          = { instanceId = 1209, name = 'Skyreach', type = 'dungeon' },
    -- Raids
    TheVoidspire      = { instanceId = 2912, name = 'The Voidspire', type = 'raid' },
    MarchOnQuelDanas  = { instanceId = 2913, name = 'March on Quel\'Danas', type = 'raid' },
    TheDreamrift      = { instanceId = 2939, name = 'The Dreamrift', type = 'raid' },
}

-- A nil specId means every spec of the class has a pet, a number restricts it to that one spec.
NRSKNUI.PET_CLASSES = {
    HUNTER = {
        summonSpellId = 883,
        specId = nil
    },
    WARLOCK = {
        summonSpellId = 688,
        specId = nil,
    },
    DEATHKNIGHT = {
        summonSpellId = 46584,
        specId = 252
    },
    MAGE = {
        summonSpellId = 31687,
        specId = 64
    },
}

-- Gear Utility Constants

---@class NRSKNUI.ItemSlotInfo
---@field slot number
---@field frame Frame
---@field rightColumn boolean? Paperdoll button sits in the right column
---@field socketable boolean?
---@field enchants string[]? Tooltip keywords that target this slot

-- Table with all item slots, their paperdoll frame and any enchant keywords that target them.
NRSKNUI.ITEM_SLOTS = {
    { slot = INVSLOT_HEAD,     frame = _G['CharacterHeadSlot'],          enchants = { 'helm', 'head' },                socketable = true, },
    { slot = INVSLOT_NECK,     frame = _G['CharacterNeckSlot'],          enchants = { 'neck' },                        socketable = true, },
    { slot = INVSLOT_SHOULDER, frame = _G['CharacterShoulderSlot'],      enchants = { 'shoulder' } },
    { slot = INVSLOT_BACK,     frame = _G['CharacterBackSlot'],          enchants = { 'cloak', 'cape', 'back' } },
    { slot = INVSLOT_CHEST,    frame = _G['CharacterChestSlot'],         enchants = { 'chest' } },
    { slot = INVSLOT_WRIST,    frame = _G['CharacterWristSlot'],         enchants = { 'bracer', 'wrist' },             socketable = true, },
    { slot = INVSLOT_HAND,     frame = _G['CharacterHandsSlot'],         enchants = { 'glove', 'hand' },               rightColumn = true, },
    { slot = INVSLOT_WAIST,    frame = _G['CharacterWaistSlot'],         enchants = { 'belt', 'waist' },               rightColumn = true, socketable = true, },
    { slot = INVSLOT_LEGS,     frame = _G['CharacterLegsSlot'],          enchants = { 'legs', 'leg' },                 rightColumn = true, },
    { slot = INVSLOT_FEET,     frame = _G['CharacterFeetSlot'],          enchants = { 'boot', 'feet' },                rightColumn = true, },
    { slot = INVSLOT_FINGER1,  frame = _G['CharacterFinger0Slot'],       enchants = { 'ring' },                        rightColumn = true, socketable = true, },
    { slot = INVSLOT_FINGER2,  frame = _G['CharacterFinger1Slot'],       enchants = { 'ring' },                        rightColumn = true, socketable = true, },
    { slot = INVSLOT_TRINKET1, frame = _G['CharacterTrinket0Slot'],      enchants = { 'trinket' },                     rightColumn = true, },
    { slot = INVSLOT_TRINKET2, frame = _G['CharacterTrinket1Slot'],      enchants = { 'trinket' },                     rightColumn = true, },
    { slot = INVSLOT_MAINHAND, frame = _G['CharacterMainHandSlot'],      enchants = { '2h weapon', 'staff', 'weapon' } },
    { slot = INVSLOT_OFFHAND,  frame = _G['CharacterSecondaryHandSlot'], enchants = { 'weapon' },                      rightColumn = true, },
}

-- Season data.
NRSKNUI.ITEM_TRACKS = {
    { key = 'MYTH',     min = 318, max = 344, letter = 'M', color = { 1.00, 0.50, 0.00 } },
    { key = 'HERO',     min = 305, max = 322, letter = 'H', color = { 0.78, 0.30, 0.78 } },
    { key = 'CHAMPION', min = 292, max = 309, letter = 'C', color = { 0.00, 0.70, 1.00 } },
    { key = 'VETERAN',  min = 279, max = 296, letter = 'V', color = { 0.00, 0.80, 0.00 } },
}

-- PvP gear carries an explicit item level floor instead of an upgrade track.
NRSKNUI.PVP_ITEM_TRACKS = {
    { key = 'CONQUEST', itemLevel = 344, letter = 'C', color = { 1.00, 0.50, 0.00 } },
    { key = 'HONOR',    itemLevel = 331, letter = 'H', color = { 0.00, 0.70, 1.00 } },
}

-- Crafted gear carries an explicit item level floor instead of an upgrade track and a seasonal text marker in the tooltip.
NRSKNUI.CRAFTED_ITEM_MARKER = 'Tidal Crafted'
NRSKNUI.CRAFTED_ITEM_TRACKS = {
    { key = 'MYTH', itemLevel = 331 },
    { key = 'HERO', itemLevel = 318 },
}

-- Second tooltip line on gear from instanced content.
NRSKNUI.ITEM_DIFFICULTY_TAGS = {
    [PLAYER_DIFFICULTY1] = 'NORMAL',
    [PLAYER_DIFFICULTY2] = 'HEROIC',
    [PLAYER_DIFFICULTY3] = 'LFR',
    [PLAYER_DIFFICULTY6] = 'MYTHIC',
    [PLAYER_DIFFICULTY_MYTHIC_PLUS] = 'MYTHICPLUS',
}

-- All gem types as of Midnight 12.0.0.
NRSKNUI.GEM_SOCKET_TYPES = {
    { name = 'Prismatic',  locale = 'EMPTY_SOCKET_PRISMATIC',  icon = 458977 },
    { name = 'Meta',       locale = 'EMPTY_SOCKET_META',       icon = 136257 },
    { name = 'Tinker',     locale = 'EMPTY_SOCKET_TINKER',     icon = 2958630 },
    { name = 'Cogwheel',   locale = 'EMPTY_SOCKET_COGWHEEL',   icon = 407324 },
    { name = 'Primordial', locale = 'EMPTY_SOCKET_PRIMORDIAL', icon = 4095404 },
    { name = 'Fiber',      locale = 'EMPTY_SOCKET_FIBER',      icon = 136260 },
}

do
    local ipairs, tinsert, sort = ipairs, table.insert, table.sort

    ---@type table<number, NRSKNUI.ItemSlotInfo>
    NRSKNUI.ITEM_SLOT_INFO = {}
    ---@type number[]
    NRSKNUI.SOCKETABLE_SLOTS = {}
    ---@type { keyword: string, slots: number[] }[]
    NRSKNUI.ENCHANT_SLOT_KEYWORDS = {}
    ---@type table<string, NRSKNUI.ItemSlotInfo|table>
    NRSKNUI.ITEM_TRACK_INFO = {}

    local byKeyword = {}

    for _, info in ipairs(NRSKNUI.ITEM_SLOTS) do
        NRSKNUI.ITEM_SLOT_INFO[info.slot] = info

        if info.socketable then
            tinsert(NRSKNUI.SOCKETABLE_SLOTS, info.slot)
        end

        for _, keyword in ipairs(info.enchants or {}) do
            if not byKeyword[keyword] then
                byKeyword[keyword] = { keyword = keyword, slots = {} }
                tinsert(NRSKNUI.ENCHANT_SLOT_KEYWORDS, byKeyword[keyword])
            end
            tinsert(byKeyword[keyword].slots, info.slot)
        end
    end

    -- Longest keyword first so "Two-Handed Weapon" matches 'weapon' rather than 'hand'. Matching
    -- has to be ordered, otherwise a pairs() walk resolves ambiguous enchants differently per run.
    sort(NRSKNUI.ENCHANT_SLOT_KEYWORDS, function(a, b) return #a.keyword > #b.keyword end)

    for _, track in ipairs(NRSKNUI.ITEM_TRACKS) do NRSKNUI.ITEM_TRACK_INFO[track.key] = track end
    for _, track in ipairs(NRSKNUI.PVP_ITEM_TRACKS) do NRSKNUI.ITEM_TRACK_INFO[track.key] = track end
end

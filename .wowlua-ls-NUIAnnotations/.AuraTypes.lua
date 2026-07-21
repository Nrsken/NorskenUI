---@meta

filters = {
    'HELPFUL',                 -- Helpful:                only helpful auras (buffs)
    'HARMFUL',                 -- Harmful:                only harmful auras (debuffs)
    'PLAYER',                  -- Player:                 only auras cast by the player, or the player's pet/vehicle
    'RAID',                    -- Raid:                   helpful auras the player can apply + harmful auras the player can dispel
    'CANCELABLE',              -- Cancelable:             only auras the player can cancel (right-click off). Negate with "!CANCELABLE"
    'INCLUDE_NAME_PLATE_ONLY', -- IncludeNameplateOnly:   also include nameplate-only auras (otherwise they're filtered out). Not negatable
    'MAW',                     -- Maw:                    ONLY Torghast auras. When unset, Torghast auras are filtered out. Not negatable
    'EXTERNAL_DEFENSIVE',      -- ExternalDefensive:      only auras that are external defensives (cast on you by someone else)
    'CROWD_CONTROL',           -- CrowdControl:           only auras with a CC effect (stun, fear, etc.)
    'RAID_IN_COMBAT',          -- RaidInCombat:           only auras flagged to show on raid frames in combat. Combine with Player+Helpful for self-cast HoTs
    'RAID_PLAYER_DISPELLABLE', -- RaidPlayerDispellable:  only auras someone in the player's raid can dispel (incl. helpful enrages on enemies)
    'BIG_DEFENSIVE',           -- BigDefensive:           only auras that are big defensives
    'IMPORTANT',               -- Important:              only auras flagged important (helpful auras shown on enemy nameplates even if non-stealable)
    'DISPELLABLE',             -- Dispellable:            only dispellable auras, regardless of whether the player's raid can dispel them
}

candidateFilters = {
    excludeSpellIDs = { -- must be a table or nil
        [225787] = true,
    },
    includeSpellIDs = { -- must be a table or nil
        [225787] = true,
    },
    excludeDispelTypes = { -- must be a table or nil
        ['Magic'] = true,
        ['Poison'] = true,
        ['Disease'] = true,
        ['Curse'] = true,
        ['Stealth'] = true,
        ['Special'] = true,
        ['Enrage'] = true,
    },
    includeDispelTypes = { -- must be a table or nil
        ['Magic'] = true,
        ['Poison'] = true,
        ['Disease'] = true,
        ['Curse'] = true,
        ['Stealth'] = true,
        ['Special'] = true,
        ['Enrage'] = true,
    },

    processedAuraType = {
        -- AuraUtil.AuraUpdateChangedType.None, -- This cannot be used.
        AuraUtil.AuraUpdateChangedType.Debuff, -- 2
        AuraUtil.AuraUpdateChangedType.Buff,   -- 3
        AuraUtil.AuraUpdateChangedType.Dispel, -- 4
    },

    canApplyAura = nil,            -- must be a boolean or nil
    isBossAura = nil,              -- must be a boolean or nil
    isBossOrRoleAura = nil,        -- must be a boolean or nil
    isFromPlayerOrPlayerPet = nil, -- must be a boolean or nil
    isRoleAura = nil,              -- must be a boolean or nil
    isPriorityAura = nil,          -- must be a boolean or nil
    isStealable = nil,             -- must be a boolean or nil

    nameplateShowAll = nil,        -- must be a boolean or nil
    nameplateShowPersonal = nil,   -- must be a boolean or nil

    maxDuration = 200000,          -- must be a non-negative number or nil
}

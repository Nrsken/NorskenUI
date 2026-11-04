---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class BigWigsTimersModule
local BigWigsTimers = NRSKNUI:GetModule('BigWigsTimers')

local next = next
local tostring = tostring
local GetRealZoneText = GetRealZoneText

-- BigWigs shows all raids for the current expansion, so manually track current season raids.
local CURRENT_SEASON_RAIDS = {
    [2987] = true, -- The Tidebound Grotto
    [3004] = true, -- The Venomous Abyss
    [3095] = true, -- The Unbinding of Kith'ix
}

-- The game has square icons for dungeons (C_ChallengeMode) but none for raid bosses, so these are kept by hand
-- each tier, keyed by journal encounter ID as BigWigs' boss modules declare them. A missing boss shows its portrait.
local BOSS_ICONS = {
    [2849] = 3012069, -- Nymrissa Wavecaller
    [2888] = 7966621, -- Nek'zali the Soulcoiler
    [2874] = 7966620, -- Entombed Sentinels
    [2894] = 7966622, -- The Lost Explorers
    [2882] = 7966618, -- Vashnik the Malignant
    [2871] = 7966619, -- Sszorak
    [2887] = 7966623, -- The Twin Fangs
    [2883] = 7966625, -- The Coiled Altar
    [2895] = 7966624, -- Ula'tek
    [2896] = 8214194, -- Kith'ix
}

---@param journalId number
---@return number? fileID
function BigWigsTimers:GetBossIcon(journalId)
    return BOSS_ICONS[journalId]
end

local seasonData

---Current season dungeons and raids, keyed by the instance ID BigWigs menus use.
---@return table<number, BigWigsTimers.SeasonInstance>
function BigWigsTimers:GetSeasonData()
    if seasonData then return seasonData end

    local expansion = BigWigsLoader and BigWigsLoader.currentExpansion
    if not expansion then return {} end

    local kinds = {}
    for instanceId in next, expansion.currentSeason do kinds[instanceId] = 'dungeon' end
    for instanceId in next, expansion.zones do
        if CURRENT_SEASON_RAIDS[instanceId] then kinds[instanceId] = 'raid' end
    end

    seasonData = {}
    for instanceId, kind in next, kinds do
        local name = GetRealZoneText(instanceId)
        seasonData[instanceId] = {
            instanceId = instanceId,
            name = name ~= '' and name or tostring(instanceId),
            type = kind,
        }
    end

    return seasonData
end

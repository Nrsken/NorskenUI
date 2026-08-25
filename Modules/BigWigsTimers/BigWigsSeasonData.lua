---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class BigWigsTimersModule
local BigWigsTimers = NRSKNUI:GetModule('BigWigsTimers')

local next = next
local tostring = tostring
local GetRealZoneText = GetRealZoneText

-- BigWigs shows all raids for the current expansion, so manually track current season raids.
local CURRENT_SEASON_RAIDS = {
    [2987] = true, -- The Tidebound Grotto
    [3004] = true, -- The Venomous Abyss
}

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

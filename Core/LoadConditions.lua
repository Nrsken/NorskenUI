---@class NRSKNUI
local NRSKNUI = select(2, ...)

--TODO: Add: Race, spell known, NOT spell known, item equipped, in encounter, mounted, skyriding, player level, alive
--TODO: Some of these might need triple state widget, for example in encounter can be: In Encounter, Not In Encounter or Off

local select = select
local tonumber = tonumber
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local wipe, next = wipe, next
local CreateFrame = CreateFrame
local IsInInstance = IsInInstance
local ipairs, pairs = ipairs, pairs
local GetInstanceInfo = GetInstanceInfo

local GetSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
local GetSpecializationInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
local GetActiveConfigID = C_ClassTalents and C_ClassTalents.GetActiveConfigID
local GetConfigInfo = C_Traits and C_Traits.GetConfigInfo
local GetTreeNodes = C_Traits and C_Traits.GetTreeNodes
local GetNodeInfo = C_Traits and C_Traits.GetNodeInfo
local GetSubTreeInfo = C_Traits and C_Traits.GetSubTreeInfo
local GetBestMapForUnit = C_Map and C_Map.GetBestMapForUnit
local GetMapGroupID = C_Map and C_Map.GetMapGroupID
local GetMapChildrenInfo = C_Map and C_Map.GetMapChildrenInfo

---@class LoadConditions
local LoadConditions = {}
NRSKNUI.LoadConditions = LoadConditions

local callbacks = {}
local eventFrame = nil

local function HasAnyEnabled(tbl)
    if not tbl then return false end
    for _, enabled in pairs(tbl) do if enabled then return true end end
    return false
end

-- Instance condition
local function CheckInstance(config)
    if not config or not config.Types then return true end
    if not HasAnyEnabled(config.Types) then return true end

    local _, instanceType = IsInInstance()
    instanceType = instanceType or "none"

    if not config.Types[instanceType] then return false end

    if config.DifficultyID then
        local _, _, currentDifficulty = GetInstanceInfo()
        if currentDifficulty ~= config.DifficultyID then return false end
    end

    return true
end

-- Group condition
local function CheckGroup(config)
    if not config or not config.Types then return true end
    if not HasAnyEnabled(config.Types) then return true end

    local inGroup = IsInGroup()
    local inRaid = IsInRaid()

    local groupType
    if not inGroup then
        groupType = "solo"
    elseif inRaid then
        groupType = "raid"
    else
        groupType = "party"
    end

    if not config.Types[groupType] then return false end

    return true
end

-- Combat condition
local function CheckCombat(config)
    if not config then return true end

    local wantsInCombat = config.InCombat == true
    local wantsOutOfCombat = config.OutOfCombat == true

    if not wantsInCombat and not wantsOutOfCombat then return true end
    if wantsInCombat and wantsOutOfCombat then return true end
    if wantsInCombat and not NRSKNUI:InCombat() then return false end
    if wantsOutOfCombat and NRSKNUI:InCombat() then return false end

    return true
end

-- Check Role condition
local function CheckRole(config)
    if not config or not config.Types then return true end
    if not HasAnyEnabled(config.Types) then return true end
    if not NRSKNUI.MySpec.role then return true end

    if not config.Types[NRSKNUI.MySpec.role] then return false end

    return true
end

-- Check Position condition
local function CheckPosition(config)
    if not config or not config.Types then return true end
    if not HasAnyEnabled(config.Types) then return true end
    if not NRSKNUI.MySpec.position then return true end

    if not config.Types[NRSKNUI.MySpec.position] then return false end

    return true
end

-- Zone condition: comma separated uiMapIDs, g = map group, c = map plus its children, i = instance, - leaves one out.
local zoneSets = {} ---@type table<string, table> parsed per MapIDs string

---@param text string
---@return table
local function ParseZones(text)
    local zones = {
        include = { maps = {}, groups = {}, instances = {} },
        exclude = { maps = {}, groups = {}, instances = {} },
    }
    for negate, prefix, id in text:gmatch("(%-?)(%a?)(%d+)") do
        id = tonumber(id)
        prefix = prefix:lower()
        local sets = negate == "-" and zones.exclude or zones.include
        if prefix == "g" then
            sets.groups[id] = true
        elseif prefix == "i" then
            sets.instances[id] = true
        elseif prefix == "" or prefix == "c" then
            sets.maps[id] = true
            if prefix == "c" then
                for _, child in ipairs(GetMapChildrenInfo(id, nil, true) or {}) do
                    sets.maps[child.mapID] = true
                end
            end
        end
        if negate ~= "-" and (prefix == "" or prefix == "c" or prefix == "g" or prefix == "i") then zones.hasInclude = true end
    end
    return zones
end

---@param sets table
---@param mapID number?
---@param groupID number?
---@param instanceID number?
---@return boolean
local function InZones(sets, mapID, groupID, instanceID)
    return (mapID and sets.maps[mapID]) or (groupID and sets.groups[groupID]) or (instanceID and sets.instances[instanceID]) or false
end

local function CheckZone(config)
    local text = config and config.MapIDs
    if not text then return true end

    local zones = zoneSets[text]
    if not zones then
        zones = ParseZones(text)
        zoneSets[text] = zones
    end

    local mapID = GetBestMapForUnit("player")
    local groupID = mapID and GetMapGroupID(mapID)
    local instanceID = select(8, GetInstanceInfo())
    if InZones(zones.exclude, mapID, groupID, instanceID) then return false end
    return not zones.hasInclude or InZones(zones.include, mapID, groupID, instanceID)
end

---@return number? specID
local function PlayerSpecID()
    local index = GetSpecialization()
    return index and GetSpecializationInfo(index) or nil
end

-- Spec condition: any picked specID; none picked means any spec.
local function CheckSpec(config)
    if not config or not config.Types or not HasAnyEnabled(config.Types) then return true end
    local specID = PlayerSpecID()
    return specID ~= nil and config.Types[specID] == true
end

-- Talents the player has taken, by C_Traits entryID; rebuilt when talents or the spec change.
local takenTalents = {}
local talentsDirty = true

local function RebuildTalents()
    talentsDirty = false
    wipe(takenTalents)
    local configID = GetActiveConfigID()
    local config = configID and GetConfigInfo(configID)
    if not config then return end

    for _, treeID in ipairs(config.treeIDs) do
        for _, nodeID in ipairs(GetTreeNodes(treeID)) do
            local node = GetNodeInfo(configID, nodeID)
            if node and node.ID ~= 0 then
                local heroInactive = node.subTreeID and not (GetSubTreeInfo(configID, node.subTreeID) or {}).isActive
                for _, entryID in ipairs(node.entryIDs) do
                    local rank = node.activeRank
                    if node.activeEntry then rank = node.activeEntry.entryID == entryID and node.activeEntry.rank or 0 end
                    if rank > 0 and not heroInactive then takenTalents[entryID] = true end
                end
            end
        end
    end
end

---@param config table
---@return number? specID the one spec picked, which talents need
local function SingleSpec(config)
    local single
    for specID, enabled in pairs(config and config.Types or {}) do
        if enabled then
            if single then return nil end
            single = specID
        end
    end
    return single
end

-- Talent condition, per spec: only with exactly one spec picked and active; true = must have, false = must not.
local function CheckTalent(config, conditions)
    local spec = SingleSpec(conditions.Spec)
    local entries = spec and config and config.Specs and config.Specs[spec]
    if not entries or next(entries) == nil or spec ~= PlayerSpecID() then return true end

    if talentsDirty then RebuildTalents() end
    for entryID, wanted in pairs(entries) do
        if (takenTalents[entryID] == true) ~= wanted then return false end
    end
    return true
end

local checkers = {
    Instance = CheckInstance,
    Group = CheckGroup,
    Combat = CheckCombat,
    Role = CheckRole,
    Position = CheckPosition,
    Zone = CheckZone,
    Spec = CheckSpec,
    Talent = CheckTalent,
}

-- Conditions that change during a session
local SITUATIONAL = {
    Instance = true,
    Group = true,
    Combat = true,
    Zone = true,
}

---@param playerChanged boolean spec or talents may have changed
local function FireCallbacks(playerChanged)
    for aceModule, callback in pairs(callbacks) do
        if aceModule:IsEnabled() then
            callback(aceModule, playerChanged)
        end
    end
end

-- Subzone events fire constantly while moving, only a new map ID can change a Zone condition.
local ZONE_EVENTS = { ZONE_CHANGED = true, ZONE_CHANGED_INDOORS = true, ZONE_CHANGED_NEW_AREA = true }
local lastMapID

-- Talent and spec changes rebuild the taken-talent set on the next check.
local TALENT_EVENTS = {
    TRAIT_CONFIG_CREATED = true,
    TRAIT_CONFIG_UPDATED = true,
    PLAYER_TALENT_UPDATE = true,
    ACTIVE_PLAYER_SPECIALIZATION_CHANGED = true,
}

local function OnEvent(_, event)
    -- the talent config can still be missing on login, so a loading screen rescans too
    local playerChanged = TALENT_EVENTS[event] or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ENTERING_WORLD"
    if playerChanged then talentsDirty = true end
    local mapID = GetBestMapForUnit("player")
    if ZONE_EVENTS[event] and mapID == lastMapID then return end
    lastMapID = mapID
    FireCallbacks(playerChanged == true)
end

local function SetupEventFrame()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    for event in pairs(TALENT_EVENTS) do eventFrame:RegisterEvent(event) end
    for event in pairs(ZONE_EVENTS) do eventFrame:RegisterEvent(event) end

    eventFrame:SetScript("OnEvent", OnEvent)
end

---@param conditions table LoadConditions config with category tables
---@param skipSituational? boolean ignore conditions that change during a session (combat, zone, group, instance)
---@return boolean
---@return string? failed the category that failed
function LoadConditions:Check(conditions, skipSituational)
    if not conditions then return true end
    if not conditions.Enabled then return true end

    for category, checker in pairs(checkers) do
        local config = conditions[category]
        if config and not (skipSituational and SITUATIONAL[category]) and not checker(config, conditions) then return false, category end
    end

    return true
end

---@return number? specID
function LoadConditions:GetSpecID()
    return PlayerSpecID()
end

---Whether the player has this talent taken, by C_Traits entryID.
---@param entryID number
---@return boolean
function LoadConditions:HasTalent(entryID)
    if talentsDirty then RebuildTalents() end
    return takenTalents[entryID] == true
end

---@return table Default LoadConditions structure
function LoadConditions:GetDefaults()
    return {
        Enabled = false,
        SelectedCategory = "Instance",
        Instance = { Types = {} },
        Group = { Types = {} },
        Combat = {},
        Role = { Types = {} },
        Position = { Types = {} },
        Zone = {},
        Spec = { Types = {} },
        Talent = { Specs = {} },
    }
end

---Register a module to receive callbacks when load conditions may have changed
---@param aceModule table AceModule with IsEnabled method
---@param callback fun(aceModule: table, playerChanged: boolean) runs when state may have changed; playerChanged on spec and talent changes
function LoadConditions:RegisterCallback(aceModule, callback)
    SetupEventFrame()
    callbacks[aceModule] = callback
end

---Unregister a module's callback
---@param aceModule table
function LoadConditions:UnregisterCallback(aceModule)
    callbacks[aceModule] = nil
end

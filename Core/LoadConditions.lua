---@class NRSKNUI
local NRSKNUI = select(2, ...)

local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local IsInInstance = IsInInstance
local GetInstanceInfo = GetInstanceInfo
local UnitAffectingCombat = UnitAffectingCombat
local pairs = pairs
local ipairs = ipairs
local select = select
local tonumber = tonumber
local CreateFrame = CreateFrame
local GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetMapGroupID = C_Map.GetMapGroupID
local GetMapChildrenInfo = C_Map.GetMapChildrenInfo

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

local checkers = {
    Instance = CheckInstance,
    Group = CheckGroup,
    Combat = CheckCombat,
    Role = CheckRole,
    Position = CheckPosition,
    Zone = CheckZone,
}

local function FireCallbacks()
    for aceModule, callback in pairs(callbacks) do
        if aceModule:IsEnabled() then
            callback(aceModule)
        end
    end
end

-- Subzone events fire constantly while moving, only a new map ID can change a Zone condition.
local ZONE_EVENTS = { ZONE_CHANGED = true, ZONE_CHANGED_INDOORS = true, ZONE_CHANGED_NEW_AREA = true }
local lastMapID

local function OnEvent(_, event)
    local mapID = GetBestMapForUnit("player")
    if ZONE_EVENTS[event] and mapID == lastMapID then return end
    lastMapID = mapID
    FireCallbacks()
end

local function SetupEventFrame()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    for event in pairs(ZONE_EVENTS) do eventFrame:RegisterEvent(event) end

    eventFrame:SetScript("OnEvent", OnEvent)
end

---@param conditions table LoadConditions config with category tables
---@return boolean
function LoadConditions:Check(conditions)
    if not conditions then return true end
    if not conditions.Enabled then return true end

    for category, checker in pairs(checkers) do
        local config = conditions[category]
        if config and not checker(config) then return false end
    end

    return true
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
    }
end

---Register a module to receive callbacks when load conditions may have changed
---@param module table AceModule with IsEnabled method
---@param callback function Called with module as argument when state changes
function LoadConditions:RegisterCallback(module, callback)
    SetupEventFrame()
    callbacks[module] = callback
end

---Unregister a module's callback
---@param module table
function LoadConditions:UnregisterCallback(module)
    callbacks[module] = nil
end

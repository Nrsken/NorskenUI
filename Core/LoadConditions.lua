---@class NRSKNUI
local NRSKNUI = select(2, ...)

local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local IsInInstance = IsInInstance
local GetInstanceInfo = GetInstanceInfo
local UnitAffectingCombat = UnitAffectingCombat
local pairs = pairs
local CreateFrame = CreateFrame

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

local checkers = {
    Instance = CheckInstance,
    Group = CheckGroup,
    Combat = CheckCombat,
    Role = CheckRole,
    Position = CheckPosition,
}

local function FireCallbacks()
    for module, callback in pairs(callbacks) do if module:IsEnabled() then callback(module) end end
end

local function SetupEventFrame()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

    eventFrame:SetScript("OnEvent", FireCallbacks)
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

-- Restriction States:
--   0: No restrictions, all operations allowed
--   1: Partial restrictions (map transitions), some operations allowed
--   2: Full restrictions (combat, M+, encounter, PvP), give up and go next :)
--
-- Usage:
--   if NRSKNUI:IsFullyRestricted() then return end
--   if NRSKNUI:IsSecretValue(value) then return end
--   NRSKNUI:DeferUntilUnrestricted(1, function() ... end)

---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Localization
local wipe = wipe
local ipairs = ipairs
local type = type
local table_insert = table.insert
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame
local issecretvalue = issecretvalue
local issecrettable = issecrettable
local canaccessvalue = canaccessvalue
local GetUnitName = GetUnitName

-- Secret Value Utilities

-- Check if a value is a secret value
function NRSKNUI:IsSecretValue(value)
    return issecretvalue and issecretvalue(value)
end

function NRSKNUI:NotSecretValue(value)
    return not self:IsSecretValue(value)
end

-- Combined check: value exists and is NOT a secret
function NRSKNUI:IsSafeValue(value)
    return value ~= nil and not self:IsSecretValue(value)
end

-- Check if a table is a secret table
function NRSKNUI:IsSecretTable(object)
    return issecrettable and issecrettable(object)
end

-- Check if a value can be accessed
function NRSKNUI:CanAccessValue(value)
    return not canaccessvalue or canaccessvalue(value)
end

-- Check if an object has secret values
function NRSKNUI:HasSecretValues(object)
    return object and object.HasSecretValues and object:HasSecretValues()
end

-- Safe Unit Helpers

-- Get unit name safely, returns nil if unit or name is secret
function NRSKNUI:GetSafeUnitName(unit)
    if not self:IsSafeValue(unit) then return nil end
    if type(unit) ~= "string" then return nil end

    local name = GetUnitName(unit, false)
    if not self:IsSafeValue(name) then return nil end

    return name:gsub("%s?%(%*%)", "")
end

-- Safely get text from a FontString, returns nil if secret
function NRSKNUI:GetSafeText(fontString)
    if not fontString or not fontString.GetText then return nil end

    local text = fontString:GetText()
    if not self:IsSafeValue(text) then return nil end

    return text
end

-- Restriction State Management

-- State tracking - initialize based on current combat state
local currentRestrictionState = InCombatLockdown() and 2 or 0
local restrictionTypes = { Combat = InCombatLockdown() }
local deferredCallbacks = {}

-- Get current restriction state (0 = none, 1 = partial, 2 = full)
function NRSKNUI:GetRestrictionState()
    return currentRestrictionState
end

-- Check if fully restricted (combat, M+, encounter, PvP)
function NRSKNUI:IsFullyRestricted()
    return currentRestrictionState == 2
end

-- Check if any restriction is active
function NRSKNUI:IsRestricted()
    return currentRestrictionState > 0
end

-- Check if safe to perform protected operations
function NRSKNUI:CanMakeProtectedCalls()
    return currentRestrictionState < 2 and not InCombatLockdown()
end

-- Queue a function to run when restrictions release to specified state or lower
-- targetState: 0 = run when fully clear, 1 = run when partial or clear
function NRSKNUI:DeferUntilUnrestricted(targetState, callback)
    if not callback then return end

    -- If already at or below the target state, execute immediately
    if currentRestrictionState <= targetState then
        callback()
        return
    end

    -- Queue for later execution
    table_insert(deferredCallbacks, {
        targetState = targetState,
        callback = callback
    })
end

-- Internal: Set restriction state and process deferred callbacks
local function SetRestrictionState(newState)
    if currentRestrictionState == newState then return end

    local oldState = currentRestrictionState
    currentRestrictionState = newState

    -- If restrictions released, execute deferred callbacks
    if newState < oldState then
        local toExecute = {}
        local toKeep = {}

        for _, entry in ipairs(deferredCallbacks) do
            if entry.targetState >= newState then
                table_insert(toExecute, entry.callback)
            else
                table_insert(toKeep, entry)
            end
        end

        -- Update queue first (in case callbacks add new entries)
        wipe(deferredCallbacks)
        for _, entry in ipairs(toKeep) do
            table_insert(deferredCallbacks, entry)
        end

        -- Execute callbacks
        for _, callback in ipairs(toExecute) do
            callback()
        end
    end
end

-- Internal: Update restriction type and recalculate overall state
local function UpdateRestrictionType(restrictionType, active)
    restrictionTypes[restrictionType] = active

    -- Determine new state based on active restrictions
    -- Full (2): Combat, Encounter, ChallengeMode, PvPMatch
    -- Partial (1): Map transitions
    -- None (0): Everything else

    if restrictionTypes.Combat or
       restrictionTypes.Encounter or
       restrictionTypes.ChallengeMode or
       restrictionTypes.PvPMatch then
        SetRestrictionState(2)
    elseif restrictionTypes.Map then
        SetRestrictionState(1)
    else
        SetRestrictionState(0)
    end
end

-- Event Handling

-- Event frame for restriction state tracking
local restrictionFrame = CreateFrame("Frame")
restrictionFrame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
restrictionFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
restrictionFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

restrictionFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_RESTRICTION_STATE_CHANGED" then
        local restrictionType, state = ...
        UpdateRestrictionType(restrictionType, state)
    elseif event == "PLAYER_REGEN_DISABLED" then
        UpdateRestrictionType("Combat", true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        UpdateRestrictionType("Combat", false)
    end
end)

-- Protected Error Listener
local protectedErrorFrame = CreateFrame("Frame")
protectedErrorFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
protectedErrorFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")

protectedErrorFrame:SetScript("OnEvent", function(self, event, addonName, funcName)
    if addonName == "NorskenUI" then
        local msg = string.format("|cffff0000[NorskenUI]|r Protected function violation: %s (%s)", funcName or "unknown", event)
        if NRSKNUI.Print then
            NRSKNUI:Print(msg)
        else
            print(msg)
        end
    end
end)

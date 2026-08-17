---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class RestrictedModule
local Restricted = NRSKNUI:GetModule('Restricted')

local scrub = scrub
local type = type
local pcall = pcall
local pairs = pairs
local ipairs = ipairs
local xpcall = xpcall
local CreateFrame = CreateFrame
local geterrorhandler = geterrorhandler
local UnitIsDND = UnitIsDND
local UnitIsAFK = UnitIsAFK
local UnitExists = UnitExists
local issecretvalue = issecretvalue
local issecrettable = issecrettable
local canaccessvalue = canaccessvalue
local InCombatLockdown = InCombatLockdown
local scrubsecretvalues = scrubsecretvalues
local securecallfunction = securecallfunction
local UnitAffectingCombat = UnitAffectingCombat
local UnitGroupRolesAssigned = UnitGroupRolesAssigned

local GetAddOnRestrictionState = C_RestrictedActions and C_RestrictedActions.GetAddOnRestrictionState
local ShouldUnitIdentityBeSecret = C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret
local CanCompareUnitTokens = C_Secrets and C_Secrets.CanCompareUnitTokens
local GetSpellAuraSecrecy = C_Secrets and C_Secrets.GetSpellAuraSecrecy

local NeverSecret = Enum and Enum.SecrecyLevel.NeverSecret
local RestrictionType = Enum and Enum.AddOnRestrictionType
local RestrictionState = Enum and Enum.AddOnRestrictionState
local RestrictionInactive = RestrictionState and RestrictionState.Inactive

function Restricted:OnInitialize()
    self.debug = false
    self:SetEnabledState(true)
end

-- Reverse map of the restriction type enum.
local typeName = {}
if RestrictionType then
    for name, i in pairs(RestrictionType) do
        typeName[i] = name
    end
end

-- Secret Wrappers --

---Is this value a secret?
---@param value any
---@return boolean
function NRSKNUI:IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

---Is this value NOT a secret?
---@param value any
---@return boolean
function NRSKNUI:NotSecretValue(value)
    return not self:IsSecretValue(value)
end

---Value exists and is not a secret, i.e. safe to read/compare.
---@param value any
---@return boolean
function NRSKNUI:IsSafeValue(value)
    return value ~= nil and not self:IsSecretValue(value)
end

---Is this table secret or flagged so that indexing it produces secrets?
---@param object any
---@return boolean
function NRSKNUI:IsSecretTable(object)
    return issecrettable and issecrettable(object) or false
end

---Can the current (possibly tainted) call context operate on this value?
---@param value any
---@return boolean
function NRSKNUI:CanAccessValue(value)
    return not canaccessvalue or canaccessvalue(value)
end

---Does this frame/object currently hold any secret aspect?
---@param object any
---@return boolean
function NRSKNUI:HasSecretValues(object)
    return object and object.HasSecretValues and object:HasSecretValues() or false
end

---Strip secrets (and non-primitives) from a vararg list before format/concat/print.
---@return ... scrubbed
function NRSKNUI:Scrub(...)
    return scrub(...)
end

---Strip only the secrets from a vararg list, leaving other values intact.
---@return ... scrubbed
function NRSKNUI:ScrubSecrets(...)
    return scrubsecretvalues(...)
end

---Run fn behind a secure barrier so taint/errors from touching a maybe-secret table do not propagate to the caller.
---@param fn function
---@return ... results
function NRSKNUI:SecureCall(fn, ...)
    return securecallfunction(fn, ...)
end

---Pre-flight, will querying this unit's identity (name/GUID) return a secret?
---@param unit string
---@return boolean
function NRSKNUI:IsSecretUnit(unit)
    return ShouldUnitIdentityBeSecret(unit) or false
end

---Pre-flight, is comparing these two unit tokens permitted (guard before UnitIsUnit)?
---@param unit1 string
---@param unit2 string
---@return boolean
function NRSKNUI:CanCompareUnits(unit1, unit2)
    return CanCompareUnitTokens(unit1, unit2)
end

---Pre-flight, can this spell hand back secrets when queried as an aura?
---@param spellID number
---@return boolean
function NRSKNUI:IsSpellAuraSecret(spellID)
    return GetSpellAuraSecrecy(spellID) ~= NeverSecret
end

---Safely get a value if it is not secret and can be accessed, otherwise return nil.
---@param value any
---@return any|nil
function NRSKNUI:SafeValue(value)
    if self:CanAccessValue(value) then
        return value
    end
    return nil
end

---@param unit string
---@return boolean|nil
function NRSKNUI:UnitIsAFK(unit)
    local isAFK = UnitIsAFK(unit)

    return NRSKNUI:NotSecretValue(isAFK) and isAFK or nil
end

---@param unit string
---@return boolean|nil
function NRSKNUI:UnitIsDND(unit)
    local isDND = UnitIsDND(unit)

    return NRSKNUI:NotSecretValue(isDND) and isDND or nil
end

---@param unit string
---@return string|nil
function NRSKNUI:GetSafeRole(unit)
    if not unit or not UnitExists(unit) then return nil end
    local role = UnitGroupRolesAssigned(unit)

    return NRSKNUI:NotSecretValue(role) and role or nil
end

-- Unit Token Validation --

-- Own frame, never a live handler, probing registers and unregisters UNIT_HEALTH on it.
local unitValidator = CreateFrame('Frame')
local validTokens = {}

---Is this a unit token the event system recognises?
---@param unit string?
---@return boolean
function NRSKNUI:IsValidUnitToken(unit)
    if type(unit) ~= 'string' then return false end

    local cached = validTokens[unit]
    if cached ~= nil then return cached end

    local valid = false
    if pcall(unitValidator.RegisterUnitEvent, unitValidator, 'UNIT_HEALTH', unit) then
        local registered, registeredUnit = unitValidator:IsEventRegistered('UNIT_HEALTH')
        unitValidator:UnregisterEvent('UNIT_HEALTH')
        valid = registered and registeredUnit ~= nil
    end

    validTokens[unit] = valid
    return valid
end

-- Combat Queue --

local combatQueue = {}

---Run fn now if out of combat lockdown, otherwise defer to PLAYER_REGEN_ENABLED.
---Used for any protected function call.
---@param fn function
function NRSKNUI:RunWhenSafe(fn)
    if not fn then return end
    if NRSKNUI:InCombat() then
        combatQueue[#combatQueue + 1] = fn
    else
        fn()
    end
end

-- Restriction State Tracking --

local active = {}
local restrictionState = 0
local pending = {}

---Check combat state, including the active.Combat flag which is set by PLAYER_REGEN_DISABLED/ENABLED events.
---@return boolean
function NRSKNUI:InCombat()
    return active.Combat or InCombatLockdown() or UnitAffectingCombat('Player')
end

---Current restriction state (0 none, 1 partial, 2 full).
---@return integer
function NRSKNUI:GetRestrictionState()
    return restrictionState
end

---Any restriction active?
---@return boolean
function NRSKNUI:IsRestricted()
    return restrictionState > 0
end

---Fully restricted i.e combat, encounter, M+, or PvP?
---@return boolean
function NRSKNUI:IsFullyRestricted()
    return restrictionState == 2
end

---Defer fn until the restriction state is at or below targetState (0 none, 1 partial, 2 full).
---@param targetState integer
---@param fn function
function NRSKNUI:DeferUntilUnrestricted(targetState, fn)
    if not fn then return end
    if restrictionState <= targetState then
        fn()
        return
    end
    pending[#pending + 1] = { target = targetState, fn = fn }
end

-- Recompute the overall state from the active type flags and flush eligible pending callbacks.
local function Recompute()
    local newState =
        (active.Combat or
            active.Encounter or
            active.ChallengeMode or
            active.PvPMatch) and 2
        or active.Map and 1
        or 0

    if newState == restrictionState then return end

    local old = restrictionState
    restrictionState = newState

    if newState < old then -- Restrictions released, run anything now eligible.
        local run, keep = {}, {}
        for _, e in ipairs(pending) do
            if e.target >= newState then
                run[#run + 1] = e.fn
            else
                keep[#keep + 1] = e
            end
        end
        pending = keep -- Swap first so callbacks may re-queue safely.
        -- One erroring callback must not abandon the rest of the queue.
        for i = 1, #run do xpcall(run[i], geterrorhandler()) end
    end
end

-- Lifecycle --

function Restricted:PLAYER_REGEN_DISABLED()
    active.Combat = true
    Recompute()
end

function Restricted:PLAYER_REGEN_ENABLED()
    active.Combat = false
    Recompute()

    -- Flush protected work queued during combat.
    if #combatQueue > 0 then
        local snapshot = combatQueue
        combatQueue = {}
        -- One erroring callback must not strand the protected work queued behind it.
        for i = 1, #snapshot do
            xpcall(snapshot[i], geterrorhandler())
        end
    end
end

function Restricted:ADDON_RESTRICTION_STATE_CHANGED(_, restrictionType, state)
    -- Activating(1) and Active(2) both count as 'on', only Inactive(0) is off.
    active[typeName[restrictionType]] = state ~= RestrictionInactive
    Recompute()
end

function Restricted:OnActionViolation(event, source, funcName)
    NRSKNUI:Print(('|cffff0000Protected violation:|r %s (%s, %s)'):format(funcName or '?', event, source or '?'))
end

function Restricted:OnEnable()
    -- Seed from the live state so an Encounter/M+/PvP already active on /reload is caught.
    for i, name in pairs(typeName) do
        active[name] = GetAddOnRestrictionState(i) ~= RestrictionInactive
    end

    active.Combat = active.Combat or InCombatLockdown() or UnitAffectingCombat('Player')
    Recompute()

    self:RegisterEvent('ADDON_RESTRICTION_STATE_CHANGED')
    self:RegisterEvent('PLAYER_REGEN_DISABLED')
    self:RegisterEvent('PLAYER_REGEN_ENABLED')

    if self.debug then
        self:RegisterEvent('ADDON_ACTION_BLOCKED', 'OnActionViolation')
        self:RegisterEvent('ADDON_ACTION_FORBIDDEN', 'OnActionViolation')
    end
end

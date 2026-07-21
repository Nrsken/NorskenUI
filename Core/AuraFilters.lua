---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AuraFilters
local AuraFilters = {}
NRSKNUI.AuraFilters = AuraFilters

local AuraUtil = AuraUtil
local ipairs = ipairs
local pairs = pairs
local type = type
local next = next
local unpack = unpack
local wipe = wipe
local tinsert = table.insert
local tsort = table.sort
local CopyTable = CopyTable

--[[

Centralized aura filter registry.

Consumers never build these themselves, they just reference a filter by name:

? local filterString, candidateFilters = NRSKNUI:GetAuraFilter(self.db.Filter)
? container:AddGroup(filterString, { candidateFilters = candidateFilters })

or, via the container convenience that also remembers the binding for live updates:

? container:AddFilteredGroup(self.db.Filter)

--]]

-- Blizzard tokens/constants read from the live client, never hardcoded since these can change between patches.
local Filters = AuraUtil.AuraFilters
local NEG = AuraUtil.AuraFilterNegationPrefix

-- These two ignore negation, so we never emit '!' for them.
local NON_NEGATABLE = { [Filters.IncludeNameplateOnly] = true, [Filters.Maw] = true }

local BOOL_NEGATION = false -- TODO: Remove once PTR6 is live

-- Boolean candidate fields that can be true, false or nil.
local BOOL_CANDIDATE_FIELDS = {
    'isBossAura', 'isBossOrRoleAura', 'isRoleAura', 'isPriorityAura', 'isStealable',
    'isFromPlayerOrPlayerPet', 'canApplyAura', 'nameplateShowAll', 'nameplateShowPersonal',
}

-- Table candidate fields that can be a table or nil.
local TABLE_CANDIDATE_FIELDS = {
    'includeDispelTypes', 'excludeDispelTypes', 'includeSpellIDs', 'excludeSpellIDs',
}

local function GetStore()
    return NRSKNUI.db.global.AuraFilters
end

local function GetSpec(name)
    local store = GetStore()
    return store and store[name]
end

---Assemble the parse filter string from a spec's base type + triple state tokens.
---@param spec table
---@return string
local function BuildFilterString(spec)
    local parts = { spec.type or Filters.Harmful }

    if spec.tokens then
        for token, state in pairs(spec.tokens) do
            if state == true then
                tinsert(parts, token)
            elseif state == false and not NON_NEGATABLE[token] then
                tinsert(parts, NEG .. token)
            end
        end
    end

    local filterString = AuraUtil.CreateFilterString(unpack(parts))
    if not AuraUtil.IsValidFilterString(filterString) then -- Make sure we always return a valid filter string.
        return spec.type or Filters.Harmful
    end
    return filterString
end

---Add spellIDs from the global blocklist to the excludeSpellIDs table. Returns nil when no blocklist is defined.
---@param into table? existing excludeSpellIDs to extend
---@return table?
local function AddBlocklistExclusions(into)
    local blocklist = NRSKNUI.db.global.AuraBlocklist
    if not blocklist then return into end

    for spellId, entry in pairs(blocklist) do
        if type(spellId) == 'number' and spellId > 0 then
            local enabled = type(entry) ~= 'table' or entry.enabled ~= false
            if enabled then
                into = into or {}
                into[spellId] = true
            end
        end
    end
    return into
end

---Build the candidateFilters table from a spec's candidate fields. Returns nil when no candidates are defined.
---@param spec table
---@return table?
local function BuildCandidateFilters(spec)
    local specCandidates = spec.candidates
    local cFilter

    if specCandidates then
        -- Copy the boolean candidate fields from the spec into a new table, ignoring nils.
        for _, field in ipairs(BOOL_CANDIDATE_FIELDS) do
            local value = specCandidates[field]
            if value == true then
                cFilter = cFilter or {}
                cFilter[field] = true
            elseif value == false and BOOL_NEGATION then
                cFilter = cFilter or {}
                cFilter[field] = false
            end
        end

        -- Copy the table candidate fields from the spec into a new table, ignoring nils.
        for _, field in ipairs(TABLE_CANDIDATE_FIELDS) do
            local table = specCandidates[field]
            if type(table) == 'table' and next(table) ~= nil then
                cFilter = cFilter or {}
                cFilter[field] = CopyTable(table) -- copy so the blocklist merge / native side never mutate the stored spec
            end
        end

        -- Copy the maxDuration candidate field from the spec into a new table, ignoring nils.
        if type(specCandidates.maxDuration) == 'number' and specCandidates.maxDuration > 0 then
            cFilter = cFilter or {}
            cFilter.maxDuration = specCandidates.maxDuration
        end
    end

    -- Merge the global blocklist into the excludeSpellIDs table, if the spec allows it.
    if spec.useGlobalBlocklist ~= false then
        local exclusions = AddBlocklistExclusions(cFilter and cFilter.excludeSpellIDs)
        if exclusions then
            cFilter = cFilter or {}
            cFilter.excludeSpellIDs = exclusions
        end
    end

    return cFilter
end

-- name -> { filterString, candidateFilters }, rebuilt lazily and cleared on Invalidate.
local cache = {}

---Compiled filter for a name. Returns nil when the name is unknown so callers can fall back.
---@param name string?
---@return string? filterString
---@return table? candidateFilters
function AuraFilters:Get(name)
    if not name then return nil end

    local cached = cache[name]
    if cached then
        return cached.filterString, cached.candidateFilters
    end

    local spec = GetSpec(name)
    if not spec then return nil end

    local filterString = BuildFilterString(spec)
    local candidateFilters = BuildCandidateFilters(spec)
    cache[name] = { filterString = filterString, candidateFilters = candidateFilters }
    return filterString, candidateFilters
end

---@param name string?
---@return boolean
function AuraFilters:Exists(name)
    return GetSpec(name) ~= nil
end

---Sorted { key, text } list for GUI dropdowns.
---@return table[]
function AuraFilters:GetList()
    local list = {}
    local store = GetStore()
    if store then
        for key, spec in pairs(store) do
            tinsert(list, { key = key, text = (type(spec) == 'table' and spec.name) or key })
        end
        tsort(list, function(a, b)
            return a.text < b.text
        end)
    end
    return list
end

-- Consumer callbacks for live updates when a spec changes. Keyed by consumer table, value is callback function.
local callbacks = {}

---@param consumer table
---@param callback fun(consumer: table, name: string?)
function AuraFilters:RegisterCallback(consumer, callback)
    callbacks[consumer] = callback
end

---@param consumer table
function AuraFilters:UnregisterCallback(consumer)
    callbacks[consumer] = nil
end

---Clear the compile cache for a filter (or all filters) and notify consumers.
---Call after editing a spec in place, or after any change to the global blocklist (pass no name).
---@param name string?
function AuraFilters:Invalidate(name)
    if name then
        cache[name] = nil
    else
        wipe(cache)
    end
    for consumer, callback in pairs(callbacks) do
        callback(consumer, name)
    end
end

---Convenience on the addon namespace so consumers read cleanly (matches container:AddFilteredGroup).
---@param name string?
---@return string? filterString
---@return table? candidateFilters
function NRSKNUI:GetAuraFilter(name)
    return AuraFilters:Get(name)
end

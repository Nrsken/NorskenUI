---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AuraFilters
local AuraFilters = {}
NRSKNUI.AuraFilters = AuraFilters

local L = NRSKNUI.Libs.AL

local AuraUtil = AuraUtil
local ipairs = ipairs
local pairs = pairs
local type = type
local next = next
local unpack = unpack
local wipe = wipe
local tinsert = table.insert
local tconcat = table.concat
local tsort = table.sort
local format = string.format
local CopyTable = CopyTable

--[[

Centralized aura filter registry.

A filter string is an intersection, not a union: 'HELPFUL|BIG_DEFENSIVE' means helpful AND
big defensive, and includeSpellIDs narrows the same way. To express OR a filter is an ordered
list of branches, each branch being one base type + tokens + candidates. The container adds
one aura group per branch and every group feeds the same flow layout.

Consumers never build these themselves, they just reference a filter by name:

API: for _, branch in ipairs(NRSKNUI:GetAuraFilter(self.db.Filter)) do
A!     container:AddGroup(branch.filterString, { candidateFilters = branch.candidateFilters })
A! end

or, via the container convenience that also remembers the binding for live updates:

API: container:AddFilteredGroup(self.db.Filter)

Note that groups do not deduplicate: an aura matching two branches is shown once per branch.
Use a negated token ('!BIG_DEFENSIVE') on the later branch to keep the branches disjoint.

--]]

-- Blizzard tokens/constants read from the live client, never hardcoded since these can change between patches.
local Filters = AuraUtil.AuraFilters
local NEG = AuraUtil.AuraFilterNegationPrefix

-- These two ignore negation, so we never emit '!' for them.
local NON_NEGATABLE = { [Filters.IncludeNameplateOnly] = true, [Filters.Maw] = true }

-- Boolean candidate fields that can be true, false or nil.
local BOOL_CANDIDATE_FIELDS = {
    'isBossAura', 'isBossOrRoleAura', 'isRoleAura', 'isPriorityAura', 'isStealable',
    'isFromPlayerOrPlayerPet', 'canApplyAura', 'nameplateShowAll', 'nameplateShowPersonal',
}

-- Table candidate fields that can be a table or nil.
local TABLE_CANDIDATE_FIELDS = {
    'includeDispelTypes', 'excludeDispelTypes', 'includeSpellIDs', 'excludeSpellIDs',
}

-- The two candidate fields the client only applies in one direction, see BranchRestriction.
local SPELLID_CANDIDATE_FIELDS = { 'includeSpellIDs', 'excludeSpellIDs' }

local function GetStore()
    return NRSKNUI.db.global.AuraFilters
end

local function GetSpec(name)
    local store = GetStore()
    return store and store[name]
end

---Assemble the parse filter string from a branch's base type + triple state tokens.
---@param branch table
---@return string
local function BuildFilterString(branch)
    local parts = { branch.type or Filters.Harmful }

    if branch.tokens then
        for token, state in pairs(branch.tokens) do
            if state == true then
                tinsert(parts, token)
            elseif state == false and not NON_NEGATABLE[token] then
                tinsert(parts, NEG .. token)
            end
        end
    end

    local filterString = AuraUtil.CreateFilterString(unpack(parts))
    if not AuraUtil.IsValidFilterString(filterString) then -- Make sure we always return a valid filter string.
        return branch.type or Filters.Harmful
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

---Merge a named spellID list's spells into the matching include/exclude map by its type.
---@param cFilter table? existing candidateFilters to extend
---@param list table { type: string, spells: table }
---@return table? cFilter
local function AddNamedList(cFilter, list)
    local field = list.type == 'whitelist' and 'includeSpellIDs' or 'excludeSpellIDs'
    if type(list.spells) ~= 'table' then return cFilter end

    for spellId in pairs(list.spells) do
        if type(spellId) == 'number' and spellId > 0 then
            cFilter = cFilter or {}
            cFilter[field] = cFilter[field] or {}
            cFilter[field][spellId] = true
        end
    end
    return cFilter
end

---The spellID lists a branch has attached (branch.spellLists = { [key] = true }), resolved against
---the store and sorted by display name so both the merge and the summary see a stable order.
---Returns nil when the branch attaches none.
---@param branch table
---@return { name: string, type: string, list: table }[]?
local function ResolveAttachedLists(branch)
    local attached = branch.spellLists
    local store = NRSKNUI.db.global.AuraSpellLists
    if type(attached) ~= 'table' or type(store) ~= 'table' then return nil end

    local resolved
    for key, on in pairs(attached) do
        local list = on and store[key]
        if type(list) == 'table' then
            resolved = resolved or {}
            tinsert(resolved, { name = list.name or key, type = list.type, list = list })
        end
    end
    if resolved then
        tsort(resolved, function(a, b) return a.name < b.name end)
    end

    return resolved
end

---Merge every spellID list a branch has attached.
---@param cFilter table? existing candidateFilters to extend
---@param attached { list: table }[]? from ResolveAttachedLists
---@return table? cFilter
local function AddAttachedLists(cFilter, attached)
    if not attached then return cFilter end

    for _, entry in ipairs(attached) do
        cFilter = AddNamedList(cFilter, entry.list)
    end
    return cFilter
end

---Build the candidateFilters table from a branch's candidate fields. Returns nil when no candidates
---are defined. The global blocklist lives on the spec, so it is merged into every branch.
---@param branch table
---@param spec table
---@param attached { list: table }[]? from ResolveAttachedLists
---@return table?
local function BuildCandidateFilters(branch, spec, attached)
    local specCandidates = branch.candidates
    local cFilter

    if specCandidates then
        -- Copy the boolean candidate fields from the spec into a new table, ignoring nils.
        for _, field in ipairs(BOOL_CANDIDATE_FIELDS) do
            local value = specCandidates[field]
            if value == true then
                cFilter = cFilter or {}
                cFilter[field] = true
            elseif value == false then
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

        -- Matching on AuraUtil.ProcessAura's classification. This only works while the container runs
        -- the ProcessAura policy, container:AddFilteredGroup turns it on when it sees this field.
        local processedAuraType = specCandidates.processedAuraType
        if type(processedAuraType) == 'number' and processedAuraType ~= AuraUtil.AuraUpdateChangedType.None then
            cFilter = cFilter or {}
            cFilter.processedAuraType = processedAuraType
        end
    end

    -- Merge any named spellID lists the branch has attached (blacklist -> exclude, whitelist -> include).
    cFilter = AddAttachedLists(cFilter, attached)

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

-- name -> { { filterString, candidateFilters }, ... }, rebuilt lazily and cleared on Invalidate.
local cache = {}

---Fold a pre-branch spec into a single branch. Filters used to be one base type + one token/candidate
---set, that is now branches[1]. Runs once at load so the GUI never sees a half-migrated spec.
---@param spec table
local function MigrateSpec(spec)
    if type(spec.branches) == 'table' then return end

    spec.branches = { {
        type = spec.type,
        tokens = spec.tokens,
        candidates = spec.candidates,
        spellLists = spec.spellLists,
    } }
    spec.type, spec.tokens, spec.candidates, spec.spellLists = nil, nil, nil, nil
end

---Fold every stored spec into the branch shape. Called from Init once the db exists.
function AuraFilters:Migrate()
    local store = GetStore()
    if not store then return end

    for _, spec in pairs(store) do
        if type(spec) == 'table' then MigrateSpec(spec) end
    end
end

---Compiled branches for a name, in the order the container should add groups. A name that is not a
---registered spec but is itself a valid filter string (the GUI's "none" entry stores a bare
---HELPFUL/HARMFUL) compiles to a single branch, so a selection always resolves to a real filter.
---Returns nil when it is neither, so callers can fall back.
---@param name string?
---@return table[]? branches { filterString: string, candidateFilters: table?, spellLists: table?, type: string }
function AuraFilters:GetBranches(name)
    if not name then return nil end

    local cached = cache[name]
    if cached then return cached end

    local spec = GetSpec(name)
    if not spec then
        if not AuraUtil.IsValidFilterString(name) then return nil end
        return { { filterString = name } }
    end

    MigrateSpec(spec) -- specs created before branches existed, and any imported from an older profile

    local branches = {}
    for index, branch in ipairs(spec.branches) do
        -- Kept on the compiled branch so the summary can name the lists a spell came from,
        -- which the merged include/exclude maps no longer say.
        local attached = ResolveAttachedLists(branch)
        branches[index] = {
            filterString = BuildFilterString(branch),
            candidateFilters = BuildCandidateFilters(branch, spec, attached),
            spellLists = attached,
            -- The base type on its own, which the filter string no longer separates out. Only the
            -- summary reads it, to say which way round a spellID restriction bites.
            type = branch.type or Filters.Harmful,
        }
    end

    -- A spec with every branch deleted would silently match nothing, so keep one default branch.
    if not branches[1] then
        branches[1] = { filterString = Filters.Harmful }
    end

    cache[name] = branches
    return branches
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

---Counts the entries in a candidate sub-table, which are keyed maps rather than arrays.
---@param map table?
---@return number
local function CountKeys(map)
    local count = 0
    if map then
        for _ in pairs(map) do count = count + 1 end
    end
    return count
end

---Does this branch match on a spellID the client can refuse to look at?
---@param candidates table? compiled candidateFilters
---@return boolean
local function HasSecretSpellID(candidates)
    if not candidates then return false end

    for _, field in ipairs(SPELLID_CANDIDATE_FIELDS) do
        for spellId in pairs(candidates[field] or {}) do
            if NRSKNUI:IsSpellAuraSecret(spellId) then return true end
        end
    end
    return false
end

---Branch restriction text for the GUI's FilterCard summary, when the branch has a candidate filter that the client may ignore. Returns nil when there is no restriction.
---@param branch table compiled branch
---@return string? line
local function BranchRestriction(branch)
    if not HasSecretSpellID(branch.candidateFilters) then return nil end

    local text
    if branch.type == Filters.Harmful then
        text = L['Spell IDs are ignored for debuffs on you and units you can assist.']
    elseif branch.type == Filters.Helpful then
        text = L['Spell IDs are ignored for buffs on units you cannot assist.']
    else
        text = L['Spell IDs are ignored for debuffs on friendly units and buffs on hostile units.']
    end

    return NRSKNUI:ColorText(text, NRSKNUI.Colors.warning)
end

---One branch's candidate filters as short phrases, appended to its filter string in the summary.
---Empty when the branch matches on the filter string alone, which reads as an absence.
---@param branch table
---@return string[]
local function BranchQualifiers(branch)
    local parts = {}

    -- An attached list is named rather than counted: where the spells came from says more than
    -- how many there are, and the name is what the user picked it by.
    local namedInclude, namedExclude
    if branch.spellLists then
        for _, entry in ipairs(branch.spellLists) do
            local isInclude = entry.type == 'whitelist'
            if isInclude then namedInclude = true else namedExclude = true end
            tinsert(parts, format(isInclude and L['Including %s'] or L['Excluding %s'], entry.name))
        end
    end

    local candidates = branch.candidateFilters
    if not candidates or not next(candidates) then return parts end

    -- Counts only where there is no named list to point at, so a list is never described twice.
    local include = CountKeys(candidates.includeSpellIDs)
    local exclude = CountKeys(candidates.excludeSpellIDs)
    if include > 0 and not namedInclude then tinsert(parts, format(L['Included spell IDs: %d'], include)) end
    if exclude > 0 and not namedExclude then tinsert(parts, format(L['Excluded spell IDs: %d'], exclude)) end

    local includeDispel = CountKeys(candidates.includeDispelTypes)
    local excludeDispel = CountKeys(candidates.excludeDispelTypes)
    if includeDispel > 0 then tinsert(parts, format(L['Included dispel types: %d'], includeDispel)) end
    if excludeDispel > 0 then tinsert(parts, format(L['Excluded dispel types: %d'], excludeDispel)) end

    if candidates.maxDuration then
        tinsert(parts, format(L['Max duration: %ds'], candidates.maxDuration))
    end
    if candidates.processedAuraType then
        tinsert(parts, L['Uses ProcessAura classification.'])
    end

    -- Whatever is left is a boolean flag candidate, list them by name so this needs no table of its own.
    for key, value in pairs(candidates) do
        if type(value) == 'boolean' then
            tinsert(parts, format('%s: %s', key, value and L['Require'] or L['Exclude']))
        end
    end

    return parts
end

---Human-readable summary of what a named filter resolves to, for the GUI's FilterCard summary.
---Compiled through :GetBranches, so it always reflects live edits made on the Aura Filters page.
---One bullet per branch, plus the heading that introduces them, which the card uses as its title.
---@param name string?
---@return string[] lines
---@return string heading
function AuraFilters:Describe(name)
    -- The heading carries the accent itself, since it lands in a title the card draws in body colour.
    if not name or name == '' then
        return {}, NRSKNUI:ColorTextByTheme(L['No filter selected, every harmful aura is shown.'])
    end

    local branches = self:GetBranches(name)
    if not branches then
        return {}, NRSKNUI:ColorTextByTheme(format(L["Filter '%s' no longer exists."], name))
    end

    local lines = {}
    for index, branch in ipairs(branches) do
        local qualifiers = BranchQualifiers(branch)
        tinsert(qualifiers, 1, branch.filterString)
        -- Only the branch number stays in the body colour, so the eye lands on what each one matches.
        tinsert(lines, format(L['Branch %d: %s'], index, NRSKNUI:ColorTextByTheme(tconcat(qualifiers, ', '))))

        -- Its own line under the branch it belongs to, since it contradicts what that line just said.
        local restriction = BranchRestriction(branch)
        if restriction then tinsert(lines, restriction) end
    end

    local heading = #branches == 1 and L['Matches auras in the branch:']
        or format(L['Matches auras in any of %d branches, shown once per branch:'], #branches)

    return lines, NRSKNUI:ColorTextByTheme(heading)
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
---@return table[]? branches { filterString: string, candidateFilters: table?, spellLists: table?, type: string }
function NRSKNUI:GetAuraFilter(name)
    return AuraFilters:GetBranches(name)
end

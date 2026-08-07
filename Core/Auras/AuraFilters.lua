---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AuraFilters
local AuraFilters = {}
NRSKNUI.AuraFilters = AuraFilters
local L = NRSKNUI.Libs.AL

local tinsert, tconcat = table.insert, table.concat
local ipairs, pairs = ipairs, pairs
local format = string.format
local CopyTable = CopyTable
local unpack = unpack
local type = type
local next = next

local AuraUtil = AuraUtil
local Filters = AuraUtil.AuraFilters
local NEG = AuraUtil.AuraFilterNegationPrefix

-- These two ignore negation, so we never emit '!' for them.
local NON_NEGATABLE = {
    [Filters.IncludeNameplateOnly] = true,
    [Filters.Maw] = true,
}

-- Boolean candidate fields that can be true, false or nil.
AuraFilters.BoolCandidateFields = {
    'isBossAura',
    'isBossOrRoleAura',
    'isRoleAura',
    'isPriorityAura',
    'isStealable',
    'isFromPlayerOrPlayerPet',
    'canApplyAura',
    'nameplateShowAll',
    'nameplateShowPersonal',
}

-- Table candidate fields that can be a table or nil.
AuraFilters.TableCandidateFields = {
    'includeDispelTypes',
    'excludeDispelTypes',
    'includeSpellIDs',
    'excludeSpellIDs',
}

-- The two candidate fields the client only applies in one direction, see :BranchRestriction.
local SPELLID_CANDIDATE_FIELDS = {
    'includeSpellIDs',
    'excludeSpellIDs',
}

local BOOL_CANDIDATE_FIELDS = AuraFilters.BoolCandidateFields
local TABLE_CANDIDATE_FIELDS = AuraFilters.TableCandidateFields

---Assemble the parse filter string from a branch's base type + triple state tokens.
---The base is the trigger's, so a branch only carries its own type when a preset gave it one.
---@param branch table
---@param baseType string?
---@return string
local function BuildFilterString(branch, baseType)
    local parts = { branch.type or baseType or Filters.Harmful }

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
        return branch.type or baseType or Filters.Harmful
    end
    return filterString
end

---Build the candidateFilters table from a branch's candidate fields. Returns nil when none are defined.
---@param branch table
---@return table?
local function BuildCandidateFilters(branch)
    local specCandidates = branch.candidates
    if not specCandidates then return nil end

    local cFilter

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
        local map = specCandidates[field]
        if type(map) == 'table' and next(map) ~= nil then
            cFilter = cFilter or {}
            cFilter[field] = CopyTable(map) -- copy so the native side never mutates the stored trigger
        end
    end

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

    return cFilter
end

---Compile a stored branch list into the groups a container adds, one per branch.
---@param branches table[]? stored branches, each { type?, tokens?, candidates? }
---@param baseType string? the trigger's HELPFUL/HARMFUL, used by every branch that carries no type of its own
---@return table[] compiled { filterString: string, candidateFilters: table?, type: string }
function AuraFilters:Compile(branches, baseType)
    local compiled = {}

    for index, branch in ipairs(branches or {}) do
        compiled[index] = {
            filterString = BuildFilterString(branch, baseType),
            candidateFilters = BuildCandidateFilters(branch),
            -- The base type on its own, which the filter string no longer separates out. Only the
            -- summary reads it, to say which way round a spellID restriction bites.
            type = branch.type or baseType or Filters.Harmful,
        }
    end

    if not compiled[1] then
        compiled[1] = { filterString = baseType or Filters.Harmful, type = baseType or Filters.Harmful }
    end

    return compiled
end

---Does this branch decide what to show from a spellID include list?
---@param candidates table? compiled candidateFilters
---@return boolean
function AuraFilters:HasSpellIDCandidates(candidates)
    if not candidates then return false end

    for _ in pairs(candidates.includeSpellIDs or {}) do return true end
    return false
end

---Does this branch match on a spellID the client can refuse to look at?
---@param candidates table? compiled candidateFilters
---@return boolean
function AuraFilters:HasSecretSpellID(candidates)
    if not candidates then return false end

    for _, field in ipairs(SPELLID_CANDIDATE_FIELDS) do
        for spellId in pairs(candidates[field] or {}) do
            if NRSKNUI:IsSpellAuraSecret(spellId) then return true end
        end
    end
    return false
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

---Branch restriction text for a summary, when the branch has a candidate filter the client may ignore.
---Returns nil when there is no restriction.
---@param branch table compiled branch
---@return string? line
local function BranchRestriction(branch)
    if not AuraFilters:HasSecretSpellID(branch.candidateFilters) then return nil end

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
---@param branch table compiled branch
---@return string[]
local function BranchQualifiers(branch)
    local parts = {}

    local candidates = branch.candidateFilters
    if not candidates or not next(candidates) then return parts end

    local include = CountKeys(candidates.includeSpellIDs)
    local exclude = CountKeys(candidates.excludeSpellIDs)
    if include > 0 then tinsert(parts, format(L['Included spell IDs: %d'], include)) end
    if exclude > 0 then tinsert(parts, format(L['Excluded spell IDs: %d'], exclude)) end

    local includeDispel = CountKeys(candidates.includeDispelTypes)
    local excludeDispel = CountKeys(candidates.excludeDispelTypes)
    if includeDispel > 0 then tinsert(parts, format(L['Included dispel types: %d'], includeDispel)) end
    if excludeDispel > 0 then tinsert(parts, format(L['Excluded dispel types: %d'], excludeDispel)) end

    if candidates.maxDuration then tinsert(parts, format(L['Max duration: %ds'], candidates.maxDuration)) end
    if candidates.processedAuraType then tinsert(parts, L['Uses ProcessAura classification.']) end

    -- Whatever is left is a boolean flag candidate, list them by name so this needs no table of its own.
    for key, value in pairs(candidates) do
        if type(value) == 'boolean' then
            tinsert(parts, format('%s: %s', key, value and L['Require'] or L['Exclude']))
        end
    end

    return parts
end

---Readable summary of what an already-compiled branch list matches.
---@param compiled table[]? from :Compile
---@return string[] lines
---@return string heading
function AuraFilters:Describe(compiled)
    if not compiled or not compiled[1] then
        return {}, NRSKNUI:ColorTextByTheme(L['This trigger matches nothing yet.'])
    end

    local lines = {}
    for index, branch in ipairs(compiled) do
        local qualifiers = BranchQualifiers(branch)
        tinsert(qualifiers, 1, branch.filterString)
        -- Only the branch number stays in the body color, so the eye lands on what each one matches.
        tinsert(lines, format(L['Branch %d: %s'], index, NRSKNUI:ColorTextByTheme(tconcat(qualifiers, ', '))))

        -- Its own line under the branch it belongs to, since it contradicts what that line just said.
        local restriction = BranchRestriction(branch)
        if restriction then tinsert(lines, restriction) end
    end

    local heading = #compiled == 1 and L['Matches auras in the branch:'] or format(L['Matches auras in any of %d branches, shown once per branch:'], #compiled)
    return lines, NRSKNUI:ColorTextByTheme(heading)
end

---Every spellID a compiled branch list matches on.
---@param compiled table[]? from :Compile
---@return table spellIds { [spellId] = true }
function AuraFilters:GetSpellIDs(compiled)
    local spellIds = {}

    for _, branch in ipairs(compiled or {}) do
        for _, field in ipairs(SPELLID_CANDIDATE_FIELDS) do
            for spellId in pairs(branch.candidateFilters and branch.candidateFilters[field] or {}) do
                spellIds[spellId] = true
            end
        end
    end

    return spellIds
end

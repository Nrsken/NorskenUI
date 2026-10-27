---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AuraTriggers
local AuraTriggers = {}
NRSKNUI.AuraTriggers = AuraTriggers
local L = NRSKNUI.Libs.AL

local CopyTable = CopyTable
local pairs = pairs
local ipairs = ipairs
local type = type
local next = next

local AF = AuraUtil.AuraFilters

--[[

What an aura display matches, owned inline by whatever display owns it. There is no registry: a
trigger is edited on the display's own Trigger tab and read straight back by it.

    Trigger = {
        Type = 'Preset' | 'AuraFilter',
        Unit = 'player' | 'target',      -- standalone displays only, unit frames use their own unit
        Base = 'HELPFUL' | 'HARMFUL',    -- applies to every branch, meaningless for Preset

        Preset   = 'preset:defensives',                   -- Type == Preset
        Added    = { [spellID] = 'GROUP' },               -- Type == Preset, spells added to its list
        Removed  = { [spellID] = true },                  -- Type == Preset, shipped spells switched off
        branches = { { tokens =, candidates =, shipped = }, ... },   -- Type == AuraFilter
    }

A branch's `shipped` links a spell condition to a preset's list, so it keeps getting list updates.
Old 'SpellIDs'/'Preset' saves still compile; the trigger editor converts them to AuraFilter on open.

Every type compiles to the same branch list through AuraFilters:Compile, so a container never learns
which type produced it.

API: NRSKNUI:GetTriggerBranches(trigger)

--]]

AuraTriggers.Types = {
    SpellIDs = 'SpellIDs',
    Preset = 'Preset',
    AuraFilter = 'AuraFilter',
}

local Types = AuraTriggers.Types

NRSKNUI:OnLanguageSet(function()
    AuraTriggers.UnitOptions = {
        { value = 'player', text = L['Player'] },
        { value = 'target', text = L['Target'] },
    }
end)

local Defaults = {
    Type = Types.AuraFilter,
    Unit = 'player',
    Base = AF.Harmful,
    Preset = '',
    branches = { {} },
}

---A fresh trigger, for a new display or a display that has none yet.
---@param overrides table? merged over the defaults
---@return table trigger
function AuraTriggers:New(overrides)
    local trigger = CopyTable(Defaults)

    for key, value in pairs(overrides or {}) do
        trigger[key] = value
    end

    return trigger
end

---A branch matching everything the base type allows, so an empty AuraFilter trigger still resolves.
---@param trigger table
---@return table[]
local function BareBranch(trigger)
    return { { type = trigger.Base or AF.Harmful } }
end

--[[

API: NRSKNUI:GetTriggerBranches(trigger)

Compile a trigger into the { filterString, candidateFilters } branches an aura container consumes,
one aura group per branch. Always at least one, so a binding never ends up with no groups.

* trigger - an inline trigger table (may be nil, which compiles to a bare HARMFUL)

--]]
---@param trigger table?
---@return table[] branches
function NRSKNUI:GetTriggerBranches(trigger)
    local Filters = NRSKNUI.AuraFilters

    -- A bare filter string is accepted as a one-branch trigger, which is what the displays running a
    -- hardcoded HELPFUL/HARMFUL group (PlayerAuras) and their previews pass.
    if type(trigger) == 'string' then
        if not AuraUtil.IsValidFilterString(trigger) then return Filters:Compile(nil, AF.Harmful) end
        return Filters:Compile({ { type = trigger } }, nil)
    end

    if type(trigger) ~= 'table' then
        return Filters:Compile(nil, AF.Harmful)
    end

    if trigger.Type == Types.Preset then
        -- A preset ships its own per-branch types, so it needs no base of its own.
        local branches = AuraTriggers:GetPresetBranches(trigger)
        if not branches then return Filters:Compile(nil, AF.Harmful) end

        return Filters:Compile(branches, nil)
    end

    if trigger.Type == Types.SpellIDs then
        local map = trigger.SpellIDs
        -- A spell list says which aura, never whose. The PLAYER token is how it says the latter, since
        -- a SpellIDs trigger has no branch of its own to put a token on.
        local tokens = trigger.OnlyMine and { [AF.Player] = true } or nil

        if type(map) ~= 'table' or next(map) == nil then
            -- An empty list is no filter at all to the client, so it would show everything the base
            -- matches. Nothing selected means nothing shown instead.
            return Filters:Compile({ { tokens = tokens, candidates = { includeSpellIDs = { [0] = true } } } }, trigger.Base)
        end

        return Filters:Compile({ { tokens = tokens, candidates = { includeSpellIDs = map } } }, trigger.Base)
    end

    local branches = trigger.branches
    if type(branches) ~= 'table' or not branches[1] then
        branches = BareBranch(trigger)
    end

    return Filters:Compile(branches, trigger.Base)
end

---A preset's branches with the trigger's added and switched-off spells applied.
---@param trigger table
---@return table[]? branches nil for an unknown preset
function AuraTriggers:GetPresetBranches(trigger)
    local preset = NRSKNUI.AuraFiltersPremade:Get(trigger.Preset)
    if not preset then return nil end
    if not (preset.spells and (trigger.Added or trigger.Removed)) then return preset.branches end

    local branches = CopyTable(preset.branches)
    local map = branches[1].candidates[preset.spellField]
    for id, group in pairs(trigger.Added or {}) do map[id] = group end
    for id in pairs(trigger.Removed or {}) do map[id] = nil end

    return branches
end

---Rewrite an old Spell IDs trigger as the one Aura Filter branch it always compiled to.
---@param trigger table
function AuraTriggers:ConvertSpellIDs(trigger)
    if trigger.Type ~= Types.SpellIDs then return end

    local ids = {}
    for id in pairs(trigger.SpellIDs or {}) do ids[id] = 'OTHER' end

    trigger.branches = {
        { tokens = trigger.OnlyMine and { [AF.Player] = true } or nil, candidates = { includeSpellIDs = ids } },
    }
    trigger.Type = Types.AuraFilter
    trigger.SpellIDs, trigger.OnlyMine = nil, nil
end

---Type and branches are written explicitly so the AceDB Preset default can't revert it on load.
---@param trigger table
function AuraTriggers:ConvertPreset(trigger)
    if trigger.Type ~= Types.Preset then return end

    local converted = self:ToAuraFilter(trigger)
    trigger.Type, trigger.Base, trigger.branches = converted.Type, converted.Base, converted.branches
    trigger.Preset, trigger.Added, trigger.Removed = nil, nil, nil
end

---@param trigger table
---@param presetKey string
function AuraTriggers:LoadPreset(trigger, presetKey)
    local loaded = self:ToAuraFilter({ Type = Types.Preset, Preset = presetKey, Unit = trigger.Unit })
    trigger.Type, trigger.Base, trigger.branches = loaded.Type, loaded.Base, loaded.branches
end

---An editable preset's spell list stays linked to the shipped one rather than copied.
---@param trigger table
---@return table trigger
function AuraTriggers:ToAuraFilter(trigger)
    self:ConvertSpellIDs(trigger)

    local branches
    if trigger.Type == Types.Preset then
        local preset = NRSKNUI.AuraFiltersPremade:Get(trigger.Preset)
        branches = CopyTable(preset and preset.branches or { {} })
        if preset and preset.spells then
            branches[1].candidates[preset.spellField] = nil
            branches[1].shipped = {
                list = preset.key,
                field = preset.spellField,
                Added = trigger.Added and CopyTable(trigger.Added),
                Removed = trigger.Removed and CopyTable(trigger.Removed),
            }
        end
    else
        branches = CopyTable(trigger.branches or { {} })
    end

    local base = branches[1].type or trigger.Base or AF.Harmful
    -- Presets carry a type per branch; the editor only has the trigger-wide one, so it moves up.
    for _, branch in ipairs(branches) do
        if branch.type == base then branch.type = nil end
    end

    return self:New({ Unit = trigger.Unit, Base = base, branches = branches })
end

---@param trigger table?
---@return table? shipped
function AuraTriggers:GetShipped(trigger)
    for _, branch in ipairs(trigger and trigger.branches or {}) do
        if branch.shipped then return branch.shipped end
    end
end

---How many groups a trigger will build, one per branch. maxFrameCount is a per-group cap, so callers
---sizing a display's worst case have to multiply by this.
---@param trigger table?
---@return number
function NRSKNUI:GetTriggerBranchCount(trigger)
    return #NRSKNUI:GetTriggerBranches(trigger)
end

---Readable summary of what a trigger matches, for the GUI.
---@param trigger table?
---@return string[] lines
---@return string heading
function AuraTriggers:Describe(trigger)
    return NRSKNUI.AuraFilters:Describe(NRSKNUI:GetTriggerBranches(trigger))
end

-- Consumers that want telling when any trigger changed, keyed by consumer table. A page can affect
-- several live displays at once (every unit frame sharing a unit config), so this stays a broadcast
-- rather than a direct call from the GUI.
local callbacks = {}

---@param consumer table
---@param callback fun(consumer: table)
function AuraTriggers:RegisterCallback(consumer, callback)
    callbacks[consumer] = callback
end

---@param consumer table
function AuraTriggers:UnregisterCallback(consumer)
    callbacks[consumer] = nil
end

---Tell every consumer a trigger changed, so live displays rebind.
function AuraTriggers:Invalidate()
    for consumer, callback in pairs(callbacks) do
        callback(consumer)
    end
end

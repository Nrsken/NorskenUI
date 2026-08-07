---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AuraTriggers
local AuraTriggers = {}
NRSKNUI.AuraTriggers = AuraTriggers
local L = NRSKNUI.Libs.AL

local CopyTable = CopyTable
local pairs = pairs
local tsort = table.sort
local type = type
local next = next

local AF = AuraUtil.AuraFilters

--[[

What an aura display matches, owned inline by whatever display owns it. There is no registry: a
trigger is edited on the display's own Trigger tab and read straight back by it.

    Trigger = {
        Type = 'SpellIDs' | 'Preset' | 'AuraFilter',
        Unit = 'player' | 'target',      -- standalone displays only, unit frames use their own unit
        Base = 'HELPFUL' | 'HARMFUL',    -- applies to every branch, meaningless for Preset

        SpellIDs = { [spellID] = true },                  -- Type == SpellIDs
        OnlyMine = true,                                  -- Type == SpellIDs, adds the PLAYER token
        Preset   = 'preset:defensives',                   -- Type == Preset
        branches = { { tokens =, candidates = }, ... },   -- Type == AuraFilter
    }

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

-- Dropdown option lists, shared by every Trigger card.
AuraTriggers.TypeOptions = {
    { value = Types.SpellIDs,   text = L['Spell IDs'] },
    { value = Types.Preset,     text = L['Preset'] },
    { value = Types.AuraFilter, text = L['Aura Filter'] },
}

AuraTriggers.UnitOptions = {
    { value = 'player', text = L['Player'] },
    { value = 'target', text = L['Target'] },
}

AuraTriggers.BaseOptions = {
    { value = AF.Helpful, text = L['Buffs (Helpful)'] },
    { value = AF.Harmful, text = L['Debuffs (Harmful)'] },
}

-- Only Preset carries its own base, so the head's Base dropdown is hidden for it.
AuraTriggers.UsesBase = {
    [Types.SpellIDs] = true,
    [Types.AuraFilter] = true,
}

local Defaults = {
    Type = Types.AuraFilter,
    Unit = 'player',
    Base = AF.Harmful,
    SpellIDs = {},
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
        local preset = NRSKNUI.AuraFiltersPremade:Get(trigger.Preset)
        if not preset then return Filters:Compile(nil, AF.Harmful) end

        return Filters:Compile(preset.branches, nil)
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

---Sorted spell IDs a SpellIDs trigger holds, so a card can list them back in a stable order.
---@param trigger table?
---@return number[]
function AuraTriggers:GetSpellIDList(trigger)
    local ids = {}
    if type(trigger) ~= 'table' or type(trigger.SpellIDs) ~= 'table' then return ids end

    for spellID in pairs(trigger.SpellIDs) do
        ids[#ids + 1] = spellID
    end
    tsort(ids)

    return ids
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

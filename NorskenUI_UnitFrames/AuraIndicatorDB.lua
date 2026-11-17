---@class NorskenUI
local NRSKNUI = _G.NorskenUI
---@class AuraIndicators
local AuraIndicators = {}
NRSKNUI.AuraIndicators = AuraIndicators
local L = NRSKNUI.Libs.AL

local tsort, tremove = table.sort, table.remove
local ipairs, pairs = ipairs, pairs
local format = string.format
local CopyTable = CopyTable
local wipe = wipe
local type = type

AuraIndicators.Styles = {
    Overlay = 'Overlay',
    Square = 'Square',
    Icon = 'Icon',
    Duration = 'Duration',
}

-- Styles that cover their attach target whole, so they have neither size nor offset of their own.
AuraIndicators.FullCover = {
    [AuraIndicators.Styles.Overlay] = true,
}

-- Styles with a width and height of their own; an Icon's is its icon style's.
AuraIndicators.Sized = {
    [AuraIndicators.Styles.Square] = true,
    [AuraIndicators.Styles.Icon] = true,
}

-- What an indicator's proxy can be anchored to. The element resolves these against its unit frame.
AuraIndicators.Attach = {
    Frame = 'frame',
    Health = 'health',
    HealthFill = 'healthFill',
}

-- Tokens are read from the live client rather than written out, since they can change between patches.

local GROUP_PREFIX = 'group:'
-- Indicators that ship with the addon, seeded into the defaults. Keyed the same way as a user's, so
-- nothing placing or drawing one cares which it got.
local BUILTIN_PREFIX = 'builtin:'

local function GetStore()
    return NRSKNUI.db.profile.AuraIndicators
end

---Groups are only a way to organise the indicator list: a group holds a name, and an indicator points
---at one through its `group` field. Nothing about what an indicator does depends on being in one.
local function GetGroupStore()
    return NRSKNUI.db.profile.AuraIndicatorGroups
end

---@param key string?
---@return table? spec
function AuraIndicators:GetSpec(key)
    local store = GetStore()
    return key and store and store[key]
end

---@param key string?
---@return boolean
function AuraIndicators:IsBuiltin(key)
    return type(key) == 'string' and key:sub(1, #BUILTIN_PREFIX) == BUILTIN_PREFIX
end

---Sorted { key, text } list for GUI sidebars and per-unit assignment lists. Shipped indicators come
---first in a stable order, then the user's own by name.
---@return table[]
function AuraIndicators:GetList()
    local builtins, own = {}, {}
    local store = GetStore()

    for key, spec in pairs(store or {}) do
        local entry = { key = key, text = (type(spec) == 'table' and spec.name) or key }
        tinsert(self:IsBuiltin(key) and builtins or own, entry)
    end

    tsort(builtins, function(a, b) return a.text < b.text end)
    tsort(own, function(a, b) return a.text < b.text end)

    for _, entry in ipairs(own) do
        tinsert(builtins, entry)
    end

    return builtins
end

---Sorted { key, name } groups, for the sidebar and the context menu.
---@return table[]
function AuraIndicators:GetGroups()
    local list = {}

    for id, group in pairs(GetGroupStore() or {}) do
        list[#list + 1] = { key = id, name = group.name or id }
    end
    tsort(list, function(a, b) return a.name < b.name end)

    return list
end

---@param name string
---@return string? id
function AuraIndicators:CreateGroup(name)
    local store = GetGroupStore()
    if not store or not name or name == '' then return nil end

    local index = 1
    while store[GROUP_PREFIX .. index] do
        index = index + 1
    end

    local id = GROUP_PREFIX .. index
    store[id] = { name = name }

    return id
end

---Indicators never placed by hand sort after the placed ones, by name.
---@param groupId string
---@return table[] members { key, text, order? }
function AuraIndicators:GetMembers(groupId)
    local members = {}
    for key, spec in pairs(GetStore() or {}) do
        if type(spec) == 'table' and spec.group == groupId then
            members[#members + 1] = { key = key, text = spec.name or key, order = spec.order }
        end
    end
    tsort(members, function(a, b)
        if a.order and b.order and a.order ~= b.order then return a.order < b.order end
        if (a.order ~= nil) ~= (b.order ~= nil) then return a.order ~= nil end
        return a.text < b.text
    end)
    return members
end

---A group outlives its last member; only DeleteGroup removes it.
---@param key string
---@param groupId string?
function AuraIndicators:SetGroup(key, groupId)
    local spec = self:GetSpec(key)
    if not spec or spec.group == groupId then return end

    spec.order = nil
    if not groupId then
        spec.group = nil
        return
    end

    -- Numbered with the members already there, so the newcomer lands last whatever order they had.
    local members = self:GetMembers(groupId)
    for index, member in ipairs(members) do GetStore()[member.key].order = index end
    spec.group = groupId
    spec.order = #members + 1
end

---Joins the target's group; an ungrouped target ungroups it, since the top level sorts by name.
---@param key string
---@param targetKey string
---@param position 'before'|'after'
function AuraIndicators:MoveNextTo(key, targetKey, position)
    local spec, target = self:GetSpec(key), self:GetSpec(targetKey)
    if not (spec and target) or key == targetKey then return end

    local groupId = target.group
    spec.group = groupId
    spec.order = nil
    if not groupId then return end

    local ordered = {}
    for _, member in ipairs(self:GetMembers(groupId)) do
        if member.key ~= key then
            if member.key == targetKey and position == 'before' then ordered[#ordered + 1] = key end
            ordered[#ordered + 1] = member.key
            if member.key == targetKey and position == 'after' then ordered[#ordered + 1] = key end
        end
    end
    for index, memberKey in ipairs(ordered) do GetStore()[memberKey].order = index end
end

---@param groupId string
---@param name string
function AuraIndicators:RenameGroup(groupId, name)
    local group = GetGroupStore()[groupId]
    if not group or not name or name == '' then return end

    group.name = name
end

---Removes a group; its indicators stay, outside any group.
---@param groupId string
function AuraIndicators:DeleteGroup(groupId)
    for _, spec in pairs(GetStore() or {}) do
        if type(spec) == 'table' and spec.group == groupId then
            spec.group = nil
            spec.order = nil
        end
    end
    GetGroupStore()[groupId] = nil
end

local placementSources = {} ---@type fun(fn: fun(placement: table))[]

---A display that places indicators hands over a walk of its placements, so a rename reaches them.
---@param source fun(fn: fun(placement: table))
function AuraIndicators:RegisterPlacements(source)
    placementSources[#placementSources + 1] = source
end

---@param fn fun(placement: table)
local function EachPlacement(fn)
    for _, source in ipairs(placementSources) do
        source(fn)
    end
end

---A user indicator is keyed by its name, so renaming moves it, and every placement listing it follows.
---@param key string
---@param name string
---@return string? newKey nil when the name is taken or the indicator is a shipped one
function AuraIndicators:Rename(key, name)
    local store, spec = GetStore(), self:GetSpec(key)
    if not spec or self:IsBuiltin(key) or not name or name == '' then return nil end
    if name == key then return key end
    if store[name] or self:IsBuiltin(name) then return nil end

    spec.name = name
    store[name] = spec
    store[key] = nil
    EachPlacement(function(placement)
        for i, assigned in ipairs(placement.Keys) do
            if assigned == key then placement.Keys[i] = name end
        end
    end)

    self:Invalidate(key)
    return name
end

---A user copy of any indicator, shipped ones included, under the first free "(Copy)" name.
---@param key string
---@return string? newKey
function AuraIndicators:Duplicate(key)
    local source = self:GetSpec(key)
    if not source then return nil end

    local plain = source.name or key
    local store = GetStore()
    local name, n = format(L['%s (Copy)'], plain), 1
    while store[name] do
        n = n + 1
        name = format(L['%s (Copy %d)'], plain, n)
    end

    local copy = CopyTable(source)
    copy.name = name
    copy.group, copy.order, copy.category = nil, nil, nil
    store[name] = copy
    self:Invalidate(name)
    return name
end

---@param key string
function AuraIndicators:ResetBuiltin(key)
    local spec = self:GetSpec(key)
    local shipped = NRSKNUI:GetDefaultDB().profile.AuraIndicators[key]
    if not (spec and shipped and self:IsBuiltin(key)) then return end

    wipe(spec)
    for field, value in pairs(CopyTable(shipped)) do spec[field] = value end
    self:Invalidate(key)
end

-- What an indicator is: the aura it means and the colour it carries. Everything about how it is drawn lives per unit, in PlacementDefaults below.
local SpecDefaults = {
    Trigger = nil, -- filled in by :Create, since every indicator needs its own table
    sortMethod = 'ExpirationOnly',
    sortDirection = 'Normal',
    Color = { 0, 0.9, 0.5, 1 },
}

-- What a unit does with an indicator: where and how it draws it. Each style has its part:
-- Overlay and Square the tint, Duration the text, Icon the icon style and its sub elements.
local PlacementDefaults = {
    Name = '',
    Keys = {},
    Alpha = 1,
    Style = AuraIndicators.Styles.Overlay,
    Attach = AuraIndicators.Attach.Health,
    Position = { AnchorFrom = 'CENTER', AnchorTo = 'CENTER', XOffset = 0, YOffset = 0 },
    Size = { Width = 24, Height = 24 },
    Tint = NRSKNUI:NewSubRegion('tint', { ColorMode = 'indicator' }),
    Text = NRSKNUI:NewSubRegion('text', { FontSize = 12 }),
    IconStyle = { Width = 24, Height = 24, Reverse = true },
}

---Add a fully populated indicator to the store.
---@param key string
---@param name string
---@param presetKey? string start from this preset's triggers instead of an empty spell list
---@return table? spec
function AuraIndicators:Create(key, name, presetKey)
    local store = GetStore()
    -- A user's key is whatever they named it, so the shipped prefix is off limits: an indicator
    -- wearing it could never be deleted again.
    if not store or store[key] or self:IsBuiltin(key) then return nil end

    local spec = CopyTable(SpecDefaults)
    spec.name = name
    -- Its own table, not a shared default: an indicator's trigger is edited in place.
    spec.Trigger = NRSKNUI.AuraTriggers:New({ branches = { { candidates = { includeSpellIDs = {} } } } })
    -- The unit frame drawing the indicator decides the unit, so the trigger never carries one.
    spec.Trigger.Unit = nil
    if presetKey then NRSKNUI.AuraTriggers:LoadPreset(spec.Trigger, presetKey) end

    store[key] = spec
    self:Invalidate(key)

    return spec
end

---Give a unit another spot to draw indicators in, appended to its list.
---@param uDB table
---@param font table the unit frames' font, which an Icon's texts start with
---@return table placement
function AuraIndicators:AddPlacement(uDB, font)
    local placement = CopyTable(PlacementDefaults)
    placement.Order = self:TopOrder(uDB.AuraIndicators)
    -- a list, so it is seeded here rather than kept in the defaults
    placement.SubRegions = NRSKNUI:DefaultAuraGroupSubRegions({
        font = font,
        timer = { FontSize = 12, GlobalTimeColor = true },
        stacks = { FontSize = 10 },
    })

    tinsert(uDB.AuraIndicators, placement)
    return placement
end

---Order above every spot on its unit, so a new or restyled one draws on top.
---@param placements table[]
---@return number
function AuraIndicators:TopOrder(placements)
    local top = 0
    for _, placement in ipairs(placements) do
        if (placement.Order or 0) > top then top = placement.Order end
    end
    return top + 1
end

---@param placement table
---@param index number
---@return string
function AuraIndicators:GetPlacementName(placement, index)
    if placement.Name and placement.Name ~= '' then return placement.Name end

    return format(L['Indicator %d'], index)
end

---@param uDB table
---@param index number
function AuraIndicators:RemovePlacement(uDB, index)
    tremove(uDB.AuraIndicators, index)
end

---@param uDB table
---@param key string
function AuraIndicators:RemoveKeyEverywhere(uDB, key)
    for _, placement in ipairs(uDB.AuraIndicators) do
        for index = #placement.Keys, 1, -1 do
            if placement.Keys[index] == key then tremove(placement.Keys, index) end
        end
    end
end

---Remove a user indicator. Shipped ones refuse: they are seeded from the defaults and would come
---straight back on the next login.
---@param key string
function AuraIndicators:Delete(key)
    local store = GetStore()
    if not store or not store[key] or self:IsBuiltin(key) then return end

    store[key] = nil
    self:Invalidate(key)
end

-- Consumer callbacks for live updates when a spec changes. Keyed by consumer table.
local callbacks = {}

---@param consumer table
---@param callback fun(consumer: table, key: string?)
function AuraIndicators:RegisterCallback(consumer, callback)
    callbacks[consumer] = callback
end

---@param consumer table
function AuraIndicators:UnregisterCallback(consumer)
    callbacks[consumer] = nil
end

---Notify consumers that an indicator (or all of them) changed.
---@param key string?
function AuraIndicators:Invalidate(key)
    for consumer, callback in pairs(callbacks) do
        callback(consumer, key)
    end
end

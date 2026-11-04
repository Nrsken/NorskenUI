---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AuraIndicators
local AuraIndicators = {}
NRSKNUI.AuraIndicators = AuraIndicators
local L = NRSKNUI.Libs.AL

local tsort, tremove = table.sort, table.remove
local ipairs, pairs = ipairs, pairs
local format, gsub = string.format, string.gsub
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

-- Styles with a width and height of their own.
AuraIndicators.Sized = {
    [AuraIndicators.Styles.Square] = true,
    [AuraIndicators.Styles.Icon] = true,
}

AuraIndicators.Previewable = {
    [AuraIndicators.Styles.Overlay] = true,
    [AuraIndicators.Styles.Square] = true,
    [AuraIndicators.Styles.Icon] = true,
    [AuraIndicators.Styles.Duration] = true,
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

---Compiled branches for an indicator, in the same shape a container binding consumes.
---@param spec table
---@return table[] branches
function AuraIndicators:GetBranches(spec)
    return NRSKNUI:GetTriggerBranches(spec.Trigger)
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

    -- Shipped names carry a class colour escape, which a user's key should not.
    local plain = gsub(gsub(source.name or key, '|c%x%x%x%x%x%x%x%x', ''), '|r', '')
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

---Readable summary of what an indicator matches, for the GUI card.
---@param key string?
---@return string[] lines
---@return string heading
function AuraIndicators:Describe(key)
    local spec = self:GetSpec(key)
    if not spec then
        return {}, NRSKNUI:ColorTextByTheme(L['This indicator no longer exists.'])
    end

    local lines = NRSKNUI.AuraTriggers:Describe(spec.Trigger)

    if not lines[1] then
        return {}, NRSKNUI:ColorTextByTheme(L['This indicator matches nothing yet.'])
    end

    return lines, NRSKNUI:ColorTextByTheme(L['Shows while a matching aura is up:'])
end

-- What an indicator is: the aura it means and the colour it carries. Everything about how it is drawn lives per unit, in PlacementDefaults below.
local SpecDefaults = {
    Trigger = nil, -- filled in by :Create, since every indicator needs its own table
    sortMethod = 'ExpirationOnly',
    sortDirection = 'Normal',
    Color = { 0, 0.9, 0.5, 1 },
}

-- What a unit does with an indicator: where it draws it, how big it is, what font it uses and so on.
local PlacementDefaults = {
    Name = '',
    Keys = {},
    Alpha = 1,
    Style = AuraIndicators.Styles.Overlay,
    Attach = AuraIndicators.Attach.Health,
    Position = { AnchorFrom = 'CENTER', AnchorTo = 'CENTER', XOffset = 0, YOffset = 0 },
    Size = { Width = 24, Height = 24 },
    Texture = '',
    Solid = false,
    Font = {
        UseGlobalFont = true,
        FontFace = 'Expressway',
        FontOutline = 'OUTLINE',
        FontSize = 12,
    },
    StackFont = { FontSize = 10, Position = { AnchorFrom = 'BOTTOMRIGHT', XOffset = 0, YOffset = 2 } },
    DurationFont = { FontSize = 12, Position = { AnchorFrom = 'CENTER', XOffset = 0, YOffset = 0 } },
    Icon = {
        showCooldown = true,
        showStacks = true,
        showDuration = true,
        showBorder = false,
        drawSwipe = true,
        drawEdge = false,
        reverseSwipe = true,
    },
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
---@return table placement
function AuraIndicators:AddPlacement(uDB)
    local placement = CopyTable(PlacementDefaults)
    placement.Order = self:TopOrder(uDB.AuraIndicators)

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

---Build a look table from the indicator's spec and the placement's own settings.
---@param spec table an entry from db.profile.AuraIndicators
---@param placement table that indicator's entry in uDB.AuraIndicators
---@param fontDB table? the host's shared font block, for placements that opted into it
---@return table look
local function ResolveLook(spec, placement, fontDB)
    local color = spec.Color
    local alpha = (color[4] or 1) * (placement.Alpha or 1)

    return {
        Color = { color[1], color[2], color[3], alpha },
        Alpha = placement.Alpha or 1,
        Texture = placement.Texture,
        Solid = placement.Solid,
        Icon = placement.Icon,
        Position = placement.Position,
        Font = placement.Font,
        StackFont = placement.StackFont,
        DurationFont = placement.DurationFont,
        FontSource = (placement.Font.UseGlobalFont and fontDB) or placement.Font,
        FontOutline = (placement.Font.UseGlobalFont and fontDB and fontDB.FontOutline) or placement.Font.FontOutline,
    }
end

---Color a plain texture, used by every style that owns its own artwork.
---@param texture Texture
---@param look table
local function ApplyTextureLook(texture, look)
    local color = look.Color
    local path = look.Texture ~= '' and look.Texture or nil

    if path then
        texture:SetTexture(NRSKNUI:ResolveMediaPath('statusbar', path))
        texture:SetVertexColor(color[1], color[2], color[3], color[4])
    else
        texture:SetColorTexture(color[1], color[2], color[3], color[4])
    end
    -- Additive never occludes, so the bar reads through the tint at any alpha. Solid blends instead,
    -- which is what makes a full-alpha tint actually opaque.
    texture:SetBlendMode(look.Solid and 'BLEND' or 'ADD')
end

---Overlay and Square are the same build, they differ only in whether the proxy covers its target.
---Neither binds to a native setter, so both stay entirely ours to restyle at any time.
---@param slot table
---@param look table
---@return table regions
local function BuildTexture(slot, look)
    local texture = slot:CreateTexture(nil, 'ARTWORK')
    texture:SetAllPoints(slot)
    ApplyTextureLook(texture, look)

    return { texture = texture }
end

---Icon is a whole aura button in one slot, so the existing skin does all of it. Sizing comes from the
---proxy, which the slot is already anchored to, so the skin's own SetSize is a no-op here.
---@param slot table
---@param look table
---@param container table
---@return table regions
local function BuildIcon(slot, look, container)
    local icon = look.Icon

    NRSKNUI:SkinAuraButton(container, {
        disableMouse = true,
        disableCooldown = not icon.showCooldown,
        drawSwipe = icon.drawSwipe,
        drawEdge = icon.drawEdge,
        reverseSwipe = icon.reverseSwipe,
        showApplicationCount = icon.showStacks,
        showDurationText = icon.showDuration,
        showBuffBorder = icon.showBorder or nil,
        showDebuffBorder = icon.showBorder or nil,
        fontDB = look.FontSource,
        stackFont = look.StackFont,
        durationFont = look.DurationFont,
    }, slot)

    return {} -- the skin owns every region, and none can be touched again after build
end

---Restyle a Duration indicator's text.
---@param regions table
---@param look table
local function ApplyDuration(regions, look)
    local text, pos = regions.text, look.Position

    text:SetFontStyle(look.FontSource, look.Font.FontSize, look.FontOutline, nil, true)
    text:SetFontJustify(look, regions.parent, pos.XOffset, pos.YOffset, true)

    local color = look.Color
    text:SetTextColor(color[1], color[2], color[3], color[4])
end

---A bare duration readout, no icon.
---@param slot table
---@param look table
---@return table regions
local function BuildDuration(slot, look)
    local text = slot:CreateFontString(nil, 'OVERLAY')

    text:SetFontStyle(look.FontSource, look.Font.FontSize, look.FontOutline, nil, true)
    slot:SetDurationText(text, { textFormatter = NRSKNUI:GetAuraDurationFormatter(false, nil), })

    local regions = { text = text, parent = slot }
    ApplyDuration(regions, look)
    return regions
end

local Styles = AuraIndicators.Styles

local StyleBuilders = {
    [Styles.Overlay] = BuildTexture,
    [Styles.Square] = BuildTexture,
    [Styles.Icon] = BuildIcon,
    [Styles.Duration] = BuildDuration,
}

---Draw an indicator on a preview dummy, through the same builder its real slot runs. The dummy stands
---in for the slot and owner for the container, so nothing here reaches a restricted object.
---@param dummy table
---@param owner table
---@param placement table
---@param spec table
---@param level number
---@param fontDB table?
---@return boolean drawn
function NRSKNUI:BuildAuraIndicatorPreview(dummy, owner, placement, spec, level, fontDB)
    local build = AuraIndicators.Previewable[placement.Style] and StyleBuilders[placement.Style]
    if not build then return false end

    build(dummy, ResolveLook(spec, placement, fontDB), owner, level)
    return true
end

---Set up a unit's indicator slot for a spec or update it if it already exists.
---@param container table
---@param handle table?
---@param placement table
---@param proxy Frame
---@param level number
---@param fontDB table?
---@return table? handle
function NRSKNUI:SyncAuraIndicator(container, handle, placement, proxy, level, fontDB)
    local build = StyleBuilders[placement.Style]
    if not build then return nil end

    handle = handle or {
        proxy = proxy,
        slots = {},
        slotIndex = {},
        regions = {},
        builtKeys = {},
    }
    handle.container = container

    for _, key in ipairs(placement.Keys) do
        local spec = not handle.builtKeys[key] and AuraIndicators:GetSpec(key)

        if spec then
            handle.builtKeys[key] = true
            local look = ResolveLook(spec, placement, fontDB)

            for _, branch in ipairs(AuraIndicators:GetBranches(spec)) do
                local index = #handle.slots + 1

                local slot, _, slotIndex = container:AddSlot(branch.filterString, {
                    candidateFilters = branch.candidateFilters,
                    sortMethod = AuraContainerSortMethod[spec.sortMethod],
                    sortDirection = AuraContainerSortDirection[spec.sortDirection],
                    initializeFrame = function(button)
                        button:EnableMouse(false) -- an indicator must never eat the unit frame's clicks
                        button:SetFrameLevel(level)
                        button:SetAllPoints(proxy)
                        handle.regions[index] = build(button, look, container, level)
                    end,
                })

                handle.slots[index], handle.slotIndex[index] = slot, slotIndex

                local regions = handle.regions[index]
                regions.key, regions.spec = key, spec
            end
        end
    end

    return handle
end

---Hide every slot an indicator owns.
---@param handle table
---@param shown boolean
function NRSKNUI:SetAuraIndicatorShown(handle, shown)
    for index in ipairs(handle.slots) do
        handle.container:SetSlotShown(handle.slotIndex[index], shown)
    end
end

---Settle which of an indicator's slots are showing. Looks are not re-applied: the regions belong to
---the slot's aura button, which the client closes to us once aura values are secret.
---@param handle table
---@param placement table
function NRSKNUI:ApplyAuraIndicator(handle, placement)
    local assigned = {}
    for _, key in ipairs(placement.Keys) do
        assigned[key] = true
    end

    for index, regions in ipairs(handle.regions) do
        -- The spec behind an assigned key can have been deleted since.
        local spec = assigned[regions.key] and AuraIndicators:GetSpec(regions.key)
        handle.container:SetSlotShown(handle.slotIndex[index], spec ~= nil)
    end
end

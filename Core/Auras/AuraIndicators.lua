---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AuraIndicators
local AuraIndicators = {}
NRSKNUI.AuraIndicators = AuraIndicators
local L = NRSKNUI.Libs.AL

local tsort, tremove = table.sort, table.remove
local ipairs, pairs = ipairs, pairs
local format = string.format
local CopyTable = CopyTable
local tonumber = tonumber
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
local AF = AuraUtil.AuraFilters

local GROUP_PREFIX = 'group:'
-- Indicators that ship with the addon, seeded into the defaults. Keyed the same way as a user's, so
-- nothing placing or drawing one cares which it got.
local BUILTIN_PREFIX = 'builtin:'

local function GetStore()
    return NRSKNUI.db.global.AuraIndicators
end

---Groups are only a way to organise the indicator list: a group holds a name, and an indicator points
---at one through its `group` field. Nothing about what an indicator does depends on being in one.
local function GetGroupStore()
    return NRSKNUI.db.global.AuraIndicatorGroups
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

---Move an indicator into a group, or out of one when groupId is nil. Emptied groups are dropped, since
---a header with nothing under it is only clutter.
---@param key string
---@param groupId string?
function AuraIndicators:SetGroup(key, groupId)
    local spec = self:GetSpec(key)
    if not spec then return end

    spec.group = groupId
    self:PruneGroups()
end

---Forget any group nothing points at.
function AuraIndicators:PruneGroups()
    local store, groups = GetStore(), GetGroupStore()
    if not (store and groups) then return end

    local used = {}
    for _, spec in pairs(store) do
        if type(spec) == 'table' and spec.group then used[spec.group] = true end
    end

    for id in pairs(groups) do
        if not used[id] then groups[id] = nil end
    end
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
    Layer = 1,
    Attach = AuraIndicators.Attach.Health,
    Position = { AnchorFrom = 'CENTER', AnchorTo = 'CENTER', XOffset = 0, YOffset = 0 },
    Size = { Width = 24, Height = 24 },
    Texture = '',
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
---@return table? spec
function AuraIndicators:Create(key, name)
    local store = GetStore()
    -- A user's key is whatever they named it, so the shipped prefix is off limits: an indicator
    -- wearing it could never be deleted again.
    if not store or store[key] or self:IsBuiltin(key) then return nil end

    local spec = CopyTable(SpecDefaults)
    spec.name = name
    -- Its own table, not a shared default: an indicator's trigger is edited in place.
    spec.Trigger = NRSKNUI.AuraTriggers:New({ Type = NRSKNUI.AuraTriggers.Types.SpellIDs })
    -- The unit frame drawing the indicator decides the unit, so the trigger never carries one.
    spec.Trigger.Unit = nil

    store[key] = spec
    self:Invalidate(key)

    return spec
end

---Give a unit another spot to draw indicators in, appended to its list.
---@param uDB table
---@return table placement
function AuraIndicators:AddPlacement(uDB)
    local placement = CopyTable(PlacementDefaults)

    tinsert(uDB.AuraIndicators, placement)
    return placement
end

---@param placement table
---@return table[] specs
function AuraIndicators:GetPlacementSpecs(placement)
    local specs = {}

    for _, key in ipairs(placement.Keys) do
        local spec = self:GetSpec(key)
        if spec then
            tinsert(specs, spec)
        end
    end

    return specs
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
    self:PruneGroups()
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
---@param spec table an entry from db.global.AuraIndicators
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
    texture:SetBlendMode('ADD')
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

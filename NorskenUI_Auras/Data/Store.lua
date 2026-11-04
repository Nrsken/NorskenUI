---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

--[[
The saved displays.
Creating, finding, moving, copying and deleting them, the tree they form and the templates new ones start from.
]]

local tsort, tconcat = table.sort, table.concat
local ipairs, pairs = ipairs, pairs
local format = string.format
local CopyTable = CopyTable
local random = math.random
local type = type
local wipe = wipe

local PowerType = Enum and Enum.PowerType

local UID_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789()'
local ID_PREFIX = 'cdm:'
local SCHEMA_VERSION = 12
local RESOURCE_WIDTH, RESOURCE_HEIGHT = 240, 12

-- Displays built from per-trigger layers: they have triggers, conditions and a style.
CDM.LAYERED_TYPES = {
    icon = true,
    bar = true,
    text = true,
}

-- What a Display paste leaves alone: identity, tree placement and the other parts.
local NOT_DISPLAY = {
    type = true,
    name = true,
    parent = true,
    order = true,
    Enabled = true,
    builtin = true,
    uid = true,
    preferToUpdate = true,
    Description = true,
    Triggers = true,
    Activation = true,
    DynamicTrigger = true,
    Conditions = true,
    Load = true,
    Trigger = true, -- an aura group's one trigger
}

-- The keys each part of a Paste Settings copies.
local PART_KEYS = {
    trigger = { 'Triggers', 'Activation', 'DynamicTrigger', 'Trigger' },
    conditions = { 'Conditions' },
    load = { 'Load' },
}

-- Ids --

local function Store()
    return CDM.db.Displays
end

---@return string id
local function NextId()
    local store = Store()
    local index = 1
    while store[ID_PREFIX .. index] do
        index = index + 1
    end

    return ID_PREFIX .. index
end

---@return string id
function CDM:NextId()
    return NextId()
end

---@return number
function CDM:GetSchemaVersion()
    return SCHEMA_VERSION
end

---11 random characters that follow a display through exports, so a re-import can find it.
---@return string
function CDM:NewUid()
    local chars = {}
    for i = 1, 11 do
        local n = random(1, #UID_CHARS)
        chars[i] = UID_CHARS:sub(n, n)
    end

    return tconcat(chars)
end

---Every display gets a uid and a uid two displays share is replaced on one of them.
function CDM:EnsureUids()
    local seen = {}
    for _, display in pairs(Store()) do
        if type(display.uid) ~= 'string' or seen[display.uid] then
            display.uid = self:NewUid()
        end
        seen[display.uid] = true
    end
end

---@param uid string
---@return string? id
function CDM:GetByUid(uid)
    for id, display in pairs(Store()) do
        if display.uid == uid then
            return id
        end
    end
end

-- Lookups --

---@param id string?
---@return table? display
function CDM:Get(id)
    return id and Store()[id] or nil
end

---Any container, static or dynamic.
---@param id string?
---@return boolean
function CDM:IsGroup(id)
    local display = self:Get(id)
    return display ~= nil and (display.type == 'group' or display.type == 'dynamicgroup')
end

---A tracker of many auras at once, drawn by one native aura group: a leaf like an icon.
---@param id string?
---@return boolean
function CDM:IsAuraGroup(id)
    local display = self:Get(id)
    return display ~= nil and display.type == 'auragroup'
end

---@param id string?
---@return boolean
function CDM:IsDynamic(id)
    local display = self:Get(id)
    return display ~= nil and display.type == 'dynamicgroup'
end

---@param id string
---@return string
function CDM:GetName(id)
    local display = self:Get(id)
    return (display and display.name) or format(L['Display %s'], id)
end

-- Tree --

---@param a table
---@param b table
local function ByOrderThenName(a, b)
    if a.order and b.order and a.order ~= b.order then
        return a.order < b.order
    end
    if (a.order ~= nil) ~= (b.order ~= nil) then
        return a.order ~= nil
    end
    return a.text < b.text
end

---A group's direct children in display order.
---@param groupId string
---@return table[] children { key, text, order? }
function CDM:GetChildren(groupId)
    local children = {}
    for id, display in pairs(Store()) do
        if display.parent == groupId then
            children[#children + 1] = { key = id, text = display.name or id, order = display.order }
        end
    end

    tsort(children, ByOrderThenName)
    return children
end

---Every group's direct children in display order, from one pass over the store.
---@return table<string, table[]> children { key, text, order? } by group id
function CDM:GetChildrenIndex()
    local index = {}
    for id, display in pairs(Store()) do
        local parent = display.parent
        if parent then
            local list = index[parent]
            if not list then
                list = {}
                index[parent] = list
            end
            list[#list + 1] = { key = id, text = display.name or id, order = display.order }
        end
    end

    for _, list in pairs(index) do
        tsort(list, ByOrderThenName)
    end

    return index
end

---Every icon under a group at any depth, in display order.
---@param groupId string
---@param into string[]?
---@return string[]
function CDM:GetIcons(groupId, into)
    into = into or {}
    for _, child in ipairs(self:GetChildren(groupId)) do
        if self:IsGroup(child.key) then
            self:GetIcons(child.key, into)
        elseif not self:IsAuraGroup(child.key) then
            into[#into + 1] = child.key
        end
    end

    return into
end

---Every display under a group that draws something, icons and aura groups, in display order.
---@param groupId string
---@param into string[]?
---@return string[]
function CDM:GetLeaves(groupId, into)
    into = into or {}
    for _, child in ipairs(self:GetChildren(groupId)) do
        if self:IsGroup(child.key) then
            self:GetLeaves(child.key, into)
        else
            into[#into + 1] = child.key
        end
    end

    return into
end

---Parent first, up to the top level.
---@param id string
---@return string[]
function CDM:GetAncestors(id)
    local ancestors = {}
    local display = self:Get(id)
    while display and display.parent do
        ancestors[#ancestors + 1] = display.parent
        display = self:Get(display.parent)
    end

    return ancestors
end

---@param id string
---@return number
function CDM:GetDepth(id)
    return #self:GetAncestors(id)
end

---Top-level displays, by name.
---@return table[] roots { key, text }
function CDM:GetRoots()
    local roots = {}
    for id, display in pairs(Store()) do
        if not display.parent then
            roots[#roots + 1] = { key = id, text = display.name or id }
        end
    end

    tsort(roots, function(a, b)
        return a.text < b.text
    end)
    return roots
end

---A dynamic group holds icons, bars and texts only; a static group holds anything but itself or a group above it.
---@param parentId string
---@param childId string
---@return boolean
function CDM:CanContain(parentId, childId)
    local parent, child = self:Get(parentId), self:Get(childId)
    if not (parent and child) or parentId == childId or not self:IsGroup(parentId) then
        return false
    end

    if parent.type == 'dynamicgroup' then
        return CDM.LAYERED_TYPES[child.type] == true
    end

    for _, ancestor in ipairs(self:GetAncestors(parentId)) do
        if ancestor == childId then
            return false
        end
    end
    return true
end

-- Moving --

---@param ordered string[]
local function Renumber(ordered)
    local store = Store()
    for index, key in ipairs(ordered) do
        store[key].order = index
    end
end

---Move a display into a group or to the top level.
---@param id string
---@param parentId string?
---@param first boolean? lead the group instead of trailing it
function CDM:SetParent(id, parentId, first)
    local display = self:Get(id)
    if not display or display.parent == parentId then return end
    if parentId and not self:CanContain(parentId, id) then return end

    self:KeepPlace(id, parentId)
    display.order = nil
    display.parent = parentId
    if not parentId then return end

    local ordered = first and { id } or {}
    for _, child in ipairs(self:GetChildren(parentId)) do
        if child.key ~= id then
            ordered[#ordered + 1] = child.key
        end
    end
    if not first then
        ordered[#ordered + 1] = id
    end

    Renumber(ordered)
end

---Place a display before or after one inside a group, joining that group.
---@param id string
---@param targetId string
---@param position 'before'|'after'
function CDM:MoveNextTo(id, targetId, position)
    local display, target = self:Get(id), self:Get(targetId)
    if not (display and target and target.parent) or id == targetId then return end
    if not self:CanContain(target.parent, id) then return end

    local parentId = target.parent
    if display.parent ~= parentId then
        self:KeepPlace(id, parentId)
    end
    display.parent = parentId
    display.order = nil

    local ordered = {}
    for _, child in ipairs(self:GetChildren(parentId)) do
        if child.key ~= id then
            if child.key == targetId and position == 'before' then
                ordered[#ordered + 1] = id
            end
            ordered[#ordered + 1] = child.key
            if child.key == targetId and position == 'after' then
                ordered[#ordered + 1] = id
            end
        end
    end

    Renumber(ordered)
end

---Swap a display with its neighbour in its group.
---@param id string
---@param delta number -1 up, 1 down
function CDM:MoveInGroup(id, delta)
    local display = self:Get(id)
    if not (display and display.parent) then return end

    local ordered = {}
    for _, child in ipairs(self:GetChildren(display.parent)) do
        ordered[#ordered + 1] = child.key
    end

    for index, key in ipairs(ordered) do
        if key == id then
            local other = index + delta
            if ordered[other] then
                ordered[index], ordered[other] = ordered[other], ordered[index]
                Renumber(ordered)
            end
            return
        end
    end
end

---Take a display out of its group, into the group that holds that one.
---@param id string
function CDM:Ungroup(id)
    local display = self:Get(id)
    if not (display and display.parent) then return end

    local grandparent = self:Get(display.parent).parent
    if grandparent and not self:CanContain(grandparent, id) then
        grandparent = nil
    end
    self:SetParent(id, nil)
    if grandparent then
        self:SetParent(id, grandparent)
    end
end

-- Creating --

---A new display's identity and starting spot, the middle of the screen. The uid comes now rather than at the next
---login's EnsureUids, as the options key session state by it.
---@param display table
local function StartDisplay(display)
    display.uid = CDM:NewUid()
    display.anchorFrameType = 'UIPARENT'
    display.ParentFrame = 'UIParent'
    display.Position = CopyTable(CDM.POSITION_TEMPLATE)
end

---@param name string
---@param dynamic boolean
---@param parentId string?
---@return string? id
function CDM:CreateGroup(name, dynamic, parentId)
    if not name or name == '' then return nil end

    local id = NextId()
    local display = { type = dynamic and 'dynamicgroup' or 'group', name = name, Enabled = true }
    if dynamic then
        display.Layout = CopyTable(CDM.LAYOUT_TEMPLATE)
    end
    StartDisplay(display)
    Store()[id] = display

    if parentId then
        self:SetParent(id, parentId)
    end
    return id
end

---@param name string
---@param trigger table
---@param parentId string?
---@return string? id
function CDM:CreateIcon(name, trigger, parentId)
    if not name or name == '' or not trigger then return nil end

    local id = NextId()
    local display = {
        type = 'icon',
        name = name,
        Enabled = true,
        Triggers = { trigger },
        Conditions = {},
        Style = CopyTable(CDM.STYLE_TEMPLATE),
        SubRegions = CDM:DefaultIconSubRegions(),
        Load = NRSKNUI.LoadConditions:GetDefaults(),
    }
    StartDisplay(display)
    Store()[id] = display

    if parentId then
        self:SetParent(id, parentId)
    end
    return id
end

---@param name string
---@param trigger table
---@param parentId string?
---@return string? id
function CDM:CreateBar(name, trigger, parentId)
    if not name or name == '' or not trigger then return nil end

    local id = NextId()
    local display = {
        type = 'bar',
        name = name,
        Enabled = true,
        Triggers = { trigger },
        Conditions = {},
        Style = CopyTable(CDM.BAR_STYLE_TEMPLATE),
        SubRegions = CDM:DefaultBarSubRegions(),
        Load = NRSKNUI.LoadConditions:GetDefaults(),
    }
    StartDisplay(display)
    Store()[id] = display

    if parentId then
        self:SetParent(id, parentId)
    end
    return id
end

---One text, its frame sized to it; the text is the display's only sub element.
---@param name string
---@param trigger table
---@param parentId string?
---@return string? id
function CDM:CreateText(name, trigger, parentId)
    if not name or name == '' or not trigger then return nil end

    local id = NextId()
    local display = {
        type = 'text',
        name = name,
        Enabled = true,
        Triggers = { trigger },
        Conditions = {},
        Style = CopyTable(CDM.TEXT_STYLE_TEMPLATE),
        SubRegions = { CDM:NewSubRegion('text', { FontSize = 20, Justify = 'LEFT' }) },
        Load = NRSKNUI.LoadConditions:GetDefaults(),
    }
    StartDisplay(display)
    Store()[id] = display

    if parentId then
        self:SetParent(id, parentId)
    end
    return id
end

---The class resource as one split bar: runes and Essence as Recharging Segments, the rest Static; nil for a class without one.
---@param parentId string?
---@return string? id
function CDM:CreateResourceBar(parentId)
    local powerType = CDM.CLASS_RESOURCES[NRSKNUI.MyClass]
    if not powerType then return nil end

    local recharges = powerType == PowerType.Runes or powerType == PowerType.Essence

    local trigger = { Type = 'power', PowerType = powerType, Mode = recharges and 'progress' or 'static' }
    local id = self:CreateBar(CDM.POWER_NAMES[powerType], trigger, parentId)
    local bar = id and self:Get(id)
    if not bar then return nil end

    bar.Style.Width, bar.Style.Height = RESOURCE_WIDTH, RESOURCE_HEIGHT
    bar.Style.BarColorMode = 'power'
    bar.Style.IconShow = false
    bar.SubRegions = {
        self:NewSubRegion('border', { EachPip = true }),
        self:NewSubRegion('text', { Text = '%p', FontSize = 10, EachPip = true, Enabled = recharges }),
    }
    return id
end

---A tracker of many auras, starting from the shipped Defensives tracker's look.
---@param name string
---@param presetKey string? start from this aura preset instead of an empty trigger
---@param parentId string?
---@return string? id
function CDM:CreateAuraGroup(name, presetKey, parentId)
    if not name or name == '' then return nil end

    local display = self:NewBuiltinAuraGroup('builtin:defensives') --[[@as table]]
    display.name, display.builtin = name, nil
    display.Trigger = presetKey
        and NRSKNUI.AuraTriggers:ToAuraFilter({ Type = NRSKNUI.AuraTriggers.Types.Preset, Preset = presetKey, Unit = 'player' })
        or NRSKNUI.AuraTriggers:New()
    StartDisplay(display)

    local id = NextId()
    Store()[id] = display

    if parentId then
        self:SetParent(id, parentId)
    end
    return id
end

---Put a built-in aura group back to how it shipped, spells, layout and position included; it keeps its place in the tree.
---@param id string
function CDM:ResetBuiltin(id)
    local display = self:Get(id)
    local reset = display and display.builtin and self:NewBuiltinAuraGroup(display.builtin)
    if not reset then return end

    reset.parent, reset.order, reset.Load, reset.uid = display.parent, display.order, display.Load, display.uid
    wipe(display)
    for key, value in pairs(reset) do
        display[key] = value
    end
end

---A new profile's General Trackers group with the built-in aura groups inside.
function CDM:SeedBuiltins()
    local folderId = self:CreateGroup(CDM.BUILTIN_FOLDER.name, false) --[[@as string]]
    local folder = self:Get(folderId) --[[@as table]]
    folder.Icon, folder.Strata = CDM.BUILTIN_FOLDER.Icon, CDM.BUILTIN_FOLDER.Strata

    for order, builtin in ipairs(CDM.BUILTIN_AURA_GROUPS) do
        local display = self:NewBuiltinAuraGroup(builtin.key) --[[@as table]]
        display.parent, display.order = folderId, order -- SetParent would place it by a frame, which doesn't exist yet
        Store()[NextId()] = display
    end
end

-- Copying, renaming and deleting --

---@param id string
---@param parentId string?
---@return string newId
local function CopySubtree(id, parentId)
    local newId = NextId()
    local copy = CopyTable(Store()[id])
    copy.parent = parentId or copy.parent
    copy.uid = CDM:NewUid()
    copy.preferToUpdate = nil
    copy.builtin = nil -- a copy of a built-in is the user's own, at any depth
    Store()[newId] = copy

    for _, child in ipairs(CDM:GetChildren(id)) do
        CopySubtree(child.key, newId)
    end

    return newId
end

---The first free "<name> N", the name taken without a number it already ends in.
---@param name string
---@return string
local function CopyName(name)
    local base = name:match('^(.-) %d+$') or name
    local taken = {}
    for _, display in pairs(Store()) do
        if display.name then
            taken[display.name] = true
        end
    end

    local number = 1
    while taken[format('%s %d', base, number)] do
        number = number + 1
    end
    return format('%s %d', base, number)
end

---A copy beside the original; a group copies everything inside it.
---@param id string
---@return string? newId
function CDM:Duplicate(id)
    local source = self:Get(id)
    if not source then return nil end

    local newId = CopySubtree(id)
    local copy = self:Get(newId)
    copy.name = CopyName(self:GetName(id))
    copy.order = nil

    if source.parent then
        self:MoveNextTo(newId, id, 'after')
    end
    return newId
end

---@param id string
---@param name string
function CDM:Rename(id, name)
    local display = self:Get(id)
    if not display or not name or name == '' then return end

    display.name = name
end

---Remove a display; a group takes everything inside it unless keepChildren hands them to its parent.
---@param id string
---@param keepChildren boolean?
function CDM:Delete(id, keepChildren)
    local display = self:Get(id)
    if not display then return end

    for _, child in ipairs(self:GetChildren(id)) do
        if keepChildren then
            self:Ungroup(child.key)
        else
            self:Delete(child.key)
        end
    end

    self:Release(id)
    Store()[id] = nil
    self.preview[id] = nil -- ids are reused, so a new display would start pinned
    for _, other in pairs(Store()) do
        if other.MatchWidth == id then
            other.MatchWidth = nil
        end
    end
end

-- Pasting --

---@param source table
---@param target table
---@param part string
local function CopyPart(source, target, part)
    local all = part == 'all'
    if part == 'display' or part == 'group' or all then
        for key in pairs(target) do
            if not NOT_DISPLAY[key] and source[key] == nil then
                target[key] = nil
            end
        end
        for key, value in pairs(source) do
            if not NOT_DISPLAY[key] then
                target[key] = type(value) == 'table' and CopyTable(value) or value
            end
        end
    end

    for name, keys in pairs(PART_KEYS) do
        if part == name or all then
            for _, key in ipairs(keys) do
                local value = source[key]
                target[key] = type(value) == 'table' and CopyTable(value) or value
            end
        end
    end
end

---Icon settings go onto an icon or every icon in a group, bar and text settings onto their own type; group settings only onto the same kind of group.
---@param source table
---@param id string
---@return boolean
function CDM:CanPasteSettings(source, id)
    local target = self:Get(id)
    if not target then return false end

    if CDM.LAYERED_TYPES[source.type] then
        return target.type == source.type or self:IsGroup(id)
    end
    return source.type == target.type
end

---Paste a part of a copied display (`all`, `display`, `group`, `trigger`, `conditions`, `load`) onto another.
---@param source table a snapshot from the time it was copied
---@param id string
---@param part string
function CDM:PasteSettings(source, id, part)
    if not self:CanPasteSettings(source, id) then return end

    if CDM.LAYERED_TYPES[source.type] and self:IsGroup(id) then
        for _, iconId in ipairs(self:GetIcons(id)) do
            local target = self:Get(iconId)
            if target.type == source.type then
                CopyPart(source, target, part)
            end
        end
    else
        CopyPart(source, self:Get(id), part)
    end
end

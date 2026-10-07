---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

local ipairs, pairs = ipairs, pairs
local tsort = table.sort
local format = string.format
local setmetatable = setmetatable
local rawget = rawget
local type = type
local CopyTable = CopyTable

local ID_PREFIX = 'cdm:'
local SCHEMA_VERSION = 3

-- Every new icon starts from this; an icon owns its full style from then on.
CDM.STYLE_TEMPLATE = {
    Width = 40,
    Height = 40,
    KeepAspectRatio = false,
    Color = { 1, 1, 1, 1 },
    Desaturate = false,
    DesaturateOnCooldown = true,
    IconSource = 'auto',
    Tooltip = false,
    Alpha = 1,
    DrawSwipe = true,
    Reverse = false,
    DrawEdge = false,
    SwipeColor = { 0, 0, 0, 0.7 },
    ShowGCD = false,
    HideCountdown = true,
}

CDM.SUBREGION_TEMPLATES = {
    text = {
        type = 'text',
        Enabled = true,
        Text = '%p',
        UseGlobalFont = true,
        FontFace = 'Expressway',
        FontOutline = 'OUTLINE',
        FontShadow = { Enabled = false, Color = { 0, 0, 0, 1 }, OffsetX = 1, OffsetY = -1 },
        FontSize = 16,
        Color = { 1, 1, 1, 1 },
        Position = { AnchorFrom = 'CENTER', XOffset = 0, YOffset = 0 },
    },
    border = {
        type = 'border',
        Enabled = true,
        Style = 'Pixel',
        Color = { 0, 0, 0, 1 },
        Size = 1,
        Offset = 0,
    },
}

---A new sub element of a type, optionally changed by overrides.
---@param kind string
---@param overrides table?
---@return table
function CDM:NewSubRegion(kind, overrides)
    local element = CopyTable(CDM.SUBREGION_TEMPLATES[kind])
    for key, value in pairs(overrides or {}) do
        element[key] = type(value) == 'table' and CopyTable(value) or value
    end
    return element
end

---WeakAuras' icon defaults: time left in the middle, charges in the corner, a 1px black border.
---@return table[]
local function DefaultSubRegions()
    return {
        CDM:NewSubRegion('text'),
        CDM:NewSubRegion('text', { Text = '%s', FontSize = 13, Position = { AnchorFrom = 'BOTTOMRIGHT', XOffset = -1, YOffset = 2 } }),
        CDM:NewSubRegion('border'),
    }
end

local function Store()
    return NRSKNUI.db.profile.CDM.Displays
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
    return display ~= nil and display.type ~= 'icon'
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

---An icon's style; keys added after it was saved read from the template.
---@param display table
---@return table
function CDM:GetStyle(display)
    return setmetatable({}, {
        __index = function(_, key)
            local value = display.Style[key]
            if value == nil then return CDM.STYLE_TEMPLATE[key] end
            return value
        end,
    })
end

---@param a table
---@param b table
local function ByOrderThenName(a, b)
    if a.order and b.order and a.order ~= b.order then return a.order < b.order end
    if (a.order ~= nil) ~= (b.order ~= nil) then return a.order ~= nil end
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

---Every icon under a group at any depth, in display order.
---@param groupId string
---@param into string[]?
---@return string[]
function CDM:GetIcons(groupId, into)
    into = into or {}
    for _, child in ipairs(self:GetChildren(groupId)) do
        if self:IsGroup(child.key) then
            self:GetIcons(child.key, into)
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
    tsort(roots, function(a, b) return a.text < b.text end)
    return roots
end

---A dynamic group holds icons only; a static group holds anything but itself or a group above it.
---@param parentId string
---@param childId string
---@return boolean
function CDM:CanContain(parentId, childId)
    local parent, child = self:Get(parentId), self:Get(childId)
    if not (parent and child) or parentId == childId or parent.type == 'icon' then return false end
    if parent.type == 'dynamicgroup' then return child.type == 'icon' end

    for _, ancestor in ipairs(self:GetAncestors(parentId)) do
        if ancestor == childId then return false end
    end
    return true
end

---@param ordered string[]
local function Renumber(ordered)
    local store = Store()
    for index, key in ipairs(ordered) do store[key].order = index end
end

---Move a display into a group, or to the top level.
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
        if child.key ~= id then ordered[#ordered + 1] = child.key end
    end
    if not first then ordered[#ordered + 1] = id end
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
    if display.parent ~= parentId then self:KeepPlace(id, parentId) end
    display.parent = parentId
    display.order = nil

    local ordered = {}
    for _, child in ipairs(self:GetChildren(parentId)) do
        if child.key ~= id then
            if child.key == targetId and position == 'before' then ordered[#ordered + 1] = id end
            ordered[#ordered + 1] = child.key
            if child.key == targetId and position == 'after' then ordered[#ordered + 1] = id end
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
    for _, child in ipairs(self:GetChildren(display.parent)) do ordered[#ordered + 1] = child.key end

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
    if grandparent and not self:CanContain(grandparent, id) then grandparent = nil end
    self:SetParent(id, nil)
    if grandparent then self:SetParent(id, grandparent) end
end

---@param display table
local function PlaceAt(display)
    display.anchorFrameType = 'UIPARENT'
    display.ParentFrame = 'UIParent'
    display.Position = { AnchorFrom = 'CENTER', AnchorTo = 'CENTER', XOffset = 0, YOffset = 0 }
end

---@param name string
---@param dynamic boolean
---@param parentId string?
---@return string? id
function CDM:CreateGroup(name, dynamic, parentId)
    if not name or name == '' then return nil end

    local id = NextId()
    local display = { type = dynamic and 'dynamicgroup' or 'group', name = name, Enabled = true }
    if dynamic then display.Layout = { Grow = 'HORIZONTAL', Spacing = 2, UseLimit = false, Limit = 10 } end
    PlaceAt(display)
    Store()[id] = display

    if parentId then self:SetParent(id, parentId) end
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
        SubRegions = DefaultSubRegions(),
        Load = NRSKNUI.LoadConditions:GetDefaults(),
    }
    PlaceAt(display)
    Store()[id] = display

    if parentId then self:SetParent(id, parentId) end
    return id
end

---@param id string
---@param parentId string?
---@return string newId
local function CopySubtree(id, parentId)
    local newId = NextId()
    local copy = CopyTable(Store()[id])
    copy.parent = parentId or copy.parent
    Store()[newId] = copy

    for _, child in ipairs(CDM:GetChildren(id)) do CopySubtree(child.key, newId) end
    return newId
end

---A copy beside the original; a group copies everything inside it.
---@param id string
---@return string? newId
function CDM:Duplicate(id)
    local source = self:Get(id)
    if not source then return nil end

    local newId = CopySubtree(id)
    local copy = self:Get(newId)
    copy.name = format(L['%s (Copy)'], self:GetName(id))
    copy.order = nil
    if source.parent then self:MoveNextTo(newId, id, 'after') end
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
end

-- Migration --

---@param target table
---@param source table?
local function Overlay(target, source)
    if not source then return end
    for key, value in pairs(source) do
        target[key] = type(value) == 'table' and CopyTable(value) or value
    end
end

-- The icon style before schema 2, which held the two texts and the border itself.
local LEGACY_STYLE = {
    Size = 40,
    BorderColor = { 0, 0, 0, 1 },
    ShowCountdown = true,
    UseGlobalFont = true,
    FontFace = 'Expressway',
    FontOutline = 'OUTLINE',
    FontShadow = { Enabled = false, Color = { 0, 0, 0, 1 }, OffsetX = 1, OffsetY = -1 },
    CountdownFont = { FontSize = 16, Position = { AnchorFrom = 'CENTER', XOffset = 0, YOffset = 0 } },
    ChargeFont = { FontSize = 13, Position = { AnchorFrom = 'BOTTOMRIGHT', XOffset = -1, YOffset = 2 } },
}

---Schema 1: groups became dynamic groups, styles moved onto the icons, groups lost their own load.
---@param db table profile.CDM
local function MigrateToOne(db)
    for _, display in pairs(db.Displays) do
        if display.type == 'group' and display.Layout then display.type = 'dynamicgroup' end
    end

    for _, display in pairs(db.Displays) do
        if display.type == 'icon' then
            local parent = display.parent and db.Displays[display.parent]
            local style = CopyTable(LEGACY_STYLE)
            Overlay(style, db.Style)
            Overlay(style, parent and parent.Style)
            Overlay(style, display.Style)
            display.Style = style

            local parentLoad = parent and parent.Load
            if parentLoad and parentLoad.Enabled and not (display.Load and display.Load.Enabled) then
                display.Load = CopyTable(parentLoad)
            end
        end
    end

    for _, display in pairs(db.Displays) do
        if display.type ~= 'icon' then
            display.Style = nil
            display.Load = nil
        end
    end
    db.Style = nil
end

---@param style table schema 1 icon style
---@param fontKey string
---@param text string
---@param enabled boolean
---@return table
local function LegacyText(style, fontKey, text, enabled)
    local font = style[fontKey] or LEGACY_STYLE[fontKey]
    return CDM:NewSubRegion('text', {
        Enabled = enabled,
        Text = text,
        UseGlobalFont = style.UseGlobalFont,
        FontFace = style.FontFace,
        FontOutline = style.FontOutline,
        FontShadow = style.FontShadow,
        FontSize = font.FontSize,
        Position = font.Position,
    })
end

---Schema 2: the two texts and the border became sub elements, size split into width and height.
---@param db table profile.CDM
local function MigrateToTwo(db)
    for _, display in pairs(db.Displays) do
        if display.type == 'icon' then
            local old = setmetatable(display.Style or {}, { __index = LEGACY_STYLE })
            display.SubRegions = {
                LegacyText(old, 'CountdownFont', '%p', old.ShowCountdown ~= false),
                LegacyText(old, 'ChargeFont', '%s', true),
                CDM:NewSubRegion('border', { Color = old.BorderColor }),
            }

            local style = CopyTable(CDM.STYLE_TEMPLATE)
            for key in pairs(style) do
                if rawget(old, key) ~= nil then style[key] = old[key] end
            end
            style.Width, style.Height = old.Size, old.Size
            style.HideCountdown = true
            display.Style = style
        end
    end
end

---Schema 3: one trigger became an ordered list, the first active one shown.
---@param db table profile.CDM
local function MigrateToThree(db)
    for _, display in pairs(db.Displays) do
        if display.type == 'icon' then
            display.Triggers = { display.Trigger }
            display.Trigger = nil
        end
    end
end

---@param db table profile.CDM
function CDM:Migrate(db)
    local version = db.Version or 0
    if version >= SCHEMA_VERSION then return end

    if version < 1 then MigrateToOne(db) end
    if version < 2 then MigrateToTwo(db) end
    if version < 3 then MigrateToThree(db) end
    db.Version = SCHEMA_VERSION
end

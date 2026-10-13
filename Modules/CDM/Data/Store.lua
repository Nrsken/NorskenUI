---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

local ipairs, pairs = ipairs, pairs
local setmetatable = setmetatable
local format = string.format
local CopyTable = CopyTable
local tsort, tconcat = table.sort, table.concat
local random = math.random
local type = type
local wipe = wipe

local ID_PREFIX = 'cdm:'
local SCHEMA_VERSION = 12

-- The Auras page's built-in trackers and the preset each one's trigger starts from.
local BUILTIN_PRESETS = {
    ['builtin:advancedDebuffs'] = 'preset:advancedDebuffs',
    ['builtin:defensives'] = 'preset:defensives',
    ['builtin:generalBuffs'] = 'preset:generalBuffs',
    ['builtin:speed'] = 'preset:speed',
}

-- Every new icon starts from this; an icon owns its full style from then on.
CDM.STYLE_TEMPLATE = {
    Width = 40,
    Height = 40,
    KeepAspectRatio = false,
    Color = { 1, 1, 1, 1 },
    Desaturate = false,
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

-- Every new bar starts from this; the icon keys stay so a bar's icon reads the same as an icon's.
CDM.BAR_STYLE_TEMPLATE = CopyTable(CDM.STYLE_TEMPLATE)
for key, value in pairs({
    Width = 200,
    Height = 20,
    DrawSwipe = false,
    UseGlobalBar = true,
    StatusBarTexture = 'NorskenUI',
    BarColorMode = 'custom',
    BarColor = { 0.35, 0.55, 0.85, 1 },
    BackgroundColor = { 0, 0, 0, 0.8 },
    Orientation = 'HORIZONTAL',
    ReverseFill = false,
    Inverse = false,
    Smooth = true,
    Spark = true,
    UseGlobalSpark = true,
    SparkTexture = 'Solid',
    SparkScale = 1,
    SparkWidth = 2,
    SparkColor = { 1, 1, 1, 1 },
    IconShow = true,
    IconSide = 'LEFT',
    LatencyColor = { 1, 0.2, 0.2, 0.5 },
    PipSpacing = 1,
}) do
    CDM.BAR_STYLE_TEMPLATE[key] = value
end

-- A text has no icon; Width/Height are only its cell in a Grid dynamic group, everywhere else it fits its text.
CDM.TEXT_STYLE_TEMPLATE = CopyTable(CDM.STYLE_TEMPLATE)
CDM.TEXT_STYLE_TEMPLATE.Width = 100
CDM.TEXT_STYLE_TEMPLATE.Height = 20
CDM.TEXT_STYLE_TEMPLATE.DrawSwipe = false

local STYLE_TEMPLATES = { bar = CDM.BAR_STYLE_TEMPLATE, text = CDM.TEXT_STYLE_TEMPLATE }

-- Displays built from per-trigger layers: they have triggers, conditions and a style.
CDM.LAYERED_TYPES = { icon = true, bar = true, text = true }

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
        TimeFormat = 'global',
        PrecisionBelow = 3,
        Precision = 1,
        ReadyText = '',                -- what a time shows once it has run out, WeakAuras' empty by default
        TimeColor = { Enabled = false, Below = 3, Color = { 1, 0.25, 0.25, 1 } },
        NumberFormat = 'auto',         -- values (power, stats): auto, decimals, abbreviate, large, breakup
        Decimals = 1,
        ValueColor = { Enabled = false, Low = { 1, 0.25, 0.25, 1 }, High = { 0.25, 1, 0.25, 1 } },
        Rotation = 'NONE',
        Justify = 'AUTO',
        WidthMode = 'auto',
        FixedWidth = 64,
        WordWrap = true,
        -- AnchorFrom is the text's own point; AUTO puts it inside the icon at AnchorTo, as WeakAuras does for icons.
        Position = { AnchorFrom = 'AUTO', AnchorTo = 'CENTER', XOffset = 0, YOffset = 0 },
    },
    border = {
        type = 'border',
        Enabled = true,
        Color = { 0, 0, 0, 1 },
        Size = 1,
        Offset = 0,
    },
    -- WeakAuras' tick: Automatic draws power segments, channel ticks and empower stages.
    tick = {
        type = 'tick',
        Enabled = true,
        Color = { 0, 0, 0, 1 },
        Placement = 'auto',
        Placements = '50',
        Thickness = 1,
        AutoLength = true,
        Length = 10,
    },
    -- Hidden until a condition shows it, as in WeakAuras.
    glow = {
        type = 'glow',
        Enabled = false,
        Type = 'modern',
        ColorMode = 'default',
        Color = { 0.95, 0.95, 0.32, 1 },
        Lines = 8,
        Frequency = 0.25,
        Length = 10,
        Thickness = 2,
        Border = true,
        StartAnim = true,
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

local DEFAULT_GLOW = 2 -- the hidden glow in DefaultSubRegions, which the proc condition shows

---WeakAuras' icon defaults: a 1px black border, a hidden glow, time left in the middle, charges in the corner.
---@return table[]
local function DefaultSubRegions()
    return {
        CDM:NewSubRegion('border'),
        CDM:NewSubRegion('glow'),
        CDM:NewSubRegion('text'),
        CDM:NewSubRegion('text', { Text = '%s', FontSize = 13, Position = { AnchorFrom = 'AUTO', AnchorTo = 'BOTTOMRIGHT', XOffset = -1, YOffset = 2 } }),
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

---@return string id
function CDM:NextId()
    return NextId()
end

---@return number
function CDM:GetSchemaVersion()
    return SCHEMA_VERSION
end

local UID_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789()'

---WeakAuras' uid: 11 random characters that follow a display through exports, so a re-import can find it.
---@return string
function CDM:NewUid()
    local chars = {}
    for i = 1, 11 do
        local n = random(1, #UID_CHARS)
        chars[i] = UID_CHARS:sub(n, n)
    end
    return tconcat(chars)
end

---Every display gets a uid, and a uid two displays share is replaced on one of them.
function CDM:EnsureUids()
    local seen = {}
    for _, display in pairs(Store()) do
        if type(display.uid) ~= 'string' or seen[display.uid] then display.uid = self:NewUid() end
        seen[display.uid] = true
    end
end

---@param uid string
---@return string? id
function CDM:GetByUid(uid)
    for id, display in pairs(Store()) do
        if display.uid == uid then return id end
    end
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

---An icon's, bar's or text's style; keys added after it was saved read from its type's template.
---@param display table
---@return table
function CDM:GetStyle(display)
    local template = STYLE_TEMPLATES[display.type] or CDM.STYLE_TEMPLATE
    return setmetatable({}, {
        __index = function(_, key)
            local value = display.Style[key]
            if value == nil then return template[key] end
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
    tsort(roots, function(a, b) return a.text < b.text end)
    return roots
end

---A dynamic group holds icons, bars and texts only; a static group holds anything but itself or a group above it.
---@param parentId string
---@param childId string
---@return boolean
function CDM:CanContain(parentId, childId)
    local parent, child = self:Get(parentId), self:Get(childId)
    if not (parent and child) or parentId == childId or not self:IsGroup(parentId) then return false end
    if parent.type == 'dynamicgroup' then return CDM.LAYERED_TYPES[child.type] == true end

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
        Conditions = { CDM:DesaturateOnCooldownCondition(1), CDM:ProcGlowCondition(1, DEFAULT_GLOW) },
        Style = CopyTable(CDM.STYLE_TEMPLATE),
        SubRegions = DefaultSubRegions(),
        Load = NRSKNUI.LoadConditions:GetDefaults(),
    }
    PlaceAt(display)
    Store()[id] = display

    if parentId then self:SetParent(id, parentId) end
    return id
end

---WeakAuras' bar defaults: a 1px border, a hidden glow, the name on the left and the time or value on the right.
---@return table[]
local function DefaultBarSubRegions()
    return {
        CDM:NewSubRegion('border'),
        CDM:NewSubRegion('tick'),
        CDM:NewSubRegion('text', { Text = '%n', FontSize = 12, Position = { AnchorFrom = 'AUTO', AnchorTo = 'LEFT', XOffset = 4, YOffset = 0 } }),
        CDM:NewSubRegion('text', { Text = '%p', FontSize = 12, Position = { AnchorFrom = 'AUTO', AnchorTo = 'RIGHT', XOffset = -4, YOffset = 0 } }),
    }
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
        Conditions = trigger.Type == 'cast' and CDM:CastBarConditions(1) or {},
        Style = CopyTable(CDM.BAR_STYLE_TEMPLATE),
        SubRegions = DefaultBarSubRegions(),
        Load = NRSKNUI.LoadConditions:GetDefaults(),
    }
    PlaceAt(display)
    Store()[id] = display

    if parentId then self:SetParent(id, parentId) end
    return id
end

---WeakAuras' text region: one text, its frame sized to it. The text is the display's only sub element.
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
    PlaceAt(display)
    Store()[id] = display

    if parentId then self:SetParent(id, parentId) end
    return id
end

local PowerType = Enum.PowerType
-- The resource a class counts in points, as EllesmereUI's resource bars pick its secondary.
local CLASS_RESOURCES = {
    DEATHKNIGHT = PowerType.Runes,
    PALADIN = PowerType.HolyPower,
    ROGUE = PowerType.ComboPoints,
    DRUID = PowerType.ComboPoints,
    MONK = PowerType.Chi,
    WARLOCK = PowerType.SoulShards,
    MAGE = PowerType.ArcaneCharges,
    EVOKER = PowerType.Essence,
}
CDM.CLASS_RESOURCES = CLASS_RESOURCES
local RESOURCE_WIDTH, RESOURCE_HEIGHT = 240, 12

---The class resource as one split bar, EllesmereUI's look: runes and Essence in Progress with a timer, other
---resources Static, and a grey recharge for all. Nil for a class without one.
---@param parentId string?
---@return string? id
function CDM:CreateResourceBar(parentId)
    local powerType = CLASS_RESOURCES[NRSKNUI.MyClass]
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
    -- Also for Static resources, so switching to Recharging Segments with a Progress Source already reads as unearned.
    bar.Conditions = {
        { check = { trigger = 1, variable = 'recharging', value = true }, changes = { { property = 'barColor', value = { 0.5, 0.5, 0.5, 1 } } } },
    }
    return id
end

---A tracker of many auras, starting from the shipped Defensives tracker's look, as the Auras page did.
---@param name string
---@param presetKey string? start from this aura preset instead of an empty trigger
---@param parentId string?
---@return string? id
function CDM:CreateAuraGroup(name, presetKey, parentId)
    if not name or name == '' then return nil end

    local template = NRSKNUI:GetDefaultDB().profile.AuraDisplays['builtin:defensives']
    local display = template and CopyTable(template) or {}
    display.type = 'auragroup'
    display.name = name
    display.Enabled = true
    display.group, display.order = nil, nil
    display.Trigger = presetKey
        and NRSKNUI.AuraTriggers:ToAuraFilter({ Type = NRSKNUI.AuraTriggers.Types.Preset, Preset = presetKey, Unit = 'player' })
        or NRSKNUI.AuraTriggers:New()
    display.Load = NRSKNUI.LoadConditions:GetDefaults()
    PlaceAt(display)

    local id = NextId()
    Store()[id] = display
    if parentId then self:SetParent(id, parentId) end
    return id
end

---An Auras page tracker's settings as an aura group under `parentId`.
---@param tracker table
---@param parentId string?
---@return table display
local function FromTracker(tracker, parentId)
    local display = CopyTable(tracker)
    display.type = 'auragroup'
    display.parent = parentId
    display.group = nil
    display.Load = display.Load or NRSKNUI.LoadConditions:GetDefaults()
    if parentId and (display.anchorFrameType or 'UIPARENT') == 'UIPARENT' then
        -- Inside a static group a screen anchor means the group's frame; a picked UIParent keeps it where it was.
        display.anchorFrameType, display.ParentFrame = 'SELECTFRAME', 'UIParent'
    end
    return display
end

---Put a built-in aura group back to how it shipped, spells, layout and position included; it keeps its place in the tree.
---@param id string
function CDM:ResetBuiltin(id)
    local display = self:Get(id)
    local shipped = display and display.builtin and NRSKNUI:GetDefaultDB().profile.AuraDisplays[display.builtin]
    if not shipped then return end

    local reset = FromTracker(shipped, display.parent)
    reset.builtin, reset.order, reset.Load = display.builtin, display.order, display.Load
    reset.Trigger = NRSKNUI.AuraTriggers:ToAuraFilter({
        Type = NRSKNUI.AuraTriggers.Types.Preset, Preset = BUILTIN_PRESETS[display.builtin], Unit = 'player',
    })
    wipe(display)
    for key, value in pairs(reset) do display[key] = value end
end

---@param id string
---@param parentId string?
---@return string newId
local function CopySubtree(id, parentId)
    local newId = NextId()
    local copy = CopyTable(Store()[id])
    copy.parent = parentId or copy.parent
    copy.uid = CDM:NewUid()
    copy.preferToUpdate = nil
    Store()[newId] = copy

    for _, child in ipairs(CDM:GetChildren(id)) do CopySubtree(child.key, newId) end
    return newId
end

---WeakAuras' naming: the first free "<name> N", the name taken without a number it already ends in.
---@param name string
---@return string
local function CopyName(name)
    local base = name:match('^(.-) %d+$') or name
    local taken = {}
    for _, display in pairs(Store()) do
        if display.name then taken[display.name] = true end
    end
    local number = 1
    while taken[format('%s %d', base, number)] do number = number + 1 end
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
    copy.builtin = nil -- a copy of a built-in is the user's own
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
    for _, other in pairs(Store()) do
        if other.MatchWidth == id then other.MatchWidth = nil end
    end
end

-- Copy settings --

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

local PART_KEYS = {
    trigger = { 'Triggers', 'Activation', 'DynamicTrigger', 'Trigger' },
    conditions = { 'Conditions' },
    load = { 'Load' },
}

---@param source table
---@param target table
---@param part string
local function CopyPart(source, target, part)
    local all = part == 'all'
    if part == 'display' or part == 'group' or all then
        for key in pairs(target) do
            if not NOT_DISPLAY[key] and source[key] == nil then target[key] = nil end
        end
        for key, value in pairs(source) do
            if not NOT_DISPLAY[key] then target[key] = type(value) == 'table' and CopyTable(value) or value end
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
    if CDM.LAYERED_TYPES[source.type] then return target.type == source.type or self:IsGroup(id) end
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
            if target.type == source.type then CopyPart(source, target, part) end
        end
    else
        CopyPart(source, self:Get(id), part)
    end
end

---Desaturate while on cooldown, a condition every new icon starts with.
---@param triggerIndex number
---@return table
function CDM:DesaturateOnCooldownCondition(triggerIndex)
    return {
        check = { trigger = triggerIndex, variable = 'onCooldown', value = true },
        changes = { { property = 'desaturate', value = true } },
    }
end

---@param triggerIndex number
---@param variable string
---@param color number[]
---@return table
local function CastColorCheck(triggerIndex, variable, color)
    return {
        check = { trigger = triggerIndex, variable = variable, value = true },
        changes = { { property = 'barColor', value = color } },
    }
end

---A new cast bar's state colours: channels, a finished cast, an interrupted or failed one.
---@param triggerIndex number
---@return table[]
function CDM:CastBarConditions(triggerIndex)
    local failed = CastColorCheck(triggerIndex, 'interrupted', { 0.85, 0.25, 0.25, 1 })
    failed.check = {
        variable = 'OR',
        checks = {
            { trigger = triggerIndex, variable = 'interrupted', value = true },
            { trigger = triggerIndex, variable = 'failed',      value = true },
        },
    }
    return {
        CastColorCheck(triggerIndex, 'channeling', { 0.35, 0.75, 0.45, 1 }),
        CastColorCheck(triggerIndex, 'succeeded', { 0.3, 0.8, 0.3, 1 }),
        failed,
    }
end

---Blizzard's proc glow while the spell is lit up, on by default.
---@param triggerIndex number
---@return table
---@param glowIndex number the glow sub element it shows
function CDM:ProcGlowCondition(triggerIndex, glowIndex)
    return {
        check = { trigger = triggerIndex, variable = 'proc', value = true },
        changes = { { property = 'sub.' .. glowIndex .. '.visible', value = true } },
    }
end

-- What Migrations.lua builds displays with.
CDM.BUILTIN_PRESETS = BUILTIN_PRESETS
CDM.PlaceAt = PlaceAt
CDM.FromTracker = FromTracker

---@class NRSKNUI
local NRSKNUI = select(2, ...)

local CreateFrame = CreateFrame
local CreateObjectPool = CreateObjectPool
local Mixin = Mixin
local ipairs, type = ipairs, type
local tinsert, tremove, tsort = table.insert, table.remove, table.sort
local max, min, floor = math.max, math.min, math.floor
local wipe = wipe
local select = select
local tostring = tostring
local error = error

NRSKNUI.GrowTypes = {
    { key = "DOWN",       text = "Down" },
    { key = "UP",         text = "Up" },
    { key = "RIGHT",      text = "Right" },
    { key = "LEFT",       text = "Left" },
    { key = "HORIZONTAL", text = "Horizontal (centered)" },
    { key = "VERTICAL",   text = "Vertical (centered)" },
    { key = "GRID",       text = "Grid" },
}

---@class NRSKNUI.DynamicGroup
local GroupMixin = {}

---@type table<string, NRSKNUI.DynamicGroupGrower>
local growers = {}

local GROW_POINTS = {
    DOWN = { CENTER = 'TOP', LEFT = 'TOPLEFT', RIGHT = 'TOPRIGHT', },
    UP = { CENTER = 'BOTTOM', LEFT = 'BOTTOMLEFT', RIGHT = 'BOTTOMRIGHT' },
    RIGHT = { CENTER = 'LEFT', TOP = 'TOPLEFT', BOTTOM = 'BOTTOMLEFT' },
    LEFT = { CENTER = 'RIGHT', TOP = 'TOPRIGHT', BOTTOM = 'BOTTOMRIGHT' },
    VERTICAL = { CENTER = 'CENTER', LEFT = 'LEFT', RIGHT = 'RIGHT' },
    HORIZONTAL = { CENTER = 'CENTER', TOP = 'TOP', BOTTOM = 'BOTTOM' },
}

local LINEAR_DIRS = {
    RIGHT = { horizontal = true, sign = 1, },
    LEFT = { horizontal = true, sign = -1, },
    UP = { horizontal = false, sign = 1, },
    DOWN = { horizontal = false, sign = -1, },
}

---Provides default values for optional config fields.
---@param value number|nil
---@param fallback number
---@return number
local function Default(value, fallback)
    if value == nil then
        return fallback
    end
    return value
end

-- Growers --

---Resolve the anchor point for a grow type and config.
---@param grow string
---@return fun(config: NRSKNUI.DynamicGroupConfig): string
local function ResolveAlignPoint(grow)
    return function(config)
        local points = GROW_POINTS[grow]
        return points[config.Align] or points.CENTER
    end
end

---Returns a closure that computes positions for a linear grow direction.
---@param dir { horizontal: boolean, sign: number }
---@return fun(config: NRSKNUI.DynamicGroupConfig): fun(positions: table, active: table, numVisible: number): (number, number)
local function LinearFactory(dir)
    return function(config)
        local spacing = Default(config.Spacing, 1)
        return function(positions, active, numVisible)
            local main, cross = 0, 0
            for i = 1, numVisible do
                local rec = active[i]
                local mainDim = dir.horizontal and rec.width or rec.height
                local crossDim = dir.horizontal and rec.height or rec.width
                if dir.horizontal then
                    positions[rec] = { main * dir.sign, 0 }
                else
                    positions[rec] = { 0, main * dir.sign }
                end
                main = main + mainDim + spacing
                if crossDim > cross then cross = crossDim end
            end
            local total = numVisible > 0 and (main - spacing) or 0
            if dir.horizontal then return total, cross end
            return cross, total
        end
    end
end

---Returns a closure that computes positions for a centered grow direction.
---@param horizontal boolean
---@return fun(config: NRSKNUI.DynamicGroupConfig): fun(positions: table, active: table, numVisible: number): (number, number)
local function CenteredFactory(horizontal)
    return function(config)
        local spacing = Default(config.Spacing, 1)
        return function(positions, active, numVisible)
            local total, cross = 0, 0
            for i = 1, numVisible do
                local rec = active[i]
                total = total + (horizontal and rec.width or rec.height)
                local crossDim = horizontal and rec.height or rec.width
                if crossDim > cross then cross = crossDim end
            end
            if numVisible > 0 then total = total + (numVisible - 1) * spacing end

            local cursor = total / 2
            for i = 1, numVisible do
                local rec = active[i]
                if horizontal then
                    positions[rec] = { rec.width / 2 - cursor, 0 }
                    cursor = cursor - rec.width - spacing
                else
                    positions[rec] = { 0, cursor - rec.height / 2 }
                    cursor = cursor - rec.height - spacing
                end
            end
            if horizontal then return total, cross end
            return cross, total
        end
    end
end

---Parse a grid type string into its row/column orientation, axis signs and anchor point.
---@param gridType string|nil
---@return boolean rowFirst, number xSign, number ySign, string point
local function ParseGridType(gridType)
    gridType = type(gridType) == 'string' and gridType:upper() or 'RD'
    local c1, c2 = gridType:sub(1, 1), gridType:sub(2, 2)
    local horiz = (c1 == 'R' or c1 == 'L') and c1 or ((c2 == 'R' or c2 == 'L') and c2)
    local vert = (c1 == 'U' or c1 == 'D') and c1 or ((c2 == 'U' or c2 == 'D') and c2)
    if not horiz or not vert then
        c1, horiz, vert = 'R', 'R', 'D'
    end
    local rowFirst = c1 == 'R' or c1 == 'L'
    local xSign = horiz == 'R' and 1 or -1
    local ySign = vert == 'U' and 1 or -1
    local point = (vert == 'D' and 'TOP' or 'BOTTOM') .. (horiz == 'R' and 'LEFT' or 'RIGHT')
    return rowFirst, xSign, ySign, point
end

---Returns a closure that computes positions for a grid layout.
---@param config NRSKNUI.DynamicGroupConfig
---@return fun(positions: table, active: table, numVisible: number): (number, number)
local function GridFactory(config)
    local spacing = Default(config.Spacing, 1)
    local rowSpacing = Default(config.RowSpacing, spacing)
    local gridWidth = max(1, floor(Default(config.GridWidth, 5)))
    local rowFirst, xSign, ySign = ParseGridType(config.GridType)

    return function(positions, active, numVisible)
        local primary, secondary = 0, 0
        local runMax, count = 0, 0
        local maxPrimary = 0
        for i = 1, numVisible do
            local rec = active[i]
            local primaryDim = rowFirst and rec.width or rec.height
            local secondaryDim = rowFirst and rec.height or rec.width
            if rowFirst then
                positions[rec] = { primary * xSign, secondary * ySign }
            else
                positions[rec] = { secondary * xSign, primary * ySign }
            end
            if primary + primaryDim > maxPrimary then maxPrimary = primary + primaryDim end
            if secondaryDim > runMax then runMax = secondaryDim end
            count = count + 1
            if count >= gridWidth and i < numVisible then
                count, primary = 0, 0
                secondary = secondary + runMax + rowSpacing
                runMax = 0
            else
                primary = primary + primaryDim + spacing
            end
        end
        local totalSecondary = secondary + runMax
        if rowFirst then return maxPrimary, totalSecondary end
        return totalSecondary, maxPrimary
    end
end

growers.RIGHT = {
    point = ResolveAlignPoint('RIGHT'),
    factory = LinearFactory(LINEAR_DIRS.RIGHT),
}
growers.LEFT = {
    point = ResolveAlignPoint('LEFT'),
    factory = LinearFactory(LINEAR_DIRS.LEFT),
}
growers.UP = {
    point = ResolveAlignPoint('UP'),
    factory = LinearFactory(LINEAR_DIRS.UP),
}
growers.DOWN = {
    point = ResolveAlignPoint('DOWN'),
    factory = LinearFactory(LINEAR_DIRS.DOWN),
}
growers.HORIZONTAL = {
    point = ResolveAlignPoint('HORIZONTAL'),
    factory = CenteredFactory(true),
}
growers.VERTICAL = {
    point = ResolveAlignPoint('VERTICAL'),
    factory = CenteredFactory(false),
}
growers.GRID = {
    point = function(config)
        local point = select(4, ParseGridType(config.GridType))
        return point
    end,
    factory = GridFactory,
}

---Register a custom grow type entry.
---@param growType string
---@param entry NRSKNUI.DynamicGroupGrower
function NRSKNUI:RegisterDynamicGroupGrower(growType, entry)
    growers[growType] = entry
end

-- Sorting --

---Sort by order, then attach index.
---@param a NRSKNUI.DynamicGroupChildRecord
---@param b NRSKNUI.DynamicGroupChildRecord
---@return boolean
local function DefaultCompare(a, b)
    if a.order ~= b.order then
        return a.order < b.order
    end
    return a.index < b.index
end

---Wrap a user-provided comparator to ensure deterministic results.
---@param fn fun(a: NRSKNUI.DynamicGroupChildRecord, b: NRSKNUI.DynamicGroupChildRecord): boolean?
---@return fun(a: NRSKNUI.DynamicGroupChildRecord, b: NRSKNUI.DynamicGroupChildRecord): boolean
local function WrapComparator(fn)
    return function(a, b)
        if fn(a, b) then
            return true
        end
        if fn(b, a) then
            return false
        end
        return DefaultCompare(a, b)
    end
end

-- Layout pipeline --

---Position all active children according to the current grow closure and config.
---@param group NRSKNUI.DynamicGroup
local function PositionChildren(group)
    local config = group._config
    local numVisible = #group._active

    -- If a limit is set, we only position up to that many children.
    if config.UseLimit then
        numVisible = min(numVisible, Default(config.Limit, 5))
    end

    local positions = wipe(group._positions)
    local width, height = group._growFunc(positions, group._active, numVisible)
    group._contentW, group._contentH = width, height

    local point = group._growPoint
    for _, rec in ipairs(group._active) do
        local controlPoint = rec.controlPoint
        local pos = positions[rec]
        if pos then
            controlPoint:SetPixelSize(max(rec.width, 1), max(rec.height, 1))
            controlPoint:ClearAllPoints()
            controlPoint:SetPixelPoint(point, group, point, pos[1], pos[2])
            controlPoint:Show()
        else
            controlPoint:Hide()
        end
    end

    group:SetPixelSize(max(width, Default(config.MinWidth, 1)), max(height, Default(config.MinHeight, 1)))
end

---Run a full layout pass and sort active children, compute positions and apply them.
---@param group NRSKNUI.DynamicGroup
local function RunLayout(group)
    if group._needSort then
        tsort(group._active, group._comparator or DefaultCompare)
        group._needSort = false
    end
    group._needPosition = false
    PositionChildren(group)
end

---Request a layout pass, either immediately or via the scheduled update if available.
---@param group NRSKNUI.DynamicGroup
local function RequestLayout(group)
    if group.ScheduleUpdate then
        group:ScheduleUpdate()
    else
        RunLayout(group)
    end
end

---Mark the group as needing layout.
---@param group NRSKNUI.DynamicGroup
---@param needSort boolean?
local function MarkDirty(group, needSort)
    -- If the group is already marked as needing layout, we don't need to do anything.
    if needSort then
        group._needSort = true
    end

    group._needPosition = true

    -- If the group is suspended, we don't trigger a layout pass until Resume is called.
    if group._suspend > 0 then
        return
    end
    RequestLayout(group)
end

---Resolve a child record by child frame or keyed handle.
---@param group NRSKNUI.DynamicGroup
---@param childOrKey Frame|string
---@return NRSKNUI.DynamicGroupChildRecord?
local function ResolveRecord(group, childOrKey)
    if type(childOrKey) == 'table' then
        return group._byChild[childOrKey]
    end
    return group._byKey[childOrKey]
end

-- Public API --

---Attach a child frame to the group. It is not part of the layout until ActivateChild is called.
---@param child Frame
---@param key? string keyed lookup handle for the other methods
---@param order? number sort priority (default = attach sequence)
function GroupMixin:AttachChild(child, key, order)
    if self._byChild[child] then return end

    -- The key is optional, but if provided it must be unique.
    if key ~= nil and self._byKey[key] then
        error('DynamicGroup: key already in use: ' .. tostring(key))
    end

    self._counter = self._counter + 1
    local controlPoint = self._pool:Acquire()

    local rec = {
        child = child,
        key = key or false,
        order = order or self._counter,
        index = self._counter,
        width = child:GetWidth() or 0,
        height = child:GetHeight() or 0,
        controlPoint = controlPoint,
        active = false,
    }

    child:SetParent(controlPoint)
    child:ClearAllPoints()
    child:SetPixelPoint('CENTER', controlPoint, 'CENTER')

    tinsert(self._children, rec)
    self._byChild[child] = rec

    -- If the key is nil, we don't store it in _byKey.
    if key ~= nil then
        self._byKey[key] = rec
    end
end

---Detach a child frame from the group. It is removed from the layout and hidden.
---@param childOrKey Frame|string
function GroupMixin:DetachChild(childOrKey)
    local rec = ResolveRecord(self, childOrKey)
    if not rec then return end

    if rec.active then
        self:DeactivateChild(childOrKey)
    end

    local child = rec.child
    child:ClearAllPoints()
    child:SetParent(NRSKNUI.HiddenFrame)
    self._pool:Release(rec.controlPoint)

    self._byChild[child] = nil
    if rec.key then
        self._byKey[rec.key] = nil
    end
    for i, entry in ipairs(self._children) do
        if entry == rec then
            tremove(self._children, i)
            break
        end
    end
end

---Activate a child and include it in the layout.
---@param childOrKey Frame|string
function GroupMixin:ActivateChild(childOrKey)
    local rec = ResolveRecord(self, childOrKey)

    -- If the child is already active, do nothing.
    if not rec or rec.active then
        return
    end

    rec.active = true

    -- Reset the control point to a clean state before layout.
    rec.controlPoint:ClearAllPoints()
    tinsert(self._active, rec)
    MarkDirty(self, true)
end

---Deactivate a child and remove it from the layout.
---@param childOrKey Frame|string
function GroupMixin:DeactivateChild(childOrKey)
    local rec = ResolveRecord(self, childOrKey)

    -- If the child is already inactive, do nothing.
    if not rec or not rec.active then
        return
    end

    rec.active = false
    rec.controlPoint:Hide()
    for i, entry in ipairs(self._active) do
        if entry == rec then
            tremove(self._active, i)
            break
        end
    end

    -- Mark the group as dirty to trigger a relayout.
    MarkDirty(self)
end

---Indicate whether a child is currently active in the layout.
---@param childOrKey Frame|string
---@return boolean
function GroupMixin:IsChildActive(childOrKey)
    local rec = ResolveRecord(self, childOrKey)

    return rec ~= nil and rec.active
end

---Get a child frame by its keyed handle.
---@param key string
---@return Frame?
function GroupMixin:GetChild(key)
    local rec = self._byKey[key]

    return rec and rec.child
end

---Update a child's sort priority.
---@param childOrKey Frame|string
---@param order number
function GroupMixin:SetChildOrder(childOrKey, order)
    local rec = ResolveRecord(self, childOrKey)

    -- If the child is not found or the order is unchanged, do nothing.
    if not rec or rec.order == order then
        return
    end

    rec.order = order

    -- If the child is active, mark the group as dirty to trigger a relayout.
    if rec.active then
        MarkDirty(self, true)
    end
end

---Notify the group that a child has been resized and updates the stored width and height.
---@param childOrKey Frame|string
---@param w? number
---@param h? number
function GroupMixin:NotifyChildResized(childOrKey, w, h)
    local rec = ResolveRecord(self, childOrKey)

    -- If the child is not found, do nothing.
    if not rec then
        return
    end

    rec.width = w or rec.child:GetWidth() or 0
    rec.height = h or rec.child:GetHeight() or 0

    -- If the child is active, mark the group as dirty to trigger a relayout.
    if rec.active then
        MarkDirty(self)
    end
end

---Set a custom comparator function for sorting active children.
---@param fn? fun(a: NRSKNUI.DynamicGroupChildRecord, b: NRSKNUI.DynamicGroupChildRecord): boolean?
function GroupMixin:SetSortComparator(fn)
    self._comparator = fn and WrapComparator(fn) or nil
    MarkDirty(self, true)
end

---Set the layout configuration for the group.
---@param config NRSKNUI.DynamicGroupConfig
function GroupMixin:SetConfig(config)
    config = config or {}
    self._config = config

    local entry = growers[config.Grow] or growers.DOWN
    self._growFunc = entry.factory(config)
    local point = entry.point
    if type(point) == 'function' then
        self._growPoint = point(config)
    else
        self._growPoint = point
    end

    self._comparator = config.Comparator and WrapComparator(config.Comparator) or nil
    MarkDirty(self, true)
end

---Force an immediate layout pass, bypassing any scheduled update.
function GroupMixin:ForceLayout()
    self._needSort = true
    RunLayout(self)
end

---Request a layout pass, either immediately or via the scheduled update if available.
function GroupMixin:ScheduleLayout()
    MarkDirty(self)
end

---Suspend layout updates.
function GroupMixin:Suspend()
    self._suspend = self._suspend + 1
end

---Resume layout updates. If the suspend count reaches zero, a layout pass is triggered if needed.
function GroupMixin:Resume()
    if self._suspend > 0 then
        self._suspend = self._suspend - 1
    end
    if self._suspend == 0 and (self._needSort or self._needPosition) then
        RequestLayout(self)
    end
end

---Iterate all active children in attach order: i, child, record.
---@return fun(): number?, Frame?, NRSKNUI.DynamicGroupChildRecord?
function GroupMixin:IterateActive()
    local i = 0
    return function()
        i = i + 1
        local rec = self._active[i]
        if rec then
            return i, rec.child, rec
        end
    end
end

---Iterate all attached children in attach order: i, child, record.
---@return fun(): number?, Frame?, NRSKNUI.DynamicGroupChildRecord?
function GroupMixin:IterateChildren()
    local i = 0
    return function()
        i = i + 1
        local rec = self._children[i]
        if rec then
            return i, rec.child, rec
        end
    end
end

---Get the current content size of the group, which is the bounding box of all active children.
---@return number width, number height
function GroupMixin:GetContentSize()
    return self._contentW, self._contentH
end

---Resolve the anchor point for the current grow type.
---@param grow string
---@return string|nil
function GroupMixin:GetResolvedAnchor(grow)
    if grow == 'DOWN' then
        return 'TOP'
    elseif grow == 'UP' then
        return 'BOTTOM'
    elseif grow == 'RIGHT' then
        return 'LEFT'
    elseif grow == 'LEFT' then
        return 'RIGHT'
    elseif grow == 'HORIZONTAL' then
        return 'CENTER'
    elseif grow == 'VERTICAL' then
        return 'CENTER'
    elseif grow == 'GRID' then
        local point = select(4, ParseGridType(self._config.GridType))
        return point
    end
end

---Update the group's position based on its configuration and optional grow direction.
---@param source NRSKNUI.DynamicGroupConfig
---@param grow? string
function GroupMixin:UpdateGroupPosition(source, grow)
    local posConfig = source.Position
    if not posConfig then return end

    local parent
    if source.anchorFrameType == 'SCREEN' or source.anchorFrameType == 'UIPARENT' then
        parent = UIParent
    elseif source.anchorFrameType == 'SELECTFRAME' and source.ParentFrame then
        local frame = _G[source.ParentFrame]
        parent = frame or UIParent
    end
    parent = parent or UIParent

    local growAnchor = self:GetResolvedAnchor(grow or source.Grow)

    self:ClearAllPoints()
    self:SetPixelPoint(growAnchor, parent, posConfig.AnchorTo or 'CENTER', posConfig.XOffset or 0, posConfig.YOffset or 0)
    self:SetFrameStrata(source.Strata or 'MEDIUM')
end

-- Constructor --

---Create a new DynamicGroup frame with optional name, parent and configuration.
---@param name? string global frame name
---@param parent? Frame defaults to UIParent
---@param config? NRSKNUI.DynamicGroupConfig
---@return NRSKNUI.DynamicGroup
function NRSKNUI:CreateDynamicGroup(name, parent, config)
    ---@class NRSKNUI.DynamicGroup
    local group = CreateFrame('Frame', name, parent or UIParent)
    Mixin(group, GroupMixin)

    group._children = {}
    group._byKey = {}
    group._byChild = {}
    group._active = {}
    group._positions = {}
    group._suspend = 0
    group._counter = 0
    group._contentW, group._contentH = 0, 0

    group._pool = CreateObjectPool(function()
        local controlPoint = CreateFrame('Frame', nil, group)
        controlPoint:Hide()
        return controlPoint
    end, function(_, controlPoint)
        controlPoint:Hide()
        controlPoint:ClearAllPoints()
    end)

    if group.SetScheduledUpdate then
        group:SetScheduledUpdate(function()
            if group._needSort or group._needPosition then
                RunLayout(group)
            end
        end)
    end

    group:SetConfig(config)
    group:ForceLayout()

    return group
end

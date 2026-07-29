--[[
# Pool

* Widget lifecycle: acquire from a per-type pool, release back into it.
* WoW frames are never destroyed, so a GUI that builds fresh frames on every page and
  drops the old ones leaks for the lifetime of the session. Every widget the library
  hands out comes from here and goes back here.

## Widget contract

Each widget type registers a constructor and implements three methods:

    lib:RegisterWidgetType('Button', function(gui) ... return button end)

    OnAcquire(parent, label, config)  configure from scratch, then UpdateColors()
    OnRelease()                       drop callbacks and transient state
    UpdateColors()                    re-apply theme colors
    OnLayout(width)                   optional; the owning row resolved our width

The constructor must create **every** sub-element unconditionally and set **every**
script once. Anything created or hooked per-config would either be missing or stacked
on the next reuse - `OnAcquire` shows, hides and re-points, it never builds.

## Size events are not a layout signal

A widget comes back from the pool at the size it was released at, so revisiting a page
resizes nothing and `OnSizeChanged` never fires. Anything that positions or measures
against its own width must be driven from `OnAcquire` or `OnLayout`, never from the
resize edge alone - keep the script as well, for real resizes, but never rely on it.

## Deferred work

A `C_Timer.After` that lands after its widget was released would act on whatever
recycled it. Capture a generation guard instead:

    local alive = lib.Generation(widget)
    C_Timer.After(0.2, function()
        if not alive() then return end
        ...
    end)

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin

local CreateFrame = CreateFrame
local UIParent = UIParent
local error, next, pairs = error, next, pairs
local tostring = tostring

lib.WidgetRegistry = lib.WidgetRegistry or {}
local WidgetRegistry = lib.WidgetRegistry

---Registers a widget constructor under a type name. The constructor receives the owning
---instance and returns a fully built, unconfigured widget.
---@param widgetType string
---@param constructor fun(gui: KajiGUIInstance): table
function lib:RegisterWidgetType(widgetType, constructor)
    WidgetRegistry[widgetType] = constructor
end

---Returns a predicate that reports whether a widget is still on the same acquisition it
---was on when this was called. See the file header.
---@param widget table
---@return fun(): boolean
function lib.Generation(widget)
    local generation = widget._generation
    return function() return widget._generation == generation end
end

---Sets up the per-instance pool state. Called from lib:New.
function InstanceMixin:_InitPool()
    self._pools = {}    -- [widgetType] = { [widget] = true }, released and parked
    self._acquired = {} -- [widget] = widgetType, currently in use

    -- Parked widgets live under a hidden frame rather than being orphaned with
    -- SetParent(nil): they stay reachable, stay hidden, and cost nothing to draw.
    self._poolHost = CreateFrame("Frame", nil, UIParent)
    self._poolHost:Hide()
end

---Takes a widget of the given type from the pool, building one if the pool is empty.
---@param widgetType string
---@return table widget
function InstanceMixin:AcquireWidget(widgetType)
    local constructor = WidgetRegistry[widgetType]
    if not constructor then
        error("Attempt to acquire unknown widget type '" .. tostring(widgetType) .. "'", 2)
    end

    local pool = self._pools[widgetType]
    if not pool then
        pool = {}
        self._pools[widgetType] = pool
    end

    local widget = next(pool)
    if widget then
        pool[widget] = nil
    else
        widget = constructor(self)
        widget._widgetType = widgetType
        widget._generation = 0
    end

    self._acquired[widget] = widgetType
    return widget
end

---Acquires a widget and configures it. The single path behind every public Create*.
---@param widgetType string
---@param parent Frame
---@param label? string
---@param config? table
---@return table widget
function InstanceMixin:BuildWidget(widgetType, parent, label, config)
    local widget = self:AcquireWidget(widgetType)
    widget:OnAcquire(parent, label, config or {})
    return widget
end

---Returns a widget to its pool. Idempotent: releasing something that is not currently
---acquired does nothing, so a container can release its children without tracking
---which of them it already handed back.
---@param widget table
function InstanceMixin:ReleaseWidget(widget)
    local widgetType = widget and self._acquired[widget]
    if not widgetType then return end

    -- Cleared first so a re-entrant release from OnRelease (a container releasing a
    -- child that points back at it) terminates instead of recursing.
    self._acquired[widget] = nil
    widget._generation = (widget._generation or 0) + 1

    if widget.OnRelease then widget:OnRelease() end

    widget:ClearAllPoints()
    widget:Hide()
    widget:SetParent(self._poolHost)

    self._pools[widgetType][widget] = true
end

---Releases every widget in a list and empties it. Containers use this on their tracked
---children, which is what makes release recurse down a card.
---@param widgets table[]
function InstanceMixin:ReleaseAll(widgets)
    if not widgets then return end
    for i = #widgets, 1, -1 do
        self:ReleaseWidget(widgets[i])
        widgets[i] = nil
    end
end

---Live and pooled counts per widget type, for the host's diagnostics.
---@return table<string, { acquired: number, pooled: number }> stats
---@return number totalAcquired
---@return number totalPooled
function InstanceMixin:GetPoolStats()
    local stats = {}
    local totalAcquired, totalPooled = 0, 0

    local function entry(widgetType)
        local e = stats[widgetType]
        if not e then
            e = { acquired = 0, pooled = 0 }
            stats[widgetType] = e
        end
        return e
    end

    for _, widgetType in pairs(self._acquired) do
        local e = entry(widgetType)
        e.acquired = e.acquired + 1
        totalAcquired = totalAcquired + 1
    end

    for widgetType, pool in pairs(self._pools) do
        local e = entry(widgetType)
        for _ in pairs(pool) do
            e.pooled = e.pooled + 1
            totalPooled = totalPooled + 1
        end
    end

    return stats, totalAcquired, totalPooled
end

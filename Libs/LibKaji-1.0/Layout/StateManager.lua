--[[
# StateManager

* Enables or disables registered widgets from named boolean conditions.
* - A widget joins one or more groups, a group may have a condition function.
* - A widget is enabled only when the master-enable and every one of its groups's conditions are true.

## Example

    local sm = GUI:CreateStateManager()
    sm:SetCondition('custom', function() return db.mode == 'custom' end)
    sm:Register(colorPicker, 'all', 'custom')
    sm:UpdateAll(db.enabled)  -- master enable

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin

local ipairs = ipairs
local pairs = pairs
local type = type
local Mixin = Mixin

---@class KajiGUIStateManagerMixin
---@field groups table<string, Frame[]>
---@field conditions table<string, function>
---@field widgetGroups table<Frame, table<string, boolean>>
local StateManagerMixin = {}

---Registers a widget to one or more condition groups.
---@param widget Frame
---@param ... string group name(s), e.g. 'all', 'custom' etc.
---@return self
function StateManagerMixin:Register(widget, ...)
    if not widget then return self end
    local groupNames = { ... }

    self.widgetGroups[widget] = self.widgetGroups[widget] or {}

    for _, groupName in ipairs(groupNames) do
        self.groups[groupName] = self.groups[groupName] or {}
        self.groups[groupName][#self.groups[groupName] + 1] = widget
        self.widgetGroups[widget][groupName] = true
    end

    return self
end

---Registers many widgets to a single group.
---@param widgets Frame[]
---@param groupName string
---@return self
function StateManagerMixin:RegisterGroup(widgets, groupName)
    if not widgets or not groupName then return self end
    self.groups[groupName] = self.groups[groupName] or {}
    for _, widget in ipairs(widgets) do
        self.groups[groupName][#self.groups[groupName] + 1] = widget
        self.widgetGroups[widget] = self.widgetGroups[widget] or {}
        self.widgetGroups[widget][groupName] = true
    end

    return self
end

---Stops tracking a widget, removing it from every group.
---Call this when a widget is torn down so a live rebuild doesn't have to refresh the whole page.
---@param widget Frame
---@return self
function StateManagerMixin:Unregister(widget)
    local groups = widget and self.widgetGroups[widget]
    if not groups then return self end

    for groupName in pairs(groups) do
        local list = self.groups[groupName]
        if list then
            -- Compact the group array in place, dropping every reference to widget.
            local write = 0
            for read = 1, #list do
                local entry = list[read]
                if entry ~= widget then
                    write = write + 1
                    list[write] = entry
                end
            end
            for i = #list, write + 1, -1 do
                list[i] = nil
            end
        end
    end

    self.widgetGroups[widget] = nil

    return self
end

---Sets the condition function for a group. It returns whether the group is enabled.
---@param groupName string
---@param conditionFn fun(): boolean
---@return self
function StateManagerMixin:SetCondition(groupName, conditionFn)
    self.conditions[groupName] = conditionFn
    return self
end

---Applies enabled state to every widget from the master enable and group conditions.
---@param mainEnabled boolean
function StateManagerMixin:UpdateAll(mainEnabled)
    -- Evaluate every condition once so a group shared by many widgets isn't re-run per widget and every widget sees one consistent snapshot.
    local conditionResults = {}
    for groupName, condition in pairs(self.conditions) do
        if type(condition) == "function" then
            conditionResults[groupName] = condition() and true or false
        end
    end

    local compositeWidgets = {}

    for widget, groups in pairs(self.widgetGroups) do
        local enabled = mainEnabled

        if enabled then
            for groupName in pairs(groups) do
                if conditionResults[groupName] == false then
                    enabled = false
                    break
                end
            end
        end

        -- Composite widgets manage their own children off their settled state,
        -- so defer them until every plain widget above has been resolved.
        if widget._hasInternalWidgetState then
            compositeWidgets[#compositeWidgets + 1] = { widget = widget, enabled = enabled }
        else
            if widget.SetEnabled then
                widget:SetEnabled(enabled)
            elseif widget.SetDisabled then
                widget:SetDisabled(not enabled)
            end
        end
    end

    for _, entry in ipairs(compositeWidgets) do
        local widget = entry.widget
        if widget.SetEnabled then
            widget:SetEnabled(entry.enabled)
        elseif widget.SetDisabled then
            widget:SetDisabled(not entry.enabled)
        end
    end
end

---Forces a group's enabled state, bypassing the master enable and conditions.
---A manual override, UpdateAll is the condition-aware path.
---@param groupName string
---@param enabled boolean
function StateManagerMixin:UpdateGroup(groupName, enabled)
    local widgets = self.groups[groupName]
    if not widgets then return end

    for _, widget in ipairs(widgets) do
        if widget.SetEnabled then
            widget:SetEnabled(enabled)
        elseif widget.SetDisabled then
            widget:SetDisabled(not enabled)
        end
    end
end

---Returns the widgets registered under a group.
---@param groupName string
---@return Frame[]
function StateManagerMixin:GetGroup(groupName)
    return self.groups[groupName] or {}
end

---Clears all registered widgets, groups and conditions.
function StateManagerMixin:Clear()
    self.groups = {}
    self.conditions = {}
    self.widgetGroups = {}
end

---Creates a new state manager instance. Each instance tracks its own groups, conditions and widgets.
---@return KajiGUIStateManager
function InstanceMixin:CreateStateManager()
    ---@class KajiGUIStateManager : KajiGUIStateManagerMixin
    local manager = {
        groups = {},
        conditions = {},
        widgetGroups = {},
    }

    return Mixin(manager, StateManagerMixin)
end

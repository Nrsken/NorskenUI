---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

local ipairs, pairs = ipairs, pairs
local tsort = table.sort
local format = string.format
local CopyTable = CopyTable

local ID_PREFIX = 'cdm:'

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

---@param id string
---@return boolean
function CDM:IsGroup(id)
    local display = self:Get(id)
    return display ~= nil and display.type == 'group'
end

---@param id string
---@return string
function CDM:GetName(id)
    local display = self:Get(id)
    return (display and display.name) or format(L['Display %s'], id)
end

---@param a table
---@param b table
local function ByOrderThenName(a, b)
    if a.order and b.order and a.order ~= b.order then return a.order < b.order end
    if (a.order ~= nil) ~= (b.order ~= nil) then return a.order ~= nil end
    return a.text < b.text
end

---A group's icons in display order.
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

---Groups and standalone icons, by name.
---@return table[] roots { key, text, isGroup }
function CDM:GetRoots()
    local roots = {}
    for id, display in pairs(Store()) do
        if not display.parent then
            roots[#roots + 1] = { key = id, text = display.name or id, isGroup = display.type == 'group' }
        end
    end
    tsort(roots, function(a, b) return a.text < b.text end)
    return roots
end

---@param ordered string[]
local function Renumber(ordered)
    local store = Store()
    for index, key in ipairs(ordered) do store[key].order = index end
end

---Move an icon into a group (last) or out of every group.
---@param id string
---@param groupId string?
function CDM:SetParent(id, groupId)
    local display = self:Get(id)
    if not display or display.type == 'group' or display.parent == groupId then return end
    if groupId and not self:IsGroup(groupId) then return end

    display.order = nil
    display.parent = groupId
    if not groupId then return end

    local ordered = {}
    for _, child in ipairs(self:GetChildren(groupId)) do
        if child.key ~= id then ordered[#ordered + 1] = child.key end
    end
    ordered[#ordered + 1] = id
    Renumber(ordered)
end

---Place an icon before or after another, joining that one's group.
---@param id string
---@param targetId string
---@param position 'before'|'after'
function CDM:MoveNextTo(id, targetId, position)
    local display, target = self:Get(id), self:Get(targetId)
    if not (display and target) or id == targetId or display.type == 'group' or target.type == 'group' then return end

    local groupId = target.parent
    display.parent = groupId
    display.order = nil
    if not groupId then return end

    local ordered = {}
    for _, child in ipairs(self:GetChildren(groupId)) do
        if child.key ~= id then
            if child.key == targetId and position == 'before' then ordered[#ordered + 1] = id end
            ordered[#ordered + 1] = child.key
            if child.key == targetId and position == 'after' then ordered[#ordered + 1] = id end
        end
    end
    Renumber(ordered)
end

---@param name string
---@return string? id
function CDM:CreateGroup(name)
    if not name or name == '' then return nil end

    local id = NextId()
    Store()[id] = {
        type = 'group',
        name = name,
        Enabled = true,
        Layout = { Grow = 'HORIZONTAL', Spacing = 2, UseLimit = false, Limit = 10 },
        Style = {},
        Load = NRSKNUI.LoadConditions:GetDefaults(),
        anchorFrameType = 'UIPARENT',
        ParentFrame = 'UIParent',
        Position = { AnchorFrom = 'CENTER', AnchorTo = 'CENTER', XOffset = 0, YOffset = -200 },
    }
    return id
end

---@param name string
---@param trigger table
---@param groupId string?
---@return string? id
function CDM:CreateIcon(name, trigger, groupId)
    if not name or name == '' or not trigger then return nil end

    local id = NextId()
    Store()[id] = {
        type = 'icon',
        name = name,
        Enabled = true,
        Trigger = trigger,
        Conditions = {},
        Style = {},
        Load = NRSKNUI.LoadConditions:GetDefaults(),
        anchorFrameType = 'UIPARENT',
        ParentFrame = 'UIParent',
        Position = { AnchorFrom = 'CENTER', AnchorTo = 'CENTER', XOffset = 0, YOffset = 0 },
    }
    if groupId then self:SetParent(id, groupId) end
    return id
end

---A copy beside the original; a group copies its icons with it.
---@param id string
---@return string? newId
function CDM:Duplicate(id)
    local source = self:Get(id)
    if not source then return nil end

    local newId = NextId()
    local copy = CopyTable(source)
    copy.name = format(L['%s (Copy)'], self:GetName(id))
    copy.order = nil
    Store()[newId] = copy

    if source.type == 'group' then
        for _, child in ipairs(self:GetChildren(id)) do
            local childId = NextId()
            local childCopy = CopyTable(Store()[child.key])
            childCopy.parent = newId
            Store()[childId] = childCopy
        end
    elseif source.parent then
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

---Remove a display; a group takes its icons with it unless keepChildren.
---@param id string
---@param keepChildren boolean?
function CDM:Delete(id, keepChildren)
    local display = self:Get(id)
    if not display then return end

    if display.type == 'group' then
        for _, child in ipairs(self:GetChildren(id)) do
            if keepChildren then
                self:SetParent(child.key, nil)
            else
                self:Release(child.key)
                Store()[child.key] = nil
            end
        end
    end

    self:Release(id)
    Store()[id] = nil
end

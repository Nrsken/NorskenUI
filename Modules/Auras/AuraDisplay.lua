---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AuraDisplayModule
local AuraDisplay = NRSKNUI:GetModule('AuraDisplay')
local Anchors = NRSKNUI.Anchors
local AuraPreview = NRSKNUI.AuraPreview
local L = NRSKNUI.Libs.AL

local tinsert, tsort = table.insert, table.sort
local ipairs, pairs = ipairs, pairs
local setmetatable = setmetatable
local CreateFrame = CreateFrame
local format = string.format
local CopyTable = CopyTable
local wipe = wipe
local type = type

local BUILTIN_PREFIX = 'builtin:'
local USER_PREFIX = 'user:'
local GROUP_PREFIX = 'group:'

local function Store()
    return NRSKNUI.db.profile.AuraDisplays
end

local function GroupStore()
    return NRSKNUI.db.profile.AuraDisplayGroups
end

-- Triggers are seeded into saved data, not AceDB defaults, which would restore removed spells.
local BUILTIN_PRESETS = {
    ['builtin:advancedDebuffs'] = 'preset:advancedDebuffs',
    ['builtin:defensives'] = 'preset:defensives',
    ['builtin:generalBuffs'] = 'preset:generalBuffs',
    ['builtin:speed'] = 'preset:speed',
}

---@param id string
---@return table? instance
function AuraDisplay:Get(id)
    local store = Store()
    local instance = id and store and store[id] or nil
    local preset = instance and BUILTIN_PRESETS[id]

    -- No Type or branches means a pre-rework save holding only the user's own keys.
    local trigger = instance and instance.Trigger
    if preset and not (trigger and trigger.Type and trigger.branches) then
        local old = instance.Trigger or {} -- keeps its added and switched-off spells
        instance.Trigger = NRSKNUI.AuraTriggers:ToAuraFilter({
            Type = NRSKNUI.AuraTriggers.Types.Preset, Preset = preset, Unit = 'player', Added = old.Added, Removed = old.Removed,
        })
    end

    return instance
end

---This profile's trackers live in the Cooldown & Aura Manager now (CDM schema 8).
---@return boolean
function AuraDisplay:IsMerged()
    return NRSKNUI.db.profile.CDM.AurasMerged == true
end

---@param id string?
---@return boolean
function AuraDisplay:IsBuiltin(id)
    return type(id) == 'string' and id:sub(1, #BUILTIN_PREFIX) == BUILTIN_PREFIX
end

---Sorted { key, text } entries for the GUI's display list.
---@return table[]
function AuraDisplay:GetList()
    local builtins, own = {}, {}

    for id, instance in pairs(Store() or {}) do
        local entry = { key = id, text = instance.name or id }
        tinsert(self:IsBuiltin(id) and builtins or own, entry)
    end

    tsort(builtins, function(a, b) return a.key < b.key end)
    tsort(own, function(a, b) return a.text < b.text end)

    for _, entry in ipairs(own) do
        tinsert(builtins, entry)
    end

    return builtins
end

---Sorted { key, name } groups, for the sidebar and the context menu.
---@return table[]
function AuraDisplay:GetGroups()
    local list = {}

    for id, group in pairs(GroupStore() or {}) do
        list[#list + 1] = { key = id, name = group.name or id }
    end
    tsort(list, function(a, b) return a.name < b.name end)

    return list
end

---@param id string?
---@return string?
function AuraDisplay:GetGroupName(id)
    local group = id and GroupStore() and GroupStore()[id]
    return group and group.name or nil
end

---@param name string
---@return string? id
function AuraDisplay:CreateGroup(name)
    local store = GroupStore()
    if not store or not name or name == '' then return nil end

    local index = 1
    while store[GROUP_PREFIX .. index] do
        index = index + 1
    end

    local id = GROUP_PREFIX .. index
    store[id] = { name = name }

    return id
end

---A group outlives its last member; only DeleteGroup removes it.
---@param id string
---@param groupId string?
function AuraDisplay:SetGroup(id, groupId)
    local instance = self:Get(id)
    if not instance or instance.group == groupId then return end

    instance.order = nil
    if not groupId then
        instance.group = nil
        return
    end

    -- Renumber existing members so the newcomer lands last.
    local members = self:GetMembers(groupId)
    for index, member in ipairs(members) do Store()[member.key].order = index end
    instance.group = groupId
    instance.order = #members + 1
end

---Trackers never placed by hand sort after the placed ones, by name.
---@param groupId string
---@return table[] members { key, text, order? }
function AuraDisplay:GetMembers(groupId)
    local members = {}
    for id, instance in pairs(Store() or {}) do
        if instance.group == groupId then
            members[#members + 1] = { key = id, text = instance.name or id, order = instance.order }
        end
    end
    tsort(members, function(a, b)
        if a.order and b.order and a.order ~= b.order then return a.order < b.order end
        if (a.order ~= nil) ~= (b.order ~= nil) then return a.order ~= nil end
        return a.text < b.text
    end)
    return members
end

---Joins the target's group; an ungrouped target ungroups it, as the top level stays sorted by name.
---@param id string
---@param targetId string
---@param position 'before'|'after'
function AuraDisplay:MoveNextTo(id, targetId, position)
    local instance, target = self:Get(id), self:Get(targetId)
    if not (instance and target) or id == targetId then return end

    local groupId = target.group
    instance.group = groupId
    instance.order = nil
    if not groupId then return end

    local members = self:GetMembers(groupId)
    local ordered = {}
    for _, member in ipairs(members) do
        if member.key ~= id then
            if member.key == targetId and position == 'before' then ordered[#ordered + 1] = id end
            ordered[#ordered + 1] = member.key
            if member.key == targetId and position == 'after' then ordered[#ordered + 1] = id end
        end
    end
    for index, key in ipairs(ordered) do Store()[key].order = index end
end

---@param groupId string
---@param name string
function AuraDisplay:RenameGroup(groupId, name)
    local group = GroupStore()[groupId]
    if not group or not name or name == '' then return end

    group.name = name
end

---Removes a group; its trackers stay, outside any group.
---@param groupId string
function AuraDisplay:DeleteGroup(groupId)
    for _, instance in pairs(Store() or {}) do
        if instance.group == groupId then
            instance.group = nil
            instance.order = nil
        end
    end
    GroupStore()[groupId] = nil
end

-- The page this module configures, so PreviewManager resolves it without an anchor lookup.
AuraDisplay.previewPages = 'auras'

function AuraDisplay:OnInitialize()
    self.hosts = {}

    self.db = setmetatable({}, {
        __index = function(_, key)
            if key == 'Enabled' then return AuraDisplay:AnyEnabled() end
            return nil
        end,
    })
end

---The container config built from an instance's settings; the CDM's aura groups own it now.
---@param db table
---@return table
function AuraDisplay:GetContainerConfig(db)
    return NRSKNUI:GetModule('CDM'):GetAuraContainerConfig(db)
end

---@param db table
---@return number
function AuraDisplay:GetPreviewCount(db)
    return NRSKNUI:GetModule('CDM'):GetAuraPreviewCount(db)
end

---Size a host to the largest grid its settings can produce, so the mover covers the full footprint.
---@param id string
function AuraDisplay:ResizeHost(id)
    local db, host = self:Get(id), self.hosts[id]
    if not (db and host) then return end

    host:SetSize(NRSKNUI:GetAuraGridSize(db, self:GetPreviewCount(db)))
end

---Create an instance's mover host. The container is attached later, out of combat.
---@param id string
---@return Frame? host
function AuraDisplay:CreateHost(id)
    if self.hosts[id] then return self.hosts[id] end
    if not self:Get(id) then return nil end

    -- Named per instance so the mover and any /getpoint style tooling can tell them apart.
    self.hosts[id] = CreateFrame('Frame', 'NRSKNUI_AuraDisplay_' .. id:gsub('%W', '_'), UIParent)
    self:ResizeHost(id)

    return self.hosts[id]
end

---@param db table
---@param id string
---@return string
local function ResolveTriggerUnit(db, id)
    return NRSKNUI:GetModule('CDM'):ResolveAuraUnit(db, id)
end

---Attach the native aura container to an instance's host.
---@param id string
function AuraDisplay:BuildContainer(id)
    local db, host = self:Get(id), self.hosts[id]
    if not (db and host) or host.container then return end

    local config = self:GetContainerConfig(db)
    local container = host:CreateAuraContainer(config)
    if not container then return end

    container:ClearAllPoints()
    container:SetPoint(config.containerPoint, host, config.containerPoint)

    container:AddFilteredGroup(db.Trigger)

    -- An instance says which unit it watches, unlike the three fixed displays this replaced.
    container:SetUnit(ResolveTriggerUnit(db, id))
    container:UpdateUnitGate() -- also starts the container watching what can move a gate verdict
    host.container = container

    AuraPreview:Attach(container, host, config.containerPoint)
    AuraPreview:Update(container, config, self:GetPreviewCount(db), db.Trigger)
end

---Re-read an instance's trigger, for an edit made on its Trigger tab.
---@param id string
function AuraDisplay:ApplyTrigger(id)
    local db = self:Get(id)
    local host = self.hosts[id]
    local container = host and host.container
    if not (db and container) then return end

    self:ResizeHost(id) -- editing a trigger can add or drop branches, which moves the worst case
    container:SetUnit(ResolveTriggerUnit(db, id))
    container:RebindFilteredGroups(db.Trigger)
    container:UpdateUnitGate()
end

---Re-read every instance's trigger. Wired to the AuraTriggers callback, since one GUI edit can
---affect an instance that is not the one on screen.
function AuraDisplay:ReapplyTriggers()
    for id in pairs(self.hosts) do
        self:ApplyTrigger(id)
    end
end

---Apply settings to an instance, creating its host and container if needed.
---@param id string? nil applies every instance
function AuraDisplay:ApplySettings(id)
    if id == nil then return self:ApplyAll() end

    local db = self:Get(id)
    if not db then return end
    if self:IsMerged() then
        if self.hosts[id] then self.hosts[id]:Hide() end
        return
    end

    local host = self:CreateHost(id)
    if not host then return end

    if not db.Enabled then
        host:Hide()
        return
    end

    self:ResizeHost(id)
    host:Show()
    host:NUIApplyPosition(db)
    Anchors:Register(self, id, host, 'auras')

    local container = host.container
    if container then
        -- Layout re-applies live, button appearance does not (see container:ApplyLayout).
        local config = self:GetContainerConfig(db)
        container:ClearAllPoints()
        container:SetPoint(config.containerPoint, host, config.containerPoint)
        container:ApplyLayout(config)
        AuraPreview:Attach(container, host, config.containerPoint)
        AuraPreview:Update(container, config, self:GetPreviewCount(db), db.Trigger)
        return
    end

    NRSKNUI:RunWhenSafe(function()
        self:BuildContainer(id)
    end)
end

---Re-apply every instance, for a settings change that could touch any of them.
function AuraDisplay:ApplyAll()
    for id in pairs(Store() or {}) do
        self:ApplySettings(id)
    end
end

---Is any instance turned on?
---@return boolean
function AuraDisplay:AnyEnabled()
    if self:IsMerged() then return false end
    for _, instance in pairs(Store() or {}) do
        if instance.Enabled then return true end
    end
    return false
end

-- Instance lifecycle --

---@return string id
local function NextUserId()
    local store = Store()
    local index = 1
    while store[USER_PREFIX .. index] do
        index = index + 1
    end
    return USER_PREFIX .. index
end

---Add a user instance, copied from whichever built-in reads closest to a blank one.
---@param name string
---@param presetKey string? start from this preset instead of empty
---@return string? id
function AuraDisplay:Create(name, presetKey)
    local store = Store()
    if not store or not name or name == '' then return nil end

    local id = NextUserId()
    local template = store[BUILTIN_PREFIX .. 'defensives']

    local instance = template and CopyTable(template) or {}
    instance.name = name
    instance.Enabled = true
    instance.group = nil
    instance.order = nil
    instance.Trigger = presetKey
        and NRSKNUI.AuraTriggers:ToAuraFilter({ Type = NRSKNUI.AuraTriggers.Types.Preset, Preset = presetKey, Unit = 'player' })
        or NRSKNUI.AuraTriggers:New()
    instance.anchorFrameType = 'UIPARENT'
    instance.ParentFrame = 'UIParent'
    instance.Position = { AnchorFrom = 'CENTER', AnchorTo = 'CENTER', XOffset = 0, YOffset = 0 }

    store[id] = instance
    return id
end

---A user copy of any instance, built-ins included, with every setting and its trigger.
---@param id string
---@return string? newId
function AuraDisplay:Duplicate(id)
    local source = self:Get(id)
    if not source then return nil end

    local newId = NextUserId()
    local copy = CopyTable(source)
    copy.name = format(L['%s (Copy)'], self:GetName(id))
    copy.group = nil
    copy.order = nil

    Store()[newId] = copy
    return newId
end

---Put a built-in back to how it shipped, its spells and every setting.
---@param id string
function AuraDisplay:ResetBuiltin(id)
    local instance = self:Get(id)
    local shipped = NRSKNUI:GetDefaultDB().profile.AuraDisplays[id]
    if not (instance and shipped and self:IsBuiltin(id)) then return end

    wipe(instance)
    for key, value in pairs(CopyTable(shipped)) do instance[key] = value end
    self:Get(id) -- seeds the trigger again
end

---@param id string
---@param name string
function AuraDisplay:Rename(id, name)
    local instance = self:Get(id)
    if not instance or not name or name == '' then return end

    instance.name = name
end

---Remove a user instance.
---@param id string
---@return boolean removed
function AuraDisplay:Delete(id)
    local store = Store()
    if not store or not store[id] or self:IsBuiltin(id) then return false end

    local host = self.hosts[id]
    if host then
        host:Hide()
        self.hosts[id] = nil
    end

    store[id] = nil
    return true
end

---@param id string
---@return string
function AuraDisplay:GetName(id)
    local instance = self:Get(id)
    return (instance and instance.name) or format(L['Display %s'], id)
end

function AuraDisplay:OnEnable()
    self:ApplyAll()
    NRSKNUI.AuraTriggers:RegisterCallback(self, function(module) module:ReapplyTriggers() end)
end

function AuraDisplay:OnDisable()
    NRSKNUI.AuraTriggers:UnregisterCallback(self)

    for _, host in pairs(self.hosts) do
        host:Hide()
    end
end

-- Previews --

---Point an instance's preview at what its settings currently say.
---@param id string
---@return boolean ready
function AuraDisplay:RefreshPreview(id)
    local db, host = self:Get(id), self.hosts[id]
    local container = host and host.container
    if not (db and container) then return false end

    local config = self:GetContainerConfig(db)
    AuraPreview:Attach(container, host, config.containerPoint)
    AuraPreview:Update(container, config, self:GetPreviewCount(db), db.Trigger)

    return true
end

---Swap one instance between its live container and its preview.
---@param id string
---@param shown boolean
function AuraDisplay:SetPreviewShown(id, shown)
    local host = self.hosts[id]
    local container = host and host.container

    if not container then
        if shown then
            NRSKNUI:Print(format(L['No container to preview for %s yet.'], self:GetName(id)))
        end
        return
    end

    if shown then self:RefreshPreview(id) end

    AuraPreview:SetShown(container, shown)
    container:SetShown(not shown)
end

---Which instance the GUI has open, so selecting one in the mini sidebar previews that one alone.
---@param id string?
function AuraDisplay:SetPreviewTarget(id)
    if self.previewTarget == id then return end

    local previous = self.previewTarget
    self.previewTarget = id

    if not self.previewing or self.previewAll then return end

    if previous then self:SetPreviewShown(previous, false) end
    if id then self:SetPreviewShown(id, true) end
end

---@param _pageId string? unused, this module claims one page
---@param showAll boolean? the everything view, which previews every enabled instance at once
function AuraDisplay:ShowPreview(_pageId, showAll)
    self.previewing = true
    self.previewAll = showAll or false

    if showAll then
        for id in pairs(self.hosts) do
            self:SetPreviewShown(id, true)
        end
        return
    end

    if self.previewTarget then
        self:SetPreviewShown(self.previewTarget, true)
    end
end

function AuraDisplay:HidePreview()
    self.previewing = false
    self.previewAll = false

    for id in pairs(self.hosts) do
        self:SetPreviewShown(id, false)
    end
end

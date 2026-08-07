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
local min = math.min
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

---@param id string
---@return table? instance
function AuraDisplay:Get(id)
    local store = Store()
    return id and store and store[id] or nil
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

---Move a display into a group or out of one when groupId is nil.
---@param id string
---@param groupId string?
function AuraDisplay:SetGroup(id, groupId)
    local instance = self:Get(id)
    if not instance then return end

    instance.group = groupId
    self:PruneGroups()
end

---Forget any group nothing points at.
function AuraDisplay:PruneGroups()
    local store, groups = Store(), GroupStore()
    if not (store and groups) then return end

    local used = {}
    for _, instance in pairs(store) do
        if instance.group then used[instance.group] = true end
    end

    for id in pairs(groups) do
        if not used[id] then groups[id] = nil end
    end
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

---Layout anchor corner derived from growth direction.
---@param cfg table
---@return string
local function AnchorCorner(cfg)
    local vertical = (cfg.verticalGrowthDirection == 'DOWN') and 'TOP' or 'BOTTOM'
    local horizontal = (cfg.horizontalGrowthDirection == 'LEFT') and 'RIGHT' or 'LEFT'
    return vertical .. horizontal
end

---The container config built from an instance's settings.
---@param db table
---@return table
function AuraDisplay:GetContainerConfig(db)
    return {
        maximumLineSize = db.perRow * (db.size + db.elementSpacing),
        anchorPoint = AnchorCorner(db),
        horizontalGrowthDirection = db.horizontalGrowthDirection,
        verticalGrowthDirection = db.verticalGrowthDirection,
        size = db.size,
        elementSpacing = db.elementSpacing,
        lineSpacing = db.lineSpacing,
        maxFrameCount = db.maxFrameCount,
        sortMethod = AuraContainerSortMethod[db.sortMethod],
        sortDirection = AuraContainerSortDirection[db.sortDirection],
        showApplicationCount = db.showApplicationCount,
        showDurationText = db.showDurationText,
        durationTextColorCurve = true,
        drawSwipe = db.drawSwipe,
        drawEdge = db.drawEdge,
        reverseSwipe = db.reverseSwipe,
        showDebuffBorder = db.showBorder or nil,
        showWithoutDispelType = db.showBorderWithoutDispelType,
        showDebuffDispelIcon = db.showDebuffDispelIcon,
        dispelIconSize = db.dispelIconSize,
        fontDB = db,
        stackFont = db.StackFont,
        durationFont = db.DurationFont,
        tooltipHideInCombat = db.tooltipHideInCombat,
    }
end

---Most auras an instance's settings can put on screen, one group per trigger branch.
---@param db table
---@return number
function AuraDisplay:GetPreviewCount(db)
    return min(db.maxFrameCount * NRSKNUI:GetTriggerBranchCount(db.Trigger), db.previewLimit)
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

---Attach the native aura container to an instance's host.
---@param id string
function AuraDisplay:BuildContainer(id)
    local db, host = self:Get(id), self.hosts[id]
    if not (db and host) or host.container then return end

    local config = self:GetContainerConfig(db)
    local container = host:CreateAuraContainer(config)
    if not container then return end

    container:ClearAllPoints()
    container:SetPoint(config.anchorPoint, host, config.anchorPoint)

    container:AddFilteredGroup(db.Trigger)

    -- An instance says which unit it watches, unlike the three fixed displays this replaced.
    container:SetUnit(db.Trigger and db.Trigger.Unit or 'player')
    container:UpdateUnitGate() -- also starts the container watching what can move a gate verdict
    host.container = container

    AuraPreview:Attach(container, host, config.anchorPoint)
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
    container:SetUnit(db.Trigger and db.Trigger.Unit or 'player')
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
        container:SetPoint(config.anchorPoint, host, config.anchorPoint)
        container:ApplyLayout(config)
        AuraPreview:Attach(container, host, config.anchorPoint)
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
    for _, instance in pairs(Store() or {}) do
        if instance.Enabled then return true end
    end
    return false
end

-- Instance lifecycle --

---Add a user instance, copied from whichever built-in reads closest to a blank one.
---@param name string
---@return string? id
function AuraDisplay:Create(name)
    local store = Store()
    if not store or not name or name == '' then return nil end

    local index = 1
    while store[USER_PREFIX .. index] do
        index = index + 1
    end

    local id = USER_PREFIX .. index
    local template = store[BUILTIN_PREFIX .. 'defensives']

    local instance = template and CopyTable(template) or {}
    instance.name = name
    instance.Enabled = true
    instance.Trigger = NRSKNUI.AuraTriggers:New()
    instance.anchorFrameType = 'UIPARENT'
    instance.ParentFrame = 'UIParent'
    instance.Position = { AnchorFrom = 'CENTER', AnchorTo = 'CENTER', XOffset = 0, YOffset = 0 }

    store[id] = instance
    return id
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
    self:PruneGroups()
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
    AuraPreview:Attach(container, host, config.anchorPoint)
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

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local Anchors = NRSKNUI.Anchors
local LoadConditions = NRSKNUI.LoadConditions

--[[
The CDM module itself.
Builds and releases displays, decides what's loaded vs what is being previewed and hides Blizzard's own Cooldown Manager when asked.
]]

local debugprofilestop = debugprofilestop
local hooksecurefunc = hooksecurefunc
local pairs, ipairs = pairs, ipairs
local CreateFrame = CreateFrame
local format = string.format
local tostring = tostring
local tsort = table.sort
local wipe = wipe

local SetCVar = C_CVar and C_CVar.SetCVar

local STATE_RANK = {
    loaded = 3,
    standby = 2,
    unloaded = 1
}
CDM.STATE_RANK = STATE_RANK

local BLIZZARD_VIEWERS = {
    'EssentialCooldownViewer',
    'UtilityCooldownViewer',
    'BuffIconCooldownViewer',
    'BuffBarCooldownViewer',
}

local hideViewers = false -- faded out but kept running, while a display reads their bars
local hookedViewers = {} ---@type table<table, true>

-- Lifecycle --

function CDM:UpdateDB()
    -- Frames are keyed by display id and another profile reuses the same ids for other displays.
    -- A namespace reset or copy refills the same table, so comparing tables can't tell a change apart.
    if self.icons then
        self:ReleaseAll()
        wipe(self.preview)
        wipe(self.selectionPreview)
    end

    local db = self.namespace.profile
    self.db = db
    if db.Version == 0 then -- a profile the CDM hasn't set up yet
        if not self:ImportOldTrackers(db) then
            self:SeedBuiltins()
            db.Enabled = true -- the built-ins are on, as they were under the old Auras module
        end
        db.Version = self:GetSchemaVersion()
    end

    self:EnsureUids()
end

function CDM:OnInitialize()
    self.namespace = NRSKNUI.ProfileManager:RegisterNamespace('CDM', self.Defaults)
    self:UpdateDB()
    self.icons = {} ---@type table<string, CDMIcon>
    self.containers = {} ---@type table<string, Frame|NRSKNUI.DynamicGroup>
    self.spareStatic = {} ---@type Frame[]
    self.spareDynamic = {} ---@type NRSKNUI.DynamicGroup[]
    self.spareChain = {} ---@type CDMChainGroup[]
    self.preview = {} ---@type table<string, number>
    self.selectionPreview = {} ---@type string[]
end

function CDM:OnEnable()
    if self.db.HideBlizzard then
        self:SetBlizzardViewers(true)
    end
    if self.db.HidePlayerCastBar then
        self:HidePlayerCastBar()
    end

    self:RegisterTriggerEvents()
    self.Catalogue:RegisterEvents()
    LoadConditions:RegisterCallback(self, function(aceModule, playerChanged)
        aceModule:RefreshLoad(true)
        if playerChanged then
            aceModule:RefreshPlayerConditions()
        end
    end)
    NRSKNUI.AuraTriggers:RegisterCallback(self, function(aceModule) aceModule:ReapplyAuraTriggers() end)

    self:ApplySettings()
end

function CDM:OnDisable()
    if self.db.HideBlizzard then
        self:SetBlizzardViewers(false)
    end

    self:UnregisterTriggerEvents()
    self.Catalogue:UnregisterEvents()
    LoadConditions:UnregisterCallback(self)
    NRSKNUI.AuraTriggers:UnregisterCallback(self)

    self:ReleaseAll()
end

function CDM:ReleaseAll()
    for id in pairs(self.icons) do
        self:Release(id)
    end
    for id in pairs(self.containers) do
        self:Release(id)
    end
    self:ReleaseAuraGroups()
end

-- Build --

---@param frame CDMIcon
local function DetachFromGroup(frame)
    local group = frame.groupId and CDM.containers[frame.groupId]
    ---@cast group NRSKNUI.DynamicGroup?
    if group then
        group:DetachChild(frame)
    end
    frame.groupId = nil
end

---@param id string
function CDM:BuildIcon(id)
    -- Disabled displays keep a frame too, hidden, but the options page can still preview them.
    local display = self:Get(id)
    if not display then
        return self:Release(id)
    end

    -- Adding a group's first aura trigger or removing its last one swaps the group's layout.
    local parentFrame = display.parent and self.containers[display.parent]
    if display.parent and not parentFrame then
        self:BuildContainer(display.parent)
    elseif parentFrame and self:IsDynamic(display.parent) and (parentFrame.isChain == true) ~= self:WantsChain(display.parent) then
        return self:ApplySettings(display.parent) -- the swap detaches every icon in the group, so all of them rebuild
    end

    local frame = self.icons[id]
    if not frame then
        frame = self:AcquireIcon(id)
        self.icons[id] = frame
    end

    if frame.groupId ~= display.parent then
        DetachFromGroup(frame)
    end

    frame.style = self:GetStyle(display)
    self:StyleIcon(frame, display, frame.style)

    if self:IsDynamic(display.parent) then
        local group = self.containers[display.parent]
        ---@cast group NRSKNUI.DynamicGroup
        if frame.groupId ~= display.parent then
            group:AttachChild(frame, id, display.order)
            frame.groupId = display.parent
            frame:Show()
        end
        group:SetChildOrder(id, display.order or 0)
        group:NotifyChildResized(id, frame.style.Width, frame.style.Height)
        Anchors:Unregister(id)
    else
        self:Place(frame, id, display)
    end

    -- After joining its group: an aura button the client creates while resolving is only reachable then, before it locks.
    self:ResolveTriggers(frame, display)
end

local RESOLVE_BUDGET = 1 -- ms per frame; every display at once was a ~25 ms freeze when combat ended
local resolveQueue, resolveNext = {}, 1
local resolveFrame ---@type Frame?

---@param self Frame
local function ResolveStep(self)
    if CDM.inCombat then return end -- an override swap in combat is already resolved per spell; the rest waits

    local start = debugprofilestop()
    while resolveNext <= #resolveQueue do
        local id = resolveQueue[resolveNext]
        resolveNext = resolveNext + 1
        local frame, display = CDM.icons[id], CDM:Get(id)
        if frame and display then
            CDM:ResolveTriggers(frame, display)
            CDM:UpdateIcon(id)
        end
        if debugprofilestop() - start >= RESOLVE_BUDGET then return end
    end

    self:Hide()
    CDM:RefreshLoad(true)
end

---Re-resolve every display's triggers, for spell changes (talents, overrides, icons), a few each frame.
function CDM:ResolveAll()
    wipe(resolveQueue)
    for id in pairs(self.icons) do
        resolveQueue[#resolveQueue + 1] = id
    end
    resolveNext = 1

    if not resolveFrame then
        resolveFrame = CreateFrame('Frame')
        resolveFrame:SetScript('OnUpdate', ResolveStep)
    end
    resolveFrame:Show()
end

---@param id string
function CDM:Release(id)
    local frame = self.icons[id]
    if frame then
        self:UnwatchIcon(id)
        DetachFromGroup(frame)
        self:ReleaseIcon(frame)
        self.icons[id] = nil
    end

    local container = self.containers[id]
    if container then
        container:Hide()
        container:ClearAllPoints()
        container.onLayout = nil
        self.containers[id] = nil

        local spare = container.isChain and self.spareChain or container.SetConfig and self.spareDynamic or self.spareStatic
        spare[#spare + 1] = container
        self:PlaceMatchedBars(id)
    end

    self:ReleaseAuraGroup(id)
    Anchors:Unregister(id)
end

-- Load state --

---Whether any of a display's triggers is known: the one load input a spell learned or lost in combat changes.
---@param display table
---@return boolean
function CDM:IsDisplayKnown(display)
    for _, trigger in ipairs(display.Triggers) do
        local triggerType = self.TriggerTypes[trigger.Type]
        if triggerType and triggerType.IsKnown(trigger) then return true end
    end
    return false
end

---Whether a known trigger appeared or went away since the last load refresh.
---@return boolean
function CDM:KnownChanged()
    for id, frame in pairs(self.icons) do
        local display = self:Get(id)
        if display and self:IsDisplayKnown(display) ~= frame.known then return true end
    end
    return false
end

---Standby when only situational load conditions fail, unloaded when a hard one does; a group takes the best state inside it.
---@param id string
---@return 'loaded'|'standby'|'unloaded'
---@return string? reason why a single display is not loaded, for the debug report
function CDM:GetLoadState(id)
    local display = self:Get(id)
    if not display then
        return 'unloaded', 'missing'
    end
    if not display.Enabled then
        return 'unloaded', 'disabled'
    end

    if self:IsGroup(id) then
        local best
        for _, leafId in ipairs(self:GetLeaves(id)) do
            local state = self:GetLoadState(leafId)
            if not best or STATE_RANK[state] > STATE_RANK[best] then
                best = state
            end
        end
        return best or 'loaded'
    end

    for _, ancestor in ipairs(self:GetAncestors(id)) do
        if not self:Get(ancestor).Enabled then
            return 'unloaded', format("group '%s' disabled", self:GetName(ancestor))
        end
    end

    if self.LAYERED_TYPES[display.type] and not self:IsDisplayKnown(display) then
        return 'unloaded', 'no trigger is known'
    end

    local hard, hardFailed = LoadConditions:Check(display.Load, true)
    if not hard then
        return 'unloaded', 'load condition ' .. tostring(hardFailed)
    end

    local situational, failed = LoadConditions:Check(display.Load)
    if not situational then
        return 'standby', 'load condition ' .. tostring(failed)
    end

    return 'loaded'
end

-- Preview --

CDM.previewPages = 'cooldownManager'

-- Opening the page previews every loaded display at level 1.
function CDM:ShowPreview()
    self.previewing = true
    for id, display in pairs(self.db.Displays) do
        if (self.icons[id] or display.type == 'auragroup') and (self.preview[id] or 0) == 0 and self:GetLoadState(id) == 'loaded' then
            self.preview[id] = 1
        end
    end

    self:RefreshLoad()
end

function CDM:HidePreview()
    self.previewing = false
    for id, level in pairs(self.preview) do
        if level == 1 then
            self.preview[id] = nil
        end
    end
    wipe(self.selectionPreview)

    self:RefreshLoad()
end

---@param id string
---@return string[]
function CDM:GetPreviewTargets(id)
    if self:IsGroup(id) then
        return self:GetLeaves(id)
    end

    return { id }
end

---@param id string
---@return number level 0 hidden, 1 shown by selection or partly (a group), 2 pinned by the eye
function CDM:GetPreview(id)
    if not self:IsGroup(id) then
        return self.preview[id] or 0
    end

    local pinned, hidden, total = 0, 0, 0
    for _, iconId in ipairs(self:GetLeaves(id)) do
        local level = self.preview[iconId] or 0
        total = total + 1
        if level == 2 then
            pinned = pinned + 1
        elseif level == 0 then
            hidden = hidden + 1
        end
    end

    if total == 0 or hidden == total then
        return 0
    end

    return pinned == total and 2 or 1
end

---Pin or clear the preview of a display or of every display in a group.
---@param id string
---@param level number
function CDM:SetPreview(id, level)
    for _, iconId in ipairs(self:GetPreviewTargets(id)) do
        self.preview[iconId] = level
    end

    self:RefreshLoad()
end

---The selected display previews at level 1; the previous selection drops back unless it was pinned.
---@param id string?
function CDM:SetSelectionPreview(id)
    for _, key in ipairs(self.selectionPreview) do
        if self.preview[key] == 1 then
            self.preview[key] = nil
        end
    end
    wipe(self.selectionPreview)

    if id and self:Get(id) then
        for _, iconId in ipairs(self:GetPreviewTargets(id)) do
            if (self.preview[iconId] or 0) == 0 then
                self.preview[iconId] = 1
                self.selectionPreview[#self.selectionPreview + 1] = iconId
            end
        end
    end

    self:RefreshLoad()
end

---@param id string
---@return boolean
function CDM:IsPreviewed(id)
    return self.previewing == true and (self.preview[id] or 0) > 0
end

-- Visibility --

---Show what's loaded or only what's previewed while the options are open; hidden displays stop updating.
---@param changedOnly boolean? rebuild only what just loaded: load and bag changes, where a display that stayed loaded is already current
function CDM:RefreshLoad(changedOnly)
    local previewing = self.previewing
    local shown = {}
    for id, display in pairs(self.db.Displays) do
        if self.icons[id] or display.type == 'auragroup' then
            if previewing then
                shown[id] = self:IsPreviewed(id)
            else
                shown[id] = self:GetLoadState(id) == 'loaded'
            end
        end
    end

    -- A container shows while anything under it does.
    local childIndex = self:GetChildrenIndex()
    local function AnyShown(id)
        local children = childIndex[id]
        if not children then return false end

        for _, child in ipairs(children) do
            if shown[child.key] or AnyShown(child.key) then return true end
        end
        return false
    end

    for id, container in pairs(self.containers) do
        container:SetShown(AnyShown(id))
    end

    for id, frame in pairs(self.icons) do
        local display = self:Get(id)
        frame.known = display ~= nil and self:IsDisplayKnown(display)
        if not changedOnly or (frame.shown == true) ~= (shown[id] == true) then
            frame.shown = shown[id]
            if shown[id] then
                self:UpdateIcon(id)
            else
                self:ApplyVisibility(id, frame)
            end
        end
    end
    self:RefreshAuraGroups()

    -- Tell what follows the CDM: whoever anchors to it, the options page and Blizzard's viewers.
    self:SendMessage('NRSKNUI_CDM_LAYOUT_CHANGED')
    if self.onStateChanged then
        self.onStateChanged()
    end
    self:SyncBlizzardViewers()
end

---The shown dynamic groups carrying the unit frame anchor roles; the first in tree order wins.
---@return Frame? primary, Frame? secondary
function CDM:GetAnchorGroups()
    local found = {}
    local function Walk(entries)
        for _, entry in ipairs(entries) do
            local display = self:Get(entry.key)
            local container = self.containers[entry.key]
            if display.UFAnchor and not found[display.UFAnchor] and container and container:IsShown() then
                found[display.UFAnchor] = container
            end
            if display.type == 'group' then
                Walk(self:GetChildren(entry.key))
            end
        end
    end

    Walk(self:GetRoots())

    if not found.primary then
        return found.secondary -- a lone secondary takes the primary role
    end

    return found.primary, found.secondary
end

-- Apply settings --

---@param id string
local function ApplySubtree(id)
    if CDM:IsGroup(id) then
        CDM:BuildContainer(id)
        for _, child in ipairs(CDM:GetChildren(id)) do
            ApplySubtree(child.key)
        end
    elseif CDM:IsAuraGroup(id) then
        CDM:BuildAuraGroup(id)
    else
        CDM:BuildIcon(id)
    end
end

---@param id string? nil applies every display
function CDM:ApplySettings(id)
    if not self:IsEnabled() then return end

    if id then
        ApplySubtree(id)
    else
        -- Parents before children, so every display finds the frame it hangs off.
        local containers = {}
        for key in pairs(self.db.Displays) do
            if self:IsGroup(key) then
                containers[#containers + 1] = key
            end
        end

        tsort(containers, function(a, b)
            return self:GetDepth(a) < self:GetDepth(b)
        end)
        for _, key in ipairs(containers) do
            self:BuildContainer(key)
        end

        for key, display in pairs(self.db.Displays) do
            if self.LAYERED_TYPES[display.type] then
                self:BuildIcon(key)
            elseif display.type == 'auragroup' then
                self:BuildAuraGroup(key)
            end
        end
    end

    self:RefreshLoad()
end

-- Blizzard frames --

---@param viewer table
local function ApplyViewerVisibility(viewer)
    viewer:SetAlpha(hideViewers and 0 or 1)
    viewer:EnableMouse(not hideViewers)
end

---Whether a loaded or standby display reads a Cooldown Manager bar, which keeps Blizzard's viewers running.
---@return boolean
function CDM:UsesViewerBar()
    for id, display in pairs(self.db.Displays) do
        if display.type == 'bar' and self:GetLoadState(id) ~= 'unloaded' then
            for _, trigger in ipairs(display.Triggers) do
                if trigger.Type == 'viewerbar' then return true end
                if trigger.Type == 'power' and trigger.Mode == 'progress' and trigger.ProgressCooldownID then return true end
            end
        end
    end
    return false
end

---Re-evaluate whether the hidden viewers must keep running, after displays load or unload.
function CDM:SyncBlizzardViewers()
    if self.db.HideBlizzard and self:UsesViewerBar() ~= hideViewers then
        self:SetBlizzardViewers(true)
    end
end

---Hide Blizzard's Cooldown Manager: turned off or only faded out while a display reads its bars (an off viewer stops updating).
---@param hide boolean
function CDM:SetBlizzardViewers(hide)
    local keepRunning = hide and self:UsesViewerBar()
    hideViewers = keepRunning

    NRSKNUI:RunWhenSafe(function()
        SetCVar('cooldownViewerEnabled', (hide and not keepRunning) and '0' or '1')

        for _, name in ipairs(BLIZZARD_VIEWERS) do
            local viewer = _G[name]
            if viewer then
                if not hookedViewers[viewer] then
                    hookedViewers[viewer] = true
                    -- Blizzard fades the viewers itself from its visibility and combat settings
                    hooksecurefunc(viewer, 'SetAlpha', function(bar, alpha)
                        if hideViewers and alpha ~= 0 then
                            bar:SetAlpha(0)
                        end
                    end)
                end
                ApplyViewerVisibility(viewer)
            end
        end
    end)
end

function CDM:HidePlayerCastBar()
    NRSKNUI:RunWhenSafe(function()
        PlayerCastingBarFrame:NUIBanish()
    end)
end

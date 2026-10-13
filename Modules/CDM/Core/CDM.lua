---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local Anchors = NRSKNUI.Anchors
local LoadConditions = NRSKNUI.LoadConditions

local tsort = table.sort
local pairs, ipairs = pairs, ipairs
local format = string.format
local tostring = tostring
local wipe = wipe

local SetCVar = C_CVar and C_CVar.SetCVar

local GUI_PAGE = 'cooldownManager'

function CDM:UpdateDB()
    local db = NRSKNUI.db.profile.CDM
    -- Frames are keyed by display id, and another profile reuses the same ids for other displays.
    if self.icons and self.db ~= db then
        self:ReleaseAll()
        wipe(self.preview)
        wipe(self.selectionPreview)
    end
    self.db = db
    self:Migrate(db)
    self:EnsureUids()
end

function CDM:OnInitialize()
    self:UpdateDB()
    self.icons = {} ---@type table<string, CDMIcon>
    self.containers = {} ---@type table<string, Frame|NRSKNUI.DynamicGroup>
    self.spareStatic = {} ---@type Frame[]
    self.spareDynamic = {} ---@type NRSKNUI.DynamicGroup[]
    self.spareChain = {} ---@type CDMChainGroup[]
    self.preview = {} ---@type table<string, number>
    self.selectionPreview = {} ---@type string[]
end

-- Icons --

---@param frame CDMIcon
local function DetachFromGroup(frame)
    local group = frame.groupId and CDM.containers[frame.groupId]
    ---@cast group NRSKNUI.DynamicGroup?
    if group then group:DetachChild(frame) end
    frame.groupId = nil
end

---@param id string
function CDM:BuildIcon(id)
    -- Disabled displays keep a frame too: hidden, but the options page can still preview them.
    local display = self:Get(id)
    if not display then return self:Release(id) end
    local parentFrame = display.parent and self.containers[display.parent]
    -- A first aura trigger in a group, or its last one gone, swaps the group's layout.
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

    if frame.groupId ~= display.parent then DetachFromGroup(frame) end
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

---Re-resolve every icon's trigger, for spell changes (talents, overrides, icons).
function CDM:ResolveAll()
    for id, frame in pairs(self.icons) do
        self:ResolveTriggers(frame, self:Get(id))
    end
    self:RefreshLoad()
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

local STATE_RANK = { loaded = 3, standby = 2, unloaded = 1 }

---WeakAuras' three states: loaded, standby when only situational conditions fail, unloaded when
---a hard one does (disabled, unknown spell, a role that can't change mid-fight). A group takes the
---best state of the icons inside it.
---@param id string
---@return 'loaded'|'standby'|'unloaded'
---@return string? reason why a single display isn't loaded, for the debug report
function CDM:GetLoadState(id)
    local display = self:Get(id)
    if not display then return 'unloaded', 'missing' end
    if not display.Enabled then return 'unloaded', 'disabled' end

    if self:IsGroup(id) then
        local best
        for _, leafId in ipairs(self:GetLeaves(id)) do
            local state = self:GetLoadState(leafId)
            if not best or STATE_RANK[state] > STATE_RANK[best] then best = state end
        end
        return best or 'loaded'
    end

    for _, ancestor in ipairs(self:GetAncestors(id)) do
        if not self:Get(ancestor).Enabled then return 'unloaded', format("group '%s' disabled", self:GetName(ancestor)) end
    end
    if self.LAYERED_TYPES[display.type] then
        local known = false
        for _, trigger in ipairs(display.Triggers) do
            local triggerType = self.TriggerTypes[trigger.Type]
            if triggerType and triggerType.IsKnown(trigger) then
                known = true
                break
            end
        end
        if not known then return 'unloaded', 'no trigger is known' end
    end
    local hard, hardFailed = LoadConditions:Check(display.Load, true)
    if not hard then return 'unloaded', 'load condition ' .. tostring(hardFailed) end
    local situational, failed = LoadConditions:Check(display.Load)
    if not situational then return 'standby', 'load condition ' .. tostring(failed) end
    return 'loaded'
end

-- Previews: WeakAuras' visibility levels, 1 shown by selection, 2 pinned by the eye.

---@param id string
---@return string[]
function CDM:GetPreviewTargets(id)
    if self:IsGroup(id) then return self:GetLeaves(id) end
    return { id }
end

---@param id string
---@return number level 0 hidden, 1 shown by selection or partly (a group), 2 pinned
function CDM:GetPreview(id)
    if not self:IsGroup(id) then return self.preview[id] or 0 end

    local pinned, hidden, total = 0, 0, 0
    for _, iconId in ipairs(self:GetLeaves(id)) do
        local level = self.preview[iconId] or 0
        total = total + 1
        if level == 2 then pinned = pinned + 1 elseif level == 0 then hidden = hidden + 1 end
    end
    if total == 0 or hidden == total then return 0 end
    return pinned == total and 2 or 1
end

---Pin or clear the preview of an icon, or of every icon in a group.
---@param id string
---@param level number
function CDM:SetPreview(id, level)
    for _, iconId in ipairs(self:GetPreviewTargets(id)) do self.preview[iconId] = level end
    self:RefreshLoad()
end

---The selected display previews at level 1; the previous selection drops back unless it was pinned.
---@param id string?
function CDM:SetSelectionPreview(id)
    for _, key in ipairs(self.selectionPreview) do
        if self.preview[key] == 1 then self.preview[key] = nil end
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

---Show what is loaded and hide the rest; while the options page is open only previewed icons show,
---as WeakAuras pauses everything else. A group shows while anything inside it does. Hidden icons stop updating.
function CDM:RefreshLoad()
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

    for id, container in pairs(self.containers) do
        local any = false
        for _, iconId in ipairs(self:GetLeaves(id)) do
            if shown[iconId] then
                any = true
                break
            end
        end
        container:SetShown(any)
    end

    for id, frame in pairs(self.icons) do
        frame.shown = shown[id]
        if shown[id] then self:UpdateIcon(id) else self:ApplyVisibility(id, frame) end
    end
    self:RefreshAuraGroups()

    local UF = NRSKNUI.UnitFrames
    if UF:IsEnabled() then UF:ScheduleCDMAnchorUpdate() end
    if self.onStateChanged then self.onStateChanged() end
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
            if display.type == 'group' then Walk(self:GetChildren(entry.key)) end
        end
    end
    Walk(self:GetRoots())

    if not found.primary then return found.secondary end
    return found.primary, found.secondary
end

local BLIZZARD_VIEWERS = { 'EssentialCooldownViewer', 'UtilityCooldownViewer', 'BuffIconCooldownViewer', 'BuffBarCooldownViewer' }
local hideViewers = false
local hookedViewers = {} ---@type table<table, true>

---@param viewer table
local function ApplyViewerVisibility(viewer)
    viewer:SetAlpha(hideViewers and 0 or 1)
    viewer:EnableMouse(not hideViewers)
end

---Whether a display that can currently load follows a Cooldown Manager bar (a Cooldown Bar trigger, or a split power
---bar's Progress Source), which needs Blizzard's viewers running.
---A standby one (load conditions only briefly unmet, like combat) counts; a disabled or unloaded one doesn't.
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
    if self.db.HideBlizzard and self:UsesViewerBar() ~= hideViewers then self:SetBlizzardViewers(true) end
end

---Hide Blizzard's Cooldown Manager. It is turned fully off unless a Cooldown Bar trigger reads it; then it keeps
---running (a disabled viewer stops updating its frames) and is hidden by alpha instead.
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
                    -- Blizzard fades the viewers itself (visibility and combat settings)
                    hooksecurefunc(viewer, 'SetAlpha', function(self, alpha)
                        if hideViewers and alpha ~= 0 then self:SetAlpha(0) end
                    end)
                end
                ApplyViewerVisibility(viewer)
            end
        end
    end)
end

-- Banishing is one-way; turning the option off takes a reload.
function CDM:HidePlayerCastBar()
    NRSKNUI:RunWhenSafe(function() PlayerCastingBarFrame:NUIBanish() end)
end

CDM.previewPages = GUI_PAGE

-- Opening the page starts every loaded icon visible at level 1, as WeakAuras does on first open.
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
        if level == 1 then self.preview[id] = nil end
    end
    wipe(self.selectionPreview)
    self:RefreshLoad()
end

-- Apply --

---@param id string
local function ApplySubtree(id)
    if CDM:IsGroup(id) then
        CDM:BuildContainer(id)
        for _, child in ipairs(CDM:GetChildren(id)) do ApplySubtree(child.key) end
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
            if self:IsGroup(key) then containers[#containers + 1] = key end
        end
        tsort(containers, function(a, b) return self:GetDepth(a) < self:GetDepth(b) end)
        for _, key in ipairs(containers) do self:BuildContainer(key) end

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

function CDM:OnCatalogueChanged()
end

function CDM:OnEnable()
    if self.db.HideBlizzard then self:SetBlizzardViewers(true) end
    if self.db.HidePlayerCastBar then self:HidePlayerCastBar() end
    self:RegisterTriggerEvents()
    LoadConditions:RegisterCallback(self, function(module) module:RefreshLoad() end)
    NRSKNUI.AuraTriggers:RegisterCallback(self, function(module) module:ReapplyAuraTriggers() end)
    self:ApplySettings()
end

function CDM:OnDisable()
    if self.db.HideBlizzard then self:SetBlizzardViewers(false) end
    self:UnregisterTriggerEvents()
    LoadConditions:UnregisterCallback(self)
    NRSKNUI.AuraTriggers:UnregisterCallback(self)

    self:ReleaseAll()
end

function CDM:ReleaseAll()
    for id in pairs(self.icons) do self:Release(id) end
    for id in pairs(self.containers) do self:Release(id) end
    self:ReleaseAuraGroups()
end

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class DefensivesModule
local Defensives = NRSKNUI:GetModule('Defensives')
local Anchors = NRSKNUI.Anchors
local AuraPreview = NRSKNUI.AuraPreview

local CreateFrame = CreateFrame
local min = math.min

function Defensives:UpdateDB()
    self.db = NRSKNUI.db.profile.Defensives
end

function Defensives:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

---Layout anchor corner derived from growth direction.
local function AnchorCorner(cfg)
    local vertical = (cfg.verticalGrowthDirection == 'DOWN') and 'TOP' or 'BOTTOM'
    local horizontal = (cfg.horizontalGrowthDirection == 'LEFT') and 'RIGHT' or 'LEFT'
    return vertical .. horizontal
end

---The container config built from the current db. Shared by creation and live re-apply, so both
---always read the same settings.
---@return table
function Defensives:GetContainerConfig()
    local db = self.db

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
        fontDB = db,
        stackFont = db.StackFont,
        durationFont = db.DurationFont,
        tooltipHideInCombat = db.tooltipHideInCombat,
    }
end

---Most auras the current settings can put on screen.
---@return number
function Defensives:GetPreviewCount()
    local db = self.db
    return min(db.maxFrameCount * NRSKNUI:GetAuraFilterBranchCount(db.Filter), db.previewLimit)
end

---Size the host to the largest grid the current settings can produce, so the mover covers the display's
---full footprint.
function Defensives:ResizeHost()
    self.host:SetSize(NRSKNUI:GetAuraGridSize(self.db, self:GetPreviewCount()))
end

---Create the mover host frame, the container is attached later, out of combat.
function Defensives:CreateHost()
    if self.host then return end

    self.host = CreateFrame('Frame', 'NRSKNUI_Defensives', UIParent)
    self:ResizeHost()
end

---Attach the native aura container to a host.
function Defensives:BuildContainer()
    if not self.host or self.host.container then return end

    local config = self:GetContainerConfig()
    local container = self.host:CreateAuraContainer(config)
    if not container then return end

    container:ClearAllPoints()
    container:SetPoint(config.anchorPoint, self.host, config.anchorPoint)

    container:AddFilteredGroup(self.db.Filter)

    container:SetUnit('player')
    self.host.container = container

    AuraPreview:Attach(container, self.host, config.anchorPoint)
    AuraPreview:Update(container, config, self:GetPreviewCount(), self.db.Filter)
end

---Live-reapply the active filter when its definition changes in the GUI.
function Defensives:OnFilterChanged()
    local container = self.host and self.host.container
    if not container then return end

    self:ResizeHost() -- editing a filter can add or drop branches, which moves the worst case
    container:ReapplyFilters()
end

---Rebind the container to whichever named filter the db now points at.
function Defensives:ApplyFilter()
    local container = self.host and self.host.container
    if not container then return end

    self:ResizeHost()
    container:RebindFilteredGroups(self.db.Filter)
end

function Defensives:ApplySettings()
    self:ResizeHost()
    self.host:Show()
    self.host:NUIApplyPosition(self.db)
    Anchors:Register(self, 'Defensives', self.host, 'defensives')

    local container = self.host.container
    if container then
        -- Layout re-applies live, button appearance does not (see container:ApplyLayout).
        local config = self:GetContainerConfig()
        container:ClearAllPoints()
        container:SetPoint(config.anchorPoint, self.host, config.anchorPoint)
        container:ApplyLayout(config)
        AuraPreview:Attach(container, self.host, config.anchorPoint)
        AuraPreview:Update(container, config, self:GetPreviewCount(), self.db.Filter)
        return
    end

    NRSKNUI:RunWhenSafe(function()
        self:BuildContainer()
    end)
end

function Defensives:OnEnable()
    if not self.db.Enabled then return end

    self:CreateHost()
    self:ApplySettings()

    NRSKNUI.AuraFilters:RegisterCallback(self, function(module) module:OnFilterChanged() end)
end

function Defensives:OnDisable()
    NRSKNUI.AuraFilters:UnregisterCallback(self)

    if self.host then
        self.host:Hide()
    end
end

-- Previews. The real container swaps out for dummy auras, which are the only ones that can follow a
-- settings change without a reload.

function Defensives:ShowPreview()
    local container = self.host and self.host.container
    if not container then return end

    AuraPreview:SetShown(container, true)
    container:Hide()
end

function Defensives:HidePreview()
    local container = self.host and self.host.container
    if not container then return end

    AuraPreview:SetShown(container, false)
    container:Show()
end

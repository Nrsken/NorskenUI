---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AdvancedDebuffsModule
local AdvancedDebuffs = NRSKNUI:GetModule('AdvancedDebuffs')
local Anchors = NRSKNUI.Anchors
local AuraPreview = NRSKNUI.AuraPreview

local CreateFrame = CreateFrame
local min = math.min

function AdvancedDebuffs:UpdateDB()
    self.db = NRSKNUI.db.profile.AdvancedDebuffs
end

function AdvancedDebuffs:OnInitialize()
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
function AdvancedDebuffs:GetContainerConfig()
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
        showDebuffBorder = db.showBorder or nil,
        showWithoutDispelType = db.showBorderWithoutDispelType,
        fontDB = db,
        stackFont = db.StackFont,
        durationFont = db.DurationFont,
        tooltipHideInCombat = db.tooltipHideInCombat,
        showDebuffDispelIcon = db.showDebuffDispelIcon,
        dispelIconSize = db.dispelIconSize,
    }
end

---Most auras the current settings can put on screen.
---@return number
function AdvancedDebuffs:GetPreviewCount()
    local db = self.db
    return min(db.maxFrameCount * NRSKNUI:GetAuraFilterBranchCount(db.Filter), db.previewLimit)
end

---Size the host to the largest grid the current settings can produce, so the mover covers the display's
---full footprint.
function AdvancedDebuffs:ResizeHost()
    self.host:SetSize(NRSKNUI:GetAuraGridSize(self.db, self:GetPreviewCount()))
end

---Create the mover host frame, the container is attached later, out of combat.
function AdvancedDebuffs:CreateHost()
    if self.host then return end

    self.host = CreateFrame('Frame', 'NRSKNUI_PlayerAdvancedDebuffs', UIParent)
    self:ResizeHost()
end

---Attach the native aura container to a host.
function AdvancedDebuffs:BuildContainer()
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
function AdvancedDebuffs:OnFilterChanged()
    local container = self.host and self.host.container
    if not container then return end

    self:ResizeHost() -- editing a filter can add or drop branches, which moves the worst case
    container:ReapplyFilters()
end

---Rebind the container to whichever named filter the db now points at.
function AdvancedDebuffs:ApplyFilter()
    local container = self.host and self.host.container
    if not container then return end

    self:ResizeHost()
    container:RebindFilteredGroups(self.db.Filter)
end

function AdvancedDebuffs:ApplySettings()
    self:ResizeHost()
    self.host:Show()
    self.host:NUIApplyPosition(self.db)
    Anchors:Register(self, 'AdvancedDebuffs', self.host, 'advancedDebuffs')

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

function AdvancedDebuffs:OnEnable()
    if not self.db.Enabled then return end

    self:CreateHost()
    self:ApplySettings()

    NRSKNUI.AuraFilters:RegisterCallback(self, function(module) module:OnFilterChanged() end)
end

function AdvancedDebuffs:OnDisable()
    NRSKNUI.AuraFilters:UnregisterCallback(self)

    if self.host then
        self.host:Hide()
    end
end

-- Previews. The real container swaps out for dummy auras, which are the only ones that can follow a
-- settings change without a reload.

function AdvancedDebuffs:ShowPreview()
    local container = self.host and self.host.container
    if not container then return end

    AuraPreview:SetShown(container, true)
    container:Hide()
end

function AdvancedDebuffs:HidePreview()
    local container = self.host and self.host.container
    if not container then return end

    AuraPreview:SetShown(container, false)
    container:Show()
end

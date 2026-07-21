---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AdvancedDebuffs
local AdvancedDebuffs = NRSKNUI:GetModule('AdvancedDebuffs')
local EM = NRSKNUI.EditMode

local CreateFrame = CreateFrame

function AdvancedDebuffs:UpdateDB()
    self.db = NRSKNUI.db.profile.AdvancedDebuffs
end

function AdvancedDebuffs:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

---Layout anchor corner derived from growth direction.
local function AnchorCorner(cfg)
    local vertical = (cfg.GrowthY == 'DOWN') and 'TOP' or 'BOTTOM'
    local horizontal = (cfg.GrowthX == 'LEFT') and 'RIGHT' or 'LEFT'
    return vertical .. horizontal
end

---Create the mover host frame for a kind, the container is attached later, out of combat.
function AdvancedDebuffs:CreateHost()
    if self.host then return end

    local host = CreateFrame('Frame', 'NRSKNUI_PlayerAdvancedDebuffs', UIParent)
    local cellW = self.db.Size + (self.db.SpacingX or 0)
    local cellH = self.db.Size + (self.db.SpacingY or 0)
    host:SetSize(self.db.PerRow * cellW, 3 * cellH)

    self.host = host
end

---Attach the native aura container to a host.
function AdvancedDebuffs:BuildContainer()
    if not self.host or self.host.container then return end
    local corner = AnchorCorner(self.db)

    local container = self.host:CreateAuraContainer({
        maxWidth = self.db.PerRow * (self.db.Size + (self.db.SpacingX or 0)),
        initialAnchor = corner,
        growthX = self.db.GrowthX,
        growthY = self.db.GrowthY,
        size = self.db.Size,
        spacingX = self.db.SpacingX,
        spacingY = self.db.SpacingY,
        num = self.db.Max,
        showCount = self.db.ShowCount,
        showDuration = self.db.ShowDuration,
        showSwipe = self.db.ShowSwipe,
        showEdge = self.db.ShowEdge,
        reverseSwipe = self.db.ReverseSwipe,
        showDebuffBorder = self.db.ShowBorder or nil,
        fontSize = self.db.FontSize,
        fontOutline = self.db.FontOutline,
    })
    if not container then return end

    container:ClearAllPoints()
    container:SetPoint(corner, self.host, corner)

    container:AddFilteredGroup(self.db.Filter)

    container:SetUnit('player')
    self.host.container = container
end

---Live-reapply the active filter when its definition changes in the GUI.
function AdvancedDebuffs:OnFilterChanged()
    local container = self.host and self.host.container
    if not container then return end

    if not container:ReapplyFilters() then
        NRSKNUI:RunWhenSafe(function()
            local c = self.host and self.host.container
            if c then c:ReapplyFilters() end
        end)
    end
end

function AdvancedDebuffs:ApplySettings()
    self.host:Show()
    self.host:ApplyPosition(self.db)
    EM:Register(self, 'PlayerAdvancedDebuffs', self.host, 'advancedDebuffs')

    NRSKNUI:RunWhenSafe(function()
        self:BuildContainer()
    end)
end

function AdvancedDebuffs:OnEnable()
    if not self.db.Enabled then return end

    self:CreateHost()
    self:ApplySettings()

    NRSKNUI.AuraFilters:RegisterCallback(self, function(module) module:OnFilterChanged() end)

    NRSKNUI:RunWhenSafe(function()
        _G.BuffFrame:Banish()
        _G.DebuffFrame:Banish()
    end)
end

function AdvancedDebuffs:OnDisable()
    NRSKNUI.AuraFilters:UnregisterCallback(self)

    if self.host then
        self.host:Hide()
    end
end

-- Previews, calling the aura data provider API's while in Blizzard Edit Mode can cause some errors so return early if that's the case.

function AdvancedDebuffs:ShowPreview()
    if not self.db.Enabled or not self.host or NRSKNUI:IsEditModeActive() then return end
    C_UnitAuras.SwitchAuraDataProvider()
end

function AdvancedDebuffs:HidePreview()
    if not self.host or NRSKNUI:IsEditModeActive() then return end
    C_UnitAuras.ResetAuraDataProvider()
end

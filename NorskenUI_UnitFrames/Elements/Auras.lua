---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF
local AuraPreview = NRSKNUI.AuraPreview

local pairs = pairs
local ipairs = ipairs
local min = math.min

local KINDS = { 'Buffs', 'Debuffs' }
-- Party and raid frames also get defensives; no other unit has the group at all.
local GROUP_KINDS = { 'Buffs', 'Debuffs', 'Defensives' }

---Most auras a container can put on screen.
---@param cfg table
---@return number
local function PreviewCount(cfg)
    return min(cfg.maxFrameCount * NRSKNUI:GetTriggerBranchCount(cfg.Trigger), cfg.previewLimit)
end

---Get the configuration table for a container, derived from the unit's aura config and the general unit frame config.
---@param cfg table one of uDB.Auras.Buffs / uDB.Auras.Debuffs
---@param general table UnitFrames General, supplies the button font
---@return table
local function GetContainerConfig(cfg, general)
    local pos = cfg.Position
    local flowCorner, containerPoint, horizontal, vertical =
        NRSKNUI:ResolveAuraGrowth(cfg.horizontalGrowthDirection, cfg.verticalGrowthDirection, pos.AnchorTo)
    -- Older saves keep the point they resolved to, written once so nothing moves.
    if not pos.AnchorFrom then pos.AnchorFrom = containerPoint end
    containerPoint = pos.AnchorFrom
    return {
        maximumLineSize = cfg.perRow * (cfg.size + cfg.elementSpacing),
        anchorPoint = flowCorner,
        containerPoint = containerPoint,
        horizontalGrowthDirection = horizontal,
        verticalGrowthDirection = vertical,
        size = cfg.size,
        elementSpacing = cfg.elementSpacing,
        lineSpacing = cfg.lineSpacing,
        maxFrameCount = cfg.maxFrameCount,
        sortMethod = AuraContainerSortMethod[cfg.sortMethod],
        sortDirection = AuraContainerSortDirection[cfg.sortDirection],
        showApplicationCount = cfg.showApplicationCount,
        showDurationText = cfg.showDurationText,
        durationTextColorCurve = true,
        drawSwipe = cfg.drawSwipe,
        drawEdge = cfg.drawEdge,
        reverseSwipe = cfg.reverseSwipe,
        showBuffBorder = cfg.showBorder or nil,
        showDebuffBorder = cfg.showBorder or nil,
        showWithoutDispelType = cfg.showBorderWithoutDispelType,
        showBuffDispelIcon = cfg.showDispelIcon or nil,
        showDebuffDispelIcon = cfg.showDispelIcon or nil,
        dispelIconSize = cfg.dispelIconSize,
        disableMouse = cfg.disableMouse,
        tooltipHideInCombat = cfg.tooltipHideInCombat,
        fontDB = general,
        stackFont = cfg.StackFont,
        durationFont = cfg.DurationFont,
    }
end

---@param frame oUF.UnitFrame
local function Update(frame)
    for _, container in pairs(frame.Auras) do
        container:SetUnit(frame.__unit) -- early-outs when the token is unchanged
        container:UpdateUnitGate()
        container:UpdateAllAuras()
    end
end

---@param frame oUF.UnitFrame
---@return boolean
local function Enable(frame)
    return frame.Auras ~= nil
end

---@param frame oUF.UnitFrame
local function Disable(frame)
    if not frame.Auras then return end

    for _, container in pairs(frame.Auras) do
        container:Hide()
    end
end

oUF:AddElement('NRSKNAuras', Update, Enable, Disable)

---Reapply every unit frame's aura filters, picking up branches added or removed in the filter builder.
---Wired to the AuraFilters callback in Core.lua.
function UF:ReapplyAuraFilters()
    for _, frame in pairs(UF.frames) do
        if frame.Auras then
            for _, container in pairs(frame.Auras) do
                container:ReapplyFilters()
            end
        end
    end
end

---@class UnitFramesElements
---@field Auras UnitFramesAurasElement
UF.Elements = UF.Elements or {}

---@class UnitFramesAurasElement
UF.Elements.Auras = {
    ---@param self oUF.UnitFrame
    ---@param unit string
    Construct = function(self, unit)
        if self.Auras then return end

        local uDB = UF.GetUnitDB(unit)
        local general = UF.db.General
        local containers = {}

        for _, kind in ipairs(UF.GroupConfigs[self.nuiConfig or unit] and GROUP_KINDS or KINDS) do
            local cfg = uDB.Auras[kind]
            local container = self:CreateAuraContainer(GetContainerConfig(cfg, general))
            if container then
                container:AddFilteredGroup(cfg.Trigger)
                containers[kind] = container
            end
        end

        self.Auras = containers
    end,

    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table
    Configure = function(self, unit, uDB, general)
        local containers = self.Auras
        if not containers then return end

        -- The health bar, not the frame, so auras never cover a docked power bar.
        local host = self.Health or self

        for kind, container in pairs(containers) do
            local cfg = uDB.Auras[kind]
            local pos = cfg.Position
            local config = GetContainerConfig(cfg, general)
            -- ApplyFrameLayers levels the container, the preview dummies take it from here.
            local level = UF.GetElementLevel(self, kind)

            -- Layout re-applies live, button appearance does not, see container:ApplyLayout.
            container:ClearAllPoints()
            container:SetPoint(config.containerPoint, host, pos.AnchorTo, pos.XOffset, pos.YOffset)
            container:ApplyLayout(config)
            container:RebindFilteredGroups(cfg.Trigger)
            -- self.__unit is the live token, which a preview repoints away from the configured unit.
            container:SetUnit(self.__unit or unit)
            if container:UpdateUnitGate() then container:UpdateAllAuras() end
            container:SetShown(cfg.Enabled)

            AuraPreview:Attach(container, host, pos.AnchorTo, pos.XOffset, pos.YOffset, level)
            AuraPreview:Update(container, config, PreviewCount(cfg), cfg.Trigger)
        end
    end,

    ---Preview the aura containers, showing the preview and hiding the live auras.
    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    Preview = function(self, unit, uDB)
        local containers = self.Auras
        if not containers then return end

        -- nuiConfig, not the token, a header child is styled with oUF's guessed archetype, which cannot tell the raid tiers apart.
        local preview = UF.Preview:IsAuraPreviewActive(self.nuiConfig or unit)

        for kind, container in pairs(containers) do
            local enabled = uDB.Auras[kind].Enabled
            AuraPreview:SetShown(container, preview and enabled)
            container:SetShown(enabled and not preview)
        end
    end,
}

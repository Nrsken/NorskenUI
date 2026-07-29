---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
---@field frames table<string, oUF.UnitFrame>
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF

local pairs = pairs
local ipairs = ipairs

local KINDS = { 'Buffs', 'Debuffs' }

---Layout anchor corner derived from growth direction.
---@param cfg table
---@return string
local function AnchorCorner(cfg)
    local vertical = (cfg.verticalGrowthDirection == 'DOWN') and 'TOP' or 'BOTTOM'
    local horizontal = (cfg.horizontalGrowthDirection == 'LEFT') and 'RIGHT' or 'LEFT'
    return vertical .. horizontal
end

---Get the configuration table for a container, derived from the unit's aura config and the general unit frame config.
---@param cfg table one of uDB.Auras.Buffs / uDB.Auras.Debuffs
---@param general table UnitFrames General, supplies the button font
---@return table
local function GetContainerConfig(cfg, general)
    return {
        maximumLineSize = cfg.perRow * (cfg.size + cfg.elementSpacing),
        anchorPoint = AnchorCorner(cfg),
        horizontalGrowthDirection = cfg.horizontalGrowthDirection,
        verticalGrowthDirection = cfg.verticalGrowthDirection,
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
        container:SetUnit(frame.unit) -- early-outs when the token is unchanged
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

UF.Elements = UF.Elements or {}
UF.Elements.Auras = {
    Construct = function(frame, unit)
        if frame.Auras then return end

        local uDB = UF.GetUnitDB(unit)
        local general = UF.db.General
        local containers = {}

        for _, kind in ipairs(KINDS) do
            local cfg = uDB.Auras[kind]
            local container = frame:CreateAuraContainer(GetContainerConfig(cfg, general))
            if container then
                container:AddFilteredGroup(cfg.Filter)
                containers[kind] = container
            end
        end

        frame.Auras = containers
    end,

    Configure = function(frame, unit, uDB, general)
        local containers = frame.Auras
        if not containers then return end

        for kind, container in pairs(containers) do
            local cfg = uDB.Auras[kind]
            local pos = cfg.Position
            local config = GetContainerConfig(cfg, general)

            -- Layout re-applies live, button appearance does not, see container:ApplyLayout.
            container:ClearAllPoints()
            container:SetPoint(config.anchorPoint, frame, pos.AnchorTo, pos.XOffset, pos.YOffset)
            container:ApplyLayout(config)
            container:RebindFilteredGroups(cfg.Filter)
            container:SetUnit(unit)
            container:SetShown(cfg.Enabled)
        end
    end,
}

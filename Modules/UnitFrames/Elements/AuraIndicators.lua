---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
---@field Elements UnitFramesElements
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF
local AuraIndicators = NRSKNUI.AuraIndicators
local AuraPreview = NRSKNUI.AuraPreview

local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs

---Resolve an indicator's attach target to a region on this frame.
---@param frame oUF.UnitFrame
---@param attach string
---@return Region?
local function ResolveAttach(frame, attach)
    local targets = AuraIndicators.Attach

    if attach == targets.Health then
        return frame.Health
    elseif attach == targets.HealthFill then
        return frame.Health and frame.Health:GetStatusBarTexture()
    end

    return frame
end

---Point a handle's proxy at its attach target.
---@param frame oUF.UnitFrame
---@param handle table
---@param placement table
---@return boolean anchored
local function AnchorProxy(frame, handle, placement)
    local target = ResolveAttach(frame, placement.Attach)
    if not target then return false end

    local proxy = handle.proxy
    proxy:ClearAllPoints()

    if AuraIndicators.Sized[placement.Style] then
        local pos = placement.Position
        proxy:NUISetPixelSize(placement.Size.Width, placement.Size.Height)
        proxy:NUISetPixelPoint(pos.AnchorFrom, target, pos.AnchorTo, pos.XOffset, pos.YOffset)
    else
        -- Everything else covers the target.
        proxy:SetAllPoints(target)
    end

    return true
end

---@param frame oUF.UnitFrame
local function Update(frame)
    local container = frame.nuiAuraIndicatorContainer
    if not container then return end

    -- A healthFill attach resolves to nothing until Health's Configure has built the fill, so retry here
    -- until it takes rather than leaving the indicator anchored to nothing.
    for _, handle in ipairs(frame.nuiAuraIndicators) do
        if not handle.anchored then
            handle.anchored = AnchorProxy(frame, handle, handle.placement)
        end
    end

    container:SetUnit(frame.unit) -- early-outs when the token is unchanged
    container:UpdateUnitGate()
    container:UpdateAllAuras()
end

---Enable the element on a frame.
---@param frame oUF.UnitFrame
---@return boolean
local function Enable(frame)
    return true
end

---@param frame oUF.UnitFrame
local function Disable(frame)
    if frame.nuiAuraIndicatorContainer then frame.nuiAuraIndicatorContainer:Hide() end
end

oUF:AddElement('NRSKNAuraIndicators', Update, Enable, Disable)

---@param handles table
---@param placement table
---@return table? handle
local function FindHandle(handles, placement)
    for _, handle in ipairs(handles) do
        if handle.placement == placement then
            return handle
        end
    end
end

---Bring a frame's slots in line with the placements configured on it.
---@param frame oUF.UnitFrame
---@param unit string
local function SyncIndicators(frame, unit)
    local placements = UF.GetUnitDB(unit).AuraIndicators
    local handles = frame.nuiAuraIndicators

    for _, placement in ipairs(placements) do
        -- A spot with nothing assigned yet costs nothing until it has something to show.
        if placement.Keys[1] then
            -- Deferred so a unit with no indicators never pays for a container.
            local container = frame.nuiAuraIndicatorContainer
            if not container then
                container = frame:CreateAuraContainer()
                frame.nuiAuraIndicatorContainer = container
            end

            if container then
                local handle = FindHandle(handles, placement)
                local proxy = handle and handle.proxy or CreateFrame('Frame', nil, frame)
                local level = UF.GetLayerLevel(frame, placement.Layer)
                local synced = NRSKNUI:SyncAuraIndicator(container, handle, placement, proxy, level, UF.db.General)

                if synced and not handle then
                    synced.placement = placement
                    handles[#handles + 1] = synced
                end
            end
        end
    end
end

---Re-read every frame's indicators. Wired to the AuraIndicators callback in Core.lua.
---Adding is live, removing is not, so a dropped indicator is only hidden until the next reload.
function UF:ReapplyAuraIndicators()
    NRSKNUI:RunWhenSafe(function()
        for unit, frame in pairs(UF.frames) do
            SyncIndicators(frame, unit)
            UF.Elements.AuraIndicators.Configure(frame, unit, UF.GetUnitDB(unit))
        end
    end)
end

---@class UnitFramesElements
---@field AuraIndicators UnitFramesAuraIndicatorsElement
UF.Elements = UF.Elements or {}

---@class UnitFramesAuraIndicatorsElement
UF.Elements.AuraIndicators = {
    ---@param self oUF.UnitFrame
    ---@param unit string
    Construct = function(self, unit)
        if self.nuiAuraIndicators then return end

        self.nuiAuraIndicators = {}
        SyncIndicators(self, unit)
    end,

    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    Configure = function(self, unit, uDB)
        if not self.nuiAuraIndicatorContainer then return end

        local live = {}
        for _, placement in ipairs(uDB.AuraIndicators) do
            live[placement] = true
        end

        for _, handle in ipairs(self.nuiAuraIndicators) do
            local placement = handle.placement

            if live[placement] then
                -- Per-slot visibility is Apply's job, since a placement can hold several indicators and only some of them may still be assigned.
                NRSKNUI:ApplyAuraIndicator(handle, placement)
                handle.anchored = AnchorProxy(self, handle, placement)
            else
                NRSKNUI:SetAuraIndicatorShown(handle, false)
            end
        end

        -- self.unit is the live token, which a preview repoints away from the configured unit.
        self.nuiAuraIndicatorContainer:SetUnit(self.unit or unit)
    end,

    ---Show dummies for the placement the GUI has open, hiding that placement's real slots.
    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    Preview = function(self, unit, uDB)
        local handles = self.nuiAuraIndicators
        if not handles then return end

        local previewed = UF.Preview:GetAuraIndicatorSlot(self.nuiConfig or unit)
        local placement = previewed and uDB.AuraIndicators[previewed]

        for _, handle in ipairs(handles) do
            -- An unpreviewable style keeps its real slots: taking them over would draw nothing.
            local on = placement ~= nil and handle.placement == placement
                and AuraIndicators.Previewable[placement.Style] == true

            if on then
                AuraPreview:UpdateIndicator(handle, placement, UF.GetLayerLevel(self, placement.Layer), UF.db.General)
                NRSKNUI:SetAuraIndicatorShown(handle, false)
            elseif handle.nuiPreview then
                NRSKNUI:ApplyAuraIndicator(handle, handle.placement) -- back to what Configure settled on
            end

            AuraPreview:SetIndicatorShown(handle, on)
        end
    end,
}

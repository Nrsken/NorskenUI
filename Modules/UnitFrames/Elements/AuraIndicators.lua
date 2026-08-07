---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF
local AuraIndicators = NRSKNUI.AuraIndicators
local AuraPreview = NRSKNUI.AuraPreview

local CreateFrame = CreateFrame
local ipairs = ipairs
local wipe = wipe

-- Which placements should be previewing, rebuilt from scratch on every Preview pass. Shared because
-- nothing a pass calls reaches back into one.
local previewing = {}

---Point a handle's proxy at its attach target.
---@param frame oUF.UnitFrame
---@param handle table
---@param placement table
---@return boolean anchored
local function AnchorProxy(frame, handle, placement)
    local target = UF.ResolveAttachTarget(frame, placement.Attach)
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

    for _, handle in ipairs(frame.nuiAuraIndicators) do
        if not handle.anchored then
            handle.anchored = AnchorProxy(frame, handle, handle.placement)
        end
    end

    container:SetUnit(frame.unit) -- early-outs when the token is unchanged
    container:UpdateUnitGate()
    container:UpdateAllAuras()
end

---@param frame oUF.UnitFrame
---@return boolean
local function Enable(frame) return true end

---@param frame oUF.UnitFrame
local function Disable(frame) if frame.nuiAuraIndicatorContainer then frame.nuiAuraIndicatorContainer:Hide() end end

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
        if placement.Keys[1] then
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

---Re-read every frame's indicators. Wired to the AuraIndicators callback in Core.lua, so every edit
---the GUI makes lands here.
---A real slot is a native aura button the client builds once, so adding one is live and restyling or
---dropping one waits for a reload. A preview is ours end to end, so it follows every edit immediately.
function UF:ReapplyAuraIndicators()
    local element = UF.Elements.AuraIndicators

    NRSKNUI:RunWhenSafe(function()
        UF:ForEachFrame(function(frame, unit)
            local uDB = UF.GetUnitDB(unit)

            SyncIndicators(frame, unit)
            element.Configure(frame, unit, uDB)
            element.Preview(frame, unit, uDB)
        end)
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

    ---Show dummies while the GUI has the unit's aura indicator section open, hiding the real slots they
    ---stand in for. Always runs straight after Configure, which is what settles every handle, so a
    ---placement that stops being previewed is already back where it belongs by the time this sees it.
    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    Preview = function(self, unit, uDB)
        local handles = self.nuiAuraIndicators
        if not handles then return end

        local selected = UF.Preview:GetAuraIndicatorTab(self.nuiConfig or unit)
        wipe(previewing)

        if selected then
            for index, placement in ipairs(uDB.AuraIndicators) do
                -- A tint covers its attach target whole, so several at once are just a wash: a tint
                -- previews on its own tab alone, everything else previews together to show the layout.
                local solo = AuraIndicators.FullCover[placement.Style]

                if AuraIndicators.Previewable[placement.Style] and (not solo or index == selected) then
                    previewing[placement] = true
                end
            end
        end

        for _, handle in ipairs(handles) do
            local placement = handle.placement
            -- A deleted placement keeps its handle until the next reload, and is never in the set.
            local on = previewing[placement] == true

            if on then
                AuraPreview:UpdateIndicator(handle, placement, UF.GetLayerLevel(self, placement.Layer), UF.db.General)
                NRSKNUI:SetAuraIndicatorShown(handle, false)
            end

            AuraPreview:SetIndicatorShown(handle, on)
        end
    end,
}

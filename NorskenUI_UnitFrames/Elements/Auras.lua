---@class NorskenUI
local NRSKNUI = _G.NorskenUI
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF

local pairs, ipairs = pairs, ipairs
local CopyTable = CopyTable

local KINDS = { 'Buffs', 'Debuffs' }
-- Party and raid frames also get defensives; no other unit has the group at all.
local GROUP_KINDS = { 'Buffs', 'Debuffs', 'Defensives' }

-- Look --

---A kind's settings ready to draw or edit: elements seeded, style read through its template.
---@param cfg table
---@param kind string
---@return table style
function UF.PrepareAuras(cfg, kind)
    return NRSKNUI:PrepareAuraGroup(cfg, function()
        local seed = CopyTable(UF.AuraLooks[kind])
        seed.font = UF.AuraFont(UF.db.General)
        return seed
    end)
end

-- Element --

---@param frame oUF.UnitFrame
local function Update(frame)
    -- a roster change can point the same token at someone else
    for _, holder in pairs(frame.Auras) do
        holder.display:SetUnit(frame.__unit)
        holder.display:Refresh()
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

    for _, holder in pairs(frame.Auras) do
        holder.display.host:Hide()
    end
end

oUF:AddElement('NRSKNAuras', Update, Enable, Disable)

---Reapply every unit frame's aura filters, picking up triggers added or removed.
---Wired to the AuraFilters callback in Core.lua.
function UF:ReapplyAuraFilters()
    for _, frame in pairs(UF.frames) do
        for _, holder in pairs(frame.Auras or {}) do
            holder.display:SetTrigger(holder.cfg.Trigger)
        end
    end
end

---@class UnitFramesElements
---@field Auras UnitFramesAurasElement
UF.Elements = UF.Elements or {}

---@class UnitFramesAurasElement
UF.Elements.Auras = {
    ---Each kind is an aura group display, its host placed off the health bar.
    ---@param self oUF.UnitFrame
    ---@param unit string
    Construct = function(self, unit)
        if self.Auras then return end

        local uDB = UF.GetUnitDB(unit)
        local holders = {}

        for _, kind in ipairs(UF.GroupConfigs[self.nuiConfig or unit] and GROUP_KINDS or KINDS) do
            local cfg = uDB.Auras[kind]
            local holder = { cfg = cfg, style = UF.PrepareAuras(cfg, kind) }
            holder.display = NRSKNUI:NewAuraDisplay(self, {
                shape = 'group',
                style = function(entry) NRSKNUI:ApplyIconLook(entry.refs, holder.style, holder.cfg.SubRegions, entry.branch) end,
            })
            holders[kind] = holder
        end

        self.Auras = holders
    end,

    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table
    ---@param restyle table? set when the buttons redraw, holding the pass's look stamps by config
    ---@param only UF.AuraKind? configure just this kind
    Configure = function(self, unit, uDB, general, restyle, only)
        local holders = self.Auras
        if not holders then return end

        -- The health bar, not the frame, so auras never cover a docked power bar.
        local anchor = self.Health or self

        for kind, holder in pairs(holders) do
            -- an edit to one kind leaves the others' buttons alone
            if not only or kind == only then
                -- set before the display reads them: SetTrigger can hand a button over at once
                local cfg = uDB.Auras[kind]
                holder.cfg, holder.style = cfg, UF.PrepareAuras(cfg, kind)
                local display = holder.display

                if restyle then
                    -- a role or profile switch that leaves the look as it was redraws nothing
                    local stamp = restyle[cfg]
                    if not stamp then
                        stamp = NRSKNUI:LookStamp(cfg.Style, cfg.SubRegions)
                        restyle[cfg] = stamp
                    end
                    display:Restyle(stamp)
                end
                local config = NRSKNUI:GetAuraGroupConfig(cfg, holder.style)
                display:SetLayout(config, NRSKNUI:GetAuraPreviewCount(cfg), UF.GetElementLevel(self, kind))
                display:SetTrigger(cfg.Trigger)
                -- the live token, which a preview repoints away from the configured unit
                display:SetUnit(self.__unit or unit)

                -- the host is the whole grid, so its point is where the auras grow from
                local pos = cfg.Position
                local host = display.host
                host:ClearAllPoints()
                host:NCSetPoint(pos.AnchorFrom, anchor, pos.AnchorTo, pos.XOffset, pos.YOffset)
                host:SetAlpha(holder.style.Alpha)
                host:SetShown(cfg.Enabled)
            end
        end
    end,

    ---Preview the aura containers, showing the preview and hiding the live auras.
    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    Preview = function(self, unit, uDB)
        local holders = self.Auras
        if not holders then return end

        -- nuiConfig, not the token: oUF's guessed archetype can't tell the raid tiers apart
        local preview = UF.Preview:IsPreviewing('Auras', self.nuiConfig or unit)

        for kind, holder in pairs(holders) do
            holder.display:SetPreview(preview and uDB.Auras[kind].Enabled)
        end
    end,
}

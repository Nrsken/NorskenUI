---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')

---@class UnitFramesElements
---@field Range UnitFramesRangeElement
UF.Elements = UF.Elements or {}

---@class UnitFramesRangeElement
UF.Elements.Range = {
    ---@param self oUF.UnitFrame
    ---@param unit string
    Construct = function(self, unit)
        -- oUF's element is event-driven and UnitInRange-only, so it scales to a full group where our spell-range ticker does not.
        if UF.GroupConfigs[unit] then
            self.Range = {
                insideAlpha = 1,
                outsideAlpha = 0.6
            }
        end
    end,

    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table
    Configure = function(self, unit, uDB, general)
        local rDB = general.Range
        local enabled = (rDB and rDB.Enabled) and true or false

        local range = self.Range
        if range then
            range.insideAlpha = (rDB and rDB.InsideAlpha) or 1
            range.outsideAlpha = (rDB and rDB.OutsideAlpha) or 0.6
            return
        end

        -- self.unit is the live token, which a preview repoints away from the configured unit.
        local liveUnit = self.unit or unit

        if enabled and liveUnit ~= 'player' then
            self.nuiRangeIn = rDB.InsideAlpha or 1
            self.nuiRangeOut = rDB.OutsideAlpha or 0.6
            UF:RegisterRangeFrame(self, liveUnit)
        else
            UF:UnregisterRangeFrame(self)
        end
    end,
}

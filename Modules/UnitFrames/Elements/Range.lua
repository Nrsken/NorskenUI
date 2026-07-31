---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
---@field Elements UnitFramesElements
local UF = NRSKNUI:GetModule('UnitFrames')

---@class UnitFramesElements
---@field Range UnitFramesRangeElement
UF.Elements = UF.Elements or {}

---@class UnitFramesRangeElement
UF.Elements.Range = {
    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table
    Configure = function(self, unit, uDB, general)
        local rDB = general.Range
        -- self.unit is the live token, which a preview repoints away from the configured unit.
        local liveUnit = self.unit or unit

        if rDB and rDB.Enabled and liveUnit ~= 'player' then
            self.nuiRangeIn = rDB.InsideAlpha or 1
            self.nuiRangeOut = rDB.OutsideAlpha or 0.6
            UF:RegisterRangeFrame(self, liveUnit)
        else
            UF:UnregisterRangeFrame(self)
        end
    end,
}

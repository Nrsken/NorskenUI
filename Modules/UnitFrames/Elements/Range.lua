---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')

local UnitIsConnected = UnitIsConnected
local UnitInRange = UnitInRange
local UnitExists = UnitExists

---Fade one group frame on the game's own range answer.
---@param frame oUF.UnitFrame
local function GroupRange(frame)
    local element = frame.Range
    local unit = frame.__unit

    if not unit or unit == 'player' or not UnitExists(unit) or not UnitIsConnected(unit) then
        frame:SetAlpha(element.insideAlpha)
        return
    end

    local inRange, wasChecked = UnitInRange(unit)

    if NRSKNUI:IsSecretValue(wasChecked) then
        frame:SetAlphaFromBoolean(inRange, element.insideAlpha, element.outsideAlpha)
    elseif wasChecked then
        frame:SetAlpha(inRange and element.insideAlpha or element.outsideAlpha)
    else
        frame:SetAlpha(element.insideAlpha)
    end
end

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
                outsideAlpha = 0.6,
                Override = GroupRange,
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

        -- self.__unit is the live token, which a preview repoints away from the configured unit.
        local liveUnit = self.__unit or unit

        if enabled and liveUnit ~= 'player' then
            self.nuiRangeIn = rDB.InsideAlpha or 1
            self.nuiRangeOut = rDB.OutsideAlpha or 0.6
            UF:RegisterRangeFrame(self, liveUnit)
        else
            UF:UnregisterRangeFrame(self)
        end
    end,
}

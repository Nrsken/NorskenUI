---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')

-- Range element, handles range fading for unit frames by check data from Modules\UnitFrames\RangeData.lua.
UF.Elements = UF.Elements or {}
UF.Elements.Range = {
    Configure = function(frame, unit, uDB, general)
        local rDB = general.Range

        if rDB and rDB.Enabled and unit ~= 'player' then
            frame.nuiRangeIn = rDB.InsideAlpha or 1
            frame.nuiRangeOut = rDB.OutsideAlpha or 0.6
            UF:RegisterRangeFrame(frame, unit)
        else
            UF:UnregisterRangeFrame(frame)
        end
    end,
}

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')

-- Units that never get a power bar or castbar.
local NO_POWER = {
    targettarget = true,
    focustarget = true,
    pettarget = true,
}

---Build the oUF style for a unit frame, constructing and configuring elements as needed.
---@param frame oUF.UnitFrame
---@param unit string
function UF:BuildStyle(frame, unit)
    frame.nrsknUnit = unit

    frame:RegisterForClicks('AnyUp') -- oUF doesn't register for clicks by default, so we do it here.

    local base = UF.NormalizeUnit(unit)
    local hasPower = not NO_POWER[base]

    self:ConstructElement('Health', frame, unit)
    self:ConstructElement('Tags', frame, unit)
    self:ConstructElement('Indicators', frame, unit)
    self:ConstructElement('Auras', frame, unit)
    self:ConstructElement('AuraIndicators', frame, unit)
    if hasPower then
        self:ConstructElement('Power', frame, unit)
        self:ConstructElement('Castbar', frame, unit)
    end

    self:ConfigureFrame(frame, unit)
    frame.nuiBuilt = true -- oUF finishes building and auto-enables elements after this returns.
end

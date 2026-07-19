---@class NRSKNUI
local NRSKNUI = select(2, ...)

local CreateCurve = C_CurveUtil and C_CurveUtil.CreateCurve

local Step = Enum.LuaCurveType.Step

-- if the duration is < 3 seconds then we want 1 decimal point, otherwise 0
-- offset this by 0.2 because of weird calculation timings making it flash 1.x
local DurationDecimals = CreateCurve()
DurationDecimals:SetType(Step)
DurationDecimals:AddPoint(0.09, 0)
DurationDecimals:AddPoint(0.1, 1)
DurationDecimals:AddPoint(2.8, 1)
DurationDecimals:AddPoint(2.9, 0)

-- Curve that yields data for SetDesaturation based on cooldown remaining
local ActionDesaturation = CreateCurve()
ActionDesaturation:SetType(Step)
ActionDesaturation:AddPoint(0, 0)
ActionDesaturation:AddPoint(0.001, 1)

-- Curve that yields data for SetAlpha based on cooldown remaining
local ActionAlpha = CreateCurve()
ActionAlpha:SetType(Step)
ActionAlpha:AddPoint(0, 1)
ActionAlpha:AddPoint(0.001, 0.33)

-- Curve that yields alpha based on health percent (0 at full, 1 when missing)
local HealthMissingAlpha = CreateCurve()
HealthMissingAlpha:SetType(Step)
HealthMissingAlpha:AddPoint(0, 1)
HealthMissingAlpha:AddPoint(0.999, 1)
HealthMissingAlpha:AddPoint(1, 0)

---@class NRSKNUI.Curves
---@field DurationDecimals CurveObject
---@field ActionDesaturation CurveObject
---@field ActionAlpha CurveObject
---@field HealthMissingAlpha CurveObject
NRSKNUI.curves = {
    DurationDecimals = DurationDecimals,
    HealthMissingAlpha = HealthMissingAlpha,
    ActionDesaturation = ActionDesaturation,
    ActionAlpha = ActionAlpha,
}

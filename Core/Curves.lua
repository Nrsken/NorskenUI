-- NorskenUI namespace
local _, NRSKNUI = ...
NRSKNUI.curves = {}

-- Module credit fully to p3lim

-- if the duration is < 1 seconds then we want 1 decimal point, otherwise 0
-- offset this by 0.2 because of weird calculation timings making it flash 1.x
NRSKNUI.curves.DurationDecimals = C_CurveUtil.CreateCurve()
NRSKNUI.curves.DurationDecimals:SetType(Enum.LuaCurveType.Step)
NRSKNUI.curves.DurationDecimals:AddPoint(0.09, 0)
NRSKNUI.curves.DurationDecimals:AddPoint(0.1, 1)
NRSKNUI.curves.DurationDecimals:AddPoint(0.8, 1)
NRSKNUI.curves.DurationDecimals:AddPoint(0.9, 0)

-- curve that yields data for SetDesaturation based on cooldown remaining
NRSKNUI.curves.ActionDesaturation = C_CurveUtil.CreateCurve()
NRSKNUI.curves.ActionDesaturation:SetType(Enum.LuaCurveType.Step)
NRSKNUI.curves.ActionDesaturation:AddPoint(0, 0)
NRSKNUI.curves.ActionDesaturation:AddPoint(0.001, 1)

-- curve that yields data for SetAlpha based on cooldown remaining
NRSKNUI.curves.ActionAlpha = C_CurveUtil.CreateCurve()
NRSKNUI.curves.ActionAlpha:SetType(Enum.LuaCurveType.Step)
NRSKNUI.curves.ActionAlpha:AddPoint(0, 1)
NRSKNUI.curves.ActionAlpha:AddPoint(0.001, 0.33)
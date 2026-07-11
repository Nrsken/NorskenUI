---@class NRSKNUI
local NRSKNUI = select(2, ...)
NRSKNUI.curves = {}

local next = next
local CreateColor = CreateColor

local CreateCurve = C_CurveUtil and C_CurveUtil.CreateCurve
local CreateColorCurve = C_CurveUtil and C_CurveUtil.CreateColorCurve

local Step = Enum.LuaCurveType.Step

-- if the duration is < 3 seconds then we want 1 decimal point, otherwise 0
-- offset this by 0.2 because of weird calculation timings making it flash 1.x
NRSKNUI.curves.DurationDecimals = CreateCurve()
NRSKNUI.curves.DurationDecimals:SetType(Step)
NRSKNUI.curves.DurationDecimals:AddPoint(0.09, 0)
NRSKNUI.curves.DurationDecimals:AddPoint(0.1, 1)
NRSKNUI.curves.DurationDecimals:AddPoint(2.8, 1)
NRSKNUI.curves.DurationDecimals:AddPoint(2.9, 0)

-- Curve that yields data for SetDesaturation based on cooldown remaining
NRSKNUI.curves.ActionDesaturation = CreateCurve()
NRSKNUI.curves.ActionDesaturation:SetType(Step)
NRSKNUI.curves.ActionDesaturation:AddPoint(0, 0)
NRSKNUI.curves.ActionDesaturation:AddPoint(0.001, 1)

-- Curve that yields data for SetAlpha based on cooldown remaining
NRSKNUI.curves.ActionAlpha = CreateCurve()
NRSKNUI.curves.ActionAlpha:SetType(Step)
NRSKNUI.curves.ActionAlpha:AddPoint(0, 1)
NRSKNUI.curves.ActionAlpha:AddPoint(0.001, 0.33)

-- Curve that yields alpha based on health percent (0 at full, 1 when missing)
NRSKNUI.curves.HealthMissingAlpha = CreateCurve()
NRSKNUI.curves.HealthMissingAlpha:SetType(Step)
NRSKNUI.curves.HealthMissingAlpha:AddPoint(0, 1)
NRSKNUI.curves.HealthMissingAlpha:AddPoint(0.999, 1)
NRSKNUI.curves.HealthMissingAlpha:AddPoint(1, 0)

-- Dispel type alpha curves (for showing/hiding dispel icons based on aura dispel type)
-- Each curve returns alpha 1 for its dispel type, 0 for all others
local DispelType = NRSKNUI.Enum.DispelType
local transparent = CreateColor(1, 1, 1, 0)
local visible = CreateColor(1, 1, 1, 1)

local function CreateDispelAlphaCurve(targetDispelType)
    local curve = CreateColorCurve()
    curve:SetType(Step)
    for _, dispelIndex in next, DispelType do
        curve:AddPoint(dispelIndex, dispelIndex == targetDispelType and visible or transparent)
    end
    return curve
end

NRSKNUI.curves.DispelAlpha = {
    Magic = CreateDispelAlphaCurve(DispelType.Magic),
    Curse = CreateDispelAlphaCurve(DispelType.Curse),
    Disease = CreateDispelAlphaCurve(DispelType.Disease),
    Poison = CreateDispelAlphaCurve(DispelType.Poison),
    Enrage = CreateDispelAlphaCurve(DispelType.Enrage),
    Bleed = CreateDispelAlphaCurve(DispelType.Bleed),
}

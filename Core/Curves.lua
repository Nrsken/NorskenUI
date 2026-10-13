---@class NRSKNUI
local NRSKNUI = select(2, ...)

local CreateColor = CreateColor
local unpack = unpack

local CreateCurve = C_CurveUtil and C_CurveUtil.CreateCurve
local CreateColorCurve = C_CurveUtil and C_CurveUtil.CreateColorCurve

local Step = Enum.LuaCurveType.Step

local function GetColorCurveDB()
    local db = NRSKNUI.db
    if not db or not db.profile or not db.profile.globalMedia then
        return nil
    end
    return db.profile.globalMedia
end

local DEFAULT_DURATION_CURVE_COLORS = {
    colorOne = { 1, 0.25, 0.25, 1 },
    colorTwo = { 1, 0.56, 0.25, 1 },
    colorThree = { 1, 0.7, 0.38, 1 },
    colorFour = { 1, 0.76, 0.61, 1 },
    colorFive = { 1, 1, 1, 1 },
    colorSix = { 1, 1, 1, 1 },
}

-- if the duration is < 3 seconds then we want 1 decimal point, otherwise 0
-- offset this by 0.2 because of weird calculation timings making it flash 1.x
local DurationDecimals = CreateCurve()
DurationDecimals:SetType(Step)
DurationDecimals:AddPoint(0.09, 0)
DurationDecimals:AddPoint(0.1, 1)
DurationDecimals:AddPoint(2.8, 1)
DurationDecimals:AddPoint(2.9, 0)

-- Decimal places for a percentage: 2 below 10%, 1 below 100%, 0 at full
local PercentDecimals = CreateCurve()
PercentDecimals:SetType(Step)
PercentDecimals:AddPoint(0, 2)
PercentDecimals:AddPoint(0.1, 1)
PercentDecimals:AddPoint(1, 0)

-- Curve that yields data for SetDesaturation based on cooldown remaining
local ActionDesaturation = CreateCurve()
ActionDesaturation:SetType(Step)
ActionDesaturation:AddPoint(0, 0)
ActionDesaturation:AddPoint(0.001, 1)

-- Curve that yields alpha based on health percent (0 at full, 1 when missing)
local HealthMissingAlpha = CreateCurve()
HealthMissingAlpha:SetType(Step)
HealthMissingAlpha:AddPoint(0, 1)
HealthMissingAlpha:AddPoint(0.999, 1)
HealthMissingAlpha:AddPoint(1, 0)

-- Curve that yields a bar spark's alpha from its fill: hidden when empty or full
local BarSparkAlpha = CreateCurve()
BarSparkAlpha:SetType(Step)
BarSparkAlpha:AddPoint(0, 0)
BarSparkAlpha:AddPoint(0.001, 1)
BarSparkAlpha:AddPoint(1, 0)

-- Curve that yields a countdown text's alpha from its cooldown's total duration: hidden for a GCD or cast lockout
local CountdownAlpha = CreateCurve()
CountdownAlpha:SetType(Step)
CountdownAlpha:AddPoint(0, 0)
CountdownAlpha:AddPoint(1.5, 1)

local function BuildAuraDurationColorCurve()
    local db = GetColorCurveDB()
    local c, points

    if not db then
        c = DEFAULT_DURATION_CURVE_COLORS
        points = {
            pointOne = { threshold = 0 },
            pointTwo = { threshold = 1 },
            pointThree = { threshold = 60 },
            pointFour = { threshold = 600 },
            pointFive = { threshold = 3600 },
            pointSix = { threshold = 86400 },
        }
    else
        c = db.profileColorCurve
        points = db.profileBreakPoints
    end

    local curve = CreateColorCurve()
    curve:AddPoint(points.pointOne.threshold, CreateColor(unpack(c.colorOne or DEFAULT_DURATION_CURVE_COLORS.colorOne)))
    curve:AddPoint(points.pointTwo.threshold, CreateColor(unpack(c.colorTwo or DEFAULT_DURATION_CURVE_COLORS.colorTwo)))
    curve:AddPoint(points.pointThree.threshold, CreateColor(unpack(c.colorThree or DEFAULT_DURATION_CURVE_COLORS.colorThree)))
    curve:AddPoint(points.pointFour.threshold, CreateColor(unpack(c.colorFour or DEFAULT_DURATION_CURVE_COLORS.colorFour)))
    curve:AddPoint(points.pointFive.threshold, CreateColor(unpack(c.colorFive or DEFAULT_DURATION_CURVE_COLORS.colorFive)))
    curve:AddPoint(points.pointSix.threshold, CreateColor(unpack(c.colorSix or DEFAULT_DURATION_CURVE_COLORS.colorSix)))
    return curve
end

local AuraDurationColor = BuildAuraDurationColorCurve()

---@class NRSKNUI.Curves
---@field DurationDecimals CurveObject
---@field PercentDecimals CurveObject
---@field ActionDesaturation CurveObject
---@field HealthMissingAlpha CurveObject
---@field BarSparkAlpha CurveObject
---@field CountdownAlpha CurveObject
---@field AuraDurationColor ColorCurveObject
NRSKNUI.curves = {
    DurationDecimals = DurationDecimals,
    PercentDecimals = PercentDecimals,
    HealthMissingAlpha = HealthMissingAlpha,
    BarSparkAlpha = BarSparkAlpha,
    CountdownAlpha = CountdownAlpha,
    ActionDesaturation = ActionDesaturation,
    AuraDurationColor = AuraDurationColor,
}

function NRSKNUI:RefreshCurves()
    self.curves.AuraDurationColor = BuildAuraDurationColorCurve()
end

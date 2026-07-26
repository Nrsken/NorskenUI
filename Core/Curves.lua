---@class NRSKNUI
local NRSKNUI = select(2, ...)

local CreateCurve = C_CurveUtil and C_CurveUtil.CreateCurve
local CreateColorCurve = C_CurveUtil and C_CurveUtil.CreateColorCurve
local CreateColor = CreateColor

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
}

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

local function BuildAuraDurationColorCurve()
    local db = GetColorCurveDB()
    local c, points

    if not db then
        c = DEFAULT_DURATION_CURVE_COLORS
        points = {
            pointOne = { threshold = 0 },
            pointTwo = { threshold = 3 },
            pointThree = { threshold = 10 },
            pointFour = { threshold = 60 },
            pointFive = { threshold = 3600 },
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
    return curve
end

local AuraDurationColor = BuildAuraDurationColorCurve()

---@class NRSKNUI.Curves
---@field DurationDecimals CurveObject
---@field ActionDesaturation CurveObject
---@field ActionAlpha CurveObject
---@field HealthMissingAlpha CurveObject
---@field AuraDurationColor ColorCurveObject
NRSKNUI.curves = {
    DurationDecimals = DurationDecimals,
    HealthMissingAlpha = HealthMissingAlpha,
    ActionDesaturation = ActionDesaturation,
    ActionAlpha = ActionAlpha,
    AuraDurationColor = AuraDurationColor,
}

function NRSKNUI:RefreshCurves()
    self.curves.AuraDurationColor = BuildAuraDurationColorCurve()
end

---@meta

---@class BugGrabber
---@field GetSessionId fun(self: BugGrabber): number
BugGrabber = BugGrabber

---@class ElvUI_SpellBookTooltip: GameTooltip
ElvUI_SpellBookTooltip = ElvUI_SpellBookTooltip

---@class Cooldown
---@field SetSwipeTexture fun(self: Cooldown, texture: string, r?: number, g?: number, b?: number, a?: number)

---@type function
GameMovieFinished = GameMovieFinished

---@type function
GetMouseFocus = GetMouseFocus

---@param value any
---@return boolean
function issecretvalue(value) end

---@class LuaCurveObject
---@class LuaDurationObject
---@field Assign fun(self: LuaDurationObject, other: LuaDurationObject)
---@field copy fun(self: LuaDurationObject): LuaDurationObject
---@field EvaluateElapsedPercent fun(self: LuaDurationObject, curve: LuaCurveObject, modifier: number?): number
---@field EvaluateRemainingPercent fun(self: LuaDurationObject, curve: LuaCurveObject, modifier: number?): number
---@field GetElapsedDuration fun(self: LuaDurationObject, modifier: number?): number
---@field GetElapsedPercent fun(self: LuaDurationObject, modifier: number?): number
---@field GetEndTime fun(self: LuaDurationObject, modifier: number?): number
---@field GetModRate fun(self: LuaDurationObject): number
---@field GetRemainingDuration fun(self: LuaDurationObject, modifier: number?): number
---@field GetRemainingPercent fun(self: LuaDurationObject, modifier: number?): number
---@field GetStartTime fun(self: LuaDurationObject, modifier: number?): number
---@field GetTotalDuration fun(self: LuaDurationObject, modifier: number?): number
---@field HasSecretValues fun(self: LuaDurationObject): boolean
---@field IsZero fun(self: LuaDurationObject): boolean
---@field Reset fun(self: LuaDurationObject)
---@field SetTimeFromEnd fun(self: LuaDurationObject, endTime: number, duration: number, modRate: number?)
---@field SetTimeFromStart fun(self: LuaDurationObject, startTime: number, duration: number, modRate: number?)
---@field SetTimeSpan fun(self: LuaDurationObject, startTime: number, endTime: number)
---@field SetToDefaults fun(self: LuaDurationObject)

---@class Frame
---@field SetAlphaFromBoolean fun(self: Frame, bool: boolean, alphaIfTrue: number?, alphaIfFalse: number?)
---@field SetShown fun(self: Frame, bool: boolean)

---@class FontString
---@field SetAlphaFromBoolean fun(self: FontString, bool: boolean, alphaIfTrue: number?, alphaIfFalse: number?)

---@class StatusBar
---@field SetTimerDuration fun(self: StatusBar, duration: LuaDurationObject, interpolation: Enum.StatusBarInterpolation?, direction: Enum.StatusBarTimerDirection?)

---@param unit string
---@return LuaDurationObject|nil
function UnitCastingDuration(unit)
    return {}
end

---@param unit string
---@return LuaDurationObject|nil
function UnitChannelDuration(unit)
    return {}
end

---@class Texture
---@field SetVertexColorFromBoolean fun(self: Texture, bool: boolean, colorIfTrue: colorRGBA, colorIfFalse: colorRGBA)

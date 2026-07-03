---@meta

---@class BugGrabber
---@field GetSessionId fun(self: BugGrabber): number
BugGrabber = BugGrabber

---@class NorskenUI : AceAddon-3.0, AceEvent-3.0, AceHook-3.0
---@type NorskenUI
NorskenUI = {}

---@class ElvUI_SpellBookTooltip: GameTooltip
ElvUI_SpellBookTooltip = ElvUI_SpellBookTooltip

---@class Cooldown
---@field SetSwipeTexture fun(self: Cooldown, texture: string, r?: number, g?: number, b?: number, a?: number)
---@field SetDrawEdge fun(self: Cooldown, drawEdge: boolean)
---@field SetReverse fun(self: Cooldown, reverse: boolean)
---@field SetDrawSwipe fun(self: Cooldown, drawSwipe: boolean)
---@field SetDrawBling fun(self: Cooldown, drawBling: boolean)
---@field SetCountdownFormatter fun(self: Cooldown, formatter: function)
---@field SetHideCountdownNumbers fun(self: Cooldown, hide: boolean)

---@type function
GameMovieFinished = GameMovieFinished

---@type function
GetMouseFocus = GetMouseFocus

---@class AuraContainerUtil
---@field ShouldIncludeAuraForFilterString fun(container: Frame, filterString: string, auraData: table): boolean
---@field CreateAuraContainerGroup fun(description: table): table
---@field CreateFramePoolProvider fun(pool: table): table
AuraContainerUtil = AuraContainerUtil

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
---@field Size fun(self: Frame, width: number, height: number?) Pixel-scaled SetSize
---@field Width fun(self: Frame, width: number) Pixel-scaled SetWidth
---@field Height fun(self: Frame, height: number) Pixel-scaled SetHeight
---@field Point fun(self: Frame, point: FramePoint, relativeTo?: Region|number, relativePoint?: FramePoint|number, offsetX?: number, offsetY?: number) Pixel-scaled SetPoint with auto-parent
---@field SetInside fun(self: Frame, anchor?: Region, xOffset?: number, yOffset?: number, anchor2?: Region) Anchor inside another frame with pixel-scaled inset
---@field SetOutside fun(self: Frame, anchor?: Region, xOffset?: number, yOffset?: number, anchor2?: Region) Anchor outside another frame with pixel-scaled outset
---@field DisablePixelSnap fun(self: Frame) Disable pixel grid snapping for crisp rendering
---@field SetMouseMotionEnabled fun(self: Frame, enabled: boolean) Enable or disable mouse motion events for the frame
---@field SetDurationCooldown fun(self: Frame, cooldown: Cooldown) Set the cooldown frame for the aura button

---@class FontString
---@field SetAlphaFromBoolean fun(self: FontString, bool: boolean, alphaIfTrue: number?, alphaIfFalse: number?)
---@field Size fun(self: FontString, width: number, height: number?) Pixel-scaled SetSize
---@field Width fun(self: FontString, width: number) Pixel-scaled SetWidth
---@field Height fun(self: FontString, height: number) Pixel-scaled SetHeight
---@field Point fun(self: FontString, point: FramePoint, relativeTo?: Region|number, relativePoint?: FramePoint|number, offsetX?: number, offsetY?: number) Pixel-scaled SetPoint with auto-parent
---@field SetInside fun(self: FontString, anchor?: Region, xOffset?: number, yOffset?: number, anchor2?: Region) Anchor inside another frame with pixel-scaled inset
---@field SetOutside fun(self: FontString, anchor?: Region, xOffset?: number, yOffset?: number, anchor2?: Region) Anchor outside another frame with pixel-scaled outset
---@field DisablePixelSnap fun(self: FontString) Disable pixel grid snapping for crisp rendering

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
---@field Size fun(self: Texture, width: number, height: number?) Pixel-scaled SetSize
---@field Width fun(self: Texture, width: number) Pixel-scaled SetWidth
---@field Height fun(self: Texture, height: number) Pixel-scaled SetHeight
---@field Point fun(self: Texture, point: FramePoint, relativeTo?: Region|number, relativePoint?: FramePoint|number, offsetX?: number, offsetY?: number) Pixel-scaled SetPoint with auto-parent
---@field SetInside fun(self: Texture, anchor?: Region, xOffset?: number, yOffset?: number, anchor2?: Region) Anchor inside another frame with pixel-scaled inset
---@field SetOutside fun(self: Texture, anchor?: Region, xOffset?: number, yOffset?: number, anchor2?: Region) Anchor outside another frame with pixel-scaled outset
---@field DisablePixelSnap fun(self: Texture) Disable pixel grid snapping for crisp rendering

---@class AuraLayoutDB
---@field IconSize number
---@field IconSpacing number
---@field IconsPerRow number
---@field MaxIcons number
---@field Position table
---@field GrowthDirection "LEFT"|"RIGHT"
---@field WrapDirection "UP"|"DOWN"
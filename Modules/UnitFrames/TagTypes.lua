---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF
local Tags = oUF.Tags
local L = NRSKNUI.Libs.AL

local UnitHealth, UnitHealthPercent, UnitGetTotalAbsorbs = UnitHealth, UnitHealthPercent, UnitGetTotalAbsorbs
local UnitPowerPercent, UnitPower, UnitPowerType = UnitPowerPercent, UnitPower, UnitPowerType
local UnitIsPVP, UnitIsEnemy, UnitIsPlayer = UnitIsPVP, UnitIsEnemy, UnitIsPlayer
local UnitIsTapDenied, UnitIsConnected = UnitIsTapDenied, UnitIsConnected
local UnitFactionGroup, UnitReaction = UnitFactionGroup, UnitReaction
local UnitNameUnmodified, UnitName = UnitNameUnmodified, UnitName
local UnitTreatAsPlayerForDisplay = UnitTreatAsPlayerForDisplay
local UnitIsDead, UnitIsGhost = UnitIsDead, UnitIsGhost
local UnitExists, UnitClass = UnitExists, UnitClass
local AbbreviateLargeNumbers = AbbreviateLargeNumbers
local format = string.format
local select = select

local GetClassColor = C_ClassColor and C_ClassColor.GetClassColor
local WrapString = C_StringUtil and C_StringUtil.WrapString

local DEAD = DEAD
local PLAYER_LIST_DELIMITER = PLAYER_LIST_DELIMITER

-- Every value the status tag can return, cycled through while previewing.
local PREVIEW_STATUSES = { DEAD, L['Ghost'], L['Offline'], L['DND'], L['AFK'], DEAD .. PLAYER_LIST_DELIMITER .. L['AFK'], }

-- Generally used events for different tag types.
local POWER_EVENTS = 'UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER'
local CONNECTION_EVENTS = 'UNIT_CONNECTION PARTY_MEMBER_ENABLE PARTY_MEMBER_DISABLE'
local NAME_COLOR_EVENTS = 'UNIT_NAME_UPDATE UNIT_FACTION PLAYER_FLAGS_CHANGED ' .. CONNECTION_EVENTS
local HEALTH_EVENTS = 'UNIT_HEALTH UNIT_MAXHEALTH'

-- Tag categories for the GUI dropdowns.
UF.TagOptions = { health = {}, power = {}, name = {}, misc = {}, prefixes = {} }

---Register a tag and offer it in the GUI when it belongs to a category.
---@param name string tag name, without brackets
---@param text string label shown in the GUI dropdown
---@param category string? 'health', 'power', 'name', 'misc' or 'prefixes'. nil registers the tag but hides it
---@param event string space separated events that refresh the tag
---@param method fun(unit: string): string|number|nil raw numbers are fine, oUF formats the result
function UF:RegisterTag(name, text, category, event, method)
	Tags.Events[name] = event
	Tags.Methods[name] = method

	local bucket = category and self.TagOptions[category]
	if not bucket then return end

	bucket[#bucket + 1] = {
		value = '[' .. name .. ']',
		text = text,
	}
end

---@param unit string
---@param frame table? oUF Frame
---@return string? Markup
local function SmartColor(unit, frame)
	local health = frame and frame.Health
	if health and health.nuiColorByClass then
		return nil -- If in class color mode, we simply use the tags without any color markup, makes switching between class color and smart color seamless.
	end

	local reaction = UnitReaction(unit, 'player')
	if UnitIsTapDenied(unit) or not UnitIsConnected(unit) then
		return '|cff999999'
	elseif UnitIsPlayer(unit) or UnitTreatAsPlayerForDisplay(unit) then
		local color
		local classToken = select(2, UnitClass(unit))

		if classToken ~= nil then
			color = GetClassColor(classToken)
		end
		if color then
			return color:GenerateHexColorMarkup()
		end
	elseif not UnitIsPlayer(unit) and reaction then
		local reactionColor = NRSKNUI.Colors.reaction[reaction]

		if reactionColor then
			return reactionColor:GenerateHexColorMarkup()
		end
	elseif UnitFactionGroup(unit) and UnitIsEnemy(unit, 'player') and UnitIsPVP(unit) then
		return '|cffff0000'
	end
end

---@param frame table? oUF Frame
---@param powerType number
---@return string? markup
local function PowerColor(frame, powerType)
	local health = frame and frame.Health
	if health and health.nuiColorByClass then
		return nil -- Same as SmartColor, if the health bar is in class color mode, we don't want to color the power text either.
	end

	local color = NRSKNUI.Colors.power[powerType]
	return color and color:GenerateHexColorMarkup()
end

-- Wrap a string in a color markup or return the string unmodified if no color is given.
---@param text string|number
---@param color string? markup
---@return string|number
local function Colored(text, color)
	if not color then return text end

	return WrapString(text, color, '|r')
end

-- Power Tags --

--* Unit power percentage.
UF:RegisterTag('NUF:perpower', L['Power %'], 'power', POWER_EVENTS, function(unit)
	if not unit or not UnitExists(unit) then return '' end

	return format('%.f', UnitPowerPercent(unit, nil, true, CurveConstants.ScaleTo100))
end)

--* Unit power percentage, smart colored.
UF:RegisterTag('NUF:perpower:smartcolor', L['Power % (Colored)'], 'power', POWER_EVENTS, function(unit)
	if not unit or not UnitExists(unit) then return '' end

	local percent = format('%.f', UnitPowerPercent(unit, nil, true, CurveConstants.ScaleTo100))
	return Colored(percent, PowerColor(_FRAME, UnitPowerType(unit)))
end)

--* Unit power percentage, smart colored w/ % symbol.
UF:RegisterTag('NUF:perpower:smartcolorpct', L['Power % (Colored) w/ %'], 'power', POWER_EVENTS, function(unit)
	if not unit or not UnitExists(unit) then return '' end

	local percent = format('%.f%%', UnitPowerPercent(unit, nil, true, CurveConstants.ScaleTo100))
	return Colored(percent, PowerColor(_FRAME, UnitPowerType(unit)))
end)

--* Unit power as a raw value.
UF:RegisterTag('NUF:curpower', L['Power'], 'power', POWER_EVENTS, function(unit)
	if not unit or not UnitExists(unit) then return '' end

	return UnitPower(unit)
end)

--* Unit power as a raw value, smart colored.
UF:RegisterTag('NUF:curpower:smartcolor', L['Power (Colored)'], 'power', POWER_EVENTS, function(unit)
	if not unit or not UnitExists(unit) then return '' end

	return Colored(UnitPower(unit), PowerColor(_FRAME, UnitPowerType(unit)))
end)

--* Unit mana percentage for healers, always shows mana, even if unit is other druid forms.
UF:RegisterTag('NUF:healmana', L['Mana % (Healer)'], 'power', POWER_EVENTS, function(unit)
	if NRSKNUI:GetSafeRole(unit) ~= 'HEALER' then return '' end

	return format('%.f', UnitPowerPercent(unit, Enum.PowerType.Mana, true, CurveConstants.ScaleTo100))
end)

--* Unit mana percentage for healers, always shows mana, even if unit is other druid forms, smart colored.
UF:RegisterTag('NUF:healmana:smartcolor', L['Mana % (Healer, Colored)'], 'power', POWER_EVENTS, function(unit)
	if NRSKNUI:GetSafeRole(unit) ~= 'HEALER' then return '' end

	local percent = format('%.f', UnitPowerPercent(unit, Enum.PowerType.Mana, true, CurveConstants.ScaleTo100))
	return Colored(percent, PowerColor(_FRAME, Enum.PowerType.Mana))
end)

--* Unit mana percentage for healers, always shows mana, even if unit is other druid forms, smart colored w/ % symbol.
UF:RegisterTag('NUF:healmana:smartcolorpct', L['Mana % (Healer, Colored) w/ %'], 'power', POWER_EVENTS, function(unit)
	if NRSKNUI:GetSafeRole(unit) ~= 'HEALER' then return '' end

	local percent = format('%.f%%', UnitPowerPercent(unit, Enum.PowerType.Mana, true, CurveConstants.ScaleTo100))
	return Colored(percent, PowerColor(_FRAME, Enum.PowerType.Mana))
end)

-- Prefix Tags --

--* Smart color prefix.
UF:RegisterTag('NUF:smartcolor', L['Smart Color'], 'prefixes', NAME_COLOR_EVENTS, function(unit)
	return SmartColor(unit, _FRAME)
end)

-- Name Tags --

--* Unmodified unit name.
UF:RegisterTag('NUF:name', L['Name'], 'name', 'UNIT_NAME_UPDATE', function(unit)
	return UnitNameUnmodified(unit)
end)

--* Unmodified unit name, smart colored.
UF:RegisterTag('NUF:name:smartcolor', L['Name (Colored)'], 'name', NAME_COLOR_EVENTS, function(unit)
	local name = UnitNameUnmodified(unit)
	if not name then return '' end

	return Colored(name, SmartColor(unit, _FRAME))
end)

--* Unmodified unit name with target name appended, separated by a tag separator.
UF:RegisterTag('NUF:name:target', L['Name + Target'], 'name', 'UNIT_NAME_UPDATE UNIT_TARGET', function(unit)
	local name = UnitNameUnmodified(unit)
	if not name then return '' end

	local targetName = UnitName(unit .. 'target')
	if not targetName then return name end

	return format('%s %s %s', name, UF.TagSeparator, targetName)
end)

--* Unmodified unit name with target name appended, separated by a tag separator, smart colored.
UF:RegisterTag('NUF:name:target:smartcolor', L['Name + Target (Colored)'], 'name', NAME_COLOR_EVENTS .. ' UNIT_TARGET', function(unit)
	local name = UnitNameUnmodified(unit)
	if not name then return '' end

	local coloredName = Colored(name, SmartColor(unit, _FRAME))
	local targetUnit = unit .. 'target'
	local targetName = UnitName(targetUnit)
	if not targetName then return coloredName end

	local coloredTarget = Colored(targetName, SmartColor(targetUnit, _FRAME))
	return format('%s %s %s', coloredName, UF.TagSeparator, coloredTarget)
end)

--* Target unit name.
UF:RegisterTag('NUF:target', L['Target'], nil, 'UNIT_NAME_UPDATE UNIT_TARGET', function(unit)
	return UnitName(unit .. 'target')
end)

-- Health Tags --

--* Unit health as an abbreviated raw value and percentage, falls back to unit state if dead, ghost or offline.
UF:RegisterTag('NUF:curhp:perhp', L['Health + Health %'], 'health', HEALTH_EVENTS .. ' ' .. CONNECTION_EVENTS, function(unit)
	if not unit or not UnitExists(unit) then return '' end
	local unitStatus = UnitIsDead(unit) and DEAD or UnitIsGhost(unit) and L['Ghost'] or not UnitIsConnected(unit) and L['Offline']

	if unitStatus then
		return unitStatus
	else
		return format('%s %s %.0f%%', AbbreviateLargeNumbers(UnitHealth(unit)), UF.TagSeparator, UnitHealthPercent(unit, false, CurveConstants.ScaleTo100))
	end
end)

--* Unit health as an abbreviated raw value.
UF:RegisterTag('NUF:curhp:abbr', L['Health (Short)'], 'health', HEALTH_EVENTS, function(unit)
	if not unit or not UnitExists(unit) then return '' end

	return AbbreviateLargeNumbers(UnitHealth(unit))
end)

--* Unit health as a raw value.
UF:RegisterTag('NUF:curhp', L['Health'], 'health', HEALTH_EVENTS, function(unit)
	if not unit or not UnitExists(unit) then return '' end

	return UnitHealth(unit)
end)

--* Unit health as a percentage.
UF:RegisterTag('NUF:perhp', L['Health %'], 'health', HEALTH_EVENTS, function(unit)
	if not unit or not UnitExists(unit) then return '' end

	return format('%.f', UnitHealthPercent(unit, false, CurveConstants.ScaleTo100))
end)

--* Unit absorb amount as an abbreviated raw value.
UF:RegisterTag('NUF:absorb:abbr', L['Damage Absorb (Short)'], 'health', 'UNIT_ABSORB_AMOUNT_CHANGED', function(unit)
	if not unit or not UnitExists(unit) then return '' end

	return AbbreviateLargeNumbers(UnitGetTotalAbsorbs(unit))
end)

-- Status Tags --

--* Unit status, returns dead, ghost, offline, dnd or afk. If the unit is dead and afk, both are returned.
UF:RegisterTag('NUF:status', L['Status'], 'misc', HEALTH_EVENTS .. ' PLAYER_FLAGS_CHANGED ' .. CONNECTION_EVENTS, function(unit)
	if not unit or not UnitExists(unit) then return '' end
	if _FRAME and _FRAME.nuiIsPreview then
		local step = UF.PreviewTick + (_FRAME.nuiPreviewIndex or 0)
		return PREVIEW_STATUSES[step % #PREVIEW_STATUSES + 1]
	end

	-- Unit offline has highest priority.
	if not UnitIsConnected(unit) then return L['Offline'] end

	local deathStatus = (UnitIsGhost(unit) and L['Ghost']) or NRSKNUI:IsUnitReallyDead(unit) and DEAD
	local awayStatus = (NRSKNUI:UnitIsDND(unit) and L['DND']) or (NRSKNUI:UnitIsAFK(unit) and L['AFK'])
	if deathStatus and awayStatus then return deathStatus .. PLAYER_LIST_DELIMITER .. awayStatus end
	return deathStatus or awayStatus or ''
end)

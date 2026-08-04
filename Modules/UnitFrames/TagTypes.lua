---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF
local Tags = oUF.Tags
local L = NRSKNUI.Libs.AL

local format = string.format

local UnitClass = UnitClass
local UnitNameUnmodified = UnitNameUnmodified
local UnitName = UnitName
local select = select
local UnitReaction = UnitReaction
local UnitIsTapDenied = UnitIsTapDenied
local UnitIsConnected = UnitIsConnected
local UnitIsPlayer = UnitIsPlayer
local UnitTreatAsPlayerForDisplay = UnitTreatAsPlayerForDisplay
local UnitFactionGroup = UnitFactionGroup
local UnitIsEnemy = UnitIsEnemy
local UnitIsPVP = UnitIsPVP
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthPercent = UnitHealthPercent
local UnitIsDead = UnitIsDead
local UnitIsGhost = UnitIsGhost
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local AbbreviateLargeNumbers = AbbreviateLargeNumbers
local UnitPowerType = UnitPowerType
local UnitPower = UnitPower
local UnitPowerPercent = UnitPowerPercent

local GetClassColor = C_ClassColor and C_ClassColor.GetClassColor
local WrapString = C_StringUtil.WrapString

local DEAD = DEAD
local PLAYER_LIST_DELIMITER = PLAYER_LIST_DELIMITER

-- Tags the GUI offers, split so each category gets its own dropdown.
UF.TagOptions = {
	health = {},
	power = {},
	name = {},
	misc = {}
}

---Register a tag and offer it in the GUI when it belongs to a category.
---@param name string tag name, without brackets
---@param text string label shown in the GUI dropdown
---@param category string? 'health', 'power', 'name' or 'misc'. nil registers the tag but hides it
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
---@param frame table? the oUF frame, used to skip coloring when its health bar is already class colored
---@return string? markup
local function SmartColor(unit, frame)
	local health = frame and frame.Health
	if health and health.nuiColorByClass then return nil end

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

---@param frame table? the oUF frame, used to skip coloring when its health bar is already class colored
---@param powerType number
---@return string? markup
local function PowerColor(frame, powerType)
	local health = frame and frame.Health
	if health and health.nuiColorByClass then return nil end

	local color = NRSKNUI.Colors.power[powerType]

	return color and color:GenerateHexColorMarkup()
end

-- Wrap a string in a color markup or return the string unmodified if no color is given.
local function Colored(text, color)
	if not color then return text end

	return WrapString(text, color, '|r')
end

-- Power Tags --

-- Unit power percentage (e.g. '0' - '100').
UF:RegisterTag('NUF:perpower', L['Power %'], 'power', 'UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER', function(unit)
	if not unit or not UnitExists(unit) then return '' end

	return format('%.f', UnitPowerPercent(unit, nil, true, CurveConstants.ScaleTo100))
end)

-- Unit power percentage, colored by power type unless the health bar already carries the class color.
UF:RegisterTag('NUF:perpower:smartcolor', L['Power % (Colored)'], 'power', 'UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER', function(unit)
	if not unit or not UnitExists(unit) then return '' end

	local percent = format('%.f', UnitPowerPercent(unit, nil, true, CurveConstants.ScaleTo100))

	return Colored(percent, PowerColor(_FRAME, UnitPowerType(unit)))
end)

-- Unit power as a raw value.
UF:RegisterTag('NUF:curpower', L['Power'], 'power', 'UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER', function(unit)
	if not unit or not UnitExists(unit) then return '' end

	return UnitPower(unit)
end)

-- Unit power as a raw value, colored by power type unless the health bar already carries the class color.
UF:RegisterTag('NUF:curpower:smartcolor', L['Power (Colored)'], 'power', 'UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER', function(unit)
	if not unit or not UnitExists(unit) then return '' end

	return Colored(UnitPower(unit), PowerColor(_FRAME, UnitPowerType(unit)))
end)

-- Reads the mana pool directly rather than the displayed power, so shapeshifted druids still report mana.
UF:RegisterTag('NUF:healmana', L['Mana % (Healer)'], 'power', 'UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER', function(unit)
	if NRSKNUI:GetSafeRole(unit) ~= 'HEALER' then return '' end

	return format('%.f', UnitPowerPercent(unit, Enum.PowerType.Mana, true, CurveConstants.ScaleTo100))
end)

UF:RegisterTag('NUF:healmana:smartcolor', L['Mana % (Healer, Colored)'], 'power', 'UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER', function(unit)
	if NRSKNUI:GetSafeRole(unit) ~= 'HEALER' then return '' end

	local percent = format('%.f', UnitPowerPercent(unit, Enum.PowerType.Mana, true, CurveConstants.ScaleTo100))

	return Colored(percent, PowerColor(_FRAME, Enum.PowerType.Mana))
end)

-- Color Tags --

-- Smart color prefix
UF:RegisterTag('NUF:smartcolor', L['Smart Color'], nil, 'UNIT_FACTION UNIT_CONNECTION UNIT_NAME_UPDATE PLAYER_FLAGS_CHANGED PARTY_MEMBER_ENABLE PARTY_MEMBER_DISABLE', function(unit)
	return SmartColor(unit, _FRAME)
end)

-- Name Tags --

-- Smart color reads faction, connection and tap state, so a colored name needs more than a name event.
local NAME_COLOR_EVENTS = 'UNIT_NAME_UPDATE UNIT_FACTION UNIT_CONNECTION PLAYER_FLAGS_CHANGED PARTY_MEMBER_ENABLE PARTY_MEMBER_DISABLE'

UF:RegisterTag('NUF:name', L['Name'], 'name', 'UNIT_NAME_UPDATE', function(unit)
	return UnitNameUnmodified(unit)
end)

UF:RegisterTag('NUF:name:smartcolor', L['Name (Colored)'], 'name', NAME_COLOR_EVENTS, function(unit)
	local name = UnitNameUnmodified(unit)
	if not name then return '' end

	return Colored(name, SmartColor(unit, _FRAME))
end)

UF:RegisterTag('NUF:name:target', L['Name + Target'], 'name', 'UNIT_NAME_UPDATE UNIT_TARGET', function(unit)
	local name = UnitNameUnmodified(unit)
	if not name then return '' end

	local targetName = UnitName(unit .. 'target')
	if not targetName then return name end

	return format('%s %s %s', name, UF.TagSeparator, targetName)
end)

UF:RegisterTag('NUF:name:target:smartcolor', L['Name + Target (Colored)'], 'name', NAME_COLOR_EVENTS .. ' UNIT_TARGET', function(unit)
	local name = UnitNameUnmodified(unit)
	if not name then return '' end

	local coloredName = Colored(name, SmartColor(unit, _FRAME))

	local targetUnit = unit .. 'target'
	local targetName = UnitName(targetUnit)
	if not targetName then return coloredName end

	-- No frame for the target half: this frame's health bar carries the unit's class color, never the target's.
	return format('%s %s %s', coloredName, UF.TagSeparator, Colored(targetName, SmartColor(targetUnit, nil)))
end)

-- Superseded by the combined name tags, kept registered so existing tag strings keep working.
UF:RegisterTag('NUF:target', L['Target'], nil, 'UNIT_NAME_UPDATE UNIT_TARGET', function(unit)
	return UnitName(unit .. 'target')
end)

-- Health Tags --

-- Smart health tag - shows dead, ghost, offline or current health and percentage with a separator (e.g. '100k » 75%').
UF:RegisterTag('NUF:curhp:perhp', L['Health + Health %'], 'health', 'UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION', function(unit)
	if not unit or not UnitExists(unit) then return '' end
	local unitStatus = UnitIsDead(unit) and DEAD or UnitIsGhost(unit) and L['Ghost'] or not UnitIsConnected(unit) and L['Offline']

	if unitStatus then
		return unitStatus
	else
		return format('%s %s %.0f%%', AbbreviateLargeNumbers(UnitHealth(unit)), UF.TagSeparator, UnitHealthPercent(unit, false, CurveConstants.ScaleTo100))
	end
end)

UF:RegisterTag('NUF:curhp:abbr', L['Health (Short)'], 'health', 'UNIT_HEALTH UNIT_MAXHEALTH', function(unit)
	if not unit or not UnitExists(unit) then return '' end

	return AbbreviateLargeNumbers(UnitHealth(unit))
end)

UF:RegisterTag('NUF:curhp', L['Health'], 'health', 'UNIT_HEALTH UNIT_MAXHEALTH', function(unit)
	if not unit or not UnitExists(unit) then return '' end

	return UnitHealth(unit)
end)

UF:RegisterTag('NUF:perhp', L['Health %'], 'health', 'UNIT_HEALTH UNIT_MAXHEALTH', function(unit)
	if not unit or not UnitExists(unit) then return '' end

	return format('%.f', UnitHealthPercent(unit, false, CurveConstants.ScaleTo100))
end)

UF:RegisterTag('NUF:absorb:abbr', L['Damage Absorb (Short)'], 'health', 'UNIT_ABSORB_AMOUNT_CHANGED', function(unit)
	if not unit or not UnitExists(unit) then return '' end

	return AbbreviateLargeNumbers(UnitGetTotalAbsorbs(unit))
end)

-- Status Tags --

-- Every value the status tag can return, cycled through while previewing.
local PREVIEW_STATUSES = { DEAD, L['Ghost'], L['Offline'], L['DND'], L['AFK'], DEAD .. PLAYER_LIST_DELIMITER .. L['AFK'], }

-- Smart all in one status tag - shows offline alone, otherwise a death state and an away flag, paired when both apply (e.g. 'Dead, AFK').
UF:RegisterTag('NUF:status', L['Status'], 'misc', 'UNIT_HEALTH UNIT_MAXHEALTH PLAYER_FLAGS_CHANGED', function(unit)
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

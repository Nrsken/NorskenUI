---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF
local Tags = oUF.Tags

local format = string.format

local UnitClass = UnitClass
local UnitNameUnmodified = UnitNameUnmodified
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
local AbbreviateLargeNumbers = AbbreviateLargeNumbers
local UnitPowerType = UnitPowerType
local UnitPower = UnitPower
local UnitPowerPercent = UnitPowerPercent

local GetClassColor = C_ClassColor and C_ClassColor.GetClassColor

local DEAD = DEAD

-- Power Tags --

-- Unit power percentage tag (e.g. '0' - '100') colored by power type OR when using classcoloring for health, colored white.
Tags.Events['nrsknuf:perpower:smartcolor'] = 'UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER'
Tags.Methods['nrsknuf:perpower:smartcolor'] = function(unit)
	if not unit or not UnitExists(unit) then return "" end
	local unitPower = UnitPower(unit)
	local powerType = UnitPowerType(unit)
	local health = _FRAME and _FRAME.Health

	local color
	if health and health.nuiColorByClass then
		color = '|cffffffff'
	else
		color = NRSKNUI.Colors.power[powerType] and Hex(NRSKNUI.Colors.power[powerType])
	end

	if unitPower then
		return color .. format("%.f", UnitPowerPercent(unit, nil, true, CurveConstants.ScaleTo100)) .. "|r"
	end
end

-- Color Tags --

-- Smart color tag - colors by class, reaction or status OR when using classcoloring for health, return white.
Tags.Events['nrsknuf:unit:smartcolor'] = 'UNIT_FACTION UNIT_CONNECTION UNIT_NAME_UPDATE PLAYER_FLAGS_CHANGED PARTY_MEMBER_ENABLE PARTY_MEMBER_DISABLE'
Tags.Methods['nrsknuf:unit:smartcolor'] = function(unit)
	local health = _FRAME and _FRAME.Health
	if health and health.nuiColorByClass then
		return '|cffffffff'
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

		if color == nil then
			color = NRSKNUI.Colors.white
		end

		return color:GenerateHexColorMarkup()
	elseif not UnitIsPlayer(unit) and reaction then
		return NRSKNUI.Colors.reaction[reaction] and Hex(NRSKNUI.Colors.reaction[reaction])
	elseif UnitFactionGroup(unit) and UnitIsEnemy(unit, 'player') and UnitIsPVP(unit) then
		return '|cffff0000'
	else
		return '|cffffffff'
	end
end

-- Name Tags --

-- Unit name tag - Unmodified by realm or player status.
Tags.Events['nrsknuf:name'] = 'UNIT_NAME_UPDATE'
Tags.Methods['nrsknuf:name'] = function(unit)
	return UnitNameUnmodified(unit)
end

-- Health Tags --

-- Smart health tag - shows dead, ghost, offline or current health and percentage with a separator (e.g. "100k » 75").
Tags.Events['nrsknuf:curhp:perhp'] = 'UNIT_HEALTH UNIT_MAXHEALTH'
Tags.Methods["nrsknuf:curhp:perhp"] = function(unit)
	if not unit or not UnitExists(unit) then return "" end
	local unitHealth = UnitHealth(unit)
	local unitHealthPercent = UnitHealthPercent(unit, false, CurveConstants.ScaleTo100)
	local unitStatus = UnitIsDead(unit) and DEAD or UnitIsGhost(unit) and "Ghost" or not UnitIsConnected(unit) and "Offline"
	if unitStatus then
		return unitStatus
	else
		return format("%s %s %.0f%%", AbbreviateLargeNumbers(unitHealth), UF.TagSeparator, unitHealthPercent)
	end
end

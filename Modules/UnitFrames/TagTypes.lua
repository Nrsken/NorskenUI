---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFrames
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF
local Tags = oUF.Tags

local format = string.format

local UnitClass = UnitClass
local UnitNameUnmodified = UnitNameUnmodified
local UnitClassification = UnitClassification
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
local UnitHasIncomingResurrection = UnitHasIncomingResurrection
local IsResting = IsResting
local AbbreviateLargeNumbers = AbbreviateLargeNumbers
local UnitPowerType = UnitPowerType
local UnitPower = UnitPower
local UnitPowerPercent = UnitPowerPercent

local UnitIsRelatedToActiveQuest = C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest
local IncomingSummonStatus = C_IncomingSummon and C_IncomingSummon.IncomingSummonStatus
local TruncateWhenZero = C_StringUtil and C_StringUtil.TruncateWhenZero

local SummonStatus = Enum and Enum.SummonStatus

local DEAD = DEAD

-- Power Tags --

-- Unit power percentage tag (e.g. '0' - '100')
Tags.Events['nrsknuf:perpower'] = 'UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER'
Tags.Methods['nrsknuf:perpower'] = function(unit)
	if not unit or not UnitExists(unit) then return "" end
	local unitPower = UnitPower(unit)
	if unitPower then
		local powerPercent = UnitPowerPercent(unit, nil, true, CurveConstants.ScaleTo100)
		return format("%.f", powerPercent)
	end
end

-- Unit power percentage tag (e.g. '0' - '100') colored by power type.
Tags.Events['nrsknuf:perpower:color'] = 'UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER'
Tags.Methods['nrsknuf:perpower:color'] = function(unit)
	if not unit or not UnitExists(unit) then return "" end
	local unitPower = UnitPower(unit)
	local powerType = UnitPowerType(unit)
	if unitPower then
		return Hex(NRSKNUI.Colors.power[powerType]) .. format("%.f", UnitPowerPercent(unit, nil, true, CurveConstants.ScaleTo100)) .. "|r"
	end
end

-- Color Tags --

-- Smart color tag - colors by class, reaction or status OR when using classcoloring for health, return white.
Tags.Events['nrsknuf:smartcolor'] = 'UNIT_FACTION UNIT_CONNECTION UNIT_NAME_UPDATE PLAYER_FLAGS_CHANGED PARTY_MEMBER_ENABLE PARTY_MEMBER_DISABLE'
Tags.Methods['nrsknuf:smartcolor'] = function(unit)
	local health = _FRAME and _FRAME.Health
	if health and health.nuiColorByClass then
		return '|cffffffff'
	end

	local reaction = UnitReaction(unit, 'player')
	if UnitIsTapDenied(unit) or not UnitIsConnected(unit) then
		return '|cff999999'
	elseif UnitIsPlayer(unit) or UnitTreatAsPlayerForDisplay(unit) then
		local _, classToken = UnitClass(unit)
		return NRSKNUI.Colors.class[classToken] and Hex(NRSKNUI.Colors.class[classToken])
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

-- Indicator Tags --

-- Resting texture, IsResting is player-state (unitless), so only place it on the player frame.
Tags.Events['nrsknuf:resting'] = 'PLAYER_UPDATE_RESTING'
Tags.Methods['nrsknuf:resting'] = function()
	if IsResting() then
		return [[|TInterface\HUD\UIUnitFrameRestingFlipbook:16:16:0:0:360:420:45:80:200:240|t]]
	end
end

-- Incoming warlock/summon status.
Tags.Events['nrsknuf:summon'] = 'INCOMING_SUMMON_CHANGED'
Tags.Methods['nrsknuf:summon'] = function(unit)
	local summonStatus = IncomingSummonStatus(unit)
	if summonStatus == SummonStatus.Pending then
		return '|A:RaidFrame-Icon-SummonPending:16:16|a'
	elseif summonStatus == SummonStatus.Accepted then
		return '|A:RaidFrame-Icon-SummonPending:32:32:0:0:0:255:0|a'
	elseif summonStatus == SummonStatus.Declined then
		return '|A:RaidFrame-Icon-SummonPending:32:32:0:0:255:0:0|a'
	end
end

-- Incoming resurrection.
Tags.Events['nrsknuf:resurrect'] = 'INCOMING_RESURRECT_CHANGED UNIT_HEALTH'
Tags.Methods['nrsknuf:resurrect'] = function(unit)
	if UnitHasIncomingResurrection(unit) then
		return '|A:RaidFrame-Icon-Rez:22:22|a'
	end
end

-- Unit is tied to one of the player's active quests.
Tags.Events['nrsknuf:quest'] = 'QUEST_LOG_UPDATE'
Tags.Methods['nrsknuf:quest'] = function(unit)
	if UnitIsRelatedToActiveQuest(unit) then
		return '|A:Crosshair_legendaryquest_32:16:16|a'
	end
end

-- Unitless events carry no unitID, so oUF needs them registered as shared.
Tags.SharedEvents.PLAYER_UPDATE_RESTING = true
Tags.SharedEvents.QUEST_LOG_UPDATE = true

local _, ns = ...
local oUF = ns.oUF
local Private = oUF.Private

function Private.argcheck(value, num, ...)
	assert(type(num) == 'number', "Bad argument #2 to 'argcheck' (number expected, got " .. type(num) .. ')')

	for i = 1, select('#', ...) do
		if(type(value) == select(i, ...)) then return end
	end

	local types = string.join(', ', ...)
	local name = debugstack(2,2,0):match(": in function [`<](.-)['>]")
	error(string.format("Bad argument #%d to '%s' (%s expected, got %s)", num, name, types, type(value)), 3)
end

function Private.print(...)
	print('|cff33ff99oUF:|r', ...)
end

local function nierror(...)
	return geterrorhandler()(...)
end
Private.nierror = nierror

function Private.xpcall(func, ...)
	return xpcall(func, Private.nierror, ...)
end

function Private.unitExists(unit)
	return unit and (UnitExists(unit) or UnitIsVisible(unit))
end

function Private.unitIsUnit(unit1, unit2)
	-- TODO: use C_Secrets.CanCompareUnitTokens instead of pcall
	local isOk, isUnit = pcall(UnitIsUnit, unit1, unit2)
	return isOk and isUnit
end

local validator = CreateFrame('Frame')

function Private.validateEventUnit(unit)
	local isOK, _ = pcall(validator.RegisterUnitEvent, validator, 'UNIT_HEALTH', unit)
	if(isOK) then
		_, unit = validator:IsEventRegistered('UNIT_HEALTH')
		validator:UnregisterEvent('UNIT_HEALTH')

		return not not unit
	end
end

function Private.validateEvent(event)
	local isOK = xpcall(validator.RegisterEvent, Private.nierror, validator, event)
	if(isOK) then
		validator:UnregisterEvent(event)
	end

	return isOK
end

function Private.isUnitEvent(event, unit)
	local isOK = pcall(validator.RegisterUnitEvent, validator, event, unit)
	if(isOK) then
		validator:UnregisterEvent(event)
	end

	return isOK
end

local validSelectionTypes = {}
for _, selectionType in next, oUF.Enum.SelectionType do
	validSelectionTypes[selectionType] = selectionType
end

function Private.unitSelectionType(unit, considerHostile)
	if(considerHostile and UnitThreatSituation('player', unit)) then
		return 0
	else
		return validSelectionTypes[UnitSelectionType(unit, true)]
	end
end

-- aura containers can't be created during combat, so for any dynamically created unit frames like
-- nameplates or group headers we need to pre-allocate aura containers during load.
-- since we can't know how many aura containers any given layout will need we expose an API to
-- adjust the number of pre-allocated aura containers to create, proxying to an internal API for
-- creating and consuming the allocated aura containers.
-- while (obvioysly) ugly/hacky, this works fine, with the one exception that layouts have no way to
-- use custom templates for the aura containers. hopefully blizzard solves this in the future.
local availableAuraContainers = {}
local function createContainer(parentName, index)
	local containerName = parentName .. 'AuraContainer' .. index
	return CreateFrame('AuraContainer', containerName, nil, 'CustomAuraContainerTemplate')
end

function Private.AllocateAuraContainers(frameNamePrefix, numFrames, numContainers)
	for frameIndex = 1, numFrames do
		local frameName = frameNamePrefix .. frameIndex
		if(not availableAuraContainers[frameName]) then
			availableAuraContainers[frameName] = {}
		end

		local existing = table.count(availableAuraContainers[frameName])
		local start = existing + 1
		local missing = numContainers - start
		for containerIndex = start, start + missing do
			local container = createContainer(frameName, containerIndex)
			availableAuraContainers[frameName][container] = true
		end
	end
end

function Private.GetOrCreateAuraContainer(frame)
	local frameName = frame:GetName()
	if(not availableAuraContainers[frameName]) then
		availableAuraContainers[frameName] = {}
	end

	local containers = availableAuraContainers[frameName]
	if(containers) then
		for container, available in next, containers do
			if(available == true) then
				availableAuraContainers[frameName][container] = false

				-- we can adjust the parent freely, even in combat
				container:SetParent(frame)
				return container
			end
		end
	end

	if(InCombatLockdown()) then
		nierror(string.format('Can\'t create aura container in combat for frame "%s".', frameName))
		return
	end

	local container = createContainer(frameName, table.count(containers) + 1)
	container:SetParent(frame)
	availableAuraContainers[frameName][container] = false -- mark as unavailable
	return container
end

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL

local GetNumGroupMembers = GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local tonumber = tonumber
local pairs = pairs
local ipairs = ipairs
local min, max = math.min, math.max

UF.MAX_BOSS_FRAMES = 8
UF.BossUnits = {}
for index = 1, UF.MAX_BOSS_FRAMES do
    UF.BossUnits[index] = 'boss' .. index
end

UF.RaidTiers = { 'raid1', 'raid2', 'raid3' }

UF.GroupUnits = { 'party' }
for _, tier in ipairs(UF.RaidTiers) do
    UF.GroupUnits[#UF.GroupUnits + 1] = tier
end

UF.GroupConfigs = {}
for _, unit in ipairs(UF.GroupUnits) do
    UF.GroupConfigs[unit] = true
end

UF.MAX_RAID_GROUPS = 8
UF.GroupCounts = { party = 1 }
for _, tier in ipairs(UF.RaidTiers) do
    UF.GroupCounts[tier] = UF.MAX_RAID_GROUPS
end

UF.SoloUnits = { 'player', 'target', 'targettarget', 'focus', 'focustarget', 'pet', 'pettarget' }
UF.Units = {}
for _, unit in ipairs(UF.SoloUnits) do
    UF.Units[#UF.Units + 1] = unit
end

UF.Units[#UF.Units + 1] = 'boss'
for _, unit in ipairs(UF.GroupUnits) do
    UF.Units[#UF.Units + 1] = unit
end

UF.UnitLabels = { player = L['Player'], target = L['Target'], targettarget = L['Target of Target'], focus = L['Focus'], focustarget = L['Focus Target'], pet = L['Pet'], pettarget = L['Pet Target'], boss = L['Boss'], party = L['Party'], raid1 = L['Raid 1'], raid2 = L['Raid 2'], raid3 = L['Raid 3'], }
UF.NoPower = { targettarget = true, focustarget = true, pettarget = true, }
UF.GROUP_SIZE = 5
UF.frames = UF.frames or {}
UF.groups = UF.groups or {}
UF.BaseLevels = { Background = 1, Bar = 2, }
UF.Layers = { Min = 1, Max = 12, Highlight = 9, Border = 10, }
UF.ReservedLayers = { [UF.Layers.Highlight] = true, [UF.Layers.Border] = true, }
UF.TopLevels = { Tags = 999, Auras = 1000, RaidMark = 1001, Status = 1002, }

---Resolve a layer on UF.Layers to a concrete frame level for a unit frame.
---@param frame oUF.UnitFrame
---@param layer number
---@return number level
function UF.GetLayerLevel(frame, layer)
    local layers = UF.Layers
    return frame:GetFrameLevel() + UF.BaseLevels.Bar + min(max(layer, layers.Min), layers.Max)
end

---Resolve an aura attach target to a region on a frame.
---@param frame oUF.UnitFrame
---@param attach string
---@return Region?
function UF.ResolveAttachTarget(frame, attach)
    local targets = NRSKNUI.AuraIndicators.Attach

    if attach == targets.Health then
        return frame.Health
    elseif attach == targets.HealthFill then
        return frame.Health and frame.Health:GetStatusBarTexture()
    end

    return frame
end

---Normalize a unit string to its base archetype, stripping any numeric suffixes.
---@param unit string
---@return string base
function UF.NormalizeUnit(unit)
    return (unit:gsub('%d+$', ''))
end

---The config key a unit token or group config resolves to.
---@param unit string
---@return string
function UF.ConfigKey(unit)
    -- Normalizing would strip the digits that tell the raid tiers apart.
    if UF.GroupConfigs[unit] then return unit end
    return UF.NormalizeUnit(unit)
end

---Get the unit DB for a unit token or a group config key.
---@param unit string
---@return table
function UF.GetUnitDB(unit)
    return UF.db.Units[UF.ConfigKey(unit)]
end

---The first `count` subgroups, for the layouts that draw a fixed number of them.
---@param count number
---@return number[] subgroups
local function FirstSubgroups(count)
    local subgroups = {}
    for subgroup = 1, count do
        subgroups[subgroup] = subgroup
    end
    return subgroups
end

---Which subgroups a group's headers draw, in ascending order and one header each.
---@param key string config key
---@param gDB table the config's Group block
---@return number[] subgroups
function UF.ActiveSubgroups(key, gDB)
    local built = UF.GroupCounts[key] or 1
    if built == 1 then return FirstSubgroups(1) end

    if not gDB.AutoGroups then
        return FirstSubgroups(min(max(gDB.NumGroups or built, 1), built))
    end

    -- No roster to read, so fall back to the wrap width: the tier's expected subgroup count.
    if UF:IsGroupSizedFull(key) then
        return FirstSubgroups(min(max(gDB.GroupsPerRowColumn or built, 1), built))
    end

    local occupied = {}
    for index = 1, GetNumGroupMembers() do
        local _, _, subgroup = GetRaidRosterInfo(index)
        -- nil outside a raid, where the party config draws the group instead.
        if subgroup then occupied[subgroup] = true end
    end

    local subgroups = {}
    for subgroup = 1, built do
        if occupied[subgroup] then subgroups[#subgroups + 1] = subgroup end
    end

    -- Nothing to read yet, on a roster event that beat the roster in. One header keeps the layout alive.
    if not subgroups[1] then subgroups[1] = 1 end

    return subgroups
end

---Visit every constructed frame, singletons then group header children.
---@param fn fun(frame: oUF.UnitFrame, unit: string) unit is what ConfigureFrame takes: a token for singletons, a config key for header children
---@param configKey string? restrict the walk to one config
function UF:ForEachFrame(fn, configKey)
    for unit, frame in pairs(UF.frames) do
        if not configKey or UF.ConfigKey(unit) == configKey then
            fn(frame, unit)
        end
    end

    for key, group in pairs(UF.groups) do
        if not configKey or key == configKey then
            for _, header in ipairs(group.headers) do
                local index = 1
                local child = header:GetAttribute('child' .. index)
                while child do
                    fn(child, key)
                    index = index + 1
                    child = header:GetAttribute('child' .. index)
                end
            end
        end
    end
end

---The 1-based position of a boss unit in the chain, nil for anything else.
---@param unit string
---@return number? index
function UF.BossIndex(unit)
    return tonumber(unit:match('^boss(%d+)$'))
end

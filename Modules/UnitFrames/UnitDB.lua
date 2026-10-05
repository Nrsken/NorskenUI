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
-- Each layer is a band of Step levels so multi-frame elements stay inside their own band.
UF.Layers = { Min = 1, Max = 40, Step = 20, }

-- Aura indicator spots split into a tint and an icon group by style, ordered per unit inside it.
UF.LayerElements = {
    { key = 'IndicatorTints', label = L['Indicator Tints'] },
    { key = 'Power',        label = L['Power'] },
    { key = 'Castbar',      label = L['Castbar'] },
    { key = 'Dispel',       label = L['Dispel Highlight'] },
    { key = 'HealPrediction', label = L['Heal Prediction'] },
    { key = 'DamageAbsorb', label = L['Damage Absorb'] },
    { key = 'HealAbsorb',   label = L['Heal Absorb'] },
    { key = 'Highlight',    label = L['Mouseover Highlight'] },
    { key = 'Border',       label = L['Border'] },
    { key = 'Tags',         label = L['Tags'] },
    { key = 'Buffs',        label = L['Aura Buffs'] },
    { key = 'Debuffs',      label = L['Aura Debuffs'] },
    { key = 'Defensives',   label = L['Aura Defensives'] },
    { key = 'IndicatorIcons', label = L['Indicator Icons'] },
    { key = 'RaidMark',     label = L['Raid Icon'] },
    { key = 'Status',       label = L['Status Icons'] },
}

---@return table layers
function UF.GetLayerMap()
    return UF.db.General.Layers
end

---Resolve a layer to the bottom frame level of its band on a unit frame.
---@param frame oUF.UnitFrame
---@param layer number
---@return number level
function UF.GetLayerLevel(frame, layer)
    local layers = UF.Layers
    return frame:GetFrameLevel() + UF.BaseLevels.Bar + min(max(layer, layers.Min), layers.Max) * layers.Step
end

---@param frame oUF.UnitFrame
---@param key string a UF.LayerElements key
---@return number level
function UF.GetElementLevel(frame, key)
    return UF.GetLayerLevel(frame, UF.GetLayerMap()[key])
end

---Tints draw low; icons, textures and text draw high.
---@param placement table
---@return string key a UF.LayerElements key
function UF.IndicatorGroup(placement)
    return placement.Style == NRSKNUI.AuraIndicators.Styles.Overlay and 'IndicatorTints' or 'IndicatorIcons'
end

---Two levels per same-group spot ordered below this one, capped at the band.
---@param frame oUF.UnitFrame
---@param placements table[] the unit's spots
---@param placement table
---@return number level
function UF.GetIndicatorLevel(frame, placements, placement)
    local group = UF.IndicatorGroup(placement)
    local order = placement.Order or 0
    local below = 0
    for _, other in ipairs(placements) do
        if other ~= placement and UF.IndicatorGroup(other) == group and (other.Order or 0) < order then
            below = below + 1
        end
    end
    return UF.GetElementLevel(frame, group) + min(below * 2, UF.Layers.Step - 2)
end

---Dispel and aura indicator slots are built once and take their level at build time instead.
---@param frame oUF.UnitFrame
---@param map table a layer map
function UF.ApplyFrameLayers(frame, map)
    local function Level(key) return UF.GetLayerLevel(frame, map[key]) end

    local health = frame.Health
    if health then
        local damage = Level('DamageAbsorb')
        health.nuiHealAbsorb:SetFrameLevel(Level('HealAbsorb'))
        health.nuiDamageAbsorb:SetFrameLevel(damage)
        health.nuiHealingAll:SetFrameLevel(Level('HealPrediction'))
        -- The over-absorb pair belongs to the damage absorb and rides its layer.
        health.OverDamageAbsorbClip:SetFrameLevel(damage)
        health.OverDamageAbsorb:SetFrameLevel(damage)
        frame.nuiHighlightFrame:SetFrameLevel(Level('Highlight'))
        frame.healthBorderFrame:SetFrameLevel(Level('Border'))
    end

    if frame.Power then
        local level = Level('Power')
        frame.powerBackground:SetFrameLevel(level)
        frame.Power:SetFrameLevel(level + 1)
        frame.powerBorderFrame:SetFrameLevel(level + 2)
    end

    if frame.CastbarContainer then
        local level = Level('Castbar')
        frame.CastbarContainer:SetFrameLevel(level)
        frame.Castbar:SetFrameLevel(level + 1)
    end

    if frame.TagContainer then frame.TagContainer:SetFrameLevel(Level('Tags')) end

    if frame.IndicatorContainer then
        frame.IndicatorContainer:SetFrameLevel(Level('Status'))
        for key, host in pairs(frame.nuiIndicatorHosts) do
            host:SetFrameLevel(Level(key))
        end
    end

    for kind, container in pairs(frame.Auras or {}) do
        container:SetFrameLevel(Level(kind))
    end
end

---Resolve an aura attach target to a region on a frame.
---@param frame oUF.UnitFrame
---@param attach string
---@return Region?
function UF.ResolveAttachTarget(frame, attach)
    local targets = NRSKNUI.AuraIndicators.Attach

    if attach == targets.HealthFill then
        return frame.Health and frame.Health:GetStatusBarTexture()
    end

    -- Nothing may cover a docked power bar, so the old Whole Frame resolves to the health area too.
    return frame.Health or frame
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

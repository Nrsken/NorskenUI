---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL

local tonumber = tonumber
local pairs = pairs
local ipairs = ipairs
local min, max = math.min, math.max

UF.MAX_BOSS_FRAMES = 8
UF.BossUnits = {}
for index = 1, UF.MAX_BOSS_FRAMES do UF.BossUnits[index] = 'boss' .. index end

UF.GroupUnits = { 'party' }
UF.GroupConfigs = {}
for _, unit in ipairs(UF.GroupUnits) do UF.GroupConfigs[unit] = true end

UF.SoloUnits = { 'player', 'target', 'targettarget', 'focus', 'focustarget', 'pet', 'pettarget' }
UF.Units = {}
for _, unit in ipairs(UF.SoloUnits) do UF.Units[#UF.Units + 1] = unit end

UF.Units[#UF.Units + 1] = 'boss'
for _, unit in ipairs(UF.GroupUnits) do UF.Units[#UF.Units + 1] = unit end

UF.UnitLabels = { player = L['Player'], target = L['Target'], targettarget = L['Target of Target'], focus = L['Focus'], focustarget = L['Focus Target'], pet = L['Pet'], pettarget = L['Pet Target'], boss = L['Boss'], party = L['Party'], }
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

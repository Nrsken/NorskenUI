---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
---@field SoloUnits UnitFramesSoloUnits
---@field BossUnits UnitFramesBossUnits
---@field MAX_BOSS_FRAMES UnitFramesMaxBossFrames
---@field GroupConfigs table<string, boolean>
---@field GROUP_SIZE number
---@field frames table<string, oUF.UnitFrame>
---@field groups table<string, UnitFramesGroup>
---@field BaseLevels { Background: number, Bar: number }
---@field Layers { Min: number, Max: number, Highlight: number, Border: number }
---@field ReservedLayers table<number, boolean>
---@field TopLevels { Tags: number, Auras: number, RaidMark: number, Status: number }
local UF = NRSKNUI:GetModule('UnitFrames')

local tonumber = tonumber
local pairs = pairs
local ipairs = ipairs
local min, max = math.min, math.max

---@class UnitFramesSoloUnits
---@field player string
---@field target string
---@field targettarget string
---@field focus string
---@field focustarget string
---@field pet string
---@field pettarget string
UF.SoloUnits = {
    'player',
    'target',
    'targettarget',
    'focus',
    'focustarget',
    'pet',
    'pettarget',
}

---@class UnitFramesMaxBossFrames
---@field MAX_BOSS_FRAMES number
UF.MAX_BOSS_FRAMES = 8

---@class UnitFramesBossUnits
---@field boss1 string
---@field boss2 string
---@field boss3 string
---@field boss4 string
---@field boss5 string
---@field boss6 string
---@field boss7 string
---@field boss8 string
UF.BossUnits = {}
for index = 1, UF.MAX_BOSS_FRAMES do
    UF.BossUnits[index] = 'boss' .. index
end

-- Header-driven units, keyed by config key: raid1..raid3 would collide with raid unit tokens.
UF.GroupConfigs = {
    party = true,
}

UF.GROUP_SIZE = 5 -- units per header column, i.e. one raid group

UF.frames = UF.frames or {} -- unit token -> oUF object, singleton units only
UF.groups = UF.groups or {} -- config key -> { container, headers }, see Groups.lua

-- Below the layer scale and not user-selectable, relative to the unit frame.
UF.BaseLevels = {
    Background = 1,
    Bar = 2,
}

-- The user-selectable band. Layer N resolves to the unit frame's level + BaseLevels.Bar + N.
UF.Layers = {
    Min = 1,
    Max = 12,
    Highlight = 9, -- reserved, mouseover highlight
    Border = 10,   -- reserved, frame border
}

-- Layers the user must not claim, since the frame's own chrome owns them.
UF.ReservedLayers = {
    [UF.Layers.Highlight] = true,
    [UF.Layers.Border] = true,
}

-- Absolute levels for what draws above every unit frame layer, in ascending order.
UF.TopLevels = {
    Tags = 999,
    Auras = 1000,
    RaidMark = 1001,
    Status = 1002,
}

---Resolve a layer on UF.Layers to a concrete frame level for a unit frame.
---@param frame oUF.UnitFrame
---@param layer number
---@return number level
function UF.GetLayerLevel(frame, layer)
    local layers = UF.Layers
    return frame:GetFrameLevel() + UF.BaseLevels.Bar + min(max(layer, layers.Min), layers.Max)
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

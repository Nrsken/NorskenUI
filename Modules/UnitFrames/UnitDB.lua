---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
---@field SoloUnits UnitFramesSoloUnits
---@field BossUnits UnitFramesBossUnits
---@field MAX_BOSS_FRAMES UnitFramesMaxBossFrames
---@field BaseLevels { Background: number, Bar: number }
---@field Layers { Min: number, Max: number, Highlight: number, Border: number }
---@field ReservedLayers table<number, boolean>
---@field TopLevels { Tags: number, RaidMark: number, Status: number }
local UF = NRSKNUI:GetModule('UnitFrames')

local tonumber = tonumber
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
    RaidMark = 1000,
    Status = 1001,
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

---Get the unit DB for a given unit.
---@param unit string
---@return table
function UF.GetUnitDB(unit)
    return UF.db.Units[UF.NormalizeUnit(unit)]
end

---The 1-based position of a boss unit in the chain, nil for anything else.
---@param unit string
---@return number? index
function UF.BossIndex(unit)
    return tonumber(unit:match('^boss(%d+)$'))
end

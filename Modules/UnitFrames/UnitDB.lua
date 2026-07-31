---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
---@field SoloUnits UnitFramesSoloUnits
---@field BossUnits UnitFramesBossUnits
---@field MAX_BOSS_FRAMES UnitFramesMaxBossFrames
local UF = NRSKNUI:GetModule('UnitFrames')

local tonumber = tonumber

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

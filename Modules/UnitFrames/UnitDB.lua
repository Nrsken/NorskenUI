---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFrames
---@field SoloUnits string[]
local UF = NRSKNUI:GetModule('UnitFrames')

UF.SoloUnits = {
    'player',
    'target',
    'targettarget',
    'focus',
    'focustarget',
    'pet',
    'pettarget',
}

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

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')

local NO_POWER = UF.NoPower

---Build the oUF style for a unit frame, constructing and configuring elements as needed.
---@param frame oUF.UnitFrame
---@param unit string oUF's guessed unit; for a header child this is the archetype, not the config key
function UF:BuildStyle(frame, unit)
    frame.nrsknUnit = unit

    -- A header stamps its own config key, since oUF guesses 'raid' for every tier.
    local parent = frame:GetParent()
    local base = parent and parent.nrsknConfig or UF.ConfigKey(unit)

    frame.nuiConfig = base
    frame.nuiGroupChild = UF.GroupConfigs[base] or nil

    frame:RegisterForClicks('AnyUp') -- oUF doesn't register for clicks by default, so we do it here.

    self:ConstructElement('Health', frame, base)
    self:ConstructElement('Tags', frame, base)
    self:ConstructElement('Indicators', frame, base)
    self:ConstructElement('Auras', frame, base)
    self:ConstructElement('AuraIndicators', frame, base)
    self:ConstructElement('Dispel', frame, base)
    self:ConstructElement('Range', frame, base)
    if not NO_POWER[base] then
        self:ConstructElement('Power', frame, base)
    end
    -- Group units are deliberately castbar-free.
    if not NO_POWER[base] and not frame.nuiGroupChild then
        self:ConstructElement('Castbar', frame, base)
    end

    self:ConfigureFrame(frame, unit)
    frame.nuiBuilt = true -- oUF finishes building and auto-enables elements after this returns.
end

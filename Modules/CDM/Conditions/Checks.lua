---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local UnitCanAttack = UnitCanAttack
local UnitExists = UnitExists

-- Each trigger file adds its own checks here; 'secret' ones never run, they're applied onto the aura's button.
---@type table<string, table<string, { type: 'bool'|'number'|'select', secret?: boolean, get?: (fun(layer: CDMLayer, trigger: table, pip: CDMPip?): any), match?: (fun(value: any): boolean), options?: string }>>
CDM.ConditionChecks = {}

-- WeakAuras' global conditions, under trigger index 0.
CDM.ConditionChecks.global = {
    combat     = { type = 'bool', get = function() return CDM.inCombat == true end },
    hasTarget  = { type = 'bool', get = function() return UnitExists('target') == true end },
    attackable = { type = 'bool', get = function() return UnitCanAttack('player', 'target') == true end },
}

-- Group conditions, under trigger index -1. A select check matches its picked value.
CDM.ConditionChecks.group = {
    classInGroup = { type = 'select', options = 'class', match = function(class) return NRSKNUI:IsClassInGroup(class) end },
}

CDM.GLOBAL_TRIGGER = { Type = 'global' }
CDM.GROUP_TRIGGER = { Type = 'group' }

---The trigger a check reads: one of the icon's, the global pseudo-trigger at index 0 or the group one at -1.
---@param display table
---@param index number?
---@return table?
function CDM:GetCheckTrigger(display, index)
    if index == 0 then return self.GLOBAL_TRIGGER end
    if index == -1 then return self.GROUP_TRIGGER end
    return index and display.Triggers[index]
end

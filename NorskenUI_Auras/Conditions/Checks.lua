---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

--[[
What a condition can check on each trigger type and how it reads the answer.
A trigger type adds its own checks to CDM.ConditionChecks.
A curve check reads a secret time, percent or stack count, so we never run it ourselves: its Text Color changes become a curve or count formatter the game evaluates.
]]

local LoadConditions = NRSKNUI.LoadConditions
local UnitCanAttack = UnitCanAttack
local UnitExists = UnitExists
local pairs = pairs

---@type table<string, table<string, { type: 'bool'|'number'|'select', secret?: boolean, curve?: boolean, talents?: boolean, get?: (fun(layer: CDMLayer, trigger: table, pip: CDMPip?): any), match?: (fun(value: any, layer: CDMLayer?, check: table): boolean), options?: string }>>
CDM.ConditionChecks = {}

CDM.ConditionChecks.global = {
    combat     = { type = 'bool', get = function() return CDM.inCombat == true end },
    hasTarget  = { type = 'bool', get = function() return UnitExists('target') == true end },
    attackable = { type = 'bool', get = function() return UnitCanAttack('player', 'target') == true end },
}

-- Player/Unit checks; spec and talents can't change in combat, so a group can move on them.
CDM.ConditionChecks.group = {
    classInGroup = { type = 'select', options = 'class', match = function(class) return NRSKNUI:IsClassInGroup(class) end },
    spec = { type = 'select', options = 'spec', match = function(specID) return LoadConditions:GetSpecID() == specID end },
    -- check.entries holds the picks: [entryID] = true must have, false must not
    talent = {
        type = 'select',
        options = 'spec',
        talents = true,
        match = function(specID, _, check)
            if LoadConditions:GetSpecID() ~= specID then return false end
            for entryID, wanted in pairs(check.entries or {}) do
                if LoadConditions:HasTalent(entryID) ~= wanted then return false end
            end
            return true
        end,
    },
}

-- What a group's conditions can check: nothing that flips in combat, where a group holding aura buttons can't move.
CDM.GROUP_CHECKS = { spec = true, talent = true }

-- Stand-in triggers, so a global or group check finds its checks through Type like any trigger.
CDM.GLOBAL_TRIGGER = { Type = 'global' }
CDM.GROUP_TRIGGER = { Type = 'group' }

---The trigger a check reads; 0 is global, -1 is group.
---@param display table
---@param index number?
---@return table?
function CDM:GetCheckTrigger(display, index)
    if index == 0 then
        return self.GLOBAL_TRIGGER
    end
    if index == -1 then
        return self.GROUP_TRIGGER
    end

    return index and display.Triggers and display.Triggers[index] -- a group has no triggers
end

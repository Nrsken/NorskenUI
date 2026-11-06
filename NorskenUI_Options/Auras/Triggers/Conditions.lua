---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenAuras') then return end
local L = NRSKNUI.Libs.AL
local rowH = NRSKNUI.Theme.rowHeight

local ipairs, pairs = ipairs, pairs
local wipe = wipe

local Shared = NRSKNUI.CDMOptions
local TriggerRows = Shared.TriggerRows

local TICK_ROW_HEIGHT = 24
local DROPDOWN_BOX_OFFSET = -16 -- level with a Dropdown's box, which sits under the space for its label
local GROUP_TYPES = {
    { value = 'solo',  text = L['Solo'] },
    { value = 'party', text = L['Party'] },
    { value = 'raid',  text = L['Raid'] },
}

function TriggerRows.conditions(card, _, _, trigger, _, apply)
    local conditions = trigger.Conditions
    local states = conditions.State

    local list = NRSKNUI.LoadConditions.STATES
    for i = 1, #list, 2 do
        local row = card:Row(TICK_ROW_HEIGHT, 0)
        for _, state in ipairs({ list[i], list[i + 1] }) do
            row:SlimCheckbox(L[state.label], {
                width = 0.5,
                tristate = true,
                value = states[state.key],
                callback = function(value)
                    states[state.key] = value
                    apply()
                end,
            })
        end
    end

    local group = conditions.Group
    local groupRow = card:Row(group and rowH or TICK_ROW_HEIGHT, 0)
    groupRow:SlimCheckbox(L['Group Type'], {
        width = 0.5,
        yOffset = group and DROPDOWN_BOX_OFFSET or nil,
        value = group ~= nil,
        callback = function(checked)
            conditions.Group = checked and { Types = {} } or nil
            apply()
            card:Rebuild()
        end,
    })
    if not group then return end

    -- the dropdown reads a list of picks where the condition keeps a set
    local picked = {}
    for groupType in pairs(group.Types) do
        picked[#picked + 1] = groupType
    end

    groupRow:Dropdown(nil, {
        width = 0.5,
        multiSelect = true,
        options = GROUP_TYPES,
        value = picked,
        callback = function(values)
            wipe(group.Types)
            for _, groupType in ipairs(values) do
                group.Types[groupType] = true
            end
            apply()
        end,
    })
end

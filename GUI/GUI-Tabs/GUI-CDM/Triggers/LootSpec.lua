---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local Shared = NRSKNUI.CDMOptions
local TriggerRows = Shared.TriggerRows

local CURRENT_SPEC = {
    { value = 'any',     text = L['Any'] },
    { value = 'current', text = L['Current Spec'] },
    { value = 'other',   text = L['Not Current Spec'] },
}

function TriggerRows.lootSpec(card, typeRow, display, trigger, id, apply)
    typeRow:Dropdown(L['Loot Specialization'], {
        width = 0.5,
        multiSelect = true,
        tooltip = L['Active while the loot specialization is one of these. None picked is any.'],
        options = NRSKNUI.CDMConditionsTab.SELECT_OPTIONS.spec,
        value = trigger.SpecIDs,
        callback = function(value)
            trigger.SpecIDs = value
            apply()
        end,
    })

    local currentRow = card:Row(rowH)
    currentRow:Dropdown(L['Current Specialization'], {
        width = 0.5,
        tooltip = L['Whether loot goes to the spec you are playing. Loot set to Current Specialization always is.'],
        options = CURRENT_SPEC,
        value = trigger.CurrentSpec or 'any',
        callback = function(value)
            trigger.CurrentSpec = value ~= 'any' and value or nil
            apply()
        end,
    })
end

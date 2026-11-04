---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Auras') then return end
local L = NRSKNUI.Libs.AL

local Shared = NRSKNUI.CDMOptions
local TriggerRows = Shared.TriggerRows

local HUNT_TEXTS = {
    { value = 'title', text = L['Quest Title'] },
    { value = 'state', text = L['Progress State'] },
    { value = 'hint',  text = L['Hunt Hint'] },
}

function TriggerRows.prey(_, typeRow, _, trigger, _, apply)
    typeRow:Dropdown(L['Text'], {
        width = 0.5,
        tooltip = L['What %n shows. The state and hint are only known inside the hunt zone.'],
        options = HUNT_TEXTS,
        value = trigger.Text or 'title',
        callback = function(value)
            trigger.Text = value ~= 'title' and value or nil
            apply()
        end,
    })
end

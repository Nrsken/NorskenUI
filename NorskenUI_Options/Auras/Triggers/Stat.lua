---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenAuras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

local ipairs = ipairs

local Shared = NRSKNUI.CDMOptions
local TriggerRows = Shared.TriggerRows

function TriggerRows.stat(card, typeRow, display, trigger, id, apply)
    local options = {}
    for _, stat in ipairs(CDM.STATS) do options[#options + 1] = { value = stat.key, text = stat.name } end
    typeRow:Dropdown(L['Stat'], {
        width = 1,
        tooltip = L['%p is the percent, %t the rating, as the character sheet shows them. Versatility is its rating part.'],
        options = options,
        value = trigger.Stat or 'haste',
        callback = function(value)
            trigger.Stat = value
            apply()
        end,
    })
end

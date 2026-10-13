---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local tostring = tostring
local tonumber = tonumber

local Shared = NRSKNUI.CDMOptions
local TriggerRows = Shared.TriggerRows

function TriggerRows.timer(card, typeRow, display, trigger, id, apply)
    typeRow:EditBox(L['Spell ID'], {
        width = 0.5,
        tooltip = L['The timer starts when you cast this spell.'],
        value = trigger.SpellID and tostring(trigger.SpellID) or '',
        callback = function(text)
            trigger.SpellID = tonumber(text)
            apply()
            card:Rebuild()
        end,
    })
    card:Row(rowH):Slider(L['Duration'], {
        width = 0.5,
        min = 1,
        max = 60,
        step = 0.5,
        value = trigger.Duration,
        callback = function(value)
            trigger.Duration = value
            apply()
        end,
    })
end

---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local tconcat = table.concat
local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber

local Shared = NRSKNUI.CDMOptions
local TriggerRows = Shared.TriggerRows

function TriggerRows.cast(card, typeRow, display, trigger, id, apply)
    local ids = {}
    for _, spellID in ipairs(trigger.SpellIDs or {}) do ids[#ids + 1] = tostring(spellID) end
    typeRow:EditBox(L['Spell IDs'], {
        width = 0.5,
        tooltip = L['Only these spells, comma separated. Empty shows every cast.'],
        value = tconcat(ids, ', '),
        callback = function(text)
            local list = {}
            for number in text:gmatch('%d+') do list[#list + 1] = tonumber(number) end
            trigger.SpellIDs = list[1] and list or nil
            apply()
            card:Rebuild()
        end,
    })

    local row = card:Row(rowH)
    row:Slider(L['Hold Time'], {
        width = 0.5,
        tooltip = L['Keep the bar up this long after the cast ends, for the Succeeded / Interrupted / Failed conditions. 0 hides it at once.'],
        min = 0,
        max = 3,
        step = 0.1,
        value = trigger.HoldTime or 0,
        callback = function(value)
            trigger.HoldTime = value
            apply()
        end,
    })
    row:Checkbox(L['Show Latency'], {
        width = 0.5,
        tooltip = L['Shades the end of the bar by the time your cast took to reach the server. Its color is on the Display tab.'],
        value = trigger.ShowLatency,
        callback = function(checked)
            trigger.ShowLatency = checked
            apply()
        end,
    })
end

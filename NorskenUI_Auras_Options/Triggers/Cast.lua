---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local Shared = NRSKNUI.CDMOptions
local SpellList = NRSKNUI.GUISpellList
local TriggerRows = Shared.TriggerRows

function TriggerRows.cast(card, typeRow, display, trigger, id, apply)
    -- empty shows every cast
    local source = SpellList:ArraySource(trigger, function() return trigger.SpellIDs or {} end, function(ids)
        trigger.SpellIDs = ids[1] and ids or nil
    end, function()
        apply()
        card:Rebuild()
    end)
    SpellList:BuildAdd(card, source)
    SpellList:BuildList(card, source)
    -- the list ends flush, so the rule brings its own gap; inSection keeps it in the trigger's section
    card:Separator(nil, { inSection = true, height = 16 })

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

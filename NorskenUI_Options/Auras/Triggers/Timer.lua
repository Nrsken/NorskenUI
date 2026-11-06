---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenAuras') then return end
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local ipairs = ipairs

local Shared = NRSKNUI.CDMOptions
local SpellList = NRSKNUI.GUISpellList
local TriggerRows = Shared.TriggerRows

function TriggerRows.timer(card, typeRow, display, trigger, id, apply)
    -- stored as SpellID (the icon and its override) plus AlsoSpellIDs, shown as one list
    local source = SpellList:ArraySource(trigger, function()
        local ids = { trigger.SpellID }
        for _, spellID in ipairs(trigger.AlsoSpellIDs or {}) do ids[#ids + 1] = spellID end
        return ids
    end, function(ids)
        local extra = {}
        for i = 2, #ids do extra[#extra + 1] = ids[i] end
        trigger.SpellID = ids[1]
        trigger.AlsoSpellIDs = extra[1] and extra or nil
    end, function()
        apply()
        card:Rebuild()
    end)
    SpellList:BuildAdd(card, source)
    SpellList:BuildList(card, source)
    -- the list ends flush, so the rule brings its own gap; inSection keeps it in the trigger's section
    card:Separator(nil, { inSection = true, height = 16 })

    local row = card:Row(rowH)
    row:Slider(L['Duration'], {
        width = 0.5,
        min = 1,
        max = 1000,
        step = 0.5,
        value = trigger.Duration,
        callback = function(value)
            trigger.Duration = value
            apply()
        end,
    })
    row:Checkbox(L['Ignore Override'], {
        width = 0.5,
        tooltip = L['Only casting this spell starts the timer, not a spell that replaces it, and its own icon is kept.'],
        value = trigger.IgnoreOverride,
        callback = function(checked)
            trigger.IgnoreOverride = checked or nil
            apply()
        end,
    })
end

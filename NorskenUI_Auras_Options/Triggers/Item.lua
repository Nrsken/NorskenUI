---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local tostring = tostring
local tonumber = tonumber

local GetItemIconByID = C_Item and C_Item.GetItemIconByID

local Shared = NRSKNUI.CDMOptions
local ITEMS, QUESTION_MARK = Shared.ITEMS, Shared.QUESTION_MARK
local Reopen, TRINKETS, TriggerRows = Shared.Reopen, Shared.TRINKETS, Shared.TriggerRows

function TriggerRows.item(card, typeRow, display, trigger, id, apply)
    typeRow:Dropdown(L['Item'], {
        width = 0.5,
        options = ITEMS,
        value = trigger.Item,
        callback = function(value)
            trigger.Item = value
            apply()
            card:Rebuild()
        end,
    })
    if trigger.Item == 'trinket1' or trigger.Item == 'trinket2' then
        local trinketRow = card:Row(rowH)
        trinketRow:Checkbox(L['Hide Passive Trinkets'], {
            width = 0.5,
            tooltip = L['A trinket without an on-use effect is not tracked.'],
            value = trigger.HidePassive,
            callback = function(checked)
                trigger.HidePassive = checked
                apply()
            end,
        })
        trinketRow:Button(L['Trinket Blacklist'], {
            width = 0.5,
            height = 24,
            yOffset = -14,
            tooltip = L['Trinkets that are never tracked, for on-use effects that only switch a mode.'],
            callback = function()
                Shared.trinketReturnKey = id
                Reopen(TRINKETS)
            end,
        })
    elseif trigger.Item == 'custom' then
        local itemRow = card:Row(rowH)
        itemRow:EditBox(L['Item ID'], {
            width = 0.5,
            value = trigger.ItemID and tostring(trigger.ItemID) or '',
            callback = function(text)
                trigger.ItemID = tonumber(text)
                apply()
                card:Rebuild()
            end,
        })
        itemRow:Icon({
            width = 0.1,
            size = 24,
            yOffset = -14,
            texture = trigger.ItemID and GetItemIconByID(trigger.ItemID) or QUESTION_MARK,
            tooltip = function(tooltip)
                if trigger.ItemID then tooltip:SetItemByID(trigger.ItemID) end
            end,
        })
    end
    local showRow = card:Row(rowH)
    showRow:Dropdown(L['Show'], {
        width = 0.5,
        options = Shared.SHOW_ON,
        value = trigger.ShowOn or 'always',
        callback = function(value)
            trigger.ShowOn = value ~= 'always' and value or nil
            apply()
        end,
    })
    if trigger.Item ~= 'trinket1' and trigger.Item ~= 'trinket2' then
        showRow:Checkbox(L['Show When Not in Bags'], {
            width = 0.5,
            tooltip = L["Keep showing the item even when not in bags."],
            value = trigger.ShowNotOwned,
            callback = function(checked)
                trigger.ShowNotOwned = checked or nil
                apply()
            end,
        })
    end
end

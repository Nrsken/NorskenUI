---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function BuildTab(page, db)
    page:SetEnabled(function() return db.Enabled end)

    -- Card 1: Enable
    local enableCard = page:Card(L['Copy Anything'])
    local enableRow = enableCard:Row(rowH)
    enableRow:Checkbox(L['Enable Copy Anything'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Copy Anything'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('CopyAnything', checked)
            page:Refresh()
        end,
    })

    enableCard:Separator()

    local textRowSize = 50
    local infoRow = enableCard:Row(textRowSize)
    infoRow:Text(NRSKNUI:ColorTextByTheme(L['Functionality Info']), {
        width = 1,
        height = textRowSize,
        bgMode = 'hide',
        text = NRSKNUI:ColorTextByTheme('• ') ..
            L['Copies SpellID, ItemID, AuraID, MacroID and Unitnames on mouseover'] .. '\n' ..
            NRSKNUI:ColorTextByTheme('• ') .. L['Limited functionality in certain environments because of secret values.'],
        conditions = { 'all' },

    })

    -- Card 2: Keybind Settings
    local keybindCard = page:Card(L['Keybind Settings'], 'all')
    local keybindRow = keybindCard:Row(rowHL, 0)
    keybindRow:Dropdown(L['Copy Modifier Key(s)'], {
        width = 0.5,
        options = {
            ['ctrl'] = L['Ctrl'],
            ['shift'] = L['Shift'],
            ['alt'] = L['Alt'],
            ['ctrl+shift'] = L['Ctrl + Shift'],
            ['ctrl+alt'] = L['Ctrl + Alt'],
            ['ctrl+shift+alt'] = L['Ctrl + Shift + Alt']
        },
        value = db.modifier,
        callback = function(key)
            db.modifier = key
        end
    })
    keybindRow:EditBox(L['Copy Keybind, Single Letter Only'], {
        width = 0.5,
        value = db.key,
        callback = function(val)
            db.key = val
        end
    })
end

GUI:RegisterPage('copyAnything', {
    mode = 'clean',
    search = {},
    build = function(page)
        local db = NRSKNUI.db.profile.Miscellaneous.CopyAnything
        if not db then return end

        BuildTab(page, db)
    end,
})

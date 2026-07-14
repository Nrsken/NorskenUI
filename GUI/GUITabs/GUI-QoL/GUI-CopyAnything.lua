---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CopyAnything
local CopyAnything = NRSKNUI:GetModule('CopyAnything')
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

GUIFrame:RegisterContent('CopyAnything', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.CopyAnything
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local manager = GUIFrame:CreateWidgetStateManager()
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    -- Card 1
    local card1 = GUIFrame:CreateCard(scrollChild, 'Copy Anything', yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
    local enableCheck = GUIFrame:CreateCheckbox(row1, 'Enable Copy Anything', {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if CopyAnything then
                if checked then NRSKNUI:EnableModule('CopyAnything') else NRSKNUI:DisableModule('CopyAnything') end
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = 'Copy Anything',
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeight)

    local sep1 = GUIFrame:CreateSeparator(card1.content)
    card1:AddRow(sep1, Theme.rowHeightSeparator)

    local textRowSize = 50
    local infoRow = GUIFrame:CreateRow(card1.content, textRowSize)
    local infoText = GUIFrame:CreateText(infoRow, NRSKNUI:ColorTextByTheme('Functionality Info'), {
        text = NRSKNUI:ColorTextByTheme('• ') ..
            'Copies SpellID, ItemID, AuraID, MacroID and Unitnames on mouseover\n' ..
            NRSKNUI:ColorTextByTheme('• ') .. 'Limited functionality in certain environments because of secret values.',
        height = textRowSize,
        bgMode = 'hide'
    })
    infoRow:AddWidget(infoText, 1)
    manager:Register(infoText, 'all')
    card1:AddRow(infoRow, textRowSize)

    yOffset = card1:GetNextOffset()

    -- Card 2
    local card2 = GUIFrame:CreateCard(scrollChild, 'Keybinding', yOffset)
    manager:Register(card2, 'all')

    local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local modList = {
        ['ctrl'] = 'Ctrl',
        ['shift'] = 'Shift',
        ['alt'] = 'Alt',
        ['ctrl+shift'] = 'Ctrl + Shift',
        ['ctrl+alt'] = 'Ctrl + Alt',
        ['ctrl+shift+alt'] = 'Ctrl + Shift + Alt'
    }
    local modDropdown = GUIFrame:CreateDropdown(row2, 'Copy Modifier Key(s)', {
        options = modList,
        value = db.modifier,
        callback = function(key)
            db.modifier = key
        end
    })
    row2:AddWidget(modDropdown, 0.5)
    manager:Register(modDropdown, 'all')

    local keyEditBox = GUIFrame:CreateEditBox(row2, 'Copy Keybind, Single Letter Only', {
        value = db.key,
        callback = function(val)
            db.key = val
        end
    })
    row2:AddWidget(keyEditBox, 0.1)
    manager:Register(keyEditBox, 'all')
    card2:AddRow(row2, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    UpdateAllWidgetStates()

    return yOffset
end)

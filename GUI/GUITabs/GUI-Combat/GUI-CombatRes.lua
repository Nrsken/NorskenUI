---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CombatRes
local CombatRes = NRSKNUI:GetModule('CombatRes', true)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

GUIFrame:RegisterContent('battleRes', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.BattleRes
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local manager = GUIFrame:CreateWidgetStateManager()
    local function ApplySettings() CombatRes:ApplySettings() end
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end
    manager:SetCondition('Backdrop', function() return db.BackdropEnabled end)

    -- Card 1: Enable
    local card1 = GUIFrame:CreateCard(scrollChild, 'Battle Res Tracker', yOffset)

    -- Enable toggle
    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, 'Enable Combat Res Tracker', {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule('CombatRes')
            else
                NRSKNUI:DisableModule('CombatRes')
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = 'Combat Res Tracker',
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Text Format
    local card2 = GUIFrame:CreateCard(scrollChild, 'Text Format', yOffset)
    manager:Register(card2, 'all')

    -- Format input edit box
    local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local formatInput = GUIFrame:CreateEditBox(row2a, 'Format', {
        value = db.TextFormat,
        callback = function(val)
            db.TextFormat = val
            ApplySettings()
        end
    })
    row2a:AddWidget(formatInput, 1)
    manager:Register(formatInput, 'all')
    card2:AddRow(row2a, Theme.rowHeight)

    -- Info text
    local tokenHeight = 70
    local tokenLegend = GUIFrame:CreateText(card2.content, NRSKNUI:ColorTextByTheme('Available Tokens'), {
        text = {
            db.TextCharge .. '  —  Battle res charges',
            db.TextSeparator .. '  —  Separator (chosen below)',
            db.TextTimer .. '  —  Cooldown timer',
        },
        bgMode = 'hide',
        height = tokenHeight,
    })
    manager:Register(tokenLegend, 'all')
    card2:AddRow(tokenLegend, tokenHeight)

    -- Separator type dropdown
    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local separatorDropdown = GUIFrame:CreateDropdown(row2b, 'Separator', {
        options = NRSKNUI.Separators,
        value = db.Separator,
        callback = function(key)
            db.Separator = key
            ApplySettings()
        end
    })
    row2b:AddWidget(separatorDropdown, 0.5)
    manager:Register(separatorDropdown, 'all')

    -- Time format dropdown
    local timeFormatDropdown = GUIFrame:CreateDropdown(row2b, 'Timer Format', {
        options = NRSKNUI.TimeFormats,
        value = db.TimeFormat,
        callback = function(key)
            db.TimeFormat = key
            ApplySettings()
        end
    })
    row2b:AddWidget(timeFormatDropdown, 0.5)
    manager:Register(timeFormatDropdown, 'all')
    card2:AddRow(row2b, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Colors
    local card3 = GUIFrame:CreateCard(scrollChild, 'Colors', yOffset)
    manager:Register(card3, 'all')

    -- Charge available color picker
    local row3a = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local chargeAvailColor = GUIFrame:CreateColorPicker(row3a, 'Charges Available', {
        color = db.ColorChargeAvailable,
        callback = function(r, g, b, a)
            db.ColorChargeAvailable = { r, g, b, a }
            ApplySettings()
        end
    })
    row3a:AddWidget(chargeAvailColor, 0.5)
    manager:Register(chargeAvailColor, 'all')

    -- Charge unavailable color picker
    local chargeUnavailColor = GUIFrame:CreateColorPicker(row3a, 'Charges Unavailable', {
        color = db.ColorChargeUnavailable,
        callback = function(r, g, b, a)
            db.ColorChargeUnavailable = { r, g, b, a }
            ApplySettings()
        end
    })
    row3a:AddWidget(chargeUnavailColor, 0.5)
    manager:Register(chargeUnavailColor, 'all')
    card3:AddRow(row3a, Theme.rowHeight)

    -- Charge timer color picker
    local row3b = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local timerColor = GUIFrame:CreateColorPicker(row3b, 'Timer', {
        color = db.ColorTimer,
        callback = function(r, g, b, a)
            db.ColorTimer = { r, g, b, a }
            ApplySettings()
        end
    })
    row3b:AddWidget(timerColor, 0.5)
    manager:Register(timerColor, 'all')

    -- Separator color picker
    local sepColor = GUIFrame:CreateColorPicker(row3b, 'Separator', {
        color = db.ColorSeparator,
        callback = function(r, g, b, a)
            db.ColorSeparator = { r, g, b, a }
            ApplySettings()
        end
    })
    row3b:AddWidget(sepColor, 0.5)
    manager:Register(sepColor, 'all')
    card3:AddRow(row3b, Theme.rowHeight)

    -- Format text color picker
    local row3c = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local formatColor = GUIFrame:CreateColorPicker(row3c, 'Format Text', {
        color = db.ColorFormat,
        callback = function(r, g, b, a)
            db.ColorFormat = { r, g, b, a }
            ApplySettings()
        end
    })
    row3c:AddWidget(formatColor, 1)
    manager:Register(formatColor, 'all')
    card3:AddRow(row3c, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card 4: Backdrop
    local card4 = GUIFrame:CreateCard(scrollChild, 'Backdrop', yOffset)
    manager:Register(card4, 'all')

    -- Enable backdrop toggle
    local row4a = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local backdropCheck = GUIFrame:CreateCheckbox(row4a, 'Enable Backdrop', {
        value = db.BackdropEnabled,
        callback = function(checked)
            db.BackdropEnabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row4a:AddWidget(backdropCheck, 1)
    manager:Register(backdropCheck, 'all')
    card4:AddRow(row4a, Theme.rowHeight)

    -- Separator
    local sep4 = GUIFrame:CreateSeparator(card4.content)
    card4:AddRow(sep4, Theme.rowHeightSeparator)

    -- Background color picker
    local row4b = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local bgColor = GUIFrame:CreateColorPicker(row4b, 'Background Color', {
        color = db.BackgroundColor,
        callback = function(r, g, b, a)
            db.BackgroundColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row4b:AddWidget(bgColor, 0.5)
    manager:Register(bgColor, 'all', 'Backdrop')

    -- Border color picker
    local borderColor = GUIFrame:CreateColorPicker(row4b, 'Border Color', {
        color = db.BorderColor,
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row4b:AddWidget(borderColor, 0.5)
    manager:Register(borderColor, 'all', 'Backdrop')
    card4:AddRow(row4b, Theme.rowHeight)

    -- Padding X slider
    local row4c = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
    local padXSlider = GUIFrame:CreateSlider(row4c, 'Padding X', {
        min = 0,
        max = 40,
        step = 1,
        value = db.BackdropWidth,
        callback = function(val)
            db.BackdropWidth = val
            ApplySettings()
        end
    })
    row4c:AddWidget(padXSlider, 0.5)
    manager:Register(padXSlider, 'all', 'Backdrop')

    -- Padding Y slider
    local padYSlider = GUIFrame:CreateSlider(row4c, 'Padding Y', {
        min = 0,
        max = 40,
        step = 1,
        value = db.BackdropHeight,
        callback = function(val)
            db.BackdropHeight = val
            ApplySettings()
        end
    })
    row4c:AddWidget(padYSlider, 0.5)
    manager:Register(padYSlider, 'all', 'Backdrop')
    card4:AddRow(row4c, Theme.rowHeightLast, 0)

    yOffset = card4:GetNextOffset()

    -- Card 5: Font Settings
    local fontCard, fontOffset, fontWidgets = GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, {
        db = db,
        includeSoftOutline = true,
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
    manager:Register(fontCard, 'all')
    manager:RegisterGroup(fontWidgets, 'all')

    yOffset = fontOffset

    -- Card 6: Position
    local posCard, posOffset, positionWidgets = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })
    manager:Register(posCard, 'all')
    manager:RegisterGroup(positionWidgets, 'all')

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

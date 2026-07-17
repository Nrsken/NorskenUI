---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CombatTimer: AceModule, AceEvent-3.0
local CombatTimer = NRSKNUI:GetModule('CombatTimer')

local GUI = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

GUI:RegisterContent('combatTimer', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.CombatTimer
    if not db then return GUI:ShowDBError(scrollChild, yOffset) end

    local manager = GUI:CreateWidgetStateManager()
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end
    manager:SetCondition('Backdrop', function() return db.BackdropEnabled end)
    manager:SetCondition('CombatOnly', function() return not db.CombatOnly end)

    -- Card 1: Enable
    local card1 = GUI:CreateCard(scrollChild, 'Combat Timer', yOffset)

    local row1 = GUI:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUI:CreateCheckbox(row1, 'Enable Combat Timer', {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule('CombatTimer')
            else
                NRSKNUI:DisableModule('CombatTimer')
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = 'Combat Timer',
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Options
    local card2 = GUI:CreateCard(scrollChild, 'Options', yOffset)
    manager:Register(card2, 'all')

    local row2a = GUI:CreateRow(card2.content, Theme.rowHeight)
    local combatOnlyCheck = GUI:CreateCheckbox(row2a, 'Combat Only', {
        value = db.CombatOnly,
        callback = function(checked)
            db.CombatOnly = checked
            CombatTimer:Toggle(checked)
            CombatTimer:ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row2a:AddWidget(combatOnlyCheck, 0.5)
    manager:Register(combatOnlyCheck, 'all')

    -- Same time formats as CombatRes, plus a sub-second option unique to the timer.
    local formatOptions = {}
    for key, preview in pairs(NRSKNUI.TimeFormats) do formatOptions[key] = preview end
    formatOptions['MM:SS.f'] = '01:30.5'

    local formatDropdown = GUI:CreateDropdown(row2a, 'Format', {
        options = formatOptions,
        value = db.Format,
        callback = function(key)
            db.Format = key
            CombatTimer:ApplySettings()
        end
    })
    row2a:AddWidget(formatDropdown, 0.5)
    manager:Register(formatDropdown, 'all')
    card2:AddRow(row2a, Theme.rowHeight)

    local row2b = GUI:CreateRow(card2.content, Theme.rowHeightLast)
    local printCheck = GUI:CreateCheckbox(row2b, 'Print Duration to Chat', {
        value = db.PrintEnd,
        callback = function(checked)
            db.PrintEnd = checked
        end
    })
    row2b:AddWidget(printCheck, 1)
    manager:Register(printCheck, 'all')
    card2:AddRow(row2b, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Colors
    local card3 = GUI:CreateCard(scrollChild, 'Colors', yOffset)
    manager:Register(card3, 'all')

    local row3a = GUI:CreateRow(card3.content, Theme.rowHeightLast)
    local inCombatColor = GUI:CreateColorPicker(row3a, 'In Combat', {
        color = db.ColorInCombat,
        callback = function(r, g, b, a)
            db.ColorInCombat = { r, g, b, a }
            CombatTimer:ApplySettings()
        end
    })
    row3a:AddWidget(inCombatColor, 0.5)
    manager:Register(inCombatColor, 'all')

    local outCombatColor = GUI:CreateColorPicker(row3a, 'Out of Combat', {
        color = db.ColorOutOfCombat,
        callback = function(r, g, b, a)
            db.ColorOutOfCombat = { r, g, b, a }
            CombatTimer:ApplySettings()
        end
    })
    row3a:AddWidget(outCombatColor, 0.5)
    manager:Register(outCombatColor, 'all', 'CombatOnly')
    card3:AddRow(row3a, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card 4: Backdrop
    local card4 = GUI:CreateCard(scrollChild, 'Backdrop', yOffset)
    manager:Register(card4, 'all')

    local row4a = GUI:CreateRow(card4.content, Theme.rowHeight)
    local backdropCheck = GUI:CreateCheckbox(row4a, 'Enable Backdrop', {
        value = db.BackdropEnabled,
        callback = function(checked)
            db.BackdropEnabled = checked
            CombatTimer:ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row4a:AddWidget(backdropCheck, 1)
    manager:Register(backdropCheck, 'all')
    card4:AddRow(row4a, Theme.rowHeight)

    local separator = GUI:CreateSeparator(card4.content)
    card4:AddRow(separator, Theme.rowHeightSeparator)

    local row4ab = GUI:CreateRow(card4.content, Theme.rowHeight)
    local bgColor = GUI:CreateColorPicker(row4ab, 'Background Color', {
        color = db.BackgroundColor,
        callback = function(r, g, b, a)
            db.BackgroundColor = { r, g, b, a }
            CombatTimer:ApplySettings()
        end
    })
    row4ab:AddWidget(bgColor, 1)
    manager:Register(bgColor, 'all', 'Backdrop')
    card4:AddRow(row4ab, Theme.rowHeight)

    local row4b = GUI:CreateRow(card4.content, Theme.rowHeight)
    local bgWidth = GUI:CreateSlider(row4b, 'Background Width', {
        min = 1,
        max = 600,
        step = 1,
        value = db.BackdropWidth,
        callback = function(val)
            db.BackdropWidth = val
            CombatTimer:ApplySettings()
        end
    })
    row4b:AddWidget(bgWidth, 0.5)
    manager:Register(bgWidth, 'all', 'Backdrop')

    local bgHeight = GUI:CreateSlider(row4b, 'Background Height', {
        min = 1,
        max = 600,
        step = 1,
        value = db.BackdropHeight,
        callback = function(val)
            db.BackdropHeight = val
            CombatTimer:ApplySettings()
        end
    })
    row4b:AddWidget(bgHeight, 0.5)
    manager:Register(bgHeight, 'all', 'Backdrop')
    card4:AddRow(row4b, Theme.rowHeight)

    local separator2 = GUI:CreateSeparator(card4.content)
    card4:AddRow(separator2, Theme.rowHeightSeparator)

    local row4bc = GUI:CreateRow(card4.content, Theme.rowHeightLast)
    local borderColor = GUI:CreateColorPicker(row4bc, 'Border Color', {
        color = db.BorderColor,
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }
            CombatTimer:ApplySettings()
        end
    })
    row4bc:AddWidget(borderColor, 1)
    manager:Register(borderColor, 'all', 'Backdrop')
    card4:AddRow(row4bc, Theme.rowHeightLast, 0)

    yOffset = card4:GetNextOffset()

    -- Card 5: Font Settings
    local fontCard, fontOffset, fontWidgets = GUI:CreateFontSettingsCard(scrollChild, yOffset, {
        db = db,
        includeSoftOutline = true,
        onChangeCallback = function() CombatTimer:ApplySettings() end,
        globalOverride = {},
    })
    manager:Register(fontCard, 'all')
    manager:RegisterGroup(fontWidgets, 'all')

    yOffset = fontOffset

    -- Card 6: Position
    local posCard, posOffset = GUI:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = function() CombatTimer:ApplySettings() end,
    })
    manager:Register(posCard, 'all')

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

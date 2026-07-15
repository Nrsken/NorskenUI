---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CombatCross
local CombatCross = NRSKNUI:GetModule('CombatCross')
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local ModeOptions = {
    { value = 'cross', text = 'Cross' },
    { value = 'dot',   text = 'Dot' },
}

GUIFrame:RegisterContent('combatCross', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.CombatCross
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local manager = GUIFrame:CreateWidgetStateManager()
    local function ApplySettings() CombatCross:ApplySettings() end
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end
    manager:SetCondition('colorMode', function() return db.ColorMode == 'custom' end)
    manager:SetCondition('rangeColor', function() return db.RangeColorMeleeEnabled or db.RangeColorRangedEnabled end)
    manager:SetCondition('crossMode', function() return db.Mode == 'cross' end)
    manager:SetCondition('dotMode', function() return db.Mode == 'dot' end)

    -- Card 1: Enable
    local card1 = GUIFrame:CreateCard(scrollChild, 'Combat Cross', yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, 'Enable Combat Cross', {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule('CombatCross')
            else
                NRSKNUI:DisableModule('CombatCross')
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = 'Combat Cross',
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Appearance
    local card2 = GUIFrame:CreateCard(scrollChild, 'Appearance', yOffset)
    manager:Register(card2, 'all')

    -- Style mode dropdown
    local row2mode = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local modeDropdown = GUIFrame:CreateDropdown(row2mode, 'Style', {
        options = ModeOptions,
        value = db.Mode,
        callback = function(key)
            db.Mode = key
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row2mode:AddWidget(modeDropdown, 0.5)
    manager:Register(modeDropdown, 'all')

    -- Outline checkbox
    local outlineCheck = GUIFrame:CreateCheckbox(row2mode, 'Outline', {
        value = db.Outline,
        callback = function(checked)
            db.Outline = checked
            ApplySettings()
        end
    })
    row2mode:AddWidget(outlineCheck, 0.5)
    manager:Register(outlineCheck, 'all')
    card2:AddRow(row2mode, Theme.rowHeight)

    local sep2 = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sep2, Theme.rowHeightSeparator)

    -- Thickness slider
    local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local thicknessSlider = GUIFrame:CreateSlider(row2a, 'Thickness', {
        min = 3,
        max = 20,
        step = 1,
        value = db.CrossThickness,
        callback = function(val)
            db.CrossThickness = val
            ApplySettings()
        end
    })
    row2a:AddWidget(thicknessSlider, 0.5)
    manager:Register(thicknessSlider, 'all', 'crossMode')

    -- Length slider
    local lengthSlider = GUIFrame:CreateSlider(row2a, 'Length', {
        min = 4,
        max = 80,
        step = 1,
        value = db.CrossLength,
        callback = function(val)
            db.CrossLength = val
            ApplySettings()
        end
    })
    row2a:AddWidget(lengthSlider, 0.5)
    manager:Register(lengthSlider, 'all', 'crossMode')
    card2:AddRow(row2a, Theme.rowHeight)

    -- Gap slider
    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local gapSlider = GUIFrame:CreateSlider(row2b, 'Center Gap', {
        min = 0,
        max = 40,
        step = 1,
        value = db.CrossGap,
        callback = function(val)
            db.CrossGap = val
            ApplySettings()
        end
    })
    row2b:AddWidget(gapSlider, 1)
    manager:Register(gapSlider, 'all', 'crossMode')
    card2:AddRow(row2b, Theme.rowHeight)

    local sep3 = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sep3, Theme.rowHeightSeparator)

    -- Dot size (dot mode only)
    local row2c = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local dotSizeSlider = GUIFrame:CreateSlider(row2c, 'Dot Size', {
        min = 4,
        max = 50,
        step = 1,
        value = db.CenterDotSize,
        callback = function(val)
            db.CenterDotSize = val
            ApplySettings()
        end
    })
    row2c:AddWidget(dotSizeSlider, 0.5)
    manager:Register(dotSizeSlider, 'all', 'dotMode')
    card2:AddRow(row2c, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Color
    local card3 = GUIFrame:CreateCard(scrollChild, 'Color', yOffset)
    manager:Register(card3, 'all')

    -- Color mode dropdown
    local row3a = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local colorModeDropdown = GUIFrame:CreateDropdown(row3a, 'Color Mode', {
        options = NRSKNUI.ColorModeOptions,
        value = db.ColorMode,
        callback = function(key)
            db.ColorMode = key
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row3a:AddWidget(colorModeDropdown, 0.5)
    manager:Register(colorModeDropdown, 'all')

    -- Custom color picker
    local colorPicker = GUIFrame:CreateColorPicker(row3a, 'Custom Color', {
        color = db.Color,
        callback = function(r, g, b, a)
            db.Color = { r, g, b, a }
            ApplySettings()
        end
    })
    row3a:AddWidget(colorPicker, 0.5)
    manager:Register(colorPicker, 'all', 'colorMode')
    card3:AddRow(row3a, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card 4: Range Warning
    local card4 = GUIFrame:CreateCard(scrollChild, 'Range Warning', yOffset)
    manager:Register(card4, 'all')

    -- Melee toggle
    local row4a = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local meleeRangeCheck = GUIFrame:CreateCheckbox(row4a, 'Enable for melee specs', {
        value = db.RangeColorMeleeEnabled,
        callback = function(checked)
            db.RangeColorMeleeEnabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row4a:AddWidget(meleeRangeCheck, 0.5)
    manager:Register(meleeRangeCheck, 'all')

    -- Ranged toggle
    local rangedRangeCheck = GUIFrame:CreateCheckbox(row4a, 'Enable for ranged specs', {
        value = db.RangeColorRangedEnabled,
        callback = function(checked)
            db.RangeColorRangedEnabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row4a:AddWidget(rangedRangeCheck, 0.5)
    manager:Register(rangedRangeCheck, 'all')
    card4:AddRow(row4a, Theme.rowHeight)

    -- Out of range color picker
    local row4b = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
    local outOfRangeColorPicker = GUIFrame:CreateColorPicker(row4b, 'Out of Range Color', {
        color = db.OutOfRangeColor,
        callback = function(r, g, b, a)
            db.OutOfRangeColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row4b:AddWidget(outOfRangeColorPicker, 1)
    manager:Register(outOfRangeColorPicker, 'all', 'rangeColor')
    card4:AddRow(row4b, Theme.rowHeightLast, 0)

    yOffset = card4:GetNextOffset()

    -- Card 5: Position
    local posCard, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = false,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })
    manager:Register(posCard, 'all')
    if posCard.positionWidgets then manager:RegisterGroup(posCard.positionWidgets, 'all') end

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

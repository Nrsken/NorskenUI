---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class Durability
local Durability = NRSKNUI:GetModule('Durability', true)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

GUIFrame:RegisterContent('Durability', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.Durability
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local manager = GUIFrame:CreateWidgetStateManager()
    local function ApplySettings() if Durability then Durability:ApplySettings() end end
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    -- Card 1: Enable
    local card1 = GUIFrame:CreateCard(scrollChild, 'Durability Low Warning', yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, 'Enable Durability Low Warning', {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule('Durability')
            else
                NRSKNUI:DisableModule('Durability')
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = 'Durability Low Warning',
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Repair Warning
    local card2 = GUIFrame:CreateCard(scrollChild, 'General Settings', yOffset)
    manager:Register(card2, 'all')

    local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local lowTextEdit = GUIFrame:CreateEditBox(row2a, 'Low Text', {
        value = db.TextLow,
        callback = function(val)
            db.TextLow = val
            ApplySettings()
        end,
        width = 150,
    })
    row2a:AddWidget(lowTextEdit, 0.5)
    manager:Register(lowTextEdit, 'all')

    local lowColor = GUIFrame:CreateColorPicker(row2a, 'Low Color', {
        color = db.TextColorLow,
        callback = function(r, g, b, a)
            db.TextColorLow = { r, g, b, a }
            ApplySettings()
        end
    })
    row2a:AddWidget(lowColor, 0.5)
    manager:Register(lowColor, 'all')
    card2:AddRow(row2a, Theme.rowHeight)

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local brokenTextEdit = GUIFrame:CreateEditBox(row2b, 'Broken Text', {
        value = db.TextBroken,
        callback = function(val)
            db.TextBroken = val
            ApplySettings()
        end,
        width = 150,
    })
    row2b:AddWidget(brokenTextEdit, 0.5)
    manager:Register(brokenTextEdit, 'all')

    local brokenColor = GUIFrame:CreateColorPicker(row2b, 'Broken Color', {
        color = db.TextColorBroken,
        callback = function(r, g, b, a)
            db.TextColorBroken = { r, g, b, a }
            ApplySettings()
        end
    })
    row2b:AddWidget(brokenColor, 0.5)
    manager:Register(brokenColor, 'all')
    card2:AddRow(row2b, Theme.rowHeight)

    local sep = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sep, Theme.rowHeightSeparator)

    local row2c = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local oocThreshold = GUIFrame:CreateSlider(row2c, '|cff4dff00Out of Combat|r Threshold %', {
        min = 1,
        max = 100,
        step = 1,
        value = db.ShowPercent,
        callback = function(val)
            db.ShowPercent = val
            ApplySettings()
        end
    })
    row2c:AddWidget(oocThreshold, 0.5)
    manager:Register(oocThreshold, 'all')

    local icThreshold = GUIFrame:CreateSlider(row2c, '|cffff0000In Combat|r Threshold %', {
        min = 0,
        max = 100,
        step = 1,
        value = db.CombatShowPercent,
        callback = function(val)
            db.CombatShowPercent = val
            ApplySettings()
        end
    })
    row2c:AddWidget(icThreshold, 0.5)
    manager:Register(icThreshold, 'all')
    card2:AddRow(row2c, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Font Settings
    local fontCard, fontOffset, fontWidgets = GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, {
        db = db,
        includeSoftOutline = true,
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
    manager:Register(fontCard, 'all')
    manager:RegisterGroup(fontWidgets, 'all')

    yOffset = fontOffset

    -- Card 4: Position
    local posCard, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })
    manager:Register(posCard, 'all')
    if posCard.positionWidgets then manager:RegisterGroup(posCard.positionWidgets, 'all') end

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

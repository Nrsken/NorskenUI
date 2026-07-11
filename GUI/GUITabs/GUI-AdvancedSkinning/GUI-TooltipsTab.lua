---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

GUIFrame:RegisterContent('tooltips', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.Tooltips
    if NRSKNUI:ShouldNotLoadModule() or not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end
    local manager = GUIFrame:CreateWidgetStateManager()

    ---@type Tooltips?
    local TT = NRSKNUI:GetModule('Tooltips', true)
    local function UpdateAllWidgetStates()
        manager:UpdateAll(db.Enabled)
        manager:UpdateGroup('combatHide', db.Enabled and db.HideInCombat)
        manager:UpdateGroup('statusBarShow', db.Enabled and db.ShowStatusBar)
        manager:UpdateGroup('globalOff', db.Enabled and db.ShowStatusBar and not db.UseGlobalBar)
    end
    local function ApplySettings() if TT then TT:ApplySettings() end end

    -- Card1: Toggle Tooltip Skinning
    local card1 = GUIFrame:CreateCard(scrollChild, 'Tooltip Skinning', yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, 'Enable Tooltip Skinning', {
        value = db.Enabled ~= false,
        callback = function(checked)
            db.Enabled = checked
            if TT then
                if checked then
                    NRSKNUI:EnableModule('Tooltips')
                else
                    NRSKNUI:DisableModule('Tooltips')
                    NRSKNUI:CreateReloadPrompt('Enabling Blizzard UI elements requires a reload to take full effect.')
                end
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = 'Tooltip Skinning',
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- CardGeneral: General
    local cardGeneral = GUIFrame:CreateCard(scrollChild, 'General Settings', yOffset)
    manager:Register(cardGeneral, 'all')

    local rowGeneral1 = GUIFrame:CreateRow(cardGeneral.content, Theme.rowHeightLast)
    local HideThreatLineCheck = GUIFrame:CreateCheckbox(rowGeneral1, 'Hide Threat Line', {
        value = db.HideThreatLine,
        callback = function(checked)
            db.HideThreatLine = checked
            ApplySettings()
        end,
        tooltip = 'Hides the current threat line on tooltips for units that you are in combat with.',
    })
    rowGeneral1:AddWidget(HideThreatLineCheck, 0.5)
    manager:Register(HideThreatLineCheck, 'all')

    local ShowMountInfoCheck = GUIFrame:CreateCheckbox(rowGeneral1, 'Show Mount', {
        value = db.ShowMountInfo,
        callback = function(checked)
            db.ShowMountInfo = checked
        end,
        tooltip = 'Shows the mount a player is currently riding on their tooltip when holding shift.',
    })
    rowGeneral1:AddWidget(ShowMountInfoCheck, 0.5)
    manager:Register(ShowMountInfoCheck, 'all')
    cardGeneral:AddRow(rowGeneral1, Theme.rowHeightLast, 0)

    yOffset = cardGeneral:GetNextOffset()

    -- CardStatusbar: Statusbar
    local cardStatusbar = GUIFrame:CreateCard(scrollChild, 'StatusBar Settings', yOffset)
    manager:Register(cardStatusbar, 'all')

    local rowStatusbar1 = GUIFrame:CreateRow(cardStatusbar.content, Theme.rowHeight)
    local ShowStatusBarCheck = GUIFrame:CreateCheckbox(rowStatusbar1, 'Show StatusBar', {
        value = db.ShowStatusBar,
        callback = function(checked)
            db.ShowStatusBar = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end,
        tooltip = 'Toggles health statusbar on unit tooltips.',
    })
    rowStatusbar1:AddWidget(ShowStatusBarCheck, 1)
    manager:Register(ShowStatusBarCheck, 'all')
    cardStatusbar:AddRow(rowStatusbar1, Theme.rowHeight)

    local sepRowStatusbar = GUIFrame:CreateSeparator(cardStatusbar.content)
    cardStatusbar:AddRow(sepRowStatusbar, Theme.rowHeightSeparator)

    local rowStatusbar2 = GUIFrame:CreateRow(cardStatusbar.content, Theme.rowHeightLast)
    local UseGlobalBarCheck = GUIFrame:CreateCheckbox(rowStatusbar2, 'Use Global Bar', {
        value = db.UseGlobalBar,
        callback = function(checked)
            db.UseGlobalBar = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end,
    })
    rowStatusbar2:AddWidget(UseGlobalBarCheck, 0.5)
    manager:Register(UseGlobalBarCheck, 'all', 'statusBarShow')

    local statusbarList = {}
    if LSM then
        for name in pairs(LSM:HashTable("statusbar")) do statusbarList[name] = name end
    else
        statusbarList["Blizzard"] = "Blizzard"
    end
    local statusbarDropdown = GUIFrame:CreateDropdown(rowStatusbar2, "Bar Texture", {
        options = statusbarList,
        value = db.StatusBarTexture,
        callback = function(key)
            db.StatusBarTexture = key
            ApplySettings()
        end,
        searchable = true
    })
    rowStatusbar2:AddWidget(statusbarDropdown, 0.5)
    manager:Register(statusbarDropdown, 'all', 'statusBarShow', 'globalOff')
    cardStatusbar:AddRow(rowStatusbar2, Theme.rowHeightLast, 0)

    yOffset = cardStatusbar:GetNextOffset()

    -- Card2: Backdrop
    local card2 = GUIFrame:CreateCard(scrollChild, 'Backdrop', yOffset)
    manager:Register(card2, 'all')

    local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local backgroundColor = GUIFrame:CreateColorPicker(row2, 'Background', {
        color = db.BackgroundColor,
        callback = function(r, g, b, a)
            db.BackgroundColor = { r, g, b, a }
            ApplySettings()
        end,
    })
    row2:AddWidget(backgroundColor, 1)
    manager:Register(backgroundColor, 'all')
    card2:AddRow(row2, Theme.rowHeight)

    local sepRowBackdrop = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sepRowBackdrop, Theme.rowHeightSeparator)

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local borderColor = GUIFrame:CreateColorPicker(row2b, 'Border', {
        color = db.BorderColor,
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }
            ApplySettings()
        end,
    })
    row2b:AddWidget(borderColor, 0.5)
    manager:Register(borderColor, 'all')

    local qualityBorderCheck = GUIFrame:CreateCheckbox(row2b, 'Item Quality Borders', {
        value = db.ShowItemQualityBorder,
        callback = function(checked)
            db.ShowItemQualityBorder = checked
            ApplySettings()
        end,
        tooltip = 'Color tooltip borders by item quality, falls back to the border color for everything else.',
    })
    row2b:AddWidget(qualityBorderCheck, 0.5)
    manager:Register(qualityBorderCheck, 'all')
    card2:AddRow(row2b, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card3: Combat Visibility
    local card3 = GUIFrame:CreateCard(scrollChild, 'Combat Visibility', yOffset)
    manager:Register(card3, 'all')

    local row3 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local combatHideCheck = GUIFrame:CreateCheckbox(row3, 'Hide Tooltips in Combat', {
        value = db.HideInCombat,
        callback = function(checked)
            db.HideInCombat = checked
            UpdateAllWidgetStates()
        end,
        tooltip = 'Hides the selected tooltip types during combat. Hold the override key to temporarily show them.',
    })
    row3:AddWidget(combatHideCheck, 0.5)
    manager:Register(combatHideCheck, 'all')

    local modDropdown = GUIFrame:CreateDropdown(row3, 'Override Key', {
        options = {
            { key = 'SHIFT', text = 'Shift' },
            { key = 'CTRL',  text = 'Ctrl' },
            { key = 'ALT',   text = 'Alt' },
        },
        value = db.Mod,
        callback = function(key)
            db.Mod = key
        end,
    })
    row3:AddWidget(modDropdown, 0.5)
    manager:Register(modDropdown, 'all', 'combatHide')
    card3:AddRow(row3, Theme.rowHeight)

    local sepRowCombat = GUIFrame:CreateSeparator(card3.content)
    card3:AddRow(sepRowCombat, Theme.rowHeightSeparator)

    local row3b = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local unitsCheck = GUIFrame:CreateCheckbox(row3b, 'Units', {
        value = db.HideInCombatTypes.Units,
        callback = function(checked)
            db.HideInCombatTypes.Units = checked
        end,
    })
    row3b:AddWidget(unitsCheck, 0.5)
    manager:Register(unitsCheck, 'all', 'combatHide')

    local itemsCheck = GUIFrame:CreateCheckbox(row3b, 'Items', {
        value = db.HideInCombatTypes.Items,
        callback = function(checked)
            db.HideInCombatTypes.Items = checked
        end,
        tooltip = 'Includes toys and equipment sets.',
    })
    row3b:AddWidget(itemsCheck, 0.5)
    manager:Register(itemsCheck, 'all', 'combatHide')
    card3:AddRow(row3b, Theme.rowHeight)

    local row3c = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local spellsCheck = GUIFrame:CreateCheckbox(row3c, 'Spells', {
        value = db.HideInCombatTypes.Spells,
        callback = function(checked)
            db.HideInCombatTypes.Spells = checked
        end,
        tooltip = 'Includes mounts, macros and flyouts.',
    })
    row3c:AddWidget(spellsCheck, 0.5)
    manager:Register(spellsCheck, 'all', 'combatHide')

    local aurasCheck = GUIFrame:CreateCheckbox(row3c, 'Auras', {
        value = db.HideInCombatTypes.Auras,
        callback = function(checked)
            db.HideInCombatTypes.Auras = checked
        end,
    })
    row3c:AddWidget(aurasCheck, 0.5)
    manager:Register(aurasCheck, 'all', 'combatHide')
    card3:AddRow(row3c, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card4: Font Settings
    local fontCard, fontOffset, fontWidgets = GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, {
        db = db,
        includeSoftOutline = false,
        onChangeCallback = ApplySettings,
        globalOverride = {},
        fontSizes = {
            { label = 'Header Text', dbKey = 'HeaderTextSize' },
            { label = 'Normal Text', dbKey = 'TextSize' },
            { label = 'Small Text',  dbKey = 'TextSmallSize' },
        },
    })
    manager:Register(fontCard, 'all')
    manager:RegisterGroup(fontWidgets, 'all')

    yOffset = fontOffset

    -- Card 5: Position
    local cardPos, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = false,
        showStrata = false,
        onChangeCallback = ApplySettings,
    })
    manager:Register(cardPos, "all")
    if cardPos.positionWidgets then manager:RegisterGroup(cardPos.positionWidgets, "all") end

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

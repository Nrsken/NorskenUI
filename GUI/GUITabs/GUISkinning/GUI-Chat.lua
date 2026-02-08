local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.LSM

-- Localization Setup
local table_insert = table.insert

-- Helper to get Chat module
local function GetChatModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("Chat", true)
    end
    return nil
end

-- Chat Tab Content
GUIFrame:RegisterContent("Chat", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.Chat
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get Chat module
    local CHAT = GetChatModule()

    -- Track widgets for enable/disable logic
    local allWidgets = {} -- All widgets (except main toggle)
    local bgWidgets = {}
    local customColorWidgets = {}

    -- Helper to apply settings
    local function ApplySettings()
        if CHAT then
            CHAT:Update()
        end
    end

    -- Helper to apply new state
    local function ApplyChatState(enabled)
        if not CHAT then return end
        CHAT.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("Chat")
        else
            NRSKNUI.Addon:DisableModule("Chat")
        end
    end

    -- Comprehensive widget state update
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false
        local bgEnabled = db.Backdrop and db.Backdrop.Enabled ~= false
        local ccEnabled = db.TabColors.InactiveColorMode and db.TabColors.InactiveColorMode == "custom"

        -- First: Apply main enable state to ALL widgets
        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end
        -- if main toggle is on, check bg widgets
        if mainEnabled then
            for _, widget in ipairs(bgWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(bgEnabled)
                end
            end

            for _, widget in ipairs(customColorWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(ccEnabled)
                end
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: Chat Skinning Enable
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Chat Skinning", yOffset)

    -- Enable Checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Chat Skinning", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyChatState(checked)
            UpdateAllWidgetStates()
            if not db.Enabled then
                NRSKNUI:CreateReloadPrompt("Enabling/Disabling Chat Skinning requires a reload to take full effect.")
            end
        end,
        true,
        "Chat Skinning",
        "On",
        "Off"
    )
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, 36)

    -- Separator
    local row1sep = GUIFrame:CreateRow(card1.content, 8)
    local seprow5Card = GUIFrame:CreateSeparator(row1sep)
    row1sep:AddWidget(seprow5Card, 1)
    table_insert(allWidgets, seprow5Card)
    card1:AddRow(row1sep, 8)

    -- Chat Width
    local row1b = GUIFrame:CreateRow(card1.content, 36)
    local chatWidth = GUIFrame:CreateSlider(row1b, "Chat Width", 50, 1000, 1,
        db.Width, nil,
        function(val)
            db.Width = val
            ApplySettings()
        end)
    row1b:AddWidget(chatWidth, 0.5)
    table_insert(allWidgets, chatWidth)

    -- Chat Height
    local chatHeight = GUIFrame:CreateSlider(row1b, "Chat Height", 50, 1000, 1,
        db.Height, nil,
        function(val)
            db.Height = val
            ApplySettings()
        end)
    row1b:AddWidget(chatHeight, 0.5)
    table_insert(allWidgets, chatHeight)
    card1:AddRow(row1b, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Font Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Font Settings", yOffset)
    table_insert(allWidgets, card2)

    -- Font Face, Outline, Size Row
    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do fontList[name] = name end
    else
        fontList["Friz Quadrata TT"] = "Friz Quadrata TT"
    end

    -- Font Face Dropdown
    local row2 = GUIFrame:CreateRow(card2.content, 40)
    local fontDropdown = GUIFrame:CreateDropdown(row2, "Font", fontList, db.FontFace, 30,
        function(key)
            db.FontFace = key
            ApplySettings()
        end)
    row2:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)

    -- Font Outline Dropdown
    local outlineList = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick" }
    local outlineDropdown = GUIFrame:CreateDropdown(row2, "Outline", outlineList, db.FontOutline or "OUTLINE", 45,
        function(key)
            db.FontOutline = key
            ApplySettings()
        end)
    row2:AddWidget(outlineDropdown, 0.5)
    table_insert(allWidgets, outlineDropdown)
    card2:AddRow(row2, 40)

    -- Separator
    local row2sep = GUIFrame:CreateRow(card2.content, 8)
    local seprow2Card = GUIFrame:CreateSeparator(row2sep)
    row2sep:AddWidget(seprow2Card, 1)
    table_insert(allWidgets, seprow2Card)
    card2:AddRow(row2sep, 8)

    -- Font Sizes
    local row3 = GUIFrame:CreateRow(card2.content, 40)
    local editBoxSizeSlider = GUIFrame:CreateSlider(row3, "EditBox Font Size", 8, 24, 1,
        db.EditBoxFontSize or 14, nil,
        function(val)
            db.EditBoxFontSize = val
            ApplySettings()
        end)
    row3:AddWidget(editBoxSizeSlider, 1)
    table_insert(allWidgets, editBoxSizeSlider)
    card2:AddRow(row3, 40)

    -- Separator
    local row3sep = GUIFrame:CreateRow(card2.content, 8)
    local seprow3Card = GUIFrame:CreateSeparator(row3sep)
    row3sep:AddWidget(seprow3Card, 1)
    table_insert(allWidgets, seprow3Card)
    card2:AddRow(row3sep, 8)

    local row3b = GUIFrame:CreateRow(card2.content, 40)
    local chatSizeSlider = GUIFrame:CreateSlider(row3b, "Chat Font Size", 8, 24, 1,
        db.ChatFontSize or 12, nil,
        function(val)
            db.ChatFontSize = val
            ApplySettings()
        end)
    row3b:AddWidget(chatSizeSlider, 1)
    table_insert(allWidgets, chatSizeSlider)
    card2:AddRow(row3b, 40)

    -- Separator
    local row4sep = GUIFrame:CreateRow(card2.content, 8)
    local seprow4Card = GUIFrame:CreateSeparator(row4sep)
    row4sep:AddWidget(seprow4Card, 1)
    table_insert(allWidgets, seprow4Card)
    card2:AddRow(row4sep, 8)

    local row3c = GUIFrame:CreateRow(card2.content, 40)
    local tabSizeSlider = GUIFrame:CreateSlider(row3c, "Tab Font Size", 8, 24, 1,
        db.TabFontSize or 12, nil,
        function(val)
            db.TabFontSize = val
            ApplySettings()
        end)
    row3c:AddWidget(tabSizeSlider, 1)
    table_insert(allWidgets, tabSizeSlider)
    card2:AddRow(row3c, 40)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Position Settings (using reusable position card)
    ----------------------------------------------------------------
    local card3, newOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        dbKeys = {
            anchorFrameType = "anchorFrameType",
            anchorFrameFrame = "ParentFrame",
            selfPoint = "AnchorFrom",
            anchorPoint = "AnchorTo",
            xOffset = "XOffset",
            yOffset = "YOffset",
            strata = "Strata",
        },
        showAnchorFrameType = false,
        showStrata = false,
        onChangeCallback = ApplySettings,
    })
    -- Add position card widgets to allWidgets for enable/disable
    if card3.positionWidgets then
        for _, widget in ipairs(card3.positionWidgets) do
            table_insert(allWidgets, widget)
        end
    end
    table_insert(allWidgets, card3)
    yOffset = newOffset

    ----------------------------------------------------------------
    -- Card 4: Backdrop Settings
    ----------------------------------------------------------------
    local card4 = GUIFrame:CreateCard(scrollChild, "Backdrop Settings", yOffset)
    table_insert(allWidgets, card4)

    -- Ensure Backdrop table exists
    db.Backdrop = db.Backdrop or {}

    -- Backdrop Toggle
    local row4 = GUIFrame:CreateRow(card4.content, 39)
    local backdropCheck = GUIFrame:CreateCheckbox(row4, "Enable Backdrop", db.Backdrop.Enabled ~= false,
        function(checked)
            db.Backdrop.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row4:AddWidget(backdropCheck, 1)
    table_insert(allWidgets, backdropCheck)
    card4:AddRow(row4, 39)

    -- Backdrop Color
    local row5 = GUIFrame:CreateRow(card4.content, 39)
    local backdropColor = GUIFrame:CreateColorPicker(row5, "Backdrop Color", db.Backdrop.Color or { 0, 0, 0, 0.8 },
        function(r, g, b, a)
            db.Backdrop.Color = { r, g, b, a }
            ApplySettings()
        end)
    row5:AddWidget(backdropColor, 1)
    table_insert(allWidgets, backdropColor)
    table_insert(bgWidgets, backdropColor)
    card4:AddRow(row5, 39)

    -- Border Color
    local row6 = GUIFrame:CreateRow(card4.content, 39)
    local borderColor = GUIFrame:CreateColorPicker(row6, "Border Color", db.Backdrop.BorderColor or { 0, 0, 0, 1 },
        function(r, g, b, a)
            db.Backdrop.BorderColor = { r, g, b, a }
            ApplySettings()
        end)
    row6:AddWidget(borderColor, 1)
    table_insert(allWidgets, borderColor)
    table_insert(bgWidgets, borderColor)
    card4:AddRow(row6, 39)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 5: EditBox Settings
    ----------------------------------------------------------------
    local card5 = GUIFrame:CreateCard(scrollChild, "EditBox Settings", yOffset)
    table_insert(allWidgets, card5)

    -- Ensure EditBox table exists
    db.EditBox = db.EditBox or {}

    -- EditBox Backdrop Color
    local row7 = GUIFrame:CreateRow(card5.content, 39)
    local editBoxBgColor = GUIFrame:CreateColorPicker(row7, "Backdrop Color",
        db.EditBox.BackdropColor or { 0, 0, 0, 0.8 },
        function(r, g, b, a)
            db.EditBox.BackdropColor = { r, g, b, a }
            ApplySettings()
        end)
    row7:AddWidget(editBoxBgColor, 0.5)
    table_insert(allWidgets, editBoxBgColor)

    -- EditBox Border Color
    local editBoxBorderColor = GUIFrame:CreateColorPicker(row7, "Border Color",
        db.EditBox.BorderColor or { 0, 0, 0, 1 },
        function(r, g, b, a)
            db.EditBox.BorderColor = { r, g, b, a }
            ApplySettings()
        end)
    row7:AddWidget(editBoxBorderColor, 0.5)
    table_insert(allWidgets, editBoxBorderColor)
    card5:AddRow(row7, 39)

    yOffset = yOffset + card5:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 6: Tab Colors
    ----------------------------------------------------------------
    local card6 = GUIFrame:CreateCard(scrollChild, "Tab Colors", yOffset)
    table_insert(allWidgets, card6)

    -- Ensure TabColors table exists
    db.TabColors = db.TabColors or {}

    -- Active and Alert Colors
    local row8 = GUIFrame:CreateRow(card6.content, 39)
    local activeColor = GUIFrame:CreateColorPicker(row8, "Active Tab",
        db.TabColors.ActiveColor or { 1, 1, 1, 1 },
        function(r, g, b, a)
            db.TabColors.ActiveColor = { r, g, b, a }
            ApplySettings()
        end)
    row8:AddWidget(activeColor, 0.5)
    table_insert(allWidgets, activeColor)

    local alertColor = GUIFrame:CreateColorPicker(row8, "Alert Tab",
        db.TabColors.AlertColor or { 1, 0, 0, 1 },
        function(r, g, b, a)
            db.TabColors.AlertColor = { r, g, b, a }
            ApplySettings()
        end)
    row8:AddWidget(alertColor, 0.5)
    table_insert(allWidgets, alertColor)
    card6:AddRow(row8, 39)

    -- Whisper Color
    local row9 = GUIFrame:CreateRow(card6.content, 39)
    local whisperColor = GUIFrame:CreateColorPicker(row9, "Whisper Tab",
        db.TabColors.WhisperColor or { 1, 0.5, 0.8, 1 },
        function(r, g, b, a)
            db.TabColors.WhisperColor = { r, g, b, a }
            ApplySettings()
        end)
    row9:AddWidget(whisperColor, 1)
    table_insert(allWidgets, whisperColor)
    card6:AddRow(row9, 39)

    -- Separator
    local row9sep = GUIFrame:CreateRow(card6.content, 8)
    row9sep:AddWidget(GUIFrame:CreateSeparator(row9sep), 1)
    card6:AddRow(row9sep, 8)

    -- Inactive Tab Color Mode
    local currentColorMode = db.TabColors.InactiveColorMode or "custom"

    local row10 = GUIFrame:CreateRow(card6.content, 40)
    local colorModeDropdown = GUIFrame:CreateDropdown(row10, "Inactive Color Mode",
        NRSKNUI.ColorModeOptions, currentColorMode, 70,
        function(key)
            db.TabColors.InactiveColorMode = key
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row10:AddWidget(colorModeDropdown, 0.5)
    table_insert(allWidgets, colorModeDropdown)

    -- Inactive Custom Color (only shown when mode is "custom")
    local inactiveColor = GUIFrame:CreateColorPicker(row10, "Inactive Custom Color",
        db.TabColors.InactiveColor,
        function(r, g, b, a)
            db.TabColors.InactiveColor = { r, g, b, a }
            ApplySettings()
        end)
    row10:AddWidget(inactiveColor, 0.5)
    table_insert(allWidgets, inactiveColor)
    table_insert(customColorWidgets, inactiveColor)
    card6:AddRow(row10, 40)

    yOffset = yOffset + card6:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 2)
    return yOffset
end)

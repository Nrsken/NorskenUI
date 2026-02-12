-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.LSM

-- Localization Setup
local table_insert = table.insert
local ipairs = ipairs
local pairs = pairs

-- Helper to get FocusCastbar module
local function GetFocusCastbarModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("FocusCastbar", true)
    end
    return nil
end

-- Focus Castbar Tab Content
GUIFrame:RegisterContent("FocusCastbar", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.FocusCastbar
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get module
    local FCB = GetFocusCastbarModule()

    -- Track widgets that depend on the toggle
    local allWidgets = {}

    -- Helper to apply settings and update preview
    local function ApplySettings()
        if FCB and FCB.ApplySettings then
            FCB:ApplySettings()
        end
    end

    -- Helper to apply position
    local function ApplyPosition()
        if FCB and FCB.ApplyPosition then
            FCB:ApplyPosition()
        end
    end

    -- Helper to apply new state
    local function ApplyFocusCastbarState(enabled)
        if not FCB then return end
        FCB.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("FocusCastbar")
        else
            NRSKNUI.Addon:DisableModule("FocusCastbar")
        end
    end

    -- Comprehensive widget state update
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false

        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end
    end

    -- Build LSM lists
    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do
            fontList[name] = name
        end
    else
        fontList["Friz Quadrata TT"] = "Friz Quadrata TT"
    end

    local statusbarList = {}
    if LSM then
        for name in pairs(LSM:HashTable("statusbar")) do
            statusbarList[name] = name
        end
    else
        statusbarList["Blizzard"] = "Blizzard"
    end

    ----------------------------------------------------------------
    -- Card 1: Focus Castbar Enable/Disable
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Focus Castbar", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Focus Castbar", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyFocusCastbarState(checked)
            UpdateAllWidgetStates()
        end,
        true, "Focus Castbar", "On", "Off"
    )
    row1:AddWidget(enableCheck, 0.5)
    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: General Settings (Size + Bar Texture)
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "General Settings", yOffset)
    table_insert(allWidgets, card2)

    -- Width and Height on same row
    local row2 = GUIFrame:CreateRow(card2.content, 40)
    local widthSlider = GUIFrame:CreateSlider(row2, "Width", 100, 400, 1,
        db.Width or 200, nil,
        function(val)
            db.Width = val
            ApplySettings()
        end)
    row2:AddWidget(widthSlider, 0.5)
    table_insert(allWidgets, widthSlider)

    local heightSlider = GUIFrame:CreateSlider(row2, "Height", 10, 40, 1,
        db.Height or 20, nil,
        function(val)
            db.Height = val
            ApplySettings()
        end)
    row2:AddWidget(heightSlider, 0.5)
    table_insert(allWidgets, heightSlider)
    card2:AddRow(row2, 40)

    -- Bar Texture
    local row2b = GUIFrame:CreateRow(card2.content, 36)
    local statusbarDropdown = GUIFrame:CreateDropdown(row2b, "Bar Texture", statusbarList,
        db.StatusBarTexture or "NorskenUI", 70,
        function(key)
            db.StatusBarTexture = key
            ApplySettings()
        end)
    row2b:AddWidget(statusbarDropdown, 1)
    table_insert(allWidgets, statusbarDropdown)
    card2:AddRow(row2b, 36)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Position
    ----------------------------------------------------------------
    local card3, newYOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
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
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = ApplyPosition,
    })
    table_insert(allWidgets, card3)
    yOffset = newYOffset

    ----------------------------------------------------------------
    -- Card 4: Font Settings
    ----------------------------------------------------------------
    local card4 = GUIFrame:CreateCard(scrollChild, "Font Settings", yOffset)
    table_insert(allWidgets, card4)

    local row4a = GUIFrame:CreateRow(card4.content, 40)
    local fontDropdown = GUIFrame:CreateDropdown(row4a, "Font", fontList,
        db.FontFace or "Expressway", 30,
        function(key)
            db.FontFace = key
            ApplySettings()
        end)
    row4a:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)

    local outlineList = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick" }
    local outlineDropdown = GUIFrame:CreateDropdown(row4a, "Outline", outlineList,
        db.FontOutline or "OUTLINE", 45,
        function(key)
            db.FontOutline = key
            ApplySettings()
        end)
    row4a:AddWidget(outlineDropdown, 0.5)
    table_insert(allWidgets, outlineDropdown)
    card4:AddRow(row4a, 40)

    local row4b = GUIFrame:CreateRow(card4.content, 36)
    local fontSizeSlider = GUIFrame:CreateSlider(row4b, "Font Size", 8, 24, 1,
        db.FontSize or 12, nil,
        function(val)
            db.FontSize = val
            ApplySettings()
        end)
    row4b:AddWidget(fontSizeSlider, 1)
    table_insert(allWidgets, fontSizeSlider)
    card4:AddRow(row4b, 36)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 5: Colors (2 rows, 4 colors at 0.5 each)
    ----------------------------------------------------------------
    local card5 = GUIFrame:CreateCard(scrollChild, "Colors", yOffset)
    table_insert(allWidgets, card5)

    -- Row 1: Casting + Channeling
    local row5a = GUIFrame:CreateRow(card5.content, 40)
    local castingColor = db.CastingColor or { 1, 0.7, 0, 1 }
    local castingPicker = GUIFrame:CreateColorPicker(row5a, "Casting", castingColor,
        function(r, g, b, a)
            db.CastingColor = { r, g, b, a }
            ApplySettings()
        end)
    row5a:AddWidget(castingPicker, 0.5)
    table_insert(allWidgets, castingPicker)

    local channelingColor = db.ChannelingColor or { 0, 0.7, 1, 1 }
    local channelingPicker = GUIFrame:CreateColorPicker(row5a, "Channeling", channelingColor,
        function(r, g, b, a)
            db.ChannelingColor = { r, g, b, a }
            ApplySettings()
        end)
    row5a:AddWidget(channelingPicker, 0.5)
    table_insert(allWidgets, channelingPicker)
    card5:AddRow(row5a, 40)

    -- Row 2: Empowering + Not Interruptible
    local row5b = GUIFrame:CreateRow(card5.content, 40)
    local empoweringColor = db.EmpoweringColor or { 0.8, 0.4, 1, 1 }
    local empoweringPicker = GUIFrame:CreateColorPicker(row5b, "Empowering", empoweringColor,
        function(r, g, b, a)
            db.EmpoweringColor = { r, g, b, a }
            ApplySettings()
        end)
    row5b:AddWidget(empoweringPicker, 0.5)
    table_insert(allWidgets, empoweringPicker)

    local notInterruptColor = db.NotInterruptibleColor or { 0.7, 0.7, 0.7, 1 }
    local notInterruptPicker = GUIFrame:CreateColorPicker(row5b, "Not Interruptible", notInterruptColor,
        function(r, g, b, a)
            db.NotInterruptibleColor = { r, g, b, a }
            ApplySettings()
        end)
    row5b:AddWidget(notInterruptPicker, 0.5)
    table_insert(allWidgets, notInterruptPicker)
    card5:AddRow(row5b, 40)

    -- Row 3: Hide Not Interruptible Toggle
    local row5c_toggle = GUIFrame:CreateRow(card5.content, 36)
    local hideNotInterruptCheck = GUIFrame:CreateCheckbox(row5c_toggle, "Hide Non-Interruptible Casts",
        db.HideNotInterruptible == true,
        function(checked)
            db.HideNotInterruptible = checked
        end,
        true, "Hide", "On", "Off"
    )
    row5c_toggle:AddWidget(hideNotInterruptCheck, 1)
    table_insert(allWidgets, hideNotInterruptCheck)
    card5:AddRow(row5c_toggle, 36)

    -- Separator
    local rowSep1 = GUIFrame:CreateRow(card5.content, 8)
    local sep1 = GUIFrame:CreateSeparator(rowSep1)
    rowSep1:AddWidget(sep1, 1)
    card5:AddRow(rowSep1, 8)

    -- Text Color
    local row5c = GUIFrame:CreateRow(card5.content, 40)
    local textColor = db.TextColor or { 1, 1, 1, 1 }
    local textPicker = GUIFrame:CreateColorPicker(row5c, "Text", textColor,
        function(r, g, b, a)
            db.TextColor = { r, g, b, a }
            ApplySettings()
        end)
    row5c:AddWidget(textPicker, 0.5)
    table_insert(allWidgets, textPicker)
    card5:AddRow(row5c, 40)

    -- Separator
    local rowSep2 = GUIFrame:CreateRow(card5.content, 8)
    local sep2 = GUIFrame:CreateSeparator(rowSep2)
    rowSep2:AddWidget(sep2, 1)
    card5:AddRow(rowSep2, 8)

    local row6a = GUIFrame:CreateRow(card5.content, 36)
    local bgColor = db.BackdropColor or { 0, 0, 0, 0.8 }
    local bgPicker = GUIFrame:CreateColorPicker(row6a, "Background", bgColor,
        function(r, g, b, a)
            db.BackdropColor = { r, g, b, a }
            ApplySettings()
        end)
    row6a:AddWidget(bgPicker, 0.5)
    table_insert(allWidgets, bgPicker)

    local borderColor = db.BorderColor or { 0, 0, 0, 1 }
    local borderPicker = GUIFrame:CreateColorPicker(row6a, "Border", borderColor,
        function(r, g, b, a)
            db.BorderColor = { r, g, b, a }
            ApplySettings()
        end)
    row6a:AddWidget(borderPicker, 0.5)
    table_insert(allWidgets, borderPicker)
    card5:AddRow(row6a, 36)

    yOffset = yOffset + card5:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 7: Hold Timer After Interrupt
    ----------------------------------------------------------------
    local card7 = GUIFrame:CreateCard(scrollChild, "Hold Timer", yOffset)
    table_insert(allWidgets, card7)

    -- Track hold timer widgets for sub-toggle
    local holdTimerWidgets = {}

    local function UpdateHoldTimerWidgetStates()
        local holdEnabled = db.HoldTimer and db.HoldTimer.Enabled ~= false
        for _, widget in ipairs(holdTimerWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(holdEnabled)
            end
        end
    end

    -- Initialize HoldTimer db if needed
    if not db.HoldTimer then
        db.HoldTimer = {
            Enabled = true,
            Duration = 0.5,
            InterruptedColor = { 0.1, 0.8, 0.1, 1 },
            SuccessColor = { 0.8, 0.1, 0.1, 1 },
        }
    end

    -- Enable Toggle
    local row7a = GUIFrame:CreateRow(card7.content, 40)
    local holdEnableCheck = GUIFrame:CreateCheckbox(row7a, "Enable Hold Timer", db.HoldTimer.Enabled ~= false,
        function(checked)
            db.HoldTimer.Enabled = checked
            UpdateHoldTimerWidgetStates()
        end,
        true, "Hold Timer", "On", "Off"
    )
    row7a:AddWidget(holdEnableCheck, 0.5)

    -- Hold Duration Slider
    local holdSlider = GUIFrame:CreateSlider(row7a, "Hold Duration", 0, 2, 0.1,
        db.HoldTimer.Duration or 0.5, nil,
        function(val)
            db.HoldTimer.Duration = val
            db.timeToHold = val
        end)
    row7a:AddWidget(holdSlider, 0.5)
    table_insert(holdTimerWidgets, holdSlider)
    card7:AddRow(row7a, 40)

    -- Separator
    local rowSep3 = GUIFrame:CreateRow(card7.content, 8)
    local sep3 = GUIFrame:CreateSeparator(rowSep3)
    rowSep3:AddWidget(sep3, 1)
    card7:AddRow(rowSep3, 8)

    -- Colors Row
    local row7c = GUIFrame:CreateRow(card7.content, 36)
    local interruptedColor = db.HoldTimer.InterruptedColor or { 0.1, 0.8, 0.1, 1 }
    local interruptedPicker = GUIFrame:CreateColorPicker(row7c, "Interrupted", interruptedColor,
        function(r, g, b, a)
            db.HoldTimer.InterruptedColor = { r, g, b, a }
        end)
    row7c:AddWidget(interruptedPicker, 0.5)
    table_insert(holdTimerWidgets, interruptedPicker)

    local successColor = db.HoldTimer.SuccessColor or { 0.8, 0.1, 0.1, 1 }
    local successPicker = GUIFrame:CreateColorPicker(row7c, "Cast Success", successColor,
        function(r, g, b, a)
            db.HoldTimer.SuccessColor = { r, g, b, a }
        end)
    row7c:AddWidget(successPicker, 0.5)
    table_insert(holdTimerWidgets, successPicker)
    card7:AddRow(row7c, 36)

    yOffset = yOffset + card7:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 8: Kick Indicator
    ----------------------------------------------------------------
    local card8 = GUIFrame:CreateCard(scrollChild, "Kick Indicator", yOffset)
    table_insert(allWidgets, card8)

    -- Track kick indicator widgets for sub-toggle
    local kickIndicatorWidgets = {}

    local function UpdateKickIndicatorWidgetStates()
        local kickEnabled = db.KickIndicator and db.KickIndicator.Enabled ~= false
        for _, widget in ipairs(kickIndicatorWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(kickEnabled)
            end
        end
    end

    -- Enable Toggle
    local row8a = GUIFrame:CreateRow(card8.content, 40)
    local kickEnableCheck = GUIFrame:CreateCheckbox(row8a, "Enable Kick Indicator", db.KickIndicator.Enabled ~= false,
        function(checked)
            db.KickIndicator.Enabled = checked
            UpdateKickIndicatorWidgetStates()
        end,
        true, "Kick Indicator", "On", "Off"
    )
    row8a:AddWidget(kickEnableCheck, 1)
    card8:AddRow(row8a, 40)

    -- Separator
    local rowSepKick = GUIFrame:CreateRow(card8.content, 8)
    local sepKick = GUIFrame:CreateSeparator(rowSepKick)
    rowSepKick:AddWidget(sepKick, 1)
    card8:AddRow(rowSepKick, 8)

    -- Colors Row
    local row8c = GUIFrame:CreateRow(card8.content, 40)
    local readyColor = db.KickIndicator.ReadyColor or { 0.1, 0.8, 0.1, 1 }
    local readyPicker = GUIFrame:CreateColorPicker(row8c, "Kick Ready", readyColor,
        function(r, g, b, a)
            db.KickIndicator.ReadyColor = { r, g, b, a }
            ApplySettings()
        end)
    row8c:AddWidget(readyPicker, 0.5)
    table_insert(kickIndicatorWidgets, readyPicker)

    local notReadyColor = db.KickIndicator.NotReadyColor or { 0.5, 0.5, 0.5, 1 }
    local notReadyPicker = GUIFrame:CreateColorPicker(row8c, "Kick Not Ready", notReadyColor,
        function(r, g, b, a)
            db.KickIndicator.NotReadyColor = { r, g, b, a }
            ApplySettings()
        end)
    row8c:AddWidget(notReadyPicker, 0.5)
    table_insert(kickIndicatorWidgets, notReadyPicker)
    card8:AddRow(row8c, 40)

    -- Tick Color Row
    local row8d = GUIFrame:CreateRow(card8.content, 36)
    local tickColor = db.KickIndicator.TickColor or { 1, 1, 1, 1 }
    local tickPicker = GUIFrame:CreateColorPicker(row8d, "Kick Ready Tick", tickColor,
        function(r, g, b, a)
            db.KickIndicator.TickColor = { r, g, b, a }
            ApplySettings()
        end)
    row8d:AddWidget(tickPicker, 0.5)
    table_insert(kickIndicatorWidgets, tickPicker)
    card8:AddRow(row8d, 36)

    yOffset = yOffset + card8:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    UpdateHoldTimerWidgetStates()
    UpdateKickIndicatorWidgetStates()
    yOffset = yOffset - Theme.paddingSmall
    return yOffset
end)

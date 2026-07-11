---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

local table_insert = table.insert
local ipairs = ipairs
local pairs = pairs

GUIFrame:RegisterContent("FocusCastbar", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.FocusCastbar
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local FCB = NRSKNUI:GetModule("FocusCastbar", true)
    local manager = GUIFrame:CreateWidgetStateManager()
    local postUpdateCallbacks = {}
    local holdTimerSubWidgets = {}
    local kickIndicatorSubWidgets = {}
    local uninterruptibleSubWidgets = {}
    local allCards = {}

    local function ApplySettings()
        if FCB and FCB.ApplySettings then FCB:ApplySettings() end
    end

    local function UpdateHoldTimerState()
        local holdEnabled = db.HoldTimer and db.HoldTimer.Enabled
        for _, widget in ipairs(holdTimerSubWidgets) do
            if widget.SetEnabled then widget:SetEnabled(holdEnabled) end
        end
    end

    local function UpdateKickIndicatorState()
        local kickEnabled = db.KickIndicator and db.KickIndicator.Enabled
        for _, widget in ipairs(kickIndicatorSubWidgets) do
            if widget.SetEnabled then widget:SetEnabled(kickEnabled) end
        end
    end

    local function UpdateUninterruptibleState()
        local enabled = not db.HideNotInterruptible
        for _, widget in ipairs(uninterruptibleSubWidgets) do
            if widget.SetEnabled then widget:SetEnabled(enabled) end
        end
    end

    local function UpdateAllWidgetStates()
        manager:UpdateAll(db.Enabled)
        if db.Enabled then
            for _, callback in ipairs(postUpdateCallbacks) do
                callback()
            end
        end
    end

    local function RelayoutCards()
        local y = allCards[1] and allCards[1]:GetNextOffset() or yOffset
        for i = 2, #allCards do
            local card = allCards[i]
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", Theme.paddingSmall, -y)
            card:SetPoint("RIGHT", scrollChild, "RIGHT", -Theme.paddingSmall, 0)
            card._yOffset = y
            y = card:GetNextOffset()
        end
    end

    local statusbarList = {}
    if LSM then
        for name in pairs(LSM:HashTable("statusbar")) do
            statusbarList[name] = name
        end
    end

    local anchorOptions = {
        { key = "LEFT",   text = "Left" },
        { key = "CENTER", text = "Center" },
        { key = "RIGHT",  text = "Right" },
    }

    -- Card 1: Enable
    local card1 = GUIFrame:CreateCard(scrollChild, "Focus Castbar", yOffset)
    table_insert(allCards, card1)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Focus Castbar", {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if FCB then
                if checked then NRSKNUI:EnableModule("FocusCastbar") else NRSKNUI:DisableModule("FocusCastbar") end
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = "Focus Castbar",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Bar Appearance
    local card2 = GUIFrame:CreateCard(scrollChild, "Bar Appearance", yOffset)
    table_insert(allCards, card2)
    manager:Register(card2, "all")

    local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local widthSlider = GUIFrame:CreateSlider(row2a, "Width", {
        min = 100,
        max = 1000,
        step = 1,
        value = db.Width,
        callback = function(val)
            db.Width = val; ApplySettings()
        end
    })
    row2a:AddWidget(widthSlider, 0.5)
    manager:Register(widthSlider, "all")

    local heightSlider = GUIFrame:CreateSlider(row2a, "Height", {
        min = 5,
        max = 500,
        step = 1,
        value = db.Height,
        callback = function(val)
            db.Height = val; ApplySettings()
        end
    })
    row2a:AddWidget(heightSlider, 0.5)
    manager:Register(heightSlider, "all")
    card2:AddRow(row2a, Theme.rowHeight)

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local useGlobalBarCheck = GUIFrame:CreateCheckbox(row2b, "Use Global Bar", {
        value = db.UseGlobalBar ~= false,
        callback = function(checked)
            db.UseGlobalBar = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row2b:AddWidget(useGlobalBarCheck, 0.5)
    manager:Register(useGlobalBarCheck, "all")

    manager:SetCondition("GlobalOn", function() return not db.UseGlobalBar end)

    local statusbarDropdown = GUIFrame:CreateDropdown(row2b, "Bar Texture", {
        options = statusbarList,
        value = db.StatusBarTexture,
        searchable = true,
        callback = function(key)
            db.StatusBarTexture = key; ApplySettings()
        end
    })
    row2b:AddWidget(statusbarDropdown, 0.5)
    manager:Register(statusbarDropdown, "all", "GlobalOn")
    card2:AddRow(row2b, Theme.rowHeight)

    local row2c = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)

    local bgPicker = GUIFrame:CreateColorPicker(row2c, "Background", {
        color = db.BackdropColor,
        callback = function(r, g, b, a)
            db.BackdropColor = { r, g, b, a }; ApplySettings()
        end
    })
    row2c:AddWidget(bgPicker, 0.5)
    manager:Register(bgPicker, "all")

    local borderPicker = GUIFrame:CreateColorPicker(row2c, "Border", {
        color = db.BorderColor,
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }; ApplySettings()
        end
    })
    row2c:AddWidget(borderPicker, 0.5)
    manager:Register(borderPicker, "all")
    card2:AddRow(row2c, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Colors & Indicators
    local card3 = GUIFrame:CreateCard(scrollChild, "Colors & Indicators", yOffset)
    table_insert(allCards, card3)
    manager:Register(card3, "all")

    local row3a = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local textPicker = GUIFrame:CreateColorPicker(row3a, "Text", {
        color = db.TextColor,
        callback = function(r, g, b, a)
            db.TextColor = { r, g, b, a }; ApplySettings()
        end
    })
    row3a:AddWidget(textPicker, 0.5)
    manager:Register(textPicker, "all")

    local castPicker = GUIFrame:CreateColorPicker(row3a, "Cast / Kick Ready", {
        color = db.CastColor,
        callback = function(r, g, b, a)
            db.CastColor = { r, g, b, a }; ApplySettings()
        end
    })
    row3a:AddWidget(castPicker, 0.5)
    manager:Register(castPicker, "all")
    card3:AddRow(row3a, Theme.rowHeight)

    local sep3_1 = GUIFrame:CreateSeparator(card3.content)
    card3:AddRow(sep3_1, Theme.rowHeightSeparator)

    local row3a2 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local hideNotInterruptCheck = GUIFrame:CreateCheckbox(row3a2, "Hide Uninterruptible", {
        value = db.HideNotInterruptible,
        callback = function(checked)
            db.HideNotInterruptible = checked
            UpdateUninterruptibleState()
        end
    })
    row3a2:AddWidget(hideNotInterruptCheck, 0.5)
    manager:Register(hideNotInterruptCheck, "all")

    local notInterruptPicker = GUIFrame:CreateColorPicker(row3a2, "Uninterruptible", {
        color = db.NotInterruptibleColor,
        callback = function(r, g, b, a)
            db.NotInterruptibleColor = { r, g, b, a }; ApplySettings()
        end
    })
    row3a2:AddWidget(notInterruptPicker, 0.5)
    manager:Register(notInterruptPicker, "all")
    table_insert(uninterruptibleSubWidgets, notInterruptPicker)
    card3:AddRow(row3a2, Theme.rowHeight)
    table_insert(postUpdateCallbacks, UpdateUninterruptibleState)

    local sep3_2 = GUIFrame:CreateSeparator(card3.content)
    card3:AddRow(sep3_2, Theme.rowHeightSeparator)

    local row3a3 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local kickEnableCheck = GUIFrame:CreateCheckbox(row3a3, "Kick Indicator", {
        value = db.KickIndicator.Enabled,
        callback = function(checked)
            db.KickIndicator.Enabled = checked; UpdateKickIndicatorState()
        end
    })
    row3a3:AddWidget(kickEnableCheck, 0.5)
    manager:Register(kickEnableCheck, "all")

    local notReadyPicker = GUIFrame:CreateColorPicker(row3a3, "Not Ready", {
        color = db.KickIndicator.NotReadyColor,
        callback = function(r, g, b, a)
            db.KickIndicator.NotReadyColor = { r, g, b, a }; ApplySettings()
        end
    })
    row3a3:AddWidget(notReadyPicker, 0.26)
    manager:Register(notReadyPicker, "all")
    table_insert(kickIndicatorSubWidgets, notReadyPicker)

    local tickPicker = GUIFrame:CreateColorPicker(row3a3, "Tick", {
        color = db.KickIndicator.TickColor,
        callback = function(r, g, b, a)
            db.KickIndicator.TickColor = { r, g, b, a }; ApplySettings()
        end
    })
    row3a3:AddWidget(tickPicker, 0.24)
    manager:Register(tickPicker, "all")
    table_insert(kickIndicatorSubWidgets, tickPicker)
    card3:AddRow(row3a3, Theme.rowHeight)
    table_insert(postUpdateCallbacks, UpdateKickIndicatorState)

    local sep3a = GUIFrame:CreateSeparator(card3.content)
    card3:AddRow(sep3a, Theme.rowHeightSeparator)

    local row3b = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local holdEnableCheck = GUIFrame:CreateCheckbox(row3b, "Hold Timer", {
        value = db.HoldTimer.Enabled,
        callback = function(checked)
            db.HoldTimer.Enabled = checked; UpdateHoldTimerState()
        end
    })
    row3b:AddWidget(holdEnableCheck, 0.5)
    manager:Register(holdEnableCheck, "all")

    local interruptedPicker = GUIFrame:CreateColorPicker(row3b, "Interrupted", {
        color = db.HoldTimer.InterruptedColor,
        callback = function(r, g, b, a) db.HoldTimer.InterruptedColor = { r, g, b, a } end
    })
    row3b:AddWidget(interruptedPicker, 0.5)
    manager:Register(interruptedPicker, "all")
    table_insert(holdTimerSubWidgets, interruptedPicker)
    card3:AddRow(row3b, Theme.rowHeight)

    local row3b2 = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local holdSlider = GUIFrame:CreateSlider(row3b2, "Duration", {
        min = 0,
        max = 2,
        step = 0.1,
        value = db.HoldTimer.Duration,
        callback = function(val)
            db.HoldTimer.Duration = val; db.timeToHold = val
        end
    })
    row3b2:AddWidget(holdSlider, 0.5)
    manager:Register(holdSlider, "all")
    table_insert(holdTimerSubWidgets, holdSlider)

    local successPicker = GUIFrame:CreateColorPicker(row3b2, "Success", {
        color = db.HoldTimer.SuccessColor,
        callback = function(r, g, b, a) db.HoldTimer.SuccessColor = { r, g, b, a } end
    })
    row3b2:AddWidget(successPicker, 0.5)
    manager:Register(successPicker, "all")
    table_insert(holdTimerSubWidgets, successPicker)
    card3:AddRow(row3b2, Theme.rowHeightLast, 0)
    table_insert(postUpdateCallbacks, UpdateHoldTimerState)

    yOffset = card3:GetNextOffset()

    -- Card: Important Spell Glow
    local glowCard, glowOffset, glowWidgets = GUIFrame:CreateGlowSettingsCard(scrollChild, yOffset, {
        title = "Important Spell Glow",
        db = db.ImportantGlow,
        glowTypes = { "pixel", "autocast" },
        onChangeCallback = function()
            if FCB then FCB:ResetGlow() end
            ApplySettings()
            RelayoutCards()
        end,
        onHeightChange = RelayoutCards,
    })
    table_insert(allCards, glowCard)
    manager:Register(glowCard, "all")
    manager:RegisterGroup(glowWidgets, "all")
    if glowCard.updateTypeVisibility then table_insert(postUpdateCallbacks, glowCard.updateTypeVisibility) end

    yOffset = glowOffset

    -- Card 4: Target Names
    local card4 = GUIFrame:CreateCard(scrollChild, "Target Names", yOffset)
    table_insert(allCards, card4)
    manager:Register(card4, "all")

    local row4a = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local targetAnchorDropdown = GUIFrame:CreateDropdown(row4a, "Anchor", {
        options = anchorOptions,
        value = db.TargetNames.Anchor,
        callback = function(key)
            db.TargetNames.Anchor = key; ApplySettings()
        end
    })
    row4a:AddWidget(targetAnchorDropdown, 0.5)
    manager:Register(targetAnchorDropdown, "all")

    local targetXSlider = GUIFrame:CreateSlider(row4a, "X Offset", {
        min = -100,
        max = 100,
        step = 1,
        value = db.TargetNames.XOffset,
        callback = function(val)
            db.TargetNames.XOffset = val; ApplySettings()
        end
    })
    row4a:AddWidget(targetXSlider, 0.5)
    manager:Register(targetXSlider, "all")
    card4:AddRow(row4a, Theme.rowHeight)

    local row4b = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
    local targetYSlider = GUIFrame:CreateSlider(row4b, "Y Offset", {
        min = -50,
        max = 100,
        step = 1,
        value = db.TargetNames.YOffset,
        callback = function(val)
            db.TargetNames.YOffset = val; ApplySettings()
        end
    })
    row4b:AddWidget(targetYSlider, 1)
    manager:Register(targetYSlider, "all")
    card4:AddRow(row4b, Theme.rowHeightLast, 0)

    yOffset = card4:GetNextOffset()

    -- Card 5: Raid Marker
    local card5 = GUIFrame:CreateCard(scrollChild, "Raid Marker", yOffset)
    table_insert(allCards, card5)
    manager:Register(card5, "all")

    local row5a = GUIFrame:CreateRow(card5.content, Theme.rowHeight)
    local markerAnchorDropdown = GUIFrame:CreateDropdown(row5a, "Anchor", {
        options = anchorOptions,
        value = db.TargetMarker.Anchor,
        callback = function(key)
            db.TargetMarker.Anchor = key; ApplySettings()
        end
    })
    row5a:AddWidget(markerAnchorDropdown, 0.5)
    manager:Register(markerAnchorDropdown, "all")

    local markerSizeSlider = GUIFrame:CreateSlider(row5a, "Size", {
        min = 1,
        max = 100,
        step = 1,
        value = db.TargetMarker.Size,
        callback = function(val)
            db.TargetMarker.Size = val; ApplySettings()
        end
    })
    row5a:AddWidget(markerSizeSlider, 0.5)
    manager:Register(markerSizeSlider, "all")
    card5:AddRow(row5a, Theme.rowHeight)

    local row5b = GUIFrame:CreateRow(card5.content, Theme.rowHeightLast)
    local markerXSlider = GUIFrame:CreateSlider(row5b, "X Offset", {
        min = -100,
        max = 100,
        step = 1,
        value = db.TargetMarker.XOffset,
        callback = function(val)
            db.TargetMarker.XOffset = val; ApplySettings()
        end
    })
    row5b:AddWidget(markerXSlider, 0.5)
    manager:Register(markerXSlider, "all")

    local markerYSlider = GUIFrame:CreateSlider(row5b, "Y Offset", {
        min = -50,
        max = 100,
        step = 1,
        value = db.TargetMarker.YOffset,
        callback = function(val)
            db.TargetMarker.YOffset = val; ApplySettings()
        end
    })
    row5b:AddWidget(markerYSlider, 0.5)
    manager:Register(markerYSlider, "all")
    card5:AddRow(row5b, Theme.rowHeightLast, 0)

    yOffset = card5:GetNextOffset()

    -- Card 6: Font Settings
    local fontCard, fontOffset, fontWidgets = GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, {
        db = db,
        includeSoftOutline = true,
        fontSizes = {
            { label = "Spell Name",  dbKey = "FontSize" },
            { label = "Target Name", dbKey = "TargetNames.FontSize" },
        },
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
    table_insert(allCards, fontCard)
    manager:Register(fontCard, "all")
    manager:RegisterGroup(fontWidgets, "all")
    if fontCard.UpdateShadowState then table_insert(postUpdateCallbacks, fontCard.UpdateShadowState) end

    yOffset = fontOffset

    -- Card 7: Position
    local posCard, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })
    table_insert(allCards, posCard)
    manager:Register(posCard, "all")

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

GUIFrame:RegisterContent("CustomSkin_Debuffs", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.DebuffTracking
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    ---@type AuraDebuffs?
    local DBF = NorskenUI and NorskenUI:GetModule("AuraDebuffs", true)
    local manager = GUIFrame:CreateWidgetStateManager()

    manager:SetCondition("swipeOn", function() return db.Swipe end)

    local function ApplySettings()
        if DBF and DBF:IsEnabled() and DBF.ApplySettings then
            DBF:ApplySettings()
        end
    end

    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    -- Card 1: Enable
    local card1 = GUIFrame:CreateCard(scrollChild, "Advanced Debuff Frame", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Advanced Debuff Frame", {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if DBF then
                DBF.db.Enabled = checked
                if checked then
                    NorskenUI:EnableModule("AuraDebuffs")
                else
                    NorskenUI:DisableModule("AuraDebuffs")
                end
            end
            UpdateAllWidgetStates()
            NRSKNUI:CreateReloadPrompt("Enabling/Disabling this module requires a reload.")
        end,
        msgPopup = true,
        msgText = "Custom Debuff Frame",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Icon Settings
    local card2 = GUIFrame:CreateCard(scrollChild, "Icon Settings", yOffset)
    manager:Register(card2, "all")

    local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local iconSizeSlider = GUIFrame:CreateSlider(row2a, "Icon Size", {
        min = 16,
        max = 80,
        step = 1,
        value = db.IconSize,
        callback = function(value)
            db.IconSize = value
            ApplySettings()
        end
    })
    row2a:AddWidget(iconSizeSlider, 0.5)
    manager:Register(iconSizeSlider, "all")

    local iconSpacingSlider = GUIFrame:CreateSlider(row2a, "Icon Spacing", {
        min = 0,
        max = 10,
        step = 1,
        value = db.IconSpacing,
        callback = function(value)
            db.IconSpacing = value
            ApplySettings()
        end
    })
    row2a:AddWidget(iconSpacingSlider, 0.5)
    manager:Register(iconSpacingSlider, "all")
    card2:AddRow(row2a, Theme.rowHeight)

    local separator2a1 = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(separator2a1, Theme.rowHeightSeparator)

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local maxIconsSlider = GUIFrame:CreateSlider(row2b, "Max Icons", {
        min = 1,
        max = 40,
        step = 1,
        value = db.MaxIcons,
        callback = function(value)
            db.MaxIcons = value
            ApplySettings()
        end
    })
    row2b:AddWidget(maxIconsSlider, 0.5)
    manager:Register(maxIconsSlider, "all")

    local iconsPerRowSlider = GUIFrame:CreateSlider(row2b, "Icons Per Row", {
        min = 1,
        max = 20,
        step = 1,
        value = db.IconsPerRow,
        callback = function(value)
            db.IconsPerRow = value
            ApplySettings()
        end
    })
    row2b:AddWidget(iconsPerRowSlider, 0.5)
    manager:Register(iconsPerRowSlider, "all")
    card2:AddRow(row2b, Theme.rowHeight)

    local separator2a2 = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(separator2a2, Theme.rowHeightSeparator)

    local growthOptions = {
        { key = "LEFT",  text = "Left" },
        { key = "RIGHT", text = "Right" },
    }
    local wrapOptions = {
        { key = "UP",   text = "Up" },
        { key = "DOWN", text = "Down" },
    }

    local row2c = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local growthDropdown = GUIFrame:CreateDropdown(row2c, "Growth Direction", {
        options = growthOptions,
        value = db.GrowthDirection or "RIGHT",
        callback = function(key)
            db.GrowthDirection = key
            ApplySettings()
        end
    })
    row2c:AddWidget(growthDropdown, 0.5)
    manager:Register(growthDropdown, "all")

    local wrapDropdown = GUIFrame:CreateDropdown(row2c, "Wrap Direction", {
        options = wrapOptions,
        value = db.WrapDirection or "DOWN",
        callback = function(key)
            db.WrapDirection = key
            ApplySettings()
        end
    })
    row2c:AddWidget(wrapDropdown, 0.5)
    manager:Register(wrapDropdown, "all")
    card2:AddRow(row2c, Theme.rowHeight)

    local separator2a = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(separator2a, Theme.rowHeightSeparator)

    local rowSwipe = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local swipeCheck = GUIFrame:CreateCheckbox(rowSwipe, "Enable Swipe", {
        value = db.Swipe,
        callback = function(checked)
            db.Swipe = checked
            ApplySettings()
            UpdateAllWidgetStates()
            if DBF then DBF:TogglePreview() end
        end
    })
    rowSwipe:AddWidget(swipeCheck, 0.5)
    manager:Register(swipeCheck, "all")

    local reverseCheck = GUIFrame:CreateCheckbox(rowSwipe, "Reverse Swipe", {
        value = db.Reverse,
        callback = function(checked)
            db.Reverse = checked
            ApplySettings()
            if DBF then DBF:TogglePreview() end
        end
    })
    rowSwipe:AddWidget(reverseCheck, 0.5)
    manager:Register(reverseCheck, "all", "swipeOn")
    card2:AddRow(rowSwipe, Theme.rowHeight)

    local separator2b = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(separator2b, Theme.rowHeightSeparator)

    local rowDispel = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local dispelBorderCheck = GUIFrame:CreateCheckbox(rowDispel, "Show Dispel Border", {
        tooltip = "Show a colored border based on dispel type.",
        value = db.ShowDispelBorder,
        callback = function(checked)
            db.ShowDispelBorder = checked
            ApplySettings()
        end
    })
    rowDispel:AddWidget(dispelBorderCheck, 0.5)
    manager:Register(dispelBorderCheck, "all")

    local tooltipCheck = GUIFrame:CreateCheckbox(rowDispel, "Show Tooltips", {
        tooltip = "Show aura tooltip on hover.",
        value = db.ShowTooltips,
        callback = function(checked)
            db.ShowTooltips = checked
            ApplySettings()
        end
    })
    rowDispel:AddWidget(tooltipCheck, 0.5)
    manager:Register(tooltipCheck, "all")
    card2:AddRow(rowDispel, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: ColorBlind Settings
    local card3 = GUIFrame:CreateCard(scrollChild, "ColorBlind Settings", yOffset)
    manager:Register(card3, "all")

    manager:SetCondition("colorBlindOn", function() return db.ColorBlindText end)

    local textAnchorOptions = {
        { key = "TOPLEFT",     text = "Top Left" },
        { key = "TOP",         text = "Top" },
        { key = "TOPRIGHT",    text = "Top Right" },
        { key = "LEFT",        text = "Left" },
        { key = "CENTER",      text = "Center" },
        { key = "RIGHT",       text = "Right" },
        { key = "BOTTOMLEFT",  text = "Bottom Left" },
        { key = "BOTTOM",      text = "Bottom" },
        { key = "BOTTOMRIGHT", text = "Bottom Right" },
    }

    db.ColorBlindPosition = db.ColorBlindPosition or { AnchorFrom = "TOP", AnchorTo = "BOTTOM", XOffset = 0, YOffset = -1 }

    local row3a = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local colorBlindCheck = GUIFrame:CreateCheckbox(row3a, "ColorBlind Text", {
        tooltip = "Show dispel type abbreviation text on debuffs.",
        value = db.ColorBlindText,
        callback = function(checked)
            db.ColorBlindText = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row3a:AddWidget(colorBlindCheck, 0.5)
    manager:Register(colorBlindCheck, "all")

    local colorBlindSizeSlider = GUIFrame:CreateSlider(row3a, "Font Size", {
        min = 8,
        max = 24,
        step = 1,
        value = db.ColorBlindFontSize or 16,
        callback = function(value)
            db.ColorBlindFontSize = value
            ApplySettings()
        end
    })
    row3a:AddWidget(colorBlindSizeSlider, 0.5)
    manager:Register(colorBlindSizeSlider, "all", "colorBlindOn")
    card3:AddRow(row3a, Theme.rowHeight)

    local sep3a = GUIFrame:CreateSeparator(card3.content)
    card3:AddRow(sep3a, Theme.rowHeightSeparator)

    local row3b = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local colorBlindAnchorDropdown = GUIFrame:CreateDropdown(row3b, "Anchor", {
        options = textAnchorOptions,
        value = db.ColorBlindPosition.AnchorFrom or "TOP",
        callback = function(key)
            db.ColorBlindPosition.AnchorFrom = key
            db.ColorBlindPosition.AnchorTo = key == "TOP" and "BOTTOM" or key == "BOTTOM" and "TOP" or key
            ApplySettings()
        end
    })
    row3b:AddWidget(colorBlindAnchorDropdown, 1 / 3)
    manager:Register(colorBlindAnchorDropdown, "all", "colorBlindOn")

    local colorBlindXSlider = GUIFrame:CreateSlider(row3b, "X Offset", {
        min = -50,
        max = 50,
        step = 1,
        value = db.ColorBlindPosition.XOffset or 0,
        callback = function(value)
            db.ColorBlindPosition.XOffset = value
            ApplySettings()
        end
    })
    row3b:AddWidget(colorBlindXSlider, 1 / 3)
    manager:Register(colorBlindXSlider, "all", "colorBlindOn")

    local colorBlindYSlider = GUIFrame:CreateSlider(row3b, "Y Offset", {
        min = -50,
        max = 50,
        step = 1,
        value = db.ColorBlindPosition.YOffset or -1,
        callback = function(value)
            db.ColorBlindPosition.YOffset = value
            ApplySettings()
        end
    })
    row3b:AddWidget(colorBlindYSlider, 1 / 3)
    manager:Register(colorBlindYSlider, "all", "colorBlindOn")
    card3:AddRow(row3b, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card 4: Text Positions
    local card4 = GUIFrame:CreateCard(scrollChild, "Text Positions", yOffset)
    manager:Register(card4, "all")

    db.TimerPosition = db.TimerPosition or {}
    db.StackPosition = db.StackPosition or
        { AnchorFrom = "BOTTOMRIGHT", AnchorTo = "BOTTOMRIGHT", XOffset = -1, YOffset = 1 }

    local row4a = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local timerAnchorDropdown = GUIFrame:CreateDropdown(row4a, "Timer Anchor", {
        options = textAnchorOptions,
        value = db.TimerPosition.AnchorFrom or "CENTER",
        callback = function(key)
            db.TimerPosition.AnchorFrom = key
            db.TimerPosition.AnchorTo = key
            ApplySettings()
        end
    })
    row4a:AddWidget(timerAnchorDropdown, 1 / 3)
    manager:Register(timerAnchorDropdown, "all")

    local timerXSlider = GUIFrame:CreateSlider(row4a, "Timer X", {
        min = -50,
        max = 50,
        step = 1,
        value = db.TimerPosition.XOffset or 0,
        callback = function(value)
            db.TimerPosition.XOffset = value
            ApplySettings()
        end
    })
    row4a:AddWidget(timerXSlider, 1 / 3)
    manager:Register(timerXSlider, "all")

    local timerYSlider = GUIFrame:CreateSlider(row4a, "Timer Y", {
        min = -50,
        max = 50,
        step = 1,
        value = db.TimerPosition.YOffset or 0,
        callback = function(value)
            db.TimerPosition.YOffset = value
            ApplySettings()
        end
    })
    row4a:AddWidget(timerYSlider, 1 / 3)
    manager:Register(timerYSlider, "all")
    card4:AddRow(row4a, Theme.rowHeight)

    local textSettingSep = GUIFrame:CreateSeparator(card4.content)
    card4:AddRow(textSettingSep, Theme.rowHeightSeparator)

    local row4b = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
    local stackAnchorDropdown = GUIFrame:CreateDropdown(row4b, "Stack Anchor", {
        options = textAnchorOptions,
        value = db.StackPosition.AnchorFrom,
        callback = function(key)
            db.StackPosition.AnchorFrom = key
            db.StackPosition.AnchorTo = key
            ApplySettings()
        end
    })
    row4b:AddWidget(stackAnchorDropdown, 1 / 3)
    manager:Register(stackAnchorDropdown, "all")

    local stackXSlider = GUIFrame:CreateSlider(row4b, "Stack X", {
        min = -50,
        max = 50,
        step = 1,
        value = db.StackPosition.XOffset,
        callback = function(value)
            db.StackPosition.XOffset = value
            ApplySettings()
        end
    })
    row4b:AddWidget(stackXSlider, 1 / 3)
    manager:Register(stackXSlider, "all")

    local stackYSlider = GUIFrame:CreateSlider(row4b, "Stack Y", {
        min = -50,
        max = 50,
        step = 1,
        value = db.StackPosition.YOffset,
        callback = function(value)
            db.StackPosition.YOffset = value
            ApplySettings()
        end
    })
    row4b:AddWidget(stackYSlider, 1 / 3)
    manager:Register(stackYSlider, "all")
    card4:AddRow(row4b, Theme.rowHeightLast, 0)

    yOffset = card4:GetNextOffset()

    -- Card 5: Font Settings
    local fontCard, fontOffset, fontWidgets = GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, {
        title = "Font Settings",
        db = db,
        dbKeys = { fontFace = "FontFace", fontOutline = "FontOutline" },
        fontSizes = {
            { label = "Timer Size", dbKey = "TimerFontSize" },
            { label = "Stack Size", dbKey = "StackFontSize" },
        },
        fontSizeRange = { 8, 32 },
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
    manager:Register(fontCard, "all")
    manager:RegisterGroup(fontWidgets, "all")

    yOffset = fontOffset

    -- Card 6: Position
    local posCard, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = true,
        showStrata = true,
        disableAnchorFrom = true,
        onChangeCallback = ApplySettings
    })
    manager:Register(posCard, "all")

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

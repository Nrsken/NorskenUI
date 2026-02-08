-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.LSM

-- Localization
local table_insert = table.insert

-- Helper to get Combat Message module
local function GetTooltipsModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("Tooltips", true)
    end
    return nil
end

-- Register Content
GUIFrame:RegisterContent("tooltips", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.Tooltips
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get tooltips module
    local TT = GetTooltipsModule()

    -- Track widgets for enable/disable logic
    local allWidgets = {}

    -- Helper to apply settings
    local function ApplySettings()
        if TT then
            TT:Refresh()
        end
    end

    -- Helper to apply new state
    local function ApplyTooltipState(enabled)
        if not TT then return end
        TT.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("Tooltips")
        else
            NRSKNUI.Addon:DisableModule("Tooltips")
        end
    end

    -- Comprehensive widget state update
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false

        -- First: Apply main enable state to ALL widgets
        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: Master Toggle
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Tooltip Skinning", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 40)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Tooltip Skinning", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyTooltipState(checked)
            UpdateAllWidgetStates()
            if not checked then
                NRSKNUI:CreateReloadPrompt("Enabling Blizzard UI elements requires a reload to take full effect.")
            end
        end,
        true,
        "Tooltip Skinning",
        "On",
        "Off"
    )
    row1:AddWidget(enableCheck, 0.5)
    card1:AddRow(row1, 40)

    -- Separator
    local row1sep = GUIFrame:CreateRow(card1.content, 8)
    local seprow1Card = GUIFrame:CreateSeparator(row1sep)
    row1sep:AddWidget(seprow1Card, 1)
    table_insert(allWidgets, seprow1Card)
    card1:AddRow(row1sep, 8)

    local textRow1Size = 140
    local row1b = GUIFrame:CreateRow(card1.content, textRow1Size)
    local ttInfoText = GUIFrame:CreateText(row1b,
        NRSKNUI:ColorTextByTheme("Important Tooltip Info"),
        (NRSKNUI:ColorTextByTheme("• ")) ..
        "As of 24/1-2026, Blizzard themselves have issues with tooltip errors. Tooltip skinning by this addon has protected checks so errors are most likely caused by blizzard.\n\n" ..
        (NRSKNUI:ColorTextByTheme("These are some common Blizzard errors\n")) ..
        (NRSKNUI:ColorTextByTheme("• ")) .. "Blizzard_SharedXML/Backdrop.lua" .. "\n" ..
        (NRSKNUI:ColorTextByTheme("• ")) .. "Blizzard_MoneyFrame/Mainline/MoneyFrame.lua" .. "\n" ..
        (NRSKNUI:ColorTextByTheme("• ")) .. "Blizzard_SharedXML/Tooltip/TooltipComparisonManager.lua",
        textRow1Size, "hide")
    row1b:AddWidget(ttInfoText, 1)
    table_insert(allWidgets, ttInfoText)
    card1:AddRow(row1b, textRow1Size)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Additional Options
    ----------------------------------------------------------------
    local card4 = GUIFrame:CreateCard(scrollChild, "General Settings", yOffset)
    table_insert(allWidgets, card4)

    local row6 = GUIFrame:CreateRow(card4.content, 34)
    local hideHealthCheck = GUIFrame:CreateCheckbox(row6, "Hide Health Bar", db.HideHealthBar ~= false,
        function(checked)
            db.HideHealthBar = checked
            ApplySettings()
            if not checked then
                NRSKNUI:CreateReloadPrompt("Enabling Blizzard UI elements requires a reload to take full effect.")
            end
        end)
    row6:AddWidget(hideHealthCheck, 1)
    table_insert(allWidgets, hideHealthCheck)
    card4:AddRow(row6, 34)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Background Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Background", yOffset)
    table_insert(allWidgets, card2)

    -- Background Color
    local row2 = GUIFrame:CreateRow(card2.content, 40)
    local bgColor = db.BackgroundColor or (NRSKNUI.Theme and NRSKNUI.Theme.bgDark) or { 0, 0, 0, 0.6 }
    local bgColorPicker = GUIFrame:CreateColorPicker(row2, "Background Color", bgColor, function(r, g, b, a)
        db.BackgroundColor = { r, g, b, a }
        ApplySettings()
    end)
    row2:AddWidget(bgColorPicker, 1)
    table_insert(allWidgets, bgColorPicker)
    card2:AddRow(row2, 40)

    -- Border Color
    local row4 = GUIFrame:CreateRow(card2.content, 34)
    local borderColor = db.BorderColor or { 0, 0, 0, 1 }
    local borderColorPicker = GUIFrame:CreateColorPicker(row4, "Border Color", borderColor, function(r, g, b, a)
        db.BorderColor = { r, g, b, a }
        ApplySettings()
    end)
    row4:AddWidget(borderColorPicker, 0.5)
    table_insert(allWidgets, borderColorPicker)

    -- Border Size
    local borderSlider = GUIFrame:CreateSlider(row4, "Border Size", 0, 4, 1, db.BorderSize or 1, 60,
        function(value)
            db.BorderSize = value
            ApplySettings()
        end)
    row4:AddWidget(borderSlider, 0.5)
    table_insert(allWidgets, borderSlider)
    card2:AddRow(row4, 34)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Font Settings
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Font Settings", yOffset)
    table_insert(allWidgets, card3)

    -- Font Face, Outline, Size Row
    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do fontList[name] = name end
    else
        fontList["Friz Quadrata TT"] = "Friz Quadrata TT"
    end

    -- Font Face and Outline Dropdowns
    local row3a = GUIFrame:CreateRow(card3.content, 40)
    local fontDropdown = GUIFrame:CreateDropdown(row3a, "Font", fontList, db.Font or "Friz Quadrata TT", 30,
        function(key)
            db.Font = key
            ApplySettings()
        end)
    row3a:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)

    -- Font Outline Dropdown
    local outlineList = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick" }
    local outlineDropdown = GUIFrame:CreateDropdown(row3a, "Outline", outlineList, db.FontOutline or "OUTLINE", 45,
        function(key)
            db.FontOutline = key
            ApplySettings()
        end)
    row3a:AddWidget(outlineDropdown, 0.5)
    table_insert(allWidgets, outlineDropdown)
    card3:AddRow(row3a, 40)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall
    ----------------------------------------------------------------
    -- Card 5: Font Size Settings
    ----------------------------------------------------------------
    local card5 = GUIFrame:CreateCard(scrollChild, "Font Size Settings", yOffset)
    table_insert(allWidgets, card5)

    -- Name Font Size Slider
    local row5a = GUIFrame:CreateRow(card5.content, 40)
    local fontSizeSlider = GUIFrame:CreateSlider(card5.content, "Title Font Size", 8, 72, 1, db.NameFontSize or 15, 60,
        function(val)
            db.NameFontSize = val
            ApplySettings()
        end)
    row5a:AddWidget(fontSizeSlider, 1)
    table_insert(allWidgets, fontSizeSlider)
    card5:AddRow(row5a, 40)

    -- Separator
    local row5asep = GUIFrame:CreateRow(card5.content, 8)
    local seprow5Card = GUIFrame:CreateSeparator(row5asep)
    row5asep:AddWidget(seprow5Card, 1)
    table_insert(allWidgets, seprow5Card)
    card5:AddRow(row5asep, 8)

    -- Guild Font Size Slider
    local row5b = GUIFrame:CreateRow(card5.content, 40)
    local guildFontSizeSlider = GUIFrame:CreateSlider(card5.content, "Guild Font Size", 8, 72, 1, db.GuildFontSize or 13,
        60,
        function(val)
            db.GuildFontSize = val
            ApplySettings()
        end)
    row5b:AddWidget(guildFontSizeSlider, 1)
    table_insert(allWidgets, guildFontSizeSlider)
    card5:AddRow(row5b, 40)

    -- Separator
    local row5bsep = GUIFrame:CreateRow(card5.content, 8)
    local seprow5bCard = GUIFrame:CreateSeparator(row5bsep)
    row5bsep:AddWidget(seprow5bCard, 1)
    table_insert(allWidgets, seprow5bCard)
    card5:AddRow(row5bsep, 8)

    -- Race & Level Font Size Slider
    local row5c = GUIFrame:CreateRow(card5.content, 40)
    local RaceLevelFontSizeSlider = GUIFrame:CreateSlider(card5.content, "Race & Level Font Size", 8, 72, 1,
        db.RaceLevelFontSize or 13,
        60,
        function(val)
            db.RaceLevelFontSize = val
            ApplySettings()
        end)
    row5c:AddWidget(RaceLevelFontSizeSlider, 1)
    table_insert(allWidgets, RaceLevelFontSizeSlider)
    card5:AddRow(row5c, 40)

    -- Separator
    local row5csep = GUIFrame:CreateRow(card5.content, 8)
    local seprow5cCard = GUIFrame:CreateSeparator(row5csep)
    row5csep:AddWidget(seprow5cCard, 1)
    table_insert(allWidgets, seprow5cCard)
    card5:AddRow(row5csep, 8)

    -- Spec Font Size Slider
    local row5d = GUIFrame:CreateRow(card5.content, 40)
    local SpecFontSizeSlider = GUIFrame:CreateSlider(card5.content, "Spec Font Size", 8, 72, 1,
        db.SpecFontSize or 13,
        60,
        function(val)
            db.SpecFontSize = val
            ApplySettings()
        end)
    row5d:AddWidget(SpecFontSizeSlider, 1)
    table_insert(allWidgets, SpecFontSizeSlider)
    card5:AddRow(row5d, 40)

    -- Separator
    local row5dsep = GUIFrame:CreateRow(card5.content, 8)
    local seprow5dCard = GUIFrame:CreateSeparator(row5dsep)
    row5dsep:AddWidget(seprow5dCard, 1)
    table_insert(allWidgets, seprow5dCard)
    card5:AddRow(row5dsep, 8)

    -- Font Size Slider
    local row5e = GUIFrame:CreateRow(card5.content, 40)
    local FactionFontSizeSlider = GUIFrame:CreateSlider(card5.content, "Faction Font Size", 8, 72, 1,
        db.FactionFontSize or 13,
        60,
        function(val)
            db.FactionFontSize = val
            ApplySettings()
        end)
    row5e:AddWidget(FactionFontSizeSlider, 1)
    table_insert(allWidgets, FactionFontSizeSlider)
    card5:AddRow(row5e, 40)

    yOffset = yOffset + card5:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 4)
    return yOffset
end)

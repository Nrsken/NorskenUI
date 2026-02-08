-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.LSM

-- Localization Setup
local table_insert = table.insert
local ipairs, pairs = ipairs, pairs

-- Helper to get XPBar module
local function GetXPBarModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("XPBar", true)
    end
    return nil
end

-- Register XPBar tab content
GUIFrame:RegisterContent("XPBar", function(scrollChild, yOffset)
    -- Safety check for database
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.XPBar
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get XPBar module
    local XPBar = GetXPBarModule()

    -- Apply XPBar settings
    local function ApplySettings()
        if XPBar then
            XPBar:ApplyStyling()
        end
    end

    -- Track widgets for enable/disable logic
    local allWidgets = {} -- All widgets (except main toggle)
    local customColorWidgets = {}

    -- Helper to apply new state
    local function ApplyXPBarState(enabled)
        if not XPBar then return end
        XPBar.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("XPBar")
        else
            NRSKNUI.Addon:DisableModule("XPBar")
        end
    end

    -- Comprehensive widget state update
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false
        local ccEnabled = db.ColorMode and db.ColorMode == "custom"

        -- First: Apply main enable state to ALL widgets
        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end

        if mainEnabled then
            for _, widget in ipairs(customColorWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(ccEnabled)
                end
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: XPBar Overview
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "XP Bar", yOffset)

    -- Enable Checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 40)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable XP Bar", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyXPBarState(checked)
            UpdateAllWidgetStates()
        end,
        true,
        "XP Bar",
        "On",
        "Off"
    )
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, 40)

    -- Separator
    local row1sep = GUIFrame:CreateRow(card1.content, 8)
    local sepCBCard = GUIFrame:CreateSeparator(row1sep)
    row1sep:AddWidget(sepCBCard, 1)
    table_insert(allWidgets, sepCBCard)
    card1:AddRow(row1sep, 8)

    -- Enable Checkbox
    local row1b = GUIFrame:CreateRow(card1.content, 36)
    local hideWhenMax = GUIFrame:CreateCheckbox(row1b, "Hide XP Bar When Max Level", db.hideWhenMax ~= false,
        function(checked)
            db.hideWhenMax = checked
            ApplySettings()
        end)
    row1b:AddWidget(hideWhenMax, 1)
    table_insert(allWidgets, hideWhenMax)
    card1:AddRow(row1b, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Font Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Font Settings", yOffset)
    table_insert(allWidgets, card2)

    -- Font lookup
    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do fontList[name] = name end
    else
        fontList["Friz Quadrata TT"] = "Friz Quadrata TT"
    end

    -- Font Face and Outline Dropdowns
    local row3a = GUIFrame:CreateRow(card2.content, 40)
    local fontDropdown = GUIFrame:CreateDropdown(row3a, "Font", fontList, db.FontFace or "Friz Quadrata TT", 30,
        function(key)
            db.FontFace = key
            ApplySettings()
        end)
    row3a:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)

    -- Font Size Slider
    local fontSizeSlider = GUIFrame:CreateSlider(card2.content, "Font Size", 8, 72, 1, db.FontSize or 24, 60,
        function(val)
            db.FontSize = val
            ApplySettings()
        end)
    row3a:AddWidget(fontSizeSlider, 0.5)
    table_insert(allWidgets, fontSizeSlider)
    card2:AddRow(row3a, 40)

    -- Font Outline Dropdown
    local row3b = GUIFrame:CreateRow(card2.content, 37)
    local outlineList = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick" }
    local outlineDropdown = GUIFrame:CreateDropdown(row3b, "Outline", outlineList, db.FontOutline or "OUTLINE", 45,
        function(key)
            db.FontOutline = key
            ApplySettings()
        end)
    row3b:AddWidget(outlineDropdown, 0.5)
    table_insert(allWidgets, outlineDropdown)

    local textColor = GUIFrame:CreateColorPicker(row3b, "Text color", db.TextColor,
        function(r, g, b, a)
            db.TextColor = { r, g, b, a }
            ApplySettings()
        end)
    row3b:AddWidget(textColor, 0.5)
    table_insert(allWidgets, textColor)
    card2:AddRow(row3b, 37)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Position Settings
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
        showStrata = true,
        onChangeCallback = ApplySettings,
    })

    if card3.positionWidgets then
        for _, widget in ipairs(card3.positionWidgets) do
            table_insert(allWidgets, widget)
        end
    end
    table_insert(allWidgets, card3)

    yOffset = newOffset

    ----------------------------------------------------------------
    -- Card 4: Size and coloring
    ----------------------------------------------------------------
    local card4 = GUIFrame:CreateCard(scrollChild, "Bar Size & Colors", yOffset)

    -- Bar Width
    local row4 = GUIFrame:CreateRow(card4.content, 40)
    local chatWidth = GUIFrame:CreateSlider(row4, "Bar Width", 1, 1000, 1,
        db.width, nil,
        function(val)
            db.width = val
            ApplySettings()
        end)
    row4:AddWidget(chatWidth, 0.5)
    table_insert(allWidgets, chatWidth)

    -- Bar Height
    local chatHeight = GUIFrame:CreateSlider(row4, "Bar Height", 1, 1000, 1,
        db.height, nil,
        function(val)
            db.height = val
            ApplySettings()
        end)
    row4:AddWidget(chatHeight, 0.5)
    table_insert(allWidgets, chatHeight)
    card4:AddRow(row4, 40)

    -- Statusbar Texture Dropdown
    local rowTexture = GUIFrame:CreateRow(card4.content, 40)
    local statusbarList = {}
    if LSM then
        for name in pairs(LSM:HashTable("statusbar")) do
            statusbarList[name] = name
        end
    else
        statusbarList["Blizzard"] = "Blizzard"
    end
    local statusbarDropdown = GUIFrame:CreateDropdown(rowTexture, "Bar Texture", statusbarList,
        db.StatusBarTexture or "Blizzard", 70,
        function(key)
            db.StatusBarTexture = key
            ApplySettings()
        end)
    rowTexture:AddWidget(statusbarDropdown, 1)
    table_insert(allWidgets, statusbarDropdown)
    card4:AddRow(rowTexture, 40)

    -- Separator
    local row4sep = GUIFrame:CreateRow(card4.content, 8)
    local seprow4Card = GUIFrame:CreateSeparator(row4sep)
    row4sep:AddWidget(seprow4Card, 1)
    table_insert(allWidgets, seprow4Card)
    card4:AddRow(row4sep, 8)

    -- Inactive Tab Color Mode
    local currentColorMode = db.ColorMode or "theme"
    local row5 = GUIFrame:CreateRow(card4.content, 40)
    local colorModeDropdown = GUIFrame:CreateDropdown(row5, "Foreground Color Mode",
        NRSKNUI.ColorModeOptions, currentColorMode, 70,
        function(key)
            db.ColorMode = key
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row5:AddWidget(colorModeDropdown, 0.5)
    table_insert(allWidgets, colorModeDropdown)

    -- Foreground Custom Color (only shown when mode is "custom")
    local foregroundColor = GUIFrame:CreateColorPicker(row5, "Foreground Custom Color",
        db.StatusColor,
        function(r, g, b, a)
            db.StatusColor = { r, g, b, a }
            ApplySettings()
        end)
    row5:AddWidget(foregroundColor, 0.5)
    table_insert(allWidgets, foregroundColor)
    table_insert(customColorWidgets, foregroundColor)
    card4:AddRow(row5, 40)

    -- Separator
    local row5sep = GUIFrame:CreateRow(card4.content, 8)
    local seprow5Card = GUIFrame:CreateSeparator(row5sep)
    row5sep:AddWidget(seprow5Card, 1)
    table_insert(allWidgets, seprow5Card)
    card4:AddRow(row5sep, 8)

    -- Rested Color
    local row5b = GUIFrame:CreateRow(card4.content, 39)
    local restedColor = GUIFrame:CreateColorPicker(row5b, "Rested XP Color", db.RestedColor or { 0, 0, 0, 0.8 },
        function(r, g, b, a)
            db.RestedColor = { r, g, b, a }
            ApplySettings()
        end)
    row5b:AddWidget(restedColor, 1)
    table_insert(allWidgets, restedColor)
    card4:AddRow(row5b, 39)

    -- Separator
    local row6sep = GUIFrame:CreateRow(card4.content, 8)
    local seprow6Card = GUIFrame:CreateSeparator(row6sep)
    row6sep:AddWidget(seprow6Card, 1)
    table_insert(allWidgets, seprow6Card)
    card4:AddRow(row6sep, 8)

    -- Backdrop Color
    local row6 = GUIFrame:CreateRow(card4.content, 39)
    local backdropColor = GUIFrame:CreateColorPicker(row6, "Backdrop Color", db.BackdropColor or { 0, 0, 0, 0.8 },
        function(r, g, b, a)
            db.BackdropColor = { r, g, b, a }
            ApplySettings()
        end)
    row6:AddWidget(backdropColor, 0.5)
    table_insert(allWidgets, backdropColor)

    -- Border Color
    local borderColor = GUIFrame:CreateColorPicker(row6, "Backdrop Border Color",
        db.BackdropBorderColor or { 0, 0, 0, 1 },
        function(r, g, b, a)
            db.BackdropBorderColor = { r, g, b, a }
            ApplySettings()
        end)
    row6:AddWidget(borderColor, 0.5)
    table_insert(allWidgets, borderColor)
    card4:AddRow(row6, 39)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall)
    return yOffset
end)

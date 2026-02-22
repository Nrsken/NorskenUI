-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.LSM

-- Localization
local table_insert = table.insert
local pairs, ipairs = pairs, ipairs

-- Get module reference
local function GetModule()
    return NorskenUI:GetModule("RangeChecker", true)
end

-- Register Pet Texts tab content
GUIFrame:RegisterContent("RangeChecker", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.RangeChecker
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    local RANGE = GetModule()
    local allWidgets = {}

    local function ApplySettings()
        if RANGE and RANGE.ApplySettings then
            RANGE:ApplySettings()
        end
    end

    local function ApplyModuleState(enabled)
        if not RANGE then return end
        db.Enabled = enabled
        if enabled then
            NorskenUI:EnableModule("RangeChecker")
        else
            NorskenUI:DisableModule("RangeChecker")
        end
    end

    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false

        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: Range Checker Text
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Range Checker Text", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Range Checker Text", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyModuleState(checked)
            UpdateAllWidgetStates()
        end,
        true, "Range Checker Text", "On", "Off"
    )
    row1:AddWidget(enableCheck, 0.5)
    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 1b: General Settings
    ----------------------------------------------------------------
    local card1b = GUIFrame:CreateCard(scrollChild, "General Settings", yOffset)
    table_insert(allWidgets, card1b)

    local row1a = GUIFrame:CreateRow(card1b.content, 40)
    local CombatOnly = GUIFrame:CreateCheckbox(row1a, "Show In Combat Only", db.CombatOnly ~= false,
        function(checked)
            db.CombatOnly = checked
            ApplySettings()
        end)
    row1a:AddWidget(CombatOnly, 0.5)
    card1b:AddRow(row1a, 40)

    -- Separator
    local row1sep = GUIFrame:CreateRow(card1b.content, 8)
    local sepCBCard = GUIFrame:CreateSeparator(row1sep)
    row1sep:AddWidget(sepCBCard, 1)
    table_insert(allWidgets, sepCBCard)
    card1b:AddRow(row1sep, 8)

    -- Update Throttle
    local row1b = GUIFrame:CreateRow(card1b.content, 36)
    local UpdateThrottle = GUIFrame:CreateSlider(row1b, "Update Throttle", 0, 1, 0.05,
        db.UpdateThrottle, nil,
        function(val)
            db.UpdateThrottle = val
            ApplySettings()
        end)
    row1b:AddWidget(UpdateThrottle, 1)
    table_insert(allWidgets, UpdateThrottle)
    card1b:AddRow(row1b, 36)

    yOffset = yOffset + card1b:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Color Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Color Settings", yOffset)
    table_insert(allWidgets, card2)

    -- 40+ Yards Color
    local row2a = GUIFrame:CreateRow(card2.content, 38)
    local ColorOneColorPicker = GUIFrame:CreateColorPicker(row2a, "40+ Yards Color",
        db.ColorOne or { 1, 0.82, 0, 1 },
        function(r, g, b, a)
            db.ColorOne = { r, g, b, a }
            ApplySettings()
        end)
    row2a:AddWidget(ColorOneColorPicker, 0.5)
    table_insert(allWidgets, ColorOneColorPicker)
    card2:AddRow(row2a, 38)

    -- 20-40 Yards Color
    local row2b = GUIFrame:CreateRow(card2.content, 38)
    local ColorTwoColorPicker = GUIFrame:CreateColorPicker(row2b, "20-40 Yards Color",
        db.ColorTwo or { 1, 0.2, 0.2, 1 },
        function(r, g, b, a)
            db.ColorTwo = { r, g, b, a }
            ApplySettings()
        end)
    row2b:AddWidget(ColorTwoColorPicker, 0.5)
    table_insert(allWidgets, ColorTwoColorPicker)
    card2:AddRow(row2b, 38)

    -- 10-20 Yards Color
    local row2c = GUIFrame:CreateRow(card2.content, 38)
    local ColorThreeColorPicker = GUIFrame:CreateColorPicker(row2c, "10-20 Yards Color",
        db.ColorThree or { 0.3, 0.7, 1, 1 },
        function(r, g, b, a)
            db.ColorThree = { r, g, b, a }
            ApplySettings()
        end)
    row2c:AddWidget(ColorThreeColorPicker, 0.5)
    table_insert(allWidgets, ColorThreeColorPicker)
    card2:AddRow(row2c, 38)

    -- 0-10 Yards Color
    local row2d = GUIFrame:CreateRow(card2.content, 38)
    local ColorFourColorPicker = GUIFrame:CreateColorPicker(row2d, "0-10 Yards Color",
        db.ColorFour or { 0.3, 0.7, 1, 1 },
        function(r, g, b, a)
            db.ColorFour = { r, g, b, a }
            ApplySettings()
        end)
    row2d:AddWidget(ColorFourColorPicker, 0.5)
    table_insert(allWidgets, ColorFourColorPicker)
    card2:AddRow(row2d, 38)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Font Settings
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Font Settings", yOffset)
    table_insert(allWidgets, card3)

    -- Font lookup
    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do fontList[name] = name end
    else
        fontList["Friz Quadrata TT"] = "Friz Quadrata TT"
    end

    -- Font Face and Outline Dropdowns
    local row3a = GUIFrame:CreateRow(card3.content, 40)
    local fontDropdown = GUIFrame:CreateDropdown(row3a, "Font", fontList, db.FontFace or "Friz Quadrata TT", 30,
        function(key)
            db.FontFace = key
            ApplySettings()
        end)
    row3a:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)

    -- Font Size Slider
    local fontSizeSlider = GUIFrame:CreateSlider(card3.content, "Font Size", 8, 72, 1, db.FontSize or 24, 60,
        function(val)
            db.FontSize = val
            ApplySettings()
        end)
    row3a:AddWidget(fontSizeSlider, 0.5)
    table_insert(allWidgets, fontSizeSlider)
    card3:AddRow(row3a, 40)

    -- Font Outline Dropdown
    local row3b = GUIFrame:CreateRow(card3.content, 37)
    local outlineList = {
        { key = "NONE",         text = "None" },
        { key = "OUTLINE",      text = "Outline" },
        { key = "THICKOUTLINE", text = "Thick" },
        { key = "SOFTOUTLINE",  text = "Soft" },
    }
    local outlineDropdown = GUIFrame:CreateDropdown(row3b, "Outline", outlineList, db.FontOutline or "OUTLINE", 45,
        function(key)
            db.FontOutline = key
            ApplySettings()
        end)
    row3b:AddWidget(outlineDropdown, 1)
    table_insert(allWidgets, outlineDropdown)

    card3:AddRow(row3b, 37)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Position Settings
    ----------------------------------------------------------------
    local card4, newOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
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
        onChangeCallback = ApplySettings,
    })

    if card4.positionWidgets then
        for _, widget in ipairs(card4.positionWidgets) do
            table_insert(allWidgets, widget)
        end
    end
    table_insert(allWidgets, card4)

    yOffset = newOffset

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 2)
    return yOffset
end)

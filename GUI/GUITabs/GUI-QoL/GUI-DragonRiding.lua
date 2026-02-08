-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local table_insert = table.insert
local ipairs = ipairs

-- Helper to get DragonRiding module
local function GetDragonRidingModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("DragonRiding", true)
    end
    return nil
end

-- Helper to get CDM module
local function GetCDMModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("CDM", true)
    end
    return nil
end

-- Dragon Riding Tab Content
GUIFrame:RegisterContent("DragonRiding", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.DragonRiding
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get modules
    local DR = GetDragonRidingModule()
    local CDM = GetCDMModule()

    -- Track widgets that depend on the toggle
    local alphaWidgets = {}
    local cdmDB = NRSKNUI.db and NRSKNUI.db.profile.Skinning.CDM
    local allWidgets = {}

    -- Live update CDM settings
    local function applyCDMSettings()
        if CDM and CDM.UpdateMountPetAlphaValue then
            CDM:UpdateMountPetAlphaValue()
        end
    end

    -- Helper to apply settings and update preview
    local function ApplySettings()
        if DR and DR.ApplySettings then
            DR:ApplySettings()
        end
    end

    -- Helper to apply new state
    local function ApplyDragonRidingState(enabled)
        if not DR then return end
        DR.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("DragonRiding")
        else
            NRSKNUI.Addon:DisableModule("DragonRiding")
        end
    end

    -- Comprehensive widget state update
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false
        local alphaEnabled = cdmDB and cdmDB.AlphaoutMountPet ~= false

        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end

        if mainEnabled then
            for _, widget in ipairs(alphaWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(alphaEnabled)
                end
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: DragonRiding Enable/Disable
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Skyriding UI", yOffset)

    -- Enable Checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Skyriding UI", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyDragonRidingState(checked)
            UpdateAllWidgetStates()
        end,
        true,
        "Skyriding UI",
        "On",
        "Off"
    )
    row1:AddWidget(enableCheck, 0.5)
    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Size Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Size Settings", yOffset)
    table_insert(allWidgets, card2)

    -- Width Slider
    local row2 = GUIFrame:CreateRow(card2.content, 40)
    local widthSlider = GUIFrame:CreateSlider(row2, "Width", 100, 500, 1,
        db.Width or 252, nil,
        function(val)
            db.Width = val
            ApplySettings()
        end)
    row2:AddWidget(widthSlider, 1)
    table_insert(allWidgets, widthSlider)
    card2:AddRow(row2, 40)

    -- Bar Height Slider
    local row3 = GUIFrame:CreateRow(card2.content, 40)
    local heightSlider = GUIFrame:CreateSlider(row3, "Bar Height", 6, 24, 1,
        db.BarHeight or 12, nil,
        function(val)
            db.BarHeight = val
            ApplySettings()
        end)
    row3:AddWidget(heightSlider, 1)
    table_insert(allWidgets, heightSlider)
    card2:AddRow(row3, 40)

    -- Spacing Slider
    local row3b = GUIFrame:CreateRow(card2.content, 40)
    local spacingSlider = GUIFrame:CreateSlider(row3b, "Row Spacing", 0, 10, 1,
        db.Spacing or 1, nil,
        function(val)
            db.Spacing = val
            ApplySettings()
        end)
    row3b:AddWidget(spacingSlider, 1)
    table_insert(allWidgets, spacingSlider)
    card2:AddRow(row3b, 40)

    -- Speed Font Size
    local row4 = GUIFrame:CreateRow(card2.content, 40)
    local speedFontSlider = GUIFrame:CreateSlider(row4, "Speed Font Size", 8, 24, 1,
        db.SpeedFontSize or 14, nil,
        function(val)
            db.SpeedFontSize = val
            ApplySettings()
        end)
    row4:AddWidget(speedFontSlider, 1)
    table_insert(allWidgets, speedFontSlider)
    card2:AddRow(row4, 40)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Color Settings
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Colors", yOffset)
    table_insert(allWidgets, card3)

    -- Ensure Colors table exists
    db.Colors = db.Colors or {}

    -- Vigor Color
    local row5 = GUIFrame:CreateRow(card3.content, 36)
    local vigorColor = db.Colors.Vigor or { 0.898, 0.063, 0.224, 1 }
    local vigorPicker = GUIFrame:CreateColorPicker(row5, "Vigor", vigorColor,
        function(r, g, b, a)
            db.Colors.Vigor = { r, g, b, a }
            ApplySettings()
        end)
    row5:AddWidget(vigorPicker, 0.5)
    table_insert(allWidgets, vigorPicker)
    card3:AddRow(row5, 36)

    -- Vigor Thrill Color
    local row6 = GUIFrame:CreateRow(card3.content, 36)
    local thrillColor = db.Colors.VigorThrill or { 0.2, 0.8, 0.2, 1 }
    local thrillPicker = GUIFrame:CreateColorPicker(row6, "Vigor (Thrill)", thrillColor,
        function(r, g, b, a)
            db.Colors.VigorThrill = { r, g, b, a }
            ApplySettings()
        end)
    row6:AddWidget(thrillPicker, 0.5)
    table_insert(allWidgets, thrillPicker)
    card3:AddRow(row6, 36)

    -- Whirling Surge Color
    local row7 = GUIFrame:CreateRow(card3.content, 36)
    local surgeColor = db.Colors.WhirlingSurge or { 0.6, 0.4, 0.9, 1 }
    local surgePicker = GUIFrame:CreateColorPicker(row7, "Whirling Surge", surgeColor,
        function(r, g, b, a)
            db.Colors.WhirlingSurge = { r, g, b, a }
            ApplySettings()
        end)
    row7:AddWidget(surgePicker, 0.5)
    table_insert(allWidgets, surgePicker)
    card3:AddRow(row7, 36)

    -- Second Wind Color
    local row8 = GUIFrame:CreateRow(card3.content, 36)
    local swColor = db.Colors.SecondWind or { 0.3, 0.7, 1, 1 }
    local swPicker = GUIFrame:CreateColorPicker(row8, "Second Wind", swColor,
        function(r, g, b, a)
            db.Colors.SecondWind = { r, g, b, a }
            ApplySettings()
        end)
    row8:AddWidget(swPicker, 0.5)
    table_insert(allWidgets, swPicker)
    card3:AddRow(row8, 36)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Mount/Pet Alpha Settings
    ----------------------------------------------------------------
    if cdmDB then
        local card4 = GUIFrame:CreateCard(scrollChild, "Mount & Pet Battle Alpha", yOffset)
        table_insert(allWidgets, card4)

        -- Enable Alpha Out Toggle
        local row9 = GUIFrame:CreateRow(card4.content, 36)
        local alphaOutCheck = GUIFrame:CreateCheckbox(row9, "Reduce Alpha While Mounted/Pet Battle",
            cdmDB.AlphaoutMountPet ~= false,
            function(checked)
                cdmDB.AlphaoutMountPet = checked
                if CDM and CDM.UpdateMountPetAlpha then
                    CDM:UpdateMountPetAlpha()
                end
                UpdateAllWidgetStates()
            end)
        row9:AddWidget(alphaOutCheck, 1)
        table_insert(allWidgets, alphaOutCheck)
        card4:AddRow(row9, 36)

        -- Separator
        local row9sep = GUIFrame:CreateRow(card4.content, 8)
        local seprow9Card = GUIFrame:CreateSeparator(row9sep)
        row9sep:AddWidget(seprow9Card, 1)
        table_insert(allWidgets, seprow9Card)
        card4:AddRow(row9sep, 8)

        -- Alpha Slider
        local row10 = GUIFrame:CreateRow(card4.content, 40)
        local alphaSlider = GUIFrame:CreateSlider(row10, "Reduced Alpha", 0, 1, 0.05,
            cdmDB.AlphaMountPet or 0.5, nil,
            function(val)
                cdmDB.AlphaMountPet = val
                applyCDMSettings()
            end)
        row10:AddWidget(alphaSlider, 1)
        table_insert(allWidgets, alphaSlider)
        table_insert(alphaWidgets, alphaSlider)
        card4:AddRow(row10, 40)

        yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall
    end

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - Theme.paddingSmall
    return yOffset
end)

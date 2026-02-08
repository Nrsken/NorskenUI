-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization
local table_insert = table.insert

-- Get module reference
local function GetModule()
    return NRSKNUI.Addon:GetModule("CombatCross", true)
end

-- Register Combat Cross tab content
GUIFrame:RegisterContent("combatCross", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.CombatCross
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    local allWidgets = {}
    local colorModeWidgets = {}

    local function ApplySettings()
        local mod = GetModule()
        if mod and mod.ApplySettings then
            mod:ApplySettings()
        end
    end

    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false
        local isCustomColor = (db.ColorMode or "custom") == "custom"

        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end

        if mainEnabled then
            for _, widget in ipairs(colorModeWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(isCustomColor)
                end
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: Combat Cross (Enable + Preview)
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Combat Cross", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Combat Cross", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end,
        true, "Combat Cross", "On", "Off"
    )
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, 36)
    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Position Settings
    ----------------------------------------------------------------
    local card2, newOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
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
        defaults = {
            anchorFrameType = "UIPARENT",
            anchorFrameFrame = "UIParent",
            selfPoint = "CENTER",
            anchorPoint = "CENTER",
            xOffset = 0,
            yOffset = -10,
            strata = "HIGH",
        },
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })

    if card2.positionWidgets then
        for _, widget in ipairs(card2.positionWidgets) do
            table_insert(allWidgets, widget)
        end
    end
    table_insert(allWidgets, card2)
    yOffset = newOffset

    ----------------------------------------------------------------
    -- Card 3: Cross Size Settings
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Cross Size", yOffset)
    table_insert(allWidgets, card3)

    local row3b = GUIFrame:CreateRow(card3.content, 36)
    local outlineCheck = GUIFrame:CreateCheckbox(row3b, "Font Outline", db.Outline ~= false,
        function(checked)
            db.Outline = checked
            ApplySettings()
        end)
    row3b:AddWidget(outlineCheck, 0.5)
    table_insert(allWidgets, outlineCheck)

    local sizeSlider = GUIFrame:CreateSlider(row3b, "Size", 8, 72, 1, db.Thickness or 22, 60,
        function(val)
            db.Thickness = val
            ApplySettings()
        end)
    row3b:AddWidget(sizeSlider, 0.5)
    table_insert(allWidgets, sizeSlider)
    card3:AddRow(row3b, 36)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Color Settings
    ----------------------------------------------------------------
    local card4 = GUIFrame:CreateCard(scrollChild, "Color", yOffset)
    table_insert(allWidgets, card4)

    local currentColorMode = db.ColorMode or "custom"

    local row4 = GUIFrame:CreateRow(card4.content, 36)
    local colorModeDropdown = GUIFrame:CreateDropdown(row4, "Color Mode", NRSKNUI.ColorModeOptions, currentColorMode, 70,
        function(key)
            db.ColorMode = key
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row4:AddWidget(colorModeDropdown, 0.5)
    table_insert(allWidgets, colorModeDropdown)

    local colorPicker = GUIFrame:CreateColorPicker(row4, "Custom Color", db.Color or { 0, 1, 0.169, 1 },
        function(r, g, b, a)
            db.Color = { r, g, b, a }
            ApplySettings()
        end)
    row4:AddWidget(colorPicker, 0.5)
    table_insert(allWidgets, colorPicker)
    table_insert(colorModeWidgets, colorPicker)
    card4:AddRow(row4, 36)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 3)
    return yOffset
end)

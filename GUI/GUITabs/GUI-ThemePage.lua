local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local table_insert = table.insert
local pairs = pairs
local ipairs = ipairs
local CreateFrame= CreateFrame
local UnitClass = UnitClass

-- Register ThemePage content
GUIFrame:RegisterContent("ThemePage", function(scrollChild, yOffset)
    -- Track widgets for enable/disable logic
    local presetWidgets = {}
    local customColorWidgets = {}

    -- Helper to refresh theme and GUI
    local function ApplyTheme()
        NRSKNUI:RefreshTheme()
        -- Refresh the content to update color pickers with new values
        C_Timer.After(0.05, function()
            if GUIFrame.mainFrame and GUIFrame.mainFrame:IsShown() then
                GUIFrame:RefreshContent()
            end
        end)
    end

    -- Get current theme settings
    local currentMode = NRSKNUI:GetThemeMode() or "preset"
    local currentPreset = NRSKNUI:GetThemePreset() or "Echo"

    ----------------------------------------------------------------
    -- Card 1: Theme Mode Selection
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Theme Mode", yOffset)

    -- Theme mode dropdown
    local row1 = GUIFrame:CreateRow(card1.content, 40)
    local modeDropdown = GUIFrame:CreateDropdown(row1, "Theme Mode", NRSKNUI.ThemeModeOptions, currentMode, 100,
        function(key)
            NRSKNUI:SetThemeMode(key)
            ApplyTheme()
        end)
    row1:AddWidget(modeDropdown, 1)
    card1:AddRow(row1, 40)

    -- Description based on mode
    local modeDescriptions = {
        preset = "Use one of the pre-made color themes.",
        class = "Accent colors will match your character's class color.",
        custom = "Fully customize every color in the theme.",
    }
    local descLabel = card1:AddLabel(modeDescriptions[currentMode] or "")
    descLabel:SetTextColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Preset Theme Selection (only shown in preset mode)
    ----------------------------------------------------------------
    if currentMode == "preset" then
        local card2 = GUIFrame:CreateCard(scrollChild, "Select Preset Theme", yOffset)

        -- Build preset options from ordered list
        local presetOptions = {}
        for _, name in ipairs(NRSKNUI.ThemePresetNames) do
            presetOptions[name] = name
        end

        local row2 = GUIFrame:CreateRow(card2.content, 40)
        local presetDropdown = GUIFrame:CreateDropdown(row2, "Theme", presetOptions, currentPreset, 100,
            function(key)
                NRSKNUI:SetThemePreset(key)
                ApplyTheme()
            end)
        row2:AddWidget(presetDropdown, 1)
        card2:AddRow(row2, 40)

        -- Theme preview colors
        card2:AddSpacing(Theme.paddingSmall)
        local previewLabel = card2:AddLabel("Theme Preview:")
        previewLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)

        -- Create color preview swatches
        local previewRow = GUIFrame:CreateRow(card2.content, 24)
        local previewContainer = CreateFrame("Frame", nil, previewRow)
        previewContainer:SetHeight(24)

        local preset = NRSKNUI.ThemePresets[currentPreset]
        if preset then
            local colorKeys = { "bgDark", "bgMedium", "bgLight", "accent", "selectedBg" }
            local swatchSize = 24
            local spacing = 4

            for i, key in ipairs(colorKeys) do
                local color = preset[key]
                if color then
                    local swatch = previewContainer:CreateTexture(nil, "ARTWORK")
                    swatch:SetSize(swatchSize, swatchSize)
                    swatch:SetPoint("LEFT", previewContainer, "LEFT", (i - 1) * (swatchSize + spacing), 0)
                    swatch:SetColorTexture(color[1], color[2], color[3], color[4] or 1)

                    -- Border
                    local border = CreateFrame("Frame", nil, previewContainer, "BackdropTemplate")
                    border:SetPoint("TOPLEFT", swatch, "TOPLEFT", -1, 1)
                    border:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", 1, -1)
                    border:SetBackdrop({
                        edgeFile = "Interface\\Buttons\\WHITE8X8",
                        edgeSize = 1,
                    })
                    border:SetBackdropBorderColor(0, 0, 0, 1)
                end
            end
        end

        previewRow:AddWidget(previewContainer, 1)
        card2:AddRow(previewRow, 24)

        yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall
    end

    ----------------------------------------------------------------
    -- Card 3: Class Color Info (only shown in class mode)
    ----------------------------------------------------------------
    if currentMode == "class" then
        local card3 = GUIFrame:CreateCard(scrollChild, "Class Color Mode", yOffset)

        -- Show current class color
        local _, class = UnitClass("player")
        local className = class or "Unknown"
        local classColor = RAID_CLASS_COLORS[class]

        --local infoLabel = card3:AddLabel("Your class: " .. className)

        if classColor then
            local colorRow = GUIFrame:CreateRow(card3.content, 24)
            local colorContainer = CreateFrame("Frame", nil, colorRow)
            colorContainer:SetHeight(24)

            -- Class color swatch
            local swatch = colorContainer:CreateTexture(nil, "ARTWORK")
            swatch:SetSize(24, 24)
            swatch:SetPoint("LEFT", colorContainer, "LEFT", 0, 0)
            swatch:SetColorTexture(classColor.r, classColor.g, classColor.b, 1)

            -- Border
            local border = CreateFrame("Frame", nil, colorContainer, "BackdropTemplate")
            border:SetPoint("TOPLEFT", swatch, "TOPLEFT", -1, 1)
            border:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", 1, -1)
            border:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            border:SetBackdropBorderColor(0, 0, 0, 1)

            -- Label
            local colorLabel = colorContainer:CreateFontString(nil, "OVERLAY")
            colorLabel:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
            NRSKNUI:ApplyThemeFont(colorLabel, "normal")
            colorLabel:SetText("Current class color will be used for accents and selections")
            colorLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)

            colorRow:AddWidget(colorContainer, 1)
            card3:AddRow(colorRow, 24)
        end

        card3:AddSpacing(Theme.paddingSmall)
        local noteLabel = card3:AddLabel("Background colors will use the Dark theme.")
        noteLabel:SetTextColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)

        yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall
    end

    ----------------------------------------------------------------
    -- Card 4: Custom Colors (only shown in custom mode)
    ----------------------------------------------------------------
    if currentMode == "custom" then
        -- Group colors by category
        local categories = {}
        local categoryOrder = { "Backgrounds", "Borders", "Accent Colors", "Text Colors", "Selection Colors",
            "Status Colors" }

        for _, colorDef in ipairs(NRSKNUI.ThemeColorKeys) do
            local cat = colorDef.category or "Other"
            categories[cat] = categories[cat] or {}
            table_insert(categories[cat], colorDef)
        end

        -- Create a card for each category
        for _, catName in ipairs(categoryOrder) do
            local colorDefs = categories[catName]
            if colorDefs then
                local catCard = GUIFrame:CreateCard(scrollChild, catName, yOffset)

                for _, colorDef in ipairs(colorDefs) do
                    local customColor = NRSKNUI:GetCustomColor(colorDef.key)

                    local colorRow = GUIFrame:CreateRow(catCard.content, 39)
                    local colorPicker = GUIFrame:CreateColorPicker(colorRow, colorDef.name, customColor,
                        function(r, g, b, a)
                            NRSKNUI:SetCustomColor(colorDef.key, r, g, b, a)
                        end)
                    colorRow:AddWidget(colorPicker, 1)
                    table_insert(customColorWidgets, colorPicker)
                    catCard:AddRow(colorRow, 39)
                end

                yOffset = yOffset + catCard:GetContentHeight() + Theme.paddingSmall
            end
        end

        -- Copy from preset button
        local copyCard = GUIFrame:CreateCard(scrollChild, "Quick Setup", yOffset)

        local copyLabel = copyCard:AddLabel("Copy colors from a preset theme as a starting point:")
        copyLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)

        -- Build preset options
        local presetOptions = {}
        for _, name in ipairs(NRSKNUI.ThemePresetNames) do
            presetOptions[name] = name
        end

        local copyRow = GUIFrame:CreateRow(copyCard.content, 40)
        local copyDropdown = GUIFrame:CreateDropdown(copyRow, "Copy From", presetOptions, "", 100,
            function(key)
                NRSKNUI:CopyPresetToCustom(key)
                ApplyTheme()
            end)
        copyRow:AddWidget(copyDropdown, 0.5)

        -- Reset button
        local resetBtn = GUIFrame:CreateButton(copyRow, "Reset Custom", {
            width = 110,
            height = 24,
            callback = function()
                NRSKNUI:ResetCustomColors()
                ApplyTheme()
            end
        })
        copyRow:AddWidget(resetBtn, 0.5, nil, 0, -14)

        copyCard:AddRow(copyRow, 40)

        yOffset = yOffset + copyCard:GetContentHeight() + Theme.paddingSmall
    end

    ----------------------------------------------------------------
    -- Card: Reset Theme
    ----------------------------------------------------------------
    local resetCard = GUIFrame:CreateCard(scrollChild, "Reset", yOffset)

    local resetRow = GUIFrame:CreateRow(resetCard.content, 36)
    local resetAllBtn = GUIFrame:CreateButton(resetRow, "Reset All Theme Settings", {
        callback = function()
            NRSKNUI:ResetTheme()
            ApplyTheme()
        end
    })
    resetRow:AddWidget(resetAllBtn, 1)
    resetCard:AddRow(resetRow, 36)

    local resetNote = resetCard:AddLabel("This will reset theme mode to 'Preset' with the Echo theme.")
    resetNote:SetTextColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)

    yOffset = yOffset + resetCard:GetContentHeight() + Theme.paddingSmall

    yOffset = yOffset - (Theme.paddingSmall * 2)
    return yOffset
end)

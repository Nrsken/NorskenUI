-- NRSKNUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

--TODO: Update

-- Localization Setup
local pairs, ipairs = pairs, ipairs
local table_insert = table.insert
local table_sort = table.sort

-- Helper to get UIWidgets module
local function GetUIWidgetsModule()
    if NRSKNUI then
        return NRSKNUI:GetModule("UIWidgets", true)
    end
    return nil
end

-- Register Content
GUIFrame:RegisterContent("UIWidgets", function(scrollChild, yOffset)
    if NRSKNUI:ShouldNotLoadModule() then return end
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.UIWidgets
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get UIWidgets module
    local UIW = GetUIWidgetsModule()

    -- Track widgets for enable/disable logic
    local allWidgets = {}
    local statusBarWidgets = {}
    local textWidgets = {}

    -- Apply settings through module
    local function ApplySettings()
        if UIW and UIW:IsEnabled() then
            UIW:ApplySettings()
        end
    end

    -- Comprehensive widget state update
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false
        local statusBarEnabled = db.StatusBar and db.StatusBar.Enabled ~= false
        local textEnabled = db.TextWidget and db.TextWidget.Enabled ~= false

        -- Apply main enable state to ALL widgets
        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end

        -- Apply conditional states (only if main is enabled)
        if mainEnabled then
            for _, widget in ipairs(statusBarWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(statusBarEnabled)
                end
            end
            for _, widget in ipairs(textWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(textEnabled)
                end
            end
        end
    end

    local OUTLINE_OPTIONS = {
        { key = "NONE",         text = "None" },
        { key = "OUTLINE",      text = "Outline" },
        { key = "THICKOUTLINE", text = "Thick" },
        { key = "SLUG",         text = "Slug" },
        { key = "SLUG,OUTLINE", text = "Slug Outline" },
    }

    -- Build font list
    local function GetFontList()
        local fontList = {}
        if LSM then
            for name in pairs(LSM:HashTable("font")) do
                table_insert(fontList, { key = name, text = name })
            end
            table_sort(fontList, function(a, b) return a.text < b.text end)
        else
            table_insert(fontList, { key = "Friz Quadrata TT", text = "Friz Quadrata TT" })
        end
        return fontList
    end
    local fontList = GetFontList()

    ----------------------------------------------------------------
    -- Card 1: Master Toggle
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "UI Widgets", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable UI Widget Skinning", {
        value = db.Enabled ~= false,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule("UIWidgets")
                ApplySettings()
            else
                NRSKNUI:DisableModule("UIWidgets")
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = "UI Widget Skinning",
        msgOn = "On",
        msgOff = "Off",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Global Font Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Font Settings", yOffset)
    table_insert(allWidgets, card2)

    -- Font Dropdown
    local row2a = GUIFrame:CreateRow(card2.content, 36)
    local fontDropdown = GUIFrame:CreateDropdown(row2a, "Font", {
        options = fontList,
        value = db.FontFace or "Expressway",
        callback = function(key)
            db.FontFace = key
            ApplySettings()
        end,
        searchable = true,
        isFontPreview = true
    })
    row2a:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)

    -- Outline Dropdown
    local outlineDropdown = GUIFrame:CreateDropdown(row2a, "Outline", {
        options = OUTLINE_OPTIONS,
        value = db.FontOutline or "OUTLINE",
        callback = function(key)
            db.FontOutline = key
            ApplySettings()
        end
    })
    row2a:AddWidget(outlineDropdown, 0.5)
    table_insert(allWidgets, outlineDropdown)
    card2:AddRow(row2a, 36)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Status Bar Widgets
    ----------------------------------------------------------------
    local barDB = db.StatusBar
    local card3 = GUIFrame:CreateCard(scrollChild, "Status Bar Widgets", yOffset)
    table_insert(allWidgets, card3)

    -- Enable toggle
    local row3a = GUIFrame:CreateRow(card3.content, 36)
    local enableBarCheck = GUIFrame:CreateCheckbox(row3a, "Enable Status Bar Styling", {
        value = barDB.Enabled ~= false,
        callback = function(checked)
            barDB.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end,
    })
    row3a:AddWidget(enableBarCheck, 0.5)
    table_insert(allWidgets, enableBarCheck)

    -- Width slider (0 = default/auto)
    local barWidthSlider = GUIFrame:CreateSlider(row3a, "Width (0=Auto)", {
        min = 0,
        max = 400,
        step = 1,
        value = barDB.Width or 0,
        labelWidth = 80,
        callback = function(val)
            barDB.Width = val
            ApplySettings()
        end
    })
    row3a:AddWidget(barWidthSlider, 0.5)
    table_insert(allWidgets, barWidthSlider)
    table_insert(statusBarWidgets, barWidthSlider)
    card3:AddRow(row3a, 36)

    -- Style Label toggle
    local row3b = GUIFrame:CreateRow(card3.content, 36)
    local styleLabelCheck = GUIFrame:CreateCheckbox(row3b, "Style Label Text", {
        value = barDB.StyleLabel ~= false,
        callback = function(checked)
            barDB.StyleLabel = checked
            ApplySettings()
        end,
    })
    row3b:AddWidget(styleLabelCheck, 0.5)
    table_insert(allWidgets, styleLabelCheck)
    table_insert(statusBarWidgets, styleLabelCheck)

    -- Style Bar Text toggle
    local styleBarTextCheck = GUIFrame:CreateCheckbox(row3b, "Style Bar Text", {
        value = barDB.StyleBarText ~= false,
        callback = function(checked)
            barDB.StyleBarText = checked
            ApplySettings()
        end,
    })
    row3b:AddWidget(styleBarTextCheck, 0.5)
    table_insert(allWidgets, styleBarTextCheck)
    table_insert(statusBarWidgets, styleBarTextCheck)
    card3:AddRow(row3b, 36)

    -- Font Size Sliders
    local row3c = GUIFrame:CreateRow(card3.content, 40)
    local labelSizeSlider = GUIFrame:CreateSlider(row3c, "Label Size", {
        min = 8,
        max = 24,
        step = 1,
        value = barDB.LabelSize or 14,
        labelWidth = 60,
        callback = function(val)
            barDB.LabelSize = val
            ApplySettings()
        end
    })
    row3c:AddWidget(labelSizeSlider, 0.5)
    table_insert(allWidgets, labelSizeSlider)
    table_insert(statusBarWidgets, labelSizeSlider)

    local barTextSizeSlider = GUIFrame:CreateSlider(row3c, "Bar Text Size", {
        min = 8,
        max = 24,
        step = 1,
        value = barDB.BarTextSize or 12,
        labelWidth = 70,
        callback = function(val)
            barDB.BarTextSize = val
            ApplySettings()
        end
    })
    row3c:AddWidget(barTextSizeSlider, 0.5)
    table_insert(allWidgets, barTextSizeSlider)
    table_insert(statusBarWidgets, barTextSizeSlider)
    card3:AddRow(row3c, 40)

    -- Separator
    local row3sep = GUIFrame:CreateRow(card3.content, 8)
    local sep1 = GUIFrame:CreateSeparator(row3sep)
    row3sep:AddWidget(sep1, 1)
    table_insert(allWidgets, sep1)
    table_insert(statusBarWidgets, sep1)
    card3:AddRow(row3sep, 8)

    -- Strip Textures toggle
    local row3d = GUIFrame:CreateRow(card3.content, 36)
    local stripTexturesCheck = GUIFrame:CreateCheckbox(row3d, "Strip Blizzard Textures & Add Backdrop", {
        value = barDB.StripTextures ~= false,
        callback = function(checked)
            barDB.StripTextures = checked
            ApplySettings()
        end,
    })
    row3d:AddWidget(stripTexturesCheck, 1)
    table_insert(allWidgets, stripTexturesCheck)
    table_insert(statusBarWidgets, stripTexturesCheck)
    card3:AddRow(row3d, 36)

    -- Backdrop Color
    local row3e = GUIFrame:CreateRow(card3.content, 36)
    local backdropColorPicker = GUIFrame:CreateColorPicker(row3e, "Backdrop Color", {
        color = barDB.BackdropColor,
        callback = function(r, g, b, a)
            barDB.BackdropColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row3e:AddWidget(backdropColorPicker, 0.5)
    table_insert(allWidgets, backdropColorPicker)
    table_insert(statusBarWidgets, backdropColorPicker)

    -- Border Color
    local borderColorPicker = GUIFrame:CreateColorPicker(row3e, "Border Color", {
        color = barDB.BorderColor,
        callback = function(r, g, b, a)
            barDB.BorderColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row3e:AddWidget(borderColorPicker, 0.5)
    table_insert(allWidgets, borderColorPicker)
    table_insert(statusBarWidgets, borderColorPicker)
    card3:AddRow(row3e, 36)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Text Widgets
    ----------------------------------------------------------------
    local textDB = db.TextWidget
    local card4 = GUIFrame:CreateCard(scrollChild, "Text Widgets", yOffset)
    table_insert(allWidgets, card4)

    -- Enable toggle and Style Text
    local row4a = GUIFrame:CreateRow(card4.content, 36)
    local enableTextCheck = GUIFrame:CreateCheckbox(row4a, "Enable Text Widget Styling", {
        value = textDB.Enabled ~= false,
        callback = function(checked)
            textDB.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end,
    })
    row4a:AddWidget(enableTextCheck, 0.5)
    table_insert(allWidgets, enableTextCheck)

    -- Style Text toggle
    local styleTextCheck = GUIFrame:CreateCheckbox(row4a, "Style Text", {
        value = textDB.StyleText ~= false,
        callback = function(checked)
            textDB.StyleText = checked
            ApplySettings()
        end,
    })
    row4a:AddWidget(styleTextCheck, 0.5)
    table_insert(allWidgets, styleTextCheck)
    table_insert(textWidgets, styleTextCheck)
    card4:AddRow(row4a, 36)

    -- Width slider (0 = default/auto)
    local row4width = GUIFrame:CreateRow(card4.content, 40)
    local textWidthSlider = GUIFrame:CreateSlider(row4width, "Width (0=Auto)", {
        min = 0,
        max = 400,
        step = 1,
        value = textDB.Width or 0,
        labelWidth = 80,
        callback = function(val)
            textDB.Width = val
            ApplySettings()
        end
    })
    row4width:AddWidget(textWidthSlider, 1)
    table_insert(allWidgets, textWidthSlider)
    table_insert(textWidgets, textWidthSlider)
    card4:AddRow(row4width, 40)

    -- Font Size Slider
    local row4b = GUIFrame:CreateRow(card4.content, 40)
    local textSizeSlider = GUIFrame:CreateSlider(row4b, "Font Size", {
        min = 8,
        max = 24,
        step = 1,
        value = textDB.Size or 14,
        labelWidth = 60,
        callback = function(val)
            textDB.Size = val
            ApplySettings()
        end
    })
    row4b:AddWidget(textSizeSlider, 1)
    table_insert(allWidgets, textSizeSlider)
    table_insert(textWidgets, textSizeSlider)
    card4:AddRow(row4b, 40)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 3)
    return yOffset
end)

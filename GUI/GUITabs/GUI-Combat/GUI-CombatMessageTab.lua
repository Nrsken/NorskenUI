-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.LSM

-- Localization Setup
local table_insert = table.insert
local pairs, ipairs = pairs, ipairs

-- Helper to get Combat Message module
local function GetCombatMessageModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("CombatMessage", true)
    end
    return nil
end

-- Combat Message Tab Content
GUIFrame:RegisterContent("combatMessage", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.CombatMessage
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Ensure new structure tables exist
    db.EnterCombat = db.EnterCombat or
        { Enabled = true, Text = db.EnterText or "+ COMBAT +", Color = db.EnterColor or { 0.929, 0.259, 0, 1 } }
    db.ExitCombat = db.ExitCombat or
        { Enabled = true, Text = db.ExitText or "- COMBAT -", Color = db.ExitColor or { 0.788, 1, 0.627, 1 } }
    db.NoTarget = db.NoTarget or { Enabled = false, Text = "NO TARGET", Color = { 1, 0.8, 0, 1 } }
    db.FontShadow = db.FontShadow or {}

    -- Get Combat Message module
    local CM = GetCombatMessageModule()

    -- Track widgets for enable/disable logic
    local allWidgets = {}
    local shadowWidgets = {}
    local enterWidgets = {}
    local exitWidgets = {}
    local noTargetWidgets = {}

    -- Helper to apply settings
    local function ApplySettings()
        if CM then
            CM:ApplySettings()
        end
    end

    -- Helper to apply new state
    local function ApplyCombatMessageState(enabled)
        if not CM then return end
        CM.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("CombatMessage")
        else
            NRSKNUI.Addon:DisableModule("CombatMessage")
        end
    end

    -- Comprehensive widget state update
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false
        local usingSoftOutline = db.FontOutline == "SOFTOUTLINE"
        local shadowEnabled = not usingSoftOutline and db.FontShadow and db.FontShadow.Enabled == true
        local enterEnabled = db.EnterCombat and db.EnterCombat.Enabled ~= false
        local exitEnabled = db.ExitCombat and db.ExitCombat.Enabled ~= false
        local noTargetEnabled = db.NoTarget and db.NoTarget.Enabled == true

        -- Apply main enable state to ALL widgets
        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end

        -- Apply conditional states (only if main is enabled)
        if mainEnabled then
            -- Disable all shadow widgets when using SOFTOUTLINE
            for _, widget in ipairs(shadowWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(shadowEnabled)
                end
            end
            for _, widget in ipairs(enterWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(enterEnabled)
                end
            end
            for _, widget in ipairs(exitWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(exitEnabled)
                end
            end
            for _, widget in ipairs(noTargetWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(noTargetEnabled)
                end
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: Combat Texts (Enable)
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Combat Texts", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Combat Messages", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyCombatMessageState(checked)
            UpdateAllWidgetStates()
        end,
        true,
        "Combat Messages",
        "On",
        "Off"
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
            yOffset = 180,
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

    -- Font Face and Outline
    local row3a = GUIFrame:CreateRow(card3.content, 40)
    local fontDropdown = GUIFrame:CreateDropdown(row3a, "Font", fontList, db.FontFace or "Friz Quadrata TT", 30,
        function(key)
            db.FontFace = key
            ApplySettings()
        end)
    row3a:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)

    local outlineList = {
        { key = "NONE", text = "None" },
        { key = "OUTLINE", text = "Outline" },
        { key = "THICKOUTLINE", text = "Thick" },
        { key = "SOFTOUTLINE", text = "Soft" },
    }
    local outlineDropdown = GUIFrame:CreateDropdown(row3a, "Outline", outlineList, db.FontOutline or "OUTLINE", 45,
        function(key)
            db.FontOutline = key
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row3a:AddWidget(outlineDropdown, 0.5)
    table_insert(allWidgets, outlineDropdown)
    card3:AddRow(row3a, 40)

    -- Font Size
    local row3b = GUIFrame:CreateRow(card3.content, 37)
    local fontSizeSlider = GUIFrame:CreateSlider(card3.content, "Font Size", 8, 72, 1, db.FontSize or 15, 60,
        function(val)
            db.FontSize = val
            ApplySettings()
        end)
    row3b:AddWidget(fontSizeSlider, 1)
    table_insert(allWidgets, fontSizeSlider)
    card3:AddRow(row3b, 37)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Font Shadow
    ----------------------------------------------------------------
    local card4 = GUIFrame:CreateCard(scrollChild, "Font Shadow", yOffset)
    table_insert(allWidgets, card4)

    local row4a = GUIFrame:CreateRow(card4.content, 40)
    local shadowEnableCheck = GUIFrame:CreateCheckbox(row4a, "Enable Shadow", db.FontShadow.Enabled == true,
        function(checked)
            db.FontShadow.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row4a:AddWidget(shadowEnableCheck, 0.5)
    table_insert(allWidgets, shadowEnableCheck)
    table_insert(shadowWidgets, shadowEnableCheck)

    local shadowColor = GUIFrame:CreateColorPicker(row4a, "Shadow Color", db.FontShadow.Color or { 0, 0, 0, 1 },
        function(r, g, b, a)
            db.FontShadow.Color = { r, g, b, a }
            ApplySettings()
        end)
    row4a:AddWidget(shadowColor, 0.5)
    table_insert(allWidgets, shadowColor)
    table_insert(shadowWidgets, shadowColor)
    card4:AddRow(row4a, 40)

    local row4b = GUIFrame:CreateRow(card4.content, 37)
    local shadowX = GUIFrame:CreateSlider(row4b, "Shadow X", -5, 5, 1, db.FontShadow.OffsetX or 0, 15,
        function(val)
            db.FontShadow.OffsetX = val
            ApplySettings()
        end)
    row4b:AddWidget(shadowX, 0.5)
    table_insert(allWidgets, shadowX)
    table_insert(shadowWidgets, shadowX)

    local shadowY = GUIFrame:CreateSlider(row4b, "Shadow Y", -5, 5, 1, db.FontShadow.OffsetY or 0, 15,
        function(val)
            db.FontShadow.OffsetY = val
            ApplySettings()
        end)
    row4b:AddWidget(shadowY, 0.5)
    table_insert(allWidgets, shadowY)
    table_insert(shadowWidgets, shadowY)
    card4:AddRow(row4b, 37)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 5: Enter Combat Message
    ----------------------------------------------------------------
    local card5 = GUIFrame:CreateCard(scrollChild, "Enter Combat Message", yOffset)
    table_insert(allWidgets, card5)

    local row5a = GUIFrame:CreateRow(card5.content, 38)
    local enterEnableCheck = GUIFrame:CreateCheckbox(row5a, "Enabled", db.EnterCombat.Enabled ~= false,
        function(checked)
            db.EnterCombat.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row5a:AddWidget(enterEnableCheck, 0.2)
    table_insert(allWidgets, enterEnableCheck)

    local enterColorPicker = GUIFrame:CreateColorPicker(row5a, "Color",
        db.EnterCombat.Color or { 0.929, 0.259, 0, 1 },
        function(r, g, b, a)
            db.EnterCombat.Color = { r, g, b, a }
            ApplySettings()
        end)
    row5a:AddWidget(enterColorPicker, 0.3)
    table_insert(allWidgets, enterColorPicker)
    table_insert(enterWidgets, enterColorPicker)

    local enterTextInput = GUIFrame:CreateEditBox(row5a, "Text", db.EnterCombat.Text or "+ COMBAT +", function(val)
        db.EnterCombat.Text = val
        ApplySettings()
    end)
    row5a:AddWidget(enterTextInput, 0.5)
    table_insert(allWidgets, enterTextInput)
    table_insert(enterWidgets, enterTextInput)
    card5:AddRow(row5a, 38)

    yOffset = yOffset + card5:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 6: Exit Combat Message
    ----------------------------------------------------------------
    local card6 = GUIFrame:CreateCard(scrollChild, "Exit Combat Message", yOffset)
    table_insert(allWidgets, card6)

    local row6a = GUIFrame:CreateRow(card6.content, 38)
    local exitEnableCheck = GUIFrame:CreateCheckbox(row6a, "Enabled", db.ExitCombat.Enabled ~= false,
        function(checked)
            db.ExitCombat.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row6a:AddWidget(exitEnableCheck, 0.2)
    table_insert(allWidgets, exitEnableCheck)

    local exitColorPicker = GUIFrame:CreateColorPicker(row6a, "Color",
        db.ExitCombat.Color or { 0.788, 1, 0.627, 1 },
        function(r, g, b, a)
            db.ExitCombat.Color = { r, g, b, a }
            ApplySettings()
        end)
    row6a:AddWidget(exitColorPicker, 0.3)
    table_insert(allWidgets, exitColorPicker)
    table_insert(exitWidgets, exitColorPicker)

    local exitTextInput = GUIFrame:CreateEditBox(row6a, "Text", db.ExitCombat.Text or "- COMBAT -", function(val)
        db.ExitCombat.Text = val
        ApplySettings()
    end)
    row6a:AddWidget(exitTextInput, 0.5)
    table_insert(allWidgets, exitTextInput)
    table_insert(exitWidgets, exitTextInput)
    card6:AddRow(row6a, 38)

    yOffset = yOffset + card6:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 7: No Target Warning
    ----------------------------------------------------------------
    local card7 = GUIFrame:CreateCard(scrollChild, "No Target Warning", yOffset)
    table_insert(allWidgets, card7)

    local row7a = GUIFrame:CreateRow(card7.content, 38)
    local noTargetEnableCheck = GUIFrame:CreateCheckbox(row7a, "Enabled", db.NoTarget.Enabled == true,
        function(checked)
            db.NoTarget.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
            -- Trigger immediate check
            if CM then CM:CheckNoTarget() end
        end)
    row7a:AddWidget(noTargetEnableCheck, 0.2)
    table_insert(allWidgets, noTargetEnableCheck)

    local noTargetColorPicker = GUIFrame:CreateColorPicker(row7a, "Color",
        db.NoTarget.Color or { 1, 0.8, 0, 1 },
        function(r, g, b, a)
            db.NoTarget.Color = { r, g, b, a }
            ApplySettings()
        end)
    row7a:AddWidget(noTargetColorPicker, 0.3)
    table_insert(allWidgets, noTargetColorPicker)
    table_insert(noTargetWidgets, noTargetColorPicker)

    local noTargetTextInput = GUIFrame:CreateEditBox(row7a, "Text", db.NoTarget.Text or "NO TARGET", function(val)
        db.NoTarget.Text = val
        ApplySettings()
    end)
    row7a:AddWidget(noTargetTextInput, 0.5)
    table_insert(allWidgets, noTargetTextInput)
    table_insert(noTargetWidgets, noTargetTextInput)
    card7:AddRow(row7a, 38)

    yOffset = yOffset + card7:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 8: Animation
    ----------------------------------------------------------------
    local card8 = GUIFrame:CreateCard(scrollChild, "Animation", yOffset)
    table_insert(allWidgets, card8)

    local row8a = GUIFrame:CreateRow(card8.content, 37)
    local durationSlider = GUIFrame:CreateSlider(row8a, "Fade Duration (seconds)", 0.5, 5.0, 0.1, db.Duration or 2.5, 140,
        function(val)
            db.Duration = val
            ApplySettings()
        end)
    row8a:AddWidget(durationSlider, 0.6)
    table_insert(allWidgets, durationSlider)

    local spacingSlider = GUIFrame:CreateSlider(row8a, "Message Spacing", 0, 20, 1, db.Spacing or 4, 100,
        function(val)
            db.Spacing = val
            ApplySettings()
        end)
    row8a:AddWidget(spacingSlider, 0.4)
    table_insert(allWidgets, spacingSlider)
    card8:AddRow(row8a, 37)

    yOffset = yOffset + card8:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 5)
    return yOffset
end)

-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local table_insert = table.insert
local ipairs = ipairs

-- Helper to get Blizzard Mouseover module
local function GetMicroMenuModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("MicroMenu", true)
    end
    return nil
end

-- Combat Message Tab Content
GUIFrame:RegisterContent("MicroMenu", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.MicroMenu
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get Combat Message module
    local MM = GetMicroMenuModule()

    -- Track widgets for enable/disable logic
    local allWidgets = {} -- All widgets (except main toggle)
    local bgWidgets = {}
    local mouseOverWidgets = {}

    -- Helper to apply settings
    local function ApplySettings()
        if MM then
            MM:UpdateMicroBar()
        end
    end

    local function ApplyPosition()
        if MM then
            MM:UpdatePosition()
        end
    end
    local function UpdateAlphaState()
        if MM then
            MM:UpdateAlpha()
        end
    end

    -- Helper to apply new state
    local function ApplyMicroMenuState(enabled)
        if not MM then return end
        MM.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("MicroMenu")
        else
            NRSKNUI.Addon:DisableModule("MicroMenu")
        end
    end

    -- Comprehensive widget state update
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false
        local bgEnabled = db.ShowBackdrop ~= false
        local mouseOverEnabled = db.Mouseover and db.Mouseover.Enabled ~= false

        -- First: Apply main enable state to ALL widgets
        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end
        -- if main toggle is on, check bg widgets
        if mainEnabled then
            for _, widget in ipairs(bgWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(bgEnabled)
                end
            end

            for _, widget in ipairs(mouseOverWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(mouseOverEnabled)
                end
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: MicroMenu Skinning Enable
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Micro Menu Skinning", yOffset)

    -- Enable Checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Micro Menu Skinning", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyMicroMenuState(checked)
            UpdateAllWidgetStates()
            NRSKNUI:CreateReloadPrompt("Enabling/Disabling this UI element requires a reload to take full effect.")
        end,
        true,
        "Micro Menu Skinning",
        "On",
        "Off"
    )
    row1:AddWidget(enableCheck, 1)

    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Position Settings (using reusable position card)
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
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })
    -- Add position card widgets to allWidgets for enable/disable
    if card2.positionWidgets then
        for _, widget in ipairs(card2.positionWidgets) do
            table_insert(allWidgets, widget)
        end
    end
    table_insert(allWidgets, card2)
    yOffset = newOffset

    ----------------------------------------------------------------
    -- Card 3: Mouseover Settings
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Mouseover Settings", yOffset)
    table_insert(allWidgets, card3)

    -- Alpha toggle
    local row2 = GUIFrame:CreateRow(card3.content, 40)
    local mouseOverDB = db.Mouseover
    local MicroMenuEnableCheck = GUIFrame:CreateCheckbox(row2, "Enable Micro Menu Mouseover", mouseOverDB.Enabled ~= false,
        function(checked)
            mouseOverDB.Enabled = checked
            UpdateAlphaState()
            UpdateAllWidgetStates()
        end)
    row2:AddWidget(MicroMenuEnableCheck, 0.5)
    table_insert(allWidgets, MicroMenuEnableCheck)

    -- Alpha when non mouseover
    local MicroMenunonMouseoverAlpha = GUIFrame:CreateSlider(row2, "Alpha When No Mouseover", 0, 1, 0.1,
        mouseOverDB.Alpha, _,
        function(val)
            mouseOverDB.Alpha = val
            ApplySettings()
        end)
    row2:AddWidget(MicroMenunonMouseoverAlpha, 0.5)
    table_insert(allWidgets, MicroMenunonMouseoverAlpha)
    table_insert(mouseOverWidgets, MicroMenunonMouseoverAlpha)

    card3:AddRow(row2, 40)

    -- Fade In Duration
    local row3 = GUIFrame:CreateRow(card3.content, 36)
    local MicroMenuFadeInDuration = GUIFrame:CreateSlider(row3, "Fade In Duration", 0, 10, 0.1,
        mouseOverDB.FadeInDuration, _,
        function(val)
            mouseOverDB.FadeInDuration = val
        end)
    row3:AddWidget(MicroMenuFadeInDuration, 0.5)
    table_insert(allWidgets, MicroMenuFadeInDuration)
    table_insert(mouseOverWidgets, MicroMenuFadeInDuration)

    -- Fade Out Duration
    local MicroMenuFadeOutDuration = GUIFrame:CreateSlider(row3, "Fade Out Duration", 0, 10, 0.1,
        mouseOverDB.FadeOutDuration, _,
        function(val)
            mouseOverDB.FadeOutDuration = val
        end)
    row3:AddWidget(MicroMenuFadeOutDuration, 0.5)
    table_insert(allWidgets, MicroMenuFadeOutDuration)
    table_insert(mouseOverWidgets, MicroMenuFadeOutDuration)

    card3:AddRow(row3, 36)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Button Settings
    ----------------------------------------------------------------
    local card4 = GUIFrame:CreateCard(scrollChild, "Button Settings", yOffset)
    table_insert(allWidgets, card4)

    -- Button width
    local row4 = GUIFrame:CreateRow(card4.content, 40)
    local MMButtonWidth = GUIFrame:CreateSlider(row4, "Button Width", 5, 50, 1,
        db.ButtonWidth, _,
        function(val)
            db.ButtonWidth = val
            ApplySettings()
        end)
    row4:AddWidget(MMButtonWidth, 0.5)
    table_insert(allWidgets, MMButtonWidth)

    -- Button Height
    local MMButtonHeight = GUIFrame:CreateSlider(row4, "Button Height", 5, 50, 1,
        db.ButtonHeight, _,
        function(val)
            db.ButtonHeight = val
            ApplySettings()
        end)
    row4:AddWidget(MMButtonHeight, 0.5)
    table_insert(allWidgets, MMButtonHeight)
    card4:AddRow(row4, 40)

    -- Button Height
    local row5 = GUIFrame:CreateRow(card4.content, 39)
    local MMButtonSpacing = GUIFrame:CreateSlider(row5, "Button Spacing", -20, 20, 1,
        db.ButtonSpacing, _,
        function(val)
            db.ButtonSpacing = val
            ApplySettings()
        end)
    row5:AddWidget(MMButtonSpacing, 1)
    table_insert(allWidgets, MMButtonSpacing)
    card4:AddRow(row5, 39)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 5: Backdrop Settings
    ----------------------------------------------------------------
    local card5 = GUIFrame:CreateCard(scrollChild, "Backdrop Settings", yOffset)
    table_insert(allWidgets, card5)

    -- MicroMenu Backdrop Toggle
    local row6 = GUIFrame:CreateRow(card5.content, 39)
    local backdropCheck = GUIFrame:CreateCheckbox(row6, "Enable Backdrop", db.ShowBackdrop ~= false,
        function(checked)
            db.ShowBackdrop = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row6:AddWidget(backdropCheck, 1)
    table_insert(allWidgets, backdropCheck)
    card5:AddRow(row6, 39)

    -- Backdrop coloring
    local row7 = GUIFrame:CreateRow(card5.content, 39)
    local BackdropColor = GUIFrame:CreateColorPicker(row7, "Backdrop Color", db.BackdropColor,
        function(r, g, b, a)
            db.BackdropColor = { r, g, b, a }
            ApplySettings()
        end)
    row7:AddWidget(BackdropColor, 1)
    table_insert(allWidgets, BackdropColor)
    table_insert(bgWidgets, BackdropColor)
    card5:AddRow(row7, 39)

    -- Backdrop Border coloring
    local row8 = GUIFrame:CreateRow(card5.content, 39)
    local BorderColor = GUIFrame:CreateColorPicker(row8, "Backdrop Border Color", db.BackdropBorderColor,
        function(r, g, b, a)
            db.BackdropBorderColor = { r, g, b, a }
            ApplySettings()
        end)
    row8:AddWidget(BorderColor, 1)
    table_insert(allWidgets, BorderColor)
    table_insert(bgWidgets, BorderColor)
    card5:AddRow(row8, 39)

    yOffset = yOffset + card5:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 4)
    return yOffset
end)

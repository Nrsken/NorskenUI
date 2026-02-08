-- NorskenUI namespace
local _, NRSKNUI = ...

local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local table_insert = table.insert
local CreateFrame = CreateFrame
local ipairs = ipairs

-- Helper: Create Texture Selector (auto-width based on container)
local function CreateTextureSelector(parent, textures, textureOrder, currentTexture, getColorFunc, onSelect)
    -- Container frame
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(80)

    -- Buttons container
    local buttons = {}
    local buttonSize = 70
    local minSpacing = 8 -- Minimum spacing between buttons

    -- Create buttons (positioned later by OnSizeChanged)
    for i, textureName in ipairs(textureOrder) do
        local texturePath = textures[textureName]

        -- Create button
        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        btn:SetSize(buttonSize, buttonSize)

        -- Backdrop
        btn:SetBackdrop({
            bgFile = "Interface\\BUTTONS\\WHITE8X8",
            edgeFile = "Interface\\BUTTONS\\WHITE8X8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)

        -- Texture
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", 8, -8)
        tex:SetPoint("BOTTOMRIGHT", -8, 8)
        tex:SetTexture(texturePath)
        btn.tex = tex
        btn.textureName = textureName

        -- Update visual state
        local function UpdateVisuals()
            local isSelected = currentTexture == btn.textureName
            local r, g, b, a = 1, 1, 1, 1
            if getColorFunc then
                r, g, b, a = getColorFunc()
            end

            -- Visual states
            if btn.disabled then
                btn:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 0.6)
                tex:SetVertexColor(r * 0.3, g * 0.3, b * 0.3)
                tex:SetAlpha(0.5)
            elseif isSelected then
                btn:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                tex:SetVertexColor(r, g, b)
                tex:SetAlpha(a)
            elseif btn.hover then
                btn:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                tex:SetVertexColor(r * 0.8, g * 0.8, b * 0.8)
                tex:SetAlpha(a * 0.9)
            else
                btn:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
                tex:SetVertexColor(r * 0.6, g * 0.6, b * 0.6)
                tex:SetAlpha(a * 0.8)
            end
        end
        btn.UpdateVisuals = UpdateVisuals

        -- Mouse events
        btn:SetScript("OnEnter", function(self)
            self.hover = true
            UpdateVisuals()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(textureName, 1, 0.82, 0)
            GameTooltip:Show()
        end)

        -- Mouse leave
        btn:SetScript("OnLeave", function(self)
            self.hover = false
            UpdateVisuals()
            GameTooltip:Hide()
        end)

        -- Click handler
        btn:SetScript("OnClick", function(self)
            if self.disabled then return end
            currentTexture = self.textureName
            -- Update all buttons
            for _, b in ipairs(buttons) do
                b.UpdateVisuals()
            end
            if onSelect then
                onSelect(self.textureName)
            end
        end)

        -- Initial visual update
        UpdateVisuals()
        table_insert(buttons, btn)
    end

    -- Track last width to prevent unnecessary recalculations
    container.lastWidth = 0

    -- OnSizeChanged: recalculate button positions when container width changes
    container:SetScript("OnSizeChanged", function(self, width)
        if not width or width <= 0 then return end

        -- Only recalculate if width changed by more than 1 pixel
        local flooredWidth = math.floor(width)
        if math.abs(flooredWidth - (self.lastWidth or 0)) < 2 then return end
        self.lastWidth = flooredWidth

        local numButtons = #buttons
        if numButtons == 0 then return end

        -- Calculate total width needed for buttons
        local totalButtonWidth = numButtons * buttonSize

        -- Calculate spacing to distribute buttons evenly
        local availableSpacing = flooredWidth - totalButtonWidth - Theme.paddingSmall
        local spacing = math.max(minSpacing, math.floor(availableSpacing / (numButtons - 1)))

        -- If not enough room, use minimum spacing
        if spacing < minSpacing then
            spacing = minSpacing
        end

        -- Position buttons
        for i, btn in ipairs(buttons) do
            btn:ClearAllPoints()
            if i == 1 then
                btn:SetPoint("LEFT", self, "LEFT", 0, 0)
            else
                btn:SetPoint("LEFT", buttons[i - 1], "RIGHT", spacing, 0)
            end
        end
    end)

    -- Container methods
    function container:SetEnabled(enabled)
        for _, btn in ipairs(buttons) do
            btn.disabled = not enabled
            btn:EnableMouse(enabled)
            btn.UpdateVisuals()
        end
    end

    -- Set current value
    function container:SetValue(textureName)
        currentTexture = textureName
        for _, btn in ipairs(buttons) do
            btn.UpdateVisuals()
        end
    end

    -- Refresh colors
    function container:RefreshColors()
        for _, btn in ipairs(buttons) do
            btn.UpdateVisuals()
        end
    end

    container.buttons = buttons
    return container
end

-- Register Cursor Circle Tab
GUIFrame:RegisterContent("cursorCircle", function(scrollChild, yOffset)
    -- Get CursorCircle module
    local CC = NRSKNUI.Addon and NRSKNUI.Addon:GetModule("CursorCircle", true)
    if not CC then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("CursorCircle module not loaded")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Safety check for database
    local db = CC.db
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Track all widgets for main toggle control
    local allWidgets = {}               -- All widgets
    local colorModeWidgets = {}         -- Widgets dependent on ColorMode = "custom"
    local throttleWidgets = {}          -- Widgets dependent on UseUpdateInterval = true
    local gcdWidgets = {}               -- Widgets dependent on GCD.Mode ~= "disabled"
    local gcdSeparateWidgets = {}       -- Widgets dependent on GCD.Mode == "separate"
    local gcdRingColorModeWidgets = {}  -- Widgets dependent on GCD.RingColorMode == "custom"
    local gcdSwipeColorModeWidgets = {} -- Widgets dependent on GCD.SwipeColorMode == "custom"
    local textureSelector = nil         -- Main texture selector
    local gcdTextureSelector = nil      -- GCD texture selector

    -- Helper to apply settings
    local function ApplySettings()
        if CC and CC.ApplySettings then CC:ApplySettings() end
        if textureSelector and textureSelector.RefreshColors then
            textureSelector:RefreshColors()
        end
        if gcdTextureSelector and gcdTextureSelector.RefreshColors then
            gcdTextureSelector:RefreshColors()
        end
    end

    -- Alias for specific functions
    local function ApplyColor()
        ApplySettings()
    end

    local function ApplyGCDSettings()
        ApplySettings()
    end

    -- Comprehensive widget state update (priority-based)
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled == true

        -- Priority 1: Main toggle controls ALL widgets
        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end
        if textureSelector then
            textureSelector:SetEnabled(mainEnabled)
        end

        -- Priority 2: If main is enabled, apply conditional states
        if mainEnabled then
            -- ColorMode widgets - only enabled when ColorMode = "custom"
            local colorMode = db.ColorMode or "theme"
            local isCustomColor = (colorMode == "custom")
            for _, widget in ipairs(colorModeWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(isCustomColor)
                end
            end

            -- Throttle widgets - only enabled when UseUpdateInterval = true
            local throttleEnabled = db.UseUpdateInterval == true
            for _, widget in ipairs(throttleWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(throttleEnabled)
                end
            end

            -- GCD widgets - only enabled when GCD.Mode ~= "disabled"
            local gcdMode = db.GCD and db.GCD.Mode or "integrated"
            local gcdEnabled = gcdMode ~= "disabled"
            for _, widget in ipairs(gcdWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(gcdEnabled)
                end
            end
            if gcdTextureSelector then
                gcdTextureSelector:SetEnabled(gcdEnabled and gcdMode == "separate")
            end

            -- GCD Separate widgets - only enabled when GCD.Mode == "separate"
            local isSeparateMode = gcdMode == "separate"
            for _, widget in ipairs(gcdSeparateWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(gcdEnabled and isSeparateMode)
                end
            end

            -- GCD Ring ColorMode widgets - only enabled when GCD.RingColorMode == "custom"
            local gcdRingColorMode = db.GCD and db.GCD.RingColorMode or "theme"
            local isGCDRingCustomColor = gcdRingColorMode == "custom"
            for _, widget in ipairs(gcdRingColorModeWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(gcdEnabled and isSeparateMode and isGCDRingCustomColor)
                end
            end

            -- GCD Swipe ColorMode widgets - only enabled when GCD.SwipeColorMode == "custom"
            local gcdSwipeColorMode = db.GCD and db.GCD.SwipeColorMode or "custom"
            local isGCDSwipeCustomColor = gcdSwipeColorMode == "custom"
            for _, widget in ipairs(gcdSwipeColorModeWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(gcdEnabled and isGCDSwipeCustomColor)
                end
            end
        else
            -- Main disabled - disable GCD texture selector too
            if gcdTextureSelector then
                gcdTextureSelector:SetEnabled(false)
            end
        end
    end

    -- Get effective color for texture preview
    local function GetEffectiveColor()
        local colorMode = db.ColorMode or "custom"
        return NRSKNUI:GetAccentColor(colorMode, db.Color)
    end

    -- Ensure GCD settings exist
    if not db.GCD then
        db.GCD = {
            Mode = "integrated",
            Size = 25,
            Texture = "Circle 5",
            SwipeColorMode = "theme",
            SwipeColorColor = { 1, 1, 1, 1 },
            Reverse = true,
            HideOutOfCombat = false,
            RingColorMode = "theme",
            RingColor = { 1, 1, 1, 1 },
        }
    end
    local gcd = db.GCD

    ----------------------------------------------------------------
    -- Card 1: Cursor Circle (Enable)
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Cursor Circle", yOffset)

    -- Enable checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 37)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Cursor Circle", db.Enabled == true, function(checked)
            db.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end,
        true,
        "Cursor Circle",
        "On",
        "Off"
    )
    row1:AddWidget(enableCheck, 0.5)

    -- GCD Mode dropdown
    local gcdModeDropdown = GUIFrame:CreateDropdown(row1, "GCD Mode", CC.GCDModeOptions,
        gcd.Mode or "integrated", 120,
        function(key)
            gcd.Mode = key
            ApplyGCDSettings()
            UpdateAllWidgetStates()
        end)
    row1:AddWidget(gcdModeDropdown, 0.5)
    table_insert(allWidgets, gcdModeDropdown)

    card1:AddRow(row1, 37)

    -- Separator
    local row1sep = GUIFrame:CreateRow(card1.content, 8)
    local sepEnblCard = GUIFrame:CreateSeparator(row1sep)
    row1sep:AddWidget(sepEnblCard, 1)
    table_insert(allWidgets, sepEnblCard)
    card1:AddRow(row1sep, 8)

    -- Throttle toggle
    local row5a = GUIFrame:CreateRow(card1.content, 27)
    local throttleCheck = GUIFrame:CreateCheckbox(row5a, "Limit Update Rate (Saves CPU)",
        db.UseUpdateInterval == true, function(checked)
            db.UseUpdateInterval = checked
            UpdateAllWidgetStates()
        end)
    row5a:AddWidget(throttleCheck, 0.5)
    table_insert(allWidgets, throttleCheck)

    -- Update interval slider (only enabled when throttling is on)
    local intervalSlider = GUIFrame:CreateSlider(row5a, "Update Interval (sec)", 0.01, 0.1, 0.001,
        db.UpdateInterval or 0.016, 80,
        function(val)
            db.UpdateInterval = val
        end)
    row5a:AddWidget(intervalSlider, 0.5)
    table_insert(allWidgets, intervalSlider)
    table_insert(throttleWidgets, intervalSlider) -- Also conditional on UseUpdateInterval
    card1:AddRow(row5a, 37)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Appearance Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Main Ring Settings", yOffset)
    table_insert(allWidgets, card2)

    -- Size slider
    local row2a = GUIFrame:CreateRow(card2.content, 39)
    local sizeSlider = GUIFrame:CreateSlider(row2a, "Size", 20, 150, 1, db.Size or 50, 60,
        function(val)
            db.Size = val
            ApplySettings()
        end)
    row2a:AddWidget(sizeSlider, 1)
    table_insert(allWidgets, sizeSlider)
    card2:AddRow(row2a, 39)

    -- Color Mode dropdown
    local row4 = GUIFrame:CreateRow(card2.content, 37)
    local colorModeDropdown = GUIFrame:CreateDropdown(row4, "Color Mode", NRSKNUI.ColorModeOptions,
        db.ColorMode or "theme", 70,
        function(key)
            db.ColorMode = key
            ApplyColor()
            UpdateAllWidgetStates()
        end)
    row4:AddWidget(colorModeDropdown, 0.5)
    table_insert(allWidgets, colorModeDropdown)

    -- Color picker (only applies when ColorMode = "custom")
    local colorPicker = GUIFrame:CreateColorPicker(row4, "Custom Color", db.Color or { 1, 1, 1, 1 },
        function(r, g, b, a)
            db.Color = { r, g, b, a }
            ApplyColor()
        end)
    row4:AddWidget(colorPicker, 0.5)
    table_insert(allWidgets, colorPicker)
    table_insert(colorModeWidgets, colorPicker) -- Also conditional on ColorMode
    card2:AddRow(row4, 37)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Texture Selection
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Main Ring Texture", yOffset)
    table_insert(allWidgets, card3)

    -- Create texture selector row
    local row3 = GUIFrame:CreateRow(card3.content, 71)

    -- Texture selector
    textureSelector = CreateTextureSelector(
        row3,
        CC.Textures,
        CC.TextureOrder,
        db.Texture or "Circle 1",
        GetEffectiveColor,
        function(textureName)
            db.Texture = textureName
            ApplySettings()
        end
    )
    textureSelector:SetPoint("TOPLEFT", row3, "TOPLEFT", 0, 3)
    textureSelector:SetPoint("TOPRIGHT", row3, "TOPRIGHT", 0, 0)
    textureSelector:SetEnabled(db.Enabled == true)
    card3:AddRow(row3, 71)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 6: GCD Ring Settings
    ----------------------------------------------------------------

    local card6 = GUIFrame:CreateCard(scrollChild, "GCD Swipe Settings", yOffset)
    table_insert(allWidgets, card6)
    table_insert(gcdWidgets, card6)

    -- GCD Swipe Color Mode dropdown
    local row9a = GUIFrame:CreateRow(card6.content, 39)
    local gcdSwipeColorModeDropdown = GUIFrame:CreateDropdown(row9a, "Color Mode", NRSKNUI.ColorModeOptions,
        gcd.SwipeColorMode or "custom", 70,
        function(key)
            gcd.SwipeColorMode = key
            ApplyGCDSettings()
            UpdateAllWidgetStates()
        end)
    row9a:AddWidget(gcdSwipeColorModeDropdown, 0.5)
    table_insert(allWidgets, gcdSwipeColorModeDropdown)
    table_insert(gcdWidgets, gcdSwipeColorModeDropdown)

    -- GCD Swipe Color picker (only applies when SwipeColorMode = "custom")
    local gcdSwipeColorPicker = GUIFrame:CreateColorPicker(row9a, "Custom Color",
        gcd.SwipeColor or { 1, 1, 1, 1 },
        function(r, g, b, a)
            gcd.SwipeColor = { r, g, b, a }
            ApplyGCDSettings()
        end)
    row9a:AddWidget(gcdSwipeColorPicker, 0.5)
    table_insert(allWidgets, gcdSwipeColorPicker)
    table_insert(gcdWidgets, gcdSwipeColorPicker)
    table_insert(gcdSwipeColorModeWidgets, gcdSwipeColorPicker)
    card6:AddRow(row9a, 39)

    -- Reverse direction checkbox
    local row10a = GUIFrame:CreateRow(card6.content, 37)
    local reverseCheck = GUIFrame:CreateCheckbox(row10a, "Reverse Swipe Direction",
        gcd.Reverse == true, function(checked)
            gcd.Reverse = checked
            ApplyGCDSettings()
        end)
    row10a:AddWidget(reverseCheck, 0.5)
    table_insert(allWidgets, reverseCheck)
    table_insert(gcdWidgets, reverseCheck)

    -- Hide out of combat checkbox
    local hideOOCCheck = GUIFrame:CreateCheckbox(row10a, "Only Show In Combat",
        gcd.HideOutOfCombat == true, function(checked)
            gcd.HideOutOfCombat = checked
            ApplyGCDSettings()
        end)
    row10a:AddWidget(hideOOCCheck, 0.5)
    table_insert(allWidgets, hideOOCCheck)
    table_insert(gcdWidgets, hideOOCCheck)
    card6:AddRow(row10a, 37)

    yOffset = yOffset + card6:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 7: GCD Ring Texture (only for separate mode)
    ----------------------------------------------------------------
    local card7 = GUIFrame:CreateCard(scrollChild, "GCD Ring Texture", yOffset)
    table_insert(allWidgets, card7)
    table_insert(gcdWidgets, card7)
    table_insert(gcdSeparateWidgets, card7)
    -- Create texture selector row for GCD
    local row7 = GUIFrame:CreateRow(card7.content, 71)

    -- Get GCD ring color for texture preview (uses ring color, not swipe)
    local function GetGCDEffectiveColor()
        local colorMode = gcd.RingColorMode or "custom"
        return NRSKNUI:GetAccentColor(colorMode, gcd.RingColor)
    end

    -- GCD Texture selector
    gcdTextureSelector = CreateTextureSelector(
        row7,
        CC.GCDRingTextures,
        CC.GCDRingTextureOrder,
        gcd.Texture or "Circle 1",
        GetGCDEffectiveColor,
        function(textureName)
            gcd.Texture = textureName
            ApplyGCDSettings()
        end
    )
    gcdTextureSelector:SetPoint("TOPLEFT", row7, "TOPLEFT", 0, 3)
    gcdTextureSelector:SetPoint("TOPRIGHT", row7, "TOPRIGHT", 0, 0)
    card7:AddRow(row7, 71)

    yOffset = yOffset + card7:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 8: GCD Ring Background Color (for separate mode)
    ----------------------------------------------------------------
    local card8 = GUIFrame:CreateCard(scrollChild, "GCD Ring Background", yOffset)
    table_insert(allWidgets, card8)
    table_insert(gcdWidgets, card8)
    table_insert(gcdSeparateWidgets, card8)

    -- Size slider (only for separate mode)
    local row6b = GUIFrame:CreateRow(card8.content, 37)
    local gcdSizeSlider = GUIFrame:CreateSlider(row6b, "Ring Size", 10, 150, 1, gcd.Size or 60, 60,
        function(val)
            gcd.Size = val
            ApplyGCDSettings()
        end)
    row6b:AddWidget(gcdSizeSlider, 1)
    table_insert(allWidgets, gcdSizeSlider)
    table_insert(gcdWidgets, gcdSizeSlider)
    table_insert(gcdSeparateWidgets, gcdSizeSlider)
    card8:AddRow(row6b, 37)

    -- GCD Ring Color Mode dropdown
    local row8a = GUIFrame:CreateRow(card8.content, 37)
    local gcdRingColorModeDropdown = GUIFrame:CreateDropdown(row8a, "Color Mode", NRSKNUI.ColorModeOptions,
        gcd.RingColorMode or "theme", 70,
        function(key)
            gcd.RingColorMode = key
            ApplyGCDSettings()
            if gcdTextureSelector and gcdTextureSelector.RefreshColors then
                gcdTextureSelector:RefreshColors()
            end
            UpdateAllWidgetStates()
        end)
    row8a:AddWidget(gcdRingColorModeDropdown, 0.5)
    table_insert(allWidgets, gcdRingColorModeDropdown)
    table_insert(gcdWidgets, gcdRingColorModeDropdown)
    table_insert(gcdSeparateWidgets, gcdRingColorModeDropdown)

    -- GCD Ring Color picker (only applies when RingColorMode = "custom")
    local gcdRingColorPicker = GUIFrame:CreateColorPicker(row8a, "Custom Color",
        gcd.RingColor or { 1, 1, 1, 1 },
        function(r, g, b, a)
            gcd.RingColor = { r, g, b, a }
            ApplyGCDSettings()
            if gcdTextureSelector and gcdTextureSelector.RefreshColors then
                gcdTextureSelector:RefreshColors()
            end
        end)
    row8a:AddWidget(gcdRingColorPicker, 0.5)
    table_insert(allWidgets, gcdRingColorPicker)
    table_insert(gcdWidgets, gcdRingColorPicker)
    table_insert(gcdSeparateWidgets, gcdRingColorPicker)
    table_insert(gcdRingColorModeWidgets, gcdRingColorPicker)
    card8:AddRow(row8a, 37)

    yOffset = yOffset + card8:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 9)
    return yOffset
end)

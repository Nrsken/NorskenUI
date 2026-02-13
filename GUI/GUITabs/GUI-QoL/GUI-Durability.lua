-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.LSM
local DUR = NRSKNUI.Addon:GetModule("Durability", true)

-- Localization Setup
local table_insert = table.insert
local ipairs, pairs = ipairs, pairs
local wipe = wipe
local CreateFrame = CreateFrame

-- Store current sub-tab
local currentSubTab = "general"
-- Cached tab bar reference (persists across content rebuilds)
local cachedTabButtons = nil

-- Sub-tab definitions
local SUB_TABS = {
    { id = "general",     text = "General" },
    { id = "datatext",    text = "Data Text" },
    { id = "warningtext", text = "Repair Now Text" },
}

-- Tab bar height constant
local TAB_BAR_HEIGHT = 28

-- Track widgets for enable/disable logic
local allWidgets = {} -- All widgets (except main toggle)
local customColorWidgets = {}
local warningWidgets = {}
local textWidgets = {}

-- Apply Durability settings
local function ApplySettings()
    if DUR then
        DUR:UpdateWarning()
        DUR:UpdateText()
    end
end

local function ApplyFonts()
    if DUR then
        DUR:UpdateFonts()
    end
end

-- Helper to apply new state
local function ApplyDurabilityState(enabled)
    if not DUR then return end
    DUR.db.Enabled = enabled
    if enabled then
        NRSKNUI.Addon:EnableModule("Durability")
    else
        NRSKNUI.Addon:DisableModule("Durability")
    end
end

-- Comprehensive widget state update
local function UpdateAllWidgetStates()
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.Durability
    if not db then return end
    local mainEnabled = db.Enabled ~= false
    local warningEnabled = db.WarningText and db.WarningText.Enabled ~= false
    local textEnabled = db.Text and db.Text.Enabled ~= false
    local ccEnabled = textEnabled and db.Text.UseStatusColor == false

    -- Apply main enable state to ALL widgets
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

        for _, widget in ipairs(warningWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(warningEnabled)
            end
        end

        for _, widget in ipairs(textWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(textEnabled)
            end
        end
    end
end

-- Sub tab 1, general settings
local function RenderGeneralTab(scrollChild, yOffset, activeCards)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.Durability
    if not db then return yOffset end

    ----------------------------------------------------------------
    -- Card 1: Durability Util Overview
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Durability Util", yOffset)
    table_insert(activeCards, card1)

    -- Enable Checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 40)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Durability Util", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyDurabilityState(checked)
            UpdateAllWidgetStates()
        end,
        true,
        "Durability Util",
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
    local enabledWarningText = GUIFrame:CreateCheckbox(row1b, "Enable Repair Now Warning",
        db.WarningText.Enabled ~= false,
        function(checked)
            db.WarningText.Enabled = checked
            ApplySettings()
        end)
    row1b:AddWidget(enabledWarningText, 0.5)
    table_insert(allWidgets, enabledWarningText)

    local enabledText = GUIFrame:CreateCheckbox(row1b, "Enable Data Text", db.Text.Enabled ~= false,
        function(checked)
            db.Text.Enabled = checked
            ApplySettings()
        end)
    row1b:AddWidget(enabledText, 0.5)
    table_insert(allWidgets, enabledText)
    card1:AddRow(row1b, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Font Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "General Font Settings", yOffset)
    table_insert(allWidgets, card2)
    table_insert(activeCards, card2)

    -- Font lookup
    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do fontList[name] = name end
    else
        fontList["Friz Quadrata TT"] = "Friz Quadrata TT"
    end

    -- Font Face and Outline Dropdowns
    local row2 = GUIFrame:CreateRow(card2.content, 40)
    local fontDropdown = GUIFrame:CreateDropdown(row2, "Font", fontList, db.FontFace or "Friz Quadrata TT", 30,
        function(key)
            db.FontFace = key
            ApplyFonts()
        end)
    row2:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)

    local outlineList = {
        { key = "NONE", text = "None" },
        { key = "OUTLINE", text = "Outline" },
        { key = "THICKOUTLINE", text = "Thick" },
        { key = "SOFTOUTLINE", text = "Soft" },
    }
    local outlineDropdown = GUIFrame:CreateDropdown(row2, "Outline", outlineList, db.FontOutline or "OUTLINE", 45,
        function(key)
            db.FontOutline = key
            ApplyFonts()
        end)
    row2:AddWidget(outlineDropdown, 0.5)
    table_insert(allWidgets, outlineDropdown)
    card2:AddRow(row2, 40)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    yOffset = yOffset - (Theme.paddingSmall)
    UpdateAllWidgetStates()
    return yOffset
end

-- Sub tab 2, data text
local function RenderDataTextTab(scrollChild, yOffset, activeCards)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.Durability
    if not db then return yOffset end
    local DT = db.Text

    ----------------------------------------------------------------
    -- Card 1: General Settings
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "General Settings", yOffset)
    table_insert(activeCards, card1)
    table_insert(allWidgets, card1)
    table_insert(textWidgets, card1)

    local red = NRSKNUI:ColorText("25%", { 1, 0, 0 })
    local orange = NRSKNUI:ColorText("50%", { 1, 0.42, 0 })
    local yellow = NRSKNUI:ColorText("75%", { 1, 0.82, 0 })
    local green = NRSKNUI:ColorText("100%", { 0, 1, 0 })
    local statusColorEx = "Use Status Color: " .. red .. " / " .. orange .. " / " .. yellow .. " / " .. green

    -- Use status coloring
    local row1 = GUIFrame:CreateRow(card1.content, 40)
    local statusColor = GUIFrame:CreateCheckbox(row1, statusColorEx, DT.UseStatusColor ~= false,
        function(checked)
            DT.UseStatusColor = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row1:AddWidget(statusColor, 0.5)
    table_insert(allWidgets, statusColor)
    table_insert(textWidgets, statusColor)

    local DTcolor = GUIFrame:CreateColorPicker(row1, "Static Color", DT.Color,
        function(r, g, b, a)
            DT.Color = { r, g, b, a }
            ApplySettings()
        end)
    row1:AddWidget(DTcolor, 0.5)
    table_insert(allWidgets, DTcolor)
    table_insert(customColorWidgets, DTcolor)
    card1:AddRow(row1, 40)

    local row1a = GUIFrame:CreateRow(card1.content, 39)
    local DurText = GUIFrame:CreateEditBox(row1a, "Prefix", DT.DurText, function(val)
        DT.DurText = val
        ApplySettings()
    end)
    row1a:AddWidget(DurText, 0.5)
    table_insert(allWidgets, DurText)
    table_insert(textWidgets, DurText)

    local Durcolor = GUIFrame:CreateColorPicker(row1a, "Prefix Color", DT.DurColor,
        function(r, g, b, a)
            DT.DurColor = { r, g, b, a }
            ApplySettings()
        end)
    row1a:AddWidget(Durcolor, 0.5)
    table_insert(allWidgets, Durcolor)
    table_insert(textWidgets, Durcolor)
    card1:AddRow(row1a, 39)

    -- Separator
    local row1sep = GUIFrame:CreateRow(card1.content, 8)
    local sepCBCard = GUIFrame:CreateSeparator(row1sep)
    row1sep:AddWidget(sepCBCard, 1)
    table_insert(allWidgets, sepCBCard)
    table_insert(textWidgets, sepCBCard)
    card1:AddRow(row1sep, 8)

    -- Font Size
    local row2 = GUIFrame:CreateRow(card1.content, 36)
    local fontSizeSlider = GUIFrame:CreateSlider(row2, "Font Size", 6, 80, 1, DT.FontSize, 60,
        function(val)
            DT.FontSize = val
            ApplyFonts()
        end)
    row2:AddWidget(fontSizeSlider, 1)
    table_insert(allWidgets, fontSizeSlider)
    table_insert(textWidgets, fontSizeSlider)
    card1:AddRow(row2, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Position Settings (using reusable position card)
    ----------------------------------------------------------------
    local card2, newOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db.Text,
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
    table_insert(textWidgets, card2)
    yOffset = newOffset

    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall)
    return yOffset
end

-- Sub tab 3, warning text
local function RenderWarningTextTab(scrollChild, yOffset, activeCards)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.Durability
    if not db then return yOffset end
    local WT = db.WarningText

    ----------------------------------------------------------------
    -- Card 1: General Settings
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "General Settings", yOffset)
    table_insert(activeCards, card1)
    table_insert(allWidgets, card1)
    table_insert(warningWidgets, card1)

    -- Use status coloring
    local row1 = GUIFrame:CreateRow(card1.content, 40)
    local WarningText = GUIFrame:CreateEditBox(row1, "Low Durability Text", WT.WarningText, function(val)
        WT.WarningText = val
        ApplySettings()
    end)
    row1:AddWidget(WarningText, 0.5)
    table_insert(allWidgets, WarningText)
    table_insert(warningWidgets, WarningText)

    local WTcolor = GUIFrame:CreateColorPicker(row1, "Color", WT.WarningColor or { 0, 0, 0, 0.6 },
        function(r, g, b, a)
            WT.WarningColor = { r, g, b, a }
            ApplySettings()
        end)
    row1:AddWidget(WTcolor, 0.5)
    table_insert(allWidgets, WTcolor)
    table_insert(warningWidgets, WTcolor)
    card1:AddRow(row1, 40)

    local row1a = GUIFrame:CreateRow(card1.content, 40)
    local ShowPercent = GUIFrame:CreateSlider(row1a, "|cff4dff00Out of Combat|r Durability % Trigger", 1, 100, 1, WT.ShowPercent, 60,
        function(val)
            WT.ShowPercent = val
            ApplyFonts()
        end)
    row1a:AddWidget(ShowPercent, 0.5)
    table_insert(allWidgets, ShowPercent)
    table_insert(warningWidgets, ShowPercent)

    local CombatShowPercent = GUIFrame:CreateSlider(row1a, "|cffff0000In Combat|r Durability % Trigger", 0, 100, 1, WT.CombatShowPercent, 60,
        function(val)
            WT.CombatShowPercent = val
            ApplyFonts()
        end)
    row1a:AddWidget(CombatShowPercent, 0.5)
    table_insert(allWidgets, CombatShowPercent)
    table_insert(warningWidgets, CombatShowPercent)
    card1:AddRow(row1a, 40)

    -- Separator
    local row1sep = GUIFrame:CreateRow(card1.content, 8)
    local sepCBCard = GUIFrame:CreateSeparator(row1sep)
    row1sep:AddWidget(sepCBCard, 1)
    table_insert(allWidgets, sepCBCard)
    table_insert(warningWidgets, sepCBCard)
    card1:AddRow(row1sep, 8)

    -- Font Size
    local row2 = GUIFrame:CreateRow(card1.content, 36)
    local fontSizeSlider = GUIFrame:CreateSlider(row2, "Font Size", 6, 80, 1, WT.FontSize, 60,
        function(val)
            WT.FontSize = val
            ApplyFonts()
        end)
    row2:AddWidget(fontSizeSlider, 1)
    table_insert(allWidgets, fontSizeSlider)
    table_insert(warningWidgets, fontSizeSlider)
    card1:AddRow(row2, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Position Settings (using reusable position card)
    ----------------------------------------------------------------
    local card2, newOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db.WarningText,
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
    -- Add position card widgets to allWidgets for enable/disable
    if card2.positionWidgets then
        for _, widget in ipairs(card2.positionWidgets) do
            table_insert(allWidgets, widget)
        end
    end
    table_insert(allWidgets, card2)
    table_insert(warningWidgets, card2)
    yOffset = newOffset

    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall)
    return yOffset
end

----------------------------------------------------------------
-- Create Durability Panel
----------------------------------------------------------------
local function CreateDurabilityPanel(container)
    -- Full-size frame to take over content area
    local panel = CreateFrame("Frame", nil, container)
    panel:SetAllPoints()

    -- Tab bar at top
    local tabBar = CreateFrame("Frame", nil, panel)
    tabBar:SetHeight(TAB_BAR_HEIGHT)
    tabBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    tabBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)

    -- Tab bar background
    local tabBarBg = tabBar:CreateTexture(nil, "BACKGROUND")
    tabBarBg:SetAllPoints()
    tabBarBg:SetColorTexture(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], 1)

    -- Tab bar bottom border
    local tabBarBorder = tabBar:CreateTexture(nil, "ARTWORK")
    tabBarBorder:SetHeight(1)
    tabBarBorder:SetPoint("BOTTOMLEFT", tabBar, "BOTTOMLEFT", 0, 0)
    tabBarBorder:SetPoint("BOTTOMRIGHT", tabBar, "BOTTOMRIGHT", 0, 0)
    tabBarBorder:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    -- Scroll frame below tab bar
    local scrollbarWidth = Theme.scrollbarWidth or 16
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -1)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

    -- Style scrollbar
    if scrollFrame.ScrollBar then
        local sb = scrollFrame.ScrollBar
        sb:ClearAllPoints()
        sb:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -(TAB_BAR_HEIGHT + Theme.paddingSmall + 13))
        sb:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -3, Theme.paddingSmall + 13)
        sb:SetWidth(scrollbarWidth - 4)

        -- Hide default scrollbar decorations
        if sb.Background then sb.Background:Hide() end
        if sb.Top then sb.Top:Hide() end
        if sb.Middle then sb.Middle:Hide() end
        if sb.Bottom then sb.Bottom:Hide() end
        if sb.trackBG then sb.trackBG:Hide() end
        if sb.ScrollUpButton then sb.ScrollUpButton:Hide() end
        if sb.ScrollDownButton then sb.ScrollDownButton:Hide() end
        -- Hide thumb when not needed
        sb:SetAlpha(0)

        -- Force scroll values to snap to whole screen pixels (in steps of 3px)
        -- This prevents texture jittering from fractional pixel positions
        local isSnapping = false
        local PIXEL_STEP = 8 / 15
        sb:HookScript("OnValueChanged", function(self, value)
            if isSnapping then return end
            local scale = scrollFrame:GetEffectiveScale()
            local screenPixels = value * scale
            local snappedPixels = math.floor(screenPixels / PIXEL_STEP + 0.5) * PIXEL_STEP
            local snappedValue = snappedPixels / scale
            if math.abs(value - snappedValue) > 0.001 then
                isSnapping = true
                self:SetValue(snappedValue)
                isSnapping = false
            end
        end)
    end

    -- Scroll child (dynamic width based on scrollbar visibility)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    -- Track scrollbar visibility state
    local scrollbarVisible = false
    local baseWidth = Theme.contentWidth

    -- Update scrollChild width based on scrollbar visibility
    local function UpdateScrollChildWidth()
        if scrollbarVisible then
            scrollChild:SetWidth(baseWidth - scrollbarWidth)
        else
            scrollChild:SetWidth(baseWidth)
        end
    end

    -- Show/hide scrollbar and adjust content width based on content height
    local function UpdateScrollBarVisibility()
        if scrollFrame.ScrollBar then
            local contentHeight = scrollChild:GetHeight()
            local frameHeight = scrollFrame:GetHeight()
            local needsScrollbar = contentHeight > frameHeight

            -- Always update visibility, don't track state (fixes edge cases)
            scrollbarVisible = needsScrollbar
            scrollFrame.ScrollBar:SetAlpha(needsScrollbar and 1 or 0)
            UpdateScrollChildWidth()
        end
    end

    -- Initial width setup
    UpdateScrollChildWidth()

    -- Hook events for visibility updates
    scrollFrame:HookScript("OnScrollRangeChanged", UpdateScrollBarVisibility)
    scrollChild:HookScript("OnSizeChanged", UpdateScrollBarVisibility)
    scrollFrame:HookScript("OnSizeChanged", UpdateScrollBarVisibility)

    -- Also update on show (in case content changed while hidden)
    scrollFrame:HookScript("OnShow", function()
        C_Timer.After(0, UpdateScrollBarVisibility)
    end)

    -- Track cards for width updates
    local activeCards = {}

    -- Update all card widths when scrollChild resizes
    local function UpdateCardWidths()
        local newWidth = scrollChild:GetWidth()
        for _, card in ipairs(activeCards) do
            if card and card.SetWidth then
                card:SetWidth(newWidth)
            end
        end
    end

    -- Hook scrollChild resize to update card widths
    scrollChild:HookScript("OnSizeChanged", function(self, width, height)
        UpdateCardWidths()
    end)

    -- Render content into scroll child
    local function RenderContentIntoScrollChild(tabId)
        -- Clear active cards tracking
        wipe(activeCards)

        -- Clear all existing children
        for _, child in ipairs({ scrollChild:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end

        -- Clear any regions (font strings, textures)
        for _, region in ipairs({ scrollChild:GetRegions() }) do
            if region:GetObjectType() == "FontString" or region:GetObjectType() == "Texture" then
                region:Hide()
            end
        end

        local yOffset = Theme.paddingMedium

        -- Render selected tab content (pass activeCards for tracking)
        if tabId == "general" then
            yOffset = RenderGeneralTab(scrollChild, yOffset, activeCards)
        elseif tabId == "datatext" then
            yOffset = RenderDataTextTab(scrollChild, yOffset, activeCards)
        elseif tabId == "warningtext" then
            yOffset = RenderWarningTextTab(scrollChild, yOffset, activeCards)
        end

        -- Update scroll child height
        scrollChild:SetHeight(yOffset + Theme.paddingLarge)
    end

    -- Helper to update tab button visuals
    local function UpdateTabVisuals(buttons, selectedId)
        for _, btn in ipairs(buttons) do
            if btn.tabId == selectedId then
                btn.label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                btn.underline:Show()
                btn.selectedOverlay:Show()
            else
                btn.label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
                btn.underline:Hide()
                btn.selectedOverlay:Hide()
            end
        end
    end

    -- Create tab buttons
    local tabButtons = {}
    local minPadding = Theme.paddingMedium * 2
    local totalTextWidth = 0

    for i, tabDef in ipairs(SUB_TABS) do
        local btn = CreateFrame("Button", nil, tabBar)
        btn:SetHeight(TAB_BAR_HEIGHT)
        btn.tabId = tabDef.id
        btn.tabIndex = i

        -- Background (for hover)
        local hoverBg = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
        hoverBg:SetAllPoints()
        hoverBg:SetColorTexture(1, 1, 1, 0.05)
        hoverBg:Hide()
        btn.hoverBg = hoverBg

        -- Selected overlay
        local selectedOverlay = btn:CreateTexture(nil, "BACKGROUND", nil, 2)
        selectedOverlay:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        selectedOverlay:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        selectedOverlay:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.1)
        selectedOverlay:Hide()
        btn.selectedOverlay = selectedOverlay

        -- Label
        local label = btn:CreateFontString(nil, "OVERLAY")
        label:SetPoint("CENTER", btn, "CENTER", 0, 0)
        if NRSKNUI.ApplyThemeFont then
            NRSKNUI:ApplyThemeFont(label, "small")
        else
            label:SetFontObject("GameFontNormalSmall")
        end
        label:SetText(tabDef.text)
        label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        btn.label = label

        -- Measure text width for proportional layout
        local textWidth = label:GetStringWidth()
        btn.textWidth = textWidth
        totalTextWidth = totalTextWidth + textWidth

        -- Underline (selected indicator)
        local underline = btn:CreateTexture(nil, "OVERLAY")
        underline:SetHeight(2)
        underline:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
        underline:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        underline:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        underline:Hide()
        btn.underline = underline

        -- Mouse events
        btn:SetScript("OnEnter", function(self)
            if currentSubTab ~= self.tabId then
                self.hoverBg:Show()
            end
        end)

        btn:SetScript("OnLeave", function(self)
            self.hoverBg:Hide()
        end)

        btn:SetScript("OnClick", function(self)
            if currentSubTab ~= self.tabId then
                currentSubTab = self.tabId
                UpdateTabVisuals(cachedTabButtons, currentSubTab)
                RenderContentIntoScrollChild(currentSubTab)
            end
        end)

        table_insert(tabButtons, btn)
    end

    -- Cache tab buttons for callbacks
    cachedTabButtons = tabButtons

    -- Function to layout tabs proportionally based on text width
    local function LayoutTabs(barWidth)
        if barWidth <= 0 then return end

        local numTabs = #tabButtons
        local totalMinWidth = totalTextWidth + (minPadding * numTabs)

        -- Calculate extra space to distribute
        local extraSpace = math.max(0, barWidth - totalMinWidth)
        local extraPerTab = extraSpace / numTabs

        local xOffset = 0
        for _, btn in ipairs(tabButtons) do
            local tabWidth = btn.textWidth + minPadding + extraPerTab

            btn:ClearAllPoints()
            btn:SetPoint("TOP", tabBar, "TOP", 0, 0)
            btn:SetPoint("BOTTOM", tabBar, "BOTTOM", 0, 0)
            btn:SetPoint("LEFT", tabBar, "LEFT", xOffset, 0)
            btn:SetWidth(tabWidth)

            xOffset = xOffset + tabWidth
        end
    end

    -- Initial layout
    LayoutTabs(tabBar:GetWidth())

    -- Update tab positions when tabBar size changes
    tabBar:SetScript("OnSizeChanged", function(self, width, height)
        LayoutTabs(width)
    end)

    -- Initial tab selection and visuals
    UpdateTabVisuals(tabButtons, currentSubTab)

    -- Render initial content
    RenderContentIntoScrollChild(currentSubTab)

    UpdateAllWidgetStates()
    return panel
end

----------------------------------------------------------------
-- Register Panel (full control of content area)
----------------------------------------------------------------
GUIFrame:RegisterPanel("Durability", CreateDurabilityPanel)

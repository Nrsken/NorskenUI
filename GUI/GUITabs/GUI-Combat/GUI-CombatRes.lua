-- NorskenUI namespace
local _, NRSKNUI = ...

-- Locals
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local table_insert = table.insert
local table_sort = table.sort
local wipe = wipe

-- Store current sub-tab
local currentSubTab = "general"

-- Cached tab bar reference (persists across content rebuilds)
local cachedTabBar = nil
local cachedTabButtons = nil

local allWidgets = {}

local sepShadowWidgets = {}
local sepShadowWidgetsToggle = {}

local timeShadowWidgets = {}
local timeShadowWidgetsToggle = {}

local chargeShadowWidgets = {}
local chargeShadowWidgetsToggle = {}

-- Sub-tab definitions
local SUB_TABS = {
    { id = "general",  text = "General" },
    { id = "textMode", text = "Text Mode" },
    { id = "iconMode", text = "Icon Mode" },
}

-- Tab bar height constant
local TAB_BAR_HEIGHT = 28

-- Display Mode options
local DISPLAY_MODE_OPTIONS = {
    { key = "text", text = "Text Mode" },
    { key = "icon", text = "Icon Mode" },
}

-- Load database settings
local function GetBattleResDB()
    if not NRSKNUI.db or not NRSKNUI.db.profile then return nil end
    return NRSKNUI.db and NRSKNUI.db.profile.BattleRes
end

-- Helper to get Combat Res module
local function GetCombatResModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("CombatRes", true)
    end
    return nil
end

-- Helper to apply settings
local function ApplySettings()
    local CR = GetCombatResModule()
    if CR and CR.ApplySettings then CR:ApplySettings() end
end

-- Comprehensive widget state update
local function UpdateAllWidgetStates()
    local db = GetBattleResDB()
    if not db then return end
    local tm = db.TextMode or {}
    local mainEnabled = db.Enabled ~= false

    -- Check if using soft outline (disables all shadow settings)
    local usingSoftOutline = tm.FontOutline == "SOFTOUTLINE"

    -- Apply main enable state to ALL widgets
    for _, widget in ipairs(allWidgets) do
        if widget.SetEnabled then
            widget:SetEnabled(mainEnabled)
        end
    end

    -- Second: Apply conditional states (only if main is enabled, otherwise already disabled)
    if mainEnabled then
        -- When using SOFTOUTLINE, disable all shadow widgets
        local shadowWidgetsEnabled = not usingSoftOutline

        -- Separator Text Shadow
        for _, widget in ipairs(sepShadowWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(shadowWidgetsEnabled and tm.SeparatorShadow and tm.SeparatorShadow.Enabled)
            end
        end
        for _, widget in ipairs(sepShadowWidgetsToggle) do
            if widget.SetEnabled then
                widget:SetEnabled(shadowWidgetsEnabled)
            end
        end
        -- Timer Text Shadow
        for _, widget in ipairs(timeShadowWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(shadowWidgetsEnabled and tm.TimerShadow and tm.TimerShadow.Enabled)
            end
        end
        for _, widget in ipairs(timeShadowWidgetsToggle) do
            if widget.SetEnabled then
                widget:SetEnabled(shadowWidgetsEnabled)
            end
        end
        -- Charge Text Shadow
        for _, widget in ipairs(chargeShadowWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(shadowWidgetsEnabled and tm.ChargeShadow and tm.ChargeShadow.Enabled)
            end
        end
        for _, widget in ipairs(chargeShadowWidgetsToggle) do
            if widget.SetEnabled then
                widget:SetEnabled(shadowWidgetsEnabled)
            end
        end
    end
end

-- Sub tab 1, general settings
local function RenderGeneralTab(scrollChild, yOffset, activeCards)
    local db = GetBattleResDB()
    if not db then return yOffset end

    ----------------------------------------------------------------
    -- Card 1: General Settings
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Battle Res Tracker", yOffset)
    table_insert(activeCards, card1)

    -- Row 1: Enable checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 40)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Combat Res Tracker", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end,
        true,
        "Combat Res Tracker",
        "On",
        "Off"
    )
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, 40)

    -- Displaymode
    local row3 = GUIFrame:CreateRow(card1.content, 37)
    local displayModeDropdown = GUIFrame:CreateDropdown(row3, "Display Mode", DISPLAY_MODE_OPTIONS,
        db.DisplayMode or "icon", 80,
        function(key)
            db.DisplayMode = key
            ApplySettings()
        end)
    row3:AddWidget(displayModeDropdown, 1)
    table_insert(allWidgets, displayModeDropdown)
    card1:AddRow(row3, 37)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Position Settings (using reusable position card)
    ----------------------------------------------------------------
    local positionCard
    positionCard, yOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        title = "Position Settings",
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
            selfPoint = "CENTER",
            anchorPoint = "CENTER",
            xOffset = 0,
            yOffset = -200,
            strata = "HIGH",
        },
        showAnchorFrameType = true,
        showStrata = true,
        sliderRange = { -2000, 2000 },
        onChangeCallback = ApplySettings,
    })
    table_insert(activeCards, positionCard)

    -- Add position card widgets to dependent widgets for enable/disable
    if positionCard.positionWidgets then
        for _, widget in ipairs(positionCard.positionWidgets) do
            table_insert(allWidgets, widget)
        end
    end
    table_insert(allWidgets, positionCard)

    yOffset = yOffset - (Theme.paddingSmall * 1)
    UpdateAllWidgetStates()
    return yOffset
end

----------------------------------------------------------------
-- Sub-Tab: Text Mode
----------------------------------------------------------------
local function RenderTextModeTab(scrollChild, yOffset, activeCards)
    local db = GetBattleResDB()
    if not db then return yOffset end

    -- Ensure TextMode table exists
    db.TextMode = db.TextMode or {}
    local tm = db.TextMode

    -- Ensure nested tables exist
    tm.SeparatorShadow = tm.SeparatorShadow or {}
    tm.TimerShadow = tm.TimerShadow or {}
    tm.ChargeShadow = tm.ChargeShadow or {}
    tm.Backdrop = tm.Backdrop or {}

    -- Build font list
    local LSM = NRSKNUI.LSM or LibStub("LibSharedMedia-3.0", true)
    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do
            table_insert(fontList, { key = name, text = name })
        end
        table_sort(fontList, function(a, b) return a.text < b.text end)
    else
        table_insert(fontList, { key = "Friz Quadrata TT", text = "Friz Quadrata TT" })
    end

    local outlineList = {
        { key = "NONE",         text = "None" },
        { key = "OUTLINE",      text = "Outline" },
        { key = "THICKOUTLINE", text = "Thick" },
        { key = "SOFTOUTLINE",  text = "Soft" },
    }

    local growthList = {
        { key = "LEFT",  text = "Left" },
        { key = "RIGHT", text = "Right" },
    }

    ----------------------------------------------------------------
    -- Card 1: Font Settings
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Font Settings", yOffset)
    table_insert(activeCards, card1)
    table_insert(allWidgets, card1)

    -- Row 1: Font and Outline
    local row1 = GUIFrame:CreateRow(card1.content, 40)
    local fontDropdown = GUIFrame:CreateDropdown(row1, "Font", fontList, tm.FontFace or "Friz Quadrata TT", 30,
        function(key)
            tm.FontFace = key
            ApplySettings()
        end)
    row1:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)

    local outlineDropdown = GUIFrame:CreateDropdown(row1, "Outline", outlineList, tm.FontOutline or "OUTLINE", 45,
        function(key)
            tm.FontOutline = key
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row1:AddWidget(outlineDropdown, 0.5)
    table_insert(allWidgets, outlineDropdown)
    card1:AddRow(row1, 40)

    -- Row 2: Font Size and Text Spacing
    local row2 = GUIFrame:CreateRow(card1.content, 40)
    local fontSizeSlider = GUIFrame:CreateSlider(row2, "Font Size", 8, 36, 1, tm.FontSize or 18, 60,
        function(val)
            tm.FontSize = val
            ApplySettings()
        end)
    row2:AddWidget(fontSizeSlider, 0.5)
    table_insert(allWidgets, fontSizeSlider)

    local spacingSlider = GUIFrame:CreateSlider(row2, "Text Spacing", 0, 20, 1, tm.TextSpacing or 4, 80,
        function(val)
            tm.TextSpacing = val
            ApplySettings()
        end)
    row2:AddWidget(spacingSlider, 0.5)
    table_insert(allWidgets, spacingSlider)
    card1:AddRow(row2, 40)

    -- Row 3: Growth Direction
    local row3 = GUIFrame:CreateRow(card1.content, 40)
    local growthDropdown = GUIFrame:CreateDropdown(row3, "Growth Direction", growthList,
        tm.GrowthDirection or "RIGHT", 100,
        function(key)
            tm.GrowthDirection = key
            ApplySettings()
        end)
    row3:AddWidget(growthDropdown, 1)
    table_insert(allWidgets, growthDropdown)
    card1:AddRow(row3, 40)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Separator Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Separator", yOffset)
    table_insert(activeCards, card2)
    table_insert(allWidgets, card2)

    -- Row 1: Separator Text
    local row2a = GUIFrame:CreateRow(card2.content, 39)
    local sepInput = GUIFrame:CreateEditBox(row2a, "Separator Text", tm.Separator or "»", function(val)
        tm.Separator = val
        ApplySettings()
    end)
    row2a:AddWidget(sepInput, 0.5)
    table_insert(allWidgets, sepInput)

    local sepChargeInput = GUIFrame:CreateEditBox(row2a, "Separator Text", tm.SeparatorCharges or "CR »", function(val)
        tm.SeparatorCharges = val
        ApplySettings()
    end)
    row2a:AddWidget(sepChargeInput, 0.5)
    table_insert(allWidgets, sepChargeInput)
    card2:AddRow(row2a, 39)

    -- Row 2: Separator Color
    local row3a = GUIFrame:CreateRow(card2.content, 39)
    local sepColor = GUIFrame:CreateColorPicker(row3a, "Separator Color", tm.SeparatorColor or { 1, 1, 1, 1 },
        function(r, g, b, a)
            tm.SeparatorColor = { r, g, b, a }
            ApplySettings()
        end)
    row3a:AddWidget(sepColor, 1)
    table_insert(allWidgets, sepColor)
    card2:AddRow(row3a, 39)

    -- Separator
    local row2sep = GUIFrame:CreateRow(card2.content, 8)
    local sepBgCard = GUIFrame:CreateSeparator(row2sep)
    row2sep:AddWidget(sepBgCard, 1)
    table_insert(allWidgets, sepBgCard)
    card2:AddRow(row2sep, 8)

    -- Row 2: Shadow Color and Offsets (if enabled)
    local row2c = GUIFrame:CreateRow(card2.content, 39)
    local sepShadowCheck = GUIFrame:CreateCheckbox(row2c, "Enable Shadow", tm.SeparatorShadow.Enabled == true,
        function(checked)
            tm.SeparatorShadow.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row2c:AddWidget(sepShadowCheck, 0.5)
    table_insert(allWidgets, sepShadowCheck)
    table_insert(sepShadowWidgetsToggle, sepShadowCheck)

    -- Row 4: Shadow Color
    local sepShadowColor = GUIFrame:CreateColorPicker(row2c, "Shadow Color",
        tm.SeparatorShadow.Color or { 0, 0, 0, 1 },
        function(r, g, b, a)
            tm.SeparatorShadow.Color = { r, g, b, a }
            ApplySettings()
        end)
    row2c:AddWidget(sepShadowColor, 0.5)
    table_insert(allWidgets, sepShadowColor)
    table_insert(sepShadowWidgets, sepShadowColor)
    card2:AddRow(row2c, 39)

    -- Only show offsets if NOT using soft outline
    local row2d = GUIFrame:CreateRow(card2.content, 39)
    local sepShadowX = GUIFrame:CreateSlider(row2d, "Shadow X Offset", -5, 5, 1,
        tm.SeparatorShadow.OffsetX or 0, 20,
        function(val)
            tm.SeparatorShadow.OffsetX = val
            ApplySettings()
        end)
    row2d:AddWidget(sepShadowX, 0.5)
    table_insert(allWidgets, sepShadowX)
    table_insert(sepShadowWidgets, sepShadowX)

    local sepShadowY = GUIFrame:CreateSlider(row2d, "Shadow Y Offset", -5, 5, 1,
        tm.SeparatorShadow.OffsetY or 0, 20,
        function(val)
            tm.SeparatorShadow.OffsetY = val
            ApplySettings()
        end)
    row2d:AddWidget(sepShadowY, 0.5)
    table_insert(allWidgets, sepShadowY)
    table_insert(sepShadowWidgets, sepShadowY)
    card2:AddRow(row2d, 39)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Timer Settings
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Timer Text", yOffset)
    table_insert(activeCards, card3)
    table_insert(allWidgets, card3)

    -- Row 1: Timer Color
    local row3atc = GUIFrame:CreateRow(card3.content, 37)
    local timerColor = GUIFrame:CreateColorPicker(row3atc, "Timer Text Color", tm.TimerColor or { 1, 1, 1, 1 },
        function(r, g, b, a)
            tm.TimerColor = { r, g, b, a }
            ApplySettings()
        end)
    row3atc:AddWidget(timerColor, 1)
    table_insert(allWidgets, timerColor)
    card3:AddRow(row3atc, 37)

    -- Separator
    local row1TimSep = GUIFrame:CreateRow(card3.content, 8)
    local sepTimCard = GUIFrame:CreateSeparator(row1TimSep)
    row1TimSep:AddWidget(sepTimCard, 1)
    table_insert(allWidgets, sepTimCard)
    card3:AddRow(row1TimSep, 8)

    -- Row 2: Shadow Enable
    local row3b = GUIFrame:CreateRow(card3.content, 40)
    local timerShadowCheck = GUIFrame:CreateCheckbox(row3b, "Use Shadow", tm.TimerShadow.Enabled == true,
        function(checked)
            tm.TimerShadow.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row3b:AddWidget(timerShadowCheck, 0.5)
    table_insert(allWidgets, timerShadowCheck)
    table_insert(timeShadowWidgetsToggle, timerShadowCheck)

    local timerShadowColor = GUIFrame:CreateColorPicker(row3b, "Shadow Color",
        tm.TimerShadow.Color or { 0, 0, 0, 1 },
        function(r, g, b, a)
            tm.TimerShadow.Color = { r, g, b, a }
            ApplySettings()
        end)
    row3b:AddWidget(timerShadowColor, 0.5)
    table_insert(allWidgets, timerShadowColor)
    table_insert(timeShadowWidgets, timerShadowColor)
    card3:AddRow(row3b, 40)

    local row3c = GUIFrame:CreateRow(card3.content, 37)
    local timerShadowX = GUIFrame:CreateSlider(row3c, "Shadow X Offset", -5, 5, 1, tm.TimerShadow.OffsetX or 1, 20,
        function(val)
            tm.TimerShadow.OffsetX = val
            ApplySettings()
        end)
    row3c:AddWidget(timerShadowX, 0.5)
    table_insert(allWidgets, timerShadowX)
    table_insert(timeShadowWidgets, timerShadowX)

    local timerShadowY = GUIFrame:CreateSlider(row3c, "Shadow Y Offset", -5, 5, 1, tm.TimerShadow.OffsetY or -1, 20,
        function(val)
            tm.TimerShadow.OffsetY = val
            ApplySettings()
        end)
    row3c:AddWidget(timerShadowY, 0.5)
    table_insert(allWidgets, timerShadowY)
    table_insert(timeShadowWidgets, timerShadowY)
    card3:AddRow(row3c, 37)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Charge Count Settings
    ----------------------------------------------------------------
    local card4 = GUIFrame:CreateCard(scrollChild, "Charge Count", yOffset)
    table_insert(activeCards, card4)
    table_insert(allWidgets, card4)

    -- Row 1: Available and Unavailable Colors
    local row4a = GUIFrame:CreateRow(card4.content, 39)
    local chargeAvailColor = GUIFrame:CreateColorPicker(row4a, "Available Color",
        tm.ChargeAvailableColor or { 0.3, 1, 0.3, 1 },
        function(r, g, b, a)
            tm.ChargeAvailableColor = { r, g, b, a }
            ApplySettings()
        end)
    row4a:AddWidget(chargeAvailColor, 0.5)
    table_insert(allWidgets, chargeAvailColor)

    local chargeUnavailColor = GUIFrame:CreateColorPicker(row4a, "Unavailable Color",
        tm.ChargeUnavailableColor or { 1, 0.3, 0.3, 1 },
        function(r, g, b, a)
            tm.ChargeUnavailableColor = { r, g, b, a }
            ApplySettings()
        end)
    row4a:AddWidget(chargeUnavailColor, 0.5)
    table_insert(allWidgets, chargeUnavailColor)
    card4:AddRow(row4a, 39)

    -- Separator
    local row1charge = GUIFrame:CreateRow(card4.content, 8)
    local chargeSepCard = GUIFrame:CreateSeparator(row1charge)
    row1charge:AddWidget(chargeSepCard, 1)
    table_insert(allWidgets, chargeSepCard)
    card4:AddRow(row1charge, 8)

    -- Row 2: Shadow Enable and Soft Outline
    local row4b = GUIFrame:CreateRow(card4.content, 39)
    local chargeShadowCheck = GUIFrame:CreateCheckbox(row4b, "Enable Shadow", tm.ChargeShadow.Enabled == true,
        function(checked)
            tm.ChargeShadow.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row4b:AddWidget(chargeShadowCheck, 0.5)
    table_insert(allWidgets, chargeShadowCheck)
    table_insert(chargeShadowWidgetsToggle, chargeShadowCheck)

    -- Color
    local chargeShadowColor = GUIFrame:CreateColorPicker(row4b, "Shadow Color",
        tm.ChargeShadow.Color or { 0, 0, 0, 1 },
        function(r, g, b, a)
            tm.ChargeShadow.Color = { r, g, b, a }
            ApplySettings()
        end)
    row4b:AddWidget(chargeShadowColor, 0.5)
    table_insert(allWidgets, chargeShadowColor)
    table_insert(chargeShadowWidgets, chargeShadowColor)
    card4:AddRow(row4b, 39)

    local row4c = GUIFrame:CreateRow(card4.content, 39)
    local chargeShadowX = GUIFrame:CreateSlider(row4c, "Shadow X Offset", -5, 5, 1,
        tm.ChargeShadow.OffsetX or 0, 20,
        function(val)
            tm.ChargeShadow.OffsetX = val
            ApplySettings()
        end)
    row4c:AddWidget(chargeShadowX, 0.5)
    table_insert(allWidgets, chargeShadowX)
    table_insert(chargeShadowWidgets, chargeShadowX)

    local chargeShadowY = GUIFrame:CreateSlider(row4c, "Shadow Y Offset", -5, 5, 1,
        tm.ChargeShadow.OffsetY or 0, 20,
        function(val)
            tm.ChargeShadow.OffsetY = val
            ApplySettings()
        end)
    row4c:AddWidget(chargeShadowY, 0.5)
    table_insert(allWidgets, chargeShadowY)
    table_insert(chargeShadowWidgets, chargeShadowY)
    card4:AddRow(row4c, 39)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 5: Backdrop Settings
    ----------------------------------------------------------------
    local card5 = GUIFrame:CreateCard(scrollChild, "Backdrop Settings", yOffset)
    table_insert(activeCards, card5)
    table_insert(allWidgets, card5)

    -- Row 1: Enable Backdrop
    local row5a = GUIFrame:CreateRow(card5.content, 40)
    local backdropCheck = GUIFrame:CreateCheckbox(row5a, "Enable Backdrop", tm.Backdrop.Enabled == true,
        function(checked)
            tm.Backdrop.Enabled = checked
            ApplySettings()
        end)
    row5a:AddWidget(backdropCheck, (1 / 3))
    table_insert(allWidgets, backdropCheck)

    -- Row 2: Backdrop Colors (if enabled)
    local bgColor = GUIFrame:CreateColorPicker(row5a, "Backdrop Color", tm.Backdrop.Color or { 0, 0, 0, 0.6 },
        function(r, g, b, a)
            tm.Backdrop.Color = { r, g, b, a }
            ApplySettings()
        end)
    row5a:AddWidget(bgColor, (1 / 3))
    table_insert(allWidgets, bgColor)

    local borderColor = GUIFrame:CreateColorPicker(row5a, "Border Color", tm.Backdrop.BorderColor or { 0, 0, 0, 1 },
        function(r, g, b, a)
            tm.Backdrop.BorderColor = { r, g, b, a }
            ApplySettings()
        end)
    row5a:AddWidget(borderColor, (1 / 3))
    table_insert(allWidgets, borderColor)
    card5:AddRow(row5a, 40)

    -- Row 2: Frame Width and Height sliders
    local row5b = GUIFrame:CreateRow(card5.content, 39)
    local frameWidthSlider = GUIFrame:CreateSlider(row5b, "Frame Width", 50, 300, 1,
        tm.Backdrop.FrameWidth or 100, 60,
        function(val)
            tm.Backdrop.FrameWidth = val
            ApplySettings()
        end)
    row5b:AddWidget(frameWidthSlider, 0.5)
    table_insert(allWidgets, frameWidthSlider)

    local frameHeightSlider = GUIFrame:CreateSlider(row5b, "Frame Height", 16, 100, 1,
        tm.Backdrop.FrameHeight or 26, 60,
        function(val)
            tm.Backdrop.FrameHeight = val
            ApplySettings()
        end)
    row5b:AddWidget(frameHeightSlider, 0.5)
    table_insert(allWidgets, frameHeightSlider)
    card5:AddRow(row5b, 39)

    yOffset = yOffset + card5:GetContentHeight() + Theme.paddingSmall

    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 4)
    return yOffset
end

----------------------------------------------------------------
-- Sub-Tab: Icon Mode (Placeholder)
----------------------------------------------------------------
local function RenderIconModeTab(scrollChild, yOffset, activeCards)
    local db = GetBattleResDB()
    if not db then return yOffset end

    ----------------------------------------------------------------
    -- Placeholder Card
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Icon Mode Settings", yOffset)
    table_insert(activeCards, card1)
    table_insert(allWidgets, card1)

    local row1 = GUIFrame:CreateRow(card1.content, 40)
    local placeholderLabel = card1.content:CreateFontString(nil, "OVERLAY")
    placeholderLabel:SetPoint("TOPLEFT", row1, "TOPLEFT", 0, 0)
    placeholderLabel:SetPoint("TOPRIGHT", row1, "TOPRIGHT", 0, 0)
    placeholderLabel:SetJustifyH("CENTER")
    if NRSKNUI.ApplyThemeFont then
        NRSKNUI:ApplyThemeFont(placeholderLabel, "normal")
    else
        placeholderLabel:SetFontObject("GameFontNormal")
    end
    placeholderLabel:SetText("Icon Mode settings coming soon...")
    placeholderLabel:SetTextColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)
    card1:AddRow(row1, 40)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    UpdateAllWidgetStates()
    return yOffset
end

----------------------------------------------------------------
-- Create Battle Res Panel (with secondary tab bar)
----------------------------------------------------------------
local function CreateBattleResPanel(container)
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

    -- Cache tab bar
    cachedTabBar = tabBar

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
        elseif tabId == "textMode" then
            yOffset = RenderTextModeTab(scrollChild, yOffset, activeCards)
        elseif tabId == "iconMode" then
            yOffset = RenderIconModeTab(scrollChild, yOffset, activeCards)
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
GUIFrame:RegisterPanel("battleRes", CreateBattleResPanel)

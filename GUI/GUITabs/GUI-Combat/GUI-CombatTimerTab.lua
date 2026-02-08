-- NorskenUI namespace
local _, NRSKNUI = ...

-- Locals
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.LSM or LibStub("LibSharedMedia-3.0", true)

-- Localization Setup
local table_insert = table.insert

-- Combat Timer Tab Content
GUIFrame:RegisterContent("combatTimer", function(scrollChild, yOffset)
    -- Load database settings
    local db = NRSKNUI.db and NRSKNUI.db.profile.CombatTimer
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Track widgets for enable/disable logic
    local allWidgets = {}    -- All widgets (except main toggle)
    local shadowWidgets = {} -- Widgets dependent on shadow enable
    local bgWidgets = {}     -- Backdrop Widgets

    -- Helper to get Combat Timer module
    local function GetCombatTimerModule()
        if NRSKNUI.Addon then
            return NRSKNUI.Addon:GetModule("CombatTimer", true)
        end
        return nil
    end

    -- Helper to apply settings changes
    local function ApplySettings()
        local CT = GetCombatTimerModule()
        if CT and CT.ApplySettings then CT:ApplySettings() end
    end

    -- Helper to apply position changes
    local function ApplyPosition()
        local CT = GetCombatTimerModule()
        if CT and CT.ApplyPosition then CT:ApplyPosition() end
    end

    -- Widget state update
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false
        local shadowEnabled = db.FontShadow and db.FontShadow.Enabled == true
        local bgEnabled = db.Backdrop and db.Backdrop.Enabled == true

        -- First: Apply main enable state to ALL widgets
        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end

        -- Second: Apply conditional states (only if main is enabled, otherwise already disabled)
        if mainEnabled then
            -- Shadow widgets: only enabled if shadow is also enabled
            for _, widget in ipairs(shadowWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(shadowEnabled)
                end
            end
            -- Backdrop widgets
            for _, widget in ipairs(bgWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(bgEnabled)
                end
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: Combat Timer (Enable + Format)
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Combat Timer", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Combat Timer", db.Enabled ~= false, function(checked)
            db.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end,
        true,
        "Combat Timer",
        "On",
        "Off"
    )
    row1:AddWidget(enableCheck, 0.5)

    local formatList = { ["MM:SS"] = "MM:SS", ["MM:SS:MS"] = "MM:SS:MS" }
    local formatDropdown = GUIFrame:CreateDropdown(row1, "Format", formatList, db.Format or "MM:SS", 50,
        function(key)
            db.Format = key
            ApplySettings()
        end)
    row1:AddWidget(formatDropdown, 0.5)
    table_insert(allWidgets, formatDropdown)
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
        defaults = {
            anchorFrameType = "SELECTFRAME",
            anchorFrameFrame = "UIParent",
            selfPoint = "CENTER",
            anchorPoint = "CENTER",
            xOffset = 0,
            yOffset = -138,
            strata = "HIGH",
        },
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = ApplyPosition,
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
    -- Card 3: Font Settings
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Font Settings", yOffset)
    table_insert(allWidgets, card3)

    -- Font Face + Outline Row
    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do fontList[name] = name end
    else
        fontList["Friz Quadrata TT"] = "Friz Quadrata TT"
    end

    -- Font Face + Outline Row
    local row3a = GUIFrame:CreateRow(card3.content, 40)
    local fontDropdown = GUIFrame:CreateDropdown(row3a, "Font", fontList, db.FontFace or "Friz Quadrata TT", 30,
        function(key)
            db.FontFace = key
            ApplySettings()
        end)
    row3a:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)

    -- Font Outline Dropdown
    local outlineList = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick" }
    local outlineDropdown = GUIFrame:CreateDropdown(row3a, "Outline", outlineList, db.FontOutline or "OUTLINE", 45,
        function(key)
            db.FontOutline = key
            ApplySettings()
        end)
    row3a:AddWidget(outlineDropdown, 0.5)
    table_insert(allWidgets, outlineDropdown)
    card3:AddRow(row3a, 40)

    -- Font Size Row
    local row3b = GUIFrame:CreateRow(card3.content, 37)
    local fontSizeSlider = GUIFrame:CreateSlider(card3.content, "Font Size", 8, 72, 1, db.FontSize or 18, 60,
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
    db.FontShadow = db.FontShadow or {}

    -- Shadow Enabled + Color Row
    local row4b = GUIFrame:CreateRow(card4.content, 40)
    local shadowEnableCheck = GUIFrame:CreateCheckbox(row4b, "Use Shadow", db.FontShadow.Enabled == true,
        function(checked)
            db.FontShadow.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row4b:AddWidget(shadowEnableCheck, 0.5)
    table_insert(allWidgets, shadowEnableCheck)

    local shadowColor = GUIFrame:CreateColorPicker(row4b, "Shadow Color", db.FontShadow.Color or { 0, 0, 0, 1 },
        function(r, g, b, a)
            db.FontShadow.Color = { r, g, b, a }
            ApplySettings()
        end)
    row4b:AddWidget(shadowColor, 0.5)
    table_insert(allWidgets, shadowColor)
    table_insert(shadowWidgets, shadowColor)
    card4:AddRow(row4b, 40)

    -- Shadow Offset Row
    local row4a = GUIFrame:CreateRow(card4.content, 37)
    local shadowX = GUIFrame:CreateSlider(row4a, "Shadow X Offset", -5, 5, 1, db.FontShadow.OffsetX or 0, 15,
        function(val)
            db.FontShadow.OffsetX = val
            ApplySettings()
        end)
    row4a:AddWidget(shadowX, 0.5)
    table_insert(allWidgets, shadowX)
    table_insert(shadowWidgets, shadowX)

    local shadowY = GUIFrame:CreateSlider(row4a, "Shadow Y Offset", -5, 5, 1, db.FontShadow.OffsetY or 0, 15,
        function(val)
            db.FontShadow.OffsetY = val
            ApplySettings()
        end)
    row4a:AddWidget(shadowY, 0.5)
    table_insert(allWidgets, shadowY)
    table_insert(shadowWidgets, shadowY)
    card4:AddRow(row4a, 37)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 5: Color Settings
    ----------------------------------------------------------------
    local card5 = GUIFrame:CreateCard(scrollChild, "Color Settings", yOffset)
    table_insert(allWidgets, card5)

    -- In Combat Color Row
    local row5a = GUIFrame:CreateRow(card5.content, 40)
    local inCombatColor = GUIFrame:CreateColorPicker(row5a, "In Combat Color", db.ColorInCombat or { 1, 1, 1, 1 },
        function(r, g, b, a)
            db.ColorInCombat = { r, g, b, a }
            ApplySettings()
        end)
    row5a:AddWidget(inCombatColor, 1)
    table_insert(allWidgets, inCombatColor)
    card5:AddRow(row5a, 40)

    -- Out Combat Color Row
    local row5b = GUIFrame:CreateRow(card5.content, 37)
    local outCombatColor = GUIFrame:CreateColorPicker(row5b, "Non Combat Color",
        db.ColorOutOfCombat or { 1, 1, 1, 0.7 },
        function(r, g, b, a)
            db.ColorOutOfCombat = { r, g, b, a }
            ApplySettings()
        end)
    row5b:AddWidget(outCombatColor, 1)
    table_insert(allWidgets, outCombatColor)
    card5:AddRow(row5b, 37)

    yOffset = yOffset + card5:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 6: Backdrop Settings
    ----------------------------------------------------------------
    local card6 = GUIFrame:CreateCard(scrollChild, "Backdrop Settings", yOffset)
    table_insert(allWidgets, card6)
    db.Backdrop = db.Backdrop or {}

    -- Row a
    local row6a = GUIFrame:CreateRow(card6.content, 39)
    local backdropCheck = GUIFrame:CreateCheckbox(row6a, "Enable Backdrop", db.Backdrop.Enabled ~= false,
        function(checked)
            db.Backdrop.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row6a:AddWidget(backdropCheck, 1)
    table_insert(allWidgets, backdropCheck)
    card6:AddRow(row6a, 39)

    -- Row b
    local row6ba = GUIFrame:CreateRow(card6.content, 39)
    local bgWidth = GUIFrame:CreateSlider(row6ba, "Backdrop Width", 1, 600, 1, db.Backdrop.bgWidth or 100, 0,
        function(val)
            db.Backdrop.bgWidth = val
            ApplySettings()
        end)
    row6ba:AddWidget(bgWidth, 0.4)
    table_insert(allWidgets, bgWidth)
    table_insert(bgWidgets, bgWidth)

    local bgHeight = GUIFrame:CreateSlider(row6ba, "Backdrop Height", 1, 600, 1, db.Backdrop.bgHeight or 40, 0,
        function(val)
            db.Backdrop.bgHeight = val
            ApplySettings()
        end)
    row6ba:AddWidget(bgHeight, 0.39)
    table_insert(allWidgets, bgHeight)
    table_insert(bgWidgets, bgHeight)

    local bgColor = GUIFrame:CreateColorPicker(row6ba, "Backdrop Color", db.Backdrop.Color or { 0, 0, 0, 0.6 },
        function(r, g, b, a)
            db.Backdrop.Color = { r, g, b, a }
            ApplySettings()
        end)
    row6ba:AddWidget(bgColor, 0.21)
    table_insert(allWidgets, bgColor)
    table_insert(bgWidgets, bgColor)
    card6:AddRow(row6ba, 39)

    -- Separator
    local row6sep = GUIFrame:CreateRow(card6.content, 8)
    local sepBgCard = GUIFrame:CreateSeparator(row6sep)
    row6sep:AddWidget(sepBgCard, 1)
    table_insert(allWidgets, sepBgCard)
    table_insert(bgWidgets, sepBgCard)
    card6:AddRow(row6sep, 8)

    -- Row c
    local row6c = GUIFrame:CreateRow(card6.content, 39)
    local borderSize = GUIFrame:CreateSlider(row6c, "Border Size", 1, 10, 1, db.Backdrop.BorderSize or 1, 0,
        function(val)
            db.Backdrop.BorderSize = val
            ApplySettings()
        end)
    row6c:AddWidget(borderSize, 0.79)
    table_insert(allWidgets, borderSize)
    table_insert(bgWidgets, borderSize)

    local borderColor = GUIFrame:CreateColorPicker(row6c, "Border Color",
        db.Backdrop.BorderColor or { 0, 0, 0, 1 },
        function(r, g, b, a)
            db.Backdrop.BorderColor = { r, g, b, a }
            ApplySettings()
        end)
    row6c:AddWidget(borderColor, 0.21)
    table_insert(allWidgets, borderColor)
    table_insert(bgWidgets, borderColor)
    card6:AddRow(row6c, 39)

    yOffset = yOffset + card6:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 5)
    return yOffset
end)

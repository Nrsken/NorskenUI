-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.LSM

-- Localization Setup
local table_insert = table.insert

-- Helper to get Blizzard Mouseover module
local function GetCDMModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("CDM", true)
    end
    return nil
end

-- Combat Message Tab Content
GUIFrame:RegisterContent("CDM", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.CDM
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get Combat Message module
    local CDM = GetCDMModule()

    -- Track widgets for enable/disable logic
    local allWidgets = {} -- All widgets (except main toggle)

    -- Helper to apply settings
    local function ApplySettings()
        if CDM then
            CDM:UpdateSettings()
        end
    end

    -- Helper to apply new state
    local function ApplyCDMState(enabled)
        if not CDM then return end
        CDM.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("CDM")
        else
            NRSKNUI.Addon:DisableModule("CDM")
        end
    end

    -- Comprehensive widget state update
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false

        -- First: Apply main enable state to ALL widgets
        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end
    end

    -- Font Face, Outline, Size Row
    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do fontList[name] = name end
    else
        fontList["Friz Quadrata TT"] = "Friz Quadrata TT"
    end

    ----------------------------------------------------------------
    -- Card 1: CDM Aura Overlay Remover
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "CDM Aura Overlay & Fonts", yOffset)

    -- Enable Checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Aura Overlay Removal", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyCDMState(checked)
            UpdateAllWidgetStates()
            NRSKNUI:CreateReloadPrompt("Disabling/Enabling this UI element requires a reload to take full effect.")
        end,
        true,
        "CDM Auras",
        "On",
        "Off"
    )
    row1:AddWidget(enableCheck, 0.5)
    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: CDM Font
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "CDM Font", yOffset)

    -- Font Face and Outline Dropdowns
    local row2 = GUIFrame:CreateRow(card2.content, 40)
    local fontDropdown = GUIFrame:CreateDropdown(row2, "Font", fontList, db.FontFace, 30,
        function(key)
            db.FontFace = key
            ApplySettings()
        end)
    row2:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)

    -- Font Outline Dropdown
    local outlineList = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick" }
    local outlineDropdown = GUIFrame:CreateDropdown(row2, "Outline", outlineList, db.FontOutline or "OUTLINE", 45,
        function(key)
            db.FontOutline = key
            ApplySettings()
        end)
    row2:AddWidget(outlineDropdown, 0.5)
    table_insert(allWidgets, outlineDropdown)
    card2:AddRow(row2, 40)

    -- Separator
    local row5asep = GUIFrame:CreateRow(card2.content, 8)
    local seprow5Card = GUIFrame:CreateSeparator(row5asep)
    row5asep:AddWidget(seprow5Card, 1)
    table_insert(allWidgets, seprow5Card)
    card2:AddRow(row5asep, 8)

    -- Cooldown Font color
    local row3 = GUIFrame:CreateRow(card2.content, 40)
    local FontColor = GUIFrame:CreateColorPicker(row3, "Cooldown Font color", db.Cooldown.FontColor,
        function(r, g, b, a)
            db.Cooldown.FontColor = { r, g, b, a }
            ApplySettings()
        end)
    row3:AddWidget(FontColor, 1)
    table_insert(allWidgets, FontColor)
    card2:AddRow(row3, 40)

    -- Essentials Font Size
    local row4 = GUIFrame:CreateRow(card2.content, 40)
    local SizeEssentials = GUIFrame:CreateSlider(row4, "Essentials Font Size", 1, 25, 1,
        db.Cooldown.SizeEssentials, _,
        function(val)
            db.Cooldown.SizeEssentials = val
            ApplySettings()
        end)
    row4:AddWidget(SizeEssentials, 0.5)
    table_insert(allWidgets, SizeEssentials)

    -- Utility Font Size
    local SizeUtil = GUIFrame:CreateSlider(row4, "Utility Font Size", 1, 25, 1,
        db.Cooldown.SizeUtil, _,
        function(val)
            db.Cooldown.SizeUtil = val
            ApplySettings()
        end)
    row4:AddWidget(SizeUtil, 0.5)
    table_insert(allWidgets, SizeUtil)
    card2:AddRow(row4, 40)

    -- Separator
    local row2asep = GUIFrame:CreateRow(card2.content, 8)
    local row2asepCard = GUIFrame:CreateSeparator(row2asep)
    row2asep:AddWidget(row2asepCard, 1)
    table_insert(allWidgets, row2asepCard)
    card2:AddRow(row2asep, 8)

    -- Charges Font color
    local row5 = GUIFrame:CreateRow(card2.content, 40)
    local ChargesFontColor = GUIFrame:CreateColorPicker(row5, "Charge Font color", db.Charges.FontColor,
        function(r, g, b, a)
            db.Charges.FontColor = { r, g, b, a }
            ApplySettings()
        end)
    row5:AddWidget(ChargesFontColor, 0.5)
    table_insert(allWidgets, ChargesFontColor)

    -- Charges Font Size
    local ChargesSize = GUIFrame:CreateSlider(row5, "Charge Font Size", 1, 25, 1,
        db.Charges.Size, _,
        function(val)
            db.Charges.Size = val
            ApplySettings()
        end)
    row5:AddWidget(ChargesSize, 0.5)
    table_insert(allWidgets, ChargesSize)
    card2:AddRow(row5, 40)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 3)
    return yOffset
end)

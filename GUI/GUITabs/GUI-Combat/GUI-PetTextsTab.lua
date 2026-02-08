-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.LSM

-- Localization
local table_insert = table.insert
local pairs = pairs

-- Get module reference
local function GetModule()
    return NRSKNUI.Addon:GetModule("PetTexts", true)
end

-- Register Pet Texts tab content
GUIFrame:RegisterContent("PetTexts", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.PetTexts
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    local mod = GetModule()
    local allWidgets = {}
    local fontWidgets = {}

    local function ApplySettings()
        if mod and mod.ApplySettings then
            mod:ApplySettings()
        end
    end

    local function ApplyModuleState(enabled)
        if not mod then return end
        db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("PetTexts")
        else
            NRSKNUI.Addon:DisableModule("PetTexts")
        end
    end

    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false
        local useSoftOutline = db.FontSoftOutline ~= true

        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end

        if mainEnabled then
            for _, widget in ipairs(fontWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(useSoftOutline)
                end
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: Pet Status Texts (Enable + Preview)
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Pet Status Texts", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Pet Status Texts", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyModuleState(checked)
            UpdateAllWidgetStates()
        end,
        true, "Pet Status Texts", "On", "Off"
    )
    row1:AddWidget(enableCheck, 0.5)
    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: State Settings (3 rows: Missing, Dead, Passive)
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "State Settings", yOffset)
    table_insert(allWidgets, card2)

    -- Row 1: Pet Missing - Text + Color
    local row2a = GUIFrame:CreateRow(card2.content, 38)
    local petMissingInput = GUIFrame:CreateEditBox(row2a, "Pet Missing Text", db.PetMissing or "PET MISSING",
        function(val)
            db.PetMissing = val
            ApplySettings()
        end)
    row2a:AddWidget(petMissingInput, 0.5)
    table_insert(allWidgets, petMissingInput)

    local missingColorPicker = GUIFrame:CreateColorPicker(row2a, "Missing Color",
        db.MissingColor or { 1, 0.82, 0, 1 },
        function(r, g, b, a)
            db.MissingColor = { r, g, b, a }
            ApplySettings()
        end)
    row2a:AddWidget(missingColorPicker, 0.5)
    table_insert(allWidgets, missingColorPicker)
    card2:AddRow(row2a, 38)

    -- Row 2: Pet Dead - Text + Color
    local row2b = GUIFrame:CreateRow(card2.content, 38)
    local petDeadInput = GUIFrame:CreateEditBox(row2b, "Pet Dead Text", db.PetDead or "PET DEAD",
        function(val)
            db.PetDead = val
            ApplySettings()
        end)
    row2b:AddWidget(petDeadInput, 0.5)
    table_insert(allWidgets, petDeadInput)

    local deadColorPicker = GUIFrame:CreateColorPicker(row2b, "Dead Color",
        db.DeadColor or { 1, 0.2, 0.2, 1 },
        function(r, g, b, a)
            db.DeadColor = { r, g, b, a }
            ApplySettings()
        end)
    row2b:AddWidget(deadColorPicker, 0.5)
    table_insert(allWidgets, deadColorPicker)
    card2:AddRow(row2b, 38)

    -- Row 3: Pet Passive - Text + Color
    local row2c = GUIFrame:CreateRow(card2.content, 38)
    local petPassiveInput = GUIFrame:CreateEditBox(row2c, "Pet Passive Text", db.PetPassive or "PET PASSIVE",
        function(val)
            db.PetPassive = val
            ApplySettings()
        end)
    row2c:AddWidget(petPassiveInput, 0.5)
    table_insert(allWidgets, petPassiveInput)

    local passiveColorPicker = GUIFrame:CreateColorPicker(row2c, "Passive Color",
        db.PassiveColor or { 0.3, 0.7, 1, 1 },
        function(r, g, b, a)
            db.PassiveColor = { r, g, b, a }
            ApplySettings()
        end)
    row2c:AddWidget(passiveColorPicker, 0.5)
    table_insert(allWidgets, passiveColorPicker)
    card2:AddRow(row2c, 38)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

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

    -- Font Face and Outline Dropdowns
    local row3a = GUIFrame:CreateRow(card3.content, 40)
    local fontDropdown = GUIFrame:CreateDropdown(row3a, "Font", fontList, db.FontFace or "Friz Quadrata TT", 30,
        function(key)
            db.FontFace = key
            ApplySettings()
        end)
    row3a:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)

    -- Font Size Slider
    local fontSizeSlider = GUIFrame:CreateSlider(card3.content, "Font Size", 8, 72, 1, db.FontSize or 24, 60,
        function(val)
            db.FontSize = val
            ApplySettings()
        end)
    row3a:AddWidget(fontSizeSlider, 0.5)
    table_insert(allWidgets, fontSizeSlider)
    card3:AddRow(row3a, 40)

    -- Font Outline Dropdown
    local row3b = GUIFrame:CreateRow(card3.content, 37)
    local outlineList = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick" }
    local outlineDropdown = GUIFrame:CreateDropdown(row3b, "Outline", outlineList, db.FontOutline or "OUTLINE", 45,
        function(key)
            db.FontOutline = key
            ApplySettings()
        end)
    row3b:AddWidget(outlineDropdown, 0.5)
    table_insert(allWidgets, outlineDropdown)
    table_insert(fontWidgets, outlineDropdown)

    local enableSoftOutline = GUIFrame:CreateCheckbox(row3b, "Enable Soft Outline", db.FontSoftOutline ~= false,
        function(checked)
            db.FontSoftOutline = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row3b:AddWidget(enableSoftOutline, 0.5)
    table_insert(allWidgets, enableSoftOutline)

    card3:AddRow(row3b, 37)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Position Settings
    ----------------------------------------------------------------
    local card4, newOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
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
            yOffset = 150,
            strata = "HIGH",
        },
        showAnchorFrameType = false,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })

    if card4.positionWidgets then
        for _, widget in ipairs(card4.positionWidgets) do
            table_insert(allWidgets, widget)
        end
    end
    table_insert(allWidgets, card4)

    yOffset = newOffset

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 2)
    return yOffset
end)

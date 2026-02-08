-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.LSM

-- Localization Setup
local table_insert = table.insert
local ipairs = ipairs
local pairs = pairs

-- Helper to get Blizzard Mouseover module
local function GetAurasModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("Auras", true)
    end
    return nil
end

-- Combat Message Tab Content
GUIFrame:RegisterContent("Auras", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.BuffDebuffFrames
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get Combat Message module
    local AURAS = GetAurasModule()

    -- Track widgets for enable/disable logic
    local allWidgets = {} -- All widgets (except main toggle)

    -- Helper to apply settings
    local function ApplySettings()
        if not AURAS or not AURAS:IsEnabled() then return end
        AURAS:Refresh()
    end

    -- Helper to apply new state
    local function ApplyAurasState(enabled)
        if not AURAS then return end
        AURAS.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("Auras")
        else
            NRSKNUI.Addon:DisableModule("Auras")
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

    ----------------------------------------------------------------
    -- Card 1: Buffs, Debuffs & Externals Enable
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Buffs, Debuffs & Externals", yOffset)

    -- Enable Checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Buffs, Debuffs & Externals Skinning", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyAurasState(checked)
            UpdateAllWidgetStates()
            if not checked then
                NRSKNUI:CreateReloadPrompt("Enabling/Disabling this UI element requires a reload to take full effect.")
            end
        end,
        true,
        "Buffs, Debuffs & Externals Skinning",
        "On",
        "Off"
    )
    row1:AddWidget(enableCheck, 0.5)
    card1:AddRow(row1, 36)
    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: General Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "General Settings", yOffset)

    -- Enable Checkbox
    local row2 = GUIFrame:CreateRow(card2.content, 40)
    local disableFlashing = GUIFrame:CreateCheckbox(row2, "Disable flashing when low duration",
        db.disableFlashing ~= false,
        function(checked)
            db.disableFlashing = checked
            ApplySettings()
            if not checked then
                NRSKNUI:CreateReloadPrompt("Disabling this UI element requires a reload to take full effect.")
            end
        end)
    row2:AddWidget(disableFlashing, 0.5)
    table_insert(allWidgets, disableFlashing)
    card2:AddRow(row2, 40)

    -- Separator
    local row5asep = GUIFrame:CreateRow(card2.content, 8)
    local seprow5Card = GUIFrame:CreateSeparator(row5asep)
    row5asep:AddWidget(seprow5Card, 1)
    table_insert(allWidgets, seprow5Card)
    card2:AddRow(row5asep, 8)

    -- Font Face, Outline, Size Row
    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do fontList[name] = name end
    else
        fontList["Friz Quadrata TT"] = "Friz Quadrata TT"
    end

    -- buffBorderColor coloring
    local row3c = GUIFrame:CreateRow(card2.content, 40)
    local FontColor = GUIFrame:CreateColorPicker(row3c, "Font color", db.FontColor,
        function(r, g, b, a)
            db.FontColor = { r, g, b, a }
            ApplySettings()
        end)
    row3c:AddWidget(FontColor, 1)
    table_insert(allWidgets, FontColor)
    card2:AddRow(row3c, 40)

    -- Font Face and Outline Dropdowns
    local row3a = GUIFrame:CreateRow(card2.content, 40)
    local fontDropdown = GUIFrame:CreateDropdown(row3a, "Font", fontList, db.FontFace, 30,
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
    card2:AddRow(row3a, 40)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Buff Settings
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Buff Settings", yOffset)

    -- buffBorderColor coloring
    local row3 = GUIFrame:CreateRow(card3.content, 39)
    local buffBorderColor = GUIFrame:CreateColorPicker(row3, "Buff border color", db.buffBorderColor,
        function(r, g, b, a)
            db.buffBorderColor = { r, g, b, a }
            ApplySettings()
        end)
    row3:AddWidget(buffBorderColor, 0.5)
    table_insert(allWidgets, buffBorderColor)
    card3:AddRow(row3, 36)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Debuff Settings
    ----------------------------------------------------------------
    local card4 = GUIFrame:CreateCard(scrollChild, "Debuff Settings", yOffset)

    -- buffBorderColor coloring
    local row4 = GUIFrame:CreateRow(card4.content, 39)
    local debuffBorderColor = GUIFrame:CreateColorPicker(row4, "Debuff border color", db.debuffBorderColor,
        function(r, g, b, a)
            db.debuffBorderColor = { r, g, b, a }
            ApplySettings()
        end)
    row4:AddWidget(debuffBorderColor, 0.5)
    table_insert(allWidgets, debuffBorderColor)
    card4:AddRow(row4, 36)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 5: External Defensive Settings
    ----------------------------------------------------------------
    local card5 = GUIFrame:CreateCard(scrollChild, "External Defensive Settings", yOffset)

    -- buffBorderColor coloring
    local row5 = GUIFrame:CreateRow(card5.content, 39)
    local defBorderColor = GUIFrame:CreateColorPicker(row5, "External Defensive border color", db.defBorderColor,
        function(r, g, b, a)
            db.defBorderColor = { r, g, b, a }
            ApplySettings()
        end)
    row5:AddWidget(defBorderColor, 0.5)
    table_insert(allWidgets, defBorderColor)
    card5:AddRow(row5, 36)

    yOffset = yOffset + card5:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 3)
    return yOffset
end)

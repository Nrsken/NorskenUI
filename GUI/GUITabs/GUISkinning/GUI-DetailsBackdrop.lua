-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local table_insert = table.insert

-- Helper to get Blizzard Mouseover module
local function GetDetailsBackdropModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("DetailsBackdrop", true)
    end
    return nil
end

-- Combat Message Tab Content
GUIFrame:RegisterContent("DetailsBackdrop", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.DetailsBackdrop
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Check for pending context from EditMode navigation (e.g., specific backdrop to select)
    if GUIFrame.pendingContext then
        local contextBackdrop = GUIFrame.pendingContext
        -- Validate that the context is a valid backdrop key
        if contextBackdrop == "bgOne" or contextBackdrop == "bgTwo" then
            db.currentEdit = contextBackdrop
        end
        -- Clear the pending context so it doesn't persist
        GUIFrame.pendingContext = nil
    end

    -- Get Combat Message module
    local DBG = GetDetailsBackdropModule()

    -- Track widgets for enable/disable logic
    local allWidgets = {}          -- All widgets (except main toggle)
    local autoSizeOnlyWidgets = {} -- Widgets that only work when autoSize is ON
    local manualSizeWidgets = {}   -- Widgets that only work when autoSize is OFF
    local card3

    -- Initialize current edit selection
    local curEdit = db.currentEdit or "bgOne"

    -- Helper to get current backdrop DB
    local function GetCurrentBackdropDB()
        if curEdit == "bgTwo" then
            return db.backDropTwo
        else
            return db.backDropOne
        end
    end

    local function ApplyAll()
        if DBG then
            DBG:UpdateDetailsBackdropOne()
            DBG:UpdateDetailsBackdropTwo()
        end
    end

    -- Helper to apply settings
    local function ApplySettings()
        if DBG then
            if curEdit == "bgOne" then
                DBG:UpdateDetailsBackdropOne()
            else
                DBG:UpdateDetailsBackdropTwo()
            end
        end
    end

    -- Helper to apply new state
    local function ApplyDetailsBackdropState(enabled)
        if not DBG then return end
        DBG.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("DetailsBackdrop")
        else
            NRSKNUI.Addon:DisableModule("DetailsBackdrop")
        end
    end

    -- Comprehensive widget state update
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false
        local currentDB = GetCurrentBackdropDB()
        local autoSizeEnabled = currentDB.autoSize

        -- First: Apply main enable state to ALL widgets
        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end

        if card3 and card3.SetAnchorsOnlyEnabled then
            local shouldAnchorsWork = mainEnabled and (not autoSizeEnabled)
            card3:SetAnchorsOnlyEnabled(shouldAnchorsWork)
        end

        -- Second: Auto-size widgets only enabled when autoSize is ON
        for _, widget in ipairs(autoSizeOnlyWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled and autoSizeEnabled)
            end
        end

        -- Third: Manual size widgets only enabled when autoSize is OFF
        for _, widget in ipairs(manualSizeWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled and not autoSizeEnabled)
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: Details Backdrop Enable
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Details Backdrop", yOffset)

    -- Enable Checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Details Backdrop", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyDetailsBackdropState(checked)
            UpdateAllWidgetStates()
        end,
        true,
        "Details Backdrop",
        "On",
        "Off"
    )
    row1:AddWidget(enableCheck, 0.5)

    -- Font Outline Dropdown
    local editList = { ["bgOne"] = "Backdrop One", ["bgTwo"] = "Backdrop Two" }
    local editDropdown = GUIFrame:CreateDropdown(row1, "Select Backdrop To Edit", editList, curEdit, _,
        function(key)
            curEdit = key
            db.currentEdit = key
            GUIFrame:RefreshContent()
        end)
    row1:AddWidget(editDropdown, 0.5)
    table_insert(allWidgets, editDropdown)

    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Auto Size Toggle
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Size Mode", yOffset)
    local currentDB = GetCurrentBackdropDB()

    local row2 = GUIFrame:CreateRow(card2.content, 40)
    local autoSizeCheck = GUIFrame:CreateCheckbox(row2, "Auto Size to Parent Frame",
        currentDB.autoSize,
        function(checked)
            GetCurrentBackdropDB().autoSize = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end,
        true,
        "Auto Size",
        "On",
        "Off"
    )
    row2:AddWidget(autoSizeCheck, 1)
    table_insert(allWidgets, autoSizeCheck)
    card2:AddRow(row2, 40)

    -- Details Bars (per-backdrop)
    local row2b = GUIFrame:CreateRow(card2.content, 40)
    local detailsBars = GUIFrame:CreateSlider(row2b, "Amount of bars to show", 1, 25, 1,
        currentDB.detailsBars or db.detailsBars or 7, _,
        function(val)
            GetCurrentBackdropDB().detailsBars = val
            ApplySettings()
        end)
    row2b:AddWidget(detailsBars, 0.5)
    table_insert(allWidgets, detailsBars)
    table_insert(autoSizeOnlyWidgets, detailsBars)

    -- Bar Height
    local detailsBarH = GUIFrame:CreateSlider(row2b, "Your current Details bar height", 1, 50, 1,
        db.detailsBarH, _,
        function(val)
            db.detailsBarH = val
            ApplyAll()
        end)
    row2b:AddWidget(detailsBarH, 0.5)
    table_insert(allWidgets, detailsBarH)
    table_insert(autoSizeOnlyWidgets, detailsBarH)
    card2:AddRow(row2b, 40)

    local row2c = GUIFrame:CreateRow(card2.content, 40)
    local detailsTitelH = GUIFrame:CreateSlider(row2c, "Your current Details titlebar height", 1, 25, 1,
        db.detailsTitelH, _,
        function(val)
            db.detailsTitelH = val
            ApplyAll()
        end)
    row2c:AddWidget(detailsTitelH, 0.5)
    table_insert(allWidgets, detailsTitelH)
    table_insert(autoSizeOnlyWidgets, detailsTitelH)

    -- Spacing
    local detailsSpacing = GUIFrame:CreateSlider(row2c, "Your current Details spacing", 1, 50, 1,
        db.detailsSpacing, _,
        function(val)
            db.detailsSpacing = val
            ApplyAll()
        end)
    row2c:AddWidget(detailsSpacing, 0.5)
    table_insert(allWidgets, detailsSpacing)
    table_insert(autoSizeOnlyWidgets, detailsSpacing)
    card2:AddRow(row2c, 40)

    -- Width
    local row2d = GUIFrame:CreateRow(card2.content, 36)
    local detailsWidth = GUIFrame:CreateSlider(row2d, "Details Width", 50, 1000, 1,
        db.detailsWidth, _,
        function(val)
            db.detailsWidth = val
            ApplyAll()
        end)
    row2d:AddWidget(detailsWidth, 1)
    table_insert(allWidgets, detailsWidth)
    table_insert(autoSizeOnlyWidgets, detailsWidth)
    card2:AddRow(row2d, 36)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 5: Backdrop Color Settings
    ----------------------------------------------------------------
    local card5 = GUIFrame:CreateCard(scrollChild, "Backdrop Color", yOffset)
    table_insert(allWidgets, card5)

    -- Backdrop coloring
    local row4 = GUIFrame:CreateRow(card5.content, 40)
    local BackdropColor = GUIFrame:CreateColorPicker(row4, "Backdrop Color",
        GetCurrentBackdropDB().BackgroundColor,
        function(r, g, b, a)
            GetCurrentBackdropDB().BackgroundColor = { r, g, b, a }
            ApplySettings()
        end)
    row4:AddWidget(BackdropColor, 1)
    table_insert(allWidgets, BackdropColor)
    card5:AddRow(row4, 40)

    -- Backdrop Border coloring
    local row5 = GUIFrame:CreateRow(card5.content, 34)
    local BorderColor = GUIFrame:CreateColorPicker(row5, "Backdrop Border Color",
        GetCurrentBackdropDB().BorderColor,
        function(r, g, b, a)
            GetCurrentBackdropDB().BorderColor = { r, g, b, a }
            ApplySettings()
        end)
    row5:AddWidget(BorderColor, 1)
    table_insert(allWidgets, BorderColor)
    card5:AddRow(row5, 34)

    yOffset = yOffset + card5:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Position Settings (using reusable position card)
    ----------------------------------------------------------------
    local newOffset
    card3, newOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = GetCurrentBackdropDB(),
        dbKeys = {
            anchorFrameType = "anchorFrameType",
            anchorFrameFrame = "ParentFrame",
            selfPoint = "AnchorFrom",
            anchorPoint = "AnchorTo",
            xOffset = "XOffset",
            yOffset = "YOffset",
            strata = "Strata",
        },
        anchorToggleKey = true,
        showAnchorFrameType = false,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })
    -- Add position card widgets to allWidgets for enable/disable
    -- When autoSize is ON, anchor widgets should be disabled (always uses BOTTOMRIGHT)
    if card3.positionWidgets then
        for _, widget in ipairs(card3.positionWidgets) do
            table_insert(allWidgets, widget) -- Respects master toggle

            local isAnchorBtn = false
            for _, abWidget in ipairs(card3.AnchorButtonWidgets) do
                if widget == abWidget then
                    isAnchorBtn = true
                    break
                end
            end
            if not isAnchorBtn then
                -- table_insert(manualSizeWidgets, widget) -- Uncomment this if you want X/Y to disable too
            end
        end
    end
    table_insert(allWidgets, card3)
    yOffset = newOffset

    ----------------------------------------------------------------
    -- Card 4: Backdrop Size Settings (Manual Size - only when autoSize is OFF)
    ----------------------------------------------------------------
    local card4 = GUIFrame:CreateCard(scrollChild, "Backdrop Size (Manual)", yOffset)
    table_insert(allWidgets, card4)
    table_insert(manualSizeWidgets, card4)

    -- Backdrop Width
    local row3 = GUIFrame:CreateRow(card4.content, 36)
    local BackdropWidth = GUIFrame:CreateSlider(card4.content, "Backdrop Width", 10, 1000, 1,
        GetCurrentBackdropDB().width, _,
        function(val)
            GetCurrentBackdropDB().width = val
            ApplySettings()
        end)
    row3:AddWidget(BackdropWidth, 0.5)
    table_insert(allWidgets, BackdropWidth)
    table_insert(manualSizeWidgets, BackdropWidth)

    -- Backdrop Height
    local BackdropHeight = GUIFrame:CreateSlider(card4.content, "Backdrop Height", 10, 1000, 1,
        GetCurrentBackdropDB().height, _,
        function(val)
            GetCurrentBackdropDB().height = val
            ApplySettings()
        end)
    row3:AddWidget(BackdropHeight, 0.5)
    table_insert(allWidgets, BackdropHeight)
    table_insert(manualSizeWidgets, BackdropHeight)
    card4:AddRow(row3, 36)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 3)
    return yOffset
end)

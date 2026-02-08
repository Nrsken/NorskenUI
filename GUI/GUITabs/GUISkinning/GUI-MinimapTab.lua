-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local table_insert = table.insert
local ipairs = ipairs

-- Helper to get Blizzard Mouseover module
local function GetMinimapModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("Minimap", true)
    end
    return nil
end

-- Combat Message Tab Content
GUIFrame:RegisterContent("Minimap", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.Minimap
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get Combat Message module
    local MAP = GetMinimapModule()

    -- Track widgets for enable/disable logic
    local allWidgets = {} -- All widgets (except main toggle)
    local bugWidgets = {}

    -- Helper to apply settings
    local function ApplySettings()
        if MAP then
            MAP:RefreshAll()
        end
    end

    -- Helper to apply new state
    local function ApplyMinimapState(enabled)
        if not MAP then return end
        MAP.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("Minimap")
        else
            NRSKNUI.Addon:DisableModule("Minimap")
        end
    end

    -- Comprehensive widget state update
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false
        local bugEnabled = db.BugSack and db.BugSack.Enabled ~= false

        -- First: Apply main enable state to ALL widgets
        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end

        if mainEnabled then
            for _, widget in ipairs(bugWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(bugEnabled)
                end
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: Minimap Enable
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Minimap", yOffset)

    -- Enable Checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Minimap", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyMinimapState(checked)
            UpdateAllWidgetStates()
            NRSKNUI:CreateReloadPrompt("Enabling/Disabling this UI element requires a reload to take full effect.")
        end,
        true,
        "Minimap",
        "On",
        "Off"
    )
    row1:AddWidget(enableCheck, 1)

    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Minimap Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Minimap Settings", yOffset)
    table_insert(allWidgets, card2)

    -- Minimap Size
    local row2 = GUIFrame:CreateRow(card2.content, 40)
    local MinimapSize = GUIFrame:CreateSlider(row2, "Minimap Size", 50, 500, 1, db.Size, _,
        function(val)
            db.Size = val
            ApplySettings()
        end)
    row2:AddWidget(MinimapSize, 1)
    table_insert(allWidgets, MinimapSize)
    card2:AddRow(row2, 40)

    -- Border Size
    local row3 = GUIFrame:CreateRow(card2.content, 36)

    -- Border coloring
    local BorderColor = GUIFrame:CreateColorPicker(row3, "Border Color", db.Border.Color,
        function(r, g, b, a)
            db.Border.Color = { r, g, b, a }
            ApplySettings()
        end)
    row3:AddWidget(BorderColor, 1)
    table_insert(allWidgets, BorderColor)
    card2:AddRow(row3, 36)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Position Settings
    ----------------------------------------------------------------
    local card3, newOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        dbKeys = {
            anchorFrameType = nil,
            anchorFrameFrame = nil,
            selfPoint = "AnchorFrom",
            anchorPoint = "AnchorTo",
            xOffset = "X",
            yOffset = "Y",
            strata = nil,
        },
        showAnchorFrameType = false,
        showStrata = false,
        onChangeCallback = ApplySettings,
    })
    if card3.positionWidgets then
        for _, widget in ipairs(card3.positionWidgets) do
            table_insert(allWidgets, widget)
        end
    end
    table_insert(allWidgets, card3)
    yOffset = newOffset

    ----------------------------------------------------------------
    -- Card 4: Minimap Settings
    ----------------------------------------------------------------
    local card4 = GUIFrame:CreateCard(scrollChild, "BugSack Settings", yOffset)
    table_insert(allWidgets, card4)

    -- Toggle BugSack frame
    local row4 = GUIFrame:CreateRow(card4.content, 40)
    local BugSackEnbl = GUIFrame:CreateCheckbox(row4, "Toggle BugSack Frame", db.BugSack.Enabled ~= false,
        function(checked)
            db.BugSack.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row4:AddWidget(BugSackEnbl, 0.5)
    table_insert(allWidgets, BugSackEnbl)

    -- BugSack Size
    local BugSackSize = GUIFrame:CreateSlider(row4, "BugSack Size", 5, 50, 1, db.BugSack.Size, _,
        function(val)
            db.BugSack.Size = val
            ApplySettings()
        end)
    row4:AddWidget(BugSackSize, 0.5)
    table_insert(allWidgets, BugSackSize)
    table_insert(bugWidgets, BugSackSize)

    card4:AddRow(row4, 40)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 5: Addon Compartment Settings
    ----------------------------------------------------------------
    local card5 = GUIFrame:CreateCard(scrollChild, "AddOn Compartment Settings", yOffset)
    table_insert(allWidgets, card5)

    -- Toggle BugSack frame
    local row5 = GUIFrame:CreateRow(card5.content, 40)
    -- Hide addon compartment toggle
    local HideAddOn = GUIFrame:CreateCheckbox(row5, "Hide AddOn Compartment", db.HideAddOnComp ~= false,
        function(checked)
            db.HideAddOnComp = checked
            ApplySettings()
        end)
    row5:AddWidget(HideAddOn, 0.5)
    table_insert(allWidgets, HideAddOn)
    card5:AddRow(row5, 40)

    yOffset = yOffset + card5:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 3)
    return yOffset
end)

-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local table_insert = table.insert
local ipairs = ipairs

-- Helper to get UICleanup module
local function GetUICleanupModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("UICleanup", true)
    end
    return nil
end

-- Register UICleanup tab content
GUIFrame:RegisterContent("UICleanup", function(scrollChild, yOffset)
    -- Safety check for database
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.UICleanup
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get UICleanup module
    local UIC = GetUICleanupModule()

    -- Track widgets for enable/disable logic
    local allWidgets = {} -- All widgets (except main toggle)

    -- Helper to apply new state
    local function ApplyUICleanupState(enabled)
        if not UIC then return end
        UIC.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("UICleanup")
        else
            NRSKNUI.Addon:DisableModule("UICleanup")
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
    -- Card 1: UICleanup Toggle
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "General UICleanup", yOffset)

    -- Enable Checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 40)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable UICleanup", db.HideBlizzardClutter ~= false,
        function(checked)
            db.HideBlizzardClutter = checked
            ApplyUICleanupState(checked)
            UpdateAllWidgetStates()
            if not db.HideBlizzardClutter then
                NRSKNUI:CreateReloadPrompt("Enabling Blizzard UI elements requires a reload to take full effect.")
            end
        end,
        true,
        "UICleanup",
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

    local hiddenNames = {
        "Objective Tracker Background",
        "Quest Tracker Background",
        "World Quest Tracker Background",
        "Scenario Tracker Background",
        "Monthly Activities Tracker Background",
        "Bonus Objective Tracker Background",
        "Professions Tracker Background",
        "Achievement Tracker Background",
        "Campaign Tracker Background",
    }
    local rowHeight = 165
    local row = GUIFrame:CreateRow(card1.content, rowHeight)
    local textWidget = GUIFrame:CreateText(
        row,
        NRSKNUI:ColorTextByTheme("Hides The Following Frames"),
        function()
            return hiddenNames
        end,
        rowHeight,
        "hide"
    )
    row:AddWidget(textWidget, 1)
    table_insert(allWidgets, textWidget)
    card1:AddRow(row, rowHeight)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall)
    return yOffset
end)

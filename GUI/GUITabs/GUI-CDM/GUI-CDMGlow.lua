-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local table_insert = table.insert
local ipairs = ipairs

-- Helper to get CDMGlow module
local function GetCDMGlowModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("CDMGlow", true)
    end
    return nil
end

-- Register CDMGlow tab content
GUIFrame:RegisterContent("CDMGlow", function(scrollChild, yOffset)
    -- Safety check for database
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.CDMGlow
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get CDMGlow module
    local CDMG = GetCDMGlowModule()

    -- Track widgets for enable/disable logic
    local allWidgets = {} -- All widgets (except main toggle)

    -- Helper to apply new state
    local function ApplyCDMGlowState(enabled)
        if not CDMG then return end
        CDMG.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("CDMGlow")
        else
            NRSKNUI.Addon:DisableModule("CDMGlow")
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
    -- Card 1: CDMGlow Toggle
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "CDM Proc Glow Animation", yOffset)

    -- Enable Checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 40)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Hide Proc Glow Animation", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyCDMGlowState(checked)
            UpdateAllWidgetStates()
            if not db.Enabled then
                NRSKNUI:CreateReloadPrompt("Enabling Blizzard UI elements requires a reload to take full effect.")
            end
        end,
        true,
        "Hide Proc Glow Animation",
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

    local rowHeight = 40
    local row = GUIFrame:CreateRow(card1.content, rowHeight)
    local textWidget = GUIFrame:CreateText(
        row,
        NRSKNUI:ColorTextByTheme("Information"),
        NRSKNUI:ColorTextByTheme("• ") .. "This module hides the proc glow animation and displays the normal glow loop instead.",
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

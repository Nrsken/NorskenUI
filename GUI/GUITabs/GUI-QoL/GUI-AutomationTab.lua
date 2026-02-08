-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local table_insert = table.insert
local ipairs = ipairs

-- Helper to get Automation module
local function GetAutomationModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("Automation", true)
    end
    return nil
end

-- Register Automation tab content
GUIFrame:RegisterContent("Automation", function(scrollChild, yOffset)
    -- Safety check for database
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.Automation
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get Automation module
    local AUTO = GetAutomationModule()

    -- Apply Automation settings
    local function ApplySettings()
        if AUTO then
            AUTO:Apply()
        end
    end

    -- Track widgets for enable/disable logic
    local allWidgets = {} -- All widgets (except main toggle)

    -- Helper to apply new state
    local function ApplyAutomationState(enabled)
        if not AUTO then return end
        AUTO.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("Automation")
        else
            NRSKNUI.Addon:DisableModule("Automation")
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
    -- Card 1: Automation Overview
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Automation", yOffset)

    -- Enable Checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Automation", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyAutomationState(checked)
            UpdateAllWidgetStates()
        end,
        true,
        "Automation",
        "On",
        "Off"
    )
    row1:AddWidget(enableCheck, 0.5)
    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Cinematics & Dialogs
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Cinematics & Dialogs", yOffset)
    table_insert(allWidgets, card2)

    -- Skip Cinematics checkbox
    local row2a = GUIFrame:CreateRow(card2.content, 40)
    local skipCinematicsCheck = GUIFrame:CreateCheckbox(row2a, "Skip Cinematics & Movies",
        db.SkipCinematics ~= false, function(checked)
            db.SkipCinematics = checked
            ApplySettings()
        end)
    row2a:AddWidget(skipCinematicsCheck, 1)
    table_insert(allWidgets, skipCinematicsCheck)
    card2:AddRow(row2a, 40)

    -- Hide Talking Head Frame checkbox
    local row2b = GUIFrame:CreateRow(card2.content, 34)
    local hideTalkingHeadCheck = GUIFrame:CreateCheckbox(row2b, "Hide Talking Head Frame",
        db.HideTalkingHead ~= false, function(checked)
            db.HideTalkingHead = checked
            ApplySettings()
        end)
    row2b:AddWidget(hideTalkingHeadCheck, 1)
    table_insert(allWidgets, hideTalkingHeadCheck)
    card2:AddRow(row2b, 34)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Merchant Automation
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Merchant Automation", yOffset)
    table_insert(allWidgets, card3)

    -- Auto Sell Junk checkbox
    local row3a = GUIFrame:CreateRow(card3.content, 40)
    local autoSellCheck = GUIFrame:CreateCheckbox(row3a, "Auto Sell Junk (Grey Items)", db.AutoSellJunk ~= false,
        function(checked)
            db.AutoSellJunk = checked
            ApplySettings()
        end)
    row3a:AddWidget(autoSellCheck, 1)
    table_insert(allWidgets, autoSellCheck)
    card3:AddRow(row3a, 40)

    -- Auto Repair checkbox
    local row3b = GUIFrame:CreateRow(card3.content, 40)
    local autoRepairCheck = GUIFrame:CreateCheckbox(row3b, "Auto Repair Gear", db.AutoRepair ~= false,
        function(checked)
            db.AutoRepair = checked
            ApplySettings()
        end)
    row3b:AddWidget(autoRepairCheck, 1)
    table_insert(allWidgets, autoRepairCheck)
    card3:AddRow(row3b, 40)

    -- Use Guild Funds checkbox
    local row3c = GUIFrame:CreateRow(card3.content, 34)
    local useGuildCheck = GUIFrame:CreateCheckbox(row3c, "Use Guild Funds for Repair", db.UseGuildFunds ~= false,
        function(checked)
            db.UseGuildFunds = checked
            ApplySettings()
        end)
    row3c:AddWidget(useGuildCheck, 1)
    table_insert(allWidgets, useGuildCheck)
    card3:AddRow(row3c, 34)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Group Finder
    ----------------------------------------------------------------
    local card4 = GUIFrame:CreateCard(scrollChild, "Group Finder", yOffset)
    table_insert(allWidgets, card4)

    -- Auto Accept Role Check checkbox
    local row4 = GUIFrame:CreateRow(card4.content, 34)
    local autoRoleCheck = GUIFrame:CreateCheckbox(row4, "Auto Accept Role Check", db.AutoRoleCheck ~= false,
        function(checked)
            db.AutoRoleCheck = checked
            ApplySettings()
        end)
    row4:AddWidget(autoRoleCheck, 1)
    table_insert(allWidgets, autoRoleCheck)
    card4:AddRow(row4, 34)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 5: Convenience
    ----------------------------------------------------------------
    local card5 = GUIFrame:CreateCard(scrollChild, "Convenience", yOffset)
    table_insert(allWidgets, card5)

    -- Auto-Fill DELETE Text checkbox
    local row5a = GUIFrame:CreateRow(card5.content, 40)
    local autoFillDeleteCheck = GUIFrame:CreateCheckbox(row5a, "Auto-Fill DELETE Text", db.AutoFillDelete ~= false,
        function(checked)
            db.AutoFillDelete = checked
            ApplySettings()
        end)
    row5a:AddWidget(autoFillDeleteCheck, 1)
    table_insert(allWidgets, autoFillDeleteCheck)
    card5:AddRow(row5a, 40)

    -- Auto Loot checkbox
    local row5b = GUIFrame:CreateRow(card5.content, 34)
    local autoLootCheck = GUIFrame:CreateCheckbox(row5b, "Auto Loot", db.AutoLoot ~= false, function(checked)
        db.AutoLoot = checked
        ApplySettings()
    end)
    row5b:AddWidget(autoLootCheck, 1)
    table_insert(allWidgets, autoLootCheck)
    card5:AddRow(row5b, 34)

    yOffset = yOffset + card5:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 4)
    return yOffset
end)

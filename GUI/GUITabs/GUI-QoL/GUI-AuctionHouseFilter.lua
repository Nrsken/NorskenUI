-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization
local table_insert = table.insert
local ipairs = ipairs
local C_AddOns = C_AddOns

-- Get module reference
local function GetModule()
    return NorskenUI:GetModule("AuctionHouseFilter", true)
end

-- Register Auction House Filter tab content
GUIFrame:RegisterContent("AuctionHouseFilter", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.AuctionHouseFilter
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    local AHF = GetModule()
    local allWidgets = {}
    local auctionatorWidgets = {}

    local function ApplyModuleState(enabled)
        if not AHF then return end
        db.Enabled = enabled
        if enabled then
            NorskenUI:EnableModule("AuctionHouseFilter")
        else
            NorskenUI:DisableModule("AuctionHouseFilter")
        end
    end

    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false
        local auctionatorExists = C_AddOns.IsAddOnLoaded("Auctionator") ~= false

        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end

        if mainEnabled then
            for _, widget in ipairs(auctionatorWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(auctionatorExists)
                end
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: Auction House Filter (Master Toggle)
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Auction House Filter", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Auction House Filter", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyModuleState(checked)
            UpdateAllWidgetStates()
        end,
        true, "Auction House Filter", "On", "Off"
    )
    row1:AddWidget(enableCheck, 0.5)
    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Blizzard Auction House
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Blizzard Auction House", yOffset)
    table_insert(allWidgets, card2)

    local row2a = GUIFrame:CreateRow(card2.content, 40)

    -- Current Expansion Toggle
    local ahExpansionCheck = GUIFrame:CreateCheckbox(row2a, "Current Expansion Only",
        db.AuctionHouse.CurrentExpansion ~= false,
        function(checked)
            db.AuctionHouse.CurrentExpansion = checked
        end)
    row2a:AddWidget(ahExpansionCheck, 0.5)
    table_insert(allWidgets, ahExpansionCheck)

    -- Focus Search Bar Toggle
    local ahFocusCheck = GUIFrame:CreateCheckbox(row2a, "Focus Search Bar", db.AuctionHouse.FocusSearchBar == true,
        function(checked)
            db.AuctionHouse.FocusSearchBar = checked
        end)
    row2a:AddWidget(ahFocusCheck, 0.5)
    table_insert(allWidgets, ahFocusCheck)

    card2:AddRow(row2a, 40)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Craft Orders
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Craft Orders", yOffset)
    table_insert(allWidgets, card3)

    local row3a = GUIFrame:CreateRow(card3.content, 40)

    -- Current Expansion Toggle
    local coExpansionCheck = GUIFrame:CreateCheckbox(row3a, "Current Expansion Only",
        db.CraftOrders.CurrentExpansion ~= false,
        function(checked)
            db.CraftOrders.CurrentExpansion = checked
        end)
    row3a:AddWidget(coExpansionCheck, 0.5)
    table_insert(allWidgets, coExpansionCheck)

    -- Focus Search Bar Toggle
    local coFocusCheck = GUIFrame:CreateCheckbox(row3a, "Focus Search Bar", db.CraftOrders.FocusSearchBar == true,
        function(checked)
            db.CraftOrders.FocusSearchBar = checked
        end)
    row3a:AddWidget(coFocusCheck, 0.5)
    table_insert(allWidgets, coFocusCheck)

    card3:AddRow(row3a, 40)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Auctionator
    ----------------------------------------------------------------
    local infoText = "Auctionator"
    if not C_AddOns.IsAddOnLoaded("Auctionator") then
        infoText = "Auctionator: " .. "|cffFFFFFFNot Loaded|r"
    end

    local card4 = GUIFrame:CreateCard(scrollChild, infoText, yOffset)
    table_insert(allWidgets, card4)

    local row4a = GUIFrame:CreateRow(card4.content, 40)

    -- Current Expansion Toggle
    local atrExpansionCheck = GUIFrame:CreateCheckbox(row4a, "Current Expansion Only",
        db.Auctionator.CurrentExpansion ~= false,
        function(checked)
            db.Auctionator.CurrentExpansion = checked
        end)
    row4a:AddWidget(atrExpansionCheck, 0.5)
    table_insert(allWidgets, atrExpansionCheck)
    table_insert(auctionatorWidgets, atrExpansionCheck)

    -- Focus Search Bar Toggle
    local atrFocusCheck = GUIFrame:CreateCheckbox(row4a, "Focus Search Bar", db.Auctionator.FocusSearchBar == true,
        function(checked)
            db.Auctionator.FocusSearchBar = checked
        end)
    row4a:AddWidget(atrFocusCheck, 0.5)
    table_insert(allWidgets, atrFocusCheck)
    table_insert(auctionatorWidgets, atrFocusCheck)
    card4:AddRow(row4a, 40)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 2)
    return yOffset
end)

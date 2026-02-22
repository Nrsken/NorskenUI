-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization
local table_insert = table.insert
local pairs, ipairs = pairs, ipairs

-- Helper to get BlizzardRM module
local function GetBlizzardRMModule()
    if NorskenUI then
        return NorskenUI:GetModule("BlizzardRM", true)
    end
    return nil
end

-- Register BlizzardRM tab content
GUIFrame:RegisterContent("BlizzardRM", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.BlizzardRM
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    local BRMG = GetBlizzardRMModule()
    local allWidgets = {}

    local function ApplySettings()
        if BRMG then
            BRMG:ApplySettings()
        end
    end

    local function ApplyModuleState(enabled)
        if not BRMG then return end
        db.Enabled = enabled
        if enabled then
            NorskenUI:EnableModule("BlizzardRM")
        else
            NorskenUI:DisableModule("BlizzardRM")
        end
    end

    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false

        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: Raid Manager (Enable)
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Raid Manager", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 40)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Raid Manager Styling", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyModuleState(checked)
            UpdateAllWidgetStates()
        end,
        true, "Raid Manager Styling", "On", "Off"
    )
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, 40)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Position Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Position Settings", yOffset)
    table_insert(allWidgets, card2)

    -- Speed Font Size
    local row2 = GUIFrame:CreateRow(card2.content, 40)
    local ySlider = GUIFrame:CreateSlider(row2, "Y Offset", -1100, 100, 1,
        db.Position.YOffset, nil,
        function(val)
            db.Position.YOffset = val
            ApplySettings()
        end)
    row2:AddWidget(ySlider, 1)
    table_insert(allWidgets, ySlider)
    card2:AddRow(row2, 40)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Mouseover Settings
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Mouseover Settings", yOffset)
    table_insert(allWidgets, card3)

    -- Toggle mouseover
    local row3 = GUIFrame:CreateRow(card3.content, 40)
    local useFade = GUIFrame:CreateCheckbox(row3, "Enable Mouseover", db.FadeOnMouseOut ~= false,
        function(checked)
            db.FadeOnMouseOut = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row3:AddWidget(useFade, 1)
    table_insert(allWidgets, useFade)
    card3:AddRow(row3, 40)

    -- Separator
    local row1sep = GUIFrame:CreateRow(card3.content, 8)
    local sepCBCard = GUIFrame:CreateSeparator(row1sep)
    row1sep:AddWidget(sepCBCard, 1)
    table_insert(allWidgets, sepCBCard)
    card3:AddRow(row1sep, 8)

    -- Fade in slider
    local row4 = GUIFrame:CreateRow(card3.content, 40)
    local FadeInDuration = GUIFrame:CreateSlider(row4, "Fade In Duration", 0, 20, 0.1,
        db.FadeInDuration, nil,
        function(val)
            db.FadeInDuration = val
            ApplySettings()
        end)
    row4:AddWidget(FadeInDuration, 0.5)
    table_insert(allWidgets, FadeInDuration)

    -- Fade out slider
    local FadeOutDuration = GUIFrame:CreateSlider(row4, "Fade Out Duration", 0, 20, 0.1,
        db.FadeOutDuration, nil,
        function(val)
            db.FadeOutDuration = val
            ApplySettings()
        end)
    row4:AddWidget(FadeOutDuration, 0.5)
    table_insert(allWidgets, FadeOutDuration)
    card3:AddRow(row4, 40)

    -- Alpha slider
    local row5 = GUIFrame:CreateRow(card3.content, 40)
    local Alpha = GUIFrame:CreateSlider(row5, "Alpha", 0, 1, 0.1,
        db.Alpha, nil,
        function(val)
            db.Alpha = val
            ApplySettings()
        end)
    row5:AddWidget(Alpha, 1)
    table_insert(allWidgets, Alpha)
    card3:AddRow(row5, 40)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 2)
    return yOffset
end)

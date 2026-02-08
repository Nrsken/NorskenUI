-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local table_insert = table.insert
local ipairs = ipairs

-- Helper to get Blizzard Mouseover module
local function GetCopyAnythingModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("CopyAnything", true)
    end
    return nil
end

-- Combat Message Tab Content
GUIFrame:RegisterContent("CopyAnything", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.CopyAnything
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get Combat Message module
    local CopyAnything = GetCopyAnythingModule()

    -- Track widgets for enable/disable logic
    local allWidgets = {} -- All widgets (except main toggle)

    -- Helper to apply new state
    local function ApplyCopyAnythingState(enabled)
        if not CopyAnything then return end
        CopyAnything.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("CopyAnything")
        else
            NRSKNUI.Addon:DisableModule("CopyAnything")
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
    -- Card 1: Copy Anything Enable/Disable
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Copy Anything", yOffset)

    -- Enable Checkbox
    local row1 = GUIFrame:CreateRow(card1.content, 40)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Copy Anything", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyCopyAnythingState(checked)
            UpdateAllWidgetStates()
        end,
        true,
        "Copy Anything",
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

    -- Quick TLDR
    local textRow5abSize = 50
    local row1b = GUIFrame:CreateRow(card1.content, textRow5abSize)
    local chatBubblText = GUIFrame:CreateText(row1b,
        NRSKNUI:ColorTextByTheme("Functionality Info"),
        (NRSKNUI:ColorTextByTheme("• ") .. "Copies SpellID, ItemID, AuraID, MacroID and Unitnames on mouseover\n" ..
            NRSKNUI:ColorTextByTheme("• ") .. "Limited functionality in certain environments because of secret values."),
        textRow5abSize, "hide")
    row1b:AddWidget(chatBubblText, 1)
    table_insert(allWidgets, chatBubblText)
    card1:AddRow(row1b, textRow5abSize)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Copy Anything Keybinding
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Keybinding", yOffset)
    table_insert(allWidgets, card2)

    -- Modkey
    local row2 = GUIFrame:CreateRow(card2.content, 38)
    local modList = {
        ["ctrl"] = "Ctrl",
        ["shift"] = "Shift",
        ["alt"] = "Alt",
        ["ctrl+shift"] = "Ctrl + Shift",
        ["ctrl+alt"] = "Ctrl + Alt",
        ["ctrl+shift+alt"] = "Ctrl + Shift + Alt"
    }
    local modDropdown = GUIFrame:CreateDropdown(row2, "Copy Modifier Key(s)", modList, db.mod, _,
        function(key)
            db.mod = key
        end)
    row2:AddWidget(modDropdown, 0.5)
    table_insert(allWidgets, modDropdown)

    -- keybind text
    local key = GUIFrame:CreateEditBox(row2, "Copy Keybind, Supports Single Letter Only", db.key, function(val)
        db.key = val
    end)
    row2:AddWidget(key, 0.1)
    table_insert(allWidgets, key)
    card2:AddRow(row2, 38)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    -- Apply initial widget states
    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall)
    return yOffset
end)

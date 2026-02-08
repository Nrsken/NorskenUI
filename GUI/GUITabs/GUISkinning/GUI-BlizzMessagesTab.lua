-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.LSM

-- Localization Setup
local pairs, ipairs = pairs, ipairs
local table_insert = table.insert
local table_sort = table.sort

-- Helper to get BlizzardMessages module
local function GetBlizzardMessagesModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("BlizzardMessages", true)
    end
    return nil
end

-- Register Content
GUIFrame:RegisterContent("messages", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.BlizzardMessages
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Get Blizzard Messages module
    local BM = GetBlizzardMessagesModule()

    -- Track widgets for enable/disable logic
    local allWidgets = {} -- All widgets (except main toggle)
    local errorWidgets = {}
    local actionWidgets = {}
    local bubbleWidgets = {}
    local objectiveWidgets = {}
    local zoneWidgets = {}

    -- Apply settings through module
    local function ApplySettings()
        if BM and BM:IsEnabled() then
            BM:Apply()
        end
    end

    -- Preview functions using module methods
    local function ShowErrorPreview()
        if BM then
            BM:PreviewUIErrors()
        end
    end
    local function ShowZonePreview()
        if BM then
            BM:PreviewZone()
        end
    end
    local function ShowActionStatusPreview()
        if BM then
            BM:PreviewActionStatus()
        end
    end

    -- Comprehensive widget state update
    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false
        local errorEnabled = db.UIErrorsFrame and db.UIErrorsFrame.Hide == false
        local actionEnabled = db.ActionStatusText and db.ActionStatusText.Hide == false
        local bubbleEnabled = db.ChatBubbles and db.ChatBubbles.Enabled ~= false
        local objectiveEnabled = db.ObjectiveTracker and db.ObjectiveTracker.Enabled ~= false
        local zoneEnabled = db.ZoneText and db.ZoneText.Hide == false

        -- Apply main enable state to ALL widgets
        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end

        -- Second: Apply conditional states (only if main is enabled, otherwise already disabled)
        if mainEnabled then
            -- Error Text widgets
            for _, widget in ipairs(errorWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(errorEnabled)
                end
            end
            -- Action Text widgets
            for _, widget in ipairs(actionWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(actionEnabled)
                end
            end
            -- Chat Bubble Text widgets
            for _, widget in ipairs(bubbleWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(bubbleEnabled)
                end
            end
            -- Objective Text widgets
            for _, widget in ipairs(objectiveWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(objectiveEnabled)
                end
            end
            -- Zone Text widgets
            for _, widget in ipairs(zoneWidgets) do
                if widget.SetEnabled then
                    widget:SetEnabled(zoneEnabled)
                end
            end
        end
    end

    -- Anchor points list
    local ANCHOR_POINTS = {
        { key = "TOPLEFT",     text = "Top Left" },
        { key = "TOP",         text = "Top" },
        { key = "TOPRIGHT",    text = "Top Right" },
        { key = "LEFT",        text = "Left" },
        { key = "CENTER",      text = "Center" },
        { key = "RIGHT",       text = "Right" },
        { key = "BOTTOMLEFT",  text = "Bottom Left" },
        { key = "BOTTOM",      text = "Bottom" },
        { key = "BOTTOMRIGHT", text = "Bottom Right" },
    }

    local OUTLINE_OPTIONS = {
        { key = "NONE",         text = "None" },
        { key = "OUTLINE",      text = "Outline" },
        { key = "THICKOUTLINE", text = "Thick" },
    }

    -- Build font list
    local function GetFontList()
        local fontList = {}
        if LSM then
            for name in pairs(LSM:HashTable("font")) do
                table_insert(fontList, { key = name, text = name })
            end
            table_sort(fontList, function(a, b) return a.text < b.text end)
        else
            table_insert(fontList, { key = "Friz Quadrata TT", text = "Friz Quadrata TT" })
        end
        return fontList
    end
    local fontList = GetFontList()

    ----------------------------------------------------------------
    -- Card 1: Master Toggle
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Blizzard Texts", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Blizzard Text Skinning", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI.Addon:EnableModule("BlizzardMessages")
                ApplySettings()
            else
                NRSKNUI.Addon:DisableModule("BlizzardMessages")
            end
            UpdateAllWidgetStates()
        end,
        true,
        "Blizzard Text Skinning",
        "On",
        "Off"
    )
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Global Font Settings
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Font Settings For Blizzard Texts", yOffset)
    table_insert(allWidgets, card2)

    -- Font Dropdown
    local row2a = GUIFrame:CreateRow(card2.content, 36)
    local fontDropdown = GUIFrame:CreateDropdown(row2a, "Font", fontList, db.Font or "Friz Quadrata TT", 30,
        function(key)
            db.Font = key
            ApplySettings()
        end)
    row2a:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)

    -- Outline Dropdown
    local outlineDropdown = GUIFrame:CreateDropdown(row2a, "Outline", OUTLINE_OPTIONS, db.FontFlag or "OUTLINE", 45,
        function(key)
            db.FontFlag = key
            ApplySettings()
        end)
    row2a:AddWidget(outlineDropdown, 0.5)
    table_insert(allWidgets, outlineDropdown)
    card2:AddRow(row2a, 36)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Error Messages (UIErrorsFrame)
    ----------------------------------------------------------------
    local errDb = db.UIErrorsFrame
    local card3 = GUIFrame:CreateCard(scrollChild, "Error Messages (Red Text)", yOffset)
    table_insert(allWidgets, card3)

    -- Toggle on/off
    local row3a = GUIFrame:CreateRow(card3.content, 40)
    local hideErrCheck = GUIFrame:CreateCheckbox(row3a, "Hide Error Messages", errDb.Hide == true,
        function(checked)
            errDb.Hide = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row3a:AddWidget(hideErrCheck, 0.5)
    table_insert(allWidgets, hideErrCheck)

    -- Preview Button
    local previewErrBtn = GUIFrame:CreateButton(row3a, "Preview", {
        callback = function() ShowErrorPreview() end,
        width = 80,
    })
    row3a:AddWidget(previewErrBtn, 0.5)
    table_insert(allWidgets, previewErrBtn)
    table_insert(errorWidgets, previewErrBtn)
    card3:AddRow(row3a, 40)

    -- Font Size Slider
    local row3b = GUIFrame:CreateRow(card3.content, 40)
    local errSizeSlider = GUIFrame:CreateSlider(row3b, "Font Size", 8, 24, 1, errDb.Size or 14, 60,
        function(val)
            errDb.Size = val
            ApplySettings()
        end)
    row3b:AddWidget(errSizeSlider, 1)
    table_insert(allWidgets, errSizeSlider)
    table_insert(errorWidgets, errSizeSlider)
    card3:AddRow(row3b, 40)

    -- Separator
    local row3sep = GUIFrame:CreateRow(card3.content, 8)
    local sepAnch1Card = GUIFrame:CreateSeparator(row3sep)
    row3sep:AddWidget(sepAnch1Card, 1)
    table_insert(allWidgets, sepAnch1Card)
    table_insert(errorWidgets, sepAnch1Card)
    card3:AddRow(row3sep, 8)

    -- Anchor Point Dropdown
    local row3c = GUIFrame:CreateRow(card3.content, 42)
    local errAnchorDropdown = GUIFrame:CreateDropdown(row3c, "Anchor", ANCHOR_POINTS,
        errDb.Position.Anchor or "TOP", 50,
        function(key)
            errDb.Position.Anchor = key
            ApplySettings()
        end)
    row3c:AddWidget(errAnchorDropdown, 1)
    table_insert(allWidgets, errAnchorDropdown)
    table_insert(errorWidgets, errAnchorDropdown)
    card3:AddRow(row3c, 42)

    -- X Offset slider
    local row3d = GUIFrame:CreateRow(card3.content, 36)
    local errXSlider = GUIFrame:CreateSlider(row3d, "X Offset", -500, 500, 1, errDb.Position.X or 0, 50,
        function(val)
            errDb.Position.X = val
            ApplySettings()
        end)
    row3d:AddWidget(errXSlider, 0.5)
    table_insert(allWidgets, errXSlider)
    table_insert(errorWidgets, errXSlider)

    -- Y Offset slider
    local errYSlider = GUIFrame:CreateSlider(row3d, "Y Offset", -500, 500, 1, errDb.Position.Y or -281, 50,
        function(val)
            errDb.Position.Y = val
            ApplySettings()
        end)
    row3d:AddWidget(errYSlider, 0.5)
    table_insert(allWidgets, errYSlider)
    table_insert(errorWidgets, errYSlider)
    card3:AddRow(row3d, 36)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Action Status Text
    ----------------------------------------------------------------
    local actDb = db.ActionStatusText
    local card4 = GUIFrame:CreateCard(scrollChild, "Action Status Text (Yellow Text)", yOffset)
    table_insert(allWidgets, card4)

    -- Toggle on/off
    local row4a = GUIFrame:CreateRow(card4.content, 40)
    local hideActCheck = GUIFrame:CreateCheckbox(row4a, "Hide Action Status", actDb.Hide == true, function(checked)
        actDb.Hide = checked
        ApplySettings()
        UpdateAllWidgetStates()
    end)
    row4a:AddWidget(hideActCheck, 0.5)
    table_insert(allWidgets, hideActCheck)

    -- Preview Button
    local previewActBtn = GUIFrame:CreateButton(row4a, "Preview", {
        callback = function() ShowActionStatusPreview() end,
        width = 80,
    })
    row4a:AddWidget(previewActBtn, 0.5)
    table_insert(allWidgets, previewActBtn)
    table_insert(actionWidgets, previewActBtn)
    card4:AddRow(row4a, 40)

    -- Font Size Slider
    local row4b = GUIFrame:CreateRow(card4.content, 40)
    local actSizeSlider = GUIFrame:CreateSlider(row4b, "Font Size", 8, 24, 1, actDb.Size or 14, 60,
        function(val)
            actDb.Size = val
            ApplySettings()
        end)
    row4b:AddWidget(actSizeSlider, 1)
    table_insert(allWidgets, actSizeSlider)
    table_insert(actionWidgets, actSizeSlider)
    card4:AddRow(row4b, 40)

    -- Separator
    local row4sep = GUIFrame:CreateRow(card4.content, 8)
    local sepAnchCard = GUIFrame:CreateSeparator(row4sep)
    row4sep:AddWidget(sepAnchCard, 1)
    table_insert(allWidgets, sepAnchCard)
    table_insert(actionWidgets, sepAnchCard)
    card4:AddRow(row4sep, 8)

    -- Anchor Point Dropdown
    local row4c = GUIFrame:CreateRow(card4.content, 42)
    local actAnchorDropdown = GUIFrame:CreateDropdown(row4c, "Anchor", ANCHOR_POINTS,
        actDb.Position.Anchor or "TOP", 50,
        function(key)
            actDb.Position.Anchor = key
            ApplySettings()
        end)
    row4c:AddWidget(actAnchorDropdown, 1)
    table_insert(allWidgets, actAnchorDropdown)
    table_insert(actionWidgets, actAnchorDropdown)
    card4:AddRow(row4c, 42)

    -- X Offset slider
    local row4d = GUIFrame:CreateRow(card4.content, 36)
    local actXSlider = GUIFrame:CreateSlider(row4d, "X Offset", -500, 500, 1, actDb.Position.X or 0, 50,
        function(val)
            actDb.Position.X = val
            ApplySettings()
        end)
    row4d:AddWidget(actXSlider, 0.5)
    table_insert(allWidgets, actXSlider)
    table_insert(actionWidgets, actXSlider)

    -- Y Offset slider
    local actYSlider = GUIFrame:CreateSlider(row4d, "Y Offset", -500, 500, 1, actDb.Position.Y or -251, 50,
        function(val)
            actDb.Position.Y = val
            ApplySettings()
        end)
    row4d:AddWidget(actYSlider, 0.5)
    table_insert(allWidgets, actYSlider)
    table_insert(actionWidgets, actYSlider)
    card4:AddRow(row4d, 36)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 5: Chat Bubbles
    ----------------------------------------------------------------
    local bubbleDb = db.ChatBubbles
    local card5 = GUIFrame:CreateCard(scrollChild, "Chat Bubbles", yOffset)
    table_insert(allWidgets, card5)

    -- Toggle on/off
    local row5a = GUIFrame:CreateRow(card5.content, 40)
    local enableBubblesCheck = GUIFrame:CreateCheckbox(row5a, "Enable Chat Bubble Styling",
        bubbleDb.Enabled ~= false, function(checked)
            bubbleDb.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row5a:AddWidget(enableBubblesCheck, 0.5)
    table_insert(allWidgets, enableBubblesCheck)

    -- Font Size Slider
    local bubbleSizeSlider = GUIFrame:CreateSlider(row5a, "Font Size", 6, 18, 1, bubbleDb.Size or 8, 60,
        function(val)
            bubbleDb.Size = val
            ApplySettings()
        end)
    row5a:AddWidget(bubbleSizeSlider, 0.5)
    table_insert(allWidgets, bubbleSizeSlider)
    table_insert(bubbleWidgets, bubbleSizeSlider)
    card5:AddRow(row5a, 40)

    -- Separator
    local row5sep = GUIFrame:CreateRow(card5.content, 8)
    local sepCBCard = GUIFrame:CreateSeparator(row5sep)
    row5sep:AddWidget(sepCBCard, 1)
    table_insert(allWidgets, sepCBCard)
    table_insert(bubbleWidgets, sepCBCard)
    card5:AddRow(row5sep, 8)

    -- Text + Button widgets for Luckyones's chat bubble text replacement
    local textRow5abSize = 145
    local row5ab = GUIFrame:CreateRow(card5.content, textRow5abSize)
    local chatBubblText = GUIFrame:CreateText(row5ab,
        NRSKNUI:ColorTextByTheme("Recommended"),
        ("ChatBubbleReplacements by " .. "|cff00e0ffLuckyone. |r" ..
            "\nReplaces backdrop with custom styling.\n\n" ..
            NRSKNUI:ColorTextByTheme("Available modes") .. "\n" ..
            NRSKNUI:ColorTextByTheme("• ") .. "Invisible Backdrop" ..
            "\n" .. NRSKNUI:ColorTextByTheme("• ") .. "Small Backdrop" ..
            "\n" .. NRSKNUI:ColorTextByTheme("• ") .. "Medium Backdrop" ..
            "\n" .. NRSKNUI:ColorTextByTheme("• ") .. "Large Backdrop"),
        textRow5abSize, "hide")
    row5ab:AddWidget(chatBubblText, 0.5)
    table_insert(allWidgets, chatBubblText)
    table_insert(bubbleWidgets, chatBubblText)
    local textureLinkActBtn = GUIFrame:CreateButton(row5ab, "Get Skin Here", {
        callback = function()
            NRSKNUI:CreatePrompt(
                "ChatBubbleReplacements By |cff00e0ffLuckyone|r",
                "https://github.com/Luckyone961/ChatBubbleReplacements",
                true,
                "Copy to clipboard by pressing CTRL + C",
                true
            )
        end,
        _,
        _,
        width = 80,
        height = 40
    })
    row5ab:AddWidget(textureLinkActBtn, 0.5)
    table_insert(allWidgets, textureLinkActBtn)
    table_insert(bubbleWidgets, textureLinkActBtn)
    card5:AddRow(row5ab, textRow5abSize)

    yOffset = yOffset + card5:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 6: Objective Tracker
    ----------------------------------------------------------------
    local objDb = db.ObjectiveTracker
    local card6 = GUIFrame:CreateCard(scrollChild, "Objective Tracker", yOffset)
    table_insert(allWidgets, card6)

    -- Toggle on/off
    local row6a = GUIFrame:CreateRow(card6.content, 40)
    local enableObjCheck = GUIFrame:CreateCheckbox(row6a, "Enable Objective Tracker Styling",
        objDb.Enabled ~= false, function(checked)
            objDb.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row6a:AddWidget(enableObjCheck, 1)
    table_insert(allWidgets, enableObjCheck)
    card6:AddRow(row6a, 40)

    -- Title Font Size Slider
    local row6b = GUIFrame:CreateRow(card6.content, 36)
    local questTitleSlider = GUIFrame:CreateSlider(row6b, "Quest Title Size", 8, 20, 1, objDb.QuestTitleSize or 13,
        80,
        function(val)
            objDb.QuestTitleSize = val
            ApplySettings()
        end)
    row6b:AddWidget(questTitleSlider, 0.5)
    table_insert(allWidgets, questTitleSlider)
    table_insert(objectiveWidgets, questTitleSlider)

    -- QuestFont Size Slider
    local questTextSlider = GUIFrame:CreateSlider(row6b, "Quest Text Size", 8, 20, 1, objDb.QuestTextSize or 12, 80,
        function(val)
            objDb.QuestTextSize = val
            ApplySettings()
        end)
    row6b:AddWidget(questTextSlider, 0.5)
    table_insert(allWidgets, questTextSlider)
    table_insert(objectiveWidgets, questTextSlider)
    card6:AddRow(row6b, 36)

    yOffset = yOffset + card6:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 7: Zone Texts
    ----------------------------------------------------------------
    local zoneDB = db.ZoneText
    local card7 = GUIFrame:CreateCard(scrollChild, "Zone Texts", yOffset)
    table_insert(allWidgets, card7)

    -- Toggle on/off
    local row7 = GUIFrame:CreateRow(card7.content, 40)
    local ZoneTextHide = GUIFrame:CreateCheckbox(row7, "Hide Zone Texts",
        zoneDB.Hide == true, function(checked)
            zoneDB.Hide = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end)
    row7:AddWidget(ZoneTextHide, 0.5)
    table_insert(allWidgets, ZoneTextHide)

    -- Preview Button
    local previewZoneBtn = GUIFrame:CreateButton(row7, "Preview", {
        callback = function() ShowZonePreview() end,
        width = 80,
    })
    row7:AddWidget(previewZoneBtn, 0.5)
    table_insert(allWidgets, previewZoneBtn)
    table_insert(zoneWidgets, previewZoneBtn)
    card7:AddRow(row7, 40)

    -- Title Font Size Slider
    local row8 = GUIFrame:CreateRow(card7.content, 36)
    local MainZoneSize = GUIFrame:CreateSlider(row8, "Main Zone Size", 8, 100, 1, zoneDB.MainZone.Size,
        80,
        function(val)
            zoneDB.MainZone.Size = val
            ApplySettings()
        end)
    row8:AddWidget(MainZoneSize, 0.5)
    table_insert(allWidgets, MainZoneSize)
    table_insert(zoneWidgets, MainZoneSize)

    -- QuestFont Size Slider
    local SubZoneSize = GUIFrame:CreateSlider(row8, "Sub Zone Size", 8, 100, 1, zoneDB.SubZone.Size, _,
        function(val)
            zoneDB.SubZone.Size = val
            ApplySettings()
        end)
    row8:AddWidget(SubZoneSize, 0.5)
    table_insert(allWidgets, SubZoneSize)
    table_insert(zoneWidgets, SubZoneSize)
    card7:AddRow(row8, 36)

    -- Separator
    local row7sep = GUIFrame:CreateRow(card7.content, 8)
    local sepZoneCard = GUIFrame:CreateSeparator(row7sep)
    row7sep:AddWidget(sepZoneCard, 1)
    table_insert(allWidgets, sepZoneCard)
    table_insert(zoneWidgets, sepZoneCard)
    card7:AddRow(row7sep, 8)

    -- Anchor Point Dropdown
    local row9 = GUIFrame:CreateRow(card7.content, 42)
    local zoneAnchorDropdown = GUIFrame:CreateDropdown(row9, "Anchor", ANCHOR_POINTS,
        zoneDB.MainZone.Anchor or "TOP", 50,
        function(key)
            zoneDB.MainZone.Anchor = key
            ApplySettings()
        end)
    row9:AddWidget(zoneAnchorDropdown, 1)
    table_insert(allWidgets, zoneAnchorDropdown)
    table_insert(zoneWidgets, zoneAnchorDropdown)
    card7:AddRow(row9, 42)

    -- X Offset slider
    local row10 = GUIFrame:CreateRow(card7.content, 36)
    local zoneXSlider = GUIFrame:CreateSlider(row10, "X Offset", -500, 500, 1, zoneDB.MainZone.X, 50,
        function(val)
            zoneDB.MainZone.X = val
            ApplySettings()
        end)
    row10:AddWidget(zoneXSlider, 0.5)
    table_insert(allWidgets, zoneXSlider)
    table_insert(zoneWidgets, zoneXSlider)

    -- Y Offset slider
    local zoneYSlider = GUIFrame:CreateSlider(row10, "Y Offset", -500, 500, 1, zoneDB.MainZone.Y, 50,
        function(val)
            zoneDB.MainZone.Y = val
            ApplySettings()
        end)
    row10:AddWidget(zoneYSlider, 0.5)
    table_insert(allWidgets, zoneYSlider)
    table_insert(zoneWidgets, zoneYSlider)
    card7:AddRow(row10, 36)
    
    yOffset = yOffset + card7:GetContentHeight() + Theme.paddingSmall

    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 5)
    return yOffset
end)

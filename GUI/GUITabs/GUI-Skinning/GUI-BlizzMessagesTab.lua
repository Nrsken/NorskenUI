---@class NRSKNUI
local NRSKNUI = select(2, ...)

local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local table_insert = table.insert

local SIDEBAR_WIDTH = 192
local ITEM_HEIGHT = 34
local LIST_PADDING = 4

local selectedItem = "General"

local SIDEBAR_ITEMS = {
    { key = "UIErrorsFrame",    name = "Error Text",         order = 1 },
    { key = "ActionStatusText", name = "Action Status Text", order = 2 },
    { key = "ZoneText",         name = "Zone Texts",         order = 3 },
    { key = "ChatBubbles",      name = "Chat Bubbles",       order = 4 },
}

GUIFrame:RegisterPanel("messages", function(container)
    if NRSKNUI:ShouldNotLoadModule() then return nil end
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.BlizzardMessages
    if not db then return nil end

    local mod = NRSKNUI:GetModule("BlizzardMessages", true)

    local function ApplySettings()
        if mod and mod.ApplySettings then mod:ApplySettings() end
    end

    local function RefreshContent()
        C_Timer.After(0.05, function()
            GUIFrame:RefreshContent()
        end)
    end

    local manager = GUIFrame:CreateWidgetStateManager()

    local function UpdateAllWidgetStates()
        manager:UpdateAll(db.Enabled)
    end

    local function GetSidebarItems()
        local items = {}
        for _, item in ipairs(SIDEBAR_ITEMS) do
            table_insert(items, {
                key = item.key,
                name = item.name,
                order = item.order,
            })
        end
        table.sort(items, function(a, b) return a.order < b.order end)
        return items
    end

    local miniSidebar = NRSKNUI.GUI.CreateMiniSidebar(container, {
        sidebarWidth = SIDEBAR_WIDTH,
        listPadding = LIST_PADDING,
        itemHeight = ITEM_HEIGHT,

        getItems = GetSidebarItems,
        getItemKey = function(item) return item.key end,

        renderItem = function(btn, item, isSelected)
            btn._icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
            NRSKNUI:ApplyZoom(btn._icon, NRSKNUI.GlobalZoom)

            btn._label:SetShadowColor(0, 0, 0, 0)
            btn._label:SetText(item.name)

            if isSelected then
                btn._label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            else
                btn._label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
            end
        end,

        onItemSelected = function(item)
            selectedItem = item.key
            RefreshContent()
        end,

        buttonArea = {
            buttonHeight = ITEM_HEIGHT,
            hideSeparator = false,
            listSpacing = 8,
            buttons = {
                {
                    text = "General Settings",
                    onClick = function()
                        selectedItem = "General"
                        RefreshContent()
                    end,
                },
            },
        },
    })

    miniSidebar.SelectItem(selectedItem)
    miniSidebar.RefreshList()

    local contentChild = miniSidebar.contentArea.scrollChild
    local yOffset = Theme.paddingSmall

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

    if selectedItem == "General" then
        -- Card 1: Enable Toggle
        local card1 = GUIFrame:CreateCard(contentChild, "Blizzard Texts", yOffset)
        miniSidebar.contentArea.RegisterCard(card1)

        local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
        local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Blizzard Text Skinning", {
            value = db.Enabled ~= false,
            callback = function(checked)
                db.Enabled = checked
                if mod then
                    if checked then
                        NRSKNUI:EnableModule("BlizzardMessages")
                    else
                        NRSKNUI:DisableModule("BlizzardMessages")
                        NRSKNUI:CreateReloadPrompt(
                            "Restoring default Blizzard text elements requires a reload to take full effect.")
                    end
                end
                ApplySettings()
                UpdateAllWidgetStates()
            end,
            msgPopup = true,
            msgText = "Blizzard Text Skinning",
        })
        row1:AddWidget(enableCheck, 1)
        card1:AddRow(row1, Theme.rowHeightLast, 0)

        yOffset = card1:GetNextOffset()

        -- Card 2: Font Settings
        local fontCard
        fontCard, yOffset = GUIFrame:CreateFontSettingsCard(contentChild, yOffset, {
            title = "Font Settings",
            db = db,
            dbKeys = {
                fontFace = "FontFace",
                fontOutline = "FontOutline",
            },
            hideFontSize = true,
            includeSoftOutline = false,
            onChangeCallback = ApplySettings,
            globalOverride = {},
        })
        miniSidebar.contentArea.RegisterCard(fontCard)
        manager:Register(fontCard, "all")

        yOffset = fontCard:GetNextOffset()
    elseif selectedItem == "UIErrorsFrame" then
        local errDb = db.UIErrorsFrame
        manager:SetCondition("errEnabled", function() return not errDb.Hide end)

        -- Card 1
        local card1 = GUIFrame:CreateCard(contentChild, "Error Text", yOffset)
        miniSidebar.contentArea.RegisterCard(card1)

        local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
        local hideCheck = GUIFrame:CreateCheckbox(row1, "Hide Error Messages", {
            value = errDb.Hide,
            callback = function(checked)
                errDb.Hide = checked
                ApplySettings()
                UpdateAllWidgetStates()
            end
        })
        row1:AddWidget(hideCheck, (2 / 3))

        local previewBtn = GUIFrame:CreateButton(row1, "Preview", {
            callback = function()
                if mod and mod.PreviewUIErrors then mod:PreviewUIErrors() end
            end,
            height = 30,
        })
        row1:AddWidget(previewBtn, (1 / 3), nil, 0, -6)
        manager:Register(previewBtn, "all", "errEnabled")
        card1:AddRow(row1, Theme.rowHeight)

        local sep1 = GUIFrame:CreateSeparator(card1.content)
        card1:AddRow(sep1, Theme.rowHeightSeparator)
        manager:Register(sep1, "all", "errEnabled")

        local row2 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
        local sizeSlider = GUIFrame:CreateSlider(row2, "Font Size", {
            min = 8,
            max = 24,
            step = 1,
            value = errDb.Size,
            callback = function(val)
                errDb.Size = val
                ApplySettings()
            end
        })
        row2:AddWidget(sizeSlider, 1)
        manager:Register(sizeSlider, "all", "errEnabled")
        card1:AddRow(row2, Theme.rowHeightLast, 0)

        yOffset = card1:GetNextOffset()

        -- Card 2: Position
        local card2 = GUIFrame:CreateCard(contentChild, "Position", yOffset)
        miniSidebar.contentArea.RegisterCard(card2)
        manager:Register(card2, "all", "errEnabled")

        local row3 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
        local anchorDropdown = GUIFrame:CreateDropdown(row3, "Anchor", {
            options = ANCHOR_POINTS,
            value = errDb.Position.Anchor,
            labelWidth = 50,
            callback = function(key)
                errDb.Position.Anchor = key
                ApplySettings()
            end
        })
        row3:AddWidget(anchorDropdown, 1)
        manager:Register(anchorDropdown, "all", "errEnabled")
        card2:AddRow(row3, Theme.rowHeight)

        local sep2 = GUIFrame:CreateSeparator(card2.content)
        card2:AddRow(sep2, Theme.rowHeightSeparator)
        manager:Register(sep2, "all", "errEnabled")

        local row4 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
        local xSlider = GUIFrame:CreateSlider(row4, "X Offset", {
            min = -500,
            max = 500,
            step = 1,
            value = errDb.Position.X,
            labelWidth = 50,
            callback = function(val)
                errDb.Position.X = val
                ApplySettings()
            end
        })
        row4:AddWidget(xSlider, 0.5)
        manager:Register(xSlider, "all", "errEnabled")

        local ySlider = GUIFrame:CreateSlider(row4, "Y Offset", {
            min = -500,
            max = 500,
            step = 1,
            value = errDb.Position.Y,
            labelWidth = 50,
            callback = function(val)
                errDb.Position.Y = val
                ApplySettings()
            end
        })
        row4:AddWidget(ySlider, 0.5)
        manager:Register(ySlider, "all", "errEnabled")
        card2:AddRow(row4, Theme.rowHeightLast, 0)

        yOffset = card2:GetNextOffset()
        UpdateAllWidgetStates()
    elseif selectedItem == "ActionStatusText" then
        local actDb = db.ActionStatusText
        manager:SetCondition("actEnabled", function() return not actDb.Hide end)

        -- Card 1
        local card1 = GUIFrame:CreateCard(contentChild, "Action Status Text", yOffset)
        miniSidebar.contentArea.RegisterCard(card1)

        local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
        local hideCheck = GUIFrame:CreateCheckbox(row1, "Hide Action Status", {
            value = actDb.Hide,
            callback = function(checked)
                actDb.Hide = checked
                ApplySettings()
                UpdateAllWidgetStates()
            end
        })
        row1:AddWidget(hideCheck, (2 / 3))

        local previewBtn = GUIFrame:CreateButton(row1, "Preview", {
            callback = function()
                if mod and mod.PreviewActionStatus then mod:PreviewActionStatus() end
            end,
            height = 30,
        })
        row1:AddWidget(previewBtn, (1 / 3), nil, 0, -6)
        manager:Register(previewBtn, "all", "actEnabled")
        card1:AddRow(row1, Theme.rowHeight)

        local sep1 = GUIFrame:CreateSeparator(card1.content)
        card1:AddRow(sep1, Theme.rowHeightSeparator)
        manager:Register(sep1, "all", "actEnabled")

        local row2 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
        local sizeSlider = GUIFrame:CreateSlider(row2, "Font Size", {
            min = 8,
            max = 24,
            step = 1,
            value = actDb.Size,
            callback = function(val)
                actDb.Size = val
                ApplySettings()
            end
        })
        row2:AddWidget(sizeSlider, 1)
        manager:Register(sizeSlider, "all", "actEnabled")
        card1:AddRow(row2, Theme.rowHeightLast, 0)

        yOffset = card1:GetNextOffset()

        -- Card 2: Position
        local card2 = GUIFrame:CreateCard(contentChild, "Position", yOffset)
        miniSidebar.contentArea.RegisterCard(card2)
        manager:Register(card2, "all", "actEnabled")

        local row3 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
        local anchorDropdown = GUIFrame:CreateDropdown(row3, "Anchor", {
            options = ANCHOR_POINTS,
            value = actDb.Position.Anchor,
            labelWidth = 50,
            callback = function(key)
                actDb.Position.Anchor = key
                ApplySettings()
            end
        })
        row3:AddWidget(anchorDropdown, 1)
        manager:Register(anchorDropdown, "all", "actEnabled")
        card2:AddRow(row3, Theme.rowHeight)

        local sep2 = GUIFrame:CreateSeparator(card2.content)
        card2:AddRow(sep2, Theme.rowHeightSeparator)
        manager:Register(sep2, "all", "actEnabled")

        local row4 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
        local xSlider = GUIFrame:CreateSlider(row4, "X Offset", {
            min = -500,
            max = 500,
            step = 1,
            value = actDb.Position.X,
            labelWidth = 50,
            callback = function(val)
                actDb.Position.X = val
                ApplySettings()
            end
        })
        row4:AddWidget(xSlider, 0.5)
        manager:Register(xSlider, "all", "actEnabled")

        local ySlider = GUIFrame:CreateSlider(row4, "Y Offset", {
            min = -500,
            max = 500,
            step = 1,
            value = actDb.Position.Y,
            labelWidth = 50,
            callback = function(val)
                actDb.Position.Y = val
                ApplySettings()
            end
        })
        row4:AddWidget(ySlider, 0.5)
        manager:Register(ySlider, "all", "actEnabled")
        card2:AddRow(row4, Theme.rowHeightLast, 0)

        yOffset = card2:GetNextOffset()
        UpdateAllWidgetStates()
    elseif selectedItem == "ZoneText" then
        local zoneDb = db.ZoneText
        manager:SetCondition("zoneEnabled", function() return not zoneDb.Hide end)

        -- Card 1
        local card1 = GUIFrame:CreateCard(contentChild, "Zone Texts", yOffset)
        miniSidebar.contentArea.RegisterCard(card1)

        local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
        local hideCheck = GUIFrame:CreateCheckbox(row1, "Hide Zone Texts", {
            value = zoneDb.Hide,
            callback = function(checked)
                zoneDb.Hide = checked
                ApplySettings()
                UpdateAllWidgetStates()
            end
        })
        row1:AddWidget(hideCheck, (2 / 3))

        local previewBtn = GUIFrame:CreateButton(row1, "Preview", {
            callback = function()
                if mod and mod.PreviewZone then mod:PreviewZone() end
            end,
            height = 30,
        })
        row1:AddWidget(previewBtn, (1 / 3), nil, 0, -6)
        manager:Register(previewBtn, "all", "zoneEnabled")
        card1:AddRow(row1, Theme.rowHeight)

        local sep1 = GUIFrame:CreateSeparator(card1.content)
        card1:AddRow(sep1, Theme.rowHeightSeparator)
        manager:Register(sep1, "all", "zoneEnabled")

        local row2 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
        local mainSizeSlider = GUIFrame:CreateSlider(row2, "Main Zone Size", {
            min = 8,
            max = 100,
            step = 1,
            value = zoneDb.MainZone.Size,
            labelWidth = 90,
            callback = function(val)
                zoneDb.MainZone.Size = val
                ApplySettings()
            end
        })
        row2:AddWidget(mainSizeSlider, 0.5)
        manager:Register(mainSizeSlider, "all", "zoneEnabled")

        local subSizeSlider = GUIFrame:CreateSlider(row2, "Sub Zone Size", {
            min = 8,
            max = 100,
            step = 1,
            value = zoneDb.SubZone.Size,
            labelWidth = 80,
            callback = function(val)
                zoneDb.SubZone.Size = val
                ApplySettings()
            end
        })
        row2:AddWidget(subSizeSlider, 0.5)
        manager:Register(subSizeSlider, "all", "zoneEnabled")
        card1:AddRow(row2, Theme.rowHeightLast, 0)

        yOffset = card1:GetNextOffset()

        -- Card 2: Position
        local card2 = GUIFrame:CreateCard(contentChild, "Position", yOffset)
        miniSidebar.contentArea.RegisterCard(card2)
        manager:Register(card2, "all", "zoneEnabled")

        local row3 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
        local anchorDropdown = GUIFrame:CreateDropdown(row3, "Anchor", {
            options = ANCHOR_POINTS,
            value = zoneDb.MainZone.Anchor,
            labelWidth = 50,
            callback = function(key)
                zoneDb.MainZone.Anchor = key
                ApplySettings()
            end
        })
        row3:AddWidget(anchorDropdown, 1)
        manager:Register(anchorDropdown, "all", "zoneEnabled")
        card2:AddRow(row3, Theme.rowHeight)

        local sep2 = GUIFrame:CreateSeparator(card2.content)
        card2:AddRow(sep2, Theme.rowHeightSeparator)
        manager:Register(sep2, "all", "zoneEnabled")

        local row4 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
        local xSlider = GUIFrame:CreateSlider(row4, "X Offset", {
            min = -500,
            max = 500,
            step = 1,
            value = zoneDb.MainZone.X,
            labelWidth = 50,
            callback = function(val)
                zoneDb.MainZone.X = val
                ApplySettings()
            end
        })
        row4:AddWidget(xSlider, 0.5)
        manager:Register(xSlider, "all", "zoneEnabled")

        local ySlider = GUIFrame:CreateSlider(row4, "Y Offset", {
            min = -500,
            max = 500,
            step = 1,
            value = zoneDb.MainZone.Y,
            labelWidth = 50,
            callback = function(val)
                zoneDb.MainZone.Y = val
                ApplySettings()
            end
        })
        row4:AddWidget(ySlider, 0.5)
        manager:Register(ySlider, "all", "zoneEnabled")
        card2:AddRow(row4, Theme.rowHeightLast, 0)

        yOffset = card2:GetNextOffset()
        UpdateAllWidgetStates()
    elseif selectedItem == "ChatBubbles" then
        local bubbleDb = db.ChatBubbles
        manager:SetCondition("bubbleEnabled", function() return bubbleDb.Enabled end)

        -- Card 1
        local card1 = GUIFrame:CreateCard(contentChild, "Chat Bubbles", yOffset)
        miniSidebar.contentArea.RegisterCard(card1)

        local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
        local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Chat Bubble Styling", {
            value = bubbleDb.Enabled,
            callback = function(checked)
                bubbleDb.Enabled = checked
                ApplySettings()
                UpdateAllWidgetStates()
            end
        })
        row1:AddWidget(enableCheck, 0.5)

        local sizeSlider = GUIFrame:CreateSlider(row1, "Font Size", {
            min = 6,
            max = 18,
            step = 1,
            value = bubbleDb.Size,
            callback = function(val)
                bubbleDb.Size = val
                ApplySettings()
            end
        })
        row1:AddWidget(sizeSlider, 0.5)
        manager:Register(sizeSlider, "all", "bubbleEnabled")
        card1:AddRow(row1, Theme.rowHeightLast, 0)

        yOffset = card1:GetNextOffset()

        -- Card 2: Recommended addon
        local card2 = GUIFrame:CreateCard(contentChild, "Recommended", yOffset)
        miniSidebar.contentArea.RegisterCard(card2)
        manager:Register(card2, "all", "bubbleEnabled")

        local bubbleHeight = 150
        local textRow = GUIFrame:CreateRow(card2.content, bubbleHeight)
        local infoText = GUIFrame:CreateText(textRow, NRSKNUI:ColorTextByTheme("Chat Bubble Replacements"), {
            text = ("ChatBubbleReplacements by " .. "|cff00e0ffLuckyone|r" ..
                "\nReplaces backdrop with custom styling.\n\n" ..
                NRSKNUI:ColorTextByTheme("Available modes") .. "\n" ..
                NRSKNUI:ColorTextByTheme("• ") .. "Invisible Backdrop\n" ..
                NRSKNUI:ColorTextByTheme("• ") .. "Small Backdrop\n" ..
                NRSKNUI:ColorTextByTheme("• ") .. "Medium Backdrop\n" ..
                NRSKNUI:ColorTextByTheme("• ") .. "Large Backdrop"),
            height = bubbleHeight,
            bgMode = "hide"
        })
        textRow:AddWidget(infoText, 0.6)
        manager:Register(infoText, "all", "bubbleEnabled")

        local linkBtn = GUIFrame:CreateButton(textRow, "Get Skin Here", {
            callback = function()
                NRSKNUI:CreateCopyDialog(
                    "ChatBubbleReplacements By |cff00e0ffLuckyone|r",
                    "https://github.com/Luckyone961/ChatBubbleReplacements",
                    "Copy to clipboard by pressing CTRL + C"
                )
            end,
            width = 100,
            height = 36,
        })
        textRow:AddWidget(linkBtn, 0.4)
        manager:Register(linkBtn, "all", "bubbleEnabled")
        card2:AddRow(textRow, bubbleHeight, 0)

        yOffset = card2:GetNextOffset()
        UpdateAllWidgetStates()
    end

    miniSidebar.contentArea.SetContentHeight(yOffset)
    C_Timer.After(0, function()
        miniSidebar.contentArea.UpdateScrollBarVisibility()
        miniSidebar.contentArea.UpdateCardWidths()
    end)

    return miniSidebar.panel
end)

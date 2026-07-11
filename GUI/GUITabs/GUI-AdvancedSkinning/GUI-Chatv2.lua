---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

local pairs = pairs
local ReloadUI = ReloadUI

local SUB_TABS = {
    { id = "general", text = "General" },
    { id = "text",    text = "Text Settings" },
    { id = "tabs",    text = "Tab Settings" },
    { id = "sounds",  text = "Sounds" },
}

local TAB_BAR_HEIGHT = 30

local currentSubTab = "general"

local TIMESTAMP_FORMATS = {
    { value = "NONE",           text = "None" },
    { value = "[%H:%M] ",       text = "[HH:MM]" },
    { value = "[%H:%M:%S] ",    text = "[HH:MM:SS]" },
    { value = "[%I:%M %p] ",    text = "[HH:MM AM/PM]" },
    { value = "[%I:%M:%S %p] ", text = "[HH:MM:SS AM/PM]" },
    { value = "%H:%M ",         text = "HH:MM" },
    { value = "%H:%M:%S ",      text = "HH:MM:SS" },
    { value = "%I:%M %p ",      text = "HH:MM AM/PM" },
    { value = "%I:%M:%S %p ",   text = "HH:MM:SS AM/PM" },
}

local TAB_SELECTOR_STYLES = {
    { value = "NONE",   text = "None" },
    { value = "ARROW",  text = ">Text<" },
    { value = "ARROW1", text = "> Text <" },
    { value = "ARROW2", text = "<Text>" },
    { value = "ARROW3", text = "< Text >" },
    { value = "BOX",    text = "[Text]" },
    { value = "BOX1",   text = "[ Text ]" },
    { value = "CURLY",  text = "{Text}" },
    { value = "CURLY1", text = "{ Text }" },
    { value = "CURVE",  text = "(Text)" },
    { value = "CURVE1", text = "( Text )" },
}

local function ApplySettings()
    local mod = NRSKNUI:GetModule("Chatv2", true)
    if mod and mod.ApplySettings then mod:ApplySettings() end
end

local function RenderGeneralTab(scrollChild, db, manager)
    local yOffset = Theme.paddingSmall

    -- Card 1: Enable Toggle
    local card1 = GUIFrame:CreateCard(scrollChild, "Chat", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Custom Chat Panel", {
        value = db.Enabled ~= false,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule("Chatv2")
                manager:UpdateAll(db.Enabled)
            else
                NRSKNUI:DisableModule("Chatv2")
                manager:UpdateAll(db.Enabled)
                NRSKNUI:CreatePrompt({
                    title = "Chat Module Disabled",
                    text = "The chat module has been disabled.\n\nA UI reload is recommended to fully restore the default chat.",
                    onAccept = function() ReloadUI() end,
                    acceptText = "Reload Now",
                    cancelText = "Later",
                })
            end
        end,
        msgPopup = true,
        msgText = "Chatv2",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Panel Size
    local card2 = GUIFrame:CreateCard(scrollChild, "Panel Size", yOffset)
    manager:Register(card2, "all")

    local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local widthSlider = GUIFrame:CreateSlider(row2, "Width", {
        min = 200,
        max = 800,
        step = 1,
        value = db.Width or 450,
        callback = function(val)
            db.Width = val
            ApplySettings()
        end
    })
    row2:AddWidget(widthSlider, 0.5)
    manager:Register(widthSlider, "all")

    local heightSlider = GUIFrame:CreateSlider(row2, "Height", {
        min = 100,
        max = 600,
        step = 1,
        value = db.Height or 250,
        callback = function(val)
            db.Height = val
            ApplySettings()
        end
    })
    row2:AddWidget(heightSlider, 0.5)
    manager:Register(heightSlider, "all")
    card2:AddRow(row2, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Backdrop Settings
    local card3 = GUIFrame:CreateCard(scrollChild, "Backdrop", yOffset)
    manager:Register(card3, "all")

    db.Backdrop = db.Backdrop or {}

    local row3 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local backdropCheck = GUIFrame:CreateCheckbox(row3, "Enable Backdrop", {
        value = db.Backdrop.Enabled ~= false,
        callback = function(checked)
            db.Backdrop.Enabled = checked
            ApplySettings()
            manager:UpdateAll(db.Enabled)
        end
    })
    row3:AddWidget(backdropCheck, 1)
    manager:Register(backdropCheck, "all")
    card3:AddRow(row3, Theme.rowHeight)

    manager:SetCondition("backdropWidgets", function() return db.Backdrop.Enabled ~= false end)

    local row4 = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local backdropColor = GUIFrame:CreateColorPicker(row4, "Background", {
        color = db.Backdrop.Color or { 0, 0, 0, 0.6 },
        callback = function(r, g, b, a)
            db.Backdrop.Color = { r, g, b, a }
            ApplySettings()
        end
    })
    row4:AddWidget(backdropColor, 0.5)
    manager:Register(backdropColor, "all", "backdropWidgets")

    local borderColor = GUIFrame:CreateColorPicker(row4, "Border", {
        color = db.Backdrop.BorderColor or { 0, 0, 0, 1 },
        callback = function(r, g, b, a)
            db.Backdrop.BorderColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row4:AddWidget(borderColor, 0.5)
    manager:Register(borderColor, "all", "backdropWidgets")
    card3:AddRow(row4, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card 4: Editbox & History
    local card4 = GUIFrame:CreateCard(scrollChild, "Editbox & History", yOffset)
    manager:Register(card4, "all")

    local row5 = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local editboxPosDropdown = GUIFrame:CreateDropdown(row5, "Editbox Position", {
        value = db.EditBoxPosition or "BELOW_CHAT",
        options = {
            { value = "BELOW_CHAT",        text = "Below Chat" },
            { value = "BELOW_CHAT_INSIDE", text = "Below Chat (Inside)" },
            { value = "ABOVE_CHAT",        text = "Above Chat" },
            { value = "ABOVE_CHAT_INSIDE", text = "Above Chat (Inside)" },
        },
        callback = function(val)
            db.EditBoxPosition = val
            ApplySettings()
        end
    })
    row5:AddWidget(editboxPosDropdown, 1)
    manager:Register(editboxPosDropdown, "all")
    card4:AddRow(row5, Theme.rowHeight)

    local row6 = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
    local maxLinesSlider = GUIFrame:CreateSlider(row6, "Max Lines", {
        min = 10,
        max = 5000,
        step = 10,
        value = db.MaxLines or 500,
        callback = function(val)
            db.MaxLines = val
            ApplySettings()
        end
    })
    row6:AddWidget(maxLinesSlider, 1)
    manager:Register(maxLinesSlider, "all")
    card4:AddRow(row6, Theme.rowHeightLast, 0)

    yOffset = card4:GetNextOffset()

    -- Card 5: Position Settings (using premade card)
    local posCard, posYOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        title = "Position Settings",
        db = db,
        dbKeys = {
            anchorFrameType = "anchorFrameType",
            anchorFrameFrame = "ParentFrame",
            selfPoint = "AnchorFrom",
            anchorPoint = "AnchorTo",
            xOffset = "XOffset",
            yOffset = "YOffset",
        },
        defaults = {
            anchorFrameType = "UIPARENT",
            selfPoint = "BOTTOMLEFT",
            anchorPoint = "BOTTOMLEFT",
            xOffset = 5,
            yOffset = 5,
        },
        onChangeCallback = ApplySettings,
        showAnchorFrameType = true,
    })
    manager:Register(posCard, "all")

    yOffset = posYOffset

    return yOffset
end

local function RenderTextTab(scrollChild, db, manager)
    local yOffset = Theme.paddingSmall

    -- Card 1: Channel Settings
    local card1 = GUIFrame:CreateCard(scrollChild, "Channel Settings", yOffset)
    manager:Register(card1, "all")

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local shortChannelsCheck = GUIFrame:CreateCheckbox(row1, "Short Channel Names", {
        value = db.ShortChannels ~= false,
        callback = function(checked)
            db.ShortChannels = checked
            ApplySettings()
        end
    })
    row1:AddWidget(shortChannelsCheck, 1)
    manager:Register(shortChannelsCheck, "all")
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Text Fading
    local card2 = GUIFrame:CreateCard(scrollChild, "Text Fading", yOffset)
    manager:Register(card2, "all")

    local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local fadeCheck = GUIFrame:CreateCheckbox(row2, "Fade Chat Text", {
        value = db.FadeEnabled ~= false,
        callback = function(checked)
            db.FadeEnabled = checked
            ApplySettings()
            manager:UpdateAll(db.Enabled)
        end
    })
    row2:AddWidget(fadeCheck, 1)
    manager:Register(fadeCheck, "all")
    card2:AddRow(row2, Theme.rowHeight)

    manager:SetCondition("fadeWidgets", function() return db.FadeEnabled ~= false end)

    local row3 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local fadeTimeSlider = GUIFrame:CreateSlider(row3, "Fade Time (seconds)", {
        min = 5,
        max = 100,
        step = 1,
        value = db.FadeTime or 3,
        callback = function(val)
            db.FadeTime = val
            ApplySettings()
        end
    })
    row3:AddWidget(fadeTimeSlider, 1)
    manager:Register(fadeTimeSlider, "all", "fadeWidgets")
    card2:AddRow(row3, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Timestamps
    local card3 = GUIFrame:CreateCard(scrollChild, "Timestamps", yOffset)
    manager:Register(card3, "all")

    local row4 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local timestampDropdown = GUIFrame:CreateDropdown(row4, "Timestamp Format", {
        value = db.TimestampFormat or "NONE",
        options = TIMESTAMP_FORMATS,
        callback = function(val)
            db.TimestampFormat = val
            ApplySettings()
        end
    })
    row4:AddWidget(timestampDropdown, 1)
    manager:Register(timestampDropdown, "all")
    card3:AddRow(row4, Theme.rowHeight)

    local row5 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local localTimeCheck = GUIFrame:CreateCheckbox(row5, "Use Local Time", {
        value = db.UseLocalTime ~= false,
        callback = function(checked)
            db.UseLocalTime = checked
            ApplySettings()
        end
    })
    row5:AddWidget(localTimeCheck, 1)
    manager:Register(localTimeCheck, "all")
    card3:AddRow(row5, Theme.rowHeight)

    local row6 = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local timestampColorCheck = GUIFrame:CreateCheckbox(row6, "Custom Timestamp Color", {
        value = db.TimestampColorEnabled == true,
        callback = function(checked)
            db.TimestampColorEnabled = checked
            ApplySettings()
            manager:UpdateAll(db.Enabled)
        end
    })
    row6:AddWidget(timestampColorCheck, 0.5)
    manager:Register(timestampColorCheck, "all")

    manager:SetCondition("timestampColorWidgets", function() return db.TimestampColorEnabled == true end)

    local tsColor = db.TimestampColor or { r = 0.6, g = 0.6, b = 0.6 }
    local timestampColorPicker = GUIFrame:CreateColorPicker(row6, "Color", {
        color = { tsColor.r or 0.6, tsColor.g or 0.6, tsColor.b or 0.6, 1 },
        callback = function(r, g, b)
            db.TimestampColor = { r = r, g = g, b = b }
            ApplySettings()
        end
    })
    row6:AddWidget(timestampColorPicker, 0.5)
    manager:Register(timestampColorPicker, "all", "timestampColorWidgets")
    card3:AddRow(row6, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card 4: Font Settings (using premade card)
    local fontCard, fontYOffset = GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, {
        title = "Font Settings",
        db = db,
        dbKeys = {
            fontFace = "FontFace",
            fontOutline = "FontOutline",
        },
        fontSizes = {
            { label = "Tab Font Size", dbKey = "TabFontSize" },
        },
        fontSizeRange = { 8, 24 },
        onChangeCallback = ApplySettings,
        includeSoftOutline = true,
        globalOverride = {},
    })
    manager:Register(fontCard, "all")

    yOffset = fontYOffset

    return yOffset
end

local function RenderTabsTab(scrollChild, db, manager)
    local yOffset = Theme.paddingSmall

    -- Card 1: Tab Text Colors
    local card1 = GUIFrame:CreateCard(scrollChild, "Tab Text Colors", yOffset)
    manager:Register(card1, "all")

    -- Row 1: Enable custom selected tab color + color picker
    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
    local enableSelectedColor = GUIFrame:CreateCheckbox(row1, "Custom Selected Tab Color", {
        value = db.TabSelectedTextEnabled == true,
        callback = function(checked)
            db.TabSelectedTextEnabled = checked
            ApplySettings()
            manager:UpdateAll(db.Enabled)
        end
    })
    row1:AddWidget(enableSelectedColor, 0.5)
    manager:Register(enableSelectedColor, "all")

    manager:SetCondition("selectedColorWidgets", function() return db.TabSelectedTextEnabled == true end)

    local selectedColor = db.TabSelectedTextColor or { r = 1, g = 1, b = 1 }
    local selectedTabColor = GUIFrame:CreateColorPicker(row1, "Color", {
        color = { selectedColor.r or 1, selectedColor.g or 1, selectedColor.b or 1, 1 },
        callback = function(r, g, b)
            db.TabSelectedTextColor = { r = r, g = g, b = b }
            ApplySettings()
        end
    })
    row1:AddWidget(selectedTabColor, 0.5)
    manager:Register(selectedTabColor, "all", "selectedColorWidgets")
    card1:AddRow(row1, Theme.rowHeight)

    -- Row 2: Non-selected tab color mode + custom color
    local row2 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local colorModeDropdown = GUIFrame:CreateDropdown(row2, "Inactive Tab Color Mode", {
        options = NRSKNUI.ColorModeOptions,
        value = db.TabTextColorMode or "custom",
        callback = function(key)
            db.TabTextColorMode = key
            ApplySettings()
            manager:UpdateAll(db.Enabled)
        end
    })
    row2:AddWidget(colorModeDropdown, 0.5)
    manager:Register(colorModeDropdown, "all")

    manager:SetCondition("inactiveCustomColorWidgets", function() return (db.TabTextColorMode or "custom") == "custom" end)

    local tabTextColor = db.TabTextColor or { r = 1, g = 0.82, b = 0 }
    local tabTextColorPicker = GUIFrame:CreateColorPicker(row2, "Custom Color", {
        color = { tabTextColor.r or 1, tabTextColor.g or 0.82, tabTextColor.b or 0, 1 },
        callback = function(r, g, b)
            db.TabTextColor = { r = r, g = g, b = b }
            ApplySettings()
        end
    })
    row2:AddWidget(tabTextColorPicker, 0.5)
    manager:Register(tabTextColorPicker, "all", "inactiveCustomColorWidgets")
    card1:AddRow(row2, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Tab Selector Style
    local card2 = GUIFrame:CreateCard(scrollChild, "Tab Selector", yOffset)
    manager:Register(card2, "all")

    local row3 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local selectorDropdown = GUIFrame:CreateDropdown(row3, "Selector Style", {
        value = db.TabSelector or "NONE",
        options = TAB_SELECTOR_STYLES,
        callback = function(val)
            db.TabSelector = val
            ApplySettings()
            manager:UpdateAll(db.Enabled)
        end
    })
    row3:AddWidget(selectorDropdown, 1)
    manager:Register(selectorDropdown, "all")
    card2:AddRow(row3, Theme.rowHeight)

    manager:SetCondition("selectorWidgets", function() return db.TabSelector ~= "NONE" end)

    local row4 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local selectorColor = db.TabSelectorColor or { r = 0.3, g = 1, b = 0.3 }
    local selectorColorPicker = GUIFrame:CreateColorPicker(row4, "Selector Color", {
        color = { selectorColor.r or 0.3, selectorColor.g or 1, selectorColor.b or 0.3, 1 },
        callback = function(r, g, b)
            db.TabSelectorColor = { r = r, g = g, b = b }
            ApplySettings()
        end
    })
    row4:AddWidget(selectorColorPicker, 1)
    manager:Register(selectorColorPicker, "all", "selectorWidgets")
    card2:AddRow(row4, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Tab Backdrop
    local card3 = GUIFrame:CreateCard(scrollChild, "Tab Backdrop", yOffset)
    manager:Register(card3, "all")

    db.TabBackdrop = db.TabBackdrop or {}

    local row5 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local tabBackdropCheck = GUIFrame:CreateCheckbox(row5, "Enable Tab Backdrop", {
        value = db.TabBackdrop.Enabled == true,
        callback = function(checked)
            db.TabBackdrop.Enabled = checked
            ApplySettings()
            manager:UpdateAll(db.Enabled)
        end
    })
    row5:AddWidget(tabBackdropCheck, 1)
    manager:Register(tabBackdropCheck, "all")
    card3:AddRow(row5, Theme.rowHeight)

    manager:SetCondition("tabBackdropWidgets", function() return db.TabBackdrop.Enabled == true end)

    local row6 = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local tabBackdropColor = GUIFrame:CreateColorPicker(row6, "Background", {
        color = db.TabBackdrop.Color or { 0, 0, 0, 0.5 },
        callback = function(r, g, b, a)
            db.TabBackdrop.Color = { r, g, b, a }
            ApplySettings()
        end
    })
    row6:AddWidget(tabBackdropColor, 0.5)
    manager:Register(tabBackdropColor, "all", "tabBackdropWidgets")

    local tabBackdropBorderColor = GUIFrame:CreateColorPicker(row6, "Border", {
        color = db.TabBackdrop.BorderColor or { 0, 0, 0, 1 },
        callback = function(r, g, b, a)
            db.TabBackdrop.BorderColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row6:AddWidget(tabBackdropBorderColor, 0.5)
    manager:Register(tabBackdropBorderColor, "all", "tabBackdropWidgets")
    card3:AddRow(row6, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    return yOffset
end

local function RenderSoundsTab(scrollChild, db, manager)
    local yOffset = Theme.paddingSmall

    db.WhisperSounds = db.WhisperSounds or {}
    local ws = db.WhisperSounds

    -- Card 1: Enable Toggle
    local card1 = GUIFrame:CreateCard(scrollChild, "Whisper Sound Alerts", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Whisper Sounds", {
        value = ws.Enabled == true,
        callback = function(checked)
            ws.Enabled = checked
            local mod = NRSKNUI:GetModule("Chatv2", true)
            if mod then
                if checked then
                    mod:RegisterWhisperSounds()
                else
                    mod:UnregisterEvent("CHAT_MSG_WHISPER")
                    mod:UnregisterEvent("CHAT_MSG_BN_WHISPER")
                end
            end
            manager:UpdateAll(db.Enabled)
        end
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Sound Selection
    local card2 = GUIFrame:CreateCard(scrollChild, "Sound Selection", yOffset)

    manager:SetCondition("whisperSoundWidgets", function() return ws.Enabled == true end)

    local soundList = { ["None"] = "None" }
    if LSM then
        for name in pairs(LSM:HashTable("sound")) do
            soundList[name] = name
        end
    end

    local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local whisperDropdown = GUIFrame:CreateDropdown(row2, "Whisper Sound", {
        options = soundList,
        value = ws.WhisperSound or "None",
        labelWidth = 60,
        callback = function(key)
            ws.WhisperSound = key
        end
    })
    row2:AddWidget(whisperDropdown, 0.6)
    manager:Register(whisperDropdown, "all", "whisperSoundWidgets")

    local testWhisperBtn = GUIFrame:CreateButton(row2, "Test", {
        width = 60,
        height = 24,
        callback = function()
            local soundName = ws.WhisperSound
            if soundName and soundName ~= "None" and LSM then
                NRSKNUI:PlaySound(LSM:Fetch("sound", soundName))
            end
        end,
    })
    row2:AddWidget(testWhisperBtn, 0.4, nil, 0, -14)
    manager:Register(testWhisperBtn, "all", "whisperSoundWidgets")
    card2:AddRow(row2, Theme.rowHeight)

    local row3 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local bnetDropdown = GUIFrame:CreateDropdown(row3, "Battle.net Whisper Sound", {
        options = soundList,
        value = ws.BNetWhisperSound or "None",
        labelWidth = 60,
        callback = function(key)
            ws.BNetWhisperSound = key
        end
    })
    row3:AddWidget(bnetDropdown, 0.6)
    manager:Register(bnetDropdown, "all", "whisperSoundWidgets")

    local testBnetBtn = GUIFrame:CreateButton(row3, "Test", {
        width = 60,
        height = 24,
        callback = function()
            local soundName = ws.BNetWhisperSound
            if soundName and soundName ~= "None" and LSM then
                NRSKNUI:PlaySound(LSM:Fetch("sound", soundName))
            end
        end,
    })
    row3:AddWidget(testBnetBtn, 0.4, nil, 0, -14)
    manager:Register(testBnetBtn, "all", "whisperSoundWidgets")
    card2:AddRow(row3, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    return yOffset
end

GUIFrame:RegisterPanel("Chatv2", function(container)
    if NRSKNUI:ShouldNotLoadModule() then return nil end
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.Chatv2
    if not db then return nil end

    local manager = GUIFrame:CreateWidgetStateManager()

    local function UpdateAllWidgetStates()
        manager:UpdateAll(db.Enabled)
    end

    local subTabPanel
    local RenderContent

    RenderContent = function()
        subTabPanel:ClearContent()
        manager:Clear()

        local tabYOffset = Theme.paddingSmall
        if currentSubTab == "general" then
            tabYOffset = RenderGeneralTab(subTabPanel.scrollChild, db, manager)
        elseif currentSubTab == "text" then
            tabYOffset = RenderTextTab(subTabPanel.scrollChild, db, manager)
        elseif currentSubTab == "tabs" then
            tabYOffset = RenderTabsTab(subTabPanel.scrollChild, db, manager)
        elseif currentSubTab == "sounds" then
            tabYOffset = RenderSoundsTab(subTabPanel.scrollChild, db, manager)
        end

        subTabPanel:SetContentHeight(tabYOffset)
        UpdateAllWidgetStates()
    end

    subTabPanel = NRSKNUI.GUI.CreateSubTabPanel(container, SUB_TABS, {
        tabBarHeight = TAB_BAR_HEIGHT,
        defaultTab = currentSubTab,
        onTabChanged = function(tabId)
            currentSubTab = tabId
            RenderContent()
        end,
    })

    RenderContent()

    return subTabPanel.panel
end)

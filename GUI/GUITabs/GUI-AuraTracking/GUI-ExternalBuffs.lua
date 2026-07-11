---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

local table_insert = table.insert
local ipairs = ipairs
local pairs = pairs

GUIFrame:RegisterContent("CustomSkin_Externals", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.ExternalBuffTracking
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    ---@type ExternalBuffTracking?
    local EXTERNALS = NRSKNUI:GetModule("ExternalBuffTracking", true)
    local manager = GUIFrame:CreateWidgetStateManager()
    local postUpdateCallbacks = {}
    local allCards = {}

    manager:SetCondition("swipeOn", function() return db.Swipe end)

    local function RelayoutCards()
        local y = allCards[1] and allCards[1]:GetNextOffset() or yOffset
        for i = 2, #allCards do
            local card = allCards[i]
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", Theme.paddingSmall, -y)
            card:SetPoint("RIGHT", scrollChild, "RIGHT", -Theme.paddingSmall, 0)
            card._yOffset = y
            y = card:GetNextOffset()
        end
    end

    local function ApplySettings()
        if EXTERNALS and EXTERNALS:IsEnabled() and EXTERNALS.ApplySettings then
            EXTERNALS:ApplySettings()
        end
    end

    local function UpdateAllWidgetStates()
        manager:UpdateAll(db.Enabled)
        if db.Enabled then
            for _, callback in ipairs(postUpdateCallbacks) do
                callback()
            end
        end
    end

    -- Card 1
    local card1 = GUIFrame:CreateCard(scrollChild, "External & Defensive Buffs", yOffset)
    table_insert(allCards, card1)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "External & Defensive Buffs Frame", {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if EXTERNALS then
                EXTERNALS.db.Enabled = checked
                if checked then
                    NRSKNUI:EnableModule("ExternalBuffTracking")
                    EXTERNALS:ShowPreview()
                else
                    NRSKNUI:DisableModule("ExternalBuffTracking")
                    EXTERNALS:HidePreview()
                end
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = "External & Defensive Buffs Frame",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeight)

    local separator1 = GUIFrame:CreateSeparator(card1.content)
    card1:AddRow(separator1, Theme.rowHeightSeparator)

    local row1b = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local bigDefCheck = GUIFrame:CreateCheckbox(row1b, "Track Defensives", {
        tooltip = "Uses Blizzards " .. "|cffFFFFFFBIG_DEFENSIVE|r" .. " filter, might not include all defensive buffs.",
        value = db.ShowBigDefensives,
        callback = function(checked)
            db.ShowBigDefensives = checked
            if EXTERNALS and EXTERNALS:IsEnabled() and EXTERNALS.UpdateAuras then
                EXTERNALS:UpdateAuras()
                EXTERNALS:TogglePreview()
            end
        end
    })
    row1b:AddWidget(bigDefCheck, 1)
    manager:Register(bigDefCheck, "all")
    card1:AddRow(row1b, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2
    local card2 = GUIFrame:CreateCard(scrollChild, "Icon Settings", yOffset)
    table_insert(allCards, card2)
    manager:Register(card2, "all")

    local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local iconSizeSlider = GUIFrame:CreateSlider(row2a, "Icon Size", {
        min = 16,
        max = 100,
        step = 1,
        value = db.IconSize,
        callback = function(value)
            db.IconSize = value
            ApplySettings()
        end
    })
    row2a:AddWidget(iconSizeSlider, 0.5)
    manager:Register(iconSizeSlider, "all")

    local iconSpacingSlider = GUIFrame:CreateSlider(row2a, "Icon Spacing", {
        min = -10,
        max = 10,
        step = 1,
        value = db.IconSpacing,
        callback = function(value)
            db.IconSpacing = value
            ApplySettings()
        end
    })
    row2a:AddWidget(iconSpacingSlider, 0.5)
    manager:Register(iconSpacingSlider, "all")
    card2:AddRow(row2a, Theme.rowHeight)

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local iconsPerRowSlider = GUIFrame:CreateSlider(row2b, "Icons Per Row", {
        min = 1,
        max = 20,
        step = 1,
        value = db.IconsPerRow,
        callback = function(value)
            db.IconsPerRow = value
            ApplySettings()
        end
    })
    row2b:AddWidget(iconsPerRowSlider, 0.5)
    manager:Register(iconsPerRowSlider, "all")

    local maxRowsSlider = GUIFrame:CreateSlider(row2b, "Max Rows", {
        min = 1,
        max = 5,
        step = 1,
        value = db.MaxRows,
        callback = function(value)
            db.MaxRows = value
            ApplySettings()
        end
    })
    row2b:AddWidget(maxRowsSlider, 0.5)
    manager:Register(maxRowsSlider, "all")
    card2:AddRow(row2b, Theme.rowHeight)

    local sep2a = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sep2a, Theme.rowHeightSeparator)

    local row2growth = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local growHList = {
        { key = "LEFT",  text = "Left" },
        { key = "RIGHT", text = "Right" },
    }
    local growHDropdown = GUIFrame:CreateDropdown(row2growth, "Grow Horizontal", {
        options = growHList,
        value = db.GrowHorizontal or "LEFT",
        callback = function(key)
            db.GrowHorizontal = key
            ApplySettings()
        end
    })
    row2growth:AddWidget(growHDropdown, 0.5)
    manager:Register(growHDropdown, "all")

    local growVList = {
        { key = "UP",   text = "Up" },
        { key = "DOWN", text = "Down" },
    }
    local growVDropdown = GUIFrame:CreateDropdown(row2growth, "Then Vertical", {
        options = growVList,
        value = db.GrowVertical or "DOWN",
        callback = function(key)
            db.GrowVertical = key
            ApplySettings()
        end
    })
    row2growth:AddWidget(growVDropdown, 0.5)
    manager:Register(growVDropdown, "all")
    card2:AddRow(row2growth, Theme.rowHeight)

    local sep2b = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sep2b, Theme.rowHeightSeparator)

    local row2c = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local iconZoomSlider = GUIFrame:CreateSlider(row2c, "Icon Zoom", {
        min = 0,
        max = 1,
        step = 0.01,
        value = db.IconZoom,
        callback = function(value)
            db.IconZoom = value
            ApplySettings()
        end
    })
    row2c:AddWidget(iconZoomSlider, 0.5)
    manager:Register(iconZoomSlider, "all")

    local borderColorPicker = GUIFrame:CreateColorPicker(row2c, "Border Color", {
        color = db.BorderColor,
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row2c:AddWidget(borderColorPicker, 0.5)
    manager:Register(borderColorPicker, "all")
    card2:AddRow(row2c, Theme.rowHeight)

    local separator3 = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(separator3, Theme.rowHeightSeparator)

    local rowSwipe = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local swipeCheck = GUIFrame:CreateCheckbox(rowSwipe, "Enable Swipe", {
        value = db.Swipe,
        callback = function(checked)
            db.Swipe = checked
            ApplySettings()
            UpdateAllWidgetStates()
            if EXTERNALS then EXTERNALS:TogglePreview() end
        end
    })
    rowSwipe:AddWidget(swipeCheck, 0.5)
    manager:Register(swipeCheck, "all")

    local reverseCheck = GUIFrame:CreateCheckbox(rowSwipe, "Reverse Swipe", {
        value = db.Reverse,
        callback = function(checked)
            db.Reverse = checked
            ApplySettings()
            if EXTERNALS then EXTERNALS:TogglePreview() end
        end
    })
    rowSwipe:AddWidget(reverseCheck, 0.5)
    manager:Register(reverseCheck, "all", "swipeOn")
    card2:AddRow(rowSwipe, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3
    local fontCard, fontOffset, fontWidgets = GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, {
        title = "Font Settings",
        db = db,
        dbKeys = { fontFace = "FontFace", fontOutline = "FontOutline" },
        fontSizes = {
            { label = "Count Size", dbKey = "FontSize" },
            { label = "Timer Size", dbKey = "TimerFontSize" },
        },
        includeSoftOutline = true,
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
    table_insert(allCards, fontCard)
    manager:Register(fontCard, "all")
    manager:RegisterGroup(fontWidgets, "all")
    if fontCard.UpdateShadowState then table_insert(postUpdateCallbacks, fontCard.UpdateShadowState) end

    yOffset = fontOffset

    -- Card 4
    local glowCard, glowOffset, glowWidgets = GUIFrame:CreateGlowSettingsCard(scrollChild, yOffset, {
        title = "Glow Settings (External Defensives Only)",
        db = db,
        onChangeCallback = function()
            ApplySettings()
            if EXTERNALS then EXTERNALS:TogglePreview() end
        end,
        onHeightChange = RelayoutCards,
    })
    table_insert(allCards, glowCard)
    manager:Register(glowCard, "all")
    manager:RegisterGroup(glowWidgets, "all")
    if glowCard.updateTypeVisibility then table_insert(postUpdateCallbacks, glowCard.updateTypeVisibility) end

    yOffset = glowOffset

    -- Card 5
    local soundCard = GUIFrame:CreateCard(scrollChild, "Sound (External Defensives Only)", yOffset)
    table_insert(allCards, soundCard)
    manager:Register(soundCard, "all")

    local soundList = { ["None"] = "None" }
    if LSM then
        for name in pairs(LSM:HashTable("sound")) do soundList[name] = name end
    end

    local rowSound = GUIFrame:CreateRow(soundCard.content, Theme.rowHeight)
    local soundEnableCheck = GUIFrame:CreateCheckbox(rowSound, "Enable Sound", {
        value = db.SoundEnabled,
        callback = function(checked)
            db.SoundEnabled = checked
        end
    })
    rowSound:AddWidget(soundEnableCheck, 1)
    manager:Register(soundEnableCheck, "all")
    soundCard:AddRow(rowSound, Theme.rowHeight)

    local separator2 = GUIFrame:CreateSeparator(soundCard.content)
    soundCard:AddRow(separator2, Theme.rowHeightSeparator)

    local rowSound2 = GUIFrame:CreateRow(soundCard.content, Theme.rowHeightLast)
    local soundDropdown = GUIFrame:CreateDropdown(rowSound2, "On Application Sound", {
        options = soundList,
        value = db.Sound,
        callback = function(key)
            db.Sound = key
        end,
        searchable = true
    })
    rowSound2:AddWidget(soundDropdown, 0.5)
    manager:Register(soundDropdown, "all")

    local testSoundBtn = GUIFrame:CreateButton(rowSound2, "Test", {
        width = 60,
        height = 24,
        callback = function()
            local soundName = db.Sound
            if soundName and soundName ~= "None" and LSM then
                NRSKNUI:PlaySound(LSM:Fetch("sound", soundName))
            end
        end,
    })
    rowSound2:AddWidget(testSoundBtn, 0.5, nil, 0, -14)
    manager:Register(testSoundBtn, "all")
    soundCard:AddRow(rowSound2, Theme.rowHeightLast, 0)

    yOffset = soundCard:GetNextOffset()

    -- Card 7
    local posCard, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = true,
        showStrata = true,
        disableAnchorFrom = true,
        onChangeCallback = function()
            if EXTERNALS and EXTERNALS.ApplyPosition then
                EXTERNALS:ApplyPosition()
            end
        end,
    })
    table_insert(allCards, posCard)
    manager:Register(posCard, "all")

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

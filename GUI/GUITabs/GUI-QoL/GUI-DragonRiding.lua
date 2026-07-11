---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

local table_insert = table.insert
local ipairs = ipairs
local pairs = pairs

GUIFrame:RegisterContent("DragonRiding", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.DragonRiding
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local DR = NRSKNUI:GetModule("DragonRiding", true)
    local manager = GUIFrame:CreateWidgetStateManager()
    local postUpdateCallbacks = {}
    local speedTextSubWidgets = {}
    local allCards = {}

    local function ApplySettings()
        if DR and DR.ApplySettings then DR:ApplySettings() end
    end

    local function UpdateSpeedTextState()
        local speedEnabled = db.SpeedText and db.SpeedText.Enabled
        for _, widget in ipairs(speedTextSubWidgets) do
            if widget.SetEnabled then widget:SetEnabled(speedEnabled) end
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

    -- Card 1: Enable
    local card1 = GUIFrame:CreateCard(scrollChild, "Skyriding UI", yOffset)
    table_insert(allCards, card1)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Skyriding UI", {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if DR then
                DR.db.Enabled = checked
                if checked then NRSKNUI:EnableModule("DragonRiding") else NRSKNUI:DisableModule("DragonRiding") end
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = "Skyriding UI",
        msgOn = "On",
        msgOff = "Off"
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Size Settings
    local card2 = GUIFrame:CreateCard(scrollChild, "Size Settings", yOffset)
    table_insert(allCards, card2)
    manager:Register(card2, "all")

    local statusbarList = {}
    if LSM then
        for name in pairs(LSM:HashTable("statusbar")) do
            statusbarList[name] = name
        end
    end

    local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local widthSlider = GUIFrame:CreateSlider(row2a, "Width", {
        min = 100,
        max = 500,
        step = 1,
        value = db.Width,
        callback = function(val)
            db.Width = val; ApplySettings()
        end
    })
    row2a:AddWidget(widthSlider, 0.5)
    manager:Register(widthSlider, "all")

    local heightSlider = GUIFrame:CreateSlider(row2a, "Bar Height", {
        min = 1,
        max = 24,
        step = 1,
        value = db.BarHeight,
        callback = function(val)
            db.BarHeight = val; ApplySettings()
        end
    })
    row2a:AddWidget(heightSlider, 0.5)
    manager:Register(heightSlider, "all")
    card2:AddRow(row2a, Theme.rowHeight)

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local spacingSlider = GUIFrame:CreateSlider(row2b, "Row Spacing", {
        min = -10,
        max = 10,
        step = 1,
        value = db.Spacing,
        callback = function(val)
            db.Spacing = val; ApplySettings()
        end
    })
    row2b:AddWidget(spacingSlider, 1)
    manager:Register(spacingSlider, "all")
    card2:AddRow(row2b, Theme.rowHeight)

    local row2c = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local useGlobalBarCheck = GUIFrame:CreateCheckbox(row2c, "Use Global Bar", {
        value = db.UseGlobalBar ~= false,
        callback = function(checked)
            db.UseGlobalBar = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row2c:AddWidget(useGlobalBarCheck, 0.5)
    manager:Register(useGlobalBarCheck, "all")

    manager:SetCondition("GlobalOn", function() return not db.UseGlobalBar end)

    local textureDropdown = GUIFrame:CreateDropdown(row2c, "Bar Texture", {
        options = statusbarList,
        value = db.StatusBarTexture,
        searchable = true,
        callback = function(key)
            db.StatusBarTexture = key; ApplySettings()
        end
    })
    row2c:AddWidget(textureDropdown, 0.5)
    manager:Register(textureDropdown, "all", "GlobalOn")
    card2:AddRow(row2c, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Colors
    local card3 = GUIFrame:CreateCard(scrollChild, "Colors", yOffset)
    table_insert(allCards, card3)
    manager:Register(card3, "all")

    local row3a = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local vigorPicker = GUIFrame:CreateColorPicker(row3a, "Vigor", {
        color = db.Colors.Vigor,
        callback = function(r, g, b, a)
            db.Colors.Vigor = { r, g, b, a }; ApplySettings()
        end
    })
    row3a:AddWidget(vigorPicker, 0.5)
    manager:Register(vigorPicker, "all")

    local thrillPicker = GUIFrame:CreateColorPicker(row3a, "Vigor (Thrill)", {
        color = db.Colors.VigorThrill,
        callback = function(r, g, b, a)
            db.Colors.VigorThrill = { r, g, b, a }; ApplySettings()
        end
    })
    row3a:AddWidget(thrillPicker, 0.5)
    manager:Register(thrillPicker, "all")
    card3:AddRow(row3a, Theme.rowHeight)

    local row3b = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local surgePicker = GUIFrame:CreateColorPicker(row3b, "Whirling Surge", {
        color = db.Colors.WhirlingSurge,
        callback = function(r, g, b, a)
            db.Colors.WhirlingSurge = { r, g, b, a }; ApplySettings()
        end
    })
    row3b:AddWidget(surgePicker, 0.5)
    manager:Register(surgePicker, "all")

    local windPicker = GUIFrame:CreateColorPicker(row3b, "Second Wind", {
        color = db.Colors.SecondWind,
        callback = function(r, g, b, a)
            db.Colors.SecondWind = { r, g, b, a }; ApplySettings()
        end
    })
    row3b:AddWidget(windPicker, 0.5)
    manager:Register(windPicker, "all")
    card3:AddRow(row3b, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card 4: Speed Text
    local card4 = GUIFrame:CreateCard(scrollChild, "Speed Text", yOffset)
    table_insert(allCards, card4)
    manager:Register(card4, "all")

    db.SpeedText = db.SpeedText or {}

    local row4a = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local speedEnableCheck = GUIFrame:CreateCheckbox(row4a, "Show Speed Text", {
        value = db.SpeedText.Enabled,
        callback = function(checked)
            db.SpeedText.Enabled = checked
            ApplySettings()
            UpdateSpeedTextState()
        end
    })
    row4a:AddWidget(speedEnableCheck, 1)
    manager:Register(speedEnableCheck, "all")
    card4:AddRow(row4a, Theme.rowHeight)

    local sep4 = GUIFrame:CreateSeparator(card4.content)
    card4:AddRow(sep4, Theme.rowHeightSeparator)

    local row4b = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
    local xSlider = GUIFrame:CreateSlider(row4b, "X Offset", {
        min = -100,
        max = 100,
        step = 1,
        value = db.SpeedText.XOffset or 0,
        callback = function(val)
            db.SpeedText.XOffset = val; ApplySettings()
        end
    })
    row4b:AddWidget(xSlider, 0.5)
    manager:Register(xSlider, "all")
    table_insert(speedTextSubWidgets, xSlider)

    local ySlider = GUIFrame:CreateSlider(row4b, "Y Offset", {
        min = -50,
        max = 50,
        step = 1,
        value = db.SpeedText.YOffset or 0,
        callback = function(val)
            db.SpeedText.YOffset = val; ApplySettings()
        end
    })
    row4b:AddWidget(ySlider, 0.5)
    manager:Register(ySlider, "all")
    table_insert(speedTextSubWidgets, ySlider)
    card4:AddRow(row4b, Theme.rowHeightLast, 0)

    table_insert(postUpdateCallbacks, UpdateSpeedTextState)
    yOffset = card4:GetNextOffset()

    -- Card 5: Speed Text Font Settings
    local fontCard, fontOffset, fontWidgets = GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, {
        title = "Speed Text Font",
        db = db.SpeedText,
        onChangeCallback = ApplySettings,
        fontSizeRange = { 8, 32 },
        includeSoftOutline = true,
        globalOverride = {},
    })
    table_insert(allCards, fontCard)
    manager:Register(fontCard, "all")
    manager:RegisterGroup(fontWidgets, "all")
    table_insert(speedTextSubWidgets, fontCard)
    if fontCard.UpdateShadowState then table_insert(postUpdateCallbacks, fontCard.UpdateShadowState) end

    yOffset = fontOffset

    -- Card 6: Position
    local posCard, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = false,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })
    table_insert(allCards, posCard)
    manager:Register(posCard, "all")

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

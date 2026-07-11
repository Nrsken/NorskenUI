---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

local pairs = pairs

GUIFrame:RegisterContent("XPBar", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.XPBar
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    ---@type XPBar?
    local XPBar = NRSKNUI:GetModule("XPBar", true)
    local manager = GUIFrame:CreateWidgetStateManager()

    local function ApplySettings()
        if XPBar and XPBar.ApplySettings then XPBar:ApplySettings() end
    end

    local function UpdateAllWidgetStates()
        local customEnabled = db.ColorMode == "custom"
        local customRestedEnabled = db.ColorModeRested == "custom"
        manager:UpdateAll(db.Enabled)
        manager:UpdateGroup("custom", customEnabled and db.Enabled)
        manager:UpdateGroup("customRested", customRestedEnabled and db.Enabled)
    end

    -- Card 1: Enable
    local card1 = GUIFrame:CreateCard(scrollChild, "XP Bar", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable XP Bar", {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if XPBar then
                if checked then NRSKNUI:EnableModule("XPBar") else NRSKNUI:DisableModule("XPBar") end
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = "XP Bar",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeight)

    yOffset = card1:GetNextOffset()

    -- Card 2: Bar Size & Texture
    local card2 = GUIFrame:CreateCard(scrollChild, "Bar Size & Texture", yOffset)
    manager:Register(card2, "all")

    local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local widthSlider = GUIFrame:CreateSlider(row2a, "Bar Width", {
        min = 1,
        max = 1000,
        step = 1,
        value = db.width,
        callback = function(val)
            db.width = val
            ApplySettings()
        end
    })
    row2a:AddWidget(widthSlider, 0.5)
    manager:Register(widthSlider, "all")

    local heightSlider = GUIFrame:CreateSlider(row2a, "Bar Height", {
        min = 1,
        max = 1000,
        step = 1,
        value = db.height,
        callback = function(val)
            db.height = val
            ApplySettings()
        end
    })
    row2a:AddWidget(heightSlider, 0.5)
    manager:Register(heightSlider, "all")
    card2:AddRow(row2a, Theme.rowHeight)

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local useGlobalBarCheck = GUIFrame:CreateCheckbox(row2b, "Use Global Bar", {
        value = db.UseGlobalBar ~= false,
        callback = function(checked)
            db.UseGlobalBar = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row2b:AddWidget(useGlobalBarCheck, 0.5)
    manager:Register(useGlobalBarCheck, "all")

    manager:SetCondition("GlobalOn", function() return not db.UseGlobalBar end)

    local statusbarList = {}
    if LSM then
        for name in pairs(LSM:HashTable("statusbar")) do statusbarList[name] = name end
    else
        statusbarList["Blizzard"] = "Blizzard"
    end
    local statusbarDropdown = GUIFrame:CreateDropdown(row2b, "Bar Texture", {
        options = statusbarList,
        value = db.StatusBarTexture,
        callback = function(key)
            db.StatusBarTexture = key
            ApplySettings()
        end,
        searchable = true
    })
    row2b:AddWidget(statusbarDropdown, 0.5)
    manager:Register(statusbarDropdown, "all", "GlobalOn")
    card2:AddRow(row2b, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Colors
    local card3 = GUIFrame:CreateCard(scrollChild, "Color Settings", yOffset)
    manager:Register(card3, "all")

    local row3a = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local colorModeDropdown = GUIFrame:CreateDropdown(row3a, "Foreground Color Mode", {
        options = NRSKNUI.ColorModeOptions,
        value = db.ColorMode,
        callback = function(key)
            db.ColorMode = key
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row3a:AddWidget(colorModeDropdown, 0.5)
    manager:Register(colorModeDropdown, "all")

    local foregroundColor = GUIFrame:CreateColorPicker(row3a, "Custom Color", {
        color = db.StatusColor,
        callback = function(r, g, b, a)
            db.StatusColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row3a:AddWidget(foregroundColor, 0.5)
    manager:Register(foregroundColor, "custom")
    card3:AddRow(row3a, Theme.rowHeight)

    local row3ab = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local colorModeRestedDropdown = GUIFrame:CreateDropdown(row3ab, "Rested XP Color Mode", {
        options = NRSKNUI.ColorModeOptions,
        value = db.ColorModeRested,
        callback = function(key)
            db.ColorModeRested = key
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row3ab:AddWidget(colorModeRestedDropdown, 0.5)
    manager:Register(colorModeRestedDropdown, "all")

    local restedColor = GUIFrame:CreateColorPicker(row3ab, "Custom Rested XP Color", {
        color = db.RestedColor,
        callback = function(r, g, b, a)
            db.RestedColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row3ab:AddWidget(restedColor, 0.5)
    manager:Register(restedColor, "customRested")
    card3:AddRow(row3ab, Theme.rowHeight)

    local sep3 = GUIFrame:CreateSeparator(card3.content)
    card3:AddRow(sep3, Theme.rowHeightSeparator)

    local row3b = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local backdropColor = GUIFrame:CreateColorPicker(row3b, "Backdrop Color", {
        color = db.BackdropColor,
        callback = function(r, g, b, a)
            db.BackdropColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row3b:AddWidget(backdropColor, 1)
    manager:Register(backdropColor, "all")
    card3:AddRow(row3b, Theme.rowHeight)

    local row3c = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local borderColor = GUIFrame:CreateColorPicker(row3c, "Border Color", {
        color = db.BackdropBorderColor,
        callback = function(r, g, b, a)
            db.BackdropBorderColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row3c:AddWidget(borderColor, 1)
    manager:Register(borderColor, "all")
    card3:AddRow(row3c, Theme.rowHeight)

    local sep4 = GUIFrame:CreateSeparator(card3.content)
    card3:AddRow(sep4, Theme.rowHeightSeparator)

    local row5a = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local textColor = GUIFrame:CreateColorPicker(row5a, "Text Color", {
        color = db.TextColor,
        callback = function(r, g, b, a)
            db.TextColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row5a:AddWidget(textColor, 1)
    manager:Register(textColor, "all")
    card3:AddRow(row5a, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card 4: Font Settings
    local fontCard, fontOffset, fontWidgets = GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, {
        db = db,
        includeSoftOutline = true,
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
    manager:Register(fontCard, "all")
    manager:RegisterGroup(fontWidgets, "all")

    yOffset = fontOffset

    -- Card 6: Position
    local card6, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = false,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })
    manager:Register(card6, "all")
    if card6.positionWidgets then manager:RegisterGroup(card6.positionWidgets, "all") end

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

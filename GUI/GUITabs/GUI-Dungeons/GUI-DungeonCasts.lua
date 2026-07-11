---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

local table_insert = table.insert
local ipairs = ipairs
local pairs = pairs

local previewActive = false

local function StartPreview()
    if previewActive then return end
    if not GUIFrame or not GUIFrame:IsShown() then return end

    previewActive = true
    local mod = NRSKNUI:GetModule("DungeonCasts", true)
    if mod and mod.ShowPreview then
        mod:ShowPreview()
    end
end

local function StopPreview()
    if not previewActive then return end

    previewActive = false
    local mod = NRSKNUI:GetModule("DungeonCasts", true)
    if mod and mod.HidePreview then
        mod:HidePreview()
    end
end

GUIFrame.contentCleanupCallbacks = GUIFrame.contentCleanupCallbacks or {}
GUIFrame.contentCleanupCallbacks["DungeonCasts"] = StopPreview

GUIFrame.onCloseCallbacks = GUIFrame.onCloseCallbacks or {}
GUIFrame.onCloseCallbacks["DungeonCasts"] = StopPreview

GUIFrame:RegisterContent("DungeonCasts", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.DungeonCasts
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    ---@type DungeonCasts?
    local DC = NRSKNUI:GetModule("DungeonCasts", true)
    local manager = GUIFrame:CreateWidgetStateManager()
    local postUpdateCallbacks = {}
    local targetSubWidgets = {}

    local function ApplySettings()
        if DC and DC.ApplySettings then DC:ApplySettings() end
    end

    local function ApplyPosition()
        if DC and DC.ApplyPosition then DC:ApplyPosition() end
    end

    local function UpdateTargetState()
        local targetEnabled = db.Target and db.Target.Enabled
        for _, widget in ipairs(targetSubWidgets) do
            if widget.SetEnabled then widget:SetEnabled(targetEnabled) end
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

    local statusbarList = {}
    if LSM then
        for name in pairs(LSM:HashTable("statusbar")) do
            statusbarList[name] = name
        end
    end

    -- Card 1: Enable
    local card1 = GUIFrame:CreateCard(scrollChild, "Dungeon Casts", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Dungeon Casts", {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if DC then
                if checked then
                    NRSKNUI:EnableModule("DungeonCasts")
                    StartPreview()
                else
                    NRSKNUI:DisableModule("DungeonCasts")
                    StopPreview()
                end
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = "Dungeon Casts",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Frame Settings
    local card2 = GUIFrame:CreateCard(scrollChild, "Frame Settings", yOffset)
    manager:Register(card2, "all")

    local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local maxBarsSlider = GUIFrame:CreateSlider(row2a, "Max Bars", {
        min = 1,
        max = 10,
        step = 1,
        value = db.Frame.MaxBars,
        callback = function(value)
            db.Frame.MaxBars = value; ApplySettings()
        end
    })
    row2a:AddWidget(maxBarsSlider, 0.5)
    manager:Register(maxBarsSlider, "all")

    local widthSlider = GUIFrame:CreateSlider(row2a, "Bar Width", {
        min = 100,
        max = 400,
        step = 1,
        value = db.Frame.Width,
        callback = function(value)
            db.Frame.Width = value; ApplySettings()
        end
    })
    row2a:AddWidget(widthSlider, 0.5)
    manager:Register(widthSlider, "all")
    card2:AddRow(row2a, Theme.rowHeight)

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local heightSlider = GUIFrame:CreateSlider(row2b, "Bar Height", {
        min = 16,
        max = 40,
        step = 1,
        value = db.Frame.Height,
        callback = function(value)
            db.Frame.Height = value; ApplySettings()
        end
    })
    row2b:AddWidget(heightSlider, 0.5)
    manager:Register(heightSlider, "all")

    local spacingSlider = GUIFrame:CreateSlider(row2b, "Spacing", {
        min = -10,
        max = 10,
        step = 1,
        value = db.Frame.Spacing,
        callback = function(value)
            db.Frame.Spacing = value; ApplySettings()
        end
    })
    row2b:AddWidget(spacingSlider, 0.5)
    manager:Register(spacingSlider, "all")
    card2:AddRow(row2b, Theme.rowHeight)

    local sep2 = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sep2, Theme.rowHeightSeparator)

    local row2c = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local growthOptions = { { key = "DOWN", text = "Down" }, { key = "UP", text = "Up" } }
    local growthDropdown = GUIFrame:CreateDropdown(row2c, "Growth Direction", {
        options = growthOptions,
        value = db.Frame.GrowthDirection,
        callback = function(selected)
            db.Frame.GrowthDirection = selected; ApplySettings()
        end
    })
    row2c:AddWidget(growthDropdown, 1)
    manager:Register(growthDropdown, "all")
    card2:AddRow(row2c, Theme.rowHeight)

    local row2d = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local useGlobalBarCheck = GUIFrame:CreateCheckbox(row2d, "Use Global Bar", {
        value = db.BarDisplay.UseGlobalBar ~= false,
        callback = function(checked)
            db.BarDisplay.UseGlobalBar = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row2d:AddWidget(useGlobalBarCheck, 0.5)
    manager:Register(useGlobalBarCheck, "all")

    manager:SetCondition("GlobalOn", function() return not db.BarDisplay.UseGlobalBar end)

    local statusbarDropdown = GUIFrame:CreateDropdown(row2d, "Bar Texture", {
        options = statusbarList,
        value = db.BarDisplay.StatusBarTexture,
        searchable = true,
        callback = function(selected)
            db.BarDisplay.StatusBarTexture = selected; ApplySettings()
        end
    })
    row2d:AddWidget(statusbarDropdown, 0.5)
    manager:Register(statusbarDropdown, "all", "GlobalOn")
    card2:AddRow(row2d, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Colors
    local card3 = GUIFrame:CreateCard(scrollChild, "Colors", yOffset)
    manager:Register(card3, "all")

    local row3a = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local castingColorPicker = GUIFrame:CreateColorPicker(row3a, "Casting", {
        color = db.CastingColor,
        callback = function(r, g, b, a)
            db.CastingColor = { r, g, b, a }; ApplySettings()
        end
    })
    row3a:AddWidget(castingColorPicker, 0.33)
    manager:Register(castingColorPicker, "all")

    local channelingColorPicker = GUIFrame:CreateColorPicker(row3a, "Channeling", {
        color = db.ChannelingColor,
        callback = function(r, g, b, a)
            db.ChannelingColor = { r, g, b, a }; ApplySettings()
        end
    })
    row3a:AddWidget(channelingColorPicker, 0.33)
    manager:Register(channelingColorPicker, "all")

    local shieldedColorPicker = GUIFrame:CreateColorPicker(row3a, "Shielded", {
        color = db.NotInterruptibleColor,
        callback = function(r, g, b, a)
            db.NotInterruptibleColor = { r, g, b, a }; ApplySettings()
        end
    })
    row3a:AddWidget(shieldedColorPicker, 0.34)
    manager:Register(shieldedColorPicker, "all")
    card3:AddRow(row3a, Theme.rowHeight)

    local sep3 = GUIFrame:CreateSeparator(card3.content)
    card3:AddRow(sep3, Theme.rowHeightSeparator)

    local row3b = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local bgColorPicker = GUIFrame:CreateColorPicker(row3b, "Background", {
        color = db.BackgroundColor,
        callback = function(r, g, b, a)
            db.BackgroundColor = { r, g, b, a }; ApplySettings()
        end
    })
    row3b:AddWidget(bgColorPicker, 0.33)
    manager:Register(bgColorPicker, "all")

    local borderColorPicker = GUIFrame:CreateColorPicker(row3b, "Border", {
        color = db.BorderColor,
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }; ApplySettings()
        end
    })
    row3b:AddWidget(borderColorPicker, 0.33)
    manager:Register(borderColorPicker, "all")

    local textColorPicker = GUIFrame:CreateColorPicker(row3b, "Text", {
        color = db.Text.TextColor,
        callback = function(r, g, b, a)
            db.Text.TextColor = { r, g, b, a }; ApplySettings()
        end
    })
    row3b:AddWidget(textColorPicker, 0.34)
    manager:Register(textColorPicker, "all")
    card3:AddRow(row3b, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card 4: Icon & Timer Settings
    local card4 = GUIFrame:CreateCard(scrollChild, "Icon & Timer", yOffset)
    manager:Register(card4, "all")

    local row4a = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local iconCheck = GUIFrame:CreateCheckbox(row4a, "Show Spell Icon", {
        value = db.Icon.Enabled,
        callback = function(checked)
            db.Icon.Enabled = checked; ApplySettings()
        end
    })
    row4a:AddWidget(iconCheck, 0.5)
    manager:Register(iconCheck, "all")

    local raidIconCheck = GUIFrame:CreateCheckbox(row4a, "Show Raid Target Icon", {
        value = db.RaidIcon.Enabled,
        callback = function(checked)
            db.RaidIcon.Enabled = checked; ApplySettings()
        end
    })
    row4a:AddWidget(raidIconCheck, 0.5)
    manager:Register(raidIconCheck, "all")
    card4:AddRow(row4a, Theme.rowHeight)

    local sep4a = GUIFrame:CreateSeparator(card4.content)
    card4:AddRow(sep4a, Theme.rowHeightSeparator)

    local row4b = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local raidIconSizeSlider = GUIFrame:CreateSlider(row4b, "Raid Icon Size", {
        min = 12,
        max = 40,
        step = 1,
        value = db.RaidIcon.Size,
        callback = function(value)
            db.RaidIcon.Size = value; ApplySettings()
        end
    })
    row4b:AddWidget(raidIconSizeSlider, 0.5)
    manager:Register(raidIconSizeSlider, "all")

    local sparkCheck = GUIFrame:CreateCheckbox(row4b, "Show Spark", {
        value = db.BarDisplay.SparkEnabled,
        callback = function(checked)
            db.BarDisplay.SparkEnabled = checked; ApplySettings()
        end
    })
    row4b:AddWidget(sparkCheck, 0.5)
    manager:Register(sparkCheck, "all")
    card4:AddRow(row4b, Theme.rowHeight)

    local sep4b = GUIFrame:CreateSeparator(card4.content)
    card4:AddRow(sep4b, Theme.rowHeightSeparator)

    local row4c = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
    local showTimeCheck = GUIFrame:CreateCheckbox(row4c, "Show Cast Time", {
        value = db.Text.ShowTime,
        callback = function(checked)
            db.Text.ShowTime = checked; ApplySettings()
        end
    })
    row4c:AddWidget(showTimeCheck, 1)
    manager:Register(showTimeCheck, "all")
    card4:AddRow(row4c, Theme.rowHeightLast, 0)

    yOffset = card4:GetNextOffset()

    -- Card 5: Target Settings
    local card5 = GUIFrame:CreateCard(scrollChild, "Target Settings", yOffset)
    manager:Register(card5, "all")

    local row5a = GUIFrame:CreateRow(card5.content, Theme.rowHeight)
    local targetCheck = GUIFrame:CreateCheckbox(row5a, "Show Cast Target", {
        value = db.Target.Enabled,
        callback = function(checked)
            db.Target.Enabled = checked
            UpdateTargetState()
            ApplySettings()
        end
    })
    row5a:AddWidget(targetCheck, 0.5)
    manager:Register(targetCheck, "all")

    local classColorCheck = GUIFrame:CreateCheckbox(row5a, "Use Class Colors", {
        value = db.Target.ShowClassColor,
        callback = function(checked)
            db.Target.ShowClassColor = checked; ApplySettings()
        end
    })
    row5a:AddWidget(classColorCheck, 0.5)
    manager:Register(classColorCheck, "all")
    table_insert(targetSubWidgets, classColorCheck)
    card5:AddRow(row5a, Theme.rowHeight)

    local sep5 = GUIFrame:CreateSeparator(card5.content)
    card5:AddRow(sep5, Theme.rowHeightSeparator)

    local row5b = GUIFrame:CreateRow(card5.content, Theme.rowHeightLast)
    local positionOptions = { { key = "LEFT", text = "Left" }, { key = "RIGHT", text = "Right" } }
    local positionDropdown = GUIFrame:CreateDropdown(row5b, "Target Position", {
        options = positionOptions,
        value = db.Target.Position,
        callback = function(selected)
            db.Target.Position = selected; ApplySettings()
        end
    })
    row5b:AddWidget(positionDropdown, 0.5)
    manager:Register(positionDropdown, "all")
    table_insert(targetSubWidgets, positionDropdown)

    local separatorOptions = {
        { key = "»", text = "»" },
        { key = "-", text = "-" },
        { key = ">", text = ">" },
        { key = ">>", text = ">>" },
        { key = "•", text = "•" },
        { key = "None", text = "None" },
    }
    local separatorDropdown = GUIFrame:CreateDropdown(row5b, "Separator", {
        options = separatorOptions,
        value = db.Target.Separator,
        callback = function(selected)
            db.Target.Separator = selected; ApplySettings()
        end
    })
    row5b:AddWidget(separatorDropdown, 0.5)
    manager:Register(separatorDropdown, "all")
    table_insert(targetSubWidgets, separatorDropdown)
    card5:AddRow(row5b, Theme.rowHeightLast, 0)
    table_insert(postUpdateCallbacks, UpdateTargetState)

    yOffset = card5:GetNextOffset()

    -- Card 6: Font Settings
    local fontCard, fontOffset, fontWidgets = GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, {
        db = db.BarDisplay,
        includeSoftOutline = true,
        fontSizeRange = { 8, 24 },
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
    manager:Register(fontCard, "all")
    manager:RegisterGroup(fontWidgets, "all")
    if fontCard.UpdateShadowState then table_insert(postUpdateCallbacks, fontCard.UpdateShadowState) end

    yOffset = fontOffset

    -- Card 7: Position
    local posCard, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db.Frame,
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = ApplyPosition,
    })
    manager:Register(posCard, "all")
    if posCard.positionWidgets then manager:RegisterGroup(posCard.positionWidgets, "all") end

    yOffset = posOffset

    UpdateAllWidgetStates()
    StartPreview()

    return yOffset
end)

---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

local SETTINGS_GROWTH_OPTIONS = {
    { key = "DOWN", text = "Down" },
    { key = "UP",   text = "Up" },
}

GUIFrame:RegisterContent("DT_Bars", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.DungeonTimers
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    ---@type DungeonTimers?
    local DT = NRSKNUI:GetModule("DungeonTimers", true)
    local manager = GUIFrame:CreateWidgetStateManager()

    local function ApplySettings()
        if DT and DT.UpdateFrameVisuals then DT:UpdateFrameVisuals() end
    end

    local function RefreshBarPreviews()
        if DT and DT.RefreshSettingsBarPreviews then DT:RefreshSettingsBarPreviews() end
    end

    local function ApplyAndUpdate()
        ApplySettings()
        RefreshBarPreviews()
    end

    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    if NRSKNUI.GUI and NRSKNUI.GUI.DungeonTimers and NRSKNUI.GUI.DungeonTimers.HideTextPreviews then
        NRSKNUI.GUI.DungeonTimers.HideTextPreviews()
    end

    if GUIFrame.selectedSidebarItem == "DT_Bars" and DT and DT.ShowSettingsBarPreviews then
        DT:ShowSettingsBarPreviews()
    end

    local TEXTURE_OPTIONS = {}
    if LSM then
        local textures = LSM:List("statusbar")
        for _, name in ipairs(textures) do
            table.insert(TEXTURE_OPTIONS, { key = name, text = name })
        end
    else
        TEXTURE_OPTIONS = { { key = "NorskenUI", text = "NorskenUI" } }
    end

    local displayCard = GUIFrame:CreateCard(scrollChild, "Bar Display Settings", yOffset)
    manager:Register(displayCard, "all")

    local row1 = GUIFrame:CreateRow(displayCard.content, Theme.rowHeight)
    local widthSlider = GUIFrame:CreateSlider(row1, "Bar Width", {
        min = 100,
        max = 400,
        step = 1,
        value = db.BarDisplay.barWidth or 200,
        labelWidth = 60,
        callback = function(val)
            db.BarDisplay.barWidth = val
            ApplyAndUpdate()
        end
    })
    row1:AddWidget(widthSlider, 0.5)
    manager:Register(widthSlider, "all")

    local heightSlider = GUIFrame:CreateSlider(row1, "Bar Height", {
        min = 12,
        max = 40,
        step = 1,
        value = db.BarDisplay.barHeight or 20,
        labelWidth = 60,
        callback = function(val)
            db.BarDisplay.barHeight = val
            ApplyAndUpdate()
        end
    })
    row1:AddWidget(heightSlider, 0.5)
    manager:Register(heightSlider, "all")
    displayCard:AddRow(row1, Theme.rowHeight)

    local barRow1 = GUIFrame:CreateRow(displayCard.content, Theme.rowHeight)
    local barGrowthDropdown = GUIFrame:CreateDropdown(barRow1, "Growth Direction", {
        options = SETTINGS_GROWTH_OPTIONS,
        value = db.BarGroup.GrowthDirection or "DOWN",
        callback = function(key)
            db.BarGroup.GrowthDirection = key
            ApplyAndUpdate()
        end
    })
    barRow1:AddWidget(barGrowthDropdown, 0.5)
    manager:Register(barGrowthDropdown, "all")

    local barSpacingSlider = GUIFrame:CreateSlider(barRow1, "Spacing", {
        min = -10,
        max = 20,
        step = 1,
        value = db.BarGroup.Spacing or 2,
        labelWidth = 50,
        callback = function(val)
            db.BarGroup.Spacing = val
            ApplyAndUpdate()
        end
    })
    barRow1:AddWidget(barSpacingSlider, 0.5)
    manager:Register(barSpacingSlider, "all")
    displayCard:AddRow(barRow1, Theme.rowHeight)

    local sep1 = GUIFrame:CreateSeparator(displayCard.content)
    displayCard:AddRow(sep1, Theme.rowHeightSeparator)

    local row2 = GUIFrame:CreateRow(displayCard.content, Theme.rowHeight)
    local useGlobalBarCheck = GUIFrame:CreateCheckbox(row2, "Use Global Bar Texture", {
        value = db.BarDisplay.UseGlobalBar ~= false,
        callback = function(checked)
            db.BarDisplay.UseGlobalBar = checked
            ApplyAndUpdate()
            UpdateAllWidgetStates()
        end
    })
    row2:AddWidget(useGlobalBarCheck, 0.5)
    manager:Register(useGlobalBarCheck, "all")

    manager:SetCondition("GlobalOn", function() return not db.BarDisplay.UseGlobalBar end)

    local textureDropdown = GUIFrame:CreateDropdown(row2, "Bar Texture", {
        options = TEXTURE_OPTIONS,
        value = db.BarDisplay.barTexture or "NorskenUI",
        callback = function(key)
            db.BarDisplay.barTexture = key
            ApplyAndUpdate()
        end,
        searchable = true
    })
    row2:AddWidget(textureDropdown, 0.5)
    manager:Register(textureDropdown, "all", "GlobalOn")
    displayCard:AddRow(row2, Theme.rowHeight)

    local sep2 = GUIFrame:CreateSeparator(displayCard.content)
    displayCard:AddRow(sep2, Theme.rowHeightSeparator)

    local row3 = GUIFrame:CreateRow(displayCard.content, Theme.rowHeightLast)
    local iconCheck = GUIFrame:CreateCheckbox(row3, "Show Icon", {
        value = db.BarDisplay.iconEnabled ~= false,
        callback = function(checked)
            db.BarDisplay.iconEnabled = checked
            ApplyAndUpdate()
        end
    })
    row3:AddWidget(iconCheck, 1)
    manager:Register(iconCheck, "all")
    displayCard:AddRow(row3, Theme.rowHeightLast, 0)

    yOffset = displayCard:GetNextOffset()

    local fontCard, fontOffset, fontWidgets = GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, {
        title = "Bar Font Settings",
        db = db.BarDisplay,
        includeSoftOutline = true,
        globalOverride = {},
        onChangeCallback = ApplyAndUpdate,
    })
    manager:Register(fontCard, "all")
    manager:RegisterGroup(fontWidgets, "all")

    yOffset = fontOffset

    local barPosCard, barPosYOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        title = "Bar Group Position",
        db = db.BarGroup.Position,
        onChangeCallback = ApplyAndUpdate,
    })
    manager:Register(barPosCard, "all")
    if barPosCard.positionWidgets then manager:RegisterGroup(barPosCard.positionWidgets, "all") end

    yOffset = barPosYOffset

    UpdateAllWidgetStates()

    return yOffset
end)

NRSKNUI.GUI = NRSKNUI.GUI or {}
NRSKNUI.GUI.DungeonTimers = NRSKNUI.GUI.DungeonTimers or {}

NRSKNUI.GUI.DungeonTimers.HideBarPreviews = function()
    local DT = NRSKNUI:GetModule("DungeonTimers", true)
    if DT and DT.HideSettingsBarPreviews then DT:HideSettingsBarPreviews() end
end

GUIFrame.onCloseCallbacks["DT_Bars"] = NRSKNUI.GUI.DungeonTimers.HideBarPreviews

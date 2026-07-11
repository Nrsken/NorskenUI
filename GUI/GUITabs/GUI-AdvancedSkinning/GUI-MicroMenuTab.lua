---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

GUIFrame:RegisterContent("MicroMenu", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.MicroMenu
    if not db or NRSKNUI:ShouldNotLoadModule() then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local MM = NRSKNUI:GetModule("MicroMenu", true)
    local manager = GUIFrame:CreateWidgetStateManager()

    manager:SetCondition("backdrop", function() return db.ShowBackdrop end)
    manager:SetCondition("mouseover", function() return db.Mouseover.Enabled end)

    local function ApplySettings() if MM then MM:ApplySettings() end end
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    -- Card 1
    local card1 = GUIFrame:CreateCard(scrollChild, "Micro Menu Skinning", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Micro Menu Skinning", {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule("MicroMenu")
            else
                NRSKNUI:DisableModule("MicroMenu")
            end
            UpdateAllWidgetStates()
            NRSKNUI:CreateReloadPrompt("Enabling/Disabling this UI element requires a reload to take full effect.")
        end,
        msgPopup = true,
        msgText = "Micro Menu Skinning",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2
    local card2 = GUIFrame:CreateCard(scrollChild, "Mouseover Settings", yOffset)
    manager:Register(card2, "all")

    local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local mouseOverDB = db.Mouseover
    local mouseoverCheck = GUIFrame:CreateCheckbox(row2, "Enable Micro Menu Mouseover", {
        value = mouseOverDB.Enabled,
        callback = function(checked)
            mouseOverDB.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end,
    })
    row2:AddWidget(mouseoverCheck, 0.5)
    manager:Register(mouseoverCheck, "all")

    local alphaSlider = GUIFrame:CreateSlider(row2, "Alpha When No Mouseover", {
        min = 0,
        max = 1,
        step = 0.1,
        value = mouseOverDB.Alpha,
        callback = function(val)
            mouseOverDB.Alpha = val
            ApplySettings()
        end
    })
    row2:AddWidget(alphaSlider, 0.5)
    manager:Register(alphaSlider, "all", "mouseover")
    card2:AddRow(row2, Theme.rowHeight)

    local row3 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local fadeInSlider = GUIFrame:CreateSlider(row3, "Fade In Duration", {
        min = 0,
        max = 10,
        step = 0.1,
        value = mouseOverDB.FadeInDuration,
        callback = function(val)
            mouseOverDB.FadeInDuration = val
        end
    })
    row3:AddWidget(fadeInSlider, 0.5)
    manager:Register(fadeInSlider, "all", "mouseover")

    local fadeOutSlider = GUIFrame:CreateSlider(row3, "Fade Out Duration", {
        min = 0,
        max = 10,
        step = 0.1,
        value = mouseOverDB.FadeOutDuration,
        callback = function(val)
            mouseOverDB.FadeOutDuration = val
        end
    })
    row3:AddWidget(fadeOutSlider, 0.5)
    manager:Register(fadeOutSlider, "all", "mouseover")
    card2:AddRow(row3, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3
    local card3 = GUIFrame:CreateCard(scrollChild, "Button Settings", yOffset)
    manager:Register(card3, "all")

    local row4 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local widthSlider = GUIFrame:CreateSlider(row4, "Button Width", {
        min = 5,
        max = 50,
        step = 1,
        value = db.ButtonWidth,
        callback = function(val)
            db.ButtonWidth = val
            ApplySettings()
        end
    })
    row4:AddWidget(widthSlider, 0.5)
    manager:Register(widthSlider, "all")

    local heightSlider = GUIFrame:CreateSlider(row4, "Button Height", {
        min = 5,
        max = 50,
        step = 1,
        value = db.ButtonHeight,
        callback = function(val)
            db.ButtonHeight = val
            ApplySettings()
        end
    })
    row4:AddWidget(heightSlider, 0.5)
    manager:Register(heightSlider, "all")
    card3:AddRow(row4, Theme.rowHeight)

    local row5 = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local spacingSlider = GUIFrame:CreateSlider(row5, "Button Spacing", {
        min = -20,
        max = 20,
        step = 1,
        value = db.ButtonSpacing,
        callback = function(val)
            db.ButtonSpacing = val
            ApplySettings()
        end
    })
    row5:AddWidget(spacingSlider, 1)
    manager:Register(spacingSlider, "all")
    card3:AddRow(row5, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card 4
    local card4 = GUIFrame:CreateCard(scrollChild, "Backdrop Settings", yOffset)
    manager:Register(card4, "all")

    local row6 = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local backdropCheck = GUIFrame:CreateCheckbox(row6, "Enable Backdrop", {
        value = db.ShowBackdrop,
        callback = function(checked)
            db.ShowBackdrop = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end,
    })
    row6:AddWidget(backdropCheck, 0.5)
    manager:Register(backdropCheck, "all")

    local backdropSpacingSlider = GUIFrame:CreateSlider(row6, "Backdrop Spacing", {
        min = 0,
        max = 20,
        step = 1,
        value = db.BackdropSpacing,
        callback = function(val)
            db.BackdropSpacing = val
            ApplySettings()
        end
    })
    row6:AddWidget(backdropSpacingSlider, 0.5)
    manager:Register(backdropSpacingSlider, "all", "backdrop")
    card4:AddRow(row6, Theme.rowHeight)

    local row7 = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
    local backdropColorPicker = GUIFrame:CreateColorPicker(row7, "Backdrop Color", {
        color = db.BackdropColor,
        callback = function(r, g, b, a)
            db.BackdropColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row7:AddWidget(backdropColorPicker, 0.5)
    manager:Register(backdropColorPicker, "all", "backdrop")

    local borderColorPicker = GUIFrame:CreateColorPicker(row7, "Border Color", {
        color = db.BackdropBorderColor,
        callback = function(r, g, b, a)
            db.BackdropBorderColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row7:AddWidget(borderColorPicker, 0.5)
    manager:Register(borderColorPicker, "all", "backdrop")
    card4:AddRow(row7, Theme.rowHeightLast, 0)

    yOffset = card4:GetNextOffset()

    -- Card 5
    local posCard, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })
    manager:Register(posCard, "all")

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local ANCHOR_OPTIONS = {
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

GUIFrame:RegisterContent("Minimap", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.Minimap
    if not db or NRSKNUI:ShouldNotLoadModule() then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local MAP = NRSKNUI:GetModule("Minimap", true)
    local manager = GUIFrame:CreateWidgetStateManager()

    manager:SetCondition("bugWidgets", function() return db.BugSack.Enabled end)
    manager:SetCondition("AddonCompWidgets", function() return not db.HideAddOnComp end)

    local function ApplySettings() if MAP then MAP:ApplySettings() end end
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    -- Card 1: Toggle
    local card1 = GUIFrame:CreateCard(scrollChild, "Minimap", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Minimap", {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule("Minimap")
            else
                NRSKNUI:DisableModule("Minimap")
            end
            UpdateAllWidgetStates()
            NRSKNUI:CreateReloadPrompt("Enabling/Disabling this UI element requires a reload to take full effect.")
        end,
        msgPopup = true,
        msgText = "Minimap",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeight)

    local sepRowInfo = GUIFrame:CreateSeparator(card1.content)
    card1:AddRow(sepRowInfo, Theme.rowHeightSeparator)

    local textRow1Size = 50
    local row1b = GUIFrame:CreateRow(card1.content, textRow1Size)
    local ttInfoText = GUIFrame:CreateText(row1b, NRSKNUI:ColorTextByTheme("Information"), {
        text = NRSKNUI:ColorTextByTheme("• ") .. "Mouse Middle-click: Opens calendar." .. "\n" ..
            NRSKNUI:ColorTextByTheme("• ") .. "Mouse Right-click: Opens tracking menu.",
        height = textRow1Size,
        bgMode = "hide"
    })
    row1b:AddWidget(ttInfoText, 1)
    manager:Register(ttInfoText, "all")
    card1:AddRow(row1b, textRow1Size)

    yOffset = card1:GetNextOffset()

    -- Card 2: Minimap Settings
    local card2 = GUIFrame:CreateCard(scrollChild, "Minimap Settings", yOffset)
    manager:Register(card2, "all")

    local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local MinimapSize = GUIFrame:CreateSlider(row2, "Minimap Size", {
        min = 50,
        max = 500,
        step = 1,
        value = db.Size,
        callback = function(val)
            db.Size = val
            if MAP then MAP:ApplyLayout({ deferZoom = true }) end
        end
    })
    row2:AddWidget(MinimapSize, 0.5)
    manager:Register(MinimapSize, "all")

    local MinimapScale = GUIFrame:CreateSlider(row2, "Minimap Scale", {
        min = 0.5,
        max = 2,
        step = 0.1,
        value = db.Scale,
        callback = function(val)
            db.Scale = val
            if MAP then MAP:ApplySettings({ scaleChanged = true }) end
        end
    })
    row2:AddWidget(MinimapScale, 0.5)
    manager:Register(MinimapScale, "all")
    card2:AddRow(row2, Theme.rowHeight)

    local sepRow1 = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sepRow1, Theme.rowHeightSeparator)

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local BorderSize = GUIFrame:CreateSlider(row2b, "Border Size", {
        min = 1,
        max = 10,
        step = 1,
        value = db.Border.Thickness,
        callback = function(val)
            db.Border.Thickness = val
            if MAP then MAP:UpdateMinimapBorder() end
        end
    })
    row2b:AddWidget(BorderSize, 0.5)
    manager:Register(BorderSize, "all")

    local BorderColor = GUIFrame:CreateColorPicker(row2b, "Border Color", {
        color = db.Border.Color,
        callback = function(r, g, b, a)
            db.Border.Color = { r, g, b, a }
            ApplySettings()
        end
    })
    row2b:AddWidget(BorderColor, 0.5)
    manager:Register(BorderColor, "all")
    card2:AddRow(row2b, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 4
    local card4 = GUIFrame:CreateCard(scrollChild, "BugSack Settings", yOffset)
    manager:Register(card4, "all")

    local row4a = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local BugSackEnbl = GUIFrame:CreateCheckbox(row4a, "Toggle BugSack Frame", {
        value = db.BugSack.Enabled ~= false,
        callback = function(checked)
            db.BugSack.Enabled = checked
            if MAP then MAP:CreateBugSackButton() end
            UpdateAllWidgetStates()
        end
    })
    row4a:AddWidget(BugSackEnbl, 1)
    manager:Register(BugSackEnbl, "all")
    card4:AddRow(row4a, Theme.rowHeight)

    local sepRow2 = GUIFrame:CreateSeparator(card4.content)
    card4:AddRow(sepRow2, Theme.rowHeightSeparator)

    local row4 = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local BugSackSize = GUIFrame:CreateSlider(row4, "BugSack Size", {
        min = 5,
        max = 50,
        step = 1,
        value = db.BugSack.Size,
        callback = function(val)
            db.BugSack.Size = val
            if MAP then MAP:UpdateBugSackButton() end
        end
    })
    row4:AddWidget(BugSackSize, 0.5)
    manager:Register(BugSackSize, "all", "bugWidgets")

    local BugSackAnchor = GUIFrame:CreateDropdown(row4, "Anchorpoint", {
        options = ANCHOR_OPTIONS,
        value = db.BugSack.Anchor,
        callback = function(key)
            db.BugSack.Anchor = key
            ApplySettings()
        end
    })
    row4:AddWidget(BugSackAnchor, 0.5)
    manager:Register(BugSackAnchor, "all", "bugWidgets")
    card4:AddRow(row4, Theme.rowHeight)

    local row4b = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
    local BugSackX = GUIFrame:CreateSlider(row4b, "X Offset", {
        min = -500,
        max = 500,
        step = 1,
        value = db.BugSack.X,
        callback = function(val)
            db.BugSack.X = val
            if MAP then MAP:UpdateBugSackButton() end
        end
    })
    row4b:AddWidget(BugSackX, 0.5)
    manager:Register(BugSackX, "all", "bugWidgets")

    local BugSackY = GUIFrame:CreateSlider(row4b, "Y Offset", {
        min = -500,
        max = 500,
        step = 1,
        value = db.BugSack.Y,
        callback = function(val)
            db.BugSack.Y = val
            if MAP then MAP:UpdateBugSackButton() end
        end
    })
    row4b:AddWidget(BugSackY, 0.5)
    manager:Register(BugSackY, "all", "bugWidgets")
    card4:AddRow(row4b, Theme.rowHeightLast, 0)

    yOffset = card4:GetNextOffset()

    -- Card: Mail Icon Settings
    local cardMail = GUIFrame:CreateCard(scrollChild, "Mail Icon Settings", yOffset)
    manager:Register(cardMail, "all")

    manager:SetCondition("mailWidgets", function() return db.Mail.Enabled end)

    local rowMailToggle = GUIFrame:CreateRow(cardMail.content, Theme.rowHeight)
    local MailEnabled = GUIFrame:CreateCheckbox(rowMailToggle, "Show Mail Icon", {
        value = db.Mail.Enabled,
        callback = function(checked)
            db.Mail.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    rowMailToggle:AddWidget(MailEnabled, 1)
    manager:Register(MailEnabled, "all")
    cardMail:AddRow(rowMailToggle, Theme.rowHeight)

    local sepRowMail = GUIFrame:CreateSeparator(cardMail.content)
    cardMail:AddRow(sepRowMail, Theme.rowHeightSeparator)

    local row3a = GUIFrame:CreateRow(cardMail.content, Theme.rowHeight)
    local MailScale = GUIFrame:CreateSlider(row3a, "Scale", {
        min = 0.5,
        max = 2,
        step = 0.1,
        value = db.Mail.Scale,
        callback = function(val)
            db.Mail.Scale = val
            ApplySettings()
        end
    })
    row3a:AddWidget(MailScale, 0.5)
    manager:Register(MailScale, "all", "mailWidgets")

    local mailAnchor = GUIFrame:CreateDropdown(row3a, "Anchorpoint", {
        options = ANCHOR_OPTIONS,
        value = db.Mail.Anchor,
        callback = function(key)
            db.Mail.Anchor = key
            ApplySettings()
        end
    })
    row3a:AddWidget(mailAnchor, 0.5)
    manager:Register(mailAnchor, "all", "mailWidgets")
    cardMail:AddRow(row3a, Theme.rowHeight)

    local row3b = GUIFrame:CreateRow(cardMail.content, Theme.rowHeightLast)
    local MailX = GUIFrame:CreateSlider(row3b, "X Offset", {
        min = -500,
        max = 500,
        step = 1,
        value = db.Mail.X,
        callback = function(val)
            db.Mail.X = val
            ApplySettings()
        end
    })
    row3b:AddWidget(MailX, 0.5)
    manager:Register(MailX, "all", "mailWidgets")

    local MailY = GUIFrame:CreateSlider(row3b, "Y Offset", {
        min = -500,
        max = 500,
        step = 1,
        value = db.Mail.Y,
        callback = function(val)
            db.Mail.Y = val
            ApplySettings()
        end
    })
    row3b:AddWidget(MailY, 0.5)
    manager:Register(MailY, "all", "mailWidgets")
    cardMail:AddRow(row3b, Theme.rowHeightLast, 0)

    yOffset = cardMail:GetNextOffset()

    -- Card: Instance Difficulty Settings
    local cardInst = GUIFrame:CreateCard(scrollChild, "Instance Difficulty Settings", yOffset)
    manager:Register(cardInst, "all")

    manager:SetCondition("instWidgets", function() return db.InstanceDifficulty.Enabled end)

    local rowInstToggle = GUIFrame:CreateRow(cardInst.content, Theme.rowHeight)
    local InstEnabled = GUIFrame:CreateCheckbox(rowInstToggle, "Show Instance Difficulty", {
        value = db.InstanceDifficulty.Enabled,
        callback = function(checked)
            db.InstanceDifficulty.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    rowInstToggle:AddWidget(InstEnabled, 1)
    manager:Register(InstEnabled, "all")
    cardInst:AddRow(rowInstToggle, Theme.rowHeight)

    local sepRowInst = GUIFrame:CreateSeparator(cardInst.content)
    cardInst:AddRow(sepRowInst, Theme.rowHeightSeparator)

    local rowInst1 = GUIFrame:CreateRow(cardInst.content, Theme.rowHeight)
    local InstScale = GUIFrame:CreateSlider(rowInst1, "Scale", {
        min = 0.5,
        max = 2,
        step = 0.1,
        value = db.InstanceDifficulty.Scale,
        callback = function(val)
            db.InstanceDifficulty.Scale = val
            ApplySettings()
        end
    })
    rowInst1:AddWidget(InstScale, 0.5)
    manager:Register(InstScale, "all", "instWidgets")

    local instAnchor = GUIFrame:CreateDropdown(rowInst1, "Anchorpoint", {
        options = ANCHOR_OPTIONS,
        value = db.InstanceDifficulty.Anchor,
        callback = function(key)
            db.InstanceDifficulty.Anchor = key
            ApplySettings()
        end
    })
    rowInst1:AddWidget(instAnchor, 0.5)
    manager:Register(instAnchor, "all", "instWidgets")
    cardInst:AddRow(rowInst1, Theme.rowHeight)

    local rowInst2 = GUIFrame:CreateRow(cardInst.content, Theme.rowHeightLast)
    local InstX = GUIFrame:CreateSlider(rowInst2, "X Offset", {
        min = -500,
        max = 500,
        step = 1,
        value = db.InstanceDifficulty.X,
        callback = function(val)
            db.InstanceDifficulty.X = val
            ApplySettings()
        end
    })
    rowInst2:AddWidget(InstX, 0.5)
    manager:Register(InstX, "all", "instWidgets")

    local InstY = GUIFrame:CreateSlider(rowInst2, "Y Offset", {
        min = -500,
        max = 500,
        step = 1,
        value = db.InstanceDifficulty.Y,
        callback = function(val)
            db.InstanceDifficulty.Y = val
            ApplySettings()
        end
    })
    rowInst2:AddWidget(InstY, 0.5)
    manager:Register(InstY, "all", "instWidgets")
    cardInst:AddRow(rowInst2, Theme.rowHeightLast, 0)

    yOffset = cardInst:GetNextOffset()

    -- Card: Queue Icon Settings
    local cardQ = GUIFrame:CreateCard(scrollChild, "Queue Icon Settings", yOffset)
    manager:Register(cardQ, "all")

    manager:SetCondition("queueWidgets", function() return db.QueueStatus.Enabled end)

    local rowQToggle = GUIFrame:CreateRow(cardQ.content, Theme.rowHeight)
    local QueueEnabled = GUIFrame:CreateCheckbox(rowQToggle, "Show Queue Icon", {
        value = db.QueueStatus.Enabled,
        callback = function(checked)
            db.QueueStatus.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    rowQToggle:AddWidget(QueueEnabled, 1)
    manager:Register(QueueEnabled, "all")
    cardQ:AddRow(rowQToggle, Theme.rowHeight)

    local sepRowQ = GUIFrame:CreateSeparator(cardQ.content)
    cardQ:AddRow(sepRowQ, Theme.rowHeightSeparator)

    local row1q = GUIFrame:CreateRow(cardQ.content, Theme.rowHeight)
    local QueueScale = GUIFrame:CreateSlider(row1q, "Scale", {
        min = 0.5,
        max = 2,
        step = 0.1,
        value = db.QueueStatus.Scale,
        callback = function(val)
            db.QueueStatus.Scale = val
            ApplySettings()
        end
    })
    row1q:AddWidget(QueueScale, 0.5)
    manager:Register(QueueScale, "all", "queueWidgets")

    local queueAnchor = GUIFrame:CreateDropdown(row1q, "Anchorpoint", {
        options = ANCHOR_OPTIONS,
        value = db.QueueStatus.Anchor,
        callback = function(key)
            db.QueueStatus.Anchor = key
            ApplySettings()
        end
    })
    row1q:AddWidget(queueAnchor, 0.5)
    manager:Register(queueAnchor, "all", "queueWidgets")
    cardQ:AddRow(row1q, Theme.rowHeight)

    local row2q = GUIFrame:CreateRow(cardQ.content, Theme.rowHeightLast)
    local QueueX = GUIFrame:CreateSlider(row2q, "X Offset", {
        min = -500,
        max = 500,
        step = 1,
        value = db.QueueStatus.X,
        callback = function(val)
            db.QueueStatus.X = val
            ApplySettings()
        end
    })
    row2q:AddWidget(QueueX, 0.5)
    manager:Register(QueueX, "all", "queueWidgets")

    local QueueY = GUIFrame:CreateSlider(row2q, "Y Offset", {
        min = -500,
        max = 500,
        step = 1,
        value = db.QueueStatus.Y,
        callback = function(val)
            db.QueueStatus.Y = val
            ApplySettings()
        end
    })
    row2q:AddWidget(QueueY, 0.5)
    manager:Register(QueueY, "all", "queueWidgets")
    cardQ:AddRow(row2q, Theme.rowHeightLast, 0)

    yOffset = cardQ:GetNextOffset()

    -- Card: Landing Page Button Settings
    local cardLP = GUIFrame:CreateCard(scrollChild, "Landing Page Button Settings", yOffset)
    manager:Register(cardLP, "all")

    manager:SetCondition("landingPageWidgets", function() return db.LandingPage.Enabled end)

    local row1lp = GUIFrame:CreateRow(cardLP.content, Theme.rowHeight)
    local LPEnabled = GUIFrame:CreateCheckbox(row1lp, "Show Landing Page Button", {
        value = db.LandingPage.Enabled,
        callback = function(checked)
            db.LandingPage.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row1lp:AddWidget(LPEnabled, 1)
    manager:Register(LPEnabled, "all")
    cardLP:AddRow(row1lp, Theme.rowHeight)

    local sepRowLP = GUIFrame:CreateSeparator(cardLP.content)
    cardLP:AddRow(sepRowLP, Theme.rowHeightSeparator)

    local row2lp = GUIFrame:CreateRow(cardLP.content, Theme.rowHeight)
    local LPSize = GUIFrame:CreateSlider(row2lp, "Size", {
        min = 16,
        max = 64,
        step = 1,
        value = db.LandingPage.Size,
        callback = function(val)
            db.LandingPage.Size = val
            if MAP then MAP:UpdateLandingPageBtn() end
        end
    })
    row2lp:AddWidget(LPSize, 0.5)
    manager:Register(LPSize, "all", "landingPageWidgets")

    local LPAnchor = GUIFrame:CreateDropdown(row2lp, "Anchorpoint", {
        options = ANCHOR_OPTIONS,
        value = db.LandingPage.Anchor,
        callback = function(key)
            db.LandingPage.Anchor = key
            if MAP then MAP:UpdateLandingPageBtn() end
        end
    })
    row2lp:AddWidget(LPAnchor, 0.5)
    manager:Register(LPAnchor, "all", "landingPageWidgets")
    cardLP:AddRow(row2lp, Theme.rowHeight)

    local row3lp = GUIFrame:CreateRow(cardLP.content, Theme.rowHeightLast)
    local LPX = GUIFrame:CreateSlider(row3lp, "X Offset", {
        min = -500,
        max = 500,
        step = 1,
        value = db.LandingPage.X,
        callback = function(val)
            db.LandingPage.X = val
            if MAP then MAP:UpdateLandingPageBtn() end
        end
    })
    row3lp:AddWidget(LPX, 0.5)
    manager:Register(LPX, "all", "landingPageWidgets")

    local LPY = GUIFrame:CreateSlider(row3lp, "Y Offset", {
        min = -500,
        max = 500,
        step = 1,
        value = db.LandingPage.Y,
        callback = function(val)
            db.LandingPage.Y = val
            if MAP then MAP:UpdateLandingPageBtn() end
        end
    })
    row3lp:AddWidget(LPY, 0.5)
    manager:Register(LPY, "all", "landingPageWidgets")
    cardLP:AddRow(row3lp, Theme.rowHeightLast, 0)

    yOffset = cardLP:GetNextOffset()

    -- Card: AddOn Compartment Settings
    local cardComp = GUIFrame:CreateCard(scrollChild, "AddOn Compartment Settings", yOffset)
    manager:Register(cardComp, "all")

    manager:SetCondition("AddonCompWidgets", function() return db.AddOnComp.Enabled end)

    local row1comp = GUIFrame:CreateRow(cardComp.content, Theme.rowHeight)
    local CompEnabled = GUIFrame:CreateCheckbox(row1comp, "Show AddOn Compartment", {
        value = db.AddOnComp.Enabled,
        callback = function(checked)
            db.AddOnComp.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row1comp:AddWidget(CompEnabled, 1)
    manager:Register(CompEnabled, "all")
    cardComp:AddRow(row1comp, Theme.rowHeight)

    local sepRowComp = GUIFrame:CreateSeparator(cardComp.content)
    cardComp:AddRow(sepRowComp, Theme.rowHeightSeparator)

    local row2comp = GUIFrame:CreateRow(cardComp.content, Theme.rowHeight)
    local compSize = GUIFrame:CreateSlider(row2comp, "Size", {
        min = 5,
        max = 50,
        step = 1,
        value = db.AddOnComp.Size,
        callback = function(val)
            db.AddOnComp.Size = val
            if MAP then MAP:UpdateAddonCompartment() end
        end
    })
    row2comp:AddWidget(compSize, 0.5)
    manager:Register(compSize, "all", "AddonCompWidgets")

    local compAnchor = GUIFrame:CreateDropdown(row2comp, "Anchorpoint", {
        options = ANCHOR_OPTIONS,
        value = db.AddOnComp.Anchor,
        callback = function(key)
            db.AddOnComp.Anchor = key
            ApplySettings()
        end
    })
    row2comp:AddWidget(compAnchor, 0.5)
    manager:Register(compAnchor, "all", "AddonCompWidgets")
    cardComp:AddRow(row2comp, Theme.rowHeight)

    local row3comp = GUIFrame:CreateRow(cardComp.content, Theme.rowHeightLast)
    local compX = GUIFrame:CreateSlider(row3comp, "X Offset", {
        min = -500,
        max = 500,
        step = 1,
        value = db.AddOnComp.X,
        callback = function(val)
            db.AddOnComp.X = val
            if MAP then MAP:UpdateAddonCompartment() end
        end
    })
    row3comp:AddWidget(compX, 0.5)
    manager:Register(compX, "all", "AddonCompWidgets")

    local compY = GUIFrame:CreateSlider(row3comp, "Y Offset", {
        min = -500,
        max = 500,
        step = 1,
        value = db.AddOnComp.Y,
        callback = function(val)
            db.AddOnComp.Y = val
            if MAP then MAP:UpdateAddonCompartment() end
        end
    })
    row3comp:AddWidget(compY, 0.5)
    manager:Register(compY, "all", "AddonCompWidgets")
    cardComp:AddRow(row3comp, Theme.rowHeightLast, 0)

    yOffset = cardComp:GetNextOffset()

    -- Card 6
    local posCard, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        dbKeys = {
            xOffset = "X",
            yOffset = "Y",
        },
        showAnchorFrameType = false,
        showStrata = false,
        onChangeCallback = ApplySettings,
    })
    manager:Register(posCard, "all")

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

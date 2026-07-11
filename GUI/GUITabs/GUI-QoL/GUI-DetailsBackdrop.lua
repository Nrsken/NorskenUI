---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local tonumber = tonumber
local ipairs = ipairs

GUIFrame:RegisterContent("DetailsBackdrop", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.DetailsBackdrop
    if not db or NRSKNUI:ShouldNotLoadModule() then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    if GUIFrame.pendingContext then
        local contextBackdrop = tonumber(GUIFrame.pendingContext)
        if contextBackdrop and contextBackdrop >= 1 and contextBackdrop <= 5 then db.currentEdit = contextBackdrop end
        GUIFrame.pendingContext = nil
    end

    local DBG = NRSKNUI:GetModule("DetailsBackdrop", true)
    local manager = GUIFrame:CreateWidgetStateManager()

    -- Santize older profiles old string format to new numeric format so that dropdown shows correct value.
    local curEdit = db.currentEdit
    if curEdit == "bgOne" then
        curEdit = 1
    elseif curEdit == "bgTwo" then
        curEdit = 2
    else
        curEdit = tonumber(curEdit) or 1
    end
    db.currentEdit = curEdit

    local backdropName = "Backdrop " .. curEdit

    -- Ensure the current edit backdrop exists in the DB, if not create it with default values, otherwise the tab will break.
    if not db.backdrops[curEdit] then
        db.backdrops[curEdit] = CopyTable(NRSKNUI.db.defaults.profile.Skinning.DetailsBackdrop.backdrops[1])
    end

    local function GetCurrentBackdropDB() return db.backdrops[curEdit] end

    manager:SetCondition("autoSizeWidgets", function() return GetCurrentBackdropDB().autoSize end)
    manager:SetCondition("manualSizeWidgets", function() return not GetCurrentBackdropDB().autoSize end)
    manager:SetCondition("backdropEnabled", function() return GetCurrentBackdropDB().Enabled end)

    local function ApplySettings() if DBG then DBG:UpdateBackdrop(curEdit) end end
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled ~= false) end

    -- Card 1
    local card1 = GUIFrame:CreateCard(scrollChild, "Details Backdrop", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Details Backdrop", {
        value = db.Enabled ~= false,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule("DetailsBackdrop")
            else
                NRSKNUI:DisableModule("DetailsBackdrop")
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = "Details Backdrop",
    })
    row1:AddWidget(enableCheck, 0.5)

    local editList = {
        { key = 1, text = "Backdrop 1" },
        { key = 2, text = "Backdrop 2" },
        { key = 3, text = "Backdrop 3" },
        { key = 4, text = "Backdrop 4" },
        { key = 5, text = "Backdrop 5" },
    }
    local editDropdown = GUIFrame:CreateDropdown(row1, "Select Backdrop To Edit", {
        options = editList,
        value = curEdit,
        callback = function(key)
            db.currentEdit = key
            GUIFrame:RefreshContent()
        end
    })
    row1:AddWidget(editDropdown, 0.5)
    manager:Register(editDropdown, "all")
    card1:AddRow(row1, Theme.rowHeight)

    local row1b = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableBackdrop = GUIFrame:CreateCheckbox(row1b, "Enable " .. backdropName, {
        value = db.backdrops[curEdit].Enabled ~= false,
        callback = function(checked)
            db.backdrops[curEdit].Enabled = checked
            if DBG then DBG:ApplySettings() end
            UpdateAllWidgetStates()
        end
    })
    row1b:AddWidget(enableBackdrop, 1)
    manager:Register(enableBackdrop, "all")
    card1:AddRow(row1b, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2
    local currentDB = GetCurrentBackdropDB()
    local card2 = GUIFrame:CreateCard(scrollChild, "Size Mode - " .. backdropName, yOffset)
    manager:Register(card2, "all")

    local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local autoSizeCheck = GUIFrame:CreateCheckbox(row2, "Auto Size to Parent Frame", {
        value = currentDB.autoSize,
        callback = function(checked, revert)
            if not checked then
                GetCurrentBackdropDB().autoSize = checked
                ApplySettings()
                UpdateAllWidgetStates()
                return
            end

            NRSKNUI:CreatePrompt({
                title = "Details Override",
                text = "This will override your current Details sizing. Are you sure?",
                onAccept = function()
                    GetCurrentBackdropDB().autoSize = checked
                    ApplySettings()
                    UpdateAllWidgetStates()
                end,
                onCancel = function()
                    revert(true)
                end,
                acceptText = "Yes",
                cancelText = "Cancel",
            })
        end
    })
    row2:AddWidget(autoSizeCheck, 1)
    manager:Register(autoSizeCheck, "all", "backdropEnabled")
    card2:AddRow(row2, Theme.rowHeight)

    local helpText = GUIFrame:CreateText(card2.content, NRSKNUI:ColorTextByTheme("Auto-Size Information"), {
        text = {
            "Automatically sizes the backdrop to fit your Details bars",
            "Bar height, spacing, and width are read from Details settings",
            "Anchor points are locked to BOTTOMRIGHT when enabled",
        },
        height = 70,
        bgMode = "hide"
    })
    card2:AddRow(helpText, 70)
    manager:Register(helpText, "all", "backdropEnabled")

    local sepRow2 = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sepRow2, Theme.rowHeightSeparator)

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local detailsBars = GUIFrame:CreateSlider(row2b, "Amount of bars to show", {
        min = 1,
        max = 25,
        step = 1,
        value = currentDB.detailsBars,
        callback = function(val)
            GetCurrentBackdropDB().detailsBars = val
            ApplySettings()
        end
    })
    row2b:AddWidget(detailsBars, 1)
    manager:Register(detailsBars, "all", "backdropEnabled", "autoSizeWidgets")
    card2:AddRow(row2b, Theme.rowHeight)

    local sepRow3 = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sepRow3, Theme.rowHeightSeparator)

    local row2e = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local BackdropWidth = GUIFrame:CreateSlider(row2e, "Backdrop Width (Manual)", {
        min = 10,
        max = 1000,
        step = 1,
        value = GetCurrentBackdropDB().width,
        callback = function(val)
            GetCurrentBackdropDB().width = val
            ApplySettings()
        end
    })
    row2e:AddWidget(BackdropWidth, 0.5)
    manager:Register(BackdropWidth, "all", "backdropEnabled", "manualSizeWidgets")

    local BackdropHeight = GUIFrame:CreateSlider(row2e, "Backdrop Height (Manual)", {
        min = 10,
        max = 1000,
        step = 1,
        value = GetCurrentBackdropDB().height,
        callback = function(val)
            GetCurrentBackdropDB().height = val
            ApplySettings()
        end
    })
    row2e:AddWidget(BackdropHeight, 0.5)
    manager:Register(BackdropHeight, "all", "backdropEnabled", "manualSizeWidgets")
    card2:AddRow(row2e, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3
    local card3 = GUIFrame:CreateCard(scrollChild, "Backdrop Color - " .. backdropName, yOffset)
    manager:Register(card3, "all")

    local row3 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local BackdropColor = GUIFrame:CreateColorPicker(row3, "Backdrop Color", {
        color = GetCurrentBackdropDB().BackgroundColor,
        callback = function(r, g, b, a)
            GetCurrentBackdropDB().BackgroundColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row3:AddWidget(BackdropColor, 1)
    manager:Register(BackdropColor, "all", "backdropEnabled")
    card3:AddRow(row3, Theme.rowHeight)

    local row3b = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local BorderColor = GUIFrame:CreateColorPicker(row3b, "Backdrop Border Color", {
        color = GetCurrentBackdropDB().BorderColor,
        callback = function(r, g, b, a)
            GetCurrentBackdropDB().BorderColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row3b:AddWidget(BorderColor, 1)
    manager:Register(BorderColor, "all", "backdropEnabled")
    card3:AddRow(row3b, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card 4
    local posCard, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        title = "Position - " .. backdropName,
        db = GetCurrentBackdropDB(),
        showAnchorFrameType = false,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })
    manager:Register(posCard, "all", "backdropEnabled")

    if posCard.AnchorButtonWidgets then
        for _, widget in ipairs(posCard.AnchorButtonWidgets) do
            local origSetEnabled = widget.SetEnabled
            widget.SetEnabled = function(self, enabled)
                local shouldDisable = GetCurrentBackdropDB().autoSize
                origSetEnabled(self, enabled and not shouldDisable)
            end
        end
    end

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

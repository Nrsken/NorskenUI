---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local GetMacroIndexByName = GetMacroIndexByName
local GetNumMacros = GetNumMacros
local CreateMacro = CreateMacro

GUIFrame:RegisterContent("TotemTracker", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.TotemTracker
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    ---@type TotemTracker?
    local TT = NRSKNUI:GetModule("TotemTracker", true)
    local manager = GUIFrame:CreateWidgetStateManager()

    manager:SetCondition("swipeOn", function() return db.Swipe end)

    local function ApplySettings() if TT then TT:ApplySettings() end end
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    -- Card 1: Enable
    local card1 = GUIFrame:CreateCard(scrollChild, "Totem Tracker", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Totem Tracker", {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if TT then
                if checked then
                    NRSKNUI:EnableModule("TotemTracker")
                else
                    NRSKNUI:DisableModule("TotemTracker")
                end
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = "Totem Tracker",
    })
    row1:AddWidget(enableCheck, (2 / 3))

    local previewBtn
    previewBtn = GUIFrame:CreateButton(row1, "Show Preview", {
        height = 30,
        callback = function()
            if TT and TT.TogglePreview then
                local isActive = TT:TogglePreview()
                previewBtn:SetLabel(isActive and "Hide Preview" or "Show Preview")
            end
        end
    })
    row1:AddWidget(previewBtn, (1 / 3), nil, 0, -6)
    if TT and TT.IsPreviewActive and TT:IsPreviewActive() then
        previewBtn:SetLabel("Hide Preview")
    end
    card1:AddRow(row1, Theme.rowHeight)

    yOffset = card1:GetNextOffset()

    -- Card 5: Destroy Totems Macro
    local macroCard = GUIFrame:CreateCard(scrollChild, "Destroy All Totems", yOffset)

    local macroName = "!NUIDestroyTotem"
    local macroIcon = "Boss_odunrunes_orange"
    local macroText =
    "/click NRSKNUI_DestroyTotem1\n/click NRSKNUI_DestroyTotem2\n/click NRSKNUI_DestroyTotem3\n/click NRSKNUI_DestroyTotem4\n/click NRSKNUI_DestroyTotem5"

    local infoHeight = 36
    local infoRow = GUIFrame:CreateRow(macroCard.content, infoHeight)
    local infoText = GUIFrame:CreateText(infoRow, NRSKNUI:ColorTextByTheme("Macro Info"), {
        text = "Click the button below to create a macro that instantly destroys all active totems.",
        height = infoHeight,
        bgMode = "hide",
    })
    infoRow:AddWidget(infoText, 1)
    macroCard:AddRow(infoRow, infoHeight)

    local infoRowSep = GUIFrame:CreateSeparator(macroCard.content)
    macroCard:AddRow(infoRowSep, Theme.rowHeightSeparator)

    local btnRow = GUIFrame:CreateRow(macroCard.content, Theme.rowHeightLast)
    local createBtn = GUIFrame:CreateButton(btnRow, "Create Macro", {
        height = 30,
        callback = function()
            if NRSKNUI:InCombat() then
                NRSKNUI:Print("Cannot create macros during combat.")
                return
            end

            local existingIndex = GetMacroIndexByName(macroName)
            if existingIndex and existingIndex > 0 then
                NRSKNUI:Print("Macro '" .. macroName .. "' already exists.")
                return
            end

            local numGlobal = GetNumMacros()
            if numGlobal >= MAX_ACCOUNT_MACROS then
                NRSKNUI:Print("No free macro slots available.")
                return
            end

            CreateMacro(macroName, macroIcon, macroText, false)
            NRSKNUI:Print("Macro '" .. macroName .. "' created! Drag it to your action bar.")
        end,
    })
    btnRow:AddWidget(createBtn, 1)
    macroCard:AddRow(btnRow, Theme.rowHeightLast - 8, 0)

    yOffset = macroCard:GetNextOffset()

    -- Card 2: Display Settings
    local card2 = GUIFrame:CreateCard(scrollChild, "Display Settings", yOffset)
    manager:Register(card2, "all")

    local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local sizeSlider = GUIFrame:CreateSlider(row2a, "Icon Size", {
        min = 20,
        max = 200,
        step = 1,
        value = db.IconSize,
        callback = function(val)
            db.IconSize = val
            ApplySettings()
        end
    })
    row2a:AddWidget(sizeSlider, 0.5)
    manager:Register(sizeSlider, "all")

    local spacingSlider = GUIFrame:CreateSlider(row2a, "Icon Spacing", {
        min = -40,
        max = 20,
        step = 1,
        value = db.IconSpacing,
        callback = function(val)
            db.IconSpacing = val
            ApplySettings()
        end
    })
    row2a:AddWidget(spacingSlider, 0.5)
    manager:Register(spacingSlider, "all")
    card2:AddRow(row2a, Theme.rowHeight)

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local showTimerCheck = GUIFrame:CreateCheckbox(row2b, "Show Timer", {
        value = db.ShowTimer,
        callback = function(checked)
            db.ShowTimer = checked
            ApplySettings()
        end
    })
    row2b:AddWidget(showTimerCheck, 0.5)
    manager:Register(showTimerCheck, "all")

    local growDropdown = GUIFrame:CreateDropdown(row2b, "Growth Direction", {
        options = {
            { key = "RIGHT", text = "Right" },
            { key = "LEFT",  text = "Left" },
            { key = "UP",    text = "Up" },
            { key = "DOWN",  text = "Down" },
        },
        value = db.GrowDirection,
        callback = function(key)
            db.GrowDirection = key
            ApplySettings()
        end
    })
    row2b:AddWidget(growDropdown, 0.5)
    manager:Register(growDropdown, "all")
    card2:AddRow(row2b, Theme.rowHeight)

    local separator3 = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(separator3, Theme.rowHeightSeparator)

    local rowSwipe = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local swipeCheck = GUIFrame:CreateCheckbox(rowSwipe, "Enable Swipe", {
        value = db.Swipe,
        callback = function(checked)
            db.Swipe = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    rowSwipe:AddWidget(swipeCheck, 0.5)
    manager:Register(swipeCheck, "all")

    local reverseCheck = GUIFrame:CreateCheckbox(rowSwipe, "Reverse Swipe", {
        value = db.Reverse,
        callback = function(checked)
            db.Reverse = checked
            ApplySettings()
        end
    })
    rowSwipe:AddWidget(reverseCheck, 0.5)
    manager:Register(reverseCheck, "all", "swipeOn")
    card2:AddRow(rowSwipe, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Timer Font Settings
    local fontCard, fontOffset, fontWidgets = GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, {
        title = "Timer Font",
        db = db,
        dbKeys = {
            fontFace = "FontFace",
            fontSize = "TimerFontSize",
            fontOutline = "FontOutline",
        },
        fontSizeRange = { 8, 32 },
        includeSoftOutline = false,
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
    manager:Register(fontCard, "all")
    manager:RegisterGroup(fontWidgets, "all")

    yOffset = fontOffset

    -- Card 4: Position
    local posCard, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })
    manager:Register(posCard, "all")
    if posCard.positionWidgets then
        manager:RegisterGroup(posCard.positionWidgets, "all")
    end

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

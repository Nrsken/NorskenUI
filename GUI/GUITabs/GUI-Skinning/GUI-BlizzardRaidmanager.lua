---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

GUIFrame:RegisterContent("BlizzardRM", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.BlizzardRM
    if not db or NRSKNUI:ShouldNotLoadModule() then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local BRMG = NRSKNUI:GetModule("BlizzardRM", true)
    local manager = GUIFrame:CreateWidgetStateManager()

    local function ApplySettings() if BRMG then BRMG:ApplySettings() end end
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled ~= false) end

    manager:SetCondition("mouseOverFade", function() return db.FadeOnMouseOut ~= false end)

    -- Card 1: Toggle
    local card1 = GUIFrame:CreateCard(scrollChild, "Raid Manager", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Raid Manager Styling", {
        value = db.Enabled ~= false,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule("BlizzardRM")
            else
                NRSKNUI:DisableModule("BlizzardRM")
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = "Raid Manager Styling",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Position Settings
    local card2 = GUIFrame:CreateCard(scrollChild, "Position Settings", yOffset)
    manager:Register(card2, "all")

    local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local ySlider = GUIFrame:CreateSlider(row2, "Y Offset", {
        min = -1100,
        max = 100,
        step = 1,
        value = db.Position.YOffset,
        callback = function(val)
            db.Position.YOffset = val
            ApplySettings()
        end
    })
    row2:AddWidget(ySlider, 1)
    manager:Register(ySlider, "all")
    card2:AddRow(row2, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Mouseover Settings
    local card3 = GUIFrame:CreateCard(scrollChild, "Mouseover Settings", yOffset)
    manager:Register(card3, "all")

    local row3 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local useFade = GUIFrame:CreateCheckbox(row3, "Enable Mouseover", {
        value = db.FadeOnMouseOut ~= false,
        callback = function(checked)
            db.FadeOnMouseOut = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end,
    })
    row3:AddWidget(useFade, 1)
    manager:Register(useFade, "all")
    card3:AddRow(row3, Theme.rowHeight)

    local row1sep = GUIFrame:CreateSeparator(card3.content)
    card3:AddRow(row1sep, Theme.rowHeightSeparator)

    local row4 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local FadeInDuration = GUIFrame:CreateSlider(row4, "Fade In Duration", {
        min = 0,
        max = 20,
        step = 0.1,
        value = db.FadeInDuration,
        callback = function(val)
            db.FadeInDuration = val
            ApplySettings()
        end
    })
    row4:AddWidget(FadeInDuration, 0.5)
    manager:Register(FadeInDuration, "all", "mouseOverFade")

    local FadeOutDuration = GUIFrame:CreateSlider(row4, "Fade Out Duration", {
        min = 0,
        max = 20,
        step = 0.1,
        value = db.FadeOutDuration,
        callback = function(val)
            db.FadeOutDuration = val
            ApplySettings()
        end
    })
    row4:AddWidget(FadeOutDuration, 0.5)
    manager:Register(FadeOutDuration, "all", "mouseOverFade")
    card3:AddRow(row4, Theme.rowHeight)

    local row5 = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local Alpha = GUIFrame:CreateSlider(row5, "Alpha", {
        min = 0,
        max = 1,
        step = 0.1,
        value = db.Alpha,
        callback = function(val)
            db.Alpha = val
            ApplySettings()
        end
    })
    row5:AddWidget(Alpha, 1)
    manager:Register(Alpha, "all", "mouseOverFade")
    card3:AddRow(row5, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    UpdateAllWidgetStates()

    return yOffset
end)

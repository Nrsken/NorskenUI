---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

GUIFrame:RegisterContent("BlizzardMouseover", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.BlizzardMouseover
    if not db or NRSKNUI:ShouldNotLoadModule() then GUIFrame:ShowDBError(scrollChild, yOffset) end

    ---@type BlizzardMouseover?
    local BMO = NRSKNUI:GetModule("BlizzardMouseover", true)
    local manager = GUIFrame:CreateWidgetStateManager()
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    local function ApplySettings() if BMO then BMO:ApplySettings() end end

    -- Card 1: Toggle
    local card1 = GUIFrame:CreateCard(scrollChild, "Blizzard Mouseover", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Blizzard Mouseover", {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule("BlizzardMouseover")
            else
                NRSKNUI:DisableModule("BlizzardMouseover")
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = "Blizzard Mouseover",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeight)

    local sepRow1 = GUIFrame:CreateSeparator(card1.content)
    card1:AddRow(sepRow1, Theme.rowHeightSeparator)

    local textRow1Size = 30
    local row1b = GUIFrame:CreateRow(card1.content, textRow1Size)
    local ttInfoText = GUIFrame:CreateText(row1b, NRSKNUI:ColorTextByTheme("Elements Supported"), {
        text = NRSKNUI:ColorTextByTheme("• ") .. "Bag Bar",
        height = textRow1Size,
        bgMode = "hide"
    })
    row1b:AddWidget(ttInfoText, 1)
    manager:Register(ttInfoText, "all")
    card1:AddRow(row1b, textRow1Size)

    yOffset = card1:GetNextOffset()

    -- Card 2: Settings
    local card2 = GUIFrame:CreateCard(scrollChild, "Mouseover Settings", yOffset)
    manager:Register(card2, "all")

    local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local nonMouseoverAlpha = GUIFrame:CreateSlider(row2, "Alpha When No Mouseover", {
        min = 0,
        max = 1,
        step = 0.1,
        value = db.Alpha,
        callback = function(val)
            db.Alpha = val
            ApplySettings()
        end
    })
    row2:AddWidget(nonMouseoverAlpha, 1)
    manager:Register(nonMouseoverAlpha, "all")
    card2:AddRow(row2, Theme.rowHeight)

    local row3 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local FadeInDuration = GUIFrame:CreateSlider(row3, "Fade In Duration", {
        min = 0,
        max = 10,
        step = 0.1,
        value = db.FadeInDuration,
        callback = function(val)
            db.FadeInDuration = val
        end
    })
    row3:AddWidget(FadeInDuration, 0.5)
    manager:Register(FadeInDuration, "all")

    local FadeOutDuration = GUIFrame:CreateSlider(row3, "Fade Out Duration", {
        min = 0,
        max = 10,
        step = 0.1,
        value = db.FadeOutDuration,
        callback = function(val)
            db.FadeOutDuration = val
        end
    })
    row3:AddWidget(FadeOutDuration, 0.5)
    manager:Register(FadeOutDuration, "all")
    card2:AddRow(row3, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Mouseover Elements
    local card3 = GUIFrame:CreateCard(scrollChild, "Blizzard Elements To Mouseover", yOffset)
    manager:Register(card3, "all")

    local row4 = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local bagEnableCheck = GUIFrame:CreateCheckbox(row4, "Enable BagBar Mouseover", {
        value = db.BagMouseover.Enabled,
        callback = function(checked)
            db.BagMouseover.Enabled = checked
            if BMO then
                BMO:ToggleElement("bags", checked)
                ApplySettings()
            end
        end,
    })
    row4:AddWidget(bagEnableCheck, 1)
    manager:Register(bagEnableCheck, "all")
    card3:AddRow(row4, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    UpdateAllWidgetStates()

    return yOffset
end)

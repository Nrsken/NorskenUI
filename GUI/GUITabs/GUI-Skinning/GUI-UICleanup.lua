---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

GUIFrame:RegisterContent("UICleanup", function(scrollChild, yOffset)
    if NRSKNUI:ShouldNotLoadModule() then return GUIFrame:ShowDBError(scrollChild, yOffset) end
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.UICleanup
    if not db then GUIFrame:ShowDBError(scrollChild, yOffset) end
    local manager = GUIFrame:CreateWidgetStateManager()

    ---@type UICleanup?
    local UIC = NRSKNUI:GetModule("UICleanup", true)
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    -- Card 1: UICleanup Toggle
    local card1 = GUIFrame:CreateCard(scrollChild, "General UICleanup", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable UICleanup", {
        value = db.HideBlizzardClutter ~= false,
        callback = function(checked)
            db.HideBlizzardClutter = checked
            if UIC then
                if checked then
                    NRSKNUI:EnableModule("UICleanup")
                else
                    NRSKNUI:DisableModule("UICleanup")
                end
            end
            UpdateAllWidgetStates()
            if not db.HideBlizzardClutter then
                NRSKNUI:CreateReloadPrompt("Enabling Blizzard UI elements requires a reload to take full effect.")
            end
        end,
        msgPopup = true,
        msgText = "UICleanup",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    local sepRow1 = GUIFrame:CreateSeparator(card1.content)
    card1:AddRow(sepRow1, Theme.rowHeightSeparator)

    local hiddenNames = {
        "Objective Tracker Background",
        "Quest Tracker Background",
        "World Quest Tracker Background",
        "Scenario Tracker Background",
        "Monthly Activities Tracker Background",
        "Bonus Objective Tracker Background",
        "Professions Tracker Background",
        "Achievement Tracker Background",
        "Campaign Tracker Background",
    }
    local rowHeight = 165
    local row = GUIFrame:CreateRow(card1.content, rowHeight)
    local textWidget = GUIFrame:CreateText(row, NRSKNUI:ColorTextByTheme("Hides The Following Frames"), {
        text = function()
            return hiddenNames
        end,
        height = rowHeight,
        bgMode = "hide"
    })
    row:AddWidget(textWidget, 1)
    manager:Register(textWidget, "all")
    card1:AddRow(row, rowHeight)

    yOffset = card1:GetNextOffset()

    UpdateAllWidgetStates()

    return yOffset
end)

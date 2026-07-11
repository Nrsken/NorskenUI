---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

GUIFrame:RegisterContent("Battlenet", function(scrollChild, yOffset)
    if NRSKNUI:ShouldNotLoadModule() then return GUIFrame:ShowDBError(scrollChild, yOffset) end
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.Battlenet
    if not db then GUIFrame:ShowDBError(scrollChild, yOffset) end
    local manager = GUIFrame:CreateWidgetStateManager()

    ---@type Battlenet?
    local BNET = NRSKNUI:GetModule("Battlenet", true)
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end
    local function ApplySettings() if BNET then BNET:ApplySettings() end end

    -- Card 1: Toggle
    local card1 = GUIFrame:CreateCard(scrollChild, "Battlenet Popup Skin", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Battlenet Popup Skin", {
        value = db.Enabled ~= false,
        callback = function(checked)
            db.Enabled = checked
            if BNET then
                if checked then
                    NRSKNUI:EnableModule("Battlenet")
                else
                    NRSKNUI:DisableModule("Battlenet")
                end
            end
            UpdateAllWidgetStates()
            if not db.Enabled then
                NRSKNUI:CreateReloadPrompt("Enabling Blizzard UI elements requires a reload to take full effect.")
            end
        end,
        msgPopup = true,
        msgText = "Battlenet Popup Skin",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Position
    local posCard, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = false,
        showStrata = false,
        onChangeCallback = ApplySettings,
    })
    manager:Register(posCard, "all")

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class Tweaks
local Tweaks = NRSKNUI:GetModule('Tweaks')
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

GUIFrame:RegisterContent('Tweaks', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.Tweaks
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local manager = GUIFrame:CreateWidgetStateManager()
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    -- Card 1: Enable
    local card1 = GUIFrame:CreateCard(scrollChild, 'Tweaks', yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, 'Enable Tweaks', {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule('Tweaks')
            else
                NRSKNUI:DisableModule('Tweaks')
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = 'Tweaks',
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Hide Misc Elements
    local card2 = GUIFrame:CreateCard(scrollChild, 'Hide Misc Elements', yOffset)
    manager:Register(card2, 'all')

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local hideTalkingHeadCheck = GUIFrame:CreateCheckbox(row2b, 'Hide Talking Head Frame', {
        value = db.HideTalkingHead,
        callback = function(checked)
            db.HideTalkingHead = checked
            Tweaks:ApplySettings()
        end
    })
    row2b:AddWidget(hideTalkingHeadCheck, 1)
    manager:Register(hideTalkingHeadCheck, 'all')
    card2:AddRow(row2b, Theme.rowHeight)

    local row2d = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local hideBossBannerCheck = GUIFrame:CreateCheckbox(row2d, 'Hide Boss Banner', {
        value = db.HideBossBanner,
        callback = function(checked)
            db.HideBossBanner = checked
            Tweaks:ApplySettings()
        end
    })
    row2d:AddWidget(hideBossBannerCheck, 1)
    manager:Register(hideBossBannerCheck, 'all')
    card2:AddRow(row2d, Theme.rowHeight)

    yOffset = card2:GetNextOffset()

    -- Card 3: Misc Tweaks
    local card3 = GUIFrame:CreateCard(scrollChild, 'Misc Tweaks', yOffset)
    manager:Register(card3, 'all')

    local row3c = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local useGuildCheck = GUIFrame:CreateCheckbox(row3c, 'Confirm Popups with Enter', {
        value = db.EnterAccept,
        callback = function(checked)
            db.EnterAccept = checked
            Tweaks:ApplySettings()
            if not checked then
                NRSKNUI:CreateReloadPrompt("Disabling this setting requires a UI reload to take effect. Reload now?")
            end
        end
    })
    row3c:AddWidget(useGuildCheck, 1)
    manager:Register(useGuildCheck, 'all')
    card3:AddRow(row3c, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    UpdateAllWidgetStates()

    return yOffset
end)

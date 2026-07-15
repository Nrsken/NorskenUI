---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class Recuperate
local Recuperate = NRSKNUI:GetModule('Recuperate')
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

GUIFrame:RegisterContent('Recuperate', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.Recuperate
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local manager = GUIFrame:CreateWidgetStateManager()
    local function ApplySettings() Recuperate:ApplySettings() end
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    -- Card 1: Enable
    local card1 = GUIFrame:CreateCard(scrollChild, 'Recuperate Button', yOffset)

    local row1a = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
    local enableCheck = GUIFrame:CreateCheckbox(row1a, 'Enable Recuperate Button', {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule('Recuperate')
            else
                NRSKNUI:DisableModule('Recuperate')
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = 'Recuperate Button',
    })
    row1a:AddWidget(enableCheck, 1)
    card1:AddRow(row1a, Theme.rowHeight)

    -- Quick TLDR
    local textRow5abSize = 50
    local infoRow = GUIFrame:CreateRow(card1.content, textRow5abSize)
    local infoRowText = GUIFrame:CreateText(infoRow, NRSKNUI:ColorTextByTheme('Functionality Info'), {
        text = NRSKNUI:ColorTextByTheme('• ') ..
            'Because of restrictions i cannot fully hide the button when loaded and at ' ..
            '|cffFFFFFFfull health|r' .. ' and ' .. '|cffFFFFFFnot in combat.|r' ..
            '\n  This means that the button is invisible but is still clickable.',
        height = textRow5abSize,
        bgMode = 'hide'
    })
    infoRow:AddWidget(infoRowText, 1)
    manager:Register(infoRowText, 'all')
    card1:AddRow(infoRow, textRow5abSize)

    -- Separator
    local sep = GUIFrame:CreateSeparator(card1.content)
    card1:AddRow(sep, Theme.rowHeightSeparator)

    -- Load in Raid
    local row1b = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
    local loadInRaidCheck = GUIFrame:CreateCheckbox(row1b, 'Load in Raid', {
        value = db.LoadInRaid,
        callback = function(checked)
            db.LoadInRaid = checked
            if Recuperate then Recuperate:UpdateStateDriver() end
        end
    })
    row1b:AddWidget(loadInRaidCheck, 1)
    manager:Register(loadInRaidCheck, 'all')
    card1:AddRow(row1b, Theme.rowHeight)

    -- Load in Party
    local row1c = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local loadInPartyCheck = GUIFrame:CreateCheckbox(row1c, 'Load in Party', {
        value = db.LoadInParty,
        callback = function(checked)
            db.LoadInParty = checked
            if Recuperate then Recuperate:UpdateStateDriver() end
        end
    })
    row1c:AddWidget(loadInPartyCheck, 1)
    manager:Register(loadInPartyCheck, 'all')
    card1:AddRow(row1c, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Size
    local card2 = GUIFrame:CreateCard(scrollChild, 'Size Settings', yOffset)
    manager:Register(card2, 'all')

    -- Button Size
    local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local sizeSlider = GUIFrame:CreateSlider(row2, 'Button Size', {
        min = 16,
        max = 128,
        step = 1,
        value = db.Size,
        callback = function(val)
            db.Size = val
            ApplySettings()
        end
    })
    row2:AddWidget(sizeSlider, 1)
    manager:Register(sizeSlider, 'all')
    card2:AddRow(row2, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Position
    local card3, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = false,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })
    manager:Register(card3, 'all')
    if card3.positionWidgets then manager:RegisterGroup(card3.positionWidgets, 'all') end

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

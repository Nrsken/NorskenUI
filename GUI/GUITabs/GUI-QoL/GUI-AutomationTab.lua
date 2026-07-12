---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class Automation
local Automation = NRSKNUI:GetModule('Automation')
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

GUIFrame:RegisterContent('Automation', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.Automation
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local manager = GUIFrame:CreateWidgetStateManager()
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end
    manager:SetCondition('bonusRollQuest', function() return db.AutoBonusRollQuest end)
    manager:SetCondition('autoRepair', function() return db.AutoRepair end)
    manager:SetCondition('autoLoot', function() return db.AutoLoot end)

    -- Card 1: Enable
    local card1 = GUIFrame:CreateCard(scrollChild, 'Automation', yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, 'Enable Automation', {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule('Automation')
            else
                NRSKNUI:DisableModule('Automation')
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = 'Automation',
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card: Override Key (gates every automation feature below)
    local cardOverride = GUIFrame:CreateCard(scrollChild, 'Override Key', yOffset)
    manager:Register(cardOverride, 'all')

    local rowOverride = GUIFrame:CreateRow(cardOverride.content, Theme.rowHeightLast)
    local overrideKeyDropdown = GUIFrame:CreateDropdown(rowOverride, 'Override Key', {
        value = db.OverrideKey,
        options = {
            { text = 'Shift', value = 'Shift' },
            { text = 'Alt',   value = 'Alt' },
            { text = 'Ctrl',  value = 'Ctrl' },
            { text = 'Cmd',   value = 'Cmd' },
        },
        callback = function(value)
            db.OverrideKey = value
            Automation:ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    rowOverride:AddWidget(overrideKeyDropdown, 0.5)
    manager:Register(overrideKeyDropdown, 'all')

    local overrideModeDropdown = GUIFrame:CreateDropdown(rowOverride, 'Override Behaviour', {
        value = db.OverrideMode,
        options = {
            { text = 'Hold to Skip',   value = 'Block' },
            { text = 'Hold to Enable', value = 'Require' },
        },
        callback = function(value)
            db.OverrideMode = value
            Automation:ApplySettings()
        end
    })
    rowOverride:AddWidget(overrideModeDropdown, 0.5)
    manager:Register(overrideModeDropdown, 'all')
    cardOverride:AddRow(rowOverride, Theme.rowHeightLast, 0)

    local sep1 = GUIFrame:CreateSeparator(cardOverride.content)
    cardOverride:AddRow(sep1, Theme.rowHeightSeparator)

    local overrideTag = '|cffffffff' .. '*' .. '|r'
    local textRowSize = 32
    local infoRow = GUIFrame:CreateRow(cardOverride.content, textRowSize)
    local infoText = GUIFrame:CreateText(infoRow, NRSKNUI:ColorTextByTheme('Override Info'), {
        text = NRSKNUI:ColorTextByTheme('• ') ..
            'Automation features that has override support are marked with ' .. overrideTag,
        height = textRowSize,
        bgMode = 'hide'
    })
    infoRow:AddWidget(infoText, 1)
    manager:Register(infoText, 'all')
    cardOverride:AddRow(infoRow, textRowSize)

    yOffset = cardOverride:GetNextOffset()

    -- Card 2: Cinematics & Dialogs
    local card2 = GUIFrame:CreateCard(scrollChild, 'Cinematics & Dialogs', yOffset)
    manager:Register(card2, 'all')

    local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local skipCinematicsCheck = GUIFrame:CreateCheckbox(row2a, 'Skip Cinematics & Movies', {
        value = db.SkipCinematics,
        callback = function(checked)
            db.SkipCinematics = checked
            Automation:ApplySettings()
        end
    })
    row2a:AddWidget(skipCinematicsCheck, 1)
    manager:Register(skipCinematicsCheck, 'all')
    card2:AddRow(row2a, Theme.rowHeight)

    local row2c = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local hideHelptipsCheck = GUIFrame:CreateCheckbox(row2c, 'Hide Spammy Tutorial Helptips', {
        value = db.HideHelptips,
        callback = function(checked)
            db.HideHelptips = checked
            Automation:ApplySettings()
        end
    })
    row2c:AddWidget(hideHelptipsCheck, 1)
    manager:Register(hideHelptipsCheck, 'all')
    card2:AddRow(row2c, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Merchant Automation
    local card3 = GUIFrame:CreateCard(scrollChild, 'Merchant Automation', yOffset)
    manager:Register(card3, 'all')
    local useGuildCheck

    local row3a = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local autoSellCheck = GUIFrame:CreateCheckbox(row3a, 'Auto Sell Junk/Grey Items ' .. overrideTag, {
        value = db.AutoSellJunk,
        callback = function(checked)
            db.AutoSellJunk = checked
            Automation:ApplySettings()
        end
    })
    row3a:AddWidget(autoSellCheck, 1)
    manager:Register(autoSellCheck, 'all')
    card3:AddRow(row3a, Theme.rowHeight)

    local row3b = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local autoRepairCheck = GUIFrame:CreateCheckbox(row3b, 'Auto Repair Gear ' .. overrideTag, {
        value = db.AutoRepair,
        callback = function(checked)
            db.AutoRepair = checked
            Automation:ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row3b:AddWidget(autoRepairCheck, 1)
    manager:Register(autoRepairCheck, 'all')
    card3:AddRow(row3b, Theme.rowHeight)

    local row3c = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    useGuildCheck = GUIFrame:CreateCheckbox(row3c, 'Use Guild Funds for Repair', {
        value = db.UseGuildFunds,
        callback = function(checked)
            db.UseGuildFunds = checked
            Automation:ApplySettings()
        end
    })
    row3c:AddWidget(useGuildCheck, 1)
    manager:Register(useGuildCheck, 'all', 'autoRepair')
    card3:AddRow(row3c, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card 4: Group Finder
    local card4 = GUIFrame:CreateCard(scrollChild, 'Group Finder', yOffset)
    manager:Register(card4, 'all')

    local row4 = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
    local autoRoleCheck = GUIFrame:CreateCheckbox(row4, 'Auto Accept Role Check ' .. overrideTag, {
        value = db.AutoRoleCheck,
        tooltip = 'Role based on selected roles in the Group Finder.',
        callback = function(checked)
            db.AutoRoleCheck = checked
            Automation:ApplySettings()
        end
    })
    row4:AddWidget(autoRoleCheck, 1)
    manager:Register(autoRoleCheck, 'all')
    card4:AddRow(row4, Theme.rowHeightLast, 0)

    yOffset = card4:GetNextOffset()

    -- Card 5: Convenience
    local card5 = GUIFrame:CreateCard(scrollChild, 'Convenience', yOffset)
    manager:Register(card5, 'all')

    local row5a = GUIFrame:CreateRow(card5.content, Theme.rowHeight)
    local autoFillDeleteCheck = GUIFrame:CreateCheckbox(row5a, 'Auto-Fill DELETE Text', {
        value = db.AutoFillDelete,
        callback = function(checked)
            db.AutoFillDelete = checked
            Automation:ApplySettings()
        end
    })
    row5a:AddWidget(autoFillDeleteCheck, 1)
    manager:Register(autoFillDeleteCheck, 'all')
    card5:AddRow(row5a, Theme.rowHeight)

    local row5b = GUIFrame:CreateRow(card5.content, Theme.rowHeightLast)
    local autoLootCheck = GUIFrame:CreateCheckbox(row5b, 'Auto Loot', {
        value = db.AutoLoot,
        callback = function(checked)
            db.AutoLoot = checked
            Automation:ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row5b:AddWidget(autoLootCheck, 0.5)
    manager:Register(autoLootCheck, 'all')

    local fastLootCheck = GUIFrame:CreateCheckbox(row5b, 'Fast Loot', {
        value = db.FastLoot,
        callback = function(checked)
            db.FastLoot = checked
            Automation:ApplySettings()
        end
    })
    row5b:AddWidget(fastLootCheck, 0.5)
    manager:Register(fastLootCheck, 'all', 'autoLoot')
    card5:AddRow(row5b, Theme.rowHeightLast, 0)

    yOffset = card5:GetNextOffset()

    -- Card 6: Quests
    local card6 = GUIFrame:CreateCard(scrollChild, 'Quests', yOffset)
    manager:Register(card6, 'all')

    local row6a = GUIFrame:CreateRow(card6.content, Theme.rowHeight)
    local autoAcceptRegularCheck = GUIFrame:CreateCheckbox(row6a, 'Auto Accept Regular Quests ' .. overrideTag, {
        value = db.AutoAcceptRegular,
        callback = function(checked)
            db.AutoAcceptRegular = checked
            Automation:ApplySettings()
        end
    })
    row6a:AddWidget(autoAcceptRegularCheck, 0.5)
    manager:Register(autoAcceptRegularCheck, 'all')

    local autoAcceptEventCheck = GUIFrame:CreateCheckbox(row6a, 'Auto Accept Event Quests ' .. overrideTag, {
        value = db.AutoAcceptEvent,
        callback = function(checked)
            db.AutoAcceptEvent = checked
            Automation:ApplySettings()
        end
    })
    row6a:AddWidget(autoAcceptEventCheck, 0.5)
    manager:Register(autoAcceptEventCheck, 'all')
    card6:AddRow(row6a, Theme.rowHeight)

    local row6b = GUIFrame:CreateRow(card6.content, Theme.rowHeight)
    local autoAcceptDailyCheck = GUIFrame:CreateCheckbox(row6b, 'Auto Accept Daily Quests ' .. overrideTag, {
        value = db.AutoAcceptDaily,
        callback = function(checked)
            db.AutoAcceptDaily = checked
            Automation:ApplySettings()
        end
    })
    row6b:AddWidget(autoAcceptDailyCheck, 0.5)
    manager:Register(autoAcceptDailyCheck, 'all')

    local autoAcceptWeeklyCheck = GUIFrame:CreateCheckbox(row6b, 'Auto Accept Weekly Quests ' .. overrideTag, {
        value = db.AutoAcceptWeekly,
        callback = function(checked)
            db.AutoAcceptWeekly = checked
            Automation:ApplySettings()
        end
    })
    row6b:AddWidget(autoAcceptWeeklyCheck, 0.5)
    manager:Register(autoAcceptWeeklyCheck, 'all')
    card6:AddRow(row6b, Theme.rowHeight)

    local row6c = GUIFrame:CreateRow(card6.content, Theme.rowHeight)
    local autoCompleteQuestCheck = GUIFrame:CreateCheckbox(row6c, 'Auto Complete Quests ' .. overrideTag, {
        value = db.AutoCompleteQuest,
        tooltip = 'Automatically complete and turn in quests when there is no reward choice.',
        callback = function(checked)
            db.AutoCompleteQuest = checked
            Automation:ApplySettings()
        end
    })
    row6c:AddWidget(autoCompleteQuestCheck, 1)
    manager:Register(autoCompleteQuestCheck, 'all')
    card6:AddRow(row6c, Theme.rowHeight)

    local separator = GUIFrame:CreateSeparator(card6.content)
    card6:AddRow(separator, Theme.separatorHeight)

    local row6e = GUIFrame:CreateRow(card6.content, Theme.rowHeightLast)
    local autoBonusRollQuestCheck = GUIFrame:CreateCheckbox(row6e, 'Auto Bonus Roll Quest ' .. overrideTag, {
        value = db.AutoBonusRollQuest,
        tooltip = 'Automatically accept and complete the weekly |cffffffffBonus Roll|r quest from Decimus.',
        callback = function(checked)
            db.AutoBonusRollQuest = checked
            Automation:ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row6e:AddWidget(autoBonusRollQuestCheck, 0.5)
    manager:Register(autoBonusRollQuestCheck, 'all')

    local autoBonusRollModeDropdown = GUIFrame:CreateDropdown(row6e, 'Auto Bonus Roll Mode', {
        value = db.AutoBonusRollMode,
        options = {
            { text = 'Gold',  value = 'Gold' },
            { text = 'Marl',  value = 'Marl' },
            { text = 'Crest', value = 'Crest' },
        },
        callback = function(value)
            db.AutoBonusRollMode = value
            Automation:ApplySettings()
        end
    })
    manager:Register(autoBonusRollModeDropdown, 'all', 'bonusRollQuest')
    row6e:AddWidget(autoBonusRollModeDropdown, 0.5)
    card6:AddRow(row6e, Theme.rowHeightLast, 0)

    yOffset = card6:GetNextOffset()

    UpdateAllWidgetStates()

    return yOffset
end)

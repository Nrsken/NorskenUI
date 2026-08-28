---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AutomationModule
local Automation = NRSKNUI:GetModule('Automation')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local overrideTag = '|cffffffff' .. '*' .. '|r'

local function ApplySettings()
    Automation:ApplySettings()
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    local enableCard = page:Card(L['Automation'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Automation'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Automation'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('Automation', checked)
            page:Refresh()
        end,
    })

    local overrideCard = page:Card(L['Override Key'], 'all')
    local overrideRow = overrideCard:Row(rowHL, 0)
    overrideRow:Dropdown(L['Override Key'], {
        width = 0.5,
        value = db.OverrideKey,
        options = {
            { text = L['Shift'], value = 'Shift' },
            { text = L['Alt'],   value = 'Alt' },
            { text = L['Ctrl'],  value = 'Ctrl' },
            { text = L['Cmd'],   value = 'Cmd' },
        },
        callback = function(key)
            db.OverrideKey = key
            ApplySettings()
        end
    })

    overrideRow:Dropdown(L['Override Behaviour'], {
        width = 0.5,
        value = db.OverrideMode,
        options = {
            { text = L['Hold to Skip'],   value = 'Block' },
            { text = L['Hold to Enable'], value = 'Require' },
        },
        callback = function(value)
            db.OverrideMode = value
            ApplySettings()
        end
    })

    overrideCard:Separator()

    local textRowSize = 32
    local infoRow = overrideCard:Row(textRowSize)
    infoRow:Text(NRSKNUI:ColorTextByTheme(L['Override Info']), {
        width = 1,
        height = textRowSize,
        autoHeight = true,
        bgMode = 'hide',
        text = NRSKNUI:ColorTextByTheme('• ') ..
            L['Automation features that has override support are marked with '] .. overrideTag,
    })
end

-- Cinematics & Dialogs Settings Tab.
local function BuildCinematicsSettingsTab(page, db)
    local cinematicsCard = page:Card(L['Cinematics & Dialogs'], 'all')
    local cinematicsRow = cinematicsCard:Row(rowH)
    cinematicsRow:Checkbox(L['Auto Skip Cinematics & Movies'], {
        width = 1,
        value = db.SkipCinematics,
        callback = function(checked)
            db.SkipCinematics = checked
            ApplySettings()
        end
    })

    local dialogsRow = cinematicsCard:Row(rowH)
    dialogsRow:Checkbox(L['Auto Hide Spammy Tutorial Helptips'], {
        width = 1,
        value = db.HideHelptips,
        callback = function(checked)
            db.HideHelptips = checked
            ApplySettings()
        end
    })
end

-- Merchant Settings Tab.
local function BuildMerchantSettingsTab(page, db)
    local merchantCard = page:Card(L['Merchant Automation'], 'all')
    local autoSellRow = merchantCard:Row(rowH)
    autoSellRow:Checkbox(L['Auto Sell Junk/Grey Items '] .. overrideTag, {
        width = 1,
        value = db.AutoSellJunk,
        callback = function(checked)
            db.AutoSellJunk = checked
            ApplySettings()
        end
    })

    local atuoRepairRow = merchantCard:Row(rowH)
    atuoRepairRow:Checkbox(L['Auto Repair Gear '] .. overrideTag, {
        width = 1,
        value = db.AutoRepair,
        callback = function(checked)
            db.AutoRepair = checked
            ApplySettings()
            page:Refresh()
        end
    })

    local guildRepairRow = merchantCard:Row(rowHL, 0)
    guildRepairRow:Checkbox(L['Use Guild Funds for Repair'], {
        width = 1,
        value = db.UseGuildFunds,
        conditions = { 'autoRepair' },
        callback = function(checked)
            db.UseGuildFunds = checked
            ApplySettings()
        end
    })
end

-- Group Finder Settings Tab.
local function BuildGroupFinderSettingsTab(page, db)
    local groupFinderCard = page:Card(L['Group Finder'], 'all')
    local groupFinderRow = groupFinderCard:Row(rowHL, 0)
    groupFinderRow:Checkbox(L['Auto Accept Group Finder Role Check'] .. overrideTag, {
        width = 1,
        value = db.AutoRoleCheck,
        tooltip = L['Role based on selected roles in the Group Finder.'],
        callback = function(checked)
            db.AutoRoleCheck = checked
            ApplySettings()
        end
    })
end

-- Convenience Settings Tab.
local function BuildConvenienceSettingsTab(page, db)
    local convenienceCard = page:Card(L['Convenience'], 'all')
    local autoFillDeleteRow = convenienceCard:Row(rowH)
    autoFillDeleteRow:Checkbox(L['Auto-Fill DELETE Text'], {
        width = 1,
        value = db.AutoFillDelete,
        callback = function(checked)
            db.AutoFillDelete = checked
            ApplySettings()
        end
    })

    local autoLootRow = convenienceCard:Row(rowH)
    autoLootRow:Checkbox(L['Auto Loot'], {
        width = 0.5,
        value = db.AutoLoot,
        callback = function(checked)
            db.AutoLoot = checked
            ApplySettings()
            page:Refresh()
        end
    })

    autoLootRow:Checkbox(L['Fast Loot'], {
        width = 0.5,
        value = db.FastLoot,
        conditions = { 'autoLoot' },
        callback = function(checked)
            db.FastLoot = checked
            ApplySettings()
        end
    })
end

-- Quests Settings Tab.
local function BuildQuestsSettingsTab(page, db)
    local questsCard = page:Card(L['Quests'], 'all')

    local regularQuestRow = questsCard:Row(rowH)
    regularQuestRow:Checkbox(L['Auto Accept Regular Quests ' .. overrideTag], {
        width = 1,
        value = db.AutoAcceptRegular,
        callback = function(checked)
            db.AutoAcceptRegular = checked
            ApplySettings()
        end
    })

    local eventQuestRow = questsCard:Row(rowH)
    eventQuestRow:Checkbox(L['Auto Accept Event Quests ' .. overrideTag], {
        width = 1,
        value = db.AutoAcceptEvent,
        callback = function(checked)
            db.AutoAcceptEvent = checked
            ApplySettings()
        end
    })

    local dailyQuestRow = questsCard:Row(rowH)
    dailyQuestRow:Checkbox(L['Auto Accept Daily Quests ' .. overrideTag], {
        width = 1,
        value = db.AutoAcceptDaily,
        callback = function(checked)
            db.AutoAcceptDaily = checked
            ApplySettings()
        end
    })

    local weeklyQuestRow = questsCard:Row(rowH)
    weeklyQuestRow:Checkbox(L['Auto Accept Weekly Quests ' .. overrideTag], {
        width = 1,
        value = db.AutoAcceptWeekly,
        callback = function(checked)
            db.AutoAcceptWeekly = checked
            ApplySettings()
        end
    })

    questsCard:Separator()

    local autoCompleteQuestRow = questsCard:Row(rowH)
    autoCompleteQuestRow:Checkbox(L['Auto Complete Quests ' .. overrideTag], {
        width = 1,
        value = db.AutoCompleteQuest,
        tooltip = L['Automatically complete and turn in quests when there is no reward choice.'],
        callback = function(checked)
            db.AutoCompleteQuest = checked
            ApplySettings()
        end
    })

    questsCard:Separator()

    local autoBonusRollQuestRow = questsCard:Row(rowH)
    autoBonusRollQuestRow:Checkbox(L['Auto Bonus Roll Quest ' .. overrideTag], {
        width = 0.5,
        value = db.AutoBonusRollQuest,
        tooltip = L['Automatically accept and complete the weekly |cffffffffBonus Roll|r quest from Decimus.'],
        callback = function(checked)
            db.AutoBonusRollQuest = checked
            ApplySettings()
            page:Refresh()
        end
    })

    autoBonusRollQuestRow:Dropdown(L['Auto Bonus Roll Mode'], {
        width = 0.5,
        value = db.AutoBonusRollMode,
        options = {
            { text = L['Gold'],  value = 'Gold' },
            { text = L['Marl'],  value = 'Marl' },
            { text = L['Crest'], value = 'Crest' },
        },
        conditions = { 'bonusRollQuest' },
        callback = function(value)
            db.AutoBonusRollMode = value
            ApplySettings()
        end
    })
end

GUI:RegisterPage('automation', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',     text = L['General Settings'] },
        { id = 'cinematics',  text = L['Cinematics & Dialogs'] },
        { id = 'merchant',    text = L['Merchant'] },
        { id = 'groupFinder', text = L['Group Finder'] },
        { id = 'convenience', text = L['Convenience'] },
        { id = 'quests',      text = L['Quests'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.Miscellaneous.Automation
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)
        page:SetCondition('bonusRollQuest', function() return db.AutoBonusRollQuest end)
        page:SetCondition('autoRepair', function() return db.AutoRepair end)
        page:SetCondition('autoLoot', function() return db.AutoLoot end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'cinematics' then
            BuildCinematicsSettingsTab(page, db)
        elseif tabId == 'merchant' then
            BuildMerchantSettingsTab(page, db)
        elseif tabId == 'groupFinder' then
            BuildGroupFinderSettingsTab(page, db)
        elseif tabId == 'convenience' then
            BuildConvenienceSettingsTab(page, db)
        elseif tabId == 'quests' then
            BuildQuestsSettingsTab(page, db)
        end
    end,
})

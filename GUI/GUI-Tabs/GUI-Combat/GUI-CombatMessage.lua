---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CombatMessage
local CombatMessage = NRSKNUI:GetModule('CombatMessage')
local L = NRSKNUI.Libs.AL
local LSM = NRSKNUI.Libs.LSM
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs = ipairs

local function ApplySettings()
    CombatMessage:ApplySettings()
end

-- Dropdown Options --

local roleSounds = {
    { label = L['Tank Sound'],   dbKey = 'SoundTank',    last = false },
    { label = L['Healer Sound'], dbKey = 'SoundHealer',  last = false },
    { label = L['DPS Sound'],    dbKey = 'SoundDamager', last = true },
}

local fontSizes = {
    { label = L['Enter Combat'],      dbKey = 'EnterCombat.FontSize' },
    { label = L['Exit Combat'],       dbKey = 'ExitCombat.FontSize' },
    { label = L['No Target'],         dbKey = 'NoTarget.FontSize' },
    { label = L['Group Member Died'], dbKey = 'PartyDeath.FontSize' },
}

local visibilityOptions = {
    { key = 'ALWAYS',   text = L['Always'] },
    { key = 'ANYGROUP', text = L['Any Group'] },
    { key = 'PARTY',    text = L['In Party'] },
    { key = 'RAID',     text = L['In Raid'] },
}

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    page:SetCondition('enter', function() return db.EnterCombat.Enabled end)
    page:SetCondition('exit', function() return db.ExitCombat.Enabled end)
    page:SetCondition('noTarget', function() return db.NoTarget.Enabled end)
    page:SetCondition('partyDeath', function() return db.PartyDeath.Enabled end)

    -- Card 1: Enable
    local enableCard = page:Card(L['Combat Message'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Combat Message'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Combat Message'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('CombatMessage', checked)
            page:Refresh()
        end,
    })

    -- Card 2: General Settings
    local generalCard = page:Card(L['General Settings'], 'all')
    local durationRow = generalCard:Row(rowHL, 0)
    durationRow:Slider(L['Message Duration'], {
        width = 1,
        min = 1,
        max = 10,
        step = 0.5,
        value = db.Duration,
        callback = function(val)
            db.Duration = val
            ApplySettings()
        end
    })

    -- Card 3: Message Types
    local typesCard = page:Card(L['Message Types'], 'all')

    -- Enter Combat Message
    local enterCombatRow = typesCard:Row(rowH)
    enterCombatRow:Checkbox(L['Enter Combat'], {
        width = 0.25,
        value = db.EnterCombat.Enabled,
        callback = function(checked)
            db.EnterCombat.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    enterCombatRow:ColorPicker(L['Enter Combat Color'], {
        width = 0.25,
        value = db.EnterCombat.Color,
        conditions = { 'enter' },
        callback = function(r, g, b, a)
            db.EnterCombat.Color = { r, g, b, a }
            ApplySettings()
        end,
    })

    enterCombatRow:EditBox(L['Enter Combat Message'], {
        width = 0.5,
        value = db.EnterCombat.Text,
        conditions = { 'enter' },
        callback = function(text)
            db.EnterCombat.Text = text
            ApplySettings()
        end,
    })

    typesCard:Separator()

    -- Exit Combat Message
    local exitCombatRow = typesCard:Row(rowH)
    exitCombatRow:Checkbox(L['Exit Combat'], {
        width = 0.25,
        value = db.ExitCombat.Enabled,

        callback = function(checked)
            db.ExitCombat.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    exitCombatRow:ColorPicker(L['Exit Combat Color'], {
        width = 0.25,
        value = db.ExitCombat.Color,
        conditions = { 'exit' },
        callback = function(r, g, b, a)
            db.ExitCombat.Color = { r, g, b, a }
            ApplySettings()
        end,
    })

    exitCombatRow:EditBox(L['Exit Combat Message'], {
        width = 0.5,
        value = db.ExitCombat.Text,
        conditions = { 'exit' },
        callback = function(text)
            db.ExitCombat.Text = text
            ApplySettings()
        end,
    })

    typesCard:Separator()

    -- No Target Message
    local noTargetRow = typesCard:Row(rowH)
    noTargetRow:Checkbox(L['No Target'], {
        width = 0.25,
        value = db.NoTarget.Enabled,
        callback = function(checked)
            db.NoTarget.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    noTargetRow:ColorPicker(L['No Target Color'], {
        width = 0.25,
        value = db.NoTarget.Color,
        conditions = { 'noTarget' },
        callback = function(r, g, b, a)
            db.NoTarget.Color = { r, g, b, a }
            ApplySettings()
        end,
    })

    noTargetRow:EditBox(L['No Target Message'], {
        width = 0.5,
        value = db.NoTarget.Text,
        conditions = { 'noTarget' },
        callback = function(text)
            db.NoTarget.Text = text
            ApplySettings()
        end,
    })

    typesCard:Separator()

    -- Group Member Died Message
    local groupMemberDiedRow = typesCard:Row(rowH)
    groupMemberDiedRow:Checkbox(L['Group Member Died'], {
        width = 0.25,
        value = db.PartyDeath.Enabled,
        callback = function(checked)
            db.PartyDeath.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    groupMemberDiedRow:ColorPicker(L['Group Member Died Color'], {
        width = 0.25,
        value = db.PartyDeath.Color,
        conditions = { 'partyDeath' },
        callback = function(r, g, b, a)
            db.PartyDeath.Color = { r, g, b, a }
            ApplySettings()
        end,
    })

    groupMemberDiedRow:EditBox(L['Group Member Died Message'], {
        width = 0.5,
        tooltip = L['Use |cffffffff%name|r to insert the name of the player who died and |cffffffff{rt1} - {rt8}|r to insert raid target icons.'],
        conditions = { 'partyDeath' },
        value = db.PartyDeath.Text,
        callback = function(text)
            db.PartyDeath.Text = text
            ApplySettings()
        end,
    })

    local groupMemberDiedRow2 = typesCard:Row(rowH)
    groupMemberDiedRow2:Checkbox(L['Class Colored Name'], {
        width = 0.5,
        value = db.PartyDeath.UseClassColor,
        conditions = { 'partyDeath' },
        callback = function(checked)
            db.PartyDeath.UseClassColor = checked
            ApplySettings()
        end,
    })

    groupMemberDiedRow2:Dropdown(L['Load Condition'], {
        width = 0.5,
        conditions = { 'partyDeath' },
        options = visibilityOptions,
        value = db.PartyDeath.LoadCondition,
        callback = function(key)
            db.PartyDeath.LoadCondition = key
            ApplySettings()
        end
    })

    for _, role in ipairs(roleSounds) do
        local rowHeight = role.last and rowHL or rowH
        local soundRow = typesCard:Row(rowHeight)

        soundRow:Dropdown(role.label, {
            width = 0.5,
            media = 'sound',
            conditions = { 'partyDeath' },
            value = db.PartyDeath[role.dbKey] or 'None',
            searchable = true,
            callback = function(key)
                db.PartyDeath[role.dbKey] = key
            end,
        })

        soundRow:Button(L['Test'], {
            width = 0.5,
            yOffset = -14,
            height = 24,
            conditions = { 'partyDeath' },
            callback = function()
                local soundName = db.PartyDeath[role.dbKey]
                if soundName and soundName ~= 'None' and LSM then
                    NRSKNUI:PlaySafeSound(soundName)
                end
            end,
        })
    end
end

-- Font Settings Tab.
local function BuildFontSettingsTab(page, db)
    page:FontSettingsCard({ db = db, fontSizes = fontSizes, onChangeCallback = ApplySettings, globalOverride = {}, })
end

-- Layout & Position Settings Tab.
local function BuildLayoutPositionSettingsTab(page, db)
    page:DynamicGroupCard({ title = L['Layout'], db = db.Config, onChangeCallback = ApplySettings })
    page:PositionCard({ db = db, showAnchorFrameType = true, showStrata = true, onChangeCallback = ApplySettings, })
end

GUI:RegisterPage('combatMessage', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general', text = L['General Settings'] },
        { id = 'font',    text = L['Font Settings'] },
        { id = 'layout',  text = L['Layout & Position'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.CombatMessage
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'font' then
            BuildFontSettingsTab(page, db)
        elseif tabId == 'layout' then
            BuildLayoutPositionSettingsTab(page, db)
        end
    end,
})

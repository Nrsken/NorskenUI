---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CombatTimer: AceModule, AceEvent-3.0
local CombatTimer = NRSKNUI:GetModule('CombatTimer')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local pairs = pairs

local function ApplySettings()
    CombatTimer:ApplySettings()
end

-- Same time formats as CombatRes, plus a sub-second option unique to the timer.
local formatOptions = {}
for key, preview in pairs(NRSKNUI.TimeFormats) do formatOptions[key] = preview end
formatOptions['MM:SS.f'] = '01:30.5'

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    -- Card 1: Enable
    local enableCard = page:Card(L['Combat Timer'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Combat Timer'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Combat Timer'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('CombatTimer', checked)
            page:Refresh()
        end,
    })

    -- Card 2: Options
    local optionsCard = page:Card(L['Options'], 'all')
    local optionsRow = optionsCard:Row(rowH)
    optionsRow:Checkbox(L['Combat Only'], {
        width = 0.5,
        value = db.CombatOnly,
        callback = function(checked)
            db.CombatOnly = checked
            CombatTimer:Toggle(checked)
            ApplySettings()
        end,
    })
    optionsRow:Dropdown(L['Format'], {
        width = 0.5,
        options = formatOptions,
        value = db.Format,
        callback = function(key)
            db.Format = key
            ApplySettings()
        end,
    })

    local printRow = optionsCard:Row(rowHL, 0)
    printRow:Checkbox(L['Print Duration to Chat'], {
        width = 1,
        value = db.PrintEnd,
        callback = function(checked)
            db.PrintEnd = checked
        end,
    })
end

-- Color Settings Tab.
local function BuildColorSettingsTab(page, db)
    page:SetCondition('combatOnly', function() return not db.CombatOnly end)

    local colorCard = page:Card(L['Colors'], 'all')
    local colorRow = colorCard:Row(rowHL, 0)
    colorRow:ColorPicker(L['In Combat'], {
        width = 0.5,
        value = db.ColorInCombat,
        callback = function(r, g, b, a)
            db.ColorInCombat = { r, g, b, a }
            ApplySettings()
        end,
    })
    colorRow:ColorPicker(L['Out of Combat'], {
        width = 0.5,
        conditions = { 'combatOnly' },
        value = db.ColorOutOfCombat,
        callback = function(r, g, b, a)
            db.ColorOutOfCombat = { r, g, b, a }
            ApplySettings()
        end,
    })
end

-- Backdrop Settings Tab.
local function BuildBackdropSettingsTab(page, db)
    page:SetCondition('backdrop', function() return db.BackdropEnabled end)

    local backdropCard = page:Card(L['Backdrop'], 'all')
    local backdropEnableRow = backdropCard:Row(rowH)
    backdropEnableRow:Checkbox(L['Enable Backdrop'], {
        width = 1,
        value = db.BackdropEnabled,
        callback = function(checked)
            db.BackdropEnabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    backdropCard:Separator()

    local bgColorRow = backdropCard:Row(rowH)
    bgColorRow:ColorPicker(L['Background Color'], {
        width = 1,
        conditions = { 'backdrop' },
        value = db.BackgroundColor,
        callback = function(r, g, b, a)
            db.BackgroundColor = { r, g, b, a }
            ApplySettings()
        end,
    })

    local sizeRow = backdropCard:Row(rowH)
    sizeRow:Slider(L['Background Width'], {
        width = 0.5,
        min = 1,
        max = 600,
        step = 1,
        conditions = { 'backdrop' },
        value = db.BackdropWidth,
        callback = function(val)
            db.BackdropWidth = val
            ApplySettings()
        end,
    })
    sizeRow:Slider(L['Background Height'], {
        width = 0.5,
        min = 1,
        max = 600,
        step = 1,
        conditions = { 'backdrop' },
        value = db.BackdropHeight,
        callback = function(val)
            db.BackdropHeight = val
            ApplySettings()
        end,
    })

    backdropCard:Separator()

    local borderColorRow = backdropCard:Row(rowHL, 0)
    borderColorRow:ColorPicker(L['Border Color'], {
        width = 1,
        conditions = { 'backdrop' },
        value = db.BorderColor,
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }
            ApplySettings()
        end,
    })
end

-- Font Settings Tab.
local function BuildFontSettingsTab(page, db)
    page:FontSettingsCard({ db = db, includeSoftOutline = true, onChangeCallback = ApplySettings, globalOverride = {}, })
end

-- Position Settings Tab.
local function BuildPositionSettingsTab(page, db)
    page:PositionCard({ db = db, showAnchorFrameType = true, showStrata = true, onChangeCallback = ApplySettings, })
end

GUI:RegisterPage('combatTimer', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',  text = L['General Settings'] },
        { id = 'color',    text = L['Color Settings'] },
        { id = 'backdrop', text = L['Backdrop Settings'] },
        { id = 'font',     text = L['Font Settings'] },
        { id = 'position', text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.CombatTimer
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'color' then
            BuildColorSettingsTab(page, db)
        elseif tabId == 'backdrop' then
            BuildBackdropSettingsTab(page, db)
        elseif tabId == 'font' then
            BuildFontSettingsTab(page, db)
        elseif tabId == 'position' then
            BuildPositionSettingsTab(page, db)
        end
    end,
})

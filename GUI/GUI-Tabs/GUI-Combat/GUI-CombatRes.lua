---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CombatRes
local CombatRes = NRSKNUI:GetModule('CombatRes', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings()
    CombatRes:ApplySettings()
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    -- Card 1: Enable
    local enableCard = page:Card(L['Combat Res Tracker'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Combat Res Tracker'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Combat Res Tracker'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('CombatRes', checked)
            page:Refresh()
        end,
    })

    -- Card 2: Text Format
    local textFormatCard = page:Card(L['Text Format'], 'all')
    local formatInputRow = textFormatCard:Row(rowH)
    formatInputRow:EditBox(L['Format'], {
        width = 1,
        value = db.TextFormat,
        callback = function(val)
            db.TextFormat = val
            ApplySettings()
        end
    })

    local tokenHeight = 70
    local tokenLegendRow = textFormatCard:Row(tokenHeight)
    tokenLegendRow:Text(NRSKNUI:ColorTextByTheme(L['Available Tokens']), {
        width = 1,
        text = {
            db.TextCharge .. '  —  ' .. L['Battle res charges'],
            db.TextSeparator .. '  —  ' .. L['Separator (chosen below)'],
            db.TextTimer .. '  —  ' .. L['Cooldown timer'],
        },
        bgMode = 'hide',
        height = tokenHeight,
    })

    local separatorTypeRow = textFormatCard:Row(rowHL, 0)
    separatorTypeRow:Dropdown(L['Separator Type'], {
        width = 0.5,
        options = NRSKNUI.Separators,
        value = db.Separator,
        callback = function(key)
            db.Separator = key
            ApplySettings()
        end
    })

    separatorTypeRow:Dropdown(L['Timer Format'], {
        width = 0.5,
        options = NRSKNUI.TimeFormats,
        value = db.TimeFormat,
        callback = function(key)
            db.TimeFormat = key
            ApplySettings()
        end
    })
end

-- Color Settings Tab.
local function BuildColorSettingsTab(page, db)
    local colorCard = page:Card(L['Colors'], 'all')
    local chargeAvailRow = colorCard:Row(rowH)
    chargeAvailRow:ColorPicker(L['Charges Available'], {
        width = 0.5,
        value = db.ColorChargeAvailable,
        callback = function(r, g, b, a)
            db.ColorChargeAvailable = { r, g, b, a }
            ApplySettings()
        end
    })

    chargeAvailRow:ColorPicker(L['Charges Unavailable'], {
        width = 0.5,
        value = db.ColorChargeUnavailable,
        callback = function(r, g, b, a)
            db.ColorChargeUnavailable = { r, g, b, a }
            ApplySettings()
        end
    })

    local timerColorRow = colorCard:Row(rowH)
    timerColorRow:ColorPicker(L['Timer'], {
        width = 0.5,
        value = db.ColorTimer,
        callback = function(r, g, b, a)
            db.ColorTimer = { r, g, b, a }
            ApplySettings()
        end
    })

    timerColorRow:ColorPicker(L['Separator'], {
        width = 0.5,
        value = db.ColorSeparator,
        callback = function(r, g, b, a)
            db.ColorSeparator = { r, g, b, a }
            ApplySettings()
        end
    })

    local formatColorRow = colorCard:Row(rowHL, 0)
    formatColorRow:ColorPicker(L['Format Text'], {
        width = 1,
        value = db.ColorFormat,
        callback = function(r, g, b, a)
            db.ColorFormat = { r, g, b, a }
            ApplySettings()
        end
    })
end

-- Backdrop Settings Tab.
local function BuildBackdropSettingsTab(page, db)
    local backdropCard = page:Card(L['Backdrop'], 'all')
    local enableBackdropRow = backdropCard:Row(rowH)
    enableBackdropRow:Checkbox(L['Enable Backdrop'], {
        width = 1,
        value = db.BackdropEnabled,
        callback = function(checked)
            db.BackdropEnabled = checked
            ApplySettings()
            page:Refresh()
        end
    })

    backdropCard:Separator()

    local backdropColorRow = backdropCard:Row(rowH)
    backdropColorRow:ColorPicker(L['Background Color'], {
        width = 0.5,
        value = db.BackgroundColor,
        conditions = { 'backdrop' },
        callback = function(r, g, b, a)
            db.BackgroundColor = { r, g, b, a }
            ApplySettings()
        end
    })

    backdropColorRow:ColorPicker(L['Border Color'], {
        width = 0.5,
        value = db.BorderColor,
        conditions = { 'backdrop' },
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }
            ApplySettings()
        end
    })

    local offsetRow = backdropCard:Row(rowHL, 0)
    offsetRow:Slider(L['Padding X'], {
        width = 0.5,
        min = 0,
        max = 40,
        step = 1,
        value = db.BackdropWidth,
        conditions = { 'backdrop' },
        callback = function(val)
            db.BackdropWidth = val
            ApplySettings()
        end
    })

    offsetRow:Slider(L['Padding Y'], {
        width = 0.5,
        min = 0,
        max = 40,
        step = 1,
        value = db.BackdropHeight,
        conditions = { 'backdrop' },
        callback = function(val)
            db.BackdropHeight = val
            ApplySettings()
        end
    })
end

-- Font Settings Tab.
local function BuildFontSettingsTab(page, db)
    page:FontSettingsCard({ db = db, onChangeCallback = ApplySettings, globalOverride = {}, })
end

-- Position Settings Tab.
local function BuildPositionSettingsTab(page, db)
    page:PositionCard({ db = db, showAnchorFrameType = true, showStrata = true, onChangeCallback = ApplySettings, })
end

GUI:RegisterPage('combatRes', {
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
        local db = NRSKNUI.db.profile.BattleRes
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

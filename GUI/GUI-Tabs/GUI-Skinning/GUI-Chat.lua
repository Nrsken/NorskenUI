---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class Chatv2Module
local CHAT = NRSKNUI:GetModule('Chatv2')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ReloadUI = ReloadUI

local timestampFormats = {
    { key = 'NONE',           text = L['None'] },
    { key = '[%H:%M] ',       text = '[HH:MM]' },
    { key = '[%H:%M:%S] ',    text = '[HH:MM:SS]' },
    { key = '[%I:%M %p] ',    text = '[HH:MM AM/PM]' },
    { key = '[%I:%M:%S %p] ', text = '[HH:MM:SS AM/PM]' },
    { key = '%H:%M ',         text = 'HH:MM' },
    { key = '%H:%M:%S ',      text = 'HH:MM:SS' },
    { key = '%I:%M %p ',      text = 'HH:MM AM/PM' },
    { key = '%I:%M:%S %p ',   text = 'HH:MM:SS AM/PM' },
}

local tabSelectorStyles = {
    { key = 'NONE',   text = L['None'] },
    { key = 'ARROW',  text = '>Text<' },
    { key = 'ARROW1', text = '> Text <' },
    { key = 'ARROW2', text = '<Text>' },
    { key = 'ARROW3', text = '< Text >' },
    { key = 'BOX',    text = '[Text]' },
    { key = 'BOX1',   text = '[ Text ]' },
    { key = 'CURLY',  text = '{Text}' },
    { key = 'CURLY1', text = '{ Text }' },
    { key = 'CURVE',  text = '(Text)' },
    { key = 'CURVE1', text = '( Text )' },
}

local editBoxPositions = {
    { key = 'BELOW_CHAT',        text = L['Below Chat'] },
    { key = 'BELOW_CHAT_INSIDE', text = L['Below Chat (Inside)'] },
    { key = 'ABOVE_CHAT',        text = L['Above Chat'] },
    { key = 'ABOVE_CHAT_INSIDE', text = L['Above Chat (Inside)'] },
}

local function ApplySettings()
    if CHAT then CHAT:ApplySettings() end
end

-- The module stores these as { r = , g = , b = } but the color picker works on arrays.
local function ToArray(color, r, g, b)
    if not color then return { r, g, b, 1 } end
    return { color.r or r, color.g or g, color.b or b, 1 }
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    page:SetCondition('backdrop', function() return db.Backdrop.Enabled end)

    -- Card 1: Enable
    local enableCard = page:Card(L['Chat'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Custom Chat Panel'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Chat'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('Chatv2', checked)
            if not checked then
                NRSKNUI:CreatePrompt({
                    title = L['Chat Module Disabled'],
                    text = L['The chat module has been disabled.'] .. '\n\n' ..
                        L['A UI reload is recommended to fully restore the default chat.'],
                    onAccept = function() ReloadUI() end,
                    acceptText = L['Reload Now'],
                    cancelText = L['Later'],
                })
            end
            page:Refresh()
        end,
    })

    -- Card 2: Panel Size
    local sizeCard = page:Card(L['Panel Size'], 'all')
    local sizeRow = sizeCard:Row(rowHL, 0)
    sizeRow:Slider(L['Width'], {
        width = 0.5,
        min = 200,
        max = 800,
        step = 1,
        value = db.Width,
        callback = function(val)
            db.Width = val; ApplySettings()
        end,
    })
    sizeRow:Slider(L['Height'], {
        width = 0.5,
        min = 100,
        max = 600,
        step = 1,
        value = db.Height,
        callback = function(val)
            db.Height = val; ApplySettings()
        end,
    })

    -- Card 3: Backdrop
    local backdropCard = page:Card(L['Backdrop'], 'all')
    local toggleRow = backdropCard:Row(rowH)
    toggleRow:Checkbox(L['Enable Backdrop'], {
        width = 1,
        value = db.Backdrop.Enabled,
        callback = function(checked)
            db.Backdrop.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    backdropCard:Separator()

    local panelColorRow = backdropCard:Row(rowH)
    panelColorRow:ColorPicker(L['Background'], {
        width = 0.5,
        conditions = { 'backdrop' },
        value = db.Backdrop.Color,
        callback = function(r, g, b, a)
            db.Backdrop.Color = { r, g, b, a }; ApplySettings()
        end,
    })
    panelColorRow:ColorPicker(L['Border'], {
        width = 0.5,
        conditions = { 'backdrop' },
        value = db.Backdrop.BorderColor,
        callback = function(r, g, b, a)
            db.Backdrop.BorderColor = { r, g, b, a }; ApplySettings()
        end,
    })

    local editBoxColorRow = backdropCard:Row(rowHL, 0)
    editBoxColorRow:ColorPicker(L['Editbox Background'], {
        width = 0.5,
        value = db.EditBox.BackdropColor,
        callback = function(r, g, b, a)
            db.EditBox.BackdropColor = { r, g, b, a }; ApplySettings()
        end,
    })
    editBoxColorRow:ColorPicker(L['Editbox Border'], {
        width = 0.5,
        value = db.EditBox.BorderColor,
        callback = function(r, g, b, a)
            db.EditBox.BorderColor = { r, g, b, a }; ApplySettings()
        end,
    })

    -- Card 4: Editbox & History
    local historyCard = page:Card(L['Editbox & History'], 'all')
    local positionRow = historyCard:Row(rowH)
    positionRow:Dropdown(L['Editbox Position'], {
        width = 1,
        options = editBoxPositions,
        value = db.EditBoxPosition,
        callback = function(key)
            db.EditBoxPosition = key; ApplySettings()
        end,
    })

    historyCard:Separator()

    local historyRow = historyCard:Row(rowHL, 0)
    historyRow:Slider(L['Max Lines'], {
        width = 0.5,
        min = 10,
        max = 5000,
        step = 10,
        value = db.MaxLines,
        callback = function(val)
            db.MaxLines = val; ApplySettings()
        end,
    })
    historyRow:Slider(L['Scroll Step'], {
        width = 0.5,
        min = 1,
        max = 10,
        step = 1,
        value = db.NumScrollMessages,
        tooltip = L['Number of messages scrolled per mouse wheel tick.'],
        callback = function(val) db.NumScrollMessages = val end,
    })
end

-- Text Settings Tab.
local function BuildTextSettingsTab(page, db)
    page:SetCondition('fade', function() return db.FadeEnabled end)
    page:SetCondition('timestampColor', function() return db.TimestampColorEnabled end)

    -- Card 1: Channels
    local channelCard = page:Card(L['Channel Settings'], 'all')
    local channelRow = channelCard:Row(rowHL, 0)
    channelRow:Checkbox(L['Short Channel Names'], {
        width = 1,
        value = db.ShortChannels,
        callback = function(checked)
            db.ShortChannels = checked; ApplySettings()
        end,
    })

    -- Card 2: Fading
    local fadeCard = page:Card(L['Text Fading'], 'all')
    local fadeToggleRow = fadeCard:Row(rowH)
    fadeToggleRow:Checkbox(L['Fade Chat Text'], {
        width = 1,
        value = db.FadeEnabled,
        callback = function(checked)
            db.FadeEnabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    fadeCard:Separator()

    local fadeRow = fadeCard:Row(rowHL, 0)
    fadeRow:Slider(L['Fade Time (seconds)'], {
        width = 1,
        conditions = { 'fade' },
        min = 5,
        max = 100,
        step = 1,
        value = db.FadeTime,
        callback = function(val)
            db.FadeTime = val; ApplySettings()
        end,
    })

    -- Card 3: Timestamps
    local timestampCard = page:Card(L['Timestamps'], 'all')
    local formatRow = timestampCard:Row(rowH)
    formatRow:Dropdown(L['Timestamp Format'], {
        width = 0.5,
        options = timestampFormats,
        value = db.TimestampFormat,
        callback = function(key)
            db.TimestampFormat = key; ApplySettings()
        end,
    })
    formatRow:Checkbox(L['Use Local Time'], {
        width = 0.5,
        value = db.UseLocalTime,
        callback = function(checked)
            db.UseLocalTime = checked; ApplySettings()
        end,
    })

    timestampCard:Separator()

    local colorRow = timestampCard:Row(rowHL, 0)
    colorRow:Checkbox(L['Custom Timestamp Color'], {
        width = 0.5,
        value = db.TimestampColorEnabled,
        callback = function(checked)
            db.TimestampColorEnabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    colorRow:ColorPicker(L['Color'], {
        width = 0.5,
        conditions = { 'timestampColor' },
        value = ToArray(db.TimestampColor, 0.6, 0.6, 0.6),
        callback = function(r, g, b)
            db.TimestampColor = { r = r, g = g, b = b }; ApplySettings()
        end,
    })

    -- Card 4: Font
    page:FontSettingsCard({
        db = db,
        includeSoftOutline = true,
        globalOverride = {},
        fontSizeRange = { 8, 24 },
        fontSizes = { { label = L['Tab Font Size'], dbKey = 'TabFontSize' }, },
        onChangeCallback = ApplySettings,
    })
end

-- Tab Settings Tab.
local function BuildTabSettingsTab(page, db)
    page:SetCondition('selectedColor', function() return db.TabSelectedTextEnabled end)
    page:SetCondition('inactiveColor', function() return (db.TabTextColorMode or 'custom') == 'custom' end)
    page:SetCondition('selector', function() return db.TabSelector ~= 'NONE' end)
    page:SetCondition('tabBackdrop', function() return db.TabBackdrop.Enabled end)

    -- Card 1: Text Colors
    local colorCard = page:Card(L['Tab Text Colors'], 'all')
    local selectedRow = colorCard:Row(rowH)
    selectedRow:Checkbox(L['Custom Selected Tab Color'], {
        width = 0.5,
        value = db.TabSelectedTextEnabled,
        callback = function(checked)
            db.TabSelectedTextEnabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    selectedRow:ColorPicker(L['Color'], {
        width = 0.5,
        conditions = { 'selectedColor' },
        value = ToArray(db.TabSelectedTextColor, 1, 1, 1),
        callback = function(r, g, b)
            db.TabSelectedTextColor = { r = r, g = g, b = b }; ApplySettings()
        end,
    })

    colorCard:Separator()

    local inactiveRow = colorCard:Row(rowHL, 0)
    inactiveRow:Dropdown(L['Inactive Tab Color Mode'], {
        width = 0.5,
        options = NRSKNUI.ColorModeOptions,
        value = db.TabTextColorMode,
        callback = function(key)
            db.TabTextColorMode = key
            ApplySettings()
            page:Refresh()
        end,
    })
    inactiveRow:ColorPicker(L['Custom Color'], {
        width = 0.5,
        conditions = { 'inactiveColor' },
        value = ToArray(db.TabTextColor, 1, 0.82, 0),
        callback = function(r, g, b)
            db.TabTextColor = { r = r, g = g, b = b }; ApplySettings()
        end,
    })

    -- Card 2: Selector
    local selectorCard = page:Card(L['Tab Selector'], 'all')
    local styleRow = selectorCard:Row(rowH)
    styleRow:Dropdown(L['Selector Style'], {
        width = 1,
        options = tabSelectorStyles,
        value = db.TabSelector,
        callback = function(key)
            db.TabSelector = key
            ApplySettings()
            page:Refresh()
        end,
    })

    selectorCard:Separator()

    local selectorColorRow = selectorCard:Row(rowHL, 0)
    selectorColorRow:ColorPicker(L['Selector Color'], {
        width = 1,
        conditions = { 'selector' },
        value = ToArray(db.TabSelectorColor, 0.3, 1, 0.3),
        callback = function(r, g, b)
            db.TabSelectorColor = { r = r, g = g, b = b }; ApplySettings()
        end,
    })

    -- Card 3: Tab Backdrop
    local backdropCard = page:Card(L['Tab Backdrop'], 'all')
    local toggleRow = backdropCard:Row(rowH)
    toggleRow:Checkbox(L['Enable Tab Backdrop'], {
        width = 1,
        value = db.TabBackdrop.Enabled,
        callback = function(checked)
            db.TabBackdrop.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    backdropCard:Separator()

    local backdropColorRow = backdropCard:Row(rowHL, 0)
    backdropColorRow:ColorPicker(L['Background'], {
        width = 0.5,
        conditions = { 'tabBackdrop' },
        value = db.TabBackdrop.Color,
        callback = function(r, g, b, a)
            db.TabBackdrop.Color = { r, g, b, a }; ApplySettings()
        end,
    })
    backdropColorRow:ColorPicker(L['Border'], {
        width = 0.5,
        conditions = { 'tabBackdrop' },
        value = db.TabBackdrop.BorderColor,
        callback = function(r, g, b, a)
            db.TabBackdrop.BorderColor = { r, g, b, a }; ApplySettings()
        end,
    })
end

-- Position Settings Tab.
local function BuildPositionSettingsTab(page, db)
    page:PositionCard({ db = db, showAnchorFrameType = true, onChangeCallback = ApplySettings, })
end

GUI:RegisterPage('chat', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',  text = L['General Settings'] },
        { id = 'text',     text = L['Text Settings'] },
        { id = 'tabs',     text = L['Tab Settings'] },
        { id = 'position', text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.Chatv2
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'text' then
            BuildTextSettingsTab(page, db)
        elseif tabId == 'tabs' then
            BuildTabSettingsTab(page, db)
        elseif tabId == 'position' then
            BuildPositionSettingsTab(page, db)
        end
    end,
})

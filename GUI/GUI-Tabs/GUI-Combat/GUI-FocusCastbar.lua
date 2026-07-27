---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@type FocusCastbar?
local FocusCastbar = NRSKNUI:GetModule('FocusCastbar', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local anchorOptions = {
    { key = 'LEFT',   text = L['Left'] },
    { key = 'CENTER', text = L['Center'] },
    { key = 'RIGHT',  text = L['Right'] },
}

local function ApplySettings()
    if FocusCastbar then FocusCastbar:ApplySettings() end
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    page:SetCondition('customBar', function() return not db.UseGlobalBar end)

    -- Card 1: Enable
    local enableCard = page:Card(L['Focus Castbar'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Focus Castbar'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Focus Castbar'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('FocusCastbar', checked)
            page:Refresh()
        end,
    })

    -- Card 2: Bar Appearance
    local barCard = page:Card(L['Bar Appearance'], 'all')
    local sizeRow = barCard:Row(rowH)
    sizeRow:Slider(L['Width'], {
        width = 0.5,
        min = 100,
        max = 1000,
        step = 1,
        value = db.Width,
        callback = function(val)
            db.Width = val; ApplySettings()
        end,
    })
    sizeRow:Slider(L['Height'], {
        width = 0.5,
        min = 5,
        max = 500,
        step = 1,
        value = db.Height,
        callback = function(val)
            db.Height = val; ApplySettings()
        end,
    })

    local textureRow = barCard:Row(rowH)
    textureRow:Checkbox(L['Use Global Bar'], {
        width = 0.5,
        value = db.UseGlobalBar ~= false,
        callback = function(checked)
            db.UseGlobalBar = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    textureRow:Dropdown(L['Bar Texture'], {
        width = 0.5,
        media = 'statusbar',
        searchable = true,
        conditions = { 'customBar' },
        value = db.StatusBarTexture,
        callback = function(key)
            db.StatusBarTexture = key; ApplySettings()
        end,
    })

    local barColorRow = barCard:Row(rowHL, 0)
    barColorRow:ColorPicker(L['Background'], {
        width = 0.5,
        value = db.BackdropColor,
        callback = function(r, g, b, a)
            db.BackdropColor = { r, g, b, a }; ApplySettings()
        end,
    })
    barColorRow:ColorPicker(L['Border'], {
        width = 0.5,
        value = db.BorderColor,
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }; ApplySettings()
        end,
    })

    page:SparkSettingsCard({
        title = L['Spark'],
        db = db,
        onChangeCallback = ApplySettings,
        globalOverride = { label = L['Use Global Spark'] },
        labels = { texture = L['Spark Texture'], scale = L['Spark Scale'], width = L['Spark Width'], color = L['Spark Color'] },
        scaleTooltip = L['Scales the spark against the bar height. Art sparks keep their own proportions.'],
    })
end

-- Colors & Indicators Tab.
local function BuildColorSettingsTab(page, db)
    page:SetCondition('uninterruptible', function() return not db.HideNotInterruptible end)
    page:SetCondition('kickIndicator', function() return db.KickIndicator.Enabled end)
    page:SetCondition('holdTimer', function() return db.HoldTimer.Enabled end)

    local colorsCard = page:Card(L['Colors & Indicators'], 'all')
    local baseColorRow = colorsCard:Row(rowH)
    baseColorRow:ColorPicker(L['Text'], {
        width = 0.5,
        value = db.TextColor,
        callback = function(r, g, b, a)
            db.TextColor = { r, g, b, a }; ApplySettings()
        end,
    })
    baseColorRow:ColorPicker(L['Interruptible / Kick Ready'], {
        width = 0.5,
        value = db.CastColor,
        callback = function(r, g, b, a)
            db.CastColor = { r, g, b, a }; ApplySettings()
        end,
    })

    colorsCard:Separator()

    local uninterruptRow = colorsCard:Row(rowH)
    uninterruptRow:Checkbox(L['Hide Uninterruptible Casts'], {
        width = 0.5,
        value = db.HideNotInterruptible,
        callback = function(checked)
            db.HideNotInterruptible = checked
            page:Refresh()
        end,
    })
    uninterruptRow:ColorPicker(L['Uninterruptible'], {
        width = 0.5,
        conditions = { 'uninterruptible' },
        value = db.NotInterruptibleColor,
        callback = function(r, g, b, a)
            db.NotInterruptibleColor = { r, g, b, a }; ApplySettings()
        end,
    })

    colorsCard:Separator()

    local kickRow = colorsCard:Row(rowH)
    kickRow:Checkbox(L['Kick Indicator'], {
        width = 0.5,
        value = db.KickIndicator.Enabled,
        callback = function(checked)
            db.KickIndicator.Enabled = checked
            page:Refresh()
        end,
    })
    kickRow:ColorPicker(L['Not Ready'], {
        width = 0.5,
        conditions = { 'kickIndicator' },
        value = db.KickIndicator.NotReadyColor,
        callback = function(r, g, b, a)
            db.KickIndicator.NotReadyColor = { r, g, b, a }; ApplySettings()
        end,
    })

    local kickRow2 = colorsCard:Row(rowH)
    kickRow2:Slider(L['Tick Width'], {
        width = 0.5,
        conditions = { 'kickIndicator' },
        min = 0,
        max = 16,
        step = 1,
        value = db.KickIndicator.TickWidth,
        callback = function(val)
            db.KickIndicator.TickWidth = val; ApplySettings()
        end,
    })
    kickRow2:ColorPicker(L['Tick'], {
        width = 0.5,
        conditions = { 'kickIndicator' },
        value = db.KickIndicator.TickColor,
        callback = function(r, g, b, a)
            db.KickIndicator.TickColor = { r, g, b, a }; ApplySettings()
        end,
    })

    colorsCard:Separator()

    local holdRow = colorsCard:Row(rowH)
    holdRow:Checkbox(L['Hold Timer'], {
        width = 0.5,
        value = db.HoldTimer.Enabled,
        callback = function(checked)
            db.HoldTimer.Enabled = checked
            page:Refresh()
        end,
    })
    holdRow:ColorPicker(L['Interrupted'], {
        width = 0.5,
        conditions = { 'holdTimer' },
        value = db.HoldTimer.InterruptedColor,
        callback = function(r, g, b, a) db.HoldTimer.InterruptedColor = { r, g, b, a } end,
    })

    local holdRow2 = colorsCard:Row(rowHL, 0)
    holdRow2:Slider(L['Duration'], {
        width = 0.5,
        conditions = { 'holdTimer' },
        min = 0,
        max = 2,
        step = 0.1,
        value = db.HoldTimer.Duration,
        callback = function(val)
            db.HoldTimer.Duration = val; db.timeToHold = val
        end,
    })
    holdRow2:ColorPicker(L['Success'], {
        width = 0.5,
        conditions = { 'holdTimer' },
        value = db.HoldTimer.SuccessColor,
        callback = function(r, g, b, a) db.HoldTimer.SuccessColor = { r, g, b, a } end,
    })
end

-- Glow Settings Tab.
local function BuildGlowSettingsTab(page, db)
    page:GlowSettingsCard({
        title = L['Important Spell Glow'],
        db = db.ImportantGlow,
        glowTypes = { 'pixel', 'autocast' },
        onChangeCallback = function()
            if FocusCastbar then FocusCastbar:ResetGlow() end
            ApplySettings()
        end,
    })
end

-- Target Names & Marker Tab.
local function BuildNamesSettingsTab(page, db)
    -- Card 1: Target Names
    local targetCard = page:Card(L['Target Names'], 'all')
    local targetRow = targetCard:Row(rowH)
    targetRow:Dropdown(L['Anchor'], {
        width = 0.5,
        options = anchorOptions,
        value = db.TargetNames.Anchor,
        callback = function(key)
            db.TargetNames.Anchor = key; ApplySettings()
        end,
    })
    targetRow:Slider(L['X Offset'], {
        width = 0.5,
        min = -100,
        max = 100,
        step = 1,
        value = db.TargetNames.XOffset,
        callback = function(val)
            db.TargetNames.XOffset = val; ApplySettings()
        end,
    })

    local targetRow2 = targetCard:Row(rowHL, 0)
    targetRow2:Slider(L['Y Offset'], {
        width = 1,
        min = -50,
        max = 100,
        step = 1,
        value = db.TargetNames.YOffset,
        callback = function(val)
            db.TargetNames.YOffset = val; ApplySettings()
        end,
    })

    -- Card 2: Raid Marker
    local markerCard = page:Card(L['Raid Marker'], 'all')
    local markerRow = markerCard:Row(rowH)
    markerRow:Dropdown(L['Anchor'], {
        width = 0.5,
        options = anchorOptions,
        value = db.TargetMarker.Anchor,
        callback = function(key)
            db.TargetMarker.Anchor = key; ApplySettings()
        end,
    })
    markerRow:Slider(L['Size'], {
        width = 0.5,
        min = 1,
        max = 100,
        step = 1,
        value = db.TargetMarker.Size,
        callback = function(val)
            db.TargetMarker.Size = val; ApplySettings()
        end,
    })

    local markerRow2 = markerCard:Row(rowHL, 0)
    markerRow2:Slider(L['X Offset'], {
        width = 0.5,
        min = -100,
        max = 100,
        step = 1,
        value = db.TargetMarker.XOffset,
        callback = function(val)
            db.TargetMarker.XOffset = val; ApplySettings()
        end,
    })
    markerRow2:Slider(L['Y Offset'], {
        width = 0.5,
        min = -50,
        max = 100,
        step = 1,
        value = db.TargetMarker.YOffset,
        callback = function(val)
            db.TargetMarker.YOffset = val; ApplySettings()
        end,
    })
end

-- Font Settings Tab.
local function BuildFontSettingsTab(page, db)
    page:FontSettingsCard({
        db = db,
        includeSoftOutline = true,
        fontSizes = {
            { label = L['Spell Name'],  dbKey = 'FontSize' },
            { label = L['Target Name'], dbKey = 'TargetNames.FontSize' },
        },
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
end

-- Position Settings Tab.
local function BuildPositionSettingsTab(page, db)
    page:PositionCard({ db = db, showAnchorFrameType = true, showStrata = true, onChangeCallback = ApplySettings, })
end

GUI:RegisterPage('focusCastbar', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',  text = L['General Settings'] },
        { id = 'color',    text = L['Color Settings'] },
        { id = 'glow',     text = L['Glow Settings'] },
        { id = 'names',    text = L['Target Names'] },
        { id = 'font',     text = L['Font Settings'] },
        { id = 'position', text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.Miscellaneous.FocusCastbar
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'color' then
            BuildColorSettingsTab(page, db)
        elseif tabId == 'glow' then
            BuildGlowSettingsTab(page, db)
        elseif tabId == 'names' then
            BuildNamesSettingsTab(page, db)
        elseif tabId == 'font' then
            BuildFontSettingsTab(page, db)
        elseif tabId == 'position' then
            BuildPositionSettingsTab(page, db)
        end
    end,
})

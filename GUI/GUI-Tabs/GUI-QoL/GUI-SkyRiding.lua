---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkyRidingModule
local SkyRiding = NRSKNUI:GetModule('SkyRiding')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local GROW_OPTIONS = {
    { key = 'UP',   text = L['Up'] },
    { key = 'DOWN', text = L['Down'] },
}

local function ApplySettings()
    SkyRiding:ApplySettings()
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    -- Card 1
    local enableCard = page:Card(L['Skyriding UI'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Skyriding UI'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Skyriding UI'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('SkyRiding', checked)
            page:Refresh()
        end,
    })

    -- Card 2
    local barsCard = page:Card(L['Bars'], 'all')
    local vigorRow = barsCard:Row(rowH)
    vigorRow:Checkbox(L['Show Vigor'], {
        width = 0.5,
        value = db.Vigor.Enabled,
        callback = function(checked)
            db.Vigor.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    vigorRow:Checkbox(L['Recolor On Thrill Of The Skies'], {
        width = 0.5,
        value = db.Vigor.ThrillEnabled,
        conditions = { 'VigorOn' },
        callback = function(checked)
            db.Vigor.ThrillEnabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    local surgeRow = barsCard:Row(rowHL, 0)
    surgeRow:Checkbox(L['Show Whirling Surge'], {
        width = 0.5,
        value = db.WhirlingSurge.Enabled,
        callback = function(checked)
            db.WhirlingSurge.Enabled = checked
            ApplySettings()
        end,
    })

    surgeRow:Checkbox(L['Show Second Wind'], {
        width = 0.5,
        value = db.SecondWind.Enabled,
        callback = function(checked)
            db.SecondWind.Enabled = checked
            ApplySettings()
        end,
    })

    -- Card 3
    local speedCard = page:Card(L['Speed Text'], 'all')
    local speedEnableRow = speedCard:Row(rowH)
    speedEnableRow:Checkbox(L['Show Speed Text'], {
        width = 1,
        value = db.SpeedText.Enabled,
        callback = function(checked)
            db.SpeedText.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    speedCard:Separator()

    local speedOffsetRow = speedCard:Row(rowHL, 0)
    speedOffsetRow:Slider(L['X Offset'], {
        width = 0.5,
        min = -100,
        max = 100,
        step = 1,
        value = db.SpeedText.XOffset,
        conditions = { 'SpeedTextOn' },
        callback = function(val)
            db.SpeedText.XOffset = val
            ApplySettings()
        end,
    })

    speedOffsetRow:Slider(L['Y Offset'], {
        width = 0.5,
        min = -50,
        max = 50,
        step = 1,
        value = db.SpeedText.YOffset,
        conditions = { 'SpeedTextOn' },
        callback = function(val)
            db.SpeedText.YOffset = val
            ApplySettings()
        end,
    })
end

-- Bar Settings Tab.
local function BuildBarSettingsTab(page, db)
    -- Card 1
    local sizeCard = page:Card(L['Bar Size'], 'all')
    local sizeRow = sizeCard:Row(rowH)
    sizeRow:Slider(L['Width'], {
        width = 0.5,
        min = 50,
        max = 800,
        step = 1,
        value = db.Width,
        callback = function(val)
            db.Width = val
            ApplySettings()
        end,
    })

    sizeRow:Slider(L['Bar Height'], {
        width = 0.5,
        min = 1,
        max = 40,
        step = 1,
        value = db.BarHeight,
        callback = function(val)
            db.BarHeight = val
            ApplySettings()
        end,
    })

    local spacingRow = sizeCard:Row(rowH)
    spacingRow:Slider(L['Row Spacing'], {
        width = 0.5,
        min = -10,
        max = 20,
        step = 1,
        value = db.Spacing,
        callback = function(val)
            db.Spacing = val
            ApplySettings()
        end,
    })

    spacingRow:Slider(L['Pill Spacing'], {
        width = 0.5,
        min = 0,
        max = 20,
        step = 1,
        value = db.PillSpacing,
        callback = function(val)
            db.PillSpacing = val
            ApplySettings()
        end,
    })

    local growRow = sizeCard:Row(rowHL, 0)
    growRow:Dropdown(L['Grow Direction'], {
        width = 1,
        options = GROW_OPTIONS,
        value = db.Grow,
        callback = function(key)
            db.Grow = key
            ApplySettings()
        end,
    })

    -- Card 2
    local textureCard = page:Card(L['Bar Texture'], 'all')
    local globalTextureRow = textureCard:Row(rowH)
    globalTextureRow:Checkbox(L['Use Global Bar'], {
        width = 1,
        value = db.UseGlobalBar,
        callback = function(checked)
            db.UseGlobalBar = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    textureCard:Separator()

    local textureRow = textureCard:Row(rowHL, 0)
    textureRow:Dropdown(L['Bar Texture'], {
        width = 1,
        media = 'statusbar',
        value = db.StatusBarTexture,
        searchable = true,
        conditions = { 'GlobalOn' },
        callback = function(key)
            db.StatusBarTexture = key
            ApplySettings()
        end,
    })
end

-- Color Settings Tab.
local function BuildColorSettingsTab(page, db)
    -- Card 1
    local barColorCard = page:Card(L['Bar Colors'], 'all')
    local vigorRow = barColorCard:Row(rowH)
    vigorRow:Dropdown(L['Vigor Color Mode'], {
        width = 0.5,
        options = NRSKNUI.ColorModeOptions,
        value = db.Vigor.ColorMode,
        conditions = { 'VigorOn' },
        callback = function(key)
            db.Vigor.ColorMode = key
            ApplySettings()
            page:Refresh()
        end,
    })

    vigorRow:ColorPicker(L['Custom Vigor Color'], {
        width = 0.5,
        value = db.Vigor.Color,
        conditions = { 'customVigor' },
        callback = function(r, g, b, a)
            db.Vigor.Color = { r, g, b, a }
            ApplySettings()
        end,
    })

    local thrillRow = barColorCard:Row(rowH)
    thrillRow:Dropdown(L['Thrill Color Mode'], {
        width = 0.5,
        options = NRSKNUI.ColorModeOptions,
        value = db.Vigor.ThrillColorMode,
        conditions = { 'thrillOn' },
        callback = function(key)
            db.Vigor.ThrillColorMode = key
            ApplySettings()
            page:Refresh()
        end,
    })

    thrillRow:ColorPicker(L['Custom Thrill Color'], {
        width = 0.5,
        value = db.Vigor.ThrillColor,
        conditions = { 'customThrill' },
        callback = function(r, g, b, a)
            db.Vigor.ThrillColor = { r, g, b, a }
            ApplySettings()
        end,
    })

    local surgeRow = barColorCard:Row(rowH)
    surgeRow:Dropdown(L['Whirling Surge Color Mode'], {
        width = 0.5,
        options = NRSKNUI.ColorModeOptions,
        value = db.WhirlingSurge.ColorMode,
        conditions = { 'SurgeOn' },
        callback = function(key)
            db.WhirlingSurge.ColorMode = key
            ApplySettings()
            page:Refresh()
        end,
    })

    surgeRow:ColorPicker(L['Custom Whirling Surge Color'], {
        width = 0.5,
        value = db.WhirlingSurge.Color,
        conditions = { 'customSurge' },
        callback = function(r, g, b, a)
            db.WhirlingSurge.Color = { r, g, b, a }
            ApplySettings()
        end,
    })

    local windRow = barColorCard:Row(rowHL, 0)
    windRow:Dropdown(L['Second Wind Color Mode'], {
        width = 0.5,
        options = NRSKNUI.ColorModeOptions,
        value = db.SecondWind.ColorMode,
        conditions = { 'WindOn' },
        callback = function(key)
            db.SecondWind.ColorMode = key
            ApplySettings()
            page:Refresh()
        end,
    })

    windRow:ColorPicker(L['Custom Second Wind Color'], {
        width = 0.5,
        value = db.SecondWind.Color,
        conditions = { 'customWind' },
        callback = function(r, g, b, a)
            db.SecondWind.Color = { r, g, b, a }
            ApplySettings()
        end,
    })

    -- Card 2
    local backdropCard = page:Card(L['Backdrop'], 'all')
    local borderRow = backdropCard:Row(rowH)
    borderRow:Checkbox(L['Show Border'], {
        width = 1,
        value = db.BorderEnabled,
        callback = function(checked)
            db.BorderEnabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    backdropCard:Separator()

    local backdropColorRow = backdropCard:Row(rowHL, 0)
    backdropColorRow:ColorPicker(L['Backdrop Color'], {
        width = 0.5,
        value = db.BackgroundColor,
        callback = function(r, g, b, a)
            db.BackgroundColor = { r, g, b, a }
            ApplySettings()
        end,
    })

    backdropColorRow:ColorPicker(L['Border Color'], {
        width = 0.5,
        value = db.BorderColor,
        conditions = { 'BorderOn' },
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }
            ApplySettings()
        end,
    })

    -- Card 3
    local textColorCard = page:Card(L['Speed Text'], 'all')
    local textColorRow = textColorCard:Row(rowHL, 0)
    textColorRow:ColorPicker(L['Text Color'], {
        width = 1,
        value = db.SpeedText.TextColor,
        conditions = { 'SpeedTextOn' },
        callback = function(r, g, b, a)
            db.SpeedText.TextColor = { r, g, b, a }
            ApplySettings()
        end,
    })
end

-- Font Settings Tab.
local function BuildFontSettingsTab(page, db)
    page:FontSettingsCard({
        title = L['Speed Text Font'],
        db = db.SpeedText,
        onChangeCallback = ApplySettings,
        fontSizeRange = { 8, 32 },
        includeSoftOutline = false,
        globalOverride = {},
    })
end

-- Position Settings Tab.
local function BuildPositionSettingsTab(page, db)
    page:PositionCard({
        db = db,
        showAnchorFrameType = false,
        showStrata = true,
        disableAnchorFrom = true, -- the grow direction owns the self point
        onChangeCallback = ApplySettings,
    })
end

GUI:RegisterPage('skyRiding', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',  text = L['General Settings'] },
        { id = 'bar',      text = L['Bar Settings'] },
        { id = 'color',    text = L['Color Settings'] },
        { id = 'font',     text = L['Font Settings'] },
        { id = 'position', text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.Miscellaneous.SkyRiding
        if not db then return end

        page:SetEnabled(function() return db.Enabled end)
        page:SetCondition('GlobalOn', function() return not db.UseGlobalBar end)
        page:SetCondition('BorderOn', function() return db.BorderEnabled end)
        page:SetCondition('SpeedTextOn', function() return db.SpeedText.Enabled end)
        page:SetCondition('VigorOn', function() return db.Vigor.Enabled end)
        page:SetCondition('SurgeOn', function() return db.WhirlingSurge.Enabled end)
        page:SetCondition('WindOn', function() return db.SecondWind.Enabled end)
        page:SetCondition('thrillOn', function() return db.Vigor.Enabled and db.Vigor.ThrillEnabled end)
        page:SetCondition('customVigor', function() return db.Vigor.Enabled and db.Vigor.ColorMode == 'custom' end)
        page:SetCondition('customThrill', function() return db.Vigor.Enabled and db.Vigor.ThrillEnabled and db.Vigor.ThrillColorMode == 'custom' end)
        page:SetCondition('customSurge', function() return db.WhirlingSurge.Enabled and db.WhirlingSurge.ColorMode == 'custom' end)
        page:SetCondition('customWind', function() return db.SecondWind.Enabled and db.SecondWind.ColorMode == 'custom' end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'bar' then
            BuildBarSettingsTab(page, db)
        elseif tabId == 'color' then
            BuildColorSettingsTab(page, db)
        elseif tabId == 'font' then
            BuildFontSettingsTab(page, db)
        elseif tabId == 'position' then
            BuildPositionSettingsTab(page, db)
        end
    end,
})

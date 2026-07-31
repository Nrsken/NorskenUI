---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local format = string.format

local function ApplySettings() UF:ApplySettings() end

local OutlineOptions = NRSKNUI:GetOutlineOptions(true)

local SeparatorOptions = {}
for _, sep in ipairs({ '»', '«', '|', '-', '–', '•', '·', '/', ':' }) do
    SeparatorOptions[#SeparatorOptions + 1] = { value = sep, text = sep }
end

local function BuildGeneralTab(page, db)
    -- Card 1: Enable
    local conflictAddon = NRSKNUI:GetConflictingUFAddon()
    local enableCard = page:Card(L['Unit Frames'])

    local enableToggle = enableCard:Row(conflictAddon and rowH or rowHL, 0):Checkbox(L['Enable Unit Frames'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Unit Frames'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('UnitFrames', checked)
            page:Refresh()
        end,
    })

    if conflictAddon then
        enableToggle:SetEnabled(not NRSKNUI.UFBlocked)

        enableCard:Row(rowHL, 0):Checkbox(format(L['Defer To %s'], conflictAddon), {
            width = 1,
            master = true,
            tooltip = format(L['%s is loaded and brings its own unit frames. Running both sets at once crashes the client, so keep this on unless you have turned that addon\'s unit frames off.'], conflictAddon),
            value = NRSKNUI.db.profile.UseOtherUF.Enabled,
            callback = function(checked)
                NRSKNUI.db.profile.UseOtherUF.Enabled = checked
                NRSKNUI:CreateReloadPrompt(L['Unit frame ownership only changes on a fresh load.'])
            end,
        })
    end

    -- Card 2: Behaviour
    local behaviourCard = page:Card(L['Behaviour'], 'all')
    behaviourCard:Row(rowHL, 0):Checkbox(L['Smooth Bars'], {
        width = 0.5,
        tooltip = L['Animate health and power bar changes. Units following the global setting inherit this.'],
        value = db.General.Smooth,
        callback = function(checked)
            db.General.Smooth = checked
            ApplySettings()
        end,
    })

    -- Card 3: Range Fade
    local rangeCard = page:Card(L['Range Fade'], 'all')
    rangeCard:Row(rowH):Checkbox(L['Enable Range Fade'], {
        width = 0.5,
        value = db.General.Range.Enabled,
        callback = function(checked)
            db.General.Range.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    rangeCard:Separator()

    local alphaRow = rangeCard:Row(rowHL, 0)
    alphaRow:Slider(L['In Range Alpha'], {
        width = 0.5,
        conditions = { 'rangeOn' },
        min = 0,
        max = 1,
        step = 0.05,
        value = db.General.Range.InsideAlpha,
        callback = function(val)
            db.General.Range.InsideAlpha = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })
    alphaRow:Slider(L['Out of Range Alpha'], {
        width = 0.5,
        conditions = { 'rangeOn' },
        min = 0,
        max = 1,
        step = 0.05,
        value = db.General.Range.OutsideAlpha,
        callback = function(val)
            db.General.Range.OutsideAlpha = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })

    -- Card 4: Absorbs
    local absorbCard = page:Card(L['Absorbs'], 'all')
    local absorbRow = absorbCard:Row(rowHL, 0)
    absorbRow:Checkbox(L['Enable Heal Absorb'], {
        width = 0.5,
        value = db.General.HealAbsorb.Enabled,
        callback = function(checked)
            db.General.HealAbsorb.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    absorbRow:Checkbox(L['Enable Damage Absorb'], {
        width = 0.5,
        value = db.General.DamageAbsorb.Enabled,
        callback = function(checked)
            db.General.DamageAbsorb.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })
end

local function BuildColorsTab(page, db)
    local general = db.General
    local colors = general.Colors

    -- Card 1: Health
    local healthCard = page:Card(L['Health'], 'all')
    local healthRow = healthCard:Row(rowH)
    healthRow:Checkbox(L['Class Colored Health'], {
        width = 1,
        tooltip = L['Color health bars by class for players and by reaction for NPCs.'],
        value = general.ColorByClass,
        callback = function(checked)
            general.ColorByClass = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    healthCard:Separator()

    local healthBgClassRow = healthCard:Row(rowH)
    healthBgClassRow:Slider(L['Class Color Alpha'], {
        width = 0.5,
        conditions = { 'healthClassColor' },
        min = 0,
        max = 1,
        step = 0.05,
        value = general.ForegroundAlphaWhenColorByClass,
        callback = function(val)
            general.ForegroundAlphaWhenColorByClass = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })
    healthBgClassRow:ColorPicker(L['Background (Class Colored)'], {
        width = 0.5,
        conditions = { 'healthClassColor' },
        value = colors.BackgroundWhenColorByClass,
        callback = function(r, g, b, a)
            colors.BackgroundWhenColorByClass = { r, g, b, a }
            ApplySettings()
        end,
    })

    local healthBgRow = healthCard:Row(rowHL, 0)
    healthBgRow:ColorPicker(L['Foreground'], {
        width = 0.5,
        conditions = { 'healthCustom' },
        value = colors.Foreground,
        callback = function(r, g, b, a)
            colors.Foreground = { r, g, b, a }
            ApplySettings()
        end,
    })
    healthBgRow:ColorPicker(L['Background'], {
        width = 0.5,
        conditions = { 'healthCustom' },
        value = colors.Background,
        callback = function(r, g, b, a)
            colors.Background = { r, g, b, a }
            ApplySettings()
        end,
    })

    -- Card 2: Power
    local powerCard = page:Card(L['Power'], 'all')
    local powerRow = powerCard:Row(rowHL, 0)
    powerRow:Checkbox(L['Color By Power Type'], {
        width = 0.5,
        tooltip = L['Color the bar by the power type (mana, rage, energy...). Uncheck to use a flat color.'],
        value = general.ColorByPower,
        callback = function(checked)
            general.ColorByPower = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    powerRow:ColorPicker(L['Power Color'], {
        width = 0.5,
        conditions = { 'powerCustom' },
        value = colors.Power,
        callback = function(r, g, b, a)
            colors.Power = { r, g, b, a }
            ApplySettings()
        end,
    })

    -- Card 3: Castbar
    local castbarCard = page:Card(L['Castbar'], 'all')
    local castbarRow = castbarCard:Row(rowH)
    castbarRow:Checkbox(L['Class Colored Castbar'], {
        width = 1,
        value = general.CastbarColorByClass,
        callback = function(checked)
            general.CastbarColorByClass = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    castbarCard:Separator()

    local castStateRow = castbarCard:Row(rowH)
    castStateRow:ColorPicker(L['Castbar Color'], {
        width = 0.5,
        conditions = { 'castbarCustom' },
        value = colors.Castbar,
        callback = function(r, g, b, a)
            colors.Castbar = { r, g, b, a }
            ApplySettings()
        end,
    })

    castStateRow:ColorPicker(L['Non-Interruptible'], {
        width = 0.5,
        value = colors.CastbarNonInterruptible,
        callback = function(r, g, b, a)
            colors.CastbarNonInterruptible = { r, g, b, a }
            ApplySettings()
        end,
    })

    local castBgRow = castbarCard:Row(rowHL, 0)
    castBgRow:ColorPicker(L['Interrupted / Failed'], {
        width = 0.5,
        value = colors.CastbarFail,
        callback = function(r, g, b, a)
            colors.CastbarFail = { r, g, b, a }
            ApplySettings()
        end,
    })

    castBgRow:ColorPicker(L['Background'], {
        width = 0.5,
        value = colors.CastbarBackground,
        callback = function(r, g, b, a)
            colors.CastbarBackground = { r, g, b, a }
            ApplySettings()
        end,
    })

    -- Card 4: Safe Zone
    local safeZoneCard = page:Card(L['Safe Zone'], 'all')
    local safeZoneRow = safeZoneCard:Row(rowHL, 0)
    safeZoneRow:Checkbox(L['Enable Safe Zone'], {
        width = 0.5,
        tooltip = L['Shows your latency at the end of the cast, on the player frame only.'],
        value = general.SafeZone.Enabled,
        callback = function(checked)
            general.SafeZone.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    safeZoneRow:ColorPicker(L['Safe Zone Color'], {
        width = 0.5,
        conditions = { 'safeZoneOn' },
        value = general.SafeZone.Color,
        callback = function(r, g, b, a)
            general.SafeZone.Color = { r, g, b, a }
            ApplySettings()
        end,
    })

    -- Card 5: Absorbs
    local absorbCard = page:Card(L['Absorbs'], 'all')
    local absorbRow = absorbCard:Row(rowHL, 0)
    absorbRow:ColorPicker(L['Heal Absorb'], {
        width = 0.5,
        conditions = { 'healAbsorbOn' },
        value = general.HealAbsorb.Color,
        callback = function(r, g, b, a)
            general.HealAbsorb.Color = { r, g, b, a }
            ApplySettings()
        end,
    })
    absorbRow:ColorPicker(L['Damage Absorb'], {
        width = 0.5,
        conditions = { 'damageAbsorbOn' },
        value = general.DamageAbsorb.Color,
        callback = function(r, g, b, a)
            general.DamageAbsorb.Color = { r, g, b, a }
            ApplySettings()
        end,
    })
end

local function BuildTexturesTab(page, db)
    local general = db.General

    -- Card 1: Foreground
    local barCard = page:Card(L['Foreground'], 'all')
    local barRow = barCard:Row(rowHL, 0)
    barRow:Checkbox(L['Use Global Bar Texture'], {
        width = 0.5,
        tooltip = L['Use the shared bar texture from the Global Settings page.'],
        value = general.UseGlobalBar,
        callback = function(checked)
            general.UseGlobalBar = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    barRow:Dropdown(L['Foreground Texture'], {
        width = 0.5,
        media = 'statusbar',
        searchable = true,
        conditions = { 'ownBar' },
        value = general.statusBar,
        callback = function(key)
            general.statusBar = key
            ApplySettings()
        end,
    })

    -- Card 2: Background
    local bgCard = page:Card(L['Background'], 'all')
    local bgRow = bgCard:Row(rowHL, 0)
    bgRow:Checkbox(L['Match Foreground'], {
        width = 0.5,
        tooltip = L['Use the foreground texture for the missing-health background.'],
        value = general.BackgroundTexture == '',
        callback = function(checked)
            general.BackgroundTexture = checked and '' or general.statusBar
            ApplySettings()
            page:Refresh()
        end,
    })
    bgRow:Dropdown(L['Background Texture'], {
        width = 0.5,
        media = 'statusbar',
        searchable = true,
        conditions = { 'ownBackground' },
        value = general.BackgroundTexture ~= '' and general.BackgroundTexture or general.statusBar,
        callback = function(key)
            general.BackgroundTexture = key
            ApplySettings()
        end,
    })

    -- Card 3: Castbar spark
    page:SparkSettingsCard({
        title = L['Castbar Spark'],
        db = general,
        onChangeCallback = ApplySettings,
        globalOverride = { label = L['Use Global Spark'] },
        labels = { texture = L['Spark Texture'], scale = L['Spark Scale'], width = L['Spark Width'], color = L['Spark Color'] },
        scaleTooltip = L['Scales the spark against the bar height. Art sparks keep their own proportions.'],
    })

    -- Card 4: Absorbs
    local absorbCard = page:Card(L['Absorbs'], 'all')
    local absorbRow = absorbCard:Row(rowHL, 0)
    absorbRow:Dropdown(L['Heal Absorb'], {
        width = 0.5,
        media = 'statusbar',
        searchable = true,
        conditions = { 'healAbsorbOn' },
        value = general.HealAbsorb.StatusBarTexture,
        callback = function(key)
            general.HealAbsorb.StatusBarTexture = key
            ApplySettings()
        end,
    })
    absorbRow:Dropdown(L['Damage Absorb'], {
        width = 0.5,
        media = 'statusbar',
        searchable = true,
        conditions = { 'damageAbsorbOn' },
        value = general.DamageAbsorb.StatusBarTexture,
        callback = function(key)
            general.DamageAbsorb.StatusBarTexture = key
            ApplySettings()
        end,
    })

    -- Card 5: Mouseover Highlight
    local hlCard = page:Card(L['Mouseover Highlight'], 'all')
    local hlRow = hlCard:Row(rowH)
    hlRow:Checkbox(L['Enable Highlight'], {
        width = 1,
        value = general.Highlight.Enabled,
        callback = function(checked)
            general.Highlight.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    hlCard:Separator()

    local colorTexRow = hlCard:Row(rowHL, 0)
    colorTexRow:Dropdown(L['Highlight Texture'], {
        width = 0.5,
        media = 'statusbar',
        searchable = true,
        conditions = { 'highlightOn' },
        value = general.Highlight.StatusBarTexture,
        callback = function(key)
            general.Highlight.StatusBarTexture = key
            ApplySettings()
        end,
    })
    colorTexRow:ColorPicker(L['Highlight Color'], {
        width = 0.5,
        conditions = { 'highlightOn' },
        value = general.Highlight.Color,
        callback = function(r, g, b, a)
            general.Highlight.Color = { r, g, b, a }
            ApplySettings()
        end,
    })
end

local function BuildFontsTab(page, db)
    local general = db.General

    local fontCard = page:Card(L['Font Settings'], 'all')
    local fontRow = fontCard:Row(rowH)
    fontRow:Checkbox(L['Use Global Font'], {
        width = 1,
        tooltip = L['Use the shared font from the Global Settings page.'],
        value = general.UseGlobalFont,
        callback = function(checked)
            general.UseGlobalFont = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    fontCard:Separator()

    local fontDropdownRow = fontCard:Row(rowHL, 0)
    fontDropdownRow:Dropdown(L['Font'], {
        width = 0.5,
        media = 'font',
        searchable = true,
        conditions = { 'ownFont' },
        value = general.FontFace,
        callback = function(key)
            general.FontFace = key
            ApplySettings()
        end,
    })
    fontDropdownRow:Dropdown(L['Outline'], {
        width = 0.5,
        options = OutlineOptions,
        value = general.FontOutline,
        callback = function(key)
            general.FontOutline = key
            ApplySettings()
        end,
    })
end

local function BuildTagsTab(page, db)
    local tagCard = page:Card(L['Tag Settings'], 'all')
    local tagRow = tagCard:Row(rowHL, 0)
    tagRow:Dropdown(L['Separator'], {
        width = 0.5,
        tooltip = L['Separator used by tags that join two values.'],
        options = SeparatorOptions,
        value = db.TagSettings.Separator,
        callback = function(key)
            db.TagSettings.Separator = key
            ApplySettings()
        end,
    })
    tagRow:Slider(L['Update Interval'], {
        width = 0.5,
        tooltip = L['How often timer-driven units (target of target etc.) refresh their texts.'],
        min = 0.1,
        max = 1,
        step = 0.05,
        value = db.TagSettings.UpdateInterval,
        callback = function(val)
            db.TagSettings.UpdateInterval = val
            ApplySettings()
        end,
        callbackOnRelease = true,
    })
end

GUI:RegisterPage('unitFramesGeneral', {
    mode = 'tabs',
    search = {
        L['Enable Unit Frames'], L['Smooth Bars'], L['Range Fade'], L['Class Colored Health'],
        L['Class Colored Castbar'], L['Heal Absorb'], L['Damage Absorb'], L['Mouseover Highlight'],
        L['Separator'], L['Update Interval'],
    },
    tabs = {
        { id = 'general',  text = L['General Settings'] },
        { id = 'colors',   text = L['Color Settings'] },
        { id = 'textures', text = L['Texture Settings'] },
        { id = 'fonts',    text = L['Font Settings'] },
        { id = 'tags',     text = L['Tag Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.UnitFrames
        if not db then return end

        page:SetEnabled(function() return db.Enabled and not NRSKNUI.UFBlocked end)
        page:SetCondition('rangeOn', function() return db.General.Range.Enabled end)
        page:SetCondition('healthCustom', function() return not db.General.ColorByClass end)
        page:SetCondition('healthClassColor', function() return db.General.ColorByClass end)
        page:SetCondition('powerCustom', function() return not db.General.ColorByPower end)
        page:SetCondition('castbarCustom', function() return not db.General.CastbarColorByClass end)
        page:SetCondition('safeZoneOn', function() return db.General.SafeZone.Enabled end)
        page:SetCondition('healAbsorbOn', function() return db.General.HealAbsorb.Enabled end)
        page:SetCondition('damageAbsorbOn', function() return db.General.DamageAbsorb.Enabled end)
        page:SetCondition('ownBar', function() return not db.General.UseGlobalBar end)
        page:SetCondition('ownBackground', function() return db.General.BackgroundTexture ~= '' end)
        page:SetCondition('highlightOn', function() return db.General.Highlight.Enabled end)
        page:SetCondition('ownFont', function() return not db.General.UseGlobalFont end)

        if tabId == 'general' then
            BuildGeneralTab(page, db)
        elseif tabId == 'colors' then
            BuildColorsTab(page, db)
        elseif tabId == 'textures' then
            BuildTexturesTab(page, db)
        elseif tabId == 'fonts' then
            BuildFontsTab(page, db)
        elseif tabId == 'tags' then
            BuildTagsTab(page, db)
        end
    end,
})

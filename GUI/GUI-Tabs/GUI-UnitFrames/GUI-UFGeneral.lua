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

-- Every section sits on one halves grid: a full-row toggle, then its settings two to a row.
local half = 0.5

local function ColorPicker(row, label, tbl, key, conditions)
    row:ColorPicker(label, {
        width = half,
        conditions = conditions,
        value = tbl[key],
        callback = function(r, g, b, a)
            tbl[key] = { r, g, b, a }
            ApplySettings()
        end,
    })
end

local function TextureDropdown(row, label, tbl, key, conditions)
    row:Dropdown(label, {
        width = half,
        media = 'statusbar',
        searchable = true,
        conditions = conditions,
        value = tbl[key],
        callback = function(value)
            tbl[key] = value
            ApplySettings()
        end,
    })
end

local function ToggleHeader(page, card, label, tbl, key, tooltip)
    card:Row(rowH):Checkbox(label, {
        width = 1,
        tooltip = tooltip,
        value = tbl[key],
        callback = function(checked)
            tbl[key] = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    card:Separator()
end

local function BuildGeneralSection(page, db)
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

    local behaviourRow = page:Card(L['Behaviour'], 'all'):Row(rowHL, 0)
    behaviourRow:Checkbox(L['Smooth Bars'], {
        width = half,
        tooltip = L['Animate health and power bar changes. Units following the global setting inherit this.'],
        value = db.General.Smooth,
        callback = function(checked)
            db.General.Smooth = checked
            ApplySettings()
        end,
    })
    behaviourRow:Checkbox(L['Hide Blizzard Raid Frames'], {
        width = half,
        tooltip = L["Takes Blizzard's compact raid frames and the raid utility off screen. The party ones already go with the party header, and only the raid half is left."],
        value = db.HideBlizzardRaidFrames,
        callback = function(checked)
            db.HideBlizzardRaidFrames = checked
            if checked then
                UF:HideBlizzardRaidFrames()
            else
                NRSKNUI:CreateReloadPrompt(L['Blizzard only builds its raid frames once, so handing them back needs a reload.'])
            end
        end,
    })

    local range = db.General.Range
    local rangeCard = page:Card(L['Range Fade'], 'all')
    ToggleHeader(page, rangeCard, L['Enable Range Fade'], range, 'Enabled',
        L['Fade frames of units that are too far away to heal or attack.'])
    local rangeRow = rangeCard:Row(rowHL, 0)
    rangeRow:Slider(L['In Range Alpha'], {
        width = half,
        conditions = { 'rangeOn' },
        min = 0,
        max = 1,
        step = 0.05,
        value = range.InsideAlpha,
        callback = function(val)
            range.InsideAlpha = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })
    rangeRow:Slider(L['Out of Range Alpha'], {
        width = half,
        conditions = { 'rangeOn' },
        min = 0,
        max = 1,
        step = 0.05,
        value = range.OutsideAlpha,
        callback = function(val)
            range.OutsideAlpha = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })
end

local function BuildTextSection(page, db)
    local general = db.General

    local fontCard = page:Card(L['Font'], 'all')
    ToggleHeader(page, fontCard, L['Use Global Font'], general, 'UseGlobalFont',
        L['Use the shared font from the Global Settings page.'])
    local fontRow = fontCard:Row(rowHL, 0)
    fontRow:Dropdown(L['Font'], {
        width = half,
        media = 'font',
        searchable = true,
        conditions = { 'ownFont' },
        value = general.FontFace,
        callback = function(key)
            general.FontFace = key
            ApplySettings()
        end,
    })
    fontRow:Dropdown(L['Outline'], {
        width = half,
        options = OutlineOptions,
        value = general.FontOutline,
        callback = function(key)
            general.FontOutline = key
            ApplySettings()
        end,
    })

    local tagRow = page:Card(L['Tags'], 'all'):Row(rowHL, 0)
    tagRow:Dropdown(L['Separator'], {
        width = half,
        tooltip = L['Placed between two values in tags that show both, like current and max health.'],
        options = SeparatorOptions,
        value = db.TagSettings.Separator,
        callback = function(key)
            db.TagSettings.Separator = key
            ApplySettings()
        end,
    })
    tagRow:Slider(L['Update Interval'], {
        width = half,
        tooltip = L['How often, in seconds, texts on units without their own events (like target of target) refresh.'],
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

-- Two toggles, so each sits above the dropdown it gates instead of taking a full row.
local function BuildTexturesSection(page, db)
    local general = db.General
    local card = page:Card(L['Textures'], 'all')

    local toggleRow = card:Row(rowH)
    toggleRow:Checkbox(L['Use Global Bar Texture'], {
        width = half,
        tooltip = L['Use the shared bar texture from the Global Settings page.'],
        value = general.UseGlobalBar,
        callback = function(checked)
            general.UseGlobalBar = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    toggleRow:Checkbox(L['Match Foreground'], {
        width = half,
        tooltip = L['Use the foreground texture for the missing-health background.'],
        value = general.BackgroundTexture == '',
        callback = function(checked)
            general.BackgroundTexture = checked and '' or general.statusBar
            ApplySettings()
            page:Refresh()
        end,
    })
    card:Separator()

    local dropdownRow = card:Row(rowHL, 0)
    TextureDropdown(dropdownRow, L['Foreground Texture'], general, 'statusBar', { 'ownBar' })
    dropdownRow:Dropdown(L['Background Texture'], {
        width = half,
        media = 'statusbar',
        searchable = true,
        conditions = { 'ownBackground' },
        value = general.BackgroundTexture ~= '' and general.BackgroundTexture or general.statusBar,
        callback = function(key)
            general.BackgroundTexture = key
            ApplySettings()
        end,
    })
end

-- Both modes' colors stay up, custom on the left and class colored on the right.
local function BuildHealthSection(page, db)
    local general = db.General
    local colors = general.Colors
    local card = page:Card(L['Health'], 'all')

    ToggleHeader(page, card, L['Class Colored'], general, 'ColorByClass',
        L['Color health bars by class for players and by reaction for NPCs.'])

    local fgRow = card:Row(rowH)
    ColorPicker(fgRow, L['Foreground'], colors, 'Foreground')
    fgRow:Slider(L['Class Color Alpha'], {
        width = half,
        min = 0,
        max = 1,
        step = 0.05,
        value = general.ForegroundAlphaWhenColorByClass,
        callback = function(val)
            general.ForegroundAlphaWhenColorByClass = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })

    local bgRow = card:Row(rowHL, 0)
    ColorPicker(bgRow, L['Background'], colors, 'Background')
    ColorPicker(bgRow, L['Background (Class Colored)'], colors, 'BackgroundWhenColorByClass')
end

local function BuildPowerSection(page, db)
    local general = db.General
    local card = page:Card(L['Power'], 'all')
    ToggleHeader(page, card, L['Color By Power Type'], general, 'ColorByPower',
        L['Color the bar by the power type (mana, rage, energy...). Uncheck to use a flat color.'])
    ColorPicker(card:Row(rowHL, 0), L['Power Color'], general.Colors, 'Power', { 'powerCustom' })
end

local function BuildCastbarSection(page, db)
    local general = db.General
    local colors = general.Colors

    local card = page:Card(L['Castbar'], 'all')
    ToggleHeader(page, card, L['Class Colored'], general, 'CastbarColorByClass')

    local colorRow = card:Row(rowH)
    ColorPicker(colorRow, L['Castbar Color'], colors, 'Castbar', { 'castbarCustom' })
    ColorPicker(colorRow, L['Background'], colors, 'CastbarBackground')

    local importantRow = card:Row(rowH)
    importantRow:Checkbox(L['Color Important Casts'], {
        width = half,
        tooltip = L['Casts the game flags as important, such as ones that are lethal if not interrupted.'],
        value = general.CastbarColorImportant,
        callback = function(checked)
            general.CastbarColorImportant = checked
            ApplySettings()
        end,
    })
    ColorPicker(importantRow, L['Important'], colors, 'CastbarImportant')

    local stateRow = card:Row(rowHL, 0)
    ColorPicker(stateRow, L['Non-Interruptible'], colors, 'CastbarNonInterruptible')
    ColorPicker(stateRow, L['Interrupted / Failed'], colors, 'CastbarFail')

    local safeZoneCard = page:Card(L['Safe Zone'], 'all')
    ToggleHeader(page, safeZoneCard, L['Enable Safe Zone'], general.SafeZone, 'Enabled',
        L['Shows your latency at the end of the cast, on the player frame only.'])
    ColorPicker(safeZoneCard:Row(rowHL, 0), L['Color'], general.SafeZone, 'Color', { 'safeZoneOn' })

    page:SparkSettingsCard({
        title = L['Castbar Spark'],
        db = general,
        onChangeCallback = ApplySettings,
        globalOverride = { label = L['Use Global Spark'] },
        labels = { texture = L['Spark Texture'], scale = L['Spark Scale'], width = L['Spark Width'], color = L['Spark Color'] },
        scaleTooltip = L['Scales the spark against the bar height. Art sparks keep their own proportions.'],
    })
end

local function BuildOverlayCard(page, title, label, tbl, condition)
    local card = page:Card(title, 'all')
    ToggleHeader(page, card, label, tbl, 'Enabled')
    local row = card:Row(rowHL, 0)
    ColorPicker(row, L['Color'], tbl, 'Color', { condition })
    TextureDropdown(row, L['Texture'], tbl, 'StatusBarTexture', { condition })
end

local function BuildAbsorbsSection(page, db)
    BuildOverlayCard(page, L['Heal Prediction'], L['Enable Heal Prediction'], db.General.HealPrediction, 'healPredictionOn')
    BuildOverlayCard(page, L['Max Health Reduction'], L['Enable Max Health Reduction'], db.General.TempLoss, 'tempLossOn')
    BuildOverlayCard(page, L['Heal Absorb'], L['Enable Heal Absorb'], db.General.HealAbsorb, 'healAbsorbOn')
    BuildOverlayCard(page, L['Damage Absorb'], L['Enable Damage Absorb'], db.General.DamageAbsorb, 'damageAbsorbOn')
end

local function BuildHighlightSection(page, db)
    BuildOverlayCard(page, L['Mouseover Highlight'], L['Enable Highlight'], db.General.Highlight, 'highlightOn')
end

local Sections = {
    general   = BuildGeneralSection,
    text      = BuildTextSection,
    dispel    = function(page, db) UF.GUIDispelTab(page, db) end,
    layers    = function(page) UF.GUILayersTab(page) end,
    textures  = BuildTexturesSection,
    health    = BuildHealthSection,
    power     = BuildPowerSection,
    castbar   = BuildCastbarSection,
    absorbs   = BuildAbsorbsSection,
    highlight = BuildHighlightSection,
}

GUI:RegisterPage('unitFramesGeneral', {
    mode = 'clean',
    search = {},
    sidebar = {
        items = {
            { type = 'label', key = 'frames', text = L['Unit Frames'] },
            { key = 'general',   text = L['General'] },
            { key = 'text',      text = L['Text'] },
            { key = 'dispel',    text = L['Dispel'] },
            { key = 'layers',    text = L['Layers'] },
            { type = 'label', key = 'bars', text = L['Bars'] },
            { key = 'textures',  text = L['Textures'] },
            { key = 'health',    text = L['Health'] },
            { key = 'power',     text = L['Power'] },
            { key = 'castbar',   text = L['Castbar'] },
            { key = 'absorbs',   text = L['Absorbs'] },
            { key = 'highlight', text = L['Mouseover Highlight'] },
        },
    },
    build = function(page, _, itemKey)
        local db = NRSKNUI.db.profile.UnitFrames
        local build = db and Sections[itemKey]
        -- Caption rows reach here from the search harvester, they have no section.
        if not build then return end

        page:SetEnabled(function() return db.Enabled and not NRSKNUI.UFBlocked end)
        page:SetCondition('rangeOn', function() return db.General.Range.Enabled end)
        page:SetCondition('powerCustom', function() return not db.General.ColorByPower end)
        page:SetCondition('castbarCustom', function() return not db.General.CastbarColorByClass end)
        page:SetCondition('safeZoneOn', function() return db.General.SafeZone.Enabled end)
        page:SetCondition('healPredictionOn', function() return db.General.HealPrediction.Enabled end)
        page:SetCondition('tempLossOn', function() return db.General.TempLoss.Enabled end)
        page:SetCondition('healAbsorbOn', function() return db.General.HealAbsorb.Enabled end)
        page:SetCondition('damageAbsorbOn', function() return db.General.DamageAbsorb.Enabled end)
        page:SetCondition('ownBar', function() return not db.General.UseGlobalBar end)
        page:SetCondition('ownBackground', function() return db.General.BackgroundTexture ~= '' end)
        page:SetCondition('highlightOn', function() return db.General.Highlight.Enabled end)
        page:SetCondition('ownFont', function() return not db.General.UseGlobalFont end)

        build(page, db)
    end,
})

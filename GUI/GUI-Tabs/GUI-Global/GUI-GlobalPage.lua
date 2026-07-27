---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local min = math.min
local _G = _G

-- { key, label } specs drive the color-picker grids below. key indexes db.profile.Colors.<category>.
-- Game terms pull Blizzard's own localized global strings so they translate for free.
local PowerColorSpecs = {
    { key = 0,  label = _G.MANA },
    { key = 1,  label = _G.RAGE },
    { key = 2,  label = _G.FOCUS },
    { key = 3,  label = _G.ENERGY },
    { key = 6,  label = _G.RUNIC_POWER },
    { key = 8,  label = _G.LUNAR_POWER },
    { key = 11, label = _G.MAELSTROM },
    { key = 13, label = _G.INSANITY },
    { key = 17, label = _G.FURY },
    { key = 18, label = _G.PAIN },
}

local ReactionColorSpecs = {}
for i = 1, 8 do
    ReactionColorSpecs[i] = { key = i, label = _G['FACTION_STANDING_LABEL' .. i] }
end

local ClassColorSpecs = {}
local ClassTokens = {
    'DEATHKNIGHT', 'DEMONHUNTER', 'DRUID', 'EVOKER', 'HUNTER', 'MAGE', 'MONK',
    'PALADIN', 'PRIEST', 'ROGUE', 'SHAMAN', 'WARLOCK', 'WARRIOR',
}
for _, token in ipairs(ClassTokens) do
    ClassColorSpecs[#ClassColorSpecs + 1] = { key = token, label = LOCALIZED_CLASS_NAMES_MALE[token] }
end

local StatusColorSpecs = {
    { key = 'Tapped',       label = L['Tapped'] },
    { key = 'Disconnected', label = L['Disconnected'] },
    { key = 'Dead',         label = L['Dead'] },
}

local DispelColorTypes = {
    { key = 'None',    label = L['None'] },
    { key = 'Magic',   label = L['Magic'] },
    { key = 'Curse',   label = L['Curse'] },
    { key = 'Disease', label = L['Disease'] },
    { key = 'Poison',  label = L['Poison'] },
    { key = 'Bleed',   label = L['Bleed'] },
    { key = 'Enrage',  label = L['Enrage'] },
}

local durationModeOptions = {
    { key = 'breakpoint', text = L['Breakpoint Colors'] },
    { key = 'curve',      text = L['Curve Colors'] },
    { key = 'single',     text = L['Single Color'] },
}

local formatOptions = {
    { key = '%0.1f',  text = L['Decimal Seconds: 0.1'] },
    { key = '%0.1fs', text = L['Decimal Seconds w/ seconds: 0.1s'] },
    { key = '%d',     text = L['Whole Seconds: 1'] },
    { key = '%ds',    text = L['Whole Seconds w/ seconds: 1s'] },
    { key = '%dm',    text = L['Minutes: 1m'] },
    { key = '%dh',    text = L['Hours: 1h'] },
}

local function RefreshFormatter()
    NRSKNUI:RefreshAuraDurationFormatter()
    NRSKNUI:ApplyToAllModules()
end

-- Font Settings Tab.
local function BuildGlobalColorsTab(page, db)
    local function RefreshColors()
        NRSKNUI:LoadCustomColors()
        NRSKNUI:ApplyToAllModules()
    end

    -- Build one card of color pickers laid out three per row from a { key, label } spec list.
    local function BuildColorCard(title, dbTable, specs, storeAlpha)
        local card = page:Card(title, 'all')
        local count = #specs

        for i = 1, count, 3 do
            local isLast = (i + 2) >= count
            local rowHeight = (isLast and rowHL) or rowH
            local row = card:Row(rowHeight)

            for j = i, min(i + 2, count) do
                local spec = specs[j]

                row:ColorPicker(spec.label, {
                    width = (1 / 3),
                    value = dbTable[spec.key],
                    callback = function(r, g, b, a)
                        dbTable[spec.key] = storeAlpha and { r, g, b, a } or { r, g, b }
                        RefreshColors()
                    end,
                })
            end
        end
    end

    BuildColorCard(L['Power Colors'], db.Power, PowerColorSpecs, false)
    BuildColorCard(L['Reaction Colors'], db.Reaction, ReactionColorSpecs, false)
    BuildColorCard(L['Class Colors'], db.Class, ClassColorSpecs, false)
    BuildColorCard(L['Status Colors'], db.Status, StatusColorSpecs, true)
    BuildColorCard(L['Dispel Colors'], db.Dispel, DispelColorTypes, true)
end

local function BuildGlobalUIScaleTab(page, db)
    page:SetCondition('uiScaleOn', function() return db.Enabled end)

    local uiScaleCard = page:Card(L['UI Scale'])
    local uiScaleRow1 = uiScaleCard:Row(rowH)
    uiScaleRow1:Checkbox(L['Enable UI Scale'], {
        width = 0.5,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['UI Scale'],
        tooltip = L['Disable scaling in other addons to avoid conflicts.'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:SetUIScale()
            page:Refresh()
        end,
    })

    uiScaleRow1:Slider(L['Scale'], {
        width = 0.5,
        min = 0.4,
        max = 1.15,
        step = 0.01,
        value = db.Scale,
        conditions = { 'uiScaleOn' },
        callback = function(val)
            db.Scale = val
            NRSKNUI:SetScaleValue(db.Scale)
        end,
        callbackOnRelease = true,
    })

    uiScaleCard:Separator()

    local buttonH = 36
    local buttonOffset = -2
    local uiScaleRow2 = uiScaleCard:Row(rowHL, 0)
    uiScaleRow2:Button(L['Auto (Pixel Perfect)'], {
        width = (1 / 3),
        height = buttonH,
        yOffset = buttonOffset,
        tooltip = L['Automatically match your resolution (768 / screen height).'],
        conditions = { 'uiScaleOn' },
        callback = function()
            NRSKNUI:SetScaleValue()
            page:Refresh()
        end,
    })

    uiScaleRow2:Button(L['1080p Scale'], {
        width = (1 / 3),
        height = buttonH,
        yOffset = buttonOffset,
        tooltip = L['Set UI scale for 1080p resolution.'],
        conditions = { 'uiScaleOn' },
        callback = function()
            NRSKNUI:SetScaleValue(NRSKNUI.TenEigthyPixel)
            page:Refresh()
        end,
    })

    uiScaleRow2:Button(L['1440p Scale'], {
        width = (1 / 3),
        height = buttonH,
        yOffset = buttonOffset,
        tooltip = L['Set UI scale for 1440p resolution.'],
        conditions = { 'uiScaleOn' },
        callback = function()
            NRSKNUI:SetScaleValue(NRSKNUI.FourteenFortyPixel)
            page:Refresh()
        end,
    })
end

local function BuildGlobalTexturesTab(page, db)
    local bar, spark = db.profileBar, db.profileSpark

    page:SetCondition('globBarON', function() return bar.Enabled end)
    page:SetCondition('globSparkON', function() return spark.Enabled end)
    page:SetCondition('globSparkSolid', function() return spark.Enabled and spark.sparkTexture == 'Solid' end)

    local globalTexturesCard = page:Card(L['Global Bar'])
    local useGlobalBarRow = globalTexturesCard:Row(rowHL, 0)
    useGlobalBarRow:Checkbox(L['Use Global Bar Texture'], {
        width = 0.5,
        value = bar.Enabled,
        msgPopup = true,
        msgText = L['Global Bar'],
        tooltip = L['Enable this to use the same bar texture across all modules.'],
        callback = function(checked)
            bar.Enabled = checked
            NRSKNUI:ApplyToAllModules()
            page:Refresh()
        end,
    })

    useGlobalBarRow:Dropdown(L['Global Bar Texture'], {
        width = 0.5,
        media = 'statusbar',
        value = bar.statusBar,
        searchable = true,
        conditions = { 'globBarON' },
        callback = function(key)
            bar.statusBar = key
            NRSKNUI:ApplyToAllModules()
        end,
    })

    local globalSparkCard = page:Card(L['Global Spark'])
    local useGlobalSparkRow = globalSparkCard:Row(rowH)
    useGlobalSparkRow:Checkbox(L['Use Global Spark Texture'], {
        width = 1,
        value = spark.Enabled,
        msgPopup = true,
        msgText = L['Global Spark'],
        tooltip = L['Enable this to use the same spark texture across all castbars.'],
        callback = function(checked)
            spark.Enabled = checked
            NRSKNUI:ApplyToAllModules()
            page:Refresh()
        end,
    })

    globalSparkCard:Separator()

    local globalSparkTextureRow = globalSparkCard:Row(rowH)
    globalSparkTextureRow:Dropdown(L['Global Spark Texture'], {
        width = 0.5,
        media = 'spark',
        value = spark.sparkTexture,
        searchable = true,
        conditions = { 'globSparkON' },
        callback = function(key)
            spark.sparkTexture = key
            NRSKNUI:ApplyToAllModules()
            page:Refresh() -- re-evaluates globSparkSolid for the width slider
        end,
    })

    globalSparkTextureRow:ColorPicker(L['Spark Color'], {
        width = 0.5,
        value = spark.color,
        conditions = { 'globSparkON' },
        callback = function(r, g, b, a)
            spark.color = { r, g, b, a }
            NRSKNUI:ApplyToAllModules()
        end,
    })

    local sparkStyleRow = globalSparkCard:Row(rowHL, 0)
    sparkStyleRow:Slider(L['Spark Scale'], {
        width = 0.5,
        min = 0.5,
        max = 4,
        step = 0.05,
        value = spark.Scale,
        conditions = { 'globSparkON' },
        tooltip = L['Scales the spark against the bar height. Art sparks keep their own proportions.'],
        callback = function(val)
            spark.Scale = val
            NRSKNUI:ApplyToAllModules()
        end,
        callbackOnRelease = true,
    })

    sparkStyleRow:Slider(L['Spark Width'], {
        width = 0.5,
        min = 1,
        max = 16,
        step = 1,
        value = spark.Width,
        conditions = { 'globSparkSolid' },
        tooltip = L['Only the solid spark can be widened, art sparks keep their own proportions.'],
        callback = function(val)
            spark.Width = val
            NRSKNUI:ApplyToAllModules()
        end,
    })
end

local function BuildFormatterTab(page, db)
    db.profileBreakPoints = db.profileBreakPoints or {}

    db.profileBreakPoints.pointOne = db.profileBreakPoints.pointOne or { threshold = 0, step = 0.1, format = '%0.1f' }
    db.profileBreakPoints.pointTwo = db.profileBreakPoints.pointTwo or { threshold = 3, step = 1, format = '%d' }
    db.profileBreakPoints.pointThree = db.profileBreakPoints.pointThree or { threshold = 10, step = 1, format = '%d' }
    db.profileBreakPoints.pointFour = db.profileBreakPoints.pointFour or { threshold = 60, format = '%dm' }
    db.profileBreakPoints.pointFive = db.profileBreakPoints.pointFive or { threshold = 3600, format = '%dh' }

    db.profileBreakPoints.pointOne.threshold = db.profileBreakPoints.pointOne.threshold or 0
    db.profileBreakPoints.pointTwo.threshold = db.profileBreakPoints.pointTwo.threshold or 3
    db.profileBreakPoints.pointThree.threshold = db.profileBreakPoints.pointThree.threshold or 10
    db.profileBreakPoints.pointFour.threshold = db.profileBreakPoints.pointFour.threshold or 60
    db.profileBreakPoints.pointFive.threshold = db.profileBreakPoints.pointFive.threshold or 3600

    db.profileColorBreakPoint = db.profileColorBreakPoint or {}
    db.profileColorBreakPoint.colorOne = db.profileColorBreakPoint.colorOne or { 1, 0.25, 0.25, 1 }
    db.profileColorBreakPoint.colorTwo = db.profileColorBreakPoint.colorTwo or { 1, 1, 1, 1 }
    db.profileColorBreakPoint.colorThree = db.profileColorBreakPoint.colorThree or { 1, 1, 1, 1 }
    db.profileColorBreakPoint.colorFour = db.profileColorBreakPoint.colorFour or { 1, 1, 1, 1 }
    db.profileColorBreakPoint.colorFive = db.profileColorBreakPoint.colorFive or { 1, 1, 1, 1 }

    db.durationSingleColorValue = db.durationSingleColorValue or { 1, 1, 1, 1 }
    if db.durationBreakpointColors == nil and db.durationCurveColors == nil and db.durationSingleColor == nil then
        db.durationBreakpointColors = true
        db.durationCurveColors = false
        db.durationSingleColor = false
    end

    local function SetDurationColorMode(mode)
        db.durationBreakpointColors = (mode == 'breakpoint')
        db.durationCurveColors = (mode == 'curve')
        db.durationSingleColor = (mode == 'single')
    end

    local function GetDurationColorMode()
        if db.durationSingleColor then return 'single' end
        if db.durationBreakpointColors then return 'breakpoint' end
        return 'curve'
    end

    page:SetCondition('durationModeBreakpoint', function() return db.durationBreakpointColors end)
    page:SetCondition('durationModeSingle', function() return db.durationSingleColor end)
    page:SetCondition('durationModeCurve', function() return db.durationCurveColors end)

    local bpCard = page:Card(L['Color Mode & Settings'])
    local modeRow = bpCard:Row(rowH)
    modeRow:Text(NRSKNUI:ColorTextByTheme(L['Color Mode']), {
        text = L['Customize how aura duration text is colored, including:'] .. '\n' ..
            NRSKNUI:ColorTextByTheme("  • ") .. L['Breakpoints, instant color changes at specific durations.'] .. '\n' ..
            NRSKNUI:ColorTextByTheme("  • ") .. L['Curve, gradual color changes based on duration.'] .. '\n' ..
            NRSKNUI:ColorTextByTheme("  • ") .. L['Single color, a single color for all durations.'],
        width = 0.5,
        textAlign = 'LEFT',
    })

    modeRow:Dropdown(L['Modes'], {
        width = 0.5,
        options = durationModeOptions,
        value = GetDurationColorMode(),
        callback = function(key)
            SetDurationColorMode(key)
            RefreshFormatter()
            RunNextFrame(function() --TODO: Figure out why this is needed for this ONE widget. Without it, the color pickers don't update until the next tab switch.
                page:Refresh()
            end)
        end,
    })

    bpCard:Separator()

    local bpRow1 = bpCard:Row(rowH)
    bpRow1:ColorPicker(L['Point 1 Color'], {
        width = 0.5,
        value = db.profileColorBreakPoint.colorOne,
        conditions = { 'durationModeBreakpoint' },
        callback = function(r, g, b, a)
            db.profileColorBreakPoint.colorOne = { r, g, b, a }
            RefreshFormatter()
        end,
    })
    bpRow1:ColorPicker(L['Point 1 Curve Color'], {
        width = 0.5,
        value = db.profileColorCurve.colorOne,
        conditions = { 'durationModeCurve' },
        callback = function(r, g, b, a)
            db.profileColorCurve.colorOne = { r, g, b, a }
            RefreshFormatter()
        end,
    })

    local bpRow2 = bpCard:Row(rowH)
    bpRow2:ColorPicker(L['Point 2 Color'], {
        width = 0.5,
        value = db.profileColorBreakPoint.colorTwo,
        conditions = { 'durationModeBreakpoint' },
        callback = function(r, g, b, a)
            db.profileColorBreakPoint.colorTwo = { r, g, b, a }
            RefreshFormatter()
        end,
    })
    bpRow2:ColorPicker(L['Point 2 Curve Color'], {
        width = 0.5,
        value = db.profileColorCurve.colorTwo,
        conditions = { 'durationModeCurve' },
        callback = function(r, g, b, a)
            db.profileColorCurve.colorTwo = { r, g, b, a }
            RefreshFormatter()
        end,
    })

    local bpRow3 = bpCard:Row(rowH)
    bpRow3:ColorPicker(L['Point 3 Color'], {
        width = 0.5,
        value = db.profileColorBreakPoint.colorThree,
        conditions = { 'durationModeBreakpoint' },
        callback = function(r, g, b, a)
            db.profileColorBreakPoint.colorThree = { r, g, b, a }
            RefreshFormatter()
        end,
    })
    bpRow3:ColorPicker(L['Point 3 Curve Color'], {
        width = 0.5,
        value = db.profileColorCurve.colorThree,
        conditions = { 'durationModeCurve' },
        callback = function(r, g, b, a)
            db.profileColorCurve.colorThree = { r, g, b, a }
            RefreshFormatter()
        end,
    })

    local bpRow4 = bpCard:Row(rowH)
    bpRow4:ColorPicker(L['Point 4 Color'], {
        width = 0.5,
        value = db.profileColorBreakPoint.colorFour,
        conditions = { 'durationModeBreakpoint' },
        callback = function(r, g, b, a)
            db.profileColorBreakPoint.colorFour = { r, g, b, a }
            RefreshFormatter()
        end,
    })
    bpRow4:ColorPicker(L['Point 4 Curve Color'], {
        width = 0.5,
        value = db.profileColorCurve.colorFour,
        conditions = { 'durationModeCurve' },
        callback = function(r, g, b, a)
            db.profileColorCurve.colorFour = { r, g, b, a }
            RefreshFormatter()
        end,
    })

    local bpRow5 = bpCard:Row(rowH)
    bpRow5:ColorPicker(L['Point 5 Color'], {
        width = 0.5,
        value = db.profileColorBreakPoint.colorFive,
        conditions = { 'durationModeBreakpoint' },
        callback = function(r, g, b, a)
            db.profileColorBreakPoint.colorFive = { r, g, b, a }
            RefreshFormatter()
        end,
    })
    bpRow5:ColorPicker(L['Point 5 Curve Color'], {
        width = 0.5,
        value = db.profileColorCurve.colorFive,
        conditions = { 'durationModeCurve' },
        callback = function(r, g, b, a)
            db.profileColorCurve.colorFive = { r, g, b, a }
            RefreshFormatter()
        end,
    })

    bpCard:Separator()

    local singleRow = bpCard:Row(rowHL, 0)
    singleRow:ColorPicker(L['One Color Mode'], {
        width = 1,
        value = db.durationSingleColorValue,
        conditions = { 'durationModeSingle' },
        callback = function(r, g, b, a)
            db.durationSingleColorValue = { r, g, b, a }
            RefreshFormatter()
        end,
    })

    local ruleCard = page:Card(L['Breakpoint Rules'])
    local ruleRow1 = ruleCard:Row(rowH)
    ruleRow1:Slider(L['Point 1 Start'], {
        width = 0.5,
        min = 0,
        max = 59,
        step = 1,
        value = db.profileBreakPoints.pointOne.threshold,
        callback = function(val)
            db.profileBreakPoints.pointOne.threshold = val
            page:Refresh()
            RefreshFormatter()
        end,
    })

    ruleRow1:Slider(L['Point 2 Start'], {
        width = 0.5,
        min = 1,
        max = 59,
        step = 1,
        value = db.profileBreakPoints.pointTwo.threshold,
        callback = function(val)
            db.profileBreakPoints.pointTwo.threshold = val
            page:Refresh()
            RefreshFormatter()
        end,
    })

    local ruleRow2 = ruleCard:Row(rowH)
    ruleRow2:Slider(L['Point 3 Start'], {
        width = 0.5,
        min = 2,
        max = 599,
        step = 1,
        value = db.profileBreakPoints.pointThree.threshold,
        callback = function(val)
            db.profileBreakPoints.pointThree.threshold = val
            page:Refresh()
            RefreshFormatter()
        end,
    })

    ruleRow2:Slider(L['Point 4 Start'], {
        width = 0.5,
        min = 3,
        max = 3599,
        step = 1,
        value = db.profileBreakPoints.pointFour.threshold,
        callback = function(val)
            db.profileBreakPoints.pointFour.threshold = val
            page:Refresh()
            RefreshFormatter()
        end,
    })

    ruleCard:Row(rowH):Slider(L['Point 5 Start'], {
        width = 1,
        min = 4,
        max = 21600,
        step = 1,
        value = db.profileBreakPoints.pointFive.threshold,
        callback = function(val)
            db.profileBreakPoints.pointFive.threshold = val
            page:Refresh()
            RefreshFormatter()
        end,
    })

    local formatCard = page:Card(L['Format Rules'])
    local function CreateFormatDropdown(row, label, dbPoint, last)
        row:Dropdown(label, {
            width = last and 1 or 0.5,
            options = formatOptions,
            value = dbPoint.format,
            callback = function(key)
                dbPoint.format = key
                RefreshFormatter()
            end,
        })
    end

    local ruleRow3 = formatCard:Row(rowH)
    CreateFormatDropdown(ruleRow3, L['Point 1 Format'], db.profileBreakPoints.pointOne)
    CreateFormatDropdown(ruleRow3, L['Point 2 Format'], db.profileBreakPoints.pointTwo)

    local ruleRow4 = formatCard:Row(rowH)
    CreateFormatDropdown(ruleRow4, L['Point 3 Format'], db.profileBreakPoints.pointThree)
    CreateFormatDropdown(ruleRow4, L['Point 4 Format'], db.profileBreakPoints.pointFour)

    local ruleRow5 = formatCard:Row(rowHL, 0)
    CreateFormatDropdown(ruleRow5, L['Point 5 Format'], db.profileBreakPoints.pointFive, true)

    local reloadCard = page:Card(L['Apply Changes'], 'all')
    reloadCard:Row(56):Text(L['Aura Button Information'], {
        width = 1,
        text = L['Aura buttons are built once by the game and cannot be restyled in place. For the formatting changes to take effect, a reload is required.'],
        height = 56,
        bgMode = 'none',
    })
    reloadCard:Row(32):Button(L['Reload UI'], {
        width = 1,
        height = 32,
        callback = function()
            ReloadUI()
        end,
    })
end

GUI:RegisterPage('globalPage', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'colors',    text = L['Color Settings'] },
        { id = 'uiscale',   text = L['UI Scale Settings'] },
        { id = 'textures',  text = L['Global Textures'] },
        { id = 'formatter', text = L['Custom Formatter'] },
    },
    build = function(page, tabId, itemKey)
        if tabId == 'colors' then
            BuildGlobalColorsTab(page, NRSKNUI.db.profile.Colors)
        elseif tabId == 'uiscale' then
            BuildGlobalUIScaleTab(page, NRSKNUI.db.global.UIScale)
        elseif tabId == 'textures' then
            BuildGlobalTexturesTab(page, NRSKNUI.db.profile.globalMedia)
        elseif tabId == 'formatter' then
            BuildFormatterTab(page, NRSKNUI.db.profile.globalMedia)
        end
    end,
})

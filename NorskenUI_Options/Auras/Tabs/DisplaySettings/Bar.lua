---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenAuras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local IconPicker = NRSKNUI.CDMIconPicker
local rowH = Theme.rowHeight

local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber

---@class NRSKNUI.CDMDisplayTab
local DisplayTab = NRSKNUI.CDMDisplayTab
local ICON_SOURCES = DisplayTab.ICON_SOURCES

local BAR_COLOR_MODES = {
    { value = 'custom', text = L['Custom'] },
    { value = 'class',  text = L['Class Color'] },
    { value = 'power',  text = L['Power Color'] },
}

local DIRECTIONS = {
    { value = 'HORIZONTAL',         text = L['Right to Left'], orientation = 'HORIZONTAL', reverse = false },
    { value = 'HORIZONTAL_INVERSE', text = L['Left to Right'], orientation = 'HORIZONTAL', reverse = true },
    { value = 'VERTICAL',           text = L['Bottom to Top'], orientation = 'VERTICAL',   reverse = true },
    { value = 'VERTICAL_INVERSE',   text = L['Top to Bottom'], orientation = 'VERTICAL',   reverse = false },
}

local ICON_SIDES = {
    HORIZONTAL = { { value = 'LEFT', text = L['Left'] }, { value = 'RIGHT', text = L['Right'] } },
    VERTICAL = { { value = 'TOP', text = L['Top'] }, { value = 'BOTTOM', text = L['Bottom'] } },
}

---@param displays table[]
---@param kind string
---@return boolean
local function HasTrigger(displays, kind)
    for _, display in ipairs(displays) do
        for _, trigger in ipairs(display.Triggers or {}) do
            if trigger.Type == kind then return true end
        end
    end
    return false
end

---The resource a split power bar shows, nil when the display isn't one.
---@param display table
---@return number?
local function SplitPower(display)
    if display.type ~= 'bar' then return nil end
    for _, trigger in ipairs(display.Triggers or {}) do
        if trigger.Type == 'power' and trigger.Mode and CDM.SEGMENTED_POWER[trigger.PowerType] then return trigger.PowerType end
    end
    return nil
end

---@param card table
---@param page table
---@param style table read side
---@param set fun(path: string[], value: any, more: boolean?)
---@param mixed fun(path: (string|number)[], default: any?): KajiGUIMixedEntry[]? where the displays edited together disagree (DisplayTab.Differ)
local function BarSettings(card, page, style, set, mixed)
    page:SetCondition('cdm:customBar', function() return style.UseGlobalBar == false or mixed({ 'UseGlobalBar' }) end)

    local textureRow = card:Row(rowH)
    textureRow:Checkbox(L['Use Global Bar'], {
        width = 0.5,
        value = style.UseGlobalBar ~= false,
        mixed = mixed({ 'UseGlobalBar' }),
        callback = function(checked)
            set({ 'UseGlobalBar' }, checked)
            page:Refresh()
        end,
    })
    textureRow:Dropdown(L['Bar Texture'], {
        width = 0.5,
        media = 'statusbar',
        searchable = true,
        conditions = { 'cdm:customBar' },
        value = style.StatusBarTexture,
        mixed = mixed({ 'StatusBarTexture' }),
        callback = function(key) set({ 'StatusBarTexture' }, key) end,
    })

    local direction
    for _, option in ipairs(DIRECTIONS) do
        if option.orientation == style.Orientation and option.reverse == (style.ReverseFill == true) then direction = option.value end
    end
    local directionRow = card:Row(rowH)
    directionRow:Dropdown(L['Orientation'], {
        width = 0.5,
        options = DIRECTIONS,
        value = direction,
        mixed = mixed({ 'Orientation' }) or mixed({ 'ReverseFill' }),
        callback = function(value)
            for _, option in ipairs(DIRECTIONS) do
                if option.value == value then
                    set({ 'Orientation' }, option.orientation, true)
                    set({ 'ReverseFill' }, option.reverse)
                end
            end
            card:Rebuild()
        end,
    })
    directionRow:Checkbox(L['Inverse'], {
        width = 0.5,
        value = style.Inverse,
        mixed = mixed({ 'Inverse' }),
        callback = function(checked) set({ 'Inverse' }, checked) end,
    })

    card:Row(rowH):Checkbox(L['Smooth'], {
        width = 0.5,
        tooltip = L['Ease the bar to a new value or a new cast instead of jumping.'],
        value = style.Smooth,
        mixed = mixed({ 'Smooth' }),
        callback = function(checked) set({ 'Smooth' }, checked) end,
    })
end

---@param card table
---@param page table
---@param style table read side
---@param set fun(path: string[], value: any)
---@param mixed fun(path: (string|number)[], default: any?): KajiGUIMixedEntry[]? where the displays edited together disagree (DisplayTab.Differ)
---@param displays table[] the bars being edited
local function BarColorSettings(card, page, style, set, mixed, displays)
    page:SetCondition('cdm:customBarColor', function() return style.BarColorMode ~= 'power' or mixed({ 'BarColorMode' }) end)
    local hasCast = HasTrigger(displays, 'cast')

    local colorRow = card:Row(rowH)
    colorRow:Dropdown(L['Bar Color'], {
        width = 0.5,
        tooltip = L['Power Color follows the power type of a power trigger. Conditions can colour the bar per state, like a channel or an interrupted cast.'],
        options = BAR_COLOR_MODES,
        value = style.BarColorMode,
        mixed = mixed({ 'BarColorMode' }),
        callback = function(value)
            set({ 'BarColorMode' }, value)
            page:Refresh()
        end,
    })
    colorRow:ColorPicker(L['Custom Color'], {
        width = 0.5,
        conditions = { 'cdm:customBarColor' },
        value = style.BarColor,
        mixed = mixed({ 'BarColor' }),
        callback = function(r, g, b, a) set({ 'BarColor' }, { r, g, b, a }) end,
    })

    local backgroundRow = card:Row(rowH)
    backgroundRow:ColorPicker(L['Background Color'], {
        width = 0.5,
        value = style.BackgroundColor,
        mixed = mixed({ 'BackgroundColor' }),
        callback = function(r, g, b, a) set({ 'BackgroundColor' }, { r, g, b, a }) end,
    })
    if hasCast then
        backgroundRow:ColorPicker(L['Latency Color'], {
            width = 0.5,
            tooltip = L["Shown while the cast trigger's Show Latency is on."],
            value = style.LatencyColor,
            mixed = mixed({ 'LatencyColor' }),
            callback = function(r, g, b, a) set({ 'LatencyColor' }, { r, g, b, a }) end,
        })
    end
end

---@param card table
---@param page table
---@param style table read side
---@param set fun(path: string[], value: any)
---@param mixed fun(path: (string|number)[], default: any?): KajiGUIMixedEntry[]? where the displays edited together disagree (DisplayTab.Differ)
local function SparkSettings(card, page, style, set, mixed)
    local function spark() return style.Spark == true or mixed({ 'Spark' }) end
    page:SetCondition('cdm:spark', spark)
    page:SetCondition('cdm:customSpark', function() return spark() and (style.UseGlobalSpark == false or mixed({ 'UseGlobalSpark' })) end)

    card:Row(rowH):Checkbox(L['Show Spark'], {
        width = 1,
        tooltip = L['Hidden while the bar is empty or full.'],
        value = style.Spark,
        mixed = mixed({ 'Spark' }),
        callback = function(checked)
            set({ 'Spark' }, checked)
            page:Refresh()
        end,
    })

    card:Separator(nil, { inSection = true })

    local sourceRow = card:Row(rowH)
    sourceRow:Checkbox(L['Use Global Spark'], {
        width = 0.5,
        conditions = { 'cdm:spark' },
        tooltip = L['The spark from the General page.'],
        value = style.UseGlobalSpark ~= false,
        mixed = mixed({ 'UseGlobalSpark' }),
        callback = function(checked)
            set({ 'UseGlobalSpark' }, checked)
            page:Refresh()
        end,
    })
    sourceRow:Dropdown(L['Texture'], {
        width = 0.5,
        media = 'spark',
        searchable = true,
        conditions = { 'cdm:customSpark' },
        value = style.SparkTexture,
        mixed = mixed({ 'SparkTexture' }),
        callback = function(key)
            local hadWidth = style.SparkTexture == 'Solid' or mixed({ 'SparkTexture' }) ~= nil
            set({ 'SparkTexture' }, key)
            if (key == 'Solid') ~= hadWidth then card:Rebuild() end
        end,
    })

    local sizeRow = card:Row(rowH)
    sizeRow:ColorPicker(L['Color'], {
        width = 0.5,
        conditions = { 'cdm:customSpark' },
        value = style.SparkColor,
        mixed = mixed({ 'SparkColor' }),
        callback = function(r, g, b, a) set({ 'SparkColor' }, { r, g, b, a }) end,
    })
    sizeRow:Slider(L['Scale'], {
        width = 0.5,
        conditions = { 'cdm:customSpark' },
        tooltip = L['Scales the spark against the bar height. Art sparks keep their own proportions.'],
        min = 0.5,
        max = 4,
        step = 0.05,
        value = style.SparkScale,
        mixed = mixed({ 'SparkScale' }),
        callback = function(value) set({ 'SparkScale' }, value) end,
        callbackOnRelease = true,
    })
    if style.SparkTexture == 'Solid' or mixed({ 'SparkTexture' }) then
        card:Row(rowH):Slider(L['Width'], {
            width = 1,
            conditions = { 'cdm:customSpark' },
            min = 1,
            max = 16,
            step = 1,
            value = style.SparkWidth,
            mixed = mixed({ 'SparkWidth' }),
            callback = function(value) set({ 'SparkWidth' }, value) end,
        })
    end
end

---Settings only a split power bar has: the spacing between its runes.
---@param card table
---@param style table read side
---@param set fun(path: string[], value: any)
---@param mixed fun(path: (string|number)[], default: any?): KajiGUIMixedEntry[]? where the displays edited together disagree (DisplayTab.Differ)
local function PipSettings(card, style, set, mixed)
    card:Row(rowH):Slider(L['Spacing'], {
        width = 1,
        min = 0,
        max = 20,
        step = 1,
        value = style.PipSpacing,
        mixed = mixed({ 'PipSpacing' }),
        callback = function(value) set({ 'PipSpacing' }, value) end,
    })
end

---@param card table
---@param page table
---@param style table read side
---@param set fun(path: string[], value: any)
---@param mixed fun(path: (string|number)[], default: any?): KajiGUIMixedEntry[]? where the displays edited together disagree (DisplayTab.Differ)
---@param refreshTree fun()
local function BarIconSettings(card, page, style, set, mixed, refreshTree)
    page:SetCondition('cdm:barIcon', function() return style.IconShow == true or mixed({ 'IconShow' }) end)
    local vertical = style.Orientation == 'VERTICAL'
    local side = style.IconSide
    if vertical and (side == 'LEFT' or side == 'RIGHT') then side = side == 'LEFT' and 'TOP' or 'BOTTOM' end
    if not vertical and (side == 'TOP' or side == 'BOTTOM') then side = side == 'TOP' and 'LEFT' or 'RIGHT' end

    local showRow = card:Row(rowH)
    showRow:Checkbox(L['Show Icon'], {
        width = 1,
        value = style.IconShow,
        mixed = mixed({ 'IconShow' }),
        callback = function(checked)
            set({ 'IconShow' }, checked)
            page:Refresh()
        end,
    })

    card:Separator(nil, { inSection = true })

    local sourceRow = card:Row(rowH)
    sourceRow:Dropdown(L['Icon Source'], {
        width = 0.5,
        conditions = { 'cdm:barIcon' },
        options = ICON_SOURCES,
        value = style.IconSource,
        mixed = mixed({ 'IconSource' }),
        callback = function(value)
            set({ 'IconSource' }, value)
            refreshTree()
            page:Refresh()
        end,
    })
    sourceRow:EditBox(L['Manual Icon'], {
        width = 0.4,
        conditions = { 'cdm:barIcon' },
        tooltip = L['An icon file ID. Automatic uses it for triggers without an icon of their own, such as Player Stat.'],
        value = style.ManualIcon and tostring(style.ManualIcon) or '',
        mixed = mixed({ 'ManualIcon' }),
        callback = function(text)
            set({ 'ManualIcon' }, tonumber(text))
            refreshTree()
        end,
    })
    IconPicker:BrowseButton(sourceRow, style.ManualIcon, function()
        IconPicker:Open(style.ManualIcon, function(texture)
            set({ 'ManualIcon' }, texture)
            refreshTree()
        end)
    end, { 'cdm:barIcon' })
    local sideRow = card:Row(rowH)
    sideRow:Dropdown(L['Icon Side'], {
        width = 0.5,
        conditions = { 'cdm:barIcon' },
        options = ICON_SIDES[vertical and 'VERTICAL' or 'HORIZONTAL'],
        value = side,
        mixed = mixed({ 'IconSide' }),
        callback = function(value) set({ 'IconSide' }, value) end,
    })
    sideRow:ColorPicker(L['Icon Color'], {
        width = 0.5,
        conditions = { 'cdm:barIcon' },
        value = style.Color,
        mixed = mixed({ 'Color' }),
        callback = function(r, g, b, a) set({ 'Color' }, { r, g, b, a }) end,
    })

    local lookRow = card:Row(rowH)
    lookRow:Checkbox(L['Desaturate'], {
        width = 0.5,
        conditions = { 'cdm:barIcon' },
        value = style.Desaturate,
        mixed = mixed({ 'Desaturate' }),
        callback = function(checked) set({ 'Desaturate' }, checked) end,
    })
    lookRow:Slider(L['Zoom'], {
        width = 0.5,
        conditions = { 'cdm:barIcon' },
        min = 0,
        max = 1,
        step = 0.01,
        value = style.Zoom or NRSKNUI.GlobalZoom,
        mixed = mixed({ 'Zoom' }, NRSKNUI.GlobalZoom),
        callback = function(value) set({ 'Zoom' }, value) end,
    })
end

DisplayTab.BarColorSettings = BarColorSettings
DisplayTab.BarIconSettings = BarIconSettings
DisplayTab.BarSettings = BarSettings
DisplayTab.PipSettings = PipSettings
DisplayTab.SparkSettings = SparkSettings
DisplayTab.SplitPower = SplitPower

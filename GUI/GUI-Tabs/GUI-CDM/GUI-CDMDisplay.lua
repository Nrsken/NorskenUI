---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local IconPicker = NRSKNUI.CDMIconPicker
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local tinsert, tremove = table.insert, table.remove
local ipairs, pairs = ipairs, pairs
local format = string.format
local CopyTable = CopyTable
local tostring = tostring
local tonumber = tonumber
local type = type
local min = math.min
local tsort = table.sort

local SUB_INDENT = 12
-- The label is centred in its row and the row keeps the default gap after it, so a heading sits midway between its neighbours.
local HEADING_HEIGHT = 26

local SUBREGION_NAMES = { text = L['Text'], border = L['Border'], glow = L['Glow'], tick = L['Tick'] }
local TICK_PLACEMENTS = {
    { value = 'auto',    text = L['Automatic'] },
    { value = 'value',   text = L['At Value'] },
    { value = 'percent', text = L['At Percent'] },
}
local GLOW_TYPES = {
    { value = 'pixel',    text = L['Pixel Glow'] },
    { value = 'button',   text = L['Action Button Glow'] },
    { value = 'autocast', text = L['Auto-Cast Shine'] },
    { value = 'gcd',      text = L['GCD Glow'] },
    { value = 'modern',   text = L['Modern WoW Glow'] },
    { value = 'classic',  text = L['Classic WoW Glow'] },
}
local GLOW_COLOR_MODES = {
    { value = 'default', text = L['Default'] },
    { value = 'class',   text = L['Class Color'] },
    { value = 'custom',  text = L['Custom'] },
}
local ICON_SOURCES = {
    { value = 'auto',   text = L['Automatic'] },
    { value = 'manual', text = L['Manual'] },
}
local ANCHOR_POINTS = {
    { value = 'TOPLEFT',     text = L['Top Left'] },
    { value = 'TOP',         text = L['Top'] },
    { value = 'TOPRIGHT',    text = L['Top Right'] },
    { value = 'LEFT',        text = L['Left'] },
    { value = 'CENTER',      text = L['Center'] },
    { value = 'RIGHT',       text = L['Right'] },
    { value = 'BOTTOMLEFT',  text = L['Bottom Left'] },
    { value = 'BOTTOM',      text = L['Bottom'] },
    { value = 'BOTTOMRIGHT', text = L['Bottom Right'] },
}
local TEXT_SELF_POINTS = { { value = 'AUTO', text = L['Automatic'] } }
for _, point in ipairs(ANCHOR_POINTS) do TEXT_SELF_POINTS[#TEXT_SELF_POINTS + 1] = point end
local TIME_FORMATS = {
    { value = 'global', text = L['Global'] },
    { value = 'custom', text = L['Custom'] },
}
local NUMBER_FORMATS = {
    { value = 'auto',       text = L['Automatic'] },
    { value = 'decimals',   text = L['Decimals'] },
    { value = 'abbreviate', text = L['Short'] },
    { value = 'large',      text = L['Short (Large)'] },
    { value = 'breakup',    text = L['Separated (12,345)'] },
}
local PRECISIONS = {
    { value = 1, text = '12.3' },
    { value = 2, text = '12.34' },
}
local TEXT_ROTATIONS = {
    { value = 'NONE',  text = L['None'] },
    { value = 'LEFT',  text = L['Left'] },
    { value = 'RIGHT', text = L['Right'] },
}
local TEXT_JUSTIFY = {
    { value = 'AUTO',   text = L['Automatic'] },
    { value = 'LEFT',   text = L['Left'] },
    { value = 'CENTER', text = L['Center'] },
    { value = 'RIGHT',  text = L['Right'] },
}
local TEXT_ALIGNMENTS = { TEXT_JUSTIFY[2], TEXT_JUSTIFY[3], TEXT_JUSTIFY[4] } -- a text display has no anchor to follow
local WIDTH_MODES = {
    { value = 'auto',  text = L['Automatic'] },
    { value = 'fixed', text = L['Fixed'] },
}
local STRATA = {
    { value = 'INHERIT',           text = L['Inherited'] },
    { value = 'BACKGROUND',        text = L['Background'] },
    { value = 'LOW',               text = L['Low'] },
    { value = 'MEDIUM',            text = L['Medium'] },
    { value = 'HIGH',              text = L['High'] },
    { value = 'DIALOG',            text = L['Dialog'] },
    { value = 'FULLSCREEN',        text = L['Fullscreen'] },
    { value = 'FULLSCREEN_DIALOG', text = L['Fullscreen Dialog'] },
    { value = 'TOOLTIP',           text = L['Tooltip'] },
}
local BAR_COLOR_MODES = {
    { value = 'custom', text = L['Custom'] },
    { value = 'class',  text = L['Class Color'] },
    { value = 'power',  text = L['Power Color'] },
}
-- WeakAuras' bar directions, named for the way a draining timer moves; its vertical fill hangs from the top.
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
local MATCH_SIDES = {
    { value = 'BELOW', text = L['Below'] },
    { value = 'ABOVE', text = L['Above'] },
}
local TEXT_TOKENS = {
    { '%p', L['Time left'] },
    { '%t', L['Total time'] },
    { '%s', L['Charges'] },
    { '%n', L['Spell name'] },
    { '%i', L['Spell icon'] },
    { '%%', L['A percent sign'] },
    { '\\n', L['New line'] },
    { '{rt1}', L['Raid marker 1 to 8'] },
}

-- Sections and sub-sections start closed, Icon Settings aside; what the user opens or closes holds for the session.
local sectionOpen = { icon = true, bar = true, text = true } -- [section key] = true
local subOpen = {}                              -- [sub-section key] = true

---@class NRSKNUI.CDMDisplayTab
local DisplayTab = {}
NRSKNUI.CDMDisplayTab = DisplayTab

---The centred heading between the Display card's sections.
---@param card table
---@param title string
function DisplayTab.Heading(card, title)
    card:Separator(title, { useLabel = true, centered = true, height = HEADING_HEIGHT })
end

---Write a value at a path, copying nested tables before their first edit so two icons never share one.
---@param target table
---@param path string[]
---@param value any
local function Assign(target, path, value)
    local node = target
    for i = 1, #path - 1 do
        local key = path[i]
        node[key] = CopyTable(node[key] or {})
        node = node[key]
    end
    node[path[#path]] = type(value) == 'table' and CopyTable(value) or value
end

---@param tooltip GameTooltip
local function DisplayTextTooltip(tooltip)
    local accent, secondary = Theme.accent, Theme.textSecondary
    tooltip:SetText(L['Display Text'], accent[1], accent[2], accent[3], 1, false)
    for _, token in ipairs(TEXT_TOKENS) do
        tooltip:AddDoubleLine(token[1], token[2], accent[1], accent[2], accent[3], secondary[1], secondary[2], secondary[3])
    end
    tooltip:AddLine(' ')
    tooltip:AddLine(L["%p and %t can't share a text with %s."], secondary[1], secondary[2], secondary[3], true)
    tooltip:AddLine(L['On Power, %p is the value and %t the max; on Player Stat, %p is the percent and %t the rating.'], secondary[1], secondary[2], secondary[3], true)
    tooltip:AddLine(L['%2.p, %2.t or %2.s read Trigger 2 instead of the shown trigger. A text reads one trigger.'], secondary[1], secondary[2], secondary[3], true)
end

---A collapsible WeakAuras-style section, closed until opened. Its rows only exist while it is open.
---@param card table
---@param key string
---@param title string
---@param actions table?
---@return boolean expanded
local function Section(card, key, title, actions)
    local config = {
        key = key,
        collapsed = not sectionOpen[key],
        onToggle = function()
            sectionOpen[key] = not sectionOpen[key] or nil
            card:Rebuild()
        end,
    }
    for name, handler in pairs(actions or {}) do config[name] = handler end
    return card:Section(title, config)
end

---An indented, animated header for the less used settings inside a section, closed until opened.
---@param card table
---@param key string
---@param title string
---@param summary string? what the closed header says about its settings, as in WeakAuras
---@return boolean open
---@return KajiGUISectionHeader header
local function SubSection(card, key, title, summary)
    return card:SubSection(title, {
        key = key,
        summary = summary,
        indent = SUB_INDENT,
        collapsed = not subOpen[key],
        onToggle = function()
            subOpen[key] = not subOpen[key] or nil
            card:Rebuild()
        end,
    })
end

---Do all these icons hold the same kinds of sub element in the same order?
---@param icons table[]
---@return boolean
local function SameLayout(icons)
    local first = icons[1].SubRegions or {}
    for i = 2, #icons do
        local other = icons[i].SubRegions or {}
        if #other ~= #first then return false end
        for index, element in ipairs(first) do
            if other[index].type ~= element.type then return false end
        end
    end
    return true
end

-- Sections --

---@param card table
---@param page table
---@param style table read side
---@param set fun(path: string[], value: any)
---@param refreshTree fun() the sidebar shows the icon too
local function IconSettings(card, page, style, set, refreshTree)
    page:SetCondition('cdm:manualIcon', function() return style.IconSource == 'manual' end)

    card:Row(rowH):ColorPicker(L['Color'], {
        width = 1,
        value = style.Color,
        callback = function(r, g, b, a) set({ 'Color' }, { r, g, b, a }) end,
    })

    local sourceRow = card:Row(rowH)
    sourceRow:Dropdown(L['Icon Source'], {
        width = 0.5,
        options = ICON_SOURCES,
        value = style.IconSource,
        callback = function(value)
            set({ 'IconSource' }, value)
            refreshTree()
            page:Refresh()
        end,
    })
    sourceRow:EditBox(L['Manual Icon'], {
        width = 0.4,
        conditions = { 'cdm:manualIcon' },
        tooltip = L['An icon file ID.'],
        value = style.ManualIcon and tostring(style.ManualIcon) or '',
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
    end, { 'cdm:manualIcon' })

    local lookRow = card:Row(rowH)
    lookRow:Checkbox(L['Desaturate'], {
        width = 0.5,
        value = style.Desaturate,
        callback = function(checked) set({ 'Desaturate' }, checked) end,
    })
    lookRow:Slider(L['Zoom'], {
        width = 0.5,
        min = 0,
        max = 1,
        step = 0.01,
        value = style.Zoom or NRSKNUI.GlobalZoom,
        callback = function(value) set({ 'Zoom' }, value) end,
    })
    card:Row(rowH):Checkbox(L['Keep Aspect Ratio'], {
        width = 0.5,
        tooltip = L['Crop the icon to the frame shape instead of stretching it.'],
        value = style.KeepAspectRatio,
        callback = function(checked) set({ 'KeepAspectRatio' }, checked) end,
    })
end

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
---@param set fun(path: string[], value: any)
local function BarSettings(card, page, style, set)
    page:SetCondition('cdm:customBar', function() return style.UseGlobalBar == false end)

    local textureRow = card:Row(rowH)
    textureRow:Checkbox(L['Use Global Bar'], {
        width = 0.5,
        value = style.UseGlobalBar ~= false,
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
        callback = function(value)
            for _, option in ipairs(DIRECTIONS) do
                if option.value == value then
                    set({ 'Orientation' }, option.orientation)
                    set({ 'ReverseFill' }, option.reverse)
                end
            end
            card:Rebuild()
        end,
    })
    directionRow:Checkbox(L['Inverse'], {
        width = 0.5,
        value = style.Inverse,
        callback = function(checked) set({ 'Inverse' }, checked) end,
    })

    card:Row(rowH):Checkbox(L['Smooth'], {
        width = 0.5,
        tooltip = L['Ease the bar to a new value or a new cast instead of jumping.'],
        value = style.Smooth,
        callback = function(checked) set({ 'Smooth' }, checked) end,
    })
end

---@param card table
---@param page table
---@param style table read side
---@param set fun(path: string[], value: any)
---@param displays table[] the bars being edited
local function BarColorSettings(card, page, style, set, displays)
    page:SetCondition('cdm:customBarColor', function() return style.BarColorMode ~= 'power' end)
    local hasCast = HasTrigger(displays, 'cast')

    local colorRow = card:Row(rowH)
    colorRow:Dropdown(L['Bar Color'], {
        width = 0.5,
        tooltip = L['Power Color follows the power type of a power trigger. Conditions can colour the bar per state, like a channel or an interrupted cast.'],
        options = BAR_COLOR_MODES,
        value = style.BarColorMode,
        callback = function(value)
            set({ 'BarColorMode' }, value)
            page:Refresh()
        end,
    })
    colorRow:ColorPicker(L['Custom Color'], {
        width = 0.5,
        conditions = { 'cdm:customBarColor' },
        value = style.BarColor,
        callback = function(r, g, b, a) set({ 'BarColor' }, { r, g, b, a }) end,
    })

    local backgroundRow = card:Row(rowH)
    backgroundRow:ColorPicker(L['Background Color'], {
        width = 0.5,
        value = style.BackgroundColor,
        callback = function(r, g, b, a) set({ 'BackgroundColor' }, { r, g, b, a }) end,
    })
    if hasCast then
        backgroundRow:ColorPicker(L['Latency Color'], {
            width = 0.5,
            tooltip = L["Shown while the cast trigger's Show Latency is on."],
            value = style.LatencyColor,
            callback = function(r, g, b, a) set({ 'LatencyColor' }, { r, g, b, a }) end,
        })
    end
end

---@param card table
---@param page table
---@param style table read side
---@param set fun(path: string[], value: any)
local function SparkSettings(card, page, style, set)
    page:SetCondition('cdm:spark', function() return style.Spark == true end)
    page:SetCondition('cdm:customSpark', function() return style.Spark == true and style.UseGlobalSpark == false end)

    card:Row(rowH):Checkbox(L['Show Spark'], {
        width = 1,
        tooltip = L['Hidden while the bar is empty or full.'],
        value = style.Spark,
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
        callback = function(key)
            local wasSolid = style.SparkTexture == 'Solid'
            set({ 'SparkTexture' }, key)
            if (key == 'Solid') ~= wasSolid then card:Rebuild() end
        end,
    })

    local sizeRow = card:Row(rowH)
    sizeRow:ColorPicker(L['Color'], {
        width = 0.5,
        conditions = { 'cdm:customSpark' },
        value = style.SparkColor,
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
        callback = function(value) set({ 'SparkScale' }, value) end,
        callbackOnRelease = true,
    })
    if style.SparkTexture == 'Solid' then
        card:Row(rowH):Slider(L['Width'], {
            width = 1,
            conditions = { 'cdm:customSpark' },
            min = 1,
            max = 16,
            step = 1,
            value = style.SparkWidth,
            callback = function(value) set({ 'SparkWidth' }, value) end,
        })
    end
end

---Settings only a split power bar has: the spacing between its runes.
---@param card table
---@param style table read side
---@param set fun(path: string[], value: any)
local function PipSettings(card, style, set)
    card:Row(rowH):Slider(L['Spacing'], {
        width = 1,
        min = 0,
        max = 20,
        step = 1,
        value = style.PipSpacing,
        callback = function(value) set({ 'PipSpacing' }, value) end,
    })
end

---@param card table
---@param page table
---@param style table read side
---@param set fun(path: string[], value: any)
---@param refreshTree fun()
local function BarIconSettings(card, page, style, set, refreshTree)
    page:SetCondition('cdm:barIcon', function() return style.IconShow == true end)
    page:SetCondition('cdm:manualIcon', function() return style.IconShow == true and style.IconSource == 'manual' end)
    local vertical = style.Orientation == 'VERTICAL'
    local side = style.IconSide
    if vertical and (side == 'LEFT' or side == 'RIGHT') then side = side == 'LEFT' and 'TOP' or 'BOTTOM' end
    if not vertical and (side == 'TOP' or side == 'BOTTOM') then side = side == 'TOP' and 'LEFT' or 'RIGHT' end

    local showRow = card:Row(rowH)
    showRow:Checkbox(L['Show Icon'], {
        width = 1,
        value = style.IconShow,
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
        callback = function(value)
            set({ 'IconSource' }, value)
            refreshTree()
            page:Refresh()
        end,
    })
    sourceRow:EditBox(L['Manual Icon'], {
        width = 0.4,
        conditions = { 'cdm:manualIcon' },
        tooltip = L['An icon file ID.'],
        value = style.ManualIcon and tostring(style.ManualIcon) or '',
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
    end, { 'cdm:manualIcon' })
    local sideRow = card:Row(rowH)
    sideRow:Dropdown(L['Icon Side'], {
        width = 0.5,
        conditions = { 'cdm:barIcon' },
        options = ICON_SIDES[vertical and 'VERTICAL' or 'HORIZONTAL'],
        value = side,
        callback = function(value) set({ 'IconSide' }, value) end,
    })
    sideRow:ColorPicker(L['Icon Color'], {
        width = 0.5,
        conditions = { 'cdm:barIcon' },
        value = style.Color,
        callback = function(r, g, b, a) set({ 'Color' }, { r, g, b, a }) end,
    })

    local lookRow = card:Row(rowH)
    lookRow:Checkbox(L['Desaturate'], {
        width = 0.5,
        conditions = { 'cdm:barIcon' },
        value = style.Desaturate,
        callback = function(checked) set({ 'Desaturate' }, checked) end,
    })
    lookRow:Slider(L['Zoom'], {
        width = 0.5,
        conditions = { 'cdm:barIcon' },
        min = 0,
        max = 1,
        step = 0.01,
        value = style.Zoom or NRSKNUI.GlobalZoom,
        callback = function(value) set({ 'Zoom' }, value) end,
    })
end

---@param card table
---@param style table read side
---@param set fun(path: string[], value: any)
---@param isBar boolean
local function GeneralSettings(card, style, set, isBar)
    local row = card:Row(rowH)
    row:Slider(L['Alpha'], {
        width = 0.5,
        min = 0,
        max = 1,
        step = 0.05,
        value = style.Alpha,
        callback = function(value) set({ 'Alpha' }, value) end,
    })
    row:Checkbox(L['Tooltip on Mouseover'], {
        width = 0.5,
        tooltip = isBar and L["The bar's spell or item; power bars have none."] or nil,
        value = style.Tooltip,
        callback = function(checked) set({ 'Tooltip' }, checked) end,
    })
end

---WeakAuras' swipe overlay grid.
---@param card table
---@param page table
---@param style table
---@param set fun(path: string[], value: any)
local function SwipeSettings(card, page, style, set)
    page:SetCondition('cdm:swipe', function() return style.DrawSwipe == true end)
    local row1 = card:Row(rowH)
    row1:Checkbox(L['Enable Swipe'], {
        width = 0.5,
        value = style.DrawSwipe,
        callback = function(checked)
            set({ 'DrawSwipe' }, checked)
            page:Refresh()
        end,
    })
    row1:Checkbox(L['Inverse'], {
        width = 0.5,
        conditions = { 'cdm:swipe' },
        value = style.Reverse,
        callback = function(checked) set({ 'Reverse' }, checked) end,
    })

    local row2 = card:Row(rowH)
    row2:Checkbox(L['Show Edge'], {
        width = 0.5,
        conditions = { 'cdm:swipe' },
        value = style.DrawEdge,
        callback = function(checked) set({ 'DrawEdge' }, checked) end,
    })
    row2:Checkbox(L['Show Global Cooldown'], {
        width = 0.5,
        conditions = { 'cdm:swipe' },
        tooltip = L['Run the swipe for the global cooldown too.'],
        value = style.ShowGCD,
        callback = function(checked) set({ 'ShowGCD' }, checked) end,
    })

    local row3 = card:Row(rowH)
    row3:Checkbox(L['Hide Timer Text'], {
        width = 0.5,
        tooltip = L["Hides the game's own cooldown numbers; a text with %p shows the time instead."],
        value = style.HideCountdown,
        callback = function(checked) set({ 'HideCountdown' }, checked) end,
    })
    row3:ColorPicker(L['Swipe Color'], {
        width = 0.5,
        conditions = { 'cdm:swipe' },
        value = style.SwipeColor,
        callback = function(r, g, b, a) set({ 'SwipeColor' }, { r, g, b, a }) end,
    })
end

---@param card table
---@param page table
---@param style table
---@param set fun(path: string[], value: any)
---@param display table? the icon whose position this edits, nil when editing a group's icons together
---@param maxSize number
---@param noSize boolean? a text display fits its text
local function PositionAndSize(card, page, style, set, display, maxSize, noSize)
    page:SetCondition('cdm:unmatched', function() return not (display and display.MatchWidth) end)
    page:SetCondition('cdm:matched', function() return display ~= nil and display.MatchWidth ~= nil end)

    if display and display.type == 'bar' and not CDM:IsDynamic(display.parent) then
        local groups = {}
        for groupId, other in pairs(CDM.db.Displays) do
            if other.type == 'dynamicgroup' then groups[#groups + 1] = { value = groupId, text = other.name or groupId } end
        end
        table.sort(groups, function(x, y) return x.text < y.text end)
        tinsert(groups, 1, { value = 'none', text = L['None'] })

        local function match(key, value)
            display[key] = value
            CDM:ApplySettings()
            page:Refresh()
        end
        local matchRow = card:Row(rowH)
        matchRow:Dropdown(L['Match Width'], {
            width = 0.5,
            tooltip = L["Take a dynamic group's width and sit against it. The width follows the group as icons come and go."],
            options = groups,
            value = display.MatchWidth or 'none',
            callback = function(value) match('MatchWidth', value ~= 'none' and value or nil) end,
        })
        matchRow:Dropdown(L['Attach'], {
            width = 0.5,
            conditions = { 'cdm:matched' },
            options = MATCH_SIDES,
            value = display.MatchSide or 'BELOW',
            callback = function(value) match('MatchSide', value) end,
        })
        card:Row(rowH):Slider(L['Gap'], {
            width = 1,
            conditions = { 'cdm:matched' },
            min = -1000,
            max = 1000,
            step = 1,
            value = display.MatchGap or 0,
            callback = function(value) match('MatchGap', value) end,
        })
        card:Separator(nil, { inSection = true })
    end

    if not noSize then
        local sizeRow = card:Row(rowH)
        sizeRow:Slider(L['Width'], {
            width = 0.5,
            conditions = { 'cdm:unmatched' },
            min = 8,
            max = maxSize,
            step = 1,
            value = style.Width,
            callback = function(value) set({ 'Width' }, value) end,
        })
        sizeRow:Slider(L['Height'], {
            width = 0.5,
            min = 2,
            max = maxSize,
            step = 1,
            value = style.Height,
            callback = function(value) set({ 'Height' }, value) end,
        })
    end
    if not display then return end

    -- A dynamic group places its icons itself, a matched bar sits on its group; elsewhere an icon has its own offsets.
    page:SetCondition('cdm:freePosition', function() return not CDM:IsDynamic(display.parent) and not display.MatchWidth end)

    local function place(path, value)
        Assign(display, path, value)
        CDM:ApplySettings(CDM:IsGroup(display.parent) and display.parent or nil)
    end

    local position = display.Position
    local offsetRow = card:Row(rowH)
    offsetRow:Slider(L['X Offset'], {
        width = 0.5,
        conditions = { 'cdm:freePosition' },
        min = -1000,
        max = 1000,
        step = 1,
        value = position.XOffset,
        callback = function(value) place({ 'Position', 'XOffset' }, value) end,
    })
    offsetRow:Slider(L['Y Offset'], {
        width = 0.5,
        conditions = { 'cdm:freePosition' },
        min = -1000,
        max = 1000,
        step = 1,
        value = position.YOffset,
        callback = function(value) place({ 'Position', 'YOffset' }, value) end,
    })

    card:Row(rowH):Dropdown(L['Frame Strata'], {
        width = 1,
        conditions = { 'cdm:freePosition' },
        options = STRATA,
        value = display.Strata or 'INHERIT',
        callback = function(value) place({ 'Strata' }, value ~= 'INHERIT' and value or nil) end,
    })
end

---@param card table
---@param page table
---@param element table read side
---@param set fun(path: string[], value: any)
---@param key string unique per element, for its conditions and sub-sections
---@param triggers table[] the icon's triggers, which %N.p tokens point into
---@param pipName string? a split power bar's "Rune", whose texts can repeat on each one
---@param main boolean? a text display's own text: always shown, pinned at its alignment, no rotation
local function TextRows(card, page, element, set, key, triggers, pipName, main)
    local shown, customFont, shadow = key .. ':shown', key .. ':font', key .. ':shadow'
    local customTime, decimals, fixedWidth = key .. ':time', key .. ':decimals', key .. ':fixed'
    page:SetCondition(shown, function() return element.Enabled == true end)
    page:SetCondition(customFont, function() return element.UseGlobalFont ~= true end)
    page:SetCondition(shadow, function() return element.FontShadow.Enabled == true end)
    page:SetCondition(customTime, function() return element.TimeFormat == 'custom' end)
    page:SetCondition(decimals, function() return element.TimeFormat == 'custom' and element.PrecisionBelow > 0 end)
    page:SetCondition(fixedWidth, function() return element.WidthMode == 'fixed' end)

    local textRow = card:Row(rowH)
    if not main then
        textRow:Checkbox(L['Show Text'], {
            width = 0.5,
            value = element.Enabled,
            callback = function(checked)
                set({ 'Enabled' }, checked)
                page:Refresh()
            end,
        })
    end
    textRow:EditBox(L['Display Text'], {
        width = main and 1 or 0.5,
        conditions = { shown },
        tooltip = DisplayTextTooltip,
        value = element.Text,
        callback = function(text)
            set({ 'Text' }, text)
            card:Rebuild()
        end,
    })
    if pipName then
        card:Row(rowH):Checkbox(format(L['Each %s'], pipName), {
            width = 0.5,
            conditions = { shown },
            tooltip = format(L['Repeat the text on every %s.'], pipName),
            value = element.EachPip,
            callback = function(checked) set({ 'EachPip' }, checked or nil) end,
        })
    end

    local hasDuration, hasCharges, source = CDM:ClassifyText(element.Text or '')
    if hasDuration and hasCharges then
        card:Row(rowH):Text(nil, {
            width = 1,
            text = L["%s is dropped here: a time and a charge count can't share one text. Add a second text for it."],
            bgMode = 'hide',
        })
    end
    local sourceTrigger = source and triggers[source]
    local sourceNote
    if source and not sourceTrigger then
        sourceNote = format(L["There's no Trigger %d, so this text stays empty."], source)
    elseif sourceTrigger and (sourceTrigger.Type == 'aura' or sourceTrigger.Type == 'auraoverlay') then
        sourceNote = format(L['Only shows on the Trigger %d overlay.'], source)
    end
    if sourceNote then
        card:Row(rowH):Text(nil, { width = 1, text = sourceNote, bgMode = 'hide' })
    end

    local fontRow = card:Row(rowH)
    fontRow:Checkbox(L['Use Global Font'], {
        width = 0.5,
        conditions = { shown },
        value = element.UseGlobalFont,
        callback = function(checked)
            set({ 'UseGlobalFont' }, checked)
            page:Refresh()
        end,
    })
    fontRow:Dropdown(L['Font'], {
        width = 0.5,
        media = 'font',
        conditions = { shown, customFont },
        value = element.FontFace,
        callback = function(value) set({ 'FontFace' }, value) end,
    })

    local sizeRow = card:Row(rowH)
    sizeRow:Slider(L['Size'], {
        width = 0.5,
        conditions = { shown },
        min = 6,
        max = main and 72 or 40,
        step = 1,
        value = element.FontSize,
        callback = function(value) set({ 'FontSize' }, value) end,
    })
    sizeRow:Dropdown(L['Outline'], {
        width = 0.5,
        conditions = { shown },
        options = NRSKNUI:GetOutlineOptions(),
        value = element.FontOutline,
        callback = function(value) set({ 'FontOutline' }, value) end,
    })

    card:Row(rowH):ColorPicker(L['Color'], {
        width = 0.5,
        conditions = { shown },
        value = element.Color,
        callback = function(r, g, b, a) set({ 'Color' }, { r, g, b, a }) end,
    })

    -- What %p/%t stand for: a time on most triggers, a value on Power and Stat. A plain token reads every layer's own trigger.
    local readsTime, readsValue, readsPower = false, false, false
    for index, trigger in ipairs(triggers) do
        if not source or index == source then
            local triggerType = CDM.TriggerTypes[trigger.Type]
            if triggerType and triggerType.Value then
                readsValue = hasDuration or hasCharges
                readsPower = readsPower or (readsValue and trigger.Type == 'power')
            else
                readsTime = readsTime or hasDuration
            end
        end
    end
    page:SetCondition(key .. ':timeColor', function() return element.TimeColor ~= nil and element.TimeColor.Enabled == true end)
    page:SetCondition(key .. ':numberDecimals', function() return element.NumberFormat == 'decimals' end)
    page:SetCondition(key .. ':valueColor', function() return element.ValueColor ~= nil and element.ValueColor.Enabled == true end)

    -- WeakAuras' "Format for %p": only a text with a time or a value has anything to format.
    local formatOpen = (readsTime or readsValue) and SubSection(card, key .. ':format', L['Format Options'])
    if formatOpen and readsValue then
        local numberRow = card:Row(rowH, nil, SUB_INDENT)
        numberRow:Dropdown(L['Number Format'], {
            width = 0.5,
            conditions = { shown },
            tooltip = L['How a Power or Stat value reads. Automatic: whole numbers, as the character sheet shows them.'],
            options = NUMBER_FORMATS,
            value = element.NumberFormat or 'auto',
            callback = function(value)
                set({ 'NumberFormat' }, value)
                page:Refresh()
            end,
        })
        numberRow:Slider(L['Decimals'], {
            width = 0.5,
            conditions = { shown, key .. ':numberDecimals' },
            min = 0,
            max = 3,
            step = 1,
            value = element.Decimals or 1,
            callback = function(value) set({ 'Decimals' }, value) end,
        })
        if readsPower then
            local colorRow = card:Row(rowH, nil, SUB_INDENT)
            local valueColor = element.ValueColor or {}
            colorRow:Checkbox(L['Color by Value'], {
                width = 0.5,
                conditions = { shown },
                tooltip = L['Blend the text from one colour when empty to another when full.'],
                value = valueColor.Enabled == true,
                callback = function(checked)
                    set({ 'ValueColor', 'Enabled' }, checked)
                    page:Refresh()
                end,
            })
            colorRow:ColorPicker(L['Empty'], {
                width = 0.25,
                conditions = { shown, key .. ':valueColor' },
                value = valueColor.Low or { 1, 0.25, 0.25, 1 },
                callback = function(r, g, b, a) set({ 'ValueColor', 'Low' }, { r, g, b, a }) end,
            })
            colorRow:ColorPicker(L['Full'], {
                width = 0.25,
                conditions = { shown, key .. ':valueColor' },
                value = valueColor.High or { 0.25, 1, 0.25, 1 },
                callback = function(r, g, b, a) set({ 'ValueColor', 'High' }, { r, g, b, a }) end,
            })
        end
    end
    if formatOpen and readsTime then
        card:Row(rowH, nil, SUB_INDENT):Dropdown(L['Time Format'], {
            width = 0.5,
            conditions = { shown },
            tooltip = L['Global uses the duration breakpoints from the global settings.'],
            options = TIME_FORMATS,
            value = element.TimeFormat,
            callback = function(value)
                set({ 'TimeFormat' }, value)
                page:Refresh()
            end,
        })

        local precisionRow = card:Row(rowH, nil, SUB_INDENT)
        precisionRow:Slider(L['Increase Precision Below'], {
            width = 0.5,
            conditions = { shown, customTime },
            tooltip = L['Seconds left at which the time shows decimals. 0 never shows them.'],
            min = 0,
            max = 60,
            step = 1,
            value = element.PrecisionBelow,
            callback = function(value)
                set({ 'PrecisionBelow' }, value)
                page:Refresh()
            end,
        })
        precisionRow:Dropdown(L['Precision'], {
            width = 0.5,
            conditions = { shown, decimals },
            options = PRECISIONS,
            value = element.Precision,
            callback = function(value) set({ 'Precision' }, value) end,
        })

        card:Row(rowH, nil, SUB_INDENT):EditBox(L['Ready Text'], {
            width = 0.5,
            conditions = { shown },
            tooltip = L['Shown once the time has run out, e.g. READY. Empty shows nothing.'],
            value = element.ReadyText or '',
            callback = function(text) set({ 'ReadyText' }, text) end,
        })

        local timeColor = element.TimeColor or {}
        local timeColorRow = card:Row(rowH, nil, SUB_INDENT)
        timeColorRow:Checkbox(L['Color by Time Left'], {
            width = 0.5,
            conditions = { shown },
            value = timeColor.Enabled == true,
            callback = function(checked)
                set({ 'TimeColor', 'Enabled' }, checked)
                page:Refresh()
            end,
        })
        timeColorRow:ColorPicker(L['Color'], {
            width = 0.5,
            conditions = { shown, key .. ':timeColor' },
            value = timeColor.Color or { 1, 0.25, 0.25, 1 },
            callback = function(r, g, b, a) set({ 'TimeColor', 'Color' }, { r, g, b, a }) end,
        })
        card:Row(rowH, nil, SUB_INDENT):Slider(L['Below Seconds'], {
            width = 0.5,
            conditions = { shown, key .. ':timeColor' },
            tooltip = L["The text takes this colour once less time than this is left. The game's own curve does it, so it works in combat too."],
            min = 1,
            max = 60,
            step = 0.5,
            value = timeColor.Below or 3,
            callback = function(value) set({ 'TimeColor', 'Below' }, value) end,
        })
    end

    local fontShadow = element.FontShadow
    local function FlagsSummary()
        if not fontShadow.Enabled then return L['None'] end
        local c = fontShadow.Color
        local swatch = format('|cff%02x%02x%02x%s|r', c[1] * 255, c[2] * 255, c[3] * 255, L['Color'])
        return format(L['Shadow %s with offset %d/%d'], swatch, fontShadow.OffsetX, fontShadow.OffsetY)
    end
    local flagsOpen, flagsHeader = SubSection(card, key .. ':shadow', L['Font Flags'], FlagsSummary())
    local function setShadow(path, value)
        set(path, value)
        flagsHeader:SetSummary(FlagsSummary())
    end
    if flagsOpen then
        local toggleRow = card:Row(rowH, nil, SUB_INDENT)
        toggleRow:Checkbox(L['Shadow'], {
            width = 0.5,
            conditions = { shown },
            value = fontShadow.Enabled,
            callback = function(checked)
                setShadow({ 'FontShadow', 'Enabled' }, checked)
                page:Refresh()
            end,
        })
        toggleRow:ColorPicker(L['Shadow Color'], {
            width = 0.5,
            conditions = { shown, shadow },
            value = fontShadow.Color,
            callback = function(r, g, b, a) setShadow({ 'FontShadow', 'Color' }, { r, g, b, a }) end,
        })

        local offsetRow = card:Row(rowH, nil, SUB_INDENT)
        offsetRow:Slider(L['Shadow X'], {
            width = 0.5,
            conditions = { shown, shadow },
            min = -5,
            max = 5,
            step = 1,
            value = fontShadow.OffsetX,
            callback = function(value) setShadow({ 'FontShadow', 'OffsetX' }, value) end,
        })
        offsetRow:Slider(L['Shadow Y'], {
            width = 0.5,
            conditions = { shown, shadow },
            min = -5,
            max = 5,
            step = 1,
            value = fontShadow.OffsetY,
            callback = function(value) setShadow({ 'FontShadow', 'OffsetY' }, value) end,
        })

        local alignRow = card:Row(rowH, nil, SUB_INDENT)
        if not main then
            alignRow:Dropdown(L['Rotate Text'], {
                width = 0.5,
                conditions = { shown },
                options = TEXT_ROTATIONS,
                value = element.Rotation,
                callback = function(value) set({ 'Rotation' }, value) end,
            })
        end
        alignRow:Dropdown(L['Alignment'], {
            width = 0.5,
            conditions = { shown },
            tooltip = main and L['The side the text grows from, and how its lines line up.'] or L['Automatic aligns the text to the side it is anchored on.'],
            options = main and TEXT_ALIGNMENTS or TEXT_JUSTIFY,
            value = element.Justify,
            callback = function(value) set({ 'Justify' }, value) end,
        })

        local widthRow = card:Row(rowH, nil, SUB_INDENT)
        widthRow:Dropdown(L['Width'], {
            width = 0.5,
            conditions = { shown },
            options = WIDTH_MODES,
            value = element.WidthMode,
            callback = function(value)
                set({ 'WidthMode' }, value)
                page:Refresh()
            end,
        })
        widthRow:Slider(L['Fixed Width'], {
            width = 0.5,
            conditions = { shown, fixedWidth },
            min = 8,
            max = 256,
            step = 1,
            value = element.FixedWidth,
            callback = function(value) set({ 'FixedWidth' }, value) end,
        })
        card:Row(rowH, nil, SUB_INDENT):Checkbox(L['Word Wrap'], {
            width = 0.5,
            conditions = { shown, fixedWidth },
            tooltip = L['Off cuts a text longer than the width short instead of wrapping it.'],
            value = element.WordWrap,
            callback = function(checked) set({ 'WordWrap' }, checked) end,
        })
    end
    if main then return end

    local position = element.Position
    local function AnchorSummary()
        local pointName = position.AnchorTo
        for _, point in ipairs(ANCHOR_POINTS) do
            if point.value == position.AnchorTo then pointName = point.text end
        end
        local summary = format(L["Anchored to frame's %s"], pointName)
        if position.XOffset == 0 and position.YOffset == 0 then return summary end
        return format(L['%s with offset %d/%d'], summary, position.XOffset, position.YOffset)
    end
    local anchorOpen, anchorHeader = SubSection(card, key .. ':anchor', L['Anchors'], AnchorSummary())
    local function setPosition(path, value)
        set(path, value)
        anchorHeader:SetSummary(AnchorSummary())
    end
    if anchorOpen then
        local pointRow = card:Row(rowH, nil, SUB_INDENT)
        pointRow:Dropdown(L['Anchor'], {
            width = 0.5,
            conditions = { shown },
            tooltip = L["The text's own point. Automatic keeps the text inside the icon at the frame's point."],
            options = TEXT_SELF_POINTS,
            value = position.AnchorFrom,
            callback = function(point) setPosition({ 'Position', 'AnchorFrom' }, point) end,
        })
        pointRow:Dropdown(L["To Frame's"], {
            width = 0.5,
            conditions = { shown },
            options = ANCHOR_POINTS,
            value = position.AnchorTo,
            callback = function(point) setPosition({ 'Position', 'AnchorTo' }, point) end,
        })

        local offsetRow = card:Row(rowH, nil, SUB_INDENT)
        offsetRow:Slider(L['X Offset'], {
            width = 0.5,
            conditions = { shown },
            min = -40,
            max = 40,
            step = 1,
            value = position.XOffset,
            callback = function(value) setPosition({ 'Position', 'XOffset' }, value) end,
        })
        offsetRow:Slider(L['Y Offset'], {
            width = 0.5,
            conditions = { shown },
            min = -40,
            max = 40,
            step = 1,
            value = position.YOffset,
            callback = function(value) setPosition({ 'Position', 'YOffset' }, value) end,
        })
    end
end

---@param card table
---@param page table
---@param element table
---@param set fun(path: string[], value: any)
---@param key string
---@param pipName string? a split power bar's "Rune", whose borders can repeat on each one
local function BorderRows(card, page, element, set, key, pipName)
    local shown = key .. ':shown'
    page:SetCondition(shown, function() return element.Enabled == true end)

    local showRow = card:Row(rowH)
    showRow:Checkbox(L['Show Border'], {
        width = pipName and 0.5 or 1,
        value = element.Enabled,
        callback = function(checked)
            set({ 'Enabled' }, checked)
            page:Refresh()
        end,
    })
    if pipName then
        showRow:Checkbox(format(L['Each %s'], pipName), {
            width = 0.5,
            conditions = { shown },
            tooltip = format(L['Outline every %s instead of the whole bar.'], pipName),
            value = element.EachPip,
            callback = function(checked) set({ 'EachPip' }, checked or nil) end,
        })
    end

    card:Row(rowH):ColorPicker(L['Border Color'], {
        width = 1,
        conditions = { shown },
        value = element.Color,
        callback = function(r, g, b, a) set({ 'Color' }, { r, g, b, a }) end,
    })

    local sizeRow = card:Row(rowH)
    sizeRow:Slider(L['Border Size'], {
        width = 0.5,
        conditions = { shown },
        min = 1,
        max = 16,
        step = 1,
        value = element.Size,
        callback = function(value) set({ 'Size' }, value) end,
    })
    sizeRow:Slider(L['Border Offset'], {
        width = 0.5,
        conditions = { shown },
        min = -10,
        max = 10,
        step = 1,
        value = element.Offset,
        callback = function(value) set({ 'Offset' }, value) end,
    })
end

---@param card table
---@param page table
---@param element table read side
---@param set fun(path: string[], value: any)
---@param key string
local function TickRows(card, page, element, set, key)
    local shown, placed, manualLength = key .. ':shown', key .. ':placed', key .. ':length'
    page:SetCondition(shown, function() return element.Enabled == true end)
    page:SetCondition(placed, function() return element.Enabled == true and element.Placement ~= 'auto' end)
    page:SetCondition(manualLength, function() return element.Enabled == true and not element.AutoLength end)

    local showRow = card:Row(rowH)
    showRow:Checkbox(L['Show Tick'], {
        width = 0.5,
        value = element.Enabled,
        callback = function(checked)
            set({ 'Enabled' }, checked)
            page:Refresh()
        end,
    })
    showRow:ColorPicker(L['Tick Color'], {
        width = 0.5,
        conditions = { shown },
        value = element.Color,
        callback = function(r, g, b, a) set({ 'Color' }, { r, g, b, a }) end,
    })

    local placeRow = card:Row(rowH)
    placeRow:Dropdown(L['Placement'], {
        width = 0.5,
        conditions = { shown },
        tooltip = L['Automatic splits combo points, chi and other point resources into segments, and marks channel ticks and empower stages. At Value counts power, or seconds into a cast.'],
        options = TICK_PLACEMENTS,
        value = element.Placement,
        callback = function(value)
            set({ 'Placement' }, value)
            page:Refresh()
        end,
    })
    placeRow:EditBox(L['Placements'], {
        width = 0.5,
        conditions = { placed },
        tooltip = L['One or more values, comma separated.'],
        value = element.Placements,
        callback = function(text) set({ 'Placements' }, text) end,
    })

    local sizeRow = card:Row(rowH)
    sizeRow:Slider(L['Thickness'], {
        width = 0.5,
        conditions = { shown },
        min = 1,
        max = 10,
        step = 1,
        value = element.Thickness,
        callback = function(value) set({ 'Thickness' }, value) end,
    })
    sizeRow:Checkbox(L['Automatic Length'], {
        width = 0.5,
        conditions = { shown },
        tooltip = L['Spans the whole bar.'],
        value = element.AutoLength,
        callback = function(checked)
            set({ 'AutoLength' }, checked)
            page:Refresh()
        end,
    })
    card:Row(rowH):Slider(L['Length'], {
        width = 0.5,
        conditions = { manualLength },
        min = 1,
        max = 100,
        step = 1,
        value = element.Length,
        callback = function(value) set({ 'Length' }, value) end,
    })
end

-- A glow is hidden until a condition shows it, so its settings stay editable while Show Glow is off.
---@param card table
---@param element table
---@param set fun(path: string[], value: any)
local function GlowRows(card, element, set)
    card:Row(rowH):Checkbox(L['Show Glow'], {
        width = 1,
        tooltip = L['Shows the glow all the time. Leave it off and let a condition show it, like Proc Glow.'],
        value = element.Enabled,
        callback = function(checked) set({ 'Enabled' }, checked) end,
    })

    local typeRow = card:Row(rowH)
    typeRow:Dropdown(L['Glow Type'], {
        width = 0.5,
        options = GLOW_TYPES,
        value = element.Type,
        callback = function(value)
            set({ 'Type' }, value)
            card:Rebuild()
        end,
    })
    typeRow:Dropdown(L['Glow Color'], {
        width = 0.5,
        options = GLOW_COLOR_MODES,
        value = element.ColorMode,
        callback = function(value)
            set({ 'ColorMode' }, value)
            card:Rebuild()
        end,
    })
    if element.ColorMode == 'custom' then
        card:Row(rowH):ColorPicker(L['Color'], {
            width = 0.5,
            value = element.Color,
            callback = function(r, g, b, a) set({ 'Color' }, { r, g, b, a }) end,
        })
    end

    if element.Type == 'pixel' then
        local defaults = CDM.GLOW_DEFAULTS -- glows made before these settings existed draw with the defaults
        card:Row(rowH):Slider(L['Speed'], {
            width = 0.5,
            min = 0.05,
            max = 1,
            step = 0.05,
            value = element.Frequency or defaults.Frequency,
            callback = function(value) set({ 'Frequency' }, value) end,
        })
        local linesRow = card:Row(rowH)
        linesRow:Slider(L['Lines'], {
            width = 0.5,
            min = 1,
            max = 16,
            step = 1,
            value = element.Lines,
            callback = function(value) set({ 'Lines' }, value) end,
        })
        linesRow:Slider(L['Length'], {
            width = 0.5,
            min = 1,
            max = 20,
            step = 1,
            value = element.Length or defaults.Length,
            callback = function(value) set({ 'Length' }, value) end,
        })
        local sizeRow = card:Row(rowH)
        sizeRow:Slider(L['Thickness'], {
            width = 0.5,
            min = 1,
            max = 8,
            step = 1,
            value = element.Thickness,
            callback = function(value) set({ 'Thickness' }, value) end,
        })
        sizeRow:Checkbox(L['Border'], {
            width = 0.5,
            tooltip = L['A dark band behind the lines.'],
            value = element.Border ~= false,
            callback = function(checked) set({ 'Border' }, checked) end,
        })
    elseif element.Type == 'modern' then
        card:Row(rowH):Checkbox(L['Start Animation'], {
            width = 0.5,
            tooltip = L["Plays Blizzard's proc burst when the glow starts."],
            value = element.StartAnim ~= false,
            callback = function(checked) set({ 'StartAnim' }, checked) end,
        })
    end
end

-- Sub elements --

---Move the overlays' slots along when element `index` goes (`by` -1) or a copy of it lands right under it (`by` 1).
---@param display table
---@param index number
---@param by number
local function ShiftSlots(display, index, by)
    for _, trigger in ipairs(display.Triggers or {}) do
        if trigger.Type == 'auraoverlay' and (trigger.Slot or 0) >= index then trigger.Slot = trigger.Slot + by end
    end
end

---@param card table
---@param page table
---@param icons table[]
---@param apply fun()
---@param triggerChip fun(index: number, trigger: table): string
local function SubElements(card, page, icons, apply, triggerChip)
    local first = icons[1]
    first.SubRegions = first.SubRegions or {}

    if not SameLayout(icons) then
        card:Row(rowH):Text(nil, { width = 1, text = L['These icons have different sub elements; edit them per icon.'], bgMode = 'hide' })
        return
    end

    local function Each(fn)
        for _, display in ipairs(icons) do
            display.SubRegions = display.SubRegions or {}
            fn(display.SubRegions, display)
        end
        apply()
        card:Rebuild()
    end

    local counts = {}
    local elements = first.SubRegions
    local pipName = CDM.PIP_NAMES[SplitPower(first) or false]

    -- The overlays sit in the list at their slot (one icon only: slots differ per icon), listed bottom layer first like the elements.
    local overlays = {}
    if #icons == 1 then
        for i, trigger in ipairs(first.Triggers) do
            if trigger.Type == 'auraoverlay' then overlays[#overlays + 1] = i end
        end
    end
    local function SlotOf(i) return min(first.Triggers[i].Slot or 0, #elements) end
    tsort(overlays, function(a, b)
        if SlotOf(a) ~= SlotOf(b) then return SlotOf(a) < SlotOf(b) end
        return a > b -- an earlier trigger draws on top, so it lists after
    end)
    local function Move(i, by)
        local trigger = first.Triggers[i]
        trigger.Slot = SlotOf(i) + by
        apply()
        card:Rebuild()
    end
    local function OverlayRows(slot)
        for _, i in ipairs(overlays) do
            if SlotOf(i) == slot then
                local key = 'cdm:overlay:' .. i
                if Section(card, key, L['Aura Overlay'], {
                        summary = triggerChip(i, first.Triggers[i]),
                        onMoveUp = slot > 0 and function() Move(i, -1) end or nil,
                        onMoveDown = slot < #elements and function() Move(i, 1) end or nil,
                    }) then
                    card:Row(rowH):Text(nil, {
                        width = 1,
                        text = L['Rows above draw under its Aura Icon.'],
                        bgMode = 'hide',
                    })
                end
            end
        end
    end
    -- The overlay row right above or below element `index`, which a move of that element crosses instead of swapping.
    local function Adjacent(slot, closestFirst)
        local found
        for _, i in ipairs(overlays) do
            if SlotOf(i) == slot and not (closestFirst and found) then found = i end
        end
        return found
    end

    OverlayRows(0)
    for index, element in ipairs(elements) do
        counts[element.type] = (counts[element.type] or 0) + 1
        local title = format('%s %d', SUBREGION_NAMES[element.type] or element.type, counts[element.type])
        local key = 'cdm:sub:' .. index .. ':' .. element.type

        local function set(path, value)
            for _, display in ipairs(icons) do Assign(display.SubRegions[index], path, value) end
            apply()
        end

        local above, below = Adjacent(index - 1, false), Adjacent(index, true)
        local expanded = Section(card, key, title, {
            onMoveUp = above and function() Move(above, 1) end or index > 1 and function()
                Each(function(list, display)
                    list[index], list[index - 1] = list[index - 1], list[index]
                    CDM:RemapConditionSubRegions(display, function(n) return n == index and index - 1 or n == index - 1 and index or n end)
                end)
            end or nil,
            onMoveDown = below and function() Move(below, -1) end or index < #elements and function()
                Each(function(list, display)
                    list[index], list[index + 1] = list[index + 1], list[index]
                    CDM:RemapConditionSubRegions(display, function(n) return n == index and index + 1 or n == index + 1 and index or n end)
                end)
            end or nil,
            onDuplicate = function()
                Each(function(list, display)
                    tinsert(list, index + 1, CopyTable(list[index]))
                    CDM:RemapConditionSubRegions(display, function(n) return n > index and n + 1 or n end)
                    ShiftSlots(display, index, 1)
                end)
            end,
            onDelete = function()
                Each(function(list, display)
                    tremove(list, index)
                    CDM:RemapConditionSubRegions(display, function(n)
                        if n == index then return nil end
                        return n > index and n - 1 or n
                    end)
                    ShiftSlots(display, index, -1)
                end)
            end,
        })

        if expanded then
            if element.type == 'text' then
                TextRows(card, page, element, set, key, first.Triggers, pipName)
            elseif element.type == 'border' then
                BorderRows(card, page, element, set, key, pipName)
            elseif element.type == 'glow' then
                GlowRows(card, element, set)
            elseif element.type == 'tick' then
                TickRows(card, page, element, set, key)
            end
            if index < #elements then card:Separator() end -- the last one meets the divider above the add buttons
        end
        OverlayRows(index)
    end
    card:EndSection()
    card:Separator()

    local btnH = 24
    local adds = { { 'text', L['Add Text'] }, { 'border', L['Add Border'] }, { 'glow', L['Add Glow'] } }
    if first.type == 'bar' then adds[#adds + 1] = { 'tick', L['Add Tick'] } end
    local addRow
    for i, add in ipairs(adds) do
        if i % 2 == 1 then addRow = card:Row(btnH) end
        addRow:Button(add[2], {
            width = (i % 2 == 1 and i == #adds) and 1 or 0.5, -- a button alone on its row fills it
            height = btnH,
            callback = function() Each(function(list) list[#list + 1] = CDM:NewSubRegion(add[1]) end) end,
        })
    end
end

---The Display tab for one icon, or every icon in a group at once (WeakAuras' group editing).
---Controls show the first icon's values; every change goes to all of them.
---@param page table
---@param iconIds string[]
---@param apply fun()
---@param refreshTree fun()
---@param triggerChip fun(index: number, trigger: table): string a trigger's icon and name
function DisplayTab:Build(page, iconIds, apply, refreshTree, triggerChip)
    if #iconIds == 0 then
        page:Card(L['Display'], 'all'):Row(rowHL, 0):Text(nil, { width = 1, text = L['This group has no icons yet.'], bgMode = 'hide' })
        return
    end

    local icons = {} ---@type table[]
    for _, id in ipairs(iconIds) do icons[#icons + 1] = CDM:Get(id) end
    local style = CDM:GetStyle(icons[1])

    local function set(path, value)
        for _, display in ipairs(icons) do Assign(display.Style, path, value) end
        apply()
    end

    local isBar = icons[1].type == 'bar'
    if icons[1].type == 'text' then
        -- Its one text is its only sub element; a Grid dynamic group gives it a fixed cell instead of fitting it.
        local function setText(path, value)
            for _, display in ipairs(icons) do Assign(display.SubRegions[1], path, value) end
            apply()
        end
        local single = #icons == 1 and icons[1] or nil
        local inGrid = single and CDM:IsDynamic(single.parent) and not CDM:WantsChain(single.parent)
        page:Card(L['Display'], 'all'):Rebuild(function(card)
            DisplayTab.Heading(card, L['Text'])
            if Section(card, 'text', L['Text Settings']) then
                TextRows(card, page, icons[1].SubRegions[1], setText, 'cdm:main', icons[1].Triggers, nil, true)
            end
            DisplayTab.Heading(card, L['Layout'])
            if single and Section(card, 'size', inGrid and L['Position and Size Settings'] or L['Position Settings']) then
                PositionAndSize(card, page, style, set, single, 600, not inGrid)
            end
            if Section(card, 'general', L['General']) then GeneralSettings(card, style, set, false) end
        end)
        return
    end
    page:Card(L['Display'], 'all'):Rebuild(function(card)
        if isBar then
            DisplayTab.Heading(card, L['Bar'])
            if Section(card, 'bar', L['Bar Settings']) then BarSettings(card, page, style, set) end
            if Section(card, 'barColor', L['Color Settings']) then BarColorSettings(card, page, style, set, icons) end
            if Section(card, 'spark', L['Spark Settings']) then SparkSettings(card, page, style, set) end
            DisplayTab.Heading(card, L['Icon'])
            if Section(card, 'barIcon', L['Icon Settings']) then BarIconSettings(card, page, style, set, refreshTree) end
            local powerType = SplitPower(icons[1])
            if powerType then
                DisplayTab.Heading(card, CDM.POWER_NAMES[powerType])
                if Section(card, 'pips', format(L['%s Settings'], CDM.PIP_NAMES[powerType])) then PipSettings(card, style, set) end
            end
        else
            DisplayTab.Heading(card, L['Icon'])
            if Section(card, 'icon', L['Icon Settings']) then IconSettings(card, page, style, set, refreshTree) end
            if Section(card, 'swipe', L['Swipe Settings']) then SwipeSettings(card, page, style, set) end
        end
        DisplayTab.Heading(card, L['Layout'])
        if Section(card, 'size', L['Position and Size Settings']) then
            PositionAndSize(card, page, style, set, #icons == 1 and icons[1] or nil, isBar and 600 or 128)
        end
        if Section(card, 'general', L['General']) then GeneralSettings(card, style, set, isBar) end

        DisplayTab.Heading(card, L['Sub Elements'])
        SubElements(card, page, icons, apply, triggerChip)
    end)
end

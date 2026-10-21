---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Auras') then return end
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local IconPicker = NRSKNUI.CDMIconPicker
local rowH = Theme.rowHeight

local tostring = tostring
local tonumber = tonumber
local ipairs = ipairs
local format = string.format
local CopyTable = CopyTable

---@class NRSKNUI.CDMDisplayTab
local DisplayTab = NRSKNUI.CDMDisplayTab
local ICON_SOURCES, ANCHOR_POINTS = DisplayTab.ICON_SOURCES, DisplayTab.ANCHOR_POINTS

---@param card table
---@param page table
---@param style table read side
---@param set fun(path: string[], value: any)
---@param refreshTree fun() the sidebar shows the icon too
local function IconSettings(card, page, style, set, refreshTree)
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
        tooltip = L['An icon file ID. Automatic uses it for triggers without an icon of their own, such as Player Stat.'],
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
    end)

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

    card:Row(rowH):ColorPicker(L['Swipe Color'], {
        width = 0.5,
        conditions = { 'cdm:swipe' },
        value = style.SwipeColor,
        callback = function(r, g, b, a) set({ 'SwipeColor' }, { r, g, b, a }) end,
    })
end

---The cooldown frame's own number, styled like a text.
---@param card table
---@param page table
---@param style table
---@param set fun(path: string[], value: any)
---@param triggers table[] the first icon's, for the trigger picker
local function TimerTextSettings(card, page, style, set, triggers)
    page:SetCondition('cdm:timerText', function() return not style.HideCountdown end)
    page:SetCondition('cdm:timerFont', function() return not style.HideCountdown and not style.TimerText.UseGlobalFont end)
    -- The whole table is written, so an icon saved before Timer Text existed never holds half of one.
    local function setTimer(key, value)
        local timer = CopyTable(style.TimerText)
        timer[key] = value
        set({ 'TimerText' }, timer)
    end
    local timer = style.TimerText

    local fontRow = card:Row(rowH)
    fontRow:Checkbox(L['Show Timer Text'], {
        width = 0.5,
        tooltip = L["The cooldown's own countdown, as the action bar shows it; unlike %p it speeds up with recovery-rate buffs."],
        value = not style.HideCountdown,
        callback = function(checked)
            set({ 'HideCountdown' }, not checked)
            page:Refresh()
        end,
    })
    fontRow:Checkbox(L['Use Global Font'], {
        width = 0.5,
        conditions = { 'cdm:timerText' },
        value = timer.UseGlobalFont,
        callback = function(checked)
            setTimer('UseGlobalFont', checked)
            page:Refresh()
        end,
    })

    local sizeRow = card:Row(rowH)
    sizeRow:Dropdown(L['Font'], {
        width = 0.5,
        media = 'font',
        conditions = { 'cdm:timerFont' },
        value = timer.FontFace,
        callback = function(value) setTimer('FontFace', value) end,
    })
    sizeRow:Slider(L['Size'], {
        width = 0.5,
        conditions = { 'cdm:timerText' },
        min = 6,
        max = 40,
        step = 1,
        value = timer.FontSize,
        callback = function(value) setTimer('FontSize', value) end,
    })

    local outlineRow = card:Row(rowH)
    outlineRow:Dropdown(L['Outline'], {
        width = 0.5,
        conditions = { 'cdm:timerText' },
        options = NRSKNUI:GetOutlineOptions(),
        value = timer.FontOutline,
        callback = function(value) setTimer('FontOutline', value) end,
    })
    outlineRow:ColorPicker(L['Color'], {
        width = 0.5,
        conditions = { 'cdm:timerText' },
        value = timer.Color,
        callback = function(r, g, b, a) setTimer('Color', { r, g, b, a }) end,
    })

    local sources = { { value = 0, text = L['Automatic'] } }
    for i in ipairs(triggers) do sources[#sources + 1] = { value = i, text = format(L['Trigger %d'], i) } end
    local sourceRow = card:Row(rowH)
    sourceRow:Dropdown(L['Trigger'], {
        width = 0.5,
        conditions = { 'cdm:timerText' },
        tooltip = L["Whose countdown shows: Automatic is the icon's own, never an aura overlay's; a picked trigger's shows only while its layer does."],
        options = sources,
        value = timer.Trigger or 0,
        callback = function(value) setTimer('Trigger', value ~= 0 and value or nil) end,
    })
    sourceRow:Dropdown(L['Anchor'], {
        width = 0.5,
        conditions = { 'cdm:timerText' },
        options = ANCHOR_POINTS,
        value = timer.AnchorTo,
        callback = function(point) setTimer('AnchorTo', point) end,
    })
    local offsetRow = card:Row(rowH)
    offsetRow:Slider(L['X Offset'], {
        width = 0.5,
        conditions = { 'cdm:timerText' },
        min = -40,
        max = 40,
        step = 1,
        value = timer.XOffset,
        callback = function(value) setTimer('XOffset', value) end,
    })
    offsetRow:Slider(L['Y Offset'], {
        width = 0.5,
        conditions = { 'cdm:timerText' },
        min = -40,
        max = 40,
        step = 1,
        value = timer.YOffset,
        callback = function(value) setTimer('YOffset', value) end,
    })
end

DisplayTab.IconSettings = IconSettings
DisplayTab.SwipeSettings = SwipeSettings
DisplayTab.TimerTextSettings = TimerTextSettings

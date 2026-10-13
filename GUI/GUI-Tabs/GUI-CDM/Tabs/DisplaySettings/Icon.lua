---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local IconPicker = NRSKNUI.CDMIconPicker
local rowH = Theme.rowHeight

local tostring = tostring
local tonumber = tonumber

---@class NRSKNUI.CDMDisplayTab
local DisplayTab = NRSKNUI.CDMDisplayTab
local ICON_SOURCES = DisplayTab.ICON_SOURCES

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

DisplayTab.IconSettings = IconSettings
DisplayTab.SwipeSettings = SwipeSettings

---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local tinsert = table.insert
local pairs = pairs

---@class NRSKNUI.CDMDisplayTab
local DisplayTab = NRSKNUI.CDMDisplayTab
local Assign = DisplayTab.Assign

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

local MATCH_SIDES = {
    { value = 'BELOW', text = L['Below'] },
    { value = 'ABOVE', text = L['Above'] },
}

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

DisplayTab.GeneralSettings = GeneralSettings
DisplayTab.PositionAndSize = PositionAndSize

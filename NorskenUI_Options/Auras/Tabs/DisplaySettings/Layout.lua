---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Auras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local tinsert = table.insert
local pairs, ipairs = pairs, ipairs

---@class NRSKNUI.CDMDisplayTab
local DisplayTab = NRSKNUI.CDMDisplayTab
local Assign, Differ = DisplayTab.Assign, DisplayTab.Differ

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
---@param mixed fun(path: (string|number)[], default: any?): KajiGUIMixedEntry[]? where the displays edited together disagree (DisplayTab.Differ)
---@param isBar boolean
local function GeneralSettings(card, style, set, mixed, isBar)
    local row = card:Row(rowH)
    row:Slider(L['Alpha'], {
        width = 0.5,
        min = 0,
        max = 1,
        step = 0.05,
        value = style.Alpha,
        mixed = mixed({ 'Alpha' }),
        callback = function(value) set({ 'Alpha' }, value) end,
    })
    row:Checkbox(L['Tooltip on Mouseover'], {
        width = 0.5,
        tooltip = isBar and L["The bar's spell or item; power bars have none."] or nil,
        value = style.Tooltip,
        mixed = mixed({ 'Tooltip' }),
        callback = function(checked) set({ 'Tooltip' }, checked) end,
    })
end

---@param card table
---@param page table
---@param style table
---@param set fun(path: string[], value: any)
---@param mixed fun(path: (string|number)[], default: any?): KajiGUIMixedEntry[]? where the displays edited together disagree (DisplayTab.Differ)
---@param displays table[] the displays this edits: one, a group's or a multi selection's, each written to
---@param apply fun() rebuilds them, which places them again
---@param maxSize number
---@param noSize boolean? a text display fits its text
local function PositionAndSize(card, page, style, set, mixed, displays, apply, maxSize, noSize)
    -- a setting is there when it means something for any of them, as WA shows every option across a selection
    local function any(test)
        for _, display in ipairs(displays) do
            if test(display) then return true end
        end
        return false
    end
    local first = displays[1]

    -- named per type: a mixed selection builds this once for each type on one page
    local unmatchedGroup, matchedGroup, freeGroup = 'cdm:unmatched:' .. first.type, 'cdm:matched:' .. first.type, 'cdm:free:' .. first.type
    page:SetCondition(unmatchedGroup, function() return any(function(d) return not d.MatchWidth end) end)
    page:SetCondition(matchedGroup, function() return any(function(d) return d.MatchWidth ~= nil end) end)

    -- offsets, strata and Match Width live on the display itself, not its style
    local function itself(display) return display end
    local placed = Differ(displays, itself)

    -- Match Width only reaches the bars outside a dynamic group
    local bars = {}
    for _, display in ipairs(displays) do
        if display.type == 'bar' and not CDM:IsDynamic(display.parent) then
            bars[#bars + 1] = display
        end
    end
    local matched = Differ(bars, itself)
    if bars[1] then
        local groups = {}
        for groupId, other in pairs(CDM.db.Displays) do
            if other.type == 'dynamicgroup' then
                groups[#groups + 1] = { value = groupId, text = other.name or groupId }
            end
        end
        table.sort(groups, function(x, y) return x.text < y.text end)
        tinsert(groups, 1, { value = 'none', text = L['None'] })

        local function match(key, value)
            for _, bar in ipairs(bars) do
                bar[key] = value
            end
            CDM:ApplySettings()
            page:Refresh()
        end
        local matchRow = card:Row(rowH)
        matchRow:Dropdown(L['Match Width'], {
            width = 0.5,
            tooltip = L["Take a dynamic group's width and sit against it. The width follows the group as icons come and go."],
            options = groups,
            value = bars[1].MatchWidth or 'none',
            mixed = matched({ 'MatchWidth' }, 'none'),
            callback = function(value) match('MatchWidth', value ~= 'none' and value or nil) end,
        })
        matchRow:Dropdown(L['Attach'], {
            width = 0.5,
            conditions = { matchedGroup },
            options = MATCH_SIDES,
            value = bars[1].MatchSide or 'BELOW',
            mixed = matched({ 'MatchSide' }, 'BELOW'),
            callback = function(value) match('MatchSide', value) end,
        })
        card:Row(rowH):Slider(L['Gap'], {
            width = 1,
            conditions = { matchedGroup },
            min = -1000,
            max = 1000,
            step = 1,
            value = bars[1].MatchGap or 0,
            mixed = matched({ 'MatchGap' }, 0),
            callback = function(value) match('MatchGap', value) end,
        })
        card:Separator(nil, { inSection = true })
    end

    if not noSize then
        local sizeRow = card:Row(rowH)
        sizeRow:Slider(L['Width'], {
            width = 0.5,
            conditions = { unmatchedGroup },
            min = 8,
            max = maxSize,
            step = 1,
            value = style.Width,
            mixed = mixed({ 'Width' }),
            callback = function(value) set({ 'Width' }, value) end,
        })
        sizeRow:Slider(L['Height'], {
            width = 0.5,
            min = 2,
            max = maxSize,
            step = 1,
            value = style.Height,
            mixed = mixed({ 'Height' }),
            callback = function(value) set({ 'Height' }, value) end,
        })
    end
    -- A dynamic group places its icons itself, a matched bar sits on its group; elsewhere an icon has its own offsets.
    page:SetCondition(freeGroup, function()
        return any(function(d) return not CDM:IsDynamic(d.parent) and not d.MatchWidth end)
    end)

    local function place(path, value)
        for _, display in ipairs(displays) do
            Assign(display, path, value)
        end
        apply()
    end

    local display = first
    local position = display.Position
    local offsetRow = card:Row(rowH)
    offsetRow:Slider(L['X Offset'], {
        width = 0.5,
        conditions = { freeGroup },
        min = -1000,
        max = 1000,
        step = 1,
        value = position.XOffset,
        mixed = placed({ 'Position', 'XOffset' }),
        callback = function(value) place({ 'Position', 'XOffset' }, value) end,
    })
    offsetRow:Slider(L['Y Offset'], {
        width = 0.5,
        conditions = { freeGroup },
        min = -1000,
        max = 1000,
        step = 1,
        value = position.YOffset,
        mixed = placed({ 'Position', 'YOffset' }),
        callback = function(value) place({ 'Position', 'YOffset' }, value) end,
    })

    card:Row(rowH):Dropdown(L['Frame Strata'], {
        width = 1,
        conditions = { freeGroup },
        options = STRATA,
        value = display.Strata or 'INHERIT',
        mixed = placed({ 'Strata' }, 'INHERIT'),
        callback = function(value) place({ 'Strata' }, value ~= 'INHERIT' and value or nil) end,
    })
end

DisplayTab.GeneralSettings = GeneralSettings
DisplayTab.PositionAndSize = PositionAndSize

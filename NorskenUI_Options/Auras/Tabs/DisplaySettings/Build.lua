---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenAuras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowHL = Theme.rowHeightLast

local ipairs = ipairs
local format = string.format

---@class NRSKNUI.CDMDisplayTab
local DisplayTab = NRSKNUI.CDMDisplayTab
local Assign, BarColorSettings, BarIconSettings, BarSettings = DisplayTab.Assign, DisplayTab.BarColorSettings, DisplayTab.BarIconSettings, DisplayTab.BarSettings
local Differ = DisplayTab.Differ
local GeneralSettings, IconSettings, PipSettings, PositionAndSize = DisplayTab.GeneralSettings, DisplayTab.IconSettings, DisplayTab.PipSettings, DisplayTab.PositionAndSize
local Section, SparkSettings, SplitPower, SubElements = DisplayTab.Section, DisplayTab.SparkSettings, DisplayTab.SplitPower, DisplayTab.SubElements
local SwipeSettings, TextRows, TimerTextSettings = DisplayTab.SwipeSettings, DisplayTab.TextRows, DisplayTab.TimerTextSettings

---@param page table
---@param iconIds string[] one type: a mixed group or selection builds one block per type
---@param apply fun()
---@param refreshTree fun()
---@param triggerChip fun(index: number, trigger: table): string a trigger's icon and name
---@param opts? { title?: string, noGeneral?: boolean } a per-type block's card title; General then sits on the All card
function DisplayTab:Build(page, iconIds, apply, refreshTree, triggerChip, opts)
    opts = opts or {}
    local title = opts.title or L['Display']
    if #iconIds == 0 then
        page:Card(title, 'all'):Row(rowHL, 0):Text(nil, { width = 1, text = L['This group has no icons yet.'], bgMode = 'hide' })
        return
    end

    local icons = {} ---@type table[]
    for _, id in ipairs(iconIds) do
        icons[#icons + 1] = CDM:Get(id)
    end
    local style = CDM:GetStyle(icons[1])

    -- one style each, read the way it draws (a missing key from its template), for every widget's differ
    local styles = {}
    for _, display in ipairs(icons) do
        styles[display] = CDM:GetStyle(display)
    end
    local mixed = Differ(icons, function(display) return styles[display] end)

    ---@param more boolean? another set follows, which applies both at once
    local function set(path, value, more)
        for _, display in ipairs(icons) do
            Assign(display.Style, path, value)
        end
        if not more then
            apply()
        end
    end

    local isBar = icons[1].type == 'bar'
    local sizeKey = 'size:' .. icons[1].type -- a mixed selection has one per block and each keeps its own open state
    if icons[1].type == 'text' then
        -- Its one text is its only sub element; a Grid dynamic group gives it a fixed cell instead of fitting it.
        local function setText(path, value)
            for _, display in ipairs(icons) do
                Assign(display.SubRegions[1], path, value)
            end
            apply()
        end
        local textMixed = Differ(icons, function(display) return display.SubRegions[1] end)
        local inGrid = false
        for _, display in ipairs(icons) do
            inGrid = inGrid or (CDM:IsDynamic(display.parent) and not CDM:WantsChain(display.parent))
        end
        page:Card(title, 'all'):Rebuild(function(card)
            if Section(card, 'text', L['Text Settings']) then
                TextRows(card, page, icons[1].SubRegions[1], setText, textMixed, 'cdm:main', icons, 1, nil, true)
            end
            DisplayTab.Heading(card, L['Layout'])
            if Section(card, sizeKey, inGrid and L['Position and Size Settings'] or L['Position Settings']) then
                PositionAndSize(card, page, style, set, mixed, icons, apply, 600, not inGrid)
            end
            if not opts.noGeneral and Section(card, 'general', L['General']) then
                GeneralSettings(card, style, set, mixed, false)
            end
        end)
        return
    end
    page:Card(title, 'all'):Rebuild(function(card)
        if isBar then
            if Section(card, 'bar', L['Bar Settings']) then BarSettings(card, page, style, set, mixed) end
            if Section(card, 'barColor', L['Color Settings']) then BarColorSettings(card, page, style, set, mixed, icons) end
            if Section(card, 'spark', L['Spark Settings']) then SparkSettings(card, page, style, set, mixed) end
            DisplayTab.Heading(card, L['Icon'])
            if Section(card, 'barIcon', L['Icon Settings']) then BarIconSettings(card, page, style, set, mixed, refreshTree) end
            local powerType
            for _, display in ipairs(icons) do
                powerType = powerType or SplitPower(display)
            end
            if powerType then
                DisplayTab.Heading(card, CDM.POWER_NAMES[powerType])
                if Section(card, 'pips', format(L['%s Settings'], CDM.PIP_NAMES[powerType])) then PipSettings(card, style, set, mixed) end
            end
        else
            if Section(card, 'icon', L['Icon Settings']) then IconSettings(card, page, style, set, mixed, refreshTree) end
            if Section(card, 'swipe', L['Swipe Settings']) then SwipeSettings(card, page, style, set, mixed) end
            local triggers = icons[1].Triggers
            for _, display in ipairs(icons) do
                if #display.Triggers > #triggers then triggers = display.Triggers end
            end
            if Section(card, 'timerText', L['Timer Text Settings']) then TimerTextSettings(card, page, style, set, mixed, triggers) end
        end
        DisplayTab.Heading(card, L['Layout'])
        if Section(card, sizeKey, L['Position and Size Settings']) then
            PositionAndSize(card, page, style, set, mixed, icons, apply, isBar and 600 or 128)
        end
        if not opts.noGeneral and Section(card, 'general', L['General']) then
            GeneralSettings(card, style, set, mixed, isBar)
        end

        DisplayTab.Heading(card, L['Sub Elements'])
        SubElements(card, page, icons, apply, triggerChip)
    end)
end

---What every type shares, for a group or selection holding more than one: General across all of them.
---@param page table
---@param iconIds string[]
---@param apply fun()
function DisplayTab:BuildShared(page, iconIds, apply)
    local icons, styles = {}, {}
    for _, id in ipairs(iconIds) do
        local display = CDM:Get(id)
        icons[#icons + 1] = display
        styles[display] = CDM:GetStyle(display)
    end
    local mixed = Differ(icons, function(display) return styles[display] end)

    local function set(path, value)
        for _, display in ipairs(icons) do
            Assign(display.Style, path, value)
        end
        apply()
    end

    page:Card(format(L['All (%d)'], #icons), 'all'):Rebuild(function(card)
        if Section(card, 'general', L['General']) then
            GeneralSettings(card, styles[icons[1]], set, mixed, false)
        end
    end)
end

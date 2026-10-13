---@class NRSKNUI
local NRSKNUI = select(2, ...)
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
local GeneralSettings, IconSettings, PipSettings, PositionAndSize = DisplayTab.GeneralSettings, DisplayTab.IconSettings, DisplayTab.PipSettings, DisplayTab.PositionAndSize
local Section, SparkSettings, SplitPower, SubElements = DisplayTab.Section, DisplayTab.SparkSettings, DisplayTab.SplitPower, DisplayTab.SubElements
local SwipeSettings, TextRows = DisplayTab.SwipeSettings, DisplayTab.TextRows

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

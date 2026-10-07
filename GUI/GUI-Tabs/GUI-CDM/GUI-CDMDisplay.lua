---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local tinsert, tremove = table.insert, table.remove
local ipairs, pairs = ipairs, pairs
local format = string.format
local CopyTable = CopyTable
local tostring = tostring
local tonumber = tonumber
local type = type

local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture

local SUB_INDENT = 12
-- Headings sit close to what comes before them and leave room before the rows they head.
local HEADING_HEIGHT = 20
local HEADING_SPACING = 10
local DIVIDER_SPACING = 10

local SUBREGION_NAMES = { text = L['Text'], border = L['Border'] }
local ICON_SOURCES = {
    { value = 'auto',   text = L['Automatic'] },
    { value = 'manual', text = L['Manual'] },
}
local BORDER_STYLES = { { value = 'Pixel', text = L['Pixel'] } }
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
local TEXT_TOKENS = {
    { '%p', L['Time left'] },
    { '%t', L['Total time'] },
    { '%s', L['Charges'] },
    { '%n', L['Spell name'] },
}

-- Sections and sub-sections start closed, Icon Settings aside; what the user opens or closes holds for the session.
local sectionOpen = { icon = true } -- [section key] = true
local subOpen = {}                  -- [sub-section key] = true

---@class NRSKNUI.CDMDisplayTab
local DisplayTab = {}
NRSKNUI.CDMDisplayTab = DisplayTab

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
---@return boolean open
local function SubSection(card, key, title)
    return card:SubSection(title, {
        key = key,
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
local function IconSettings(card, page, style, set)
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
            page:Refresh()
        end,
    })
    sourceRow:EditBox(L['Manual Icon'], {
        width = 0.5,
        conditions = { 'cdm:manualIcon' },
        tooltip = L['A spell ID or an icon file ID.'],
        value = style.ManualIcon and tostring(style.ManualIcon) or '',
        callback = function(text)
            local number = tonumber(text)
            set({ 'ManualIcon' }, number and (GetSpellTexture(number) or number) or nil)
        end,
    })

    local toggleRow = card:Row(rowH)
    toggleRow:Checkbox(L['Desaturate'], {
        width = 0.5,
        value = style.Desaturate,
        callback = function(checked) set({ 'Desaturate' }, checked) end,
    })
    toggleRow:Checkbox(L['Tooltip on Mouseover'], {
        width = 0.5,
        value = style.Tooltip,
        callback = function(checked) set({ 'Tooltip' }, checked) end,
    })

    if SubSection(card, 'extra', L['Extra Options']) then
        local extraRow = card:Row(rowH, nil, SUB_INDENT)
        extraRow:Slider(L['Alpha'], {
            width = 0.5,
            min = 0,
            max = 1,
            step = 0.05,
            value = style.Alpha,
            callback = function(value) set({ 'Alpha' }, value) end,
        })
        extraRow:Slider(L['Zoom'], {
            width = 0.5,
            min = 0,
            max = 1,
            step = 0.01,
            value = style.Zoom or NRSKNUI.GlobalZoom,
            callback = function(value) set({ 'Zoom' }, value) end,
        })
        card:Row(rowH, nil, SUB_INDENT):Checkbox(L['Keep Aspect Ratio'], {
            width = 1,
            tooltip = L['Crop the icon to the frame shape instead of stretching it.'],
            value = style.KeepAspectRatio,
            callback = function(checked) set({ 'KeepAspectRatio' }, checked) end,
        })
    end
end

---WeakAuras' swipe overlay grid, under its own label inside Icon Settings.
---@param card table
---@param page table
---@param style table
---@param set fun(path: string[], value: any)
local function SwipeSettings(card, page, style, set)
    page:SetCondition('cdm:swipe', function() return style.DrawSwipe == true end)
    card:Separator(L['Swipe Overlay Settings'], { useLabel = true, centered = true, inSection = true, height = HEADING_HEIGHT, spacing = HEADING_SPACING })

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
    card:Separator(nil, { inSection = true, spacing = DIVIDER_SPACING })
end

---@param card table
---@param page table
---@param style table
---@param set fun(path: string[], value: any)
---@param display table? the icon whose position this edits, nil when editing a group's icons together
local function PositionAndSize(card, page, style, set, display)
    local sizeRow = card:Row(rowH)
    sizeRow:Slider(L['Width'], {
        width = 0.5,
        min = 8,
        max = 128,
        step = 1,
        value = style.Width,
        callback = function(value) set({ 'Width' }, value) end,
    })
    sizeRow:Slider(L['Height'], {
        width = 0.5,
        min = 8,
        max = 128,
        step = 1,
        value = style.Height,
        callback = function(value) set({ 'Height' }, value) end,
    })
    if not display then return end

    -- A dynamic group places its icons itself; elsewhere an icon has its own offsets.
    page:SetCondition('cdm:freePosition', function() return not CDM:IsDynamic(display.parent) end)

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
        width = 0.5,
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
local function TextRows(card, page, element, set, key)
    local shown, customFont, shadow = key .. ':shown', key .. ':font', key .. ':shadow'
    page:SetCondition(shown, function() return element.Enabled == true end)
    page:SetCondition(customFont, function() return element.UseGlobalFont ~= true end)
    page:SetCondition(shadow, function() return element.FontShadow.Enabled == true end)

    card:Row(rowH):Checkbox(L['Show Text'], {
        width = 1,
        value = element.Enabled,
        callback = function(checked)
            set({ 'Enabled' }, checked)
            page:Refresh()
        end,
    })
    card:Separator(nil, { inSection = true })

    card:Row(rowH):EditBox(L['Display Text'], {
        width = 1,
        conditions = { shown },
        tooltip = DisplayTextTooltip,
        value = element.Text,
        callback = function(text)
            set({ 'Text' }, text)
            card:Rebuild()
        end,
    })

    local hasDuration, hasCharges = CDM:ClassifyText(element.Text or '')
    if hasDuration and hasCharges then
        card:Row(rowH):Text(nil, {
            width = 1,
            text = L["%s is dropped here: a time and a charge count can't share one text. Add a second text for it."],
            bgMode = 'hide',
        })
    end

    if SubSection(card, key .. ':format', L['Format Options']) then
        card:Row(rowH, nil, SUB_INDENT):Checkbox(L['Use Global Font'], {
            width = 1,
            conditions = { shown },
            value = element.UseGlobalFont,
            callback = function(checked)
                set({ 'UseGlobalFont' }, checked)
                page:Refresh()
            end,
        })

        local fontRow = card:Row(rowH, nil, SUB_INDENT)
        fontRow:Dropdown(L['Font'], {
            width = 0.5,
            media = 'font',
            conditions = { shown, customFont },
            value = element.FontFace,
            callback = function(value) set({ 'FontFace' }, value) end,
        })
        fontRow:Slider(L['Size'], {
            width = 0.5,
            conditions = { shown },
            min = 6,
            max = 40,
            step = 1,
            value = element.FontSize,
            callback = function(value) set({ 'FontSize' }, value) end,
        })

        local colorRow = card:Row(rowH, nil, SUB_INDENT)
        colorRow:ColorPicker(L['Color'], {
            width = 0.5,
            conditions = { shown },
            value = element.Color,
            callback = function(r, g, b, a) set({ 'Color' }, { r, g, b, a }) end,
        })
        colorRow:Dropdown(L['Outline'], {
            width = 0.5,
            conditions = { shown },
            options = NRSKNUI:GetOutlineOptions(),
            value = element.FontOutline,
            callback = function(value) set({ 'FontOutline' }, value) end,
        })
    end

    if SubSection(card, key .. ':shadow', L['Font Shadow']) then
        card:Row(rowH, nil, SUB_INDENT):Checkbox(L['Shadow'], {
            width = 1,
            conditions = { shown },
            value = element.FontShadow.Enabled,
            callback = function(checked)
                set({ 'FontShadow', 'Enabled' }, checked)
                page:Refresh()
            end,
        })

        local shadowRow = card:Row(rowH, nil, SUB_INDENT)
        shadowRow:ColorPicker(L['Shadow Color'], {
            width = 0.34,
            conditions = { shown, shadow },
            value = element.FontShadow.Color,
            callback = function(r, g, b, a) set({ 'FontShadow', 'Color' }, { r, g, b, a }) end,
        })
        shadowRow:Slider(L['Shadow X'], {
            width = 0.33,
            conditions = { shown, shadow },
            min = -5,
            max = 5,
            step = 1,
            value = element.FontShadow.OffsetX,
            callback = function(value) set({ 'FontShadow', 'OffsetX' }, value) end,
        })
        shadowRow:Slider(L['Shadow Y'], {
            width = 0.33,
            conditions = { shown, shadow },
            min = -5,
            max = 5,
            step = 1,
            value = element.FontShadow.OffsetY,
            callback = function(value) set({ 'FontShadow', 'OffsetY' }, value) end,
        })
    end

    if SubSection(card, key .. ':anchor', L['Anchors']) then
        local position = element.Position
        card:Row(rowH, nil, SUB_INDENT):Dropdown(L['Anchor'], {
            width = 1,
            conditions = { shown },
            options = ANCHOR_POINTS,
            value = position.AnchorFrom,
            callback = function(point) set({ 'Position', 'AnchorFrom' }, point) end,
        })

        local offsetRow = card:Row(rowH, nil, SUB_INDENT)
        offsetRow:Slider(L['X Offset'], {
            width = 0.5,
            conditions = { shown },
            min = -40,
            max = 40,
            step = 1,
            value = position.XOffset,
            callback = function(value) set({ 'Position', 'XOffset' }, value) end,
        })
        offsetRow:Slider(L['Y Offset'], {
            width = 0.5,
            conditions = { shown },
            min = -40,
            max = 40,
            step = 1,
            value = position.YOffset,
            callback = function(value) set({ 'Position', 'YOffset' }, value) end,
        })
    end
end

---@param card table
---@param page table
---@param element table
---@param set fun(path: string[], value: any)
---@param key string
local function BorderRows(card, page, element, set, key)
    local shown = key .. ':shown'
    page:SetCondition(shown, function() return element.Enabled == true end)

    card:Row(rowH):Checkbox(L['Show Border'], {
        width = 1,
        value = element.Enabled,
        callback = function(checked)
            set({ 'Enabled' }, checked)
            page:Refresh()
        end,
    })
    card:Separator(nil, { inSection = true })

    local styleRow = card:Row(rowH)
    styleRow:Dropdown(L['Style'], {
        width = 0.5,
        media = 'border',
        conditions = { shown },
        options = BORDER_STYLES,
        value = element.Style,
        callback = function(value) set({ 'Style' }, value) end,
    })
    styleRow:ColorPicker(L['Border Color'], {
        width = 0.5,
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

-- Sub elements --

---@param card table
---@param page table
---@param icons table[]
---@param apply fun()
local function SubElements(card, page, icons, apply)
    local first = icons[1]
    first.SubRegions = first.SubRegions or {}

    if not SameLayout(icons) then
        card:Row(rowH):Text(nil, { width = 1, text = L['These icons have different sub elements; edit them per icon.'], bgMode = 'hide' })
        return
    end

    local function Each(fn)
        for _, display in ipairs(icons) do
            display.SubRegions = display.SubRegions or {}
            fn(display.SubRegions)
        end
        apply()
        card:Rebuild()
    end

    local counts = {}
    local elements = first.SubRegions
    for index, element in ipairs(elements) do
        counts[element.type] = (counts[element.type] or 0) + 1
        local title = format('%s %d', SUBREGION_NAMES[element.type] or element.type, counts[element.type])
        local key = 'cdm:sub:' .. index .. ':' .. element.type

        local function set(path, value)
            for _, display in ipairs(icons) do Assign(display.SubRegions[index], path, value) end
            apply()
        end

        local expanded = Section(card, key, title, {
            onMoveUp = index > 1 and function()
                Each(function(list) list[index], list[index - 1] = list[index - 1], list[index] end)
            end or nil,
            onMoveDown = index < #elements and function()
                Each(function(list) list[index], list[index + 1] = list[index + 1], list[index] end)
            end or nil,
            onDuplicate = function()
                Each(function(list) tinsert(list, index + 1, CopyTable(list[index])) end)
            end,
            onDelete = function()
                Each(function(list) tremove(list, index) end)
            end,
        })

        if expanded then
            if element.type == 'text' then
                TextRows(card, page, element, set, key)
            elseif element.type == 'border' then
                BorderRows(card, page, element, set, key)
            end
        end
    end
    card:EndSection()

    local addRow = card:Row(rowHL, 0)
    addRow:Button(L['Add Text'], {
        width = 0.5,
        callback = function() Each(function(list) list[#list + 1] = CDM:NewSubRegion('text') end) end,
    })
    addRow:Button(L['Add Border'], {
        width = 0.5,
        callback = function() Each(function(list) list[#list + 1] = CDM:NewSubRegion('border') end) end,
    })
end

---The Display tab for one icon, or every icon in a group at once (WeakAuras' group editing).
---Controls show the first icon's values; every change goes to all of them.
---@param page table
---@param iconIds string[]
---@param apply fun()
function DisplayTab:Build(page, iconIds, apply)
    if #iconIds == 0 then
        page:Card():Row(rowHL, 0):Text(nil, { width = 1, text = L['This group has no icons yet.'], bgMode = 'hide' })
        return
    end

    local icons = {} ---@type table[]
    for _, id in ipairs(iconIds) do icons[#icons + 1] = CDM:Get(id) end
    local style = CDM:GetStyle(icons[1])

    local function set(path, value)
        for _, display in ipairs(icons) do Assign(display.Style, path, value) end
        apply()
    end

    page:Card():Rebuild(function(card)
        if Section(card, 'icon', L['Icon Settings']) then
            IconSettings(card, page, style, set)
            SwipeSettings(card, page, style, set)
        end
        if Section(card, 'size', L['Position and Size Settings']) then
            PositionAndSize(card, page, style, set, #icons == 1 and icons[1] or nil)
        end

        card:Separator(L['Sub Elements'], { useLabel = true, centered = true, height = HEADING_HEIGHT, spacing = HEADING_SPACING })
        SubElements(card, page, icons, apply)
    end)
end

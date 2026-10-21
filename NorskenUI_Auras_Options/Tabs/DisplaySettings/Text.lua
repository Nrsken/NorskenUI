---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local ipairs = ipairs
local strfind = string.find
local format = string.format

---@class NRSKNUI.CDMDisplayTab
local DisplayTab = NRSKNUI.CDMDisplayTab
local ANCHOR_POINTS, SUB_INDENT, TEXT_JUSTIFY, subOpen = DisplayTab.ANCHOR_POINTS, DisplayTab.SUB_INDENT, DisplayTab.TEXT_JUSTIFY, DisplayTab.subOpen

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
-- A power's %p can also read as a percent of its max.
local POWER_NUMBER_FORMATS = CopyTable(NUMBER_FORMATS)
POWER_NUMBER_FORMATS[#POWER_NUMBER_FORMATS + 1] = { value = 'percent', text = L['Percent'] }

local NAME_FORMATS = {
    { value = 'full',    text = L['Full'] },
    { value = 'initial', text = L['First Letter'] },
    { value = 'upper',   text = L['Uppercase'] },
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

local TEXT_ALIGNMENTS = { TEXT_JUSTIFY[2], TEXT_JUSTIFY[3], TEXT_JUSTIFY[4] } -- a text display has no anchor to follow

local WIDTH_MODES = {
    { value = 'auto',  text = L['Automatic'] },
    { value = 'fixed', text = L['Fixed'] },
}

local TEXT_TOKENS = {
    { '%p', L['Time left'] },
    { '%t', L['Total time'] },
    { '%s', L['Charges'] },
    { '%n', L['Spell name'] },
    { '%2.n', L["Trigger 2's name, e.g. the highest stat"] },
    { '%i', L['Spell icon'] },
    { '%2.i', L["Trigger 2's icon"] },
    { '%%', L['A percent sign'] },
    { '\\n', L['New line'] },
    { '{rt1}', L['Raid marker 1 to 8'] },
}

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

---An indented, animated header for the less used settings inside a section, closed until opened.
---@param card table
---@param key string
---@param title string
---@param summary string? what the closed header says about its settings
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
    page:SetCondition(key .. ':numberDecimals', function() return element.NumberFormat == 'decimals' end)

    -- Only a text with a time, a value or a name has anything to format.
    local readsName = strfind(element.Text or '', '%%%d*%.?n') ~= nil
    local formatOpen = (readsTime or readsValue or readsName) and SubSection(card, key .. ':format', L['Format Options'])
    if formatOpen and readsName then
        local nameRow = card:Row(rowH, nil, SUB_INDENT)
        nameRow:Dropdown(L['Name Format'], {
            width = 0.5,
            conditions = { shown },
            tooltip = L['How %n reads. First Letter turns Mastery into M, Uppercase into MASTERY.'],
            options = NAME_FORMATS,
            value = element.NameFormat or 'full',
            callback = function(value) set({ 'NameFormat' }, value) end,
        })
        nameRow:Dropdown(L['Name Color'], {
            width = 0.5,
            conditions = { shown },
            tooltip = L["The colour of %n. Custom uses the text's Color."],
            options = NRSKNUI.ColorModeOptions,
            value = element.NameColor or 'custom',
            callback = function(value) set({ 'NameColor' }, value) end,
        })
    end
    if formatOpen and readsValue then
        local numberRow = card:Row(rowH, nil, SUB_INDENT)
        numberRow:Dropdown(L['Number Format'], {
            width = 0.5,
            conditions = { shown },
            tooltip = readsPower and L['How a Power value reads. Automatic: whole numbers. Percent: %p as a share of the max, like Stagger against your health.']
                or L['How a Power or Stat value reads. Automatic: whole numbers, as the character sheet shows them.'],
            options = readsPower and POWER_NUMBER_FORMATS or NUMBER_FORMATS,
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

DisplayTab.TextRows = TextRows

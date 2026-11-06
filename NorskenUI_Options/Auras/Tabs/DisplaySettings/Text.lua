---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenAuras') then return end
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

---What a text's %p/%t stand for: a time on most triggers, a value on Power and Stat. A plain token reads every layer's own trigger.
---@param text string?
---@param triggers table[]
---@return boolean readsTime
---@return boolean readsValue
---@return boolean readsPower
---@return boolean readsCount
---@return number? source the trigger its %N. token names
local function Reads(text, triggers)
    local hasDuration, hasCharges, source = CDM:ClassifyText(text or '')
    local readsTime, readsValue, readsPower, readsCount = false, false, false, false
    for index, trigger in ipairs(triggers) do
        if not source or index == source then
            local triggerType = CDM.TriggerTypes[trigger.Type]
            if triggerType and triggerType.Value then
                readsValue = hasDuration or hasCharges
                readsPower = readsPower or (readsValue and trigger.Type == 'power')
            else
                readsTime = readsTime or hasDuration
                readsCount = readsCount or hasCharges
            end
        end
    end
    return readsTime, readsValue, readsPower, readsCount, source
end

---@param card table
---@param page table
---@param element table read side
---@param set fun(path: string[], value: any)
---@param mixed fun(path: (string|number)[], default: any?): KajiGUIMixedEntry[]? where the displays edited together disagree (DisplayTab.Differ)
---@param key string unique per element, for its conditions and sub-sections
---@param displays table[] the displays this text is on; the first one's triggers are what %N.p tokens point into
---@param slot number where the text sits in each one's SubRegions
---@param pipName string? a split power bar's "Rune", whose texts can repeat on each one
---@param main boolean? a text display's own text: always shown, pinned at its alignment, no rotation
---@param noAuraSlot boolean? an earlier text already took the aura button's one time or count, see CDM:DroppedAuraTexts
local function TextRows(card, page, element, set, mixed, key, displays, slot, pipName, main, noAuraSlot)
    local shown, customFont, shadow = key .. ':shown', key .. ':font', key .. ':shadow'
    local customTime, decimals, fixedWidth = key .. ':time', key .. ':decimals', key .. ':fixed'
    page:SetCondition(shown, function() return element.Enabled == true or mixed({ 'Enabled' }) end)
    page:SetCondition(customFont, function() return element.UseGlobalFont ~= true or mixed({ 'UseGlobalFont' }) end)
    page:SetCondition(shadow, function() return element.FontShadow.Enabled == true or mixed({ 'FontShadow', 'Enabled' }) end)
    page:SetCondition(customTime, function() return element.TimeFormat == 'custom' or mixed({ 'TimeFormat' }) end)
    page:SetCondition(decimals, function()
        return (element.TimeFormat == 'custom' or mixed({ 'TimeFormat' })) and (element.PrecisionBelow > 0 or mixed({ 'PrecisionBelow' }))
    end)
    page:SetCondition(fixedWidth, function() return element.WidthMode == 'fixed' or mixed({ 'WidthMode' }) end)

    local triggers = displays[1].Triggers
    local readsTime, readsValue, readsPower, readsCount, source = Reads(element.Text, triggers)

    -- what the text can't show goes on its Display Text marker; a missing trigger or a dropped %s is a warning
    local sourceTrigger = source and triggers[source]
    local notes, level = {}, 'info'
    if readsTime and readsCount then -- a time's binding has no slot for a count; a Power or Stat value text mixes them fine
        notes[#notes + 1] = L["%s is dropped here: a time and a charge count can't share one text. Add a second text for it."]
        level = 'warning'
    end
    if source and not sourceTrigger then
        notes[#notes + 1] = format(L["There's no Trigger %d, so this text stays empty."], source)
        level = 'warning'
    elseif sourceTrigger and (sourceTrigger.Type == 'aura' or sourceTrigger.Type == 'auraoverlay') then
        notes[#notes + 1] = format(L['Only shows on the Trigger %d overlay.'], source)
    end
    if noAuraSlot then
        notes[#notes + 1] = L["An aura can only show one timer and one stack count. An earlier text already shows it, so this one stays empty."]
        level = 'warning'
    end

    local textRow = card:Row(rowH)
    if not main then
        textRow:Checkbox(L['Show Text'], {
            width = 0.5,
            value = element.Enabled,
            mixed = mixed({ 'Enabled' }),
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
        notice = notes[1] and { level = level, text = notes } or nil,
        value = element.Text,
        mixed = mixed({ 'Text' }),
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
            mixed = mixed({ 'EachPip' }),
            callback = function(checked) set({ 'EachPip' }, checked or nil) end,
        })
    end

    local fontRow = card:Row(rowH)
    fontRow:Checkbox(L['Use Global Font'], {
        width = 0.5,
        conditions = { shown },
        value = element.UseGlobalFont,
        mixed = mixed({ 'UseGlobalFont' }),
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
        mixed = mixed({ 'FontFace' }),
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
        mixed = mixed({ 'FontSize' }),
        callback = function(value) set({ 'FontSize' }, value) end,
    })
    sizeRow:Dropdown(L['Outline'], {
        width = 0.5,
        conditions = { shown },
        options = NRSKNUI:GetOutlineOptions(),
        value = element.FontOutline,
        mixed = mixed({ 'FontOutline' }),
        callback = function(value) set({ 'FontOutline' }, value) end,
    })

    card:Row(rowH):ColorPicker(L['Color'], {
        width = 0.5,
        conditions = { shown },
        value = element.Color,
        mixed = mixed({ 'Color' }),
        callback = function(r, g, b, a) set({ 'Color' }, { r, g, b, a }) end,
    })

    page:SetCondition(key .. ':numberDecimals', function() return element.NumberFormat == 'decimals' or mixed({ 'NumberFormat' }, 'auto') end)

    -- Only a text with a time, a value, a count or a name has anything to format; any display's text earns the rows.
    local readsName = strfind(element.Text or '', '%%%d*%.?n') ~= nil
    for i = 2, #displays do
        local other = displays[i].SubRegions[slot].Text
        local time, value, power, count = Reads(other, displays[i].Triggers)
        readsTime = readsTime or time
        readsValue = readsValue or value
        readsPower = readsPower or power
        readsCount = readsCount or count
        readsName = readsName or strfind(other or '', '%%%d*%.?n') ~= nil
    end
    local formatOpen = (readsTime or readsValue or readsCount or readsName) and SubSection(card, key .. ':format', L['Format Options'])
    if formatOpen and readsName then
        local nameRow = card:Row(rowH, nil, SUB_INDENT)
        nameRow:Dropdown(L['Name Format'], {
            width = 0.5,
            conditions = { shown },
            tooltip = L['How %n reads. First Letter turns Mastery into M, Uppercase into MASTERY.'],
            options = NAME_FORMATS,
            value = element.NameFormat or 'full',
            mixed = mixed({ 'NameFormat' }, 'full'),
            callback = function(value) set({ 'NameFormat' }, value) end,
        })
        nameRow:Dropdown(L['Name Color'], {
            width = 0.5,
            conditions = { shown },
            tooltip = L["The colour of %n. Custom uses the text's Color."],
            options = NRSKNUI.ColorModeOptions,
            value = element.NameColor or 'custom',
            mixed = mixed({ 'NameColor' }, 'custom'),
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
            mixed = mixed({ 'NumberFormat' }, 'auto'),
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
            mixed = mixed({ 'Decimals' }, 1),
            callback = function(value) set({ 'Decimals' }, value) end,
        })
    end
    if formatOpen and readsCount then
        card:Row(rowH, nil, SUB_INDENT):Checkbox(L['Hide Zero'], {
            width = 0.5,
            conditions = { shown },
            tooltip = L['%s shows nothing instead of 0.'],
            value = element.HideZero,
            mixed = mixed({ 'HideZero' }),
            callback = function(checked) set({ 'HideZero' }, checked or nil) end,
        })
    end
    if formatOpen and readsTime then
        card:Row(rowH, nil, SUB_INDENT):Dropdown(L['Time Format'], {
            width = 0.5,
            conditions = { shown },
            tooltip = L['Global uses the duration breakpoints from the global settings.'],
            options = TIME_FORMATS,
            value = element.TimeFormat,
            mixed = mixed({ 'TimeFormat' }),
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
            mixed = mixed({ 'PrecisionBelow' }),
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
            mixed = mixed({ 'Precision' }),
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
            mixed = mixed({ 'FontShadow', 'Enabled' }),
            callback = function(checked)
                setShadow({ 'FontShadow', 'Enabled' }, checked)
                page:Refresh()
            end,
        })
        toggleRow:ColorPicker(L['Shadow Color'], {
            width = 0.5,
            conditions = { shown, shadow },
            value = fontShadow.Color,
            mixed = mixed({ 'FontShadow', 'Color' }),
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
            mixed = mixed({ 'FontShadow', 'OffsetX' }),
            callback = function(value) setShadow({ 'FontShadow', 'OffsetX' }, value) end,
        })
        offsetRow:Slider(L['Shadow Y'], {
            width = 0.5,
            conditions = { shown, shadow },
            min = -5,
            max = 5,
            step = 1,
            value = fontShadow.OffsetY,
            mixed = mixed({ 'FontShadow', 'OffsetY' }),
            callback = function(value) setShadow({ 'FontShadow', 'OffsetY' }, value) end,
        })

        local alignRow = card:Row(rowH, nil, SUB_INDENT)
        if not main then
            alignRow:Dropdown(L['Rotate Text'], {
                width = 0.5,
                conditions = { shown },
                options = TEXT_ROTATIONS,
                value = element.Rotation,
                mixed = mixed({ 'Rotation' }),
                callback = function(value) set({ 'Rotation' }, value) end,
            })
        end
        alignRow:Dropdown(L['Alignment'], {
            width = 0.5,
            conditions = { shown },
            tooltip = main and L['The side the text grows from, and how its lines line up.'] or L['Automatic aligns the text to the side it is anchored on.'],
            options = main and TEXT_ALIGNMENTS or TEXT_JUSTIFY,
            value = element.Justify,
            mixed = mixed({ 'Justify' }),
            callback = function(value) set({ 'Justify' }, value) end,
        })

        local widthRow = card:Row(rowH, nil, SUB_INDENT)
        widthRow:Dropdown(L['Width'], {
            width = 0.5,
            conditions = { shown },
            options = WIDTH_MODES,
            value = element.WidthMode,
            mixed = mixed({ 'WidthMode' }),
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
            mixed = mixed({ 'FixedWidth' }),
            callback = function(value) set({ 'FixedWidth' }, value) end,
        })
        card:Row(rowH, nil, SUB_INDENT):Checkbox(L['Word Wrap'], {
            width = 0.5,
            conditions = { shown, fixedWidth },
            tooltip = L['Off cuts a text longer than the width short instead of wrapping it.'],
            value = element.WordWrap,
            mixed = mixed({ 'WordWrap' }),
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
            mixed = mixed({ 'Position', 'AnchorFrom' }),
            callback = function(point) setPosition({ 'Position', 'AnchorFrom' }, point) end,
        })
        pointRow:Dropdown(L["To Frame's"], {
            width = 0.5,
            conditions = { shown },
            options = ANCHOR_POINTS,
            value = position.AnchorTo,
            mixed = mixed({ 'Position', 'AnchorTo' }),
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
            mixed = mixed({ 'Position', 'XOffset' }),
            callback = function(value) setPosition({ 'Position', 'XOffset' }, value) end,
        })
        offsetRow:Slider(L['Y Offset'], {
            width = 0.5,
            conditions = { shown },
            min = -40,
            max = 40,
            step = 1,
            value = position.YOffset,
            mixed = mixed({ 'Position', 'YOffset' }),
            callback = function(value) setPosition({ 'Position', 'YOffset' }, value) end,
        })
    end
end

DisplayTab.TextRows = TextRows

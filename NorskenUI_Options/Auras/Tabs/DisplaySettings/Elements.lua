---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Auras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local tinsert, tremove = table.insert, table.remove
local ipairs = ipairs
local format = string.format
local CopyTable = CopyTable
local min = math.min
local tsort = table.sort

---@class NRSKNUI.CDMDisplayTab
local DisplayTab = NRSKNUI.CDMDisplayTab
local Assign, Section, SplitPower, TextRows = DisplayTab.Assign, DisplayTab.Section, DisplayTab.SplitPower, DisplayTab.TextRows
local Differ = DisplayTab.Differ

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
---@param element table
---@param set fun(path: string[], value: any)
---@param mixed fun(path: (string|number)[], default: any?): KajiGUIMixedEntry[]? where the displays edited together disagree (DisplayTab.Differ)
---@param key string
---@param pipName string? a split power bar's "Rune", whose borders can repeat on each one
local function BorderRows(card, page, element, set, mixed, key, pipName)
    local shown = key .. ':shown'
    page:SetCondition(shown, function() return element.Enabled == true or mixed({ 'Enabled' }) end)

    local showRow = card:Row(rowH)
    showRow:Checkbox(L['Show Border'], {
        width = pipName and 0.5 or 1,
        value = element.Enabled,
        mixed = mixed({ 'Enabled' }),
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
            mixed = mixed({ 'EachPip' }),
            callback = function(checked) set({ 'EachPip' }, checked or nil) end,
        })
    end

    card:Row(rowH):ColorPicker(L['Border Color'], {
        width = 1,
        conditions = { shown },
        value = element.Color,
        mixed = mixed({ 'Color' }),
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
        mixed = mixed({ 'Size' }),
        callback = function(value) set({ 'Size' }, value) end,
    })
    sizeRow:Slider(L['Border Offset'], {
        width = 0.5,
        conditions = { shown },
        min = -10,
        max = 10,
        step = 1,
        value = element.Offset,
        mixed = mixed({ 'Offset' }),
        callback = function(value) set({ 'Offset' }, value) end,
    })
end

---@param card table
---@param page table
---@param element table read side
---@param set fun(path: string[], value: any)
---@param mixed fun(path: (string|number)[], default: any?): KajiGUIMixedEntry[]? where the displays edited together disagree (DisplayTab.Differ)
---@param key string
local function TickRows(card, page, element, set, mixed, key)
    local shown, placed, manualLength = key .. ':shown', key .. ':placed', key .. ':length'
    local function on() return element.Enabled == true or mixed({ 'Enabled' }) end
    page:SetCondition(shown, on)
    page:SetCondition(placed, function() return on() and (element.Placement ~= 'auto' or mixed({ 'Placement' })) end)
    page:SetCondition(manualLength, function() return on() and (not element.AutoLength or mixed({ 'AutoLength' })) end)

    local showRow = card:Row(rowH)
    showRow:Checkbox(L['Show Tick'], {
        width = 0.5,
        value = element.Enabled,
        mixed = mixed({ 'Enabled' }),
        callback = function(checked)
            set({ 'Enabled' }, checked)
            page:Refresh()
        end,
    })
    showRow:ColorPicker(L['Tick Color'], {
        width = 0.5,
        conditions = { shown },
        value = element.Color,
        mixed = mixed({ 'Color' }),
        callback = function(r, g, b, a) set({ 'Color' }, { r, g, b, a }) end,
    })

    local placeRow = card:Row(rowH)
    placeRow:Dropdown(L['Placement'], {
        width = 0.5,
        conditions = { shown },
        tooltip = L['Automatic splits combo points, chi and other point resources into segments, and marks channel ticks and empower stages. At Value counts power, or seconds into a cast.'],
        options = TICK_PLACEMENTS,
        value = element.Placement,
        mixed = mixed({ 'Placement' }),
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
        mixed = mixed({ 'Placements' }),
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
        mixed = mixed({ 'Thickness' }),
        callback = function(value) set({ 'Thickness' }, value) end,
    })
    sizeRow:Checkbox(L['Automatic Length'], {
        width = 0.5,
        conditions = { shown },
        tooltip = L['Spans the whole bar.'],
        value = element.AutoLength,
        mixed = mixed({ 'AutoLength' }),
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
        mixed = mixed({ 'Length' }),
        callback = function(value) set({ 'Length' }, value) end,
    })
end

-- A glow is hidden until a condition shows it, so its settings stay editable while Show Glow is off.
---@param card table
---@param element table
---@param set fun(path: string[], value: any)
---@param mixed fun(path: (string|number)[], default: any?): KajiGUIMixedEntry[]? where the displays edited together disagree (DisplayTab.Differ)
local function GlowRows(card, element, set, mixed)
    card:Row(rowH):Checkbox(L['Show Glow'], {
        width = 1,
        tooltip = L['Shows the glow all the time. Leave it off and let a condition show it, like Proc Glow.'],
        value = element.Enabled,
        mixed = mixed({ 'Enabled' }),
        callback = function(checked) set({ 'Enabled' }, checked) end,
    })

    local typeRow = card:Row(rowH)
    typeRow:Dropdown(L['Glow Type'], {
        width = 0.5,
        options = GLOW_TYPES,
        value = element.Type,
        mixed = mixed({ 'Type' }),
        callback = function(value)
            set({ 'Type' }, value)
            card:Rebuild()
        end,
    })
    typeRow:Dropdown(L['Glow Color'], {
        width = 0.5,
        options = GLOW_COLOR_MODES,
        value = element.ColorMode,
        mixed = mixed({ 'ColorMode' }),
        callback = function(value)
            set({ 'ColorMode' }, value)
            card:Rebuild()
        end,
    })
    if element.ColorMode == 'custom' or mixed({ 'ColorMode' }) then
        card:Row(rowH):ColorPicker(L['Color'], {
            width = 0.5,
            value = element.Color,
            mixed = mixed({ 'Color' }),
            callback = function(r, g, b, a) set({ 'Color' }, { r, g, b, a }) end,
        })
    end

    if element.Type == 'pixel' or mixed({ 'Type' }) then
        local defaults = CDM.GLOW_DEFAULTS -- glows made before these settings existed draw with the defaults
        card:Row(rowH):Slider(L['Speed'], {
            width = 0.5,
            min = 0.05,
            max = 1,
            step = 0.05,
            value = element.Frequency or defaults.Frequency,
            mixed = mixed({ 'Frequency' }, defaults.Frequency),
            callback = function(value) set({ 'Frequency' }, value) end,
        })
        local linesRow = card:Row(rowH)
        linesRow:Slider(L['Lines'], {
            width = 0.5,
            min = 1,
            max = 16,
            step = 1,
            value = element.Lines,
            mixed = mixed({ 'Lines' }),
            callback = function(value) set({ 'Lines' }, value) end,
        })
        linesRow:Slider(L['Length'], {
            width = 0.5,
            min = 1,
            max = 20,
            step = 1,
            value = element.Length or defaults.Length,
            mixed = mixed({ 'Length' }, defaults.Length),
            callback = function(value) set({ 'Length' }, value) end,
        })
        local sizeRow = card:Row(rowH)
        sizeRow:Slider(L['Thickness'], {
            width = 0.5,
            min = 1,
            max = 8,
            step = 1,
            value = element.Thickness,
            mixed = mixed({ 'Thickness' }),
            callback = function(value) set({ 'Thickness' }, value) end,
        })
        sizeRow:Checkbox(L['Border'], {
            width = 0.5,
            tooltip = L['A dark band behind the lines.'],
            value = element.Border ~= false,
            mixed = mixed({ 'Border' }, true),
            callback = function(checked) set({ 'Border' }, checked) end,
        })
    end

    if element.Type == 'modern' or mixed({ 'Type' }) then
        card:Row(rowH):Checkbox(L['Start Animation'], {
            width = 0.5,
            tooltip = L["Plays Blizzard's proc burst when the glow starts."],
            value = element.StartAnim ~= false,
            mixed = mixed({ 'StartAnim' }, true),
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
    local powerType
    for _, display in ipairs(icons) do
        powerType = powerType or SplitPower(display)
    end
    local pipName = CDM.PIP_NAMES[powerType or false]

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
        local key = 'cdm:sub:' .. first.type .. ':' .. index .. ':' .. element.type -- a mixed selection has a list per type

        local function set(path, value)
            for _, display in ipairs(icons) do
                Assign(display.SubRegions[index], path, value)
            end
            apply()
        end
        -- the same layout on all of them (SameLayout), so this element is each one's element at this index
        local mixed = Differ(icons, function(display) return display.SubRegions[index] end)

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
                TextRows(card, page, element, set, mixed, key, icons, index, pipName, false, CDM:DroppedAuraTexts(first)[element] == true)
            elseif element.type == 'border' then
                BorderRows(card, page, element, set, mixed, key, pipName)
            elseif element.type == 'glow' then
                GlowRows(card, element, set, mixed)
            elseif element.type == 'tick' then
                TickRows(card, page, element, set, mixed, key)
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

DisplayTab.SubElements = SubElements

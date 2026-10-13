---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local IconPicker = NRSKNUI.CDMIconPicker
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs = ipairs
local format = string.format
local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
local tostring, tonumber, type = tostring, tonumber, type
local CopyTable = CopyTable

local CHECK_ORDER = { 'active', 'casting', 'channeling', 'empowering', 'empowerStage', 'succeeded', 'interrupted', 'failed', 'onCooldown', 'onGCD', 'recharging', 'waiting', 'noCharges', 'usable', 'noPower', 'inRange', 'proc', 'remaining', 'count', 'owned', 'pandemic', 'missing', 'combat', 'hasTarget', 'attackable', 'classInGroup' }
local CHECK_NAMES = {
    active = L['Active'],
    casting = L['Casting'],
    channeling = L['Channeling'],
    empowering = L['Empowering'],
    empowerStage = L['Empower Stage'],
    succeeded = L['Succeeded'],
    interrupted = L['Interrupted'],
    failed = L['Failed'],
    onCooldown = L['On Cooldown'],
    onGCD = L['On Global Cooldown'],
    recharging = L['Recharging'],
    waiting = L['Waiting'],
    noCharges = L['No Charges Left'],
    usable = L['Usable'],
    noPower = L['Not Enough Resources'],
    inRange = L['In Range'],
    proc = L['Proc Glow'],
    remaining = L['Remaining Time'],
    count = L['Count'],
    owned = L['In Bags'],
    combat = L['In Combat'],
    hasTarget = L['Has Target'],
    attackable = L['Attackable Target'],
    classInGroup = L['Class in Group'],
}
-- An aura's checks are states of the aura, worded as such in the If list and in a condition's title.
local AURA_CHECK_NAMES = { active = L['Is Up'], pandemic = L['In Pandemic'], missing = L['Is Missing'] }
local AURA_TITLES = { active = L['While %s is up'], pandemic = L['While %s is in pandemic'], missing = L['While %s is missing'] }
-- Strings, since a dropdown option can't carry false as its value.
local BOOLEAN = {
    { value = 'true',  text = L['True'] },
    { value = 'false', text = L['False'] },
}
-- Values a select check picks from, by its def.options.
local SELECT_OPTIONS = { class = {} }
for _, token in ipairs(CLASS_SORT_ORDER) do
    local color = C_ClassColor.GetClassColor(token)
    local name = LOCALIZED_CLASS_NAMES_MALE[token] or token
    SELECT_OPTIONS.class[#SELECT_OPTIONS.class + 1] = { value = token, text = color and color:WrapTextInColorCode(name) or name }
end

local OPERATORS = {
    { value = '<',  text = '<' },
    { value = '<=', text = '<=' },
    { value = '==', text = '=' },
    { value = '>=', text = '>=' },
    { value = '>',  text = '>' },
}
local SUB_NAMES = { text = L['Text'], border = L['Border'], glow = L['Glow'], tick = L['Tick'] }
local REMOVE = 'remove'
local MAX_DEPTH = 3    -- combinations nest this deep, as in WeakAuras
local INDENT = 16
local MIN_LIGHT = 0.35 -- a colour value in a condition's title is lifted to at least this brightness

-- iconOnly / barOnly: the display type the property exists on; noText: not on a text display, which has no icon.
-- up / pandemic: an aura's While Up / In Pandemic check can put it on the aura's button; auraOnly: nothing else can.
-- missing: a lone aura's While Missing check can put it on its placeholder (only what the aura's button covers).
local PROPERTIES = {
    { key = 'auraIcon',        text = L['Aura Icon'],            kind = 'bool',  up = true,       auraOnly = true, iconOnly = true },
    { key = 'auraTexture',     text = L['Aura Icon Texture'],    kind = 'icon',  up = true,       auraOnly = true, iconOnly = true },
    { key = 'auraColor',       text = L['Aura Icon Color'],      kind = 'color', up = true,       auraOnly = true, iconOnly = true },
    { key = 'auraDesaturate',  text = L['Aura Icon Desaturate'], kind = 'bool',  up = true,       auraOnly = true, iconOnly = true },
    { key = 'auraSwipe',       text = L['Aura Icon Swipe'],      kind = 'bool',  up = true,       auraOnly = true, iconOnly = true },
    { key = 'auraInverse',     text = L['Aura Icon Inverse Swipe'], kind = 'bool', up = true,     auraOnly = true, iconOnly = true },
    { key = 'fillOverlay',     text = L['Fill Overlay'],         kind = 'color', up = true,       auraOnly = true, barOnly = true },
    { key = 'missingOverlay',  text = L['Missing Overlay'],      kind = 'color', up = true,       auraOnly = true, barOnly = true },
    { key = 'barOverlay',      text = L['Bar Overlay'],          kind = 'color', up = true,       auraOnly = true, barOnly = true },
    { key = 'pandemicColor',   text = L['Pandemic Border'],      kind = 'color', pandemic = true, auraOnly = true },
    { key = 'desaturate',      text = L['Desaturate'],           kind = 'bool',  noText = true, missing = true },
    { key = 'color',           text = L['Icon Color'],           kind = 'color', noText = true, missing = true },
    { key = 'show',            text = L['Show Display'],         kind = 'bool' },
    { key = 'alpha',           text = L['Alpha'],                kind = 'alpha', missing = true },
    { key = 'swipe',           text = L['Show Swipe'],           kind = 'bool',  iconOnly = true },
    { key = 'inverse',         text = L['Inverse Swipe'],        kind = 'bool',  iconOnly = true },
    { key = 'edge',            text = L['Show Edge'],            kind = 'bool',  iconOnly = true },
    { key = 'swipeColor',      text = L['Swipe Color'],          kind = 'color', iconOnly = true },
    { key = 'barColor',        text = L['Bar Color'],            kind = 'color', barOnly = true },
    { key = 'backgroundColor', text = L['Background Color'],     kind = 'color', barOnly = true, missing = true },
    { key = 'sound',           text = L['Play Sound'],           kind = 'sound' },
}

local condOpen = {} -- [index] = open, for the session

---@class NRSKNUI.CDMConditionsTab
local ConditionsTab = {}
NRSKNUI.CDMConditionsTab = ConditionsTab

---Every property a change can set on this icon, its sub elements included.
---@param display table
---@return table[] list, table<string, table> byKey
local function PropertyList(display)
    local list, byKey = {}, {}
    local function add(entry)
        list[#list + 1] = entry
        byKey[entry.key] = entry
    end
    local kind = display.type
    for _, entry in ipairs(PROPERTIES) do
        local onType = entry.iconOnly and kind == 'icon' or entry.barOnly and kind == 'bar' or not (entry.iconOnly or entry.barOnly)
        if onType and not (entry.noText and kind == 'text') then add(entry) end
    end

    local counts = {}
    for n, element in ipairs(display.SubRegions or {}) do
        counts[element.type] = (counts[element.type] or 0) + 1
        -- A text display's one text is just "Text", as in WeakAuras.
        local name = kind == 'text' and L['Text'] or format('%s %d', SUB_NAMES[element.type] or element.type, counts[element.type])
        -- An overlay holds glows and texts, never a border: borders belong to the icon's frame.
        local onAura = element.type == 'glow' or element.type == 'text'
        local onPlaceholder = element.type == 'border' or element.type == 'text' -- a glow would show around the aura too
        -- Under an aura's check the change puts the element on its overlay, and says so.
        add({ key = 'sub.' .. n .. '.visible', text = format(L['%s Visible'], name), overlayText = format(L['%s on Overlay'], name), kind = 'bool', up = onAura, pandemic = element.type == 'glow', missing = onPlaceholder })
        if element.type ~= 'glow' then
            add({ key = 'sub.' .. n .. '.color', text = format(L['%s Color'], name), overlayText = format(L['%s Color on Overlay'], name), kind = 'color', up = onAura, missing = onPlaceholder })
        end
        if element.type == 'text' then
            add({ key = 'sub.' .. n .. '.fontSize', text = format(L['%s Font Size'], name), kind = 'fontSize' })
            add({ key = 'sub.' .. n .. '.text', text = format(L['%s Display Text'], name), kind = 'text' })
        end
    end
    return list, byKey
end

---@param entry table
---@param variable string?
---@param secret boolean
---@return boolean
local function Allowed(entry, variable, secret)
    if not secret then return not entry.auraOnly end
    if variable == 'pandemic' then return entry.pandemic == true end
    if variable == 'missing' then return entry.missing == true end
    return entry.up == true
end

---@param entry table
---@return any
local function DefaultValue(entry)
    if entry.kind == 'bool' then return true end
    if entry.kind == 'alpha' then return 0.5 end
    if entry.kind == 'fontSize' then return 20 end
    if entry.kind == 'text' then return '%p' end
    if entry.kind == 'color' then return entry.pandemic and entry.auraOnly and { 1, 0.25, 0.25, 1 } or { 1, 1, 1, 1 } end
    return nil
end

---@param display table
---@param check table
---@return table? trigger, table? def
local function CheckDef(display, check)
    local trigger = CDM:GetCheckTrigger(display, check.trigger)
    local checks = trigger and CDM.ConditionChecks[trigger.Type]
    return trigger, checks and checks[check.variable]
end

---@param trigger table?
---@param skipSecret boolean? inside a combination, where an aura's checks can't be combined
---@return table[] options, string? first
local function CheckOptions(trigger, skipSecret)
    local checks = trigger and CDM.ConditionChecks[trigger.Type]
    local options, first = {}, nil
    for _, key in ipairs(CHECK_ORDER) do
        local def = checks and checks[key]
        if def and not (skipSecret and def.secret) and not (key == 'missing' and not trigger.Placeholder) then
            options[#options + 1] = { value = key, text = def.secret and AURA_CHECK_NAMES[key] or CHECK_NAMES[key] }
            first = first or key
        end
    end
    return options, first
end

---A condition's header: '5. [icon] Blade of Justice On Cooldown' or '5. While [icon] Art of War is up', its changes as the summary.
---@param index number
---@param condition table
---@param byKey table<string, table>
---@param display table
---@param triggerChip fun(index: number, trigger: table): string
---@return string title, string? summary
local function Title(index, condition, byKey, display, triggerChip)
    local check = condition.check or {}
    local trigger, def = CheckDef(display, check)
    local name = CHECK_NAMES[check.variable]
    local ifText
    if CDM.COMBINATIONS[check.variable] then
        ifText = format('%s (%d)', check.variable == 'AND' and L['All of'] or L['Any of'], #(check.checks or {}))
    elseif def and def.secret and trigger then
        ifText = format(AURA_TITLES[check.variable], triggerChip(check.trigger, trigger))
    elseif def and name then
        if def.type == 'number' then
            name = format('%s %s %s', name, check.op or '<', tostring(check.value or 0))
        elseif def.type == 'bool' and check.value == false then
            name = format(L['Not %s'], name)
        end
        ifText = check.trigger > 0 and trigger and format('%s %s', triggerChip(check.trigger, trigger), name) or name
    end
    local title = ifText and format('%d. %s', index, ifText) or format('%d.', index)

    local secret = def ~= nil and def.secret == true
    local names = {}
    for _, change in ipairs(condition.changes or {}) do
        local entry = change.property and byKey[change.property]
        local value = change.value
        local text = entry and (secret and check.variable ~= 'missing' and entry.overlayText or entry.text)
        if entry and entry.overlayText and secret and entry.kind == 'bool' then
            names[#names + 1] = value ~= false and text or format('%s %s', text, L['OFF'])
        elseif entry and entry.kind == 'bool' then
            names[#names + 1] = format('%s %s', text, value ~= false and L['ON'] or L['OFF'])
        elseif entry and entry.kind == 'color' and type(value) == 'table' then
            local r, g, b = value[1] or 1, value[2] or 1, value[3] or 1
            local hex = format('#%02X%02X%02X', r * 255, g * 255, b * 255)
            -- Drawn in its own colour, lifted toward white just enough to read on the dark header when it's very dark.
            local light = 0.299 * r + 0.587 * g + 0.114 * b
            if light < MIN_LIGHT then
                local lift = (MIN_LIGHT - light) / (1 - light)
                r, g, b = r + (1 - r) * lift, g + (1 - g) * lift, b + (1 - b) * lift
            end
            names[#names + 1] = format('%s |cff%02x%02x%02x%s|r', text, r * 255, g * 255, b * 255, hex)
        elseif entry and value ~= nil and type(value) ~= 'table' then
            names[#names + 1] = format('%s %s', text, tostring(value))
        elseif entry then
            names[#names + 1] = text
        end
    end
    return title, names[1] and tconcat(names, ', ') or nil
end

---Every check a condition line can use, grouped under the trigger it reads; WeakAuras' If list.
---@param display table
---@param triggerTitle fun(index: number, trigger: table): string
---@param depth number how deep inside combinations the line sits
---@param removable boolean
---@return table[]
local function IfOptions(display, triggerTitle, depth, removable)
    local options = {}
    if depth < MAX_DEPTH then
        options[1] = { value = 'header:combinations', text = L['Combinations'], header = true }
        options[2] = { value = 'AND', text = L['All of'] }
        options[3] = { value = 'OR', text = L['Any of'] }
    end
    local function addGroup(index, trigger, title)
        local checks = CheckOptions(trigger, depth > 0)
        if not checks[1] then return end
        options[#options + 1] = { value = 'header:' .. index, text = title, header = true }
        for _, option in ipairs(checks) do
            options[#options + 1] = { value = index .. ':' .. option.value, text = option.text }
        end
    end
    for index, trigger in ipairs(display.Triggers) do addGroup(index, trigger, triggerTitle(index, trigger)) end
    addGroup(0, CDM.GLOBAL_TRIGGER, L['Global Conditions'])
    addGroup(-1, CDM.GROUP_TRIGGER, L['Group Conditions'])
    if removable then options[#options + 1] = { value = REMOVE, text = L['Remove'], color = Theme.error, action = true } end
    return options
end

---Point a check at an If option; a plain check turned into a combination becomes its first part.
---@param display table
---@param check table
---@param value string
local function SetCheck(display, check, value)
    if CDM.COMBINATIONS[value] then
        if not CDM.COMBINATIONS[check.variable] then
            local _, def = CheckDef(display, check)
            check.checks = {}
            if def and not def.secret then
                check.checks[1] = { trigger = check.trigger, variable = check.variable, op = check.op, value = check.value }
            end
            check.trigger, check.op, check.value = nil, nil, nil
        end
        check.variable = value
        return
    end

    local triggerIndex, variable = value:match('^(%-?%d+):(.+)$')
    check.trigger, check.variable, check.checks = tonumber(triggerIndex), variable, nil
    local _, def = CheckDef(display, check)
    if def and def.type == 'number' then
        check.op, check.value = '<', 3
    elseif def and def.type == 'select' then
        check.op, check.value = nil, SELECT_OPTIONS[def.options][1].value
    else
        check.op, check.value = nil, true
    end
end

---The value half of a check's line: True/False, or an operator and a number.
---@param row table
---@param check table
---@param def table
---@param apply fun()
local function ValueControls(row, check, def, apply)
    if def.type == 'select' then
        row:Dropdown(nil, {
            width = 0.5,
            options = SELECT_OPTIONS[def.options],
            value = check.value,
            callback = function(value)
                check.value = value
                apply()
            end,
        })
    elseif def.type == 'number' then
        row:Dropdown(nil, {
            width = 0.15,
            options = OPERATORS,
            value = check.op or '<',
            callback = function(value)
                check.op = value
                apply()
            end,
        })
        row:EditBox(nil, {
            width = 0.35,
            value = tostring(check.value or 0),
            callback = function(text)
                check.value = tonumber(text) or 0
                apply()
            end,
        })
    else
        row:Dropdown(nil, {
            width = 0.5,
            options = BOOLEAN,
            value = tostring(check.value ~= false),
            callback = function(value)
                check.value = value == 'true'
                apply()
            end,
        })
    end
end

---@param row table
---@param entry table
---@param change table
---@param set fun(value: any)
---@param edit fun(fn: fun())
local function ValueWidget(row, entry, change, set, edit)
    if entry.kind == 'bool' then
        local on = change.value ~= false
        row:Checkbox(on and L['ON'] or L['OFF'], {
            width = 0.5,
            value = on,
            callback = function(checked) edit(function() change.value = checked end) end,
        })
    elseif entry.kind == 'icon' then
        row:EditBox(L['Icon'], {
            width = 0.4,
            tooltip = L['An icon file ID.'],
            value = change.value and tostring(change.value) or '',
            callback = function(text) edit(function() change.value = tonumber(text) end) end,
        })
        IconPicker:BrowseButton(row, change.value, function()
            IconPicker:Open(change.value, function(texture) change.value = texture end) -- this card is gone by then; the picker re-applies
        end)
    elseif entry.kind == 'color' then
        row:ColorPicker(L['Color'], {
            width = 0.5,
            value = change.value,
            callback = function(r, g, b, a) set({ r, g, b, a }) end,
        })
    elseif entry.kind == 'alpha' then
        row:Slider(L['Alpha'], {
            width = 0.5,
            min = 0,
            max = 1,
            step = 0.05,
            value = change.value,
            callback = set,
        })
    elseif entry.kind == 'fontSize' then
        row:Slider(L['Size'], {
            width = 0.5,
            min = 6,
            max = 72,
            step = 1,
            value = change.value,
            callback = set,
        })
    elseif entry.kind == 'text' then
        row:EditBox(L['Display Text'], {
            width = 0.5,
            value = change.value or '',
            callback = function(text) edit(function() change.value = text end) end,
        })
    elseif entry.kind == 'sound' then
        row:Dropdown(L['Sound'], {
            width = 0.5,
            media = 'sound',
            searchable = true,
            value = change.value or 'None',
            callback = function(value) edit(function() change.value = value end) end,
        })
    end
end

---The Conditions tab for one icon: WeakAuras' "If Trigger N: check, then these changes" list.
---@param page table
---@param id string
---@param apply fun()
---@param triggerTitle fun(index: number, trigger: table): string
---@param triggerChip fun(index: number, trigger: table): string the trigger's icon and name, which names the layer it draws
function ConditionsTab:Build(page, id, apply, triggerTitle, triggerChip)
    local display = CDM:Get(id)
    if not CDM.LAYERED_TYPES[display.type] then
        page:Card(L['Conditions'], 'all'):Row(rowHL, 0):Text(nil, { width = 1, text = L['Conditions are set per icon.'], bgMode = 'hide' })
        return
    end
    local conditions = display.Conditions
    local triggers = display.Triggers

    local firstCheck
    for index, trigger in ipairs(triggers) do
        local _, variable = CheckOptions(trigger)
        if variable and not firstCheck then firstCheck = { trigger = index, variable = variable, value = true } end
    end

    page:Card(L['Conditions'], 'all'):Rebuild(function(card)
        local function Edit(fn)
            fn()
            apply()
            card:Rebuild()
        end

        local properties, byKey = PropertyList(display)

        ---One check's line, then its parts when it's a combination, one empty line after them to add another.
        ---@param check table
        ---@param depth number
        ---@param label string?
        ---@param parentChecks table[]? the combination it's part of, which Remove takes it out of
        ---@param subIndex number?
        local function IfLine(check, depth, label, parentChecks, subIndex)
            local _, def = CheckDef(display, check)
            local combination = CDM.COMBINATIONS[check.variable]

            local row = card:Row(rowH, nil, depth * INDENT)
            row:Dropdown(label, {
                width = 0.5,
                tooltip = def and def.secret and (check.variable == 'missing' and L["The game hides whether an aura is up, so this check can't be combined with others and only changes the placeholder."]
                    or L["The game hides whether an aura is up, so this check can't be combined with others and only changes the aura's own button."]) or nil,
                options = IfOptions(display, triggerTitle, depth, parentChecks ~= nil),
                value = combination and check.variable or (check.trigger and check.variable and check.trigger .. ':' .. check.variable) or nil,
                callback = function(value)
                    Edit(function()
                        if value == REMOVE then tremove(parentChecks, subIndex) else SetCheck(display, check, value) end
                    end)
                end,
            })
            if def and not def.secret then ValueControls(row, check, def, apply) end
            if not combination then return end

            check.checks = check.checks or {}
            local join = check.variable == 'AND' and L['and %s'] or L['or %s']
            local joinWord = check.variable == 'AND' and L['and'] or L['or']
            for i, sub in ipairs(check.checks) do
                local subTrigger = sub.trigger and sub.trigger > 0 and display.Triggers[sub.trigger]
                local title = subTrigger and triggerTitle(sub.trigger, subTrigger)
                local subLabel = title
                if i > 1 then subLabel = title and format(join, title) or joinWord end
                IfLine(sub, depth + 1, subLabel, check.checks, i)
            end

            card:Row(rowH, nil, (depth + 1) * INDENT):Dropdown(check.checks[1] and joinWord or nil, {
                width = 0.5,
                options = IfOptions(display, triggerTitle, depth + 1, false),
                callback = function(value)
                    Edit(function()
                        local sub = {}
                        SetCheck(display, sub, value)
                        tinsert(check.checks, sub)
                    end)
                end,
            })
        end

        for index, condition in ipairs(conditions) do
            local check = condition.check
            local trigger, def = CheckDef(display, check)
            local secret = def ~= nil and def.secret == true
            local linked = condition.linked and index > 1

            local open = condOpen[index]
            if open == nil then open = #conditions <= 2 end

            local title, summary = Title(index, condition, byKey, display, triggerChip)
            local expanded = card:Section(title, {
                key = 'cdm:condition:' .. index,
                summary = summary,
                collapsed = not open,
                onToggle = function()
                    condOpen[index] = not open
                    card:Rebuild()
                end,
                onMoveUp = index > 1 and function()
                    Edit(function() conditions[index], conditions[index - 1] = conditions[index - 1], conditions[index] end)
                end or nil,
                onMoveDown = index < #conditions and function()
                    Edit(function() conditions[index], conditions[index + 1] = conditions[index + 1], conditions[index] end)
                end or nil,
                onDuplicate = function()
                    Edit(function() tinsert(conditions, index + 1, CopyTable(condition)) end)
                end,
                onDelete = function()
                    Edit(function() tremove(conditions, index) end)
                end,
            })

            if expanded then
                local ifLabel = linked and L['Else If'] or L['If']
                if check.trigger and check.trigger > 0 and trigger then
                    ifLabel = format(linked and L['Else If %s'] or L['If %s'], triggerTitle(check.trigger, trigger))
                end
                IfLine(check, 0, ifLabel)


                condition.changes = condition.changes or {}
                for changeIndex, change in ipairs(condition.changes) do
                    local used = {}
                    for other, otherChange in ipairs(condition.changes) do
                        if other ~= changeIndex and otherChange.property then used[otherChange.property] = true end
                    end
                    local options = {}
                    for _, entry in ipairs(properties) do
                        if not used[entry.key] and Allowed(entry, check.variable, secret) then
                            options[#options + 1] = { value = entry.key, text = secret and check.variable ~= 'missing' and entry.overlayText or entry.text }
                        end
                    end
                    options[#options + 1] = { value = REMOVE, text = L['Remove this property'], color = Theme.error, action = true }

                    local changeRow = card:Row(rowH)
                    changeRow:Dropdown(changeIndex == 1 and L['Then'] or L['And'], {
                        width = 0.5,
                        options = options,
                        value = change.property,
                        callback = function(value)
                            Edit(function()
                                if value == REMOVE then
                                    tremove(condition.changes, changeIndex)
                                else
                                    change.property = value
                                    change.value = DefaultValue(byKey[value])
                                end
                            end)
                        end,
                    })
                    local entry = change.property and byKey[change.property]
                    if entry then
                        ValueWidget(changeRow, entry, change, function(value)
                            change.value = value
                            apply()
                        end, Edit)
                    end
                end

                local addRow = card:Row(index > 1 and rowH or 30)
                addRow:Button(L['Add Property Change'], {
                    width = 0.5,
                    height = 24,
                    yOffset = index > 1 and -14 or nil,
                    callback = function() Edit(function() condition.changes[#condition.changes + 1] = {} end) end,
                })
                if index > 1 then
                    addRow:Checkbox(L['Else If'], {
                        width = 0.5,
                        tooltip = L['Only checked when the condition above it does not match.'],
                        value = condition.linked == true,
                        callback = function(checked) Edit(function() condition.linked = checked or nil end) end,
                    })
                end
                if index < #conditions then card:Separator() end -- the last one meets the divider above Add Condition
            end
        end
        card:EndSection()

        card:Separator()

        card:Row(24):Button(L['Add Condition'], {
            width = 1,
            height = 24,
            callback = function()
                Edit(function()
                    conditions[#conditions + 1] = { check = CopyTable(firstCheck or { trigger = 0, variable = 'combat', value = true }), changes = { {} } }
                    condOpen[#conditions] = true
                end)
            end,
        })
    end)
end

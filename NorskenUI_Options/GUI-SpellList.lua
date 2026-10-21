---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class NRSKNUI.GUISpellList
local SpellList = {}
NRSKNUI.GUISpellList = SpellList
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local Premade = NRSKNUI.AuraFiltersPremade

local ipairs, pairs, tonumber, tostring, next = ipairs, pairs, tonumber, tostring, next
local format = string.format
local tinsert, tsort = table.insert, table.sort
local setmetatable = setmetatable
local CopyTable = CopyTable
local strtrim = strtrim
local rad = math.rad
local GetSpellInfo = C_Spell.GetSpellInfo

local ROW_HEIGHT = 32
local ICON_SIZE = 24
local BUTTON_ROW_HEIGHT = 30
local CROSS_WIDTH = 0.06
local UNKNOWN_ICON = 134400
local CROSS = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomCrossv3.png'
local DELETE_COLOR = { 1, 0, 0 }

local states = setmetatable({}, { __mode = 'k' })

---The picked group survives the rebuilds a list goes through.
---@param source table
---@return table
local function State(source)
    local state = states[source.key]
    if not state then
        state = {}
        states[source.key] = state
    end
    return state
end

---@param entries table[]
---@return table<string, { on: number, total: number }>
local function GroupCounts(entries)
    local counts = {}
    for _, entry in ipairs(entries) do
        local count = counts[entry.group] or { on = 0, total = 0 }
        count.total = count.total + 1
        if entry.on then count.on = count.on + 1 end
        counts[entry.group] = count
    end
    return counts
end

---The group a shipped list opens on: the player's class when the list has it, else the first group it has.
---@param state table
---@param counts table
local function EnsureGroup(state, counts)
    if state.group then return end
    if counts[NRSKNUI.MyClass] then
        state.group = NRSKNUI.MyClass
        return
    end
    for _, group in ipairs(Premade.Groups) do
        if counts[group] then
            state.group = group
            return
        end
    end
    state.group = NRSKNUI.MyClass
end

---@param group string
---@return string
local function GroupLabel(group)
    local name = Premade:GetGroupName(group)
    return Premade:IsClassGroup(group) and NRSKNUI:ColorTextByClass(name, group) or name
end

local function Muted(text)
    return NRSKNUI:ColorText(tostring(text), Theme.textMuted)
end

---@param text string?
---@return table? info
local function Lookup(text)
    text = strtrim(text or '')
    if text == '' then return nil end
    -- Names only resolve for spells in the player's own spellbook, IDs always do.
    local info = GetSpellInfo(tonumber(text) or text)
    return info and info.spellID and info or nil
end

---@param card KajiGUIFluentCard
---@param source table
function SpellList:BuildAdd(card, source)
    local state = State(source)
    local entries = source.entries()
    local listed = {}
    for _, entry in ipairs(entries) do listed[entry.id] = true end

    local found, text, addButton = nil, '', nil

    local function Refresh()
        found = Lookup(text)

        local label
        if not found then
            label = text == '' and L['Add'] or L['No spell found']
        elseif listed[found.spellID] then
            label = format(L['%s is already listed'], found.name)
        elseif source.grouped then
            label = format(L['Add %s to %s'], found.name, Premade:GetGroupName(state.group))
        else
            label = format(L['Add %s'], found.name)
        end
        addButton:SetLabel(label)
        addButton:SetEnabled(found ~= nil and not listed[found.spellID])
    end

    local function Add()
        if not found then return end
        source.add(found.spellID, state.group)
        source.onChange()
    end

    local inputRow = card:Row(rowH)
    inputRow:EditBox(L['Add Spell'], {
        width = 0.5,
        tooltip = L['A spell ID, or the name of a spell you know.'],
        onTextChanged = function(value)
            text = value
            Refresh()
        end,
    })

    local buttonConfig = { width = 0.5, height = 24, yOffset = -14, callback = Add }
    if source.grouped then
        local counts = GroupCounts(entries)
        EnsureGroup(state, counts)

        local options = {}
        for _, group in ipairs(Premade.Groups) do
            local count = counts[group]
            local label = count and format('%s  %s', GroupLabel(group), Muted(format('%d/%d', count.on, count.total))) or GroupLabel(group)
            options[#options + 1] = { value = group, text = label }
        end
        inputRow:Dropdown(L['Group'], {
            width = 0.5,
            options = options,
            value = state.group,
            tooltip = L['The group the list shows, and where an added spell goes.'],
            callback = function(group)
                if group == state.group then return end
                state.group = group
                source.onChange()
            end,
        })

        buttonConfig.width, buttonConfig.yOffset = 1, nil
        addButton = card:Row(BUTTON_ROW_HEIGHT):Button(L['Add'], buttonConfig) --[[@as KajiGUIButton]]
    else
        addButton = inputRow:Button(L['Add'], buttonConfig) --[[@as KajiGUIButton]]
    end

    Refresh()
end

---A listed spell's ID typed over in place; Enter or leaving the box takes it.
---@param card KajiGUIFluentCard
---@param source table
---@param entry table
---@param striped boolean
---@param listed table<number, true>
local function EditRow(card, source, entry, striped, listed)
    local state = State(source)
    local row = card:Row(ROW_HEIGHT, 0):Stripe(striped)
    row:Icon({ width = 0.08, size = ICON_SIZE, yOffset = -(ROW_HEIGHT - ICON_SIZE) / 2, texture = entry.icon })
    row:EditBox(nil, {
        width = 1 - 0.08 - CROSS_WIDTH,
        inlineLabel = true,
        labelWidth = 0,
        yOffset = -(ROW_HEIGHT - 24) / 2,
        tooltip = L['A spell ID, or the name of a spell you know.'],
        value = tostring(entry.id),
        autoFocus = true,
        callback = function(text)
            -- Enter also loses focus, so the box answers twice; only the first one counts
            if state.editing ~= entry.id then return end
            state.editing = nil

            local found = Lookup(text)
            if found and not listed[found.spellID] then
                if source.replace then
                    source.replace(entry.id, found.spellID)
                else
                    source.remove(entry.id)
                    source.add(found.spellID, entry.group)
                end
            end
            source.onChange()
        end,
    })
end

---@param card KajiGUIFluentCard
---@param source table
---@param entry table
---@param striped boolean
---@param linkTo? KajiGUIIcon the previous row's icon, for the guide line
---@return KajiGUIIcon
local function SpellRow(card, source, entry, striped, linkTo)
    local row = card:Row(ROW_HEIGHT, 0):Stripe(striped)

    local icon = row:Icon({
        width = 1 - CROSS_WIDTH,
        size = ICON_SIZE,
        yOffset = -(ROW_HEIGHT - ICON_SIZE) / 2,
        texture = entry.icon,
        linkTo = linkTo,
        dimmed = not entry.on,
        text = { text = entry.name, description = tostring(entry.id), color = Theme.textPrimary },
        tooltip = function(gameTooltip)
            gameTooltip:SetSpellByID(entry.id)
            local muted = Theme.textMuted
            gameTooltip:AddLine(L['Left-click to change its spell ID'], muted[1], muted[2], muted[3])
            if source.toggle then
                gameTooltip:AddLine(entry.on and L['Right-click to switch it off'] or L['Right-click to switch it on'], muted[1], muted[2], muted[3])
            end
        end,
        onClick = function(button)
            if button == 'LeftButton' then
                State(source).editing = entry.id
            elseif button == 'RightButton' and source.toggle then
                source.toggle(entry.id, not entry.on)
            else
                return
            end
            source.onChange()
        end,
    })
    row:Button('', {
        width = CROSS_WIDTH,
        height = ROW_HEIGHT,
        bare = true,
        image = CROSS, -- the skinning module's close cross
        imageSize = 12,
        imageRotation = rad(45),
        imageColor = DELETE_COLOR,
        tooltip = entry.shipped and L['Hide from the list until Reset'] or L['Remove'],
        callback = function()
            source.remove(entry.id)
            source.onChange()
        end,
    })
    return icon
end

---@param card KajiGUIFluentCard
---@param source table
function SpellList:BuildList(card, source)
    local state = State(source)
    local entries = source.entries()

    for _, entry in ipairs(entries) do
        local info = GetSpellInfo(entry.id)
        entry.name = info and info.name or format(L['Unknown spell %d'], entry.id)
        entry.icon = info and info.iconID or UNKNOWN_ICON
    end

    local function Reset()
        NRSKNUI:CreatePrompt({
            title = L['Reset to Default'],
            text = L['Remove the spells you added and switch every default spell back on?'],
            onAccept = function()
                source.reset()
                source.onChange()
            end,
            acceptText = L['Reset'],
            cancelText = L['Cancel'],
        })
    end

    if source.reset and source.isModified() then
        card:Row(BUTTON_ROW_HEIGHT):Button(L['Reset to Default'], { width = 1, height = BUTTON_ROW_HEIGHT - 4, callback = Reset })
    end

    if not entries[1] then
        card:Row(24):Text(nil, { width = 1, height = 24, text = Muted(L['No spells yet.']), bgMode = 'hide' })
        return
    end

    if source.grouped then EnsureGroup(state, GroupCounts(entries)) end
    local shown, listed = {}, {}
    for _, entry in ipairs(entries) do
        listed[entry.id] = true
        if not source.grouped or entry.group == state.group then tinsert(shown, entry) end
    end
    if not source.ordered then
        tsort(shown, function(a, b) return a.name < b.name end)
    end

    if not shown[1] then
        card:Row(24):Text(nil, {
            width = 1,
            height = 24,
            text = Muted(L['No spells in this group yet.']),
            bgMode = 'hide',
        })
        return
    end

    local previous
    for index, entry in ipairs(shown) do
        if state.editing == entry.id then
            EditRow(card, source, entry, index % 2 == 0, listed)
            previous = nil
        else
            previous = SpellRow(card, source, entry, index % 2 == 0, previous)
        end
    end
end

---holder.Removed[id]: true switches a spell off, 'hidden' also drops a shipped spell from the list.
---@param holder table
---@param listKey string the preset whose spells are shipped
---@param onChange fun()
---@return table source
function SpellList:ShippedSource(holder, listKey, onChange)
    local function SetRemoved(id, value)
        holder.Removed = holder.Removed or {}
        holder.Removed[id] = value
        if not next(holder.Removed) then holder.Removed = nil end
    end

    return {
        key = holder,
        grouped = true,
        entries = function()
            local list, shipped = {}, Premade:GetShippedSpells(listKey) or {}
            local removed = holder.Removed or {}
            for id, group in pairs(shipped) do
                if removed[id] ~= 'hidden' then
                    tinsert(list, { id = id, group = group, on = not removed[id], shipped = true })
                end
            end
            for id, group in pairs(holder.Added or {}) do
                if not shipped[id] then tinsert(list, { id = id, group = group, on = not removed[id] }) end
            end
            return list
        end,
        add = function(id, group)
            holder.Added = holder.Added or {}
            holder.Added[id] = group
        end,
        remove = function(id)
            local shipped = Premade:GetShippedSpells(listKey) or {}
            if shipped[id] then
                SetRemoved(id, 'hidden')
                return
            end
            holder.Added[id] = nil
            if not next(holder.Added) then holder.Added = nil end
            SetRemoved(id, nil)
        end,
        toggle = function(id, on) SetRemoved(id, (not on) or nil) end,
        reset = function() holder.Added, holder.Removed = nil, nil end,
        isModified = function() return holder.Added ~= nil or holder.Removed ~= nil end,
        onChange = onChange,
    }
end

---A trigger's own list: { [id] = true } for a spell that is on, false for one switched off.
---@param map table
---@param onChange fun()
---@return table source
function SpellList:MapSource(map, onChange)
    return {
        key = map,
        grouped = false,
        entries = function()
            local list = {}
            for id, value in pairs(map) do tinsert(list, { id = id, on = value ~= false }) end
            return list
        end,
        add = function(id) map[id] = true end,
        remove = function(id) map[id] = nil end,
        replace = function(old, new)
            map[new] = map[old]
            map[old] = nil
        end,
        toggle = function(id, on) map[id] = on end,
        onChange = onChange,
    }
end

---A plain list of spell IDs, kept in its order since the first can matter (the icon a trigger shows).
---@param key table what the list's edit state hangs off across rebuilds
---@param get fun(): number[]
---@param set fun(ids: number[]) gets a fresh list, empty when the last spell is removed
---@param onChange fun()
---@return table source
function SpellList:ArraySource(key, get, set, onChange)
    return {
        key = key,
        grouped = false,
        ordered = true,
        entries = function()
            local list = {}
            for _, id in ipairs(get()) do tinsert(list, { id = id, on = true }) end
            return list
        end,
        add = function(id)
            local ids = CopyTable(get())
            ids[#ids + 1] = id
            set(ids)
        end,
        remove = function(id)
            local ids = {}
            for _, other in ipairs(get()) do
                if other ~= id then ids[#ids + 1] = other end
            end
            set(ids)
        end,
        replace = function(old, new)
            local ids = CopyTable(get())
            for i, other in ipairs(ids) do
                if other == old then ids[i] = new end
            end
            set(ids)
        end,
        onChange = onChange,
    }
end

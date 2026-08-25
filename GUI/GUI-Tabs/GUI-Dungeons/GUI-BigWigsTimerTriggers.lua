---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class BigWigsTimersModule
local BigWigsTimers = NRSKNUI:GetModule('BigWigsTimers')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs, pairs = ipairs, pairs
local insert, sort = table.insert, table.sort
local format, tonumber, tostring = string.format, tonumber, tostring
local strlower = string.lower

local PAGE_DUNGEONS = 'bwTimersDungeons'
local PAGE_RAIDS = 'bwTimersRaids'
local BOSS_HEADER_HEIGHT = 18
local SPELL_ROW_HEIGHT = 28

local COUNT_TOOLTIP = 'Which occurrences of the bar to match, using the count BigWigs shows in brackets.\n\n' ..
    '2, 5, 6   the 2nd, 5th and 6th\n' ..
    '2-6       the 2nd through 6th\n' ..
    '/2        every 2nd\n' ..
    '2/3       every 3rd starting from the 2nd\n' ..
    '2-11/3    every 3rd from the 2nd to the 11th\n\n' ..
    'Leave empty to match every occurrence.'

local FORMAT_TOOLTIP = L['%n bar text, %t time left, %c count, %i icon, %s spell ID']

local DISPLAY_TYPES = {
    { key = 'bar',  text = L['Bar'] },
    { key = 'text', text = L['Text Only'] },
}

-- Search text per instance, so switching timers inside one dungeon keeps the filter.
local spellSearch = {}

local function Apply() BigWigsTimers:ApplySettings() end

---@param instanceId number
---@param triggerId number
---@return string
local function MakeKey(instanceId, triggerId)
    return format('%d:%d', instanceId, triggerId)
end

---@param instanceId number
---@param journalId number 0 for the group holding timers that belong to no encounter
---@return string
local function BossKey(instanceId, journalId)
    return format('boss:%d:%d', instanceId, journalId)
end

---@param key string?
---@return number? instanceId, number? triggerId
local function ParseKey(key)
    if not key then return end

    local instanceId, triggerId = key:match('^(%d+):(%d+)$')

    return tonumber(instanceId), tonumber(triggerId)
end

---@param kind 'dungeon'|'raid'
---@return BigWigsTimers.SeasonInstance[]
local function SortedInstances(kind)
    local list = {}

    for _, info in pairs(BigWigsTimers:GetSeasonData()) do
        if info.type == kind then insert(list, info) end
    end
    sort(list, function(a, b) return a.name < b.name end)

    return list
end

---@return table? sidebar the open window's mini-sidebar
local function Sidebar()
    local window = NRSKNUI.GUIFrame

    return window and window.content and window.content.miniSidebar
end

---@param pageId string
---@param selectKey string?
local function Reopen(pageId, selectKey)
    local window = NRSKNUI.GUIFrame
    if not (window and window.content) then return end

    window.content:ShowPage(pageId, selectKey and { itemKey = selectKey } or nil)
end

-- Sidebar --

---Groups are always emitted, empty or not, so an instance with no timers is still reachable.
---@param kind 'dungeon'|'raid'
---@return fun(): table[]
local function SidebarItems(kind)
    return function()
        local instances = NRSKNUI.db.profile.BigWigsTimers.Instances
        local items = {}

        for _, info in ipairs(SortedInstances(kind)) do
            local instance = instances[info.instanceId]
            local headers, byBoss, loose = {}, {}, {}

            if kind == 'raid' then
                insert(items, { type = 'label', key = 'raid:' .. info.instanceId, text = info.name })

                for _, boss in ipairs(BigWigsTimers:GetBossesForInstance(info.instanceId)) do
                    local header = {
                        type = 'header',
                        key = BossKey(info.instanceId, boss.journalId),
                        text = format('B%d %s', boss.num, boss.name),
                        defaultExpanded = false,
                        items = {},
                    }

                    byBoss[boss.journalId] = header.items
                    insert(headers, header)
                end
            end

            if instance then
                for _, trigger in ipairs(instance.Triggers) do
                    local spellId = tonumber(trigger.SpellId)

                    insert(byBoss[trigger.BossId] or loose, {
                        key = MakeKey(info.instanceId, trigger.Id),
                        text = trigger.Name,
                        icon = spellId and spellId > 0 and C_Spell.GetSpellTexture(spellId) or nil,
                    })
                end
            end

            if kind == 'dungeon' then
                insert(headers, {
                    type = 'header',
                    key = 'instance:' .. info.instanceId,
                    text = info.name,
                    defaultExpanded = false,
                    items = loose,
                })
            elseif #loose > 0 or #headers == 0 then
                insert(headers, {
                    type = 'header',
                    key = BossKey(info.instanceId, 0),
                    text = L['Unassigned'],
                    defaultExpanded = false,
                    items = loose,
                })
            end

            for _, header in ipairs(headers) do insert(items, header) end
        end

        return items
    end
end

---Re-render the mini-sidebar in place, so a renamed timer or a new spell icon shows up without
---rebuilding the whole page (which would restart the preview).
---@param kind 'dungeon'|'raid'
---@param expandKey string? a group to open, so a timer that just moved into it stays in view
local function RefreshSidebar(kind, expandKey)
    local sidebar = Sidebar()
    if not sidebar then return end

    local selected = sidebar:GetSelected()

    sidebar:SetItems(SidebarItems(kind)())
    if expandKey then sidebar:SetExpanded(expandKey, true) end
    sidebar:SetSelected(selected)
end

---@param pageId string
---@param groupKey string the sidebar header the timer is created under
local function NewTimerPrompt(pageId, groupKey)
    local instanceId, bossId = groupKey:match('^boss:(%d+):(%d+)$')

    instanceId = tonumber(instanceId) or tonumber(groupKey:match('^instance:(%d+)$'))
    bossId = tonumber(bossId) or 0
    if not instanceId then return end

    NRSKNUI:CreatePrompt({
        title = L['New Timer'],
        text = '',
        editBox = true,
        editBoxLabel = L['Timer Name'],
        onAccept = function(name)
            local trigger = BigWigsTimers:CreateTrigger(instanceId, name, bossId)
            local sidebar = Sidebar()

            -- The new timer is the selection, so its group has to be open for it to be seen.
            if sidebar then sidebar:SetExpanded(groupKey, true) end

            Apply()
            Reopen(pageId, MakeKey(instanceId, trigger.Id))
        end,
        acceptText = L['Create'],
        cancelText = L['Cancel'],
    })
end

---@param pageId string
---@param kind 'dungeon'|'raid'
---@param instanceId number
---@param triggerId number
---@param toInstance number
---@param bossId number
local function MoveTo(pageId, kind, instanceId, triggerId, toInstance, bossId)
    local newId = triggerId

    if toInstance ~= instanceId then
        newId = BigWigsTimers:MoveTriggerToInstance(instanceId, triggerId, toInstance)
        if not newId then return end
    end

    BigWigsTimers:SetTriggerBoss(toInstance, newId, bossId)

    local sidebar = Sidebar()

    if sidebar then
        sidebar:SetExpanded(kind == 'raid' and BossKey(toInstance, bossId) or ('instance:' .. toInstance), true)
    end

    Apply()
    Reopen(pageId, MakeKey(toInstance, newId))
end

---@param pageId string
---@param kind 'dungeon'|'raid'
---@return fun(key: string, item: table)
local function ContextMenu(pageId, kind)
    return function(key, item)
        -- Right-clicking a group header is the only way to add a timer to an empty one.
        if item and item.type == 'header' then
            GUI:ShowContextMenu({
                { text = L['New Timer'], onClick = function() NewTimerPrompt(pageId, key) end },
            })

            return
        end

        local instanceId, triggerId = ParseKey(key)
        local trigger = instanceId and triggerId and BigWigsTimers:GetTrigger(instanceId, triggerId)
        if not trigger or not instanceId or not triggerId then return end

        local entries = {
            {
                text = L['Rename'],
                onClick = function()
                    NRSKNUI:CreatePrompt({
                        title = L['Rename Timer'],
                        text = trigger.Name,
                        editBox = true,
                        editBoxLabel = L['Timer Name'],
                        onAccept = function(name)
                            if not name or name == '' then return end

                            trigger.Name = name
                            Apply()
                            Reopen(pageId, key)
                        end,
                        acceptText = L['Rename'],
                        cancelText = L['Cancel'],
                    })
                end,
            },
            {
                text = L['Duplicate'],
                onClick = function()
                    local copy = BigWigsTimers:DuplicateTrigger(instanceId, triggerId)

                    Apply()
                    Reopen(pageId, copy and MakeKey(instanceId, copy.Id))
                end,
            },
            {
                text = L['Delete'],
                onClick = function()
                    NRSKNUI:CreatePrompt({
                        title = L['Delete Timer'],
                        text = format(L["Delete the timer '%s'? This cannot be undone."], trigger.Name),
                        onAccept = function()
                            BigWigsTimers:DeleteTrigger(instanceId, triggerId)
                            Apply()
                            Reopen(pageId)
                        end,
                        acceptText = L['Delete'],
                        cancelText = L['Cancel'],
                    })
                end,
            },
            { divider = true },
            {
                text = L['Move Up'],
                onClick = function()
                    BigWigsTimers:MoveTrigger(instanceId, triggerId, -1)
                    Apply()
                    Reopen(pageId, key)
                end,
            },
            {
                text = L['Move Down'],
                onClick = function()
                    BigWigsTimers:MoveTrigger(instanceId, triggerId, 1)
                    Apply()
                    Reopen(pageId, key)
                end,
            },
            { divider = true },
        }

        for _, info in ipairs(SortedInstances(kind)) do
            local target = info.instanceId

            if kind == 'dungeon' then
                if target ~= instanceId then
                    insert(entries, {
                        text = format(L['Move to %s'], info.name),
                        onClick = function() MoveTo(pageId, kind, instanceId, triggerId, target, 0) end,
                    })
                end
            else
                local heading = #entries + 1

                insert(entries, { text = info.name, disabled = true })

                for _, boss in ipairs(BigWigsTimers:GetBossesForInstance(target)) do
                    if target ~= instanceId or boss.journalId ~= trigger.BossId then
                        insert(entries, {
                            text = format(L['Move to %s'], format('B%d %s', boss.num, boss.name)),
                            onClick = function() MoveTo(pageId, kind, instanceId, triggerId, target, boss.journalId) end,
                        })
                    end
                end

                if target ~= instanceId or trigger.BossId ~= 0 then
                    insert(entries, {
                        text = format(L['Move to %s'], L['Unassigned']),
                        onClick = function() MoveTo(pageId, kind, instanceId, triggerId, target, 0) end,
                    })
                end

                if #entries == heading then entries[heading] = nil end
            end
        end

        GUI:ShowContextMenu(entries)
    end
end

-- Spell browser --

---@param page KajiGUIPage
---@param instanceId number
---@param trigger table
---@param kind 'dungeon'|'raid'
---@param onPick fun() redraws the card holding the Spell ID box, which lives outside this one
---@return KajiGUIFluentCard card so a boss change can redraw the list
local function BuildSpellBrowser(page, instanceId, trigger, kind, onPick)
    local card = page:Card(L['Browse BigWigs Spells'], 'all')

    card:Rebuild(function(c)
        local spells = BigWigsTimers:GetSpellsForDungeon(instanceId)

        if #spells == 0 then
            c:Row(rowHL, 0):Text(L['BigWigs Spells'], {
                width = 1,
                autoHeight = true,
                bgMode = 'hide',
                text = L['No BigWigs data for this instance. Make sure BigWigs is installed and its module for this instance is available.'],
            })

            return
        end

        local filter = spellSearch[instanceId] or ''

        c:Row(rowH):EditBox(L['Search spells'], {
            width = 1,
            value = filter,
            callback = function(text)
                spellSearch[instanceId] = text
                c:Rebuild()
            end,
        })

        local needle = strlower(filter)
        local bossId = trigger.BossId
        local matched, lastBoss = 0, nil

        for _, spell in ipairs(spells) do
            if (bossId == 0 or spell.journalId == bossId) and (needle == '' or
                    strlower(spell.name):find(needle, 1, true) or
                    tostring(spell.spellId):find(needle, 1, true)) then
                matched = matched + 1

                if spell.bossName ~= lastBoss then
                    lastBoss = spell.bossName

                    local bossLabel = spell.bossNum and format('B%d %s', spell.bossNum, spell.bossName) or spell.bossName

                    c:Row(BOSS_HEADER_HEIGHT, 0):Text(NRSKNUI:ColorTextByTheme(bossLabel), {
                        width = 1,
                        height = BOSS_HEADER_HEIGHT,
                        bgMode = 'hide',
                    })
                    c:Separator()
                end

                local row = c:Row(SPELL_ROW_HEIGHT)
                local spellId = spell.spellId

                row:Icon({
                    width = 0.7,
                    size = 24,
                    showBorder = true,
                    texture = spell.icon,
                    tooltip = function(tooltip) tooltip:SetSpellByID(spellId) end,
                    text = {
                        text = format('%s|cffffffff (%d)|r', spell.name, spellId),
                        position = 'RIGHT',
                        size = 'small',
                    },
                })
                row:Button(L['Use'], {
                    width = 0.3,
                    height = 22,
                    yOffset = -3,
                    tooltip = spell.name,
                    callback = function()
                        trigger.SpellId = tostring(spellId)
                        Apply()
                        onPick()
                        RefreshSidebar(kind)
                        c:Rebuild()
                    end,
                })
            end
        end

        if matched == 0 then
            c:Row(rowHL, 0):Text(L['Search spells'], {
                width = 1,
                bgMode = 'hide',
                text = filter ~= '' and L['No spells match your search.'] or L['BigWigs has no spells for this boss.'],
            })
        end
    end)

    return card
end

-- Tabs --

---@param page KajiGUIPage
---@param instanceId number
---@param trigger table
---@param kind 'dungeon'|'raid'
local function BuildTriggerTab(page, instanceId, trigger, kind)
    local card = page:Card(L['Timer'], 'all')
    local browser -- built below, the boss dropdown redraws it

    card:Rebuild(function(c)
        local nameRow = c:Row(rowH)

        nameRow:Checkbox(L['Enabled'], {
            width = 0.5,
            value = trigger.Enabled,
            callback = function(checked)
                trigger.Enabled = checked
                Apply()
            end,
        })
        nameRow:EditBox(L['Timer Name'], {
            width = 0.5,
            value = trigger.Name,
            callback = function(text)
                if not text or text == '' then return end

                trigger.Name = text
                Apply()
                RefreshSidebar(kind)
            end,
        })

        if kind == 'raid' then
            local options = { { key = 0, text = L['Unassigned'] } }

            for _, boss in ipairs(BigWigsTimers:GetBossesForInstance(instanceId)) do
                insert(options, { key = boss.journalId, text = format('B%d %s', boss.num, boss.name) })
            end

            c:Row(rowH):Dropdown(L['Boss'], {
                width = 1,
                tooltip = L['Only bars from this encounter can match the timer.'],
                options = options,
                value = trigger.BossId,
                callback = function(bossId)
                    BigWigsTimers:SetTriggerBoss(instanceId, trigger.Id, bossId)
                    Apply()
                    RefreshSidebar(kind, BossKey(instanceId, bossId))
                    browser:Rebuild()
                end,
            })
        end

        c:Separator()

        local idRow = c:Row(rowH)

        idRow:EditBox(L['Spell ID'], {
            width = 0.5,
            tooltip = L['The BigWigs option key, usually a spell ID. Leave empty to match on message instead.'],
            value = trigger.SpellId,
            callback = function(text)
                trigger.SpellId = text
                Apply()
                RefreshSidebar(kind)
                c:Rebuild()
            end,
        })

        local spellId = tonumber(trigger.SpellId)
        local spellInfo = spellId and spellId > 0 and C_Spell.GetSpellInfo(spellId)

        idRow:Icon({
            width = 0.5,
            size = 22,
            yOffset = -14,
            texture = spellInfo and spellInfo.iconID or 134400,
            tooltip = spellInfo and function(tooltip) tooltip:SetSpellByID(spellId) end or L['No spell selected'],
            text = {
                text = spellInfo and spellInfo.name or L['No spell selected'],
                position = 'RIGHT',
            },
        })

        local msgRow = c:Row(rowH)

        msgRow:EditBox(L['Message'], {
            width = 0.5,
            tooltip = L['Matched against the bar text BigWigs shows.'],
            value = trigger.Message,
            callback = function(text)
                trigger.Message = text
                Apply()
            end,
        })
        msgRow:Dropdown(L['Match'], {
            width = 0.5,
            options = NRSKNUI.BigWigsMessageOperators,
            value = trigger.MessageOperator,
            callback = function(op)
                trigger.MessageOperator = op
                Apply()
            end,
        })

        c:Row(rowH):EditBox(L['Count'], {
            width = 1,
            tooltip = COUNT_TOOLTIP,
            value = trigger.Count,
            callback = function(text)
                trigger.Count = text
                Apply()
            end,
        })

        c:Separator()

        local remainingRow = c:Row(trigger.UseRemaining and rowH or rowHL, trigger.UseRemaining and nil or 0)

        remainingRow:Checkbox(L['Remaining Time'], {
            width = 0.5,
            tooltip = L['Only show while the time left passes this test.'],
            value = trigger.UseRemaining,
            callback = function(checked)
                trigger.UseRemaining = checked
                Apply()
                c:Rebuild()
            end,
        })
        remainingRow:Dropdown(L['Casts'], {
            width = 0.5,
            tooltip = L['BigWigs sends a cast bar alongside the cooldown timer for the same spell.'],
            value = trigger.ShowCasts,
            options = NRSKNUI.BigWigsCast,
            callback = function(val)
                trigger.ShowCasts = val
                Apply()
            end,
        })

        if trigger.UseRemaining then
            local testRow = c:Row(rowH)

            testRow:Dropdown(L['Operator'], {
                width = 0.5,
                options = NRSKNUI.BigWigsRemainingOperators,
                value = trigger.RemainingOperator,
                callback = function(op)
                    trigger.RemainingOperator = op
                    Apply()
                end,
            })
            testRow:Slider(L['Seconds'], {
                width = 0.5,
                min = 0,
                max = 120,
                step = 0.5,
                value = trigger.Remaining,
                callback = function(val)
                    trigger.Remaining = val
                    Apply()
                end,
            })
        end

        c:Row(rowHL, 0):Slider(L['Offset Timer'], {
            width = 1,
            tooltip = L['Added to the time left before every test. Positive keeps the display up past the bar, negative fires it early.'],
            min = -60,
            max = 60,
            step = 0.5,
            value = trigger.Offset,
            callback = function(val)
                trigger.Offset = val
                Apply()
            end,
        })
    end)

    browser = BuildSpellBrowser(page, instanceId, trigger, kind, function() card:Rebuild() end)
end

---@param page KajiGUIPage
---@param trigger table
local function BuildDisplayTab(page, trigger)
    local card = page:Card(L['Display'], 'all')

    card:Rebuild(function(c)
        c:Row(rowH):Dropdown(L['Style'], {
            width = 1,
            options = DISPLAY_TYPES,
            value = trigger.DisplayType,
            callback = function(key)
                trigger.DisplayType = key
                Apply()
                c:Rebuild()
            end,
        })

        c:Separator()

        if trigger.DisplayType == 'bar' then
            local textRow = c:Row(rowH)

            textRow:EditBox(L['Left Text'], {
                width = 0.5,
                tooltip = FORMAT_TOOLTIP,
                value = trigger.LeftText,
                callback = function(text)
                    trigger.LeftText = text
                    Apply()
                end,
            })
            textRow:EditBox(L['Right Text'], {
                width = 0.5,
                tooltip = FORMAT_TOOLTIP,
                value = trigger.RightText,
                callback = function(text)
                    trigger.RightText = text
                    Apply()
                end,
            })
        else
            c:Row(rowH):EditBox(L['Text'], {
                width = 1,
                tooltip = FORMAT_TOOLTIP,
                value = trigger.Text,
                callback = function(text)
                    trigger.Text = text
                    Apply()
                end,
            })
        end

        local decimalRow = c:Row(rowHL, 0)

        decimalRow:Checkbox(L['Show Decimals'], {
            width = trigger.ShowDecimals and 0.5 or 1,
            value = trigger.ShowDecimals,
            callback = function(checked)
                trigger.ShowDecimals = checked
                Apply()
                c:Rebuild()
            end,
        })

        if trigger.ShowDecimals then
            decimalRow:Slider(L['Below (seconds)'], {
                width = 0.5,
                min = 1,
                max = 30,
                step = 1,
                value = trigger.DecimalThreshold,
                callback = function(val)
                    trigger.DecimalThreshold = val
                    Apply()
                end,
            })
        end
    end)

    local colorCard = page:Card(L['Colors'], 'all')

    colorCard:Rebuild(function(c)
        local isBar = trigger.DisplayType == 'bar'

        if isBar then
            c:Row(rowH):Checkbox(L['Sync With BigWigs Bar Coloring'], {
                width = 1,
                value = trigger.UseBigWigsColors,
                callback = function(checked)
                    trigger.UseBigWigsColors = checked
                    Apply()
                    c:Rebuild()
                end,
            })
        end

        local colorRow = c:Row(rowHL, 0)

        if isBar and not trigger.UseBigWigsColors then
            colorRow:ColorPicker(L['Bar Color'], {
                width = 0.5,
                value = trigger.BarColor,
                callback = function(r, g, b, a)
                    trigger.BarColor = { r, g, b, a }
                    Apply()
                end,
            })
        end

        colorRow:ColorPicker(L['Text Color'], {
            width = (isBar and not trigger.UseBigWigsColors) and 0.5 or 1,
            value = trigger.TextColor,
            callback = function(r, g, b, a)
                trigger.TextColor = { r, g, b, a }
                Apply()
            end,
        })
    end)
end

---@param page KajiGUIPage
---@param trigger table
local function BuildActionsTab(page, trigger)
    local card = page:Card(L['Sounds'], 'all')
    local sounds = {
        { label = L['On Show'], dbKey = 'ActionOnShowSound' },
        { label = L['On Hide'], dbKey = 'ActionOnHideSound' },
    }

    for index, entry in ipairs(sounds) do
        local last = index == #sounds
        local row = card:Row(last and rowHL or rowH, last and 0 or nil)

        row:Dropdown(entry.label, {
            width = 0.5,
            media = 'sound',
            searchable = true,
            value = trigger[entry.dbKey],
            callback = function(key)
                trigger[entry.dbKey] = key
                Apply()
            end,
        })
        row:Button(L['Test'], {
            width = 0.5,
            yOffset = -14,
            height = 24,
            callback = function()
                if trigger[entry.dbKey] ~= 'None' then NRSKNUI:PlaySafeSound(trigger[entry.dbKey]) end
            end,
        })
    end
end

-- Pages --

---@param pageId string
---@param kind 'dungeon'|'raid'
---@param title string
local function RegisterTriggerPage(pageId, kind, title)
    GUI:RegisterPage(pageId, {
        mode = 'tabs',
        search = { title, L['BigWigs Timers'] },
        sidebar = {
            items = SidebarItems(kind),
            onContextMenu = ContextMenu(pageId, kind),
        },
        tabs = {
            { id = 'trigger', text = L['Trigger'] },
            { id = 'display', text = L['Display'] },
            { id = 'load',    text = L['Load'] },
            { id = 'actions', text = L['Actions'] },
        },
        build = function(page, tabId, itemKey)
            local db = NRSKNUI.db.profile.BigWigsTimers

            page:SetEnabled(function() return db.Enabled end)

            local instanceId, triggerId = ParseKey(itemKey)
            local trigger = instanceId and triggerId and BigWigsTimers:GetTrigger(instanceId, triggerId)

            BigWigsTimers:SetPreviewTrigger(trigger or nil)

            if not trigger or not instanceId then
                local card = page:Card(L['No Timer Selected'])

                card:Row(rowHL, 0):Text(L['Help'], {
                    width = 1,
                    autoHeight = true,
                    bgMode = 'hide',
                    text = L['Right-click an instance on the left and choose New Timer, or pick an existing one.'],
                })

                return
            end

            if tabId == 'trigger' then
                BuildTriggerTab(page, instanceId, trigger, kind)
            elseif tabId == 'display' then
                BuildDisplayTab(page, trigger)
            elseif tabId == 'load' then
                page:LoadConditionsCard({ db = trigger.LoadConditions, onChangeCallback = Apply })
            elseif tabId == 'actions' then
                BuildActionsTab(page, trigger)
            end
        end,
    })
end

RegisterTriggerPage(PAGE_DUNGEONS, 'dungeon', L['Dungeons'])
RegisterTriggerPage(PAGE_RAIDS, 'raid', L['Raids'])

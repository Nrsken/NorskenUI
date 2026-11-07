---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_QoL') then return end
---@class BigWigsTimersModule
local BigWigsTimers = NRSKNUI:GetModule('BigWigsTimers')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs, pairs, next, select = ipairs, pairs, next, select
local insert, sort = table.insert, table.sort
local format, tonumber, tostring = string.format, tonumber, tostring
local strlower = string.lower

local PAGE_DUNGEONS = 'bwTimersDungeons'
local PAGE_RAIDS = 'bwTimersRaids'
local BOSS_HEADER_HEIGHT = 18
local BUTTON_ROW_HEIGHT = 24 -- Kaji's own widget height, so a row of buttons takes no more than they do
local SPELL_ROW_HEIGHT = 28

local COUNT_TOOLTIP = L['Which occurrences of the bar to match, using the count BigWigs shows in brackets.'] .. '\n\n' ..
    '2, 5, 6   ' .. L['the 2nd, 5th and 6th'] .. '\n' ..
    '2-6       ' .. L['the 2nd through 6th'] .. '\n' ..
    '/2        ' .. L['every 2nd'] .. '\n' ..
    '2/3       ' .. L['every 3rd starting from the 2nd'] .. '\n' ..
    '2-11/3    ' .. L['every 3rd from the 2nd to the 11th'] .. '\n\n' ..
    L['Leave empty to match every occurrence.']

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

local expanded = {} -- [group key] = true while open, for the session; every instance starts folded
local folded = {} -- [band key] = true while closed, for the session; the bands start open
local SEASON_KEY = 'band:season'

---@param key string
---@param text string
---@return table
local function Band(key, text)
    return { key = key, text = text, collapsed = folded[key] == true, rows = {} }
end

local dungeonIcons -- [instance map ID] = the season's square dungeon icon, from the Mythic+ UI's own data

---A season dungeon's icon as the Mythic+ tab draws it (Blizzard_ChallengesUI.lua, live); the journal's
---instance art is a wide banner that crops badly, so it's only the fallback for raids.
---@param mapId number
---@return number|string?
local function InstanceIcon(mapId)
    if not dungeonIcons then
        local found = {}
        for _, challengeId in ipairs(C_ChallengeMode.GetMapTable() or {}) do
            local _, _, _, texture, _, instanceMapId = C_ChallengeMode.GetMapUIInfo(challengeId)
            if instanceMapId and texture then
                found[instanceMapId] = texture
            end
        end
        -- kept once the season's maps have answered, so an early empty read is asked again
        if next(found) then
            dungeonIcons = found
        end
    end
    if dungeonIcons and dungeonIcons[mapId] then
        return dungeonIcons[mapId]
    end

    local journalId = C_EncounterJournal.GetInstanceForGameMap(mapId)
    return journalId and select(4, EJ_GetInstanceInfo(journalId))
end

---A boss's square icon from the season table, else its portrait as the Encounter Journal's boss list draws it.
---@param encounterId number
---@return number|string?
local function BossIcon(encounterId)
    return BigWigsTimers:GetBossIcon(encounterId) or select(5, EJ_GetCreatureInfo(1, encounterId))
end

---@param key string
---@param text string
---@param icon number|string?
---@return table
local function Group(key, text, icon)
    return {
        key = key,
        text = text,
        icon = icon,
        depth = 0,
        enabled = true,
        isGroup = true,
        expanded = expanded[key] == true,
        children = {},
    }
end

---@param group table
---@param trigger table
---@param instanceId number
local function AddTimerRow(group, trigger, instanceId)
    local spellId = tonumber(trigger.SpellId)
    local enabled = trigger.Enabled ~= false

    insert(group.children, {
        key = MakeKey(instanceId, trigger.Id),
        text = trigger.Name,
        icon = spellId and spellId > 0 and C_Spell.GetSpellTexture(spellId) or nil,
        depth = 1,
        enabled = enabled,
        loadState = enabled and 'loaded' or 'unloaded',
        stateTitle = enabled and L['Enabled'] or L['Disabled'],
    })
end

---A group's timers step within it, so the first can't go up and the last can't go down.
---@param group table
local function FinishGroup(group)
    local children = group.children
    for i, child in ipairs(children) do
        child.canMoveUp = i > 1
        child.canMoveDown = i < #children
    end
    group.childCount = #children
end

---The timers as the collection tree's groups: one per dungeon under the season's band, one per boss under
---its raid's band with the unassigned ones last. Groups are always emitted, empty or not, so an instance
---with no timers can still take one.
---@param kind 'dungeon'|'raid'
---@return fun(): table
local function TreeContent(kind)
    return function()
        local instances = NRSKNUI.BigWigsTimers.db.Instances
        local sections = {}

        -- the season's dungeons share one band, titled as the Mythic+ tab counts seasons
        local dungeons
        if kind == 'dungeon' then
            local season = C_MythicPlus.GetCurrentUIDisplaySeason()
            dungeons = Band(SEASON_KEY, season and format(L['Season %d Dungeons'], season) or L['Dungeons'])
            insert(sections, dungeons)
        end

        for _, info in ipairs(SortedInstances(kind)) do
            local instance = instances[info.instanceId]
            local bosses, byBoss = {}, {}
            -- a raid is its own band, its bosses the groups in it
            local band = dungeons or Band('band:raid:' .. info.instanceId, info.name)
            if not dungeons then
                insert(sections, band)
            end

            if kind == 'raid' then
                for _, boss in ipairs(BigWigsTimers:GetBossesForInstance(info.instanceId)) do
                    local group = Group(BossKey(info.instanceId, boss.journalId), format('B%d %s', boss.num, boss.name), BossIcon(boss.journalId))

                    byBoss[boss.journalId] = group
                    insert(bosses, group)
                end
            end

            local loose = kind == 'dungeon' and Group('instance:' .. info.instanceId, info.name, InstanceIcon(info.instanceId))
                or Group(BossKey(info.instanceId, 0), L['Unassigned'], InstanceIcon(info.instanceId))

            for _, trigger in ipairs(instance and instance.Triggers or {}) do
                AddTimerRow(byBoss[trigger.BossId] or loose, trigger, info.instanceId)
            end

            for _, group in ipairs(bosses) do
                FinishGroup(group)
                insert(band.rows, group)
            end
            if kind == 'dungeon' or loose.children[1] or not bosses[1] then
                FinishGroup(loose)
                insert(band.rows, loose)
            end
        end

        return { sections = sections }
    end
end

---Re-render the tree in place, so a renamed timer or a new spell icon shows up without
---rebuilding the whole page (which would restart the preview).
---@param expandKey string? a section to open, so a timer that just moved into it stays in view
local function RefreshSidebar(expandKey)
    local sidebar = Sidebar()
    if not sidebar then return end

    local selected = sidebar:GetSelected()

    if expandKey then
        sidebar:SetExpanded(expandKey, true)
    else
        sidebar:SetItems()
    end
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

---A timer belongs to its instance for good, so the menu only edits it in place; a raid timer's boss is
---picked on its Trigger tab.
---@param pageId string
---@return fun(key: string, item: table)
local function ContextMenu(pageId)
    return function(key, item)
        if item and item.isGroup then
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
        }

        GUI:ShowContextMenu(entries)
    end
end

-- Spell browser --

---@param page KajiGUIPage
---@param instanceId number
---@param bossId fun(): number the boss whose spells to list, 0 for the whole instance; read on every redraw
---@param action { label: string, onUse: fun(spell: table) } what a spell's button does
---@return KajiGUIFluentCard card so a boss change can redraw the list
local function BuildSpellBrowser(page, instanceId, bossId, action)
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
        local boss = bossId()
        local matched, lastBoss = 0, nil

        for _, spell in ipairs(spells) do
            if (boss == 0 or spell.journalId == boss) and (needle == '' or
                    strlower(spell.name):find(needle, 1, true) or
                    tostring(spell.spellId):find(needle, 1, true)) then
                matched = matched + 1

                if spell.bossName ~= lastBoss then
                    lastBoss = spell.bossName

                    local bossLabel = spell.bossNum and format(L['B%d %s'], spell.bossNum, spell.bossName) or spell.bossName

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
                row:Button(action.label, {
                    width = 0.3,
                    height = 22,
                    yOffset = -3,
                    tooltip = spell.name,
                    callback = function() action.onUse(spell) end,
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
        local isAnnounce = trigger.TriggerType == 'announce'
        local nameRow = c:Row(rowH)

        nameRow:EditBox(L['Timer Name'], {
            width = 0.5,
            value = trigger.Name,
            callback = function(text)
                if not text or text == '' then return end

                trigger.Name = text
                Apply()
                RefreshSidebar()
            end,
        })
        nameRow:Dropdown(L['Trigger Type'], {
            width = 0.5,
            options = NRSKNUI.BigWigsTriggerTypes,
            value = trigger.TriggerType,
            callback = function(key)
                trigger.TriggerType = key
                Apply()
                c:Rebuild()
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
                    RefreshSidebar(BossKey(instanceId, bossId))
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
                RefreshSidebar()
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
            tooltip = isAnnounce and L['Matched against the announce text BigWigs shows.'] or
                L['Matched against the bar text BigWigs shows.'],
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

        if isAnnounce then
            c:Row(rowHL, 0):Slider(L['Duration'], {
                width = 1,
                tooltip = L['How long the display stays up after the announce fires.'],
                min = 0.5,
                max = 30,
                step = 0.5,
                value = trigger.Duration,
                callback = function(val)
                    trigger.Duration = val
                    Apply()
                end,
            })

            return
        end

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

    browser = BuildSpellBrowser(page, instanceId, function() return trigger.BossId end, {
        label = L['Use'],
        onUse = function(spell)
            trigger.SpellId = tostring(spell.spellId)
            Apply()
            card:Rebuild()
            RefreshSidebar()
            browser:Rebuild()
        end,
    })
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

-- Group page --

---@param key string? a tree group's key: 'instance:<id>' or 'boss:<id>:<journalId>'
---@return number? instanceId, number? bossId 0 for a dungeon or a raid's unassigned timers
local function ParseGroupKey(key)
    if not key then return end

    local instanceId, bossId = key:match('^boss:(%d+):(%d+)$')
    if instanceId then
        return tonumber(instanceId), tonumber(bossId)
    end

    instanceId = key:match('^instance:(%d+)$')
    return tonumber(instanceId), instanceId and 0 or nil
end

---The timers a group holds, as the tree sorts them: a dungeon's are all of them, a raid boss's its own,
---and a raid's unassigned ones every timer whose boss isn't one of its bosses.
---@param kind 'dungeon'|'raid'
---@param instanceId number
---@param bossId number
---@return table[]
local function GroupTriggers(kind, instanceId, bossId)
    local instance = NRSKNUI.BigWigsTimers.db.Instances[instanceId]
    local known = {}
    if kind == 'raid' and bossId == 0 then
        for _, boss in ipairs(BigWigsTimers:GetBossesForInstance(instanceId)) do
            known[boss.journalId] = true
        end
    end

    local list = {}
    for _, trigger in ipairs(instance and instance.Triggers or {}) do
        local mine = kind == 'dungeon'
            or (bossId ~= 0 and trigger.BossId == bossId)
            or (bossId == 0 and not known[trigger.BossId])
        if mine then
            insert(list, trigger)
        end
    end
    return list
end

---A dungeon's or a boss's own page: actions for all its timers at once and the BigWigs spells to make new
---ones from, so filling a dungeon is a few clicks instead of a prompt per timer.
---@param page KajiGUIPage
---@param pageId string
---@param kind 'dungeon'|'raid'
---@param groupKey string
---@param item table? the tree row, for the group's name
local function BuildGroupPage(page, pageId, kind, groupKey, item)
    local instanceId, bossId = ParseGroupKey(groupKey)
    if not instanceId or not bossId then return end

    local triggers = GroupTriggers(kind, instanceId, bossId)
    page:SetCondition('hasTimers', function() return triggers[1] ~= nil end)

    local actions = page:Card(item and item.text or L['Timers'])
    local actionRow = actions:Row(BUTTON_ROW_HEIGHT)
    actionRow:Button(L['New Timer'], {
        width = 1 / 3,
        height = BUTTON_ROW_HEIGHT,
        callback = function() NewTimerPrompt(pageId, groupKey) end,
    })
    for _, state in ipairs({ true, false }) do
        actionRow:Button(state and L['Enable All'] or L['Disable All'], {
            width = 1 / 3,
            height = BUTTON_ROW_HEIGHT,
            conditions = { 'hasTimers' },
            callback = function()
                for _, trigger in ipairs(triggers) do
                    trigger.Enabled = state
                end
                Apply()
                Reopen(pageId, groupKey)
            end,
        })
    end

    -- a spell becomes a timer under its own boss, named the way the browser numbers the bosses
    BuildSpellBrowser(page, instanceId, function() return bossId end, {
        label = L['Add'],
        onUse = function(spell)
            local boss = kind == 'raid' and (bossId ~= 0 and bossId or spell.journalId or 0) or 0
            local name = spell.bossNum and format(L['B%d %s'], spell.bossNum, spell.name) or spell.name
            local trigger = BigWigsTimers:CreateTrigger(instanceId, name, boss)
            trigger.SpellId = tostring(spell.spellId)

            local sidebar = Sidebar()
            if sidebar then
                sidebar:SetExpanded(kind == 'raid' and BossKey(instanceId, boss) or groupKey, true)
            end
            Apply()
            Reopen(pageId, MakeKey(instanceId, trigger.Id))
        end,
    })
end

-- Pages --

local TRIGGER_TABS = {
    { id = 'trigger', text = L['Trigger'] },
    { id = 'display', text = L['Display'] },
    { id = 'load',    text = L['Load'] },
    { id = 'actions', text = L['Actions'] },
}

---@param pageId string
---@param kind 'dungeon'|'raid'
---@param title string
local function RegisterTriggerPage(pageId, kind, title)
    GUI:RegisterPage(pageId, {
        mode = 'tabs',
        search = { title, L['BigWigs Timers'] },
        sidebar = {
            width = 260,
            create = NRSKNUI.Libs.KAJI.CreateItemTree,
            locked = function() return not NRSKNUI.BigWigsTimers.db.Enabled end,
            items = TreeContent(kind),
            -- bands start open and remember closing, groups start folded and remember opening
            onToggleExpanded = function(key, open)
                if key:find('^band:') then
                    folded[key] = not open or nil
                else
                    expanded[key] = open or nil
                end
            end,
            onMoveInGroup = function(key, delta)
                local instanceId, triggerId = ParseKey(key)
                if not instanceId or not triggerId then return end

                BigWigsTimers:MoveTrigger(instanceId, triggerId, delta)
                Apply()
                RefreshSidebar()
            end,
            onContextMenu = ContextMenu(pageId),
        },
        -- a timer has its tabs; a dungeon, a boss or nothing picked gets the whole width
        tabs = function(itemKey)
            local _, triggerId = ParseKey(itemKey)
            return triggerId and TRIGGER_TABS or {}
        end,
        build = function(page, tabId, itemKey, item)
            local db = NRSKNUI.BigWigsTimers.db

            page:SetEnabled(function() return db.Enabled end)

            local instanceId, triggerId = ParseKey(itemKey)
            local trigger = instanceId and triggerId and BigWigsTimers:GetTrigger(instanceId, triggerId)

            BigWigsTimers:SetPreviewTrigger(trigger or nil)

            if not trigger and ParseGroupKey(itemKey) then
                BuildGroupPage(page, pageId, kind, itemKey, item)
                return
            end

            if not trigger or not instanceId then
                local card = page:Card(L['No Timer Selected'])

                card:Row(rowHL, 0):Text(L['Help'], {
                    width = 1,
                    autoHeight = true,
                    bgMode = 'hide',
                    text = L['Pick an instance on the left to add timers to it, or pick an existing timer.'],
                })

                return
            end

            if tabId == 'trigger' then
                BuildTriggerTab(page, instanceId, trigger, kind)
            elseif tabId == 'display' then
                BuildDisplayTab(page, trigger)
            elseif tabId == 'load' then
                page:LoadConditionsCard({ db = trigger.LoadConditions, specs = true, onChangeCallback = Apply })
            elseif tabId == 'actions' then
                BuildActionsTab(page, trigger)
            end
        end,
    })
end

RegisterTriggerPage(PAGE_DUNGEONS, 'dungeon', L['Dungeons'])
RegisterTriggerPage(PAGE_RAIDS, 'raid', L['Raids'])

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class NRSKNUI.GUITriggerEditor
local TriggerEditor = {}
NRSKNUI.GUITriggerEditor = TriggerEditor
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local AuraTriggers = NRSKNUI.AuraTriggers
local Premade = NRSKNUI.AuraFiltersPremade
local SpellList = NRSKNUI.GUISpellList
local AF = AuraUtil.AuraFilters

local ipairs, tonumber, tostring = ipairs, tonumber, tostring
local format = string.format
local setmetatable = setmetatable
local tinsert, tremove = table.insert, table.remove
local min, rad = math.min, math.rad
local CopyTable = CopyTable

local TEX = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\'
local DELETE_COLOR = { 1, 0, 0 }

-- A "trigger" here is one branch of the saved trigger: an aura group inside the display's container.

local AURA_TYPES = {
    { value = AF.Helpful, text = L['Buffs'] },
    { value = AF.Harmful, text = L['Debuffs'] },
}
local SPELL_MODES = {
    { value = 'all',  text = L['All Spells'] },
    { value = 'only', text = L['Whitelist'] },
    { value = 'hide', text = L['Blacklist'] },
}
local MODE_FIELD = { only = 'includeSpellIDs', hide = 'excludeSpellIDs' }

---A set filter shows its Yes or No in the accent, so it stands out from the rows left on Any.
---@param yesOnly? boolean
---@return table[]
local function StateOptions(yesOnly)
    local options = {
        { value = 'any', text = L['Any'] },
        { value = 'yes', text = L['Yes'], valueColor = Theme.accent },
    }
    if not yesOnly then options[3] = { value = 'no', text = L['No'], valueColor = Theme.accent } end
    return options
end

---@param state boolean?
---@return string
local function StateValue(state)
    if state == true then return 'yes' end
    if state == false then return 'no' end
    return 'any'
end

---@param value string
---@return boolean?
local function ValueState(value)
    if value == 'yes' then return true end
    if value == 'no' then return false end
    return nil
end

---@param branch table
---@param key string
---@return table
local function Sub(branch, key)
    branch[key] = branch[key] or {}
    return branch[key]
end

-- Each group reads and writes one kind of branch field, so a group is a list of keys plus how to reach them.
local GROUPS = {
    {
        key = 'aura',
        title = L['Aura Filters'],
        desc = L['The tags Blizzard puts on the aura. Yes needs the tag, No hides auras that have it.'],
        fields = {
            { key = AF.Player,                label = L['Player'] },
            { key = AF.Raid,                  label = L['Raid'] },
            { key = AF.Cancelable,            label = L['Cancelable'] },
            { key = AF.ExternalDefensive,     label = L['External Defensive'] },
            { key = AF.CrowdControl,          label = L['Crowd Control'] },
            { key = AF.RaidInCombat,          label = L['Raid In Combat'] },
            { key = AF.RaidPlayerDispellable, label = L['Raid Player Dispellable'] },
            { key = AF.BigDefensive,          label = L['Big Defensive'] },
            { key = AF.Important,             label = L['Important'] },
            { key = AF.Dispellable,           label = L['Dispellable'] },
            { key = AF.IncludeNameplateOnly,  label = L['Include Nameplate Only'], yesOnly = true }, -- not negatable
        },
        get = function(branch, key) return branch.tokens and branch.tokens[key] end,
        set = function(branch, key, state) Sub(branch, 'tokens')[key] = state end,
    },
    {
        key = 'candidate',
        title = L['Candidate Filters'],
        desc = L['Checked after the aura filters, every one that is set has to match.'],
        duration = true,
    },
    {
        key = 'dispel',
        title = L['Dispel Types'],
        desc = L['Yes shows only these types, No hides them.'],
        fields = {
            { key = 'Magic' }, { key = 'Curse' }, { key = 'Disease' }, { key = 'Poison' },
            { key = 'Enrage' }, { key = 'Stealth' }, { key = 'Special' },
        },
        get = function(branch, key)
            local c = branch.candidates
            if c and c.includeDispelTypes and c.includeDispelTypes[key] then return true end
            if c and c.excludeDispelTypes and c.excludeDispelTypes[key] then return false end
            return nil
        end,
        set = function(branch, key, state)
            local candidates = Sub(branch, 'candidates')
            Sub(candidates, 'includeDispelTypes')[key] = (state == true) or nil
            Sub(candidates, 'excludeDispelTypes')[key] = (state == false) or nil
        end,
    },
    {
        key = 'props',
        title = L['Aura Properties'],
        desc = L['What the aura is and what can be done with it.'],
        fields = {
            { key = 'isFromPlayerOrPlayerPet', label = L['From Player or Pet'] },
            { key = 'isRoleAura',              label = L['Role Aura'] },
            { key = 'isPriorityAura',          label = L['Priority Aura'] },
            { key = 'isStealable',             label = L['Stealable'] },
            { key = 'canApplyAura',            label = L['Can Apply Aura'] },
            { key = 'nameplateShowAll',        label = L['Nameplate: Show All'] },
            { key = 'nameplateShowPersonal',   label = L['Nameplate: Personal'] },
            { key = 'isBossAura',              label = L['Boss Aura'] },
            { key = 'isBossOrRoleAura',        label = L['Boss or Role Aura'] },
        },
        get = function(branch, key) return branch.candidates and branch.candidates[key] end,
        set = function(branch, key, state) Sub(branch, 'candidates')[key] = state end,
    },
}

---@param branch table
---@param group table
---@return number
local function CountSet(branch, group)
    if group.duration then
        return (branch.candidates and branch.candidates.maxDuration) and 1 or 0
    end
    local count = 0
    for _, field in ipairs(group.fields) do
        if group.get(branch, field.key) ~= nil then count = count + 1 end
    end
    return count
end

-- Weak keys: a branch or trigger that goes away takes its state with it.
local openState = setmetatable({}, { __mode = 'k' })
local pickedBranch = setmetatable({}, { __mode = 'k' })

---@param trigger table
---@return number
local function Picked(trigger)
    local index = min(pickedBranch[trigger] or 1, #trigger.branches)
    pickedBranch[trigger] = index
    return index
end

-- Spells --

---@param branch table
---@return string
local function GetSpellMode(branch)
    if branch.shipped then return branch.shipped.field == MODE_FIELD.hide and 'hide' or 'only' end
    local c = branch.candidates
    if c and c.includeSpellIDs then return 'only' end
    if c and c.excludeSpellIDs then return 'hide' end
    return 'all'
end

---Moves the list to the field the new mode reads; All Spells parks it, so switching back restores it.
---@param branch table
---@param mode string
local function SetSpellMode(branch, mode)
    local current = GetSpellMode(branch)
    if mode == current then return end
    local candidates = Sub(branch, 'candidates')

    local list = branch.parkedSpells
    if current ~= 'all' then
        list = branch.shipped and { shipped = branch.shipped } or { map = candidates[MODE_FIELD[current]] }
        branch.shipped = nil
        candidates[MODE_FIELD[current]] = nil
    end

    if mode == 'all' then
        branch.parkedSpells = list
        return
    end

    branch.parkedSpells = nil
    local field = MODE_FIELD[mode]
    if list and list.shipped then
        list.shipped.field = field
        branch.shipped = list.shipped
    else
        candidates[field] = list and list.map or {}
    end
end

---Typeless branches inherit the base, so pin them first or a trigger 1 change would retype them all.
---@param trigger table
---@param index number
---@param value string
local function SetAuraType(trigger, index, value)
    for i, branch in ipairs(trigger.branches) do
        if i ~= index and not branch.type then branch.type = trigger.Base end
    end

    -- Trigger 1 keeps living on the base, which the display's own dispel settings read.
    local branch = trigger.branches[index]
    if index == 1 then
        trigger.Base, branch.type = value, nil
    else
        branch.type = value
    end
end

---@param text string
---@return string
local function Muted(text)
    return NRSKNUI:ColorText(text, Theme.textMuted)
end

-- Container card --

---@param trigger table
---@param index number
---@return string
local function TriggerLabel(trigger, index)
    local auraType = (trigger.branches[index].type or trigger.Base) == AF.Helpful and L['Buffs'] or L['Debuffs']
    return format('%s  %s', format(L['Trigger %d'], index), Muted(auraType))
end

---Duplicate and delete on every row of the trigger dropdown.
---@param trigger table
---@param changed fun(picked: number)
---@return fun(index: number): KajiGUIDropdownItemAction[]
local function TriggerActions(trigger, changed)
    local branches = trigger.branches
    return function(index)
        return {
            {
                icon = TEX .. 'plus-sign.png',
                tooltip = L['Duplicate'],
                onClick = function()
                    tinsert(branches, index + 1, CopyTable(branches[index]))
                    changed(index + 1)
                end,
            },
            {
                icon = TEX .. 'NorskenCustomCrossv3.png', -- same cross, tint and rotation as skinned close buttons
                color = DELETE_COLOR,
                rotation = rad(45),
                tooltip = L['Delete Trigger'],
                -- The last one stays: a display without any matches everything its base allows.
                disabled = #branches == 1,
                onClick = function()
                    NRSKNUI:CreatePrompt({
                        title = L['Delete Trigger'],
                        text = format(L['Delete Trigger %d and everything set on it?\nThis cannot be undone.'], index),
                        onAccept = function()
                            tremove(branches, index)
                            changed(min(index, #branches))
                        end,
                        acceptText = L['Delete'],
                        cancelText = L['Cancel'],
                    })
                end,
            },
        }
    end
end

---@param trigger table
---@param changed fun(picked: number)
---@param refresh fun()
---@return table config the Load Preset dropdown
local function LoadPresetConfig(trigger, changed, refresh)
    local options = {}
    for i, preset in ipairs(Premade:GetList()) do
        options[i] = { value = preset.key, text = preset.text }
    end

    return {
        width = 0.5,
        options = options,
        tooltip = L['Replace the triggers with a preset, as a starting point to edit.'],
        callback = function(key)
            local preset = Premade:Get(key)
            NRSKNUI:CreatePrompt({
                title = L['Load Preset'],
                text = format(L['Replace every trigger with %s?\nThis cannot be undone.'], preset and preset.name or key),
                onAccept = function()
                    AuraTriggers:LoadPreset(trigger, key)
                    changed(1)
                end,
                onCancel = refresh, -- the dropdown already shows the preset it was asked for
                acceptText = L['Load'],
                cancelText = L['Cancel'],
            })
        end,
    }
end

---@param page table
---@param trigger table
---@param ctx table
---@param apply fun()
---@param show fun(picked: number) shows another trigger
---@param changed fun(picked: number) after the trigger list changed
---@return KajiGUIFluentCard
local function BuildContainerCard(page, trigger, ctx, apply, show, changed)
    local card
    card = page:Card(ctx.title, ctx.group):Rebuild(function(c)
        local index = Picked(trigger)
        local options = {}
        for i = 1, #trigger.branches do
            options[i] = { value = i, text = TriggerLabel(trigger, i) }
        end

        local editing = {
            width = 0.5,
            options = options,
            value = index,
            tooltip = L['Each trigger is its own group of auras, shown together in this display.'],
            itemActions = TriggerActions(trigger, changed),
            callback = function(value)
                if value ~= index then show(value) end
            end,
        }
        local addTrigger = {
            height = 24,
            callback = function()
                local branch = trigger.branches[index]
                tinsert(trigger.branches, { type = branch.type or trigger.Base })
                changed(#trigger.branches)
            end,
        }
        local loadPreset = LoadPresetConfig(trigger, changed, function() card:Rebuild() end)

        local first = c:Row(rowH)
        if ctx.showUnit then
            first:Dropdown(L['Unit'], {
                width = 0.5,
                options = AuraTriggers.UnitOptions,
                value = trigger.Unit,
                tooltip = L['Every trigger in this display watches this unit.'],
                callback = function(value)
                    trigger.Unit = value
                    apply()
                end,
            })
            first:Dropdown(L['Editing'], editing)

            local second = c:Row(rowH, 0)
            second:Dropdown(L['Load Preset'], loadPreset)
            addTrigger.width, addTrigger.yOffset = 0.5, -14 -- level with the dropdown box beside it
            second:Button(L['Add Trigger'], addTrigger)
        else
            first:Dropdown(L['Editing'], editing)
            first:Dropdown(L['Load Preset'], loadPreset)

            addTrigger.width = 1
            c:Row(24, 0):Button(L['Add Trigger'], addTrigger)
        end
    end)
    return card
end

-- Trigger card --

---@param card KajiGUIFluentCard
---@param branch table
---@param group table
---@param changed fun()
local function BuildGroupRows(card, branch, group, changed)
    if group.duration then
        card:Row(rowH):EditBox(L['Max Duration (seconds)'], {
            width = 0.5,
            value = tostring(branch.candidates and branch.candidates.maxDuration or ''),
            callback = function(text)
                local n = tonumber(text)
                local value = (n and n > 0) and n or nil
                if value == (branch.candidates and branch.candidates.maxDuration) then return end
                Sub(branch, 'candidates').maxDuration = value
                changed()
            end,
        })
        return
    end

    local fields = group.fields
    for index = 1, #fields, 2 do
        local row = card:Row(rowH)
        for i = index, index + 1 do
            local field = fields[i]
            if field then
                row:Dropdown(field.label or L[field.key], {
                    width = 0.5,
                    options = StateOptions(field.yesOnly),
                    value = StateValue(group.get(branch, field.key)),
                    callback = function(value)
                        group.set(branch, field.key, ValueState(value))
                        changed()
                    end,
                })
            end
        end
    end
end

---@param card KajiGUIFluentCard
---@param branch table
---@param changed fun()
local function BuildFilters(card, branch, changed)
    local open = openState[branch] or {}
    openState[branch] = open

    for _, group in ipairs(GROUPS) do
        local count = CountSet(branch, group)
        local isOpen = open[group.key] == true -- closed until the user opens one

        local title = count > 0 and (group.title .. '  ' .. Muted(format(L['%d active'], count))) or group.title
        local expanded = card:Section(title, {
            collapsed = not isOpen,
            onToggle = function()
                open[group.key] = not isOpen
                card:Rebuild()
            end,
        })
        if expanded then
            card:Row(20):Text(nil, { width = 1, text = Muted(group.desc), bgMode = 'hide' })
            BuildGroupRows(card, branch, group, changed)
        end
    end
end

---@param page table
---@param trigger table
---@param apply fun()
---@param retype fun() after the aura type changed, which the container card names
---@param group string? the page condition group its widgets join
---@return KajiGUIFluentCard
local function BuildTriggerCard(page, trigger, apply, retype, group)
    local card
    card = page:Card(format(L['Trigger %d'], Picked(trigger)), group):Rebuild(function(c)
        local index = Picked(trigger)
        local branch = trigger.branches[index]
        local function Changed()
            apply()
            card:Rebuild()
        end

        local row = c:Row(rowH)
        row:Dropdown(L['Aura Type'], {
            width = 0.5,
            options = AURA_TYPES,
            value = branch.type or trigger.Base,
            callback = function(value)
                SetAuraType(trigger, index, value)
                apply()
                retype()
            end,
        })
        row:Dropdown(L['Spells'], {
            width = 0.5,
            options = SPELL_MODES,
            value = GetSpellMode(branch),
            callback = function(value)
                SetSpellMode(branch, value)
                Changed()
            end,
        })

        local mode = GetSpellMode(branch)
        if mode ~= 'all' then
            local shipped = branch.shipped
            local source = shipped and SpellList:ShippedSource(shipped, shipped.list, Changed)
                or SpellList:MapSource(branch.candidates[MODE_FIELD[mode]], Changed)

            c:Separator(mode == 'only' and L['Whitelist'] or L['Blacklist'], { useLabel = true })
            SpellList:BuildAdd(c, source)
            SpellList:BuildList(c, source)
        end

        c:Separator(L['Filters'], { useLabel = true })
        BuildFilters(c, branch, Changed)
    end)
    return card
end

---@param page table
---@param trigger table
---@param ctx { title: string, group?: string, showUnit?: boolean, onChange: fun() }
function TriggerEditor:Build(page, trigger, ctx)
    AuraTriggers:ConvertSpellIDs(trigger)
    AuraTriggers:ConvertPreset(trigger)
    trigger.branches = trigger.branches or { {} }

    local function Apply()
        ctx.onChange()
        AuraTriggers:Invalidate()
    end

    -- Both cards rebuild in place rather than the page reloading, so the scroll stays where it was.
    local containerCard, triggerCard
    local function Show(picked)
        pickedBranch[trigger] = picked
        containerCard:Rebuild()
        triggerCard:SetTitle(format(L['Trigger %d'], Picked(trigger)))
        triggerCard:Rebuild()
    end
    local function Changed(picked)
        Apply()
        Show(picked)
    end

    containerCard = BuildContainerCard(page, trigger, ctx, Apply, Show, Changed)
    triggerCard = BuildTriggerCard(page, trigger, Apply, function() containerCard:Rebuild() end, ctx.group)
end

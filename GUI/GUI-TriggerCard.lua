---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class NRSKNUI.GUITriggerCard
local TriggerCard = {}
NRSKNUI.GUITriggerCard = TriggerCard
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local AuraTriggers = NRSKNUI.AuraTriggers
local Premade = NRSKNUI.AuraFiltersPremade
local AF = AuraUtil.AuraFilters

local ipairs, pairs, tonumber = ipairs, pairs, tonumber
local tinsert, tremove, tsort = table.insert, table.remove, table.sort
local format = string.format
local setmetatable = setmetatable
local tostring = tostring
local CopyTable = CopyTable

--[[

The Trigger card, shared by every display that matches auras: the standalone aura displays, the unit
frame Buffs/Debuffs, and the aura indicators.

One card, rebuilt in place whenever the shape of what it shows changes, so switching type or adding a
condition never needs the page reopened. What it edits is an inline trigger owned by the display
itself (see Core/Auras/AuraTriggers.lua) - there is no registry and no second place to visit.

API: NRSKNUI.GUITriggerCard:Build(page, trigger, ctx)

* trigger - the inline trigger table, edited in place
* ctx.hideUnit - unit frames know their own unit, so they suppress the Unit dropdown
* ctx.onChange - called after every edit, to rebind the live display

--]]

local Types = AuraTriggers.Types

-- Which branch sections are closed, keyed by the trigger they belong to so two displays never share
-- collapse state. Weak keys: a trigger that goes away takes its state with it.
local collapsed = setmetatable({}, { __mode = 'k' })

---@param trigger table
---@param index number
---@return boolean
local function IsCollapsed(trigger, index)
    local state = collapsed[trigger]
    return state ~= nil and state[index] == true
end

---@param trigger table
---@param index number
local function ToggleCollapsed(trigger, index)
    local state = collapsed[trigger] or {}
    state[index] = not state[index]
    collapsed[trigger] = state
end

-- Condition catalogue --

-- Tokens are added as conditions and then set to Include/Exclude; strings read live from the client.
local NEGATABLE_TOKENS = {
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
}

-- Not negatable and nothing to configure, so their row carries a note describing what they do
-- rather than a second copy of the label.
local SIMPLE_TOKENS = {
    { key = AF.IncludeNameplateOnly, label = L['Include Nameplate Only'], note = L['Nameplate-only auras are included.'] },
    { key = AF.Maw,                  label = L['Maw (Torghast Only)'],    note = L['Only Torghast auras are shown.'] },
}

local BOOL_FIELDS = {
    { key = 'isBossAura',              label = L['Boss Aura'] },
    { key = 'isBossOrRoleAura',        label = L['Boss or Role Aura'] },
    { key = 'isRoleAura',              label = L['Role Aura'] },
    { key = 'isPriorityAura',          label = L['Priority Aura'] },
    { key = 'isStealable',             label = L['Stealable'] },
    { key = 'isFromPlayerOrPlayerPet', label = L['From Player or Pet'] },
    { key = 'canApplyAura',            label = L['Can Apply Aura'] },
    { key = 'nameplateShowAll',        label = L['Nameplate Show All'] },
    { key = 'nameplateShowPersonal',   label = L['Nameplate Show Personal'] },
}

-- Labels come from L[key], so the keys are the whole table.
local DISPEL_KEYS = { 'Magic', 'Poison', 'Disease', 'Curse', 'Stealth', 'Special', 'Enrage' }

-- A condition only exists once it has been added, so these have no "off" state: removing the row is
-- what turns a condition off.
local TOKEN_STATES = {
    { value = 'include', text = L['Include'] },
    { value = 'exclude', text = L['Exclude'] },
}
local BOOL_STATES = {
    { value = 'yes', text = L['Require'] },
    { value = 'no',  text = L['Exclude'] },
}

local function TokenValue(state) return state == false and 'exclude' or 'include' end
local function BoolValue(state) return state == false and 'no' or 'yes' end

local function Dispels(branch, field)
    branch.candidates = branch.candidates or {}
    branch.candidates[field] = branch.candidates[field] or {}
    return branch.candidates[field]
end

local function DispelState(branch, key)
    local cands = branch.candidates
    if not cands then return nil end
    if cands.includeDispelTypes and cands.includeDispelTypes[key] then return 'include' end
    if cands.excludeDispelTypes and cands.excludeDispelTypes[key] then return 'exclude' end
    return nil
end

--[[

A branch stores its conditions by presence: a token, aura flag, dispel type or duration that has a
key is an active condition, and removing one clears the key. Nothing extra is stored, so the shape
here is exactly what AuraFilters:Compile reads.

Each entry knows how to answer three things for a branch: is it already added, what does adding it
default to, and how does its row render. This drives both the add dropdown and the rendered list, so
the two can never drift apart.

--]]
local CONDITION_KINDS = {
    {
        kind = 'token',
        category = L['Token'],
        entries = function()
            local list = {}
            for _, t in ipairs(NEGATABLE_TOKENS) do list[#list + 1] = { key = t.key, label = t.label } end
            for _, t in ipairs(SIMPLE_TOKENS) do list[#list + 1] = { key = t.key, label = t.label, note = t.note } end
            return list
        end,
        isAdded = function(branch, entry) return branch.tokens ~= nil and branch.tokens[entry.key] ~= nil end,
        add = function(branch, entry)
            branch.tokens = branch.tokens or {}
            branch.tokens[entry.key] = true
        end,
        remove = function(branch, entry) branch.tokens[entry.key] = nil end,
        -- The two non-negatable tokens have nothing to configure, so their row states what they do.
        render = function(row, branch, entry, onChange)
            if entry.note then
                row:Text(entry.label, { width = 0.7, text = entry.note, height = rowH, bgMode = 'hide' })
                return
            end
            row:Dropdown(entry.label, {
                width = 0.7,
                options = TOKEN_STATES,
                value = TokenValue(branch.tokens[entry.key]),
                callback = function(v)
                    branch.tokens[entry.key] = (v == 'include')
                    onChange()
                end,
            })
        end,
    },
    {
        kind = 'flag',
        category = L['Aura Flag'],
        entries = function() return BOOL_FIELDS end,
        isAdded = function(branch, entry) return branch.candidates ~= nil and branch.candidates[entry.key] ~= nil end,
        add = function(branch, entry)
            branch.candidates = branch.candidates or {}
            branch.candidates[entry.key] = true
        end,
        remove = function(branch, entry) branch.candidates[entry.key] = nil end,
        render = function(row, branch, entry, onChange)
            row:Dropdown(entry.label, {
                width = 0.7,
                options = BOOL_STATES,
                value = BoolValue(branch.candidates[entry.key]),
                callback = function(v)
                    branch.candidates[entry.key] = (v == 'yes')
                    onChange()
                end,
            })
        end,
    },
    {
        kind = 'dispel',
        category = L['Dispel Type'],
        entries = function()
            local list = {}
            for _, d in ipairs(DISPEL_KEYS) do list[#list + 1] = { key = d, label = L[d] or d } end
            return list
        end,
        isAdded = function(branch, entry) return DispelState(branch, entry.key) ~= nil end,
        add = function(branch, entry) Dispels(branch, 'includeDispelTypes')[entry.key] = true end,
        remove = function(branch, entry)
            Dispels(branch, 'includeDispelTypes')[entry.key] = nil
            Dispels(branch, 'excludeDispelTypes')[entry.key] = nil
        end,
        render = function(row, branch, entry, onChange)
            row:Dropdown(entry.label, {
                width = 0.7,
                options = TOKEN_STATES,
                value = DispelState(branch, entry.key),
                callback = function(v)
                    Dispels(branch, 'includeDispelTypes')[entry.key] = (v == 'include') or nil
                    Dispels(branch, 'excludeDispelTypes')[entry.key] = (v == 'exclude') or nil
                    onChange()
                end,
            })
        end,
    },
    {
        kind = 'duration',
        category = L['Duration'],
        entries = function() return { { key = 'maxDuration', label = L['Max Duration (seconds)'] } } end,
        isAdded = function(branch) return branch.candidates ~= nil and branch.candidates.maxDuration ~= nil end,
        add = function(branch)
            branch.candidates = branch.candidates or {}
            branch.candidates.maxDuration = 10
        end,
        remove = function(branch) branch.candidates.maxDuration = nil end,
        render = function(row, branch, entry, onChange)
            row:EditBox(entry.label, {
                width = 0.7,
                value = tostring(branch.candidates.maxDuration or 0),
                callback = function(text)
                    local n = tonumber(text)
                    branch.candidates.maxDuration = (n and n > 0) and n or nil
                    onChange()
                end,
            })
        end,
    },
}

---Every condition a branch has not got yet, as dropdown options prefixed by category.
---@param branch table
---@return table[] options
---@return table lookup value -> { kind, entry }
local function UnusedConditions(branch)
    local options, lookup = {}, {}

    for _, kind in ipairs(CONDITION_KINDS) do
        for _, entry in ipairs(kind.entries()) do
            if not kind.isAdded(branch, entry) then
                local value = kind.kind .. ':' .. entry.key
                options[#options + 1] = { value = value, text = format('%s: %s', kind.category, entry.label) }
                lookup[value] = { kind = kind, entry = entry }
            end
        end
    end

    return options, lookup
end

---One branch's active conditions, each with its own remove button.
---@param card table
---@param branch table
---@param onChange fun()
local function BuildConditionRows(card, branch, onChange)
    for _, kind in ipairs(CONDITION_KINDS) do
        for _, entry in ipairs(kind.entries()) do
            if kind.isAdded(branch, entry) then
                local row = card:Row(rowH)
                kind.render(row, branch, entry, onChange)
                row:Button(L['Remove'], {
                    width = 0.3,
                    height = 24,
                    yOffset = -14,
                    callback = function()
                        kind.remove(branch, entry)
                        onChange()
                    end,
                })
            end
        end
    end
end

---The AuraFilter editor: one collapsible section per branch, then Add Branch.
---@param card table
---@param trigger table
---@param onChange fun()
local function BuildBranches(card, trigger, onChange)
    -- A trigger that has only ever been a Preset or a SpellID list carries no branches, so switching
    -- it to Aura Filter is where they get made.
    trigger.branches = trigger.branches or { {} }
    local branches = trigger.branches

    for index = 1, #branches do
        local branch = branches[index]
        local count = #branches

        local title = format(L['Branch %d'], index)
        local expanded = card:Section(title, {
            collapsed = IsCollapsed(trigger, index),
            onToggle = function()
                ToggleCollapsed(trigger, index)
                card:Rebuild()
            end,
            -- Order decides group layout order, so a branch can be moved without rebuilding it.
            onMoveUp = index > 1 and function()
                branches[index], branches[index - 1] = branches[index - 1], branches[index]
                onChange()
            end or nil,
            onMoveDown = index < count and function()
                branches[index], branches[index + 1] = branches[index + 1], branches[index]
                onChange()
            end or nil,
            onDuplicate = function()
                tinsert(branches, index + 1, CopyTable(branch))
                onChange()
            end,
            -- The last branch stays: a trigger with none matches everything its base allows.
            onDelete = count > 1 and function()
                tremove(branches, index)
                onChange()
            end or nil,
            moveUpTooltip = L['Move Up'],
            moveDownTooltip = L['Move Down'],
            duplicateTooltip = L['Duplicate'],
            deleteTooltip = L['Remove'],
        })

        if expanded then
            local options, lookup = UnusedConditions(branch)
            if options[1] then
                card:Row(rowH):Dropdown(L['Add Condition'], {
                    width = 1,
                    searchable = true,
                    options = options,
                    value = nil,
                    callback = function(value)
                        local picked = lookup[value]
                        if not picked then return end

                        picked.kind.add(branch, picked.entry)
                        onChange()
                    end,
                })
            end

            BuildConditionRows(card, branch, onChange)
        end
    end

    card:Separator()

    card:Row(24):Button(L['Add Branch'], {
        width = 1,
        height = 24,
        callback = function()
            tinsert(branches, {})
            onChange()
        end,
    })
end

---The SpellIDs editor: an add box, then one row per spell.
---@param card table
---@param trigger table
---@param onChange fun()
local function BuildSpellIDs(card, trigger, onChange)
    trigger.SpellIDs = trigger.SpellIDs or {}

    card:Row(rowH):Checkbox(L['Only My Auras'], {
        width = 1,
        tooltip = L['Match only auras you cast yourself, so someone else applying the same spell does not light it up.'],
        value = trigger.OnlyMine == true,
        callback = function(checked)
            trigger.OnlyMine = checked or nil
            onChange()
        end,
    })

    local addRow = card:Row(rowH)

    -- Committed through the box's own callback, never a script hook: widgets are pooled, and a hook
    -- stays on the frame for good, so every display that had ever opened this card would add to its
    -- own trigger the next time anyone pressed Enter in the box.
    local function Add(text)
        local id = tonumber(text)
        if not id or id <= 0 then return end

        trigger.SpellIDs[id] = true
        onChange() -- rebuilds the card, which brings the box back empty
    end

    local box = addRow:EditBox(L['Spell ID'], {
        width = 0.5,
        value = '',
        tooltip = L['A spell ID to match. Press Enter or use Add.'],
        callback = Add,
    })

    addRow:Button(L['Add'], {
        width = 0.5,
        height = 24,
        yOffset = -14,
        callback = function() Add(box:GetValue()) end,
    })

    local ids = AuraTriggers:GetSpellIDList(trigger)
    if not ids[1] then
        card:Row(rowHL, 0):Text(L['Spell IDs'], {
            width = 1,
            text = L['No spells yet. Nothing is shown until at least one is added.'],
            height = rowH,
            bgMode = 'hide',
        })
        return
    end

    card:Separator()

    for _, id in ipairs(ids) do
        local info = C_Spell.GetSpellInfo(id)
        local row = card:Row(26)
        local label = info and info.name and format('%s (%d)', info.name, id) or format(L['Unknown spell ID %d'], id)

        row:Icon({
            width = 0.05,
            size = 24,
            texture = info and info.iconID,
            tooltip = function(t) t:SetSpellByID(id) end,
        })
        row:Text(NRSKNUI:ColorTextByTheme(label), {
            width = 0.65,
            yOffset = -2,
            height = rowH,
            bgMode = 'hide',
        })
        row:Button(L['Remove'], {
            width = 0.3,
            height = 24,
            callback = function()
                trigger.SpellIDs[id] = nil
                onChange()
            end,
        })
    end
end

---The Preset editor: pick one, read what it resolves to. Presets ship with the addon and are not
---editable, so anyone wanting a change builds their own with the Aura Filter type instead.
---@param card table
---@param trigger table
---@param onChange fun()
local function BuildPreset(card, trigger, onChange)
    local options = {}
    for _, entry in ipairs(Premade:GetList()) do
        options[#options + 1] = { value = entry.key, text = entry.text }
    end

    card:Row(rowH):Dropdown(L['Preset'], {
        width = 1,
        searchable = true,
        options = options,
        value = trigger.Preset,
        callback = function(value)
            trigger.Preset = value
            onChange()
        end,
    })

    local lines, heading = AuraTriggers:Describe(trigger)
    card:Row(rowHL, 0):Text(heading, {
        width = 1,
        text = table.concat(lines, '\n'),
        autoHeight = true,
        minHeight = rowH,
        bgMode = 'none',
    })
end

local BUILDERS = {
    [Types.SpellIDs] = BuildSpellIDs,
    [Types.Preset] = BuildPreset,
    [Types.AuraFilter] = BuildBranches,
}

--[[

API: NRSKNUI.GUITriggerCard:Build(page, trigger, ctx)

Add the Trigger card to a page. The trigger is edited in place; ctx.onChange rebinds the display.

--]]
---@param page table
---@param trigger table
---@param ctx table? { hideUnit?: boolean, onChange?: fun() }
---@return table card
function TriggerCard:Build(page, trigger, ctx)
    ctx = ctx or {}
    local card = page:Card(L['Trigger'])

    -- The whole card redraws on any structural edit: the fields, the branch list and the summary all
    -- change with the trigger, so rebuilding is cheaper to reason about than patching rows.
    card:Rebuild(function(c)
        local function Changed()
            if ctx.onChange then ctx.onChange() end
            NRSKNUI.AuraTriggers:Invalidate()
            c:Rebuild()
        end

        local headRow = c:Row(rowH)
        headRow:Dropdown(L['Trigger Type'], {
            width = ctx.hideUnit and 1 or 0.5,
            options = AuraTriggers.TypeOptions,
            value = trigger.Type,
            callback = function(value)
                trigger.Type = value
                Changed()
            end,
        })

        -- A unit frame's aura display already knows its unit, so offering a second answer there
        -- would only let the two disagree.
        if not ctx.hideUnit then
            headRow:Dropdown(L['Unit'], {
                width = 0.5,
                options = AuraTriggers.UnitOptions,
                value = trigger.Unit,
                callback = function(value)
                    trigger.Unit = value
                    Changed()
                end,
            })
        end

        -- A preset brings its own base type per branch, so it has nothing to answer here.
        if AuraTriggers.UsesBase[trigger.Type] then
            c:Row(rowH):Dropdown(L['Aura Type'], {
                width = 1,
                options = AuraTriggers.BaseOptions,
                value = trigger.Base,
                callback = function(value)
                    trigger.Base = value
                    Changed()
                end,
            })
        end

        c:Separator()

        local build = BUILDERS[trigger.Type] or BuildBranches
        build(c, trigger, Changed)
    end)

    return card
end

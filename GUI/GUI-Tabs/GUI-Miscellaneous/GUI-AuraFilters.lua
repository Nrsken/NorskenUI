---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local AuraFilters = NRSKNUI.AuraFilters
local AF = AuraUtil.AuraFilters

local ipairs, pairs, tonumber = ipairs, pairs, tonumber
local tsort = table.sort
local tremove = table.remove
local min, max = math.min, math.max
local format = string.format

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

-- Boolean candidate flags, added as Require/Exclude conditions.
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
local DISPEL_KEYS = {
    'Magic',
    'Poison',
    'Disease',
    'Curse',
    'Stealth',
    'Special',
    'Enrage',
}

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
local BASE_TYPES = {
    { value = '',         text = L['Any'] },
    { value = AF.Helpful, text = L['Buffs (Helpful)'] },
    { value = AF.Harmful, text = L['Debuffs (Harmful)'] },
}
local function Store() return NRSKNUI.db.global.AuraFilters end
local function Lists() return NRSKNUI.db.global.AuraSpellLists end

-- Reopen the whole page so the sidebar re-reads its item list and the tab strip re-reads the branch
-- count, selecting `selectKey` and (for a filter) the branch at `branchIndex`.
local function Reopen(selectKey, branchIndex)
    local window = NRSKNUI.GUIFrame
    if not (window and window.content) then return end

    local target
    if selectKey then
        target = { itemKey = selectKey, tabId = branchIndex and tostring(branchIndex) or nil }
    end
    window.content:ShowPage('filterBuilder', target)
end

-- Filters are created, renamed and deleted from the sidebar (its New Filter button and the
-- right-click menu on each entry), so these are shared by both entry points.

local function CreateFilterPrompt()
    NRSKNUI:CreatePrompt({
        title = L['Create Filter'],
        text = '',
        editBox = true,
        editBoxLabel = L['Filter Name'],
        onAccept = function(name)
            if not name or name == '' then
                NRSKNUI:Print(L['Please enter a filter name'])
                return
            end
            local store = Store()
            if store[name] then
                NRSKNUI:Print(L['A filter with that name already exists'])
                return
            end
            store[name] = { name = name, branches = { { type = AF.Harmful } } }
            AuraFilters:Invalidate(name)
            Reopen(name)
        end,
        acceptText = L['Create'],
        cancelText = L['Cancel'],
    })
end

local function RenameFilterPrompt(name)
    local spec = Store()[name]
    if not spec then return end

    NRSKNUI:CreatePrompt({
        title = L['Rename Filter'],
        text = '',
        editBox = true,
        editBoxLabel = L['New Name'],
        onAccept = function(new)
            if not new or new == '' then return end
            local store = Store()
            if store[new] then
                NRSKNUI:Print(L['A filter with that name already exists'])
                return
            end
            spec.name = new
            store[new] = spec
            store[name] = nil
            AuraFilters:Invalidate(name)
            AuraFilters:Invalidate(new)
            Reopen(new)
        end,
        acceptText = L['Rename'],
        cancelText = L['Cancel'],
    })
end

local function DeleteFilterPrompt(name)
    local spec = Store()[name]
    if not spec then return end

    NRSKNUI:CreatePrompt({
        title = L['Delete Filter'],
        text = format(L["Delete the filter '%s'? This cannot be undone."], spec.name or name),
        onAccept = function()
            Store()[name] = nil
            AuraFilters:Invalidate(name)
            Reopen() -- no key: falls back to whichever filter is now first
        end,
        acceptText = L['Delete'],
        cancelText = L['Cancel'],
    })
end

local function TokenValue(state) return state == false and 'exclude' or 'include' end
local function BoolValue(state) return state == false and 'no' or 'yes' end

--[[

A branch stores its conditions by presence: a token, aura flag, dispel type, duration or spellID list
that has a key is an active condition, and removing one clears the key. Nothing extra is stored, so
the compiled spec shape is identical to what Core/AuraFilters.lua already reads.

Each catalogue entry below knows how to answer three things for a branch: is it already added, what
does adding it default to, and how does its row render. `CONDITION_KINDS` drives both the add
dropdown and the rendered list, so the two can never drift apart.

--]]

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

---What an attached spellID list contributes, for the row body.
---@param name string
---@return string
local function ListSummary(name)
    local list = Lists() and Lists()[name]
    if not list then return '' end

    local total = 0
    for _ in pairs(list.spells or {}) do total = total + 1 end

    if total == 0 then return L['No spells yet'] end
    return format(L['%d spells'], total)
end

-- kind -> how its conditions are listed, added, removed and drawn. `entries` is resolved lazily so
-- spellID lists pick up ones created since the page was built.
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
                row:Text(entry.label, { width = 0.75, text = entry.note, height = rowH, bgMode = 'hide' })
                return
            end
            row:Dropdown(entry.label, {
                width = 0.75,
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
                width = 0.75,
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
                width = 0.75,
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
                width = 0.75,
                value = tostring(branch.candidates.maxDuration or 0),
                callback = function(text)
                    local n = tonumber(text)
                    branch.candidates.maxDuration = (n and n > 0) and n or nil
                    onChange()
                end,
            })
        end,
    },
    {
        kind = 'list',
        category = L['Spell List'],
        entries = function()
            local names = {}
            for lname in pairs(Lists()) do names[#names + 1] = lname end
            tsort(names)

            local list = {}
            for _, lname in ipairs(names) do
                local ldata = Lists()[lname]
                local typeLabel = ldata.type == 'whitelist' and L['Whitelist'] or L['Blacklist']
                list[#list + 1] = { key = lname, label = format('%s (%s)', ldata.name or lname, typeLabel) }
            end
            return list
        end,
        isAdded = function(branch, entry) return branch.spellLists ~= nil and branch.spellLists[entry.key] == true end,
        add = function(branch, entry)
            branch.spellLists = branch.spellLists or {}
            branch.spellLists[entry.key] = true
        end,
        remove = function(branch, entry) branch.spellLists[entry.key] = nil end,
        -- Which spells a list holds is edited on the SpellID Filters page, so the row reports what
        -- the attachment currently contributes rather than repeating its name.
        render = function(row, _, entry)
            row:Text(entry.label, { width = 0.75, text = ListSummary(entry.key), height = rowH, bgMode = 'hide' })
        end,
    },
}

local function FilterOptions()
    local opts = {}
    for _, e in ipairs(AuraFilters:GetList()) do opts[e.key] = e.text end
    return opts
end

-- Detail page for one branch of a filter spec. Branches are OR'd: an aura shows when it matches any
-- of them, so each branch carries its own base type, tokens and candidates.
local function BuildFilterPage(page, name, branchIndex)
    local spec = Store()[name]
    local branch = spec and spec.branches and spec.branches[branchIndex]
    if not branch then
        page:Card(L['Error']):Row(rowH, 0):Text(L['Error'], {
            width = 1, text = format(L["Filter '%s' not found."], name), height = rowH, bgMode = 'hide',
        })
        return
    end

    local function Changed() AuraFilters:Invalidate(name) end

    local card = page:Card(format(L['Filter: %s'], spec.name or name))
    card:Rebuild(function(c)
        -- Every branch needs a base type, so this one is not a removable condition.
        c:Row(rowH):Dropdown(L['Aura Type'], {
            width = 1,
            options = BASE_TYPES,
            value = branch.type or AF.Harmful,
            callback = function(v)
                branch.type = v
                Changed()
            end,
        })

        -- Everything not already on the branch, grouped by kind so 'Token: Player' reads unambiguously
        -- next to 'Aura Flag: Boss Aura'. Picking one adds it and redraws the card in place.
        local addable = {}
        for _, kindDef in ipairs(CONDITION_KINDS) do
            for _, entry in ipairs(kindDef.entries()) do
                if not kindDef.isAdded(branch, entry) then
                    addable[#addable + 1] = {
                        value = kindDef.kind .. ':' .. entry.key,
                        text = format('%s: %s', kindDef.category, entry.label),
                        kindDef = kindDef,
                        entry = entry,
                    }
                end
            end
        end

        c:Row(rowH):Dropdown(L['Add Condition'], {
            width = 1,
            searchable = true,
            options = addable,
            value = '',
            callback = function(value)
                for _, option in ipairs(addable) do
                    if option.value == value then
                        option.kindDef.add(branch, option.entry)
                        Changed()
                        c:Rebuild()
                        return
                    end
                end
            end,
        })

        c:Separator()

        -- Added conditions, in catalogue order so the list does not reshuffle as things are added.
        local added = {}
        for _, kindDef in ipairs(CONDITION_KINDS) do
            for _, entry in ipairs(kindDef.entries()) do
                if kindDef.isAdded(branch, entry) then
                    added[#added + 1] = { kindDef = kindDef, entry = entry }
                end
            end
        end

        if not added[1] then
            c:Row(rowH):Text(L['Conditions'], {
                width = 1,
                text = L['No conditions yet. Add one above to start narrowing this branch.'],
                height = rowH,
                bgMode = 'hide',
            })
        end

        for _, item in ipairs(added) do
            local row = c:Row(rowH)
            item.kindDef.render(row, branch, item.entry, Changed)
            row:Button(L['Remove'], {
                width = 0.25,
                height = 24,
                yOffset = -14,
                callback = function()
                    item.kindDef.remove(branch, item.entry)
                    Changed()
                    c:Rebuild()
                end,
            })
        end

        c:Separator()

        local branchRow = c:Row(rowHL - 14, 0)
        local canDelete = #spec.branches > 1
        branchRow:Button(L['Add Branch'], {
            width = canDelete and 0.5 or 1,
            height = 24,
            yOffset = -2,
            tooltip = L['Adds another set of conditions. An aura is shown when it matches any branch.'],
            callback = function()
                spec.branches[#spec.branches + 1] = { type = branch.type or AF.Harmful }
                AuraFilters:Invalidate(name)
                Reopen(name, #spec.branches)
            end,
        })
        if canDelete then
            branchRow:Button(L['Delete Branch'], {
                width = 0.5,
                height = 24,
                yOffset = -2,
                callback = function()
                    NRSKNUI:CreatePrompt({
                        title = L['Delete Branch'],
                        text = format(L['Delete branch %d? This cannot be undone.'], branchIndex),
                        onAccept = function()
                            tremove(spec.branches, branchIndex)
                            AuraFilters:Invalidate(name)
                            Reopen(name, min(branchIndex, #spec.branches))
                        end,
                        acceptText = L['Delete'],
                        cancelText = L['Cancel'],
                    })
                end,
            })
        end
    end)
end

-- A page-level sidebar alongside mode='tabs' is sidebar-outer: the selected filter decides the tab
-- strip, so a filter's branches become its tabs (see LibKaji ContentArea.lua).
GUI:RegisterPage('filterBuilder', {
    mode = 'tabs',
    search = {},
    sidebar = {
        buttons = {
            { text = L['New Filter'], onClick = CreateFilterPrompt },
        },
        items = function()
            local items = {}
            for _, e in ipairs(AuraFilters:GetList()) do
                items[#items + 1] = { key = e.key, text = e.text }
            end
            return items
        end,
        onContextMenu = function(key)
            if not (Store() and Store()[key]) then return end

            GUI:ShowContextMenu({
                { text = L['Rename'], onClick = function() RenameFilterPrompt(key) end },
                { divider = true },
                { text = L['Delete'], onClick = function() DeleteFilterPrompt(key) end },
            })
        end,
    },
    -- With no filters yet there is no item to derive a tab strip from, so the strip carries the
    -- empty state instead.
    tabs = function(itemKey)
        local spec = itemKey and Store() and Store()[itemKey]
        if not spec then
            return { { id = 'main', text = L['Filter Builder'] } }
        end

        local tabs = {}
        for index = 1, max(#(spec.branches or {}), 1) do
            tabs[index] = { id = tostring(index), text = format(L['Branch %d'], index) }
        end
        return tabs
    end,
    build = function(page, tabId, itemKey)
        if not NRSKNUI.db or not Store() then return end

        if not itemKey then
            page:Card(L['Filter Builder']):Row(rowH, 0):Text(L['Filter Builder'], {
                width = 1,
                text = L['No filters yet. Use New Filter to create one.'],
                height = rowH,
                bgMode = 'hide',
            })
            return
        end

        BuildFilterPage(page, itemKey, tonumber(tabId) or 1)
    end,
})

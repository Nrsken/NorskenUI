---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local AuraFilters = NRSKNUI.AuraFilters

local ipairs, pairs, type, tonumber = ipairs, pairs, type, tonumber
local tsort = table.sort
local format = string.format
local GetSpellName = C_Spell and C_Spell.GetSpellName

local LIST_TYPES = {
    { value = 'blacklist', text = L['Blacklist'] },
    { value = 'whitelist', text = L['Whitelist'] },
}

local function Lists() return NRSKNUI.db.global.AuraSpellLists end

-- Reopen the page so the sidebar re-reads its item list, selecting `selectKey`.
local function Reopen(selectKey)
    local window = NRSKNUI.GUIFrame
    if not (window and window.content) then return end
    window.content:ShowPage('spellIDFilters', selectKey and { itemKey = selectKey } or nil)
end

---Repoint every filter branch that attached `oldName` at `newName`, so a rename never orphans a
---reference. Branches are the only thing that reference a list, and they all live in db.global.
---@param oldName string
---@param newName string
local function RetargetAttachments(oldName, newName)
    for _, spec in pairs(NRSKNUI.db.global.AuraFilters or {}) do
        for _, branch in ipairs((type(spec) == 'table' and spec.branches) or {}) do
            if branch.spellLists and branch.spellLists[oldName] then
                branch.spellLists[oldName] = nil
                branch.spellLists[newName] = true
            end
        end
    end
end

---Drop `name` from every filter branch that attached it, so a deleted list leaves nothing behind.
---@param name string
local function ClearAttachments(name)
    for _, spec in pairs(NRSKNUI.db.global.AuraFilters or {}) do
        for _, branch in ipairs((type(spec) == 'table' and spec.branches) or {}) do
            if branch.spellLists then branch.spellLists[name] = nil end
        end
    end
end

-- Lists are created, renamed and deleted from the sidebar (its New List button and the right-click
-- menu on each entry), matching how the Filter Builder page manages filters.

local function CreateListPrompt()
    NRSKNUI:CreatePrompt({
        title = L['Create SpellID List'],
        text = '',
        editBox = true,
        editBoxLabel = L['List Name'],
        onAccept = function(name)
            if not name or name == '' then
                NRSKNUI:Print(L['Please enter a list name'])
                return
            end
            if Lists()[name] then
                NRSKNUI:Print(L['A list with that name already exists'])
                return
            end
            -- Blacklist is the safer default: a fresh whitelist would hide every aura until filled.
            Lists()[name] = { name = name, type = 'blacklist', spells = {} }
            AuraFilters:Invalidate()
            Reopen(name)
        end,
        acceptText = L['Create'],
        cancelText = L['Cancel'],
    })
end

local function RenameListPrompt(name)
    local list = Lists()[name]
    if not list then return end

    NRSKNUI:CreatePrompt({
        title = L['Rename List'],
        text = '',
        editBox = true,
        editBoxLabel = L['New Name'],
        onAccept = function(new)
            if not new or new == '' then return end
            if Lists()[new] then
                NRSKNUI:Print(L['A list with that name already exists'])
                return
            end
            list.name = new
            Lists()[new] = list
            Lists()[name] = nil
            RetargetAttachments(name, new)
            AuraFilters:Invalidate()
            Reopen(new)
        end,
        acceptText = L['Rename'],
        cancelText = L['Cancel'],
    })
end

local function DeleteListPrompt(name)
    local list = Lists()[name]
    if not list then return end

    NRSKNUI:CreatePrompt({
        title = L['Delete List'],
        text = format(L["Delete the list '%s'? This cannot be undone."], list.name or name),
        onAccept = function()
            Lists()[name] = nil
            ClearAttachments(name)
            AuraFilters:Invalidate()
            Reopen()
        end,
        acceptText = L['Delete'],
        cancelText = L['Cancel'],
    })
end

-- Detail page for one spellID list: its type, then the spells it holds.
local function BuildListPage(page, key)
    local list = Lists()[key]
    if not list then
        page:Card(L['Error']):Row(rowH, 0):Text(L['Error'], {
            width = 1, text = format(L["List '%s' not found."], key), height = rowH, bgMode = 'hide',
        })
        return
    end

    local card = page:Card(list.name or key)
    card:Rebuild(function(c)
        c:Row(rowH):Dropdown(L['Type'], {
            width = 1,
            tooltip = L['A whitelist shows only these spells, a blacklist hides them.'],
            options = LIST_TYPES,
            value = list.type or 'blacklist',
            callback = function(v)
                list.type = v
                AuraFilters:Invalidate()
            end,
        })

        local addRow = c:Row(rowH)
        local idInput = addRow:EditBox(L['Spell ID'], { width = 0.75, value = '' })
        addRow:Button(L['Add'], {
            width = 0.25,
            height = 24,
            yOffset = -14,
            callback = function()
                local id = tonumber(idInput:GetValue())
                if not id then
                    NRSKNUI:Print(L['Enter a numeric spell ID'])
                    return
                end
                local sname = GetSpellName and GetSpellName(id)
                if not sname then
                    NRSKNUI:Print(format(L['No spell found for ID %d'], id))
                    return
                end
                if NRSKNUI:IsSpellAuraProtected(id) then
                    NRSKNUI:CreatePrompt({
                        title = L['Protected Spell'],
                        text = format(L["'%s' (%d) is protected and cannot be used in aura filters."], sname, id),
                        acceptText = L['OK'],
                    })
                    return
                end
                list.spells = list.spells or {}
                list.spells[id] = { label = sname, enabled = true }
                AuraFilters:Invalidate()
                idInput:SetValue('')
                c:Rebuild()
            end,
        })

        c:Separator()

        local ids = {}
        for sid in pairs(list.spells or {}) do ids[#ids + 1] = sid end
        tsort(ids)

        if #ids == 0 then
            c:Row(rowH, 0):Text(list.name or key, {
                width = 1, text = L['No spells in this list yet.'], height = rowH, bgMode = 'hide',
            })
            return
        end

        for index, sid in ipairs(ids) do
            local entry = list.spells[sid]
            local last = index == #ids
            local row = c:Row(last and rowHL or rowH, last and 0 or nil)
            row:Checkbox(format('%s (%d)', entry.label or '?', sid), {
                width = 0.75,
                value = entry.enabled ~= false,
                callback = function(checked)
                    entry.enabled = checked
                    AuraFilters:Invalidate()
                end,
            })
            row:Button(L['Remove'], {
                width = 0.25,
                height = 24,
                yOffset = -14,
                callback = function()
                    list.spells[sid] = nil
                    AuraFilters:Invalidate()
                    c:Rebuild()
                end,
            })
        end
    end)
end

GUI:RegisterPage('spellIDFilters', {
    mode = 'clean',
    search = {},
    sidebar = {
        buttons = {
            { text = L['New List'], onClick = CreateListPrompt },
        },
        items = function()
            local names = {}
            for name in pairs(Lists() or {}) do names[#names + 1] = name end
            tsort(names)

            local items = {}
            for _, name in ipairs(names) do
                items[#items + 1] = { key = name, text = Lists()[name].name or name }
            end
            return items
        end,
        onContextMenu = function(key)
            if not (Lists() and Lists()[key]) then return end

            GUI:ShowContextMenu({
                { text = L['Rename'], onClick = function() RenameListPrompt(key) end },
                { divider = true },
                { text = L['Delete'], onClick = function() DeleteListPrompt(key) end },
            })
        end,
    },
    build = function(page, _, itemKey)
        if not NRSKNUI.db or not Lists() then return end

        if not itemKey then
            page:Card(L['SpellID Filters']):Row(rowH, 0):Text(L['SpellID Filters'], {
                width = 1,
                text = L['No lists yet. Use New List to create one.'],
                height = rowH,
                bgMode = 'hide',
            })
            return
        end

        BuildListPage(page, itemKey)
    end,
})

---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local pairs, ipairs = pairs, ipairs
local format = string.format

local Shared = NRSKNUI.CDMOptions
local EnsureModuleEnabled, GENERAL, Reopen, TYPE_NAMES = Shared.EnsureModuleEnabled, Shared.GENERAL, Shared.Reopen, Shared.TYPE_NAMES

local IMPORT_BOX_HEIGHT = 120
local importState = { text = '', mode = 'update', picked = {} } ---@type { text: string, plan: table?, error: string?, mode: 'update'|'copy', picked: table<string, boolean> }

---@param text string
local function ReadImport(text)
    importState.text = text
    local payload, err = CDM:DecodeImport(text)
    importState.error = err
    importState.plan = payload and CDM:PlanImport(payload) or nil
    importState.mode = importState.plan and importState.plan.target and CDM:Get(importState.plan.target).preferToUpdate and 'update' or 'copy'
    importState.picked = {}
    for _, category in ipairs(CDM.IMPORT_CATEGORIES) do importState.picked[category.key] = category.default end
end

local RADIO_ROW_HEIGHT = 20 -- a Radio without a description is 16 tall

---@param card table
---@param lines string[]
local function TextBlock(card, lines)
    local height = #lines * 16
    card:Row(height):Text(nil, { width = 1, height = height, autoHeight = true, bgMode = 'hide', text = table.concat(lines, '\n') })
end

---What an import would add or change.
---@param card table
local function BuildImportSummary(card)
    local plan = importState.plan
    if importState.error then
        TextBlock(card, { NRSKNUI:ColorText(importState.error, Theme.warning) })
        return
    elseif not plan then
        TextBlock(card, { NRSKNUI:ColorText(L['Paste a string to see what it adds.'], Theme.textSecondary) })
        return
    end

    local d, root = plan.payload.d, plan.payload.d[plan.payload.root]
    local hasChanges = plan.target and not plan.blocked and next(plan.categories) ~= nil
    local bullet = NRSKNUI:ColorText('• ', Theme.accent) -- Kaji Text's own list bullet
    local lines = {
        NRSKNUI:ColorText(L['Importing:'], Theme.accent) .. ' ' .. root.name,
        bullet .. format(L['Made with NorskenUI %s'], tostring(plan.payload._a)),
        bullet .. (TYPE_NAMES[root.type] or root.type),
        bullet .. (plan.count == 1 and L['1 display'] or format(L['%d displays'], plan.count)),
    }
    if root.Description then lines[#lines + 1] = bullet .. root.Description end
    if plan.blocked then
        lines[#lines + 1] = bullet .. L['You have this under another display type, so it can only be imported as a copy.']
    elseif plan.target and not hasChanges then
        lines[#lines + 1] = bullet .. L['You already have this.']
    elseif hasChanges then
        lines[#lines + 1] = bullet .. format(L['This is a changed version of your %s.'], NRSKNUI:ColorText(CDM:GetName(plan.target), Theme.accent))

        local labels = {}
        for _, category in ipairs(CDM.IMPORT_CATEGORIES) do labels[category.key] = category.label end
        local added, modified, removed = {}, {}, {}
        for _, key in ipairs(plan.added) do added[#added + 1] = d[key].name end
        for key, changed in pairs(plan.modified) do
            local names = {}
            for _, category in ipairs(CDM.IMPORT_CATEGORIES) do
                if changed[category.key] then names[#names + 1] = labels[category.key] end
            end
            modified[#modified + 1] = format('%s (%s)', d[key].name, table.concat(names, ', '))
        end
        for _, id in ipairs(plan.removed) do removed[#removed + 1] = CDM:GetName(id) end
        for _, list in ipairs({ { title = L['Added'], names = added }, { title = L['Modified'], names = modified }, { title = L['Removed'], names = removed } }) do
            if list.names[1] then
                table.sort(list.names)
                lines[#lines + 1] = ''
                lines[#lines + 1] = NRSKNUI:ColorText(list.title, Theme.accent)
                for _, name in ipairs(list.names) do lines[#lines + 1] = bullet .. name end
            end
        end
    end
    TextBlock(card, lines)

    local update = hasChanges and importState.mode == 'update'
    if hasChanges then
        card:Separator(L['What do you want to do?'], { useLabel = true })
        local previous
        local modes = { { id = 'copy', text = L['Create a Copy'] }, { id = 'update', text = L['Update Displays'] } }
        for i, mode in ipairs(modes) do
            previous = card:Row(RADIO_ROW_HEIGHT, i == #modes and 0 or nil):Radio(mode.text, {
                width = 1,
                selected = importState.mode == mode.id,
                linkTo = previous,
                callback = function()
                    importState.mode = mode.id
                    card:Rebuild()
                end,
            })
        end
        if update then
            card:Separator(L['Categories to Update'], { useLabel = true })
            local row
            local shown = 0
            for _, category in ipairs(CDM.IMPORT_CATEGORIES) do
                if plan.categories[category.key] then
                    shown = shown + 1
                    if shown % 2 == 1 then row = card:Row(rowH) end
                    row:Checkbox(category.label, {
                        width = 0.5,
                        value = importState.picked[category.key],
                        callback = function(checked) importState.picked[category.key] = checked end,
                    })
                end
            end
        end
    end

    card:Separator()
    card:Row(30, 0):Button(update and L['Update'] or (plan.target and L['Import as Copy'] or L['Import']), {
        width = 1,
        height = 24,
        callback = function()
            local mode, picked = update and 'update' or 'copy', importState.picked
            NRSKNUI:RunWhenSafe(function()
                local id = CDM:ApplyImport(plan, mode, picked)
                ReadImport('')
                EnsureModuleEnabled()
                CDM:ApplySettings()
                Reopen(id)
            end)
        end,
    })
end

---Paste a string and see what it adds or updates before importing it.
---@param page table
local function BuildImportPage(page)
    page:SetEnabled(function() return CDM.db.Enabled end)
    ReadImport(importState.text) -- the tree may have changed since the string was pasted
    local summary
    page:Card(L['Import'], 'all'):HeaderButton({
        texture = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\right-arrow.png',
        size = 20,
        rotation = math.pi,
        tooltip = L['Back'],
        onClick = function() Reopen(GENERAL) end,
    }):Row(IMPORT_BOX_HEIGHT + 18, 0):MultiLineEditBox(L['Import String'], {
        width = 1,
        height = IMPORT_BOX_HEIGHT,
        value = importState.text,
        tooltip = L['CTRL+V to paste, CTRL+A to select all'],
        onTextChanged = function(text)
            ReadImport(text)
            summary:Rebuild()
        end,
    })
    summary = page:Card(L['Contents'], 'all')
    summary:Rebuild(BuildImportSummary)
end

Shared.BuildImportPage = BuildImportPage

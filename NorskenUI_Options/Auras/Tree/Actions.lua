---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Auras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI

local ipairs = ipairs
local format = string.format
local CopyTable = CopyTable
local RunNextFrame = RunNextFrame

local Shared = NRSKNUI.CDMOptions
local EnsureModuleEnabled, Reopen, TRIGGER_DEFAULTS, Tree = Shared.EnsureModuleEnabled, Shared.Reopen, Shared.TRIGGER_DEFAULTS, Shared.Tree

-- Actions --

---Select a display that was just created and open its name for editing in the tree.
---@param id string
local function SelectAndRename(id)
    EnsureModuleEnabled()
    CDM:ApplySettings(id)
    Reopen(id)
    RunNextFrame(function()
        local tree = Tree()
        if tree then tree:BeginRename(id) end
    end)
end

---@param parentId string?
local function NewIcon(parentId)
    SelectAndRename(CDM:CreateIcon(L['New Icon'], { Type = 'spell' }, parentId))
end

---A new progress bar starts as a cast bar, its trigger picks what it shows.
---@param parentId string?
local function NewProgressBar(parentId)
    local trigger = CopyTable(TRIGGER_DEFAULTS.cast)
    trigger.Type = 'cast'
    SelectAndRename(CDM:CreateBar(L['New Progress Bar'], trigger, parentId))
end

---@param parentId string?
local function NewText(parentId)
    SelectAndRename(CDM:CreateText(L['New Text'], { Type = 'spell' }, parentId))
end

---@param parentId string?
local function NewResourceBar(parentId)
    local id = CDM:CreateResourceBar(parentId)
    if not id then
        NRSKNUI:Print(L['Your class has no Runes, Holy Power or Combo Points.'])
        return
    end
    SelectAndRename(id)
end

---@param dynamic boolean
---@param parentId string?
local function NewGroup(dynamic, parentId)
    SelectAndRename(CDM:CreateGroup(dynamic and L['New Dynamic Group'] or L['New Group'], dynamic, parentId))
end

---@param parentId string?
local function NewAuraGroup(parentId)
    SelectAndRename(CDM:CreateAuraGroup(L['New Aura Group'], nil, parentId))
end

---@param id string
local function ToggleDisplay(id)
    local display = CDM:Get(id)
    display.Enabled = not display.Enabled
    CDM:ApplySettings(id)
    local tree = Tree()
    Reopen(tree and tree:GetSelected() or id)
end

---@param id string
local function DuplicateDisplay(id)
    local newId = CDM:Duplicate(id)
    if not newId then return end

    CDM:ApplySettings()
    Reopen(newId)
end

local COPY_PARTS = {
    { part = 'all',        text = L['Everything'], paste = L['Paste Settings'] },
    { part = 'display',    text = L['Display'],    paste = L['Paste Display Settings'] },
    { part = 'trigger',    text = L['Trigger'],    paste = L['Paste Trigger Settings'] },
    { part = 'conditions', text = L['Conditions'], paste = L['Paste Condition Settings'] },
    { part = 'load',       text = L['Load'],       paste = L['Paste Load Settings'] },
}
local GROUP_PARTS = {
    { part = 'group', text = L['Group'], paste = L['Paste Group Settings'] },
}
local AURA_GROUP_PARTS = { COPY_PARTS[1], COPY_PARTS[2], COPY_PARTS[3], COPY_PARTS[5] } -- an aura group has no conditions

local clipboard ---@type { source: table, part: table }? -- kept for the session only

---@param id string
local function PasteSettings(id)
    CDM:PasteSettings(clipboard.source, id, clipboard.part.part)
    CDM:ApplySettings(id)
    Reopen(id)
end

---@param id string
---@param keepChildren boolean?
local function DeletePrompt(id, keepChildren)
    local name = CDM:GetName(id)
    local inside = not keepChildren and CDM:IsGroup(id) and #CDM:GetLeaves(id) or 0
    local text
    if keepChildren then
        text = format(L["Remove the group '%s'? Everything inside it stays."], name)
    elseif inside > 0 then
        text = format(L["Delete '%s' and the %d displays inside it? This cannot be undone."], name, inside)
    else
        text = format(L["Delete '%s'? This cannot be undone."], name)
    end

    NRSKNUI:CreatePrompt({
        title = L['Delete'],
        text = text,
        onAccept = function()
            CDM:Delete(id, keepChildren)
            CDM:ApplySettings()
            Reopen()
        end,
        acceptText = L['Delete'],
        cancelText = L['Cancel'],
    })
end

---Right click on a multi selection.
---@param ids string[]
local function MultiContextMenu(ids)
    GUI:ShowContextMenu({
        {
            text = L['Delete All'],
            onClick = function()
                -- everything that goes: the picked rows and what their groups hold, each once
                local going, count = {}, 0
                for _, id in ipairs(ids) do
                    local all = CDM:IsGroup(id) and CDM:GetLeaves(id) or {}
                    all[#all + 1] = id
                    for _, key in ipairs(all) do
                        if not going[key] then
                            going[key] = true
                            count = count + 1
                        end
                    end
                end
                NRSKNUI:CreatePrompt({
                    title = L['Delete All'],
                    text = format(L['Delete %d displays? This cannot be undone.'], count),
                    onAccept = function()
                        for _, id in ipairs(ids) do CDM:Delete(id) end -- a child already taken by its group is skipped
                        CDM:ApplySettings()
                        Reopen()
                    end,
                    acceptText = L['Delete'],
                    cancelText = L['Cancel'],
                })
            end,
        },
    })
end

---A built-in aura group's two resets, as the Auras page had them: its spells, or everything.
---@param id string
---@param entries table[]
local function BuiltinResetEntries(id, entries)
    local display = CDM:Get(id)
    local shipped = NRSKNUI.AuraTriggers:GetShipped(display.Trigger)
    if shipped and (shipped.Added or shipped.Removed) then
        entries[#entries + 1] = {
            text = L['Reset Spells to Default'],
            onClick = function()
                NRSKNUI:CreatePrompt({
                    title = L['Reset Spells to Default'],
                    text = L['Remove the spells you added and switch every default spell back on?'],
                    onAccept = function()
                        shipped.Added, shipped.Removed = nil, nil
                        NRSKNUI.AuraTriggers:Invalidate()
                        Reopen(id)
                    end,
                    acceptText = L['Reset'],
                    cancelText = L['Cancel'],
                })
            end,
        }
    end
    entries[#entries + 1] = {
        text = L['Reset Everything to Default'],
        onClick = function()
            NRSKNUI:CreatePrompt({
                title = L['Reset Everything to Default'],
                text = format(L["Put '%s' back to how it shipped, spells, layout and position included?"], CDM:GetName(id)),
                onAccept = function()
                    CDM:ResetBuiltin(id)
                    CDM:ApplySettings(id)
                    NRSKNUI.AuraTriggers:Invalidate()
                    Reopen(id)
                end,
                acceptText = L['Reset'],
                cancelText = L['Cancel'],
            })
        end,
    }
end

---@param id string
local function ContextMenu(id)
    local display = CDM:Get(id)
    local isGroup = CDM:IsGroup(id)
    local entries = {}
    if isGroup then
        entries[#entries + 1] = { text = L['Add Icon'], onClick = function() NewIcon(id) end }
        entries[#entries + 1] = { text = L['Add Progress Bar'], onClick = function() NewProgressBar(id) end }
        entries[#entries + 1] = { text = L['Add Text'], onClick = function() NewText(id) end }
        if display.type == 'group' then
            entries[#entries + 1] = { text = L['Add Aura Group'], onClick = function() NewAuraGroup(id) end }
            entries[#entries + 1] = { text = L['Add Group'], onClick = function() NewGroup(false, id) end }
            entries[#entries + 1] = { text = L['Add Dynamic Group'], onClick = function() NewGroup(true, id) end }
        end
        entries[#entries + 1] = { divider = true }
    end
    entries[#entries + 1] = { text = display.Enabled and L['Disable'] or L['Enable'], onClick = function() ToggleDisplay(id) end }
    entries[#entries + 1] = { text = L['Rename'], onClick = function() Tree():BeginRename(id) end }
    entries[#entries + 1] = { text = L['Duplicate'], onClick = function() DuplicateDisplay(id) end }
    entries[#entries + 1] = {
        text = L['Export'],
        onClick = function()
            local text = CDM:Export(id)
            if text then NRSKNUI:CreateCopyDialog(format(L['Export %s'], CDM:GetName(id)), text) end
        end,
    }

    local copyEntries = {}
    local parts = isGroup and GROUP_PARTS or display.type == 'auragroup' and AURA_GROUP_PARTS or COPY_PARTS
    for _, part in ipairs(parts) do
        copyEntries[#copyEntries + 1] = {
            text = part.text,
            onClick = function() clipboard = { source = CopyTable(display), part = part } end,
        }
    end
    entries[#entries + 1] = { text = L['Copy settings...'], submenu = copyEntries }
    if clipboard and CDM:CanPasteSettings(clipboard.source, id) then
        entries[#entries + 1] = { text = clipboard.part.paste, onClick = function() PasteSettings(id) end }
    end
    if display.builtin then BuiltinResetEntries(id, entries) end

    if display.parent then
        entries[#entries + 1] = {
            text = L['Remove from Group'],
            onClick = function()
                CDM:Ungroup(id)
                CDM:ApplySettings()
                Reopen(id)
            end,
        }
    end

    entries[#entries + 1] = { divider = true }
    if isGroup then
        entries[#entries + 1] = { text = L['Ungroup'], onClick = function() DeletePrompt(id, true) end }
        entries[#entries + 1] = { text = L['Delete Group and Contents'], onClick = function() DeletePrompt(id) end }
    else
        entries[#entries + 1] = { text = L['Delete'], onClick = function() DeletePrompt(id) end }
    end

    GUI:ShowContextMenu(entries)
end

Shared.ContextMenu = ContextMenu
Shared.MultiContextMenu = MultiContextMenu
Shared.NewAuraGroup = NewAuraGroup
Shared.NewGroup = NewGroup
Shared.NewIcon = NewIcon
Shared.NewProgressBar = NewProgressBar
Shared.NewResourceBar = NewResourceBar
Shared.NewText = NewText

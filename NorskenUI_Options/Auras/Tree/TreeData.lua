---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Auras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Thumbnail = NRSKNUI.CDMThumbnail
local Theme = NRSKNUI.Theme
local IconPicker = NRSKNUI.CDMIconPicker

local pairs, ipairs = pairs, ipairs
local format = string.format

local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture

local Shared = NRSKNUI.CDMOptions
local CAST_ICON, GENERAL, IMPORT, IsCollapsed = Shared.CAST_ICON, Shared.GENERAL, Shared.IMPORT, Shared.IsCollapsed
local QUESTION_MARK, SECTION_LOADED, SECTION_UNLOADED, SETTINGS = Shared.QUESTION_MARK, Shared.SECTION_LOADED, Shared.SECTION_UNLOADED, Shared.SETTINGS
local TRINKETS, TYPE_NAMES, expandedGroups = Shared.TRINKETS, Shared.TYPE_NAMES, Shared.expandedGroups

-- Tree data --

---@param id string
---@return number|string
local function DisplayIcon(id)
    local display = CDM:Get(id)
    if CDM.LAYERED_TYPES[display.type] then
        local style = CDM:GetStyle(display)
        if style.IconSource == 'manual' and style.ManualIcon then return style.ManualIcon end -- as CDM:SetIconTexture draws it
        for _, trigger in ipairs(display.Triggers) do
            if trigger.Type ~= 'auraoverlay' then                                             -- an overlay sits on the icon below it
                return CDM:GetTriggerTexture(trigger) or (trigger.Type == 'cast' and CAST_ICON) or style.ManualIcon or QUESTION_MARK
            end
        end
        return style.ManualIcon or QUESTION_MARK
    end
    if display.Icon then return display.Icon end
    if display.type == 'auragroup' then
        -- The lowest spell ID of the first spell list, presets resolved.
        for _, branch in ipairs(NRSKNUI:GetTriggerBranches(display.Trigger)) do
            local lowest
            for spellID in pairs(branch.candidates and branch.candidates.includeSpellIDs or {}) do
                if not lowest or spellID < lowest then lowest = spellID end
            end
            if lowest then return GetSpellTexture(lowest) or QUESTION_MARK end
        end
    end
    return QUESTION_MARK
end

---A group's load state, preview and icon come from its children's rows, as CDM:GetLoadState/GetPreview read its leaves.
---@param id string
---@param depth number
---@param childIndex table<string, table[]> from CDM:GetChildrenIndex
---@param index number? position among its group's children
---@param count number? children in its group
---@return table
local function RowData(id, depth, childIndex, index, count)
    local display = CDM:Get(id)
    local isGroup = CDM:IsGroup(id)
    local children = isGroup and (childIndex[id] or {}) or nil

    local data = {
        key = id,
        text = display.name,
        isGroup = isGroup,
        depth = depth,
        enabled = display.Enabled,
        draggable = true,
        expanded = isGroup and expandedGroups[display.uid] == true,
        childCount = children and #children or 0,
        canMoveUp = index ~= nil and index > 1,
        canMoveDown = index ~= nil and index < count,
    }

    -- the row's warning marker: its own warnings and on a group how many displays inside have some
    local warnings = CDM:GetWarnings(id)
    data.warned = not isGroup and warnings[1] and 1 or 0

    if isGroup then
        local rank = CDM.STATE_RANK
        local best, leafIcon
        local leaves, pinned, hidden = 0, 0, 0
        data.children = {}
        for i, child in ipairs(children) do
            local row = RowData(child.key, depth + 1, childIndex, i, #children)
            data.children[i] = row
            data.warned = data.warned + row.warned
            if row.leaves > 0 then -- an empty group inside adds nothing, as it has no leaves
                if not best or rank[row.loadState] > rank[best] then
                    best = row.loadState
                end
                leafIcon = leafIcon or row.leafIcon
                leaves, pinned, hidden = leaves + row.leaves, pinned + row.pinned, hidden + row.hidden
            end
        end
        if data.warned > 0 then
            warnings[#warnings + 1] = format(L['Displays inside with warnings: %d'], data.warned)
        end
        data.loadState = display.Enabled and (best or 'loaded') or 'unloaded'
        data.icon = display.Icon or leafIcon or QUESTION_MARK
        data.preview = (leaves == 0 or hidden == leaves) and 0 or (pinned == leaves and 2 or 1)
        data.leafIcon, data.leaves, data.pinned, data.hidden = leafIcon, leaves, pinned, hidden
    else
        local level = CDM.preview[id] or 0
        data.loadState = CDM:GetLoadState(id)
        data.icon = DisplayIcon(id)
        data.preview = level
        data.leafIcon, data.leaves = data.icon, 1
        data.pinned, data.hidden = level == 2 and 1 or 0, level == 0 and 1 or 0
    end

    data.warnings = warnings[1] and warnings or nil

    local icon = data.icon
    data.draw = function(canvas, size) return Thumbnail:Draw(canvas, display, size, icon) end

    data.tooltip = function(tooltip)
        local accent, secondary, muted = Theme.accent, Theme.textSecondary, Theme.textMuted
        tooltip:SetText(display.name, accent[1], accent[2], accent[3], 1, false)
        tooltip:AddLine(TYPE_NAMES[display.type], secondary[1], secondary[2], secondary[3])
        if display.Description then tooltip:AddLine(display.Description, muted[1], muted[2], muted[3], true) end
        if isGroup then
            if #children == 0 then tooltip:AddLine(L['No Children'], muted[1], muted[2], muted[3]) end
            for _, child in ipairs(children) do tooltip:AddLine('  ' .. child.text, secondary[1], secondary[2], secondary[3]) end
        end
        tooltip:AddLine(' ')
        tooltip:AddLine(L['Right-click for more options'], muted[1], muted[2], muted[3])
        tooltip:AddLine(L['Drag to move'], muted[1], muted[2], muted[3])
    end

    return data
end

---@param row table
---@param into string[]
local function CollectIcons(row, into)
    if not row.isGroup then
        into[#into + 1] = row.key
        return
    end
    for _, child in ipairs(row.children) do CollectIcons(child, into) end
end

---@param section table
---@return string[]
local function SectionIcons(section)
    local ids = {}
    for _, row in ipairs(section.rows) do CollectIcons(row, ids) end
    return ids
end

---@param ids string[]
---@return number level
local function PreviewLevel(ids)
    local pinned, hidden = 0, 0
    for _, id in ipairs(ids) do
        local level = CDM.preview[id] or 0
        if level == 2 then pinned = pinned + 1 elseif level == 0 then hidden = hidden + 1 end
    end
    if #ids == 0 or hidden == #ids then return 0 end
    return pinned == #ids and 2 or 1
end

---Top-level rows go under Loaded/Standby unless every icon they hold is not loaded.
---@return table
local function TreeContent()
    local loaded = {
        key = SECTION_LOADED,
        text = L['Loaded/Standby'],
        collapseText = L['Show or hide the loaded displays'],
        previewText = L['Toggle the visibility of all loaded displays'],
        rows = {},
    }
    local unloaded = {
        key = SECTION_UNLOADED,
        text = L['Not Loaded'],
        collapseText = L['Show or hide the displays that are not loaded'],
        previewText = L['Toggle the visibility of all displays that are not loaded'],
        rows = {},
    }

    local childIndex = CDM:GetChildrenIndex()
    for _, root in ipairs(CDM:GetRoots()) do
        local data = RowData(root.key, 0, childIndex)
        local section = data.loadState == 'unloaded' and unloaded or loaded
        section.rows[#section.rows + 1] = data
    end

    for _, section in ipairs({ loaded, unloaded }) do
        section.collapsed = IsCollapsed(section.key)
        section.preview = PreviewLevel(SectionIcons(section))
    end

    return {
        general = { key = GENERAL, text = L['General'] },
        pages = {
            { key = TRINKETS,        text = L['Trinket Blacklist'] },
            { key = SETTINGS,        text = L['Cooldown & Aura Manager Settings'] },
            { key = IMPORT,          text = L['Import'] },
            { key = IconPicker.PAGE, text = L['Choose an Icon'] },
        },
        sections = { loaded, unloaded },
    }
end

Shared.PreviewLevel = PreviewLevel
Shared.SectionIcons = SectionIcons
Shared.TreeContent = TreeContent

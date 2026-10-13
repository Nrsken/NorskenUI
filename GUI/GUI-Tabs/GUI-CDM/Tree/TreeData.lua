---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Thumbnail = NRSKNUI.CDMThumbnail
local Theme = NRSKNUI.Theme
local IconPicker = NRSKNUI.CDMIconPicker

local pairs, ipairs = pairs, ipairs

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
                return CDM:GetTriggerTexture(trigger) or (trigger.Type == 'cast' and CAST_ICON) or QUESTION_MARK
            end
        end
        return QUESTION_MARK
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
        return QUESTION_MARK
    end

    local first = CDM:GetLeaves(id)[1]
    return first and DisplayIcon(first) or QUESTION_MARK
end

---@param id string
---@param index number? position among its group's children
---@param count number? children in its group
---@return table
local function RowData(id, index, count)
    local display = CDM:Get(id)
    local isGroup = CDM:IsGroup(id)
    local children = isGroup and CDM:GetChildren(id) or nil
    local icon = DisplayIcon(id)

    local data = {
        key = id,
        text = display.name,
        icon = icon,
        draw = function(canvas, size) return Thumbnail:Draw(canvas, display, size, icon) end,
        isGroup = isGroup,
        depth = CDM:GetDepth(id),
        enabled = display.Enabled,
        loadState = CDM:GetLoadState(id),
        preview = CDM:GetPreview(id),
        draggable = true,
        expanded = isGroup and expandedGroups[id] == true,
        childCount = children and #children or 0,
        canMoveUp = index ~= nil and index > 1,
        canMoveDown = index ~= nil and index < count,
    }

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

    if isGroup then
        data.children = {}
        for i, child in ipairs(children) do data.children[i] = RowData(child.key, i, #children) end
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

---Top-level rows go under Loaded/Standby unless every icon they hold is not loaded, as in WeakAuras.
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

    for _, root in ipairs(CDM:GetRoots()) do
        local section = CDM:GetLoadState(root.key) == 'unloaded' and unloaded or loaded
        section.rows[#section.rows + 1] = RowData(root.key)
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

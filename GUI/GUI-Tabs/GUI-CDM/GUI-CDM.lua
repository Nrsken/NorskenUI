---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs = ipairs
local type = type
local tostring = tostring
local format = string.format
local strtrim = strtrim
local tonumber = tonumber
local CopyTable = CopyTable
local GetSpellInfo = C_Spell.GetSpellInfo
local GetSpellTexture = C_Spell.GetSpellTexture
local GetSpellName = C_Spell.GetSpellName

local PAGE = 'cooldownManager'
local GENERAL = 'cdm:general'
local SECTION_LOADED = 'cdm:section:loaded'
local SECTION_UNLOADED = 'cdm:section:unloaded'
local QUESTION_MARK = 134400
local NEW_ROW_HEIGHT = 40

-- WeakAuras' tab order; the ones without settings yet stay empty.
local TABS = {
    { id = 'group',       text = L['Group'] },
    { id = 'display',     text = L['Display'] },
    { id = 'trigger',     text = L['Trigger'] },
    { id = 'conditions',  text = L['Conditions'] },
    { id = 'actions',     text = L['Actions'] },
    { id = 'animations',  text = L['Animations'] },
    { id = 'load',        text = L['Load'] },
    { id = 'custom',      text = L['Custom Options'] },
    { id = 'information', text = L['Information'] },
}

local TYPE_NAMES = {
    icon = L['Icon'],
    group = L['Group'],
    dynamicgroup = L['Dynamic Group'],
}

-- Font keys FontSettingsCard writes, copied across a group's icons after each change.
local FONT_KEYS = { 'UseGlobalFont', 'FontFace', 'FontOutline', 'FontShadow' }

local sectionCollapsed = {} -- [section key] = true, for this session

---@param text string?
---@return SpellInfo? info
local function Lookup(text)
    text = strtrim(text or '')
    if text == '' then return nil end
    -- Names only resolve for spells in the player's own spellbook, IDs always do.
    local info = GetSpellInfo(tonumber(text) or text)
    return info and info.spellID and info or nil
end

---@return table? tree
local function Tree()
    local content = NRSKNUI.GUIFrame and NRSKNUI.GUIFrame.content
    return content and content.miniSidebar
end

local function Reopen(selectKey)
    local window = NRSKNUI.GUIFrame
    if not (window and window.content) then return end

    window.content:ShowPage(PAGE, selectKey and { itemKey = selectKey } or nil)
end

local function RefreshTree()
    local tree = Tree()
    if tree and tree.frame:IsShown() and tree.Render then tree:Render() end
end

local function EnsureModuleEnabled()
    if CDM.db.Enabled then return end
    CDM.db.Enabled = true
    NRSKNUI:ToggleModule('CDM', true)
end

---@param id string?
---@return fun()
local function Applier(id)
    return function() CDM:ApplySettings(id) end
end

---@param key string
---@return boolean
local function IsCollapsed(key)
    return NRSKNUI.db.global.SidebarCollapsed[PAGE][key] == true
end

-- Display (style) --

-- A nested table is copied before its first edit, so icons never share one.
---@param own table
---@param path string[]
---@param value any
local function SetPath(own, path, value)
    local key = path[1]
    if #path == 1 then
        own[key] = type(value) == 'table' and CopyTable(value) or value
        return
    end

    own[key] = CopyTable(own[key] or CDM.STYLE_TEMPLATE[key])
    local node = own[key]
    for i = 2, #path - 1 do node = node[path[i]] end
    node[path[#path]] = value
end

---A collapsible WeakAuras-style section, remembered for the session. Its rows only exist while it is open.
---@param card table
---@param key string
---@param title string
---@return boolean expanded
local function Section(card, key, title)
    return card:Section(title, {
        key = key,
        collapsed = sectionCollapsed[key] == true,
        onToggle = function()
            sectionCollapsed[key] = not sectionCollapsed[key] or nil
            card:Rebuild()
        end,
    })
end

---@param card table
---@param style table read side
---@param set fun(path: string[], value: any)
---@param fontKey string 'CountdownFont'|'ChargeFont'
---@param showToggle string? style key of a checkbox leading the section
local function TextRows(card, style, set, fontKey, showToggle)
    local font = style[fontKey]

    if showToggle then
        card:Row(rowH):Checkbox(L['Show'], {
            width = 1,
            value = style[showToggle],
            callback = function(checked) set({ showToggle }, checked) end,
        })
    end

    local sizeRow = card:Row(rowH)
    sizeRow:Slider(L['Font Size'], {
        width = 0.5,
        min = 6,
        max = 40,
        step = 1,
        value = font.FontSize,
        callback = function(value) set({ fontKey, 'FontSize' }, value) end,
    })
    sizeRow:AnchorPicker(L['Anchor'], {
        width = 0.5,
        value = font.Position.AnchorFrom,
        callback = function(point) set({ fontKey, 'Position', 'AnchorFrom' }, point) end,
    })

    local offsetRow = card:Row(rowH)
    offsetRow:Slider(L['X Offset'], {
        width = 0.5,
        min = -30,
        max = 30,
        step = 1,
        value = font.Position.XOffset,
        callback = function(value) set({ fontKey, 'Position', 'XOffset' }, value) end,
    })
    offsetRow:Slider(L['Y Offset'], {
        width = 0.5,
        min = -30,
        max = 30,
        step = 1,
        value = font.Position.YOffset,
        callback = function(value) set({ fontKey, 'Position', 'YOffset' }, value) end,
    })
end

---Style controls for one icon, or every icon in a group at once (WeakAuras' group editing).
---Controls show the first icon's values.
---@param page table
---@param iconIds string[]
---@param apply fun()
local function BuildStyle(page, iconIds, apply)
    if #iconIds == 0 then
        page:Card(L['Display']):Row(rowHL, 0):Text(L['This group has no icons yet.'], { width = 1 })
        return
    end

    local first = CDM:Get(iconIds[1])
    local style = CDM:GetStyle(first)

    local function Set(path, value)
        for _, id in ipairs(iconIds) do SetPath(CDM:Get(id).Style, path, value) end
        apply()
    end

    page:Card(L['Display']):Rebuild(function(card)
        if Section(card, 'icon', L['Icon Settings']) then
            local iconRow = card:Row(rowH)
            iconRow:Slider(L['Size'], {
                width = 0.5,
                min = 16,
                max = 96,
                step = 1,
                value = style.Size,
                callback = function(value) Set({ 'Size' }, value) end,
            })
            iconRow:ColorPicker(L['Border Color'], {
                width = 0.5,
                value = style.BorderColor,
                callback = function(r, g, b, a) Set({ 'BorderColor' }, { r, g, b, a }) end,
            })
        end

        if Section(card, 'cooldown', L['Cooldown Settings']) then
            local swipeRow = card:Row(rowH)
            swipeRow:Checkbox(L['Draw Swipe'], {
                width = 0.5,
                value = style.DrawSwipe,
                callback = function(checked) Set({ 'DrawSwipe' }, checked) end,
            })
            swipeRow:Checkbox(L['Reverse Swipe'], {
                width = 0.5,
                value = style.Reverse,
                callback = function(checked) Set({ 'Reverse' }, checked) end,
            })
            local edgeRow = card:Row(rowH)
            edgeRow:Checkbox(L['Draw Edge'], {
                width = 0.5,
                value = style.DrawEdge,
                callback = function(checked) Set({ 'DrawEdge' }, checked) end,
            })
            edgeRow:Checkbox(L['Show Global Cooldown'], {
                width = 0.5,
                tooltip = L['Run the swipe for the global cooldown too.'],
                value = style.ShowGCD,
                callback = function(checked) Set({ 'ShowGCD' }, checked) end,
            })
            local colorRow = card:Row(rowH)
            colorRow:ColorPicker(L['Swipe Color'], {
                width = 0.5,
                value = style.SwipeColor,
                callback = function(r, g, b, a) Set({ 'SwipeColor' }, { r, g, b, a }) end,
            })
            colorRow:Checkbox(L['Desaturate on Cooldown'], {
                width = 0.5,
                value = style.DesaturateOnCooldown,
                callback = function(checked) Set({ 'DesaturateOnCooldown' }, checked) end,
            })
        end

        if Section(card, 'countdown', L['Countdown Text']) then
            TextRows(card, style, Set, 'CountdownFont', 'ShowCountdown')
        end

        if Section(card, 'charges', L['Charge Text']) then
            TextRows(card, style, Set, 'ChargeFont')
        end
    end)

    page:FontSettingsCard({
        db = first.Style,
        hideFontSize = true,
        onChangeCallback = function()
            for i = 2, #iconIds do
                local other = CDM:Get(iconIds[i]).Style
                for _, key in ipairs(FONT_KEYS) do
                    local value = first.Style[key]
                    other[key] = type(value) == 'table' and CopyTable(value) or value
                end
            end
            apply()
        end,
    })
end

-- Tabs --

---@param page table
---@param display table
---@param apply fun()
local function EnableCard(page, display, apply)
    page:Card(display.name):Row(rowHL, 0):Checkbox(L['Enable'], {
        width = 1,
        master = true,
        value = display.Enabled,
        callback = function(checked)
            display.Enabled = checked
            apply()
            page:Refresh()
            RefreshTree()
        end,
    })
end

---@param page table
---@param id string
local function PositionCard(page, id)
    local display = CDM:Get(id)
    page:PositionCard({
        title = L['Position and Size Settings'],
        db = display,
        showAnchorFrameType = display.parent == nil, -- inside a group it anchors to the group
        showStrata = display.parent == nil,
        disableAnchorFrom = display.type == 'dynamicgroup', -- a dynamic group anchors from its grow direction
        onChangeCallback = Applier(id),
    })
end

---@param page table
---@param id string
local function BuildTriggerTab(page, id)
    local display = CDM:Get(id)
    local trigger = display.Trigger
    local apply = Applier(id)

    EnableCard(page, display, apply)

    local function SetSpell(spellID, cooldownID)
        -- An icon still named after its spell follows the new one.
        if display.name == GetSpellName(trigger.SpellID) then display.name = GetSpellName(spellID) or display.name end
        trigger.SpellID = spellID
        trigger.CooldownID = cooldownID
        apply()
        Reopen(id)
    end

    local card = page:Card(L['Spell'])
    card:Row(rowH):Icon({
        width = 1,
        size = 28,
        texture = GetSpellTexture(trigger.SpellID),
        text = { text = GetSpellName(trigger.SpellID) or L['Unknown Spell'], description = tostring(trigger.SpellID) },
        tooltip = function(tooltip) tooltip:SetSpellByID(trigger.SpellID) end,
    })

    local found
    local useButton
    local inputRow = card:Row(rowH)
    inputRow:EditBox(L['Spell ID or Name'], {
        width = 0.5,
        tooltip = L['A spell ID, or the name of a spell you know.'],
        onTextChanged = function(text)
            found = Lookup(text)
            local label = (found and format(L['Use %s'], found.name)) or (strtrim(text) == '' and L['Use Spell']) or L['No spell found']
            useButton:SetLabel(label)
            useButton:SetEnabled(found ~= nil)
        end,
    })
    useButton = inputRow:Button(L['Use Spell'], {
        width = 0.5,
        height = 24,
        yOffset = -14,
        callback = function() if found then SetSpell(found.spellID) end end,
    }) --[[@as KajiGUIButton]]
    useButton:SetEnabled(false)

    local Category = Enum.CooldownViewerCategory
    local options = {}
    for _, category in ipairs({ Category.Essential, Category.Utility }) do
        for _, cooldownID in ipairs(CDM.Catalogue:GetList(category)) do
            local info = CDM.Catalogue:GetEntry(cooldownID)
            if info and info.isKnown and info.spellID then
                options[#options + 1] = {
                    value = cooldownID,
                    text = format('|T%d:16:16:0:0:64:64:5:59:5:59|t %s', GetSpellTexture(info.spellID) or QUESTION_MARK, GetSpellName(info.spellID) or info.spellID),
                }
            end
        end
    end

    card:Row(rowHL, 0):Dropdown(L['From Cooldown Manager'], {
        width = 1,
        tooltip = L["Spells Blizzard's Cooldown Manager tracks for your current spec."],
        options = options,
        value = trigger.CooldownID,
        callback = function(cooldownID)
            local info = CDM.Catalogue:GetEntry(cooldownID)
            if info then SetSpell(info.spellID, cooldownID) end
        end,
    })
end

---@param page table
---@param id string
local function BuildGroupTab(page, id)
    local display = CDM:Get(id)
    local apply = Applier(id)

    EnableCard(page, display, apply)
    if display.type == 'dynamicgroup' then
        page:DynamicGroupCard({ title = L['Dynamic Group Settings'], db = display.Layout, onChangeCallback = apply })
    end

    page:Card(L['Group Icon']):Row(rowHL, 0):EditBox(L['Spell or Icon ID'], {
        width = 1,
        tooltip = L['The icon this group shows in the list. Empty uses its first icon.'],
        value = display.Icon and tostring(display.Icon) or '',
        callback = function(text)
            local number = tonumber(text)
            display.Icon = number and (GetSpellTexture(number) or number) or nil
            RefreshTree()
        end,
    })

    PositionCard(page, id)
end

---@param page table
---@param id string
local function BuildDisplayTab(page, id)
    local display = CDM:Get(id)
    if display.type ~= 'icon' then
        BuildStyle(page, CDM:GetIcons(id), Applier(id))
        return
    end

    BuildStyle(page, { id }, Applier(id))
    if not CDM:IsDynamic(display.parent) then PositionCard(page, id) end
end

---A group's load settings are its icons', edited together as in WeakAuras.
---@param page table
---@param id string
local function BuildLoadTab(page, id)
    local iconIds = CDM:IsGroup(id) and CDM:GetIcons(id) or { id }
    if #iconIds == 0 then
        page:Card(L['Load']):Row(rowHL, 0):Text(L['This group has no icons yet.'], { width = 1 })
        return
    end

    local first = CDM:Get(iconIds[1])
    page:LoadConditionsCard({
        db = first.Load,
        onChangeCallback = function()
            for i = 2, #iconIds do CDM:Get(iconIds[i]).Load = CopyTable(first.Load) end
            CDM:RefreshLoad()
        end,
    })
end

-- Tree data --

---@param id string
---@return number
local function DisplayIcon(id)
    local display = CDM:Get(id)
    if display.type == 'icon' then return GetSpellTexture(display.Trigger.SpellID) or QUESTION_MARK end
    if display.Icon then return display.Icon end

    local first = CDM:GetIcons(id)[1]
    return first and DisplayIcon(first) or QUESTION_MARK
end

---@param id string
---@param index number? position among its group's children
---@param count number? children in its group
---@return table
local function RowData(id, index, count)
    local display = CDM:Get(id)
    local isGroup = display.type ~= 'icon'
    local children = isGroup and CDM:GetChildren(id) or nil

    local data = {
        key = id,
        text = display.name,
        icon = DisplayIcon(id),
        isGroup = isGroup,
        depth = CDM:GetDepth(id),
        enabled = display.Enabled,
        loadState = CDM:GetLoadState(id),
        preview = CDM:GetPreview(id),
        draggable = true,
        expanded = isGroup and not IsCollapsed(id),
        childCount = children and #children or 0,
        canMoveUp = index ~= nil and index > 1,
        canMoveDown = index ~= nil and index < count,
    }

    data.tooltip = function(tooltip)
        tooltip:SetText(display.name, 1, 1, 1)
        tooltip:AddLine(TYPE_NAMES[display.type], 0.7, 0.7, 0.7)
        if isGroup then
            if #children == 0 then tooltip:AddLine(L['No Children'], 0.7, 0.7, 0.7) end
            for _, child in ipairs(children) do tooltip:AddLine('  ' .. child.text, 0.8, 0.8, 0.8) end
        end
        tooltip:AddLine(' ')
        tooltip:AddLine(L['Right-click for more options'], 0.4, 0.8, 1)
        tooltip:AddLine(L['Drag to move'], 0.4, 0.8, 1)
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

    return { general = { key = GENERAL, text = L['General'] }, sections = { loaded, unloaded } }
end

-- Actions --

---@param parentId string?
local function NewIconPrompt(parentId)
    NRSKNUI:CreatePrompt({
        title = L['New Icon'],
        text = '',
        editBox = true,
        editBoxLabel = L['Spell ID or Name'],
        onAccept = function(text)
            local info = Lookup(text)
            if not info then
                NRSKNUI:Print(L['No spell found'])
                return
            end

            local id = CDM:CreateIcon(info.name, { Type = 'spell', SpellID = info.spellID }, parentId)
            EnsureModuleEnabled()
            CDM:ApplySettings(id)
            Reopen(id)
        end,
        acceptText = L['Create'],
        cancelText = L['Cancel'],
    })
end

---@param dynamic boolean
---@param parentId string?
local function NewGroupPrompt(dynamic, parentId)
    NRSKNUI:CreatePrompt({
        title = dynamic and L['New Dynamic Group'] or L['New Group'],
        text = '',
        editBox = true,
        editBoxLabel = L['Group Name'],
        onAccept = function(name)
            if not name or name == '' then
                NRSKNUI:Print(L['Please enter a name'])
                return
            end

            local id = CDM:CreateGroup(name, dynamic, parentId)
            EnsureModuleEnabled()
            CDM:ApplySettings(id)
            Reopen(id)
        end,
        acceptText = L['Create'],
        cancelText = L['Cancel'],
    })
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

---@param id string
---@param keepChildren boolean?
local function DeletePrompt(id, keepChildren)
    local text = keepChildren
        and format(L["Remove the group '%s'? Everything inside it stays."], CDM:GetName(id))
        or format(L["Delete '%s'? This cannot be undone."], CDM:GetName(id))

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

---@param id string
local function ContextMenu(id)
    local display = CDM:Get(id)
    local isGroup = display.type ~= 'icon'
    local entries = {}
    if isGroup then
        entries[#entries + 1] = { text = L['Add Icon'], onClick = function() NewIconPrompt(id) end }
        if display.type == 'group' then
            entries[#entries + 1] = { text = L['Add Group'], onClick = function() NewGroupPrompt(false, id) end }
            entries[#entries + 1] = { text = L['Add Dynamic Group'], onClick = function() NewGroupPrompt(true, id) end }
        end
        entries[#entries + 1] = { divider = true }
    end
    entries[#entries + 1] = { text = display.Enabled and L['Disable'] or L['Enable'], onClick = function() ToggleDisplay(id) end }
    entries[#entries + 1] = { text = L['Rename'], onClick = function() Tree():BeginRename(id) end }
    entries[#entries + 1] = { text = L['Duplicate'], onClick = function() DuplicateDisplay(id) end }
    entries[#entries + 1] = { divider = true }

    for _, root in ipairs(CDM:GetRoots()) do
        if root.key ~= display.parent and CDM:CanContain(root.key, id) then
            entries[#entries + 1] = {
                text = format(L['Move to %s'], root.text),
                onClick = function()
                    CDM:SetParent(id, root.key)
                    CDM:ApplySettings()
                    RefreshTree()
                end,
            }
        end
    end

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

-- New display page: shown when nothing is selected, WeakAuras' New Aura view --

local NEW_TYPES = {
    {
        text = L['Group'],
        description = L['Controls the positioning and configuration of multiple displays at the same time'],
        icon = 'Interface\Icons\INV_Misc_Bag_10',
        create = function() NewGroupPrompt(false) end,
    },
    {
        text = L['Dynamic Group'],
        description = L['A group that dynamically controls the positioning of its children'],
        icon = 'Interface\Icons\Ability_Rogue_Sprint',
        create = function() NewGroupPrompt(true) end,
    },
    {
        text = L['Icon'],
        description = L['Shows a spell icon with an optional cooldown overlay'],
        icon = 'Interface\Icons\Spell_Nature_Lightning',
        create = function() NewIconPrompt() end,
    },
}

---@param page table
local function BuildNewPage(page)
    page:Card(L['Cooldown Manager']):Row(rowHL, 0):Checkbox(L['Enable Cooldown Manager'], {
        width = 1,
        master = true,
        value = CDM.db.Enabled,
        callback = function(checked)
            CDM.db.Enabled = checked
            NRSKNUI:ToggleModule('CDM', checked)
            page:Refresh()
        end,
    })

    local card = page:Card(L['New'])
    for i, entry in ipairs(NEW_TYPES) do
        card:Row(NEW_ROW_HEIGHT, i == #NEW_TYPES and 0 or nil):Icon({
            width = 1,
            size = 32,
            texture = entry.icon,
            text = { text = entry.text, description = entry.description, color = Theme.accent },
            tooltip = function(tooltip) tooltip:SetText(entry.text, 1, 1, 1) tooltip:AddLine(entry.description, nil, nil, nil, true) end,
            onClick = function(button) if button == 'LeftButton' then entry.create() end end,
        })
    end
end

GUI:RegisterPage(PAGE, {
    mode = 'tabs',
    search = { L['Cooldown Manager'], L['Countdown Text'], L['Charge Text'] },
    onEnter = function()
        CDM.onStateChanged = RefreshTree
    end,
    onLeave = function()
        CDM.onStateChanged = nil
        CDM:SetSelectionPreview(nil)
    end,
    sidebar = {
        width = 260,
        create = NRSKNUI.CreateCDMTree,
        items = TreeContent,
        onSelectionChanged = function(key)
            CDM:SetSelectionPreview(CDM:Get(key) and key or nil)
        end,
        onToggleExpanded = function(key, expanded)
            NRSKNUI.db.global.SidebarCollapsed[PAGE][key] = (not expanded) or nil
        end,
        onRename = function(key, text)
            CDM:Rename(key, text)
            RefreshTree()
        end,
        -- Into a group that can hold it, or next to a display inside one; the top level stays alphabetical.
        canDrop = function(item, target, position)
            if position == 'into' then return target.isGroup and CDM:CanContain(target.key, item.key) end
            local parent = CDM:Get(target.key).parent
            return parent ~= nil and CDM:CanContain(parent, item.key)
        end,
        onMove = function(key, targetKey, position)
            if position == 'into' then
                CDM:SetParent(key, targetKey, true)
            else
                CDM:MoveNextTo(key, targetKey, position)
            end
            CDM:ApplySettings()
            RefreshTree()
        end,
        onMoveInGroup = function(key, delta)
            CDM:MoveInGroup(key, delta)
            CDM:ApplySettings(CDM:Get(key).parent)
            RefreshTree()
        end,
        onUngroup = function(key)
            CDM:Ungroup(key)
            CDM:ApplySettings()
            RefreshTree()
        end,
        onToggleEnabled = ToggleDisplay,
        onTogglePreview = function(key)
            CDM:SetPreview(key, CDM:GetPreview(key) == 2 and 0 or 2)
        end,
        onSectionPreview = function(sectionKey)
            for _, section in ipairs(TreeContent().sections) do
                if section.key == sectionKey then
                    local ids = SectionIcons(section)
                    local level = PreviewLevel(ids) ~= 2 and 2 or nil
                    for _, id in ipairs(ids) do CDM.preview[id] = level end
                    CDM:RefreshLoad()
                end
            end
        end,
        onContextMenu = function(key)
            if CDM:Get(key) then ContextMenu(key) end
        end,
    },
    tabs = function(itemKey)
        local display = CDM:Get(itemKey)
        if not display then return {} end -- the new display page has no tabs

        local tabs = {}
        for _, tab in ipairs(TABS) do
            if tab.id ~= 'group' or display.type ~= 'icon' then tabs[#tabs + 1] = tab end
        end
        return tabs
    end,
    build = function(page, tabId, itemKey)
        local display = CDM:Get(itemKey)

        if not display then
            BuildNewPage(page)
            return
        end

        page:SetEnabled(function() return CDM.db.Enabled end)

        if tabId == 'group' then
            BuildGroupTab(page, itemKey)
        elseif tabId == 'display' then
            BuildDisplayTab(page, itemKey)
        elseif tabId == 'trigger' and display.type == 'icon' then
            BuildTriggerTab(page, itemKey)
        elseif tabId == 'load' then
            BuildLoadTab(page, itemKey)
        end
    end,
})

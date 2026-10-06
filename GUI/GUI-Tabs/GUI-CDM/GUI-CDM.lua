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
local tostring = tostring
local format = string.format
local wipe = wipe
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

---@param id string
---@return fun()
local function Applier(id)
    return function() CDM:ApplySettings(id) end
end

---@param key string
---@return boolean
local function IsCollapsed(key)
    return NRSKNUI.db.global.SidebarCollapsed[PAGE][key] == true
end

-- Style --

-- Overrides copy a whole nested table on first write, so later edits never touch the layer below.
---@param own table
---@param resolved table
---@param path string[]
---@param value any
local function SetPath(own, resolved, path, value)
    local key = path[1]
    if #path == 1 then
        own[key] = value
        return
    end

    own[key] = own[key] or CopyTable(resolved[key])
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
---@param own table the layer being edited
---@param resolved table what that layer currently resolves to
---@param apply fun()
---@param fontKey string 'CountdownFont'|'ChargeFont'
---@param showToggle string? style key of a checkbox leading the section
local function TextRows(card, own, resolved, apply, fontKey, showToggle)
    local font = resolved[fontKey]

    local function Set(path, value)
        SetPath(own, resolved, path, value)
        apply()
    end

    if showToggle then
        card:Row(rowH):Checkbox(L['Show'], {
            width = 1,
            value = resolved[showToggle],
            callback = function(checked)
                own[showToggle] = checked
                apply()
            end,
        })
    end

    local sizeRow = card:Row(rowH)
    sizeRow:Slider(L['Font Size'], {
        width = 0.5,
        min = 6,
        max = 40,
        step = 1,
        value = font.FontSize,
        callback = function(value) Set({ fontKey, 'FontSize' }, value) end,
    })
    sizeRow:AnchorPicker(L['Anchor'], {
        width = 0.5,
        value = font.Position.AnchorFrom,
        callback = function(point) Set({ fontKey, 'Position', 'AnchorFrom' }, point) end,
    })

    local offsetRow = card:Row(rowH)
    offsetRow:Slider(L['X Offset'], {
        width = 0.5,
        min = -30,
        max = 30,
        step = 1,
        value = font.Position.XOffset,
        callback = function(value) Set({ fontKey, 'Position', 'XOffset' }, value) end,
    })
    offsetRow:Slider(L['Y Offset'], {
        width = 0.5,
        min = -30,
        max = 30,
        step = 1,
        value = font.Position.YOffset,
        callback = function(value) Set({ fontKey, 'Position', 'YOffset' }, value) end,
    })
end

---@param page table
---@param own table the layer being edited
---@param resolved table what that layer currently resolves to
---@param apply fun()
---@param inheritsFrom string? name of the layer below, nil when editing the base style
---@param reopenKey string
local function BuildStyle(page, own, resolved, apply, inheritsFrom, reopenKey)
    if inheritsFrom then
        local overrideCard = page:Card(L['Overrides'])
        overrideCard:Row(rowH):Text(format(L['Settings changed here override %s. Untouched settings keep following it.'], inheritsFrom), { width = 1 })
        overrideCard:Row(rowHL, 0):Button(L['Reset Overrides'], {
            width = 1,
            callback = function()
                wipe(own)
                apply()
                Reopen(reopenKey)
            end,
        })
    end

    local function Set(key, value)
        own[key] = value
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
                value = resolved.Size,
                callback = function(value) Set('Size', value) end,
            })
            iconRow:ColorPicker(L['Border Color'], {
                width = 0.5,
                value = resolved.BorderColor,
                callback = function(r, g, b, a) Set('BorderColor', { r, g, b, a }) end,
            })
        end

        if Section(card, 'cooldown', L['Cooldown Settings']) then
            local swipeRow = card:Row(rowH)
            swipeRow:Checkbox(L['Draw Swipe'], {
                width = 0.5,
                value = resolved.DrawSwipe,
                callback = function(checked) Set('DrawSwipe', checked) end,
            })
            swipeRow:Checkbox(L['Reverse Swipe'], {
                width = 0.5,
                value = resolved.Reverse,
                callback = function(checked) Set('Reverse', checked) end,
            })
            local edgeRow = card:Row(rowH)
            edgeRow:Checkbox(L['Draw Edge'], {
                width = 0.5,
                value = resolved.DrawEdge,
                callback = function(checked) Set('DrawEdge', checked) end,
            })
            edgeRow:Checkbox(L['Show Global Cooldown'], {
                width = 0.5,
                tooltip = L['Run the swipe for the global cooldown too.'],
                value = resolved.ShowGCD,
                callback = function(checked) Set('ShowGCD', checked) end,
            })
            local colorRow = card:Row(rowH)
            colorRow:ColorPicker(L['Swipe Color'], {
                width = 0.5,
                value = resolved.SwipeColor,
                callback = function(r, g, b, a) Set('SwipeColor', { r, g, b, a }) end,
            })
            colorRow:Checkbox(L['Desaturate on Cooldown'], {
                width = 0.5,
                value = resolved.DesaturateOnCooldown,
                callback = function(checked) Set('DesaturateOnCooldown', checked) end,
            })
        end

        if Section(card, 'countdown', L['Countdown Text']) then
            TextRows(card, own, resolved, apply, 'CountdownFont', 'ShowCountdown')
        end

        if Section(card, 'charges', L['Charge Text']) then
            TextRows(card, own, resolved, apply, 'ChargeFont')
        end
    end)
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
    page:DynamicGroupCard({ title = L['Dynamic Group Settings'], db = display.Layout, onChangeCallback = apply })

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

    page:PositionCard({
        title = L['Position and Size Settings'],
        db = display,
        showAnchorFrameType = true,
        showStrata = true,
        disableAnchorFrom = true, -- a group anchors from its grow direction
        onChangeCallback = apply,
    })
end

---@param page table
---@param id string
local function BuildDisplayTab(page, id)
    local display = CDM:Get(id)
    local inheritsFrom = display.parent and CDM:GetName(display.parent) or L['the General style']
    BuildStyle(page, display.Style, CDM:ResolveStyle(display), Applier(id), inheritsFrom, id)

    if display.type == 'icon' and not display.parent then
        page:PositionCard({
            title = L['Position and Size Settings'],
            db = display,
            showAnchorFrameType = true,
            showStrata = true,
            onChangeCallback = Applier(id),
        })
    end
end

---@param page table
---@param id string
local function BuildLoadTab(page, id)
    page:LoadConditionsCard({
        db = CDM:Get(id).Load,
        onChangeCallback = function() CDM:RefreshLoad() end,
    })
end

---@param page table
local function BuildGeneralTab(page)
    local card = page:Card(L['Cooldown Manager'])
    card:Row(rowH):Checkbox(L['Enable Cooldown Manager'], {
        width = 1,
        master = true,
        value = CDM.db.Enabled,
        callback = function(checked)
            CDM.db.Enabled = checked
            NRSKNUI:ToggleModule('CDM', checked)
            page:Refresh()
        end,
    })
    card:Row(rowHL, 0):Text(L['Groups and icons are listed on the left. Right-click them for more options.'], { width = 1 })
end

-- Tree data --

---@param id string
---@return number
local function DisplayIcon(id)
    local display = CDM:Get(id)
    if display.type ~= 'group' then return GetSpellTexture(display.Trigger.SpellID) or QUESTION_MARK end
    if display.Icon then return display.Icon end

    local first = CDM:GetChildren(id)[1]
    return first and DisplayIcon(first.key) or QUESTION_MARK
end

---@param id string
---@param index number? position among its group's icons
---@param count number? icons in its group
---@return table
local function RowData(id, index, count)
    local display = CDM:Get(id)
    local isGroup = display.type == 'group'
    local children = isGroup and CDM:GetChildren(id) or nil

    local data = {
        key = id,
        text = display.name,
        icon = DisplayIcon(id),
        isGroup = isGroup,
        depth = display.parent and 1 or 0,
        enabled = display.Enabled,
        loadState = CDM:GetLoadState(id),
        preview = CDM:GetPreview(id),
        draggable = not isGroup,
        expanded = isGroup and not IsCollapsed(id),
        childCount = children and #children or 0,
        canMoveUp = index ~= nil and index > 1,
        canMoveDown = index ~= nil and index < count,
    }

    data.tooltip = function(tooltip)
        tooltip:SetText(display.name, 1, 1, 1)
        if isGroup then
            if #children == 0 then tooltip:AddLine(L['No Children'], 0.7, 0.7, 0.7) end
            for _, child in ipairs(children) do tooltip:AddLine('  ' .. child.text, 0.8, 0.8, 0.8) end
        end
        tooltip:AddLine(' ')
        tooltip:AddLine(L['Right-click for more options'], 0.4, 0.8, 1)
        if not isGroup then tooltip:AddLine(L['Drag to move'], 0.4, 0.8, 1) end
    end

    if isGroup then
        data.children = {}
        for i, child in ipairs(children) do data.children[i] = RowData(child.key, i, #children) end
    end
    return data
end

---@param section table
---@return number level
local function SectionPreview(section)
    local pinned, hidden, total = 0, 0, 0
    for _, row in ipairs(section.rows) do
        for _, leaf in ipairs(row.isGroup and row.children or { row }) do
            total = total + 1
            if leaf.preview == 2 then pinned = pinned + 1 elseif leaf.preview == 0 then hidden = hidden + 1 end
        end
    end
    if total == 0 or hidden == total then return 0 end
    return pinned == total and 2 or 1
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

    local groups, loose = {}, {}
    for _, root in ipairs(CDM:GetRoots()) do
        local list = root.isGroup and groups or loose
        list[#list + 1] = root.key
    end

    for _, list in ipairs({ groups, loose }) do
        for _, id in ipairs(list) do
            local section = CDM:GetLoadState(id) == 'unloaded' and unloaded or loaded
            section.rows[#section.rows + 1] = RowData(id)
        end
    end

    for _, section in ipairs({ loaded, unloaded }) do
        section.collapsed = IsCollapsed(section.key)
        section.preview = SectionPreview(section)
    end

    return { general = { key = GENERAL, text = L['General'] }, sections = { loaded, unloaded } }
end

-- Actions --

---@param groupId string?
local function NewIconPrompt(groupId)
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

            local id = CDM:CreateIcon(info.name, { Type = 'spell', SpellID = info.spellID }, groupId)
            EnsureModuleEnabled()
            CDM:ApplySettings(id)
            Reopen(id)
        end,
        acceptText = L['Create'],
        cancelText = L['Cancel'],
    })
end

local function NewGroupPrompt()
    NRSKNUI:CreatePrompt({
        title = L['New Group'],
        text = '',
        editBox = true,
        editBoxLabel = L['Group Name'],
        onAccept = function(name)
            if not name or name == '' then
                NRSKNUI:Print(L['Please enter a name'])
                return
            end

            local id = CDM:CreateGroup(name)
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

    CDM:ApplySettings(newId)
    Reopen(newId)
end

---@param id string
---@param keepChildren boolean?
local function DeletePrompt(id, keepChildren)
    local text = keepChildren
        and format(L["Remove the group '%s'? Its icons stay, outside any group."], CDM:GetName(id))
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

---@param groupId string
local function GroupMenu(groupId)
    local display = CDM:Get(groupId)
    GUI:ShowContextMenu({
        { text = L['Add Icon'],                                    onClick = function() NewIconPrompt(groupId) end },
        { text = display.Enabled and L['Disable'] or L['Enable'], onClick = function() ToggleDisplay(groupId) end },
        { text = L['Rename'],                                      onClick = function() Tree():BeginRename(groupId) end },
        { text = L['Duplicate'],                                   onClick = function() DuplicateDisplay(groupId) end },
        { divider = true },
        { text = L['Ungroup'],                                     onClick = function() DeletePrompt(groupId, true) end },
        { text = L['Delete Group and Icons'],                      onClick = function() DeletePrompt(groupId) end },
    })
end

---@param id string
local function IconMenu(id)
    local display = CDM:Get(id)
    local entries = {
        { text = display.Enabled and L['Disable'] or L['Enable'], onClick = function() ToggleDisplay(id) end },
        { text = L['Rename'],                                      onClick = function() Tree():BeginRename(id) end },
        { text = L['Duplicate'],                                   onClick = function() DuplicateDisplay(id) end },
        { text = L['Delete'],                                      onClick = function() DeletePrompt(id) end },
        { divider = true },
    }

    for _, root in ipairs(CDM:GetRoots()) do
        if root.isGroup and root.key ~= display.parent then
            entries[#entries + 1] = {
                text = format(L['Move to %s'], root.text),
                onClick = function()
                    CDM:SetParent(id, root.key)
                    CDM:ApplySettings(id)
                    RefreshTree()
                end,
            }
        end
    end

    if display.parent then
        entries[#entries + 1] = {
            text = L['Remove from Group'],
            onClick = function()
                CDM:SetParent(id, nil)
                CDM:ApplySettings(id)
                Reopen(id)
            end,
        }
    end

    GUI:ShowContextMenu(entries)
end

---@param ids string[]
local function TogglePreviews(ids)
    local allPinned = #ids > 0
    for _, id in ipairs(ids) do
        if (CDM.preview[id] or 0) ~= 2 then allPinned = false end
    end
    for _, id in ipairs(ids) do CDM.preview[id] = (not allPinned) and 2 or nil end
    CDM:RefreshLoad()
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
        onNew = function()
            GUI:ShowContextMenu({
                { text = L['New Group'], onClick = NewGroupPrompt },
                { text = L['New Icon'],  onClick = function() NewIconPrompt() end },
            })
        end,
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
        -- An icon goes into a group, or next to an icon inside one; top-level rows stay alphabetical.
        canDrop = function(item, target, position)
            if not item.draggable then return false end
            if position == 'into' then return target.isGroup end
            return target.depth > 0
        end,
        onMove = function(key, targetKey, position)
            if position == 'into' then
                CDM:SetParent(key, targetKey, true)
            else
                CDM:MoveNextTo(key, targetKey, position)
            end
            CDM:ApplySettings(key)
            local display = CDM:Get(key)
            if display.parent then CDM:ApplySettings(display.parent) end
            RefreshTree()
        end,
        onMoveInGroup = function(key, delta)
            CDM:MoveInGroup(key, delta)
            CDM:ApplySettings(CDM:Get(key).parent)
            RefreshTree()
        end,
        onUngroup = function(key)
            CDM:SetParent(key, nil)
            CDM:ApplySettings(key)
            RefreshTree()
        end,
        onToggleEnabled = ToggleDisplay,
        onTogglePreview = function(key)
            CDM:SetPreview(key, CDM:GetPreview(key) == 2 and 0 or 2)
        end,
        onSectionPreview = function(sectionKey)
            local ids = {}
            for _, section in ipairs(TreeContent().sections) do
                if section.key == sectionKey then
                    for _, row in ipairs(section.rows) do
                        for _, leaf in ipairs(row.isGroup and row.children or { row }) do ids[#ids + 1] = leaf.key end
                    end
                end
            end
            TogglePreviews(ids)
        end,
        onContextMenu = function(key)
            if not CDM:Get(key) then return end
            if CDM:IsGroup(key) then return GroupMenu(key) end
            IconMenu(key)
        end,
    },
    tabs = function(itemKey)
        local display = CDM:Get(itemKey)
        if not display then
            return { { id = 'general', text = L['General'] }, { id = 'display', text = L['Display'] } }
        end

        local tabs = {}
        for _, tab in ipairs(TABS) do
            if tab.id ~= 'group' or display.type == 'group' then tabs[#tabs + 1] = tab end
        end
        return tabs
    end,
    build = function(page, tabId, itemKey)
        local display = CDM:Get(itemKey)

        if not display then
            if tabId == 'general' then
                BuildGeneralTab(page)
            elseif tabId == 'display' then
                local apply = function() CDM:ApplySettings() end
                BuildStyle(page, CDM.db.Style, CDM.db.Style, apply, nil, GENERAL)
                page:FontSettingsCard({ db = CDM.db.Style, hideFontSize = true, onChangeCallback = apply })
            end
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

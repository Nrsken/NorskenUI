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
local SECTION_PREFIX = 'section:'

local RefreshSidebar -- defined with the sidebar below

---@param text string?
---@return SpellInfo? info
local function Lookup(text)
    text = strtrim(text or '')
    if text == '' then return nil end
    -- Names only resolve for spells in the player's own spellbook, IDs always do.
    local info = GetSpellInfo(tonumber(text) or text)
    return info and info.spellID and info or nil
end

local function Reopen(selectKey)
    local window = NRSKNUI.GUIFrame
    if not (window and window.content) then return end

    window.content:ShowPage(PAGE, selectKey and { itemKey = selectKey } or nil)
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

---@param page table
---@param own table the layer being edited
---@param resolved table what that layer currently resolves to
---@param apply fun()
---@param fontKey string 'CountdownFont'|'ChargeFont'
---@param title string
---@param showToggle string? style key of a checkbox leading the card
local function TextCard(page, own, resolved, apply, fontKey, title, showToggle)
    local font = resolved[fontKey]
    local card = page:Card(title)

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

    local function Set(path, value)
        SetPath(own, resolved, path, value)
        apply()
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

    local offsetRow = card:Row(rowHL, 0)
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
local function BuildStyleTab(page, own, resolved, apply, inheritsFrom, reopenKey)
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

    local iconCard = page:Card(L['Icon'])
    local iconRow = iconCard:Row(rowHL, 0)
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

    local cooldownCard = page:Card(L['Cooldown'])
    local swipeRow = cooldownCard:Row(rowH)
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
    local edgeRow = cooldownCard:Row(rowH)
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
    local colorRow = cooldownCard:Row(rowHL, 0)
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

    TextCard(page, own, resolved, apply, 'CountdownFont', L['Countdown Text'], 'ShowCountdown')
    TextCard(page, own, resolved, apply, 'ChargeFont', L['Charge Text'])
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
            RefreshSidebar()
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
                    text = format('|T%d:16:16:0:0:64:64:5:59:5:59|t %s', GetSpellTexture(info.spellID) or 134400, GetSpellName(info.spellID) or info.spellID),
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
local function BuildLayoutTab(page, id)
    local display = CDM:Get(id)
    local apply = Applier(id)

    EnableCard(page, display, apply)
    page:DynamicGroupCard({ db = display.Layout, onChangeCallback = apply })
end

---@param page table
---@param id string
local function BuildPositionTab(page, id)
    local display = CDM:Get(id)
    page:PositionCard({
        db = display,
        showAnchorFrameType = true,
        showStrata = true,
        disableAnchorFrom = display.type == 'group', -- a group anchors from its grow direction
        onChangeCallback = Applier(id),
    })
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

-- Sidebar --

---@return table? miniSidebar
local function MiniSidebar()
    local content = NRSKNUI.GUIFrame and NRSKNUI.GUIFrame.content
    return content and content.miniSidebar
end

---@param key string
---@return boolean
local function IsOpen(key)
    return not NRSKNUI.db.global.SidebarCollapsed[PAGE][key]
end

---@param id string
---@return table
local function IconItem(id)
    local display = CDM:Get(id)
    return {
        key = id,
        text = display.name,
        icon = GetSpellTexture(display.Trigger.SpellID),
        disabled = not display.Enabled,
        draggable = true,
        renamable = true,
        grouped = display.parent ~= nil,
    }
end

---Groups by name, each opening on its own settings, then the icons outside any group.
---@return table[]
local function SidebarItems()
    local items, loose = {}, {}

    for _, root in ipairs(CDM:GetRoots()) do
        if root.isGroup then
            local children = { { key = root.key, text = L['Group Settings'], disabled = not CDM:Get(root.key).Enabled } }
            for _, child in ipairs(CDM:GetChildren(root.key)) do
                children[#children + 1] = IconItem(child.key)
            end

            local sectionKey = SECTION_PREFIX .. root.key
            items[#items + 1] = {
                type = 'header',
                key = sectionKey,
                text = root.text,
                groupId = root.key,
                defaultExpanded = IsOpen(sectionKey),
                items = children,
            }
        else
            loose[#loose + 1] = IconItem(root.key)
        end
    end

    if #loose > 0 then
        items[#items + 1] = { type = 'label', key = 'cdm:loose', text = L['Ungrouped'] }
        for _, item in ipairs(loose) do items[#items + 1] = item end
    end

    return items
end

function RefreshSidebar()
    local sidebar = MiniSidebar()
    if sidebar then sidebar:SetItems(SidebarItems()) end
end

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
    Reopen(id)
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
---@param sectionKey string
local function GroupMenu(groupId, sectionKey)
    local display = CDM:Get(groupId)
    GUI:ShowContextMenu({
        { text = L['Add Icon'],                                    onClick = function() NewIconPrompt(groupId) end },
        { text = display.Enabled and L['Disable'] or L['Enable'], onClick = function() ToggleDisplay(groupId) end },
        { text = L['Rename'],                                      onClick = function() MiniSidebar():BeginRename(sectionKey) end },
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
        { text = L['Rename'],                                      onClick = function() MiniSidebar():BeginRename(id) end },
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
                    RefreshSidebar()
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

GUI:RegisterPage(PAGE, {
    mode = 'tabs',
    search = { L['Cooldown Manager'], L['Countdown Text'], L['Charge Text'] },
    sidebar = {
        buttons = {
            { text = L['General'],   key = GENERAL },
            { text = L['New Group'], onClick = NewGroupPrompt },
            { text = L['New Icon'],  onClick = function() NewIconPrompt() end },
        },
        items = SidebarItems,
        onToggle = function(key, expanded)
            NRSKNUI.db.global.SidebarCollapsed[PAGE][key] = (not expanded) or nil
        end,
        onRename = function(key, text, item)
            CDM:Rename(item.groupId or key, text)
            RefreshSidebar()
        end,
        -- Icons go into a group, or next to another icon; groups themselves stay sorted by name.
        canDrop = function(_, target, position)
            if position == 'into' then return target.groupId ~= nil end
            return target.draggable == true
        end,
        onMove = function(key, targetKey, position)
            if position == 'into' then
                CDM:SetParent(key, targetKey:sub(#SECTION_PREFIX + 1))
            else
                CDM:MoveNextTo(key, targetKey, position)
            end
            CDM:ApplySettings(key)
            local display = CDM:Get(key)
            if display.parent then CDM:ApplySettings(display.parent) end
            RefreshSidebar()
        end,
        onContextMenu = function(key, item)
            if item and item.groupId then return GroupMenu(item.groupId, key) end
            if not CDM:Get(key) then return end
            if CDM:IsGroup(key) then return GroupMenu(key, SECTION_PREFIX .. key) end
            IconMenu(key)
        end,
    },
    tabs = function(itemKey)
        if itemKey == GENERAL or not CDM:Get(itemKey) then
            return { { id = 'general', text = L['General'] }, { id = 'style', text = L['Style'] } }
        end

        if CDM:IsGroup(itemKey) then
            return {
                { id = 'layout',   text = L['Layout'] },
                { id = 'style',    text = L['Style'] },
                { id = 'load',     text = L['Load'] },
                { id = 'position', text = L['Position Settings'] },
            }
        end

        local tabs = {
            { id = 'trigger', text = L['Trigger'] },
            { id = 'style',   text = L['Style'] },
            { id = 'load',    text = L['Load'] },
        }
        if not CDM:Get(itemKey).parent then tabs[#tabs + 1] = { id = 'position', text = L['Position Settings'] } end
        return tabs
    end,
    build = function(page, tabId, itemKey)
        local display = CDM:Get(itemKey)

        if not display then
            if tabId == 'general' then
                BuildGeneralTab(page)
            elseif tabId == 'style' then
                local apply = function() CDM:ApplySettings() end
                BuildStyleTab(page, CDM.db.Style, CDM.db.Style, apply, nil, GENERAL)
                page:FontSettingsCard({ db = CDM.db.Style, hideFontSize = true, onChangeCallback = apply })
            end
            return
        end

        page:SetEnabled(function() return CDM.db.Enabled end)

        if tabId == 'trigger' then
            BuildTriggerTab(page, itemKey)
        elseif tabId == 'layout' then
            BuildLayoutTab(page, itemKey)
        elseif tabId == 'style' then
            local inheritsFrom = display.parent and CDM:GetName(display.parent) or L['the General style']
            BuildStyleTab(page, display.Style, CDM:ResolveStyle(display), Applier(itemKey), inheritsFrom, itemKey)
        elseif tabId == 'load' then
            BuildLoadTab(page, itemKey)
        elseif tabId == 'position' then
            BuildPositionTab(page, itemKey)
        end
    end,
})

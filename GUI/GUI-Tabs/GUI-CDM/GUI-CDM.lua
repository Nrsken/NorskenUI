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
local tonumber = tonumber
local CopyTable = CopyTable
local tinsert, tremove = table.insert, table.remove
local floor = math.floor

local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture
local GetSpellName = C_Spell and C_Spell.GetSpellName
local GetItemIconByID = C_Item and C_Item.GetItemIconByID
local GetItemNameByID = C_Item and C_Item.GetItemNameByID

local PAGE = 'cooldownManager'
local GENERAL = 'cdm:general'
local TRINKETS = 'cdm:trinkets'
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

-- Tabs --

---@param page table
---@param id string
local function PositionCard(page, id)
    local display = CDM:Get(id)
    page:PositionCard({
        title = L['Position and Size Settings'],
        db = display,
        showAnchorFrameType = display.parent == nil,        -- inside a group it anchors to the group
        showStrata = display.parent == nil,
        disableAnchorFrom = display.type == 'dynamicgroup', -- a dynamic group anchors from its grow direction
        onChangeCallback = Applier(id),
    })
end

--[[
-- Info dump on what can be used for triggers.

- Info we can get from CDM:
    - CDM Spell Cooldowns, including racial abilities
    - CDM Aura, including racial abilities, both buffs on the player and debuffs on enemies e.g. flame shock or rupture.
    - CDM Item Cooldowns, including: trinket 1 and 2, Healthstone, combat potion and health potion
    - CDM Item Aura, including: trinket 1 and 2 (these can have 2 buffs each e.g one active buff and one passive buff coming from the same trinket) and combat potion

- Info we can grab ourselves via API's:
    - Basically any item info about any item.
    - We can create timer based uptime trackers based on cast success by the player, for example on holy paladin, aura mastery has no buff uptime, but we can create a 8s long timer to track its uptime.
    - Totem information, needs some digging on how it is achieved the best, but should be possible.
]]


local TRIGGER_TYPES = {
    { value = 'spell', text = L['Cooldown'] },
    { value = 'aura',  text = L['Aura'] },
    { value = 'item',  text = L['Item'] },
    { value = 'timer', text = L['Cast Timer'] },
    { value = 'totem', text = L['Totem'] },
}
local TRIGGER_NAMES = {}
for _, entry in ipairs(TRIGGER_TYPES) do TRIGGER_NAMES[entry.value] = entry.text end

-- What a trigger starts with when it's added or its type changes.
local TRIGGER_DEFAULTS = {
    spell = {},
    aura  = { Source = 'cdm', Unit = 'player', OwnOnly = true, Pandemic = false, UseSpellIcon = false },
    item  = { Item = 'trinket1', HidePassive = true },
    timer = { Duration = 8 },
    totem = {},
}
local AURA_SOURCES = {
    { value = 'cdm',    text = L['Cooldown Manager'] },
    { value = 'custom', text = L['Custom'] },
}
local AURA_UNITS = {
    { value = 'player', text = L['Player'] },
    { value = 'target', text = L['Target'] },
}
local ITEMS = {
    { value = 'trinket1',     text = L['Trinket 1'] },
    { value = 'trinket2',     text = L['Trinket 2'] },
    { value = 'healthstone',  text = L['Healthstone'] },
    { value = 'combatPotion', text = L['Combat Potion'] },
    { value = 'custom',       text = L['Custom Item'] },
}
local triggerOpen = {} -- [index] = open, for the session; a lone trigger starts open
local trinketReturnKey ---@type string?

---A new aura trigger for the Cooldown Manager aura that shares a spell with one of the icon's cooldowns.
---@param display table
---@return table? trigger
local function LinkedAuraTrigger(display)
    for _, trigger in ipairs(display.Triggers) do
        local cooldownID = trigger.Type == 'spell' and trigger.SpellID and CDM.Catalogue:FindBySpell(trigger.SpellID, 'aura')
        local info = cooldownID and CDM.Catalogue:GetEntry(cooldownID)
        if info then
            local new = CopyTable(TRIGGER_DEFAULTS.aura)
            new.Type, new.CooldownID, new.SpellID = 'aura', cooldownID, info.spellID
            return new
        end
    end
end

---Every spell the Cooldown Manager has for these categories: known ones first, the rest dimmed after them.
---@param categories number[] Enum.CooldownViewerCategory values
---@return table[] options
local function CatalogueOptions(categories)
    local known, unknown = {}, {}
    local muted = Theme.textMuted
    local tint = format('%d:%d:%d', floor(muted[1] * 255 + 0.5), floor(muted[2] * 255 + 0.5), floor(muted[3] * 255 + 0.5))
    for _, category in ipairs(categories) do
        for _, cooldownID in ipairs(CDM.Catalogue:GetList(category)) do
            local info = CDM.Catalogue:GetEntry(cooldownID)
            if info and info.spellID then
                local texture = GetSpellTexture(info.spellID) or QUESTION_MARK
                local name = GetSpellName(info.spellID) or info.spellID
                if info.isKnown then
                    known[#known + 1] = { value = cooldownID, text = format('|T%d:16:16:0:0:64:64:5:59:5:59|t %s', texture, name) }
                else
                    unknown[#unknown + 1] = {
                        value = cooldownID,
                        text = format('|T%d:16:16:0:0:64:64:5:59:5:59:%s|t %s', texture, tint, name),
                        color = muted,
                    }
                end
            end
        end
    end
    for _, option in ipairs(unknown) do known[#known + 1] = option end
    return known
end

---@param trigger table
---@param display table
---@param id string
---@param apply fun()
---@return fun(cooldownID: number)
local function CataloguePicker(trigger, display, id, apply)
    return function(cooldownID)
        local info = CDM.Catalogue:GetEntry(cooldownID)
        if not info or cooldownID == trigger.CooldownID then return end
        -- A new icon, or one still named after its spell, takes the new spell's name.
        if display.name == L['New Icon'] or (trigger.SpellID and display.name == GetSpellName(trigger.SpellID)) then
            display.name = GetSpellName(info.spellID) or display.name
        end
        trigger.SpellID = info.spellID
        trigger.CooldownID = cooldownID
        apply()
        Reopen(id)
    end
end

-- Rows per trigger type: the first row opens with the Type dropdown, the rest follow.
local TriggerRows = {}

function TriggerRows.spell(card, typeRow, display, trigger, id, apply)
    local Category = Enum.CooldownViewerCategory
    typeRow:Dropdown(L['Cooldown Manager'], {
        width = 0.5,
        tooltip = L["Spells Blizzard's Cooldown Manager tracks for your current spec."],
        options = CatalogueOptions({ Category.Essential, Category.Utility }),
        value = trigger.CooldownID,
        callback = CataloguePicker(trigger, display, id, apply),
    })
end

function TriggerRows.aura(card, typeRow, display, trigger, id, apply)
    local Category = Enum.CooldownViewerCategory
    local function set(key, value)
        trigger[key] = value
        apply()
    end

    typeRow:Dropdown(L['Source'], {
        width = 0.5,
        options = AURA_SOURCES,
        value = trigger.Source,
        callback = function(value)
            set('Source', value)
            card:Rebuild()
        end,
    })

    local auraRow = card:Row(rowH)
    if trigger.Source == 'custom' then
        auraRow:EditBox(L['Spell IDs'], {
            width = 0.5,
            tooltip = L['Aura spell IDs, separated by commas.'],
            value = trigger.SpellIDs and table.concat(trigger.SpellIDs, ', ') or '',
            callback = function(text)
                local ids = {}
                for number in text:gmatch('%d+') do ids[#ids + 1] = tonumber(number) end
                set('SpellIDs', ids)
            end,
        })
    else
        auraRow:Dropdown(L['Aura'], {
            width = 0.5,
            tooltip = L["Auras Blizzard's Cooldown Manager tracks for your current spec."],
            options = CatalogueOptions({ Category.TrackedBuff, Category.TrackedBar }),
            value = trigger.CooldownID,
            callback = CataloguePicker(trigger, display, id, apply),
        })
    end
    auraRow:Dropdown(L['Unit'], {
        width = 0.5,
        options = AURA_UNITS,
        value = trigger.Unit,
        callback = function(value) set('Unit', value) end,
    })

    local optionsRow = card:Row(rowH)
    optionsRow:Checkbox(L['Cast by Me'], {
        width = 0.5,
        value = trigger.OwnOnly,
        callback = function(checked) set('OwnOnly', checked) end,
    })
    optionsRow:Checkbox(L['Pandemic Highlight'], {
        width = 0.5,
        tooltip = L['Highlights the aura while refreshing it would carry over its remaining time.'],
        value = trigger.Pandemic,
        callback = function(checked) set('Pandemic', checked) end,
    })
    card:Row(rowH):Checkbox(L['Use Spell Icon'], {
        width = 0.5,
        tooltip = L["Shows the spell's icon instead of the aura's own."],
        value = trigger.UseSpellIcon,
        callback = function(checked) set('UseSpellIcon', checked) end,
    })
end

function TriggerRows.item(card, typeRow, display, trigger, id, apply)
    typeRow:Dropdown(L['Item'], {
        width = 0.5,
        options = ITEMS,
        value = trigger.Item,
        callback = function(value)
            trigger.Item = value
            apply()
            card:Rebuild()
        end,
    })
    if trigger.Item == 'trinket1' or trigger.Item == 'trinket2' then
        local trinketRow = card:Row(rowH)
        trinketRow:Button(L['Trinket Blacklist'], {
            width = 0.5,
            height = 24,
            yOffset = -14,
            tooltip = L['Trinkets that are never tracked, for on-use effects that only switch a mode.'],
            callback = function()
                trinketReturnKey = id
                Reopen(TRINKETS)
            end,
        })
        trinketRow:Checkbox(L['Hide Passive Trinkets'], {
            width = 0.5,
            tooltip = L['A trinket without an on-use effect is not tracked.'],
            value = trigger.HidePassive,
            callback = function(checked)
                trigger.HidePassive = checked
                apply()
            end,
        })
    elseif trigger.Item == 'custom' then
        local itemRow = card:Row(rowH)
        itemRow:EditBox(L['Item ID'], {
            width = 0.5,
            value = trigger.ItemID and tostring(trigger.ItemID) or '',
            callback = function(text)
                trigger.ItemID = tonumber(text)
                apply()
                card:Rebuild()
            end,
        })
        itemRow:Icon({
            width = 0.1,
            size = 24,
            yOffset = -14,
            texture = trigger.ItemID and GetItemIconByID(trigger.ItemID) or QUESTION_MARK,
            tooltip = function(tooltip)
                if trigger.ItemID then tooltip:SetItemByID(trigger.ItemID) end
            end,
        })
    end
end

function TriggerRows.timer(card, typeRow, display, trigger, id, apply)
    typeRow:EditBox(L['Spell ID'], {
        width = 0.5,
        tooltip = L['The timer starts when you cast this spell.'],
        value = trigger.SpellID and tostring(trigger.SpellID) or '',
        callback = function(text)
            trigger.SpellID = tonumber(text)
            apply()
            card:Rebuild()
        end,
    })
    card:Row(rowH):Slider(L['Duration'], {
        width = 0.5,
        min = 1,
        max = 60,
        step = 0.5,
        value = trigger.Duration,
        callback = function(value)
            trigger.Duration = value
            apply()
        end,
    })
end

function TriggerRows.totem(card, typeRow, display, trigger, id, apply)
    local Category = Enum.CooldownViewerCategory
    typeRow:Dropdown(L['Cooldown Manager'], {
        width = 0.5,
        tooltip = L['The spell that summons the totem.'],
        options = CatalogueOptions({ Category.Essential, Category.Utility }),
        value = trigger.CooldownID,
        callback = CataloguePicker(trigger, display, id, apply),
    })
end

---WeakAuras' trigger list: the first active trigger is the one shown, so the order is the priority.
---@param page table
---@param id string
local function BuildTriggerTab(page, id)
    local display = CDM:Get(id)
    local triggers = display.Triggers
    local apply = Applier(id)

    page:Card():Rebuild(function(card)
        local function Edit(fn)
            fn()
            apply()
            card:Rebuild()
        end

        for index, trigger in ipairs(triggers) do
            local title = format(L['Trigger %d: %s'], index, TRIGGER_NAMES[trigger.Type] or trigger.Type)
            local name = CDM:GetTriggerName(trigger)
            if name then title = title .. ' - ' .. name end

            local open = triggerOpen[index]
            if open == nil then open = #triggers == 1 end

            local expanded = card:Section(title, {
                key = 'cdm:trigger:' .. index,
                collapsed = not open,
                onToggle = function()
                    triggerOpen[index] = not open
                    card:Rebuild()
                end,
                onMoveUp = index > 1 and function()
                    Edit(function() triggers[index], triggers[index - 1] = triggers[index - 1], triggers[index] end)
                end or nil,
                onMoveDown = index < #triggers and function()
                    Edit(function() triggers[index], triggers[index + 1] = triggers[index + 1], triggers[index] end)
                end or nil,
                onDuplicate = function()
                    Edit(function() tinsert(triggers, index + 1, CopyTable(trigger)) end)
                end,
                onDelete = #triggers > 1 and function()
                    Edit(function() tremove(triggers, index) end)
                end or nil,
            })

            if expanded then
                local typeRow = card:Row(rowH)
                typeRow:Dropdown(L['Type'], {
                    width = 0.5,
                    options = TRIGGER_TYPES,
                    value = trigger.Type,
                    callback = function(value)
                        if value == trigger.Type then return end
                        Edit(function()
                            local new = value == 'aura' and LinkedAuraTrigger(display) or CopyTable(TRIGGER_DEFAULTS[value])
                            new.Type = value
                            triggers[index] = new
                        end)
                    end,
                })
                local rows = TriggerRows[trigger.Type]
                if rows then rows(card, typeRow, display, trigger, id, apply) end
            end
        end
        card:EndSection()

        card:Row(30, 0):Button(L['Add Trigger'], {
            width = 0.5,
            height = 24,
            callback = function()
                Edit(function()
                    local hasAura = false
                    for _, trigger in ipairs(triggers) do
                        if trigger.Type == 'aura' then hasAura = true end
                    end
                    -- A cooldown with a matching aura gets it on top, WeakAuras' aura-over-cooldown pair.
                    local aura = not hasAura and LinkedAuraTrigger(display)
                    if aura then
                        tinsert(triggers, 1, aura)
                    else
                        triggers[#triggers + 1] = { Type = 'spell', SpellID = triggers[1] and triggers[1].SpellID }
                    end
                end)
            end,
        })
    end)
end

local ANCHOR_ROLES = {
    { value = 'none',      text = L['None'] },
    { value = 'primary',   text = L['Primary'] },
    { value = 'secondary', text = L['Secondary'] },
}

local function ScheduleAnchorUpdate()
    local UF = NRSKNUI.UnitFrames
    if UF:IsEnabled() then UF:ScheduleCDMAnchorUpdate() end
end

---@param page table
---@param id string
local function BuildGroupTab(page, id)
    local display = CDM:Get(id)
    local apply = Applier(id)

    if display.type == 'dynamicgroup' then
        page:DynamicGroupCard({ title = L['Dynamic Group Settings'], db = display.Layout, onChangeCallback = apply })
        page:Card(L['Unit Frame Anchor']):Row(rowHL, 0):Dropdown(L['Anchor Role'], {
            width = 1,
            options = ANCHOR_ROLES,
            value = display.UFAnchor or 'none',
            tooltip = L['The unit frame anchor follows the loaded group with this role. Give one group per class or spec the Primary role.'],
            callback = function(value)
                display.UFAnchor = value ~= 'none' and value or nil
                ScheduleAnchorUpdate()
            end,
        })
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
        NRSKNUI.CDMDisplayTab:Build(page, CDM:GetIcons(id), Applier(id))
        return
    end

    NRSKNUI.CDMDisplayTab:Build(page, { id }, Applier(id))
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
    if display.type == 'icon' then
        local first = display.Triggers[1]
        return first and CDM:GetTriggerTexture(first) or QUESTION_MARK
    end
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
        local accent, secondary, muted = Theme.accent, Theme.textSecondary, Theme.textMuted
        tooltip:SetText(display.name, accent[1], accent[2], accent[3], 1, false)
        tooltip:AddLine(TYPE_NAMES[display.type], secondary[1], secondary[2], secondary[3])
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

    return { general = { key = GENERAL, text = L['General'] }, sections = { loaded, unloaded } }
end

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

---@param dynamic boolean
---@param parentId string?
local function NewGroup(dynamic, parentId)
    SelectAndRename(CDM:CreateGroup(dynamic and L['New Dynamic Group'] or L['New Group'], dynamic, parentId))
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
        entries[#entries + 1] = { text = L['Add Icon'], onClick = function() NewIcon(id) end }
        if display.type == 'group' then
            entries[#entries + 1] = { text = L['Add Group'], onClick = function() NewGroup(false, id) end }
            entries[#entries + 1] = { text = L['Add Dynamic Group'], onClick = function() NewGroup(true, id) end }
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
        description = L['Controls settings of multiple displays at the same time'],
        icon = 'Interface\\Icons\\INV_Misc_Bag_10',
        create = function() NewGroup(false) end,
    },
    {
        text = L['Dynamic Group'],
        description = L['A group that dynamically controls the positioning of its children'],
        icon = 'Interface\\Icons\\Ability_Rogue_Sprint',
        create = function() NewGroup(true) end,
    },
    {
        text = L['Icon'],
        description = L['Shows a spell icon with a variety of customization options'],
        icon = 'Interface\\Icons\\Spell_Nature_Lightning',
        create = function() NewIcon() end,
    },
}

---The trinket blacklist, its own page so the main page stays short; Back returns to the trigger it came from.
---@param page table
local function BuildTrinketPage(page)
    if trinketReturnKey and CDM:Get(trinketReturnKey) then
        page:Card():Row(30, 0):Button(format(L['Back to %s'], CDM:GetName(trinketReturnKey)), {
            width = 0.5,
            height = 24,
            callback = function() Reopen(trinketReturnKey) end,
        })
    end

    page:Card(L['Trinket Blacklist']):Rebuild(function(card)
        local ids = {}
        for itemID in pairs(CDM.db.TrinketBlacklist) do ids[#ids + 1] = itemID end
        table.sort(ids)
        for _, itemID in ipairs(ids) do
            card:Row(28):Icon({
                width = 1,
                size = 24,
                texture = GetItemIconByID(itemID) or QUESTION_MARK,
                text = { text = GetItemNameByID(itemID) or tostring(itemID), description = tostring(itemID) },
                tooltip = function(tooltip)
                    tooltip:SetItemByID(itemID)
                    tooltip:AddLine(L['Click to remove it from the blacklist.'], Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], true)
                end,
                onClick = function(button)
                    if button ~= 'LeftButton' then return end
                    CDM.db.TrinketBlacklist[itemID] = nil
                    CDM:ApplySettings()
                    card:Rebuild()
                end,
            })
        end
        card:Row(rowHL, 0):EditBox(L['Add Trinket'], {
            width = 1,
            tooltip = L["An item ID. Trinkets on this list are never tracked, for on-use effects that only switch the trinket's mode."],
            callback = function(text)
                local itemID = tonumber(text)
                if not itemID then return end
                CDM.db.TrinketBlacklist[itemID] = true
                CDM:ApplySettings()
                card:Rebuild()
            end,
        })
    end)
end

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

    local integration = page:Card(L['Integration'])
    integration:Row(rowH):Checkbox(L['Hide Blizzard Cooldown Manager'], {
        width = 1,
        value = CDM.db.HideBlizzard,
        tooltip = L["Turns off Blizzard's Cooldown Manager. Its spell list still feeds the icon picker."],
        callback = function(checked)
            CDM.db.HideBlizzard = checked
            if CDM:IsEnabled() then CDM:SetBlizzardViewers(checked) end
        end,
    })
    integration:Separator()
    integration:Row(rowHL, 0):Slider(L['Unit Frame Anchor Minimum Width'], {
        width = 1,
        min = 0,
        max = 600,
        step = 1,
        value = CDM.db.AnchorMinWidth,
        tooltip = L['The unit frame anchor is never narrower than this, so frames beside it keep their distance from a short group.'],
        callback = function(value)
            CDM.db.AnchorMinWidth = value
            ScheduleAnchorUpdate()
        end,
    })

    local card = page:Card(L['New'])
    for i, entry in ipairs(NEW_TYPES) do
        local entryNum = i == #NEW_TYPES and 0 or nil

        card:Row(NEW_ROW_HEIGHT, entryNum):Icon({
            width = 1,
            size = 32,
            texture = entry.icon,
            text = { text = entry.text, description = entry.description, color = Theme.accent },
            tooltip = function(tooltip)
                local accent, secondary = Theme.accent, Theme.textSecondary
                tooltip:SetText(entry.text, accent[1], accent[2], accent[3], 1, false)
                tooltip:AddLine(entry.description, secondary[1], secondary[2], secondary[3], true)
            end,
            onClick = function(button) if button == 'LeftButton' then entry.create() end end,
        })

        if entryNum ~= 0 then
            card:Separator()
        end
    end
end

GUI:RegisterPage(PAGE, {
    mode = 'tabs',
    search = { L['Cooldown Manager'], L['Sub Elements'], L['Swipe Overlay Settings'] },
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
        -- Into a group that can hold it, or next to a display inside one, the top level stays alphabetical.
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

        if itemKey == TRINKETS then
            BuildTrinketPage(page)
            return
        elseif not display then
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

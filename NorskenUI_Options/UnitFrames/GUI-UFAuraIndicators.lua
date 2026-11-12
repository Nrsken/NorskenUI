---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_UnitFrames') then return end
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast
local AuraIndicators = NRSKNUI.AuraIndicators
local AuraTriggers = NRSKNUI.AuraTriggers
local Premade = NRSKNUI.AuraFiltersPremade
local TriggerEditor = NRSKNUI.GUITriggerEditor
local AuraCards = NRSKNUI.GUIAuraCards
local OutlineOptions = NRSKNUI:GetOutlineOptions(true)

local ipairs, pairs = ipairs, pairs
local tonumber = tonumber
local format = string.format
local insert = table.insert
local CopyTable = CopyTable
local wipe = wipe
local GetSpellTexture = C_Spell.GetSpellTexture

local PAGE = 'unitFramesIndicators'
local NEW = 'new'
local PRESETS_SECTION = 'band:presets'
local OWN_SECTION = 'band:own'
local CATEGORY_PREFIX = 'category:'
local BUTTON_ROW_HEIGHT = 24 -- Kaji's own widget height, so a row of buttons takes no more than they do
local BUFF_ICON_SPELL = 21562 -- Power Word: Fortitude
local DEBUFF_ICON_SPELL = 589 -- Shadow Word: Pain
local Styles = AuraIndicators.Styles

local openGroups = {} -- [group key] = true while open, for the session; every class and user group starts folded

local STYLE_OPTIONS = {
    { value = Styles.Overlay,  text = L['Overlay Tint'] },
    { value = Styles.Square,   text = L['Square Texture'] },
    { value = Styles.Icon,     text = L['Aura Icon'] },
    { value = Styles.Duration, text = L['Duration Text'] },
}

-- Shared with the dispel pages, which hang off the same two things.
local ATTACH_OPTIONS = {
    { value = AuraIndicators.Attach.Health,     text = L['Health Bar'] },
    { value = AuraIndicators.Attach.HealthFill, text = L['Health Fill'] },
}
UF.GUIAttachOptions = ATTACH_OPTIONS

local function Store() return NRSKNUI.db.profile.AuraIndicators end
local function Changed(key) AuraIndicators:Invalidate(key) end

---@return table[] options
local function IndicatorOptions()
    local options = {}
    for _, entry in ipairs(AuraIndicators:GetList()) do
        options[#options + 1] = { value = entry.key, text = entry.text }
    end
    return options
end

local function Reopen(selectKey)
    local window = NRSKNUI.GUIFrame
    if not (window and window.content) then return end

    window.content:ShowPage(PAGE, selectKey and { itemKey = selectKey } or nil)
end

---@return table? tree
local function Tree()
    local content = NRSKNUI.GUIFrame and NRSKNUI.GUIFrame.content
    return content and content.miniSidebar
end

---@param groupKey string? the group it goes into
local function CreateIndicatorPrompt(groupKey)
    GUI:Prompt({
        title = L['Create Indicator'],
        text = '',
        editBox = true,
        editBoxLabel = L['Indicator Name'],
        onAccept = function(name)
            if not name or name == '' then
                NRSKNUI:Print(L['Please enter an indicator name'])
                return
            end
            if Store()[name] then
                NRSKNUI:Print(L['An indicator with that name already exists'])
                return
            end

            AuraIndicators:Create(name, name)
            -- the new indicator is the selection, so its group has to be open for it to be seen
            if groupKey then
                AuraIndicators:SetGroup(name, groupKey)
                Tree():SetExpanded(groupKey, true)
            end
            Reopen(name)
        end,
        acceptText = L['Create'],
        cancelText = L['Cancel'],
    })
end

---Make a group and move this indicator into it.
local function CreateGroupPrompt(key)
    GUI:Prompt({
        title = L['Create New Group'],
        text = '',
        editBox = true,
        editBoxLabel = L['Group Name'],
        onAccept = function(name)
            if not name or name == '' then
                NRSKNUI:Print(L['Please enter a name'])
                return
            end

            local groupId = AuraIndicators:CreateGroup(name)
            if not groupId then return end

            AuraIndicators:SetGroup(key, groupId)
            Reopen(key)
        end,
        acceptText = L['Create'],
        cancelText = L['Cancel'],
    })
end

local function DeleteIndicatorPrompt(key)
    local spec = AuraIndicators:GetSpec(key)
    if not spec then return end

    GUI:Prompt({
        title = L['Delete Indicator'],
        text = format(L["Delete the indicator '%s'? This cannot be undone."], spec.name or key),
        onAccept = function()
            for _, unit in ipairs(UF.Units) do
                AuraIndicators:RemoveKeyEverywhere(UF.db.Units[unit], key)
            end
            AuraIndicators:Delete(key)
            Reopen()
        end,
        acceptText = L['Delete'],
        cancelText = L['Cancel'],
    })
end

---@param key string
local function DuplicateIndicator(key)
    local newKey = AuraIndicators:Duplicate(key)
    if newKey then Reopen(newKey) end
end

---@param keys string[] shipped indicators to put back
---@param title string
---@param text string
local function ResetPrompt(keys, title, text)
    GUI:Prompt({
        title = title,
        text = text,
        onAccept = function()
            for _, key in ipairs(keys) do
                AuraIndicators:ResetBuiltin(key)
            end
            -- whatever is open may be one of them, so it rebuilds from the reset spec
            Reopen(Tree():GetSelected())
        end,
        acceptText = L['Reset'],
        cancelText = L['Cancel'],
    })
end

---@param key string
local function BuiltinMenu(key)
    local spec = AuraIndicators:GetSpec(key)

    GUI:ShowContextMenu({
        { text = L['Duplicate as Custom'], onClick = function() DuplicateIndicator(key) end },
        { divider = true },
        {
            text = L['Reset to Default'],
            onClick = function()
                ResetPrompt({ key }, L['Reset to Default'],
                    format(L["Put '%s' back to how it shipped, its triggers and color included?"], spec.name or key))
            end,
        },
    })
end

---@param item table a class group's tree row
local function CategoryMenu(item)
    local keys = {}
    for _, child in ipairs(item.children) do
        keys[#keys + 1] = child.key
    end

    local title = format(L['Reset %s to Default'], item.text)
    GUI:ShowContextMenu({
        {
            text = title,
            onClick = function()
                ResetPrompt(keys, title,
                    format(L['Put every %s indicator back to how it shipped, triggers and colors included?'], item.text))
            end,
        },
    })
end

local function BuildLibraryPage(page, key, spec)
    spec.Trigger = spec.Trigger or NRSKNUI.AuraTriggers:New()
    TriggerEditor:Build(page, spec.Trigger, { title = L['Indicator'], onChange = function() Changed(key) end })

    local look = page:Card(L['Appearance'])
    look:Row(rowHL, 0):ColorPicker(L['Color'], {
        width = 1,
        value = spec.Color,
        tooltip = L['Used by every style that draws its own artwork. The dispel styles are colored by the game instead.'],
        callback = function(r, g, b, a)
            spec.Color = { r, g, b, a }
            Changed(key)
        end,
    })

    local sorting = page:Card(L['Sorting'])
    local sortRow = sorting:Row(rowHL, 0)
    sortRow:Dropdown(L['Sort Method'], {
        width = 0.5,
        options = AuraCards.SortMethods,
        value = spec.sortMethod,
        tooltip = L['Which aura wins the slot when several match at once.'],
        callback = function(value)
            spec.sortMethod = value
            Changed(key)
        end,
    })
    sortRow:Dropdown(L['Sort Direction'], {
        width = 0.5,
        options = AuraCards.SortDirections,
        value = spec.sortDirection,
        callback = function(value)
            spec.sortDirection = value
            Changed(key)
        end,
    })
end

-- Sidebar --

---The sidebar's icon, only a picture: the lowest spell it whitelists, which is the baseline one when a
---spell has an echo or a talent copy, else a stand-in for its aura type.
---@param spec table
---@return number|string?
local function IndicatorIcon(spec)
    local trigger = spec.Trigger or {}
    local maps = {}
    -- an unconverted SpellIDs save is AceDB-refilled with its old list after conversion, so only its type says it's live
    if trigger.Type == AuraTriggers.Types.SpellIDs then
        maps[1] = trigger.SpellIDs
    else
        for _, branch in ipairs(trigger.branches or {}) do
            maps[#maps + 1] = branch.candidates and branch.candidates.includeSpellIDs
        end
    end

    local lowest
    for _, map in ipairs(maps) do
        for id, on in pairs(map) do
            if on and (not lowest or id < lowest) then
                lowest = id
            end
        end
    end
    if lowest then
        return GetSpellTexture(lowest)
    end

    return GetSpellTexture(trigger.Base == AuraUtil.AuraFilters.Harmful and DEBUFF_ICON_SPELL or BUFF_ICON_SPELL)
end

---@param key string
---@return boolean
local function IsOpen(key)
    return not NRSKNUI.db.global.SidebarCollapsed[PAGE][key]
end

---@param key string
---@param text string
---@param depth number
---@return table
local function IndicatorRow(key, text, depth)
    local shipped = AuraIndicators:IsBuiltin(key)

    return {
        key = key,
        text = text,
        icon = IndicatorIcon(AuraIndicators:GetSpec(key)),
        depth = depth,
        enabled = true,
        draggable = not shipped,
        fixed = shipped,
    }
end

-- the canvas only ever holds this one texture on this page, so it's kept on the canvas and re-pointed
---@param classFile string
---@return fun(canvas: Frame): boolean
local function DrawClassIcon(classFile)
    return function(canvas)
        local texture = canvas.NUIClassIcon
        if not texture then
            texture = canvas:CreateTexture(nil, 'ARTWORK')
            texture:NCSetInside(canvas, 0, 0)
            canvas.NUIClassIcon = texture
        end
        texture:SetAtlas(GetClassAtlas(classFile:lower()))
        texture:Show()
        return true
    end
end

---The shipped indicators under Presets, the unclassed ones loose and a folding group per class, then the
---user's own: their groups and loose ones by name, only a group's members keeping a manual order. An empty
---user group stays listed so it can be dropped into.
---@return table
local function TreeContent()
    local presets = { key = PRESETS_SECTION, text = L['Presets'], collapsed = not IsOpen(PRESETS_SECTION), rows = {} }
    local own = { key = OWN_SECTION, text = L['Your Indicators'], collapsed = not IsOpen(OWN_SECTION), rows = {} }
    local categories = {}

    for _, group in ipairs(AuraIndicators:GetGroups()) do
        local children = {}
        local members = AuraIndicators:GetMembers(group.key)
        for index, member in ipairs(members) do
            local child = IndicatorRow(member.key, member.text, 1)
            child.canMoveUp = index > 1
            child.canMoveDown = index < #members
            insert(children, child)
        end

        -- a group wears its first member's icon
        insert(own.rows, {
            key = group.key,
            text = group.name,
            icon = children[1] and children[1].icon or GetSpellTexture(BUFF_ICON_SPELL),
            depth = 0,
            enabled = true,
            isGroup = true,
            expanded = openGroups[group.key] == true,
            children = children,
            childCount = #children,
        })
    end

    for _, entry in ipairs(AuraIndicators:GetList()) do
        local spec = AuraIndicators:GetSpec(entry.key)
        local category = spec.category
        if category then
            categories[category] = categories[category] or {}
            insert(categories[category], IndicatorRow(entry.key, entry.text, 1))
        elseif AuraIndicators:IsBuiltin(entry.key) then
            insert(presets.rows, IndicatorRow(entry.key, entry.text, 0))
        elseif not spec.group then
            insert(own.rows, IndicatorRow(entry.key, entry.text, 0))
        end
    end

    -- the classes as the presets order them, a shared group like Trinkets after them
    for _, category in ipairs(Premade.Groups) do
        local children = categories[category]
        if children then
            local key = CATEGORY_PREFIX .. category
            local isClass = Premade:IsClassGroup(category)
            insert(presets.rows, {
                key = key,
                text = Premade:GetGroupName(category),
                icon = not isClass and children[1].icon or nil,
                draw = isClass and DrawClassIcon(category) or nil,
                depth = 0,
                enabled = true,
                isGroup = true,
                shipped = true,
                expanded = openGroups[key] == true,
                children = children,
                childCount = #children,
            })
        end
    end

    return { general = { key = NEW, text = L['New Indicator'] }, sections = { presets, own } }
end

local function RefreshTree()
    local tree = Tree()
    if not tree then return end

    tree:SetItems()
end

---@param groupKey string
local function GroupMenu(groupKey)
    GUI:ShowContextMenu({
        { text = L['New Indicator'], onClick = function() CreateIndicatorPrompt(groupKey) end },
        { divider = true },
        { text = L['Rename'],        onClick = function() Tree():BeginRename(groupKey) end },
        {
            text = L['Delete Group'],
            onClick = function()
                AuraIndicators:DeleteGroup(groupKey)
                RefreshTree()
            end,
        },
    })
end

---What a group's or nothing's selection opens on, an indicator made inside the group when it's one of the
---user's; a preset is picked later on its trigger.
---@param page KajiGUIPage
---@param item table? the tree row, a group's for its name
local function BuildNewPage(page, item)
    local groupKey = item and item.isGroup and not item.shipped and item.key or nil

    page:Card(groupKey and item.text or L['New Indicator']):Row(BUTTON_ROW_HEIGHT):Button(L['Create Indicator'], {
        width = 1,
        height = BUTTON_ROW_HEIGHT,
        callback = function() CreateIndicatorPrompt(groupKey) end,
    })
end

GUI:RegisterPage(PAGE, {
    mode = 'clean',
    search = {},
    sidebar = {
        width = 260,
        create = NRSKNUI.Kaji.CreateItemTree,
        items = TreeContent,
        -- the two bands start open and remember closing, every group starts folded and remembers opening
        onToggleExpanded = function(key, expanded)
            if key == PRESETS_SECTION or key == OWN_SECTION then
                NRSKNUI.db.global.SidebarCollapsed[PAGE][key] = (not expanded) or nil
            else
                openGroups[key] = expanded or nil
            end
        end,
        onRename = function(key, text, item)
            if item.isGroup then
                AuraIndicators:RenameGroup(key, text)
                RefreshTree()
                return
            end

            -- an indicator is keyed by its name, so a taken name is refused and a rename moves the key
            local newKey = AuraIndicators:Rename(key, text)
            if not newKey then
                NRSKNUI:Print(L['An indicator with that name already exists'])
                return
            end
            if Tree():GetSelected() == key then
                Reopen(newKey)
            else
                RefreshTree()
            end
        end,
        -- into a group or next to a grouped indicator; next to a loose one only takes an indicator out of its group
        canDrop = function(item, target, position)
            if position == 'into' then
                return target.isGroup == true and not target.shipped
            end
            if not target.draggable then return false end

            return AuraIndicators:GetSpec(target.key).group ~= nil or AuraIndicators:GetSpec(item.key).group ~= nil
        end,
        onMove = function(keys, targetKey, position)
            -- after the target each one follows it, so going in reverse keeps their order
            local reverse = position == 'after'
            for i = reverse and #keys or 1, reverse and 1 or #keys, reverse and -1 or 1 do
                if position == 'into' then
                    AuraIndicators:SetGroup(keys[i], targetKey)
                else
                    AuraIndicators:MoveNextTo(keys[i], targetKey, position)
                end
            end

            if position == 'into' then
                Tree():SetExpanded(targetKey, true)
            else
                RefreshTree()
            end
        end,
        onMoveInGroup = function(key, delta)
            local members = AuraIndicators:GetMembers(AuraIndicators:GetSpec(key).group)
            for index, member in ipairs(members) do
                local neighbour = member.key == key and members[index + delta]
                if neighbour then
                    AuraIndicators:MoveNextTo(key, neighbour.key, delta < 0 and 'before' or 'after')
                    break
                end
            end
            RefreshTree()
        end,
        onUngroup = function(key)
            AuraIndicators:SetGroup(key, nil)
            RefreshTree()
        end,
        onContextMenu = function(key, item)
            if item and item.shipped then
                CategoryMenu(item)
                return
            end
            if item and item.isGroup then
                GroupMenu(key)
                return
            end
            if AuraIndicators:IsBuiltin(key) then
                BuiltinMenu(key)
                return
            end

            local spec = AuraIndicators:GetSpec(key)
            if not spec then return end

            local entries = {
                { text = L['Rename'],           onClick = function() Tree():BeginRename(key) end },
                { text = L['Duplicate'],        onClick = function() DuplicateIndicator(key) end },
                { text = L['Delete'],           onClick = function() DeleteIndicatorPrompt(key) end },
                { divider = true },
                { text = L['Create New Group'], onClick = function() CreateGroupPrompt(key) end },
            }

            for _, group in ipairs(AuraIndicators:GetGroups()) do
                if group.key ~= spec.group then
                    entries[#entries + 1] = {
                        text = format(L['Add to %s'], group.name),
                        onClick = function()
                            AuraIndicators:SetGroup(key, group.key)
                            RefreshTree()
                        end,
                    }
                end
            end

            if spec.group then
                entries[#entries + 1] = {
                    text = L['Remove from Group'],
                    onClick = function()
                        AuraIndicators:SetGroup(key, nil)
                        RefreshTree()
                    end,
                }
            end

            GUI:ShowContextMenu(entries)
        end,
    },
    build = function(page, _, itemKey, item)
        if not NRSKNUI.db or not Store() then return end

        local spec = itemKey and AuraIndicators:GetSpec(itemKey)
        if not spec then
            BuildNewPage(page, item)
            return
        end

        BuildLibraryPage(page, itemKey, spec)
    end,
})

---@param unit string
---@return table[] tabs
function UF.GUIAuraIndicatorTabs(unit)
    local placements = UF.db.Units[unit].AuraIndicators
    local tabs = {}

    for index, placement in ipairs(placements) do
        tabs[index] = { id = tostring(index), text = AuraIndicators:GetPlacementName(placement, index) }
    end
    if not tabs[1] then
        tabs[1] = { id = '1', text = L['Aura Indicators'] }
    end

    return tabs
end

---@param page KajiGUIPage
---@param card KajiGUIFluentCard
---@param font table placement.Font
---@param sizes table[] one { label, db, key } per string the style draws
local function AddFontRows(page, card, font, sizes)
    local ownFont = { 'indicatorOwnFont' }

    local function AddSize(row, width, size)
        row:Slider(size.label, {
            width = width,
            min = 6,
            max = 32,
            step = 1,
            value = size.db[size.key],
            callbackOnRelease = true,
            callback = function(value)
                size.db[size.key] = value
                Changed(nil)
            end,
        })
    end

    local function AddOutline(row, width)
        row:Dropdown(L['Outline'], {
            width = width,
            options = OutlineOptions,
            conditions = ownFont,
            value = font.FontOutline,
            callback = function(value)
                font.FontOutline = value
                Changed(nil)
            end,
        })
    end

    local fontRow = card:Row(rowH)
    fontRow:Checkbox(L['Use Global Font'], {
        width = 0.5,
        value = font.UseGlobalFont,
        tooltip = L["The text is colored by the indicator itself, on the Aura Indicators page."],
        callback = function(checked)
            font.UseGlobalFont = checked
            Changed(nil)
            page:Refresh()
        end,
    })
    fontRow:Dropdown(L['Font'], {
        width = 0.5,
        media = 'font',
        searchable = true,
        conditions = ownFont,
        value = font.FontFace,
        callback = function(value)
            font.FontFace = value
            Changed(nil)
        end,
    })

    if #sizes == 1 then
        local sizeRow = card:Row(rowHL, 0)
        AddSize(sizeRow, 0.5, sizes[1])
        AddOutline(sizeRow, 0.5)
        return
    end

    local sizeRow = card:Row(rowH)
    AddSize(sizeRow, 0.5, sizes[1])
    AddSize(sizeRow, 0.5, sizes[2])

    AddOutline(card:Row(rowHL, 0), 1)
end

local function BuildStyleOptions(page, card, placement)
    if placement.Style == Styles.Icon then
        local row1 = card:Row(rowH)
        row1:Checkbox(L['Cooldown Spiral'], {
            width = 0.5,
            value = placement.Icon.showCooldown,
            callback = function(checked)
                placement.Icon.showCooldown = checked
                Changed(nil)
            end,
        })
        row1:Checkbox(L['Stack Count'], {
            width = 0.5,
            value = placement.Icon.showStacks,
            callback = function(checked)
                placement.Icon.showStacks = checked
                Changed(nil)
            end,
        })

        local row2 = card:Row(rowH)
        row2:Checkbox(L['Duration Text'], {
            width = 0.5,
            value = placement.Icon.showDuration,
            callback = function(checked)
                placement.Icon.showDuration = checked
                Changed(nil)
            end,
        })
        row2:Checkbox(L['Dispel Colored Border'], {
            width = 0.5,
            value = placement.Icon.showBorder,
            callback = function(checked)
                placement.Icon.showBorder = checked
                Changed(nil)
            end,
        })

        card:Separator()

        AddFontRows(page, card, placement.Font, {
            { label = L['Stack Font Size'],    db = placement.StackFont,    key = 'FontSize' },
            { label = L['Duration Font Size'], db = placement.DurationFont, key = 'FontSize' },
        })
        return
    end

    if placement.Style == Styles.Duration then
        AddFontRows(page, card, placement.Font, {
            { label = L['Font Size'], db = placement.Font, key = 'FontSize' },
        })
        return
    end

    local textureRow = card:Row(rowHL, 0)
    textureRow:Dropdown(L['Texture'], {
        width = 0.5,
        media = 'statusbar',
        searchable = true,
        value = placement.Texture,
        tooltip = L['Leave empty for a flat color. The color itself is set on the indicator.'],
        callback = function(value)
            placement.Texture = value
            Changed(nil)
        end,
    })
    textureRow:Checkbox(L['Solid'], {
        width = 0.5,
        value = placement.Solid,
        tooltip = L['Draw the tint over the bar instead of adding to it, so alpha reads as real opacity.'],
        callback = function(checked)
            placement.Solid = checked
            Changed(nil)
        end,
    })
end

---Reopen a unit's Aura Indicators section, optionally on a given placement.
---@param unit string
---@param index number? 1-based placement to select
local function ReloadUnit(unit, index)
    local window = NRSKNUI.GUIFrame
    if not (window and window.content) then return end

    window.content:ShowPage(UF.GUIPageID(unit), { itemKey = 'auraindicators', tabId = index and tostring(index) or nil })
end

---The last copied setup. Held as its own deep copy, so editing the source unit afterwards, or
---switching profiles, leaves what was copied alone.
local clipboard

---@param unit string
---@return string
local function UnitLabel(unit)
    return UF.UnitLabels[unit] or unit
end

---@param unit string
---@param uDB table
---@param replace boolean wipe what the unit has, rather than appending to it
local function Paste(unit, uDB, replace)
    if not clipboard then return end

    local placements = uDB.AuraIndicators
    local first = replace and 1 or #placements + 1

    if replace then wipe(placements) end
    -- Pasted spots keep their order among themselves and land above what the unit already has.
    local base = AuraIndicators:TopOrder(placements) - 1
    -- Copied again on the way out, so pasting the same setup onto two units never shares tables.
    for _, placement in ipairs(clipboard.placements) do
        local copy = CopyTable(placement)
        copy.Order = base + (placement.Order or 0)
        placements[#placements + 1] = copy
    end

    Changed(nil)
    ReloadUnit(unit, first)
end

---Right-click menu on a unit page's Aura Indicators section, for moving a whole setup between units.
---@param unit string
function UF.GUIAuraIndicatorContext(unit)
    local uDB = UF.db.Units[unit]
    local placements = uDB.AuraIndicators

    local entries = {
        {
            text = L['Copy Aura Indicators'],
            disabled = not placements[1],
            onClick = function()
                clipboard = { unit = unit, placements = CopyTable(placements) }
                NRSKNUI:Print(format(L['Copied %d aura indicators from %s'], #placements, UnitLabel(unit)))
            end,
        },
    }

    if clipboard then
        local from = UnitLabel(clipboard.unit)

        entries[#entries + 1] = { divider = true }
        entries[#entries + 1] = {
            text = format(L['Paste from %s'], from),
            onClick = function()
                if not placements[1] then
                    Paste(unit, uDB, true)
                    return
                end

                GUI:Prompt({
                    title = L['Paste Aura Indicators'],
                    text = format(L['Replace the %d aura indicators on %s with the %d copied from %s?'],
                        #placements, UnitLabel(unit), #clipboard.placements, from),
                    onAccept = function() Paste(unit, uDB, true) end,
                    acceptText = L['Replace'],
                    cancelText = L['Cancel'],
                })
            end,
        }
        entries[#entries + 1] = {
            text = format(L['Paste from %s (Add)'], from),
            onClick = function() Paste(unit, uDB, false) end,
        }
    end

    GUI:ShowContextMenu(entries)
end

---@param page KajiGUIPage
---@param uDB table
---@param unit string
---@param tabId string the 1-based placement index, as a string
local function BuildUnitSection(page, uDB, unit, tabId)
    local placements = uDB.AuraIndicators
    local index = tonumber(tabId) or 1
    local placement = placements[index]

    if placement and not Styles[placement.Style] then
        placement.Style = Styles.Overlay
        Changed(nil)
    end

    page:SetCondition('indicatorOwnFont', function()
        return placement ~= nil and not placement.Font.UseGlobalFont
    end)

    local function Reload() ReloadUnit(unit) end

    local card = page:Card(placement and AuraIndicators:GetPlacementName(placement, index) or L['Aura Indicators'])

    card:Rebuild(function(c)
        if not placement then
            c:Row(rowH):Text(L['Aura Indicators'], {
                width = 1,
                text = L['Nothing placed on this unit yet. Use Add Indicator below.'],
                height = rowH,
                bgMode = 'hide',
            })
        else
            c:Row(rowH):EditBox(L['Name'], {
                width = 1,
                value = placement.Name,
                tooltip = L['What to call this spot in the tab strip. Leave empty to number it.'],
                callback = function(value)
                    placement.Name = value
                    Reload()
                end,
            })

            local row = c:Row(rowH)
            row:Dropdown(L['Indicators'], {
                width = 0.5,
                searchable = true,
                multiSelect = true,
                options = IndicatorOptions(),
                value = placement.Keys,
                tooltip = L['Every indicator that can fill this spot. Assign one per spec and the same spot works on all of them.'],
                callback = function() Changed(nil) end,
            })
            row:Button(L['Remove Spot'], {
                yOffset = -14,
                width = 0.5,
                height = 24,
                callback = function()
                    AuraIndicators:RemovePlacement(uDB, index)
                    Changed(nil)
                    Reload()
                end,
            })
        end

        c:Separator()

        c:Row(32):Button(L['Add Indicator'], {
            width = 1,
            height = 32,
            callback = function()
                AuraIndicators:AddPlacement(uDB)
                Reload()
            end,
        })
    end)

    if not placement then return end

    local typeCard = page:Card(L['Style Type'])

    typeCard:Row(rowH):Dropdown(L['Style'], {
        width = 1,
        options = STYLE_OPTIONS,
        value = placement.Style,
        tooltip = L['The preview follows straight away. Aura buttons are built once by the game, so the real indicator only picks a new style up after a reload.'],
        callback = function(value)
            -- A new style can mean a new draw group, and it arrives on top of it.
            if UF.IndicatorGroup({ Style = value }) ~= UF.IndicatorGroup(placement) then
                placement.Order = AuraIndicators:TopOrder(placements)
            end
            placement.Style = value
            Changed(nil)
            Reload()
        end,
    })

    local placeRow = typeCard:Row(rowHL, 0)
    placeRow:Dropdown(L['Attach To'], {
        width = 0.5,
        options = ATTACH_OPTIONS,
        value = placement.Attach,
        callback = function(value)
            placement.Attach = value
            Changed(nil)
        end,
    })
    placeRow:Slider(L['Alpha'], {
        width = 0.5,
        min = 0,
        max = 1,
        step = 0.05,
        value = placement.Alpha,
        tooltip = L["Multiplies the indicator's own color alpha, so 100% is exactly the color it carries."],
        callback = function(value)
            placement.Alpha = value
            Changed(nil)
        end,
    })

    -- Back on this spot's own tab after a reorder.
    UF.GUIDrawOrderCard(page, uDB, placement, function() ReloadUnit(unit, index) end)
    BuildStyleOptions(page, page:Card(L['Style Settings']), placement)

    if AuraIndicators.FullCover[placement.Style] then return end

    if placement.Style == Styles.Icon then
        AuraCards:TextPosition(page, placement, { Apply = function() Changed(nil) end })
    end

    if AuraIndicators.Sized[placement.Style] then
        local sizeCard = page:Card(L['Size'])
        local sizeRow = sizeCard:Row(rowHL, 0)
        sizeRow:Slider(L['Width'], {
            width = 0.5,
            min = 1,
            max = 200,
            step = 1,
            value = placement.Size.Width,
            callback = function(value)
                placement.Size.Width = value
                Changed(nil)
            end,
        })
        sizeRow:Slider(L['Height'], {
            width = 0.5,
            min = 1,
            max = 200,
            step = 1,
            value = placement.Size.Height,
            callback = function(value)
                placement.Size.Height = value
                Changed(nil)
            end,
        })
    end

    page:PositionCard({
        db = placement,
        showAnchorFrameType = false,
        showStrata = false,
        onChangeCallback = function() Changed(nil) end,
    })
end

UF.GUISections.auraindicators = BuildUnitSection

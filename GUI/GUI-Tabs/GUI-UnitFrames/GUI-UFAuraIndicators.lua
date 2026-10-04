---@class NRSKNUI
local NRSKNUI = select(2, ...)
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

local ipairs = ipairs
local tonumber = tonumber
local format = string.format
local CopyTable = CopyTable
local wipe = wipe

local PAGE = 'unitFramesIndicators'
local INDICATORS_SECTION = 'auraIndicators_section'
local Styles = AuraIndicators.Styles

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

---@return table? miniSidebar
local function MiniSidebar()
    local content = NRSKNUI.GUIFrame and NRSKNUI.GUIFrame.content
    return content and content.miniSidebar
end

---@param presetKey string? start from this preset
---@param presetName string? its name, the suggested indicator name
local function CreateIndicatorPrompt(presetKey, presetName)
    NRSKNUI:CreatePrompt({
        title = L['Create Indicator'],
        text = presetName or '',
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

            AuraIndicators:Create(name, name, presetKey)
            Reopen(name)
        end,
        acceptText = L['Create'],
        cancelText = L['Cancel'],
    })
end

local function NewIndicatorMenu()
    local entries = {
        { text = L['Empty Indicator'], onClick = function() CreateIndicatorPrompt() end },
        { divider = true },
    }
    for _, preset in ipairs(Premade:GetList()) do
        entries[#entries + 1] = {
            text = format(L['From %s'], preset.text),
            onClick = function() CreateIndicatorPrompt(preset.key, preset.text) end,
        }
    end
    GUI:ShowContextMenu(entries)
end

---Make a group and move this indicator into it.
local function CreateGroupPrompt(key)
    NRSKNUI:CreatePrompt({
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

    NRSKNUI:CreatePrompt({
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

---@param key string
local function BuiltinMenu(key)
    local spec = AuraIndicators:GetSpec(key)
    local shipped = AuraTriggers:GetShipped(spec.Trigger)
    local entries = {
        { text = L['Duplicate as Custom'], onClick = function() DuplicateIndicator(key) end },
        { divider = true },
    }

    if shipped and (shipped.Added or shipped.Removed) then
        entries[#entries + 1] = {
            text = L['Reset Spells to Default'],
            onClick = function()
                NRSKNUI:CreatePrompt({
                    title = L['Reset Spells to Default'],
                    text = L['Remove the spells you added and switch every default spell back on?'],
                    onAccept = function()
                        shipped.Added, shipped.Removed = nil, nil
                        Changed(key)
                        Reopen(key)
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
                text = format(L["Put '%s' back to how it shipped, its triggers and color included?"], spec.name or key),
                onAccept = function()
                    AuraIndicators:ResetBuiltin(key)
                    Reopen(key)
                end,
                acceptText = L['Reset'],
                cancelText = L['Cancel'],
            })
        end,
    }

    GUI:ShowContextMenu(entries)
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

---@param key string
---@param text string
---@param spec table
---@return table
local function IndicatorItem(key, text, spec)
    return {
        key = key,
        text = text,
        draggable = true,
        renamable = true,
        grouped = spec.group ~= nil,
    }
end

---@param key string
---@return boolean
local function IsOpen(key)
    return not NRSKNUI.db.global.SidebarCollapsed[PAGE][key]
end

---Defaults first, then groups and loose indicators by name; only a group's own indicators keep a manual order.
---@return table[]
local function SidebarItems()
    local items = {}

    local shipped = {}
    for _, entry in ipairs(AuraIndicators:GetList()) do
        if AuraIndicators:IsBuiltin(entry.key) then
            shipped[#shipped + 1] = { key = entry.key, text = entry.text }
        end
    end

    if shipped[1] then
        items[#items + 1] = {
            type = 'header',
            key = INDICATORS_SECTION,
            text = L['Default Indicators'],
            defaultExpanded = IsOpen(INDICATORS_SECTION),
            items = shipped,
        }
    end

    -- An empty group stays listed, so an indicator can be dragged back into it.
    for _, group in ipairs(AuraIndicators:GetGroups()) do
        local members = {}
        for _, member in ipairs(AuraIndicators:GetMembers(group.key)) do
            members[#members + 1] = IndicatorItem(member.key, member.text, AuraIndicators:GetSpec(member.key))
        end

        items[#items + 1] = {
            type = 'header',
            key = group.key,
            text = group.name,
            isGroup = true,
            defaultExpanded = IsOpen(group.key),
            items = members,
        }
    end

    for _, entry in ipairs(AuraIndicators:GetList()) do
        local spec = AuraIndicators:GetSpec(entry.key)
        if spec and not spec.group and not AuraIndicators:IsBuiltin(entry.key) then
            items[#items + 1] = IndicatorItem(entry.key, entry.text, spec)
        end
    end

    return items
end

local function RefreshSidebar()
    local sidebar = MiniSidebar()
    if sidebar then sidebar:SetItems(SidebarItems()) end
end

---@param groupKey string
local function GroupMenu(groupKey)
    GUI:ShowContextMenu({
        { text = L['Rename'], onClick = function() MiniSidebar():BeginRename(groupKey) end },
        {
            text = L['Delete Group'],
            onClick = function()
                AuraIndicators:DeleteGroup(groupKey)
                RefreshSidebar()
            end,
        },
    })
end

GUI:RegisterPage(PAGE, {
    mode = 'clean',
    search = {},
    sidebar = {
        buttons = {
            { text = L['New Indicator'], onClick = NewIndicatorMenu },
        },
        items = SidebarItems,
        onToggle = function(key, expanded)
            NRSKNUI.db.global.SidebarCollapsed[PAGE][key] = (not expanded) or nil
        end,
        onRename = function(key, text, item)
            if item.isGroup then
                AuraIndicators:RenameGroup(key, text)
                RefreshSidebar()
                return
            end

            -- An indicator is keyed by its name, so a taken name is refused and a rename moves the key.
            local newKey = AuraIndicators:Rename(key, text)
            if not newKey then return false end
            if MiniSidebar():GetSelected() == key then
                Reopen(newKey)
            else
                RefreshSidebar()
            end
        end,
        -- Into a group, or next to a grouped indicator; next to a loose one only takes an indicator out of its group.
        canDrop = function(item, target, position)
            if position == 'into' then return target.isGroup == true end
            return target.draggable == true and (target.grouped or item.grouped)
        end,
        onMove = function(key, targetKey, position)
            if position == 'into' then
                AuraIndicators:SetGroup(key, targetKey)
            else
                AuraIndicators:MoveNextTo(key, targetKey, position)
            end
            RefreshSidebar()
            if position == 'into' then MiniSidebar():SetExpanded(targetKey, true) end
        end,
        onContextMenu = function(key, item)
            if item and item.isGroup then return GroupMenu(key) end
            if AuraIndicators:IsBuiltin(key) then return BuiltinMenu(key) end

            local spec = AuraIndicators:GetSpec(key)
            if not spec then return end

            local entries = {
                { text = L['Rename'],           onClick = function() MiniSidebar():BeginRename(key) end },
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
                            RefreshSidebar()
                        end,
                    }
                end
            end

            if spec.group then
                entries[#entries + 1] = {
                    text = L['Remove from Group'],
                    onClick = function()
                        AuraIndicators:SetGroup(key, nil)
                        RefreshSidebar()
                    end,
                }
            end

            GUI:ShowContextMenu(entries)
        end,
    },
    build = function(page, _, itemKey)
        if not NRSKNUI.db or not Store() then return end

        local spec = itemKey and AuraIndicators:GetSpec(itemKey)
        if not spec then
            page:Card(L['Aura Indicators']):Row(rowH):Text(L['Aura Indicators'], {
                width = 1,
                text = L['No indicators yet. Use New Indicator to create one.'],
                height = rowH,
                bgMode = 'hide',
            })
            return
        end

        BuildLibraryPage(page, itemKey, spec)
    end,
})

---@param unit string
---@return table[] tabs
function UF.GUIAuraIndicatorTabs(unit)
    local placements = NRSKNUI.db.profile.UnitFrames.Units[unit].AuraIndicators
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
    local uDB = NRSKNUI.db.profile.UnitFrames.Units[unit]
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

                NRSKNUI:CreatePrompt({
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

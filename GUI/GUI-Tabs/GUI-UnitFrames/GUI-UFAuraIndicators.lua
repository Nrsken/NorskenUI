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
local TriggerCard = NRSKNUI.GUITriggerCard
local AuraCards = NRSKNUI.GUIAuraCards
local OutlineOptions = NRSKNUI:GetOutlineOptions(true)

local ipairs = ipairs
local tonumber = tonumber
local format = string.format

local PAGE = 'unitFramesIndicators'
local INDICATORS_SECTION = 'auraIndicators_section'
local Styles = AuraIndicators.Styles

local STYLE_OPTIONS = {
    { value = Styles.Overlay,  text = L['Overlay Tint'] },
    { value = Styles.Square,   text = L['Square Texture'] },
    { value = Styles.Icon,     text = L['Aura Icon'] },
    { value = Styles.Duration, text = L['Duration Text'] },
}

-- Shared with the dispel pages, which hang off the same three things.
local ATTACH_OPTIONS = {
    { value = AuraIndicators.Attach.Frame,      text = L['Whole Frame'] },
    { value = AuraIndicators.Attach.Health,     text = L['Health Bar'] },
    { value = AuraIndicators.Attach.HealthFill, text = L['Health Fill'] },
}
UF.GUIAttachOptions = ATTACH_OPTIONS

local function Store() return NRSKNUI.db.global.AuraIndicators end
local function Changed(key) AuraIndicators:Invalidate(key) end

---Layer choices.
---@return table[]
function UF.GUILayerOptions()
    local options = {}

    for layer = UF.Layers.Min, UF.Layers.Max do
        local text = format(L['Layer %d'], layer)
        if layer == UF.Layers.Highlight then
            text = format(L['Layer %d (mouseover highlight)'], layer)
        elseif layer == UF.Layers.Border then
            text = format(L['Layer %d (frame border)'], layer)
        end

        options[#options + 1] = { value = layer, text = text }
    end

    return options
end

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

local function CreateIndicatorPrompt()
    NRSKNUI:CreatePrompt({
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
            Reopen(name)
        end,
        acceptText = L['Create'],
        cancelText = L['Cancel'],
    })
end

local function RenameIndicatorPrompt(key)
    local spec = AuraIndicators:GetSpec(key)
    if not spec then return end

    NRSKNUI:CreatePrompt({
        title = L['Rename Indicator'],
        text = '',
        editBox = true,
        editBoxLabel = L['New Name'],
        onAccept = function(new)
            if not new or new == '' then return end
            local store = Store()
            if store[new] then
                NRSKNUI:Print(L['An indicator with that name already exists'])
                return
            end

            -- Placements reference the store key, so every one of them has to follow the rename.
            spec.name = new
            store[new] = spec
            store[key] = nil
            for _, unit in ipairs(UF.Units) do
                for _, placement in ipairs(UF.db.Units[unit].AuraIndicators) do
                    for i, assigned in ipairs(placement.Keys) do
                        if assigned == key then placement.Keys[i] = new end
                    end
                end
            end

            Changed(key)
            Reopen(new)
        end,
        acceptText = L['Rename'],
        cancelText = L['Cancel'],
    })
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

local function BuildLibraryPage(page, key, spec)
    spec.Trigger = spec.Trigger or NRSKNUI.AuraTriggers:New()
    TriggerCard:Build(page, spec.Trigger, { hideUnit = true, onChange = function() Changed(key) end })

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

---Indicator list.
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
            defaultExpanded = true,
            items = shipped,
        }
    end

    for _, group in ipairs(AuraIndicators:GetGroups()) do
        local members = {}
        for _, entry in ipairs(AuraIndicators:GetList()) do
            local spec = AuraIndicators:GetSpec(entry.key)
            if spec and spec.group == group.key then
                members[#members + 1] = { key = entry.key, text = entry.text }
            end
        end

        if members[1] then
            items[#items + 1] = {
                type = 'header',
                key = group.key,
                text = group.name,
                defaultExpanded = true,
                items = members,
            }
        end
    end

    for _, entry in ipairs(AuraIndicators:GetList()) do
        local spec = AuraIndicators:GetSpec(entry.key)
        if spec and not spec.group and not AuraIndicators:IsBuiltin(entry.key) then
            items[#items + 1] = { key = entry.key, text = entry.text }
        end
    end

    return items
end

GUI:RegisterPage(PAGE, {
    mode = 'clean',
    search = {},
    sidebar = {
        buttons = {
            { text = L['New Indicator'], onClick = CreateIndicatorPrompt },
        },
        items = SidebarItems,
        onContextMenu = function(key)
            local spec = not AuraIndicators:IsBuiltin(key) and AuraIndicators:GetSpec(key)
            if not spec then return end

            local entries = {
                { text = L['Rename'],           onClick = function() RenameIndicatorPrompt(key) end },
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
                            Reopen(key)
                        end,
                    }
                end
            end

            if spec.group then
                entries[#entries + 1] = {
                    text = L['Remove from Group'],
                    onClick = function()
                        AuraIndicators:SetGroup(key, nil)
                        Reopen(key)
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

    card:Row(rowHL, 0):Dropdown(L['Texture'], {
        width = 1,
        media = 'statusbar',
        searchable = true,
        value = placement.Texture,
        tooltip = L['Leave empty for a flat color. The color itself is set on the indicator.'],
        callback = function(value)
            placement.Texture = value
            Changed(nil)
        end,
    })
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

    local function Reload()
        local window = NRSKNUI.GUIFrame
        if window and window.content then
            window.content:ShowPage(UF.GUIPageID(unit), { itemKey = 'auraindicators' })
        end
    end

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
            row:Button(L['Remove'], {
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
            placement.Style = value
            Changed(nil)
            Reload()
        end,
    })

    local placeRow = typeCard:Row(rowH)
    placeRow:Dropdown(L['Attach To'], {
        width = 0.5,
        options = ATTACH_OPTIONS,
        value = placement.Attach,
        callback = function(value)
            placement.Attach = value
            Changed(nil)
        end,
    })
    placeRow:Dropdown(L['Layer'], {
        width = 0.5,
        options = UF.GUILayerOptions(),
        value = placement.Layer,
        tooltip = L['Higher layers draw over lower ones. Damage absorb sits on 4 and heal absorb on 5 by default.'],
        callback = function(value)
            placement.Layer = value
            Changed(nil)
        end,
    })

    typeCard:Row(rowHL, 0):Slider(L['Alpha'], {
        width = 1,
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

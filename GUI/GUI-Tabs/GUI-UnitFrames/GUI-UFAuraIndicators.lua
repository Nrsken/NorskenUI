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
local AuraFilters = NRSKNUI.AuraFilters
local AuraCards = NRSKNUI.GUIAuraCards
local OutlineOptions = NRSKNUI:GetOutlineOptions(true)

local ipairs = ipairs
local tonumber = tonumber
local format = string.format

local PAGE = 'unitFramesIndicators'
local Styles = AuraIndicators.Styles
local MatchTypes = AuraIndicators.MatchTypes

local MATCH_TYPES = {
    { value = MatchTypes.SpellIDs, text = L['Spell IDs'] },
    { value = MatchTypes.Preset,   text = L['Preset'] },
    { value = MatchTypes.Filter,   text = L['Named Filter'] },
}

local STYLE_OPTIONS = {
    { value = Styles.Overlay,       text = L['Overlay Tint'] },
    { value = Styles.Square,        text = L['Square Texture'] },
    { value = Styles.Icon,          text = L['Aura Icon'] },
    { value = Styles.Duration,      text = L['Duration Text'] },
    { value = Styles.DispelBorder,  text = L['Dispel Border'] },
    { value = Styles.DispelOverlay, text = L['Dispel Overlay'] },
}

local ATTACH_OPTIONS = {
    { value = AuraIndicators.Attach.Frame,      text = L['Whole Frame'] },
    { value = AuraIndicators.Attach.Health,     text = L['Health Bar'] },
    { value = AuraIndicators.Attach.HealthFill, text = L['Health Fill'] },
}

local UNITS = { 'player', 'target', 'targettarget', 'focus', 'focustarget', 'pet', 'pettarget', 'boss' }

local function Store() return NRSKNUI.db.global.AuraIndicators end
local function Changed(key) AuraIndicators:Invalidate(key) end

---Layer choices. The two the frame's own chrome owns stay selectable but say so, since sharing a level
---with the border is a legitimate thing to want and hiding them would make the scale read wrong.
---@return table[]
local function LayerOptions()
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
            for _, unit in ipairs(UNITS) do
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

local function DeleteIndicatorPrompt(key)
    local spec = AuraIndicators:GetSpec(key)
    if not spec then return end

    NRSKNUI:CreatePrompt({
        title = L['Delete Indicator'],
        text = format(L["Delete the indicator '%s'? This cannot be undone."], spec.name or key),
        onAccept = function()
            for _, unit in ipairs(UNITS) do
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
    local card = page:Card(format(L['Indicator: %s'], spec.name or key))

    -- The match fields and the summary both change with the match type, so the whole card redraws.
    card:Rebuild(function(c)
        c:Row(rowH):Dropdown(L['Match Type'], {
            width = 1,
            options = MATCH_TYPES,
            value = spec.MatchType,
            callback = function(value)
                spec.MatchType = value
                Changed(key)
                c:Rebuild()
            end,
        })

        if spec.MatchType == MatchTypes.SpellIDs then
            local spellRow = c:Row(rowH)
            spellRow:EditBox(L['Spell IDs'], {
                width = 0.5,
                value = spec.SpellIDs,
                tooltip = L['One or more spell IDs, separated by commas. The indicator shows while any of them is up.'],
                callback = function(value)
                    spec.SpellIDs = value
                    Changed(key)
                    c:Rebuild()
                end,
            })
            spellRow:Dropdown(L['Aura Type'], {
                width = 0.5,
                options = AuraIndicators.AuraTypes,
                value = spec.AuraType,
                callback = function(value)
                    spec.AuraType = value
                    Changed(key)
                    c:Rebuild()
                end,
            })

            c:Separator()

            for _, id in ipairs(AuraIndicators:GetSpellIDs(spec) or {}) do
                local info = C_Spell.GetSpellInfo(id)
                local row = c:Row(26)
                local labelText = info and info.name and format('%s (%d)', info.name, id) or format(L['Unknown spell ID %d'], id)

                row:Icon({
                    width = 0.05,
                    size = 24,
                    texture = info and info.iconID,
                    tooltip = function(t)
                        t:SetSpellByID(id)
                    end
                })
                row:Text(NRSKNUI:ColorTextByTheme(labelText), {
                    yOffset = -2,
                    width = 0.95,
                    height = rowH,
                    bgMode = 'hide',
                })
            end
        elseif spec.MatchType == MatchTypes.Preset then
            c:Row(rowH):Dropdown(L['Preset'], {
                width = 1,
                options = AuraIndicators.Presets,
                value = spec.Preset,
                callback = function(value)
                    spec.Preset = value
                    Changed(key)
                    c:Rebuild()
                end,
            })
        else
            local filters = AuraFilters:GetList()
            c:Row(rowH):Dropdown(L['Filter'], {
                width = 0.7,
                searchable = true,
                options = filters,
                value = spec.Filter,
                callback = function(value)
                    spec.Filter = value
                    Changed(key)
                    c:Rebuild()
                end,
            })
            c:Row(rowH):Button(L['Manage Filters'], {
                width = 0.3,
                height = 24,
                callback = function()
                    local window = NRSKNUI.GUIFrame
                    if window and window.content then window.content:ShowPage('filterBuilder') end
                end,
            })
        end
    end)

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

GUI:RegisterPage(PAGE, {
    mode = 'clean',
    search = {},
    sidebar = {
        buttons = {
            { text = L['New Indicator'], onClick = CreateIndicatorPrompt },
        },
        items = function()
            local items = {}
            for _, entry in ipairs(AuraIndicators:GetList()) do
                items[#items + 1] = { key = entry.key, text = entry.text }
            end
            return items
        end,
        onContextMenu = function(key)
            if not AuraIndicators:Exists(key) then return end

            GUI:ShowContextMenu({
                { text = L['Rename'], onClick = function() RenameIndicatorPrompt(key) end },
                { divider = true },
                { text = L['Delete'], onClick = function() DeleteIndicatorPrompt(key) end },
            })
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

    -- With nothing placed there is no tab to derive a strip from, so the strip carries the empty state.
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
    if placement.Style == Styles.DispelBorder or placement.Style == Styles.DispelOverlay then
        card:Row(rowHL, 0):Checkbox(L['Show Without Dispel Type'], {
            width = 1,
            value = placement.ShowWithoutDispelType,
            tooltip = L['Keep the indicator up for matching auras that have no dispel type at all. The game colors these by dispel type, so the indicator color does not apply.'],
            callback = function(checked)
                placement.ShowWithoutDispelType = checked
                Changed(nil)
            end,
        })
        return
    end

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
        tooltip = L['Aura buttons are built once by the game, so a new style only appears after a reload.'],
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
        options = LayerOptions(),
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

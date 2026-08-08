---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class ActionBarsModule
local ACB = NRSKNUI:GetModule('ActionBars', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs = ipairs
local min = math.min

local PAGE = 'actionBars'
local GLOBAL = 'global'

local anchorOptions = NRSKNUI.AnchorOptions

local barList = {   
    { key = 'Bar1',      text = L['Action Bar 1'] },
    { key = 'Bar2',      text = L['Action Bar 2'] },
    { key = 'Bar3',      text = L['Action Bar 3'] },
    { key = 'Bar4',      text = L['Action Bar 4'] },
    { key = 'Bar5',      text = L['Action Bar 5'] },
    { key = 'Bar6',      text = L['Action Bar 6'] },
    { key = 'Bar7',      text = L['Action Bar 7'] },
    { key = 'Bar8',      text = L['Action Bar 8'] },
    { key = 'PetBar',    text = L['Pet Bar'] },
    { key = 'StanceBar', text = L['Stance Bar'] },
}

local layoutOptions = {
    { key = 'HORIZONTAL', text = L['Horizontal'] },
    { key = 'VERTICAL',   text = L['Vertical'] },
}

local growthOptions = {
    { key = 'RIGHT', text = L['Grow Right'] },
    { key = 'LEFT',  text = L['Grow Left'] },
}

local flyoutOptions = {
    { key = 'AUTO',  text = L['Auto'] },
    { key = 'UP',    text = L['Up'] },
    { key = 'DOWN',  text = L['Down'] },
    { key = 'LEFT',  text = L['Left'] },
    { key = 'RIGHT', text = L['Right'] },
}

local outlineOptions = {
    { key = 'NONE',         text = L['None'] },
    { key = 'OUTLINE',      text = L['Outline'] },
    { key = 'THICKOUTLINE', text = L['Thick'] },
    { key = 'SLUG',         text = L['Slug'] },
    { key = 'SLUG,OUTLINE', text = L['Slug Outline'] },
}

local function Update(updateType, barKey)
    if ACB then ACB:UpdateSettings(updateType, barKey) end
end

-- Every per-bar control feeds one of these five passes, so the bar tabs push them all.
local function ApplyBar(barKey)
    if not ACB then return end
    ACB:UpdateSettings('layout', barKey)
    ACB:UpdateSettings('positions', barKey)
    ACB:UpdateSettings('mouseover', barKey)
    ACB:UpdateSettings('backdrops', barKey)
    ACB:UpdateSettings('fonts')
end

-- Re-renders the sidebar in place so bar names dim with their Enabled state. Rebuilding the whole
-- page would release the checkbox that is still running its own callback.
local function RefreshSidebar()
    local window = NRSKNUI.GUIFrame
    local miniSidebar = window and window.content and window.content.miniSidebar
    if miniSidebar then miniSidebar:Render() end
end

local function SidebarItems()
    local items = { { key = GLOBAL, text = L['Global Settings'] } }
    for _, bar in ipairs(barList) do
        items[#items + 1] = { key = bar.key, text = bar.text }
    end

    return items
end

-- Items are pooled, so both branches always set the alpha back.
local function RenderItem(itemFrame, item)
    local bars = NRSKNUI.db and NRSKNUI.db.profile.Skinning.ActionBars.Bars
    local barDB = bars and bars[item.key]
    local enabled = not barDB or barDB.Enabled
    itemFrame.label:SetAlpha(enabled and 1 or 0.5)
end

-- Global: the master toggle and everything shared by every bar.
local function BuildGlobalPage(page, db)
    page:SetCondition('customFont', function() return not db.UseGlobalFont end)

    -- Card 1: Enable
    local enableCard = page:Card(L['Action Bars'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Action Bars Skinning'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Action Bars'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('ActionBars', checked)
            NRSKNUI:CreateReloadPrompt('Enabling/Disabling Action Bars requires a reload to take full effect.')
            page:Refresh()
        end,
    })

    -- Card 2: General
    local generalCard = page:Card(L['General Settings'], 'all')
    local textRow = generalCard:Row(rowH)
    textRow:Checkbox(L['Hide Profession Texture'], {
        width = 0.5,
        value = db.HideProfTexture,
        callback = function(checked)
            db.HideProfTexture = checked; Update('profTextures')
        end,
    })
    textRow:Checkbox(L['Hide Macro Text'], {
        width = 0.5,
        value = db.HideMacroText,
        callback = function(checked)
            db.HideMacroText = checked; Update('fonts')
        end,
    })

    local textRow2 = generalCard:Row(rowH)
    textRow2:Checkbox(L['Hide Keybind Text'], {
        width = 0.5,
        value = db.HideKeybindText,
        callback = function(checked)
            db.HideKeybindText = checked; Update('fonts')
        end,
    })
    textRow2:Checkbox(L['Hide Charge Text'], {
        width = 0.5,
        value = db.HideChargeText,
        callback = function(checked)
            db.HideChargeText = checked; Update('fonts')
        end,
    })

    generalCard:Separator()

    local overlayRow = generalCard:Row(rowHL, 0)
    overlayRow:ColorPicker(L['Range Overlay'], {
        width = 1,
        value = db.RangeOverlayColor,
        tooltip = L['Tint drawn over buttons whose action is out of range.'],
        callback = function(r, g, b, a)
            db.RangeOverlayColor = { r, g, b, a }; Update('rangeOverlay')
        end,
    })

    -- Card 3: Global Font
    -- Hand-built rather than a FontSettingsCard: the module clears every text shadow, so the
    -- premade card's shadow controls would be dead settings here.
    local fontCard = page:Card(L['Global Font Settings'], 'all')
    local overrideRow = fontCard:Row(rowH)
    overrideRow:Checkbox(L['Use Global Font'], {
        width = 1,
        value = db.UseGlobalFont,
        callback = function(checked)
            db.UseGlobalFont = checked
            Update('fonts')
            page:Refresh()
        end,
    })

    fontCard:Separator()

    local faceRow = fontCard:Row(rowH)
    faceRow:Dropdown(L['Font'], {
        width = 0.5,
        media = 'font',
        searchable = true,
        conditions = { 'customFont' },
        value = db.FontFace,
        callback = function(key)
            db.FontFace = key; Update('fonts')
        end,
    })
    faceRow:Dropdown(L['Outline'], {
        width = 0.5,
        options = outlineOptions,
        value = db.FontOutline,
        callback = function(key)
            db.FontOutline = key; Update('fonts')
        end,
    })

    fontCard:Separator()

    local sizeRow = fontCard:Row(rowH)
    sizeRow:Slider(L['Keybind Size'], {
        width = 0.5,
        min = 6,
        max = 24,
        step = 1,
        value = db.FontSizes.KeybindSize,
        callback = function(val)
            db.FontSizes.KeybindSize = val; Update('fonts')
        end,
    })
    sizeRow:Slider(L['Cooldown Size'], {
        width = 0.5,
        min = 6,
        max = 24,
        step = 1,
        value = db.FontSizes.CooldownSize,
        callback = function(val)
            db.FontSizes.CooldownSize = val; Update('fonts')
        end,
    })

    local sizeRow2 = fontCard:Row(rowHL, 0)
    sizeRow2:Slider(L['Charge Size'], {
        width = 0.5,
        min = 6,
        max = 24,
        step = 1,
        value = db.FontSizes.ChargeSize,
        callback = function(val)
            db.FontSizes.ChargeSize = val; Update('fonts')
        end,
    })
    sizeRow2:Slider(L['Macro Size'], {
        width = 0.5,
        min = 6,
        max = 24,
        step = 1,
        value = db.FontSizes.MacroSize,
        callback = function(val)
            db.FontSizes.MacroSize = val; Update('fonts')
        end,
    })

    -- Card 4: Global Mouseover
    local mouseoverCard = page:Card(L['Global Mouseover Settings'], 'all')
    local toggleRow = mouseoverCard:Row(rowH)
    toggleRow:Checkbox(L['Enable Global Mouseover'], {
        width = 0.5,
        value = db.Mouseover.Enabled,
        callback = function(checked)
            db.Mouseover.Enabled = checked; Update('all')
        end,
    })
    toggleRow:Checkbox(L['Override When Mounted/Vehicle'], {
        width = 0.5,
        value = db.MouseoverOverride,
        tooltip = L['Keeps the bar visible while an override bar is active, such as while dragonriding.'],
        callback = function(checked)
            db.MouseoverOverride = checked
            if ACB then ACB:UpdateBonusBarOverride() end
        end,
    })

    mouseoverCard:Separator()

    local alphaRow = mouseoverCard:Row(rowH)
    alphaRow:Slider(L['Fade Out Alpha'], {
        width = 1,
        min = 0,
        max = 1,
        step = 0.05,
        value = db.Mouseover.Alpha,
        callback = function(val)
            db.Mouseover.Alpha = val; Update('all')
        end,
    })

    local fadeRow = mouseoverCard:Row(rowHL, 0)
    fadeRow:Slider(L['Fade In Duration'], {
        width = 0.5,
        min = 0,
        max = 2,
        step = 0.1,
        value = db.Mouseover.FadeInDuration,
        callback = function(val)
            db.Mouseover.FadeInDuration = val; Update('all')
        end,
    })
    fadeRow:Slider(L['Fade Out Duration'], {
        width = 0.5,
        min = 0,
        max = 2,
        step = 0.1,
        value = db.Mouseover.FadeOutDuration,
        callback = function(val)
            db.Mouseover.FadeOutDuration = val; Update('all')
        end,
    })

    -- Card 5: Bar toggles
    local barsCard = page:Card(L['Bar Enable/Disable'], 'all')
    for i = 1, #barList, 2 do
        local last = i + 2 > #barList
        local row = barsCard:Row(last and rowHL or rowH, last and 0 or nil)

        for index = i, min(i + 1, #barList) do
            local bar = barList[index]
            row:Checkbox(bar.text, {
                width = 0.5,
                value = db.Bars[bar.key].Enabled,
                callback = function(checked)
                    db.Bars[bar.key].Enabled = checked
                    Update('enabled', bar.key)
                    if checked then
                        NRSKNUI:CreateReloadPrompt('Enabling bars requires a reload to take full effect.')
                    end
                    RefreshSidebar()
                end,
            })
        end
    end
end

-- Bar Layout Tab.
local function BuildBarLayoutTab(page, db, barKey, barDB)
    page:SetCondition('bar', function() return barDB.Enabled end)
    page:SetCondition('perBarMouseover', function() return not barDB.Mouseover.GlobalOverride end)
    page:SetCondition('perBarMouseoverOn', function()
        return not barDB.Mouseover.GlobalOverride and barDB.Mouseover.Enabled
    end)

    -- Card 1: Enable
    local enableCard = page:Card(L['Bar'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Bar'], {
        width = 1,
        master = true,
        value = barDB.Enabled,
        callback = function(checked)
            barDB.Enabled = checked
            Update('enabled', barKey)
            if checked then
                NRSKNUI:CreateReloadPrompt('Enabling bars requires a reload to take full effect.')
            end
            RefreshSidebar()
            page:Refresh()
        end,
    })

    -- Card 2: Layout
    local layoutCard = page:Card(L['Layout'], 'bar')
    local sizeRow = layoutCard:Row(rowH)
    sizeRow:Slider(L['Button Size'], {
        width = 0.5,
        min = 20,
        max = 80,
        step = 1,
        value = barDB.ButtonSize,
        callback = function(val)
            barDB.ButtonSize = val; ApplyBar(barKey)
        end,
    })
    sizeRow:Slider(L['Spacing'], {
        width = 0.5,
        min = -10,
        max = 20,
        step = 1,
        value = barDB.Spacing,
        callback = function(val)
            barDB.Spacing = val; ApplyBar(barKey)
        end,
    })

    local countRow = layoutCard:Row(rowH)
    countRow:Slider(L['Total Buttons'], {
        width = 0.5,
        min = 1,
        max = 12,
        step = 1,
        value = barDB.TotalButtons,
        callback = function(val)
            barDB.TotalButtons = val; ApplyBar(barKey)
        end,
    })
    countRow:Slider(L['Buttons Per Line'], {
        width = 0.5,
        min = 1,
        max = 12,
        step = 1,
        value = barDB.ButtonsPerLine,
        callback = function(val)
            barDB.ButtonsPerLine = val; ApplyBar(barKey)
        end,
    })

    local isActionBar = barKey:match('^Bar%d$') ~= nil
    local directionRow = layoutCard:Row(isActionBar and rowH or rowHL, not isActionBar and 0 or nil)
    directionRow:Dropdown(L['Layout Direction'], {
        width = 0.5,
        options = layoutOptions,
        value = barDB.Layout,
        callback = function(key)
            barDB.Layout = key; ApplyBar(barKey)
        end,
    })
    directionRow:Dropdown(L['Growth Direction'], {
        width = 0.5,
        options = growthOptions,
        value = barDB.GrowthDirection,
        callback = function(key)
            barDB.GrowthDirection = key; ApplyBar(barKey)
        end,
    })

    if isActionBar then
        local flyoutRow = layoutCard:Row(rowHL, 0)
        flyoutRow:Dropdown(L['Flyout Direction'], {
            width = 1,
            options = flyoutOptions,
            value = barDB.FlyoutDirection,
            callback = function(key)
                barDB.FlyoutDirection = key; Update('flyout', barKey)
            end,
        })
    end

    -- Card 3: Position
    local positionCard = page:Card(L['Position'], 'bar')
    local anchorRow = positionCard:Row(rowH)
    anchorRow:Dropdown(L['Screen Anchor'], {
        width = 1,
        options = anchorOptions,
        value = barDB.Position.AnchorPoint,
        callback = function(key)
            barDB.Position.AnchorPoint = key; ApplyBar(barKey)
        end,
    })

    positionCard:Separator()

    local offsetRow = positionCard:Row(rowHL, 0)
    offsetRow:Slider(L['X Offset'], {
        width = 0.5,
        min = -2000,
        max = 2000,
        step = 1,
        value = barDB.Position.XOffset,
        callback = function(val)
            barDB.Position.XOffset = val; ApplyBar(barKey)
        end,
    })
    offsetRow:Slider(L['Y Offset'], {
        width = 0.5,
        min = -2000,
        max = 2000,
        step = 1,
        value = barDB.Position.YOffset,
        callback = function(val)
            barDB.Position.YOffset = val; ApplyBar(barKey)
        end,
    })

    -- Card 4: Mouseover
    local mouseoverCard = page:Card(L['Mouseover'], 'bar')
    local toggleRow = mouseoverCard:Row(rowH)
    toggleRow:Checkbox(L['Use Global Mouseover Settings'], {
        width = 0.5,
        value = barDB.Mouseover.GlobalOverride,
        callback = function(checked)
            barDB.Mouseover.GlobalOverride = checked
            ApplyBar(barKey)
            page:Refresh()
        end,
    })
    toggleRow:Checkbox(L['Enable Mouseover'], {
        width = 0.5,
        conditions = { 'perBarMouseover' },
        value = barDB.Mouseover.Enabled,
        callback = function(checked)
            barDB.Mouseover.Enabled = checked
            ApplyBar(barKey)
            page:Refresh()
        end,
    })

    mouseoverCard:Separator()

    local alphaRow = mouseoverCard:Row(rowHL, 0)
    alphaRow:Slider(L['Fade Out Alpha'], {
        width = 1,
        conditions = { 'perBarMouseoverOn' },
        min = 0,
        max = 1,
        step = 0.05,
        value = barDB.Mouseover.Alpha,
        callback = function(val)
            barDB.Mouseover.Alpha = val; ApplyBar(barKey)
        end,
    })
end

-- Bar Texts Tab.
local function BuildBarTextsTab(page, db, barKey, barDB)
    page:SetCondition('bar', function() return barDB.Enabled end)
    page:SetCondition('customSizes', function() return not barDB.FontSizes.GlobalOverride end)
    page:SetCondition('customPositions', function() return not barDB.TextPositions.GlobalOverride end)
    page:SetCondition('customVisibility', function() return not barDB.TextVisibility.GlobalOverride end)

    -- Card 1: Font Sizes
    local sizeCard = page:Card(L['Font Sizes'], 'bar')
    local overrideRow = sizeCard:Row(rowH)
    overrideRow:Checkbox(L['Use Global Font Sizes'], {
        width = 1,
        value = barDB.FontSizes.GlobalOverride,
        callback = function(checked)
            barDB.FontSizes.GlobalOverride = checked
            ApplyBar(barKey)
            page:Refresh()
        end,
    })

    sizeCard:Separator()

    local sizeRow = sizeCard:Row(rowH)
    sizeRow:Slider(L['Keybind Size'], {
        width = 0.5,
        conditions = { 'customSizes' },
        min = 6,
        max = 24,
        step = 1,
        value = barDB.FontSizes.KeybindSize,
        callback = function(val)
            barDB.FontSizes.KeybindSize = val; ApplyBar(barKey)
        end,
    })
    sizeRow:Slider(L['Cooldown Size'], {
        width = 0.5,
        conditions = { 'customSizes' },
        min = 6,
        max = 24,
        step = 1,
        value = barDB.FontSizes.CooldownSize,
        callback = function(val)
            barDB.FontSizes.CooldownSize = val; ApplyBar(barKey)
        end,
    })

    local sizeRow2 = sizeCard:Row(rowHL, 0)
    sizeRow2:Slider(L['Charge Size'], {
        width = 0.5,
        conditions = { 'customSizes' },
        min = 6,
        max = 24,
        step = 1,
        value = barDB.FontSizes.ChargeSize,
        callback = function(val)
            barDB.FontSizes.ChargeSize = val; ApplyBar(barKey)
        end,
    })
    sizeRow2:Slider(L['Macro Size'], {
        width = 0.5,
        conditions = { 'customSizes' },
        min = 6,
        max = 24,
        step = 1,
        value = barDB.FontSizes.MacroSize,
        callback = function(val)
            barDB.FontSizes.MacroSize = val; ApplyBar(barKey)
        end,
    })

    -- Card 2: Text Positions
    local positionCard = page:Card(L['Text Positions'], 'bar')
    local positionOverrideRow = positionCard:Row(rowH)
    positionOverrideRow:Checkbox(L['Use Global Text Positions'], {
        width = 1,
        value = barDB.TextPositions.GlobalOverride,
        callback = function(checked)
            barDB.TextPositions.GlobalOverride = checked
            ApplyBar(barKey)
            page:Refresh()
        end,
    })

    local texts = {
        { label = L['Keybind Anchor'], anchor = 'KeybindAnchor', x = 'KeybindXOffset', y = 'KeybindYOffset' },
        { label = L['Charge Anchor'],  anchor = 'ChargeAnchor',  x = 'ChargeXOffset',  y = 'ChargeYOffset' },
        { label = L['Macro Anchor'],   anchor = 'MacroAnchor',   x = 'MacroXOffset',   y = 'MacroYOffset' },
    }

    for index, text in ipairs(texts) do
        positionCard:Separator()

        local last = index == #texts
        local row = positionCard:Row(last and rowHL or rowH, last and 0 or nil)
        row:Dropdown(text.label, {
            width = 0.34,
            conditions = { 'customPositions' },
            options = anchorOptions,
            value = barDB.TextPositions[text.anchor],
            callback = function(key)
                barDB.TextPositions[text.anchor] = key; ApplyBar(barKey)
            end,
        })
        row:Slider(L['X'], {
            width = 0.33,
            conditions = { 'customPositions' },
            min = -20,
            max = 20,
            step = 1,
            value = barDB.TextPositions[text.x],
            callback = function(val)
                barDB.TextPositions[text.x] = val; ApplyBar(barKey)
            end,
        })
        row:Slider(L['Y'], {
            width = 0.33,
            conditions = { 'customPositions' },
            min = -20,
            max = 20,
            step = 1,
            value = barDB.TextPositions[text.y],
            callback = function(val)
                barDB.TextPositions[text.y] = val; ApplyBar(barKey)
            end,
        })
    end

    -- Card 3: Text Visibility
    local visibilityCard = page:Card(L['Text Visibility'], 'bar')
    local visibilityOverrideRow = visibilityCard:Row(rowH)
    visibilityOverrideRow:Checkbox(L['Use Global Text Visibility'], {
        width = 1,
        value = barDB.TextVisibility.GlobalOverride,
        callback = function(checked)
            barDB.TextVisibility.GlobalOverride = checked
            ApplyBar(barKey)
            page:Refresh()
        end,
    })

    visibilityCard:Separator()

    local visibilityRow = visibilityCard:Row(rowH)
    visibilityRow:Checkbox(L['Hide Keybind Text'], {
        width = 0.5,
        conditions = { 'customVisibility' },
        value = barDB.TextVisibility.HideKeybindText,
        callback = function(checked)
            barDB.TextVisibility.HideKeybindText = checked; ApplyBar(barKey)
        end,
    })
    visibilityRow:Checkbox(L['Hide Macro Text'], {
        width = 0.5,
        conditions = { 'customVisibility' },
        value = barDB.TextVisibility.HideMacroText,
        callback = function(checked)
            barDB.TextVisibility.HideMacroText = checked; ApplyBar(barKey)
        end,
    })

    local visibilityRow2 = visibilityCard:Row(rowHL, 0)
    visibilityRow2:Checkbox(L['Hide Charge Text'], {
        width = 0.5,
        conditions = { 'customVisibility' },
        value = barDB.TextVisibility.HideChargeText,
        callback = function(checked)
            barDB.TextVisibility.HideChargeText = checked; ApplyBar(barKey)
        end,
    })
    visibilityRow2:Checkbox(L['Hide Profession Texture'], {
        width = 0.5,
        conditions = { 'customVisibility' },
        value = barDB.TextVisibility.HideProfTexture,
        callback = function(checked)
            barDB.TextVisibility.HideProfTexture = checked; Update('profTextures')
        end,
    })
end

-- Bar Style Tab.
local function BuildBarStyleTab(page, db, barKey, barDB)
    page:SetCondition('bar', function() return barDB.Enabled end)

    local backdropCard = page:Card(L['Backdrop'], 'bar')
    local hideRow = backdropCard:Row(rowH)
    hideRow:Checkbox(L['Hide Empty Backdrops'], {
        width = 1,
        value = barDB.HideEmptyBackdrops,
        tooltip = L['Hides the backdrop behind buttons that hold no action.'],
        callback = function(checked)
            barDB.HideEmptyBackdrops = checked; ApplyBar(barKey)
        end,
    })

    backdropCard:Separator()

    local colorRow = backdropCard:Row(rowHL, 0)
    colorRow:ColorPicker(L['Backdrop Color'], {
        width = 0.5,
        value = barDB.BackdropColor,
        callback = function(r, g, b, a)
            barDB.BackdropColor = { r, g, b, a }; ApplyBar(barKey)
        end,
    })
    colorRow:ColorPicker(L['Border Color'], {
        width = 0.5,
        value = barDB.BorderColor,
        callback = function(r, g, b, a)
            barDB.BorderColor = { r, g, b, a }; ApplyBar(barKey)
        end,
    })
end

GUI:RegisterPage(PAGE, {
    mode = 'tabs',
    search = {},
    sidebar = {
        items = SidebarItems,
        renderItem = RenderItem,
        default = GLOBAL,
    },
    tabs = function(itemKey)
        if itemKey == GLOBAL then return {} end

        return {
            { id = 'layout', text = L['Layout'] },
            { id = 'texts',  text = L['Texts'] },
            { id = 'style',  text = L['Style'] },
        }
    end,
    build = function(page, tabId, itemKey)
        local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.ActionBars
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if itemKey == GLOBAL then return BuildGlobalPage(page, db) end

        local barDB = db.Bars[itemKey]
        if not barDB then return end

        if tabId == 'layout' then
            BuildBarLayoutTab(page, db, itemKey, barDB)
        elseif tabId == 'texts' then
            BuildBarTextsTab(page, db, itemKey, barDB)
        elseif tabId == 'style' then
            BuildBarStyleTab(page, db, itemKey, barDB)
        end
    end,
})

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs = ipairs
local format = string.format

local function ApplySettings() UF:ApplySettings() end

local UNIT_LABELS = {
    player = L['Player'],
    target = L['Target'],
    targettarget = L['Target of Target'],
    focus = L['Focus'],
    focustarget = L['Focus Target'],
    pet = L['Pet'],
    pettarget = L['Pet Target'],
}

local NO_POWER = { targettarget = true, focustarget = true, pettarget = true }

local AnchorOptions = {}
for _, point in ipairs({ 'TOPLEFT', 'TOP', 'TOPRIGHT', 'LEFT', 'CENTER', 'RIGHT', 'BOTTOMLEFT', 'BOTTOM', 'BOTTOMRIGHT' }) do
    AnchorOptions[#AnchorOptions + 1] = { value = point, text = point }
end

local OutlineOptions = {
    { value = 'NONE',               text = L['None'] },
    { value = 'OUTLINE',            text = L['Outline'] },
    { value = 'THICKOUTLINE',       text = L['Thick Outline'] },
    { value = 'MONOCHROME,OUTLINE', text = L['Mono Outline'] },
}

local TAG_SLOTS = { 'TagOne', 'TagTwo', 'TagThree', 'TagFour', 'TagFive' }

local TagInsertOptions = {
    { value = '[nrsknuf:name]',                text = L['Name'] },
    { value = '[nrsknuf:unit:smartcolor]',     text = L['Smart Color'] },
    { value = '[nrsknuf:curhp:perhp]',         text = L['Health + Percent'] },
    { value = '[nrsknuf:perpower:smartcolor]', text = L['Power Percent (Colored)'] },
    { value = '[curhp]',                       text = L['Current Health'] },
    { value = '[perhp]',                       text = L['Health Percent'] },
    { value = '[curpp]',                       text = L['Current Power'] },
    { value = '[perpp]',                       text = L['Power Percent'] },
}

local IndicatorOptions = {
    { value = 'Resting',    text = L['Resting'] },
    { value = 'Combat',     text = L['Combat'] },
    { value = 'ReadyCheck', text = L['Ready Check'] },
    { value = 'Summon',     text = L['Summon'] },
    { value = 'Resurrect',  text = L['Resurrect'] },
    { value = 'Quest',      text = L['Quest'] },
    { value = 'PvP',        text = L['PvP'] },
    { value = 'Phase',      text = L['Phase'] },
}

local function AddPositionRows(card, slotDB, conditions, lastSpacing)
    local anchorRow = card:Row(rowH)
    anchorRow:Dropdown(L['Anchor From'], {
        width = 0.5,
        conditions = conditions,
        options = AnchorOptions,
        value = slotDB.Position.AnchorFrom,
        callback = function(key)
            slotDB.Position.AnchorFrom = key; ApplySettings()
        end,
    })
    anchorRow:Dropdown(L['Anchor To'], {
        width = 0.5,
        conditions = conditions,
        options = AnchorOptions,
        value = slotDB.Position.AnchorTo,
        callback = function(key)
            slotDB.Position.AnchorTo = key; ApplySettings()
        end,
    })

    local offsetRow = card:Row(rowHL, lastSpacing or 0)
    offsetRow:Slider(L['X Offset'], {
        width = 0.5,
        conditions = conditions,
        min = -200,
        max = 200,
        step = 1,
        value = slotDB.Position.XOffset,
        callback = function(val)
            slotDB.Position.XOffset = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })
    offsetRow:Slider(L['Y Offset'], {
        width = 0.5,
        conditions = conditions,
        min = -200,
        max = 200,
        step = 1,
        value = slotDB.Position.YOffset,
        callback = function(val)
            slotDB.Position.YOffset = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })
end

-- Checkbox + gated dropdown for a nil-able per-element texture override.
local function AddTextureOverrideRow(page, row, elementDB, condName, conditions)
    page:SetCondition(condName, function() return elementDB.StatusBarTexture ~= nil end)

    row:Checkbox(L['Override Texture'], {
        width = 0.5,
        conditions = conditions,
        value = elementDB.StatusBarTexture ~= nil,
        callback = function(checked)
            elementDB.StatusBarTexture = checked and NRSKNUI.db.profile.UnitFrames.General.statusBar or nil
            ApplySettings()
            page:Refresh()
        end,
    })

    local dropConditions = { condName }
    for _, condition in ipairs(conditions or {}) do dropConditions[#dropConditions + 1] = condition end
    row:Dropdown(L['Texture'], {
        width = 0.5,
        media = 'statusbar',
        searchable = true,
        conditions = dropConditions,
        value = elementDB.StatusBarTexture or NRSKNUI.db.profile.UnitFrames.General.statusBar,
        callback = function(key)
            elementDB.StatusBarTexture = key
            ApplySettings()
        end,
    })
end

local function BuildFrameSection(page, uDB, unit)
    -- Card 1: Enable
    local enableCard = page:Card(UNIT_LABELS[unit], 'all')
    enableCard:Row(rowHL, 0):Checkbox(L['Enable'], {
        width = 1,
        value = uDB.Enabled,
        callback = function(checked)
            uDB.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    -- Card 2: Size
    local sizeCard = page:Card(L['Size'], 'unitOn')
    local sizeRow = sizeCard:Row(rowHL, 0)
    sizeRow:Slider(L['Width'], {
        width = 0.5,
        min = 40,
        max = 400,
        step = 1,
        value = uDB.Width,
        callback = function(val)
            uDB.Width = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })
    sizeRow:Slider(L['Height'], {
        width = 0.5,
        min = 10,
        max = 150,
        step = 1,
        value = uDB.Height,
        callback = function(val)
            uDB.Height = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })

    -- Card 3: Position
    page:PositionCard({
        db = uDB,
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = ApplySettings,
    }, 'unitOn')
end

local function BuildHealthSection(page, uDB, unit)
    local hDB = uDB.Health
    page:SetCondition('ownHealthColors', function() return not hDB.UseGlobalColors end)
    page:SetCondition('ownHealthBg', function() return hDB.BackgroundTexture ~= '' end)
    page:SetCondition('ownHealthSmooth', function() return not hDB.UseGlobalSmooth end)
    page:SetCondition('ownHealAbsorb', function() return not hDB.HealAbsorb.UseGlobal end)
    page:SetCondition('ownDamageAbsorb', function() return not hDB.DamageAbsorb.UseGlobal end)

    -- Card 1: Health
    local healthCard = page:Card(L['Health'], 'unitOn')
    local healthRow = healthCard:Row(rowH)
    healthRow:Checkbox(L['Use Global Smoothing'], {
        width = 0.5,
        tooltip = L['Follow the smoothing setting from the general settings.'],
        value = hDB.UseGlobalSmooth,
        callback = function(checked)
            hDB.UseGlobalSmooth = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    healthRow:Checkbox(L['Smooth'], {
        width = 0.5,
        conditions = { 'ownHealthSmooth' },
        value = hDB.Smooth,
        callback = function(checked)
            hDB.Smooth = checked; ApplySettings()
        end,
    })
    healthCard:Row(rowHL, 0):Checkbox(L['Inverse Fill'], {
        width = 0.5,
        value = hDB.Inverse,
        callback = function(checked)
            hDB.Inverse = checked; ApplySettings()
        end,
    })

    -- Card 2: Colors
    local colorCard = page:Card(L['Colors'], 'unitOn')
    local modeRow = colorCard:Row(rowH)
    modeRow:Checkbox(L['Use Global Colors'], {
        width = 0.5,
        value = hDB.UseGlobalColors,
        callback = function(checked)
            hDB.UseGlobalColors = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    modeRow:Checkbox(L['Class Colored Health'], {
        width = 0.5,
        conditions = { 'ownHealthColors' },
        value = hDB.ColorByClass,
        callback = function(checked)
            hDB.ColorByClass = checked; ApplySettings()
        end,
    })
    local fgRow = colorCard:Row(rowH)
    fgRow:ColorPicker(L['Foreground'], {
        width = 0.5,
        conditions = { 'ownHealthColors' },
        value = hDB.Foreground,
        callback = function(r, g, b, a)
            hDB.Foreground = { r, g, b, a }
            ApplySettings()
        end,
    })
    fgRow:Slider(L['Class Color Alpha'], {
        width = 0.5,
        conditions = { 'ownHealthColors' },
        min = 0,
        max = 1,
        step = 0.05,
        value = hDB.ForegroundAlphaWhenColorByClass,
        callback = function(val)
            hDB.ForegroundAlphaWhenColorByClass = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })
    local bgRow = colorCard:Row(rowHL, 0)
    bgRow:ColorPicker(L['Background'], {
        width = 0.5,
        conditions = { 'ownHealthColors' },
        value = hDB.Background,
        callback = function(r, g, b, a)
            hDB.Background = { r, g, b, a }
            ApplySettings()
        end,
    })
    bgRow:ColorPicker(L['Background (Class Colored)'], {
        width = 0.5,
        conditions = { 'ownHealthColors' },
        value = hDB.BackgroundWhenColorByClass,
        callback = function(r, g, b, a)
            hDB.BackgroundWhenColorByClass = { r, g, b, a }
            ApplySettings()
        end,
    })

    -- Card 3: Textures
    local textureCard = page:Card(L['Textures'], 'unitOn')
    AddTextureOverrideRow(page, textureCard:Row(rowH), hDB, 'ownHealthTexture', nil)
    local bgTexRow = textureCard:Row(rowHL, 0)
    bgTexRow:Checkbox(L['Match Foreground'], {
        width = 0.5,
        tooltip = L['Use the foreground texture for the missing-health background.'],
        value = hDB.BackgroundTexture == '',
        callback = function(checked)
            hDB.BackgroundTexture = checked and '' or NRSKNUI.db.profile.UnitFrames.General.statusBar
            ApplySettings()
            page:Refresh()
        end,
    })
    bgTexRow:Dropdown(L['Background Texture'], {
        width = 0.5,
        media = 'statusbar',
        searchable = true,
        conditions = { 'ownHealthBg' },
        value = hDB.BackgroundTexture ~= '' and hDB.BackgroundTexture or NRSKNUI.db.profile.UnitFrames.General.statusBar,
        callback = function(key)
            hDB.BackgroundTexture = key
            ApplySettings()
        end,
    })

    -- Card 4/5: one card per absorb, each with its own global-or-override toggle.
    local absorbSlots = {
        { db = hDB.HealAbsorb,   title = L['Heal Absorb'],   label = L['Enable Heal Absorb'],   cond = 'ownHealAbsorb',   onCond = 'healAbsorbOn' },
        { db = hDB.DamageAbsorb, title = L['Damage Absorb'], label = L['Enable Damage Absorb'], cond = 'ownDamageAbsorb', onCond = 'damageAbsorbOn' },
    }
    for _, slot in ipairs(absorbSlots) do
        page:SetCondition(slot.onCond, function() return not slot.db.UseGlobal and slot.db.Enabled end)

        local card = page:Card(slot.title, 'unitOn')
        local headRow = card:Row(rowH)
        headRow:Checkbox(L['Use Global Settings'], {
            width = 0.5,
            tooltip = L['Follow the shared absorb settings from the general settings.'],
            value = slot.db.UseGlobal,
            callback = function(checked)
                slot.db.UseGlobal = checked
                ApplySettings()
                page:Refresh()
            end,
        })
        headRow:Checkbox(slot.label, {
            width = 0.5,
            conditions = { slot.cond },
            value = slot.db.Enabled,
            callback = function(checked)
                slot.db.Enabled = checked
                ApplySettings()
                page:Refresh()
            end,
        })

        local overrideRow = card:Row(rowHL, 0)
        overrideRow:Dropdown(L['Texture'], {
            width = 0.5,
            media = 'statusbar',
            searchable = true,
            conditions = { slot.onCond },
            value = slot.db.StatusBarTexture,
            callback = function(key)
                slot.db.StatusBarTexture = key
                ApplySettings()
            end,
        })
        overrideRow:ColorPicker(L['Color'], {
            width = 0.5,
            conditions = { slot.onCond },
            value = slot.db.Color,
            callback = function(r, g, b, a)
                slot.db.Color = { r, g, b, a }
                ApplySettings()
            end,
        })
    end
end

local function BuildPowerSection(page, uDB, unit)
    local pDB = uDB.Power
    page:SetCondition('powerOn', function() return pDB.Enabled end)
    page:SetCondition('ownPowerSmooth', function() return not pDB.UseGlobalSmooth end)
    page:SetCondition('ownPowerColors', function() return not pDB.UseGlobalColors end)
    page:SetCondition('powerFlatColor', function() return not pDB.UseGlobalColors and not pDB.ColorByPower end)

    -- Card 1: Power
    local powerCard = page:Card(L['Power'], 'unitOn')
    local enableRow = powerCard:Row(rowH)
    enableRow:Checkbox(L['Enable Power Bar'], {
        width = 0.5,
        value = pDB.Enabled,
        callback = function(checked)
            pDB.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    enableRow:Slider(L['Height'], {
        width = 0.5,
        conditions = { 'powerOn' },
        min = 1,
        max = 30,
        step = 1,
        value = pDB.Height,
        callback = function(val)
            pDB.Height = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })

    local smoothRow = powerCard:Row(rowH)
    smoothRow:Checkbox(L['Use Global Smoothing'], {
        width = 0.5,
        tooltip = L['Follow the smoothing setting from the general settings.'],
        conditions = { 'powerOn' },
        value = pDB.UseGlobalSmooth,
        callback = function(checked)
            pDB.UseGlobalSmooth = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    smoothRow:Checkbox(L['Smooth'], {
        width = 0.5,
        tooltip = L['Power smoothing only applies to the player frame.'],
        conditions = { 'powerOn', 'ownPowerSmooth' },
        value = pDB.Smooth,
        callback = function(checked)
            pDB.Smooth = checked; ApplySettings()
        end,
    })

    AddTextureOverrideRow(page, powerCard:Row(rowHL, 0), pDB, 'ownPowerTexture', { 'powerOn' })

    -- Card 2: Colors
    local colorCard = page:Card(L['Colors'], 'unitOn')
    local modeRow = colorCard:Row(rowH)
    modeRow:Checkbox(L['Use Global Colors'], {
        width = 0.5,
        conditions = { 'powerOn' },
        value = pDB.UseGlobalColors,
        callback = function(checked)
            pDB.UseGlobalColors = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    modeRow:Checkbox(L['Color By Power Type'], {
        width = 0.5,
        tooltip = L['Color the bar by the power type (mana, rage, energy...). Uncheck to use a flat color.'],
        conditions = { 'powerOn', 'ownPowerColors' },
        value = pDB.ColorByPower,
        callback = function(checked)
            pDB.ColorByPower = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    colorCard:Row(rowHL, 0):ColorPicker(L['Power Color'], {
        width = 0.5,
        conditions = { 'powerOn', 'powerFlatColor' },
        value = pDB.Color,
        callback = function(r, g, b, a)
            pDB.Color = { r, g, b, a }
            ApplySettings()
        end,
    })
end

local function BuildCastbarSection(page, uDB, unit)
    local cDB = uDB.Castbar
    page:SetCondition('castbarOn', function() return cDB.Enabled end)
    page:SetCondition('ownCastbarColors', function() return not cDB.UseGlobalColors end)

    -- Card 1: Castbar
    local castbarCard = page:Card(L['Castbar'], 'unitOn')
    local enableRow = castbarCard:Row(rowH)
    enableRow:Checkbox(L['Enable Castbar'], {
        width = 0.5,
        value = cDB.Enabled,
        callback = function(checked)
            cDB.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    enableRow:Slider(L['Height'], {
        width = 0.5,
        conditions = { 'castbarOn' },
        min = 10,
        max = 60,
        step = 1,
        value = cDB.Height,
        callback = function(val)
            cDB.Height = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })

    local showRow = castbarCard:Row(rowH)
    showRow:Checkbox(L['Show Icon'], {
        width = 0.5,
        conditions = { 'castbarOn' },
        value = cDB.ShowIcon,
        callback = function(checked)
            cDB.ShowIcon = checked; ApplySettings()
        end,
    })
    showRow:Checkbox(L['Show Spell Name'], {
        width = 0.5,
        conditions = { 'castbarOn' },
        value = cDB.ShowSpellName,
        callback = function(checked)
            cDB.ShowSpellName = checked; ApplySettings()
        end,
    })

    local holdRow = castbarCard:Row(rowH)
    holdRow:Checkbox(L['Show Cast Time'], {
        width = 0.5,
        conditions = { 'castbarOn' },
        value = cDB.ShowTime,
        callback = function(checked)
            cDB.ShowTime = checked; ApplySettings()
        end,
    })
    holdRow:Slider(L['Hold After Interrupt'], {
        width = 0.5,
        conditions = { 'castbarOn' },
        tooltip = L['Seconds the bar lingers after an interrupted or failed cast. Completed casts always hide immediately.'],
        min = 0,
        max = 2,
        step = 0.1,
        value = cDB.TimeToHold,
        callback = function(val)
            cDB.TimeToHold = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })

    AddTextureOverrideRow(page, castbarCard:Row(rowHL, 0), cDB, 'ownCastbarTexture', { 'castbarOn' })

    -- Card 2: Colors
    local colorCard = page:Card(L['Colors'], 'unitOn')
    local modeRow = colorCard:Row(rowH)
    modeRow:Checkbox(L['Use Global Colors'], {
        width = 0.5,
        conditions = { 'castbarOn' },
        value = cDB.UseGlobalColors,
        callback = function(checked)
            cDB.UseGlobalColors = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    modeRow:Checkbox(L['Class Colored Castbar'], {
        width = 0.5,
        conditions = { 'castbarOn', 'ownCastbarColors' },
        value = cDB.ColorByClass,
        callback = function(checked)
            cDB.ColorByClass = checked; ApplySettings()
        end,
    })
    local castColorRow = colorCard:Row(rowH)
    castColorRow:ColorPicker(L['Castbar Color'], {
        width = 0.5,
        conditions = { 'castbarOn', 'ownCastbarColors' },
        value = cDB.Color,
        callback = function(r, g, b, a)
            cDB.Color = { r, g, b, a }
            ApplySettings()
        end,
    })
    castColorRow:ColorPicker(L['Non-Interruptible'], {
        width = 0.5,
        conditions = { 'castbarOn', 'ownCastbarColors' },
        value = cDB.NonInterruptibleColor,
        callback = function(r, g, b, a)
            cDB.NonInterruptibleColor = { r, g, b, a }
            ApplySettings()
        end,
    })
    local stateRow = colorCard:Row(rowHL, 0)
    stateRow:ColorPicker(L['Interrupted / Failed'], {
        width = 0.5,
        conditions = { 'castbarOn', 'ownCastbarColors' },
        value = cDB.FailColor,
        callback = function(r, g, b, a)
            cDB.FailColor = { r, g, b, a }
            ApplySettings()
        end,
    })
    stateRow:ColorPicker(L['Background'], {
        width = 0.5,
        conditions = { 'castbarOn', 'ownCastbarColors' },
        value = cDB.Background,
        callback = function(r, g, b, a)
            cDB.Background = { r, g, b, a }
            ApplySettings()
        end,
    })

    -- Card 3: Safe Zone. Its own override, independent of the colour group.
    page:SetCondition('ownSafeZone', function() return not cDB.SafeZone.UseGlobal end)
    page:SetCondition('safeZoneOn', function() return not cDB.SafeZone.UseGlobal and cDB.SafeZone.Enabled end)
    local safeZoneCard = page:Card(L['Safe Zone'], 'unitOn')
    local safeZoneRow = safeZoneCard:Row(rowH)
    safeZoneRow:Checkbox(L['Use Global Settings'], {
        width = 0.5,
        tooltip = L['Follow the safe zone settings from the general settings.'],
        conditions = { 'castbarOn' },
        value = cDB.SafeZone.UseGlobal,
        callback = function(checked)
            cDB.SafeZone.UseGlobal = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    safeZoneRow:Checkbox(L['Enable Safe Zone'], {
        width = 0.5,
        tooltip = L['Shows your latency at the end of the cast, on the player frame only.'],
        conditions = { 'castbarOn', 'ownSafeZone' },
        value = cDB.SafeZone.Enabled,
        callback = function(checked)
            cDB.SafeZone.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    safeZoneCard:Row(rowHL, 0):ColorPicker(L['Safe Zone Color'], {
        width = 0.5,
        conditions = { 'castbarOn', 'safeZoneOn' },
        value = cDB.SafeZone.Color,
        callback = function(r, g, b, a)
            cDB.SafeZone.Color = { r, g, b, a }
            ApplySettings()
        end,
    })

    -- Card 3: Position
    local posCard = page:Card(L['Position Settings'], 'unitOn')
    local posRow = posCard:Row(rowHL, 0)
    posRow:Slider(L['X Offset'], {
        width = 0.5,
        conditions = { 'castbarOn' },
        min = -200,
        max = 200,
        step = 1,
        value = cDB.Position.XOffset,
        callback = function(val)
            cDB.Position.XOffset = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })
    posRow:Slider(L['Y Offset'], {
        width = 0.5,
        conditions = { 'castbarOn' },
        min = -200,
        max = 200,
        step = 1,
        value = cDB.Position.YOffset,
        callback = function(val)
            cDB.Position.YOffset = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })
end

local function BuildTagsSection(page, uDB, unit)
    local selected = 'TagOne'
    page:SetCondition('tagOn', function() return uDB.Tags[selected].Enabled end)
    page:SetCondition('tagOwnFont', function() return not uDB.Tags[selected].UseGlobalFont end)

    local card = page:Card(L['Tags'], 'unitOn')
    card:Rebuild(function(card)
        local slotDB = uDB.Tags[selected]

        local switchRow = card:Row(rowH)
        for i, name in ipairs(TAG_SLOTS) do
            local btn = switchRow:Button(format('%s %d', L['Tag'], i), {
                width = 0.2,
                callback = function()
                    selected = name
                    card:Rebuild()
                end,
            })
            if name == selected then
                btn.text:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3], 1)
            end
        end

        card:Separator()

        local headRow = card:Row(rowH)
        headRow:Checkbox(L['Enable'], {
            width = 0.5,
            value = slotDB.Enabled,
            callback = function(checked)
                slotDB.Enabled = checked
                ApplySettings()
                page:Refresh()
            end,
        })
        headRow:ColorPicker(L['Color'], {
            width = 0.5,
            conditions = { 'tagOn' },
            value = slotDB.Color,
            callback = function(r, g, b)
                slotDB.Color = { r, g, b }
                ApplySettings()
            end,
        })

        card:Row(rowH):EditBox(L['Tag Text'], {
            width = 1,
            conditions = { 'tagOn' },
            tooltip = L['Any oUF tag string, e.g. [nrsknuf:name] or [perhp]%.'],
            value = slotDB.Tag,
            callback = function(val)
                slotDB.Tag = val
                ApplySettings()
            end,
        })

        local boundOptions = { { value = '', text = L['None'] }, { value = 'frame', text = L['Frame'] } }
        for j, other in ipairs(TAG_SLOTS) do
            if other ~= selected then
                boundOptions[#boundOptions + 1] = { value = other, text = format('%s %d', L['Tag'], j) }
            end
        end
        local styleRow = card:Row(rowH)
        styleRow:Dropdown(L['Insert Tag'], {
            width = 0.5,
            conditions = { 'tagOn' },
            tooltip = L['Appends the picked tag to the tag text above.'],
            options = TagInsertOptions,
            value = '',
            callback = function(key)
                slotDB.Tag = slotDB.Tag == '' and key or slotDB.Tag .. key
                ApplySettings()
                card:Rebuild()
            end,
        })
        styleRow:Dropdown(L['Bound To'], {
            width = 0.5,
            conditions = { 'tagOn' },
            tooltip = L['Pins the far edge so long text truncates instead of overflowing.'],
            options = boundOptions,
            value = slotDB.BoundTo,
            callback = function(key)
                slotDB.BoundTo = key
                ApplySettings()
            end,
        })

        card:Separator()

        local fontRow = card:Row(rowH)
        fontRow:Checkbox(L['Use Global Font'], {
            width = 0.5,
            conditions = { 'tagOn' },
            value = slotDB.UseGlobalFont,
            callback = function(checked)
                slotDB.UseGlobalFont = checked
                ApplySettings()
                page:Refresh()
            end,
        })
        fontRow:Dropdown(L['Font'], {
            width = 0.5,
            media = 'font',
            searchable = true,
            conditions = { 'tagOn', 'tagOwnFont' },
            value = slotDB.FontFace,
            callback = function(key)
                slotDB.FontFace = key
                ApplySettings()
            end,
        })
        local sizeRow = card:Row(rowH)
        sizeRow:Slider(L['Font Size'], {
            width = 0.5,
            conditions = { 'tagOn' },
            min = 6,
            max = 32,
            step = 1,
            value = slotDB.FontSize,
            callback = function(val)
                slotDB.FontSize = val; ApplySettings()
            end,
            callbackOnRelease = true,
        })
        sizeRow:Dropdown(L['Outline'], {
            width = 0.5,
            conditions = { 'tagOn', 'tagOwnFont' },
            options = OutlineOptions,
            value = slotDB.FontOutline,
            callback = function(key)
                slotDB.FontOutline = key
                ApplySettings()
            end,
        })

        card:Separator()

        AddPositionRows(card, slotDB, { 'tagOn' })
    end)
end

local function BuildIndicatorsSection(page, uDB, unit)
    local selected = 'Resting'
    page:SetCondition('indicatorOn', function() return uDB.Indicators[selected].Enabled end)

    local card = page:Card(L['Indicators'], 'unitOn')
    card:Rebuild(function(card)
        local iDB = uDB.Indicators[selected]

        local headRow = card:Row(rowH)
        headRow:Dropdown(L['Indicator'], {
            width = 0.5,
            options = IndicatorOptions,
            value = selected,
            callback = function(key)
                selected = key
                card:Rebuild()
            end,
        })
        headRow:Checkbox(L['Enable'], {
            width = 0.5,
            value = iDB.Enabled,
            callback = function(checked)
                iDB.Enabled = checked
                ApplySettings()
                page:Refresh()
            end,
        })

        card:Separator()

        card:Row(rowH):Slider(L['Size'], {
            width = 0.5,
            conditions = { 'indicatorOn' },
            min = 8,
            max = 48,
            step = 1,
            value = iDB.Size,
            callback = function(val)
                iDB.Size = val; ApplySettings()
            end,
            callbackOnRelease = true,
        })

        AddPositionRows(card, iDB, { 'indicatorOn' })
    end)
end

local function BuildMiscSection(page, uDB, unit)
    page:SetCondition('raidIconOn', function() return uDB.RaidIcon.Enabled end)
    page:SetCondition('leaderOn', function() return uDB.LeaderIndicator.Enabled end)

    local iconSlots = {
        { db = uDB.RaidIcon,        title = L['Raid Icon'],        enableLabel = L['Enable Raid Icon'],        cond = 'raidIconOn', maxSize = 64 },
        { db = uDB.LeaderIndicator, title = L['Leader Indicator'], enableLabel = L['Enable Leader Indicator'], cond = 'leaderOn',   maxSize = 32 },
    }
    for _, slot in ipairs(iconSlots) do
        local card = page:Card(slot.title, 'unitOn')
        local headRow = card:Row(rowH)
        headRow:Checkbox(slot.enableLabel, {
            width = 0.5,
            value = slot.db.Enabled,
            callback = function(checked)
                slot.db.Enabled = checked
                ApplySettings()
                page:Refresh()
            end,
        })
        headRow:Slider(L['Size'], {
            width = 0.5,
            conditions = { slot.cond },
            min = 8,
            max = slot.maxSize,
            step = 1,
            value = slot.db.Size,
            callback = function(val)
                slot.db.Size = val; ApplySettings()
            end,
            callbackOnRelease = true,
        })

        AddPositionRows(card, slot.db, { slot.cond })
    end
end

local SECTION_BUILDERS = {
    frame = BuildFrameSection,
    health = BuildHealthSection,
    power = BuildPowerSection,
    castbar = BuildCastbarSection,
    tags = BuildTagsSection,
    indicators = BuildIndicatorsSection,
    misc = BuildMiscSection,
}

-- Every unit is always listed in the sidebar; the selected unit decides which section tabs exist.
local UNIT_ITEMS = {}
for _, unit in ipairs({ 'player', 'target', 'targettarget', 'focus', 'focustarget', 'pet', 'pettarget' }) do
    UNIT_ITEMS[#UNIT_ITEMS + 1] = { key = unit, text = UNIT_LABELS[unit] }
end

local SECTION_TABS = {
    { id = 'frame',      text = L['Frame'] },
    { id = 'health',     text = L['Health'] },
    { id = 'power',      text = L['Power'] },
    { id = 'castbar',    text = L['Castbar'] },
    { id = 'tags',       text = L['Tags'] },
    { id = 'indicators', text = L['Indicators'] },
    { id = 'misc',       text = L['Miscellaneous'] },
}

GUI:RegisterPage('unitFramesUnits', {
    mode = 'tabs',
    -- The content depends on the selected unit, so there is nothing to harvest from a bare build.
    noHarvest = true,
    search = {
        L['Frame'], L['Health'], L['Power'], L['Castbar'], L['Tags'], L['Indicators'],
        L['Raid Icon'], L['Leader Indicator'], L['Bound To'], L['Miscellaneous'], L['Safe Zone'],
        L['Width'], L['Height'], L['Size'], L['Absorbs'], L['Heal Absorb'], L['Damage Absorb'],
        L['Use Global Colors'], L['Inverse Fill'], L['Enable Castbar'], L['Enable Power Bar'],
        L['Tag Text'], L['Insert Tag'], L['Outline'], L['Font Size'],
    },
    sidebar = { items = UNIT_ITEMS },
    tabs = function(unit)
        if not NO_POWER[unit] then return SECTION_TABS end

        local tabs = {}
        for _, tab in ipairs(SECTION_TABS) do
            if tab.id ~= 'power' and tab.id ~= 'castbar' then
                tabs[#tabs + 1] = tab
            end
        end
        return tabs
    end,
    build = function(page, sectionKey, unit)
        local builder = SECTION_BUILDERS[sectionKey]
        if not builder or not unit then return end

        local db = NRSKNUI.db.profile.UnitFrames
        local uDB = db.Units[unit]

        page:SetEnabled(function() return db.Enabled end)
        page:SetCondition('unitOn', function() return uDB.Enabled end)

        builder(page, uDB, unit)
    end,
})

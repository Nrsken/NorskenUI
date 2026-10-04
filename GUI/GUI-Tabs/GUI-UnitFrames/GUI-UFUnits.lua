---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs = ipairs
local pairs = pairs
local format = string.format

local function ApplySettings() UF:ApplySettings() end
local AnchorOptions = NRSKNUI.AnchorOptions
local GrowthOptions = NRSKNUI.GrowthOptions
local OutlineOptions = NRSKNUI:GetOutlineOptions(true)
local TAG_SLOTS = { 'TagOne', 'TagTwo', 'TagThree', 'TagFour', 'TagFive' }
local TAG_CATEGORIES = {
    { key = 'health',   label = L['Health'] },
    { key = 'power',    label = L['Power'] },
    { key = 'name',     label = L['Name'] },
    { key = 'misc',     label = L['Misc'] },
    { key = 'prefixes', label = L['Prefix'] },
}
local INDICATOR_MAX_SIZE = { RaidIcon = 64 }

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

---@param text string
---@return string
local function Muted(text)
    return NRSKNUI:ColorText(text, Theme.textMuted)
end

---A muted note in the half of a row a global toggle leaves empty, saying what the card follows instead.
---@param row KajiGUIFluentRow
---@param text string
local function FollowingNote(row, text)
    row:Text(nil, { width = 0.5, height = rowH, text = Muted(text), bgMode = 'hide' })
end

local SMOOTHING_OPTIONS = {
    { value = 'global', text = L['Use Global'] },
    { value = 'on',     text = L['On'] },
    { value = 'off',    text = L['Off'] },
}

---Smoothing as one dropdown over the UseGlobalSmooth / Smooth pair.
---@param row KajiGUIFluentRow
---@param db table
---@param config table? width / conditions / tooltip
local function SmoothingDropdown(row, db, config)
    config = config or {}
    row:Dropdown(L['Smoothing'], {
        width = config.width or 0.5,
        conditions = config.conditions,
        tooltip = config.tooltip or L['Use Global follows the smoothing setting from the general settings.'],
        options = SMOOTHING_OPTIONS,
        value = db.UseGlobalSmooth and 'global' or (db.Smooth and 'on' or 'off'),
        callback = function(value)
            db.UseGlobalSmooth = value == 'global'
            if value ~= 'global' then db.Smooth = value == 'on' end
            ApplySettings()
        end,
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
    for _, condition in ipairs(conditions or {}) do
        dropConditions[#dropConditions + 1] = condition
    end

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

-- Frame Settings Page.
local function BuildFrameSection(page, uDB, unit)
    -- Card 1: Enable
    local enableCard = page:Card(UF.UnitLabels[unit], 'all')
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
        min = 1,
        max = 1000,
        step = 1,
        value = uDB.Width,
        callback = function(val)
            uDB.Width = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })
    sizeRow:Slider(L['Height'], {
        width = 0.5,
        min = 1,
        max = 1000,
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

    if unit ~= 'boss' then return end

    -- Card 4: Boss chain. Position above only moves boss1, the rest follow these two settings.
    local chainCard = page:Card(L['Boss Frames'], 'unitOn')
    local chainRow = chainCard:Row(rowHL, 0)
    chainRow:Slider(L['Spacing'], {
        width = 0.5,
        tooltip = L['Gap between each boss frame and the one before it.'],
        min = 0,
        max = 200,
        step = 1,
        value = uDB.Spacing,
        callback = function(val)
            uDB.Spacing = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })
    chainRow:Dropdown(L['Growth Direction'], {
        width = 0.5,
        tooltip = L['Which way the chain grows away from the first boss frame.'],
        options = GrowthOptions,
        value = uDB.GrowthDirection,
        callback = function(key)
            uDB.GrowthDirection = key; ApplySettings()
        end,
    })
end

-- Healthbar Settings Page.
local function BuildHealthSection(page, uDB, unit)
    local hDB = uDB.Health
    page:SetCondition('ownHealthBg', function() return hDB.BackgroundTexture ~= '' end)

    -- Card 1: the bar itself, motion and textures.
    local barCard = page:Card(L['Bar'], 'unitOn')
    local motionRow = barCard:Row(rowH)
    SmoothingDropdown(motionRow, hDB)
    motionRow:Checkbox(L['Inverse Fill'], {
        width = 0.5,
        value = hDB.Inverse,
        callback = function(checked)
            hDB.Inverse = checked; ApplySettings()
        end,
    })
    AddTextureOverrideRow(page, barCard:Row(rowH), hDB, 'ownHealthTexture', nil)
    local bgTexRow = barCard:Row(rowHL, 0)
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

    -- Card 2: Colors. Following the global colors, the unit's own are not drawn at all.
    local colorCard = page:Card(L['Colors'], 'unitOn')
    colorCard:Rebuild(function(card)
        local own = not hDB.UseGlobalColors
        local modeRow = card:Row(own and rowH or rowHL, not own and 0 or nil)
        modeRow:Checkbox(L['Use Global Colors'], {
            width = 0.5,
            value = hDB.UseGlobalColors,
            callback = function(checked)
                hDB.UseGlobalColors = checked
                ApplySettings()
                card:Rebuild()
            end,
        })
        if not own then
            FollowingNote(modeRow, L['Following the colors in Unit Frames > General.'])
            return
        end

        modeRow:Checkbox(L['Class Colored Health'], {
            width = 0.5,
            value = hDB.ColorByClass,
            callback = function(checked)
                hDB.ColorByClass = checked; ApplySettings()
            end,
        })
        local fgRow = card:Row(rowH)
        fgRow:ColorPicker(L['Foreground'], {
            width = 0.5,
            value = hDB.Foreground,
            callback = function(r, g, b, a)
                hDB.Foreground = { r, g, b, a }
                ApplySettings()
            end,
        })
        fgRow:Slider(L['Class Color Alpha'], {
            width = 0.5,
            min = 0,
            max = 1,
            step = 0.05,
            value = hDB.ForegroundAlphaWhenColorByClass,
            callback = function(val)
                hDB.ForegroundAlphaWhenColorByClass = val; ApplySettings()
            end,
            callbackOnRelease = true,
        })
        local bgRow = card:Row(rowHL, 0)
        bgRow:ColorPicker(L['Background'], {
            width = 0.5,
            value = hDB.Background,
            callback = function(r, g, b, a)
                hDB.Background = { r, g, b, a }
                ApplySettings()
            end,
        })
        bgRow:ColorPicker(L['Background (Class Colored)'], {
            width = 0.5,
            value = hDB.BackgroundWhenColorByClass,
            callback = function(r, g, b, a)
                hDB.BackgroundWhenColorByClass = { r, g, b, a }
                ApplySettings()
            end,
        })
    end)

    -- Card 3/4: one card per absorb, each with its own global-or-override toggle.
    local absorbSlots = {
        { db = hDB.HealAbsorb,   title = L['Heal Absorb'],   label = L['Enable Heal Absorb'],   onCond = 'healAbsorbOn' },
        { db = hDB.DamageAbsorb, title = L['Damage Absorb'], label = L['Enable Damage Absorb'], onCond = 'damageAbsorbOn' },
    }
    for _, slot in ipairs(absorbSlots) do
        page:SetCondition(slot.onCond, function() return slot.db.Enabled end)

        page:Card(slot.title, 'unitOn'):Rebuild(function(card)
            local own = not slot.db.UseGlobal
            local headRow = card:Row(own and rowH or rowHL, not own and 0 or nil)
            headRow:Checkbox(L['Use Global Settings'], {
                width = 0.5,
                tooltip = L['Follow the shared absorb settings from the general settings.'],
                value = slot.db.UseGlobal,
                callback = function(checked)
                    slot.db.UseGlobal = checked
                    ApplySettings()
                    card:Rebuild()
                end,
            })
            if not own then
                FollowingNote(headRow, L['Following the absorb settings in Unit Frames > General.'])
                return
            end

            headRow:Checkbox(slot.label, {
                width = 0.5,
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
        end)
    end
end

-- Powerbar Settings Page.
local function BuildPowerSection(page, uDB, unit)
    local pDB = uDB.Power
    page:SetCondition('powerOn', function() return pDB.Enabled end)
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
    enableRow:Dropdown(L['Mode'], {
        width = 0.5,
        conditions = { 'powerOn' },
        options = {
            { value = 'docked',   text = L['Docked'] },
            { value = 'undocked', text = L['Undocked'] },
        },
        value = pDB.Docked and 'docked' or 'undocked',
        tooltip = L['Docked sits inside the frame along its bottom, the health bar making room. Undocked hangs below the frame.'],
        callback = function(value)
            pDB.Docked = value == 'docked'
            ApplySettings()
        end,
    })

    local sizeRow = powerCard:Row(rowH)
    sizeRow:Slider(L['Height'], {
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
    SmoothingDropdown(sizeRow, pDB, {
        conditions = { 'powerOn' },
        tooltip = L['Use Global follows the smoothing setting from the general settings. Power smoothing only applies to the player frame.'],
    })

    AddTextureOverrideRow(page, powerCard:Row(rowHL, 0), pDB, 'ownPowerTexture', { 'powerOn' })

    -- Group frames pick whose bar shows, e.g. tanks only, or Tank + Death Knight for Blood's runic power.
    if UF.GroupConfigs[unit] then
        ---@param map table<string, boolean> the saved picks, kept as a map so AceDB never refills one
        ---@return string[]
        local function Picked(map)
            local list = {}
            for key, on in pairs(map) do
                if on then list[#list + 1] = key end
            end
            return list
        end
        ---@param map table<string, boolean>
        ---@param options table[]
        ---@param values string[]
        local function Store(map, options, values)
            local chosen = {}
            for _, value in ipairs(values) do chosen[value] = true end
            for _, option in ipairs(options) do map[option.value] = chosen[option.value] == true end
            ApplySettings()
        end

        local roleOptions = {
            { value = 'TANK',    text = L['Tank'] },
            { value = 'HEALER',  text = L['Healer'] },
            { value = 'DAMAGER', text = L['Damage'] },
        }
        local classOptions = {}
        for _, class in ipairs(CLASS_SORT_ORDER) do
            classOptions[#classOptions + 1] = { value = class, text = NRSKNUI:ColorTextByClass(LOCALIZED_CLASS_NAMES_MALE[class], class) }
        end

        local showRow = page:Card(L['Show For'], 'unitOn'):Row(rowHL, 0)
        showRow:Dropdown(L['Roles'], {
            width = 0.5,
            multiSelect = true,
            conditions = { 'powerOn' },
            options = roleOptions,
            value = Picked(pDB.Roles),
            tooltip = L['Members whose role is picked get a power bar.'],
            callback = function(values) Store(pDB.Roles, roleOptions, values) end,
        })
        showRow:Dropdown(L['Classes'], {
            width = 0.5,
            multiSelect = true,
            searchable = true,
            conditions = { 'powerOn' },
            options = classOptions,
            value = Picked(pDB.Classes),
            tooltip = L['Only these classes get a power bar. Pick none for every class. Tank + Death Knight shows Blood runic power.'],
            callback = function(values) Store(pDB.Classes, classOptions, values) end,
        })
    end

    -- Card 2: Colors. Following the global colors, the unit's own are not drawn at all.
    page:Card(L['Colors'], 'unitOn'):Rebuild(function(card)
        local own = not pDB.UseGlobalColors
        local modeRow = card:Row(own and rowH or rowHL, not own and 0 or nil)
        modeRow:Checkbox(L['Use Global Colors'], {
            width = 0.5,
            conditions = { 'powerOn' },
            value = pDB.UseGlobalColors,
            callback = function(checked)
                pDB.UseGlobalColors = checked
                ApplySettings()
                card:Rebuild()
            end,
        })
        if not own then
            FollowingNote(modeRow, L['Following the colors in Unit Frames > General.'])
            return
        end

        modeRow:Checkbox(L['Color By Power Type'], {
            width = 0.5,
            tooltip = L['Color the bar by the power type (mana, rage, energy...). Uncheck to use a flat color.'],
            conditions = { 'powerOn' },
            value = pDB.ColorByPower,
            callback = function(checked)
                pDB.ColorByPower = checked
                ApplySettings()
                page:Refresh()
            end,
        })
        card:Row(rowHL, 0):ColorPicker(L['Power Color'], {
            width = 0.5,
            conditions = { 'powerOn', 'powerFlatColor' },
            value = pDB.Color,
            callback = function(r, g, b, a)
                pDB.Color = { r, g, b, a }
                ApplySettings()
            end,
        })
    end)
end

-- Castbar Settings Page.
local function BuildCastbarSection(page, uDB, unit)
    local cDB = uDB.Castbar
    page:SetCondition('castbarOn', function() return cDB.Enabled end)
    page:SetCondition('safeZoneOn', function() return cDB.SafeZone.Enabled end)

    -- Card 1: the bar itself.
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
    AddTextureOverrideRow(page, castbarCard:Row(rowHL, 0), cDB, 'ownCastbarTexture', { 'castbarOn' })

    -- Card 2: what it shows.
    local displayCard = page:Card(L['Display'], 'unitOn')
    local showRow = displayCard:Row(rowH)
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
    local holdRow = displayCard:Row(rowHL, 0)
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

    -- Card 3: Colors. Following the global colors, the unit's own are not drawn at all.
    page:Card(L['Colors'], 'unitOn'):Rebuild(function(card)
        local own = not cDB.UseGlobalColors
        local modeRow = card:Row(own and rowH or rowHL, not own and 0 or nil)
        modeRow:Checkbox(L['Use Global Colors'], {
            width = 0.5,
            conditions = { 'castbarOn' },
            value = cDB.UseGlobalColors,
            callback = function(checked)
                cDB.UseGlobalColors = checked
                ApplySettings()
                card:Rebuild()
            end,
        })
        if not own then
            FollowingNote(modeRow, L['Following the colors in Unit Frames > General.'])
            return
        end

        modeRow:Checkbox(L['Class Colored Castbar'], {
            width = 0.5,
            conditions = { 'castbarOn' },
            value = cDB.ColorByClass,
            callback = function(checked)
                cDB.ColorByClass = checked; ApplySettings()
            end,
        })
        local castColorRow = card:Row(rowH)
        castColorRow:ColorPicker(L['Castbar Color'], {
            width = 0.5,
            conditions = { 'castbarOn' },
            value = cDB.Color,
            callback = function(r, g, b, a)
                cDB.Color = { r, g, b, a }
                ApplySettings()
            end,
        })
        castColorRow:ColorPicker(L['Non-Interruptible'], {
            width = 0.5,
            conditions = { 'castbarOn' },
            value = cDB.NonInterruptibleColor,
            callback = function(r, g, b, a)
                cDB.NonInterruptibleColor = { r, g, b, a }
                ApplySettings()
            end,
        })
        local stateRow = card:Row(rowHL, 0)
        stateRow:ColorPicker(L['Interrupted / Failed'], {
            width = 0.5,
            conditions = { 'castbarOn' },
            value = cDB.FailColor,
            callback = function(r, g, b, a)
                cDB.FailColor = { r, g, b, a }
                ApplySettings()
            end,
        })
        stateRow:ColorPicker(L['Background'], {
            width = 0.5,
            conditions = { 'castbarOn' },
            value = cDB.Background,
            callback = function(r, g, b, a)
                cDB.Background = { r, g, b, a }
                ApplySettings()
            end,
        })
    end)

    -- Card 4: Safe Zone, latency at the end of the cast. Only the player's own casts have one.
    if unit == 'player' then
        page:Card(L['Safe Zone'], 'unitOn'):Rebuild(function(card)
            local own = not cDB.SafeZone.UseGlobal
            local headRow = card:Row(own and rowH or rowHL, not own and 0 or nil)
            headRow:Checkbox(L['Use Global Settings'], {
                width = 0.5,
                tooltip = L['Follow the safe zone settings from the general settings.'],
                conditions = { 'castbarOn' },
                value = cDB.SafeZone.UseGlobal,
                callback = function(checked)
                    cDB.SafeZone.UseGlobal = checked
                    ApplySettings()
                    card:Rebuild()
                end,
            })
            if not own then
                FollowingNote(headRow, L['Following the safe zone in Unit Frames > General.'])
                return
            end

            headRow:Checkbox(L['Enable Safe Zone'], {
                width = 0.5,
                tooltip = L['Shows your latency at the end of the cast.'],
                conditions = { 'castbarOn' },
                value = cDB.SafeZone.Enabled,
                callback = function(checked)
                    cDB.SafeZone.Enabled = checked
                    ApplySettings()
                    page:Refresh()
                end,
            })
            card:Row(rowHL, 0):ColorPicker(L['Safe Zone Color'], {
                width = 0.5,
                conditions = { 'castbarOn', 'safeZoneOn' },
                value = cDB.SafeZone.Color,
                callback = function(r, g, b, a)
                    cDB.SafeZone.Color = { r, g, b, a }
                    ApplySettings()
                end,
            })
        end)
    end

    -- Card 5: Position
    local posRow = page:Card(L['Position'], 'unitOn'):Row(rowHL, 0)
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

-- Tag Settings Page.
local function BuildTagsSection(page, uDB, unit, selected)
    selected = selected or TAG_SLOTS[1]
    page:SetCondition('tagOn', function() return uDB.Tags[selected].Enabled end)
    page:SetCondition('tagOwnFont', function() return not uDB.Tags[selected].UseGlobalFont end)

    local c = page:Card(L['Tags'], 'unitOn')
    c:Rebuild(function(card)
        local slotDB = uDB.Tags[selected]

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
        headRow:EditBox(L['Name'], {
            width = 0.5,
            value = slotDB.Name or '',
            tooltip = L['What to call this tag in the tab strip. Leave empty to number it.'],
            callback = function(value)
                if value == (slotDB.Name or '') then return end
                slotDB.Name = value ~= '' and value or nil
                NRSKNUI.GUIFrame.content:ShowPage(UF.GUIPageID(unit), { itemKey = 'tags', tabId = selected })
            end,
        })

        card:Separator()

        card:Row(rowH):EditBox(L['Tag Text'], {
            width = 1,
            conditions = { 'tagOn' },
            tooltip = L['Any oUF tag string, e.g. [NUF:name] or [perhp]%.'],
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

        -- Every category in one searchable list, each entry naming its category after it.
        local insertOptions = {}
        for _, category in ipairs(TAG_CATEGORIES) do
            for _, option in ipairs(UF.TagOptions[category.key]) do
                insertOptions[#insertOptions + 1] = { value = option.value, text = option.text .. '  ' .. Muted(category.label) }
            end
        end
        card:Row(rowH):Dropdown(L['Insert Tag'], {
            width = 1,
            searchable = true,
            conditions = { 'tagOn' },
            tooltip = L['Adds the picked tag to the end of the tag text. A prefix colors what follows it; close it with ||r.'],
            options = insertOptions,
            value = L['-- Select --'],
            callback = function(key)
                slotDB.Tag = slotDB.Tag == '' and key or slotDB.Tag .. key
                ApplySettings()
                card:Rebuild()
            end,
        })

        card:Separator()

        local fontRow = card:Row(rowH)
        fontRow:Checkbox(L['Use Global Font'], {
            width = 1,
            conditions = { 'tagOn' },
            value = slotDB.UseGlobalFont,
            callback = function(checked)
                slotDB.UseGlobalFont = checked
                ApplySettings()
                page:Refresh()
            end,
        })

        card:Separator()

        local globalRow = card:Row(rowH)
        globalRow:Dropdown(L['Font'], {
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
        globalRow:Dropdown(L['Outline'], {
            width = 0.5,
            conditions = { 'tagOn', 'tagOwnFont' },
            options = OutlineOptions,
            value = slotDB.FontOutline,
            callback = function(key)
                slotDB.FontOutline = key
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
        sizeRow:ColorPicker(L['Baseline Color'], {
            width = 0.5,
            conditions = { 'tagOn' },
            value = slotDB.Color,
            tooltip = L['The color of the text, unless a tag overrides it.'],
            callback = function(r, g, b)
                slotDB.Color = { r, g, b }
                ApplySettings()
            end,
        })

        card:Separator()

        card:Row(rowH):Dropdown(L['Bound To'], {
            width = 1,
            conditions = { 'tagOn' },
            tooltip = L['Pins the far edge so long text truncates instead of overflowing.'],
            options = boundOptions,
            value = slotDB.BoundTo,
            callback = function(key)
                slotDB.BoundTo = key
                ApplySettings()
            end,
        })

        AddPositionRows(card, slotDB, { 'tagOn' })
    end)
end

-- Rows only one indicator has, added between its size row and its position rows.
local INDICATOR_EXTRAS = {
    Role = function(card, iDB)
        card:Row(rowH):Checkbox(L['Tank and Healer Only'], {
            width = 1,
            conditions = { 'indicatorOn' },
            value = iDB.TankHealerOnly,
            tooltip = L['Hide the role icon on damage dealers.'],
            callback = function(checked)
                iDB.TankHealerOnly = checked
                ApplySettings()
            end,
        })
    end,
}

-- Indicator Settings Page.
local function BuildIndicatorsSection(page, uDB, unit, selected)
    local defs = UF.UnitIndicators(unit)
    local def
    for _, entry in ipairs(defs) do
        if entry.key == selected then
            def = entry
            break
        end
    end
    if not def then
        def = defs[1]
        selected = def.key
    end

    page:SetCondition('indicatorOn', function() return uDB.Indicators[selected].Enabled end)

    local iDB = uDB.Indicators[selected]

    local card = page:Card(def.label, 'unitOn')
    local headRow = card:Row(rowH)
    headRow:Checkbox(L['Enable'], {
        width = 1,
        value = iDB.Enabled,
        callback = function(checked)
            iDB.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    card:Separator()

    local multipleArt = #def.art > 1
    local sizeTypeRow = card:Row(rowH)

    if multipleArt then
        local artOptions = {}
        for i, variant in ipairs(def.art) do
            artOptions[i] = { value = variant.key, text = variant.label }
        end

        sizeTypeRow:Dropdown(L['Texture'], {
            width = 0.5,
            conditions = { 'indicatorOn' },
            tooltip = L['Which artwork the indicator draws.'],
            options = artOptions,
            value = iDB.Texture,
            callback = function(key)
                iDB.Texture = key
                ApplySettings()
            end,
        })
    end

    sizeTypeRow:Slider(L['Size'], {
        width = multipleArt and 0.5 or 1,
        conditions = { 'indicatorOn' },
        min = 8,
        max = INDICATOR_MAX_SIZE[selected] or 48,
        step = 1,
        value = iDB.Size,
        callback = function(val)
            iDB.Size = val; ApplySettings()
        end,
        callbackOnRelease = true,
    })

    local extra = INDICATOR_EXTRAS[selected]
    if extra then extra(card, iDB) end

    AddPositionRows(card, iDB, { 'indicatorOn' })
end

-- Exposed for GUI-UFPages.lua, which assembles the per-unit pages.
---@class UF.GUISections
UF.GUISections = {
    frame = BuildFrameSection,
    health = BuildHealthSection,
    power = BuildPowerSection,
    castbar = BuildCastbarSection,
    tags = BuildTagsSection,
    indicators = BuildIndicatorsSection,
}

---Sub-tab strips. Their ids are the DB keys the builders index with.
---@class UF.GUITagTab
---@field id string The tag slot's DB key.
---@field text string The tag slot's display name.
---One tab per tag slot, titled with the tag's name where it has one.
---@param unit string config key
---@return { id: string, text: string }[] tabs
function UF.GUITagTabs(unit)
    local tags = NRSKNUI.db.profile.UnitFrames.Units[unit].Tags
    local tabs = {}
    for i, slot in ipairs(TAG_SLOTS) do
        local name = tags[slot].Name
        tabs[i] = { id = slot, text = (name and name ~= '') and name or format('%s %d', L['Tag'], i) }
    end
    return tabs
end

---One tab per indicator the unit can actually show, see UF.UnitIndicators.
---@param unit string config key
---@return { id: string, text: string }[] tabs
function UF.GUIIndicatorTabs(unit)
    local tabs = {}
    for i, def in ipairs(UF.UnitIndicators(unit)) do
        tabs[i] = { id = def.key, text = def.label }
    end
    return tabs
end

---Every indicator name, for the page search index, which is built once rather than per unit.
---@return { key: string, text: string }[]
function UF.GUIIndicatorNames()
    local names = {}
    for i, def in ipairs(UF.IndicatorDefs) do
        names[i] = { key = def.key, text = def.label }
    end
    return names
end

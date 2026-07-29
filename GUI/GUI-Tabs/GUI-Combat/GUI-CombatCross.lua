---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CombatCrossModule
local CombatCross = NRSKNUI:GetModule('CombatCross')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

GUI:RegisterPage('combatCross', {
    mode = 'clean',
    search = { L['Thickness'], L['Length'], L['Center Gap'], L['Center Dot'], L['Dot Size'], L['Diamond Size'], },
    build = function(page)
        local db = NRSKNUI.db.profile.CombatCross
        if not db then return end

        page:SetEnabled(function() return db.Enabled end)
        page:SetCondition('colorMode', function() return db.ColorMode == 'custom' end)
        page:SetCondition('rangeColor', function() return db.RangeColorMeleeEnabled or db.RangeColorRangedEnabled end)
        page:SetCondition('crossMode', function() return db.Mode == 'cross' end)
        page:SetCondition('dotMode', function() return db.Mode == 'dot' end)
        page:SetCondition('diamondMode', function() return db.Mode == 'diamond' end)
        local function ApplySettings() CombatCross:ApplySettings() end

        -- Card 1: Enable
        local enableCard = page:Card(L['Combat Cross'])
        local enableRow = enableCard:Row(rowHL, 0)
        enableRow:Checkbox(L['Enable Combat Cross'], {
            width = 1,
            master = true,
            value = db.Enabled,
            msgPopup = true,
            msgText = L['Combat Cross'],
            callback = function(checked)
                db.Enabled = checked
                NRSKNUI:ToggleModule('CombatCross', checked)
                page:Refresh()
            end,
        })

        -- Card 2: Appearance
        local appearanceCard = page:Card(L['Appearance'], 'all')
        appearanceCard:Rebuild(function(card)
            local modeRow = card:Row(rowH)
            modeRow:Dropdown(L['Style'], {
                width = 0.5,
                options = {
                    { value = 'cross',   text = L['Cross'] },
                    { value = 'dot',     text = L['Dot'] },
                    { value = 'diamond', text = L['Diamond'] },
                },
                value = db.Mode,
                callback = function(key)
                    db.Mode = key
                    ApplySettings()
                    card:Rebuild()
                end,
            })
            modeRow:Checkbox(L['Outline'], {
                width = 0.5,
                value = db.Outline,
                callback = function(checked)
                    db.Outline = checked
                    ApplySettings()
                end,
            })

            if db.Mode == 'cross' then
                card:Separator()

                local sizeRow = card:Row(rowH)
                sizeRow:Slider(L['Thickness'], {
                    width = 0.5,
                    conditions = { 'crossMode' },
                    min = 3,
                    max = 20,
                    step = 1,
                    value = db.CrossThickness,
                    callback = function(val)
                        db.CrossThickness = val; ApplySettings()
                    end,
                })
                sizeRow:Slider(L['Length'], {
                    width = 0.5,
                    conditions = { 'crossMode' },
                    min = 4,
                    max = 80,
                    step = 1,
                    value = db.CrossLength,
                    callback = function(val)
                        db.CrossLength = val; ApplySettings()
                    end,
                })

                local gapRow = card:Row(rowHL, 0)
                gapRow:Slider(L['Center Gap'], {
                    width = 0.5,
                    conditions = { 'crossMode' },
                    min = 0,
                    max = 40,
                    step = 1,
                    value = db.CrossGap,
                    callback = function(val)
                        db.CrossGap = val; ApplySettings()
                    end,
                })
                gapRow:Checkbox(L['Center Dot'], {
                    width = 0.5,
                    conditions = { 'crossMode' },
                    tooltip = L['Because of pixel alignment, I recommend using even numbers (2,4,6 etc.) for thickness when using the center dot.'],
                    value = db.CrossCenterDotEnabled,
                    callback = function(checked)
                        db.CrossCenterDotEnabled = checked; ApplySettings()
                    end,
                })
            end

            if db.Mode == 'dot' then
                card:Separator()

                card:Row(rowHL, 0):Slider(L['Dot Size'], {
                    width = 1,
                    conditions = { 'dotMode' },
                    min = 4,
                    max = 50,
                    step = 1,
                    value = db.CenterDotSize,
                    callback = function(val)
                        db.CenterDotSize = val; ApplySettings()
                    end,
                })
            end

            if db.Mode == 'diamond' then
                card:Separator()

                card:Row(rowHL, 0):Slider(L['Diamond Size'], {
                    width = 1,
                    conditions = { 'diamondMode' },
                    min = 4,
                    max = 50,
                    step = 1,
                    value = db.DiamondSize,
                    callback = function(val)
                        db.DiamondSize = val; ApplySettings()
                    end,
                })
            end
        end)

        -- Card 3: Color
        local colorCard = page:Card(L['Color'], 'all')
        local colorRow = colorCard:Row(rowHL, 0)
        colorRow:Dropdown(L['Color Mode'], {
            width = 0.5,
            options = NRSKNUI.ColorModeOptions,
            value = db.ColorMode,
            callback = function(key)
                db.ColorMode = key
                ApplySettings()
                page:Refresh()
            end,
        })
        colorRow:ColorPicker(L['Custom Color'], {
            width = 0.5,
            conditions = { 'colorMode' },
            value = db.Color,
            callback = function(r, g, b, a)
                db.Color = { r, g, b, a }
                ApplySettings()
            end,
        })

        -- Card 4: Range Warning
        local rangeCard = page:Card(L['Range Warning'], 'all')
        local toggleRow = rangeCard:Row(rowH)
        toggleRow:Checkbox(L['Enable for melee specs'], {
            width = 0.5,
            value = db.RangeColorMeleeEnabled,
            callback = function(checked)
                db.RangeColorMeleeEnabled = checked
                ApplySettings()
                page:Refresh()
            end,
        })
        toggleRow:Checkbox(L['Enable for ranged specs'], {
            width = 0.5,
            value = db.RangeColorRangedEnabled,
            callback = function(checked)
                db.RangeColorRangedEnabled = checked
                ApplySettings()
                page:Refresh()
            end,
        })

        rangeCard:Separator()

        local rangeRow = rangeCard:Row(rowH)
        rangeRow:ColorPicker(L['Out of Range Color'], {
            width = 1,
            conditions = { 'rangeColor' },
            value = db.OutOfRangeColor,
            callback = function(r, g, b, a)
                db.OutOfRangeColor = { r, g, b, a }
                ApplySettings()
            end,
        })

        -- Card 5: Position
        page:PositionCard({
            db = db,
            showAnchorFrameType = false,
            showStrata = true,
            onChangeCallback = ApplySettings,
        })
    end,
})

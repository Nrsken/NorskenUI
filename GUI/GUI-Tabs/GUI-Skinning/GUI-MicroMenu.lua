---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class MicroMenuModule
local MM = NRSKNUI:GetModule('MicroMenu', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings()
    if MM then MM:ApplySettings() end
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    -- Card 1: Enable
    local enableCard = page:Card(L['Micro Menu Skinning'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Micro Menu Skinning'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Micro Menu Skinning'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('MicroMenu', checked)
            NRSKNUI:CreateReloadPrompt('Enabling/Disabling this UI element requires a reload to take full effect.')
            page:Refresh()
        end,
    })

    -- Card 2: Buttons
    local buttonCard = page:Card(L['Button Settings'], 'all')
    local sizeRow = buttonCard:Row(rowH)
    sizeRow:Slider(L['Button Width'], {
        width = 0.5,
        min = 5,
        max = 50,
        step = 1,
        value = db.ButtonWidth,
        callback = function(val)
            db.ButtonWidth = val; ApplySettings()
        end,
    })
    sizeRow:Slider(L['Button Height'], {
        width = 0.5,
        min = 5,
        max = 50,
        step = 1,
        value = db.ButtonHeight,
        callback = function(val)
            db.ButtonHeight = val; ApplySettings()
        end,
    })

    buttonCard:Separator()

    local spacingRow = buttonCard:Row(rowHL, 0)
    spacingRow:Slider(L['Button Spacing'], {
        width = 1,
        min = -20,
        max = 20,
        step = 1,
        value = db.ButtonSpacing,
        callback = function(val)
            db.ButtonSpacing = val; ApplySettings()
        end,
    })
end

-- Backdrop Settings Tab.
local function BuildBackdropSettingsTab(page, db)
    page:SetCondition('backdrop', function() return db.ShowBackdrop end)

    local backdropCard = page:Card(L['Backdrop Settings'], 'all')
    local toggleRow = backdropCard:Row(rowH)
    toggleRow:Checkbox(L['Enable Backdrop'], {
        width = 0.5,
        value = db.ShowBackdrop,
        callback = function(checked)
            db.ShowBackdrop = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    toggleRow:Slider(L['Backdrop Spacing'], {
        width = 0.5,
        conditions = { 'backdrop' },
        min = 0,
        max = 20,
        step = 1,
        value = db.BackdropSpacing,
        callback = function(val)
            db.BackdropSpacing = val; ApplySettings()
        end,
    })

    backdropCard:Separator()

    local colorRow = backdropCard:Row(rowHL, 0)
    colorRow:ColorPicker(L['Backdrop Color'], {
        width = 0.5,
        conditions = { 'backdrop' },
        value = db.BackdropColor,
        callback = function(r, g, b, a)
            db.BackdropColor = { r, g, b, a }; ApplySettings()
        end,
    })
    colorRow:ColorPicker(L['Border Color'], {
        width = 0.5,
        conditions = { 'backdrop' },
        value = db.BackdropBorderColor,
        callback = function(r, g, b, a)
            db.BackdropBorderColor = { r, g, b, a }; ApplySettings()
        end,
    })
end

-- Mouseover Settings Tab.
local function BuildMouseoverSettingsTab(page, db)
    page:SetCondition('mouseover', function() return db.Mouseover.Enabled end)

    local mouseoverCard = page:Card(L['Mouseover Settings'], 'all')
    local toggleRow = mouseoverCard:Row(rowH)
    toggleRow:Checkbox(L['Enable Micro Menu Mouseover'], {
        width = 0.5,
        value = db.Mouseover.Enabled,
        callback = function(checked)
            db.Mouseover.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    toggleRow:Slider(L['Alpha When No Mouseover'], {
        width = 0.5,
        conditions = { 'mouseover' },
        min = 0,
        max = 1,
        step = 0.1,
        value = db.Mouseover.Alpha,
        callback = function(val)
            db.Mouseover.Alpha = val; ApplySettings()
        end,
    })

    mouseoverCard:Separator()

    local fadeRow = mouseoverCard:Row(rowHL, 0)
    fadeRow:Slider(L['Fade In Duration'], {
        width = 0.5,
        conditions = { 'mouseover' },
        min = 0,
        max = 10,
        step = 0.1,
        value = db.Mouseover.FadeInDuration,
        callback = function(val) db.Mouseover.FadeInDuration = val end,
    })
    fadeRow:Slider(L['Fade Out Duration'], {
        width = 0.5,
        conditions = { 'mouseover' },
        min = 0,
        max = 10,
        step = 0.1,
        value = db.Mouseover.FadeOutDuration,
        callback = function(val) db.Mouseover.FadeOutDuration = val end,
    })
end

-- Position Settings Tab.
local function BuildPositionSettingsTab(page, db)
    page:PositionCard({ db = db, showAnchorFrameType = true, showStrata = true, onChangeCallback = ApplySettings, })
end

GUI:RegisterPage('microMenu', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',   text = L['General Settings'] },
        { id = 'backdrop',  text = L['Backdrop'] },
        { id = 'mouseover', text = L['Mouseover'] },
        { id = 'position',  text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.MicroMenu
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'backdrop' then
            BuildBackdropSettingsTab(page, db)
        elseif tabId == 'mouseover' then
            BuildMouseoverSettingsTab(page, db)
        elseif tabId == 'position' then
            BuildPositionSettingsTab(page, db)
        end
    end,
})

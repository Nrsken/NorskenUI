---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CombatCursorModule
local CursorCircle = NRSKNUI:GetModule('CursorCircle')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs = ipairs

local function ApplySettings()
    CursorCircle:ApplySettings()
end

-- Texture options built from the module's exposed texture list (key doubles as label).
local function GetTextureOptions()
    local options = {}
    for _, tex in ipairs(CursorCircle.Textures) do
        options[#options + 1] = { value = tex.key, text = tex.key }
    end
    return options
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    local gcd = db.GCD

    -- Card 1: Enable
    local enableCard = page:Card(L['Cursor Circle'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Cursor Circle'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Cursor Circle'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('CursorCircle', checked)
            page:Refresh()
        end,
    })

    -- Card 2: General Settings
    local generalCard = page:Card(L['General Settings'], 'all')
    local generalRow = generalCard:Row(rowHL, 0)
    generalRow:Dropdown(L['GCD Mode'], {
        width = 0.5,
        options = CursorCircle.GCDModeOptions,
        value = gcd.Mode,
        callback = function(key)
            gcd.Mode = key
            ApplySettings()
        end,
    })
    generalRow:Dropdown(L['Visibility'], {
        width = 0.5,
        options = CursorCircle.VisibilityModeOptions,
        value = db.VisibilityMode,
        callback = function(key)
            db.VisibilityMode = key
            ApplySettings()
        end,
    })
end

-- Main Ring Tab.
local function BuildRingTab(page, db)
    page:SetCondition('colorMode', function() return db.ColorMode == 'custom' end)

    local ringCard = page:Card(L['Main Ring Settings'], 'all')
    local ringRow = ringCard:Row(rowH)
    ringRow:Dropdown(L['Texture'], {
        width = 0.5,
        options = GetTextureOptions(),
        value = db.Texture,
        callback = function(key)
            db.Texture = key
            ApplySettings()
        end,
    })
    ringRow:Slider(L['Size'], {
        width = 0.5,
        min = 20,
        max = 150,
        step = 1,
        value = db.Size,
        callback = function(val)
            db.Size = val
            ApplySettings()
        end,
    })

    ringCard:Separator()

    local ringColorRow = ringCard:Row(rowHL, 0)
    ringColorRow:Dropdown(L['Color Mode'], {
        width = 0.5,
        options = NRSKNUI.ColorModeOptions,
        value = db.ColorMode,
        callback = function(key)
            db.ColorMode = key
            ApplySettings()
            page:Refresh()
        end,
    })
    ringColorRow:ColorPicker(L['Custom Color'], {
        width = 0.5,
        conditions = { 'colorMode' },
        value = db.Color,
        callback = function(r, g, b, a)
            db.Color = { r, g, b, a }
            ApplySettings()
        end,
    })
end

-- GCD Ring Tab.
local function BuildGCDTab(page, db)
    local gcd = db.GCD

    page:SetCondition('gcdEnabled', function() return gcd.Mode ~= 'disabled' end)
    page:SetCondition('gcdSeparate', function() return gcd.Mode == 'separate' end)
    page:SetCondition('gcdSwipeCustom', function() return gcd.SwipeColorMode == 'custom' end)
    page:SetCondition('gcdRingCustom', function() return gcd.RingColorMode == 'custom' end)

    local gcdCard = page:Card(L['GCD Settings'], 'all')
    local swipeRow = gcdCard:Row(rowH)
    swipeRow:Dropdown(L['Swipe Color Mode'], {
        width = 0.5,
        conditions = { 'gcdEnabled' },
        options = NRSKNUI.ColorModeOptions,
        value = gcd.SwipeColorMode,
        callback = function(key)
            gcd.SwipeColorMode = key
            ApplySettings()
            page:Refresh()
        end,
    })
    swipeRow:ColorPicker(L['Custom Color'], {
        width = 0.5,
        conditions = { 'gcdEnabled', 'gcdSwipeCustom' },
        value = gcd.SwipeColor,
        callback = function(r, g, b, a)
            gcd.SwipeColor = { r, g, b, a }
            ApplySettings()
        end,
    })

    local reverseRow = gcdCard:Row(rowH)
    reverseRow:Checkbox(L['Reverse Swipe'], {
        width = 1,
        conditions = { 'gcdEnabled' },
        value = gcd.Reverse,
        callback = function(checked)
            gcd.Reverse = checked
            ApplySettings()
        end,
    })

    local combatRow = gcdCard:Row(rowH)
    combatRow:Checkbox(L['Only In Combat'], {
        width = 1,
        conditions = { 'gcdEnabled' },
        value = gcd.HideOutOfCombat,
        callback = function(checked)
            gcd.HideOutOfCombat = checked
            ApplySettings()
        end,
    })

    gcdCard:Separator()

    local gcdRingRow = gcdCard:Row(rowH)
    gcdRingRow:Dropdown(L['Texture'], {
        width = 0.5,
        conditions = { 'gcdSeparate' },
        options = GetTextureOptions(),
        value = gcd.Texture,
        callback = function(key)
            gcd.Texture = key
            ApplySettings()
        end,
    })
    gcdRingRow:Slider(L['Ring Size'], {
        width = 0.5,
        conditions = { 'gcdSeparate' },
        min = 10,
        max = 150,
        step = 1,
        value = gcd.Size,
        callback = function(val)
            gcd.Size = val
            ApplySettings()
        end,
    })

    gcdCard:Separator()

    local gcdColorRow = gcdCard:Row(rowHL, 0)
    gcdColorRow:Dropdown(L['Ring Color Mode'], {
        width = 0.5,
        conditions = { 'gcdSeparate' },
        options = NRSKNUI.ColorModeOptions,
        value = gcd.RingColorMode,
        callback = function(key)
            gcd.RingColorMode = key
            ApplySettings()
            page:Refresh()
        end,
    })
    gcdColorRow:ColorPicker(L['Custom Color'], {
        width = 0.5,
        conditions = { 'gcdSeparate', 'gcdRingCustom' },
        value = gcd.RingColor,
        callback = function(r, g, b, a)
            gcd.RingColor = { r, g, b, a }
            ApplySettings()
        end,
    })
end

GUI:RegisterPage('cursorCircle', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general', text = L['General Settings'] },
        { id = 'ring',    text = L['Main Ring'] },
        { id = 'gcd',     text = L['GCD Ring'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.Miscellaneous.CursorCircle
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'ring' then
            BuildRingTab(page, db)
        elseif tabId == 'gcd' then
            BuildGCDTab(page, db)
        end
    end,
})

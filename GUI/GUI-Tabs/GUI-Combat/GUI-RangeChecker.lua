---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@type RangeChecker?
local RangeChecker = NRSKNUI:GetModule('RangeChecker', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings()
    if RangeChecker then RangeChecker:ApplySettings() end
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    -- Card 1: Enable
    local enableCard = page:Card(L['Range Checker'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Range Checker'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Range Checker'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('RangeChecker', checked)
            page:Refresh()
        end,
    })

    -- Card 2: General Settings
    local generalCard = page:Card(L['General Settings'], 'all')
    local combatRow = generalCard:Row(rowH)
    combatRow:Checkbox(L['Show In Combat Only'], {
        width = 1,
        value = db.CombatOnly,
        callback = function(checked)
            db.CombatOnly = checked
            ApplySettings()
        end,
    })

    local throttleRow = generalCard:Row(rowHL, 0)
    throttleRow:Slider(L['Update Throttle'], {
        width = 1,
        min = 0,
        max = 1,
        step = 0.05,
        value = db.UpdateThrottle,
        callback = function(val)
            db.UpdateThrottle = val
        end,
    })
end

-- Color Settings Tab.
local function BuildColorSettingsTab(page, db)
    local colorCard = page:Card(L['Color Gradient'], 'all')
    local colorRow1 = colorCard:Row(rowH)
    colorRow1:ColorPicker(L['Far (40+ yards)'], {
        width = 0.5,
        value = db.ColorOne,
        callback = function(r, g, b, a)
            db.ColorOne = { r, g, b, a }
            ApplySettings()
        end,
    })
    colorRow1:ColorPicker(L['Mid-Far (20-40)'], {
        width = 0.5,
        value = db.ColorTwo,
        callback = function(r, g, b, a)
            db.ColorTwo = { r, g, b, a }
            ApplySettings()
        end,
    })

    local colorRow2 = colorCard:Row(rowHL, 0)
    colorRow2:ColorPicker(L['Mid-Close (10-20)'], {
        width = 0.5,
        value = db.ColorThree,
        callback = function(r, g, b, a)
            db.ColorThree = { r, g, b, a }
            ApplySettings()
        end,
    })
    colorRow2:ColorPicker(L['Close (0-10)'], {
        width = 0.5,
        value = db.ColorFour,
        callback = function(r, g, b, a)
            db.ColorFour = { r, g, b, a }
            ApplySettings()
        end,
    })
end

-- Font Settings Tab.
local function BuildFontSettingsTab(page, db)
    page:FontSettingsCard({ db = db, includeSoftOutline = true, onChangeCallback = ApplySettings, globalOverride = {}, })
end

-- Position Settings Tab.
local function BuildPositionSettingsTab(page, db)
    page:PositionCard({ db = db, showAnchorFrameType = true, showStrata = true, onChangeCallback = ApplySettings, })
end

GUI:RegisterPage('rangeChecker', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',  text = L['General Settings'] },
        { id = 'color',    text = L['Color Settings'] },
        { id = 'font',     text = L['Font Settings'] },
        { id = 'position', text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.RangeChecker
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'color' then
            BuildColorSettingsTab(page, db)
        elseif tabId == 'font' then
            BuildFontSettingsTab(page, db)
        elseif tabId == 'position' then
            BuildPositionSettingsTab(page, db)
        end
    end,
})

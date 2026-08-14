---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GearUtilityModule
local Gear = NRSKNUI:GetModule('GearUtility')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings()
    Gear:ApplySettings()
end

local function BuildTab(page, db)
    page:SetEnabled(function() return db.Enabled end)
    page:SetCondition('sockets', function() return db.Sockets.Enabled end)

    -- Card 1: Enable
    local enableCard = page:Card(L['Gear Util'])
    local enableRow = enableCard:Row(rowH)
    enableRow:Checkbox(L['Enable Gear Util'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Gear Util'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('GearUtility', checked)
            page:Refresh()
        end,
    })

    enableCard:Separator()

    local infoRowSize = 50
    local infoRow = enableCard:Row(infoRowSize, 0)
    infoRow:Text(NRSKNUI:ColorTextByTheme(L['Functionality Info']), {
        autoHeight = true,
        width = 1,
        height = infoRowSize,
        bgMode = 'hide',
        text = NRSKNUI:ColorTextByTheme('• ') .. L['Adds upgrade track letters to the character panel gear slots.'] .. '\n' ..
            NRSKNUI:ColorTextByTheme('• ') .. L['Adds a bar next to the character tabs for socketing gems and applying enchants from your bags.'],
        conditions = { 'all' },
    })

    -- Card 2: Item Track Indicators
    local trackCard = page:Card(L['Item Track Indicators'], 'all')
    local trackRow = trackCard:Row(rowHL, 0)
    trackRow:Checkbox(L['Show Item Track Letters'], {
        width = 1,
        value = db.TrackIndicators.Enabled,
        tooltip = L['Shows |cffFF8000M|r / |cffC74DC7H|r / |cff00B3FFC|r / |cff00CC00V|r / |cffFFFFFFA|r on the equipped gear slots for the Myth, Hero, Champion, Veteran and Adventurer tracks.'],
        callback = function(checked)
            db.TrackIndicators.Enabled = checked
            ApplySettings()
        end,
    })

    -- Card 3: Gem Sockets
    local socketCard = page:Card(L['Gem Sockets'], 'all')
    local socketEnableRow = socketCard:Row(rowH)
    socketEnableRow:Checkbox(L['Enable Gem Socket Helper'], {
        width = 1,
        value = db.Sockets.Enabled,
        tooltip = L['Shows the sockets of your equipped gear, click one to pick a gem from your bags.'],
        callback = function(checked)
            db.Sockets.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    socketCard:Separator()

    local emptyOnlyRow = socketCard:Row(rowH)
    emptyOnlyRow:Checkbox(L['Show Only Empty Sockets'], {
        width = 1,
        value = db.Sockets.ShowOnlyEmpty,
        conditions = { 'sockets' },
        tooltip = L['Hide sockets that already have a gem in them.'],
        callback = function(checked)
            db.Sockets.ShowOnlyEmpty = checked
            ApplySettings()
        end,
    })

    local sizeRow = socketCard:Row(rowHL, 0)
    sizeRow:Slider(L['Button Size'], {
        width = 0.5,
        min = 16,
        max = 48,
        step = 1,
        value = db.Sockets.ButtonSize,
        conditions = { 'sockets' },
        callback = function(val)
            db.Sockets.ButtonSize = val
            ApplySettings()
        end,
    })

    sizeRow:Slider(L['Button Spacing'], {
        width = 0.5,
        min = 0,
        max = 10,
        step = 1,
        value = db.Sockets.ButtonSpacing,
        conditions = { 'sockets' },
        callback = function(val)
            db.Sockets.ButtonSpacing = val
            ApplySettings()
        end,
    })

    -- Card 4: Enchants
    local enchantCard = page:Card(L['Enchants'], 'all')
    local enchantRow = enchantCard:Row(rowHL, 0)
    enchantRow:Checkbox(L['Enable Enchant Helper'], {
        width = 1,
        value = db.Enchants.Enabled,
        tooltip = L['Adds a button to the socket bar that applies enchants from your bags, highlighting the slots each one fits.'],
        callback = function(checked)
            db.Enchants.Enabled = checked
            ApplySettings()
        end,
    })
end

GUI:RegisterPage('gearUtil', {
    mode = 'clean',
    search = {},
    build = function(page)
        local db = NRSKNUI.db.profile.GearUtility
        if not db then return end

        BuildTab(page, db)
    end,
})

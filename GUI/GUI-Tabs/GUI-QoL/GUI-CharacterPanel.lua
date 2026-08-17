---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CharacterPanelModule
local CHAR = NRSKNUI:GetModule('CharacterPanel')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings()
    CHAR:ApplySettings()
end

local function BuildGearView(page, db)
    page:SetCondition('sockets', function() return db.Sockets.Enabled end)

    -- Card 1: Enable
    local enableCard = page:Card(L['Character Panel'])
    local enableRow = enableCard:Row(rowH)
    enableRow:Checkbox(L['Enable Character Panel'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Character Panel'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('CharacterPanel', checked)
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

local function BuildTextsView(page, db)
    page:SetCondition('customColor', function() return db.CategoryColorMode == 'custom' end)

    local ilvlCard = page:Card(L['Item Level'])
    local decimalRow = ilvlCard:Row(rowHL, 0)
    decimalRow:Checkbox(L['Show Decimal Item Level'], {
        width = 1,
        value = db.DecimalItemLevel,
        tooltip = L['Shows your average item level with 2 decimals instead of a rounded value.'],
        callback = function(checked)
            db.DecimalItemLevel = checked
            ApplySettings()
        end,
    })

    local nameCard = page:Card(L['Name & Level'])
    local factionRow = nameCard:Row(rowH)
    factionRow:Checkbox(L['Show Faction Tag'], {
        width = 1,
        value = db.FactionTag,
        tooltip = L['Appends |cff3399ff(A)|r or |cffe63333(H)|r to the level text.'],
        callback = function(checked)
            db.FactionTag = checked
            ApplySettings()
        end,
    })

    nameCard:Separator()

    local raceRow = nameCard:Row(rowHL, 0)
    raceRow:Checkbox(L['Show Realm & Race'], {
        width = 1,
        value = db.ShowRaceText,
        tooltip = L['Adds a line with your realm and race under the level text.'],
        callback = function(checked)
            db.ShowRaceText = checked
            ApplySettings()
        end,
    })

    local colorCard = page:Card(L['Category Titles'])
    local colorRow = colorCard:Row(rowHL, 0)
    colorRow:Dropdown(L['Color'], {
        width = 0.5,
        options = NRSKNUI.ColorModeOptions,
        value = db.CategoryColorMode,
        tooltip = L['Colors the Item Level, Attributes and Enhancements headers in the stats pane.'],
        callback = function(key)
            db.CategoryColorMode = key
            ApplySettings()
            page:Refresh()
        end,
    })
    colorRow:ColorPicker(L['Custom Color'], {
        width = 0.5,
        value = db.CategoryColor,
        conditions = { 'customColor' },
        callback = function(r, g, b, a)
            db.CategoryColor = { r, g, b, a }
            ApplySettings()
        end,
    })
end

local fontSizes = {
    { label = L['Name Text Size'],  dbKey = 'NameTextSize' },
    { label = L['Level Text Size'], dbKey = 'LevelTextSize' },
    { label = L['Category Size'],   dbKey = 'CategoryFontSize' },
    { label = L['Item Level Size'], dbKey = 'IlvlValueSize' },
    { label = L['Stats Size'],      dbKey = 'StatsFontSize' },
}

local function BuildFontsView(page, db)
    page:FontSettingsCard({
        db = db,
        fontSizes = fontSizes,
        fontSizeRange = { 8, 24 },
        includeSoftOutline = true,
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
end

local items = {
    { key = 'gear',  text = L['Gear'] },
    { key = 'texts', text = L['Panel Texts'] },
    { key = 'fonts', text = L['Fonts'] },
}

GUI:RegisterPage('characterPanel', {
    mode = 'clean',
    search = {
        L['Show Decimal Item Level'], L['Show Faction Tag'], L['Show Realm & Race'],
        L['Show Item Track Letters'], L['Enable Gem Socket Helper'], L['Enable Enchant Helper'],
    },
    sidebar = { items = items },
    build = function(page, _, itemKey)
        local db = NRSKNUI.db.profile.CharacterPanel
        if not db then return end

        page:SetEnabled(function() return db.Enabled end)

        if itemKey == 'texts' then
            BuildTextsView(page, db)
        elseif itemKey == 'fonts' then
            BuildFontsView(page, db)
        else
            BuildGearView(page, db)
        end
    end,
})

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class DungeonCastsModule
local DungeonCasts = NRSKNUI:GetModule('DungeonCasts', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local anchorOptions = {
    { key = 'LEFT',   text = L['Left'] },
    { key = 'CENTER', text = L['Center'] },
    { key = 'RIGHT',  text = L['Right'] },
}

local targetSideOptions = {
    { key = 'LEFT',  text = L['After Spell Name'] },
    { key = 'RIGHT', text = L['Before Timer'] },
}

local function ApplySettings() DungeonCasts:ApplySettings() end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    page:SetCondition('customBar', function() return not db.UseGlobalBar end)

    -- Card 1: Enable
    local enableCard = page:Card(L['Dungeon Casts'])
    local enableRow = enableCard:Row(rowH)
    enableRow:Checkbox(L['Enable Dungeon Casts'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Dungeon Casts'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('DungeonCasts', checked)
            page:Refresh()
        end,
    })

    enableCard:Separator()

    enableCard:Row(rowHL, 0):Checkbox(L['Hide Un-Pulled Mobs'], {
        width = 1,
        value = db.RequireCombat,
        callback = function(checked)
            db.RequireCombat = checked; ApplySettings()
        end,
    })

    -- Card 2: Bar Appearance
    local barCard = page:Card(L['Bar Appearance'], 'all')
    local sizeRow = barCard:Row(rowH)
    sizeRow:Slider(L['Width'], {
        width = 0.5,
        min = 100,
        max = 1000,
        step = 1,
        value = db.Width,
        callback = function(val)
            db.Width = val; ApplySettings()
        end,
    })
    sizeRow:Slider(L['Height'], {
        width = 0.5,
        min = 5,
        max = 200,
        step = 1,
        value = db.Height,
        callback = function(val)
            db.Height = val; ApplySettings()
        end,
    })

    local textureRow = barCard:Row(rowH)
    textureRow:Checkbox(L['Use Global Bar'], {
        width = 0.5,
        value = db.UseGlobalBar ~= false,
        callback = function(checked)
            db.UseGlobalBar = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    textureRow:Dropdown(L['Bar Texture'], {
        width = 0.5,
        media = 'statusbar',
        searchable = true,
        conditions = { 'customBar' },
        value = db.StatusBarTexture,
        callback = function(key)
            db.StatusBarTexture = key; ApplySettings()
        end,
    })

    local barColorRow = barCard:Row(rowHL, 0)
    barColorRow:ColorPicker(L['Background'], {
        width = 0.5,
        value = db.BackdropColor,
        callback = function(r, g, b, a)
            db.BackdropColor = { r, g, b, a }; ApplySettings()
        end,
    })
    barColorRow:ColorPicker(L['Border'], {
        width = 0.5,
        value = db.BorderColor,
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }; ApplySettings()
        end,
    })

    page:SparkSettingsCard({
        title = L['Spark'],
        db = db,
        onChangeCallback = ApplySettings,
        globalOverride = { label = L['Use Global Spark'] },
        labels = { texture = L['Spark Texture'], scale = L['Spark Scale'], width = L['Spark Width'], color = L['Spark Color'] },
    })
end

-- Layout Settings Tab.
local function BuildLayoutSettingsTab(page, db)
    page:DynamicGroupCard({ title = L['Layout'], db = db.Config, onChangeCallback = ApplySettings })
end

-- Colors Tab.
local function BuildColorSettingsTab(page, db)
    local colorsCard = page:Card(L['Colors'], 'all')
    colorsCard:Row(rowH):ColorPicker(L['Casting'], {
        width = 1,
        value = db.CastColor,
        callback = function(r, g, b, a)
            db.CastColor = { r, g, b, a }; ApplySettings()
        end,
    })

    colorsCard:Row(rowH):ColorPicker(L['Channeling'], {
        width = 1,
        value = db.ChannelColor,
        callback = function(r, g, b, a)
            db.ChannelColor = { r, g, b, a }; ApplySettings()
        end,
    })

    colorsCard:Row(rowH):ColorPicker(L['Uninterruptible'], {
        width = 1,
        value = db.NotInterruptibleColor,
        callback = function(r, g, b, a)
            db.NotInterruptibleColor = { r, g, b, a }; ApplySettings()
        end,
    })

    colorsCard:Separator()

    colorsCard:Row(rowHL, 0):ColorPicker(L['Text'], {
        width = 1,
        value = db.TextColor,
        callback = function(r, g, b, a)
            db.TextColor = { r, g, b, a }; ApplySettings()
        end,
    })
end

-- Icon, Marker & Target Tab.
local function BuildDisplaySettingsTab(page, db)
    page:SetCondition('raidIcon', function() return db.RaidIcon.Enabled end)
    page:SetCondition('target', function() return db.Target.Enabled end)

    -- Card 1: Icon & Timer
    local iconCard = page:Card(L['Icon & Timer'], 'all')
    iconCard:Row(rowH):Checkbox(L['Show Spell Icon'], {
        width = 1,
        value = db.Icon.Enabled,
        callback = function(checked)
            db.Icon.Enabled = checked; ApplySettings()
        end,
    })

    iconCard:Row(rowHL, 0):Checkbox(L['Show Cast Timer'], {
        width = 1,
        value = db.ShowTime,
        callback = function(checked)
            db.ShowTime = checked; ApplySettings()
        end,
    })

    -- Card 2: Raid Marker
    local markerCard = page:Card(L['Raid Marker'], 'all')
    local markerRow = markerCard:Row(rowH)
    markerRow:Checkbox(L['Show Raid Marker'], {
        width = 1,
        value = db.RaidIcon.Enabled,
        callback = function(checked)
            db.RaidIcon.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    markerCard:Separator()

    local markerSizeRow = markerCard:Row(rowH)
    markerSizeRow:Slider(L['Size'], {
        width = 0.5,
        min = 1,
        max = 100,
        step = 1,
        conditions = { 'raidIcon' },
        value = db.RaidIcon.Size,
        callback = function(val)
            db.RaidIcon.Size = val; ApplySettings()
        end,
    })
    markerSizeRow:Dropdown(L['Anchor'], {
        width = 0.5,
        options = anchorOptions,
        conditions = { 'raidIcon' },
        value = db.RaidIcon.Anchor,
        callback = function(key)
            db.RaidIcon.Anchor = key; ApplySettings()
        end,
    })

    local markerRow2 = markerCard:Row(rowHL, 0)
    markerRow2:Slider(L['X Offset'], {
        width = 0.5,
        min = -100,
        max = 100,
        step = 1,
        conditions = { 'raidIcon' },
        value = db.RaidIcon.XOffset,
        callback = function(val)
            db.RaidIcon.XOffset = val; ApplySettings()
        end,
    })
    markerRow2:Slider(L['Y Offset'], {
        width = 0.5,
        min = -100,
        max = 100,
        step = 1,
        conditions = { 'raidIcon' },
        value = db.RaidIcon.YOffset,
        callback = function(val)
            db.RaidIcon.YOffset = val; ApplySettings()
        end,
    })

    -- Card 3: Spell Target
    local targetCard = page:Card(L['Spell Target'], 'all')
    local targetRow = targetCard:Row(rowH)
    targetRow:Checkbox(L['Show Spell Target'], {
        width = 1,
        value = db.Target.Enabled,
        callback = function(checked)
            db.Target.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    targetCard:Separator()

    local targetRow2 = targetCard:Row(rowHL, 0)
    targetRow2:Checkbox(L['Class Color Target'], {
        width = 0.5,
        conditions = { 'target' },
        value = db.Target.ShowClassColor,
        callback = function(checked)
            db.Target.ShowClassColor = checked; ApplySettings()
        end,
    })

    targetRow2:Dropdown(L['Position'], {
        width = 0.25,
        options = targetSideOptions,
        conditions = { 'target' },
        value = db.Target.Position,
        callback = function(key)
            db.Target.Position = key; ApplySettings()
        end,
    })
    targetRow2:Dropdown(L['Separator Type'], {
        width = 0.25,
        options = NRSKNUI.Separators,
        conditions = { 'target' },
        value = db.Target.Separator,
        callback = function(key)
            db.Target.Separator = key; ApplySettings()
        end,
    })
end

-- Font Settings Tab.
local function BuildFontSettingsTab(page, db)
    page:FontSettingsCard({
        db = db,
        includeSoftOutline = false,
        fontSizes = {
            { label = L['Spell Name'], dbKey = 'FontSize' },
        },
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
end

-- Position Settings Tab.
local function BuildPositionSettingsTab(page, db)
    page:PositionCard({ db = db, showAnchorFrameType = true, showStrata = true, onChangeCallback = ApplySettings, })
end

GUI:RegisterPage('dungeonCasts', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',  text = L['General Settings'] },
        { id = 'layout',   text = L['Layout'] },
        { id = 'color',    text = L['Color Settings'] },
        { id = 'display',  text = L['Display Settings'] },
        { id = 'font',     text = L['Font Settings'] },
        { id = 'position', text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.DungeonCasts
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'layout' then
            BuildLayoutSettingsTab(page, db)
        elseif tabId == 'color' then
            BuildColorSettingsTab(page, db)
        elseif tabId == 'display' then
            BuildDisplaySettingsTab(page, db)
        elseif tabId == 'font' then
            BuildFontSettingsTab(page, db)
        elseif tabId == 'position' then
            BuildPositionSettingsTab(page, db)
        end
    end,
})

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class XPBarModule
local XPBar = NRSKNUI:GetModule('XPBar')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings()
    XPBar:ApplySettings()
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    local enableCard = page:Card(L['XP Bar'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable XP Bar'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['XP Bar'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('XPBar', checked)
            page:Refresh()
        end,
    })

    local cardGeneral = page:Card(L['General Settings'], 'all')
    local showRestedRow = cardGeneral:Row(rowH)
    showRestedRow:Checkbox(L['Show Rested Bar'], {
        width = 1,
        value = db.RestedShow,
        callback = function(checked)
            db.RestedShow = checked
            ApplySettings()
            page:Refresh()
        end
    })

    local showQuestRow = cardGeneral:Row(rowHL, 0)
    showQuestRow:Checkbox(L['Show Quest Bar'], {
        width = 1,
        value = db.QuestShow,
        callback = function(checked)
            db.QuestShow = checked
            ApplySettings()
            page:Refresh()
        end
    })
end

-- Bar Settings Tab.
local function BuildBarSettingsTab(page, db)
    local barSizeCard = page:Card(L['Bar Size'], 'all')
    local barSizeRow = barSizeCard:Row(rowHL, 0)
    barSizeRow:Slider(L['Bar Width'], {
        width = 0.5,
        min = 1,
        max = 1000,
        step = 1,
        value = db.width,
        callback = function(val)
            db.width = val
            ApplySettings()
        end
    })

    barSizeRow:Slider(L['Bar Height'], {
        width = 0.5,
        min = 1,
        max = 1000,
        step = 1,
        value = db.height,
        callback = function(val)
            db.height = val
            ApplySettings()
        end
    })

    local barTextureCard = page:Card(L['Bar Texture'], 'all')
    local globalTextureRow = barTextureCard:Row(rowH)
    globalTextureRow:Checkbox(L['Use Global Bar'], {
        width = 1,
        value = db.UseGlobalBar ~= false,
        callback = function(checked)
            db.UseGlobalBar = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    barTextureCard:Separator()

    local progressTexRow = barTextureCard:Row(rowH)
    progressTexRow:Dropdown(L['Progress Texture'], {
        width = 1,
        media = 'statusbar',
        value = db.StatusBarTexture,
        searchable = true,
        conditions = { 'GlobalOn' },
        callback = function(key)
            db.StatusBarTexture = key
            ApplySettings()
        end,
    })

    local questRestedTexRow = barTextureCard:Row(rowHL, 0)
    questRestedTexRow:Dropdown(L['Rested Texture'], {
        width = 0.5,
        media = 'statusbar',
        value = db.RestedTexture,
        searchable = true,
        conditions = { 'GlobalOn', 'RestedShowTexture' },
        callback = function(key)
            db.RestedTexture = key
            ApplySettings()
        end,
    })

    questRestedTexRow:Dropdown(L['Quest Texture'], {
        width = 0.5,
        media = 'statusbar',
        value = db.QuestTexture,
        searchable = true,
        conditions = { 'GlobalOn', 'QuestShowTexture' },
        callback = function(key)
            db.QuestTexture = key
            ApplySettings()
        end,
    })
end

-- Color Settings Tab.
local function BuildColorSettingsTab(page, db)
    local colorCard = page:Card(L['Color Settings'], 'all')
    local foreGroundColorRow = colorCard:Row(rowH)
    foreGroundColorRow:Dropdown(L['Foreground Color Mode'], {
        width = 0.5,
        options = NRSKNUI.ColorModeOptions,
        value = db.ColorMode,
        callback = function(key)
            db.ColorMode = key
            ApplySettings()
            page:Refresh()
        end
    })

    foreGroundColorRow:ColorPicker(L['Custom Foreground Color'], {
        width = 0.5,
        value = db.StatusColor,
        conditions = { 'custom' },
        callback = function(r, g, b, a)
            db.StatusColor = { r, g, b, a }
            ApplySettings()
        end
    })

    local restedColorRow = colorCard:Row(rowH)
    restedColorRow:Dropdown(L['Rested Color Mode'], {
        width = 0.5,
        options = NRSKNUI.ColorModeOptions,
        value = db.ColorModeRested,
        conditions = { 'RestedShowMode' },
        callback = function(key)
            db.ColorModeRested = key
            ApplySettings()
            page:Refresh()
        end
    })

    restedColorRow:ColorPicker(L['Custom Rested Color'], {
        width = 0.5,
        value = db.RestedColor,
        conditions = { 'customRested' },
        callback = function(r, g, b, a)
            db.RestedColor = { r, g, b, a }
            ApplySettings()
        end
    })

    local questColorRow = colorCard:Row(rowH)
    questColorRow:Dropdown(L['Quest Color Mode'], {
        width = 0.5,
        options = NRSKNUI.ColorModeOptions,
        value = db.ColorModeQuest,
        conditions = { 'QuestShowMode' },
        callback = function(key)
            db.ColorModeQuest = key
            ApplySettings()
            page:Refresh()
        end
    })

    questColorRow:ColorPicker(L['Custom Quest Color'], {
        width = 0.5,
        value = db.QuestColor,
        conditions = { 'customQuest' },
        callback = function(r, g, b, a)
            db.QuestColor = { r, g, b, a }
            ApplySettings()
        end
    })

    colorCard:Separator()

    local backdropColorRow = colorCard:Row(rowH)
    backdropColorRow:ColorPicker(L['Backdrop Color'], {
        width = 0.5,
        value = db.BackgroundColor,
        callback = function(r, g, b, a)
            db.BackgroundColor = { r, g, b, a }
            ApplySettings()
        end
    })

    backdropColorRow:ColorPicker(L['Border Color'], {
        width = 0.5,
        value = db.BorderColor,
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }
            ApplySettings()
        end
    })

    colorCard:Separator()

    local textColorRow = colorCard:Row(rowHL, 0)
    textColorRow:ColorPicker(L['Text Color'], {
        width = 1,
        value = db.TextColor,
        callback = function(r, g, b, a)
            db.TextColor = { r, g, b, a }
            ApplySettings()
        end
    })
end

-- Font Settings Tab.
local function BuildFontSettingsTab(page, db)
    page:FontSettingsCard({ db = db, onChangeCallback = ApplySettings, globalOverride = {}, })
end

-- Position Settings Tab.
local function BuildPositionSettingsTab(page, db)
    page:PositionCard({ db = db, showAnchorFrameType = false, showStrata = true, onChangeCallback = ApplySettings, })
end

GUI:RegisterPage('XPBar', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general', text = L['General Settings'] },
        { id = 'bar',     text = L['Bar Settings'] },
        { id = 'color',   text = L['Color Settings'] },
        { id = 'font',    text = L['Font Settings'] },
        { id = 'layout',  text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.Miscellaneous.XPBar
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)
        page:SetCondition('GlobalOn', function() return not db.UseGlobalBar end)
        page:SetCondition('custom', function() return db.ColorMode == 'custom' and db.Enabled end)
        page:SetCondition('customRested', function() return db.RestedShow and db.ColorModeRested == 'custom' and db.Enabled end)
        page:SetCondition('customQuest', function() return db.QuestShow and db.ColorModeQuest == 'custom' and db.Enabled end)
        page:SetCondition('QuestShowTexture', function() return db.QuestShow and db.Enabled and not db.UseGlobalBar end)
        page:SetCondition('RestedShowTexture', function() return db.RestedShow and db.Enabled and not db.UseGlobalBar end)
        page:SetCondition('QuestShowMode', function() return db.QuestShow and db.Enabled end)
        page:SetCondition('RestedShowMode', function() return db.RestedShow and db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'bar' then
            BuildBarSettingsTab(page, db)
        elseif tabId == 'color' then
            BuildColorSettingsTab(page, db)
        elseif tabId == 'font' then
            BuildFontSettingsTab(page, db)
        elseif tabId == 'layout' then
            BuildPositionSettingsTab(page, db)
        end
    end,
})

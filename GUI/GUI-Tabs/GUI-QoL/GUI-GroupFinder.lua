---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GroupFinderModule
local GroupFinder = NRSKNUI:GetModule('GroupFinder')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local SCORE_SOURCE_OPTIONS = {
    { key = 'blizzard', text = L['Blizzard'] },
    { key = 'raiderio', text = L['Raider.IO'] },
}

local ROLE_ICON_OPTIONS = {
    { key = 'bar',    text = L['Class Bar'] },
    { key = 'circle', text = L['Class Circle'] },
}

local SORT_OPTIONS = {
    { key = 'default',      text = L['Default'] },
    { key = 'overallScore', text = L['Leader Score'] },
    { key = 'dungeonScore', text = L['Dungeon Score'] },
}

local function ApplySettings()
    GroupFinder:ApplySettings()
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    local enableCard = page:Card(L['Group Finder'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Group Finder'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Group Finder'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('GroupFinder', checked)
            page:Refresh()
        end,
    })

    local panelCard = page:Card(L['Side Panel'], 'all')
    local panelRow = panelCard:Row(rowH)
    panelRow:Checkbox(L['Show Side Panel'], {
        width = 0.5,
        value = db.ShowPanel,
        callback = function(checked)
            db.ShowPanel = checked
            ApplySettings()
        end,
    })
    panelRow:Slider(L['Panel Width'], {
        width = 0.5,
        min = 140,
        max = 260,
        step = 2,
        value = db.PanelWidth,
        callback = function(val)
            db.PanelWidth = val
            ApplySettings()
        end,
    })

    local sortRow = panelCard:Row(rowHL, 0)
    sortRow:Dropdown(L['Sort Order'], {
        width = 0.5,
        options = SORT_OPTIONS,
        value = db.SortBy,
        callback = function(key)
            db.SortBy = key
            GroupFinder:RefreshResults()
            GroupFinder:RefreshPanel()
        end,
    })
    sortRow:Checkbox(L['Descending'], {
        width = 0.5,
        value = db.SortDescending,
        callback = function(checked)
            db.SortDescending = checked
            GroupFinder:RefreshResults()
            GroupFinder:RefreshPanel()
        end,
    })
end

-- Results Settings Tab.
local function BuildResultsSettingsTab(page, db)
    local resultsCard = page:Card(L['Search Results'])
    local scoreRow = resultsCard:Row(rowH)
    scoreRow:Checkbox(L['Show Leader Score'], {
        width = 0.5,
        value = db.ShowLeaderScore,
        callback = function(checked)
            db.ShowLeaderScore = checked
            ApplySettings()
        end,
    })

    local raiderIOReady = GroupFinder:IsRaiderIOAvailable()
    scoreRow:Dropdown(L['Score Colors'], {
        width = 0.5,
        options = SCORE_SOURCE_OPTIONS,
        value = raiderIOReady and db.ScoreColorSource or 'blizzard',
        disabled = not raiderIOReady,
        tooltip = not raiderIOReady and L['Requires the RaiderIO addon.'] or nil,
        callback = function(key)
            db.ScoreColorSource = key
            ApplySettings()
        end,
    })

    local iconRow = resultsCard:Row(rowHL, 0)
    iconRow:Dropdown(L['Role Icons'], {
        width = 1,
        options = ROLE_ICON_OPTIONS,
        value = db.RoleIconStyle,
        callback = function(key)
            db.RoleIconStyle = key
            ApplySettings()
        end,
    })

    page:FontSettingsCard({ db = db, onChangeCallback = ApplySettings, globalOverride = {}, })
end

GUI:RegisterPage('groupFinder', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general', text = L['General Settings'] },
        { id = 'results', text = L['Search Results'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.Miscellaneous.GroupFinder
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'results' then
            BuildResultsSettingsTab(page, db)
        end
    end,
})

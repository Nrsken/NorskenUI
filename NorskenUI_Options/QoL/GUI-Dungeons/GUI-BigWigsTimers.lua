---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_QoL') then return end
---@class BigWigsTimersModule
local BigWigsTimers = NRSKNUI:GetModule('BigWigsTimers')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings() BigWigsTimers:ApplySettings() end

-- Display --

-- one tab per kind of timer (bar, text), each kind's look out to where its group sits in one scroll

---@param page KajiGUIPage
---@param db table
local function BuildBarCard(page, db)
    local card = page:Card(L['Bar'], 'all')
    local sizeRow = card:Row(rowH)
    sizeRow:Slider(L['Width'], {
        width = 0.5,
        min = 60,
        max = 800,
        step = 1,
        value = db.Width,
        callback = function(val)
            db.Width = val
            ApplySettings()
        end,
    })
    sizeRow:Slider(L['Height'], {
        width = 0.5,
        min = 5,
        max = 100,
        step = 1,
        value = db.Height,
        callback = function(val)
            db.Height = val
            ApplySettings()
        end,
    })

    local textureRow = card:Row(rowH)
    textureRow:Checkbox(L['Use Global Bar'], {
        width = 0.5,
        value = db.UseGlobalBar,
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
            db.StatusBarTexture = key
            ApplySettings()
        end,
    })

    card:Row(rowHL, 0):Checkbox(L['Show Spell Icon'], {
        width = 1,
        value = db.Icon.Enabled,
        callback = function(checked)
            db.Icon.Enabled = checked
            ApplySettings()
        end,
    })
end

---The cards both kinds share, after whatever is the kind's own.
---@param page KajiGUIPage
---@param db table
---@param fontSizeLabel string
local function BuildGroupCards(page, db, fontSizeLabel)
    page:FontSettingsCard({
        db = db,
        fontSizes = { { label = fontSizeLabel, dbKey = 'FontSize' } },
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
    page:DynamicGroupCard({ db = db.Config, onChangeCallback = ApplySettings })
    page:PositionCard({
        db = db,
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })
end

GUI:RegisterPage('bwTimersDisplay', {
    mode = 'tabs',
    search = { L['BigWigs Timers'], L['Boss Mod Timer'], L['Bar Settings'], L['Text Settings'] },
    tabs = {
        { id = 'bars',  text = L['Bars'] },
        { id = 'texts', text = L['Texts'] },
    },
    build = function(page, tabId)
        local module = NRSKNUI.BigWigsTimers.db
        page:SetEnabled(function() return module.Enabled end)

        if tabId == 'texts' then
            BuildGroupCards(page, module.Texts, L['Text Size'])
            return
        end

        local db = module.Bars
        page:SetCondition('customBar', function() return not db.UseGlobalBar end)
        BuildBarCard(page, db)
        page:BackdropColorsCard({ db = db, onChangeCallback = ApplySettings })
        BuildGroupCards(page, db, L['Bar Text'])
    end,
})

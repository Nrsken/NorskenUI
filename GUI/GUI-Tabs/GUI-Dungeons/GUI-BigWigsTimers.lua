---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class BigWigsTimersModule
local BigWigsTimers = NRSKNUI:GetModule('BigWigsTimers')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings() BigWigsTimers:ApplySettings() end

-- General --

GUI:RegisterPage('bwTimers', {
    mode = 'clean',
    search = { L['BigWigs Timers'], L['Boss Mod Timer'] },
    build = function(page)
        local db = NRSKNUI.db.profile.BigWigsTimers

        local enableCard = page:Card(L['BigWigs Timers'])
        enableCard:Row(rowH):Checkbox(L['Enable BigWigs Timers'], {
            width = 1,
            master = true,
            value = db.Enabled,
            msgPopup = true,
            msgText = L['BigWigs Timers'],
            callback = function(checked)
                db.Enabled = checked
                NRSKNUI:ToggleModule('BigWigsTimers', checked)
                page:Refresh()
            end,
        })

        enableCard:Separator()

        enableCard:Row(rowHL, 0):Text(L['About'], {
            width = 1,
            autoHeight = true,
            bgMode = 'hide',
            text = NRSKNUI:ColorTextByTheme('• ') ..
                L['Timers are configured per instance under Dungeons and Raids. Dungeons follow the season BigWigs reports; raids are grouped by boss and limited to the current tier.'],
        })
    end,
})

-- Bar and text groups --

---@param page KajiGUIPage
---@param db table
local function BuildBarAppearance(page, db)
    local sizeCard = page:Card(L['Bar Appearance'], 'all')
    local sizeRow = sizeCard:Row(rowH)

    sizeRow:Slider(L['Width'], {
        width = 0.5,
        min = 60,
        max = 800,
        step = 1,
        value = db.Width,
        callback = function(val)
            db.Width = val; ApplySettings()
        end,
    })
    sizeRow:Slider(L['Height'], {
        width = 0.5,
        min = 5,
        max = 100,
        step = 1,
        value = db.Height,
        callback = function(val)
            db.Height = val; ApplySettings()
        end,
    })

    local textureRow = sizeCard:Row(rowH)
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
            db.StatusBarTexture = key; ApplySettings()
        end,
    })

    sizeCard:Row(rowHL, 0):Checkbox(L['Show Spell Icon'], {
        width = 1,
        value = db.Icon.Enabled,
        callback = function(checked)
            db.Icon.Enabled = checked; ApplySettings()
        end,
    })

    local colorCard = page:Card(L['Colors'], 'all')
    local colorRow = colorCard:Row(rowHL, 0)

    colorRow:ColorPicker(L['Background'], {
        width = 0.5,
        value = db.BackdropColor,
        callback = function(r, g, b, a)
            db.BackdropColor = { r, g, b, a }; ApplySettings()
        end,
    })
    colorRow:ColorPicker(L['Border'], {
        width = 0.5,
        value = db.BorderColor,
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }; ApplySettings()
        end,
    })
end

---One registration for each group. The text group has nothing to put on an Appearance tab: its
---alignment is the dynamic group's own Align setting, on the Layout tab.
---@param pageId string
---@param dbKey 'Bars'|'Texts'
---@param title string
---@param BuildAppearance? fun(page: KajiGUIPage, db: table)
---@param fontSizeLabel string
local function RegisterGroupPage(pageId, dbKey, title, BuildAppearance, fontSizeLabel)
    local tabs = {
        { id = 'layout',   text = L['Layout'] },
        { id = 'font',     text = L['Font Settings'] },
        { id = 'position', text = L['Position Settings'] },
    }

    if BuildAppearance then
        table.insert(tabs, 1, { id = 'appearance', text = L['Appearance'] })
    end

    GUI:RegisterPage(pageId, {
        mode = 'tabs',
        search = { title },
        tabs = tabs,
        build = function(page, tabId)
            local db = NRSKNUI.db.profile.BigWigsTimers[dbKey]

            page:SetEnabled(function() return NRSKNUI.db.profile.BigWigsTimers.Enabled end)
            page:SetCondition('customBar', function() return not db.UseGlobalBar end)

            if tabId == 'appearance' and BuildAppearance then
                BuildAppearance(page, db)
            elseif tabId == 'layout' then
                page:DynamicGroupCard({ db = db.Config, onChangeCallback = ApplySettings })
            elseif tabId == 'font' then
                page:FontSettingsCard({
                    db = db,
                    fontSizes = { { label = fontSizeLabel, dbKey = 'FontSize' } },
                    onChangeCallback = ApplySettings,
                    globalOverride = {},
                })
            elseif tabId == 'position' then
                page:PositionCard({
                    db = db,
                    showAnchorFrameType = true,
                    showStrata = true,
                    onChangeCallback = ApplySettings,
                })
            end
        end,
    })
end

RegisterGroupPage('bwTimersBars', 'Bars', L['Bar Settings'], BuildBarAppearance, L['Bar Text'])
RegisterGroupPage('bwTimersTexts', 'Texts', L['Text Settings'], nil, L['Text Size'])

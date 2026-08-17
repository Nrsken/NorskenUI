---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class RerollKeystoneModule
local RerollKeystone = NRSKNUI:GetModule('RerollKeystone', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings() RerollKeystone:ApplySettings() end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    -- Card 1: Enable
    local enableCard = page:Card(L['Reroll Keystone'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Reroll Keystone'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Reroll Keystone'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('RerollKeystone', checked)
            page:Refresh()
        end,
    })

    -- Card 2: Appearance
    local appearanceCard = page:Card(L['Appearance'], 'all')
    local sizeRow = appearanceCard:Row(rowH)
    sizeRow:Slider(L['Icon Size'], {
        width = 1,
        min = 20,
        max = 120,
        step = 1,
        value = db.Size,
        callback = function(val)
            db.Size = val; ApplySettings()
        end,
    })

    local colorRow = appearanceCard:Row(rowHL, 0)
    colorRow:ColorPicker(L['Text Color'], {
        width = 0.5,
        value = db.FontColor,
        callback = function(r, g, b, a)
            db.FontColor = { r, g, b, a }; ApplySettings()
        end,
    })
    colorRow:ColorPicker(L['Key Text Color'], {
        width = 0.5,
        value = db.FontColorKey,
        callback = function(r, g, b, a)
            db.FontColorKey = { r, g, b, a }; ApplySettings()
        end,
    })
end

-- Font Settings Tab.
local function BuildFontSettingsTab(page, db)
    page:FontSettingsCard({
        db = db,
        fontSizes = {
            { label = L['Text Size'],     dbKey = 'FontSize' },
            { label = L['Key Text Size'], dbKey = 'FontSizeKey' },
        },
        includeSoftOutline = false,
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
end

-- Position Settings Tab.
local function BuildPositionSettingsTab(page, db)
    page:PositionCard({ db = db, showAnchorFrameType = true, showStrata = true, onChangeCallback = ApplySettings, })
end

GUI:RegisterPage('rerollKeystone', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',  text = L['General Settings'] },
        { id = 'font',     text = L['Font Settings'] },
        { id = 'position', text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.RerollKeystone
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'font' then
            BuildFontSettingsTab(page, db)
        elseif tabId == 'position' then
            BuildPositionSettingsTab(page, db)
        end
    end,
})

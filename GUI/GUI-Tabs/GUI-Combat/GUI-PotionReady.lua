---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class PotionReadyModule
local PotionReady = NRSKNUI:GetModule('PotionReady', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowHL = Theme.rowHeightLast

local function ApplySettings()
    if PotionReady then PotionReady:ApplySettings() end
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    -- Card 1: Enable
    local enableCard = page:Card(L['Potion Ready'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Potion Ready'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Potion Ready'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('PotionReady', checked)
            page:Refresh()
        end,
    })

    -- Card 2: Appearance
    local appearanceCard = page:Card(L['Appearance'], 'all')
    local appearanceRow = appearanceCard:Row(rowHL, 0)
    appearanceRow:EditBox(L['Alert Text'], {
        width = 0.5,
        value = db.Text,
        callback = function(value)
            db.Text = value
            ApplySettings()
            if PotionReady and PotionReady.alertFrame and PotionReady.alertFrame.text then
                PotionReady.alertFrame.text:SetText(value)
            end
        end,
    })
    appearanceRow:ColorPicker(L['Alert Color'], {
        width = 0.5,
        value = db.Color,
        callback = function(r, g, b, a)
            db.Color = { r, g, b, a }
            ApplySettings()
        end,
    })
end

-- Load Conditions Tab.
local function BuildLoadConditionsTab(page, db)
    db.LoadConditions = db.LoadConditions or NRSKNUI.LoadConditions:GetDefaults()
    page:LoadConditionsCard({
        db = db.LoadConditions,
        onChangeCallback = function()
            if PotionReady then PotionReady:UpdateCooldownState() end
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

GUI:RegisterPage('potionReady', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',    text = L['General Settings'] },
        { id = 'conditions', text = L['Load Conditions'] },
        { id = 'font',       text = L['Font Settings'] },
        { id = 'position',   text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.PotionReady
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'conditions' then
            BuildLoadConditionsTab(page, db)
        elseif tabId == 'font' then
            BuildFontSettingsTab(page, db)
        elseif tabId == 'position' then
            BuildPositionSettingsTab(page, db)
        end
    end,
})

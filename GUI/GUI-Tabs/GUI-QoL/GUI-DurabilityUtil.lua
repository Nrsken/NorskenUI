---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class DurabilityModule
local Durability = NRSKNUI:GetModule('Durability')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings()
    Durability:ApplySettings()
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    local enableCard = page:Card(L['Durability Util'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Durability Low Warning'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Durability Low Warning'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('Durability', checked)
            page:Refresh()
        end,
    })

    local cardGeneral = page:Card(L['General Settings'], 'all')
    local lowThresholdRow = cardGeneral:Row(rowH)
    lowThresholdRow:EditBox(L['Low Threshold Text'], {
        width = 0.5,
        value = db.TextLow,
        callback = function(val)
            db.TextLow = val
            ApplySettings()
        end,
    })

    lowThresholdRow:ColorPicker(L['Low Threshold Color'], {
        width = 0.5,
        value = db.TextColorLow,
        callback = function(r, g, b, a)
            db.TextColorLow = { r, g, b, a }
            ApplySettings()
        end
    })

    local brokenThresholdRow = cardGeneral:Row(rowH)
    brokenThresholdRow:EditBox(L['Broken Text'], {
        width = 0.5,
        value = db.TextBroken,
        callback = function(val)
            db.TextBroken = val
            ApplySettings()
        end,
    })

    brokenThresholdRow:ColorPicker(L['Broken Color'], {
        width = 0.5,
        value = db.TextColorBroken,
        callback = function(r, g, b, a)
            db.TextColorBroken = { r, g, b, a }
            ApplySettings()
        end
    })

    cardGeneral:Separator()

    local thresholdRow = cardGeneral:Row(rowHL, 0)
    thresholdRow:Slider('|cff4dff00' .. L['Out of Combat'] .. '|r ' .. L['Threshold %'], {
        width = 0.5,
        min = 1,
        max = 100,
        step = 1,
        value = db.ShowPercent,
        callback = function(val)
            db.ShowPercent = val
            ApplySettings()
        end
    })

    thresholdRow:Slider('|cffff0000' .. L['In Combat'] .. '|r ' .. L['Threshold %'], {
        width = 0.5,
        min = 0,
        max = 100,
        step = 1,
        value = db.CombatShowPercent,
        callback = function(val)
            db.CombatShowPercent = val
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
    page:PositionCard({ db = db, showAnchorFrameType = true, showStrata = true, onChangeCallback = ApplySettings, })
end

GUI:RegisterPage('durabilityUtil', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general', text = L['General Settings'] },
        { id = 'font',    text = L['Font Settings'] },
        { id = 'layout',  text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.Miscellaneous.Durability
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'font' then
            BuildFontSettingsTab(page, db)
        elseif tabId == 'layout' then
            BuildPositionSettingsTab(page, db)
        end
    end,
})

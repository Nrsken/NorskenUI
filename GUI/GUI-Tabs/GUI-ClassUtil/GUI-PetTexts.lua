---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@type PetTexts?
local PetTexts = NRSKNUI:GetModule('PetTexts', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings()
    if PetTexts then PetTexts:ApplySettings() end
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    -- Card 1: Enable
    local enableCard = page:Card(L['Pet Status Texts'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Pet Status Texts'], {
        width = 1,
        master = true,
        value = db.Enabled ~= false,
        msgPopup = true,
        msgText = L['Pet Status Texts'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('PetTexts', checked)
            page:Refresh()
            if checked and PetTexts then PetTexts:ShowPreview() end
        end,
    })

    -- Card 2: State Settings
    local stateCard = page:Card(L['State Settings'], 'all')

    local missingRow = stateCard:Row(rowH)
    missingRow:EditBox(L['Pet Missing Text'], {
        width = 0.5,
        value = db.PetMissing,
        callback = function(val)
            db.PetMissing = val
            ApplySettings()
        end,
    })
    missingRow:ColorPicker(L['Missing Color'], {
        width = 0.5,
        value = db.MissingColor,
        callback = function(r, g, b, a)
            db.MissingColor = { r, g, b, a }
            ApplySettings()
        end,
    })

    local deadRow = stateCard:Row(rowH)
    deadRow:EditBox(L['Pet Dead Text'], {
        width = 0.5,
        value = db.PetDead,
        callback = function(val)
            db.PetDead = val
            ApplySettings()
        end,
    })
    deadRow:ColorPicker(L['Dead Color'], {
        width = 0.5,
        value = db.DeadColor,
        callback = function(r, g, b, a)
            db.DeadColor = { r, g, b, a }
            ApplySettings()
        end,
    })

    local passiveRow = stateCard:Row(rowHL, 0)
    passiveRow:EditBox(L['Pet Passive Text'], {
        width = 0.5,
        value = db.PetPassive,
        callback = function(val)
            db.PetPassive = val
            ApplySettings()
        end,
    })
    passiveRow:ColorPicker(L['Passive Color'], {
        width = 0.5,
        value = db.PassiveColor,
        callback = function(r, g, b, a)
            db.PassiveColor = { r, g, b, a }
            ApplySettings()
        end,
    })
end

-- Font Settings Tab.
local function BuildFontSettingsTab(page, db)
    page:FontSettingsCard({ db = db, includeSoftOutline = true, onChangeCallback = ApplySettings, globalOverride = {}, })
end

-- Position Settings Tab.
local function BuildPositionSettingsTab(page, db)
    page:PositionCard({ db = db, showAnchorFrameType = false, showStrata = true, onChangeCallback = ApplySettings, })
end

GUI:RegisterPage('petTexts', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',  text = L['General Settings'] },
        { id = 'font',     text = L['Font Settings'] },
        { id = 'position', text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.PetTexts
        if not db then return end
        page:SetEnabled(function() return db.Enabled ~= false end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'font' then
            BuildFontSettingsTab(page, db)
        elseif tabId == 'position' then
            BuildPositionSettingsTab(page, db)
        end
    end,
})

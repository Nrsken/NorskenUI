---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_QoL') then return end
---@class GatewayModule
local Gateway = NRSKNUI:GetModule('Gateway', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowHL = Theme.rowHeightLast

local function ApplySettings()
    Gateway:ApplySettings()
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    -- Card 1: Appearance
    local appearanceCard = page:Card(L['Appearance'], 'all')
    local appearanceRow = appearanceCard:Row(rowHL, 0)
    appearanceRow:EditBox(L['Alert Text'], {
        width = 0.5,
        value = db.Text,
        callback = function(val)
            db.Text = val
            ApplySettings()
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

-- Font Settings Tab.
local function BuildFontSettingsTab(page, db)
    page:FontSettingsCard({ db = db, includeSoftOutline = true, onChangeCallback = ApplySettings, globalOverride = {}, })
end

-- Position Settings Tab.
local function BuildPositionSettingsTab(page, db)
    page:PositionCard({ db = db, showAnchorFrameType = false, showStrata = true, onChangeCallback = ApplySettings, })
end

GUI:RegisterPage('gateway', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',  text = L['General Settings'] },
        { id = 'font',     text = L['Font Settings'] },
        { id = 'position', text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.Gateway.db
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

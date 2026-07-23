---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class Tweaks
local Tweaks = NRSKNUI:GetModule('Tweaks')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings()
    Tweaks:ApplySettings()
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    local enableCard = page:Card(L['Tweaks'])
    local enableRow = enableCard:Row(rowH)
    enableRow:Checkbox(L['Enable Tweaks'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Tweaks'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('Tweaks', checked)
            page:Refresh()
        end,
    })
end

-- Hide Misc Elements Tab.
local function BuildHideMiscElementsTab(page, db)
    local hideCard = page:Card(L['Hide Misc Elements'], 'all')
    local hideTalkingHeadRow = hideCard:Row(rowH)
    hideTalkingHeadRow:Checkbox(L['Hide Talking Head Frame'], {
        width = 1,
        value = db.HideTalkingHead,
        callback = function(checked)
            db.HideTalkingHead = checked
            ApplySettings()
        end
    })

    hideCard:Separator()

    local hideBossBannerRow = hideCard:Row(rowHL, 0)
    hideBossBannerRow:Checkbox(L['Hide Boss Banner'], {
        width = 1,
        value = db.HideBossBanner,
        callback = function(checked)
            db.HideBossBanner = checked
            ApplySettings()
        end,
    })
end

-- Misc Tweaks Tab.
local function BuildMiscTweaksTab(page, db)
    local miscCard = page:Card(L['Misc Tweaks'], 'all')
    local confirmPopupsRow = miscCard:Row(rowHL, 0)
    confirmPopupsRow:Checkbox(L['Confirm Popups with Enter'], {
        width = 1,
        value = db.EnterAccept,
        callback = function(checked)
            db.EnterAccept = checked
            ApplySettings()
            if not checked then
                NRSKNUI:CreateReloadPrompt("Disabling this setting requires a UI reload to take effect. Reload now?")
            end
        end
    })
end

GUI:RegisterPage('tweaks', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general', text = L['General Settings'] },
        { id = 'hide',    text = L['Hide Misc Elements'] },
        { id = 'misc',    text = L['Misc Tweaks'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.Miscellaneous.Tweaks
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'hide' then
            BuildHideMiscElementsTab(page, db)
        elseif tabId == 'misc' then
            BuildMiscTweaksTab(page, db)
        end
    end,
})

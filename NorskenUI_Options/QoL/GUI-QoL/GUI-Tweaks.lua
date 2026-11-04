---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_QoL') then return end
---@class TweaksModule
local Tweaks = NRSKNUI:GetModule('Tweaks')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings()
    Tweaks:ApplySettings()
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

-- Whisper Sounds Tab.
local function BuildWhisperSoundsTab(page, db)
    local ws = db.WhisperSounds
    page:SetCondition('whisperSounds', function() return ws.Enabled end)

    local enableCard = page:Card(L['Whisper Sound Alerts'], 'all')
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Whisper Sounds'], {
        width = 1,
        value = ws.Enabled,
        callback = function(checked)
            ws.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    local soundCard = page:Card(L['Sound Selection'], 'all')
    local sounds = {
        { label = L['Whisper Sound'],          dbKey = 'WhisperSound' },
        { label = L['Battle.net Whisper Sound'], dbKey = 'BNetWhisperSound', last = true },
    }

    for _, sound in ipairs(sounds) do
        local row = soundCard:Row(sound.last and rowHL or rowH, sound.last and 0 or nil)
        row:Dropdown(sound.label, {
            width = 0.6,
            media = 'sound',
            searchable = true,
            conditions = { 'whisperSounds' },
            value = ws[sound.dbKey],
            callback = function(key) ws[sound.dbKey] = key end,
        })
        row:Button(L['Test'], {
            width = 0.4,
            yOffset = -14,
            height = 24,
            conditions = { 'whisperSounds' },
            callback = function() NRSKNUI:PlaySafeSound(ws[sound.dbKey]) end,
        })
    end
end

-- Misc Tweaks Tab.
local function BuildMiscTweaksTab(page, db)
    local miscCard = page:Card(L['Misc Tweaks'], 'all')
    miscCard:Row(rowH):Checkbox(L['Fix Blizzard Bugs'], {
        width = 1,
        tooltip = L['On login, untracks hidden quests and completed achievements stuck in the tracker, and keeps the dressing room maximized after a reset.'],
        value = db.FixBlizzardBugs,
        callback = function(checked)
            db.FixBlizzardBugs = checked
            ApplySettings()
        end
    })

    miscCard:Separator()

    local confirmPopupsRow = miscCard:Row(rowHL, 0)
    confirmPopupsRow:Checkbox(L['Confirm Popups with Enter'], {
        width = 1,
        value = db.EnterAccept,
        callback = function(checked)
            db.EnterAccept = checked
            ApplySettings()
            if not checked then
                NRSKNUI:CreateReloadPrompt(L['Disabling this setting requires a UI reload to take effect. Reload now?'])
            end
        end
    })
end

GUI:RegisterPage('tweaks', {
    mode = 'tabs',
    search = {},
    -- the on/off is the module header's, so the first tab is the first set of tweaks
    tabs = {
        { id = 'hide',    text = L['Hide Misc Elements'] },
        { id = 'misc',    text = L['Misc Tweaks'] },
        { id = 'whisper', text = L['Whisper Sounds'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.Tweaks.db
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'hide' then
            BuildHideMiscElementsTab(page, db)
        elseif tabId == 'misc' then
            BuildMiscTweaksTab(page, db)
        elseif tabId == 'whisper' then
            BuildWhisperSoundsTab(page, db)
        end
    end,
})

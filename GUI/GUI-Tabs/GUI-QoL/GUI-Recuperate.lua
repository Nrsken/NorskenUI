---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class Recuperate
local Recuperate = NRSKNUI:GetModule('Recuperate')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings()
    Recuperate:ApplySettings()
    Recuperate:UpdateStateDriver()
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    local enableCard = page:Card(L['Recuperate Button'])
    local enableRow = enableCard:Row(rowH)
    enableRow:Checkbox(L['Enable Recuperate Button'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Recuperate Button'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('Recuperate', checked)
            page:Refresh()
        end,
    })

    local infoRowSize = 50
    local infoRow = enableCard:Row(infoRowSize)
    infoRow:Text(NRSKNUI:ColorTextByTheme(L['Functionality Info']), {
        width = 1,
        height = infoRowSize,
        bgMode = 'hide',
        text = NRSKNUI:ColorTextByTheme('• ') ..
            L['Because of restrictions i cannot fully hide the button when loaded and at '] ..
            L['|cffFFFFFFfull health|r'] .. ' and ' .. L['|cffFFFFFFnot in combat.|r'] ..
            '\n  ' .. L['This means that the button is invisible but is still clickable.'],
        conditions = { 'all' },
    })

    enableCard:Separator()

    local loadInRaidRow = enableCard:Row(rowH)
    loadInRaidRow:Checkbox(L['Load in Raid'], {
        width = 1,
        value = db.LoadInRaid,
        conditions = { 'all' },
        callback = function(checked)
            db.LoadInRaid = checked
            ApplySettings()
        end
    })

    local loadInPartyRow = enableCard:Row(rowHL, 0)
    loadInPartyRow:Checkbox(L['Load in Party'], {
        width = 1,
        value = db.LoadInParty,
        conditions = { 'all' },
        callback = function(checked)
            db.LoadInParty = checked
            ApplySettings()
        end
    })

    local sizeCard = page:Card(L['Button Size'], 'all')
    local sizeRow = sizeCard:Row(rowHL, 0)
    sizeRow:Slider(L['Button Size'], {
        width = 1,
        min = 16,
        max = 128,
        step = 1,
        value = db.Size,
        callback = function(val)
            db.Size = val
            ApplySettings()
        end,
    })
end

-- Position Settings Tab.
local function BuildPositionSettingsTab(page, db)
    page:PositionCard({ db = db, showAnchorFrameType = false, showStrata = true, onChangeCallback = ApplySettings, })
end

GUI:RegisterPage('recuperate', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general', text = L['General Settings'] },
        { id = 'layout',  text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.Miscellaneous.Recuperate
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'layout' then
            BuildPositionSettingsTab(page, db)
        end
    end,
})

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class MinimapModule
local MAP = NRSKNUI:GetModule('Minimap', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local anchorOptions = {
    { key = 'TOPLEFT',     text = L['Top Left'] },
    { key = 'TOP',         text = L['Top'] },
    { key = 'TOPRIGHT',    text = L['Top Right'] },
    { key = 'LEFT',        text = L['Left'] },
    { key = 'CENTER',      text = L['Center'] },
    { key = 'RIGHT',       text = L['Right'] },
    { key = 'BOTTOMLEFT',  text = L['Bottom Left'] },
    { key = 'BOTTOM',      text = L['Bottom'] },
    { key = 'BOTTOMRIGHT', text = L['Bottom Right'] },
}

local function ApplySettings()
    if MAP then MAP:ApplySettings() end
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    -- Card 1: Enable
    local enableCard = page:Card(L['Minimap'])
    local enableRow = enableCard:Row(rowH)
    enableRow:Checkbox(L['Enable Minimap'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Minimap'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('Minimap', checked)
            NRSKNUI:CreateReloadPrompt('Enabling/Disabling this UI element requires a reload to take full effect.')
            page:Refresh()
        end,
    })

    enableCard:Separator()

    local infoRowSize = 60
    local infoRow = enableCard:Row(infoRowSize, 0)
    infoRow:Text(NRSKNUI:ColorTextByTheme(L['Information']), {
        width = 1,
        height = infoRowSize,
        bgMode = 'hide',
        text = NRSKNUI:ColorTextByTheme('• ') .. L['Mouse Middle-click: Opens calendar.'] .. '\n' ..
            NRSKNUI:ColorTextByTheme('• ') .. L['Mouse Right-click: Opens tracking menu.'],
    })

    -- Card 2: Minimap Settings
    local settingsCard = page:Card(L['Minimap Settings'], 'all')
    local sizeRow = settingsCard:Row(rowH)
    sizeRow:Slider(L['Minimap Size'], {
        width = 0.5,
        min = 50,
        max = 500,
        step = 1,
        value = db.Size,
        callback = function(val)
            db.Size = val
            if MAP then MAP:ApplyLayout({ deferZoom = true }) end
        end,
    })
    sizeRow:Slider(L['Minimap Scale'], {
        width = 0.5,
        min = 0.5,
        max = 2,
        step = 0.1,
        value = db.Scale,
        callback = function(val)
            db.Scale = val
            if MAP then MAP:ApplySettings({ scaleChanged = true }) end
        end,
    })

    settingsCard:Separator()

    local borderRow = settingsCard:Row(rowHL, 0)
    borderRow:Slider(L['Border Size'], {
        width = 0.5,
        min = 1,
        max = 10,
        step = 1,
        value = db.Border.Thickness,
        callback = function(val)
            db.Border.Thickness = val
            if MAP then MAP:UpdateMinimapBorder() end
        end,
    })
    borderRow:ColorPicker(L['Border Color'], {
        width = 0.5,
        value = db.Border.Color,
        callback = function(r, g, b, a)
            db.Border.Color = { r, g, b, a }; ApplySettings()
        end,
    })
end

-- Indicators Tab (Mail, Instance Difficulty, Queue).
local function BuildIndicatorsTab(page, db)
    page:SetCondition('mailWidgets', function() return db.Mail.Enabled end)
    page:SetCondition('instWidgets', function() return db.InstanceDifficulty.Enabled end)
    page:SetCondition('queueWidgets', function() return db.QueueStatus.Enabled end)

    -- Card: Mail Icon
    local mailCard = page:Card(L['Mail Icon Settings'], 'all')
    local mailToggleRow = mailCard:Row(rowH)
    mailToggleRow:Checkbox(L['Show Mail Icon'], {
        width = 1,
        value = db.Mail.Enabled,
        callback = function(checked)
            db.Mail.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    mailCard:Separator()

    local mailRow = mailCard:Row(rowH)
    mailRow:Slider(L['Scale'], {
        width = 0.5,
        conditions = { 'mailWidgets' },
        min = 0.5,
        max = 2,
        step = 0.1,
        value = db.Mail.Scale,
        callback = function(val)
            db.Mail.Scale = val; ApplySettings()
        end,
    })
    mailRow:Dropdown(L['Anchorpoint'], {
        width = 0.5,
        conditions = { 'mailWidgets' },
        options = anchorOptions,
        value = db.Mail.Anchor,
        callback = function(key)
            db.Mail.Anchor = key; ApplySettings()
        end,
    })

    local mailRow2 = mailCard:Row(rowHL, 0)
    mailRow2:Slider(L['X Offset'], {
        width = 0.5,
        conditions = { 'mailWidgets' },
        min = -500,
        max = 500,
        step = 1,
        value = db.Mail.X,
        callback = function(val)
            db.Mail.X = val; ApplySettings()
        end,
    })
    mailRow2:Slider(L['Y Offset'], {
        width = 0.5,
        conditions = { 'mailWidgets' },
        min = -500,
        max = 500,
        step = 1,
        value = db.Mail.Y,
        callback = function(val)
            db.Mail.Y = val; ApplySettings()
        end,
    })

    -- Card: Instance Difficulty
    local instCard = page:Card(L['Instance Difficulty Settings'], 'all')
    local instToggleRow = instCard:Row(rowH)
    instToggleRow:Checkbox(L['Show Instance Difficulty'], {
        width = 1,
        value = db.InstanceDifficulty.Enabled,
        callback = function(checked)
            db.InstanceDifficulty.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    instCard:Separator()

    local instRow = instCard:Row(rowH)
    instRow:Slider(L['Scale'], {
        width = 0.5,
        conditions = { 'instWidgets' },
        min = 0.5,
        max = 2,
        step = 0.1,
        value = db.InstanceDifficulty.Scale,
        callback = function(val)
            db.InstanceDifficulty.Scale = val; ApplySettings()
        end,
    })
    instRow:Dropdown(L['Anchorpoint'], {
        width = 0.5,
        conditions = { 'instWidgets' },
        options = anchorOptions,
        value = db.InstanceDifficulty.Anchor,
        callback = function(key)
            db.InstanceDifficulty.Anchor = key; ApplySettings()
        end,
    })

    local instRow2 = instCard:Row(rowHL, 0)
    instRow2:Slider(L['X Offset'], {
        width = 0.5,
        conditions = { 'instWidgets' },
        min = -500,
        max = 500,
        step = 1,
        value = db.InstanceDifficulty.X,
        callback = function(val)
            db.InstanceDifficulty.X = val; ApplySettings()
        end,
    })
    instRow2:Slider(L['Y Offset'], {
        width = 0.5,
        conditions = { 'instWidgets' },
        min = -500,
        max = 500,
        step = 1,
        value = db.InstanceDifficulty.Y,
        callback = function(val)
            db.InstanceDifficulty.Y = val; ApplySettings()
        end,
    })

    -- Card: Queue Icon
    local queueCard = page:Card(L['Queue Icon Settings'], 'all')
    local queueToggleRow = queueCard:Row(rowH)
    queueToggleRow:Checkbox(L['Show Queue Icon'], {
        width = 1,
        value = db.QueueStatus.Enabled,
        callback = function(checked)
            db.QueueStatus.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    queueCard:Separator()

    local queueRow = queueCard:Row(rowH)
    queueRow:Slider(L['Scale'], {
        width = 0.5,
        conditions = { 'queueWidgets' },
        min = 0.5,
        max = 2,
        step = 0.1,
        value = db.QueueStatus.Scale,
        callback = function(val)
            db.QueueStatus.Scale = val; ApplySettings()
        end,
    })
    queueRow:Dropdown(L['Anchorpoint'], {
        width = 0.5,
        conditions = { 'queueWidgets' },
        options = anchorOptions,
        value = db.QueueStatus.Anchor,
        callback = function(key)
            db.QueueStatus.Anchor = key; ApplySettings()
        end,
    })

    local queueRow2 = queueCard:Row(rowHL, 0)
    queueRow2:Slider(L['X Offset'], {
        width = 0.5,
        conditions = { 'queueWidgets' },
        min = -500,
        max = 500,
        step = 1,
        value = db.QueueStatus.X,
        callback = function(val)
            db.QueueStatus.X = val; ApplySettings()
        end,
    })
    queueRow2:Slider(L['Y Offset'], {
        width = 0.5,
        conditions = { 'queueWidgets' },
        min = -500,
        max = 500,
        step = 1,
        value = db.QueueStatus.Y,
        callback = function(val)
            db.QueueStatus.Y = val; ApplySettings()
        end,
    })
end

-- Buttons Tab (BugSack, Landing Page, AddOn Compartment).
local function BuildButtonsTab(page, db)
    page:SetCondition('bugWidgets', function() return db.BugSack.Enabled end)
    page:SetCondition('landingPageWidgets', function() return db.LandingPage.Enabled end)
    page:SetCondition('addonCompWidgets', function() return db.AddOnComp.Enabled end)

    -- Card: BugSack
    local bugCard = page:Card(L['BugSack Settings'], 'all')
    local bugToggleRow = bugCard:Row(rowH)
    bugToggleRow:Checkbox(L['Toggle BugSack Frame'], {
        width = 1,
        value = db.BugSack.Enabled ~= false,
        callback = function(checked)
            db.BugSack.Enabled = checked
            if MAP then MAP:CreateBugSackButton() end
            page:Refresh()
        end,
    })

    bugCard:Separator()

    local bugRow = bugCard:Row(rowH)
    bugRow:Slider(L['BugSack Size'], {
        width = 0.5,
        conditions = { 'bugWidgets' },
        min = 5,
        max = 50,
        step = 1,
        value = db.BugSack.Size,
        callback = function(val)
            db.BugSack.Size = val
            if MAP then MAP:UpdateBugSackButton() end
        end,
    })
    bugRow:Dropdown(L['Anchorpoint'], {
        width = 0.5,
        conditions = { 'bugWidgets' },
        options = anchorOptions,
        value = db.BugSack.Anchor,
        callback = function(key)
            db.BugSack.Anchor = key; ApplySettings()
        end,
    })

    local bugRow2 = bugCard:Row(rowHL, 0)
    bugRow2:Slider(L['X Offset'], {
        width = 0.5,
        conditions = { 'bugWidgets' },
        min = -500,
        max = 500,
        step = 1,
        value = db.BugSack.X,
        callback = function(val)
            db.BugSack.X = val
            if MAP then MAP:UpdateBugSackButton() end
        end,
    })
    bugRow2:Slider(L['Y Offset'], {
        width = 0.5,
        conditions = { 'bugWidgets' },
        min = -500,
        max = 500,
        step = 1,
        value = db.BugSack.Y,
        callback = function(val)
            db.BugSack.Y = val
            if MAP then MAP:UpdateBugSackButton() end
        end,
    })

    -- Card: Landing Page Button
    local lpCard = page:Card(L['Landing Page Button Settings'], 'all')
    local lpToggleRow = lpCard:Row(rowH)
    lpToggleRow:Checkbox(L['Show Landing Page Button'], {
        width = 1,
        value = db.LandingPage.Enabled,
        callback = function(checked)
            db.LandingPage.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    lpCard:Separator()

    local lpRow = lpCard:Row(rowH)
    lpRow:Slider(L['Size'], {
        width = 0.5,
        conditions = { 'landingPageWidgets' },
        min = 16,
        max = 64,
        step = 1,
        value = db.LandingPage.Size,
        callback = function(val)
            db.LandingPage.Size = val
            if MAP then MAP:UpdateLandingPageBtn() end
        end,
    })
    lpRow:Dropdown(L['Anchorpoint'], {
        width = 0.5,
        conditions = { 'landingPageWidgets' },
        options = anchorOptions,
        value = db.LandingPage.Anchor,
        callback = function(key)
            db.LandingPage.Anchor = key
            if MAP then MAP:UpdateLandingPageBtn() end
        end,
    })

    local lpRow2 = lpCard:Row(rowHL, 0)
    lpRow2:Slider(L['X Offset'], {
        width = 0.5,
        conditions = { 'landingPageWidgets' },
        min = -500,
        max = 500,
        step = 1,
        value = db.LandingPage.X,
        callback = function(val)
            db.LandingPage.X = val
            if MAP then MAP:UpdateLandingPageBtn() end
        end,
    })
    lpRow2:Slider(L['Y Offset'], {
        width = 0.5,
        conditions = { 'landingPageWidgets' },
        min = -500,
        max = 500,
        step = 1,
        value = db.LandingPage.Y,
        callback = function(val)
            db.LandingPage.Y = val
            if MAP then MAP:UpdateLandingPageBtn() end
        end,
    })

    -- Card: AddOn Compartment
    local compCard = page:Card(L['AddOn Compartment Settings'], 'all')
    local compToggleRow = compCard:Row(rowH)
    compToggleRow:Checkbox(L['Show AddOn Compartment'], {
        width = 1,
        value = db.AddOnComp.Enabled,
        callback = function(checked)
            db.AddOnComp.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    compCard:Separator()

    local compRow = compCard:Row(rowH)
    compRow:Slider(L['Size'], {
        width = 0.5,
        conditions = { 'addonCompWidgets' },
        min = 5,
        max = 50,
        step = 1,
        value = db.AddOnComp.Size,
        callback = function(val)
            db.AddOnComp.Size = val
            if MAP then MAP:UpdateAddonCompartment() end
        end,
    })
    compRow:Dropdown(L['Anchorpoint'], {
        width = 0.5,
        conditions = { 'addonCompWidgets' },
        options = anchorOptions,
        value = db.AddOnComp.Anchor,
        callback = function(key)
            db.AddOnComp.Anchor = key; ApplySettings()
        end,
    })

    local compRow2 = compCard:Row(rowHL, 0)
    compRow2:Slider(L['X Offset'], {
        width = 0.5,
        conditions = { 'addonCompWidgets' },
        min = -500,
        max = 500,
        step = 1,
        value = db.AddOnComp.X,
        callback = function(val)
            db.AddOnComp.X = val
            if MAP then MAP:UpdateAddonCompartment() end
        end,
    })
    compRow2:Slider(L['Y Offset'], {
        width = 0.5,
        conditions = { 'addonCompWidgets' },
        min = -500,
        max = 500,
        step = 1,
        value = db.AddOnComp.Y,
        callback = function(val)
            db.AddOnComp.Y = val
            if MAP then MAP:UpdateAddonCompartment() end
        end,
    })
end

-- Position Settings Tab.
local function BuildPositionSettingsTab(page, db)
    page:PositionCard({
        db = db,
        dbKeys = { xOffset = 'X', yOffset = 'Y' },
        showAnchorFrameType = false,
        showStrata = false,
        onChangeCallback = ApplySettings,
    })
end

GUI:RegisterPage('minimap', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',    text = L['General Settings'] },
        { id = 'indicators', text = L['Indicators'] },
        { id = 'buttons',    text = L['Buttons'] },
        { id = 'position',   text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.Minimap
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'indicators' then
            BuildIndicatorsTab(page, db)
        elseif tabId == 'buttons' then
            BuildButtonsTab(page, db)
        elseif tabId == 'position' then
            BuildPositionSettingsTab(page, db)
        end
    end,
})

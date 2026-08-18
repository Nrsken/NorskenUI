---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class Skinning
local Skinning = NRSKNUI:GetModule('Skinning', true)
---@class BlizzObjectiveTracker
local BOT = NRSKNUI:GetModule('BlizzObjectiveTracker', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local FRAME_TOGGLES = {
    { key = 'CharacterFrame', label = L['Character Frame'] },
    { key = 'InspectFrame',   label = L['Inspect Frame'] },
    { key = 'PlayerSpells',   label = L['Spellbook & Talents'] },
}

local fontSizes = {
    { label = L['Tab Text'],   dbKey = 'FontTabSize' },
    { label = L['Panel Text'], dbKey = 'FontMediumSize' },
    { label = L['Search Box'], dbKey = 'FontEditBoxSize' },
}

local function ApplySettings()
    if Skinning then Skinning:ApplySettings() end
end

local function ApplyObjectiveTracker()
    if BOT then BOT:ApplySettings() end
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    page:SetCondition('customAccent', function() return db.General.AccentMode == 'custom' end)

    -- Card 1: Enable
    local enableCard = page:Card(L['Blizzard Frame Skinning'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Blizzard Frame Skinning'], {
        width = 1,
        master = true,
        value = db.Enabled ~= false,
        msgPopup = true,
        msgText = L['Blizzard Frame Skinning'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('Skinning', checked)
            NRSKNUI:ToggleModule('BlizzObjectiveTracker', checked)
            if checked then
                ApplySettings()
                ApplyObjectiveTracker()
            else
                NRSKNUI:CreateReloadPrompt(
                    'Restoring the default Blizzard frames requires a reload to take full effect.')
            end
            page:Refresh()
        end,
    })

    -- Card 2: Skin Colors
    local colorCard = page:Card(L['Skin Colors'], 'all')
    local colorRow = colorCard:Row(rowH)
    colorRow:ColorPicker(L['Border Color'], {
        width = 0.5,
        value = db.General.BorderColor,
        callback = function(r, g, b, a)
            db.General.BorderColor = { r, g, b, a }; ApplySettings()
        end,
    })
    colorRow:ColorPicker(L['Background Color'], {
        width = 0.5,
        value = db.General.BackgroundColor,
        callback = function(r, g, b, a)
            db.General.BackgroundColor = { r, g, b, a }; ApplySettings()
        end,
    })

    colorCard:Separator()

    local accentRow = colorCard:Row(rowHL, 0)
    accentRow:Dropdown(L['Accent Mode'], {
        width = 0.5,
        options = NRSKNUI.ColorModeOptions,
        value = db.General.AccentMode,
        tooltip = L['Color used for the highlights and accents on the skinned frames.'],
        callback = function(key)
            db.General.AccentMode = key
            ApplySettings()
            page:Refresh()
        end,
    })
    accentRow:ColorPicker(L['Custom Accent'], {
        width = 0.5,
        conditions = { 'customAccent' },
        value = db.General.CustomAccentColor,
        callback = function(r, g, b, a)
            db.General.CustomAccentColor = { r, g, b, a }; ApplySettings()
        end,
    })
end

-- Frames Tab.
local function BuildFramesTab(page, db)
    local framesCard = page:Card(L['Skinned Frames'], 'all')
    local toggleRow = framesCard:Row(rowHL, 0)
    for _, toggle in ipairs(FRAME_TOGGLES) do
        toggleRow:Checkbox(toggle.label, {
            width = 0.33,
            value = db.Frames[toggle.key] ~= false,
            callback = function(checked)
                db.Frames[toggle.key] = checked
                if checked then
                    ApplySettings()
                else
                    NRSKNUI:CreateReloadPrompt(
                        'Restoring the default ' .. toggle.label .. ' requires a reload to take full effect.')
                end
            end,
        })
    end
end

-- Objective Tracker Tab.
local function BuildObjectiveTrackerTab(page, db)
    local objDb = db.ObjectiveTracker
    page:SetCondition('objEnabled', function() return objDb.Enabled end)
    page:SetCondition('fontEnabled', function() return objDb.FontStyling end)
    page:SetCondition('customColor', function() return objDb.ColorMode == 'custom' end)

    -- Card 1: Enable
    local enableCard = page:Card(L['Objective Tracker'], 'all')
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Objective Tracker Skinning'], {
        width = 1,
        value = objDb.Enabled,
        callback = function(checked)
            objDb.Enabled = checked
            ApplyObjectiveTracker()
            page:Refresh()
            NRSKNUI:CreateReloadPrompt('Objective Tracker skinning changes require a reload to take full effect.')
        end,
    })

    -- Card 2: Color
    local colorCard = page:Card(L['Color'], 'all')
    local colorRow = colorCard:Row(rowHL, 0)
    colorRow:Dropdown(L['Color Mode'], {
        width = 0.5,
        options = NRSKNUI.ColorModeOptions,
        conditions = { 'objEnabled' },
        value = objDb.ColorMode,
        callback = function(key)
            objDb.ColorMode = key
            ApplyObjectiveTracker()
            page:Refresh()
        end,
    })
    colorRow:ColorPicker(L['Custom Color'], {
        width = 0.5,
        conditions = { 'objEnabled', 'customColor' },
        value = objDb.CustomColor,
        callback = function(r, g, b, a)
            objDb.CustomColor = { r, g, b, a }; ApplyObjectiveTracker()
        end,
    })

    -- Card 3: Font Styling
    local fontCard = page:Card(L['Font Styling'], 'all')
    local fontToggleRow = fontCard:Row(rowH)
    fontToggleRow:Checkbox(L['Enable Font Styling'], {
        width = 1,
        conditions = { 'objEnabled' },
        value = objDb.FontStyling,
        callback = function(checked)
            objDb.FontStyling = checked
            ApplyObjectiveTracker()
            page:Refresh()
        end,
    })

    fontCard:Separator()

    local fontSizeRow = fontCard:Row(rowHL, 0)
    fontSizeRow:Slider(L['Quest Title Size'], {
        width = 0.5,
        min = 8,
        max = 20,
        step = 1,
        conditions = { 'objEnabled', 'fontEnabled' },
        value = objDb.QuestTitleSize,
        callback = function(val)
            objDb.QuestTitleSize = val; ApplyObjectiveTracker()
        end,
    })
    fontSizeRow:Slider(L['Quest Text Size'], {
        width = 0.5,
        min = 8,
        max = 20,
        step = 1,
        conditions = { 'objEnabled', 'fontEnabled' },
        value = objDb.QuestTextSize,
        callback = function(val)
            objDb.QuestTextSize = val; ApplyObjectiveTracker()
        end,
    })
end

-- Font Settings Tab.
local function BuildFontSettingsTab(page, db)
    page:FontSettingsCard({
        db = db,
        fontSizes = fontSizes,
        fontSizeRange = { 8, 24 },
        includeSoftOutline = false,
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
end

GUI:RegisterPage('blizzardElements', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',   text = L['General Settings'] },
        { id = 'frames',    text = L['Frames'] },
        { id = 'objective', text = L['Objective Tracker'] },
        { id = 'font',      text = L['Font Settings'] },
    },
    build = function(page, tabId)
        if NRSKNUI:ShouldNotLoadModule() then return end
        local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.BlizzardElements
        if not db then return end
        page:SetEnabled(function() return db.Enabled ~= false end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'frames' then
            BuildFramesTab(page, db)
        elseif tabId == 'objective' then
            BuildObjectiveTrackerTab(page, db)
        elseif tabId == 'font' then
            BuildFontSettingsTab(page, db)
        end
    end,
})

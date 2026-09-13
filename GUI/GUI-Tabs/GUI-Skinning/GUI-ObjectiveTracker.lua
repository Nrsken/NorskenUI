---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class BlizzObjectiveTrackerModule
local BOT = NRSKNUI:GetModule('BlizzObjectiveTracker', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function ApplySettings()
    if BOT then BOT:ApplySettings() end
end

local function BuildPage(page, db)
    local objDb = db.ObjectiveTracker
    page:SetCondition('fontEnabled', function() return objDb.FontStyling end)
    page:SetCondition('customColor', function() return objDb.ColorMode == 'custom' end)

    -- Card 1: Enable
    local enableCard = page:Card(L['Objective Tracker Skinning'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Objective Tracker Skinning'], {
        width = 1,
        master = true,
        value = objDb.Enabled,
        msgPopup = true,
        msgText = L['Objective Tracker Skinning'],
        callback = function(checked)
            objDb.Enabled = checked
            NRSKNUI:ToggleModule('BlizzObjectiveTracker', checked)
            if checked then
                ApplySettings()
            else
                NRSKNUI:CreateReloadPrompt(
                    'Restoring the default Objective Tracker requires a reload to take full effect.')
            end
            page:Refresh()
        end,
    })

    -- Card 2: Color
    local colorCard = page:Card(L['Color'], 'all')
    local colorRow = colorCard:Row(rowHL, 0)
    colorRow:Dropdown(L['Color Mode'], {
        width = 0.5,
        options = NRSKNUI.ColorModeOptions,
        value = objDb.ColorMode,
        callback = function(key)
            objDb.ColorMode = key
            ApplySettings()
            page:Refresh()
        end,
    })
    colorRow:ColorPicker(L['Custom Color'], {
        width = 0.5,
        conditions = { 'customColor' },
        value = objDb.CustomColor,
        callback = function(r, g, b, a)
            objDb.CustomColor = { r, g, b, a }; ApplySettings()
        end,
    })

    -- Card 3: Font Styling
    local fontCard = page:Card(L['Font Styling'], 'all')
    local fontToggleRow = fontCard:Row(rowH)
    fontToggleRow:Checkbox(L['Enable Font Styling'], {
        width = 1,
        value = objDb.FontStyling,
        tooltip = L['The font face and shadow are taken from Skinning > Frames > Font Settings.'],
        callback = function(checked)
            objDb.FontStyling = checked
            ApplySettings()
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
        conditions = { 'fontEnabled' },
        value = objDb.QuestTitleSize,
        callback = function(val)
            objDb.QuestTitleSize = val; ApplySettings()
        end,
    })
    fontSizeRow:Slider(L['Quest Text Size'], {
        width = 0.5,
        min = 8,
        max = 20,
        step = 1,
        conditions = { 'fontEnabled' },
        value = objDb.QuestTextSize,
        callback = function(val)
            objDb.QuestTextSize = val; ApplySettings()
        end,
    })
end

GUI:RegisterPage('objectiveTracker', {
    mode = 'clean',
    search = {},
    build = function(page)
        if NRSKNUI:ShouldNotLoadModule() then return end
        -- Still nested under the frame-skinning table, the font face and shadow are shared.
        local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.BlizzardElements
        if not db then return end
        page:SetEnabled(function() return db.ObjectiveTracker.Enabled end)

        BuildPage(page, db)
    end,
})

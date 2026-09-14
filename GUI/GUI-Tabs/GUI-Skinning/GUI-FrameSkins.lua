---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class Skinning
local Skinning = NRSKNUI:GetModule('Skinning', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local min = math.min

local BLIZZARD_TOGGLES = {
    { key = 'CharacterFrame', label = L['Character Frame'] },
    { key = 'GroupFinder',    label = L['Group Finder'] },
    { key = 'InspectFrame',   label = L['Inspect Frame'] },
    { key = 'Menus',          label = L['Right-Click Menus'] },
    { key = 'PlayerSpells',   label = L['Spellbook & Talents'] },
    { key = 'StaticPopups',   label = L['Static Popups'] },
}

local ADDON_TOGGLES = {
    { key = 'Ace3',               label = L['Ace3 Config Windows'] },
    { key = 'RaiderIO',           label = L['Raider.IO'] },
    { key = 'SimpleAddonManager', label = L['Simple Addon Manager'] },
    { key = 'TalentLoadoutsEx',   label = L['Talent Loadout Ex'] },
}

local fontSizes = {
    { label = L['Tab Text'],   dbKey = 'FontTabSize' },
    { label = L['Panel Text'], dbKey = 'FontMediumSize' },
    { label = L['Search Box'], dbKey = 'FontEditBoxSize' },
}

local function ApplySettings()
    if Skinning then Skinning:ApplySettings() end
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    page:SetCondition('customAccent', function() return db.General.AccentMode == 'custom' end)

    -- Card 1: Enable
    local enableCard = page:Card(L['Frame Skinning'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Frame Skinning'], {
        width = 1,
        master = true,
        value = db.Enabled ~= false,
        msgPopup = true,
        msgText = L['Frame Skinning'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('Skinning', checked)
            if checked then
                ApplySettings()
            else
                NRSKNUI:CreateReloadPrompt(
                    'Restoring the default frames requires a reload to take full effect.')
            end
            page:Refresh()
        end,
    })

    -- Card 2: Skin Colors
    local colorCard = page:Card(L['Skin Colors'], 'all')
    local panelRow = colorCard:Row(rowH)
    panelRow:ColorPicker(L['Border Color'], {
        width = 0.5,
        value = db.General.BorderColor,
        callback = function(r, g, b, a)
            db.General.BorderColor = { r, g, b, a }; ApplySettings()
        end,
    })
    panelRow:ColorPicker(L['Background Color'], {
        width = 0.5,
        value = db.General.BackgroundColor,
        callback = function(r, g, b, a)
            db.General.BackgroundColor = { r, g, b, a }; ApplySettings()
        end,
    })

    local widgetRow = colorCard:Row(rowH)
    widgetRow:ColorPicker(L['Widget Border Color'], {
        width = 0.5,
        value = db.General.WidgetBorderColor,
        callback = function(r, g, b, a)
            db.General.WidgetBorderColor = { r, g, b, a }; ApplySettings()
        end,
    })
    widgetRow:ColorPicker(L['Widget Background Color'], {
        width = 0.5,
        value = db.General.WidgetBackgroundColor,
        callback = function(r, g, b, a)
            db.General.WidgetBackgroundColor = { r, g, b, a }; ApplySettings()
        end,
    })

    local glowRow = colorCard:Row(rowH)
    glowRow:ColorPicker(L['Widget Glow'], {
        width = 1,
        value = db.General.WidgetGlowColor,
        callback = function(r, g, b, a)
            db.General.WidgetGlowColor = { r, g, b, a }; ApplySettings()
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
---@param card any Card the toggles are laid into, four per row
---@param specs table[] { key, label } pairs keyed under db.Frames
local function BuildToggleCard(card, db, specs)
    local count = #specs

    for i = 1, count, 4 do
        local isLast = (i + 3) >= count
        local rowHeight = (isLast and rowHL) or rowH
        local row = card:Row(rowHeight, (isLast and 0) or nil)

        for j = i, min(i + 3, count) do
            local spec = specs[j]

            row:Checkbox(spec.label, {
                width = (1 / 4),
                value = db.Frames[spec.key] ~= false,
                callback = function(checked)
                    db.Frames[spec.key] = checked
                    if checked then
                        ApplySettings()
                    else
                        NRSKNUI:CreateReloadPrompt('Restoring the default ' .. spec.label .. ' requires a reload to take full effect.')
                    end
                end,
            })
        end
    end
end

local function BuildFramesTab(page, db)
    BuildToggleCard(page:Card(L['Blizzard Frames'], 'all'), db, BLIZZARD_TOGGLES)
    BuildToggleCard(page:Card(L['Addons'], 'all'), db, ADDON_TOGGLES)
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

GUI:RegisterPage('frameSkins', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general', text = L['General Settings'] },
        { id = 'frames',  text = L['Frames'] },
        { id = 'font',    text = L['Font Settings'] },
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
        elseif tabId == 'font' then
            BuildFontSettingsTab(page, db)
        end
    end,
})

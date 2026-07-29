---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class TooltipsModule
local Tooltips = NRSKNUI:GetModule('Tooltips', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local modOptions = {
    { key = 'SHIFT', text = L['Shift'] },
    { key = 'CTRL',  text = L['Ctrl'] },
    { key = 'ALT',   text = L['Alt'] },
}

local function ApplySettings()
    if Tooltips then Tooltips:ApplySettings() end
end

-- General Settings Tab.
local function BuildGeneralSettingsTab(page, db)
    -- Card 1: Enable
    local enableCard = page:Card(L['Tooltip Skinning'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Tooltip Skinning'], {
        width = 1,
        master = true,
        value = db.Enabled ~= false,
        msgPopup = true,
        msgText = L['Tooltip Skinning'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('Tooltips', checked)
            if not checked then
                NRSKNUI:CreateReloadPrompt('Enabling Blizzard UI elements requires a reload to take full effect.')
            end
            page:Refresh()
        end,
    })

    enableCard:Separator()

    local inforRowHeight = 90
    local overrideKeyRow = enableCard:Row(inforRowHeight, 0)
    overrideKeyRow:Text(NRSKNUI:ColorTextByTheme(L['Override Key']), {
        text = L['This key is used to temporarily show: '] .. '\n' ..
            NRSKNUI:ColorTextByTheme('  • ') .. L['Tooltips in combat'] .. '\n' ..
            NRSKNUI:ColorTextByTheme('  • ') .. L['Mount tooltips on mounted players'] .. '\n' ..
            NRSKNUI:ColorTextByTheme('  • ') .. L['Aura container spell IDs while holding the key.'],
        width = 0.5,
        tooltip = L['The key that must be held down to temporarily show tooltips while in combat.'],
        height = inforRowHeight,
    })
    overrideKeyRow:Dropdown(L['Override Key'], {
        width = 0.5,
        options = modOptions,
        conditions = { 'combatHide' },
        value = db.Mod,
        callback = function(key) db.Mod = key end,
    })

    -- Card 2: General
    local generalCard = page:Card(L['General Settings'], 'all')
    local auraContainerRow = generalCard:Row(rowH)
    auraContainerRow:Checkbox(L['Skin Aura Container Tooltips'], {
        width = 1,
        value = db.SkinAuraContainer,
        callback = function(checked)
            db.SkinAuraContainer = checked
            NRSKNUI:CreateReloadPrompt('Changing the aura container skin requires a reload to take full effect.')
        end,
    })

    local auraContainerSpellIDRow = generalCard:Row(rowH)
    auraContainerSpellIDRow:Checkbox(L['Show Spell ID On Aura Container Tooltips'], {
        width = 1,
        value = db.ShowAuraContainerSpellID,
        tooltip = L['Show Spell ID On Aura Container Tooltips when holding the override key.'],
        callback = function(checked)
            db.ShowAuraContainerSpellID = checked
        end,
    })

    generalCard:Separator()

    local threatLineRow = generalCard:Row(rowH)
    threatLineRow:Checkbox(L['Hide Threat Line'], {
        width = 1,
        value = db.HideThreatLine,
        tooltip = L['Hides the current threat line on tooltips for units that you are in combat with.'],
        callback = function(checked)
            db.HideThreatLine = checked
            ApplySettings()
        end,
    })

    local mountRow = generalCard:Row(rowHL, 0)
    mountRow:Checkbox(L['Show Mount'], {
        width = 1,
        value = db.ShowMountInfo,
        tooltip = L['Shows the mount a player is currently riding on their tooltip when holding shift.'],
        callback = function(checked)
            db.ShowMountInfo = checked
        end,
    })

    -- Card 3: Backdrop
    local backdropCard = page:Card(L['Backdrop'], 'all')
    local bgRow = backdropCard:Row(rowH)
    bgRow:ColorPicker(L['Background'], {
        width = 1,
        value = db.BackgroundColor,
        callback = function(r, g, b, a)
            db.BackgroundColor = { r, g, b, a }; ApplySettings()
        end,
    })

    backdropCard:Separator()

    local borderRow = backdropCard:Row(rowHL, 0)
    borderRow:ColorPicker(L['Border'], {
        width = 0.5,
        value = db.BorderColor,
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }; ApplySettings()
        end,
    })
    borderRow:Checkbox(L['Item Quality Borders'], {
        width = 0.5,
        value = db.ShowItemQualityBorder,
        tooltip = L['Color tooltip borders by item quality, falls back to the border color for everything else.'],
        callback = function(checked)
            db.ShowItemQualityBorder = checked
            ApplySettings()
        end,
    })
end

-- StatusBar Settings Tab.
local function BuildStatusBarSettingsTab(page, db)
    page:SetCondition('statusBarShow', function() return db.ShowStatusBar end)
    page:SetCondition('customBar', function() return db.ShowStatusBar and not db.UseGlobalBar end)

    local statusCard = page:Card(L['StatusBar Settings'], 'all')
    local showRow = statusCard:Row(rowH)
    showRow:Checkbox(L['Show StatusBar'], {
        width = 1,
        value = db.ShowStatusBar,
        tooltip = L['Toggles health statusbar on unit tooltips.'],
        callback = function(checked)
            db.ShowStatusBar = checked
            ApplySettings()
            page:Refresh()
        end,
    })

    statusCard:Separator()

    local barRow = statusCard:Row(rowHL, 0)
    barRow:Checkbox(L['Use Global Bar'], {
        width = 0.5,
        conditions = { 'statusBarShow' },
        value = db.UseGlobalBar,
        callback = function(checked)
            db.UseGlobalBar = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    barRow:Dropdown(L['Bar Texture'], {
        width = 0.5,
        media = 'statusbar',
        searchable = true,
        conditions = { 'customBar' },
        value = db.StatusBarTexture,
        callback = function(key)
            db.StatusBarTexture = key; ApplySettings()
        end,
    })
end

-- Combat Visibility Tab.
local function BuildCombatSettingsTab(page, db)
    page:SetCondition('combatHide', function() return db.HideInCombat end)

    local combatCard = page:Card(L['Combat Visibility'], 'all')
    local toggleRow = combatCard:Row(rowH)
    toggleRow:Checkbox(L['Hide Tooltips in Combat'], {
        width = 1,
        value = db.HideInCombat,
        tooltip = L['Hides the selected tooltip types during combat. Hold the override key to temporarily show them.'],
        callback = function(checked)
            db.HideInCombat = checked
            page:Refresh()
        end,
    })

    combatCard:Separator()

    local typesRow = combatCard:Row(rowH)
    typesRow:Checkbox(L['Units'], {
        width = 0.5,
        conditions = { 'combatHide' },
        value = db.HideInCombatTypes.Units,
        callback = function(checked) db.HideInCombatTypes.Units = checked end,
    })
    typesRow:Checkbox(L['Items'], {
        width = 0.5,
        conditions = { 'combatHide' },
        value = db.HideInCombatTypes.Items,
        tooltip = L['Includes toys and equipment sets.'],
        callback = function(checked) db.HideInCombatTypes.Items = checked end,
    })

    local typesRow2 = combatCard:Row(rowHL, 0)
    typesRow2:Checkbox(L['Spells'], {
        width = 0.5,
        conditions = { 'combatHide' },
        value = db.HideInCombatTypes.Spells,
        tooltip = L['Includes mounts, macros and flyouts.'],
        callback = function(checked) db.HideInCombatTypes.Spells = checked end,
    })
    typesRow2:Checkbox(L['Auras'], {
        width = 0.5,
        conditions = { 'combatHide' },
        value = db.HideInCombatTypes.Auras,
        callback = function(checked) db.HideInCombatTypes.Auras = checked end,
    })
end

-- Font Settings Tab.
local function BuildFontSettingsTab(page, db)
    page:FontSettingsCard({
        db = db,
        includeSoftOutline = false,
        onChangeCallback = ApplySettings,
        globalOverride = {},
        fontSizes = {
            { label = L['Header Text'], dbKey = 'HeaderTextSize' },
            { label = L['Normal Text'], dbKey = 'TextSize' },
            { label = L['Small Text'],  dbKey = 'TextSmallSize' },
        },
    })
end

-- Position Settings Tab.
local function BuildPositionSettingsTab(page, db)
    page:PositionCard({ db = db, showAnchorFrameType = false, showStrata = false, onChangeCallback = ApplySettings, })
end

GUI:RegisterPage('tooltip', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',   text = L['General Settings'] },
        { id = 'statusbar', text = L['StatusBar Settings'] },
        { id = 'combat',    text = L['Combat Visibility'] },
        { id = 'font',      text = L['Font Settings'] },
        { id = 'position',  text = L['Position Settings'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.Tooltips
        if not db then return end
        page:SetEnabled(function() return db.Enabled ~= false end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'statusbar' then
            BuildStatusBarSettingsTab(page, db)
        elseif tabId == 'combat' then
            BuildCombatSettingsTab(page, db)
        elseif tabId == 'font' then
            BuildFontSettingsTab(page, db)
        elseif tabId == 'position' then
            BuildPositionSettingsTab(page, db)
        end
    end,
})

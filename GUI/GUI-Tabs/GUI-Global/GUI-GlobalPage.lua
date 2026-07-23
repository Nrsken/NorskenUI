---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local min = math.min
local _G = _G

-- { key, label } specs drive the color-picker grids below. key indexes db.profile.Colors.<category>.
-- Game terms pull Blizzard's own localized global strings so they translate for free.
local PowerColorSpecs = {
    { key = 0,  label = _G.MANA },
    { key = 1,  label = _G.RAGE },
    { key = 2,  label = _G.FOCUS },
    { key = 3,  label = _G.ENERGY },
    { key = 6,  label = _G.RUNIC_POWER },
    { key = 8,  label = _G.LUNAR_POWER },
    { key = 11, label = _G.MAELSTROM },
    { key = 13, label = _G.INSANITY },
    { key = 17, label = _G.FURY },
    { key = 18, label = _G.PAIN },
}

local ReactionColorSpecs = {}
for i = 1, 8 do
    ReactionColorSpecs[i] = { key = i, label = _G['FACTION_STANDING_LABEL' .. i] }
end

local ClassColorSpecs = {}
local ClassTokens = {
    'DEATHKNIGHT', 'DEMONHUNTER', 'DRUID', 'EVOKER', 'HUNTER', 'MAGE', 'MONK',
    'PALADIN', 'PRIEST', 'ROGUE', 'SHAMAN', 'WARLOCK', 'WARRIOR',
}
for _, token in ipairs(ClassTokens) do
    ClassColorSpecs[#ClassColorSpecs + 1] = { key = token, label = LOCALIZED_CLASS_NAMES_MALE[token] }
end

local StatusColorSpecs = {
    { key = 'Tapped',       label = L['Tapped'] },
    { key = 'Disconnected', label = L['Disconnected'] },
    { key = 'Dead',         label = L['Dead'] },
}

-- Font Settings Tab.
local function BuildGlobalColorsTab(page, db)
    local function RefreshColors()
        NRSKNUI:LoadCustomColors()
        NRSKNUI:ApplyToAllModules()
    end

    -- Build one card of color pickers laid out three per row from a { key, label } spec list.
    local function BuildColorCard(title, dbTable, specs, storeAlpha)
        local card = page:Card(title, 'all')
        local count = #specs

        for i = 1, count, 3 do
            local isLast = (i + 2) >= count
            local rowHeight = (isLast and rowHL) or rowH
            local row = card:Row(rowHeight)

            for j = i, min(i + 2, count) do
                local spec = specs[j]

                row:ColorPicker(spec.label, {
                    width = (1 / 3),
                    value = dbTable[spec.key],
                    callback = function(r, g, b, a)
                        dbTable[spec.key] = storeAlpha and { r, g, b, a } or { r, g, b }
                        RefreshColors()
                    end,
                })
            end
        end
    end

    BuildColorCard(L['Power Colors'], db.Power, PowerColorSpecs, false)
    BuildColorCard(L['Reaction Colors'], db.Reaction, ReactionColorSpecs, false)
    BuildColorCard(L['Class Colors'], db.Class, ClassColorSpecs, false)
    BuildColorCard(L['Status Colors'], db.Status, StatusColorSpecs, true)
end

local function BuildGlobalUIScaleTab(page, db)
    page:SetCondition('uiScaleOn', function() return db.Enabled end)

    local uiScaleCard = page:Card(L['UI Scale'])
    local uiScaleRow1 = uiScaleCard:Row(rowH)
    uiScaleRow1:Checkbox(L['Enable UI Scale'], {
        width = 0.5,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['UI Scale'],
        tooltip = L['Disable scaling in other addons to avoid conflicts.'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:SetUIScale()
            page:Refresh()
        end,
    })

    uiScaleRow1:Slider(L['Scale'], {
        width = 0.5,
        min = 0.4,
        max = 1.15,
        step = 0.01,
        value = db.Scale,
        conditions = { 'uiScaleOn' },
        callback = function(val)
            db.Scale = val
            NRSKNUI:SetScaleValue(db.Scale)
        end,
        callbackOnRelease = true,
    })

    uiScaleCard:Separator()

    local buttonH = 36
    local buttonOffset = -2
    local uiScaleRow2 = uiScaleCard:Row(rowHL, 0)
    uiScaleRow2:Button(L['Auto (Pixel Perfect)'], {
        width = (1 / 3),
        height = buttonH,
        yOffset = buttonOffset,
        tooltip = L['Automatically match your resolution (768 / screen height).'],
        conditions = { 'uiScaleOn' },
        callback = function()
            NRSKNUI:SetScaleValue()
            page:Refresh()
        end,
    })

    uiScaleRow2:Button(L['1080p Scale'], {
        width = (1 / 3),
        height = buttonH,
        yOffset = buttonOffset,
        tooltip = L['Set UI scale for 1080p resolution.'],
        conditions = { 'uiScaleOn' },
        callback = function()
            NRSKNUI:SetScaleValue(NRSKNUI.TenEigthyPixel)
            page:Refresh()
        end,
    })

    uiScaleRow2:Button(L['1440p Scale'], {
        width = (1 / 3),
        height = buttonH,
        yOffset = buttonOffset,
        tooltip = L['Set UI scale for 1440p resolution.'],
        conditions = { 'uiScaleOn' },
        callback = function()
            NRSKNUI:SetScaleValue(NRSKNUI.FourteenFortyPixel)
            page:Refresh()
        end,
    })
end

local function BuildGlobalTexturesTab(page, db)
    page:SetCondition('globBarON', function() return db.Enabled end)

    local globalTexturesCard = page:Card(L['Global Bar'])
    local useGlobalBarRow = globalTexturesCard:Row(rowHL, 0)
    useGlobalBarRow:Checkbox(L['Use Global Bar Texture'], {
        width = 0.5,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Global Bar'],
        tooltip = L['Enable this to use the same bar texture across all modules.'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ApplyToAllModules()
            page:Refresh()
        end,
    })

    useGlobalBarRow:Dropdown(L['Global Bar Texture'], {
        width = 0.5,
        media = 'statusbar',
        value = db.statusBar,
        searchable = true,
        conditions = { 'globBarON' },
        callback = function(key)
            db.statusBar = key
            NRSKNUI:ApplyToAllModules()
        end,
    })
end

-- Tab builds only run for the selected tab, so the search harvest sees none of
-- their widgets; the font terms and special-font labels are backfilled here.
local fontsSearch = {
    L['Use Global Font'], L['Style Blizzard Fonts'], L['Outline'], L['Use Slug Rendering'],
    L['Hide Shadows'], L['Small Size'], L['Medium Size'], L['Large Size'], L['Huge Size'], L['Font Size'],
}
for _, item in ipairs(NRSKNUI.GlobalFontsTab.items) do
    fontsSearch[#fontsSearch + 1] = item.text
end

GUI:RegisterPage('globalPage', {
    mode = 'tabs',
    search = fontsSearch,
    tabs = {
        { id = 'fonts',    text = L['Font Settings'],    sidebar = { items = NRSKNUI.GlobalFontsTab.items } },
        { id = 'colors',   text = L['Color Settings'] },
        { id = 'uiscale',  text = L['UI Scale Settings'] },
        { id = 'textures', text = L['Global Texture'] },
    },
    build = function(page, tabId, itemKey)
        if tabId == 'fonts' then
            NRSKNUI.GlobalFontsTab.Build(page, itemKey)
        elseif tabId == 'colors' then
            BuildGlobalColorsTab(page, NRSKNUI.db.profile.Colors)
        elseif tabId == 'uiscale' then
            BuildGlobalUIScaleTab(page, NRSKNUI.db.global.UIScale)
        elseif tabId == 'textures' then
            BuildGlobalTexturesTab(page, NRSKNUI.db.profile.globalMedia.profileBar)
        end
    end,
})

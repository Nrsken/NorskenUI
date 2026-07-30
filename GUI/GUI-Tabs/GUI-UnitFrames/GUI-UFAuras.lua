---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local AuraFilters = NRSKNUI.AuraFilters
local AuraCards = NRSKNUI.GUIAuraCards
local AF = AuraUtil.AuraFilters

local ipairs = ipairs
local format = string.format

local function ApplySettings() UF:ApplySettings() end

local KINDS = {
    { kind = 'Buffs',   pageId = 'unitFramesAuraBuffs',   title = L['Aura Buffs'],   label = L['Buffs'],   harmful = false },
    { kind = 'Debuffs', pageId = 'unitFramesAuraDebuffs', title = L['Aura Debuffs'], label = L['Debuffs'], harmful = true },
}

local UNIT_LABELS = {
    player = L['Player'],
    target = L['Target'],
    targettarget = L['Target of Target'],
    focus = L['Focus'],
    focustarget = L['Focus Target'],
    pet = L['Pet'],
    pettarget = L['Pet Target'],
}

local UNIT_ITEMS = {}
for _, unit in ipairs({ 'player', 'target', 'targettarget', 'focus', 'focustarget', 'pet', 'pettarget' }) do
    UNIT_ITEMS[#UNIT_ITEMS + 1] = { key = unit, text = UNIT_LABELS[unit] }
end

local AnchorOptions = {}
for _, point in ipairs({ 'TOPLEFT', 'TOP', 'TOPRIGHT', 'LEFT', 'CENTER', 'RIGHT', 'BOTTOMLEFT', 'BOTTOM', 'BOTTOMRIGHT' }) do
    AnchorOptions[#AnchorOptions + 1] = { value = point, text = point }
end

local TABS = {
    { id = 'layout',     text = L['Layout'] },
    { id = 'filter',     text = L['Filter'] },
    { id = 'appearance', text = L['Appearance'] },
    { id = 'font',       text = L['Font Settings'] },
    { id = 'position',   text = L['Position Settings'] },
}

-- Layout Tab
local function BuildLayoutTab(page, def, cfg, unit, ctx)
    local enableCard = page:Card(format('%s %s', UNIT_LABELS[unit], def.label))
    enableCard:Row(rowHL, 0):Checkbox(L['Enable'], {
        width = 1,
        master = true,
        value = cfg.Enabled,
        callback = function(checked)
            cfg.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    AuraCards:Grid(page, cfg, ctx)
    AuraCards:Growth(page, cfg, ctx)
end

-- Filter Tab
local function BuildFilterTab(page, def, cfg, unit, ctx)
    page:FilterCard({
        title = L['Aura Filter'],
        label = L['Filter'],
        db = cfg,
        dbKey = 'Filter',
        filters = function() return AuraFilters:GetList() end,
        noneText = def.harmful and L['None (all harmful)'] or L['None (all helpful)'],
        noneValue = def.harmful and AF.Harmful or AF.Helpful,
        summaryTitle = NRSKNUI:ColorTextByTheme(L['Resolves To']),
        emptyText = L['No filters defined yet. Create one under Aura Filters.'],
        describe = function(name) return AuraFilters:Describe(name) end,
        manageText = L['Manage Filters'],
        onManage = function()
            local window = NRSKNUI.GUIFrame
            if window and window.content then window.content:ShowPage('filterBuilder') end
        end,
        onChangeCallback = ApplySettings,
    })
    AuraCards:Sorting(page, cfg, ctx)
end

-- Appearance Tab
local function BuildAppearanceTab(page, def, cfg, unit, ctx)
    AuraCards:Icons(page, cfg, ctx)
    AuraCards:Text(page, cfg)
    AuraCards:Cooldown(page, cfg)
    AuraCards:Dispel(page, cfg, ctx)
    AuraCards:Tooltip(page, cfg, ctx)
    AuraCards:Reload(page)
end

-- Font Settings Tab
local function BuildFontTab(page, def, cfg, unit, ctx)
    local sizeCard = page:Card(L['Font Sizes'], 'all')
    local sizeRow = sizeCard:Row(rowHL, 0)
    sizeRow:Slider(L['Stack Size'], {
        width = 0.5,
        tooltip = L['The font face and outline come from the general unit frame font settings.'],
        min = 8,
        max = 40,
        step = 1,
        value = cfg.StackFont.FontSize,
        callback = function(val) cfg.StackFont.FontSize = val end,
    })
    sizeRow:Slider(L['Duration Size'], {
        width = 0.5,
        min = 8,
        max = 40,
        step = 1,
        value = cfg.DurationFont.FontSize,
        callback = function(val) cfg.DurationFont.FontSize = val end,
    })
    AuraCards:TextPosition(page, cfg)
    AuraCards:Reload(page)
end

-- Position Settings Tab
local function BuildPositionTab(page, def, cfg, unit, ctx)
    local pos = cfg.Position

    local card = page:Card(L['Position Settings'], 'all')
    card:Row(rowH):Dropdown(L['Anchor To'], {
        width = 1,
        tooltip = L['The point on the unit frame the auras attach to. The container corner follows the growth direction.'],
        options = AnchorOptions,
        value = pos.AnchorTo,
        callback = function(key)
            pos.AnchorTo = key
            ApplySettings()
        end,
    })

    local offsetRow = card:Row(rowHL, 0)
    offsetRow:Slider(L['X Offset'], {
        width = 0.5,
        min = -200,
        max = 200,
        step = 1,
        value = pos.XOffset,
        callback = function(val)
            pos.XOffset = val
            ApplySettings()
        end,
        callbackOnRelease = true,
    })
    offsetRow:Slider(L['Y Offset'], {
        width = 0.5,
        min = -200,
        max = 200,
        step = 1,
        value = pos.YOffset,
        callback = function(val)
            pos.YOffset = val
            ApplySettings()
        end,
        callbackOnRelease = true,
    })
end

local TAB_BUILDERS = {
    layout = BuildLayoutTab,
    filter = BuildFilterTab,
    appearance = BuildAppearanceTab,
    font = BuildFontTab,
    position = BuildPositionTab,
}

for _, def in ipairs(KINDS) do
    GUI:RegisterPage(def.pageId, {
        mode = 'tabs',
        -- The content depends on the selected unit, so there is nothing to harvest from a bare build.
        noHarvest = true,
        search = {
            def.title, L['Grid'], L['Growth'], L['Sorting'], L['Icons'], L['Cooldown'], L['Tooltip'],
            L['Aura Filter'], L['Dispel Indicators'], L['Text Position'], L['Font Sizes'],
            L['Max Auras'], L['Per Row'], L['Element Spacing'], L['Line Spacing'],
            L['Horizontal Growth'], L['Vertical Growth'], L['Sort Method'], L['Sort Direction'],
            L['Show Count'], L['Show Duration'], L['Draw Swipe'], L['Reverse Swipe'], L['Draw Edge'],
            L['Show Border'], L['Show Without Dispel Type'], L['Show Dispel Icon'], L['Dispel Icon Size'],
            L['Hide Tooltip In Combat'], L['Disable Mouse'], L['Stack Size'], L['Duration Size'],
            L['Anchor To'], L['X Offset'], L['Y Offset'],
        },
        sidebar = { items = UNIT_ITEMS },
        tabs = TABS,
        build = function(page, tabId, unit)
            local builder = TAB_BUILDERS[tabId]
            if not builder or not unit then return end

            local db = NRSKNUI.db.profile.UnitFrames
            local uDB = db.Units[unit]
            local cfg = uDB.Auras[def.kind]

            page:SetEnabled(function() return db.Enabled and uDB.Enabled and cfg.Enabled end)

            local ctx = {
                Apply = ApplySettings,
                filtered = true,
                dispelIconKey = 'showDispelIcon',
                withoutDispelType = true,
                disableMouse = true,
            }

            builder(page, def, cfg, unit, ctx)
        end,
    })
end

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast
local AuraCards = NRSKNUI.GUIAuraCards
local TriggerCard = NRSKNUI.GUITriggerCard

local ipairs = ipairs

-- sectionKey is the mini sidebar item each kind hangs off on a unit page.
local KINDS = {
    { kind = 'Buffs',   sectionKey = 'aurabuffs',   title = L['Aura Buffs'],   label = L['Buffs'],   harmful = false },
    { kind = 'Debuffs', sectionKey = 'auradebuffs', title = L['Aura Debuffs'], label = L['Debuffs'], harmful = true },
}

local AnchorOptions = NRSKNUI.AnchorOptions

local TABS = {
    { id = 'layout',     text = L['Layout'] },
    { id = 'trigger',    text = L['Trigger'] },
    { id = 'appearance', text = L['Appearance'] },
    { id = 'font',       text = L['Font Settings'] },
    { id = 'position',   text = L['Position Settings'] },
}

-- Layout Tab
local function BuildLayoutTab(page, def, cfg, unit, ctx)
    local enableCard = page:Card(def.title)
    enableCard:Row(rowHL, 0):Checkbox(L['Enable'], {
        width = 1,
        master = true,
        value = cfg.Enabled,
        callback = function(checked)
            cfg.Enabled = checked
            ctx.Apply()
            page:Refresh()
        end,
    })
    AuraCards:Grid(page, cfg, ctx)
    AuraCards:Growth(page, cfg, ctx)
    AuraCards:Sorting(page, cfg, ctx)
end

-- Trigger Tab
local function BuildTriggerTab(page, def, cfg, unit, ctx)
    cfg.Trigger = cfg.Trigger or NRSKNUI.AuraTriggers:New({
        Base = def.harmful and AuraUtil.AuraFilters.Harmful or AuraUtil.AuraFilters.Helpful,
    })

    -- hideUnit: the frame this display sits on already decides the unit.
    TriggerCard:Build(page, cfg.Trigger, { hideUnit = true, onChange = ctx.Apply })
end

-- Appearance Tab
local function BuildAppearanceTab(page, def, cfg, unit, ctx)
    AuraCards:Icons(page, cfg, ctx)
    AuraCards:Text(page, cfg, ctx)
    AuraCards:Cooldown(page, cfg, ctx)
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
        callback = function(val)
            cfg.StackFont.FontSize = val
            ctx.Apply()
        end,
    })
    sizeRow:Slider(L['Duration Size'], {
        width = 0.5,
        min = 8,
        max = 40,
        step = 1,
        value = cfg.DurationFont.FontSize,
        callback = function(val)
            cfg.DurationFont.FontSize = val
            ctx.Apply()
        end,
    })
    AuraCards:TextPosition(page, cfg, ctx)
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
            ctx.Apply()
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
            ctx.Apply()
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
            ctx.Apply()
        end,
        callbackOnRelease = true,
    })
end

local TAB_BUILDERS = {
    layout = BuildLayoutTab,
    trigger = BuildTriggerTab,
    appearance = BuildAppearanceTab,
    font = BuildFontTab,
    position = BuildPositionTab,
}

-- Exposed for GUI-UFPages.lua.
UF.GUIAuras = {
    tabs = TABS,
    search = {
        L['Grid'], L['Growth'], L['Sorting'], L['Icons'], L['Cooldown'], L['Tooltip'],
        L['Trigger'], L['Dispel Indicators'], L['Text Position'], L['Font Sizes'],
        L['Max Auras'], L['Per Row'], L['Element Spacing'], L['Line Spacing'],
        L['Horizontal Growth'], L['Vertical Growth'], L['Sort Method'], L['Sort Direction'],
        L['Show Count'], L['Show Duration'], L['Draw Swipe'], L['Reverse Swipe'], L['Draw Edge'],
        L['Show Border'], L['Show Without Dispel Type'], L['Show Dispel Icon'], L['Dispel Icon Size'],
        L['Hide Tooltip In Combat'], L['Disable Mouse'], L['Stack Size'], L['Duration Size'],
    },
}

-- Sidebar item key -> aura kind definition.
---@class UF.GUIAuraSections
UF.GUIAuraSections = {}
for _, def in ipairs(KINDS) do
    UF.GUIAuraSections[def.sectionKey] = def
end

---Render one aura sub-tab that owns its own SetEnabled chain.
---@param page KajiGUIPage
---@param def table one of the KINDS entries
---@param tabId string
---@param unit string
function UF.GUIAuras.Build(page, def, tabId, unit)
    local builder = TAB_BUILDERS[tabId]
    if not builder then return end

    local db = NRSKNUI.db.profile.UnitFrames
    local uDB = db.Units[unit]
    local cfg = uDB.Auras[def.kind]

    page:SetEnabled(function()
        return (db.Enabled and uDB.Enabled and cfg.Enabled and not NRSKNUI.UFBlocked) and true or false
    end)

    local ctx = {
        -- Scoped to this unit: a full pass reconfigures every group child on every other unit too.
        Apply = function() UF:ApplySettings(unit) end,
        filtered = true,
        dispelIconKey = 'showDispelIcon',
        withoutDispelType = true,
        disableMouse = true,
    }

    builder(page, def, cfg, unit, ctx)
end

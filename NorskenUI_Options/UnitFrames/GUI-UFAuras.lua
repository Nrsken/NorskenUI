---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_UnitFrames') then return end
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowHL = Theme.rowHeightLast
local AuraCards = NRSKNUI.GUIAuraCards
local TriggerEditor = NRSKNUI.GUITriggerEditor

local ipairs = ipairs

-- sectionKey is the mini sidebar item each kind hangs off on a unit page.
local KINDS = {
    { kind = 'Buffs',   sectionKey = 'aurabuffs',   title = L['Aura Buffs'],   label = L['Buffs'],   harmful = false },
    { kind = 'Debuffs', sectionKey = 'auradebuffs', title = L['Aura Debuffs'], label = L['Debuffs'], harmful = true },
    -- Party and raid pages only, see GUI-UFPages.lua.
    { kind = 'Defensives', sectionKey = 'auradefensives', title = L['Aura Defensives'], label = L['Defensives'], harmful = false },
}

local TABS = {
    { id = 'layout',     text = L['Layout'] },
    { id = 'trigger',    text = L['Trigger'] },
    { id = 'appearance', text = L['Appearance'] },
    { id = 'text',       text = L['Text'] },
}

---@param page KajiGUIPage
---@param cfg table
---@param ctx table
local function BuildPositionCard(page, cfg, ctx)
    page:PositionCard({
        db = cfg,
        showAnchorFrameType = false,
        showStrata = false,
        sliderRange = { -200, 200 },
        onChangeCallback = ctx.Apply,
    }, 'all')
end

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
    BuildPositionCard(page, cfg, ctx)
    AuraCards:Sorting(page, cfg, ctx)
end

-- Trigger Tab
local function BuildTriggerTab(page, def, cfg, unit, ctx)
    cfg.Trigger = cfg.Trigger or NRSKNUI.AuraTriggers:New({
        Base = def.harmful and AuraUtil.AuraFilters.Harmful or AuraUtil.AuraFilters.Helpful,
    })

    -- No Unit dropdown: the frame this display sits on already decides the unit.
    TriggerEditor:Build(page, cfg.Trigger, { title = def.title, onChange = ctx.Apply })
end

-- Appearance Tab
local function BuildAppearanceTab(page, def, cfg, unit, ctx)
    AuraCards:Cooldown(page, cfg, ctx)
    AuraCards:Dispel(page, cfg, ctx)
    AuraCards:Tooltip(page, cfg, ctx)
    AuraCards:Reload(page)
end

-- Text Tab
local function BuildTextTab(page, def, cfg, unit, ctx)
    AuraCards:Text(page, cfg, ctx)
    AuraCards:Reload(page)
end

local TAB_BUILDERS = {
    layout = BuildLayoutTab,
    trigger = BuildTriggerTab,
    appearance = BuildAppearanceTab,
    text = BuildTextTab,
}

-- Exposed for GUI-UFPages.lua.
UF.GUIAuras = {
    tabs = TABS,
    search = {
        L['Grid'], L['Growth'], L['Sorting'], L['Icons'], L['Cooldown'], L['Tooltip'],
        L['Trigger'], L['Dispel Indicators'], L['Text'], L['Position'],
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

    local db = UF.db
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

---@class NorskenUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_UnitFrames') then return end
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local AuraLook = NRSKNUI.GUIAuraLook
local TriggerEditor = NRSKNUI.GUITriggerEditor

local ipairs = ipairs
local setmetatable = setmetatable
local Apply = NRSKNUI.Enum.Apply

-- sectionKey is the mini sidebar item each kind hangs off on a unit page.
local KINDS = {
    { kind = 'Buffs',   sectionKey = 'aurabuffs',   title = L['Aura Buffs'],   label = L['Buffs'],   harmful = false },
    { kind = 'Debuffs', sectionKey = 'auradebuffs', title = L['Aura Debuffs'], label = L['Debuffs'], harmful = true },
    -- Party and raid pages only, see GUI-UFPages.lua.
    { kind = 'Defensives', sectionKey = 'auradefensives', title = L['Aura Defensives'], label = L['Defensives'], harmful = false },
}

-- an aura group's tabs, less what the frame decides itself: unit, load, conditions
local TABS = {
    { id = 'group',   text = L['Group'] },
    { id = 'display', text = L['Display'] },
    { id = 'trigger', text = L['Trigger'] },
}

-- Group Tab
local function BuildGroupTab(page, def, cfg, unit, ctx)
    page:Card(def.title, 'all'):Rebuild(function(card)
        card:Row(rowH):Checkbox(L['Enable'], {
            width = 1,
            master = true,
            value = cfg.Enabled,
            callback = function(checked)
                cfg.Enabled = checked
                ctx.Apply(Apply.Visibility)
                page:Refresh()
            end,
        })

        if AuraLook.Section(card, 'groupLayout', L['Dynamic Group Settings']) then
            card:Premade('DynamicGroupCard', {
                db = cfg.Layout,
                showLimit = false,
                extraRows = function(c) AuraLook.AuraGroupCountRows(c, cfg, ctx.Apply) end,
                onChangeCallback = ctx.Layout,
            })
        end
        if AuraLook.Section(card, 'groupPosition', L['Position Settings']) then
            card:Premade('PositionCard', {
                db = cfg,
                showAnchorFrameType = false,
                showStrata = false,
                sliderRange = { -200, 200 },
                onChangeCallback = function() ctx.Apply(Apply.Position) end,
            })
        end
    end)
end

-- Display Tab
local function BuildDisplayTab(page, def, cfg, unit, ctx)
    local style = UF.PrepareAuras(cfg, def.kind)
    -- edited as an aura group with no triggers of its own; writes reach the kind's settings
    local displays = { setmetatable({ Triggers = {}, type = 'auragroup', name = def.title }, { __index = cfg, __newindex = cfg }) }
    local mixed = AuraLook.Differ(displays, function() return style end)
    -- any part a row names redraws the whole button
    local function Restyle()
        ctx.Apply(Apply.Look)
    end
    local function set(path, value)
        AuraLook.Assign(cfg.Style, path, value)
        Restyle()
    end

    page:Card(def.title, 'all'):Rebuild(function(card)
        AuraLook.AuraGroupRows(card, page, style, set, mixed, false, function()
            AuraLook.SubElements(card, page, displays, Restyle, { adds = AuraLook.AuraGroupAdds, auraGroup = true })
        end)
    end)
end

-- Trigger Tab
local function BuildTriggerTab(page, def, cfg, unit, ctx)
    cfg.Trigger = cfg.Trigger or NRSKNUI.AuraTriggers:New({
        Base = def.harmful and AuraUtil.AuraFilters.Harmful or AuraUtil.AuraFilters.Helpful,
    })

    -- no Unit row: the frame this display sits on decides the unit
    -- what the kind matches, not how its buttons look
    TriggerEditor:BuildSections(page, cfg.Trigger, { title = def.title, apply = ctx.Apply })
end

local TAB_BUILDERS = {
    group = BuildGroupTab,
    display = BuildDisplayTab,
    trigger = BuildTriggerTab,
}

-- Exposed for GUI-UFPages.lua.
UF.GUIAuras = {
    tabs = TABS,
    search = {
        L['Dynamic Group Settings'], L['Sort Method'], L['Sort Direction'], L['Auras Per Trigger'], L['Preview Limit'],
        L['Position Settings'], L['Icon Settings'], L['Swipe Settings'], L['Timer Text Settings'], L['Size Settings'],
        L['General'], L['Sub Elements'], L['Trigger'], L['Show Dispel Icon'], L['Aura Type Texture'],
        L['Hide Tooltip In Combat'], L['Add Text'], L['Add Border'],
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

    -- one kind on this unit's frames; only the Display tab redraws its buttons
    local function Update(part) UF:ApplySettings(part, unit, 'Auras', def.kind) end
    builder(page, def, cfg, unit, { Apply = Update, Layout = function() Update(Apply.Layout) end })
end

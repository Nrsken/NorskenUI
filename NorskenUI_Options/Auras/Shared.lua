---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Auras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local IconPicker = NRSKNUI.CDMIconPicker

local ipairs = ipairs

-- What the CDM options files share: page keys, helpers and the trigger lists.
NRSKNUI.CDMOptions = {}
local Shared = NRSKNUI.CDMOptions

local PAGE = 'cooldownManager'
local GENERAL = 'cdm:general'
local TRINKETS = 'cdm:trinkets'
local SETTINGS = 'cdm:settings'
local IMPORT = 'cdm:import'
local SECTION_LOADED = 'cdm:section:loaded'
local SECTION_UNLOADED = 'cdm:section:unloaded'
local QUESTION_MARK = 134400
local NEW_TILE_HEIGHT = 104
local NEW_TILE_ICON = 44
local NEW_TILE_PREVIEW = 74 -- a picture's width: fills a tile at the narrowest window
local POWER_MODES = {
    { value = 'bar',      text = L['Static Single Bar'],   description = L['One bar for all your %s.'] },
    { value = 'static',   text = L['Static Segments'],     description = L['One segment each, filled while it is ready, empty otherwise.'] },
    { value = 'progress', text = L['Recharging Segments'], description = L['Like Static Segments but each one fills up as it recharges.'] },
}

local TABS = {
    { id = 'group',       text = L['Group'] },
    { id = 'display',     text = L['Display'] },
    { id = 'trigger',     text = L['Trigger'] },
    { id = 'conditions',  text = L['Conditions'] },
    { id = 'load',        text = L['Load'] },
    { id = 'information', text = L['Information'] },
}

-- Several picked rows edit together, in the WA style: only what every display has, nothing that is one display's own.
local MULTI_TABS = {
    { id = 'display', text = L['Display'] },
    { id = 'load',    text = L['Load'] },
}

-- An aura group only has what the Auras page gave it; its look is split from where it sits.
local AURA_GROUP_TABS = {
    { id = 'display',     text = L['Display'] },
    { id = 'layout',      text = L['Layout'] },
    { id = 'trigger',     text = L['Trigger'] },
    { id = 'conditions',  text = L['Conditions'] },
    { id = 'load',        text = L['Load'] },
    { id = 'information', text = L['Information'] },
}

local TYPE_NAMES = {
    icon = L['Icon'],
    bar = L['Progress Bar'],
    text = L['Text'],
    group = L['Group'],
    dynamicgroup = L['Dynamic Group'],
    auragroup = L['Aura Group'],
}

local expandedGroups = {} -- [group uid] = true, for the session; groups start collapsed. A uid is never reused, unlike an id

---@return table? tree
local function Tree()
    local content = NRSKNUI.GUIFrame and NRSKNUI.GUIFrame.content
    return content and content.miniSidebar
end

---Every display a tab edits for the shown row: with two or more rows picked (it among them) each picked display,
---a picked group standing for everything inside it; else a group's displays or the row alone.
---@param id string
---@return string[] ids each once, in tree order
---@return boolean multi whether it's a multi selection
local function EditTargets(id)
    local tree = Tree()
    local picked = tree and tree.picked and tree.picked[id] and tree:GetPicked()
    if not (picked and picked[2]) then
        return CDM:IsGroup(id) and CDM:GetLeaves(id) or { id }, false
    end

    local ids, seen = {}, {}
    for _, key in ipairs(picked) do
        for _, leaf in ipairs(CDM:IsGroup(key) and CDM:GetLeaves(key) or { key }) do
            if not seen[leaf] then
                seen[leaf] = true
                ids[#ids + 1] = leaf
            end
        end
    end
    return ids, true
end

local function Reopen(selectKey)
    local window = NRSKNUI.GUIFrame
    if not (window and window.content) then return end

    if selectKey and CDM:Get(selectKey) then
        for _, ancestor in ipairs(CDM:GetAncestors(selectKey)) do
            expandedGroups[CDM:Get(ancestor).uid] = true
        end
    end
    window.content:ShowPage(PAGE, selectKey and { itemKey = selectKey } or nil)
end

IconPicker.navigate = Reopen

local function RefreshTree()
    local tree = Tree()
    if tree and tree.frame:IsShown() and tree.Render then
        tree:Render()
    end
end

local function EnsureModuleEnabled()
    if CDM.db.Enabled then return end
    CDM.db.Enabled = true
    NRSKNUI:ToggleModule('CDM', true)
end

---@param id string?
---@return fun()
local function Applier(id)
    return function() CDM:ApplySettings(id) end
end

---@param key string
---@return boolean
local function IsCollapsed(key)
    return NRSKNUI.db.global.SidebarCollapsed[PAGE][key] == true
end

Shared.AURA_GROUP_TABS = AURA_GROUP_TABS
Shared.MULTI_TABS = MULTI_TABS
Shared.EditTargets = EditTargets
Shared.Applier = Applier
Shared.EnsureModuleEnabled = EnsureModuleEnabled
Shared.GENERAL = GENERAL
Shared.IMPORT = IMPORT
Shared.IsCollapsed = IsCollapsed
Shared.NEW_TILE_HEIGHT = NEW_TILE_HEIGHT
Shared.NEW_TILE_ICON = NEW_TILE_ICON
Shared.NEW_TILE_PREVIEW = NEW_TILE_PREVIEW
Shared.PAGE = PAGE
Shared.POWER_MODES = POWER_MODES
Shared.QUESTION_MARK = QUESTION_MARK
Shared.RefreshTree = RefreshTree
Shared.Reopen = Reopen
Shared.SECTION_LOADED = SECTION_LOADED
Shared.SECTION_UNLOADED = SECTION_UNLOADED
Shared.SETTINGS = SETTINGS
Shared.TABS = TABS
Shared.TRINKETS = TRINKETS
Shared.TYPE_NAMES = TYPE_NAMES
Shared.Tree = Tree
Shared.expandedGroups = expandedGroups

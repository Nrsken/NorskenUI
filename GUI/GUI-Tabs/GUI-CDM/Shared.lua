---@class NRSKNUI
local NRSKNUI = select(2, ...)
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

-- WeakAuras' tab order; the ones without settings yet stay empty.
local TABS = {
    { id = 'group',       text = L['Group'] },
    { id = 'display',     text = L['Display'] },
    { id = 'trigger',     text = L['Trigger'] },
    { id = 'conditions',  text = L['Conditions'] },
    { id = 'actions',     text = L['Actions'] },
    { id = 'animations',  text = L['Animations'] },
    { id = 'load',        text = L['Load'] },
    { id = 'custom',      text = L['Custom Options'] },
    { id = 'information', text = L['Information'] },
}

-- An aura group only has what the Auras page gave it, and its look is split from where it sits.
local AURA_GROUP_TABS = {
    { id = 'display',     text = L['Display'] },
    { id = 'layout',      text = L['Layout'] },
    { id = 'trigger',     text = L['Trigger'] },
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

local expandedGroups = {} -- [group id] = true, for the session; groups start collapsed

---@return table? tree
local function Tree()
    local content = NRSKNUI.GUIFrame and NRSKNUI.GUIFrame.content
    return content and content.miniSidebar
end

local function Reopen(selectKey)
    local window = NRSKNUI.GUIFrame
    if not (window and window.content) then return end

    if selectKey and CDM:Get(selectKey) then
        for _, ancestor in ipairs(CDM:GetAncestors(selectKey)) do
            expandedGroups[ancestor] = true
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

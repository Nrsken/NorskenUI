---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local GUI = NRSKNUI.GUI
local L = NRSKNUI.Libs.AL
local PM = NRSKNUI.ProfileManager

local ipairs = ipairs
local pairs = pairs
local next = next
local format = string.format
local concat = table.concat

-- Every page of a module opens under that module's header: its name, its on/off, a few actions for the whole
-- module and, where the entry sets `roles`, its role sets as tabs. A page belongs to the module its sidebar
-- entry (or that entry's section) names with `module`.

local ROLES = { 'TANK', 'HEALER', 'DAMAGER' }
local ROLE_NAMES = { TANK = L['Tank'], HEALER = L['Healer'], DAMAGER = L['DPS'] } ---@type table<string, string>

local content = GUIFrame.content
local module, moduleName -- the module the open page edits
local moduleIndex -- its place in the sidebar
local rolesAllowed -- the entry set `roles = true`: the module's settings can be split by role

local header -- made below, its callbacks need the actions
local toggleHooks = {} -- [module] = fun(enabled), what its page does past the switch itself: a reload prompt, a preview

-- Lookup --

---The module a page belongs to and the name to title it with, from the sidebar entry's `module`.
---@param entries table[]
---@param pageId string
---@param owner table? closest enclosing entry that names a module
---@return string|nil module
---@return string|nil name
---@return boolean|nil roles true when that entry sets `roles = true`
local function FindModule(entries, pageId, owner)
    for _, entry in ipairs(entries) do
        local own = entry.module and entry or owner
        if entry.id == pageId then
            return own and own.module, own and own.text, own and own.roles == true
        end
        if entry.items then
            local found, name, roles = FindModule(entry.items, pageId, own)
            if found then
                return found, name, roles
            end
        end
    end
end

---Where a page's top-level sidebar entry sits.
---@param pageId string
---@return number|nil index
local function Locate(pageId)
    for i, entry in ipairs(GUIFrame.SidebarConfig.systems) do
        if entry.id == pageId then
            return i
        end
        for _, item in ipairs(entry.items or {}) do
            if item.id == pageId then
                return i
            end
        end
    end
end

---What a tab is called: a role's name for a role set; the shared set names every role still on it
---("Tank & DPS") and is "All Roles" while no role has split off.
---@param sets table<string, boolean>
---@param tab string|false false = the shared set
---@return string
local function TabName(sets, tab)
    if tab then
        return ROLE_NAMES[tab]
    end
    if not next(sets) then
        return L['All Roles']
    end
    local names = {}
    for _, role in ipairs(ROLES) do
        if not sets[role] then
            names[#names + 1] = ROLE_NAMES[role]
        end
    end
    return concat(names, ' & ')
end

---@return table|nil aceModule the open module
local function AceModule()
    return module and NRSKNUI:GetModule(module, true)
end

---@return table|nil aceModule the open module, when it has an on/off of its own
local function SwitchModule()
    local aceModule = AceModule()
    if aceModule and aceModule.db and aceModule.db.Enabled ~= nil then
        return aceModule
    end
end

---@return boolean
local function ModuleOn()
    local aceModule = SwitchModule()
    return not aceModule or aceModule.db.Enabled and true or false
end

---Whether the module's settings are its whole namespace, the only case the profile manager's reset, role sets and
---switch fit. Frame Skins' db is one table inside its namespace and the other Skinning modules read tables of that
---same namespace, so a namespace reset there would wipe all of them.
---@return boolean
local function OwnsNamespace()
    local aceModule = AceModule()
    local ns = NRSKNUI.db.children and NRSKNUI.db.children[module]
    return aceModule ~= nil and ns ~= nil and aceModule.db == ns.profile
end

-- Role sets --

local function Rebuild()
    content:ShowPage(content.currentId)
end

---@param tab string|false
local function Select(tab)
    PM:SetEditRole(module, tab or nil)
    Rebuild()
end

---@param role string
local function Add(role)
    -- starts from the set on screen, so nothing jumps
    PM:AddRoleSet(module, role, PM:GetShownRole(module))
    PM:SetEditRole(module, role)
    Rebuild()
end

---@param role string
local function Remove(role)
    local sets = PM:GetRoleSets(module)
    sets[role] = nil
    GUI:Prompt({
        title = format(L['Remove the %s settings?'], ROLE_NAMES[role]),
        text = format(L['%s specs go back to the %s settings.'], ROLE_NAMES[role], TabName(sets, false)),
        onAccept = function()
            PM:RemoveRoleSet(module, role)
            Rebuild()
        end,
        acceptText = L['Remove'],
        cancelText = L['Cancel'],
    })
end

---@param role string|false the tab right-clicked; the shared set always stays, so only a role set has a menu
local function OpenTabMenu(role)
    if not role then return end
    GUI:ShowContextMenu({ { text = format(L['Remove %s settings'], ROLE_NAMES[role]), onClick = function() Remove(role) end } })
end

-- three roles, so two role sets at most: one role always keeps the shared settings
local function CanAdd(sets)
    local count = 0
    for _ in pairs(sets) do
        count = count + 1
    end
    return count < 2
end

local function OpenAddMenu()
    local sets = PM:GetRoleSets(module)
    local entries = { { text = L['Give a role its own settings'], disabled = true } }
    for _, role in ipairs(ROLES) do
        if not sets[role] then
            entries[#entries + 1] = { text = ROLE_NAMES[role], onClick = function() Add(role) end }
        end
    end
    GUI:ShowContextMenu(entries)
end

-- Quick actions --

---@param aceModule table
---@return boolean
local function HasAnchor(aceModule)
    for _, entry in pairs(NRSKNUI.Anchors.registry) do
        if entry.module == aceModule then
            return true
        end
    end
    return false
end

local function TogglePreview()
    local aceModule = AceModule()
    local manager = NRSKNUI.PreviewManager
    manager:SetModulePreview(aceModule, not manager:IsModulePreviewing(aceModule))
end

local function ToggleAnchors()
    local aceModule = AceModule()
    local anchors = NRSKNUI.Anchors
    local ours = anchors:IsActive() and anchors.onlyModule == aceModule
    if anchors:IsActive() then
        anchors:Exit()
    end
    -- a wider view was open: this swaps it for just this module's anchors
    if not ours then
        anchors:Enter(aceModule)
    end
end

local function Reset()
    local sets = PM:GetRoleSets(module)
    local function Accept(everything)
        PM:ResetModule(module, everything)
        Rebuild()
    end

    if not next(sets) then
        GUI:Prompt({
            title = L['Reset Module'],
            text = format(L['Reset %s settings to defaults?'], moduleName),
            onAccept = function() Accept(false) end,
            acceptText = L['Reset'],
            cancelText = L['Cancel'],
        })
        return
    end

    -- with role sets the reset can stop at the set on screen or take the whole module back to one set
    local shown = TabName(sets, PM:GetShownRole(module) or false)
    GUI:Prompt({
        title = L['Reset Module'],
        text = format(L['Reset only the %s settings for %s, or everything including the role settings?'], shown, moduleName),
        width = 360,
        onAccept = function() Accept(false) end,
        acceptText = format(L['Reset %s'], shown),
        altText = L['Reset Everything'],
        onAlt = function() Accept(true) end,
        cancelText = L['Cancel'],
    })
end

---@param aceModule table
---@return table[]
local function BuildActions(aceModule)
    local actions = {}
    if aceModule.ShowPreview then
        actions[#actions + 1] = {
            text = L['Preview'],
            tooltip = format(L['Show %s on every one of its pages, or hide it on its own'], moduleName),
            isActive = function() return NRSKNUI.PreviewManager:IsModulePreviewing(aceModule) end,
            onClick = TogglePreview,
        }
    end
    if HasAnchor(aceModule) then
        actions[#actions + 1] = {
            text = L['Anchors'],
            tooltip = format(L['Move %s, with every other anchor hidden'], moduleName),
            isActive = function() return NRSKNUI.Anchors:IsActive() and NRSKNUI.Anchors.onlyModule == aceModule end,
            onClick = ToggleAnchors,
        }
    end
    if OwnsNamespace() then
        actions[#actions + 1] = {
            text = L['Reset'],
            tooltip = format(L['Put %s back to its defaults'], moduleName),
            keepLive = true,
            onClick = Reset,
        }
    end
    return actions
end

-- Header --

header = GUI:CreatePageHeader(content.frame, {
    onTabSelect = Select,
    onTabMenu = OpenTabMenu,
})

---@return number height
local function Render()
    local aceModule = AceModule()
    local sets = PM:GetRoleSets(module)

    -- the shared set first, then each role with its own, in role order; a lone shared tab says nothing so it stays hidden
    local tabs = { { value = false, text = TabName(sets, false) } }
    for _, role in ipairs(ROLES) do
        if sets[role] then
            tabs[#tabs + 1] = { value = role, text = TabName(sets, role) }
        end
    end
    -- a module without role sets still shows ones it already has, since they apply on a spec swap and the tab's
    -- menu is the only way to remove them; it just never offers to add one
    if #tabs == 1 then
        tabs = {}
    end

    header:SetTitle(moduleName)
    header:SetIndex(moduleIndex)
    header:SetActions(aceModule and BuildActions(aceModule) or {})
    header:SetTabs(tabs, PM:GetShownRole(module) or false)
    header:SetAddButton(rolesAllowed and OwnsNamespace() and CanAdd(sets) and { tooltip = L['Give a role its own settings'], onClick = OpenAddMenu } or nil)
    -- off, the tabs and path grey and lock with the page; only the switch and Reset stay live
    header:SetDimmed(not ModuleOn())

    local switchModule = SwitchModule()
    if switchModule then
        header:SetSwitch({
            text = format(L['Enable %s'], moduleName),
            value = switchModule.db.Enabled,
            enabled = not (switchModule.IsBlocked and switchModule:IsBlocked()),
            msgText = moduleName,
            onToggle = function(checked)
                -- through the profile manager when every role set holds an Enabled, straight into the module's table otherwise
                if OwnsNamespace() then
                    PM:SetModuleEnabled(module, checked)
                else
                    switchModule.db.Enabled = checked
                end
                NRSKNUI:ToggleModule(module, checked)
                local hook = toggleHooks[module]
                if hook then
                    hook(checked)
                end
                Rebuild() -- the page greys out with it
            end,
        })
    else
        header:SetSwitch(nil)
    end

    return header:Render()
end

-- previews and the anchors view also change from elsewhere: a page change, the title bar's buttons, Escape;
-- the header draws before the preview manager hears of a new page, so it follows the managers' messages
local function FollowState()
    header:RefreshActions(true)
end
NRSKNUI:RegisterMessage('NRSKNUI_PREVIEWS_CHANGED', FollowState)
NRSKNUI:RegisterMessage('NRSKNUI_ANCHORS_CHANGED', FollowState)

-- Window hooks --

---@class ModuleHeader
local ModuleHeader = {}
NRSKNUI.ModuleHeader = ModuleHeader

---Called for every page change, before the page lays out.
---@param pageId string
function ModuleHeader:OnPage(pageId)
    local found, name, roles = FindModule(GUIFrame.SidebarConfig.systems, pageId)
    -- a module whose addon isn't loaded has nothing to head
    if found and not NRSKNUI:GetModule(found, true) then
        found = nil
    end
    -- another module, so the one we left goes back to the player's role and to previewing with its pages
    if found ~= module then
        PM:ClearEditRoles()
        NRSKNUI.PreviewManager:ClearModulePreviews()
        module, moduleName, rolesAllowed = found, name, roles
        header:ResetTabs()
    end

    if not module then
        content:SetHeader(nil)
        return
    end
    moduleIndex = Locate(pageId)
    content:SetHeader(header.frame, Render())
end

---A page's own follow-up to its module being switched on or off from the header, run once the module has toggled.
---@param name string the AceModule the sidebar entry names
---@param fn fun(enabled: boolean)
function ModuleHeader:OnToggle(name, fn)
    toggleHooks[name] = fn
end

function ModuleHeader:OnClose()
    module, moduleName = nil, nil
    PM:ClearEditRoles()
end

---@class NRSKNUI
local NRSKNUI = select(2, ...)

local pairs = pairs
local type = type
local next = next
local wipe = wipe

-- Preview Utilities --

local HOME_PAGE = 'homePage'

local PreviewManager = {
    guiOpen = false,
    anchorsActive = false,
    forceAll = false,
    currentPage = nil,
    active = {},
}
NRSKNUI.PreviewManager = PreviewManager

---Does this module claim the page itself, for the few that have no anchor to resolve through?
---@param module table
---@param pageId string
---@return boolean
local function ClaimsPage(module, pageId)
    local claim = module.previewPages
    if type(claim) == 'table' then
        for _, id in pairs(claim) do
            if id == pageId then return true end
        end
        return false
    end
    return claim == pageId
end

---@param module table
---@return boolean
local function IsPreviewable(module)
    return module.ShowPreview ~= nil and module.db ~= nil and module.db.Enabled == true
end

---Fill `into` with the modules a page configures.
---@param pageId string?
---@param into table module -> pageId
local function ResolvePage(pageId, into)
    if not pageId then return end

    local registry = NRSKNUI.Anchors and NRSKNUI.Anchors.registry
    if registry then
        for _, entry in pairs(registry) do
            if entry.guiPath == pageId and entry.module and IsPreviewable(entry.module) then
                into[entry.module] = pageId
            end
        end
    end

    for _, module in NRSKNUI:IterateModules() do
        if ClaimsPage(module, pageId) and IsPreviewable(module) then
            into[module] = pageId
        end
    end
end

---Fill `into` with every module that can preview.
---@param into table module -> true
local function ResolveAll(into)
    for _, module in NRSKNUI:IterateModules() do
        if IsPreviewable(module) then
            into[module] = true
        end
    end
end

---Whether everything previews at once, rather than only what the open page configures.
---@return boolean
function PreviewManager:ShouldShowAll()
    return self.forceAll or self.anchorsActive or self.currentPage == HOME_PAGE
end

---What a module is currently previewing, as one comparable value, so the diff can tell a module that
---only changed page from one that also changed between the everything view and a single page.
---@param scope string|boolean|nil the page it previews for or true for the everything view alone
---@param showAll boolean
---@return string?
local function ScopeKey(scope, showAll)
    if scope == nil then return nil end
    return (showAll and 'all:' or 'page:') .. tostring(scope)
end

---Bring the previews in line with the current state: stop what is leaving, start what is arriving and
---restart anything that stays but is now previewing something else.
function PreviewManager:Refresh()
    local wanted = {}
    local showAll = false

    if self.guiOpen or self.anchorsActive then
        showAll = self:ShouldShowAll()

        -- The everything view is a superset rather than a replacement: the open page still hands its
        -- module the page id, so a module that shows extra for its own page keeps showing it.
        if showAll then ResolveAll(wanted) end
        ResolvePage(self.currentPage, wanted)
    end

    local active = self.active

    -- Anything whose scope changed is dropped as well as anything leaving, so a module owning several
    -- pages gets told again below and previews the right part of itself.
    for module, key in pairs(active) do
        if ScopeKey(wanted[module], showAll) ~= key then
            module:HidePreview()
            active[module] = nil
        end
    end

    for module, scope in pairs(wanted) do
        if active[module] == nil then
            module:ShowPreview(scope ~= true and scope or nil, showAll)
            active[module] = ScopeKey(scope, showAll)
        end
    end
end

---@param open boolean
function PreviewManager:SetGUIOpen(open)
    self.guiOpen = open
    -- Intent goes with the window, so reopening resolves from the home page it always lands on rather
    -- than from wherever it was closed. forceAll is deliberately kept: it is a session-long override.
    if not open then self.currentPage = nil end
    self:Refresh()
end

---@param active boolean
function PreviewManager:SetAnchorsActive(active)
    self.anchorsActive = active
    self:Refresh()
end

---Called on every GUI page change, see window.content.onPageChanged.
---@param pageId string?
function PreviewManager:SetPage(pageId)
    if self.currentPage == pageId then return end

    self.currentPage = pageId
    self:Refresh()
end

---The header toggle: preview everything regardless of which page is open.
---@param force boolean
function PreviewManager:SetForceAll(force)
    if self.forceAll == force then return end

    self.forceAll = force
    self:Refresh()
end

---@return boolean
function PreviewManager:IsForceAll()
    return self.forceAll
end

---Drop every preview on the screen without changing what the state says should be showing, so a caller
---that is about to rebuild things can put them back with :Refresh.
function PreviewManager:StopAllPreviews()
    for module in pairs(self.active) do
        module:HidePreview()
    end
    wipe(self.active)
end

---@return boolean
function PreviewManager:IsPreviewActive()
    return next(self.active) ~= nil
end

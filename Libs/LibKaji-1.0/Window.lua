--[[
# Window

* The library-owned settings window: backdrop, crisp overlay border, draggable header (config-driven logo +
* auto-laid-out buttons), resizable footer (auto-laid-out social buttons + resize handle), a content host,
* session/position persistence and an in-combat defensive guard.
* The consuming addon supplies only config + content: `gui:CreateGUIWindow(opts)`, then `AddHeaderButton` /
* `AddFooterSocial` / `RegisterPage`. All chrome colours self-restyle via OnThemeChanged (no monolithic refresh).

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local Animations = lib.Animations
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local Mixin = Mixin
local ipairs = ipairs
local type = type
local rad = math.rad
local InCombatLockdown = InCombatLockdown

local C_Timer = C_Timer
local GameTooltip = GameTooltip
local UIParent = UIParent

local WHITE = "Interface\\Buttons\\WHITE8X8"

---@class KajiGUIWindowMixin
---@field gui KajiGUIInstance
---@field frame Frame & BackdropTemplate
---@field header Frame
---@field footer Frame
---@field content KajiGUIContentHost
local WindowMixin = {}

-- Resolves a logo/version anchor spec { point, [relLayerIndex], relPoint, x, y }. When the second
-- element is a number it anchors to that layer's texture, otherwise to the logo container.
local function ParseAnchor(spec, container, layerTex)
    if not spec then return "LEFT", container, "LEFT", 0, 0 end
    if type(spec[2]) == "number" then
        return spec[1], layerTex[spec[2]], spec[3], spec[4], spec[5]
    end
    return spec[1], container, spec[2], spec[3], spec[4]
end

-- Header / Footer builders --

local function BuildHeader(window, logoCfg)
    local gui, theme, parent = window.gui, window.gui.theme, window.frame

    local header = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    pixel.SetPixelHeight(header, theme.headerHeight)
    pixel.SetPixelPoint(header, "TOPLEFT", parent, "TOPLEFT", 0, 0)
    pixel.SetPixelPoint(header, "TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    header:SetBackdrop({ bgFile = WHITE })

    local bottomBorder = header:CreateTexture(nil, "BORDER")
    pixel.SetPixelHeight(bottomBorder, theme.borderSize)
    pixel.SetPixelPoint(bottomBorder, "BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    pixel.SetPixelPoint(bottomBorder, "BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)

    local layerTex = {}
    if logoCfg then
        local container = CreateFrame("Frame", nil, header)
        pixel.SetPixelSize(container, 180, 32)
        pixel.SetPixelPoint(container, "LEFT", header, "LEFT", theme.paddingLarge, -1)

        for i, layer in ipairs(logoCfg.layers or {}) do
            local t = container:CreateTexture(nil, "ARTWORK")
            pixel.SetPixelSize(t, layer.size, layer.size)
            pixel.SetPixelPoint(t, ParseAnchor(layer.anchor, container, layerTex))
            t:SetTexture(layer.texture)
            pixel.SetPixelSnap(t)
            layerTex[i] = t
            layer._tex = t
        end

        if logoCfg.version then
            local v = header:CreateFontString(nil, "OVERLAY")
            pixel.SetPixelPoint(v, ParseAnchor(logoCfg.versionAnchor, container, layerTex))
            v:SetFont("Fonts\\FRIZQT__.TTF", theme.fontSizeSmall or 10, "")
            v:SetText(logoCfg.version)
            v:SetJustifyH("LEFT")
            v:SetShadowColor(0, 0, 0, 0)
            window._logoVersion = v
        end
    end

    local function Restyle()
        header:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], theme.bgMedium[4])
        bottomBorder:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
        if logoCfg then
            for _, layer in ipairs(logoCfg.layers or {}) do
                if layer._tex then
                    local c = theme[layer.color] or theme.textSecondary
                    layer._tex:SetVertexColor(c[1], c[2], c[3], layer.alpha or c[4] or 1)
                end
            end
            if window._logoVersion then
                local c = theme[logoCfg.versionColor or "textSecondary"]
                window._logoVersion:SetTextColor(c[1], c[2], c[3], 1)
            end
        end
    end
    Restyle()
    gui:OnThemeChanged(Restyle)

    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() parent:StartMoving() end)
    header:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        pixel.SnapFrameEdges(parent)
        window:SavePosition()
    end)

    window.header = header
end

local function BuildFooter(window)
    local gui, theme, parent = window.gui, window.gui.theme, window.frame

    local footer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    pixel.SetPixelHeight(footer, theme.footerHeight)
    pixel.SetPixelPoint(footer, "BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    pixel.SetPixelPoint(footer, "BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    footer:SetBackdrop({ bgFile = WHITE })

    local topBorder = footer:CreateTexture(nil, "BORDER")
    pixel.SetPixelHeight(topBorder, theme.borderSize)
    pixel.SetPixelPoint(topBorder, "TOPLEFT", footer, "TOPLEFT", 0, 0)
    pixel.SetPixelPoint(topBorder, "TOPRIGHT", footer, "TOPRIGHT", 0, 0)

    local handle = CreateFrame("Button", nil, footer)
    pixel.SetPixelSize(handle, 23, 23)
    pixel.SetPixelPoint(handle, "BOTTOMRIGHT", footer, "BOTTOMRIGHT", -2, 2)
    handle:EnableMouse(true)

    local htex = handle:CreateTexture(nil, "OVERLAY")
    htex:SetAllPoints()
    htex:SetTexture(theme.resizeHandleTexture)
    pixel.SetPixelSnap(htex)

    local function HandleColor(hover)
        local c = hover and theme.accent or theme.textSecondary
        htex:SetVertexColor(c[1], c[2], c[3], hover and 1 or 0.6)
    end
    HandleColor(false)

    handle:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            htex:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            parent:StartSizing("BOTTOMRIGHT")
        end
    end)
    handle:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            HandleColor(false)
            parent:StopMovingOrSizing()
            pixel.SnapFrameEdges(parent)
            if window.content then C_Timer.After(0.05, window.content.UpdateScrollbar) end
            window:SavePosition()
        end
    end)
    handle:SetScript("OnEnter", function() HandleColor(true) end)
    handle:SetScript("OnLeave", function() HandleColor(false) end)

    footer:EnableMouse(true)
    footer:RegisterForDrag("LeftButton")
    footer:SetScript("OnDragStart", function() parent:StartMoving() end)
    footer:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        pixel.SnapFrameEdges(parent)
        window:SavePosition()
    end)

    local function Restyle()
        footer:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], theme.bgMedium[4])
        topBorder:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
        HandleColor(false)
    end
    Restyle()
    gui:OnThemeChanged(Restyle)

    window.footer = footer
end

-- Public window methods --

---Adds a header button, auto-packed from the right edge in add order.
---@param config table { icon, size?, width?, height?, onClick?, tooltip?, rotation?, strata?, yOffset? }
---@return Button
function WindowMixin:AddHeaderButton(config)
    local gui, theme, header = self.gui, self.gui.theme, self.header
    local size = config.size or 22
    local width = config.width or size

    local btn = CreateFrame("Button", nil, header)
    pixel.SetPixelSize(btn, width, config.height or size)
    pixel.SetPixelPoint(btn, "RIGHT", header, "RIGHT", self._headerCursor, config.yOffset or 0)
    self._headerCursor = self._headerCursor - width - theme.paddingSmall
    if config.strata then btn:SetFrameStrata(config.strata) end

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(config.icon)
    pixel.SetPixelSnap(tex)
    if config.rotation then tex:SetRotation(rad(config.rotation)) end
    btn:SetNormalTexture(tex)

    local function ApplyAlpha(a)
        tex:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], a)
    end
    ApplyAlpha(0.7)
    -- Tween only alpha; the setter reads accent live so theme changes keep the tint correct.
    local animateAlpha = Animations:CreateColorAnimator(btn, function(_, _, _, a) ApplyAlpha(a) end,
        { 0, 0, 0, 0.7 }, theme.animDuration)
    gui:OnThemeChanged(function() ApplyAlpha(0.7) end)

    btn:SetScript("OnEnter", function()
        animateAlpha(0, 0, 0, 1)
        if config.tooltip then
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT", 0, 10)
            GameTooltip:SetText(config.tooltip, theme.accent[1], theme.accent[2], theme.accent[3], 1, false)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function()
        animateAlpha(0, 0, 0, 0.7)
        GameTooltip:Hide()
    end)
    if config.onClick then
        btn:SetScript("OnClick", function() safecall(config.onClick) end)
    end

    return btn
end

---Adds a footer social button, auto-packed from the left edge in add order.
---@param config table { icon, text?, width?, onClick?, tooltip? }
---@return Button
function WindowMixin:AddFooterSocial(config)
    local gui, theme, footer = self.gui, self.gui.theme, self.footer
    local width = config.width or 68

    local btn = CreateFrame("Button", nil, footer)
    pixel.SetPixelSize(btn, width, 21)
    pixel.SetPixelPoint(btn, "LEFT", footer, "LEFT", self._footerCursor, 0)
    self._footerCursor = self._footerCursor + width + theme.paddingMedium

    local tex = btn:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelSize(tex, 21, 21)
    pixel.SetPixelPoint(tex, "LEFT", btn, "LEFT", 0, 0)
    tex:SetTexture(config.icon)
    pixel.SetPixelSnap(tex)

    local label = btn:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "LEFT", tex, "RIGHT", theme.paddingSmall, 1)
    gui:ApplyFont(label, "normal")
    label:SetText(config.text or "")
    label:SetShadowColor(0, 0, 0, 0)

    local function Restyle(hover)
        local a = hover and 1 or 0.7
        tex:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], a)
        label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], a)
    end
    Restyle(false)
    gui:OnThemeChanged(function() Restyle(false) end)

    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnClick", function() safecall(config.onClick) end)
    btn:SetScript("OnEnter", function() Restyle(true) end)
    btn:SetScript("OnLeave", function() Restyle(false) end)

    return btn
end

---Builds and shows the page registered under id, remembering it as the current page.
---@param id string
function WindowMixin:ShowPage(id)
    self._currentId = id
    if self.content then self.content:ShowPage(id) end
    if self.sidebar then self.sidebar:SetSelected(id) end
end

local SEARCH_BOX_HEIGHT = 30

---Builds the navigation sidebar + search box from a config list and wires selection to ShowPage.
---@param config table[] sidebar entry list (headers / items)
---@param opts? table { isDisabled?: fun(entry): boolean }
---@return table sidebar
function WindowMixin:SetSidebar(config, opts)
    opts = opts or {}
    local gui, theme, frame = self.gui, self.gui.theme, self.frame
    self._sidebarConfig = config

    -- Inset the content to the right of the sidebar column.
    self.contentContainer:ClearAllPoints()
    pixel.SetPixelPoint(self.contentContainer, "TOPLEFT", frame, "TOPLEFT", theme.sidebarWidth, -theme.headerHeight)
    pixel.SetPixelPoint(self.contentContainer, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, theme.footerHeight)

    local sidebar
    sidebar = gui:CreateSidebar(frame, {
        config = config,
        isDisabled = opts.isDisabled,
        onSelect = function(id, searchResult)
            self._currentId = id
            self.content:ShowPage(id)
            if searchResult and searchResult.isWidget then self.content:ScrollToLabel(searchResult.text) end
            sidebar:EnsureExpandedFor(id)
            self:SavePosition()
        end,
    })
    pixel.SetPixelPoint(sidebar.frame, "TOPLEFT", frame, "TOPLEFT", 0, -(theme.headerHeight + SEARCH_BOX_HEIGHT - 1))
    pixel.SetPixelPoint(sidebar.frame, "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, theme.footerHeight)
    pixel.SetPixelWidth(sidebar.frame, theme.sidebarWidth)
    self.sidebar = sidebar

    local search = gui:CreateSearchBox(frame, {
        height = SEARCH_BOX_HEIGHT,
        onChanged = function(text)
            if text == "" then
                sidebar:ClearResults()
            else
                sidebar:ShowResults(gui:Search(text, config))
            end
        end,
    })
    pixel.SetPixelPoint(search, "TOPLEFT", frame, "TOPLEFT", 0, -(theme.headerHeight -1))
    pixel.SetPixelWidth(search, theme.sidebarWidth)
    self.searchBox = search

    -- Initial render with config defaults. Session (expansion/selection) restores on first Show
    -- via RestorePosition, once the saved DB is available (it isn't at file-load time).
    if self._currentId then sidebar:EnsureExpandedFor(self._currentId) end
    sidebar:Refresh()
    if self._currentId then sidebar:SetSelected(self._currentId) end

    return sidebar
end

function WindowMixin:Show()
    if self._showing then return end
    self._showing = true

    if self.inCombat then
        if self._onCombatDefer then safecall(self._onCombatDefer) end
        self.reopenAfterCombat = true
        self._showing = false
        return
    end

    if not self._restored then
        self:RestorePosition()
        self._restored = true
    end

    self.frame:Show()
    self.frame:Raise()
    if self._currentId then self:ShowPage(self._currentId) end
    if self._onShow then safecall(self._onShow) end

    self._showing = false
end

function WindowMixin:Hide()
    self.frame:Hide() -- OnHide handles persistence + onClose
end

function WindowMixin:Toggle()
    if self:IsShown() then self:Hide() else self:Show() end
end

---@return boolean
function WindowMixin:IsShown()
    return self.frame:IsShown() and true or false
end

function WindowMixin:SavePosition()
    local state = self._state
    if not state or not state.save then return end
    local frame = self.frame
    local point, _, relPoint, x, y = frame:GetPoint()
    state.save({
        frame = {
            point = point,
            relativePoint = relPoint,
            xOffset = x,
            yOffset = y,
            width = frame:GetWidth(),
            height = frame:GetHeight(),
        },
        currentPage = self._currentId,
        sidebarExpanded = self.sidebar and self.sidebar:GetExpanded() or nil,
    })
end

function WindowMixin:RestorePosition()
    local state = self._state
    local data = state and state.load and state.load()
    if not data then return end
    if data.frame then
        local f = data.frame
        self.frame:ClearAllPoints()
        pixel.SetPixelPoint(self.frame, f.point or "CENTER", UIParent, f.relativePoint or "CENTER", f.xOffset or 0, f.yOffset or 50)
        if f.width and f.height then pixel.SetPixelSize(self.frame, f.width, f.height) end
    end
    if data.currentPage then self._currentId = data.currentPage end
    if self.sidebar then
        if data.sidebarExpanded then self.sidebar:SetExpanded(data.sidebarExpanded) end
        if self._currentId then self.sidebar:EnsureExpandedFor(self._currentId) end
        self.sidebar:Refresh()
        self.sidebar:SetSelected(self._currentId)
    end
end

-- Constructor --

---@class KajiGUIWindowOptions
---@field name? string global frame name
---@field size? number[] { width, height }
---@field minSize? number[] { minWidth, minHeight }
---@field logo? table { layers = { {texture,size,anchor,color,alpha}, ... }, version?, versionAnchor?, versionColor? }
---@field state? table { load: fun(): table?, save: fun(data: table) } addon-owned persistence
---@field defaultPage? string page id shown on first open
---@field onShow? fun()
---@field onClose? fun()
---@field onCombatDefer? fun() called when Show is blocked by combat

---Creates the library-owned settings window.
---@param opts? KajiGUIWindowOptions
---@return KajiGUIWindow
function InstanceMixin:CreateGUIWindow(opts)
    opts = opts or {}
    local gui = self
    local theme = self.theme

    -- The high-strata reparent target for open dropdowns (folds in the old GUIOverlay).
    if not self.overlay then
        local overlay = CreateFrame("Frame", nil, UIParent)
        overlay:SetAllPoints(UIParent)
        overlay:SetFrameStrata("TOOLTIP")
        overlay:SetFrameLevel(1)
        overlay:EnableMouse(false)
        self.overlay = overlay
    end

    local w = (opts.size and opts.size[1]) or 950
    local h = (opts.size and opts.size[2]) or 700
    local minW = (opts.minSize and opts.minSize[1]) or w
    local minH = (opts.minSize and opts.minSize[2]) or h

    local frame = CreateFrame("Frame", opts.name, UIParent, "BackdropTemplate")
    pixel.SetPixelSize(frame, w, h)
    pixel.SetPixelPoint(frame, "CENTER", UIParent, "CENTER", 0, 50)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(false)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(minW, minH)
    frame:EnableMouse(true)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = theme.borderSize })
    pixel.SetPixelSnap(frame)
    frame:Hide()

    ---@class KajiGUIWindow : KajiGUIWindowMixin
    local window = Mixin({ gui = gui, frame = frame }, WindowMixin)
    window._state = opts.state
    window._onShow = opts.onShow
    window._onClose = opts.onClose
    window._onCombatDefer = opts.onCombatDefer
    window._currentId = opts.defaultPage
    window._headerCursor = -(theme.paddingSmall + 2) -- running right edge for header buttons
    window._footerCursor = theme.paddingMedium       -- running left edge for footer socials
    window.inCombat = InCombatLockdown() and true or false

    local function RestyleFrame()
        frame:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], theme.bgDark[4])
        frame:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
    end
    RestyleFrame()
    gui:OnThemeChanged(RestyleFrame)

    BuildHeader(window, opts.logo)

    -- Content fills the area between header and footer. SetSidebar insets the left edge later.
    local container = CreateFrame("Frame", nil, frame)
    pixel.SetPixelPoint(container, "TOPLEFT", frame, "TOPLEFT", 0, -theme.headerHeight)
    pixel.SetPixelPoint(container, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, theme.footerHeight)
    window.contentContainer = container
    window.content = gui:CreateContentHost(container, {})

    BuildFooter(window)

    -- Keyboard: ESC closes, everything else propagates.
    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", function(f, key)
        if key == "ESCAPE" then
            f:SetPropagateKeyboardInput(false)
            window:Hide()
        else
            f:SetPropagateKeyboardInput(true)
        end
    end)

    frame:SetScript("OnHide", function()
        window:SavePosition()
        if window._onClose then safecall(window._onClose) end
    end)

    -- Defensive combat guard: hide on combat start, reopen after if it was open.
    local combatFrame = CreateFrame("Frame")
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            window.inCombat = true
            if window:IsShown() then
                window.reopenAfterCombat = true
                window:Hide()
            end
        else
            window.inCombat = false
            if window.reopenAfterCombat then
                window.reopenAfterCombat = nil
                window:Show()
            end
        end
    end)

    return window
end

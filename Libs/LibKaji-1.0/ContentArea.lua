--[[
# ContentArea

* The window's content host: a scrollable region that renders a registered page by id.
* Pages are declared with `gui:RegisterPage(id, descriptor)` and shown with `host:ShowPage(id)`.
* A descriptor's `mode` selects the layout:
*     clean -> a single scrollable fluent page (build(page))
*     tabs  -> a sub-tab strip over per-tab pages (build(page, tabId))
* A `sidebar` field adds a left item list (MiniSidebar) beside the scroll region, orthogonal to mode:
* page-level in clean mode, or on a tab entry in tabs mode.
*     sidebar = { items: table|fun():table, width?, buttons?, renderItem?, default? }
* All layouts share the uniform contract build(page, tabId, itemKey, item) — trailing args are nil
* when no tab strip / sidebar is active, so plain pages just declare build(page).
*
* tabs descriptor: { mode='tabs', tabs = { {id, text, disabled?, sidebar?}, ... }, build = fun(page, tabId, ...) }
* The strip wraps to multiple justified rows when the tabs overflow the content width (see CreateTabStrip).

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local ipairs = ipairs
local wipe = wipe
local PlaySound = PlaySound
local tremove = table.remove
local strfind, strlower = string.find, string.lower
local mmax, mmin = math.max, math.min

local C_Timer = C_Timer
local SOUNDKIT = SOUNDKIT

-- Finds the first FontString under `root` whose text contains `label` (case-insensitive),
-- and returns the frame that owns it. Used to jump to a widget search result.
local function FindOwnerByLabel(root, label)
    local q = strlower(label)
    local stack = { root }
    while #stack > 0 do
        local f = tremove(stack)
        for _, region in ipairs({ f:GetRegions() }) do
            if region:IsObjectType("FontString") then
                local t = region:GetText()
                if t and strfind(strlower(t), q, 1, true) then return region:GetParent() end
            end
        end
        for _, child in ipairs({ f:GetChildren() }) do stack[#stack + 1] = child end
    end
end

---Registers a page descriptor under an id. The window's content host builds it on ShowPage(id).
---@param id string
---@param descriptor table { mode?: "clean"|"tabs", build: fun(page, tabId?, itemKey?, item?), tabs?, sidebar?, search? }
function InstanceMixin:RegisterPage(id, descriptor)
    self._pages = self._pages or {}
    self._pages[id] = descriptor
end

---@param scrollChild Frame
local function ClearScrollChild(scrollChild)
    for _, child in ipairs({ scrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({ scrollChild:GetRegions() }) do
        if region:IsObjectType("FontString") or region:IsObjectType("Texture") then
            region:Hide()
        end
    end
    pixel.SetPixelHeight(scrollChild, 1)
end

local TAB_ROW_HEIGHT = 29      -- height of one row of tabs
local TAB_STRIP_TOP = 0        -- gap above the first row
local TAB_HPAD = 14            -- horizontal padding on each side of a tab label
local TAB_UNDERLINE = 2        -- selected-tab underline thickness
local UNDERLINE_INSET = 6      -- underline is shorter than the tab by this on each side
local JUSTIFY_THRESHOLD = 0.75 -- a lone row under this fill ratio stays left-packed instead of justified

-- Scratch tables reused across a single BuildTabs pass.
local widths, rowwidths, rowends = {}, {}, {}

---Creates a tab strip that wraps to multiple justified rows when the tabs overflow the content width.
---@param gui KajiGUIInstance
---@param parent Frame the strip pins to the top of this frame; its height grows with the row count
---@param opts table { onSelect: fun(tabId) }
---@return table strip
local function CreateTabStrip(gui, parent, opts)
    local theme = gui.theme
    local onSelect = opts.onSelect

    local frame = CreateFrame("Frame", nil, parent)
    pixel.SetPixelPoint(frame, "TOPLEFT", parent, "TOPLEFT", 0, 0)
    pixel.SetPixelPoint(frame, "TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    pixel.SetPixelHeight(frame, TAB_STRIP_TOP + TAB_ROW_HEIGHT)

    -- Boundary line between the strip and the content below it.
    local baseline = frame:CreateTexture(nil, "BORDER")
    pixel.SetPixelHeight(baseline, theme.borderSize)
    pixel.SetPixelPoint(baseline, "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    pixel.SetPixelPoint(baseline, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    local strip = { frame = frame, selected = nil }
    local pool, active = {}, {}

    local function ApplyTabState(tab)
        if tab.disabled then
            tab.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.35)
            tab.underline:Hide()
        elseif tab.value == strip.selected then
            tab.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            tab.underline:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            tab.underline:Show()
        else
            tab.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
            tab.underline:Hide()
        end
    end

    local function CreateTab()
        local tab = CreateFrame("Button", nil, frame)
        pixel.SetPixelHeight(tab, TAB_ROW_HEIGHT)
        tab:RegisterForClicks("LeftButtonUp")

        local label = tab:CreateFontString(nil, "OVERLAY")
        pixel.SetPixelPoint(label, "CENTER", tab, "CENTER", 0, 0)
        label:SetJustifyH("CENTER")
        label:SetWordWrap(false)
        tab.label = label

        local underline = tab:CreateTexture(nil, "OVERLAY")
        pixel.SetPixelHeight(underline, TAB_UNDERLINE)
        pixel.SetPixelPoint(underline, "BOTTOMLEFT", tab, "BOTTOMLEFT", UNDERLINE_INSET, 0)
        pixel.SetPixelPoint(underline, "BOTTOMRIGHT", tab, "BOTTOMRIGHT", -UNDERLINE_INSET, 0)
        underline:Hide()
        tab.underline = underline

        tab:SetScript("OnEnter", function(self)
            if self.disabled or self.value == strip.selected then return end
            self.label:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
            self.underline:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.3)
            self.underline:Show()
        end)
        tab:SetScript("OnLeave", function(self)
            if self.disabled or self.value == strip.selected then return end
            ApplyTabState(self)
        end)
        tab:SetScript("OnClick", function(self)
            if self.disabled or self.value == strip.selected then return end
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            strip:Select(self.value)
        end)

        return tab
    end

    local function AcquireTab()
        for _, t in ipairs(pool) do
            if not t.inUse then
                t.inUse = true; t:Show(); return t
            end
        end
        local t = CreateTab()
        t.inUse = true
        pool[#pool + 1] = t
        return t
    end

    local function ReleaseAll()
        for _, t in ipairs(pool) do
            t.inUse = false; t.disabled = nil; t.value = nil
            t.underline:Hide(); t:Hide(); t:ClearAllPoints()
        end
        wipe(active)
    end

    -- Greedy line-wrap into justified rows. Runs on tab change and on width change.
    function strip:Layout()
        local width = frame:GetWidth()
        if not width or width <= 0 or #active == 0 then return end

        wipe(widths); wipe(rowwidths); wipe(rowends)
        for i, tab in ipairs(active) do widths[i] = tab.naturalWidth end

        -- Pass 1: pack tabs into rows, opening a new row when the next tab won't fit.
        local numrows, used = 1, 0
        for i = 1, #active do
            if used ~= 0 and (width - used - widths[i]) < 0 then
                rowwidths[numrows] = used
                rowends[numrows] = i - 1
                numrows = numrows + 1
                used = 0
            end
            used = used + widths[i]
        end
        rowwidths[numrows] = used
        rowends[numrows] = #active

        -- Avoid a lone tab dangling on the last row: pull one down from the row above
        -- if that row has spare tabs and the last row has room (generalizes AceGUI's fix).
        if numrows > 1 and (rowends[numrows] - rowends[numrows - 1]) == 1 then
            local prevCount = rowends[numrows - 1] - (rowends[numrows - 2] or 0)
            local moved = widths[rowends[numrows - 1]]
            if prevCount > 2 and (rowwidths[numrows] + moved) <= width then
                rowends[numrows - 1] = rowends[numrows - 1] - 1
                rowwidths[numrows] = rowwidths[numrows] + moved
                rowwidths[numrows - 1] = rowwidths[numrows - 1] - moved
            end
        end

        -- Pass 2: stack rows top-down and stretch each row's tabs to fill the width.
        local starttab = 1
        for row, endtab in ipairs(rowends) do
            local count = endtab - starttab + 1
            local justify = not (numrows == 1 and rowwidths[row] < width * JUSTIFY_THRESHOLD)
            local extra = justify and mmax(0, (width - rowwidths[row]) / count) or 0
            local y = -(TAB_STRIP_TOP + (row - 1) * TAB_ROW_HEIGHT)
            for i = starttab, endtab do
                local tab = active[i]
                tab:ClearAllPoints()
                pixel.SetPixelWidth(tab, widths[i] + extra)
                if i == starttab then
                    pixel.SetPixelPoint(tab, "TOPLEFT", frame, "TOPLEFT", 0, y)
                else
                    pixel.SetPixelPoint(tab, "TOPLEFT", active[i - 1], "TOPRIGHT", 0, 0)
                end
            end
            starttab = endtab + 1
        end

        pixel.SetPixelHeight(frame, TAB_STRIP_TOP + numrows * TAB_ROW_HEIGHT)
    end

    ---@param tabs table[] { {id, text, disabled?}, ... }
    function strip:SetTabs(tabs)
        ReleaseAll()
        for i, t in ipairs(tabs) do
            local tab = AcquireTab()
            tab.value = t.id
            tab.disabled = t.disabled or false
            tab:EnableMouse(not tab.disabled)
            tab.label:Show()
            gui:ApplyFont(tab.label, "normal")
            tab.label:SetText(t.text or "")
            tab.naturalWidth = tab.label:GetStringWidth() + TAB_HPAD * 2
            active[i] = tab
        end
        self:Layout()
        for _, tab in ipairs(active) do ApplyTabState(tab) end
    end

    ---Selects a tab and fires onSelect.
    ---@param value any
    function strip:Select(value)
        self.selected = value
        for _, tab in ipairs(active) do ApplyTabState(tab) end
        if onSelect then safecall(onSelect, value) end
    end

    frame:HookScript("OnSizeChanged", function() strip:Layout() end)

    local function Restyle()
        baseline:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
        for _, tab in ipairs(active) do
            gui:ApplyFont(tab.label, "normal")
            ApplyTabState(tab)
        end
    end
    Restyle()
    gui:OnThemeChanged(Restyle)

    return strip
end

---Creates the scrollable content host filling a parent frame.
---@param parent Frame
---@param opts? table { showBackground?: boolean, topOffset?: number, scrollbarOptions?: table }
---@return table host
function InstanceMixin:CreateContentHost(parent, opts)
    opts = opts or {}
    local gui = self
    local theme = self.theme
    local topOffset = opts.topOffset or theme.paddingSmall
    local scrollbarWidth = (opts.scrollbarOptions and opts.scrollbarOptions.width) or theme.scrollbarWidth or 16

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetAllPoints(parent)
    if opts.showBackground ~= false then
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        local function Restyle()
            frame:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], theme.bgDark[4])
        end
        Restyle()
        gui:OnThemeChanged(Restyle)
    end

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetClipsChildren(true)

    -- Scroll region fills the host (clean mode), starts below the tab strip (tabs mode)
    -- and to the right of the mini sidebar when one is active.
    local function AnchorScrollTop()
        scrollFrame:ClearAllPoints()
        pixel.SetPixelPoint(scrollFrame, "TOPLEFT", frame, "TOPLEFT", 0, 0)
        pixel.SetPixelPoint(scrollFrame, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    end
    local function AnchorScrollBelow(stripFrame)
        scrollFrame:ClearAllPoints()
        pixel.SetPixelPoint(scrollFrame, "TOPLEFT", stripFrame, "BOTTOMLEFT", 0, 0)
        pixel.SetPixelPoint(scrollFrame, "TOPRIGHT", stripFrame, "BOTTOMRIGHT", 0, 0)
        pixel.SetPixelPoint(scrollFrame, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    end
    local function AnchorScrollBeside(sidebarFrame)
        scrollFrame:ClearAllPoints()
        pixel.SetPixelPoint(scrollFrame, "TOPLEFT", sidebarFrame, "TOPRIGHT", 0, 0)
        pixel.SetPixelPoint(scrollFrame, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    end
    AnchorScrollTop()

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    pixel.SetPixelHeight(scrollChild, 1)
    scrollFrame:SetScrollChild(scrollChild)

    local scrollbar = gui:CreateScrollbar(scrollFrame, opts.scrollbarOptions or {
        width = 16,
        thumbHeight = 40,
        padding = { top = -1, bottom = -1, right = 0 },
        scrollStep = 40,
    })

    local scrollbarVisible = false
    local sidebarInset = 0
    local function ApplyScrollChildWidth()
        local w = frame:GetWidth() - sidebarInset
        pixel.SetPixelWidth(scrollChild, scrollbarVisible and (w - scrollbarWidth) or w)
    end

    local function UpdateScrollbar()
        scrollbarVisible = scrollbar:UpdateVisibility(scrollChild:GetHeight(), scrollFrame:GetHeight())
        ApplyScrollChildWidth()
    end

    scrollFrame:HookScript("OnSizeChanged", UpdateScrollbar)
    scrollFrame:HookScript("OnShow", function() UpdateScrollbar() end)
    ApplyScrollChildWidth()

    ---@class KajiGUIContentHost
    local host = {
        frame = frame,
        scrollFrame = scrollFrame,
        scrollChild = scrollChild,
        scrollbar = scrollbar,
        UpdateScrollbar = UpdateScrollbar,
        _tabMemory = {},  -- last selected tab id per page id
        _itemMemory = {}, -- last selected sidebar item key per page/tab
    }

    local tabStrip, miniSidebar

    local function ResetScroll()
        if scrollbar:IsShown() then scrollbar:SetValue(0) else scrollFrame:SetVerticalScroll(0) end
    end

    local function MemoryKey()
        return (host.currentId or "") .. "/" .. (host._currentTab or "")
    end

    -- Builds a fluent page into the (freshly cleared) scroll child. `tabId`, `itemKey` and `item`
    -- are nil when no tab strip / sidebar is active.
    local function BuildPage(descriptor, tabId, itemKey, item)
        local page = gui:CreatePage(scrollChild, topOffset, {
            onLayout = function() UpdateScrollbar() end,
        })
        safecall(descriptor.build, page, tabId, itemKey, item)
        page:Finish()
        host.page = page
        UpdateScrollbar()
    end

    local function AnchorMiniSidebar(stripFrame)
        local msf = miniSidebar.frame
        msf:ClearAllPoints()
        if stripFrame then
            pixel.SetPixelPoint(msf, "TOPLEFT", stripFrame, "BOTTOMLEFT", 0, 0)
        else
            pixel.SetPixelPoint(msf, "TOPLEFT", frame, "TOPLEFT", 0, 0)
        end
        pixel.SetPixelPoint(msf, "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    end

    local function EnsureMiniSidebar()
        if miniSidebar then return miniSidebar end
        miniSidebar = gui:CreateMiniSidebar(frame, {
            onSelect = function(key, item)
                local descriptor = host._descriptor
                if not descriptor then return end
                host._itemMemory[MemoryKey()] = key
                ClearScrollChild(scrollChild)
                host.page = nil
                BuildPage(descriptor, host._currentTab, key, item)
                ResetScroll()
            end,
        })
        host.miniSidebar = miniSidebar
        return miniSidebar
    end

    -- The per-tab sidebar (tabs) or the page-level one (clean).
    local function ResolveSidebar(descriptor, tabId)
        if tabId then
            for _, t in ipairs(descriptor.tabs or {}) do
                if t.id == tabId then return t.sidebar end
            end
            return nil
        end
        return descriptor.sidebar
    end

    -- Picks the item to select: the remembered one if still present, else the declared default, else the first.
    local function ResolveInitialItem(items, remembered, default)
        local first, def
        for _, data in ipairs(items or {}) do
            if data.key == remembered then return data.key, data end
            if data.key == default then def = data end
            first = first or data
        end
        if def then return def.key, def end
        if first then return first.key, first end
    end

    -- Shows the content for a page (clean: tabId nil) or one of its tabs, attaching the
    -- mini sidebar when the descriptor/tab declares one.
    local function ShowContent(descriptor, tabId)
        host._currentTab = tabId
        local sd = ResolveSidebar(descriptor, tabId)
        local stripFrame = tabId and tabStrip and tabStrip.frame or nil
        if sd then
            local ms = EnsureMiniSidebar()
            local items = ms:SetConfig(sd)
            ms.frame:Show()
            sidebarInset = sd.width or 192
            AnchorMiniSidebar(stripFrame)
            AnchorScrollBeside(ms.frame)
            local key, item = ResolveInitialItem(items, host._itemMemory[MemoryKey()], sd.default)
            ms:SetSelected(key)
            BuildPage(descriptor, tabId, key, item)
        else
            if miniSidebar then miniSidebar.frame:Hide() end
            sidebarInset = 0
            if stripFrame then AnchorScrollBelow(stripFrame) else AnchorScrollTop() end
            BuildPage(descriptor, tabId)
        end
    end

    -- tabs: a wrapping sub-tab strip over per-tab content built with ShowContent.
    local function EnsureTabStrip()
        if tabStrip then return tabStrip end
        tabStrip = CreateTabStrip(gui, frame, {
            onSelect = function(tabId)
                local descriptor = host._descriptor
                if not descriptor then return end
                host._tabMemory[host.currentId] = tabId
                ClearScrollChild(scrollChild)
                host.page = nil
                ShowContent(descriptor, tabId)
                ResetScroll()
            end,
        })
        host.tabStrip = tabStrip
        return tabStrip
    end

    -- Picks the tab to open: the remembered one for this page if still valid, else the first enabled tab.
    local function ResolveInitialTab(tabs, remembered)
        local first
        for _, t in ipairs(tabs) do
            if not t.disabled then
                if t.id == remembered then return remembered end
                first = first or t.id
            end
        end
        return first
    end

    local function ShowTabs(descriptor)
        local strip = EnsureTabStrip()
        strip.frame:Show()
        local tabs = descriptor.tabs or {}
        strip:SetTabs(tabs)
        local initial = ResolveInitialTab(tabs, host._tabMemory[host.currentId])
        if initial then strip:Select(initial) end
    end

    ---Builds and shows the page registered under id.
    ---@param id string
    function host:ShowPage(id)
        local descriptor = gui._pages and gui._pages[id]
        ClearScrollChild(scrollChild)
        host.page = nil
        host.currentId = id
        host._descriptor = descriptor

        local mode = descriptor and (descriptor.mode or "clean")
        if mode == "tabs" then
            ShowTabs(descriptor)
            return
        end

        if tabStrip then tabStrip.frame:Hide() end
        if descriptor then
            ShowContent(descriptor, nil)
        else
            host._currentTab = nil
            if miniSidebar then miniSidebar.frame:Hide() end
            sidebarInset = 0
            AnchorScrollTop()
            UpdateScrollbar()
        end
    end

    -- Briefly flashes a frame with an accent overlay (search result feedback).
    ---@param widget Frame
    function host:FlashWidget(widget)
        if not widget then return end
        local overlay = widget._kajiFlash
        if not overlay then
            overlay = CreateFrame("Frame", nil, widget)
            overlay:SetAllPoints()
            overlay:SetFrameLevel(widget:GetFrameLevel() + 10)
            overlay.tex = overlay:CreateTexture(nil, "OVERLAY")
            overlay.tex:SetAllPoints()
            local ag = overlay:CreateAnimationGroup()
            local fade = ag:CreateAnimation("Alpha")
            fade:SetFromAlpha(1); fade:SetToAlpha(0); fade:SetDuration(1.5); fade:SetSmoothing("OUT")
            ag:SetScript("OnFinished", function() overlay:Hide() end)
            overlay._ag = ag
            widget._kajiFlash = overlay
        end
        overlay.tex:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.3)
        overlay:Show(); overlay:SetAlpha(1)
        overlay._ag:Stop(); overlay._ag:Play()
    end

    -- Scrolls the content so the widget whose label matches `label` is visible, then flashes it.
    ---@param label string
    function host:ScrollToLabel(label)
        if not label or label == "" then return end
        C_Timer.After(0.05, function()
            local owner = FindOwnerByLabel(scrollChild, label)
            if not owner then return end
            local ownerTop, childTop = owner:GetTop(), scrollChild:GetTop()
            if not ownerTop or not childTop then return end
            local maxScroll = mmax(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
            local target = mmax(0, mmin(childTop - ownerTop - 50, maxScroll))
            if scrollbar:IsShown() then scrollbar:SetValue(target) else scrollFrame:SetVerticalScroll(target) end
            host:FlashWidget(owner)
        end)
    end

    return host
end

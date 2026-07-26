--[[
# ContentArea

* The window's content host: a scrollable region that renders a registered page by id.
* Pages are declared with `gui:RegisterPage(id, descriptor)` and shown with `host:ShowPage(id)`.
* A descriptor's `mode` selects the layout:
*     clean -> a single scrollable fluent page (build(page))
*     tabs  -> a sub-tab strip over per-tab pages (build(page, tabId))
* A `sidebar` field adds a full-height left item list (MiniSidebar) beside the scroll region, orthogonal to mode:
*     sidebar = { items: table|fun():table, width?, buttons?, renderItem?, onContextMenu?, default? }
* All layouts share the uniform contract build(page, tabId, itemKey, item) — trailing args are nil
* when no tab strip / sidebar is active, so plain pages just declare build(page).
*
* tabs descriptor: { mode='tabs', tabs = { {id, text, disabled?, sidebar?}, ... }, build = fun(page, tabId, ...) }
* The strip wraps to multiple justified rows when the tabs overflow the content width (see CreateTabStrip).
*
* Where the sidebar sits decides which axis drives the other:
*     tab-outer    -> `sidebar` on a tab entry: the selected tab decides the item list.
*     sidebar-outer-> `sidebar` page-level alongside mode='tabs': the item list is fixed and the
*                     selected item decides the tabs. Pass `tabs = fun(itemKey, item) -> tabs[]`
*                     to vary them per item; a static table works too.

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

local TAB_ROW_HEIGHT = 29 -- height of one row of tabs
local TAB_STRIP_TOP = 0   -- gap above the first row
local TAB_HPAD = 14       -- horizontal padding on each side of a tab label
local TAB_GAP = 2         -- gap between the bordered tab buttons (and below them, before the next row)
local TAB_INSET = 4       -- padding between the strip's edges and the tab buttons
local TAB_UNDERLINE = 2   -- selected-tab underline thickness
local UNDERLINE_INSET = 1 -- underline is shorter than the tab by this on each side
local TAB_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

-- Scratch tables reused across a single BuildTabs pass.
local widths, rowwidths, rowends = {}, {}, {}

---Creates a tab strip that wraps to multiple justified rows when the tabs overflow the content width.
---@param gui KajiGUIInstance
---@param parent Frame the strip pins to the top of this frame; its height grows with the row count
---@param opts table { onSelect: fun(tabId), rightReserve?: number }
---@return table strip
local function CreateTabStrip(gui, parent, opts)
    local theme = gui.theme
    local onSelect = opts.onSelect
    -- Space kept clear on the right (the scroll region's scrollbar). Reserved unconditionally so
    -- the tabs don't jump when switching between tabs that scroll and tabs that don't.
    local rightReserve = opts.rightReserve or 0

    local frame = CreateFrame("Frame", nil, parent)
    pixel.SetPixelPoint(frame, "TOPLEFT", parent, "TOPLEFT", 0, 0)
    pixel.SetPixelHeight(frame, TAB_STRIP_TOP + TAB_INSET * 2 + TAB_ROW_HEIGHT)

    -- Authoritative width, never measured (AceGUI's `frame.width or frame:GetWidth()` pattern):
    -- a frame re-anchored this tick still reports its old rect, which is what let rows lay out
    -- against the pre-sidebar width and spill past the right edge. The strip is sized explicitly
    -- from the long-lived parent instead, so the value is correct the instant the inset changes.
    local leftInset, stripWidth = 0, 0
    local function ApplyWidth()
        stripWidth = mmax(0, (parent:GetWidth() or 0) - leftInset)
        pixel.SetPixelWidth(frame, stripWidth)
    end
    ApplyWidth()

    -- Pushes the strip right of a full-height mini sidebar; 0 restores the full width.
    local function SetLeftInset(inset)
        leftInset = inset
        frame:ClearAllPoints()
        pixel.SetPixelPoint(frame, "TOPLEFT", parent, "TOPLEFT", inset, 0)
        ApplyWidth()
    end

    -- Boundary line between the strip and the content below it.
    local baseline = frame:CreateTexture(nil, "BORDER")
    pixel.SetPixelHeight(baseline, theme.borderSize)
    pixel.SetPixelPoint(baseline, "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    pixel.SetPixelPoint(baseline, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    local strip = { frame = frame, selected = nil }
    local pool, active = {}, {}
    local currentRows = 0 -- forces the first layout to size the strip

    ---Re-anchors the strip beside a mini sidebar (or back to the full width) and reflows.
    ---@param inset number
    function strip:SetLeftInset(inset)
        if inset == leftInset then return end
        SetLeftInset(inset)
        self:Layout()
    end

    -- Label widths only change with the text or the font, so they are measured on those events
    -- rather than per resize tick: a cold-font measurement mid-drag would resize tabs under the cursor.
    local function MeasureTabs()
        for _, tab in ipairs(active) do
            tab.naturalWidth = tab.label:GetStringWidth() + TAB_HPAD * 2
        end
    end

    local function ApplyTabState(tab)
        if tab.disabled then
            tab.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.35)
            tab.selectedBg:Hide()
            tab.underline:Hide()
            tab:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], 1)
            tab:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
        elseif tab.value == strip.selected then
            tab.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            tab.selectedBg:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.08)
            tab.selectedBg:Show()
            tab.underline:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            tab.underline:Show()
            tab:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], 1)
            tab:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
        else
            tab.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
            tab.selectedBg:Hide()
            tab.underline:Hide()
            tab:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], 1)
            tab:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
        end
    end

    local function CreateTab()
        local tab = CreateFrame("Button", nil, frame, "BackdropTemplate")
        pixel.SetPixelHeight(tab, TAB_ROW_HEIGHT - TAB_GAP)
        tab:SetBackdrop(TAB_BACKDROP)
        tab:RegisterForClicks("LeftButtonUp")

        local selectedBg = tab:CreateTexture(nil, "BACKGROUND", nil, 1)
        selectedBg:SetAllPoints()
        selectedBg:Hide()
        tab.selectedBg = selectedBg

        local label = tab:CreateFontString(nil, "OVERLAY")
        pixel.SetPixelPoint(label, "CENTER", tab, "CENTER", 0, 0)
        label:SetJustifyH("CENTER")
        label:SetWordWrap(false)
        tab.label = label

        local underline = tab:CreateTexture(nil, "OVERLAY")
        pixel.SetPixelHeight(underline, TAB_UNDERLINE)
        pixel.SetPixelPoint(underline, "BOTTOMLEFT", tab, "BOTTOMLEFT", UNDERLINE_INSET, theme.borderSize)
        pixel.SetPixelPoint(underline, "BOTTOMRIGHT", tab, "BOTTOMRIGHT", -UNDERLINE_INSET, theme.borderSize)
        underline:Hide()
        tab.underline = underline

        tab:SetScript("OnEnter", function(self)
            if self.disabled or self.value == strip.selected then return end
            self.label:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
            self:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.6)
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
        -- Tabs are laid out inside the insets, so that is the width they get to fill.
        local width = stripWidth - TAB_INSET * 2 - rightReserve
        if width <= 0 or #active == 0 then return end

        wipe(widths); wipe(rowwidths); wipe(rowends)
        for i, tab in ipairs(active) do
            widths[i] = mmin(tab.naturalWidth, width)
        end

        -- Pass 1: pack tabs into rows, opening a new row when the next tab won't fit.
        -- Row widths include the gaps between the bordered buttons.
        local numrows, used = 1, 0
        for i = 1, #active do
            local packed = widths[i] + (used == 0 and 0 or TAB_GAP)
            if used ~= 0 and (width - used - packed) < 0 then
                rowwidths[numrows] = used
                rowends[numrows] = i - 1
                numrows = numrows + 1
                used = widths[i]
            else
                used = used + packed
            end
        end
        rowwidths[numrows] = used
        rowends[numrows] = #active

        -- Avoid a lone tab dangling on the last row: pull one down from the row above
        -- if that row has spare tabs and the last row has room (generalizes AceGUI's fix).
        if numrows > 1 and (rowends[numrows] - rowends[numrows - 1]) == 1 then
            local prevCount = rowends[numrows - 1] - (rowends[numrows - 2] or 0)
            local moved = widths[rowends[numrows - 1]] + TAB_GAP
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
            -- Every row is justified to the full width, however few tabs it holds.
            local extra = mmax(0, (width - rowwidths[row]) / count)
            -- A row that can't fit (one oversized tab, or a mid-layout width change) shrinks
            -- its tabs proportionally instead of spilling past the frame.
            local shrink = 1
            if rowwidths[row] > width then
                local gaps = (count - 1) * TAB_GAP
                shrink = mmax(0.1, (width - gaps) / (rowwidths[row] - gaps))
            end
            -- Every tab anchors to the strip at a running offset that accumulates *unrounded*
            -- widths (how KajiGUIRow lays a row out). Chaining each tab off the previous one's
            -- resolved rect instead makes pixel-grid rounding compound down the row and drag
            -- resizes visibly stutter.
            local y = -(TAB_STRIP_TOP + TAB_INSET + (row - 1) * TAB_ROW_HEIGHT)
            local x = TAB_INSET
            for i = starttab, endtab do
                local tab = active[i]
                local tabWidth = widths[i] * shrink + extra
                tab:ClearAllPoints()
                pixel.SetPixelPoint(tab, "TOPLEFT", frame, "TOPLEFT", x, y)
                pixel.SetPixelWidth(tab, tabWidth)
                x = x + tabWidth + TAB_GAP
            end
            starttab = endtab + 1
        end

        -- Height drives the scroll region anchored below, so only touch it on an actual row
        -- change: resizing the strip every tick reflows the whole page behind it.
        if numrows ~= currentRows then
            currentRows = numrows
            pixel.SetPixelHeight(frame, TAB_STRIP_TOP + TAB_INSET * 2 + numrows * TAB_ROW_HEIGHT)
        end
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
            active[i] = tab
        end
        MeasureTabs()
        self:Layout()
        -- Re-measure once the fonts have settled: a label measured before its font is realized
        -- reports a short string width (AceGUI does the same via a one-shot OnUpdate).
        C_Timer.After(0, function()
            MeasureTabs()
            strip:Layout()
        end)
        for _, tab in ipairs(active) do ApplyTabState(tab) end
    end

    ---Selects a tab and fires onSelect.
    ---@param value any
    function strip:Select(value)
        self.selected = value
        for _, tab in ipairs(active) do ApplyTabState(tab) end
        if onSelect then safecall(onSelect, value) end
    end

    -- Track the host, not the strip: the strip's own size changes are our doing.
    parent:HookScript("OnSizeChanged", function()
        ApplyWidth()
        strip:Layout()
    end)

    local function Restyle()
        baseline:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
        for _, tab in ipairs(active) do
            gui:ApplyFont(tab.label, "normal")
            ApplyTabState(tab)
        end
        MeasureTabs()
        strip:Layout()
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

    -- Anchored to the scroll region, not the host, so it starts below the tab strip in tabs mode.
    local scrollbarOptions = opts.scrollbarOptions or {
        width = 16,
        thumbHeight = 40,
        padding = { top = -1, bottom = -1, right = 0 },
        scrollStep = 40,
    }
    scrollbarOptions.anchorToScrollFrame = true
    local scrollbar = gui:CreateScrollbar(scrollFrame, scrollbarOptions)

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
    ---@field frame Frame
    ---@field scrollFrame ScrollFrame
    ---@field scrollChild Frame
    ---@field scrollbar any
    ---@field UpdateScrollbar fun(): void
    ---@field ShowPage fun(self: KajiGUIContentHost, id: string, target?: table): void
    ---@field FlashWidget fun(self: KajiGUIContentHost, widget: Frame): void
    ---@field ScrollToLabel fun(self: KajiGUIContentHost, label: string): void
    ---@field page? Frame
    ---@field currentId? string
    ---@field tabStrip? table
    ---@field miniSidebar? table
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
    local ApplyTabsForItem -- defined once the strip helpers exist

    local function ResetScroll()
        if scrollbar:IsShown() then scrollbar:SetValue(0) else scrollFrame:SetVerticalScroll(0) end
    end

    -- A page-level sidebar alongside tabs makes the sidebar the outer axis: the selected item
    -- decides which tabs exist. A per-tab sidebar is the reverse. Which one is outer decides how
    -- the selections are remembered, so the inner axis is keyed by the outer one.
    local function IsSidebarOuter(descriptor)
        return descriptor ~= nil and descriptor.sidebar ~= nil and (descriptor.mode or "clean") == "tabs"
    end

    local function ItemMemoryKey()
        if IsSidebarOuter(host._descriptor) then return host.currentId or "" end
        return (host.currentId or "") .. "/" .. (host._currentTab or "")
    end

    local function TabMemoryKey()
        if IsSidebarOuter(host._descriptor) then
            return (host.currentId or "") .. "/" .. (host._currentItem or "")
        end
        return host.currentId or ""
    end

    ---The tab list, which a sidebar-outer page may derive from the selected item.
    ---@return table[]
    local function ResolveTabs(descriptor, itemKey, item)
        local tabs = descriptor.tabs
        if type(tabs) == "function" then
            local resolved = select(2, safecall(tabs, itemKey, item))
            return resolved or {}
        end
        return tabs or {}
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

    -- The mini sidebar always spans the full host height; in tabs mode the strip is inset beside it.
    local function AnchorMiniSidebar()
        local msf = miniSidebar.frame
        msf:ClearAllPoints()
        pixel.SetPixelPoint(msf, "TOPLEFT", frame, "TOPLEFT", 0, 0)
        pixel.SetPixelPoint(msf, "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    end

    local function EnsureMiniSidebar()
        if miniSidebar then return miniSidebar end
        miniSidebar = gui:CreateMiniSidebar(frame, {
            onSelect = function(key, item)
                local descriptor = host._descriptor
                if not descriptor then return end
                host._itemMemory[ItemMemoryKey()] = key
                host._currentItem, host._currentItemData = key, item
                ClearScrollChild(scrollChild)
                host.page = nil
                -- Sidebar-outer: the new item may offer a different tab set, and re-selecting a
                -- tab rebuilds the page, so ApplyTabsForItem owns the build in that case.
                if IsSidebarOuter(descriptor) then
                    ApplyTabsForItem(descriptor, key, item)
                else
                    BuildPage(descriptor, host._currentTab, key, item)
                end
                ResetScroll()
            end,
        })
        host.miniSidebar = miniSidebar
        return miniSidebar
    end

    -- The per-tab sidebar (tabs) or the page-level one (clean / sidebar-outer).
    local function ResolveSidebar(descriptor, tabId)
        if descriptor.sidebar then return descriptor.sidebar end
        if tabId then
            for _, t in ipairs(descriptor.tabs or {}) do
                if t.id == tabId then return t.sidebar end
            end
        end
        return nil
    end

    -- Picks the item to select: a search-targeted one if present, else the remembered one, else the
    -- declared default, else the first.
    local function ResolveInitialItem(items, preferred, remembered, default)
        local first, rem, def
        for _, data in ipairs(items or {}) do
            if preferred ~= nil and data.key == preferred then return data.key, data end
            if data.key == remembered then rem = rem or data end
            if data.key == default then def = data end
            first = first or data
        end
        if rem then return rem.key, rem end
        if def then return def.key, def end
        if first then return first.key, first end
    end

    -- Shows the content for a page (clean: tabId nil) or one of its tabs, attaching the
    -- mini sidebar when the descriptor/tab declares one.
    local function ShowContent(descriptor, tabId)
        -- One-shot search target: consumed here (the terminal builder for clean / per-tab layouts)
        -- so later user-driven tab clicks that reach ShowContent don't reuse a stale selection.
        local target = host._pendingTarget
        host._pendingTarget = nil
        host._currentTab = tabId
        local sd = ResolveSidebar(descriptor, tabId)
        local stripFrame = tabId and tabStrip and tabStrip.frame or nil
        if sd then
            local ms = EnsureMiniSidebar()
            local items = ms:SetConfig(sd)
            ms.frame:Show()
            sidebarInset = sd.width or 192
            AnchorMiniSidebar()
            if stripFrame then
                -- Strip sits right of the sidebar, so the scroll region below it is already clear of both.
                tabStrip:SetLeftInset(sidebarInset)
                AnchorScrollBelow(stripFrame)
            else
                AnchorScrollBeside(ms.frame)
            end
            local key, item = ResolveInitialItem(items, target and target.itemKey, host._itemMemory[ItemMemoryKey()], sd.default)
            ms:SetSelected(key)
            host._currentItem, host._currentItemData = key, item
            BuildPage(descriptor, tabId, key, item)
        else
            if miniSidebar then miniSidebar.frame:Hide() end
            sidebarInset = 0
            host._currentItem, host._currentItemData = nil, nil
            if stripFrame then
                tabStrip:SetLeftInset(0)
                AnchorScrollBelow(stripFrame)
            else
                AnchorScrollTop()
            end
            BuildPage(descriptor, tabId)
        end
    end

    -- tabs: a wrapping sub-tab strip over per-tab content built with ShowContent.
    local function EnsureTabStrip()
        if tabStrip then return tabStrip end
        tabStrip = CreateTabStrip(gui, frame, {
            rightReserve = 0,
            onSelect = function(tabId)
                local descriptor = host._descriptor
                if not descriptor then return end
                host._currentTab = tabId
                host._tabMemory[TabMemoryKey()] = tabId
                ClearScrollChild(scrollChild)
                host.page = nil
                -- Sidebar-outer keeps the sidebar as it is; only the content below changes.
                if IsSidebarOuter(descriptor) then
                    BuildPage(descriptor, tabId, host._currentItem, host._currentItemData)
                else
                    ShowContent(descriptor, tabId)
                end
                ResetScroll()
            end,
        })
        host.tabStrip = tabStrip
        return tabStrip
    end

    -- Picks the tab to open: a search-targeted one if valid, else the remembered one for this page,
    -- else the first enabled tab.
    local function ResolveInitialTab(tabs, preferred, remembered)
        local first, rem
        for _, t in ipairs(tabs) do
            if not t.disabled then
                if preferred ~= nil and t.id == preferred then return t.id end
                if t.id == remembered then rem = rem or t.id end
                first = first or t.id
            end
        end
        return rem or first
    end

    -- Sidebar-outer: rebuild the strip for the selected item, keeping the current tab when the
    -- new item still offers it. Selecting a tab fires onSelect, which builds the page.
    function ApplyTabsForItem(descriptor, itemKey, item)
        -- Consume the one-shot search target's tab here: this is the last step of a sidebar-outer
        -- show, and a later user item click also routes through here (with no target).
        local target = host._pendingTarget
        host._pendingTarget = nil
        local strip = EnsureTabStrip()
        strip.frame:Show()
        local tabs = ResolveTabs(descriptor, itemKey, item)
        strip:SetLeftInset(sidebarInset)
        strip:SetTabs(tabs)
        AnchorScrollBelow(strip.frame)

        local initial = ResolveInitialTab(tabs, target and target.tabId, host._currentTab or host._tabMemory[TabMemoryKey()])
        if initial then
            strip:Select(initial)
        else
            host._currentTab = nil
            BuildPage(descriptor, nil, itemKey, item)
        end
    end

    local function ShowSidebarOuter(descriptor)
        local target = host._pendingTarget -- ApplyTabsForItem clears it; read the item here first.
        local sd = descriptor.sidebar
        local ms = EnsureMiniSidebar()
        local items = ms:SetConfig(sd)
        ms.frame:Show()
        sidebarInset = sd.width or 192
        AnchorMiniSidebar()

        local key, item = ResolveInitialItem(items, target and target.itemKey, host._itemMemory[ItemMemoryKey()], sd.default)
        ms:SetSelected(key)
        host._currentItem, host._currentItemData = key, item
        host._currentTab = host._tabMemory[TabMemoryKey()]
        ApplyTabsForItem(descriptor, key, item)
    end

    local function ShowTabs(descriptor)
        if IsSidebarOuter(descriptor) then
            ShowSidebarOuter(descriptor)
            return
        end

        local strip = EnsureTabStrip()
        strip.frame:Show()
        local tabs = descriptor.tabs or {}
        -- Peek the search target's tab (ShowContent, fired by strip:Select below, clears it).
        local target = host._pendingTarget
        local initial = ResolveInitialTab(tabs, target and target.tabId, host._tabMemory[TabMemoryKey()])
        -- Apply the initial tab's sidebar inset before SetTabs measures the strip,
        -- so the first layout already packs against the narrowed width.
        local sd = initial and ResolveSidebar(descriptor, initial) or nil
        strip:SetLeftInset(sd and (sd.width or 192) or 0)
        strip:SetTabs(tabs)
        if initial then strip:Select(initial) end
    end

    ---Builds and shows the page registered under id.
    ---@param id string
    ---@param target? table { tabId?, itemKey? } a search result's context, so the shown page opens
    --- on the tab / sidebar item that owns the matched widget. Consumed once by the initial show.
    function host:ShowPage(id, target)
        local descriptor = gui._pages and gui._pages[id]
        ClearScrollChild(scrollChild)
        host.page = nil
        host.currentId = id
        host._descriptor = descriptor
        host._pendingTarget = target

        local mode = descriptor and (descriptor.mode or "clean")
        if mode == "tabs" then
            ShowTabs(descriptor)
            return
        end

        if tabStrip then tabStrip.frame:Hide() end
        if descriptor then
            ShowContent(descriptor, nil)
        else
            host._pendingTarget = nil
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

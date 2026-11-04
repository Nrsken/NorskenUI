--[[
# ContentArea

* The window's content host: a scrollable region that renders a registered page by id.
* Pages are declared with `gui:RegisterPage(id, descriptor)` and shown with `host:ShowPage(id)`.
* A descriptor's `mode` selects the layout:
*     clean -> a single scrollable fluent page (build(page))
*     tabs  -> a sub-tab strip over per-tab pages (build(page, tabId))
* A `sidebar` field adds a full-height left item list (MiniSidebar) beside the scroll region, orthogonal to mode:
*     sidebar = { items: table|fun():table, width?, buttons?, renderItem?, onContextMenu?, default?, create? }
* `create(gui, parent, { onSelect })` swaps MiniSidebar for a column of the page's own, which answers the
* same calls: .frame, SetConfig(sd) -> selectable leaves, SetSelected, Select, SetItems, Render, BeginRename, SetExpanded.
* All layouts share the uniform contract build(page, tabId, itemKey, item) — trailing args are nil
* when no tab strip / sidebar is active, so plain pages just declare build(page).
*
* tabs descriptor: { mode='tabs', tabs = { {id, text, disabled?, sidebar?}, ... }, build = fun(page, tabId, ...) }
* The strip wraps to more rows when the tabs overflow the content width (see CreateTabStrip).
*
* Where the sidebar sits decides which axis drives the other:
*     tab-outer    -> `sidebar` on a tab entry: the selected tab decides the item list.
*     sidebar-outer-> `sidebar` page-level alongside mode='tabs': the item list is fixed and the
*                     selected item decides the tabs. Pass `tabs = fun(itemKey, item) -> tabs[]`
*                     to vary them per item; a static table works too. An item whose tabs resolve
*                     to an empty list gets no strip at all, so a page can mix plain items and
*                     tabbed ones.
*
* A descriptor may also declare page lifecycle hooks, for pages that drive something outside the
* window while they are open (a live preview, say):
*     onEnter(pageId) -- fired on every ShowPage of this page, including a re-show of the same page
*     onLeave(pageId) -- fired when a *different* page is shown
* Both must be idempotent. They are separate from `build` on purpose: the search harvester calls
* `build` as a dry run, and a dry run must not have side effects outside the page.
*
* The host itself takes one hook, for consumers that follow the open page across every page rather than
* declaring it page by page. Assign it after creating the host:
*     host.onPageChanged(pageId, previousPageId)
* It fires after the descriptor's own onEnter, and also for ids that registered no descriptor.
*
* A consumer can also pin a frame above every page, outside the scroll region, from that hook:
*     host:SetHeader(frame, height) -- nil removes it; the frame spans the whole host, a mini sidebar starts under it

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
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
---@param descriptor table { mode?: "clean"|"tabs", build: fun(page, tabId?, itemKey?, item?), tabs?, sidebar?, search?, onEnter?: fun(pageId), onLeave?: fun(pageId) }
function InstanceMixin:RegisterPage(id, descriptor)
    self._pages = self._pages or {}
    -- Re-registering replaces the build function, so any labels harvested from the
    -- old one are stale.
    if self._pages[id] then self:InvalidateSearchLabels(id) end
    self._pages[id] = descriptor
end

---Tears down the previous page. Every child here is a pooled card, so releasing them
---hands back their rows and widgets too and the frames get reused by the next page -
---orphaning them with SetParent(nil) leaked the whole subtree, permanently.
---@param gui KajiGUIInstance
---@param scrollChild Frame
local function ClearScrollChild(gui, scrollChild)
    for _, child in ipairs({ scrollChild:GetChildren() }) do
        gui:ReleaseWidget(child)
    end
    pixel.SetPixelHeight(scrollChild, 1)
end

local TAB_HPAD = 14 -- horizontal padding on each side of a tab label
local SLASH = 8 -- the 45° separator between neighbouring tabs, as tall as it is wide
local HOVER_LIGHTEN = 0.6 -- how far a hovered label goes toward textPrimary, as in the sidebar
local DISABLED_ALPHA = 0.35

-- Scratch tables reused across a single Layout pass.
local widths, rowwidths, rowends = {}, {}, {}

---Creates a tab strip that wraps to multiple rows when the tabs overflow the content width.
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
    local MARGIN = theme.paddingSmall -- around the panel, as around the module header and the cards
    local EDGE = theme.borderSize
    local ROW_HEIGHT = theme.barControlHeight

    local frame = CreateFrame("Frame", nil, parent)
    pixel.SetPixelPoint(frame, "TOPLEFT", parent, "TOPLEFT", 0, 0)
    pixel.SetPixelHeight(frame, MARGIN + EDGE * 2 + ROW_HEIGHT)

    -- one panel for the whole strip, like the module header's; the tabs are text on it
    local panel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    pixel.SetPixelPoint(panel, "TOPLEFT", frame, "TOPLEFT", MARGIN, -MARGIN)
    pixel.SetPixelPoint(panel, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -MARGIN - rightReserve, 0)
    lib.SetBackdrop(panel, gui, { bg = "bgMedium", border = "border", edgeSize = "borderSize" })
    local cornerTicks = lib.CreateCornerTicks(panel, panel, theme)

    -- Authoritative width, never measured (AceGUI's `frame.width or frame:GetWidth()` pattern):
    -- a frame re-anchored this tick still reports its old rect, which is what let rows lay out
    -- against the pre-sidebar width and spill past the right edge. The strip is sized explicitly
    -- from the long-lived parent instead, so the value is correct the instant the inset changes.
    local leftInset, topInset, stripWidth = 0, 0, 0
    local function ApplyWidth()
        stripWidth = mmax(0, (parent:GetWidth() or 0) - leftInset)
        pixel.SetPixelWidth(frame, stripWidth)
    end
    ApplyWidth()

    -- Pushes the strip right of a full-height mini sidebar and below the host's header; 0 restores either.
    local function SetLeftInset(inset)
        leftInset = inset
        frame:ClearAllPoints()
        pixel.SetPixelPoint(frame, "TOPLEFT", parent, "TOPLEFT", inset, -topInset)
        ApplyWidth()
    end

    local strip = { frame = frame, selected = nil }
    local pool, active = {}, {}
    local slashes = {}
    local currentRows = 0 -- forces the first layout to size the strip

    ---Re-anchors the strip beside a mini sidebar (or back to the full width) and reflows.
    ---@param inset number
    function strip:SetLeftInset(inset)
        if inset == leftInset then return end
        SetLeftInset(inset)
        self:Layout()
    end

    ---Moves the strip down to sit below the host's header.
    ---@param top number
    function strip:SetTopInset(top)
        if top == topInset then return end
        topInset = top
        SetLeftInset(leftInset)
    end

    -- Label widths only change with the text or the font, so they are measured on those events
    -- rather than per resize tick: a cold-font measurement mid-drag would resize tabs under the cursor.
    local function MeasureTabs()
        for _, tab in ipairs(active) do
            tab.naturalWidth = tab.label:GetStringWidth() + TAB_HPAD * 2
        end
    end

    ---A tab's label: textSecondary at rest, lightening while hovered, the accent as it's selected.
    local function PaintLabel(tab)
        local l, h = lib.RowSelectionProgress(tab)
        local rest, hi, ac = theme.textSecondary, theme.textPrimary, theme.accent
        local r = rest[1] + (hi[1] - rest[1]) * h * HOVER_LIGHTEN
        local g = rest[2] + (hi[2] - rest[2]) * h * HOVER_LIGHTEN
        local b = rest[3] + (hi[3] - rest[3]) * h * HOVER_LIGHTEN
        tab.label:SetTextColor(r + (ac[1] - r) * l, g + (ac[2] - g) * l, b + (ac[3] - b) * l, tab.disabled and DISABLED_ALPHA or 1)
    end

    ---@param instant? boolean snap instead of crossfading, for a tab just set up or restyled
    local function ApplyTabState(tab, instant)
        local selected = not tab.disabled and tab.value == strip.selected
        lib.SetRowSelection(tab, theme, selected and 1 or 0, tab.hovered and not selected and 1 or 0, instant)
        if instant then
            PaintLabel(tab)
        end
    end

    local function CreateTab()
        local tab = CreateFrame("Button", nil, panel)
        pixel.SetPixelHeight(tab, ROW_HEIGHT)
        tab:RegisterForClicks("LeftButtonUp")
        -- the line style, as the header's role tabs, but on a panel of its own so the two rows don't read alike
        lib.CreateRowSelection(tab, theme, "bottom", true)

        local label = tab:CreateFontString(nil, "OVERLAY")
        gui:ApplyFont(label, "normal")
        pixel.SetPixelPoint(label, "CENTER", tab, "CENTER", 0, 0)
        label:SetJustifyH("CENTER")
        label:SetWordWrap(false)
        tab.label = label

        tab:SetScript("OnUpdate", function(self, elapsed)
            if lib.StepRowSelection(self, theme, elapsed) then
                PaintLabel(self)
            end
        end)
        tab:SetScript("OnEnter", function(self)
            self.hovered = true
            ApplyTabState(self)
        end)
        tab:SetScript("OnLeave", function(self)
            self.hovered = nil
            ApplyTabState(self)
        end)
        tab:SetScript("OnClick", function(self)
            if self.disabled or self.value == strip.selected then return end
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            strip:Select(self.value, true)
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
            t.inUse = false; t.disabled = nil; t.value = nil; t.hovered = nil
            lib.SetRowSelection(t, theme, 0, 0, true)
            t:Hide(); t:ClearAllPoints()
        end
        wipe(active)
    end

    -- the 45° recipe of the module header's dive: one physical pixel thick, endpoints on the grid
    local function PlaceSlash(index, x, rowTop)
        local slash = slashes[index]
        if not slash then
            slash = panel:CreateLine(nil, "ARTWORK")
            slashes[index] = slash
        end
        local c = theme.widgetBorder
        local px = pixel.ToPixelGrid(1)
        local size = pixel.ToPixelGrid(SLASH)
        local left = pixel.ToPixelGrid(x - size / 2)
        local top = pixel.ToPixelGrid(rowTop + (ROW_HEIGHT - size) / 2)
        slash:SetColorTexture(c[1], c[2], c[3], 1)
        slash:SetThickness(px)
        slash:SetStartPoint("TOPLEFT", panel, left, px / 2 - top - size)
        slash:SetEndPoint("TOPLEFT", panel, left + size, px / 2 - top)
        slash:Show()
    end

    -- Greedy line-wrap into justified rows. Runs on tab change and on width change.
    function strip:Layout()
        local width = stripWidth - MARGIN * 2 - rightReserve - EDGE * 2
        if width <= 0 or #active == 0 then return end

        wipe(widths); wipe(rowwidths); wipe(rowends)
        for i, tab in ipairs(active) do
            widths[i] = mmin(tab.naturalWidth, width)
        end

        -- Pass 1: pack tabs into rows, opening a new row when the next tab won't fit.
        local numrows, used = 1, 0
        for i = 1, #active do
            if used ~= 0 and used + widths[i] > width then
                rowwidths[numrows] = used
                rowends[numrows] = i - 1
                numrows = numrows + 1
                used = widths[i]
            else
                used = used + widths[i]
            end
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

        -- Pass 2: stack rows top-down and stretch each row's tabs to fill the width, a slash between neighbours.
        -- Every tab anchors to the panel at a running offset that accumulates *unrounded*
        -- widths (how KajiGUIRow lays a row out). Chaining each tab off the previous one's
        -- resolved rect instead makes pixel-grid rounding compound down the row and drag
        -- resizes visibly stutter.
        local starttab, slashCount = 1, 0
        for row, endtab in ipairs(rowends) do
            -- every row is justified to the full width, however few tabs it holds
            local extra = mmax(0, (width - rowwidths[row]) / (endtab - starttab + 1))
            -- a row that can't fit (one oversized tab or a mid-layout width change) shrinks its tabs instead of spilling
            local shrink = rowwidths[row] > width and mmax(0.1, width / rowwidths[row]) or 1
            local y = EDGE + (row - 1) * ROW_HEIGHT
            local x = EDGE
            for i = starttab, endtab do
                if i > starttab then
                    slashCount = slashCount + 1
                    PlaceSlash(slashCount, x, y)
                end
                local tab = active[i]
                local tabWidth = widths[i] * shrink + extra
                tab:ClearAllPoints()
                pixel.SetPixelPoint(tab, "TOPLEFT", panel, "TOPLEFT", x, -y)
                pixel.SetPixelWidth(tab, tabWidth)
                x = x + tabWidth
            end
            starttab = endtab + 1
        end
        for i = slashCount + 1, #slashes do
            slashes[i]:Hide()
        end

        -- Height drives the scroll region anchored below, so only touch it on an actual row
        -- change: resizing the strip every tick reflows the whole page behind it.
        if numrows ~= currentRows then
            currentRows = numrows
            pixel.SetPixelHeight(frame, MARGIN + EDGE * 2 + numrows * ROW_HEIGHT)
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
        for _, tab in ipairs(active) do
            ApplyTabState(tab, true)
        end
    end

    ---Selects a tab and fires onSelect.
    ---@param value any
    ---@param animate? boolean crossfade, for a click; a page opening on its remembered tab snaps
    function strip:Select(value, animate)
        self.selected = value
        for _, tab in ipairs(active) do
            ApplyTabState(tab, not animate)
        end
        if onSelect then
            safecall(onSelect, value)
        end
    end

    -- Track the host, not the strip: the strip's own size changes are our doing.
    parent:HookScript("OnSizeChanged", function()
        ApplyWidth()
        strip:Layout()
    end)

    local function Restyle()
        lib.RefreshBackdrop(panel)
        lib.PaintCornerTicks(cornerTicks, theme)
        for _, tab in ipairs(active) do
            gui:ApplyFont(tab.label, "normal")
            ApplyTabState(tab, true)
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
        -- Also covers the item list column, which sits inside this frame on a translucent fill.
        lib.AddSurfaceTexture(frame, gui)
        lib.AddSurfaceTexture(frame, gui, "page")
        local function Restyle()
            frame:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], theme.bgDark[4])
        end
        Restyle()
        gui:OnThemeChanged(Restyle)
    end

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetClipsChildren(true)

    local tabStrip, miniSidebar
    local sidebarInset = 0
    local header, headerHeight = nil, 0

    -- The header spans the whole host, above the mini sidebar, the strip and the scroll region alike.
    local function AnchorHeader()
        if tabStrip then
            tabStrip:SetTopInset(headerHeight)
        end
        if not header then return end
        header:ClearAllPoints()
        pixel.SetPixelPoint(header, "TOPLEFT", frame, "TOPLEFT", 0, 0)
        pixel.SetPixelPoint(header, "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        pixel.SetPixelHeight(header, headerHeight)
    end

    -- Scroll region fills the host (clean mode), starts below the tab strip (tabs mode)
    -- and to the right of the mini sidebar when one is active.
    local function AnchorScrollTop()
        AnchorHeader()
        scrollFrame:ClearAllPoints()
        pixel.SetPixelPoint(scrollFrame, "TOPLEFT", frame, "TOPLEFT", 0, -headerHeight)
        pixel.SetPixelPoint(scrollFrame, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    end
    local function AnchorScrollBelow(stripFrame)
        AnchorHeader()
        scrollFrame:ClearAllPoints()
        pixel.SetPixelPoint(scrollFrame, "TOPLEFT", stripFrame, "BOTTOMLEFT", 0, 0)
        pixel.SetPixelPoint(scrollFrame, "TOPRIGHT", stripFrame, "BOTTOMRIGHT", 0, 0)
        pixel.SetPixelPoint(scrollFrame, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    end
    local function AnchorScrollBeside(sidebarFrame)
        AnchorHeader()
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
        width = scrollbarWidth,
        thumbHeight = 40,
        padding = { top = -1, bottom = -1, right = 0 },
        scrollStep = 40,
    }
    scrollbarOptions.anchorToScrollFrame = true
    local scrollbar = gui:CreateScrollbar(scrollFrame, scrollbarOptions)

    local scrollbarVisible = false
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
    ---@field SetHeader fun(self: KajiGUIContentHost, headerFrame?: Frame, height?: number): void
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

    -- The mini sidebar runs from under the header to the host's foot; in tabs mode the strip is inset beside it.
    local function AnchorMiniSidebar()
        local msf = miniSidebar.frame
        msf:ClearAllPoints()
        pixel.SetPixelPoint(msf, "TOPLEFT", frame, "TOPLEFT", 0, -headerHeight)
        pixel.SetPixelPoint(msf, "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    end

    local function OnColumnSelect(key, item)
        local descriptor = host._descriptor
        if not descriptor then return end
        host._itemMemory[ItemMemoryKey()] = key
        host._currentItem, host._currentItemData = key, item
        ClearScrollChild(gui, scrollChild)
        host.page = nil
        -- Sidebar-outer: the new item may offer a different tab set, and re-selecting a
        -- tab rebuilds the page, so ApplyTabsForItem owns the build in that case.
        if IsSidebarOuter(descriptor) then
            ApplyTabsForItem(descriptor, key, item)
        else
            BuildPage(descriptor, host._currentTab, key, item)
        end
        ResetScroll()
    end

    local columns = {} -- [sd.create or "default"] = column, each built once

    ---The left column a sidebar descriptor asks for, made the active one.
    ---@param sd table
    local function EnsureMiniSidebar(sd)
        local slot = sd.create or "default"
        local column = columns[slot]
        if not column then
            local opts = { onSelect = OnColumnSelect }
            column = sd.create and sd.create(gui, frame, opts) or gui:CreateMiniSidebar(frame, opts)
            columns[slot] = column
        end

        if miniSidebar and miniSidebar ~= column then miniSidebar.frame:Hide() end
        miniSidebar = column
        host.miniSidebar = column
        return column
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
            local ms = EnsureMiniSidebar(sd)
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
            -- a targeted item (a new or duplicated row, a search hit) is the one to come back to
            host._itemMemory[ItemMemoryKey()] = key
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
                ClearScrollChild(gui, scrollChild)
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
        local tabs = ResolveTabs(descriptor, itemKey, item)

        -- An item can opt out of sub-tabs entirely by resolving to an empty list; the content then
        -- fills the space beside the sidebar. Handled before the strip is shown, so a tabless item
        -- doesn't leave an empty strip (and its baseline) hanging above the page.
        if #tabs == 0 then
            if tabStrip then tabStrip.frame:Hide() end
            host._currentTab = nil
            AnchorScrollBeside(miniSidebar.frame)
            BuildPage(descriptor, nil, itemKey, item)
            return
        end

        local strip = EnsureTabStrip()
        strip.frame:Show()
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
        local ms = EnsureMiniSidebar(sd)
        local items = ms:SetConfig(sd)
        ms.frame:Show()
        sidebarInset = sd.width or 192
        AnchorMiniSidebar()

        local key, item = ResolveInitialItem(items, target and target.itemKey, host._itemMemory[ItemMemoryKey()], sd.default)
        ms:SetSelected(key)
        -- a targeted item (a new or duplicated row, a search hit) is the one to come back to
        host._itemMemory[ItemMemoryKey()] = key
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

        -- Lifecycle hooks for pages that drive something outside the window while they are open.
        -- onLeave only fires on an actual page change; onEnter re-fires on a re-show of the same
        -- page, so both are documented as idempotent.
        local previous = host._descriptor
        local previousId = host.currentId
        if previous and previous ~= descriptor and previous.onLeave then
            safecall(previous.onLeave, host.currentId)
        end

        ClearScrollChild(gui, scrollChild)
        host.page = nil
        host.currentId = id
        host._descriptor = descriptor
        host._pendingTarget = target

        if descriptor and descriptor.onEnter then safecall(descriptor.onEnter, id) end

        -- One hook for consumers that track the open page for every page rather than page by page.
        -- Fires after the descriptor's own onEnter and for pages that registered no descriptor at all.
        if host.onPageChanged then safecall(host.onPageChanged, id, previousId) end

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

    ---Puts a frame across the top of the host, above a mini sidebar, the tab strip and the scroll region, on
    ---every page until replaced; nil takes it away. Call it from onPageChanged, the page lays out right after.
    ---@param headerFrame? Frame parented to host.frame
    ---@param height? number
    function host:SetHeader(headerFrame, height)
        if header and header ~= headerFrame then
            header:Hide()
        end
        header = headerFrame
        headerHeight = headerFrame and height or 0
        if header then
            header:Show()
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

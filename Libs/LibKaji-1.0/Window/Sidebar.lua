--[[
# Sidebar

* The library-owned navigation panel: a scrollable list of section headers with child items.
* Driven by a config list (data); fires opts.onSelect(id, searchResult?) when an entry is chosen.
* Entry kinds:
*     { type='header', id, text, defaultExpanded?, items = { {id,text}, ... } }  -> expandable section
*     { type='item',   id, text }                                               -> header-styled leaf (opens page `id`)
* Self-restyles on theme change. Search results are rendered via ShowResults(results); ClearResults() returns to the tree.
* A section's children live in a clipping container whose height animates on toggle, so the rows below slide with it.

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local safecall = lib.safecall
local pixel = lib.Pixel
local L = lib.L

local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs
local wipe = wipe
local mpi, mmin, mmax, mfloor = math.pi, math.min, math.max, math.floor
local format = string.format

-- Shared with MiniSidebar, so a page list reads as a small copy of this one.
local HEADER_HEIGHT = 28
local ITEM_HEIGHT = 26
local CHEVRON_SIZE = 10
local TEXT_INSET = 8 -- headers' text and the chevron from the panel's border; the rows run flush to it
local ROW_STEP = 8 -- a section's rows step in to its header's text, so their bar sits under it
local ROW_TEXT = 12 -- a row's text from its bar
local EXPAND_DURATION = 0.2
local COLLAPSE_DURATION = 0.15
local HEADER_GAP = 2 -- between stacked headers
local ROWS_GAP = 8 -- under a section's open rows, folding with them
local ITEM_SPACING = 1
local HOVER_LIGHTEN = 0.6 -- how far a hovered label goes toward textPrimary

---Creates the sidebar panel.
---@param parent Frame
---@param opts table { config: table[], onSelect: fun(id, searchResult?), isDisabled?: fun(entry): boolean, top?: number room at the panel's top for what the host puts there (sidebar.panel), onScrollbar?: fun(shown: boolean) }
---@return table sidebar
function InstanceMixin:CreateSidebar(parent, opts)
    opts = opts or {}
    local gui = self
    local theme = self.theme
    local onSelect = opts.onSelect
    local isDisabled = opts.isDisabled or function(e) return e.disabled end
    local pad = theme.paddingSmall

    -- the column is page ground like the content area's, the list a panel on it as a page's list is
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    lib.AddSurfaceTexture(frame, gui)
    lib.AddSurfaceTexture(frame, gui, "page")

    -- inset as a page's list is: flush right, where the next column's own inset is the gap
    local panel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    pixel.SetPixelPoint(panel, "TOPLEFT", frame, "TOPLEFT", pad, -pad)
    pixel.SetPixelPoint(panel, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, pad)
    local RestylePanel = lib.CreatePanelChrome(panel, gui)

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel)
    scrollFrame:SetFrameLevel(panel:GetFrameLevel() + 5)
    -- inside the panel's border, which the list would otherwise scroll over, under what the host tops it with
    pixel.SetPixelPoint(scrollFrame, "TOPLEFT", panel, "TOPLEFT", theme.borderSize, -(theme.borderSize + (opts.top or 0)))
    pixel.SetPixelPoint(scrollFrame, "BOTTOMRIGHT", panel, "BOTTOMRIGHT", -theme.borderSize, theme.borderSize)
    scrollFrame:SetClipsChildren(true)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    pixel.SetPixelHeight(scrollChild, 1)
    scrollChild:SetFrameLevel(scrollFrame:GetFrameLevel() + 1)
    scrollFrame:SetScrollChild(scrollChild)

    local scrollbar = gui:CreateScrollbar(scrollFrame, {
        width = theme.scrollbarWidth,
        thumbHeight = 40,
        padding = { top = -1, bottom = -1, right = 0 },
        scrollStep = 40,
    })

    local scrollbarVisible = false
    local function UpdateScrollChildWidth()
        local w = scrollFrame:GetWidth()
        if not w or w <= 0 then return end
        pixel.SetPixelWidth(scrollChild, scrollbarVisible and (w - (theme.scrollbarWidth or 16)) or w)
    end
    local function UpdateScrollbar()
        local visible = scrollbar:UpdateVisibility(scrollChild:GetHeight(), scrollFrame:GetHeight())
        -- the track runs the panel's full height, so whatever the host put at the top steps aside with the rows
        if visible ~= scrollbarVisible and opts.onScrollbar then
            safecall(opts.onScrollbar, visible)
        end
        scrollbarVisible = visible
        UpdateScrollChildWidth()
    end
    scrollChild:HookScript("OnSizeChanged", UpdateScrollbar)
    scrollFrame:HookScript("OnSizeChanged", UpdateScrollbar)
    scrollFrame:HookScript("OnShow", function() UpdateScrollbar() end)
    frame:HookScript("OnSizeChanged", UpdateScrollChildWidth)

    local sidebar = {
        frame = frame,
        panel = panel,
        scrollFrame = scrollFrame,
        scrollChild = scrollChild,
        scrollbar = scrollbar,
        config = opts.config,
        expanded = {},
        anims = {}, -- [sectionId] = { p, from, to, t, duration }
        selected = nil,
        results = nil,
    }

    local headerPool, itemPool = {}, {}
    local activeHeaders, activeItems = {}, {}
    local ApplyItemState, ApplyHeaderSelection -- defined under Visual state, the row scripts call them

    ---A selectable row's label: its rest colour lightening while hovered, the accent as it's selected.
    local function PaintLabel(row, rest)
        local l, h = lib.RowSelectionProgress(row)
        local hi, ac = theme.textPrimary, theme.accent
        local r = rest[1] + (hi[1] - rest[1]) * h * HOVER_LIGHTEN
        local g = rest[2] + (hi[2] - rest[2]) * h * HOVER_LIGHTEN
        local b = rest[3] + (hi[3] - rest[3]) * h * HOVER_LIGHTEN
        row.label:SetTextColor(r + (ac[1] - r) * l, g + (ac[2] - g) * l, b + (ac[3] - b) * l, 1)
    end

    -- Header --
    local function CreateHeader()
        local header = CreateFrame("Button", nil, scrollChild)
        pixel.SetPixelHeight(header, HEADER_HEIGHT)
        header:EnableMouse(true)
        header:RegisterForClicks("LeftButtonUp")

        -- hover previews the selection dimmed, as on the rows, for a section header too
        lib.CreateRowSelection(header, theme)

        local label = header:CreateFontString(nil, "OVERLAY")
        pixel.SetPixelPoint(label, "LEFT", header, "LEFT", TEXT_INSET, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        header.label = label

        local arrow = header:CreateTexture(nil, "OVERLAY")
        pixel.SetPixelSize(arrow, CHEVRON_SIZE, CHEVRON_SIZE)
        pixel.SetPixelPoint(arrow, "RIGHT", header, "RIGHT", -TEXT_INSET, 0)
        arrow:SetTexture(theme.stepperTexture)
        pixel.SetPixelSnap(arrow)
        header.arrow = arrow

        -- Collapsed points right, expanded points down.
        local animGroup = arrow:CreateAnimationGroup()
        local rotation = animGroup:CreateAnimation("Rotation")
        rotation:SetOrigin("CENTER", 0, 0)
        animGroup:SetScript("OnFinished", function()
            arrow:SetRotation(header.isExpanded and 0 or mpi / 2)
        end)
        header.SetArrowState = function(self, expanded)
            if self.isExpanded == expanded and animGroup:IsPlaying() then return end
            animGroup:Stop()
            self.isExpanded = expanded
            arrow:SetRotation(expanded and 0 or mpi / 2)
        end
        header.AnimateArrow = function(self, expanded)
            if self.isExpanded == expanded then return end
            animGroup:Stop()
            rotation:SetDuration(expanded and EXPAND_DURATION or COLLAPSE_DURATION)
            rotation:SetSmoothing(expanded and "OUT" or "IN")
            rotation:SetRadians(expanded and -mpi / 2 or mpi / 2)
            self.isExpanded = expanded
            animGroup:Play()
        end

        header:SetScript("OnUpdate", function(_, elapsed)
            if lib.StepRowSelection(header, theme, elapsed) and not header.disabled then
                PaintLabel(header, theme.accent)
            end
        end)
        header:SetScript("OnEnter", function()
            if header.disabled then return end
            header.hovered = true
            ApplyHeaderSelection(header)
            if not header.leafId then
                header.arrow:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
            end
        end)
        header:SetScript("OnLeave", function()
            header.hovered = nil
            if header.disabled then return end
            ApplyHeaderSelection(header)
            if not header.leafId then
                header.arrow:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.7)
            end
        end)
        header:SetScript("OnClick", function()
            if header.disabled then return end
            if header.leafId then
                sidebar:Select(header.leafId)
            else
                sidebar:ToggleSection(header.sectionId)
            end
        end)

        return header
    end

    local function AcquireHeader()
        for _, h in ipairs(headerPool) do
            if not h.inUse then
                h.inUse = true; h:Show(); return h
            end
        end
        local h = CreateHeader()
        h.inUse = true
        headerPool[#headerPool + 1] = h
        return h
    end

    -- Item --
    local function CreateItem()
        local item = CreateFrame("Button", nil, scrollChild)
        pixel.SetPixelHeight(item, ITEM_HEIGHT)
        item:EnableMouse(true)
        item:RegisterForClicks("LeftButtonUp")

        -- hover previews the selection dimmed, so there's no separate hover wash
        lib.CreateRowSelection(item, theme)

        local label = item:CreateFontString(nil, "OVERLAY")
        pixel.SetPixelPoint(label, "LEFT", item, "LEFT", ROW_TEXT, 0)
        pixel.SetPixelPoint(label, "RIGHT", item, "RIGHT", -pad, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        item.label = label

        item:SetScript("OnUpdate", function(self, elapsed)
            if lib.StepRowSelection(self, theme, elapsed) and not self.disabled then
                PaintLabel(self, theme.textSecondary)
            end
        end)
        item:SetScript("OnEnter", function(self)
            if self.disabled then return end
            self.hovered = true
            ApplyItemState(self)
        end)
        item:SetScript("OnLeave", function(self)
            self.hovered = nil
            if not self.disabled then
                ApplyItemState(self)
            end
        end)
        item:SetScript("OnClick", function(self)
            if not self.disabled then sidebar:Select(self.id, self.searchResult) end
        end)

        return item
    end

    local function AcquireItem()
        for _, it in ipairs(itemPool) do
            if not it.inUse then
                it.inUse = true; it:Show(); return it
            end
        end
        local it = CreateItem()
        it.inUse = true
        itemPool[#itemPool + 1] = it
        return it
    end

    local containerPool = {}
    local layout = {} -- ordered blocks: { frame, height } | { frame, section, full } | { gap }

    local function AcquireContainer()
        for _, c in ipairs(containerPool) do
            if not c.inUse then
                c.inUse = true; c:Show(); return c
            end
        end
        local c = CreateFrame("Frame", nil, scrollChild)
        c:SetClipsChildren(true)
        c:SetFrameLevel(scrollChild:GetFrameLevel() + 1)

        c.inUse = true
        containerPool[#containerPool + 1] = c
        return c
    end

    -- Rows are only marked free here and hidden by SweepUnused once the render has claimed what it needs.
    -- A row that stays on screen is never hidden and re-shown, which would reset its hover and blink it.
    local function ReleaseAll()
        for _, c in ipairs(containerPool) do c.inUse = false end
        wipe(layout)
        for _, h in ipairs(headerPool) do
            h.inUse = false; h.disabled = nil; h.leafId = nil; h.sectionId = nil
        end
        for _, it in ipairs(itemPool) do
            it.inUse = false; it.disabled = nil; it.id = nil; it.searchResult = nil
        end
        wipe(activeHeaders); wipe(activeItems)
    end

    local function SweepUnused()
        for _, c in ipairs(containerPool) do
            if not c.inUse and c:IsShown() then c:Hide(); c:ClearAllPoints() end
        end
        for _, h in ipairs(headerPool) do
            if not h.inUse and h:IsShown() then
                lib.SetRowSelection(h, theme, 0, 0, true)
                h:Hide(); h:ClearAllPoints()
            end
        end
        for _, it in ipairs(itemPool) do
            if not it.inUse and it:IsShown() then
                lib.SetRowSelection(it, theme, 0, 0, true)
                it:Hide(); it:ClearAllPoints()
            end
        end
    end

    -- Visual state --

    ---@param instant? boolean snap, for a row just configured; selection and hover changes crossfade
    function ApplyItemState(item, instant)
        if item.disabled then
            lib.SetRowSelection(item, theme, 0, 0, true)
            item.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.35)
            return
        end
        local selected = item.id == sidebar.selected
        lib.SetRowSelection(item, theme, selected and 1 or 0, item.hovered and not selected and 1 or 0, instant)
        if instant then
            PaintLabel(item, theme.textSecondary)
        end
    end

    ---A leaf header selects like a row; a section header only ever shows the hover preview.
    ---@param instant? boolean
    function ApplyHeaderSelection(header, instant)
        if header.disabled then
            lib.SetRowSelection(header, theme, 0, 0, true)
            return
        end
        local selected = header.leafId ~= nil and header.leafId == sidebar.selected
        lib.SetRowSelection(header, theme, selected and 1 or 0, header.hovered and not selected and 1 or 0, instant)
        if instant then
            PaintLabel(header, theme.accent)
        end
    end

    ---@param parent? Frame a section container; the scroll child otherwise
    local function ConfigureItem(item, id, text, yOffset, searchResult, parent)
        local host = parent or scrollChild
        item:SetParent(host)
        item:SetFrameLevel(host:GetFrameLevel() + 2)
        pixel.SetPixelHeight(item, ITEM_HEIGHT)
        item:ClearAllPoints()
        -- search results step in too, so every row's text shares one edge
        pixel.SetPixelPoint(item, "TOPLEFT", host, "TOPLEFT", ROW_STEP, -yOffset)
        pixel.SetPixelPoint(item, "TOPRIGHT", host, "TOPRIGHT", 0, -yOffset)
        item.id = id
        item.searchResult = searchResult
        item.label:Show()
        gui:ApplyFont(item.label, "normal")
        item.label:SetText(text or "")
        activeItems[#activeItems + 1] = item
    end

    local function ConfigureHeader(header, entry, isLeaf)
        header:SetParent(scrollChild)
        header:SetFrameLevel(scrollChild:GetFrameLevel() + 2)
        pixel.SetPixelHeight(header, HEADER_HEIGHT)
        header.label:Show()
        gui:ApplyFont(header.label, "medium")
        header.label:SetText(entry.text or "")

        local disabled = isDisabled(entry) or false
        header.disabled = disabled

        if disabled then
            header.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.35)
            header.arrow:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.35)
        else
            header.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            header.arrow:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.7)
        end

        if isLeaf then
            header.leafId = entry.id
            header.sectionId = nil
            header.arrow:Hide()
        else
            header.leafId = nil
            header.sectionId = entry.id
            header.arrow:Show()
            header:SetArrowState(sidebar.expanded[entry.id] == true)
        end
        ApplyHeaderSelection(header, true)
        activeHeaders[#activeHeaders + 1] = header
    end

    -- Rendering --
    ---@param sectionId string
    ---@return number progress 0 collapsed .. 1 expanded
    local function SectionProgress(sectionId)
        local anim = sidebar.anims[sectionId]
        if anim then return anim.p end
        return sidebar.expanded[sectionId] and 1 or 0
    end

    ---@param block Frame
    ---@param y number
    local function Place(block, y)
        block:ClearAllPoints()
        pixel.SetPixelPoint(block, "TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
        pixel.SetPixelPoint(block, "TOPRIGHT", scrollChild, "TOPRIGHT", 0, -y)
    end

    -- Positions the rendered blocks top to bottom. Cheap, so an animating section can call it every frame.
    local function Relayout()
        local y = pad
        for _, block in ipairs(layout) do
            if block.gap then
                y = y + block.gap
            elseif block.section then
                local height = mfloor(block.full * SectionProgress(block.section) + 0.5)
                Place(block.frame, y)
                pixel.SetPixelHeight(block.frame, mmax(height, 1))
                block.frame:SetShown(height > 0)
                y = y + height
            else
                Place(block.frame, y)
                y = y + block.height
            end
        end
        pixel.SetPixelHeight(scrollChild, y + pad)

        -- A shorter list must not leave the view scrolled past its new end, which hides the top rows.
        scrollFrame:UpdateScrollChildRect()
        local maxScroll = mmax(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
        if scrollFrame:GetVerticalScroll() > maxScroll then
            scrollbar:SetValue(maxScroll)
            scrollFrame:SetVerticalScroll(maxScroll)
        end
    end

    local function RenderTree()
        if not sidebar.config then
            pixel.SetPixelHeight(scrollChild, 1); return
        end
        for _, entry in ipairs(sidebar.config) do
            local header = AcquireHeader()
            local isLeaf = entry.type == "item"
            ConfigureHeader(header, entry, isLeaf)
            layout[#layout + 1] = { frame = header, height = HEADER_HEIGHT }

            -- A collapsing section keeps its children until the animation has closed over them.
            if not isLeaf and entry.items and (sidebar.expanded[entry.id] or sidebar.anims[entry.id]) then
                local container = AcquireContainer()
                local sectionDisabled = isDisabled(entry)
                local y = 0
                for _, child in ipairs(entry.items) do
                    local item = AcquireItem()
                    ConfigureItem(item, child.id, child.text, y, nil, container)
                    item.disabled = sectionDisabled or isDisabled(child) or false
                    item:EnableMouse(not item.disabled)
                    ApplyItemState(item, true)
                    y = y + ITEM_HEIGHT + ITEM_SPACING
                end
                layout[#layout + 1] = { frame = container, section = entry.id, full = y - ITEM_SPACING + ROWS_GAP }
            end
            layout[#layout + 1] = { gap = HEADER_GAP }
        end
        Relayout()
    end

    -- Expand eases out (decelerate), collapse eases in (accelerate); a finished section re-renders once.
    local driver = CreateFrame("Frame", nil, frame)
    local function StepAnimations(_, elapsed)
        if sidebar.results then wipe(sidebar.anims) end

        local finished, running = false, false
        for id, anim in pairs(sidebar.anims) do
            anim.t = mmin(anim.t + elapsed, anim.duration)
            local x = anim.t / anim.duration
            local eased = anim.to > anim.from and (1 - (1 - x) ^ 3) or x * x
            anim.p = anim.from + (anim.to - anim.from) * eased
            if x >= 1 then
                sidebar.anims[id] = nil
                finished = true
            else
                running = true
            end
        end

        if not running then driver:SetScript("OnUpdate", nil) end
        if sidebar.results then return end
        if finished then sidebar:Refresh() else Relayout() end
    end

    local function RenderResults(results)
        local y = pad
        if #results == 0 then
            if not sidebar.emptyText then
                sidebar.emptyText = scrollChild:CreateFontString(nil, "OVERLAY")
                gui:ApplyFont(sidebar.emptyText, "normal")
            end
            sidebar.emptyText:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.6)
            sidebar.emptyText:SetText(L["No results found"])
            sidebar.emptyText:ClearAllPoints()
            pixel.SetPixelPoint(sidebar.emptyText, "TOP", scrollChild, "TOP", 0, -y - 10)
            sidebar.emptyText:Show()
            pixel.SetPixelHeight(scrollChild, y + 40)
            return
        end
        if sidebar.emptyText then sidebar.emptyText:Hide() end

        for _, result in ipairs(results) do
            local item = AcquireItem()
            ConfigureItem(item, result.id, nil, y, result)
            local text
            if result.isWidget then
                text = " |cFFAAAAAA» |r " .. result.text
            else
                local hex = format("%02X%02X%02X", theme.accent[1] * 255, theme.accent[2] * 255, theme.accent[3] * 255)
                text = "|cFF" .. hex .. result.text .. "|r |cFF888888(" .. (result.sectionText or "") .. ")|r"
            end
            item.label:SetText(text)
            item.disabled = false
            item:EnableMouse(true)
            ApplyItemState(item, true)
            y = y + ITEM_HEIGHT + ITEM_SPACING
        end
        pixel.SetPixelHeight(scrollChild, y + pad)
    end

    function sidebar:Refresh()
        ReleaseAll()
        if self.results then
            RenderResults(self.results)
        else
            if self.emptyText then self.emptyText:Hide() end
            RenderTree()
        end
        SweepUnused()
    end

    function sidebar:ToggleSection(sectionId)
        local expanding = not self.expanded[sectionId]
        self.expanded[sectionId] = expanding or nil

        local header = self:GetHeader(sectionId)
        if header then header:AnimateArrow(expanding) end

        -- Toggling mid-animation turns around from wherever the section currently is.
        local running = self.anims[sectionId]
        local from = running and running.p or (expanding and 0 or 1)
        self.anims[sectionId] = {
            p = from,
            from = from,
            to = expanding and 1 or 0,
            t = 0,
            duration = expanding and EXPAND_DURATION or COLLAPSE_DURATION,
        }
        self:Refresh()
        driver:SetScript("OnUpdate", StepAnimations)
    end

    function sidebar:GetHeader(sectionId)
        for _, h in ipairs(activeHeaders) do
            if h.inUse and h.sectionId == sectionId then return h end
        end
    end

    ---Selects an entry: updates visuals in place (no rebuild) and fires onSelect.
    ---@param id string
    ---@param searchResult? table
    function sidebar:Select(id, searchResult)
        self:SetSelected(id, true)
        if onSelect then safecall(onSelect, id, searchResult) end
    end

    ---Marks an entry selected visually without firing onSelect (restore / external navigation).
    ---@param animate? boolean crossfade, for a click; restores and navigation from elsewhere snap
    function sidebar:SetSelected(id, animate)
        -- a click's onSelect navigates and lands back here; re-marking the same entry would cut its fade short
        if id == self.selected and not animate then return end
        self.selected = id
        for _, it in ipairs(activeItems) do
            ApplyItemState(it, not animate)
        end
        for _, h in ipairs(activeHeaders) do
            if h.leafId then
                ApplyHeaderSelection(h, not animate)
            end
        end
    end

    ---Expands the header owning itemId.
    ---@return boolean changed true when a collapsed header was opened, so callers can skip a Refresh
    function sidebar:EnsureExpandedFor(itemId)
        if not self.config then return false end
        for _, entry in ipairs(self.config) do
            if entry.type ~= "item" and entry.items then
                for _, child in ipairs(entry.items) do
                    if child.id == itemId then
                        local changed = not self.expanded[entry.id]
                        self.expanded[entry.id] = true
                        return changed
                    end
                end
            end
        end
        return false
    end

    function sidebar:ShowResults(results)
        self.results = results
        self:Refresh()
    end

    function sidebar:ClearResults()
        self.results = nil
        self:Refresh()
    end

    function sidebar:GetExpanded() return self.expanded end

    function sidebar:SetExpanded(tbl)
        wipe(self.expanded)
        if tbl then for k, v in pairs(tbl) do self.expanded[k] = v end end
    end

    function sidebar:SetConfig(config)
        self.config = config
        wipe(self.expanded)
        if config then
            for _, entry in ipairs(config) do
                if entry.type ~= "item" and entry.defaultExpanded then self.expanded[entry.id] = true end
            end
        end
    end

    local function RestyleChrome()
        frame:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], theme.bgDark[4])
        RestylePanel()
    end
    RestyleChrome()
    gui:OnThemeChanged(function()
        RestyleChrome()
        sidebar:Refresh()
    end)

    if opts.config then sidebar:SetConfig(opts.config) end
    return sidebar
end

--[[
# Sidebar

* The library-owned navigation panel: a scrollable list of section headers with child items.
* Driven by a config list (data); fires opts.onSelect(id, searchResult?) when an entry is chosen.
* Entry kinds:
*     { type='header', id, text, defaultExpanded?, items = { {id,text}, ... } }  -> expandable section
*     { type='item',   id, text }                                               -> header-styled leaf (opens page `id`)
* Self-restyles on theme change. Search results are rendered via ShowResults(results); ClearResults() returns to the tree.

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs
local wipe = wipe
local mrad, mpi, mabs, mmin, mmax = math.rad, math.pi, math.abs, math.min, math.max
local format = string.format

local HEADER_HEIGHT = 32
local ITEM_HEIGHT = 28
local HOVER_DURATION = 0.12
local ARROW_DURATION = 0.2
local ACCENT_BAR_WIDTH = 2
local SECTION_SPACING = 4
local ITEM_SPACING = 1

---Creates the sidebar panel.
---@param parent Frame
---@param opts table { config: table[], onSelect: fun(id, searchResult?), isDisabled?: fun(entry): boolean }
---@return table sidebar
function InstanceMixin:CreateSidebar(parent, opts)
    opts = opts or {}
    local gui = self
    local theme = self.theme
    local onSelect = opts.onSelect
    local isDisabled = opts.isDisabled or function(e) return e.disabled end
    local pad = theme.paddingSmall

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })

    local rightBorder = frame:CreateTexture(nil, "BORDER")
    pixel.SetPixelWidth(rightBorder, theme.borderSize)
    pixel.SetPixelPoint(rightBorder, "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    pixel.SetPixelPoint(rightBorder, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetFrameLevel(frame:GetFrameLevel() + 5)
    pixel.SetPixelPoint(scrollFrame, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    pixel.SetPixelPoint(scrollFrame, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -theme.borderSize, pad)
    scrollFrame:SetClipsChildren(true)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    pixel.SetPixelHeight(scrollChild, 1)
    scrollChild:SetFrameLevel(scrollFrame:GetFrameLevel() + 1)
    scrollFrame:SetScrollChild(scrollChild)

    local scrollbar = gui:CreateScrollbar(scrollFrame, {
        width = 16,
        thumbHeight = 40,
        padding = { top = -1, bottom = -1, right = 0 },
        scrollStep = 40,
    })

    local scrollbarVisible = false
    local function UpdateScrollChildWidth()
        local w = frame:GetWidth()
        if not w or w <= 0 then return end
        pixel.SetPixelWidth(scrollChild, scrollbarVisible and (w - theme.borderSize - (theme.scrollbarWidth or 16)) or (w - theme.borderSize))
    end
    local function UpdateScrollbar()
        scrollbarVisible = scrollbar:UpdateVisibility(scrollChild:GetHeight(), scrollFrame:GetHeight())
        UpdateScrollChildWidth()
    end
    scrollChild:HookScript("OnSizeChanged", UpdateScrollbar)
    scrollFrame:HookScript("OnSizeChanged", UpdateScrollbar)
    scrollFrame:HookScript("OnShow", function() UpdateScrollbar() end)
    frame:HookScript("OnSizeChanged", UpdateScrollChildWidth)

    local sidebar = {
        frame = frame,
        scrollFrame = scrollFrame,
        scrollChild = scrollChild,
        scrollbar = scrollbar,
        config = opts.config,
        expanded = {},
        selected = nil,
        results = nil,
    }

    local headerPool, itemPool = {}, {}
    local activeHeaders, activeItems = {}, {}

    -- Header --
    local function CreateHeader()
        local header = CreateFrame("Button", nil, scrollChild)
        pixel.SetPixelHeight(header, HEADER_HEIGHT)
        header:EnableMouse(true)
        header:RegisterForClicks("LeftButtonUp")

        local hoverBg = header:CreateTexture(nil, "BACKGROUND")
        hoverBg:SetAllPoints()
        hoverBg:SetColorTexture(1, 1, 1, 0.04)
        hoverBg:SetAlpha(0)
        header.hoverBg = hoverBg

        local selectedBg = header:CreateTexture(nil, "BACKGROUND", nil, 1)
        selectedBg:SetAllPoints()
        selectedBg:Hide()
        header.selectedBg = selectedBg

        local accentBar = header:CreateTexture(nil, "OVERLAY")
        pixel.SetPixelWidth(accentBar, ACCENT_BAR_WIDTH)
        pixel.SetPixelPoint(accentBar, "TOPLEFT", header, "TOPLEFT", 0, 0)
        pixel.SetPixelPoint(accentBar, "BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
        accentBar:Hide()
        header.accentBar = accentBar

        local label = header:CreateFontString(nil, "OVERLAY")
        label:SetPoint("LEFT", header, "LEFT", pad, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        header.label = label

        local arrow = header:CreateTexture(nil, "OVERLAY")
        pixel.SetPixelSize(arrow, 14, 14)
        pixel.SetPixelPoint(arrow, "RIGHT", header, "RIGHT", -pad, 0)
        arrow:SetTexture(theme.stepperTexture)
        pixel.SetPixelSnap(arrow)
        header.arrow = arrow

        local animGroup = arrow:CreateAnimationGroup()
        local rotation = animGroup:CreateAnimation("Rotation")
        rotation:SetDuration(ARROW_DURATION)
        rotation:SetOrigin("CENTER", 0, 0)
        rotation:SetSmoothing("OUT")
        animGroup:SetScript("OnFinished", function()
            arrow:SetRotation(header.isExpanded and 0 or -mpi / 2)
        end)
        header.SetArrowState = function(self, expanded)
            animGroup:Stop()
            self.isExpanded = expanded
            arrow:SetRotation(expanded and 0 or -mpi / 2)
        end
        header.AnimateArrow = function(self, expanded)
            if self.isExpanded == expanded then return end
            animGroup:Stop()
            rotation:SetRadians(expanded and mpi / 2 or -mpi / 2)
            self.isExpanded = expanded
            animGroup:Play()
        end

        local hoverTarget = 0
        header:SetScript("OnUpdate", function(_, elapsed)
            local cur = hoverBg:GetAlpha()
            if mabs(cur - hoverTarget) > 0.01 then
                local speed = elapsed / HOVER_DURATION
                hoverBg:SetAlpha(hoverTarget > cur and mmin(cur + speed, hoverTarget) or mmax(cur - speed, hoverTarget))
            end
        end)
        header:SetScript("OnEnter", function()
            if header.disabled then return end
            hoverTarget = 1
            header.arrow:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
        end)
        header:SetScript("OnLeave", function()
            hoverTarget = 0
            if not header.disabled then
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

        local hoverBg = item:CreateTexture(nil, "BACKGROUND")
        hoverBg:SetAllPoints()
        hoverBg:SetColorTexture(1, 1, 1, 0.05)
        hoverBg:SetAlpha(0)
        item.hoverBg = hoverBg

        local selectedBg = item:CreateTexture(nil, "BACKGROUND", nil, 1)
        selectedBg:SetAllPoints()
        selectedBg:Hide()
        item.selectedBg = selectedBg

        local accentBar = item:CreateTexture(nil, "OVERLAY")
        pixel.SetPixelWidth(accentBar, ACCENT_BAR_WIDTH)
        pixel.SetPixelPoint(accentBar, "TOPLEFT", item, "TOPLEFT", 0, 0)
        pixel.SetPixelPoint(accentBar, "BOTTOMLEFT", item, "BOTTOMLEFT", 0, 0)
        accentBar:Hide()
        item.accentBar = accentBar

        local label = item:CreateFontString(nil, "OVERLAY")
        pixel.SetPixelPoint(label, "LEFT", item, "LEFT", 10, 0)
        pixel.SetPixelPoint(label, "RIGHT", item, "RIGHT", -pad, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        item.label = label

        item.hoverTarget = 0
        item:SetScript("OnUpdate", function(self, elapsed)
            local cur = hoverBg:GetAlpha()
            if mabs(cur - self.hoverTarget) > 0.01 then
                local speed = elapsed / HOVER_DURATION
                hoverBg:SetAlpha(self.hoverTarget > cur and mmin(cur + speed, self.hoverTarget) or mmax(cur - speed, self.hoverTarget))
            end
        end)
        item:SetScript("OnEnter", function(self)
            if self.disabled then return end
            self.hoverTarget = 1
            if self.id ~= sidebar.selected then
                self.label:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
            end
        end)
        item:SetScript("OnLeave", function(self)
            self.hoverTarget = 0
            if self.id ~= sidebar.selected and not self.disabled then
                self.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
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

    local function ReleaseAll()
        for _, h in ipairs(headerPool) do
            h.inUse = false; h.disabled = nil; h.leafId = nil; h.sectionId = nil
            h.hoverBg:SetAlpha(0); h.accentBar:Hide(); h.selectedBg:Hide(); h:Hide(); h:ClearAllPoints()
        end
        for _, it in ipairs(itemPool) do
            it.inUse = false; it.disabled = nil; it.id = nil; it.searchResult = nil; it.hoverTarget = 0
            it.hoverBg:SetAlpha(0); it.accentBar:Hide(); it.selectedBg:Hide()
            it:Hide(); it:ClearAllPoints()
        end
        wipe(activeHeaders); wipe(activeItems)
    end

    -- Visual state --
    local function ApplyItemState(item)
        if item.disabled then
            item.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.35)
            item.accentBar:Hide(); item.selectedBg:Hide()
        elseif item.id == sidebar.selected then
            item.accentBar:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            item.selectedBg:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.08)
            item.accentBar:Show(); item.selectedBg:Show()
            item.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        else
            item.accentBar:Hide(); item.selectedBg:Hide()
            item.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
        end
    end

    local function ApplyHeaderSelection(header)
        if header.leafId and not header.disabled and header.leafId == sidebar.selected then
            header.accentBar:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            header.selectedBg:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.08)
            header.accentBar:Show(); header.selectedBg:Show()
        else
            header.accentBar:Hide(); header.selectedBg:Hide()
        end
    end

    local function ConfigureItem(item, id, text, yOffset, searchResult)
        item:SetParent(scrollChild)
        item:SetFrameLevel(scrollChild:GetFrameLevel() + 2)
        pixel.SetPixelHeight(item, ITEM_HEIGHT)
        item:ClearAllPoints()
        pixel.SetPixelPoint(item, "TOPLEFT", scrollChild, "TOPLEFT", pad, -yOffset)
        pixel.SetPixelPoint(item, "TOPRIGHT", scrollChild, "TOPRIGHT", -pad, -yOffset)
        item.id = id
        item.searchResult = searchResult
        item.label:Show()
        gui:ApplyFont(item.label, "normal")
        item.label:SetText(text or "")
        activeItems[#activeItems + 1] = item
    end

    local function ConfigureHeader(header, entry, yOffset, isLeaf)
        header:SetParent(scrollChild)
        header:SetFrameLevel(scrollChild:GetFrameLevel() + 2)
        pixel.SetPixelHeight(header, HEADER_HEIGHT)
        header:ClearAllPoints()
        pixel.SetPixelPoint(header, "TOPLEFT", scrollChild, "TOPLEFT", pad, -yOffset)
        pixel.SetPixelPoint(header, "TOPRIGHT", scrollChild, "TOPRIGHT", -pad, -yOffset)
        header.label:Show()
        gui:ApplyFont(header.label, "large")
        header.label:SetText(entry.text or "")

        local disabled = isDisabled(entry) or false
        header.disabled = disabled

        if isLeaf then
            header.leafId = entry.id
            header.sectionId = nil
            header.arrow:Hide()
            ApplyHeaderSelection(header)
        else
            header.leafId = nil
            header.sectionId = entry.id
            header.arrow:Show()
            header.accentBar:Hide()
            header.selectedBg:Hide()
            header:SetArrowState(sidebar.expanded[entry.id] == true)
        end

        if disabled then
            header.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.35)
            header.arrow:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.35)
        else
            header.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            header.arrow:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.7)
        end
        activeHeaders[#activeHeaders + 1] = header
    end

    -- Rendering --
    local function RenderTree()
        local y = pad
        if not sidebar.config then
            pixel.SetPixelHeight(scrollChild, 1); return
        end
        for _, entry in ipairs(sidebar.config) do
            if entry.type == "item" then
                local header = AcquireHeader()
                ConfigureHeader(header, entry, y, true)
                y = y + HEADER_HEIGHT + SECTION_SPACING
            else
                local header = AcquireHeader()
                ConfigureHeader(header, entry, y, false)
                y = y + HEADER_HEIGHT
                if sidebar.expanded[entry.id] and entry.items then
                    local sectionDisabled = isDisabled(entry)
                    for _, child in ipairs(entry.items) do
                        local item = AcquireItem()
                        ConfigureItem(item, child.id, child.text, y)
                        item.disabled = sectionDisabled or isDisabled(child) or false
                        item:EnableMouse(not item.disabled)
                        ApplyItemState(item)
                        y = y + ITEM_HEIGHT + ITEM_SPACING
                    end
                end
                y = y + SECTION_SPACING
            end
        end
        pixel.SetPixelHeight(scrollChild, y + pad)
    end

    local function RenderResults(results)
        local y = pad
        if #results == 0 then
            if not sidebar.emptyText then
                sidebar.emptyText = scrollChild:CreateFontString(nil, "OVERLAY")
                gui:ApplyFont(sidebar.emptyText, "normal")
            end
            sidebar.emptyText:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.6)
            sidebar.emptyText:SetText("No results found")
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
            ApplyItemState(item)
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
    end

    function sidebar:ToggleSection(sectionId)
        if self.expanded[sectionId] then
            self.expanded[sectionId] = nil
            local h = self:GetHeader(sectionId)
            if h then h:AnimateArrow(false) end
        else
            self.expanded[sectionId] = true
            local h = self:GetHeader(sectionId)
            if h then h:AnimateArrow(true) end
        end
        self:Refresh()
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
        self:SetSelected(id)
        if onSelect then safecall(onSelect, id, searchResult) end
    end

    ---Marks an entry selected visually without firing onSelect (restore / external navigation).
    function sidebar:SetSelected(id)
        self.selected = id
        for _, it in ipairs(activeItems) do ApplyItemState(it) end
        for _, h in ipairs(activeHeaders) do
            if h.leafId then ApplyHeaderSelection(h) end
        end
    end

    function sidebar:EnsureExpandedFor(itemId)
        if not self.config then return end
        for _, entry in ipairs(self.config) do
            if entry.type ~= "item" and entry.items then
                for _, child in ipairs(entry.items) do
                    if child.id == itemId then
                        self.expanded[entry.id] = true; return
                    end
                end
            end
        end
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
        frame:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], theme.bgMedium[4])
        rightBorder:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
    end
    RestyleChrome()
    gui:OnThemeChanged(function()
        RestyleChrome()
        sidebar:Refresh()
    end)

    if opts.config then sidebar:SetConfig(opts.config) end
    return sidebar
end

--[[
# MiniSidebar

* A left item-list column that a content host places beside its scroll region.
* Owns only the list column: an optional button area on top, then a scrollable flat list of items.
* Items are plain data: { key, text, icon? }. renderItem(itemFrame, item, selected) can override the default rendering.
* An item may instead be a section: { type = 'header', key, text, defaultExpanded?, items = { ... } }, which
  renders a collapsible header with its children indented beneath. Sections are one level deep.
* :SetConfig returns only the *selectable leaves*, flattened in display order, so a host can pick an
  initial selection by key without knowing the tree exists.
* Fires opts.onSelect(key, item) when an item is clicked. Self-restyles on theme change.
* A descriptor may add onContextMenu(key, item, itemFrame), fired on right-click. The sidebar has no
  opinion on what that means; the host decides (typically gui:ShowContextMenu).

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
local type = type
local mabs, mmin, mmax = math.abs, math.min, math.max
local mpi = math.pi

local DEFAULT_WIDTH = 192
local HEADER_HEIGHT = 26
local ITEM_INDENT = 10
local ITEM_HEIGHT = 28
local ITEM_SPACING = 1
local HOVER_DURATION = 0.12
local ACCENT_BAR_WIDTH = 2
local ICON_SIZE = 16
local BUTTON_HEIGHT = 26
local BUTTON_SPACING = 4

---Creates a mini sidebar column. The caller anchors, shows and hides ms.frame.
---@param parent Frame
---@param opts table { onSelect: fun(key: string, item: table) }
---@return table ms
function InstanceMixin:CreateMiniSidebar(parent, opts)
    opts = opts or {}
    local gui = self
    local theme = self.theme
    local onSelect = opts.onSelect
    local pad = theme.paddingSmall

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    pixel.SetPixelWidth(frame, DEFAULT_WIDTH)

    local rightBorder = frame:CreateTexture(nil, "BORDER")
    pixel.SetPixelWidth(rightBorder, theme.borderSize)
    pixel.SetPixelPoint(rightBorder, "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    pixel.SetPixelPoint(rightBorder, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    -- Button area: anchored to the top, height set in SetConfig; the list scrolls below it.
    local buttonArea = CreateFrame("Frame", nil, frame)
    pixel.SetPixelPoint(buttonArea, "TOPLEFT", frame, "TOPLEFT", pad, -pad)
    pixel.SetPixelPoint(buttonArea, "TOPRIGHT", frame, "TOPRIGHT", -pad - theme.borderSize, -pad)
    pixel.SetPixelHeight(buttonArea, 1)
    buttonArea:Hide()

    local buttonSeparator = buttonArea:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelHeight(buttonSeparator, theme.borderSize)
    pixel.SetPixelPoint(buttonSeparator, "BOTTOMLEFT", buttonArea, "BOTTOMLEFT", 0, 0)
    pixel.SetPixelPoint(buttonSeparator, "BOTTOMRIGHT", buttonArea, "BOTTOMRIGHT", 0, 0)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetFrameLevel(frame:GetFrameLevel() + 5)
    scrollFrame:SetClipsChildren(true)

    local function AnchorScroll(belowButtons)
        scrollFrame:ClearAllPoints()
        if belowButtons then
            pixel.SetPixelPoint(scrollFrame, "TOPLEFT", buttonArea, "BOTTOMLEFT", -pad, -pad)
        else
            pixel.SetPixelPoint(scrollFrame, "TOPLEFT", frame, "TOPLEFT", 0, 0)
        end
        pixel.SetPixelPoint(scrollFrame, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -theme.borderSize, pad)
    end
    AnchorScroll(false)

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

    local ms = {
        frame = frame,
        items = nil,        -- the tree as given
        leaves = nil,       -- selectable entries only, flattened in display order
        expanded = {},      -- [headerKey] = true
        selected = nil,
        renderItem = nil,
    }

    local itemPool, activeItems = {}, {}
    local headerPool, activeHeaders = {}, {}
    local buttonPool = {}

    local function ApplyItemState(item)
        if item.key == ms.selected then
            item.accentBar:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            item.selectedBg:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.08)
            item.accentBar:Show(); item.selectedBg:Show()
            item.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        else
            item.accentBar:Hide(); item.selectedBg:Hide()
            item.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
        end
    end

    local function CreateItem()
        local item = CreateFrame("Button", nil, scrollChild)
        pixel.SetPixelHeight(item, ITEM_HEIGHT)
        item:RegisterForClicks("LeftButtonUp", "RightButtonUp")

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

        local icon = item:CreateTexture(nil, "ARTWORK")
        pixel.SetPixelSize(icon, ICON_SIZE, ICON_SIZE)
        pixel.SetPixelPoint(icon, "LEFT", item, "LEFT", 10, 0)
        icon:Hide()
        item.icon = icon

        local label = item:CreateFontString(nil, "OVERLAY")
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
            self.hoverTarget = 1
            if self.key ~= ms.selected then
                self.label:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
            end
        end)
        item:SetScript("OnLeave", function(self)
            self.hoverTarget = 0
            if self.key ~= ms.selected then
                self.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
            end
        end)
        item:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if ms.onContextMenu then safecall(ms.onContextMenu, self.key, self.item, self) end
                return
            end
            if self.key ~= ms.selected then ms:Select(self.key) end
        end)

        return item
    end

    local function CreateHeader()
        local header = CreateFrame("Button", nil, scrollChild)
        pixel.SetPixelHeight(header, HEADER_HEIGHT)
        header:RegisterForClicks("LeftButtonUp")

        local hoverBg = header:CreateTexture(nil, "BACKGROUND")
        hoverBg:SetAllPoints()
        hoverBg:SetColorTexture(1, 1, 1, 0.05)
        hoverBg:SetAlpha(0)
        header.hoverBg = hoverBg

        local arrow = header:CreateTexture(nil, "OVERLAY")
        pixel.SetPixelSize(arrow, 10, 10)
        arrow:SetTexture(theme.stepperTexture)
        pixel.SetPixelPoint(arrow, "LEFT", header, "LEFT", pad, 0)
        header.arrow = arrow

        local label = header:CreateFontString(nil, "OVERLAY")
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        pixel.SetPixelPoint(label, "LEFT", arrow, "RIGHT", 6, 0)
        pixel.SetPixelPoint(label, "RIGHT", header, "RIGHT", -pad, 0)
        header.label = label

        header:SetScript("OnEnter", function(self) self.hoverBg:SetAlpha(1) end)
        header:SetScript("OnLeave", function(self) self.hoverBg:SetAlpha(0) end)
        header:SetScript("OnClick", function(self)
            ms.expanded[self.key] = not ms.expanded[self.key]
            ms:Render()
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
            h.inUse = false; h.key = nil
            h.hoverBg:SetAlpha(0)
            h:Hide(); h:ClearAllPoints()
        end
        wipe(activeHeaders)
        for _, it in ipairs(itemPool) do
            it.inUse = false; it.key = nil; it.item = nil; it.hoverTarget = 0
            it.hoverBg:SetAlpha(0); it.accentBar:Hide(); it.selectedBg:Hide(); it.icon:Hide()
            it:Hide(); it:ClearAllPoints()
        end
        wipe(activeItems)
    end

    local function ConfigureItem(item, data, yOffset, indent)
        item:ClearAllPoints()
        pixel.SetPixelPoint(item, "TOPLEFT", scrollChild, "TOPLEFT", pad + (indent or 0), -yOffset)
        pixel.SetPixelPoint(item, "TOPRIGHT", scrollChild, "TOPRIGHT", -pad, -yOffset)
        item.key = data.key
        item.item = data

        gui:ApplyFont(item.label, "normal")
        item.label:SetText(data.text or "")
        item.label:ClearAllPoints()
        if data.icon then
            item.icon:SetTexture(data.icon)
            item.icon:Show()
            pixel.SetPixelPoint(item.icon, "LEFT", item, "LEFT", 10, 0)
            pixel.SetPixelPoint(item.label, "LEFT", item.icon, "RIGHT", 6, 0)
        else
            item.icon:Hide()
            pixel.SetPixelPoint(item.label, "LEFT", item, "LEFT", 10, 0)
        end
        pixel.SetPixelPoint(item.label, "RIGHT", item, "RIGHT", -pad, 0)

        ApplyItemState(item)
        if ms.renderItem then safecall(ms.renderItem, item, data, data.key == ms.selected) end
        activeItems[#activeItems + 1] = item
    end

    local function ConfigureHeader(header, data, yOffset)
        header:ClearAllPoints()
        pixel.SetPixelPoint(header, "TOPLEFT", scrollChild, "TOPLEFT", pad, -yOffset)
        pixel.SetPixelPoint(header, "TOPRIGHT", scrollChild, "TOPRIGHT", -pad, -yOffset)
        header.key = data.key

        gui:ApplyFont(header.label, "normal")
        header.label:SetText(data.text or "")
        header.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        header.arrow:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.7)
        header.arrow:SetRotation(ms.expanded[data.key] and 0 or mpi / 2)

        activeHeaders[#activeHeaders + 1] = header
    end

    ---Walks the tree, rendering it and collecting the selectable leaves in display order.
    local function RenderList()
        ReleaseAll()
        local leaves = {}
        local y = pad

        for _, data in ipairs(ms.items or {}) do
            if data.type == "header" then
                ConfigureHeader(AcquireHeader(), data, y)
                y = y + HEADER_HEIGHT + ITEM_SPACING

                if ms.expanded[data.key] then
                    for _, child in ipairs(data.items or {}) do
                        ConfigureItem(AcquireItem(), child, y, ITEM_INDENT)
                        leaves[#leaves + 1] = child
                        y = y + ITEM_HEIGHT + ITEM_SPACING
                    end
                else
                    -- Still selectable by key while collapsed: a host restoring a remembered item
                    -- must not be told it has gone away.
                    for _, child in ipairs(data.items or {}) do
                        leaves[#leaves + 1] = child
                    end
                end
            else
                ConfigureItem(AcquireItem(), data, y)
                leaves[#leaves + 1] = data
                y = y + ITEM_HEIGHT + ITEM_SPACING
            end
        end

        ms.leaves = leaves
        pixel.SetPixelHeight(scrollChild, y + pad)
        UpdateScrollbar()
    end

    ---Re-render in place, keeping the current items and expansion state.
    function ms:Render()
        RenderList()
        for _, it in ipairs(activeItems) do ApplyItemState(it) end
    end

    local function LayoutButtons(buttons)
        for _, b in ipairs(buttonPool) do b:Hide() end
        if not buttons or #buttons == 0 then
            buttonArea:Hide()
            AnchorScroll(false)
            return
        end

        for i, def in ipairs(buttons) do
            local btn = buttonPool[i]
            if not btn then
                btn = gui:CreateButton(buttonArea, def.text, {
                    height = BUTTON_HEIGHT,
                    callback = def.onClick,
                    tooltip = def.tooltip,
                })
                buttonPool[i] = btn
            else
                btn:SetLabel(def.text)
                btn:SetCallback(def.onClick)
                btn:SetTooltip(def.tooltip)
            end
            btn:Show()
            btn:ClearAllPoints()
            local y = (i - 1) * (BUTTON_HEIGHT + BUTTON_SPACING)
            pixel.SetPixelPoint(btn, "TOPLEFT", buttonArea, "TOPLEFT", 0, -y)
            pixel.SetPixelPoint(btn, "TOPRIGHT", buttonArea, "TOPRIGHT", 0, -y)
        end

        pixel.SetPixelHeight(buttonArea, #buttons * (BUTTON_HEIGHT + BUTTON_SPACING) + pad)
        buttonArea:Show()
        AnchorScroll(true)
    end

    ---Seeds expansion for any section seen for the first time, so a header's defaultExpanded is
    ---honoured once and the user's own collapsing survives a re-render.
    local function SeedExpansion(items)
        for _, data in ipairs(items or {}) do
            if data.type == "header" and ms.expanded[data.key] == nil then
                ms.expanded[data.key] = data.defaultExpanded ~= false
            end
        end
    end

    ---Applies a sidebar descriptor and renders the list. Returns the selectable leaves, flattened in
    ---display order, so a host can resolve an initial selection by key without walking the tree.
    ---@param sd table { items: table|fun(): table, width?: number, buttons?: table[], renderItem?: fun(itemFrame, item, selected), onContextMenu?: fun(key, item, itemFrame) }
    ---@return table leaves
    function ms:SetConfig(sd)
        pixel.SetPixelWidth(frame, sd.width or DEFAULT_WIDTH)
        self.renderItem = sd.renderItem
        self.onContextMenu = sd.onContextMenu
        if self._buttonsRef ~= sd.buttons then
            self._buttonsRef = sd.buttons
            LayoutButtons(sd.buttons)
        end
        self.items = type(sd.items) == "function" and sd.items() or sd.items
        SeedExpansion(self.items)
        RenderList()
        return self.leaves
    end

    ---@param items table[]
    ---@return table leaves
    function ms:SetItems(items)
        self.items = items
        SeedExpansion(items)
        RenderList()
        return self.leaves
    end

    ---Marks an item selected visually without firing onSelect.
    ---@param key any
    function ms:SetSelected(key)
        self.selected = key
        for _, it in ipairs(activeItems) do ApplyItemState(it) end
    end

    ---Selects an item and fires onSelect.
    ---@param key any
    function ms:Select(key)
        self:SetSelected(key)
        if onSelect then
            for _, data in ipairs(self.leaves or {}) do
                if data.key == key then
                    safecall(onSelect, key, data)
                    return
                end
            end
        end
    end

    function ms:GetSelected() return self.selected end

    local function RestyleChrome()
        frame:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], 0.2)
        rightBorder:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
        buttonSeparator:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    end
    RestyleChrome()
    gui:OnThemeChanged(function()
        RestyleChrome()
        -- Through :Render, so selection colouring is reapplied to the freshly configured rows.
        ms:Render()
    end)

    return ms
end

--[[
# MiniSidebar

* A left item-list column that a content host places beside its scroll region.
* Owns only the list column: an optional button area on top, then a scrollable flat list of items.
* Items are plain data: { key, text, icon? }. renderItem(itemFrame, item, selected) can override the default rendering.
* Items may carry `accent` ({ r, g, b }), which colours the icon border (class colour, say), and `disabled`,
* which dims the row and desaturates its icon. `iconColor` ({ r, g, b, a? }) tints the icon
* and `iconCoords` ({ l, r, t, b }) crops it.
* An item may instead be a section: { type = 'header', key, text, defaultExpanded?, items = { ... } }, which
* renders a collapsible header with its children indented beneath. Sections are one level deep, and
* open and close with an animation. `sd.onToggle(key, expanded)` lets a host remember the state; it
* hands it back as `defaultExpanded`.
* An item may also be a caption: { type = 'label', key, text }, an inert row that titles the sections
* below it, for a flat list whose sections come from more than one source.
* :SetConfig returns only the *selectable leaves*, flattened in display order, so a host can pick an
* initial selection by key without knowing the tree exists.
* A button def { text, key } is a selectable entry: it latches while selected and leads the leaves.
* Without a key a button is a plain action firing def.onClick.
* Fires opts.onSelect(key, item) when an item is clicked. Self-restyles on theme change.
* A descriptor may add onContextMenu(key, item, itemFrame), fired on right-click of an item or a
* section header. The sidebar has no opinion on what that means; the host decides (typically
* gui:ShowContextMenu) and tells the two apart with item.type == 'header'.

## Rename in place

* `ms:BeginRename(key)` swaps an item's or header's label for an edit box. Enter hands the text to
  `sd.onRename(key, text, item)`; returning false keeps the box open with an error border.
  Escape and clicking away cancel. An item with `renamable = true` also starts it on a double-click.

## Drag and drop

* Items with `draggable = true` can be dragged once `sd.onMove(key, targetKey, position)` is set.
  `position` is 'before' / 'after' an item or 'into' a section header.
* `sd.canDrop(item, target, position)` vetoes a spot; without it every spot is allowed.
* A ghost of the row follows the cursor, a line or a tinted header marks the drop. Hovering a closed
  section opens it, the list scrolls near its edges, and Escape or releasing over nothing cancels.

--]]

local lib = LibStub and LibStub('LibKaji-1.0', true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local InCombatLockdown = InCombatLockdown
local UIParent = UIParent
local ipairs, pairs = ipairs, pairs
local wipe = wipe
local type = type
local strtrim = strtrim
local mabs, mmin, mmax, mfloor = math.abs, math.min, math.max, math.floor
local mpi = math.pi
local C_Timer = C_Timer

local DEFAULT_WIDTH = 192
local HEADER_HEIGHT = 26
local LABEL_HEIGHT = 24
local ITEM_INDENT = 2
local ITEM_HEIGHT = 28
local ITEM_SPACING = 1
local HOVER_DURATION = 0.12
local EXPAND_DURATION = 0.2
local COLLAPSE_DURATION = 0.15
local ACCENT_BAR_WIDTH = 2
local ICON_SIZE = 22
local ICON_CROP = 0.08
local DISABLED_ALPHA = 0.45
local DRAG_SOURCE_ALPHA = 0.35
local DROP_LINE_HEIGHT = 2
local DROP_TINT_ALPHA = 0.15
local OPEN_ON_HOVER = 0.6 -- seconds a dragged row rests on a closed section before it opens
local SCROLL_EDGE = 24 -- the list scrolls while a dragged row is this close to its top or bottom
local SCROLL_SPEED = 300 -- pixels a second at the very edge
local ICON_BORDER = { 0, 0, 0, 1 }
local BUTTON_SPACING = 4
local UNDERLINE_GLOW_HEIGHT = 8
local LABEL_TEXT_BOTTOM = 6 -- caption text sits this far above its row's bottom
local SECTION_GAP = 10 -- extra space above every caption but the first, so captions group downwards
local TAB_UNDERLINE = 2
local TAB_BACKDROP = { bgFile = 'Interface\\Buttons\\WHITE8X8', edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 }

---An item's crop and tint, back to the default zoomed icon when it names neither.
---@param texture Texture
---@param data table
local function ApplyIconLook(texture, data)
    local coords, tint = data.iconCoords, data.iconColor
    if coords then
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        texture:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    end
    if tint then
        texture:SetVertexColor(tint[1], tint[2], tint[3], tint[4] or 1)
    else
        texture:SetVertexColor(1, 1, 1, 1)
    end
end

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
    -- Buttons sit in the theme's header band, like the content sub-tabs and the search box.
    local BUTTON_HEIGHT = theme.barControlHeight
    local BAR_INSET = theme.barInset

    local frame = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
    frame:SetBackdrop({ bgFile = 'Interface\\Buttons\\WHITE8X8' })
    pixel.SetPixelWidth(frame, DEFAULT_WIDTH)

    local rightBorder = frame:CreateTexture(nil, 'BORDER')
    pixel.SetPixelWidth(rightBorder, theme.borderSize)
    pixel.SetPixelPoint(rightBorder, 'TOPRIGHT', frame, 'TOPRIGHT', 0, 0)
    pixel.SetPixelPoint(rightBorder, 'BOTTOMRIGHT', frame, 'BOTTOMRIGHT', 0, 0)

    -- Button area: anchored to the top, height set in SetConfig; the list scrolls below it.
    local buttonArea = CreateFrame('Frame', nil, frame)
    pixel.SetPixelPoint(buttonArea, 'TOPLEFT', frame, 'TOPLEFT', pad, -BAR_INSET)
    pixel.SetPixelPoint(buttonArea, 'TOPRIGHT', frame, 'TOPRIGHT', -pad - theme.borderSize, -BAR_INSET)
    pixel.SetPixelHeight(buttonArea, 1)
    buttonArea:Hide()

    local buttonSeparator = buttonArea:CreateTexture(nil, 'ARTWORK')
    pixel.SetPixelHeight(buttonSeparator, theme.borderSize)
    pixel.SetPixelPoint(buttonSeparator, 'BOTTOMLEFT', buttonArea, 'BOTTOMLEFT', 0, 0)
    pixel.SetPixelPoint(buttonSeparator, 'BOTTOMRIGHT', buttonArea, 'BOTTOMRIGHT', 0, 0)

    local scrollFrame = CreateFrame('ScrollFrame', nil, frame)
    scrollFrame:SetFrameLevel(frame:GetFrameLevel() + 5)
    scrollFrame:SetClipsChildren(true)

    local function AnchorScroll(belowButtons)
        scrollFrame:ClearAllPoints()
        if belowButtons then
            pixel.SetPixelPoint(scrollFrame, 'TOPLEFT', buttonArea, 'BOTTOMLEFT', -pad, -pad)
        else
            pixel.SetPixelPoint(scrollFrame, 'TOPLEFT', frame, 'TOPLEFT', 0, 0)
        end
        pixel.SetPixelPoint(scrollFrame, 'BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -theme.borderSize, pad)
    end
    AnchorScroll(false)

    local scrollChild = CreateFrame('Frame', nil, scrollFrame)
    pixel.SetPixelHeight(scrollChild, 1)
    scrollChild:SetFrameLevel(scrollFrame:GetFrameLevel() + 1)
    scrollFrame:SetScrollChild(scrollChild)

    -- The track spans the whole column, button area included; the buttons step aside for it.
    local scrollbar = gui:CreateScrollbar(scrollFrame, {
        width = theme.scrollbarWidth,
        thumbHeight = 40,
        -- Flush with the column edge: the track's own right border doubles as the column's divider.
        padding = { top = 0, bottom = 0, right = 0 },
        scrollStep = 40,
    })

    local scrollbarVisible = false
    local function AnchorButtonArea()
        local right = pad + (scrollbarVisible and theme.scrollbarWidth or theme.borderSize)
        buttonArea:ClearAllPoints()
        pixel.SetPixelPoint(buttonArea, 'TOPLEFT', frame, 'TOPLEFT', pad, -BAR_INSET)
        pixel.SetPixelPoint(buttonArea, 'TOPRIGHT', frame, 'TOPRIGHT', -right, -BAR_INSET)
    end
    local function UpdateScrollChildWidth()
        local w = frame:GetWidth()
        if not w or w <= 0 then return end
        pixel.SetPixelWidth(scrollChild, scrollbarVisible and (w - theme.scrollbarWidth) or (w - theme.borderSize))
    end
    local function UpdateScrollbar()
        local visible = scrollbar:UpdateVisibility(scrollChild:GetHeight(), scrollFrame:GetHeight())
        if visible ~= scrollbarVisible then
            scrollbarVisible = visible
            AnchorButtonArea()
        end
        UpdateScrollChildWidth()
        -- A scroll child resized before its ScrollFrame has a rect is not redrawn once the rect resolves.
        scrollFrame:UpdateScrollChildRect()
    end
    scrollChild:HookScript('OnSizeChanged', UpdateScrollbar)
    scrollFrame:HookScript('OnSizeChanged', UpdateScrollbar)
    scrollFrame:HookScript('OnShow', function() UpdateScrollbar() end)
    frame:HookScript('OnSizeChanged', UpdateScrollChildWidth)

    local ms = {
        frame = frame,
        items = nil,        -- the tree as given
        leaves = nil,       -- selectable entries only, flattened in display order
        expanded = {},      -- [headerKey] = true
        anims = {},         -- [headerKey] = { p, from, to, t, duration }, a section opening or closing
        selected = nil,
        renderItem = nil,
    }

    local itemPool, activeItems = {}, {}
    local headerPool, activeHeaders = {}, {}
    local labelPool = {}
    local containerPool = {}
    local layout = {} -- ordered blocks: { frame, height } | { frame, section, full } | { gap }
    local buttonPool = {}    -- unkeyed action buttons
    local tabButtonPool = {} -- keyed, selectable tab-styled buttons

    local BeginDrag, EndRename -- defined with their features below

    -- SetTextColor's alpha overrides FontString:SetAlpha, so the disabled dim rides on every text colour.
    local function ApplyItemState(item)
        local alpha = item.item and item.item.disabled and DISABLED_ALPHA or 1
        if item.key == ms.selected then
            item.accentBar:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            item.accentBar:Show()
            lib.PaintSelected(item, theme)
            item.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], alpha)
        else
            item.accentBar:Hide(); item.selectedBg:Hide(); item.barGlow:Hide()
            item.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], alpha)
        end
        item:SetAlpha(ms.drag and ms.drag.key == item.key and DRAG_SOURCE_ALPHA or 1)
    end

    local function CreateItem()
        local item = CreateFrame('Button', nil, scrollChild)
        pixel.SetPixelHeight(item, ITEM_HEIGHT)
        item:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

        local hoverBg = item:CreateTexture(nil, 'BACKGROUND')
        hoverBg:SetAllPoints()
        hoverBg:SetColorTexture(1, 1, 1, 0.05)
        hoverBg:SetAlpha(0)
        item.hoverBg = hoverBg

        local selectedBg = item:CreateTexture(nil, 'BACKGROUND', nil, 1)
        selectedBg:SetAllPoints()
        selectedBg:Hide()
        item.selectedBg = selectedBg

        local accentBar = item:CreateTexture(nil, 'OVERLAY')
        pixel.SetPixelWidth(accentBar, ACCENT_BAR_WIDTH)
        pixel.SetPixelPoint(accentBar, 'TOPLEFT', item, 'TOPLEFT', 0, 0)
        pixel.SetPixelPoint(accentBar, 'BOTTOMLEFT', item, 'BOTTOMLEFT', 0, 0)
        accentBar:Hide()
        item.accentBar = accentBar
        item.barGlow = lib.CreateBarGlow(item, accentBar)

        -- Runs through the spacing gap so the guide is unbroken; the selected item's bar covers its stretch.
        local guide = item:CreateTexture(nil, 'BORDER')
        pixel.SetPixelWidth(guide, theme.borderSize)
        pixel.SetPixelPoint(guide, 'TOPLEFT', item, 'TOPLEFT', 0, 0)
        pixel.SetPixelPoint(guide, 'BOTTOMLEFT', item, 'BOTTOMLEFT', 0, -ITEM_SPACING)
        pixel.SetPixelSnap(guide)
        guide:Hide()
        item.guide = guide

        local iconBorder = item:CreateTexture(nil, 'ARTWORK', nil, -1)
        pixel.SetPixelSize(iconBorder, ICON_SIZE, ICON_SIZE)
        iconBorder:Hide()
        item.iconBorder = iconBorder

        local icon = item:CreateTexture(nil, 'ARTWORK')
        pixel.SetPixelSize(icon, ICON_SIZE - 2, ICON_SIZE - 2)
        pixel.SetPixelPoint(icon, 'CENTER', iconBorder, 'CENTER', 0, 0)
        icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        icon:Hide()
        item.icon = icon

        local label = item:CreateFontString(nil, 'OVERLAY')
        label:SetJustifyH('LEFT')
        label:SetWordWrap(false)
        item.label = label

        item.hoverTarget = 0
        item:SetScript('OnUpdate', function(self, elapsed)
            local cur = hoverBg:GetAlpha()
            if mabs(cur - self.hoverTarget) > 0.01 then
                local speed = elapsed / HOVER_DURATION
                hoverBg:SetAlpha(self.hoverTarget > cur and mmin(cur + speed, self.hoverTarget) or mmax(cur - speed, self.hoverTarget))
            end
        end)
        item:SetScript('OnEnter', function(self)
            self.hoverTarget = 1
            if self.key ~= ms.selected then
                local alpha = self.item and self.item.disabled and DISABLED_ALPHA or 1
                self.label:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], alpha)
                -- Neon: the accent bar fades in partway, previewing the selection.
                self.accentBar:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], lib.HOVER_BAR_ALPHA)
                self.accentBar:Show()
            end
        end)
        item:SetScript('OnLeave', function(self)
            self.hoverTarget = 0
            ApplyItemState(self)
        end)
        item:SetScript('OnClick', function(self, button)
            if button == 'RightButton' then
                if ms.onContextMenu then safecall(ms.onContextMenu, self.key, self.item, self) end
                return
            end
            if self.key ~= ms.selected then ms:Select(self.key) end
        end)
        item:SetScript('OnDoubleClick', function(self, button)
            if button == 'LeftButton' and self.item and self.item.renamable and ms.onRename then
                ms:BeginRename(self.key)
            end
        end)
        item:RegisterForDrag('LeftButton')
        item:SetScript('OnDragStart', function(self)
            if self.item and self.item.draggable and ms.onMove then BeginDrag(self) end
        end)

        return item
    end

    local function CreateHeader()
        local header = CreateFrame('Button', nil, scrollChild)
        pixel.SetPixelHeight(header, HEADER_HEIGHT)
        header:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

        local hoverBg = header:CreateTexture(nil, 'BACKGROUND')
        hoverBg:SetAllPoints()
        hoverBg:SetColorTexture(1, 1, 1, 0.05)
        hoverBg:SetAlpha(0)
        header.hoverBg = hoverBg

        local dropBg = header:CreateTexture(nil, 'BACKGROUND', nil, 1)
        dropBg:SetAllPoints()
        dropBg:Hide()
        header.dropBg = dropBg

        local arrow = header:CreateTexture(nil, 'OVERLAY')
        pixel.SetPixelSize(arrow, 10, 10)
        arrow:SetTexture(theme.stepperTexture)
        pixel.SetPixelSnap(arrow)
        pixel.SetPixelPoint(arrow, 'LEFT', header, 'LEFT', pad, 0)
        header.arrow = arrow

        local label = header:CreateFontString(nil, 'OVERLAY')
        label:SetJustifyH('LEFT')
        label:SetWordWrap(false)
        pixel.SetPixelPoint(label, 'LEFT', arrow, 'RIGHT', 6, 0)
        pixel.SetPixelPoint(label, 'RIGHT', header, 'RIGHT', -pad, 0)
        header.label = label

        header:SetScript('OnEnter', function(self) self.hoverBg:SetAlpha(1) end)
        header:SetScript('OnLeave', function(self) self.hoverBg:SetAlpha(0) end)
        header:SetScript('OnClick', function(self, button)
            if button == 'RightButton' then
                if ms.onContextMenu then safecall(ms.onContextMenu, self.key, self.item, self) end
                return
            end
            ms:ToggleSection(self.key)
        end)

        return header
    end

    local function CreateLabel()
        local label = CreateFrame('Frame', nil, scrollChild)
        pixel.SetPixelHeight(label, LABEL_HEIGHT)

        local text = label:CreateFontString(nil, 'OVERLAY')
        text:SetJustifyH('LEFT')
        text:SetWordWrap(false)
        pixel.SetPixelPoint(text, 'BOTTOMLEFT', label, 'BOTTOMLEFT', pad, LABEL_TEXT_BOTTOM)
        label.text = text

        return label
    end

    local function CreateContainer()
        local c = CreateFrame('Frame', nil, scrollChild)
        c:SetClipsChildren(true)
        c:SetFrameLevel(scrollChild:GetFrameLevel() + 1)
        return c
    end

    ---Only SweepUnused hides rows, so one that stays on screen is never re-shown and its hover never blinks.
    local function Acquire(pool, create)
        for _, f in ipairs(pool) do
            if not f.inUse then
                f.inUse = true; f:Show(); return f
            end
        end
        local f = create()
        f.inUse = true
        pool[#pool + 1] = f
        return f
    end

    local function ReleaseAll()
        for _, pool in ipairs({ itemPool, headerPool, labelPool, containerPool }) do
            for _, f in ipairs(pool) do f.inUse = false end
        end
        wipe(activeItems); wipe(activeHeaders); wipe(layout)
    end

    local function SweepUnused()
        for _, h in ipairs(headerPool) do
            if not h.inUse and h:IsShown() then
                h.key = nil; h.item = nil
                h.hoverBg:SetAlpha(0); h.dropBg:Hide()
                h:Hide(); h:ClearAllPoints()
            end
        end
        for _, it in ipairs(itemPool) do
            if not it.inUse and it:IsShown() then
                it.key = nil; it.item = nil; it.hoverTarget = 0
                it.hoverBg:SetAlpha(0); it.accentBar:Hide(); it.selectedBg:Hide(); it.barGlow:Hide()
                it:Hide(); it:ClearAllPoints()
            end
        end
        for _, pool in ipairs({ labelPool, containerPool }) do
            for _, f in ipairs(pool) do
                if not f.inUse and f:IsShown() then f:Hide(); f:ClearAllPoints() end
            end
        end
    end

    ---@param host Frame the scroll child, or a section's container
    local function ConfigureItem(item, data, guided, host, yOffset, indent)
        item:SetParent(host)
        item:SetFrameLevel(host:GetFrameLevel() + 2)
        item:ClearAllPoints()
        if yOffset then
            pixel.SetPixelPoint(item, 'TOPLEFT', host, 'TOPLEFT', indent or 0, -yOffset)
            pixel.SetPixelPoint(item, 'TOPRIGHT', host, 'TOPRIGHT', 0, -yOffset)
        end
        item.guide:SetColorTexture(theme.widgetBorder[1], theme.widgetBorder[2], theme.widgetBorder[3], 1)
        item.guide:SetShown(guided == true)
        item.key = data.key
        item.item = data

        gui:ApplyFont(item.label, 'normal')
        item.label:SetText(data.text or '')
        item.label:Show()
        item.label:ClearAllPoints()
        if data.icon then
            local border = data.accent or ICON_BORDER
            item.iconBorder:SetColorTexture(border[1], border[2], border[3], 1)
            item.iconBorder:ClearAllPoints()
            pixel.SetPixelPoint(item.iconBorder, 'LEFT', item, 'LEFT', 6, 0)
            item.iconBorder:Show()
            item.icon:SetTexture(data.icon)
            ApplyIconLook(item.icon, data)
            item.icon:Show()
            pixel.SetPixelPoint(item.label, 'LEFT', item.iconBorder, 'RIGHT', 6, 0)
        else
            item.iconBorder:Hide()
            item.icon:Hide()
            pixel.SetPixelPoint(item.label, 'LEFT', item, 'LEFT', 6, 0)
        end
        pixel.SetPixelPoint(item.label, 'RIGHT', item, 'RIGHT', -pad, 0)

        item.icon:SetDesaturated(data.disabled == true)
        item.icon:SetAlpha(data.disabled and DISABLED_ALPHA or 1)

        ApplyItemState(item)
        if ms.renderItem then safecall(ms.renderItem, item, data, data.key == ms.selected) end
        activeItems[#activeItems + 1] = item
    end

    local function ConfigureLabel(label, data)
        gui:ApplyFont(label.text, 'medium')
        label.text:SetText(data.text or '')
        label.text:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    end

    local function ConfigureHeader(header, data)
        header.key = data.key
        header.item = data

        gui:ApplyFont(header.label, 'normal')
        header.label:SetText(data.text or '')
        header.label:Show()
        header.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        header.arrow:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.7)
        header.dropBg:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], DROP_TINT_ALPHA)
        header.dropBg:SetShown(ms.drag ~= nil and ms.drag.target == data.key and ms.drag.position == 'into')

        activeHeaders[#activeHeaders + 1] = header
    end

    ---@param key any
    ---@return number progress 0 closed .. 1 open
    local function SectionProgress(key)
        local anim = ms.anims[key]
        if anim then return anim.p end
        return ms.expanded[key] and 1 or 0
    end

    local function Place(block, y)
        block:ClearAllPoints()
        pixel.SetPixelPoint(block, 'TOPLEFT', scrollChild, 'TOPLEFT', pad, -y)
        pixel.SetPixelPoint(block, 'TOPRIGHT', scrollChild, 'TOPRIGHT', -pad, -y)
    end

    -- Cheap, so an animating section calls it every frame.
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
                if block.frame.arrow then block.frame.arrow:SetRotation((1 - SectionProgress(block.frame.key)) * mpi / 2) end
                y = y + block.height
            end
        end
        pixel.SetPixelHeight(scrollChild, y + pad)
        UpdateScrollbar()
    end

    ---Walks the tree, rendering it and collecting the selectable leaves in display order.
    local function RenderList()
        EndRename(false)
        ReleaseAll()
        local leaves = {}
        local captioned = false -- items after a caption belong to its section and get the guide line

        -- Keyed buttons lead the leaves, so a host default or remembered key can land on them.
        for _, def in ipairs(ms._buttonsRef or {}) do
            if def.key ~= nil then leaves[#leaves + 1] = def end
        end

        for _, data in ipairs(ms.items or {}) do
            if data.type == 'header' then
                local header = Acquire(headerPool, CreateHeader)
                ConfigureHeader(header, data)
                layout[#layout + 1] = { frame = header, height = HEADER_HEIGHT + ITEM_SPACING }

                -- A closing section keeps its rows until the animation has closed over them.
                local open = ms.expanded[data.key] or ms.anims[data.key]
                local container = open and Acquire(containerPool, CreateContainer)
                local y = 0
                for _, child in ipairs(data.items or {}) do
                    -- Still selectable while closed, so a host restoring a remembered item isn't told it's gone.
                    leaves[#leaves + 1] = child
                    if container then
                        ConfigureItem(Acquire(itemPool, CreateItem), child, true, container, y, ITEM_INDENT)
                        y = y + ITEM_HEIGHT + ITEM_SPACING
                    end
                end
                if container then layout[#layout + 1] = { frame = container, section = data.key, full = y } end
            elseif data.type == 'label' then
                if layout[1] then layout[#layout + 1] = { gap = SECTION_GAP } end
                local label = Acquire(labelPool, CreateLabel)
                ConfigureLabel(label, data)
                layout[#layout + 1] = { frame = label, height = LABEL_HEIGHT + ITEM_SPACING }
                captioned = true
            else
                local item = Acquire(itemPool, CreateItem)
                ConfigureItem(item, data, captioned, scrollChild)
                layout[#layout + 1] = { frame = item, height = ITEM_HEIGHT + ITEM_SPACING }
                leaves[#leaves + 1] = data
            end
        end

        ms.leaves = leaves
        Relayout()
        SweepUnused()
    end

    ---Re-render in place, keeping the current items and expansion state.
    function ms:Render()
        RenderList()
        for _, it in ipairs(activeItems) do ApplyItemState(it) end
    end

    -- Section animation --

    -- Expand eases out (decelerate), collapse eases in (accelerate); a finished section re-renders once.
    local driver = CreateFrame('Frame', nil, frame)
    local function StepAnimations(_, elapsed)
        local finished, running = false, false
        for key, anim in pairs(ms.anims) do
            anim.t = mmin(anim.t + elapsed, anim.duration)
            local x = anim.t / anim.duration
            local eased = anim.to > anim.from and (1 - (1 - x) ^ 3) or x * x
            anim.p = anim.from + (anim.to - anim.from) * eased
            if x >= 1 then
                ms.anims[key] = nil
                finished = true
            else
                running = true
            end
        end

        if not running then driver:SetScript('OnUpdate', nil) end
        if finished then ms:Render() else Relayout() end
    end

    ---Opens or closes a section with the animation, and tells the host so it can remember it.
    ---@param key any
    function ms:ToggleSection(key)
        local expanding = not self.expanded[key]
        -- false, not nil: nil means unseen, and the next SetItems would seed it from defaultExpanded again.
        self.expanded[key] = expanding

        -- Toggling mid-animation turns around from wherever the section currently is.
        local running = self.anims[key]
        local from = running and running.p or (expanding and 0 or 1)
        self.anims[key] = {
            p = from,
            from = from,
            to = expanding and 1 or 0,
            t = 0,
            duration = expanding and EXPAND_DURATION or COLLAPSE_DURATION,
        }
        self:Render()
        driver:SetScript('OnUpdate', StepAnimations)

        if self.onToggle then safecall(self.onToggle, key, expanding) end
    end

    -- Rename in place --

    local renameBox = CreateFrame('EditBox', nil, scrollChild, 'BackdropTemplate')
    renameBox:SetAutoFocus(false)
    renameBox:SetBackdrop(TAB_BACKDROP)
    renameBox:SetTextInsets(4, 4, 0, 0)
    renameBox:Hide()

    local function PaintRenameBorder(failed)
        local edge = failed and theme.error or theme.accent
        renameBox:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], 1)
        renameBox:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
    end

    ---Puts the label back. A render does this first, so the box never sits on a recycled row.
    ---@param commit boolean
    function EndRename(commit)
        local renaming = ms.renaming
        if not renaming then return end

        if commit then
            local text = strtrim(renameBox:GetText() or '')
            local ok = text ~= '' and select(2, safecall(ms.onRename, renaming.key, text, renaming.row.item))
            if ok == false or text == '' then
                PaintRenameBorder(true)
                return
            end
        end

        ms.renaming = nil
        renameBox:ClearFocus()
        renameBox:Hide()
        if renaming.row.key == renaming.key then renaming.row.label:Show() end
    end

    renameBox:SetScript('OnEnterPressed', function() EndRename(true) end)
    renameBox:SetScript('OnEscapePressed', function() EndRename(false) end)
    renameBox:SetScript('OnEditFocusLost', function() EndRename(false) end)
    renameBox:SetScript('OnTextChanged', function(_, userInput)
        if userInput then PaintRenameBorder(false) end
    end)

    ---Swaps the label of an item or section header for an edit box holding its name.
    ---@param key any
    function ms:BeginRename(key)
        if not self.onRename then return end
        EndRename(false)

        local row
        for _, list in ipairs({ activeItems, activeHeaders }) do
            for _, f in ipairs(list) do
                if f.key == key then row = f end
            end
        end
        if not row then return end

        self.renaming = { key = key, row = row }
        gui:ApplyFont(renameBox, 'normal')
        renameBox:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
        PaintRenameBorder(false)
        renameBox:SetParent(row)
        renameBox:SetFrameLevel(row:GetFrameLevel() + 5)
        renameBox:ClearAllPoints()
        pixel.SetPixelHeight(renameBox, row:GetHeight() - 6)
        pixel.SetPixelPoint(renameBox, 'LEFT', row.label, 'LEFT', -4, 0)
        pixel.SetPixelPoint(renameBox, 'RIGHT', row, 'RIGHT', -pad, 0)
        row.label:Hide()
        renameBox:SetText(row.item and row.item.text or '')
        renameBox:Show()
        renameBox:SetFocus()
        renameBox:HighlightText()
    end

    -- Drag and drop --

    local ghost = CreateFrame('Frame', nil, UIParent, 'BackdropTemplate')
    ghost:SetFrameStrata('TOOLTIP')
    ghost:SetBackdrop(TAB_BACKDROP)
    pixel.SetPixelHeight(ghost, ITEM_HEIGHT)
    ghost:Hide()

    local ghostIcon = ghost:CreateTexture(nil, 'ARTWORK')
    pixel.SetPixelSize(ghostIcon, ICON_SIZE - 2, ICON_SIZE - 2)
    pixel.SetPixelPoint(ghostIcon, 'LEFT', ghost, 'LEFT', 7, 0)
    ghostIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)

    local ghostLabel = ghost:CreateFontString(nil, 'OVERLAY')
    ghostLabel:SetJustifyH('LEFT')
    ghostLabel:SetWordWrap(false)

    -- Above the rows, so the insertion line is never covered by a hovered row's background.
    local dropLayer = CreateFrame('Frame', nil, scrollChild)
    dropLayer:SetAllPoints(scrollChild)
    dropLayer:SetFrameLevel(scrollChild:GetFrameLevel() + 20)
    local dropLine = dropLayer:CreateTexture(nil, 'OVERLAY')
    pixel.SetPixelHeight(dropLine, DROP_LINE_HEIGHT)
    pixel.SetPixelSnap(dropLine)
    dropLine:Hide()

    local function ShowDropMark(drag, row)
        dropLine:Hide()
        for _, h in ipairs(activeHeaders) do h.dropBg:SetShown(drag.position == 'into' and h.key == drag.target) end
        if not row or drag.position == 'into' then return end

        -- On the seam between two rows, so before and after a neighbour read as the same spot.
        local edge = drag.position == 'before' and 'TOP' or 'BOTTOM'
        local y = drag.position == 'before' and (ITEM_SPACING + DROP_LINE_HEIGHT) / 2 or -(ITEM_SPACING + DROP_LINE_HEIGHT) / 2
        dropLine:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        dropLine:ClearAllPoints()
        pixel.SetPixelPoint(dropLine, 'LEFT', row, edge .. 'LEFT', 0, y)
        pixel.SetPixelPoint(dropLine, 'RIGHT', row, edge .. 'RIGHT', 0, y)
        dropLine:Show()
    end

    ---The row under the cursor and where on it the drop would go, or nil when no spot is allowed.
    ---@return Frame? row, any target, string? position
    local function FindDropTarget(drag)
        if not scrollFrame:IsMouseOver() then return nil end

        local _, cursorY = GetCursorPosition()
        cursorY = cursorY / scrollChild:GetEffectiveScale()

        local function Allowed(row, position)
            if row.key == drag.key then return false end
            if not ms.canDrop then return true end
            return select(2, safecall(ms.canDrop, drag.item, row.item, position)) == true
        end

        for _, header in ipairs(activeHeaders) do
            if header:IsVisible() and header:IsMouseOver() and Allowed(header, 'into') then
                return header, header.key, 'into'
            end
        end
        for _, row in ipairs(activeItems) do
            if row:IsVisible() and row:IsMouseOver() then
                local top, height = row:GetTop(), row:GetHeight()
                local position = (top - cursorY) < height / 2 and 'before' or 'after'
                if Allowed(row, position) then return row, row.key, position end
            end
        end
        return nil
    end

    local dragFrame = CreateFrame('Frame', nil, frame)

    local function StopDrag()
        local drag = ms.drag
        ms.drag = nil
        dragFrame:SetScript('OnUpdate', nil)
        dragFrame:UnregisterEvent('GLOBAL_MOUSE_UP')
        ghost:EnableKeyboard(false)
        ghost:Hide()
        dropLine:Hide()
        for _, h in ipairs(activeHeaders) do h.dropBg:Hide() end
        for _, it in ipairs(activeItems) do ApplyItemState(it) end
        return drag
    end

    local function StepDrag(_, elapsed)
        local drag = ms.drag
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        ghost:ClearAllPoints()
        ghost:SetPoint('LEFT', UIParent, 'BOTTOMLEFT', x / scale + 12, y / scale)

        local listScale = scrollFrame:GetEffectiveScale()
        local top, bottom = scrollFrame:GetTop(), scrollFrame:GetBottom()
        local cy = y / listScale
        if top and scrollbar:IsShown() and cy <= top and cy >= bottom then
            local step = 0
            if cy > top - SCROLL_EDGE then step = -SCROLL_SPEED * elapsed * (1 - (top - cy) / SCROLL_EDGE) end
            if cy < bottom + SCROLL_EDGE then step = SCROLL_SPEED * elapsed * (1 - (cy - bottom) / SCROLL_EDGE) end
            if step ~= 0 then
                local low, high = scrollbar:GetMinMaxValues()
                scrollbar:SetValue(mmax(low, mmin(high, scrollbar:GetValue() + step)))
            end
        end

        local row, target, position = FindDropTarget(drag)
        if target ~= drag.target then drag.hoverTime = 0 end
        drag.target, drag.position = target, position
        ShowDropMark(drag, row)

        -- Resting on a closed section opens it, so a row can be dropped between its children.
        if position == 'into' and not ms.expanded[target] then
            drag.hoverTime = (drag.hoverTime or 0) + elapsed
            if drag.hoverTime >= OPEN_ON_HOVER then
                drag.hoverTime = 0
                ms:ToggleSection(target)
            end
        end
    end

    dragFrame:SetScript('OnEvent', function(_, _, button)
        if button ~= 'LeftButton' then return end
        local drag = StopDrag()
        if drag and drag.target ~= nil then safecall(ms.onMove, drag.key, drag.target, drag.position) end
    end)

    ghost:SetScript('OnKeyDown', function(self, key)
        if key == 'ESCAPE' then
            self:SetPropagateKeyboardInput(false)
            StopDrag()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    ---@param row Frame the item a drag started on
    function BeginDrag(row)
        EndRename(false)
        local data = row.item
        ms.drag = { key = row.key, item = data }

        ghost:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], 0.95)
        ghost:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        pixel.SetPixelWidth(ghost, row:GetWidth())
        ghostIcon:SetTexture(data.icon)
        ApplyIconLook(ghostIcon, data)
        ghostIcon:SetShown(data.icon ~= nil)
        gui:ApplyFont(ghostLabel, 'normal')
        ghostLabel:SetText(data.text or '')
        ghostLabel:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
        ghostLabel:ClearAllPoints()
        pixel.SetPixelPoint(ghostLabel, 'LEFT', data.icon and ghostIcon or ghost, data.icon and 'RIGHT' or 'LEFT', 6, 0)
        pixel.SetPixelPoint(ghostLabel, 'RIGHT', ghost, 'RIGHT', -pad, 0)
        ghost:Show()
        -- Keyboard capture is protected in combat; Escape simply does not cancel there.
        if not InCombatLockdown() then ghost:EnableKeyboard(true) end

        for _, it in ipairs(activeItems) do ApplyItemState(it) end
        dragFrame:RegisterEvent('GLOBAL_MOUSE_UP')
        dragFrame:SetScript('OnUpdate', StepDrag)
        StepDrag(dragFrame, 0)
    end

    -- A keyed button reads like a content sub-tab: boxed, accent label + tint + underline while selected.
    local function ApplyTabButtonState(tab)
        local sec, pri, ac = theme.textSecondary, theme.textPrimary, theme.accent
        if tab.key == ms.selected then
            tab.label:SetTextColor(ac[1], ac[2], ac[3], 1)
            tab.selectedBg:SetColorTexture(ac[1], ac[2], ac[3], 0.08)
            tab.selectedBg:Show()
            tab.underline:SetColorTexture(ac[1], ac[2], ac[3], 1)
            tab.underline:Show()
            -- VERTICAL runs bottom (first color) to top (second color).
            tab.underGlow:SetGradient('VERTICAL', CreateColor(ac[1], ac[2], ac[3], theme.underlineGlowAlpha), CreateColor(ac[1], ac[2], ac[3], 0))
            tab.underGlow:Show()
        else
            local c = tab:IsMouseOver() and pri or sec
            tab.label:SetTextColor(c[1], c[2], c[3], 1)
            tab.selectedBg:Hide()
            tab.underline:Hide()
            tab.underGlow:Hide()
        end
        tab:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], 1)
        tab:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
    end

    local function CreateTabButton()
        local tab = CreateFrame('Button', nil, buttonArea, 'BackdropTemplate')
        pixel.SetPixelHeight(tab, BUTTON_HEIGHT)
        tab:SetBackdrop(TAB_BACKDROP)
        tab:RegisterForClicks('LeftButtonUp')
        lib.AddTopSheen(tab, gui)
        lib.AddTopHighlight(tab, gui)

        local hoverBg = tab:CreateTexture(nil, 'BACKGROUND')
        hoverBg:SetAllPoints()
        hoverBg:SetColorTexture(1, 1, 1, 0.05)
        hoverBg:Hide()

        local selectedBg = tab:CreateTexture(nil, 'BACKGROUND', nil, 1)
        selectedBg:SetAllPoints()
        selectedBg:Hide()
        tab.selectedBg = selectedBg

        local label = tab:CreateFontString(nil, 'OVERLAY')
        pixel.SetPixelPoint(label, 'CENTER', tab, 'CENTER', 0, 0)
        label:SetWordWrap(false)
        tab.label = label

        local underline = tab:CreateTexture(nil, 'OVERLAY')
        pixel.SetPixelHeight(underline, TAB_UNDERLINE)
        pixel.SetPixelPoint(underline, 'BOTTOMLEFT', tab, 'BOTTOMLEFT', 1, theme.borderSize)
        pixel.SetPixelPoint(underline, 'BOTTOMRIGHT', tab, 'BOTTOMRIGHT', -1, theme.borderSize)
        underline:Hide()
        tab.underline = underline

        local underGlow = tab:CreateTexture(nil, 'ARTWORK')
        underGlow:SetTexture('Interface\\Buttons\\WHITE8X8')
        pixel.SetPixelHeight(underGlow, UNDERLINE_GLOW_HEIGHT)
        pixel.SetPixelPoint(underGlow, 'BOTTOMLEFT', underline, 'TOPLEFT', 0, 0)
        pixel.SetPixelPoint(underGlow, 'BOTTOMRIGHT', underline, 'TOPRIGHT', 0, 0)
        underGlow:Hide()
        tab.underGlow = underGlow

        tab:SetScript('OnEnter', function(self)
            hoverBg:SetShown(self.key ~= ms.selected)
            ApplyTabButtonState(self)
            if self.tooltip then
                GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                GameTooltip:SetText(self.tooltip)
                GameTooltip:Show()
            end
        end)
        tab:SetScript('OnLeave', function(self)
            hoverBg:Hide()
            ApplyTabButtonState(self)
            GameTooltip:Hide()
        end)
        tab:SetScript('OnClick', function(self)
            hoverBg:Hide()
            if self.key ~= ms.selected then ms:Select(self.key) end
        end)

        return tab
    end

    local function LayoutButtons(buttons)
        for _, b in ipairs(buttonPool) do b:Hide() end
        for _, t in ipairs(tabButtonPool) do t:Hide() end
        if not buttons or #buttons == 0 then
            buttonArea:Hide()
            AnchorScroll(false)
            return
        end

        local actions, tabs, y = 0, 0, 0
        for _, def in ipairs(buttons) do
            local btn
            -- A keyed button is a selectable entry that latches, an unkeyed one stays an action.
            if def.key ~= nil then
                tabs = tabs + 1
                btn = tabButtonPool[tabs]
                if not btn then
                    btn = CreateTabButton()
                    tabButtonPool[tabs] = btn
                end
                btn.key = def.key
                btn.tooltip = def.tooltip
                gui:ApplyFont(btn.label, 'normal')
                btn.label:SetText(def.text or '')
                ApplyTabButtonState(btn)
            else
                actions = actions + 1
                btn = buttonPool[actions]
                if not btn then
                    btn = gui:CreateButton(buttonArea, def.text, {
                        height = BUTTON_HEIGHT,
                        callback = def.onClick,
                        tooltip = def.tooltip,
                    })
                    buttonPool[actions] = btn
                else
                    btn:SetLabel(def.text)
                    btn:SetCallback(def.onClick)
                    btn:SetTooltip(def.tooltip)
                end
            end
            btn:Show()
            btn:ClearAllPoints()
            pixel.SetPixelPoint(btn, 'TOPLEFT', buttonArea, 'TOPLEFT', 0, -y)
            pixel.SetPixelPoint(btn, 'TOPRIGHT', buttonArea, 'TOPRIGHT', 0, -y)
            y = y + BUTTON_HEIGHT + BUTTON_SPACING
        end

        -- The separator lands on the band's bottom edge, the content tab strip's baseline.
        pixel.SetPixelHeight(buttonArea, y - BUTTON_SPACING - BUTTON_HEIGHT + theme.barHeight - BAR_INSET)
        buttonArea:Show()
        AnchorScroll(true)
    end

    ---Seeds expansion for any section seen for the first time, so a header's defaultExpanded is
    ---honoured once and the user's own collapsing survives a re-render.
    local function SeedExpansion(items)
        for _, data in ipairs(items or {}) do
            if data.type == 'header' and ms.expanded[data.key] == nil then
                ms.expanded[data.key] = data.defaultExpanded ~= false
            end
        end
    end

    ---Applies a sidebar descriptor and renders the list. Returns the selectable leaves, flattened in
    ---display order, so a host can resolve an initial selection by key without walking the tree.
    ---@param sd table { items: table|fun(): table, width?: number, buttons?: table[], renderItem?: fun(itemFrame, item, selected), onContextMenu?: fun(key, item, itemFrame), onToggle?: fun(key, expanded), onRename?: fun(key, text, item): boolean?, onMove?: fun(key, targetKey, position), canDrop?: fun(item, target, position): boolean }
    ---@return table leaves
    function ms:SetConfig(sd)
        if self.drag then StopDrag() end
        -- Section keys repeat between pages, so each page's descriptor keeps its own open/closed state.
        if self._sd ~= sd then
            self._sd = sd
            sd._expanded = sd._expanded or {}
            self.expanded = sd._expanded
            wipe(self.anims)
        end
        pixel.SetPixelWidth(frame, sd.width or DEFAULT_WIDTH)
        self.renderItem = sd.renderItem
        self.onContextMenu = sd.onContextMenu
        self.onToggle = sd.onToggle
        self.onRename = sd.onRename
        self.onMove = sd.onMove
        self.canDrop = sd.canDrop
        if self._buttonsRef ~= sd.buttons then
            self._buttonsRef = sd.buttons
            LayoutButtons(sd.buttons)
        end
        self.items = type(sd.items) == 'function' and sd.items() or sd.items
        SeedExpansion(self.items)
        RenderList()
        -- On first show this runs before layout has sized the column.
        C_Timer.After(0, UpdateScrollbar)
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

    ---Opens or closes a section from outside, so a host that just added a child can reveal it.
    ---@param key any
    ---@param expanded boolean
    function ms:SetExpanded(key, expanded)
        if (self.expanded[key] == true) == expanded then return end
        self:ToggleSection(key)
    end

    ---Marks an item selected visually without firing onSelect.
    ---@param key any
    function ms:SetSelected(key)
        self.selected = key
        for _, it in ipairs(activeItems) do ApplyItemState(it) end
        for _, tab in ipairs(tabButtonPool) do ApplyTabButtonState(tab) end
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
        -- Same black baseline as the content tab strip; the selected tab's underline carries the accent.
        buttonSeparator:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
        for _, tab in ipairs(tabButtonPool) do
            gui:ApplyFont(tab.label, 'normal')
            ApplyTabButtonState(tab)
        end
    end
    RestyleChrome()
    gui:OnThemeChanged(function()
        RestyleChrome()
        -- Through :Render, so selection colouring is reapplied to the freshly configured rows.
        ms:Render()
    end)

    return ms
end

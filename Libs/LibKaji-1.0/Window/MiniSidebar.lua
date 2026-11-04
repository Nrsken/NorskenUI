--[[
# MiniSidebar

* A left item-list column that a content host places beside its scroll region.
* Owns only the list column: a scrollable list of rows on the panel the module header uses.
* Items are plain data: { key, text, icon? }. renderItem(itemFrame, item, selected) can override the default rendering.
* Items may carry `accent` ({ r, g, b }), which colours the icon border (class colour, say), and `disabled`,
* which dims the row and desaturates its icon. `iconColor` ({ r, g, b, a? }) tints the icon
* and `iconCoords` ({ l, r, t, b }) crops it.
* An item may instead be a section: { type = 'header', key, text, defaultExpanded?, items = { ... } }, which
* renders a collapsible head with its size and a chevron, its children beneath. Sections are one level deep,
* and open and close with an animation. `sd.onToggle(key, expanded)` lets a host remember the state; it
* hands it back as `defaultExpanded`.
* An item may also be a caption: { type = 'label', key, text }, the same head without folding, which titles
* the rows below it, for a flat list whose sections come from more than one source.
* :SetConfig returns only the *selectable leaves*, flattened in display order, so a host can pick an
* initial selection by key without knowing the tree exists.
* `sd.buttons` are the list's first rows. A button def { text, key } is a selectable entry and leads
* the leaves; without a key it's an action row with a +, firing def.onClick.
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
local mmin, mmax, mfloor = math.min, math.max, math.floor
local mpi = math.pi
local C_Timer = C_Timer

local DEFAULT_WIDTH = 192
-- Sizes and steps match the main sidebar's, so this list reads as a small copy of it.
local HEAD_HEIGHT = 28 -- captions and section heads alike
local ITEM_HEIGHT = 26
local ITEM_SPACING = 1
local TEXT_INSET = 8 -- heads and rows outside any head, from the panel's edge
local ROW_STEP = 8 -- a head's rows step in to its text, so their bar sits under it
local STEPPED_TEXT = 12 -- those rows' text from their bar
local CHEVRON_SIZE = 10
local GLYPH_SIZE = 10 -- an action row's +
local HOVER_LIGHTEN = 0.6 -- how far a hovered label goes toward textPrimary, as in the sidebar
local HOVER_FADE = 0.15 -- a section head's hover crossfade, as long as the rows' selection fade
local EXPAND_DURATION = 0.2
local COLLAPSE_DURATION = 0.15
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
local SECTION_GAP = 8 -- above a head that follows rows; folded sections stack without it
local BOX_BACKDROP = { bgFile = 'Interface\\Buttons\\WHITE8X8', edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 }

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

    local frame = CreateFrame('Frame', nil, parent)
    pixel.SetPixelWidth(frame, DEFAULT_WIDTH)

    -- a panel like the module header's, inset as it is; flush right, where the page's own card inset is the gap
    local panel = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
    pixel.SetPixelPoint(panel, 'TOPLEFT', frame, 'TOPLEFT', pad, -pad)
    pixel.SetPixelPoint(panel, 'BOTTOMRIGHT', frame, 'BOTTOMRIGHT', 0, pad)
    local RestyleChrome = lib.CreatePanelChrome(panel, gui)

    local scrollFrame = CreateFrame('ScrollFrame', nil, panel)
    scrollFrame:SetFrameLevel(panel:GetFrameLevel() + 5)
    scrollFrame:SetClipsChildren(true)
    -- inside the panel's border, which the list would otherwise scroll over
    pixel.SetPixelPoint(scrollFrame, 'TOPLEFT', panel, 'TOPLEFT', theme.borderSize, -theme.borderSize)
    pixel.SetPixelPoint(scrollFrame, 'BOTTOMRIGHT', panel, 'BOTTOMRIGHT', -theme.borderSize, theme.borderSize)

    local scrollChild = CreateFrame('Frame', nil, scrollFrame)
    pixel.SetPixelHeight(scrollChild, 1)
    scrollChild:SetFrameLevel(scrollFrame:GetFrameLevel() + 1)
    scrollFrame:SetScrollChild(scrollChild)

    local scrollbar = gui:CreateScrollbar(scrollFrame, {
        width = theme.scrollbarWidth,
        thumbHeight = 40,
        -- Flush with the panel's edge, so the track's own border lies on the panel's.
        padding = { top = 0, bottom = 0, right = 0 },
        scrollStep = 40,
    })

    local scrollbarVisible = false
    local function UpdateScrollChildWidth()
        local w = panel:GetWidth()
        if not w or w <= 0 then return end
        pixel.SetPixelWidth(scrollChild, scrollbarVisible and (w - theme.scrollbarWidth - theme.borderSize) or (w - theme.borderSize * 2))
    end
    local function UpdateScrollbar()
        scrollbarVisible = scrollbar:UpdateVisibility(scrollChild:GetHeight(), scrollFrame:GetHeight())
        UpdateScrollChildWidth()
        -- A scroll child resized before its ScrollFrame has a rect is not redrawn once the rect resolves.
        scrollFrame:UpdateScrollChildRect()
    end
    scrollChild:HookScript('OnSizeChanged', UpdateScrollbar)
    scrollFrame:HookScript('OnSizeChanged', UpdateScrollbar)
    scrollFrame:HookScript('OnShow', function() UpdateScrollbar() end)
    panel:HookScript('OnSizeChanged', UpdateScrollChildWidth)

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

    local BeginDrag, EndRename -- defined with their features below

    ---An item's label: textSecondary at rest, lightening while hovered, the accent as it's selected.
    ---SetTextColor's alpha overrides FontString:SetAlpha, so the disabled dim rides on the colour.
    local function PaintLabel(item)
        local l, h = lib.RowSelectionProgress(item)
        local rest, hi, ac = theme.textSecondary, theme.textPrimary, theme.accent
        local r = rest[1] + (hi[1] - rest[1]) * h * HOVER_LIGHTEN
        local g = rest[2] + (hi[2] - rest[2]) * h * HOVER_LIGHTEN
        local b = rest[3] + (hi[3] - rest[3]) * h * HOVER_LIGHTEN
        local alpha = item.item and item.item.disabled and DISABLED_ALPHA or 1
        item.label:SetTextColor(r + (ac[1] - r) * l, g + (ac[2] - g) * l, b + (ac[3] - b) * l, alpha)
    end

    ---@param instant? boolean snap instead of crossfading, for a row just rendered or reconfigured
    local function ApplyItemState(item, instant)
        local selected = item.key == ms.selected
        lib.SetRowSelection(item, theme, selected and 1 or 0, item.hovered and not selected and 1 or 0, instant)
        if instant then
            PaintLabel(item)
        end
        item:SetAlpha(ms.drag and ms.drag.key == item.key and DRAG_SOURCE_ALPHA or 1)
    end

    local function CreateItem()
        local item = CreateFrame('Button', nil, scrollChild)
        pixel.SetPixelHeight(item, ITEM_HEIGHT)
        item:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

        lib.CreateRowSelection(item, theme)

        local glyph = item:CreateTexture(nil, 'ARTWORK')
        pixel.SetPixelSize(glyph, GLYPH_SIZE, GLYPH_SIZE)
        pixel.SetPixelPoint(glyph, 'LEFT', item, 'LEFT', TEXT_INSET, 0)
        pixel.SetPixelSnap(glyph)
        glyph:SetTexture(theme.plusTexture)
        glyph:Hide()
        item.glyph = glyph

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

        item:SetScript('OnUpdate', function(self, elapsed)
            if lib.StepRowSelection(self, theme, elapsed) then
                PaintLabel(self)
            end
        end)
        item:SetScript('OnEnter', function(self)
            self.hovered = true
            ApplyItemState(self)
        end)
        item:SetScript('OnLeave', function(self)
            self.hovered = nil
            ApplyItemState(self)
        end)
        item:SetScript('OnClick', function(self, button)
            if button == 'RightButton' then
                if ms.onContextMenu then safecall(ms.onContextMenu, self.key, self.item, self) end
                return
            end
            if self.item and self.item.action then
                safecall(self.item.action)
            elseif self.key ~= ms.selected then
                ms:Select(self.key)
            end
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

    ---A section's accent title whitens while hovered, the hint that it folds, as the main sidebar's headers; no wash behind it.
    local function PaintHeader(header)
        local p = header.lit
        p = p * p * (3 - 2 * p) -- the rows' selection eases the same way
        local rest, hot = theme.accent, theme.textPrimary
        local dim, lit = theme.textMuted, theme.textPrimary
        header.label:SetTextColor(rest[1] + (hot[1] - rest[1]) * p, rest[2] + (hot[2] - rest[2]) * p, rest[3] + (hot[3] - rest[3]) * p, 1)
        header.arrow:SetVertexColor(dim[1] + (lit[1] - dim[1]) * p, dim[2] + (lit[2] - dim[2]) * p, dim[3] + (lit[3] - dim[3]) * p, 1)
    end

    local function StepHeader(header, elapsed)
        local step = elapsed / HOVER_FADE
        header.lit = header.litTo > header.lit and mmin(header.lit + step, 1) or mmax(header.lit - step, 0)
        PaintHeader(header)
        if header.lit == header.litTo then
            header:SetScript('OnUpdate', nil)
        end
    end

    ---@param on boolean
    local function FadeHeader(header, on)
        header.litTo = on and 1 or 0
        header:SetScript('OnUpdate', StepHeader)
    end

    local function CreateHeader()
        local header = CreateFrame('Button', nil, scrollChild)
        pixel.SetPixelHeight(header, HEAD_HEIGHT)
        header:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

        local dropBg = header:CreateTexture(nil, 'BACKGROUND', nil, 1)
        dropBg:SetAllPoints()
        dropBg:Hide()
        header.dropBg = dropBg

        local label = header:CreateFontString(nil, 'OVERLAY')
        label:SetJustifyH('LEFT')
        label:SetWordWrap(false)
        pixel.SetPixelPoint(label, 'LEFT', header, 'LEFT', TEXT_INSET, 0)
        header.label = label

        -- the section's size reads on after its name
        local count = header:CreateFontString(nil, 'OVERLAY')
        pixel.SetPixelPoint(count, 'BOTTOMLEFT', label, 'BOTTOMRIGHT', 6, 1)
        header.count = count

        local arrow = header:CreateTexture(nil, 'OVERLAY')
        pixel.SetPixelSize(arrow, CHEVRON_SIZE, CHEVRON_SIZE)
        arrow:SetTexture(theme.stepperTexture)
        pixel.SetPixelSnap(arrow)
        pixel.SetPixelPoint(arrow, 'RIGHT', header, 'RIGHT', -TEXT_INSET, 0)
        header.arrow = arrow
        header.lit, header.litTo = 0, 0

        header:SetScript('OnEnter', function(self) FadeHeader(self, true) end)
        header:SetScript('OnLeave', function(self) FadeHeader(self, false) end)
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
        pixel.SetPixelHeight(label, HEAD_HEIGHT)

        local text = label:CreateFontString(nil, 'OVERLAY')
        text:SetJustifyH('LEFT')
        text:SetWordWrap(false)
        pixel.SetPixelPoint(text, 'LEFT', label, 'LEFT', TEXT_INSET, 0)
        label.text = text

        return label
    end

    -- a head's rows: clipped so a folding section slides
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
                h.lit, h.litTo = 0, 0
                h:SetScript('OnUpdate', nil)
                h.dropBg:Hide()
                h:Hide(); h:ClearAllPoints()
            end
        end
        for _, it in ipairs(itemPool) do
            if not it.inUse and it:IsShown() then
                it.key = nil; it.item = nil; it.hovered = nil
                lib.SetRowSelection(it, theme, 0, 0, true)
                it:Hide(); it:ClearAllPoints()
            end
        end
        for _, pool in ipairs({ labelPool, containerPool }) do
            for _, f in ipairs(pool) do
                if not f.inUse and f:IsShown() then f:Hide(); f:ClearAllPoints() end
            end
        end
    end

    ---@param host Frame the scroll child or a head's container
    ---@param yOffset? number a head's row's place in its container; the scroll child's rows are placed by Relayout
    local function ConfigureItem(item, data, host, yOffset)
        item:SetParent(host)
        item:SetFrameLevel(host:GetFrameLevel() + 2)
        item:ClearAllPoints()
        if yOffset then
            pixel.SetPixelPoint(item, 'TOPLEFT', host, 'TOPLEFT', 0, -yOffset)
            pixel.SetPixelPoint(item, 'TOPRIGHT', host, 'TOPRIGHT', 0, -yOffset)
        end
        item.key = data.key
        item.item = data
        local inset = yOffset and STEPPED_TEXT or TEXT_INSET

        gui:ApplyFont(item.label, 'normal')
        item.label:SetText(data.text or '')
        item.label:Show()
        item.label:ClearAllPoints()
        item.glyph:SetShown(data.action ~= nil)
        if data.action then
            local ac = theme.accent
            item.glyph:ClearAllPoints()
            pixel.SetPixelPoint(item.glyph, 'LEFT', item, 'LEFT', inset, 0)
            item.glyph:SetVertexColor(ac[1], ac[2], ac[3], 1)
            item.iconBorder:Hide()
            item.icon:Hide()
            pixel.SetPixelPoint(item.label, 'LEFT', item.glyph, 'RIGHT', 6, 0)
        elseif data.icon then
            local border = data.accent or ICON_BORDER
            item.iconBorder:SetColorTexture(border[1], border[2], border[3], 1)
            item.iconBorder:ClearAllPoints()
            pixel.SetPixelPoint(item.iconBorder, 'LEFT', item, 'LEFT', inset, 0)
            item.iconBorder:Show()
            item.icon:SetTexture(data.icon)
            ApplyIconLook(item.icon, data)
            item.icon:Show()
            pixel.SetPixelPoint(item.label, 'LEFT', item.iconBorder, 'RIGHT', 6, 0)
        else
            item.iconBorder:Hide()
            item.icon:Hide()
            pixel.SetPixelPoint(item.label, 'LEFT', item, 'LEFT', inset, 0)
        end
        pixel.SetPixelPoint(item.label, 'RIGHT', item, 'RIGHT', -pad, 0)

        item.icon:SetDesaturated(data.disabled == true)
        item.icon:SetAlpha(data.disabled and DISABLED_ALPHA or 1)

        ApplyItemState(item, true)
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

        local muted = theme.textMuted
        gui:ApplyFont(header.count, 'normal')
        header.count:SetText(#(data.items or {}))
        header.count:SetTextColor(muted[1], muted[2], muted[3], 1)

        -- a long name stops short of the count and chevron instead of running under them
        gui:ApplyFont(header.label, 'medium')
        header.label:SetWidth(0)
        header.label:SetText(data.text or '')
        header.label:Show()
        local gaps = 6 * 2 + TEXT_INSET -- before the count, before the chevron and the chevron's own inset
        local room = scrollChild:GetWidth() - TEXT_INSET - header.count:GetStringWidth() - CHEVRON_SIZE - gaps
        if room > 0 and header.label:GetStringWidth() > room then
            pixel.SetPixelWidth(header.label, room)
        end
        PaintHeader(header)
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

    -- flush with the panel's border, so the selection's bar sits on the panel's edge; a head's rows step in
    local function Place(block, y, x)
        block:ClearAllPoints()
        pixel.SetPixelPoint(block, 'TOPLEFT', scrollChild, 'TOPLEFT', x or 0, -y)
        pixel.SetPixelPoint(block, 'TOPRIGHT', scrollChild, 'TOPRIGHT', 0, -y)
    end

    local function AcquireGroup()
        return Acquire(containerPool, CreateContainer)
    end

    -- Cheap, so an animating section calls it every frame.
    local function Relayout()
        local y = pad
        for _, block in ipairs(layout) do
            if block.gap then
                -- a gap under a section opens and closes with it
                y = y + mfloor(block.gap * (block.after and SectionProgress(block.after) or 1) + 0.5)
            elseif block.full then
                -- a caption's rows never fold, a section's follow its animation
                local height = mfloor(block.full * (block.section and SectionProgress(block.section) or 1) + 0.5)
                Place(block.frame, y, ROW_STEP)
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

        -- Buttons are the first rows; keyed ones lead the leaves, so a host default or remembered key can land on them.
        for _, def in ipairs(ms.buttons or {}) do
            local data = def
            if def.key == nil then
                data = { key = def, text = def.text, action = def.onClick or function() end }
            else
                leaves[#leaves + 1] = def
            end
            local item = Acquire(itemPool, CreateItem)
            ConfigureItem(item, data, scrollChild)
            layout[#layout + 1] = { frame = item, height = ITEM_HEIGHT + ITEM_SPACING }
        end

        -- what sits above the next head: plain rows get the full gap, a section's rows a gap that folds with them
        local afterRows = ms.buttons ~= nil and ms.buttons[1] ~= nil
        local afterSection
        local captionGroup -- the rows after a caption, stepped in until the next head
        for _, data in ipairs(ms.items or {}) do
            if data.type == 'header' or data.type == 'label' then
                if afterRows then
                    layout[#layout + 1] = { gap = SECTION_GAP }
                elseif afterSection then
                    layout[#layout + 1] = { gap = SECTION_GAP, after = afterSection }
                end
                afterRows = false
                afterSection = data.type == 'header' and data.items and data.items[1] and data.key or nil
                captionGroup = nil
            else
                afterRows, afterSection = true, nil
            end

            if data.type == 'header' then
                local header = Acquire(headerPool, CreateHeader)
                ConfigureHeader(header, data)
                layout[#layout + 1] = { frame = header, height = HEAD_HEIGHT + ITEM_SPACING }

                -- A closing section keeps its rows until the animation has closed over them.
                local open = ms.expanded[data.key] or ms.anims[data.key]
                local container = open and AcquireGroup()
                local y = 0
                local children = data.items or {}
                for _, child in ipairs(children) do
                    -- Still selectable while closed, so a host restoring a remembered item isn't told it's gone.
                    leaves[#leaves + 1] = child
                    if container then
                        ConfigureItem(Acquire(itemPool, CreateItem), child, container, y)
                        y = y + ITEM_HEIGHT + ITEM_SPACING
                    end
                end
                if container then layout[#layout + 1] = { frame = container, section = data.key, full = y } end
            elseif data.type == 'label' then
                local label = Acquire(labelPool, CreateLabel)
                ConfigureLabel(label, data)
                layout[#layout + 1] = { frame = label, height = HEAD_HEIGHT + ITEM_SPACING }
                captionGroup = { frame = AcquireGroup(), full = 0 }
                layout[#layout + 1] = captionGroup
            elseif captionGroup then
                ConfigureItem(Acquire(itemPool, CreateItem), data, captionGroup.frame, captionGroup.full)
                captionGroup.full = captionGroup.full + ITEM_HEIGHT + ITEM_SPACING
                leaves[#leaves + 1] = data
            else
                local item = Acquire(itemPool, CreateItem)
                ConfigureItem(item, data, scrollChild)
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
        for _, it in ipairs(activeItems) do
            ApplyItemState(it, true)
        end
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
    renameBox:SetBackdrop(BOX_BACKDROP)
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
    ghost:SetBackdrop(BOX_BACKDROP)
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
        self.buttons = sd.buttons
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
    ---@param animate? boolean crossfade, for a click; a page opening on its remembered item snaps
    function ms:SetSelected(key, animate)
        self.selected = key
        for _, it in ipairs(activeItems) do
            ApplyItemState(it, not animate)
        end
    end

    ---Selects an item and fires onSelect.
    ---@param key any
    function ms:Select(key)
        self:SetSelected(key, true)
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

    gui:OnThemeChanged(function()
        RestyleChrome()
        -- Through :Render, so selection colouring is reapplied to the freshly configured rows.
        ms:Render()
    end)

    return ms
end

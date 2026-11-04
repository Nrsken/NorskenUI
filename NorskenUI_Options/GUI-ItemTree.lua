---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
local L = NRSKNUI.Libs.AL
local Kaji = NRSKNUI.Libs.KAJI

local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local InCombatLockdown = InCombatLockdown
local GameTooltip = GameTooltip
local UIParent = UIParent
local ipairs, pairs, next, select = ipairs, pairs, next, select
local wipe = wipe
local IsShiftKeyDown, IsControlKeyDown = IsShiftKeyDown, IsControlKeyDown
local mmin = math.min
local strtrim = strtrim
local strlower = string.lower
local strfind = string.find
local format = string.format
local mmax = math.max
local floor = math.floor
local tremove = table.remove
local C_Timer = C_Timer
local pi = math.pi

local MEDIA = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\'
local WHITE = 'Interface\\Buttons\\WHITE8X8'
local BOX_BACKDROP = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }

local WIDTH = 260
local ROW_HEIGHT = 32
local ROW_GAP = 2
local SECTION_HEIGHT = 22
local CHILD_INDENT = 9
local ARROW_SIZE = 10 -- even, so the ungroup arrow centres on the 32px row without a half pixel
local ICON_SIZE = ROW_HEIGHT - 2 -- a pixel clear of the row's top and bottom, where the selection draws its lines
local ICON_CROP = 0.08
local SMALL_BUTTON = 14
local DOT_SIZE = 8
local DISABLED_ALPHA = 0.45
local DRAG_SOURCE_ALPHA = 0.35
local ACCENT_BAR_WIDTH = 2
local EXPAND_DURATION = 0.2
local COLLAPSE_DURATION = 0.15

-- collapse.tga points down at rotation 0.
local ARROW_UP, ARROW_LEFT = pi, -pi / 2

local STATE_COLORS = { loaded = 'success', standby = 'warning', unloaded = 'textMuted' }
local STATE_TEXT = {
    loaded = { L['Loaded'], L['This display is currently loaded'] },
    standby = { L['Standby'], L['This display is on standby, it will be loaded when needed.'] },
    unloaded = { L['Not Loaded'], L['This display is not currently loaded'] },
}

-- Kaji's tooltip look: accent title, secondary body, beside the cursor.
---@param owner Frame
---@param title string
---@param text string?
local function ShowTooltip(owner, title, text)
    local theme = NRSKNUI.Theme
    local accent, secondary = theme.accent, theme.textSecondary
    GameTooltip:SetOwner(owner, 'ANCHOR_CURSOR_RIGHT', 30, 0)
    GameTooltip:SetText(title, accent[1], accent[2], accent[3], 1, false)
    if text then GameTooltip:AddLine(text, secondary[1], secondary[2], secondary[3], true) end
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

---A small textured button with its own tooltip and click handler.
---@param parent Frame
---@param texture string
---@param size number
---@return CDMTreeSmallButton
local function SmallButton(parent, texture, size)
    local button = CreateFrame('Button', nil, parent) --[[@as CDMTreeSmallButton]]
    button:NUISetPixelSize(size, size)
    local tex = button:CreateTexture(nil, 'ARTWORK')
    tex:NUISetPixelSnap()
    tex:SetAllPoints()
    tex:SetTexture(texture)
    button.tex = tex
    button:SetScript('OnEnter', function(self)
        if self.tipTitle then ShowTooltip(self, self.tipTitle, self.tipText) end
    end)
    button:SetScript('OnLeave', HideTooltip)
    return button
end

--[[
The collection list: a page's own things (CDM displays, BigWigs timers) as icon rows in banded sections,
a ContentArea column picked with `sidebar.create = NRSKNUI.CreateItemTree`. Navigation pages use Kaji's
MiniSidebar instead.

`sd.items()` returns { general?, sections = { { key, text, collapsed, rows, preview? } } }.
A row is { key, text, icon, depth, enabled }, plus what it has:
* `loadState` ('loaded'|'standby'|'unloaded') draws the state dot, `stateTitle` / `stateText` word its tooltip
* `preview` (0|1|2) draws the eye, `isGroup` with `children` folds, `canMoveUp` / `canMoveDown` reorder in a group
* children only get the ungroup arrow with `sd.onUngroup`; a `fixed` child has no reorder column at all
* `sd.onPicksChanged()` runs after a Ctrl/Shift click changes the multi selection without moving the shown row
A section's `preview` draws its eye; one without `text` has no band.
]]

---Creates a collection tree, a ContentArea column.
---@param gui KajiGUIInstance
---@param parent Frame
---@param opts table { onSelect: fun(key: string, item: table) }
---@return table tree
local function CreateTree(gui, parent, opts)
    local theme = gui.theme
    local pad = theme.paddingSmall
    local onSelect = opts.onSelect

    local frame = CreateFrame('Frame', nil, parent)
    frame:NUISetPixelWidth(WIDTH)

    -- the page list's panel, inset as it is: flush right, where the page's own card inset is the gap
    local panel = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
    panel:NUISetPixelPoint('TOPLEFT', frame, 'TOPLEFT', pad, -pad)
    panel:NUISetPixelPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', 0, pad)
    local RestylePanel = Kaji.CreatePanelChrome(panel, gui)

    local tree = {
        frame = frame,
        selected = nil,
        picked = {},  -- [key] = true, every selected row; ctrl and shift click add to it
        rowKeys = {}, -- [key] = true, every display row, collapsed ones included
        order = {},   -- drawn row keys top to bottom, for shift click ranges
        leaves = {},
        search = '',
        anims = {}, -- [key] = { p, from, to, t, duration }, a group or section opening or closing
    }

    -- Search --

    -- the window sidebar's search, placed the same way at the top of the panel
    local searchBox = gui:CreateSearchBox(panel, {
        onChanged = function(text)
            tree.search = strlower(strtrim(text))
            tree:Render(true)
        end,
    })
    ---The scrollbar's track runs the panel's full height, so the search steps aside for it.
    ---@param scrollbarShown boolean
    local function AnchorSearch(scrollbarShown)
        searchBox:ClearAllPoints()
        searchBox:NUISetPixelPoint('TOPLEFT', panel, 'TOPLEFT', theme.borderSize, -theme.borderSize)
        searchBox:NUISetPixelPoint('TOPRIGHT', panel, 'TOPRIGHT', -(scrollbarShown and theme.scrollbarWidth or theme.borderSize), -theme.borderSize)
    end
    AnchorSearch(false)

    -- List --

    -- inside the panel's border, which the list would otherwise scroll over; the window sidebar's rows start
    -- a padding under its search, these sections start flush, so the gap is made here
    local scrollFrame = CreateFrame('ScrollFrame', nil, panel)
    scrollFrame:SetClipsChildren(true)
    scrollFrame:NUISetPixelPoint('TOPLEFT', searchBox, 'BOTTOMLEFT', 0, -pad)
    scrollFrame:NUISetPixelPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', -theme.borderSize, theme.borderSize)

    local scrollChild = CreateFrame('Frame', nil, scrollFrame)
    scrollChild:NUISetPixelHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    local scrollbar = gui:CreateScrollbar(scrollFrame, {
        width = theme.scrollbarWidth,
        thumbHeight = 40,
        padding = { top = 0, bottom = 0, right = 0 },
        scrollStep = 40,
    })

    local scrollbarVisible = false
    local function UpdateScrollbar()
        local visible = scrollbar:UpdateVisibility(scrollChild:GetHeight(), scrollFrame:GetHeight())
        if visible ~= scrollbarVisible then
            scrollbarVisible = visible
            AnchorSearch(visible)
        end
        local w = scrollFrame:GetWidth()
        if w and w > 0 then
            scrollChild:NUISetPixelWidth(w - (scrollbarVisible and theme.scrollbarWidth or 0))
        end
        scrollFrame:UpdateScrollChildRect()
    end
    scrollFrame:HookScript('OnSizeChanged', UpdateScrollbar)
    frame:HookScript('OnSizeChanged', UpdateScrollbar)

    local rowPool, activeRows = {}, {}
    local sectionPool, activeSections = {}, {}
    local BeginDrag, EndRename

    -- Rows --

    ---@param row CDMTreeRow
    ---@param instant? boolean snap, for a row just configured; selection and hover changes crossfade
    local function ApplyRowState(row, instant)
        local data = row.data
        local alpha = data.enabled and 1 or DISABLED_ALPHA
        local selected = data.key == tree.selected or tree.picked[data.key]
        local hovered = not selected and row.hovered
        Kaji.SetRowSelection(row, theme, selected and 1 or 0, hovered and 1 or 0, instant)
        local c = selected and theme.accent or hovered and theme.textPrimary or theme.textSecondary
        row.title:SetTextColor(c[1], c[2], c[3], alpha)
        local dragged = tree.drag and tree.drag.moving[data.key]
        row:SetAlpha(dragged and DRAG_SOURCE_ALPHA or tree.locked and DISABLED_ALPHA or 1)
    end

    ---@return CDMTreeRow
    local function CreateRow()
        local row = CreateFrame('Button', nil, scrollChild) --[[@as CDMTreeRow]]
        row:NUISetPixelHeight(ROW_HEIGHT)
        row:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
        row:RegisterForDrag('LeftButton')

        row.bg = row:CreateTexture(nil, 'BACKGROUND')
        row.bg:SetColorTexture(1, 1, 1, 0.03)

        -- the sidebars' selection, its bar moved onto the indented background in ConfigureRow
        Kaji.CreateRowSelection(row, theme)
        row:SetScript('OnUpdate', function(self, elapsed)
            Kaji.StepRowSelection(self, theme, elapsed)
        end)

        row.dropFill = row:CreateTexture(nil, 'BACKGROUND', nil, 3)
        row.dropFill:Hide()

        -- Reorder column for icons inside a group: up, out of the group, down.
        row.up = SmallButton(row, theme.stepperTexture, ARROW_SIZE)
        row.up.tex:SetRotation(ARROW_UP)
        row.up.tipTitle, row.up.tipText = L['Move Up'], L["Move this display up in its group's order"]
        row.up:SetScript('OnClick', function() tree.sd.onMoveInGroup(row.data.key, -1) end)

        row.ungroup = SmallButton(row, theme.stepperTexture, ARROW_SIZE)
        row.ungroup.tex:SetRotation(ARROW_LEFT)
        row.ungroup.tipTitle, row.ungroup.tipText = L['Ungroup'], L['Remove this display from its group']
        row.ungroup:SetScript('OnClick', function() tree.sd.onUngroup(row.data.key) end)

        row.down = SmallButton(row, theme.stepperTexture, ARROW_SIZE)
        row.down.tipTitle, row.down.tipText = L['Move Down'], L["Move this display down in its group's order"]
        row.down:SetScript('OnClick', function() tree.sd.onMoveInGroup(row.data.key, 1) end)

        row.iconBorder = row:CreateTexture(nil, 'ARTWORK', nil, -1)
        row.iconBorder:NUISetPixelSnap()
        row.iconBorder:NUISetPixelSize(ICON_SIZE, ICON_SIZE)
        row.iconBorder:SetColorTexture(0, 0, 0, 1)

        row.icon = row:CreateTexture(nil, 'ARTWORK')
        row.icon:NUISetPixelSnap()
        row.icon:NUISetPixelSize(ICON_SIZE - 2, ICON_SIZE - 2)
        row.icon:NUISetPixelPoint('CENTER', row.iconBorder, 'CENTER', 0, 0)
        row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)

        -- A display's WeakAuras-style picture (a mini bar, a group's blocks), drawn over the icon square.
        row.canvas = CreateFrame('Frame', nil, row)
        row.canvas:NUISetPixelSize(ICON_SIZE - 2, ICON_SIZE - 2)
        row.canvas:NUISetPixelPoint('CENTER', row.iconBorder, 'CENTER', 0, 0)

        row.title = row:CreateFontString(nil, 'OVERLAY')
        row.title:SetJustifyH('LEFT')
        row.title:SetWordWrap(false)

        row.expand = SmallButton(row, MEDIA .. 'plus-sign.png', SMALL_BUTTON - 2)
        row.expand:SetScript('OnClick', function()
            local data = row.data
            tree:ToggleExpanded(data.key, not data.expanded)
        end)

        row.state = SmallButton(row, MEDIA .. 'whiteCircle.png', DOT_SIZE)

        row.eye = SmallButton(row, MEDIA .. 'eye.png', SMALL_BUTTON + 2)
        row.eye.tipTitle, row.eye.tipText = L['View'], L['Toggle the visibility of this display']
        row.eye:SetScript('OnClick', function() tree.sd.onTogglePreview(row.data.key) end)

        row:SetScript('OnEnter', function(self)
            self.hovered = true
            ApplyRowState(self)
            if self.data.tooltip then
                GameTooltip:SetOwner(self, 'ANCHOR_NONE')
                GameTooltip:ClearAllPoints()
                GameTooltip:SetPoint('LEFT', self, 'RIGHT', 4, 0)
                self.data.tooltip(GameTooltip)
                GameTooltip:Show()
            end
        end)
        row:SetScript('OnLeave', function(self)
            self.hovered = nil
            ApplyRowState(self)
            HideTooltip()
        end)
        row:SetScript('OnClick', function(self, button)
            local key = self.data.key
            if button == 'RightButton' then
                if tree.locked then return end
                local picked = tree:GetPicked()
                if tree.picked[key] and #picked > 1 and tree.sd.onMultiContextMenu then
                    tree.sd.onMultiContextMenu(picked)
                elseif tree.sd.onContextMenu then
                    tree.sd.onContextMenu(key, self.data)
                end
                return
            end
            -- Shift/Ctrl multi select, from a display that is already selected.
            local anchor = tree.rowKeys[tree.selected] and tree.selected
            if anchor and IsShiftKeyDown() then
                tree:PickRange(anchor, key)
                return
            elseif anchor and IsControlKeyDown() then
                tree:TogglePick(key)
                return
            end
            -- Clicking the selected row again clears the selection, back to the general page or to none.
            tree:Select(key ~= tree.selected and key or tree.generalKey)
        end)
        row:SetScript('OnDragStart', function(self)
            if self.data.draggable and tree.sd.onMove and not tree.locked then BeginDrag(self) end
        end)

        return row
    end

    local function HideRegions(...)
        for i = 1, select('#', ...) do
            (select(i, ...)):Hide()
        end
    end

    ---@param row CDMTreeRow
    ---@param data table
    local function ConfigureRow(row, data)
        row.data = data

        local child = data.depth > 0
        local left = child and data.depth * CHILD_INDENT or 1

        row.bg:ClearAllPoints()
        row.bg:NUISetPixelPoint('TOPLEFT', row, 'TOPLEFT', left, 0)
        row.bg:NUISetPixelPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 0, 0)
        local bar = row.selection.bar
        bar:ClearAllPoints()
        bar:NUISetPixelPoint('TOPLEFT', row.bg, 'TOPLEFT', 0, 0)
        bar:NUISetPixelPoint('BOTTOMLEFT', row.bg, 'BOTTOMLEFT', 0, 0)

        local muted = theme.textMuted
        local reorder = child and not data.fixed
        for _, arrow in ipairs({ row.up, row.ungroup, row.down }) do
            -- only a page whose rows can leave their group gets the middle arrow
            arrow:SetShown(reorder and (arrow ~= row.ungroup or tree.sd.onUngroup ~= nil))
            arrow.tex:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
        end
        row.iconBorder:ClearAllPoints()
        if reorder then
            row.up:ClearAllPoints(); row.ungroup:ClearAllPoints(); row.down:ClearAllPoints()
            row.up:NUISetPixelPoint('TOPLEFT', row.bg, 'TOPLEFT', 0, 0)
            row.ungroup:NUISetPixelPoint('LEFT', row.bg, 'LEFT', 0, 0)
            row.down:NUISetPixelPoint('BOTTOMLEFT', row.bg, 'BOTTOMLEFT', 0, 0)
            row.up:SetEnabled(not tree.locked and data.canMoveUp == true)
            row.down:SetEnabled(not tree.locked and data.canMoveDown == true)
            row.ungroup:SetEnabled(not tree.locked)
            if not data.canMoveUp then row.up.tex:SetVertexColor(muted[1], muted[2], muted[3], 0.4) end
            if not data.canMoveDown then row.down.tex:SetVertexColor(muted[1], muted[2], muted[3], 0.4) end
            row.iconBorder:NUISetPixelPoint('LEFT', row.bg, 'LEFT', ARROW_SIZE + 2, 0)
        else
            -- a pixel past the selection bar, so the bar and the icon read as one edge
            row.iconBorder:NUISetPixelPoint('LEFT', row.bg, 'LEFT', ACCENT_BAR_WIDTH + 1, 0)
        end

        row.icon:SetTexture(data.icon or 134400)
        row.icon:SetDesaturated(not data.enabled)
        row.icon:SetAlpha(data.enabled and 1 or DISABLED_ALPHA)
        -- every page shares these pooled rows, so whatever another page drew on the canvas goes before this one draws
        HideRegions(row.canvas:GetRegions())
        local drawn = data.draw ~= nil and data.draw(row.canvas, ICON_SIZE - 2) == true
        row.canvas:SetShown(drawn)
        row.canvas:SetAlpha(data.enabled and 1 or DISABLED_ALPHA)
        row.icon:SetShown(not drawn)

        -- the title sits over the state line or alone in the middle when the row has none
        local stateLine = data.isGroup or data.loadState ~= nil
        gui:ApplyFont(row.title, 'normal')
        row.title:SetText(data.text or '')
        row.title:ClearAllPoints()
        if stateLine then
            row.title:NUISetPixelPoint('TOPLEFT', row.iconBorder, 'TOPRIGHT', 6, -2)
        else
            row.title:NUISetPixelPoint('LEFT', row.iconBorder, 'RIGHT', 6, 0)
        end

        row.expand:ClearAllPoints()
        row.state:ClearAllPoints()
        if data.isGroup then
            row.expand:Show()
            local hasChildren = (data.childCount or 0) > 0
            row.expand:SetEnabled(hasChildren)
            row.expand.tex:SetTexture(MEDIA .. (data.expanded and 'minus-sign.png' or 'plus-sign.png'))
            local c = hasChildren and theme.textSecondary or muted
            row.expand.tex:SetVertexColor(c[1], c[2], c[3], 1)
            row.expand.tipTitle = data.expanded and L['Collapse'] or L['Expand']
            row.expand.tipText = hasChildren and (data.expanded and L["Hide this group's children"] or L["Show this group's children"])
                or L['Expansion is disabled because this group has no children']
            row.expand:NUISetPixelPoint('BOTTOMLEFT', row.iconBorder, 'BOTTOMRIGHT', 6, 3)
            row.state:NUISetPixelPoint('LEFT', row.expand, 'RIGHT', 6, 0)
        else
            row.expand:Hide()
            row.state:NUISetPixelPoint('BOTTOMLEFT', row.iconBorder, 'BOTTOMRIGHT', 8, 6)
        end

        row.state:SetShown(data.loadState ~= nil)
        if data.loadState then
            local stateColor = theme[STATE_COLORS[data.loadState]]
            row.state.tex:SetVertexColor(stateColor[1], stateColor[2], stateColor[3], 1)
            row.state.tipTitle = data.stateTitle or STATE_TEXT[data.loadState][1]
            row.state.tipText = data.stateText or (not data.stateTitle and STATE_TEXT[data.loadState][2]) or nil
        end

        row.eye:ClearAllPoints()
        row.eye:SetShown(data.preview ~= nil)
        row.eye:SetEnabled(not tree.locked)
        row.eye:NUISetPixelPoint('RIGHT', row, 'RIGHT', -pad, 0)
        if data.preview == 2 then
            row.eye.tex:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        elseif data.preview == 1 then
            row.eye.tex:SetVertexColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 0.9)
        else
            row.eye.tex:SetVertexColor(muted[1], muted[2], muted[3], 0.3)
        end
        row.eye.tipText = data.preview == 2 and L['Pinned: shown while the options are open. Click to hide.']
            or L['Click to keep this display shown while the options are open.']

        -- a warning shows on the row, so a problem is seen without opening the display
        Kaji.SetNotice(row, gui, nil, data.warnings and { text = data.warnings } or nil, row.eye)

        -- the title runs up to the marker or the eye, whichever is shown first
        local marker = row._noticeMarker
        local edge = marker and marker:IsShown() and marker or data.preview ~= nil and row.eye or nil
        if edge then
            row.title:NUISetPixelPoint('RIGHT', edge, 'LEFT', -4, 0)
        else
            row.title:NUISetPixelPoint('RIGHT', row, 'RIGHT', -pad, 0)
        end

        row.dropFill:Hide()
        ApplyRowState(row, true)
        activeRows[#activeRows + 1] = row
    end

    -- Section headers --

    ---@return CDMTreeSection
    local function CreateSection()
        local section = CreateFrame('Frame', nil, scrollChild, 'BackdropTemplate') --[[@as CDMTreeSection]]
        section:NUISetPixelHeight(SECTION_HEIGHT)
        -- the band shares the panel's fill, so it's outlined the way a button is to stand off it
        Kaji.SetBackdrop(section, gui, { bg = 'bgMedium', border = 'widgetBorder', edgeSize = 'borderSize' })

        section.label = section:CreateFontString(nil, 'OVERLAY')
        section.label:SetJustifyH('LEFT')
        section.label:NUISetPixelPoint('LEFT', section, 'LEFT', 6, 0)

        section.collapse = SmallButton(section, MEDIA .. 'minus-sign.png', SMALL_BUTTON - 2)
        section.collapse:NUISetPixelPoint('RIGHT', section, 'RIGHT', -pad, 0)
        section.collapse:SetScript('OnClick', function()
            tree:ToggleExpanded(section.data.key, section.data.collapsed == true)
        end)

        section.eye = SmallButton(section, MEDIA .. 'eye.png', SMALL_BUTTON + 2)
        section.eye:NUISetPixelPoint('RIGHT', section.collapse, 'LEFT', -6, 0)
        section.eye:SetScript('OnClick', function() tree.sd.onSectionPreview(section.data.key) end)

        return section
    end

    ---@param section CDMTreeSection
    ---@param data table
    local function ConfigureSection(section, data)
        section.data = data
        Kaji.RefreshBackdrop(section)

        gui:ApplyFont(section.label, 'normal')
        section.label:SetText(data.text)
        section.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)

        section.collapse.tex:SetTexture(MEDIA .. (data.collapsed and 'plus-sign.png' or 'minus-sign.png'))
        section.collapse.tex:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
        section.collapse.tipTitle = data.collapsed and L['Expand'] or L['Collapse']
        section.collapse.tipText = data.collapseText

        section.eye:SetShown(data.preview ~= nil)
        if data.preview then
            local c = data.preview == 2 and theme.accent or (data.preview == 1 and theme.textPrimary or theme.textMuted)
            section.eye.tex:SetVertexColor(c[1], c[2], c[3], data.preview == 0 and 0.3 or 1)
            section.eye.tipTitle, section.eye.tipText = L['View'], data.previewText
            section.eye:SetEnabled(not tree.locked)
            section.eye:SetAlpha(tree.locked and DISABLED_ALPHA or 1)
        end

        activeSections[#activeSections + 1] = section
    end

    -- Rendering --

    local function Acquire(pool, create)
        for _, f in ipairs(pool) do
            if not f.inUse then
                f.inUse = true
                f:Show()
                return f
            end
        end
        local f = create()
        f.inUse = true
        pool[#pool + 1] = f
        return f
    end

    local clipPool = {}
    local layout = {} -- rows and section headers top to bottom, with open/close markers around an animating block

    ---@return Frame
    local function CreateClip()
        local clip = CreateFrame('Frame', nil, scrollChild)
        clip:SetClipsChildren(true)
        return clip
    end

    local Snap = Kaji.Pixel.ToPixelGrid

    ---Places everything every frame; offsets are differences of snapped absolute y, so a row in a clip never rounds twice.
    local function Relayout()
        local y, stack = 0, {}
        local container, origin = scrollChild, 0
        for _, item in ipairs(layout) do
            if item.clip then
                local anim = item.open and tree.anims[item.open]
                stack[#stack + 1] = { container = container, origin = origin, start = y, clip = item.clip, p = anim and anim.p or 1 }
                local clip = item.clip
                clip:SetParent(container)
                clip:ClearAllPoints()
                local offset = Snap(origin) - Snap(y)
                clip:SetPoint('TOPLEFT', container, 'TOPLEFT', 0, offset)
                clip:SetPoint('TOPRIGHT', container, 'TOPRIGHT', 0, offset)
                container, origin = clip, y
            elseif item.close then
                local block = tremove(stack)
                local shown = floor((y - block.start) * block.p + 0.5)
                block.clip:SetHeight(mmax(Snap(block.start + shown) - Snap(block.start), 1))
                block.clip:SetShown(shown > 0)
                container, origin, y = block.container, block.origin, block.start + shown
            else
                local f = item.frame
                f:SetParent(container)
                f:ClearAllPoints()
                local offset = Snap(origin) - Snap(y)
                f:SetPoint('TOPLEFT', container, 'TOPLEFT', 0, offset)
                f:SetPoint('TOPRIGHT', container, 'TOPRIGHT', 0, offset)
                y = y + item.height + ROW_GAP
            end
        end
        scrollChild:NUISetPixelHeight(mmax(y, 1))
        UpdateScrollbar()
    end

    ---@param text string?
    ---@return boolean
    local function Matches(text)
        return tree.search == '' or (text ~= nil and strfind(strlower(text), tree.search, 1, true) ~= nil)
    end

    ---@param reuse boolean? draw the last content again, when only expansion or the search changed
    function tree:Render(reuse)
        if not self.sd then return end
        EndRename(false)
        for _, pool in ipairs({ rowPool, sectionPool, clipPool }) do
            for _, f in ipairs(pool) do f.inUse = false end
        end
        wipe(layout)
        wipe(activeRows)
        wipe(activeSections)

        -- The module is off: rows can still be browsed, nothing in them edits.
        self.locked = self.sd.locked ~= nil and self.sd.locked() == true
        local content = reuse and self.content or self.sd.items()
        self.content = content
        self.generalKey = content.general and content.general.key
        local leaves = {}
        if content.general then leaves[1] = content.general end
        for _, page in ipairs(content.pages or {}) do leaves[#leaves + 1] = page end -- selectable, never drawn as rows

        local searching = self.search ~= ''

        -- A row stays while it or anything under it matches the search.
        local function Visible(data)
            if Matches(data.text) then return true end
            for _, child in ipairs(data.children or {}) do
                if Visible(child) then return true end
            end
            return false
        end

        local rowKeys, order = self.rowKeys, self.order
        wipe(rowKeys)
        wipe(order)
        local function Collect(data)
            leaves[#leaves + 1] = data
            rowKeys[data.key] = true
            for _, child in ipairs(data.children or {}) do Collect(child) end
        end

        -- Every open block keeps its rows in a clip, as MiniSidebar sections do, so an animation never reparents them.
        local function Add(data)
            if searching and not Visible(data) then return end
            order[#order + 1] = data.key
            local row = Acquire(rowPool, CreateRow)
            ConfigureRow(row, data)
            layout[#layout + 1] = { frame = row, height = ROW_HEIGHT }
            local children = data.children
            if children and children[1] and (data.expanded or searching or self.anims[data.key]) then
                layout[#layout + 1] = { open = not searching and data.key or nil, clip = Acquire(clipPool, CreateClip) }
                for _, child in ipairs(children) do Add(child) end
                layout[#layout + 1] = { close = true }
            end
        end

        for _, section in ipairs(content.sections) do
            -- a section with no title is just its rows, for a page whose groups are its only structure
            if section.text then
                local header = Acquire(sectionPool, CreateSection)
                ConfigureSection(header, section)
                layout[#layout + 1] = { frame = header, height = SECTION_HEIGHT }
            end

            local open = not section.collapsed or self.anims[section.key] ~= nil
            if open and section.rows[1] then
                layout[#layout + 1] = { open = section.key, clip = Acquire(clipPool, CreateClip) }
            end
            for _, data in ipairs(section.rows) do
                Collect(data)
                if open then Add(data) end
            end
            if open and section.rows[1] then layout[#layout + 1] = { close = true } end
        end

        for _, pool in ipairs({ rowPool, sectionPool, clipPool }) do
            for _, f in ipairs(pool) do
                if not f.inUse then f:Hide() end
            end
        end

        for key in pairs(self.picked) do
            if not rowKeys[key] then self.picked[key] = nil end
        end

        self.leaves = leaves
        Relayout()
    end

    -- Expand animation --

    -- Expand eases out, collapse eases in, as Kaji's MiniSidebar; a finished block renders once to drop closed rows.
    local driver = CreateFrame('Frame', nil, frame)
    local function StepAnimations(_, elapsed)
        local finished = false
        for key, anim in pairs(tree.anims) do
            anim.t = mmin(anim.t + elapsed, anim.duration)
            local x = anim.t / anim.duration
            local eased = anim.to > anim.from and (1 - (1 - x) ^ 3) or x * x
            anim.p = anim.from + (anim.to - anim.from) * eased
            if anim.t >= anim.duration then
                tree.anims[key] = nil
                finished = true
            end
        end
        if not next(tree.anims) then driver:SetScript('OnUpdate', nil) end
        if finished then tree:Render(true) else Relayout() end
    end

    ---@param key string
    ---@param expanded boolean
    local function PatchExpanded(key, expanded)
        if not tree.content then return end
        for _, section in ipairs(tree.content.sections) do
            if section.key == key then
                section.collapsed = not expanded
                return
            end
        end
        for _, data in ipairs(tree.leaves) do
            if data.key == key then
                data.expanded = expanded
                return
            end
        end
    end

    ---Opens or closes a group or section with the animation; the host remembers the state.
    ---@param key string
    ---@param expanded boolean
    function tree:ToggleExpanded(key, expanded)
        self.sd.onToggleExpanded(key, expanded)
        if self.search == '' then
            -- Toggling mid-animation turns around from wherever the block is.
            local running = self.anims[key]
            local from = running and running.p or (expanded and 0 or 1)
            self.anims[key] = { p = from, from = from, to = expanded and 1 or 0, t = 0, duration = expanded and EXPAND_DURATION or COLLAPSE_DURATION }
            driver:SetScript('OnUpdate', StepAnimations)
        end
        PatchExpanded(key, expanded)
        self:Render(true)
    end

    -- Rename --

    local renameBox = CreateFrame('EditBox', nil, scrollChild, 'BackdropTemplate')
    renameBox:SetAutoFocus(false)
    renameBox:SetBackdrop(BOX_BACKDROP)
    renameBox:SetTextInsets(4, 4, 0, 0)
    renameBox:Hide()

    function EndRename(commit)
        local renaming = tree.renaming
        if not renaming then return end
        tree.renaming = nil

        local text = strtrim(renameBox:GetText() or '')
        renameBox:ClearFocus()
        renameBox:Hide()
        renaming.row.title:Show()
        if commit and text ~= '' and tree.sd.onRename then tree.sd.onRename(renaming.key, text, renaming.row.data) end
    end

    renameBox:SetScript('OnEnterPressed', function() EndRename(true) end)
    renameBox:SetScript('OnEscapePressed', function() EndRename(false) end)
    renameBox:SetScript('OnEditFocusLost', function() EndRename(false) end)

    ---@param key string
    function tree:BeginRename(key)
        EndRename(false)
        local row
        for _, r in ipairs(activeRows) do
            if r.data.key == key then row = r end
        end
        if not row then return end

        self.renaming = { key = key, row = row }
        gui:ApplyFont(renameBox --[[@as FontString]], 'normal')
        renameBox:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
        renameBox:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], 1)
        renameBox:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        renameBox:SetParent(row)
        renameBox:SetFrameLevel(row:GetFrameLevel() + 5)
        renameBox:ClearAllPoints()
        renameBox:NUISetPixelHeight(18)
        renameBox:NUISetPixelPoint('TOPLEFT', row.title, 'TOPLEFT', -4, 2)
        renameBox:NUISetPixelPoint('RIGHT', row, 'RIGHT', -pad, 0)
        row.title:Hide()
        renameBox:SetText(row.data.text or '')
        renameBox:Show()
        renameBox:SetFocus()
        renameBox:HighlightText()
    end

    -- Drag and drop: an icon goes into a group or before/after an icon inside one. --

    local ghost = CreateFrame('Frame', nil, UIParent, 'BackdropTemplate')
    ghost:SetFrameStrata('TOOLTIP')
    ghost:SetBackdrop(BOX_BACKDROP)
    ghost:NUISetPixelHeight(ROW_HEIGHT)
    ghost:Hide()

    local ghostIcon = ghost:CreateTexture(nil, 'ARTWORK')
    ghostIcon:NUISetPixelSnap()
    ghostIcon:NUISetPixelSize(ICON_SIZE - 4, ICON_SIZE - 4)
    ghostIcon:NUISetPixelPoint('LEFT', ghost, 'LEFT', 2, 0)
    ghostIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)

    local ghostLabel = ghost:CreateFontString(nil, 'OVERLAY')
    ghostLabel:NUISetPixelPoint('LEFT', ghostIcon, 'RIGHT', 6, 0)

    local dropLayer = CreateFrame('Frame', nil, scrollChild)
    dropLayer:SetAllPoints(scrollChild)
    dropLayer:SetFrameLevel(scrollChild:GetFrameLevel() + 20)
    local dropLine = dropLayer:CreateTexture(nil, 'OVERLAY')
    dropLine:NUISetPixelSnap()
    dropLine:NUISetPixelHeight(2)
    dropLine:Hide()

    local function ClearDropMarks()
        dropLine:Hide()
        for _, row in ipairs(activeRows) do row.dropFill:Hide() end
    end

    ---@param drag table
    ---@param row CDMTreeRow?
    local function ShowDropMark(drag, row)
        ClearDropMarks()
        if not row then return end

        local accent = theme.accent
        if drag.position == 'into' then
            row.dropFill:ClearAllPoints()
            row.dropFill:NUISetPixelPoint('TOPLEFT', row.iconBorder, 'TOPRIGHT', 2, 0)
            row.dropFill:NUISetPixelPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', -1, 1)
            row.dropFill:SetColorTexture(accent[1], accent[2], accent[3], 0.2)
            row.dropFill:Show()
            return
        end

        local edge = drag.position == 'before' and 'TOP' or 'BOTTOM'
        local offset = drag.position == 'before' and ROW_GAP / 2 or -ROW_GAP / 2
        dropLine:SetColorTexture(accent[1], accent[2], accent[3], 1)
        dropLine:ClearAllPoints()
        dropLine:NUISetPixelPoint('LEFT', row.bg, edge .. 'LEFT', 0, offset)
        dropLine:NUISetPixelPoint('RIGHT', row, edge .. 'RIGHT', 0, offset)
        dropLine:Show()
    end

    local function FindDropTarget(drag)
        if not scrollFrame:IsMouseOver() then return nil end
        local _, cursorY = GetCursorPosition()
        cursorY = cursorY / scrollChild:GetEffectiveScale()

        for _, row in ipairs(activeRows) do
            if row:IsVisible() and row:IsMouseOver() and not drag.moving[row.data.key] then
                local position
                if row.data.isGroup then
                    position = 'into'
                else
                    position = (row:GetTop() - cursorY) < row:GetHeight() / 2 and 'before' or 'after'
                end
                local fits = true
                for _, key in ipairs(drag.keys) do
                    if tree.sd.canDrop and not tree.sd.canDrop(key == drag.key and drag.data or { key = key }, row.data, position) then
                        fits = false
                        break
                    end
                end
                if fits then return row, row.data.key, position end
            end
        end
        return nil
    end

    local dragFrame = CreateFrame('Frame', nil, frame)

    local function StopDrag()
        local drag = tree.drag
        tree.drag = nil
        dragFrame:SetScript('OnUpdate', nil)
        dragFrame:UnregisterEvent('GLOBAL_MOUSE_UP')
        ghost:EnableKeyboard(false)
        ghost:Hide()
        ClearDropMarks()
        for _, row in ipairs(activeRows) do ApplyRowState(row) end
        return drag
    end

    local function StepDrag()
        local drag = tree.drag
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        ghost:ClearAllPoints()
        ghost:SetPoint('LEFT', UIParent, 'BOTTOMLEFT', x / scale + 12, y / scale)

        local row, target, position = FindDropTarget(drag)
        drag.target, drag.position = target, position
        ShowDropMark(drag, row)
    end

    dragFrame:SetScript('OnEvent', function(_, _, button)
        if button ~= 'LeftButton' then return end
        local drag = StopDrag()
        if drag and drag.target then tree.sd.onMove(drag.keys, drag.target, drag.position) end
    end)

    ghost:SetScript('OnKeyDown', function(self, key)
        self:SetPropagateKeyboardInput(key ~= 'ESCAPE')
        if key == 'ESCAPE' then StopDrag() end
    end)

    ---@param row CDMTreeRow
    function BeginDrag(row)
        EndRename(false)
        -- A row of a multi selection carries the whole selection.
        local keys = { row.data.key }
        if tree.picked[row.data.key] then
            local picked = tree:GetPicked()
            if #picked > 1 then keys = picked end
        end
        local moving = {}
        for _, key in ipairs(keys) do moving[key] = true end
        tree.drag = { key = row.data.key, data = row.data, keys = keys, moving = moving }

        ghost:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], 0.95)
        ghost:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        ghost:NUISetPixelWidth(row:GetWidth())
        ghostIcon:SetTexture(row.data.icon or 134400)
        gui:ApplyFont(ghostLabel, 'normal')
        ghostLabel:SetText(#keys > 1 and format(L['%d Displays'], #keys) or row.data.text or '')
        ghostLabel:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
        ghost:Show()
        if not InCombatLockdown() then ghost:EnableKeyboard(true) end -- keyboard capture is protected in combat

        for _, r in ipairs(activeRows) do ApplyRowState(r) end
        dragFrame:RegisterEvent('GLOBAL_MOUSE_UP')
        dragFrame:SetScript('OnUpdate', StepDrag)
        StepDrag()
    end

    -- Column contract --

    ---@param sd table
    ---@return table leaves
    function tree:SetConfig(sd)
        if self.drag then
            StopDrag()
        end
        -- every page with a tree shares this one column, so another page's search and picks don't come along
        if self.sd ~= sd then
            wipe(self.picked)
            wipe(self.anims)
            self.search = ''
            searchBox.editBox:ClearFocus()
            if searchBox.text ~= '' then
                searchBox.Clear()
            end
        end
        self.sd = sd
        -- the search restyles itself, the panel follows the theme on every page that shows the column
        RestylePanel()
        self:Render()
        C_Timer.After(0, UpdateScrollbar) -- the column has no size yet on its first show
        return self.leaves
    end

    ---@return table leaves
    function tree:SetItems()
        self:Render()
        return self.leaves
    end

    ---@param key string
    ---@param expanded boolean
    function tree:SetExpanded(key, expanded)
        self.sd.onToggleExpanded(key, expanded)
        self:Render()
    end

    ---@param key string?
    ---@param animate? boolean crossfade, for a click; a page opening on its remembered row snaps, as MiniSidebar's
    function tree:SetSelected(key, animate)
        -- Selected from outside (a new or duplicated display): the old multi selection goes.
        if not (key and self.picked[key]) then
            wipe(self.picked)
            if key then
                self.picked[key] = true
            end
        end
        self.selected = key
        for _, row in ipairs(activeRows) do
            ApplyRowState(row, not animate)
        end
        if self.sd and self.sd.onSelectionChanged then self.sd.onSelectionChanged(key) end
    end

    ---@param key string
    ---@param keepPicked boolean? leave the multi selection alone, when it only moves the shown display
    function tree:Select(key, keepPicked)
        if not keepPicked then
            wipe(self.picked)
            if self.rowKeys[key] then self.picked[key] = true end
        end
        self:SetSelected(key, true)
        -- a page without a general row deselects to nothing and its content has to follow
        if key == nil then
            onSelect(nil, nil)
            return
        end
        for _, data in ipairs(self.leaves) do
            if data.key == key then
                onSelect(key, data)
                return
            end
        end
    end

    function tree:GetSelected() return self.selected end

    ---Every selected display, top to bottom as drawn.
    ---@return string[]
    function tree:GetPicked()
        local list, listed = {}, {}
        for _, key in ipairs(self.order) do
            if self.picked[key] then
                list[#list + 1] = key
                listed[key] = true
            end
        end
        for key in pairs(self.picked) do
            if not listed[key] then list[#list + 1] = key end -- inside a collapsed group
        end
        return list
    end

    ---Ctrl click: add or remove one row; removing the shown display shows another picked one.
    ---@param key string
    function tree:TogglePick(key)
        local picked = self.picked
        picked[self.selected] = true
        if not picked[key] then
            picked[key] = true
        else
            picked[key] = nil
            if key == self.selected then
                local nextKey = next(picked)
                if not nextKey then
                    self:Select(self.generalKey)
                    return
                end
                self:Select(nextKey, true)
                return
            end
        end
        for _, row in ipairs(activeRows) do
            ApplyRowState(row)
        end
        if self.sd.onPicksChanged then
            self.sd.onPicksChanged()
        end
    end

    ---Shift click: everything drawn between the shown display and this row.
    ---@param anchor string
    ---@param key string
    function tree:PickRange(anchor, key)
        local from, to
        for index, rowKey in ipairs(self.order) do
            if rowKey == anchor then from = index end
            if rowKey == key then to = index end
        end
        if not (from and to) then return self:TogglePick(key) end

        wipe(self.picked)
        for index = mmin(from, to), mmax(from, to) do
            self.picked[self.order[index]] = true
        end
        for _, row in ipairs(activeRows) do
            ApplyRowState(row)
        end
        if self.sd.onPicksChanged then
            self.sd.onPicksChanged()
        end
    end

    return tree
end

NRSKNUI.CreateItemTree = CreateTree

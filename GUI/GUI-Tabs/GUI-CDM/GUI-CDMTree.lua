---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local Kaji = NRSKNUI.Libs.KAJI

local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local InCombatLockdown = InCombatLockdown
local GameTooltip = GameTooltip
local UIParent = UIParent
local ipairs = ipairs
local wipe = wipe
local strtrim = strtrim
local strlower = string.lower
local strfind = string.find
local mmax = math.max
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
local ICON_SIZE = 32
local ICON_CROP = 0.08
local SMALL_BUTTON = 14
local DOT_SIZE = 8
local DISABLED_ALPHA = 0.45
local DRAG_SOURCE_ALPHA = 0.35
local ACCENT_BAR_WIDTH = 2

-- collapse.tga points down at rotation 0.
local ARROW_UP, ARROW_LEFT = pi, -pi / 2

local STATE_COLORS = { loaded = 'success', standby = 'warning', unloaded = 'textMuted' }
local STATE_TEXT = {
    loaded = { L['Loaded'], L['This display is currently loaded'] },
    standby = { L['Standby'], L['This display is on standby, it will be loaded when needed.'] },
    unloaded = { L['Not Loaded'], L['This display is not currently loaded'] },
}

---@class CDMTreeSmallButton : Button
---@field tex Texture
---@field tipTitle string?
---@field tipText string?

---@class CDMTreeRow : Button
---@field data table
---@field inUse boolean
---@field bg Texture
---@field hoverBg Texture
---@field selectedBg Texture
---@field dropFill Texture
---@field accentBar Texture
---@field barGlow Texture
---@field up CDMTreeSmallButton
---@field ungroup CDMTreeSmallButton
---@field down CDMTreeSmallButton
---@field iconBorder Texture
---@field icon Texture
---@field title FontString
---@field expand CDMTreeSmallButton
---@field state CDMTreeSmallButton
---@field enable Button|BackdropTemplate
---@field eye CDMTreeSmallButton

---@class CDMTreeSection : Frame
---@field data table
---@field inUse boolean
---@field bg Texture
---@field label FontString
---@field collapse CDMTreeSmallButton
---@field eye CDMTreeSmallButton

---@param owner Frame
---@param title string
---@param text string?
local function ShowTooltip(owner, title, text)
    GameTooltip:SetOwner(owner, 'ANCHOR_RIGHT')
    GameTooltip:SetText(title, 1, 1, 1)
    if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
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

---Creates the Cooldown Manager's WeakAuras-style display tree, a ContentArea column.
---@param gui KajiGUIInstance
---@param parent Frame
---@param opts table { onSelect: fun(key: string, item: table) }
---@return table tree
local function CreateTree(gui, parent, opts)
    local theme = gui.theme
    local pad = theme.paddingSmall
    local onSelect = opts.onSelect

    local frame = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
    frame:SetBackdrop({ bgFile = WHITE })
    frame:NUISetPixelWidth(WIDTH)

    local rightBorder = frame:CreateTexture(nil, 'BORDER')
    rightBorder:NUISetPixelSnap()
    rightBorder:NUISetPixelWidth(theme.borderSize)
    rightBorder:NUISetPixelPoint('TOPRIGHT', frame, 'TOPRIGHT', 0, 0)
    rightBorder:NUISetPixelPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', 0, 0)

    local tree = {
        frame = frame,
        selected = nil,
        leaves = {},
        search = '',
    }

    -- Toolbar --

    local toolbar = CreateFrame('Frame', nil, frame)
    ---The scrollbar's track runs the full column height, so the toolbar steps aside for it.
    ---@param scrollbarShown boolean
    local function AnchorToolbar(scrollbarShown)
        toolbar:ClearAllPoints()
        toolbar:NUISetPixelPoint('TOPLEFT', frame, 'TOPLEFT', pad, -theme.barInset)
        toolbar:NUISetPixelPoint('TOPRIGHT', frame, 'TOPRIGHT', -pad - (scrollbarShown and theme.scrollbarWidth or theme.borderSize), -theme.barInset)
    end
    AnchorToolbar(false)
    toolbar:NUISetPixelHeight(theme.barControlHeight)

    local searchBox = CreateFrame('EditBox', nil, toolbar, 'BackdropTemplate')
    searchBox:SetAutoFocus(false)
    searchBox:SetBackdrop(BOX_BACKDROP)
    searchBox:SetTextInsets(6, 6, 0, 0)
    searchBox:NUISetPixelHeight(theme.barControlHeight)
    searchBox:NUISetPixelPoint('BOTTOMLEFT', toolbar, 'BOTTOMLEFT', 0, 0)
    searchBox:NUISetPixelPoint('BOTTOMRIGHT', toolbar, 'BOTTOMRIGHT', 0, 0)

    local searchHint = searchBox:CreateFontString(nil, 'OVERLAY')
    searchHint:NUISetPixelPoint('LEFT', searchBox, 'LEFT', 6, 0)

    searchBox:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
    searchBox:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
    searchBox:SetScript('OnTextChanged', function(self)
        tree.search = strlower(strtrim(self:GetText() or ''))
        searchHint:SetShown(tree.search == '' and not self:HasFocus())
        tree:Render()
    end)
    searchBox:SetScript('OnEditFocusGained', function() searchHint:Hide() end)
    searchBox:SetScript('OnEditFocusLost', function() searchHint:SetShown(tree.search == '') end)

    -- List --

    local scrollFrame = CreateFrame('ScrollFrame', nil, frame)
    scrollFrame:SetClipsChildren(true)
    scrollFrame:NUISetPixelPoint('TOPLEFT', toolbar, 'BOTTOMLEFT', -pad, -pad)
    scrollFrame:NUISetPixelPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -theme.borderSize, pad)

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
            AnchorToolbar(visible)
        end
        local w = frame:GetWidth()
        if w and w > 0 then
            scrollChild:NUISetPixelWidth(w - (scrollbarVisible and theme.scrollbarWidth or theme.borderSize))
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
    local function ApplyRowState(row)
        local data = row.data
        local alpha = data.enabled and 1 or DISABLED_ALPHA
        local selected = data.key == tree.selected
        if selected then
            row.accentBar:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            row.accentBar:Show()
            Kaji.PaintSelected(row --[[@as { selectedBg: Texture, barGlow: Texture }]], theme)
            row.title:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], alpha)
        else
            row.accentBar:Hide(); row.selectedBg:Hide(); row.barGlow:Hide()
            local c = row:IsMouseOver() and theme.textPrimary or theme.textSecondary
            row.title:SetTextColor(c[1], c[2], c[3], alpha)
        end
        row:SetAlpha(tree.drag and tree.drag.key == data.key and DRAG_SOURCE_ALPHA or 1)
    end

    ---@return CDMTreeRow
    local function CreateRow()
        local row = CreateFrame('Button', nil, scrollChild) --[[@as CDMTreeRow]]
        row:NUISetPixelHeight(ROW_HEIGHT)
        row:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
        row:RegisterForDrag('LeftButton')

        row.bg = row:CreateTexture(nil, 'BACKGROUND')
        row.bg:SetColorTexture(1, 1, 1, 0.03)

        row.hoverBg = row:CreateTexture(nil, 'BACKGROUND', nil, 1)
        row.hoverBg:SetColorTexture(1, 1, 1, 0.05)
        row.hoverBg:Hide()

        row.selectedBg = row:CreateTexture(nil, 'BACKGROUND', nil, 1)
        row.selectedBg:Hide()

        row.dropFill = row:CreateTexture(nil, 'BACKGROUND', nil, 3)
        row.dropFill:Hide()

        row.accentBar = row:CreateTexture(nil, 'OVERLAY')
        row.accentBar:NUISetPixelSnap()
        row.accentBar:NUISetPixelWidth(ACCENT_BAR_WIDTH)
        row.accentBar:Hide()
        row.barGlow = Kaji.CreateBarGlow(row, row.accentBar)

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

        row.title = row:CreateFontString(nil, 'OVERLAY')
        row.title:SetJustifyH('LEFT')
        row.title:SetWordWrap(false)

        row.expand = SmallButton(row, MEDIA .. 'plus-sign.png', SMALL_BUTTON - 2)
        row.expand:SetScript('OnClick', function()
            local data = row.data
            tree.sd.onToggleExpanded(data.key, not data.expanded)
            tree:Render()
        end)

        row.state = SmallButton(row, MEDIA .. 'whiteCircle.png', DOT_SIZE)

        row.enable = CreateFrame('Button', nil, row, 'BackdropTemplate')
        row.enable:NUISetPixelSize(SMALL_BUTTON, SMALL_BUTTON)
        row.enable:SetBackdrop(BOX_BACKDROP)
        row.enable.check = row.enable:CreateTexture(nil, 'ARTWORK')
        row.enable.check:NUISetPixelSnap()
        row.enable.check:SetTexture(MEDIA .. 'check.png')
        row.enable.check:NUISetPixelPoint('TOPLEFT', row.enable, 'TOPLEFT', 2, -2)
        row.enable.check:NUISetPixelPoint('BOTTOMRIGHT', row.enable, 'BOTTOMRIGHT', -2, 2)
        row.enable:SetScript('OnEnter', function(self)
            ShowTooltip(self, row.data.enabled and L['Disable'] or L['Enable'], L['Turn this display on or off'])
        end)
        row.enable:SetScript('OnLeave', HideTooltip)
        row.enable:SetScript('OnClick', function() tree.sd.onToggleEnabled(row.data.key) end)

        row.eye = SmallButton(row, MEDIA .. 'eye.png', SMALL_BUTTON + 2)
        row.eye.tipTitle, row.eye.tipText = L['View'], L['Toggle the visibility of this display']
        row.eye:SetScript('OnClick', function() tree.sd.onTogglePreview(row.data.key) end)

        row:SetScript('OnEnter', function(self)
            self.hoverBg:Show()
            if self.data.key ~= tree.selected then
                self.accentBar:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], Kaji.HOVER_BAR_ALPHA)
                self.accentBar:Show()
            end
            ApplyRowState(self)
            if self.data.tooltip then
                GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                self.data.tooltip(GameTooltip)
                GameTooltip:Show()
            end
        end)
        row:SetScript('OnLeave', function(self)
            self.hoverBg:Hide()
            ApplyRowState(self)
            HideTooltip()
        end)
        row:SetScript('OnClick', function(self, button)
            if button == 'RightButton' then
                if tree.sd.onContextMenu then tree.sd.onContextMenu(self.data.key, self.data) end
                return
            end
            -- Clicking the selected row again clears the selection, back to the new-display page.
            tree:Select(self.data.key ~= tree.selected and self.data.key or tree.generalKey)
        end)
        row:SetScript('OnDoubleClick', function(self, button)
            if button == 'LeftButton' then tree:BeginRename(self.data.key) end
        end)
        row:SetScript('OnDragStart', function(self)
            if self.data.draggable and tree.sd.onMove then BeginDrag(self) end
        end)

        return row
    end

    ---@param row CDMTreeRow
    ---@param data table
    ---@param y number
    local function ConfigureRow(row, data, y)
        row.data = data
        row:ClearAllPoints()
        row:NUISetPixelPoint('TOPLEFT', scrollChild, 'TOPLEFT', 0, -y)
        row:NUISetPixelPoint('TOPRIGHT', scrollChild, 'TOPRIGHT', 0, -y)

        local child = data.depth > 0
        local left = child and data.depth * CHILD_INDENT or 1

        row.bg:ClearAllPoints()
        row.bg:NUISetPixelPoint('TOPLEFT', row, 'TOPLEFT', left, 0)
        row.bg:NUISetPixelPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 0, 0)
        row.hoverBg:SetAllPoints(row.bg)
        row.selectedBg:SetAllPoints(row.bg)
        row.accentBar:ClearAllPoints()
        row.accentBar:NUISetPixelPoint('TOPLEFT', row.bg, 'TOPLEFT', 0, 0)
        row.accentBar:NUISetPixelPoint('BOTTOMLEFT', row.bg, 'BOTTOMLEFT', 0, 0)

        local muted = theme.textMuted
        for _, arrow in ipairs({ row.up, row.ungroup, row.down }) do
            arrow:SetShown(child)
            arrow.tex:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
        end
        row.iconBorder:ClearAllPoints()
        if child then
            row.up:ClearAllPoints(); row.ungroup:ClearAllPoints(); row.down:ClearAllPoints()
            row.up:NUISetPixelPoint('TOPLEFT', row.bg, 'TOPLEFT', 0, 0)
            row.ungroup:NUISetPixelPoint('LEFT', row.bg, 'LEFT', 0, 0)
            row.down:NUISetPixelPoint('BOTTOMLEFT', row.bg, 'BOTTOMLEFT', 0, 0)
            row.up:SetEnabled(data.canMoveUp == true)
            row.down:SetEnabled(data.canMoveDown == true)
            if not data.canMoveUp then row.up.tex:SetVertexColor(muted[1], muted[2], muted[3], 0.4) end
            if not data.canMoveDown then row.down.tex:SetVertexColor(muted[1], muted[2], muted[3], 0.4) end
            row.iconBorder:NUISetPixelPoint('LEFT', row.bg, 'LEFT', ARROW_SIZE + 2, 0)
        else
            row.iconBorder:NUISetPixelPoint('LEFT', row.bg, 'LEFT', ACCENT_BAR_WIDTH + 2, 0)
        end

        row.icon:SetTexture(data.icon or 134400)
        row.icon:SetDesaturated(not data.enabled)
        row.icon:SetAlpha(data.enabled and 1 or DISABLED_ALPHA)

        gui:ApplyFont(row.title, 'normal')
        row.title:SetText(data.text or '')
        row.title:ClearAllPoints()
        row.title:NUISetPixelPoint('TOPLEFT', row.iconBorder, 'TOPRIGHT', 6, -3)
        row.title:NUISetPixelPoint('RIGHT', row, 'RIGHT', -pad, 0)

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

        local stateColor = theme[STATE_COLORS[data.loadState]]
        row.state.tex:SetVertexColor(stateColor[1], stateColor[2], stateColor[3], 1)
        row.state.tipTitle = STATE_TEXT[data.loadState][1]
        row.state.tipText = data.stateText or STATE_TEXT[data.loadState][2]

        row.enable:ClearAllPoints()
        row.enable:NUISetPixelPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', -pad, 4)
        row.enable:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], 1)
        row.enable:SetBackdropBorderColor(theme.widgetBorder[1], theme.widgetBorder[2], theme.widgetBorder[3], 1)
        row.enable.check:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        row.enable.check:SetShown(data.enabled)

        row.eye:ClearAllPoints()
        row.eye:NUISetPixelPoint('RIGHT', row.enable, 'LEFT', -6, 0)
        if data.preview == 2 then
            row.eye.tex:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        elseif data.preview == 1 then
            row.eye.tex:SetVertexColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 0.9)
        else
            row.eye.tex:SetVertexColor(muted[1], muted[2], muted[3], 0.3)
        end
        row.eye.tipText = data.preview == 2 and L['Pinned: shown while the options are open. Click to hide.']
            or L['Click to keep this display shown while the options are open.']

        row.dropFill:Hide()
        ApplyRowState(row)
        activeRows[#activeRows + 1] = row
    end

    -- Section headers --

    ---@return CDMTreeSection
    local function CreateSection()
        local section = CreateFrame('Frame', nil, scrollChild) --[[@as CDMTreeSection]]
        section:NUISetPixelHeight(SECTION_HEIGHT)

        section.bg = section:CreateTexture(nil, 'BACKGROUND')
        section.bg:SetAllPoints()

        section.label = section:CreateFontString(nil, 'OVERLAY')
        section.label:SetJustifyH('LEFT')
        section.label:NUISetPixelPoint('LEFT', section, 'LEFT', 6, 0)

        section.collapse = SmallButton(section, MEDIA .. 'minus-sign.png', SMALL_BUTTON - 2)
        section.collapse:NUISetPixelPoint('RIGHT', section, 'RIGHT', -pad, 0)
        section.collapse:SetScript('OnClick', function()
            tree.sd.onToggleExpanded(section.data.key, section.data.collapsed)
            tree:Render()
        end)

        section.eye = SmallButton(section, MEDIA .. 'eye.png', SMALL_BUTTON + 2)
        section.eye:NUISetPixelPoint('RIGHT', section.collapse, 'LEFT', -6, 0)
        section.eye:SetScript('OnClick', function() tree.sd.onSectionPreview(section.data.key) end)

        return section
    end

    ---@param section CDMTreeSection
    ---@param data table
    ---@param y number
    local function ConfigureSection(section, data, y)
        section.data = data
        section:ClearAllPoints()
        section:NUISetPixelPoint('TOPLEFT', scrollChild, 'TOPLEFT', 0, -y)
        section:NUISetPixelPoint('TOPRIGHT', scrollChild, 'TOPRIGHT', 0, -y)
        section.bg:SetColorTexture(theme.widgetBorder[1], theme.widgetBorder[2], theme.widgetBorder[3], 0.9)

        gui:ApplyFont(section.label, 'normal')
        section.label:SetText(data.text)
        section.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)

        section.collapse.tex:SetTexture(MEDIA .. (data.collapsed and 'plus-sign.png' or 'minus-sign.png'))
        section.collapse.tex:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
        section.collapse.tipTitle = data.collapsed and L['Expand'] or L['Collapse']
        section.collapse.tipText = data.collapseText

        local c = data.preview == 2 and theme.accent or (data.preview == 1 and theme.textPrimary or theme.textMuted)
        section.eye.tex:SetVertexColor(c[1], c[2], c[3], data.preview == 0 and 0.3 or 1)
        section.eye.tipTitle, section.eye.tipText = L['View'], data.previewText

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

    ---@param text string?
    ---@return boolean
    local function Matches(text)
        return tree.search == '' or (text ~= nil and strfind(strlower(text), tree.search, 1, true) ~= nil)
    end

    function tree:Render()
        if not self.sd then return end
        EndRename(false)
        for _, pool in ipairs({ rowPool, sectionPool }) do
            for _, f in ipairs(pool) do f.inUse = false end
        end
        wipe(activeRows)
        wipe(activeSections)

        local content = self.sd.items()
        self.generalKey = content.general and content.general.key
        local leaves = {}
        if content.general then leaves[1] = content.general end

        local searching = self.search ~= ''

        -- A row stays while it or anything under it matches the search.
        local function Visible(data)
            if Matches(data.text) then return true end
            for _, child in ipairs(data.children or {}) do
                if Visible(child) then return true end
            end
            return false
        end

        local function Collect(data)
            leaves[#leaves + 1] = data
            for _, child in ipairs(data.children or {}) do Collect(child) end
        end

        local y = 0
        local function Add(data)
            if searching and not Visible(data) then return end
            ConfigureRow(Acquire(rowPool, CreateRow), data, y)
            y = y + ROW_HEIGHT + ROW_GAP
            if data.expanded or searching then
                for _, child in ipairs(data.children or {}) do Add(child) end
            end
        end

        for _, section in ipairs(content.sections) do
            ConfigureSection(Acquire(sectionPool, CreateSection), section, y)
            y = y + SECTION_HEIGHT + ROW_GAP

            for _, data in ipairs(section.rows) do
                Collect(data)
                if not section.collapsed then Add(data) end
            end
        end

        for _, pool in ipairs({ rowPool, sectionPool }) do
            for _, f in ipairs(pool) do
                if not f.inUse then f:Hide() end
            end
        end

        self.leaves = leaves
        scrollChild:NUISetPixelHeight(mmax(y, 1))
        UpdateScrollbar()
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
            if row:IsVisible() and row:IsMouseOver() and row.data.key ~= drag.key then
                local position
                if row.data.isGroup then
                    position = 'into'
                else
                    position = (row:GetTop() - cursorY) < row:GetHeight() / 2 and 'before' or 'after'
                end
                if not tree.sd.canDrop or tree.sd.canDrop(drag.data, row.data, position) then
                    return row, row.data.key, position
                end
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
        if drag and drag.target then tree.sd.onMove(drag.key, drag.target, drag.position) end
    end)

    ghost:SetScript('OnKeyDown', function(self, key)
        self:SetPropagateKeyboardInput(key ~= 'ESCAPE')
        if key == 'ESCAPE' then StopDrag() end
    end)

    ---@param row CDMTreeRow
    function BeginDrag(row)
        EndRename(false)
        tree.drag = { key = row.data.key, data = row.data }

        ghost:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], 0.95)
        ghost:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        ghost:NUISetPixelWidth(row:GetWidth())
        ghostIcon:SetTexture(row.data.icon or 134400)
        gui:ApplyFont(ghostLabel, 'normal')
        ghostLabel:SetText(row.data.text or '')
        ghostLabel:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
        ghost:Show()
        if not InCombatLockdown() then ghost:EnableKeyboard(true) end -- keyboard capture is protected in combat

        for _, r in ipairs(activeRows) do ApplyRowState(r) end
        dragFrame:RegisterEvent('GLOBAL_MOUSE_UP')
        dragFrame:SetScript('OnUpdate', StepDrag)
        StepDrag()
    end

    -- Column contract --

    local function RestyleChrome()
        frame:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], 0.2)
        rightBorder:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
        searchBox:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], 1)
        searchBox:SetBackdropBorderColor(theme.widgetBorder[1], theme.widgetBorder[2], theme.widgetBorder[3], 1)
        gui:ApplyFont(searchBox --[[@as FontString]], 'normal')
        searchBox:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
        gui:ApplyFont(searchHint, 'normal')
        searchHint:SetText(L['Search'])
        searchHint:SetTextColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 1)
    end

    ---@param sd table
    ---@return table leaves
    function tree:SetConfig(sd)
        if self.drag then StopDrag() end
        self.sd = sd
        RestyleChrome()
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
    function tree:SetSelected(key)
        self.selected = key
        for _, row in ipairs(activeRows) do ApplyRowState(row) end
        if self.sd and self.sd.onSelectionChanged then self.sd.onSelectionChanged(key) end
    end

    ---@param key string
    function tree:Select(key)
        self:SetSelected(key)
        for _, data in ipairs(self.leaves) do
            if data.key == key then
                onSelect(key, data)
                return
            end
        end
    end

    function tree:GetSelected() return self.selected end

    return tree
end

NRSKNUI.CreateCDMTree = CreateTree

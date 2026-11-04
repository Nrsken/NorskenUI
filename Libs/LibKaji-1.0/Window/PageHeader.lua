--[[
# PageHeader

* A panel for a content host's header slot (host:SetHeader): a title on a hairline that dives 45° down
  to a track, label-width tabs standing on the track's right end with an optional + after them, an optional
  switch under the title and a quiet row of actions above it. A dot field, a ruler, a faint index number and corner marks dress it.
* It knows nothing about what it heads. The owner fills it through setters, hears clicks through the
  callbacks it hands in, then calls :Render(), which lays it out and returns the height for the slot.
* One per window, like the mini sidebar; it restyles itself on theme change.

## Example

    local header = gui:CreatePageHeader(host.frame, {
        onTabSelect = function(value) ... end,
        onTabMenu = function(value) ... end, -- right-click on a tab
    })
    header:SetTitle('Unit Frames')
    header:SetIndex(4)
    header:SetActions({ { text = 'Reset', tooltip = 'Back to defaults', onClick = Reset } })
    header:SetSwitch({ text = 'Enable Unit Frames', value = true, msgText = 'Unit Frames', onToggle = Toggle })
    header:SetTabs({ { value = false, text = 'All Roles' } }, false)
    header:SetAddButton({ tooltip = 'Add', onClick = OpenMenu })
    host:SetHeader(header.frame, header:Render())
--]]

local lib = LibStub and LibStub('LibKaji-1.0', true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local C_Timer = C_Timer
local ipairs = ipairs
local floor, max = math.floor, math.max
local format = string.format

local TITLE_SIZE = 22
local TAB_PAD = 12 -- either side of a tab's label
local CROSS = 17 -- the cross the + is cut from, smaller than the close button's so it sits back
local CROSS_CROP = (1 - 1 / math.sqrt(2)) / 2 -- turned 45° the close button's arms span 1/√2 of it, so the + crops to that
local ACTION_GAP = 2 -- between the action row and the title
local GHOST_SIZE = 72
local GHOST_ALPHA = 0.04
local GHOST_BLEED = 14 -- how far the number runs off the panel's right edge
local TICK_STEP = 6 -- between the ruler's ticks
local TICK_MINOR, TICK_MAJOR = 2, 4 -- tick lengths, every fifth one major
local HALFTONE_WIDTH = 1024 -- texels, drawn one per physical pixel
local HALFTONE_ROWS = 128 -- the dots repeat down the panel every 128 texels
local HOVER_LIGHTEN = 0.6 -- how far a hovered tab label goes toward textPrimary, as in the sidebar
local DIM_ALPHA = 0.35
local SEPARATOR = ' · '

---Creates the header. The caller hands header.frame and :Render()'s height to host:SetHeader.
---@param parent Frame the host's frame
---@param opts? { onTabSelect?: fun(value: any), onTabMenu?: fun(value: any) }
---@return KajiGUIPageHeader
function InstanceMixin:CreatePageHeader(parent, opts)
    opts = opts or {}
    local gui = self
    local theme = self.theme
    local MARGIN = theme.paddingSmall -- around the panel, as around the cards; the page below brings its own
    local INSET = theme.paddingMedium -- where the card titles below start
    local TOP = theme.paddingMedium + theme.paddingSmall
    local LINE_GAP = theme.paddingSmall -- between the title and the row under it
    local BOTTOM = theme.paddingMedium
    local UNDER_GAP = theme.paddingSmall -- between the title and its underline
    local TAB_HEIGHT = theme.barControlHeight
    local PATH = theme.borderSize -- a hairline, so only the selected tab's bar reads as the accent

    ---@class KajiGUIPageHeader
    ---@field frame Frame the whole header, for host:SetHeader
    local header = {}

    local frame = CreateFrame('Frame', nil, parent)
    frame:Hide()
    header.frame = frame

    local panel = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
    pixel.SetPixelPoint(panel, 'TOPLEFT', frame, 'TOPLEFT', MARGIN, -MARGIN)
    pixel.SetPixelPoint(panel, 'BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -MARGIN, 0)
    lib.SetBackdrop(panel, gui, { bg = 'bgMedium', border = 'border', edgeSize = 'borderSize' })

    -- Dressing --

    -- the dot field: right of the slash and above the track, so the line is its edge, thickening toward the right end
    local halftone = panel:CreateTexture(nil, 'BACKGROUND', nil, 3)
    halftone:SetTexture(theme.headerHalftoneTexture, 'CLAMP', 'REPEAT')
    pixel.SetPixelSnap(halftone)

    -- cuts the field along the slash; past the slash's box it stays whole
    local cut = panel:CreateMaskTexture()
    cut:SetTexture(theme.diagonalMask, 'CLAMPTOWHITE', 'CLAMPTOWHITE')
    pixel.SetPixelSnap(cut)
    halftone:AddMaskTexture(cut)

    local fieldLeft, fieldBottom = 0, 0 -- set by Render, down and across from the panel's top left

    ---One texel per physical pixel with the texture's right end at the panel's, so the dots stay crisp.
    local function LayoutField()
        local perUnit = panel:GetEffectiveScale() / pixel.GetPerfectPixel()
        local w = (panel:GetWidth() - fieldLeft - theme.borderSize) * perUnit
        local h = (fieldBottom - theme.borderSize) * perUnit
        if w <= 0 or h <= 0 then return end
        halftone:SetTexCoord(max(0, 1 - w / HALFTONE_WIDTH), 1, 0, h / HALFTONE_ROWS)
    end

    -- the ruler under the track: ticks from the slash's foot to the right end, every fifth one longer
    local ticks = {}
    local rulerLeft, rulerTop = 0, 0 -- set by Render, as the field's

    local function LayoutRuler()
        -- the panel can resize before the first Render has placed the track; ticks then would land on the top edge
        if rulerTop == 0 then return end
        local right = panel:GetWidth() - INSET
        local count = right > rulerLeft and floor((right - rulerLeft) / TICK_STEP) + 1 or 0
        local c = theme.widgetBorder
        for i = 1, max(count, #ticks) do
            local tick = ticks[i]
            if i > count then
                tick:Hide()
            else
                if not tick then
                    tick = panel:CreateTexture(nil, 'ARTWORK')
                    pixel.SetPixelSnap(tick)
                    ticks[i] = tick
                end
                tick:SetColorTexture(c[1], c[2], c[3], 1)
                pixel.SetPixelSize(tick, PATH, (i - 1) % 5 == 0 and TICK_MAJOR or TICK_MINOR)
                tick:ClearAllPoints()
                pixel.SetPixelPoint(tick, 'TOPLEFT', panel, 'TOPLEFT', rulerLeft + (i - 1) * TICK_STEP, -rulerTop)
                tick:Show()
            end
        end
    end

    panel:SetScript('OnSizeChanged', function()
        LayoutField()
        LayoutRuler()
    end)

    local corners = lib.CreateCornerTicks(panel, panel, theme)

    -- the faint index running off the right edge behind the dots and tabs;
    -- a frame deeper than the clipping one, since that clips its children
    local ghostClip = CreateFrame('Frame', nil, panel)
    pixel.SetPixelInside(ghostClip, panel, 0, 0)
    ghostClip:SetClipsChildren(true)

    local ghostHolder = CreateFrame('Frame', nil, ghostClip)
    pixel.SetPixelInside(ghostHolder, ghostClip, 0, 0)

    local ghost = ghostHolder:CreateFontString(nil, 'BACKGROUND')
    gui:ApplyFont(ghost, GHOST_SIZE)
    pixel.SetPixelPoint(ghost, 'RIGHT', panel, 'RIGHT', GHOST_BLEED, 0)

    -- grows to the right from a fixed edge: centred in its own fractional width, the first letter shifted per title
    local title = panel:CreateFontString(nil, 'OVERLAY')
    title:SetJustifyH('LEFT')
    title:SetWordWrap(false)
    gui:ApplyFont(title, TITLE_SIZE)

    -- the underline: out from the title, down the slash, then along under the tabs
    local underline = panel:CreateTexture(nil, 'ARTWORK')
    pixel.SetPixelHeight(underline, PATH)
    pixel.SetPixelSnap(underline)

    local dive = panel:CreateLine(nil, 'ARTWORK')

    local track = panel:CreateTexture(nil, 'ARTWORK')
    pixel.SetPixelHeight(track, PATH)
    pixel.SetPixelSnap(track)

    -- State --

    local titleText = ''
    local index ---@type number?
    local actionDefs = {}
    local switchDef ---@type table?
    local tabDefs, selectedTab = {}, nil
    local addDef ---@type table?
    local dimmed = false

    -- Actions --

    -- small words above the title, as quiet as a caption: muted at rest, lightening while hovered, the accent
    -- while what they toggle is on; colour only, so the tabs keep the header's one lit line
    local actionRow = CreateFrame('Frame', nil, panel)
    local actions, separators = {}, {}
    local clicking = false -- inside an action's click, whose state changes always fade

    ---@param button Button
    local function PaintAction(button)
        local def = button.def
        if not def then return end
        local l, h = lib.RowSelectionProgress(button)
        local rest, hi, ac = theme.textMuted, theme.textPrimary, theme.accent
        local r = rest[1] + (hi[1] - rest[1]) * h * HOVER_LIGHTEN
        local g = rest[2] + (hi[2] - rest[2]) * h * HOVER_LIGHTEN
        local b = rest[3] + (hi[3] - rest[3]) * h * HOVER_LIGHTEN
        local off = dimmed and not def.keepLive or def.isDisabled and def.isDisabled()
        button.label:SetTextColor(r + (ac[1] - r) * l, g + (ac[2] - g) * l, b + (ac[3] - b) * l, off and DIM_ALPHA or 1)
        button:EnableMouse(not off)
    end

    ---Aims an action's line at its state.
    ---@param instant? boolean snap, for state that changed with the page rather than by a click here
    local function ApplyAction(button, instant)
        local def = button.def
        if not def then return end
        local lit = def.isActive and def.isActive() and true or false
        local snap = instant and not clicking
        lib.SetRowSelection(button, theme, lit and 1 or 0, button.hovered and not lit and 1 or 0, snap)
        if snap then
            PaintAction(button)
        end
    end

    local function CreateAction()
        local button = CreateFrame('Button', nil, actionRow)
        button.label = button:CreateFontString(nil, 'OVERLAY')
        button.label:SetJustifyH('LEFT')
        gui:ApplyFont(button.label, 'small')
        pixel.SetPixelPoint(button.label, 'LEFT', button, 'LEFT', 0, 0)
        -- the selection's fade drives the label alone, no line
        lib.CreateRowSelection(button, theme, 'bottom', 'none')
        button:SetScript('OnUpdate', function(self, elapsed)
            if lib.StepRowSelection(self, theme, elapsed) then
                PaintAction(self)
            end
        end)
        button:SetScript('OnEnter', function(self)
            self.hovered = true
            ApplyAction(self)
            if self.def.tooltip then
                lib.ShowTooltip(self)
            end
        end)
        button:SetScript('OnLeave', function(self)
            self.hovered = nil
            ApplyAction(self)
            lib.HideTooltip()
        end)
        button:SetScript('OnClick', function(self)
            clicking = true
            safecall(self.def.onClick, self.def)
            header:RefreshActions()
            clicking = false
        end)
        return button
    end

    ---Lays the actions out along their row.
    ---@return number width the row's
    ---@return number height the row's, 0 without actions
    local function LayoutActions()
        local x, height = 0, 0
        for i, def in ipairs(actionDefs) do
            local button = actions[i] or CreateAction()
            actions[i] = button
            button.def = def
            button.label:SetText(def.text)
            lib.SetTooltip(button, gui, def.text, def.tooltip)
            local w, h = button.label:GetStringWidth(), button.label:GetStringHeight()
            pixel.SetPixelSize(button, w, h)
            height = max(height, h)
            button:ClearAllPoints()
            pixel.SetPixelPoint(button, 'BOTTOMLEFT', actionRow, 'BOTTOMLEFT', x, 0)
            button:Show()
            -- a render follows a page change or a theme change, never a click, so the line snaps
            ApplyAction(button, true)
            x = x + w

            local separator = separators[i]
            if i < #actionDefs then
                if not separator then
                    separator = actionRow:CreateFontString(nil, 'OVERLAY')
                    separator:SetJustifyH('LEFT')
                    gui:ApplyFont(separator, 'small')
                    separator:SetText(SEPARATOR)
                    separators[i] = separator
                end
                local m = theme.textMuted
                separator:SetTextColor(m[1], m[2], m[3], dimmed and DIM_ALPHA or 1)
                separator:ClearAllPoints()
                pixel.SetPixelPoint(separator, 'LEFT', actionRow, 'LEFT', x, 0)
                separator:Show()
                x = x + separator:GetStringWidth()
            elseif separator then
                separator:Hide()
            end
        end
        for i = #actionDefs + 1, #actions do
            actions[i]:Hide()
            actions[i].def = nil
            if separators[i] then
                separators[i]:Hide()
            end
        end
        return x, height
    end

    -- Tabs --

    -- the tab row: label-width tabs at the track's right end, + after the last
    local row = CreateFrame('Frame', nil, panel)
    pixel.SetPixelHeight(row, TAB_HEIGHT)

    ---A tab's label: textSecondary at rest, lightening while hovered, the accent as it's selected.
    local function PaintLabel(tab)
        local l, h = lib.RowSelectionProgress(tab)
        local rest, hi, ac = theme.textSecondary, theme.textPrimary, theme.accent
        local r = rest[1] + (hi[1] - rest[1]) * h * HOVER_LIGHTEN
        local g = rest[2] + (hi[2] - rest[2]) * h * HOVER_LIGHTEN
        local b = rest[3] + (hi[3] - rest[3]) * h * HOVER_LIGHTEN
        tab.label:SetTextColor(r + (ac[1] - r) * l, g + (ac[2] - g) * l, b + (ac[3] - b) * l, 1)
    end

    ---Aims a tab's selection at its state; a tab that just took on another value snaps there.
    local function ApplyTab(tab, instant)
        lib.SetRowSelection(tab, theme, tab.selected and 1 or 0, tab.hovered and not tab.selected and 1 or 0, instant)
        if instant then
            PaintLabel(tab)
        end
    end

    ---A tab standing on the panel's track; its stretch of it lights in the line style when selected.
    local function CreateTab()
        local tab = CreateFrame('Button', nil, row)
        pixel.SetPixelHeight(tab, TAB_HEIGHT)
        tab:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
        tab.label = tab:CreateFontString(nil, 'OVERLAY')
        gui:ApplyFont(tab.label, 'normal') -- SetText errors on a FontString with no font yet
        pixel.SetPixelPoint(tab.label, 'CENTER', tab, 'CENTER', 0, 0)
        lib.CreateRowSelection(tab, theme, 'bottom', true)

        tab:SetScript('OnUpdate', function(self, elapsed)
            if lib.StepRowSelection(self, theme, elapsed) then
                PaintLabel(self)
            end
        end)
        tab:SetScript('OnEnter', function(self)
            self.hovered = true
            ApplyTab(self)
        end)
        tab:SetScript('OnLeave', function(self)
            self.hovered = nil
            ApplyTab(self)
        end)
        tab:SetScript('OnClick', function(self, button)
            if button == 'RightButton' then
                if opts.onTabMenu then
                    safecall(opts.onTabMenu, self.value)
                end
                return
            end
            if not self.selected and opts.onTabSelect then
                safecall(opts.onTabSelect, self.value)
            end
        end)
        return tab
    end

    local tabs = {}

    local plus = CreateFrame('Button', nil, row)
    pixel.SetPixelSize(plus, TAB_HEIGHT, TAB_HEIGHT)
    plus.icon = plus:CreateTexture(nil, 'ARTWORK')
    plus.icon:SetTexture(theme.plusTexture)
    plus.icon:SetTexCoord(CROSS_CROP, 1 - CROSS_CROP, CROSS_CROP, 1 - CROSS_CROP)
    pixel.SetPixelSize(plus.icon, CROSS * (1 - CROSS_CROP * 2), CROSS * (1 - CROSS_CROP * 2))
    pixel.SetPixelSnap(plus.icon)
    pixel.SetPixelPoint(plus.icon, 'CENTER', plus, 'CENTER', 0, 0)

    ---@param hovered boolean?
    function plus:Paint(hovered)
        local c = hovered and theme.accent or theme.textSecondary
        self.icon:SetVertexColor(c[1], c[2], c[3], 1)
    end

    plus:SetScript('OnClick', function()
        if addDef then
            safecall(addDef.onClick)
        end
    end)
    plus:SetScript('OnEnter', function(self)
        self:Paint(true)
        if addDef and addDef.tooltip then
            GameTooltip:SetOwner(self, 'ANCHOR_TOP')
            GameTooltip:SetText(addDef.tooltip, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    plus:SetScript('OnLeave', function(self)
        self:Paint()
        GameTooltip:Hide()
    end)

    ---@return number width the row's
    local function LayoutTabs()
        local on = not dimmed
        local x = 0
        for i, def in ipairs(tabDefs) do
            local tab = tabs[i] or CreateTab()
            tabs[i] = tab
            local changed = tab.value ~= def.value
            tab.value = def.value
            tab.selected = def.value == selectedTab
            tab.label:SetText(def.text)
            local width = floor(tab.label:GetStringWidth() + TAB_PAD * 2 + 0.5)
            pixel.SetPixelWidth(tab, width)
            tab:ClearAllPoints()
            pixel.SetPixelPoint(tab, 'BOTTOMLEFT', row, 'BOTTOMLEFT', x, 0)
            tab:EnableMouse(on)
            if not on then
                tab.hovered = nil
            end
            tab:Show()
            ApplyTab(tab, changed)
            x = x + width
        end
        for i = #tabDefs + 1, #tabs do
            tabs[i]:Hide()
            tabs[i].value = nil
        end

        plus:SetShown(addDef ~= nil)
        plus:EnableMouse(on)
        plus:Paint()
        plus:ClearAllPoints()
        pixel.SetPixelPoint(plus, 'BOTTOMLEFT', row, 'BOTTOMLEFT', x, 0)
        if addDef then
            x = x + TAB_HEIGHT
        end
        row:SetAlpha(on and 1 or DIM_ALPHA)
        return x
    end

    -- Switch --

    local switchLabel = panel:CreateFontString(nil, 'OVERLAY')
    switchLabel:SetJustifyH('LEFT')
    gui:ApplyFont(switchLabel, 'normal')

    local switch, switchFor

    ---The real Kaji toggle, made again when the flash message would name something else.
    local function EnsureSwitch()
        if switch and switchFor == switchDef.msgText then return end
        if switch then
            switch.glow:SetAlpha(1) -- pooled, so the next checkbox gets its glow back
            gui:ReleaseWidget(switch)
        end
        switch = gui:CreateCheckbox(panel, nil, {
            value = false,
            msgPopup = switchDef.msgText ~= nil,
            msgText = switchDef.msgText,
            callback = function(checked)
                if switchDef and switchDef.onToggle then
                    safecall(switchDef.onToggle, checked)
                end
            end,
        })
        pixel.SetPixelWidth(switch, switch.toggle:GetWidth())
        -- no on-state glow up here, so the lit tab stays the header's loudest accent
        switch.glow:SetAlpha(0)
        switchFor = switchDef.msgText
    end

    ---@param rowTop number the second line's top, down from the panel's
    ---@return number right where the switch's label ends, 0 without a switch
    local function LayoutSwitch(rowTop)
        switchLabel:SetShown(switchDef ~= nil)
        if not switchDef then
            if switch then
                switch:Hide()
            end
            return 0
        end

        EnsureSwitch()
        -- under the title, centred on the tab row; the toggle hangs 14 below the checkbox's empty label line
        switch:ClearAllPoints()
        pixel.SetPixelPoint(switch, 'TOPLEFT', panel, 'TOPLEFT', INSET, -rowTop + 14 - (TAB_HEIGHT - switch.toggle:GetHeight()) / 2)
        switch:Show()
        switch:SetValue(switchDef.value and true or false, true)
        switch:SetEnabled(switchDef.enabled ~= false)
        switchLabel:SetText(switchDef.text or '')
        switchLabel:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
        switchLabel:ClearAllPoints()
        pixel.SetPixelPoint(switchLabel, 'LEFT', switch.toggle, 'RIGHT', theme.paddingMedium, 0)
        return INSET + switch.toggle:GetWidth() + theme.paddingMedium + switchLabel:GetStringWidth()
    end

    -- Setters --

    ---@param text string
    function header:SetTitle(text)
        titleText = text or ''
    end

    ---@param number? number shown faint behind the right end, two digits; nil hides it
    function header:SetIndex(number)
        index = number
    end

    ---The small words above the title. Each def: { text, tooltip?, onClick(def), isActive?: fun(): boolean,
    ---isDisabled?: fun(): boolean, keepLive?: boolean } — keepLive stays clickable while the header is dimmed.
    ---@param defs table[]
    function header:SetActions(defs)
        actionDefs = defs or {}
    end

    ---Re-aims the actions at their state, for state that changed outside the header (a view closed with
    ---Escape, say). A click's own changes fade however this is called.
    ---@param instant? boolean snap rather than fade
    function header:RefreshActions(instant)
        for _, button in ipairs(actions) do
            if button:IsShown() then
                ApplyAction(button, instant)
            end
        end
    end

    ---@param def? { text: string, value: boolean, enabled?: boolean, msgText?: string, onToggle: fun(checked: boolean) }
    function header:SetSwitch(def)
        switchDef = def
    end

    ---@param defs { value: any, text: string }[]
    ---@param selected any the value of the lit tab
    function header:SetTabs(defs, selected)
        tabDefs, selectedTab = defs or {}, selected
    end

    ---Lets every tab snap on the next render rather than fade, for when the tabs now stand for something else.
    function header:ResetTabs()
        for _, tab in ipairs(tabs) do
            tab.value = nil
        end
    end

    ---@param def? { tooltip?: string, onClick: fun() } nil hides the +
    function header:SetAddButton(def)
        addDef = def
    end

    ---Greys the tabs, the path and the actions for something switched off; the switch stays live.
    ---@param dim boolean
    function header:SetDimmed(dim)
        dimmed = dim and true or false
    end

    -- Render --

    ---Lays the header out from what the setters hold.
    ---@return number height for host:SetHeader
    function header:Render()
        lib.RefreshBackdrop(panel)
        lib.PaintCornerTicks(corners, theme)
        title:SetText(titleText)
        title:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
        ghost:SetText(index and format('%02d', index) or '')
        ghost:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], GHOST_ALPHA)
        halftone:SetVertexColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], theme.halftoneAlpha)

        local actionWidth, actionHeight = LayoutActions()
        pixel.SetPixelSize(actionRow, actionWidth, max(actionHeight, 1))
        actionRow:ClearAllPoints()
        pixel.SetPixelPoint(actionRow, 'TOPLEFT', panel, 'TOPLEFT', INSET, -TOP)

        local titleTop = TOP + (actionHeight > 0 and actionHeight + ACTION_GAP or 0)
        title:ClearAllPoints()
        pixel.SetPixelPoint(title, 'TOPLEFT', panel, 'TOPLEFT', INSET, -titleTop)
        -- the hairlines sit on whole pixels so the slash between them steps evenly
        local titleBottom = pixel.ToPixelGrid(titleTop + title:GetStringHeight() + UNDER_GAP) -- where the underline runs
        local rowTop = titleBottom + LINE_GAP
        local trackBottom = pixel.ToPixelGrid(rowTop + TAB_HEIGHT)

        local rowWidth = LayoutTabs()
        pixel.SetPixelWidth(row, rowWidth)
        row:ClearAllPoints()
        pixel.SetPixelPoint(row, 'BOTTOMRIGHT', panel, 'TOPRIGHT', -INSET, -trackBottom)

        -- the slash clears whichever is longer, the title or the switch's label
        local labelRight = LayoutSwitch(rowTop)
        local titleWidth = title:GetStringWidth()
        local top = pixel.ToPixelGrid(max(INSET + titleWidth, labelRight) + theme.paddingLarge)
        local bottom = top + trackBottom - titleBottom -- 45°, as the portrait headers' cut: one pixel across per pixel down
        local c = theme.widgetBorder
        underline:SetColorTexture(c[1], c[2], c[3], 1)
        track:SetColorTexture(c[1], c[2], c[3], 1)
        dive:SetColorTexture(c[1], c[2], c[3], 1)
        underline:ClearAllPoints()
        pixel.SetPixelPoint(underline, 'BOTTOMLEFT', panel, 'TOPLEFT', INSET, -titleBottom)
        pixel.SetPixelPoint(underline, 'BOTTOMRIGHT', panel, 'TOPLEFT', top, -titleBottom)
        track:ClearAllPoints()
        pixel.SetPixelPoint(track, 'BOTTOMLEFT', panel, 'TOPLEFT', bottom, -trackBottom)
        pixel.SetPixelPoint(track, 'BOTTOMRIGHT', panel, 'TOPRIGHT', -INSET, -trackBottom)
        -- exactly one physical pixel through the hairlines' centres, so the corners meet without a notch
        local px = pixel.ToPixelGrid(1)
        dive:SetThickness(px)
        dive:SetStartPoint('TOPLEFT', panel, top, px / 2 - titleBottom)
        dive:SetEndPoint('TOPLEFT', panel, bottom, px / 2 - trackBottom)

        fieldLeft, fieldBottom = top, trackBottom
        halftone:ClearAllPoints()
        pixel.SetPixelPoint(halftone, 'TOPLEFT', panel, 'TOPLEFT', top, -theme.borderSize)
        pixel.SetPixelPoint(halftone, 'BOTTOMRIGHT', panel, 'TOPRIGHT', -theme.borderSize, -trackBottom)
        cut:ClearAllPoints()
        pixel.SetPixelPoint(cut, 'TOPLEFT', panel, 'TOPLEFT', top, -titleBottom)
        pixel.SetPixelPoint(cut, 'BOTTOMRIGHT', panel, 'TOPLEFT', bottom, -trackBottom)
        LayoutField()
        rulerLeft, rulerTop = bottom, trackBottom
        LayoutRuler()

        -- a 22px face can measure 0 the first time on a fresh login, so place the slash again once it has loaded
        if titleWidth == 0 and titleText ~= '' then
            C_Timer.After(0, function()
                if frame:IsShown() then
                    header:Render()
                end
            end)
        end

        local alpha = dimmed and DIM_ALPHA or 1
        underline:SetAlpha(alpha)
        track:SetAlpha(alpha)
        dive:SetAlpha(alpha)

        return trackBottom + BOTTOM + MARGIN
    end

    gui:OnThemeChanged(function()
        if not frame:IsShown() then return end
        header:ResetTabs() -- repaint in the new colours rather than fading into them
        header:Render()
    end)

    return header
end

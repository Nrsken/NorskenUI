--[[
# Card & Row

* Cards are bordered containers with a vertical stack of rows.
* Rows are horizontal layout containers that manage the relative width of their child widgets.
* These are the layout primitives beneath the fluent Page layer, which is how pages are
  authored - see Page.lua. Build cards through `page:Card()` rather than calling
  CreateCard/CreateRow directly, so widgets are tracked, gated and reflowed for you.
* Both are pooled widgets. Releasing a card releases its rows, and releasing a row
  releases its widgets, so tearing down a page reclaims the whole tree (see Pool.lua).

## Example

    local card = page:Card('Appearance', 'all')
    card:Row(40):Slider('Thickness', { width = 0.5, value = db.Thickness })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local Mixin = Mixin
local ipairs = ipairs
local wipe = wipe
local tinsert = table.insert
local abs = math.abs

local CARD_TYPE = "Card"
local ROW_TYPE = "Row"
local HEADER_HEIGHT = 32

-- Card --

---@class KajiGUICardMixin : Frame
---@field gui KajiGUIInstance
---@field content Frame
---@field header Frame|BackdropTemplate
---@field titleText FontString
---@field headerHeight number
---@field contentHeight number
---@field rows table
---@field currentY number
---@field _leadPad? number
---@field _onHeightChanged? fun(card: KajiGUICard) set by the card stack, for rows that resize themselves
---@field _enabledHandler? fun(enabled: boolean) see FluentCard:SetEnabledHandler
---@field _yOffset number
local CardMixin = {}

---Re-anchors every entry in the vertical flow from the top, using the height each one was added
---with. Cheap enough to be the single layout path: a card holds a handful of rows.
function CardMixin:Relayout()
    local pad = self.gui.theme.paddingSmall
    local y = self._leadPad or 0

    for _, row in ipairs(self.rows) do
        local offset = y + (row._layoutOffsetY or 0)
        row:ClearAllPoints()
        pixel.SetPixelPoint(row, "TOPLEFT", self.content, "TOPLEFT", 0, -offset)
        pixel.SetPixelPoint(row, "TOPRIGHT", self.content, "TOPRIGHT", 0, -offset)
        y = y + (row._layoutHeight or 24) + (row._layoutSpacing or pad)
    end

    self.currentY = y
    pixel.SetPixelHeight(self.content, y > 0 and y or 1)
    self:UpdateHeight()
end

---Adds a row (or any frame) below the previous one.
---@param widget Frame
---@param height? number
---@param spacing? number trailing spacing; pass 0 for the last row
---@return Frame
function CardMixin:AddRow(widget, height, spacing)
    widget:SetParent(self.content)
    widget._card = self
    widget._layoutHeight = height or widget:GetHeight() or 24
    widget._layoutSpacing = spacing or self.gui.theme.paddingSmall

    tinsert(self.rows, widget)
    self:Relayout()

    return widget
end

function CardMixin:UpdateHeight()
    local totalHeight = self.headerHeight + self.currentY + self.gui.theme.paddingSmall * 2
    pixel.SetPixelHeight(self, totalHeight)
    self.contentHeight = totalHeight
end

---@return number
function CardMixin:GetContentHeight()
    return self.contentHeight
end

---Clears every row so the card can be repopulated (used by fluent card:Rebuild).
---Rows go back to the pool, and each takes its own widgets with it.
function CardMixin:Reset()
    for _, row in ipairs(self.rows) do
        -- Cut the link back to us first: a discarded row must not reflow the card we are rebuilding.
        row._card = nil
        self.gui:ReleaseWidget(row)
    end
    wipe(self.rows)

    self.currentY = 0
    self.contentHeight = 0
    self._leadPad = nil
    pixel.SetPixelHeight(self.content, 1)
    pixel.SetPixelHeight(self, self.headerHeight + self.gui.theme.paddingMedium * 2)
end

---Dims the card when disabled by the state manager. A card whose inner controls gate
---each other (see FluentCard:SetEnabledHandler) settles them here, after the manager
---has applied the plain per-widget state.
---@param enabled boolean
function CardMixin:SetEnabled(enabled)
    local alpha = enabled and 1 or 0.5
    self:SetAlpha(alpha)
    self.header:SetAlpha(alpha)
    self.titleText:SetAlpha(alpha)

    if self._enabledHandler then self._enabledHandler(enabled) end
end

---Y position the next card in a stack should start at.
---@return number
function CardMixin:GetNextOffset()
    return self._yOffset + self:GetContentHeight() + self.gui.theme.paddingSmall
end

---Only the card's own chrome. Rows and widgets are acquired in their own right, so the
---theme fire reaches them directly rather than being recursed into from here.
function CardMixin:UpdateColors()
    local theme = self.gui.theme
    lib.RefreshBackdrop(self)
    lib.RefreshBackdrop(self.header)
    self.titleText:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
end

---@param parent Frame
---@param title? string
---@param config table `{ yOffset?: number, width?: number }`
function CardMixin:OnAcquire(parent, title, config)
    local theme = self.gui.theme
    local yOffset = config.yOffset or 0
    local hasHeader = title ~= nil and title ~= ""

    self:SetParent(parent)
    self:ClearAllPoints()
    if config.width then
        pixel.SetPixelWidth(self, config.width)
        pixel.SetPixelPoint(self, "TOPLEFT", parent, "TOPLEFT", theme.paddingSmall, -yOffset)
    else
        pixel.SetPixelPoint(self, "TOPLEFT", parent, "TOPLEFT", theme.paddingSmall, -yOffset)
        pixel.SetPixelPoint(self, "RIGHT", parent, "RIGHT", -theme.paddingSmall, 0)
    end

    self._yOffset = yOffset
    self._enabledHandler = nil
    self._hasInternalWidgetState = nil
    self.currentY = 0
    self.contentHeight = 0
    self._leadPad = nil

    -- The header always exists and is hidden for an untitled card, so the height it
    -- contributes is the only thing that varies.
    self.headerHeight = hasHeader and HEADER_HEIGHT or 0
    self.header:SetShown(hasHeader)
    self.titleText:SetText(title or "")

    self.content:ClearAllPoints()
    pixel.SetPixelPoint(self.content, "TOPLEFT", self, "TOPLEFT",
        theme.paddingMedium, -self.headerHeight - theme.paddingSmall)
    pixel.SetPixelPoint(self.content, "TOPRIGHT", self, "TOPRIGHT",
        -theme.paddingMedium, -self.headerHeight - theme.paddingSmall)
    pixel.SetPixelHeight(self.content, 1)

    self:SetAlpha(1)
    self.header:SetAlpha(1)
    self.titleText:SetAlpha(1)
    self:UpdateColors()
    self:UpdateHeight()
    self:Show()
end

function CardMixin:OnRelease()
    self:Reset()
    self._onHeightChanged = nil
    self._enabledHandler = nil
    self._hasInternalWidgetState = nil
    self._refreshPositions = nil
    self.titleText:SetText("")
end

---@class KajiGUICard : KajiGUICardMixin

lib:RegisterWidgetType(CARD_TYPE, function(gui)
    local theme = gui.theme

    local card = CreateFrame("Frame", nil, gui._poolHost, "BackdropTemplate")
    card:EnableMouse(false)
    lib.SetBackdrop(card, gui, { bg = "bgLight", border = "border", edgeSize = "borderSize" })

    card.gui = gui
    card.contentHeight = 0
    card.rows = {}
    card.currentY = 0
    card.headerHeight = 0
    card._yOffset = 0

    local header = CreateFrame("Frame", nil, card, "BackdropTemplate")
    pixel.SetPixelHeight(header, HEADER_HEIGHT)
    pixel.SetPixelPoint(header, "TOPLEFT", card, "TOPLEFT", 0, 0)
    pixel.SetPixelPoint(header, "TOPRIGHT", card, "TOPRIGHT", 0, 0)
    lib.SetBackdrop(header, gui, { bg = "bgMedium", border = "border", edgeSize = "borderSize" })
    card.header = header

    local titleText = header:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(titleText, "LEFT", header, "LEFT", theme.paddingMedium, 0)
    gui:ApplyFont(titleText, "large")
    card.titleText = titleText

    local content = CreateFrame("Frame", nil, card)
    pixel.SetPixelHeight(content, 1)
    content:EnableMouse(false)
    card.content = content

    return Mixin(card, CardMixin)
end)

---Creates a card. Anchors full-width to the parent unless an explicit width is given.
---@param parent Frame
---@param title? string
---@param yOffset? number
---@param width? number
---@return KajiGUICard
function InstanceMixin:CreateCard(parent, title, yOffset, width)
    return self:BuildWidget(CARD_TYPE, parent, title, { yOffset = yOffset, width = width })
end

-- Row --

---@class KajiGUIRowMixin : Frame
---@field gui KajiGUIInstance
---@field widgets table
---@field _rowHeight number
---@field _card? KajiGUICard set when the row is added to a card
local RowMixin = {}

---Resizes the row to fit a widget that measured its own content, and reflows the card around it.
---This is the upward half of the layout: everything above the widget is anchored, so a taller
---widget only becomes visible once the row, the card and the stack all know about it.
---@param height number
function RowMixin:SetContentHeight(height)
    height = pixel.ToPixelGrid(height)
    if abs(height - (self._rowHeight or 0)) < 0.5 then return end

    self._rowHeight = height
    self._layoutHeight = height
    pixel.SetPixelHeight(self, height)

    local card = self._card
    if not card then return end

    card:Relayout()
    if card._onHeightChanged then card._onHeightChanged(card) end
end

---Adds a widget at a relative width. Widths in a row should sum to 1.0.
---@param widget Frame
---@param widthPct? number
---@param spacing? number
---@param xOffset? number
---@param yOffset? number
function RowMixin:AddWidget(widget, widthPct, spacing, xOffset, yOffset)
    widthPct = widthPct or 0.5
    spacing = spacing or self.gui.theme.paddingSmall
    xOffset = xOffset or 0
    yOffset = yOffset or 0

    widget:SetParent(self)

    if not widget.explicitHeight then
        pixel.SetPixelHeight(widget, self._rowHeight)
    end

    widget._widthPct = widthPct
    widget._spacing = spacing
    widget._xOffset = xOffset
    widget._yOffset = yOffset
    tinsert(self.widgets, widget)

    self:LayoutWidgets(self:GetWidth())
end

---Resolves every child's width from the row's own, left to right.
---Laid out on every insert rather than only from OnSizeChanged: a pooled row comes back
---at the width it was released at, so the size never changes and that event never fires.
---@param width number
function RowMixin:LayoutWidgets(width)
    if not width or width <= 0 then return end

    local pad = self.gui.theme.paddingSmall
    local x = 0
    local count = #self.widgets

    for i, widget in ipairs(self.widgets) do
        local spacing = (i == count) and 0 or (widget._spacing or pad)
        local widgetWidth = width * widget._widthPct - spacing
        widget:ClearAllPoints()
        pixel.SetPixelPoint(widget, "TOPLEFT", self, "TOPLEFT", x + (widget._xOffset or 0), widget._yOffset or 0)
        pixel.SetPixelWidth(widget, widgetWidth)
        -- Widgets that derive their inner layout from their width are told directly, for the
        -- same reason: an unchanged width raises no OnSizeChanged for them either.
        if widget.OnLayout then widget:OnLayout(widgetWidth) end
        x = x + widgetWidth + spacing
    end
end

---@param parent Frame
---@param _ any unused; Row takes (parent, config)
---@param config table `{ height?: number }`
function RowMixin:OnAcquire(parent, _, config)
    local height = config.height or 24

    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelHeight(self, height)
    self._rowHeight = height
    self:SetAlpha(1)
    self:Show()
end

function RowMixin:OnRelease()
    -- A row owns its widgets, so releasing it hands them back too. This is what makes a
    -- card teardown reclaim the whole subtree rather than orphaning it.
    self.gui:ReleaseAll(self.widgets)
    self._card = nil
    self._rowHeight = 24
    self._layoutHeight = nil
    self._layoutSpacing = nil
    self._layoutOffsetY = nil
end

---@class KajiGUIRow : KajiGUIRowMixin

lib:RegisterWidgetType(ROW_TYPE, function(gui)
    local row = CreateFrame("Frame", nil, gui._poolHost)
    row.gui = gui
    row:EnableMouse(false)
    row.widgets = {}
    row._rowHeight = 24

    Mixin(row, RowMixin)
    row:SetScript("OnSizeChanged", function(self, width) self:LayoutWidgets(width) end)

    return row
end)

---Horizontal layout container. Widget widths resolve on resize.
---@param parent Frame
---@param height? number
---@return KajiGUIRow
function InstanceMixin:CreateRow(parent, height)
    return self:BuildWidget(ROW_TYPE, parent, nil, { height = height })
end

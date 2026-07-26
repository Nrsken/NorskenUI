--[[
# Card & Row

* Cards are bordered containers with a vertical stack of rows.
* Rows are horizontal layout containers that manage the relative width of their child widgets.

## Example

    local card = GUI:CreateCard(scrollChild, 'Appearance', 0)
    local row = GUI:CreateRow(card.content, 40)
    row:AddWidget(slider, 0.5)
    card:AddRow(row, 40)

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local Mixin = Mixin
local ipairs = ipairs
local wipe = wipe
local tinsert = table.insert
local abs = math.abs

local WHITE = "Interface\\Buttons\\WHITE8X8"

-- Card --

---@class KajiGUICardMixin : Frame
---@field gui KajiGUIInstance
---@field content Frame
---@field header? Frame
---@field titleText? FontString
---@field headerHeight number
---@field contentHeight number
---@field rows table
---@field currentY number
---@field _leadPad? number
---@field _onHeightChanged? fun(card: KajiGUICard) set by the card stack, for rows that resize themselves
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

---Adds a left-aligned secondary-text label spanning the card width.
---@param text string
---@param size? "small"|"normal"|"large"|number
---@return FontString
function CardMixin:AddLabel(text, size)
    local theme = self.gui.theme
    local label = self.content:CreateFontString(nil, "OVERLAY")
    label:SetJustifyH("LEFT")
    self.gui:ApplyFont(label, size or "normal")
    label:SetText(text)
    label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)

    label._layoutHeight = label:GetStringHeight() or 14
    label._layoutSpacing = theme.paddingSmall
    tinsert(self.rows, label)
    self:Relayout()

    return label
end

---Adds a thin horizontal divider.
---@return Texture
function CardMixin:AddSeparator()
    local theme = self.gui.theme
    local sep = self.content:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelHeight(sep, theme.borderSize)
    sep:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], 0.5)

    -- The line sits padding below the previous row and takes the same padding again after it.
    sep._layoutOffsetY = theme.paddingSmall
    sep._layoutHeight = theme.borderSize
    sep._layoutSpacing = theme.paddingSmall * 2
    tinsert(self.rows, sep)
    self:Relayout()

    return sep
end

---Adds empty vertical space. Carried as trailing spacing on the last entry so the flow stays
---relayoutable, which is identical to advancing the cursor.
---@param amount? number
function CardMixin:AddSpacing(amount)
    amount = amount or self.gui.theme.paddingMedium
    local last = self.rows[#self.rows]

    if last then
        last._layoutSpacing = (last._layoutSpacing or 0) + amount
    else
        self._leadPad = (self._leadPad or 0) + amount
    end

    self:Relayout()
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
function CardMixin:Reset()
    for _, row in ipairs(self.rows) do
        -- Cut the link back to us first: a discarded row must not reflow the card we are rebuilding.
        row._card = nil
        if row.Hide then row:Hide() end
        if row.SetParent then row:SetParent(nil) end
    end
    wipe(self.rows)
    self.currentY = 0
    self.contentHeight = 0
    self._leadPad = nil
    pixel.SetPixelHeight(self.content, 1)
    pixel.SetPixelHeight(self, self.headerHeight + self.gui.theme.paddingMedium * 2)
end

---Dims the card when disabled by the state manager.
---@param enabled boolean
function CardMixin:SetEnabled(enabled)
    local alpha = enabled and 1 or 0.5
    self:SetAlpha(alpha)
    if self.header then self.header:SetAlpha(alpha) end
    if self.titleText then self.titleText:SetAlpha(alpha) end
end

---Y position the next card in a stack should start at.
---@return number
function CardMixin:GetNextOffset()
    return self._yOffset + self:GetContentHeight() + self.gui.theme.paddingSmall
end

---Creates a card. Anchors full-width to the parent unless an explicit width is given.
---@param parent Frame
---@param title string
---@param yOffset number
---@param width? number
---@return KajiGUICard
function InstanceMixin:CreateCard(parent, title, yOffset, width)
    local theme = self.theme
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:EnableMouse(false)

    if width then
        pixel.SetPixelWidth(card, width)
        pixel.SetPixelPoint(card, "TOPLEFT", parent, "TOPLEFT", theme.paddingSmall, -(yOffset or 0))
    else
        pixel.SetPixelPoint(card, "TOPLEFT", parent, "TOPLEFT", theme.paddingSmall, -(yOffset or 0))
        pixel.SetPixelPoint(card, "RIGHT", parent, "RIGHT", -theme.paddingSmall, 0)
    end

    card:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = theme.borderSize })
    card:SetBackdropColor(theme.bgLight[1], theme.bgLight[2], theme.bgLight[3], theme.bgLight[4])
    card:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], theme.border[4])

    card.gui = self
    card.contentHeight = 0
    card.rows = {}
    card._yOffset = yOffset or 0

    local headerHeight = 0
    if title and title ~= "" then
        headerHeight = 32

        local header = CreateFrame("Frame", nil, card, "BackdropTemplate")
        pixel.SetPixelHeight(header, headerHeight)
        pixel.SetPixelPoint(header, "TOPLEFT", card, "TOPLEFT", 0, 0)
        pixel.SetPixelPoint(header, "TOPRIGHT", card, "TOPRIGHT", 0, 0)
        header:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = theme.borderSize })
        header:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], theme.bgMedium[4])
        header:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
        card.header = header

        local titleText = header:CreateFontString(nil, "OVERLAY")
        pixel.SetPixelPoint(titleText, "LEFT", header, "LEFT", theme.paddingMedium, 0)
        self:ApplyFont(titleText, "large")
        titleText:SetText(title)
        titleText:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        card.titleText = titleText
    end
    card.headerHeight = headerHeight

    local content = CreateFrame("Frame", nil, card)
    pixel.SetPixelPoint(content, "TOPLEFT", card, "TOPLEFT", theme.paddingMedium, -headerHeight - theme.paddingSmall)
    pixel.SetPixelPoint(content, "TOPRIGHT", card, "TOPRIGHT", -theme.paddingMedium, -headerHeight - theme.paddingSmall)
    pixel.SetPixelHeight(content, 1)
    content:EnableMouse(false)
    card.content = content
    card.currentY = 0

    Mixin(card, CardMixin)
    card:UpdateHeight()

    ---@cast card KajiGUICard
    return card
end

-- Row --

---@class KajiGUIRowMixin : Frame
---@field widgets table
---@field nextX number
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
    widget:ClearAllPoints()
    pixel.SetPixelPoint(widget, "TOPLEFT", self, "TOPLEFT", self.nextX + xOffset, yOffset)

    if not widget.explicitHeight then
        pixel.SetPixelHeight(widget, self._rowHeight)
    end

    widget._widthPct = widthPct
    widget._spacing = spacing
    widget._xOffset = xOffset
    widget._yOffset = yOffset
    tinsert(self.widgets, widget)
    self.nextX = self.nextX + 10
end

---Horizontal layout container. Widget widths resolve on resize.
---@param parent Frame
---@param height? number
---@return KajiGUIRow
function InstanceMixin:CreateRow(parent, height)
    height = height or 24
    local row = CreateFrame("Frame", nil, parent)
    row.gui = self
    pixel.SetPixelHeight(row, height)
    row:EnableMouse(false)
    row.widgets = {}
    row.nextX = 0
    row._rowHeight = height

    Mixin(row, RowMixin)

    local pad = self.theme.paddingSmall
    row:SetScript("OnSizeChanged", function(self, width)
        local x = 0
        local count = #self.widgets
        for i, widget in ipairs(self.widgets) do
            local isLast = (i == count)
            local spacing = isLast and 0 or (widget._spacing or pad)
            local widgetWidth = width * widget._widthPct - spacing
            widget:ClearAllPoints()
            pixel.SetPixelPoint(widget, "TOPLEFT", self, "TOPLEFT", x + (widget._xOffset or 0), widget._yOffset or 0)
            pixel.SetPixelWidth(widget, widgetWidth)
            x = x + widgetWidth + spacing
        end
    end)

    ---@cast row KajiGUIRow
    return row
end

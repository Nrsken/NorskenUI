--[[
# Icon

* A square icon with an optional black border and an item-quality overlay.
* `width` is the widget's share of the row like any other widget, `size` is the icon itself
  and `align` says where the icon sits inside that share. `align = 'FILL'` drops the square
  and stretches the icon over the whole share instead, for swatches and bars.
* `text` attaches a label to one side of the icon, so an icon-plus-caption row needs one widget
  rather than an icon and a Text sharing a row. The label takes the leftover space on its side, and
  a TOP/BOTTOM label makes the widget taller instead of wider. A RIGHT label can carry a muted
  `description` line under it.
* For lists: `linkTo` draws a guide line from the previous icon down to this one, `dimmed` greys the
  icon and fades its text (an entry that is switched off), and `onClick(button)` fires on a click.
* `borderColor` tints the border, e.g. the accent on a picked toggle.
* `row = true` makes it a full-width button row: Button's chrome flush with the widget (fill, border,
  accent border and glow on hover, pressed fill), the icon centred with an even margin, label and
  description centred beside it. `rowHeight` makes the row taller than the icon.
* `tile = true` is the same button stood upright: the icon centred at the top, label and description
  centred under it, `tileHeight` tall. `disabled = true` greys it and keeps it unclickable, even when
  the page's state manager enables everything else.
* `button = true` frames the whole widget as a button (Button's fill, accent border and glow on hover,
  pressed fill), for a list of actions rather than a list of things.

## Examples

    row:Icon({ width = 0.2, size = 24, align = 'RIGHT', itemID = 211878 })
    row:Icon({ width = 0.5, align = 'FILL' })
    GUI:CreateIcon(parent, { size = 32, texture = 'Interface\\Icons\\INV_Misc_QuestionMark' })

    -- A tooltip filler hands the tooltip to the game, for a real spell or item tooltip.
    row:Icon({ size = 24, texture = icon, tooltip = function(t) t:SetSpellByID(spellID) end })

    -- Icon with its caption to the right; hovering either shows the tooltip.
    row:Icon({
        width = 1,
        size = 24,
        texture = icon,
        tooltip = function(t) t:SetSpellByID(spellID) end,
        text = { text = spellName, position = 'RIGHT', size = 'small' },
    })

--]]

---@class LibKaji-1.0
local lib = _G.LibStub and _G.LibStub('LibKaji-1.0', true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local Mixin = Mixin
local ipairs = ipairs
local C_Item = C_Item

local WIDGET_TYPE = "Icon"
local QUALITY_ATLAS_PATTERN = "|A:(Professions%-ChatIcon%-Quality%-Tier%d):%d+:%d+"
local QUESTION_MARK = 134400
local TEXT_SPACING = 6
local DIMMED_ALPHA = 0.4
local BUTTON_PAD = 4 -- the frame around a button icon, outside its share so the icon keeps its place
local BUTTON_GLOW_REACH = 8
local TILE_PAD = 10 -- a tile's icon below its top edge

-- Which side of the icon the label sits on, and how it reads there by default.
local TEXT_POSITIONS = {
    RIGHT = { justify = "LEFT" },
    LEFT = { justify = "RIGHT" },
    TOP = { justify = "CENTER", stacked = true },
    BOTTOM = { justify = "CENTER", stacked = true },
}

local floor = math.floor
local safecall = lib.safecall

local GetItemInfo = C_Item.GetItemInfo
local GetItemIconByID = C_Item.GetItemIconByID

---@class KajiGUIIconMixin : Frame
---@field gui KajiGUIInstance
---@field iconFrame Frame the square the icon actually occupies, placed inside the widget
---@field icon Texture
---@field border Frame|BackdropTemplate
---@field qualityFrame Frame
---@field qualityTexture Texture
---@field label FontString
---@field description FontString muted line under a RIGHT label
---@field guide Texture line up to the linked icon
---@field _size number
---@field _dimmed boolean
---@field _onClick? fun(button: string)
---@field _button boolean framed as a button
---@field chromeFill Texture the button frame's fill
---@field chromeEdges Texture[] its border, top/bottom/left/right
---@field _glow Texture
---@field _animateBorder fun(isHover: boolean)
---@field _syncBorder fun(r: number, g: number, b: number, a?: number)
---@field _disabled boolean? a page's state manager switched it off: faded, and clicks do nothing
---@field _align string
---@field _textPosition? string
---@field _textSpacing number
---@field _textColor? number[]
---@field _row boolean a full-width button row
---@field _tile boolean an upright button tile
---@field _locked boolean? configured disabled, which no SetEnabled undoes
local IconMixin = {}

---Shows the crafting-quality pip an item link carries, if any.
---@param itemID? number
function IconMixin:UpdateQuality(itemID)
    self.qualityTexture:Hide()
    if not itemID or not self.qualityFrame:IsShown() then return end

    local _, itemLink = GetItemInfo(itemID)
    if not itemLink then return end
    local atlas = itemLink:match(QUALITY_ATLAS_PATTERN)
    if atlas then
        self.qualityTexture:SetAtlas(atlas, false)
        self.qualityTexture:Show()
    end
end

---@param tex string|number
function IconMixin:SetTexture(tex)
    self.icon:SetTexture(tex)
end

---Replaces the caption's text, for a caption configured through `text`.
---@param text string
function IconMixin:SetLabel(text)
    self.label:SetText(text)
end

---@param id number
function IconMixin:SetItemID(id)
    self._itemID = id
    self.icon:SetTexture(GetItemIconByID(id) or QUESTION_MARK)
    self:UpdateQuality(id)
end

---@param enabled boolean
function IconMixin:SetEnabled(enabled)
    self._disabled = not enabled or self._locked
    self:SetAlpha(enabled and 1 or 0.5)
end

---Places the icon square inside the widget, and the label beside or above it.
function IconMixin:LayoutIcon()
    local frame, label = self.iconFrame, self.label

    frame:ClearAllPoints()
    label:ClearAllPoints()
    self.description:ClearAllPoints()

    if self._align == "FILL" then
        frame:SetAllPoints()
        return
    end

    pixel.SetPixelSize(frame, self._size, self._size)

    local align = self._align
    local position = self._textPosition
    local spec = position and TEXT_POSITIONS[position]

    -- A stacked label owns the full width, so the icon gives up its own side for a corner anchor.
    if spec and spec.stacked then
        local edge = position == "TOP" and "BOTTOM" or "TOP"
        local corner = align == "CENTER" and edge or edge .. align
        local labelEdge = position == "TOP" and "TOP" or "BOTTOM"

        pixel.SetPixelPoint(frame, corner, self, corner, 0, 0)
        pixel.SetPixelPoint(label, labelEdge .. "LEFT", self, labelEdge .. "LEFT", 0, 0)
        pixel.SetPixelPoint(label, labelEdge .. "RIGHT", self, labelEdge .. "RIGHT", 0, 0)

        return
    end

    if self._tile then
        pixel.SetPixelSize(frame, self._previewWidth or self._size, self._size)
        pixel.SetPixelPoint(frame, "TOP", self, "TOP", 0, -TILE_PAD)
        pixel.SetPixelPoint(label, "TOP", frame, "BOTTOM", 0, -self._textSpacing)
        pixel.SetPixelPoint(label, "LEFT", self, "LEFT", 2, 0)
        pixel.SetPixelPoint(label, "RIGHT", self, "RIGHT", -2, 0)
        pixel.SetPixelPoint(self.description, "TOP", label, "BOTTOM", 0, -2)
        pixel.SetPixelPoint(self.description, "LEFT", self, "LEFT", 2, 0)
        pixel.SetPixelPoint(self.description, "RIGHT", self, "RIGHT", -2, 0)
        return
    elseif self._row then
        -- The icon keeps the same margin on its left as above and below it; label and description centre on it together.
        pixel.SetPixelPoint(frame, "LEFT", self, "LEFT", floor((self:GetHeight() - self._size) / 2), 0)
        if self.description:IsShown() then
            pixel.SetPixelPoint(label, "BOTTOMLEFT", frame, "RIGHT", self._textSpacing, 1)
            pixel.SetPixelPoint(self.description, "TOPLEFT", frame, "RIGHT", self._textSpacing, -2)
            pixel.SetPixelPoint(self.description, "RIGHT", self, "RIGHT", 0, 0)
        else
            pixel.SetPixelPoint(label, "LEFT", frame, "RIGHT", self._textSpacing, 0)
        end
        pixel.SetPixelPoint(label, "RIGHT", self, "RIGHT", 0, 0)
        return
    elseif align == "RIGHT" then
        pixel.SetPixelPoint(frame, "RIGHT", self, "RIGHT", 0, 0)
    elseif align == "CENTER" then
        pixel.SetPixelPoint(frame, "CENTER", self, "CENTER", 0, 0)
    else
        pixel.SetPixelPoint(frame, "LEFT", self, "LEFT", 0, 0)
    end

    if position == "RIGHT" and self.description:IsShown() then
        -- Split around the icon's middle, so the two lines sit centred on it together.
        pixel.SetPixelPoint(label, "BOTTOMLEFT", frame, "RIGHT", self._textSpacing, 1)
        pixel.SetPixelPoint(label, "RIGHT", self, "RIGHT", 0, 0)
        pixel.SetPixelPoint(self.description, "TOPLEFT", frame, "RIGHT", self._textSpacing, -1)
        pixel.SetPixelPoint(self.description, "RIGHT", self, "RIGHT", 0, 0)
    elseif position == "RIGHT" then
        pixel.SetPixelPoint(label, "LEFT", frame, "RIGHT", self._textSpacing, 0)
        pixel.SetPixelPoint(label, "RIGHT", self, "RIGHT", 0, 0)
    elseif position == "LEFT" then
        pixel.SetPixelPoint(label, "RIGHT", frame, "LEFT", -self._textSpacing, 0)
        pixel.SetPixelPoint(label, "LEFT", self, "LEFT", 0, 0)
    end
end

function IconMixin:UpdateColors()
    lib.RefreshBackdrop(self.border)
    self:PaintChrome(false)
    local edge = self.gui.theme.widgetBorder
    -- The hover animator only paints while it runs, so the resting border is painted here too.
    self._syncBorder(edge[1], edge[2], edge[3], edge[4] or 1)
    for _, chrome in ipairs(self.chromeEdges) do chrome:SetColorTexture(edge[1], edge[2], edge[3], edge[4] or 1) end
    local border = self._borderColor
    if border then self.border:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1) end

    local theme = self.gui.theme
    local color = self._textColor or theme.textSecondary
    local alpha = self._dimmed and DIMMED_ALPHA or 1

    self.label:SetTextColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
    self.description:SetTextColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], alpha)
    self.guide:SetColorTexture(theme.widgetBorder[1], theme.widgetBorder[2], theme.widgetBorder[3], 1)
    self.icon:SetDesaturated(self._dimmed)
    self.icon:SetAlpha(alpha)
    if self.canvas then self.canvas:SetAlpha(alpha) end
end

---The button frame's fill, Button's resting and pressed colours.
---@param pressed boolean
function IconMixin:PaintChrome(pressed)
    local theme = self.gui.theme
    local color = pressed and theme.selectedBg or theme.bgMedium
    self.chromeFill:SetColorTexture(color[1], color[2], color[3], pressed and (color[4] or 1) or 0.9)
end

---@param parent Frame
---@param _ any unused; Icon takes (parent, config)
---@param config table
function IconMixin:OnAcquire(parent, _, config)
    local size = config.size or 24
    local itemID = config.itemID
    local text = config.text
    local spec = text and text.enabled ~= false and TEXT_POSITIONS[text.position or "RIGHT"]

    self:SetParent(parent)
    self:ClearAllPoints()

    self._size = size
    self._align = config.align or "LEFT"
    self._textPosition = spec and (text.position or "RIGHT") or nil
    self._textSpacing = (text and text.spacing) or TEXT_SPACING
    self._textColor = text and text.color or nil

    local height = size
    self._tile = config.tile == true
    self._previewWidth = self._tile and config.previewWidth or nil

    local description = spec and (self._tile or not spec.stacked) and text.description or nil
    self.gui:ApplyFont(self.description, "small")
    self.description:SetText(description or "")
    self.description:SetJustifyH(self._tile and "CENTER" or "LEFT")
    self.description:SetShown(description ~= nil and description ~= "")

    if spec then
        self.gui:ApplyFont(self.label, text.size or "normal")
        self.label:SetText(text.text or "")
        self.label:SetJustifyH(self._tile and "CENTER" or text.justify or spec.justify)
        self.label:SetWordWrap(false)
        self.label:Show()

        if spec.stacked then
            height = size + self._textSpacing + self.label:GetStringHeight()
        end
    else
        self.label:SetText("")
        self.label:Hide()
    end

    self._row = config.row == true
    if self._row then height = config.rowHeight or height end
    if self._tile then height = config.tileHeight or height end
    pixel.SetPixelSize(self, size, height)
    self.explicitHeight = self._align ~= "FILL" or nil
    self:LayoutIcon()
    -- A row's or tile's chrome is the widget's own edge; an icon button's frame sits outside its share.
    local pad = (self._row or self._tile) and 0 or BUTTON_PAD
    self.chromeFill:ClearAllPoints()
    pixel.SetPixelPoint(self.chromeFill, "TOPLEFT", self, "TOPLEFT", -pad, pad)
    pixel.SetPixelPoint(self.chromeFill, "BOTTOMRIGHT", self, "BOTTOMRIGHT", pad, -pad)

    lib.SetTooltip(self, self.gui, config.tooltipTitle, config.tooltip)
    self._onClick = config.onClick
    self._button = config.button == true or self._row or self._tile
    self.chromeFill:SetShown(self._button)
    for _, edge in ipairs(self.chromeEdges) do edge:SetShown(self._button) end
    lib.SetFrameGlow(self._glow, self.gui, 0)
    local interactive = config.tooltip ~= nil or config.onClick ~= nil
    -- A button is one target: the icon handing the hover over to its own frame would flicker the frame's state.
    self.iconFrame:EnableMouse(interactive and not self._button)

    -- With a label the icon is only part of what the reader sees, so the whole widget is the target.
    self:EnableMouse((spec ~= nil or self._button) and interactive)

    -- Floored to the pixel left of centre: a 1px line on an even icon's exact middle straddles two.
    local linked = config.linkTo
    self.guide:ClearAllPoints()
    if linked then
        pixel.SetPixelPoint(self.guide, "TOPLEFT", linked.iconFrame, "BOTTOMLEFT", floor(linked._size / 2), 0)
        pixel.SetPixelPoint(self.guide, "BOTTOMLEFT", self.iconFrame, "TOPLEFT", floor(size / 2), 0)
    end
    self.guide:SetShown(linked ~= nil)
    self._locked = config.disabled == true or nil
    self._disabled = self._locked
    self._dimmed = config.dimmed == true or config.disabled == true
    self._borderColor = config.borderColor

    self.border:SetShown(config.showBorder ~= false)
    self.qualityFrame:SetShown(config.showQuality ~= false and itemID ~= nil)

    self._itemID = itemID
    if itemID then
        self.icon:SetTexture(GetItemIconByID(itemID) or QUESTION_MARK)
    else
        self.icon:SetTexture(config.texture or QUESTION_MARK)
    end
    self:DrawCanvas(config.draw, size)
    self:UpdateQuality(itemID)

    self:SetAlpha(1)
    self:UpdateColors()
    self:Show()
end

---Hand the icon square to a draw callback instead of the texture; whatever an earlier one drew is hidden first.
---@param draw? fun(canvas: Frame, size: number, width: number): boolean? returns false to keep the texture after all
---@param size number
function IconMixin:DrawCanvas(draw, size)
    local canvas = self.canvas
    if canvas then
        for _, region in ipairs({ canvas:GetRegions() }) do region:Hide() end
        for _, child in ipairs({ canvas:GetChildren() }) do child:Hide() end
        canvas:Hide()
    end
    local drawn = false
    if draw then
        if not canvas then
            -- Inside the border like the icon texture, and under it, so a picture lines up with plain icons.
            canvas = CreateFrame("Frame", nil, self.iconFrame)
            pixel.SetPixelPoint(canvas, "TOPLEFT", self.iconFrame, "TOPLEFT", 1, -1)
            pixel.SetPixelPoint(canvas, "BOTTOMRIGHT", self.iconFrame, "BOTTOMRIGHT", -1, 1)
            self.canvas = canvas
        end
        -- Every draw: reparenting the pooled widget resets child levels.
        canvas:SetFrameLevel(self.iconFrame:GetFrameLevel())
        self.border:SetFrameLevel(self.iconFrame:GetFrameLevel() + 1)
        canvas:Show()
        drawn = draw(canvas, size - 2, (self._previewWidth or size) - 2) ~= false
        canvas:SetShown(drawn)
    end
    self.icon:SetShown(not drawn)
end

function IconMixin:OnRelease()
    self:DrawCanvas(nil, 0)
    self._row = false
    self._tile = false
    self._previewWidth = nil
    self._locked = nil
    self._onClick = nil
    self._disabled = nil
    self._dimmed = false
    self._borderColor = nil
    self.guide:Hide()
    self.guide:ClearAllPoints() -- never left anchored to an icon that is reused elsewhere
    self.description:SetText("")
    self.description:Hide()
    self.icon:SetDesaturated(false)
    self.icon:SetAlpha(1)
    self._itemID = nil
    self._textPosition = nil
    self._textColor = nil
    self.explicitHeight = nil
    self.icon:SetTexture(QUESTION_MARK)
    self.qualityTexture:Hide()
    self.label:SetText("")
    self.label:Hide()
    self.iconFrame:EnableMouse(false)
    self:EnableMouse(false)
    lib.ClearTooltip(self)
end

---@class KajiGUIIcon : KajiGUIIconMixin

---@class KajiGUIIconConfig
---@field size? number Icon size in pixels, independent of the widget's row width. Defaults to 24.
---@field align? 'LEFT'|'CENTER'|'RIGHT'|'FILL' Where the icon sits in the widget's width. FILL stretches it. Defaults to 'LEFT'.
---@field texture? string|number
---@field draw? fun(canvas: Frame, size: number): boolean? Draws its own picture over the icon square (a live thumbnail); return false to show `texture` instead.
---@field itemID? number
---@field showQuality? boolean
---@field showBorder? boolean
---@field tooltip? string|{ text?: string, default?: any }|fun(tooltip: GameTooltip, frame: Frame) Hovering the icon shows this. A function fills the tooltip itself, e.g. `function(t) t:SetSpellByID(id) end`.
---@field tooltipTitle? string Accent-colored title above a text tooltip. Ignored when `tooltip` is a filler function.
---@field text? KajiGUIIconTextConfig A label attached to one side of the icon.
---@field linkTo? KajiGUIIcon The previous icon in a list, joined to this one by a guide line.
---@field dimmed? boolean Greys the icon and fades its text, for a list entry that is switched off.
---@field onClick? fun(button: string) Fires on a click anywhere on the widget, with the mouse button.
---@field button? boolean Frames the widget as a button: fill, accent border and glow on hover, pressed fill.
---@field row? boolean A full-width button row: Button's chrome flush with the widget, icon and text centred in it.
---@field tile? boolean An upright button tile: icon at the top, label and description centred under it.
---@field tileHeight? number A tile's height.
---@field previewWidth? number A tile's picture wider than it is tall (`size`); `draw` is handed the width as its third argument.
---@field disabled? boolean Greyed and unclickable, whatever the page's state manager says.
---@field rowHeight? number A row's height when taller than the icon; the icon sits centred with an even margin.

---@class KajiGUIIconTextConfig
---@field text? string The label itself; colour escapes work as anywhere else.
---@field enabled? boolean Set false to keep the config but hide the label. Defaults to true.
---@field position? 'LEFT'|'RIGHT'|'TOP'|'BOTTOM' Which side of the icon it sits on. Defaults to 'RIGHT'.
---@field size? 'small'|'normal'|'large'|number Theme font size. Defaults to 'normal'.
---@field justify? 'LEFT'|'CENTER'|'RIGHT' Defaults to reading away from the icon.
---@field color? number[] Defaults to the theme's secondary text colour.
---@field spacing? number Gap between icon and label. Defaults to 6.
---@field description? string A muted second line under a RIGHT label.

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local container = CreateFrame("Frame", nil, gui._poolHost)
    container.gui = gui

    local iconFrame = CreateFrame("Frame", nil, container)
    container.iconFrame = iconFrame

    local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelPoint(iconTexture, "TOPLEFT", 1, -1)
    pixel.SetPixelPoint(iconTexture, "BOTTOMRIGHT", -1, 1)
    pixel.SetPixelSnap(iconTexture)
    lib.SetTextureZoom(iconTexture)
    container.icon = iconTexture

    -- The border and quality pip are always built and simply hidden when unwanted, so a
    -- recycled icon can never come back missing one.
    local border = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
    border:SetAllPoints()
    lib.SetBackdrop(border, gui, { border = { 0, 0, 0 }, borderAlpha = 1 })
    container.border = border

    local qualityFrame = CreateFrame("Frame", nil, iconFrame)
    qualityFrame:SetFrameLevel(iconFrame:GetFrameLevel() + 10)
    pixel.SetPixelSize(qualityFrame, 14, 14)
    pixel.SetPixelPoint(qualityFrame, "TOPLEFT", iconFrame, "TOPLEFT", -4, 4)
    container.qualityFrame = qualityFrame

    local qualityTexture = qualityFrame:CreateTexture(nil, "OVERLAY")
    qualityTexture:SetAllPoints()
    container.qualityTexture = qualityTexture

    -- Given the theme font up front: an icon built without a label still has SetText called on it.
    local label = container:CreateFontString(nil, "OVERLAY")
    gui:ApplyFont(label, "normal")
    label:Hide()
    container.label = label

    local description = container:CreateFontString(nil, "OVERLAY")
    description:SetJustifyH("LEFT")
    description:SetWordWrap(false)
    gui:ApplyFont(description, "small")
    description:Hide()
    container.description = description

    -- Behind the icons, so it runs from one icon's bottom edge to the next one's top.
    local guide = container:CreateTexture(nil, "BACKGROUND")
    pixel.SetPixelWidth(guide, gui.theme.borderSize)
    pixel.SetPixelSnap(guide)
    guide:Hide()
    container.guide = guide

    -- Textures on the container itself, so the label (OVERLAY) always draws over the fill; the glow goes under it.
    local fill = container:CreateTexture(nil, "BACKGROUND")
    pixel.SetPixelPoint(fill, "TOPLEFT", container, "TOPLEFT", -BUTTON_PAD, BUTTON_PAD)
    pixel.SetPixelPoint(fill, "BOTTOMRIGHT", container, "BOTTOMRIGHT", BUTTON_PAD, -BUTTON_PAD)
    pixel.SetPixelSnap(fill)
    fill:Hide()
    container.chromeFill = fill
    local edges = {}
    for i, sides in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = container:CreateTexture(nil, "BORDER")
        pixel.SetPixelPoint(edge, sides[1], fill, sides[1], 0, 0)
        pixel.SetPixelPoint(edge, sides[2], fill, sides[2], 0, 0)
        if i <= 2 then pixel.SetPixelHeight(edge, 1) else pixel.SetPixelWidth(edge, 1) end
        pixel.SetPixelSnap(edge)
        edge:Hide()
        edges[i] = edge
    end
    container.chromeEdges = edges
    container._glow = lib.CreateFrameGlow(fill, gui, BUTTON_GLOW_REACH, container)
    container._animateBorder, container._syncBorder = lib.Animations:CreateHoverColorAnimator(container,
        function(r, g, b, a)
            for _, edge in ipairs(edges) do edge:SetColorTexture(r, g, b, a or 1) end
        end,
        gui.theme.widgetBorder, gui.theme.accent, gui.theme.animDuration)

    -- Set once, reading the tooltip off the container, so a recycled icon can never show the
    -- previous occupant's content (see lib.SetTooltip).
    iconFrame:SetScript("OnEnter", function() lib.ShowTooltip(container) end)
    iconFrame:SetScript("OnLeave", function() lib.HideTooltip() end)
    container:SetScript("OnEnter", function(self)
        if self._button and not self._disabled then
            lib.SetFrameGlow(self._glow, self.gui, lib.GLOW_HOVER)
            self._animateBorder(true)
        end
        lib.ShowTooltip(self)
    end)
    container:SetScript("OnLeave", function(self)
        if self._button then
            lib.SetFrameGlow(self._glow, self.gui, 0)
            self._animateBorder(false)
            self:PaintChrome(false)
        end
        lib.HideTooltip()
    end)
    container:SetScript("OnMouseDown", function(self)
        if self._button and not self._disabled then self:PaintChrome(true) end
    end)

    local function Click(self, button)
        if container._button then container:PaintChrome(false) end
        if container._onClick and not container._disabled and self:IsMouseOver() then safecall(container._onClick, button) end
    end
    iconFrame:SetScript("OnMouseUp", Click)
    container:SetScript("OnMouseUp", Click)

    return Mixin(container, IconMixin)
end)

---@param parent Frame
---@param config? KajiGUIIconConfig
---@return KajiGUIIcon
function InstanceMixin:CreateIcon(parent, config)
    return self:BuildWidget(WIDGET_TYPE, parent, nil, config)
end

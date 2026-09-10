--[[
# Button

* A themed button with an optional icon and tooltip.

## Examples

    row:Button('Apply', {
        width = 0.5,
        callback = function() Apply() end,
    })
    GUI:CreateButton(parent, 'Select', { width = 110, image = iconID, callback = fn })

Pass `selected` (or call `SetSelected`) for a latched toggle. `selectionStyle` picks which
channel carries the latch: `"fill"` (the default) rests the button on the theme's selection
tint and keeps the label accent-colored throughout, `"text"` leaves the fill alone and moves
the accent onto the label, which rests on `textPrimary` while unlatched, and `"both"` runs
the two together. `"text"` is the convention skinned Blizzard frames follow, so it is the
one to pick for a button sitting among them.

Hover is signalled by the border in every style, so it never collides with the latch. A
button with no latch at all - a plain action - can take `hoverLabel` instead, which accents
the label on hover the way a skinned Blizzard button does.

`backgroundImage` fills the button with art instead of stretching it: the source is
scaled to cover the button and the overflowing axis is trimmed, so the art keeps its
aspect ratio and the button acts as a mask. Give `backgroundImageAspect` when the
source is not square.

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local Animations = lib.Animations
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local Mixin = Mixin

local WIDGET_TYPE = "Button"
local ICON_TEXT_GAP = 6

---@class KajiGUIButtonMixin : Button, BackdropTemplate
---@field gui KajiGUIInstance
---@field icon Texture
---@field text FontString
---@field _callback? fun()
---@field _tooltipTitle? string see lib.SetTooltip
---@field _tooltipContent? fun(tooltip: GameTooltip, frame: Frame) see lib.SetTooltip
---@field _bgColor number[]
---@field _bgAlpha number resting fill opacity
---@field _selectionStyle "fill"|"text"|"both"
---@field _hoverLabel boolean
---@field _hovered boolean
---@field _selected boolean
---@field _hasIcon boolean
---@field bgImage Texture
---@field _hasBackgroundImage boolean
---@field _backgroundAspect number source width/height, for the cover crop
---@field _imageColor? number[] icon tint; may be a live theme color table
---@field _iconSize number
---@field _iconSpan number
---@field _iconYOffset number
---@field _animateBorder fun(isHover: boolean)
---@field _syncBorder fun(r: number, g: number, b: number, a?: number)
local ButtonMixin = {}

---@param newLabel string
function ButtonMixin:SetLabel(newLabel)
    self.text:SetText(newLabel)
    self:LayoutContent()
end

---@param newImage string|number
function ButtonMixin:SetImage(newImage)
    self.icon:SetTexture(newImage)
end

---@param newImage? string|number nil clears the fill
---@param aspect? number source width/height (default 1)
function ButtonMixin:SetBackgroundImage(newImage, aspect)
    self._hasBackgroundImage = newImage ~= nil
    self._backgroundAspect = aspect or 1

    self.bgImage:SetShown(self._hasBackgroundImage)
    if not self._hasBackgroundImage then return end

    self.bgImage:SetTexture(newImage)
    self:UpdateBackgroundCrop()
end

---Cover fit: the source is scaled until it fills the button, then the axis that
---overflows is trimmed off centre - the button masks the art rather than stretching it.
function ButtonMixin:UpdateBackgroundCrop()
    if not self._hasBackgroundImage then return end

    local width, height = self:GetWidth(), self:GetHeight()
    if not width or width <= 0 or not height or height <= 0 then return end

    local aspect = self._backgroundAspect
    local buttonAspect = width / height
    local left, right, top, bottom = 0, 1, 0, 1

    if buttonAspect > aspect then
        local visible = aspect / buttonAspect
        top = (1 - visible) / 2
        bottom = 1 - top
    else
        local visible = buttonAspect / aspect
        left = (1 - visible) / 2
        right = 1 - left
    end

    self.bgImage:SetTexCoord(left, right, top, bottom)
end

---@param enabled boolean
function ButtonMixin:SetEnabled(enabled)
    if enabled then
        self:Enable()
    else
        self:Disable()
    end
    self:SetAlpha(enabled and 1 or 0.5)
    self:EnableMouse(enabled)
end

---@param newCallback fun()
function ButtonMixin:SetCallback(newCallback)
    self._callback = newCallback
end

---Resting fill: the selection tint while latched, the caller's background otherwise. Only
---the "text" style opts out, having handed the latch to the label instead.
function ButtonMixin:ApplyRestingColor()
    local spec = self._kajiBackdrop
    if not spec then return end

    if self._selected and self._selectionStyle ~= "text" then
        spec.bg, spec.bgAlpha = self._accentColor, 0.25
    else
        spec.bg, spec.bgAlpha = self._bgColor, self._bgAlpha
    end

    lib.RefreshBackdrop(self)

    -- RefreshBackdrop repaints the edge as well, which would drop the accent border on a
    -- click. The animator owns that edge, so hand it back and keep its tracked color in step.
    if self._hovered then
        local accent = self._accentColor
        self._syncBorder(accent[1], accent[2], accent[3], accent[4] or 1)
        self:SetBackdropBorderColor(accent[1], accent[2], accent[3], accent[4] or 1)
    end
end

---The accent marks the latch, or the hover for a `hoverLabel` button that has no latch to
---mark. Only the "fill" style opts out, keeping the accent throughout because there the
---background carries the state on its own.
function ButtonMixin:ApplyLabelColor()
    local accented = self._selectionStyle == "fill"
        or self._selected
        or (self._hoverLabel and self._hovered)

    local color = accented and self._accentColor or self.gui.theme.textPrimary
    self.text:SetTextColor(color[1], color[2], color[3], (color[4] or 1) * (self._labelAlpha or 1))
end

---Fade the label without fading the fill, for a button that stays clickable while the value it
---carries is empty. It rides the label color because SetTextColor's alpha overrides SetAlpha on a
---FontString, so a plain SetAlpha would be dropped by the next hover.
---@param alpha number
function ButtonMixin:SetLabelAlpha(alpha)
    self._labelAlpha = alpha
    self:ApplyLabelColor()
end

---@param selected boolean
function ButtonMixin:SetSelected(selected)
    self._selected = selected and true or false
    self:ApplyRestingColor()
    self:ApplyLabelColor()
end

---@return boolean
function ButtonMixin:IsSelected()
    return self._selected == true
end

---@param newTooltip string
function ButtonMixin:SetTooltip(newTooltip)
    self._tooltipTitle = newTooltip
end

---A filler writes the whole tooltip itself - header included - for content a plain
---string cannot carry, such as per-line colors. It supersedes the title.
---@param filler? fun(tooltip: GameTooltip, frame: Frame) see lib.SetTooltip
function ButtonMixin:SetTooltipContent(filler)
    self._tooltipContent = filler
end

---The icon/text block is centred against the button's width, which is only final once the
---row has resolved it - and OnAcquire runs before that, on whatever width the previous
---occupant left behind.
function ButtonMixin:OnLayout()
    self:LayoutContent()
    self:UpdateBackgroundCrop()
end

---Centres the icon and text as one block. Re-run on resize and whenever either changes.
function ButtonMixin:LayoutContent()
    local text = self.text:GetText() or ""
    local hasText = text ~= ""

    if not self._hasIcon then
        self.text:ClearAllPoints()
        pixel.SetPixelPoint(self.text, "CENTER")
        return
    end

    local span = self.text:GetStringWidth() + self._iconSize
    if hasText then span = span + ICON_TEXT_GAP end
    self._iconSpan = hasText and span or self._iconSize

    local width = self:GetWidth()
    if not width or width <= 0 then return end

    self.icon:ClearAllPoints()
    pixel.SetPixelPoint(self.icon, "LEFT", self, "LEFT", (width - self._iconSpan) / 2, self._iconYOffset)

    self.text:ClearAllPoints()
    if hasText then
        pixel.SetPixelPoint(self.text, "LEFT", self.icon, "RIGHT", ICON_TEXT_GAP, 0)
    end
end

function ButtonMixin:UpdateColors()
    local theme = self.gui.theme

    local accent = self._accentColor
    if not self._accentOverride then
        accent[1], accent[2], accent[3], accent[4] =
            theme.accent[1], theme.accent[2], theme.accent[3], theme.accent[4] or 1
    end

    -- The hover animator rests on the border color, so reseat it after a palette change.
    self._syncBorder(theme.border[1], theme.border[2], theme.border[3], theme.border[4] or 1)

    -- Both read the accent above, and the fill has to land after the reseat so a button
    -- repainted mid-hover keeps its accent edge.
    self:ApplyRestingColor()
    self:ApplyLabelColor()

    -- Re-tinted here rather than only on acquire: callers hand us a live theme table
    -- (theme.accent for the Anchors nudge arrows), whose contents change under us.
    if self._hasIcon then
        local color = self._imageColor
        if color then
            self.icon:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        else
            self.icon:SetVertexColor(1, 1, 1, 1)
        end
    end
end

---@param parent Frame
---@param buttonText? string
---@param config table
function ButtonMixin:OnAcquire(parent, buttonText, config)
    local theme = self.gui.theme
    local text = buttonText or "Button"
    local image = config.image
    local atlas = config.imageAtlas
    local imageSize = config.imageSize or 16

    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelHeight(self, config.height or 24)
    pixel.SetPixelWidth(self, config.width or 120)
    self.explicitHeight = config.height and true or nil

    self._bgColor = config.bgColor or theme.bgMedium
    self._bgAlpha = config.bgAlpha or 0.9
    self._selectionStyle = config.selectionStyle or "fill"
    self._hoverLabel = config.hoverLabel == true

    self.gui:ApplyFont(self.text, config.fontSize or "normal")

    local source = config.accentColor or theme.accent
    local accent = self._accentColor
    accent[1], accent[2], accent[3], accent[4] = source[1], source[2], source[3], source[4] or 1
    self._accentOverride = config.accentColor ~= nil

    self._selected = config.selected == true
    self._labelAlpha = config.labelAlpha
    self._callback = config.callback
    self._hasIcon = image ~= nil or atlas ~= nil
    self._imageColor = config.imageColor
    self._iconSize = imageSize
    self._iconYOffset = config.yOffset or 0

    -- A button's tooltip is a bare title above the button, not a labelled body.
    --lib.SetTooltip(self, self.gui, config.tooltip, nil, { anchor = "ANCHOR_TOP", x = 0, y = 4 })

    -- The "Default: x" line is only meaningful for a cvar-backed checkbox.
    local spec = config.tooltip
    if type(spec) == "table" then
        spec = { text = spec.text }
    end
    lib.SetTooltip(self, self.gui, buttonText, spec)

    self._kajiBackdrop = { bg = self._bgColor, bgAlpha = self._bgAlpha, border = "border", borderAlpha = 1 }

    -- The icon always exists; only its content and visibility change between uses.
    self.icon:SetShown(self._hasIcon)
    if self._hasIcon then
        pixel.SetPixelSize(self.icon, imageSize, imageSize)
        if atlas then
            self.icon:SetAtlas(atlas, false)
        else
            self.icon:SetTexture(image)
        end

        -- Rotation blurs on the pixel grid unless snapping is released first.
        local rotation = config.imageRotation or 0
        self.icon:SetTexelSnappingBias(rotation ~= 0 and 0 or 1)
        self.icon:SetSnapToPixelGrid(rotation == 0)
        self.icon:SetRotation(rotation)
    end

    local background = config.backgroundImage
    self:SetBackgroundImage(background, config.backgroundImageAspect)
    if background then
        local color = config.backgroundImageColor
        if color then
            self.bgImage:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        end
        self.bgImage:SetAlpha(config.backgroundImageAlpha or 1)
    end

    self.text:SetText(text)

    self:Enable()
    self:EnableMouse(true)
    self:SetAlpha(1)
    self:UpdateColors()
    self:LayoutContent()
    self:Show()
end

function ButtonMixin:OnRelease()
    self._callback = nil
    self._labelAlpha = nil
    self._accentOverride = nil
    self._selected = false
    self._selectionStyle = "fill"
    self._hoverLabel = false
    self._hovered = false
    self._bgAlpha = 0.9
    self._hasIcon = false
    self._imageColor = nil
    self._hasBackgroundImage = false
    self.bgImage:Hide()
    self.bgImage:SetTexCoord(0, 1, 0, 1)
    self.bgImage:SetVertexColor(1, 1, 1, 1)
    self.bgImage:SetAlpha(1)
    lib.ClearTooltip(self)
    self.text:SetText("")
    self.text:SetAlpha(1)
    self.icon:SetRotation(0)
    self.icon:SetVertexColor(1, 1, 1, 1)
    self.icon:SetDesaturated(false)
    -- SetAtlas writes texcoords that SetTexture would not clear for the next occupant.
    self.icon:SetTexCoord(0, 1, 0, 1)
    self.icon:Hide()
    self.explicitHeight = nil
end

---@class KajiGUIButton : KajiGUIButtonMixin

---@class KajiGUIButtonConfig
---@field tooltip? string
---@field callback? fun()
---@field image? string|number
---@field imageAtlas? string atlas name for the icon, in place of `image`
---@field imageSize? number
---@field imageRotation? number radians; releases pixel snapping so the rotated texture stays crisp
---@field imageColor? number[] vertex color applied to the image
---@field backgroundImage? string|number art that fills the button, cover-cropped to its rect
---@field backgroundImageAspect? number source width/height (default 1)
---@field backgroundImageAlpha? number opacity of the fill (default 1)
---@field backgroundImageColor? number[] vertex color applied to the fill
---@field width? number pixel width (default 120)
---@field height? number pixel height (default 24)
---@field bgColor? number[]
---@field bgAlpha? number resting fill opacity, overriding the default 0.9
---@field accentColor? number[] per-widget accent, overriding the theme's
---@field selected? boolean latch the button; selectionStyle decides how that reads
---@field selectionStyle? "fill"|"text"|"both" latched look: a tinted fill, an accent label, or the two together (default "fill")
---@field hoverLabel? boolean accent the label on hover; for a "text" button with no latch to mark
---@field labelAlpha? number label opacity, multiplied into the label color (default 1)
---@field fontSize? "small"|"normal"|"large"|number label font size (default "normal")

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local theme = gui.theme
    local button = CreateFrame("Button", nil, gui._poolHost, "BackdropTemplate")
    button.gui = gui
    lib.SetBackdrop(button, gui, { bg = "bgMedium", bgAlpha = 0.9, border = "border", borderAlpha = 1 })

    -- Above the backdrop's fill (BACKGROUND, sublevel 0) but below its edge, which
    -- BackdropTemplate draws on BORDER - so the border survives an opaque fill.
    local bgImage = button:CreateTexture(nil, "BACKGROUND", nil, 1)
    bgImage:SetAllPoints(button)
    bgImage:Hide()
    button.bgImage = bgImage

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:Hide()
    button.icon = icon

    local text = button:CreateFontString(nil, "OVERLAY")
    gui:ApplyFont(text, "normal")
    button.text = text

    Mixin(button, ButtonMixin)

    -- Button-owned copy: the hover animator holds this table, so OnAcquire writes into it.
    button._accentColor = { theme.accent[1], theme.accent[2], theme.accent[3], theme.accent[4] or 1 }

    button._animateBorder, button._syncBorder = Animations:CreateHoverColorAnimator(button,
        function(r, g, b, a) button:SetBackdropBorderColor(r, g, b, a) end,
        theme.border, button._accentColor, theme.animDuration)

    -- Every script is set once here and reads state from fields, so a recycled button
    -- never carries a previous caller's callback or stacks a second handler.
    button:SetScript("OnSizeChanged", function(self)
        self:LayoutContent()
        self:UpdateBackgroundCrop()
    end)
    button:SetScript("OnEnter", function(self)
        self._hovered = true
        self._animateBorder(true)
        self:ApplyLabelColor()
        lib.ShowTooltip(self)
    end)
    button:SetScript("OnLeave", function(self)
        self._hovered = false
        self._animateBorder(false)
        self:ApplyRestingColor()
        self:ApplyLabelColor()
        lib.HideTooltip()
    end)
    button:SetScript("OnMouseDown", function(self)
        local selected = self.gui.theme.selectedBg
        self:SetBackdropColor(selected[1], selected[2], selected[3], selected[4])
    end)
    button:SetScript("OnMouseUp", function(self)
        self:ApplyRestingColor()
    end)
    button:SetScript("OnClick", function(self)
        safecall(self._callback)
    end)

    return button
end)

---@param parent Frame
---@param buttonText? string
---@param config? KajiGUIButtonConfig
---@return KajiGUIButton
function InstanceMixin:CreateButton(parent, buttonText, config)
    return self:BuildWidget(WIDGET_TYPE, parent, buttonText, config)
end

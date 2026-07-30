--[[
# Button

* A themed button with an optional icon and tooltip.

## Examples

    row:Button('Apply', {
        width = 0.5,
        callback = function() Apply() end,
    })
    GUI:CreateButton(parent, 'Select', { width = 110, image = iconID, callback = fn })

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
---@field _bgColor number[]
---@field _hasIcon boolean
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

---@param newTooltip string
function ButtonMixin:SetTooltip(newTooltip)
    self._tooltipTitle = newTooltip
end

---The icon/text block is centred against the button's width, which is only final once the
---row has resolved it - and OnAcquire runs before that, on whatever width the previous
---occupant left behind.
function ButtonMixin:OnLayout()
    self:LayoutContent()
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
    lib.RefreshBackdrop(self)
    self.text:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    -- The hover animator rests on the border color, so reseat it after a palette change.
    self._syncBorder(theme.border[1], theme.border[2], theme.border[3], theme.border[4] or 1)

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
    local imageSize = config.imageSize or 16

    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelHeight(self, config.height or 24)
    pixel.SetPixelWidth(self, config.width or 120)
    self.explicitHeight = config.height and true or nil

    self._bgColor = config.bgColor or theme.bgMedium
    self._callback = config.callback
    self._hasIcon = image ~= nil
    self._imageColor = config.imageColor
    self._iconSize = imageSize
    self._iconYOffset = config.yOffset or 0

    -- A button's tooltip is a bare title above the button, not a labelled body.
    lib.SetTooltip(self, self.gui, config.tooltip, nil, { anchor = "ANCHOR_TOP", x = 0, y = 4 })

    self._kajiBackdrop = { bg = self._bgColor, bgAlpha = 0.9, border = "border", borderAlpha = 1 }

    -- The icon always exists; only its content and visibility change between uses.
    self.icon:SetShown(self._hasIcon)
    if self._hasIcon then
        pixel.SetPixelSize(self.icon, imageSize, imageSize)
        self.icon:SetTexture(image)

        -- Rotation blurs on the pixel grid unless snapping is released first.
        local rotation = config.imageRotation or 0
        self.icon:SetTexelSnappingBias(rotation ~= 0 and 0 or 1)
        self.icon:SetSnapToPixelGrid(rotation == 0)
        self.icon:SetRotation(rotation)
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
    self._hasIcon = false
    self._imageColor = nil
    lib.ClearTooltip(self)
    self.text:SetText("")
    self.icon:SetRotation(0)
    self.icon:SetVertexColor(1, 1, 1, 1)
    self.icon:Hide()
    self.explicitHeight = nil
end

---@class KajiGUIButton : KajiGUIButtonMixin

---@class KajiGUIButtonConfig
---@field tooltip? string
---@field callback? fun()
---@field image? string|number
---@field imageSize? number
---@field imageRotation? number radians; releases pixel snapping so the rotated texture stays crisp
---@field imageColor? number[] vertex color applied to the image
---@field width? number pixel width (default 120)
---@field height? number pixel height (default 24)
---@field bgColor? number[]

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local theme = gui.theme
    local button = CreateFrame("Button", nil, gui._poolHost, "BackdropTemplate")
    button.gui = gui
    lib.SetBackdrop(button, gui, { bg = "bgMedium", bgAlpha = 0.9, border = "border", borderAlpha = 1 })

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:Hide()
    button.icon = icon

    local text = button:CreateFontString(nil, "OVERLAY")
    gui:ApplyFont(text, "normal")
    button.text = text

    Mixin(button, ButtonMixin)

    button._animateBorder, button._syncBorder = Animations:CreateHoverColorAnimator(button,
        function(r, g, b, a) button:SetBackdropBorderColor(r, g, b, a) end,
        theme.border, theme.accent, theme.animDuration)

    -- Every script is set once here and reads state from fields, so a recycled button
    -- never carries a previous caller's callback or stacks a second handler.
    button:SetScript("OnSizeChanged", button.LayoutContent)
    button:SetScript("OnEnter", function(self)
        self._animateBorder(true)
        lib.ShowTooltip(self)
    end)
    button:SetScript("OnLeave", function(self)
        self._animateBorder(false)
        self:SetBackdropColor(self._bgColor[1], self._bgColor[2], self._bgColor[3], 0.9)
        lib.HideTooltip()
    end)
    button:SetScript("OnMouseDown", function(self)
        local selected = self.gui.theme.selectedBg
        self:SetBackdropColor(selected[1], selected[2], selected[3], selected[4])
    end)
    button:SetScript("OnMouseUp", function(self)
        self:SetBackdropColor(self._bgColor[1], self._bgColor[2], self._bgColor[3], 0.9)
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

--[[
# ColorPicker

* A color swatch with a hex readout that opens Blizzard's color picker on click.

## Examples

    row:ColorPicker('Custom Color', {
        width = 0.5,
        value = db.Color,
        callback = function(r, g, b, a)
            db.Color = { r, g, b, a }
        end,
    })

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
local ColorPickerFrame = ColorPickerFrame

local WIDGET_TYPE = "ColorPicker"

---@alias KajiGUIColorChanged fun(r: number, g: number, b: number, a: number)

---@class KajiGUIColorSwatch : Button, BackdropTemplate
---@field r number
---@field g number
---@field b number
---@field a number

---@class KajiGUIColorPickerMixin : Frame
---@field gui KajiGUIInstance
---@field swatch KajiGUIColorSwatch
---@field swatchBg Texture
---@field label FontString
---@field hexText FontString
---@field _callback? KajiGUIColorChanged
---@field _animateBorder fun(isHover: boolean)
---@field _syncBorder fun(r: number, g: number, b: number, a?: number)
local ColorPickerMixin = {}

---Applies a color without notifying the consumer. Acquiring a recycled widget must not
---look like the user just picked a color.
---@param r number
---@param g number
---@param b number
---@param a? number
function ColorPickerMixin:SetColorSilent(r, g, b, a)
    a = a or 1
    local swatch = self.swatch
    swatch.r, swatch.g, swatch.b, swatch.a = r, g, b, a
    -- The fill is the user's color, so it is stored on the backdrop spec rather than
    -- resolved from the theme (see UpdateColors).
    swatch._kajiBackdrop.bg = { r, g, b, a }
    swatch:SetBackdropColor(r, g, b, a)
    self.hexText:SetText("#" .. self.gui:RGBAToHex(r, g, b))
end

---@param r number
---@param g number
---@param b number
---@param a? number
function ColorPickerMixin:SetColor(r, g, b, a)
    self:SetColorSilent(r, g, b, a)
    safecall(self._callback, r, g, b, a or 1)
end

---@return number, number, number, number
function ColorPickerMixin:GetColor()
    return self.swatch.r, self.swatch.g, self.swatch.b, self.swatch.a
end

---@param enabled boolean
function ColorPickerMixin:SetEnabled(enabled)
    self:SetAlpha(enabled and 1 or 0.4)
    self.swatch:EnableMouse(enabled)
end

function ColorPickerMixin:UpdateColors()
    local theme = self.gui.theme
    lib.RefreshBackdrop(self.swatch)
    self.swatchBg:SetTexture(theme.colorSwatchTexture)
    self.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    self.hexText:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    self._syncBorder(theme.border[1], theme.border[2], theme.border[3], theme.border[4] or 1)
end

---@param parent Frame
---@param labelText? string
---@param config table
function ColorPickerMixin:OnAcquire(parent, labelText, config)
    local color = config.value or { 1, 1, 1, 1 }

    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelHeight(self, 34)

    self.label:SetText(labelText or "")
    self._callback = nil -- set after the initial color, so seeding never notifies
    self:SetColorSilent(color[1], color[2], color[3], color[4] or 1)
    self._callback = config.callback

    self.swatch:EnableMouse(true)
    self:SetAlpha(1)
    self:UpdateColors()
    self:Show()

    self.gui:RegisterSearchableWidget(self, labelText)
end

function ColorPickerMixin:OnRelease()
    self._callback = nil
    self.label:SetText("")
    self.hexText:SetText("")
end

---@class KajiGUIColorPicker : KajiGUIColorPickerMixin

---@class KajiGUIColorPickerConfig
---@field value? number[]
---@field callback? KajiGUIColorChanged

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local theme = gui.theme

    local row = CreateFrame("Frame", nil, gui._poolHost)
    row.gui = gui

    local label = row:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    gui:ApplyFont(label, "small")
    row.label = label

    -- Checkerboard behind the swatch, so a translucent color reads as translucent.
    local swatchBg = row:CreateTexture(nil, "BACKGROUND")
    pixel.SetPixelSize(swatchBg, 48, 24)
    pixel.SetPixelPoint(swatchBg, "TOPLEFT", row, "TOPLEFT", 0, -14)
    swatchBg:SetTexture(theme.colorSwatchTexture)
    swatchBg:SetAlpha(0.8)
    pixel.SetPixelSnap(swatchBg)
    row.swatchBg = swatchBg

    local swatch = CreateFrame("Button", nil, row, "BackdropTemplate") --[[@as KajiGUIColorSwatch]]
    pixel.SetPixelSize(swatch, 48, 24)
    pixel.SetPixelPoint(swatch, "TOPLEFT", row, "TOPLEFT", 0, -14)
    lib.SetBackdrop(swatch, gui, { bg = { 1, 1, 1, 1 }, border = "border", borderAlpha = 1 })
    swatch.r, swatch.g, swatch.b, swatch.a = 1, 1, 1, 1
    swatch.isKajiColorPicker = true
    swatch.colorPickerRow = row
    row.swatch = swatch

    local hexText = row:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(hexText, "LEFT", swatch, "RIGHT", 8, 0)
    gui:ApplyFont(hexText, "small")
    hexText:SetShadowColor(0, 0, 0, 0)
    row.hexText = hexText

    Mixin(row, ColorPickerMixin)

    row._animateBorder, row._syncBorder = Animations:CreateHoverColorAnimator(swatch,
        function(r, g, b, a) swatch:SetBackdropBorderColor(r, g, b, a) end,
        theme.border, theme.accent, theme.animDuration)

    swatch:SetScript("OnEnter", function() row._animateBorder(true) end)
    swatch:SetScript("OnLeave", function() row._animateBorder(false) end)
    swatch:SetScript("OnClick", function()
        local prevR, prevG, prevB, prevA = swatch.r, swatch.g, swatch.b, swatch.a
        local info = { r = prevR, g = prevG, b = prevB, opacity = prevA, hasOpacity = true }
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            row:SetColor(r or 1, g or 1, b or 1, a or 1)
        end
        info.opacityFunc = info.swatchFunc
        info.cancelFunc = function() row:SetColor(prevR, prevG, prevB, prevA) end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    return row
end)

---@param parent Frame
---@param labelText? string
---@param config? KajiGUIColorPickerConfig
---@return KajiGUIColorPicker
function InstanceMixin:CreateColorPicker(parent, labelText, config)
    return self:BuildWidget(WIDGET_TYPE, parent, labelText, config)
end

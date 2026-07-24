--[[
# ColorPicker

* A color swatch with a hex readout that opens Blizzard's color picker on click.

## Examples

    row:AddWidget(GUI:CreateColorPicker(row, 'Custom Color', {
        color = db.Color,
        callback = function(r, g, b, a)
            db.Color = { r, g, b, a }
        end,
    }))

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local Animations = lib.Animations
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local Mixin = Mixin
local ColorPickerFrame = ColorPickerFrame

---@alias KajiGUIColorChanged fun(r: number, g: number, b: number, a: number)

---@class KajiGUIColorSwatch : Button, BackdropTemplate
---@field r number
---@field g number
---@field b number
---@field a number

---@class KajiGUIColorPickerMixin : Frame
---@field gui KajiGUIInstance
---@field swatch KajiGUIColorSwatch
---@field hexText FontString
---@field _callback? KajiGUIColorChanged
local ColorPickerMixin = {}

---@param r number
---@param g number
---@param b number
---@param a? number
function ColorPickerMixin:SetColor(r, g, b, a)
    a = a or 1
    self.swatch.r, self.swatch.g, self.swatch.b, self.swatch.a = r, g, b, a
    self.swatch:SetBackdropColor(r, g, b, a)
    self.hexText:SetText("#" .. self.gui:RGBAToHex(r, g, b))
    safecall(self._callback, r, g, b, a)
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

---@class KajiGUIColorPicker : KajiGUIColorPickerMixin
---@field label FontString

---@class KajiGUIColorPickerConfig
---@field value? number[]
---@field callback? KajiGUIColorChanged

---@param parent Frame
---@param labelText string
---@param config KajiGUIColorPickerConfig
---@return KajiGUIColorPicker
function InstanceMixin:CreateColorPicker(parent, labelText, config)
    config = config or {}
    local gui = self
    local theme = self.theme
    local color = config.value or { 1, 1, 1, 1 }

    local row = CreateFrame("Frame", nil, parent) --[[@as KajiGUIColorPicker]]
    pixel.SetPixelHeight(row, 34)
    row.gui = gui

    local label = row:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    gui:ApplyFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    row.label = label

    local swatchBg = row:CreateTexture(nil, "BACKGROUND")
    pixel.SetPixelSize(swatchBg, 48, 24)
    pixel.SetPixelPoint(swatchBg, "TOPLEFT", row, "TOPLEFT", 0, -14)
    swatchBg:SetTexture(theme.colorSwatchTexture)
    swatchBg:SetAlpha(0.8)
    pixel.SetPixelSnap(swatchBg)

    local swatch = CreateFrame("Button", nil, row, "BackdropTemplate") --[[@as KajiGUIColorSwatch]]
    pixel.SetPixelSize(swatch, 48, 24)
    pixel.SetPixelPoint(swatch, "TOPLEFT", row, "TOPLEFT", 0, -14)
    swatch:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    swatch:SetBackdropColor(color[1], color[2], color[3], color[4] or 1)
    swatch:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
    swatch.r, swatch.g, swatch.b, swatch.a = color[1], color[2], color[3], color[4] or 1
    row.swatch = swatch

    local hexText = row:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(hexText, "LEFT", swatch, "RIGHT", 8, 0)
    gui:ApplyFont(hexText, "small")
    hexText:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    hexText:SetText("#" .. gui:RGBAToHex(color[1], color[2], color[3]))
    hexText:SetShadowColor(0, 0, 0, 0)
    row.hexText = hexText

    row._callback = config.callback

    Mixin(row, ColorPickerMixin)

    local animateBorder = Animations:CreateHoverColorAnimator(swatch,
        function(r, g, b, a)
            swatch:SetBackdropBorderColor(r, g, b, a)
        end,
        theme.border,
        theme.accent,
        theme.animDuration
    )

    swatch:SetScript("OnEnter", function() animateBorder(true) end)
    swatch:SetScript("OnLeave", function() animateBorder(false) end)
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

    gui:RegisterSearchableWidget(row, labelText)
    ---@cast row KajiGUIColorPicker
    return row
end

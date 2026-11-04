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
local C_Timer = C_Timer

local WIDGET_TYPE = "ColorPicker"
local THROTTLE_DELAY = 0.1 -- Blizzard's picker reports every mouse move, and consumers may rebuild on each

local mixedPick ---@type KajiGUIColorPicker? the mixed swatch waiting on the picker's Okay
local okayHooked = false

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
---@field _pendingColor? number[] the latest pick the callback hasn't seen yet
---@field _flushScheduled? boolean
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
    lib.ClearMixed(self) -- a pick gives them all this colour
    self:SetColorSilent(r, g, b, a)
    self._pendingColor = { r, g, b, a or 1 }
    if self._flushScheduled then return end
    self._flushScheduled = true
    C_Timer.After(THROTTLE_DELAY, function()
        self._flushScheduled = false
        self:FlushColor()
    end)
end

---Hand the consumer the latest pick now instead of waiting for the throttle.
function ColorPickerMixin:FlushColor()
    local color = self._pendingColor
    if not color then return end
    self._pendingColor = nil
    safecall(self._callback, color[1], color[2], color[3], color[4])
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
    self._syncBorder(theme.widgetBorder[1], theme.widgetBorder[2], theme.widgetBorder[3], theme.widgetBorder[4] or 1)
    lib.PaintMixed(self, self.label)
end

---@param parent Frame
---@param labelText? string
---@param config table
function ColorPickerMixin:OnAcquire(parent, labelText, config)
    local color = config.value or { 1, 1, 1, 1 }
    if config.mixed then
        color = { 0, 0, 0, 1 } -- black with no hex, as WA's
    end

    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelHeight(self, 34)

    self.label:SetText(labelText or "")
    lib.SetTooltip(self, self.gui, labelText) -- only shown while mixed, for the list of colours
    lib.SetNotice(self, self.gui, self.label, config.notice)
    lib.SetMixed(self, config.mixed, self._describeValue)
    self._pendingColor = nil
    self._callback = nil -- set after the initial color, so seeding never notifies
    self:SetColorSilent(color[1], color[2], color[3], color[4] or 1)
    if config.mixed then
        self.hexText:SetText("")
    end
    self._callback = config.callback

    self.swatch:EnableMouse(true)
    self:SetAlpha(1)
    self:UpdateColors()
    self:Show()

    self.gui:RegisterSearchableWidget(self, labelText)
end

function ColorPickerMixin:OnRelease()
    if mixedPick == self then
        mixedPick = nil
    end
    self:FlushColor() -- a page rebuilt or closed mid-drag still keeps the last pick
    self._callback = nil
    self.label:SetText("")
    self.hexText:SetText("")
    lib.ClearTooltip(self)
end

---@class KajiGUIColorPicker : KajiGUIColorPickerMixin

---@class KajiGUIColorPickerConfig
---@field value? number[]
---@field callback? KajiGUIColorChanged
---@field notice? KajiGUINotice a marker after the label, see lib.SetNotice
---@field mixed? KajiGUIMixedEntry[] the things it edits disagree: black with no hex, see lib.SetMixed

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
    lib.SetBackdrop(swatch, gui, { bg = { 1, 1, 1, 1 }, border = "widgetBorder", borderAlpha = 1 })
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
        theme.widgetBorder, theme.accent, theme.animDuration)

    -- a colour has no tooltip of its own; a mixed one lists what each one has
    row._describeValue = function(value)
        if not value then return "" end
        local hex = row.gui:RGBAToHex(value[1], value[2], value[3])
        return "|cff" .. hex .. "#" .. hex .. "|r"
    end

    swatch:SetScript("OnEnter", function()
        row._animateBorder(true)
        if row._mixed then
            lib.ShowTooltip(row)
        end
    end)
    swatch:SetScript("OnLeave", function()
        row._animateBorder(false)
        lib.HideTooltip()
    end)
    swatch:SetScript("OnClick", function()
        local prevR, prevG, prevB, prevA = swatch.r, swatch.g, swatch.b, swatch.a
        local wasMixed = row._mixed ~= nil
        local info = { r = prevR, g = prevG, b = prevB, opacity = prevA, hasOpacity = true }
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            if not wasMixed then
                row:SetColor(r or 1, g or 1, b or 1, a or 1)
            elseif mixedPick == row then
                row:SetColorSilent(r or 1, g or 1, b or 1, a or 1)
            end
        end
        info.opacityFunc = info.swatchFunc
        -- each one's own colour can't be put back from here, so a mixed swatch only previews until Okay
        info.cancelFunc = function()
            if not wasMixed then
                row:SetColor(prevR, prevG, prevB, prevA)
                return
            end
            if mixedPick ~= row then return end

            mixedPick = nil
            row:SetColorSilent(prevR, prevG, prevB, prevA)
            row.hexText:SetText("")
        end
        mixedPick = wasMixed and row or nil
        -- Okay is the only way out that skips cancelFunc, and it has no callback of its own
        if wasMixed and not okayHooked then
            okayHooked = true
            ColorPickerFrame.Footer.OkayButton:HookScript("OnClick", function()
                local picked = mixedPick
                if not picked then return end

                mixedPick = nil
                picked:SetColor(picked:GetColor())
            end)
        end
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

--[[
# Button

* A themed button with an optional icon and tooltip.

## Examples

    row:Button('Apply', {
        callback = function()
            Apply()
        end
    })
    GUI:CreateButton(parent, 'Select', {
        width = 110,
        image = iconID,
        callback = fn
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local Animations = lib.Animations
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local type = type
local Mixin = Mixin

---@class KajiGUIButtonMixin : Button, BackdropTemplate
---@field gui KajiGUIInstance
---@field icon? Texture
---@field text FontString
---@field _callback? fun()
---@field _tooltip? string
---@field _bgColor number[]
local ButtonMixin = {}

---@param newLabel string
function ButtonMixin:SetLabel(newLabel)
    self.text:SetText(newLabel)
end

---@param newImage string|number
function ButtonMixin:SetImage(newImage)
    if self.icon then
        self.icon:SetTexture(newImage)
    end
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
    self._tooltip = newTooltip
end

function ButtonMixin:UpdateColors()
    local theme = self.gui.theme
    local bg = self._bgColor
    self:SetBackdropColor(bg[1], bg[2], bg[3], 1)
    self:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
    self.text:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
end

---@class KajiGUIButton : KajiGUIButtonMixin

---@class KajiGUIButtonConfig
---@field tooltip? string
---@field callback? fun()
---@field image? string|number
---@field imageSize? number
---@field width? number pixel width (default 120)
---@field height? number pixel height (default 24)
---@field bgColor? number[]

---@param parent Frame
---@param buttonText? string
---@param config? KajiGUIButtonConfig
---@return KajiGUIButton
function InstanceMixin:CreateButton(parent, buttonText, config)
    if type(config) ~= "table" then config = {} end
    local gui = self
    local theme = self.theme
    local text = buttonText or "Button"
    local image = config.image
    local imageSize = config.imageSize or 16
    local height = config.height or 24
    local bgColor = config.bgColor or theme.bgMedium
    local yOffset = config.yOffset or 0

    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button.gui = gui
    pixel.SetPixelHeight(button, height)
    if config.height then button.explicitHeight = true end
    pixel.SetPixelWidth(button, config.width or 120)
    button._bgColor = bgColor
    button._callback = config.callback
    button._tooltip = config.tooltip
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    button:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], 1)
    button:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)

    local animateBorder = Animations:CreateHoverColorAnimator(button,
        function(r, g, b, a)
            button:SetBackdropBorderColor(r, g, b, a)
        end,
        theme.border,
        theme.accent,
        theme.animDuration
    )
    local contentWidth = 0
    local iconWidget

    if image then
        iconWidget = button:CreateTexture(nil, "ARTWORK")
        pixel.SetPixelSize(iconWidget, imageSize, imageSize)
        iconWidget:SetTexture(image)
        contentWidth = contentWidth + imageSize
    end

    local textWidget = button:CreateFontString(nil, "OVERLAY")
    gui:ApplyFont(textWidget, "normal")
    textWidget:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    textWidget:SetText(text)
    contentWidth = contentWidth + textWidget:GetStringWidth()

    if image and text and text ~= "" then
        contentWidth = contentWidth + 6
    end

    if iconWidget then
        local iconSpan = (text ~= "") and contentWidth or imageSize
        local function AlignIcon()
            local w = button:GetWidth()
            if not w or w <= 0 then return end
            iconWidget:ClearAllPoints()
            pixel.SetPixelPoint(iconWidget, "LEFT", button, "LEFT", (w - iconSpan) / 2, yOffset)
        end
        AlignIcon()
        button:SetScript("OnSizeChanged", AlignIcon)
        if text ~= "" then
            pixel.SetPixelPoint(textWidget, "LEFT", iconWidget, "RIGHT", 6, 0)
        end
    else
        pixel.SetPixelPoint(textWidget, "CENTER")
    end

    button:SetScript("OnEnter", function(btn)
        animateBorder(true)
        if btn._tooltip then
            GameTooltip:SetOwner(btn, "ANCHOR_TOP", 0, 4)
            GameTooltip:SetText(btn._tooltip, theme.accent[1], theme.accent[2], theme.accent[3], 1, false)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(btn)
        animateBorder(false)
        btn:SetBackdropColor(btn._bgColor[1], btn._bgColor[2], btn._bgColor[3], 1)
        GameTooltip:Hide()
    end)
    button:SetScript("OnMouseDown", function(btn)
        btn:SetBackdropColor(theme.selectedBg[1], theme.selectedBg[2], theme.selectedBg[3], theme.selectedBg[4])
    end)
    button:SetScript("OnMouseUp", function(btn)
        btn:SetBackdropColor(btn._bgColor[1], btn._bgColor[2], btn._bgColor[3], 1)
    end)
    button:SetScript("OnClick", function(btn)
        safecall(btn._callback)
    end)

    button.icon = iconWidget
    button.text = textWidget

    Mixin(button, ButtonMixin)

    ---@cast button KajiGUIButton
    return button
end

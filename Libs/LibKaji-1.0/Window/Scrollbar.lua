--[[
# Scrollbar

* A themed vertical scrollbar bound to a ScrollFrame, with pixel-snapped scrolling and mouse-wheel support.
* Self-restyles on theme change (subscribes to OnThemeChanged); callers never poke its colors.

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local Mixin = Mixin
local math_abs, math_max, math_min = math.abs, math.max, math.min

local SCROLLBAR_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}
local BORDER_ONLY_BACKDROP = {
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

---@class KajiGUIScrollbarMixin : Slider, BackdropTemplate
---@field thumb Texture
---@field thumbBorder Frame & BackdropTemplate
---@field onValueChanged? fun(self: Slider, value: number)
---@field _scrollFrame ScrollFrame
local ScrollbarMixin = {}

---Shows/hides the scrollbar for the given content vs. frame height and returns whether it is visible.
---@param contentHeight number
---@param frameHeight number
---@return boolean visible
function ScrollbarMixin:UpdateVisibility(contentHeight, frameHeight)
    local needsScrollbar = contentHeight > frameHeight
    if needsScrollbar then
        self:Show()
        -- Keep the range on the pixel grid: a fractional max would clamp values back onto
        -- fractions at the bottom of the scroll, defeating the snap below.
        self:SetMinMaxValues(0, pixel.ToPixelGrid(contentHeight - frameHeight))
    else
        self:Hide()
        self:SetMinMaxValues(0, 0)
        self._scrollFrame:SetVerticalScroll(0)
    end
    return needsScrollbar
end

---Creates a scrollbar for a ScrollFrame.
---@param scrollFrame ScrollFrame
---@param options? table { width?, thumbHeight?, padding?, scrollStep?, anchorToScrollFrame? }
---@return KajiGUIScrollbarMixin
function InstanceMixin:CreateScrollbar(scrollFrame, options)
    options = options or {}
    local width = options.width or 12
    local thumbHeight = options.thumbHeight or 30
    local padding = options.padding or { top = 0, bottom = 0, right = 0 }
    local scrollStep = options.scrollStep or 20

    local gui = self
    local theme = self.theme
    local parent = scrollFrame:GetParent()
    local anchorFrame = options.anchorToScrollFrame and scrollFrame or parent

    local scrollbar = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    pixel.SetPixelPoint(scrollbar, "TOPRIGHT", anchorFrame, "TOPRIGHT", -padding.right, -padding.top)
    pixel.SetPixelPoint(scrollbar, "BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", -padding.right, padding.bottom)
    pixel.SetPixelWidth(scrollbar, width)
    scrollbar:SetBackdrop(SCROLLBAR_BACKDROP)
    scrollbar:SetOrientation("VERTICAL")

    scrollbar:SetValueStep(pixel.GetMult())
    scrollbar:SetMinMaxValues(0, 1)
    scrollbar:SetValue(0)
    scrollbar:Hide()

    scrollbar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = scrollbar:GetThumbTexture()
    thumb:SetSize(width, thumbHeight)
    scrollbar.thumb = thumb

    local thumbBorder = CreateFrame("Frame", nil, scrollbar, "BackdropTemplate")
    pixel.SetPixelPoint(thumbBorder, "TOPLEFT", thumb, 0, 0)
    pixel.SetPixelPoint(thumbBorder, "BOTTOMRIGHT", thumb, 0, 0)
    thumbBorder:SetBackdrop(BORDER_ONLY_BACKDROP)
    scrollbar.thumbBorder = thumbBorder

    scrollbar._scrollFrame = scrollFrame

    thumb:HookScript("OnShow", function() thumbBorder:Show() end)
    thumb:HookScript("OnHide", function() thumbBorder:Hide() end)

    -- Colours: applied now and re-applied on every theme change.
    local function Restyle()
        scrollbar:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], theme.bgDark[4])
        scrollbar:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
        thumb:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.8)
        thumbBorder:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
    end
    Restyle()
    gui:OnThemeChanged(Restyle)

    local isSnapping = false
    scrollbar:SetScript("OnValueChanged", function(bar, value)
        scrollFrame:SetVerticalScroll(pixel.ToPixelGrid(value))
        if bar.onValueChanged then bar.onValueChanged(bar, value) end

        if isSnapping then return end
        local snappedValue = pixel.ToPixelGrid(value)
        if math_abs(value - snappedValue) > 0.001 then
            isSnapping = true
            bar:SetValue(snappedValue)
            isSnapping = false
        end
    end)

    local function OnMouseWheel(_, delta)
        local currentVal = scrollbar:GetValue()
        local minVal, maxVal = scrollbar:GetMinMaxValues()
        scrollbar:SetValue(math_max(minVal, math_min(maxVal, currentVal - delta * scrollStep)))
    end
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", OnMouseWheel)
    scrollbar:EnableMouseWheel(true)
    scrollbar:SetScript("OnMouseWheel", OnMouseWheel)

    Mixin(scrollbar, ScrollbarMixin)
    return scrollbar
end

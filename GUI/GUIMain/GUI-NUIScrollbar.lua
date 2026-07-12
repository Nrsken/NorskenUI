-- NRSKNUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Initialize GUI table
NRSKNUI.GUI = NRSKNUI.GUI or {}

-- Localization Setup
local CreateFrame = CreateFrame
local math_floor, math_abs, math_max, math_min = math.floor, math.abs, math.max, math.min

-- Cached backdrop tables
local SCROLLBAR_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}
local BORDER_ONLY_BACKDROP = {
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

---@class NUIScrollbarMixin : Slider, BackdropTemplate
---@field thumb Texture
---@field thumbBorder Frame & BackdropTemplate
---@field onValueChanged? fun(self: Slider, value: number)
---@field _scrollFrame ScrollFrame
local NUIScrollbarMixin = {}

---@param contentHeight number Total height of scrollable content
---@param frameHeight number Visible frame height
---@return boolean visible Whether the scrollbar is visible
function NUIScrollbarMixin:UpdateVisibility(contentHeight, frameHeight)
    local needsScrollbar = contentHeight > frameHeight
    if needsScrollbar then
        self:Show()
        self:SetMinMaxValues(0, contentHeight - frameHeight)
    else
        self:Hide()
        self:SetMinMaxValues(0, 0)
        self._scrollFrame:SetVerticalScroll(0)
    end
    return needsScrollbar
end

function NUIScrollbarMixin:ApplyThemeColors()
    local theme = NRSKNUI.Theme
    self:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
    self:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], theme.bgDark[4])
    self.thumb:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.8)
    self.thumbBorder:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
end

---@param scrollFrame ScrollFrame
---@param options? table
---@return NUIScrollbarMixin
function NRSKNUI.GUI.CreateScrollbar(scrollFrame, options)
    options = options or {}
    local width = options.width or 12
    local thumbHeight = options.thumbHeight or 30
    local padding = options.padding or { top = 0, bottom = 0, right = 0 }
    local scrollStep = options.scrollStep or 20

    local Theme = NRSKNUI.Theme
    local parent = scrollFrame:GetParent()
    local anchorFrame = options.anchorToScrollFrame and scrollFrame or parent

    -- Create scrollbar
    local scrollbar = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    scrollbar:SetPoint("TOPRIGHT", anchorFrame, "TOPRIGHT", -padding.right, -padding.top)
    scrollbar:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", -padding.right, padding.bottom)
    scrollbar:SetWidth(width)
    scrollbar:SetBackdrop(SCROLLBAR_BACKDROP)
    scrollbar:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    scrollbar:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], Theme.bgDark[4])
    scrollbar:SetOrientation("VERTICAL")

    -- Pixel-perfect stepping
    local pixelStep = NRSKNUI.PerfectPixel
    scrollbar:SetValueStep(pixelStep)
    scrollbar:SetMinMaxValues(0, 1)
    scrollbar:SetValue(0)
    scrollbar:Hide()

    -- Thumb texture
    scrollbar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = scrollbar:GetThumbTexture()
    thumb:SetSize(width, thumbHeight)
    thumb:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.8)
    scrollbar.thumb = thumb

    -- Border frame around thumb
    local thumbBorder = CreateFrame("Frame", nil, scrollbar, "BackdropTemplate")
    thumbBorder:SetPoint("TOPLEFT", thumb, 0, 0)
    thumbBorder:SetPoint("BOTTOMRIGHT", thumb, 0, 0)
    thumbBorder:SetBackdrop(BORDER_ONLY_BACKDROP)
    thumbBorder:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    scrollbar.thumbBorder = thumbBorder

    -- Store scrollFrame reference for mixin
    scrollbar._scrollFrame = scrollFrame

    -- Show/hide thumb border with thumb
    thumb:HookScript("OnShow", function() thumbBorder:Show() end)
    thumb:HookScript("OnHide", function() thumbBorder:Hide() end)

    -- Pixel snapping state
    local isSnapping = false
    local PIXEL_STEP = 8 / 15

    -- OnValueChanged with pixel snapping to prevent jiggle
    scrollbar:SetScript("OnValueChanged", function(self, value)
        -- Always scroll the frame first
        scrollFrame:SetVerticalScroll(value)

        -- Call custom handler if set
        if scrollbar.onValueChanged then
            scrollbar.onValueChanged(self, value)
        end

        if isSnapping then return end
        local scale = scrollFrame:GetEffectiveScale()
        local screenPixels = value * scale
        local snappedPixels = math_floor(screenPixels / PIXEL_STEP + 0.5) * PIXEL_STEP
        local snappedValue = snappedPixels / scale
        if math_abs(value - snappedValue) > 0.001 then
            isSnapping = true
            self:SetValue(snappedValue)
            isSnapping = false
        end
    end)

    -- Mouse wheel handler
    local function OnMouseWheel(_, delta)
        local currentVal = scrollbar:GetValue()
        local minVal, maxVal = scrollbar:GetMinMaxValues()
        local newVal = currentVal - (delta * scrollStep)
        scrollbar:SetValue(math_max(minVal, math_min(maxVal, newVal)))
    end

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", OnMouseWheel)
    scrollbar:EnableMouseWheel(true)
    scrollbar:SetScript("OnMouseWheel", OnMouseWheel)

    Mixin(scrollbar, NUIScrollbarMixin)

    return scrollbar
end

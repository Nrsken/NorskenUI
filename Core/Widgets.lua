---@class NRSKNUI
local NRSKNUI = select(2, ...)
local Theme = NRSKNUI.Theme

local CreateFrame = CreateFrame
local unpack = unpack
local pairs = pairs

-- Default backdrop colors
NRSKNUI.Media = {
    Background = { 0, 0, 0, 0.8 },
    Border     = { 0, 0, 0, 1 },
}

-- Icon zoom helper bcs blizz border uggy
-- Example Usage: NRSKNUI:ApplyZoom(auraIcon, 0.3)

---@param obj Frame
---@param zoom number
-- Helper function to apply a zoom effect to an icon texture
function NRSKNUI:ApplyZoom(obj, zoom)
    local texMin = 0.25 * zoom
    local texMax = 1 - 0.25 * zoom
    obj:SetTexCoord(texMin, texMax, texMin, texMax)
end

-- Add pixel-perfect borders to any frame
-- borderParent: optional frame to create textures on (for frame level control)
-- Returns the frame for chaining
-- Example Usage:
--[[
-- Simple usage example where borders are on the same frame:
NRSKNUI:AddBorders(frame, {0, 0, 0, 1})

-- Usage example with frame level control, borders on child frame:
local borderFrame = CreateFrame("Frame", nil, backdrop)
borderFrame:SetAllPoints(backdrop)
borderFrame:SetFrameLevel(backdrop:GetFrameLevel() + 1)
NRSKNUI:AddBorders(backdrop, {0, 0, 0, 1}, borderFrame)

frame:SetBorderColor(r, g, b, a)
]]

---@param frame Frame
---@param color table?
---@param borderParent Frame?
-- Helper function to create pixel-perfect borders on any frame
function NRSKNUI:AddBorders(frame, color, borderParent)
    if not frame then return end
    color = color or { 0, 0, 0, 1 }
    borderParent = borderParent or frame

    frame.borders = frame.borders or {}

    local function CreateBorder(point1, point2, width, height)
        local tex = borderParent:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetColorTexture(unpack(color))
        tex:SetTexelSnappingBias(0)
        tex:SetSnapToPixelGrid(false)

        if width then
            tex:SetWidth(width)
            tex:SetPoint("TOPLEFT", frame, point1, 0, 0)
            tex:SetPoint("BOTTOMLEFT", frame, point2, 0, 0)
        else
            tex:SetHeight(height)
            tex:SetPoint("TOPLEFT", frame, point1, 0, 0)
            tex:SetPoint("TOPRIGHT", frame, point2, 0, 0)
        end
        return tex
    end

    frame.borders.top = CreateBorder("TOPLEFT", "TOPRIGHT", nil, 1)

    frame.borders.bottom = borderParent:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.borders.bottom:SetHeight(1)
    frame.borders.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.borders.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.borders.bottom:SetColorTexture(unpack(color))
    frame.borders.bottom:SetTexelSnappingBias(0)
    frame.borders.bottom:SetSnapToPixelGrid(false)

    frame.borders.left = CreateBorder("TOPLEFT", "BOTTOMLEFT", 1, nil)

    frame.borders.right = borderParent:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.borders.right:SetWidth(1)
    frame.borders.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.borders.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.borders.right:SetColorTexture(unpack(color))
    frame.borders.right:SetTexelSnappingBias(0)
    frame.borders.right:SetSnapToPixelGrid(false)

    -- Add helper method to change border color
    function frame:SetBorderColor(r, g, b, a)
        if not self.borders then return end
        for _, tex in pairs(self.borders) do
            tex:SetColorTexture(r, g, b, a or 1)
        end
    end

    return frame
end

-- Create an icon frame with borders, icon texture, and text
-- Example usage:
--[[
local icon = NRSKNUI:CreateIconFrame(parent, size, {
    name = "MyIcon",
    zoom = 0.3,
    borderColor = {0, 0, 0, 1},
    textPoint = "CENTER",
    textOffset = {1, 0},
})
]]

---@param parent Frame
---@param size number
---@param options table?
-- Helper function to create a icon frame with borders, icon texture and text
function NRSKNUI:CreateIconFrame(parent, size, options)
    options = options or {}
    local name = options.name
    local zoom = options.zoom or 0.3
    local borderColor = options.borderColor or { 0, 0, 0, 1 }
    local textPoint = options.textPoint or "CENTER"
    local textOffset = options.textOffset or { 1, 0 }

    local frame = CreateFrame("Frame", name, parent)
    frame:SetSize(size, size)

    -- Add borders
    self:AddBorders(frame, borderColor)

    -- Icon texture with zoom
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints(frame)
    self:ApplyZoom(frame.icon, zoom)

    -- Text (in OVERLAY so it's above the icon)
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetFont(NRSKNUI.FONT, 12, "")
    frame.text:SetPoint(textPoint, frame, textPoint, textOffset[1], textOffset[2])

    -- Helper to update icon size
    function frame:SetIconSize(newSize)
        self:SetSize(newSize, newSize)
        self.icon:SetAllPoints(self)
    end

    return frame
end

-- Create a simple text frame with FontString
-- Example usage:
--[[
local textFrame = NRSKNUI:CreateTextFrame(parent, width, height, {
    name = "ExampleText",
    textPoint = "CENTER",
    textOffset = {0, 0},
})
]]

---@param parent Frame
---@param width number
---@param height number
---@param options table
-- Helper function to create a text frame with a FontString
function NRSKNUI:CreateTextFrame(parent, width, height, options)
    options = options or {}
    local name = options.name
    local textPoint = options.textPoint or "CENTER"
    local textOffset = options.textOffset or { 0, 0 }
    local color = options.color or { 1, 1, 1, 1 }

    local frame = CreateFrame("Frame", name, parent)
    frame:SetSize(width, height)

    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetPoint(textPoint, frame, textPoint, textOffset[1], textOffset[2])
    frame.text:SetFont(NRSKNUI.FONT, 12, "")
    frame.text:SetTextColor(color[1], color[2], color[3], color[4] or 1)

    return frame
end

-- Create a frame with solid background and pixel-perfect borders
-- Example usage:
--[[
local backdrop = NRSKNUI:CreateStandardBackdrop(parent, "MyBackdrop", 5, {0,0,0,0.8}, {0,0,0,1})
backdrop:SetBackgroundColor(r, g, b, a)
backdrop:SetBorderColor(r, g, b, a)
]]

---@param parent Frame
---@param name string
---@param frameLevel number
---@param bgColor table
---@param borderColor table
-- Helper function to create a standard backdrop frame with optional border and background color support
function NRSKNUI:CreateStandardBackdrop(parent, name, frameLevel, bgColor, borderColor)
    local backdrop = CreateFrame("Frame", name, parent, "BackdropTemplate")
    backdrop:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    backdrop:SetBackdropColor(unpack(bgColor))

    if frameLevel then
        backdrop:SetFrameLevel(frameLevel)
    end

    -- Add borders using shared helper
    self:AddBorders(backdrop, borderColor)

    -- Alias for consistency
    function backdrop:SetBackgroundColor(r, g, b, a)
        self:SetBackdropColor(r, g, b, a)
    end

    return backdrop
end

-- Create a button frame with backdrop, borders, and texture support
-- Example usage:
--[[
local button = NRSKNUI:CreateButtonFrame(parent, width, height, btnName, {
    name = "MyButton",
    bgColor = {0.1, 0.1, 0.1, 0.9},
    borderColor = {0, 0, 0, 1},
    highlightColor = {1, 1, 1, 0.1},
    pushedColor = {1, 1, 1, 0.05},
    text = true,
    textPoint = "CENTER",
    textOffset = {0, 0},
    icon = true,
    iconPoint = "LEFT",
    iconOffset = {4, 0},
    iconSize = 16,
})

button:SetButtonText("Click Me")
button:SetButtonIcon(texturePath)
button:SetBackgroundColor(r, g, b, a)
button:SetBorderColor(r, g, b, a)
button:SetHighlightColor(r, g, b, a)
button:SetTextColor(r, g, b, a)
]]

---@param parent Frame
---@param width number
---@param height number
---@param btnName string
---@param options table
-- Helper function to create a button frame with backdrop, borders, and texture support
function NRSKNUI:CreateButtonFrame(parent, width, height, btnName, options)
    -- Crate config, has defaults for all options to simplify usage when only a few custom settings are needed
    options = options or {}
    local name = btnName
    local bgColor = options.bgColor or { 0, 0, 0, 0.8 }
    local borderColor = options.borderColor or { 0, 0, 0, 1 }
    local borderHighlightColor = options.borderHighlightColor or { Theme.accent[1], Theme.accent[2], Theme.accent[3], 1 }
    local highlightColor = options.highlightColor or { 1, 1, 1, 0.1 }
    local pushedColor = options.pushedColor or { 1, 1, 1, 0.05 }

    -- Button positioning
    local btnPoint = options.btnPoint or "CENTER"
    local btnOffset = options.btnOffset or { 0, 0 }

    -- Text positioning
    local textPoint = options.textPoint or "CENTER"
    local textOffset = options.textOffset or { 0, 0 }

    local button = CreateFrame("Button", name, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetPoint(btnPoint, parent, btnPoint, btnOffset[1], btnOffset[2])

    -- Backdrop background
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    button:SetBackdropColor(unpack(bgColor))
    button._bgColor = bgColor

    -- Add borders
    self:AddBorders(button, borderColor)

    -- Highlight texture
    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints(button)
    button.highlight:SetColorTexture(unpack(highlightColor))
    button.highlight:SetBlendMode("ADD")

    -- Pushed texture
    button.pushed = button:CreateTexture(nil, "ARTWORK", nil, 1)
    button.pushed:SetAllPoints(button)
    button.pushed:SetColorTexture(unpack(pushedColor))
    button.pushed:Hide()

    -- Text
    if options.text then
        local shadowSettings = {}
        button.text = button:CreateFontString(nil, "OVERLAY")
        button.text:SetPoint(textPoint, button, textPoint, textOffset[1], textOffset[2])
        button.text:SetTextColor(1, 1, 1, 1)
        NRSKNUI:ApplyFontToText(button.text, "Expressway", 14, "SOFTOUTLINE", shadowSettings)
    end

    -- icon
    if options.icon then
        local iconPoint = options.iconPoint or "LEFT"
        local iconOffset = options.iconOffset or { 4, 0 }
        local iconSize = options.iconSize or 16

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(iconSize, iconSize)
        button.icon:SetPoint(iconPoint, button, iconPoint, iconOffset[1], iconOffset[2])

        if options.iconZoom then
            self:ApplyZoom(button.icon, options.iconZoom)
        end
    end

    -- Push/release visual feedback
    button:SetScript("OnMouseDown", function(self)
        if self:IsEnabled() then
            self.pushed:Show()
        end
    end)

    button:SetScript("OnMouseUp", function(self)
        self.pushed:Hide()
    end)

    button:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            self.highlight:Show()
            if borderHighlightColor then
                self:SetBorderColor(unpack(borderHighlightColor))
            end
        end
    end)

    button:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        if borderHighlightColor then
            self:SetBorderColor(unpack(borderColor))
        end
    end)

    -- Helper methods
    function button:SetButtonText(text)
        self.text:SetText(text)
    end

    function button:SetButtonIcon(texture)
        if self.icon then
            self.icon:SetTexture(texture)
        end
    end

    function button:SetBackgroundColor(r, g, b, a)
        self:SetBackdropColor(r, g, b, a)
        self._bgColor = { r, g, b, a }
    end

    function button:SetHighlightColor(r, g, b, a)
        self.highlight:SetColorTexture(r, g, b, a or 1)
    end

    function button:SetPushedColor(r, g, b, a)
        self.pushed:SetColorTexture(r, g, b, a or 1)
    end

    function button:SetTextColor(r, g, b, a)
        self.text:SetTextColor(r, g, b, a or 1)
    end

    function button:SetDisabledState(disabled)
        if disabled then
            self:Disable()
            self:SetAlpha(0.5)
        else
            self:Enable()
            self:SetAlpha(1)
        end
    end

    return button
end

-- Fade a frame to target alpha over duration, combat safe
function NRSKNUI:CombatSafeFade(frame, targetAlpha, duration)
    if frame._fadeTimer then frame._fadeTimer:Hide() end -- stop previous fade

    local startAlpha = frame:GetAlpha()
    local diff = targetAlpha - startAlpha
    if diff == 0 or duration <= 0 then
        frame:SetAlpha(targetAlpha)
        return
    end

    -- Create a tiny helper frame
    local fadeFrame = frame._fadeTimer or CreateFrame("Frame")
    fadeFrame:Show()
    fadeFrame.elapsed = 0

    fadeFrame:SetScript("OnUpdate", function(self, dt)
        self.elapsed = self.elapsed + dt
        local progress = math.min(self.elapsed / duration, 1)
        frame:SetAlpha(startAlpha + diff * progress)
        if progress >= 1 then
            self:Hide()
        end
    end)

    frame._fadeTimer = fadeFrame
end

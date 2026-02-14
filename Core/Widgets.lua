local _, NRSKNUI = ...

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
function NRSKNUI:CreateTextFrame(parent, width, height, options)
    options = options or {}
    local name = options.name
    local textPoint = options.textPoint or "CENTER"
    local textOffset = options.textOffset or { 0, 0 }

    local frame = CreateFrame("Frame", name, parent)
    frame:SetSize(width, height)

    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetPoint(textPoint, frame, textPoint, textOffset[1], textOffset[2])

    return frame
end

-- Create a frame with solid background and pixel-perfect borders
-- Example usage:
--[[
local backdrop = NRSKNUI:CreateStandardBackdrop(parent, "MyBackdrop", 5, {0,0,0,0.8}, {0,0,0,1})
backdrop:SetBackgroundColor(r, g, b, a)
backdrop:SetBorderColor(r, g, b, a)
]]
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

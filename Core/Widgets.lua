local _, NRSKNUI = ...

-- Localization
local Mixin = Mixin
local CreateFrame = CreateFrame
local unpack = unpack
local pairs = pairs

local widgetMixin = {}
function widgetMixin:CreateFrame(frameType, template)
    return Mixin(NRSKNUI:CreateFrame(frameType or 'Frame', nil, self, template), widgetMixin)
end

function widgetMixin:CreateBackdropFrame(frameType, template)
    local frame = self:CreateFrame(frameType, template)
    frame:AddBackdrop()
    return frame
end

do
    local statusBarMixin = {}
    function statusBarMixin:SetStatusBarColor(...)
        self:GetStatusBarTexture():SetVertexColor(...)
    end

    function statusBarMixin:SetStatusBarColorFromBoolean(...)
        self:GetStatusBarTexture():SetVertexColorFromBoolean(...)
    end

    function widgetMixin:CreateStatusBar(template)
        local statusBar = Mixin(self:CreateFrame('StatusBar', template), statusBarMixin)
        local texture = statusBar:CreateTexture()
        texture:SetTexture(NRSKNUI.TEXTURE)
        statusBar:SetStatusBarTexture(texture)

        return statusBar
    end

    function widgetMixin:CreateBackdropStatusBar(template)
        local statusBar = self:CreateStatusBar(template)
        statusBar:AddBackdrop()
        statusBar:SetBackgroundColor(0, 0, 0, 0.8)
        return statusBar
    end
end

do
    local textureMixin = {}
    function textureMixin:SetColorTextureFromBoolean(...)
        self:SetColorTexture(1, 1, 1) -- reset color texture first
        self:SetVertexColorFromBoolean(...)
    end

    local createTexture = CreateFrame('Frame').CreateTexture
    function widgetMixin:CreateTexture(layer, level)
        local texture = Mixin(createTexture(self, nil, layer, nil, level), textureMixin)
        NRSKNUI:PixelPerfect(texture)
        return texture
    end

    function widgetMixin:CreateIcon(layer, level)
        local icon = self:CreateTexture(layer, level)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        return icon
    end
end

do
    local textMixin = {}
    function textMixin:SetFontSize(size)
        self:SetFont(NRSKNUI.FONT, size or 16, 'OUTLINE')
    end

    function textMixin:SetFrameLevel(level)
        self:GetParent():SetFrameLevel(level)
    end

    function widgetMixin:CreateText(size)
        if not self.overlayParent then
            -- make sure text renders above other widgets
            self.overlayParent = CreateFrame('Frame', nil, self)
            self.overlayParent:SetAllPoints() -- needs a size so children can render
        end

        local text = Mixin(self.overlayParent:CreateFontString(nil, 'OVERLAY'), textMixin)
        text:SetFontSize(size)
        text:SetWordWrap(false)
        return text
    end
end

do
    local cooldownMixin = {}
    function cooldownMixin:SetTimeFont(size)
        self:GetRegions():SetFont(NRSKNUI.FONT, size or 16, 'OUTLINE')
    end

    function cooldownMixin:ClearTimePoints()
        self:GetRegions():ClearAllPoints()
    end

    function cooldownMixin:SetTimePoint(...)
        self:GetRegions():SetPoint(...)
    end

    function cooldownMixin:SetIgnoreGlobalCooldown(state)
        self:SetMinimumCountdownDuration(state and 1500 or 0)
    end

    function widgetMixin:CreateCooldown(anchor)
        local cooldown = Mixin(NRSKNUI:CreateFrame('Cooldown', nil, self, 'CooldownFrameTemplate'), cooldownMixin)
        cooldown:SetAllPoints(anchor or self)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        cooldown:SetSwipeColor(0, 0, 0, 0.9)
        cooldown:SetTimeFont()
        cooldown:SetIgnoreGlobalCooldown(true)
        return cooldown
    end

    -- expose creation globally
    function NRSKNUI:CreateCooldown(parent, anchor)
        return widgetMixin.CreateCooldown(parent, anchor)
    end
end

function widgetMixin:AddBackdrop(...)
    NRSKNUI:AddBackdrop(self, ...)
end

function widgetMixin:AddBorders(color)
    NRSKNUI:AddBorders(self, color)
end

-- Expose internally
function NRSKNUI:CreateFrame(...)
    return Mixin(CreateFrame(...), widgetMixin, NRSKNUI.eventMixin)
end

NRSKNUI.widgetMixin = widgetMixin

-- Add pixel-perfect borders to any frame
-- Returns the frame for chaining
-- Example Usage:
--[[
NRSKNUI:AddBorders(frame, {0, 0, 0, 1})
frame:SetBorderColor(r, g, b, a)
]]
function NRSKNUI:AddBorders(frame, color)
    if not frame then return end
    color = color or { 0, 0, 0, 1 }

    frame.borders = frame.borders or {}

    local function CreateBorder(point1, point2, width, height)
        local tex = frame:CreateTexture(nil, "OVERLAY", nil, 7)
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
    frame.borders.bottom = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.borders.bottom:SetHeight(1)
    frame.borders.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.borders.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.borders.bottom:SetColorTexture(unpack(color))
    frame.borders.bottom:SetTexelSnappingBias(0)
    frame.borders.bottom:SetSnapToPixelGrid(false)

    frame.borders.left = CreateBorder("TOPLEFT", "BOTTOMLEFT", 1, nil)
    frame.borders.right = frame:CreateTexture(nil, "OVERLAY", nil, 7)
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
    local texMin = 0.25 * zoom
    local texMax = 1 - 0.25 * zoom
    frame.icon:SetTexCoord(texMin, texMax, texMin, texMax)

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

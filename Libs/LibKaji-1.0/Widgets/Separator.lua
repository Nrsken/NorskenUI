--[[
# Separator

* A thin horizontal divider, optionally with an accent label above it.

## Examples

API: card:Separator()
API: GUI:CreateSeparator(parent, 'Advanced', { useLabel = true })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local CreateColor = CreateColor
local Mixin = Mixin

local WIDGET_TYPE = "Separator"
local LABEL_OFFSET = 5

---@class KajiGUISeparatorMixin : Frame, BackdropTemplate
---@field gui KajiGUIInstance
---@field texture Texture
---@field label FontString
---@field _useLabel boolean
local SeparatorMixin = {}

---@param enabled boolean
function SeparatorMixin:SetEnabled(enabled)
    self:SetAlpha(enabled and 1 or 0.5)
end

function SeparatorMixin:UpdateColors()
    local theme = self.gui.theme
    local r, g, b = theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3]
    self.texture:SetGradient("HORIZONTAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, 1))
    self.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
end

---@param parent Frame
---@param labelText? string
---@param config table
function SeparatorMixin:OnAcquire(parent, labelText, config)
    local useLabel = config.useLabel or false
    local height = config.height or 6
    local offset = useLabel and LABEL_OFFSET or 0

    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelHeight(self, height)
    pixel.SetPixelPoint(self, "TOPLEFT", parent, "TOPLEFT", 0, 0)
    pixel.SetPixelPoint(self, "TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    -- The rule sits centred without a label and drops below it with one.
    self.texture:ClearAllPoints()
    pixel.SetPixelPoint(self.texture, "LEFT", self, "LEFT", 0, -offset)
    pixel.SetPixelPoint(self.texture, "RIGHT", self, "RIGHT", 0, -offset)

    self._useLabel = useLabel
    self.label:SetText(useLabel and (labelText or "") or "")
    self.label:SetShown(useLabel)

    self:SetAlpha(1)
    self:UpdateColors()
    self:Show()
end

function SeparatorMixin:OnRelease()
    self.label:SetText("")
    self._useLabel = false
end

---@class KajiGUISeparator : KajiGUISeparatorMixin

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local separator = CreateFrame("Frame", nil, gui._poolHost, "BackdropTemplate")
    separator.gui = gui

    local texture = separator:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelHeight(texture, 2)
    texture:SetColorTexture(1, 1, 1, 1)
    pixel.SetPixelSnap(texture)
    separator.texture = texture

    -- Created unconditionally and hidden when unused: building it only for the labelled
    -- variant would leave a recycled separator without one.
    local label = separator:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "LEFT", separator, "LEFT", 0, LABEL_OFFSET)
    gui:ApplyFont(label, "normal")
    label:Hide()
    separator.label = label

    return Mixin(separator, SeparatorMixin)
end)

---@param parent Frame
---@param labelText? string
---@param config? { useLabel?: boolean, height?: number }
---@return KajiGUISeparator
function InstanceMixin:CreateSeparator(parent, labelText, config)
    return self:BuildWidget(WIDGET_TYPE, parent, labelText, config)
end

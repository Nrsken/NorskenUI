--[[
# Separator

* A thin horizontal divider.
* With a label it is a heading inside a card: the accent label sits low in a taller row, with room
  above it, and a visible rule runs from the label to the right edge.

## Examples

API: card:Separator()
API: card:Separator('Advanced', { useLabel = true })
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
local LABEL_BOTTOM = 4 -- the label sits this far above the row's bottom
local RULE_GAP = 8 -- between the label and its rule

---@class KajiGUISeparatorMixin : Frame, BackdropTemplate
---@field gui KajiGUIInstance
---@field texture Texture
---@field rule Texture the labelled heading's line
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
    self.rule:SetColorTexture(theme.widgetBorder[1], theme.widgetBorder[2], theme.widgetBorder[3], 1)
    self.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
end

---@param parent Frame
---@param labelText? string
---@param config table
function SeparatorMixin:OnAcquire(parent, labelText, config)
    local useLabel = config.useLabel or false
    -- A labelled one fills its taller row, so the label and the rule both sit inside it.
    local height = config.height or (useLabel and self.gui.theme.rowHeightLabelSeparator or 6)

    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelHeight(self, height)
    pixel.SetPixelPoint(self, "TOPLEFT", parent, "TOPLEFT", 0, 0)
    pixel.SetPixelPoint(self, "TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    self._useLabel = useLabel
    self.label:SetText(useLabel and (labelText or "") or "")
    self.label:SetShown(useLabel)
    self.rule:SetShown(useLabel)
    self.texture:SetShown(not useLabel)

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
    pixel.SetPixelPoint(texture, "LEFT", separator, "LEFT", 0, 0)
    pixel.SetPixelPoint(texture, "RIGHT", separator, "RIGHT", 0, 0)
    separator.texture = texture

    -- Always created: a recycled separator may later be the labelled variant.
    local label = separator:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "BOTTOMLEFT", separator, "BOTTOMLEFT", 0, LABEL_BOTTOM)
    gui:ApplyFont(label, "medium")
    label:Hide()
    separator.label = label

    -- Centred on the label, so the heading reads as one line: "Filters ──────".
    local rule = separator:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelHeight(rule, gui.theme.borderSize)
    pixel.SetPixelPoint(rule, "LEFT", label, "RIGHT", RULE_GAP, 0)
    pixel.SetPixelPoint(rule, "RIGHT", separator, "RIGHT", 0, 0)
    pixel.SetPixelSnap(rule)
    rule:Hide()
    separator.rule = rule

    return Mixin(separator, SeparatorMixin)
end)

---@param parent Frame
---@param labelText? string
---@param config? { useLabel?: boolean, height?: number }
---@return KajiGUISeparator
function InstanceMixin:CreateSeparator(parent, labelText, config)
    return self:BuildWidget(WIDGET_TYPE, parent, labelText, config)
end

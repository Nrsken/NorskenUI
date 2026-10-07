--[[
# Separator

* A thin horizontal divider.
* With a label it is a heading inside a card: the accent label sits low in a taller row, with room
  above it, and a visible rule runs from the label to the right edge.
* `centered` makes the labelled heading smaller and centres it between two rules, for a group of
  rows inside a section that should rank below the section's own header.

## Examples

API: card:Separator()
API: card:Separator('Advanced', { useLabel = true })
API: card:Separator('Swipe', { useLabel = true, centered = true })
API: GUI:CreateSeparator(parent, 'Advanced', { useLabel = true })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local Mixin = Mixin

local WIDGET_TYPE = "Separator"
local LABEL_BOTTOM = 4 -- the label sits this far above the row's bottom
local RULE_GAP = 8 -- between the label and its rule

---@class KajiGUISeparatorMixin : Frame, BackdropTemplate
---@field gui KajiGUIInstance
---@field texture Texture
---@field rule Texture the labelled heading's line
---@field ruleLeft Texture a centred heading's line on the left of its label
---@field label FontString
---@field _useLabel boolean
local SeparatorMixin = {}

---@param enabled boolean
function SeparatorMixin:SetEnabled(enabled)
    self:SetAlpha(enabled and 1 or 0.5)
end

function SeparatorMixin:UpdateColors()
    local theme = self.gui.theme
    local line = theme.widgetBorder
    self.texture:SetColorTexture(line[1], line[2], line[3], 1)
    self.rule:SetColorTexture(line[1], line[2], line[3], 1)
    self.ruleLeft:SetColorTexture(line[1], line[2], line[3], 1)
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
    local centered = useLabel and config.centered == true
    local label = self.label
    label:ClearAllPoints()
    if centered then
        self.gui:ApplyFont(label, "small")
        pixel.SetPixelPoint(label, "CENTER", self, "CENTER", 0, 0)
    else
        self.gui:ApplyFont(label, "medium")
        pixel.SetPixelPoint(label, "BOTTOMLEFT", self, "BOTTOMLEFT", 0, LABEL_BOTTOM)
    end
    label:SetText(useLabel and (labelText or "") or "")
    label:SetShown(useLabel)
    self.rule:SetShown(useLabel)
    self.ruleLeft:SetShown(centered)
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
    pixel.SetPixelHeight(texture, gui.theme.borderSize)
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

    local ruleLeft = separator:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelHeight(ruleLeft, gui.theme.borderSize)
    pixel.SetPixelPoint(ruleLeft, "LEFT", separator, "LEFT", 0, 0)
    pixel.SetPixelPoint(ruleLeft, "RIGHT", label, "LEFT", -RULE_GAP, 0)
    pixel.SetPixelSnap(ruleLeft)
    ruleLeft:Hide()
    separator.ruleLeft = ruleLeft

    return Mixin(separator, SeparatorMixin)
end)

---@param parent Frame
---@param labelText? string
---@param config? { useLabel?: boolean, centered?: boolean, height?: number }
---@return KajiGUISeparator
function InstanceMixin:CreateSeparator(parent, labelText, config)
    return self:BuildWidget(WIDGET_TYPE, parent, labelText, config)
end

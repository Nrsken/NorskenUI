--[[
# SlimCheckbox

* A compact square tick for dense grids and lists, drawn like the Checkbox knob: accent fill, checkmark
  and glow fade in when checked. An optional label sits to its right. The callback fires on the click.
* `align = 'CENTER'` centres the box in its share of the row, for matrix cells without a label.

## Examples

    row:SlimCheckbox('Show on bars', {
        width = 0.5,
        value = db.Show,
        callback = function(checked) db.Show = checked end,
    })

    -- A label-less matrix cell with its own tooltip.
    row:SlimCheckbox(nil, {
        width = 0.12,
        align = 'CENTER',
        value = accepted[id] == true,
        tooltip = function(t) t:SetSpellByID(spellID) end,
        callback = function(checked) accepted[id] = checked end,
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local Mixin = Mixin
local floor = math.floor

local WIDGET_TYPE = "SlimCheckbox"
local BOX_SIZE = 16
local LABEL_GAP = 6

---@class KajiGUISlimCheckboxMixin : Frame
---@field gui KajiGUIInstance
---@field box KajiTickBox
---@field label FontString
---@field button Button
---@field _state boolean
---@field _hovered boolean
---@field _align 'LEFT'|'CENTER'
---@field _callback? fun(checked: boolean)
local SlimCheckboxMixin = {}

---@param instant? boolean
function SlimCheckboxMixin:ApplyState(instant)
    local theme = self.gui.theme
    self.box:SetChecked(self._state, instant)
    self.box:SetHovered(self._hovered, instant)

    local text = self._state and theme.textPrimary or theme.textSecondary
    self.label:SetTextColor(text[1], text[2], text[3], 1)
end

---Places the box for the current alignment, only final once the row has resolved the width.
---Offsets are floored to whole pixels: centring an odd leftover lands the box on a half pixel,
---and its 1px border and inset fill then round unevenly from one cell to the next.
---@param width? number
function SlimCheckboxMixin:LayoutContent(width)
    width = width or self:GetWidth()
    local mult = pixel.GetMult()
    local size = BOX_SIZE
    local x = 0
    if self._align == "CENTER" and width and width > size then
        x = floor((width - size) / 2 / mult) * mult
    end
    local y = floor((self:GetHeight() - size) / 2 / mult) * mult

    self.box:ClearAllPoints()
    pixel.SetPixelPoint(self.box, "TOPLEFT", self, "TOPLEFT", x, -y)
end

---@param width number
function SlimCheckboxMixin:OnLayout(width)
    self:LayoutContent(width)
end

---@param enabled boolean
function SlimCheckboxMixin:SetEnabled(enabled)
    self.box:SetEnabled(enabled)
    self:SetAlpha(enabled and 1 or 0.5)
    self.button:EnableMouse(enabled)
end

---@return boolean
function SlimCheckboxMixin:GetValue()
    return self._state
end

---@param value boolean
function SlimCheckboxMixin:SetValue(value)
    self._state = value == true
    self:ApplyState(true)
end

function SlimCheckboxMixin:UpdateColors()
    self.box:Repaint()
    self:ApplyState(true)
end

---@param parent Frame
---@param labelText? string
---@param config table
function SlimCheckboxMixin:OnAcquire(parent, labelText, config)
    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelHeight(self, config.height or BOX_SIZE + 4)
    self.explicitHeight = true

    self._state = config.value == true
    self._hovered = false
    self._align = config.align == "CENTER" and "CENTER" or "LEFT"
    self._callback = config.callback

    self.label:SetText(labelText or "")
    self.label:SetShown(labelText ~= nil and labelText ~= "")
    lib.SetTooltip(self, self.gui, labelText, config.tooltip)

    self.button:EnableMouse(true)
    self.box:SetEnabled(true)
    self:SetAlpha(1)
    self:LayoutContent()
    self:UpdateColors()
    self:Show()

    if labelText then self.gui:RegisterSearchableWidget(self, labelText) end
end

function SlimCheckboxMixin:OnRelease()
    self._callback = nil
    self._state = false
    self._hovered = false
    self.label:SetText("")
    lib.ClearTooltip(self)
end

---@class KajiGUISlimCheckbox : KajiGUISlimCheckboxMixin

---@class KajiGUISlimCheckboxConfig
---@field value? boolean
---@field callback? fun(checked: boolean)
---@field align? 'LEFT'|'CENTER' where the box sits in its share of the row, LEFT by default
---@field height? number
---@field tooltip? any string, table or a filler function, see lib.SetTooltip

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local row = CreateFrame("Frame", nil, gui._poolHost)
    row.gui = gui

    local box = lib.CreateTickBox(gui, row, BOX_SIZE)
    row.box = box

    local label = row:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "LEFT", box, "RIGHT", LABEL_GAP, 0)
    pixel.SetPixelPoint(label, "RIGHT", row, "RIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    gui:ApplyFont(label, "normal")
    row.label = label

    -- The whole share clicks, box and label as one, so a matrix cell is an easy target.
    local button = CreateFrame("Button", nil, row)
    button:SetAllPoints(row)
    button:RegisterForClicks("LeftButtonUp")
    row.button = button

    Mixin(row, SlimCheckboxMixin)

    button:SetScript("OnClick", function()
        row._state = not row._state
        row:ApplyState()
        safecall(row._callback, row._state)
    end)
    button:SetScript("OnEnter", function()
        row._hovered = true
        row:ApplyState()
        lib.ShowTooltip(row)
    end)
    button:SetScript("OnLeave", function()
        row._hovered = false
        row:ApplyState()
        lib.HideTooltip()
    end)

    return row
end)

---@param parent Frame
---@param labelText? string
---@param config? KajiGUISlimCheckboxConfig
---@return KajiGUISlimCheckbox
function InstanceMixin:CreateSlimCheckbox(parent, labelText, config)
    return self:BuildWidget(WIDGET_TYPE, parent, labelText, config)
end

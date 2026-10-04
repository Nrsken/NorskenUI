--[[
# Radio

* One option of a pick-one choice: a tick box, a title and an optional description.
* One widget per choice; rebuild on the callback so the chosen option's rows can sit under it.

## Examples

    local previous
    for _, mode in ipairs(MODES) do
        previous = card:Row(34):Radio(mode.text, {
            width = 1,
            description = mode.hint,
            selected = db.Mode == mode.id,
            linkTo = previous,
            callback = function()
                db.Mode = mode.id
                card:Rebuild()
            end,
        })
        if db.Mode == mode.id then
            card:Row(40, nil, 22):Dropdown('Profile', { width = 1, ... })
        end
    end

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local Mixin = Mixin

local WIDGET_TYPE = "Radio"
local DOT_SIZE = 14
local TEXT_GAP = 8
local TITLE_HEIGHT = 16
local DESCRIPTION_HEIGHT = 16

---@class KajiGUIRadioMixin : Frame
---@field gui KajiGUIInstance
---@field dot KajiTickBox
---@field guide Texture line up to the linked option's box
---@field title FontString
---@field description FontString
---@field button Button
---@field _selected boolean
---@field _hovered boolean
---@field _callback? fun()
local RadioMixin = {}

---@param instant? boolean
function RadioMixin:ApplyState(instant)
    local theme = self.gui.theme
    self.dot:SetChecked(self._selected, instant)
    self.dot:SetHovered(self._hovered, instant)

    local title = self._selected and theme.accent or theme.textPrimary
    self.title:SetTextColor(title[1], title[2], title[3], 1)
    self.description:SetTextColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 1)
    self.guide:SetColorTexture(theme.widgetBorder[1], theme.widgetBorder[2], theme.widgetBorder[3], 1)
end

---@param enabled boolean
function RadioMixin:SetEnabled(enabled)
    self.dot:SetEnabled(enabled)
    self:SetAlpha(enabled and 1 or 0.5)
    self.button:EnableMouse(enabled)
end

---@return boolean
function RadioMixin:GetValue()
    return self._selected
end

---@param selected boolean
function RadioMixin:SetValue(selected)
    self._selected = selected == true
    self:ApplyState(true)
end

function RadioMixin:UpdateColors()
    self.dot:Repaint()
    self:ApplyState(true)
end

---@param parent Frame
---@param titleText? string
---@param config table
function RadioMixin:OnAcquire(parent, titleText, config)
    local hasDescription = config.description ~= nil and config.description ~= ""

    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelHeight(self, hasDescription and TITLE_HEIGHT + DESCRIPTION_HEIGHT or TITLE_HEIGHT)
    self.explicitHeight = true

    self._selected = config.selected == true
    self._hovered = false
    self._callback = config.callback

    self.title:SetText(titleText or "")
    self.description:SetText(config.description or "")
    self.description:SetShown(hasDescription)
    lib.SetTooltip(self, self.gui, titleText, config.tooltip)

    local linked = config.linkTo
    self.guide:ClearAllPoints()
    if linked then
        pixel.SetPixelPoint(self.guide, "TOP", linked.dot, "BOTTOM", 0, 0)
        pixel.SetPixelPoint(self.guide, "BOTTOM", self.dot, "TOP", 0, 0)
    end
    self.guide:SetShown(linked ~= nil)

    self.button:EnableMouse(true)
    self.dot:SetEnabled(true)
    self:SetAlpha(1)
    self:UpdateColors()
    self:Show()

    if titleText then self.gui:RegisterSearchableWidget(self, titleText) end
end

function RadioMixin:OnRelease()
    self._callback = nil
    self._selected = false
    self._hovered = false
    self.title:SetText("")
    self.description:SetText("")
    self.guide:Hide()
    self.guide:ClearAllPoints() -- never left anchored to an option that is reused elsewhere
    lib.ClearTooltip(self)
end

---@class KajiGUIRadio : KajiGUIRadioMixin

---@class KajiGUIRadioConfig
---@field description? string one line under the title
---@field selected? boolean
---@field callback? fun() fires when an unselected option is clicked
---@field tooltip? any string, table or a filler function, see lib.SetTooltip
---@field linkTo? KajiGUIRadio the previous option, joined to this one by a guide line

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local row = CreateFrame("Frame", nil, gui._poolHost)
    row.gui = gui

    local dot = lib.CreateTickBox(gui, row, DOT_SIZE)
    pixel.SetPixelPoint(dot, "TOPLEFT", row, "TOPLEFT", 0, -(TITLE_HEIGHT - DOT_SIZE) / 2)
    row.dot = dot

    local guide = row:CreateTexture(nil, "BACKGROUND")
    pixel.SetPixelWidth(guide, gui.theme.borderSize)
    pixel.SetPixelSnap(guide)
    guide:Hide()
    row.guide = guide

    local title = row:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(title, "LEFT", dot, "RIGHT", TEXT_GAP, 0)
    pixel.SetPixelPoint(title, "RIGHT", row, "RIGHT", 0, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    gui:ApplyFont(title, "medium")
    row.title = title

    local description = row:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(description, "TOPLEFT", row, "TOPLEFT", DOT_SIZE + TEXT_GAP, -TITLE_HEIGHT - 1)
    pixel.SetPixelPoint(description, "RIGHT", row, "RIGHT", 0, 0)
    description:SetJustifyH("LEFT")
    description:SetWordWrap(false)
    gui:ApplyFont(description, "small")
    row.description = description

    local button = CreateFrame("Button", nil, row)
    button:SetAllPoints(row)
    button:RegisterForClicks("LeftButtonUp")
    row.button = button

    Mixin(row, RadioMixin)

    button:SetScript("OnClick", function()
        if row._selected then return end
        row._selected = true
        row:ApplyState()
        safecall(row._callback)
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
---@param titleText? string
---@param config? KajiGUIRadioConfig
---@return KajiGUIRadio
function InstanceMixin:CreateRadio(parent, titleText, config)
    return self:BuildWidget(WIDGET_TYPE, parent, titleText, config)
end

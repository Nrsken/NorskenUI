--[[
# AnchorPicker

* WeakAuras style 9-point anchor selector: a labelled box with a clickable dot at each
  of the nine anchor points.
* Used by PositionCard for "Anchor From" / "To Frame's", but it is an ordinary widget,
  so it can go in any fluent row.

## Examples

    row:AnchorPicker('Anchor From', {
        width = 0.5,
        value = db.AnchorFrom,
        callback = function(point) db.AnchorFrom = point end,
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel
local safecall = lib.safecall

local CreateFrame = CreateFrame
local Mixin = Mixin
local ipairs, pairs = ipairs, pairs

local ANCHOR_DIRECTIONS = {
    "TOPLEFT", "TOP", "TOPRIGHT",
    "LEFT", "CENTER", "RIGHT",
    "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
}

local DIRECTION_NAMES = {
    TOPLEFT = "Top Left",
    TOP = "Top",
    TOPRIGHT = "Top Right",
    LEFT = "Left",
    CENTER = "Center",
    RIGHT = "Right",
    BOTTOMLEFT = "Bottom Left",
    BOTTOM = "Bottom",
    BOTTOMRIGHT = "Bottom Right",
}

local WIDGET_TYPE = "AnchorPicker"
local BUTTON_SIZE, FRAME_WIDTH, FRAME_HEIGHT, TITLE_HEIGHT, SPACING = 10, 100, 52, 18, 2

---@class KajiGUIAnchorPickerMixin : Frame
---@field label FontString
---@field background Frame|BackdropTemplate
---@field buttons table<string, Button>
---@field value string
---@field disabled? boolean
---@field _callback? fun(point: string)
local AnchorPickerMixin = {}

---Tints one dot for the current selection / disabled state.
---@param button Button
function AnchorPickerMixin:ColorButton(button)
    local theme = self.gui.theme
    if self.disabled then
        button.tex:SetVertexColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 0.3)
    elseif self.value == button.value then
        button.tex:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    else
        button.tex:SetVertexColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 1)
    end
end

---@param value string
function AnchorPickerMixin:SetValue(value)
    self.value = value
    for _, button in pairs(self.buttons) do self:ColorButton(button) end
end

---@return string
function AnchorPickerMixin:GetValue()
    return self.value
end

---@param enabled boolean
function AnchorPickerMixin:SetEnabled(enabled)
    local theme = self.gui.theme
    self.disabled = not enabled
    -- Alpha is left alone: the dots and label carry the disabled state themselves, so the
    -- box does not double-dim when the whole card is also greyed out.
    self:SetAlpha(1)

    if enabled then
        self.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        self.background:SetBackdropBorderColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 1)
    else
        self.label:SetTextColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 0.5)
        self.background:SetBackdropBorderColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 0.3)
    end

    for _, button in pairs(self.buttons) do
        button:EnableMouse(enabled)
        self:ColorButton(button)
    end
end

function AnchorPickerMixin:UpdateColors()
    lib.RefreshBackdrop(self.background)
    self:SetEnabled(not self.disabled)
end

---@param parent Frame
---@param labelText? string
---@param config table
function AnchorPickerMixin:OnAcquire(parent, labelText, config)
    self:SetParent(parent)
    self:ClearAllPoints()

    self.value = config.value or "CENTER"
    self._callback = config.callback
    self.label:SetText(labelText or "")

    self:SetEnabled(true)
    self:SetValue(self.value)
    self:UpdateColors()
    self:Show()
end

function AnchorPickerMixin:OnRelease()
    self._callback = nil
    self.label:SetText("")
    self.value = "CENTER"
    self.disabled = nil
end

---@class KajiGUIAnchorPicker : KajiGUIAnchorPickerMixin

---@class KajiGUIAnchorPickerConfig
---@field value? string one of the nine anchor points (default "CENTER")
---@field callback? fun(point: string)

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local theme = gui.theme

    local container = CreateFrame("Frame", nil, gui._poolHost)
    pixel.SetPixelSize(container, FRAME_WIDTH + BUTTON_SIZE,
        FRAME_HEIGHT + BUTTON_SIZE + TITLE_HEIGHT + SPACING + 4)
    pixel.SetPixelSnap(container)

    container.gui = gui
    container.value = "CENTER"

    local label = container:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "TOP", container, "TOP", 0, 2)
    pixel.SetPixelHeight(label, TITLE_HEIGHT)
    label:SetJustifyH("CENTER")
    gui:ApplyFont(label, "small")
    label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    container.label = label

    local background = CreateFrame("Frame", nil, container, "BackdropTemplate")
    pixel.SetPixelSize(background, FRAME_WIDTH, FRAME_HEIGHT)
    lib.SetBackdrop(background, gui, { bg = "bgDark", bgAlpha = 0.9, border = "textMuted", borderAlpha = 1 })
    pixel.SetPixelSnap(background)
    container.background = background

    -- The row resizes the container, so the box re-centres itself rather than being
    -- anchored once at a width it will not keep.
    local function AlignBackground()
        local width = container:GetWidth()
        if not width or width <= 0 then return end
        background:ClearAllPoints()
        pixel.SetPixelPoint(background, "TOPLEFT", container, "TOPLEFT",
            (width - FRAME_WIDTH) / 2, -(TITLE_HEIGHT + SPACING))
    end
    AlignBackground()
    container:SetScript("OnSizeChanged", AlignBackground)

    Mixin(container, AnchorPickerMixin)

    local buttons = {}
    for _, direction in ipairs(ANCHOR_DIRECTIONS) do
        local button = CreateFrame("Button", nil, container)
        pixel.SetPixelSize(button, BUTTON_SIZE, BUTTON_SIZE)
        pixel.SetPixelPoint(button, "CENTER", background, direction)

        local tex = button:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        pixel.SetPixelSnap(tex)
        button.tex = tex
        button.value = direction

        button:SetScript("OnClick", function(self)
            container:SetValue(self.value)
            safecall(container._callback, self.value)
        end)
        -- Each dot names its own anchor point, so the tooltip is set once here rather
        -- than rebuilt on every hover.
        lib.SetTooltip(button, gui, DIRECTION_NAMES[direction] or direction, nil,
            { anchor = "ANCHOR_RIGHT", x = 0, y = 4 })

        button:SetScript("OnEnter", function(self)
            if not container.disabled then
                local hover = container.gui.theme.accentHover
                self.tex:SetVertexColor(hover[1], hover[2], hover[3], 1)
            end
            lib.ShowTooltip(self)
        end)
        button:SetScript("OnLeave", function(self)
            container:ColorButton(self)
            lib.HideTooltip()
        end)

        buttons[direction] = button
    end
    container.buttons = buttons

    for _, button in pairs(buttons) do container:ColorButton(button) end

    return container
end)

---@param parent Frame
---@param labelText? string
---@param config? KajiGUIAnchorPickerConfig
---@return KajiGUIAnchorPicker
function InstanceMixin:CreateAnchorPicker(parent, labelText, config)
    return self:BuildWidget(WIDGET_TYPE, parent, labelText, config)
end

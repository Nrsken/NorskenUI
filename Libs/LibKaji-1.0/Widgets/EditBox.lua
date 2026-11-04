--[[
# EditBox

* A single-line text input with a label, either above the box or inline to its left.

## Examples

    row:EditBox('Name', {
        width = 0.5,
        value = db.Name,
        callback = function(text) db.Name = text end,
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local Animations = lib.Animations
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local Mixin = Mixin
local tostring = tostring

local WIDGET_TYPE = "EditBox"

---An unset value lists as blank, not "nil".
---@param value any
---@return string
local function DescribeValue(value)
    return (value == nil or value == false) and "" or tostring(value)
end

---@class KajiGUIEditBoxMixin : Frame
---@field gui KajiGUIInstance
---@field editBox EditBox
---@field container Frame|BackdropTemplate
---@field label FontString
---@field _callback? fun(text: string)
---@field _onTextChanged? fun(text: string)
---@field _animateBorder fun(isHover: boolean)
---@field _syncBorder fun(r: number, g: number, b: number, a?: number)
local EditBoxMixin = {}

---@param val string
function EditBoxMixin:SetValue(val)
    self.editBox:SetText(val or "")
end

---@return string
function EditBoxMixin:GetValue()
    return self.editBox:GetText()
end

---@param enabled boolean
function EditBoxMixin:SetEnabled(enabled)
    self:SetAlpha(enabled and 1 or 0.4)
    self.editBox:EnableMouse(enabled)
    self.editBox:EnableKeyboard(enabled)
    if not enabled then
        self.editBox:ClearFocus()
        self._hovered = false
        self._paintGlow()
    end
end

function EditBoxMixin:UpdateColors()
    local theme = self.gui.theme
    lib.RefreshBackdrop(self.container)
    self.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    self.editBox:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
    self._syncBorder(theme.widgetBorder[1], theme.widgetBorder[2], theme.widgetBorder[3], theme.widgetBorder[4] or 1)
    lib.PaintMixed(self, self.label)
end

---@param parent Frame
---@param labelText? string
---@param config table
function EditBoxMixin:OnAcquire(parent, labelText, config)
    local inlineLabel = config.inlineLabel
    local labelWidth = config.labelWidth or 60
    local autoFocus = config.autoFocus or false

    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelHeight(self, inlineLabel and 24 or 34)

    -- The label sits left of the box or above it; both layouts re-anchor from scratch so
    -- a recycled widget cannot keep the other one's points.
    self.label:ClearAllPoints()
    self.container:ClearAllPoints()
    if inlineLabel then
        pixel.SetPixelPoint(self.label, "LEFT", self, "LEFT", 0, 0)
        pixel.SetPixelWidth(self.label, labelWidth)
        pixel.SetPixelPoint(self.container, "TOPLEFT", self, "TOPLEFT", labelWidth, 0)
        pixel.SetPixelPoint(self.container, "TOPRIGHT", self, "TOPRIGHT", 0, 0)
    else
        pixel.SetPixelPoint(self.label, "TOPLEFT", self, "TOPLEFT", 0, 1)
        pixel.SetPixelPoint(self.container, "TOPLEFT", self, "TOPLEFT", 0, -14)
        pixel.SetPixelPoint(self.container, "TOPRIGHT", self, "TOPRIGHT", 0, -14)
    end

    self.label:SetText(labelText or "")
    self._callback = config.callback
    self._onTextChanged = config.onTextChanged

    lib.SetMixed(self, config.mixed, DescribeValue)
    self.editBox:SetAutoFocus(autoFocus)
    self.editBox:SetText(not config.mixed and tostring(config.value or "") or "") -- mixed is blank, as WA's
    self.editBox:EnableMouse(true)
    self.editBox:EnableKeyboard(true)

    lib.SetTooltip(self, self.gui, labelText, config.tooltip, config.tooltipBeside and { owner = self.container, beside = true } or nil)
    lib.SetNotice(self, self.gui, self.label, config.notice)

    self:SetAlpha(1)
    self:UpdateColors()
    self:Show()

    if autoFocus then self.editBox:SetFocus() end
end

function EditBoxMixin:OnRelease()
    self._hovered = false
    self._paintGlow()
    self._callback = nil
    self._onTextChanged = nil
    -- A released box that kept keyboard focus would go on swallowing input.
    self.editBox:ClearFocus()
    self.editBox:SetAutoFocus(false)
    self.editBox:SetText("")
    self.label:SetText("")
    lib.ClearTooltip(self)
end

---@class KajiGUIEditBox : KajiGUIEditBoxMixin

---@class KajiGUIEditBoxConfig
---@field value? string
---@field callback? fun(text: string)
---@field onTextChanged? fun(text: string) fires on every keystroke the user types
---@field autoFocus? boolean
---@field tooltip? any
---@field tooltipBeside? boolean the tooltip opens to the right of the input box instead of at the cursor
---@field inlineLabel? boolean Place the label left of the box instead of above it.
---@field labelWidth? number Width reserved for an inline label.
---@field notice? KajiGUINotice a marker after the label, see lib.SetNotice
---@field mixed? KajiGUIMixedEntry[] the things it edits disagree: blank until typed in, see lib.SetMixed

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local theme = gui.theme

    local row = CreateFrame("Frame", nil, gui._poolHost)
    row.gui = gui

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetJustifyH("LEFT")
    gui:ApplyFont(label, "small")
    row.label = label

    local container = CreateFrame("Frame", nil, row, "BackdropTemplate")
    pixel.SetPixelHeight(container, 24)
    lib.SetBackdrop(container, gui, { bg = "bgDark", bgAlpha = 0.9, border = "widgetBorder", borderAlpha = 1 })
    row.container = container

    -- EditBox frames autofocus by default, and OnAcquire reparents before it can turn
    -- that off, so a freshly built box would steal the keyboard the moment it is shown.
    local editBox = CreateFrame("EditBox", nil, container)
    editBox:SetAutoFocus(false)
    pixel.SetPixelPoint(editBox, "TOPLEFT", container, "TOPLEFT", 6, -4)
    pixel.SetPixelPoint(editBox, "BOTTOMRIGHT", container, "BOTTOMRIGHT", -6, 4)
    editBox:SetFontObject("GameFontNormal")
    row.editBox = editBox

    Mixin(row, EditBoxMixin)

    row._animateBorder, row._syncBorder = Animations:CreateHoverColorAnimator(container,
        function(r, g, b, a) container:SetBackdropBorderColor(r, g, b, a) end,
        theme.widgetBorder, theme.accent, theme.animDuration)

    -- Neon: the field glows faintly while hovered, fully while focused.
    local fieldGlow = lib.CreateFrameGlow(container, gui, lib.FIELD_GLOW_REACH, row)
    row._paintGlow = function()
        lib.SetFrameGlow(fieldGlow, gui, editBox:HasFocus() and lib.GLOW_ACTIVE or (row._hovered and lib.GLOW_HOVER or 0))
    end

    -- Set once, reading the callback off the row, so a recycled box never fires the
    -- previous consumer's handler.
    editBox:SetScript("OnTextChanged", function(eb, userInput)
        if userInput then
            lib.ClearMixed(row) -- typed text is the one value they all get
            safecall(row._onTextChanged, eb:GetText())
        end
    end)
    editBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)
    -- clearing focus runs OnEditFocusLost, which commits; a second call here could reach a field a rebuild re-pooled this box for
    editBox:SetScript("OnEnterPressed", function(eb) eb:ClearFocus() end)
    editBox:SetScript("OnEditFocusLost", function(eb)
        local border = row.gui.theme.widgetBorder
        container:SetBackdropBorderColor(border[1], border[2], border[3], 1)
        row._paintGlow()
        -- a mixed box nobody typed in stays as it was, rather than giving them all an empty value
        if row._mixed then return end
        safecall(row._callback, eb:GetText())
    end)
    editBox:SetScript("OnEditFocusGained", function()
        local accent = row.gui.theme.accent
        container:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
        row._paintGlow()
    end)
    editBox:SetScript("OnEnter", function(eb)
        row._hovered = true
        row._paintGlow()
        if not eb:HasFocus() then row._animateBorder(true) end
        lib.ShowTooltip(row)
    end)
    editBox:SetScript("OnLeave", function(eb)
        row._hovered = false
        row._paintGlow()
        if not eb:HasFocus() then row._animateBorder(false) end
        lib.HideTooltip()
    end)

    return row
end)

---@param parent Frame
---@param labelText? string
---@param config? KajiGUIEditBoxConfig
---@return KajiGUIEditBox
function InstanceMixin:CreateEditBox(parent, labelText, config)
    return self:BuildWidget(WIDGET_TYPE, parent, labelText, config)
end

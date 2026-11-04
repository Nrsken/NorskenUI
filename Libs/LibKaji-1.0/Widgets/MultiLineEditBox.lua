--[[
# MultiLineEditBox

* A scrollable multi-line text input with a label above it.
* The container, scroll frame, edit box and scrollbar share hover and focus handling so
  the whole widget reads as one hit area.

## Examples

    row:MultiLineEditBox('Script', {
        width = 1,
        height = 120,
        value = db.Script,
        callback = function(text) db.Script = text end, -- on focus lost
        onTextChanged = function(text) Preview(text) end, -- every keystroke and paste
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local Animations = lib.Animations
local safecall = lib.safecall
local pixel = lib.Pixel

local tostring = tostring
local Mixin = Mixin
local CreateFrame = CreateFrame
local C_Timer = C_Timer

local WIDGET_TYPE = "MultiLineEditBox"
local LABEL_HEIGHT = 14

---An unset value lists as blank, not "nil".
---@param value any
---@return string
local function DescribeValue(value)
    return (value == nil or value == false) and "" or tostring(value)
end

---@class KajiGUIMultiLineEditBoxMixin : Frame
---@field gui KajiGUIInstance
---@field editBox EditBox
---@field container Frame|BackdropTemplate
---@field scrollFrame ScrollFrame
---@field scrollbar table
---@field label FontString
---@field rowHeight number
---@field _callback? fun(text: string)
---@field _onTextChanged? fun(text: string)
---@field _animateBorder fun(isHover: boolean)
---@field _syncBorder fun(r: number, g: number, b: number, a?: number)
local MultiLineEditBoxMixin = {}

---@param val string
function MultiLineEditBoxMixin:SetValue(val)
    self.editBox:SetText(val or "")
    self.editBox:SetCursorPosition(0)
end

---@return string
function MultiLineEditBoxMixin:GetValue()
    return self.editBox:GetText()
end

---@param enabled boolean
function MultiLineEditBoxMixin:SetEnabled(enabled)
    self:SetAlpha(enabled and 1 or 0.4)
    self.editBox:EnableMouse(enabled)
    self.editBox:EnableKeyboard(enabled)
    self.container:EnableMouse(enabled)
    if not enabled then
        self.editBox:ClearFocus()
        self._hovered = false
        self._paintGlow()
    end
end

function MultiLineEditBoxMixin:UpdateScrollbar()
    self.scrollbar:UpdateVisibility(self.editBox:GetHeight() or 0, self.scrollFrame:GetHeight() or 0)
end

function MultiLineEditBoxMixin:UpdateColors()
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
function MultiLineEditBoxMixin:OnAcquire(parent, labelText, config)
    local containerHeight = config.height or 80
    self.rowHeight = LABEL_HEIGHT + containerHeight + 4

    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelHeight(self, self.rowHeight)
    pixel.SetPixelHeight(self.container, containerHeight)

    self.label:SetText(labelText or "")
    self._callback = config.callback
    self._onTextChanged = config.onTextChanged

    self.editBox:EnableMouse(true)
    self.editBox:EnableKeyboard(true)
    lib.SetMixed(self, config.mixed, DescribeValue)
    self.editBox:SetText(not config.mixed and tostring(config.value or "") or "") -- mixed is blank, as WA's
    self.editBox:SetCursorPosition(0)
    self.container:EnableMouse(true)

    lib.SetTooltip(self, self.gui, config.tooltip, nil, { owner = self.container, anchor = "ANCHOR_TOP" })
    lib.SetNotice(self, self.gui, self.label, config.notice)

    self:SetAlpha(1)
    self:UpdateColors()
    self:Show()
    self:UpdateScrollbar()
end

function MultiLineEditBoxMixin:OnRelease()
    self._hovered = false
    self._paintGlow()
    self._callback = nil
    self._onTextChanged = nil
    self.editBox:ClearFocus()
    self.editBox:SetText("")
    self.label:SetText("")
    lib.ClearTooltip(self)
end

---@class KajiGUIMultiLineEditBox : KajiGUIMultiLineEditBoxMixin

---@class KajiGUIMultiLineEditBoxConfig
---@field value? string
---@field height? number
---@field tooltip? string
---@field callback? fun(text: string)
---@field notice? KajiGUINotice a marker after the label, see lib.SetNotice
---@field mixed? KajiGUIMixedEntry[] the things it edits disagree: blank until typed in, see lib.SetMixed

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local theme = gui.theme

    local row = CreateFrame("Frame", nil, gui._poolHost)
    row.gui = gui

    local label = row:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    gui:ApplyFont(label, "small")
    row.label = label

    local container = CreateFrame("Frame", nil, row, "BackdropTemplate")
    pixel.SetPixelPoint(container, "TOPLEFT", row, "TOPLEFT", 0, -LABEL_HEIGHT)
    pixel.SetPixelPoint(container, "TOPRIGHT", row, "TOPRIGHT", 0, -LABEL_HEIGHT)
    lib.SetBackdrop(container, gui, { bg = "bgDark", bgAlpha = 0.9, border = "widgetBorder", borderAlpha = 1 })
    row.container = container

    local scrollFrame = CreateFrame("ScrollFrame", nil, container)
    pixel.SetPixelPoint(scrollFrame, "TOPLEFT", container, "TOPLEFT", 6, -6)
    pixel.SetPixelPoint(scrollFrame, "BOTTOMRIGHT", container, "BOTTOMRIGHT", -18, 6)
    row.scrollFrame = scrollFrame

    local scrollbar = gui:CreateScrollbar(scrollFrame, {
        width = 8,
        thumbHeight = 24,
        padding = { top = 3, bottom = 3, right = 3 },
        scrollStep = 20,
    })
    row.scrollbar = scrollbar

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetCountInvisibleLetters(false)
    editBox:EnableMouse(true)
    scrollFrame:SetScrollChild(editBox)
    row.editBox = editBox

    Mixin(row, MultiLineEditBoxMixin)

    row._animateBorder, row._syncBorder = Animations:CreateHoverColorAnimator(container,
        function(r, g, b, a) container:SetBackdropBorderColor(r, g, b, a) end,
        theme.widgetBorder, theme.accent, theme.animDuration)

    -- Neon: the field glows faintly while hovered, fully while focused.
    local fieldGlow = lib.CreateFrameGlow(container, gui, lib.FIELD_GLOW_REACH, row)
    row._paintGlow = function()
        lib.SetFrameGlow(fieldGlow, gui, editBox:HasFocus() and lib.GLOW_ACTIVE or (row._hovered and lib.GLOW_HOVER or 0))
    end

    local scrollWidth = scrollFrame:GetWidth()
    pixel.SetPixelWidth(editBox, scrollWidth > 0 and scrollWidth - 14 or 186)

    editBox:SetScript("OnCursorChanged", function(_, _, y, _, cursorHeight)
        local _, maxVal = scrollbar:GetMinMaxValues()
        if maxVal <= 0 then return end
        local offset = scrollbar:GetValue()
        if -y < offset then
            scrollbar:SetValue(-y)
        else
            local bottom = -y + cursorHeight - scrollFrame:GetHeight()
            if bottom > offset then
                scrollbar:SetValue(bottom)
            end
        end
    end)

    editBox:SetScript("OnTextChanged", function(eb, userInput)
        if userInput then
            lib.ClearMixed(row) -- typed text is the one value they all get
            safecall(row._onTextChanged, eb:GetText())
        end
        -- Deferred one frame so the edit box has resized first. Guarded because the
        -- widget may have been released and re-acquired by something else by then.
        local alive = lib.Generation(row)
        C_Timer.After(0, function()
            if alive() then row:UpdateScrollbar() end
        end)
    end)

    scrollFrame:SetScript("OnSizeChanged", function(_, width)
        pixel.SetPixelWidth(editBox, width - 14)
        row:UpdateScrollbar()
    end)

    editBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)
    editBox:SetScript("OnEditFocusLost", function(eb)
        eb:HighlightText(0, 0)
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

    -- One hover pair shared by every hit area in the widget.
    local function OnEnter()
        row._hovered = true
        row._paintGlow()
        if not editBox:HasFocus() then row._animateBorder(true) end
        lib.ShowTooltip(row)
    end
    local function OnLeave()
        row._hovered = container:IsMouseOver()
        row._paintGlow()
        if not editBox:HasFocus() and not row._hovered then row._animateBorder(false) end
        lib.HideTooltip()
    end
    local function FocusEditBox() editBox:SetFocus() end

    editBox:SetScript("OnEnter", OnEnter)
    editBox:SetScript("OnLeave", OnLeave)

    container:EnableMouse(true)
    container:SetScript("OnMouseDown", FocusEditBox)
    container:SetScript("OnEnter", OnEnter)
    container:SetScript("OnLeave", OnLeave)

    scrollFrame:EnableMouse(true)
    scrollFrame:SetScript("OnMouseDown", FocusEditBox)
    scrollFrame:SetScript("OnEnter", OnEnter)
    scrollFrame:SetScript("OnLeave", OnLeave)

    -- HookScript accumulates, so this must stay in the constructor: hooking it per
    -- acquire would add a layer on every reuse.
    scrollbar:HookScript("OnEnter", OnEnter)
    scrollbar:HookScript("OnLeave", OnLeave)

    return row
end)

---@param parent Frame
---@param labelText? string
---@param config? KajiGUIMultiLineEditBoxConfig
---@return KajiGUIMultiLineEditBox
function InstanceMixin:CreateMultiLineEditBox(parent, labelText, config)
    return self:BuildWidget(WIDGET_TYPE, parent, labelText, config)
end

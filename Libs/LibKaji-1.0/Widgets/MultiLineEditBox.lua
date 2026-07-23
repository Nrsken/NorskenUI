--[[
# MultiLineEditBox

* A scrollable multi-line text input with a label.
* Fires its callback on focus loss.

## Examples

?   row:MultiLineEditBox('Custom code', {
?       value = db.Code,
?       height = 120,
?       callback = function(text)
?           db.Code = text
?       end
?   })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local Animations = lib.Animations
local safecall = lib.safecall
local pixel = lib.Pixel

local tostring = tostring
local Mixin = Mixin
local CreateFrame = CreateFrame
local C_Timer = C_Timer

---@class KajiGUIMultiLineEditBoxMixin : Frame
---@field editBox EditBox
---@field container Frame|BackdropTemplate
---@field scrollFrame ScrollFrame
---@field rowHeight number
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
    if not enabled then self.editBox:ClearFocus() end
end

---@class KajiGUIMultiLineEditBox : KajiGUIMultiLineEditBoxMixin
---@field label FontString

---@class KajiGUIMultiLineEditBoxConfig
---@field value? string
---@field height? number
---@field tooltip? string
---@field syntaxHighlight? boolean
---@field callback? fun(text: string)

---@param parent Frame
---@param labelText string
---@param config? KajiGUIMultiLineEditBoxConfig
---@return KajiGUIMultiLineEditBox
function InstanceMixin:CreateMultiLineEditBox(parent, labelText, config)
    config = config or {}
    local gui = self
    local theme = self.theme
    local value = tostring(config.value or "")
    local callback = config.callback
    local tooltip = config.tooltip
    local containerHeight = config.height or 80

    local rowHeight = 14 + containerHeight + 4
    local row = CreateFrame("Frame", nil, parent)
    pixel.SetPixelHeight(row, rowHeight)

    -- Label
    local label = row:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    gui:ApplyFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    row.label = label

    -- Container
    local container = CreateFrame("Frame", nil, row, "BackdropTemplate")
    pixel.SetPixelHeight(container, containerHeight)
    pixel.SetPixelPoint(container, "TOPLEFT", row, "TOPLEFT", 0, -14)
    pixel.SetPixelPoint(container, "TOPRIGHT", row, "TOPRIGHT", 0, -14)
    container:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    container:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], 1)
    container:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
    row.container = container

    local animateBorder = Animations:CreateHoverColorAnimator(container,
        function(r, g, b, a) container:SetBackdropBorderColor(r, g, b, a) end,
        theme.border,
        theme.accent,
        theme.animDuration
    )

    -- Scroll frame + scrollbar
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

    -- Edit box
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    editBox:SetCountInvisibleLetters(false)
    editBox:EnableMouse(true)
    scrollFrame:SetScrollChild(editBox)
    row.editBox = editBox

    local function UpdateScrollbar()
        scrollbar:UpdateVisibility(editBox:GetHeight() or 0, scrollFrame:GetHeight() or 0)
    end

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

    editBox:SetScript("OnTextChanged", function()
        C_Timer.After(0, UpdateScrollbar)
    end)

    local scrollWidth = scrollFrame:GetWidth()
    pixel.SetPixelWidth(editBox, scrollWidth > 0 and scrollWidth - 14 or 186)

    scrollFrame:SetScript("OnSizeChanged", function(_, width)
        pixel.SetPixelWidth(editBox, width - 14)
        UpdateScrollbar()
    end)

    editBox:SetText(value)
    editBox:SetCursorPosition(0)

    editBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)
    editBox:SetScript("OnEditFocusLost", function(eb)
        eb:HighlightText(0, 0)
        container:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
        safecall(callback, eb:GetText())
    end)
    editBox:SetScript("OnEditFocusGained", function()
        container:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    end)

    -- Shared hover / focus / tooltip handlers across the container, scroll frame,
    -- edit box and scrollbar so the whole widget reads as one hit area.
    local function OnEnter()
        if not editBox:HasFocus() then animateBorder(true) end
        if tooltip then
            GameTooltip:SetOwner(container, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end
    local function OnLeave()
        if not editBox:HasFocus() and not container:IsMouseOver() then animateBorder(false) end
        GameTooltip:Hide()
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

    scrollbar:HookScript("OnEnter", OnEnter)
    scrollbar:HookScript("OnLeave", OnLeave)

    Mixin(row, MultiLineEditBoxMixin)
    row.rowHeight = rowHeight

    ---@cast row KajiGUIMultiLineEditBox
    return row
end

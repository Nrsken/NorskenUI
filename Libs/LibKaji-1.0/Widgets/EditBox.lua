--[[
# EditBox

* A single-line text input with a label. 
* Fires its callback on Enter or focus loss.

## Examples

    row:EditBox('Frame', {
        value = db.Frame,
        callback = function(v)
            db.Frame = v
        end
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local Animations = lib.Animations
local safecall = lib.safecall
local pixel = lib.Pixel

local tostring = tostring
local type = type
local Mixin = Mixin
local CreateFrame = CreateFrame

---@class KajiGUIEditBoxMixin : Frame
---@field editBox EditBox
---@field container Frame|BackdropTemplate
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
    if not enabled then self.editBox:ClearFocus() end
end

---@class KajiGUIEditBox : KajiGUIEditBoxMixin
---@field label FontString

---@class KajiGUIEditBoxConfig
---@field value? string
---@field callback? fun(text: string)
---@field autoFocus? boolean
---@field tooltip? any

---@param parent Frame
---@param labelText string
---@param config KajiGUIEditBoxConfig
---@return KajiGUIEditBox
function InstanceMixin:CreateEditBox(parent, labelText, config)
    config = config or {}
    local gui = self
    local theme = self.theme
    local value = tostring(config.value or "")
    local callback = config.callback
    local autoFocus = config.autoFocus
    local tooltip = config.tooltip

    local row = CreateFrame("Frame", nil, parent)
    pixel.SetPixelHeight(row, 34)

    local label = row:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    gui:ApplyFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    row.label = label

    local container = CreateFrame("Frame", nil, row, "BackdropTemplate")
    pixel.SetPixelHeight(container, 24)
    pixel.SetPixelPoint(container, "TOPLEFT", row, "TOPLEFT", 0, -14)
    pixel.SetPixelPoint(container, "TOPRIGHT", row, "TOPRIGHT", 0, -14)
    container:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    container:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], 1)
    container:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
    row.container = container

    local animateBorder = Animations:CreateHoverColorAnimator(container,
        function(r, g, b, a)
            container:SetBackdropBorderColor(r, g, b, a)
        end,
        theme.border,
        theme.accent,
        theme.animDuration
    )

    local editBox = CreateFrame("EditBox", nil, container)
    pixel.SetPixelPoint(editBox, "TOPLEFT", container, "TOPLEFT", 6, -4)
    pixel.SetPixelPoint(editBox, "BOTTOMRIGHT", container, "BOTTOMRIGHT", -6, 4)
    editBox:SetFontObject("GameFontNormal")
    editBox:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    editBox:SetAutoFocus(autoFocus or false)
    editBox:SetText(value)
    if autoFocus then editBox:SetFocus() end
    row.editBox = editBox

    editBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)
    editBox:SetScript("OnEnterPressed", function(eb)
        eb:ClearFocus()
        safecall(callback, eb:GetText())
    end)
    editBox:SetScript("OnEditFocusLost", function(eb)
        container:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
        safecall(callback, eb:GetText())
    end)
    editBox:SetScript("OnEditFocusGained", function()
        container:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    end)
    editBox:SetScript("OnEnter", function()
        if not editBox:HasFocus() then animateBorder(true) end
    end)
    editBox:SetScript("OnLeave", function()
        if not editBox:HasFocus() then animateBorder(false) end
    end)

    Mixin(row, EditBoxMixin)

    if tooltip then
        local tooltipText = type(tooltip) == "table" and tooltip.text or tooltip
        local oldEnter = editBox:GetScript("OnEnter")
        local oldLeave = editBox:GetScript("OnLeave")
        editBox:SetScript("OnEnter", function(self, ...)
            if oldEnter then oldEnter(self, ...) end
            GameTooltip:SetOwner(row, "ANCHOR_CURSOR_RIGHT", 30, 0)
            GameTooltip:SetText(labelText or "", theme.accent[1], theme.accent[2], theme.accent[3], 1, false)
            GameTooltip:AddLine(tooltipText, theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], false)
            GameTooltip:Show()
        end)
        editBox:SetScript("OnLeave", function(self, ...)
            if oldLeave then oldLeave(self, ...) end
            GameTooltip:Hide()
        end)
    end

    ---@cast row KajiGUIEditBox
    return row
end

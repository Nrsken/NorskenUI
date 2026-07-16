---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local tostring = tostring
local Mixin = Mixin
local CreateFrame = CreateFrame

---@class NUIEditBoxMixin : Frame
---@field editBox EditBox
---@field container Frame|BackdropTemplate
local NUIEditBoxMixin = {}

---@param val string
function NUIEditBoxMixin:SetValue(val)
    self.editBox:SetText(val or "")
end

---@return string
function NUIEditBoxMixin:GetValue()
    return self.editBox:GetText()
end

---@param enabled boolean
function NUIEditBoxMixin:SetEnabled(enabled)
    if enabled then
        self:SetAlpha(1)
        self.editBox:EnableMouse(true)
        self.editBox:EnableKeyboard(true)
    else
        self:SetAlpha(0.4)
        self.editBox:EnableMouse(false)
        self.editBox:EnableKeyboard(false)
        self.editBox:ClearFocus()
    end
end

---Single-line text input field
---```lua
---config = {
---    value = string,          -- Initial text value
---    callback = function,     -- Called when text changes
---    autoFocus = boolean,     -- Auto focus on creation
---}
---```
---@param parent Frame
---@param labelText string
---@param config NUIEditBoxConfig
---@return NUIEditBox
function GUIFrame:CreateEditBox(parent, labelText, config)
    config = config or {}
    local value = tostring(config.value or "")
    local callback = config.callback
    local autoFocus = config.autoFocus
    local tooltip = config.tooltip

    local rowHeight = 34
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(rowHeight)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    NRSKNUI:ApplyThemeFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    row.label = label

    local container = CreateFrame("Frame", nil, row, "BackdropTemplate")
    container:SetHeight(24)
    container:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -14)
    container:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -14)
    container:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, })
    container:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
    container:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    row.container = container

    local animateBorder = NRSKNUI.Animations:CreateHoverColorAnimator(
        container,
        function(r, g, b, a) container:SetBackdropBorderColor(r, g, b, a) end,
        Theme.border,
        Theme.accent,
        Theme.animDuration
    )

    local editBox = CreateFrame("EditBox", nil, container)
    editBox:SetPoint("TOPLEFT", container, "TOPLEFT", 6, -4)
    editBox:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -6, 4)
    editBox:SetFontObject("GameFontNormal")
    editBox:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    editBox:SetAutoFocus(autoFocus or false)
    editBox:SetText(value or "")
    if autoFocus then editBox:SetFocus() end
    row.editBox = editBox

    editBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)

    editBox:SetScript("OnEnterPressed", function(eb)
        eb:ClearFocus()
        if callback then callback(eb:GetText()) end
    end)

    editBox:SetScript("OnEditFocusLost", function(eb)
        container:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
        if callback then callback(eb:GetText()) end
    end)

    editBox:SetScript("OnEditFocusGained", function()
        container:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    end)

    editBox:SetScript("OnEnter", function()
        if not editBox:HasFocus() then animateBorder(true) end
    end)
    editBox:SetScript("OnLeave", function()
        if not editBox:HasFocus() then animateBorder(false) end
    end)

    Mixin(row, NUIEditBoxMixin)

    -- Tooltip support
    if tooltip then
        local tooltipText = type(tooltip) == "table" and tooltip.text or tooltip

        local function SetupTooltip(frame)
            local oldEnter = frame:GetScript("OnEnter")
            local oldLeave = frame:GetScript("OnLeave")
            frame:SetScript("OnEnter", function(self, ...)
                if oldEnter then oldEnter(self, ...) end
                GameTooltip:SetOwner(row, "ANCHOR_CURSOR_RIGHT", 30, 0)
                GameTooltip:SetText(labelText or "", Theme.accent[1], Theme.accent[2], Theme.accent[3], 1, false)
                GameTooltip:AddLine(tooltipText, Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], false)
                GameTooltip:Show()
            end)
            frame:SetScript("OnLeave", function(self, ...)
                if oldLeave then oldLeave(self, ...) end
                GameTooltip:Hide()
            end)
        end
        SetupTooltip(editBox)
    end

    return row
end

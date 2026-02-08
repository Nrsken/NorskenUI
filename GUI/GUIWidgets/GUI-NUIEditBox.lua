-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local tostring = tostring
local type = type
local CreateFrame = CreateFrame

-- EditBox widget
function GUIFrame:CreateEditBox(parent, labelText, value, callback)
    local tooltip = nil
    local customHeight = nil
    -- Detect AceConfig table format: second param is number (yOffset), third is table
    if type(labelText) == "number" and type(value) == "table" then
        local config = value
        labelText = config.label
        value = config.value or ""
        callback = config.callback
        tooltip = config.tooltip
        customHeight = config.height
    end

    -- Ensure value is a string
    value = tostring(value or "")

    local rowHeight = customHeight or 34
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(rowHeight)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    label:SetJustifyH("LEFT")
    NRSKNUI:ApplyThemeFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    row.label = label

    local container = CreateFrame("Frame", nil, row, "BackdropTemplate")
    container:SetHeight(24)
    container:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -14)
    container:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -14)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    container:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
    container:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    --- ANIMATION

    -- EditBox border hover animation
    local editBoxAnimGroup = container:CreateAnimationGroup()
    local editBoxAnim = editBoxAnimGroup:CreateAnimation("Animation")
    editBoxAnim:SetDuration(0.18)

    local editBoxColorFrom = {}
    local editBoxColorTo = {}
    local editBoxR, editBoxG, editBoxB = Theme.border[1], Theme.border[2], Theme.border[3]

    local function AnimateEditBoxBorder(toAccent)
        editBoxAnimGroup:Stop()
        editBoxColorFrom.r = editBoxR
        editBoxColorFrom.g = editBoxG
        editBoxColorFrom.b = editBoxB

        if toAccent then
            editBoxColorTo.r = Theme.accent[1]
            editBoxColorTo.g = Theme.accent[2]
            editBoxColorTo.b = Theme.accent[3]
        else
            editBoxColorTo.r = Theme.border[1]
            editBoxColorTo.g = Theme.border[2]
            editBoxColorTo.b = Theme.border[3]
        end
        editBoxAnimGroup:Play()
    end

    editBoxAnimGroup:SetScript("OnUpdate", function(self)
        local progress = self:GetProgress() or 0
        local r = editBoxColorFrom.r + (editBoxColorTo.r - editBoxColorFrom.r) * progress
        local g = editBoxColorFrom.g + (editBoxColorTo.g - editBoxColorFrom.g) * progress
        local b = editBoxColorFrom.b + (editBoxColorTo.b - editBoxColorFrom.b) * progress
        container:SetBackdropBorderColor(r, g, b, 1)
        editBoxR, editBoxG, editBoxB = r, g, b
    end)

    editBoxAnimGroup:SetScript("OnFinished", function()
        container:SetBackdropBorderColor(editBoxColorTo.r, editBoxColorTo.g, editBoxColorTo.b, 1)
        editBoxR, editBoxG, editBoxB = editBoxColorTo.r, editBoxColorTo.g, editBoxColorTo.b
    end)

    --------

    local editBox = CreateFrame("EditBox", nil, container)
    editBox:SetPoint("TOPLEFT", container, "TOPLEFT", 6, -4)
    editBox:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -6, 4)
    editBox:SetFontObject("GameFontNormal")
    editBox:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    editBox:SetAutoFocus(false)
    editBox:SetText(value or "")

    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if callback then callback(self:GetText()) end
    end)

    editBox:SetScript("OnEditFocusLost", function(self)
        container:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
        if callback then callback(self:GetText()) end
    end)

    editBox:SetScript("OnEditFocusGained", function()
        container:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    end)

    -- Add tooltip support for the editBox itself
    editBox:SetScript("OnEnter", function()
        if not editBox:HasFocus() then
            AnimateEditBoxBorder(true)
        end
        if tooltip then
            GameTooltip:SetOwner(container, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    editBox:SetScript("OnLeave", function()
        if not editBox:HasFocus() then
            AnimateEditBoxBorder(false)
        end
        GameTooltip:Hide()
    end)

    -- Add tooltip support for the container
    container:EnableMouse(true)
    container:SetScript("OnEnter", function(self)
        if tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    container:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    function row:SetValue(val) editBox:SetText(val or "") end

    function row:GetValue() return editBox:GetText() end

    function row:SetEnabled(enabled)
        if enabled then
            row:SetAlpha(1)
            editBox:EnableMouse(true)
            editBox:EnableKeyboard(true)
        else
            row:SetAlpha(0.4)
            editBox:EnableMouse(false)
            editBox:EnableKeyboard(false)
            editBox:ClearFocus()
        end
    end

    row.editBox = editBox
    row.container = container
    return row
end

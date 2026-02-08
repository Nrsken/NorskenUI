-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local CreateFrame = CreateFrame
local type = type

-- Button widgt
function GUIFrame:CreateButton(parent, labelText, config)
    local customHeight = nil
    -- Ensure config is a table
    if type(config) ~= "table" then
        config = {}
    end
    local label = labelText or "Button"
    local tooltip = config.tooltip
    local callback = config.callback
    local image = config.image
    local imageSize = config.imageSize or 16
    local explicitWidth = config.width
    local height = config.height or 24
    local cWidth = config.cWidth or true

    -- CREATE ROW CONTAINER
    local rowHeight = customHeight or 34
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(rowHeight)

    local button = CreateFrame("Button", nil, row, "BackdropTemplate")
    button:SetHeight(height)
    if config.height then
        button.explicitHeight = true
    end

    if explicitWidth then
        button:SetWidth(explicitWidth)
    else
        button:SetWidth(120)
    end
    --button:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -14)
    --button:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -14)


    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    button:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], 1)
    button:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    -- Hover fade animation for border color
    local hoverAnimGroup = button:CreateAnimationGroup()
    local hoverAnim = hoverAnimGroup:CreateAnimation("Animation")
    hoverAnim:SetDuration(0.15)

    local borderColorFrom = {}
    local borderColorTo = {}

    hoverAnimGroup:SetScript("OnUpdate", function(self)
        local progress = self:GetProgress() or 0
        local r = borderColorFrom.r + (borderColorTo.r - borderColorFrom.r) * progress
        local g = borderColorFrom.g + (borderColorTo.g - borderColorFrom.g) * progress
        local b = borderColorFrom.b + (borderColorTo.b - borderColorFrom.b) * progress
        button:SetBackdropBorderColor(r, g, b, 1)
    end)

    hoverAnimGroup:SetScript("OnFinished", function()
        button:SetBackdropBorderColor(borderColorTo.r, borderColorTo.g, borderColorTo.b, 1)
    end)

    local function AnimateBorderColor(toAccent)
        hoverAnimGroup:Stop()

        local currentR, currentG, currentB = button:GetBackdropBorderColor()
        borderColorFrom.r = currentR
        borderColorFrom.g = currentG
        borderColorFrom.b = currentB

        if toAccent then
            borderColorTo.r = Theme.accent[1]
            borderColorTo.g = Theme.accent[2]
            borderColorTo.b = Theme.accent[3]
        else
            borderColorTo.r = Theme.border[1]
            borderColorTo.g = Theme.border[2]
            borderColorTo.b = Theme.border[3]
        end

        hoverAnimGroup:Play()
    end

    local contentWidth = 0
    local iconWidget, textWidget

    if image then
        iconWidget = button:CreateTexture(nil, "ARTWORK")
        iconWidget:SetSize(imageSize, imageSize)
        iconWidget:SetTexture(image)
        contentWidth = contentWidth + imageSize
    end

    textWidget = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    NRSKNUI:ApplyThemeFont(textWidget, "normal")
    textWidget:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    textWidget:SetText(label)
    contentWidth = contentWidth + textWidget:GetStringWidth()

    if image and label and label ~= "" then
        contentWidth = contentWidth + 6
    end

    if iconWidget and textWidget then
        iconWidget:SetPoint("LEFT", button, "CENTER", -contentWidth / 2, 0)
        textWidget:SetPoint("LEFT", iconWidget, "RIGHT", 6, 0)
    elseif iconWidget then
        iconWidget:SetPoint("CENTER")
    else
        textWidget:SetPoint("CENTER")
    end

    button:SetScript("OnEnter", function(self)
        AnimateBorderColor(true)
        if tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)

    button:SetScript("OnLeave", function(self)
        AnimateBorderColor(false)
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(self)
        callback()
    end)

    function button:SetLabel(newLabel)
        textWidget:SetText(newLabel)
    end

    function button:SetImage(newImage)
        if iconWidget then
            iconWidget:SetTexture(newImage)
        end
    end

    function button:SetEnabled(enabled)
        if enabled then
            button:Enable()
            button:SetAlpha(1)
            button:EnableMouse(true)
            if textWidget then
                textWidget:SetAlpha(1)
            end
            if iconWidget then
                iconWidget:SetAlpha(1)
            end
        else
            button:Disable()
            button:SetAlpha(0.5)
            button:EnableMouse(false)
            if textWidget then
                textWidget:SetAlpha(0.5)
            end
            if iconWidget then
                iconWidget:SetAlpha(0.5)
            end
        end
    end

    button.icon = iconWidget
    button.text = textWidget
    return button
end

-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local CreateFrame = CreateFrame
local ColorPickerFrame = ColorPickerFrame

-- ColorPicker widget
function GUIFrame:CreateColorPicker(parent, labelText, color, callback)
    local tooltip = nil
    local customHeight = nil
    local rowHeight = customHeight or 34
    local ANIMATION_DURATION = 0.18
    local texPath = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NUIcolorPickerBG.png"

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(rowHeight)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    NRSKNUI:ApplyThemeFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    row.label = label

    -- Backdrop texture to easier see current alpha value
    local swatchBg = row:CreateTexture(nil, "BACKGROUND")
    swatchBg:SetSize(48, 24)
    swatchBg:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -14)
    swatchBg:SetTexture(texPath)
    swatchBg:SetAlpha(0.8)
    swatchBg:SetTexelSnappingBias(0)
    swatchBg:SetSnapToPixelGrid(false)

    local swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
    swatch:SetSize(48, 24)
    swatch:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -14)
    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    color = color or { 1, 1, 1, 1 }
    swatch:SetBackdropColor(color[1], color[2], color[3], color[4] or 1)
    swatch:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    swatch.r, swatch.g, swatch.b, swatch.a = color[1], color[2], color[3], color[4] or 1

    -- Hex code display
    local hexText = row:CreateFontString(nil, "OVERLAY")
    hexText:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    NRSKNUI:ApplyThemeFont(hexText, "small")
    hexText:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    hexText:SetText("#" .. NRSKNUI:RGBAToHex(color[1], color[2], color[3]))
    hexText:SetShadowColor(0,0,0,0)
    row.hexText = hexText

    local function UpdateColor(r, g, b, a)
        swatch.r, swatch.g, swatch.b, swatch.a = r, g, b, a or 1
        swatch:SetBackdropColor(r, g, b, a or 1)
        hexText:SetText("#" .. NRSKNUI:RGBAToHex(r, g, b))
        if callback then callback(r, g, b, a or 1) end
    end

    -- Hover fade animation for border color
    local hoverAnimGroup = swatch:CreateAnimationGroup()
    local hoverAnim = hoverAnimGroup:CreateAnimation("Animation")
    hoverAnim:SetDuration(ANIMATION_DURATION)

    local borderColorFrom = {}
    local borderColorTo = {}

    hoverAnimGroup:SetScript("OnUpdate", function(self)
        local progress = self:GetProgress() or 0
        local r = borderColorFrom.r + (borderColorTo.r - borderColorFrom.r) * progress
        local g = borderColorFrom.g + (borderColorTo.g - borderColorFrom.g) * progress
        local b = borderColorFrom.b + (borderColorTo.b - borderColorFrom.b) * progress
        swatch:SetBackdropBorderColor(r, g, b, 1)
    end)

    hoverAnimGroup:SetScript("OnFinished", function()
        swatch:SetBackdropBorderColor(borderColorTo.r, borderColorTo.g, borderColorTo.b, 1)
    end)

    local function AnimateBorderColor(toAccent)
        hoverAnimGroup:Stop()

        local currentR, currentG, currentB = swatch:GetBackdropBorderColor()
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

    swatch:SetScript("OnEnter", function(self)
        AnimateBorderColor(true)
        if tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)

    swatch:SetScript("OnLeave", function(self)
        AnimateBorderColor(false)
        GameTooltip:Hide()
    end)

    swatch:SetScript("OnClick", function()
        local prevR, prevG, prevB, prevA = swatch.r, swatch.g, swatch.b, swatch.a
        local info = {
            r = prevR,
            g = prevG,
            b = prevB,
            opacity = prevA,
            hasOpacity = true
        }
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            UpdateColor(r or 1, g or 1, b or 1, a or 1)
        end
        info.opacityFunc = info.swatchFunc
        info.cancelFunc = function()
            UpdateColor(prevR, prevG, prevB, prevA)
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
    function row:SetColor(r, g, b, a) UpdateColor(r, g, b, a) end

    function row:GetColor() return swatch.r, swatch.g, swatch.b, swatch.a end

    function row:SetEnabled(enabled)
        if enabled then
            row:SetAlpha(1)
            swatch:EnableMouse(true)
        else
            row:SetAlpha(0.4)
            swatch:EnableMouse(false)
        end
    end

    row.swatch = swatch
    return row
end

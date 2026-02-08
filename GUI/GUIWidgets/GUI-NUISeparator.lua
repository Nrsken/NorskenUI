-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local CreateFrame = CreateFrame
local CreateColor = CreateColor

-- Separator widget
function GUIFrame:CreateSeparator(parent)
    local sepHeight = 6

    local separator = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    separator:SetHeight(sepHeight)
    separator:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    separator:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    --local r, g, b = Theme.accent[1], Theme.accent[2], Theme.accent[3]
    local r, g, b = Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3]

    -- Left half
    local left = separator:CreateTexture(nil, "ARTWORK")
    left:SetHeight(2)
    left:SetPoint("LEFT", separator, "LEFT", 3, 0)
    left:SetPoint("RIGHT", separator, "CENTER", 0, 0)
    left:SetColorTexture(1, 1, 1, 1)
    left:SetGradient("HORIZONTAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, 1))
    left:SetTexelSnappingBias(0)
    left:SetSnapToPixelGrid(false)

    -- Right half
    local right = separator:CreateTexture(nil, "ARTWORK")
    right:SetHeight(2)
    right:SetPoint("LEFT", separator, "CENTER", 0, 0)
    right:SetPoint("RIGHT", separator, "RIGHT", -3, 0)
    right:SetColorTexture(1, 1, 1, 1)
    right:SetGradient("HORIZONTAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, 1))
    right:SetTexelSnappingBias(0)
    right:SetSnapToPixelGrid(false)

    function separator:SetEnabled(enabled)
        if enabled then
            separator:SetAlpha(1)
        else
            separator:SetAlpha(0.5)
        end
    end

    return separator
end

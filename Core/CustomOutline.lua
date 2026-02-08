-- NorskenUI namespace
local _, NRSKNUI = ...

-- Module with a custom "Soft Outline" that uses shadows to create a clean outline, works better with smaller font sizes
-- TODO: Revisit this one, not 100% happy with it and how it updates

-- Localization
local ipairs = ipairs

-- Cached shadow offsets (created once, not on every call)
local SHADOW_OFFSETS = {
    { 0,  1 },  -- N
    { 1,  1 },  -- NE
    { 1,  0 },  -- E
    { 1,  -1 }, -- SE
    { 0,  -1 }, -- S
    { -1, -1 }, -- SW
    { -1, 0 },  -- W
    { -1, 1 },  -- NW
}

-- CreateStackedShadowText: Create 8 shadow copies for soft outline effect
function NRSKNUI:CreateStackedShadowText(parent, mainText, font, size, shadowColor, shadowAlpha)
    -- Validate inputs
    if not parent or not mainText then return nil end

    -- Default parameters
    shadowColor = shadowColor or { 0, 0, 0 }
    shadowAlpha = shadowAlpha or 0.9

    -- Disable the main text's built-in shadow
    mainText:SetShadowColor(0, 0, 0, 0)
    mainText:SetShadowOffset(0, 0)

    local shadows = {}
    for i, offset in ipairs(SHADOW_OFFSETS) do
        local shadow = parent:CreateFontString(nil, "BACKGROUND")
        shadow:SetFont(font, size, "")
        shadow:SetTextColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowAlpha)
        -- Anchor to CENTER so shadows follow text movement regardless of width
        shadow:SetPoint("CENTER", mainText, "CENTER", offset[1], offset[2])
        shadow:SetText(mainText:GetText() or "")
        -- Match the parent text's justification
        shadow:SetJustifyH(mainText:GetJustifyH())
        shadows[i] = shadow
    end

    return shadows
end

-- UpdateStackedShadowText: Update all stacked shadow FontStrings with new text
function NRSKNUI:UpdateStackedShadowText(shadows, text)
    if not shadows then return end
    for _, shadow in ipairs(shadows) do
        shadow:SetText(text)
    end
end
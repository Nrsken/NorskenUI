-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local CreateFrame = CreateFrame
local type = type
local ipairs = ipairs

-- Slider widget
function GUIFrame:CreateText(parent, titleTex, labelText, customRowHeight, bgShow, wrapOn)
    -- Row
    local rowHeight = customRowHeight or 34
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(rowHeight)

    local container = CreateFrame("Frame", nil, row, "BackdropTemplate")
    container:SetHeight(rowHeight)
    container:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    container:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })

    if bgShow == "show" then
        container:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
        container:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    elseif bgShow == "border" then
        container:SetBackdropColor(0, 0, 0, 0)
        container:SetBackdropBorderColor(0, 0, 0, 1)
    elseif bgShow == "hide" then
        container:SetBackdropColor(0, 0, 0, 0)
        container:SetBackdropBorderColor(0, 0, 0, 0)
    end

    -- Label
    local title = container:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", container, "TOPLEFT", 1, -1)
    title:SetPoint("TOPRIGHT", container, "TOPRIGHT", -1, -1)
    title:SetHeight(18)
    title:SetJustifyH("LEFT")
    NRSKNUI:ApplyThemeFont(title, "large")
    title:SetText(titleTex or "")
    title:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    title:SetShadowColor(0, 0, 0, 0)

    local titleHeight = title:GetStringHeight()
    local smolSpacer = 2
    local totSpacer = titleHeight + smolSpacer

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -totSpacer)
    label:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetSpacing(4)
    label:SetWordWrap(true)
    label:SetNonSpaceWrap(true)
    NRSKNUI:ApplyThemeFont(label, "small")
    local function ResolveLabelText(input)
        if type(input) == "function" then
            input = input()
        end

        if type(input) == "table" then
            for i, v in ipairs(input) do
                input[i] = NRSKNUI:ColorTextByTheme("• ") .. v
            end
            return table.concat(input, "\n")
        end

        return input or ""
    end
    label:SetText(ResolveLabelText(labelText))
    label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    label:SetShadowColor(0, 0, 0, 0)

    function row:SetEnabled(enabled)
        if enabled then
            row:SetAlpha(1)
        else
            row:SetAlpha(0.4)
        end
    end

    row.container = container
    container.label = label
    return row
end

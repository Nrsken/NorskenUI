--[[
# Text

* A read-only text block: an accent-less title above a body paragraph.
* The body accepts a string, a function returning one, or a list (rendered as a bulleted list).

## Examples

    row:Text('About', {
        text = 'This module does a thing.'
    })

    row:Text('Notes', {
        text = { 'First point', 'Second point' },
        height = 60,
        bgMode = 'show',
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local type = type
local ipairs = ipairs
local tconcat = table.concat

---@class KajiGUIText : Frame
---@field container Frame|BackdropTemplate
---@field SetEnabled fun(self: KajiGUIText, enabled: boolean)

---@class KajiGUITextConfig
---@field text? string|string[]|fun(): string|string[]
---@field height? number
---@field bgMode? "show"|"border"|"hide"
---@field wrapOn? boolean

---@param parent Frame
---@param titleText string
---@param config? KajiGUITextConfig
---@return KajiGUIText
function InstanceMixin:CreateText(parent, titleText, config)
    config = config or {}
    local gui = self
    local theme = self.theme
    local bodyText = config.text
    local rowHeight = config.height or 34
    local bgMode = config.bgMode

    local row = CreateFrame("Frame", nil, parent)
    pixel.SetPixelHeight(row, rowHeight)

    local container = CreateFrame("Frame", nil, row, "BackdropTemplate")
    pixel.SetPixelHeight(container, rowHeight)
    pixel.SetPixelPoint(container, "TOPLEFT", row, "TOPLEFT", 0, 0)
    pixel.SetPixelPoint(container, "TOPRIGHT", row, "TOPRIGHT", 0, 0)
    container:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })

    if bgMode == "show" then
        container:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], 1)
        container:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
    elseif bgMode == "border" then
        container:SetBackdropColor(0, 0, 0, 0)
        container:SetBackdropBorderColor(0, 0, 0, 1)
    else
        container:SetBackdropColor(0, 0, 0, 0)
        container:SetBackdropBorderColor(0, 0, 0, 0)
    end
    row.container = container

    local title = container:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(title, "TOPLEFT", container, "TOPLEFT", 1, -1)
    pixel.SetPixelPoint(title, "TOPRIGHT", container, "TOPRIGHT", -1, -1)
    pixel.SetPixelHeight(title, 18)
    title:SetJustifyH("LEFT")
    gui:ApplyFont(title, "large")
    title:SetText(titleText or "")
    title:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)

    local totSpacer = title:GetStringHeight() + 2

    local label = container:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "TOPLEFT", container, "TOPLEFT", 0, -totSpacer)
    pixel.SetPixelPoint(label, "BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetSpacing(4)
    label:SetWordWrap(true)
    label:SetNonSpaceWrap(true)
    gui:ApplyFont(label, "small")
    label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)

    local function ResolveBody(input)
        if type(input) == "function" then
            input = input()
        end
        if type(input) == "table" then
            local lines = {}
            for i, v in ipairs(input) do
                lines[i] = gui:ColorText("• ") .. v
            end
            return tconcat(lines, "\n")
        end
        return input or ""
    end
    label:SetText(ResolveBody(bodyText))
    container.label = label

    function row:SetEnabled(enabled)
        self:SetAlpha(enabled and 1 or 0.4)
    end

    ---@cast row KajiGUIText
    return row
end

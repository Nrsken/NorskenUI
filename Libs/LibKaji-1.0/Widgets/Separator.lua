--[[
# Separator

* A thin horizontal divider, optionally with an accent label above it.

## Examples

?   GUI:CreateSeparator(parent)
?   GUI:CreateSeparator(parent, 'Advanced', {
?       useLabel = true
?   })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local CreateColor = CreateColor
local type = type

---@class KajiGUISeparator : Frame, BackdropTemplate
---@field SetEnabled fun(self: KajiGUISeparator, enabled: boolean)

---@param parent Frame
---@param labelText? string
---@param config? { useLabel?: boolean, height?: number }
---@return KajiGUISeparator
function InstanceMixin:CreateSeparator(parent, labelText, config)
    if type(config) ~= "table" then config = {} end
    local theme = self.theme
    local useLabel = config.useLabel or false
    local height = config.height or 6
    local offset = useLabel and 5 or 0

    -- Create the separator frame
    local separator = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    pixel.SetPixelHeight(separator, height)
    pixel.SetPixelPoint(separator, "TOPLEFT", parent, "TOPLEFT", 0, 0)
    pixel.SetPixelPoint(separator, "TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    -- Create the texture for the separator
    local r, g, b = theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3]
    local texture = separator:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelHeight(texture, 2)
    pixel.SetPixelPoint(texture, "LEFT", separator, "LEFT", 0, -offset)
    pixel.SetPixelPoint(texture, "RIGHT", separator, "RIGHT", 0, -offset)
    texture:SetColorTexture(1, 1, 1, 1)
    texture:SetGradient("HORIZONTAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, 1))
    pixel.SetPixelSnap(texture)

    -- Create the label if useLabel is true
    if useLabel then
        local headerLabel = separator:CreateFontString(nil, "OVERLAY")
        pixel.SetPixelPoint(headerLabel, "LEFT", separator, "LEFT", 0, offset)
        self:ApplyFont(headerLabel, "normal")
        headerLabel:SetText(labelText)
        headerLabel:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    end

    -- Set the enabled state of the separator
    function separator:SetEnabled(enabled)
        separator:SetAlpha(enabled and 1 or 0.5)
    end

    ---@cast separator KajiGUISeparator
    return separator
end

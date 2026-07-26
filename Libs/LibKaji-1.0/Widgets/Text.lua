--[[
# Text

* A read-only text block: an accent-less title above a body paragraph.
* The body accepts a string, a function returning one, or a list (rendered as a bulleted list).
* Without a `height` the block measures its own wrapped text and grows the row it sits in to fit,
  so dynamic text is never clipped. Pass a `height` for a fixed box instead.

## Examples

    row:Text('About', {
        text = 'This module does a thing.'
    })

    row:Text('Notes', {
        text = { 'First point', 'Second point' },
        height = 60,
        bgMode = 'show',
    })

    -- Grows with the text, never shorter than 40.
    row:Text('Matches auras in any of 2 branches:', {
        text = { 'Branch 1: HELPFUL', 'Branch 2: HARMFUL' },
        autoHeight = true,
        minHeight = 40,
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local type = type
local ipairs = ipairs
local abs = math.abs
local max = math.max
local tconcat = table.concat

---@alias KajiGUITextBody string|string[]|fun(): string|string[]

---@class KajiGUIText : Frame
---@field container Frame|BackdropTemplate
---@field SetEnabled fun(self: KajiGUIText, enabled: boolean)
---@field SetText fun(self: KajiGUIText, text: KajiGUITextBody)

---@class KajiGUITextConfig
---@field text? KajiGUITextBody
---@field height? number fixed height; omitting it sizes the block to its wrapped text
---@field autoHeight? boolean force auto sizing even with a height set (which then acts as a floor)
---@field minHeight? number shortest the block may get while auto sizing
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

    -- A height means the caller sized the box themselves, so honour it unless they opt back in.
    local autoHeight = config.autoHeight
    if autoHeight == nil then autoHeight = config.height == nil end
    local minHeight = config.minHeight or config.height or 0

    local row = CreateFrame("Frame", nil, parent)
    pixel.SetPixelHeight(row, rowHeight)
    -- Keeps the row it is added to from stamping its own height back over the measured one.
    if autoHeight then row.explicitHeight = true end

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

    local totSpacer = title:GetStringHeight() + 6

    -- Auto sizing anchors one corner and sets the width itself, so GetStringHeight reports the
    -- wrapped height right away. Pinning both sides only resolves the width on the next layout pass,
    -- which would leave us measuring against the previous one.
    local label = container:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "TOPLEFT", container, "TOPLEFT", 0, -totSpacer)
    if autoHeight then
        label:SetJustifyV("TOP")
    else
        pixel.SetPixelPoint(label, "BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    end
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

    -- Last height we settled on. Nil until the first measure, so the row always hears about it once.
    local measured

    ---Sizes the block to its wrapped text at the given width and passes the height up to the row.
    ---@param width number?
    local function Measure(width)
        -- No width yet means the row has not been laid out; OnSizeChanged brings us back.
        if not autoHeight or not width or width <= 0 then return end

        pixel.SetPixelWidth(label, width)
        local desired = max(totSpacer + (label:GetStringHeight() or 0) + theme.paddingSmall, minHeight)
        -- Bailing on an unchanged height is what stops resize -> OnSizeChanged -> resize looping.
        if measured and abs(desired - measured) < 0.5 then return end

        measured = desired
        pixel.SetPixelHeight(container, desired)
        pixel.SetPixelHeight(row, desired)

        local owner = row:GetParent()
        if owner and owner.SetContentHeight then owner:SetContentHeight(desired) end
    end

    row:SetScript("OnSizeChanged", function(self, width) Measure(width) end)

    ---Replaces the body text, remeasuring when the block sizes itself.
    ---@param text string|string[]|fun(): string|string[]
    function row:SetText(text)
        label:SetText(ResolveBody(text))
        Measure(self:GetWidth())
    end

    function row:SetEnabled(enabled)
        self:SetAlpha(enabled and 1 or 0.4)
    end

    ---@cast row KajiGUIText
    return row
end

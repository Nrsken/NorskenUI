--[[
# SectionHeader

* A clickable bar that opens and closes a run of rows inside one card: arrow, title, and an optional
  right-aligned cluster of icon actions (move up, move down, duplicate, delete).
* Built for repeating lists that live in a single card rather than a card each, so a list of branches
  or conditions reads as one thing. Modelled on the WeakAuras Conditions tab.
* The header owns no rows. Collapsing is the caller omitting the body on the next build, which is why
  this stays a plain row and needs nothing from the card's layout (see FluentCard:Section).

## Examples

API: card:Section('1. Big Defensives', { collapsed = false, onToggle = fn, onDelete = fn })
API: GUI:CreateSectionHeader(parent, 'Conditions', { onToggle = fn })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local Mixin = Mixin
local ipairs = ipairs
local mpi = math.pi
local GetAtlasInfo = C_Texture and C_Texture.GetAtlasInfo

local WIDGET_TYPE = "SectionHeader"
local HEIGHT = 26
local ARROW_SIZE = 10
local ACTION_SIZE = 18
local ACTION_SPACING = 2

-- Right to left, so the rightmost action is the destructive one and the cluster keeps its order
-- however many of them a caller opts into.
local ACTIONS = {
    { key = "onDelete",    atlas = "transmog-icon-remove",            rotation = 0,   tooltipKey = "deleteTooltip" },
    { key = "onDuplicate", atlas = "communities-icon-addchannelplus", rotation = 0,   tooltipKey = "duplicateTooltip" },
    { key = "onMoveDown",  atlas = "channels-icon-arrowdown",         rotation = 0,   tooltipKey = "moveDownTooltip" },
    { key = "onMoveUp",    atlas = "channels-icon-arrowup",           rotation = mpi, tooltipKey = "moveUpTooltip" },
}

---Atlas if the client still has one by that name, otherwise fall back to theme media so a button is
---never invisible. Move up/down share one fallback and are told apart by rotation.
---@param texture Texture
---@param action table
---@param theme table
local function SetIcon(texture, action, theme)
    if GetAtlasInfo and GetAtlasInfo(action.atlas) then
        texture:SetAtlas(action.atlas)
        texture:SetRotation(0)
        return
    end

    texture:SetTexture(action.key == "onDelete" and theme.crossTexture or theme.stepperTexture)
    texture:SetRotation(action.rotation or 0)
end

---@class KajiGUISectionHeaderMixin : Frame, BackdropTemplate
---@field gui KajiGUIInstance
---@field arrow Texture
---@field label FontString
---@field actions Button[]
local SectionHeaderMixin = {}

---@param enabled boolean
function SectionHeaderMixin:SetEnabled(enabled)
    self:SetAlpha(enabled and 1 or 0.5)
    self:EnableMouse(enabled)
end

function SectionHeaderMixin:UpdateColors()
    local theme = self.gui.theme
    lib.RefreshBackdrop(self)
    self.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    self.arrow:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.9)
end

---@param parent Frame
---@param labelText? string
---@param config table
function SectionHeaderMixin:OnAcquire(parent, labelText, config)
    local theme = self.gui.theme

    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelHeight(self, HEIGHT)
    -- Read by FluentCard:Section, so the card lays the row out to a known height rather than
    -- whatever GetHeight happens to report before the frame has been drawn.
    self.layoutHeight = HEIGHT
    pixel.SetPixelPoint(self, "TOPLEFT", parent, "TOPLEFT", 0, 0)
    pixel.SetPixelPoint(self, "TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    self._onToggle = config.onToggle
    -- Collapsed points right, expanded points down, matching the main sidebar's headers.
    self.arrow:SetRotation(config.collapsed and mpi / 2 or 0)

    self.gui:ApplyFont(self.label, "normal")
    self.label:SetText(labelText or "")

    -- Actions are laid out right to left, so an omitted one leaves no gap.
    local x = -theme.paddingSmall
    for _, action in ipairs(ACTIONS) do
        local button = self.actions[action.key]
        local callback = config[action.key]

        button:SetShown(callback ~= nil)
        button._callback = callback
        lib.SetTooltip(button, self.gui, nil, config[action.tooltipKey], { anchor = "ANCHOR_TOP", x = 0, y = 4 })

        if callback then
            button:ClearAllPoints()
            pixel.SetPixelPoint(button, "RIGHT", self, "RIGHT", x, 0)
            x = x - ACTION_SIZE - ACTION_SPACING
        end
    end

    -- The title stops where the action cluster starts, so a long name truncates instead of running under it.
    self.label:ClearAllPoints()
    pixel.SetPixelPoint(self.label, "LEFT", self, "LEFT", theme.paddingSmall + ARROW_SIZE + 6, 0)
    pixel.SetPixelPoint(self.label, "RIGHT", self, "RIGHT", x - theme.paddingSmall, 0)

    self:SetAlpha(1)
    self:EnableMouse(true)
    self:UpdateColors()
    self:Show()
end

function SectionHeaderMixin:OnRelease()
    self._onToggle = nil
    self.label:SetText("")
    for _, action in ipairs(ACTIONS) do
        local button = self.actions[action.key]
        button._callback = nil
        lib.ClearTooltip(button)
        button:Hide()
    end
end

---@class KajiGUISectionHeader : KajiGUISectionHeaderMixin

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local header = CreateFrame("Button", nil, gui._poolHost, "BackdropTemplate")
    header.gui = gui
    header:RegisterForClicks("LeftButtonUp")

    local hoverBg = header:CreateTexture(nil, "BACKGROUND")
    hoverBg:SetAllPoints()
    hoverBg:SetColorTexture(1, 1, 1, 0.04)
    hoverBg:Hide()

    header:SetScript("OnEnter", function() hoverBg:Show() end)
    header:SetScript("OnLeave", function() hoverBg:Hide() end)
    header:SetScript("OnClick", function(self)
        if self._onToggle then safecall(self._onToggle) end
    end)

    local arrow = header:CreateTexture(nil, "OVERLAY")
    pixel.SetPixelSize(arrow, ARROW_SIZE, ARROW_SIZE)
    arrow:SetTexture(gui.theme.stepperTexture)
    header.arrow = arrow

    local label = header:CreateFontString(nil, "OVERLAY")
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    header.label = label

    -- The arrow is placed after the label so both exist before anchoring.
    pixel.SetPixelPoint(arrow, "LEFT", header, "LEFT", gui.theme.paddingSmall, 0)

    -- Every action button is created up front and hidden when unused, so a recycled header never
    -- finds itself missing one.
    header.actions = {}
    for _, action in ipairs(ACTIONS) do
        local button = CreateFrame("Button", nil, header)
        pixel.SetPixelSize(button, ACTION_SIZE, ACTION_SIZE)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        SetIcon(icon, action, gui.theme)
        icon:SetAlpha(0.7)

        button:SetScript("OnEnter", function(self)
            icon:SetAlpha(1)
            lib.ShowTooltip(self)
        end)
        button:SetScript("OnLeave", function()
            icon:SetAlpha(0.7)
            lib.HideTooltip()
        end)
        button:SetScript("OnClick", function(self)
            if self._callback then safecall(self._callback) end
        end)

        button:Hide()
        header.actions[action.key] = button
    end

    return Mixin(header, SectionHeaderMixin)
end)

---@param parent Frame
---@param labelText? string
---@param config? { collapsed?: boolean, onToggle?: fun(), onMoveUp?: fun(), onMoveDown?: fun(), onDuplicate?: fun(), onDelete?: fun() }
---@return KajiGUISectionHeader
function InstanceMixin:CreateSectionHeader(parent, labelText, config)
    return self:BuildWidget(WIDGET_TYPE, parent, labelText, config)
end

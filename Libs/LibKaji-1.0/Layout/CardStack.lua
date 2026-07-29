--[[
# CardStack

* An ordered stack of cards anchored into a scroll child.
* Each card is positioned below the previous one and the scroll child is sized to fit the total height of the stack.
* The stack can be paused to batch several changes into one reflow.

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel

local ipairs = ipairs
local Mixin = Mixin

---@class KajiGUICardStackMixin
---@field gui KajiGUIInstance owning instance (for theme)
---@field parent Frame the scroll child cards live in
---@field topOffset number y position of the first card
---@field cards Frame[] ordered cards
---@field laying boolean
---@field pending boolean
---@field onLayout? fun(height: number)
local CardStackMixin = {}

---Tracks a card as the next entry in the stack.
---@generic T : Frame
---@param card T
---@return T card the same card, for inline use
function CardStackMixin:Add(card)
    self.cards[#self.cards + 1] = card
    -- Lets a card that grew on its own (auto-height text) pull the stack back into line.
    card._onHeightChanged = function() self:DoLayout() end
    return card
end

---Re-anchors every card below the previous one and sizes the scroll child.
---Call after any card changes height.
---@return number height the total stack height the scroll child was sized to
function CardStackMixin:DoLayout()
    -- Re-anchoring a card can resize it (auto-height text remeasures on the new width), which lands
    -- back here mid-pass. Fold that into one more pass rather than recursing through the stack.
    if self.laying then
        self.pending = true
        return self.parent:GetHeight()
    end
    self.laying = true

    local pad = self.gui.theme.paddingSmall
    local y = self.topOffset
    for _, card in ipairs(self.cards) do
        card:ClearAllPoints()
        pixel.SetPixelPoint(card, "TOPLEFT", self.parent, "TOPLEFT", pad, -y)
        pixel.SetPixelPoint(card, "RIGHT", self.parent, "RIGHT", -pad, 0)
        card._yOffset = y
        y = card:GetNextOffset()
    end

    pixel.SetPixelHeight(self.parent, y)
    self.laying = false

    if self.pending then
        self.pending = false
        return self:DoLayout()
    end

    if self.onLayout then self.onLayout(y) end

    return y
end

---Creates a card stack anchored into a scroll child.
---@param parent Frame the scroll child
---@param topOffset? number y of the first card (defaults to a small padding)
---@param onLayout? fun(height: number) called after each layout, for host chrome
---@return KajiGUICardStack
function InstanceMixin:CreateCardStack(parent, topOffset, onLayout)
    ---@class KajiGUICardStack : KajiGUICardStackMixin
    local stack = {
        gui = self,
        parent = parent,
        topOffset = topOffset or self.theme.paddingSmall,
        cards = {},
        laying = false,
        pending = false,
        onLayout = onLayout,
    }

    return Mixin(stack, CardStackMixin)
end

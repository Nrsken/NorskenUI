---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local Mixin = Mixin
local ipairs = ipairs
local floor = math.floor

local CENTRED_POINTS = { CENTER = true, LEFT = true, RIGHT = true }

local SkinnedStatusBarMixin = {}

function SkinnedStatusBarMixin:NUIUpdateSkinColors()
    local border = NRSKNUI:GetBorderColor(Skinning.db.General)
    self:SetBorderColor(border[1], border[2], border[3], border[4])

    if self.NUIKeepColor then return end

    local r, g, b = Skinning:GetAccentColor()
    self:SetStatusBarColor(r, g, b)
end

---Drop the vertical nudge from text that is meant to sit centred on the bar.
---@param bar StatusBar
local function CentreBarText(bar)
    for _, region in ipairs({ bar:GetRegions() }) do
        if region:IsObjectType('FontString') then
            local point, relativeTo, relativePoint, x = region:GetPoint()
            if point and CENTRED_POINTS[point] then
                region:NUISetPixelPoint(point, relativeTo or bar, relativePoint or point, x or 0, 0)
            end
        end
    end
end

---@param bar StatusBar
local function AlignBarParity(bar)
    local point, relativeTo = bar:GetPoint()
    if not point or not CENTRED_POINTS[point] then return end

    relativeTo = relativeTo or bar:GetParent()
    local anchorHeight = relativeTo and NRSKNUI:SafeValue(relativeTo:GetHeight())
    local barHeight = anchorHeight and NRSKNUI:SafeValue(bar:GetHeight())
    if not barHeight or barHeight == 0 then return end

    barHeight = floor(barHeight + 0.5)
    if (floor(anchorHeight + 0.5) - barHeight) % 2 ~= 0 then
        bar:NUISetPixelHeight(barHeight + 1)
    end
end

---Skin a StatusBar: strips art, applies our statusbar texture and a backdrop
---@param bar StatusBar
---@param keepColor boolean? Keep Blizzard's bar color (e.g. faction reputation colors)
function Skinning:HandleStatusBar(bar, keepColor)
    if not bar or bar.NUISkinned then return end
    bar.NUISkinned = true

    bar:NUIStripTextures()
    bar:SetStatusBarTexture(NRSKNUI.Media.Statusbars.NorskenUI)
    self:CreateStatusBarBackdrop(bar)

    AlignBarParity(bar)
    -- Blizzard positions these bars (ScrollBox rows land on half pixels), so leave grid snapping on.
    bar:NUIAddBorders(true)
    CentreBarText(bar)

    ---@cast bar StatusBar & SkinnedStatusBarMixin
    Mixin(bar, SkinnedStatusBarMixin)

    bar.NUIKeepColor = keepColor or nil
    bar:NUIUpdateSkinColors()
    self:RegisterSkinned(bar)
end

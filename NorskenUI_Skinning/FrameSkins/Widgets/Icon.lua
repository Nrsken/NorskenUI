---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local CreateFrame = CreateFrame
local Mixin = Mixin

local SkinnedIconBackdropMixin = {}

---Forward a Blizzard IconBorder's quality color onto our border, r/g/b may be secret so never compare them.
---@param r number
---@param g number
---@param b number
function SkinnedIconBackdropMixin:NUISetQualityColor(r, g, b)
    self.NUIQualityShown = true
    self:SetBorderColor(r, g, b, 1)
end

function SkinnedIconBackdropMixin:NUIResetQualityColor()
    self.NUIQualityShown = nil
    self:NUIUpdateSkinColors()
end

function SkinnedIconBackdropMixin:NUIUpdateSkinColors()
    local general = Skinning.db.General
    if not self.NUIQualityShown then
        local border = self.NUIFill and general.WidgetBorderColor or NRSKNUI:GetBorderColor(general)
        self:SetBorderColor(border[1], border[2], border[3], border[4])
    end

    if not self.NUIFill then return end

    local bg = general.WidgetBackgroundColor
    self.NUIFill:SetColorTexture(bg[1], bg[2], bg[3], bg[4])

    local glow = general.WidgetGlowColor
    self.NUIGlow:SetVertexColor(glow[1], glow[2], glow[3], glow[4])
end

---@param icon Texture
---@param createBackdrop boolean? Create a border frame behind the icon
---@param skipZoom boolean? Leave the texcoords alone, for an icon already showing an atlas
---@param isWidget boolean? Fill it from the Widget palette, so an empty or dimmed icon reads as a slot
function Skinning:HandleIcon(icon, createBackdrop, skipZoom, isWidget)
    if not icon then return end

    if not skipZoom then icon:NUISetZoom() end

    if createBackdrop and not icon.NUIBackdrop then
        local parent = icon:GetParent()
        local backdrop = CreateFrame('Frame', nil, parent)
        backdrop:SetPoint('TOPLEFT', icon, -1, 1)
        backdrop:SetPoint('BOTTOMRIGHT', icon, 1, -1)
        backdrop:NUIAddBorders()
        backdrop:SetFrameLevel(parent:GetFrameLevel())
        backdrop:SetBorderLayer('ARTWORK', 7)

        -- BACKGROUND sits under the icon's own ARTWORK, so only an empty or dimmed icon shows it.
        if isWidget then
            local fill = backdrop:CreateTexture(nil, 'BACKGROUND')
            fill:SetAllPoints(backdrop)
            fill:NUISetPixelSnap() -- AddBorders owns the pixel math, an unsnapped fill rounds off it
            backdrop.NUIFill = fill

            local glow = backdrop:CreateTexture(nil, 'BACKGROUND', nil, 2)
            glow:SetAllPoints(fill)
            glow:SetAtlas(self.WidgetGlowAtlas)
            glow:SetDesaturated(true)
            backdrop.NUIGlow = glow
        end

        ---@cast backdrop Frame & PublicBackdropMixin & SkinnedIconBackdropMixin
        Mixin(backdrop, SkinnedIconBackdropMixin)
        backdrop:NUIUpdateSkinColors()

        self:RegisterSkinned(backdrop)
        icon.NUIBackdrop = backdrop
    end
end

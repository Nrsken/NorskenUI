---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local CreateFrame = CreateFrame
local Mixin = Mixin

local SkinnedIconBackdropMixin = {}

function SkinnedIconBackdropMixin:NUIUpdateSkinColors()
    local general = Skinning.db.General
    local border = self.NUIFill and general.WidgetBorderColor or general.BorderColor
    self:SetBorderColor(border[1], border[2], border[3], border[4])

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

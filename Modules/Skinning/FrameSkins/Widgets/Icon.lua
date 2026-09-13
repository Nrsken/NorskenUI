---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local CreateFrame = CreateFrame
local Mixin = Mixin

local SkinnedIconBackdropMixin = {}

function SkinnedIconBackdropMixin:NUIUpdateSkinColors()
    local border = Skinning.db.General.BorderColor
    self:SetBorderColor(border[1], border[2], border[3], border[4])
end

---@param icon Texture
---@param createBackdrop boolean? Create a border frame behind the icon
function Skinning:HandleIcon(icon, createBackdrop)
    if not icon then return end

    icon:NUISetZoom()

    if createBackdrop and not icon.NUIBackdrop then
        local parent = icon:GetParent()
        local backdrop = CreateFrame('Frame', nil, parent)
        backdrop:SetPoint('TOPLEFT', icon, -1, 1)
        backdrop:SetPoint('BOTTOMRIGHT', icon, 1, -1)
        backdrop:NUIAddBorders()
        local border = self.db.General.BorderColor
        backdrop:SetBorderColor(border[1], border[2], border[3], border[4])

        ---@cast backdrop Frame & PublicBackdropMixin & SkinnedIconBackdropMixin
        Mixin(backdrop, SkinnedIconBackdropMixin)

        self:RegisterSkinned(backdrop)
        icon.NUIBackdrop = backdrop
    end
end

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local Mixin = Mixin

local SkinnedStatusBarMixin = {}

function SkinnedStatusBarMixin:NUIUpdateSkinColors()
    if self.NUIKeepColor then return end

    local r, g, b = Skinning:GetAccentColor()
    self:SetStatusBarColor(r, g, b)
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

    ---@cast bar StatusBar & SkinnedStatusBarMixin
    Mixin(bar, SkinnedStatusBarMixin)

    bar.NUIKeepColor = keepColor or nil
    if not keepColor then
        local r, g, b = self:GetAccentColor()
        bar:SetStatusBarColor(r, g, b)
    end
    self:RegisterSkinned(bar)
end

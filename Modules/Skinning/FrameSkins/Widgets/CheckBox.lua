---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local Mixin = Mixin

-- The backdrop's border sits on the outer edge of its own fill, and lives on a lower frame, so the
-- tick has to stop short of it rather than rely on draw order.
local BORDER_WIDTH = 1
local CHECK_ALPHA = 0.9
local DISABLED_R, DISABLED_G, DISABLED_B, DISABLED_A = 0.5, 0.5, 0.5, 0.75

---@class SkinnedCheckMixin
---@field NUILocked boolean? Paint the fill dead while the button stays clickable
local SkinnedCheckMixin = {}

-- SetCheckButtonIsRadio rewrites every state texture, so the set has to stay re-appliable.
function SkinnedCheckMixin:NUIApplyCheckTextures()
    if self.SetNormalTexture then
        self:SetNormalTexture(NRSKNUI.ClearTexture)
        self:SetPushedTexture(NRSKNUI.ClearTexture)
        self:SetHighlightTexture(NRSKNUI.ClearTexture)
    end

    -- Tracking the backdrop's fill keeps the tick centred in the box at any size.
    local inner = self.NUIBackdrop and self.NUIBackdrop.backdropBackground
    if not inner then return end

    -- Some templates ship no state textures at all, so the fill has nothing to recolor yet.
    if not self:GetCheckedTexture() then
        self:SetCheckedTexture(NRSKNUI.ClearTexture)
    end

    local checked = self:GetCheckedTexture()
    if checked then
        checked:ClearAllPoints()
        checked:NUISetPixelPoint('TOPLEFT', inner, 'TOPLEFT', BORDER_WIDTH, -BORDER_WIDTH)
        checked:NUISetPixelPoint('BOTTOMRIGHT', inner, 'BOTTOMRIGHT', -BORDER_WIDTH, BORDER_WIDTH)
    end

    local disabledChecked = self.GetDisabledCheckedTexture and self:GetDisabledCheckedTexture()
    if disabledChecked then
        disabledChecked:SetColorTexture(DISABLED_R, DISABLED_G, DISABLED_B, DISABLED_A)
        disabledChecked:ClearAllPoints()
        disabledChecked:NUISetPixelPoint('TOPLEFT', inner, 'TOPLEFT', BORDER_WIDTH, -BORDER_WIDTH)
        disabledChecked:NUISetPixelPoint('BOTTOMRIGHT', inner, 'BOTTOMRIGHT', -BORDER_WIDTH, BORDER_WIDTH)
    end

    self:NUIUpdateSkinColors()
end

function SkinnedCheckMixin:NUIUpdateSkinColors()
    local checked = self:GetCheckedTexture()
    if not checked then return end

    if self.NUILocked then
        checked:SetColorTexture(DISABLED_R, DISABLED_G, DISABLED_B, DISABLED_A)
        return
    end

    local r, g, b = Skinning:GetAccentColor()
    checked:SetColorTexture(r, g, b, CHECK_ALPHA)
end

---Skin a CheckButton: box backdrop with an accent-colored fill when checked
---@param check CheckButton
---@param inset number? Shrink the panel inside the button, for boxes that overhang a tighter row
function Skinning:HandleCheckBox(check, inset)
    if not check or check.NUISkinned or not check.GetCheckedTexture then return end
    check.NUISkinned = true

    local backdrop = self:CreatePanelBackdrop(check, nil, nil, true)
    if inset and backdrop then
        backdrop:ClearAllPoints()
        backdrop:NUISetPixelPoint('TOPLEFT', check, 'TOPLEFT', inset, -inset)
        backdrop:NUISetPixelPoint('BOTTOMRIGHT', check, 'BOTTOMRIGHT', -inset, inset)
    end

    ---@cast check CheckButton & SkinnedCheckMixin
    Mixin(check, SkinnedCheckMixin)
    check:NUIApplyCheckTextures()

    self:RegisterSkinned(check)
end

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local Mixin = Mixin

local SkinnedCheckMixin = {}

function SkinnedCheckMixin:NUIUpdateSkinColors()
    local checked = self:GetCheckedTexture()
    if not checked then return end

    local r, g, b = Skinning:GetAccentColor()
    checked:SetColorTexture(r, g, b, 0.9)
end

---Skin a CheckButton: box backdrop with an accent-colored fill when checked
---@param check CheckButton
function Skinning:HandleCheckBox(check)
    if not check or check.NUISkinned or not check.GetCheckedTexture then return end
    check.NUISkinned = true

    if check.SetNormalTexture then
        check:SetNormalTexture(NRSKNUI.ClearTexture)
        check:SetPushedTexture(NRSKNUI.ClearTexture)
        check:SetHighlightTexture(NRSKNUI.ClearTexture)
    end

    self:CreatePanelBackdrop(check, nil, nil, true)

    local r, g, b = self:GetAccentColor()
    local checked = check:GetCheckedTexture()
    if checked then
        checked:SetColorTexture(r, g, b, 0.9)
        checked:ClearAllPoints()
        checked:SetPoint('TOPLEFT', 4, -4)
        checked:SetPoint('BOTTOMRIGHT', -4, 4)
    end

    local disabledChecked = check.GetDisabledCheckedTexture and check:GetDisabledCheckedTexture()
    if disabledChecked then
        disabledChecked:SetColorTexture(0.5, 0.5, 0.5, 0.75)
        disabledChecked:ClearAllPoints()
        disabledChecked:SetPoint('TOPLEFT', 4, -4)
        disabledChecked:SetPoint('BOTTOMRIGHT', -4, 4)
    end

    ---@cast check CheckButton & SkinnedCheckMixin
    Mixin(check, SkinnedCheckMixin)

    self:RegisterSkinned(check)
end

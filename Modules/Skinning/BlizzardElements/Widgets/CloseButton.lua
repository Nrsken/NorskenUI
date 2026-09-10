---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local Mixin = Mixin
local math_max = math.max
local math_rad = math.rad

local CROSS_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomCrossv3.png'

local SkinnedCloseButtonMixin = {}

function SkinnedCloseButtonMixin:NUIOnEnter()
    local r, g, b = Skinning:GetAccentColor()
    self.NUIBtnCross:SetVertexColor(r, g, b)
end

function SkinnedCloseButtonMixin:NUIOnLeave()
    self.NUIBtnCross:SetVertexColor(1, 0, 0)
end

---Skin a close button: strips the round art, draws a plain cross with accent hover
---@param button Button
---@param relativeTo Frame? Re-anchor the button to this frame's TOPRIGHT
---@param xOffset number? Defaults to -2
---@param yOffset number? Defaults to -2
---@param size number? Size of the close button cross
function Skinning:HandleCloseButton(button, relativeTo, xOffset, yOffset, size)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    if button.SetNormalTexture then
        button:SetNormalTexture(NRSKNUI.ClearTexture)
        button:SetPushedTexture(NRSKNUI.ClearTexture)
        button:SetDisabledTexture(NRSKNUI.ClearTexture)
        button:SetHighlightTexture(NRSKNUI.ClearTexture)
    end
    button:NUIStripTextures()

    if relativeTo then
        button:NUISetPixelPoint('TOPRIGHT', relativeTo, 'TOPRIGHT', xOffset or -2, yOffset or -2)
    end

    if not size then
        local width = button:GetWidth()
        size = NRSKNUI:NotSecretValue(width) and math_max(8, width * 0.8) or 8
    end

    local cross = button:CreateTexture(nil, 'OVERLAY')
    cross:SetPoint('CENTER')
    cross:SetSize(size, size)
    cross:SetTexture(CROSS_TEXTURE)
    cross:SetRotation(math_rad(45))
    cross:NUISetPixelSnap()
    cross:SetVertexColor(1, 0, 0)

    ---@cast button Button & SkinnedCloseButtonMixin
    Mixin(button, SkinnedCloseButtonMixin)

    button.NUIBtnCross = cross
    button:HookScript('OnEnter', button.NUIOnEnter)
    button:HookScript('OnLeave', button.NUIOnLeave)
end

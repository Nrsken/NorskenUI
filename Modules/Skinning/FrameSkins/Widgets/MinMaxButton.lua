---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local next = next
local Mixin = Mixin
local math_max = math.max
local math_rad = math.rad

local ARROW_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\up-right-arrow.png'

local SkinnedMinMaxButtonMixin = {}

function SkinnedMinMaxButtonMixin:NUIOnEnter()
    local r, g, b = Skinning:GetAccentColor()
    self.NUIBtnMinMax:SetVertexColor(r, g, b)
end

function SkinnedMinMaxButtonMixin:NUIOnLeave()
    self.NUIBtnMinMax:SetVertexColor(0.9, 0.9, 0.9)
end

---@param frame Frame
function Skinning:HandleMinMaxButton(frame)
    if not frame or frame.NUISkinned then return end
    frame.NUISkinned = true

    for buttonName, buttonDirection in next, {
        MaximizeButton = 'expand',
        MinimizeButton = 'collapse'
    } do
        local btn = frame[buttonName]
        if btn then
            if btn.SetNormalTexture then
                btn:SetNormalTexture(NRSKNUI.ClearTexture)
                btn:SetPushedTexture(NRSKNUI.ClearTexture)
                btn:SetDisabledTexture(NRSKNUI.ClearTexture)
                btn:SetHighlightTexture(NRSKNUI.ClearTexture)
            end
            btn:NUIStripTextures()

            local point, relativeTo, relativePoint, x, y = btn:GetPoint()
            btn:NUISetPixelPoint(point, relativeTo or btn:GetParent(), relativePoint or point, x or 0, y or 0)

            local width = btn:GetWidth()
            local size = NRSKNUI:NotSecretValue(width) and math_max(8, width * 0.6) or 8

            local minMax = btn:CreateTexture(nil, 'OVERLAY')
            minMax:SetPoint('CENTER')
            minMax:SetSize(size, size)
            minMax:SetTexture(ARROW_TEXTURE)
            minMax:NUISetPixelSnap()
            minMax:SetVertexColor(0.9, 0.9, 0.9)

            if buttonDirection == 'expand' then
                minMax:SetRotation(math_rad(0))
            elseif buttonDirection == 'collapse' then
                minMax:SetRotation(math_rad(180))
            end

            ---@cast btn Button & SkinnedMinMaxButtonMixin
            Mixin(btn, SkinnedMinMaxButtonMixin)

            btn.NUIBtnMinMax = minMax
            btn:HookScript('OnEnter', btn.NUIOnEnter)
            btn:HookScript('OnLeave', btn.NUIOnLeave)
        end
    end
end

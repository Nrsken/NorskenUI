---@class NorskenUI
local NRSKNUI = _G.NorskenUI
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local issecretvalue = issecretvalue
local max = math.max
local next = next

-- Expanding always adds content on the right, collapsing takes it back to the left
local BUTTON_DIRECTIONS = { MaximizeButton = 'right', MinimizeButton = 'left' }

---@param frame Frame?
function Skinning:HandleMinMaxButton(frame)
    if not frame or frame.NUISkinned then return end
    frame.NUISkinned = true

    for buttonName, direction in next, BUTTON_DIRECTIONS do
        local btn = frame[buttonName]
        if btn then
            if btn.SetNormalTexture then
                btn:SetNormalTexture(NRSKNUI.ClearTexture)
                btn:SetPushedTexture(NRSKNUI.ClearTexture)
                btn:SetDisabledTexture(NRSKNUI.ClearTexture)
                btn:SetHighlightTexture(NRSKNUI.ClearTexture)
            end
            btn:NCStripTextures()

            local point, relativeTo, relativePoint, x, y = btn:GetPoint()
            btn:NCSetPoint(point, relativeTo or btn:GetParent(), relativePoint or point, x or 0, y or 0)

            -- The buttons measure 0 until laid out, so size from the template-sized parent
            local width = frame:GetWidth()
            local size = not issecretvalue(width) and max(8, width * 0.8) or 8
            self:CreateArrowTexture(btn, direction, size, size, nil, nil, nil, nil, nil, 'edge')
        end
    end
end

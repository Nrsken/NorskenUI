---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local unpack = unpack

local QUESTION_MARK = 134400

---The trigger's texture, unless the style picks one by hand.
---@param layer CDMLayer
---@param texture number?
function CDM:SetIconTexture(layer, texture)
    local style = layer.owner.style
    if style and style.IconSource == 'manual' and style.ManualIcon then texture = style.ManualIcon end
    layer.Icon:SetTexture(texture or QUESTION_MARK)
end

---Crop the icon to its frame's shape, so a wide icon isn't stretched.
---@param texture Texture
---@param style table
local function ApplyTexCoords(texture, style)
    local margin = 0.25 * (style.Zoom or NRSKNUI.GlobalZoom)
    local left, right, top, bottom = margin, 1 - margin, margin, 1 - margin
    if style.KeepAspectRatio and style.Width ~= style.Height then
        local span = 1 - 2 * margin
        if style.Width > style.Height then
            local cut = span * (1 - style.Height / style.Width) / 2
            top, bottom = top + cut, bottom - cut
        else
            local cut = span * (1 - style.Width / style.Height) / 2
            left, right = left + cut, right - cut
        end
    end
    texture:SetTexCoord(left, right, top, bottom)
end
CDM.ApplyTexCoords = ApplyTexCoords

---The icon art and its cooldown swipe, from the style.
---@param layer CDMLayer
---@param style table
function CDM:StyleIconParts(layer, style)
    local icon = layer.Icon
    ApplyTexCoords(icon, style)
    icon:SetVertexColor(unpack(style.Color))
    icon:SetAlpha(1) -- an aura placeholder dims it

    local cooldown = layer.Cooldown
    cooldown:SetDrawSwipe(style.DrawSwipe)
    cooldown:SetDrawEdge(style.DrawEdge)
    cooldown:SetReverse(style.Reverse)
    cooldown:SetSwipeColor(unpack(style.SwipeColor))
    cooldown:SetHideCountdownNumbers(style.HideCountdown)
end

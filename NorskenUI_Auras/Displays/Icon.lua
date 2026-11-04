---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local unpack = unpack

local QUESTION_MARK = 134400

--[[
An icon layer's art, cropped to the icon's shape, and the cooldown frame's own countdown number.
]]

-- Icon --

---The trigger's texture, unless the style picks one by hand; a trigger with none falls back to the manual icon.
---@param layer CDMLayer
---@param texture (number|string)?
function CDM:SetIconTexture(layer, texture)
    local style = layer.owner.style
    if style and style.ManualIcon and (style.IconSource == 'manual' or not texture) then
        texture = style.ManualIcon
    end
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
    cooldown:SetHideCountdownNumbers(not self:ShowsTimerText(layer, style))
    self:StyleTimerText(cooldown, style)
end

---Whether a layer draws its icon: an icon display's unless Show Icon is off (older icons never saved it), a bar's only when it's on.
---@param layer CDMLayer
---@param style table
---@param display table?
---@return boolean
function CDM:ShowsIcon(layer, style, display)
    if layer.isText then return false end
    if display and display.type == 'icon' then
        return style.IconShow ~= false
    end
    -- an aura overlay on a bar is styled as an icon, not as the bar
    return not layer.isBar or style.IconShow == true
end

-- Timer Text --

---Whether this layer draws the Timer Text: the picked trigger's, or with Automatic every layer but an aura overlay.
---@param layer CDMLayer
---@param style table
---@return boolean
function CDM:ShowsTimerText(layer, style)
    if style.HideCountdown then return false end
    local pick = style.TimerText.Trigger
    if pick then return pick == layer.index end
    local display = layer.owner.id and self:Get(layer.owner.id)
    local trigger = display and display.Triggers[layer.index]
    return not (trigger and trigger.Type == 'auraoverlay')
end

---The cooldown frame's own number, styled as a text.
---@param cooldown Cooldown
---@param style table
function CDM:StyleTimerText(cooldown, style)
    local timer = style.TimerText
    local countdown = cooldown:GetCountdownFontString()
    countdown:SetFontStyle(timer, timer.FontSize, nil, nil, true)
    countdown:SetTextColor(unpack(timer.Color))
    countdown:SetFontJustify(timer.AnchorTo, cooldown, timer.XOffset, timer.YOffset, true)
end

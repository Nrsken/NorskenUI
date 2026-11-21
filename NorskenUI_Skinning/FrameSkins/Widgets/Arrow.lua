---@class NorskenUI
local NRSKNUI = _G.NorskenUI
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local math_rad = math.rad

local STEPPER_ARROW_SIZE = 20
local ARROW_ATLAS = 'CovenantSanctum-Renown-Arrow-Depressed'
local ARROW_TEXTURE = NRSKNUI.Media.GUITextures .. 'collapse.tga'
local EDGE_TEXTURE = NRSKNUI.Media.GUITextures .. 'arrow-to-line.png'

local ARROW_ROTATION = { left = 0, up = math_rad(-90), down = math_rad(90), right = math_rad(180), }
-- The texture points down where the atlas points left
local TEXTURE_ROTATION = { down = 0, up = math_rad(180), left = math_rad(-90), right = math_rad(90) }
local EDGE_ROTATION = { right = 0, left = math_rad(180), up = math_rad(90), down = math_rad(-90) }

---Every arrow color change runs through here, so hover can never light up a disabled button.
---@param button Button
local function UpdateArrowState(button)
    local arrow = button.NUIArrow
    if not arrow then return end

    if button.IsEnabled and not button:IsEnabled() then
        local dim = Skinning.db.General.DisabledColor[4]
        arrow:SetVertexColor(dim, dim, dim)
    elseif button.NUIHover then
        arrow:SetVertexColor(Skinning:GetAccentColor())
    else
        arrow:SetVertexColor(button.NUIColorR, button.NUIColorG, button.NUIColorB)
    end
end

---@param button Button
local function ArrowOnEnter(button)
    button.NUIHover = true
    UpdateArrowState(button)
end

---@param button Button
local function ArrowOnLeave(button)
    button.NUIHover = nil
    UpdateArrowState(button)
end

---Create the arrow texture and its NUISetArrowDirection setter, accented while open or hovered.
---@param button Button
---@param direction string 'left'|'right'|'up'|'down'
---@param sizeX number
---@param sizeY number
---@param point string? Defaults to CENTER on the button
---@param relativeTo Frame?
---@param relativePoint string?
---@param xOffset number?
---@param yOffset number?
---@param texture boolean|'edge'? true for the chevron, 'edge' for arrow-to-line, else the atlas
function Skinning:CreateArrowTexture(button, direction, sizeX, sizeY, point, relativeTo, relativePoint, xOffset, yOffset, texture)
    if button.NUIArrow then return end

    local arrow = button:CreateTexture(nil, 'ARTWORK')
    arrow:NCSetPoint(point or 'CENTER', relativeTo or button, relativePoint or 'CENTER', xOffset or 0, yOffset or 0)
    arrow:NCSetSize(sizeX, sizeY)
    if texture == 'edge' then
        arrow:SetTexture(EDGE_TEXTURE)
        button.NUIArrowRotation = EDGE_ROTATION
    elseif texture then
        arrow:SetTexture(ARROW_TEXTURE)
        button.NUIArrowRotation = TEXTURE_ROTATION
    else
        arrow:SetAtlas(ARROW_ATLAS)
        button.NUIArrowRotation = ARROW_ROTATION
    end
    arrow:NCDisablePixelSnap()
    arrow:SetDesaturated(true)

    button.NUIArrow = arrow
    button.NUIUpdateArrowState = UpdateArrowState

    function button:NUISetArrowDirection(dir, open)
        self.NUIArrow:SetRotation(self.NUIArrowRotation[dir] or 0)
        if open then
            self.NUIColorR, self.NUIColorG, self.NUIColorB = Skinning:GetAccentColor()
        else
            self.NUIColorR, self.NUIColorG, self.NUIColorB = 1, 1, 1
        end
        -- NUIHover, not IsMouseOver: closing the menu mid-hover must not slam the arrow back.
        self:NUIUpdateArrowState()
    end

    button:NUISetArrowDirection(direction)

    button:HookScript('OnEnter', ArrowOnEnter)
    button:HookScript('OnLeave', ArrowOnLeave)
end

---@param button Button
---@param direction string 'left'|'right'|'up'|'down'
function Skinning:HandleArrowButton(button, direction)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    local sizeX, sizeY = 14, 38
    button:NCStripTextures()
    self:CreateArrowTexture(button, direction, sizeX, sizeY)
end

---Tone down next/prev paging buttons to fit the dark look
---@param button Button
---@param direction string 'left'|'right'|'up'|'down'
function Skinning:HandleNextPrevButton(button, direction)
    if not button or button.NUISkinned then return end

    local size = math.min(button:GetWidth(), button:GetHeight()) * 0.7

    self:HandleButton(button)
    self:CreateArrowTexture(button, direction, size, size, nil, nil, nil, nil, nil, true)
end

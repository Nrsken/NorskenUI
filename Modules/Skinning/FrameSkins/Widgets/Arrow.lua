---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local math_rad = math.rad

local STEPPER_ARROW_SIZE = 20
local ARROW_ATLAS = 'CovenantSanctum-Renown-Arrow-Depressed'
local ARROW_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\collapse.tga'

local ARROW_ROTATION = { left = 0, up = math_rad(-90), down = math_rad(90), right = math_rad(180), }

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
---@param texture boolean? Whether to use texture instead of the atlas
function Skinning:CreateArrowTexture(button, direction, sizeX, sizeY, point, relativeTo, relativePoint, xOffset, yOffset, texture)
    if button.NUIArrow then return end

    local arrow = button:CreateTexture(nil, 'ARTWORK')
    arrow:NUISetPixelPoint(point or 'CENTER', relativeTo or button, relativePoint or 'CENTER', xOffset or 0, yOffset or 0)
    arrow:NUISetPixelSize(sizeX, sizeY)
    if texture then
        arrow:SetTexture(ARROW_TEXTURE)
    else
        arrow:SetAtlas(ARROW_ATLAS)
    end
    arrow:NUISetPixelSnap()
    arrow:SetDesaturated(true)

    button.NUIArrow = arrow
    button.NUIUpdateArrowState = UpdateArrowState

    function button:NUISetArrowDirection(dir, open)
        self.NUIArrow:SetRotation(ARROW_ROTATION[dir] or 0)
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
    button:NUIStripTextures()
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

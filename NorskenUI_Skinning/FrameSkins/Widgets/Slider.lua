---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local Mixin = Mixin
local CreateFrame = CreateFrame

local THUMB_THICKNESS = 10
local THUMB_LENGTH = 14
local SCROLLBAR_THUMB_LENGTH = 24
local GRIP_INSET = 2

---@class SkinnedSliderMixin
---@field NUIThumb Texture? The accent-colored grip drawn inside the invisible thumb texture
---@field NUIActive boolean? The thumb is being dragged
---@field NUIHover boolean? The cursor is over the slider
local SkinnedSliderMixin = {}

function SkinnedSliderMixin:NUIUpdateThumbColor()
    local thumb = self.NUIThumb
    if not thumb then return end

    if self.NUIActive or self.NUIHover then
        local r, g, b = Skinning:GetAccentColor()
        thumb:SetColorTexture(r, g, b, self.NUIActive and 0.9 or 0.6)
    else
        local panel = Skinning.db.General.PanelColor
        thumb:SetColorTexture(panel[1], panel[2], panel[3], panel[4])
    end
end

function SkinnedSliderMixin:NUIUpdateSkinColors()
    ---@cast self Slider & PublicBackdropMixin & SkinnedSliderMixin
    local general = Skinning.db.General
    local bg, border = general.WidgetBackgroundColor, general.WidgetBorderColor

    self:SetBackgroundColor(bg[1], bg[2], bg[3], bg[4])
    self:SetBorderColor(border[1], border[2], border[3], border[4])

    self:NUIUpdateThumbColor()
end

function SkinnedSliderMixin:NUIOnEnter()
    self.NUIHover = true
    self:NUIUpdateThumbColor()
end

function SkinnedSliderMixin:NUIOnLeave()
    self.NUIHover = nil
    self:NUIUpdateThumbColor()
end

function SkinnedSliderMixin:NUIOnMouseDown()
    self.NUIActive = true
    self:NUIUpdateThumbColor()
end

function SkinnedSliderMixin:NUIOnMouseUp()
    self.NUIActive = nil
    self:NUIUpdateThumbColor()
end

---Skin a Slider, flat track backdrop with an accent-colored thumb.
---@param slider Slider
---@param isScrollBar boolean? Take the scroll bar look instead of the value knob's
function Skinning:HandleSlider(slider, isScrollBar)
    if not slider or slider.NUISkinned then return end
    slider.NUISkinned = true

    -- The track art is a real Backdrop, not a region, so stripping regions misses it.
    if slider.SetBackdrop then slider:SetBackdrop(nil) end
    slider:NUIStripTextures()

    local vertical = slider:GetOrientation() == 'VERTICAL'
    local thumb = slider.GetThumbTexture and slider:GetThumbTexture()

    -- A bare track with the backdrop on the thumb, so a legacy bar reads as a trim one.
    if isScrollBar then
        if not thumb then return end

        thumb:SetSize(vertical and THUMB_THICKNESS or SCROLLBAR_THUMB_LENGTH,
            vertical and SCROLLBAR_THUMB_LENGTH or THUMB_THICKNESS)
        thumb:SetColorTexture(0, 0, 0, 0)

        local grip = CreateFrame('Frame', nil, slider)
        grip:SetPoint('TOPLEFT', thumb, 'TOPLEFT', 0, 0)
        grip:SetPoint('BOTTOMRIGHT', thumb, 'BOTTOMRIGHT', 0, 0)

        self:HandleScrollThumb(grip, slider)
        return
    end

    slider:NUICreateBackdrop(false)

    if thumb then
        thumb:SetSize(vertical and THUMB_THICKNESS or THUMB_LENGTH, vertical and THUMB_LENGTH or THUMB_THICKNESS)
        thumb:SetColorTexture(0, 0, 0, 0)

        local insetX = vertical and 0 or GRIP_INSET
        local insetY = vertical and GRIP_INSET or 0

        local grip = slider:CreateTexture(nil, 'OVERLAY', nil, 1)
        grip:SetPoint('TOPLEFT', thumb, 'TOPLEFT', insetX, -insetY)
        grip:SetPoint('BOTTOMRIGHT', thumb, 'BOTTOMRIGHT', -insetX, insetY)
        grip:NUISetPixelSnap()
        slider.NUIThumb = grip
    end

    ---@cast slider Slider & PublicBackdropMixin & SkinnedSliderMixin
    Mixin(slider, SkinnedSliderMixin)

    slider:NUIUpdateSkinColors()

    slider:HookScript('OnEnter', slider.NUIOnEnter)
    slider:HookScript('OnLeave', slider.NUIOnLeave)
    slider:HookScript('OnMouseDown', slider.NUIOnMouseDown)
    slider:HookScript('OnMouseUp', slider.NUIOnMouseUp)

    self:RegisterSkinned(slider)
end

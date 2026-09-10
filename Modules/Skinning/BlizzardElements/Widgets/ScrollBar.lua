---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc
local Mixin = Mixin

local STEPPER_ARROW_SIZE = 16

local SkinnedThumbMixin = {}

function SkinnedThumbMixin:NUIUpdateThumbColor()
    if self.NUIActive then
        local r, g, b = Skinning:GetAccentColor()
        self.NUIBackdrop:SetBackgroundColor(r, g, b, 0.8)
    elseif self.NUIHover then
        local r, g, b = Skinning:GetAccentColor()
        self.NUIBackdrop:SetBackgroundColor(r, g, b, 0.5)
    else
        local bg = Skinning.db.General.PanelColor
        self.NUIBackdrop:SetBackgroundColor(bg[1], bg[2], bg[3], bg[4])
    end
end

function SkinnedThumbMixin:NUIUpdateSkinColors()
    self:NUIUpdateThumbColor()

    local border = Skinning.db.General.BorderColor
    self.NUIBackdrop:SetBorderColor(border[1], border[2], border[3], border[4])
end

function SkinnedThumbMixin:NUIOnEnter()
    self.NUIHover = true
    self:NUIUpdateThumbColor()
end

function SkinnedThumbMixin:NUIOnLeave()
    self.NUIHover = nil
    self:NUIUpdateThumbColor()
end

function SkinnedThumbMixin:NUIOnMouseDown()
    self.NUIActive = true
    self:NUIUpdateThumbColor()
end

function SkinnedThumbMixin:NUIOnMouseUp()
    self.NUIActive = nil
    self:NUIUpdateThumbColor()
end

---Blizzard drives the stepper through OnButtonStateChanged, which fires for hover, press,
---and the SetEnabled calls ScrollBarMixin:Update makes at either end of the track.
---@param S SkinningModule
---@param button Button?
---@param direction string 'up'|'down'|'left'|'right'
local function SkinStepper(S, button, direction)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    -- Alpha only, same as the thumb: OnButtonStateChanged keeps re-atlasing both of these.
    if button.Texture then button.Texture:SetAlpha(0) end
    if button.Overlay then button.Overlay:SetAlpha(0) end

    S:CreateArrowTexture(button, direction, STEPPER_ARROW_SIZE, STEPPER_ARROW_SIZE, nil, nil, nil, nil, nil, true)

    if button.OnButtonStateChanged then
        hooksecurefunc(button, 'OnButtonStateChanged', button.NUIUpdateArrowState)
    end
    button:NUIUpdateArrowState()
end

---Skin a modern WowTrimScrollBar/MinimalScrollBar
---@param scrollBar Frame
function Skinning:HandleTrimScrollBar(scrollBar)
    if not scrollBar or scrollBar.NUISkinned then return end
    scrollBar.NUISkinned = true

    scrollBar:NUIStripTextures()
    if scrollBar.Background then scrollBar.Background:NUIStripTextures() end
    if scrollBar.Track then scrollBar.Track:NUIStripTextures() end

    local back, forward = 'right', 'left'
    if scrollBar.isHorizontal then
        back, forward = 'down', 'up'
    end

    SkinStepper(self, scrollBar.Back, back)
    SkinStepper(self, scrollBar.Forward, forward)

    local thumb = scrollBar.GetThumb and scrollBar:GetThumb()
    if not thumb and scrollBar.Track then
        thumb = scrollBar.Track.Thumb
    end

    if thumb then
        -- Alpha only: the thumb re-reads its own atlases on state changes, so they must stay valid.
        thumb:NUIStripTextures('Alpha')
        self:CreatePanelBackdrop(thumb, nil, true)

        ---@cast thumb Frame & SkinnedThumbMixin
        Mixin(thumb, SkinnedThumbMixin)

        thumb:NUIUpdateThumbColor()

        thumb:HookScript('OnEnter', thumb.NUIOnEnter)
        thumb:HookScript('OnLeave', thumb.NUIOnLeave)
        thumb:HookScript('OnMouseDown', thumb.NUIOnMouseDown)
        thumb:HookScript('OnMouseUp', thumb.NUIOnMouseUp)

        self:RegisterSkinned(thumb)
    end
end

---Skin dynamically created ScrollBox children now and on every ScrollBox update.
---@param scrollBox ScrollBox|Frame
---@param skinChild fun(child: Frame)
function Skinning:HookScrollBoxChildren(scrollBox, skinChild)
    if not scrollBox or not scrollBox.ForEachFrame or scrollBox.NUIHooked then return end
    scrollBox.NUIHooked = true

    hooksecurefunc(scrollBox, 'Update', function(sb)
        sb:ForEachFrame(skinChild)
    end)

    scrollBox:ForEachFrame(skinChild)
end

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc
local Mixin = Mixin
local _G = _G

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

local function OnThumbEnter(host) host.NUIScrollThumb:NUIOnEnter() end
local function OnThumbLeave(host) host.NUIScrollThumb:NUIOnLeave() end
local function OnThumbMouseDown(host) host.NUIScrollThumb:NUIOnMouseDown() end
local function OnThumbMouseUp(host) host.NUIScrollThumb:NUIOnMouseUp() end

---Give a scroll thumb the bordered panel fill that takes the accent on hover and press.
---@param thumb Frame Carries the backdrop; a legacy bar pins one over its thumb texture
---@param host Frame? Frame that reports the mouse, defaults to the thumb
function Skinning:HandleScrollThumb(thumb, host)
    self:CreatePanelBackdrop(thumb, nil, true)

    ---@cast thumb Frame & SkinnedThumbMixin
    Mixin(thumb, SkinnedThumbMixin)
    thumb:NUIUpdateThumbColor()

    host = host or thumb
    host.NUIScrollThumb = thumb

    host:HookScript('OnEnter', OnThumbEnter)
    host:HookScript('OnLeave', OnThumbLeave)
    host:HookScript('OnMouseDown', OnThumbMouseDown)
    host:HookScript('OnMouseUp', OnThumbMouseUp)

    self:RegisterSkinned(thumb)
end

---Blizzard drives the stepper through OnButtonStateChanged, which fires for hover, press,
---and the SetEnabled calls ScrollBarMixin:Update makes at either end of the track.
---@param S SkinningModule
---@param button NUIArrowButton|Button|nil
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
---@param scrollBar NUIScrollBar|Frame
function Skinning:HandleTrimScrollBar(scrollBar)
    if not scrollBar or scrollBar.NUISkinned then return end
    scrollBar.NUISkinned = true

    scrollBar:NUIStripTextures()
    if scrollBar.Background then scrollBar.Background:NUIStripTextures() end
    if scrollBar.Track then scrollBar.Track:NUIStripTextures() end

    local back, forward = 'right', 'left'
    if scrollBar.isHorizontal then
        back, forward = 'up', 'down'
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
        self:HandleScrollThumb(thumb)
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

---Blizzard's legacy stepper has no state callback, so Enable/Disable drive the arrow directly.
---@param S SkinningModule
---@param button Button?
---@param direction string 'up'|'down'
local function SkinLegacyStepper(S, button, direction)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    button:SetNormalTexture(NRSKNUI.ClearTexture)
    button:SetPushedTexture(NRSKNUI.ClearTexture)
    button:SetDisabledTexture(NRSKNUI.ClearTexture)
    button:SetHighlightTexture(NRSKNUI.ClearTexture)
    button:NUIStripTextures()

    S:CreateArrowTexture(button, direction, STEPPER_ARROW_SIZE, STEPPER_ARROW_SIZE, nil, nil, nil, nil, nil, true)

    ---@cast button NUIArrowButton
    hooksecurefunc(button, 'Enable', button.NUIUpdateArrowState)
    hooksecurefunc(button, 'Disable', button.NUIUpdateArrowState)
    hooksecurefunc(button, 'SetEnabled', button.NUIUpdateArrowState)
    button:NUIUpdateArrowState()
end

---Skin a legacy UIPanelScrollBarTemplate: a Slider with two stepper buttons.
---@param scrollBar NUILegacyScrollBar
function Skinning:HandleScrollBar(scrollBar)
    if not scrollBar or scrollBar.NUISkinned then return end

    local name = scrollBar.GetName and scrollBar:GetName()
    local up = scrollBar.ScrollUpButton or (name and _G[name .. 'ScrollUpButton'])
    local down = scrollBar.ScrollDownButton or (name and _G[name .. 'ScrollDownButton'])

    self:HandleSlider(scrollBar, true)

    SkinLegacyStepper(self, up, 'right')
    SkinLegacyStepper(self, down, 'left')
end

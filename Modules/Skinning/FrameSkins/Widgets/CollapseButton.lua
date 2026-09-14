---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local Mixin = Mixin
local strfind = string.find

local EXPAND_ATLAS = 'UI-QuestTrackerButton-Secondary-Expand'
local COLLAPSE_ATLAS = 'UI-QuestTrackerButton-Secondary-Collapse'
local HIGHTLIGHT_ATLAS = 'UI-QuestTrackerButton-Yellow-Highlight'

local PLUS_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\plus-sign.png'
local MINUS_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\minus-sign.png'
local PLUS_MINUS_SIZE = 14
local PLUS_MINUS_REST_ALPHA = 0.85
local PLUS_MINUS_HOVER_MULT = 1.25

---@class NUICollapseButtonMixin
local NUICollapseButtonMixin = {}

---@param collapsed boolean
function NUICollapseButtonMixin:NUIDoCollapse(collapsed)
    if collapsed then
        self.NUICollapseIcon:SetAtlas(EXPAND_ATLAS, true)
    else
        self.NUICollapseIcon:SetAtlas(COLLAPSE_ATLAS, true)
    end
end

---@param texture string?
function NUICollapseButtonMixin:NUIResetTexture(texture)
    if self.NUISettingTexture then return end
    self.NUISettingTexture = true
    self:SetNormalTexture(NRSKNUI.ClearTexture)

    if texture and texture ~= '' then
        if strfind(texture, 'Plus') or strfind(texture, '[Cc]losed') then
            self:NUIDoCollapse(true)
        elseif strfind(texture, 'Minus') or strfind(texture, '[Oo]pen') then
            self:NUIDoCollapse(false)
        end
    end
    self.NUISettingTexture = nil
end

---@param atlas string?
function NUICollapseButtonMixin:NUIResetAtlas(atlas)
    if self.NUISettingTexture then return end
    self.NUISettingTexture = true
    self:SetNormalTexture(NRSKNUI.ClearTexture)

    if atlas and atlas ~= '' then
        if strfind(atlas, 'Plus') or strfind(atlas, '[Cc]losed') or strfind(atlas, 'Expand') then
            self:NUIDoCollapse(true)
        elseif strfind(atlas, 'Minus') or strfind(atlas, '[Oo]pen') or strfind(atlas, 'Collapse') then
            self:NUIDoCollapse(false)
        end
    end
    self.NUISettingTexture = nil
end

function NUICollapseButtonMixin:NUIOnEnter()
    if self:IsEnabled() and self.NUICollapseHighlight then
        self.NUICollapseHighlight:Show()
    end
end

function NUICollapseButtonMixin:NUIOnLeave()
    if self.NUICollapseHighlight then
        self.NUICollapseHighlight:Hide()
    end
end

---@param button Button
---@param isAtlas boolean?
function Skinning:ReskinCollapse(button, isAtlas)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    ---@cast button Button & NUICollapseButtonMixin
    Mixin(button, NUICollapseButtonMixin)

    button:SetNormalTexture(NRSKNUI.ClearTexture)
    button:SetHighlightTexture(NRSKNUI.ClearTexture)
    button:SetPushedTexture(NRSKNUI.ClearTexture)

    local container = CreateFrame('Frame', nil, button)
    container:SetAllPoints(button)
    container:SetFrameLevel(button:GetFrameLevel() + 1)
    button.NUIContainer = container

    local texture = container:CreateTexture(nil, 'OVERLAY', nil, 6)
    texture:SetPoint('CENTER')
    texture:SetAtlas(COLLAPSE_ATLAS, true)
    button.NUICollapseIcon = texture

    local highlight = container:CreateTexture(nil, 'OVERLAY', nil, 7)
    highlight:SetPoint('CENTER')
    highlight:SetAtlas(HIGHTLIGHT_ATLAS, true)
    highlight:Hide()
    button.NUICollapseHighlight = highlight

    button:HookScript('OnEnter', button.NUIOnEnter)
    button:HookScript('OnLeave', button.NUIOnLeave)

    if isAtlas then
        hooksecurefunc(button, 'SetNormalAtlas', button.NUIResetAtlas)
    else
        hooksecurefunc(button, 'SetNormalTexture', button.NUIResetTexture)
    end
end

---@param button Button & NUIPlusMinusButtonMixin
local function ClearPlusMinusArt(button)
    if button.NUIClearingArt then return end
    button.NUIClearingArt = true

    button:SetNormalTexture(NRSKNUI.ClearTexture)
    button:SetPushedTexture(NRSKNUI.ClearTexture)

    button.NUIClearingArt = nil
end

---@class NUIPlusMinusButtonMixin
---@field NUIPlusMinusIcon Texture
---@field NUIHover boolean?
---@field NUIPressed boolean?
---@field NUIClearingArt boolean?
local NUIPlusMinusButtonMixin = {}

function NUIPlusMinusButtonMixin:NUIUpdateSkinColors()
    ---@cast self Button & NUIPlusMinusButtonMixin
    local glyph = self.NUIPlusMinusIcon

    if self.NUIPressed then
        glyph:SetVertexColor(1, 1, 1, 1)
        return
    end

    local r, g, b = Skinning:GetAccentColor()
    if self.NUIHover then
        glyph:SetVertexColor(r * PLUS_MINUS_HOVER_MULT, g * PLUS_MINUS_HOVER_MULT, b * PLUS_MINUS_HOVER_MULT, 1)
    else
        glyph:SetVertexColor(r, g, b, PLUS_MINUS_REST_ALPHA)
    end
end

---@param collapsed boolean
function NUIPlusMinusButtonMixin:NUISetCollapsed(collapsed)
    ---@cast self Button & NUIPlusMinusButtonMixin
    -- Templates whose refresh re-atlases GetNormalTexture() directly never touch the setters, so the
    -- art is cleared on every state change as well rather than only when a setter is called.
    ClearPlusMinusArt(self)

    self.NUIPlusMinusIcon:SetTexture(collapsed and PLUS_TEXTURE or MINUS_TEXTURE)
end

function NUIPlusMinusButtonMixin:NUIOnEnter()
    ---@cast self Button & NUIPlusMinusButtonMixin
    self.NUIHover = true
    self:NUIUpdateSkinColors()
end

function NUIPlusMinusButtonMixin:NUIOnLeave()
    ---@cast self Button & NUIPlusMinusButtonMixin
    self.NUIHover = nil
    -- Releasing off the button never sends OnMouseUp, so the press has to end with the hover.
    self.NUIPressed = nil
    self:NUIUpdateSkinColors()
end

function NUIPlusMinusButtonMixin:NUIOnMouseDown()
    ---@cast self Button & NUIPlusMinusButtonMixin
    self.NUIPressed = true
    self:NUIUpdateSkinColors()
end

function NUIPlusMinusButtonMixin:NUIOnMouseUp()
    ---@cast self Button & NUIPlusMinusButtonMixin
    self.NUIPressed = nil
    self:NUIUpdateSkinColors()
end

---@class NUIPlusMinusGlyphMixin
local NUIPlusMinusGlyphMixin = {}

function NUIPlusMinusGlyphMixin:NUIUpdateSkinColors()
    ---@cast self Texture
    local r, g, b = Skinning:GetAccentColor()
    self:SetVertexColor(r, g, b, PLUS_MINUS_REST_ALPHA)
end

---The same glyph for headers that mark their state with a plain texture instead of a button, so
---there is no hover or pressed state to track. Call it again to flip the glyph.
---@param texture Texture?
---@param collapsed boolean
---@param size number? Glyph size, defaults to 14
function Skinning:SetPlusMinusGlyph(texture, collapsed, size)
    if not texture then return end

    texture:SetTexture(collapsed and PLUS_TEXTURE or MINUS_TEXTURE)
    texture:NUISetPixelSize(size or PLUS_MINUS_SIZE, size or PLUS_MINUS_SIZE)

    if not texture.NUISkinned then
        texture.NUISkinned = true

        ---@cast texture Texture & NUIPlusMinusGlyphMixin
        Mixin(texture, NUIPlusMinusGlyphMixin)
        self:RegisterSkinned(texture)
    end

    ---@cast texture Texture & NUIPlusMinusGlyphMixin
    texture:NUIUpdateSkinColors()
end

---Plus/minus toggle: accent glyph, brighter on hover, white while pressed. Drive the state
---with button:NUISetCollapsed(collapsed).
---@param button Button
---@param size number? Glyph size, defaults to 14
function Skinning:ReskinPlusMinus(button, size)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    ---@cast button Button & NUIPlusMinusButtonMixin
    Mixin(button, NUIPlusMinusButtonMixin)

    button:SetHighlightTexture(NRSKNUI.ClearTexture)
    ClearPlusMinusArt(button)

    local glyph = button:CreateTexture(nil, 'ARTWORK')
    glyph:NUISetPixelPoint('CENTER', button, 'CENTER', 0, 0)
    glyph:NUISetPixelSize(size or PLUS_MINUS_SIZE, size or PLUS_MINUS_SIZE)
    glyph:NUISetPixelSnap()
    button.NUIPlusMinusIcon = glyph

    -- Templates that re-apply their own art on every show would otherwise draw over this.
    hooksecurefunc(button, 'SetNormalTexture', ClearPlusMinusArt)
    hooksecurefunc(button, 'SetPushedTexture', ClearPlusMinusArt)

    button:HookScript('OnEnter', button.NUIOnEnter)
    button:HookScript('OnLeave', button.NUIOnLeave)
    button:HookScript('OnMouseDown', button.NUIOnMouseDown)
    button:HookScript('OnMouseUp', button.NUIOnMouseUp)

    button:NUISetCollapsed(true)
    button:NUIUpdateSkinColors()

    self:RegisterSkinned(button)
end

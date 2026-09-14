---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local Mixin = Mixin

local SkinnedButtonMixin = {}
Skinning.ButtonMixin = SkinnedButtonMixin
SkinnedButtonMixin.NUITextR, SkinnedButtonMixin.NUITextG, SkinnedButtonMixin.NUITextB = 1, 1, 1

---Explicit SetTextColor overrides the font object in every state, so the mixin owns the disabled/hover look.
---@param hovered boolean?
function SkinnedButtonMixin:NUIUpdateState(hovered)
    -- NUIIgnoreDisabled is for templates that disable themselves to stay inert, a static column
    -- header being the usual one. Dimming those would read as a button the player can't press.
    local disabled = not self.NUIIgnoreDisabled and self.IsEnabled and not self:IsEnabled()
    local dim = Skinning.db.General.DisabledColor[4]
    if self.NUIBackdrop then
        self.NUIBackdrop:SetAlpha(disabled and dim or 1)
    end

    -- A stripped icon stays at alpha 0 so Blizzard can't drive it back in.
    if self.Icon and self.Icon.NUINoStrip then
        self.Icon:SetAlpha(disabled and dim or 1)
    end

    if self.NUIUpdateArrowState then self:NUIUpdateArrowState() end

    local text = self.Text or (self.GetFontString and self:GetFontString())
    if not text then return end

    if disabled then
        text:SetTextColor(dim, dim, dim)
    elseif hovered then
        local r, g, b = Skinning:GetAccentColor()
        text:SetTextColor(r, g, b)
    else
        text:SetTextColor(self.NUITextR, self.NUITextG, self.NUITextB)
    end
end

---Resting label color, for buttons whose text carries meaning. Hover and disabled are unchanged.
---@param r number
---@param g number
---@param b number
function SkinnedButtonMixin:NUISetTextColor(r, g, b)
    self.NUITextR, self.NUITextG, self.NUITextB = r, g, b
    self:NUIUpdateState()
end

---Resting state only, a hovered button repaints on the next OnEnter.
function SkinnedButtonMixin:NUIUpdateSkinColors()
    Skinning:UpdateHighlightColor(self)
    self:NUIUpdateState()
end

function SkinnedButtonMixin:NUIOnEnter()
    if self.IsEnabled and not self:IsEnabled() then return end
    self:NUIUpdateState(true)
end

function SkinnedButtonMixin:NUIOnLeave()
    self:NUIUpdateState()
end

---Wrapper so SetEnabled's boolean argument isn't mistaken for the hovered flag
---@param button Button & SkinnedButtonMixin
local function UpdateButtonState(button)
    button:NUIUpdateState()
end

---Skin a text button (UIPanelButtonTemplate style). Strips button art, keeps the text.
---@param button Button
---@param template string? 'Transparent' pins the background alpha at 0.5
---@param skipRegister boolean? Skip recolor registration (caller owns coloring)
---@param keepIcon boolean? Spare button.Icon from the strip, leaving Blizzard's art and anchors intact
---@param ignoreDisabled boolean? Keep the resting look even while the button is disabled
function Skinning:HandleButton(button, template, skipRegister, keepIcon, ignoreDisabled)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true
    button.NUIIgnoreDisabled = ignoreDisabled

    if keepIcon and button.Icon then
        button.Icon.NUINoStrip = true
    end

    if button.SetNormalTexture then
        button:SetNormalTexture(NRSKNUI.ClearTexture)
        button:SetPushedTexture(NRSKNUI.ClearTexture)
        button:SetDisabledTexture(NRSKNUI.ClearTexture)
        button:SetHighlightTexture(NRSKNUI.ClearTexture)
    end

    button:NUIStripTextures('ClearHide')

    local backdrop = self:CreatePanelBackdrop(button, template, skipRegister, true)

    if backdrop then
        for _, region in ipairs({ button:GetRegions() }) do
            if region:IsObjectType('FontString') then
                -- Templates that anchor their label off an edge keep fighting a bare CENTER.
                region:ClearAllPoints()
                region:SetPoint('CENTER', backdrop, 'CENTER', 0, 0)
            end
        end
    end

    self:AddHighlight(button)

    ---@cast button Button & SkinnedButtonMixin
    Mixin(button, SkinnedButtonMixin)

    button:HookScript('OnEnter', button.NUIOnEnter)
    button:HookScript('OnLeave', button.NUIOnLeave)

    hooksecurefunc(button, 'Enable', UpdateButtonState)
    hooksecurefunc(button, 'Disable', UpdateButtonState)
    hooksecurefunc(button, 'SetEnabled', UpdateButtonState)

    button:NUIUpdateState()

    if not skipRegister then
        self:RegisterSkinned(button)
    end
end

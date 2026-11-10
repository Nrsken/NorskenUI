---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
local Pixel = NRSKNUI.Pixel

local UIParent = UIParent

-- NorskenUI owns UIParent's scale once the user turns it on, unless another UI addon already does

NRSKNUI.TenEigthyPixel = 768 / 1080 -- the 1080p preset
NRSKNUI.FourteenFortyPixel = 768 / 1440 -- the 1440p preset
NRSKNUI.InverseScale = 1 / UIParent:GetEffectiveScale() -- the cursor ring reads it every frame

---Set a scale or the pixel perfect one for this screen when none is given.
---@param custom number|nil
function NRSKNUI:SetScaleValue(custom)
    self.db.profile.UIScale.Scale = custom or Pixel.GetBestPixelSize()
    self:SetUIScale()
end

function NRSKNUI:SetUIScale()
    if self.db.profile.UIScale.Enabled and not self:GetConflictingScaleAddon() then
        UIParent:SetScale(self.db.profile.UIScale.Scale)
        self:UpdateInverseScale()
    end
end

function NRSKNUI:UpdateInverseScale()
    self.InverseScale = 1 / UIParent:GetEffectiveScale()
end

function NRSKNUI:UI_SCALE_CHANGED()
    self:UpdateInverseScale()
    self:SetUIScale()
end

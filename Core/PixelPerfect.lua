---@class NRSKNUI
local NRSKNUI = select(2, ...)
local Pixel = NRSKNUI.Libs.KAJI.Pixel

local GetPhysicalScreenSize = GetPhysicalScreenSize
local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight
local format = format

local UIParent = UIParent

NRSKNUI.PhysW, NRSKNUI.PhysH = GetPhysicalScreenSize()                 -- Get the physical screen size of the user's display.
NRSKNUI.ScreenW, NRSKNUI.ScreenH = GetScreenWidth(), GetScreenHeight() -- Get the current screen width and height of the game window.
NRSKNUI.Res = format('%dx%d', NRSKNUI.PhysW, NRSKNUI.PhysH)            -- Format the physical screen size into a resolution string, e.g. "1920x1080".
NRSKNUI.PerfectPixel = 768 / NRSKNUI.PhysH                             -- Auto scale factor
NRSKNUI.InverseScale = 1 / UIParent:GetEffectiveScale()                -- Refreshed by SetUIScale
NRSKNUI.TenEigthyPixel = 768 / 1080                                    -- Scale factor for 1080p resolution
NRSKNUI.FourteenFortyPixel = 768 / 1440                                -- Scale factor for 1440p resolution

---Sets either pixel perfect scale or a custom scale value.
---@param custom number|nil
function NRSKNUI:SetScaleValue(custom)
    if not custom then
        self.db.profile.UIScale.Scale = self:GetBestPixelSize()
    else
        self.db.profile.UIScale.Scale = custom
    end
    self:SetUIScale()
end

---Returns the best pixel size for the current resolution. See LibKaji Pixel.lua for the math.
---@return number
function NRSKNUI:GetBestPixelSize()
    return Pixel.GetBestPixelSize()
end

---Updates the multiplier for scaling UI elements based on the current resolution and perfect pixel size.
function NRSKNUI:UpdateMult()
    self.Mult = Pixel.GetMult()
end

---Sets the UI scale based on the user's settings.
function NRSKNUI:SetUIScale()
    if self.db.profile.UIScale.Enabled and not self:GetConflictingScaleAddon() then
        UIParent:SetScale(self.db.profile.UIScale.Scale)
    end
end

---Updates the physical and screen dimensions, as well as the perfect pixel size.
function NRSKNUI:UpdateValues()
    self.PhysW, self.PhysH = GetPhysicalScreenSize()
    self.ScreenW, self.ScreenH = GetScreenWidth(), GetScreenHeight()
    self.Res = format('%dx%d', self.PhysW, self.PhysH)
    self.PerfectPixel = 768 / self.PhysH
    self.InverseScale = 1 / UIParent:GetEffectiveScale()
end

---Handles the UI scale change event, updating values and setting the UI scale accordingly.
function NRSKNUI:ChangedScaleEvent(event)
    if event == "UI_SCALE_CHANGED" then
        self:UpdateValues()
    end

    self:UpdateMult()
    self:SetUIScale()
end

---@class NRSKNUI
local NRSKNUI = select(2, ...)

local GetPhysicalScreenSize = GetPhysicalScreenSize
local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight
local format = format

local UIParent = UIParent

NRSKNUI.PhysW, NRSKNUI.PhysH = GetPhysicalScreenSize()                 -- Get the physical screen size of the user's display.
NRSKNUI.ScreenW, NRSKNUI.ScreenH = GetScreenWidth(), GetScreenHeight() -- Get the current screen width and height of the game window.
NRSKNUI.Res = format('%dx%d', NRSKNUI.PhysW, NRSKNUI.PhysH)            -- Format the physical screen size into a resolution string, e.g. "1920x1080".
NRSKNUI.PerfectPixel = 768 / NRSKNUI.PhysH                             -- Auto scale factor
NRSKNUI.TenEigthyPixel = 768 / 1080                                    -- Scale factor for 1080p resolution
NRSKNUI.FourteenFortyPixel = 768 / 1440                                -- Scale factor for 1440p resolution

---Sets either pixel perfect scale or a custom scale value.
---@param custom number|nil
function NRSKNUI:SetScaleValue(custom)
    if not custom then
        self.db.global.UIScale.Scale = self:GetBestPixelSize()
    else
        self.db.global.UIScale.Scale = custom
    end
    self:SetUIScale()
end

---Returns the best pixel size for the current resolution.
---@return number
function NRSKNUI:GetBestPixelSize()
    if self.PerfectPixel > 1.15 then
        return 1.15
    elseif self.PerfectPixel < 0.4 then
        return 0.4
    end
    return self.PerfectPixel
end

---Updates the multiplier for scaling UI elements based on the current resolution and perfect pixel size.
function NRSKNUI:UpdateMult()
    self.Mult = self.PerfectPixel / self:GetBestPixelSize()
end

---Sets the UI scale based on the user's settings.
function NRSKNUI:SetUIScale()
    if not self.db.global.UIScale.Enabled then return end

    UIParent:SetScale(self.db.global.UIScale.Scale)
end

---Updates the physical and screen dimensions, as well as the perfect pixel size.
function NRSKNUI:UpdateValues()
    self.PhysW, self.PhysH = GetPhysicalScreenSize()
    self.ScreenW, self.ScreenH = GetScreenWidth(), GetScreenHeight()
    self.Res = format('%dx%d', self.PhysW, self.PhysH)
    self.PerfectPixel = 768 / self.PhysH
end

---Handles the UI scale change event, updating values and setting the UI scale accordingly.
function NRSKNUI:ChangedScaleEvent(event)
    if event == "UI_SCALE_CHANGED" then
        self:UpdateValues()
    end

    self:UpdateMult()
    self:SetUIScale()
end

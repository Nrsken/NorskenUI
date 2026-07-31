---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
---@field Elements UnitFramesElements
local UF = NRSKNUI:GetModule('UnitFrames')

local CreateFrame = CreateFrame

local Interpolation = Enum and Enum.StatusBarInterpolation

---@class UnitFramesElements
---@field Power UnitFramesPowerElement
UF.Elements = UF.Elements or {}

---@class UnitFramesPowerElement
UF.Elements.Power = {
    ---@param self oUF.UnitFrame
    ---@param unit string
    Construct = function(self, unit)
        if self.Power then return end

        -- Power bar background frame
        local powerBackground = CreateFrame('Frame', nil, self)
        powerBackground:CreateBackdrop(true)
        self.powerBackground = powerBackground

        -- Power bar border frame
        local powerBorderFrame = CreateFrame('Frame', nil, self)
        powerBorderFrame:AddBorders()
        powerBorderFrame:SetFrameLevel(self:GetFrameLevel() + 3)
        self.powerBorderFrame = powerBorderFrame

        -- Power bar
        local powerBar = CreateFrame('StatusBar', nil, self) --[[@as oUF.Power]]
        powerBar:SetFrameLevel(self:GetFrameLevel() + 2)
        powerBar:SetPixelSnap()
        powerBar.PostUpdate = UF.PostUpdatePower
        powerBar.PostUpdateColor = UF.PostUpdatePowerColor

        self.Power = powerBar
    end,

    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table
    Configure = function(self, unit, uDB, general)
        local powerBar = self.Power
        if not powerBar then return end
        local powerBackground = self.powerBackground
        local powerBorderFrame = self.powerBorderFrame

        local pDB = uDB.Power

        -- Set power bar texture and sizing
        powerBar:SetStatusBarTexture(NRSKNUI:GetStatusbar(general, pDB.StatusBarTexture))
        powerBar:ClearAllPoints()
        powerBar:SetPixelPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', 0, -pDB.Height - 1)
        powerBar:SetPixelPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', 0, -pDB.Height - 1)
        powerBar:SetPixelHeight(pDB.Height)

        -- Set background and border frame sizing
        powerBackground:ClearAllPoints()
        powerBackground:SetAllPoints(powerBar)
        powerBorderFrame:ClearAllPoints()
        powerBorderFrame:SetAllPoints(powerBar)

        --TODO: Keep looking for a better solution to the inital empty -> fill slide in effect.
        -- Only smoothing for the player's power bar.
        local smooth = pDB.UseGlobalSmooth and general.Smooth or (not pDB.UseGlobalSmooth and pDB.Smooth)
        powerBar.nuiSmoothing = ((smooth and unit == 'player') and Interpolation.ExponentialEaseOut) or Interpolation.Immediate
        powerBar.smoothing = Interpolation.Immediate

        -- Power type colouring, or a flat colour that PostUpdatePowerColor re-applies over oUF's pick.
        local colorByPower, color
        if pDB.UseGlobalColors then
            colorByPower = general.ColorByPower
            color = general.Colors.Power
        else
            colorByPower = pDB.ColorByPower
            color = pDB.Color
        end

        powerBar.colorPower = colorByPower
        powerBar.colorClass = false
        powerBar.colorReaction = false
        powerBar.nuiColor = color
        powerBar.nuiColorByPower = colorByPower
    end,
}

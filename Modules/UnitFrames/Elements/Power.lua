---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFrames
local UF = NRSKNUI:GetModule('UnitFrames')

local CreateFrame = CreateFrame

local Interpolation = Enum.StatusBarInterpolation

UF.Elements = UF.Elements or {}
UF.Elements.Power = {
    Construct = function(frame, unit)
        if frame.Power then return end

        -- Power bar background frame
        local powerBackground = CreateFrame('Frame', nil, frame)
        powerBackground:CreateBackdrop(true)
        frame.powerBackground = powerBackground

        -- Power bar border frame
        local powerBorderFrame = CreateFrame('Frame', nil, frame)
        powerBorderFrame:AddBorders()
        powerBorderFrame:SetFrameLevel(frame:GetFrameLevel() + 3)
        frame.powerBorderFrame = powerBorderFrame

        -- Power bar
        local powerBar = CreateFrame('StatusBar', nil, frame)
        powerBar:SetFrameLevel(frame:GetFrameLevel() + 2)
        powerBar:SetPixelSnap()
        powerBar.PostUpdate = UF.PostUpdatePower

        frame.Power = powerBar
    end,

    Configure = function(frame, unit, uDB, general)
        local powerBar = frame.Power
        if not powerBar then return end
        local powerBackground = frame.powerBackground
        local powerBorderFrame = frame.powerBorderFrame

        local pDB = uDB.Power

        -- Set power bar texture and sizing
        powerBar:SetStatusBarTexture(NRSKNUI:GetBarTexture(general, pDB.StatusBarTexture))
        powerBar:ClearAllPoints()
        powerBar:SetPixelPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 0, -pDB.Height - 1)
        powerBar:SetPixelPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', 0, -pDB.Height - 1)
        powerBar:SetPixelHeight(pDB.Height)

        -- Set background and border frame sizing
        powerBackground:ClearAllPoints()
        powerBackground:SetAllPoints(powerBar)
        powerBorderFrame:ClearAllPoints()
        powerBorderFrame:SetAllPoints(powerBar)

        --TODO: Keep looking for a better solution to the inital empty -> fill slide in effect.
        -- Only smoothing for the player's power bar.
        powerBar.nuiSmoothing = ((general.Smooth and pDB.Smooth and unit == 'player') and Interpolation.ExponentialEaseOut) or Interpolation.Immediate
        powerBar.smoothing = Interpolation.Immediate
        powerBar.colorPower = pDB.ColorByPower
    end,
}

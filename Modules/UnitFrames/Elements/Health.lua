---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFrames
local UF = NRSKNUI:GetModule('UnitFrames')

local CreateFrame = CreateFrame

local Interpolation = Enum.StatusBarInterpolation

UF.Elements = UF.Elements or {}
UF.Elements.Health = {
    Construct = function(frame, unit)
        if frame.Health then return end

        -- Setup tooltip handlers for the frame.
        frame:SetScript('OnEnter', function(self) UF:ShowTooltip(self.unit) end)
        frame:SetScript('OnLeave', function(self) UF:HideTooltip() end)

        -- Backgroundbar
        local healthBackground = CreateFrame('StatusBar', nil, frame)
        healthBackground:SetFrameLevel(frame:GetFrameLevel() + 1)
        healthBackground:SetReverseFill(true)
        healthBackground:SetPixelSnap()

        -- Health bar
        local healthBar = CreateFrame('StatusBar', nil, frame)
        healthBar:SetFrameLevel(frame:GetFrameLevel() + 2)
        healthBar:SetPixelSnap()
        healthBar.healthBackground = healthBackground
        healthBar.PostUpdate = UF.PostUpdateHealth
        healthBar.PostUpdateColor = UF.PostUpdateHealthColor

        -- Border frame
        local healthBorderFrame = CreateFrame('Frame', nil, frame)
        healthBorderFrame:SetFrameLevel(frame:GetFrameLevel() + 3)
        healthBorderFrame:AddBorders()
        frame.healthBorderFrame = healthBorderFrame

        local RaidIcon = healthBorderFrame:CreateTexture(nil, 'OVERLAY', nil, 1) -- Higher than border textures.
        RaidIcon:SetPoint('CENTER', healthBar, 'TOP')
        RaidIcon:SetSize(24, 24)
        frame.RaidTargetIndicator = RaidIcon

        frame.Health = healthBar
    end,

    Configure = function(frame, unit, uDB, general)
        local healthBar = frame.Health
        local healthBorderFrame = frame.healthBorderFrame
        local healthBackground = healthBar.healthBackground
        local hDB = uDB.Health

        -- Set the texture for both the foreground and background bars.
        local texture = NRSKNUI:GetBarTexture(general, hDB.StatusBarTexture)
        healthBar:SetStatusBarTexture(texture)
        healthBackground:SetStatusBarTexture(texture)

        -- Set sizing
        healthBar:SetAllPoints(frame)
        healthBackground:SetAllPoints(frame)
        healthBorderFrame:SetAllPoints(frame)

        -- Prime to Immediate, postUpdate switches to the steady mode after the first paint.
        healthBar.nuiSmoothing = (general.Smooth and hDB.Smooth) and Interpolation.ExponentialEaseOut or Interpolation.Immediate
        healthBar.smoothing = Interpolation.Immediate

        -- Background always fills opposite the foreground so the two meet in the middle.
        healthBar:SetReverseFill(hDB.Inverse or false)
        healthBackground:SetReverseFill(not (hDB.Inverse or false))

        -- oUF flags pick the hue, PostUpdateHealthColor enforces the alpha.
        healthBar.nuiForeground = hDB.Foreground
        healthBar.nuiColorByClass = hDB.ColorByClass
        healthBar.colorClass = hDB.ColorByClass
        healthBar.colorReaction = hDB.ColorByClass
        healthBar.colorHealth = false

        healthBackground:SetStatusBarColor(hDB.Background[1], hDB.Background[2], hDB.Background[3], hDB.Background[4])

        healthBar.nuiBackground = hDB.Background
    end,
}

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
        healthBar:SetClipsChildren(true) -- Keep over-absorb overflow inside the bar.
        healthBar.healthBackground = healthBackground
        healthBar.PostUpdate = UF.PostUpdateHealth
        healthBar.PostUpdateColor = UF.PostUpdateHealthColor

        -- Heal absorb bar
        local HealAbsorb = CreateFrame('StatusBar', nil, healthBar)
        HealAbsorb:SetFrameLevel(healthBar:GetFrameLevel() + 1)
        HealAbsorb:SetPixelSnap()
        HealAbsorb:SetPixelWidth(frame:GetWidth())
        healthBar.HealAbsorb = HealAbsorb

        -- Damage absorb bar
        local DamageAbsorb = CreateFrame('StatusBar', nil, healthBar)
        DamageAbsorb:SetFrameLevel(healthBar:GetFrameLevel() + 1)
        DamageAbsorb:SetPixelSnap()
        DamageAbsorb:SetPixelWidth(frame:GetWidth())
        healthBar.DamageAbsorb = DamageAbsorb

        -- Over-absorb bar clip frame.
        local OverDamageAbsorbClip = CreateFrame('Frame', nil, healthBar)
        OverDamageAbsorbClip:SetFrameLevel(healthBar:GetFrameLevel() + 1)
        OverDamageAbsorbClip:SetClipsChildren(true)
        healthBar.OverDamageAbsorbClip = OverDamageAbsorbClip

        -- Over-absorb bar.
        local OverDamageAbsorb = CreateFrame('StatusBar', nil, OverDamageAbsorbClip)
        OverDamageAbsorb:SetFrameLevel(healthBar:GetFrameLevel() + 1)
        OverDamageAbsorb:SetPixelSnap()
        OverDamageAbsorb:SetPixelWidth(frame:GetWidth())

        healthBar.OverDamageAbsorb = OverDamageAbsorb
        healthBar.damageAbsorbClampMode = 2
        healthBar.healAbsorbClampMode = 1
        healthBar.healAbsorbMode = 1

        -- Border frame
        local healthBorderFrame = CreateFrame('Frame', nil, frame)
        healthBorderFrame:SetFrameLevel(frame:GetFrameLevel() + 4)
        healthBorderFrame:AddBorders()
        frame.healthBorderFrame = healthBorderFrame

        -- RaidIcon
        local RaidIcon = healthBorderFrame:CreateTexture(nil, 'OVERLAY', nil, 1) -- Higher than border textures.
        frame.RaidTargetIndicator = RaidIcon

        -- Leader indicator
        local LeaderIndicator = frame:CreateTexture(nil, 'OVERLAY', nil, 1)
        frame.LeaderIndicator = LeaderIndicator

        frame.Health = healthBar
    end,

    Configure = function(frame, unit, uDB, general)
        local healthBar = frame.Health
        local healthBorderFrame = frame.healthBorderFrame
        local healthBackground = healthBar.healthBackground
        local RaidIcon = frame.RaidTargetIndicator
        local LeaderIndicator = frame.LeaderIndicator
        local hDB = uDB.Health

        -- Position and size the raid icon.
        RaidIcon:SetPixelSize(uDB.RaidIcon.Size, uDB.RaidIcon.Size)
        RaidIcon:ClearAllPoints()
        RaidIcon:SetPixelPoint(uDB.RaidIcon.Position.AnchorFrom, frame, uDB.RaidIcon.Position.AnchorTo, uDB.RaidIcon.Position.XOffset, uDB.RaidIcon.Position.YOffset)

        -- Position and size the leader indicator.
        LeaderIndicator:SetPixelSize(uDB.LeaderIndicator.Size, uDB.LeaderIndicator.Size)
        LeaderIndicator:ClearAllPoints()
        LeaderIndicator:SetPixelPoint(uDB.LeaderIndicator.Position.AnchorFrom, frame, uDB.LeaderIndicator.Position.AnchorTo, uDB.LeaderIndicator.Position.XOffset, uDB.LeaderIndicator.Position.YOffset)

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

        -- Background coloring
        healthBackground:SetStatusBarColor(hDB.Background[1], hDB.Background[2], hDB.Background[3], hDB.Background[4])
        healthBar.nuiBackground = hDB.Background

        -- Absorb bars
        local HealAbsorb = healthBar.HealAbsorb
        local DamageAbsorb = healthBar.DamageAbsorb
        local OverDamageAbsorb = healthBar.OverDamageAbsorb
        local OverClip = healthBar.OverDamageAbsorbClip
        local fill = healthBar:GetStatusBarTexture()
        local inverse = hDB.Inverse or false
        local healColor = hDB.HealAbsorb.Color
        local dmgColor = hDB.DamageAbsorb.Color

        -- Each absorb resolves its own global-or-override texture, independent of the main bar toggle.
        local shield = NRSKNUI:GetBarTexture(hDB.DamageAbsorb)

        -- Heal absorb bar config
        HealAbsorb:SetStatusBarTexture(NRSKNUI:GetBarTexture(hDB.HealAbsorb))
        HealAbsorb:SetStatusBarColor(healColor[1], healColor[2], healColor[3], healColor[4])
        HealAbsorb:ClearAllPoints()
        HealAbsorb:SetPixelPoint('TOP')
        HealAbsorb:SetPixelPoint('BOTTOM')

        -- Damage absorb bar config
        DamageAbsorb:SetStatusBarTexture(shield)
        DamageAbsorb:SetStatusBarColor(dmgColor[1], dmgColor[2], dmgColor[3], dmgColor[4])
        DamageAbsorb:ClearAllPoints()
        DamageAbsorb:SetPixelPoint('TOP')
        DamageAbsorb:SetPixelPoint('BOTTOM')

        -- Over-absorb bar config
        OverDamageAbsorb:SetStatusBarTexture(shield)
        OverDamageAbsorb:SetStatusBarColor(dmgColor[1], dmgColor[2], dmgColor[3], dmgColor[4])
        OverDamageAbsorb:SetPixelWidth(frame:GetWidth())
        OverClip:ClearAllPoints()
        OverDamageAbsorb:ClearAllPoints()

        if inverse then
            -- Foreground fills right to left, so the current-health edge is on the left.
            HealAbsorb:SetPixelPoint('LEFT', fill)
            HealAbsorb:SetReverseFill(false)
            DamageAbsorb:SetPixelPoint('RIGHT', fill, 'LEFT')
            DamageAbsorb:SetReverseFill(true)

            OverClip:SetPixelPoint('TOPRIGHT', healthBar, 'TOPRIGHT')
            OverClip:SetPixelPoint('BOTTOMLEFT', fill, 'BOTTOMLEFT')
            OverDamageAbsorb:SetPixelPoint('TOPLEFT', healthBar, 'TOPLEFT')
            OverDamageAbsorb:SetPixelPoint('BOTTOMLEFT', healthBar, 'BOTTOMLEFT')
            OverDamageAbsorb:SetReverseFill(false)
        else
            -- Foreground fills left to right, so the current-health edge is on the right.
            HealAbsorb:SetPixelPoint('RIGHT', fill)
            HealAbsorb:SetReverseFill(true)
            DamageAbsorb:SetPixelPoint('LEFT', fill, 'RIGHT')
            DamageAbsorb:SetReverseFill(false)

            OverClip:SetPixelPoint('TOPLEFT', healthBar, 'TOPLEFT')
            OverClip:SetPixelPoint('BOTTOMRIGHT', fill, 'BOTTOMRIGHT')
            OverDamageAbsorb:SetPixelPoint('TOPRIGHT', healthBar, 'TOPRIGHT')
            OverDamageAbsorb:SetPixelPoint('BOTTOMRIGHT', healthBar, 'BOTTOMRIGHT')
            OverDamageAbsorb:SetReverseFill(true)
        end
    end,
}

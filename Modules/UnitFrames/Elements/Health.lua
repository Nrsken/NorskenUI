---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
---@field Elements UnitFramesElements
local UF = NRSKNUI:GetModule('UnitFrames')

local CreateFrame = CreateFrame

local Interpolation = Enum and Enum.StatusBarInterpolation

---@class UnitFramesElements
---@field Health UnitFramesHealthElement
UF.Elements = UF.Elements or {}

---@class UnitFramesHealthElement
UF.Elements.Health = {
    ---@param self oUF.UnitFrame
    ---@param unit string
    Construct = function(self, unit)
        if self.Health then return end

        -- Setup tooltip + highlight handlers for the frame.
        self:SetScript('OnEnter', function()
            if self.nuiHighlight.nuiEnabled then self.nuiHighlight:Show() end
            UF:ShowTooltip(self.unit)
        end)
        self:SetScript('OnLeave', function()
            self.nuiHighlight:Hide()
            UF:HideTooltip()
        end)

        -- Backgroundbar
        local healthBackground = CreateFrame('StatusBar', nil, self)
        healthBackground:SetFrameLevel(self:GetFrameLevel() + UF.BaseLevels.Background)
        healthBackground:SetReverseFill(true)
        healthBackground:NUISetPixelSnap()

        -- Health bar
        local healthBar = CreateFrame('StatusBar', nil, self) --[[@as oUF.Health]]
        healthBar:SetFrameLevel(self:GetFrameLevel() + UF.BaseLevels.Bar)
        healthBar:NUISetPixelSnap()
        healthBar:SetClipsChildren(true) -- Keep over-absorb overflow inside the bar.
        healthBar.healthBackground = healthBackground
        healthBar.PostUpdate = UF.PostUpdateHealth
        healthBar.PostUpdateColor = UF.PostUpdateHealthColor

        -- Heal absorb bar
        local HealAbsorb = CreateFrame('StatusBar', nil, healthBar)
        HealAbsorb:NUISetPixelSnap()
        HealAbsorb:NUISetPixelWidth(self:GetWidth())
        healthBar.HealAbsorb = HealAbsorb

        -- Damage absorb bar
        local DamageAbsorb = CreateFrame('StatusBar', nil, healthBar)
        DamageAbsorb:NUISetPixelSnap()
        DamageAbsorb:NUISetPixelWidth(self:GetWidth())
        healthBar.DamageAbsorb = DamageAbsorb

        -- Over-absorb bar clip frame.
        local OverDamageAbsorbClip = CreateFrame('Frame', nil, healthBar)
        OverDamageAbsorbClip:SetClipsChildren(true)
        healthBar.OverDamageAbsorbClip = OverDamageAbsorbClip

        -- Over-absorb bar.
        local OverDamageAbsorb = CreateFrame('StatusBar', nil, OverDamageAbsorbClip)
        OverDamageAbsorb:NUISetPixelSnap()
        OverDamageAbsorb:NUISetPixelWidth(self:GetWidth())

        healthBar.OverDamageAbsorb = OverDamageAbsorb
        healthBar.damageAbsorbClampMode = 2
        healthBar.healAbsorbClampMode = 1
        healthBar.healAbsorbMode = 1

        -- oUF skips an absorb whose field is nil, so disabling clears the field, these keep the bars reachable for configuration.
        healthBar.nuiHealAbsorb = HealAbsorb
        healthBar.nuiDamageAbsorb = DamageAbsorb

        -- Mouseover highlight
        local highlightFrame = CreateFrame('Frame', nil, self)
        highlightFrame:SetFrameLevel(UF.GetLayerLevel(self, UF.Layers.Highlight))
        self.nuiHighlightFrame = highlightFrame

        local highlight = highlightFrame:CreateTexture(nil, 'OVERLAY') --[[@as NUI.HighlightTexture]]
        highlight:SetBlendMode('ADD')
        highlight:Hide()
        self.nuiHighlight = highlight

        -- Border frame
        local healthBorderFrame = CreateFrame('Frame', nil, self)
        healthBorderFrame:SetFrameLevel(UF.GetLayerLevel(self, UF.Layers.Border))
        healthBorderFrame:NUIAddBorders()
        self.healthBorderFrame = healthBorderFrame

        -- RaidIcon
        local raidMarkFrame = CreateFrame('Frame', nil, self)
        raidMarkFrame:SetFrameLevel(UF.TopLevels.RaidMark)
        self.nuiRaidMarkFrame = raidMarkFrame

        local RaidIcon = raidMarkFrame:CreateTexture(nil, 'OVERLAY') --[[@as oUF.RaidTargetIndicator]]
        self.RaidTargetIndicator = RaidIcon

        -- Leader indicator
        local LeaderIndicator = self:CreateTexture(nil, 'OVERLAY', nil, 1) --[[@as oUF.LeaderIndicator]]
        self.LeaderIndicator = LeaderIndicator

        self.Health = healthBar
    end,

    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table
    Configure = function(self, unit, uDB, general)
        local healthBar = self.Health
        local healthBorderFrame = self.healthBorderFrame
        local healthBackground = healthBar.healthBackground
        local RaidIcon = self.RaidTargetIndicator
        local LeaderIndicator = self.LeaderIndicator
        local hDB = uDB.Health

        -- Position and size the raid icon.
        RaidIcon:NUISetPixelSize(uDB.RaidIcon.Size, uDB.RaidIcon.Size)
        RaidIcon:ClearAllPoints()
        RaidIcon:NUISetPixelPoint(uDB.RaidIcon.Position.AnchorFrom, self, uDB.RaidIcon.Position.AnchorTo, uDB.RaidIcon.Position.XOffset, uDB.RaidIcon.Position.YOffset)

        -- Position and size the leader indicator.
        LeaderIndicator:NUISetPixelSize(uDB.LeaderIndicator.Size, uDB.LeaderIndicator.Size)
        LeaderIndicator:ClearAllPoints()
        LeaderIndicator:NUISetPixelPoint(uDB.LeaderIndicator.Position.AnchorFrom, self, uDB.LeaderIndicator.Position.AnchorTo, uDB.LeaderIndicator.Position.XOffset, uDB.LeaderIndicator.Position.YOffset)

        -- Foreground texture, background follows it unless a background texture is set (unit override first).
        local texture = NRSKNUI:GetStatusbar(general, hDB.StatusBarTexture)
        local bgName = hDB.BackgroundTexture ~= '' and hDB.BackgroundTexture or general.BackgroundTexture
        healthBar:SetStatusBarTexture(texture)
        healthBackground:SetStatusBarTexture(bgName ~= '' and NRSKNUI:ResolveMediaPath('statusbar', bgName) or texture)

        -- Set sizing
        healthBar:SetAllPoints(self)
        healthBackground:SetAllPoints(self)
        healthBorderFrame:SetAllPoints(self)

        -- Prime to Immediate, postUpdate switches to the steady mode after the first paint.
        local smooth = hDB.UseGlobalSmooth and general.Smooth or (not hDB.UseGlobalSmooth and hDB.Smooth)
        healthBar.nuiSmoothing = smooth and Interpolation.ExponentialEaseOut or Interpolation.Immediate
        healthBar.smoothing = Interpolation.Immediate

        -- Background always fills opposite the foreground so the two meet in the middle.
        healthBar:SetReverseFill(hDB.Inverse or false)
        healthBackground:SetReverseFill(not (hDB.Inverse or false))

        -- The whole colour set comes from General unless the unit overrides it.
        local classColor, foreground, background, backgroundClass, classAlpha
        if hDB.UseGlobalColors then
            classColor = general.ColorByClass
            foreground = general.Colors.Foreground
            background = general.Colors.Background
            backgroundClass = general.Colors.BackgroundWhenColorByClass
            classAlpha = general.ForegroundAlphaWhenColorByClass
        else
            classColor = hDB.ColorByClass
            foreground = hDB.Foreground
            background = hDB.Background
            backgroundClass = hDB.BackgroundWhenColorByClass
            classAlpha = hDB.ForegroundAlphaWhenColorByClass
        end

        -- oUF flags pick the hue, PostUpdateHealthColor enforces the alpha.
        healthBar.ForegroundAlphaWhenColorByClass = classAlpha
        healthBar.nuiForeground = foreground
        healthBar.nuiColorByClass = classColor
        healthBar.colorClass = classColor
        healthBar.colorReaction = classColor
        healthBar.colorHealth = false

        -- Background coloring
        healthBackground:SetStatusBarColor(background[1], background[2], background[3], background[4])
        healthBar.nuiBackground = classColor and backgroundClass or background

        -- Mouseover highlight
        local highlight = self.nuiHighlight
        local hlDB = general.Highlight
        highlight.nuiEnabled = hlDB.Enabled
        highlight:NUISetPixelInside(self, 1, 1)
        highlight:SetTexture(NRSKNUI:GetStatusbar(hlDB))
        highlight:SetVertexColor(hlDB.Color[1], hlDB.Color[2], hlDB.Color[3], hlDB.Color[4])
        if not hlDB.Enabled then highlight:Hide() end

        -- Absorb bars
        local HealAbsorb = healthBar.nuiHealAbsorb
        local DamageAbsorb = healthBar.nuiDamageAbsorb
        local OverDamageAbsorb = healthBar.OverDamageAbsorb
        local OverClip = healthBar.OverDamageAbsorbClip
        local fill = healthBar:GetStatusBarTexture()
        local inverse = hDB.Inverse or false

        -- Each absorb reads the General slot unless the unit overrides the whole slot.
        local haDB = hDB.HealAbsorb.UseGlobal and general.HealAbsorb or hDB.HealAbsorb
        local daDB = hDB.DamageAbsorb.UseGlobal and general.DamageAbsorb or hDB.DamageAbsorb
        local healColor = haDB.Color
        local dmgColor = daDB.Color
        local shield = NRSKNUI:GetStatusbar(daDB)

        -- Both absorbs draw inside the health rect, so they claim layers like anything else on it. The
        -- over-absorb pair belongs to the damage absorb and rides its layer.
        local healAbsorbLevel = UF.GetLayerLevel(self, haDB.Layer)
        local damageAbsorbLevel = UF.GetLayerLevel(self, daDB.Layer)
        HealAbsorb:SetFrameLevel(healAbsorbLevel)
        DamageAbsorb:SetFrameLevel(damageAbsorbLevel)
        OverClip:SetFrameLevel(damageAbsorbLevel)
        OverDamageAbsorb:SetFrameLevel(damageAbsorbLevel)

        -- oUF only drives an absorb whose element field is set, so disabling clears it.
        healthBar.HealAbsorb = haDB.Enabled and HealAbsorb or nil
        healthBar.DamageAbsorb = daDB.Enabled and DamageAbsorb or nil
        HealAbsorb:SetShown(haDB.Enabled)
        DamageAbsorb:SetShown(daDB.Enabled)
        OverClip:SetShown(daDB.Enabled)

        -- Heal absorb bar config
        HealAbsorb:SetStatusBarTexture(NRSKNUI:GetStatusbar(haDB))
        HealAbsorb:SetStatusBarColor(healColor[1], healColor[2], healColor[3], healColor[4])
        HealAbsorb:ClearAllPoints()
        HealAbsorb:NUISetPixelPoint('TOP')
        HealAbsorb:NUISetPixelPoint('BOTTOM')

        -- Damage absorb bar config
        DamageAbsorb:SetStatusBarTexture(shield)
        DamageAbsorb:SetStatusBarColor(dmgColor[1], dmgColor[2], dmgColor[3], dmgColor[4])
        DamageAbsorb:ClearAllPoints()
        DamageAbsorb:NUISetPixelPoint('TOP')
        DamageAbsorb:NUISetPixelPoint('BOTTOM')

        -- Over-absorb bar config
        OverDamageAbsorb:SetStatusBarTexture(shield)
        OverDamageAbsorb:SetStatusBarColor(dmgColor[1], dmgColor[2], dmgColor[3], dmgColor[4])
        OverDamageAbsorb:NUISetPixelWidth(self:GetWidth())
        OverClip:ClearAllPoints()
        OverDamageAbsorb:ClearAllPoints()

        if inverse then
            -- Foreground fills right to left, so the current-health edge is on the left.
            HealAbsorb:NUISetPixelPoint('LEFT', fill)
            HealAbsorb:SetReverseFill(false)
            DamageAbsorb:NUISetPixelPoint('RIGHT', fill, 'LEFT')
            DamageAbsorb:SetReverseFill(true)

            OverClip:NUISetPixelPoint('TOPRIGHT', healthBar, 'TOPRIGHT')
            OverClip:NUISetPixelPoint('BOTTOMLEFT', fill, 'BOTTOMLEFT')
            OverDamageAbsorb:NUISetPixelPoint('TOPLEFT', healthBar, 'TOPLEFT')
            OverDamageAbsorb:NUISetPixelPoint('BOTTOMLEFT', healthBar, 'BOTTOMLEFT')
            OverDamageAbsorb:SetReverseFill(false)
        else
            -- Foreground fills left to right, so the current-health edge is on the right.
            HealAbsorb:NUISetPixelPoint('RIGHT', fill)
            HealAbsorb:SetReverseFill(true)
            DamageAbsorb:NUISetPixelPoint('LEFT', fill, 'RIGHT')
            DamageAbsorb:SetReverseFill(false)

            OverClip:NUISetPixelPoint('TOPLEFT', healthBar, 'TOPLEFT')
            OverClip:NUISetPixelPoint('BOTTOMRIGHT', fill, 'BOTTOMRIGHT')
            OverDamageAbsorb:NUISetPixelPoint('TOPRIGHT', healthBar, 'TOPRIGHT')
            OverDamageAbsorb:NUISetPixelPoint('BOTTOMRIGHT', healthBar, 'BOTTOMRIGHT')
            OverDamageAbsorb:SetReverseFill(true)
        end
    end,
}

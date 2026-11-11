---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')

local CreateFrame = CreateFrame

local Interpolation = Enum.StatusBarInterpolation

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
            UF:ShowTooltip(self.__unit)
        end)
        self:SetScript('OnLeave', function()
            self.nuiHighlight:Hide()
            UF:HideTooltip()
        end)

        -- Backgroundbar
        local healthBackground = CreateFrame('StatusBar', nil, self)
        healthBackground:SetFrameLevel(self:GetFrameLevel() + UF.BaseLevels.Background)
        healthBackground:SetReverseFill(true)
        healthBackground:NCDisablePixelSnap()

        -- Health bar
        local healthBar = CreateFrame('StatusBar', nil, self) --[[@as oUF.Health]]
        healthBar:SetFrameLevel(self:GetFrameLevel() + UF.BaseLevels.Bar)
        healthBar:NCDisablePixelSnap()
        healthBar:SetClipsChildren(true) -- Keep over-absorb overflow inside the bar.
        healthBar.healthBackground = healthBackground
        healthBar.PostUpdate = UF.PostUpdateHealth
        healthBar.PostUpdateColor = UF.PostUpdateHealthColor

        -- Temporary max health loss, LayoutBars ends the health bar at its fill.
        local TempLoss = CreateFrame('StatusBar', nil, self)
        TempLoss:SetFrameLevel(self:GetFrameLevel() + UF.BaseLevels.Bar)
        TempLoss:NCDisablePixelSnap()
        healthBar.nuiTempLoss = TempLoss

        -- Incoming heal bar
        local HealingAll = CreateFrame('StatusBar', nil, healthBar)
        HealingAll:NCDisablePixelSnap()
        HealingAll:NCSetWidth(self:GetWidth())

        -- Heal absorb bar
        local HealAbsorb = CreateFrame('StatusBar', nil, healthBar)
        HealAbsorb:NCDisablePixelSnap()
        HealAbsorb:NCSetWidth(self:GetWidth())
        healthBar.HealAbsorb = HealAbsorb

        local OverHealAbsorb = HealAbsorb:CreateTexture(nil, 'OVERLAY')
        OverHealAbsorb:NCDisablePixelSnap()
        healthBar.nuiOverHealAbsorb = OverHealAbsorb

        -- Damage absorb bar
        local DamageAbsorb = CreateFrame('StatusBar', nil, healthBar)
        DamageAbsorb:NCDisablePixelSnap()
        DamageAbsorb:NCSetWidth(self:GetWidth())
        healthBar.DamageAbsorb = DamageAbsorb

        -- Over-absorb bar clip frame.
        local OverDamageAbsorbClip = CreateFrame('Frame', nil, healthBar)
        OverDamageAbsorbClip:SetClipsChildren(true)
        healthBar.OverDamageAbsorbClip = OverDamageAbsorbClip

        -- Over-absorb bar.
        local OverDamageAbsorb = CreateFrame('StatusBar', nil, OverDamageAbsorbClip)
        OverDamageAbsorb:NCDisablePixelSnap()
        OverDamageAbsorb:NCSetWidth(self:GetWidth())

        healthBar.OverDamageAbsorb = OverDamageAbsorb
        healthBar.damageAbsorbClampMode = 2
        healthBar.healAbsorbClampMode = 1
        healthBar.healAbsorbMode = 1

        -- oUF skips an absorb whose field is nil, so disabling clears the field, these keep the bars reachable for configuration.
        healthBar.nuiHealAbsorb = HealAbsorb
        healthBar.nuiDamageAbsorb = DamageAbsorb
        healthBar.nuiHealingAll = HealingAll

        -- Mouseover highlight
        local highlightFrame = CreateFrame('Frame', nil, self)
        self.nuiHighlightFrame = highlightFrame

        local highlight = highlightFrame:CreateTexture(nil, 'OVERLAY') --[[@as NUI.HighlightTexture]]
        highlight:SetBlendMode('ADD')
        highlight:Hide()
        self.nuiHighlight = highlight

        -- Border frame
        local healthBorderFrame = CreateFrame('Frame', nil, self)
        healthBorderFrame:NCAddBorders()
        self.healthBorderFrame = healthBorderFrame

        self.Health = healthBar
    end,

    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table
    Configure = function(self, unit, uDB, general)
        local healthBar = self.Health
        local healthBackground = healthBar.healthBackground
        local hDB = uDB.Health

        -- Foreground texture, background follows it unless a background texture is set (unit override first).
        local texture = NRSKNUI:GetStatusbar(general, hDB.StatusBarTexture)
        local bgName = hDB.BackgroundTexture ~= '' and hDB.BackgroundTexture or general.BackgroundTexture
        healthBar:SetStatusBarTexture(texture)
        healthBackground:SetStatusBarTexture(bgName ~= '' and NRSKNUI:ResolveMediaPath('statusbar', bgName) or texture)

        local tlDB = hDB.TempLoss.UseGlobal and general.TempLoss or hDB.TempLoss
        local TempLoss = healthBar.nuiTempLoss
        healthBar.TempLoss = tlDB.Enabled and TempLoss or nil
        healthBar.nuiInverse = hDB.Inverse or false
        TempLoss:SetShown(tlDB.Enabled)
        TempLoss:SetStatusBarTexture(NRSKNUI:GetStatusbar(tlDB))
        TempLoss:SetStatusBarColor(tlDB.Color[1], tlDB.Color[2], tlDB.Color[3], tlDB.Color[4])
        TempLoss:SetReverseFill(not healthBar.nuiInverse)

        -- Sizing: the whole frame, or the part above a docked power bar.
        UF.LayoutBars(self)

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
        UF.CacheColor(healthBar, 'nuiForeground', foreground)
        healthBar.nuiColorByClass = classColor
        healthBar.colorClass = classColor
        healthBar.colorReaction = classColor
        healthBar.colorHealth = false

        -- Background coloring
        healthBackground:SetStatusBarColor(background[1], background[2], background[3], background[4])
        UF.CacheColor(healthBar, 'nuiBackground', classColor and backgroundClass or background)

        -- Mouseover highlight
        local highlight = self.nuiHighlight
        local hlDB = general.Highlight
        highlight.nuiEnabled = hlDB.Enabled
        highlight:NCSetInside(self, 1, 1)
        highlight:SetTexture(NRSKNUI:GetStatusbar(hlDB))
        highlight:SetVertexColor(hlDB.Color[1], hlDB.Color[2], hlDB.Color[3], hlDB.Color[4])
        if not hlDB.Enabled then highlight:Hide() end

        -- Absorb bars
        local HealAbsorb = healthBar.nuiHealAbsorb
        local DamageAbsorb = healthBar.nuiDamageAbsorb
        local HealingAll = healthBar.nuiHealingAll
        local OverDamageAbsorb = healthBar.OverDamageAbsorb
        local OverClip = healthBar.OverDamageAbsorbClip
        local fill = healthBar:GetStatusBarTexture()
        local inverse = hDB.Inverse or false

        -- Each absorb reads the General slot unless the unit overrides the whole slot.
        local haDB = hDB.HealAbsorb.UseGlobal and general.HealAbsorb or hDB.HealAbsorb
        local daDB = hDB.DamageAbsorb.UseGlobal and general.DamageAbsorb or hDB.DamageAbsorb
        local hpDB = hDB.HealPrediction.UseGlobal and general.HealPrediction or hDB.HealPrediction

        healthBar.HealingAll = hpDB.Enabled and HealingAll or nil
        HealingAll:SetShown(hpDB.Enabled)
        HealingAll:SetStatusBarTexture(NRSKNUI:GetStatusbar(hpDB))
        HealingAll:SetStatusBarColor(hpDB.Color[1], hpDB.Color[2], hpDB.Color[3], hpDB.Color[4])
        HealingAll:ClearAllPoints()
        HealingAll:NCSetPoint('TOP')
        HealingAll:NCSetPoint('BOTTOM')
        HealingAll:SetReverseFill(inverse)

        -- The damage absorb continues past incoming heals.
        local absorbEdge = hpDB.Enabled and HealingAll:GetStatusBarTexture() or fill
        local healColor = haDB.Color
        local dmgColor = daDB.Color
        local shield = NRSKNUI:GetStatusbar(daDB)

        -- oUF only drives an absorb whose element field is set, so disabling clears it.
        healthBar.HealAbsorb = haDB.Enabled and HealAbsorb or nil
        healthBar.DamageAbsorb = daDB.Enabled and DamageAbsorb or nil
        HealAbsorb:SetShown(haDB.Enabled)
        DamageAbsorb:SetShown(daDB.Enabled)
        OverClip:SetShown(daDB.Enabled)

        -- oUF registers each sub-widget's event on enable only, so a changed set re-enables the element.
        local subWidgets = (hpDB.Enabled and 1 or 0) + (haDB.Enabled and 2 or 0) + (daDB.Enabled and 4 or 0) + (tlDB.Enabled and 8 or 0)
        if healthBar.nuiSubWidgets and healthBar.nuiSubWidgets ~= subWidgets and self:IsElementEnabled('Health') then
            self:DisableElement('Health')
            self:EnableElement('Health')
        end
        healthBar.nuiSubWidgets = subWidgets

        -- Heal absorb bar config
        HealAbsorb:SetStatusBarTexture(NRSKNUI:GetStatusbar(haDB))
        HealAbsorb:SetStatusBarColor(healColor[1], healColor[2], healColor[3], healColor[4])
        HealAbsorb:ClearAllPoints()
        HealAbsorb:NCSetPoint('TOP')
        HealAbsorb:NCSetPoint('BOTTOM')

        -- Marks a heal absorb larger than current health, at the bar's empty end.
        local OverHealAbsorb = healthBar.nuiOverHealAbsorb
        healthBar.OverHealAbsorbIndicator = haDB.Enabled and OverHealAbsorb or nil
        OverHealAbsorb:SetColorTexture(healColor[1], healColor[2], healColor[3], 1)
        OverHealAbsorb:ClearAllPoints()
        OverHealAbsorb:NCSetPoint('TOP' .. (inverse and 'RIGHT' or 'LEFT'), healthBar)
        OverHealAbsorb:NCSetPoint('BOTTOM' .. (inverse and 'RIGHT' or 'LEFT'), healthBar)
        OverHealAbsorb:NCSetWidth(2)

        -- Damage absorb bar config
        DamageAbsorb:SetStatusBarTexture(shield)
        DamageAbsorb:SetStatusBarColor(dmgColor[1], dmgColor[2], dmgColor[3], dmgColor[4])
        DamageAbsorb:ClearAllPoints()
        DamageAbsorb:NCSetPoint('TOP')
        DamageAbsorb:NCSetPoint('BOTTOM')

        -- Over-absorb bar config
        OverDamageAbsorb:SetStatusBarTexture(shield)
        OverDamageAbsorb:SetStatusBarColor(dmgColor[1], dmgColor[2], dmgColor[3], dmgColor[4])
        OverDamageAbsorb:NCSetWidth(self:GetWidth())
        OverClip:ClearAllPoints()
        OverDamageAbsorb:ClearAllPoints()

        if inverse then
            -- Foreground fills right to left, so the current-health edge is on the left.
            HealAbsorb:NCSetPoint('LEFT', fill)
            HealAbsorb:SetReverseFill(false)
            HealingAll:NCSetPoint('RIGHT', fill, 'LEFT')
            DamageAbsorb:NCSetPoint('RIGHT', absorbEdge, 'LEFT')
            DamageAbsorb:SetReverseFill(true)

            OverClip:NCSetPoint('TOPRIGHT', healthBar, 'TOPRIGHT')
            OverClip:NCSetPoint('BOTTOMLEFT', fill, 'BOTTOMLEFT')
            OverDamageAbsorb:NCSetPoint('TOPLEFT', healthBar, 'TOPLEFT')
            OverDamageAbsorb:NCSetPoint('BOTTOMLEFT', healthBar, 'BOTTOMLEFT')
            OverDamageAbsorb:SetReverseFill(false)
        else
            -- Foreground fills left to right, so the current-health edge is on the right.
            HealAbsorb:NCSetPoint('RIGHT', fill)
            HealAbsorb:SetReverseFill(true)
            HealingAll:NCSetPoint('LEFT', fill, 'RIGHT')
            DamageAbsorb:NCSetPoint('LEFT', absorbEdge, 'RIGHT')
            DamageAbsorb:SetReverseFill(false)

            OverClip:NCSetPoint('TOPLEFT', healthBar, 'TOPLEFT')
            OverClip:NCSetPoint('BOTTOMRIGHT', fill, 'BOTTOMRIGHT')
            OverDamageAbsorb:NCSetPoint('TOPRIGHT', healthBar, 'TOPRIGHT')
            OverDamageAbsorb:NCSetPoint('BOTTOMRIGHT', healthBar, 'BOTTOMRIGHT')
            OverDamageAbsorb:SetReverseFill(true)
        end
    end,
}

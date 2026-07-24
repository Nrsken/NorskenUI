---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class FocusCastbar: AceModule, AceEvent-3.0
local FCB = NRSKNUI:NewModule("FocusCastbar", "AceEvent-3.0")
local EM = NRSKNUI.EditMode

local CreateFrame = CreateFrame
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local UnitCastingDuration, UnitChannelDuration = UnitCastingDuration, UnitChannelDuration
local UnitEmpoweredChannelDuration = UnitEmpoweredChannelDuration
local UnitExists = UnitExists
local select = select
local UnitClass = UnitClass
local UnitName = UnitName
local CreateColor = CreateColor
local GetTime = GetTime
local UnitSpellTargetName = UnitSpellTargetName
local UnitSpellTargetClass = UnitSpellTargetClass
local UnitNameFromGUID = UnitNameFromGUID
local UnitClassFromGUID = UnitClassFromGUID
local GetRaidTargetIndex = GetRaidTargetIndex
local SetRaidTargetIconTexture = SetRaidTargetIconTexture
local random = math.random
local ipairs = ipairs

local LCG = NRSKNUI.Libs.LCG

local FALLBACK_ICON = 136243
local INTERRUPTED = "Interrupted"
local INTERRUPTED_BY = "Interrupted by %s"
local PREVIEW_DURATION = 20

function FCB:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.FocusCastbar
end

function FCB:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function FCB:CreateColorObjects()
    local kick = self.db.KickIndicator
    local cast = self.db.CastColor
    self.colors = {
        Cast = CreateColor(cast[1], cast[2], cast[3]),
        NotReady = CreateColor(kick.NotReadyColor[1], kick.NotReadyColor[2], kick.NotReadyColor[3]),
        Uninterruptible = CreateColor(self.db.NotInterruptibleColor[1], self.db.NotInterruptibleColor[2],
            self.db.NotInterruptibleColor[3]),
    }
end

function FCB:ResetCastState()
    self.casting, self.channeling, self.empowering = nil, nil, nil
    self.castID, self.spellID, self.spellName = nil, nil, nil
    self.notInterruptible = nil
    self.cachedDuration = nil
end

function FCB:CreateFrame()
    if self.frame then return end
    local db = self.db
    local height = db.Height

    local frame = CreateFrame("Frame", "NRSKNUI_FocusCastbarFrame", UIParent)
    frame:SetPixelSize(db.Width, height)
    frame:SetPoint(db.Position.AnchorFrom, UIParent, db.Position.AnchorTo, db.Position.XOffset, db.Position.YOffset)
    frame:SetFrameLevel(100)
    frame:CreateBackdrop(true)
    frame:AddBorders()
    frame:SetBackgroundColor(unpack(db.BackdropColor))
    frame:SetBorderColor(unpack(db.BorderColor))
    frame:SetFrameStrata(db.Strata)
    frame:EnableMouse(false)
    frame:Hide()

    local iconFrame = CreateFrame("Frame", nil, frame)
    iconFrame:SetPixelSize(height, height)
    iconFrame:SetPixelPoint("LEFT", frame, "LEFT", 0, 0)
    iconFrame:CreateBackdrop()
    iconFrame:SetBackgroundColor(unpack(db.BackdropColor))
    iconFrame:SetBorderColor(unpack(db.BorderColor))

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetZoom()

    local castBar = CreateFrame("StatusBar", nil, frame)
    castBar:SetPoint("LEFT", iconFrame, "RIGHT", 0, 0)
    castBar:SetPoint("RIGHT", frame, "RIGHT", -1, 0)
    castBar:SetPoint("TOP", frame, "TOP", 0, -1)
    castBar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 1)
    castBar:SetStatusBarTexture(NRSKNUI:GetStatusbar(db))
    castBar:SetMinMaxValues(0, 1)
    castBar:SetValue(0)

    local spark = castBar:CreateTexture(nil, "OVERLAY")
    spark:SetSize(12, height)
    spark:SetBlendMode("ADD")
    spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
    spark:SetPoint("CENTER", castBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    spark:Hide()

    local positioner = CreateFrame("StatusBar", nil, castBar)
    positioner:SetAllPoints(castBar)
    positioner:SetStatusBarTexture(NRSKNUI:GetStatusbar(db))
    positioner:SetStatusBarColor(0, 0, 0, 0)
    positioner:SetMinMaxValues(0, 1)
    positioner:SetValue(0)
    positioner:SetFrameLevel(castBar:GetFrameLevel() + 1)

    local kickCooldownBar = CreateFrame("StatusBar", nil, castBar)
    kickCooldownBar:SetAllPoints(castBar)
    kickCooldownBar:SetStatusBarTexture(NRSKNUI:GetStatusbar(db))
    kickCooldownBar:SetStatusBarColor(0, 0, 0, 0)
    kickCooldownBar:SetClipsChildren(true)
    kickCooldownBar:SetMinMaxValues(0, 1)
    kickCooldownBar:SetValue(0)
    kickCooldownBar:SetFrameLevel(castBar:GetFrameLevel() + 4)

    local tickMask = castBar:CreateMaskTexture()
    tickMask:SetAllPoints(castBar)
    tickMask:SetTexture("Interface\\BUTTONS\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    local kickTick = kickCooldownBar:CreateTexture(nil, "OVERLAY", nil, 7)
    kickTick:SetSize(2, height)
    kickTick:SetColorTexture(1, 1, 1, 1)
    kickTick:SetPoint("CENTER", kickCooldownBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    kickTick:AddMaskTexture(tickMask)
    kickTick:SetAlpha(0)

    local text = castBar:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", castBar, "LEFT", 4, 0)
    text:SetJustifyH("LEFT")

    local time = castBar:CreateFontString(nil, "OVERLAY")
    time:SetPoint("RIGHT", castBar, "RIGHT", -4, 0)
    time:SetJustifyH("RIGHT")

    local targetText = frame:CreateFontString(nil, "OVERLAY")
    targetText:SetParent(castBar)
    targetText:Hide()

    local targetMarker = frame:CreateTexture(nil, "OVERLAY")
    targetMarker:SetTexture("Interface/TargetingFrame/UI-RaidTargetingIcons")
    targetMarker:SetSize(40, 40)
    targetMarker:SetParent(castBar)
    targetMarker:Hide()

    self.targetMarker = targetMarker
    self.positioner = positioner
    self.frame, self.iconFrame, self.icon = frame, iconFrame, icon
    self.castBar, self.spark = castBar, spark
    self.kickCooldownBar, self.kickTick = kickCooldownBar, kickTick
    self.text, self.time = text, time
    self.targetText = targetText
    self.holdTimer = nil
end

function FCB:ApplySettings()
    if not self.frame then return end
    self:CreateColorObjects()

    local db = self.db

    self.frame:SetPixelSize(db.Width, db.Height)
    self.frame:SetBackgroundColor(db.BackdropColor[1], db.BackdropColor[2], db.BackdropColor[3], db.BackdropColor[4])
    self.frame:SetBorderColor(db.BorderColor[1], db.BorderColor[2], db.BorderColor[3], db.BorderColor[4])
    self.frame:SetFrameStrata(db.Strata)

    self.iconFrame:SetSize(db.Height, db.Height)
    self.iconFrame:SetBorderColor(db.BorderColor[1], db.BorderColor[2], db.BorderColor[3], db.BorderColor[4])

    local texturePath = NRSKNUI:GetStatusbar(db)
    self.castBar:SetStatusBarTexture(texturePath)
    self.positioner:SetStatusBarTexture(texturePath)
    self.kickCooldownBar:SetStatusBarTexture(texturePath)
    self.spark:SetSize(12, db.Height)

    self.kickTick:SetSize(2, db.Height)
    local tickColor = db.KickIndicator.TickColor
    self.kickTick:SetColorTexture(tickColor[1], tickColor[2], tickColor[3], tickColor[4])

    self.text:SetFontStyle(db)
    self.time:SetFontStyle(db)
    self.text:SetTextColor(db.TextColor[1], db.TextColor[2], db.TextColor[3], db.TextColor[4])
    self.time:SetTextColor(db.TextColor[1], db.TextColor[2], db.TextColor[3], db.TextColor[4])

    if self.targetText then
        local targetSettings = db.TargetNames
        local anchorPoint = NRSKNUI:GetJustifyFromAnchor(targetSettings.Anchor)
        self.targetText:ClearAllPoints()
        self.targetText:SetPoint(anchorPoint, self.frame, anchorPoint, targetSettings.XOffset, targetSettings.YOffset)
        self.targetText:SetJustifyH(anchorPoint)
        self.targetText:SetFontStyle(db, targetSettings.FontSize)
    end

    if self.targetMarker then
        local markerSettings = db.TargetMarker
        local anchorPoint = NRSKNUI:GetJustifyFromAnchor(markerSettings.Anchor)
        self.targetMarker:SetSize(markerSettings.Size, markerSettings.Size)
        self.targetMarker:ClearAllPoints()
        self.targetMarker:SetPoint(anchorPoint, self.frame, anchorPoint, markerSettings.XOffset, markerSettings.YOffset)
    end

    self.frame:ApplyPosition(self.db, true)

    if self.isPreview then
        self:RefreshPreviewSoftOutlines()
        self:RefreshPreviewGlow()
    end
end

function FCB:RefreshPreviewSoftOutlines()
    if self.targetText and self.targetText.softOutline then
        local name = UnitName("player")
        if name and not (issecurevariable and issecurevariable(name)) then
            self.targetText.softOutline:SetText(name)
        end
    end

    if self.text and self.text.softOutline then
        local currentText = self.text:GetText()
        if currentText and type(currentText) == "string" and not (issecretvalue and issecretvalue(currentText)) then
            local plainText = currentText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            self.text.softOutline:SetText(plainText)
        end
    end
end

function FCB:RefreshPreviewGlow()
    if not self.isPreview then return end

    self:ResetGlow()

    if self.db.ImportantGlow.GlowEnabled and self.casting then
        self:InitGlow()
        local glowFrame = self:GetGlowFrame()
        if glowFrame then
            glowFrame:SetAlpha(1)
        end
    end
end

function FCB:UpdateBarColor(interruptDuration)
    if not self.castBar then return end
    local kick = self.db.KickIndicator
    local texture = self.castBar:GetStatusBarTexture()
    local hasActiveCast = self.casting or self.channeling or self.empowering

    if self.isPreview then
        local color = self.db.CastColor
        texture:SetVertexColor(color[1], color[2], color[3], color[4])
        return
    end

    if kick.Enabled and hasActiveCast then
        if self.interruptId then
            local cooldown = interruptDuration or C_Spell.GetSpellCooldownDuration(self.interruptId)
            if cooldown then
                local interruptibleColor = C_CurveUtil.EvaluateColorFromBoolean(
                    cooldown:IsZero(),
                    self.colors.Cast,
                    self.colors.NotReady
                )
                texture:SetVertexColorFromBoolean(self.notInterruptible, self.colors.Uninterruptible, interruptibleColor)
                return
            end
        end
        texture:SetVertexColorFromBoolean(self.notInterruptible, self.colors.Uninterruptible, self.colors.NotReady)
        return
    end

    local color = self.db.CastColor
    texture:SetVertexColor(color[1], color[2], color[3], color[4])
end

function FCB:CacheInterruptId()
    local playerClass = select(3, UnitClass("player"))
    local interrupts = NRSKNUI.CLASS_INTERRUPTS[playerClass]
    if not interrupts then
        self.interruptId = nil
        return
    end
    for i = 1, #interrupts do
        local id = interrupts[i]
        if C_SpellBook.IsSpellKnownOrInSpellBook(id)
            or C_SpellBook.IsSpellKnownOrInSpellBook(id, Enum.SpellBookSpellBank.Pet) then
            self.interruptId = id
            return
        end
    end
    self.interruptId = nil
end

function FCB:UpdateKickIndicator()
    local kick = self.db.KickIndicator
    if not kick.Enabled then
        self.kickTick:SetAlpha(0)
        return
    end

    if self.isPreview then return end

    if not self.interruptId then
        self.kickTick:SetAlpha(0)
        return
    end

    local cooldown = C_Spell.GetSpellCooldownDuration(self.interruptId)
    if not cooldown then return end

    self.kickTick:SetAlphaFromBoolean(cooldown:IsZero(), 0,
        C_CurveUtil.EvaluateColorValueFromBoolean(self.notInterruptible, 0, 1))

    self:UpdateBarColor(cooldown)
end

function FCB:UpdateTickPosition(duration)
    local kick = self.db.KickIndicator
    if not kick.Enabled then return end

    self.positioner:SetValue(duration:GetElapsedDuration())

    if self.isPreview then return end

    if not self.interruptId then return end

    local cooldown = C_Spell.GetSpellCooldownDuration(self.interruptId)
    if not cooldown then return end

    self.kickCooldownBar:SetValue(cooldown:GetRemainingDuration())
end

function FCB:UpdateTargetText()
    if not self.targetText then return end
    if self.isPreview then return end

    if not UnitExists("focus") then
        self:HideTargetText()
        return
    end
    if not (self.casting or self.channeling or self.empowering) then
        self:HideTargetText()
        return
    end

    local targetName = UnitSpellTargetName("focus")
    local targetClass = targetName and UnitSpellTargetClass("focus")

    if not targetName then
        self:HideTargetText()
        return
    end

    local coloredTarget
    if targetClass then
        local color = C_ClassColor.GetClassColor(targetClass)
        if color then
            coloredTarget = color:WrapTextInColorCode(targetName)
        else
            coloredTarget = targetName
        end
    else
        coloredTarget = targetName
    end

    self.targetText:SetText(coloredTarget)
    if self.targetText.softOutline then
        self.targetText.softOutline:SetShown(true)
        self.targetText.softOutline:SetText(targetName)
    end
    self.targetText:Show()
end

function FCB:HideTargetText()
    if not self.targetText then return end
    self.targetText:Hide()
    if self.targetText.softOutline then
        self.targetText.softOutline:SetShown(false)
    end
end

function FCB:ToggleTargetMarkerIntegration()
    if self.db.TargetMarker and self.db.TargetMarker.Enabled then
        self:RegisterEvent("RAID_TARGET_UPDATE", "UpdateTargetMarker")
    else
        self:UnregisterEvent("RAID_TARGET_UPDATE")
        if self.targetMarker then
            self.targetMarker:Hide()
        end
    end
end

function FCB:UpdateTargetMarker()
    if not self.targetMarker then return end

    if not self.db.TargetMarker or not self.db.TargetMarker.Enabled then
        self.targetMarker:Hide()
        return
    end

    local index = GetRaidTargetIndex("focus")
    if index == nil then
        self.targetMarker:Hide()
    else
        SetRaidTargetIconTexture(self.targetMarker, index)
        self.targetMarker:Show()
    end
end

function FCB:SetupKickCooldownBar()
    local kick = self.db.KickIndicator
    if not kick or not kick.Enabled or not self.interruptId then
        self.kickTick:SetAlpha(0)
        return
    end

    -- Check if duration object exists
    local duration = self.cachedDuration
    if not duration then
        self.kickTick:SetAlpha(0)
        return
    end

    local width, height = self.castBar:GetSize()
    local isChannel = self.channeling or false

    self.positioner:SetMinMaxValues(0, duration:GetTotalDuration())
    self.positioner:SetReverseFill(isChannel)

    self.kickCooldownBar:ClearAllPoints()
    self.kickCooldownBar:SetSize(width, height)
    self.kickCooldownBar:SetReverseFill(isChannel)
    self.kickCooldownBar:SetMinMaxValues(0, duration:GetTotalDuration())

    self.kickTick:ClearAllPoints()
    self.kickTick:SetSize(2, height)

    if isChannel then
        self.kickCooldownBar:SetPoint("RIGHT", self.positioner:GetStatusBarTexture(), "LEFT")
        self.kickTick:SetPoint("RIGHT", self.kickCooldownBar:GetStatusBarTexture(), "LEFT")
    else
        self.kickCooldownBar:SetPoint("LEFT", self.positioner:GetStatusBarTexture(), "RIGHT")
        self.kickTick:SetPoint("LEFT", self.kickCooldownBar:GetStatusBarTexture(), "RIGHT")
    end
end

function FCB:GetGlowFrame()
    if not self.frame then return nil end
    local glowType = self.db.ImportantGlow.GlowType
    if glowType == "pixel" then
        return self.frame._PixelGlow
    elseif glowType == "autocast" then
        return self.frame._AutoCastGlow
    end
    return self.frame._PixelGlow
end

function FCB:InitGlow()
    if not self.frame or not LCG then return end
    if self.glowInitialized then return end

    local glowDb = self.db.ImportantGlow
    local glowType = glowDb.GlowType

    if glowType == "autocast" then
        LCG.AutoCastGlow_Start(self.frame, glowDb.GlowColor, glowDb.GlowLines, glowDb.GlowFrequency,
            glowDb.GlowScale, 1, 1, nil)
    else
        LCG.PixelGlow_Start(self.frame, glowDb.GlowColor, glowDb.GlowLines, glowDb.GlowFrequency,
            glowDb.GlowLength, glowDb.GlowThickness, 0, 0, glowDb.GlowBorder, nil)
    end

    local glowFrame = self:GetGlowFrame()
    if glowFrame then
        glowFrame:SetAlpha(0)
    end

    self.glowInitialized = true
end

function FCB:ShowGlow(isImportant)
    if not self.db.ImportantGlow.GlowEnabled then return end
    if not LCG then return end

    self:InitGlow()

    local glowFrame = self:GetGlowFrame()
    if glowFrame then
        glowFrame:SetAlphaFromBoolean(isImportant)
    end
end

function FCB:HideGlow()
    local glowFrame = self:GetGlowFrame()
    if glowFrame then
        glowFrame:SetAlpha(0)
    end
end

function FCB:ResetGlow()
    if not self.frame or not LCG then return end

    LCG.PixelGlow_Stop(self.frame)
    LCG.AutoCastGlow_Stop(self.frame)

    self.glowInitialized = false
end

function FCB:OnCastEvent(event, unit, ...)
    if unit ~= "focus" then return end
    if event:find("START") then
        self:StartCast()
    elseif event:find("STOP") then
        local interruptedBy
        if event:find("CHANNEL") then
            interruptedBy = select(3, ...)
        elseif event:find("EMPOWER") then
            interruptedBy = select(4, ...)
        end
        local wasInterrupted = interruptedBy ~= nil
        self:EndCast(wasInterrupted, wasInterrupted, interruptedBy)
    elseif event:find("INTERRUPTED") then
        local interruptedBy = select(3, ...)
        self:EndCast(true, true, interruptedBy)
    elseif event:find("FAILED") then
        self:EndCast(true, false)
    elseif event:find("INTERRUPTIBLE") then
        self:UpdateInterruptible()
    end
end

function FCB:StartCast()
    if not self.frame or not UnitExists("focus") then return end
    local name, text, texture, castID, notInterruptible, spellID, isEmpowered
    local duration, direction = nil, Enum.StatusBarTimerDirection.ElapsedTime

    -- Try regular cast first
    name, text, texture, _, _, _, castID, notInterruptible, spellID = UnitCastingInfo("focus")
    if name then
        self.casting, self.channeling, self.empowering = true, nil, nil
        duration = UnitCastingDuration("focus")
    else
        -- Try channel
        name, text, texture, _, _, _, notInterruptible, spellID, isEmpowered, _, castID = UnitChannelInfo("focus")
        if name then
            self.casting = nil
            if isEmpowered then
                self.empowering, self.channeling = true, nil
                duration = UnitEmpoweredChannelDuration("focus")
            else
                self.channeling, self.empowering = true, nil
                duration = UnitChannelDuration("focus")
                direction = Enum.StatusBarTimerDirection.RemainingTime
            end
        end
    end

    if not name then
        if not self.holdTimer then
            self:ResetCastState()
            self.frame:Hide()
        end
        return
    end

    -- Cancel any pending hold timer
    if self.holdTimer then
        self.holdTimer:Cancel()
        self.holdTimer = nil
    end

    self.castID, self.spellID, self.spellName = castID, spellID, text or name
    self.notInterruptible = notInterruptible

    -- Hide non-interruptible casts if enabled
    if self.db.HideNotInterruptible then
        self.frame:SetAlphaFromBoolean(notInterruptible, 0, 1)
    else
        self.frame:SetAlpha(1)
    end

    self.castBar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)

    -- Store duration object
    self.cachedDuration = duration

    -- Positioner mirrors cast progress for tick anchoring
    local isChannel = self.channeling == true
    self.positioner:SetReverseFill(isChannel)

    if duration then
        self.positioner:SetMinMaxValues(0, duration:GetTotalDuration())
    end
    self.positioner:SetValue(0)

    self.icon:SetTexture(texture or FALLBACK_ICON)
    self.spark:Show()
    self.text:SetText(text or name or "")
    self.time:SetText("")

    self:UpdateBarColor()
    self:SetupKickCooldownBar()
    self:EnsureOnUpdate()
    self.frame:Show()

    if self.db.ImportantGlow.GlowEnabled and spellID then
        self:ShowGlow(C_Spell.IsSpellImportant(spellID))
    end
end

function FCB:EndCast(showHold, wasInterrupted, interruptedBy)
    if not self.frame or not self.frame:IsShown() then return end
    if self.holdTimer then return end

    local holdSettings = self.db.HoldTimer
    if not holdSettings.Enabled then
        self.spark:Hide()
        self:HideTargetText()
        self:HideGlow()
        self:ResetCastState()
        self.frame:Hide()
        return
    end

    self.spark:Hide()
    self.kickTick:SetAlpha(0)
    self:HideTargetText()
    self:HideGlow()

    self.castBar:SetMinMaxValues(0, 1)
    self.castBar:SetValue(1)
    self.positioner:SetMinMaxValues(0, 1)
    self.positioner:SetValue(1)
    self.time:SetText("")

    local texture = self.castBar:GetStatusBarTexture()
    if wasInterrupted then
        local displayText, plainText = INTERRUPTED, INTERRUPTED
        if interruptedBy then
            local name = UnitNameFromGUID(interruptedBy)
            local classToken = select(2, UnitClassFromGUID(interruptedBy))
            if name then
                local color = classToken and C_ClassColor.GetClassColor(classToken)
                local coloredName = color and color:WrapTextInColorCode(name) or name
                displayText = INTERRUPTED_BY:format(coloredName)
                plainText = INTERRUPTED_BY:format(name)
            end
        end
        self.text:SetText(displayText)
        if self.text.softOutline then
            self.text.softOutline:SetShown(true)
            self.text.softOutline:SetText(plainText)
        end
        local color = holdSettings.InterruptedColor
        texture:SetVertexColor(color[1], color[2], color[3], color[4])
    elseif showHold then
        local color = holdSettings.FailedColor
        texture:SetVertexColor(color[1], color[2], color[3], color[4])
    else
        local color = holdSettings.SuccessColor
        texture:SetVertexColor(color[1], color[2], color[3], color[4])
    end

    self:ResetCastState()

    self.holdTimer = C_Timer.NewTimer(holdSettings.Duration, function()
        self.holdTimer = nil
        if self.frame and not (self.casting or self.channeling or self.empowering) then
            self.frame:Hide()
        end
    end)
end

function FCB:UpdateInterruptible()
    if not self.frame or not self.frame:IsShown() then return end
    if not C_CastingInfo then return end

    local castInfo = C_CastingInfo.GetCastInfo("focus") or C_CastingInfo.GetChannelInfo("focus")
    if not castInfo then return end

    self.notInterruptible = castInfo.notInterruptible

    if self.db.HideNotInterruptible then
        self.frame:SetAlphaFromBoolean(self.notInterruptible, 0, 1)
    end

    self:UpdateBarColor()
end

function FCB:PLAYER_FOCUS_CHANGED()
    if UnitExists("focus") then
        self:StartCast()
        self:UpdateTargetMarker()
    else
        self:HideTargetText()
        self:ResetCastState()
        if self.holdTimer then
            self.holdTimer:Cancel()
            self.holdTimer = nil
        end
        if self.targetMarker then
            self.targetMarker:Hide()
        end
        if self.frame then self.frame:Hide() end
    end
end

function FCB:StartPreviewTimer()
    local duration = C_DurationUtil.CreateDuration()
    duration:SetTimeFromStart(GetTime(), PREVIEW_DURATION)
    self.castBar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate,
        Enum.StatusBarTimerDirection.ElapsedTime)

    self.cachedDuration = duration
    self.positioner:SetMinMaxValues(0, PREVIEW_DURATION)
    self.positioner:SetReverseFill(false)
    self.positioner:SetValue(0)
end

local updateThrottle = 0.1
local updateElapsed = 0

function FCB:OnUpdate(elapsed)
    updateElapsed = updateElapsed + elapsed
    local hasActiveCast = self.casting or self.channeling or self.empowering

    if hasActiveCast then
        local duration = self.castBar:GetTimerDuration()
        if duration and self.cachedDuration then
            self:UpdateTickPosition(duration)
        end
        self:UpdateKickIndicator()
    else
        self.kickTick:SetAlpha(0)
    end

    if updateElapsed < updateThrottle then return end

    if self.holdTimer then
        updateElapsed = 0
        return
    end

    local duration = self.castBar:GetTimerDuration()
    if not duration then
        updateElapsed = 0
        return
    end

    local remaining = duration:GetRemainingDuration()
    if not remaining then
        updateElapsed = 0
        return
    end

    local decimals = duration:EvaluateRemainingDuration(NRSKNUI.curves.DurationDecimals)
    self.time:SetFormattedText('%.' .. decimals .. 'f', remaining)

    if hasActiveCast then
        self:UpdateTargetText()
    end

    if not hasActiveCast then
        self:HideTargetText()
        self:ResetCastState()
        if self.frame then self.frame:Hide() end
    end

    updateElapsed = 0
end

function FCB:EnsureOnUpdate()
    if self.frame and not self.frame:GetScript("OnUpdate") then
        self.frame:SetScript("OnUpdate", function(_, elapsed) self:OnUpdate(elapsed) end)
    end
end

function FCB:ShowPreview()
    if not self.frame then self:CreateFrame() end
    self.isPreview, self.casting = true, true
    self.previewCycle = 0
    self.icon:SetTexture(FALLBACK_ICON)
    self.text:SetText("Focus Castbar")
    self.spark:Show()
    self:UpdateBarColor()
    self:ApplySettings()
    self:StartPreviewTimer()
    self:EnsureOnUpdate()
    self.frame:Show()

    if self.db.ImportantGlow.GlowEnabled then
        self:InitGlow()
        local glowFrame = self:GetGlowFrame()
        if glowFrame then
            glowFrame:SetAlpha(1)
        end
    end

    if self.targetText then
        local name = UnitName("player")
        local classToken = select(2, UnitClass("player"))
        local color = C_ClassColor.GetClassColor(classToken)
        local coloredName = color and color:WrapTextInColorCode(name) or name
        self.targetText:SetText(coloredName)
        if self.targetText.softOutline then
            self.targetText.softOutline:SetShown(true)
            self.targetText.softOutline:SetText(name)
        end
        self.targetText:Show()
    end

    if self.targetMarker then
        local markerSettings = self.db.TargetMarker
        if markerSettings.Enabled then
            SetRaidTargetIconTexture(self.targetMarker, random(1, 8))
            self.targetMarker:Show()
        else
            self.targetMarker:Hide()
        end
    end

    if self.previewTicker then self.previewTicker:Cancel() end
    self.previewTicker = C_Timer.NewTicker(PREVIEW_DURATION, function()
        if not self.isPreview then return end
        if self.previewHoldTimer then return end

        self:ShowPreviewInterrupted()
    end)
end

function FCB:ShowPreviewInterrupted()
    self.casting = false
    self.spark:Hide()
    self.kickTick:SetAlpha(0)
    self.kickCooldownBar:SetValue(0)
    self:HideTargetText()
    self:HideGlow()
    if self.targetMarker then self.targetMarker:Hide() end

    self.castBar:SetMinMaxValues(0, 1)
    self.castBar:SetValue(1)
    self.positioner:SetMinMaxValues(0, 1)
    self.positioner:SetValue(1)
    self.time:SetText("")

    local name = UnitName("player")
    local classToken = select(2, UnitClass("player"))
    local color = classToken and C_ClassColor.GetClassColor(classToken)
    local coloredName = color and color:WrapTextInColorCode(name) or name
    local displayText = INTERRUPTED_BY:format(coloredName)
    local plainText = INTERRUPTED_BY:format(name)

    self.text:SetText(displayText)
    if self.text.softOutline then
        self.text.softOutline:SetShown(true)
        self.text.softOutline:SetText(plainText)
    end

    local holdColor = self.db.HoldTimer.InterruptedColor
    local texture = self.castBar:GetStatusBarTexture()
    texture:SetVertexColor(holdColor[1], holdColor[2], holdColor[3], holdColor[4])

    if self.previewHoldTimer then self.previewHoldTimer:Cancel() end
    self.previewHoldTimer = C_Timer.NewTimer(self.db.HoldTimer.Duration, function()
        self.previewHoldTimer = nil
        if self.isPreview then
            self:StartPreviewCast()
            self.previewCycle = (self.previewCycle or 0) + 1
        end
    end)
end

function FCB:StartPreviewCast()
    self.casting = true
    self.icon:SetTexture(FALLBACK_ICON)
    self.text:SetText("Focus Castbar")
    if self.text.softOutline then
        self.text.softOutline:SetShown(true)
        self.text.softOutline:SetText("Focus Castbar")
    end
    self.spark:Show()
    self:UpdateBarColor()
    self:StartPreviewTimer()

    if self.targetText then
        local name = UnitName("player")
        local classToken = select(2, UnitClass("player"))
        local color = C_ClassColor.GetClassColor(classToken)
        local coloredName = color and color:WrapTextInColorCode(name) or name
        self.targetText:SetText(coloredName)
        if self.targetText.softOutline then
            self.targetText.softOutline:SetShown(true)
            self.targetText.softOutline:SetText(name)
        end
        self.targetText:Show()
    end

    if self.targetMarker then
        local markerSettings = self.db.TargetMarker
        if markerSettings.Enabled then
            SetRaidTargetIconTexture(self.targetMarker, random(1, 8))
            self.targetMarker:Show()
        else
            self.targetMarker:Hide()
        end
    end

    if self.db.ImportantGlow.GlowEnabled then
        self:InitGlow()
        local glowFrame = self:GetGlowFrame()
        if glowFrame then
            glowFrame:SetAlpha(1)
        end
    end
end

function FCB:HidePreview()
    self.isPreview, self.casting = false, nil
    self.previewCycle = nil
    if self.previewTicker then
        self.previewTicker:Cancel()
        self.previewTicker = nil
    end
    if self.previewHoldTimer then
        self.previewHoldTimer:Cancel()
        self.previewHoldTimer = nil
    end
    self:HideTargetText()
    self:ResetGlow()
    if self.kickTick then
        self.kickTick:SetAlpha(0)
    end
    if self.kickCooldownBar then
        self.kickCooldownBar:SetValue(0)
    end
    if self.targetMarker then
        self.targetMarker:Hide()
    end
    if self.frame and not (self.casting or self.channeling or self.empowering) then
        self.frame:Hide()
    end
end

function FCB:OnEnable()
    if not self.db.Enabled then return end
    self:CreateColorObjects()
    self:CreateFrame()
    C_Timer.After(0.5, function()
        self:ApplySettings()
    end)

    local castEvents = {
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_EMPOWER_START",
        "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_STOP",
        "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
        "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    }
    for _, event in ipairs(castEvents) do
        self:RegisterEvent(event, "OnCastEvent")
    end

    self:RegisterEvent("PLAYER_FOCUS_CHANGED")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "CacheInterruptId")
    self:RegisterEvent("LOADING_SCREEN_DISABLED", "CacheInterruptId")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CacheInterruptId")
    self:EnsureOnUpdate()
    self:CacheInterruptId()
    self:ToggleTargetMarkerIntegration()

    EM:Register(self, 'FocusCastbar', self.frame, 'FocusCastbar')
end

function FCB:OnDisable()
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide()
    end
    if self.holdTimer then
        self.holdTimer:Cancel()
        self.holdTimer = nil
    end
    self:HideTargetText()
    self:ResetCastState()
    self.isPreview = false
    self:UnregisterAllEvents()
end

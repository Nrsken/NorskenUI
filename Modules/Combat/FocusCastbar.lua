---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class FocusCastbarModule
local FocusCastbar = NRSKNUI:GetModule('FocusCastbar')
local Anchors = NRSKNUI.Anchors
local LCG = NRSKNUI.Libs.LCG

local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local UnitCastingDuration, UnitChannelDuration = UnitCastingDuration, UnitChannelDuration
local UnitEmpoweredChannelDuration = UnitEmpoweredChannelDuration
local UnitEmpoweredStagePercentages = UnitEmpoweredStagePercentages
local UnitSpellTargetName, UnitSpellTargetClass = UnitSpellTargetName, UnitSpellTargetClass
local UnitNameFromGUID, UnitClassFromGUID = UnitNameFromGUID, UnitClassFromGUID
local GetRaidTargetIndex, SetRaidTargetIconTexture = GetRaidTargetIndex, SetRaidTargetIconTexture
local GetTime, random = GetTime, math.random
local pairs, ipairs, select = pairs, ipairs, select
local unpack = unpack

local CreateDuration = C_DurationUtil and C_DurationUtil.CreateDuration
local GetSpellCooldownDuration = C_Spell and C_Spell.GetSpellCooldownDuration
local IsSpellImportant = C_Spell and C_Spell.IsSpellImportant
local IsSpellKnownOrInSpellBook = C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook
local GetClassColor = C_ClassColor and C_ClassColor.GetClassColor
local EvaluateColorValueFromBoolean = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
local EvaluateColorFromBoolean = C_CurveUtil and C_CurveUtil.EvaluateColorFromBoolean

local Immediate = Enum.StatusBarInterpolation.Immediate
local ElapsedTime = Enum.StatusBarTimerDirection.ElapsedTime
local RemainingTime = Enum.StatusBarTimerDirection.RemainingTime
local PetSpellBank = Enum.SpellBookSpellBank.Pet

local INTERRUPTED = _G.INTERRUPTED

local FALLBACK_ICON = 136243
local INTERRUPTED_BY = 'Interrupted by %s'
local KICK_STATE_THROTTLE = 0.1

local CAST_EVENTS = {
    UNIT_SPELLCAST_START = 'CastStart',
    UNIT_SPELLCAST_CHANNEL_START = 'CastStart',
    UNIT_SPELLCAST_EMPOWER_START = 'CastStart',
    UNIT_SPELLCAST_DELAYED = 'CastUpdate',
    UNIT_SPELLCAST_CHANNEL_UPDATE = 'CastUpdate',
    UNIT_SPELLCAST_EMPOWER_UPDATE = 'CastUpdate',
    UNIT_SPELLCAST_STOP = 'CastStop',
    UNIT_SPELLCAST_CHANNEL_STOP = 'CastStop',
    UNIT_SPELLCAST_EMPOWER_STOP = 'CastStop',
    UNIT_SPELLCAST_FAILED = 'CastFail',
    UNIT_SPELLCAST_INTERRUPTED = 'CastFail',
    UNIT_SPELLCAST_INTERRUPTIBLE = 'CastInterruptible',
    UNIT_SPELLCAST_NOT_INTERRUPTIBLE = 'CastInterruptible',
}

function FocusCastbar:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.FocusCastbar
end

function FocusCastbar:CreateFrame()
    if self.coreFrame then return end

    -- Create the coreFrame and register cast events to it.
    local coreFrame = CreateFrame('Frame', 'NRSKNUI_FocusCastbar', UIParent)
    coreFrame:EnableMouse(false)
    coreFrame:NUICreateBackdrop(true)
    coreFrame:NUISetPixelSnap()
    coreFrame:Hide()
    coreFrame:SetScript('OnEvent', function(_, event, ...) self[CAST_EVENTS[event]](self, event, ...) end)
    self.coreFrame = coreFrame

    -- Main border, rendered above the cast bar and icon, but below the glow.
    local borderFrame = CreateFrame('Frame', nil, coreFrame)
    borderFrame:SetFrameLevel(coreFrame:GetFrameLevel() + 5)
    borderFrame:NUIAddBorders()
    borderFrame:NUISetPixelSnap()
    self.borderFrame = borderFrame

    -- Icon frame with it's own border.
    local iconFrame = CreateFrame('Frame', nil, coreFrame)
    iconFrame:NUIAddBorders()
    iconFrame:NUISetPixelSnap()
    iconFrame.texture = iconFrame:CreateTexture(nil, 'ARTWORK')
    self.iconFrame = iconFrame

    -- Main castbar
    local castBar = CreateFrame('StatusBar', nil, coreFrame)
    castBar:SetMinMaxValues(0, 1)
    castBar:SetValue(0)
    self.castBar = castBar

    -- Create spark
    local spark = castBar:CreateTexture(nil, 'OVERLAY')
    spark:NUISetPixelSnap()
    spark:SetBlendMode('ADD')
    spark:Hide()
    self.spark = spark

    -- Transparent mirror of the cast, its fill edge is what the kick bar anchors to.
    local positioner = CreateFrame('StatusBar', nil, castBar)
    positioner:NUISetPixelSnap()
    positioner:SetStatusBarColor(0, 0, 0, 0)
    positioner:SetMinMaxValues(0, 1)
    positioner:SetValue(0)
    positioner:SetFrameLevel(castBar:GetFrameLevel() + 1)
    self.positioner = positioner

    -- Grows from the cast's current position by the interrupt's remaining cooldown.
    local kickCooldownBar = CreateFrame('StatusBar', nil, castBar)
    kickCooldownBar:NUISetPixelSnap()
    kickCooldownBar:SetStatusBarColor(0, 0, 0, 0)
    kickCooldownBar:SetClipsChildren(true)
    kickCooldownBar:SetMinMaxValues(0, 1)
    kickCooldownBar:SetValue(0)
    kickCooldownBar:SetFrameLevel(castBar:GetFrameLevel() + 4)
    self.kickCooldownBar = kickCooldownBar

    -- Clamps the tick to the bar, so a kick that comes up after the cast ends is not drawn.
    local tickMask = castBar:CreateMaskTexture()
    tickMask:SetTexture('Interface\\BUTTONS\\WHITE8X8', 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')
    self.tickMask = tickMask

    -- Create the tick that indicates when the interrupt is ready and mask it to the cast bar.
    local kickTick = kickCooldownBar:CreateTexture(nil, 'OVERLAY', nil, 7)
    kickTick:NUISetPixelSnap()
    kickTick:SetColorTexture(1, 1, 1, 1)
    kickTick:AddMaskTexture(tickMask)
    kickTick:SetAlpha(0)
    self.kickTick = kickTick

    -- Cast name text.
    local castText = castBar:CreateFontString(nil, 'OVERLAY')
    castText:SetWordWrap(false)
    self.castText = castText

    -- Cast time text.
    local castTimeText = castBar:CreateFontString(nil, 'OVERLAY')
    self.castTimeText = castTimeText

    -- Cast tager text.
    local targetText = castBar:CreateFontString(nil, 'OVERLAY')
    targetText:Hide()
    self.targetText = targetText

    -- Raid marker.
    local targetMarker = castBar:CreateTexture(nil, 'OVERLAY')
    targetMarker:NUISetPixelSnap()
    targetMarker:SetTexture('Interface/TargetingFrame/UI-RaidTargetingIcons')
    targetMarker:Hide()
    self.targetMarker = targetMarker

    -- Built once so the script can be attached and detached per cast without a closure each time.
    self.onUpdate = function(_, elapsed) self:OnUpdate(elapsed) end
    Anchors:Register(self, 'FocusCastbar', coreFrame, 'focusCastbar')
end

function FocusCastbar:ApplySettings()
    if not self.coreFrame then return end

    local barTexture = NRSKNUI:GetStatusbar(self.db)
    local castColor = self.db.CastColor
    local unintColor = self.db.NotInterruptibleColor
    local notReadyColor = self.db.KickIndicator.NotReadyColor
    local kickTickColor = self.db.KickIndicator.TickColor
    local textColor = self.db.TextColor
    local bgColor = self.db.BackdropColor
    local borderColor = self.db.BorderColor
    local w, h = self.db.Width, self.db.Height

    self.durationFormatter = NRSKNUI:GetAuraDurationFormatter()

    self.colCast = NRSKNUI:CreateColor(castColor[1], castColor[2], castColor[3], castColor[4]) --[[@as colorRGBA]]
    self.colUninterruptible = NRSKNUI:CreateColor(unintColor[1], unintColor[2], unintColor[3], unintColor[4]) --[[@as colorRGBA]]
    self.colNotReady = NRSKNUI:CreateColor(notReadyColor[1], notReadyColor[2], notReadyColor[3], notReadyColor[4]) --[[@as colorRGBA]]

    self.coreFrame:NUISetPixelSize(w, h)
    self.coreFrame:SetBackgroundColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    self.coreFrame:SetBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    self.coreFrame:NUIApplyPosition(self.db)

    self.borderFrame:SetAllPoints(self.coreFrame)

    self.iconFrame:NUISetPixelSize(h, h)
    self.iconFrame:NUISetPixelPoint('LEFT', self.coreFrame, 'LEFT', 0, 0)

    self.iconFrame.texture:NUISetPixelInside(self.iconFrame, 1, 1)
    self.iconFrame.texture:NUISetZoom()

    self.castBar:ClearAllPoints()
    self.castBar:NUISetPixelPoint('TOPLEFT', self.coreFrame, 'TOPLEFT', h - 1, -1)
    self.castBar:NUISetPixelPoint('BOTTOMRIGHT', self.coreFrame, 'BOTTOMRIGHT', -1, 1)
    self.castBar:SetStatusBarTexture(barTexture)

    NRSKNUI:SetSpark(self.spark, self.db, h)
    self.spark:SetPoint('CENTER', self.castBar:GetStatusBarTexture(), 'RIGHT', 0, 0)

    self.positioner:SetAllPoints(self.castBar)
    self.positioner:SetStatusBarTexture(barTexture)
    self.positioner:SetStatusBarColor(0, 0, 0, 0)

    self.kickCooldownBar:SetAllPoints(self.castBar)
    self.kickCooldownBar:SetStatusBarTexture(barTexture)
    self.kickCooldownBar:SetStatusBarColor(0, 0, 0, 0)

    self.tickMask:SetAllPoints(self.castBar)

    local tickWidth = self.db.KickIndicator.TickWidth
    self.kickTick:SetShown(tickWidth > 0)
    if tickWidth > 0 then
        self.kickTick:NUISetPixelSize(tickWidth, h - 2)
    end
    self.kickTick:NUISetPixelPoint('CENTER', self.kickCooldownBar:GetStatusBarTexture(), 'RIGHT', 0, 0)
    self.kickTick:SetColorTexture(kickTickColor[1], kickTickColor[2], kickTickColor[3], kickTickColor[4])

    self.castTimeText:SetFontStyle(self.db)
    self.castTimeText:SetFontJustify('RIGHT', self.castBar, -4, 0)
    self.castTimeText:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])

    self.castTimeText:SetWidth(30) -- TODO: Revisit maybe

    self.castText:SetFontStyle(self.db)
    self.castText:SetFontJustify('LEFT', self.castBar, 4, 0, nil, {
        relTo = self.castTimeText,
        point = 'RIGHT',
        relPoint = 'LEFT',
        offsetX = -4,
    })
    self.castText:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])

    self.targetText:SetFontStyle(self.db, self.db.TargetNames.FontSize)
    self.targetText:SetFontJustify(self.db.TargetNames.Anchor, self.coreFrame, self.db.TargetNames.XOffset, self.db.TargetNames.YOffset)

    self.targetMarker:NUISetPixelSize(self.db.TargetMarker.Size, self.db.TargetMarker.Size)
    self.targetMarker:ClearAllPoints()
    self.targetMarker:NUISetPixelPoint(self.db.TargetMarker.Anchor, self.coreFrame, self.db.TargetMarker.Anchor, self.db.TargetMarker.XOffset, self.db.TargetMarker.YOffset)

    self:UpdateVisibility()
    self:UpdateBarColor()
    self:UpdateTargetMarker()

    if self:HasActiveCast() then
        local duration = self.castBar:GetTimerDuration()
        if duration then self:SetupKickBar(duration) end
    end

    if self.isPreview then
        self:ShowPreviewTarget()
        self:ResetGlow()
        self:ShowGlow(true)
    end
end

-- Cast State --

function FocusCastbar:ResetCastState()
    self.casting, self.channeling, self.empowering = nil, nil, nil
    self.castBarID, self.spellID, self.spellName = nil, nil, nil
    self.notInterruptible = false
    self:HidePips()
end

---Use castBarID to check if the event is for the currently running cast.
---@param castBarID number?
---@return boolean
function FocusCastbar:IsCurrentCast(castBarID)
    return self.castBarID ~= nil and self.castBarID == castBarID
end

---@return boolean
function FocusCastbar:HasActiveCast()
    return (self.casting or self.channeling or self.empowering) and true or false
end

---Update the bar's alpha based on the interruptibility of the cast and the user's settings.
function FocusCastbar:UpdateVisibility()
    if self.db.HideNotInterruptible then
        self.coreFrame:SetAlphaFromBoolean(self.notInterruptible, 0, 1)
    else
        self.coreFrame:SetAlpha(1)
    end
end

---With the kick indicator on, an interrupt that is still on cooldown greys the bar out.
function FocusCastbar:UpdateBarColor()
    local texture = self.castBar:GetStatusBarTexture()

    if self.isPreview or not self.db.KickIndicator.Enabled or not self:HasActiveCast() then
        texture:SetVertexColorFromBoolean(self.notInterruptible, self.colUninterruptible, self.colCast)
        return
    end

    -- No interrupt of your own means the cast is never kickable, so it stays in the not ready color.
    local interruptible = self.colNotReady
    if self.interruptCooldown then
        interruptible = EvaluateColorFromBoolean(self.interruptCooldown:IsZero(), self.colCast, self.colNotReady)
    end

    texture:SetVertexColorFromBoolean(self.notInterruptible, self.colUninterruptible, interruptible)
end

-- Kick Indicator --

---Cache the interrupt this character actually has, spec and pet swaps can change it.
function FocusCastbar:CacheInterruptId()
    self.interruptId = nil
    self.interruptCooldown = nil

    local interrupts = NRSKNUI.CLASS_INTERRUPTS[NRSKNUI.MyClassID]
    if not interrupts then return end

    for i = 1, #interrupts do
        local id = interrupts[i]
        if IsSpellKnownOrInSpellBook(id) or IsSpellKnownOrInSpellBook(id, PetSpellBank) then
            self.interruptId = id
            self.interruptCooldown = GetSpellCooldownDuration(id)
            return
        end
    end
end

---A duration is a live view of its window, so it only has to be re-fetched when a new cooldown starts.
function FocusCastbar:SPELL_UPDATE_COOLDOWN()
    if not self.interruptId then return end
    self.interruptCooldown = GetSpellCooldownDuration(self.interruptId)
end

---Setup the kick bar to match the cast's duration and direction and scale the tick to the interrupt's cooldown.
---@param duration LuaDurationObject
function FocusCastbar:SetupKickBar(duration)
    local isChannel = self.channeling == true
    local total = duration:GetTotalDuration()

    self.positioner:SetReverseFill(isChannel)
    self.positioner:SetMinMaxValues(0, total)
    self.positioner:SetValue(duration:GetElapsedDuration()) -- 0 at cast start, correct on a re-setup

    if not self.db.KickIndicator.Enabled or not self.interruptId then
        self.kickTick:SetAlpha(0)
        return
    end

    self.kickCooldownBar:ClearAllPoints()
    self.kickCooldownBar:SetSize(self.castBar:GetSize())
    self.kickCooldownBar:SetReverseFill(isChannel)
    self.kickCooldownBar:SetMinMaxValues(0, total)

    self.kickTick:ClearAllPoints()

    -- A channel drains right to left, so both anchors mirror.
    if isChannel then
        self.kickCooldownBar:SetPoint('RIGHT', self.positioner:GetStatusBarTexture(), 'LEFT')
        self.kickTick:SetPoint('RIGHT', self.kickCooldownBar:GetStatusBarTexture(), 'LEFT')
    else
        self.kickCooldownBar:SetPoint('LEFT', self.positioner:GetStatusBarTexture(), 'RIGHT')
        self.kickTick:SetPoint('LEFT', self.kickCooldownBar:GetStatusBarTexture(), 'RIGHT')
    end
end

---The cached cooldown feeds the tick's position, its visibility and the bar color.
---@param duration LuaDurationObject The running cast
---@param elapsed number
function FocusCastbar:UpdateKick(duration, elapsed)
    self.positioner:SetValue(duration:GetElapsedDuration())

    if self.isPreview then return end
    if not self.db.KickIndicator.Enabled then return end

    local cooldown = self.interruptCooldown
    if not cooldown then return end

    -- Both bars drive where the tick sits, so they stay per frame. On a throttle the tick jiggles.
    self.kickCooldownBar:SetValue(cooldown:GetRemainingDuration())

    -- The tick's visibility and the bar color only move when the interrupt's readiness does, so they ride a throttle.
    self.kickElapsed = self.kickElapsed + elapsed
    if self.kickElapsed < KICK_STATE_THROTTLE then return end
    self.kickElapsed = 0

    -- A ready interrupt needs no tick and an uninterruptible cast hides it either way.
    self.kickTick:SetAlphaFromBoolean(cooldown:IsZero(), 0,
        EvaluateColorValueFromBoolean(self.notInterruptible, 0, 1))

    self:UpdateBarColor()
end

-- Empowered stage separators, created on demand and reused across casts.

---@param index number
---@return Texture
function FocusCastbar:GetPip(index)
    local pip = self.pips[index]
    if not pip then
        pip = self.castBar:CreateTexture(nil, 'OVERLAY', nil, 2)
        pip:SetColorTexture(0, 0, 0, 1)
        pip:NUISetPixelSnap()
        self.pips[index] = pip
    end
    return pip
end

-- Update the pips to match the current empowered stage percentages or hide them if the cast is not empowered.
function FocusCastbar:UpdatePips()
    local stages = UnitEmpoweredStagePercentages('focus')
    if not stages then return end

    local width = self.castBar:GetWidth()
    local offset = 0

    for index = 1, #stages - 1 do
        offset = offset + width * stages[index]

        local pip = self:GetPip(index)
        pip:NUISetPixelWidth(2)
        pip:ClearAllPoints()
        pip:NUISetPixelPoint('TOP', self.castBar, 'TOPLEFT', offset, 0)
        pip:NUISetPixelPoint('BOTTOM', self.castBar, 'BOTTOMLEFT', offset, 0)
        pip:Show()
    end
end

function FocusCastbar:HidePips()
    for _, pip in ipairs(self.pips) do
        pip:Hide()
    end
end

-- Spell Target --

-- The target name is only available while the cast is active, so it is updated on each cast event.
function FocusCastbar:UpdateTargetText()
    if self.isPreview then return end

    local name = UnitSpellTargetName('focus')
    if name == nil then
        self.targetText:Hide()
        return
    end

    self.targetText:SetText(name)

    local class = UnitSpellTargetClass('focus')
    local color = class ~= nil and GetClassColor(class)
    if color then
        self.targetText:SetTextColor(color:GetRGB())
    else
        local text = self.db.TextColor
        self.targetText:SetTextColor(text[1], text[2], text[3], text[4])
    end

    self.targetText:Show()
end

function FocusCastbar:UpdateTargetMarker()
    if self.isPreview then return end

    if not self.db.TargetMarker.Enabled then
        self.targetMarker:Hide()
        return
    end

    local index = GetRaidTargetIndex('focus')
    if index == nil then
        self.targetMarker:Hide()
        return
    end

    SetRaidTargetIconTexture(self.targetMarker, index)
    self.targetMarker:Show()
end

function FocusCastbar:RAID_TARGET_UPDATE()
    self:UpdateTargetMarker()
end

-- Important Spell Glow --

---@return Frame?
function FocusCastbar:GetGlowFrame()
    if self.db.ImportantGlow.GlowType == 'autocast' then
        return self.coreFrame._AutoCastGlow
    end
    return self.coreFrame._PixelGlow
end

---The glow is started once and then driven by alpha, restarting it per cast would restart the animation and leak a second glow frame of the other type.
function FocusCastbar:InitGlow()
    if self.glowInitialized then return end

    local glow = self.db.ImportantGlow
    if glow.GlowType == 'autocast' then
        LCG.AutoCastGlow_Start(self.coreFrame, glow.GlowColor, glow.GlowLines, glow.GlowFrequency, glow.GlowScale, 1, 1)
    else
        LCG.PixelGlow_Start(self.coreFrame, glow.GlowColor, glow.GlowLines, glow.GlowFrequency, glow.GlowLength,
            glow.GlowThickness, 0, 0, glow.GlowBorder)
    end

    local glowFrame = self:GetGlowFrame()
    if glowFrame then glowFrame:SetAlpha(0) end

    self.glowInitialized = true
end

---@param isImportant boolean May be a secret, so it only ever reaches SetAlphaFromBoolean.
function FocusCastbar:ShowGlow(isImportant)
    if not self.db.ImportantGlow.GlowEnabled then return end

    self:InitGlow()

    local glowFrame = self:GetGlowFrame()
    if glowFrame then glowFrame:SetAlphaFromBoolean(isImportant, 1, 0) end
end

function FocusCastbar:HideGlow()
    local glowFrame = self:GetGlowFrame()
    if glowFrame then glowFrame:SetAlpha(0) end
end

---Called by the GUI whenever a glow setting changes, the next ShowGlow rebuilds it.
function FocusCastbar:ResetGlow()
    if not self.coreFrame then return end

    LCG.PixelGlow_Stop(self.coreFrame)
    LCG.AutoCastGlow_Stop(self.coreFrame)
    self.glowInitialized = false
end

-- Cast Events --

function FocusCastbar:CastStart()
    if self.isPreview then return end -- a live cast must not fight the preview loop for the bar

    self:ResetCastState()

    local _, isEmpowered, duration, direction
    local name, displayName, texture, notInterruptible, spellID, castBarID

    name, displayName, texture, _, _, _, _, notInterruptible, spellID, castBarID = UnitCastingInfo('focus')
    if name then
        self.casting = true
        duration, direction = UnitCastingDuration('focus'), ElapsedTime
    else
        name, displayName, texture, _, _, _, notInterruptible, spellID, isEmpowered, _, castBarID = UnitChannelInfo('focus')
        if isEmpowered then
            self.empowering = true
            duration, direction = UnitEmpoweredChannelDuration('focus'), ElapsedTime
        elseif name then
            self.channeling = true
            duration, direction = UnitChannelDuration('focus'), RemainingTime
        end
    end

    if not name then
        -- Swapping focus mid-hold must not cut the hold short.
        if not self.holdTimer then
            self:HideAll()
        end
        return
    end

    if notInterruptible == nil then
        notInterruptible = false
    end

    if self.holdTimer then
        self.holdTimer:Cancel()
        self.holdTimer = nil
    end

    self.castBarID, self.spellID, self.spellName = castBarID, spellID, displayName
    self.notInterruptible = notInterruptible
    self.textElapsed = 0
    self.kickElapsed = 0

    self.castBar:SetTimerDuration(duration, Immediate, direction)
    self.iconFrame.texture:SetTexture(texture or FALLBACK_ICON)
    self.castText:SetText(displayName)
    self.castTimeText:SetText('')
    self.spark:Show()

    if self.empowering then
        self:UpdatePips()
    end

    self:SetupKickBar(duration)
    self:UpdateVisibility()
    self:UpdateBarColor()
    self:UpdateTargetText()
    self:UpdateTargetMarker()

    if spellID ~= nil then
        self:ShowGlow(IsSpellImportant(spellID))
    else
        self:HideGlow()
    end

    self.coreFrame:SetScript('OnUpdate', self.onUpdate)
    self.coreFrame:Show()
end

---Pushback, channel clipping and empower extensions all re-issue the duration for the running cast.
function FocusCastbar:CastUpdate(event, unit, castGUID, spellID, castBarID)
    if not self:IsCurrentCast(castBarID) then return end

    local duration, direction
    if event == 'UNIT_SPELLCAST_DELAYED' then
        duration, direction = UnitCastingDuration('focus'), ElapsedTime
    elseif event == 'UNIT_SPELLCAST_EMPOWER_UPDATE' then
        duration, direction = UnitEmpoweredChannelDuration('focus'), ElapsedTime
    else
        duration, direction = UnitChannelDuration('focus'), RemainingTime
    end

    if not duration then return end

    self.castBar:SetTimerDuration(duration, Immediate, direction)
    self:SetupKickBar(duration) -- the total changed, so the kick chain has to be re-scaled

    if self.empowering then
        self:UpdatePips()
    end
end

function FocusCastbar:CastStop(event, unit, castGUID, spellID, a, b, c)
    local interruptedBy, castBarID
    if event == 'UNIT_SPELLCAST_EMPOWER_STOP' then
        interruptedBy, castBarID = b, c -- complete, interruptedBy, castBarID
    elseif event == 'UNIT_SPELLCAST_CHANNEL_STOP' then
        interruptedBy, castBarID = a, b
    else
        castBarID = a
    end

    if not self:IsCurrentCast(castBarID) then return end
    self:FinishCast(interruptedBy)
end

function FocusCastbar:CastFail(event, unit, castGUID, spellID, a, b)
    local interruptedBy, castBarID
    if event == 'UNIT_SPELLCAST_INTERRUPTED' then
        interruptedBy, castBarID = a, b
    else
        castBarID = a
    end

    if not self:IsCurrentCast(castBarID) then return end
    self:FinishCast(interruptedBy, true)
end

---The payload carries no cast id, so the flag comes from the event itself instead of a re-query.
function FocusCastbar:CastInterruptible(event)
    if not self.castBarID then return end

    self.notInterruptible = event == 'UNIT_SPELLCAST_NOT_INTERRUPTIBLE'
    self:UpdateVisibility()
    self:UpdateBarColor()
end

---@param interruptedBy string? GUID of the interrupter, nil for a clean stop or a plain failure
---@param failed boolean?
function FocusCastbar:FinishCast(interruptedBy, failed)
    local hold = self.db.HoldTimer

    self.coreFrame:SetScript('OnUpdate', nil)
    self.spark:Hide()
    self.kickTick:SetAlpha(0)
    self.targetText:Hide()
    self:HideGlow()
    self:ResetCastState()

    if not hold.Enabled then
        self:HideAll()
        return
    end

    -- An explicit value takes the bar off its timer, so it stays filled for the hold.
    self.castBar:SetMinMaxValues(0, 1)
    self.castBar:SetValue(1)
    self.positioner:SetMinMaxValues(0, 1)
    self.positioner:SetValue(1)
    self.castTimeText:SetText('')

    self.holdTimer = C_Timer.NewTimer(hold.Duration, function()
        self.holdTimer = nil
        self:HideAll()
    end)

    local color
    if interruptedBy ~= nil then
        self:SetInterruptText(interruptedBy)
        color = hold.InterruptedColor
    else
        color = failed and hold.InterruptedColor or hold.SuccessColor
    end

    self.castBar:GetStatusBarTexture():SetVertexColor(color[1], color[2], color[3], color[4])
end

function FocusCastbar:SetInterruptText(interruptedBy)
    if interruptedBy ~= nil then
        local name = UnitNameFromGUID(interruptedBy)
        local class = select(2, UnitClassFromGUID(interruptedBy))
        local color = (class and GetClassColor(class)) or NRSKNUI.Colors.white
        name = color:WrapTextInColorCode(name)

        self.castText:SetFormattedText(INTERRUPTED_BY, name)
    end
end

function FocusCastbar:PLAYER_FOCUS_CHANGED()
    if UnitExists('focus') then
        self:CastStart()
        return
    end

    self:ResetCastState()
    self:HideAll()
end

function FocusCastbar:HideAll()
    if self.holdTimer then
        self.holdTimer:Cancel()
        self.holdTimer = nil
    end

    self.coreFrame:SetScript('OnUpdate', nil)
    self.targetText:Hide()
    self.targetMarker:Hide()
    self.kickTick:SetAlpha(0)
    self:HideGlow()
    self.coreFrame:Hide()
end

-- Update Loop --

function FocusCastbar:UpdateTimeText()
    local duration = self.castBar:GetTimerDuration()
    if not duration then return end

    self.castTimeText:SetText(duration:FormatRemainingDuration(self.durationFormatter))
end

---Only attached while a cast runs. The bar's own timer draws the cast progress, the kick ready indicator tracks
---it every frame, the text and the spell target only need the throttle, doing it this way to avoid kick ready indicator being too jumpy.
local TEXT_THROTTLE = 0.1
function FocusCastbar:OnUpdate(elapsed)
    local duration = self.castBar:GetTimerDuration()
    if duration then
        self:UpdateKick(duration, elapsed)
    end

    self.textElapsed = self.textElapsed + elapsed
    if self.textElapsed >= TEXT_THROTTLE then
        self.textElapsed = 0
        self:UpdateTimeText()
        self:UpdateTargetText()
    end
end

function FocusCastbar:OnEnable()
    self.textElapsed = 0
    self.kickElapsed = 0
    self.pips = {}
    self:ResetCastState()

    self:CreateFrame()
    self:ApplySettings()

    for event in pairs(CAST_EVENTS) do
        self.coreFrame:RegisterUnitEvent(event, 'focus')
    end

    self:RegisterEvent('PLAYER_FOCUS_CHANGED')
    self:RegisterEvent('RAID_TARGET_UPDATE')
    self:RegisterEvent('SPELL_UPDATE_COOLDOWN')
    self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED', 'CacheInterruptId')
    self:RegisterEvent('PLAYER_ENTERING_WORLD', 'CacheInterruptId')

    self:CacheInterruptId()
    self:CastStart()
end

function FocusCastbar:OnDisable()
    self:ResetCastState()
    self.isPreview = false

    if self.previewTimer then
        self.previewTimer:Cancel()
        self.previewTimer = nil
    end

    if self.coreFrame then
        self.coreFrame:UnregisterAllEvents()
        self:ResetGlow()
        self:HideAll()
    end
end

-- Preview --

---Runs a fake cast on a loop while the GUI or Edit Mode is open, so every setting can be seen.
function FocusCastbar:ShowPreview()
    if not self.coreFrame then
        self:CreateFrame()
        self:ApplySettings()
    end

    self.isPreview = true
    self:StartPreviewCast()
end

function FocusCastbar:StartPreviewCast()
    local duration = CreateDuration()
    duration:SetTimeFromStart(GetTime(), 20)

    self.casting = true
    self.channeling, self.empowering = nil, nil
    self.notInterruptible = false
    self.textElapsed = 0
    self.kickElapsed = 0

    self.castBar:SetTimerDuration(duration, Immediate, ElapsedTime)
    self.iconFrame.texture:SetTexture(FALLBACK_ICON)
    self.castText:SetText('Focus Castbar')
    self.spark:Show()
    self:SetupKickBar(duration)
    self:UpdateVisibility()
    self:UpdateBarColor()

    self:ShowPreviewTarget()
    self:ShowGlow(true)
    self.coreFrame:SetScript('OnUpdate', self.onUpdate)
    self.coreFrame:Show()

    self.previewTimer = C_Timer.NewTimer(20, function() self:PreviewInterrupt() end)
end

---The player stands in for a spell target. Kept separate so a settings change mid preview re-applies it without waiting for the next cycle.
function FocusCastbar:ShowPreviewTarget()
    self.targetText:SetText(NRSKNUI.MyName)
    self.targetText:SetTextColor(unpack(NRSKNUI:GetPlayerClassColor()))
    self.targetText:Show()

    if self.db.TargetMarker.Enabled then
        SetRaidTargetIconTexture(self.targetMarker, random(1, 8))
        self.targetMarker:Show()
    else
        self.targetMarker:Hide()
    end
end

---Second half of the loop, shows what an interrupted cast looks like before starting over.
function FocusCastbar:PreviewInterrupt()
    if not self.isPreview then return end

    self.casting = nil
    self.coreFrame:SetScript('OnUpdate', nil)
    self.spark:Hide()
    self.kickTick:SetAlpha(0)
    self.targetText:Hide()
    self:HideGlow()

    self.castBar:SetMinMaxValues(0, 1)
    self.castBar:SetValue(1)
    self.castTimeText:SetText('')

    local color = self.db.HoldTimer.InterruptedColor
    self.castBar:GetStatusBarTexture():SetVertexColor(color[1], color[2], color[3], color[4])
    self.castText:SetText(INTERRUPTED)

    self.previewTimer = C_Timer.NewTimer(self.db.HoldTimer.Duration, function()
        if self.isPreview then self:StartPreviewCast() end
    end)
end

function FocusCastbar:HidePreview()
    if not self.isPreview then return end

    self.isPreview = false

    if self.previewTimer then
        self.previewTimer:Cancel()
        self.previewTimer = nil
    end

    self:ResetGlow()
    self:ResetCastState()
    self:HideAll()
    self:CastStart() -- fall straight back onto a real cast if the focus has one
end

-- NorskenUI namespace
---@class NRSKNUI
---@diagnostic disable: undefined-field
local NRSKNUI = select(2, ...)

-- Check for addon object
if not NorskenUI then
    error("FocusCastbar: Addon object not initialized. Check file load order!")
    return
end

-- Create module
---@class FocusCastbar: AceModule, AceEvent-3.0
local FCB = NorskenUI:NewModule("FocusCastbar", "AceEvent-3.0")

-- Localization
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
local GetNumGroupMembers = GetNumGroupMembers
local IsInGroup = IsInGroup
local UnitIsSpellTarget = UnitIsSpellTarget
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local ipairs = ipairs
local type = type

-- Module locals
local FALLBACK_ICON = 136243
local INTERRUPTED = "Interrupted"
local INTERRUPTED_BY = "Interrupted by %s"
local PREVIEW_DURATION = 20
local MAX_TARGET_NAMES = 5

-- Class interrupt spell IDs
local CLASS_INTERRUPTS = {
    [1] = { 6552 },                         -- Warrior
    [2] = { 31935, 96231 },                 -- Paladin
    [3] = { 147362, 187707 },               -- Hunter
    [4] = { 1766 },                         -- Rogue
    [5] = { 15487 },                        -- Priest
    [6] = { 47528 },                        -- Death Knight
    [7] = { 57994 },                        -- Shaman
    [8] = { 2139 },                         -- Mage
    [9] = { 19647, 89766, 119910, 132409 }, -- Warlock
    [10] = { 116705 },                      -- Monk
    [11] = { 78675, 106839 },               -- Druid
    [12] = { 183752 },                      -- Demon Hunter
    [13] = { 351338 },                      -- Evoker
}

-- Update db, used for profile changes
function FCB:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.FocusCastbar
end

-- Module init
function FCB:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

-- Create pre-cached color objects
function FCB:CreateColorObjects()
    local kick = self.db.KickIndicator or {}
    local ready = kick.ReadyColor or { 0.1, 0.8, 0.1, 1 }
    local notReady = kick.NotReadyColor or { 0.5, 0.5, 0.5, 1 }
    local uninterruptible = self.db.NotInterruptibleColor or { 0.7, 0.7, 0.7, 1 }
    self.colors = {
        Ready = CreateColor(ready[1], ready[2], ready[3]),
        NotReady = CreateColor(notReady[1], notReady[2], notReady[3]),
        Uninterruptible = CreateColor(uninterruptible[1], uninterruptible[2], uninterruptible[3]),
    }
end

-- Reset cast state
function FCB:ResetCastState()
    self.casting, self.channeling, self.empowering = nil, nil, nil
    self.castID, self.spellID, self.spellName = nil, nil, nil
    self.notInterruptible = nil
    self.cachedDuration = nil
end

-- Create castbar frame
function FCB:CreateFrame()
    if self.frame then return end
    local db = self.db
    local parent = NRSKNUI:ResolveAnchorFrame(db.anchorFrameType, db.ParentFrame)
    local height = db.Height or 20

    -- Main container with backdrop
    local frame = NRSKNUI:CreateStandardBackdrop(parent, "NRSKNUI_FocusCastbarFrame", 100,
        { 0, 0, 0, 0.8 }, { 0, 0, 0, 1 })
    frame:SetSize(db.Width or 200, height)
    frame:SetPoint(db.Position.AnchorFrom or "CENTER", parent, db.Position.AnchorTo or "CENTER",
        db.Position.XOffset or 0, db.Position.YOffset or 200)
    frame:SetFrameStrata(db.Strata or "HIGH")
    frame:EnableMouse(false)
    frame:Hide()

    -- Icon frame with backdrop
    local iconFrame = NRSKNUI:CreateStandardBackdrop(frame, nil, nil, { 0, 0, 0, 0.8 }, { 0, 0, 0, 1 })
    iconFrame:SetSize(height, height)
    iconFrame:SetPoint("LEFT", frame, "LEFT", 0, 0)

    -- Icon texture with zoom
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    NRSKNUI:ApplyZoom(icon, 0.3)

    -- Castbar
    local castBar = CreateFrame("StatusBar", nil, frame)
    castBar:SetPoint("LEFT", iconFrame, "RIGHT", 0, 0)
    castBar:SetPoint("RIGHT", frame, "RIGHT", -1, 0)
    castBar:SetPoint("TOP", frame, "TOP", 0, -1)
    castBar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 1)
    castBar:SetStatusBarTexture(NRSKNUI:GetStatusbarPath(db.StatusBarTexture))
    castBar:SetMinMaxValues(0, 1)
    castBar:SetValue(0)

    -- Spark
    local spark = castBar:CreateTexture(nil, "OVERLAY")
    spark:SetSize(12, height)
    spark:SetBlendMode("ADD")
    spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
    spark:SetPoint("CENTER", castBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    spark:Hide()

    -- Invisible positioner for tick
    local positioner = CreateFrame("StatusBar", nil, castBar)
    positioner:SetAllPoints(castBar)
    positioner:SetStatusBarTexture(NRSKNUI:GetStatusbarPath(db.StatusBarTexture))
    positioner:SetStatusBarColor(0, 0, 0, 0)
    positioner:SetMinMaxValues(0, 1)
    positioner:SetValue(0)
    positioner:SetFrameLevel(castBar:GetFrameLevel() + 1)

    -- Kick cooldown bar
    local kickCooldownBar = CreateFrame("StatusBar", nil, castBar)
    kickCooldownBar:SetAllPoints(castBar)
    kickCooldownBar:SetStatusBarTexture(NRSKNUI:GetStatusbarPath(db.StatusBarTexture))
    kickCooldownBar:SetStatusBarColor(0, 0, 0, 0)
    kickCooldownBar:SetClipsChildren(true)
    kickCooldownBar:SetMinMaxValues(0, 1)
    kickCooldownBar:SetValue(0)
    kickCooldownBar:SetFrameLevel(castBar:GetFrameLevel() + 4)

    -- Mask texture to clip tick at castbar bounds
    local tickMask = castBar:CreateMaskTexture()
    tickMask:SetAllPoints(castBar)
    tickMask:SetTexture("Interface\\BUTTONS\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    -- Tick texture
    local kickTick = kickCooldownBar:CreateTexture(nil, "OVERLAY", nil, 7)
    kickTick:SetSize(2, height)
    kickTick:SetColorTexture(1, 1, 1, 1)
    kickTick:SetPoint("CENTER", kickCooldownBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    kickTick:AddMaskTexture(tickMask)
    kickTick:SetAlpha(0)

    -- Text elements
    local text = castBar:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", castBar, "LEFT", 4, 0)
    text:SetJustifyH("LEFT")
    NRSKNUI:ApplyFont(text, db.FontFace, db.FontSize, db.FontOutline)

    local time = castBar:CreateFontString(nil, "OVERLAY")
    time:SetPoint("RIGHT", castBar, "RIGHT", -4, 0)
    time:SetJustifyH("RIGHT")
    NRSKNUI:ApplyFont(time, db.FontFace, db.FontSize, db.FontOutline)

    -- Target name text
    local targetNames = {}
    for i = 1, MAX_TARGET_NAMES do
        local targetText = frame:CreateFontString(nil, "OVERLAY", nil)
        targetText:SetParent(castBar)
        targetText:SetAlpha(0)
        targetNames[i] = targetText
    end

    -- Store references
    self.positioner = positioner
    self.frame, self.iconFrame, self.icon = frame, iconFrame, icon
    self.castBar, self.spark = castBar, spark
    self.kickCooldownBar, self.kickTick = kickCooldownBar, kickTick
    self.text, self.time = text, time
    self.targetNames = targetNames
    self.holdTimer = nil

    self:ApplySettings()
end

-- Apply visual settings
function FCB:ApplySettings()
    if not self.frame then return end
    self:CreateColorObjects()

    local db = self.db
    local bgColor = db.BackdropColor or { 0, 0, 0, 0.8 }
    local borderColor = db.BorderColor or { 0, 0, 0, 1 }
    local textColor = db.TextColor or { 1, 1, 1, 1 }
    local kickColors = db.KickIndicator or {}

    self.frame:SetSize(db.Width or 200, db.Height)
    self.frame:SetBackgroundColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.8)
    self.frame:SetBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    self.frame:SetFrameStrata(db.Strata or "HIGH")

    self.iconFrame:SetSize(db.Height, db.Height)
    self.iconFrame:SetBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)

    local texturePath = NRSKNUI:GetStatusbarPath(db.StatusBarTexture)
    self.castBar:SetStatusBarTexture(texturePath)
    self.positioner:SetStatusBarTexture(texturePath)
    self.kickCooldownBar:SetStatusBarTexture(texturePath)
    self.spark:SetSize(12, db.Height)

    -- Kick tick settings
    self.kickTick:SetSize(2, db.Height)
    local tickColor = kickColors.TickColor or { 1, 1, 1, 1 }
    self.kickTick:SetColorTexture(tickColor[1], tickColor[2], tickColor[3], tickColor[4] or 1)

    NRSKNUI:ApplyFont(self.text, db.FontFace, db.FontSize, db.FontOutline)
    NRSKNUI:ApplyFont(self.time, db.FontFace, db.FontSize, db.FontOutline)
    self.text:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
    self.time:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)

    -- Target name stuff
    if self.targetNames then
        local targetSettings = db.TargetNames or {}
        local anchorPoint = NRSKNUI:GetTextPointFromAnchor(targetSettings.Anchor)
        for i = 1, MAX_TARGET_NAMES do
            local targetText = self.targetNames[i]
            targetText:ClearAllPoints()
            targetText:SetPoint(anchorPoint, self.frame, anchorPoint, targetSettings.XOffset, targetSettings.YOffset)
            targetText:SetJustifyH(anchorPoint)
            NRSKNUI:ApplyFont(targetText, db.FontFace, targetSettings.FontSize, db.FontOutline)
        end
    end

    self:ApplyPosition()
end

-- Apply position
function FCB:ApplyPosition()
    if not self.frame then return end
    NRSKNUI:ApplyFramePosition(self.frame, self.db.Position, self.db, true)
end

-- Update bar color based on kick ready state
function FCB:UpdateBarColor(interruptDuration)
    if not self.castBar then return end
    local kick = self.db.KickIndicator
    local texture = self.castBar:GetStatusBarTexture()
    local hasActiveCast = self.casting or self.channeling or self.empowering

    -- Skip kick indicator in preview mode
    if self.isPreview then
        local color = self.db.CastingColor or { 1, 0.7, 0, 1 }
        texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        return
    end

    -- Kick indicator with interrupt spell and active cast
    if kick and kick.Enabled and self.interruptId and hasActiveCast then
        local cooldown = interruptDuration or C_Spell.GetSpellCooldownDuration(self.interruptId)
        if not cooldown then return end

        -- Use EvaluateColorFromBoolean to avoid creating color objects each frame
        local interruptibleColor = C_CurveUtil.EvaluateColorFromBoolean(
            cooldown:IsZero(),
            self.colors.Ready,
            self.colors.NotReady
        )
        texture:SetVertexColorFromBoolean(self.notInterruptible, self.colors.Uninterruptible, interruptibleColor)
        return
    end

    -- Kick indicator enabled but no interrupt spell
    if kick and kick.Enabled and hasActiveCast then
        texture:SetVertexColorFromBoolean(self.notInterruptible, self.colors.Uninterruptible, self.colors.NotReady)
        return
    end

    -- Fallback to regular colors
    local color = self.channeling and (self.db.ChannelingColor or { 0, 0.7, 1, 1 })
        or self.empowering and (self.db.EmpoweringColor or { 0.8, 0.4, 1, 1 })
        or (self.db.CastingColor or { 1, 0.7, 0, 1 })
    texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
end

-- Detect and cache interrupt spell ID
function FCB:CacheInterruptId()
    local playerClass = select(3, UnitClass("player"))
    local interrupts = CLASS_INTERRUPTS[playerClass]
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

-- Update kick indicator tick visibility and bar color
function FCB:UpdateKickIndicator()
    local kick = self.db.KickIndicator
    if not kick or not kick.Enabled or not self.interruptId then
        self.kickTick:SetAlpha(0)
        return
    end

    -- Skip in preview mode
    if self.isPreview then
        self.kickTick:SetAlpha(0)
        return
    end

    local cooldown = C_Spell.GetSpellCooldownDuration(self.interruptId)
    if not cooldown then return end

    self.kickTick:SetAlphaFromBoolean(cooldown:IsZero(), 0,
        C_CurveUtil.EvaluateColorValueFromBoolean(self.notInterruptible, 0, 1))

    self:UpdateBarColor(cooldown)
end

-- Update tick position based on interrupt cooldown
function FCB:UpdateTickPosition(duration)
    local kick = self.db.KickIndicator
    if not kick or not kick.Enabled or not self.interruptId then return end

    -- Update positioner to match cast progress
    self.positioner:SetValue(duration:GetElapsedDuration())

    -- Update kick cooldown bar value based on interrupt cooldown remaining
    local cooldown = C_Spell.GetSpellCooldownDuration(self.interruptId)
    if not cooldown then return end

    -- GetRemainingDuration returns 0 when cooldown is ready
    self.kickCooldownBar:SetValue(cooldown:GetRemainingDuration())
end

-- Update target name display
function FCB:UpdateTargetNames()
    if not self.targetNames then return end
    if self.isPreview then return end

    -- Hide all first
    for i = 1, MAX_TARGET_NAMES do
        self.targetNames[i]:SetAlpha(0)
    end

    if not UnitExists("focus") then return end
    if not (self.casting or self.channeling or self.empowering) then return end

    if IsInGroup() then
        local numMembers = GetNumGroupMembers()
        for i = 1, math.min(numMembers, MAX_TARGET_NAMES) do
            local unit = i == numMembers and "player" or ("party" .. i)
            local name = UnitName(unit)
            local targetText = self.targetNames[i]

            if name then
                local classToken = select(2, UnitClass(unit))
                targetText:SetText(NRSKNUI:ColorTextByClass(name, classToken))
                targetText:SetAlphaFromBoolean(UnitIsSpellTarget("focus", unit), 1, 0)
            end
        end
    else
        local name = UnitName("player")
        local classToken = select(2, UnitClass("player"))
        self.targetNames[1]:SetText(NRSKNUI:ColorTextByClass(name, classToken))
        self.targetNames[1]:SetAlphaFromBoolean(UnitIsSpellTarget("focus", "player"), 1, 0)
    end
end

-- Hide all target names
function FCB:HideTargetNames()
    if not self.targetNames then return end
    for i = 1, MAX_TARGET_NAMES do
        self.targetNames[i]:SetAlpha(0)
    end
end

-- Get colored name from GUID
function FCB:GetColoredNameFromGUID(guid)
    if guid == nil then return nil end

    local _, classToken, _, _, _, name = GetPlayerInfoByGUID(guid)
    if name == nil then return nil end
    if type(classToken) ~= "string" then return name end

    local color = C_ClassColor.GetClassColor(classToken)
    if color == nil then return name end

    return color:WrapTextInColorCode(name)
end

-- Setup kick cooldown bar direction based on cast type
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

-- Cast events
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

-- Start displaying a cast
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
end

-- End cast (stop, fail, or interrupt)
function FCB:EndCast(showHold, wasInterrupted, interruptedBy)
    if not self.frame or not self.frame:IsShown() then return end
    if self.holdTimer then return end -- Already in hold state

    local holdSettings = self.db.HoldTimer
    if not holdSettings or not holdSettings.Enabled then
        self.spark:Hide()
        self:HideTargetNames()
        self:ResetCastState()
        self.frame:Hide()
        return
    end

    -- Show hold state
    self.spark:Hide()
    self.kickTick:SetAlpha(0)
    self:HideTargetNames()

    self.castBar:SetMinMaxValues(0, 1)
    self.castBar:SetValue(1)
    self.positioner:SetMinMaxValues(0, 1)
    self.positioner:SetValue(1)
    self.time:SetText("")

    local texture = self.castBar:GetStatusBarTexture()
    if wasInterrupted then
        -- Show who interrupted
        local interrupterName = interruptedBy and self:GetColoredNameFromGUID(interruptedBy)
        if interrupterName then
            self.text:SetText(INTERRUPTED_BY:format(interrupterName))
        else
            self.text:SetText(INTERRUPTED)
        end
        local color = holdSettings.InterruptedColor or { 0.1, 0.8, 0.1, 1 }
        texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    elseif showHold then
        -- Failed cast, keep spell name, just change color
        local color = holdSettings.FailedColor or { 0.5, 0.5, 0.5, 1 }
        texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    else
        -- Completed cast
        local color = holdSettings.SuccessColor or { 0.8, 0.1, 0.1, 1 }
        texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    end

    self:ResetCastState()

    local duration = holdSettings.Duration or 0.5
    self.holdTimer = C_Timer.NewTimer(duration, function()
        self.holdTimer = nil
        if self.frame and not (self.casting or self.channeling or self.empowering) then
            self.frame:Hide()
        end
    end)
end

-- Update interruptible state mid-cast
function FCB:UpdateInterruptible()
    if not self.frame or not self.frame:IsShown() then return end
    local notInterruptible = select(8, UnitCastingInfo("focus")) or select(7, UnitChannelInfo("focus"))
    self.notInterruptible = notInterruptible

    -- Hide non-interruptible casts if enabled
    if self.db.HideNotInterruptible then
        self.frame:SetAlphaFromBoolean(notInterruptible, 0, 1)
    end

    self:UpdateBarColor()
end

-- Focus changed handler
function FCB:PLAYER_FOCUS_CHANGED()
    if UnitExists("focus") then
        self:StartCast()
    else
        self:HideTargetNames()
        self:ResetCastState()
        if self.holdTimer then
            self.holdTimer:Cancel()
            self.holdTimer = nil
        end
        if self.frame then self.frame:Hide() end
    end
end

-- Start preview cast timer
function FCB:StartPreviewTimer()
    local duration = C_DurationUtil.CreateDuration()
    duration:SetTimeFromStart(GetTime(), PREVIEW_DURATION)
    self.castBar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate,
        Enum.StatusBarTimerDirection.ElapsedTime)

    -- Store duration object for preview mode, game very madge otherwise
    self.cachedDuration = duration
    self.positioner:SetMinMaxValues(0, PREVIEW_DURATION)
    self.positioner:SetReverseFill(false)
    self.positioner:SetValue(0)
end

-- Frame update handler
local updateThrottle = 0.1
local updateElapsed = 0

function FCB:OnUpdate(elapsed)
    updateElapsed = updateElapsed + elapsed
    local hasActiveCast = self.casting or self.channeling or self.empowering

    -- Tick positioning runs every frame for now, not ideal but if throttled it becomes very jiggly
    if hasActiveCast then
        local duration = self.castBar:GetTimerDuration()
        if duration and self.cachedDuration then
            self:UpdateTickPosition(duration)
        end
        self:UpdateKickIndicator()
    else
        self.kickTick:SetAlpha(0)
    end

    -- Throttle remaining updates
    if updateElapsed < updateThrottle then return end

    -- Skip updates during hold timer
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

    -- Update time text
    local decimals = duration:EvaluateRemainingDuration(NRSKNUI.curves.DurationDecimals)
    self.time:SetFormattedText('%.' .. decimals .. 'f', remaining)

    -- Update target names
    if hasActiveCast then
        self:UpdateTargetNames()
    end

    -- End cast check
    if not hasActiveCast then
        self:HideTargetNames()
        self:ResetCastState()
        if self.frame then self.frame:Hide() end
    end

    updateElapsed = 0
end

-- Ensure OnUpdate script is set
-- Had weird issues with OnUpdate not running after being set, so doing this to be safe and ensure it's always set when needed
function FCB:EnsureOnUpdate()
    if self.frame and not self.frame:GetScript("OnUpdate") then
        self.frame:SetScript("OnUpdate", function(_, elapsed) self:OnUpdate(elapsed) end)
    end
end

-- Preview stuff
function FCB:ShowPreview()
    if not self.frame then self:CreateFrame() end
    self.isPreview, self.casting = true, true
    self.icon:SetTexture(FALLBACK_ICON)
    self.text:SetText("Focus Castbar")
    self.spark:Show()
    self.kickTick:SetAlpha(0)
    self:UpdateBarColor()
    self:ApplySettings()
    self:StartPreviewTimer()
    self:EnsureOnUpdate()
    self.frame:Show()

    -- Show player name in preview
    if self.targetNames then
        local name = UnitName("player")
        local classToken = select(2, UnitClass("player"))
        self.targetNames[1]:SetText(NRSKNUI:ColorTextByClass(name, classToken))
        self.targetNames[1]:SetAlpha(1)
        for i = 2, MAX_TARGET_NAMES do
            self.targetNames[i]:SetAlpha(0)
        end
    end

    -- Loop preview using ticker
    if self.previewTicker then self.previewTicker:Cancel() end
    self.previewTicker = C_Timer.NewTicker(PREVIEW_DURATION, function()
        if self.isPreview then
            self:StartPreviewTimer()
        end
    end)
end

function FCB:HidePreview()
    self.isPreview, self.casting = false, nil
    if self.previewTicker then
        self.previewTicker:Cancel()
        self.previewTicker = nil
    end
    self:HideTargetNames()
    if self.frame and not (self.casting or self.channeling or self.empowering) then
        self.frame:Hide()
    end
end

-- Module enable
function FCB:OnEnable()
    if not self.db.Enabled then return end
    self:CreateColorObjects()
    self:CreateFrame()
    C_Timer.After(0.5, function() self:ApplyPosition() end)

    -- Register cast events
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

    -- EditMode registration
    NRSKNUI.EditMode:RegisterElement({
        key = "FocusCastbar",
        displayName = "Focus Castbar",
        frame = self.frame,
        getPosition = function() return self.db.Position end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom, self.db.Position.AnchorTo = pos.AnchorFrom, pos.AnchorTo
            self.db.Position.XOffset, self.db.Position.YOffset = pos.XOffset, pos.YOffset
            self:ApplyPosition()
        end,
        getParentFrame = function()
            return NRSKNUI:ResolveAnchorFrame(self.db.anchorFrameType, self.db.ParentFrame)
        end,
        guiPath = "FocusCastbar",
    })
end

-- Module disable
function FCB:OnDisable()
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide()
    end
    if self.holdTimer then
        self.holdTimer:Cancel()
        self.holdTimer = nil
    end
    self:HideTargetNames()
    self:ResetCastState()
    self.isPreview = false
    self:UnregisterAllEvents()
end

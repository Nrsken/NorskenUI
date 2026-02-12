-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("FocusCastbar: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local FCB = NRSKNUI.Addon:NewModule("FocusCastbar", "AceEvent-3.0")

-- Localization
local CreateFrame = CreateFrame
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local UnitCastingDuration, UnitChannelDuration = UnitCastingDuration, UnitChannelDuration
local UnitEmpoweredChannelDuration = UnitEmpoweredChannelDuration
local UnitExists = UnitExists
local ipairs, select = ipairs, select
local UnitClass = UnitClass
local CreateColor = CreateColor
local GetTime = GetTime

-- Module locals
local FALLBACK_ICON = 136243
local FAILED = "Failed"
local INTERRUPTED = "Interrupted"
local PREVIEW_DURATION = 20

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

-- Module init
function FCB:OnInitialize()
    self.db = NRSKNUI.db.profile.Miscellaneous.FocusCastbar
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
end

-- Create castbar frame
function FCB:CreateFrame()
    if self.frame then return end
    local db = self.db
    local parent = NRSKNUI:ResolveAnchorFrame(db.anchorFrameType, db.ParentFrame)
    local height = db.Height or 20

    local backdrop = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    }

    -- Main container
    local frame = CreateFrame("Frame", "NRSKNUI_FocusCastbarFrame", parent, BackdropTemplateMixin and "BackdropTemplate")
    frame:SetSize(db.Width or 200, height)
    frame:SetPoint(db.Position.AnchorFrom or "CENTER", parent, db.Position.AnchorTo or "CENTER",
        db.Position.XOffset or 0, db.Position.YOffset or 200)
    frame:SetFrameStrata(db.Strata or "HIGH")
    frame:SetFrameLevel(100)
    frame:EnableMouse(false)
    frame:Hide()
    frame:SetBackdrop(backdrop)

    -- Icon frame
    local iconFrame = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
    iconFrame:SetSize(height, height)
    iconFrame:SetPoint("LEFT", frame, "LEFT", 0, 0)
    iconFrame:SetBackdrop(backdrop)
    iconFrame:SetBackdropColor(0, 0, 0, 0.8)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    local zoom = 0.3
    local texMin, texMax = 0.25 * zoom, 1 - 0.25 * zoom
    icon:SetTexCoord(texMin, texMax, texMin, texMax)

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

    -- Kick cooldown bar (invisible, only for tick positioning)
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
    text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    text:SetPoint("LEFT", castBar, "LEFT", 4, 0)
    text:SetJustifyH("LEFT")

    local time = castBar:CreateFontString(nil, "OVERLAY")
    time:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    time:SetPoint("RIGHT", castBar, "RIGHT", -4, 0)
    time:SetJustifyH("RIGHT")

    -- Store references
    self.frame, self.iconFrame, self.icon = frame, iconFrame, icon
    self.castBar, self.spark = castBar, spark
    self.kickCooldownBar, self.kickTick = kickCooldownBar, kickTick
    self.text, self.time = text, time
    self.holdTime = 0

    self:ApplySettings()
end

-- Apply visual settings
function FCB:ApplySettings()
    if not self.frame then return end
    self:CreateColorObjects()

    local db = self.db
    local height = db.Height or 20
    local bgColor = db.BackdropColor or { 0, 0, 0, 0.8 }
    local borderColor = db.BorderColor or { 0, 0, 0, 1 }
    local textColor = db.TextColor or { 1, 1, 1, 1 }
    local kickColors = db.KickIndicator or {}

    self.frame:SetSize(db.Width or 200, height)
    self.frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.8)
    self.frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    self.frame:SetFrameStrata(db.Strata or "HIGH")

    self.iconFrame:SetSize(height, height)
    self.iconFrame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)

    local texturePath = NRSKNUI:GetStatusbarPath(db.StatusBarTexture)
    self.castBar:SetStatusBarTexture(texturePath)
    self.kickCooldownBar:SetStatusBarTexture(texturePath)
    self.spark:SetSize(12, height)

    -- Kick tick settings
    self.kickTick:SetSize(2, height)
    local tickColor = kickColors.TickColor or { 1, 1, 1, 1 }
    self.kickTick:SetColorTexture(tickColor[1], tickColor[2], tickColor[3], tickColor[4] or 1)

    NRSKNUI:ApplyFont(self.text, db.FontFace, db.FontSize, db.FontOutline)
    NRSKNUI:ApplyFont(self.time, db.FontFace, db.FontSize, db.FontOutline)
    self.text:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
    self.time:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
end

-- Apply position
function FCB:ApplyPosition()
    if not self.frame then return end
    local db = self.db
    local parent = NRSKNUI:ResolveAnchorFrame(db.anchorFrameType, db.ParentFrame)
    self.frame:SetParent(parent)
    self.frame:ClearAllPoints()
    self.frame:SetPoint(db.Position.AnchorFrom or "CENTER", parent, db.Position.AnchorTo or "CENTER",
        db.Position.XOffset or 0, db.Position.YOffset or 200)
    self.frame:SetFrameStrata(db.Strata)
    NRSKNUI:SnapFrameToPixels(self.frame)
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
        local isReady = cooldown:IsZero()
        local rR, rG, rB = self.colors.Ready:GetRGB()
        local nR, nG, nB = self.colors.NotReady:GetRGB()

        local interruptibleColor = CreateColor(
            C_CurveUtil.EvaluateColorValueFromBoolean(isReady, rR, nR),
            C_CurveUtil.EvaluateColorValueFromBoolean(isReady, rG, nG),
            C_CurveUtil.EvaluateColorValueFromBoolean(isReady, rB, nB)
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

-- Update kick indicator tick position and visibility
function FCB:UpdateKickIndicator()
    local kick = self.db.KickIndicator
    if not kick or not kick.Enabled or not self.interruptId then
        self.kickTick:SetAlpha(0)
        return
    end

    local castDuration = UnitCastingDuration("focus") or UnitChannelDuration("focus")
    if not castDuration then
        self.kickTick:SetAlpha(0)
        return
    end

    local cooldown = C_Spell.GetSpellCooldownDuration(self.interruptId)
    if not cooldown then return end

    self.kickCooldownBar:SetMinMaxValues(0, castDuration:GetTotalDuration())
    self.kickCooldownBar:SetValue(cooldown:GetRemainingDuration())

    -- Tick visible when on cooldown AND cast is interruptible
    self.kickTick:SetAlphaFromBoolean(
        cooldown:IsZero(), 0,
        C_CurveUtil.EvaluateColorValueFromBoolean(self.notInterruptible, 0, 1)
    )

    self:UpdateBarColor(cooldown)
end

-- Setup kick cooldown bar direction based on cast type
function FCB:SetupKickCooldownBar()
    local kick = self.db.KickIndicator
    if not kick or not kick.Enabled or not self.interruptId then
        self.kickTick:SetAlpha(0)
        return
    end

    local width, height = self.castBar:GetSize()
    self.kickCooldownBar:ClearAllPoints()
    self.kickCooldownBar:SetSize(width, height)
    self.kickTick:ClearAllPoints()
    self.kickTick:SetSize(2, height)

    if self.channeling then
        self.kickCooldownBar:SetFillStyle(Enum.StatusBarFillStyle.Reverse)
        self.kickCooldownBar:SetPoint("RIGHT", self.castBar:GetStatusBarTexture(), "LEFT")
        self.kickTick:SetPoint("CENTER", self.kickCooldownBar:GetStatusBarTexture(), "LEFT", 0, 0)
    else
        self.kickCooldownBar:SetFillStyle(Enum.StatusBarFillStyle.Standard)
        self.kickCooldownBar:SetPoint("LEFT", self.castBar:GetStatusBarTexture(), "RIGHT")
        self.kickTick:SetPoint("CENTER", self.kickCooldownBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    end
end

-- Cast events
function FCB:OnCastEvent(event, unit)
    if unit ~= "focus" then return end
    if event:find("START") then
        self:StartCast()
    elseif event:find("STOP") then
        self:EndCast(false, false)
    elseif event:find("INTERRUPTED") then
        self:EndCast(true, true)
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
        if self.holdTime <= 0 then
            self:ResetCastState()
            self.frame:Hide()
        end
        return
    end

    self.castID, self.spellID, self.spellName = castID, spellID, text or name
    self.holdTime = 0
    self.notInterruptible = notInterruptible

    -- Hide non-interruptible casts if enabled
    if self.db.HideNotInterruptible then
        self.frame:SetAlphaFromBoolean(notInterruptible, 0, 1)
    else
        self.frame:SetAlpha(1)
    end

    self.castBar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)
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
function FCB:EndCast(showHold, wasInterrupted)
    if not self.frame or not self.frame:IsShown() then return end
    if self.holdTime > 0 then return end

    local holdTimer = self.db.HoldTimer
    if not holdTimer or not holdTimer.Enabled then
        self.spark:Hide()
        self:ResetCastState()
        self.frame:Hide()
        return
    end

    -- Show hold state
    self.spark:Hide()
    self.kickTick:SetAlpha(0)
    self.holdTime = holdTimer.Duration or 0.5
    self.castBar:SetMinMaxValues(0, 1)
    self.castBar:SetValue(1)
    self.time:SetText("")

    if showHold then
        self.text:SetText(wasInterrupted and INTERRUPTED or FAILED)
        if wasInterrupted then
            local color = holdTimer.InterruptedColor or { 0.1, 0.8, 0.1, 1 }
            self.castBar:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
        end
    else
        local color = holdTimer.SuccessColor or { 0.8, 0.1, 0.1, 1 }
        self.castBar:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
    end

    self:ResetCastState()
    self:EnsureOnUpdate()
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
        self:ResetCastState()
        if self.frame then self.frame:Hide() end
    end
end

-- Start preview cast timer
function FCB:StartPreviewTimer()
    local duration = C_DurationUtil.CreateDuration()
    duration:SetTimeFromStart(GetTime(), PREVIEW_DURATION)
    self.castBar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.ElapsedTime)
end

-- Frame update handler
function FCB:OnUpdate(elapsed)
    -- Handle hold time, after cast ends
    if self.holdTime > 0 then
        self.holdTime = self.holdTime - elapsed
        if self.holdTime <= 0 then
            self:ResetCastState()
            if self.frame then self.frame:Hide() end
        end
        return
    end

    -- Preview or active cast, update timer display
    local duration = self.castBar:GetTimerDuration()
    if not duration then return end

    local remaining = duration:GetRemainingDuration()
    if not remaining then return end

    local decimals = duration:EvaluateRemainingDuration(NRSKNUI.curves.DurationDecimals)
    self.time:SetFormattedText('%.' .. decimals .. 'f', remaining)

    if self.isPreview then return end

    if self.casting or self.channeling or self.empowering then
        self:UpdateKickIndicator()
    else
        -- No active cast and no hold time, hide bar
        self:ResetCastState()
        if self.frame then self.frame:Hide() end
    end
end

-- Ensure OnUpdate script is set
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
    self:ResetCastState()
    self.isPreview = false
    self:UnregisterAllEvents()
end

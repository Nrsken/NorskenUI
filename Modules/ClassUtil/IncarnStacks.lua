-- NRSKNUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Safety check
-- Create module
---@class IncarnStacks: AceModule, AceEvent-3.0
local INCARN = NRSKNUI:NewModule("IncarnStacks", "AceEvent-3.0")

-- Libraries
local LCG = NRSKNUI.Libs.LCG

-- Localization
local CreateFrame = CreateFrame
local UIParent = UIParent
local GetTime = GetTime

-- Module locals
local STACK_GRANT_SPELL_ID = 1269658 -- Wild Guardian
local DURATION = 60                  -- Buff uptime, if you press wild guardian again, this is refreshed
local ICON_TEXTURE = 237395          -- Gift of Maul icon
local CONSUME_SPELL_IDS = {
    [400254] = true,                 -- Raze
    [441605] = true,                 -- Ravage
}

-- Module state stuff
local currentStacks = 0
local isPreviewActive = false
local iconFrame = nil
local FORMAT_STRINGS = { [0] = "%.0f", [1] = "%.1f" }
local UPDATE_INTERVALS = { [0] = 0.5, [1] = 0.05 }
local updateElapsed = 0
local lastDecimals = 0
local eventFrame = nil

-- Update db, used for profile changes
function INCARN:UpdateDB()
    self.db = NRSKNUI.db.profile.IncarnStacks
end

-- Module init
function INCARN:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

-- Create the display frame
function INCARN:CreateFrame()
    if iconFrame then return end

    -- Create icon with borders
    iconFrame = NRSKNUI:CreateIconFrame(UIParent, self.db.IconSize, {
        name = "NRSKNUI_IncarnStacksIcon",
        zoom = 0.3,
        borderColor = { 0, 0, 0, 1 },
    })
    iconFrame:EnableMouse(false)
    iconFrame:SetMouseClickEnabled(false)
    iconFrame:Hide()

    -- Set icon texture
    iconFrame.icon:SetTexture(ICON_TEXTURE)

    -- Add cooldown spiral overlay
    local cooldown = CreateFrame("Cooldown", nil, iconFrame, "CooldownFrameTemplate")
    cooldown:SetAllPoints(iconFrame)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawSwipe(true)
    cooldown:SetReverse(true)
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetDrawBling(false)
    iconFrame.cooldown = cooldown

    -- Create a higher strata frame for text elements
    local textOverlay = CreateFrame("Frame", nil, iconFrame)
    textOverlay:SetAllPoints(iconFrame)
    textOverlay:SetFrameLevel(iconFrame:GetFrameLevel() + 10)
    iconFrame.textOverlay = textOverlay

    local stackText = NRSKNUI:CreateText(textOverlay, "OVERLAY")
    stackText:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 1, 1)
    stackText:SetTextColor(1, 1, 1, 1)
    iconFrame.stackText = stackText

    local timerText = NRSKNUI:CreateText(textOverlay, "OVERLAY")
    timerText:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    timerText:SetText("")
    iconFrame.timerText = timerText

    self.frame = iconFrame
    self.iconFrame = iconFrame
    self.cooldown = cooldown
    self.timerText = timerText
    self.stackText = stackText

    self:ApplySettings()
end

-- Apply settings from db
function INCARN:ApplySettings()
    if not iconFrame then return end
    local showTimer = self.db.ShowTimer ~= false
    local showStacks = self.db.ShowStacks ~= false

    -- Update frame and icon size
    iconFrame:SetSize(self.db.IconSize, self.db.IconSize)
    iconFrame.icon:SetAllPoints(iconFrame)

    -- Update stack text
    if self.stackText then
        NRSKNUI:SetTextFont(self.stackText, NRSKNUI:GetEffectiveFont(self.db), self.db.StackFontSize, self.db.StackFontOutline,
            {})
        local stackColor = self.db.StackTextColor
        self.stackText:SetTextColor(stackColor[1], stackColor[2], stackColor[3], stackColor[4] or 1)
        self.stackText:SetShown(showStacks)
    end

    -- Update timer text
    if self.timerText then
        NRSKNUI:SetTextFont(self.timerText, NRSKNUI:GetEffectiveFont(self.db), self.db.TimerFontSize, self.db.TimerFontOutline,
            {})
        local timerColor = self.db.TimerTextColor
        self.timerText:SetTextColor(timerColor[1], timerColor[2], timerColor[3], timerColor[4] or 1)

        if showTimer then
            self.timerText:Show()
            if self.timerText.softOutline then
                local usingSoftOutline = (self.db.TimerFontOutline == "SOFTOUTLINE")
                self.timerText.softOutline:SetShown(usingSoftOutline)
            end
        else
            self.timerText:Hide()
            if self.timerText.softOutline then
                self.timerText.softOutline:SetShown(false)
            end
        end
    end

    -- Apply position
    self:ApplyPosition()

    -- Handle glow state
    if self.glowActive then
        self:StopGlow()
        self:StartGlow()
    elseif self.db.GlowEnabled and iconFrame:IsShown() then
        self:StartGlow()
    end
end

-- Apply position
function INCARN:ApplyPosition()
    if not self.db.Enabled then return end
    if not iconFrame then return end
    NRSKNUI:ApplyFramePosition(iconFrame, self.db.Position, self.db)
end

-- Start glow effect
function INCARN:StartGlow()
    if not iconFrame then return end
    if not self.db.GlowEnabled then return end
    if not LCG then return end

    if self.db.GlowType == "pixel" then
        LCG.PixelGlow_Start(iconFrame, self.db.GlowColor,
            self.db.GlowLines,
            self.db.GlowFrequency,
            self.db.GlowLength,
            self.db.GlowThickness,
            self.db.GlowXOffset, self.db.GlowYOffset,
            self.db.GlowBorder,
            nil)
    elseif self.db.GlowType == "autocast" then
        LCG.AutoCastGlow_Start(iconFrame, self.db.GlowColor,
            self.db.GlowLines,
            self.db.GlowFrequency,
            self.db.GlowScale,
            self.db.GlowXOffset, self.db.GlowYOffset,
            nil)
    elseif self.db.GlowType == "button" then
        LCG.ButtonGlow_Start(iconFrame, self.db.GlowColor,
            self.db.GlowFrequency)
    elseif self.db.GlowType == "proc" then
        LCG.ProcGlow_Start(iconFrame, {
            color = self.db.GlowColor,
            startAnim = self.db.GlowStartAnim,
            duration = self.db.GlowDuration,
            xOffset = self.db.GlowXOffset,
            yOffset = self.db.GlowYOffset,
        })
    end

    self.glowActive = true
end

-- Stop glow effect
function INCARN:StopGlow()
    if not iconFrame then return end
    if not LCG then return end

    LCG.PixelGlow_Stop(iconFrame)
    LCG.AutoCastGlow_Stop(iconFrame)
    LCG.ButtonGlow_Stop(iconFrame)
    LCG.ProcGlow_Stop(iconFrame)

    self.glowActive = false
end

-- OnUpdate handler for timer text
function INCARN:OnUpdate(elapsed)
    if not self.durationObject then return end
    updateElapsed = updateElapsed + elapsed
    local interval = UPDATE_INTERVALS[lastDecimals] or 0.05
    if updateElapsed < interval then return end
    updateElapsed = 0

    -- Skip text updates if timer is hidden
    if not self.db.ShowTimer or not self.timerText then return end

    local remaining = self.durationObject:GetRemainingDuration()
    if not remaining or remaining <= 0 then
        self.timerText:SetText("")
        currentStacks = 0
        self:UpdateDisplay()
        return
    end

    -- Decimal stuff
    local decimals = self.durationObject:EvaluateRemainingDuration(NRSKNUI.curves.DurationDecimals)
    if decimals ~= lastDecimals then
        lastDecimals = decimals
        updateElapsed = 0
    end

    -- Use pre-cached format string
    local fmt = FORMAT_STRINGS[decimals] or FORMAT_STRINGS[0]
    self.timerText:SetFormattedText(fmt, remaining)

    -- Update soft outline text if it exists
    local softOutline = self.timerText.softOutline
    if softOutline and softOutline.main then
        softOutline.main:SetFormattedText(fmt, remaining)
    end
end

-- Update the display
function INCARN:UpdateDisplay()
    if not iconFrame then return end

    if currentStacks > 0 then
        if self.stackText and self.db.ShowStacks ~= false then
            self.stackText:SetText(currentStacks)
        end
        iconFrame:Show()
        if self.db.GlowEnabled and not self.glowActive then
            self:StartGlow()
        end
    else
        self:HideDisplay()
    end
end

-- Show the display with timer
function INCARN:ShowDisplay()
    if not iconFrame then self:CreateFrame() end
    if not iconFrame then return end
    updateElapsed = 0
    lastDecimals = 0

    self.procStartTime = GetTime()
    self.cooldown:SetCooldown(self.procStartTime, DURATION)

    -- Create duration object for timer text
    self.durationObject = C_DurationUtil.CreateDuration()
    self.durationObject:SetTimeFromStart(self.procStartTime, DURATION)

    -- Set initial timer text immediately (avoid throttle delay)
    if self.timerText and self.db.ShowTimer then
        self.timerText:SetFormattedText(FORMAT_STRINGS[0], DURATION)
        if self.timerText.softOutline and self.timerText.softOutline.main then
            self.timerText.softOutline.main:SetFormattedText(FORMAT_STRINGS[0], DURATION)
        end
    end

    if self.stackText and self.db.ShowStacks ~= false then self.stackText:SetText(currentStacks) end
    self:StartGlow()
    iconFrame:Show()

    -- Cancel any existing hide timer
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
end

-- Hide the display
function INCARN:HideDisplay()
    if not iconFrame then return end
    updateElapsed = 0
    lastDecimals = 0
    self:StopGlow()
    iconFrame:Hide()
    self.procStartTime = nil
    self.durationObject = nil

    if self.timerText then
        self.timerText:SetText("")
        if self.timerText.softOutline and self.timerText.softOutline.main then
            self.timerText.softOutline.main:SetText("")
        end
    end

    if self.stackText then self.stackText:SetText("") end

    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
end

-- Handle spell cast events
function INCARN:OnSpellCast(spellID)
    if isPreviewActive then return end

    if spellID == STACK_GRANT_SPELL_ID then
        currentStacks = 2
        self:ShowDisplay()
    elseif CONSUME_SPELL_IDS[spellID] then
        if currentStacks > 0 then
            currentStacks = currentStacks - 1
            if currentStacks > 0 then
                self:UpdateDisplay()
            else
                self:HideDisplay()
            end
        end
    end
end

-- Preview mode
function INCARN:ShowPreview()
    if not iconFrame then self:CreateFrame() end
    updateElapsed = 0
    lastDecimals = 0
    isPreviewActive = true
    currentStacks = 2
    self:ApplySettings()

    -- Show with fake cooldown
    local now = GetTime()
    self.cooldown:SetCooldown(now, DURATION)

    -- Create duration object for preview timer
    self.durationObject = C_DurationUtil.CreateDuration()
    self.durationObject:SetTimeFromStart(now, DURATION)

    -- Set initial timer text immediately (avoid throttle delay)
    if self.timerText and self.db.ShowTimer then
        self.timerText:SetFormattedText(FORMAT_STRINGS[0], DURATION)
        if self.timerText.softOutline and self.timerText.softOutline.main then
            self.timerText.softOutline.main:SetFormattedText(FORMAT_STRINGS[0], DURATION)
        end
    end

    -- Update stack display
    if self.stackText and self.db.ShowStacks ~= false then self.stackText:SetText(currentStacks) end

    self:StartGlow()
    if iconFrame then iconFrame:Show() end
end

function INCARN:HidePreview()
    updateElapsed = 0
    lastDecimals = 0
    isPreviewActive = false
    currentStacks = 0
    self:StopGlow()
    self.durationObject = nil

    if self.timerText then
        self.timerText:SetText("")
        if self.timerText.softOutline and self.timerText.softOutline.main then
            self.timerText.softOutline.main:SetText("")
        end
    end

    if self.stackText then self.stackText:SetText("") end
    if iconFrame then iconFrame:Hide() end
end

function INCARN:TogglePreview()
    if isPreviewActive then
        self:HidePreview()
    else
        self:ShowPreview()
    end
    return isPreviewActive
end

function INCARN:IsPreviewActive()
    return isPreviewActive
end

-- Module OnEnable
function INCARN:OnEnable()
    if not self.db or not self.db.Enabled then return end

    self:CreateFrame()
    C_Timer.After(0.5, function() self:ApplyPosition() end)

    -- Set up OnUpdate for timer text
    if iconFrame then
        iconFrame:SetScript("OnUpdate", function(_, elapsed)
            self:OnUpdate(elapsed)
        end)
    end

    -- Player cast event reg
    if not eventFrame then eventFrame = CreateFrame("Frame") end
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    eventFrame:SetScript("OnEvent", function(_, _, _, _, spellID)
        self:OnSpellCast(spellID)
    end)

    -- Reset stacks on death
    self:RegisterEvent("PLAYER_DEAD", function()
        currentStacks = 0
        self:HideDisplay()
    end)

    -- Register with EditMode
    if NRSKNUI.EditMode then
        NRSKNUI.EditMode:RegisterElement({
            key = "IncarnStacks",
            displayName = "Incarn Stacks",
            frame = iconFrame,
            getPosition = function()
                return self.db.Position
            end,
            setPosition = function(pos)
                self.db.Position.AnchorFrom = pos.AnchorFrom
                self.db.Position.AnchorTo = pos.AnchorTo
                self.db.Position.XOffset = pos.XOffset
                self.db.Position.YOffset = pos.YOffset
                self:ApplyPosition()
            end,
            getParentFrame = function()
                return NRSKNUI:ResolveAnchorFrame(self.db.anchorFrameType, self.db.ParentFrame)
            end,
            guiPath = "IncarnStacks",
        })
    end
end

-- Module OnDisable
function INCARN:OnDisable()
    if iconFrame then
        self:StopGlow()
        iconFrame:SetScript("OnUpdate", nil)
        iconFrame:Hide()
    end
    currentStacks = 0
    isPreviewActive = false
    self.glowActive = false
    self.durationObject = nil
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
    self:UnregisterAllEvents()

    -- Unregister unit event frame
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end

    -- Unregister from edit mode
    if NRSKNUI.EditMode then
        NRSKNUI.EditMode:UnregisterElement("IncarnStacks")
    end
end

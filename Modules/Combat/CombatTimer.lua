---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CombatTimer
local CombatTimer = NRSKNUI:GetModule('CombatTimer')
local EM = NRSKNUI.EditMode

local CreateFrame = CreateFrame
local GetTime = GetTime
local unpack = unpack

local IsEncounterInProgress = C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress

function CombatTimer:UpdateDB()
    self.db = NRSKNUI.db.profile.CombatTimer
end

function CombatTimer:OnInitialize()
    self:UpdateDB()
    self.lastCombatDuration = 0
    self:SetEnabledState(false)
end

function CombatTimer:CreateFrame()
    if self.frame then return end

    local frame = CreateFrame('Frame', 'NRSKNUI_CombatTimerFrame', UIParent)
    frame:SetPixelSize(100, 25)
    frame:SetFrameLevel(100)
    frame:EnableMouse(false)
    frame:SetMouseClickEnabled(false)
    frame:CreateBackdrop()

    frame.text = frame:CreateFontString(nil, 'OVERLAY')

    -- Install the ticker once, SetTicking flips its run mode instead of re-attaching a closure.
    self.onUpdate = function(_, elapsed) self:OnUpdate(elapsed) end
    if frame.SetOnUpdateMode then
        local disabledEnum = Enum and Enum.OnUpdateMode.Disabled
        frame:SetScript('OnUpdate', self.onUpdate)
        frame:SetOnUpdateMode(disabledEnum)
    end

    -- Finalize the frame and register it with Anchors.
    self.frame = frame
    EM:Register(self, 'CombatTimerFrame', self.frame, 'combatTimer')
    frame:Hide()
end

-- GUI Helper
function CombatTimer:Toggle(checked)
    if CombatTimer.frame then
        if checked and not CombatTimer.running and not CombatTimer.isPreview then
            CombatTimer.frame:Hide()
        elseif not checked then
            CombatTimer.frame:Show()
        end
    end
end

function CombatTimer:ApplySettings()
    if not self.frame then return end

    self.frame:ApplyPosition(self.db)
    self.frame.text:SetFontStyle(self.db)
    self.frame.text:SetFontJustify(self.db, nil, 4, 0, nil, nil, true)

    -- Only the sub-second format needs the faster tick.
    self.refreshRate = (self.db.Format == 'MM:SS.f' and 0.1) or 0.25

    if self.db.BackdropEnabled then
        self.frame:UpdateBackdropFromDB(self.db)
        self.frame:ToggleBackdrop(true)
    else
        self.frame:ToggleBackdrop(false)
    end

    -- Mark for a resize on the next update, since the backdrop may have changed.
    self.frame.NUIBackdropShape = nil
    self:UpdateState()
end

function CombatTimer:TextOnUpdate()
    if not self.frame then return end

    local totalTime = (self.running and (GetTime() - self.startTime)) or self.lastCombatDuration
    local status = NRSKNUI:FormatTime(totalTime, self.db.Format)

    -- Keep the backdrop fitted to the current shape, a resize clobbers the fontstring.
    local resized = self.frame:FitBackdropToText(self.frame.text, status, self.db.BackdropWidth, self.db.BackdropHeight)

    if resized or status ~= self.lastDisplayedText then
        self.frame.text:SetText(status)
        self.lastDisplayedText = status
    end
end

function CombatTimer:UpdateState()
    if not self.frame then return end

    local textColor = ((self.running or self.db.CombatOnly) and self.db.ColorInCombat) or self.db.ColorOutOfCombat
    self.frame.text:SetTextColor(unpack(textColor))

    self:TextOnUpdate()
end

function CombatTimer:OnUpdate(elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < self.refreshRate then return end
    self.elapsed = self.elapsed - self.refreshRate

    self:TextOnUpdate()
end

--TODO: Remove old script method when 12.1.0 is live.
-- Toggle the OnUpdate ticker with new SetOnUpdateMode API in 12.1.0
-- falls back to the old SetScript method for older clients.
function CombatTimer:SetTicking(enabled)
    local frame = self.frame
    if not frame then return end

    if frame.SetOnUpdateMode then
        local disabledEnum = Enum and Enum.OnUpdateMode.Disabled
        local runWhenVisibleEnum = Enum and Enum.OnUpdateMode.RunWhenVisible
        frame:SetOnUpdateMode((enabled and runWhenVisibleEnum) or disabledEnum)
    else
        frame:SetScript('OnUpdate', (enabled and self.onUpdate) or nil)
    end
end

function CombatTimer:StartTimer(isEncounterEvent)
    if not self.running then
        self.startTime = GetTime()
        self.running = true
        self.isEncounter = isEncounterEvent
        self.elapsed = 0
        self.lastCombatDuration = 0
        self.lastDisplayedText = ''

        self:SetTicking(true)
        self.frame:Show()
        self:UpdateState()
    elseif isEncounterEvent then
        self.isEncounter = true
    end
end

function CombatTimer:StopTimer(isEncounterEvent)
    if not self.running then return end

    local shouldStop = (self.isEncounter == isEncounterEvent) or (self.isEncounter and not IsEncounterInProgress())
    if not shouldStop then return end

    self.lastCombatDuration = GetTime() - self.startTime
    self.running = false
    self.isEncounter = false
    self.startTime = 0
    self:SetTicking(false)

    if self.db.CombatOnly then
        self.frame:Hide()
    end

    if self.db.PrintEnd then
        NRSKNUI:Print('Combat lasted ' .. NRSKNUI:FormatTime(self.lastCombatDuration, self.db.Format))
    end

    self:UpdateState()
end

function CombatTimer:OnEnable()
    self:CreateFrame()
    self:ApplySettings()

    if not self.db.CombatOnly then
        self.frame:Show()
    end

    self:RegisterEvent('PLAYER_REGEN_DISABLED', function() self:StartTimer(false) end)
    self:RegisterEvent('PLAYER_REGEN_ENABLED', function() self:StopTimer(false) end)
    self:RegisterEvent('ENCOUNTER_START', function() self:StartTimer(true) end)
    self:RegisterEvent('ENCOUNTER_END', function() self:StopTimer(true) end)
end

function CombatTimer:OnDisable()
    self:UnregisterAllEvents()
    if self.frame then
        self:SetTicking(false)
        self.frame:Hide()
    end
    self.running = false
    self.isPreview = false
end

function CombatTimer:ShowPreview()
    if not self.frame then return end
    self.isPreview = true
    self.frame:Show()
    self:ApplySettings()
end

function CombatTimer:HidePreview()
    self.isPreview = false
    if not self.frame then return end

    if not self.running and self.db.CombatOnly then
        self.frame:Hide()
    end
end

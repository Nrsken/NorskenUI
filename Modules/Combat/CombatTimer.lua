---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CombatTimer: AceModule, AceEvent-3.0
local CombatTimer = NRSKNUI:GetModule('CombatTimer')

local EM = NRSKNUI.EditMode

local CreateFrame = CreateFrame
local GetTime = GetTime
local unpack = unpack
local math_floor, math_max = math.floor, math.max
local string_format = string.format

local disabledEnum = Enum and Enum.OnUpdateMode.Disabled
local runWhenVisibleEnum = Enum and Enum.OnUpdateMode.RunWhenVisible

local IsEncounterInProgress = C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress

function CombatTimer:UpdateDB()
    self.db = NRSKNUI.db.profile.CombatTimer
end

function CombatTimer:OnInitialize()
    self:UpdateDB()
    self.lastCombatDuration = 0
    self:SetEnabledState(false)
end

---@param totalSeconds number
---@param format string
---@return string
local function FormatTime(totalSeconds, format)
    local mins = math_floor(totalSeconds / 60)
    local secs = math_floor(totalSeconds % 60)

    if format == 'MM:SS:MS' then
        local frac = totalSeconds - math_floor(totalSeconds)
        local ms = math_floor(frac * 10)
        return string_format('%02d:%02d:%d', mins, secs, ms)
    end

    return string_format('%02d:%02d', mins, secs)
end

function CombatTimer:CreateFrame()
    if self.frame then return end

    local frame = CreateFrame('Frame', 'NRSKNUI_CombatTimerFrame', UIParent)
    frame:SetSize(100, 25)
    frame:SetFrameLevel(100)
    frame:EnableMouse(false)
    frame:SetMouseClickEnabled(false)

    ---@cast frame Frame & PublicBackdropMixin
    NRSKNUI:CreateBackdrop(frame)

    frame.text = frame:CreateFontString(nil, 'OVERLAY')
    frame.text:SetAllPoints(frame)

    -- Install the ticker once, SetTicking flips its run mode instead of re-attaching a closure.
    self.onUpdate = function(_, elapsed) self:OnUpdate(elapsed) end
    if frame.SetOnUpdateMode then
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
    self.frame.text:SetFontJustify(self.db, nil, 4)

    self.refreshRate = (self.db.Format == 'MM:SS:MS' and 0.1) or 0.25

    local refText = (self.db.Format == 'MM:SS:MS' and '00:00:0') or '00:00'
    self.frame.text:SetText(refText)

    self:UpdateState()

    if self.db.BackdropEnabled then
        self.frame:UpdateBackdropFromDB(self.db)
        self.frame:ToggleBackdrop(true)
    else
        self.frame:ToggleBackdrop(false)
    end

    local w = math_floor(self.frame.text:GetStringWidth() + self.db.BackdropWidth)
    local h = math_floor(self.frame.text:GetStringHeight() + self.db.BackdropHeight)
    self.frame:SetSize(math_max(w, 40), math_max(h, 20))
end

function CombatTimer:TextOnUpdate()
    if not self.frame then return end

    local totalTime = (self.running and (GetTime() - self.startTime)) or self.lastCombatDuration
    local status = FormatTime(totalTime, self.db.Format)

    -- If the text has changed, update it.
    if status ~= self.lastDisplayedText then
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
        NRSKNUI:Print('Combat lasted ' .. FormatTime(self.lastCombatDuration, self.db.Format))
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

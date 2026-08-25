---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class BigWigsTimersModule
local BigWigsTimers = NRSKNUI:GetModule('BigWigsTimers')

BigWigsTimers.bars = {}
BigWigsTimers.textByEventId = {}
BigWigsTimers.eventIdByText = {}

local hasanysecretvalues = hasanysecretvalues
local pairs, next = pairs, next
local tostring = tostring
local GetTime = GetTime
local wipe = wipe

local HANDLERS = {
    BigWigs_StartBar = 'OnStartBar',
    BigWigs_Timer = 'OnTimer',
    BigWigs_TargetTimer = 'OnTargetTimer',
    BigWigs_CastTimer = 'OnCastTimer',
    BigWigs_StartBreak = 'OnStartBreak',
    BigWigs_StartPull = 'OnStartPull',
    BigWigs_StopBar = 'OnStopBar',
    BigWigs_PauseBar = 'OnPauseBar',
    BigWigs_ResumeBar = 'OnResumeBar',
    BigWigs_StopBars = 'OnModuleStop',
    BigWigs_OnBossDisable = 'OnModuleStop',
    BigWigs_OnBossWipe = 'OnModuleStop',
    BigWigs_OnPluginDisable = 'OnModuleStop',
}

-- Registration --

---@return boolean registered
function BigWigsTimers:RegisterCallbacks()
    if not BigWigsLoader then return false end

    for event, handler in pairs(HANDLERS) do
        BigWigsLoader.RegisterMessage(self, event, handler)
    end

    return true
end

function BigWigsTimers:UnregisterCallbacks()
    if not BigWigsLoader then return end

    for event in pairs(HANDLERS) do
        BigWigsLoader.UnregisterMessage(self, event)
    end
end

-- Registry --

---@param text string
function BigWigsTimers:RemoveBar(text)
    if not self.bars[text] then return end

    self.bars[text] = nil

    local eventId = self.eventIdByText[text]
    if eventId then
        self.eventIdByText[text] = nil
        self.textByEventId[eventId] = nil
    end
end

function BigWigsTimers:WipeBars()
    wipe(self.bars)
    wipe(self.textByEventId)
    wipe(self.eventIdByText)
    self:OnBarsChanged()
end

---@param addon BigWigs.Module?
---@param spellId number|string as BigWigs sent it, the color lookup keys off the raw value
---@param duration number
---@param text string
---@param count number
---@param icon number|string
---@param timerType 'timer'|'cast'|'break'|'pull'
---@param isCooldown boolean
---@param isBarEnabled boolean
function BigWigsTimers:StoreBar(addon, spellId, duration, text, count, icon, timerType, isCooldown, isBarEnabled)
    local bar = self.bars[text]

    if not bar then
        bar = {}
        self.bars[text] = bar
    end

    bar.addon = addon
    bar.spellId = tostring(spellId)
    bar.text = text
    bar.duration = duration
    bar.expirationTime = GetTime() + duration
    bar.icon = icon
    bar.count = count
    bar.timerType = timerType
    bar.isCooldown = isCooldown
    bar.isBarEnabled = isBarEnabled
    bar.paused = nil
    bar.remaining = nil
    bar.keepUntil = nil
    bar.bwBarColor, bar.bwTextColor, bar.bwBgColor = self:GetBigWigsColors(addon, spellId)

    self:OnBarsChanged()
end

-- Handlers --

---The only message carrying the timeline event ID and it arrives before its BigWigs_Timer.
function BigWigsTimers:OnStartBar(...)
    local _, _, _, text, _, _, _, _, eventId = ...
    if not eventId or hasanysecretvalues(text) then return end

    self.eventIdByText[text] = eventId
    self.textByEventId[eventId] = text
end

function BigWigsTimers:OnTimer(...)
    local _, addon, spellId, duration, _, text, count, icon, isCooldown, isBarEnabled = ...
    if hasanysecretvalues(spellId, text) then return end

    self:StoreBar(addon, spellId, duration, text, count, icon, 'timer', isCooldown, isBarEnabled)
end

function BigWigsTimers:OnTargetTimer(...)
    local _, addon, spellId, duration, _, text, count, icon, _, isBarEnabled = ...
    if hasanysecretvalues(spellId, text) then return end

    self:StoreBar(addon, spellId, duration, text, count, icon, 'timer', false, isBarEnabled)
end

function BigWigsTimers:OnCastTimer(...)
    local _, addon, spellId, duration, _, text, count, icon, _, isBarEnabled = ...
    if hasanysecretvalues(spellId, text) then return end

    self:StoreBar(addon, spellId, duration, text, count, icon, 'cast', false, isBarEnabled)
end

function BigWigsTimers:OnStartBreak(...)
    local _, plugin, seconds, _, _, _, text, icon = ...

    self:StoreBar(plugin, '-1', seconds, text, 0, icon, 'break', false, true)
end

function BigWigsTimers:OnStartPull(...)
    local _, plugin, seconds, _, text = ...

    self:StoreBar(plugin, '-2', seconds, text, 0, 136116, 'pull', false, true)
end

---Timeline modules send (nil, nil, eventId) in place of (module, text).
function BigWigsTimers:OnStopBar(...)
    local _, _, text, eventId = ...

    text = text or (eventId and self.textByEventId[eventId])
    if not text then return end

    local bar = self.bars[text]
    if not bar then return end

    -- A trigger holding the bar past its own expiry keeps it alive until that offset runs out.
    if not bar.keepUntil or bar.keepUntil <= GetTime() then
        self:RemoveBar(text)
    end

    self:OnBarsChanged()
end

function BigWigsTimers:OnPauseBar(...)
    local _, _, text, eventId = ...

    text = text or (eventId and self.textByEventId[eventId])
    local bar = text and self.bars[text]
    if not bar or bar.paused then return end

    bar.paused = true
    bar.remaining = bar.expirationTime - GetTime()
    self:OnBarsChanged()
end

function BigWigsTimers:OnResumeBar(...)
    local _, _, text, eventId = ...

    text = text or (eventId and self.textByEventId[eventId])
    local bar = text and self.bars[text]
    if not bar or not bar.paused then return end

    bar.expirationTime = GetTime() + bar.remaining
    bar.paused = nil
    bar.remaining = nil
    self:OnBarsChanged()
end

---Fired on wipe, kill and plugin disable, each clearing only what that module started.
function BigWigsTimers:OnModuleStop(...)
    local _, addon = ...

    for text, bar in pairs(self.bars) do
        if bar.addon == addon then
            self:RemoveBar(text)
        end
    end

    self:OnBarsChanged()
end

-- Expiry --

---Drop bars that have run out, unless a trigger offset is still holding one on screen.
---@return boolean anyLeft
function BigWigsTimers:SweepExpiredBars()
    local now = GetTime()
    local changed

    for text, bar in pairs(self.bars) do
        if not bar.paused and bar.expirationTime <= now then
            if not bar.keepUntil or bar.keepUntil <= now then
                self:RemoveBar(text)
                changed = true
            end
        end
    end

    if changed then
        self:OnBarsChanged()
    end

    return next(self.bars) ~= nil
end

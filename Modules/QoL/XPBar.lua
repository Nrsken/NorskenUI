---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class XPBar
local XPBar = NRSKNUI:GetModule('XPBar')
local EM = NRSKNUI.EditMode
local kajiGUI = NRSKNUI.GUI

local CreateFrame = CreateFrame
local UnitLevel = UnitLevel
local UnitXP, UnitXPMax, GetXPExhaustion = UnitXP, UnitXPMax, GetXPExhaustion
local GetMaxLevelForPlayerExpansion = GetMaxLevelForPlayerExpansion
local RequestTimePlayed = RequestTimePlayed
local GetQuestLogRewardXP = GetQuestLogRewardXP
local SecondsToTime = SecondsToTime
local math_min, math_floor = math.min, math.floor
local format = string.format
local time = time
local unpack = unpack
local ipairs = ipairs

local UIParent = UIParent
local GameTooltip = GameTooltip
local C_Timer = C_Timer
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
local MainStatusTrackingBarContainer = MainStatusTrackingBarContainer
local _G = _G

local GetNumQuestLogEntries = C_QuestLog and C_QuestLog.GetNumQuestLogEntries
local GetQuestInfo = C_QuestLog and C_QuestLog.GetInfo
local ReadyForTurnIn = C_QuestLog and C_QuestLog.ReadyForTurnIn
local IsComplete = C_QuestLog and C_QuestLog.IsComplete

local STALE_SESSION = 259200 -- 3 days, a session older than this is treated as a fresh one.

-- Abbreviate an XP amount to a compact K/M string for the bar and tooltip.
local function FormatXP(value)
    value = value or 0
    if value >= 1e6 then
        return format('%.2fM', value / 1e6)
    elseif value >= 1e3 then
        return format('%.1fK', value / 1e3)
    end
    return format('%d', value)
end

function XPBar:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.XPBar
    self.charDB = NRSKNUI.db.char.XPBar
end

function XPBar:OnInitialize()
    self:UpdateDB()
    self.QuestXPComplete = 0
    self.QuestXPIncomplete = 0
    self.QuestXPTotal = 0
    self:SetEnabledState(false)
end

function XPBar:CreateBar()
    if self.coreFrame then return end
    local width, height = self.db.width, self.db.height
    local sTex = NRSKNUI:GetStatusbar(self.db)

    -- Create the main frame for the Experience Bar
    local coreFrame = CreateFrame('Frame', 'NRSKNUI_XPBar', UIParent)
    coreFrame:SetPixelSize(width, height)
    coreFrame:ApplyPosition(self.db)
    coreFrame:CreateBackdrop(true)
    coreFrame:EnableMouse(true) -- Enable mouse for tooltip.

    -- Rested Experience Bar
    coreFrame.RestedBar = CreateFrame('StatusBar', nil, coreFrame)
    coreFrame.RestedBar:SetPixelSize(width, height)
    coreFrame.RestedBar:SetPixelPoint('CENTER')
    coreFrame.RestedBar:SetFrameLevel(10)
    coreFrame.RestedBar:SetValue(0)
    coreFrame.RestedBar:SetStatusBarTexture(sTex)
    coreFrame.RestedBar:SetPixelSnap()

    -- Quest Experience Bar
    coreFrame.questBar = CreateFrame('StatusBar', nil, coreFrame)
    coreFrame.questBar:SetPixelSize(width, height)
    coreFrame.questBar:SetPixelPoint('CENTER')
    coreFrame.questBar:SetFrameLevel(20)
    coreFrame.questBar:SetValue(0)
    coreFrame.questBar:SetStatusBarTexture(sTex)
    coreFrame.questBar:SetPixelSnap()

    -- Main Experience Bar
    coreFrame.progressBar = CreateFrame('StatusBar', nil, coreFrame)
    coreFrame.progressBar:SetPixelSize(width, height)
    coreFrame.progressBar:SetPixelPoint('CENTER')
    coreFrame.progressBar:SetFrameLevel(30)
    coreFrame.progressBar:SetValue(0)
    coreFrame.progressBar:SetStatusBarTexture(sTex)
    coreFrame.progressBar:SetPixelSnap()

    -- Border frame
    coreFrame.borderFrame = CreateFrame('Frame', nil, coreFrame)
    coreFrame.borderFrame:SetPixelSize(width, height)
    coreFrame.borderFrame:SetPixelPoint('CENTER')
    coreFrame.borderFrame:SetFrameLevel(40)
    coreFrame.borderFrame:AddBorders()

    -- Level
    coreFrame.leftText = coreFrame.borderFrame:CreateFontString(nil, 'OVERLAY')
    -- Current/max
    coreFrame.centerText = coreFrame.borderFrame:CreateFontString(nil, 'OVERLAY')
    -- Percent
    coreFrame.rightText = coreFrame.borderFrame:CreateFontString(nil, 'OVERLAY')

    coreFrame:SetScript('OnEnter', function()
        self.tooltipShown = true
        self:ShowTooltip()
        self.tooltipTicker = C_Timer.NewTicker(1, function()
            if self.tooltipShown and GameTooltip:IsOwned(coreFrame) then
                self:ShowTooltip()
            end
        end)
    end)
    coreFrame:SetScript('OnLeave', function()
        self.tooltipShown = false
        if self.tooltipTicker then
            self.tooltipTicker:Cancel()
            self.tooltipTicker = nil
        end
        if GameTooltip:IsOwned(coreFrame) then -- Only hide if we still own it, another addon may have taken over.
            GameTooltip:Hide()
        end
    end)

    self.coreFrame = coreFrame
    self.coreFrame:Hide()
end

function XPBar:ApplySettings()
    if not self.coreFrame then return end

    -- Make settings locals so it looks cleaner and not so noisy.
    local width, height = self.db.width, self.db.height
    local pTex = NRSKNUI:GetStatusbar(self.db)
    local rTex = NRSKNUI:GetStatusbar(self.db, self.db.RestedTexture)
    local qTex = NRSKNUI:GetStatusbar(self.db, self.db.QuestTexture)
    local pR, pG, pB, pA = NRSKNUI:GetAccentColor(self.db.ColorMode, self.db.StatusColor)
    local qR, qG, qB, qA = NRSKNUI:GetAccentColor(self.db.ColorModeQuest, self.db.QuestColor)
    local rR, rG, rB, rA = NRSKNUI:GetAccentColor(self.db.ColorModeRested, self.db.RestedColor)
    local bgR, bgG, bgB, bgA = unpack(self.db.BackgroundColor)
    local bR, bG, bB, bA = unpack(self.db.BorderColor)
    local tR, tG, tB, tA = unpack(self.db.TextColor)

    if self.db.ColorModeRested == 'theme' or self.db.ColorModeRested == 'class' then rA = 0.25 end -- Force 0.25 alpha for theme/class rested bar colors.

    -- Store the colors for use in the tooltip later, don't need alpha tho.
    self.pC = { pR, pG, pB }
    self.qC = { qR, qG, qB }
    self.rC = { rR, rG, rB }

    -- Core frame settings
    self.coreFrame:SetPixelSize(width, height)
    self.coreFrame:ApplyPosition(self.db)
    self.coreFrame:SetBackgroundColor(bgR, bgG, bgB, bgA)
    self.coreFrame.borderFrame:SetBorderColor(bR, bG, bB, bA)

    -- Main XP bar
    self.coreFrame.progressBar:SetPixelSize(width, height)
    self.coreFrame.progressBar:SetStatusBarTexture(pTex)
    self.coreFrame.progressBar:SetStatusBarColor(pR, pG, pB, pA)

    -- Rested bar
    self.coreFrame.RestedBar:SetPixelSize(width, height)
    self.coreFrame.RestedBar:SetStatusBarTexture(rTex)
    self.coreFrame.RestedBar:SetStatusBarColor(rR, rG, rB, rA)

    -- Quest bar
    self.coreFrame.questBar:SetPixelSize(width, height)
    self.coreFrame.questBar:SetStatusBarTexture(qTex)
    self.coreFrame.questBar:SetStatusBarColor(qR, qG, qB, qA)

    -- Border frame
    self.coreFrame.borderFrame:SetPixelSize(width, height)

    -- Info text
    for _, fs in ipairs({ self.coreFrame.leftText, self.coreFrame.centerText, self.coreFrame.rightText }) do
        fs:SetFontStyle(self.db)
        fs:SetTextColor(tR, tG, tB, tA)
    end
    self.coreFrame.leftText:SetFontJustify('LEFT', self.coreFrame, 4, 0)
    self.coreFrame.centerText:SetFontJustify('CENTER', self.coreFrame, 0, 0)
    self.coreFrame.rightText:SetFontJustify('RIGHT', self.coreFrame, -4, 0)

    self:Update()
end

-- Sum the reward XP of every quest in the log, split by whether it can be turned in now.
function XPBar:UpdateQuestXP()
    local complete, incomplete = 0, 0

    if GetNumQuestLogEntries then
        local numShown = GetNumQuestLogEntries()
        for i = 1, numShown do
            local info = GetQuestInfo(i)
            if info and not info.isHeader and not info.isHidden and info.questID and info.questID > 0 then
                local xp = GetQuestLogRewardXP(info.questID) or 0
                if xp > 0 then
                    if ReadyForTurnIn(info.questID) or IsComplete(info.questID) then
                        complete = complete + xp
                    else
                        incomplete = incomplete + xp
                    end
                end
            end
        end
    end

    self.QuestXPComplete = complete
    self.QuestXPIncomplete = incomplete
    self.QuestXPTotal = complete + incomplete
end

-- Gather the live experience numbers used by both the bars and the text.
function XPBar:GetData()
    local dataTable = {}
    dataTable.xpCurr = UnitXP('player') or 0
    dataTable.xpMax = UnitXPMax('player') or 0
    dataTable.rested = GetXPExhaustion() or 0
    dataTable.level = UnitLevel('player')
    dataTable.isMaxLevel = dataTable.level >= GetMaxLevelForPlayerExpansion()
    dataTable.remaining = dataTable.xpMax - dataTable.xpCurr
    dataTable.completeXP = self.QuestXPComplete
    dataTable.incompleteXP = self.QuestXPIncomplete
    dataTable.questXP = self.QuestXPTotal
    dataTable.percentXP = dataTable.xpMax > 0 and (dataTable.xpCurr / dataTable.xpMax * 100) or 0
    dataTable.percentComplete = dataTable.xpMax > 0 and ((dataTable.xpCurr + dataTable.completeXP) / dataTable.xpMax * 100) or 0
    dataTable.percentRested = dataTable.xpMax > 0 and (dataTable.rested / dataTable.xpMax * 100) or 0

    return dataTable
end

-- TODO use this data once ready.
-- Record per level xp requirements for math use later.
local shouldRecordXP = true
function XPBar:RecordXP(data)
    if not shouldRecordXP then return end
    if data.isMaxLevel or data.xpMax <= 0 then return end
    local xpTable = NRSKNUI.db.global.XPTable
    if xpTable[data.level] ~= data.xpMax then
        xpTable[data.level] = data.xpMax
    end
end

-- Generates some fake data for the preview.
function XPBar:GetPreviewData()
    local xpMax, xpCurr, completeXP = 100000, 40000, 12000
    return {
        level = UnitLevel('player'),
        isMaxLevel = false,
        xpCurr = xpCurr,
        xpMax = xpMax,
        rested = 40000,
        remaining = xpMax - xpCurr,
        completeXP = completeXP,
        percentXP = xpCurr / xpMax * 100,
        percentComplete = (xpCurr + completeXP) / xpMax * 100,
    }
end

-- Gather the session stats (XP/hour, time-to-level, time played) for the tooltip.
function XPBar:GetSessionStats(data)
    local perCharDB = self.charDB
    local now = time()
    local sessionTime = now - perCharDB.StartTime
    local gained = perCharDB.XPGained
    local xpPerHour, timeToLevel = 0, nil

    if sessionTime > 0 and gained > 0 then
        xpPerHour = math_floor(gained / (sessionTime / 3600))
        if xpPerHour > 0 and not data.isMaxLevel then
            timeToLevel = math_floor(data.remaining / xpPerHour * 3600)
        end
    end

    local elapsed = self.timePlayedStamp and (now - self.timePlayedStamp) or 0
    return {
        sessionTime = sessionTime,
        gained = gained,
        xpPerHour = xpPerHour,
        timeToLevel = timeToLevel,
        totalPlayed = perCharDB.TotalAccumulationTime + elapsed,
        levelPlayed = perCharDB.LevelAccumulationTime + elapsed,
    }
end

function XPBar:UpdateText(data)
    local coreFrame = self.coreFrame
    coreFrame.leftText:SetText('Level ' .. data.level)

    if data.isMaxLevel then
        coreFrame.centerText:SetText('Max Level')
        coreFrame.rightText:SetText('')
        return
    end

    coreFrame.centerText:SetText(format('%s / %s (%s)', FormatXP(data.xpCurr), FormatXP(data.xpMax), FormatXP(data.remaining)))

    if data.completeXP > 0 then
        coreFrame.rightText:SetText(format('%.1f%% (%.1f%%)', data.percentXP, data.percentComplete))
    else
        coreFrame.rightText:SetText(format('%.1f%%', data.percentXP))
    end
end

-- Push a data table onto the bars and text, shared by the live update and the preview.
function XPBar:Render(data)
    local coreFrame = self.coreFrame

    if data.isMaxLevel and not self.previewActive then
        coreFrame:Hide()
        return
    end

    if data.xpMax > 0 then
        coreFrame.progressBar:SetMinMaxValues(0, data.xpMax)
        coreFrame.progressBar:SetValue(data.xpCurr)

        coreFrame.RestedBar:SetMinMaxValues(0, data.xpMax)
        coreFrame.RestedBar:SetValue(self.db.RestedShow and math_min(data.xpCurr + data.rested, data.xpMax) or 0)

        coreFrame.questBar:SetMinMaxValues(0, data.xpMax)
        coreFrame.questBar:SetValue(self.db.QuestShow and math_min(data.xpCurr + data.completeXP, data.xpMax) or 0)
    end

    self:UpdateText(data)
    coreFrame:Show()
end

function XPBar:Update()
    if not self.coreFrame then return end
    if self.previewActive then
        self:Render(self:GetPreviewData())
        return
    end

    local data = self:GetData()
    self:RecordXP(data)

    -- Player is max level, hide bar and unregister events to save resources.
    if data.isMaxLevel then
        self.coreFrame:Hide()
        self:UnregisterAllEvents()
        return
    end

    self:Render(data)

    if self.tooltipShown and GameTooltip:IsOwned(self.coreFrame) then
        self:ShowTooltip()
    end
end

function XPBar:ShowTooltip()
    local coreFrame = self.coreFrame
    if not coreFrame then return end

    local data = self:GetData()
    local sData = self:GetSessionStats(data)

    -- Tooltip header
    GameTooltip:SetOwner(coreFrame, 'ANCHOR_BOTTOM')
    GameTooltip:ClearLines()
    GameTooltip:AddLine('Experience Breakdown', 1, 1, 1)
    GameTooltip:AddLine(' ')

    -- Show the XP and remaining XP, or indicate that the player is at max level.
    if data.isMaxLevel then
        GameTooltip:AddLine('Max Level', 0.6, 0.8, 1)
    else
        GameTooltip:AddDoubleLine('XP:', format('%s / %s (%.1f%%)', FormatXP(data.xpCurr), FormatXP(data.xpMax), data.percentXP), self.pC[1], self.pC[2], self.pC[3], self.pC[1], self.pC[2], self.pC[3])
        GameTooltip:AddDoubleLine('Remaining:', format('%s (%.1f%%)', FormatXP(data.remaining), 100 - data.percentXP), 1, 1, 1, 1, 1, 1)
    end

    -- Show the rested XP if any is available.
    if data.rested > 0 then
        GameTooltip:AddDoubleLine('Rested:', format('+%s (%.1f%%)', FormatXP(data.rested), data.percentRested), self.rC[1], self.rC[2], self.rC[3], self.rC[1], self.rC[2], self.rC[3])
    end

    -- Show the quest XP if any is available.
    if data.questXP > 0 then
        local questPercent = data.xpMax > 0 and (data.questXP / data.xpMax * 100) or 0
        GameTooltip:AddDoubleLine('Quest Log XP:', format('%s (%.1f%%)', FormatXP(data.questXP), questPercent), self.qC[1], self.qC[2], self.qC[3], self.qC[1], self.qC[2], self.qC[3])
        GameTooltip:AddDoubleLine('  Ready to turn in:', FormatXP(data.completeXP), 1, 0.82, 0, 1, 0.82, 0)
        GameTooltip:AddDoubleLine('  In progress:', FormatXP(data.incompleteXP), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
    end

    -- Show the XP/hour and time-to-level if the player is not at max level and has gained XP this session.
    if not data.isMaxLevel and sData.xpPerHour > 0 then
        GameTooltip:AddLine(' ')
        GameTooltip:AddDoubleLine('XP per hour:', FormatXP(sData.xpPerHour), 1, 1, 1, 1, 1, 1)
        if sData.timeToLevel then
            GameTooltip:AddDoubleLine('Time to level:', SecondsToTime(sData.timeToLevel), 1, 1, 1, 1, 1, 1)
        end
    end

    -- Show the time played stats if any have been recorded.
    GameTooltip:AddLine(' ')
    GameTooltip:AddDoubleLine('Time this level:', sData.levelPlayed > 0 and SecondsToTime(sData.levelPlayed) or '--', 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine('Time this session:', sData.sessionTime > 0 and SecondsToTime(sData.sessionTime) or '--', 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine('Total played:', sData.totalPlayed > 0 and SecondsToTime(sData.totalPlayed) or '--', 1, 1, 1, 1, 1, 1)

    GameTooltip:SetMinimumWidth(260) -- Set a min width, otherwise tooltip will look 'jumpy' when Time this sesson text updates.
    GameTooltip:Show()
end

-- Restore the chat frames's TIME_PLAYED_MSG registration after a silenced request.
function XPBar:RestoreChatPlayed()
    if not self.silencedFrames then return end
    for _, cFrame in ipairs(self.silencedFrames) do
        cFrame:RegisterEvent('TIME_PLAYED_MSG')
    end
    self.silencedFrames = nil
end

-- Silent /played request to gather total and level time without spamming the chat frames with messages.
function XPBar:RequestPlayed()
    self:RestoreChatPlayed() -- reclaim any frames from a request that never got a response
    self.silencedFrames = {}
    for i = 1, NUM_CHAT_WINDOWS do
        local cFrame = _G['ChatFrame' .. i]
        if cFrame and cFrame:IsEventRegistered('TIME_PLAYED_MSG') then
            cFrame:UnregisterEvent('TIME_PLAYED_MSG')
            self.silencedFrames[#self.silencedFrames + 1] = cFrame
        end
    end
    RequestTimePlayed()
    C_Timer.After(3, function() self:RestoreChatPlayed() end) -- safety net if no response arrives
end

function XPBar:PLAYER_ENTERING_WORLD(_, isLogin, isReload)
    local perCharDB = self.charDB
    if isLogin or perCharDB.StartTime == 0 or (time() - perCharDB.StartTime) >= STALE_SESSION then
        perCharDB.XPGained = 0
        perCharDB.StartTime = time()
    end

    perCharDB.XPLast = UnitXP('player') or 0
    perCharDB.XPMax = UnitXPMax('player') or 0

    if isLogin or isReload then
        self:RequestPlayed()
    end

    self:UpdateQuestXP()
    self:Update()
end

function XPBar:PLAYER_XP_UPDATE()
    local perCharDB = self.charDB
    local currXP = UnitXP('player') or 0
    local maxXP = UnitXPMax('player') or 0

    local gained = currXP - perCharDB.XPLast
    if gained < 0 then -- crossed a level, the previous bar wrapped around
        gained = perCharDB.XPMax - perCharDB.XPLast + currXP
    end

    perCharDB.XPGained = perCharDB.XPGained + gained
    perCharDB.XPLast = currXP
    perCharDB.XPMax = maxXP

    self:Update()
end

function XPBar:PLAYER_LEVEL_UP()
    self.charDB.LevelAccumulationTime = 0
    self:RequestPlayed()
    self:Update()
end

function XPBar:TIME_PLAYED_MSG(_, totalTime, levelTime)
    self.charDB.TotalAccumulationTime = totalTime or 0
    self.charDB.LevelAccumulationTime = levelTime or 0
    self.timePlayedStamp = time()

    -- Restore next frame so the chat frames miss this event burst but work for a manual /played.
    C_Timer.After(0, function() self:RestoreChatPlayed() end)

    if self.tooltipShown and GameTooltip:IsOwned(self.coreFrame) then self:ShowTooltip() end
end

function XPBar:QUEST_LOG_UPDATE()
    self:UpdateQuestXP()
    self:Update()
end

function XPBar:OnEnable()
    if not self.db.Enabled then return end

    if self.db.HideBlizzardBar and MainStatusTrackingBarContainer then
        MainStatusTrackingBarContainer:Banish()
        MainStatusTrackingBarContainer:UnregisterAllEvents()
        MainStatusTrackingBarContainer:Hide()
        MainStatusTrackingBarContainer:SetAlpha(0)
    end

    self.themeSub = kajiGUI:OnThemeChanged(function()
        if self.db.ColorMode ~= "theme" and
            self.db.ColorModeQuest ~= "theme" and
            self.db.ColorModeRested ~= "theme" then
            return
        end

        self:ApplySettings()
    end)

    -- Player is already max level, there is no XP to track, so skip building the bar and registering events entirely.
    if UnitLevel('player') >= GetMaxLevelForPlayerExpansion() then return end

    self:CreateBar()
    self:ApplySettings()

    self:RegisterEvent('UPDATE_EXHAUSTION', 'Update')
    self:RegisterEvent('PLAYER_ENTERING_WORLD')
    self:RegisterEvent('PLAYER_XP_UPDATE')
    self:RegisterEvent('PLAYER_LEVEL_UP')
    self:RegisterEvent('QUEST_LOG_UPDATE')
    self:RegisterEvent('TIME_PLAYED_MSG')

    EM:Register(self, 'ExperienceBar', self.coreFrame, 'XPBar')
end

function XPBar:OnDisable()
    self.previewActive = false
    if self.coreFrame then
        self.coreFrame:Hide()
        if self.themeSub then
            self.themeSub()
            self.themeSub = nil
        end
    end
end

function XPBar:ShowPreview()
    self.previewActive = true

    -- At max level the bar is never built during play, so create and register it on demand for the preview.
    if not self.coreFrame then
        self:CreateBar()
        self:ApplySettings()
        EM:Register(self, 'ExperienceBar', self.coreFrame, 'XPBar')
    end

    self:Render(self:GetPreviewData())
end

function XPBar:HidePreview()
    self.previewActive = false
    if not self.coreFrame then return end
    self:Update() -- Restore live data, or re-hide if the player is max level.
end

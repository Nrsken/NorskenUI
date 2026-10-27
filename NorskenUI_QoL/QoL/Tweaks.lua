---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class TweaksModule
local Tweaks = NRSKNUI:GetModule('Tweaks')
function Tweaks:UpdateDB() self.db = self.namespace.profile end

local GetAchievementInfo = GetAchievementInfo
local select = select
local ipairs = ipairs
local _G = _G

local GetNumQuestWatches = C_QuestLog and C_QuestLog.GetNumQuestWatches
local GetQuestIDForQuestWatchIndex = C_QuestLog and C_QuestLog.GetQuestIDForQuestWatchIndex
local GetLogIndexForQuestID = C_QuestLog and C_QuestLog.GetLogIndexForQuestID
local GetInfo = C_QuestLog and C_QuestLog.GetInfo
local RemoveQuestWatch = C_QuestLog and C_QuestLog.RemoveQuestWatch

local GetTrackedIDs = C_ContentTracking and C_ContentTracking.GetTrackedIDs
local StopTracking = C_ContentTracking and C_ContentTracking.StopTracking

local enterclicks = {
    'ABANDON_QUEST',
    'ABANDON_QUEST_WITH_ITEMS',
    'CONFIRM_PURCHASE_NONREFUNDABLE_ITEM',
}

-- Confirm Popups with Enter
function Tweaks:SetEnterAccept()
    if self.db.EnterAccept then
        local function SetTrueSafely(object, key)
            TextureLoadingGroupMixin.AddTexture({ textures = object }, key)
        end

        for _, name in ipairs(enterclicks) do
            local dialog = StaticPopupDialogs[name]
            if dialog then
                SetTrueSafely(dialog, 'enterClicksFirstButton')
            end
        end
    end
end

-- Hide Talking Head Frame
function Tweaks:SetupTalkingHeadHider()
    if not self.db.HideTalkingHead or self._talkingHeadHooked then return end

    local talkingHead = _G.TalkingHeadFrame
    if not talkingHead then return end
    self._talkingHeadHooked = true

    -- CloseImmediately over Hide(), it also stops the voice-over and clears isPlaying.
    self:SecureHook(talkingHead, 'PlayCurrent', function(frame)
        if Tweaks.db.HideTalkingHead then frame:CloseImmediately() end
    end)
end

-- Hide Boss Banner
function Tweaks:ToggleHideBossBanner()
    local banner = _G.BossBanner
    if not banner then return end

    -- Drive registration from the setting so toggling off restores the banner.
    if self.db.HideBossBanner then
        banner:UnregisterEvent('ENCOUNTER_LOOT_RECEIVED')
        banner:UnregisterEvent('BOSS_KILL')
    else
        banner:RegisterEvent('ENCOUNTER_LOOT_RECEIVED')
        banner:RegisterEvent('BOSS_KILL')
    end
end

function Tweaks:ToggleWhisperSounds()
    if self.db.WhisperSounds.Enabled then
        self:RegisterEvent('CHAT_MSG_WHISPER', function() NRSKNUI:PlaySafeSound(self.db.WhisperSounds.WhisperSound) end)
        self:RegisterEvent('CHAT_MSG_BN_WHISPER',
            function() NRSKNUI:PlaySafeSound(self.db.WhisperSounds.BNetWhisperSound) end)
    else
        self:UnregisterEvent('CHAT_MSG_WHISPER')
        self:UnregisterEvent('CHAT_MSG_BN_WHISPER')
    end
end

-- Blizzard Bug Fixes
function Tweaks:FixBlizzardBugs()
    if not self.db.FixBlizzardBugs or self._bugsFixed then return end
    self._bugsFixed = true

    -- Hidden quests can stay tracked and fill watch slots.
    for index = GetNumQuestWatches(), 1, -1 do
        local questID = GetQuestIDForQuestWatchIndex(index)
        local logIndex = questID and GetLogIndexForQuestID(questID)
        local info = logIndex and GetInfo(logIndex)

        if info and info.isHidden then
            RemoveQuestWatch(questID)
        end
    end

    -- Completed achievements can stay tracked but never show.
    local achievement = Enum.ContentTrackingType.Achievement
    for _, id in ipairs(GetTrackedIDs(achievement)) do
        if select(4, GetAchievementInfo(id)) then
            StopTracking(achievement, id, Enum.ContentTrackingStopType.Manual)
        end
    end

    -- Resetting the dressing room un-maximizes it.
    EventUtil.ContinueOnAddOnLoaded('Blizzard_UIPanels_Game', function()
        _G.DressUpFrameResetButton:HookScript('OnClick', function()
            local maximize = _G.DressUpFrame.MaximizeMinimizeFrame
            if maximize:IsMinimized() then maximize:Maximize() end
        end)
    end)
end

function Tweaks:ApplySettings()
    if not self.db.Enabled then return end

    self:FixBlizzardBugs()
    self:SetEnterAccept()
    self:SetupTalkingHeadHider()
    self:ToggleHideBossBanner()
    self:ToggleWhisperSounds()
end

function Tweaks:OnEnable()
    self:ApplySettings()
end

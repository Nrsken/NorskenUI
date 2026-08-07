---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class TweaksModule
local Tweaks = NRSKNUI:GetModule('Tweaks')

local ipairs = ipairs
local _G = _G

function Tweaks:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.Tweaks
end

-- Confirm Popups with Enter
function Tweaks:SetEnterAccept()
    if self.db.EnterAccept then
        local function SetTrueSafely(object, key)
            TextureLoadingGroupMixin.AddTexture({ textures = object }, key)
        end

        local enterclicks = {
            'ABANDON_QUEST',
            'ABANDON_QUEST_WITH_ITEMS',
        }

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
    self._talkingHeadHooked = true

    local function HideTalkingHeadFrame(frame)
        if Tweaks.db.HideTalkingHead and frame then
            frame:Hide()
        end
    end

    -- If the TalkingHeadFrame is already loaded, hook it immediately. Otherwise, wait for it to load.
    local TalkingHeadFrame = _G.TalkingHeadFrame
    if TalkingHeadFrame then
        self:SecureHook(TalkingHeadFrame, 'PlayCurrent', HideTalkingHeadFrame)
        self:SecureHook(TalkingHeadFrame, 'Reset', HideTalkingHeadFrame)
    else
        self:SecureHook('TalkingHead_LoadUI', function()
            if TalkingHeadFrame then
                self:SecureHook(TalkingHeadFrame, 'PlayCurrent', HideTalkingHeadFrame)
                self:SecureHook(TalkingHeadFrame, 'Reset', HideTalkingHeadFrame)
            end
        end)
    end
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
        self:RegisterEvent('CHAT_MSG_BN_WHISPER', function() NRSKNUI:PlaySafeSound(self.db.WhisperSounds.BNetWhisperSound) end)
    else
        self:UnregisterEvent('CHAT_MSG_WHISPER')
        self:UnregisterEvent('CHAT_MSG_BN_WHISPER')
    end
end

function Tweaks:ApplySettings()
    if not self.db.Enabled then return end

    self:SetEnterAccept()
    self:SetupTalkingHeadHider()
    self:ToggleHideBossBanner()
    self:ToggleWhisperSounds()
end

function Tweaks:OnEnable()
    self:ApplySettings()
end

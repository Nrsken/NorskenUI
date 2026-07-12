---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class Tweaks
local Tweaks = NRSKNUI:GetModule('Tweaks')

local pairs = pairs
local _G = _G

function Tweaks:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.Tweaks
end

function Tweaks:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

-- Confirm Popups with Enter
function Tweaks:SetEnterAccept()
    if self.db.EnterAccept then
        local function SetTrueSafely(object, key)
            TextureLoadingGroupMixin.AddTexture({ textures = object }, key)
        end

        for key, dialog in pairs(StaticPopupDialogs) do
            SetTrueSafely(dialog, 'enterClicksFirstButton')
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
        banner:UnregisterEvent("ENCOUNTER_LOOT_RECEIVED")
        banner:UnregisterEvent("BOSS_KILL")
    else
        banner:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
        banner:RegisterEvent("BOSS_KILL")
    end
end

function Tweaks:ApplySettings()
    if not self.db.Enabled then return end

    self:SetEnterAccept()
    self:SetupTalkingHeadHider()
    self:ToggleHideBossBanner()
end

function Tweaks:OnEnable()
    if not self.db.Enabled then return end

    self:ApplySettings()
end

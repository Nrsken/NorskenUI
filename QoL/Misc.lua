-- NorskenUI namespace
local _, NRSKNUI = ...
local LSM = NRSKNUI.LSM

-- Localization Setup
local PlaySoundFile = PlaySoundFile
local CreateFrame = CreateFrame

-- Module locals
local whisperFrame = nil

-- Ensure Miscellaneous settings exist
local function EnsureMiscSettings()
    if not NRSKNUI.db or not NRSKNUI.db.profile then return false end
    NRSKNUI.db.profile.Miscellaneous = NRSKNUI.db.profile.Miscellaneous or {}
    NRSKNUI.db.profile.Miscellaneous.WhisperSounds = NRSKNUI.db.profile.Miscellaneous.WhisperSounds or {
        Enabled = false,
        WhisperSound = "None",
        BNetWhisperSound = "None",
    }
    return true
end

-- Play whisper sound
function NRSKNUI:PlayWhisperSound(soundName)
    if not soundName or soundName == "None" then return end
    if not EnsureMiscSettings() then return end

    -- Check if enabled
    local MiscDB = self.db.profile.Miscellaneous
    if not MiscDB.WhisperSounds.Enabled then return end

    -- Fetch sound file
    local file = LSM:Fetch("sound", soundName)
    if file then
        PlaySoundFile(file, "Master")
    end
end

-- Initialize whisper sounds
function NRSKNUI:InitializeWhisperSounds()
    if not EnsureMiscSettings() then return end
    local MiscDB = self.db.profile.Miscellaneous

    -- Create event frame if not exists
    if not whisperFrame then
        whisperFrame = CreateFrame("Frame")
    end

    -- Unregister first to avoid duplicates
    whisperFrame:UnregisterAllEvents()
    whisperFrame:SetScript("OnEvent", nil)

    -- Only register if enabled
    if MiscDB.WhisperSounds.Enabled then
        whisperFrame:RegisterEvent("CHAT_MSG_WHISPER")
        whisperFrame:RegisterEvent("CHAT_MSG_BN_WHISPER")

        -- Set event handler
        whisperFrame:SetScript("OnEvent", function(_, event)
            if event == "CHAT_MSG_WHISPER" then
                NRSKNUI:PlayWhisperSound(MiscDB.WhisperSounds.WhisperSound)
            elseif event == "CHAT_MSG_BN_WHISPER" then
                NRSKNUI:PlayWhisperSound(MiscDB.WhisperSounds.BNetWhisperSound)
            end
        end)
    end
end

-- Apply whisper sound settings
function NRSKNUI:ApplyWhisperSoundSettings()
    self:InitializeWhisperSounds()
end

-- Initialize Miscellaneous module
function NRSKNUI:InitializeMiscellaneous()
    self:InitializeWhisperSounds()
end

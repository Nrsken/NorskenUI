---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')

---Take Blizzard's raid frames off screen, if the profile asks for it.
local complete = false
function UF:HideBlizzardRaidFrames()
    if complete or not self.db.HideBlizzardRaidFrames then return end

    NRSKNUI:RunWhenSafe(function()
        local container = _G.CompactRaidFrameContainer
        local manager = _G.CompactRaidFrameManager

        if container then container:NUIBanish() end
        if manager then manager:NUIBanish() end

        -- The setting the raid utility itself reads, so it comes up off on the next login too.
        local SetSetting = _G.CompactRaidFrameManager_SetSetting
        if SetSetting then SetSetting('IsShown', '0') end

        -- Both halves are only there once Blizzard's raid UI has loaded, which may be the first time
        -- the player joins a group rather than login.
        complete = container ~= nil and manager ~= nil
    end)
end

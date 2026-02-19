-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Check for addon object
if not NorskenUI then
    error("Blizzard Raidmanager: Addon object not initialized. Check file load order!")
    return
end

-- Create module
---@class BlizzardRM: AceModule, AceEvent-3.0
local BRMG = NorskenUI:NewModule("BlizzardRM", "AceEvent-3.0")

-- Localization
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame

-- Module init
function BRMG:OnInitialize()
    self.db = NRSKNUI.db.profile.Skinning.BlizzardRM
    self:SetEnabledState(false)
end

-- Fade in function
local function FadeIn()
    if CompactRaidFrameManager._isMouseOver then return end
    CompactRaidFrameManager._isMouseOver = true
    local dur = BRMG.db.FadeInDuration
    if InCombatLockdown() then
        dur = 0.1 -- Force a faster fade in combat, make more sense to me since you want info faster
    end
    NRSKNUI:CombatSafeFade(CompactRaidFrameManager, 1, dur)
end

-- Fade out function
local function FadeOut()
    if not CompactRaidFrameManager._isMouseOver then return end
    CompactRaidFrameManager._isMouseOver = false

    -- Check if mouseover is currently enabled
    if not BRMG.db.FadeOnMouseOut then
        CompactRaidFrameManager:SetAlpha(1)
        return
    end

    -- Read current fade alpha from CompactRaidFrameManager
    NRSKNUI:CombatSafeFade(CompactRaidFrameManager, BRMG.db.Alpha, BRMG.db.FadeOutDuration)
end

-- Setup styling
function BRMG:SetupRaidManager()
    if not CompactRaidFrameManager or BRMG._raidManagerHooked then return end

    -- Apply Strata
    CompactRaidFrameManager:SetFrameStrata(self.db.Strata)

    -- Function to help with the need to set position when RaidFrameManager is toggled and initially on load
    local function ApplyPosition()
        local point, relTo, relPoint, x = CompactRaidFrameManager:GetPoint()
        if point then
            CompactRaidFrameManager:ClearAllPoints()
            CompactRaidFrameManager:SetPoint(point, relTo, relPoint, x, self.db.Position.YOffset)
        end
    end

    -- Hook fade updates if not already done
    if not BRMG._raidManagerHooked then
        CompactRaidFrameManager:HookScript("OnEnter", function()
            FadeIn()
        end)

        CompactRaidFrameManager:HookScript("OnLeave", function()
            if not MouseIsOver(CompactRaidFrameManager) then
                FadeOut()
            end
        end)

        hooksecurefunc("CompactRaidFrameManager_Toggle", function()
            ApplyPosition()
            if MouseIsOver(CompactRaidFrameManager) then
                FadeIn()
            else
                C_Timer.After(0.1, function()
                    if not MouseIsOver(CompactRaidFrameManager) then
                        FadeOut()
                    end
                end)
            end
        end)

        BRMG._raidManagerHooked = true
    end
    ApplyPosition()

    -- Initial state: fade it out if the mouse isn't there
    if not MouseIsOver(CompactRaidFrameManager) then
        CompactRaidFrameManager:SetAlpha(0)
        CompactRaidFrameManager._isMouseOver = false
    end
end

-- Module OnEnable
function BRMG:OnEnable()
    if not self.db.Enabled then return end
    C_Timer.After(1, function()
        BRMG:SetupRaidManager()
    end)
end

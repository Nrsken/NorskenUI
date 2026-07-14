---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class BlizzardRM: AceModule, AceEvent-3.0
local BRMG = NRSKNUI:NewModule("BlizzardRM", "AceEvent-3.0")

local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown

function BRMG:UpdateDB()
    self.db = NRSKNUI.db.profile.BlizzardRM
end

function BRMG:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

local function FadeIn()
    if not BRMG:IsEnabled() then return end
    if CompactRaidFrameManager._isMouseOver then return end
    CompactRaidFrameManager._isMouseOver = true
    local dur = BRMG.db.FadeInDuration
    if InCombatLockdown() then dur = 0.1 end
    --NRSKNUI:CombatSafeFade(CompactRaidFrameManager, 1, dur)
end

local function FadeOut()
    if not BRMG:IsEnabled() then return end
    if not CompactRaidFrameManager._isMouseOver then return end
    CompactRaidFrameManager._isMouseOver = false

    if not BRMG.db.FadeOnMouseOut then
        CompactRaidFrameManager:SetAlpha(1)
        return
    end

    --NRSKNUI:CombatSafeFade(CompactRaidFrameManager, BRMG.db.Alpha, BRMG.db.FadeOutDuration)
end

function BRMG:ApplyPosition()
    local point, relTo, relPoint, x = CompactRaidFrameManager:GetPoint()
    if point then
        CompactRaidFrameManager:ClearAllPoints()
        CompactRaidFrameManager:SetPoint(point, relTo, relPoint, x, self.db.Position.YOffset)
    end
end

function BRMG:SetupRaidManager()
    if not CompactRaidFrameManager or BRMG._raidManagerHooked then return end

    CompactRaidFrameManager:SetFrameStrata(self.db.Strata)

    if not BRMG._raidManagerHooked then
        CompactRaidFrameManager:HookScript("OnEnter", function()
            FadeIn()
        end)

        CompactRaidFrameManager:HookScript("OnLeave", function()
            if not CompactRaidFrameManager:IsMouseOver() then FadeOut() end
        end)

        hooksecurefunc("CompactRaidFrameManager_Toggle", function()
            if not BRMG:IsEnabled() then return end
            BRMG:ApplyPosition()
            if CompactRaidFrameManager:IsMouseOver() then
                FadeIn()
            else
                C_Timer.After(0.1, function()
                    if not CompactRaidFrameManager:IsMouseOver() then FadeOut() end
                end)
            end
        end)

        BRMG._raidManagerHooked = true
    end

    if not CompactRaidFrameManager:IsMouseOver() then
        CompactRaidFrameManager:SetAlpha(self.db.Alpha)
        CompactRaidFrameManager._isMouseOver = false
    end
end

function BRMG:ApplySettings()
    if NRSKNUI:ShouldNotLoadModule() then return end
    self:SetupRaidManager()
    self:ApplyPosition()
    if CompactRaidFrameManager then
        if self.db.FadeOnMouseOut then
            CompactRaidFrameManager:SetAlpha(self.db.Alpha)
        else
            CompactRaidFrameManager:SetAlpha(1)
        end
    end
end

function BRMG:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end
    if not self.db.Enabled then return end
    C_Timer.After(1, function() self:ApplySettings() end)
end

function BRMG:OnDisable()
    if CompactRaidFrameManager then
        CompactRaidFrameManager:SetAlpha(1)
        CompactRaidFrameManager._isMouseOver = nil
        CompactRaidFrameManager:SetFrameStrata("HIGH")
    end
end

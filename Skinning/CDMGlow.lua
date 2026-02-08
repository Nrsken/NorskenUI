-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("CDMGlow: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local CDMG = NRSKNUI.Addon:NewModule("CDMGlow", "AceEvent-3.0")

-- Localization
local hooksecurefunc = hooksecurefunc

-- Module init
function CDMG:OnInitialize()
    self.db = NRSKNUI.db.profile.Skinning.CDMGlow
    self:SetEnabledState(false)
end

-- Setup hook
local function SetupGlowHooks()
    if not CDMG.db.Enabled then return end
    if ActionButtonSpellAlertManager then
        if ActionButtonSpellAlertManager.ShowAlert then
            hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, button)
                button.SpellActivationAlert.ProcStartFlipbook:Hide() -- Hide proc glow animation
                button.SpellActivationAlert:SetFrameStrata("HIGH")   -- Set strata high so that the custom swipe in CDMOverlay.lua gets placed behind glow
                button.SpellActivationAlert.ProcLoop:Play()          -- Show the proc loop instead, 100x cleaner
            end)
        end
    end
end

-- Module OnEnable
function CDMG:OnEnable()
    if not self.db.Enabled then return end
    SetupGlowHooks()
end

-- Module OnDisable
function CDMG:OnDisable()
end

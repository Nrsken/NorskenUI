---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class SpellAlert: AceModule, AceEvent-3.0
local SA = NRSKNUI:NewModule("SpellAlert", "AceEvent-3.0")

local LS = NRSKNUI.Libs.LS

local C_Timer = C_Timer
local GetCVar = GetCVar
local SetCVar = SetCVar

local SpellActivationOverlayFrame = SpellActivationOverlayFrame

function SA:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.SpellAlert
end

function SA:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function SA:GetCurrentSettings()
    if self.db.UseGlobal then return self.db.Global end

    local specID = NRSKNUI.MySpec.id
    if specID and self.db.Specs[specID] then return self.db.Specs[specID] end
    return self.db.Global
end

function SA:EnsureSpecEntry(specID)
    if not specID then return end
    if not self.db.Specs[specID] then
        self.db.Specs[specID] = { Scale = self.db.Global.Scale, Alpha = self.db.Global.Alpha, }
    end
end

function SA:ApplySettings()
    if not self:IsEnabled() then return end
    if not SpellActivationOverlayFrame then return end

    local settings = self:GetCurrentSettings()
    if not settings then return end

    SetCVar("displaySpellActivationOverlays", 1)
    SetCVar("spellActivationOverlayOpacity", 1)

    SpellActivationOverlayFrame:SetScale(settings.Scale)
    SpellActivationOverlayFrame:SetAlpha(settings.Alpha)
end

function SA:OnEnable()
    if not self.db.Enabled then return end

    -- Save the original opacity to restore it later if module is turned off
    self.savedOpacity = GetCVar("spellActivationOverlayOpacity")

    C_Timer.After(1, function() self:ApplySettings() end)
    if LS then LS.RegisterPlayerSpecChange(self, function() if self:IsEnabled() then self:ApplySettings() end end) end
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function() C_Timer.After(0.5, function() self:ApplySettings() end) end)
end

function SA:OnDisable()
    self:UnregisterAllEvents()

    if LS then LS.UnregisterPlayerSpecChange(self) end

    -- Restore original opacity and scale when the module is disabled
    if self.savedOpacity then SetCVar("spellActivationOverlayOpacity", self.savedOpacity) end
    if SpellActivationOverlayFrame then SpellActivationOverlayFrame:SetScale(1.0) end
end

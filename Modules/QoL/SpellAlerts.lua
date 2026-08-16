---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SpellAlertModule
local SpellAlert = NRSKNUI:GetModule('SpellAlert')
function SpellAlert:UpdateDB() self.db = NRSKNUI.db.profile.Miscellaneous.SpellAlert end

local LS = NRSKNUI.Libs.LS

local _G = _G
local next = next
local ipairs = ipairs
local tonumber = tonumber

local GetCVar = C_CVar and C_CVar.GetCVar
local SetCVar = C_CVar and C_CVar.SetCVar
local GetSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
local GetSpecializationInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo

local OVERRIDDEN_CVARS = {
    'displaySpellActivationOverlays',
    'spellActivationOverlayOpacity',
}

---The active specialization, or nothing while the player has none. The name and icon are what the
---config shows so the scope the sliders write to is named rather than implied.
---@return integer? specID
---@return string? name
---@return number|string? icon
function SpellAlert:GetSpecInfo()
    local index = GetSpecialization()
    if not index or index <= 0 then return nil end

    local specID, name, _, icon = GetSpecializationInfo(index)
    return specID, name, icon
end

---@param specID integer?
function SpellAlert:EnsureSpecEntry(specID)
    if not specID then return end

    if not self.db.Specs[specID] then
        self.db.Specs[specID] = {
            Scale = self.db.Global.Scale,
            Alpha = self.db.Global.Alpha,
        }
    end
end

function SpellAlert:GetCurrentSettings()
    if self.db.UseGlobal then return self.db.Global end

    local specID = self:GetSpecInfo()
    self:EnsureSpecEntry(specID)

    return specID and self.db.Specs[specID] or self.db.Global
end

---Remembers the player's own CVars before the first override.
---@param settings NRSKNUI.DBProfile.Miscellaneous.SpellAlert.Global
function SpellAlert:CaptureCVars(settings)
    local saved = NRSKNUI.db.global.SpellAlertCVars
    if next(saved) then return end

    for _, cvar in ipairs(OVERRIDDEN_CVARS) do
        saved[cvar] = GetCVar(cvar)
    end

    -- Adopt the opacity that was already running so turning the module on is not a visible change on its own.
    if settings.Alpha == 1 then
        settings.Alpha = tonumber(saved.spellActivationOverlayOpacity) or 1
    end
end

function SpellAlert:RestoreCVars()
    local saved = NRSKNUI.db.global.SpellAlertCVars

    for _, cvar in ipairs(OVERRIDDEN_CVARS) do
        if saved[cvar] then
            SetCVar(cvar, saved[cvar])
        end
        saved[cvar] = nil
    end
end

function SpellAlert:ApplySettings()
    if not self:IsEnabled() then return end

    local frame = _G.SpellActivationOverlayFrame
    if not frame then return end

    local settings = self:GetCurrentSettings()
    if not settings then return end

    self:CaptureCVars(settings)

    SetCVar('displaySpellActivationOverlays', 1)
    SetCVar('spellActivationOverlayOpacity', 1)

    frame:SetScale(settings.Scale)
    frame:SetAlpha(settings.Alpha)
end

function SpellAlert:OnEnable()
    self:ApplySettings()

    LS.RegisterPlayerSpecChange(self, function() self:ApplySettings() end)
    self:RegisterMessage('NRSKNUI_WORLD_READY', 'ApplySettings')
end

function SpellAlert:OnDisable()
    LS.UnregisterPlayerSpecChange(self)

    local frame = _G.SpellActivationOverlayFrame
    if frame then
        frame:SetScale(1.0)
        frame:SetAlpha(1.0)
    end

    self:RestoreCVars()
end

---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
local LDS = NRSKNUI.Libs.LDS
local GUI = NRSKNUI.GUI
local AceDB = NRSKNUI.Libs.AceDB
local L = NRSKNUI.Libs.AL

local geterrorhandler = geterrorhandler
local format = string.format
local xpcall = xpcall

local profilesDiffered -- said at login, a message this early can go unseen

-- Lifecycle --

function NRSKNUI:OnInitialize()
    self.db = AceDB:New('NorskenUIDB', self:GetDefaultDB(), true)
    self:UpgradeSavedProfiles(self.db)

    LDS:EnhanceDatabase(self.db, 'NorskenUI')
    self.ProfileManager:SyncGlobalProfile()

    -- raw reads: these keys left the defaults, so only saved values exist
    local source = self:ChooseSharedSource(self.db.profiles, self.db:GetCurrentProfile(), self.db.sv.profileKeys)
    local adopted = self:AdoptSharedSettings(source and source.globalMedia, source and source.Colors, self.db.global.Language)
    profilesDiffered = adopted and source and self:SharedSettingsDiffer(self.db.profiles, source)

    -- before any module folder loads, so their locale files keep only the chosen language
    self:SetLanguage(self:GetSharedSettings().Language)

    self.db.char.Class = self.MyClass -- lets the profile page class-colour alts

    -- RefreshAllModules owns the whole sequence so there is one ordering to reason about
    local function OnProfileRefresh()
        -- one broken module mustn't cost the rest: fonts go after it, since styled strings hold module db blocks
        xpcall(function() self.ProfileManager:RefreshAllModules() end, geterrorhandler())
        -- a switch before OnEnable needs nothing, OnEnable registers on the profile it finds
        if self.launcherDB then
            self:RegisterLauncher(self.db.profile.Minimap)
        end
        self:DeferUntilUnrestricted(0, function() self:RefreshFontStyles() end)
        self.ProfileManager:PromptReload()
    end
    self.db.RegisterCallback(self, 'OnProfileChanged', OnProfileRefresh)
    self.db.RegisterCallback(self, 'OnProfileCopied', OnProfileRefresh)
    self.db.RegisterCallback(self, 'OnProfileReset', OnProfileRefresh)
end

function NRSKNUI:OnEnable()
    GUI:ApplyTheme()
    self:RegisterLauncher(self.db.profile.Minimap)
    -- what isn't an AceModule follows the theme from here
    GUI:OnThemeChanged(function()
        if self.Anchors:IsActive() then
            self.Anchors:RefreshTheme()
        end
    end)
    self:SetUIScale()

    if self.db.profile.Minimap.hideMessage ~= true then
        self:Print(format(L['%s to open the configuration window.'], self:ColorTextByTheme('/nui')))
    end
    if profilesDiffered then
        self:Print(L['Fonts, textures and colors now apply to every profile. Yours differed, so check them in Global Settings.'])
    end

    self.UFBlocked = self:ShouldNotLoadUF()
    self.ProfileManager:SettleRole()

    for name, aceModule in self:IterateModules() do
        if aceModule.db and aceModule.db.Enabled and not (aceModule.IsBlocked and aceModule:IsBlocked()) then
            self:EnableModule(name)
        end
    end

    self:RegisterEvent('PLAYER_ENTERING_WORLD')
    self:RegisterEvent('UI_SCALE_CHANGED')
    self:RegisterEvent('ACTIVE_PLAYER_SPECIALIZATION_CHANGED', function() self.ProfileManager:OnSpecChanged() end)
    self:RegisterMessage('NRSKNUI_SHARED_SETTINGS_CHANGED', 'ApplyToAllModules')
    self:RegisterMessage('NRSKNUI_WORLD_READY', function()
        self:UpdateInverseScale()

        -- only now can a profile change be the user's doing rather than the login sequence's
        self.ProfileManager:SetPromptsReady()
    end)
end

function NRSKNUI:PLAYER_ENTERING_WORLD()
    self:UnregisterEvent('PLAYER_ENTERING_WORLD')
    self.enteredWorld = true
    self:ApplyToAllModules()

    C_Timer.After(1, function() self:SendMessage('NRSKNUI_WORLD_READY') end)
end

-- Modules --

-- one shared function, so RunWhenSafe collapses repeat calls made during combat
local function ApplyAllModules()
    for _, aceModule in NRSKNUI:IterateModules() do
        if aceModule:IsEnabled() and aceModule.ApplySettings then
            aceModule:ApplySettings()
        end
    end
end

function NRSKNUI:ApplyToAllModules()
    self:RunWhenSafe(ApplyAllModules)
end

function NRSKNUI:ToggleModule(moduleName, enabled)
    if enabled then
        self:EnableModule(moduleName)
    else
        self:DisableModule(moduleName)
    end
    -- a module toggled on while the GUI is open joins the previews the open page calls for
    if self.PreviewManager then
        self.PreviewManager:Refresh()
    end
end

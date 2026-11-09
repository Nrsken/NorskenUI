---@class NRSKNUI
local NRSKNUI = select(2, ...)
local LDS = NRSKNUI.Libs.LDS
local GUI = NRSKNUI.GUI
local AceDB = NRSKNUI.Libs.AceDB
local L = NRSKNUI.Libs.AL

local InCombatLockdown = InCombatLockdown
local geterrorhandler = geterrorhandler
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local format = string.format
local PlaySound = PlaySound
local CopyTable = CopyTable
local GetText = GetText
local xpcall = xpcall
local ipairs = ipairs
local pairs = pairs

local MACROS = MACROS
local GAMEMENU_SUPPORT = GAMEMENU_SUPPORT

local after = C_Timer and C_Timer.After

local profilesDiffered -- said at login, a message this early can go unseen

-- Global to profile scope migration --

-- Moved from global to profile scope.
local SCOPE_MOVED_KEYS = { 'Theme', 'UIScale', 'AuraIndicators', 'AuraIndicatorGroups' }

---@param db NRSKNUI.DBObject
local function RunProfileScopeMigration(db)
    if db.global.ProfileScopeMigrated then return end

    for _, key in ipairs(SCOPE_MOVED_KEYS) do
        local old = db.global[key]
        -- Overwrite, never skip, AceDB already seeded the active profile with the new defaults.
        if old ~= nil then
            for _, profile in pairs(db.profiles) do
                profile[key] = CopyTable(old)
            end
            db.global[key] = nil
        end
    end

    db.global.ProfileScopeMigrated = true
end

-- Load conditions migrations --

---@param db NRSKNUI.DBObject
local function RunLoadEnableMigration(db)
    if db.global.LoadEnableDropped then return end

    -- the raw save, so namespaces and profiles other than the active one come along
    NRSKNUI.LoadConditions:DropEnableToggle(db.sv)
    db.global.LoadEnableDropped = true
end

---@param db NRSKNUI.DBObject
local function RunLoadCombatMigration(db)
    if db.global.LoadCombatMoved then return end

    NRSKNUI.LoadConditions:MoveCombatToState(db.sv)
    db.global.LoadCombatMoved = true
end

-- OnInitialize: Called when the addon is initialized
function NRSKNUI:OnInitialize()
    self.db = AceDB:New('NorskenUIDB', self:GetDefaultDB(), true)

    RunProfileScopeMigration(self.db)
    RunLoadEnableMigration(self.db)
    RunLoadCombatMigration(self.db)

    LDS:EnhanceDatabase(self.db, 'NorskenUI')
    self.ProfileManager:SyncGlobalProfile()

    -- raw reads: these keys left the defaults, so only saved values exist
    local source = self:ChooseSharedSource(self.db.profiles, self.db:GetCurrentProfile(), self.db.sv.profileKeys)
    local adopted = self:AdoptSharedSettings(source and source.globalMedia, source and source.Colors, self.db.global.Language)
    profilesDiffered = adopted and source and self:SharedSettingsDiffer(self.db.profiles, source)

    -- before any module folder loads, so their locale files keep only the chosen language
    self:SetLanguage(self:GetSharedSettings().Language)

    self.db.char.Class = self.MyClass -- lets the profile page class-colour alts

    -- Load the shared colors
    self:LoadCustomColors()
    self:RefreshCurves()
    self:RefreshAuraDurationFormatter()

    -- Profile change callbacks. RefreshAllModules owns the whole sequence so there is exactly one
    -- ordering to reason about, and it re-points every module db before anything reads one.
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

-- One shared function, so RunWhenSafe collapses repeat calls made during combat.
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

-- Live GUI edits fire many times a second; re-applying every module on each one drops frames.
local APPLY_SETTLE_DELAY = 0.15
local queuedApply

function NRSKNUI:QueueApplyToAllModules()
    if queuedApply then queuedApply:Cancel() end
    queuedApply = C_Timer.NewTimer(APPLY_SETTLE_DELAY, function()
        queuedApply = nil
        self:ApplyToAllModules()
    end)
end

function NRSKNUI:ToggleModule(moduleName, enabled)
    if enabled then
        self:EnableModule(moduleName)
    else
        self:DisableModule(moduleName)
    end
    if self.PreviewManager then self.PreviewManager:Refresh() end -- A module toggled on while the GUI is open joins the previews the open page calls for.
end

function NRSKNUI:PLAYER_ENTERING_WORLD()
    self:UnregisterEvent('PLAYER_ENTERING_WORLD')
    self.enteredWorld = true
    self:ApplyToAllModules()

    after(1, function() self:SendMessage('NRSKNUI_WORLD_READY') end)
end

-- Game menu entry, kept out of Blizzard's button pool so its pooled buttons never carry our taint.
function NRSKNUI:SetupGameMenuButton()
    EventUtil.ContinueOnAddOnLoaded('Blizzard_GameMenu', function()
        local menu = _G.GameMenuFrame
        local button = CreateFrame('Button', 'NRSKNUI_GameMenuButton', menu, 'MainMenuFrameButtonTemplate')
        button:SetScript('OnClick', function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
            menu:CloseMenu()
            NRSKNUI:OpenOptions()
        end)

        -- Layout re-anchors every pooled button from scratch, so this slots in below Macros each time.
        hooksecurefunc(menu, 'Layout', function()
            local anchor
            for menuButton in menu.buttonPool:EnumerateActive() do
                local text = menuButton:GetText()
                if text == MACROS or (text == GAMEMENU_SUPPORT and not anchor) then anchor = menuButton end
            end
            -- A secure frame anchored to the menu protects it, and resizing it is blocked in combat.
            if not anchor or (InCombatLockdown() and menu:IsProtected()) then
                button:Hide()
                return
            end

            local height = anchor:GetHeight()
            button:SetText(NRSKNUI:GetTitle()) -- per open, so a theme change shows
            button:SetSize(anchor:GetWidth(), height)
            button:ClearAllPoints()
            button:SetPoint('TOP', anchor, 'BOTTOM')
            button:Show()

            for menuButton in menu.buttonPool:EnumerateActive() do
                if menuButton.layoutIndex > anchor.layoutIndex then
                    menuButton:AdjustPointsOffset(0, -height)
                end
            end
            menu:SetHeight(menu:GetHeight() + height)
        end)
    end)
end

function NRSKNUI:OnEnable()
    GUI:ApplyTheme()
    self:RegisterLauncher(self.db.profile.Minimap)
    GUI:OnThemeChanged(function() -- None AceModules go into here.
        if self.Anchors:IsActive() then
            self.Anchors:RefreshTheme()
        end
    end)

    self:SetupGameMenuButton()
    self:SetUIScale()

    -- Show login message if enabled
    if self.db.profile.Minimap.hideMessage ~= true then
        self:Print(format(L['%s to open the configuration window.'], self:ColorTextByTheme('/nui')))
    end
    if profilesDiffered then
        self:Print(L['Fonts, textures and colors now apply to every profile. Yours differed, so check them in Global Settings.'])
    end

    self.UFBlocked = self:ShouldNotLoadUF()
    self.ProfileManager:SettleRole()

    -- Automatically enable modules based on their saved settings.
    for name, aceModule in self:IterateModules() do
        if aceModule.db and aceModule.db.Enabled and not (aceModule.IsBlocked and aceModule:IsBlocked()) then
            self:EnableModule(name)
        end
    end

    -- Event Registration
    self:RegisterEvent('PLAYER_ENTERING_WORLD')
    self:RegisterEvent('UI_SCALE_CHANGED')
    self:RegisterEvent('ACTIVE_PLAYER_SPECIALIZATION_CHANGED', function() self.ProfileManager:OnSpecChanged() end)
    self:RegisterMessage('NRSKNUI_SHARED_SETTINGS_CHANGED', 'QueueApplyToAllModules')
    self:RegisterMessage('NRSKNUI_WORLD_READY', function()
        self:UpdateInverseScale()

        -- Only now can a profile change be the user's doing rather than the login sequence's.
        self.ProfileManager:SetPromptsReady()
    end)
end

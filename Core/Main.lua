---@class NRSKNUI
---@field MyGUID string?
local NRSKNUI = select(2, ...)
local LDB = NRSKNUI.Libs.LDB
local LDBIcon = NRSKNUI.Libs.LDBIcon
local LDS = NRSKNUI.Libs.LDS
local GUI = NRSKNUI.GUI
local AceDB = NRSKNUI.Libs.AceDB
local L = NRSKNUI.Libs.AL

local UnitGUID = UnitGUID
local format = string.format
local after = C_Timer and C_Timer.After

local LDBIconPath = 'Interface\\AddOns\\NorskenUI\\Media\\Logo\\logocookingsPT1128x128OTBRED.png'

---Print message with class colored addon name prefix
function NRSKNUI:Print(msg)
    print(self:ColorTextByTheme('Norsken') .. 'UI:|r ' .. msg)
end

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

-- OnInitialize: Called when the addon is initialized
function NRSKNUI:OnInitialize()
    self.MyGUID = UnitGUID('player')

    self.db = AceDB:New('NorskenUIDB', self:GetDefaultDB(), true)

    -- before any module folder loads, so their locale files keep only the chosen language
    self:SetLanguage(self.db.global.Language)

    RunProfileScopeMigration(self.db)

    LDS:EnhanceDatabase(self.db, 'NorskenUI')
    self.ProfileManager:SyncGlobalProfile()
    self.db.char.Class = self.MyClass -- lets the profile page class-colour alts

    -- Load custom colors from the profile
    self:LoadCustomColors()
    self:RefreshCurves()
    self:RefreshAuraDurationFormatter()

    -- Profile change callbacks. RefreshAllModules owns the whole sequence so there is exactly one
    -- ordering to reason about, and it re-points every module db before anything reads one.
    local function OnProfileRefresh()
        self.ProfileManager:RefreshAllModules()
        self.ProfileManager:PromptReload()
    end
    self.db.RegisterCallback(self, 'OnProfileChanged', OnProfileRefresh)
    self.db.RegisterCallback(self, 'OnProfileCopied', OnProfileRefresh)
    self.db.RegisterCallback(self, 'OnProfileReset', OnProfileRefresh)

    self:UpdateMult()
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

local function SetupMinimapIcon()
    local Theme = NRSKNUI.Theme
    local MyLDB = LDB:NewDataObject('NorskenUI', {
        type = 'launcher',
        text = 'NorskenUI',
        icon = LDBIconPath,
        iconR = Theme.accent[1],
        iconG = Theme.accent[2],
        iconB = Theme.accent[3],
        OnClick = function(_, button)
            if button == 'LeftButton' then
                NRSKNUI:ToggleOptions()
            elseif button == 'RightButton' then
                if NRSKNUI.Anchors then
                    NRSKNUI.Anchors:Toggle()
                end
            elseif button == 'MiddleButton' then
                NRSKNUI:ResetGUIState()
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine(NRSKNUI:ColorTextByTheme('Norsken') .. '|cffb3b3b3UI|r')
            tt:AddLine(L['Left-Click to open options'], 0.70, 0.70, 0.70)
            tt:AddLine(L['Right-Click to toggle anchors'], 0.70, 0.70, 0.70)
            tt:AddLine(L['Middle-Click to reset the options window position'], 0.70, 0.70, 0.70)
        end,
    })
    local minimapDB = NRSKNUI.db.profile.Minimap
    ---@cast minimapDB LibDBIcon.button.DB
    LDBIcon:Register('NorskenUI', MyLDB, minimapDB)
end

function NRSKNUI:PLAYER_ENTERING_WORLD()
    self:UnregisterEvent('PLAYER_ENTERING_WORLD')
    self.enteredWorld = true
    self:ApplyToAllModules()

    after(1, function() self:SendMessage('NRSKNUI_WORLD_READY') end)
end

function NRSKNUI:OnEnable()
    GUI:ApplyTheme()
    GUI:OnThemeChanged(function() -- None AceModules go into here.
        if self.Anchors:IsActive() then self.Anchors:RefreshTheme() end
    end)

    self:SetupSlashCommands()
    self:SetupGameMenuButton()
    self:SetUIScale()

    -- Show login message if enabled
    if self.db.profile.Minimap.hideMessage ~= true then
        self:Print(format(L['%s to open the configuration window.'], self:ColorTextByTheme('/nui')))
    end

    self.UFBlocked = self:ShouldNotLoadUF()

    -- Automatically enable modules based on their saved settings.
    for name, aceModule in self:IterateModules() do
        if aceModule.db and aceModule.db.Enabled and not (aceModule.IsBlocked and aceModule:IsBlocked()) then
            self:EnableModule(name)
        end
    end

    -- Event Registration
    self:RegisterEvent('PLAYER_ENTERING_WORLD')
    self:RegisterEvent('UI_SCALE_CHANGED', 'ChangedScaleEvent')
    self:RegisterMessage('NRSKNUI_WORLD_READY', function()
        SetupMinimapIcon()
        self:UpdateValues()

        -- Only now can a profile change be the user's doing rather than the login sequence's.
        self.ProfileManager:SetPromptsReady()
    end)
end

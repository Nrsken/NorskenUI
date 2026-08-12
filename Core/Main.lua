---@class NRSKNUI
local NRSKNUI = select(2, ...)
local LDB = NRSKNUI.Libs.LDB
local LDBIcon = NRSKNUI.Libs.LDBIcon
local LDS = NRSKNUI.Libs.LDS
local GUI = NRSKNUI.GUI
local AceDB = NRSKNUI.Libs.AceDB

local UnitGUID = UnitGUID
local after = C_Timer and C_Timer.After

local LDBIconPath = 'Interface\\AddOns\\NorskenUI\\Media\\Logo\\logocookingsPT1128x128OTBRED.png'

---Print message with class colored addon name prefix
function NRSKNUI:Print(msg)
    print(self:ColorTextByTheme('Norsken') .. 'UI:|r ' .. msg)
end

-- OnInitialize: Called when the addon is initialized
function NRSKNUI:OnInitialize()
    self.MyGUID = UnitGUID('player')

    self.db = AceDB:New('NorskenUIDB', self:GetDefaultDB(), true)
    ---@cast self.db NRSKNUI.DBObject

    LDS:EnhanceDatabase(self.db, 'NorskenUI')

    local CheckDualSpecState = self.db.CheckDualSpecState
    self.db.CheckDualSpecState = function(db)
        if self.db.global.UseGlobalProfile then return end
        return CheckDualSpecState(db)
    end

    if self.db.global.UseGlobalProfile then
        local profileName = self.db.global.GlobalProfile or 'Default'
        self.db:SetProfile(profileName)
    end

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

    self:ApplyGlobalFontVars()
    self:UpdateMult()
end

function NRSKNUI:ApplyToAllModules()
    self:RunWhenSafe(function()
        for _, aceModule in self:IterateModules() do
            if aceModule:IsEnabled() and aceModule.ApplySettings then
                aceModule:ApplySettings()
            end
        end
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
                if NRSKNUI.GUIFrame then
                    NRSKNUI.GUIFrame:Toggle()
                end
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
            tt:AddLine('Left-Click to open options', 0.70, 0.70, 0.70)
            tt:AddLine('Right-Click to toggle anchors', 0.70, 0.70, 0.70)
            tt:AddLine('Middle-Click to reset the options window position', 0.70, 0.70, 0.70)
        end,
    })
    local minimapDB = NRSKNUI.db.profile.Minimap
    ---@cast minimapDB LibDBIcon.button.DB
    LDBIcon:Register('NorskenUI', MyLDB, minimapDB)
end

function NRSKNUI:PLAYER_ENTERING_WORLD()
    self:UnregisterEvent('PLAYER_ENTERING_WORLD')
    self:ApplyToAllModules()

    after(1, function() self:SendMessage('NRSKNUI_WORLD_READY') end)
end

function NRSKNUI:OnEnable()
    GUI:ApplyTheme()
    GUI:OnThemeChanged(function() -- None AceModules go into here.
        if self.Anchors:IsActive() then self.Anchors:RefreshTheme() end
    end)

    self:SetupSlashCommands()
    self:SetUIScale()
    self:ApplyBlizzardFonts()

    -- Show login message if enabled
    if self.db.profile.Minimap.hideMessage ~= true then
        self:Print(self:ColorTextByTheme('/nui') .. ' to open the configuration window.')
    end

    self.UFBlocked = self:ShouldNotLoadUF()

    -- Automatically enable modules based on their saved settings.
    for name, aceModule in self:IterateModules() do
        if aceModule.db and aceModule.db.Enabled and not (self.UFBlocked and name == 'UnitFrames') then
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

---@class NRSKNUI
local NRSKNUI = select(2, ...)

local UnitGUID = UnitGUID

local LDB = NRSKNUI.Libs.LDB
local LDBIcon = NRSKNUI.Libs.LDBIcon
local LDS = NRSKNUI.Libs.LDS
local GUI = NRSKNUI.GUI

---Print message with class colored addon name prefix
function NRSKNUI:Print(msg)
    print(self:ColorTextByTheme("Norsken") .. "UI:|r " .. msg)
end

-- OnInitialize: Called when the addon is initialized
function NRSKNUI:OnInitialize()
    self.MyGUID = UnitGUID('player') -- Player GUID is not reliably available at file-scope load time

    self.db = self.Libs.AceDB:New("NorskenUIDB", self:GetDefaultDB(), true)
    ---@cast self.db NRSKNUI.DBObject

    LDS:EnhanceDatabase(self.db, "NorskenUI")
    -- Hook CheckDualSpecState to skip spec-based switching when global profile is active
    local originalCheckDualSpecState = self.db.CheckDualSpecState
    self.db.CheckDualSpecState = function(db)
        if self.db.global.UseGlobalProfile then return end
        originalCheckDualSpecState(db)
    end

    if self.db.global.UseGlobalProfile then
        local profileName = self.db.global.GlobalProfile or "Default"
        self.db:SetProfile(profileName)
    end

    -- Aura filters live in db.global, so this only needs running once per session.
    self.AuraFilters:Migrate()

    -- Load custom colors from the profile
    self:LoadCustomColors()
    self:RefreshCurves()
    self:RefreshAuraDurationFormatter()

    -- Profile change callbacks
    local function OnProfileRefresh()
        self:LoadCustomColors()
        self:RefreshCurves()
        self:RefreshAuraDurationFormatter()
        self:ApplyBlizzardFonts(true)
        self.ProfileManager:RefreshAllModules()
    end
    self.db.RegisterCallback(self, "OnProfileChanged", OnProfileRefresh)
    self.db.RegisterCallback(self, "OnProfileCopied", OnProfileRefresh)
    self.db.RegisterCallback(self, "OnProfileReset", OnProfileRefresh)

    self:ApplyGlobalFontVars()
    self:UpdateMult()
end

function NRSKNUI:ApplyToAllModules()
    self:RunWhenSafe(function()
        for _, module in self:IterateModules() do
            if module:IsEnabled() and module.ApplySettings then
                module:ApplySettings()
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
end

local function SetupMinimapIcon()
    local Theme = NRSKNUI.Theme
    local MyLDB = LDB:NewDataObject("NorskenUI", {
        type = "launcher",
        text = "NorskenUI",
        icon = "Interface\\AddOns\\NorskenUI\\Media\\Logo\\logocookingsPT1128x128OTBRED.png",
        iconR = Theme.accent[1],
        iconG = Theme.accent[2],
        iconB = Theme.accent[3],
        OnClick = function(_, button)
            if button == "LeftButton" then
                if NRSKNUI.GUIFrame then
                    NRSKNUI.GUIFrame:Toggle()
                end
            elseif button == "RightButton" then
                if NRSKNUI.Anchors then
                    NRSKNUI.Anchors:Toggle()
                end
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine(NRSKNUI:ColorTextByTheme("Norsken") .. "|cffb3b3b3UI|r")
            tt:AddLine("Left-Click to open options", 0.70, 0.70, 0.70)
            tt:AddLine("Right-Click to toggle anchors", 0.70, 0.70, 0.70)
        end,
    })
    local minimapDB = NRSKNUI.db.profile.Minimap
    ---@cast minimapDB LibDBIcon.button.DB
    LDBIcon:Register("NorskenUI", MyLDB, minimapDB)
end

local function OnPlayerEnteringWorld()
    NRSKNUI:ApplyToAllModules()
end

-- OnEnable: Called when the addon is enabled
function NRSKNUI:OnEnable()
    -- Method to fix old frame sizing data that messes up sidebar width
    local currentVersion = self:GetDefaultDB().global.GUIState.GUIFrameLayoutVersion or 1
    local rawState = _G.NorskenUIDB.global.GUIState
    if (rawState and rawState.GUIFrameLayoutVersion or 0) < currentVersion then
        local frame = self.db.global.GUIState.frame
        if frame then frame.width, frame.height = nil, nil end
        self.db.global.GUIState.GUIFrameLayoutVersion = currentVersion
    end

    -- Delay setting up the minimap icon so that AddonTheme.lua can load first.
    C_Timer.After(1, function()
        SetupMinimapIcon()
    end)

    GUI:ApplyTheme()
    GUI:OnThemeChanged(function() -- None AceModules go into here.
        if self.Anchors and self.Anchors:IsActive() then
            self.Anchors:RefreshTheme()
        end
    end)

    self:SetupSlashCommands()
    self:SetUIScale()
    self:ApplyBlizzardFonts()

    --self:TestEnv()

    -- Show login message if enabled
    if self.db.profile.Minimap.hideMessage ~= true then
        self:Print(self:ColorTextByTheme("/nui") .. " to open the configuration window.")
    end

    -- Resolved once here and never re-read, the other addon has already gutted the Blizzard frames
    -- and hooked their SetParent by now, so spawning ours later in the session would recurse into
    -- its hook until the C stack overflows. Ownership can only change on a fresh load.
    self.UFBlocked = self:ShouldNotLoadUF()

    -- Automatically enable modules based on their saved settings. A blocked UnitFrames never
    -- reaches OnEnable, so it constructs nothing and stays IsEnabled() == false.
    for name, module in self:IterateModules() do
        if module.db and module.db.Enabled and not (self.UFBlocked and name == 'UnitFrames') then
            self:EnableModule(name)
        end
    end

    -- Event Registration
    self:RegisterEvent("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld)
    self:RegisterEvent('UI_SCALE_CHANGED', 'ChangedScaleEvent')
end

---@class NRSKNUI
local NRSKNUI = select(2, ...)
local Theme = NRSKNUI.Theme

local UnitGUID = UnitGUID

local LDB = NRSKNUI.Libs.LDB
local LDBIcon = NRSKNUI.Libs.LDBIcon
local LDS = NRSKNUI.Libs.LDS

-- OnInitialize: Called when the addon is initialized
function NRSKNUI:OnInitialize()
    NRSKNUI.MyGUID = UnitGUID('player') -- Player GUID is not reliably available at file-scope load time

    NRSKNUI.db = NRSKNUI.Libs.AceDB:New("NorskenUIDB", NRSKNUI:GetDefaultDB(), true)

    LDS:EnhanceDatabase(NRSKNUI.db, "NorskenUI")
    -- Hook CheckDualSpecState to skip spec-based switching when global profile is active
    local originalCheckDualSpecState = NRSKNUI.db.CheckDualSpecState
    NRSKNUI.db.CheckDualSpecState = function(db)
        if NRSKNUI.db.global.UseGlobalProfile then return end
        originalCheckDualSpecState(db)
    end

    if NRSKNUI.db.global.UseGlobalProfile then
        local profileName = NRSKNUI.db.global.GlobalProfile or "Default"
        NRSKNUI.db:SetProfile(profileName)
    end

    -- Profile change callbacks (registered after the global-profile switch above,
    -- so that switch does not trigger a full module refresh during init)
    local function OnProfileRefresh()
        NRSKNUI:ValidateProfileFonts()
        NRSKNUI.ProfileManager:RefreshAllModules()
    end
    NRSKNUI.db.RegisterCallback(NRSKNUI, "OnProfileChanged", OnProfileRefresh)
    NRSKNUI.db.RegisterCallback(NRSKNUI, "OnProfileCopied", OnProfileRefresh)
    NRSKNUI.db.RegisterCallback(NRSKNUI, "OnProfileReset", OnProfileRefresh)

    -- Compute the pixel-perfect multiplier from the current UI scale
    NRSKNUI:UIMult()
end

local function SetupMinimapIcon()
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
                if NRSKNUI.EditMode then
                    NRSKNUI.EditMode:Toggle()
                end
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine(NRSKNUI:ColorTextByTheme("Norsken") .. "|cffb3b3b3UI|r")
            tt:AddLine("Left-Click to open options", 0.70, 0.70, 0.70)
            tt:AddLine("Right-Click to toggle anchors", 0.70, 0.70, 0.70)
        end,
    })
    LDBIcon:Register("NorskenUI", MyLDB, NRSKNUI.db.profile.Minimap)
end

local function OnPlayerEnteringWorld()
    -- Automatically refresh all AceAddon modules
    for _, module in NRSKNUI:IterateModules() do
        if module:IsEnabled() and module.ApplySettings then
            module:ApplySettings()
        end
    end
end

-- OnEnable: Called when the addon is enabled
function NRSKNUI:OnEnable()
    -- Method to fix old frame sizing data that messes up sidebar width
    local currentVersion = NRSKNUI:GetDefaultDB().global.GUIState.GUIFrameLayoutVersion or 1
    local rawState = _G.NorskenUIDB.global.GUIState
    if (rawState and rawState.GUIFrameLayoutVersion or 0) < currentVersion then
        local frame = NRSKNUI.db.global.GUIState.frame
        if frame then frame.width, frame.height = nil, nil end
        NRSKNUI.db.global.GUIState.GUIFrameLayoutVersion = currentVersion
    end

    NRSKNUI:RefreshTheme()
    SetupMinimapIcon()
    self:SetupSlashCommands()

    -- Show login message if enabled
    if NRSKNUI.db.profile.Minimap.LoginMessage ~= false then
        NRSKNUI:Print(NRSKNUI:ColorTextByTheme("/nui") .. " to open the configuration window.")
    end

    -- Automatically enable modules based on their saved settings
    for name, module in self:IterateModules() do
        if module.db and module.db.Enabled then
            self:EnableModule(name)
        end
    end

    -- Event Registration
    self:RegisterEvent("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld)
end

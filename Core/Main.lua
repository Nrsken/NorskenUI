-- NorskenUI namespace
local _, NRSKNUI = ...

-- Localization Setup
local IsInInstance = IsInInstance
local LSM = NRSKNUI.LSM
local LibStub = LibStub
local Theme = NRSKNUI.Theme

-- Constants
local DEFAULT_PROFILE = "Default"

-- Create the main addon object
local NorskenUI = LibStub("AceAddon-3.0"):NewAddon("NorskenUI", "AceEvent-3.0", "AceHook-3.0")
NRSKNUI.Addon = NorskenUI

-- Register media with LibSharedMedia
if LSM then
    LSM:Register("sound", "|cffe51039NorskenWhisper|r", [[Interface\AddOns\NorskenUI\Media\Sounds\Whisper.ogg]])
    LSM:Register("border", "WHITE8X8", [[Interface\Buttons\WHITE8X8]])
end

-- Encounter state
NRSKNUI.encounterActive = false

-- OnInitialize: Called when the addon is initialized
function NorskenUI:OnInitialize()
    local defaults = NRSKNUI:GetDefaultDB()
    if not defaults then
        defaults = { profile = {} }
    end
    NRSKNUI.db = LibStub("AceDB-3.0"):New("NorskenUIDB", defaults, true)
    if NRSKNUI.LDS then
        NRSKNUI.LDS:EnhanceDatabase(NRSKNUI.db, "NorskenUI")
    end
    if NRSKNUI.db.global and NRSKNUI.db.global.UseGlobalProfile then
        local profileName = NRSKNUI.db.global.GlobalProfile or DEFAULT_PROFILE
        NRSKNUI.db:SetProfile(profileName)
    end

    -- Setup minimap icon
    local LDB = NRSKNUI.LDB
    local LDBIcon = NRSKNUI.LDBIcon
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
            tt:AddLine(NRSKNUI:ColorTextByTheme("Norsken") .. "|cffffffffUI|r")
            tt:AddLine("Left-Click to open options", 1, 1, 1)
            tt:AddLine("Right-Click to open custom Edit Mode", 1, 1, 1)
        end,
    })

    -- Register minimap icon
    LDBIcon:Register("NorskenUI", MyLDB, NRSKNUI.db.profile.Minimap)
end

local function OnEncounterEnd()
    local _, instanceType = IsInInstance()
    if instanceType == "raid" and NRSKNUI.encounterActive then
        NRSKNUI.encounterActive = false
    end
end

local function OnEncounterStart()
    local _, instanceType = IsInInstance()
    if instanceType == "raid" then
        NRSKNUI.encounterActive = true
    end
end

local function OnPlayerEnteringWorld()
    -- Automatically refresh all AceAddon modules
    for name, module in NorskenUI:IterateModules() do
        if module:IsEnabled() and module.ApplySettings then
            module:ApplySettings()
        end
    end
end

-- OnEnable: Called when the addon is enabled
function NorskenUI:OnEnable()
    if NRSKNUI.RefreshTheme then NRSKNUI:RefreshTheme() end
    if NRSKNUI.Init then NRSKNUI:Init() end

    -- Old modules
    -- TODO: Update to aceaddon
    if NRSKNUI.InitializeMiscellaneous then NRSKNUI:InitializeMiscellaneous() end

    -- Automatically enable modules based on their saved settings
    for name, module in self:IterateModules() do
        if module.db and module.db.Enabled then
            self:EnableModule(name)
        end
    end

    -- Event Registration
    self:RegisterEvent("ENCOUNTER_END", OnEncounterEnd)
    self:RegisterEvent("ENCOUNTER_START", OnEncounterStart)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld)
end

---@class NRSKNUI : AceAddon-3.0, AceEvent-3.0, AceTimer-3.0, AceHook-3.0
---@field db NRSKNUI.DBObject
---@field Locale string
---@field L table<string, string> the registry, Core/Localization.lua
---@field AddOnName string?
---@field Version string?
---@field Author string?
---@field MyClass string
---@field MyClassID number
---@field MyName string
---@field MyRealm string
---@field MySpec NRSKNUI.MySpecData
---@field ClearTexture number
---@field WhiteTexture string
---@field GlobalZoom number
---@field Separators table<string, string>
---@field TimeFormats table<string, string>
---@field UFBlocked boolean resolved at login, true when another UI addon owns the unit frames
---@field Libs NRSKNUI.Libraries
---@field GUI KajiGUIInstance
---@field Theme KajiTheme
---@field CDMWindow KajiGUIWindow? the Cooldown & Aura Manager window, once the options have loaded
---@field PageWindows table<string, KajiGUIWindow>?
local NRSKNUI = select(2, ...)
local addonName = select(1, ...)

local _G = _G
local GetLocale = GetLocale
local UnitFullName = UnitFullName

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata

-- Create the addon object
local NorskenCore = _G.NorskenCore --[[@as NorskenCoreAPI]]
NorskenCore:NewAddon(NRSKNUI, addonName, 'AceEvent-3.0', 'AceTimer-3.0', 'AceHook-3.0')
_G.NorskenUI = NRSKNUI
NRSKNUI.Anchors = NorskenCore:NewAnchors(NRSKNUI)
NRSKNUI.PreviewManager = NorskenCore:NewPreviewManager(NRSKNUI)
_G.NorskenUIAPI = _G.NorskenUIAPI or {} -- Global API table for things we want to expose to other addons, like WagoUI Packs and profile installers.

NRSKNUI:SetDefaultModuleState(false)
local ModulePrototype = {}
function ModulePrototype:OnInitialize()
    -- a module with Defaults gets its own namespace; dbKey says where its settings sat in the profile before
    if self.Defaults then
        -- old formats get fixed while the settings still sit in the profile, before the namespace takes them
        if self.UpgradeSavedProfiles then
            self:UpgradeSavedProfiles(NRSKNUI.db)
        end
        self.namespace = NRSKNUI.ProfileManager:RegisterNamespace(self.moduleName, self.Defaults, self.dbKey)
    end
    if self.UpdateDB then
        self:UpdateDB()
    end
end

NRSKNUI:SetDefaultModulePrototype(ModulePrototype)

-- Setup addon constants
NRSKNUI.Locale = GetLocale()
NRSKNUI.AddOnName = GetAddOnMetadata(addonName, 'Title')
NRSKNUI.Version = GetAddOnMetadata(addonName, 'Version')
NRSKNUI.Author = GetAddOnMetadata(addonName, 'Author')
NRSKNUI.MyName, NRSKNUI.MyRealm = UnitFullName('player')
NRSKNUI:OnLanguageSet(function()
    NRSKNUI.Separators = {
        ['||'] = '|',
        ['-'] = '-',
        ['/'] = '/',
        [' '] = NRSKNUI.L['Space'],
        ['•'] = '•',
        ['>'] = '>',
        ['>>'] = '>>',
        ['»'] = '»',
    }
end)
NRSKNUI.TimeFormats = {
    ['MM:SS']  = '01:30',
    ['M:SS']   = '1:30',
    ['MmSs']   = '01m 30s',
    ['MmSs_c'] = '1m 30s',
    ['Ss']     = '90s',
    ['S']      = '90',
    ['Smart']  = '1m / 30s',
}

-- Setup libraries
NRSKNUI.Libs = {
    AceDB = _G.LibStub('AceDB-3.0'),
    LSM = _G.LibStub('LibSharedMedia-3.0'),
    LCG = _G.LibStub('LibCustomGlow-1.0'),
    LS = _G.LibStub('LibSpecialization'),
    LRC = _G.LibStub('LibRangeCheck-3.0'),
    AS = _G.LibStub('AceSerializer-3.0'),
    AL = NRSKNUI.L, -- our own registry (Core/Localization.lua), the language picker needs every locale
    LD = _G.LibStub('LibDeflate'),
    LDB = _G.LibStub('LibDataBroker-1.1'),
    LDBIcon = _G.LibStub('LibDBIcon-1.0'),
    LDS = _G.LibStub('LibDualSpec-1.0'),
    KAJI = _G.LibStub('LibKaji-1.0'),
}

do
    -- Convert GitHub version string to a more user-friendly format for display in the GUI.
    if NRSKNUI.Version == '@project-version@' then
        NRSKNUI.Version = 'Development Version'
    end

    -- Setup KAJI GUI & Utilities for NorskenUI
    local KAJI = NRSKNUI.Libs.KAJI
    NRSKNUI.GUI = KAJI:New({
        store = function()
            if not (NRSKNUI.db and NRSKNUI.db.profile) then return nil end
            return NRSKNUI.db.profile.Theme
        end,
        classColorProvider = function()
            return NRSKNUI:GetPlayerClassColor()
        end,
    })
    NRSKNUI.Theme = NRSKNUI.GUI:GetTheme()
end


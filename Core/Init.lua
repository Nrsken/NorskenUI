---@class NRSKNUI : AceAddon-3.0, AceEvent-3.0, AceTimer-3.0, AceHook-3.0
---@field db NRSKNUI.DBObject
---@field L table<string, string> the registry, Core/Localization.lua
---@field MyClass string
---@field MyClassID number
---@field MyName string
---@field MyRealm string
---@field MyGUID string
---@field MySpec NRSKNUI.MySpecData
---@field ClearTexture number
---@field WhiteTexture string
---@field GlobalZoom number
---@field UFBlocked boolean resolved at login, true when another UI addon owns the unit frames
---@field Libs NRSKNUI.Libraries
---@field GUI KajiGUIInstance
---@field Theme KajiTheme
---@field PageWindows table<string, KajiGUIWindow>?
local NRSKNUI = select(2, ...)
local addonName = select(1, ...)

local _G = _G

local NorskenCore = _G.NorskenCore --[[@as NorskenCoreAPI]]
NorskenCore:NewAddon(NRSKNUI, addonName, function() return NRSKNUI.db and NRSKNUI.db.profile.Theme end, 'AceEvent-3.0', 'AceTimer-3.0', 'AceHook-3.0')
_G.NorskenUI = NRSKNUI
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

-- Setup libraries
NRSKNUI.Libs = {
    AceDB = _G.LibStub('AceDB-3.0'),
    LSM = _G.LibStub('LibSharedMedia-3.0'),
    LS = _G.LibStub('LibSpecialization'),
    LRC = _G.LibStub('LibRangeCheck-3.0'),
    AS = _G.LibStub('AceSerializer-3.0'),
    AL = NRSKNUI.L, -- our own registry (Core/Localization.lua), the language picker needs every locale
    LD = _G.LibStub('LibDeflate'),
    LDB = _G.LibStub('LibDataBroker-1.1'),
    LDS = _G.LibStub('LibDualSpec-1.0'),
}

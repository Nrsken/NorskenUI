---@class NRSKNUI : AceAddon-3.0, AceEvent-3.0, AceTimer-3.0, AceHook-3.0
---@field db NRSKNUI.AceDB
local NRSKNUI = select(2, ...)
local addonName = select(1, ...)

local _G = _G
local GetLocale = GetLocale
local select = select
local UnitClass = UnitClass

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata

-- Create the addon object
local AceAddon = _G.LibStub('AceAddon-3.0')
AceAddon:NewAddon(NRSKNUI, addonName, 'AceEvent-3.0', 'AceTimer-3.0', 'AceHook-3.0')
_G.NorskenUI = NRSKNUI

-- Setup addon variables
NRSKNUI.Locale = GetLocale()
NRSKNUI.AddOnName = GetAddOnMetadata(addonName, "Title")
NRSKNUI.Version = GetAddOnMetadata(addonName, "Version")
NRSKNUI.Author = GetAddOnMetadata(addonName, "Author")
NRSKNUI.myclass = select(2, UnitClass('player'))
NRSKNUI.ClearTexture = 0

-- Setup libraries
NRSKNUI.Libs = {
    AceDB = _G.LibStub('AceDB-3.0'),
    LSM = _G.LibStub('LibSharedMedia-3.0'),
    LCG = _G.LibStub('LibCustomGlow-1.0'),
    LS = _G.LibStub('LibSpecialization'),
    LRC = _G.LibStub('LibRangeCheck-3.0'),
    AS = _G.LibStub('AceSerializer-3.0'),
    LD = _G.LibStub('LibDeflate'),
    LDB = _G.LibStub('LibDataBroker-1.1'),
    LDBIcon = _G.LibStub('LibDBIcon-1.0'),
    LDS = _G.LibStub('LibDualSpec-1.0'),
}

do
    -- Get player data via LibSpecialization and let the Lib handle changes.
    local LS = NRSKNUI.Libs.LS
    NRSKNUI.MySpec = {
        id = nil,
        role = nil,
        position = nil,
        talents = nil,
    }
    local function UpdateSpec()
        NRSKNUI.MySpec.id, NRSKNUI.MySpec.role, NRSKNUI.MySpec.position, NRSKNUI.MySpec.talents = LS.MySpecialization()
    end
    NRSKNUI:RegisterEvent("PLAYER_LOGIN", UpdateSpec) -- Update initial spec info on login
    LS.RegisterPlayerSpecChange(NRSKNUI, UpdateSpec)
end

-- Class Util Modules
NRSKNUI.BloodlustTracker = NRSKNUI:NewModule("BloodlustTracker", "AceEvent-3.0")
NRSKNUI.BurningRush = NRSKNUI:NewModule("BurningRush", "AceEvent-3.0")

-- Advanced Skinning Modules
NRSKNUI.Tooltips = NRSKNUI:NewModule('Tooltips', 'AceEvent-3.0')
NRSKNUI.Minimap = NRSKNUI:NewModule('Minimap', 'AceEvent-3.0')

-- Skinning Modules
NRSKNUI.Skinning = NRSKNUI:NewModule('Skinning', 'AceEvent-3.0')

-- Class Util Modules
NRSKNUI.Gateway = NRSKNUI:NewModule('Gateway', 'AceEvent-3.0')

-- Combat Modules
NRSKNUI.CombatTimer = NRSKNUI:NewModule("CombatTimer", "AceEvent-3.0")
NRSKNUI.PotionReady = NRSKNUI:NewModule("PotionReady", "AceEvent-3.0")
NRSKNUI.RangeChecker = NRSKNUI:NewModule("RangeChecker", "AceEvent-3.0")

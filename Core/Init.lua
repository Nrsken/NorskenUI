---@class NRSKNUI : AceAddon-3.0, AceEvent-3.0, AceTimer-3.0, AceHook-3.0
---@field db NRSKNUI.AceDB
local NRSKNUI = select(2, ...)
local addonName = select(1, ...)

local _G = _G
local GetLocale = GetLocale
local select = select
local UnitClass = UnitClass
local UnitFullName = UnitFullName
local assert = assert

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata

-- Create the addon object
local AceAddon = _G.LibStub('AceAddon-3.0')
AceAddon:NewAddon(NRSKNUI, addonName, 'AceEvent-3.0', 'AceTimer-3.0', 'AceHook-3.0')
_G.NorskenUI = NRSKNUI

-- Setup oUF library
NRSKNUI.oUF = _G.NorskenUF
NRSKNUI.oUFPrefix = GetAddOnMetadata(addonName, 'X-oUF')
assert(NRSKNUI.oUF, 'oUF library not found!')

-- Setup addon constants
NRSKNUI.Locale = GetLocale()
NRSKNUI.AddOnName = GetAddOnMetadata(addonName, 'Title')
NRSKNUI.Version = GetAddOnMetadata(addonName, 'Version')
NRSKNUI.Author = GetAddOnMetadata(addonName, 'Author')
NRSKNUI.MyClass = select(2, UnitClass('player'))
NRSKNUI.MyName, NRSKNUI.MyRealm = UnitFullName('player')
-- Texture and color constants
NRSKNUI.ClearTexture = 0
NRSKNUI.WhiteTexture = 'Interface\\Buttons\\WHITE8X8'
NRSKNUI.GlobalZoom = 0.3
-- Supported separator types.
NRSKNUI.Separators = {
    ['||'] = '|',
    ['-'] = '-',
    ['/'] = '/',
    [' '] = 'Space',
    ['•'] = '•',
    ['>'] = '>',
    ['>>'] = '>>',
    ['»'] = '»',
}
-- Time display formats.
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
    AL = _G.LibStub('AceLocale-3.0'):GetLocale('NorskenUI'),
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
    NRSKNUI:RegisterEvent('PLAYER_LOGIN', UpdateSpec) -- Update initial spec info on login
    LS.RegisterPlayerSpecChange(NRSKNUI, UpdateSpec)

    -- Setup KAJI GUI & Utilities for NorskenUI
    local KAJI = NRSKNUI.Libs.KAJI
    NRSKNUI.GUI = KAJI:New({
        store = function()
            if not (NRSKNUI.db and NRSKNUI.db.global) then return nil end
            NRSKNUI.db.global.Theme = NRSKNUI.db.global.Theme or {}
            return NRSKNUI.db.global.Theme
        end,
        classColorProvider = function()
            return NRSKNUI:GetPlayerClassColor()
        end,
    })
    NRSKNUI.Theme = NRSKNUI.GUI:GetTheme()
end

-- RestrictedActions Module
NRSKNUI.Restricted = NRSKNUI:NewModule('Restricted', 'AceEvent-3.0')

-- UnitFrames Module
NRSKNUI.UnitFrames = NRSKNUI:NewModule('UnitFrames', 'AceTimer-3.0', 'AceEvent-3.0', 'AceHook-3.0')

-- Quality of Life Modules
NRSKNUI.AuctionHouseFilter = NRSKNUI:NewModule('AuctionHouseFilter', 'AceEvent-3.0')
NRSKNUI.Automation = NRSKNUI:NewModule('Automation', 'AceEvent-3.0')
NRSKNUI.Tweaks = NRSKNUI:NewModule('Tweaks', 'AceEvent-3.0', 'AceHook-3.0')
NRSKNUI.XPBar = NRSKNUI:NewModule('XPBar', 'AceEvent-3.0')
NRSKNUI.CopyAnything = NRSKNUI:NewModule('CopyAnything', 'AceEvent-3.0')
NRSKNUI.Recuperate = NRSKNUI:NewModule('Recuperate', 'AceEvent-3.0')
NRSKNUI.MiscVars = NRSKNUI:NewModule('MiscVars', 'AceEvent-3.0')
NRSKNUI.Durability = NRSKNUI:NewModule('Durability', 'AceEvent-3.0')

-- Class Util Modules
NRSKNUI.BurningRush = NRSKNUI:NewModule('BurningRush', 'AceEvent-3.0')

-- Advanced Skinning Modules
NRSKNUI.Tooltips = NRSKNUI:NewModule('Tooltips', 'AceEvent-3.0')
NRSKNUI.Minimap = NRSKNUI:NewModule('Minimap', 'AceEvent-3.0')

-- Skinning Modules
NRSKNUI.Skinning = NRSKNUI:NewModule('Skinning', 'AceEvent-3.0')

-- Class Utility Modules
NRSKNUI.Gateway = NRSKNUI:NewModule('Gateway', 'AceEvent-3.0')
NRSKNUI.PetTexts = NRSKNUI:NewModule('PetTexts', 'AceEvent-3.0')

-- Player Auras
NRSKNUI.PlayerAuras = NRSKNUI:NewModule('PlayerAuras', 'AceEvent-3.0')
NRSKNUI.AdvancedDebuffs = NRSKNUI:NewModule('AdvancedDebuffs', 'AceEvent-3.0')
NRSKNUI.Defensives = NRSKNUI:NewModule('Defensives', 'AceEvent-3.0')

-- Combat Modules
NRSKNUI.CombatTimer = NRSKNUI:NewModule('CombatTimer', 'AceEvent-3.0')
NRSKNUI.PotionReady = NRSKNUI:NewModule('PotionReady', 'AceEvent-3.0')
NRSKNUI.RangeChecker = NRSKNUI:NewModule('RangeChecker', 'AceEvent-3.0')
NRSKNUI.CombatCross = NRSKNUI:NewModule('CombatCross', 'AceEvent-3.0')
NRSKNUI.CombatMessage = NRSKNUI:NewModule('CombatMessage', 'AceEvent-3.0', 'AceTimer-3.0')
NRSKNUI.CombatRes = NRSKNUI:NewModule('CombatRes', 'AceEvent-3.0', 'AceTimer-3.0')
NRSKNUI.CombatCursor = NRSKNUI:NewModule('CursorCircle', 'AceEvent-3.0')

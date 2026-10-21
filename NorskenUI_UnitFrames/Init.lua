---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
local addonName = ...

NRSKNUI.UnitFrames = NRSKNUI:NewModule('UnitFrames', 'AceTimer-3.0', 'AceEvent-3.0', 'AceHook-3.0')

-- oUF names its global from this folder's X-oUF field
NRSKNUI.oUF = _G.NorskenUF
NRSKNUI.oUFPrefix = C_AddOns.GetAddOnMetadata(addonName, 'X-oUF')
assert(NRSKNUI.oUF, 'oUF library not found!')

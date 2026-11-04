---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

CDM.Defaults = {
    Enabled = false,
    HidePlayerCastBar = false,
    AnchorMinWidth = 0,
    TrinketBlacklist = {}, -- [itemID] = true, trinkets whose on-use isn't worth tracking
    Version = 0,
    Displays = {}, -- 'cdm:N' keys, user data only
}

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

CDM.Defaults = {
    Enabled = false,
    HideBlizzard = false,
    HidePlayerCastBar = false,
    AnchorMinWidth = 0,
    TrinketBlacklist = {}, -- [itemID] = true, trinkets whose on-use isn't worth tracking
    Version = 0,
    Displays = {}, -- 'cdm:N' keys, user data only
}

---@class NorskenUI
local NRSKNUI = _G.NorskenUI

local SpellAlert = NRSKNUI:GetModule('SpellAlert')
SpellAlert.dbKey = 'Miscellaneous.SpellAlert'
SpellAlert.Defaults = {
    Enabled = false,
    UseGlobal = true,
    Global = {
        Scale = 1.0,
        Alpha = 1.0,
    },
    Specs = {},
}

local CombatRes = NRSKNUI:GetModule('CombatRes')
CombatRes.dbKey = 'BattleRes' -- its old profile key, which keeps saved profiles and export strings working
CombatRes.Defaults = {
    -- General Settings
    Enabled = true,
    -- Text Settings
    TextSeparator = "%sep",
    TextCharge = "%s",
    TextTimer = "%p",
    TextFormat = "CR: %s %sep %p",
    Separator = "||",
    TimeFormat = "MM:SS",
    -- Color Settings
    ColorSeparator = { 1, 1, 1, 1 },
    ColorChargeAvailable = { 0.3, 1, 0.3, 1 },
    ColorChargeUnavailable = { 1, 0.3, 0.3, 1 },
    ColorTimer = { 1, 1, 1, 1 },
    ColorFormat = { 1, 1, 1, 1 },
    -- Frame Settings
    Strata = "HIGH",
    anchorFrameType = "UIPARENT",
    ParentFrame = "UIParent",
    Position = {
        AnchorFrom = "CENTER",
        AnchorTo = "CENTER",
        XOffset = 814,
        YOffset = -465,
    },
    -- Font Settings
    UseGlobalFont = true,
    FontFace = "Expressway",
    FontSize = 18,
    FontOutline = "OUTLINE",
    FontShadow = {
        Enabled = false,
        Color = { 0, 0, 0, 1 },
        OffsetX = 1,
        OffsetY = -1,
    },
    -- Backdrop Settings
    BackdropEnabled = true,
    UseGlobalBorder = true,
    UseGlobalBackdrop = true,
    BackgroundColor = { 0, 0, 0, 0.8 },
    BorderColor = { 0, 0, 0, 1 },
    BackdropWidth = 4,
    BackdropHeight = 4,
}

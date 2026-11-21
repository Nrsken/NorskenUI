---@class NorskenUI
local NRSKNUI = _G.NorskenUI

local CombatCross = NRSKNUI:GetModule('CombatCross')
CombatCross.Defaults = {
    -- General Settings
    Enabled = true,
    CrossGap = 0,
    CrossThickness = 5,
    CrossLength = 18,
    Outline = true,
    -- Style Settings
    Mode = "cross", -- "cross"| "dot" | "diamond"
    CrossCenterDotEnabled = true,
    CenterDotSize = 20,
    DiamondSize = 32,
    -- Color Settings
    ColorMode = "custom",
    Color = { 0, 1, 0.169, 1 },
    -- Frame Settings
    Strata = "HIGH",
    anchorFrameType = "UIPARENT",
    ParentFrame = "UIParent",
    Position = {
        AnchorFrom = "CENTER",
        AnchorTo = "CENTER",
        XOffset = 0,
        YOffset = -10,
    },
    -- Range Indicator Settings
    RangeColorMeleeEnabled = true,
    RangeColorRangedEnabled = true,
    OutOfRangeColor = { 1, 0, 0, 1 },
}

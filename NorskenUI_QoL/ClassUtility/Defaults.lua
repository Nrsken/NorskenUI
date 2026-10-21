---@class NRSKNUI
local NRSKNUI = _G.NorskenUI

local PetTexts = NRSKNUI:GetModule('PetTexts')
PetTexts.Defaults = {
    Enabled = true, -- Master toggle
    -- State texts
    PetMissing = "PET MISSING",
    PetPassive = "PET PASSIVE",
    PetDead = "PET DEAD",
    PetWrong = "WRONG PET!",
    -- State colors (RGBA)
    MissingColor = { 1, 0.82, 0, 1 },  -- Gold/yellow for missing
    PassiveColor = { 0.3, 0.7, 1, 1 }, -- Light blue for passive
    DeadColor = { 1, 0.2, 0.2, 1 },    -- Red for dead
    WrongColor = { 1, 0, 1, 1 },       -- Magenta for wrong pet
    -- Font settings
    UseGlobalFont = true,
    FontFace = "Expressway",
    FontSize = 27,
    FontOutline = "SOFTOUTLINE",
    FontShadow = {
        Enabled = false,
        Color = { 0, 0, 0, 1 },
        OffsetX = 1,
        OffsetY = -1,
    },
    Strata = "HIGH",
    anchorFrameType = "UIPARENT",
    ParentFrame = "UIParent",
    Position = {               -- Position settings
        AnchorFrom = "CENTER", -- Anchor point from
        AnchorTo = "CENTER",   -- Anchor point to
        XOffset = 0,           -- X offset
        YOffset = 220,         -- Y offset
    },
    Config = {
        Spacing = 10,
        Grow = "HORIZONTAL",
        Align = "CENTER",
        RowSpacing = 0,
        GridType = "RD",
        GridWidth = 5,
        UseLimit = true,
        Limit = 1,
    },
}

local Gateway = NRSKNUI:GetModule('Gateway')
Gateway.dbKey = 'Miscellaneous.Gateway'
Gateway.Defaults = {
    Enabled = true,
    Text = "GATE USABLE CUH",
    Color = { 0, 1, 0 },
    -- Font settings
    UseGlobalFont = true,
    FontFace = "Expressway",      -- Font face
    FontSize = 36,                -- Font size
    FontOutline = "SOFTOUTLINE",  -- Font outline (NONE, OUTLINE, THICKOUTLINE, SOFTOUTLINE, SLUG, SLUG,OUTLINE)
    -- Position settings
    Strata = "HIGH",              -- Frame strata
    anchorFrameType = "UIPARENT", -- Anchor frame type
    ParentFrame = "UIParent",     -- Parent frame name
    Position = {                  -- Position settings
        AnchorFrom = "CENTER",    -- Anchor point from
        AnchorTo = "CENTER",      -- Anchor point to
        XOffset = 0,              -- X offset
        YOffset = -427,           -- Y offset
    },
}

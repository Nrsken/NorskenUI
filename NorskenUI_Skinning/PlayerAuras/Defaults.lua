---@class NorskenUI
local NRSKNUI = _G.NorskenUI

local PlayerAuras = NRSKNUI:GetModule('PlayerAuras')
PlayerAuras.dbKey = 'Auras' -- its old profile key, which keeps saved profiles and export strings working

-- Each frame is an aura group. Sub elements are a list, which AceDB would refill after a
-- delete, so they are seeded on first build (PlayerAuras.Looks).
PlayerAuras.Defaults = {
    Enabled = true,
    Buffs = {
        Trigger = { Type = 'AuraFilter', Base = 'HELPFUL', branches = { {} } },
        maxFrameCount = 38,
        previewLimit = 40,
        sortMethod = "AuraInstanceIDOnly",
        sortDirection = "Normal",
        showWeaponEnchants = true,
        groupSpacing = 0, -- seam between the weapon enchants and the buff group
        groupLineSpacing = 0,
        Layout = { Grow = "GRID", Align = "CENTER", GridType = "LD", GridWidth = 10, Spacing = 1, RowSpacing = 1 },
        Style = {
            Width = 40,
            Height = 40,
            DrawSwipe = true,
            Reverse = true,
            Tooltip = true,
            TooltipHideInCombat = false,
            DispelIcon = false,
            DispelIconSize = 16,
        },
        anchorFrameType = "SCREEN",
        Position = {
            AnchorFrom = "TOPRIGHT",
            AnchorTo = "TOPRIGHT",
            XOffset = -234,
            YOffset = -1,
        },
    },
    Debuffs = {
        Trigger = { Type = 'AuraFilter', Base = 'HARMFUL', branches = { {} } },
        maxFrameCount = 8,
        previewLimit = 8,
        sortMethod = "ExpirationOnly",
        sortDirection = "Normal",
        Layout = { Grow = "GRID", Align = "CENTER", GridType = "LD", GridWidth = 8, Spacing = 1, RowSpacing = 1 },
        Style = {
            Width = 46,
            Height = 46,
            DrawSwipe = false,
            Reverse = true,
            Tooltip = true,
            TooltipHideInCombat = false,
            DispelIcon = true,
            DispelIconSize = 16,
        },
        anchorFrameType = "SCREEN",
        Position = {
            AnchorFrom = "TOPRIGHT",
            AnchorTo = "TOPRIGHT",
            XOffset = -234,
            YOffset = -218,
        },
    },
}

-- How each frame's texts and border start, for Core:DefaultAuraGroupSubRegions: the way the
-- frames drew before they were aura groups.
PlayerAuras.Looks = {
    -- buffs aren't coloured by type, but a weapon enchant draws its border through it
    Buffs = { auraType = { ShowHelpful = false }, timer = { FontSize = 12, GlobalTimeColor = true }, stacks = { FontSize = 12 } },
    Debuffs = { auraType = { DispelUntyped = true }, timer = { FontSize = 14, GlobalTimeColor = true }, stacks = { FontSize = 12 } },
}

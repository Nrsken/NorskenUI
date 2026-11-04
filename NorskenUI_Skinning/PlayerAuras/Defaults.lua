---@class NRSKNUI
local NRSKNUI = _G.NorskenUI

local PlayerAuras = NRSKNUI:GetModule('PlayerAuras')
PlayerAuras.dbKey = 'Auras' -- its old profile key, which keeps saved profiles and export strings working
PlayerAuras.Defaults = {
    Enabled = true,
    Buffs = {
        size = 40,
        perRow = 10,
        maxFrameCount = 38,
        previewLimit = 40,
        elementSpacing = 1,
        lineSpacing = 1,
        groupSpacing = 0, -- seam between the weapon enchants and the buff group
        groupLineSpacing = 0,
        horizontalGrowthDirection = "LEFT",
        verticalGrowthDirection = "DOWN",
        sortMethod = "AuraInstanceIDOnly",
        sortDirection = "Normal",
        showApplicationCount = true,
        showDurationText = true,
        drawSwipe = true,
        drawEdge = false,
        reverseSwipe = true,
        tooltipHideInCombat = false,
        showWeaponEnchants = true,
        UseGlobalFont = true,
        FontFace = "Expressway",
        FontOutline = "OUTLINE",
        FontShadow = {
            Enabled = false,
            Color = { 0, 0, 0, 1 },
            OffsetX = 1,
            OffsetY = -1,
        },
        StackFont = {
            FontSize = 12,
            Position = {
                AnchorFrom = "BOTTOMRIGHT",
                XOffset = 0,
                YOffset = 2,
            },
        },
        DurationFont = {
            FontSize = 12,
            Position = {
                AnchorFrom = "CENTER",
                XOffset = 0,
                YOffset = 0,
            },
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
        -- Aura container options, names match Blizzard's (see Core/AuraContainer.lua).
        size = 46,
        perRow = 8,
        maxFrameCount = 8,
        previewLimit = 8,
        elementSpacing = 1,
        lineSpacing = 1,
        horizontalGrowthDirection = "LEFT",
        verticalGrowthDirection = "DOWN",
        -- Enum key names, resolved against AuraContainerSortMethod/SortDirection at use time.
        sortMethod = "ExpirationOnly",
        sortDirection = "Normal",
        showApplicationCount = true,
        showDurationText = true,
        drawSwipe = false,
        drawEdge = false,
        reverseSwipe = true,
        showBorder = true,
        showBorderWithoutDispelType = true,
        showDebuffDispelIcon = true,
        dispelIconSize = 16,
        tooltipHideInCombat = false,
        UseGlobalFont = true,
        FontFace = "Expressway",
        FontOutline = "OUTLINE",
        FontShadow = {
            Enabled = false,
            Color = { 0, 0, 0, 1 },
            OffsetX = 1,
            OffsetY = -1,
        },
        -- Per-string size and placement inside the aura button, face/outline/shadow are shared.
        StackFont = {
            FontSize = 12,
            Position = {
                AnchorFrom = "BOTTOMRIGHT",
                XOffset = 0,
                YOffset = 2,
            },
        },
        DurationFont = {
            FontSize = 14,
            Position = {
                AnchorFrom = "CENTER",
                XOffset = 0,
                YOffset = 0,
            },
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

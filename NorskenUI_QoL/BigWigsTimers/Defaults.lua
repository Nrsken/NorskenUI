---@class NRSKNUI
local NRSKNUI = _G.NorskenUI

local BigWigsTimers = NRSKNUI:GetModule('BigWigsTimers')
BigWigsTimers.Defaults = {
    Enabled = false,
    -- Bar group
    Bars = {
        Width = 180,
        Height = 22,
        Config = {
            Grow = "UP",
            Align = "CENTER",
            Spacing = 1,
            UseLimit = true,
            Limit = 2,
        },
        Strata = "HIGH",
        anchorFrameType = "UIPARENT",
        ParentFrame = "UIParent",
        Position = {
            AnchorFrom = "CENTER",
            AnchorTo = "CENTER",
            XOffset = 0,
            YOffset = -128,
        },
        UseGlobalFont = true,
        FontFace = "Expressway",
        FontSize = 12,
        FontOutline = "OUTLINE",
        FontShadow = {
            Enabled = false,
            Color = { 0, 0, 0, 1 },
            OffsetX = 1,
            OffsetY = -1,
        },
        UseGlobalBar = true,
        StatusBarTexture = "NorskenUI",
        Icon = {
            Enabled = true,
        },
        UseGlobalBorder = true,
        UseGlobalBackdrop = true,
        BackdropColor = { 0, 0, 0, 0.8 },
        BorderColor = { 0, 0, 0, 1 },
    },
    -- Text group
    Texts = {
        Config = {
            Grow = "DOWN",
            Align = "CENTER",
            Spacing = 0,
            UseLimit = true,
            Limit = 3,
        },
        Strata = "HIGH",
        anchorFrameType = "UIPARENT",
        ParentFrame = "UIParent",
        Position = {
            AnchorFrom = "CENTER",
            AnchorTo = "CENTER",
            XOffset = 0,
            YOffset = 136,
        },
        UseGlobalFont = true,
        FontFace = "Expressway",
        FontSize = 20,
        FontOutline = "OUTLINE",
        FontShadow = {
            Enabled = false,
            Color = { 0, 0, 0, 1 },
            OffsetX = 1,
            OffsetY = -1,
        },
    },
    -- Per-instance triggers, keyed by the instance ID BigWigs menus use
    Instances = {},
    -- Template copied on every new trigger
    TriggerDefaults = {
        Enabled = true,
        Name = "New Timer",
        TriggerType = "timer",
        -- Match
        BossId = 0,
        SpellId = "",
        Message = "",
        MessageOperator = "find",
        UseRemaining = true,
        RemainingOperator = "<",
        Remaining = 5,
        Offset = 0,
        Count = "",
        ShowCasts = "show",
        -- Announce
        Duration = 3,
        -- Display
        DisplayType = "bar",
        UseBigWigsColors = true,
        BarColor = { 0.772, 0.168, 0.168, 1 },
        TextColor = { 1, 1, 1, 1 },
        LeftText = "%n",
        RightText = "%t",
        Text = "%n » %t",
        ShowDecimals = true,
        DecimalThreshold = 1,
        -- Actions
        ActionOnShowSound = "None",
        ActionOnHideSound = "None",
        LoadConditions = {
            Enabled = false,
            SelectedCategory = "Instance",
            Instance = { Types = {} },
            Group = { Types = {} },
            Combat = {},
            Role = { Types = {} },
            Position = { Types = {} },
        },
    },
}

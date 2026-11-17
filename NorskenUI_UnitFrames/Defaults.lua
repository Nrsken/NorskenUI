---@class NorskenUI
local NRSKNUI = _G.NorskenUI
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')

UF.Defaults = {
    Enabled = false,
    HideBlizzardRaidFrames = true, -- oUF only ever disables the party ones
    General = {
        UseGlobalBar = true,
        statusBar = "NorskenUI",
        BackgroundTexture = "", -- "" = match the foreground texture
        UseGlobalSpark = true,
        SparkTexture = "Solid",
        SparkScale = 1,
        SparkWidth = 1,
        SparkColor = { 1, 1, 1, 1 },
        UseGlobalFont = true,
        FontFace = "Expressway",
        FontOutline = "OUTLINE",
        Smooth = true,
        Range = {
            Enabled = true,
            InsideAlpha = 1,
            OutsideAlpha = 0.6,
        },
        ColorByClass = false,
        ColorByPower = true,
        CastbarColorByClass = true,
        CastbarColorImportant = true,
        ForegroundAlphaWhenColorByClass = 1,
        Colors = {
            Foreground = { 0, 0, 0, 0.8 },
            Background = { 0.5, 0.5, 0.5, 1 },
            BackgroundWhenColorByClass = { 0, 0, 0, 0.8 },
            Power = { 0.3, 0.5, 0.8, 1 },
            Castbar = { 0.35, 0.55, 0.85, 1 },
            CastbarNonInterruptible = { 0.78, 0.25, 0.25, 1 },
            CastbarImportant = { 0.85, 0.55, 0.15, 1 },
            CastbarFail = { 0.8, 0.25, 0.2, 1 },
            CastbarBackground = { 0, 0, 0, 0.8 },
        },
        SafeZone = {
            Enabled = true,
            Color = { 0.8, 0.1, 0.1, 0.35 },
        },
        HealAbsorb = {
            Enabled = true,
            UseGlobalBar = false,
            StatusBarTexture = "StripesThick",
            Color = { 0.8, 0, 0, 0.5 },
        },
        HealPrediction = {
            Enabled = true,
            UseGlobalBar = true,
            StatusBarTexture = "NorskenUI",
            Color = { 0, 0.8, 0.35, 0.5 },
        },
        TempLoss = {
            Enabled = true,
            UseGlobalBar = false,
            StatusBarTexture = "StripesThick",
            Color = { 0.3, 0.3, 0.3, 0.8 },
        },
        DamageAbsorb = {
            Enabled = true,
            UseGlobalBar = false,
            StatusBarTexture = "StripesThick",
            Color = { 0, 0.58, 0.88, 0.81 },
        },
        Highlight = {
            Enabled = true,
            UseGlobalBar = false,
            StatusBarTexture = "StripesThick",
            Color = { 1, 1, 1, 0.1 },
        },
        Dispel = {
            Enabled = true,
            Source = "raid",    -- raid = your raid can dispel it, any = dispellable at all
            Style = "Gradient", -- Overlay (flat fill) | Gradient
            BorderSize = 2,     -- 0 = no border, and it draws with either style
            ShowIcon = false,   -- the game's own dispel type icon
            IconSize = 16,
            IconPosition = { AnchorFrom = "TOPRIGHT", AnchorTo = "TOPRIGHT", XOffset = -2, YOffset = -2 },
            Attach = "health",
            Alpha = 0.6,
            ShowWithoutDispelType = false,
            IgnoreTypes = {}, -- dispel types the highlight never picks, eg "Bleed"
        },
        -- Draw order above the health bar, higher draws on top. Keys are UF.LayerElements.
        Layers = {
            IndicatorTints = 1,
            Power = 2,
            Castbar = 3,
            Dispel = 4,
            HealPrediction = 5,
            DamageAbsorb = 5,
            HealAbsorb = 6,
            Highlight = 7,
            Border = 8,
            Tags = 9,
            Buffs = 10,
            Debuffs = 10,
            Defensives = 11,
            IndicatorIcons = 12,
            RaidMark = 13,
            Status = 14,
        },
    },
    TagSettings = {
        Separator = "»",
        UpdateInterval = 0.5,
    },
    Units = {
        -- Baseline settings for all unit frames, AceDB handles ["**"] and provides a copy of these settings for each unit frame, which can be overridden individually.
        ["**"] = {
            Enabled = true,
            Width = 220,
            Height = 42,
            anchorFrameType = "UIPARENT",
            ParentFrame = "UIParent",
            Strata = "MEDIUM",
            Position = {
                AnchorFrom = "CENTER",
                AnchorTo = "CENTER",
                XOffset = 0,
                YOffset = 0
            },
            Health = {
                Enabled = true,
                StatusBarTexture = nil,
                BackgroundTexture = "",
                UseGlobalColors = true,
                ColorByClass = false,
                UseGlobalSmooth = true,
                Smooth = false,
                Inverse = false,
                Foreground = { 0, 0, 0, 0.8 },
                Background = { 0.5, 0.5, 0.5, 1 },
                BackgroundWhenColorByClass = { 0, 0, 0, 0.8 },
                ForegroundAlphaWhenColorByClass = 1,
                HealAbsorb = {
                    UseGlobal = true,
                    Enabled = true,
                    UseGlobalBar = false,
                    StatusBarTexture = "StripesThick",
                    Color = { 0.4, 0, 0.8, 0.5 },
                },
                HealPrediction = {
                    UseGlobal = true,
                    Enabled = true,
                    UseGlobalBar = true,
                    StatusBarTexture = "NorskenUI",
                    Color = { 0, 0.8, 0.35, 0.5 },
                },
                TempLoss = {
                    UseGlobal = true,
                    Enabled = true,
                    UseGlobalBar = false,
                    StatusBarTexture = "StripesThick",
                    Color = { 0.3, 0.3, 0.3, 0.8 },
                },
                DamageAbsorb = {
                    UseGlobal = true,
                    Enabled = true,
                    UseGlobalBar = false,
                    StatusBarTexture = "StripesThick",
                    Color = { 0, 0.39, 0.88, 0.81 },
                },
            },
            Power = {
                Enabled = true,
                Height = 8,
                StatusBarTexture = nil,
                UseGlobalColors = true,
                ColorByPower = true,
                Color = { 0.3, 0.5, 0.8, 1 },
                UseGlobalSmooth = true,
                Smooth = true,
                CostPrediction = { -- player only
                    Enabled = true,
                    Color = { 0, 0, 0, 0.4 },
                },
            },
            Tags = {
                TagOne = {
                    Enabled = true,
                    Tag = "[NUF:name:smartcolor]",
                    UseGlobalFont = true,
                    FontFace = "Expressway",
                    FontSize = 12,
                    FontOutline = "OUTLINE",
                    Color = { 1, 1, 1 },
                    BoundTo = "",
                    Position = {
                        AnchorFrom = "TOPLEFT",
                        AnchorTo = "TOPLEFT",
                        XOffset = 4,
                        YOffset = -6
                    },
                },
                TagTwo = {
                    Enabled = true,
                    Tag = "[NUF:curhp:perhp]",
                    UseGlobalFont = true,
                    FontFace = "Expressway",
                    FontSize = 12,
                    FontOutline = "OUTLINE",
                    Color = { 1, 1, 1 },
                    BoundTo = "",
                    Position = {
                        AnchorFrom = "BOTTOMLEFT",
                        AnchorTo = "BOTTOMLEFT",
                        XOffset = 4,
                        YOffset = 6
                    },
                },
                TagThree = {
                    Enabled = true,
                    Tag = "[NUF:perpower:smartcolor]",
                    UseGlobalFont = true,
                    FontFace = "Expressway",
                    FontSize = 12,
                    FontOutline = "OUTLINE",
                    Color = { 1, 1, 1 },
                    BoundTo = "",
                    Position = {
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "BOTTOMRIGHT",
                        XOffset = -4,
                        YOffset = 6
                    },
                },
                TagFour = {
                    Enabled = false,
                    Tag = "",
                    UseGlobalFont = true,
                    FontFace = "Expressway",
                    FontSize = 12,
                    FontOutline = "OUTLINE",
                    Color = { 1, 1, 1 },
                    BoundTo = "",
                    Position = {
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
                TagFive = {
                    Enabled = false,
                    Tag = "",
                    UseGlobalFont = true,
                    FontFace = "Expressway",
                    FontSize = 12,
                    FontOutline = "OUTLINE",
                    Color = { 1, 1, 1 },
                    BoundTo = "",
                    Position = {
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
            },
            AuraIndicators = {},
            Dispel = {
                UseGlobal = false,
                Enabled = false,
                Source = "raid",
                Style = "Gradient",
                BorderSize = 2,
                ShowIcon = false,
                IconSize = 16,
                IconPosition = { AnchorFrom = "TOPRIGHT", AnchorTo = "TOPRIGHT", XOffset = -2, YOffset = -2 },
                Attach = "health",
                Alpha = 0.6,
                ShowWithoutDispelType = false,
                IgnoreTypes = {},
            },
            Indicators = {
                ["**"] = {
                    Texture = "Blizzard",
                },
                Resting = {
                    Enabled = false,
                    Size = 16,
                    Position = {
                        AnchorFrom = "BOTTOMLEFT",
                        AnchorTo = "TOPLEFT",
                        XOffset = 0,
                        YOffset = 2
                    },
                },
                Combat = {
                    Enabled = false,
                    Size = 20,
                    Position = {
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
                ReadyCheck = {
                    Enabled = false,
                    Size = 30,
                    Position = {
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
                Summon = {
                    Enabled = false,
                    Size = 24,
                    Position = {
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
                Resurrect = {
                    Enabled = false,
                    Size = 24,
                    Position = {
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
                Quest = {
                    Enabled = false,
                    Size = 16,
                    Position = {
                        AnchorFrom = "TOPRIGHT",
                        AnchorTo = "TOPRIGHT",
                        XOffset = -4,
                        YOffset = 0
                    },
                },
                PvP = {
                    Enabled = false,
                    Size = 24,
                    Position = {
                        AnchorFrom = "TOPLEFT",
                        AnchorTo = "TOPLEFT",
                        XOffset = -8,
                        YOffset = 8
                    },
                },
                Phase = {
                    Enabled = false,
                    Size = 20,
                    Position = {
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
                Role = {
                    Enabled = false,
                    Size = 14,
                    TankHealerOnly = true,
                    Position = {
                        AnchorFrom = "TOPLEFT",
                        AnchorTo = "TOPLEFT",
                        XOffset = 2,
                        YOffset = -16
                    },
                },
                Leader = {
                    Enabled = false,
                    Size = 14,
                    Position = {
                        AnchorFrom = "BOTTOMLEFT",
                        AnchorTo = "TOPLEFT",
                        XOffset = 0,
                        YOffset = -2
                    },
                },
                Focus = {
                    Enabled = false,
                    Size = 16,
                    Position = {
                        AnchorFrom = "RIGHT",
                        AnchorTo = "LEFT",
                        XOffset = -2,
                        YOffset = 0
                    },
                },
                RaidIcon = {
                    Enabled = true,
                    Size = 24,
                    Position = {
                        AnchorFrom = "CENTER",
                        AnchorTo = "TOP",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
            },
            Castbar = {
                Enabled = true,
                Height = 24,
                StatusBarTexture = nil,
                ShowIcon = true,
                ShowSpellName = true,
                ShowTime = true,
                ShowTarget = true,
                ShowInterrupter = true,
                TimeToHold = 0.5,
                UseGlobalColors = true,
                ColorByClass = true,
                ColorImportant = true,
                Color = { 0.35, 0.55, 0.85, 1 },
                NonInterruptibleColor = { 0.78, 0.25, 0.25, 1 },
                ImportantColor = { 0.85, 0.55, 0.15, 1 },
                FailColor = { 0.8, 0.25, 0.2, 1 },
                Background = { 0, 0, 0, 0.8 },
                SafeZone = {
                    UseGlobal = true,
                    Enabled = true,
                    Color = { 0.8, 0.1, 0.1, 0.35 },
                },
                Position = {
                    AnchorFrom = "TOPLEFT",
                    AnchorTo = "BOTTOMLEFT",
                    XOffset = 0,
                    YOffset = -10
                },
            },
            -- An aura group each, grown like a dynamic group of icons. Sub elements are a list,
            -- which AceDB would refill after a delete, so UF.PrepareAuras seeds them on first build.
            Auras = {
                Buffs = {
                    Enabled = true,
                    Trigger = { Type = 'AuraFilter', Base = 'HELPFUL', branches = { {} } },
                    maxFrameCount = 8,
                    previewLimit = 40,
                    sortMethod = "ExpirationOnly",
                    sortDirection = "Normal",
                    Layout = { Grow = "GRID", Align = "CENTER", GridType = "LU", GridWidth = 4, Spacing = 1, RowSpacing = 1 },
                    Style = {
                        Width = 32,
                        Height = 32,
                        DrawSwipe = false,
                        Reverse = true,
                        Tooltip = true,
                        TooltipHideInCombat = false,
                        DispelIcon = false,
                        DispelIconSize = 10,
                    },
                    Position = {
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "TOPRIGHT",
                        XOffset = 0,
                        YOffset = 1
                    },
                },
                Debuffs = {
                    Enabled = true,
                    Trigger = { Type = 'AuraFilter', Base = 'HARMFUL', branches = { {} } },
                    maxFrameCount = 6,
                    previewLimit = 40,
                    sortMethod = "ExpirationOnly",
                    sortDirection = "Normal",
                    Layout = { Grow = "GRID", Align = "CENTER", GridType = "RU", GridWidth = 2, Spacing = 1, RowSpacing = 1 },
                    Style = {
                        Width = 32,
                        Height = 32,
                        DrawSwipe = false,
                        Reverse = true,
                        Tooltip = true,
                        TooltipHideInCombat = false,
                        DispelIcon = false,
                        DispelIconSize = 10,
                    },
                    Position = {
                        AnchorFrom = "BOTTOMLEFT",
                        AnchorTo = "TOPLEFT",
                        XOffset = 0,
                        YOffset = 1
                    },
                },
                -- Party and raid only: their frames build this group, no other unit has it.
                Defensives = {
                    Enabled = false,
                    Trigger = { Type = 'Preset', Preset = 'preset:defensives' },
                    maxFrameCount = 4,
                    previewLimit = 4,
                    sortMethod = "ExpirationOnly",
                    sortDirection = "Normal",
                    Layout = { Grow = "HORIZONTAL", Align = "CENTER", GridType = "RD", GridWidth = 4, Spacing = 1, RowSpacing = 1 },
                    Style = {
                        Width = 22,
                        Height = 22,
                        DrawSwipe = false,
                        Reverse = true,
                        Tooltip = false,
                        TooltipHideInCombat = false,
                        DispelIcon = false,
                        DispelIconSize = 10,
                    },
                    Position = {
                        AnchorFrom = "CENTER",
                        AnchorTo = "CENTER",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
            },
        },
        -- Per unit overrides, these will override the ["**"] settings above
        player = {
            Tags = {
                TagOne = {
                    Tag = "[NUF:absorb:abbr]",
                    Color = { 0, 1, 0.86 },
                },
                TagThree = {
                    Enabled = false,
                },
            },
            Indicators = {
                Resting = {
                    Enabled = true,
                },
                Combat = {
                    Enabled = false,
                },
                Summon = {
                    Enabled = true,
                },
                Leader = {
                    Enabled = true,
                },
            },
            anchorFrameType = "SELECTFRAME",
            ParentFrame = "NRSKNUF_CDMAnchor",
            Position = {
                AnchorFrom = "RIGHT",
                AnchorTo = "LEFT",
                XOffset = -30,
                YOffset = 0
            },
            Power = {
                Enabled = false,
            },
            Castbar = {
                Enabled = false,
            },
            Auras = {
                Buffs = { Enabled = false },
                Debuffs = { Enabled = false },
            },
        },
        target = {
            Auras = {
                Buffs = { Trigger = { Type = 'Preset', Preset = 'preset:targetBuffs' } },
                Debuffs = { Trigger = { Type = 'Preset', Preset = 'preset:targetDebuffs' } },
            },
            Indicators = {
                Summon = {
                    Enabled = true,
                },
                Quest = {
                    Enabled = true,
                },
                Leader = {
                    Enabled = true,
                },
            },
            anchorFrameType = "SELECTFRAME",
            ParentFrame = "NRSKNUF_CDMAnchor",
            Position = {
                AnchorFrom = "LEFT",
                AnchorTo = "RIGHT",
                XOffset = 30,
                YOffset = 0
            },
            Power = {
                Enabled = false,
            },
            Castbar = {
                Position = {
                    AnchorFrom = "TOPLEFT",
                    AnchorTo = "BOTTOMLEFT",
                    XOffset = 0,
                    YOffset = -1,
                },
            },
        },
        targettarget = {
            Width = 110,
            Height = 22,
            Power = {
                Enabled = false,
            },
            Castbar = {
                Enabled = false,
            },
            Tags = {
                TagOne = {
                    BoundTo = "frame",
                    Position = {
                        AnchorFrom = "LEFT",
                        AnchorTo = "LEFT",
                        XOffset = 4,
                        YOffset = 0
                    }
                },
                TagTwo = {
                    Enabled = false
                },
                TagThree = {
                    Enabled = false
                },

            },
            anchorFrameType = "SELECTFRAME",
            ParentFrame = "NUF_Target",
            Position = {
                AnchorFrom = "LEFT",
                AnchorTo = "RIGHT",
                XOffset = 1,
                YOffset = 10
            },
            Auras = {
                Buffs = { Enabled = false },
                Debuffs = { Enabled = false },
            },
        },
        focus = {
            Auras = {
                Debuffs = {
                    Enabled = false,
                },
                Buffs = {
                    Enabled = false,
                },
            },
            anchorFrameType = "SELECTFRAME",
            ParentFrame = "NUF_Target",
            Position = {
                AnchorFrom = "BOTTOMLEFT",
                AnchorTo = "TOPRIGHT",
                XOffset = 40,
                YOffset = 32
            },
            Power = {
                Enabled = false,
            },
            Castbar = {
                Enabled = false,
            },
        },
        focustarget = {
            Width = 110,
            Height = 22,
            Power = {
                Enabled = false,
            },
            Castbar = {
                Enabled = false,
            },
            Tags = {
                TagOne = {
                    BoundTo = "frame",
                    Position = {
                        AnchorFrom = "LEFT",
                        AnchorTo = "LEFT",
                        XOffset = 4,
                        YOffset = 0
                    }
                },
                TagTwo = {
                    Enabled = false,
                },
                TagThree = {
                    Enabled = false
                },
            },
            anchorFrameType = "SELECTFRAME",
            ParentFrame = "NUF_Focus",
            Position = {
                AnchorFrom = "LEFT",
                AnchorTo = "RIGHT",
                XOffset = 1,
                YOffset = 10
            },
            Auras = {
                Buffs = { Enabled = false },
                Debuffs = { Enabled = false },
            },
        },
        pet = {
            Width = 110,
            Height = 22,
            anchorFrameType = "SELECTFRAME",
            ParentFrame = "NUF_Player",
            Position = {
                AnchorFrom = "TOPLEFT",
                AnchorTo = "BOTTOMLEFT",
                XOffset = 0,
                YOffset = -20
            },
            Tags = {
                TagOne = {
                    BoundTo = "frame",
                    Position = {
                        AnchorFrom = "LEFT",
                        AnchorTo = "LEFT",
                        XOffset = 4,
                        YOffset = 0
                    }
                },
                TagTwo = {
                    Enabled = false
                },
                TagThree = {
                    Enabled = false
                },
            },
            Power = {
                Enabled = false,
            },
            Auras = {
                Buffs = { Enabled = false },
                Debuffs = { Enabled = false },
            },
        },
        pettarget = {
            Width = 109,
            Height = 22,
            Power = {
                Enabled = false,
            },
            Castbar = {
                Enabled = false,
            },
            Tags = {
                TagOne = {
                    BoundTo = "frame",
                    Position = {
                        AnchorFrom = "LEFT",
                        AnchorTo = "LEFT",
                        XOffset = 4,
                        YOffset = 0
                    }
                },
                TagTwo = {
                    Enabled = false
                },
                TagThree = {
                    Enabled = false
                },
            },
            anchorFrameType = "SELECTFRAME",
            ParentFrame = "NUF_Pet",
            Position = {
                AnchorFrom = "LEFT",
                AnchorTo = "RIGHT",
                XOffset = 1,
                YOffset = 0
            },
            Auras = {
                Buffs = { Enabled = false },
                Debuffs = { Enabled = false },
            },
        },
        boss = {
            Auras = {
                Buffs = {
                    Trigger = { Type = 'Preset', Preset = 'preset:bossBuffs' },
                    maxFrameCount = 4,
                    previewLimit = 4,
                    Layout = { GridType = "RU", GridWidth = 4 },
                    Style = { Width = 42, Height = 42 },
                    Position = {
                        AnchorFrom = "BOTTOMLEFT",
                        AnchorTo = "BOTTOMRIGHT",
                        XOffset = 1,
                        YOffset = 0
                    },
                },
                Debuffs = {
                    Trigger = { Type = 'Preset', Preset = 'preset:bossDebuffs' },
                    maxFrameCount = 4,
                    previewLimit = 4,
                    Layout = { GridType = "LU", GridWidth = 4 },
                    Style = { Width = 42, Height = 42 },
                    Position = {
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "BOTTOMLEFT",
                        XOffset = -1,
                        YOffset = 0
                    },
                },
            },
            Spacing = 26,
            GrowthDirection = "UP",
            anchorFrameType = "UIPARENT",
            ParentFrame = "UIParent",
            Position = {
                AnchorFrom = "LEFT",
                AnchorTo = "CENTER",
                XOffset = 500,
                YOffset = -50,
            },
            Power = {
                Enabled = false,
            },
            Castbar = {
                Position = {
                    AnchorFrom = "TOPLEFT",
                    AnchorTo = "BOTTOMLEFT",
                    XOffset = 0,
                    YOffset = -1,
                },
            },
        },
        party = {
            Dispel = {
                UseGlobal = true,
            },
            Auras = {
                Defensives = { Enabled = true },
                Buffs = {
                    Trigger = { Type = 'Preset', Preset = 'preset:partyBuffs' },
                    maxFrameCount = 2,
                    previewLimit = 2,
                    Layout = { GridWidth = 2 },
                    Style = { Width = 26, Height = 26 },
                    Position = {
                        AnchorTo = "BOTTOMRIGHT",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
                Debuffs = {
                    Trigger = { Type = 'Preset', Preset = 'preset:partyDebuffs' },
                    maxFrameCount = 2,
                    previewLimit = 2,
                    Style = { Width = 30, Height = 30 },
                    Position = {
                        AnchorTo = "BOTTOMLEFT",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
            },
            Width = 150,
            Height = 80,
            anchorFrameType = "UIPARENT",
            ParentFrame = "UIParent",
            Position = {
                AnchorFrom = "TOPLEFT",
                AnchorTo = "TOPLEFT",
                XOffset = 558,
                YOffset = -484
            },
            Group = {
                GrowthDirection = "DOWN",
                HorizontalSpacing = 1,
                VerticalSpacing = 1,
                ShowPlayer = true,
                StartFromCenter = false,
                SortBy = "ROLE",
                SortMethod = "INDEX",
                SortDirection = "ASC",
                RoleOrder = { "TANK", "HEALER", "DAMAGER" },
                Visibility = "[@raid1,exists][nogroup] hide;show",
            },
            Power = {
                Roles = { TANK = true, HEALER = true, DAMAGER = true },
                Classes = {}, -- [classToken] = true; none picked means every class
                Enabled = false,
            },
            Castbar = {
                Enabled = false, -- never constructed on group units
            },
            Tags = {
                TagOne = {
                    Position = {
                        AnchorFrom = "TOPLEFT",
                        AnchorTo = "TOPLEFT",
                        XOffset = 2,
                        YOffset = -2
                    },
                },
                TagTwo = {
                    Tag = "[NUF:healmana:smartcolor]",
                    Position = {
                        AnchorFrom = "LEFT",
                        AnchorTo = "LEFT",
                        XOffset = 18,
                        YOffset = 17
                    },
                },
                TagThree = {
                    Enabled = true,
                    Tag = "[NUF:status]",
                    Position = {
                        AnchorFrom = "TOPLEFT",
                        AnchorTo = "TOPLEFT",
                        XOffset = 2,
                        YOffset = -30
                    },
                },
            },
            Indicators = {
                ReadyCheck = { Enabled = true },
                Summon = {
                    Enabled = true,
                    Position = {
                        AnchorFrom = "TOPRIGHT",
                        AnchorTo = "TOPRIGHT",
                        XOffset = -2,
                        YOffset = -2
                    },
                },
                Resurrect = { Enabled = true },
                Phase = { Enabled = true },
                Role = { Enabled = true },
                Leader = { Enabled = true },
                RaidIcon = { Size = 20 },
            },
        },
        raid1 = {
            Dispel = {
                UseGlobal = true,
            },
            Auras = {
                Defensives = { Enabled = true },
                Buffs = {
                    Trigger = { Type = 'Preset', Preset = 'preset:partyBuffs' },
                    maxFrameCount = 2,
                    previewLimit = 2,
                    Layout = { GridWidth = 2 },
                    Style = { Width = 26, Height = 26 },
                    Position = {
                        AnchorTo = "BOTTOMRIGHT",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
                Debuffs = {
                    Trigger = { Type = 'Preset', Preset = 'preset:partyDebuffs' },
                    maxFrameCount = 2,
                    previewLimit = 2,
                    Style = { Width = 30, Height = 30 },
                    Position = {
                        AnchorTo = "BOTTOMLEFT",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
            },
            Width = 120,
            Height = 75,
            anchorFrameType = "UIPARENT",
            ParentFrame = "UIParent",
            Position = {
                AnchorFrom = "TOPLEFT",
                AnchorTo = "TOPLEFT",
                XOffset = 1,
                YOffset = -1
            },
            Group = {
                GrowthDirection = "DOWN",
                HorizontalSpacing = 1,
                VerticalSpacing = 1,
                ShowPlayer = true,
                StartFromCenter = false,
                SortBy = "GROUP",
                SortMethod = "INDEX",
                SortDirection = "ASC",
                RoleOrder = { "TANK", "HEALER", "DAMAGER" },
                -- Every raid up to twenty, down to the two-man ones the party frames used to take.
                Visibility = "[@raid21,exists][@raid1,noexists] hide;show",
                GroupGrowthDirection = "RIGHT",
                GroupsPerRowColumn = 4,
                GroupSpacing = 1,
                AutoGroups = true,
                NumGroups = 8,
            },
            Power = {
                Roles = { TANK = true, HEALER = true, DAMAGER = true },
                Classes = {}, -- [classToken] = true; none picked means every class
                Enabled = false,
            },
            Castbar = {
                Enabled = false, -- never constructed on group units
            },
            Tags = {
                TagOne = {
                    Position = {
                        AnchorFrom = "TOPLEFT",
                        AnchorTo = "TOPLEFT",
                        XOffset = 2,
                        YOffset = -2
                    },
                },
                TagTwo = {
                    Tag = "[NUF:healmana:smartcolor]",
                    Position = {
                        AnchorFrom = "LEFT",
                        AnchorTo = "LEFT",
                        XOffset = 18,
                        YOffset = 17
                    },
                },
                TagThree = {
                    Enabled = true,
                    Tag = "[NUF:status]",
                    Position = {
                        AnchorFrom = "TOPLEFT",
                        AnchorTo = "TOPLEFT",
                        XOffset = 2,
                        YOffset = -30
                    },
                },
            },
            Indicators = {
                ReadyCheck = { Enabled = true },
                Summon = {
                    Enabled = true,
                    Position = {
                        AnchorFrom = "TOPRIGHT",
                        AnchorTo = "TOPRIGHT",
                        XOffset = -2,
                        YOffset = -2
                    },
                },
                Resurrect = { Enabled = true },
                Phase = { Enabled = true },
                Role = { Enabled = true },
                Leader = { Enabled = true },
                RaidIcon = { Size = 20 },
            },
        },
        raid2 = {
            Dispel = {
                UseGlobal = true,
            },
            Auras = {
                Defensives = { Enabled = true },
                Buffs = {
                    Trigger = { Type = 'Preset', Preset = 'preset:partyBuffs' },
                    maxFrameCount = 2,
                    previewLimit = 2,
                    Layout = { GridWidth = 2 },
                    Style = { Width = 26, Height = 26 },
                    Position = {
                        AnchorTo = "BOTTOMRIGHT",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
                Debuffs = {
                    Trigger = { Type = 'Preset', Preset = 'preset:partyDebuffs' },
                    maxFrameCount = 2,
                    previewLimit = 2,
                    Style = { Width = 30, Height = 30 },
                    Position = {
                        AnchorTo = "BOTTOMLEFT",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
            },
            Width = 120,
            Height = 75,
            anchorFrameType = "UIPARENT",
            ParentFrame = "UIParent",
            Position = {
                AnchorFrom = "TOPLEFT",
                AnchorTo = "TOPLEFT",
                XOffset = 1,
                YOffset = -1
            },
            Group = {
                GrowthDirection = "DOWN",
                HorizontalSpacing = 1,
                VerticalSpacing = 1,
                ShowPlayer = true,
                StartFromCenter = false,
                SortBy = "GROUP",
                SortMethod = "INDEX",
                SortDirection = "ASC",
                RoleOrder = { "TANK", "HEALER", "DAMAGER" },
                Visibility = "[@raid31,exists][@raid21,noexists] hide;show",
                GroupGrowthDirection = "RIGHT",
                GroupsPerRowColumn = 6,
                GroupSpacing = 1,
                AutoGroups = true,
                NumGroups = 8,
            },
            Power = {
                Roles = { TANK = true, HEALER = true, DAMAGER = true },
                Classes = {}, -- [classToken] = true; none picked means every class
                Enabled = false,
            },
            Castbar = {
                Enabled = false, -- never constructed on group units
            },
            Tags = {
                TagOne = {
                    Position = {
                        AnchorFrom = "TOPLEFT",
                        AnchorTo = "TOPLEFT",
                        XOffset = 2,
                        YOffset = -2
                    },
                },
                TagTwo = {
                    Tag = "[NUF:healmana:smartcolor]",
                    Position = {
                        AnchorFrom = "LEFT",
                        AnchorTo = "LEFT",
                        XOffset = 18,
                        YOffset = 17
                    },
                },
                TagThree = {
                    Enabled = true,
                    Tag = "[NUF:status]",
                    Position = {
                        AnchorFrom = "TOPLEFT",
                        AnchorTo = "TOPLEFT",
                        XOffset = 2,
                        YOffset = -30
                    },
                },
            },
            Indicators = {
                ReadyCheck = { Enabled = true },
                Summon = {
                    Enabled = true,
                    Position = {
                        AnchorFrom = "TOPRIGHT",
                        AnchorTo = "TOPRIGHT",
                        XOffset = -2,
                        YOffset = -2
                    },
                },
                Resurrect = { Enabled = true },
                Phase = { Enabled = true },
                Role = { Enabled = true },
                Leader = { Enabled = true },
                RaidIcon = { Size = 20 },
            },
        },
        raid3 = {
            Dispel = {
                UseGlobal = true,
            },
            Auras = {
                Defensives = { Enabled = true },
                Buffs = {
                    Trigger = { Type = 'Preset', Preset = 'preset:partyBuffs' },
                    maxFrameCount = 2,
                    previewLimit = 2,
                    Layout = { GridWidth = 2 },
                    Style = { Width = 26, Height = 26 },
                    Position = {
                        AnchorTo = "BOTTOMRIGHT",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
                Debuffs = {
                    Trigger = { Type = 'Preset', Preset = 'preset:partyDebuffs' },
                    maxFrameCount = 2,
                    previewLimit = 2,
                    Style = { Width = 30, Height = 30 },
                    Position = {
                        AnchorTo = "BOTTOMLEFT",
                        XOffset = 0,
                        YOffset = 0
                    },
                },
            },
            Width = 120,
            Height = 75,
            anchorFrameType = "UIPARENT",
            ParentFrame = "UIParent",
            Position = {
                AnchorFrom = "TOPLEFT",
                AnchorTo = "TOPLEFT",
                XOffset = 1,
                YOffset = -1
            },
            Group = {
                GrowthDirection = "DOWN",
                HorizontalSpacing = 1,
                VerticalSpacing = 1,
                ShowPlayer = true,
                StartFromCenter = false,
                SortBy = "GROUP",
                SortMethod = "INDEX",
                SortDirection = "ASC",
                RoleOrder = { "TANK", "HEALER", "DAMAGER" },
                Visibility = "[@raid31,noexists] hide;show",
                GroupGrowthDirection = "RIGHT",
                GroupsPerRowColumn = 8,
                GroupSpacing = 1,
                AutoGroups = true,
                NumGroups = 8,
            },
            Power = {
                Roles = { TANK = true, HEALER = true, DAMAGER = true },
                Classes = {}, -- [classToken] = true; none picked means every class
                Enabled = false,
            },
            Castbar = {
                Enabled = false, -- never constructed on group units
            },
            Tags = {
                TagOne = {
                    Position = {
                        AnchorFrom = "TOPLEFT",
                        AnchorTo = "TOPLEFT",
                        XOffset = 2,
                        YOffset = -2
                    },
                },
                TagTwo = {
                    Tag = "[NUF:healmana:smartcolor]",
                    Position = {
                        AnchorFrom = "LEFT",
                        AnchorTo = "LEFT",
                        XOffset = 18,
                        YOffset = 17
                    },
                },
                TagThree = {
                    Enabled = true,
                    Tag = "[NUF:status]",
                    Position = {
                        AnchorFrom = "TOPLEFT",
                        AnchorTo = "TOPLEFT",
                        XOffset = 2,
                        YOffset = -30
                    },
                },
            },
            Indicators = {
                ReadyCheck = { Enabled = true },
                Summon = {
                    Enabled = true,
                    Position = {
                        AnchorFrom = "TOPRIGHT",
                        AnchorTo = "TOPRIGHT",
                        XOffset = -2,
                        YOffset = -2
                    },
                },
                Resurrect = { Enabled = true },
                Phase = { Enabled = true },
                Role = { Enabled = true },
                Leader = { Enabled = true },
                RaidIcon = { Size = 20 },
            },
        },
    },
}

-- How a kind's texts and border start, for Core:DefaultAuraGroupSubRegions: the way its buttons
-- looked before they were aura groups.
UF.AuraLooks = {
    Buffs = { timer = { FontSize = 12, GlobalTimeColor = true }, stacks = { FontSize = 12 } },
    Debuffs = { auraType = { DispelUntyped = true }, timer = { FontSize = 12, GlobalTimeColor = true }, stacks = { FontSize = 12 } },
    Defensives = { timer = { FontSize = 10, GlobalTimeColor = true }, stacks = { FontSize = 10, Enabled = false } },
}

---The unit frames' own font for aura texts, which they always drew in.
---@param general table UnitFrames.General, raw or with its defaults
---@return table overrides for a text sub element
function UF.AuraFont(general)
    return { UseGlobalFont = general.UseGlobalFont ~= false, FontFace = general.FontFace, FontOutline = general.FontOutline }
end

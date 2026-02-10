-- NorskenUI namespace
local _, NRSKNUI = ...

-- Default settings table
local Defaults = {
    global = {
        UseGlobalProfile = false,  -- Switch to global profile
        GlobalProfile = "Default", -- Name of global profile to use

        -- Theme settings
        -- Mode: "preset", "class", or "custom"
        -- All theme presets are defined in AddonTheme.lua
        Theme = {
            mode           = "preset", -- Theme mode: preset, class, or custom
            selectedPreset = "Echo",   -- Selected preset theme name
            customColors   = {},       -- Custom color overrides (used in custom mode)

            -- Font settings (shared across all modes)
            fontFace       = "Fonts\\FRIZQT__.TTF",
            fontSizeNormal = 12,
            fontSizeSmall  = 12,
            fontSizeLarge  = 16,
            fontOutline    = "OUTLINE",
            fontShadow     = false,
        },

        -- GUI State (only frame position/size persists across logins)
        GUIState = {
            frame = {
                point = nil,         -- Anchor point
                relativePoint = nil, -- Relative anchor point
                xOffset = nil,       -- Frame X offset
                yOffset = nil,       -- Frame Y offset
                width = nil,         -- Frame width
                height = nil,        -- Frame height
            },
            selectedGroupId = nil,   -- Currently selected sidebar item
            selectedTab = nil,       -- Currently selected tab in content
            minimized = false,       -- Is frame minimized
        },
    },
    profile = {
        -- Minimap Icon Settings
        Minimap = {
            hide = false, -- Show/hide minimap icon
        },
        -- Combat Timer Settings
        CombatTimer = {
            Enabled = true,                      -- Enable/disable combat timer
            Format = "MM:SS",                    -- Time format
            FontSize = 22,                       -- Font size
            FontFace = "Expressway",             -- Font face
            FontOutline = "OUTLINE",             -- Font outline
            Strata = "HIGH",                     -- Frame strata
            anchorFrameType = "SELECTFRAME",     -- Anchor type: SCREEN, UIPARENT, SELECTFRAME
            FontShadow = {                       -- Font shadow settings
                Enabled = false,                 -- Enable font shadow
                OffsetX = 0,                     -- X offset
                OffsetY = 0,                     -- Y offset
                Color = { 0, 0, 0, 1 },          -- Shadow color (alpha 1 when enabled)
            },
            ColorInCombat = { 1, 1, 1, 1 },      -- Color when in combat
            ColorOutOfCombat = { 1, 1, 1, 0.7 }, -- Color when out of combat
            ParentFrame = "UIParent",            -- Parent frame
            Position = {                         -- Position settings
                AnchorFrom = "CENTER",           -- Anchor point from
                AnchorTo = "CENTER",             -- Anchor point to
                XOffset = 0,                     -- X offset
                YOffset = -100,                  -- Y offset
            },
            Backdrop = {                         -- Backdrop settings
                Enabled = false,                 -- Enable/disable backdrop
                Color = { 0, 0, 0, 0.6 },        -- Backdrop color
                BorderColor = { 0, 0, 0, 1 },    -- Border color
                BorderSize = 1,
                bgWidth = 5,
                bgHeight = 5,

            },
        },

        -- Combat Message Settings
        CombatMessage = {
            Enabled = true,               -- Enable/disable combat messages
            Strata = "HIGH",              -- Frame strata
            anchorFrameType = "UIPARENT", -- Anchor frame type (SCREEN, UIPARENT, SELECTFRAME)
            ParentFrame = "UIParent",     -- Parent frame name (when SELECTFRAME)
            FontFace = "Expressway",      -- Font face
            FontSize = 15,                -- Font size
            FontOutline = "OUTLINE",      -- Font outline
            FontShadow = {                -- Font shadow settings
                Enabled = false,          -- Enable font shadow
                Color = { 0, 0, 0, 0 },   -- Shadow color
                OffsetX = 0,              -- Shadow X offset
                OffsetY = 0,              -- Shadow Y offset
            },
            Position = {                  -- Position settings
                AnchorFrom = "CENTER",    -- Anchor point from
                AnchorTo = "CENTER",      -- Anchor point to
                XOffset = 0,              -- X offset
                YOffset = 142,            -- Y offset
            },
            Duration = 2.5,               -- Message display duration
            Spacing = 4,                  -- Vertical spacing between messages
            -- Enter Combat Message
            EnterCombat = {
                Enabled = true,                 -- Enable enter combat message
                Text = "+ COMBAT +",            -- Text on entering combat
                Color = { 0.929, 0.259, 0, 1 }, -- Color on entering combat
            },
            -- Exit Combat Message
            ExitCombat = {
                Enabled = true,                 -- Enable exit combat message
                Text = "- COMBAT -",            -- Text on exiting combat
                Color = { 0.788, 1, 0.627, 1 }, -- Color on exiting combat
            },
            -- No Target Warning (persistent while in combat with no target)
            NoTarget = {
                Enabled = true,           -- Enable no target warning
                Text = "NO TARGET",       -- Warning text
                Color = { 1, 0.4, 0, 1 }, -- Warning color (yellow/orange)
            },
        },

        -- Combat Cross Settings
        CombatCross = {
            Enabled = true,               -- Enable/disable combat cross
            Strata = "HIGH",              -- Frame strata
            anchorFrameType = "UIPARENT", -- Anchor frame type (SCREEN, UIPARENT, SELECTFRAME)
            ParentFrame = "UIParent",     -- Parent frame name (when SELECTFRAME)
            Position = {                  -- Position settings
                AnchorFrom = "CENTER",    -- Anchor point from
                AnchorTo = "CENTER",      -- Anchor point to
                XOffset = 0,              -- X offset
                YOffset = -10,            -- Y offset
            },
            ColorMode = "custom",         -- Color mode: "class" | "custom" | "theme"
            Color = { 0, 1, 0.169, 1 },   -- Cross color (used when ColorMode = "custom")
            Thickness = 22,               -- Cross thickness (font size)
            Outline = true,               -- Outline enabled
        },

        -- Battle Res Tracker Settings
        BattleRes = {
            Enabled = true,               -- Enable/disable battle res tracker
            DisplayMode = "text",         -- "icon" or "text"
            PreviewMode = false,          -- Preview mode for testing outside M+
            Strata = "HIGH",              -- Frame strata
            anchorFrameType = "UIPARENT", -- Anchor frame type
            ParentFrame = "UIParent",     -- Parent frame name
            Position = {                  -- Position settings
                AnchorFrom = "CENTER",    -- Anchor point from
                AnchorTo = "CENTER",      -- Anchor point to
                XOffset = 0.1,            -- X offset
                YOffset = -430,           -- Y offset
            },

            -- Text Mode Settings
            TextMode = {
                -- General text settings
                FontFace = "Expressway", -- Font face
                FontSize = 18,           -- Font size
                FontOutline = "OUTLINE", -- Font outline
                TextSpacing = 4,         -- Spacing between timer and charges

                -- Separator Settings
                Separator = "|",                 -- Separator between timer and charges
                SeparatorCharges = "CR:",
                SeparatorColor = { 1, 1, 1, 1 }, -- Separator color
                SeparatorShadow = {
                    Enabled = false,             -- Enable shadow
                    UseSoftOutline = true,       -- Use stacked shadows (soft outline) vs regular shadow
                    Color = { 0, 0, 0, 0 },      -- Shadow color
                    OffsetX = 0,                 -- Shadow X offset (regular shadow only)
                    OffsetY = 0,                 -- Shadow Y offset (regular shadow only)
                },

                -- Cooldown Timer Settings (uses Blizzard cooldown text - no soft outline support)
                TimerColor = { 1, 1, 1, 1 }, -- Timer text color
                TimerShadow = {
                    Enabled = false,         -- Enable shadow
                    UseSoftOutline = true,
                    Color = { 0, 0, 0, 0 },  -- Shadow color
                    OffsetX = 0,             -- Shadow X offset
                    OffsetY = 0,             -- Shadow Y offset
                },

                -- Charge Count Settings
                ChargeAvailableColor = { 0.3, 1, 0.3, 1 },   -- Charge color when 1+ available
                ChargeUnavailableColor = { 1, 0.3, 0.3, 1 }, -- Charge color when 0 available
                ChargeShadow = {
                    Enabled = false,                         -- Enable shadow
                    UseSoftOutline = true,                   -- Use stacked shadows (soft outline) vs regular shadow
                    Color = { 0, 0, 0, 0 },                  -- Shadow color
                    OffsetX = 0,                             -- Shadow X offset (regular shadow only)
                    OffsetY = 0,                             -- Shadow Y offset (regular shadow only)
                },

                -- Backdrop Settings
                Backdrop = {                      -- Backdrop settings (text mode mainly)
                    Enabled = false,              -- Enable backdrop
                    Color = { 0, 0, 0, 0.6 },     -- Background color
                    BorderColor = { 0, 0, 0, 1 }, -- Border color
                    PaddingX = 8,                 -- Horizontal padding (visual only, not used for sizing)
                    PaddingY = 4,                 -- Vertical padding (visual only, not used for sizing)
                    FrameWidth = 100,             -- Fixed frame width
                    FrameHeight = 26,             -- Fixed frame height
                },
                GrowthDirection = "RIGHT",        -- Growth direction: "LEFT", "RIGHT", "CENTER"
            },
        },

        PetTexts = {
            Enabled = true, -- Master toggle
            -- State texts
            PetMissing = "PET MISSING",
            PetPassive = "PET PASSIVE",
            PetDead = "PET DEAD",
            -- State colors (RGBA)
            MissingColor = { 1, 0.82, 0, 1 },  -- Gold/yellow for missing
            PassiveColor = { 0.3, 0.7, 1, 1 }, -- Light blue for passive
            DeadColor = { 1, 0.2, 0.2, 1 },    -- Red for dead
            -- Font settings
            FontFace = "Expressway",           -- Font face
            FontSize = 24,                     -- Font size
            FontOutline = "OUTLINE",           -- Font outline (NONE, OUTLINE, THICKOUTLINE)
            FontSoftOutline = true,
            -- Position settings
            Strata = "HIGH",              -- Frame strata
            anchorFrameType = "UIPARENT", -- Anchor frame type
            ParentFrame = "UIParent",     -- Parent frame name
            Position = {                  -- Position settings
                AnchorFrom = "CENTER",    -- Anchor point from
                AnchorTo = "CENTER",      -- Anchor point to
                XOffset = 0,              -- X offset
                YOffset = 181,            -- Y offset
            },
        },

        -- Miscellaneous Settings
        Miscellaneous = {
            Durability = {
                Enabled = true,
                FontFace = "Expressway",
                FontOutline = "OUTLINE",

                WarningText = {
                    Enabled = true,
                    ShowPercent = 30,
                    CombatShowPercent = 0,
                    WarningColor = { 1, 0.537, 0.2, 1 },
                    FontSize = 18,
                    WarningText = "REPAIR NOW",
                    -- Position settings
                    Strata = "HIGH",              -- Frame strata
                    anchorFrameType = "UIPARENT", -- Anchor frame type
                    ParentFrame = "UIParent",     -- Parent frame name
                    Position = {                  -- Position settings
                        AnchorFrom = "CENTER",    -- Anchor point from
                        AnchorTo = "CENTER",      -- Anchor point to
                        XOffset = 0,              -- X offset
                        YOffset = 104,            -- Y offset
                    },
                },

                Text = {
                    Enabled = true,
                    UseStatusColor = true,
                    Color = { 1, 1, 1, 1 },
                    FontSize = 12,
                    DurColor = { 1, 1, 1, 1 },
                    DurText = "Dur: ",
                    -- Position settings
                    Strata = "HIGH",                 -- Frame strata
                    anchorFrameType = "SELECTFRAME", -- Anchor frame type
                    ParentFrame = "Minimap",         -- Parent frame name
                    Position = {                     -- Position settings
                        AnchorFrom = "BOTTOMLEFT",   -- Anchor point from
                        AnchorTo = "BOTTOMLEFT",     -- Anchor point to
                        XOffset = 1,                 -- X offset
                        YOffset = 18,                -- Y offset
                    },
                },
            },

            XPBar = {
                Enabled = true,
                HideBlizzardBar = true,
                hideWhenMax = true,
                width = 400,
                height = 24,
                FontFace = "Expressway", -- Font face
                FontOutline = "OUTLINE", -- Font outline
                FontSize = 14,
                Strata = "HIGH",
                anchorFrameType = "UIPARENT", -- Anchor frame type
                ParentFrame = "UIParent",     -- Parent frame name
                Position = {                  -- Position settings
                    AnchorFrom = "CENTER",    -- Anchor point from
                    AnchorTo = "CENTER",      -- Anchor point to
                    XOffset = 0,              -- X offset
                    YOffset = 500,
                },
                -- Statusbar coloring
                ColorMode = "theme",
                StatusColor = { 1, 1, 1, 1 },
                StatusBarTexture = "NorskenUI", -- LSM statusbar texture name

                -- Rested Coloring
                RestedColor = { 0.7803, 0.0000, 0.0000, 0.25 },

                -- Backdrop
                BackdropColor = { 0, 0, 0, 0.8 },
                BackdropBorderColor = { 0, 0, 0, 1 },

                -- Text Coloring
                TextColor = { 1, 1, 1, 1 },
            },

            CopyAnything = {
                Enabled = true, -- Master toggle
                key = "C",      -- Copy keybind
                mod = "ctrl",   -- ctrl, shift, alt
            },

            WhisperSounds = {
                Enabled = true,                                  -- Enable whisper sounds
                WhisperSound = "|cffe51039NorskenWhisper|r",     -- Sound for regular whispers
                BNetWhisperSound = "|cffe51039NorskenWhisper|r", -- Sound for Battle.net whispers
            },
            CursorCircle = {
                Enabled = true,            -- Enable cursor circle
                Size = 40,                 -- Circle size
                Texture = "Circle 3",      -- Selected texture
                Color = { 1, 1, 1, 1 },    -- Circle color (RGBA) - used when ColorMode = "custom"
                ColorMode = "theme",       -- Color mode: "class" | "custom" | "theme"
                UseUpdateInterval = false, -- Use throttled updates (saves CPU but less smooth)
                UpdateInterval = 0.016,    -- Update interval in seconds (0.016 = ~60 FPS, lower = smoother but higher CPU)
                GCD = {
                    Mode = "integrated",
                    Size = 25,
                    Texture = "Circle 5",
                    SwipeColorMode = "custom",
                    SwipeColor = { 1, 1, 1, 1 },
                    Reverse = true,
                    HideOutOfCombat = false,
                    RingColorMode = "theme",
                    RingColor = { 1, 1, 1, 1 },
                },
            },
            Automation = {
                Enabled = true,         -- Master toggle
                SkipCinematics = true,  -- Skip in-game cinematics and movies
                HideTalkingHead = true, -- Hide talking head popup frame
                AutoSellJunk = true,    -- Auto sell grey items at merchants
                AutoRepair = true,      -- Auto repair gear at merchants
                UseGuildFunds = true,   -- Use guild bank for repairs when available
                AutoRoleCheck = true,   -- Auto accept role checks and LFG signups
                AutoFillDelete = true,  -- Auto fill DELETE text when deleting items
                AutoLoot = true,        -- Enable auto loot by default
            },
            DragonRiding = {
                Enabled = true,
                Width = 252,               -- Total width of the UI
                BarHeight = 6,             -- Height of each row
                Spacing = 3,               -- Spacing between rows
                FontFace = "Expressway",
                SpeedFontSize = 14,        -- Speed text font size
                Position = {               -- Position settings
                    AnchorFrom = "CENTER", -- Anchor point from
                    AnchorTo = "CENTER",   -- Anchor point to
                    XOffset = 0,           -- X offset
                    YOffset = 220,         -- Y offset
                },
                Colors = {
                    Vigor = { 0.898, 0.063, 0.224, 1 },       -- Normal vigor color
                    VigorThrill = { 0, 1, 0.137, 1 },         -- Thrill of the Skies active
                    WhirlingSurge = { 0.411, 0.8, 0.941, 1 }, -- Whirling Surge
                    SecondWind = { 0.917, 0.168, 0.901, 1 },  -- Second Wind
                },
            },
            CooldownStrings = {
                Enabled = true,    -- Enable/disable CDM profile strings
                FrameWidth = 350,  -- Width of the attached frame
                FrameHeight = 400, -- Height of the attached frame
                Profiles = {},     -- Saved profile strings { [name] = { String = "", Created = timestamp } }
            },
            FocusCastbar = {
                Enabled = true,

                Width = 300,
                Height = 29,

                FontFace = "Expressway",
                FontSize = 14,
                FontOutline = "OUTLINE",

                Strata = "HIGH",
                anchorFrameType = "UIPARENT",
                ParentFrame = "UIParent",
                Position = {
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    XOffset = 0.1,
                    YOffset = 220.1,
                },

                -- Colors
                CastingColor = { 0.623, 0.749, 1, 1 },
                ChannelingColor = { 0.623, 0.749, 1, 1 },
                EmpoweringColor = { 0.8, 0.4, 1, 1 },
                NotInterruptibleColor = { 0.780, 0.250, 0.250, 1 },
                TextColor = { 1, 1, 1, 1 },

                -- Backdrop
                BackdropColor = { 0, 0, 0, 0.8 },
                BorderColor = { 0, 0, 0, 1 },

                -- Statusbar
                StatusBarTexture = "NorskenUI",

                -- Hold Timer
                HoldTimer = {
                    Enabled = true,
                    Duration = 0.5,
                    InterruptedColor = { 0.1, 0.8, 0.1, 1 },
                    SuccessColor = { 0.780, 0.250, 0.250, 1 },
                },
                timeToHold = 0.5,

                -- Kick Indicator
                KickIndicator = {
                    Enabled = true,
                    ReadyColor = { 0.623, 0.749, 1, 1 },
                    NotReadyColor = { 0.5, 0.5, 0.5, 1 },
                    TickColor = { 0.1, 0.8, 0.1, 1 },
                },
            },

            RaidAlerts = {
                Enabled = true,

                IconSize = 20,

                FontSize = 20,
                FontFace = "Expressway", -- Module font face
                FontOutline = "OUTLINE",

                Strata = "HIGH",
                Position = {
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    XOffset = 0,
                    YOffset = 150,
                },
                Alerts = {
                    Feast = {
                        Enabled = true,
                        DisplayText = "Feast",
                        Color = { 0.96, 0.76, 0.26, 1 },
                    },
                    HeartyFeast = {
                        Enabled = true,
                        DisplayText = "Hearty Feast",
                        Color = { 1, 0.5, 0, 1 },
                    },
                    PotCauldron = {
                        Enabled = true,
                        DisplayText = "Pot Cauldron",
                        Color = { 0.627, 1, 0.854, 1 },
                    },
                    FlaskCauldron = {
                        Enabled = true,
                        DisplayText = "Flask Cauldron",
                        Color = { 1, 0.760, 0.525, 1 },
                    },
                    RepairBot = {
                        Enabled = true,
                        DisplayText = "Auto-Hammer",
                        Color = { 1, 0.6, 0.227, 1 },
                    },
                    Soulwell = {
                        Enabled = true,
                        DisplayText = "Grab Healthstones",
                        Color = { 0.741, 1, 0, 1 },
                    },
                    SummonStone = {
                        Enabled = true,
                        DisplayText = "Help Summon",
                        Color = { 0.780, 0, 1, 1 },
                    },
                },
            },
        },
        -- Skinning Settings (CDM, Buffs, Action Bars, etc.)
        Skinning = {
            Battlenet = {
                Enabled = true,
                -- Position Settings
                anchorFrameType = "UIPARENT",  -- Anchor frame type
                ParentFrame = "UIParent",      -- Parent frame name
                Position = {                   -- Position settings
                    AnchorFrom = "BOTTOMLEFT", -- Anchor point from
                    AnchorTo = "BOTTOMLEFT",   -- Anchor point to
                    XOffset = 1,               -- X offset
                    YOffset = 247,             -- Y offset
                },
            },

            UICleanup = {
                Enabled = true,
            },

            Chat = {
                Enabled = true,
                Width = 448,
                Height = 245,
                FontFace = "Expressway", -- Module font face
                FontOutline = "OUTLINE", -- Module font outline
                EditBoxFontSize = 14,    -- EditBox Font size
                ChatFontSize = 12,       -- Chat Font size
                TabFontSize = 12,        -- Chat Tab Font size
                TabSpacing = 20,
                -- Tab Color Settings
                TabColors = {
                    AlertColor = { 1, 0, 0, 1 },                -- Red for new messages/alerts
                    ActiveColor = { 1, 1, 1, 1 },               -- White for selected/active tab
                    WhisperColor = { 1, 0.5, 0.8, 1 },          -- Pink for whisper tabs
                    InactiveColorMode = "custom",               -- "theme", "class", or "custom"
                    InactiveColor = { 0.898, 0.063, 0.224, 1 }, -- Custom color for inactive tabs
                },
                -- EditBox Backdrop Settings
                EditBox = {
                    BackdropColor = { 0, 0, 0, 0.8 }, -- EditBox background color
                    BorderColor = { 0, 0, 0, 1 },     -- EditBox border color
                },
                -- Backdrop Settings
                Backdrop = {                      -- Backdrop settings (text mode mainly)
                    Enabled = true,               -- Enable backdrop, if not enable, set alpha 0 on backdrop and borders
                    Color = { 0, 0, 0, 0.8 },     -- Background color
                    BorderColor = { 0, 0, 0, 1 }, -- Border color
                },
                -- Position Settings
                anchorFrameType = "UIPARENT",  -- Anchor frame type
                ParentFrame = "UIParent",      -- Parent frame name
                Position = {                   -- Position settings
                    AnchorFrom = "BOTTOMLEFT", -- Anchor point from
                    AnchorTo = "BOTTOMLEFT",   -- Anchor point to
                    XOffset = 1,               -- X offset
                    YOffset = 1,               -- Y offset
                },
            },

            -- Smoll CDM skin on aura overlay
            CDM = {
                Enabled = true,
                FontFace = "Expressway",
                FontOutline = "OUTLINE",
                AlphaoutMountPet = true,
                AlphaMountPet = 0.5,
                Charges = {
                    Size = 18,
                    FontColor = { 1, 1, 1, 1 },
                },
                Cooldown = {
                    SizeEssentials = 18,
                    SizeUtil = 14,
                    FontColor = { 1, 1, 1, 1 },
                },
            },
            CDMGlow = {
                Enabled = true,
            },

            -- Actionbars
            ActionBars = {
                Enabled = true,            -- Master toggle for action bar skinning
                HideProfTexture = true,    -- Hide profession quality textures
                HideMacroText = false,     -- Hide macro name text
                MouseoverOverride = false, -- Mouseover override when dragonriding for example
                Mouseover = {              -- Global mouseover settings (used when bar's globalOverride is true)
                    Enabled = false,
                    FadeInDuration = 0.3,
                    FadeOutDuration = 1,
                    Alpha = 0,
                },
                FontFace = "Expressway",
                FontOutline = "OUTLINE",

                -- Global Font Sizes (used when bar's FontSizes.GlobalOverride is true)
                FontSizes = {
                    KeybindSize = 12,
                    CooldownSize = 14,
                    ChargeSize = 12,
                    MacroSize = 10,
                },

                -- Text Anchor Settings
                KeybindAnchor = "TOPRIGHT",
                KeybindXOffset = -2,
                KeybindYOffset = -2,

                ChargeAnchor = "BOTTOMRIGHT",
                ChargeXOffset = -2,
                ChargeYOffset = 2,

                MacroAnchor = "BOTTOM",
                MacroXOffset = 0,
                MacroYOffset = 2,

                CooldownAnchor = "CENTER",
                CooldownXOffset = 0,
                CooldownYOffset = 0,
                -- Per-bar settings (all bars use same structure)
                Bars = {
                    Bar1 = {
                        Enabled = true,
                        Spacing = 1,
                        ButtonSize = 40,
                        TotalButtons = 12,
                        Layout = "HORIZONTAL",
                        GrowthDirection = "RIGHT",
                        ButtonsPerLine = 12,
                        ParentFrame = "UIParent",
                        HideEmptyBackdrops = false,
                        BackdropColor = { 0, 0, 0, 0.8 },
                        BorderColor = { 0, 0, 0, 1 },
                        Position = {
                            AnchorFrom = "BOTTOM",
                            AnchorTo = "BOTTOM",
                            XOffset = 0.1,
                            YOffset = 1.1,
                        },
                        Mouseover = {
                            GlobalOverride = true,
                            Enabled = true,
                            Alpha = 0,
                        },
                        FontSizes = {
                            GlobalOverride = true,
                            KeybindSize = 12,
                            CooldownSize = 14,
                            ChargeSize = 12,
                            MacroSize = 10,
                        },
                        TextPositions = {
                            GlobalOverride = true,
                            KeybindAnchor = "TOPRIGHT",
                            KeybindXOffset = -2,
                            KeybindYOffset = -2,
                            ChargeAnchor = "BOTTOMRIGHT",
                            ChargeXOffset = -2,
                            ChargeYOffset = 2,
                            MacroAnchor = "BOTTOM",
                            MacroXOffset = 0,
                            MacroYOffset = -2,
                        },
                    },
                    Bar2 = {
                        Enabled = true,
                        Spacing = 1,
                        ButtonSize = 40,
                        TotalButtons = 12,
                        Layout = "HORIZONTAL",
                        GrowthDirection = "RIGHT",
                        ButtonsPerLine = 6,
                        ParentFrame = "UIParent",
                        HideEmptyBackdrops = false,
                        BackdropColor = { 0, 0, 0, 0.8 },
                        BorderColor = { 0, 0, 0, 1 },
                        Position = {
                            AnchorFrom = "BOTTOM",
                            AnchorTo = "BOTTOM",
                            XOffset = 369.1,
                            YOffset = 1.1,
                        },
                        Mouseover = {
                            GlobalOverride = true,
                            Enabled = true,
                            Alpha = 0,
                        },
                        FontSizes = {
                            GlobalOverride = true,
                            KeybindSize = 12,
                            CooldownSize = 14,
                            ChargeSize = 12,
                            MacroSize = 10,
                        },
                        TextPositions = {
                            GlobalOverride = true,
                            KeybindAnchor = "TOPRIGHT",
                            KeybindXOffset = -2,
                            KeybindYOffset = -2,
                            ChargeAnchor = "BOTTOMRIGHT",
                            ChargeXOffset = -2,
                            ChargeYOffset = 2,
                            MacroAnchor = "BOTTOM",
                            MacroXOffset = 0,
                            MacroYOffset = -2,
                        },
                    },
                    Bar3 = {
                        Enabled = true,
                        Spacing = 1,
                        ButtonSize = 40,
                        TotalButtons = 12,
                        Layout = "HORIZONTAL",
                        GrowthDirection = "RIGHT",
                        ButtonsPerLine = 12,
                        ParentFrame = "UIParent",
                        HideEmptyBackdrops = false,
                        BackdropColor = { 0, 0, 0, 0.8 },
                        BorderColor = { 0, 0, 0, 1 },
                        Position = {
                            AnchorFrom = "BOTTOM",
                            AnchorTo = "BOTTOM",
                            XOffset = 0.1,
                            YOffset = 42.1,
                        },
                        Mouseover = {
                            GlobalOverride = true,
                            Enabled = true,
                            Alpha = 0,
                        },
                        FontSizes = {
                            GlobalOverride = true,
                            KeybindSize = 12,
                            CooldownSize = 14,
                            ChargeSize = 12,
                            MacroSize = 10,
                        },
                        TextPositions = {
                            GlobalOverride = true,
                            KeybindAnchor = "TOPRIGHT",
                            KeybindXOffset = -2,
                            KeybindYOffset = -2,
                            ChargeAnchor = "BOTTOMRIGHT",
                            ChargeXOffset = -2,
                            ChargeYOffset = 2,
                            MacroAnchor = "BOTTOM",
                            MacroXOffset = 0,
                            MacroYOffset = -2,
                        },
                    },
                    Bar4 = {
                        Enabled = true,
                        Spacing = 1,
                        ButtonSize = 40,
                        TotalButtons = 12,
                        Layout = "VERTICAL",
                        GrowthDirection = "RIGHT",
                        ButtonsPerLine = 6,
                        ParentFrame = "UIParent",
                        HideEmptyBackdrops = false,
                        BackdropColor = { 0, 0, 0, 0.8 },
                        BorderColor = { 0, 0, 0, 1 },
                        Position = {
                            AnchorFrom = "BOTTOMLEFT",
                            AnchorTo = "BOTTOMLEFT",
                            XOffset = 450.1,
                            YOffset = 1.1,
                        },
                        Mouseover = {
                            GlobalOverride = true,
                            Enabled = true,
                            Alpha = 0,
                        },
                        FontSizes = {
                            GlobalOverride = true,
                            KeybindSize = 12,
                            CooldownSize = 14,
                            ChargeSize = 12,
                            MacroSize = 10,
                        },
                        TextPositions = {
                            GlobalOverride = true,
                            KeybindAnchor = "TOPRIGHT",
                            KeybindXOffset = -2,
                            KeybindYOffset = -2,
                            ChargeAnchor = "BOTTOMRIGHT",
                            ChargeXOffset = -2,
                            ChargeYOffset = 2,
                            MacroAnchor = "BOTTOM",
                            MacroXOffset = 0,
                            MacroYOffset = -2,
                        },
                    },
                    Bar5 = {
                        Enabled = true,
                        Spacing = 1,
                        ButtonSize = 40,
                        TotalButtons = 12,
                        Layout = "HORIZONTAL",
                        GrowthDirection = "RIGHT",
                        ButtonsPerLine = 6,
                        ParentFrame = "UIParent",
                        HideEmptyBackdrops = false,
                        BackdropColor = { 0, 0, 0, 0.8 },
                        BorderColor = { 0, 0, 0, 1 },
                        Position = {
                            AnchorFrom = "BOTTOM",
                            AnchorTo = "BOTTOM",
                            XOffset = -368.1,
                            YOffset = 1.1,
                        },
                        Mouseover = {
                            GlobalOverride = true,
                            Enabled = true,
                            Alpha = 0,
                        },
                        FontSizes = {
                            GlobalOverride = true,
                            KeybindSize = 12,
                            CooldownSize = 14,
                            ChargeSize = 12,
                            MacroSize = 10,
                        },
                        TextPositions = {
                            GlobalOverride = true,
                            KeybindAnchor = "TOPRIGHT",
                            KeybindXOffset = -2,
                            KeybindYOffset = -2,
                            ChargeAnchor = "BOTTOMRIGHT",
                            ChargeXOffset = -2,
                            ChargeYOffset = 2,
                            MacroAnchor = "BOTTOM",
                            MacroXOffset = 0,
                            MacroYOffset = -2,
                        },
                    },
                    Bar6 = {
                        Enabled = true,
                        Spacing = 1,
                        ButtonSize = 40,
                        TotalButtons = 12,
                        Layout = "VERTICAL",
                        GrowthDirection = "RIGHT",
                        ButtonsPerLine = 6,
                        ParentFrame = "UIParent",
                        HideEmptyBackdrops = false,
                        BackdropColor = { 0, 0, 0, 0.8 },
                        BorderColor = { 0, 0, 0, 1 },
                        Position = {
                            AnchorFrom = "BOTTOMLEFT",
                            AnchorTo = "BOTTOMLEFT",
                            XOffset = 532.1,
                            YOffset = 1.1,
                        },
                        Mouseover = {
                            GlobalOverride = true,
                            Enabled = true,
                            Alpha = 0,
                        },
                        FontSizes = {
                            GlobalOverride = true,
                            KeybindSize = 12,
                            CooldownSize = 14,
                            ChargeSize = 12,
                            MacroSize = 10,
                        },
                        TextPositions = {
                            GlobalOverride = true,
                            KeybindAnchor = "TOPRIGHT",
                            KeybindXOffset = -2,
                            KeybindYOffset = -2,
                            ChargeAnchor = "BOTTOMRIGHT",
                            ChargeXOffset = -2,
                            ChargeYOffset = 2,
                            MacroAnchor = "BOTTOM",
                            MacroXOffset = 0,
                            MacroYOffset = -2,
                        },
                    },
                    Bar7 = {
                        Enabled = true,
                        Spacing = 1,
                        ButtonSize = 40,
                        TotalButtons = 12,
                        Layout = "VERTICAL",
                        GrowthDirection = "RIGHT",
                        ButtonsPerLine = 12,
                        ParentFrame = "UIParent",
                        HideEmptyBackdrops = false,
                        BackdropColor = { 0, 0, 0, 0.8 },
                        BorderColor = { 0, 0, 0, 1 },
                        Position = {
                            AnchorFrom = "LEFT",
                            AnchorTo = "LEFT",
                            XOffset = 1.1,
                            YOffset = 0.1,
                        },
                        Mouseover = {
                            GlobalOverride = true,
                            Enabled = false,
                            Alpha = 1,
                        },
                        FontSizes = {
                            GlobalOverride = true,
                            KeybindSize = 12,
                            CooldownSize = 14,
                            ChargeSize = 12,
                            MacroSize = 10,
                        },
                        TextPositions = {
                            GlobalOverride = true,
                            KeybindAnchor = "TOPRIGHT",
                            KeybindXOffset = -2,
                            KeybindYOffset = -2,
                            ChargeAnchor = "BOTTOMRIGHT",
                            ChargeXOffset = -2,
                            ChargeYOffset = 2,
                            MacroAnchor = "BOTTOM",
                            MacroXOffset = 0,
                            MacroYOffset = -2,
                        },
                    },
                    Bar8 = {
                        Enabled = true,
                        Spacing = 1,
                        ButtonSize = 40,
                        TotalButtons = 12,
                        Layout = "VERTICAL",
                        GrowthDirection = "RIGHT",
                        ButtonsPerLine = 12,
                        ParentFrame = "UIParent",
                        HideEmptyBackdrops = false,
                        BackdropColor = { 0, 0, 0, 0.8 },
                        BorderColor = { 0, 0, 0, 1 },
                        Position = {
                            AnchorFrom = "LEFT",
                            AnchorTo = "LEFT",
                            XOffset = 43.1,
                            YOffset = 0.1,
                        },
                        Mouseover = {
                            GlobalOverride = true,
                            Enabled = false,
                            Alpha = 1,
                        },
                        FontSizes = {
                            GlobalOverride = true,
                            KeybindSize = 12,
                            CooldownSize = 14,
                            ChargeSize = 12,
                            MacroSize = 10,
                        },
                        TextPositions = {
                            GlobalOverride = true,
                            KeybindAnchor = "TOPRIGHT",
                            KeybindXOffset = -2,
                            KeybindYOffset = -2,
                            ChargeAnchor = "BOTTOMRIGHT",
                            ChargeXOffset = -2,
                            ChargeYOffset = 2,
                            MacroAnchor = "BOTTOM",
                            MacroXOffset = 0,
                            MacroYOffset = -2,
                        },
                    },
                    PetBar = {
                        Enabled = true,
                        Spacing = 1,
                        ButtonSize = 32,
                        TotalButtons = 10,
                        Layout = "HORIZONTAL",
                        GrowthDirection = "RIGHT",
                        ButtonsPerLine = 10,
                        ParentFrame = "UIParent",
                        HideEmptyBackdrops = false,
                        BackdropColor = { 0, 0, 0, 0.8 },
                        BorderColor = { 0, 0, 0, 1 },
                        Position = {
                            AnchorFrom = "BOTTOM",
                            AnchorTo = "BOTTOM",
                            XOffset = 0.1,
                            YOffset = 83.1,
                        },
                        Mouseover = {
                            GlobalOverride = false,
                            Enabled = false,
                            Alpha = 0,
                        },
                        FontSizes = {
                            GlobalOverride = true,
                            KeybindSize = 10,
                            CooldownSize = 12,
                            ChargeSize = 10,
                            MacroSize = 8,
                        },
                        TextPositions = {
                            GlobalOverride = true,
                            KeybindAnchor = "TOPRIGHT",
                            KeybindXOffset = -2,
                            KeybindYOffset = -2,
                            ChargeAnchor = "BOTTOMRIGHT",
                            ChargeXOffset = -2,
                            ChargeYOffset = 2,
                            MacroAnchor = "BOTTOM",
                            MacroXOffset = 0,
                            MacroYOffset = -2,
                        },
                    },
                    StanceBar = {
                        Enabled = true,
                        Spacing = 1,
                        ButtonSize = 32,
                        TotalButtons = 10,
                        Layout = "HORIZONTAL",
                        GrowthDirection = "RIGHT",
                        ButtonsPerLine = 10,
                        ParentFrame = "UIParent",
                        HideEmptyBackdrops = true,
                        BackdropColor = { 0, 0, 0, 0.8 },
                        BorderColor = { 0, 0, 0, 1 },
                        Position = {
                            AnchorFrom = "BOTTOM",
                            AnchorTo = "BOTTOM",
                            XOffset = 0.1,
                            YOffset = 117.1,
                        },
                        Mouseover = {
                            GlobalOverride = false,
                            Enabled = false,
                            Alpha = 0,
                        },
                        FontSizes = {
                            GlobalOverride = true,
                            KeybindSize = 10,
                            CooldownSize = 12,
                            ChargeSize = 10,
                            MacroSize = 8,
                        },
                        TextPositions = {
                            GlobalOverride = true,
                            KeybindAnchor = "TOPRIGHT",
                            KeybindXOffset = -2,
                            KeybindYOffset = -2,
                            ChargeAnchor = "BOTTOMRIGHT",
                            ChargeXOffset = -2,
                            ChargeYOffset = 2,
                            MacroAnchor = "BOTTOM",
                            MacroXOffset = 0,
                            MacroYOffset = -2,
                        },
                    },
                },
            },

            -- Standard Buff/Debuff Frame Skinning
            BuffDebuffFrames = {
                Enabled = true,          -- Master toggle for buff/debuff frame skinning
                disableFlashing = true,  -- Disable flashing on low duration icons
                FontFace = "Expressway", -- Font face
                FontOutline = "OUTLINE", -- Font outline
                FontColor = { 1, 1, 1, 1 },

                -- Buffs
                buffSize = 36,
                buffBorderColor = { 0, 0, 0, 1 },

                -- Debuffs
                debuffSize = 40,
                debuffBorderColor = { 0.8, 0, 0, 1 },

                -- External Defensives
                defSize = 42,
                defBorderColor = { 0, 0, 0, 1 },
            },

            -- Minimap Skinning
            Minimap = {
                Enabled = true,              -- Master toggle for minimap skinning
                HideAddOnComp = true,        -- Hide the addon compartment button
                Size = 232,                  -- Minimap size (square)
                Position = {                 -- Position
                    AnchorFrom = "TOPRIGHT", -- Anchor point
                    AnchorTo = "TOPRIGHT",
                    X = -1,                  -- X offset from anchor
                    Y = -1,                  -- Y offset from anchor
                },
                Border = {                   -- Border settings
                    Thickness = 1,           -- Border thickness
                    Color = { 0, 0, 0, 1 },  -- Border color
                },

                -- MiniMap Elements
                ExpansionButton = {        -- Expansion button
                    Hide = false,          -- Hide expansion button
                    Scale = 0.6,           -- Scale of button
                    Anchor = "TOPRIGHT",   -- Anchor point
                    X = -2,                -- X offset
                    Y = -2,                -- Y offset
                },
                Mail = {                   -- Mail icon
                    Scale = 1.0,           -- Scale of mail icon
                    Anchor = "TOPRIGHT",   -- Anchor point
                    X = -7,                -- X offset
                    Y = -39,               -- Y offset
                },
                InstanceDifficulty = {     -- Instance difficulty
                    Scale = 0.8,           -- Scale of difficulty icon
                    Anchor = "TOPLEFT",    -- Anchor point
                    X = 2,                 -- X offset
                    Y = -2,                -- Y offset
                },
                QueueStatus = {            -- Queue status button
                    Scale = 0.5,           -- Scale of queue status button
                    Anchor = "BOTTOMLEFT", -- Anchor point
                    X = 2,                 -- X offset
                    Y = 80,                -- Y offset
                },
                BugSack = {                -- BugSack error counter button
                    Enabled = true,        -- Enable BugSack button skinning
                    Size = 15,             -- Size of button
                    Anchor = "BOTTOMLEFT", -- Anchor point
                    X = 2,                 -- X offset
                    Y = 2,                 -- Y offset
                },
            },

            -- MicroMenu Skinning
            MicroMenu = {
                Enabled = true,
                ButtonWidth = 23,
                ButtonHeight = 31,
                ButtonSpacing = -4,
                BackdropSpacing = 0,
                ShowBackdrop = true,
                BackdropColor = { 0, 0, 0, 0.8 },
                BackdropBorderColor = { 0, 0, 0, 1 },
                anchorFrameType = "SELECTFRAME",
                ParentFrame = "Minimap",
                Strata = "HIGH",
                Position = {
                    AnchorFrom = "TOP",
                    AnchorTo = "BOTTOM",
                    XOffset = 0,
                    YOffset = -1,
                },
                Mouseover = {
                    Enabled = false,
                    Alpha = 0.0,
                    FadeInDuration = 0.2,
                    FadeOutDuration = 0.2,
                },
            },

            -- Blizzard Element Mouseover
            BlizzardMouseover = {
                Enabled = true,       -- Master toggle for bags bar skinning
                Alpha = 0.0,          -- Alpha when not hovered (0 = fully hidden)
                FadeInDuration = 0.2, -- Fade in duration
                FadeOutDuration = 1,  -- Fade out duration
                BagMouseover = {
                    Enabled = true,   -- Enable mouseover fading
                },
            },

            -- Blizzard Messages Skinning
            BlizzardMessages = {
                Enabled = true,          -- Master toggle for Blizzard messages skinning
                -- Global font settings
                Font = "Expressway",     -- Font face
                FontOutline = "OUTLINE", -- Font outline
                -- UIErrorsFrame (red error messages at top of screen)
                UIErrorsFrame = {
                    Hide = false, -- Show/hide error messages
                    Size = 14,    -- Font size
                    -- Position
                    Position = {
                        Anchor = "TOP", -- Anchor point
                        X = 0,          -- X offset
                        Y = -281,       -- Y offset
                    },
                },
                -- ActionStatusText (action feedback messages)
                ActionStatusText = {
                    Hide = false, -- Show/hide action status messages
                    Size = 14,    -- Font size
                    -- Position
                    Position = {
                        Anchor = "TOP", -- Anchor point
                        X = 0,          -- X offset
                        Y = -251,       -- Y offset
                    },
                },
                -- Chat bubbles font
                ChatBubbles = {
                    Enabled = true, -- Enable chat bubble font skinning
                    Size = 8,       -- Font size
                },
                -- Objective tracker fonts
                ObjectiveTracker = {
                    Enabled = true,      -- Enable objective tracker font skinning
                    QuestTextSize = 12,  -- Font size for quest text
                    QuestTitleSize = 13, -- Font size for quest titles
                },
                ZoneText = {
                    Hide = false,
                    SubZone = {
                        Size = 20,
                    },
                    MainZone = {
                        Size = 40,
                        Anchor = "TOP", -- Anchor point
                        X = 0,          -- X offset
                        Y = -200,       -- Y offset
                    },
                },
            },

            -- Tooltip Skinning
            Tooltips = {
                Enabled = true,                     -- Master toggle for tooltip skinning
                BackgroundColor = { 0, 0, 0, 0.8 }, -- nil = use Theme.bgDark
                BorderColor = { 0, 0, 0, 1 },       -- Black border
                BorderSize = 1,                     -- Border thickness
                HideHealthBar = true,               -- Hide health bar on unit tooltips
                Font = "Expressway",                -- Font face
                FontOutline = "OUTLINE",            -- Font outline
                NameFontSize = 17,                  -- Name Font size
                GuildFontSize = 14,                 -- Guild Font size
                RaceLevelFontSize = 14,             -- RaceLevel Font size
                SpecFontSize = 14,                  -- Spec Fontsize
                FactionFontSize = 14,               -- Faction Font size
                -- Position Settings
                anchorFrameType = "UIPARENT",       -- Anchor frame type
                ParentFrame = "UIParent",           -- Parent frame name
                Position = {                        -- Position settings
                    AnchorFrom = "BOTTOMRIGHT",     -- Anchor point from
                    AnchorTo = "BOTTOMRIGHT",       -- Anchor point to
                    XOffset = -1,                   -- X offset
                    YOffset = 350,                  -- Y offset
                },
            },

            -- Details Backdrop Settings
            DetailsBackdrop = {
                Enabled = true,
                detailsBarH = 26,
                detailsSpacing = 1,
                detailsTitelH = 20,
                detailsWidth = 260,
                backDropOne = {
                    Enabled = true,
                    autoSize = false,
                    detailsBars = 7,
                    width = 260,
                    height = 210,
                    BackgroundColor = { 0, 0, 0, 0.8 },
                    BorderColor = { 0, 0, 0, 1 },
                    anchorFrameType = "UIPARENT",
                    ParentFrame = "UIParent",
                    Strata = "LOW",
                    Position = {
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "BOTTOMRIGHT",
                        XOffset = -1,
                        YOffset = 1,
                    },
                },
                backDropTwo = {
                    Enabled = true,
                    autoSize = false,
                    detailsBars = 7,
                    width = 260,
                    height = 210,
                    BackgroundColor = { 0, 0, 0, 0.8 },
                    BorderColor = { 0, 0, 0, 1 },
                    anchorFrameType = "UIPARENT",
                    ParentFrame = "UIParent",
                    Strata = "LOW",
                    Position = {
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "BOTTOMRIGHT",
                        XOffset = -262,
                        YOffset = 1,
                    },
                },
            }
        },

        -- Custom Buff Trackers
        CustomBuffs = {
            -- Buff Bars (StatusBar style trackers)
            Bars = {
                Enabled = true,
                GrowthDirection = "DOWN", -- DOWN, UP, LEFT, RIGHT
                Spacing = 1,
                -- Position settings
                anchorFrameType = "SCREEN",
                Position = {
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    XOffset = 0.1,
                    YOffset = 100.1,
                },
                -- Trackers stored by index, each has SpellID + Duration + optional overrides
                Trackers = {},
                -- Default settings for new bars (used as template)
                Defaults = {
                    BarWidth = 200,
                    BarHeight = 20,
                    IconSize = 20,
                    ShowIcon = true,
                    ShowTimeText = true,
                    ShowSpellText = true,
                    FontSize = 12,
                    BarColor = { 0.65, 0.65, 0.65, 1 },
                    BackgroundColor = { 0, 0, 0, 0.8 },
                    BorderColor = { 0, 0, 0, 1 },
                    Reverse = false,
                    StatusBarTexture = "NorskenUI", -- LSM statusbar texture name
                },
            },

            -- Buff Icons (Icon with cooldown style trackers)
            Icons = {
                Enabled = true,
                GrowthDirection = "RIGHT", -- LEFT, RIGHT, UP, DOWN
                Spacing = 1,
                -- Position settings
                anchorFrameType = "SCREEN",
                Position = {
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    XOffset = 0.1,
                    YOffset = 150.1,
                },
                Trackers = {},
                -- Default settings for new icons
                Defaults = {
                    IconSize = 40,
                    ShowCooldownText = true,
                    CountdownSize = 18,
                    BorderColor = { 0, 0, 0, 1 },
                },
            },
        },

        -- Missing Buffs Tracker
        MissingBuffs = {
            -- General Settings
            Enabled = true,          -- Enable/disable module
            IconSize = 48,           -- Icon size
            IconSpacing = 1,         -- Spacing between icons
            Strata = "HIGH",         -- Frame strata
            Font = "Expressway",     -- Font face
            FontSize = 12,           -- Font size
            FontOutline = "OUTLINE", -- Font outline
            HideWhileMounted = true, -- Hide when mounted

            -- Raid & General Buffs Settings
            NotifyLowDuration = false, -- Notify when buff is about to expire
            LowDurationThreshold = 5,  -- Minutes remaining to trigger reapply notification

            -- Consumable Tracking
            Consumables = {
                Flask = { Enabled = true, LoadCondition = "ANYGROUP" },
                Food = { Enabled = true, LoadCondition = "ANYGROUP" },
                MHEnchant = { Enabled = true, LoadCondition = "ANYGROUP" },
                OHEnchant = { Enabled = true, LoadCondition = "ANYGROUP" },
                Rune = { Enabled = true, LoadCondition = "RAID" },
                RaidBuffs = { Enabled = true, LoadCondition = "ANYGROUP" },
            },

            -- Raid Buff Display Settings (separate position from main)
            RaidBuffDisplay = {
                IconSize = 48,
                IconSpacing = 1,
                Strata = "HIGH",
                anchorFrameType = "UIPARENT",
                ParentFrame = "UIParent",
                Position = {
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    XOffset = 0.1,
                    YOffset = -375.1,
                },
            },

            -- Stance & Spec Buff Settings
            Stances = {
                Enabled = true, -- Master toggle for stance tracking

                -- Warrior Stances
                WARRIOR = {
                    Enabled = true,            -- Warn if no stance active
                    ArmsEnabled = false,       -- Require specific stance for Arms
                    Arms = "386164",           -- Battle Stance
                    FuryEnabled = false,       -- Require specific stance for Fury
                    Fury = "386196",           -- Berserker Stance
                    ProtectionEnabled = false, -- Require specific stance for Protection
                    Protection = "386208",     -- Defensive Stance
                },

                -- Paladin Auras
                PALADIN = {
                    Enabled = true,
                    HolyEnabled = false,
                    Holy = "465",          -- Devotion Aura
                    ProtectionEnabled = false,
                    Protection = "465",    -- Devotion Aura
                    RetributionEnabled = false,
                    Retribution = "32223", -- Crusader Aura
                },

                -- Druid Forms
                DRUID = {
                    Enabled = true,
                    BalanceEnabled = true,
                    Balance = "24858", -- Moonkin Form
                    FeralEnabled = true,
                    Feral = "768",     -- Cat Form
                    GuardianEnabled = true,
                    Guardian = "5487", -- Bear Form
                },

                -- Priest Shadowform
                PRIEST = {
                    ShadowEnabled = true, -- Require Shadowform for Shadow spec
                },

                -- Evoker Attunements
                EVOKER = {
                    Enabled = true,
                    AugmentationEnabled = false,
                    Augmentation = "403264", -- Black Attunement
                },
            },

            -- Stance Display Settings (separate position)
            StanceDisplay = {
                IconSize = 38,
                Strata = "HIGH",
                anchorFrameType = "UIPARENT",
                ParentFrame = "UIParent",
                Position = {
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    XOffset = 0,
                    YOffset = -150,
                },
            },

            -- Stance Text Display Settings
            StanceText = {
                Enabled = false, -- Enable stance text display
                Font = "Expressway",
                FontOutline = "OUTLINE",
                FontSize = 14,
                Strata = "HIGH",
                anchorFrameType = "UIPARENT",
                ParentFrame = "UIParent",
                Position = {
                    AnchorFrom = "CENTER",
                    AnchorTo = "CENTER",
                    XOffset = -250,
                    YOffset = -130,
                },

                -- Warrior Stance Texts
                WARRIOR = {
                    ["386164"] = { Enabled = true, Text = "BATTLE", Color = { 1, 0, 0, 1 } },
                    ["386196"] = { Enabled = true, Text = "BER", Color = { 1, 0, 0, 1 } },
                    ["386208"] = { Enabled = true, Text = "DEF", Color = { 0.3, 0.7, 1, 1 } },
                },

                -- Paladin Aura Texts
                PALADIN = {
                    ["465"] = { Enabled = true, Text = "DEVO", Color = { 0.3, 0.7, 1, 1 } },
                    ["317920"] = { Enabled = true, Text = "CONC", Color = { 0.9, 0.5, 1, 1 } },
                    ["32223"] = { Enabled = true, Text = "CRU", Color = { 1, 0.8, 0.3, 1 } },
                },
            },

            -- Custom buffs to track (spellId based)
            CustomBuffs = {
            },
        },
    },
}

-- Returns the Default Table.
function NRSKNUI:GetDefaultDB()
    return Defaults
end

-- Position Card Template
--[[

                anchorFrameType = "UIPARENT",
                ParentFrame = "UIParent",
                Strata = "LOW",
                Position = {
                    AnchorFrom = "BOTTOMRIGHT",
                    AnchorTo = "BOTTOMRIGHT",
                    XOffset = -1,
                    YOffset = 1,
                },

]]

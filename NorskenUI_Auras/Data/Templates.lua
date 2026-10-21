---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

--[[
What new displays start from:
Each type's style, the sub elements a new icon or bar gets, the built-in aura groups and the resource each class counts in points.
]]

local pairs, ipairs = pairs, ipairs
local setmetatable = setmetatable
local CopyTable = CopyTable
local type = type

local PowerType = Enum and Enum.PowerType

-- Styles --

-- Every new icon starts from this; an icon owns its full style from then on.
CDM.STYLE_TEMPLATE = {
    Width = 40,
    Height = 40,
    KeepAspectRatio = false,
    Color = { 1, 1, 1, 1 },
    Desaturate = false,
    IconSource = 'auto',
    Tooltip = false,
    Alpha = 1,
    DrawSwipe = true,
    Reverse = false,
    DrawEdge = false,
    SwipeColor = { 0, 0, 0, 0.7 },
    ShowGCD = false,
    HideCountdown = true,
    -- The cooldown frame's own number: unlike a %p text it follows recovery-rate buffs the way the action bar does.
    TimerText = {
        UseGlobalFont = true,
        FontFace = 'Expressway',
        FontSize = 15,
        FontOutline = 'OUTLINE',
        Color = { 1, 1, 1, 1 },
        AnchorTo = 'CENTER',
        XOffset = 0,
        YOffset = 0,
    },
}

-- Every new bar starts from this; the icon keys stay so a bar's icon reads the same as an icon's.
---@type table
CDM.BAR_STYLE_TEMPLATE = CopyTable(CDM.STYLE_TEMPLATE)
for key, value in pairs({
    Width = 200,
    Height = 20,
    DrawSwipe = false,
    UseGlobalBar = true,
    StatusBarTexture = 'NorskenUI',
    BarColorMode = 'custom',
    BarColor = { 0.35, 0.55, 0.85, 1 },
    BackgroundColor = { 0, 0, 0, 0.8 },
    Orientation = 'HORIZONTAL',
    ReverseFill = false,
    Inverse = false,
    Smooth = true,
    Spark = true,
    UseGlobalSpark = true,
    SparkTexture = 'Solid',
    SparkScale = 1,
    SparkWidth = 2,
    SparkColor = { 1, 1, 1, 1 },
    IconShow = true,
    IconSide = 'LEFT',
    LatencyColor = { 1, 0.2, 0.2, 0.5 },
    PipSpacing = 1,
}) do
    CDM.BAR_STYLE_TEMPLATE[key] = value
end

-- A text has no icon; Width/Height are only its cell in a Grid dynamic group, everywhere else it fits its text.
---@type table
CDM.TEXT_STYLE_TEMPLATE = CopyTable(CDM.STYLE_TEMPLATE)
CDM.TEXT_STYLE_TEMPLATE.Width = 100
CDM.TEXT_STYLE_TEMPLATE.Height = 20
CDM.TEXT_STYLE_TEMPLATE.DrawSwipe = false

local STYLE_TEMPLATES = {
    bar = CDM.BAR_STYLE_TEMPLATE,
    text = CDM.TEXT_STYLE_TEMPLATE
}

---An icon's, bar's or text's style; keys added after it was saved read from its type's template.
---@param display table
---@return table
function CDM:GetStyle(display)
    local template = STYLE_TEMPLATES[display.type] or CDM.STYLE_TEMPLATE
    return setmetatable({}, {
        __index = function(_, key)
            local value = display.Style[key]
            if value == nil then
                return template[key]
            end
            return value
        end,
    })
end

-- Sub elements --

CDM.SUBREGION_TEMPLATES = {
    text = {
        type = 'text',
        Enabled = true,
        Text = '%p',
        UseGlobalFont = true,
        FontFace = 'Expressway',
        FontOutline = 'OUTLINE',
        FontShadow = { Enabled = false, Color = { 0, 0, 0, 1 }, OffsetX = 1, OffsetY = -1 },
        FontSize = 15,
        Color = { 1, 1, 1, 1 },
        TimeFormat = 'global',
        PrecisionBelow = 3,
        Precision = 1,
        NumberFormat = 'auto', -- values (power, stats): auto, decimals, abbreviate, large, breakup, percent (power only)
        Decimals = 1,
        NameFormat = 'full',   -- %n: full, initial, upper
        NameColor = 'custom',  -- %n: custom (the text's Color), class, theme
        Rotation = 'NONE',
        Justify = 'AUTO',
        WidthMode = 'auto',
        FixedWidth = 64,
        WordWrap = true,
        Position = { AnchorFrom = 'AUTO', AnchorTo = 'CENTER', XOffset = 0, YOffset = 0 },
    },
    border = {
        type = 'border',
        Enabled = true,
        Color = { 0, 0, 0, 1 },
        Size = 1,
        Offset = 0,
    },
    tick = {
        type = 'tick',
        Enabled = true,
        Color = { 0, 0, 0, 1 },
        Placement = 'auto',
        Placements = '50',
        Thickness = 1,
        AutoLength = true,
        Length = 10,
    },
    glow = {
        type = 'glow',
        Enabled = false,
        Type = 'modern',
        ColorMode = 'default',
        Color = { 0.95, 0.95, 0.32, 1 },
        Lines = 8,
        Frequency = 0.25,
        Length = 10,
        Thickness = 2,
        Border = true,
        StartAnim = true,
    },
}

---A new sub element of a type, optionally changed by overrides.
---@param kind string
---@param overrides table?
---@return table
function CDM:NewSubRegion(kind, overrides)
    local element = CopyTable(CDM.SUBREGION_TEMPLATES[kind])
    for key, value in pairs(overrides or {}) do
        element[key] = type(value) == 'table' and CopyTable(value) or value
    end

    return element
end

---A new icon's elements: a 1px black border, time left in the middle, charges in the corner.
---@return table[]
function CDM:DefaultIconSubRegions()
    return {
        CDM:NewSubRegion('border'),
        CDM:NewSubRegion('text'),
        CDM:NewSubRegion('text', { Text = '%s', FontSize = 13, Position = { AnchorFrom = 'AUTO', AnchorTo = 'BOTTOMRIGHT', XOffset = -1, YOffset = 2 } }),
    }
end

---A new bar's elements: a 1px border, the name on the left and the time or value on the right.
---@return table[]
function CDM:DefaultBarSubRegions()
    return {
        CDM:NewSubRegion('border'),
        CDM:NewSubRegion('text', { Text = '%n', FontSize = 12, Position = { AnchorFrom = 'AUTO', AnchorTo = 'LEFT', XOffset = 4, YOffset = 0 } }),
        CDM:NewSubRegion('text', { Text = '%p', FontSize = 12, Position = { AnchorFrom = 'AUTO', AnchorTo = 'RIGHT', XOffset = -4, YOffset = 0 } }),
    }
end

-- Class resources --

-- The resource a class counts in points.
CDM.CLASS_RESOURCES = {
    DEATHKNIGHT = PowerType.Runes,
    PALADIN = PowerType.HolyPower,
    ROGUE = PowerType.ComboPoints,
    DRUID = PowerType.ComboPoints,
    MONK = PowerType.Chi,
    WARLOCK = PowerType.SoulShards,
    MAGE = PowerType.ArcaneCharges,
    EVOKER = PowerType.Essence,
}

-- Built-in aura groups --

-- What the built-in aura groups share; each one below changes only what sets it apart.
local BUILTIN_BASE = {
    Enabled = true,
    size = 50,
    perRow = 6,
    maxFrameCount = 6,
    previewLimit = 6,
    elementSpacing = 1,
    lineSpacing = 1,
    horizontalGrowthDirection = 'LEFT',
    verticalGrowthDirection = 'UP',
    sortMethod = 'ExpirationOnly',
    sortDirection = 'Normal',
    showApplicationCount = true,
    showDurationText = true,
    drawSwipe = false,
    drawEdge = false,
    reverseSwipe = true,
    tooltipHideInCombat = false,
    UseGlobalFont = true,
    FontFace = 'Expressway',
    FontOutline = 'OUTLINE',
    StackFont = { FontSize = 14, Position = { AnchorFrom = 'BOTTOMRIGHT', XOffset = 0, YOffset = 2 } },
    DurationFont = { FontSize = 18, Position = { AnchorFrom = 'CENTER', XOffset = 0, YOffset = 0 } },
    FontShadow = { Enabled = false, Color = { 0, 0, 0, 1 }, OffsetX = 1, OffsetY = -1 },
    anchorFrameType = 'SELECTFRAME',
    ParentFrame = 'NUF_Player',
}

---@param into table
---@param from table
---@return table into
local function Merge(into, from)
    for key, value in pairs(from) do
        if type(value) == 'table' and type(into[key]) == 'table' then
            Merge(into[key], value)
        else
            into[key] = value
        end
    end

    return into
end

---@param overrides table
---@return table
local function Builtin(overrides)
    return Merge(CopyTable(BUILTIN_BASE), overrides)
end

-- The aura groups a new profile starts with, inside the General Trackers group; each trigger starts from its preset.
CDM.BUILTIN_AURA_GROUPS = {
    {
        key = 'builtin:advancedDebuffs',
        preset = 'preset:advancedDebuffs',
        display = Builtin({
            name = 'Advanced Debuffs',
            Icon = 1396978,
            showBorder = true,
            showBorderWithoutDispelType = true,
            showDebuffDispelIcon = true,
            dispelIconSize = 12,
            Position = { AnchorFrom = 'BOTTOMRIGHT', AnchorTo = 'TOPRIGHT', XOffset = 0, YOffset = 120 },
        }),
    },
    {
        key = 'builtin:defensives',
        preset = 'preset:defensives',
        display = Builtin({
            name = 'Defensives',
            Icon = 132360,
            Position = { AnchorFrom = 'BOTTOMRIGHT', AnchorTo = 'TOPRIGHT', XOffset = 0, YOffset = 40 },
        }),
    },
    {
        key = 'builtin:generalBuffs',
        preset = 'preset:generalBuffs',
        display = Builtin({
            name = 'General Buffs',
            Icon = 4374707,
            size = 36,
            perRow = 1,
            maxFrameCount = 10,
            previewLimit = 5,
            sortMethod = 'AuraInstanceIDOnly',
            StackFont = { FontSize = 12 },
            DurationFont = { FontSize = 14 },
            ParentFrame = 'NUF_Target',
            Position = { AnchorFrom = 'BOTTOMRIGHT', AnchorTo = 'TOPLEFT', XOffset = -30, YOffset = 120 },
        }),
    },
    {
        key = 'builtin:speed',
        preset = 'preset:speed',
        display = Builtin({
            name = 'Speed',
            Icon = 648208,
            size = 42,
            Position = { AnchorFrom = 'RIGHT', AnchorTo = 'LEFT', XOffset = -1, YOffset = 0 },
        }),
    },
}
for _, builtin in ipairs(CDM.BUILTIN_AURA_GROUPS) do
    CDM.BUILTIN_AURA_GROUPS[builtin.key] = builtin -- also by key, which saved displays and migrations look them up by
end

-- The group a new profile's built-ins live in.
CDM.BUILTIN_FOLDER = { name = 'General Trackers', Icon = 464820, Strata = 'HIGH' }

---A built-in aura group as it shipped, its trigger fresh from its preset.
---@param key string
---@return table? display
function CDM:NewBuiltinAuraGroup(key)
    local builtin = CDM.BUILTIN_AURA_GROUPS[key]
    if not builtin then return nil end

    local display = CopyTable(builtin.display)
    display.type = 'auragroup'
    display.builtin = key
    display.Trigger = NRSKNUI.AuraTriggers:ToAuraFilter({ Type = NRSKNUI.AuraTriggers.Types.Preset, Preset = builtin.preset, Unit = 'player' })
    display.Load = NRSKNUI.LoadConditions:GetDefaults()
    return display
end

---@class NRSKNUI
local NRSKNUI = select(2, ...)
local Theme = NRSKNUI.Theme

-- Module with a bunch of color utilities

local math_floor = math.floor
local string_format = string.format
local type = type
local tonumber = tonumber
local CreateColor = CreateColor
local select = select
local unpack = unpack
local modf = math.modf
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

---An { r, g, b, a? } color array with 0-1 components.
---@alias RGBA number[]

-- Class color hex codes table
---@type { DEATHKNIGHT: "C41E3A", DEMONHUNTER: "A330C9", DRUID: "FF7C0A", EVOKER: "33937F", HUNTER: "AAD372", MAGE: "3FC7EB", MONK: "00FF98", PALADIN: "F48CBA", PRIEST: "FFFFFF", ROGUE: "FFF468", SHAMAN: "0070DD", WARLOCK: "8788EE", WARRIOR: "C69B6D" }
NRSKNUI.ClassColorHex = {
    DEATHKNIGHT = "C41E3A",
    DEMONHUNTER = "A330C9",
    DRUID = "FF7C0A",
    EVOKER = "33937F",
    HUNTER = "AAD372",
    MAGE = "3FC7EB",
    MONK = "00FF98",
    PALADIN = "F48CBA",
    PRIEST = "FFFFFF",
    ROGUE = "FFF468",
    SHAMAN = "0070DD",
    WARLOCK = "8788EE",
    WARRIOR = "C69B6D",
}

---Get the player's class color as an RGBA table.
---@return RGBA
function NRSKNUI:GetPlayerClassColor()
    local class = self.MyClass
    if class and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return { c.r, c.g, c.b, 1 }
    end
    return { 1, 1, 1, 1 }
end

---Get a class color as an RGBA table for any class token, falling back to the player's class.
---@param classToken? string
---@return RGBA
function NRSKNUI:GetClassColor(classToken)
    if not classToken then
        return self:GetPlayerClassColor()
    end
    if RAID_CLASS_COLORS[classToken] then
        local c = RAID_CLASS_COLORS[classToken]
        return { c.r, c.g, c.b, 1 }
    end
    return { 1, 1, 1, 1 }
end

---Get a class color hex code ("RRGGBB") for text coloring, falling back to the player's class.
---@param classToken? string
---@return string hex
function NRSKNUI:GetClassColorHex(classToken)
    -- Validate classToken is a string before using as table key
    if type(classToken) == "string" then
        local hex = self.ClassColorHex[classToken]
        if hex then return hex end
    end
    -- Fallback to player class
    return self.ClassColorHex[self.MyClass] or "FFFFFF"
end

---Get the RAID_CLASS_COLORS entry for a class token, falling back to the player's class.
---@param classToken? string
---@return ColorMixin
function NRSKNUI:GetClassColorRaw(classToken)
    -- Validate classToken is a string before using as table key
    if type(classToken) == "string" then
        local color = RAID_CLASS_COLORS[classToken]
        if color then return color end
    end
    -- Fallback to player class
    return RAID_CLASS_COLORS[self.MyClass]
end

---Wrap text in a class color escape code.
---@param text string
---@param classToken? string
---@return string
function NRSKNUI:ColorTextByClass(text, classToken)
    local hex = self:GetClassColorHex(classToken)
    return "|cFF" .. hex .. text .. "|r"
end

---Convert 0-1 RGB components to an "RRGGBB" hex string.
---@param r? number
---@param g? number
---@param b? number
---@return string hex
function NRSKNUI:RGBAToHex(r, g, b)
    r = math_floor((r or 1) * 255 + 0.5)
    g = math_floor((g or 1) * 255 + 0.5)
    b = math_floor((b or 1) * 255 + 0.5)
    return string_format("%02X%02X%02X", r, g, b)
end

---Get the theme accent color as an "RRGGBB" hex string.
---@return string hex
function NRSKNUI:GetThemeColorHex()
    if Theme and Theme.accent then
        return self:RGBAToHex(Theme.accent[1], Theme.accent[2], Theme.accent[3])
    end
    return "e51039"
end

---Wrap text in the theme accent color escape code.
---@param text string
---@return string
function NRSKNUI:ColorTextByTheme(text)
    local hex = self:GetThemeColorHex()
    return "|cFF" .. hex .. text .. "|r"
end

---Get accent color components based on mode.
---@param colorMode? "class"|"theme"|"custom"
---@param customColor? RGBA Used when colorMode is "custom"
---@return number r, number g, number b, number a
function NRSKNUI:GetAccentColor(colorMode, customColor)
    colorMode = colorMode or "custom"

    if colorMode == "class" then
        local classColor = self:GetPlayerClassColor()
        return classColor[1], classColor[2], classColor[3], classColor[4]
    elseif colorMode == "theme" then
        if Theme and Theme.accent then
            return Theme.accent[1], Theme.accent[2], Theme.accent[3], Theme.accent[4] or 1
        end
        return 1, 0.82, 0, 1
    else
        -- Validate custom color
        if customColor and type(customColor) == "table" and #customColor >= 3 then
            return customColor[1] or 1, customColor[2] or 1, customColor[3] or 1, customColor[4] or 1
        end
        return 1, 1, 1, 1
    end
end

---Create a color from basically anything: 0-1 RGB, 0-255 RGB, a hex string ("RRGGBB" or "AARRGGBB", optionally "#"-prefixed), or an { r, g, b, a } table.
---@param r number|string|{ r: number, g: number, b: number, a: number? }
---@param g? number
---@param b? number
---@param a? number
---@return ColorMixin
function NRSKNUI:CreateColor(r, g, b, a)
    if type(r) == 'table' then
        return NRSKNUI:CreateColor(r.r, r.g, r.b, r.a)
    elseif type(r) == 'string' then
        -- load from hex
        local hex = r:gsub('#', '')
        if #hex == 8 then
            -- prefixed with alpha
            a = tonumber(hex:sub(1, 2), 16) / 255
            r = tonumber(hex:sub(3, 4), 16) / 255
            g = tonumber(hex:sub(5, 6), 16) / 255
            b = tonumber(hex:sub(7, 8), 16) / 255
        elseif #hex == 6 then
            r = tonumber(hex:sub(1, 2), 16) / 255
            g = tonumber(hex:sub(3, 4), 16) / 255
            b = tonumber(hex:sub(5, 6), 16) / 255
        end
    elseif r > 1 or g > 1 or b > 1 then
        r = r / 255
        g = g / 255
        b = b / 255
    end
    local color = CreateColor(r --[[@as number]], g, b, a)
    return color
end

-- Color mode options for dropdowns in the GUI
---@type { key: "class"|"custom"|"theme", text: string }[]
NRSKNUI.ColorModeOptions = {
    { key = "class",  text = "Class Color" },
    { key = "custom", text = "Custom Color" },
    { key = "theme",  text = "Theme Color" },
}

---Blend between RGB triplets based on the Min/Max ratio.
---@param Min number
---@param Max number
---@param ... number RGB triplets (r1, g1, b1, r2, g2, b2, ...)
---@return number r, number g, number b
---@return ...number
function NRSKNUI:ColorGradient(Min, Max, ...)
    local Percent = (Max == 0) and 0 or (Min / Max)

    if Percent >= 1 then
        return select(select("#", ...) - 2, ...)
    elseif Percent <= 0 then
        return ...
    end

    local Num = select("#", ...) / 3
    local Segment, RelPercent = modf(Percent * (Num - 1))

    local R1, G1, B1, R2, G2, B2 = select((Segment * 3) + 1, ...)
    return
        R1 + (R2 - R1) * RelPercent,
        G1 + (G2 - G1) * RelPercent,
        B1 + (B2 - B1) * RelPercent
end

---Wrap text in a color escape code built from an RGBA table.
---@param text string
---@param color RGBA
---@return string
function NRSKNUI:ColorText(text, color)
    local r, g, b, a = unpack(color)
    return string.format(
        "|c%02X%02X%02X%02X%s|r",
        (a or 1) * 255,
        r * 255,
        g * 255,
        b * 255,
        text
    )
end

local DispelType = NRSKNUI.Enum.DispelType

---@type table<NRSKNUI.DispelType, ColorMixin>
local defaultDispelColors = {
    [DispelType.None] = _G.DEBUFF_TYPE_NONE_COLOR,
    [DispelType.Magic] = _G.DEBUFF_TYPE_MAGIC_COLOR,
    [DispelType.Curse] = _G.DEBUFF_TYPE_CURSE_COLOR,
    [DispelType.Disease] = _G.DEBUFF_TYPE_DISEASE_COLOR,
    [DispelType.Poison] = _G.DEBUFF_TYPE_POISON_COLOR,
    [DispelType.Bleed] = _G.DEBUFF_TYPE_BLEED_COLOR,
    [DispelType.Enrage] = NRSKNUI:CreateColor(243, 95, 245),
}

---@type { dispel: table<NRSKNUI.DispelType, ColorMixin> }
local colors = {
    dispel = {},
}

for k, v in pairs(defaultDispelColors) do
    colors.dispel[k] = v
end

NRSKNUI.colors = colors

local dispelColorCurve
local dispelColorGeneration = 0
local curveGeneration = -1

---Get a step ColorCurve mapping dispel type index to color, rebuilt when colors change.
function NRSKNUI:GetDispelColorCurve()
    if dispelColorCurve and curveGeneration == dispelColorGeneration then
        return dispelColorCurve
    end

    if not dispelColorCurve then
        dispelColorCurve = C_CurveUtil.CreateColorCurve()
        dispelColorCurve:SetType(Enum.LuaCurveType.Step)
    else
        dispelColorCurve:ClearPoints()
    end

    for _, dispelIndex in next, DispelType do
        local color = colors.dispel[dispelIndex]
        if color then
            dispelColorCurve:AddPoint(dispelIndex, color --[[@as colorRGBA]])
        end
    end

    curveGeneration = dispelColorGeneration
    return dispelColorCurve
end

---Get the configured color for a dispel type as an RGBA table.
---@param dispelType NRSKNUI.DispelType
---@return RGBA
function NRSKNUI:GetDispelColor(dispelType)
    local color = colors.dispel[dispelType]
    if color then
        return { color:GetRGBA() } --[[@as RGBA]]
    end
    local fallback = colors.dispel[DispelType.None]
    if fallback then
        return { fallback:GetRGBA() } --[[@as RGBA]]
    end
    return { 0.8, 0, 0, 1 }
end

---Get the default color for a dispel type as an RGBA table.
---@param dispelType NRSKNUI.DispelType
---@return RGBA
function NRSKNUI:GetDefaultDispelColor(dispelType)
    local color = defaultDispelColors[dispelType]
    if color then
        return { color:GetRGBA() } --[[@as RGBA]]
    end
    return { 0.8, 0, 0, 1 }
end

---@type table<string, NRSKNUI.DispelType>
local dispelTypeNameToIndex = {
    None = DispelType.None,
    Magic = DispelType.Magic,
    Curse = DispelType.Curse,
    Disease = DispelType.Disease,
    Poison = DispelType.Poison,
    Bleed = DispelType.Bleed,
    Enrage = DispelType.Enrage,
}
NRSKNUI.DispelTypeNameToIndex = dispelTypeNameToIndex

---Set a custom dispel color, or reset it to the default when r/g/b are omitted.
---@param dispelTypeName string One of "None", "Magic", "Curse", "Disease", "Poison", "Bleed", "Enrage"
---@param r? number
---@param g? number
---@param b? number
---@param a? number
function NRSKNUI:SetDispelColor(dispelTypeName, r, g, b, a)
    local index = dispelTypeNameToIndex[dispelTypeName]
    if not index then return end

    if r and g and b then
        colors.dispel[index] = self:CreateColor(r, g, b, a or 1)
    else
        colors.dispel[index] = defaultDispelColors[index]
    end
    dispelColorGeneration = dispelColorGeneration + 1
end

---Load custom dispel colors from the saved profile, resetting missing entries to defaults.
function NRSKNUI:LoadDispelColorsFromDB()
    local db = self.db.profile.Skinning.DebuffTracking
    if not db or not db.DispelColors then return end

    for name, index in pairs(dispelTypeNameToIndex) do
        local customColor = db.DispelColors[name]
        if customColor and type(customColor) == "table" and customColor[1] then
            colors.dispel[index] = self:CreateColor(customColor[1], customColor[2], customColor[3], customColor[4] or 1)
        else
            colors.dispel[index] = defaultDispelColors[index]
        end
    end
    dispelColorGeneration = dispelColorGeneration + 1
end

---@return number generation Increments whenever dispel colors change
function NRSKNUI:GetDispelColorGeneration()
    return dispelColorGeneration
end
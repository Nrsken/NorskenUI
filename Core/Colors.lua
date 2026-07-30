---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL

-- Module with a bunch of color utilities

local math_floor = math.floor
local format = string.format
local type = type
local tonumber = tonumber
local CreateColor = CreateColor
local select = select
local unpack = unpack
local modf = math.modf
local next = next

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
    local c = self.Colors.class[self.MyClass]
    if c then return { c.r, c.g, c.b, 1 } end
    return { 1, 1, 1, 1 }
end

---Get a class color as an RGBA table for any class token, falling back to the player's class.
---@param classToken? string
---@return RGBA
function NRSKNUI:GetClassColor(classToken)
    if not classToken then
        return self:GetPlayerClassColor()
    end
    local c = self.Colors.class[classToken]
    if c then return { c.r, c.g, c.b, 1 } end
    return { 1, 1, 1, 1 }
end

---Get the class-color ColorMixin for a class token, falling back to the player's class.
---@param classToken? string
---@return ColorMixin
function NRSKNUI:GetClassColorRaw(classToken)
    if type(classToken) == "string" and self.Colors.class[classToken] then
        return self.Colors.class[classToken]
    end
    return self.Colors.class[self.MyClass]
end

---Get a class color hex code ("RRGGBB") for text coloring, falling back to the player's class.
---@param classToken? string
---@return string hex
function NRSKNUI:GetClassColorHex(classToken)
    local c = self:GetClassColorRaw(classToken)
    return c and self:RGBAToHex(c.r, c.g, c.b) or "FFFFFF"
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
    return format("%02X%02X%02X", r, g, b)
end

---Get the theme accent color as an "RRGGBB" hex string.
---@return string hex
function NRSKNUI:GetThemeColorHex()
    return self.GUI:RGBAToHex(self.GUI:Color("accent"))
end

---Wrap text in the theme accent color escape code.
---@param text string
---@return string
function NRSKNUI:ColorTextByTheme(text)
    return self.GUI:ColorText(text)
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
        return self.GUI:Color("accent")
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
    { key = "class",  text = L['Class Color'] },
    { key = "custom", text = L['Custom Color'] },
    { key = "theme",  text = L['Theme Color'] },
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
    return format("|c%02X%02X%02X%02X%s|r", (a or 1) * 255, r * 255, g * 255, b * 255, text)
end

NRSKNUI.Colors = {
    class = {},
    reaction = {},
    power = {},
    status = {},
    dispel = {},
    white = CreateColor(1, 1, 1, 1),
    warning = { 1, 0.55, 0.2, 1 },
    highlightColor = { 1, 1, 1, 0.25 },
    selectedColor = { 0.8, 0.8, 0.8, 0.25 },
    blackBgColor = { 0, 0, 0, 0.8 },
}

---Custom color palette (db.profile.Colors), pushed into oUF.colors and NRSKNUI.Colors.
function NRSKNUI:LoadCustomColors()
    local db = self.db and self.db.profile.Colors
    if not db then return end

    local oUF = self.oUF
    local palette = self.Colors

    for powerType, c in next, db.Power do
        local col = oUF:CreateColor(c[1], c[2], c[3])
        oUF.colors.power[powerType] = col
        palette.power[powerType] = col
    end

    for index, c in next, db.Reaction do
        local col = oUF:CreateColor(c[1], c[2], c[3])
        oUF.colors.reaction[index] = col
        palette.reaction[index] = col
    end

    for token, c in next, db.Class do
        local col = oUF:CreateColor(c[1], c[2], c[3])
        oUF.colors.class[token] = col
        palette.class[token] = col
    end

    for index, c in next, db.Dispel do
        local col = oUF:CreateColor(c[1], c[2], c[3])
        oUF.colors.dispel[index] = col
        palette.dispel[index] = col
    end

    -- Status colors are consumed directly (RGBA) by the health handler, mirror to oUF too.
    palette.status = db.Status
    oUF.colors.tapped = oUF:CreateColor(db.Status.Tapped[1], db.Status.Tapped[2], db.Status.Tapped[3])
    oUF.colors.disconnected = oUF:CreateColor(db.Status.Disconnected[1], db.Status.Disconnected[2], db.Status.Disconnected[3])
end

-- NorskenUI namespace
local _, NRSKNUI = ...
local Theme = NRSKNUI.Theme

-- Module with a bunch of color utilities

-- Localization
local UnitClass = UnitClass
local math_floor = math.floor
local string_format = string.format
local type = type
local tonumber = tonumber
local CreateColor = CreateColor
local select = select
local unpack = unpack
local modf = math.modf
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

-- Class color hex codes table
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

-- GetPlayerClassColor: Get player's class color as RGBA table
function NRSKNUI:GetPlayerClassColor()
    local _, class = UnitClass("player")
    if class and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return { c.r, c.g, c.b, 1 }
    end
    return { 1, 1, 1, 1 }
end

-- GetClassColor: Get class color as RGBA table for any class token
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

-- GetClassColorHex: Get class color hex code for text coloring
function NRSKNUI:GetClassColorHex(classToken)
    if not classToken then
        local _, class = UnitClass("player")
        classToken = class
    end
    return self.ClassColorHex[classToken] or "FFFFFF"
end

-- GetClassColorRaw: Get RAID_CLASS_COLORS entry for a class token
function NRSKNUI:GetClassColorRaw(classToken)
    if not classToken then
        local _, class = UnitClass("player")
        classToken = class
    end
    return RAID_CLASS_COLORS[classToken]
end

-- ColorTextByClass: Wrap text in class color
function NRSKNUI:ColorTextByClass(text, classToken)
    local hex = self:GetClassColorHex(classToken)
    return "|cFF" .. hex .. text .. "|r"
end

-- RGBAToHex: Convert RGBA (0-1) to hex string "RRGGBB"
function NRSKNUI:RGBAToHex(r, g, b)
    r = math_floor((r or 1) * 255 + 0.5)
    g = math_floor((g or 1) * 255 + 0.5)
    b = math_floor((b or 1) * 255 + 0.5)
    return string_format("%02X%02X%02X", r, g, b)
end

-- GetThemeColorHex: Get theme accent color as hex string
function NRSKNUI:GetThemeColorHex()
    if Theme and Theme.accent then
        return self:RGBAToHex(Theme.accent[1], Theme.accent[2], Theme.accent[3])
    end
    return "e51039"
end

-- ColorTextByTheme: Wrap text in theme accent color
function NRSKNUI:ColorTextByTheme(text)
    local hex = self:GetThemeColorHex()
    return "|cFF" .. hex .. text .. "|r"
end

-- GetAccentColor: Get accent color RGBA based on mode (class/theme/custom)
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

-- Function to create color from basically anything, hex, rgb (1,1,1) format or even >1 format
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
    local color = CreateColor(r, g, b, a)
    return color
end

-- Color mode options for dropdowns in the GUI
NRSKNUI.ColorModeOptions = {
    { key = "class",  text = "Class Color" },
    { key = "custom", text = "Custom Color" },
    { key = "theme",  text = "Theme Color" },
}

-- Create a gradient color
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

-- Color text with rgb -> hex
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

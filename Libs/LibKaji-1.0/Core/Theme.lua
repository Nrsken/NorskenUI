--[[
# Theme

* The instance-wide palette, metrics and fonts every widget reads from as `gui.theme`.
* Three modes drive the colors: a bundled `preset`, the player's `class` color, or the host's `custom` overrides.
* Widgets never poll: they subscribe with `OnThemeChanged` and restyle themselves when the mode or palette changes.
* A consuming addon can replace the bundled presets, the ordered preset list and the color-key editor metadata at `lib:New()`.

## Example

    GUI:SetMode('preset')
    GUI:SetPreset('NUI v2')

    GUI:OnThemeChanged(function()
        frame:SetBackdropColor(unpack(GUI.theme.bgDark))
    end)

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local LSM = LibStub("LibSharedMedia-3.0", true)

local type = type
local pairs = pairs
local ipairs = ipairs
local format = string.format
local floor = math.floor
local CreateFont = CreateFont

local FALLBACK_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local MEDIA = lib.mediaBase

local DEFAULT_THEME = {
    -- Backgrounds
    bgDark                  = { 0.0235, 0.0235, 0.0235, 0.6 },
    bgMedium                = { 0.0431, 0.0431, 0.0431, 1 },
    bgLight                 = { 0.1176, 0.1176, 0.1176, 1 },
    bgHover                 = { 0.22, 0.22, 0.24, 1 },
    -- Border
    border                  = { 0, 0, 0, 1 },
    -- Accent
    accent                  = { 0.8980, 0.0627, 0.2235, 1 },
    accentHover             = { 0.8980, 0.0627, 0.2235, 0.25 },
    accentDim               = { 0.8980, 0.0627, 0.2235, 1 },
    -- Text
    textPrimary             = { 0.95, 0.95, 0.95, 1 },
    textSecondary           = { 0.70, 0.70, 0.70, 1 },
    textMuted               = { 0.50, 0.50, 0.50, 1 },
    -- Selection
    selectedBg              = { 0.8980, 0.0627, 0.2235, 0.25 },
    selectedText            = { 0.8980, 0.0627, 0.2235, 1 },
    -- Status
    error                   = { 0.90, 0.30, 0.30, 1 },
    success                 = { 0.30, 0.80, 0.40, 1 },
    warning                 = { 0.90, 0.75, 0.30, 1 },
    -- Dimensions
    headerHeight            = 35,
    footerHeight            = 28,
    sidebarWidth            = 242,
    contentWidth            = 679.1,
    borderSize              = 1,
    -- Spacing
    paddingSmall            = 4,
    paddingMedium           = 8,
    paddingLarge            = 16,
    scrollbarWidth          = 17,
    -- Row heights
    rowHeight               = 40,
    rowHeightLast           = 44,
    rowHeightTall           = 80,
    rowHeightSeparator      = 8,
    rowHeightLabelSeparator = 22,
    -- Fonts
    fontFace                = FALLBACK_FONT,
    fontSizeSmall           = 12,
    fontSizeNormal          = 12,
    fontSizeLarge           = 16,
    fontOutline             = "OUTLINE",
    fontShadow              = false,
    -- Widget textures (consumers override to match their look)
    checkTexture            = MEDIA .. "ok-iconBlack.tga",
    crossTexture            = MEDIA .. "cross-small.png",
    crossCustomTexture      = MEDIA .. "NorskenCustomCross.png",
    stepperTexture          = MEDIA .. "collapse.tga",
    colorSwatchTexture      = MEDIA .. "NUIcolorPickerBG.png",
    resizeHandleTexture     = MEDIA .. "NorskenCustomResizeHandle23px.png",
    -- Animation
    animDuration            = 0.18,
}
lib.DEFAULT_THEME = DEFAULT_THEME

-- Expands a compact preset spec into the 16 color keys. Backgrounds share their RGB
-- (dark and medium differ only in alpha unless `medium` is given); accent variants are
-- derived from the accent color. Shared rows (text/status) are constant across presets.
local function BuildPreset(spec)
    local aC = spec.accent
    local aH = spec.accentHover or { aC[1], aC[2], aC[3], 0.25 }
    local aD = spec.accentDim or aC
    local dBG = spec.dark
    local mBG = spec.medium or spec.dark
    local lBG = spec.light
    local sBG = spec.selectedBg or { aC[1], aC[2], aC[3], 0.25 }
    local hBG = spec.bgHover or { 0.22, 0.22, 0.24, 1 }
    local tP = spec.textPrimary or { 0.95, 0.95, 0.95, 1 }
    local tS = spec.textSecondary or { 0.70, 0.70, 0.70, 1 }
    local tM = spec.textMuted or { 0.50, 0.50, 0.50, 1 }

    return {
        -- Backgrounds & Border
        bgDark = dBG,
        bgMedium = mBG,
        bgLight = lBG,
        bgHover = hBG,
        border = { 0, 0, 0, 1 },
        -- Accent Colors
        accent = aC,
        accentHover = aH,
        accentDim = aD,
        -- Text colors
        textPrimary = tP,
        textSecondary = tS,
        textMuted = tM,
        selectedBg = sBG,
        selectedText = aC,
        error = { 0.90, 0.30, 0.30, 1 },
        success = { 0.30, 0.80, 0.40, 1 },
        warning = { 0.90, 0.75, 0.30, 1 },
    }
end

-- Bundled preset themes. Consumers may override the whole set via New{ presets = ... }.
local THEME_PRESETS = {
    ["Warpaint"] = BuildPreset {
        dark = { 0.0745, 0.0588, 0.0510, 0.6 },
        light = { 0.1945, 0.1788, 0.1710, 1 },
        accent = { 0.7098, 0.2000, 0.1412 },
    },
    ["Greenwake"] = BuildPreset {
        dark = { 0.031, 0.106, 0.106, 0.6 },
        light = { 0.125, 0.231, 0.216, 1 },
        accent = { 0.933, 0.910, 0.698 },
    },
    ["Timberfall"] = BuildPreset {
        dark = { 0.092, 0.069, 0.018, 0.6 },
        light = { 0.286, 0.220, 0.118, 1 },
        accent = { 0.988, 0.361, 0.008 },
    },
    ["Obsidian"] = BuildPreset {
        dark = { 0.014, 0.047, 0.063, 0.6 },
        light = { 0.114, 0.147, 0.163, 1 },
        accent = { 0.900, 0.467, 0.976 },
        selectedBg = { 0.900, 0.467, 0.976, 0.25 },
    },
    ["Mocha"] = BuildPreset {
        dark = { 0.0588, 0.0559, 0.0294, 0.6 },
        light = { 0.1019, 0.0969, 0.0510, 1 },
        accent = { 0.7451, 0.9412, 0.0000 },
    },
    ["Frost"] = BuildPreset {
        dark = { 0.024, 0.078, 0.106, 0.6 },
        light = { 0.067, 0.129, 0.176, 1 },
        accent = { 0.790, 0.857, 0.872 },
    },
    ["Echo"] = BuildPreset {
        dark = { 0.0666, 0.0000, 0.0000, 0.6 },
        light = { 0.0705, 0.0705, 0.0705, 1 },
        accent = { 0.7803, 0.0000, 0.0000 },
    },
    ["Dark"] = BuildPreset {
        dark = { 0.0235, 0.0235, 0.0235, 0.6 },
        medium = { 0.0431, 0.0431, 0.0431, 0.8 },
        light = { 0.1176, 0.1176, 0.1176, 1 },
        accent = { 0.8980, 0.0627, 0.2235 },
    },
    ["NUI v2"] = BuildPreset {
        dark = { 0.015, 0.047, 0.062, 0.6 },
        light = { 0.113, 0.145, 0.164, 1 },
        accent = { 0, 1, 0.588 },
        selectedBg = { 0.8980, 0.0627, 0.2235, 0.25 },
        bgHover = { 0.219, 0.219, 0.239, 1 },
    },
    ["NUI v3"] = BuildPreset {
        dark = { 0, 0, 0, 0.5 },
        medium = { 0, 0, 0, 0.5 },
        light = { 0.17, 0.17, 0.17, 0.8 },
        accent = { 0.85, 1, 0.39 },
        bgHover = { 0.22, 0.22, 0.24, 1 },
        textPrimary = { 1, 1, 1, 1 },
        textSecondary = { 0.82, 0.82, 0.82, 1 },
        textMuted = { 0.5, 0.5, 0.5, 1 },
        selectedBg = { 0.68, 0.68, 0.68, 0.25 },
    },
}
lib.THEME_PRESETS = THEME_PRESETS

-- Ordered preset names for the theme picker.
local THEME_PRESET_NAMES = {
    "Echo", "Warpaint", "Greenwake", "Timberfall", "Obsidian", "Mocha", "Frost", "Dark", "NUI v2", "NUI v3",
}
lib.THEME_PRESET_NAMES = THEME_PRESET_NAMES

-- Editor metadata for every color key: display name, group, and whether it follows class color.
local THEME_COLOR_KEYS = {
    { key = "bgDark",        name = "Background Dark",     category = "Backgrounds" },
    { key = "bgMedium",      name = "Background Medium",   category = "Backgrounds" },
    { key = "bgLight",       name = "Background Light",    category = "Backgrounds" },
    { key = "bgHover",       name = "Background Hover",    category = "Backgrounds" },
    { key = "border",        name = "Border",              category = "Borders" },
    { key = "accent",        name = "Accent",              category = "Accent Colors",    supportsClassColor = true },
    { key = "accentHover",   name = "Accent Hover",        category = "Accent Colors",    supportsClassColor = true },
    { key = "accentDim",     name = "Accent Dim",          category = "Accent Colors",    supportsClassColor = true },
    { key = "textPrimary",   name = "Text Primary",        category = "Text Colors" },
    { key = "textSecondary", name = "Text Secondary",      category = "Text Colors" },
    { key = "textMuted",     name = "Text Muted",          category = "Text Colors" },
    { key = "selectedText",  name = "Selected Text",       category = "Text Colors",      supportsClassColor = true },
    { key = "selectedBg",    name = "Selected Background", category = "Selection Colors", supportsClassColor = true },
    { key = "error",         name = "Error",               category = "Status Colors" },
    { key = "success",       name = "Success",             category = "Status Colors" },
    { key = "warning",       name = "Warning",             category = "Status Colors" },
}
lib.THEME_COLOR_KEYS = THEME_COLOR_KEYS

-- Font keys resolved from the store alongside colors.
local FONT_KEYS = { "fontFace", "fontSizeNormal", "fontSizeSmall", "fontSizeLarge", "fontOutline", "fontShadow" }

-- Valid theme modes.
local VALID_MODES = { preset = true, class = true, custom = true }

-- Copies a color, padding to 4 components with sensible defaults.
local function copyColor(color)
    if type(color) ~= "table" then return { 1, 1, 1, 1 } end
    return { color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1 }
end

-- Overwrites dst's array part from src, keeping dst's identity.
local function overwriteArray(dst, src)
    for i = 1, #src do dst[i] = src[i] end
    for i = #src + 1, #dst do dst[i] = nil end
end

---Merges src's keys into dst. Table values are merged into the table already at that
---key rather than replacing it: widgets, animators and the host addon hold direct
---references to theme colors, and swapping the table would leave every one of them
---pointing at the previous palette. Only the first merge allocates.
local function mergeInto(dst, src)
    for key, value in pairs(src) do
        if type(value) == "table" then
            local existing = dst[key]
            if type(existing) == "table" then
                overwriteArray(existing, value)
            else
                -- Copy rather than alias: src may be DEFAULT_THEME or a caller's table.
                local copy = {}
                overwriteArray(copy, value)
                dst[key] = copy
            end
        else
            dst[key] = value
        end
    end
end

-- Resolves a font name to a path using LibSharedMedia or returns the fallback font if not found.
local function resolveFont(face)
    if LSM and type(face) == "string" then
        local byName = LSM:HashTable("font")[face]
        if byName then return byName end
    end
    return face or FALLBACK_FONT
end

-- Cached Font objects keyed by path|size|flags. Applying a shared Font object via
-- SetFontObject is reliable on a fresh client login, unlike a bare FontString:SetFont,
-- which can render blank until the client's glyph cache is warmed (e.g. by a /reload) -
-- most visibly on larger sizes the default UI never requests first.
local fontObjectCache = {}
local fontObjectIndex = 0
local function getFontObject(path, size, flags)
    local key = path .. "|" .. size .. "|" .. flags
    local obj = fontObjectCache[key]
    if not obj then
        fontObjectIndex = fontObjectIndex + 1
        obj = CreateFont("LibKajiFont" .. fontObjectIndex)
        obj:SetFont(path, size, flags)
        fontObjectCache[key] = obj
    end
    return obj
end

---@param overrides? table
function InstanceMixin:_InitTheme(overrides)
    self.theme = {}
    self._themeCallbacks = {}
    mergeInto(self.theme, DEFAULT_THEME)
    if overrides then mergeInto(self.theme, overrides) end

    -- Derive the flat color-key list and class-color key set from the (possibly overridden) metadata.
    self._colorKeyList = {}
    self._classColorKeys = {}
    for _, def in ipairs(self.colorKeys or THEME_COLOR_KEYS) do
        self._colorKeyList[#self._colorKeyList + 1] = def.key
        if def.supportsClassColor then self._classColorKeys[def.key] = true end
    end
end

---Returns the live theme table. Both it and every color table inside it keep their
---identity across theme changes (see mergeInto), so a held `theme.accent` reference
---always reads the current palette. Widgets and animators rely on this.
---@return table
function InstanceMixin:GetTheme()
    return self.theme
end

---Merges overrides over the current theme and notifies subscribers.
---@param overrides table
---@return KajiGUIInstance self
function InstanceMixin:SetTheme(overrides)
    if overrides then mergeInto(self.theme, overrides) end
    self:_FireThemeChanged()
    return self
end

---Resets the persisted store to preset mode on the default preset (preserving fonts)
---and re-resolves. Notifies subscribers.
---@return KajiGUIInstance self
function InstanceMixin:ResetTheme()
    local store = self:_Store()
    if store then
        store.mode = "preset"
        store.selectedPreset = self.defaultPreset
        store.customColors = {}
    end
    return self:ApplyTheme()
end

---Subscribes to theme changes. The callback receives the live theme table.
---@param callback fun(theme: table)
---@return fun() unsubscribe
function InstanceMixin:OnThemeChanged(callback)
    self._themeCallbacks[callback] = true
    return function() self._themeCallbacks[callback] = nil end
end

function InstanceMixin:_FireThemeChanged()
    -- Chrome (the window, sidebars, scrollbars) is built once and subscribes.
    for callback in pairs(self._themeCallbacks) do
        callback(self.theme)
    end

    -- Widgets don't subscribe: the set of acquired widgets is already an exact,
    -- bounded registry, so there is nothing to unsubscribe and nothing to leak.
    -- Released widgets are skipped and pick the new palette up in OnAcquire.
    for widget in pairs(self._acquired) do
        if widget.UpdateColors then widget:UpdateColors() end
    end
end

---Returns the r, g, b, a components of a theme color key.
---@param key string
---@return number r, number g, number b, number a
function InstanceMixin:Color(key)
    local c = self.theme[key]
    if type(c) == "table" then return c[1], c[2], c[3], c[4] or 1 end
    return 1, 1, 1, 1
end

---@param r? number
---@param g? number
---@param b? number
---@return string hex "RRGGBB"
function InstanceMixin:RGBAToHex(r, g, b)
    r = floor((r or 1) * 255 + 0.5)
    g = floor((g or 1) * 255 + 0.5)
    b = floor((b or 1) * 255 + 0.5)
    return format("%02X%02X%02X", r, g, b)
end

---Wraps text in the accent color.
---@param text string
---@return string
function InstanceMixin:ColorText(text)
    local a = self.theme.accent
    local hex = a and self:RGBAToHex(a[1], a[2], a[3]) or "FFFFFF"
    return "|cFF" .. hex .. text .. "|r"
end

---Applies the themed font to a FontString.
---@param fontString FontString
---@param size? "small"|"normal"|"large"|number
function InstanceMixin:ApplyFont(fontString, size)
    if not fontString or not fontString.SetFontObject then return end

    local theme = self.theme
    local fontSize
    if type(size) == "number" then
        fontSize = size
    elseif size == "small" then
        fontSize = theme.fontSizeSmall or 12
    elseif size == "large" then
        fontSize = theme.fontSizeLarge or 16
    else
        fontSize = theme.fontSizeNormal or 12
    end

    fontString:SetFontObject(getFontObject(resolveFont(theme.fontFace), fontSize, theme.fontOutline or "OUTLINE"))
    fontString:SetShadowOffset(0, 0)
    fontString:SetShadowColor(0, 0, 0, 0)
end

-- Preset / mode engine --

--[[
* Resolves the active mode — preset, class or custom — from the host's persisted store and pushes the result through SetTheme.
* The host wires a `store` accessor and an optional `classColorProvider` at New().
--]]

-- Returns the host's persisted theme store (host DB table), or nil before it exists.
function InstanceMixin:_Store()
    if not self._storeAccessor then return nil end
    return self._storeAccessor()
end

function InstanceMixin:_SelectedPreset(store)
    return (store and store.selectedPreset) or self.defaultPreset
end

-- Resolves one color key for the active mode.
function InstanceMixin:_ResolveColor(key, store, mode)
    if mode == "class" and self._classColorKeys[key] and self.classColorProvider then
        local cc = self.classColorProvider()
        if cc then
            if key == "selectedBg" or key == "accentHover" then
                return { cc[1], cc[2], cc[3], 0.25 }
            end
            return { cc[1], cc[2], cc[3], cc[4] or 1 }
        end
    end

    if mode == "custom" and store and store.customColors and store.customColors[key] then
        return copyColor(store.customColors[key])
    end

    if mode == "preset" then
        local preset = self.presets[self:_SelectedPreset(store)]
        if preset and preset[key] then return copyColor(preset[key]) end
    end

    if mode == "class" then
        local dark = self.presets["Dark"]
        if dark and dark[key] then return copyColor(dark[key]) end
    end

    return copyColor(DEFAULT_THEME[key])
end

---Resolves the active mode from the store and applies it. Notifies subscribers.
---@return KajiGUIInstance self
function InstanceMixin:ApplyTheme()
    local store = self:_Store()
    local mode = (store and store.mode) or "preset"

    local overrides = {}
    for _, key in ipairs(self._colorKeyList) do
        overrides[key] = self:_ResolveColor(key, store, mode)
    end
    for _, key in ipairs(FONT_KEYS) do
        if store and store[key] ~= nil then
            overrides[key] = store[key]
        else
            overrides[key] = DEFAULT_THEME[key]
        end
    end

    return self:SetTheme(overrides)
end

---@return "preset"|"class"|"custom"
function InstanceMixin:GetMode()
    local store = self:_Store()
    return (store and store.mode) or "preset"
end

---@param mode "preset"|"class"|"custom"
---@return KajiGUIInstance self
function InstanceMixin:SetMode(mode)
    if not VALID_MODES[mode] then return self end
    local store = self:_Store()
    if not store then return self end
    store.mode = mode
    return self:ApplyTheme()
end

---Name of the currently selected preset.
---@return string
function InstanceMixin:GetSelectedPreset()
    return self:_SelectedPreset(self:_Store())
end

---@param name string
---@return KajiGUIInstance self
function InstanceMixin:SetPreset(name)
    if not self.presets[name] then return self end
    local store = self:_Store()
    if not store then return self end
    store.selectedPreset = name
    store.mode = "preset"
    return self:ApplyTheme()
end

---Preset color data for a name (the resolved 16-key table).
---@param name string
---@return table?
function InstanceMixin:GetPreset(name)
    return self.presets[name]
end

---Ordered list of preset names.
---@return string[]
function InstanceMixin:GetPresetNames()
    return self.presetNames
end

---Editor metadata for every color key (name/category/supportsClassColor).
---@return table[]
function InstanceMixin:GetColorKeys()
    return self.colorKeys
end

---@param key string
---@param r number
---@param g number
---@param b number
---@param a? number
---@return KajiGUIInstance self
function InstanceMixin:SetCustomColor(key, r, g, b, a)
    local store = self:_Store()
    if not store then return self end
    store.customColors = store.customColors or {}
    store.customColors[key] = { r, g, b, a or 1 }
    if store.mode ~= "custom" then store.mode = "custom" end
    return self:ApplyTheme()
end

---@param key string
---@return number[] rgba
function InstanceMixin:GetCustomColor(key)
    local store = self:_Store()
    if store and store.customColors and store.customColors[key] then
        return copyColor(store.customColors[key])
    end
    return copyColor(DEFAULT_THEME[key])
end

---Copies a preset's colors into the custom slots and switches to custom mode.
---@param name string
---@return KajiGUIInstance self
function InstanceMixin:CopyPresetToCustom(name)
    local preset = self.presets[name]
    if not preset then return self end
    local store = self:_Store()
    if not store then return self end
    store.customColors = store.customColors or {}
    for key, color in pairs(preset) do
        store.customColors[key] = copyColor(color)
    end
    store.mode = "custom"
    return self:ApplyTheme()
end

---Clears all custom colors and re-resolves.
---@return KajiGUIInstance self
function InstanceMixin:ResetCustomColors()
    local store = self:_Store()
    if not store then return self end
    store.customColors = {}
    return self:ApplyTheme()
end

---Writes a single scalar/font theme key to the store and applies it live.
---@param key string
---@param value any
---@return KajiGUIInstance self
function InstanceMixin:SetThemeValue(key, value)
    local store = self:_Store()
    if store then store[key] = value end
    return self:SetTheme({ [key] = value })
end

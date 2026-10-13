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

---@class LibKaji-1.0
local lib = _G.LibStub and _G.LibStub('LibKaji-1.0', true)
if not lib then return end
---@class KajiGUIInstanceMixin
---@field theme KajiTheme
local InstanceMixin = lib.InstanceMixin
local LSM = LibStub("LibSharedMedia-3.0", true)

local type = type
local pairs = pairs
local ipairs = ipairs
local format = string.format
local floor = math.floor
local CreateFont = CreateFont
local CreateFrame = CreateFrame

local FALLBACK_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
-- Class mode fills its non-class keys from this preset; DEFAULT_THEME's colours mirror it for palettes with gaps.
local BASELINE_PRESET = "NUI Neon"
local MEDIA = lib.mediaBase

---Theme table.
---@class KajiTheme
---@field bgDark number[]
---@field bgMedium number[]
---@field bgLight number[]
---@field bgHover number[]
---@field border number[]
---@field widgetBorder number[]
---@field accent number[]
---@field accentHover number[]
---@field accentDim number[]
---@field textPrimary number[]
---@field textSecondary number[]
---@field textMuted number[]
---@field selectedBg number[]
---@field selectedText number[]
---@field error number[]
---@field success number[]
---@field warning number[]
local DEFAULT_THEME = {
    -- Colours mirror BASELINE_PRESET
    -- Backgrounds
    bgDark                  = { 0.016, 0.016, 0.024, 0.9 },
    bgMedium                = { 0.035, 0.035, 0.045, 0.9 },
    bgLight                 = { 0.055, 0.055, 0.07, 0.9 },
    bgHover                 = { 0.16, 0.16, 0.19, 1 },
    -- Border: `border` edges the window chrome, `widgetBorder` the controls inside it
    border                  = { 0.114, 0.114, 0.133, 1 },
    widgetBorder            = { 0.149, 0.149, 0.172, 1 },
    -- Accent
    accent                  = { 0.85, 1, 0.39, 1 },
    accentHover             = { 0.85, 1, 0.39, 0.25 },
    accentDim               = { 0.85, 1, 0.39, 1 },
    -- Text
    textPrimary             = { 1, 1, 1, 1 },
    textSecondary           = { 0.86, 0.86, 0.88, 1 },
    textMuted               = { 0.50, 0.50, 0.54, 1 },
    -- Selection
    selectedBg              = { 0.85, 1, 0.39, 0.15 },
    selectedText            = { 0.85, 1, 0.39, 1 },
    -- Status
    error                   = { 0.90, 0.30, 0.30, 1 },
    success                 = { 0.30, 0.80, 0.40, 1 },
    warning                 = { 0.90, 0.75, 0.30, 1 },
    -- Dimensions
    headerHeight            = 35,
    -- Band under the header, shared by search box, item-list buttons and sub-tabs so they share a baseline
    barHeight               = 37,
    barInset                = 4,
    barControlHeight        = 27,
    footerHeight            = 28,
    sidebarWidth            = 242,
    contentWidth            = 679.1,
    borderSize              = 1,
    -- Spacing
    paddingSmall            = 4,
    paddingMedium           = 8,
    paddingLarge            = 16,
    scrollbarWidth          = 10, -- every window scrollbar: main sidebar, content and item list
    -- Row heights
    rowHeight               = 40,
    rowHeightLast           = 44,
    rowHeightTall           = 80,
    rowHeightSeparator      = 8,
    rowHeightLabelSeparator = 32,
    -- Fonts
    fontFace                = FALLBACK_FONT,
    fontSizeSmall           = 12,
    fontSizeNormal          = 12,
    fontSizeMedium          = 14, -- navigation titles: main sidebar headers, item list sections
    fontSizeLarge           = 16,
    fontOutline             = "OUTLINE",
    fontShadow              = false, ---@type boolean presets and the font editor both flip this
    -- Widget textures (consumers override to match their look)
    checkTexture            = MEDIA .. "ok-iconBlack.tga",
    crossTexture            = MEDIA .. "cross-small.png",
    crossCustomTexture      = MEDIA .. "NorskenCustomCross.png",
    plusTexture             = MEDIA .. "NorskenCustomCrossv3.png",
    stepperTexture          = MEDIA .. "collapse.tga",
    colorSwatchTexture      = MEDIA .. "NUIcolorPickerBG.png",
    resizeHandleTexture     = MEDIA .. "NorskenCustomResizeHandle23px.png",
    -- Drag cursors: an Enum.Cursormode or built-in cursor name, never a path (addon textures draw black)
    dragCursor              = Enum.Cursormode and Enum.Cursormode.GrabbingHandCursor or "UI_MOVE_CURSOR",
    dragCursorHeld          = Enum.Cursormode and Enum.Cursormode.HoldingHandCursor or "UI_MOVE_CURSOR",
    -- Neon turns grain, corner ticks, sheen and highlight off at 0; raise a strength to bring one back.
    -- Tiling grain over sidebars, content area, header and footer
    surfaceTexture          = MEDIA .. "surface.png",
    surfaceAlpha            = 0,
    -- Accent ticks on two corners of every card
    cardCornerLength        = 7,
    cardCornerAlpha         = 0,
    -- Top sheen on header bands, 1px top highlight on cards and tabs
    sheenAlpha              = 0,
    highlightAlpha          = 0,
    -- Soft white 9-slice falloff, tinted per use: black for the window shadow, accent for the toggle glow
    glowTexture             = MEDIA .. "glow.png",
    glowSmallTexture        = MEDIA .. "glow_small.png", -- 8px falloff, for fields, buttons and thumbs
    -- Window drop shadow and the window's accent edge
    shadowSize              = 16, -- = glow.png's slice margin, so the shadow starts right at the window edge
    shadowAlpha             = 0.2,
    windowEdgeAlpha         = 0.35,
    -- Glows on selection and controls
    underlineGlowAlpha      = 0.28, -- the selected tab's glow rising from its underline
    glowControlAlpha        = 0.35, -- on-state toggle and slider fill
    iconGlowAlpha           = 0.6, -- baked icon glows, scaled by the icon's own hover alpha
    selectionGlowAlpha      = 0.22, -- selected row tint, fading out to the right
    barGlowAlpha            = 0.45, -- glow spilling right from the selected row's accent bar
    -- Animation
    animDuration            = 0.18,
}
lib.DEFAULT_THEME = DEFAULT_THEME

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
        border = spec.border or { 0, 0, 0, 1 },
        widgetBorder = spec.widgetBorder or hBG,
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
        dark = { 0.0745, 0.0588, 0.0510, 0.8 },
        light = { 0.1945, 0.1788, 0.1710, 1 },
        accent = { 0.7098, 0.2000, 0.1412 },
    },
    ["Greenwake"] = BuildPreset {
        dark = { 0.031, 0.106, 0.106, 0.8 },
        light = { 0.125, 0.231, 0.216, 1 },
        accent = { 0.933, 0.910, 0.698 },
    },
    ["Timberfall"] = BuildPreset {
        dark = { 0.092, 0.069, 0.018, 0.8 },
        light = { 0.286, 0.220, 0.118, 1 },
        accent = { 0.988, 0.361, 0.008 },
    },
    ["Obsidian"] = BuildPreset {
        dark = { 0.014, 0.047, 0.063, 0.8 },
        light = { 0.114, 0.147, 0.163, 1 },
        accent = { 0.900, 0.467, 0.976 },
        selectedBg = { 0.900, 0.467, 0.976, 0.25 },
    },
    ["Mocha"] = BuildPreset {
        dark = { 0.0588, 0.0559, 0.0294, 0.8 },
        light = { 0.1019, 0.0969, 0.0510, 1 },
        accent = { 0.7451, 0.9412, 0.0000 },
    },
    ["Frost"] = BuildPreset {
        dark = { 0.024, 0.078, 0.106, 0.8 },
        light = { 0.067, 0.129, 0.176, 1 },
        accent = { 0.790, 0.857, 0.872 },
    },
    ["Echo"] = BuildPreset {
        dark = { 0.0666, 0.0000, 0.0000, 0.8 },
        light = { 0.0705, 0.0705, 0.0705, 1 },
        accent = { 0.7803, 0.0000, 0.0000 },
    },
    ["Dark"] = BuildPreset {
        dark = { 0.0235, 0.0235, 0.0235, 0.8 },
        medium = { 0.0431, 0.0431, 0.0431, 0.8 },
        light = { 0.1176, 0.1176, 0.1176, 1 },
        accent = { 0.8980, 0.0627, 0.2235 },
    },
    ["NUI v2"] = BuildPreset {
        dark = { 0.015, 0.047, 0.062, 0.8 },
        light = { 0.113, 0.145, 0.164, 1 },
        accent = { 0, 1, 0.588 },
        selectedBg = { 0.8980, 0.0627, 0.2235, 0.25 },
        bgHover = { 0.219, 0.219, 0.239, 1 },
    },
    ["NUI v3"] = BuildPreset {
        dark = { 0, 0, 0, 0.8 },
        medium = { 0, 0, 0, 0.8 },
        light = { 0.17, 0.17, 0.17, 0.8 },
        accent = { 0.85, 1, 0.39 },
        bgHover = { 0.22, 0.22, 0.24, 1 },
        textPrimary = { 1, 1, 1, 1 },
        textSecondary = { 0.82, 0.82, 0.82, 1 },
        textMuted = { 0.5, 0.5, 0.5, 1 },
        selectedBg = { 0.68, 0.68, 0.68, 0.25 },
    },
    ["NUI Neon"] = BuildPreset {
        dark = { 0.016, 0.016, 0.024, 0.9 },
        medium = { 0.035, 0.035, 0.045, 0.9 },
        light = { 0.055, 0.055, 0.07, 0.9 },
        accent = { 0.85, 1, 0.39 },
        border = { 0.114, 0.114, 0.133, 1 },
        widgetBorder = { 0.149, 0.149, 0.172, 1 },
        bgHover = { 0.16, 0.16, 0.19, 1 },
        textPrimary = { 1, 1, 1, 1 },
        textSecondary = { 0.86, 0.86, 0.88, 1 },
        textMuted = { 0.5, 0.5, 0.54, 1 },
        selectedBg = { 0.85, 1, 0.39, 0.15 },
    },
}
lib.THEME_PRESETS = THEME_PRESETS

-- Ordered preset names for the theme picker.
local THEME_PRESET_NAMES = {
    "Echo", "Warpaint", "Greenwake", "Timberfall", "Obsidian", "Mocha", "Frost", "Dark", "NUI v2", "NUI v3", "NUI Neon",
}
lib.THEME_PRESET_NAMES = THEME_PRESET_NAMES

-- Editor metadata for every color key: display name, group, and whether it follows class color.
local THEME_COLOR_KEYS = {
    { key = "bgDark",        name = "Background Dark",     category = "Backgrounds" },
    { key = "bgMedium",      name = "Background Medium",   category = "Backgrounds" },
    { key = "bgLight",       name = "Background Light",    category = "Backgrounds" },
    { key = "bgHover",       name = "Background Hover",    category = "Backgrounds" },
    { key = "border",        name = "Border",              category = "Borders" },
    { key = "widgetBorder",  name = "Widget Border",       category = "Borders" },
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
local FONT_KEYS = { "fontFace", "fontSizeNormal", "fontSizeSmall", "fontSizeMedium", "fontSizeLarge", "fontOutline", "fontShadow" }

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
    self.theme = {} ---@type KajiTheme
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

---@return KajiTheme
function InstanceMixin:GetTheme()
    return self.theme
end

local WARM_SIZES = { "small", "normal", "medium", "large" }
local WARM_TEXT = "AaBbGgQq0123"
local warmFrame

---@param gui KajiGUIInstanceMixin
local function WarmFonts(gui)
    if not warmFrame then
        warmFrame = CreateFrame("Frame", nil, UIParent)
        warmFrame:SetSize(1, 1)
        warmFrame:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -100, 0)
        warmFrame:SetAlpha(0)
        warmFrame.strings = {}
    end
    for i, size in ipairs(WARM_SIZES) do
        local fs = warmFrame.strings[i]
        if not fs then
            fs = warmFrame:CreateFontString(nil, "OVERLAY")
            fs:SetPoint("TOPLEFT")
            warmFrame.strings[i] = fs
        end
        gui:ApplyFont(fs, size)
        fs:SetText(WARM_TEXT)
    end
end

---@param overrides table
---@return KajiGUIInstance self
function InstanceMixin:SetTheme(overrides)
    if overrides then mergeInto(self.theme, overrides) end
    WarmFonts(self)
    self:_FireThemeChanged()
    return self
end

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

---@param callback fun(theme: KajiTheme)
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
---@param size? "small"|"normal"|"medium"|"large"|number
function InstanceMixin:ApplyFont(fontString, size)
    if not fontString or not fontString.SetFontObject then return end

    fontString:SetFontObject(getFontObject(self:GetThemeFont(size)))
    fontString:SetShadowOffset(0, 0)
    fontString:SetShadowColor(0, 0, 0, 0)
end

---@param size? "small"|"normal"|"medium"|"large"|number
---@return string path, number size, string flags
function InstanceMixin:GetThemeFont(size)
    local theme = self.theme
    local fontSize
    if type(size) == "number" then
        fontSize = size
    elseif size == "small" then
        fontSize = theme.fontSizeSmall or 12
    elseif size == "medium" then
        fontSize = theme.fontSizeMedium or 14
    elseif size == "large" then
        fontSize = theme.fontSizeLarge or 16
    else
        fontSize = theme.fontSizeNormal or 12
    end

    return resolveFont(theme.fontFace), fontSize, theme.fontOutline or "OUTLINE"
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

    -- Class mode takes everything but its class-coloured keys from the baseline preset.
    if mode == "class" then
        local base = self.presets[BASELINE_PRESET]
        if base and base[key] then return copyColor(base[key]) end
    end

    -- Custom palettes saved before this key existed get the hover background they already chose.
    if key == "widgetBorder" then return self:_ResolveColor("bgHover", store, mode) end

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

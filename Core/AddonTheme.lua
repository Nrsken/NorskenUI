-- NorskenUI namespace
local _, NRSKNUI = ...

-- Module with my addon theme settings and helpers

-- Localization Setup
local type = type
local ipairs, pairs = ipairs, pairs
local UnitClass = UnitClass

-- Theme presets
-- All pre-made themes are defined here
local THEME_PRESETS = {
    -- Theme 1: Warpaint (Red, brown, grey/brownish)
    ["Warpaint"] = {
        bgDark        = { 0.0745, 0.0588, 0.0510, 0.6 },
        bgMedium      = { 0.0745, 0.0588, 0.0510, 1 },
        bgLight       = { 0.1945, 0.1788, 0.1710, 1 },
        bgHover       = { 0.22, 0.22, 0.24, 1 },
        border        = { 0, 0, 0, 1 },
        accent        = { 0.7098, 0.2000, 0.1412, 1 },
        accentHover   = { 0.7098, 0.2000, 0.1412, 0.25 },
        accentDim     = { 0.7098, 0.2000, 0.1412, 1 },
        textPrimary   = { 0.95, 0.95, 0.95, 1 },
        textSecondary = { 0.70, 0.70, 0.70, 1 },
        textMuted     = { 0.50, 0.50, 0.50, 1 },
        selectedBg    = { 0.7098, 0.2000, 0.1412, 0.25 },
        selectedText  = { 0.7098, 0.2000, 0.1412, 1 },
        error         = { 0.90, 0.30, 0.30, 1 },
        success       = { 0.30, 0.80, 0.40, 1 },
        warning       = { 0.90, 0.75, 0.30, 1 },
    },

    -- Theme 2: Greenwake (Green, blue, peach)
    ["Greenwake"] = {
        bgDark        = { 0.031, 0.106, 0.106, 0.6 },
        bgMedium      = { 0.031, 0.106, 0.106, 1 },
        bgLight       = { 0.125, 0.231, 0.216, 1 },
        bgHover       = { 0.22, 0.22, 0.24, 1 },
        border        = { 0, 0, 0, 1 },
        accent        = { 0.933, 0.910, 0.698, 1 },
        accentHover   = { 0.933, 0.910, 0.698, 0.25 },
        accentDim     = { 0.933, 0.910, 0.698, 1 },
        textPrimary   = { 0.95, 0.95, 0.95, 1 },
        textSecondary = { 0.70, 0.70, 0.70, 1 },
        textMuted     = { 0.50, 0.50, 0.50, 1 },
        selectedBg    = { 0.933, 0.910, 0.698, 0.25 },
        selectedText  = { 0.933, 0.910, 0.698, 1 },
        error         = { 0.90, 0.30, 0.30, 1 },
        success       = { 0.30, 0.80, 0.40, 1 },
        warning       = { 0.90, 0.75, 0.30, 1 },
    },

    -- Theme 3: Timberfall (Orange, Dark green, light brown/green)
    ["Timberfall"] = {
        bgDark        = { 0.092, 0.069, 0.018, 0.6 },
        bgMedium      = { 0.092, 0.069, 0.018, 1 },
        bgLight       = { 0.286, 0.220, 0.118, 1 },
        bgHover       = { 0.22, 0.22, 0.24, 1 },
        border        = { 0, 0, 0, 1 },
        accent        = { 0.988, 0.361, 0.008, 1 },
        accentHover   = { 0.988, 0.361, 0.008, 0.25 },
        accentDim     = { 0.988, 0.361, 0.008, 1 },
        textPrimary   = { 0.95, 0.95, 0.95, 1 },
        textSecondary = { 0.70, 0.70, 0.70, 1 },
        textMuted     = { 0.50, 0.50, 0.50, 1 },
        selectedBg    = { 0.988, 0.361, 0.008, 0.25 },
        selectedText  = { 0.988, 0.361, 0.008, 1 },
        error         = { 0.90, 0.30, 0.30, 1 },
        success       = { 0.30, 0.80, 0.40, 1 },
        warning       = { 0.90, 0.75, 0.30, 1 },
    },

    -- Theme 4: Obsidian (Purple, obsidian)
    ["Obsidian"] = {
        bgDark        = { 0.014, 0.047, 0.063, 0.6 },
        bgMedium      = { 0.014, 0.047, 0.063, 1 },
        bgLight       = { 0.114, 0.147, 0.163, 1 },
        bgHover       = { 0.22, 0.22, 0.24, 1 },
        border        = { 0, 0, 0, 1 },
        accent        = { 0.900, 0.467, 0.976, 1 },
        accentHover   = { 0.900, 0.467, 0.976, 0.25 },
        accentDim     = { 0.900, 0.467, 0.976, 1 },
        textPrimary   = { 0.95, 0.95, 0.95, 1 },
        textSecondary = { 0.70, 0.70, 0.70, 1 },
        textMuted     = { 0.50, 0.50, 0.50, 1 },
        selectedBg    = { 0.900, 0.467, 0.976, 0.15 },
        selectedText  = { 0.900, 0.467, 0.976, 1 },
        error         = { 0.90, 0.30, 0.30, 1 },
        success       = { 0.30, 0.80, 0.40, 1 },
        warning       = { 0.90, 0.75, 0.30, 1 },
    },

    -- Theme 5: Mocha
    ["Mocha"] = {
        bgDark        = { 0.0588, 0.0559, 0.0294, 0.6 },
        bgMedium      = { 0.0588, 0.0559, 0.0294, 1 },
        bgLight       = { 0.1019, 0.0969, 0.0510, 1 },
        bgHover       = { 0.22, 0.22, 0.24, 1 },
        border        = { 0, 0, 0, 1 },
        accent        = { 0.7451, 0.9412, 0.0000, 1 },
        accentHover   = { 0.7451, 0.9412, 0.0000, 0.25 },
        accentDim     = { 0.7451, 0.9412, 0.0000, 1 },
        textPrimary   = { 0.95, 0.95, 0.95, 1 },
        textSecondary = { 0.70, 0.70, 0.70, 1 },
        textMuted     = { 0.50, 0.50, 0.50, 1 },
        selectedBg    = { 0.7451, 0.9412, 0.0000, 0.25 },
        selectedText  = { 0.7451, 0.9412, 0.0000, 1 },
        error         = { 0.90, 0.30, 0.30, 1 },
        success       = { 0.30, 0.80, 0.40, 1 },
        warning       = { 0.90, 0.75, 0.30, 1 },
    },

    -- Theme 6: Frost (Icy blue)
    ["Frost"] = {
        bgDark        = { 0.024, 0.078, 0.106, 0.6 },
        bgMedium      = { 0.024, 0.078, 0.106, 1 },
        bgLight       = { 0.067, 0.129, 0.176, 1 },
        bgHover       = { 0.22, 0.22, 0.24, 1 },
        border        = { 0, 0, 0, 1 },
        accent        = { 0.790, 0.857, 0.872, 1 },
        accentHover   = { 0.790, 0.857, 0.872, 0.25 },
        accentDim     = { 0.790, 0.857, 0.872, 1 },
        textPrimary   = { 0.95, 0.95, 0.95, 1 },
        textSecondary = { 0.70, 0.70, 0.70, 1 },
        textMuted     = { 0.50, 0.50, 0.50, 1 },
        selectedBg    = { 0.790, 0.857, 0.872, 0.25 },
        selectedText  = { 0.790, 0.857, 0.872, 1 },
        error         = { 0.90, 0.30, 0.30, 1 },
        success       = { 0.30, 0.80, 0.40, 1 },
        warning       = { 0.90, 0.75, 0.30, 1 },
    },

    -- Theme 7: Echo (Red/Pink)
    ["Echo"] = {
        bgDark        = { 0.0666, 0.0000, 0.0000, 0.6 },
        bgMedium      = { 0.0666, 0.0000, 0.0000, 1 },
        bgLight       = { 0.0705, 0.0705, 0.0705, 1 },
        bgHover       = { 0.22, 0.22, 0.24, 1 },
        border        = { 0, 0, 0, 1 },
        accent        = { 0.7803, 0.0000, 0.0000, 1 },
        accentHover   = { 0.7803, 0.0000, 0.0000, 0.25 },
        accentDim     = { 0.7803, 0.0000, 0.0000, 1 },
        textPrimary   = { 0.95, 0.95, 0.95, 1 },
        textSecondary = { 0.70, 0.70, 0.70, 1 },
        textMuted     = { 0.50, 0.50, 0.50, 1 },
        selectedBg    = { 0.7803, 0.0000, 0.0000, 0.25 },
        selectedText  = { 0.7803, 0.0000, 0.0000, 1 },
        error         = { 0.90, 0.30, 0.30, 1 },
        success       = { 0.30, 0.80, 0.40, 1 },
        warning       = { 0.90, 0.75, 0.30, 1 },
    },

    -- Theme 8: Dark
    ["Dark"] = {
        bgDark        = { 0.0235, 0.0235, 0.0235, 0.6 },
        bgMedium      = { 0.0431, 0.0431, 0.0431, 1 },
        bgLight       = { 0.1176, 0.1176, 0.1176, 1 },
        bgHover       = { 0.22, 0.22, 0.24, 1 },
        border        = { 0, 0, 0, 1 },
        accent        = { 0.8980, 0.0627, 0.2235, 1 },
        accentHover   = { 0.8980, 0.0627, 0.2235, 0.25 },
        accentDim     = { 0.8980, 0.0627, 0.2235, 1 },
        textPrimary   = { 0.95, 0.95, 0.95, 1 },
        textSecondary = { 0.70, 0.70, 0.70, 1 },
        textMuted     = { 0.50, 0.50, 0.50, 1 },
        selectedBg    = { 0.8980, 0.0627, 0.2235, 0.25 },
        selectedText  = { 0.8980, 0.0627, 0.2235, 1 },
        error         = { 0.90, 0.30, 0.30, 1 },
        success       = { 0.30, 0.80, 0.40, 1 },
        warning       = { 0.90, 0.75, 0.30, 1 },
    },
}

-- Export theme presets for GUI
NRSKNUI.ThemePresets = THEME_PRESETS

-- Ordered list of theme names for GUI dropdown
NRSKNUI.ThemePresetNames = {
    "Echo",
    "Warpaint",
    "Greenwake",
    "Timberfall",
    "Obsidian",
    "Mocha",
    "Frost",
    "Dark"
}

-- Theme mode options that the user can choose between
-- "preset" = Use a pre-made theme
-- "class"  = Use class color for accent colors
-- "custom" = Use fully custom colors
NRSKNUI.ThemeModeOptions = {
    ["preset"] = "Preset Theme",
    ["class"]  = "Class Color",
    ["custom"] = "Custom",
}

-- Default theme values
-- Used as fallback when no theme is selected or for non-color values
local ThemeDefaults = {
    -- Default to Dark theme colors
    bgDark         = { 0.0235, 0.0235, 0.0235, 0.6 },
    bgMedium       = { 0.0431, 0.0431, 0.0431, 1 },
    bgLight        = { 0.1176, 0.1176, 0.1176, 1 },
    bgHover        = { 0.22, 0.22, 0.24, 1 },
    border         = { 0, 0, 0, 1 },
    accent         = { 0.8980, 0.0627, 0.2235, 1 },
    accentHover    = { 0.8980, 0.0627, 0.2235, 0.25 },
    accentDim      = { 0.8980, 0.0627, 0.2235, 1 },
    textPrimary    = { 0.95, 0.95, 0.95, 1 },
    textSecondary  = { 0.70, 0.70, 0.70, 1 },
    textMuted      = { 0.50, 0.50, 0.50, 1 },
    selectedBg     = { 0.8980, 0.0627, 0.2235, 0.25 },
    selectedText   = { 0.8980, 0.0627, 0.2235, 1 },
    error          = { 0.90, 0.30, 0.30, 1 },
    success        = { 0.30, 0.80, 0.40, 1 },
    warning        = { 0.90, 0.75, 0.30, 1 },

    -- Dimensions
    headerHeight   = 35,
    footerHeight   = 28,
    sidebarWidth   = 162,
    contentWidth   = 562,
    borderSize     = 1,

    -- Spacing
    paddingSmall   = 4,
    paddingMedium  = 8,
    paddingLarge   = 16,
    scrollbarWidth = 16,

    -- Font settings
    fontFace       = "Fonts\\FRIZQT__.TTF",
    fontSizeSmall  = 12,
    fontSizeNormal = 12,
    fontSizeLarge  = 16,
    fontOutline    = "OUTLINE",
    fontShadow     = false,
}

-- Export ThemeDefaults for reference
NRSKNUI.ThemeDefaults = ThemeDefaults

-- Color keys that support class coloring
local ClassColorKeys = {
    "accent",
    "accentHover",
    "accentDim",
    "selectedText",
    "selectedBg",
}

-- Create lookup table for faster checking
local ClassColorKeyLookup = {}
for _, key in ipairs(ClassColorKeys) do
    ClassColorKeyLookup[key] = true
end

-- CopyColor: Create a copy of a color table
local function CopyColor(color)
    if type(color) ~= "table" then return { 1, 1, 1, 1 } end
    return { color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1 }
end

-- GetPlayerClassColor: Get the player's class color
local function GetPlayerClassColor()
    local _, class = UnitClass("player")
    if class and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return { c.r, c.g, c.b, 1 }
    end
    return { 1, 1, 1, 1 } -- Fallback to white
end

-- GetThemeDB: Get the theme database
local function GetThemeDB()
    return NRSKNUI.db and NRSKNUI.db.global and NRSKNUI.db.global.Theme
end

-- GetThemeMode: Get current theme mode (preset, class, or custom)
local function GetThemeMode()
    local db = GetThemeDB()
    return (db and db.mode) or "preset"
end

-- GetSelectedPreset: Get the name of the selected preset theme
local function GetSelectedPreset()
    local db = GetThemeDB()
    return (db and db.selectedPreset) or "Echo"
end

-- GetThemeValue: Get theme value from db or default (for non-color values)
local function GetThemeValue(key)
    local db = GetThemeDB()
    if db and db[key] ~= nil then
        return db[key]
    end
    return ThemeDefaults[key]
end

-- GetThemeColor: Get theme color based on current mode
local function GetThemeColor(key)
    local db = GetThemeDB()
    local mode = GetThemeMode()

    -- Check if this key supports class color and we're in class mode
    if mode == "class" and ClassColorKeyLookup[key] then
        local classColor = GetPlayerClassColor()
        -- Special handling for selectedBg: always use alpha 0.25
        if key == "selectedBg" then
            return { classColor[1], classColor[2], classColor[3], 0.25 }
        end
        -- Special handling for accentHover: always use alpha 0.25
        if key == "accentHover" then
            return { classColor[1], classColor[2], classColor[3], 0.25 }
        end
        return classColor
    end

    -- Custom mode: use saved custom colors
    if mode == "custom" and db and db.customColors and db.customColors[key] then
        return CopyColor(db.customColors[key])
    end

    -- Preset mode: use the selected preset theme
    if mode == "preset" then
        local presetName = GetSelectedPreset()
        local preset = THEME_PRESETS[presetName]
        if preset and preset[key] then
            return CopyColor(preset[key])
        end
    end

    -- Class mode: use Dark preset for non-accent colors (backgrounds, text, etc.)
    if mode == "class" then
        local darkPreset = THEME_PRESETS["Dark"]
        if darkPreset and darkPreset[key] then
            return CopyColor(darkPreset[key])
        end
    end

    -- Fallback to defaults
    return CopyColor(ThemeDefaults[key])
end

-- Live theme table
-- This table holds the currently active theme values
NRSKNUI.Theme = {
    -- Colors (will be populated by RefreshTheme)
    bgDark         = CopyColor(ThemeDefaults.bgDark),
    bgMedium       = CopyColor(ThemeDefaults.bgMedium),
    bgLight        = CopyColor(ThemeDefaults.bgLight),
    bgHover        = CopyColor(ThemeDefaults.bgHover),

    border         = CopyColor(ThemeDefaults.border),

    accent         = CopyColor(ThemeDefaults.accent),
    accentHover    = CopyColor(ThemeDefaults.accentHover),
    accentDim      = CopyColor(ThemeDefaults.accentDim),

    textPrimary    = CopyColor(ThemeDefaults.textPrimary),
    textSecondary  = CopyColor(ThemeDefaults.textSecondary),
    textMuted      = CopyColor(ThemeDefaults.textMuted),

    selectedBg     = CopyColor(ThemeDefaults.selectedBg),
    selectedText   = CopyColor(ThemeDefaults.selectedText),

    error          = CopyColor(ThemeDefaults.error),
    success        = CopyColor(ThemeDefaults.success),
    warning        = CopyColor(ThemeDefaults.warning),

    -- Dimensions
    headerHeight   = ThemeDefaults.headerHeight,
    footerHeight   = ThemeDefaults.footerHeight,
    sidebarWidth   = ThemeDefaults.sidebarWidth,
    contentWidth   = ThemeDefaults.contentWidth,
    borderSize     = ThemeDefaults.borderSize,

    -- Spacing
    paddingSmall   = ThemeDefaults.paddingSmall,
    paddingMedium  = ThemeDefaults.paddingMedium,
    paddingLarge   = ThemeDefaults.paddingLarge,
    scrollbarWidth = ThemeDefaults.scrollbarWidth,

    -- Font settings
    fontFace       = ThemeDefaults.fontFace,
    fontSizeNormal = ThemeDefaults.fontSizeNormal,
    fontSizeSmall  = ThemeDefaults.fontSizeSmall,
    fontSizeLarge  = ThemeDefaults.fontSizeLarge,
    fontOutline    = ThemeDefaults.fontOutline,
    fontShadow     = ThemeDefaults.fontShadow,
}

-- Theme color keys, for iteration in settings UI
NRSKNUI.ThemeColorKeys = {
    -- Backgrounds
    { key = "bgDark",        name = "Background Dark",     category = "Backgrounds" },
    { key = "bgMedium",      name = "Background Medium",   category = "Backgrounds" },
    { key = "bgLight",       name = "Background Light",    category = "Backgrounds" },
    { key = "bgHover",       name = "Background Hover",    category = "Backgrounds" },
    -- Borders
    { key = "border",        name = "Border",              category = "Borders" },
    -- Accent Colors
    { key = "accent",        name = "Accent",              category = "Accent Colors",    supportsClassColor = true },
    { key = "accentHover",   name = "Accent Hover",        category = "Accent Colors",    supportsClassColor = true },
    { key = "accentDim",     name = "Accent Dim",          category = "Accent Colors",    supportsClassColor = true },
    -- Text Colors
    { key = "textPrimary",   name = "Text Primary",        category = "Text Colors" },
    { key = "textSecondary", name = "Text Secondary",      category = "Text Colors" },
    { key = "textMuted",     name = "Text Muted",          category = "Text Colors" },
    { key = "selectedText",  name = "Selected Text",       category = "Text Colors",      supportsClassColor = true },
    -- Selection Colors
    { key = "selectedBg",    name = "Selected Background", category = "Selection Colors", supportsClassColor = true },
    -- Status Colors
    { key = "error",         name = "Error",               category = "Status Colors" },
    { key = "success",       name = "Success",             category = "Status Colors" },
    { key = "warning",       name = "Warning",             category = "Status Colors" },
}

-- RefreshTheme: Update theme values from SavedVariables
function NRSKNUI:RefreshTheme()
    local Theme          = self.Theme

    -- Update all color values
    Theme.bgDark         = GetThemeColor("bgDark")
    Theme.bgMedium       = GetThemeColor("bgMedium")
    Theme.bgLight        = GetThemeColor("bgLight")
    Theme.bgHover        = GetThemeColor("bgHover")

    Theme.border         = GetThemeColor("border")

    Theme.accent         = GetThemeColor("accent")
    Theme.accentHover    = GetThemeColor("accentHover")
    Theme.accentDim      = GetThemeColor("accentDim")

    Theme.textPrimary    = GetThemeColor("textPrimary")
    Theme.textSecondary  = GetThemeColor("textSecondary")
    Theme.textMuted      = GetThemeColor("textMuted")

    Theme.selectedBg     = GetThemeColor("selectedBg")
    Theme.selectedText   = GetThemeColor("selectedText")

    Theme.error          = GetThemeColor("error")
    Theme.success        = GetThemeColor("success")
    Theme.warning        = GetThemeColor("warning")

    -- Update font settings from db
    Theme.fontFace       = GetThemeValue("fontFace")
    Theme.fontSizeNormal = GetThemeValue("fontSizeNormal")
    Theme.fontSizeSmall  = GetThemeValue("fontSizeSmall")
    Theme.fontSizeLarge  = GetThemeValue("fontSizeLarge")
    Theme.fontOutline    = GetThemeValue("fontOutline")
    Theme.fontShadow     = GetThemeValue("fontShadow")

    -- Refresh the GUI if it's open
    if self.GUIFrame and self.GUIFrame.mainFrame and self.GUIFrame.mainFrame:IsShown() then
        self.GUIFrame:ApplyThemeColors()
    end

    -- Notify modules that use theme colors to update
    self:NotifyThemeChange()
end

-- NotifyThemeChange: Update all modules that use theme-based colors
function NRSKNUI:NotifyThemeChange()
    if not self.db or not self.db.profile then return end

    -- Update CursorCircle if it uses theme color mode
    local CC = self.CursorCircle
    if CC and CC.ApplyColor then
        local settings = self.db.profile.Miscellaneous and self.db.profile.Miscellaneous.CursorCircle
        if settings then
            -- Update main circle color
            if settings.ColorMode == "theme" then
                CC:ApplyColor()
            end
            -- Also update GCD ring if it uses theme color
            if settings.GCD and settings.GCD.RingColorMode == "theme" then
                if CC.frame and CC.frame.gcdCooldown and CC.GetGCDRingColor then
                    local r, g, b, a = CC:GetGCDRingColor()
                    if CC.frame.gcdCooldown.SetSwipeColor then
                        CC.frame.gcdCooldown:SetSwipeColor(r, g, b, a)
                    end
                end
            end
        end
    end

    -- Update Chat tab colors if it uses theme color mode
    if self.Addon then
        local CHAT = self.Addon:GetModule("Chat", true)
        if CHAT and CHAT.UpdateTabColors then
            local settings = self.db.profile.Skinning and self.db.profile.Skinning.Chat
            if settings and settings.TabColors and settings.TabColors.InactiveColorMode == "theme" then
                CHAT:UpdateTabColors()
            end
        end
    end

    -- Update CombatCross if it uses theme color mode
    if self.db.profile.CombatCross then
        local settings = self.db.profile.CombatCross
        if settings.ColorMode == "theme" and self.RefreshCombatCrossSettings then
            self:RefreshCombatCrossSettings()
        end
    end

    -- Update EditMode overlays if active
    if self.EditMode and self.EditMode:IsActive() then
        self.EditMode:RefreshOverlays()
    end
end

-- SetThemeMode: Change the theme mode (preset, class, custom)
function NRSKNUI:SetThemeMode(mode)
    if not self.db or not self.db.global then return end
    if not self.ThemeModeOptions[mode] then return end

    self.db.global.Theme = self.db.global.Theme or {}
    self.db.global.Theme.mode = mode

    self:RefreshTheme()
end

-- GetThemeMode: Get the current theme mode
function NRSKNUI:GetThemeMode()
    return GetThemeMode()
end

-- SetThemePreset: Change the selected preset theme
function NRSKNUI:SetThemePreset(presetName)
    if not self.db or not self.db.global then return end
    if not THEME_PRESETS[presetName] then return end

    self.db.global.Theme = self.db.global.Theme or {}
    self.db.global.Theme.selectedPreset = presetName

    -- Also set mode to preset if not already
    self.db.global.Theme.mode = "preset"

    self:RefreshTheme()
end

-- GetThemePreset: Get the current preset name
function NRSKNUI:GetThemePreset()
    return GetSelectedPreset()
end

-- SetCustomColor: Set a custom color (used in custom mode)
function NRSKNUI:SetCustomColor(key, r, g, b, a)
    if not self.db or not self.db.global then return end

    self.db.global.Theme = self.db.global.Theme or {}
    self.db.global.Theme.customColors = self.db.global.Theme.customColors or {}
    self.db.global.Theme.customColors[key] = { r, g, b, a or 1 }

    -- If not in custom mode, switch to it
    if self.db.global.Theme.mode ~= "custom" then
        self.db.global.Theme.mode = "custom"
    end

    self:RefreshTheme()
end

-- GetCustomColor: Get a custom color value
function NRSKNUI:GetCustomColor(key)
    local db = GetThemeDB()
    if db and db.customColors and db.customColors[key] then
        return CopyColor(db.customColors[key])
    end
    -- Return default if no custom color set
    return CopyColor(ThemeDefaults[key])
end

-- ResetTheme: Reset all theme values to defaults
function NRSKNUI:ResetTheme()
    if not self.db or not self.db.global then return end

    -- Reset theme settings
    self.db.global.Theme = {
        mode = "preset",
        selectedPreset = "Echo",
        customColors = {},
    }

    -- Apply the reset
    self:RefreshTheme()
end

-- ResetCustomColors: Reset only custom colors (keep mode and preset)
function NRSKNUI:ResetCustomColors()
    if not self.db or not self.db.global then return end

    self.db.global.Theme = self.db.global.Theme or {}
    self.db.global.Theme.customColors = {}

    self:RefreshTheme()
end

-- CopyPresetToCustom: Copy a preset's colors to custom colors for editing
function NRSKNUI:CopyPresetToCustom(presetName)
    if not self.db or not self.db.global then return end
    if not THEME_PRESETS[presetName] then return end

    self.db.global.Theme = self.db.global.Theme or {}
    self.db.global.Theme.customColors = self.db.global.Theme.customColors or {}

    -- Copy all colors from the preset
    local preset = THEME_PRESETS[presetName]
    for key, color in pairs(preset) do
        self.db.global.Theme.customColors[key] = CopyColor(color)
    end

    -- Switch to custom mode
    self.db.global.Theme.mode = "custom"

    self:RefreshTheme()
end

-- Font helpers
-- SetThemeValue: Set a single theme value
function NRSKNUI:SetThemeValue(key, value)
    if not self.db or not self.db.global then return end

    self.db.global.Theme = self.db.global.Theme or {}
    self.db.global.Theme[key] = value

    -- Update live Theme table
    self.Theme[key] = value

    -- Refresh GUI appearance if open
    if self.GUIFrame and self.GUIFrame.mainFrame and self.GUIFrame.mainFrame:IsShown() then
        self.GUIFrame:ApplyThemeColors()
    end
end

-- ApplyThemeFont: Apply theme font to a font string
function NRSKNUI:ApplyThemeFont(fontString, size)
    if not fontString or not fontString.SetFont then return end

    local Theme = self.Theme
    local fontSize

    -- Determine font size
    if type(size) == "number" then
        fontSize = size
    elseif size == "small" then
        fontSize = Theme.fontSizeSmall or 10
    elseif size == "large" then
        fontSize = Theme.fontSizeLarge or 14
    else
        fontSize = Theme.fontSizeNormal or 12
    end

    -- Get font face and outline
    local fontFace = Theme.fontFace or "Fonts\\FRIZQT__.TTF"
    local fontOutline = Theme.fontOutline or "OUTLINE"

    -- Handle "NONE" outline option
    if fontOutline == "NONE" then
        fontOutline = ""
    end

    -- Apply font settings
    fontString:SetFont(fontFace, fontSize, fontOutline)

    -- Apply shadow (disabled by default - alpha 0)
    if Theme.fontShadow then
        fontString:SetShadowOffset(1, -1)
        fontString:SetShadowColor(0, 0, 0, 0.8)
    else
        fontString:SetShadowOffset(0, 0)
        fontString:SetShadowColor(0, 0, 0, 0)
    end
end

-- GetAccentColor: Get accent color based on a color mode setting
function NRSKNUI:GetAccentColor(mode, customColor)
    if mode == "class" then
        local _, class = UnitClass("player")
        if class and RAID_CLASS_COLORS[class] then
            local c = RAID_CLASS_COLORS[class]
            return c.r, c.g, c.b, 1
        end
    elseif mode == "custom" and customColor then
        return customColor[1] or 1, customColor[2] or 1, customColor[3] or 1, customColor[4] or 1
    end

    -- Default to theme accent
    local accent = self.Theme.accent
    return accent[1], accent[2], accent[3], accent[4]
end

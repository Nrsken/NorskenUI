---@class NRSKNUI
local NRSKNUI = select(2, ...)

local pairs = pairs
local type = type
local pcall = pcall
local next = next
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local PlaySoundFile = PlaySoundFile

local GetFileID = C_UIFileAsset and C_UIFileAsset.GetFileID
local IsKnownFile = C_UIFileAsset and C_UIFileAsset.IsKnownFile

local LSM = NRSKNUI.Libs.LSM

-- Locale masks: LSM rejects font registrations on koKR/zhCN/zhTW/ruRU clients unless the
-- mask includes their locale bit and Fetch then falls back to the locale default game font.
local westAndRU = LSM.LOCALE_BIT_western + LSM.LOCALE_BIT_ruRU

-- STANDARD_TEXT_FONT is locale-correct (ARKai_T on zhCN, 2002 on koKR, etc) a hardcoded
-- FRIZQT__ fallback renders CJK text as boxes on those clients.
local FALLBACK_FONT = STANDARD_TEXT_FONT or (GameFontNormal and GameFontNormal:GetFont()) or 'Fonts\\FRIZQT__.TTF'
local FALLBACK_SIZE = 12
local DEFAULT_FONT_NAME = 'Expressway'

NRSKNUI.Media = {
    Fonts = {},
    Statusbars = {},
    Sounds = {},
    Solid = [[Interface\Buttons\WHITE8X8]],
    FallbackFont = FALLBACK_FONT,
    FallbackSize = FALLBACK_SIZE,
    DefaultFont = DEFAULT_FONT_NAME,
}

local mediaKeys = {
    font = 'Fonts',
    statusbar = 'Statusbars',
    sound = 'Sounds',
}

local mediaPaths = {
    font = [[Interface\AddOns\NorskenUI\Media\Fonts\]],
    statusbar = [[Interface\AddOns\NorskenUI\Media\Statusbars\]],
    sound = [[Interface\AddOns\NorskenUI\Media\Sounds\]],
}

---@param MediaType string
---@param FileName string
---@param DisplayName string | boolean
---@param LocaleMask number?
local function RegisterLSMMedia(MediaType, FileName, DisplayName, LocaleMask)
    local mediaPathForType = mediaPaths[MediaType]

    if mediaPathForType then
        -- Strip file type, for example: Expressway.TTF -> Expressway
        local cleanFileName = FileName:gsub('%.%w-$', '')
        -- Get the full media path
        local fullFilePath = mediaPathForType .. FileName

        -- Insert into NRSKNUI.Media, can be use like this later: NRSKNUI.Media.Fonts.Expressway, this returns the full media path.
        local pathKey = mediaKeys[MediaType]
        if pathKey then
            NRSKNUI.Media[pathKey][cleanFileName] = fullFilePath
        end

        -- If DisplayName is true, then use key as displayname, else use specified displayname.
        local nameKey = (DisplayName == true and cleanFileName) or DisplayName
        LSM:Register(MediaType, nameKey, fullFilePath, LocaleMask)
    end
end

-- Font reg
RegisterLSMMedia('font', 'Expressway.TTF', true, westAndRU)
RegisterLSMMedia('font', 'Quazii.TTF', true, westAndRU)

-- Statusbar reg
RegisterLSMMedia('statusbar', 'NorskenUI.blp', true)

-- Sound reg
RegisterLSMMedia('sound', 'Whisper.ogg', '|cffe51039NorskenWhisper|r')

---@param font string? LSM name or literal path
---@return string path
local function ResolveFontPath(font)
    if font and font ~= '' then
        if LSM:IsValid('font', font) then
            local path = LSM:Fetch('font', font, true) -- noDefault: nil when unregistered
            if path and (not IsKnownFile or IsKnownFile(path)) then
                return path
            end
        elseif IsKnownFile and IsKnownFile(font) then
            return font -- already a real file path
        end
    end
    return FALLBACK_FONT
end

---@param font string? LSM name or literal path
---@return string path
function NRSKNUI:ResolveFontPath(font)
    return ResolveFontPath(font)
end

-- Applies late loading LSM fonts.
local lastResolvedPath
local function ReapplyIfFontChanged()
    if not lastResolvedPath then return end
    local db = NRSKNUI.db
    local profileFont = db and db.profile.globalMedia.profileFont
    if not profileFont then return end

    local path = ResolveFontPath(profileFont.FontFace)
    if path == lastResolvedPath then return end
    lastResolvedPath = path

    NRSKNUI:DeferUntilUnrestricted(0, function()
        NRSKNUI:ApplyBlizzardFonts()
        NRSKNUI:RefreshFontStyles()
    end)
end

-- Font preloader using new C_UIFileAsset API
do
    -- Hidden frame that we yeet outside the screen, we will add fontstrings to this later.
    local preloadFrame = CreateFrame('Frame')
    preloadFrame:SetPoint('TOP', UIParent, 'BOTTOM', 0, -99999)
    preloadFrame:SetSize(200, 200)

    local preloadedFonts = {}

    local function PreloadFontAndCache(Path)
        local fileID = GetFileID(Path)
        if not fileID or preloadedFonts[fileID] then return end
        preloadedFonts[fileID] = true

        local preloadText = preloadFrame:CreateFontString()
        preloadText:SetAllPoints()
        if pcall(preloadText.SetFont, preloadText, Path, 14) then
            pcall(preloadText.SetText, preloadText, 'fontCache')
        end
    end

    -- Run a full inital preload of all the fonts.
    local fonts = LSM:HashTable('font')
    for _, Path in next, fonts do
        PreloadFontAndCache(Path)
    end

    -- Preload fonts that other addons add, and re-apply if the registration just made
    -- the configured font resolvable.
    hooksecurefunc(LSM, 'Register', function(_, Type, _, Path)
        if not Type or type(Type) ~= 'string' then return end

        if Type == 'font' and Path then
            PreloadFontAndCache(Path)
            ReapplyIfFontChanged()
        end
    end)
end

do
    local loginFrame = CreateFrame('Frame')
    loginFrame:RegisterEvent('PLAYER_LOGIN')
    loginFrame:SetScript('OnEvent', function(self)
        self:UnregisterAllEvents()
        NRSKNUI:ValidateProfileFonts()

        -- Seed the late-registration baseline with the now-validated configured face.
        local db = NRSKNUI.db
        local profileFont = db and db.profile.globalMedia.profileFont
        if profileFont then
            lastResolvedPath = ResolveFontPath(profileFont.FontFace)
        end
    end)
end

local function IsFontKey(key)
    if type(key) ~= 'string' then return false end
    return key == 'Font' or key:lower():match('fontface$') ~= nil
end

local function ValidateFontsRecursive(tbl, defaults)
    if type(tbl) ~= 'table' then return end

    for key, value in pairs(tbl) do
        if IsFontKey(key) and type(value) == 'string' then
            if not LSM:IsValid('font', value) then
                local defaultVal = defaults and defaults[key] or DEFAULT_FONT_NAME
                if not LSM:IsValid('font', defaultVal) then
                    defaultVal = DEFAULT_FONT_NAME
                end
                tbl[key] = defaultVal
            end
        elseif type(value) == 'table' then
            local subDefaults = defaults and defaults[key]
            ValidateFontsRecursive(value, subDefaults)
        end
    end
end

---Walk the active profile and swap any font key whose value is no longer a registered
---LSM font for the matching default (or the addon default), so a removed font can't leave a broken face behind.
function NRSKNUI:ValidateProfileFonts()
    if not self.db or not self.db.profile then return end
    local defaults = self.db.defaults and self.db.defaults.profile
    ValidateFontsRecursive(self.db.profile, defaults)
end

---@param mediaType string
---@param name string
---@param fallback string
---@return string
function NRSKNUI:GetMediaPath(mediaType, name, fallback)
    if name then
        local path = LSM:Fetch(mediaType, name)
        if path and IsKnownFile(path) then return path end
    end
    return fallback
end

---@param fontName string
---@return string
function NRSKNUI:GetFontPath(fontName)
    return self:GetMediaPath('font', fontName, FALLBACK_FONT)
end

---@param barName string
---@return string
function NRSKNUI:GetStatusbarPath(barName)
    return self:GetMediaPath('statusbar', barName, 'Interface\\TargetingFrame\\UI-StatusBar')
end

---@param path string|number
---@return boolean
function NRSKNUI:IsSoundValid(path)
    if not path or path == '' or path == 'None' then return false end
    return IsKnownFile(path)
end

---@param path string|number
---@param channel string?
function NRSKNUI:PlaySound(path, channel)
    if not self:IsSoundValid(path) then return end
    PlaySoundFile(path, channel or 'Master')
end

---@param outline string?
---@return string
function NRSKNUI:GetFontOutline(outline)
    if not outline or outline == 'NONE' or outline == 'SOFTOUTLINE' or outline == '' then return '' end
    return outline
end

---@param moduleDB table?
---@return string
function NRSKNUI:GetEffectiveFont(moduleDB)
    local global = self.db and self.db.profile and self.db.profile.globalMedia
    if global and global.Enabled and global.profileFont.Enabled then
        if moduleDB and moduleDB.UseGlobalFont == false then
            return moduleDB.FontFace or moduleDB.Font or moduleDB.fontFace or DEFAULT_FONT_NAME
        end
        return global.profileFont.FontFace or DEFAULT_FONT_NAME
    end
    return moduleDB and (moduleDB.FontFace or moduleDB.Font or moduleDB.fontFace) or DEFAULT_FONT_NAME
end

---@param moduleDB table?
---@param override string? -- per-element texture name; used only when the global bar is not in effect
---@return string
function NRSKNUI:GetEffectiveStatusBar(moduleDB, override)
    local global = self.db and self.db.profile and self.db.profile.globalMedia
    if global and global.Enabled and global.profileBar.Enabled then
        if moduleDB and moduleDB.UseGlobalBar == false then
            return override or moduleDB.StatusBarTexture or moduleDB.statusBar or 'NorskenUI'
        end
        return global.profileBar.statusBar or 'NorskenUI'
    end
    return override or (moduleDB and (moduleDB.StatusBarTexture or moduleDB.statusBar)) or 'NorskenUI'
end

---@param moduleDB table?
---@param override string? -- per-element texture name; falls back to the module texture when nil
---@return string path resolved statusbar texture path
function NRSKNUI:GetBarTexture(moduleDB, override)
    return self:GetStatusbarPath(self:GetEffectiveStatusBar(moduleDB, override))
end

---Resolve the effective font for a module (global-aware) straight to a usable font path.
---@param moduleDB table?
---@return string path resolved font file path
function NRSKNUI:GetFontName(moduleDB)
    return self:GetFontPath(self:GetEffectiveFont(moduleDB))
end

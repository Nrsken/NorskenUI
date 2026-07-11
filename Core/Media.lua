---@class NRSKNUI
local NRSKNUI = select(2, ...)

local pairs, type = pairs, type
local pcall = pcall
local next = next
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local PlaySoundFile = PlaySoundFile

local C_UIFileAsset = C_UIFileAsset
local IsKnownFile = C_UIFileAsset and C_UIFileAsset.IsKnownFile
local GetFileID = C_UIFileAsset and C_UIFileAsset.GetFileID

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

    -- Preload fonts that other addons add.
    hooksecurefunc(LSM, 'Register', function(_, Type, _, Path)
        if not Type or type(Type) ~= 'string' then return end

        if Type == 'font' and Path then
            PreloadFontAndCache(Path)
        end
    end)
end

do
    local loginFrame = CreateFrame('Frame')
    loginFrame:RegisterEvent('PLAYER_LOGIN')
    loginFrame:SetScript('OnEvent', function(self)
        self:UnregisterAllEvents()
        NRSKNUI:ValidateProfileFonts()
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

---@param fontString FontString
---@param fontName string
---@param fontSize number
---@param fontOutline string
---@return boolean
function NRSKNUI:ApplyFont(fontString, fontName, fontSize, fontOutline)
    if not fontString then return false end

    local fontPath = self:GetFontPath(fontName)
    local size = (fontSize and fontSize > 0) and fontSize or FALLBACK_SIZE
    local outline = self:GetFontOutline(fontOutline)

    local result = fontString:SetFont(fontPath, size, outline)
    if result then return true end

    return fontString:SetFont(FALLBACK_FONT, size, outline) or false
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
---@return string
function NRSKNUI:GetEffectiveStatusBar(moduleDB)
    local global = self.db and self.db.profile and self.db.profile.globalMedia
    if global and global.Enabled and global.profileBar.Enabled then
        if moduleDB and moduleDB.UseGlobalBar == false then
            return moduleDB.StatusBarTexture or moduleDB.statusBar or 'NorskenUI'
        end
        return global.profileBar.statusBar or 'NorskenUI'
    end
    return moduleDB and (moduleDB.StatusBarTexture or moduleDB.statusBar) or 'NorskenUI'
end

function NRSKNUI:GetBarTexture(moduleDB)
    return self:GetStatusbarPath(self:GetEffectiveStatusBar(moduleDB))
end

function NRSKNUI:GetFontName(moduleDB)
    return self:GetFontPath(self:GetEffectiveFont(moduleDB))
end

---@param parent Frame
---@param layer DrawLayer?
---@return FontString
function NRSKNUI:CreateText(parent, layer)
    local fs = parent:CreateFontString(nil, layer or 'OVERLAY')
    fs:SetFont(FALLBACK_FONT, FALLBACK_SIZE, '')
    return fs
end

---@param fontString FontString
---@param fontName string
---@param fontSize number
---@param fontOutline string
---@param shadowSettings table?
---@return boolean
function NRSKNUI:SetTextFont(fontString, fontName, fontSize, fontOutline, shadowSettings)
    if not fontString then return false end

    fontName = fontName or DEFAULT_FONT_NAME
    fontSize = (fontSize and fontSize > 0) and fontSize or FALLBACK_SIZE
    fontOutline = fontOutline or 'OUTLINE'
    shadowSettings = shadowSettings or {}

    local fontPath = self:GetFontPath(fontName)
    local outline = self:GetFontOutline(fontOutline)

    local success = fontString:SetFont(fontPath, fontSize, outline) or false
    if not success then
        success = fontString:SetFont(FALLBACK_FONT, fontSize, outline) or false
        fontPath = FALLBACK_FONT
    end

    if not success then
        return false
    end

    if fontOutline == 'SOFTOUTLINE' then
        fontString:SetShadowOffset(0, 0)
        fontString:SetShadowColor(0, 0, 0, 0)
        if not fontString.softOutline then
            fontString.softOutline = self:CreateSoftOutline(fontString, {
                fontPath = fontPath,
                fontSize = fontSize,
            })
        else
            fontString.softOutline:SetFont(fontPath, fontSize)
        end
        fontString.softOutline:SetShown(true)
    else
        if fontString.softOutline then
            fontString.softOutline:SetShown(false)
        end
        if shadowSettings.Enabled then
            local c = shadowSettings.Color or { 0, 0, 0, 1 }
            fontString:SetShadowColor(c[1], c[2], c[3], c[4] or 0.9)
            fontString:SetShadowOffset(shadowSettings.OffsetX or 1, shadowSettings.OffsetY or -1)
        end
    end

    return true
end

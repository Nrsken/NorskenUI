---@class NRSKNUI
local NRSKNUI = select(2, ...)
local LSM = NRSKNUI.Libs.LSM

local type = type
local pcall = pcall
local next = next
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local PlaySoundFile = PlaySoundFile

local GetFileID = C_UIFileAsset and C_UIFileAsset.GetFileID
local IsKnownFile = C_UIFileAsset and C_UIFileAsset.IsKnownFile

-- Locale masks: LSM rejects font registrations on koKR/zhCN/zhTW/ruRU clients unless the mask includes their locale bit and Fetch then falls back to the locale default game font.
local westAndRU = LSM.LOCALE_BIT_western + LSM.LOCALE_BIT_ruRU
-- STANDARD_TEXT_FONT is locale-correct (ARKai_T on zhCN, 2002 on koKR, etc) a hardcoded FRIZQT__ fallback renders CJK text as boxes on those clients.
local FALLBACK_FONT = STANDARD_TEXT_FONT or (GameFontNormal and GameFontNormal:GetFont()) or 'Fonts\\FRIZQT__.TTF'
local FALLBACK_SIZE = 12
local DEFAULT_FONT_NAME = 'Expressway'
local fallbackPaths = {
    font = FALLBACK_FONT,
    statusbar = [[Interface\TargetingFrame\UI-StatusBar]],
}

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
RegisterLSMMedia('statusbar', 'Stripes.blp', true)      -- WA Assets: https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/Media/Textures/Statusbar_Stripes.blp
RegisterLSMMedia('statusbar', 'StripesThin.blp', true)  -- WA Assets: https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/Media/Textures/Statusbar_Stripes_Thin.blp
RegisterLSMMedia('statusbar', 'StripesThick.blp', true) -- WA Assets: https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/Media/Textures/Statusbar_Stripes_Thick.blp

-- Sound reg
RegisterLSMMedia('sound', 'Whisper.ogg', '|cffe51039NorskenWhisper|r')


-- Font preloader using new C_UIFileAsset API --

do
    -- Applies late loading LSM fonts.
    local lastResolvedPath
    local function ReapplyIfFontChanged()
        if not lastResolvedPath then return end
        local profileFont = NRSKNUI.db and NRSKNUI.db.profile.globalMedia.profileFont
        if not profileFont then return end

        local path = NRSKNUI:ResolveMediaPath('font', profileFont.FontFace)
        if path == lastResolvedPath then return end
        lastResolvedPath = path

        NRSKNUI:DeferUntilUnrestricted(0, function()
            NRSKNUI:ApplyBlizzardFonts()
            NRSKNUI:RefreshFontStyles()
        end)
    end

    -- Hidden frame that we yeet outside the screen, we will add fontstrings to this later.
    local preloadFrame = CreateFrame('Frame')
    preloadFrame:SetPoint('TOP', UIParent, 'BOTTOM', 0, -99999)
    preloadFrame:SetSize(200, 200)

    -- Preload fonts and cache them to avoid reloading the same font multiple times.
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

    -- Preload fonts that other addons add and re-apply if the registration just made the configured font resolvable.
    hooksecurefunc(LSM, 'Register', function(_, Type, _, Path)
        if not Type or type(Type) ~= 'string' then return end

        if Type == 'font' and Path then
            PreloadFontAndCache(Path)
            ReapplyIfFontChanged()
        end
    end)
end

-- Media Utilities --

---Resolve an LSM media name (or literal file path) to a usable file path.
---@param mediaType string 'font' | 'statusbar' | 'sound'
---@param name string|number|nil LSM name, literal path, or fileID
---@return string|number|nil path per-type fallback when unresolved (nil for sounds)
function NRSKNUI:ResolveMediaPath(mediaType, name)
    if name and name ~= '' then
        if LSM:IsValid(mediaType, name) then
            local path = LSM:Fetch(mediaType, name, true) -- noDefault: nil when unregistered
            if path and (not IsKnownFile or IsKnownFile(path)) then
                return path
            end
        elseif IsKnownFile and IsKnownFile(name) then
            return name -- already a real file path
        end
    end
    return fallbackPaths[mediaType]
end

---Resolve a module's effective font straight to a usable font path.
---@param moduleDB table?
---@return string path
function NRSKNUI:GetFont(moduleDB)
    local global = self.db and self.db.profile and self.db.profile.globalMedia
    local name
    if global and global.Enabled and global.profileFont.Enabled then
        if moduleDB and moduleDB.UseGlobalFont == false then
            name = moduleDB.FontFace or moduleDB.Font or moduleDB.fontFace or DEFAULT_FONT_NAME
        else
            name = global.profileFont.FontFace or DEFAULT_FONT_NAME
        end
    else
        name = moduleDB and (moduleDB.FontFace or moduleDB.Font or moduleDB.fontFace) or DEFAULT_FONT_NAME
    end
    return self:ResolveMediaPath('font', name) or FALLBACK_FONT --[[@as string]]
end

---Resolve a module's effective statusbar straight to a usable texture path.
---@param moduleDB table?
---@param override string? per-element texture name, wins outright when set.
---@return string path
function NRSKNUI:GetStatusbar(moduleDB, override)
    -- A per-element override is an explicit pick, so it beats the global bar too. Without this
    -- the global texture silently swallowed every element override (global media is on by default).
    if override then
        return self:ResolveMediaPath('statusbar', override) or fallbackPaths.statusbar --[[@as string]]
    end

    local global = self.db and self.db.profile and self.db.profile.globalMedia
    local name
    if global and global.Enabled and global.profileBar.Enabled then
        if moduleDB and moduleDB.UseGlobalBar == false then
            name = moduleDB.StatusBarTexture or moduleDB.statusBar or 'NorskenUI'
        else
            name = global.profileBar.statusBar or 'NorskenUI'
        end
    else
        name = (moduleDB and (moduleDB.StatusBarTexture or moduleDB.statusBar)) or 'NorskenUI'
    end
    return self:ResolveMediaPath('statusbar', name) or fallbackPaths.statusbar --[[@as string]]
end

---@param name string|number LSM sound name, literal path, or fileID
---@param channel string?
function NRSKNUI:PlaySafeSound(name, channel)
    local resolved = self:ResolveMediaPath('sound', name)
    if not resolved then return end

    PlaySoundFile(resolved, channel or 'Master')
end

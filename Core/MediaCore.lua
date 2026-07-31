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
local GetAtlasInfo = C_Texture and C_Texture.GetAtlasInfo

-- Locale masks: LSM rejects font registrations on koKR/zhCN/zhTW/ruRU clients unless the mask includes their locale bit and Fetch then falls back to the locale default game font.
local westAndRU = LSM.LOCALE_BIT_western + LSM.LOCALE_BIT_ruRU
-- STANDARD_TEXT_FONT is locale-correct (ARKai_T on zhCN, 2002 on koKR, etc) a hardcoded FRIZQT__ fallback renders CJK text as boxes on those clients.
local FALLBACK_FONT = STANDARD_TEXT_FONT or (GameFontNormal and GameFontNormal:GetFont()) or 'Fonts\\FRIZQT__.TTF'
local FALLBACK_SIZE = 12
local DEFAULT_FONT_NAME = 'Expressway'
local SOLID = NRSKNUI.WhiteTexture
local fallbackPaths = {
    font = FALLBACK_FONT,
    statusbar = [[Interface\TargetingFrame\UI-StatusBar]],
    spark = SOLID,
}

NRSKNUI.Media = {
    Fonts = {},
    Statusbars = {},
    Sounds = {},
    Solid = SOLID,
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
    spark = '',
}

---Register one media file with LSM. Types with a media folder above take a bare file name and
---get NRSKNUI.Media populated, types without one take the finished path or atlas name.
---@param MediaType string
---@param FileName string file name, or a complete path/atlas for types with no media folder
---@param DisplayName string | boolean true reuses the file name, a string names it explicitly
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

        local nameKey
        if DisplayName == true then
            nameKey = cleanFileName
        elseif type(DisplayName) == 'string' then
            nameKey = DisplayName
        end
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

-- Spark reg
RegisterLSMMedia('spark', SOLID, 'Solid')
RegisterLSMMedia('spark', [[Interface\CastingBar\UI-CastingBar-Spark]], 'Blizzard Spark')
RegisterLSMMedia('spark', 'Insanity-Spark', 'Blizzard Insanity Spark')
RegisterLSMMedia('spark', 'XPBarAnim-OrangeSpark', 'Blizzard XPBar Spark')
RegisterLSMMedia('spark', 'GarrMission_EncounterBar-Spark', 'Blizzard Garrison Mission Encounter Spark')
RegisterLSMMedia('spark', 'Legionfall_BarSpark', 'Blizzard Legionfall Spark')
RegisterLSMMedia('spark', 'honorsystem-bar-spark', 'Blizzard Honor System Spark')
RegisterLSMMedia('spark', 'bonusobjectives-bar-spark', 'Bonus Objectives Spark')


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
---@param name string|nil LSM name or literal path
---@return string|nil path per-type fallback when unresolved (nil for sounds)
function NRSKNUI:ResolveMediaPath(mediaType, name)
    if name and name ~= '' then
        if LSM:IsValid(mediaType, name) then
            local path = LSM:Fetch(mediaType, name, true)

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
    return self:ResolveMediaPath('font', name) or FALLBACK_FONT
end

---Resolve a module's effective statusbar straight to a usable texture path.
---@param moduleDB table?
---@param override string? per-element texture name, wins outright when set.
---@return string path
function NRSKNUI:GetStatusbar(moduleDB, override)
    -- A per-element override is an explicit pick, so it beats the global bar too. Without this
    -- the global texture silently swallowed every element override (global media is on by default).
    if override then
        return self:ResolveMediaPath('statusbar', override) or fallbackPaths.statusbar
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
    return self:ResolveMediaPath('statusbar', name) or fallbackPaths.statusbar
end

---Resolve spark texture to a usable file path or atlas name, with a fallback to the solid spark.
---@param name string? LSM spark name, literal path, or atlas name
---@return string value
local function ResolveSpark(name)
    if name and name ~= '' then
        if LSM:IsValid('spark', name) then
            local value = LSM:Fetch('spark', name, true)
            if value then return value end
        elseif (GetAtlasInfo and GetAtlasInfo(name)) or (IsKnownFile and IsKnownFile(name)) then
            return name
        end
    end
    return fallbackPaths.spark
end

---Set a spark texture, vertex color and size to suit the bar height and chosen texture.
---@param texture Texture
---@param moduleDB table?
---@param barHeight number? height of the bar the spark rides on, omit to keep the caller's size.
---@param override string? per-element spark name, wins over the global texture but not its scale.
function NRSKNUI:SetSpark(texture, moduleDB, barHeight, override)
    local global = self.db and self.db.profile and self.db.profile.globalMedia
    local globalSpark = global and global.Enabled and global.profileSpark

    -- Use global or per module spark settings, but allow a per-element override to win outright.
    local name, scale, color, width
    if globalSpark and globalSpark.Enabled and not (moduleDB and moduleDB.UseGlobalSpark == false) then
        name, scale, color, width = globalSpark.sparkTexture, globalSpark.Scale, globalSpark.color, globalSpark.Width
    elseif moduleDB then
        name, scale, color, width = moduleDB.SparkTexture, moduleDB.SparkScale, moduleDB.SparkColor, moduleDB.SparkWidth
    end

    -- Set spark texture.
    local value = ResolveSpark(override or name or 'Solid')
    local atlas = GetAtlasInfo and GetAtlasInfo(value)
    if atlas then
        texture:SetAtlas(value)
    else
        texture:SetTexture(value)
    end

    -- Spark coloring.
    texture:SetDesaturated(true) -- Set to true so that the spark can be colored with SetVertexColor, even if the texture is a colored atlas.
    if color then
        texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    else
        texture:SetVertexColor(1, 1, 1, 1)
    end

    if not barHeight then return end

    -- Calculate the spark size based on the bar height and the texture's aspect ratio.
    -- Only the solid spark takes a width setting: it is a plain fill with no proportions of its
    -- own, where every other texture derives its width from the art so it cannot be stretched.
    local height = barHeight * (scale or 1)
    if value == SOLID then
        texture:NUISetPixelSize(width or 2, (barHeight - 2) * (scale or 1))
    elseif atlas and atlas.width and atlas.height and atlas.height > 0 then
        texture:NUISetPixelSize(height * (atlas.width / atlas.height), height)
    else
        texture:NUISetPixelSize(height, height)
    end
end

---@param name string LSM sound name or literal path
---@param channel string?
function NRSKNUI:PlaySafeSound(name, channel)
    local resolved = self:ResolveMediaPath('sound', name)
    if not resolved then return end

    PlaySoundFile(resolved, channel or 'Master')
end

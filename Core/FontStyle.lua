---@class NRSKNUI
local NRSKNUI = select(2, ...)
local LSM = NRSKNUI.Libs.LSM

local pairs = pairs
local ipairs = ipairs
local type = type
local format = string.format
local CreateFrame = CreateFrame
local CreateFont = CreateFont
local CreateFontFamily = CreateFontFamily

local animEnum = Enum and Enum.FontStringScaleAnimationMode
local vertexEnum = Enum and Enum.FontStringScaleAnimationMode.Vertex
local fontSizeEnum = Enum and Enum.FontStringScaleAnimationMode.FontSize

local IsKnownFile = C_UIFileAsset and C_UIFileAsset.IsKnownFile

-- STANDARD_TEXT_FONT is locale-correct (ARKai_T on zhCN, 2002 on koKR, etc) a hardcoded FRIZQT__ fallback renders CJK text as boxes on those clients.
local FALLBACK_FONT = STANDARD_TEXT_FONT or (GameFontNormal and GameFontNormal:GetFont()) or 'Fonts\\FRIZQT__.TTF'
local DEFAULT_SIZE = 12
local DEFAULT_FONT_NAME = 'Expressway'

NRSKNUI.StyledFonts = NRSKNUI.StyledFonts or {}
NRSKNUI.StyledJustify = NRSKNUI.StyledJustify or {}

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

---@return string
local function GetGlobalFontName()
    local profile = NRSKNUI.db and NRSKNUI.db.profile
    local global = profile and profile.globalMedia
    if global and global.Enabled and global.profileFont and global.profileFont.Enabled then
        return global.profileFont.FontFace or DEFAULT_FONT_NAME
    end
    return DEFAULT_FONT_NAME
end

-- Exposed on NRSKNUI so that it can be used in the GUI.
---@type { value: string|string[], label: string }[]
NRSKNUI.FontOutlines = {
    { value = 'NONE',                                                   label = 'None' },
    { value = 'OUTLINE',                                                label = 'Outline' },
    { value = 'THICKOUTLINE',                                           label = 'Thick' },
    { value = 'MONOCHROME',                                             label = 'Mono' },
    { value = { 'MONOCHROME,OUTLINE', 'OUTLINE,MONOCHROME' },           label = 'Mono Outline' },
    { value = { 'MONOCHROME,THICKOUTLINE', 'THICKOUTLINE,MONOCHROME' }, label = 'Mono Thick' },
    { value = 'SLUG',                                                   label = 'Slug' },
    { value = { 'SLUG,OUTLINE', 'OUTLINE,SLUG' },                       label = 'Slug Outline' },
}

-- Validation set derived from the canonical list. NONE is excluded (it maps to '').
NRSKNUI.ValidOutlines = { [''] = true }
for _, option in ipairs(NRSKNUI.FontOutlines) do
    local value = option.value
    if type(value) == 'table' then
        for _, flags in ipairs(value) do
            NRSKNUI.ValidOutlines[flags] = true
        end
    elseif value ~= 'NONE' then
        NRSKNUI.ValidOutlines[value] = true
    end
end
local ValidOutlines = NRSKNUI.ValidOutlines

---@param outline string?
---@return string
local function NormalizeOutline(outline)
    if type(outline) ~= 'string' then return '' end

    local flags = outline:upper():gsub('%s+', '')
    if flags == 'NONE' or flags == 'SOFTOUTLINE' then return '' end

    return ValidOutlines[flags] and flags or ''
end

local ALPHABETS = {
    'roman',
    'russian',
    'korean',
    'simplifiedchinese',
    'traditionalchinese',
}

-- Build a table of CJK font paths from the Blizzard font object, if available.
-- This is used to substitute the correct CJK font for each alphabet when creating a font family.
local cjkFonts = {}
do
    local base = _G.GameFontNormal
    if base and base.GetFontObjectForAlphabet then
        for i = 1, #ALPHABETS do
            local alphabet = ALPHABETS[i]
            if alphabet ~= 'roman' and alphabet ~= 'russian' then
                local obj = base:GetFontObjectForAlphabet(alphabet)
                if obj then cjkFonts[alphabet] = obj:GetFont() end
            end
        end
    end
end

---@param fontPath string
---@param size number
---@param style string
---@return table members
local function BuildFontMembers(fontPath, size, style)
    local members = {}
    for i = 1, #ALPHABETS do
        local alphabet = ALPHABETS[i]
        members[i] = {
            alphabet = alphabet,
            file = cjkFonts[alphabet] or fontPath,
            height = size,
            flags = style,
        }
    end
    return members
end

-- Shadow carries arbitrary color/offset, so it is part of the object's identity.
---@param shadow table?
---@return string
local function ShadowSignature(shadow)
    if not (shadow and shadow.Enabled) then return '0' end
    local c = shadow.Color or {}
    return format('%s:%s:%s:%s:%s:%s', c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1, shadow.OffsetX or 1, shadow.OffsetY or -1)
end

---@param obj table font object (family or plain)
---@param shadow table?
local function ApplyObjectShadow(obj, shadow)
    local r, g, b, a = 0, 0, 0, 0
    local ox, oy = 0, 0
    if shadow and shadow.Enabled then
        local c = shadow.Color or {}
        r, g, b, a = c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1
        ox, oy = shadow.OffsetX or 1, shadow.OffsetY or -1
    end

    -- ** Blizzy bug **
    -- Always write both branches (color + offset) so toggling a shadow off on a
    -- reused object actually clears a previously-set shadow instead of leaving it stale.
    if obj.GetFontObjectForAlphabet then
        for i = 1, #ALPHABETS do
            local member = obj:GetFontObjectForAlphabet(ALPHABETS[i])
            if member then
                member:SetShadowColor(r, g, b, a)
                member:SetShadowOffset(ox, oy)
            end
        end
    else
        obj:SetShadowColor(r, g, b, a)
        obj:SetShadowOffset(ox, oy)
    end
end

local fontObjects = {}
local familyIndex = 0

---@param fontPath string
---@param size number
---@param style string
---@param sig string shadow signature
---@param shadow table?
---@return table fontObject
local function AcquireFontObject(fontPath, size, style, sig, shadow)
    local byPath = fontObjects[fontPath]
    if not byPath then
        byPath = {}
        fontObjects[fontPath] = byPath
    end

    local bySize = byPath[size]
    if not bySize then
        bySize = {}
        byPath[size] = bySize
    end

    local byStyle = bySize[style]
    if not byStyle then
        byStyle = {}
        bySize[style] = byStyle
    end

    local obj = byStyle[sig]
    if not obj then
        familyIndex = familyIndex + 1
        local name = 'NRSKNUI_Font' .. familyIndex
        if CreateFontFamily then
            obj = CreateFontFamily(name, BuildFontMembers(fontPath, size, style))
        else
            -- Fallback if CreateFontFamily is unavailable: a plain font object still
            -- delivers the shadow fix, just without per-alphabet CJK substitution.
            obj = CreateFont(name)
            obj:SetFont(fontPath, size, style)
        end
        ApplyObjectShadow(obj, shadow)
        byStyle[sig] = obj
    end

    return obj
end

---Style any FontString or Font object in one call.
---@param self table FontString or Font object
---@param source string|table|nil DB block, explicit LSM name / path, or nil for the global font
---@param size number? explicit size, or a size override when `source` is a DB block
---@param outline string? explicit outline (ignored when `source` is a DB block)
---@param shadow table? explicit shadow (ignored when `source` is a DB block)
---@param skip boolean? internal: set during RefreshFontStyles to avoid re-registering
---@param setOwner boolean? point the widget's state font objects at ours so every state resolves to our fontObject
---@return boolean
local function SetFontStyle(self, source, size, outline, shadow, skip, setOwner)
    if not self or not self.SetFontObject then return false end

    -- Store the raw source (not a resolved path) so a refresh re-runs resolution -
    -- a DB block re-reads the current global/module font, an explicit font re-resolves.
    if not skip then
        NRSKNUI.StyledFonts[self] = {
            source = source,
            size = size,
            outline = outline,
            shadow = shadow,
            setOwner = setOwner,
        }
    end

    local font
    if type(source) == 'table' then
        local db = source
        local database = NRSKNUI.db
        local profile = database and database.profile
        local global = profile and profile.globalMedia
        local useGlobal = global and global.Enabled and global.profileFont
            and global.profileFont.Enabled and db.UseGlobalFont ~= false

        -- Leave font nil under global so it resolves (and re-resolves) the global face.
        if not useGlobal then
            font = db.FontFace or db.Font or db.fontFace
        end
        size = size or db.FontSize -- `size` acts as an optional override here
        outline = db.FontOutline
        shadow = db.FontShadow
    else
        font = source
    end

    local fontPath = ResolveFontPath(font or GetGlobalFontName())
    size = (type(size) == 'number' and size > 0) and size or DEFAULT_SIZE
    local style = NormalizeOutline(outline)
    local obj = AcquireFontObject(fontPath, size, style, ShadowSignature(shadow), shadow)

    -- SLUG needs vertex-based scaling, everything else uses font-size scaling.
    if self.SetScaleAnimationMode and animEnum then
        local slug = style:find('SLUG') ~= nil
        self:SetScaleAnimationMode(slug and vertexEnum or fontSizeEnum)
    end

    self:SetFontObject(obj)

    -- If the font is being applied to a FontString that is the text of a Button or CheckButton,
    -- point the widget's state font objects at ours so every state resolves to our fontObject.
    -- This is necessary because SetFontObject resets the widget's state font objects to their defaults, which may not match the desired style.
    if setOwner then
        local owner = self.GetParent and self:GetParent()
        if owner and owner.SetNormalFontObject then
            local label = owner.GetFontString and owner:GetFontString()
            if label == self or (not label and owner.Text == self) then
                owner:SetNormalFontObject(obj)
                if owner.SetHighlightFontObject then owner:SetHighlightFontObject(obj) end
                if owner.SetDisabledFontObject then owner:SetDisabledFontObject(obj) end
            end
        end
    end

    return true
end

-- Publish onto both metatables.
do
    -- FontString and Font are distinct types, so a FontString we create and a named Blizzard Font object, e.g. InvoiceTextFontNormal, need the method injected separately.
    local methods = { SetFontStyle = SetFontStyle }
    NRSKNUI:InjectAPI(CreateFrame('Frame'):CreateFontString(), methods)
    if _G.GameFontNormal then
        NRSKNUI:InjectAPI(_G.GameFontNormal, methods)
    end
end

---@param anchorPoint string?
---@return string 'LEFT'|'CENTER'|'RIGHT'
local function GetTextJustifyHFromAnchor(anchorPoint)
    if not anchorPoint then return 'CENTER' end
    if anchorPoint == 'RIGHT' or anchorPoint == 'TOPRIGHT' or anchorPoint == 'BOTTOMRIGHT' then
        return 'RIGHT'
    elseif anchorPoint == 'LEFT' or anchorPoint == 'TOPLEFT' or anchorPoint == 'BOTTOMLEFT' then
        return 'LEFT'
    end
    return 'CENTER'
end

---@param anchorPoint string?
---@return string 'TOP'|'MIDDLE'|'BOTTOM'
local function GetTextJustifyVFromAnchor(anchorPoint)
    if not anchorPoint then return 'MIDDLE' end
    if anchorPoint == 'TOP' or anchorPoint == 'TOPLEFT' or anchorPoint == 'TOPRIGHT' then
        return 'TOP'
    elseif anchorPoint == 'BOTTOM' or anchorPoint == 'BOTTOMLEFT' or anchorPoint == 'BOTTOMRIGHT' then
        return 'BOTTOM'
    end
    return 'MIDDLE'
end

---Anchor a string to its Position.AnchorFrom and align both axes from that same point,
---then register it so RefreshFontStyles re-applies it — SetFontObject (via SetFontStyle)
---resets justify, so this MUST run after the font pass or the alignment reverts on a
---profile change. AnchorFrom encodes both axes: TOPRIGHT -> point TOPRIGHT, H RIGHT, V TOP.
---@param self table FontString
---@param source table DB block with a Position.AnchorFrom
---@param parent table? anchor parent, defaults to self:GetParent()
---@param offsetX number?
---@param offsetY number?
---@param skip boolean? internal: set during RefreshFontStyles to avoid re-registering
---@return boolean
local function SetFontJustify(self, source, parent, offsetX, offsetY, skip)
    if not self or not self.SetJustifyH or not source then return false end

    if not skip then
        NRSKNUI.StyledJustify[self] = {
            source = source,
            parent = parent,
            offsetX = offsetX,
            offsetY = offsetY,
        }
    end

    local anchor = (source.Position and source.Position.AnchorFrom) or 'CENTER'

    -- Flip the X offset when the anchor is on the right side of the parent.
    if anchor == 'LEFT' then
        offsetX = offsetX
    elseif anchor == 'RIGHT' then
        offsetX = -offsetX
    end

    self:ClearAllPoints()
    self:SetPoint(anchor, parent or self:GetParent(), anchor, offsetX or 0, offsetY or 0)
    self:SetJustifyH(GetTextJustifyHFromAnchor(anchor)) -- LEFT, CENTER, RIGHT
    self:SetJustifyV(GetTextJustifyVFromAnchor(anchor)) -- TOP, MIDDLE, BOTTOM

    return true
end

-- Publish SetFontJustify onto the FontString metatable.
NRSKNUI:InjectAPI(CreateFrame('Frame'):CreateFontString(), { SetFontJustify = SetFontJustify })

---Re-apply every registered string. Runs on profile change, call after a global font change too.
---skip == true keeps the setters from mutating their registries mid-loop.
function NRSKNUI:RefreshFontStyles()
    for fs, data in pairs(self.StyledFonts) do
        SetFontStyle(fs, data.source, data.size, data.outline, data.shadow, true, data.setOwner)
    end
    -- Justify runs after the font pass, SetFontObject resets JustifyH/V, so re-applying here restores the anchor-based alignment the font swap just wiped.
    for fs, data in pairs(self.StyledJustify) do
        SetFontJustify(fs, data.source, data.parent, data.offsetX, data.offsetY, true)
    end
end

do
    -- db only exists after OnInitialize, so wire the profile callbacks at login.
    -- A dedicated target table keeps this registration separate from Main.lua's.
    local callbackTarget = {}
    local function OnProfileChanged()
        NRSKNUI:DeferUntilUnrestricted(0, function() NRSKNUI:RefreshFontStyles() end)
    end

    local loginFrame = CreateFrame('Frame')
    loginFrame:RegisterEvent('PLAYER_LOGIN')
    loginFrame:SetScript('OnEvent', function(self)
        self:UnregisterAllEvents()
        if not NRSKNUI.db then return end
        NRSKNUI.db.RegisterCallback(callbackTarget, 'OnProfileChanged', OnProfileChanged)
        NRSKNUI.db.RegisterCallback(callbackTarget, 'OnProfileCopied', OnProfileChanged)
        NRSKNUI.db.RegisterCallback(callbackTarget, 'OnProfileReset', OnProfileChanged)
    end)
end

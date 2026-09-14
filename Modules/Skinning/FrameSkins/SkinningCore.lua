---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local strlower = strlower
local Mixin = Mixin
local CreateFont = CreateFont
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local setmetatable = setmetatable
local xpcall = xpcall
local geterrorhandler = geterrorhandler

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded

---@type SkinEntry[]
Skinning.skins = {}
---@type table<string, SkinEntry[]>
Skinning.addonIndex = {}
-- Weak-keyed set of skinned widgets implementing NUIUpdateSkinColors()
Skinning.skinned = setmetatable({}, { __mode = 'k' })

---Register a skin function, run once its Blizzard addon loads. Safe to call at file scope.
---@param addonName string? Blizzard addon that must load first; nil = always-loaded base UI
---@param key string Toggle key under db.Frames
---@param func fun(S: SkinningModule) Skin function; receives the Skinning module
function Skinning:RegisterSkin(addonName, key, func)
    local entry = { addonName = addonName, key = key, func = func, ran = false }
    self.skins[#self.skins + 1] = entry
    if addonName then
        local list = self.addonIndex[addonName]
        if not list then
            list = {}
            self.addonIndex[addonName] = list
        end
        list[#list + 1] = entry
    end

    -- A file loading after OnEnable would otherwise sit unran until the next ApplySettings.
    if self.db and self:IsEnabled() and (not addonName or IsAddOnLoaded(addonName)) then
        self:RunSkin(entry)
    end
end

---Track a widget for live recoloring, it must implement NUIUpdateSkinColors()
---@param widget Frame|Button|StatusBar|FontString|Font|Texture
function Skinning:RegisterSkinned(widget)
    self.skinned[widget] = true
end

-- Accent text --

---@class AccentTextMixin
local AccentTextMixin = {}

function AccentTextMixin:NUIUpdateSkinColors()
    ---@cast self FontString
    self:SetTextColor(Skinning:GetAccentColor())
end

---Copy a Blizzard font object so it can be restyled without repainting the shared original every
---other frame draws from.
---@param base Font Blizzard font object to copy size and face from
---@param name string
---@return Font
local function CreateOutlinedMirror(base, name)
    local mirror = CreateFont(name)
    mirror:SetFontObject(base)

    -- Read the face and size back off the base so only the outline flag is ours. SetFont drops the
    -- inheritance, so a refused combination falls back rather than leaving the object unset.
    local face, size = mirror:GetFont()
    if face and size and not mirror:SetFont(face, size, 'OUTLINE') then
        mirror:SetFontObject(base)
    end

    return mirror
end

---@type table<Font, Font>
local outlineFonts = {}
local outlineFontCount = 0

---Outlined mirror that stays white, for labels that want the outline without the accent.
---@param base Font Blizzard font object to copy size and face from
---@return Font
function Skinning:GetOutlineFont(base)
    local mirror = outlineFonts[base]
    if mirror then return mirror end

    outlineFontCount = outlineFontCount + 1
    mirror = CreateOutlinedMirror(base, 'NorskenUIOutlineFont' .. outlineFontCount)
    mirror:SetTextColor(1, 1, 1)

    outlineFonts[base] = mirror
    return mirror
end

---@type table<Font, NUIAccentFont>
local accentFonts = {}
local accentFontCount = 0

---Mirror a Blizzard font object so the accent can recolor it without repainting the shared
---original every other frame draws from. A FontString follows its font object's color live.
---@param base Font Blizzard font object to copy size and face from
---@return NUIAccentFont
function Skinning:GetAccentFont(base)
    local mirror = accentFonts[base]
    if mirror then return mirror end

    accentFontCount = accentFontCount + 1
    mirror = CreateOutlinedMirror(base, 'NorskenUIAccentFont' .. accentFontCount)

    ---@cast mirror NUIAccentFont
    Mixin(mirror, AccentTextMixin)
    -- Callers at file scope run before the profile exists, the skin pass repaints them.
    if self.db then mirror:NUIUpdateSkinColors() end

    accentFonts[base] = mirror
    self:RegisterSkinned(mirror)
    return mirror
end

---Swap a FontString onto an accent mirror of whatever font object it already carries, so its size
---and face are kept. For labels that take their color from that object rather than their own.
---@param text FontString?
function Skinning:HandleAccentFont(text)
    -- Re-running would mirror the mirror, so the swap is one way.
    if not text or text.NUIAccented then return end

    local base = text.GetFontObject and text:GetFontObject()
    if not base then return end

    text.NUIAccented = true
    text:SetFontObject(self:GetAccentFont(base))
end

---Swap a FontString onto an outlined mirror of whatever font object it already carries, so its size
---and face stay the ones BlizzardFonts resolved. Swapping resets the string's own color, so call this
---before any SetTextColor on the same label.
---@param text FontString?
function Skinning:HandleOutlineFont(text)
    -- Re-running would mirror the mirror, so the swap is one way.
    if not text or text.NUIOutlined then return end

    local base = text.GetFontObject and text:GetFontObject()
    if not base then return end

    text.NUIOutlined = true
    text:SetFontObject(self:GetOutlineFont(base))
end

---Paint one FontString in the accent, for labels whose own color overrides their font object.
---@param text FontString?
function Skinning:HandleAccentText(text)
    if not text or text.NUISkinned then return end
    text.NUISkinned = true

    ---@cast text FontString & AccentTextMixin
    Mixin(text, AccentTextMixin)
    text:NUIUpdateSkinColors()

    self:RegisterSkinned(text)
end

---Resolve the accent from the mode picked in the db: theme, class or custom.
---@return number r, number g, number b, number a
function Skinning:GetAccentColor()
    return NRSKNUI:GetAccentColor(self.db.General.AccentMode, self.db.General.CustomAccentColor)
end

-- Backdrops --

local SkinnedBackdropMixin = {}

local WIDGET_GLOW_ATLAS = 'glues-characterSelect-GS-TopHUD-middle-selectedGlow'

---@param backdrop Frame
local function UpdateWidgetGlow(backdrop)
    local glow = backdrop.NUIGlow
    if not glow then return end

    local color = Skinning.db.General.WidgetGlowColor
    glow:SetVertexColor(color[1], color[2], color[3], color[4])
end

function SkinnedBackdropMixin:NUIUpdateSkinColors()
    local general = Skinning.db.General
    local bg = self.NUIIsWidget and general.WidgetBackgroundColor or general.BackgroundColor
    local border = self.NUIIsWidget and general.WidgetBorderColor or general.BorderColor

    self:SetBackgroundColor(bg[1], bg[2], bg[3], self.NUIBgAlpha or bg[4])
    self:SetBorderColor(border[1], border[2], border[3], border[4])
    UpdateWidgetGlow(self)
end

---A child at its parent's level draws on top of it, so make room below rather than clamping into a collision.
---@param frame Frame
---@return number level
local function LowerLevel(frame)
    if frame:GetFrameLevel() == 0 then frame:SetFrameLevel(1) end
    return frame:GetFrameLevel() - 1
end

---Create a pixel-perfect backdrop child frame colored from the Blizzard Elements db
---@param frame Frame
---@param template string? 'Transparent' pins the background alpha at 0.5
---@param skipRegister boolean? Skip recolor registration (caller owns coloring)
---@param isWidget boolean? Color it from the Widget palette and give it the widget glow
---@return Frame|nil backdrop
function Skinning:CreatePanelBackdrop(frame, template, skipRegister, isWidget)
    if not frame then return end
    if frame.NUIBackdrop then return frame.NUIBackdrop end

    local backdrop = CreateFrame('Frame', nil, frame)
    backdrop:SetAllPoints(frame)
    backdrop:SetFrameLevel(LowerLevel(frame))
    backdrop:NUICreateBackdrop()

    ---@cast backdrop Frame & PublicBackdropMixin & SkinnedBackdropMixin
    Mixin(backdrop, SkinnedBackdropMixin)

    if template == 'Transparent' then
        backdrop.NUIBgAlpha = 0.5
    end
    -- BACKGROUND/2 keeps the glow over the fill but under the border, and the atlas is baked warm.
    if isWidget then
        backdrop.NUIIsWidget = true

        local glow = backdrop:CreateTexture(nil, 'BACKGROUND', nil, 2)
        glow:SetAllPoints(backdrop.backdropBackground)
        glow:SetAtlas(WIDGET_GLOW_ATLAS)
        glow:SetDesaturated(true)
        backdrop.NUIGlow = glow
    end

    backdrop:NUIUpdateSkinColors()

    if not skipRegister then
        self:RegisterSkinned(backdrop)
    end

    frame.NUIBackdrop = backdrop
    return backdrop
end

---@param bar StatusBar
---@param template string? 'Transparent' pins the background alpha at 0.5
---@return Frame|nil backdrop
function Skinning:CreateStatusBarBackdrop(bar, template)
    if not bar then return end
    if bar.NUIBackdrop then return bar.NUIBackdrop end

    local backdrop = CreateFrame('Frame', nil, bar)
    backdrop:SetPoint('TOPLEFT', bar, -1, 1)
    backdrop:SetPoint('BOTTOMRIGHT', bar, 1, -1)
    backdrop:SetFrameLevel(LowerLevel(bar))
    backdrop:NUICreateBackdrop()

    ---@cast backdrop Frame & PublicBackdropMixin & SkinnedBackdropMixin
    Mixin(backdrop, SkinnedBackdropMixin)

    if template == 'Transparent' then
        backdrop.NUIBgAlpha = 0.5
    end

    backdrop:NUIUpdateSkinColors()

    self:RegisterSkinned(backdrop)

    bar.NUIBackdrop = backdrop
    return backdrop
end

-- Highlight overlay --

---@param widget Button
function Skinning:UpdateHighlightColor(widget)
    if not widget.NUIHighlight then return end
    local highlight = self.db.General.HighlightColor
    widget.NUIHighlight:SetColorTexture(highlight[1], highlight[2], highlight[3], highlight[4])
end

---Inset ADD-blended highlight, recolored on every theme/color change.
---@param widget Button
function Skinning:AddHighlight(widget)
    local highlight = widget:CreateTexture(nil, 'HIGHLIGHT')
    highlight:SetPoint('TOPLEFT', widget, 'TOPLEFT', 2, -2)
    highlight:SetPoint('BOTTOMRIGHT', widget, 'BOTTOMRIGHT', -2, 2)
    highlight:SetBlendMode('ADD')
    widget.NUIHighlight = highlight

    self:UpdateHighlightColor(widget)
end

-- Module lifecycle --

function Skinning:UpdateDB()
    self.db = NRSKNUI.db.profile.Skinning.BlizzardElements

    -- Profiles from before the modes were lowercased still hold 'Theme'/'Class'/'Custom'.
    local general = self.db.General
    general.AccentMode = strlower(general.AccentMode)
    local objDb = self.db.ObjectiveTracker
    objDb.ColorMode = strlower(objDb.ColorMode)
end

---@param entry SkinEntry
function Skinning:RunSkin(entry)
    if entry.ran then return end
    if not self.db.Enabled then return end
    if self.db.Frames[entry.key] == false then return end
    -- Flagged before the call so a skin that errors doesn't re-fire on every ADDON_LOADED.
    entry.ran = true
    xpcall(entry.func, geterrorhandler(), Skinning)
end

function Skinning:RunPendingSkins()
    for _, entry in ipairs(self.skins) do
        if not entry.ran and (not entry.addonName or IsAddOnLoaded(entry.addonName)) then
            self:RunSkin(entry)
        end
    end
end

function Skinning:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end
    self:UpdateDB()

    self:RunPendingSkins()

    self:RegisterEvent('ADDON_LOADED', 'OnAddonLoaded')

    self.themeSub = NRSKNUI.GUI:OnThemeChanged(function()
        if self.db.General.AccentMode ~= 'theme' then return end
        self:UpdateColors()
    end)
end

function Skinning:OnDisable()
    if self.themeSub then
        self.themeSub()
        self.themeSub = nil
    end
end

function Skinning:OnAddonLoaded(_, addonName)
    local list = self.addonIndex[addonName]
    if not list then return end
    
    for _, entry in ipairs(list) do
        self:RunSkin(entry)
    end
end

function Skinning:UpdateColors()
    if not self.db.Enabled then return end

    for widget in pairs(self.skinned) do
        if widget.NUIUpdateSkinColors then
            xpcall(widget.NUIUpdateSkinColors, geterrorhandler(), widget)
        end
    end
end

function Skinning:ApplySettings()
    if NRSKNUI:ShouldNotLoadModule() then return end
    self:UpdateDB()
    if not self.db.Enabled then return end

    self:RunPendingSkins()
    self:UpdateColors()
end

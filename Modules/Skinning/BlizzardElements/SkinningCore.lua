---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local strlower = strlower
local Mixin = Mixin
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local setmetatable = setmetatable
local xpcall = xpcall
local geterrorhandler = geterrorhandler
local math_max = math.max

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
---@param widget Frame|Button|StatusBar
function Skinning:RegisterSkinned(widget)
    self.skinned[widget] = true
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
    backdrop:SetFrameLevel(math_max(0, frame:GetFrameLevel() - 1))
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
    backdrop:SetFrameLevel(math_max(0, bar:GetFrameLevel() - 1))
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

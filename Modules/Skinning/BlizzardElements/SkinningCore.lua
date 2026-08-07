---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class Skinning : AceModule, AceEvent-3.0
---@field db table
local Skinning = NRSKNUI:GetModule('Skinning')

local xpcall = xpcall
local geterrorhandler = geterrorhandler
local ipairs = ipairs
local pairs = pairs
local setmetatable = setmetatable

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded

local BSKIN = NRSKNUI.BlizzSkin

function BSKIN:GetDB()
    return NRSKNUI.db.profile.Skinning.BlizzardElements
end

---@type SkinEntry[]
Skinning.skins = {}
---@type table<string, SkinEntry[]>
Skinning.addonIndex = {}
-- Weak-keyed set of skinned widgets implementing NUIUpdateSkinColors(colors)
Skinning.skinned = setmetatable({}, { __mode = "k" })

---Register a skin function, run once its Blizzard addon is loaded (or at enable for base UI).
---Safe to call at file scope; it only queues.
---@param addonName string? Blizzard addon that must load first; nil = always-loaded base UI
---@param key string Toggle key under db.Frames
---@param func fun(S: table) Skin function; receives NRSKNUI.BlizzSkin
function BSKIN:RegisterSkin(addonName, key, func)
    local entry = { addonName = addonName, key = key, func = func, ran = false }
    Skinning.skins[#Skinning.skins + 1] = entry
    if addonName then
        local list = Skinning.addonIndex[addonName]
        if not list then
            list = {}
            Skinning.addonIndex[addonName] = list
        end
        list[#list + 1] = entry
    end
end

---Track a widget for live recoloring; it must implement NUIUpdateSkinColors(colors)
---@param widget Frame|Button|StatusBar
function BSKIN:RegisterSkinned(widget)
    Skinning.skinned[widget] = true
end

---@return RGBA
function BSKIN:GetBorderColor()
    return Skinning.db.General.BorderColor
end

---@return RGBA
function BSKIN:GetBackgroundColor()
    return Skinning.db.General.BackgroundColor
end

---@return RGBA
function BSKIN:GetPanelColor()
    return Skinning.db.General.PanelColor
end

---@return RGBA
function BSKIN:GetDisabledColor()
    return Skinning.db.General.DisabledColor
end

---@return number r, number g, number b, number a
function BSKIN:GetAccentColor()
    local general = Skinning.db.General
    return NRSKNUI:GetAccentColor(general.AccentMode:lower(), general.CustomAccentColor)
end

---@return SkinColors
function BSKIN:GetColors()
    return {
        border = self:GetBorderColor(),
        background = self:GetBackgroundColor(),
        panel = self:GetPanelColor(),
        disabled = self:GetDisabledColor(),
        accent = { self:GetAccentColor() },
    }
end

function Skinning:UpdateDB()
    self.db = NRSKNUI.db.profile.Skinning.BlizzardElements
end

---@param entry SkinEntry
function Skinning:RunSkin(entry)
    if entry.ran then return end
    if self.db.Frames[entry.key] == false then return end
    entry.ran = true
    xpcall(entry.func, geterrorhandler(), BSKIN)
end

function Skinning:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end
    self:UpdateDB()

    for _, entry in ipairs(self.skins) do
        if not entry.addonName or IsAddOnLoaded(entry.addonName) then
            self:RunSkin(entry)
        end
    end

    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
end

function Skinning:OnDisable() end

function Skinning:OnAddonLoaded(_, addonName)
    local list = self.addonIndex[addonName]
    if not list then return end
    for _, entry in ipairs(list) do
        self:RunSkin(entry)
    end
end

function Skinning:UpdateColors()
    local colors = BSKIN:GetColors()
    for widget in pairs(self.skinned) do
        if widget.NUIUpdateSkinColors then
            xpcall(widget.NUIUpdateSkinColors, geterrorhandler(), widget, colors)
        end
    end
end

function Skinning:ApplySettings()
    if NRSKNUI:ShouldNotLoadModule() then return end
    self:UpdateDB()
    if not self.db.Enabled then return end

    for _, entry in ipairs(self.skins) do
        if not entry.ran and (not entry.addonName or IsAddOnLoaded(entry.addonName)) then
            self:RunSkin(entry)
        end
    end

    self:UpdateColors()
end

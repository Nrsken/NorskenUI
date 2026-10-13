---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local ipairs, pairs = ipairs, pairs
local CreateFrame = CreateFrame
local format = string.format
local tostring = tostring
local wipe = wipe

local GetCategorySet = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet
local GetCooldownInfo = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo
local IsCooldownViewerAvailable = C_CooldownViewer and C_CooldownViewer.IsCooldownViewerAvailable
local GetSpellName = C_Spell and C_Spell.GetSpellName
local GetSpellCooldownSecrecy = C_Secrets and C_Secrets.GetSpellCooldownSecrecy
local GetSpellAuraSecrecy = C_Secrets and C_Secrets.GetSpellAuraSecrecy

local Category = Enum and Enum.CooldownViewerCategory

-- Read-only view of Blizzard's cooldown catalogue for the current spec. We never write to the CDM.
---@class CDMCatalogue
local Catalogue = {
    entries = {}, ---@type table<number, CooldownViewerCooldown>
    lists = {}, ---@type table<number, number[]>
    bySpell = { cooldown = {}, aura = {} }, ---@type table<'cooldown'|'aura', table<number, number>>
    dirty = true,
}
CDM.Catalogue = Catalogue

Catalogue.CATEGORIES = {
    Category.Essential,
    Category.Utility,
    Category.TrackedBuff,
    Category.TrackedBar,
}

-- One spell can sit in a cooldown category and an aura category at once.
local KIND = {
    [Category.Essential] = 'cooldown',
    [Category.Utility] = 'cooldown',
    [Category.TrackedBuff] = 'aura',
    [Category.TrackedBar] = 'aura',
}

function Catalogue:Rebuild()
    wipe(self.entries)
    wipe(self.lists)
    wipe(self.bySpell.cooldown)
    wipe(self.bySpell.aura)

    for _, category in ipairs(self.CATEGORIES) do
        local list, bySpell = {}, self.bySpell[KIND[category]]
        for _, cooldownID in ipairs(GetCategorySet(category, true)) do
            local info = GetCooldownInfo(cooldownID)
            if info then
                list[#list + 1] = cooldownID
                self.entries[cooldownID] = info
                if info.spellID then bySpell[info.spellID] = cooldownID end
                if info.overrideSpellID then bySpell[info.overrideSpellID] = cooldownID end
            end
        end
        self.lists[category] = list
    end

    self.dirty = false
end

---@param category number Enum.CooldownViewerCategory
---@return 'cooldown'|'aura'
function Catalogue:GetKind(category)
    return KIND[category]
end

function Catalogue:EnsureBuilt()
    if self.dirty then self:Rebuild() end
end

---@param cooldownID number
---@return CooldownViewerCooldown?
function Catalogue:GetEntry(cooldownID)
    self:EnsureBuilt()
    return self.entries[cooldownID]
end

---@param category number Enum.CooldownViewerCategory
---@return number[] cooldownIDs
function Catalogue:GetList(category)
    self:EnsureBuilt()
    return self.lists[category] or {}
end

---@param spellID number
---@param kind 'cooldown'|'aura'
---@return number? cooldownID
function Catalogue:FindBySpell(spellID, kind)
    self:EnsureBuilt()
    return self.bySpell[kind][spellID]
end

---The spell a cooldown entry currently casts as; overrideSpellID mirrors spellID when nothing overrides it.
---@param info CooldownViewerCooldown
---@return number?
function Catalogue:ResolveSpell(info)
    return info.overrideSpellID or info.spellID
end

-- Same triggers Blizzard's own data provider rebuilds on (CooldownViewerSettingsDataProvider.lua, live).
local REBUILD_EVENTS = {
    'COOLDOWN_VIEWER_DATA_LOADED',
    'COOLDOWN_VIEWER_TABLE_HOTFIXED',
    'COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED',
    'TRAIT_CONFIG_UPDATED',
    'ACTIVE_PLAYER_SPECIALIZATION_CHANGED',
    'ACTIVE_COMBAT_CONFIG_CHANGED',
    'PLAYER_PVP_TALENT_UPDATE',
    'SPELLS_CHANGED',
    'PLAYER_EQUIPMENT_CHANGED',
}

local eventFrame = CreateFrame('Frame')
for _, event in ipairs(REBUILD_EVENTS) do eventFrame:RegisterEvent(event) end
eventFrame:SetScript('OnEvent', function()
    Catalogue.dirty = true
    if CDM:IsEnabled() then CDM:OnCatalogueChanged() end
end)

-- Debug dump --

local CATEGORY_NAMES = {}
for name, value in pairs(Category) do CATEGORY_NAMES[value] = name end

local SECRECY_NAMES = {}
for name, value in pairs(Enum.SecrecyLevel) do SECRECY_NAMES[value] = name end

---@param spellID number?
---@return string
local function SpellLabel(spellID)
    if not spellID then return '-' end
    return format('%s (%d)', GetSpellName(spellID) or '?', spellID)
end

function Catalogue:Dump()
    local available, reason = IsCooldownViewerAvailable()
    NRSKNUI:Print(format('CDM catalogue, viewer available: %s %s', tostring(available), reason or ''))

    self:Rebuild()
    for _, category in ipairs(self.CATEGORIES) do
        local list = self.lists[category]
        print(format('|cffffd100%s|r: %d', CATEGORY_NAMES[category], #list))

        for _, cooldownID in ipairs(list) do
            local info = self.entries[cooldownID]
            local spellID = self:ResolveSpell(info)
            local isAura = self:GetKind(category) == 'aura'
            local secrecy = spellID and (isAura and GetSpellAuraSecrecy or GetSpellCooldownSecrecy)(spellID)
            local overridden = info.overrideSpellID and info.overrideSpellID ~= info.spellID

            print(format('  %d %s%s known=%s charges=%s linked=%d %s=%s',
                cooldownID,
                SpellLabel(info.spellID),
                overridden and (' -> ' .. SpellLabel(info.overrideSpellID)) or '',
                tostring(info.isKnown),
                tostring(info.charges),
                #info.linkedSpellIDs,
                isAura and 'aura' or 'cd',
                secrecy and SECRECY_NAMES[secrecy] or '-'))
        end
    end
end

---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class MiscVarsModule
local MiscVars = NRSKNUI:GetModule('MiscVars')
local L = NRSKNUI.Libs.AL
function MiscVars:UpdateDB() self.db = self.namespace.profile end

local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local C_Timer = C_Timer

local SetCVar = C_CVar and C_CVar.SetCVar
local GetCVar = C_CVar and C_CVar.GetCVar

---@type table
MiscVars.DEFS = {
    -- General CVars
    {
        key = 'nameplateUseClassColorForFriendlyPlayerUnitNames',
        label = L['Class Colored Friendly Nameplates'],
        description = L['Display the class color in friendly player nameplate names.'],
        type = 'boolean',
        default = false,
    },
    {
        key = 'nameplateShowOnlyNameForFriendlyPlayerUnits',
        label = L['Hide Friendly Nameplate Bars'],
        description = L['Hide every part of the nameplate except the name for friendly players.'],
        type = 'boolean',
        default = false,
    },
    {
        key = 'ResampleAlwaysSharpen',
        label = L['Sharpen Visuals'],
        description = L['Applies a sharpening filter to the game visuals.'],
        type = 'boolean',
        default = false,
    },
    {
        key = 'cameraDistanceMaxZoomFactor',
        label = L['Max Camera Distance'],
        description = L['Adjust the maximum distance the camera will follow behind you.'],
        type = 'number',
        min = 1,
        max = 2.6,
        step = 0.1,
        default = 1.9,
    },
    {
        key = 'alwaysCompareItems',
        label = L['Always compare items'],
        description = L['Only compare items while holding shift if disabled, comparing items in combat causes framedrops.'],
        type = 'boolean',
        default = true,
    },
    -- Dev CVars
    {
        key = 'addonPvPMatchRestrictionsForced',
        label = L['Force PvP Match Addon Restrictions'],
        description = L['Force addon restrictions during PvP matches.'],
        type = 'boolean',
        default = false,
        category = 'dev',
    },
    {
        key = 'addonMapRestrictionsForced',
        label = L['Force Map Addon Restrictions'],
        description = L['Force addon restrictions for map functionality.'],
        type = 'boolean',
        default = false,
        category = 'dev',
    },
    {
        key = 'addonEncounterRestrictionsForced',
        label = L['Force Encounter Addon Restrictions'],
        description = L['Force addon restrictions during encounters.'],
        type = 'boolean',
        default = false,
        category = 'dev',
    },
    {
        key = 'addonCombatRestrictionsForced',
        label = L['Force Combat Addon Restrictions'],
        description = L['Force addon restrictions during combat.'],
        type = 'boolean',
        default = false,
        category = 'dev',
    },
    {
        key = 'addonChatRestrictionsForced',
        label = L['Force Chat Addon Restrictions'],
        description = L['Force addon restrictions for chat functionality.'],
        type = 'boolean',
        default = false,
        category = 'dev',
    },
    {
        key = 'addonChallengeModeRestrictionsForced',
        label = L['Force M+ Addon Restrictions'],
        description = L['Force addon restrictions during Mythic+ dungeons.'],
        type = 'boolean',
        default = false,
        category = 'dev',
    },
    {
        key = 'tooltipShowAuraSpellIDs',
        label = L['Show Aura Spell IDs in Tooltip'],
        description = L['Show the spell IDs of auras in the tooltip.'],
        type = 'boolean',
        default = false,
        category = 'dev',
    },
    -- Combat text CVars
    {
        key = 'floatingCombatTextCombatDamage_v2',
        label = L['Floating Combat Text Damage'],
        description = L['Show floating combat text for damage.'],
        type = 'boolean',
        default = true,
        category = 'combatTexts',
    },
    {
        key = 'floatingCombatTextCombatHealing_v2',
        label = L['Floating Combat Text Healing'],
        description = L['Show floating combat text for healing.'],
        type = 'boolean',
        default = true,
        category = 'combatTexts',
    },
    {
        key = 'enableFloatingCombatText',
        label = L['Enable Floating Combat Text'],
        description = L['Enable floating combat text for damage and healing.'],
        type = 'boolean',
        default = true,
        category = 'combatTexts',
    },
    {
        key = 'floatingCombatTextReactives_v2',
        label = L['Floating Combat Text Reactives'],
        description = L['Show floating combat text for reactives.'],
        type = 'boolean',
        default = true,
        category = 'combatTexts',
    },
    {
        key = 'WorldTextScale_v2',
        label = L['World Text Scale'],
        description = L['Adjust the scale of world text. Set this to max value to hide stagger text.'],
        type = 'number',
        min = 0.1,
        max = 100000,
        step = 0.1,
        default = 1.0,
        category = 'combatTexts',
    },
}

---@type table
MiscVars.SQW_DEFS = {
    {
        key = 'SpellQueueWindowMelee',
        label = L['Melee SQW'],
        description = L['Spell Queue Window value for melee specializations.'],
        type = 'number',
        min = 1,
        max = 400,
        step = 1,
        default = 400,
        position = 'MELEE',
    },
    {
        key = 'SpellQueueWindowRanged',
        label = L['Ranged SQW'],
        description = L['Spell Queue Window value for ranged specializations.'],
        type = 'number',
        min = 1,
        max = 400,
        step = 1,
        default = 400,
        position = 'RANGED',
    },
}

local function ToCVarValue(value, cvarType)
    if cvarType == 'boolean' then
        return value and 1 or 0
    elseif cvarType == 'number' then
        return tostring(value)
    end
    return value
end

local function FromCVarValue(value, cvarType)
    if cvarType == 'boolean' then
        return value == '1'
    elseif cvarType == 'number' then
        return tonumber(value) or 0
    end
    return value
end

function MiscVars:GetCVar(key)
    for _, def in ipairs(self.DEFS) do
        if def.key == key then
            local current = GetCVar(key)

            return FromCVarValue(current, def.type)
        end
    end
    return nil
end

function MiscVars:SetCVar(key, value)
    for _, def in ipairs(self.DEFS) do
        if def.key == key then
            SetCVar(key, ToCVarValue(value, def.type))
            return
        end
    end
end

function MiscVars:GetSQW(key)
    if self.db[key .. 'Managed'] and self.db[key] then
        return self.db[key]
    end
    return tonumber(GetCVar('SpellQueueWindow')) or 400
end

function MiscVars:IsSQWManaged(key)
    return self.db[key .. 'Managed'] == true
end

function MiscVars:ApplySQW()
    local position = NRSKNUI.MySpec and NRSKNUI.MySpec.position
    if not position then return end

    local sqwKey = position == 'MELEE' and 'SpellQueueWindowMelee' or 'SpellQueueWindowRanged'

    if not self.db[sqwKey .. 'Managed'] then return end

    local sqwValue = self.db[sqwKey]
    if sqwValue then
        local currentSQW = tonumber(GetCVar('SpellQueueWindow')) or 400

        if sqwValue ~= currentSQW then
            SetCVar('SpellQueueWindow', tostring(sqwValue))
        end
    end
end

function MiscVars:SetSQW(key, value)
    self.db[key] = value
    self.db[key .. 'Managed'] = true

    local position = NRSKNUI.MySpec and NRSKNUI.MySpec.position
    local activeKey = position == 'MELEE' and 'SpellQueueWindowMelee' or 'SpellQueueWindowRanged'
    if key == activeKey then
        SetCVar('SpellQueueWindow', tostring(value))
    end
end

function MiscVars:PLAYER_SPECIALIZATION_CHANGED()
    C_Timer.After(0.1, function()
        self:ApplySQW()
    end)
end

function MiscVars:OnEnable()
    self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
    C_Timer.After(1, function()
        self:ApplySQW()
    end)
end

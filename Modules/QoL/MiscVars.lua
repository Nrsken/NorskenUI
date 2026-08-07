---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class MiscVarsModule
local MiscVars = NRSKNUI:GetModule('MiscVars')

local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local C_Timer = C_Timer

local SetCVar = C_CVar and C_CVar.SetCVar
local GetCVar = C_CVar and C_CVar.GetCVar

function MiscVars:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.MiscVars
end

---@type table
MiscVars.DEFS = {
    {
        key = 'nameplateUseClassColorForFriendlyPlayerUnitNames',
        label = 'Class Colored Friendly Nameplates',
        description = 'Display the class color in friendly player nameplate names.',
        type = 'boolean',
        default = false,
    },
    {
        key = 'nameplateShowOnlyNameForFriendlyPlayerUnits',
        label = 'Hide Friendly Nameplate Bars',
        description = 'Hide every part of the nameplate except the name for friendly players.',
        type = 'boolean',
        default = false,
    },
    {
        key = 'ResampleAlwaysSharpen',
        label = 'Sharpen Visuals',
        description = 'Applies a sharpening filter to the game visuals.',
        type = 'boolean',
        default = false,
    },
    {
        key = 'cameraDistanceMaxZoomFactor',
        label = 'Max Camera Distance',
        description = 'Adjust the maximum distance the camera will follow behind you.',
        type = 'number',
        min = 1,
        max = 2.6,
        step = 0.1,
        default = 1.9,
    },
    {
        key = 'alwaysCompareItems',
        label = 'Always compare items',
        description = 'Only compare items while holding shift if disabled, comparing items in combat causes framedrops.',
        type = 'boolean',
        default = true,
    },
    {
        key = 'addonPvPMatchRestrictionsForced',
        label = 'Force PvP Match Addon Restrictions',
        description = 'Force addon restrictions during PvP matches.',
        type = 'boolean',
        default = false,
        category = 'dev',
    },
    {
        key = 'addonMapRestrictionsForced',
        label = 'Force Map Addon Restrictions',
        description = 'Force addon restrictions for map functionality.',
        type = 'boolean',
        default = false,
        category = 'dev',
    },
    {
        key = 'addonEncounterRestrictionsForced',
        label = 'Force Encounter Addon Restrictions',
        description = 'Force addon restrictions during encounters.',
        type = 'boolean',
        default = false,
        category = 'dev',
    },
    {
        key = 'addonCombatRestrictionsForced',
        label = 'Force Combat Addon Restrictions',
        description = 'Force addon restrictions during combat.',
        type = 'boolean',
        default = false,
        category = 'dev',
    },
    {
        key = 'addonChatRestrictionsForced',
        label = 'Force Chat Addon Restrictions',
        description = 'Force addon restrictions for chat functionality.',
        type = 'boolean',
        default = false,
        category = 'dev',
    },
    {
        key = 'addonChallengeModeRestrictionsForced',
        label = 'Force M+ Addon Restrictions',
        description = 'Force addon restrictions during Mythic+ dungeons.',
        type = 'boolean',
        default = false,
        category = 'dev',
    },
    {
        key = 'tooltipShowAuraSpellIDs',
        label = 'Show Aura Spell IDs in Tooltip',
        description = 'Show the spell IDs of auras in the tooltip.',
        type = 'boolean',
        default = false,
        category = 'dev',
    }
}

---@type table
MiscVars.SQW_DEFS = {
    {
        key = 'SpellQueueWindowMelee',
        label = 'Melee SQW',
        description = 'Spell Queue Window value for melee specializations.',
        type = 'number',
        min = 1,
        max = 400,
        step = 1,
        default = 400,
        position = 'MELEE',
    },
    {
        key = 'SpellQueueWindowRanged',
        label = 'Ranged SQW',
        description = 'Spell Queue Window value for ranged specializations.',
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

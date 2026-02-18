-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@type NorskenUI
local NorskenUI = _G.NorskenUI

-- Check for addon object
if not NorskenUI then
    error("MiscVars: Addon object not initialized. Check file load order!")
    return
end

-- Create module
---@class MiscVars: AceModule, AceEvent-3.0
local MVAR = NorskenUI:NewModule("MiscVars", "AceEvent-3.0")

-- Localization Setup
local ipairs = ipairs
local C_CVar = C_CVar

-- Module variables
MVAR._suppressCVarUpdate = false

-- Cvar list
MVAR.DEFS = {
    {
        key = "nameplateUseClassColorForFriendlyPlayerUnitNames",
        label = "Class Colored Friendly Names",
        type = "boolean",
    },
    {
        key = "nameplateShowOnlyNameForFriendlyPlayerUnits",
        label = "Show Only Name (Friendly Players)",
        type = "boolean",
    },
    {
        key = "ResampleAlwaysSharpen",
        label = "Sharpen Game",
        type = "boolean",
    },
}

-- Module init
function MVAR:OnInitialize()
    self.db = NRSKNUI.db.profile.Miscellaneous.MiscVars
    self:SyncFromCVars()
    self:SetEnabledState(false)
end

-- Apply settings
local function ToCVarValue(value, cvarType)
    if cvarType == "boolean" then
        return value and 1 or 0
    end
    return value
end

local function FromCVarValue(value, cvarType)
    if cvarType == "boolean" then
        return value == "1"
    end
    return value
end

-- Settings application, called from GUI
function MVAR:ApplySettings()
    if not self.db.Enabled then return end

    for _, def in ipairs(self.DEFS) do
        local key = def.key
        local dbValue = self.db[key]
        local currentCVar = C_CVar.GetCVar(key)
        local currentValue = FromCVarValue(currentCVar, def.type)

        if dbValue == nil then
            self.db[key] = currentValue
        else
            -- Only set if different
            if dbValue ~= currentValue then
                C_CVar.SetCVar(key, ToCVarValue(dbValue, def.type))
            end
        end
    end
end

-- Sync current cvars with the addon
function MVAR:SyncFromCVars()
    for _, def in ipairs(self.DEFS) do
        local key = def.key
        local current = C_CVar.GetCVar(key)
        self.db[key] = FromCVarValue(current, def.type)
    end
end

-- Live sync with updates from external sources
function MVAR:CVAR_UPDATE(_, cvarName)
    for _, def in ipairs(self.DEFS) do
        if def.key == cvarName then
            local current = C_CVar.GetCVar(cvarName)
            self.db[cvarName] = FromCVarValue(current, def.type)
        end
    end

    -- Only refresh GUI if change came from outside addon
    if NRSKNUI.GUIFrame and not self._suppressCVarUpdate then
        NRSKNUI.GUIFrame:RefreshContent()
    end
end

-- Module OnEnable
function MVAR:OnEnable()
    if not self.db.Enabled then return end

    self:RegisterEvent("CVAR_UPDATE")

    C_Timer.After(1, function()
        self:ApplySettings()
    end)
end

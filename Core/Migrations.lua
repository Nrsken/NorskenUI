---@class NRSKNUI
local NRSKNUI = _G.NorskenUI

local CopyTable = CopyTable
local ipairs = ipairs
local pairs = pairs

-- moved from global to profile scope
local SCOPE_MOVED_KEYS = { 'Theme', 'UIScale', 'AuraIndicators', 'AuraIndicatorGroups' }

---@param db NRSKNUI.DBObject
local function RunProfileScopeMigration(db)
    if db.global.ProfileScopeMigrated then return end

    for _, key in ipairs(SCOPE_MOVED_KEYS) do
        local old = db.global[key]
        -- overwrite, never skip: AceDB already seeded the active profile with the new defaults
        if old ~= nil then
            for _, profile in pairs(db.profiles) do
                profile[key] = CopyTable(old)
            end
            db.global[key] = nil
        end
    end

    db.global.ProfileScopeMigrated = true
end

---@param db NRSKNUI.DBObject
local function RunLoadEnableMigration(db)
    if db.global.LoadEnableDropped then return end

    -- the raw save, so namespaces and profiles other than the active one come along
    NRSKNUI.LoadConditions:DropEnableToggle(db.sv)
    db.global.LoadEnableDropped = true
end

---@param db NRSKNUI.DBObject
local function RunLoadCombatMigration(db)
    if db.global.LoadCombatMoved then return end

    NRSKNUI.LoadConditions:MoveCombatToState(db.sv)
    db.global.LoadCombatMoved = true
end

---Old layouts, fixed right after AceDB loads and before any module takes its namespace.
---@param db NRSKNUI.DBObject
function NRSKNUI:UpgradeSavedProfiles(db)
    RunProfileScopeMigration(db)
    RunLoadEnableMigration(db)
    RunLoadCombatMigration(db)
end

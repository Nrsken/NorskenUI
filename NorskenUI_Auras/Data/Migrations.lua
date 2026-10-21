---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

--[[
The old Auras module's trackers, carried into the Cooldown & Aura Manager once per profile.
One-off for profiles from v12.1.0.4-.8

TODO: delete this file and its call in UpdateDB a release or two after the CDM ships.
]]

local ipairs, pairs, next = ipairs, pairs, next
local CopyTable = CopyTable
local type = type

---@param into table
---@param from table
---@return table into
local function Merge(into, from)
    for key, value in pairs(from) do
        if type(value) == 'table' and type(into[key]) == 'table' then
            Merge(into[key], value)
        elseif type(value) == 'table' then
            into[key] = CopyTable(value)
        else
            into[key] = value
        end
    end

    return into
end

---@param name string
---@param look table? its Icon and Strata
---@return string id
local function NewFolder(name, look)
    local id = CDM:CreateGroup(name, false) --[[@as string]]
    local folder = CDM:Get(id) --[[@as table]]
    folder.Icon, folder.Strata = look and look.Icon, look and look.Strata
    return id
end

---The old trackers as aura groups and their folders as Groups; false when the profile has none.
---@param db table profile.CDM
---@return boolean imported
function CDM:ImportOldTrackers(db)
    local profile = NRSKNUI.db.profile --[[@as table]] -- old saved data, no longer in the defaults
    local trackers = profile.AuraDisplays
    if not (type(trackers) == 'table' and next(trackers)) then return false end

    -- The old folders become Groups, with General always there for the built-ins.
    local groups = {}
    for key, saved in pairs(profile.AuraDisplayGroups or {}) do
        local folder = Merge(key == 'group:general' and CopyTable(CDM.BUILTIN_FOLDER) or {}, saved)
        groups[key] = NewFolder(folder.name or key, folder)
    end
    groups['group:general'] = groups['group:general'] or NewFolder(CDM.BUILTIN_FOLDER.name, CDM.BUILTIN_FOLDER)

    local anyEnabled = false
    local function Add(display, groupKey)
        display.type, display.group = 'auragroup', nil
        display.parent = groupKey and groups[groupKey] or nil
        display.Load = display.Load or NRSKNUI.LoadConditions:GetDefaults()
        if display.parent and (display.anchorFrameType or 'UIPARENT') == 'UIPARENT' then
            -- Inside a static group a screen anchor means the group's frame; a picked UIParent keeps it where it was.
            display.anchorFrameType, display.ParentFrame = 'SELECTFRAME', 'UIParent'
        end
        anyEnabled = anyEnabled or display.Enabled == true
        db.Displays[self:NextId()] = display
    end

    -- A profile with its own General Buffs tracker keeps that one rather than gaining the newer built-in beside it.
    local ownNames = {}
    for key, tracker in pairs(trackers) do
        if not CDM.BUILTIN_AURA_GROUPS[key] then
            ownNames[tracker.name or key] = true
        end
    end

    -- Built-ins were saved as changes to their shipped look, which the templates still hold.
    for _, builtin in ipairs(CDM.BUILTIN_AURA_GROUPS) do
        local saved = trackers[builtin.key] or {}
        if not (builtin.key == 'builtin:generalBuffs' and ownNames[saved.name or builtin.display.name]) then
            local display = self:NewBuiltinAuraGroup(builtin.key) --[[@as table]]
            local changes = CopyTable(saved)
            local trigger = changes.Trigger
            changes.Trigger, changes.group = nil, nil
            Merge(display, changes)
            if trigger and trigger.Type and trigger.branches then
                display.Trigger = trigger
            elseif trigger then -- a pre-rework save holding only its added and switched-off spells
                display.Trigger = NRSKNUI.AuraTriggers:ToAuraFilter({
                    Type = NRSKNUI.AuraTriggers.Types.Preset, Preset = builtin.preset, Unit = 'player', Added = trigger.Added, Removed = trigger.Removed,
                })
            end

            local group = saved.group
            if group == nil then -- never moved; false means it was moved out to the top level
                group = 'group:general'
            end
            Add(display, group or nil)
        end
    end

    -- The user's own trackers come over as they are.
    for key, tracker in pairs(trackers) do
        if not CDM.BUILTIN_AURA_GROUPS[key] then
            Add(CopyTable(tracker), tracker.group)
        end
    end

    if anyEnabled then
        db.Enabled = true
    end
    return true
end

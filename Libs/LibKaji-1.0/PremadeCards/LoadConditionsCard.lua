--[[
# LoadConditionsCard

* Premade card for a module's load conditions:
* an enable toggle plus a compact category selector (Instance / Group / Combat / Role / Position), each category showing its own set of checkboxes.
* Toggling enable or switching category changes the visible rows, so the card rebuilds in place (no full page refresh).

## Examples

    page:LoadConditionsCard({
        db = db.LoadConditions,
        onChangeCallback = Apply,
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end

lib.premadeCards = lib.premadeCards or {}

local ipairs = ipairs
local pairs = pairs
local sformat = string.format
local C_Timer = C_Timer

local INSTANCE_TYPES = {
    { key = "none",     label = "Open World" },
    { key = "party",    label = "Dungeon" },
    { key = "raid",     label = "Raid" },
    { key = "pvp",      label = "Battleground" },
    { key = "arena",    label = "Arena" },
    { key = "scenario", label = "Scenario" },
}

local GROUP_TYPES = {
    { key = "solo",  label = "Solo" },
    { key = "party", label = "Party" },
    { key = "raid",  label = "Raid" },
}

local COMBAT_OPTIONS = {
    { key = "InCombat",    label = "In Combat" },
    { key = "OutOfCombat", label = "Out of Combat" },
}

local ROLE_TYPES = {
    { key = "TANK",    label = "Tank" },
    { key = "HEALER",  label = "Healer" },
    { key = "DAMAGER", label = "DPS" },
}

local POSITION_TYPES = {
    { key = "MELEE",  label = "Melee" },
    { key = "RANGED", label = "Ranged" },
}

-- Category -> the simple checkbox list rendered under it.
local SIMPLE_CATEGORIES = {
    Group = { db = "Group", nested = "Types", list = GROUP_TYPES },
    Role = { db = "Role", nested = "Types", list = ROLE_TYPES },
    Position = { db = "Position", nested = "Types", list = POSITION_TYPES },
    Combat = { db = "Combat", list = COMBAT_OPTIONS },
}

local GREEN = { 0, 1, 0 }
local RED = { 1, 0, 0 }

local function HasAnyEnabled(tbl)
    if not tbl then return false end
    for _, enabled in pairs(tbl) do
        if enabled then return true end
    end
    return false
end

local function IsCategoryActive(db, category)
    if category == "Instance" then
        return HasAnyEnabled(db.Instance and db.Instance.Types)
    elseif category == "Group" then
        return HasAnyEnabled(db.Group and db.Group.Types)
    elseif category == "Combat" then
        return (db.Combat and db.Combat.InCombat) or (db.Combat and db.Combat.OutOfCombat)
    elseif category == "Role" then
        return HasAnyEnabled(db.Role and db.Role.Types)
    elseif category == "Position" then
        return HasAnyEnabled(db.Position and db.Position.Types)
    end
    return false
end

local function GetActiveCount(db)
    local count = 0
    if IsCategoryActive(db, "Instance") then count = count + 1 end
    if IsCategoryActive(db, "Group") then count = count + 1 end
    if IsCategoryActive(db, "Combat") then count = count + 1 end
    if IsCategoryActive(db, "Role") then count = count + 1 end
    if IsCategoryActive(db, "Position") then count = count + 1 end
    return count
end

local function BuildCategoryOptions(db)
    return {
        { key = "Instance", text = "Instance", indicator = IsCategoryActive(db, "Instance") and GREEN or RED },
        { key = "Group",    text = "Group",    indicator = IsCategoryActive(db, "Group") and GREEN or RED },
        { key = "Combat",   text = "Combat",   indicator = IsCategoryActive(db, "Combat") and GREEN or RED },
        { key = "Role",     text = "Role",     indicator = IsCategoryActive(db, "Role") and GREEN or RED },
        { key = "Position", text = "Position", indicator = IsCategoryActive(db, "Position") and GREEN or RED },
    }
end

---Load conditions card with a compact category selector.
lib.premadeCards.LoadConditionsCard = {
    title = "Load Conditions",

    ---@param card KajiGUIFluentCard
    ---@param config table
    ---@param gui KajiGUIInstance
    build = function(card, config, gui)
        local theme = gui.theme
        local db = config.db
        local onChange = config.onChangeCallback

        db.Enabled = db.Enabled or false
        db.SelectedCategory = db.SelectedCategory or "Instance"
        db.Instance = db.Instance or { Types = {} }
        db.Group = db.Group or { Types = {} }
        db.Combat = db.Combat or {}
        db.Role = db.Role or { Types = {} }
        db.Position = db.Position or { Types = {} }

        local function fireChange()
            if onChange then onChange() end
        end

        -- Both the enable toggle and every option checkbox rebuild the card, and they fire
        -- from inside their own click handler. Rebuild hides/reparents the row that owns the
        -- clicked widget, so defer it off the current call stack (one frame). The guard lives
        -- on the card so a rebuild scheduled by the outgoing build cannot double up.
        local function ScheduleRebuild()
            if card._rebuildPending then return end
            card._rebuildPending = true
            C_Timer.After(0, function()
                card._rebuildPending = false
                card:Rebuild()
            end)
        end

        -- Emits one or two checkboxes for { key, label } entries bound to a target table.
        local function AddCheckRow(target, entry1, entry2, isLast)
            local height = isLast and theme.rowHeightLast or theme.rowHeight
            local row = card:Row(height, isLast and 0 or nil)

            row:Checkbox(entry1.label, {
                width = entry2 and 0.5 or 1,
                value = target[entry1.key] == true,
                callback = function(checked)
                    target[entry1.key] = checked or nil
                    fireChange()
                    ScheduleRebuild()
                end,
            })

            if entry2 then
                row:Checkbox(entry2.label, {
                    width = 0.5,
                    value = target[entry2.key] == true,
                    callback = function(checked)
                        target[entry2.key] = checked or nil
                        fireChange()
                        ScheduleRebuild()
                    end,
                })
            end
        end

        local isEnabled = db.Enabled
        local selectedCategory = db.SelectedCategory

        -- Main row: Enable toggle (+ active count) + Category dropdown.
        local mainHeight = isEnabled and theme.rowHeight or theme.rowHeightLast
        local mainRow = card:Row(mainHeight, not isEnabled and 0 or nil)

        local activeCount = GetActiveCount(db)
        local accentHex = sformat("%02x%02x%02x", theme.accent[1] * 255, theme.accent[2] * 255, theme.accent[3] * 255)
        local enableLabel = activeCount > 0 and ("Enable |cff" .. accentHex .. "(" .. activeCount .. " active)|r") or
            "Enable"

        mainRow:Checkbox(enableLabel, {
            width = 0.5,
            value = isEnabled,
            callback = function(checked)
                db.Enabled = checked
                fireChange()
                ScheduleRebuild()
            end,
        })

        if isEnabled then
            mainRow:Dropdown("Category", {
                width = 0.5,
                options = BuildCategoryOptions(db),
                value = selectedCategory,
                callback = function(value)
                    db.SelectedCategory = value
                    ScheduleRebuild()
                end,
            })
        end

        if not isEnabled then return end

        card:Separator()

        if selectedCategory == "Instance" then
            local instanceDb = db.Instance
            instanceDb.Types = instanceDb.Types or {}
            for i = 1, #INSTANCE_TYPES, 2 do
                local isLastRow = i + 1 >= #INSTANCE_TYPES
                AddCheckRow(instanceDb.Types, INSTANCE_TYPES[i], INSTANCE_TYPES[i + 1], isLastRow)
            end
        else
            local cat = SIMPLE_CATEGORIES[selectedCategory]
            if cat then
                local target = db[cat.db]
                if cat.nested then
                    target[cat.nested] = target[cat.nested] or {}
                    target = target[cat.nested]
                end
                for i, entry in ipairs(cat.list) do
                    AddCheckRow(target, entry, nil, i == #cat.list)
                end
            end
        end
    end,
}

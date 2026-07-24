--[[
# LoadConditionsCard

* Premade card for a module's load conditions:
* an enable toggle plus a compact category selector (Instance / Group / Combat / Role / Position), each category showing its own set of checkboxes.
* Toggling enable or switching category changes the visible rows, so the card body rebuilds in place (no full page refresh).

## Examples

    page:LoadConditionsCard({
        db = db.LoadConditions,
        onChangeCallback = Apply,
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin

local ipairs = ipairs
local pairs = pairs
local wipe = wipe
local tinsert = table.insert
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
---@param scrollChild Frame
---@param yOffset number
---@param config table
---@return KajiGUICard card
---@return number newYOffset
---@return Frame[] widgets
function InstanceMixin:CreateLoadConditionsCard(scrollChild, yOffset, config)
    config = config or {}
    local gui = self
    local theme = self.theme

    local title = config.title or "Load Conditions"
    local db = config.db
    local onChange = config.onChangeCallback

    db.Enabled = db.Enabled or false
    db.SelectedCategory = db.SelectedCategory or "Instance"
    db.Instance = db.Instance or { Types = {} }
    db.Group = db.Group or { Types = {} }
    db.Combat = db.Combat or {}
    db.Role = db.Role or { Types = {} }
    db.Position = db.Position or { Types = {} }

    local widgets = {}
    local card = gui:CreateCard(scrollChild, title, yOffset)

    local function fireChange()
        if onChange then onChange() end
    end

    -- Forward-declared: assigned below, referenced by the checkbox callbacks here.
    local ScheduleRebuild

    -- Emits a checkbox for a { key, label } entry bound to a target table.
    local function AddCheckRow(target, entry1, entry2, isLast)
        local height = isLast and theme.rowHeightLast or theme.rowHeight
        local row = gui:CreateRow(card.content, height)

        local check1 = gui:CreateCheckbox(row, entry1.label, {
            value = target[entry1.key] == true,
            callback = function(checked)
                target[entry1.key] = checked or nil
                fireChange()
                ScheduleRebuild()
            end
        })
        row:AddWidget(check1, entry2 and 0.5 or 1)
        tinsert(widgets, check1)

        if entry2 then
            local check2 = gui:CreateCheckbox(row, entry2.label, {
                value = target[entry2.key] == true,
                callback = function(checked)
                    target[entry2.key] = checked or nil
                    fireChange()
                    ScheduleRebuild()
                end
            })
            row:AddWidget(check2, 0.5)
            tinsert(widgets, check2)
        end

        card:AddRow(row, height, isLast and 0 or nil)
    end

    local BuildContent
    -- Rebuilds the whole card body (enable toggle changed, or category switched).
    local function RebuildContent()
        if card._onBeforeRebuild then card._onBeforeRebuild(widgets) end
        wipe(widgets)
        card:Reset()
        BuildContent()
        if card._onAfterRebuild then card._onAfterRebuild(widgets) end
    end

    -- Both the enable toggle and every option checkbox trigger a rebuild, and they fire
    -- from inside their own click handler. Reset() hides/reparents the row that owns the
    -- clicked widget, so defer the rebuild off the current call stack (one frame).
    local rebuildPending = false
    ScheduleRebuild = function()
        if rebuildPending then return end
        rebuildPending = true
        C_Timer.After(0, function()
            rebuildPending = false
            RebuildContent()
        end)
    end

    BuildContent = function()
        local isEnabled = db.Enabled
        local selectedCategory = db.SelectedCategory

        -- Main row: Enable toggle (+ active count) + Category dropdown.
        local mainHeight = isEnabled and theme.rowHeight or theme.rowHeightLast
        local mainRow = gui:CreateRow(card.content, mainHeight)

        local activeCount = GetActiveCount(db)
        local accentHex = sformat("%02x%02x%02x", theme.accent[1] * 255, theme.accent[2] * 255, theme.accent[3] * 255)
        local enableLabel = activeCount > 0 and ("Enable |cff" .. accentHex .. "(" .. activeCount .. " active)|r") or
            "Enable"
        local enableToggle = gui:CreateCheckbox(mainRow, enableLabel, {
            value = isEnabled,
            callback = function(checked)
                db.Enabled = checked
                fireChange()
                ScheduleRebuild()
            end
        })
        mainRow:AddWidget(enableToggle, 0.5)
        tinsert(widgets, enableToggle)

        if isEnabled then
            local categoryDropdown = gui:CreateDropdown(mainRow, "Category", {
                options = BuildCategoryOptions(db),
                value = selectedCategory,
                callback = function(value)
                    db.SelectedCategory = value
                    ScheduleRebuild()
                end
            })
            mainRow:AddWidget(categoryDropdown, 0.5)
            tinsert(widgets, categoryDropdown)
        end
        card:AddRow(mainRow, mainHeight, not isEnabled and 0 or nil)

        if not isEnabled then return end

        card:AddRow(gui:CreateSeparator(card.content), theme.rowHeightSeparator)

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
    end

    BuildContent()

    card.conditionWidgets = widgets
    card._hasInternalWidgetState = true

    function card:SetEnabled(enabled)
        local alpha = enabled and 1 or 0.5
        self:SetAlpha(alpha)
        if self.header then self.header:SetAlpha(alpha) end
        if self.titleText then self.titleText:SetAlpha(alpha) end
        for _, widget in ipairs(self.conditionWidgets) do
            if widget.SetEnabled then widget:SetEnabled(enabled) end
        end
    end

    return card, card:GetNextOffset(), widgets
end

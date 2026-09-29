--[[
# LoadConditionsCard

* Premade card for a module's load conditions:
* an enable toggle plus a compact category selector (Instance / Group / Combat / Role / Position / Zone), each category showing its own set of checkboxes.
* Zone takes a map ID list (g/c/i prefixes, - to leave one out); its tooltip lists this season's instances and where you stand.
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
local tostring = tostring
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
    elseif category == "Zone" then
        return db.Zone ~= nil and db.Zone.MapIDs ~= nil and db.Zone.MapIDs:find("%d") ~= nil
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
    if IsCategoryActive(db, "Zone") then count = count + 1 end
    return count
end

---Appends a plain map ID unless that exact entry is already there, a g486 or c486 is a different entry.
---@param text string
---@param mapID number
---@return string
local function AddMapID(text, mapID)
    local entry = tostring(mapID)
    for token in text:gmatch("[^,%s]+") do
        if token == entry then return text end
    end
    return text:find("%d") and (text .. ", " .. entry) or entry
end

-- Zone tooltip --

local ZONE_SYNTAX = {
    { "2393", "A map" },
    { "g486", "Every floor of a map group" },
    { "c2395", "A map and every map inside it" },
    { "i2912", "An instance" },
    { "-2393", "Leave a map out, works with any prefix" },
}

local seasonZones ---@type { title: string, zones: { name: string, id: string }[] }[]?

---A map group covers every floor of a dungeon, so it is the entry worth suggesting.
---@param mapID number
---@return string
local function ZoneEntry(mapID)
    local groupID = C_Map.GetMapGroupID(mapID)
    return groupID and ("g" .. groupID) or tostring(mapID)
end

---The current tier's dungeons and raids from the Encounter Journal, kept once both sections came back filled.
---@return { title: string, zones: { name: string, id: string }[] }[]
local function GetSeasonZones()
    if seasonZones then return seasonZones end
    local sections, complete = {}, true

    -- Selecting a tier is shared journal state, so the one the player had open is put back after.
    local previousTier = EJ_GetCurrentTier()
    EJ_SelectTier(EJ_GetNumTiers())
    for _, isRaid in ipairs({ false, true }) do
        local section = { title = isRaid and "Current Season Raids" or "Current Season Dungeons", zones = {} }
        local index = 1
        local instanceID = EJ_GetInstanceByIndex(index, isRaid)
        while instanceID do
            -- A dungeon reports map 0 until it is the selected instance, raids answer either way.
            EJ_SelectInstance(instanceID)
            local name, _, _, _, _, _, mapID = EJ_GetInstanceInfo(instanceID)
            if name and mapID and mapID ~= 0 then
                section.zones[#section.zones + 1] = { name = name, id = ZoneEntry(mapID) }
            end
            index = index + 1
            instanceID = EJ_GetInstanceByIndex(index, isRaid)
        end
        if #section.zones > 0 then
            sections[#sections + 1] = section
        else
            complete = false
        end
    end
    if previousTier then EJ_SelectTier(previousTier) end

    if complete then seasonZones = sections end
    return sections
end

---Built on every hover, so the current zone is always the one the player stands in.
---@param tooltip GameTooltip
---@param theme table
local function FillZoneTooltip(tooltip, theme)
    local accent, text, muted = theme.accent, theme.textPrimary, theme.textSecondary
    local function Header(title)
        tooltip:AddLine(" ")
        tooltip:AddLine(title, accent[1], accent[2], accent[3])
    end
    local function Entry(name, id)
        tooltip:AddDoubleLine(name, id, text[1], text[2], text[3], muted[1], muted[2], muted[3])
    end

    tooltip:SetText("Map IDs", accent[1], accent[2], accent[3])

    for _, section in ipairs(GetSeasonZones()) do
        Header(section.title)
        for _, zone in ipairs(section.zones) do Entry(zone.name, zone.id) end
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    local mapInfo = mapID and C_Map.GetMapInfo(mapID)
    if mapID and mapInfo then
        Header("Current Zone")
        Entry(mapInfo.name, tostring(mapID))
        local groupID = C_Map.GetMapGroupID(mapID)
        if groupID then Entry("All floors", "g" .. groupID) end

        local parentInfo = mapInfo.parentMapID and mapInfo.parentMapID > 0 and C_Map.GetMapInfo(mapInfo.parentMapID)
        if parentInfo then
            Header("Parent Zone")
            Entry(parentInfo.name, "c" .. mapInfo.parentMapID)
        end
    end

    local instanceName, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceID and instanceID > 0 then
        Header("Current Instance")
        Entry(instanceName, "i" .. instanceID)
    end

    Header("How To Write Them")
    tooltip:AddLine("Separate entries with commas.", muted[1], muted[2], muted[3], true)
    for _, syntax in ipairs(ZONE_SYNTAX) do
        tooltip:AddDoubleLine(syntax[1], syntax[2], text[1], text[2], text[3], muted[1], muted[2], muted[3])
    end
end

---A category only marks itself when it carries conditions.
local function BuildCategoryOptions(db)
    return {
        { key = "Instance", text = "Instance", indicator = IsCategoryActive(db, "Instance") and GREEN or nil },
        { key = "Group",    text = "Group",    indicator = IsCategoryActive(db, "Group") and GREEN or nil },
        { key = "Combat",   text = "Combat",   indicator = IsCategoryActive(db, "Combat") and GREEN or nil },
        { key = "Role",     text = "Role",     indicator = IsCategoryActive(db, "Role") and GREEN or nil },
        { key = "Position", text = "Position", indicator = IsCategoryActive(db, "Position") and GREEN or nil },
        { key = "Zone",     text = "Zone",     indicator = IsCategoryActive(db, "Zone") and GREEN or nil },
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
        db.Zone = db.Zone or {}

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
        elseif selectedCategory == "Zone" then
            local zoneDb = db.Zone
            card:Row(theme.rowHeight):EditBox("Map IDs", {
                width = 1,
                value = zoneDb.MapIDs or "",
                tooltip = function(tooltip) FillZoneTooltip(tooltip, theme) end,
                callback = function(text)
                    zoneDb.MapIDs = text
                    fireChange()
                    ScheduleRebuild()
                end,
            })

            local mapID = C_Map.GetBestMapForUnit("player")
            local mapInfo = mapID and C_Map.GetMapInfo(mapID)
            if mapID and mapInfo then
                card:Row(24):Button(sformat("Add Current Zone: %s (%d)", mapInfo.name, mapID), {
                    width = 1,
                    callback = function()
                        zoneDb.MapIDs = AddMapID(zoneDb.MapIDs or "", mapID)
                        fireChange()
                        ScheduleRebuild()
                    end,
                })
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

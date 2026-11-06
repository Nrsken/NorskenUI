---@class NRSKNUI
local NRSKNUI = select(2, ...)

--TODO: Add: item equipped, player level

local select = select
local tonumber = tonumber
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local wipe, next = wipe, next
local CreateFrame = CreateFrame
local IsInInstance = IsInInstance
local IsMounted = IsMounted
local IsResting = IsResting
local IsPlayerMoving = IsPlayerMoving
local UnitRace = UnitRace
local UnitExists = UnitExists
local UnitIsDead = UnitIsDead
local UnitIsPVP = UnitIsPVP
local UnitOnTaxi = UnitOnTaxi
local UnitInVehicle = UnitInVehicle
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local HasOverrideActionBar = HasOverrideActionBar
local HasVehicleActionBar = HasVehicleActionBar
local IsEncounterInProgress = IsEncounterInProgress
local UnitAffectingCombat = UnitAffectingCombat
local ipairs, pairs = ipairs, pairs
local type = type
local After = C_Timer.After
local GetInstanceInfo = GetInstanceInfo

local GetSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
local GetSpecializationInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
local GetActiveConfigID = C_ClassTalents and C_ClassTalents.GetActiveConfigID
local GetConfigInfo = C_Traits and C_Traits.GetConfigInfo
local GetTreeNodes = C_Traits and C_Traits.GetTreeNodes
local GetNodeInfo = C_Traits and C_Traits.GetNodeInfo
local GetSubTreeInfo = C_Traits and C_Traits.GetSubTreeInfo
local GetBestMapForUnit = C_Map and C_Map.GetBestMapForUnit
local GetMapGroupID = C_Map and C_Map.GetMapGroupID
local GetMapChildrenInfo = C_Map and C_Map.GetMapChildrenInfo
local IsSpellKnownOrInSpellBook = C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook
local IsInPetBattle = C_PetBattles and C_PetBattles.IsInBattle
local IsWarModeActive = C_PvP and C_PvP.IsWarModeActive
local GetGlidingInfo = C_PlayerInfo and C_PlayerInfo.GetGlidingInfo

local PET_SPELLS = Enum.SpellBookSpellBank.Pet

---@class LoadConditions
local LoadConditions = {}
NRSKNUI.LoadConditions = LoadConditions

local callbacks = {}
local stateCallbacks = {}
local eventFrame = nil

local function HasAnyEnabled(tbl)
    if not tbl then return false end
    for _, enabled in pairs(tbl) do
        if enabled then return true end
    end
    return false
end

-- Events only one condition cares about start once a load table asks for it, so nothing listens for what isn't used.
local watchedSets = {}

---@param events table<string, true|string> each event to true or the unit it's registered for
local function Watch(events)
    if not eventFrame or watchedSets[events] then return end

    watchedSets[events] = true
    for event, unit in pairs(events) do
        if unit == true then
            eventFrame:RegisterEvent(event)
        else
            eventFrame:RegisterUnitEvent(event, unit)
        end
    end
end

-- Instance condition
local function CheckInstance(config)
    if not config or not config.Types then return true end
    if not HasAnyEnabled(config.Types) then return true end

    local _, instanceType = IsInInstance()
    instanceType = instanceType or "none"

    if not config.Types[instanceType] then return false end

    return true
end

-- Difficulty condition: any picked difficultyID, none picked means any.
-- Starting a key turns the dungeon's difficulty into Mythic Keystone without a zone change.
local DIFFICULTY_EVENTS = { PLAYER_DIFFICULTY_CHANGED = true, CHALLENGE_MODE_START = true, CHALLENGE_MODE_COMPLETED = true }

local function CheckDifficulty(config)
    if not config or not config.Types or not HasAnyEnabled(config.Types) then return true end

    Watch(DIFFICULTY_EVENTS)
    local _, _, difficultyID = GetInstanceInfo()
    return config.Types[difficultyID] == true
end

-- Group condition
local function CheckGroup(config)
    if not config or not config.Types then return true end
    if not HasAnyEnabled(config.Types) then return true end

    local inGroup = IsInGroup()
    local inRaid = IsInRaid()

    local groupType
    if not inGroup then
        groupType = "solo"
    elseif inRaid then
        groupType = "raid"
    else
        groupType = "party"
    end

    if not config.Types[groupType] then return false end

    return true
end

-- Combat state
-- Read from the REGEN event our own frame gets: NRSKNUI:InCombat()'s flag is set by another frame's handler for
-- the same event, which may run after ours; InCombatLockdown() can still read false on PLAYER_REGEN_DISABLED.
local inCombat = false

local function InCombat()
    if eventFrame then
        return inCombat
    end
    return NRSKNUI:InCombat() -- nothing has registered yet, so no events are tracked
end

-- Check Role condition
local function CheckRole(config)
    if not config or not config.Types then return true end
    if not HasAnyEnabled(config.Types) then return true end
    if not NRSKNUI.MySpec.role then return true end

    if not config.Types[NRSKNUI.MySpec.role] then return false end

    return true
end

-- Check Position condition
local function CheckPosition(config)
    if not config or not config.Types then return true end
    if not HasAnyEnabled(config.Types) then return true end
    if not NRSKNUI.MySpec.position then return true end

    if not config.Types[NRSKNUI.MySpec.position] then return false end

    return true
end

-- Zone condition: comma separated uiMapIDs, g = map group, c = map plus its children, i = instance, - leaves one out.
local zoneSets = {} ---@type table<string, table> parsed per MapIDs string

---@param text string
---@return table
local function ParseZones(text)
    local zones = {
        include = { maps = {}, groups = {}, instances = {} },
        exclude = { maps = {}, groups = {}, instances = {} },
    }
    for negate, prefix, id in text:gmatch("(%-?)(%a?)(%d+)") do
        id = tonumber(id)
        prefix = prefix:lower()
        local sets = negate == "-" and zones.exclude or zones.include
        if prefix == "g" then
            sets.groups[id] = true
        elseif prefix == "i" then
            sets.instances[id] = true
        elseif prefix == "" or prefix == "c" then
            sets.maps[id] = true
            if prefix == "c" then
                for _, child in ipairs(GetMapChildrenInfo(id, nil, true) or {}) do
                    sets.maps[child.mapID] = true
                end
            end
        end
        if negate ~= "-" and (prefix == "" or prefix == "c" or prefix == "g" or prefix == "i") then zones.hasInclude = true end
    end
    return zones
end

---@param sets table
---@param mapID number?
---@param groupID number?
---@param instanceID number?
---@return boolean
local function InZones(sets, mapID, groupID, instanceID)
    return (mapID and sets.maps[mapID]) or (groupID and sets.groups[groupID]) or (instanceID and sets.instances[instanceID]) or false
end

local function CheckZone(config)
    local text = config and config.MapIDs
    if not text then return true end

    local zones = zoneSets[text]
    if not zones then
        zones = ParseZones(text)
        zoneSets[text] = zones
    end

    local mapID = GetBestMapForUnit("player")
    local groupID = mapID and GetMapGroupID(mapID)
    local instanceID = select(8, GetInstanceInfo())
    if InZones(zones.exclude, mapID, groupID, instanceID) then return false end
    return not zones.hasInclude or InZones(zones.include, mapID, groupID, instanceID)
end

---@return number? specID
local function PlayerSpecID()
    local index = GetSpecialization()
    return index and GetSpecializationInfo(index) or nil
end

-- Spec condition: any picked specID; none picked means any spec.
local function CheckSpec(config)
    if not config or not config.Types or not HasAnyEnabled(config.Types) then return true end
    local specID = PlayerSpecID()
    return specID ~= nil and config.Types[specID] == true
end

-- Talents the player has taken, by C_Traits entryID; rebuilt when talents or the spec change.
local takenTalents = {}
local talentsDirty = true

local function RebuildTalents()
    talentsDirty = false
    wipe(takenTalents)
    local configID = GetActiveConfigID()
    local config = configID and GetConfigInfo(configID)
    if not config then return end

    for _, treeID in ipairs(config.treeIDs) do
        for _, nodeID in ipairs(GetTreeNodes(treeID)) do
            local node = GetNodeInfo(configID, nodeID)
            if node and node.ID ~= 0 then
                local heroInactive = node.subTreeID and not (GetSubTreeInfo(configID, node.subTreeID) or {}).isActive
                for _, entryID in ipairs(node.entryIDs) do
                    local rank = node.activeRank
                    if node.activeEntry then rank = node.activeEntry.entryID == entryID and node.activeEntry.rank or 0 end
                    if rank > 0 and not heroInactive then takenTalents[entryID] = true end
                end
            end
        end
    end
end

---@param config table
---@return number? specID the one spec picked, which talents need
local function SingleSpec(config)
    local single
    for specID, enabled in pairs(config and config.Types or {}) do
        if enabled then
            if single then return nil end
            single = specID
        end
    end
    return single
end

-- Talent condition, per spec: only with exactly one spec picked and active; true = must have, false = must not.
local function CheckTalent(config, conditions)
    local spec = SingleSpec(conditions.Spec)
    local entries = spec and config and config.Specs and config.Specs[spec]
    if not entries or next(entries) == nil or spec ~= PlayerSpecID() then return true end

    if talentsDirty then RebuildTalents() end
    for entryID, wanted in pairs(entries) do
        if (takenTalents[entryID] == true) ~= wanted then return false end
    end
    return true
end

-- Race condition: any picked race, keyed by UnitRace's file name; none picked means any race.
local function CheckRace(config)
    if not config or not config.Types or not HasAnyEnabled(config.Types) then return true end
    local _, race = UnitRace("player")
    return config.Types[race] == true
end

-- Spell condition: the player's or the pet's spellbook, overrides included; answers are kept so an event can tell what changed.
local knownSpells = {} ---@type table<number, boolean>
local SPELL_EVENTS = { SPELLS_CHANGED = true, UNIT_PET = "player" }

---@param spellID number
---@return boolean
local function ReadKnown(spellID)
    return IsSpellKnownOrInSpellBook(spellID) or IsSpellKnownOrInSpellBook(spellID, PET_SPELLS)
end

---@param spellID number
---@return boolean
local function IsKnown(spellID)
    Watch(SPELL_EVENTS)
    local known = ReadKnown(spellID)
    knownSpells[spellID] = known
    return known
end

---@return boolean changed
local function SpellsChanged()
    local changed = false
    for spellID, known in pairs(knownSpells) do
        if ReadKnown(spellID) ~= known then
            changed = true
        end
    end
    return changed
end

local function CheckSpells(config)
    if config.Known and not IsKnown(config.Known) then return false end
    if config.NotKnown and IsKnown(config.NotKnown) then return false end
    return true
end

-- State condition: true = must be, false = must not be, unset leaves it out. Load and the Conditions trigger list these in order.
local inEncounter = false

local STATES = {
    { key = "Always", label = "Always Active", read = function() return true end, triggerOnly = true },
    { key = "InCombat", label = "In Combat", read = InCombat },
    { key = "InEncounter", label = "In Encounter", read = function() return inEncounter end },
    {
        key = "Alive",
        label = "Alive",
        read = function() return not UnitIsDeadOrGhost("player") end,
        events = { PLAYER_DEAD = true, PLAYER_ALIVE = true, PLAYER_UNGHOST = true },
    },
    { key = "WarMode", label = "In War Mode", read = IsWarModeActive, events = { PLAYER_FLAGS_CHANGED = "player" } },
    {
        key = "InPetBattle",
        label = "In Pet Battle",
        read = IsInPetBattle,
        events = { PET_BATTLE_OPENING_START = true, PET_BATTLE_CLOSE = true },
    },
    {
        key = "InVehicle",
        label = "In Vehicle",
        read = function() return UnitInVehicle("player") end,
        events = { UNIT_ENTERED_VEHICLE = "player", UNIT_EXITED_VEHICLE = "player" },
    },
    {
        key = "VehicleUI",
        label = "Has Vehicle UI",
        read = function() return UnitHasVehicleUI("player") or HasOverrideActionBar() or HasVehicleActionBar() end,
        events = { VEHICLE_UPDATE = true, UPDATE_VEHICLE_ACTIONBAR = true, UPDATE_OVERRIDE_ACTIONBAR = true },
    },
    {
        -- the control events are for taxis, UnitOnTaxi has no event of its own
        key = "Skyriding",
        label = "Skyriding",
        read = function()
            local _, canGlide = GetGlidingInfo()
            return canGlide and not UnitOnTaxi("player")
        end,
        events = { PLAYER_CAN_GLIDE_CHANGED = true, PLAYER_CONTROL_LOST = true, PLAYER_CONTROL_GAINED = true },
    },
    { key = "Mounted", label = "Mounted", read = IsMounted, events = { PLAYER_MOUNT_DISPLAY_CHANGED = true } },
    {
        key = "Restricted",
        label = "Secret Restrictions Active",
        read = function() return NRSKNUI:IsRestricted() end,
        events = { ADDON_RESTRICTION_STATE_CHANGED = true },
    },
    { key = "Resting", label = "Resting", read = IsResting, events = { PLAYER_UPDATE_RESTING = true }, triggerOnly = true },
    {
        key = "HasPet",
        label = "Has Pet",
        read = function() return UnitExists("pet") and not UnitIsDead("pet") end,
        events = { UNIT_PET = "player" },
        triggerOnly = true,
    },
    {
        key = "Moving",
        label = "Moving",
        read = IsPlayerMoving,
        events = { PLAYER_STARTED_MOVING = true, PLAYER_STOPPED_MOVING = true },
        triggerOnly = true,
    },
    {
        key = "PvPFlagged",
        label = "PvP Flagged",
        read = function() return UnitIsPVP("player") end,
        events = { PLAYER_FLAGS_CHANGED = "player" },
        triggerOnly = true,
    },
}
LoadConditions.STATES = STATES
NRSKNUI.GUI.loadStates = STATES -- Kaji's load card can't reach the addon, so it gets the list handed over

local function CheckState(config)
    for _, state in ipairs(STATES) do
        local wanted = config[state.key]
        if wanted ~= nil then
            if state.events then
                Watch(state.events)
            end
            if (state.read() == true) ~= wanted then return false end
        end
    end
    return true
end

local checkers = {
    Instance = CheckInstance,
    Group = CheckGroup,
    Role = CheckRole,
    Position = CheckPosition,
    Zone = CheckZone,
    Spec = CheckSpec,
    Talent = CheckTalent,
    Race = CheckRace,
    Spells = CheckSpells,
    Difficulty = CheckDifficulty,
    State = CheckState,
}

-- Conditions that change during a session
local SITUATIONAL = {
    Instance = true,
    Group = true,
    Zone = true,
    Spells = true, -- the pet can change at any time
    Difficulty = true,
    State = true,
}

local function FireStateCallbacks()
    for aceModule, callback in pairs(stateCallbacks) do
        if aceModule:IsEnabled() then
            callback(aceModule)
        end
    end
end

---@param playerChanged boolean spec or talents may have changed
local function FireCallbacks(playerChanged)
    for aceModule, callback in pairs(callbacks) do
        if aceModule:IsEnabled() then
            callback(aceModule, playerChanged)
        end
    end
    FireStateCallbacks()
end

-- Subzone events fire constantly while moving, only a new map ID can change a Zone condition.
local ZONE_EVENTS = { ZONE_CHANGED = true, ZONE_CHANGED_INDOORS = true, ZONE_CHANGED_NEW_AREA = true }
local lastMapID

-- Talent and spec changes rebuild the taken-talent set on the next check.
local TALENT_EVENTS = {
    TRAIT_CONFIG_CREATED = true,
    TRAIT_CONFIG_UPDATED = true,
    PLAYER_TALENT_UPDATE = true,
    ACTIVE_PLAYER_SPECIALIZATION_CHANGED = true,
}

-- What only a triggerOnly state reads: moving flips on every step, so these leave load alone.
local STATE_ONLY_EVENTS = { PLAYER_STARTED_MOVING = true, PLAYER_STOPPED_MOVING = true, PLAYER_UPDATE_RESTING = true }

local function OnEvent(_, event, isInitialLogin)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    elseif event == "ENCOUNTER_START" then
        inEncounter = true
    elseif event == "ENCOUNTER_END" then
        inEncounter = false
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- hearthing out of a pull is the one way to leave without an ENCOUNTER_END
        inEncounter = IsEncounterInProgress()
        -- canGlide isn't settled yet on the first loading screen
        if isInitialLogin then
            After(2, function() FireCallbacks(false) end)
        end
    end

    if STATE_ONLY_EVENTS[event] then
        FireStateCallbacks()
        return
    end
    if event == "UNIT_PET" then
        FireStateCallbacks()
    end

    -- SPELLS_CHANGED comes with every combat override swap, only a spell a condition asked about matters
    if (event == "SPELLS_CHANGED" or event == "UNIT_PET") and not SpellsChanged() then return end

    -- the talent config can still be missing on login, so a loading screen rescans too
    local playerChanged = TALENT_EVENTS[event] or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ENTERING_WORLD"
    if playerChanged then talentsDirty = true end
    local mapID = GetBestMapForUnit("player")
    if ZONE_EVENTS[event] and mapID == lastMapID then return end
    lastMapID = mapID
    FireCallbacks(playerChanged == true)
end

local function SetupEventFrame()
    if eventFrame then return end

    -- a reload in combat starts here already in combat, before any REGEN event
    inCombat = NRSKNUI:InCombat() or UnitAffectingCombat("player")
    inEncounter = IsEncounterInProgress()
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ENCOUNTER_START")
    eventFrame:RegisterEvent("ENCOUNTER_END")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    for event in pairs(TALENT_EVENTS) do eventFrame:RegisterEvent(event) end
    for event in pairs(ZONE_EVENTS) do eventFrame:RegisterEvent(event) end

    eventFrame:SetScript("OnEvent", OnEvent)
end

---@param conditions table LoadConditions config with category tables
---@param skipSituational? boolean ignore conditions that change during a session (combat, zone, group, instance)
---@return boolean
---@return string? failed the category that failed
function LoadConditions:Check(conditions, skipSituational)
    if not conditions then return true end

    for category, checker in pairs(checkers) do
        local config = conditions[category]
        if config and not (skipSituational and SITUATIONAL[category]) and not checker(config, conditions) then return false, category end
    end

    return true
end

---@return number? specID
function LoadConditions:GetSpecID()
    return PlayerSpecID()
end

---Whether the player has this talent taken, by C_Traits entryID.
---@param entryID number
---@return boolean
function LoadConditions:HasTalent(entryID)
    if talentsDirty then RebuildTalents() end
    return takenTalents[entryID] == true
end

---@return table Default LoadConditions structure
function LoadConditions:GetDefaults()
    return {
        Instance = { Types = {} },
        Group = { Types = {} },
        Role = { Types = {} },
        Position = { Types = {} },
        Zone = {},
        Spec = { Types = {} },
        Talent = { Specs = {} },
        Race = { Types = {} },
        Spells = {},
        Difficulty = { Types = {} },
        State = {},
    }
end

---Register a module to receive callbacks when load conditions may have changed
---@param aceModule table AceModule with IsEnabled method
---@param callback fun(aceModule: table, playerChanged: boolean) runs when state may have changed; playerChanged on spec and talent changes
function LoadConditions:RegisterCallback(aceModule, callback)
    SetupEventFrame()
    callbacks[aceModule] = callback
end

---Unregister a module's callback
---@param aceModule table
function LoadConditions:UnregisterCallback(aceModule)
    callbacks[aceModule] = nil
end

---Register a module to hear about every state change, the triggerOnly ones included.
---@param aceModule table AceModule with IsEnabled method
---@param callback fun(aceModule: table)
function LoadConditions:RegisterStateCallback(aceModule, callback)
    SetupEventFrame()
    stateCallbacks[aceModule] = callback
end

---@param aceModule table
function LoadConditions:UnregisterStateCallback(aceModule)
    stateCallbacks[aceModule] = nil
end

-- Saved data --

---@param block table
---@return boolean
local function IsLoadBlock(block)
    if block.Enabled ~= nil or block.SelectedCategory ~= nil or block.Combat then return true end
    for category in pairs(checkers) do
        if block[category] then return true end
    end
    return false
end

---@param saved table any saved or imported table, searched at every depth
---@param fn fun(block: table)
local function EachLoadBlock(saved, fn)
    for key, value in pairs(saved) do
        if type(value) == "table" then
            if (key == "LoadConditions" or key == "Load") and IsLoadBlock(value) then
                fn(value)
            else
                EachLoadBlock(value, fn)
            end
        end
    end
end

---Brings saved load tables over from the old Enable toggle. Off meant the picks were ignored so they go;
---AceDB strips a value equal to its default, so off reads as unset and only true means it was on.
---@param saved table
function LoadConditions:DropEnableToggle(saved)
    EachLoadBlock(saved, function(block)
        if block.Enabled == true then
            block.Enabled, block.SelectedCategory = nil, nil
        else
            wipe(block)
        end
    end)
end

---Moves the old In Combat and Out of Combat pair onto the one tri-state. Neither or both ticked meant no limit.
---@param saved table
function LoadConditions:MoveCombatToState(saved)
    EachLoadBlock(saved, function(block)
        local combat = block.Combat
        if not combat then return end

        if (combat.InCombat == true) ~= (combat.OutOfCombat == true) then
            block.State = block.State or {}
            block.State.InCombat = combat.InCombat == true
        end
        block.Combat = nil
    end)
end

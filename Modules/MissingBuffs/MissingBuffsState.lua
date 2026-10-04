---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class MissingBuffsModule
local MissingBuffs = NRSKNUI:GetModule('MissingBuffs')

local type = type
local wipe = wipe
local pairs = pairs
local ipairs = ipairs
local select = select
local tonumber = tonumber
local mmax = math.max
local GetTime = GetTime
local UnitRace = UnitRace
local UnitClass = UnitClass
local UnitLevel = UnitLevel
local GetMaxLevelForPlayerExpansion = GetMaxLevelForPlayerExpansion
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitIsPlayer = UnitIsPlayer
local UnitIsVisible = UnitIsVisible
local UnitCanAssist = UnitCanAssist
local UnitIsConnected = UnitIsConnected
local UnitPhaseReason = UnitPhaseReason
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local GetUnitName = GetUnitName
local IsInRaid = IsInRaid
local IsInInstance = IsInInstance
local GetInstanceInfo = GetInstanceInfo
local GetNumGroupMembers = GetNumGroupMembers
local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemLink = GetInventoryItemLink

local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant
local GetItemCount = C_Item and C_Item.GetItemCount
local GetItemSpell = C_Item and C_Item.GetItemSpell
local GetItemIconByID = C_Item and C_Item.GetItemIconByID
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture
local IsSpellKnown = C_SpellBook and C_SpellBook.IsSpellKnown
local IsSpellOverlayed = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed
local GetUnitAuraBySpellID = C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID
local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local GetActiveConfigID = C_ClassTalents and C_ClassTalents.GetActiveConfigID
local GetConfigInfo = C_Traits and C_Traits.GetConfigInfo
local GetTreeNodes = C_Traits and C_Traits.GetTreeNodes
local GetNodeInfo = C_Traits and C_Traits.GetNodeInfo
local GetEntryInfo = C_Traits and C_Traits.GetEntryInfo
local GetDefinitionInfo = C_Traits and C_Traits.GetDefinitionInfo
local GetTemporaryEnchantmentInfo =C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo
local IsChallengeModeActive = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive

local INVSLOT_MAINHAND = INVSLOT_MAINHAND
local INVSLOT_OFFHAND = INVSLOT_OFFHAND
local ITEM_CLASS_WEAPON = Enum.ItemClass.Weapon
local ITEM_CLASS_ARMOR = Enum.ItemClass.Armor
local ARMOR_SHIELD = Enum.ItemArmorSubclass.Shield

local Data = MissingBuffs.Data
local SpecBeneficiaries = MissingBuffs.SpecBeneficiaries
local ClassBeneficiaries = MissingBuffs.ClassBeneficiaries

local CATEGORY_ORDER = { 'Self', 'Raid', 'Presence', 'Targeted', 'Consumable', 'Utility' }
local POISON_ORDER = { 'lethal', 'nonLethal' }

MissingBuffs.results = {} ---@type table<MissingBuffs.Category, MissingBuffs.Result[]>
MissingBuffs.shown = {} ---@type table<string, MissingBuffs.Result>
MissingBuffs.groupSpecs = {} ---@type table<string, number>
MissingBuffs.trackedSpells = {} ---@type table<number, true>
MissingBuffs.glowSpells = {} ---@type table<number, true> action bar glows a glow-detectable entry of this class reads
MissingBuffs.trackedInstances = {} ---@type table<number, true>

local resultPool = {} ---@type table<string, MissingBuffs.Result>
local chosenItems = {} ---@type table<string, number> bag pick per entry, kept through combat for the icon
local activeSpells = {} ---@type table<string, number> running consumable aura per entry, so a refresh keeps its stat
local units = {} ---@type MissingBuffs.Unit[]
local unitPool = {} ---@type MissingBuffs.Unit[]
local classMaxLevel = {} ---@type table<string, number>
local trackable = {} ---@type table<number, boolean>
local enchants = {}
local heroChoices = {} ---@type table<number, boolean>

local now, aurasSecret, nextChange, db
local playerClass = NRSKNUI.MyClass
local heroChoiceSpells = MissingBuffs.HeroChoiceSpells[playerClass]
MissingBuffs.heroChoicesDirty = true

-- Spell Gates --

---@param entry MissingBuffs.Entry
---@return number?
local function GetCastSpell(entry)
    local id = entry.castSpellID or entry.spellID
    return (type(id) == 'table' and id[1] or id) --[[@as number?]]
end

---@param entry MissingBuffs.Entry
---@return boolean
local function PassesGates(entry)
    if entry.class and entry.class ~= playerClass then return false end
    if entry.specID and entry.specID ~= NRSKNUI.MySpec.id then return false end
    if entry.requiresSpellID and not IsSpellKnown(entry.requiresSpellID) then return false end
    if entry.excludeSpellID and IsSpellKnown(entry.excludeSpellID) then return false end
    return true
end

---@param spellID number
---@return boolean
local function IsSpellTrackable(spellID)
    local cached = trackable[spellID]
    if cached == nil then
        cached = not NRSKNUI:IsSpellAuraSecret(spellID)
        trackable[spellID] = cached
    end
    return cached
end

---@param ids number|number[]
---@return boolean
local function AreSpellsTrackable(ids)
    if type(ids) == 'number' then return IsSpellTrackable(ids) end
    for _, id in ipairs(ids) do
        if not IsSpellTrackable(id) then return false end
    end
    return true
end

-- Alternates such as the NPC copies of a raid buff can be secret while the player cast is not.
---@param ids number|number[]
---@return boolean
local function IsAnySpellTrackable(ids)
    if type(ids) == 'number' then return IsSpellTrackable(ids) end
    for _, id in ipairs(ids) do
        if IsSpellTrackable(id) then return true end
    end
    return false
end

-- Can this entry be answered while aura reads are secret?
---@param entry MissingBuffs.Entry
---@return boolean
local function IsEntryTrackable(entry)
    if entry.unsafeRestricted then return false end
    if entry.check == 'Food' then return false end
    if entry.check == 'Poisons' then
        return AreSpellsTrackable(MissingBuffs.Poisons.lethal) and AreSpellsTrackable(MissingBuffs.Poisons.nonLethal)
    end
    if entry.casterBuffID then return IsSpellTrackable(entry.casterBuffID) end
    if entry.enchantID then return true end
    if entry.spellID then return IsAnySpellTrackable(entry.spellID) end
    return true
end

MissingBuffs.IsEntryTrackable = IsEntryTrackable

function MissingBuffs:ResetSpellSecrecy()
    wipe(trackable)
end

-- Aura Reads --

---@param aura AuraData
---@return number?
local function GetRemaining(aura)
    local expirationTime = aura.expirationTime
    if NRSKNUI:IsSecretValue(expirationTime) or not expirationTime or expirationTime <= 0 then return nil end
    -- An aura lingers briefly past its expiration until the client removes it.
    return mmax(expirationTime - now, 0)
end

-- While auras are secret only the IDs the client still answers for are asked.
---@param unit string
---@param ids number|number[]
---@return AuraData?
local function FindAura(unit, ids)
    if type(ids) == 'number' then
        if aurasSecret and not IsSpellTrackable(ids) then return nil end
        return GetUnitAuraBySpellID(unit, ids)
    end
    for _, id in ipairs(ids) do
        if not aurasSecret or IsSpellTrackable(id) then
            local aura = GetUnitAuraBySpellID(unit, id)
            if aura then return aura end
        end
    end
    return nil
end

---@param aura AuraData
local function RecordInstance(aura)
    local instanceID = aura.auraInstanceID
    if NRSKNUI:IsSafeValue(instanceID) then
        MissingBuffs.trackedInstances[instanceID] = true
    end
end

---@param aura AuraData
---@return boolean? nil when the source cannot be read
local function IsFromPlayer(aura)
    local fromPlayer = aura.isFromPlayerOrPlayerPet
    if NRSKNUI:IsSecretValue(fromPlayer) then return nil end
    return fromPlayer
end

-- Another caster's copy can mask ours in GetUnitAuraBySpellID, so fall back to the PLAYER filter.
---@param unit string
---@param spellID number
---@return AuraData?
local function FindPlayerAura(unit, spellID)
    local aura = GetUnitAuraBySpellID(unit, spellID)
    if not aura then return nil end
    if IsFromPlayer(aura) then return aura end
    if aurasSecret then return nil end

    local i = 1
    aura = GetAuraDataByIndex(unit, i, 'HELPFUL|PLAYER')
    while aura do
        ---@diagnostic disable-next-line: secret-comparison
        if aura.spellId == spellID then return aura end
        i = i + 1
        aura = GetAuraDataByIndex(unit, i, 'HELPFUL|PLAYER')
    end
    return nil
end

-- Group --

---@param unit string
---@return boolean
local function IsPhased(unit)
    if not UnitIsVisible(unit) then return true end
    local reason = UnitPhaseReason(unit)
    return NRSKNUI:NotSecretValue(reason) and reason ~= nil
end

---@param unit string
---@param npcsCount boolean
local function AddUnit(unit, npcsCount)
    if not UnitExists(unit) then return end
    if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then return end
    if unit ~= 'player' and not UnitCanAssist('player', unit) then return end
    if not npcsCount and not UnitIsPlayer(unit) then return end

    local record = unitPool[#units + 1] or {}
    unitPool[#units + 1] = record
    units[#units + 1] = record

    local name = GetUnitName(unit, true)
    record.unit = unit
    record.name = NRSKNUI:IsSafeValue(name) and name or nil
    record.class = select(2, UnitClass(unit))
    record.isPlayer = UnitIsPlayer(unit)
    record.isMe = UnitIsUnit(unit, 'player')
    record.phased = IsPhased(unit)

    if record.isPlayer and record.class and not record.phased then
        local level = UnitLevel(unit)
        if level > (classMaxLevel[record.class] or 0) then
            classMaxLevel[record.class] = level
        end
    end
end

local function BuildUnits()
    wipe(units)
    wipe(classMaxLevel)
    wipe(MissingBuffs.trackedInstances)

    -- Only follower dungeon and delve companions take buffs, quest scenario NPCs never do.
    local difficulty = select(3, GetInstanceInfo())
    local npcsCount = difficulty == MissingBuffs.FollowerDifficulty or difficulty == MissingBuffs.DelveDifficulty

    local count = GetNumGroupMembers()
    if IsInRaid() then
        for i = 1, count do AddUnit('raid' .. i, npcsCount) end
    else
        AddUnit('player', npcsCount)
        for i = 1, count - 1 do AddUnit('party' .. i, npcsCount) end
    end
end

---@param record MissingBuffs.Unit
---@param benefit string?
---@return boolean
local function Benefits(record, benefit)
    if not benefit then return true end
    local specID = record.isMe and NRSKNUI.MySpec.id or (record.name and MissingBuffs.groupSpecs[record.name])
    if specID then return SpecBeneficiaries[benefit][specID] or false end
    return record.class and ClassBeneficiaries[benefit][record.class] or false
end

---@param class string
---@param levelRequired number?
---@return boolean
local function HasProvider(class, levelRequired)
    local level = classMaxLevel[class]
    return level ~= nil and (not levelRequired or level >= levelRequired)
end

---@param specID number?
---@param _role string?
---@param _position string?
---@param name string?
function MissingBuffs:OnGroupSpec(specID, _role, _position, name)
    if not name then return end
    specID = specID and specID > 0 and specID or nil
    if self.groupSpecs[name] == specID then return end
    self.groupSpecs[name] = specID
    self:RequestUpdate()
end

-- Equipment --

---@return 'weapon'|'shield'|nil
local function GetOffHandType()
    local itemID = GetInventoryItemID('player', INVSLOT_OFFHAND)
    if not itemID then return nil end
    local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID)
    if classID == ITEM_CLASS_WEAPON then return 'weapon' end
    if classID == ITEM_CLASS_ARMOR and subClassID == ARMOR_SHIELD then return 'shield' end
    return nil
end

---@param slot number
---@return number?
local function GetPermanentEnchant(slot)
    local link = GetInventoryItemLink('player', slot)
    return link and tonumber(link:match('item:%d+:(%d+)')) or nil
end

local function ReadEnchants()
    local mainHand = GetTemporaryEnchantmentInfo(INVSLOT_MAINHAND)
    local offHand = GetTemporaryEnchantmentInfo(INVSLOT_OFFHAND)
    enchants.mainHand = mainHand and mainHand.enchantID
    enchants.mainHandRemaining = mainHand and mainHand.hasExpirationTime and mainHand.remainingTimeMs / 1000 or nil
    enchants.offHand = offHand and offHand.enchantID
    enchants.offHandRemaining = offHand and offHand.hasExpirationTime and offHand.remainingTimeMs / 1000 or nil
end

---Read the picked hero choice spells off the talent tree, false while the config is not loaded yet.
---@return boolean
local function ScanHeroChoices()
    local configID = GetActiveConfigID()
    local config = configID and GetConfigInfo(configID)
    if not config then return false end

    for _, spellID in ipairs(heroChoiceSpells) do heroChoices[spellID] = false end
    for _, treeID in ipairs(config.treeIDs) do
        for _, nodeID in ipairs(GetTreeNodes(treeID)) do
            local node = GetNodeInfo(configID, nodeID)
            local entryID = node.subTreeActive and node.activeRank > 0 and node.activeEntry and node.activeEntry.entryID
            local entry = entryID and GetEntryInfo(configID, entryID)
            local definition = entry and entry.definitionID and GetDefinitionInfo(entry.definitionID)
            if definition and heroChoices[definition.spellID] ~= nil then heroChoices[definition.spellID] = true end
        end
    end
    return true
end

---@param spellID number
---@return boolean
local function KnowsSpell(spellID)
    local picked = heroChoices[spellID]
    if picked ~= nil then return picked end
    return IsSpellKnown(spellID)
end

---@param spells number[]
---@return boolean
local function KnowsAny(spells)
    for _, id in ipairs(spells) do
        if KnowsSpell(id) then return true end
    end
    return false
end

---@param itemIDs number[]
---@return number
local function CountItems(itemIDs)
    local total = 0
    for _, id in ipairs(itemIDs) do
        total = total + GetItemCount(id, false, true)
    end
    return total
end

---@param class string
---@return boolean
local function ClassAvailable(class)
    return playerClass == class or classMaxLevel[class] ~= nil
end

---@return boolean
local function HasHealerInGroup()
    for _, record in ipairs(units) do
        if NRSKNUI:GetSafeRole(record.unit) == 'HEALER' then return true end
    end
    return false
end

---@param spellID number
---@return boolean
local function IsOnCooldown(spellID)
    if NRSKNUI:AreCooldownsSecret() then return true end
    local info = NRSKNUI:GetSpellCooldownInfo(spellID)
    return info ~= nil and info.isActive and not info.isOnGCD
end

-- Consumable Items --

local itemSpells = {} ---@type table<number, number>
local bagItems = {} ---@type table<string, number[]> per entry key
local bagItemsGeneration = {} ---@type table<string, number>
local bagGeneration = 0

-- Both qualities of one flask share the spell they cast, so the spell is what identifies a choice.
---@param itemID number
---@return number?
local function GetItemSpellID(itemID)
    local spellID = itemSpells[itemID]
    if not spellID then
        spellID = select(2, GetItemSpell(itemID))
        itemSpells[itemID] = spellID
    end
    return spellID
end

function MissingBuffs:InvalidateBagItems()
    bagGeneration = bagGeneration + 1
end

---Items of the entry's list that are in the bags and fit the equipped weapon, in list order.
---Cached until the bags or the equipment change, callers must not modify the list.
---@param entry MissingBuffs.Entry
---@return number[]
function MissingBuffs:CollectBagItems(entry)
    local key = entry.key
    local out = bagItems[key]
    if out and bagItemsGeneration[key] == bagGeneration then return out end
    out = out and wipe(out) or {}
    bagItems[key] = out
    bagItemsGeneration[key] = bagGeneration

    local weaponType
    if entry.itemList == 'WeaponOil' then
        local itemID = GetInventoryItemID('player', entry.enchantSlot == 'offhand' and INVSLOT_OFFHAND or INVSLOT_MAINHAND)
        local subClassID = itemID and select(7, GetItemInfoInstant(itemID))
        weaponType = subClassID and self.WeaponTypes[subClassID]
    end

    for _, item in ipairs(self.ConsumableItems[entry.itemList --[[@as string]]]) do
        local itemID = type(item) == 'table' and item.itemID or item
        local fits = type(item) ~= 'table' or not item.weaponType or item.weaponType == weaponType
        if fits and GetItemCount(itemID) > 0 then out[#out + 1] = itemID end
    end
    return out
end

---Remember an item as this spec's choice for its list, fleeting flasks never count.
---@param itemList string
---@param itemID number
---@param updateOnly? boolean only replace an existing choice, a passive sighting must not seed a new spec
function MissingBuffs:RememberItem(itemList, itemID, updateOnly)
    local specID = NRSKNUI.MySpec.id
    if not specID or self.FleetingItems[itemID] then return end

    local memory = self.db.Remembered[specID]
    if updateOnly and not memory[itemList] then return end
    memory[itemList] = itemID
end

-- The wanted stat is the running flask's, else the remembered one. A fleeting flask of that stat first, then the
-- remembered item, its other quality, any fleeting flask, list order.
---@param entry MissingBuffs.Entry
---@return number?
local function FindBagItem(entry)
    local items = MissingBuffs:CollectBagItems(entry)
    if #items == 0 then return nil end

    local remembered = NRSKNUI.MySpec.id and db.Remembered[NRSKNUI.MySpec.id][entry.itemList]
    local wantedSpell = activeSpells[entry.key] or (remembered and GetItemSpellID(remembered))
    local fleeting, fleetingMatch, exact, sibling

    for _, itemID in ipairs(items) do
        local sameSpell = wantedSpell and GetItemSpellID(itemID) == wantedSpell
        if MissingBuffs.FleetingItems[itemID] then
            fleeting = fleeting or itemID
            if sameSpell then fleetingMatch = fleetingMatch or itemID end
        elseif sameSpell then
            if itemID == remembered then exact = itemID else sibling = sibling or itemID end
        end
    end
    return fleetingMatch or exact or sibling or fleeting or items[1]
end

-- An active flask or rune tells which one this spec drinks, but only updates a choice made before.
---@param entry MissingBuffs.Entry
---@param aura AuraData
local function RememberActive(entry, aura)
    local spellID = aura.spellId
    if not NRSKNUI:IsSafeValue(spellID) then return end

    for _, item in ipairs(MissingBuffs.ConsumableItems[entry.itemList --[[@as string]]]) do
        if type(item) == 'number' and GetItemSpellID(item) == spellID then
            MissingBuffs:RememberItem(entry.itemList --[[@as string]], item, true)
            return
        end
    end
end

-- Results --

---@param entry MissingBuffs.Entry
---@param category MissingBuffs.Category
---@param remaining number?
---@return MissingBuffs.Result
local function Push(entry, category, remaining)
    local result = resultPool[entry.key]
    if not result then
        result = { entry = entry }
        resultPool[entry.key] = result
    end

    result.category = category
    result.remaining = remaining
    result.expiring = false
    result.missing = nil
    result.total = nil
    result.eating = nil

    local castSpell = entry.roleSpell and entry.roleSpell[NRSKNUI.MySpec.role] or GetCastSpell(entry)
    result.icon = entry.icon or GetSpellTexture(castSpell or 0)
    result.castSpell = not entry.noClick and castSpell and IsSpellKnown(castSpell) and castSpell or nil
    result.useItem = nil
    -- itemID entries are only pushed once the bags came up empty.
    result.noItem = entry.itemID ~= nil

    if entry.itemList then
        if not MissingBuffs.inCombat then chosenItems[entry.key] = FindBagItem(entry) end
        local itemID = chosenItems[entry.key]
        if itemID then
            result.icon = GetItemIconByID(itemID)
            result.useItem = db.ClickToCast and not MissingBuffs.inCombat and itemID or nil
        else
            result.noItem = true
            if MissingBuffs:GetSettings(entry.key).EmptyBagMode == 'hide' then return result end
        end
    end

    local list = MissingBuffs.results[category]
    list[#list + 1] = result
    MissingBuffs.shown[entry.key] = result
    return result
end

-- A present buff with a timer: show it once it drops under the buff's own threshold.
---@param entry MissingBuffs.Entry
---@param category MissingBuffs.Category
---@param remaining number?
local function CheckExpiring(entry, category, remaining)
    if not remaining or entry.noExpiry then return end
    local threshold = MissingBuffs:GetSettings(entry.key).Expiring * 60
    if threshold <= 0 then return end

    if remaining <= threshold then
        Push(entry, category, remaining).expiring = true
        if not nextChange or remaining < nextChange then nextChange = remaining end
    elseif not nextChange or remaining - threshold < nextChange then
        nextChange = remaining - threshold
    end
end

-- Custom Checks --

local Checks = {}

---@param entry MissingBuffs.Entry
function Checks.Poisons(entry)
    local poisons = MissingBuffs.Poisons
    local perCategory = IsSpellKnown(MissingBuffs.DragonTemperedBlades) and 2 or 1
    local nextCast, minRemaining

    for _, kind in ipairs(POISON_ORDER) do
        local list = poisons[kind]
        local known, active, firstMissing = 0, 0, nil
        for _, id in ipairs(list) do
            local isKnown = IsSpellKnown(id)
            if isKnown then known = known + 1 end

            local aura = GetUnitAuraBySpellID('player', id)
            if aura then
                active = active + 1
                local remaining = GetRemaining(aura)
                if remaining and (not minRemaining or remaining < minRemaining) then minRemaining = remaining end
            elseif isKnown and not firstMissing then
                firstMissing = id
            end
        end

        local required = known < perCategory and known or perCategory
        if active < required and not nextCast then nextCast = firstMissing end
    end

    if nextCast then
        local result = Push(entry, 'Self')
        result.icon = GetSpellTexture(nextCast)
        result.castSpell = nextCast
    else
        CheckExpiring(entry, 'Self', minRemaining)
    end
end

---@param entry MissingBuffs.Entry
function Checks.Runeforge(entry)
    local offHand = entry.enchantSlot == 'offhand'
    if offHand and GetOffHandType() ~= 'weapon' then return end

    local slot = offHand and INVSLOT_OFFHAND or INVSLOT_MAINHAND
    local itemID = GetInventoryItemID('player', slot)
    if not itemID then return end

    -- A two-hander and a dual wield main hand want different runes.
    local slotKey = offHand and 'OffHand' or (select(4, GetItemInfoInstant(itemID)) == 'INVTYPE_2HWEAPON' and 'TwoHand' or 'MainHand')
    local accepted = db.Runeforge[NRSKNUI.MySpec.id or 0][slotKey]
    local current = GetPermanentEnchant(slot)

    -- Nothing ticked means any rune will do.
    local hasRune, wanted = false, nil
    for _, rune in ipairs(MissingBuffs.Runeforges) do
        if accepted[rune.enchantID] then
            if rune.enchantID == current then return end
            wanted = wanted or rune.spellID
        elseif rune.enchantID == current then
            hasRune = true
        end
    end
    if hasRune and not wanted then return end

    local result = Push(entry, 'Self')
    if wanted then result.icon = GetSpellTexture(wanted) end
end

---@param entry MissingBuffs.Entry
function Checks.Food(entry)
    if select(2, UnitRace('player')) == 'EarthenDwarf' then return end

    local fed, eating
    local i = 1
    local aura = GetAuraDataByIndex('player', i, 'HELPFUL')
    while aura do
        local icon = aura.icon
        ---@diagnostic disable-next-line: secret-comparison
        if icon == MissingBuffs.FoodIcon then
            fed = aura
        ---@diagnostic disable-next-line: secret-comparison
        elseif icon == MissingBuffs.EatingIcon then
            eating = true
        end
        i = i + 1
        aura = GetAuraDataByIndex('player', i, 'HELPFUL')
    end

    if fed then
        CheckExpiring(entry, 'Consumable', GetRemaining(fed))
    else
        Push(entry, 'Consumable').eating = eating
    end
end

---@param entry MissingBuffs.Entry
function Checks.DelveFood(entry)
    if select(3, GetInstanceInfo()) ~= MissingBuffs.DelveDifficulty then return end
    if not GetUnitAuraBySpellID('player', entry.spellID --[[@as number]]) then
        Push(entry, 'Consumable')
    end
end

---@param entry MissingBuffs.Entry
function Checks.Healthstone(entry)
    if not ClassAvailable(entry.casterClass) then return end
    local charges = CountItems(entry.itemID --[[@as number[] ]])
    if charges == 0 then
        Push(entry, 'Consumable')
    elseif charges == 1 then
        local result = Push(entry, 'Consumable')
        result.noItem = false
        result.total = entry.maxCharges
        result.missing = entry.maxCharges - charges
    end
end

---@param entry MissingBuffs.Entry
function Checks.MageFood(entry)
    if NRSKNUI.MySpec.role ~= 'HEALER' or not classMaxLevel[entry.casterClass] then return end
    local _, instanceType = IsInInstance()
    if instanceType ~= 'party' and instanceType ~= 'raid' then return end
    if CountItems(entry.itemID --[[@as number[] ]]) == 0 then
        Push(entry, 'Consumable')
    end
end

---@param entry MissingBuffs.Entry
function Checks.WeaponOil(entry)
    if KnowsAny(MissingBuffs.WeaponImbueSpells) then return end

    local offHand = entry.enchantSlot == 'offhand'
    if offHand and GetOffHandType() ~= 'weapon' then return end
    if not offHand and not GetInventoryItemID('player', INVSLOT_MAINHAND) then return end

    local enchantID, remaining
    if offHand then
        enchantID, remaining = enchants.offHand, enchants.offHandRemaining
    else
        enchantID, remaining = enchants.mainHand, enchants.mainHandRemaining
    end

    if not enchantID then
        Push(entry, 'Consumable')
    else
        CheckExpiring(entry, 'Consumable', remaining)
    end
end

---@return boolean
function Checks.RefreshmentTable()
    return not aurasSecret and HasHealerInGroup()
end

-- Category Evaluators --

local Evaluate = {}

---@param entry MissingBuffs.Entry
function Evaluate.Raid(entry)
    local mine = playerClass == entry.class
    if not mine and not HasProvider(entry.class, entry.levelRequired) then return end
    if mine and UnitLevel('player') < (entry.levelRequired or 0) then return end

    -- Personal only asks whether you have it, group counts everyone the buff helps. Your own buff always counts the group.
    local personal = db.RaidBuffMode == 'personal' and not mine
    local missing, total, minRemaining = 0, 0, nil
    for _, record in ipairs(units) do
        -- NPCs carry the NPC copies, which go secret with everything else.
        if (not personal or record.isMe) and (record.isPlayer or not (entry.playersOnly or aurasSecret))
            and Benefits(record, entry.benefit) then
            local ids = entry.perClass and record.class and entry.perClass[record.class] or entry.spellID
            local aura = FindAura(record.unit, ids --[[@as number|number[] ]])
            if aura then
                RecordInstance(aura)
                total = total + 1
                local remaining = GetRemaining(aura)
                if remaining and (not minRemaining or remaining < minRemaining) then minRemaining = remaining end
            elseif not record.phased then
                total = total + 1
                missing = missing + 1
            end
        end
    end

    if total == 0 then return end
    if missing > 0 then
        local result = Push(entry, 'Raid')
        if not personal then
            result.missing = missing
            result.total = total
        end
    else
        CheckExpiring(entry, 'Raid', minRemaining)
    end
end

---@param entry MissingBuffs.Entry
function Evaluate.Presence(entry)
    if entry.suppressedBy and MissingBuffs.shown[entry.suppressedBy] then return end
    if entry.readyCheckOnly and not MissingBuffs.inReadyCheck then return end
    if entry.groupOnly and #units <= 1 then return end

    local mine = playerClass == entry.class
    if not mine and not HasProvider(entry.class, entry.levelRequired) then return end
    if mine and entry.hideOnCooldown and IsOnCooldown(GetCastSpell(entry) --[[@as number]]) then return end

    local ids = entry.outdoorSpellID and not IsInInstance() and entry.outdoorSpellID or entry.spellID
    local minRemaining
    for _, record in ipairs(units) do
        local aura
        if mine and entry.hideOnCooldown then
            aura = FindPlayerAura(record.unit, GetCastSpell(entry) --[[@as number]])
        else
            aura = FindAura(record.unit, ids --[[@as number|number[] ]])
        end
        if aura then
            RecordInstance(aura)
            local remaining = GetRemaining(aura)
            if not remaining then return end
            if not minRemaining or remaining < minRemaining then minRemaining = remaining end
        end
    end

    if minRemaining then
        CheckExpiring(entry, 'Presence', minRemaining)
    else
        Push(entry, 'Presence')
    end
end

---@param entry MissingBuffs.Entry
function Evaluate.Targeted(entry)
    if #units <= 1 then return end
    if not IsSpellKnown(GetCastSpell(entry) --[[@as number]]) then return end

    if entry.casterBuffID then
        local aura = GetUnitAuraBySpellID('player', entry.casterBuffID)
        if aura then
            CheckExpiring(entry, 'Targeted', GetRemaining(aura))
        else
            Push(entry, 'Targeted')
        end
        return
    end

    local spellID = GetCastSpell(entry) --[[@as number]]
    local hasBeneficiary = not entry.role
    local found, minRemaining = false, nil
    for _, record in ipairs(units) do
        if not entry.role or NRSKNUI:GetSafeRole(record.unit) == entry.role then
            hasBeneficiary = true
            local aura = FindPlayerAura(record.unit, spellID)
            if aura then
                RecordInstance(aura)
                found = true
                local remaining = GetRemaining(aura)
                if remaining and (not minRemaining or remaining < minRemaining) then minRemaining = remaining end
            end
        end
    end

    if not hasBeneficiary then return end
    if not found then
        Push(entry, 'Targeted')
    else
        CheckExpiring(entry, 'Targeted', minRemaining)
    end
end

---@param entry MissingBuffs.Entry
function Evaluate.Self(entry)
    if entry.check then return Checks[entry.check](entry) end

    local castSpell = GetCastSpell(entry)
    if castSpell and not KnowsSpell(castSpell) then return end

    local enchantOk, enchantRemaining = true, nil
    if entry.enchantID then
        local offHand = entry.enchantSlot == 'offhand'
        if entry.requiresShield and GetOffHandType() ~= 'shield' then return end
        if offHand then
            enchantOk = enchants.offHand == entry.enchantID
            enchantRemaining = enchants.offHandRemaining
        elseif enchants.mainHand == entry.enchantID then
            enchantRemaining = enchants.mainHandRemaining
        elseif enchants.offHand == entry.enchantID then
            enchantRemaining = enchants.offHandRemaining
        else
            enchantOk = false
        end
    end

    -- The rite buff only guards against a talent swap dropping it, which cannot happen while auras are secret.
    local needsAura = entry.spellID and not (aurasSecret and entry.enchantID and not IsAnySpellTrackable(entry.spellID))
    local aura = needsAura and FindAura('player', entry.spellID --[[@as number|number[] ]])
    if not enchantOk or (needsAura and not aura) then
        Push(entry, 'Self')
    else
        CheckExpiring(entry, 'Self', enchantRemaining or (aura and GetRemaining(aura)))
    end
end

---@param entry MissingBuffs.Entry
function Evaluate.Consumable(entry)
    if entry.readyCheckOnly and not MissingBuffs.inReadyCheck then return end
    if entry.check then return Checks[entry.check](entry) end

    local aura = FindAura('player', entry.spellID --[[@as number|number[] ]])
    if aura then
        if entry.itemList and not MissingBuffs.inCombat then
            RememberActive(entry, aura)
            local spellID = aura.spellId
            activeSpells[entry.key] = NRSKNUI:IsSafeValue(spellID) and spellID or nil
        end
        CheckExpiring(entry, 'Consumable', GetRemaining(aura))
    else
        activeSpells[entry.key] = nil
        Push(entry, 'Consumable')
    end
end

---@param entry MissingBuffs.Entry
function Evaluate.Utility(entry)
    if not MissingBuffs.inInstanceEntry then return end
    if not IsSpellKnown(GetCastSpell(entry) --[[@as number]]) then return end
    if entry.hideOnCooldown and IsOnCooldown(GetCastSpell(entry) --[[@as number]]) then return end
    if entry.check and not Checks[entry.check](entry) then return end
    Push(entry, 'Utility')
end

-- While auras are secret an untrackable entry is hidden, a glow-detectable one reads the action bar glow instead.
---@param entry MissingBuffs.Entry
---@param category MissingBuffs.Category
local function EvaluateEntry(entry, category)
    local settings = MissingBuffs:GetSettings(entry.key)
    if not settings.Enabled or not NRSKNUI.LoadConditions:Check(settings.LoadConditions) then return end
    if category ~= 'Raid' and category ~= 'Presence' and not PassesGates(entry) then return end

    if aurasSecret and not IsEntryTrackable(entry) then
        if entry.glowDetectable and IsSpellKnown(GetCastSpell(entry) --[[@as number]]) and IsSpellOverlayed(GetCastSpell(entry) --[[@as number]]) then
            Push(entry, category)
        end
        return
    end

    Evaluate[category](entry)
end

---@param category MissingBuffs.Category
---@return boolean
local function IsCategoryAllowed(category)
    if category ~= 'Consumable' then return true end
    -- Consumables are endgame upkeep, nothing to nag about while levelling.
    if UnitLevel('player') < GetMaxLevelForPlayerExpansion() then return false end
    local _, instanceType = IsInInstance()
    return instanceType ~= 'pvp' and instanceType ~= 'arena'
end

---Rebuild every category's results, returns seconds until the next timed change.
---@return number?
function MissingBuffs:Evaluate()
    db = self.db
    now = GetTime()
    aurasSecret = NRSKNUI:AreAurasSecret()
    nextChange = nil
    wipe(self.shown)

    BuildUnits()
    ReadEnchants()
    if self.heroChoicesDirty and heroChoiceSpells and ScanHeroChoices() then self.heroChoicesDirty = false end

    for _, category in ipairs(CATEGORY_ORDER) do
        local list = self.results[category]
        if list then wipe(list) else self.results[category] = {} end

        if IsCategoryAllowed(category) then
            for _, entry in ipairs(Data[category]) do
                EvaluateEntry(entry, category)
            end
        end
    end

    return nextChange
end

-- Aura Event Filtering --

function MissingBuffs:BuildTrackedSpells()
    local glowSpells = wipe(self.glowSpells)
    for _, list in pairs(Data) do
        for _, entry in ipairs(list) do
            if entry.glowDetectable and entry.class == playerClass then glowSpells[GetCastSpell(entry) --[[@as number]]] = true end
        end
    end

    local spells = wipe(self.trackedSpells)
    for _, category in ipairs({ 'Raid', 'Presence', 'Targeted' }) do
        for _, entry in ipairs(Data[category]) do
            local ids = entry.spellID
            if type(ids) == 'table' then
                for _, id in ipairs(ids) do spells[id] = true end
            elseif ids then
                spells[ids] = true
            end
            if entry.casterBuffID then spells[entry.casterBuffID] = true end
            for _, id in ipairs(entry.outdoorSpellID or {}) do spells[id] = true end
        end
    end
end

---Does a group unit's UNIT_AURA payload touch anything we track?
---@param updateInfo UnitAuraUpdateInfo?
---@return boolean
function MissingBuffs:IsTrackedAuraUpdate(updateInfo)
    if not updateInfo or NRSKNUI:IsSecretValue(updateInfo) then return false end

    local isFullUpdate = updateInfo.isFullUpdate
    if NRSKNUI:NotSecretValue(isFullUpdate) and isFullUpdate then return true end

    local added = updateInfo.addedAuras
    if added and NRSKNUI:NotSecretValue(added) then
        for _, aura in ipairs(added) do
            local spellID = NRSKNUI:NotSecretValue(aura) and aura.spellId
            if NRSKNUI:IsSafeValue(spellID) and self.trackedSpells[spellID] then return true end
        end
    end

    local instances = self.trackedInstances
    for _, list in ipairs({ updateInfo.removedAuraInstanceIDs, updateInfo.updatedAuraInstanceIDs }) do
        if NRSKNUI:NotSecretValue(list) then
            for _, instanceID in ipairs(list) do
                if NRSKNUI:IsSafeValue(instanceID) and instances[instanceID] then return true end
            end
        end
    end

    return false
end

---Should zoning into this instance open the instance-entry window?
---@return boolean
function MissingBuffs:IsInstanceEntryZone()
    local _, instanceType = IsInInstance()
    if instanceType ~= 'party' and instanceType ~= 'raid' then return false end
    if select(3, GetInstanceInfo()) == MissingBuffs.FollowerDifficulty then return false end
    return GetNumGroupMembers() > 1 and not IsChallengeModeActive()
end

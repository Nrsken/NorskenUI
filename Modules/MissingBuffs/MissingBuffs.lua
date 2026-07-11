---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class MissingBuffs: AceModule, AceEvent-3.0
local MBUFFS = NRSKNUI:NewModule("MissingBuffs", "AceEvent-3.0")

local LibSpec = NRSKNUI.Libs.LS
local LCG = NRSKNUI.Libs.LCG

local ipairs, pairs = ipairs, pairs
local select = select
local wipe = wipe
local UnitClass, UnitExists, UnitIsDeadOrGhost = UnitClass, UnitExists, UnitIsDeadOrGhost
local UnitIsConnected, UnitCanAssist, UnitIsPlayer = UnitIsConnected, UnitCanAssist, UnitIsPlayer
local UnitPosition = UnitPosition
local UnitIsUnit = UnitIsUnit
local UnitName = UnitName
local InCombatLockdown = InCombatLockdown
local GetNumGroupMembers = GetNumGroupMembers
local UnitFactionGroup = UnitFactionGroup
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local IsInRaid = IsInRaid
local GetTime = GetTime
local CreateFrame = CreateFrame
local GetInventorySlotInfo, GetInventoryItemLink = GetInventorySlotInfo, GetInventoryItemLink
local GetInventoryItemTexture = GetInventoryItemTexture
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local issecretvalue = issecretvalue
local GetInstanceInfo = GetInstanceInfo
local GetSpecializationInfoByID = GetSpecializationInfoByID
local C_Spell, C_SpellBook = C_Spell, C_SpellBook
local C_PetBattles, C_ChallengeMode = C_PetBattles, C_ChallengeMode
local C_Item = C_Item
local isEncounterInProgress = false
local AuraUtil = AuraUtil
local UIParent = UIParent
local C_Timer = C_Timer

local CHECK_THROTTLE = 0.25
local WEAPON_ENCHANT_ICON = 135697

local Data = NRSKNUI.MissingBuffsData
local SAFE_BUFFS = Data.SAFE_BUFFS
local RESTRICTED_BUFFS = Data.RESTRICTED_BUFFS
local TARGETED_BUFFS = Data.TARGETED_BUFFS
local SELF_BUFFS = Data.SELF_BUFFS
local PRESENCE_BUFFS = Data.PRESENCE_BUFFS
local POISON_IDS = Data.POISON_IDS
local ASSA_DOUBLE_POISON_TALENT = Data.ASSA_DOUBLE_POISON_TALENT
local WELL_FED_NAME = Data.WELL_FED_NAME
local HEARTY_WELL_FED_NAME = Data.HEARTY_WELL_FED_NAME
local SPEC_PRIMARY_STAT = Data.SPEC_PRIMARY_STAT
local RAID_BUFF_STAT_REQUIREMENT = Data.RAID_BUFF_STAT_REQUIREMENT

local UNIT_STRINGS = { raid = {}, party = {} }
for i = 1, 40 do
    UNIT_STRINGS.raid[i] = "raid" .. i
    if i <= 5 then
        UNIT_STRINGS.party[i] = "party" .. i
    end
end

local playerClass = nil
local isThrottled = false
local lastCheckTime = 0

local containerFrame = nil
local iconPool = {}
local activeIcons = {}
local currentMissingBuffs = {}

local isPreviewActive = false

local targetedContainerFrame = nil
local targetedIconPool = {}
local targetedActiveIcons = {}
local currentMissingTargetedBuffs = {}

local groupSpecData = {}
local groupClassesCache = {}

local expirationTicker = nil
local EXPIRATION_CHECK_INTERVAL = 3

local groupMembersCache = {}
local spellNameCache = {}
local countStringCache = {}

local safeMissingCache = {}
local restrictedMissingCache = {}
local targetedMissingCache = {}
local selfMissingCache = {}
local presenceMissingCache = {}
local categorySatisfiedCache = {}
local categoryExpiringCache = {}
local categoryExpTimeCache = {}
local groupSatisfiedCache = {}
local groupMissingBuffCache = {}

local checkContext = {
    trackingMode = "smart",
    groupSize = 0,
    isInRaid = false,
    inGroup = false,
    canCrossFaction = false,
    showOtherClass = true,
    checkGroup = true,
    units = nil,
    maxIndex = 0,
}

local CheckForMissingBuffs
local StopGlow

local function GetCachedSpellName(spellId)
    if not spellId then return nil end
    local name = spellNameCache[spellId]
    if name == nil then
        name = C_Spell.GetSpellName(spellId) or false
        spellNameCache[spellId] = name
    end
    return name or nil
end

local cachedIsInPvP = false
local cachedIsInInstance = false

local function UpdateInstanceCache()
    local _, instanceType = GetInstanceInfo()
    cachedIsInPvP = instanceType == "arena" or instanceType == "pvp"
    cachedIsInInstance = instanceType == "party" or instanceType == "raid" or instanceType == "scenario" or
        instanceType == "delve"
end

local function IsInPvPInstance()
    return cachedIsInPvP
end

local function IsInInstance()
    return cachedIsInInstance
end

local function CanCrossFactionBuff()
    return cachedIsInInstance
end

local function UpdateCheckContext()
    UpdateInstanceCache()
    checkContext.groupSize = GetNumGroupMembers()
    checkContext.isInRaid = IsInRaid()
    checkContext.inGroup = checkContext.groupSize > 0
    checkContext.canCrossFaction = cachedIsInInstance
    checkContext.trackingMode = MBUFFS.db and MBUFFS.db.TrackingMode or "smart"
    checkContext.showOtherClass = true
    checkContext.checkGroup = true
    checkContext.units = checkContext.isInRaid and UNIT_STRINGS.raid or UNIT_STRINGS.party
    checkContext.maxIndex = checkContext.isInRaid and checkContext.groupSize or (checkContext.groupSize - 1)
end

local playerFaction = nil
local function GetPlayerFaction()
    if not playerFaction then
        playerFaction = UnitFactionGroup("player")
    end
    return playerFaction
end

local function IsSameFaction(unit)
    if not unit or not UnitExists(unit) then return false end
    local unitFaction = UnitFactionGroup(unit)
    return unitFaction == GetPlayerFaction()
end

local function IsLoadConditionMet(loadCondition)
    if not loadCondition or loadCondition == "ALWAYS" then return true end
    local groupSize = GetNumGroupMembers()
    local inRaid = IsInRaid()
    local inGroup = groupSize > 0

    if loadCondition == "ANYGROUP" then
        return inGroup
    elseif loadCondition == "PARTY" then
        return inGroup and not inRaid
    elseif loadCondition == "RAID" then
        return inRaid
    elseif loadCondition == "NOGROUP" then
        return not inGroup
    end

    return true
end

local function ShouldShowGlow(settings, isMissing, expirationTime)
    if not settings then return true end

    if settings.GlowMode == "never" then
        return false
    elseif settings.GlowMode == "always" then
        return true
    elseif settings.GlowMode == "expiration" then
        if isMissing then
            return false
        end
        if settings.ExpirationMins <= 0 or not expirationTime then
            return false
        end
        local timeLeftMins = (expirationTime - GetTime()) / 60
        return timeLeftMins <= settings.ExpirationMins
    end

    return true
end

local function IsValidTarget(unit)
    if not UnitExists(unit) then return false end
    if UnitIsDeadOrGhost(unit) then return false end
    if not UnitIsConnected(unit) then return false end
    if not UnitIsPlayer(unit) then return false end
    if not UnitCanAssist("player", unit) then return false end
    if not CanCrossFactionBuff() and not IsSameFaction(unit) then return false end
    local playerInstanceId = select(4, UnitPosition("player"))
    local unitInstanceId = select(4, UnitPosition(unit))
    if playerInstanceId and unitInstanceId and playerInstanceId ~= unitInstanceId then
        return false
    end
    return true
end

local function GetGroupMembersByRole(targetType)
    wipe(groupMembersCache)
    if checkContext.groupSize == 0 then return groupMembersCache end

    local units = checkContext.units
    local maxIndex = checkContext.maxIndex

    for i = 1, maxIndex do
        local unit = units[i]
        if IsValidTarget(unit) then
            local role = UnitGroupRolesAssigned(unit)
            if targetType == "any" or
                (targetType == "tank" and role == "TANK") or
                (targetType == "healer" and role == "HEALER") then
                groupMembersCache[#groupMembersCache + 1] = unit
            end
        end
    end
    return groupMembersCache
end

local function CanPlayerBenefitFromBuff(buffKey)
    if not buffKey then return true end
    local statReq = RAID_BUFF_STAT_REQUIREMENT[buffKey]
    if not statReq then return true end
    local specId = NRSKNUI.MySpec.id
    if not specId then return true end
    local playerStat = SPEC_PRIMARY_STAT[specId]
    if not playerStat then return true end
    return playerStat == statReq
end

local function GetUnitSpecId(unit)
    local unitName, unitRealm = UnitName(unit)
    if not unitName then return nil end

    local specId = groupSpecData[unitName]
    if specId then return specId end

    if unitRealm and unitRealm ~= "" then
        local fullName = unitName .. "-" .. unitRealm
        specId = groupSpecData[fullName]
        if specId then return specId end
    end

    for storedName, storedSpecId in pairs(groupSpecData) do
        local baseName = storedName:match("^([^-]+)")
        if baseName == unitName then
            return storedSpecId
        end
    end

    return nil
end

local function CanUnitBenefitFromBuff(unit, buffKey)
    if not buffKey then return true end
    local statReq = RAID_BUFF_STAT_REQUIREMENT[buffKey]
    if not statReq then return true end

    local unitSpecId = GetUnitSpecId(unit)
    if not unitSpecId then return false end

    local unitStat = SPEC_PRIMARY_STAT[unitSpecId]
    if not unitStat then return false end

    return unitStat == statReq
end

---@param spellId number
---@param extraSpellIds? number[]
---@return boolean hasBuff
---@return number? expirationTime
local function PlayerHasBuff(spellId, extraSpellIds)
    if not spellId then return false, nil end

    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
    if auraData then
        local expTime = not issecretvalue(auraData.expirationTime) and auraData.expirationTime or nil
        return true, expTime
    end

    if extraSpellIds then
        for _, extraId in ipairs(extraSpellIds) do
            auraData = C_UnitAuras.GetPlayerAuraBySpellID(extraId)
            if auraData then
                local expTime = not issecretvalue(auraData.expirationTime) and auraData.expirationTime or nil
                return true, expTime
            end
        end
    end

    return false, nil
end

local function UnitHasBuff(unit, spellId, extraSpellIds)
    if not unit or not IsValidTarget(unit) or not UnitIsConnected(unit) then return true end

    local spellName = GetCachedSpellName(spellId)
    if not spellName then
        spellName = C_Spell.GetSpellName(spellId)
        if spellName then
            spellNameCache[spellId] = spellName
        end
    end

    if spellName then
        local auraData = C_UnitAuras.GetAuraDataBySpellName(unit, spellName, "HELPFUL")
        if auraData then
            return true
        end
    end

    if extraSpellIds then
        for _, extraId in ipairs(extraSpellIds) do
            local extraName = GetCachedSpellName(extraId)
            if extraName then
                local auraData = C_UnitAuras.GetAuraDataBySpellName(unit, extraName, "HELPFUL")
                if auraData then
                    return true
                end
            end
        end
    end

    return false
end

local function ShouldTrackBuff(buff)
    if buff.class and buff.class ~= playerClass then return false end

    if buff.specId then
        local currentSpecId = NRSKNUI.MySpec.id
        if not currentSpecId or currentSpecId ~= buff.specId then return false end
    end

    if buff.talentId and not C_SpellBook.IsSpellKnown(buff.talentId) then return false end

    local dbKey = buff.dbKey or buff.category
    if dbKey and MBUFFS.db then
        local settings = MBUFFS.db.Consumables and MBUFFS.db.Consumables[dbKey]
        if settings then
            if settings.Enabled == false then return false end
            if not IsLoadConditionMet(settings.LoadCondition) then return false end
        end
    end

    return true
end

local function GetCountString(buffed, total)
    if buffed < 0 then buffed = 0 end
    if total < 0 then total = 0 end
    if buffed > total then buffed = total end
    local key = buffed * 100 + total
    local cached = countStringCache[key]
    if not cached then
        cached = buffed .. "/" .. total
        countStringCache[key] = cached
    end
    return cached
end

local function CheckBuffWithCount(buff, expirationMins)
    local result = {
        isMissing = false,
        needsReapply = false,
        buffedCount = 0,
        totalCount = 0,
        buff = buff,
        expirationTime = nil,
    }

    local playerCanBenefit = CanPlayerBenefitFromBuff(buff.key)

    local hasBuff, expTime = PlayerHasBuff(buff.spellId, buff.extraBuffSpellIds)
    if playerCanBenefit then
        if hasBuff then
            result.buffedCount = 1
            result.expirationTime = expTime
        else
            result.isMissing = true
        end
    end

    if expTime and expTime > 0 and expirationMins > 0 then
        local timeLeft = (expTime - GetTime()) / 60
        if timeLeft <= expirationMins then
            result.needsReapply = true
        end
    end

    if buff.buffType == "raid" and not buff.onlySelf then
        local groupSize = GetNumGroupMembers()
        if groupSize > 0 then
            if playerCanBenefit then
                result.totalCount = 1
            end

            local units = IsInRaid() and UNIT_STRINGS.raid or UNIT_STRINGS.party
            local maxIndex = IsInRaid() and groupSize or (groupSize - 1)

            for i = 1, maxIndex do
                local unit = units[i]
                if not UnitIsUnit(unit, "player") and IsValidTarget(unit) and CanUnitBenefitFromBuff(unit, buff.key) then
                    result.totalCount = result.totalCount + 1
                    if UnitHasBuff(unit, buff.spellId, buff.extraBuffSpellIds) then
                        result.buffedCount = result.buffedCount + 1
                    elseif not result.isMissing then
                        if buff.ignoreRangeCheck or C_Spell.IsSpellInRange(buff.spellId, unit) then
                            result.isMissing = true
                        end
                    end
                end
            end
        else
            if playerCanBenefit then
                result.totalCount = 1
            end
        end
    else
        if playerCanBenefit then
            result.totalCount = 1
        end
    end

    return result
end

local function GetBuffDisplayText(buff, checkResult, showCount)
    if buff.text then return buff.text end

    if buff.buffType == "raid" and showCount and checkResult and checkResult.totalCount > 1 then
        local buffed = checkResult.buffedCount or 0
        local total = checkResult.totalCount or 0
        return GetCountString(buffed, total)
    end
    return ""
end

local function RebuildGroupClassCache()
    UpdateInstanceCache()
    wipe(groupClassesCache)

    if playerClass then
        groupClassesCache[playerClass] = true
    end

    local groupSize = GetNumGroupMembers()
    if groupSize == 0 then
        wipe(groupSpecData)
        return
    end

    local currentMembers = {}
    local units = IsInRaid() and UNIT_STRINGS.raid or UNIT_STRINGS.party
    local maxIndex = IsInRaid() and groupSize or (groupSize - 1)
    local canCrossFaction = cachedIsInInstance

    for i = 1, maxIndex do
        local unit = units[i]
        if UnitExists(unit) then
            local name = UnitName(unit)
            if name then
                currentMembers[name] = true
            end
            if canCrossFaction or IsSameFaction(unit) then
                local _, unitClass = UnitClass(unit)
                if unitClass then
                    groupClassesCache[unitClass] = true
                end
            end
        end
    end

    for playerName in pairs(groupSpecData) do
        if not currentMembers[playerName] then
            groupSpecData[playerName] = nil
        end
    end

    for playerName, specId in pairs(groupSpecData) do
        if specId and specId > 0 then
            local _, _, _, _, _, classFile = GetSpecializationInfoByID(specId)
            if classFile and not groupClassesCache[classFile] then
                local shouldAddClass = canCrossFaction
                if not shouldAddClass then
                    for i = 1, maxIndex do
                        local unit = units[i]
                        if UnitExists(unit) and UnitName(unit) == playerName and IsSameFaction(unit) then
                            shouldAddClass = true
                            break
                        end
                    end
                end
                if shouldAddClass then
                    groupClassesCache[classFile] = true
                end
            end
        end
    end
end

local function OnLibSpecUpdate(specId, _, _, playerName)
    if not playerName then return end

    if specId and specId > 0 then
        groupSpecData[playerName] = specId
    else
        groupSpecData[playerName] = nil
    end

    RebuildGroupClassCache()
    CheckForMissingBuffs()
end

local function HasWeaponEnchant(slot)
    local hasMain, mainExpMs, _, _, hasOff, offExpMs = GetWeaponEnchantInfo()

    local slotName, hasEnchant, expMs
    if slot == "main" then
        slotName = "MAINHANDSLOT"
        hasEnchant = hasMain
        expMs = mainExpMs
    elseif slot == "off" then
        slotName = "SECONDARYHANDSLOT"
        hasEnchant = hasOff
        expMs = offExpMs
    else
        return nil, nil, false, nil
    end

    local slotID = GetInventorySlotInfo(slotName)
    local itemLink = GetInventoryItemLink("player", slotID)
    if not itemLink then return nil, nil, false, nil end

    local equipLoc = select(9, C_Item.GetItemInfo(itemLink))
    if not equipLoc then return nil, nil, false, nil end

    if equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_HOLDABLE" then return nil, nil, false, nil end

    local icon = GetInventoryItemTexture("player", slotID)
    if not icon then return hasEnchant, nil, false, nil end

    local expirationTime = nil
    if hasEnchant and expMs and expMs > 0 then
        expirationTime = GetTime() + (expMs / 1000)
    end

    return hasEnchant, icon, true, expirationTime
end

local function CheckShamanLoad(class)
    if class ~= "SHAMAN" then
        return true
    else
        if NRSKNUI.MySpec.id == 262 and not C_SpellBook.IsSpellInSpellBook(318038) then return true end
        if NRSKNUI.MySpec.id == 264 and not C_SpellBook.IsSpellInSpellBook(382021) then return true end
    end
    return false
end

local function ShouldShowBuffForPrimaryStat(buffKey)
    if not buffKey then return true end
    local statReq = RAID_BUFF_STAT_REQUIREMENT[buffKey]
    if not statReq then return true end
    local specId = NRSKNUI.MySpec.id
    if not specId then return true end
    local playerStat = SPEC_PRIMARY_STAT[specId]
    if not playerStat then return true end
    return playerStat == statReq
end

local function CheckSafeBuffs()
    wipe(safeMissingCache)
    if not MBUFFS.db then return safeMissingCache end
    local consumablesDb = MBUFFS.db.Consumables or {}
    local raidBuffsDb = MBUFFS.db.RaidBuffs or {}
    local selfBuffsDb = MBUFFS.db.SelfBuffs or {}
    local poisonSettings = selfBuffsDb.Poisons
    local poisonsEnabled = poisonSettings.Enabled ~= false
    local poisonsLoadMet = IsLoadConditionMet(poisonSettings.LoadCondition)

    local showOtherClass = checkContext.showOtherClass
    local checkGroup = checkContext.checkGroup

    local groupBuffClasses = groupClassesCache
    local isRogue = playerClass == "ROGUE"
    local trackPoisons = isRogue and poisonsEnabled and poisonsLoadMet

    local lethalCount = 0
    local nonLethalCount = 0
    local specId = NRSKNUI.MySpec.id
    local isAssassination = specId == 259
    local hasDoublePoisonTalent = isAssassination and C_SpellBook.IsSpellKnown(ASSA_DOUBLE_POISON_TALENT)
    local requiredLethal = hasDoublePoisonTalent and 2 or 1

    for _, buff in ipairs(SAFE_BUFFS) do
        local buffType = buff.buffType

        if buffType == "poison" then
            if trackPoisons and PlayerHasBuff(buff.spellId) then
                if buff.poisonType == "lethal" then
                    lethalCount = lethalCount + 1
                else
                    nonLethalCount = nonLethalCount + 1
                end
            end
        elseif buffType == "raid" and buff.key then
            local buffSettings = raidBuffsDb[buff.key] or {}
            if buffSettings.Enabled ~= false and IsLoadConditionMet(buffSettings.LoadCondition) then
                local isOwnClassBuff = buff.class == playerClass
                if isOwnClassBuff then
                    local spellToCheck = buff.castSpellId or buff.spellId
                    if C_SpellBook.IsSpellKnown(spellToCheck) then
                        local result
                        if checkGroup then
                            result = CheckBuffWithCount(buff, buffSettings.ExpirationMins)
                        else
                            local hasBuff, expTime = PlayerHasBuff(buff.spellId, buff.extraBuffSpellIds)
                            result = {
                                isMissing = not hasBuff,
                                needsReapply = false,
                                buffedCount = hasBuff and 1 or 0,
                                totalCount = 1,
                                buff = buff,
                                expirationTime = expTime,
                            }
                            if expTime and expTime > 0 and buffSettings.ExpirationMins > 0 then
                                local timeLeftMins = (expTime - GetTime()) / 60
                                if timeLeftMins <= buffSettings.ExpirationMins then
                                    result.needsReapply = true
                                end
                            end
                        end
                        if result.isMissing or result.needsReapply then
                            local displayText = checkGroup and GetBuffDisplayText(buff, result, true) or ""
                            local showGlow = ShouldShowGlow(buffSettings, result.isMissing, result.expirationTime)
                            safeMissingCache[#safeMissingCache + 1] = {
                                buff = buff,
                                text = displayText,
                                checkResult = result,
                                showGlow = showGlow,
                                glowSettings = buffSettings,
                            }
                        end
                    end
                elseif showOtherClass and groupBuffClasses[buff.class] then
                    local isRaidLeaderMode = checkContext.trackingMode == "all"
                    if not isRaidLeaderMode and not ShouldShowBuffForPrimaryStat(buff.key) then
                        -- Skip buffs that don't benefit this spec in personal mode
                    elseif isRaidLeaderMode and checkGroup then
                        local result = CheckBuffWithCount(buff, buffSettings.ExpirationMins)
                        local isMissingFromGroup = result.buffedCount < result.totalCount
                        if isMissingFromGroup or result.needsReapply then
                            local displayText = GetBuffDisplayText(buff, result, true)
                            local showGlow = ShouldShowGlow(buffSettings, isMissingFromGroup, result.expirationTime)
                            safeMissingCache[#safeMissingCache + 1] = {
                                buff = buff,
                                text = displayText,
                                checkResult = result,
                                showGlow = showGlow,
                                glowSettings = buffSettings,
                            }
                        end
                    elseif not PlayerHasBuff(buff.spellId, buff.extraBuffSpellIds) then
                        local showGlow = ShouldShowGlow(buffSettings, true, nil)
                        safeMissingCache[#safeMissingCache + 1] = {
                            buff = buff,
                            text = "",
                            showGlow = showGlow,
                            glowSettings = buffSettings,
                        }
                    end
                end
            end
        elseif buffType == "weaponEnchant" and ShouldTrackBuff(buff) then
            local shamanLoad = CheckShamanLoad(playerClass)
            if shamanLoad then
                local hasEnchant, icon, hasItem, expirationTime = HasWeaponEnchant(buff.slot)
                if hasItem then
                    local enchantSettings = consumablesDb[buff.dbKey] or {}
                    local isMissing = not hasEnchant
                    local isExpiring = false

                    if hasEnchant and expirationTime and enchantSettings.ExpirationMins and enchantSettings.ExpirationMins > 0 then
                        local timeLeftMins = (expirationTime - GetTime()) / 60
                        if timeLeftMins <= enchantSettings.ExpirationMins then
                            isExpiring = true
                        end
                    end

                    if isMissing or isExpiring then
                        local showGlow = ShouldShowGlow(enchantSettings, isMissing, expirationTime)
                        safeMissingCache[#safeMissingCache + 1] = {
                            buff = {
                                spellId = 0,
                                text = buff.text,
                                iconTexture = icon or WEAPON_ENCHANT_ICON,
                            },
                            text = buff.text,
                            showGlow = showGlow,
                            glowSettings = enchantSettings,
                        }
                    end
                end
            end
        end
    end

    if trackPoisons then
        local lethalMissing = requiredLethal - lethalCount
        local showPoisonGlow = ShouldShowGlow(poisonSettings, true, nil)

        local hasAtrophicTalent = C_SpellBook.IsSpellKnown(POISON_IDS.ATROPHIC)
        local hasNumbingTalent = C_SpellBook.IsSpellKnown(POISON_IDS.NUMBING)
        local primaryNonLethal = hasAtrophicTalent and POISON_IDS.ATROPHIC or
            (hasNumbingTalent and POISON_IDS.NUMBING or nil)

        local wantCrippling = isAssassination and hasDoublePoisonTalent and poisonSettings.EnableCrippling
        local nonLethalRequired = 1
        if isAssassination and hasDoublePoisonTalent and wantCrippling then
            nonLethalRequired = 2
        end
        local nonLethalMissing = nonLethalRequired - nonLethalCount

        if lethalMissing > 0 then
            local lethalIcons = {}
            if isAssassination then
                lethalIcons[1] = POISON_IDS.DEADLY
                if hasDoublePoisonTalent then
                    lethalIcons[2] = C_SpellBook.IsSpellKnown(POISON_IDS.AMPLIFYING) and POISON_IDS.AMPLIFYING or
                        POISON_IDS.INSTANT
                end
            else
                lethalIcons[1] = POISON_IDS.INSTANT
            end

            for i = 1, lethalMissing do
                local iconSpellId = lethalIcons[i] or lethalIcons[1]
                safeMissingCache[#safeMissingCache + 1] = {
                    buff = { spellId = iconSpellId, text = "" },
                    text = "",
                    showGlow = showPoisonGlow,
                    glowSettings = poisonSettings,
                }
            end
        end

        if nonLethalMissing > 0 and primaryNonLethal then
            local nonLethalIcons = {}
            nonLethalIcons[1] = primaryNonLethal
            if wantCrippling then
                nonLethalIcons[2] = POISON_IDS.CRIPPLING
            end

            for i = 1, nonLethalMissing do
                local iconSpellId = nonLethalIcons[i] or nonLethalIcons[1]
                safeMissingCache[#safeMissingCache + 1] = {
                    buff = { spellId = iconSpellId, text = "" },
                    text = "",
                    showGlow = showPoisonGlow,
                    glowSettings = poisonSettings,
                }
            end
        end
    end

    return safeMissingCache
end

local function PlayerHasFoodBuff()
    local hasBuff = false
    local expirationTime = nil

    AuraUtil.ForEachAura("player", "HELPFUL", nil, function(auraInfo)
        if not auraInfo or not auraInfo.name then return false end
        if issecretvalue(auraInfo.name) then return false end

        if auraInfo.name == WELL_FED_NAME or auraInfo.name == HEARTY_WELL_FED_NAME then
            hasBuff = true
            expirationTime = auraInfo.expirationTime
            return true
        end
        return false
    end, true)

    return hasBuff, expirationTime
end

local function PlayerHasItemInBags(itemId)
    if not itemId then return false end
    local count = C_Item.GetItemCount(itemId, false, false, false)
    return count and count > 0
end

local function CheckRestrictedBuffs()
    wipe(restrictedMissingCache)
    wipe(categorySatisfiedCache)
    wipe(categoryExpiringCache)
    wipe(categoryExpTimeCache)
    if not MBUFFS.db then return restrictedMissingCache end
    if NRSKNUI:IsFullyRestricted() or InCombatLockdown() or C_ChallengeMode.IsChallengeModeActive() or isEncounterInProgress then
        return restrictedMissingCache
    end
    if UnitLevel("player") < GetMaxLevelForLatestExpansion() then
        return restrictedMissingCache
    end

    local consumablesDb = MBUFFS.db.Consumables or {}

    local foodSettings = consumablesDb.Food or {}
    local trackFood = foodSettings.Enabled ~= false and IsLoadConditionMet(foodSettings.LoadCondition)

    if trackFood then
        local hasFoodBuff, foodExpTime = PlayerHasFoodBuff()
        if hasFoodBuff then
            categorySatisfiedCache["Food"] = true
            categoryExpTimeCache["Food"] = foodExpTime

            if foodSettings.ExpirationMins > 0 and foodExpTime and foodExpTime > 0 then
                local timeLeftMins = (foodExpTime - GetTime()) / 60
                if timeLeftMins <= foodSettings.ExpirationMins then
                    categoryExpiringCache["Food"] = true
                end
            end
        end
    end

    for _, buff in ipairs(RESTRICTED_BUFFS) do
        if ShouldTrackBuff(buff) then
            if buff.category then
                if not categorySatisfiedCache[buff.category] then
                    local hasBuff, expTime = PlayerHasBuff(buff.spellId, buff.extraBuffSpellIds)
                    if hasBuff then
                        categorySatisfiedCache[buff.category] = true
                        categoryExpTimeCache[buff.category] = expTime

                        local catSettings = consumablesDb[buff.category]
                        if catSettings.ExpirationMins > 0 and expTime and expTime > 0 then
                            local timeLeftMins = (expTime - GetTime()) / 60
                            if timeLeftMins <= catSettings.ExpirationMins then
                                categoryExpiringCache[buff.category] = true
                            end
                        end
                    end
                end
            elseif buff.buffType == "self" then
                if not PlayerHasBuff(buff.spellId, buff.extraBuffSpellIds) then
                    restrictedMissingCache[#restrictedMissingCache + 1] = {
                        buff = buff,
                        text = "",
                        showGlow = true,
                        glowSettings = {},
                    }
                end
            end
        end
    end

    if trackFood then
        local isFoodMissing = not categorySatisfiedCache["Food"]
        local isFoodExpiring = categoryExpiringCache["Food"]

        if isFoodMissing or isFoodExpiring then
            local showGlow = ShouldShowGlow(foodSettings, isFoodMissing, categoryExpTimeCache["Food"])
            restrictedMissingCache[#restrictedMissingCache + 1] = {
                buff = {
                    spellId = 19705,
                    text = "",
                },
                text = "",
                showGlow = showGlow,
                glowSettings = foodSettings,
            }
        end
    end

    local categorySeen = {}
    for _, buff in ipairs(RESTRICTED_BUFFS) do
        if buff.category and ShouldTrackBuff(buff) then
            local isMissing = not categorySatisfiedCache[buff.category]
            local isExpiring = categoryExpiringCache[buff.category]

            if (isMissing or isExpiring) and not categorySeen[buff.category] then
                if buff.itemId and not PlayerHasItemInBags(buff.itemId) then
                    -- Skip if item required but not in bags
                else
                    categorySeen[buff.category] = true
                    local catSettings = consumablesDb[buff.category] or {}
                    local showGlow = ShouldShowGlow(catSettings, isMissing, categoryExpTimeCache[buff.category])
                    restrictedMissingCache[#restrictedMissingCache + 1] = {
                        buff = {
                            spellId = buff.spellId,
                            text = "",
                        },
                        text = "",
                        showGlow = showGlow,
                        glowSettings = catSettings,
                    }
                end
            end
        end
    end

    return restrictedMissingCache
end

local function CheckTargetedBuffs()
    wipe(targetedMissingCache)
    if not MBUFFS.db then return targetedMissingCache end

    local targetedSettings = MBUFFS.db.TargetedBuffs
    if not targetedSettings or targetedSettings.Enabled == false then return targetedMissingCache end

    local restrictionState = NRSKNUI:GetRestrictionState()
    local isRestricted = InCombatLockdown() or isEncounterInProgress or restrictionState == 1 or restrictionState == 2

    local targetedBuffsDb = MBUFFS.db.TargetedBuffSettings or {}
    local currentSpecId = NRSKNUI.MySpec.id
    local inGroup = checkContext.groupSize > 0

    for _, buff in ipairs(TARGETED_BUFFS) do
        if buff.class == playerClass and buff.key then
            if buff.secret and isRestricted then
                -- Skip secret buffs when restricted (can't check aura data reliably)
            elseif not inGroup and not buff.includeSelf then
                -- Skip buffs that require group targets when solo
            else
                local buffSettings = targetedBuffsDb[buff.key] or {}
                local specMatch = not buff.specId or currentSpecId == buff.specId
                local talentKnown = not buff.talentId or C_SpellBook.IsSpellKnown(buff.talentId)
                local spellKnown = C_SpellBook.IsSpellKnown(buff.spellId)
                local excludedByTalent = buff.excludeIfTalent and C_SpellBook.IsSpellKnown(buff.excludeIfTalent)

                if buffSettings.Enabled ~= false and specMatch and talentKnown and spellKnown and not excludedByTalent then
                    local isMissing = false

                    if buff.selfBuffSpellId then
                        isMissing = not PlayerHasBuff(buff.selfBuffSpellId)
                    else
                        local buffedCount = 0
                        local targetCount = 0
                        local playerIncluded = false

                        if inGroup then
                            local targets = GetGroupMembersByRole(buff.targetType)
                            targetCount = #targets

                            for _, unit in ipairs(targets) do
                                if UnitIsUnit(unit, "player") then
                                    playerIncluded = true
                                end
                                if buff.excludeSelf and UnitIsUnit(unit, "player") then
                                    targetCount = targetCount - 1
                                elseif UnitHasBuff(unit, buff.spellId) then
                                    buffedCount = buffedCount + 1
                                end
                            end
                        end

                        if buff.includeSelf and not playerIncluded then
                            targetCount = targetCount + 1
                            if PlayerHasBuff(buff.spellId) then
                                buffedCount = buffedCount + 1
                            end
                        end

                        local requiredTargets = buff.maxTargets
                        if targetCount < requiredTargets then
                            requiredTargets = targetCount
                        end

                        isMissing = buffedCount < requiredTargets and requiredTargets > 0
                    end

                    if isMissing then
                        targetedMissingCache[#targetedMissingCache + 1] = {
                            buff = buff,
                            text = "",
                            showGlow = true,
                            glowSettings = buffSettings,
                        }
                    end
                end
            end
        end
    end

    return targetedMissingCache
end

local function HasWeaponImbue(enchantId)
    if not enchantId then return false end
    local _, _, _, mainEnchantId, _, _, _, offEnchantId = GetWeaponEnchantInfo()
    return mainEnchantId == enchantId or offEnchantId == enchantId
end

local ELEMENTAL_ORBIT_TALENT = Data.ELEMENTAL_ORBIT_TALENT
local EARTH_SHIELD_SELF_BUFF = Data.EARTH_SHIELD_SELF_BUFF

local function CheckSelfBuffs()
    wipe(selfMissingCache)
    wipe(groupSatisfiedCache)
    wipe(groupMissingBuffCache)
    if not MBUFFS.db then return selfMissingCache end

    local restrictionState = NRSKNUI:GetRestrictionState()
    local isRestricted = InCombatLockdown() or isEncounterInProgress or restrictionState == 1 or restrictionState == 2

    local selfBuffsDb = MBUFFS.db.SelfBuffs or {}
    local currentSpecId = NRSKNUI.MySpec.id

    local hasElementalOrbit = playerClass == "SHAMAN" and C_SpellBook.IsSpellKnown(ELEMENTAL_ORBIT_TALENT)

    for _, buff in ipairs(SELF_BUFFS) do
        if buff.secret and isRestricted then
            -- Skip secret buffs when restricted
        elseif buff.class == playerClass and buff.key then
            local buffSettings = selfBuffsDb[buff.key] or {}
            local specMatch = not buff.specId or currentSpecId == buff.specId
            local talentKnown = not buff.talentId or C_SpellBook.IsSpellKnown(buff.talentId)
            local spellKnown = buff.spellId and C_SpellBook.IsSpellKnown(buff.spellId)
            local spellCast = buff.castSpellId and C_SpellBook.IsSpellKnown(buff.castSpellId)

            if buffSettings.Enabled ~= false and IsLoadConditionMet(buffSettings.LoadCondition) and specMatch and talentKnown and (spellKnown or spellCast) then
                local hasBuff = false

                if buff.enchantId then
                    hasBuff = HasWeaponImbue(buff.enchantId)
                elseif buff.groupId == "ShamanShield" and buff.key == "EarthShieldSelf" and hasElementalOrbit then
                    hasBuff = PlayerHasBuff(EARTH_SHIELD_SELF_BUFF)
                else
                    hasBuff = PlayerHasBuff(buff.spellId)
                end

                if buff.groupId then
                    if buff.groupId == "ShamanShield" and hasElementalOrbit then
                        local isEarthShield = buff.key == "EarthShieldSelf"
                        local isOtherShield = buff.key == "LightningShield" or buff.key == "WaterShield"

                        if isEarthShield then
                            if hasBuff then
                                groupSatisfiedCache["ShamanShieldEO_ES"] = true
                            else
                                groupMissingBuffCache["ShamanShieldEO_ES"] = { buff = buff, settings = buffSettings }
                            end
                        elseif isOtherShield then
                            if not groupSatisfiedCache["ShamanShieldEO_Other"] then
                                if hasBuff then
                                    groupSatisfiedCache["ShamanShieldEO_Other"] = true
                                elseif not groupMissingBuffCache["ShamanShieldEO_Other"] then
                                    groupMissingBuffCache["ShamanShieldEO_Other"] = {
                                        buff = buff,
                                        settings =
                                            buffSettings
                                    }
                                end
                            end
                        end
                    else
                        if not groupSatisfiedCache[buff.groupId] then
                            if hasBuff then
                                groupSatisfiedCache[buff.groupId] = true
                            elseif not groupMissingBuffCache[buff.groupId] then
                                groupMissingBuffCache[buff.groupId] = { buff = buff, settings = buffSettings }
                            end
                        end
                    end
                elseif not hasBuff then
                    local showGlow = ShouldShowGlow(buffSettings, true, nil)
                    selfMissingCache[#selfMissingCache + 1] = {
                        buff = buff,
                        text = "",
                        showGlow = showGlow,
                        glowSettings = buffSettings,
                    }
                end
            end
        end
    end

    for groupId, data in pairs(groupMissingBuffCache) do
        if not groupSatisfiedCache[groupId] then
            local showGlow = ShouldShowGlow(data.settings, true, nil)
            selfMissingCache[#selfMissingCache + 1] = {
                buff = data.buff,
                text = "",
                showGlow = showGlow,
                glowSettings = data.settings,
            }
        end
    end

    return selfMissingCache
end

local function CheckPresenceBuffs()
    wipe(presenceMissingCache)
    if not MBUFFS.db then return presenceMissingCache end

    if not checkContext.isInRaid then return presenceMissingCache end
    if checkContext.trackingMode ~= "all" then return presenceMissingCache end

    local restrictionState = NRSKNUI:GetRestrictionState()
    local isRestricted = InCombatLockdown() or isEncounterInProgress or restrictionState == 1 or restrictionState == 2

    local presenceBuffsDb = MBUFFS.db.PresenceBuffs or {}
    local showOtherClass = checkContext.showOtherClass
    local checkGroup = checkContext.checkGroup

    local units = checkContext.units
    local maxIndex = checkContext.maxIndex

    for _, buff in ipairs(PRESENCE_BUFFS) do
        if buff.secret and isRestricted then
            -- Skip secret buffs when restricted
        else
            local isOwnClassBuff = buff.providerClass == playerClass
            local shouldTrack = isOwnClassBuff or (showOtherClass and groupClassesCache[buff.providerClass])

            if buff.key and shouldTrack then
            local buffSettings = presenceBuffsDb[buff.key] or {}
            local buffEnabled = buffSettings.Enabled ~= false

            if buffEnabled then
                local hasBuff = false

                if buff.checkAnyGroupMember and checkGroup then
                    for i = 1, maxIndex do
                        local unit = units[i]
                        if IsValidTarget(unit) and UnitHasBuff(unit, buff.spellId) then
                            hasBuff = true
                            break
                        end
                    end

                    if not hasBuff then
                        hasBuff = PlayerHasBuff(buff.spellId)
                    end
                else
                    hasBuff = PlayerHasBuff(buff.spellId)
                end

                if not hasBuff then
                    local showGlow = ShouldShowGlow(buffSettings, true, nil)
                    presenceMissingCache[#presenceMissingCache + 1] = {
                        buff = buff,
                        text = "",
                        showGlow = showGlow,
                        glowSettings = buffSettings,
                    }
                end
            end
        end
        end
    end

    return presenceMissingCache
end

local function CreateIcon()
    local raidDb = MBUFFS.db.RaidBuffDisplay
    local iconFrame = NRSKNUI:CreateIconFrame(containerFrame, raidDb.IconSize)
    NRSKNUI:SetTextFont(iconFrame.text, NRSKNUI:GetEffectiveFont(raidDb), raidDb.FontSize, raidDb.FontOutline, raidDb.FontShadow)
    iconFrame.text:SetTextColor(1, 1, 1, 1)
    iconFrame.text:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    iconFrame:Hide()
    return iconFrame
end

local function AcquireIcon()
    for _, icon in ipairs(iconPool) do
        if not icon.inUse then
            icon.inUse = true
            return icon
        end
    end

    local newIcon = CreateIcon()
    newIcon.inUse = true
    iconPool[#iconPool + 1] = newIcon
    return newIcon
end

local function ReleaseIcon(icon)
    StopGlow(icon)
    icon.inUse = false
    icon:Hide()
    icon:ClearAllPoints()
end

local function ReleaseAllIcons()
    for _, icon in ipairs(activeIcons) do
        ReleaseIcon(icon)
    end
    wipe(activeIcons)
end

local function CreateContainerFrame()
    if containerFrame then return end
    local raidDb = MBUFFS.db.RaidBuffDisplay
    containerFrame = CreateFrame("Frame", "NRSKNUI_MissingBuffContainer", UIParent)
    containerFrame:SetSize(400, raidDb.IconSize)
    NRSKNUI:ApplyFramePosition(containerFrame, raidDb.Position, raidDb)
    containerFrame:Hide()
end

local function CreateTargetedContainerFrame()
    if targetedContainerFrame then return end
    local targetedDb = MBUFFS.db.TargetedBuffDisplay
    targetedContainerFrame = CreateFrame("Frame", "NRSKNUI_TargetedBuffContainer", UIParent)
    targetedContainerFrame:SetSize(400, targetedDb.IconSize)
    NRSKNUI:ApplyFramePosition(targetedContainerFrame, targetedDb.Position, targetedDb)
    targetedContainerFrame:Hide()
end

local function CreateTargetedIcon()
    local targetedDb = MBUFFS.db.TargetedBuffDisplay
    local iconFrame = NRSKNUI:CreateIconFrame(targetedContainerFrame, targetedDb.IconSize)
    iconFrame:Hide()
    return iconFrame
end

local function AcquireTargetedIcon()
    for _, icon in ipairs(targetedIconPool) do
        if not icon.inUse then
            icon.inUse = true
            return icon
        end
    end

    local newIcon = CreateTargetedIcon()
    newIcon.inUse = true
    targetedIconPool[#targetedIconPool + 1] = newIcon
    return newIcon
end

local function ReleaseTargetedIcon(icon)
    StopGlow(icon)
    icon.inUse = false
    icon:Hide()
    icon:ClearAllPoints()
end

local function ReleaseAllTargetedIcons()
    for _, icon in ipairs(targetedActiveIcons) do
        ReleaseTargetedIcon(icon)
    end
    wipe(targetedActiveIcons)
end

local function StopAllGlowTypes(iconFrame)
    if not LCG or not iconFrame then return end
    LCG.PixelGlow_Stop(iconFrame)
    LCG.AutoCastGlow_Stop(iconFrame)
    LCG.ButtonGlow_Stop(iconFrame)
end

StopGlow = function(iconFrame)
    if not iconFrame then return end
    StopAllGlowTypes(iconFrame)
    iconFrame.glowActive = false
    iconFrame.glowType = nil
end

local function StartGlow(iconFrame, glowSettings)
    if not LCG or not iconFrame or not glowSettings then return end

    if glowSettings.GlowEnabled == false then
        if iconFrame.glowActive then
            StopGlow(iconFrame)
        end
        return
    end

    local glowType = glowSettings.GlowType
    if iconFrame.glowActive and iconFrame.glowType and iconFrame.glowType ~= glowType then
        StopAllGlowTypes(iconFrame)
    end

    if glowType == "pixel" then
        LCG.PixelGlow_Start(iconFrame, glowSettings.GlowColor, glowSettings.GlowLines, glowSettings.GlowFrequency,
            glowSettings.GlowLength, glowSettings.GlowThickness, 0, 0, glowSettings.GlowBorder, nil)
    elseif glowType == "autocast" then
        LCG.AutoCastGlow_Start(iconFrame, glowSettings.GlowColor, glowSettings.GlowLines, glowSettings.GlowFrequency,
            glowSettings.GlowScale, 1, 1, nil)
    elseif glowType == "button" then
        LCG.ButtonGlow_Start(iconFrame, glowSettings.GlowColor, glowSettings.GlowFrequency)
    elseif glowType == "proc" then
        LCG.ProcGlow_Start(iconFrame, {
            color = glowSettings.GlowColor,
            startAnim = glowSettings.GlowStartAnim ~= false,
            duration = glowSettings.GlowDuration or 1
        })
    end

    iconFrame.glowActive = true
    iconFrame.glowType = glowType
end

local function UpdateTargetedIconAppearance(iconFrame, buff, showGlow, glowSettings)
    local texture = C_Spell.GetSpellTexture(buff.spellId)
    if not texture then texture = buff.iconTexture or WEAPON_ENCHANT_ICON end
    iconFrame.icon:SetTexture(texture)

    local targetedDb = MBUFFS.db.TargetedBuffDisplay
    iconFrame:SetSize(targetedDb.IconSize, targetedDb.IconSize)
    iconFrame.icon:SetAllPoints(iconFrame)

    if showGlow then
        StartGlow(iconFrame, glowSettings)
    else
        StopGlow(iconFrame)
    end
end

local function ArrangeTargetedIcons()
    if not targetedContainerFrame then return end
    local targetedDb = MBUFFS.db.TargetedBuffDisplay or {}
    local count = #targetedActiveIcons

    if count == 0 then
        targetedContainerFrame:Hide()
        return
    end

    local iconSize = targetedDb.IconSize
    local spacing = targetedDb.IconSpacing
    local totalWidth = (iconSize * count) + (spacing * (count - 1))
    targetedContainerFrame:SetSize(totalWidth, iconSize)

    local growDirection = targetedDb.GrowDirection
    local position = targetedDb.Position

    for i, iconFrame in ipairs(targetedActiveIcons) do
        iconFrame:ClearAllPoints()

        if growDirection == "LEFT" then
            local xOffset = -((i - 1) * (iconSize + spacing))
            iconFrame:SetPoint("RIGHT", targetedContainerFrame, "RIGHT", xOffset, 0)
        elseif growDirection == "RIGHT" then
            local xOffset = (i - 1) * (iconSize + spacing)
            iconFrame:SetPoint("LEFT", targetedContainerFrame, "LEFT", xOffset, 0)
        else
            local startX = -totalWidth / 2 + iconSize / 2
            local xOffset = startX + (i - 1) * (iconSize + spacing)
            iconFrame:SetPoint("CENTER", targetedContainerFrame, "CENTER", xOffset, 0)
        end
        iconFrame:Show()
    end

    local parent = NRSKNUI:ResolveAnchorFrame(targetedDb.anchorFrameType, targetedDb.ParentFrame)

    targetedContainerFrame:ClearAllPoints()

    if growDirection == "RIGHT" then
        targetedContainerFrame:SetPoint("LEFT", parent, position.AnchorTo, position.XOffset, position.YOffset)
    elseif growDirection == "LEFT" then
        targetedContainerFrame:SetPoint("RIGHT", parent, position.AnchorTo, position.XOffset, position.YOffset)
    else
        targetedContainerFrame:SetPoint(position.AnchorFrom, parent, position.AnchorTo, position.XOffset,
            position.YOffset)
    end

    targetedContainerFrame:SetFrameStrata(targetedDb.Strata)
    NRSKNUI:SnapFrameToPixels(targetedContainerFrame, targetedDb.ForcePixelPerfect)

    targetedContainerFrame:Show()
end

local function ShowTargetedBuffs(missingList, updateInPlace)
    if updateInPlace then
        local newCount = #missingList
        local oldCount = #targetedActiveIcons

        for i, entry in ipairs(missingList) do
            if i <= oldCount then
                UpdateTargetedIconAppearance(targetedActiveIcons[i], entry.buff, entry.showGlow, entry.glowSettings)
            else
                local iconFrame = AcquireTargetedIcon()
                UpdateTargetedIconAppearance(iconFrame, entry.buff, entry.showGlow, entry.glowSettings)
                targetedActiveIcons[#targetedActiveIcons + 1] = iconFrame
            end
        end

        while #targetedActiveIcons > newCount do
            local icon = targetedActiveIcons[#targetedActiveIcons]
            ReleaseTargetedIcon(icon)
            targetedActiveIcons[#targetedActiveIcons] = nil
        end
    else
        ReleaseAllTargetedIcons()
        for _, entry in ipairs(missingList) do
            local iconFrame = AcquireTargetedIcon()
            UpdateTargetedIconAppearance(iconFrame, entry.buff, entry.showGlow, entry.glowSettings)
            targetedActiveIcons[#targetedActiveIcons + 1] = iconFrame
        end
    end
    ArrangeTargetedIcons()
end

local function HideTargetedBuffIcons()
    ReleaseAllTargetedIcons()
    if targetedContainerFrame then
        targetedContainerFrame:Hide()
    end
end

local function UpdateIconAppearance(iconFrame, buff, text, showGlow, glowSettings)
    local texture = C_Spell.GetSpellTexture(buff.spellId)
    if not texture then texture = buff.iconTexture or WEAPON_ENCHANT_ICON end
    iconFrame.icon:SetTexture(texture)

    local raidDb = MBUFFS.db.RaidBuffDisplay
    NRSKNUI:SetTextFont(iconFrame.text, NRSKNUI:GetEffectiveFont(raidDb), raidDb.FontSize, raidDb.FontOutline, raidDb.FontShadow)
    iconFrame.text:SetText(text or buff.text or "")

    iconFrame:SetSize(MBUFFS.db.RaidBuffDisplay.IconSize, MBUFFS.db.RaidBuffDisplay.IconSize)
    iconFrame.icon:SetAllPoints(iconFrame)

    if showGlow then
        StartGlow(iconFrame, glowSettings)
    else
        StopGlow(iconFrame)
    end
end

local function ArrangeIcons()
    if not containerFrame then return end
    local raidDb = MBUFFS.db.RaidBuffDisplay or {}
    local count = #activeIcons

    if count == 0 then
        containerFrame:Hide()
        return
    end

    local iconSize = raidDb.IconSize
    local spacing = raidDb.IconSpacing
    local totalWidth = (iconSize * count) + (spacing * (count - 1))
    containerFrame:SetSize(totalWidth, iconSize)

    local growDirection = raidDb.GrowDirection
    local position = raidDb.Position

    for i, iconFrame in ipairs(activeIcons) do
        iconFrame:ClearAllPoints()

        if growDirection == "LEFT" then
            local xOffset = -((i - 1) * (iconSize + spacing))
            iconFrame:SetPoint("RIGHT", containerFrame, "RIGHT", xOffset, 0)
        elseif growDirection == "RIGHT" then
            local xOffset = (i - 1) * (iconSize + spacing)
            iconFrame:SetPoint("LEFT", containerFrame, "LEFT", xOffset, 0)
        else
            local startX = -totalWidth / 2 + iconSize / 2
            local xOffset = startX + (i - 1) * (iconSize + spacing)
            iconFrame:SetPoint("CENTER", containerFrame, "CENTER", xOffset, 0)
        end
        iconFrame:Show()
    end

    local parent = NRSKNUI:ResolveAnchorFrame(raidDb.anchorFrameType, raidDb.ParentFrame)

    containerFrame:ClearAllPoints()

    if growDirection == "RIGHT" then
        containerFrame:SetPoint("LEFT", parent, position.AnchorTo, position.XOffset, position.YOffset)
    elseif growDirection == "LEFT" then
        containerFrame:SetPoint("RIGHT", parent, position.AnchorTo, position.XOffset, position.YOffset)
    else
        containerFrame:SetPoint(position.AnchorFrom, parent, position.AnchorTo, position.XOffset, position.YOffset)
    end

    containerFrame:SetFrameStrata(raidDb.Strata)
    NRSKNUI:SnapFrameToPixels(containerFrame, raidDb.ForcePixelPerfect)

    containerFrame:Show()
end

local function ShowMissingBuffs(missingList, updateInPlace)
    if updateInPlace then
        local newCount = #missingList
        local oldCount = #activeIcons

        for i, entry in ipairs(missingList) do
            if i <= oldCount then
                UpdateIconAppearance(activeIcons[i], entry.buff, entry.text, entry.showGlow, entry.glowSettings)
            else
                local iconFrame = AcquireIcon()
                UpdateIconAppearance(iconFrame, entry.buff, entry.text, entry.showGlow, entry.glowSettings)
                activeIcons[#activeIcons + 1] = iconFrame
            end
        end

        while #activeIcons > newCount do
            local icon = activeIcons[#activeIcons]
            ReleaseIcon(icon)
            activeIcons[#activeIcons] = nil
        end
    else
        ReleaseAllIcons()
        for _, entry in ipairs(missingList) do
            local iconFrame = AcquireIcon()
            UpdateIconAppearance(iconFrame, entry.buff, entry.text, entry.showGlow, entry.glowSettings)
            activeIcons[#activeIcons + 1] = iconFrame
        end
    end
    ArrangeIcons()
end

local function HideMissingBuffIcons()
    ReleaseAllIcons()
    if containerFrame then
        containerFrame:Hide()
    end
    HideTargetedBuffIcons()
end

local function IsTrackingPaused()
    return isPreviewActive
end

local function CheckCombatSafeElements()
    if IsTrackingPaused() then return end
    if not MBUFFS.db or not MBUFFS.db.Enabled then return end
    if UnitIsDeadOrGhost("player") or C_PetBattles.IsInBattle() or IsInPvPInstance() then return end

    local safeMissing = CheckSafeBuffs()
    wipe(currentMissingBuffs)
    for _, entry in ipairs(safeMissing) do
        currentMissingBuffs[#currentMissingBuffs + 1] = entry
    end

    if #currentMissingBuffs > 0 then
        ShowMissingBuffs(currentMissingBuffs, true)
    else
        ReleaseAllIcons()
        ArrangeIcons()
    end

    local targetedMissing = CheckTargetedBuffs()
    wipe(currentMissingTargetedBuffs)
    for _, entry in ipairs(targetedMissing) do
        currentMissingTargetedBuffs[#currentMissingTargetedBuffs + 1] = entry
    end

    if #currentMissingTargetedBuffs > 0 then
        ShowTargetedBuffs(currentMissingTargetedBuffs, true)
    else
        HideTargetedBuffIcons()
    end
end

CheckForMissingBuffs = function()
    if IsTrackingPaused() then return end
    local currentTime = GetTime()
    if currentTime - lastCheckTime < CHECK_THROTTLE then
        if not isThrottled then
            isThrottled = true
            C_Timer.After(CHECK_THROTTLE, function()
                isThrottled = false
                CheckForMissingBuffs()
            end)
        end
        return
    end
    lastCheckTime = currentTime

    UpdateCheckContext()

    if not MBUFFS.db or not MBUFFS.db.Enabled then
        HideMissingBuffIcons()
        return
    end
    if InCombatLockdown() or isEncounterInProgress then
        CheckCombatSafeElements()
        return
    end
    if cachedIsInPvP or UnitIsDeadOrGhost("player") or C_PetBattles.IsInBattle() then
        HideMissingBuffIcons()
        return
    end

    wipe(currentMissingBuffs)

    local safeMissing = CheckSafeBuffs()
    for _, entry in ipairs(safeMissing) do
        currentMissingBuffs[#currentMissingBuffs + 1] = entry
    end

    local restrictedMissing = CheckRestrictedBuffs()
    for _, entry in ipairs(restrictedMissing) do
        currentMissingBuffs[#currentMissingBuffs + 1] = entry
    end

    local selfMissing = CheckSelfBuffs()
    for _, entry in ipairs(selfMissing) do
        currentMissingBuffs[#currentMissingBuffs + 1] = entry
    end

    local presenceMissing = CheckPresenceBuffs()
    for _, entry in ipairs(presenceMissing) do
        currentMissingBuffs[#currentMissingBuffs + 1] = entry
    end

    if #currentMissingBuffs > 0 then
        ShowMissingBuffs(currentMissingBuffs, true)
    else
        HideMissingBuffIcons()
    end

    wipe(currentMissingTargetedBuffs)
    local targetedMissing = CheckTargetedBuffs()
    for _, entry in ipairs(targetedMissing) do
        currentMissingTargetedBuffs[#currentMissingTargetedBuffs + 1] = entry
    end

    if #currentMissingTargetedBuffs > 0 then
        ShowTargetedBuffs(currentMissingTargetedBuffs, true)
    else
        HideTargetedBuffIcons()
    end
end

local function OnAuraChange(unit, updateInfo)
    if not MBUFFS.db or not MBUFFS.db.Enabled then return end
    if IsTrackingPaused() then return end
    if unit ~= "player" and not (unit and (unit:find("party") or unit:find("raid"))) then return end

    if InCombatLockdown() or isEncounterInProgress then
        if unit == "player" then
            CheckForMissingBuffs()
        end
        return
    end

    if updateInfo and not updateInfo.isFullUpdate then
        local hasRelevant = false
        if updateInfo.addedAuras then
            for _, aura in ipairs(updateInfo.addedAuras) do
                if not issecretvalue(aura.isHelpful) and aura.isHelpful then
                    hasRelevant = true
                    break
                end
            end
        end
        if updateInfo.removedAuraInstanceIDs and #updateInfo.removedAuraInstanceIDs > 0 then
            hasRelevant = true
        end
        if not hasRelevant then
            return
        end
    end
    CheckForMissingBuffs()
end

function MBUFFS:UpdateDB()
    self.db = NRSKNUI.db.profile.MissingBuffs
end

function MBUFFS:OnInitialize()
    self:UpdateDB()
    local _, class = UnitClass("player")
    playerClass = class
    self:SetEnabledState(false)
end

function MBUFFS:OnEnable()
    if not self.db or not self.db.Enabled then return end

    CreateContainerFrame()
    CreateTargetedContainerFrame()

    wipe(groupSpecData)
    wipe(groupClassesCache)
    if playerClass then
        groupClassesCache[playerClass] = true
    end

    LibSpec.RegisterGroup(self, OnLibSpecUpdate)

    C_Timer.After(0.5, function()
        self:ApplySettings()
    end)

    self:RegisterEvent("UNIT_AURA", function(_, unit, updateInfo) OnAuraChange(unit, updateInfo) end)
    self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        RebuildGroupClassCache()
        CheckForMissingBuffs()
    end)
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        HideMissingBuffIcons()
        CheckCombatSafeElements()
    end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function() CheckForMissingBuffs() end)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, CheckForMissingBuffs) end)
    self:RegisterEvent("PLAYER_ALIVE", function() CheckForMissingBuffs() end)
    self:RegisterEvent("PLAYER_DEAD", function() CheckForMissingBuffs() end)
    self:RegisterEvent("PLAYER_UNGHOST", function() CheckForMissingBuffs() end)
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(0.5, CheckForMissingBuffs) end)
    self:RegisterEvent("SCENARIO_UPDATE", function() C_Timer.After(1, CheckForMissingBuffs) end)
    self:RegisterEvent("START_TIMER", function() C_Timer.After(1, CheckForMissingBuffs) end)
    self:RegisterEvent("UNIT_INVENTORY_CHANGED", function() C_Timer.After(0.1, CheckForMissingBuffs) end)
    self:RegisterEvent("TRAIT_CONFIG_UPDATED", function() C_Timer.After(0.5, CheckForMissingBuffs) end)
    self:RegisterEvent("SPELLS_CHANGED", function() C_Timer.After(0.5, CheckForMissingBuffs) end)
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function() C_Timer.After(1, CheckForMissingBuffs) end)
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED", function() C_Timer.After(1, CheckForMissingBuffs) end)
    self:RegisterEvent("CHALLENGE_MODE_START", function() C_Timer.After(1, CheckForMissingBuffs) end)

    self:RegisterEvent("ENCOUNTER_START", function()
        isEncounterInProgress = true
        HideMissingBuffIcons()
        CheckCombatSafeElements()
    end)
    self:RegisterEvent("ENCOUNTER_END", function()
        isEncounterInProgress = false
        C_Timer.After(0.5, CheckForMissingBuffs)
    end)

    C_Timer.After(2, CheckForMissingBuffs)

    if expirationTicker then
        expirationTicker:Cancel()
    end
    expirationTicker = C_Timer.NewTicker(EXPIRATION_CHECK_INTERVAL, CheckForMissingBuffs)

    self:RegisterEditModeElements()
end

function MBUFFS:RegisterEditModeElements()
    if not NRSKNUI.EditMode then return end

    if not containerFrame then CreateContainerFrame() end
    if not targetedContainerFrame then CreateTargetedContainerFrame() end

    local raidDb = self.db.RaidBuffDisplay
    local targetedDb = self.db.TargetedBuffDisplay

    NRSKNUI.EditMode:RegisterElement({
        key = "MissingBuffs",
        displayName = "Missing Buffs",
        frame = containerFrame,
        getPosition = function()
            return raidDb.Position or {}
        end,
        setPosition = function(pos)
            raidDb.Position = raidDb.Position or {}
            raidDb.Position.AnchorFrom = pos.AnchorFrom
            raidDb.Position.AnchorTo = pos.AnchorTo
            raidDb.Position.XOffset = pos.XOffset
            raidDb.Position.YOffset = pos.YOffset
            if containerFrame then
                local anchorFrame = NRSKNUI:ResolveAnchorFrame(raidDb.anchorFrameType, raidDb.ParentFrame)
                local growDirection = raidDb.GrowDirection or "CENTER"
                local anchorFrom = pos.AnchorFrom
                if growDirection == "RIGHT" then
                    anchorFrom = "LEFT"
                elseif growDirection == "LEFT" then
                    anchorFrom = "RIGHT"
                end
                containerFrame:ClearAllPoints()
                containerFrame:SetPoint(anchorFrom, anchorFrame, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        guiPath = "missingBuffs",
    })

    NRSKNUI.EditMode:RegisterElement({
        key = "TargetedBuffs",
        displayName = "Targeted Buffs",
        frame = targetedContainerFrame,
        getPosition = function()
            return targetedDb.Position or {}
        end,
        setPosition = function(pos)
            targetedDb.Position = targetedDb.Position or {}
            targetedDb.Position.AnchorFrom = pos.AnchorFrom
            targetedDb.Position.AnchorTo = pos.AnchorTo
            targetedDb.Position.XOffset = pos.XOffset
            targetedDb.Position.YOffset = pos.YOffset
            if targetedContainerFrame then
                local anchorFrame = NRSKNUI:ResolveAnchorFrame(targetedDb.anchorFrameType, targetedDb.ParentFrame)
                targetedContainerFrame:ClearAllPoints()
                targetedContainerFrame:SetPoint(pos.AnchorFrom, anchorFrame, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        guiPath = "targetedBuffs",
    })
end

function MBUFFS:OnDisable()
    self:UnregisterAllEvents()
    LibSpec.UnregisterGroup(self)
    HideMissingBuffIcons()

    if expirationTicker then
        expirationTicker:Cancel()
        expirationTicker = nil
    end

    wipe(groupSpecData)
    wipe(groupClassesCache)

    if NRSKNUI.EditMode then
        NRSKNUI.EditMode:UnregisterElement("MissingBuffs")
        NRSKNUI.EditMode:UnregisterElement("TargetedBuffs")
    end
end

function MBUFFS:Refresh()
    if self.db and self.db.Enabled then
        self:OnEnable()
        if IsTrackingPaused() then
            self:RefreshPreview()
        else
            CheckForMissingBuffs()
        end
    else
        self:OnDisable()
    end
end

function MBUFFS:ApplySettings()
    if not self.db then return end
    if not self.db.Enabled then return end

    if IsTrackingPaused() then
        self:RefreshPreview()
        return
    end

    local raidDb = self.db.RaidBuffDisplay
    local targetedDb = self.db.TargetedBuffDisplay

    if containerFrame then
        NRSKNUI:ApplyFramePosition(containerFrame, raidDb.Position, raidDb)
    end

    for i, iconFrame in ipairs(activeIcons) do
        if currentMissingBuffs[i] then
            local entry = currentMissingBuffs[i]
            UpdateIconAppearance(iconFrame, entry.buff, entry.text, entry.showGlow, entry.glowSettings)
        end
    end
    ArrangeIcons()

    if targetedContainerFrame then
        NRSKNUI:ApplyFramePosition(targetedContainerFrame, targetedDb.Position, targetedDb)
    end

    for i, iconFrame in ipairs(targetedActiveIcons) do
        if currentMissingTargetedBuffs[i] then
            local entry = currentMissingTargetedBuffs[i]
            UpdateTargetedIconAppearance(iconFrame, entry.buff, entry.showGlow, entry.glowSettings)
        end
    end
    ArrangeTargetedIcons()
end

local function GetAllEnabledBuffsForPreview()
    local entries = {}
    if not MBUFFS.db then return entries end

    local raidBuffsDb = MBUFFS.db.RaidBuffs or {}
    local consumablesDb = MBUFFS.db.Consumables or {}
    local selfBuffsDb = MBUFFS.db.SelfBuffs or {}
    local presenceBuffsDb = MBUFFS.db.PresenceBuffs or {}

    for _, buff in ipairs(SAFE_BUFFS) do
        if buff.buffType == "raid" and buff.key then
            local buffSettings = raidBuffsDb[buff.key] or {}
            if buffSettings.Enabled ~= false then
                entries[#entries + 1] = {
                    buff = buff,
                    text = "0/5",
                    showGlow = true,
                    glowSettings = buffSettings,
                }
            end
        elseif buff.buffType == "weaponEnchant" then
            local enchantSettings = consumablesDb[buff.dbKey] or {}
            if enchantSettings.Enabled ~= false then
                entries[#entries + 1] = {
                    buff = { spellId = 0, text = buff.text, iconTexture = WEAPON_ENCHANT_ICON },
                    text = buff.text,
                    showGlow = true,
                    glowSettings = enchantSettings,
                }
            end
        end
    end

    local poisonSettings = selfBuffsDb.Poisons
    if poisonSettings.Enabled ~= false then
        entries[#entries + 1] = {
            buff = { spellId = 2823, text = "" },
            text = "",
            showGlow = true,
            glowSettings = poisonSettings,
        }
        entries[#entries + 1] = {
            buff = { spellId = 3408, text = "" },
            text = "",
            showGlow = true,
            glowSettings = poisonSettings,
        }
    end

    local flaskSettings = consumablesDb.Flask or {}
    if flaskSettings.Enabled ~= false then
        entries[#entries + 1] = {
            buff = { spellId = 1235111, text = "" },
            text = "",
            showGlow = true,
            glowSettings = flaskSettings,
        }
    end

    local foodSettings = consumablesDb.Food or {}
    if foodSettings.Enabled ~= false then
        entries[#entries + 1] = {
            buff = { spellId = 104280, text = "" },
            text = "",
            showGlow = true,
            glowSettings = foodSettings,
        }
    end

    local runeSettings = consumablesDb.Rune or {}
    if runeSettings.Enabled ~= false then
        entries[#entries + 1] = {
            buff = { spellId = 1264426, text = "" },
            text = "",
            showGlow = true,
            glowSettings = runeSettings,
        }
    end

    for _, buff in ipairs(SELF_BUFFS) do
        if buff.key then
            local buffSettings = selfBuffsDb[buff.key] or {}
            if buffSettings.Enabled ~= false then
                entries[#entries + 1] = {
                    buff = buff,
                    text = "",
                    showGlow = true,
                    glowSettings = buffSettings,
                }
            end
        end
    end

    for _, buff in ipairs(PRESENCE_BUFFS) do
        if buff.key then
            local buffSettings = presenceBuffsDb[buff.key] or {}
            if buffSettings.Enabled ~= false then
                entries[#entries + 1] = {
                    buff = buff,
                    text = "",
                    showGlow = true,
                    glowSettings = buffSettings,
                }
            end
        end
    end

    return entries
end

local function GetAllEnabledTargetedBuffsForPreview()
    local entries = {}
    if not MBUFFS.db then return entries end

    local targetedSettings = MBUFFS.db.TargetedBuffs
    if not targetedSettings or targetedSettings.Enabled == false then return entries end

    local targetedBuffsDb = MBUFFS.db.TargetedBuffSettings or {}

    for _, buff in ipairs(TARGETED_BUFFS) do
        if buff.key then
            local buffSettings = targetedBuffsDb[buff.key] or {}
            if buffSettings.Enabled ~= false then
                entries[#entries + 1] = {
                    buff = buff,
                    text = "",
                    showGlow = true,
                    glowSettings = buffSettings,
                }
            end
        end
    end

    return entries
end

local function ShowPreviewIcons()
    if not containerFrame then CreateContainerFrame() end
    if not targetedContainerFrame then CreateTargetedContainerFrame() end

    local previewEntries = GetAllEnabledBuffsForPreview()
    wipe(currentMissingBuffs)
    for _, entry in ipairs(previewEntries) do
        currentMissingBuffs[#currentMissingBuffs + 1] = entry
    end

    if #currentMissingBuffs > 0 then
        ShowMissingBuffs(currentMissingBuffs, true)
    else
        ReleaseAllIcons()
        ArrangeIcons()
    end

    local targetedEntries = GetAllEnabledTargetedBuffsForPreview()
    wipe(currentMissingTargetedBuffs)
    for _, entry in ipairs(targetedEntries) do
        currentMissingTargetedBuffs[#currentMissingTargetedBuffs + 1] = entry
    end

    if #currentMissingTargetedBuffs > 0 then
        ShowTargetedBuffs(currentMissingTargetedBuffs, true)
    else
        ReleaseAllTargetedIcons()
        if targetedContainerFrame then
            targetedContainerFrame:Hide()
        end
    end
end

function MBUFFS:IsPaused()
    return IsTrackingPaused()
end

function MBUFFS:RefreshPreview()
    if not IsTrackingPaused() then return end
    ShowPreviewIcons()
end

function MBUFFS:ShowPreview()
    if not containerFrame then CreateContainerFrame() end
    isPreviewActive = true
    ShowPreviewIcons()
end

function MBUFFS:HidePreview()
    isPreviewActive = false
    HideMissingBuffIcons()
    wipe(currentMissingBuffs)
    if self.db and self.db.Enabled then C_Timer.After(0.1, CheckForMissingBuffs) end
end

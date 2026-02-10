-- NorskenUI namespace
local _, NRSKNUI = ...

-- Safety check
if not NRSKNUI.Addon then
    error("MissingBuffs: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local MBUFFS = NRSKNUI.Addon:NewModule("MissingBuffs", "AceEvent-3.0")

-- Localization
local ipairs, pairs = ipairs, pairs
local wipe = wipe
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local UnitIsPlayer = UnitIsPlayer
local UnitCanAssist = UnitCanAssist
local IsMounted = IsMounted
local UnitOnTaxi = UnitOnTaxi
local UnitInVehicle = UnitInVehicle
local UnitHasVehicleUI = UnitHasVehicleUI
local InCombatLockdown = InCombatLockdown
local GetNumGroupMembers = GetNumGroupMembers
local IsInRaid = IsInRaid
local GetTime = GetTime
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local CreateFrame = CreateFrame
local GetInventorySlotInfo = GetInventorySlotInfo
local GetInventoryItemLink = GetInventoryItemLink
local GetItemInfo = GetItemInfo
local GetInventoryItemTexture = GetInventoryItemTexture
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local issecretvalue = issecretvalue
local tonumber = tonumber
local GetShapeshiftForm = GetShapeshiftForm
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
local tostring = tostring
local C_Spell = C_Spell
local C_SpellBook = C_SpellBook
local C_PetBattles = C_PetBattles
local C_ChallengeMode = C_ChallengeMode
local C_SpellActivationOverlay = C_SpellActivationOverlay
local AuraUtil = AuraUtil
local UIParent = UIParent
local C_Timer = C_Timer

-- Constants
local CHECK_THROTTLE = 0.25
local MISSING_TEXT = "MISSING"
local REAPPLY_TEXT = ""
local GENERALBUFF_TEXT = ""

-- Default icon for weapon enchants
local WEAPON_ENCHANT_ICON = 136244

-- Map CUSTOM_BUFFS categories to db.Consumables keys
local CATEGORY_TO_DB_KEY = {
    FLASK = "Flask",
    FOOD = "Food",
    MH_ENCHANT = "MHEnchant",
    OH_ENCHANT = "OHEnchant",
    RUNE = "Rune",
}

-- Class buff definitions
local CLASS_BUFFS = {
    ["DRUID"] = {
        { spellId = 1126, text = GENERALBUFF_TEXT }, -- Mark of the Wild
    },
    ["EVOKER"] = {
        {
            spellId = 381748,
            spellbookId = 364342,
            text = GENERALBUFF_TEXT,
            ignoreRangeCheck = true,
            extraBuffSpellIds = { 381732, 381741, 381746, 381749, 381750, 381751, 381752, 381753, 381754, 381756, 381757, 381758, 442744, 432658, 432652, 432655 }
        }, -- Blessing of the Bronze
    },
    ["MAGE"] = {
        { spellId = 1459, text = GENERALBUFF_TEXT }, -- Arcane Intellect
    },
    ["PRIEST"] = {
        { spellId = 21562, text = GENERALBUFF_TEXT }, -- Power Word: Fortitude
    },
    ["SHAMAN"] = {
        { spellId = 462854, text = GENERALBUFF_TEXT }, -- Skyfury
    },
    ["WARRIOR"] = {
        { spellId = 6673, text = GENERALBUFF_TEXT, ignoreRangeCheck = true }, -- Battle Shout
    },
}

-- Class stance/form definitions
local CLASS_STANCES = {
    WARRIOR = {
        stances = {
            { spellId = 386164 }, -- Battle Stance
            { spellId = 386196 }, -- Berserker Stance
            { spellId = 386208 }, -- Defensive Stance
        },
    },
    PALADIN = {
        stances = {
            { spellId = 465 },    -- Devotion Aura
            { spellId = 317920 }, -- Concentration Aura
            { spellId = 32223 },  -- Crusader Aura
        },
    },
    EVOKER = {
        stances = {
            { spellId = 403264 }, -- Black Attunement
            { spellId = 403265 }, -- Bronze Attunement
        },
        specIds = { 1473 },       -- Augmentation only
    },
    DRUID = {
        stances = {
            { spellId = 24858, specIds = { 102 } }, -- Moonkin Form (Balance)
            { spellId = 768,   specIds = { 103 } }, -- Cat Form (Feral)
            { spellId = 5487,  specIds = { 104 } }, -- Bear Form (Guardian)
        },
    },
    PRIEST = {
        stances = {
            { spellId = 232698, extraSpellIds = { 194249 } }, -- Shadowform / Voidform
        },
        specIds = { 258 },                                    -- Shadow only
    },
}

-- Custom buff table
local CUSTOM_BUFFS = {
    -- Midnight Flasks
    { category = "FLASK",      spellId = 1235110,   enabled = true }, -- Blood Knights
    { category = "FLASK",      spellId = 1235057,   enabled = true }, -- Thalassian Resistance
    { category = "FLASK",      spellId = 1235111,   enabled = true }, -- Shattered Sun
    -- TWW Flasks
    { category = "FLASK",      spellId = 432021,    enabled = true }, -- Alchemical Chaos
    { category = "FLASK",      spellId = 431971,    enabled = true }, -- Flask of Tempered Aggression
    { category = "FLASK",      spellId = 431972,    enabled = true }, -- Flask of Tempered Swiftness
    { category = "FLASK",      spellId = 431974,    enabled = true }, -- Flask of Tempered Mastery
    { category = "FLASK",      spellId = 431973,    enabled = true }, -- Flask of Tempered Versatility

    -- Food
    { category = "FOOD",       spellId = 457284,    enabled = true }, -- Well Fed (Mainstat)
    { category = "FOOD",       spellId = 1232585,   enabled = true }, -- Well Fed (Stamina + Mainstat)
    { category = "FOOD",       spellId = 461959,    enabled = true }, -- Well Fed (Crit)
    { category = "FOOD",       spellId = 461960,    enabled = true }, -- Well Fed (Haste)
    { category = "FOOD",       spellId = 462210,    enabled = true }, -- Hearty Well Fed (Mainstat)
    { category = "FOOD",       spellId = 462181,    enabled = true }, -- Hearty Well Fed (Crit)
    { category = "FOOD",       spellId = 462183,    enabled = true }, -- Hearty Well Fed (Mastery)
    { category = "FOOD",       spellId = 462180,    enabled = true }, -- Hearty Well Fed (Haste)

    -- Weapon enchants
    { category = "MH_ENCHANT", weaponSlot = "main", text = "MH",   enabled = true },
    { category = "OH_ENCHANT", weaponSlot = "off",  text = "OH",   enabled = true },
}

-- Spec ID to name mapping for each class
local SPEC_ID_TO_NAME = {
    -- Warrior
    [71] = "Arms",
    [72] = "Fury",
    [73] = "Protection",
    -- Paladin
    [65] = "Holy",
    [66] = "Protection",
    [70] = "Retribution",
    -- Druid
    [102] = "Balance",
    [103] = "Feral",
    [104] = "Guardian",
    [105] = "Restoration",
    -- Priest
    [256] = "Discipline",
    [257] = "Holy",
    [258] = "Shadow",
    -- Evoker
    [1467] = "Devastation",
    [1468] = "Preservation",
    [1473] = "Augmentation",
}

-- Unit strings for group checking
local UNIT_STRINGS = { raid = {}, party = {} }
for i = 1, 40 do
    UNIT_STRINGS.raid[i] = "raid" .. i
    if i <= 5 then
        UNIT_STRINGS.party[i] = "party" .. i
    end
end

-- Module state
local playerClass = nil
local playerBuffs = nil
local isThrottled = false
local lastCheckTime = 0

-- Frame state
local containerFrame = nil
local stanceFrame = nil
local stanceTextFrame = nil
local iconPool = {}
local activeIcons = {}
local currentMissingBuffs = {}

-- Preview state
local isPreviewActive = false

-- Load condition checker
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

    return true -- Default to true for unknown conditions
end

-- Helper Functions
local function IsSpellKnown(spellId)
    return spellId and C_SpellBook.IsSpellKnown(spellId)
end
local function GetSpellTexture(spellId)
    if spellId and spellId > 0 then
        return C_Spell.GetSpellTexture(spellId)
    end
    return nil
end
local function IsPlayerMounted()
    return IsMounted() or UnitOnTaxi("player") or UnitInVehicle("player") or UnitHasVehicleUI("player")
end
local function IsValidTarget(unit)
    return UnitExists(unit)
        and not UnitIsDeadOrGhost(unit)
        and UnitIsConnected(unit)
        and UnitIsPlayer(unit)
        and UnitCanAssist("player", unit)
end

local function PlayerHasBuff(spellId, extraSpellIds)
    if not spellId then return false, nil end
    if issecretvalue(spellId) or issecretvalue(extraSpellIds) then return end

    local hasBuff = false
    local expirationTime = nil

    AuraUtil.ForEachAura("player", "HELPFUL", nil, function(auraInfo)
        if issecretvalue(auraInfo.spellId) then return end
        if not auraInfo or not auraInfo.spellId then return false end

        if auraInfo.spellId == spellId then
            hasBuff = true
            expirationTime = auraInfo.expirationTime
            return true
        end

        if extraSpellIds then
            for _, extraId in ipairs(extraSpellIds) do
                if auraInfo.spellId == extraId then
                    hasBuff = true
                    expirationTime = auraInfo.expirationTime
                    return true
                end
            end
        end
        return false
    end, true)

    return hasBuff, expirationTime
end

local function UnitHasBuff(unit, spellId, extraSpellIds)
    if issecretvalue(unit) then return end
    if not unit or not IsValidTarget(unit) then return true end
    if issecretvalue(spellId) or issecretvalue(extraSpellIds) then return end

    local hasBuff = false

    AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(auraInfo)
        if not auraInfo or not auraInfo.spellId then return false end

        if auraInfo.spellId == spellId then
            hasBuff = true
            return true
        end

        if extraSpellIds then
            for _, extraId in ipairs(extraSpellIds) do
                if auraInfo.spellId == extraId then
                    hasBuff = true
                    return true
                end
            end
        end
        return false
    end, true)

    return hasBuff
end

-- Check buff status
local function CheckBuffStatus(buff)
    if InCombatLockdown() then return false, false end
    if issecretvalue(buff) then return end

    local hasBuff, expirationTime = PlayerHasBuff(buff.spellId, buff.extraBuffSpellIds)
    if not hasBuff then
        return true, false
    end

    local needsReapply = false
    if expirationTime and expirationTime > 0 then
        local timeLeft = expirationTime - GetTime()
        local durationMinutes = timeLeft / 60
        if MBUFFS.db and MBUFFS.db.NotifyLowDuration and durationMinutes <= MBUFFS.db.LowDurationThreshold then
            needsReapply = true
        end
    end

    if buff.onlySelf then
        return false, needsReapply
    end

    local groupSize = GetNumGroupMembers()
    if groupSize > 0 then
        if IsInRaid() then
            for i = 1, groupSize do
                local unit = UNIT_STRINGS.raid[i]
                if IsValidTarget(unit) and not UnitHasBuff(unit, buff.spellId, buff.extraBuffSpellIds) then
                    if buff.ignoreRangeCheck or C_Spell.IsSpellInRange(buff.spellId, unit) then
                        return true, false
                    end
                end
            end
        else
            for i = 1, groupSize - 1 do
                local unit = UNIT_STRINGS.party[i]
                if IsValidTarget(unit) and not UnitHasBuff(unit, buff.spellId, buff.extraBuffSpellIds) then
                    if buff.ignoreRangeCheck or C_Spell.IsSpellInRange(buff.spellId, unit) then
                        return true, false
                    end
                end
            end
        end
    end

    return false, needsReapply
end

local function HasWeaponEnchant(slot)
    local hasMain, _, _, _, hasOff = GetWeaponEnchantInfo()
    local slotName = slot == "main" and "MAINHANDSLOT" or slot == "off" and "SECONDARYHANDSLOT"
    if not slotName then return nil, nil, false end
    local slotID = GetInventorySlotInfo(slotName)
    local itemLink = GetInventoryItemLink("player", slotID)
    if not itemLink then
        return nil, nil, false
    end

    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLink)
    if not equipLoc then return nil, nil, false end

    if equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_HOLDABLE" then
        return nil, nil, false
    end

    local hasEnchant = (slot == "main") and hasMain or hasOff
    local icon = GetInventoryItemTexture("player", slotID)

    if not icon then
        return hasEnchant, nil, false
    end

    return hasEnchant, icon, true
end

-- Check custom buff status
local function CheckCustomBuffs()
    local db = MBUFFS.db
    if not db then return {} end
    local consumablesDb = db.Consumables or {}
    local missing = {}
    local categorySeen = {}
    local categorySatisfied = {}
    local categoryIcon = {}
    local categoryEnabled = {}

    -- Pre-check which categories are enabled and meet load conditions
    for category, dbKey in pairs(CATEGORY_TO_DB_KEY) do
        local catSettings = consumablesDb[dbKey]
        if catSettings then
            local enabled = catSettings.Enabled ~= false
            local loadMet = IsLoadConditionMet(catSettings.LoadCondition)
            categoryEnabled[category] = enabled and loadMet
        else
            -- Default to enabled if no settings found
            categoryEnabled[category] = true
        end
    end

    -- Check what buffs are present
    for _, buff in ipairs(CUSTOM_BUFFS) do
        local category = buff.category
        if category and categoryEnabled[category] then
            if buff.weaponSlot then
                local hasEnchant, icon, hasItem = HasWeaponEnchant(buff.weaponSlot)
                if hasItem then
                    if hasEnchant ~= nil then
                        categoryIcon[category] = icon or WEAPON_ENCHANT_ICON
                    end
                    if hasEnchant == true then
                        categorySatisfied[category] = true
                    end
                end
            elseif buff.spellId then
                if PlayerHasBuff(buff.spellId, buff.extraBuffSpellIds) then
                    categorySatisfied[category] = true
                end
            end
        end
    end

    -- Create missing notifications for unsatisfied categories
    for _, buff in ipairs(CUSTOM_BUFFS) do
        local category = buff.category
        if category and categoryEnabled[category] then
            if not categorySatisfied[category] and not categorySeen[category] then
                categorySeen[category] = true

                local icon = categoryIcon[category]

                if buff.weaponSlot and not icon then
                    -- Skip creating icon if no weapon
                else
                    missing[#missing + 1] = {
                        buff = {
                            spellId = buff.spellId or 0,
                            text = buff.text,
                            iconTexture = buff.iconTexture or icon,
                        },
                        text = buff.text,
                        isCustom = true,
                    }
                end
            end
        end
    end

    return missing
end

-- Icon Pool Management
local function CreateIcon()
    local db = MBUFFS.db
    local raidDb = db.RaidBuffDisplay or db

    local iconFrame = CreateFrame("Frame", nil, containerFrame)
    iconFrame:SetSize(raidDb.IconSize or db.IconSize or 48, raidDb.IconSize or db.IconSize or 48)
    NRSKNUI:SnapFrameToPixels(iconFrame)

    -- Create border container
    iconFrame.iconBorder = CreateFrame("Frame", nil, iconFrame)
    iconFrame.iconBorder:SetAllPoints(iconFrame)
    iconFrame.iconBorder:SetFrameLevel(iconFrame:GetFrameLevel() + 1)

    -- Create borders
    local borderTop = iconFrame.iconBorder:CreateTexture(nil, "OVERLAY", nil, 7)
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", iconFrame, "TOPRIGHT", 0, 0)
    borderTop:SetColorTexture(0, 0, 0, 1)
    borderTop:SetTexelSnappingBias(0)
    borderTop:SetSnapToPixelGrid(false)

    local borderBottom = iconFrame.iconBorder:CreateTexture(nil, "OVERLAY", nil, 7)
    borderBottom:SetHeight(1)
    borderBottom:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetColorTexture(0, 0, 0, 1)
    borderBottom:SetTexelSnappingBias(0)
    borderBottom:SetSnapToPixelGrid(false)

    local borderLeft = iconFrame.iconBorder:CreateTexture(nil, "OVERLAY", nil, 7)
    borderLeft:SetWidth(1)
    borderLeft:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMLEFT", 0, 0)
    borderLeft:SetColorTexture(0, 0, 0, 1)
    borderLeft:SetTexelSnappingBias(0)
    borderLeft:SetSnapToPixelGrid(false)

    local borderRight = iconFrame.iconBorder:CreateTexture(nil, "OVERLAY", nil, 7)
    borderRight:SetWidth(1)
    borderRight:SetPoint("TOPRIGHT", iconFrame, "TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0, 0)
    borderRight:SetColorTexture(0, 0, 0, 1)
    borderRight:SetTexelSnappingBias(0)
    borderRight:SetSnapToPixelGrid(false)

    -- Icon texture
    iconFrame.icon = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.icon:SetAllPoints(iconFrame)

    -- Icon zoom
    local zoom = 0.3
    local texMin = 0.25 * zoom
    local texMax = 1 - 0.25 * zoom
    iconFrame.icon:SetTexCoord(texMin, texMax, texMin, texMax)

    -- Text
    iconFrame.text = iconFrame:CreateFontString(nil, "OVERLAY")
    NRSKNUI:ApplyFont(iconFrame.text, db.Font, 14, db.FontOutline)
    iconFrame.text:SetPoint("CENTER", iconFrame, "CENTER", 1, 0)
    iconFrame.text:SetTextColor(1, 1, 1, 1)
    iconFrame.text:SetShadowOffset(0, 0)
    iconFrame.text:SetShadowColor(0, 0, 0, 0)

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

-- Container for raid buff icons
local function CreateContainerFrame()
    if containerFrame then return end
    local db = MBUFFS.db
    local raidDb = db.RaidBuffDisplay or {}
    local pos = raidDb.Position or {}

    containerFrame = CreateFrame("Frame", "NorskenUI_MissingBuffContainer", UIParent)
    containerFrame:SetSize(400, raidDb.IconSize or db.IconSize or 48)

    local anchorFrame = NRSKNUI:ResolveAnchorFrame(raidDb.anchorFrameType, raidDb.ParentFrame)
    containerFrame:SetPoint(
        pos.AnchorFrom or "CENTER",
        anchorFrame,
        pos.AnchorTo or "CENTER",
        pos.XOffset or 0,
        pos.YOffset or 200
    )
    containerFrame:SetFrameStrata(raidDb.Strata or db.Strata or "HIGH")
    containerFrame:Hide()
end

-- Stance icon frame
local function CreateStanceFrame()
    if stanceFrame then return end
    local db = MBUFFS.db
    local stanceDb = db.StanceDisplay or {}
    local pos = stanceDb.Position or {}

    stanceFrame = CreateFrame("Frame", "NorskenUI_MissingStanceIcon", UIParent)
    stanceFrame:SetSize(stanceDb.IconSize or db.IconSize or 48, stanceDb.IconSize or db.IconSize or 48)

    local anchorFrame = NRSKNUI:ResolveAnchorFrame(stanceDb.anchorFrameType, stanceDb.ParentFrame)
    stanceFrame:SetPoint(
        pos.AnchorFrom or "CENTER",
        anchorFrame,
        pos.AnchorTo or "CENTER",
        pos.XOffset or 0,
        pos.YOffset or 150
    )
    stanceFrame:SetFrameStrata(stanceDb.Strata or db.Strata or "HIGH")
    NRSKNUI:SnapFrameToPixels(stanceFrame)

    -- Border
    stanceFrame.border = CreateFrame("Frame", nil, stanceFrame)
    stanceFrame.border:SetAllPoints(stanceFrame)
    stanceFrame.border:SetFrameLevel(stanceFrame:GetFrameLevel() + 1)

    local borderTop = stanceFrame.border:CreateTexture(nil, "OVERLAY", nil, 7)
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT", stanceFrame, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", stanceFrame, "TOPRIGHT", 0, 0)
    borderTop:SetColorTexture(0, 0, 0, 1)

    local borderBottom = stanceFrame.border:CreateTexture(nil, "OVERLAY", nil, 7)
    borderBottom:SetHeight(1)
    borderBottom:SetPoint("BOTTOMLEFT", stanceFrame, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", stanceFrame, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetColorTexture(0, 0, 0, 1)

    local borderLeft = stanceFrame.border:CreateTexture(nil, "OVERLAY", nil, 7)
    borderLeft:SetWidth(1)
    borderLeft:SetPoint("TOPLEFT", stanceFrame, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", stanceFrame, "BOTTOMLEFT", 0, 0)
    borderLeft:SetColorTexture(0, 0, 0, 1)

    local borderRight = stanceFrame.border:CreateTexture(nil, "OVERLAY", nil, 7)
    borderRight:SetWidth(1)
    borderRight:SetPoint("TOPRIGHT", stanceFrame, "TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", stanceFrame, "BOTTOMRIGHT", 0, 0)
    borderRight:SetColorTexture(0, 0, 0, 1)

    -- Icon texture
    stanceFrame.icon = stanceFrame:CreateTexture(nil, "ARTWORK")
    stanceFrame.icon:SetAllPoints(stanceFrame)
    local zoom = 0.3
    local texMin = 0.25 * zoom
    local texMax = 1 - 0.25 * zoom
    stanceFrame.icon:SetTexCoord(texMin, texMax, texMin, texMax)

    -- Text
    stanceFrame.text = stanceFrame:CreateFontString(nil, "OVERLAY")
    NRSKNUI:ApplyFont(stanceFrame.text, db.Font, db.FontSize or 12, db.FontOutline)
    stanceFrame.text:SetPoint("BOTTOM", stanceFrame, "TOP", 1, 4)
    stanceFrame.text:SetTextColor(1, 1, 1, 1)
    stanceFrame.text:SetShadowColor(0, 0, 0, 0)
    stanceFrame:Hide()
end

-- Stance text frame
local function CreateStanceTextFrame()
    if stanceTextFrame then return end
    local db = MBUFFS.db
    local textDb = db.StanceText or {}
    local pos = textDb.Position or {}

    stanceTextFrame = CreateFrame("Frame", "NorskenUI_StanceTextDisplay", UIParent)
    stanceTextFrame:SetSize(200, 30)

    local anchorFrom = pos.AnchorFrom or "CENTER"
    local anchorFrame = NRSKNUI:ResolveAnchorFrame(textDb.anchorFrameType, textDb.ParentFrame)
    stanceTextFrame:SetPoint(
        anchorFrom,
        anchorFrame,
        pos.AnchorTo or "CENTER",
        pos.XOffset or 0,
        pos.YOffset or 100
    )
    stanceTextFrame:SetFrameStrata(textDb.Strata or "HIGH")

    -- Text with smart alignment based on anchor point
    stanceTextFrame.text = stanceTextFrame:CreateFontString(nil, "OVERLAY")
    NRSKNUI:ApplyFont(stanceTextFrame.text, textDb.Font, textDb.FontSize or 14, textDb.FontOutline)

    local textPoint = NRSKNUI:GetTextPointFromAnchor(anchorFrom)
    local textJustify = NRSKNUI:GetTextJustifyFromAnchor(anchorFrom)
    stanceTextFrame.text:SetPoint(textPoint, stanceTextFrame, textPoint, 0, 0)
    stanceTextFrame.text:SetJustifyH(textJustify)
    stanceTextFrame.text:SetTextColor(1, 1, 1, 1)

    stanceTextFrame:Hide()
end

local function ShowStanceIcon(spellId)
    if not stanceFrame then CreateStanceFrame() end
    local db = MBUFFS.db
    local stanceDb = db.StanceDisplay or {}
    if stanceFrame then
        local texture = GetSpellTexture(spellId)
        stanceFrame.icon:SetTexture(texture)
        stanceFrame.text:SetText(MISSING_TEXT)

        local iconSize = stanceDb.IconSize or db.IconSize or 48
        stanceFrame:SetSize(iconSize, iconSize)
        stanceFrame.icon:SetSize(iconSize, iconSize)

        NRSKNUI:ApplyFont(stanceFrame.text, db.Font, db.FontSize or 12, db.FontOutline)
        stanceFrame:SetFrameStrata(stanceDb.Strata or db.Strata or "HIGH")

        -- Apply position with custom anchor frame
        local pos = stanceDb.Position or {}
        local anchorFrame = NRSKNUI:ResolveAnchorFrame(stanceDb.anchorFrameType, stanceDb.ParentFrame)
        stanceFrame:ClearAllPoints()
        stanceFrame:SetPoint(
            pos.AnchorFrom or "CENTER",
            anchorFrame,
            pos.AnchorTo or "CENTER",
            pos.XOffset or 0,
            pos.YOffset or 150
        )

        stanceFrame:Show()
    end
end

local function HideStanceIcon()
    if stanceFrame then
        stanceFrame:Hide()
    end
end

-- Stance text display functions
local function UpdateStanceTextDisplay()
    if not MBUFFS.db then return end
    local db = MBUFFS.db
    local textDb = db.StanceText or {}

    -- Check if stance text is enabled
    if not textDb.Enabled then
        if stanceTextFrame then stanceTextFrame:Hide() end
        return
    end

    -- Only show for warrior/paladin
    if playerClass ~= "WARRIOR" and playerClass ~= "PALADIN" then
        if stanceTextFrame then stanceTextFrame:Hide() end
        return
    end

    -- Create frame if needed
    if not stanceTextFrame then CreateStanceTextFrame() end

    -- Get current form/stance
    local currentForm = GetShapeshiftForm()
    local currentSpellId = nil

    if currentForm > 0 then
        local _, _, _, formSpellId = GetShapeshiftFormInfo(currentForm)
        currentSpellId = formSpellId
    end

    -- For paladin, check auras via buff
    if playerClass == "PALADIN" then
        local paladinAuras = { 465, 317920, 32223 }
        for _, auraId in ipairs(paladinAuras) do
            if PlayerHasBuff(auraId) then
                currentSpellId = auraId
                break
            end
        end
    end
    if stanceTextFrame then
        -- No stance active
        if not currentSpellId then
            stanceTextFrame:Hide()
            return
        end

        -- Get settings for this stance
        local classData = textDb[playerClass]
        if not classData then
            stanceTextFrame:Hide()
            return
        end

        local stanceKey = tostring(currentSpellId)
        local stanceSettings = classData[stanceKey]

        if not stanceSettings or not stanceSettings.Enabled then
            stanceTextFrame:Hide()
            return
        end

        -- Update text and color
        local text = stanceSettings.Text or "Stance"
        local color = stanceSettings.Color or { 1, 1, 1, 1 }

        stanceTextFrame.text:SetText(text)
        stanceTextFrame.text:SetTextColor(color[1], color[2], color[3], color[4] or 1)

        -- Update font
        NRSKNUI:ApplyFont(stanceTextFrame.text, textDb.Font, textDb.FontSize or 14, textDb.FontOutline)

        -- Update position with custom anchor frame support
        local pos = textDb.Position or {}
        local anchorFrom = pos.AnchorFrom or "CENTER"
        local anchorFrame = NRSKNUI:ResolveAnchorFrame(textDb.anchorFrameType, textDb.ParentFrame)
        stanceTextFrame:ClearAllPoints()
        stanceTextFrame:SetPoint(
            anchorFrom,
            anchorFrame,
            pos.AnchorTo or "CENTER",
            pos.XOffset or 0,
            pos.YOffset or 100
        )
        stanceTextFrame:SetFrameStrata(textDb.Strata or "HIGH")

        -- Update text alignment based on anchor point
        local textPoint = NRSKNUI:GetTextPointFromAnchor(anchorFrom)
        local textJustify = NRSKNUI:GetTextJustifyFromAnchor(anchorFrom)
        stanceTextFrame.text:ClearAllPoints()
        stanceTextFrame.text:SetPoint(textPoint, stanceTextFrame, textPoint, 0, 0)
        stanceTextFrame.text:SetJustifyH(textJustify)

        stanceTextFrame:Show()
    end
end

local function HideStanceText()
    if stanceTextFrame then
        stanceTextFrame:Hide()
    end
end

-- Display Functions
local function UpdateIconAppearance(iconFrame, buff, text)
    local db = MBUFFS.db
    local raidDb = db.RaidBuffDisplay or {}
    local iconSize = raidDb.IconSize or db.IconSize or 48

    local texture = GetSpellTexture(buff.spellId)
    if not texture then
        texture = buff.iconTexture or WEAPON_ENCHANT_ICON
    end
    iconFrame.icon:SetTexture(texture)
    iconFrame.text:SetText(text or buff.text or GENERALBUFF_TEXT)

    iconFrame:SetSize(iconSize, iconSize)
    iconFrame.icon:SetSize(iconSize, iconSize)
    iconFrame.iconBorder:SetAllPoints(iconFrame)

    NRSKNUI:ApplyFont(iconFrame.text, db.Font, 14, db.FontOutline)
end

-- Icon arranger, uses center horizontal layout
-- TODO: Maybe add left and right layout?
local function ArrangeIcons()
    if not containerFrame then return end
    local db = MBUFFS.db
    local raidDb = db.RaidBuffDisplay or {}
    local count = #activeIcons

    if count == 0 then
        containerFrame:Hide()
        return
    end

    local iconWidth = raidDb.IconSize or db.IconSize or 48
    local spacing = raidDb.IconSpacing or db.IconSpacing or 8
    local totalWidth = (iconWidth * count) + (spacing * (count - 1))

    containerFrame:SetSize(totalWidth, iconWidth)

    local startX = -totalWidth / 2 + iconWidth / 2

    for i, iconFrame in ipairs(activeIcons) do
        iconFrame:ClearAllPoints()
        iconFrame:SetPoint("CENTER", containerFrame, "CENTER", startX + (i - 1) * (iconWidth + spacing), 0)
        iconFrame:Show()
    end

    -- Update container position with custom anchor frame support
    local pos = raidDb.Position or {}
    local anchorFrame = NRSKNUI:ResolveAnchorFrame(raidDb.anchorFrameType, raidDb.ParentFrame)
    containerFrame:ClearAllPoints()
    containerFrame:SetPoint(
        pos.AnchorFrom or "CENTER",
        anchorFrame,
        pos.AnchorTo or "CENTER",
        pos.XOffset or 0,
        pos.YOffset or 200
    )
    containerFrame:SetFrameStrata(raidDb.Strata or db.Strata or "HIGH")
    containerFrame:Show()
end

-- Check stances/forms
local function CheckStances()
    HideStanceIcon()
    -- Also update stance text display
    UpdateStanceTextDisplay()
    local db = MBUFFS.db
    if not db then return end

    -- Check if stances feature is enabled at all
    local stancesDb = db.Stances
    if not stancesDb then return end
    if stancesDb.Enabled == false then return end

    -- Get current spec info
    local spec = GetSpecialization()
    if not spec then return end
    local currentSpecId = GetSpecializationInfo(spec)
    local specName = SPEC_ID_TO_NAME[currentSpecId]

    -- Get class settings
    local classSettings = stancesDb[playerClass]
    if not classSettings then return end

    -- Special handling for Priest
    if playerClass == "PRIEST" then
        if not classSettings.ShadowEnabled then return end
        if currentSpecId ~= 258 then return end -- Shadow spec only

        -- Check for Shadowform
        local shadowformSpellId = 232698
        local hasShadowform = PlayerHasBuff(shadowformSpellId, { 194249 }) -- Shadowform or Voidform
        if not hasShadowform and IsSpellKnown(shadowformSpellId) then
            ShowStanceIcon(shadowformSpellId)
        end
        return
    end
    -- Check if class toggle is enabled
    local classEnabled = classSettings.Enabled ~= false
    -- Check if spec-specific requirement is enabled
    local specEnabledKey = specName and (specName .. "Enabled")
    local specEnabled = specEnabledKey and classSettings[specEnabledKey] and true or false
    local requiredStanceId = specName and classSettings[specName] and tonumber(classSettings[specName])
    -- If neither class nor spec tracking is enabled, skip
    if not classEnabled and not specEnabled then return end
    -- Get current form/stance
    local currentForm = GetShapeshiftForm()
    local currentSpellId = nil
    if currentForm > 0 then
        local _, _, _, formSpellId = GetShapeshiftFormInfo(currentForm)
        currentSpellId = formSpellId
    end

    -- For Paladin, check auras via buffs
    if playerClass == "PALADIN" then
        local paladinAuras = { 465, 317920, 32223 }
        for _, auraId in ipairs(paladinAuras) do
            if PlayerHasBuff(auraId) then
                currentSpellId = auraId
                break
            end
        end
    end

    -- Determine what to warn about
    if specEnabled and requiredStanceId then
        if currentSpellId ~= requiredStanceId then
            if IsSpellKnown(requiredStanceId) then
                ShowStanceIcon(requiredStanceId)
            end
        end
    elseif classEnabled then
        if not currentSpellId then
            local stanceData = CLASS_STANCES[playerClass]
            if stanceData and stanceData.stances then
                -- Check if the current spec has any applicable stances
                local hasApplicableStance = false
                for _, stance in ipairs(stanceData.stances) do
                    -- If stance has specIds, check if current spec matches
                    if stance.specIds then
                        for _, specId in ipairs(stance.specIds) do
                            if specId == currentSpecId then
                                hasApplicableStance = true
                                break
                            end
                        end
                    else
                        -- No specIds means applicable to all specs
                        hasApplicableStance = true
                    end
                    if hasApplicableStance then break end
                end

                -- Only warn if this spec has applicable stances
                if hasApplicableStance then
                    for _, stance in ipairs(stanceData.stances) do
                        if IsSpellKnown(stance.spellId) then
                            ShowStanceIcon(stance.spellId)
                            break
                        end
                    end
                end
            end
        end
    end
end

-- Show missing buffs
local function ShowMissingBuffs(missingList)
    ReleaseAllIcons()
    for _, entry in ipairs(missingList) do
        local iconFrame = AcquireIcon()
        UpdateIconAppearance(iconFrame, entry.buff, entry.text)
        activeIcons[#activeIcons + 1] = iconFrame
    end
    ArrangeIcons()
end

-- Hide only the raid buff container
local function HideMissingBuffIcons()
    ReleaseAllIcons()
    if containerFrame then
        containerFrame:Hide()
    end
end

-- Hide everything
local function HideAllNotifications()
    HideMissingBuffIcons()
    HideStanceIcon()
    HideStanceText()
end

-- Check only weapon enchants
local function CheckWeaponEnchants()
    local db = MBUFFS.db
    if not db then return end
    local consumablesDb = db.Consumables or {}
    local raidDb = db.RaidBuffDisplay or {}
    for _, buff in ipairs(CUSTOM_BUFFS) do
        if buff.weaponSlot and buff.category then
            local dbKey = CATEGORY_TO_DB_KEY[buff.category]
            local catSettings = dbKey and consumablesDb[dbKey]
            local enabled = not catSettings or catSettings.Enabled ~= false
            local loadMet = not catSettings or IsLoadConditionMet(catSettings.LoadCondition)
            if enabled and loadMet then
                local hasEnchant, icon, hasItem = HasWeaponEnchant(buff.weaponSlot)
                if hasItem and not hasEnchant then
                    local iconFrame = AcquireIcon()
                    local displayIcon = icon or WEAPON_ENCHANT_ICON
                    local text = buff.text or GENERALBUFF_TEXT
                    local iconSize = raidDb.IconSize or db.IconSize or 48

                    -- Set texture directly
                    iconFrame.icon:SetTexture(displayIcon)
                    iconFrame.text:SetText(text)
                    iconFrame:SetSize(iconSize, iconSize)
                    iconFrame.icon:SetSize(iconSize, iconSize)
                    NRSKNUI:ApplyFont(iconFrame.text, db.Font, 14, db.FontOutline)
                    activeIcons[#activeIcons + 1] = iconFrame
                    currentMissingBuffs[#currentMissingBuffs + 1] = { buff = buff, text = text }
                end
            end
        end
    end
end

-- Check glow-based raid buffs
local function CheckGlowBasedRaidBuffs()
    local db = MBUFFS.db
    local consumablesDb = db.Consumables or {}
    local raidBuffsSettings = consumablesDb.RaidBuffs or {}
    local raidBuffsEnabled = raidBuffsSettings.Enabled ~= false
    local raidBuffsLoadMet = IsLoadConditionMet(raidBuffsSettings.LoadCondition)
    if playerBuffs and raidBuffsEnabled and raidBuffsLoadMet then
        for _, buff in ipairs(playerBuffs) do
            local spellToCheck = buff.spellbookId or buff.spellId
            if IsSpellKnown(spellToCheck) then
                if C_SpellActivationOverlay.IsSpellOverlayed(buff.spellId) then
                    local iconFrame = AcquireIcon()
                    UpdateIconAppearance(iconFrame, buff, GENERALBUFF_TEXT)
                    activeIcons[#activeIcons + 1] = iconFrame
                    currentMissingBuffs[#currentMissingBuffs + 1] = { buff = buff, text = GENERALBUFF_TEXT }
                end
            end
        end
    end
end

-- Check combat-safe elements
local function CheckCombatSafeElements()
    if isPreviewActive then return end
    if not MBUFFS.db or not MBUFFS.db.Enabled then return end
    if UnitIsDeadOrGhost("player") or C_PetBattles.IsInBattle() then return end
    ReleaseAllIcons()
    wipe(currentMissingBuffs)
    -- Check glow-based raid buffs if in M+ key
    if C_ChallengeMode.IsChallengeModeActive() then
        CheckGlowBasedRaidBuffs()
    end
    -- Check weapon enchants and stances
    CheckWeaponEnchants()
    CheckStances()
    ArrangeIcons()
end

-- M+ Glow-Based Detection, used when in M+ outside of combat
-- TODO: Might need to revisit if not consistent enough
local function CheckMissingBuffsViaGlow()
    ReleaseAllIcons()
    wipe(currentMissingBuffs)

    CheckGlowBasedRaidBuffs()
    CheckWeaponEnchants()
    CheckStances()
    ArrangeIcons()
end

-- Check if tracking should be paused
local function IsTrackingPaused()
    return isPreviewActive
end

-- Main Check Function
local function CheckForMissingBuffs()
    -- Don't run checks when GUI or edit mode is open
    if IsTrackingPaused() then return end
    -- If in keystone, use glow-based checking
    if C_ChallengeMode.IsChallengeModeActive() then
        CheckMissingBuffsViaGlow()
        return
    end
    -- Throttled checks
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
    if not MBUFFS.db or not MBUFFS.db.Enabled then
        HideAllNotifications()
        return
    end
    -- In combat: only check combat-safe elements
    if InCombatLockdown() then
        CheckCombatSafeElements()
        return
    end
    if UnitIsDeadOrGhost("player") or C_PetBattles.IsInBattle() then
        HideAllNotifications()
        return
    end
    --if MBUFFS.db.HideWhileMounted and IsPlayerMounted() then
    --    HideAllNotifications()
    --    return
    --end
    wipe(currentMissingBuffs)
    -- Check custom buffs like flasks, food, weapon enchants, runes
    local customMissing = CheckCustomBuffs()
    for _, entry in ipairs(customMissing) do
        currentMissingBuffs[#currentMissingBuffs + 1] = entry
    end
    -- Check class buffs like raid buffs like Intellect, Fortitude, etc
    local consumablesDb = MBUFFS.db.Consumables or {}
    local raidBuffsSettings = consumablesDb.RaidBuffs or {}
    local raidBuffsEnabled = raidBuffsSettings.Enabled ~= false
    local raidBuffsLoadMet = IsLoadConditionMet(raidBuffsSettings.LoadCondition)
    if playerBuffs and raidBuffsEnabled and raidBuffsLoadMet then
        for _, buff in ipairs(playerBuffs) do
            local spellToCheck = buff.spellbookId or buff.spellId
            if IsSpellKnown(spellToCheck) then
                local specOk = true
                if buff.specIds then
                    specOk = false
                    local spec = GetSpecialization()
                    if spec then
                        local specId = GetSpecializationInfo(spec)
                        for _, id in ipairs(buff.specIds) do
                            if specId == id then
                                specOk = true
                                break
                            end
                        end
                    end
                end
                if specOk then
                    local isMissing, needsReapply = CheckBuffStatus(buff)
                    if isMissing then
                        currentMissingBuffs[#currentMissingBuffs + 1] = { buff = buff, text = GENERALBUFF_TEXT }
                    elseif needsReapply then
                        currentMissingBuffs[#currentMissingBuffs + 1] = { buff = buff, text = REAPPLY_TEXT }
                    end
                end
            end
        end
    end

    -- Check stances/forms
    CheckStances()
    if #currentMissingBuffs > 0 then
        ShowMissingBuffs(currentMissingBuffs)
    else
        HideMissingBuffIcons()
    end
end

-- Event Handlers
local function OnAuraChange(unit, updateInfo)
    if not MBUFFS.db or not MBUFFS.db.Enabled then return end
    if IsTrackingPaused() then return end
    if unit ~= "player" and not (unit and (unit:find("party") or unit:find("raid"))) then return end
    if InCombatLockdown() then return end
    if updateInfo and not updateInfo.isFullUpdate then
        local hasRelevant = false
        if updateInfo.addedAuras then
            for _, aura in ipairs(updateInfo.addedAuras) do
                if issecretvalue(aura.isHelpful) then return end
                if aura.isHelpful then
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

-- Module init
function MBUFFS:OnInitialize()
    self.db = NRSKNUI.db.profile.MissingBuffs
    local _, class = UnitClass("player")
    playerClass = class
    playerBuffs = CLASS_BUFFS[class]
    self:SetEnabledState(false)
end

-- Module OnEnable
function MBUFFS:OnEnable()
    if not self.db or not self.db.Enabled then return end

    -- Create frames
    CreateContainerFrame()
    CreateStanceFrame()
    CreateStanceTextFrame()

    -- Register events
    self:RegisterEvent("UNIT_AURA", function(_, unit, updateInfo) OnAuraChange(unit, updateInfo) end)
    self:RegisterEvent("GROUP_ROSTER_UPDATE", function() CheckForMissingBuffs() end)
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
    self:RegisterEvent("UNIT_INVENTORY_CHANGED", function() C_Timer.After(0, CheckForMissingBuffs) end)
    self:RegisterEvent("TRAIT_CONFIG_UPDATED", function() C_Timer.After(0.5, CheckForMissingBuffs) end)
    self:RegisterEvent("SPELLS_CHANGED", function() C_Timer.After(0.5, CheckForMissingBuffs) end)
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function() C_Timer.After(1, CheckForMissingBuffs) end)
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED", function() C_Timer.After(1, CheckForMissingBuffs) end)
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function()
        CheckForMissingBuffs()
        UpdateStanceTextDisplay()
    end)
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", function()
        CheckForMissingBuffs()
        UpdateStanceTextDisplay()
    end)

    -- M+ events
    self:RegisterEvent("CHALLENGE_MODE_START", function() C_Timer.After(1, CheckForMissingBuffs) end)
    self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", function() C_Timer.After(0.1, CheckForMissingBuffs) end)
    self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", function() C_Timer.After(0.1, CheckForMissingBuffs) end)

    C_Timer.After(2, CheckForMissingBuffs)

    -- Register with edit mode
    self:RegisterEditModeElements()
end

-- Register all edit mode elements
function MBUFFS:RegisterEditModeElements()
    if not NRSKNUI.EditMode then return end

    -- Ensure frames exist before registering
    if not containerFrame then CreateContainerFrame() end
    if not stanceFrame then CreateStanceFrame() end
    if not stanceTextFrame then CreateStanceTextFrame() end

    local db = self.db
    local raidDb = db.RaidBuffDisplay or {}
    local stanceDb = db.StanceDisplay or {}
    local textDb = db.StanceText or {}

    -- Raid buff container
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
                containerFrame:ClearAllPoints()
                containerFrame:SetPoint(pos.AnchorFrom, anchorFrame, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        guiPath = "missingBuffs",
        onEditModeEnter = function() self:SetEditModeActive(true) end,
        onEditModeExit = function() self:SetEditModeActive(false) end,
    })

    -- Stance icon frame
    NRSKNUI.EditMode:RegisterElement({
        key = "MissingStanceIcon",
        displayName = "Missing Stance Icon",
        frame = stanceFrame,
        getPosition = function()
            return stanceDb.Position or {}
        end,
        setPosition = function(pos)
            stanceDb.Position = stanceDb.Position or {}
            stanceDb.Position.AnchorFrom = pos.AnchorFrom
            stanceDb.Position.AnchorTo = pos.AnchorTo
            stanceDb.Position.XOffset = pos.XOffset
            stanceDb.Position.YOffset = pos.YOffset
            if stanceFrame then
                local anchorFrame = NRSKNUI:ResolveAnchorFrame(stanceDb.anchorFrameType, stanceDb.ParentFrame)
                stanceFrame:ClearAllPoints()
                stanceFrame:SetPoint(pos.AnchorFrom, anchorFrame, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        guiPath = "missingBuffs",
        onEditModeEnter = function() self:SetEditModeActive(true) end,
        onEditModeExit = function() self:SetEditModeActive(false) end,
    })

    -- Stance text frame
    NRSKNUI.EditMode:RegisterElement({
        key = "StanceText",
        displayName = "Stance Text",
        frame = stanceTextFrame,
        getPosition = function()
            return textDb.Position or {}
        end,
        setPosition = function(pos)
            textDb.Position = textDb.Position or {}
            textDb.Position.AnchorFrom = pos.AnchorFrom
            textDb.Position.AnchorTo = pos.AnchorTo
            textDb.Position.XOffset = pos.XOffset
            textDb.Position.YOffset = pos.YOffset
            if stanceTextFrame then
                local anchorFrame = NRSKNUI:ResolveAnchorFrame(textDb.anchorFrameType, textDb.ParentFrame)
                stanceTextFrame:ClearAllPoints()
                stanceTextFrame:SetPoint(pos.AnchorFrom, anchorFrame, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        guiPath = "missingBuffs",
        onEditModeEnter = function() self:SetEditModeActive(true) end,
        onEditModeExit = function() self:SetEditModeActive(false) end,
    })
end

-- Module OnDisable
function MBUFFS:OnDisable()
    self:UnregisterAllEvents()
    HideAllNotifications()

    -- Unregister from edit mode
    if NRSKNUI.EditMode then
        NRSKNUI.EditMode:UnregisterElement("MissingBuffs")
        NRSKNUI.EditMode:UnregisterElement("MissingStanceIcon")
        NRSKNUI.EditMode:UnregisterElement("StanceText")
    end
end

-- Public API
function MBUFFS:Refresh()
    if self.db and self.db.Enabled then
        self:OnEnable()
        if not IsTrackingPaused() then
            CheckForMissingBuffs()
        end
    else
        self:OnDisable()
    end
end

-- Public settings applier, called from GUI when the user makes changes
function MBUFFS:ApplySettings()
    local db = self.db
    if not db then return end

    -- If preview is showing, refresh preview with new settings
    if IsTrackingPaused() then
        self:RefreshPreview()
        return
    end

    local raidDb = db.RaidBuffDisplay or {}
    local stanceDb = db.StanceDisplay or {}
    local textDb = db.StanceText or {}

    -- Update container frame with custom anchor frame support
    if containerFrame then
        local pos = raidDb.Position or {}
        local anchorFrame = NRSKNUI:ResolveAnchorFrame(raidDb.anchorFrameType, raidDb.ParentFrame)
        containerFrame:ClearAllPoints()
        containerFrame:SetPoint(
            pos.AnchorFrom or "CENTER",
            anchorFrame,
            pos.AnchorTo or "CENTER",
            pos.XOffset or 0,
            pos.YOffset or 200
        )
        containerFrame:SetFrameStrata(raidDb.Strata or db.Strata or "HIGH")
    end

    -- Update stance frame with custom anchor frame support
    if stanceFrame then
        local pos = stanceDb.Position or {}
        local iconSize = stanceDb.IconSize or db.IconSize or 48
        local anchorFrame = NRSKNUI:ResolveAnchorFrame(stanceDb.anchorFrameType, stanceDb.ParentFrame)
        stanceFrame:SetSize(iconSize, iconSize)
        stanceFrame:ClearAllPoints()
        stanceFrame:SetPoint(
            pos.AnchorFrom or "CENTER",
            anchorFrame,
            pos.AnchorTo or "CENTER",
            pos.XOffset or 0,
            pos.YOffset or 150
        )
        stanceFrame:SetFrameStrata(stanceDb.Strata or db.Strata or "HIGH")

        -- Update stance frame font
        NRSKNUI:ApplyFont(stanceFrame.text, db.Font, db.FontSize or 12, db.FontOutline)
    end

    -- Update stance text frame with custom anchor frame support
    if stanceTextFrame then
        local pos = textDb.Position or {}
        local anchorFrom = pos.AnchorFrom or "CENTER"
        local anchorFrame = NRSKNUI:ResolveAnchorFrame(textDb.anchorFrameType, textDb.ParentFrame)
        NRSKNUI:ApplyFont(stanceTextFrame.text, textDb.Font, textDb.FontSize or 14, textDb.FontOutline)
        stanceTextFrame:ClearAllPoints()
        stanceTextFrame:SetPoint(
            anchorFrom,
            anchorFrame,
            pos.AnchorTo or "CENTER",
            pos.XOffset or 0,
            pos.YOffset or 100
        )
        stanceTextFrame:SetFrameStrata(textDb.Strata or "HIGH")

        -- Update text alignment based on anchor point
        local textPoint = NRSKNUI:GetTextPointFromAnchor(anchorFrom)
        local textJustify = NRSKNUI:GetTextJustifyFromAnchor(anchorFrom)
        stanceTextFrame.text:ClearAllPoints()
        stanceTextFrame.text:SetPoint(textPoint, stanceTextFrame, textPoint, 0, 0)
        stanceTextFrame.text:SetJustifyH(textJustify)

        -- Show/hide based on enabled state
        if not textDb.Enabled then
            stanceTextFrame:Hide()
        end
    end

    -- Update all active icons
    for i, iconFrame in ipairs(activeIcons) do
        if currentMissingBuffs[i] then
            UpdateIconAppearance(iconFrame, currentMissingBuffs[i].buff, currentMissingBuffs[i].text)
        end
    end
    ArrangeIcons()
    UpdateStanceTextDisplay()
end

-- Setup preview stuff
local function ShowPreviewIcons()
    -- Create frames if needed
    if not containerFrame then CreateContainerFrame() end
    if not stanceFrame then CreateStanceFrame() end
    if not stanceTextFrame then CreateStanceTextFrame() end

    local db = MBUFFS.db
    local raidDb = db.RaidBuffDisplay or {}
    local stanceDb = db.StanceDisplay or {}
    local textDb = db.StanceText or {}

    -- Show raid buff preview with sample buffs
    local previewBuffs = {
        { buff = { spellId = 381748, text = "" },   text = "" },
        { buff = { spellId = 1126, text = "" },     text = "" },
        { buff = { spellId = 21562, text = "" },    text = "" },
        { buff = { spellId = 1459, text = "" },     text = "" },
        { buff = { spellId = 462854, text = "" },   text = "" },
        { buff = { spellId = 6673, text = "" },     text = "" },
        { buff = { spellId = 1235110, text = "" },  text = "" },
        { buff = { spellId = 462181, text = "" },   text = "" },
        { buff = { spellId = 1264426, text = "" },  text = "" },
        { buff = { spellId = 180608, text = "MH" }, text = "MH" },
        { buff = { spellId = 180608, text = "OH" }, text = "OH" },
    }

    wipe(currentMissingBuffs)
    for _, entry in ipairs(previewBuffs) do
        currentMissingBuffs[#currentMissingBuffs + 1] = entry
    end
    ShowMissingBuffs(previewBuffs)

    -- Show stance icon preview
    local previewStanceSpell = 386164
    local texture = GetSpellTexture(previewStanceSpell)
    if texture and stanceFrame then
        local iconSize = stanceDb.IconSize or db.IconSize or 48
        stanceFrame.icon:SetTexture(texture)
        stanceFrame.text:SetText("MISSING")
        stanceFrame:SetSize(iconSize, iconSize)
        NRSKNUI:ApplyFont(stanceFrame.text, db.Font, db.FontSize or 12, db.FontOutline)

        -- Apply custom anchor frame for stance icon
        local pos = stanceDb.Position or {}
        local anchorFrame = NRSKNUI:ResolveAnchorFrame(stanceDb.anchorFrameType, stanceDb.ParentFrame)
        stanceFrame:ClearAllPoints()
        stanceFrame:SetPoint(
            pos.AnchorFrom or "CENTER",
            anchorFrame,
            pos.AnchorTo or "CENTER",
            pos.XOffset or 0,
            pos.YOffset or 150
        )
        stanceFrame:SetFrameStrata(stanceDb.Strata or db.Strata or "HIGH")
        stanceFrame:Show()
    end

    -- Show stance text preview - respect Enabled toggle
    if stanceTextFrame then
        -- Check if stance text is enabled
        if not textDb.Enabled then
            stanceTextFrame:Hide()
        else
            -- Apply font settings
            NRSKNUI:ApplyFont(stanceTextFrame.text, textDb.Font, textDb.FontSize or 14, textDb.FontOutline)

            -- Get preview text and color from per-stance settings
            local previewText = "Battle Stance"
            local previewColor = { 1, 1, 1, 1 }

            -- Check if we have per-stance settings for the preview stance
            local classData = textDb["WARRIOR"]
            if classData then
                local stanceSettings = classData["386164"] -- Battle Stance
                if stanceSettings then
                    if stanceSettings.Text and stanceSettings.Text ~= "" then
                        previewText = stanceSettings.Text
                    end
                    if stanceSettings.Color then
                        previewColor = stanceSettings.Color
                    end
                end
            end

            stanceTextFrame.text:SetText(previewText)
            stanceTextFrame.text:SetTextColor(previewColor[1], previewColor[2], previewColor[3], previewColor[4] or 1)

            -- Apply custom anchor frame for stance text
            local pos = textDb.Position or {}
            local anchorFrom = pos.AnchorFrom or "CENTER"
            local anchorFrame = NRSKNUI:ResolveAnchorFrame(textDb.anchorFrameType, textDb.ParentFrame)
            stanceTextFrame:ClearAllPoints()
            stanceTextFrame:SetPoint(
                anchorFrom,
                anchorFrame,
                pos.AnchorTo or "CENTER",
                pos.XOffset or 0,
                pos.YOffset or 100
            )
            stanceTextFrame:SetFrameStrata(textDb.Strata or "HIGH")

            -- Update text alignment based on anchor point
            local textPoint = NRSKNUI:GetTextPointFromAnchor(anchorFrom)
            local textJustify = NRSKNUI:GetTextJustifyFromAnchor(anchorFrom)
            stanceTextFrame.text:ClearAllPoints()
            stanceTextFrame.text:SetPoint(textPoint, stanceTextFrame, textPoint, 0, 0)
            stanceTextFrame.text:SetJustifyH(textJustify)
            stanceTextFrame:Show()
        end
    end
end

-- Check if tracking is currently paused
function MBUFFS:IsPaused()
    return IsTrackingPaused()
end

-- Refresh preview appearanc
function MBUFFS:RefreshPreview()
    if not IsTrackingPaused() then return end
    ShowPreviewIcons()
end

-- Public ShowPreview for PreviewManager
function MBUFFS:ShowPreview()
    -- Ensure frames exist
    if not containerFrame then CreateContainerFrame() end
    if not stanceFrame then CreateStanceFrame() end
    if not stanceTextFrame then CreateStanceTextFrame() end
    isPreviewActive = true -- Mark preview as active, this pauses tracking
    ShowPreviewIcons()     -- Show preview icons
end

-- Public HidePreview for PreviewManager
function MBUFFS:HidePreview()
    isPreviewActive = false                                                          -- Mark preview as inactive
    HideAllNotifications()                                                           -- Hide all preview elements
    wipe(currentMissingBuffs)
    if self.db and self.db.Enabled then C_Timer.After(0.1, CheckForMissingBuffs) end -- Resume tracking if enabled
end

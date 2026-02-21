-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Safety check
if not NorskenUI then
    error("MissingBuffs: Addon object not initialized. Check file load order!")
    return
end

-- Create module
---@class MissingBuffs: AceModule, AceEvent-3.0
local MBUFFS = NorskenUI:NewModule("MissingBuffs", "AceEvent-3.0")

-- Localization
local ipairs, pairs = ipairs, pairs
local wipe = wipe
local UnitClass, UnitExists, UnitIsDeadOrGhost = UnitClass, UnitExists, UnitIsDeadOrGhost
local UnitIsConnected, UnitCanAssist, UnitIsPlayer = UnitIsConnected, UnitCanAssist, UnitIsPlayer
local InCombatLockdown = InCombatLockdown
local GetNumGroupMembers = GetNumGroupMembers
local IsInRaid = IsInRaid
local GetTime = GetTime
local GetSpecialization, GetSpecializationInfo = GetSpecialization, GetSpecializationInfo
local CreateFrame = CreateFrame
local GetInventorySlotInfo, GetInventoryItemLink = GetInventorySlotInfo, GetInventoryItemLink
local GetItemInfo, GetInventoryItemTexture = GetItemInfo, GetInventoryItemTexture
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local issecretvalue = issecretvalue
local GetShapeshiftForm, GetShapeshiftFormInfo = GetShapeshiftForm, GetShapeshiftFormInfo
local tostring, tonumber = tostring, tonumber
local C_Spell, C_SpellBook, C_SpellActivationOverlay = C_Spell, C_SpellBook, C_SpellActivationOverlay
local C_PetBattles, C_ChallengeMode = C_PetBattles, C_ChallengeMode
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

-- Helper Functions to get spell and unit info
local function IsSpellKnown(spellId)
    return spellId and C_SpellBook.IsSpellKnown(spellId)
end
local function GetSpellTexture(spellId)
    if spellId and spellId > 0 then
        return C_Spell.GetSpellTexture(spellId)
    end
    return nil
end
local function IsValidTarget(unit)
    return UnitExists(unit)
        and not UnitIsDeadOrGhost(unit)
        and UnitIsConnected(unit)
        and UnitIsPlayer(unit)
        and UnitCanAssist("player", unit)
end

-- Helper to Check player buff status
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

-- Helper to Check unit buff status
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

-- Helper to get buff-providing classes present in the group
local function GetGroupBuffClasses()
    local classesInGroup = {}
    local groupSize = GetNumGroupMembers()

    -- Solo, only check player's own class
    if groupSize == 0 then
        if playerClass then
            classesInGroup[playerClass] = true
        end
        return classesInGroup
    end

    if IsInRaid() then
        for i = 1, groupSize do
            local unit = UNIT_STRINGS.raid[i]
            if UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
                local _, class = UnitClass(unit)
                if class and CLASS_BUFFS[class] then
                    classesInGroup[class] = true
                end
            end
        end
    else
        -- Check player
        if playerClass then
            classesInGroup[playerClass] = true
        end
        -- Check party members
        for i = 1, groupSize - 1 do
            local unit = UNIT_STRINGS.party[i]
            if UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
                local _, class = UnitClass(unit)
                if class and CLASS_BUFFS[class] then
                    classesInGroup[class] = true
                end
            end
        end
    end

    return classesInGroup
end

-- Check if player is missing a raid buff that someone in group can provide
local function CheckMissingRaidBuffsFromGroup()
    local missing = {}
    local groupSize = GetNumGroupMembers()

    -- Only check when in a group
    if groupSize == 0 then return missing end

    local classesInGroup = GetGroupBuffClasses()

    -- Check each class's buffs
    for class, _ in pairs(classesInGroup) do
        -- Skip player's own class buffs
        if class ~= playerClass then
            local classBuffs = CLASS_BUFFS[class]
            if classBuffs then
                for _, buff in ipairs(classBuffs) do
                    -- Check if player is missing this buff
                    local hasBuff = PlayerHasBuff(buff.spellId, buff.extraBuffSpellIds)
                    if not hasBuff then
                        missing[#missing + 1] = {
                            buff = buff,
                            text = GENERALBUFF_TEXT,
                        }
                    end
                end
            end
        end
    end

    return missing
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

-- Check weapon enchant status
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

    local hasEnchant
    if slot == "main" then
        hasEnchant = hasMain
    else
        hasEnchant = hasOff
    end
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

-- General buff icon creation
local function CreateIcon()
    local raidDb = MBUFFS.db.RaidBuffDisplay
    local iconFrame = NRSKNUI:CreateIconFrame(containerFrame, raidDb.IconSize)
    NRSKNUI:ApplyFontSettings(iconFrame, raidDb, nil)
    iconFrame.text:SetTextColor(1, 1, 1, 1)
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

-- Container for general buff icons
local function CreateContainerFrame()
    if containerFrame then return end
    local raidDb = MBUFFS.db.RaidBuffDisplay
    containerFrame = CreateFrame("Frame", "NRSKNUI_MissingBuffContainer", UIParent)
    containerFrame:SetSize(400, raidDb.IconSize)
    NRSKNUI:ApplyFramePosition(containerFrame, raidDb.Position, raidDb)
    containerFrame:Hide()
end

-- Warrior stance spell IDs for timer tracking
local WARRIOR_STANCE_SPELLS = {
    [386164] = true, -- Battle Stance
    [386196] = true, -- Berserker Stance
    [386208] = true, -- Defensive Stance
}
local STANCE_TIMER_DURATION = 3

-- Stance timer state
local stanceTimerHandle = nil
local stanceTimerActive = false

-- Stance icon creation
local function CreateStanceFrame()
    if stanceFrame then return end
    local stanceDb = MBUFFS.db.StanceDisplay

    stanceFrame = NRSKNUI:CreateIconFrame(UIParent, stanceDb.IconSize, {
        name = "NRSKNUI_MissingStanceIcon",
    })

    -- Position text above the icon
    stanceFrame.text:ClearAllPoints()
    stanceFrame.text:SetPoint("BOTTOM", stanceFrame, "TOP", 1, 4)

    -- Create cooldown frame for stance timer
    local cooldown = CreateFrame("Cooldown", nil, stanceFrame, "CooldownFrameTemplate")
    cooldown:SetAllPoints(stanceFrame)
    cooldown:SetFrameLevel(stanceFrame:GetFrameLevel() + 1)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetSwipeColor(0, 0, 0, 0.6)
    cooldown:SetReverse(true)
    cooldown:SetHideCountdownNumbers(false)

    -- Style cooldown text
    local cdText = cooldown:GetRegions()
    if cdText and cdText.SetFont then
        cdText:SetFont(NRSKNUI.FONT or STANDARD_TEXT_FONT, stanceDb.IconSize * 0.5, "OUTLINE")
        cdText:SetShadowColor(0, 0, 0, 0)
        cdText:SetShadowOffset(0, 0)
        cdText:ClearAllPoints()
        cdText:SetPoint("CENTER", stanceFrame, "CENTER", 1, 0)
    end

    -- Store for later use
    stanceFrame.cooldown = cooldown

    NRSKNUI:ApplyFramePosition(stanceFrame, stanceDb.Position, stanceDb)
    NRSKNUI:ApplyFontSettings(stanceFrame, stanceDb, nil)
    stanceFrame.text:SetTextColor(1, 1, 1, 1)
    stanceFrame:Hide()
end

-- Stance text frame
local function CreateStanceTextFrame()
    if stanceTextFrame then return end
    local textDb = MBUFFS.db.StanceText

    -- Create frame using helper
    stanceTextFrame = NRSKNUI:CreateTextFrame(UIParent, 200, 30, {
        name = "NRSKNUI_StanceTextDisplay",
    })

    -- Apply position and font settings
    NRSKNUI:ApplyFramePosition(stanceTextFrame, textDb.Position, textDb)
    NRSKNUI:ApplyFontSettings(stanceTextFrame, textDb, nil)

    -- Text alignment based on anchor point
    local textPoint = NRSKNUI:GetTextPointFromAnchor(textDb.Position.AnchorFrom)
    local textJustify = NRSKNUI:GetTextJustifyFromAnchor(textDb.Position.AnchorFrom)
    stanceTextFrame.text:ClearAllPoints()
    stanceTextFrame.text:SetPoint(textPoint, stanceTextFrame, textPoint, 0, 0)
    stanceTextFrame.text:SetJustifyH(textJustify)
    stanceTextFrame.text:SetTextColor(1, 1, 1, 1)

    stanceTextFrame:Hide()
end

-- Show the stance icon
local function ShowStanceIcon(spellId, reverseIcon, currentSpellId)
    if not stanceFrame then CreateStanceFrame() end
    local stanceDb = MBUFFS.db.StanceDisplay
    if stanceFrame then
        -- Apply texture settings
        local displaySpellId = (reverseIcon and currentSpellId) and currentSpellId or spellId
        local texture = GetSpellTexture(displaySpellId)
        stanceFrame.icon:SetTexture(texture)

        -- Apply Font Settings
        NRSKNUI:ApplyFontSettings(stanceFrame, stanceDb, nil)
        stanceFrame.text:SetText(reverseIcon and "" or MISSING_TEXT)

        -- Apply icon size settings
        stanceFrame:SetSize(stanceDb.IconSize, stanceDb.IconSize)
        stanceFrame.icon:SetSize(stanceDb.IconSize, stanceDb.IconSize)

        -- Apply position with custom anchor frame
        NRSKNUI:ApplyFramePosition(stanceFrame, stanceDb.Position, stanceDb)

        -- Show frame
        stanceFrame:Show()
    end
end

-- Stance text display functions
local function UpdateStanceTextDisplay()
    if not MBUFFS.db then return end
    local textDb = MBUFFS.db.StanceText

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
        NRSKNUI:ApplyFontSettings(stanceTextFrame, textDb, nil)

        -- Update position
        NRSKNUI:ApplyFramePosition(stanceTextFrame, textDb.Position, textDb)

        -- Update text alignment based on anchor point
        local textPoint = NRSKNUI:GetTextPointFromAnchor(textDb.Position.AnchorFrom)
        local textJustify = NRSKNUI:GetTextJustifyFromAnchor(textDb.Position.AnchorFrom)
        stanceTextFrame.text:ClearAllPoints()
        stanceTextFrame.text:SetPoint(textPoint, stanceTextFrame, textPoint, 0, 0)
        stanceTextFrame.text:SetJustifyH(textJustify)
        stanceTextFrame:Show()
    end
end

-- Update icon texture, font and size
local function UpdateIconAppearance(iconFrame, buff, text)
    -- Apply texture settings
    local texture = GetSpellTexture(buff.spellId)
    if not texture then texture = buff.iconTexture or WEAPON_ENCHANT_ICON end
    iconFrame.icon:SetTexture(texture)

    -- Apply font settings
    NRSKNUI:ApplyFontSettings(iconFrame, MBUFFS.db.RaidBuffDisplay, nil)
    iconFrame.text:SetText(text or buff.text or GENERALBUFF_TEXT)

    -- Apply size settings
    iconFrame:SetSize(MBUFFS.db.RaidBuffDisplay.IconSize, MBUFFS.db.RaidBuffDisplay.IconSize)
    iconFrame.icon:SetAllPoints(iconFrame)
end

-- Icon arranger, uses center horizontal layout
-- TODO: Maybe add left and right layout?
local function ArrangeIcons()
    if not containerFrame then return end
    local raidDb = MBUFFS.db.RaidBuffDisplay or {}
    local count = #activeIcons

    if count == 0 then
        containerFrame:Hide()
        return
    end

    local totalWidth = (raidDb.IconSize * count) + (raidDb.IconSpacing * (count - 1))
    containerFrame:SetSize(totalWidth, raidDb.IconSize)

    local startX = -totalWidth / 2 + raidDb.IconSize / 2
    for i, iconFrame in ipairs(activeIcons) do
        iconFrame:ClearAllPoints()
        iconFrame:SetPoint("CENTER", containerFrame, "CENTER", startX + (i - 1) * (raidDb.IconSize + raidDb.IconSpacing),
            0)
        iconFrame:Show()
    end

    -- Update container position
    NRSKNUI:ApplyFramePosition(containerFrame, raidDb.Position, raidDb)

    containerFrame:Show()
end

-- Check stances/forms
local function CheckStances()
    -- For warriors, don't interfere while stance timer is active and hide when timer is over
    if playerClass == "WARRIOR" and stanceTimerActive then
        UpdateStanceTextDisplay()
        return
    end

    if stanceFrame then
        stanceFrame:Hide()
    end
    -- Also update stance text display
    UpdateStanceTextDisplay()
    if not MBUFFS.db then return end

    -- Check if stances feature is enabled at all
    local stancesDb = MBUFFS.db.Stances
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

        -- When you enter voidform cd, standard tracking is overriden and we cant check this in combat
        -- This is fine since almost always, you would want to be in shadowform pre combat so we just return early here
        if InCombatLockdown or C_ChallengeMode.IsChallengeModeActive() then
            return
        end

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
    local reverseIconKey = specName and (specName .. "ReverseIcon")
    local reverseIcon = reverseIconKey and classSettings[reverseIconKey] and true or false
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
                ShowStanceIcon(requiredStanceId, reverseIcon, currentSpellId)
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

-- Show stance timer, only doing this for warrior since they have a 3 second CD when swapping stances
local function ShowStanceTimer()
    if not stanceFrame then CreateStanceFrame() end
    if not stanceFrame then return end
    if not stanceFrame.cooldown then return end

    -- Mark timer as active so CheckStances won't interfere
    stanceTimerActive = true

    -- Start cooldown animation
    stanceFrame.cooldown:SetAllPoints(stanceFrame)
    stanceFrame.cooldown:SetCooldown(GetTime(), STANCE_TIMER_DURATION)
    stanceFrame:Show()

    -- After duration, clear flag and re-check stances
    stanceTimerHandle = C_Timer.NewTimer(STANCE_TIMER_DURATION, function()
        stanceTimerHandle = nil
        stanceTimerActive = false
        if stanceFrame and not isPreviewActive then
            CheckStances()
        end
    end)
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
    if stanceFrame then
        stanceFrame:Hide()
    end
    if stanceTextFrame then
        stanceTextFrame:Hide()
    end
end

-- Check only weapon enchants
local function CheckWeaponEnchants()
    if not MBUFFS.db then return end
    local consumablesDb = MBUFFS.db.Consumables or {}
    local raidDb = MBUFFS.db.RaidBuffDisplay or {}
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
                    local iconSize = raidDb.IconSize

                    -- Set texture directly
                    iconFrame.icon:SetTexture(displayIcon)
                    iconFrame:SetSize(iconSize, iconSize)
                    iconFrame.icon:SetSize(iconSize, iconSize)
                    NRSKNUI:ApplyFontSettings(iconFrame, raidDb, nil)
                    iconFrame.text:SetText(text)
                    activeIcons[#activeIcons + 1] = iconFrame
                    currentMissingBuffs[#currentMissingBuffs + 1] = { buff = buff, text = text }
                end
            end
        end
    end
end

-- Check glow-based raid buffs
local function CheckGlowBasedRaidBuffs()
    local consumablesDb = MBUFFS.db.Consumables or {}
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
    if raidBuffsEnabled and raidBuffsLoadMet then
        -- Track which buff spellIds we've already added to avoid duplicates
        local addedBuffs = {}

        -- First check player's own class buffs
        if playerBuffs then
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
                            addedBuffs[buff.spellId] = true
                        elseif needsReapply then
                            currentMissingBuffs[#currentMissingBuffs + 1] = { buff = buff, text = REAPPLY_TEXT }
                            addedBuffs[buff.spellId] = true
                        end
                    end
                end
            end
        end

        -- Then check if player is missing buffs from other classes in the group
        local groupMissing = CheckMissingRaidBuffsFromGroup()
        for _, entry in ipairs(groupMissing) do
            -- Only add if we haven't already added this buff
            if not addedBuffs[entry.buff.spellId] then
                currentMissingBuffs[#currentMissingBuffs + 1] = entry
                addedBuffs[entry.buff.spellId] = true
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

-- Update db, used for profile changes
function MBUFFS:UpdateDB()
    self.db = NRSKNUI.db.profile.MissingBuffs
end

-- Module init
function MBUFFS:OnInitialize()
    self:UpdateDB()
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

    C_Timer.After(0.5, function()
        self:ApplySettings()
    end)

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

    -- For Warrior stance icon, show a 3 second cooldown when any stance spell is casted
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
        if unit ~= "player" then return end
        if playerClass ~= "WARRIOR" then return end
        if not WARRIOR_STANCE_SPELLS[spellID] then return end
        if isPreviewActive then return end

        -- Check if stance display is enabled
        local stanceDb = self.db and self.db.StanceDisplay
        if not stanceDb or not stanceDb.Enabled then return end

        ShowStanceTimer()
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

    local raidDb = self.db.RaidBuffDisplay
    local stanceDb = self.db.StanceDisplay
    local textDb = self.db.StanceText

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

    -- Cancel stance timer if active
    if stanceTimerHandle then
        stanceTimerHandle:Cancel()
        stanceTimerHandle = nil
    end

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
    if not self.db then return end

    -- If preview is showing, refresh preview with new settings
    if IsTrackingPaused() then
        self:RefreshPreview()
        return
    end

    local raidDb = self.db.RaidBuffDisplay
    local stanceDb = self.db.StanceDisplay
    local textDb = self.db.StanceText

    -- Update container frame
    if containerFrame then
        NRSKNUI:ApplyFramePosition(containerFrame, raidDb.Position, raidDb)
    end

    -- Update stance frame
    if stanceFrame then
        stanceFrame:SetSize(stanceDb.IconSize, stanceDb.IconSize)
        NRSKNUI:ApplyFramePosition(stanceFrame, stanceDb.Position, stanceDb)

        -- Update stance frame font
        NRSKNUI:ApplyFontSettings(stanceFrame, stanceDb, nil)
    end

    -- Update stance text frame
    if stanceTextFrame then
        NRSKNUI:ApplyFontSettings(stanceTextFrame, textDb, nil)
        NRSKNUI:ApplyFramePosition(stanceTextFrame, textDb.Position, textDb)

        -- Update text alignment based on anchor point
        local textPoint = NRSKNUI:GetTextPointFromAnchor(textDb.Position.AnchorFrom)
        local textJustify = NRSKNUI:GetTextJustifyFromAnchor(textDb.Position.AnchorFrom)
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

    local raidDb = MBUFFS.db.RaidBuffDisplay or {}
    local stanceDb = MBUFFS.db.StanceDisplay or {}
    local textDb = MBUFFS.db.StanceText or {}

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
        stanceFrame.icon:SetTexture(texture)
        stanceFrame.text:SetText("MISSING")
        stanceFrame:SetSize(stanceDb.IconSize, stanceDb.IconSize)
        NRSKNUI:ApplyFontSettings(stanceFrame, stanceDb, nil)
        NRSKNUI:ApplyFramePosition(stanceFrame, stanceDb.Position, stanceDb)
        stanceFrame:Show()
    end

    -- Show stance text preview - respect Enabled toggle
    if stanceTextFrame then
        -- Check if stance text is enabled
        if not textDb.Enabled then
            stanceTextFrame:Hide()
        else
            -- Apply font settings
            NRSKNUI:ApplyFontSettings(stanceTextFrame, textDb, nil)

            -- Get preview text and color from per-stance settings
            local previewText = "Battle Stance"
            local previewColor = { 1, 1, 1, 1 }

            -- Check if we have per-stance settings for the preview stance
            local classData = textDb["WARRIOR"]
            if classData then
                local stanceSettings = classData["386164"]
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

            NRSKNUI:ApplyFramePosition(stanceTextFrame, textDb.Position, textDb)

            -- Update text alignment based on anchor point
            local textPoint = NRSKNUI:GetTextPointFromAnchor(textDb.Position.AnchorFrom)
            local textJustify = NRSKNUI:GetTextJustifyFromAnchor(textDb.Position.AnchorFrom)
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

-- Refresh preview appearance
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
    isPreviewActive = true
    ShowPreviewIcons()
end

-- Public HidePreview for PreviewManager
function MBUFFS:HidePreview()
    isPreviewActive = false
    HideAllNotifications()
    wipe(currentMissingBuffs)
    if self.db and self.db.Enabled then C_Timer.After(0.1, CheckForMissingBuffs) end
end

---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Global API functions

local GetNumGroupMembers = GetNumGroupMembers
local UnitTokenFromGUID = UnitTokenFromGUID
local UnitIsFeignDeath = UnitIsFeignDeath
local GetUnitName = GetUnitName
local UnitIsDead = UnitIsDead
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local IsInRaid = IsInRaid
local select = select
local type = type

local EditModeManagerFrame = EditModeManagerFrame

local IsAddonLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
local GetSpellCooldown = C_Spell and C_Spell.GetSpellCooldown

---Check if ElvUI is loaded and ElvUI skinning is enabled, so a module should skip its own load.
---@return boolean
function NRSKNUI:ShouldNotLoadModule()
    return IsAddonLoaded('ElvUI') and NRSKNUI.db.profile.UseElvUI.Enabled
end

-- Addons that bring their own oUF copy.
local ConflictingUFAddons = { 'ElvUI', 'UnhaltedUnitFrames', 'EllesmereUIUnitFrames' }

-- Addons that set UIParent's scale themselves.
local ConflictingScaleAddons = { 'ElvUI', 'UnhaltedUnitFrames', 'EllesmereUI' }

---@param addons string[]
---@return string|nil
local function FirstLoaded(addons)
    for i = 1, #addons do
        if IsAddonLoaded(addons[i]) then return addons[i] end
    end
    return nil
end

---Name of the loaded addon that owns the unit frames, if any.
---Only meaningful from PLAYER_LOGIN onwards, addons sorted after us have not loaded before that.
---@return string|nil
function NRSKNUI:GetConflictingUFAddon()
    return FirstLoaded(ConflictingUFAddons)
end

---Name of the loaded addon that owns UIParent's scale, if any. Same timing rule as above.
---@return string|nil
function NRSKNUI:GetConflictingScaleAddon()
    return FirstLoaded(ConflictingScaleAddons)
end

---Check if another UI addon owns the unit frames, so the UnitFrames module must not load at all.
---@return boolean
function NRSKNUI:ShouldNotLoadUF()
    if not self.db.profile.UseOtherUF.Enabled then return false end
    return self:GetConflictingUFAddon() ~= nil
end

---Check if Blizzard Edit Mode is currently active
---@return boolean
function NRSKNUI:IsEditModeActive()
    return EditModeManagerFrame and EditModeManagerFrame:IsShown()
end

---Get justification based on anchor point
---@param anchorPoint string
---@return string
function NRSKNUI:GetJustifyFromAnchor(anchorPoint)
    if not anchorPoint then return 'CENTER' end
    if anchorPoint == 'RIGHT' or anchorPoint == 'TOPRIGHT' or anchorPoint == 'BOTTOMRIGHT' then
        return 'RIGHT'
    elseif anchorPoint == 'LEFT' or anchorPoint == 'TOPLEFT' or anchorPoint == 'BOTTOMLEFT' then
        return 'LEFT'
    end
    return 'CENTER'
end

---Check if a specific class is present in the current group.
---@param classFilenameToCheck 'WARRIOR'|'HUNTER'|'ROGUE'|'MAGE'|'PRIEST'|'WARLOCK'|'DRUID'|'SHAMAN'|'PALADIN'|'DEATHKNIGHT'|'MONK'|'DEMONHUNTER'
---@return boolean
function NRSKNUI:IsClassInGroup(classFilenameToCheck)
    local numMembers = GetNumGroupMembers()
    local prefix = (IsInRaid() and 'raid') or 'party'
    local maxCheck = (IsInRaid() and numMembers) or (numMembers - 1)
    for i = 1, maxCheck do
        local unit = prefix .. i
        local classFilename = select(2, UnitClass(unit))
        if classFilename == classFilenameToCheck then
            return true
        end
    end
    return false
end

---Check if a unit is actually dead, ignoring hunters feign death.
---@param unit string
---@return boolean
function NRSKNUI:IsUnitReallyDead(unit)
    return UnitIsDead(unit) and not UnitIsFeignDeath(unit)
end

---Safely get a unit token from a GUID.
---@param GUID string
---@return string|nil unitToken
function NRSKNUI:SafeGetUnitFromGUID(GUID)
    if not self:IsSafeValue(GUID) then return nil end -- GUID is nil or secret.
    if self.MyGUID == GUID then return 'player' end   -- GUID is the player.

    -- Check if UnitTokenFromGUID is available.
    if UnitTokenFromGUID then
        local Unit = UnitTokenFromGUID(GUID)
        if Unit then
            return Unit
        end
    end

    -- Iterate through the group to find a matching GUID.
    local numMembers = GetNumGroupMembers()
    local prefix = ((IsInRaid() and 'raid') or 'party')
    local maxCheck = ((IsInRaid() and numMembers) or (numMembers - 1))
    for i = 1, maxCheck do
        local Unit = prefix .. i
        if UnitGUID(Unit) == GUID then
            return Unit
        end
    end

    -- All checks failed, return nil.
    return nil
end

---Get unit name safely, returns nil if unit or name is secret
---@param unit string
---@return string|nil
function NRSKNUI:GetSafeUnitName(unit)
    if not self:IsSafeValue(unit) then return nil end -- unit is nil or secret.
    if type(unit) ~= "string" then return nil end     -- unit is not a string.

    local name = GetUnitName(unit, false)
    if not self:IsSafeValue(name) then return nil end

    return name:gsub("%s?%(%*%)", "")
end

---Safely get text from a FontString, returns nil if secret
---@param fontString FontString
---@return string|nil
function NRSKNUI:GetSafeText(fontString)
    if not fontString or not fontString.GetText then return nil end

    local text = fontString:GetText()
    if not self:IsSafeValue(text) then return nil end

    return text
end

---Get spell cooldown information for a given spell ID.
---@param spellID number
---@return SpellCooldownInfo|nil
function NRSKNUI:GetSpellCooldownInfo(spellID)
    local info = GetSpellCooldown(spellID)
    if info then
        return info
    end
    return nil
end

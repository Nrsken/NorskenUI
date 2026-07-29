---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')

local UnitHealthMissing = UnitHealthMissing
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local UnitIsTapDenied = UnitIsTapDenied
local CheckInteractDistance = CheckInteractDistance
local UnitExists = UnitExists
local UnitInRange = UnitInRange
local UnitIsUnit = UnitIsUnit
local UnitIsPlayer = UnitIsPlayer
local UnitCanAttack = UnitCanAttack
local UnitPhaseReason = UnitPhaseReason
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local wipe = wipe
local ipairs = ipairs
local pairs = pairs
local next = next

local IsSpellInRange = C_Spell and C_Spell.IsSpellInRange
local IsSpellInSpellBook = C_SpellBook and C_SpellBook.IsSpellInSpellBook

---Prime the smoothing function for a health or power element.
---@param element table Health element
local function PrimeSmoothing(element)
    if element.smoothing ~= element.nuiSmoothing then
        element.smoothing = element.nuiSmoothing
    end
end

---Post-update function for health and power elements.
---@param element table Health element
---@param unit string
---@param cur number
---@param max number
---@param lossPerc number
function UF.PostUpdateHealth(element, unit, cur, max, lossPerc)
    local healthBackground = element.healthBackground
    if healthBackground then
        healthBackground:SetMinMaxValues(0, max)
        healthBackground:SetValue(UnitHealthMissing(unit, true), element.smoothing)

        -- Dead units sit at empty health, so the background bar fills the whole frame.
        local bg = UnitIsDeadOrGhost(unit) and NRSKNUI.Colors.status.Dead or element.nuiBackground
        healthBackground:SetStatusBarColor(bg[1], bg[2], bg[3], bg[4])
    end

    -- Overabsorb handling
    local over = element.OverDamageAbsorb
    local damage = element.DamageAbsorb
    if over and damage then
        over:SetMinMaxValues(damage:GetMinMaxValues())
        over:SetValue(damage:GetValue())
    end

    PrimeSmoothing(element)
end

---Post-update function for power elements.
---@param element table Power element
function UF.PostUpdatePower(element)
    PrimeSmoothing(element)
end

---Applies the flat power colour. oUF still runs its own colour pass with every flag off, so the
---custom colour has to be re-applied here rather than once in Configure.
---@param element oUF.Power
function UF.PostUpdatePowerColor(element)
    if element.nuiColorByPower then return end

    local color = element.nuiColor
    if color then
        element:SetStatusBarColor(color[1], color[2], color[3], color[4])
    end
end

-- Active spell set per relationship, filtered to spells actually in the spellbook.
local activeSpells = {
    enemy = {},
    friendly = {},
    resurrect = {},
    pet = {},
}

---Rebuild the active spell set for the player's class. Wired to SPELLS_CHANGED.
function UF:UpdateActiveRangeSpells()
    local spells = UF.RangeSpells

    local function Build(category, list)
        wipe(activeSpells[category])
        for _, spellID in ipairs(list or {}) do
            if IsSpellInSpellBook(spellID, nil, true) then
                activeSpells[category][spellID] = true
            end
        end
    end

    Build('enemy', spells.ENEMY[NRSKNUI.MyClass])
    Build('friendly', spells.FRIENDLY[NRSKNUI.MyClass])
    Build('resurrect', spells.RESURRECT[NRSKNUI.MyClass])
    Build('pet', spells.PET[NRSKNUI.MyClass])
end

---Test a set of spells against a unit. First castable-in-range spell wins.
---@return boolean|nil # true in range, false out of range, nil couldn't check (secret passes through)
local function UnitSpellRange(unit, spells)
    local isNotInRange = false

    for spellID in pairs(spells) do
        local inRange = IsSpellInRange(spellID, unit)
        if NRSKNUI:IsSecretValue(inRange) then
            return inRange      -- secret result, pass through
        elseif inRange then
            return true         -- at least one spell is in range
        elseif inRange ~= nil then
            isNotInRange = true -- at least one spell is castable but out of range
        end
    end
    if isNotInRange then
        return false -- all castable spells are out of range
    end
end

---Spell-based range with an out-of-combat CheckInteractDistance fallback.
local function UnitInSpellsRange(unit, category)
    local spells = activeSpells[category]
    local inRange = not next(spells) and 1 or UnitSpellRange(unit, spells) -- No known spells for this category: 1 means "assume in range unless interact says otherwise".
    if NRSKNUI:IsSecretValue(inRange) then
        return inRange
    end

    -- CheckInteractDistance is protected, only touch it out of combat.
    if (not inRange or inRange == 1) and not NRSKNUI:InCombat() then
        return CheckInteractDistance(unit, 4)
    end
    return (inRange == nil and 1) or inRange
end

---Friendly units: UnitInRange first, then friendly spells.
local function FriendlyRangeCheck(unit, frame)
    -- UnitPhaseReason and UnitInRaid return secrets once the unit's identity is restricted.
    local secret = NRSKNUI:IsSecretUnit(unit)

    if not secret and UnitIsPlayer(unit) and UnitPhaseReason(unit) then
        return false
    end

    local inRange, wasChecked = UnitInRange(unit)
    if NRSKNUI:IsSecretValue(wasChecked) then
        -- Group members hand the secret result to SetAlphaFromBoolean via the stash.
        if UnitInParty(unit) or (not secret and UnitInRaid(unit)) then
            frame.RangeIsInRange = inRange
            frame.RangeWasChecked = wasChecked
            return
        end
    elseif wasChecked and not inRange then
        return false -- Blizzard checked and the unit is out of range.
    end

    return UnitInSpellsRange(unit, 'friendly')
end

---Fade one frame's alpha to reflect whether its unit is in range. Shared by reference.
---@param frame oUF.UnitFrame
---@param unit string
function UF.UpdateRangeAlpha(frame, unit)
    -- Clear any stashed secret from the previous pass so it can't go stale.
    frame.RangeIsInRange = nil
    frame.RangeWasChecked = nil

    local inAlpha = frame.nuiRangeIn or 1
    local outAlpha = frame.nuiRangeOut or 0.6

    -- Player is always in range, dont need to check anything else.
    if not unit or unit == 'player' or not UnitExists(unit) then
        frame:SetAlpha(inAlpha)
        return
    end

    local inRange
    -- Dead or ghost units, check for a resurrect spell in range.
    if UnitIsDeadOrGhost(unit) then
        inRange = UnitInSpellsRange(unit, 'resurrect')
        if not NRSKNUI:IsSecretValue(inRange) then
            inRange = inRange == true
        end
        -- Enemy units, check for an enemy spell in range.
    elseif UnitCanAttack('player', unit) then
        inRange = UnitInSpellsRange(unit, 'enemy')
    else
        -- Friendly units, check for a friendly spell in range, then fall back to CheckInteractDistance if out of combat.
        local isPet = UnitIsUnit(unit, 'pet')
        if not NRSKNUI:IsSecretValue(isPet) and isPet then
            inRange = UnitInSpellsRange(unit, 'pet')
        elseif UnitIsConnected(unit) then
            inRange = FriendlyRangeCheck(unit, frame)
        else
            inRange = false
        end
    end

    -- Route any secret result through the secret-safe setter.
    if NRSKNUI:IsSecretValue(frame.RangeIsInRange) then
        frame:SetAlphaFromBoolean(frame.RangeIsInRange, inAlpha, outAlpha)
        return
    elseif NRSKNUI:IsSecretValue(inRange) then
        frame:SetAlphaFromBoolean(inRange, inAlpha, outAlpha)
        return
    end

    -- Normal alpha setting for a non-secret result.
    frame:SetAlpha(inRange and inAlpha or outAlpha)
end

-- Frame registry keyed by unit, one shared ticker fades them all.
UF.RangeFrames = UF.RangeFrames or {}

local function UpdateAllRangeFrames()
    for unit, frames in pairs(UF.RangeFrames) do
        for frame in pairs(frames) do
            if frame:IsVisible() then UF.UpdateRangeAlpha(frame, unit) end
        end
    end
end

local function UpdateRangeUnit(unit)
    local frames = UF.RangeFrames[unit]
    if not frames then return end
    for frame in pairs(frames) do UF.UpdateRangeAlpha(frame, unit) end
end

-- AceEvent method handlers
function UF:SPELLS_CHANGED()
    self:UpdateActiveRangeSpells()
    UpdateAllRangeFrames()
end

function UF:PLAYER_TARGET_CHANGED()
    UpdateRangeUnit('target')
    UpdateRangeUnit('targettarget')
end

function UF:PLAYER_FOCUS_CHANGED()
    UpdateRangeUnit('focus')
    UpdateRangeUnit('focustarget')
end

function UF:UNIT_TARGET(_, unit)
    UpdateRangeUnit(unit .. 'target')
end

-- Shared by UNIT_IN_RANGE_UPDATE and UNIT_CONNECTION (both carry a unit arg).
function UF:RangeUnitEvent(_, unit)
    UpdateRangeUnit(unit)
end

-- Register or unregister the range events based on whether any frames are registered.
local function SetRangeEventsRegistered(enabled)
    if enabled then
        UF:UpdateActiveRangeSpells()
        UF:RegisterEvent('SPELLS_CHANGED')
        UF:RegisterEvent('PLAYER_TARGET_CHANGED')
        UF:RegisterEvent('PLAYER_FOCUS_CHANGED')
        UF:RegisterEvent('UNIT_TARGET')
        UF:RegisterEvent('UNIT_IN_RANGE_UPDATE', 'RangeUnitEvent')
        UF:RegisterEvent('UNIT_CONNECTION', 'RangeUnitEvent')
    else
        UF:UnregisterEvent('SPELLS_CHANGED')
        UF:UnregisterEvent('PLAYER_TARGET_CHANGED')
        UF:UnregisterEvent('PLAYER_FOCUS_CHANGED')
        UF:UnregisterEvent('UNIT_TARGET')
        UF:UnregisterEvent('UNIT_IN_RANGE_UPDATE')
        UF:UnregisterEvent('UNIT_CONNECTION')
    end
end

-- Ticker + reactive events only run while at least one frame is registered.
local rangeTicker
local function UpdateRangeTicker()
    local shouldRun = next(UF.RangeFrames) ~= nil
    if shouldRun and not rangeTicker then
        SetRangeEventsRegistered(true)
        rangeTicker = C_Timer.NewTicker(0.2, UpdateAllRangeFrames)
    elseif not shouldRun and rangeTicker then
        rangeTicker:Cancel()
        rangeTicker = nil
        SetRangeEventsRegistered(false)
    end
end

---Register a frame for range fading under a unit.
---@param frame oUF.UnitFrame
---@param unit string
function UF:RegisterRangeFrame(frame, unit)
    if not frame or not unit then return end

    local previous = frame.nuiRangeUnit
    if previous and previous ~= unit then
        local prevFrames = UF.RangeFrames[previous]
        if prevFrames then
            prevFrames[frame] = nil
            if not next(prevFrames) then UF.RangeFrames[previous] = nil end
        end
    end

    local frames = UF.RangeFrames[unit]
    if not frames then
        frames = {}
        UF.RangeFrames[unit] = frames
    end
    frames[frame] = true
    frame.nuiRangeUnit = unit

    UpdateRangeTicker()
    UF.UpdateRangeAlpha(frame, unit)
end

---Unregister a frame from range fading and restore full opacity.
---@param frame oUF.UnitFrame
function UF:UnregisterRangeFrame(frame)
    if not frame or not frame.nuiRangeUnit then return end
    local frames = UF.RangeFrames[frame.nuiRangeUnit]
    if frames then
        frames[frame] = nil
        if not next(frames) then
            UF.RangeFrames[frame.nuiRangeUnit] = nil
        end
    end
    frame.nuiRangeUnit = nil
    frame:SetAlpha(1)
    UpdateRangeTicker()
end

---Post-update function for health and power elements to set the color based on class or custom color.
---@param element oUF.Health
---@param unit string
function UF.PostUpdateHealthColor(element, unit)
    local fg = element.nuiForeground
    if not fg then return end

    local status = NRSKNUI.Colors.status

    -- oUF fills the bar to max for Offline units, so recolor the whole foreground and skip the hue logic.
    if not UnitIsConnected(unit) then
        local off = status.Disconnected
        element:SetStatusBarColor(off[1], off[2], off[3], off[4])
        return
    end

    -- Tapped mobs get the muted tapped tint.
    if UnitIsTapDenied(unit) then
        local tap = status.Tapped
        element:SetStatusBarColor(tap[1], tap[2], tap[3], tap[4] or fg[4])
        return
    end

    if element.nuiColorByClass then
        local r, g, b = element:GetStatusBarColor()
        local alpha = element.ForegroundAlphaWhenColorByClass or fg[4]
        element:SetStatusBarColor(r, g, b, alpha)
    else
        element:SetStatusBarColor(fg[1], fg[2], fg[3], fg[4])
    end
end

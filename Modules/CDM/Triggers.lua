---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local pairs = pairs
local next = next
local CreateFrame = CreateFrame
local GetSpellCooldown = C_Spell.GetSpellCooldown
local GetSpellCharges = C_Spell.GetSpellCharges
local GetSpellCooldownDuration = C_Spell.GetSpellCooldownDuration
local GetSpellChargeDuration = C_Spell.GetSpellChargeDuration
local GetSpellDisplayCount = C_Spell.GetSpellDisplayCount
local GetSpellTexture = C_Spell.GetSpellTexture
local GetOverrideSpell = C_Spell.GetOverrideSpell
local IsSpellKnown = C_SpellBook.IsSpellKnown

local spellIndex = {} ---@type table<number, table<string, true>> spellID -> icon ids watching it

---@param spellID number?
---@param id string
local function Index(spellID, id)
    if not spellID then return end
    local watchers = spellIndex[spellID]
    if not watchers then
        watchers = {}
        spellIndex[spellID] = watchers
    end
    watchers[id] = true
end

---@param id string
function CDM:UnwatchIcon(id)
    for spellID, watchers in pairs(spellIndex) do
        watchers[id] = nil
        if not next(watchers) then spellIndex[spellID] = nil end
    end
end

-- Trigger types. Resolve runs on build and on spell changes, Update on every relevant event.
CDM.TriggerTypes = {
    spell = {
        ---@param trigger table
        ---@return boolean
        IsKnown = function(trigger)
            local base = trigger.SpellID
            return IsSpellKnown(base) or IsSpellKnown(GetOverrideSpell(base) or base)
        end,

        ---@param frame CDMIcon
        ---@param trigger table
        Resolve = function(frame, trigger)
            local base = trigger.SpellID
            frame.baseSpellID = base
            frame.spellID = GetOverrideSpell(base) or base
            Index(base, frame.id)
            Index(frame.spellID, frame.id)
            frame.Icon:SetTexture(GetSpellTexture(frame.spellID))
        end,

        -- Only isActive/isOnGCD/isEnabled/maxCharges are documented NeverSecret; every timing value
        -- reaches the widgets inside duration objects.
        ---@param frame CDMIcon
        ---@param style table
        Update = function(frame, style)
            local spellID = frame.spellID
            local state = frame.state
            local cooldown = GetSpellCooldown(spellID)
            local charges = GetSpellCharges(spellID)

            state.hasCharges = charges ~= nil and charges.maxCharges > 1
            state.onGCD = cooldown ~= nil and cooldown.isOnGCD == true
            state.onCooldown = cooldown ~= nil and cooldown.isActive and not state.onGCD
            state.recharging = state.hasCharges and charges.isActive

            local duration
            if state.hasCharges and not state.onCooldown then
                duration = GetSpellChargeDuration(spellID)
            else
                duration = GetSpellCooldownDuration(spellID, not style.ShowGCD)
            end
            if duration then
                frame.Cooldown:SetCooldownFromDurationObject(duration)
            else
                frame.Cooldown:Clear() -- previewing a spell this character doesn't have
            end
            frame.Charges:SetText(state.hasCharges and GetSpellDisplayCount(spellID) or '')
            frame.Icon:SetDesaturated(style.DesaturateOnCooldown and state.onCooldown)
        end,
    },
}

---Resolve an icon's trigger and start watching what it needs.
---@param frame CDMIcon
---@param trigger table
function CDM:ResolveTrigger(frame, trigger)
    self:UnwatchIcon(frame.id)
    local triggerType = self.TriggerTypes[trigger.Type]
    if triggerType then triggerType.Resolve(frame, trigger) end
end

---@param id string
function CDM:UpdateIcon(id)
    local frame = self.icons[id]
    local display = self:Get(id)
    if not (frame and display and frame.shown) then return end

    self.TriggerTypes[display.Trigger.Type].Update(frame, frame.style)
end

---@param spellID number?
local function UpdateWatchers(spellID)
    local watchers = spellID and spellIndex[spellID]
    if not watchers then return end
    for id in pairs(watchers) do CDM:UpdateIcon(id) end
end

local function UpdateAll()
    for id in pairs(CDM.icons) do CDM:UpdateIcon(id) end
end

-- isOnGCD is only trustworthy inside the SPELL_UPDATE_COOLDOWN handler (SpellSharedDocumentation.lua, live),
-- so cooldown updates run in the handler rather than being coalesced to the next frame.
local handlers = {
    SPELL_UPDATE_COOLDOWN = function(spellID, baseSpellID)
        if not spellID then return UpdateAll() end
        UpdateWatchers(spellID)
        if baseSpellID ~= spellID then UpdateWatchers(baseSpellID) end
    end,
    SPELL_UPDATE_CHARGES = UpdateAll,
    SPELL_UPDATE_ICON = function() CDM:ResolveAll() end,
    COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED = function() CDM:ResolveAll() end,
    SPELLS_CHANGED = function() CDM:ResolveAll() end,
}

local eventFrame = CreateFrame('Frame')
eventFrame:SetScript('OnEvent', function(_, event, ...) handlers[event](...) end)

function CDM:RegisterTriggerEvents()
    for event in pairs(handlers) do eventFrame:RegisterEvent(event) end
end

function CDM:UnregisterTriggerEvents()
    eventFrame:UnregisterAllEvents()
end

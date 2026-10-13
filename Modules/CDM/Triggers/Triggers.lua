---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

local pairs, ipairs = pairs, ipairs
local next = next
local tonumber = tonumber
local format = string.format
local CreateFrame = CreateFrame
local GetSpellTexture = C_Spell.GetSpellTexture
local GetSpellName = C_Spell.GetSpellName
local CreateDuration = C_DurationUtil.CreateDuration
local GetTime = GetTime

-- One file per type in Triggers/: Resolve on build, Update per event, IsActive picks the shown layer; the rest are optional hooks.
CDM.TriggerTypes = {}

CDM.PREVIEW_LENGTH = 7     -- WeakAuras' options preview: anything not already running gets a 7s timer
CDM.PREVIEW_PANDEMIC = 0.3 -- most auras' refresh window: the last 30% carries over

---@param layer CDMLayer
---@return boolean
function CDM.IsPreviewingLayer(layer)
    return CDM.previewing == true and layer.owner.shown == true
end

---A looping fake timer for the options preview; OnCooldownDone re-arms it through UpdateIcon.
---@param layer CDMLayer
---@param length number
---@return LuaDurationObject
function CDM.PreviewDuration(layer, length)
    local now = GetTime()
    if not layer.previewEnd or now >= layer.previewEnd - 0.05 then layer.previewEnd = now + length end
    layer.previewDuration = layer.previewDuration or CreateDuration()
    layer.previewDuration:SetTimeFromStart(layer.previewEnd - length, length)
    return layer.previewDuration
end

local spellIndex = {} ---@type table<number, table<string, true>> spellID -> icon ids watching it

---Update `id` whenever `spellID` changes.
---@param spellID number?
---@param id string
function CDM:WatchSpell(spellID, id)
    if not spellID then return end
    local watchers = spellIndex[spellID]
    if not watchers then
        watchers = {}
        spellIndex[spellID] = watchers
    end
    watchers[id] = true
end

---@param spellID number?
function CDM:UpdateWatchers(spellID)
    local watchers = spellID and spellIndex[spellID]
    if not watchers then return end
    for id in pairs(watchers) do self:UpdateIcon(id) end
end

function CDM:UpdateAll()
    for id in pairs(self.icons) do self:UpdateIcon(id) end
end

---@param id string
function CDM:UnwatchIcon(id)
    for _, triggerType in pairs(self.TriggerTypes) do
        if triggerType.Unwatch then triggerType.Unwatch(id) end
    end
    for spellID, watchers in pairs(spellIndex) do
        watchers[id] = nil
        if not next(watchers) then spellIndex[spellID] = nil end
    end
end

---The spell a trigger stands for; a custom aura goes by its own first ID, not one left from a Cooldown Manager pick.
---@param trigger table
---@return number?
function CDM:GetTriggerSpell(trigger)
    if (trigger.Type == 'aura' or trigger.Type == 'auraoverlay') and trigger.Source == 'custom' then return trigger.SpellIDs and trigger.SpellIDs[1] end
    return trigger.SpellID or (trigger.SpellIDs and trigger.SpellIDs[1])
end

---@param trigger table
---@return number? texture
function CDM:GetTriggerTexture(trigger)
    local triggerType = self.TriggerTypes[trigger.Type]
    if triggerType and triggerType.Texture then return triggerType.Texture(trigger) end
    local spellID = self:GetTriggerSpell(trigger)
    return spellID and GetSpellTexture(spellID)
end

---@param trigger table
---@return string? name
function CDM:GetTriggerName(trigger)
    local triggerType = self.TriggerTypes[trigger.Type]
    if triggerType and triggerType.Name then return triggerType.Name(trigger) end
    local spellID = self:GetTriggerSpell(trigger)
    return spellID and GetSpellName(spellID)
end

---@param warnings string[]
---@param i number the trigger
---@param spellID number
function CDM:WarnUnknownSpell(warnings, i, spellID)
    if not GetSpellName(spellID) then warnings[#warnings + 1] = format(L['Trigger %d: spell ID %d does not exist.'], i, spellID) end
end

---Problems found from the settings alone, for the Information tab.
---@param id string
---@return string[]
function CDM:GetWarnings(id)
    local display = self:Get(id)
    local warnings = {}
    if not display then return warnings end

    if self:IsGroup(id) then
        if #self:GetChildren(id) == 0 then warnings[1] = L['This group is empty.'] end
        return warnings
    end

    local triggers = display.Triggers or {}
    for i, trigger in ipairs(triggers) do
        local triggerType = self.TriggerTypes[trigger.Type]
        if triggerType and triggerType.Warnings then triggerType.Warnings(i, trigger, warnings) end
    end

    local textIndex = 0
    for _, element in ipairs(display.SubRegions or {}) do
        if element.type == 'text' then
            textIndex = textIndex + 1
            for source in (element.Text or ''):gmatch('%%(%d+)%.[pts]') do
                local n = tonumber(source)
                if not triggers[n] then warnings[#warnings + 1] = format(L['Text %d reads trigger %d, which does not exist.'], textIndex, n) end
            end
        end
    end
    return warnings
end

---Resolve every trigger of an icon and start watching what they need.
---@param frame CDMIcon
---@param display table
function CDM:ResolveTriggers(frame, display)
    self:UnwatchIcon(frame.id)
    for i, trigger in ipairs(display.Triggers) do
        local layer = frame.layers[i]
        local triggerType = self.TriggerTypes[trigger.Type]
        local secret = triggerType ~= nil and triggerType.Secret == true
        layer.Icon:SetShown(not secret and not layer.isText and not (layer.isBar and not frame.style.IconShow))
        if layer.isBar then layer.Bar:SetShown(not secret) end -- an aura bar draws inside its aura button
        layer.Cooldown:SetShown(not secret)
        layer.textHost:SetShown(not secret)
        layer.borderHost:SetShown(not secret)
        if not secret then self:ReleaseAuraLayer(layer) end
        if triggerType then triggerType.Resolve(layer, trigger) end
    end
end

---Re-resolve only the spell and timer triggers built on `baseSpellID`, all of them when nil; an override never changes what loads.
---@param baseSpellID number?
function CDM:ResolveOverrides(baseSpellID)
    local ids = baseSpellID and spellIndex[baseSpellID] or self.icons
    for id in pairs(ids) do
        local frame, display = self.icons[id], self:Get(id)
        if frame and display then
            local changed = false
            for i, trigger in ipairs(display.Triggers) do
                if (trigger.Type == 'spell' or trigger.Type == 'timer') and (not baseSpellID or trigger.SpellID == baseSpellID) then
                    local layer = frame.layers[i]
                    local before = layer.spellID
                    self.TriggerTypes[trigger.Type].Resolve(layer, trigger)
                    changed = changed or layer.spellID ~= before
                end
            end
            if changed then self:UpdateIcon(id) end
        end
    end
end

---WeakAuras' trigger combination: Any or All triggers activate the icon, and it shows the first active
---trigger's layer or the one Dynamic Information pins. An aura layer shows itself while its aura is up, so
---aura triggers can't count toward All; an overlay stays over whichever layer shows.
---@param frame CDMIcon
---@param display table
function CDM:SelectLayer(frame, display)
    local triggers = display.Triggers
    local requireAll = display.Activation == 'all' and not self.previewing -- WeakAuras ignores the combination while editing
    local first, blocked, standby = nil, false, nil
    for i, trigger in ipairs(triggers) do
        local triggerType = self.TriggerTypes[trigger.Type]
        if not (triggerType and triggerType.Secret) then
            if triggerType and triggerType.IsActive(frame.layers[i], trigger) then
                first = first or i
            else
                if requireAll then blocked = true end
                if not standby and triggerType and triggerType.IsStandby and triggerType.IsStandby(frame.layers[i], trigger) then standby = i end
            end
        end
    end
    if blocked then first = nil end
    -- Hidden but ready to show: a condition's Show Display brings it up when nothing else is active.
    frame.standbyLayer = not blocked and standby and frame.layers[standby] or nil

    local pin = display.DynamicTrigger
    local pinType = pin and triggers[pin] and self.TriggerTypes[triggers[pin].Type]
    if not pinType then pin = nil end
    local pinSecret = pinType and pinType.Secret == true
    local pinned = pin ~= nil and (first ~= nil or pinSecret)

    local maybeAura, placeholder = false, false
    for i, trigger in ipairs(triggers) do
        local triggerType = self.TriggerTypes[trigger.Type]
        local secret = triggerType ~= nil and triggerType.Secret == true
        local show
        if blocked then
            show = false
        elseif trigger.Type == 'auraoverlay' then
            show = true
        elseif pinned then
            show = i == pin
        elseif secret then
            show = first == nil or i < first -- above whatever is active below
        else
            show = i == first
        end
        if secret and show then maybeAura = true end
        if secret and show and trigger.Placeholder and trigger.Type == 'aura' then placeholder = true end
        frame.layers[i]:SetShown(show)
    end
    frame.placeholder = placeholder

    if pinned then
        frame.activeLayer = not pinSecret and frame.layers[pin] or nil
    else
        frame.activeLayer = first and frame.layers[first] or nil
    end
    frame.hasActive = frame.activeLayer ~= nil or maybeAura
end

---An icon shows while it's loaded and a trigger is active, as in WeakAuras; in a dynamic group a hidden
---one frees its slot. Previewed icons show regardless, so the options page can edit them.
---@param id string
---@param frame CDMIcon
function CDM:ApplyVisibility(id, frame)
    local visible = frame.shown and (self.previewing or (frame.hasActive and not frame.forceHidden)) or false
    local group = frame.groupId and self.containers[frame.groupId]
    if group and group.isChain then
        ---@cast group CDMChainGroup
        local logic = frame.activeLayer ~= nil or frame.placeholder -- a placeholder keeps its slot open while the aura is missing
        group:SetChildVisible(id, frame.shown == true, frame.shown == true and (self.previewing or (logic and not frame.forceHidden)))
        return
    end
    ---@cast group NRSKNUI.DynamicGroup?
    if group then
        if visible then group:ActivateChild(id) else group:DeactivateChild(id) end
    else
        frame:SetShown(visible)
    end
end

---@param id string
function CDM:UpdateIcon(id)
    local frame = self.icons[id]
    local display = self:Get(id)
    if not (frame and display and frame.shown) then return end

    for i, trigger in ipairs(display.Triggers) do
        local triggerType = self.TriggerTypes[trigger.Type]
        if triggerType then triggerType.Update(frame.layers[i], frame.style, trigger) end
        -- Conditions put their own over it after; an aura layer's icon is only its preview or placeholder, set by Update.
        if not (triggerType and triggerType.Secret) then frame.layers[i].Icon:SetDesaturated(frame.style.Desaturate == true) end
    end
    -- A %N.p text reads a trigger that may have updated after its own.
    for i = 1, #display.Triggers do
        local layer = frame.layers[i]
        if layer.sourced or layer.auraSourced then self:UpdateTexts(layer) end
    end
    self:SelectLayer(frame, display)
    self:EvaluateConditions(id, frame, display)
    self:ApplyVisibility(id, frame)
end

local resolveAllFrame = CreateFrame('Frame')
resolveAllFrame:NUISetScheduledUpdate(function() CDM:ResolveAll() end)

local function UpdateAll() CDM:UpdateAll() end

-- What every trigger reacts to; each trigger type registers its own events besides.
local handlers = {
    SPELL_UPDATE_CHARGES = UpdateAll,
    SPELL_UPDATE_USES = UpdateAll,
    SPELL_UPDATE_USABLE = UpdateAll,
    PLAYER_REGEN_DISABLED = function()
        CDM.inCombat = true
        UpdateAll()
    end,
    PLAYER_REGEN_ENABLED = function()
        CDM.inCombat = false
        UpdateAll()
    end,
    PLAYER_TARGET_CHANGED = UpdateAll,
    GROUP_ROSTER_UPDATE = UpdateAll,
    SPELL_UPDATE_ICON = function(spellID) CDM:ResolveOverrides(spellID) end,
    COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED = function(baseSpellID) CDM:ResolveOverrides(baseSpellID) end,
    SPELLS_CHANGED = function() resolveAllFrame:NUIScheduleUpdate() end,
}

local eventFrame = CreateFrame('Frame')
eventFrame:SetScript('OnEvent', function(_, event, ...) handlers[event](...) end)

function CDM:RegisterTriggerEvents()
    self.inCombat = InCombatLockdown() -- a reload mid-fight misses the REGEN_DISABLED edge
    for event in pairs(handlers) do eventFrame:RegisterEvent(event) end
    for _, triggerType in pairs(self.TriggerTypes) do
        if triggerType.RegisterEvents then triggerType.RegisterEvents() end
    end
end

function CDM:UnregisterTriggerEvents()
    eventFrame:UnregisterAllEvents()
    for _, triggerType in pairs(self.TriggerTypes) do
        if triggerType.UnregisterEvents then triggerType.UnregisterEvents() end
    end
end

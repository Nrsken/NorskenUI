---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

--[[
The pipeline every trigger type shares: Resolve what a trigger points at, Update its layer from the game, Derive which layer shows.
Each Triggers/*.lua fills CDM.TriggerTypes[type] with IsKnown, Resolve, Update and IsActive, plus optional IsStandby, Warnings, Unwatch and RegisterEvents.
]]

CDM.TriggerTypes = {}
CDM.PREVIEW_LENGTH = 7     -- options preview timer, in seconds
CDM.PREVIEW_PANDEMIC = 0.3 -- previewed pandemic border at 30% left

local InCombatLockdown = InCombatLockdown
local pairs, ipairs = pairs, ipairs
local CreateFrame = CreateFrame
local format = string.format
local tonumber = tonumber
local GetTime = GetTime
local next = next

local CreateDuration = C_DurationUtil and C_DurationUtil.CreateDuration
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture
local GetSpellName = C_Spell and C_Spell.GetSpellName

-- Preview --

---@param layer CDMLayer
---@return boolean
function CDM.IsPreviewingLayer(layer)
    return CDM.previewing == true and layer.owner.shown == true
end

---A looping fake timer for the options preview.
---@param layer CDMLayer
---@param length number
---@return LuaDurationObject
function CDM.PreviewDuration(layer, length)
    local now = GetTime()
    if not layer.previewEnd or now >= layer.previewEnd - 0.05 then
        layer.previewEnd = now + length
    end

    layer.previewDuration = layer.previewDuration or CreateDuration()
    layer.previewDuration:SetTimeFromStart(layer.previewEnd - length, length)
    return layer.previewDuration
end

-- Watchers --

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

local SPELL_TYPES = { spell = true }
CDM.SPELL_TYPES = SPELL_TYPES -- items aren't in it: BAG_UPDATE_COOLDOWN covers bags and equipped slots

---Re-read only the spell triggers on `spellID`, in the icons watching it.
---@param spellID number?
function CDM:UpdateWatchers(spellID)
    local watchers = spellID and spellIndex[spellID]
    if not watchers then return end

    for id in pairs(watchers) do
        self:UpdateTriggers(id, SPELL_TYPES, spellID)
    end
end

---@param types table<string, true>
function CDM:UpdateAllTriggers(types)
    for id in pairs(self.icons) do
        self:UpdateTriggers(id, types)
    end
end

---Whirling Dragon Punch's usability flips on other spells' cooldowns and no event names it.
function CDM:RefreshUsable()
    for id, frame in pairs(self.icons) do
        local display = frame.shown and self:Get(id)
        if display then
            local changed = false
            for i, trigger in ipairs(display.Triggers) do
                local layer = frame.layers[i]
                local triggerType = layer.watchUsable and self.TriggerTypes[trigger.Type]
                if triggerType and triggerType.RefreshUsable and triggerType.RefreshUsable(layer) then
                    changed = true
                end
            end

            if changed then
                self:Derive(id, frame, display)
            end
        end
    end
end

---Re-derive only the icons whose conditions read a global (0) or player/unit (-1) check.
---@param triggerIndex number
---@param variable string
---@param other string?
function CDM:DeriveUsing(triggerIndex, variable, other)
    for id in pairs(self.icons) do
        local display = self:Get(id)
        if display and (self:ConditionsUse(display, triggerIndex, variable) or (other and self:ConditionsUse(display, triggerIndex, other))) then
            self:Derive(id)
        end
    end
end

---Before a re-resolve or when the pooled frame moves to another display.
---@param id string
function CDM:UnwatchIcon(id)
    for _, triggerType in pairs(self.TriggerTypes) do
        if triggerType.Unwatch then
            triggerType.Unwatch(id)
        end
    end

    for spellID, watchers in pairs(spellIndex) do
        watchers[id] = nil
        if not next(watchers) then
            spellIndex[spellID] = nil
        end
    end
end

-- Trigger info --

---A custom aura goes by its own first ID, not one left from a Cooldown Manager pick.
---@param trigger table
---@return number?
function CDM:GetTriggerSpell(trigger)
    if trigger.Type == 'aura' or trigger.Type == 'auraoverlay' then
        if trigger.Source == 'custom' then
            return trigger.SpellIDs and trigger.SpellIDs[1]
        end

        local info = trigger.CooldownID and self.Catalogue:GetEntry(trigger.CooldownID)
        if info then
            return self.Catalogue:DisplaySpell(info)
        end
    end

    return trigger.SpellID or (trigger.SpellIDs and trigger.SpellIDs[1])
end

---@param trigger table
---@return number? texture
function CDM:GetTriggerTexture(trigger)
    local triggerType = self.TriggerTypes[trigger.Type]
    if triggerType and triggerType.Texture then
        return triggerType.Texture(trigger)
    end

    local spellID = self:GetTriggerSpell(trigger)
    return spellID and GetSpellTexture(spellID)
end

---@param trigger table
---@return string? name
function CDM:GetTriggerName(trigger)
    local triggerType = self.TriggerTypes[trigger.Type]
    if triggerType and triggerType.Name then
        return triggerType.Name(trigger)
    end

    local spellID = self:GetTriggerSpell(trigger)
    return spellID and GetSpellName(spellID)
end

---@param warnings string[]
---@param i number the trigger
---@param spellID number
function CDM:WarnUnknownSpell(warnings, i, spellID)
    if not GetSpellName(spellID) then
        warnings[#warnings + 1] = format(L['Trigger %d: spell ID %d does not exist.'], i, spellID)
    end
end

---Problems found from the settings alone, for the Information tab.
---@param id string
---@return string[]
function CDM:GetWarnings(id)
    local display = self:Get(id)
    local warnings = {}
    if not display then
        return warnings
    end

    if self:IsGroup(id) then
        if #self:GetChildren(id) == 0 then
            warnings[1] = L['This group is empty.']
        end
        return warnings
    end

    local triggers = display.Triggers or {}
    for i, trigger in ipairs(triggers) do
        local triggerType = self.TriggerTypes[trigger.Type]
        if triggerType and triggerType.Warnings then
            triggerType.Warnings(i, trigger, warnings)
        end
    end

    local dropped = self:DroppedAuraTexts(display)
    local textIndex = 0
    for _, element in ipairs(display.SubRegions or {}) do
        if element.type == 'text' then
            textIndex = textIndex + 1
            for source in (element.Text or ''):gmatch('%%(%d+)%.[ptsn]') do
                local n = tonumber(source)
                if not triggers[n] then
                    warnings[#warnings + 1] = format(L['Text %d reads trigger %d, which does not exist.'], textIndex, n)
                end
            end
            if dropped[element] then
                warnings[#warnings + 1] = format(L["Text %d stays empty: an earlier text already shows the aura's timer or stacks."], textIndex)
            end
        end
    end

    return warnings
end

-- Resolve --

---@param frame CDMIcon
---@param display table
function CDM:ResolveTriggers(frame, display)
    self:UnwatchIcon(frame.id)

    for i, trigger in ipairs(display.Triggers) do
        local layer = frame.layers[i]
        local triggerType = self.TriggerTypes[trigger.Type]
        local secret = triggerType ~= nil and triggerType.Secret == true

        -- An aura layer is drawn by its aura button, so its own parts hide.
        layer.Icon:SetShown(not secret and self:ShowsIcon(layer, frame.style, display))
        if layer.isBar then
            layer.Bar:SetShown(not secret)
        end
        layer.Cooldown:SetShown(not secret)
        layer.textHost:SetShown(not secret)
        layer.borderHost:SetShown(not secret)
        if not secret then
            self:ReleaseAuraLayer(layer)
        end

        layer.count = nil -- one left by another trigger type would stand in for this one's %s
        if triggerType then
            triggerType.Resolve(layer, trigger)
        end
    end
end

---Spell and timer triggers on `baseSpellID`, all when nil; an override never changes what loads.
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
                    local before, wasOverridden = layer.spellID, layer.overridden
                    self.TriggerTypes[trigger.Type].Resolve(layer, trigger)
                    -- an Ignore Override icon keeps its spell, but its Overridden condition still flips
                    changed = changed or layer.spellID ~= before or layer.overridden ~= wasOverridden
                end
            end

            if changed then
                self:UpdateIcon(id)
            end
        end
    end
end

---Re-read every spell and timer icon: a talent can swap one without an override (Empty Barrel on Keg Smash); only SPELLS_CHANGED says so.
function CDM:RefreshSpellTextures()
    for id, frame in pairs(self.icons) do
        local display = self:Get(id)
        for i, trigger in ipairs(display and display.Triggers or {}) do
            local layer = frame.layers[i]
            if layer and layer.spellID and (trigger.Type == 'spell' or trigger.Type == 'timer') then
                local icon, original = GetSpellTexture(layer.spellID)
                -- an Ignore Override spell trigger keeps the base spell's own icon, as its Resolve does
                self:SetIconTexture(layer, trigger.Type == 'spell' and trigger.IgnoreOverride and original or icon)
            end
        end
    end
end

-- Visibility --

---Any/All activation in the WA style: the first active trigger's layer shows, unless Dynamic Information pins one.
---@param frame CDMIcon
---@param display table
function CDM:SelectLayer(frame, display)
    local triggers = display.Triggers
    local requireAll = display.Activation == 'all' and not self.previewing -- ignored while editing since one inactive trigger would blank the preview
    local first, blocked, standby = nil, false, nil

    -- First active trigger; with All, any inactive one blocks.
    for i, trigger in ipairs(triggers) do
        local triggerType = self.TriggerTypes[trigger.Type]
        if not (triggerType and triggerType.Secret) then
            if triggerType and triggerType.IsActive(frame.layers[i], trigger) then
                first = first or i
            else
                if requireAll then
                    blocked = true
                end
                if not standby and triggerType and triggerType.IsStandby and triggerType.IsStandby(frame.layers[i], trigger) then
                    standby = i
                end
            end
        end
    end

    if blocked then
        first = nil
    end

    -- Hidden but ready: a condition's Show Display can bring it up.
    frame.standbyLayer = not blocked and standby and frame.layers[standby] or nil

    local pin = display.DynamicTrigger
    local pinType = pin and triggers[pin] and self.TriggerTypes[triggers[pin].Type]
    if not pinType then
        pin = nil
    end
    local pinSecret = pinType and pinType.Secret == true
    local pinned = pin ~= nil and (first ~= nil or pinSecret) -- a pin needs something active and an aura might be

    -- Show the chosen layer.
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
            show = first == nil or i < first -- unreadable, so it covers the active layer while up
        else
            show = i == first
        end

        if secret and show then
            maybeAura = true -- its aura may be up, so keep the icon visible
        end
        if secret and show and trigger.Placeholder and trigger.Type == 'aura' then
            placeholder = true
        end
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

---Shown while loaded and active or always while previewed; in a dynamic group a hidden icon frees its slot.
---@param id string
---@param frame CDMIcon
function CDM:ApplyVisibility(id, frame)
    local visible = frame.shown and (self.previewing or (frame.hasActive and not frame.forceHidden)) or false
    local group = frame.groupId and self.containers[frame.groupId]

    if group and group.isChain then
        ---@cast group CDMChainGroup
        local loaded = frame.shown == true and (self.previewing or not frame.forceHidden) -- Show Display off must hide the aura too, not only free the slot
        local logic = frame.activeLayer ~= nil or frame.placeholder                       -- a placeholder keeps its slot open while the aura is missing
        group:SetChildVisible(id, loaded, self.previewing or logic)
        return
    end

    ---@cast group NRSKNUI.DynamicGroup?
    if group then
        if visible then
            group:ActivateChild(id)
        else
            group:DeactivateChild(id)
        end
    else
        frame:SetShown(visible)
    end
end

-- Update --

---@param frame CDMIcon
---@param trigger table
---@param i number
local function RunTrigger(frame, trigger, i)
    local triggerType = CDM.TriggerTypes[trigger.Type]
    if triggerType then
        triggerType.Update(frame.layers[i], frame.style, trigger)
    end

    -- Conditions override this after; an aura layer's icon is set by its Update.
    if not (triggerType and triggerType.Secret) then
        frame.layers[i].Icon:SetDesaturated(frame.style.Desaturate == true)
    end
end

---@param id string
---@param frame CDMIcon
---@param display table
local function Settle(id, frame, display)
    -- A %N.p text reads a trigger that may have updated after its own.
    for i = 1, #display.Triggers do
        local layer = frame.layers[i]
        if layer.sourced or layer.auraSourced then
            CDM:UpdateTexts(layer)
        end
    end

    CDM:Derive(id, frame, display)
end

---Only shown icons update; a hidden one catches up when RefreshLoad shows it again.
---@param id string
---@return CDMIcon? frame, table? display
local function Live(id)
    local frame, display = CDM.icons[id], CDM:Get(id)
    if frame and display and frame.shown then
        return frame, display
    end
end

---Every trigger re-read, for builds and settings; combat events use the narrower ones below.
---@param id string
function CDM:UpdateIcon(id)
    local frame, display = Live(id)
    if not frame then return end

    ---@cast display table
    for i, trigger in ipairs(display.Triggers) do
        RunTrigger(frame, trigger, i)
    end

    Settle(id, frame, display)
end

---Re-read the triggers of these types, only those on `spellID` when given.
---@param id string
---@param types table<string, true>
---@param spellID number?
function CDM:UpdateTriggers(id, types, spellID)
    local frame, display = Live(id)
    if not frame then return end

    ---@cast display table
    local ran = false
    for i, trigger in ipairs(display.Triggers) do
        local layer = frame.layers[i]
        if types[trigger.Type] and (not spellID or layer.spellID == spellID or layer.baseSpellID == spellID) then
            RunTrigger(frame, trigger, i)
            ran = true
        end
    end

    if ran then
        Settle(id, frame, display)
    end
end

---Re-read the one trigger behind `layer`, for its own timers and events.
---@param layer CDMLayer
function CDM:UpdateLayer(layer)
    local id = layer.owner.id
    if not id then return end
    local frame, display = Live(id)
    if not frame then return end
    ---@cast display table
    local trigger = display.Triggers[layer.index]
    if not trigger then return end

    RunTrigger(frame, trigger, layer.index)
    Settle(id, frame, display)
end

---Pick the shown layer and re-run conditions and visibility, reading no trigger.
---@param id string
---@param frame CDMIcon?
---@param display table?
function CDM:Derive(id, frame, display)
    if not frame then
        frame, display = Live(id)
    end
    if not frame then return end

    ---@cast display table
    self:SelectLayer(frame, display)
    self:EvaluateConditions(id, frame, display)
    self:ApplyVisibility(id, frame)
end

-- Events --

local eventFrame, resolveAllFrame, loadCheckFrame ---@type Frame, Frame, Frame
local resolvePending = false

local function ResolveAllScheduled()
    CDM:ResolveAll()
end

local function CheckLoadScheduled()
    if CDM:KnownChanged() then
        CDM:RefreshLoad(true)
    end
end

-- What every trigger reacts to; each trigger type registers its own events besides.
local handlers = {
    SPELL_UPDATE_CHARGES = function()
        CDM:UpdateAllTriggers(SPELL_TYPES) -- no payload, so every spell trigger re-reads
    end,
    SPELL_UPDATE_USES = function(spellID, baseSpellID)
        CDM:UpdateWatchers(spellID)
        if baseSpellID ~= spellID then
            CDM:UpdateWatchers(baseSpellID)
        end
    end,
    SPELL_UPDATE_USABLE = function()
        CDM:RefreshUsable()
    end,
    PLAYER_REGEN_DISABLED = function()
        CDM.inCombat = true
        CDM:DeriveUsing(0, 'combat')
    end,
    PLAYER_REGEN_ENABLED = function()
        CDM.inCombat = false
        CDM:DeriveUsing(0, 'combat')
        if resolvePending then
            resolvePending = false
            resolveAllFrame:NUIScheduleUpdate()
        end
    end,
    PLAYER_TARGET_CHANGED = function()
        CDM:DeriveUsing(0, 'hasTarget', 'attackable')
        CDM:RefreshUsable() -- usability can change with the target
    end,
    GROUP_ROSTER_UPDATE = function()
        CDM:DeriveUsing(-1, 'classInGroup')
    end,
    SPELL_UPDATE_ICON = function(spellID)
        CDM:ResolveOverrides(spellID)
    end,
    COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED = function(baseSpellID)
        CDM:ResolveOverrides(baseSpellID)
    end,
}

---The catalogue rebuilt (SPELLS_CHANGED and others), so every display re-resolves once.
function CDM:OnCatalogueChanged()
    if self.inCombat then
        -- In combat this fires on every override swap, which ResolveOverrides already handled; only a learned or lost spell
        -- and an icon swapped without an override matter.
        resolvePending = true
        loadCheckFrame:NUIScheduleUpdate()
        self:RefreshSpellTextures()
        return
    end

    resolveAllFrame:NUIScheduleUpdate()
end

local function OnEvent(_, event, ...)
    handlers[event](...)
end

function CDM:RegisterTriggerEvents()
    self.inCombat = InCombatLockdown() -- a reload mid-fight misses the REGEN_DISABLED edge

    if not eventFrame then
        eventFrame = CreateFrame('Frame')
        eventFrame:SetScript('OnEvent', OnEvent)
        resolveAllFrame = CreateFrame('Frame')
        resolveAllFrame:NUISetScheduledUpdate(ResolveAllScheduled)
        loadCheckFrame = CreateFrame('Frame')
        loadCheckFrame:NUISetScheduledUpdate(CheckLoadScheduled)
    end

    for event in pairs(handlers) do
        eventFrame:RegisterEvent(event)
    end

    for _, triggerType in pairs(self.TriggerTypes) do
        if triggerType.RegisterEvents then
            triggerType.RegisterEvents()
        end
    end
end

function CDM:UnregisterTriggerEvents()
    eventFrame:UnregisterAllEvents()

    for _, triggerType in pairs(self.TriggerTypes) do
        if triggerType.UnregisterEvents then
            triggerType.UnregisterEvents()
        end
    end
end

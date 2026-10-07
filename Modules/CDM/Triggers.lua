---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local pairs, ipairs = pairs, ipairs
local next = next
local CreateFrame = CreateFrame
local GetSpellCooldown = C_Spell.GetSpellCooldown
local GetSpellCharges = C_Spell.GetSpellCharges
local GetSpellCooldownDuration = C_Spell.GetSpellCooldownDuration
local GetSpellChargeDuration = C_Spell.GetSpellChargeDuration
local GetSpellTexture = C_Spell.GetSpellTexture
local GetOverrideSpell = C_Spell.GetOverrideSpell
local IsSpellKnown = C_SpellBook.IsSpellKnown
local GetSpellName = C_Spell.GetSpellName
local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemCooldown = GetInventoryItemCooldown
local GetItemCooldown = C_Item.GetItemCooldown
local GetItemCount = C_Item.GetItemCount
local GetItemIconByID = C_Item.GetItemIconByID
local GetItemNameByID = C_Item.GetItemNameByID
local GetItemSpell = C_Item.GetItemSpell
local CreateDuration = C_DurationUtil.CreateDuration
local GetTime = GetTime
local GLOBAL_RECOVERY_CATEGORY = Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY

local spellIndex = {} ---@type table<number, table<string, true>> spellID -> icon ids watching it
local tconcat, tsort, tostring = table.concat, table.sort, tostring
local AuraKey
local inCooldownEvent = false
local itemWatchers = {} ---@type table<string, true> icon ids with an item trigger

local ITEM_SLOTS = { trinket1 = INVSLOT_TRINKET1, trinket2 = INVSLOT_TRINKET2 }
-- Items that share one cooldown, so any of them reads it; the first one in the bags is shown.
local ITEM_FAMILIES = {
    healthstone = { 5512, 224464 }, -- Healthstone, Demonic Healthstone
    combatPotion = { 241308 },      -- Light's Potential; every combat potion shares its cooldown
}
local MIN_ITEM_COOLDOWN = 1.5 -- shorter is the item's global cooldown, not its own

---The item IDs an item trigger can read: the equipped trinket, a family, or a custom ID.
---@param trigger table
---@return number[]
local function ItemIDs(trigger)
    local slot = ITEM_SLOTS[trigger.Item]
    if slot then return { GetInventoryItemID('player', slot) } end
    if trigger.Item == 'custom' then return { trigger.ItemID } end
    return ITEM_FAMILIES[trigger.Item] or {}
end

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
    itemWatchers[id] = nil
    for spellID, watchers in pairs(spellIndex) do
        watchers[id] = nil
        if not next(watchers) then spellIndex[spellID] = nil end
    end
end

-- Trigger types. Resolve runs on build and on spell changes, Update on every relevant event,
-- IsActive picks the layer on show: the first active trigger wins.
CDM.TriggerTypes = {
    spell = {
        ---@param trigger table
        ---@return boolean
        IsKnown = function(trigger)
            local base = trigger.SpellID
            if not base then return false end
            return IsSpellKnown(base) or IsSpellKnown(GetOverrideSpell(base) or base)
        end,

        ---@param layer CDMLayer
        ---@param trigger table
        Resolve = function(layer, trigger)
            local base = trigger.SpellID
            layer.baseSpellID = base
            layer.spellID = base and (GetOverrideSpell(base) or base)
            Index(base, layer.owner.id)
            Index(layer.spellID, layer.owner.id)
            CDM:SetIconTexture(layer, layer.spellID and GetSpellTexture(layer.spellID))
        end,

        -- Only isActive/isOnGCD/isEnabled/maxCharges are documented NeverSecret; every timing value
        -- reaches the widgets inside duration objects.
        ---@param layer CDMLayer
        ---@param style table
        Update = function(layer, style)
            local spellID = layer.spellID
            if not spellID then return end
            local state = layer.state
            local cooldown = GetSpellCooldown(spellID)
            local charges = GetSpellCharges(spellID)

            state.hasCharges = charges ~= nil and charges.maxCharges > 1
            if inCooldownEvent then state.onGCD = cooldown ~= nil and cooldown.isOnGCD == true end
            state.onCooldown = cooldown ~= nil and cooldown.isActive and not state.onGCD
            state.recharging = state.hasCharges and charges.isActive

            -- Time texts never count the global cooldown; the swipe only does when the style asks.
            local duration, swipe
            if state.recharging and not state.onCooldown then
                duration = GetSpellChargeDuration(spellID)
                swipe = duration
            else
                duration = GetSpellCooldownDuration(spellID, true)
                swipe = style.ShowGCD and GetSpellCooldownDuration(spellID) or duration
            end
            if swipe then
                layer.Cooldown:SetCooldownFromDurationObject(swipe)
            else
                layer.Cooldown:Clear() -- previewing a spell this character doesn't have
            end
            layer.duration = duration
            layer.Icon:SetDesaturated(style.Desaturate or (style.DesaturateOnCooldown and state.onCooldown))
            CDM:UpdateTexts(layer)
        end,

        ---@param layer CDMLayer
        IsActive = function(layer) return layer.spellID ~= nil end,
    },

    item = {
        ---@param trigger table
        ---@return boolean
        IsKnown = function(trigger)
            local itemID = ItemIDs(trigger)[1]
            if not itemID then return false end
            -- A blacklisted trinket, or a passive one when the trigger hides those, never loads.
            if ITEM_SLOTS[trigger.Item] then
                if CDM.db.TrinketBlacklist[itemID] then return false end
                if trigger.HidePassive and not GetItemSpell(itemID) then return false end
            end
            return true
        end,

        ---@param layer CDMLayer
        ---@param trigger table
        Resolve = function(layer, trigger)
            local ids = ItemIDs(trigger)
            local owned
            for _, itemID in ipairs(ids) do
                if ITEM_SLOTS[trigger.Item] or GetItemCount(itemID, false, true) > 0 then
                    owned = itemID
                    break
                end
            end
            layer.itemID = owned or ids[1]
            layer.itemSlot = ITEM_SLOTS[trigger.Item]
            layer.itemFamily = not layer.itemSlot and ids or nil
            layer.spellID, layer.baseSpellID = nil, nil
            itemWatchers[layer.owner.id] = true
            CDM:SetIconTexture(layer, layer.itemID and GetItemIconByID(layer.itemID))
        end,

        -- Item cooldowns are plain numbers, so the duration object is built here.
        ---@param layer CDMLayer
        ---@param style table
        Update = function(layer, style)
            local itemID = layer.itemID
            if not itemID then return end

            local start, duration, enabled
            if layer.itemSlot then
                start, duration, enabled = GetInventoryItemCooldown('player', layer.itemSlot)
            else
                start, duration, enabled = GetItemCooldown(itemID)
            end
            local onCooldown = enabled ~= false and enabled ~= 0 and (duration or 0) > MIN_ITEM_COOLDOWN
                and start + duration > GetTime()

            layer.itemDuration = layer.itemDuration or CreateDuration()
            if onCooldown then
                layer.itemDuration:SetTimeFromStart(start, duration)
                layer.Cooldown:SetCooldownFromDurationObject(layer.itemDuration)
            else
                layer.itemDuration:SetTimeFromStart(0, 0)
                layer.Cooldown:Clear()
            end
            layer.duration = layer.itemDuration

            local count
            if layer.itemFamily then
                count = 0
                for _, familyID in ipairs(layer.itemFamily) do count = count + GetItemCount(familyID, false, true) end
            end
            layer.count = count
            layer.state.onCooldown = onCooldown

            layer.Icon:SetDesaturated(style.Desaturate or (style.DesaturateOnCooldown and onCooldown) or count == 0)
            CDM:UpdateTexts(layer)
        end,

        ---@param layer CDMLayer
        IsActive = function(layer) return layer.itemID ~= nil end,
    },

    -- Secret: whether the aura is up never reaches Lua, the layer's slot shows itself while it is.
    aura = {
        Secret = true,

        ---@param trigger table
        ---@return boolean
        IsKnown = function(trigger) return CDM:GetAuraSpellIDs(trigger) ~= nil end,

        ---@param layer CDMLayer
        ---@param trigger table
        Resolve = function(layer, trigger)
            local spellIDs = CDM:GetAuraSpellIDs(trigger)
            if not spellIDs then return CDM:ReleaseAuraLayer(layer) end

            local key = AuraKey(trigger, spellIDs)
            local configured = layer.auraKey == key
            layer.auraKey = key
            NRSKNUI:RunWhenSafe(function()
                if layer.auraKey ~= key then return end
                if configured then
                    CDM:StyleAuraButton(layer, trigger)
                else
                    CDM:ConfigureAuraLayer(layer, trigger, spellIDs)
                end
            end)
        end,

        Update = function() end,
        IsActive = function() return false end,
    },
}

---@param trigger table
---@return number? texture
function CDM:GetTriggerTexture(trigger)
    if trigger.Type == 'item' then
        local itemID = ItemIDs(trigger)[1]
        return itemID and GetItemIconByID(itemID)
    end
    return trigger.SpellID and GetSpellTexture(trigger.SpellID)
end

---@param trigger table
---@return string? name
function CDM:GetTriggerName(trigger)
    if trigger.Type == 'item' then
        local itemID = ItemIDs(trigger)[1]
        return itemID and GetItemNameByID(itemID)
    end
    return trigger.SpellID and GetSpellName(trigger.SpellID)
end

---The aura spell IDs a trigger watches: a Cooldown Manager entry's spell and its linked spells, or a custom list.
---@param trigger table
---@return table<number, true>? spellIDs
function CDM:GetAuraSpellIDs(trigger)
    local ids = {}
    if trigger.Source == 'custom' then
        for _, spellID in ipairs(trigger.SpellIDs or {}) do ids[spellID] = true end
    else
        local info = trigger.CooldownID and self.Catalogue:GetEntry(trigger.CooldownID)
        if info then
            if info.spellID then ids[info.spellID] = true end
            if info.overrideSpellID then ids[info.overrideSpellID] = true end
            for _, linked in ipairs(info.linkedSpellIDs or {}) do ids[linked] = true end
        elseif trigger.SpellID then
            ids[trigger.SpellID] = true
        end
    end
    if next(ids) == nil then return nil end
    return ids
end

---What an aura slot is configured for, so an unchanged trigger skips the out-of-combat rebuild.
---@param trigger table
---@param spellIDs table<number, true>
---@return string
function AuraKey(trigger, spellIDs)
    local ids = {}
    for spellID in pairs(spellIDs) do ids[#ids + 1] = spellID end
    tsort(ids)
    return tconcat(ids, ',') .. '|' .. tostring(trigger.Unit) .. '|' .. tostring(trigger.OwnOnly)
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
        layer.Icon:SetShown(not secret)
        layer.Cooldown:SetShown(not secret)
        layer.textHost:SetShown(not secret)
        if not secret then self:ReleaseAuraLayer(layer) end
        if triggerType then triggerType.Resolve(layer, trigger) end
    end
end

---Show the first active trigger's layer and hide the ones it covers.
---@param frame CDMIcon
---@param display table
function CDM:SelectLayer(frame, display)
    local active
    for i, trigger in ipairs(display.Triggers) do
        local layer = frame.layers[i]
        local triggerType = self.TriggerTypes[trigger.Type]
        if triggerType and triggerType.Secret then
            layer:SetShown(not active) -- shows itself while its aura is up, above whatever is active below
        else
            local show = not active and triggerType ~= nil and triggerType.IsActive(layer, trigger)
            if show then active = layer end
            layer:SetShown(show)
        end
    end
    frame.activeLayer = active
end

---@param id string
function CDM:UpdateIcon(id)
    local frame = self.icons[id]
    local display = self:Get(id)
    if not (frame and display and frame.shown) then return end

    for i, trigger in ipairs(display.Triggers) do
        local triggerType = self.TriggerTypes[trigger.Type]
        if triggerType then triggerType.Update(frame.layers[i], frame.style, trigger) end
    end
    self:SelectLayer(frame, display)
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

local function UpdateItems()
    for id in pairs(itemWatchers) do CDM:UpdateIcon(id) end
end

-- A swapped trinket or a bag change can change which item a trigger shows, and whether it loads at all.
local function ResolveItems()
    local itemType = CDM.TriggerTypes.item
    for id in pairs(itemWatchers) do
        local frame, display = CDM.icons[id], CDM:Get(id)
        if frame and display then
            for i, trigger in ipairs(display.Triggers) do
                if trigger.Type == 'item' then itemType.Resolve(frame.layers[i], trigger) end
            end
        end
    end
    CDM:RefreshLoad()
end

-- isOnGCD is only trustworthy inside the SPELL_UPDATE_COOLDOWN handler (SpellSharedDocumentation.lua, live),
-- so cooldown updates run in the handler rather than being coalesced to the next frame.
local handlers = {
    SPELL_UPDATE_COOLDOWN = function(spellID, baseSpellID, _, startRecoveryCategory)
        inCooldownEvent = true
        if not spellID or startRecoveryCategory == GLOBAL_RECOVERY_CATEGORY then
            UpdateAll()
        else
            UpdateWatchers(spellID)
            if baseSpellID ~= spellID then UpdateWatchers(baseSpellID) end
        end
        inCooldownEvent = false
    end,
    SPELL_UPDATE_CHARGES = UpdateAll,
    BAG_UPDATE_COOLDOWN = UpdateItems,
    BAG_UPDATE_DELAYED = ResolveItems,
    PLAYER_EQUIPMENT_CHANGED = ResolveItems,
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

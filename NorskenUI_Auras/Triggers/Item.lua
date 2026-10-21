---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

local pairs, ipairs = pairs, ipairs
local format = string.format
local CreateFrame = CreateFrame
local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemCooldown = GetInventoryItemCooldown
local GetItemCooldown = C_Item.GetItemCooldown
local GetItemCount = C_Item.GetItemCount
local GetItemIconByID = C_Item.GetItemIconByID
local GetItemNameByID = C_Item.GetItemNameByID
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetItemSpell = C_Item.GetItemSpell
local IsUsableItem = C_Item.IsUsableItem
local CreateDuration = C_DurationUtil.CreateDuration
local NewTimer = C_Timer.NewTimer
local GetTime = GetTime

local IsPreviewing, PreviewDuration = CDM.IsPreviewingLayer, CDM.PreviewDuration
local PREVIEW_LENGTH = CDM.PREVIEW_LENGTH

local ITEM_SLOTS = { trinket1 = INVSLOT_TRINKET1, trinket2 = INVSLOT_TRINKET2 }
-- Items that share one cooldown, so any of them reads it; the first one in the bags is shown.
local ITEM_FAMILIES = {
    healthstone = { 5512, 224464 }, -- Healthstone, Demonic Healthstone
    combatPotion = { 241308 },      -- Light's Potential; every combat potion shares its cooldown
}
local MIN_ITEM_COOLDOWN = 1.5       -- shorter is the item's global cooldown, not its own

local itemWatchers = {} ---@type table<string, true> icon ids with an item trigger

--[[
Item triggers: an equipped trinket, a family of items that share a cooldown (healthstones, potions) or one item by ID.
]]

-- Trigger --

---The item IDs an item trigger can read: the equipped trinket, a family, or a custom ID.
---@param trigger table
---@return number[]
local function ItemIDs(trigger)
    local slot = ITEM_SLOTS[trigger.Item]
    if slot then
        return { GetInventoryItemID('player', slot) }
    end
    if trigger.Item == 'custom' then
        return { trigger.ItemID }
    end
    return ITEM_FAMILIES[trigger.Item] or {}
end

CDM.TriggerTypes.item = {
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
        local display = layer.owner.id and CDM:Get(layer.owner.id)
        layer.watchUsable = display ~= nil and CDM:ConditionsUse(display, layer.index, 'usable')
        itemWatchers[layer.owner.id] = true
        CDM:SetIconTexture(layer, layer.itemID and GetItemIconByID(layer.itemID))
    end,

    -- Item cooldowns are plain numbers, so the duration object is built here.
    ---@param layer CDMLayer
    ---@param style table
    ---@param trigger table
    Update = function(layer, style, trigger)
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
        local preview = not onCooldown and IsPreviewing(layer)

        layer.itemDuration = layer.itemDuration or CreateDuration()
        if onCooldown then
            layer.itemDuration:SetTimeFromStart(start, duration)
            layer.duration = layer.itemDuration
        elseif preview then
            layer.duration = PreviewDuration(layer, PREVIEW_LENGTH)
        else
            layer.itemDuration:SetTimeFromStart(0, 0)
            layer.duration = layer.itemDuration
        end
        CDM:SetLayerTimer(layer, (onCooldown or preview) and layer.duration or nil)
        layer.endTime = (onCooldown and start + duration) or (preview and layer.previewEnd) or nil
        if layer.timerTicker then
            layer.timerTicker:Cancel()
        end
        layer.timerTicker = nil
        if onCooldown and trigger.ShowOn then
            -- A hidden layer's Cooldown never fires OnCooldownDone, so When Ready would stay hidden.
            layer.timerTicker = NewTimer(start + duration - GetTime(), function()
                layer.timerTicker = nil
                CDM:UpdateLayer(layer)
            end)
        end

        local count
        if layer.itemFamily then
            count = 0
            for _, familyID in ipairs(layer.itemFamily) do
                count = count + GetItemCount(familyID, false, true)
            end
        end
        layer.count = count
        layer.state.onCooldown = onCooldown or preview
        layer.state.owned = layer.itemSlot ~= nil or (count or 0) > 0
        -- ~50 µs a call, so only for a condition that reads it
        if layer.watchUsable then
            layer.state.usable = IsUsableItem(itemID) == true
        end

        CDM:UpdateTexts(layer)
    end,

    -- An item not in the bags only shows with Show When Not in Bags, or a condition's Show Display.
    ---@param layer CDMLayer
    ---@param trigger table
    IsActive = function(layer, trigger)
        if layer.itemID == nil then return false end
        if IsPreviewing(layer) then return true end
        if layer.state.owned == false and trigger.ShowNotOwned ~= true then return false end
        local showOn = trigger.ShowOn
        return not showOn or (layer.state.onCooldown == true) == (showOn == 'cooldown')
    end,

    ---@param layer CDMLayer
    IsStandby = function(layer) return layer.itemID ~= nil and layer.state.owned == false end,
}

---@param trigger table
---@return number? texture
CDM.TriggerTypes.item.Texture = function(trigger)
    local itemID = ItemIDs(trigger)[1]
    return itemID and GetItemIconByID(itemID)
end

---@param trigger table
---@return string? name
CDM.TriggerTypes.item.Name = function(trigger)
    local itemID = ItemIDs(trigger)[1]
    return itemID and GetItemNameByID(itemID)
end

---@param i number
---@param trigger table
---@param warnings string[]
CDM.TriggerTypes.item.Warnings = function(i, trigger, warnings)
    if trigger.Item ~= 'custom' then return end
    if not trigger.ItemID then
        warnings[#warnings + 1] = format(L['Trigger %d: no item ID.'], i)
    elseif not GetItemInfoInstant(trigger.ItemID) then
        warnings[#warnings + 1] = format(L['Trigger %d: item ID %d does not exist.'], i, trigger.ItemID)
    end
end

---@param id string
CDM.TriggerTypes.item.Unwatch = function(id)
    itemWatchers[id] = nil
end

-- Events --

local ITEM_TYPES = { item = true }

local function UpdateItems()
    for id in pairs(itemWatchers) do
        CDM:UpdateTriggers(id, ITEM_TYPES)
    end
end

-- A swapped trinket or a bag change can change which item a trigger shows, and whether it loads at all.
local function ResolveItems()
    local itemType = CDM.TriggerTypes.item
    for id in pairs(itemWatchers) do
        local frame, display = CDM.icons[id], CDM:Get(id)
        if frame and display then
            for i, trigger in ipairs(display.Triggers) do
                if trigger.Type == 'item' then
                    itemType.Resolve(frame.layers[i], trigger)
                end
            end
        end
    end
    CDM:RefreshLoad(true)
    UpdateItems() -- a display that stayed loaded may now show another item or count
end

-- Item usability isn't re-read on SPELL_UPDATE_USABLE; these are what change it.
local handlers = {
    BAG_UPDATE_COOLDOWN = UpdateItems,
    PLAYER_REGEN_DISABLED = UpdateItems,
    PLAYER_REGEN_ENABLED = UpdateItems,
    BAG_UPDATE_DELAYED = ResolveItems,
    PLAYER_EQUIPMENT_CHANGED = ResolveItems,
}

local eventFrame ---@type Frame?

local function OnEvent(_, event)
    handlers[event]()
end

CDM.TriggerTypes.item.RegisterEvents = function()
    if not eventFrame then
        eventFrame = CreateFrame('Frame')
        eventFrame:SetScript('OnEvent', OnEvent)
    end

    for event in pairs(handlers) do
        eventFrame:RegisterEvent(event)
    end
end

CDM.TriggerTypes.item.UnregisterEvents = function()
    eventFrame:UnregisterAllEvents()
end

-- Conditions --

CDM.ConditionChecks.item = {
    active     = { type = 'bool', get = function(layer, trigger) return CDM.TriggerTypes.item.IsActive(layer, trigger) end },
    onCooldown = { type = 'bool', get = function(layer) return layer.state.onCooldown == true end },
    remaining  = { type = 'number', get = function(layer) return layer.endTime and layer.endTime - GetTime() or 0 end },
    count      = { type = 'number', get = function(layer) return layer.count or 0 end },
    owned      = { type = 'bool', get = function(layer) return layer.state.owned ~= false end },
    usable     = { type = 'bool', get = function(layer) return layer.state.usable == true end },
}

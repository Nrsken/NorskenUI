---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

-- Blizzard for some reason doesn't provide a direct API to access its tracked aura/cooldown bars,
-- so we have to find them in the item frame pool ourselves and mirror their state onto our own bars.

local next = next
local wipe = wipe
local pairs = pairs
local CreateFrame = CreateFrame

local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture
local GetSpellName = C_Spell and C_Spell.GetSpellName

local SCAN_INTERVAL = 0.25

local viewerLayers = {} ---@type table<CDMLayer, table|true> layers following a Cooldown Manager bar -> their trigger
local scanElapsed = 0

---@param child table
---@return boolean
local function ChildIsActive(child)
    if child.IsActive then
        return child:IsActive() and true or false
    end
    return child:IsShown() and true or false
end

---@param cooldownID number
---@return table? child the live Tracked Bar frame Blizzard draws for this entry
local function FindChild(cooldownID)
    local viewer = _G.BuffBarCooldownViewer
    local pool = viewer and viewer.itemFramePool

    if not (pool and pool.EnumerateActive) then
        return nil
    end

    for child in pool:EnumerateActive() do
        local id = child.cooldownID
        if id ~= nil and not NRSKNUI:IsSecretValue(id) and id == cooldownID then
            return child
        end
    end
end

---@param layer CDMLayer
---@return table? child
local function GetChild(layer)
    local child = layer.viewerChild
    local id = child and child.cooldownID
    if child and id ~= nil and not NRSKNUI:IsSecretValue(id) and id == layer.viewerCooldownID then return child end
    layer.viewerChild = FindChild(layer.viewerCooldownID)
    return layer.viewerChild
end

---Pass remaining time from the Blizzard Cooldown Manager's tracked bar to our own bar, or to a split power bar's progress source.
---@param layer CDMLayer
---@return boolean active
local function Mirror(layer)
    local child = GetChild(layer)
    local source = child and child.Bar
    local active = source ~= nil and ChildIsActive(child)

    local target = layer.viewerTarget or (layer.isBar and layer.Bar)
    if active and target and not layer.viewerHold then
        target:SetMinMaxValues(source:GetMinMaxValues())
        target:SetValue(source:GetValue())
        if target == layer.Bar then layer.Bar.spark:SetAlpha(1) end
    end
    return active
end

local driver = CreateFrame('Frame')
driver:Hide()
driver:SetScript('OnUpdate', function(_, elapsed)
    scanElapsed = scanElapsed + elapsed
    for layer in pairs(viewerLayers) do
        local owner = layer.owner
        if owner.shown and owner.id and (layer.viewerChild or scanElapsed >= SCAN_INTERVAL) then
            if Mirror(layer) ~= (layer.viewerActive == true) then
                CDM:UpdateIcon(owner.id)
            end
        end
    end
    if scanElapsed >= SCAN_INTERVAL then scanElapsed = 0 end
end)

---Follow a tracked bar onto `target` every frame, for a split power bar's progress source.
---@param layer CDMLayer
---@param cooldownID number
---@param target StatusBar
function CDM:WatchViewerBar(layer, cooldownID, target)
    layer.viewerCooldownID = cooldownID
    layer.viewerChild = nil
    layer.viewerTarget = target
    viewerLayers[layer] = true
    driver:Show()
end

---Mirror once and say whether the tracked bar is running.
---@param layer CDMLayer
---@return boolean active
function CDM:MirrorViewerBar(layer)
    local active = Mirror(layer)
    layer.viewerActive = active
    return active
end

-- A Tracked Bar of Blizzard's Cooldown Manager, drawn on our own bar, for entries that aren't real auras.
CDM.TriggerTypes.viewerbar = {
    ---@param trigger table
    ---@return boolean
    IsKnown = function(trigger) return trigger.CooldownID ~= nil end,

    ---@param layer CDMLayer
    ---@param trigger table
    Resolve = function(layer, trigger)
        layer.spellID, layer.baseSpellID = nil, nil
        layer.viewerCooldownID = trigger.CooldownID
        layer.viewerChild = nil
        viewerLayers[layer] = trigger
        driver:Show()

        local info = trigger.CooldownID and CDM.Catalogue:GetEntry(trigger.CooldownID)
        local spellID = info and CDM.Catalogue:ResolveSpell(info) or trigger.SpellID
        layer.viewerSpellID = spellID
        CDM:SetIconTexture(layer, spellID and GetSpellTexture(spellID))
    end,

    ---@param layer CDMLayer
    ---@param style table
    Update = function(layer, style)
        layer.duration = nil
        local spellID = layer.viewerSpellID
        local active = Mirror(layer)
        layer.viewerActive = active
        if active then
            CDM:SetLayerName(layer, spellID and GetSpellName(spellID) or '')
        elseif CDM.IsPreviewingLayer(layer) then
            layer.duration = CDM.PreviewDuration(layer, 7)
            CDM:SetLayerTimer(layer, layer.duration)
            CDM:SetLayerName(layer, spellID and GetSpellName(spellID) or L['Cooldown Bar'])
        else
            CDM:SetLayerTimer(layer, nil)
        end
        if active then
            layer.Cooldown:Clear()
        end
        CDM:UpdateTexts(layer)
    end,

    ---@param layer CDMLayer
    ---@return boolean
    IsActive = function(layer)
        return layer.viewerActive == true or CDM.IsPreviewingLayer(layer)
    end,

    ---@param id string
    Unwatch = function(id)
        for layer in pairs(viewerLayers) do
            if layer.owner.id == id then
                viewerLayers[layer] = nil
                layer.viewerChild, layer.viewerActive, layer.viewerTarget, layer.viewerHold = nil, nil, nil, nil
            end
        end
        if not next(viewerLayers) then
            driver:Hide()
        end
    end,

    UnregisterEvents = function()
        wipe(viewerLayers)
        driver:Hide()
    end,
}

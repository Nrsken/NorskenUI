---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

local next = next
local wipe = wipe
local pairs = pairs
local CreateFrame = CreateFrame

local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture
local GetSpellName = C_Spell and C_Spell.GetSpellName

local SCAN_INTERVAL = 0.25

local viewerLayers = {} ---@type table<CDMLayer, table|true> layers following a Cooldown Manager bar -> their trigger
local scanElapsed = 0

--[[
Cooldown Bar triggers: a Tracked Bar of Blizzard's Cooldown Manager mirrored onto our own bar.
No API reads those bars, so the live frame is found in the viewer's pool and copied every frame.
]]

-- Mirror --

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
    -- a pooled frame can be handed to another entry, so the cached one is checked first
    if child and id ~= nil and not NRSKNUI:IsSecretValue(id) and id == layer.viewerCooldownID then
        return child
    end
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
        if target == layer.Bar then
            layer.Bar.spark:SetAlpha(1)
        end
    end
    return active
end

local driver ---@type Frame?

local function Drive(_, elapsed)
    scanElapsed = scanElapsed + elapsed
    for layer in pairs(viewerLayers) do
        local owner = layer.owner
        if owner.shown and owner.id and (layer.viewerChild or scanElapsed >= SCAN_INTERVAL) then
            if Mirror(layer) ~= (layer.viewerActive == true) then
                CDM:UpdateLayer(layer)
            end
        end
    end

    if scanElapsed >= SCAN_INTERVAL then
        scanElapsed = 0
    end
end

---Runs only while some display reads a Cooldown Manager bar.
local function StartDriver()
    if not driver then
        driver = CreateFrame('Frame')
        driver:SetScript('OnUpdate', Drive)
    end
    driver:Show()
end

---Follow a tracked bar onto `target` every frame, for a split power bar's progress source.
---@param layer CDMLayer
---@param cooldownID number
---@param target StatusBar
function CDM:WatchViewerBar(layer, cooldownID, target)
    layer.viewerCooldownID = cooldownID
    layer.viewerChild = nil
    layer.viewerTarget = target
    viewerLayers[layer] = true
    StartDriver()
end

---Mirror once and say whether the tracked bar is running.
---@param layer CDMLayer
---@return boolean active
function CDM:MirrorViewerBar(layer)
    local active = Mirror(layer)
    layer.viewerActive = active
    return active
end

-- Trigger --

-- For Cooldown Manager entries that aren't real auras.
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
        StartDriver()

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
            layer.duration = CDM.PreviewDuration(layer, CDM.PREVIEW_LENGTH)
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
        if driver and not next(viewerLayers) then
            driver:Hide()
        end
    end,

    UnregisterEvents = function()
        wipe(viewerLayers)
        if driver then
            driver:Hide()
        end
    end,
}

-- Conditions --

CDM.ConditionChecks.viewerbar = {
    active = { type = 'bool', get = function(layer) return CDM.TriggerTypes.viewerbar.IsActive(layer) end },
}

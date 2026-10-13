---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

local _G = _G
local pairs, ipairs = pairs, ipairs
local unpack = unpack
local CreateFrame = CreateFrame
local GetSpecialization, GetSpecializationInfo = GetSpecialization, GetSpecializationInfo

local WHITE = 'Interface\\Buttons\\WHITE8X8'
local GATE_LENGTH = 1000000 -- a comparison bar; a stat 0.1% below another moves its gate 1000px away
local GATE_REACH = 4000     -- an open gate's clip, centred on the display's right edge, so any display fits inside

-- The character sheet's stats, percent and rating (PaperDollFrame.lua, live); secret in combat, so versatility is its rating part alone.
CDM.STATS = {
    { key = 'haste',       name = L['Haste'],             get = function() return GetHaste() end,                                       rating = 'CR_HASTE_MELEE' },
    { key = 'crit',        name = L['Critical Strike'],   get = function() return GetCritChance() end,                                  rating = 'CR_CRIT_MELEE' },
    { key = 'mastery',     name = L['Mastery'],           get = function() return (GetMasteryEffect()) end,                             rating = 'CR_MASTERY' },
    { key = 'versatility', name = L['Versatility'],       get = function() return GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) end, rating = 'CR_VERSATILITY_DAMAGE_DONE' },
    { key = 'leech',       name = L['Leech'],             get = function() return GetLifesteal() end,                                   rating = 'CR_LIFESTEAL' },
    { key = 'avoidance',   name = L['Avoidance'],         get = function() return GetAvoidance() end,                                   rating = 'CR_AVOIDANCE' },
    { key = 'speed',       name = L['Speed'],             get = function() return GetSpeed() end,                                       rating = 'CR_SPEED' },
    -- The secondary with the highest or lowest rating, as Potion of Recklessness picks it (in-game probe 2026-10-13).
    { key = 'highest',     name = L['Highest Secondary'], gate = 'highest' },
    { key = 'lowest',      name = L['Lowest Secondary'],  gate = 'lowest' },
}
local STAT_BY_KEY = {}
for _, stat in pairs(CDM.STATS) do STAT_BY_KEY[stat.key] = stat end
local SECONDARIES = { STAT_BY_KEY.haste, STAT_BY_KEY.crit, STAT_BY_KEY.mastery, STAT_BY_KEY.versatility }

-- What PaperDollFrame refreshes its stats on.
local EVENTS = { 'COMBAT_RATING_UPDATE', 'MASTERY_UPDATE', 'SPEED_UPDATE', 'LIFESTEAL_UPDATE', 'AVOIDANCE_UPDATE', 'PLAYER_DAMAGE_DONE_MODS' }
local UNIT_EVENTS = { 'UNIT_SPELL_HASTE', 'UNIT_STATS', 'UNIT_ATTACK_SPEED' }

local statLayers = {} ---@type table<CDMLayer, table> stat layers -> their trigger

---@param trigger table
---@return table
function CDM:GetStat(trigger)
    return STAT_BY_KEY[trigger.Stat] or STAT_BY_KEY.haste
end

-- Gates: the engine compares secret ratings (a bar is full when value >= max); nested clips on the fill edges open for the winner.

---@class CDMStatGate
---@field root Frame the outermost clip, hidden while the layer isn't gated
---@field inner Frame the innermost clip, which the copies live in
---@field bars StatusBar[] one comparison per other stat
---@field others number[] which secondary each bar compares against
---@field source { value: any, max: any } what the copies read: this stat's percent and rating
---@field texts CDMIconText[] a copy of each of the layer's texts
---@field fill StatusBar? bar displays: this stat's percent

---@param layer CDMLayer
---@param index number
---@return CDMStatGate
local function CreateGate(layer, index)
    local gate = { bars = {}, others = {}, source = {}, texts = {} } --[[@as CDMStatGate]]
    local parent = layer
    for other = 1, #SECONDARIES do
        if other ~= index then
            local bar = CreateFrame('StatusBar', nil, layer)
            bar:SetStatusBarTexture(WHITE)
            bar:GetStatusBarTexture():SetAlpha(0)
            bar:SetSize(GATE_LENGTH, 1)
            bar:SetPoint('RIGHT', layer, 'RIGHT', GATE_REACH / 2, 0)
            local clip = CreateFrame('Frame', nil, parent)
            clip:SetClipsChildren(true)
            clip:SetSize(GATE_REACH, GATE_REACH)
            clip:SetPoint('RIGHT', bar:GetStatusBarTexture(), 'RIGHT')
            gate.root = gate.root or clip
            gate.bars[#gate.bars + 1] = bar
            gate.others[#gate.others + 1] = other
            parent = clip
        end
    end
    gate.inner = parent
    return gate
end

---@param layer CDMLayer
local function HideGates(layer)
    for _, gate in ipairs(layer.statGates or {}) do gate.root:Hide() end
end

---Copy the layer's texts (and a bar's fill) into one gate per secondary; the original texts stay as the display's size.
---@param layer CDMLayer
local function StyleGates(layer)
    layer.statGates = layer.statGates or {}
    layer:SetIgnoringChildrenForBounds(true) -- a fitting text display must never measure the huge comparison bars
    local style = layer.owner.style
    for index, stat in ipairs(SECONDARIES) do
        local gate = layer.statGates[index] or CreateGate(layer, index)
        layer.statGates[index] = gate
        gate.root:Show()
        for i = 1, layer.textCount or 0 do
            gate.texts[i] = CDM:StyleTextCopy(layer, i, gate.texts[i], gate.inner, stat.name)
        end
        for i = (layer.textCount or 0) + 1, #gate.texts do gate.texts[i].fs:Hide() end

        if layer.isBar then
            local fill = gate.fill or CreateFrame('StatusBar', nil, gate.inner)
            gate.fill = fill
            fill:SetAllPoints(layer.Bar)
            fill:SetFrameLevel(layer.Bar:GetFrameLevel() + 1)
            fill:SetStatusBarTexture(NRSKNUI:GetStatusbar(style))
            fill:SetOrientation(style.Orientation == 'VERTICAL' and 'VERTICAL' or 'HORIZONTAL')
            fill:SetReverseFill(style.ReverseFill == true)
            local color = layer.barColor or style.BarColor
            fill:SetStatusBarColor(unpack(color))
            fill:SetMinMaxValues(0, 100)
            fill:Show()
        elseif gate.fill then
            gate.fill:Hide()
        end
    end
end

---@param layer CDMLayer
---@param lowest boolean
local function UpdateGates(layer, lowest)
    local ratings = {}
    for index, stat in ipairs(SECONDARIES) do ratings[index] = GetCombatRating(_G[stat.rating]) end
    for index, gate in ipairs(layer.statGates or {}) do
        for i, bar in ipairs(gate.bars) do
            local other = ratings[gate.others[i]]
            -- Full while this one is the highest (value >= max), or for Lowest while the other is at least as high.
            if lowest then
                bar:SetMinMaxValues(0, ratings[index])
                bar:SetValue(other)
            else
                bar:SetMinMaxValues(0, other)
                bar:SetValue(ratings[index])
            end
        end
        gate.source.value = SECONDARIES[index].get()
        gate.source.max = ratings[index]
        for i = 1, layer.textCount or 0 do
            if gate.texts[i] then CDM:UpdateTextCopy(gate.texts[i], gate.source) end
        end
        if gate.fill then gate.fill:SetValue(gate.source.value) end
    end
end

-- %p is the percent and %t the rating, which a bar doesn't use: it fills to the percent out of 100.
CDM.TriggerTypes.stat = {
    Value = true,
    Decimals = 0, -- rounded like the character sheet (PaperDollFrame_SetLabelAndText), unless the text picks its own format

    IsKnown = function() return true end,

    ---@param layer CDMLayer
    ---@param trigger table
    Resolve = function(layer, trigger)
        layer.spellID, layer.baseSpellID = nil, nil
        statLayers[layer] = trigger
        local specIndex = GetSpecialization()
        CDM:SetIconTexture(layer, specIndex and select(4, GetSpecializationInfo(specIndex)))
        if CDM:GetStat(trigger).gate then StyleGates(layer) else HideGates(layer) end
    end,

    ---@param layer CDMLayer
    ---@param style table
    ---@param trigger table
    Update = function(layer, style, trigger)
        local stat = CDM:GetStat(trigger)
        if stat.gate then
            UpdateGates(layer, stat.gate == 'lowest')
            -- The layer's own texts only size the display (their %n reads the long "Highest Secondary"); the gates draw.
            local first = layer.statGates and layer.statGates[1]
            layer.value, layer.max = first and first.source.value, first and first.source.max
            CDM:SetLayerValue(layer, 0, 100)
            CDM:UpdateTexts(layer)
            for i = 1, layer.textCount or 0 do layer.texts[i].fs:SetAlpha(0) end
            return
        end
        layer.value = stat.get()
        layer.max = GetCombatRating(_G[stat.rating])
        CDM:SetLayerValue(layer, layer.value, 100)
        CDM:UpdateTexts(layer)
    end,

    IsActive = function() return true end,

    ---@param id string
    Unwatch = function(id)
        for layer in pairs(statLayers) do
            if layer.owner.id == id then
                HideGates(layer) -- a pooled frame may come back with another trigger
                statLayers[layer] = nil
            end
        end
    end,
}

local eventFrame = CreateFrame('Frame')
eventFrame:SetScript('OnEvent', function()
    local stat = CDM.TriggerTypes.stat
    for layer, trigger in pairs(statLayers) do
        if layer.owner.shown then stat.Update(layer, layer.owner.style, trigger) end
    end
end)

---@param trigger table
---@return string name
CDM.TriggerTypes.stat.Name = function(trigger)
    return CDM:GetStat(trigger).name
end

CDM.TriggerTypes.stat.Texture = CDM.TriggerTypes.power.Texture -- the spec's icon, as power's

CDM.TriggerTypes.stat.RegisterEvents = function()
    for _, event in pairs(EVENTS) do eventFrame:RegisterEvent(event) end
    for _, event in pairs(UNIT_EVENTS) do eventFrame:RegisterUnitEvent(event, 'player') end
end

CDM.TriggerTypes.stat.UnregisterEvents = function()
    eventFrame:UnregisterAllEvents()
end

-- Conditions --

-- Its value is secret in combat, so nothing compares it.
CDM.ConditionChecks.stat = {
    active = { type = 'bool', get = function() return true end },
}

---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

--[[
The Player Stat trigger: one secondary's percent and rating or the highest/lowest secondary.
Ratings are secret in combat, so the game picks the highest/lowest and only the winner's text is revealed.
]]

local GetCombatRatingBonus = GetCombatRatingBonus
local GetMasteryEffect = GetMasteryEffect
local GetCombatRating = GetCombatRating
local GetCritChance = GetCritChance
local pairs, ipairs = pairs, ipairs
local GetLifesteal = GetLifesteal
local GetAvoidance = GetAvoidance
local CreateFrame = CreateFrame
local setmetatable = setmetatable
local strfind = string.find
local tconcat = table.concat
local GetHaste = GetHaste
local GetSpeed = GetSpeed
local tostring = tostring
local unpack = unpack
local format = string.format
local next = next
local _G = _G

local GATE_LENGTH = 100000000 -- one rating point below another moves a gate ~10000px, well past GATE_REACH / 2
local GATE_REACH = 4000       -- an open gate's clip, centred on the display's right edge, so any display fits inside
local RATING_FLOOR = -1000    -- Venomcursed procs cut the other secondaries below zero; a max under the min never fills

-- Stats --

CDM.STATS = {
    { key = 'haste', name = L['Haste'], get = GetHaste, rating = 'CR_HASTE_MELEE' },
    { key = 'crit', name = L['Critical Strike'], get = GetCritChance, rating = 'CR_CRIT_MELEE' },
    {
        key = 'mastery',
        name = L['Mastery'],
        get = function()
            return (GetMasteryEffect()) -- the effect, not its coefficient
        end,
        rating = 'CR_MASTERY'
    },
    {
        key = 'versatility',
        name = L['Versatility'],
        get = function()
            return GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE)
        end,
        rating = 'CR_VERSATILITY_DAMAGE_DONE'
    },
    { key = 'leech', name = L['Leech'], get = GetLifesteal, rating = 'CR_LIFESTEAL' },
    { key = 'avoidance', name = L['Avoidance'], get = GetAvoidance, rating = 'CR_AVOIDANCE' },
    { key = 'speed', name = L['Speed'], get = GetSpeed, rating = 'CR_SPEED' },
    {
        key = 'highest',
        name = L['Highest Secondary'],
        gate = 'highest'
    },
    {
        key = 'lowest',
        name = L['Lowest Secondary'],
        gate = 'lowest'
    },
}
local STAT_BY_KEY = {}
for _, stat in pairs(CDM.STATS) do
    STAT_BY_KEY[stat.key] = stat
end
local SECONDARIES = {
    STAT_BY_KEY.haste,
    STAT_BY_KEY.crit,
    STAT_BY_KEY.mastery,
    STAT_BY_KEY.versatility
}

-- What PaperDollFrame refreshes its stats on.
local EVENTS = {
    'COMBAT_RATING_UPDATE',
    'MASTERY_UPDATE',
    'SPEED_UPDATE',
    'LIFESTEAL_UPDATE',
    'AVOIDANCE_UPDATE',
    'PLAYER_DAMAGE_DONE_MODS',
}
local UNIT_EVENTS = {
    'UNIT_SPELL_HASTE',
    'UNIT_STATS',
    'UNIT_ATTACK_SPEED',
}

local statLayers = {} ---@type table<CDMLayer, table>
local ratings = {} -- each secondary's rating, refilled on every stat event

---@param trigger table
---@return table
function CDM:GetStat(trigger)
    return STAT_BY_KEY[trigger.Stat] or STAT_BY_KEY.haste
end

-- Gates --

-- A bar is full only when value >= max, so nested clips on the fill edges open for the stat winning every comparison.

---@param layer CDMLayer
---@param index number
---@return CDMStatGate
local function CreateGate(layer, index)
    local gate = { bars = {}, others = {}, source = {}, texts = {} } --[[@as CDMStatGate]]
    local parent = layer
    for other = 1, #SECONDARIES do
        if other ~= index then
            local bar = CreateFrame('StatusBar', nil, layer)
            bar:SetStatusBarTexture(NRSKNUI.WhiteTexture)
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
    for _, gate in ipairs(layer.statGates or {}) do
        gate.root:Hide()
    end
    for i in pairs(layer.gatedTexts or {}) do
        if layer.texts[i] then
            layer.texts[i].host:SetAlpha(1)
        end
    end
    layer.gatedTexts, layer.gateSource = nil, nil
end

---The texts on `layer` that read the stat layer: all of the stat layer's own, %N.n/%N.p/%N.t on any other.
---@param layer CDMLayer
---@param statLayer CDMLayer
---@return table<number, true>?
local function GatedTexts(layer, statLayer)
    local pattern = '%%' .. statLayer.index .. '%.[npt]'
    local gated
    for i = 1, layer.textCount or 0 do
        local element = layer.texts[i].element
        if layer == statLayer or (element and strfind(element.Text or '', pattern)) then
            gated = gated or {}
            gated[i] = true
        end
    end
    return gated
end

---Copy the gated texts (and the stat's own bar fill) into one gate per secondary; the originals stay, invisible, as the display's size.
---@param layer CDMLayer
---@param statLayer CDMLayer
---@param gated table<number, true>
local function StyleGates(layer, statLayer, gated)
    layer.statGates = layer.statGates or {}
    layer.gatedTexts, layer.gateSource = gated, statLayer
    layer:SetIgnoringChildrenForBounds(true) -- a fitting text display must never measure the huge comparison bars
    for i in pairs(gated) do
        layer.texts[i].host:SetAlpha(0)      -- the host, so a spell trigger's countdown alpha can't bring it back
    end
    local style = layer.owner.style
    local triggers = CDM:Get(layer.owner.id).Triggers
    for index, stat in ipairs(SECONDARIES) do
        local gate = layer.statGates[index] or CreateGate(layer, index)
        layer.statGates[index] = gate
        gate.root:Show()
        -- The copies see the stat trigger as this gate's stat, so %n, %N.n and %N.p all read it.
        local asStat = setmetatable({ [statLayer.index] = { Type = 'stat', Stat = stat.key } }, { __index = triggers })
        for _, copy in pairs(gate.texts) do
            copy.fs:Hide()
        end
        for i in pairs(gated) do
            local copy = CDM:StyleTextCopy(layer, i, gate.texts[i], gate.inner, layer == statLayer and stat.name or nil, asStat)
            gate.texts[i] = copy
            if copy then
                copy.fs:SetShown(layer.texts[i].fs:IsShown()) -- a condition's Visible stays on the original between changes
            end
        end

        if layer == statLayer and layer.isBar then
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

---Read the ratings once and set every reader's gates; each reader's texts re-run, the stat layer's by its own Update.
---@param statLayer CDMLayer
---@param lowest boolean
local function UpdateGates(statLayer, lowest)
    for index, stat in ipairs(SECONDARIES) do
        ratings[index] = GetCombatRating(_G[stat.rating])
    end

    for _, layer in ipairs(statLayer.gateReaders or {}) do
        for index, gate in ipairs(layer.statGates) do
            for i, bar in ipairs(gate.bars) do
                local other = ratings[gate.others[i]]
                if lowest then
                    bar:SetMinMaxValues(RATING_FLOOR, ratings[index])
                    bar:SetValue(other)
                else
                    bar:SetMinMaxValues(RATING_FLOOR, other)
                    bar:SetValue(ratings[index])
                end
            end
            gate.source.value = SECONDARIES[index].get()
            gate.source.max = ratings[index]
        end

        if layer ~= statLayer then
            CDM:UpdateTexts(layer)
        end
    end
end

---Feed a layer's gate copies, after its own texts: a copy reads what its original does, the stat as the gate's stat.
---@param layer CDMLayer
function CDM:UpdateStatCopies(layer)
    local statIndex = layer.gateSource.index
    local layers = layer.owner.layers

    for _, gate in ipairs(layer.statGates) do
        for i in pairs(layer.gatedTexts) do
            local reads = layer.texts[i].source or layer.index
            local copy = gate.texts[i]

            if copy then
                self:UpdateTextCopy(copy, reads == statIndex and gate.source or layers[reads])
            end
        end

        if gate.fill then
            gate.fill:SetValue(gate.source.value)
        end
    end
end

-- Trigger --

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
        CDM:SetIconTexture(layer, nil)
        layer.gateReaders = nil
        if not CDM:GetStat(trigger).gate then return end
        local readers = {}
        local display = CDM:Get(layer.owner.id)
        for i, other in ipairs(display.Triggers) do
            local reader = layer.owner.layers[i]
            local gated = GatedTexts(reader, layer)
            local ownGates = other.Type == 'stat' and CDM:GetStat(other).gate
            local auraTexts = CDM.TriggerTypes[other.Type] and CDM.TriggerTypes[other.Type].Secret -- drawn inside its aura button
            -- a layer reads one Highest/Lowest trigger, the first
            if reader == layer or (gated and not ownGates and not auraTexts and not reader.gateSource) then
                StyleGates(reader, layer, gated or {})
                readers[#readers + 1] = reader
            end
        end
        layer.gateReaders = readers
    end,

    ---@param layer CDMLayer
    ---@param style table
    ---@param trigger table
    Update = function(layer, style, trigger)
        local stat = CDM:GetStat(trigger)
        if stat.gate then
            UpdateGates(layer, stat.gate == 'lowest')
            local first = layer.statGates and layer.statGates[1]
            layer.value, layer.max = first and first.source.value, first and first.source.max
            CDM:SetLayerValue(layer, 0, 100)
            CDM:UpdateTexts(layer)
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
                -- a pooled frame may come back with other triggers
                for _, reader in ipairs(layer.gateReaders or {}) do
                    HideGates(reader)
                end
                HideGates(layer)
                layer.gateReaders = nil
                statLayers[layer] = nil
            end
        end
    end,
}

-- Debug --

---@param value any
---@return string
local function Plain(value)
    return NRSKNUI:IsSecretValue(value) and 'secret' or format('%.2f', value)
end

---The gates for the debug report: what each comparison holds and whether its clip reaches the display.
---@param lines string[]
---@param layer CDMLayer
CDM.TriggerTypes.stat.DebugLines = function(lines, layer)
    for _, reader in ipairs(layer.gateReaders or {}) do
        lines[#lines + 1] = format('  Gates on trigger %d', reader.index)
        local first = next(reader.gatedTexts)
        for index, gate in ipairs(reader.statGates) do
            local bars = {}
            for i, bar in ipairs(gate.bars) do
                local _, max = bar:GetMinMaxValues()
                bars[i] = format('%s %s/%s', SECONDARIES[gate.others[i]].key, Plain(bar:GetValue()), Plain(max))
            end
            local valid, clip = true, gate.inner
            while clip ~= reader do
                valid = valid and clip:IsRectValid()
                clip = clip:GetParent()
            end
            local edge, right = gate.inner:GetRight(), reader:GetRight()
            local fs = first and gate.texts[first] and gate.texts[first].fs
            local text = fs and fs:GetText()
            lines[#lines + 1] = format('    Gate %s: root %s, visible %s, rects %s, clip edge %s, text %s, vs %s', SECONDARIES[index].key,
                gate.root:IsShown() and 'shown' or 'hidden', gate.inner:IsVisible() and 'yes' or 'no', valid and 'valid' or 'INVALID',
                (NRSKNUI:IsSecretValue(edge) or NRSKNUI:IsSecretValue(right)) and 'secret' or (edge and right) and Plain(edge - right) or '-',
                fs and (NRSKNUI:IsSecretValue(text) and 'secret' or format('"%s" alpha %.2f', tostring(text), fs:GetAlpha())) or 'none',
                tconcat(bars, ', '))
        end
    end
end

---@param trigger table
---@return string name
CDM.TriggerTypes.stat.Name = function(trigger)
    return CDM:GetStat(trigger).name
end

-- Events --

local eventFrame ---@type Frame?

local function OnStatEvent()
    local statTrigger = CDM.TriggerTypes.stat
    for layer, trigger in pairs(statLayers) do
        if layer.owner.shown then
            statTrigger.Update(layer, layer.owner.style, trigger)
        end
    end
end

CDM.TriggerTypes.stat.RegisterEvents = function()
    if not eventFrame then
        eventFrame = CreateFrame('Frame')
        eventFrame:SetScript('OnEvent', OnStatEvent)
    end

    for _, event in pairs(EVENTS) do
        eventFrame:RegisterEvent(event)
    end
    for _, event in pairs(UNIT_EVENTS) do
        eventFrame:RegisterUnitEvent(event, 'player')
    end
end

CDM.TriggerTypes.stat.UnregisterEvents = function()
    eventFrame:UnregisterAllEvents()
end

-- Conditions --

-- Its value is secret in combat, so nothing compares it.
CDM.ConditionChecks.stat = {
    active = { type = 'bool', get = function() return true end },
}

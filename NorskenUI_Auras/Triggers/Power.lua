---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

--[[
The Power trigger: the player's power, a class resource split into pips, or a resource that isn't
a power type (Maelstrom Weapon, Stagger). Values only ever reach widgets, so a secret one still draws.
]]

local UnitPower, UnitPowerMax, UnitPowerMissing, UnitPowerType = UnitPower, UnitPowerMax, UnitPowerMissing, UnitPowerType
local UnitPartialPower, UnitPowerDisplayMod = UnitPartialPower, UnitPowerDisplayMod
local GetUnitChargedPowerPoints = GetUnitChargedPowerPoints
local tContains = tContains
local GetPowerRegenForPowerType = GetPowerRegenForPowerType
local GetSpecialization = GetSpecialization
local UnitPowerPercent = UnitPowerPercent
local GetRuneCooldown = GetRuneCooldown
local pairs, ipairs = pairs, ipairs
local UnitHealthMax = UnitHealthMax
local CreateFrame = CreateFrame
local GetTime = GetTime
local select = select

-- Plain for the player under every addon restriction (probed); the stub has no player exemption.
local UnitStagger = UnitStagger --[[@as fun(unit: 'player'): number]]

local huge = math.huge

local GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
local IsSpellKnown = C_SpellBook and C_SpellBook.IsSpellKnown
local NewTimer = C_Timer and C_Timer.NewTimer

local PowerType = Enum.PowerType

local powerLayers = {} ---@type table<CDMLayer, table> power layers -> their trigger

-- Power types --

-- Enhancement's Maelstrom Weapon is a buff's stacks, not a power type; it reads plain in combat.
local MAELSTROM_WEAPON = 'maelstromWeapon'
local MAELSTROM_WEAPON_AURA = 344179
local RAGING_MAELSTROM = 384143
CDM.MAELSTROM_WEAPON = MAELSTROM_WEAPON

-- Brewmaster Stagger against max health, as Blizzard's bar draws it.
local STAGGER = 'stagger'
local STAGGER_MODERATE, STAGGER_HEAVY = 0.3, 0.6 -- STAGGER_STATES in MonkStaggerBar.lua, live
CDM.STAGGER = STAGGER

-- These change with UNIT_AURA, never UNIT_POWER_*.
local AURA_POWER = {
    [MAELSTROM_WEAPON] = true,
    [STAGGER] = true,
}

-- What a power trigger can follow; 'primary' is whatever the current form or spec uses.
CDM.POWER_TYPES = {
    { value = 'primary',               text = L['Primary Power'] },
    { value = PowerType.Mana,          text = L['Mana'] },
    { value = PowerType.Rage,          text = L['Rage'] },
    { value = PowerType.Focus,         text = L['Focus'] },
    { value = PowerType.Energy,        text = L['Energy'] },
    { value = PowerType.RunicPower,    text = L['Runic Power'] },
    { value = PowerType.LunarPower,    text = L['Astral Power'] },
    { value = PowerType.Maelstrom,     text = L['Maelstrom'] },
    { value = MAELSTROM_WEAPON,        text = L['Maelstrom Weapon'] },
    { value = PowerType.Insanity,      text = L['Insanity'] },
    { value = PowerType.Fury,          text = L['Fury'] },
    { value = PowerType.ComboPoints,   text = L['Combo Points'] },
    { value = PowerType.HolyPower,     text = L['Holy Power'] },
    { value = PowerType.SoulShards,    text = L['Soul Shards'] },
    { value = PowerType.Chi,           text = L['Chi'] },
    { value = PowerType.ArcaneCharges, text = L['Arcane Charges'] },
    { value = PowerType.Essence,       text = L['Essence'] },
    { value = PowerType.Runes,         text = L['Runes'] },
    { value = STAGGER,                 text = L['Stagger'] },
}

-- Resources counted in whole points, which Automatic ticks split and a bar's Static or Progress mode draws one pip each.
CDM.SEGMENTED_POWER = {
    [PowerType.ComboPoints] = true,
    [PowerType.HolyPower] = true,
    [PowerType.SoulShards] = true,
    [PowerType.Chi] = true,
    [PowerType.ArcaneCharges] = true,
    [PowerType.Essence] = true,
    [PowerType.Runes] = true,
    [MAELSTROM_WEAPON] = true,
}
local SEGMENTED_POWER = CDM.SEGMENTED_POWER

-- Resources whose points can be supercharged, as Blizzard's combo point and Essence bars draw them.
CDM.CHARGED_POWER = {
    [PowerType.ComboPoints] = true,
    [PowerType.Essence] = true,
}

-- One of each, for "Each Rune" and the like.
CDM.PIP_NAMES = {
    [PowerType.ComboPoints] = L['Combo Point'],
    [PowerType.HolyPower] = L['Holy Power'],
    [PowerType.SoulShards] = L['Soul Shard'],
    [PowerType.Chi] = L['Chi'],
    [PowerType.ArcaneCharges] = L['Arcane Charge'],
    [PowerType.Essence] = L['Essence'],
    [PowerType.Runes] = L['Rune'],
    [MAELSTROM_WEAPON] = L['Stack'],
}

local POWER_NAMES = {}
for _, entry in ipairs(CDM.POWER_TYPES) do
    POWER_NAMES[entry.value] = entry.text
end
CDM.POWER_NAMES = POWER_NAMES

---@return number stacks, number max 10 with Raging Maelstrom, else 5
local function MaelstromWeapon()
    local aura = GetPlayerAuraBySpellID(MAELSTROM_WEAPON_AURA)
    return aura and aura.applications or 0, IsSpellKnown(RAGING_MAELSTROM) and 10 or 5
end

-- Split bars --

local runeOrder, runeRemaining = {}, {}
local RUNE_START_SLACK = 0.1 -- so a rune spent this frame never reads as queued

---Runes ready first, then by time left (RuneFrame.lua, live); rune timings are never secret.
---@return number[]
local function SortedRunes()
    local now = GetTime()
    for i = 1, 6 do
        local start, duration, ready = GetRuneCooldown(i)
        runeOrder[i] = i
        -- A rune waiting its turn has no start yet, so it sorts after every running one.
        local remaining = start and duration and duration > 0 and start + duration - now or huge
        -- One that ran out isn't ready until RUNE_POWER_UPDATE, so it must not sort ahead of the ready runes.
        runeRemaining[i] = ready and -1 or remaining > 0 and remaining or 0
    end

    for i = 2, 6 do
        local key, j = runeOrder[i], i - 1
        while j > 0 and runeRemaining[runeOrder[j]] > runeRemaining[key] do
            runeOrder[j + 1] = runeOrder[j]
            j = j - 1
        end
        runeOrder[j + 1] = key
    end
    return runeOrder
end

local PROGRESS_HOLD = 0.3 -- longest a filled progress pip waits for the power its swing grants
local SECRET_MAX_PIPS = 5 -- a split bar's pips while the resource's maximum reads secret
local essenceRate = 0.2   -- points a second, Blizzard's fallback in EssenceFramePlayer.lua; regen reads secret while stats are restricted

---The filling Essence's start and length, from its elapsed share in thousandths and the regen rate (EssenceFramePlayer.lua, live).
---@return number? start, number? length
local function EssenceFill()
    local partial = UnitPartialPower('player', PowerType.Essence)
    local rate = GetPowerRegenForPowerType(PowerType.Essence)
    if rate and not NRSKNUI:IsSecretValue(rate) and rate > 0 then
        essenceRate = rate
    end
    if NRSKNUI:IsSecretValue(partial) then return nil end

    local length = 1 / essenceRate
    return GetTime() - partial / 1000 * length, length
end

---Every pip of a split bar. A point pip gets an (N-1, N) range fed the whole value, so the widget does the compare and a secret count still draws.
---@param layer CDMLayer
---@param trigger table
local function UpdatePips(layer, trigger)
    local powerType, count, state = layer.powerType --[[@as Enum.PowerType]], layer.pipCount --[[@as number]], layer.state
    local progress = trigger.Mode == 'progress'
    state.recharging, state.waiting, state.charged = false, false, false
    layer.duration = nil

    if powerType == PowerType.Runes then
        local order, ready, now = SortedRunes(), 0, GetTime()
        for n = 1, count do
            local rune = order[n]
            local start, duration, isReady = GetRuneCooldown(rune)
            if isReady then
                ready = ready + 1
            end
            CDM:SetLayerPipSlot(layer, rune, n)
            local running = not isReady and start and duration and duration > 0
            -- Three runes regenerate at once; a queued one reports the start of its turn, still ahead.
            local waiting = not isReady and not (running and start <= now + RUNE_START_SLACK)
            layer.pips[rune].waiting = waiting
            state.waiting = state.waiting or waiting
            if progress and running then
                CDM:SetLayerPipTimer(layer, rune, start, duration)
            else
                CDM:SetLayerPipValue(layer, rune, isReady and 1 or 0, 1, 0, not isReady, running and start or nil, running and duration or nil)
            end
            state.recharging = state.recharging or not isReady
        end
        layer.value, layer.max = ready, count
        return
    end

    if powerType == MAELSTROM_WEAPON then
        local stacks, max = MaelstromWeapon()
        for n = 1, count do
            CDM:SetLayerPipValue(layer, n, stacks, n, n - 1, false)
        end
        layer.value, layer.max = stacks, max
        return
    end

    -- Soul Shards move in tenths: Progress feeds the unmodified value against a scaled range, so a partial shard fills.
    local mod = progress and UnitPowerDisplayMod(powerType) or 1
    if mod <= 0 then
        mod = 1
    end
    local value = UnitPower('player', powerType, progress)
    -- the player's charged points read plain in combat, same as UnitPower (probed)
    local charged = layer.readsCharged and GetUnitChargedPowerPoints('player')
    for n = 1, count do
        CDM:SetLayerPipValue(layer, n, value, n * mod, (n - 1) * mod, false)
        local isCharged = charged and tContains(charged, n) or false
        layer.pips[n].charged = isCharged
        state.charged = state.charged or isCharged
    end

    local current, max = UnitPower('player', powerType), UnitPowerMax('player', powerType)
    layer.value, layer.max = current, max
    if not progress then return end

    -- the next point's pip, which Essence and a progress source fill
    local filling = not NRSKNUI:IsSecretValue(current) and not NRSKNUI:IsSecretValue(max)
        and current < max and current < count and current + 1 or nil
    if filling and powerType == PowerType.Essence then
        local start, length = EssenceFill()
        if start then
            CDM:SetLayerPipTimer(layer, filling, start, length)
            state.recharging = true
        end
    end

    if trigger.ProgressCooldownID then
        layer.viewerHold = filling == nil
        local running = CDM:MirrorViewerBar(layer)
        -- The tracked bar ends a frame or so before the power it grants arrives; hold the fill full until then.
        local held = false
        if running then
            layer.progressPip, layer.progressHoldEnd = filling, nil
        elseif filling and layer.progressPip == filling then
            local now = GetTime()
            if not layer.progressHoldEnd then
                layer.progressHoldEnd = now + PROGRESS_HOLD
                if layer.progressHoldTimer then
                    layer.progressHoldTimer:Cancel()
                end
                layer.progressHoldTimer = NewTimer(PROGRESS_HOLD, function()
                    layer.progressHoldTimer = nil
                    CDM:UpdateLayer(layer)
                end)
            end
            held = now < layer.progressHoldEnd
            if held then
                local source = CDM:GetLayerProgress(layer)
                source:SetValue((source:GetMinMaxValues()))
            else
                layer.progressPip = nil
            end
        else
            layer.progressPip, layer.progressHoldEnd = nil, nil
        end
        local shown = filling ~= nil and (running or held)
        if shown then
            layer.pips[filling].recharging = true
        end
        CDM:ShowLayerProgress(layer, shown, filling and layer.pips[filling] or nil)
        state.recharging = state.recharging or shown
    end
end

-- Trigger --

CDM.TriggerTypes.power = {
    Value = true, -- %p is the value and %t the max, not a time
    IsKnown = function() return true end,

    ---@param layer CDMLayer
    ---@param trigger table
    Resolve = function(layer, trigger)
        local powerType = trigger.PowerType
        if powerType == nil or powerType == 'primary' then
            powerType = UnitPowerType('player')
        end
        layer.powerType = powerType
        layer.spellID, layer.baseSpellID = nil, nil
        layer.staggerBand = nil
        powerLayers[layer] = trigger
        -- only a Supercharged check reads the charged points, so nothing else pays for the table
        local display = layer.owner.id and CDM:Get(layer.owner.id)
        layer.readsCharged = CDM.CHARGED_POWER[powerType] and display and CDM:ConditionsUse(display, layer.index, 'charged') or nil
        if powerType == MAELSTROM_WEAPON then
            layer.max = select(2, MaelstromWeapon())
        elseif powerType == STAGGER then
            layer.max = UnitHealthMax('player')
        else
            layer.max = UnitPowerMax('player', powerType)
        end

        -- a split bar's pips and its progress source
        local plainMax = not NRSKNUI:IsSecretValue(layer.max)
        local split = layer.isBar and trigger.Mode ~= nil and SEGMENTED_POWER[powerType] == true
        if split then
            CDM:SetLayerPips(layer, powerType == PowerType.Runes and 6 or plainMax and layer.max or SECRET_MAX_PIPS)
        end
        if split and trigger.Mode == 'progress' and trigger.ProgressCooldownID then
            CDM:WatchViewerBar(layer, trigger.ProgressCooldownID, CDM:GetLayerProgress(layer))
        else
            CDM:ShowLayerProgress(layer, false)
        end

        -- automatic ticks between whole points
        local ticks
        local segments = split and layer.pipCount or SEGMENTED_POWER[powerType] and plainMax and layer.max or 0
        if segments > 1 then
            ticks = {}
            for i = 1, segments - 1 do
                ticks[i] = i / segments
            end
        end
        layer.autoTicks = ticks
        CDM:DrawTicks(layer)

        -- Power Color from the unit frames' palette; runes take their spec's color and Stagger paints its band in Update.
        CDM:SetIconTexture(layer, nil)
        local specIndex = GetSpecialization()
        if layer.owner.style.BarColorMode == 'power' and powerType ~= STAGGER then
            local runeColor = powerType == PowerType.Runes and specIndex and NRSKNUI.Colors.runes[specIndex]
            local maelstromColor = NRSKNUI.Colors.power[powerType == MAELSTROM_WEAPON and PowerType.Maelstrom]
            local powerColor = NRSKNUI.Colors.power[powerType]
            local color = runeColor or maelstromColor or powerColor
            if color then
                CDM:PaintBar(layer, { color:GetRGB() })
            end
        end
    end,

    ---@param layer CDMLayer
    ---@param style table
    Update = function(layer, style, trigger)
        local powerType = layer.powerType
        if (layer.pipCount or 0) > 0 then
            UpdatePips(layer, trigger)
            CDM:UpdateTexts(layer)
            return
        end

        if powerType == PowerType.Runes then
            -- Runes never fire UNIT_POWER_*; each rune reports its own cooldown instead (RuneFrame.lua, live).
            local ready = 0
            for i = 1, layer.max do
                if select(3, GetRuneCooldown(i)) then
                    ready = ready + 1
                end
            end
            layer.value = ready

            local fill = style.Inverse and layer.max - ready or ready
            local sparkAlpha = (fill > 0 and fill < layer.max) and 1 or 0

            CDM:SetLayerValue(layer, fill, layer.max, sparkAlpha)
            CDM:UpdateTexts(layer)
            return
        end

        if powerType == MAELSTROM_WEAPON then
            local stacks, max = MaelstromWeapon()
            layer.value = stacks
            layer.max = max

            local fill = style.Inverse and max - stacks or stacks
            local sparkAlpha = (fill > 0 and fill < max) and 1 or 0

            CDM:SetLayerValue(layer, fill, max, sparkAlpha)
            CDM:UpdateTexts(layer)
            return
        end

        if powerType == STAGGER then
            local stagger = UnitStagger('player') or 0
            local maxHealth = UnitHealthMax('player')
            layer.value = stagger
            layer.max = maxHealth

            local fill = style.Inverse and maxHealth - stagger or stagger
            local sparkAlpha = (fill > 0 and fill < maxHealth) and 1 or 0

            CDM:SetLayerValue(layer, fill, maxHealth, sparkAlpha)

            -- light, moderate or heavy, repainted only when the band changes
            local share = maxHealth > 0 and stagger / maxHealth or 0
            local band = share >= STAGGER_HEAVY and 3 or share >= STAGGER_MODERATE and 2 or 1
            if style.BarColorMode == 'power' and band ~= layer.staggerBand then
                layer.staggerBand = band
                CDM:PaintBar(layer, { NRSKNUI.Colors.stagger[band]:GetRGB() })
            end

            CDM:UpdateTexts(layer)
            return
        end

        ---@cast powerType Enum.PowerType
        layer.value = UnitPower('player', powerType)
        layer.max = UnitPowerMax('player', powerType)

        local fill = style.Inverse and UnitPowerMissing('player', powerType) or layer.value
        local sparkAlpha = UnitPowerPercent('player', powerType, false, NRSKNUI.curves.BarSparkAlpha) --[[@as number]]

        CDM:SetLayerValue(layer, fill, layer.max, sparkAlpha)
        CDM:UpdateTexts(layer)
    end,

    IsActive = function() return true end,
}

---@param trigger table
---@return string? name
CDM.TriggerTypes.power.Name = function(trigger)
    return POWER_NAMES[trigger.PowerType or 'primary']
end

---@param id string
CDM.TriggerTypes.power.Unwatch = function(id)
    for layer in pairs(powerLayers) do
        if layer.owner.id == id then
            powerLayers[layer] = nil
        end
    end
end

-- Events --

local powerFrame ---@type Frame?

-- A plain tick only moves the bar and its texts; a split bar's Recharging and Maelstrom Weapon's Stacks feed conditions, so those re-run them.
local function OnPowerEvent(_, event)
    local powerTrigger = CDM.TriggerTypes.power
    local aura = event == 'UNIT_AURA'

    for layer, trigger in pairs(powerLayers) do
        if layer.owner.shown and (AURA_POWER[layer.powerType] == true) == aura then
            -- a new max or display power can change the pips, ticks and Power Color
            if event ~= 'UNIT_POWER_FREQUENT' and event ~= 'RUNE_POWER_UPDATE' and event ~= 'UNIT_POWER_POINT_CHARGE' and not aura then
                powerTrigger.Resolve(layer, trigger)
            end
            if (layer.pipCount or 0) > 0 or layer.powerType == MAELSTROM_WEAPON then
                CDM:UpdateLayer(layer)
            else
                powerTrigger.Update(layer, layer.owner.style, trigger)
            end
        end
    end
end

local POWER_EVENTS = {
    'UNIT_POWER_FREQUENT',
    'UNIT_MAXPOWER',
    'UNIT_DISPLAYPOWER',
    'UNIT_POWER_POINT_CHARGE',
    'UNIT_AURA',
}

CDM.TriggerTypes.power.RegisterEvents = function()
    if not powerFrame then
        powerFrame = CreateFrame('Frame')
        powerFrame:SetScript('OnEvent', OnPowerEvent)
    end

    for _, event in ipairs(POWER_EVENTS) do
        powerFrame:RegisterUnitEvent(event, 'player')
    end
    powerFrame:RegisterEvent('RUNE_POWER_UPDATE')
end

CDM.TriggerTypes.power.UnregisterEvents = function()
    powerFrame:UnregisterAllEvents()
end

-- Conditions --

-- The value can be secret, so nothing compares it but the game's curve on a %p text; a split bar's Recharging and Supercharged are plain and per pip for Bar Color.
-- Maelstrom Weapon's stacks are the one plain value, so only its trigger offers Stacks.
CDM.ConditionChecks.power = {
    active     = { type = 'bool', get = function() return CDM.TriggerTypes.power.IsActive() end },
    stacks     = { type = 'number', get = function(layer) return layer.powerType == MAELSTROM_WEAPON and layer.value or 0 end },
    percent    = { type = 'number', curve = true },
    value      = { type = 'number', curve = true }, -- turned into a percent of the max, so it waits for a max that reads plain
    recharging = {
        type = 'bool',
        get = function(layer, _, pip)
            if pip then
                return pip.recharging == true
            end
            return layer.state.recharging == true
        end,
    },
    waiting    = {
        type = 'bool',
        get = function(layer, _, pip)
            if pip then
                return pip.waiting == true
            end
            return layer.state.waiting == true
        end,
    },
    charged    = {
        type = 'bool',
        get = function(layer, _, pip)
            if pip then
                return pip.charged == true
            end
            return layer.state.charged == true
        end,
    },
}

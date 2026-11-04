---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local CreateFrame = CreateFrame
local gsub = string.gsub
local ipairs, pairs = ipairs, pairs
local next = next
local unpack = unpack
local max = math.max
local setmetatable = setmetatable
local GetSpellName = C_Spell and C_Spell.GetSpellName

local PANDEMIC_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\AuraOverlay.png'
local PANDEMIC_COLOR = { 1, 0.25, 0.25, 1 }
CDM.PANDEMIC_TEXTURE = PANDEMIC_TEXTURE
local AURA_FILTERS = { player = 'HELPFUL', target = 'HARMFUL' } -- spellID matching only holds for buffs on friends and debuffs on enemies
local TEXT_KINDS = { 'time', 'count', 'static', 'sourcedText' } -- the fontstrings an aura button's text frame can hold

local ExpandText, ConfigureText, DurationFormat, PlaceText = CDM.Text.Expand, CDM.Text.Configure, CDM.Text.DurationFormat, CDM.Text.Place
local LITERAL_PERCENT, TIME_SCALES = CDM.Text.LITERAL_PERCENT, CDM.Text.TIME_SCALES
local StyleBorders, LevelElements, ElementEnabled = CDM.Layer.StyleBorders, CDM.Layer.LevelElements, CDM.Layer.ElementEnabled
local ApplyTexCoords = CDM.ApplyTexCoords

--[[
An aura trigger draws through a one-slot native AuraContainer: the client shows the slot while the
aura is up, so we never touch anything secret and the layer simply covers the triggers below it.
]]

-- Target --

local targetContainers = {} ---@type table<table, true> containers following the target
local targetWatcher ---@type Frame?

-- The container doesn't follow target changes on its own (Blizzard_AuraContainer.lua, live).
local function OnTargetChanged()
    for container in pairs(targetContainers) do
        container:UpdateUnitGate()
        container:UpdateAllAuras()
    end
end

---Listen for target changes only while some container follows the target.
---@param container table
---@param follows boolean
local function FollowTarget(container, follows)
    targetContainers[container] = follows or nil

    if next(targetContainers) then
        if not targetWatcher then
            targetWatcher = CreateFrame('Frame')
            targetWatcher:SetScript('OnEvent', OnTargetChanged)
        end
        targetWatcher:RegisterEvent('PLAYER_TARGET_CHANGED')
    elseif targetWatcher then
        targetWatcher:UnregisterEvent('PLAYER_TARGET_CHANGED')
    end
end

-- Button --

-- AddSlot only returns a secret-wrapped button; this is the one place we get the real one, so it all goes into refs.
---@param button table native AuraButton
---@param host Frame
---@param refs table
---@param style table the icon's style; in a chain group the host's own size reads back secret
local function InitAuraButton(button, host, refs, style)
    -- Top-left with its own size, so a chain group can measure it; it collapses to nothing while hidden.
    button:SetPoint('TOPLEFT', host, 'TOPLEFT')
    button:SetSize(style.Width, style.Height)
    button:SetCollapsesLayout(true)
    button:EnableMouse(false)
    refs.button = button

    -- The icon's own area; the button may be wider by a chain group's spacing.
    local inner = CreateFrame('Frame', nil, button)
    inner:SetPoint('TOPLEFT', button, 'TOPLEFT')
    inner:SetSize(style.Width, style.Height)
    refs.inner = inner

    local icon = button:CreateTexture(nil, 'ARTWORK')
    icon:SetAllPoints(inner)
    icon:NUISetPixelSnap() -- snaps like the borders around it, so they still line up when a chain lands on a half pixel
    refs.icon = icon
    button:SetIcon(icon)

    local cooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(true)
    refs.cooldown = cooldown
    button:SetDurationCooldown(cooldown)

    -- The pandemic border right over the swipe; the sub elements above it get their levels in list order when styled.
    local base = cooldown:GetFrameLevel()
    local borderHost = CreateFrame('Frame', nil, button)
    borderHost:SetAllPoints(inner)
    borderHost:SetFrameLevel(base + 1)
    refs.borderHost = borderHost
    refs.borders = {}

    local textHost = CreateFrame('Frame', nil, button)
    textHost:SetAllPoints(inner)
    textHost:SetFrameLevel(base + 1)
    refs.textHost = textHost
    refs.textHosts = {}
    refs.sourced = {}

    local pandemicHost = CreateFrame('Frame', nil, button)
    pandemicHost:SetAllPoints(inner)
    pandemicHost:SetFrameLevel(base + 1)
    local pandemic = pandemicHost:CreateTexture(nil, 'OVERLAY')
    pandemic:SetTexture(PANDEMIC_TEXTURE)
    pandemic:NUISetPixelInside(inner) -- the same inset SkinAuraButton gives this texture on debuffs
    pandemic:SetVertexColor(unpack(PANDEMIC_COLOR))
    refs.pandemic = pandemic
    button:AddPandemicRegion(pandemic)
end

---@param fs FontString
---@param element table
---@param button table
local function StyleAuraText(fs, element, button)
    fs:SetFontStyle(element, element.FontSize, nil, nil, true)
    PlaceText(fs, element, button)
    fs:SetTextColor(unpack(element.Color))
end

-- Styling --

---The texts an aura's button leaves empty: it has one time and one count, which go to the first text asking
---for each, in the order StyleAuraButton hands them out. A text reading another trigger takes neither.
---@param display table
---@return table<table, true> dropped text elements
function CDM:DroppedAuraTexts(display)
    local dropped = {}
    for index, trigger in ipairs(display.Triggers or {}) do
        if trigger.Type == 'aura' or trigger.Type == 'auraoverlay' then
            local hasTime, hasCount = false, false
            for _, element in ipairs(display.SubRegions or {}) do
                if element.type == 'text' and element.Enabled then
                    local isDuration, isCount, source = self:ClassifyText(element.Text or '')
                    if source == nil or source == index then
                        if isDuration and hasTime or not isDuration and isCount and hasCount then
                            dropped[element] = true
                        end
                        hasTime = hasTime or isDuration
                        hasCount = hasCount or (isCount and not isDuration)
                    end
                end
            end
        end
    end

    return dropped
end

---Style the slot on show from the icon's style and its sub elements: the first %p/%t text becomes the
---native duration text, the first %s text its stack count, the rest stay plain.
---@param layer CDMLayer
---@param trigger table
function CDM:StyleAuraButton(layer, trigger)
    local refs = layer.auraRefs
    local style = layer.owner.style
    local display = layer.owner.id and self:Get(layer.owner.id)
    if not (refs and refs.button and style and display) then return end
    local button = refs.button

    -- A lone aura is the icon itself; an overlay draws only what its While Up conditions put on it, never a border.
    local active, pandemicColor, pandemic = self:GetAuraConditionChanges(display, layer.index)
    local overlay = trigger.Type == 'auraoverlay'
    local isBar = display.type == 'bar' and not overlay
    local showIcon = active.auraIcon == true
    if not overlay then
        showIcon = self:ShowsIcon(layer, style, display)
    end

    local subRegions = layer.subRegions or {}
    if overlay then
        local list = {}
        for n, element in ipairs(subRegions) do
            local own = element.type == 'glow' or element.type == 'text'
            list[n] = setmetatable({
                Enabled = own and active['sub.' .. n .. '.visible'] == true,
                Color = active['sub.' .. n .. '.color'] or element.Color,
            }, { __index = element })
        end
        subRegions = list
    end

    local color, desaturate, swipe, reverse = style.Color, style.Desaturate, style.DrawSwipe, style.Reverse
    if overlay then
        color = active.auraColor or color
        if active.auraDesaturate ~= nil then
            desaturate = active.auraDesaturate
        end
        if active.auraSwipe ~= nil then
            swipe = active.auraSwipe
        end
        if active.auraInverse ~= nil then
            reverse = active.auraInverse
        end
    end

    local textParent = refs.inner
    if isBar then
        textParent = self:StyleAuraBar(layer, button, refs, style, trigger)
        swipe = false
        self:SetStackTicks(layer, trigger)
        self:StyleAuraTicks(layer, refs, subRegions)
    else
        self:ClearAuraBar(button, refs)
    end

    local icon = refs.icon
    ApplyTexCoords(icon, style)
    icon:SetVertexColor(unpack(color))
    icon:SetDesaturated(desaturate == true)
    local spellID = self:GetTriggerSpell(trigger)
    -- An overlay's icon is the aura's own unless its While Up picks one; the icon's Icon Source belongs to the icon below it.
    local iconTexture = overlay and active.auraTexture or (not overlay and style.IconSource == 'manual' and style.ManualIcon)
    -- The button overrides the alpha of an icon it holds, so a hidden icon is taken off the button entirely.
    icon:SetShown(showIcon)
    if not showIcon then
        button:ClearIcon()
    elseif iconTexture then
        button:ClearIcon()
        icon:SetTexture(iconTexture)
    else
        button:SetIcon(icon)
    end

    local cooldown = refs.cooldown
    cooldown:SetDrawSwipe(swipe and showIcon)
    cooldown:SetDrawEdge(style.DrawEdge and showIcon and not isBar)
    cooldown:SetReverse(reverse == true)
    cooldown:SetSwipeColor(unpack(style.SwipeColor))
    cooldown:SetHideCountdownNumbers(not self:ShowsTimerText(layer, style) or not showIcon or isBar)
    self:StyleTimerText(cooldown, style)

    refs.pandemic:SetAlpha(pandemicColor and 1 or 0)
    if pandemicColor then
        refs.pandemic:SetVertexColor(unpack(pandemicColor))
    end

    local spellName = spellID and GetSpellName(spellID) or ''
    local hasTime, hasCount, sourcedCount, ordinal = false, false, 0, 0
    -- Each text draws from its own frame, at its place in the list. The button denies reparenting its fontstrings
    -- (forbidden aspect ChangeParent), so every text frame makes its own and the button is pointed at the one in use.
    local function Text(entry, key)
        if not entry[key] then
            entry[key] = entry.host:CreateFontString(nil, 'OVERLAY')
        end
        return entry[key]
    end

    for _, element in ipairs(subRegions) do
        if element.type == 'text' then
            ordinal = ordinal + 1
            local entry = refs.textHosts[ordinal]
            if not entry then
                local host = CreateFrame('Frame', nil, refs.textHost)
                host:SetAllPoints(refs.inner)
                entry = { host = host }
                refs.textHosts[ordinal] = entry
            end
            for _, key in ipairs(TEXT_KINDS) do
                if entry[key] then
                    entry[key]:Hide()
                end
            end
            if entry.sourced and entry.sourced.binding then
                entry.sourced.binding:SetToDefaults()
            end

            if element.Enabled then
                local raw = ExpandText(element, spellName, self:GetTriggerTexture(trigger), display.Triggers)
                local isDuration, isCount, source = self:ClassifyText(raw)
                if source == layer.index then
                    source = nil
                end
                local sourceType = source and display.Triggers[source] and self.TriggerTypes[display.Triggers[source].Type]
                if source and (isDuration or isCount) then
                    -- Another trigger's time or charges, fed by UpdateTexts; only a non-aura trigger has any to give.
                    if sourceType and not sourceType.Secret then
                        local fs = Text(entry, 'sourcedText')
                        entry.sourced = entry.sourced or { fs = fs, kind = 'static', format = '', tokens = 0, ordinal = ordinal }
                        sourcedCount = sourcedCount + 1
                        refs.sourced[sourcedCount] = entry.sourced
                        StyleAuraText(fs, element, textParent)
                        ConfigureText(entry.sourced, element, spellName, layer, display.Triggers)
                        fs:Show()
                    end
                elseif isDuration and not hasTime then
                    hasTime = true
                    local fs = Text(entry, 'time')
                    StyleAuraText(fs, element, textParent)
                    local format, components = DurationFormat(raw, element)
                    local curve = self:TextColorCurve(display, layer.index, TIME_SCALES, ordinal, element.Color)
                    button:SetDurationText(fs, {
                        textFormat = { formatString = format, components = components },
                        textColor = curve and { curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration } or nil,
                    })
                    fs:Show()
                elseif isCount and not hasCount and not isDuration then
                    hasCount = true
                    local fs = Text(entry, 'count')
                    StyleAuraText(fs, element, textParent)
                    button:SetApplicationCount(fs, { formatter = self:StackCountFormatter(display, layer.index, ordinal) })
                    fs:Show()
                elseif not isDuration and not isCount then
                    local fs = Text(entry, 'static')
                    StyleAuraText(fs, element, textParent)
                    fs:SetText((gsub(raw, LITERAL_PERCENT, '%%')))
                    fs:Show()
                end
            end
        end
    end
    -- Text frames past the current list stay hidden.
    for i = ordinal + 1, #refs.textHosts do
        local entry = refs.textHosts[i]
        for _, key in ipairs(TEXT_KINDS) do
            if entry[key] then
                entry[key]:Hide()
            end
        end
    end

    if not hasTime then
        button:ClearDurationText()
    end
    if not hasCount then
        button:ClearApplicationCount()
    end
    for i = sourcedCount + 1, #refs.sourced do
        refs.sourced[i] = nil
    end
    refs.sourcedCount = sourcedCount
    layer.auraSourced = sourcedCount > 0
    if sourcedCount > 0 then
        self:UpdateTexts(layer)
    end

    StyleBorders(refs.borders, refs.borderHost, refs.inner, subRegions)

    -- In a chain group the size comes from the style, since reading it back would be secret: the icon's area,
    -- plus the chain's spacing on the button. Anywhere else it fills its frame, which a matched bar stretches to fit.
    local inner = refs.inner
    button:ClearAllPoints()
    inner:ClearAllPoints()
    button:SetPoint('TOPLEFT', layer.auraHost, 'TOPLEFT')
    inner:SetPoint('TOPLEFT', button, 'TOPLEFT')
    if layer.owner.chainGroup then
        local pad = layer.owner.chainPad
        local padX, padY = pad and pad[1] or 0, pad and pad[2] or 0
        inner:SetSize(style.Width, style.Height)
        button:SetSize(style.Width + padX, style.Height + padY)
    else
        button:SetPoint('BOTTOMRIGHT', layer.auraHost, 'BOTTOMRIGHT')
        inner:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT')
    end

    -- Glow sub elements inside the button: shown ones appear with the aura, pandemic ones only in its window.
    local width, height = style.Width, style.Height
    local function Host()
        local host = CreateFrame('Frame', nil, button)
        host:SetAllPoints(refs.inner)
        host:SetFrameLevel(refs.borderHost:GetFrameLevel() + 1)
        return host
    end
    refs.glows = refs.glows or {}
    refs.pandemicGlows = refs.pandemicGlows or {}
    self:StyleGlows(refs.glows, Host, subRegions, width, height, ElementEnabled)
    self:StyleGlows(refs.pandemicGlows, Host, subRegions, width, height, function(index)
        return pandemic['sub.' .. index .. '.visible'] == true
    end, function(texture) button:AddPandemicRegion(texture) end)

    local base = refs.cooldown:GetFrameLevel() + 1
    local listLevel = overlay and layer.levelOf
    local function LevelOf(n)
        if listLevel then
            return max(base + 1, listLevel(n)) -- never under its own swipe and pandemic border
        end
        return base + n
    end
    LevelElements(subRegions, refs.borders, refs.glows, refs.textHosts, LevelOf)
    LevelElements(subRegions, {}, refs.pandemicGlows, {}, LevelOf)

    if display.type == 'bar' and overlay then
        refs.barOverlay = refs.barOverlay or {}
        self:PaintBarOverlay(layer, refs.barOverlay, button, active)
    end
end

-- Slots --

---Point a layer's aura slot at its trigger; builds the container on first use. Out of combat only.
---@param layer CDMLayer
---@param trigger table
---@param spellIDs table<number, true>
function CDM:ConfigureAuraLayer(layer, trigger, spellIDs)
    local unit = trigger.Unit == 'target' and 'target' or 'player'
    local filter = AURA_FILTERS[unit] .. (trigger.OwnOnly and '|PLAYER' or '') -- the token Blizzard's own viewer filters casters with
    local candidates = { includeSpellIDs = spellIDs }

    if not layer.auraHost then
        layer.auraHost = CreateFrame('Frame', nil, layer)
        layer.auraHost:SetAllPoints()
        layer.auraContainer = layer.auraHost:CreateAuraContainer({ disableMouse = true })
        layer.auraSlots = {}
    end
    local container = layer.auraContainer
    layer.auraHost:SetShown(not (self.previewing and layer.owner.shown))

    layer.auraTrigger = trigger
    local slot = layer.auraSlots[filter]
    if slot then
        container:SetSlotCandidates(slot.index, candidates)
    else
        local host, refs = layer.auraHost, {}
        layer.auraRefs = refs -- AddSlot can create the first button right away
        local _, _, index = container:AddSlot(filter, {
            candidateFilters = candidates,
            -- Blizzard restricts a button only after this runs, so it is styled here, in an M+ key too.
            initializeFrame = function(created)
                InitAuraButton(created, host, refs, layer.owner.style)
                if layer.auraRefs ~= refs then return end
                local chain = layer.owner.chainGroup
                if chain then
                    chain:WatchAuraButton(layer.owner.id, created)
                end
                self:StyleAuraButton(layer, layer.auraTrigger)
            end,
        })
        slot = { refs = refs, index = index }
        layer.auraSlots[filter] = slot
    end

    -- Only the slot for the current filter shows.
    for key, other in pairs(layer.auraSlots) do
        container:SetSlotShown(other.index, key == filter)
    end
    layer.auraRefs = slot.refs
    -- A button that already exists denies tainted access while auras are secret (DenyTaintedAccessWhenAurasAreSecret).
    local accessible = not NRSKNUI:AreAurasSecret()
    local chain = layer.owner.chainGroup
    if accessible and chain and slot.refs.button then
        chain:WatchAuraButton(layer.owner.id, slot.refs.button)
    end

    container:SetEnabled(true)
    container:SetUnit(unit)
    container:UpdateUnitGate()
    container:UpdateAllAuras()
    FollowTarget(container, unit == 'target')

    if accessible then
        self:StyleAuraButton(layer, trigger)
    end
end

---Stop a layer's aura container when its trigger is no longer an aura or its icon goes back to the pool.
---@param layer CDMLayer
function CDM:ReleaseAuraLayer(layer)
    local container = layer.auraContainer
    if not container then return end

    layer.auraHost:Hide()
    layer.auraKey = nil
    FollowTarget(container, false)
    -- One function per layer: RunWhenSafe drops a repeat, so re-resolving in combat never grows the queue.
    layer.disableAura = layer.disableAura or function()
        if not layer.auraKey then
            container:SetEnabled(false)
        end
    end
    NRSKNUI:RunWhenSafe(layer.disableAura)
end

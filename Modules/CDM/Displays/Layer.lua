---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local CreateObjectPool = CreateObjectPool
local CreateFrame = CreateFrame
local ipairs = ipairs
local unpack = unpack
local min = math.min
local tsort = table.sort

local GameTooltip = GameTooltip

local OVERLAY_LEVELS = 6 -- an aura overlay's layer, aura host, container, button, its swipe and pandemic border, before its elements
CDM.GLOW_LEVEL = 3       -- a glow's level above its layer

local Text = CDM.Text
local AcquireText, PlaceText, ConfigureText, TEXT_PINS = Text.Acquire, Text.Place, Text.Configure, Text.PINS

---One trigger's visuals; the icon stacks one per trigger, trigger 1 on top.
---@class CDMBorder : Frame
---@field edges Texture[] top, bottom, left, right
---@field eachPip boolean? hidden for its copies on every pip of a split bar

---@class CDMLayer : Frame
---@field owner CDMIcon
---@field Icon Texture
---@field Cooldown Cooldown
---@field textHost Frame
---@field borderHost Frame the border sub elements; hidden with the icon on an aura layer, which draws its own
---@field texts CDMIconText[]
---@field borders CDMBorder[] one per border sub element
---@field glows CDMGlow[] one per glow sub element, shown by its Enabled or a condition
---@field textCount number? texts in use, the rest of the pool is hidden
---@field sourced boolean? a text reads another trigger, so it updates after every trigger has
---@field auraSourced boolean? the same, for texts inside the aura button
---@field state table trigger state the conditions read
---@field duration LuaDurationObject? what time texts count, without the global cooldown
---@field spellID number?
---@field baseSpellID number?
---@field itemID number? item triggers: the item shown
---@field itemSlot number? item triggers: the equipment slot read
---@field itemFamily number[]? item triggers: the items counted together
---@field itemDuration LuaDurationObject? item triggers: built from plain cooldown numbers
---@field readyDuration LuaDurationObject? zero, handed to texts for ready (a cast lockout)
---@field realCooldown LuaDurationObject? spell triggers: a copy of the running cooldown, shown on while a GCD outlasts it
---@field heldGCD number? spell triggers: the GCD that overtook realCooldown, which shows until it ends
---@field count number? a count to show for %s instead of spell charges
---@field timerLength number? cast timers: the configured duration
---@field timerEnd number? cast timers: when the running timer ends
---@field timerDuration LuaDurationObject? cast timers: built from the cast time
---@field timerTicker table? cast timers: wakes the icon when the timer ends
---@field previewEnd number? options preview: when the looping fake timer ends
---@field previewDuration LuaDurationObject? options preview: the fake timer
---@field previewPandemic Texture? options preview: an aura layer's stand-in pandemic border
---@field previewPandemicTimer table? options preview: shows that border when the fake timer reaches it
---@field endTime number? item and cast timers: when the running cooldown or timer ends, for remaining checks
---@field index number? this layer's trigger index
---@field levelOf fun(n: number): number? the frame level of sub element n on this layer, from its place in the list
---@field subRegions table[]? the sub elements the layer was last styled with
---@field auraHost Frame? parent of the aura container, for aura triggers
---@field auraContainer table? native AuraContainer with the NorskenUI mixin
---@field auraSlots table<string, { refs: table, index: number }>? one slot per filter string
---@field auraRefs table? the slot on show: its button and the regions we gave it
---@field auraTrigger table? the trigger that slot shows
---@field auraKey string? what the slot was last configured for
---@field disableAura fun()? turns the container off once safe; one per layer so the combat queue holds it once
---@field applyAura fun()? the aura trigger's latest pending setup
---@field runAura fun()? runs applyAura once safe; one per layer so the combat queue holds it once
---@field restyleAura fun()? the latest restyle waiting for auras to stop being secret
---@field restyleQueued boolean? that restyle is already in the restriction queue
---@field isBar boolean? the layer belongs to a bar display
---@field isText boolean? the layer belongs to a text display: no icon, its text pinned at its alignment
---@field statGates CDMStatGate[]? Highest/Lowest Secondary: one gate per candidate stat, which the engine opens for the winner
---@field overlayProxies table<string, Frame[]>? bar aura overlays: per part, frames riding the fills of the bar below
---@field previewOverlay table<string, Texture[]>? bar aura overlays: the options preview's parts
---@field previewOverlayShown boolean? those parts are up
---@field shownName string? cast layers: the spell name its %n texts were last given
---@field barColor number[]? bar displays: the colour the trigger or style last painted
---@field barColorOverride number[]? bar displays: a condition's colour, held over the trigger's
---@field powerType number? power layers: the power type read
---@field progress { source: StatusBar, fill: Texture?, bar: StatusBar? }? split power bars: a tracked bar's progress in the filling pip
---@field pips CDMPip[]? split power bars: one bar per rune or point, the rest of the pool hidden
---@field pipEdges StatusBar[]? split power bars: invisible fills whose edges part the pips
---@field pipCount number? split power bars: pips in use, 0 for one bar
---@field pipsStyled boolean? the pips match the layer's current style
---@field pipLayout { corners: string[], dx: number, dy: number, share: number }? split power bars: how a pip sits between its boundaries
---@field barLength number? bar displays: the bar's long side, without the icon
---@field viewerCooldownID number? the Cooldown Manager tracked bar followed
---@field viewerChild table? its live Blizzard frame
---@field viewerActive boolean? whether it is running
---@field viewerSpellID number?
---@field viewerTarget StatusBar? where it is mirrored, when not the layer's own bar
---@field viewerHold boolean? mirroring paused while no pip is filling
---@field progressPip number? split power bars: the pip the tracked bar was last filling
---@field progressHoldEnd number? when a finished tracked bar's held fill gives up on the power arriving
---@field progressHoldTimer table? re-evaluates once the hold ends
---@field castHoldTimer table? cast layers: ends the hold after a finished cast
---@field barThickness number? bar displays: the bar's cross size, a tick's automatic length
---@field tickSets CDMTickSet[]? bar displays: one per tick sub element
---@field autoTicks number[]? bar displays: where the trigger puts Automatic ticks
---@field Bar CDMBar? bar displays: the status bar beside the icon
---@field value number? value triggers: what %p shows
---@field max number? value triggers: what %t shows

---@class CDMIcon : Frame
---@field id string?
---@field layers CDMLayer[]
---@field layerCount number layers in use
---@field activeLayer CDMLayer? the logic layer on show, for the tooltip
---@field hasActive boolean? a trigger is active, or an aura layer may be
---@field standbyLayer CDMLayer? a layer that is hidden but ready, which a condition's Show Display brings up
---@field forceHidden boolean? a condition's Show Display is off
---@field chainGroup CDMChainGroup? the chain group the icon sits in
---@field chainPad number[]? that group's spacing, padding the icon's measured size
---@field style table the icon's style, see CDM:GetStyle
---@field shown boolean loaded or previewed
---@field groupId string?
---@field placeholder boolean? a lone aura showing its placeholder, which holds its place while the aura is missing
---@field fitsText boolean? a text display sizing itself to its text each frame
---@field fitProbes Frame[]? the two corners of the measured text
---@field fitText FontString? the text those corners ride

---@param layer CDMLayer
local function OnCooldownDone(layer)
    layer.heldGCD = nil
    local id = layer.owner.id
    if id then CDM:UpdateIcon(id) end
end

---@param frame CDMIcon
local function OnEnter(frame)
    local layer = frame.activeLayer
    local spellID = layer and (layer.spellID or layer.viewerSpellID)
    if not (frame.style and frame.style.Tooltip and layer and (spellID or layer.itemID)) then return end
    GameTooltip:SetOwner(frame, 'ANCHOR_RIGHT')
    if spellID then
        GameTooltip:SetSpellByID(spellID)
    else
        GameTooltip:SetItemByID(layer.itemID)
    end
    GameTooltip:Show()
end

---@param frame CDMIcon
---@return CDMLayer
local function CreateLayer(frame)
    local layer = CreateFrame('Frame', nil, frame) --[[@as CDMLayer]]
    layer:SetAllPoints()
    layer.owner = frame

    local icon = layer:CreateTexture(nil, 'ARTWORK')
    icon:SetAllPoints()
    icon:NUISetPixelSnap()
    layer.Icon = icon

    local cooldown = CreateFrame('Cooldown', nil, layer, 'CooldownFrameTemplate')
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawBling(false)
    cooldown:SetCountdownFormatter(NRSKNUI:GetAuraDurationFormatter())
    cooldown:SetScript('OnCooldownDone', function() OnCooldownDone(layer) end)
    layer.Cooldown = cooldown

    local textHost = CreateFrame('Frame', nil, layer)
    textHost:SetAllPoints()
    layer.textHost = textHost

    local borderHost = CreateFrame('Frame', nil, layer)
    borderHost:SetAllPoints()
    layer.borderHost = borderHost

    layer.texts = {}
    layer.borders = {}
    layer.glows = {}
    layer.state = {}
    return layer
end

---@return CDMIcon
local function CreateIcon()
    local frame = CreateFrame('Frame', nil, UIParent) --[[@as CDMIcon]]
    frame:Hide()

    frame.layers = {}
    frame.layerCount = 0
    frame:SetScript('OnEnter', OnEnter)
    frame:SetScript('OnLeave', GameTooltip_Hide)

    return frame
end

---@param frame CDMIcon
local function ResetIcon(_, frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(UIParent)
    for _, layer in ipairs(frame.layers) do
        CDM:SetLayerTimer(layer, nil)
        layer.duration = nil
        layer.state = {}
        layer.realCooldown, layer.heldGCD = nil, nil
        layer.timerEnd = nil
        layer.previewEnd = nil
        if layer.timerTicker then
            layer.timerTicker:Cancel()
            layer.timerTicker = nil
        end
        CDM:ReleaseAuraLayer(layer)
    end
    CDM:ResetConditions(frame)
    frame.activeLayer = nil
    frame.id = nil
end

local pool = CreateObjectPool(CreateIcon, ResetIcon)

---@param id string
---@return CDMIcon
function CDM:AcquireIcon(id)
    local frame = pool:Acquire()
    frame.id = id
    return frame
end

---@param frame CDMIcon
function CDM:ReleaseIcon(frame)
    pool:Release(frame)
end

-- Border --

-- Edge textures rather than a Backdrop: an icon in a chain group or an aura button reads back a secret size, which Backdrop does arithmetic on.
local EDGES = {
    { 'TOPLEFT',    'TOPRIGHT',    'height' },
    { 'BOTTOMLEFT', 'BOTTOMRIGHT', 'height' },
    { 'TOPLEFT',    'BOTTOMLEFT',  'width' },
    { 'TOPRIGHT',   'BOTTOMRIGHT', 'width' },
}

---@param border CDMBorder? nil makes one on `host`
---@param host Frame
---@param anchor table what it outlines
---@param element table
---@param engineSnap boolean? keep Blizzard's pixel snap, for an outline on edges the engine places
---@return CDMBorder
local function StyleBorder(border, host, anchor, element, engineSnap)
    if not border then
        border = CreateFrame('Frame', nil, host) --[[@as CDMBorder]]
        border.edges = {}
        for i, edge in ipairs(EDGES) do
            local texture = border:CreateTexture(nil, 'OVERLAY')
            texture:NUISetPixelPoint(edge[1], border, edge[1], 0, 0)
            texture:NUISetPixelPoint(edge[2], border, edge[2], 0, 0)
            if not engineSnap then texture:NUISetPixelSnap() end
            border.edges[i] = texture
        end
    end

    local offset, size = element.Offset or 0, element.Size or 1
    border:ClearAllPoints()
    border:NUISetPixelPoint('TOPLEFT', anchor, 'TOPLEFT', -offset, offset)
    border:NUISetPixelPoint('BOTTOMRIGHT', anchor, 'BOTTOMRIGHT', offset, -offset)
    for i, texture in ipairs(border.edges) do
        if EDGES[i][3] == 'height' then texture:NUISetPixelHeight(size) else texture:NUISetPixelWidth(size) end
        texture:SetColorTexture(unpack(element.Color))
    end
    border:SetShown(element.Enabled)
    return border
end

---@param borders CDMBorder[]
---@param host Frame
---@param anchor table what they outline
---@param subRegions table[]
local function StyleBorders(borders, host, anchor, subRegions)
    local count = 0
    for _, element in ipairs(subRegions) do
        if element.type == 'border' then
            count = count + 1
            borders[count] = StyleBorder(borders[count], host, anchor, element)
        end
    end
    for i = count + 1, #borders do borders[i]:Hide() end
end

---Put each sub element's frame at its level, `levelOf(n)` for element n: WeakAuras' draw order, later on top.
---@param subRegions table[]
---@param borders Frame[]
---@param glows CDMGlow[]
---@param texts table[] anything with a `host` frame, by text ordinal
---@param levelOf fun(n: number): number
---@param tickSets CDMTickSet[]? a bar layer's ticks, by tick ordinal
local function LevelElements(subRegions, borders, glows, texts, levelOf, tickSets)
    local b, g, t, k = 0, 0, 0, 0
    for n, element in ipairs(subRegions) do
        if element.type == 'tick' then
            k = k + 1
            local set = tickSets and tickSets[k]
            if set then
                set.level = levelOf(n)
                for _, host in ipairs(set.hosts) do host:SetFrameLevel(set.level) end
            end
        elseif element.type == 'border' then
            b = b + 1
            if borders[b] then borders[b]:SetFrameLevel(levelOf(n)) end
        elseif element.type == 'glow' then
            g = g + 1
            if glows[g] then glows[g].host:SetFrameLevel(levelOf(n)) end
        elseif element.type == 'text' then
            t = t + 1
            if texts[t] then texts[t].host:SetFrameLevel(levelOf(n)) end
        end
    end
end

-- Style --

---@param layer CDMLayer
---@param style table
---@param subRegions table[]
---@param spellName string
local function StyleLayer(layer, style, subRegions, spellName, triggers)
    CDM:StyleIconParts(layer, style)

    layer.subRegions = subRegions
    layer.sourced = false
    layer.shownName = nil
    local textCount = 0
    for _, element in ipairs(subRegions) do
        if element.type == 'text' then
            textCount = textCount + 1
            local fs = AcquireText(layer, textCount).fs
            fs:SetFontStyle(element, element.FontSize, nil, nil, true)
            PlaceText(fs, element, layer.isBar and layer.Bar or layer, layer.isText and TEXT_PINS[element.Justify] or nil)
            fs:SetTextColor(unpack(element.Color))
            fs:SetShown(element.Enabled)
            local text = layer.texts[textCount]
            ConfigureText(text, element, spellName, layer, triggers)
            if text.source then layer.sourced = true end
        end
    end

    for i = textCount + 1, #layer.texts do
        local text = layer.texts[i]
        if text.binding then text.binding:SetToDefaults() end
        text.fs:Hide()
    end
    layer.textCount = textCount
end

---Glow sub elements, one glow per element on its own frame; `visibleOf(n)` says whether element n shows.
---@param glows CDMGlow[]
---@param host fun(): Frame makes the frame a new glow draws on
---@param subRegions table[]
---@param width number
---@param height number
---@param visibleOf fun(index: number, element: table): boolean
---@param onTexture fun(texture: Texture)?
function CDM:StyleGlows(glows, host, subRegions, width, height, visibleOf, onTexture)
    local count = 0
    for index, element in ipairs(subRegions) do
        if element.type == 'glow' then
            count = count + 1
            local glow = glows[count]
            if not glow then
                glow = self:CreateGlow(host(), onTexture)
                glows[count] = glow
            end
            if visibleOf(index, element) then glow:Start(element, width, height) else glow:Stop() end
        end
    end
    for i = count + 1, #glows do glows[i]:Stop() end
end

---@param layer CDMLayer
---@return fun(): Frame
local function LayerGlowHost(layer)
    return function()
        local host = CreateFrame('Frame', nil, layer)
        host:SetAllPoints()
        host:SetFrameLevel(layer:GetFrameLevel() + CDM.GLOW_LEVEL)
        return host
    end
end

local function ElementEnabled(_, element) return element.Enabled == true end
local function Never() return false end

---@param frame CDMIcon
---@param display table
---@param style table
function CDM:StyleIcon(frame, display, style)
    frame:NUISetPixelSize(style.Width, style.Height)
    frame:SetAlpha(style.Alpha)
    frame:EnableMouse(style.Tooltip == true)

    local subRegions = display.SubRegions or {}
    local triggers = display.Triggers
    local count = #triggers
    local elements = #subRegions
    local base = frame:GetFrameLevel() + 1 -- one base layer shows at a time, all at this level

    -- Overlays in stacking order: by slot, an earlier trigger above a later one in the same slot.
    local overlays = {}
    for i, trigger in ipairs(triggers) do
        if trigger.Type == 'auraoverlay' then overlays[#overlays + 1] = i end
    end
    local function SlotOf(i) return min(triggers[i].Slot or 0, elements) end
    -- An overlay under every element that only swaps the icon art goes below the base swipe, so the cooldown and GCD stay on it.
    local artOnly, hasArtOnly = {}, false
    for _, i in ipairs(overlays) do
        if SlotOf(i) == 0 then
            local active = self:GetAuraConditionChanges(display, i)
            local swipe = active.auraSwipe
            if swipe == nil then swipe = style.DrawSwipe end
            artOnly[i] = not (active.auraIcon == true and swipe)
            hasArtOnly = hasArtOnly or artOnly[i]
        end
    end
    tsort(overlays, function(a, b)
        if SlotOf(a) ~= SlotOf(b) then return SlotOf(a) < SlotOf(b) end
        if (artOnly[a] == true) ~= (artOnly[b] == true) then return artOnly[a] == true end
        return a > b
    end)
    -- Element n sits at base + 2 + n (over the icon, swipe and a bar), pushed up by every overlay slotted under it;
    -- on an overlay too, so its elements interleave with the base's in list order.
    local overlayLevel, shiftOf = {}, {}
    local shift, nextOverlay, swipeLevel = 0, 1, nil
    for n = 0, elements do
        while overlays[nextOverlay] and SlotOf(overlays[nextOverlay]) == n do
            local i = overlays[nextOverlay]
            if hasArtOnly and not swipeLevel and not artOnly[i] then swipeLevel, shift = base + 3 + shift, shift + 1 end
            overlayLevel[i] = base + 3 + n + shift
            shift = shift + OVERLAY_LEVELS + n
            nextOverlay = nextOverlay + 1
        end
        if hasArtOnly and not swipeLevel then swipeLevel, shift = base + 3 + shift, shift + 1 end
        shiftOf[n + 1] = shift
    end
    local function BaseLevel(n) return base + 2 + n + shiftOf[n] end

    for i, trigger in ipairs(triggers) do
        local layer = frame.layers[i]
        if not layer then
            layer = CreateLayer(frame)
            frame.layers[i] = layer
        end
        local level = overlayLevel[i] or base
        local levelOf = BaseLevel
        if overlayLevel[i] then
            -- Its elements in rows above it still draw over its own icon, under everything below the row.
            local slot = SlotOf(i)
            levelOf = function(n) return n > slot and BaseLevel(n) or level + OVERLAY_LEVELS - 1 + n end
        end
        layer.levelOf = levelOf
        layer.index = i
        layer:SetFrameLevel(level)
        layer.Cooldown:SetFrameLevel(not overlayLevel[i] and swipeLevel or level + 1)
        layer.textHost:SetFrameLevel(level + 1)
        layer.borderHost:SetFrameLevel(level + 1)
        if layer.auraHost then layer.auraHost:SetFrameLevel(level + 1) end
        self:StyleBarLayer(layer, style, trigger.Type == 'auraoverlay' and 'icon' or display.type, level)
        self:StyleTicks(layer, subRegions)
        StyleLayer(layer, style, subRegions, CDM:GetTriggerName(trigger) or '', triggers)
        StyleBorders(layer.borders, layer.borderHost, layer, subRegions)
        -- An aura layer's own glows are only the preview stand-in's; the aura button draws the real ones.
        local secret = self.TriggerTypes[trigger.Type] and self.TriggerTypes[trigger.Type].Secret
        self:StyleGlows(layer.glows, LayerGlowHost(layer), subRegions, style.Width, style.Height, secret and Never or ElementEnabled)
        LevelElements(subRegions, layer.borders, layer.glows, layer.texts, levelOf, layer.tickSets)
    end
    for i = count + 1, #frame.layers do
        local layer = frame.layers[i]
        self:SetLayerTimer(layer, nil)
        layer:Hide()
    end
    frame.layerCount = count

    self:SetupTextFit(frame, display)

    self:AnchorBarOverlays(frame)
    -- Restyling put every layer back to its style, so conditions apply everything again on the next update.
    frame.conditionApplied, frame.conditionLayer = nil, nil
end

-- What the aura button and bar pip files draw their borders and levels with.
CDM.Layer = {
    StyleBorder = StyleBorder,
    StyleBorders = StyleBorders,
    LevelElements = LevelElements,
    ElementEnabled = ElementEnabled,
}

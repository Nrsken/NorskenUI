---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local CreateObjectPool = CreateObjectPool
local CreateFrame = CreateFrame
local strfind = string.find
local strmatch = string.match
local tonumber = tonumber
local gsub = string.gsub
local ipairs, pairs = ipairs, pairs
local unpack = unpack
local min, max = math.min, math.max
local tsort = table.sort
local setmetatable = setmetatable

local GameTooltip = GameTooltip

local CreateDurationTextBinding = C_DurationUtil and C_DurationUtil.CreateDurationTextBinding
local GetSpellDisplayCount = C_Spell and C_Spell.GetSpellDisplayCount
local GetSpellCastCount = C_Spell and C_Spell.GetSpellCastCount
local TruncateWhenZero = C_StringUtil and C_StringUtil.TruncateWhenZero
local GetSpellName = C_Spell and C_Spell.GetSpellName
local CreateColorCurve = C_CurveUtil and C_CurveUtil.CreateColorCurve
local CreateColor = CreateColor
local UnitPowerPercent = UnitPowerPercent

-- Number formats for value texts; each takes a secret number (LocalizationDocumentation, AllowedWhenTainted).
local ABBREVIATORS = { abbreviate = AbbreviateNumbers, large = AbbreviateLargeNumbers, breakup = BreakUpLargeNumbers }
local LITERAL_PERCENT = '\001' -- a typed %%, until the text's kind decides how a percent sign is written

local BindingProperty = Enum.DurationTextBindingProperty

local PANDEMIC_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\AuraOverlay.png'
local PANDEMIC_COLOR = { 1, 0.25, 0.25, 1 }
CDM.PANDEMIC_TEXTURE = PANDEMIC_TEXTURE
local AURA_FILTERS = { player = 'HELPFUL', target = 'HARMFUL' } -- spellID matching only holds for buffs on friends and debuffs on enemies
local QUESTION_MARK = 134400
local TEXT_ROTATIONS = { LEFT = math.pi / 2, RIGHT = -math.pi / 2 }
local TEXT_PINS = { LEFT = 'LEFT', RIGHT = 'RIGHT', CENTER = 'CENTER', AUTO = 'CENTER' } -- a text display's text, by its alignment
local TEXT_KINDS = { 'time', 'count', 'static', 'sourcedText' } -- the fontstrings an aura button's text frame can hold
local OVERLAY_LEVELS = 6                                        -- an aura overlay's layer, aura host, container, button, its swipe and pandemic border, before its elements
CDM.GLOW_LEVEL = 3                                              -- a glow's level above its layer

-- Text tokens: %p time left and %t total run through a duration binding, %s is the charge count.
local DURATION_TOKENS = { p = BindingProperty.RemainingDuration, t = BindingProperty.TotalDuration }

---@class CDMIconText
---@field fs FontString
---@field binding table? C_DurationUtil duration text binding, for duration texts
---@field kind 'duration'|'charges'|'value'|'static'
---@field format string
---@field tokens number how many %s a charges text holds
---@field order string[]? value texts: the token behind each %s, in order
---@field element table? the sub element it was configured from
---@field usesName boolean? holds %n, so a cast's spell name reconfigures it
---@field source number? the trigger a %N.p / %N.s text reads, when it isn't the layer's own
---@field eachPip boolean? hidden for its copies on every pip of a split bar
---@field host Frame? its own frame, so it draws at its place in the sub element list (a layer's texts)
---@field abbreviate (fun(value: number): string)? value texts: the number format, AbbreviateNumbers and the like
---@field valueCurve LuaColorCurveObject? value texts on a power trigger: colour by how full the power is

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

---The trigger's texture, unless the style picks one by hand.
---@param layer CDMLayer
---@param texture number?
function CDM:SetIconTexture(layer, texture)
    local style = layer.owner.style
    if style and style.IconSource == 'manual' and style.ManualIcon then texture = style.ManualIcon end
    layer.Icon:SetTexture(texture or QUESTION_MARK)
end

-- Text --

---Does this text use a duration token, does it also ask for the charge count it can't show with one, and
---which trigger it reads: WeakAuras' %2.p reads trigger 2, a plain %p the layer's own.
---@param text string
---@return boolean duration, boolean charges, number? source
function CDM:ClassifyText(text)
    return strfind(text, '%%%d*%.?[pt]') ~= nil, strfind(text, '%%%d*%.?s') ~= nil, tonumber(strmatch(text, '%%(%d+)%.[pts]'))
end

---@param layer CDMLayer
---@param index number
---@return CDMIconText
local function AcquireText(layer, index)
    local text = layer.texts[index]
    if not text then
        local host = CreateFrame('Frame', nil, layer.textHost)
        host:SetAllPoints()
        text = { fs = host:CreateFontString(nil, 'OVERLAY'), host = host, kind = 'static', format = '', tokens = 0 } --[[@as CDMIconText]]
        layer.texts[index] = text
    end
    return text
end

---@param mark string
---@return string?
local function RaidMarker(mark)
    local index = tonumber(mark)
    if index and index >= 1 and index <= 8 then return '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_' .. index .. ':0|t' end
end

---The text with %n, %i, \n and {rt1}..{rt8} filled in; %% stays LITERAL_PERCENT until its kind writes the sign.
---@param element table
---@param spellName string
---@param texture number|string?
---@return string
local function ExpandText(element, spellName, texture)
    local raw = gsub(element.Text or '', '%%%%', LITERAL_PERCENT)
    raw = gsub(raw, '\\n', '\n')
    raw = gsub(raw, '{rt(%d)}', RaidMarker)
    raw = gsub(raw, '%%i', function() return texture and ('|T' .. texture .. ':0|t') or '' end)
    return (gsub(raw, '%%n', function() return spellName end))
end

---A text with %p/%t as a binding format: '{}' per token, with a component that renders it.
---@param raw string
---@param element table
---@return string format, table[] components
local function DurationFormat(raw, element)
    local formatter = element.TimeFormat == 'custom'
        and NRSKNUI:GetPrecisionDurationFormatter(element.PrecisionBelow, element.Precision)
        or NRSKNUI:GetAuraDurationFormatter()
    local components = {}
    local format = gsub(raw, '%%%d*%.?([pt])', function(token)
        components[#components + 1] = { property = DURATION_TOKENS[token], formatter = formatter }
        return '{}'
    end)
    format = gsub(format, '%%%d*%.?s', '')
    return (gsub(format, LITERAL_PERCENT, '%%')), components
end

---A step curve: the text's own colour, `color` below `seconds` left.
---@param element table
---@return LuaColorCurveObject?
local function TimeColorCurve(element)
    local timeColor = element.TimeColor
    if not (timeColor and timeColor.Enabled) then return nil end
    local curve = CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0, CreateColor(unpack(timeColor.Color or { 1, 0.25, 0.25, 1 })))
    curve:AddPoint(timeColor.Below or 3, CreateColor(unpack(element.Color)))
    return curve
end

---@param text CDMIconText
---@param element table
---@param spellName string
---@param layer CDMLayer
---@param triggers table[]
local function ConfigureText(text, element, spellName, layer, triggers)
    text.element = element
    text.fs:SetAlpha(1) -- a spell trigger hides short countdowns through it
    text.usesName = strfind(element.Text or '', '%%n') ~= nil
    local own = triggers[layer.index]
    local raw = ExpandText(element, spellName, own and CDM:GetTriggerTexture(own))
    local hasDuration, hasCharges, source = CDM:ClassifyText(raw)
    if source == layer.index or not (hasDuration or hasCharges) then source = nil end
    text.source = source
    text.abbreviate, text.valueCurve = nil, nil

    local reads = triggers[source or layer.index]
    local readsType = reads and CDM.TriggerTypes[reads.Type]
    -- An Each Rune %p is that rune's recharge; anywhere else a value trigger's %p is its value, %t its max.
    local perPip = element.EachPip and reads and reads.Mode and layer.isBar
    if readsType and readsType.Value and not perPip and (hasDuration or hasCharges) then
        if text.binding then text.binding:SetToDefaults() end
        local mode = element.NumberFormat or 'auto'
        local auto = mode == 'auto' and readsType.Decimals -- one count for every token, or one per token
        local order = {}
        local format = gsub(gsub(raw, '%%', '%%%%'), '%%%%%d*%.?([pts])', function(token)
            order[#order + 1] = token
            local decimals = mode == 'decimals' and (element.Decimals or 1) or (type(auto) == 'table' and auto[token] or auto)
            if token == 's' or not decimals then return '%s' end
            return string.format('%%.%df', decimals) -- SetFormattedText takes secrets in number specs too
        end)
        text.format = gsub(format, LITERAL_PERCENT, '%%%%')
        text.order, text.kind = order, 'value'
        text.abbreviate = ABBREVIATORS[mode]
        local valueColor = element.ValueColor
        if valueColor and valueColor.Enabled and reads.Type == 'power' then
            local curve = CreateColorCurve()
            curve:AddPoint(0, CreateColor(unpack(valueColor.Low or { 1, 0.25, 0.25, 1 })))
            curve:AddPoint(1, CreateColor(unpack(valueColor.High or { 0.25, 1, 0.25, 1 })))
            text.valueCurve = curve
        end
        return
    end

    local sourceType = source and triggers[source] and CDM.TriggerTypes[triggers[source].Type]
    if source and not (sourceType and not sourceType.Secret) then
        -- Another trigger's aura time stays inside its own button, and a missing trigger has none.
        if text.binding then text.binding:SetToDefaults() end
        text.kind, text.source = 'static', nil
        text.fs:SetText('')
        return
    end

    if hasDuration then
        text.binding = text.binding or CreateDurationTextBinding()
        local binding = text.binding
        binding:SetToDefaults() -- the only way to drop a colour curve an earlier style set
        binding:SetFontString(text.fs)
        binding:SetTextFormat(DurationFormat(raw, element))
        local ready = element.ReadyText or ''
        binding:SetZeroDurationText(ready)
        binding:SetExpiredText(ready)
        local curve = TimeColorCurve(element)
        if curve then binding:SetTextColorCurve(curve, BindingProperty.RemainingDuration) end
        binding:SetEnabled(true)
        text.kind = 'duration'
    else
        if text.binding then text.binding:SetToDefaults() end
        if hasCharges then
            -- Every other % is escaped, so only the %s tokens take the count.
            local format, tokens = gsub(gsub(raw, '%%', '%%%%'), '%%%%%d*%.?s', '%%s')
            text.format, text.tokens, text.kind = gsub(format, LITERAL_PERCENT, '%%%%'), tokens, 'charges'
        else
            text.kind = 'static'
            text.fs:SetText((gsub(raw, LITERAL_PERCENT, '%%')))
        end
    end
end

---WeakAuras' text placement: the text's own point on the frame's point, then alignment, rotation and width.
---@param fs FontString
---@param element table
---@param parent Frame
---@param pin string? a text display's text sits on this point of its frame instead (WeakAuras pins it at its alignment)
local function PlaceText(fs, element, parent, pin)
    local position = element.Position
    local to = pin or position.AnchorTo or 'CENTER'
    local from = pin or position.AnchorFrom ~= 'AUTO' and position.AnchorFrom or to
    fs:SetFontJustify(from, parent, nil, nil, true, {
        { point = from, relTo = parent, relPoint = to, offsetX = pin and 0 or position.XOffset, offsetY = pin and 0 or position.YOffset },
    })
    if element.Justify ~= 'AUTO' then fs:SetJustifyH(element.Justify) end
    fs:SetRotation(TEXT_ROTATIONS[element.Rotation] or 0)
    local fixed = element.WidthMode == 'fixed'
    local wrap = not fixed or element.WordWrap
    fs:SetWidth(fixed and element.FixedWidth or 0)
    fs:SetWordWrap(wrap)
    fs:SetNonSpaceWrap(wrap)
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

---Crop the icon to its frame's shape, so a wide icon isn't stretched.
---@param texture Texture
---@param style table
local function ApplyTexCoords(texture, style)
    local margin = 0.25 * (style.Zoom or NRSKNUI.GlobalZoom)
    local left, right, top, bottom = margin, 1 - margin, margin, 1 - margin
    if style.KeepAspectRatio and style.Width ~= style.Height then
        local span = 1 - 2 * margin
        if style.Width > style.Height then
            local cut = span * (1 - style.Height / style.Width) / 2
            top, bottom = top + cut, bottom - cut
        else
            local cut = span * (1 - style.Width / style.Height) / 2
            left, right = left + cut, right - cut
        end
    end
    texture:SetTexCoord(left, right, top, bottom)
end

---@param layer CDMLayer
---@param style table
---@param subRegions table[]
---@param spellName string
local function StyleLayer(layer, style, subRegions, spellName, triggers)
    local icon = layer.Icon
    ApplyTexCoords(icon, style)
    icon:SetVertexColor(unpack(style.Color))
    icon:SetAlpha(1) -- an aura placeholder dims it

    local cooldown = layer.Cooldown
    cooldown:SetDrawSwipe(style.DrawSwipe)
    cooldown:SetDrawEdge(style.DrawEdge)
    cooldown:SetReverse(style.Reverse)
    cooldown:SetSwipeColor(unpack(style.SwipeColor))
    cooldown:SetHideCountdownNumbers(style.HideCountdown)

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

---A text display's frame sized to the shown text by the engine; Lua never reads the size, which turns secret with the text.
---@param frame CDMIcon
local function FitText(frame)
    local layer = frame.activeLayer or frame.layers[1]
    local text = layer and layer.texts[1]
    if not text then return end
    if frame.fitText ~= text.fs then
        frame.fitText = text.fs
        local first, last = frame.fitProbes[1], frame.fitProbes[2]
        first:ClearAllPoints()
        first:SetPoint('TOPLEFT', text.fs, 'TOPLEFT')
        last:ClearAllPoints()
        last:SetPoint('BOTTOMRIGHT', text.fs, 'BOTTOMRIGHT')
    end
    CDM.MeasureBounds(frame)
end

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

    -- A Grid dynamic group reads its children's sizes, so a text there keeps the style's box.
    local fits = display.type == 'text' and not (self:IsDynamic(display.parent) and not self:WantsChain(display.parent))
    if fits and not frame.fitProbes then
        frame.fitProbes = {}
        for i = 1, 2 do
            local probe = CreateFrame('Frame', nil, frame)
            probe:SetSize(0.001, 0.001)
            frame.fitProbes[i] = probe
        end
    end
    for _, probe in ipairs(frame.fitProbes or {}) do probe:SetShown(fits) end
    frame.fitsText, frame.fitText = fits, nil
    frame:SetScript('OnUpdate', fits and FitText or nil)

    self:AnchorBarOverlays(frame)
    -- Restyling put every layer back to its style, so conditions apply everything again on the next update.
    frame.conditionApplied, frame.conditionLayer = nil, nil
end

---Copy the texts and borders marked Each Rune onto every pip of a split bar; the layer's own copies hide.
---@param layer CDMLayer
function CDM:StylePips(layer)
    local count = layer.pipCount or 0
    for _, pip in ipairs(layer.pips or {}) do
        for _, text in pairs(pip.texts) do
            if text.binding then text.binding:SetToDefaults() end
            text.kind = 'static'
            text.fs:Hide()
        end
        for _, border in pairs(pip.borders) do border:Hide() end
    end
    -- Un-splitting runs from StyleBarLayer, before StyleLayer grows layer.texts for a newly added element.
    if count == 0 then
        for _, own in ipairs(layer.texts) do own.eachPip = nil end
        for _, own in ipairs(layer.borders) do own.eachPip = nil end
        return
    end

    local display = layer.owner.id and self:Get(layer.owner.id)
    local triggers = display and display.Triggers or {}
    local spellName = triggers[layer.index] and self:GetTriggerName(triggers[layer.index]) or ''
    local textOrdinal, borderOrdinal = 0, 0
    for _, element in ipairs(layer.subRegions or {}) do
        local each = count > 0 and element.EachPip == true
        if element.type == 'text' then
            textOrdinal = textOrdinal + 1
            local own = layer.texts[textOrdinal]
            own.eachPip = each
            if each then
                own.fs:Hide()
                for i = 1, count do
                    local pip = layer.pips[i]
                    local text = pip.texts[textOrdinal]
                    if not text then
                        text = { fs = own.host:CreateFontString(nil, 'OVERLAY'), host = own.host, kind = 'static', format = '', tokens = 0 } --[[@as CDMIconText]]
                        pip.texts[textOrdinal] = text
                    end
                    text.fs:SetFontStyle(element, element.FontSize, nil, nil, true)
                    PlaceText(text.fs, element, pip)
                    text.fs:SetTextColor(unpack(element.Color))
                    ConfigureText(text, element, spellName, layer, triggers)
                    text.fs:SetShown(element.Enabled)
                end
            end
        elseif element.type == 'border' then
            borderOrdinal = borderOrdinal + 1
            local own = layer.borders[borderOrdinal]
            own.eachPip = each
            if each then
                own:Hide()
                for i = 1, count do
                    local pip = layer.pips[i]
                    pip.borders[borderOrdinal] = StyleBorder(pip.borders[borderOrdinal], layer.borderHost, pip, element, true)
                    pip.borders[borderOrdinal]:SetFrameLevel(own:GetFrameLevel())
                end
            end
        end
    end
end

---@param from CDMLayer
---@param token string?
---@return any
---@param abbreviate (fun(value: number): string)? the text's number format, which takes a secret value
local function ValueOf(from, token, abbreviate)
    local value
    if token == 'p' then
        value = from.value or 0
    elseif token == 't' then
        value = from.max or 0
    else
        return token and '' or nil
    end
    if abbreviate then return abbreviate(value) end
    return value
end

---@param text CDMIconText
---@param from CDMLayer the layer whose trigger the text reads
local function UpdateText(text, from)
    if text.kind == 'duration' then
        if from.duration then text.binding:SetDuration(from.duration) end
    elseif text.kind == 'charges' then
        local charges = from.count
        local spellID = from.spellID
        if not charges and spellID then
            if from.state.hasCharges then
                charges = GetSpellDisplayCount(spellID)
            elseif GetSpellCastCount then
                -- Stack spells without charges (Soul Fragments style) expose their count as a cast count; zero reads as blank.
                local ok, count = pcall(TruncateWhenZero, GetSpellCastCount(spellID))
                if ok and count then charges = count end
            end
        end
        if charges then
            text.fs:SetFormattedText(text.format, charges, charges, charges, charges) -- extra arguments are ignored
        else
            text.fs:SetText('')
        end
    elseif text.kind == 'value' then
        local order, abbreviate = text.order, text.abbreviate
        text.fs:SetFormattedText(text.format, ValueOf(from, order[1], abbreviate), ValueOf(from, order[2], abbreviate),
            ValueOf(from, order[3], abbreviate), ValueOf(from, order[4], abbreviate))
        -- Colour by value: the engine evaluates the curve on the (maybe secret) percent and hands back a plain colour.
        if text.valueCurve and from.powerType then
            local color = UnitPowerPercent('player', from.powerType, false, text.valueCurve) --[[@as colorRGBA]]
            text.fs:SetTextColor(color:GetRGBA())
        end
    end
end

---Feed a layer's texts their trigger's latest timing and charges.
---@param layer CDMLayer
function CDM:UpdateTexts(layer)
    local layers = layer.owner.layers
    for i = 1, layer.textCount or 0 do
        local text = layer.texts[i]
        UpdateText(text, text.source and layers[text.source] or layer)
    end
    local refs = layer.auraRefs
    if refs and refs.sourced then
        for i = 1, refs.sourcedCount do
            local text = refs.sourced[i]
            UpdateText(text, layers[text.source])
        end
    end
end

---A copy of one of the layer's texts on another parent, read with another name: the same font, place, tokens and formats.
---@param layer CDMLayer
---@param ordinal number which of the layer's texts
---@param copy CDMIconText? the copy made last time
---@param parent Frame
---@param name string what its %n reads
---@return CDMIconText?
function CDM:StyleTextCopy(layer, ordinal, copy, parent, name)
    local own = layer.texts[ordinal]
    local element = own and own.element
    local display = layer.owner.id and self:Get(layer.owner.id)
    if not (element and display) then return copy end
    copy = copy or { kind = 'static', format = '', tokens = 0 } --[[@as CDMIconText]]
    if not copy.fs then copy.fs = parent:CreateFontString(nil, 'OVERLAY') end
    local fs = copy.fs
    fs:SetFontStyle(element, element.FontSize, nil, nil, true)
    PlaceText(fs, element, layer.isBar and layer.Bar or layer, layer.isText and TEXT_PINS[element.Justify] or nil)
    fs:SetTextColor(unpack(element.Color))
    fs:SetShown(element.Enabled)
    ConfigureText(copy, element, name, layer, display.Triggers)
    copy.source = nil -- it reads what it is handed, never another trigger
    return copy
end

---Feed a text copy its values, as UpdateTexts feeds a layer's own texts.
---@param copy CDMIconText
---@param from table anything with the fields a text reads (value, max, duration)
function CDM:UpdateTextCopy(copy, from)
    UpdateText(copy, from)
end

---A cast's spell name for the layer's %n texts; set per cast instead of baked in when the layer is styled.
---@param layer CDMLayer
---@param name string
function CDM:SetLayerName(layer, name)
    if layer.shownName == name then return end
    layer.shownName = name
    local display = layer.owner.id and self:Get(layer.owner.id)
    if not display then return end
    for i = 1, layer.textCount or 0 do
        local text = layer.texts[i]
        if text.usesName then ConfigureText(text, text.element, name, layer, display.Triggers) end
    end
end

---A condition's Display Text on one of a layer's texts, read like the element's own.
---@param layer CDMLayer
---@param text CDMIconText
---@param element table
---@param value string
function CDM:SetDisplayText(layer, text, element, value)
    local display = layer.owner.id and self:Get(layer.owner.id)
    if not display then return end
    local trigger = display.Triggers[layer.index]
    local name = layer.shownName or (trigger and self:GetTriggerName(trigger)) or ''
    ConfigureText(text, setmetatable({ Text = value }, { __index = element }), name, layer, display.Triggers)
    if text.source then layer.sourced = true end
    UpdateText(text, text.source and layer.owner.layers[text.source] or layer)
end

-- Aura layers --
-- An aura trigger draws through a one-slot native AuraContainer: the client shows the slot while the
-- aura is up, so nothing secret ever reaches Lua and the layer simply covers the triggers below it.

local targetContainers = {} ---@type table<table, true> containers following the target

-- AddSlot hands back a secret-wrapped button, so everything is reached through the refs filled in here,
-- the one place the real button is passed to us.
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
    icon:NUISetPixelSnap() -- rounds like its edge borders when the engine lays the chain on a half pixel
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
    pandemic:NUISetPixelInside(inner) -- where SkinAuraButton puts the same texture on debuffs
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
    local showIcon = not overlay or active.auraIcon == true
    if isBar then showIcon = style.IconShow == true end
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
        if active.auraDesaturate ~= nil then desaturate = active.auraDesaturate end
        if active.auraSwipe ~= nil then swipe = active.auraSwipe end
        if active.auraInverse ~= nil then reverse = active.auraInverse end
    end

    local textParent = refs.inner
    if isBar then
        textParent = self:StyleAuraBar(button, refs, style, trigger)
        swipe = false
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
    -- Without its icon the native button doesn't hold an alpha we set on it, so the icon is kept from it entirely.
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
    cooldown:SetHideCountdownNumbers(style.HideCountdown or not showIcon or isBar)

    refs.pandemic:SetAlpha(pandemicColor and 1 or 0)
    if pandemicColor then refs.pandemic:SetVertexColor(unpack(pandemicColor)) end

    local spellName = spellID and GetSpellName(spellID) or ''
    local hasTime, hasCount, sourcedCount, ordinal = false, false, 0, 0
    -- Each text draws from its own frame, at its place in the list. The button denies reparenting its fontstrings
    -- (forbidden aspect ChangeParent), so every text frame makes its own and the button is pointed at the one in use.
    local function Text(entry, key)
        if not entry[key] then entry[key] = entry.host:CreateFontString(nil, 'OVERLAY') end
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
                if entry[key] then entry[key]:Hide() end
            end
            if entry.sourced and entry.sourced.binding then entry.sourced.binding:SetToDefaults() end

            if element.Enabled then
                local raw = ExpandText(element, spellName, self:GetTriggerTexture(trigger))
                local isDuration, isCount, source = CDM:ClassifyText(raw)
                if source == layer.index then source = nil end
                local sourceType = source and display.Triggers[source] and self.TriggerTypes[display.Triggers[source].Type]
                if source and (isDuration or isCount) then
                    -- Another trigger's time or charges, fed by UpdateTexts; only a non-aura trigger has any to give.
                    if sourceType and not sourceType.Secret then
                        local fs = Text(entry, 'sourcedText')
                        entry.sourced = entry.sourced or { fs = fs, kind = 'static', format = '', tokens = 0 }
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
                    button:SetDurationText(fs, { textFormat = { formatString = format, components = components } })
                    fs:Show()
                elseif isCount and not hasCount and not isDuration then
                    hasCount = true
                    local fs = Text(entry, 'count')
                    StyleAuraText(fs, element, textParent)
                    button:SetApplicationCount(fs, {})
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
    for i = ordinal + 1, #refs.textHosts do
        local entry = refs.textHosts[i]
        for _, key in ipairs(TEXT_KINDS) do
            if entry[key] then entry[key]:Hide() end
        end
    end

    if not hasTime then button:ClearDurationText() end
    if not hasCount then button:ClearApplicationCount() end
    for i = sourcedCount + 1, #refs.sourced do refs.sourced[i] = nil end
    refs.sourcedCount = sourcedCount
    layer.auraSourced = sourcedCount > 0
    if sourcedCount > 0 then self:UpdateTexts(layer) end

    StyleBorders(refs.borders, refs.borderHost, refs.inner, subRegions)

    -- In a chain group sized from the style, never read: the icon's area, and the button padded by the chain's spacing.
    -- Elsewhere it follows its frame, which a matched bar has from the engine.
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
    local width, height = layer.owner.style.Width, layer.owner.style.Height
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
        if listLevel then return max(base + 1, listLevel(n)) end -- never under its own swipe and pandemic border
        return base + n
    end
    LevelElements(subRegions, refs.borders, refs.glows, refs.textHosts, LevelOf)
    LevelElements(subRegions, {}, refs.pandemicGlows, {}, LevelOf)

    if display.type == 'bar' and overlay then
        refs.barOverlay = refs.barOverlay or {}
        self:PaintBarOverlay(layer, refs.barOverlay, button, active)
    end
end

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
                if chain then chain:WatchAuraButton(layer.owner.id, created) end
                self:StyleAuraButton(layer, layer.auraTrigger)
            end,
        })
        slot = { refs = refs, index = index }
        layer.auraSlots[filter] = slot
    end
    for key, other in pairs(layer.auraSlots) do container:SetSlotShown(other.index, key == filter) end
    layer.auraRefs = slot.refs
    -- A button that already exists denies tainted access while auras are secret (DenyTaintedAccessWhenAurasAreSecret).
    local accessible = not NRSKNUI:AreAurasSecret()
    local chain = layer.owner.chainGroup
    if accessible and chain and slot.refs.button then chain:WatchAuraButton(layer.owner.id, slot.refs.button) end

    container:SetEnabled(true)
    container:SetUnit(unit)
    container:UpdateUnitGate()
    container:UpdateAllAuras()
    targetContainers[container] = unit == 'target' or nil

    if accessible then self:StyleAuraButton(layer, trigger) end
end

---Stop a layer's aura container, when its trigger is no longer an aura or its icon goes back to the pool.
---@param layer CDMLayer
function CDM:ReleaseAuraLayer(layer)
    local container = layer.auraContainer
    if not container then return end
    layer.auraHost:Hide()
    layer.auraKey = nil
    targetContainers[container] = nil
    -- One function per layer: RunWhenSafe drops a repeat, so re-resolving in combat never grows the queue.
    layer.disableAura = layer.disableAura or function()
        if not layer.auraKey then container:SetEnabled(false) end
    end
    NRSKNUI:RunWhenSafe(layer.disableAura)
end

-- The container doesn't follow target changes on its own (Blizzard_AuraContainer.lua, live).
local targetWatcher = CreateFrame('Frame')
targetWatcher:RegisterEvent('PLAYER_TARGET_CHANGED')
targetWatcher:SetScript('OnEvent', function()
    for container in pairs(targetContainers) do
        container:UpdateUnitGate()
        container:UpdateAllAuras()
    end
end)

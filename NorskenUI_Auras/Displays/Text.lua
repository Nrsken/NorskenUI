---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local CreateFrame = CreateFrame
local strfind = string.find
local strmatch = string.match
local strupper = string.upper
local strformat = string.format
local tonumber = tonumber
local type = type
local gsub = string.gsub
local unpack = unpack
local setmetatable = setmetatable

local CreateDurationTextBinding = C_DurationUtil and C_DurationUtil.CreateDurationTextBinding
local GetSpellDisplayCount = C_Spell and C_Spell.GetSpellDisplayCount
local GetSpellCharges = C_Spell and C_Spell.GetSpellCharges
local GetSpellCastCount = C_Spell and C_Spell.GetSpellCastCount
local TruncateWhenZero = C_StringUtil and C_StringUtil.TruncateWhenZero
local UnitPowerPercent = UnitPowerPercent
local CurveConstants = CurveConstants

local BindingProperty = Enum.DurationTextBindingProperty
local PowerType = Enum.PowerType

--[[
Text sub elements: what their tokens read, where they sit and how they update.
Times and power values can be secret, so they only ever go through a duration binding or SetFormattedText.
]]

-- number formats for value texts; each takes a secret number (LocalizationDocumentation, AllowedWhenTainted)
local ABBREVIATORS = { abbreviate = AbbreviateNumbers, large = AbbreviateLargeNumbers, breakup = BreakUpLargeNumbers }
local LITERAL_PERCENT = '\001' -- a typed %%, until the text's kind decides how a percent sign is written
local args = {} -- one SetFormattedText argument per token, refilled on every update

local TEXT_ROTATIONS = { LEFT = math.pi / 2, RIGHT = -math.pi / 2 }
local TEXT_PINS = { LEFT = 'LEFT', RIGHT = 'RIGHT', CENTER = 'CENTER', AUTO = 'CENTER' } -- a text display's text, by its alignment

-- %p is the time left and %t the total, both rendered by the duration binding
local DURATION_TOKENS = { p = BindingProperty.RemainingDuration, t = BindingProperty.TotalDuration }

-- the checks a text's colour curve follows, each with what divides its threshold into the value the game reads
local TIME_SCALES = { remaining = 1 }
local powerScales = { percent = 100 } -- value: the max, set per curve

-- Configure --

---Whether a text has duration (%p/%t) or charge (%s) tokens and which trigger a %N. token reads.
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
        text = { fs = host:CreateFontString(nil, 'OVERLAY'), host = host, kind = 'static', format = '', tokens = 0, ordinal = index } --[[@as CDMIconText]]
        layer.texts[index] = text
    end

    return text
end

---@param mark string
---@return string?
local function RaidMarker(mark)
    local index = tonumber(mark)
    if index and index >= 1 and index <= 8 then
        return '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_' .. index .. ':0|t'
    end
end

---@param element table
---@param name string?
---@return string?
local function FormatName(element, name)
    if not name then return nil end

    if element.NameFormat == 'initial' then
        name = strmatch(name, '^[%z\1-\127\194-\244][\128-\191]*') or '' -- one UTF-8 character, for non-Latin clients
    elseif element.NameFormat == 'upper' then
        name = strupper(name)
    end

    -- custom keeps the text's own Color
    if element.NameColor == 'class' then
        return NRSKNUI:ColorTextByClass(name)
    elseif element.NameColor == 'theme' then
        return NRSKNUI:ColorTextByTheme(name)
    end

    return name
end

---The text with %n, %N.n, %i, %N.i, \n and {rt1}..{rt8} filled in; %% stays LITERAL_PERCENT until its kind writes the sign.
---@param element table
---@param spellName string
---@param texture number|string?
---@param triggers table[]? the display's triggers, which %N.n and %N.i read
---@return string
local function ExpandText(element, spellName, texture, triggers)
    local raw = gsub(element.Text or '', '%%%%', LITERAL_PERCENT)
    raw = gsub(raw, '\\n', '\n')
    raw = gsub(raw, '{rt(%d)}', RaidMarker)
    raw = gsub(raw, '%%(%d+)%.i', function(index)
        local trigger = triggers and triggers[tonumber(index)]
        local icon = trigger and CDM:GetTriggerTexture(trigger)
        return icon and ('|T' .. icon .. ':0|t') or ''
    end)
    raw = gsub(raw, '%%i', function()
        return texture and ('|T' .. texture .. ':0|t') or ''
    end)
    raw = gsub(raw, '%%(%d+)%.n', function(index)
        local trigger = triggers and triggers[tonumber(index)]
        return FormatName(element, trigger and CDM:GetTriggerName(trigger)) or ''
    end)

    return (gsub(raw, '%%n', function()
        return FormatName(element, spellName)
    end))
end

---A %p/%t text as a binding format: '{}' per token, each with a component that renders it.
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

---A power text's colour curve; the game only reads a percent, so a Value threshold needs a plain max.
---@param text CDMIconText
---@param display table
---@param index number the power trigger
---@param max any
local function PowerColorCurve(text, display, index, max)
    local plain = not NRSKNUI:IsSecretValue(max)
    if plain then
        text.curveMax = max
    end

    powerScales.value = plain and max and max > 0 and max or nil
    text.valueCurve = CDM:TextColorCurve(display, index, powerScales, text.ordinal, text.element.Color)
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
    text.abbreviate, text.valueCurve, text.percent, text.colorsByValue, text.curveMax = nil, nil, nil, nil, nil

    local own = triggers[layer.index]
    local raw = ExpandText(element, spellName, own and CDM:GetTriggerTexture(own), triggers)
    local hasDuration, hasCharges, source = CDM:ClassifyText(raw)
    if source == layer.index or not (hasDuration or hasCharges) then
        source = nil
    end
    text.source = source

    local display = text.ordinal and layer.owner.id and CDM:Get(layer.owner.id) -- whose conditions can colour it
    local reads = triggers[source or layer.index]
    local readsType = reads and CDM.TriggerTypes[reads.Type]

    -- an Each Rune %p is that rune's recharge; anywhere else a value trigger's %p is its value and %t its max
    local perPip = element.EachPip and reads and reads.Mode and layer.isBar
    if readsType and readsType.Value and not perPip and (hasDuration or hasCharges) then
        if text.binding then
            text.binding:SetToDefaults()
        end

        local mode = element.NumberFormat or 'auto'
        local auto = mode == 'auto' and readsType.Decimals -- one count for every token or one per token
        local percent = mode == 'percent' and reads.Type == 'power'
        local order = {}
        local format = gsub(gsub(raw, '%%', '%%%%'), '%%%%%d*%.?([pts])', function(token)
            order[#order + 1] = token
            local decimals = mode == 'decimals' and (element.Decimals or 1) or (type(auto) == 'table' and auto[token] or auto)
            if percent and token == 'p' then
                decimals = 0
            end
            if token == 's' or not decimals then
                return '%s'
            end

            return strformat('%%.%df', decimals) -- SetFormattedText takes secrets in number specs too
        end)
        text.format = gsub(format, LITERAL_PERCENT, '%%%%')
        text.order, text.kind = order, 'value'
        text.abbreviate, text.percent = ABBREVIATORS[mode], percent

        if display and reads.Type == 'power' then
            local index = source or layer.index
            text.colorsByValue = CDM:ConditionsUse(display, index, 'value') or nil
            PowerColorCurve(text, display, index, (source and layer.owner.layers[source] or layer).max)
        end
        return
    end

    -- another trigger's aura time stays inside its own button and a missing trigger has none
    local sourceType = source and triggers[source] and CDM.TriggerTypes[triggers[source].Type]
    if source and not (sourceType and not sourceType.Secret) then
        if text.binding then
            text.binding:SetToDefaults()
        end
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
        binding:SetZeroDurationText('')
        binding:SetExpiredText('')
        local curve = display and CDM:TextColorCurve(display, source or layer.index, TIME_SCALES, text.ordinal, element.Color)
        if curve then
            binding:SetTextColorCurve(curve, BindingProperty.RemainingDuration)
        end
        binding:SetEnabled(true)
        text.kind = 'duration'
        return
    end

    if text.binding then
        text.binding:SetToDefaults()
    end

    text.hideZero = element.HideZero
    if hasCharges then
        -- every other % is escaped, so only the %s tokens take the count
        local format, tokens = gsub(gsub(raw, '%%', '%%%%'), '%%%%%d*%.?s', '%%s')
        text.format, text.tokens, text.kind = gsub(format, LITERAL_PERCENT, '%%%%'), tokens, 'charges'
    else
        text.kind = 'static'
        text.fs:SetText((gsub(raw, LITERAL_PERCENT, '%%')))
    end
end

---The text's own point on the frame's point, then alignment, rotation and width.
---@param fs FontString
---@param element table
---@param parent Frame
---@param pin string? a text display's text sits on this point of its frame instead, picked by its alignment
local function PlaceText(fs, element, parent, pin)
    local position = element.Position
    local to = pin or position.AnchorTo or 'CENTER'
    local from = pin or position.AnchorFrom ~= 'AUTO' and position.AnchorFrom or to
    fs:SetFontJustify(from, parent, nil, nil, true, {
        { point = from, relTo = parent, relPoint = to, offsetX = pin and 0 or position.XOffset, offsetY = pin and 0 or position.YOffset },
    })
    if element.Justify ~= 'AUTO' then
        fs:SetJustifyH(element.Justify)
    end
    fs:SetRotation(TEXT_ROTATIONS[element.Rotation] or 0)

    local fixed = element.WidthMode == 'fixed'
    local wrap = not fixed or element.WordWrap
    fs:SetWidth(fixed and element.FixedWidth or 0)
    fs:SetWordWrap(wrap)
    fs:SetNonSpaceWrap(wrap)
end

-- Update --

---@param from CDMLayer
---@param token string?
---@param abbreviate (fun(value: number): string)? the text's number format, which takes a secret value
---@param percent boolean? %p as a share of the max, 0 to 100
---@return any
local function ValueOf(from, token, abbreviate, percent)
    local value
    if token == 'p' and percent then
        local powerType = from.powerType
        -- these read plain; a real power's percent can be secret, so the game scales that one for us
        if powerType == CDM.MAELSTROM_WEAPON or powerType == CDM.STAGGER or powerType == PowerType.Runes then
            local max = from.max or 0
            return max > 0 and (from.value or 0) / max * 100 or 0
        end
        return UnitPowerPercent('player', powerType --[[@as Enum.PowerType]], false, CurveConstants.ScaleTo100)
    elseif token == 'p' then
        value = from.value or 0
    elseif token == 't' then
        value = from.max or 0
    else
        return token and '' or nil
    end

    if abbreviate then
        return abbreviate(value)
    end

    return value
end

---@param text CDMIconText
---@param from CDMLayer the layer whose trigger the text reads
local function UpdateText(text, from)
    if text.kind == 'duration' then
        if from.duration then
            text.binding:SetDuration(from.duration)
        end
    elseif text.kind == 'charges' then
        local hideZero = text.hideZero
        local charges = from.count
        local spellID = from.spellID
        if charges and hideZero then
            charges = TruncateWhenZero(charges)
        end
        if not charges and spellID then
            if from.state.hasCharges and hideZero then
                -- the display count is a string, so a zero can only be blanked from the secret number behind it
                charges = TruncateWhenZero(GetSpellCharges(spellID).currentCharges)
            elseif from.state.hasCharges then
                charges = GetSpellDisplayCount(spellID)
            else
                -- stack spells without charges, like Soul Fragments, count as casts; both calls take a secret and zero reads blank
                charges = TruncateWhenZero(GetSpellCastCount(spellID))
            end
        end

        if charges then
            for i = 1, text.tokens do
                args[i] = charges
            end
            text.fs:SetFormattedText(text.format, unpack(args, 1, text.tokens))
        else
            text.fs:SetText('')
        end
    elseif text.kind == 'value' then
        local order, abbreviate, percent = text.order, text.abbreviate, text.percent
        for i = 1, #order do
            args[i] = ValueOf(from, order[i], abbreviate, percent)
        end
        text.fs:SetFormattedText(text.format, unpack(args, 1, #order))

        -- a Value condition's share of the max moves when the max does (talents); a secret max keeps the last one
        local max = from.max
        if text.colorsByValue and not NRSKNUI:IsSecretValue(max) and max ~= text.curveMax then
            PowerColorCurve(text, CDM:Get(from.owner.id), from.index, max)
        end

        -- the curve takes the percent even when it's secret and gives back a colour we can use
        if text.valueCurve and (from.powerType == CDM.MAELSTROM_WEAPON or from.powerType == CDM.STAGGER) then
            text.fs:SetTextColor(text.valueCurve:Evaluate((from.value or 0) / (from.max or 1)):GetRGBA())
        elseif text.valueCurve and from.powerType then
            local color = UnitPowerPercent('player', from.powerType --[[@as Enum.PowerType]], false, text.valueCurve) --[[@as colorRGBA]]
            text.fs:SetTextColor(color:GetRGBA())
        end
    end
end

---Feed a layer's texts their trigger's latest timing, charges and values.
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

    if layer.gatedTexts then
        self:UpdateStatCopies(layer)
    end
end

-- Copies --

---A copy of one of the layer's texts on another parent, read with another name: the same font, place, tokens and formats.
---@param layer CDMLayer
---@param ordinal number which of the layer's texts
---@param copy CDMIconText? the copy made last time
---@param parent Frame
---@param name string? what its %n reads, the layer's trigger name when nil
---@param triggers table[]? what its %N tokens read, the display's triggers when nil
---@return CDMIconText?
function CDM:StyleTextCopy(layer, ordinal, copy, parent, name, triggers)
    local own = layer.texts[ordinal]
    local element = own and own.element
    local display = layer.owner.id and self:Get(layer.owner.id)
    if not (element and display) then
        return copy
    end

    copy = copy or { kind = 'static', format = '', tokens = 0, ordinal = ordinal } --[[@as CDMIconText]]
    if not copy.fs then
        copy.fs = parent:CreateFontString(nil, 'OVERLAY')
    end

    local fs = copy.fs
    fs:SetFontStyle(element, element.FontSize, nil, nil, true)
    PlaceText(fs, element, layer.isBar and layer.Bar or layer, layer.isText and TEXT_PINS[element.Justify] or nil)
    fs:SetTextColor(unpack(element.Color))
    fs:SetShown(element.Enabled)

    triggers = triggers or display.Triggers
    ConfigureText(copy, element, name or self:GetTriggerName(triggers[layer.index] or {}) or '', layer, triggers)
    copy.source = nil -- it reads what it is handed, never another trigger
    return copy
end

---Feed a text copy its values, as UpdateTexts feeds a layer's own texts.
---@param copy CDMIconText
---@param from table anything with the fields a text reads (value, max, duration)
function CDM:UpdateTextCopy(copy, from)
    UpdateText(copy, from)
end

-- Live text --

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
        if text.usesName then
            ConfigureText(text, text.element, name, layer, display.Triggers)
        end
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
    if text.source then
        layer.sourced = true
    end
    UpdateText(text, text.source and layer.owner.layers[text.source] or layer)
end

-- what the layer, aura button and bar pip files build their texts with
CDM.Text = {
    Acquire = AcquireText,
    Expand = ExpandText,
    DurationFormat = DurationFormat,
    Configure = ConfigureText,
    Place = PlaceText,
    LITERAL_PERCENT = LITERAL_PERCENT,
    PINS = TEXT_PINS,
    TIME_SCALES = TIME_SCALES,
}

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local CreateFrame = CreateFrame
local strfind = string.find
local strmatch = string.match
local tonumber = tonumber
local gsub = string.gsub
local unpack = unpack
local setmetatable = setmetatable

local CreateDurationTextBinding = C_DurationUtil and C_DurationUtil.CreateDurationTextBinding
local GetSpellDisplayCount = C_Spell and C_Spell.GetSpellDisplayCount
local GetSpellCastCount = C_Spell and C_Spell.GetSpellCastCount
local TruncateWhenZero = C_StringUtil and C_StringUtil.TruncateWhenZero
local CreateColorCurve = C_CurveUtil and C_CurveUtil.CreateColorCurve
local CreateColor = CreateColor
local UnitPowerPercent = UnitPowerPercent

-- Number formats for value texts; each takes a secret number (LocalizationDocumentation, AllowedWhenTainted).
local ABBREVIATORS = { abbreviate = AbbreviateNumbers, large = AbbreviateLargeNumbers, breakup = BreakUpLargeNumbers }
local LITERAL_PERCENT = '\001' -- a typed %%, until the text's kind decides how a percent sign is written

local BindingProperty = Enum.DurationTextBindingProperty

local TEXT_ROTATIONS = { LEFT = math.pi / 2, RIGHT = -math.pi / 2 }
local TEXT_PINS = { LEFT = 'LEFT', RIGHT = 'RIGHT', CENTER = 'CENTER', AUTO = 'CENTER' } -- a text display's text, by its alignment

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

-- What the layer, aura button and bar pip files build their texts with.
CDM.Text = {
    Acquire = AcquireText,
    Expand = ExpandText,
    DurationFormat = DurationFormat,
    Configure = ConfigureText,
    Place = PlaceText,
    Update = UpdateText,
    LITERAL_PERCENT = LITERAL_PERCENT,
    PINS = TEXT_PINS,
}

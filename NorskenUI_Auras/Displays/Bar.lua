---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local PlaceText = CDM.Text.Place
local ConfigureText = CDM.Text.Configure
local StyleBorder = CDM.Layer.StyleBorder

--[[
Bar layers: the fill, its icon and spark, timers and values, split resource bars and their pips,
ticks, aura overlays painted over a bar and the cast's latency shade.
]]

local tonumber, tostring = tonumber, tostring
local ipairs, pairs = ipairs, pairs
local CreateFrame = CreateFrame
local unpack = unpack
local max = math.max

local CreateDuration = C_DurationUtil and C_DurationUtil.CreateDuration

local SMOOTH = Enum and Enum.StatusBarInterpolation.ExponentialEaseOut
local REMAINING = Enum and Enum.StatusBarTimerDirection.RemainingTime
local ELAPSED = Enum and Enum.StatusBarTimerDirection.ElapsedTime
local IMMEDIATE = Enum and Enum.StatusBarInterpolation.Immediate

CDM.BAR_REMAINING = REMAINING
CDM.BAR_ELAPSED = ELAPSED

-- Bar --

-- The moving edge of the fill, normal and reversed.
local FILL_EDGE = {
    HORIZONTAL = { 'RIGHT', 'LEFT' },
    VERTICAL = { 'TOP', 'BOTTOM' },
}

-- Per icon side: the bar corner that meets the icon, the icon corner and the bar's far corner on the layer.
local ICON_SIDES = {
    LEFT = { 'TOPLEFT', 'TOPRIGHT', 'BOTTOMRIGHT' },
    RIGHT = { 'TOPRIGHT', 'TOPLEFT', 'BOTTOMLEFT' },
    TOP = { 'TOPLEFT', 'BOTTOMLEFT', 'BOTTOMRIGHT' },
    BOTTOM = { 'BOTTOMLEFT', 'TOPLEFT', 'TOPRIGHT' },
}

---A status bar with its background and spark, for a bar layer or an aura button's bar.
---@param parent Frame
---@return CDMBar
local function NewBar(parent)
    local bar = CreateFrame('StatusBar', nil, parent) --[[@as CDMBar]]
    bar.bg = bar:CreateTexture(nil, 'BACKGROUND')
    bar.bg:SetAllPoints()
    bar.spark = bar:CreateTexture(nil, 'OVERLAY')
    bar.spark:SetBlendMode('ADD')
    bar.spark:NUISetPixelSnap() -- the spark glides between pixels, the fill stays snapped or its edge smears
    return bar
end

---Lay `bar` out over `area` beside its icon, with the style's texture, direction, background and spark.
---@param bar CDMBar
---@param icon Texture
---@param area Frame the space the icon and bar share
---@param style table
---@return number thickness the bar's short side, which the icon is square to
local function ShapeBar(bar, icon, area, style)
    local vertical = style.Orientation == 'VERTICAL'
    local thickness = vertical and style.Width or style.Height

    bar:ClearAllPoints()
    icon:ClearAllPoints()
    if style.IconShow then
        -- on a vertical bar Left and Right mean its top and bottom, and the other way round
        local side = style.IconSide
        if vertical and (side == 'LEFT' or side == 'RIGHT') then
            side = side == 'LEFT' and 'TOP' or 'BOTTOM'
        end
        if not vertical and (side == 'TOP' or side == 'BOTTOM') then
            side = side == 'TOP' and 'LEFT' or 'RIGHT'
        end
        icon:NUISetPixelSize(thickness, thickness)
        icon:NUISetPixelPoint(side, area, side, 0, 0)
        local corners = ICON_SIDES[side]
        bar:NUISetPixelPoint(corners[1], icon, corners[2], 0, 0)
        bar:NUISetPixelPoint(corners[3], area, corners[3], 0, 0)
    else
        bar:SetAllPoints(area)
    end

    bar:SetStatusBarTexture(NRSKNUI:GetStatusbar(style))
    bar:SetOrientation(vertical and 'VERTICAL' or 'HORIZONTAL')
    bar:SetReverseFill(style.ReverseFill == true)
    bar.bg:SetTexture(NRSKNUI:GetBarBackground(style) or NRSKNUI.WhiteTexture)
    bar.bg:SetVertexColor(unpack(style.BackgroundColor))

    local spark = bar.spark
    spark:ClearAllPoints()
    if style.Spark then
        NRSKNUI:SetSpark(spark, style, thickness)
        if vertical then
            local width, height = spark:GetSize()
            spark:NUISetPixelSize(height, width)
        end
        spark:SetRotation(vertical and math.pi / 2 or 0)
        spark:SetPoint('CENTER', bar:GetStatusBarTexture(), FILL_EDGE[vertical and 'VERTICAL' or 'HORIZONTAL'][style.ReverseFill and 2 or 1], 0, 0)
    end
    spark:SetShown(style.Spark == true)
    return thickness
end

---@param layer CDMLayer
---@return CDMBar
local function CreateBar(layer)
    local bar = NewBar(layer)
    bar.latency = CreateFrame('StatusBar', nil, bar)
    bar.latency:SetAllPoints()
    bar.latency:SetStatusBarTexture(NRSKNUI.WhiteTexture)
    bar.latency:SetMinMaxValues(0, 1)
    bar.latency:Hide()
    layer.Bar = bar
    return bar
end

---@param layer CDMLayer
---@param pip CDMPip
local function PaintPip(layer, pip)
    local paint = pip.color or layer.barColor
    if not paint then return end

    pip:SetStatusBarColor(paint[1], paint[2], paint[3], paint[4] or 1)
    if pip.progressFill then
        pip.progressFill:SetVertexColor(paint[1], paint[2], paint[3], paint[4] or 1)
    end
end

---Paint the bar the trigger's color, unless a condition holds its own color over it.
---@param layer CDMLayer
---@param color number[]?
function CDM:PaintBar(layer, color)
    layer.barColor = color
    local paint = layer.barColorOverride or color
    if paint and layer.Bar then
        local split = (layer.pipCount or 0) > 0 -- a split bar hides its own fill through the colour: a texture SetAlpha(0) didn't stick and it showed in the gaps
        layer.Bar:SetStatusBarColor(paint[1], paint[2], paint[3], split and 0 or paint[4] or 1)
    end
    for i = 1, layer.pipCount or 0 do
        PaintPip(layer, layer.pips[i])
    end
end

---The bar's color from its style; a power trigger paints over it in Power Color mode.
---@param layer CDMLayer
---@param style table
function CDM:ResetBarColor(layer, style)
    if style.BarColorMode == 'class' then
        local color = NRSKNUI:GetPlayerClassColor()
        color[4] = style.BarColor[4] or 1
        self:PaintBar(layer, color)
    else
        self:PaintBar(layer, style.BarColor)
    end
end

---A bar layer's icon on one side and the bar over the rest, an icon layer its whole icon, a text layer neither.
---@param layer CDMLayer
---@param style table
---@param kind 'icon'|'bar'|'text'
---@param level number the layer's frame level
function CDM:StyleBarLayer(layer, style, kind, level)
    local icon = layer.Icon
    -- One bar again until a power trigger's Resolve splits it, which also restyles its pips.
    if (layer.pipCount or 0) > 0 then
        self:SetLayerPips(layer, 0)
    end
    layer.pipsStyled = nil
    layer.isBar = kind == 'bar'
    layer.isText = kind == 'text'
    if kind ~= 'bar' then
        if layer.Bar then
            layer.Bar:Hide()
        end
        icon:ClearAllPoints()
        icon:SetAllPoints()
        icon:SetShown(kind == 'icon') -- a text's swipe stays off through its style template
        return
    end

    local bar = layer.Bar or CreateBar(layer)
    layer.barThickness = ShapeBar(bar, icon, layer, style)
    icon:SetShown(style.IconShow == true)
    bar.spark:SetAlpha(0) -- shown by a running timer or a value between empty and full
    bar:SetFrameLevel(level + 1)
    layer.barColorOverride = nil
    self:ResetBarColor(layer, style)

    -- The cooldown stays on the bar's icon so expiring timers still wake the display, but draws nothing.
    layer.Cooldown:SetDrawSwipe(false)
    layer.Cooldown:SetDrawEdge(false)
    layer.Cooldown:SetHideCountdownNumbers(true)
    bar:Show()
end

-- Aura bar --

---A lone aura's bar inside its aura button, which fills it from the aura's duration or stacks (Blizzard_CustomAuraButton.lua, live).
---The top of an aura stacks bar: the trigger's Max Stacks, unless a condition sets it (a talent that adds stacks).
---@param layer CDMLayer
---@param trigger table
---@return number
function CDM:GetMaxStacks(layer, trigger)
    return layer.owner.conditionMaxStacks or trigger.MaxStacks or 10
end

---@param layer CDMLayer
---@param button table the real aura button
---@param refs table its regions, see InitAuraButton
---@param style table
---@param trigger table
---@return StatusBar bar what the button's texts sit on
function CDM:StyleAuraBar(layer, button, refs, style, trigger)
    local bar = refs.bar
    if not bar then
        bar = NewBar(button)
        refs.bar = bar
    end

    ShapeBar(bar, refs.icon, refs.inner, style)
    bar:SetFrameLevel(refs.cooldown:GetFrameLevel())
    local color = style.BarColorMode == 'class' and NRSKNUI:GetPlayerClassColor() or style.BarColor
    bar:SetStatusBarColor(color[1], color[2], color[3], style.BarColor[4] or 1)

    local interpolation = style.Smooth and SMOOTH or IMMEDIATE
    if trigger.BarMode == 'stacks' then
        button:ClearDurationBar()
        button:SetApplicationBar(bar, { maxApplications = self:GetMaxStacks(layer, trigger), interpolation = interpolation })
    else
        button:ClearApplicationBar()
        button:SetDurationBar(bar, { direction = style.Inverse and ELAPSED or REMAINING, interpolation = interpolation })
    end
    bar:Show()
    return bar
end

---An aura button back to an icon, when its pooled frame now serves an icon display.
---@param button table
---@param refs table
function CDM:ClearAuraBar(button, refs)
    if not refs.bar then return end
    button:ClearDurationBar()
    button:ClearApplicationBar()
    refs.bar:Hide()
    refs.icon:ClearAllPoints()
    refs.icon:SetAllPoints(refs.inner)
end

-- Timer and value --

---The layer's timer: the icon's swipe and a bar's fill; cooldowns drain by default, a cast fills.
---@param layer CDMLayer
---@param duration LuaDurationObject?
---@param direction number? Enum.StatusBarTimerDirection, RemainingTime by default
function CDM:SetLayerTimer(layer, duration, direction)
    if duration then
        layer.Cooldown:SetCooldownFromDurationObject(duration)
    else
        layer.Cooldown:Clear()
    end
    if not layer.isBar then return end

    local bar = layer.Bar
    local style = layer.owner.style
    local inverse = style.Inverse == true
    if duration then
        direction = direction or REMAINING
        if inverse then
            direction = direction == ELAPSED and REMAINING or ELAPSED
        end
        bar:SetTimerDuration(duration, style.Smooth and SMOOTH or IMMEDIATE, direction)
    else
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(inverse and 1 or 0) -- an explicit value takes the bar off its timer
    end
    bar.spark:SetAlpha(duration and 1 or 0)
end

---Show a value on a bar; secret values go straight to the widget.
---@param layer CDMLayer
---@param value number
---@param maxValue number
---@param sparkAlpha number? from NRSKNUI.curves.BarSparkAlpha, possibly secret; hidden when omitted
function CDM:SetLayerValue(layer, value, maxValue, sparkAlpha)
    layer.Cooldown:Clear()
    if not layer.isBar then return end

    local interpolation = layer.owner.style.Smooth and SMOOTH or IMMEDIATE
    layer.Bar:SetMinMaxValues(0, maxValue, interpolation)
    layer.Bar:SetValue(value, interpolation)
    layer.Bar.spark:SetAlpha(sparkAlpha or 0)
end

-- Progress source --

---A hidden bar that mirrors a tracked bar's remaining time from the far end; the shown fill runs up to its edge, so no secret is ever compared (the CSAA Tracker trick).
---@param layer CDMLayer
---@return StatusBar source what a tracked bar is mirrored onto
function CDM:GetLayerProgress(layer)
    local progress = layer.progress
    if not progress then
        local source = CreateFrame('StatusBar', nil, layer.Bar)
        source:SetAllPoints()
        source:SetStatusBarTexture('Interface\\Buttons\\WHITE8X8')
        source:GetStatusBarTexture():SetAlpha(0)
        source:Hide()
        progress = { source = source }
        layer.progress = progress
    end
    return progress.source
end

---@param layer CDMLayer
---@param shown boolean
---@param bar CDMBar|CDMPip|nil where it fills: the layer's bar or a split bar's filling pip
function CDM:ShowLayerProgress(layer, shown, bar)
    local progress = layer.progress
    if not (progress and layer.isBar) then return end

    bar = bar or layer.Bar
    if progress.bar ~= bar then
        if progress.fill then
            progress.fill:Hide()
        end
        bar.progressFill = bar.progressFill or bar:CreateTexture(nil, 'ARTWORK', nil, 1)
        progress.fill, progress.bar = bar.progressFill, bar
        progress.source:ClearAllPoints()
        progress.source:SetAllPoints(bar)
    end
    progress.source:SetShown(shown)
    progress.fill:SetShown(shown)
    if not shown then return end

    local source, fill = progress.source, progress.fill
    local vertical, reverse = bar:GetOrientation() == 'VERTICAL', bar:GetReverseFill()
    source:SetOrientation(bar:GetOrientation())
    source:SetReverseFill(not reverse)
    local edge = source:GetStatusBarTexture()
    fill:ClearAllPoints()
    if vertical and reverse then
        fill:SetPoint('TOPLEFT', bar, 'TOPLEFT')
        fill:SetPoint('BOTTOMRIGHT', edge, 'TOPRIGHT')
    elseif vertical then
        fill:SetPoint('BOTTOMLEFT', bar, 'BOTTOMLEFT')
        fill:SetPoint('TOPRIGHT', edge, 'BOTTOMRIGHT')
    elseif reverse then
        fill:SetPoint('TOPRIGHT', bar, 'TOPRIGHT')
        fill:SetPoint('BOTTOMLEFT', edge, 'BOTTOMRIGHT')
    else
        fill:SetPoint('TOPLEFT', bar, 'TOPLEFT')
        fill:SetPoint('BOTTOMRIGHT', edge, 'BOTTOMLEFT')
    end
    fill:SetTexture(bar:GetStatusBarTexture():GetTexture())
    fill:SetVertexColor(bar:GetStatusBarColor())
end

-- Pips --

-- Per orientation and fill direction: a pip's leading corner and the boundary fill corner it sits on,
-- then its trailing corner and the next boundary's.
local PIP_CORNERS = {
    HORIZONTAL = {
        { 'TOPLEFT',  'TOPRIGHT', 'BOTTOMRIGHT', 'BOTTOMRIGHT' },
        { 'TOPRIGHT', 'TOPLEFT',  'BOTTOMLEFT',  'BOTTOMLEFT' },
    },
    VERTICAL = {
        { 'BOTTOMLEFT', 'TOPLEFT',    'TOPRIGHT',    'TOPRIGHT' },
        { 'TOPLEFT',    'BOTTOMLEFT', 'BOTTOMRIGHT', 'BOTTOMRIGHT' },
    },
}
-- The direction pips run in, which spacing offsets follow.
local PIP_AXIS = {
    HORIZONTAL = { { 1, 0 }, { -1, 0 } },
    VERTICAL = { { 0, 1 }, { 0, -1 } },
}

---@param bar CDMBar
---@return CDMPip
local function CreatePip(bar)
    local pip = CreateFrame('StatusBar', nil, bar) --[[@as CDMPip]]
    pip.bg = pip:CreateTexture(nil, 'BACKGROUND')
    pip.bg:SetAllPoints()
    pip.timer = CreateDuration()
    pip.timer:SetTimeFromStart(0, 0)
    pip.texts, pip.borders = {}, {}
    return pip
end

---An invisible fill to `fraction` of the bar whose edge a pip boundary rides; being anchored, it follows
---a Match Width bar's width, which we may never read (the same trick as the ticks).
---@param layer CDMLayer
---@param index number
---@param fraction number
---@param vertical boolean
---@param reverse boolean
---@return Texture
local function PipBoundary(layer, index, fraction, vertical, reverse)
    local host = layer.pipEdges[index]
    if not host then
        host = CreateFrame('StatusBar', nil, layer.Bar)
        host:SetAllPoints()
        host:SetStatusBarTexture(NRSKNUI.WhiteTexture)
        host:GetStatusBarTexture():SetAlpha(0)
        host:SetMinMaxValues(0, 1)
        layer.pipEdges[index] = host
    end
    host:SetOrientation(vertical and 'VERTICAL' or 'HORIZONTAL')
    host:SetReverseFill(reverse)
    host:SetValue(fraction)
    host:Show()
    return host:GetStatusBarTexture()
end

---Put `pip` in place `slot` of its split bar, between the boundaries either side of it.
---@param layer CDMLayer
---@param pip CDMPip
---@param slot number
local function AnchorPip(layer, pip, slot)
    local layout, count, edges = layer.pipLayout, layer.pipCount, layer.pipEdges
    local corners, dx, dy = layout.corners, layout.dx, layout.dy
    local before = slot > 1 and edges[slot - 1]:GetStatusBarTexture() or nil
    local after = slot < count and edges[slot]:GetStatusBarTexture() or nil
    local lead, trail = (slot - 1) * layout.share, (slot - count) * layout.share
    pip:ClearAllPoints()
    pip:SetPoint(corners[1], before or layer.Bar, before and corners[2] or corners[1], dx * lead, dy * lead)
    pip:SetPoint(corners[3], after or layer.Bar, after and corners[4] or corners[3], dx * trail, dy * trail)
    pip.slot = slot
end

---Split a bar layer into `count` pips, each its own fill; 0 makes it one bar again. Every boundary gives up the
---spacing in equal shares, so the pips come out the same size and the gaps exact once they snap to pixels.
---@param layer CDMLayer
---@param count number
function CDM:SetLayerPips(layer, count)
    if layer.pipCount == count and layer.pipsStyled then return end
    layer.pipCount, layer.pipsStyled = count, true
    local bar = layer.Bar --[[@as CDMBar]]
    local pips, edges = layer.pips or {}, layer.pipEdges or {}
    layer.pips, layer.pipEdges = pips, edges
    bar.bg:SetShown(count == 0)

    if count > 0 then
        local style = layer.owner.style
        local vertical, reverse = style.Orientation == 'VERTICAL', style.ReverseFill == true
        local orientation, direction = vertical and 'VERTICAL' or 'HORIZONTAL', reverse and 2 or 1
        local axis = PIP_AXIS[orientation][direction]
        layer.pipLayout = {
            corners = PIP_CORNERS[orientation][direction],
            dx = axis[1],
            dy = axis[2],
            share = style.PipSpacing / count,
        }
        local texture = NRSKNUI:GetStatusbar(style)
        local background = NRSKNUI:GetBarBackground(style) or NRSKNUI.WhiteTexture
        for i = 1, count - 1 do
            PipBoundary(layer, i, i / count, vertical, reverse)
        end
        for i = 1, count do
            local pip = pips[i] or CreatePip(bar)
            pips[i] = pip
            pip.timerStart, pip.timerLength, pip.waiting = nil, nil, nil
            pip:SetFrameLevel(bar:GetFrameLevel()) -- under the ticks and borders, which share the next level
            AnchorPip(layer, pip, i)
            pip:SetStatusBarTexture(texture)
            pip:SetOrientation(vertical and 'VERTICAL' or 'HORIZONTAL')
            pip:SetReverseFill(reverse)
            pip.bg:SetTexture(background)
            pip.bg:SetVertexColor(unpack(style.BackgroundColor))
            pip:Show()
        end
    end
    for i = count + 1, #pips do
        pips[i]:Hide()
    end
    for i = max(count, 1), #edges do
        edges[i]:Hide()
    end
    self:StylePips(layer)
    self:PaintBar(layer, layer.barColor)
    self:AnchorBarOverlays(layer.owner)
end

-- A spent rune moves to its new place as it empties; easing would drain it there after the move.
---@param layer CDMLayer
---@return number
local function PipInterpolation(layer)
    return layer.owner.style.Smooth and layer.powerType ~= Enum.PowerType.Runes and SMOOTH or IMMEDIATE
end

---@param pip CDMPip
local function UpdatePipTexts(pip)
    for _, text in pairs(pip.texts) do
        if text.kind == 'duration' then
            text.binding:SetDuration(pip.timer)
        end
    end
end

---Move pip `index` to place `slot`; runes keep their own pip and only change places, as Blizzard's RuneFrame does.
---@param layer CDMLayer
---@param index number
---@param slot number
function CDM:SetLayerPipSlot(layer, index, slot)
    local pip = layer.pips[index]
    if pip.slot ~= slot then
        AnchorPip(layer, pip, slot)
    end
end

---Pip `index` filling over `length` seconds from `start`: a recharging rune, the filling Essence.
---@param layer CDMLayer
---@param index number
---@param start number
---@param length number
function CDM:SetLayerPipTimer(layer, index, start, length)
    local pip = layer.pips[index]
    if pip.timerStart == start and pip.timerLength == length then return end
    pip.timerStart, pip.timerLength = start, length
    pip.timer:SetTimeFromStart(start, length)
    pip:SetTimerDuration(pip.timer, PipInterpolation(layer), ELAPSED)
    pip.recharging = true
    UpdatePipTexts(pip)
end

---Pip `index` at a value in its range; the value may be secret, the widget compares it.
---@param layer CDMLayer
---@param index number
---@param value number
---@param maxValue number
---@param minValue number
---@param recharging boolean
---@param start number? with `length`, what its texts count down while the fill holds still: a Static mode rune
---@param length number?
function CDM:SetLayerPipValue(layer, index, value, maxValue, minValue, recharging, start, length)
    local pip = layer.pips[index]
    local interpolation = PipInterpolation(layer)
    pip.timerStart, pip.timerLength = nil, nil
    pip.timer:SetTimeFromStart(start or 0, length or 0)
    pip:SetMinMaxValues(minValue, maxValue, interpolation)
    pip:SetValue(value, interpolation)
    pip.recharging = recharging
    UpdatePipTexts(pip)
end

---A condition's Bar Color on one pip; nil gives it the bar's colour back.
---@param layer CDMLayer
---@param index number
---@param color number[]?
function CDM:SetLayerPipColor(layer, index, color)
    local pip = layer.pips[index]
    if pip.color == color then return end
    pip.color = color
    PaintPip(layer, pip)
end

-- Pip texts and borders --

---Copy the texts and borders marked Each Rune onto every pip of a split bar; the layer's own copies hide.
---@param layer CDMLayer
function CDM:StylePips(layer)
    local count = layer.pipCount or 0
    for _, pip in ipairs(layer.pips or {}) do
        for _, text in pairs(pip.texts) do
            if text.binding then
                text.binding:SetToDefaults()
            end
            text.kind = 'static'
            text.fs:Hide()
        end
        for _, border in pairs(pip.borders) do
            border:Hide()
        end
    end
    -- Un-splitting runs from StyleBarLayer, before StyleLayer grows layer.texts for a newly added element.
    if count == 0 then
        for _, own in ipairs(layer.texts) do
            own.eachPip = nil
        end
        for _, own in ipairs(layer.borders) do
            own.eachPip = nil
        end
        return
    end

    local display = layer.owner.id and self:Get(layer.owner.id)
    local triggers = display and display.Triggers or {}
    local spellName = triggers[layer.index] and self:GetTriggerName(triggers[layer.index]) or ''
    local textOrdinal, borderOrdinal = 0, 0
    for _, element in ipairs(layer.subRegions or {}) do
        local each = element.EachPip == true
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
                        text = { fs = own.host:CreateFontString(nil, 'OVERLAY'), host = own.host, kind = 'static', format = '', tokens = 0, ordinal = textOrdinal } --[[@as CDMIconText]]
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

-- Ticks --

local NO_TICKS = {}

---A tick element's places as fractions of the bar; At Value reads the trigger's maximum (power or a cast's seconds).
---@param layer CDMLayer
---@param element table
---@return number[]
local function TickFractions(layer, element)
    if element.Placement == 'auto' then
        return layer.autoTicks or NO_TICKS
    end
    local list = {}
    for text in tostring(element.Placements or ''):gmatch('[%d%.]+') do
        local number = tonumber(text)
        if number then
            list[#list + 1] = number
        end
    end
    local scale = 100
    if element.Placement == 'value' then
        scale = layer.max
        if scale == nil or NRSKNUI:IsSecretValue(scale) or scale <= 0 then
            return NO_TICKS
        end
    end
    for i, value in ipairs(list) do
        list[i] = value / scale
    end
    return list
end

---@param layer CDMLayer
---@param set CDMTickSet
---@param index number
---@param fraction number
---@param bar StatusBar the layer's own bar or the real aura button's
local function PlaceTick(layer, set, index, fraction, bar)
    local host = set.hosts[index]
    if not host then
        host = CreateFrame('StatusBar', nil, bar) --[[@as CDMTickHost]]
        host:SetAllPoints()
        host:SetStatusBarTexture(NRSKNUI.WhiteTexture)
        host:GetStatusBarTexture():SetAlpha(0)
        host:SetMinMaxValues(0, 1)
        host.mark = host:CreateTexture(nil, 'OVERLAY')
        host.mark:SetTexture(NRSKNUI.WhiteTexture)
        host.mark:NUISetPixelSnap()
        set.hosts[index] = host
    end

    local element = set.element
    local style = layer.owner.style
    local vertical = style.Orientation == 'VERTICAL'
    local reverse = style.ReverseFill == true
    host:SetFrameLevel(set.level or bar:GetFrameLevel() + 1)
    host:SetOrientation(vertical and 'VERTICAL' or 'HORIZONTAL')
    host:SetReverseFill(reverse)
    host:SetValue(fraction)

    local mark = host.mark
    local length = element.AutoLength and layer.barThickness or element.Length
    mark:ClearAllPoints()
    mark:SetPoint('CENTER', host:GetStatusBarTexture(), FILL_EDGE[vertical and 'VERTICAL' or 'HORIZONTAL'][reverse and 2 or 1])
    if vertical then
        mark:NUISetPixelSize(length, element.Thickness)
    else
        mark:NUISetPixelSize(element.Thickness, length)
    end
    mark:SetVertexColor(unpack(set.color or element.Color))
    host:Show()
end

---Draw every tick element of a bar layer where its placement says.
---@param layer CDMLayer
function CDM:DrawTicks(layer)
    for _, set in ipairs(layer.tickSets or NO_TICKS) do
        local used = 0
        local element = set.element
        if element and layer.isBar and not set.hidden then
            for _, fraction in ipairs(TickFractions(layer, element)) do
                if fraction > 0 and fraction < 1 then
                    used = used + 1
                    PlaceTick(layer, set, used, fraction, layer.Bar --[[@as CDMBar]])
                end
            end
        end
        for i = used + 1, #set.hosts do
            set.hosts[i]:Hide()
        end
    end
end

---@param layer CDMLayer
---@param subRegions table[]
function CDM:StyleTicks(layer, subRegions)
    local sets = layer.tickSets or {}
    layer.tickSets = sets
    local count = 0
    for _, element in ipairs(subRegions) do
        if element.type == 'tick' then
            count = count + 1
            local set = sets[count] or { hosts = {} }
            sets[count] = set
            set.element, set.hidden, set.color = element, not element.Enabled, nil
        end
    end
    for i = count + 1, #sets do
        sets[i].element = nil
    end
    self:DrawTicks(layer)
end

---The tick places a trigger offers its Automatic ticks: power segments, channel ticks, empower stages.
---@param layer CDMLayer
---@param fractions number[]?
function CDM:SetLayerTicks(layer, fractions)
    if layer.autoTicks == fractions then return end
    layer.autoTicks = fractions
    self:DrawTicks(layer)
end

local stackFractions = {} -- [max stacks] = the place of every stack but the last

---An aura stacks bar counts up to its Max Stacks: Automatic ticks mark every stack and At Value counts in stacks.
---@param layer CDMLayer
---@param trigger table
function CDM:SetStackTicks(layer, trigger)
    local maxStacks = layer.isBar and trigger.BarMode == 'stacks' and self:GetMaxStacks(layer, trigger) or nil
    layer.max = maxStacks
    local fractions = maxStacks and stackFractions[maxStacks]
    if maxStacks and not fractions then
        fractions = {}
        for i = 1, maxStacks - 1 do
            fractions[i] = i / maxStacks
        end
        stackFractions[maxStacks] = fractions
    end
    self:SetLayerTicks(layer, fractions)
end

---Ticks on the real aura button's bar. They live inside the button so they hide with it when the aura
---goes, which nothing outside can tell while auras are secret, so they are styled with the rest of it.
---@param layer CDMLayer
---@param refs table the button's regions, see InitAuraButton
---@param subRegions table[]
function CDM:StyleAuraTicks(layer, refs, subRegions)
    local sets = refs.tickSets or {}
    refs.tickSets = sets
    local count = 0
    for _, element in ipairs(subRegions) do
        if element.type == 'tick' then
            count = count + 1
            local set = sets[count] or { hosts = {} }
            sets[count] = set
            local used = 0
            if element.Enabled then
                set.element, set.level = element, nil
                for _, fraction in ipairs(TickFractions(layer, element)) do
                    if fraction > 0 and fraction < 1 then
                        used = used + 1
                        PlaceTick(layer, set, used, fraction, refs.bar)
                    end
                end
            end
            for i = used + 1, #set.hosts do
                set.hosts[i]:Hide()
            end
        end
    end
    for i = count + 1, #sets do
        for _, host in ipairs(sets[i].hosts) do
            host:Hide()
        end
    end
end

-- Aura overlay parts --

-- An aura overlay on a bar paints over the bar below it, as the unit frames' aura tints do: proxies of ours ride
-- the bar's fills and textures inside the aura button cover them, so they size and show themselves with the aura.

local OVERLAY_PARTS = { 'barOverlay', 'missingOverlay', 'fillOverlay' } -- bottom to top
local OVERLAY_PROXIES = 10                                              -- more than any split resource has pips; the button can't grow more once auras are secret

-- Per orientation and fill direction: the missing part's corner on the fill's moving edge, that edge's corner and its far corner.
local MISSING_CORNERS = {
    HORIZONTAL = { { 'TOPLEFT', 'TOPRIGHT', 'BOTTOMRIGHT' }, { 'TOPRIGHT', 'TOPLEFT', 'BOTTOMLEFT' } },
    VERTICAL = { { 'BOTTOMLEFT', 'TOPLEFT', 'TOPRIGHT' }, { 'TOPLEFT', 'BOTTOMLEFT', 'BOTTOMRIGHT' } },
}

---@param layer CDMLayer
---@param part string
---@param index number
---@param target StatusBar? the pip or bar it covers, nil parks it at no size
local function AnchorProxy(layer, part, index, target)
    local proxy = layer.overlayProxies[part][index]
    proxy:ClearAllPoints()
    if not target then
        proxy:SetPoint('CENTER', layer)
        proxy:SetSize(0, 0)
    elseif part == 'barOverlay' then
        proxy:SetAllPoints(target)
    elseif part == 'fillOverlay' then
        proxy:SetAllPoints(target:GetStatusBarTexture())
    else
        local corners = MISSING_CORNERS[target:GetOrientation() == 'VERTICAL' and 'VERTICAL' or 'HORIZONTAL'][target:GetReverseFill() and 2 or 1]
        proxy:SetPoint(corners[1], target:GetStatusBarTexture(), corners[2], 0, 0)
        proxy:SetPoint(corners[3], target, corners[3], 0, 0)
    end
end

---Point every aura overlay of a bar display at the bar it covers, the first trigger's that isn't an overlay.
---@param frame CDMIcon
function CDM:AnchorBarOverlays(frame)
    local display = frame.id and self:Get(frame.id)
    if not display then return end

    local base
    for i, trigger in ipairs(display.Triggers) do
        if trigger.Type ~= 'auraoverlay' then
            base = frame.layers[i]
            break
        end
    end
    local pipCount = base and base.isBar and base.pipCount or 0
    for i, trigger in ipairs(display.Triggers) do
        local layer = frame.layers[i]
        if layer and trigger.Type == 'auraoverlay' and (display.type == 'bar' or layer.overlayProxies) then
            if not layer.overlayProxies then
                layer.overlayProxies = {}
                for _, part in ipairs(OVERLAY_PARTS) do
                    layer.overlayProxies[part] = {}
                    for n = 1, OVERLAY_PROXIES do
                        layer.overlayProxies[part][n] = CreateFrame('Frame', nil, layer)
                    end
                end
            end
            for _, part in ipairs(OVERLAY_PARTS) do
                for n = 1, OVERLAY_PROXIES do
                    local target
                    if display.type == 'bar' and base and base.isBar then
                        if pipCount > 0 then
                            target = n <= pipCount and base.pips[n] or nil
                        else
                            target = n == 1 and base.Bar or nil
                        end
                    end
                    AnchorProxy(layer, part, n, target)
                end
            end
        end
    end
end

---Paint an aura overlay's parts from its While Up changes onto textures covering its proxies: the aura button's,
---or the layer's own for the options preview.
---@param layer CDMLayer
---@param store table<string, Texture[]> the textures by part, filled on first need
---@param parent Frame
---@param active table the While Up changes
function CDM:PaintBarOverlay(layer, store, parent, active)
    local proxies = layer.overlayProxies
    local texture = NRSKNUI:GetStatusbar(layer.owner.style)
    for sublevel, part in ipairs(OVERLAY_PARTS) do
        local color = proxies and active[part] or nil
        local textures = store[part]
        if color and not textures then
            textures = {}
            for n = 1, OVERLAY_PROXIES do
                local region = parent:CreateTexture(nil, 'ARTWORK', nil, sublevel)
                region:SetAllPoints(proxies[part][n])
                textures[n] = region
            end
            store[part] = textures
        end
        for _, region in ipairs(textures or {}) do
            if color then
                region:SetTexture(texture)
                region:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
            end
            region:SetShown(color ~= nil)
        end
    end
end

---Shade the last (or first) `fraction` of the bar, the cast's latency.
---@param layer CDMLayer
---@param fraction number? nil hides it
---@param atStart boolean shade from where the fill starts instead of where it ends
---@param color number[]?
function CDM:SetBarLatency(layer, fraction, atStart, color)
    local bar = layer.Bar
    if not bar then return end

    local latency = bar.latency
    if not (fraction and fraction > 0 and color) then
        latency:Hide()
        return
    end

    local style = layer.owner.style
    latency:SetOrientation(style.Orientation == 'VERTICAL' and 'VERTICAL' or 'HORIZONTAL')
    latency:SetReverseFill((style.ReverseFill == true) == atStart) -- from the fill's start or back from its end
    latency:SetValue(fraction > 1 and 1 or fraction)
    latency:SetStatusBarColor(unpack(color))
    latency:Show()
end

---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

--[[
Everything a condition can change on a display and how to put it back.
'base' is the value with no condition on it. Desaturate has none, since the trigger resets it every update anyway.
X and Y Offset aren't here: they move the whole display, so EvaluateConditions puts them on the frame itself.
]]

local tonumber = tonumber
local ipairs = ipairs
local unpack = unpack

-- Regions --

---@param display table
---@param index number SubRegions index
---@return table? element, number? ordinal its position among elements of its type
local function SubElement(display, index)
    local element = display.SubRegions and display.SubRegions[index]
    if not element then return nil end

    local ordinal = 0
    for i = 1, index do
        if display.SubRegions[i].type == element.type then
            ordinal = ordinal + 1
        end
    end

    return element, ordinal
end

---Run 'fn' on a text or border's region, its copy on every pip with Each Rune and a text's copy in every stat gate.
---@param layer CDMLayer
---@param element table
---@param ordinal number
---@param fn fun(region: any)
local function EachRegion(layer, element, ordinal, fn)
    local key = element.type == 'text' and 'texts' or 'borders'
    local own = layer[key][ordinal]
    if not own then return end

    if key == 'texts' and layer.gatedTexts and layer.gatedTexts[ordinal] then
        for _, gate in ipairs(layer.statGates) do
            if gate.texts[ordinal] then
                fn(gate.texts[ordinal])
            end
        end
    end

    if not own.eachPip then
        return fn(own)
    end
    for i = 1, layer.pipCount do
        fn(layer.pips[i][key][ordinal])
    end
end

---Paint Visible or Color on one text or border region.
---@param element table
---@param region any a CDMIconText or CDMBorder
---@param name 'visible'|'subColor'
---@param value any
local function PaintRegion(element, region, name, value)
    if name == 'visible' then
        (region.fs or region):SetShown(value == true)
    elseif element.type == 'text' then
        region.fs:SetTextColor(unpack(value))
    else
        for _, edge in ipairs(region.edges) do
            edge:SetColorTexture(unpack(value))
        end
    end
end

-- Properties --

---@type table<string, { apply: fun(frame: CDMIcon, layer: CDMLayer, value: any, display: table, sub: number?), base?: fun(frame: CDMIcon, layer: CDMLayer, display: table, sub: number?): any }>
local PROPERTIES = {
    desaturate = {
        apply = function(_, layer, value)
            layer.Icon:SetDesaturated(value == true)
        end,
        -- only a trigger update resets it otherwise, which a combat or target change doesn't run
        base = function(frame)
            return frame.style.Desaturate
        end,
    },
    color = {
        apply = function(_, layer, value)
            layer.Icon:SetVertexColor(unpack(value))
        end,
        base = function(frame)
            return frame.style.Color
        end,
    },
    -- alpha is the display's, not a layer's: Derive sets it on the frame (see Engine.lua)
    swipe = {
        apply = function(_, layer, value)
            layer.Cooldown:SetDrawSwipe(value == true)
        end,
        base = function(frame)
            return frame.style.DrawSwipe
        end,
    },
    inverse = {
        apply = function(_, layer, value)
            layer.Cooldown:SetReverse(value == true)
        end,
        base = function(frame)
            return frame.style.Reverse
        end,
    },
    edge = {
        apply = function(_, layer, value)
            layer.Cooldown:SetDrawEdge(value == true)
        end,
        base = function(frame)
            return frame.style.DrawEdge
        end,
    },
    swipeColor = {
        apply = function(_, layer, value)
            layer.Cooldown:SetSwipeColor(unpack(value))
        end,
        base = function(frame)
            return frame.style.SwipeColor
        end,
    },
    barColor = {
        apply = function(_, layer, value)
            if not layer.isBar then return end

            layer.barColorOverride = value or nil
            CDM:PaintBar(layer, layer.barColor)
        end,
        base = function() -- clears the override, the trigger's own color shows again
            return false
        end,
    },
    -- The value lives on the frame (see EvaluateConditions and GetMaxStacks); this only redraws what reads it.
    maxStacks = {
        apply = function(_, layer)
            local trigger = layer.auraTrigger
            if not (layer.isBar and trigger) then return end

            CDM:SetStackTicks(layer, trigger)
            CDM:QueueAuraRestyle(layer, function()
                if layer.auraTrigger == trigger then
                    CDM:StyleAuraButton(layer, trigger)
                end
            end)
        end,
    },
    backgroundColor = {
        apply = function(_, layer, value)
            if not layer.isBar then return end

            layer.Bar.bg:SetVertexColor(unpack(value))
            for i = 1, layer.pipCount or 0 do
                layer.pips[i].bg:SetVertexColor(unpack(value))
            end
        end,
        base = function(frame)
            return frame.style.BackgroundColor
        end,
    },
    visible = {
        apply = function(frame, layer, value, display, sub)
            local element, ordinal = SubElement(display, sub)
            if not element then return end

            if element.type == 'glow' then
                local glow = layer.glows[ordinal]
                if glow and value then
                    glow:Start(element, frame.style.Width, frame.style.Height, true)
                elseif glow then
                    glow:Stop()
                end
                return
            end

            if element.type == 'tick' then
                local set = layer.tickSets and layer.tickSets[ordinal]
                if set then
                    set.hidden = value ~= true
                    CDM:DrawTicks(layer)
                end
                return
            end

            EachRegion(layer, element, ordinal, function(region)
                PaintRegion(element, region, 'visible', value)
            end)
        end,
        base = function(_, _, display, sub)
            local element = SubElement(display, sub)
            return element and element.Enabled
        end,
    },
    subColor = {
        apply = function(_, layer, value, display, sub)
            local element, ordinal = SubElement(display, sub)
            if not element then return end

            if element.type == 'tick' then
                local set = layer.tickSets and layer.tickSets[ordinal]
                if set then
                    set.color = value
                    CDM:DrawTicks(layer)
                end
            else
                EachRegion(layer, element, ordinal, function(region)
                    PaintRegion(element, region, 'subColor', value)
                end)
            end
        end,
        base = function(_, _, display, sub)
            local element = SubElement(display, sub)
            return element and element.Color
        end,
    },
    fontSize = {
        apply = function(_, layer, value, display, sub)
            local element, ordinal = SubElement(display, sub)
            if not (element and element.type == 'text') then return end

            EachRegion(layer, element, ordinal, function(region)
                region.fs:SetFontStyle(element, value, nil, nil, true)
            end)
        end,
        base = function(_, _, display, sub)
            local element = SubElement(display, sub)
            return element and element.FontSize
        end,
    },
    text = {
        apply = function(_, layer, value, display, sub)
            local element, ordinal = SubElement(display, sub)
            if not (element and element.type == 'text') then return end

            EachRegion(layer, element, ordinal, function(region)
                CDM:SetDisplayText(layer, region, element, value)
            end)
        end,
        base = function(_, _, display, sub)
            local element = SubElement(display, sub)
            return element and element.Text
        end,
    },
}

CDM.ConditionProperties = PROPERTIES

-- Lookups --

---A glow element's index in a layer's 'glows'.
---@param display table
---@param index number
---@return number
function CDM:GlowOrdinal(display, index)
    local _, ordinal = SubElement(display, index)
    return ordinal or 0
end

---'sub.3.color' -> 'subColor', 3; plain keys come back as they are.
---@param key string
---@return string property, number? sub
function CDM:SplitProperty(key)
    local index, name = key:match('^sub%.(%d+)%.(%a+)$')
    if index then
        return name == 'color' and 'subColor' or name, tonumber(index)
    end

    return key, nil
end

-- The per-pip condition pass uses these too.
CDM.ConditionRegions = { SubElement = SubElement, PaintRegion = PaintRegion }

---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local PROPERTIES = CDM.ConditionProperties
local SubElement = CDM.ConditionRegions.SubElement
local PaintRegion = CDM.ConditionRegions.PaintRegion
CDM.COMBINATIONS = { AND = true, OR = true }

--[[
Runs a display's conditions and puts their changes on it, taking them back off once they stop matching.
Also keeps conditions pointing at the right triggers and sub elements when those move.
]]

local ipairs, pairs, next = ipairs, pairs, next
local tremove, tsort = table.remove, table.sort
local tonumber = tonumber
local unpack = unpack
local GetTime = GetTime
local select = select
local wipe = wipe

local NewTimer = C_Timer and C_Timer.NewTimer
local CreateColorCurve = C_CurveUtil and C_CurveUtil.CreateColorCurve
local CreateNumericRuleFormatter = C_StringUtil and C_StringUtil.CreateNumericRuleFormatter
local CreateColor = CreateColor

-- Evaluate --

local OPERATORS = {
    ['<']  = function(a, b) return a < b end,
    ['<='] = function(a, b) return a <= b end,
    ['=='] = function(a, b) return a == b end,
    ['>='] = function(a, b) return a >= b end,
    ['>']  = function(a, b) return a > b end,
    ['~='] = function(a, b) return a ~= b end,
}

---@param check table
---@param display table
---@param frame CDMIcon|Frame a group's frame has no layers
---@param pip CDMPip? a split bar's pip, read instead of the whole bar
---@return boolean? matched nil when the check can't run here
local function Matches(check, display, frame, pip)
    if CDM.COMBINATIONS[check.variable] then
        local isAnd = check.variable == 'AND'
        local subs = check.checks or {}
        if not subs[1] then return false end
        for _, sub in ipairs(subs) do
            local matched = Matches(sub, display, frame, pip) == true
            if matched ~= isAnd then
                return matched -- AND stops at the first miss, OR at the first hit
            end
        end
        return isAnd
    end

    local trigger = CDM:GetCheckTrigger(display, check.trigger)
    local checks = trigger and CDM.ConditionChecks[trigger.Type]
    local def = checks and checks[check.variable]
    if not def or def.secret or def.curve then return nil end

    local layer = frame.layers and frame.layers[check.trigger]
    if def.type == 'select' then
        return def.match(check.value, layer, check) == true
    end

    local value = def.get(layer, trigger, pip)
    if def.type == 'bool' then
        return value == (check.value ~= false)
    end

    local op = OPERATORS[check.op or '<']
    return op ~= nil and op(value, tonumber(check.value) or 0)
end

---When a remaining-time check next flips, so the display re-runs without an event.
---@param check table
---@param frame CDMIcon
---@param now number
---@return number? seconds from now
local function NextFlip(check, frame, now)
    if CDM.COMBINATIONS[check.variable] then
        local soonest
        for _, sub in ipairs(check.checks or {}) do
            local flip = NextFlip(sub, frame, now)
            if flip and (not soonest or flip < soonest) then
                soonest = flip
            end
        end
        return soonest
    end

    if check.variable ~= 'remaining' then return nil end

    local layer = frame.layers[check.trigger]
    local endTime = layer and layer.endTime
    if not endTime then return nil end

    local flip = endTime - (tonumber(check.value) or 0) - now
    if flip > 0 then
        return flip
    end
end

---Later changes win, Else If stops at the first match.
---@param conditions table[]?
---@param display table
---@param frame CDMIcon|Frame
---@param pip CDMPip?
---@param overrides table
---@param matches table
local function Collect(conditions, display, frame, pip, overrides, matches)
    local chainMatched = false
    for index, condition in ipairs(conditions or {}) do
        local matched = Matches(condition.check or {}, display, frame, pip) == true
        if condition.linked and index > 1 then
            matched = matched and not chainMatched
            chainMatched = chainMatched or matched
        else
            chainMatched = matched
        end
        matches[index] = matched

        if matched then
            for _, change in ipairs(condition.changes or {}) do
                if change.property and change.property ~= 'sound' then
                    overrides[change.property] = change.value
                end
            end
        end
    end
end

---Move a display by its offset conditions; inside a dynamic group the group owns its slot.
---@param frame CDMIcon
---@param display table
local function PlaceOffset(frame, display)
    if CDM:IsDynamic(display.parent) then return end

    -- one function per frame, as the combat queue dedupes by identity
    frame.placeOffset = frame.placeOffset or function()
        local current = CDM:Get(frame.id)
        if current and not CDM:IsDynamic(current.parent) then
            CDM:Place(frame, frame.id, current)
        end
    end

    -- Our own frames move fine in combat, which is when an In Combat offset matters. Only one hanging off a picked frame,
    -- itself or through a group, can join a protected frame's anchor family, so that one waits for combat to end.
    local current = display
    while current do
        if current.anchorFrameType == 'SELECTFRAME' and current.ParentFrame and current.ParentFrame ~= 'UIParent' then
            NRSKNUI:RunWhenSafe(frame.placeOffset)
            return
        end
        current = current.parent and CDM:Get(current.parent)
    end
    frame.placeOffset()
end

local pipOverrides, pipMatches, pipKeys = {}, {}, {}

---A change decided per pip: Visible or Color of an Each Rune text or border.
---@param display table
---@param layer CDMLayer
---@param key string
---@return table? element, number? ordinal, string? name
local function PipRegionChange(display, layer, key)
    local name, sub = CDM:SplitProperty(key)
    if not sub or (name ~= 'visible' and name ~= 'subColor') then return nil end
    local element, ordinal = SubElement(display, sub)
    if not element or (element.type ~= 'text' and element.type ~= 'border') then return nil end
    local own = layer[element.type == 'text' and 'texts' or 'borders'][ordinal]
    if not (own and own.eachPip) then return nil end
    return element, ordinal, name
end

---Apply the display's conditions over what its triggers drew.
---@param id string
---@param frame CDMIcon
---@param display table
function CDM:EvaluateConditions(id, frame, display)
    local conditions = display.Conditions
    local applied = frame.conditionApplied or {}
    frame.conditionApplied = applied
    local wasActive = frame.conditionActive or {}
    frame.conditionActive = wasActive

    if frame.conditionTimer then
        frame.conditionTimer:Cancel()
        frame.conditionTimer = nil
    end

    -- Runs before the layer check: Show Display can bring a standby layer up.
    local overrides, matches = {}, {}
    Collect(conditions, display, frame, nil, overrides, matches)

    -- Re-run when a remaining-time check next flips.
    local now, soonest = GetTime(), nil
    for _, condition in ipairs(conditions or {}) do
        local flip = NextFlip(condition.check or {}, frame, now)
        if flip and (not soonest or flip < soonest) then
            soonest = flip
        end
    end

    -- Max Stacks is the display's, not a layer's: an aura bar is never the active layer, nothing can read its aura
    local maxStacks = overrides.maxStacks
    overrides.maxStacks = nil
    if frame.conditionMaxStacks ~= maxStacks then
        frame.conditionMaxStacks = maxStacks
        for _, each in ipairs(frame.layers or {}) do
            PROPERTIES.maxStacks.apply(frame, each, maxStacks, display)
        end
    end

    -- Offsets are the display's too: a cast bar has no layer between casts, so they'd reset every cast and wait out combat to come back
    local x, y = tonumber(overrides.xOffset) or 0, tonumber(overrides.yOffset) or 0
    overrides.xOffset, overrides.yOffset = nil, nil
    if (frame.conditionX or 0) ~= x or (frame.conditionY or 0) ~= y then
        frame.conditionX, frame.conditionY = x, y
        PlaceOffset(frame, display)
    end

    -- Alpha is the display's frame, ours and outside the aura button the game locks, so it reaches a lone aura that never
    -- has an active layer; set on every pass while a condition holds it, as restyling the frame puts the style's back
    local alpha = overrides.alpha
    overrides.alpha = nil
    if alpha ~= nil or frame.conditionAlpha ~= nil then
        frame:SetAlpha(alpha or frame.style.Alpha)
    end
    frame.conditionAlpha = alpha

    local layer = frame.activeLayer
    local show = overrides.show
    overrides.show = nil
    if show == true and not layer and frame.standbyLayer then
        layer = frame.standbyLayer
        layer:Show()
        frame.activeLayer, frame.hasActive = layer, true
    end
    frame.forceHidden = show == false

    -- A split bar decides Bar Color and Each Rune regions per pip, so the whole bar's pass skips them.
    local pipCount = layer and layer.isBar and layer.pipCount or 0
    if pipCount > 0 then
        ---@cast layer CDMLayer
        overrides.barColor = nil
        wipe(pipKeys)
        for _, condition in ipairs(conditions or {}) do
            for _, change in ipairs(condition.changes or {}) do
                if change.property and PipRegionChange(display, layer, change.property) then
                    pipKeys[change.property] = true
                end
            end
        end

        for key in pairs(pipKeys) do
            overrides[key] = nil
        end
    end

    -- Sounds play once when a condition starts matching on a shown display.
    for index, condition in ipairs(conditions or {}) do
        local matched = layer ~= nil and not frame.forceHidden and matches[index]
        if matched and not wasActive[index] then
            for _, change in ipairs(condition.changes or {}) do
                if change.property == 'sound' and change.value then
                    NRSKNUI:PlaySafeSound(change.value)
                end
            end
        end
        wasActive[index] = matched or nil
    end

    -- A different layer shows now, so the old one gets its own look back.
    local lastLayer = frame.conditionLayer
    if lastLayer and lastLayer ~= layer then
        for key in pairs(applied) do
            local name, sub = self:SplitProperty(key)
            local prop = PROPERTIES[name]
            if prop and prop.base then
                prop.apply(frame, lastLayer, prop.base(frame, lastLayer, display, sub), display, sub)
            end
        end
        wipe(applied)
    end
    frame.conditionLayer = layer

    -- Put new changes on and take off the ones that stopped matching.
    if layer then
        for key, value in pairs(overrides) do
            if applied[key] ~= value then
                local name, sub = self:SplitProperty(key)
                local prop = PROPERTIES[name]
                if prop then
                    prop.apply(frame, layer, value, display, sub)
                end
                applied[key] = value
            end
        end

        for key in pairs(applied) do
            if overrides[key] == nil then
                local name, sub = self:SplitProperty(key)
                local prop = PROPERTIES[name]
                if prop and prop.base then
                    prop.apply(frame, layer, prop.base(frame, layer, display, sub), display, sub)
                end
                applied[key] = nil
            end
        end

        -- The trigger resets desaturation every update, so an override is re-applied every pass too.
        if overrides.desaturate ~= nil then
            PROPERTIES.desaturate.apply(frame, layer, overrides.desaturate, display)
        end
    end

    -- Each pip of a split bar runs the conditions again with itself as the bar.
    if pipCount > 0 then
        ---@cast layer CDMLayer
        for i = 1, pipCount do
            local pip = layer.pips[i]
            wipe(pipOverrides)
            Collect(conditions, display, frame, pip, pipOverrides, pipMatches)
            self:SetLayerPipColor(layer, i, pipOverrides.barColor)
            for key in pairs(pipKeys) do
                local element, ordinal, name = PipRegionChange(display, layer, key)
                ---@cast element table
                ---@cast name 'visible'|'subColor'
                local value = pipOverrides[key]
                if value == nil then
                    value = PROPERTIES[name].base(frame, layer, display, select(2, self:SplitProperty(key)))
                end
                local region = pip[element.type == 'text' and 'texts' or 'borders'][ordinal]
                if region then
                    PaintRegion(element, region, name, value)
                end
            end
        end
    end

    if soonest then
        frame.conditionTimer = NewTimer(soonest + 0.01, function() -- just past the flip, so the check reads flipped
            frame.conditionTimer = nil
            if frame.id == id then
                self:Derive(id)
            end
        end)
    end
end

---Drop everything conditions put on a frame, when it goes back to the pool.
---@param frame CDMIcon
function CDM:ResetConditions(frame)
    if frame.conditionTimer then
        frame.conditionTimer:Cancel()
    end
    frame.conditionTimer, frame.conditionApplied, frame.conditionActive, frame.conditionLayer = nil, nil, nil, nil
    frame.forceHidden, frame.standbyLayer = nil, nil
    frame.conditionX, frame.conditionY = nil, nil
    frame.conditionMaxStacks, frame.conditionAlpha = nil, nil
end

-- Groups --

---Put a group's offset conditions on its frame, read by Place.
---@param display table
---@param frame Frame
---@return boolean changed
function CDM:EvaluateGroupConditions(display, frame)
    ---@cast frame CDMPlaced
    local overrides, matches = {}, {}
    Collect(display.Conditions, display, frame, nil, overrides, matches)

    local x, y = tonumber(overrides.xOffset) or 0, tonumber(overrides.yOffset) or 0
    if frame.conditionX == x and frame.conditionY == y then return false end
    frame.conditionX, frame.conditionY = x, y
    return true
end

local movedGroups = {}

-- One function for the combat queue, which dedupes by identity; spec and talents can't change in combat, a loading screen can.
local function PlaceMovedGroups()
    for id in pairs(movedGroups) do
        local display = CDM:Get(id)
        local frame = CDM.containers[id]
        if display and frame then
            CDM:Place(frame, id, display, display.type == 'dynamicgroup' and frame:GetResolvedAnchor(display.Layout.Grow) or nil)
        elseif display then
            local host = CDM:GetAuraHost(id)
            if host then
                CDM:Place(host, id, display)
            end
        end
    end
    wipe(movedGroups)
end

---Spec or talents changed: re-run every condition that reads them.
function CDM:RefreshPlayerConditions()
    for id, display in pairs(self.db.Displays) do
        if self:ConditionsUse(display, -1, 'spec') or self:ConditionsUse(display, -1, 'talent') then
            local group = self.containers[id] or self:GetAuraHost(id)
            if self.icons[id] then
                self:Derive(id)
            elseif group and self:EvaluateGroupConditions(display, group) then
                movedGroups[id] = true
            end
        end
    end

    if next(movedGroups) then
        NRSKNUI:RunWhenSafe(PlaceMovedGroups)
    end
end

-- Curves --

---The step curve a text's colour follows from its curve checks on one trigger, nil when no condition colours it that way.
---@param display table
---@param triggerIndex number the trigger whose time or power the text shows
---@param scales table<string, number> the checks it follows, each with what divides its threshold into what the game reads
---@param ordinal number the text's place among the display's texts
---@param base table the text's own colour, where no condition matches
---@return LuaColorCurveObject?
function CDM:TextColorCurve(display, triggerIndex, scales, ordinal, base)
    local steps -- only made when a condition colours this text, since a cast restyles %n texts every time
    for _, condition in ipairs(display.Conditions or {}) do
        local check = condition.check or {}
        local scale = check.trigger == triggerIndex and scales[check.variable]
        if scale then
            for _, change in ipairs(condition.changes or {}) do
                local name, sub = self:SplitProperty(change.property or '')
                if name == 'subColor' then
                    local element, textOrdinal = SubElement(display, sub)
                    if element and element.type == 'text' and textOrdinal == ordinal then
                        local above = check.op == '>' or check.op == '>='
                        steps = steps or {}
                        steps[#steps + 1] = { above = above, at = (tonumber(check.value) or 0) / scale, color = change.value }
                    end
                end
            end
        end
    end
    if not steps then return nil end

    -- later conditions win, same as when the conditions are checked directly
    local function ColorAt(value)
        local color = base
        for _, step in ipairs(steps) do
            if (step.above and value > step.at) or (not step.above and value < step.at) then
                color = step.color
            end
        end
        return color
    end

    local points, seen = {}, {}
    for _, step in ipairs(steps) do
        if not seen[step.at] then
            seen[step.at] = true
            points[#points + 1] = step.at
        end
    end
    tsort(points)

    -- a step holds from its point up to the next one, read halfway; the first starts below zero, where nothing reads
    local curve = CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    local first = (points[1] < 0 and points[1] or 0) - 1
    curve:AddPoint(first, CreateColor(unpack(ColorAt(first))))
    for i, at in ipairs(points) do
        local after = points[i + 1]
        curve:AddPoint(at, CreateColor(unpack(ColorAt(after and (at + after) / 2 or at + 1))))
    end
    return curve
end

---The formatter an aura's stack count follows from its Stacks checks, nil when no condition colours this text that way.
---@param display table
---@param triggerIndex number the aura trigger whose count the text shows
---@param ordinal number the text's place among the display's texts
---@return table? formatter a NumericRuleFormatter for SetApplicationCount
function CDM:StackCountFormatter(display, triggerIndex, ordinal)
    local steps
    for _, condition in ipairs(display.Conditions or {}) do
        local check = condition.check or {}
        if check.trigger == triggerIndex and check.variable == 'stacks' then
            for _, change in ipairs(condition.changes or {}) do
                local name, sub = self:SplitProperty(change.property or '')
                if name == 'subColor' then
                    local element, textOrdinal = SubElement(display, sub)
                    if element and element.type == 'text' and textOrdinal == ordinal then
                        steps = steps or {}
                        steps[#steps + 1] = { above = check.op == '>=', at = tonumber(check.value) or 0, color = change.value }
                    end
                end
            end
        end
    end
    if not steps then return nil end

    -- the count is secret, so the game picks the breakpoint and its colour code; later conditions win
    local function FormatAt(value)
        local color
        for _, step in ipairs(steps) do
            if (step.above and value >= step.at) or (not step.above and value < step.at) then
                color = step.color
            end
        end
        return color and CreateColor(unpack(color)):WrapTextInColorCode('%d') or '%d'
    end

    -- every step starts a breakpoint, so each one reads the same colour across its whole range
    local points, seen = { 2 }, { [2] = true }
    for _, step in ipairs(steps) do
        if step.at > 2 and not seen[step.at] then
            seen[step.at] = true
            points[#points + 1] = step.at
        end
    end
    tsort(points)

    -- a single stack stays blank, as Blizzard draws a count without a formatter
    local breakpoints = { { threshold = 0, format = '' } }
    for _, at in ipairs(points) do
        breakpoints[#breakpoints + 1] = { threshold = at, format = FormatAt(at) }
    end

    local formatter = CreateNumericRuleFormatter()
    formatter:SetBreakpoints(breakpoints)
    return formatter
end

-- Remap --

---Follow triggers that moved: `map(old)` gives the new index, nil drops checks on a deleted one.
---@param display table
---@param map fun(index: number): number?
function CDM:RemapConditionTriggers(display, map)
    if display.DynamicTrigger then
        display.DynamicTrigger = map(display.DynamicTrigger)
    end

    local timer = display.Style and display.Style.TimerText
    if timer and timer.Trigger then
        timer.Trigger = map(timer.Trigger)
    end

    ---@return boolean keep false when its trigger is gone
    local function remap(check)
        for i = #(check.checks or {}), 1, -1 do
            if not remap(check.checks[i]) then
                tremove(check.checks, i)
            end
        end

        if not check.trigger then return true end
        local new = check.trigger <= 0 and check.trigger or map(check.trigger) -- global and group checks stay put
        check.trigger = new
        return new ~= nil
    end

    local conditions = display.Conditions or {}
    for index = #conditions, 1, -1 do
        local check = conditions[index].check
        if check and not remap(check) then
            tremove(conditions, index)
        end
    end
end

---Follow sub elements that moved: `map(old)` gives an element's new index, nil drops changes to a deleted one.
---@param display table
---@param map fun(index: number): number?
function CDM:RemapConditionSubRegions(display, map)
    for _, condition in ipairs(display.Conditions or {}) do
        local changes = condition.changes or {}
        for i = #changes, 1, -1 do
            local index, name = (changes[i].property or ''):match('^sub%.(%d+)%.(%a+)$')
            if index then
                local new = map(tonumber(index))
                if new then
                    changes[i].property = 'sub.' .. new .. '.' .. name
                else
                    tremove(changes, i)
                end
            end
        end
    end
end

-- Queries --

---Whether any condition uses this check, so a trigger can skip work nobody reads.
---@param display table
---@param triggerIndex number
---@param variable string
---@return boolean
function CDM:ConditionsUse(display, triggerIndex, variable)
    local function uses(check)
        if check.trigger == triggerIndex and check.variable == variable then return true end
        for _, sub in ipairs(check.checks or {}) do
            if uses(sub) then return true end
        end
        return false
    end

    for _, condition in ipairs(display.Conditions or {}) do
        if condition.check and uses(condition.check) then return true end
    end
    return false
end

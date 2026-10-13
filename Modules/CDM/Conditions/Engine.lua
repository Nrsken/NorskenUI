---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local tremove = table.remove
local GetTime = GetTime
local select = select
local wipe = wipe
local ipairs, pairs = ipairs, pairs
local NewTimer = C_Timer and C_Timer.NewTimer

local PROPERTIES = CDM.ConditionProperties
local SubElement, PaintRegion = CDM.ConditionRegions.SubElement, CDM.ConditionRegions.PaintRegion

local OPERATORS = {
    ['<']  = function(a, b) return a < b end,
    ['<='] = function(a, b) return a <= b end,
    ['=='] = function(a, b) return a == b end,
    ['>='] = function(a, b) return a >= b end,
    ['>']  = function(a, b) return a > b end,
    ['~='] = function(a, b) return a ~= b end,
}

-- Evaluate --

CDM.COMBINATIONS = { AND = true, OR = true }

---@param check table
---@param display table
---@param frame CDMIcon
---@param pip CDMPip? one pip of a split bar, which its checks read instead of the whole bar where they can
---@return boolean? matched nil when the check can't run here
local function Matches(check, display, frame, pip)
    if CDM.COMBINATIONS[check.variable] then
        local isAnd = check.variable == 'AND'
        local subs = check.checks or {}
        if not subs[1] then return false end
        for _, sub in ipairs(subs) do
            local matched = Matches(sub, display, frame, pip) == true
            if matched ~= isAnd then return matched end -- AND stops at the first miss, OR at the first hit
        end
        return isAnd
    end

    local trigger = CDM:GetCheckTrigger(display, check.trigger)
    local checks = trigger and CDM.ConditionChecks[trigger.Type]
    local def = checks and checks[check.variable]
    if not def or def.secret then return nil end

    if def.type == 'select' then return def.match(check.value) == true end
    local value = def.get(frame.layers[check.trigger], trigger, pip)
    if def.type == 'bool' then return value == (check.value ~= false) end
    local op = OPERATORS[check.op or '<']
    return op ~= nil and op(value, tonumber(check.value) or 0)
end

---When a remaining-time check will next flip, so the icon re-evaluates without another event.
---@param check table
---@param frame CDMIcon
---@param now number
---@return number? seconds from now
local function NextFlip(check, frame, now)
    if CDM.COMBINATIONS[check.variable] then
        local soonest
        for _, sub in ipairs(check.checks or {}) do
            local flip = NextFlip(sub, frame, now)
            if flip and (not soonest or flip < soonest) then soonest = flip end
        end
        return soonest
    end
    if check.variable ~= 'remaining' then return nil end
    local layer = frame.layers[check.trigger]
    local endTime = layer and layer.endTime
    if not endTime then return nil end
    local flip = endTime - (tonumber(check.value) or 0) - now
    if flip > 0 then return flip end
end

---Match every condition into `overrides`: later changes win, Else If stops at the first match.
---@param conditions table[]?
---@param display table
---@param frame CDMIcon
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
                if change.property and change.property ~= 'sound' then overrides[change.property] = change.value end
            end
        end
    end
end

local pipOverrides, pipMatches, pipKeys = {}, {}, {}

---A change a split bar decides per pip: Visible or Color of a text or border copied onto every pip (Each Rune).
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

---Apply the icon's conditions over what its triggers drew; later wins, Else If stops at the first match.
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

    -- Checks read the trigger layers directly, so they run while nothing shows; Show Display can bring a standby layer up.
    local overrides, matches = {}, {}
    Collect(conditions, display, frame, nil, overrides, matches)
    local now, soonest = GetTime(), nil
    for _, condition in ipairs(conditions or {}) do
        local flip = NextFlip(condition.check or {}, frame, now)
        if flip and (not soonest or flip < soonest) then soonest = flip end
    end

    local layer = frame.activeLayer
    local show = overrides.show
    overrides.show = nil
    if show == true and not layer and frame.standbyLayer then
        layer = frame.standbyLayer
        layer:Show()
        frame.activeLayer, frame.hasActive = layer, true
    end
    frame.forceHidden = show == false

    -- A split bar's Bar Color and Each Rune texts and borders are decided per pip, its checks reading that pip (Ayije_CDM's pip conditions).
    local pipCount = layer and layer.isBar and layer.pipCount or 0
    if pipCount > 0 then
        ---@cast layer CDMLayer
        overrides.barColor = nil
        wipe(pipKeys)
        for _, condition in ipairs(conditions or {}) do
            for _, change in ipairs(condition.changes or {}) do
                if change.property and PipRegionChange(display, layer, change.property) then pipKeys[change.property] = true end
            end
        end
        for key in pairs(pipKeys) do overrides[key] = nil end
    end

    -- Sounds play on the rising edge of a condition on a display that shows.
    for index, condition in ipairs(conditions or {}) do
        local matched = layer ~= nil and not frame.forceHidden and matches[index]
        if matched and not wasActive[index] then
            for _, change in ipairs(condition.changes or {}) do
                if change.property == 'sound' and change.value then NRSKNUI:PlaySafeSound(change.value) end
            end
        end
        wasActive[index] = matched or nil
    end

    local lastLayer = frame.conditionLayer
    if lastLayer and lastLayer ~= layer then
        for key in pairs(applied) do
            local name, sub = self:SplitProperty(key)
            local prop = PROPERTIES[name]
            if prop and prop.base then prop.apply(frame, lastLayer, prop.base(frame, lastLayer, display, sub), display, sub) end
        end
        wipe(applied)
    end
    frame.conditionLayer = layer

    if layer then
        for key, value in pairs(overrides) do
            if applied[key] ~= value then
                local name, sub = self:SplitProperty(key)
                local prop = PROPERTIES[name]
                if prop then prop.apply(frame, layer, value, display, sub) end
                applied[key] = value
            end
        end
        for key in pairs(applied) do
            if overrides[key] == nil then
                local name, sub = self:SplitProperty(key)
                local prop = PROPERTIES[name]
                if prop and prop.base then prop.apply(frame, layer, prop.base(frame, layer, display, sub), display, sub) end
                applied[key] = nil
            end
        end
        -- Update rewrites desaturation every pass, so an override has to be re-applied every pass too.
        if overrides.desaturate ~= nil then PROPERTIES.desaturate.apply(frame, layer, overrides.desaturate, display) end
    end

    -- After the whole bar's pass: one that held a per pip key before the split resets it on every pip.
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
                if value == nil then value = PROPERTIES[name].base(frame, layer, display, select(2, self:SplitProperty(key))) end
                local region = pip[element.type == 'text' and 'texts' or 'borders'][ordinal]
                if region then PaintRegion(element, region, name, value) end
            end
        end
    end

    if soonest then
        frame.conditionTimer = NewTimer(soonest + 0.01, function()
            frame.conditionTimer = nil
            if frame.id == id then self:UpdateIcon(id) end
        end)
    end
end

---Drop everything conditions put on a frame, when it goes back to the pool.
---@param frame CDMIcon
function CDM:ResetConditions(frame)
    if frame.conditionTimer then frame.conditionTimer:Cancel() end
    frame.conditionTimer, frame.conditionApplied, frame.conditionActive, frame.conditionLayer = nil, nil, nil, nil
    frame.forceHidden, frame.standbyLayer = nil, nil
end

---Follow the icon's triggers after they move: map(old index) gives the new one, or nil when it's gone.
---Conditions and the Dynamic Information trigger both point at triggers by index.
---@param display table
---@param map fun(index: number): number?
function CDM:RemapConditionTriggers(display, map)
    if display.DynamicTrigger then display.DynamicTrigger = map(display.DynamicTrigger) end

    ---@return boolean keep false when its trigger is gone
    local function remap(check)
        for i = #(check.checks or {}), 1, -1 do
            if not remap(check.checks[i]) then tremove(check.checks, i) end
        end
        if not check.trigger then return true end
        local new = check.trigger <= 0 and check.trigger or map(check.trigger) -- global and group checks stay put
        check.trigger = new
        return new ~= nil
    end

    local conditions = display.Conditions or {}
    for index = #conditions, 1, -1 do
        local check = conditions[index].check
        if check and not remap(check) then tremove(conditions, index) end
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
                if new then changes[i].property = 'sub.' .. new .. '.' .. name else tremove(changes, i) end
            end
        end
    end
end

---Does any condition on this icon ask for a check, so the trigger only does that work when needed.
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

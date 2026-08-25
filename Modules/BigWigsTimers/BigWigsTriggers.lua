---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class BigWigsTimersModule
local BigWigsTimers = NRSKNUI:GetModule('BigWigsTimers')

local insert, remove = table.insert, table.remove
local format = string.format
local CopyTable = CopyTable
local tonumber = tonumber
local GetTime = GetTime
local huge = math.huge
local ipairs = ipairs
local pcall = pcall

local FAST_LIMIT = 20
local counters = {}

---@param tests BigWigsTimers.CountTest[]
---@param count number
---@return boolean
local function RunTests(tests, count)
    for _, test in ipairs(tests) do
        if count >= test.first and count <= test.last and (count - test.first) % test.interval == 0 then
            return true
        end
    end

    return false
end

---Parse the Count syntax: "2, 5, 6" (list), "2-6" (range), "/2" (every 2nd), "2/3", "2-11/3".
---@param pattern string
---@return BigWigsTimers.Counter
local function ParseCount(pattern)
    local tests = {}

    for token in pattern:gmatch('[^ ,]+') do
        local firstText, lastText, intervalText = token:match('(%d*)-?(%d*)/?(%d*)')
        local interval = tonumber(intervalText)
        local first = tonumber(firstText) or 0

        insert(tests, {
            first = first,
            -- No end given means a single value, unless an interval opens it up.
            last = tonumber(lastText) or (interval and huge or first),
            interval = interval or 1,
        })
    end

    local fast = {}
    for i = 0, FAST_LIMIT do
        fast[i] = RunTests(tests, i)
    end

    return { tests = tests, fast = fast }
end

---@param pattern string
---@return BigWigsTimers.Counter?
local function GetCounter(pattern)
    if pattern == '' then return nil end

    local counter = counters[pattern]

    if not counter then
        counter = ParseCount(pattern)
        counters[pattern] = counter
    end

    return counter
end

---@param counter BigWigsTimers.Counter
---@param count number
---@return boolean
local function MatchesCount(counter, count)
    if count <= FAST_LIMIT then return counter.fast[count] end

    return RunTests(counter.tests, count)
end

local MESSAGE_TESTS = {
    ['=='] = function(text, needle) return text == needle end,
    ['find'] = function(text, needle) return text:find(needle, 1, true) ~= nil end,
    -- A hand-written pattern can be malformed, which is a plain Lua error rather than a no-match.
    ['match'] = function(text, needle)
        local ok, result = pcall(text.match, text, needle)
        return ok and result ~= nil
    end,
}

local REMAINING_TESTS = {
    ['=='] = function(a, b) return a == b end,
    ['~='] = function(a, b) return a ~= b end,
    ['<'] = function(a, b) return a < b end,
    ['<='] = function(a, b) return a <= b end,
    ['>'] = function(a, b) return a > b end,
    ['>='] = function(a, b) return a >= b end,
}

NRSKNUI.BigWigsMessageOperators = {
    { key = '==',    text = 'Is Exactly' },
    { key = 'find',  text = 'Contains' },
    { key = 'match', text = 'Matches (Pattern)' },
}

NRSKNUI.BigWigsRemainingOperators = {
    { key = '<',  text = '<' },
    { key = '<=', text = '<=' },
    { key = '==', text = '=' },
    { key = '~=', text = '!=' },
    { key = '>',  text = '>' },
    { key = '>=', text = '>=' },
}

NRSKNUI.BigWigsCast = {
    { key = 'show', text = 'Show' },
    { key = 'hide', text = 'Hide' },
    { key = 'only', text = 'Only Show Cast' },
}

-- Matching --

---Fields that cannot change for as long as a bar is on screen, so they are only re-tested when the
---bar registry changes.
---@param trigger table
---@param bar BigWigsTimers.Bar
---@return boolean
function BigWigsTimers:BarMatchesTrigger(trigger, bar)
    -- Filed under a boss means only that encounter's own bars count.
    if trigger.BossId ~= 0 and (not bar.addon or bar.addon.journalId ~= trigger.BossId) then return false end

    if trigger.SpellId ~= '' and trigger.SpellId ~= bar.spellId then return false end

    -- BigWigs sends the cooldown timer and the cast bar under the same key.
    local isCast = bar.timerType == 'cast'

    if isCast and trigger.ShowCasts == 'hide' then return false end
    if not isCast and trigger.ShowCasts == 'only' then return false end

    if trigger.Message ~= '' then
        local test = MESSAGE_TESTS[trigger.MessageOperator]

        if not test or not test(bar.text, trigger.Message) then return false end
    end

    local counter = GetCounter(trigger.Count)

    if counter and not MatchesCount(counter, tonumber(bar.count) or 0) then return false end

    return NRSKNUI.LoadConditions:Check(trigger.LoadConditions)
end

---Time left on a bar with the trigger's offset applied, which can be negative to fire early or
---positive to hold the display past the bar's own expiry.
---@param trigger table
---@param bar BigWigsTimers.Bar
---@return number
function BigWigsTimers:TriggerRemaining(trigger, bar)
    if bar.paused then return bar.remaining + trigger.Offset end

    return bar.expirationTime - GetTime() + trigger.Offset
end

---@param trigger table
---@param remaining number
---@return boolean
function BigWigsTimers:TriggerPasses(trigger, remaining)
    if remaining <= 0 then return false end
    if not trigger.UseRemaining then return true end

    return REMAINING_TESTS[trigger.RemainingOperator](remaining, trigger.Remaining)
end

---The soonest-expiring bar a trigger currently matches, if any of them pass its remaining-time test.
---@param trigger table
---@param bars BigWigsTimers.Bar[]
---@return BigWigsTimers.Bar? bar, number? remaining
function BigWigsTimers:ResolveTrigger(trigger, bars)
    local best, bestRemaining

    for _, bar in ipairs(bars) do
        local remaining = self:TriggerRemaining(trigger, bar)

        if self:TriggerPasses(trigger, remaining) and (not best or bar.expirationTime < best.expirationTime) then
            best, bestRemaining = bar, remaining
        end
    end

    return best, bestRemaining
end

-- Trigger storage --

---@param instanceId number
---@return table instance
function BigWigsTimers:GetInstanceDB(instanceId)
    local instance = self.db.Instances[instanceId]

    if not instance then
        instance = { Enabled = true, NextId = 1, Triggers = {} }
        self.db.Instances[instanceId] = instance
    end

    return instance
end

---Array position is the display order, Id is the identity the GUI keys off.
---@param instanceId number
---@param triggerId number
---@return table? trigger, number? index
function BigWigsTimers:GetTrigger(instanceId, triggerId)
    for index, trigger in ipairs(self:GetInstanceDB(instanceId).Triggers) do
        if trigger.Id == triggerId then
            return trigger, index
        end
    end
end

---@param instanceId number
---@param name string?
---@param bossId number? journal ID of the encounter it belongs to, 0 or nil for the whole instance
---@return table trigger
function BigWigsTimers:CreateTrigger(instanceId, name, bossId)
    local instance = self:GetInstanceDB(instanceId)
    local trigger = CopyTable(self.db.TriggerDefaults)

    trigger.BossId = bossId or 0
    trigger.Id = instance.NextId
    trigger.Name = (name and name ~= '' and name) or format('%s %d', trigger.Name, instance.NextId)
    instance.NextId = instance.NextId + 1
    insert(instance.Triggers, trigger)
    self:RebuildActiveTriggers()

    return trigger
end

---@param instanceId number
---@param triggerId number
function BigWigsTimers:DeleteTrigger(instanceId, triggerId)
    local _, index = self:GetTrigger(instanceId, triggerId)
    if not index then return end

    remove(self:GetInstanceDB(instanceId).Triggers, index)
    self:RebuildActiveTriggers()
end

---@param instanceId number
---@param triggerId number
---@return table? trigger
function BigWigsTimers:DuplicateTrigger(instanceId, triggerId)
    local source, index = self:GetTrigger(instanceId, triggerId)
    if not source or not index then return end

    local instance = self:GetInstanceDB(instanceId)
    local copy = CopyTable(source)

    -- Copying a copy re-uses the original stem, so the suffix counts up instead of stacking.
    local base = source.Name:gsub('%s*%(%d+%)$', '')
    local taken = {}

    for _, other in ipairs(instance.Triggers) do taken[other.Name] = true end

    local name, suffix = base, 2

    while taken[name] do
        name = format('%s (%d)', base, suffix)
        suffix = suffix + 1
    end

    copy.Id = instance.NextId
    copy.Name = name
    instance.NextId = instance.NextId + 1
    insert(instance.Triggers, index + 1, copy)
    self:RebuildActiveTriggers()

    return copy
end

---Swaps with the nearest timer under the same boss, which is the neighbour the list shows.
---@param instanceId number
---@param triggerId number
---@param delta number -1 to move up, 1 to move down
function BigWigsTimers:MoveTrigger(instanceId, triggerId, delta)
    local triggers = self:GetInstanceDB(instanceId).Triggers
    local trigger, index = self:GetTrigger(instanceId, triggerId)
    if not trigger or not index then return end

    for target = index + delta, delta < 0 and 1 or #triggers, delta do
        if triggers[target].BossId == trigger.BossId then
            triggers[index], triggers[target] = triggers[target], triggers[index]
            self:RebuildActiveTriggers()

            return
        end
    end
end

---@param instanceId number
---@param triggerId number
---@param bossId number journal ID, 0 for the whole instance
function BigWigsTimers:SetTriggerBoss(instanceId, triggerId, bossId)
    local trigger = self:GetTrigger(instanceId, triggerId)
    if not trigger or trigger.BossId == bossId then return end

    trigger.BossId = bossId
    self:RebuildActiveTriggers()
end

---Moving keeps the trigger's settings but not its Id, which belongs to the instance it came from.
---@param fromId number
---@param triggerId number
---@param toId number
---@return number? newTriggerId
function BigWigsTimers:MoveTriggerToInstance(fromId, triggerId, toId)
    local trigger, index = self:GetTrigger(fromId, triggerId)
    if not trigger or not index or fromId == toId then return end

    local target = self:GetInstanceDB(toId)

    remove(self:GetInstanceDB(fromId).Triggers, index)
    trigger.BossId = 0 -- a journal ID means nothing in the instance it just left
    trigger.Id = target.NextId
    target.NextId = target.NextId + 1
    insert(target.Triggers, trigger)
    self:RebuildActiveTriggers()

    return trigger.Id
end

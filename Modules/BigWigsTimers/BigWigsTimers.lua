---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class BigWigsTimersModule
local BigWigsTimers = NRSKNUI:GetModule('BigWigsTimers')
function BigWigsTimers:UpdateDB()
    self.db = NRSKNUI.db.profile.BigWigsTimers
    self:RepairTriggers()
end

local Anchors = NRSKNUI.Anchors

local format, gsub, tostring = string.format, string.gsub, tostring
local floor, max, min = math.floor, math.max, math.min
local ipairs, pairs, next = ipairs, pairs, next
local insert, wipe = table.insert, wipe
local GetInstanceInfo = GetInstanceInfo
local IsInInstance = IsInInstance
local CreateFrame = CreateFrame
local CopyTable = CopyTable
local tonumber = tonumber
local GetTime = GetTime
local select = select
local type = type

local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture

local UPDATE_THROTTLE = 0.03
local TEXT_WIDTH = 400
local ICON_MARKUP = '|T%s:0:0:0:0:64:64:4:60:4:60|t'
local BARS, TEXTS = 'Bars', 'Texts'
local ALIGN_JUSTIFY = { LEFT = 'LEFT', RIGHT = 'RIGHT' }

BigWigsTimers.displays = { [BARS] = {}, [TEXTS] = {} }
BigWigsTimers.displayByTrigger = {}
BigWigsTimers.activeTriggers = {}
BigWigsTimers.triggerOrder = {}
BigWigsTimers.matched = {}
BigWigsTimers.previewEntries = {}

-- Anchors only resolve the two group settings pages, so the trigger pages are claimed directly.
BigWigsTimers.previewPages = {
    'bwTimers',
    'bwTimersBars',
    'bwTimersTexts',
    'bwTimersDungeons',
    'bwTimersRaids',
}

---@param kind 'Bars'|'Texts'
---@return number
function BigWigsTimers:MaxDisplays(kind)
    return self.db[kind].Config.Limit
end

-- Text Formatting --

---@param remaining number
---@param trigger table
---@return string
local function FormatTime(remaining, trigger)
    if remaining < 1 or (trigger.ShowDecimals and remaining <= trigger.DecimalThreshold) then
        return format('%.1f', remaining)
    end

    return tostring(floor(remaining + 0.5))
end

---@param formatStr string
---@param trigger table
---@param bar BigWigsTimers.Bar
---@param remaining number
---@return string
local function FormatText(formatStr, trigger, bar, remaining)
    if not formatStr:find('%%') then return formatStr end

    return (gsub(formatStr, '%%(%a)', function(token)
        if token == 'n' then return bar.text end
        if token == 't' then return FormatTime(remaining, trigger) end
        if token == 'c' then return tostring(bar.count) end
        if token == 's' then return bar.spellId end
        if token == 'i' then return bar.icon and format(ICON_MARKUP, bar.icon) or '' end

        return '%' .. token
    end))
end

-- Frames --

function BigWigsTimers:CreateFrames()
    if self.groups then return end

    self.groups = {}
    self.groups[BARS] = NRSKNUI:CreateDynamicGroup('NRSKNUI_BigWigsTimers_Bars', UIParent)
    self.groups[TEXTS] = NRSKNUI:CreateDynamicGroup('NRSKNUI_BigWigsTimers_Texts', UIParent)

    -- Utilize fancy new 12.1 rolesets to hide/show the groups when the encounter UI is active.
    for _, group in pairs(self.groups) do
        group:SetRolesets('encounterUI')
    end

    -- Each group drives its own OnUpdate as the layout scheduler, so the countdown rides its own frame.
    local updater = CreateFrame('Frame')
    updater:Hide()
    updater:NUIApplyOnUpdate(UPDATE_THROTTLE, function() self:OnUpdate() end)
    self.updater = updater

    Anchors:Register(self, 'BigWigsTimerBars', self.groups[BARS], 'bwTimersBars', { db = self.db[BARS], displayName = 'BigWigs Timer Bars' })
    Anchors:Register(self, 'BigWigsTimerTexts', self.groups[TEXTS], 'bwTimersTexts', { db = self.db[TEXTS], displayName = 'BigWigs Timer Texts' })
end

---@param index number
---@return Frame
function BigWigsTimers:CreateBarDisplay(index)
    local display = CreateFrame('Frame', nil, self.groups[BARS])
    display:EnableMouse(false)
    display:NUICreateBackdrop(true)
    display:NUISetPixelSnap()
    display.key = 'bar' .. index
    display.kind = BARS

    local borderFrame = CreateFrame('Frame', nil, display)
    borderFrame:SetFrameLevel(display:GetFrameLevel() + 5)
    borderFrame:NUIAddBorders()
    borderFrame:NUISetPixelSnap()
    display.borderFrame = borderFrame

    local iconFrame = CreateFrame('Frame', nil, display)
    iconFrame:NUIAddBorders()
    iconFrame:NUISetPixelSnap()
    iconFrame.texture = iconFrame:CreateTexture(nil, 'ARTWORK')
    display.iconFrame = iconFrame

    local statusBar = CreateFrame('StatusBar', nil, display)
    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(1)
    display.statusBar = statusBar

    display.leftText = statusBar:CreateFontString(nil, 'OVERLAY')
    display.leftText:SetWordWrap(false)
    display.rightText = statusBar:CreateFontString(nil, 'OVERLAY')
    display.rightText:SetWordWrap(false)

    self.displays[BARS][index] = display
    self.groups[BARS]:AttachChild(display, display.key)
    self:ConfigureDisplay(display)
    display:Show()

    return display
end

---@param index number
---@return Frame
function BigWigsTimers:CreateTextDisplay(index)
    local display = CreateFrame('Frame', nil, self.groups[TEXTS])
    display:EnableMouse(false)
    display.key = 'text' .. index
    display.kind = TEXTS

    display.text = display:CreateFontString(nil, 'OVERLAY')
    display.text:SetWordWrap(false)

    self.displays[TEXTS][index] = display
    self.groups[TEXTS]:AttachChild(display, display.key)
    self:ConfigureDisplay(display)
    display:Show()

    return display
end

---@param display Frame
function BigWigsTimers:ConfigureDisplay(display)
    if display.kind == TEXTS then
        local db = self.db[TEXTS]
        local height = db.FontSize + 4

        display:NUISetPixelSize(TEXT_WIDTH, height)
        display.text:SetFontStyle(db)
        display.text:SetFontJustify(ALIGN_JUSTIFY[db.Config.Align] or 'CENTER', display, 0, 0)
        self.groups[TEXTS]:NotifyChildResized(display.key, TEXT_WIDTH, height)

        return
    end

    local db = self.db[BARS]
    local w, h = db.Width, db.Height
    local bg, border = db.BackdropColor, db.BorderColor
    local iconShown = db.Icon.Enabled

    display:NUISetPixelSize(w, h)
    display:SetBackgroundColor(bg[1], bg[2], bg[3], bg[4])

    display.borderFrame:SetAllPoints(display)
    display.borderFrame:SetBorderColor(border[1], border[2], border[3], border[4])

    display.iconFrame:SetShown(iconShown)
    display.iconFrame:NUISetPixelSize(h, h)
    display.iconFrame:NUISetPixelPoint('LEFT', display, 'LEFT', 0, 0)
    display.iconFrame:SetBorderColor(border[1], border[2], border[3], border[4])
    display.iconFrame.texture:NUISetPixelInside(display.iconFrame, 1, 1)
    display.iconFrame.texture:NUISetZoom()

    display.statusBar:ClearAllPoints()
    display.statusBar:NUISetPixelPoint('TOPLEFT', display, 'TOPLEFT', iconShown and (h - 1) or 1, -1)
    display.statusBar:NUISetPixelPoint('BOTTOMRIGHT', display, 'BOTTOMRIGHT', -1, 1)
    display.statusBar:SetStatusBarTexture(NRSKNUI:GetStatusbar(db))

    display.leftText:SetFontStyle(db)
    display.leftText:SetFontJustify('LEFT', display.statusBar, 4, 0)
    display.rightText:SetFontStyle(db)
    display.rightText:SetFontJustify('RIGHT', display.statusBar, -4, 0)

    self.groups[BARS]:NotifyChildResized(display.key, w, h)
end

-- Display assignment --

---@param trigger table
---@return Frame?
function BigWigsTimers:AcquireDisplay(trigger)
    local existing = self.displayByTrigger[trigger]
    if existing then return existing end

    local kind = trigger.DisplayType == 'text' and TEXTS or BARS

    for index = 1, self:MaxDisplays(kind) do
        local display = self.displays[kind][index]

        if not display then
            display = kind == TEXTS and self:CreateTextDisplay(index) or self:CreateBarDisplay(index)
        end

        if not display.trigger then
            display.trigger = trigger
            self.displayByTrigger[trigger] = display

            return display
        end
    end
end

---@param trigger table
function BigWigsTimers:ReleaseDisplay(trigger)
    local display = self.displayByTrigger[trigger]
    if not display then return end

    self.displayByTrigger[trigger] = nil
    display.trigger = nil
    self.groups[display.kind]:DeactivateChild(display.key)
end

function BigWigsTimers:ReleaseAllDisplays()
    for trigger in pairs(self.displayByTrigger) do
        self:ReleaseDisplay(trigger)
    end
end

---@param display Frame
---@param trigger table
---@param bar BigWigsTimers.Bar
---@param remaining number
function BigWigsTimers:UpdateDisplay(display, trigger, bar, remaining)
    if display.kind == TEXTS then
        display.text:SetText(FormatText(trigger.Text, trigger, bar, remaining))
        display.text:SetTextColor(trigger.TextColor[1], trigger.TextColor[2], trigger.TextColor[3],
            trigger.TextColor[4])

        return
    end

    display.iconFrame.texture:SetTexture(bar.icon)
    display.leftText:SetText(FormatText(trigger.LeftText, trigger, bar, remaining))
    display.rightText:SetText(FormatText(trigger.RightText, trigger, bar, remaining))

    local color = (trigger.UseBigWigsColors and bar.bwBarColor) or trigger.BarColor
    display.statusBar:SetStatusBarColor(color[1], color[2], color[3], color[4])

    local text = (trigger.UseBigWigsColors and bar.bwTextColor) or trigger.TextColor
    display.leftText:SetTextColor(text[1], text[2], text[3], text[4])
    display.rightText:SetTextColor(text[1], text[2], text[3], text[4])

    -- The offset shifts what "full" means, so the fill is measured against the same shifted window.
    local total = bar.duration + trigger.Offset
    display.statusBar:SetValue(total > 0 and min(remaining / total, 1) or 0)
end

-- Evaluation --

---Static matching only runs when the bar registry changes, so the per-frame pass is just arithmetic.
function BigWigsTimers:RebuildMatches()
    self.matchDirty = nil

    for _, trigger in ipairs(self.activeTriggers) do
        local bars = self.matched[trigger]

        if not bars then
            bars = {}
            self.matched[trigger] = bars
        end
        wipe(bars)

        for _, bar in pairs(self.bars) do
            if self:BarMatchesTrigger(trigger, bar) then
                insert(bars, bar)

                -- A positive offset has to keep the bar in the registry past its own expiry.
                if trigger.Offset > 0 then
                    bar.keepUntil = max(bar.keepUntil or 0, bar.expirationTime + trigger.Offset)
                end
            end
        end
    end
end

function BigWigsTimers:EvaluateTriggers()
    for _, trigger in ipairs(self.activeTriggers) do
        local bars = self.matched[trigger]
        local bar, remaining = nil, nil

        if bars and #bars > 0 then
            bar, remaining = self:ResolveTrigger(trigger, bars)
        end

        if bar then
            local wasShown = self.displayByTrigger[trigger]
            local display = self:AcquireDisplay(trigger)

            if display then
                if not wasShown and trigger.ActionOnShowSound ~= 'None' then
                    NRSKNUI:PlaySafeSound(trigger.ActionOnShowSound)
                end

                self:UpdateDisplay(display, trigger, bar, remaining)
                self.groups[display.kind]:SetChildOrder(display.key, self.triggerOrder[trigger])
                self.groups[display.kind]:ActivateChild(display.key)
            end
        elseif self.displayByTrigger[trigger] then
            if trigger.ActionOnHideSound ~= 'None' then
                NRSKNUI:PlaySafeSound(trigger.ActionOnHideSound)
            end

            self:ReleaseDisplay(trigger)
        end
    end
end

---Called by the registry on every change, the work itself is deferred to the next tick.
function BigWigsTimers:OnBarsChanged()
    self.matchDirty = true

    if next(self.bars) then
        self:SetUpdaterRunning(true)
    end
end

function BigWigsTimers:OnUpdate()
    if self.isPreview then
        self:UpdatePreview()

        return
    end

    local anyBars = self:SweepExpiredBars()

    if self.matchDirty then self:RebuildMatches() end

    self:EvaluateTriggers()

    if not anyBars then self:SetUpdaterRunning(false) end
end

---@param running boolean
function BigWigsTimers:SetUpdaterRunning(running)
    if not self.updater then return end

    self.updater:SetShown(running)
end

-- Triggers for the current instance --

---Hand back the displays of triggers that are no longer being shown, leaving the rest running so a
---settings change does not restart every visible timer.
function BigWigsTimers:ReleaseStaleDisplays()
    if not self.groups then return end

    local live = {}

    if self.isPreview then
        for _, entry in ipairs(self.previewEntries) do
            live[entry.trigger] = true
        end
    else
        for _, trigger in ipairs(self.activeTriggers) do
            live[trigger] = true
        end
    end

    for trigger in pairs(self.displayByTrigger) do
        if not live[trigger] then
            self:ReleaseDisplay(trigger)
        end
    end
end

function BigWigsTimers:RebuildActiveTriggers()
    wipe(self.activeTriggers)
    wipe(self.triggerOrder)
    wipe(self.matched)

    if self.isPreview then
        if self.previewTrigger then
            insert(self.activeTriggers, self.previewTrigger)
            self.triggerOrder[self.previewTrigger] = 1
        end
    else
        local instance = self.currentInstanceId and self.db.Instances[self.currentInstanceId]

        if instance and instance.Enabled then
            for index, trigger in ipairs(instance.Triggers) do
                if trigger.Enabled then
                    insert(self.activeTriggers, trigger)
                    self.triggerOrder[trigger] = index
                end
            end
        end
    end

    self:ReleaseStaleDisplays()
    self.matchDirty = true
end

function BigWigsTimers:CheckInstance()
    local inInstance = IsInInstance()
    local instanceId = inInstance and select(8, GetInstanceInfo()) or nil

    if self.currentInstanceId == instanceId then return end

    self.currentInstanceId = instanceId
    self:WipeBars()
    self:RebuildActiveTriggers()
    self:UpdateActive()
end

---Derived from both, so a preview that starts and ends in the same zone still hands the live display back.
function BigWigsTimers:UpdateActive()
    local active = self.currentInstanceId ~= nil and not self.isPreview

    if self.active == active then return end
    self.active = active

    if active then
        self:RegisterCallbacks()
        for _, group in pairs(self.groups) do
            group:Show()
        end
    else
        self:UnregisterCallbacks()
        self:WipeBars() -- nothing maintains the registry once the callbacks are gone
        self:ReleaseAllDisplays()
        self:SetUpdaterRunning(false)

        for _, group in pairs(self.groups) do
            group:Hide()
        end
    end
end

-- Settings --

function BigWigsTimers:ApplySettings()
    if not self.groups then return end

    self:UpdateDB()

    for kind, group in pairs(self.groups) do
        local db = self.db[kind]

        group:SetConfig(db.Config)
        group:UpdateGroupPosition(db, db.Config.Grow)

        -- Suspended so a stack of displays re-lays out once rather than per display.
        group:Suspend()
        for _, display in ipairs(self.displays[kind]) do
            self:ConfigureDisplay(display)
        end
        group:Resume()

        -- Lowering the limit can leave displays assigned above it, they have to give their trigger back.
        for index = self:MaxDisplays(kind) + 1, #self.displays[kind] do
            local display = self.displays[kind][index]

            if display.trigger then self:ReleaseDisplay(display.trigger) end
        end
    end

    self:RebuildActiveTriggers()

    if self.isPreview then
        self:SyncPreview()
    end

    for _, group in pairs(self.groups) do
        group:ForceLayout()
    end
end

-- Lifecycle --

local COLOR_KEYS = { 'BarColor', 'TextColor' }

---Saved triggers are copies of the defaults, so a field added later never reaches them on its own.
function BigWigsTimers:RepairTriggers()
    for _, instance in pairs(self.db.Instances) do
        for _, trigger in ipairs(instance.Triggers) do
            for _, key in ipairs(COLOR_KEYS) do
                if type(trigger[key]) ~= 'table' then
                    trigger[key] = CopyTable(self.db.TriggerDefaults[key])
                end
            end

            trigger.BossId = trigger.BossId or 0
        end
    end
end

function BigWigsTimers:OnEnable()
    self:UpdateDB()
    self:CreateFrames()
    self:ApplySettings()

    self:RegisterEvent('PLAYER_ENTERING_WORLD', 'CheckInstance')
    self:RegisterEvent('ZONE_CHANGED_NEW_AREA', 'CheckInstance')

    NRSKNUI.LoadConditions:RegisterCallback(self, function() self.matchDirty = true end)

    self:CheckInstance()
end

function BigWigsTimers:OnDisable()
    NRSKNUI.LoadConditions:UnregisterCallback(self)

    self.currentInstanceId = nil -- cleared first so the preview teardown resolves straight to inactive
    self:HidePreview()

    if self.groups then self:UpdateActive() end
end

-- Preview --

local PREVIEW_SAMPLES = {
    bar = {
        { text = 'Tank Hit',     icon = 135771, count = 1, color = { 0.772, 0.168, 0.168, 1 } },
        { text = 'Tank Frontal', icon = 136106, count = 2, color = { 0.902, 0.549, 0.169, 1 } },
    },
    text = {
        { text = 'AOE',     icon = 132219, count = 1, color = { 1, 0, 0, 1 } },
        { text = 'DEBUFFS', icon = 136010, count = 2, color = { 0.12, 1, 0, 1 } },
        { text = 'SOAKS',   icon = 136010, count = 2, color = { 1, 0.67, 0.31, 1 } },
    },
}
local PREVIEW_KINDS = {
    { displayType = 'bar',  group = BARS,  colorKey = 'BarColor' },
    { displayType = 'text', group = TEXTS, colorKey = 'TextColor' },
}
local PREVIEW_DURATION = 12

---Enough samples to fill both groups to their own limits, so raising a limit shows more rather than leaving empty slots.
---@return { trigger: table, text: string, icon: number, count: number }[]
function BigWigsTimers:GetPreviewSamples()
    self.previewSamples = self.previewSamples or {}

    local samples = self.previewSamples
    local total = 0

    for _, kind in ipairs(PREVIEW_KINDS) do
        local pool = PREVIEW_SAMPLES[kind.displayType]

        for slot = 1, self:MaxDisplays(kind.group) do
            local sample = pool[(slot - 1) % #pool + 1]
            total = total + 1

            local entry = samples[total]

            if not entry then
                entry = { trigger = {} }
                samples[total] = entry
            end

            for key, value in pairs(self.db.TriggerDefaults) do
                entry.trigger[key] = value
            end

            -- Past one pass of the pool the names repeat, so the slot number keeps them apart.
            entry.text = slot <= #pool and sample.text or format('%s %d', sample.text, slot)
            entry.trigger.DisplayType = kind.displayType
            entry.trigger.Name = entry.text
            entry.trigger[kind.colorKey] = sample.color
            entry.icon = sample.icon
            entry.count = sample.count
        end
    end

    for extra = total + 1, #samples do
        samples[extra] = nil
    end

    return samples
end

---Bring the preview in line with the current settings without disturbing what is already on screen:
---timers that are still wanted keep their running countdown, only new ones start fresh.
function BigWigsTimers:SyncPreview()
    local now = GetTime()
    local wanted = {}

    for _, trigger in ipairs(self.activeTriggers) do
        local spellId = tonumber(trigger.SpellId)
        local icon = spellId and spellId > 0 and GetSpellTexture(spellId)

        insert(wanted, {
            trigger = trigger,
            text = trigger.Name,
            icon = icon or PREVIEW_SAMPLES.bar[1].icon,
            count = 1,
        })
    end

    -- Nothing configured yet still needs something on screen to drag both groups by, so the samples
    -- carry their own display type rather than all landing in the bar group.
    if #wanted == 0 then
        for _, sample in ipairs(self:GetPreviewSamples()) do
            insert(wanted, {
                trigger = sample.trigger,
                text = sample.text,
                icon = sample.icon,
                count = sample.count,
            })
        end
    end

    local existing = {}

    for _, entry in ipairs(self.previewEntries) do existing[entry.trigger] = entry end
    wipe(self.previewEntries)

    for _, source in ipairs(wanted) do
        local entry = existing[source.trigger]

        if entry then
            existing[source.trigger] = nil
        else
            entry = { trigger = source.trigger, bar = { duration = PREVIEW_DURATION, expirationTime = now + PREVIEW_DURATION } }
        end

        -- Everything config can change is refreshed; the countdown itself is left alone.
        local bar = entry.bar

        bar.spellId = source.trigger.SpellId
        bar.text = source.text
        bar.icon = source.icon
        bar.count = source.count
        bar.isCooldown = false
        bar.isBarEnabled = true
        bar.timerType = 'timer'
        bar.bwBarColor = source.trigger.BarColor
        bar.bwTextColor = source.trigger.TextColor
        bar.bwBgColor = source.trigger.BarColor

        insert(self.previewEntries, entry)
    end

    -- Whatever is left over is no longer previewed and gives its display back.
    for trigger in pairs(existing) do
        self:ReleaseDisplay(trigger)
    end

    self:SetUpdaterRunning(true)
end

function BigWigsTimers:UpdatePreview()
    local now = GetTime()

    for index, entry in ipairs(self.previewEntries) do
        local remaining = entry.bar.expirationTime - now

        if remaining <= 0 then
            entry.bar.expirationTime = now + PREVIEW_DURATION
            remaining = PREVIEW_DURATION
        end

        local display = self:AcquireDisplay(entry.trigger)

        if display then
            self:UpdateDisplay(display, entry.trigger, entry.bar, remaining)
            self.groups[display.kind]:SetChildOrder(display.key, index)
            self.groups[display.kind]:ActivateChild(display.key)
        end
    end
end

---@param trigger table? the timer being edited, nil for the sample preview
function BigWigsTimers:SetPreviewTrigger(trigger)
    if self.previewTrigger == trigger then return end

    self.previewTrigger = trigger

    if self.isPreview then
        self:RebuildActiveTriggers()
        self:SyncPreview()
    end
end

function BigWigsTimers:ShowPreview()
    self:CreateFrames()

    self.isPreview = true
    self:UpdateActive()

    for _, group in pairs(self.groups) do
        group:Show()
    end

    self:ApplySettings()
end

function BigWigsTimers:HidePreview()
    if not self.isPreview then return end
    self.isPreview = nil
    self.previewTrigger = nil

    wipe(self.previewEntries)
    self:ReleaseAllDisplays()
    self:RebuildActiveTriggers() -- preview built these from the edited timer, not the instance we are in
    self:UpdateActive()
end

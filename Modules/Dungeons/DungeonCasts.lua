---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class DungeonCastsModule
local DungeonCasts = NRSKNUI:GetModule('DungeonCasts')
function DungeonCasts:UpdateDB() self.db = NRSKNUI.db.profile.DungeonCasts end

local Anchors = NRSKNUI.Anchors

local GetRaidTargetIndex, SetRaidTargetIconTexture = GetRaidTargetIndex, SetRaidTargetIconTexture
local UnitSpellTargetName, UnitSpellTargetClass = UnitSpellTargetName, UnitSpellTargetClass
local UnitCastingInfo, UnitCastingDuration = UnitCastingInfo, UnitCastingDuration
local UnitChannelInfo, UnitChannelDuration = UnitChannelInfo, UnitChannelDuration
local UnitShouldDisplaySpellTargetName = UnitShouldDisplaySpellTargetName
local UnitEmpoweredChannelDuration = UnitEmpoweredChannelDuration
local UnitExists, UnitCanAttack = UnitExists, UnitCanAttack
local UnitAffectingCombat = UnitAffectingCombat
local pairs, ipairs, next = pairs, ipairs, next
local IsInInstance = IsInInstance
local CreateFrame = CreateFrame
local strsub = string.sub
local GetTime = GetTime
local unpack = unpack
local min = math.min

local CreateDuration = C_DurationUtil and C_DurationUtil.CreateDuration
local GetClassColor = C_ClassColor and C_ClassColor.GetClassColor

local Immediate = Enum and Enum.StatusBarInterpolation.Immediate
local ElapsedTime = Enum and Enum.StatusBarTimerDirection.ElapsedTime
local RemainingTime = Enum and Enum.StatusBarTimerDirection.RemainingTime

local FALLBACK_ICON = 136243
local MAX_NAMEPLATES = 40
local DEFAULT_MAX_BARS = 8
local UPDATE_THROTTLE = 0.1
local PREVIEW_DURATION = 8

local CAST_EVENTS = {
    -- Cast start events.
    UNIT_SPELLCAST_START = 'CastStart',
    UNIT_SPELLCAST_CHANNEL_START = 'CastStart',
    UNIT_SPELLCAST_EMPOWER_START = 'CastStart',

    -- Cast update events.
    UNIT_SPELLCAST_DELAYED = 'CastUpdate',
    UNIT_SPELLCAST_CHANNEL_UPDATE = 'CastUpdate',
    UNIT_SPELLCAST_EMPOWER_UPDATE = 'CastUpdate',

    -- Cast stop events.
    UNIT_SPELLCAST_STOP = 'CastStop',
    UNIT_SPELLCAST_CHANNEL_STOP = 'CastStop',
    UNIT_SPELLCAST_EMPOWER_STOP = 'CastStop',
    UNIT_SPELLCAST_FAILED = 'CastStop',
    UNIT_SPELLCAST_INTERRUPTED = 'CastStop',

    -- Cast interruptibility events.
    UNIT_SPELLCAST_INTERRUPTIBLE = 'CastInterruptible',
    UNIT_SPELLCAST_NOT_INTERRUPTIBLE = 'CastInterruptible',
}

-- The nameplate events are handled separately because they don't carry a cast id, so they can't be processed by the generic cast event handler.
local EVENT_HANDLERS = {
    NAME_PLATE_UNIT_ADDED = 'NameplateAdded',
    NAME_PLATE_UNIT_REMOVED = 'NameplateRemoved',
    UNIT_FLAGS = 'CombatFlagsChanged',
    UNIT_THREAT_LIST_UPDATE = 'CombatFlagsChanged',
}
for event, handler in pairs(CAST_EVENTS) do EVENT_HANDLERS[event] = handler end

---@param unit string?
---@return boolean
local function IsNameplate(unit)
    return unit ~= nil and strsub(unit, 1, 9) == 'nameplate'
end

---Checks if the unit is a valid nameplate that can be attacked, which is the only type of cast we care about.
---@param unit string
---@param requireCombat boolean
---@return boolean
local function IsValidUnit(unit, requireCombat)
    if not UnitExists(unit) or not UnitCanAttack('player', unit) then return false end
    return not requireCombat or UnitAffectingCombat(unit)
end

---How many bars the stack is allowed to hold, the group caps what it draws at the same number.
---@return number
function DungeonCasts:MaxBars()
    return (self.db.Config.UseLimit and self.db.Config.Limit) or DEFAULT_MAX_BARS
end

-- Frames --

function DungeonCasts:CreateFrames()
    if self.group then return end

    self.bars = {}
    self.byUnit = {}

    self.group = NRSKNUI:CreateDynamicGroup('NRSKNUI_DungeonCasts', UIParent)
    self.group:SetRolesets('encounterUI')

    local eventFrame = CreateFrame('Frame')
    eventFrame:SetScript('OnEvent', function(_, event, unit, ...)
        if not IsNameplate(unit) then return end

        self[EVENT_HANDLERS[event]](self, event, unit, ...)
    end)
    self.eventFrame = eventFrame

    -- The group owns its own OnUpdate for layout scheduling, so the timer text rides a separate frame.
    local updater = CreateFrame('Frame')
    updater:Hide()
    updater:NUIApplyOnUpdate(UPDATE_THROTTLE, function() self:OnUpdate() end)
    self.updater = updater

    Anchors:Register(self, 'DungeonCasts', self.group, 'dungeonCasts')
end

---@param index number
---@return Frame
function DungeonCasts:CreateBar(index)
    local bar = CreateFrame('Frame', nil, self.group)
    bar:EnableMouse(false)
    bar:NUICreateBackdrop(true)
    bar:NUISetPixelSnap()
    bar.key = 'bar' .. index

    -- Rendered above the fill and the icon so the frame reads as one unit.
    local borderFrame = CreateFrame('Frame', nil, bar)
    borderFrame:SetFrameLevel(bar:GetFrameLevel() + 5)
    borderFrame:NUIAddBorders()
    borderFrame:NUISetPixelSnap()
    bar.borderFrame = borderFrame

    local iconFrame = CreateFrame('Frame', nil, bar)
    iconFrame:NUIAddBorders()
    iconFrame:NUISetPixelSnap()
    iconFrame.texture = iconFrame:CreateTexture(nil, 'ARTWORK')
    bar.iconFrame = iconFrame

    local castBar = CreateFrame('StatusBar', nil, bar)
    castBar:SetMinMaxValues(0, 1)
    castBar:SetValue(0)
    bar.castBar = castBar

    local spark = castBar:CreateTexture(nil, 'OVERLAY')
    spark:NUISetPixelSnap()
    spark:SetBlendMode('ADD')
    bar.spark = spark

    bar.nameText = castBar:CreateFontString(nil, 'OVERLAY')
    bar.nameText:SetWordWrap(false)
    bar.timeText = castBar:CreateFontString(nil, 'OVERLAY')

    bar.targetText = castBar:CreateFontString(nil, 'OVERLAY')
    bar.targetText:SetWordWrap(false)
    bar.targetText:Hide()

    local marker = borderFrame:CreateTexture(nil, 'OVERLAY', nil, 7)
    marker:NUISetPixelSnap()
    marker:SetTexture('Interface/TargetingFrame/UI-RaidTargetingIcons')
    marker:Hide()
    bar.marker = marker

    self.bars[index] = bar
    self.group:AttachChild(bar, bar.key)
    self:ConfigureBar(bar)

    -- Visibility is the control point's job from here, the bar itself stays shown.
    bar:Show()
    return bar
end

---Configure the bar's size, colors and text elements based on the current settings.
---@param bar Frame
function DungeonCasts:ConfigureBar(bar)
    local db = self.db
    local w, h = db.Width, db.Height
    local bg, border, text = db.BackdropColor, db.BorderColor, db.TextColor
    local barTexture = NRSKNUI:GetStatusbar(db)
    local iconShown = db.Icon.Enabled

    bar:NUISetPixelSize(w, h)
    bar:SetBackgroundColor(bg[1], bg[2], bg[3], bg[4])

    -- Bars border.
    bar.borderFrame:SetAllPoints(bar)
    bar.borderFrame:SetBorderColor(border[1], border[2], border[3], border[4])

    -- Icon.
    bar.iconFrame:SetShown(iconShown)
    bar.iconFrame:NUISetPixelSize(h, h)
    bar.iconFrame:NUISetPixelPoint('LEFT', bar, 'LEFT', 0, 0)
    bar.iconFrame:SetBorderColor(border[1], border[2], border[3], border[4])
    bar.iconFrame.texture:NUISetPixelInside(bar.iconFrame, 1, 1)
    bar.iconFrame.texture:NUISetZoom()

    -- Main castbar.
    bar.castBar:ClearAllPoints()
    bar.castBar:NUISetPixelPoint('TOPLEFT', bar, 'TOPLEFT', iconShown and (h - 1) or 1, -1)
    bar.castBar:NUISetPixelPoint('BOTTOMRIGHT', bar, 'BOTTOMRIGHT', -1, 1)
    bar.castBar:SetStatusBarTexture(barTexture)

    -- Spark.
    NRSKNUI:SetSpark(bar.spark, db, h)
    bar.spark:SetPoint('CENTER', bar.castBar:GetStatusBarTexture(), 'RIGHT', 0, 0)

    -- Timer text.
    bar.timeText:SetFontStyle(db)
    bar.timeText:SetFontJustify('RIGHT', bar.castBar, -4, 0)
    bar.timeText:SetTextColor(text[1], text[2], text[3], text[4])
    bar.timeText:SetShown(db.ShowTime)
    bar.timeText:SetWidth(25)
    if not db.ShowTime then bar.timeText:SetText('') end

    -- Cast name text.
    bar.nameText:SetFontStyle(db)
    bar.nameText:SetFontJustify('LEFT', bar.castBar, 4, 0)
    bar.nameText:SetTextColor(text[1], text[2], text[3], text[4])

    -- Target name text is a special case, it is boxed between the other two strings so it truncates rather than overrunning either.
    bar.targetText:SetTextColor(text[1], text[2], text[3], text[4]) -- We override this later if class coloring is enabled.
    bar.targetText:SetFontStyle(db)
    bar.targetText:SetFontJustify(db.Target.Position, bar.castBar, 0, 0, nil, {
        { relTo = bar.nameText, point = 'LEFT',  relPoint = 'RIGHT', offsetX = 1 },
        { relTo = bar.timeText, point = 'RIGHT', relPoint = 'LEFT',  offsetX = -1 },
    })

    -- The update loop skips target work entirely when disabled, so it can't retire a shown string.
    if not db.Target.Enabled then bar.targetText:Hide() end

    -- Raidmarker icon.
    bar.marker:NUISetPixelSize(db.RaidIcon.Size, db.RaidIcon.Size)
    bar.marker:ClearAllPoints()
    bar.marker:NUISetPixelPoint(db.RaidIcon.Anchor, bar, db.RaidIcon.Anchor, db.RaidIcon.XOffset, db.RaidIcon.YOffset)

    -- Notify the group that the bar has been resized so it can re-layout if needed.
    self.group:NotifyChildResized(bar.key, w, h)
end

function DungeonCasts:ApplySettings()
    if not self.group then return end

    self.durationFormatter = NRSKNUI:GetAuraDurationFormatter() --TODO: Add a cast specifc formatter to the API so it can be used here.
    self.requireCombat = self.db.RequireCombat
    self.targetEnabled = self.db.Target.Enabled
    self.targetClassColor = self.db.Target.ShowClassColor
    self.targetPrefix, self.targetSuffix = nil, nil

    local separator = NRSKNUI.Separators[self.db.Target.Separator] and self.db.Target.Separator
    if separator then
        if self.db.Target.Position == 'LEFT' then
            self.targetPrefix = separator .. ' '
        else
            self.targetSuffix = ' ' .. separator
        end
    end

    self.colCast = NRSKNUI:CreateColor(unpack(self.db.CastColor))
    self.colChannel = NRSKNUI:CreateColor(unpack(self.db.ChannelColor))
    self.colUninterruptible = NRSKNUI:CreateColor(unpack(self.db.NotInterruptibleColor))

    self.group:SetConfig(self.db.Config)
    self.group:UpdateGroupPosition(self.db, self.db.Config.Grow)

    -- Suspended so a stack of bars re-lays out once at the end rather than per bar.
    self.group:Suspend()
    for _, bar in ipairs(self.bars) do
        self:ConfigureBar(bar)
    end
    self.group:Resume()

    for _, bar in pairs(self.byUnit) do
        self:UpdateBarColor(bar)
    end

    -- Lowering the limit can leave bars assigned above it, they have to give their unit back.
    local max = self:MaxBars()
    for index = max + 1, #self.bars do
        local bar = self.bars[index]

        if bar.unit then
            self:ReleaseBar(bar.unit)
        end
    end

    if self.isPreview then
        self:BuildPreviewBars()
    elseif self.active then
        -- Toggling the combat gate has to re-evaluate every live nameplate, no cast event will fire for it.
        self:ScanNameplates()
    end

    self.group:ForceLayout()
end

-- Bar assignment --

---@param unit string
---@return Frame?
function DungeonCasts:AcquireBar(unit)
    local bar = self.byUnit[unit]
    if bar then return bar end

    for index = 1, self:MaxBars() do
        local candidate = self.bars[index] or self:CreateBar(index)
        if not candidate.unit then
            candidate.unit = unit
            self.byUnit[unit] = candidate
            return candidate
        end
    end
end

---@param unit string
function DungeonCasts:ReleaseBar(unit)
    local bar = self.byUnit[unit]
    if not bar then return end

    self.byUnit[unit] = nil
    bar.unit, bar.castBarID, bar.channeling, bar.notInterruptible = nil, nil, nil, nil
    bar.startTime, bar.previewMarker, bar.duration = nil, nil, nil
    bar.targetText:Hide()
    bar.marker:Hide()
    self.group:DeactivateChild(bar.key)
end

function DungeonCasts:ReleaseAllBars()
    for unit in pairs(self.byUnit) do
        self:ReleaseBar(unit)
    end

    self:SetUpdaterRunning(false)
end

---@param running boolean
function DungeonCasts:SetUpdaterRunning(running)
    if not self.updater then return end
    if running then
        self.updater:Show()
    else
        self.updater:Hide()
    end
end

-- Bar content --

---@param bar Frame
function DungeonCasts:UpdateBarColor(bar)
    local base = bar.channeling and self.colChannel or self.colCast

    bar.castBar:GetStatusBarTexture():SetVertexColorFromBoolean(bar.notInterruptible, self.colUninterruptible, base)
end

---@param bar Frame
---@param unit string
function DungeonCasts:UpdateMarker(bar, unit)
    if not self.db.RaidIcon.Enabled then
        bar.marker:Hide()
        return
    end

    local index = self.isPreview and bar.previewMarker or GetRaidTargetIndex(unit)
    if index == nil then
        bar.marker:Hide()
        return
    end

    SetRaidTargetIconTexture(bar.marker, index)
    bar.marker:Show()
end

function DungeonCasts:RAID_TARGET_UPDATE()
    if self.isPreview then return end

    for unit, bar in pairs(self.byUnit) do
        self:UpdateMarker(bar, unit)
    end
end

---Returns a finished target name string with class coloring (if enabled) and separator applied.
---@param unit string
---@param targetName string
---@param preview boolean UnitSpellTargetClass is not populated in preview mode, so the player's class is used instead.
---@return string
function DungeonCasts:GetTargetText(unit, targetName, preview)
    if self.targetClassColor then
        if not preview then
            local className = UnitSpellTargetClass(unit)
            if className then
                local color = GetClassColor(className)
                targetName = color:WrapTextInColorCode(targetName)
            end
        else
            local color = GetClassColor(NRSKNUI.MyClass)
            targetName = color:WrapTextInColorCode(targetName)
        end
    end

    local prefix, suffix = self.targetPrefix, self.targetSuffix
    if prefix then return prefix .. targetName end
    if suffix then return targetName .. suffix end

    return targetName
end

---@param bar Frame
---@param unit string
function DungeonCasts:UpdateTargetText(bar, unit)
    -- First pass, is the feature enabled at all?
    if not self.targetEnabled then
        bar.targetText:Hide()
        return
    end

    -- Second pass, the plain visibility flag gates the name query, which is a secret on nameplates.
    if not UnitShouldDisplaySpellTargetName(unit) then
        bar.targetText:Hide()
        return
    end

    -- Third pass, is the target name populated yet?
    local targetName = UnitSpellTargetName(unit)
    if not (targetName ~= nil) then
        bar.targetText:Hide()
        return
    end

    bar.targetText:SetText(self:GetTargetText(unit, targetName, self.isPreview))
    bar.targetText:Show()
end

-- Cast events --

function DungeonCasts:CastStart(_, unit)
    if self.isPreview then return end

    if not IsValidUnit(unit, self.requireCombat) then
        self:ReleaseBar(unit)
        if not next(self.byUnit) then
            self:SetUpdaterRunning(false)
        end
        return
    end

    local _, isEmpowered, duration, direction, channeling
    local name, displayName, textureID, notInterruptible, spellID, castBarID

    -- Check if the unit is casting.
    name, displayName, textureID, _, _, _, _, notInterruptible, spellID, castBarID = UnitCastingInfo(unit)
    if name then
        duration, direction = UnitCastingDuration(unit), ElapsedTime
    else
        -- Unit is not casting, check if it is channeling.
        name, displayName, textureID, _, _, _, notInterruptible, spellID, isEmpowered, _, castBarID = UnitChannelInfo(unit)

        -- No cast or channel is running at all.
        if not name then
            self:ReleaseBar(unit)
            return
        end

        channeling = true

        -- Check if the channel is empowered.
        -- The empowered channel duration is the total duration of the channel, not the remaining time, so it is treated as an elapsed timer.
        if isEmpowered then
            duration, direction = UnitEmpoweredChannelDuration(unit), ElapsedTime
        else
            duration, direction = UnitChannelDuration(unit), RemainingTime
        end
    end

    if not duration then return end

    local bar = self:AcquireBar(unit)
    if not bar then return end

    -- Store cast info on the bar so it can be matched to future events and updated.
    bar.castBarID = castBarID
    bar.channeling = channeling
    bar.notInterruptible = notInterruptible
    bar.startTime = GetTime()
    bar.duration = duration

    bar.iconFrame.texture:SetTexture(textureID or FALLBACK_ICON)
    bar.nameText:SetText(displayName or name)
    bar.timeText:SetText('')
    bar.castBar:SetTimerDuration(duration, Immediate, direction)

    self:UpdateBarColor(bar)
    self:UpdateMarker(bar, unit)
    self:UpdateTargetText(bar, unit)

    -- Start time as the sort key keeps the oldest cast at the head of the stack.
    self.group:SetChildOrder(bar.key, bar.startTime)
    self.group:ActivateChild(bar.key)
    self:SetUpdaterRunning(true)
end

---Pushback, channel clipping and empower extensions all re-issue the duration for the running cast.
function DungeonCasts:CastUpdate(event, unit, castGUID, spellID, castBarID)
    local bar = self.byUnit[unit]
    if not bar or bar.castBarID ~= castBarID then return end

    local duration, direction
    if event == 'UNIT_SPELLCAST_DELAYED' then
        duration, direction = UnitCastingDuration(unit), ElapsedTime
    elseif event == 'UNIT_SPELLCAST_EMPOWER_UPDATE' then
        duration, direction = UnitEmpoweredChannelDuration(unit), ElapsedTime
    else
        duration, direction = UnitChannelDuration(unit), RemainingTime
    end

    if not duration then return end

    bar.duration = duration
    bar.castBar:SetTimerDuration(duration, Immediate, direction)
end

---The cast id sits at a different payload position per event, so it is picked out before matching.
function DungeonCasts:CastStop(event, unit, castGUID, spellID, a, b, c)
    local bar = self.byUnit[unit]
    if not bar then return end

    local castBarID
    if event == 'UNIT_SPELLCAST_EMPOWER_STOP' then
        castBarID = c
    elseif event == 'UNIT_SPELLCAST_CHANNEL_STOP' or event == 'UNIT_SPELLCAST_INTERRUPTED' then
        castBarID = b
    else
        castBarID = a
    end

    if bar.castBarID ~= castBarID then return end

    self:ReleaseBar(unit)
    if not next(self.byUnit) then
        self:SetUpdaterRunning(false)
    end
end

---The payload carries no cast id, so the flag comes from the event itself instead of a re-query.
function DungeonCasts:CastInterruptible(event, unit)
    local bar = self.byUnit[unit]
    if not bar then return end

    bar.notInterruptible = event == 'UNIT_SPELLCAST_NOT_INTERRUPTIBLE'
    self:UpdateBarColor(bar)
end

---Un-pulled mobs channel indefinitely or cast on random mobs, so their bar only appears once they are actually engaged.
---@param unit string
function DungeonCasts:CombatFlagsChanged(_, unit)
    if self.isPreview or not self.requireCombat then return end

    if UnitAffectingCombat(unit) then
        -- Only on the transition, a re-entry would reset the start time the stack is sorted on.
        if not self.byUnit[unit] then
            self:CastStart(nil, unit)
        end
    else
        self:ReleaseBar(unit)
        if not next(self.byUnit) then
            self:SetUpdaterRunning(false)
        end
    end
end

function DungeonCasts:NameplateAdded(_, unit)
    self:CastStart(nil, unit)
end

function DungeonCasts:NameplateRemoved(_, unit)
    self:ReleaseBar(unit)
    if not next(self.byUnit) then
        self:SetUpdaterRunning(false)
    end
end

-- Update loop --

function DungeonCasts:OnUpdate()
    local showTime = self.db.ShowTime
    local formatter = self.durationFormatter

    -- Preview target text is written once at build time, so only live bars need the re-read.
    local showTarget = self.targetEnabled and not self.isPreview

    for unit, bar in pairs(self.byUnit) do
        if showTime then
            bar.timeText:SetText(bar.duration:FormatRemainingDuration(formatter))
        end

        -- The spell target is not populated yet on the start event, so it is re-read here.
        if showTarget then
            self:UpdateTargetText(bar, unit)
        end
    end
end

-- Instance gating --

---@param active boolean
function DungeonCasts:SetActive(active)
    if self.active == active then return end
    self.active = active

    if active then
        self.eventFrame:RegisterEvent('NAME_PLATE_UNIT_ADDED')
        self.eventFrame:RegisterEvent('NAME_PLATE_UNIT_REMOVED')
        self.eventFrame:RegisterEvent('UNIT_FLAGS')
        self.eventFrame:RegisterEvent('UNIT_THREAT_LIST_UPDATE')
        for event in pairs(CAST_EVENTS) do
            self.eventFrame:RegisterEvent(event)
        end

        self.group:Show()
        self:ScanNameplates()
    else
        self.eventFrame:UnregisterAllEvents()
        self:ReleaseAllBars()
        self.group:Hide()
    end
end

function DungeonCasts:ScanNameplates()
    for i = 1, MAX_NAMEPLATES do
        local unit = 'nameplate' .. i

        if UnitExists(unit) then
            self:CastStart(nil, unit)
        end
    end
end

function DungeonCasts:CheckInstance()
    if self.isPreview or not self:IsEnabled() then return end

    local inInstance, instanceType = IsInInstance()
    self:SetActive(inInstance and instanceType == 'party' or false)
end

-- Lifecycle --

function DungeonCasts:OnEnable()
    self:CreateFrames()
    self:ApplySettings()

    self:RegisterEvent('PLAYER_ENTERING_WORLD', 'CheckInstance')
    self:RegisterEvent('ZONE_CHANGED_NEW_AREA', 'CheckInstance')
    self:RegisterEvent('RAID_TARGET_UPDATE')

    self:CheckInstance()
end

function DungeonCasts:OnDisable()
    self:HidePreview()

    if self.group then
        self:SetActive(false)
        self.group:Hide()
    end
end

-- Preview --

local PREVIEW_SPELLS = {
    { name = 'Shadow Bolt',     icon = 136197, shielded = false, channeling = false, marker = 8,   target = true },
    { name = 'Drain Life',      icon = 136169, shielded = true,  channeling = true,  marker = 4,   target = false },
    { name = 'Fireball',        icon = 135812, shielded = false, channeling = false, marker = 1,   target = true },
    { name = 'Frostbolt',       icon = 135846, shielded = false, channeling = false, marker = 6,   target = true },
    { name = 'Arcane Missiles', icon = 136096, shielded = false, channeling = true,  marker = 2,   target = false },
    { name = 'Pyroblast',       icon = 135808, shielded = false, channeling = false, marker = 7,   target = true },
    { name = 'Mind Flay',       icon = 136208, shielded = true,  channeling = true,  marker = 3,   target = true },
    { name = 'Lightning Bolt',  icon = 136048, shielded = false, channeling = false, marker = 5,   target = false },
    { name = 'Heal',            icon = 135916, shielded = true,  channeling = false, marker = nil, target = false },
    { name = 'Chain Lightning', icon = 136015, shielded = false, channeling = false, marker = nil, target = true },
}

function DungeonCasts:BuildPreviewBars()
    for unit in pairs(self.byUnit) do
        self:ReleaseBar(unit)
    end

    local count = min(self:MaxBars(), #PREVIEW_SPELLS)
    local now = GetTime()

    for index = 1, count do
        local spell = PREVIEW_SPELLS[index]
        local unit = 'preview' .. index
        local bar = self:AcquireBar(unit)
        if not bar then break end

        bar.channeling = spell.channeling
        bar.notInterruptible = spell.shielded
        bar.previewMarker = spell.marker
        bar.startTime = now + index * 0.001

        local duration = CreateDuration()
        duration:SetTimeFromStart(now, PREVIEW_DURATION)
        bar.duration = duration

        bar.iconFrame.texture:SetTexture(spell.icon)
        bar.nameText:SetText(spell.name)
        bar.castBar:SetTimerDuration(duration, Immediate, spell.channeling and RemainingTime or ElapsedTime)

        self:UpdateBarColor(bar)
        self:UpdateMarker(bar, unit)

        if self.targetEnabled and spell.target then
            bar.targetText:SetText(self:GetTargetText('player', NRSKNUI.MyName, self.isPreview))
            bar.targetText:Show()
        else
            bar.targetText:Hide()
        end

        self.group:SetChildOrder(bar.key, bar.startTime)
        self.group:ActivateChild(bar.key)
    end

    self:SetUpdaterRunning(true)
end

function DungeonCasts:ShowPreview()
    self:CreateFrames()

    self.isPreview = true
    self:SetActive(false)
    self.group:Show()

    self:ApplySettings()

    if self.previewTicker then
        self.previewTicker:Cancel()
    end

    self.previewTicker = C_Timer.NewTicker(PREVIEW_DURATION, function()
        if self.isPreview then
            self:BuildPreviewBars()
        end
    end)
end

function DungeonCasts:HidePreview()
    if not self.isPreview then return end
    self.isPreview = false

    if self.previewTicker then
        self.previewTicker:Cancel()
        self.previewTicker = nil
    end

    self:ReleaseAllBars()
    self:CheckInstance()
end

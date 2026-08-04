---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
---@field Preview UnitFramesPreview
local UF = NRSKNUI:GetModule('UnitFrames')
local Theme = NRSKNUI.Theme

local UnregisterStateDriver = UnregisterStateDriver
local UnregisterUnitWatch = UnregisterUnitWatch
local RegisterUnitWatch = RegisterUnitWatch
local ipairs, pairs = ipairs, pairs
local CreateFrame = CreateFrame
local format = string.format

local LABEL_SIZE = 13
local LABEL_LEVEL = 1100 -- Above the indicator container, which sits at 1000.

---@class UnitFramesPreview
local Preview = {}
UF.Preview = Preview

local groups = {}      -- entry-based previews, i.e. the boss chain
local groupStates = {} -- header-driven previews, keyed by config key

---@param group string
---@return table
local function GetGroup(group)
    local state = groups[group]
    if not state then
        state = { wanted = false, active = false, entries = {} }
        groups[group] = state
    end
    return state
end

---@param frame oUF.UnitFrame
---@param text string
local function ShowLabel(frame, text)
    local label = frame.nuiPreviewLabel
    if not label then
        local overlay = CreateFrame('Frame', nil, frame)
        overlay:SetAllPoints(frame)
        overlay:SetFrameLevel(LABEL_LEVEL)

        label = overlay:CreateFontString(nil, 'OVERLAY')
        label:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 0, 16)
        label:SetFontStyle(nil, LABEL_SIZE, 'OUTLINE')
        frame.nuiPreviewLabel = label
    end

    label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0) --TODO: Figure our what to do with this.
    label:SetText(text)
    label:Show()
end

---@param frame oUF.UnitFrame
local function HideLabel(frame)
    if frame.nuiPreviewLabel then
        frame.nuiPreviewLabel:Hide()
    end
end

---@param entry table
local function ApplyFrame(entry)
    local frame = entry.frame
    if frame.nuiPreviewUnit then return end

    frame.nuiPreviewUnit = entry.unit
    frame.unit = entry.unit
    frame:EnableMouse(false)

    -- asState keeps the watch from hiding the frame again the moment its real unit is missing.
    UnregisterUnitWatch(frame)
    RegisterUnitWatch(frame, true)

    -- Show first: oUF repaints every element on OnShow, which would undo the preview overrides that
    -- ConfigureFrame applies at the end of its pass.
    frame:Show()

    -- Rebuild against the preview unit: the elements that bind a unit at configure time rather
    -- than on every update (range, aura containers) only follow through here. ConfigureFrame ends
    -- in a full element pass, so nothing else has to repaint the frame.
    UF:ConfigureFrame(frame, frame.nrsknUnit)

    ShowLabel(frame, entry.label)
end

---@param entry table
local function RestoreFrame(entry)
    local frame = entry.frame
    if not frame.nuiPreviewUnit then return end

    frame.nuiPreviewUnit = nil
    frame.unit = frame.nrsknUnit
    frame:EnableMouse(true)

    HideLabel(frame)

    -- Clears the asState watch mode, ConfigureFrame re-registers the normal show/hide watch.
    UnregisterUnitWatch(frame)
    UF:ConfigureFrame(frame, frame.nrsknUnit)
end

---Register a frame as previewable. Calling it again for the same frame refreshes its preview data.
---@param group string preview group, e.g. 'boss'
---@param frame oUF.UnitFrame
---@param unit string the live unit the frame renders while previewing
---@param label string text drawn over the frame while previewing
function Preview:Register(group, frame, unit, label)
    local entries = GetGroup(group).entries

    for _, entry in ipairs(entries) do
        if entry.frame == frame then
            entry.unit, entry.label = unit, label
            return
        end
    end

    entries[#entries + 1] = { frame = frame, unit = unit, label = label }

    -- Position in the group, read by elements that vary their preview per frame.
    frame.nuiPreviewIndex = #entries
end

---@param group string
---@return boolean
function Preview:IsActive(group)
    return GetGroup(group).active
end

-- The combat watch only runs while something is being previewed.
local function UpdateCombatWatch()
    for _, state in pairs(groups) do
        if state.wanted then
            UF:RegisterEvent('PLAYER_REGEN_DISABLED')
            return
        end
    end
    for _, state in pairs(groupStates) do
        if state.wanted then
            UF:RegisterEvent('PLAYER_REGEN_DISABLED')
            return
        end
    end
    UF:UnregisterEvent('PLAYER_REGEN_DISABLED')
end

---Apply a group that is wanted but not yet showing.
---@param state table
local function Apply(state)
    if state.active or NRSKNUI:InCombat() then return end

    state.active = true
    for _, entry in ipairs(state.entries) do
        ApplyFrame(entry)
    end
end

---Take a group off the screen, leaving `wanted` for the caller to decide.
---@param state table
local function Restore(state)
    if not state.active then return end
    state.active = false

    -- The label and the element previews are unprotected, so they always come down immediately.
    -- That matters on the combat path: a fake boss cast must not survive a pull.
    for _, entry in ipairs(state.entries) do
        HideLabel(entry.frame)
        UF:ApplyElementPreviews(entry.frame, entry.frame.nrsknUnit, false)
    end

    -- Restoring the frames themselves touches protected state, so hand that to the combat queue if
    -- the lockdown already landed. They keep rendering the preview unit until then.
    local function RestoreFrames()
        for _, entry in ipairs(state.entries) do
            RestoreFrame(entry)
        end
    end

    NRSKNUI:RunWhenSafe(RestoreFrames)
end

---Ask for a group to be previewed and keep asking until it is released.
---@param group string
function Preview:Request(group)
    local state = GetGroup(group)
    state.wanted = true
    UpdateCombatWatch()
    Apply(state)
end

---Drop the request and take the group off the screen.
---@param group string
function Preview:Release(group)
    local state = GetGroup(group)
    if not state.wanted and not state.active then return end

    state.wanted = false
    UpdateCombatWatch()
    Restore(state)
end

function Preview:ReleaseAll()
    for group in pairs(groups) do
        self:Release(group)
    end
end

-- Group previews --

-- A header with no show* attribute matching builds children from startingIndex alone, so a negative
-- one makes it lay out a full column of unit-less frames. See SecureGroupHeaders configureChildren.
local FORCED_START = -(UF.GROUP_SIZE - 1)

---@param key string
---@return table
local function GetGroupState(key)
    local state = groupStates[key]
    if not state then
        state = { wanted = false, active = false }
        groupStates[key] = state
    end
    return state
end

---@param frame oUF.UnitFrame
---@param index number
---@param label string
local function ForceChild(frame, index, label)
    if not frame.nuiPreviewUnit then
        frame.nuiPreviewUnit = 'player'
        frame.unit = 'player'
        frame.nuiPreviewIndex = index
        frame:EnableMouse(false)

        UnregisterUnitWatch(frame)
        RegisterUnitWatch(frame, true)
    end

    frame:Show()
    UF:ConfigureFrame(frame, frame.nuiConfig)
    ShowLabel(frame, label)
end

---@param frame oUF.UnitFrame
local function RestoreChild(frame)
    if not frame.nuiPreviewUnit then return end

    frame.nuiPreviewUnit = nil
    -- The forced children past the real roster carry no unit, so fall back rather than nil it out.
    frame.unit = frame:GetAttribute('unit') or frame.nrsknUnit
    frame:EnableMouse(true)

    HideLabel(frame)
    UnregisterUnitWatch(frame)
    RegisterUnitWatch(frame)
    UF:ConfigureFrame(frame, frame.nuiConfig)
end

---@param header Frame
---@param fn fun(child: Frame, index: number)
local function ForEachChild(header, fn)
    local index = 1
    local child = header:GetAttribute('child' .. index)
    while child do
        fn(child, index)
        index = index + 1
        child = header:GetAttribute('child' .. index)
    end
end

---Drive a forced header back to the forced state. Also the OnAttributeChanged hook, since the header
---resets startingIndex whenever it re-runs its own layout.
---@param header Frame
local function ForceHeader(header)
    if not header.nuiForced or not header:IsShown() then return end

    -- Comparing first is what stops the SetAttribute below from recursing forever.
    if header:GetAttribute('startingIndex') ~= FORCED_START then
        header:SetAttribute('startingIndex', FORCED_START)
    end

    ForEachChild(header, function(child, index)
        ForceChild(child, index, format('%s %d', header.nuiLabel, index))
    end)
end

---@param key string
---@param state table
local function ApplyGroup(key, state)
    local group = UF.groups[key]
    if state.active or not group or NRSKNUI:InCombat() then return end

    state.active = true
    group.container.nuiPreviewing = true

    UnregisterStateDriver(group.container, 'visibility')
    group.container:Show()

    for _, header in ipairs(group.headers) do
        if not header.nuiHooked then
            header.nuiHooked = true
            header:HookScript('OnAttributeChanged', ForceHeader)
        end

        header.nuiForced = true
        for attr in pairs(header.nuiShown) do
            header:SetAttribute(attr, nil)
        end

        ForceHeader(header)
    end
end

---@param key string
---@param state table
local function RestoreGroup(key, state)
    local group = UF.groups[key]
    if not state.active or not group then return end
    state.active = false

    -- Labels and element previews are unprotected, so they always come down immediately.
    for _, header in ipairs(group.headers) do
        header.nuiForced = nil
        ForEachChild(header, function(child)
            HideLabel(child)
            UF:ApplyElementPreviews(child, child.nuiConfig, false)
        end)
    end

    NRSKNUI:RunWhenSafe(function()
        for _, header in ipairs(group.headers) do
            for attr, value in pairs(header.nuiShown) do
                header:SetAttribute(attr, value)
            end
            header:SetAttribute('startingIndex', 1)
            ForEachChild(header, RestoreChild)
        end

        group.container.nuiPreviewing = nil
        UF:ApplyGroupVisibility(key)
    end)
end

---Stop honouring the forced state while a caller rewrites header attributes. Each write re-runs
---SecureGroupHeader_Update, which clears the points of every child it is not currently displaying,
---and re-forcing in that window shows them unanchored.
---@param key string config key
---@return boolean suspended whether ResumeGroup has to be called
function Preview:SuspendGroup(key)
    local state = groupStates[key]
    if not state or not state.active then return false end

    local group = UF.groups[key]
    if not group then return false end

    for _, header in ipairs(group.headers) do
        header.nuiForced = nil
    end
    return true
end

---@param key string config key
function Preview:ResumeGroup(key)
    local group = UF.groups[key]
    if not group then return end

    for _, header in ipairs(group.headers) do
        header.nuiForced = true
        ForceHeader(header)
    end
end

---Ask for a group unit to be previewed and keep asking until it is released.
---@param key string config key
function Preview:RequestGroup(key)
    local state = GetGroupState(key)
    state.wanted = true
    UpdateCombatWatch()
    ApplyGroup(key, state)
end

---@param key string config key
function Preview:ReleaseGroup(key)
    local state = GetGroupState(key)
    if not state.wanted and not state.active then return end

    state.wanted = false
    UpdateCombatWatch()
    RestoreGroup(key, state)
end

function Preview:ReleaseAllGroups()
    for key in pairs(groupStates) do
        self:ReleaseGroup(key)
    end
end

-- Aura previews --

-- Kept per config key rather than per group: the GUI only ever configures one unit's auras at a time
-- and dummy buttons on every frame at once is what makes a preview expensive. Config keys rather than
-- normalized tokens, so the raid tiers stay apart, see UF.GroupConfigs.
local auraUnits = {}

---Repaint the aura element on every frame a config renders, so 'boss' covers all eight of them.
---Goes through ForEachFrame: header children are not in UF.frames, and a walk that misses them
---leaves their dummies up with no way to take them back down.
---@param key string config key
local function RefreshAuraPreviews(key)
    UF:ForEachFrame(function(frame, unit)
        UF.Elements.Auras.Preview(frame, unit, UF.GetUnitDB(unit))
    end, key)
end

---Show dummy auras on a config's frames and keep showing them until released.
---@param unit string
function Preview:RequestAuras(unit)
    local key = UF.ConfigKey(unit)
    if auraUnits[key] then return end

    auraUnits[key] = true
    RefreshAuraPreviews(key)
end

---@param unit string
function Preview:ReleaseAuras(unit)
    local key = UF.ConfigKey(unit)
    if not auraUnits[key] then return end

    auraUnits[key] = nil
    RefreshAuraPreviews(key)
end

function Preview:ReleaseAllAuras()
    for key in pairs(auraUnits) do
        auraUnits[key] = nil
        RefreshAuraPreviews(key)
    end
end

---@param unit string config key or unit token
---@return boolean
function Preview:IsAuraPreviewActive(unit)
    return auraUnits[UF.ConfigKey(unit)] == true
end

-- config key -> the placement index whose indicator is previewing, set from the GUI's open tab.
local indicatorSlots = {}

---@param key string config key
local function RefreshIndicatorPreviews(key)
    UF:ForEachFrame(function(frame, unit)
        UF.Elements.AuraIndicators.Preview(frame, unit, UF.GetUnitDB(unit))
    end, key)
end

---Preview one placement's indicator, replacing whatever the unit was previewing before.
---@param unit string
---@param index number?
function Preview:RequestAuraIndicator(unit, index)
    local key = UF.ConfigKey(unit)
    if indicatorSlots[key] == index then return end

    indicatorSlots[key] = index
    RefreshIndicatorPreviews(key)
end

function Preview:ReleaseAllAuraIndicators()
    for key in pairs(indicatorSlots) do
        indicatorSlots[key] = nil
        RefreshIndicatorPreviews(key)
    end
end

---@param unit string config key or unit token
---@return number? index
function Preview:GetAuraIndicatorSlot(unit)
    return indicatorSlots[UF.ConfigKey(unit)]
end

-- config key -> the uDB.Indicators key whose icon is force-shown, set from the GUI's open tab.
local indicatorKeys = {}

---@param key string config key
local function RefreshIndicators(key)
    UF:ForEachFrame(function(frame, unit)
        UF.Elements.Indicators.Preview(frame, unit, UF.GetUnitDB(unit))
    end, key)
end

---@param unit string
---@param indicator string? nil to stop previewing
function Preview:RequestIndicator(unit, indicator)
    local key = UF.ConfigKey(unit)
    if indicatorKeys[key] == indicator then return end

    indicatorKeys[key] = indicator
    RefreshIndicators(key)
end

function Preview:ReleaseAllIndicators()
    for key in pairs(indicatorKeys) do
        indicatorKeys[key] = nil
        RefreshIndicators(key)
    end
end

---@param unit string config key or unit token
---@return string? indicator
function Preview:GetIndicatorKey(unit)
    return indicatorKeys[UF.ConfigKey(unit)]
end

---Show a preview for a page. The page is responsible for calling Release when it closes or switches away.
---@param pageId string? the page asking, e.g. 'unitFrames_target'
---@param showAll boolean? whether everything is being previewed
function UF:ShowPreview(pageId, showAll)
    if showAll then
        Preview:Request('boss')
        for key in pairs(UF.GroupConfigs) do
            Preview:RequestGroup(key)
        end
    end

    local unit = pageId and pageId:match('^unitFrames_(.+)$')
    if not unit then return end

    Preview:RequestAuras(unit)
    if unit == 'boss' then Preview:Request('boss') end
    if UF.GroupConfigs[unit] then Preview:RequestGroup(unit) end
end

---Called by PreviewManager when the page changes or the window closes.
function UF:HidePreview()
    Preview:ReleaseAllAuras()
    Preview:ReleaseAllAuraIndicators()
    Preview:ReleaseAllIndicators()
    Preview:ReleaseAll()
    Preview:ReleaseAllGroups()
end

---Preview the indicator on one placement, driven by the aura indicator tab the GUI has open.
---@param unit string
---@param index number? nil to stop previewing
function UF:PreviewAuraIndicator(unit, index)
    Preview:RequestAuraIndicator(unit, index)
end

---Force-show one indicator, driven by the indicator tab the GUI has open.
---@param unit string
---@param indicator string? nil to stop previewing
function UF:PreviewIndicator(unit, indicator)
    Preview:RequestIndicator(unit, indicator)
end

function UF:PLAYER_REGEN_DISABLED()
    for _, state in pairs(groups) do
        Restore(state) -- `wanted` survives, so the resume below puts it back.
    end
    for key, state in pairs(groupStates) do
        RestoreGroup(key, state)
    end

    NRSKNUI:RunWhenSafe(function()
        for _, state in pairs(groups) do
            if state.wanted then
                Apply(state)
            end
        end
        for key, state in pairs(groupStates) do
            if state.wanted then
                ApplyGroup(key, state)
            end
        end
    end)
end

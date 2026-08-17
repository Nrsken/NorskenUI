---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
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
    frame.__unit = entry.unit
    frame:EnableMouse(false)
    UnregisterUnitWatch(frame)
    RegisterUnitWatch(frame, true)
    frame:Show()
    UF:ConfigureFrame(frame, frame.nrsknUnit)

    ShowLabel(frame, entry.label)
end

---@param entry table
local function RestoreFrame(entry)
    local frame = entry.frame
    if not frame.nuiPreviewUnit then return end

    frame.nuiPreviewUnit = nil
    frame.__unit = frame.nrsknUnit
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
---@param header oUF.Header
---@return number
local function ForcedStart(header)
    local perColumn = header:GetAttribute('unitsPerColumn') or UF.GROUP_SIZE
    local columns = header:GetAttribute('maxColumns') or 1
    return -(perColumn * columns - 1)
end

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
    -- ForceHeader is an OnAttributeChanged hook, so only a newly forced child pays the reconfigure.
    if not frame.nuiPreviewUnit then
        frame.nuiPreviewUnit = 'player'
        frame.__unit = 'player'
        frame:EnableMouse(false)

        UnregisterUnitWatch(frame)
        RegisterUnitWatch(frame, true)

        frame:Show()
        UF:ConfigureFrame(frame, frame.nuiConfig)
    else
        frame:Show()
    end

    frame.nuiPreviewIndex = index
    ShowLabel(frame, label)
end

---@param frame oUF.UnitFrame
local function RestoreChild(frame)
    if not frame.nuiPreviewUnit then return end

    frame.nuiPreviewUnit = nil
    -- The forced children past the real roster carry no unit, so fall back rather than nil it out.
    frame.__unit = frame:GetAttribute('unit') or frame.nrsknUnit
    frame:EnableMouse(true)

    HideLabel(frame)
    UnregisterUnitWatch(frame)
    RegisterUnitWatch(frame)
    UF:ConfigureFrame(frame, frame.nuiConfig)
end

---@param header oUF.Header
---@param fn fun(child: oUF.UnitFrame, index: number)
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
---@param header oUF.Header
local function ForceHeader(header)
    if not header.nuiForced or not header:IsShown() then return end

    local start = ForcedStart(header)

    -- Comparing first is what stops the SetAttribute below from recursing forever.
    if header:GetAttribute('startingIndex') ~= start then
        header:SetAttribute('startingIndex', start)
    end

    -- Numbering restarts per header so dummies read as subgroup members.
    ForEachChild(header, function(child, index)
        local label = header.nuiGroup
            and format('%s %d-%d', header.nuiLabel, header.nuiGroup, index)
            or format('%s %d', header.nuiLabel, index)

        ForceChild(child, index, label)
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

    UF:PrimeGroupChildren(key)

    for _, header in ipairs(group.headers) do
        if not header.nuiHooked then
            header.nuiHooked = true
            header:HookScript('OnAttributeChanged', ForceHeader)
        end

        for attr in pairs(header.nuiShown) do
            header:SetAttribute(attr, nil)
        end

        header.nuiForced = true
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

---Stop honouring the forced state while a caller rewrites header attributes.
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

local auraUnits = {}

---Repaint the aura element on every frame a config renders, so 'boss' covers all eight of them.
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

-- config key -> the placement tab the GUI has open on its aura indicator section, nil while closed.
-- Everything but the tint styles previews whenever the section is open, so this only picks the tint.
local indicatorTabs = {}

---@param key string config key
local function RefreshIndicatorPreviews(key)
    local element = UF.Elements.AuraIndicators

    UF:ForEachFrame(function(frame, unit)
        local uDB = UF.GetUnitDB(unit)

        -- Configure settles every handle, so a placement that stops previewing gets its real slots
        -- back and the preview below only has to take over the ones it wants.
        element.Configure(frame, unit, uDB)
        element.Preview(frame, unit, uDB)
    end, key)
end

---Preview a unit's aura indicators, with `index` the placement tab the GUI has open.
---@param unit string
---@param index number? nil to stop previewing
function Preview:RequestAuraIndicator(unit, index)
    local key = UF.ConfigKey(unit)
    if indicatorTabs[key] == index then return end

    indicatorTabs[key] = index
    RefreshIndicatorPreviews(key)
end

function Preview:ReleaseAllAuraIndicators()
    for key in pairs(indicatorTabs) do
        indicatorTabs[key] = nil
        RefreshIndicatorPreviews(key)
    end
end

---The placement tab the GUI has open, nil while the unit's aura indicator section is closed.
---@param unit string config key or unit token
---@return number? index
function Preview:GetAuraIndicatorTab(unit)
    return indicatorTabs[UF.ConfigKey(unit)]
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

local previewTier
local anchorsShown = false

---Whether a group ignores the live roster and lays out at full size.
---@param key string config key
---@return boolean
function UF:IsGroupSizedFull(key)
    return previewTier == key or anchorsShown
end

---@param shown boolean
local function SetAnchorLayout(shown)
    if anchorsShown == shown then return end
    anchorsShown = shown

    NRSKNUI:RunWhenSafe(function()
        for key in pairs(UF.GroupConfigs) do
            if UF.GroupCounts[key] > 1 then UF:LayoutGroup(key) end
        end
    end)
end

---Show a preview for a page. The page is responsible for calling Release when it closes or switches away.
---Raid tiers sit out the everything view and only preview from their own page.
---@param pageId string? the page asking, e.g. 'unitFrames_target'
---@param showAll boolean? whether everything is being previewed
function UF:ShowPreview(pageId, showAll)
    SetAnchorLayout(NRSKNUI.Anchors.isActive == true)

    if showAll then
        Preview:Request('boss')
        for key in pairs(UF.GroupConfigs) do
            if UF.GroupCounts[key] == 1 then Preview:RequestGroup(key) end
        end
    end

    local unit = pageId and pageId:match('^unitFrames_(.+)$')
    if not unit then return end

    if unit == 'boss' then Preview:Request('boss') end

    if UF.GroupConfigs[unit] then
        if UF.GroupCounts[unit] > 1 then
            previewTier = unit
            UF:LayoutGroup(unit)
        end
        Preview:RequestGroup(unit)
    end
end

---Called by PreviewManager when the page changes or the window closes.
function UF:HidePreview()
    SetAnchorLayout(NRSKNUI.Anchors.isActive == true)

    Preview:ReleaseAllAuras()
    Preview:ReleaseAllAuraIndicators()
    Preview:ReleaseAllIndicators()
    Preview:ReleaseAll()
    Preview:ReleaseAllGroups()

    -- Back to the live roster's count, so it relayouts rather than just hiding.
    if previewTier then
        local previous = previewTier
        previewTier = nil
        NRSKNUI:RunWhenSafe(function()
            UF:LayoutGroup(previous)
        end)
    end
end

---Show a unit's dummy auras, driven by the aura section the GUI has open.
---@param unit string
---@param shown boolean
function UF:PreviewAuras(unit, shown)
    if shown then
        Preview:RequestAuras(unit)
    else
        Preview:ReleaseAuras(unit)
    end
end

---Preview a unit's aura indicators, driven by the aura indicator section the GUI has open.
---@param unit string
---@param index number? the open placement tab, nil to stop previewing
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

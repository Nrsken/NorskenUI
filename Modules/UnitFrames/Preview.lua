---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
---@field Preview UnitFramesPreview
local UF = NRSKNUI:GetModule('UnitFrames')
local Theme = NRSKNUI.Theme

local CreateFrame = CreateFrame
local RegisterUnitWatch = RegisterUnitWatch
local UnregisterUnitWatch = UnregisterUnitWatch
local ipairs = ipairs
local pairs = pairs

local LABEL_SIZE = 13
local LABEL_LEVEL = 1100 -- Above the indicator container, which sits at 1000.

---@class UnitFramesPreview
local Preview = {}
UF.Preview = Preview

local groups = {}

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
        label:SetPoint('CENTER')
        label:SetFontStyle(nil, LABEL_SIZE, 'OUTLINE')
        frame.nuiPreviewLabel = label
    end

    label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
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

---Called by PreviewManager when the GUI or the anchor session closes. Intent goes with it, so a
---later combat drop cannot bring the frames back behind a closed window.
function UF:HidePreview()
    Preview:ReleaseAll()
end

function UF:PLAYER_REGEN_DISABLED()
    for _, state in pairs(groups) do
        Restore(state) -- `wanted` survives, so the resume below puts it back.
    end

    NRSKNUI:RunWhenSafe(function()
        for _, state in pairs(groups) do
            if state.wanted then
                Apply(state)
            end
        end
    end)
end

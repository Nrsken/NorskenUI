---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

--[[
The Information tab's debug report, sent to BugSack so a user can copy it and send it for support.
]]

local GetSpecializationInfo = GetSpecializationInfo
local GetSpecialization = GetSpecialization
local GetInstanceInfo = GetInstanceInfo
local geterrorhandler = geterrorhandler
local GetBuildInfo = GetBuildInfo
local tconcat = table.concat
local format = string.format
local tostring = tostring
local select = select
local unpack = unpack
local ipairs = ipairs
local min = math.min
local type = type
local date = date

local GetCVar = C_CVar and C_CVar.GetCVar

local Category = Enum and Enum.CooldownViewerCategory

local PREVIEW_NAMES = {
    [0] = 'off',
    [1] = 'selected',
    [2] = 'pinned',
}

-- Rows --

---@param value any
---@return string
local function YesNo(value)
    return value and 'yes' or 'no'
end

---Each sub element's level, in list order, to check the draw order (an overlay's elements inside its button).
---@param subRegions table[]
---@param borders table
---@param glows table
---@param texts table
---@return string
local function ElementLevels(subRegions, borders, glows, texts)
    local out, counts = {}, { border = 0, glow = 0, text = 0 }
    for _, element in ipairs(subRegions) do
        local kind = element.type
        if counts[kind] then
            local n = counts[kind] + 1
            counts[kind] = n

            local level
            if kind == 'border' then
                level = borders[n] and borders[n]:GetFrameLevel()
            elseif kind == 'glow' then
                level = glows[n] and glows[n].host:GetFrameLevel()
            else
                level = texts[n] and texts[n].host and texts[n].host:GetFrameLevel()
            end
            out[#out + 1] = format('%s %d = %s', kind, n, level and tostring(level) or '-')
        end
    end

    return out[1] and tconcat(out, ', ') or 'none'
end

---An aura trigger's layer: what it was styled with and where its elements sit, to tell a missing pandemic border on our side from the game's.
---@param lines string[]
---@param frame CDMIcon
---@param display table
---@param i number
local function AuraLayerLines(lines, frame, display, i)
    local trigger = display.Triggers[i]
    local layer = frame.layers[i]
    local refs = layer and layer.auraRefs
    local _, color = CDM:GetAuraConditionChanges(display, i)
    local accessible = refs and refs.button and not NRSKNUI:AreAurasSecret()

    lines[#lines + 1] = format('  Aura: index %s, key %s, button %s', tostring(layer and layer.index), tostring(layer and layer.auraKey), YesNo(refs and refs.button))
    lines[#lines + 1] = format('  Pandemic: colour %s, border alpha %s', YesNo(color), accessible and refs.pandemic and format('%.2f', refs.pandemic:GetAlpha()) or '-')
    lines[#lines + 1] = format('  Levels: layer %s, aura host %s, button %s, slot %s',
        tostring(layer and layer:GetFrameLevel()), tostring(layer and layer.auraHost and layer.auraHost:GetFrameLevel()),
        accessible and tostring(refs.button:GetFrameLevel()) or '-', tostring(trigger.Slot))

    if accessible then
        lines[#lines + 1] = '  Button elements: ' .. ElementLevels(display.SubRegions or {}, refs.borders, refs.glows or {}, refs.textHosts)
    end

    for j, other in ipairs(frame.layers) do
        if j ~= i and display.Triggers[j] and display.Triggers[j].Type ~= 'auraoverlay' then
            lines[#lines + 1] = format('  Under trigger %d (level %d): %s', j, other:GetFrameLevel(),
                ElementLevels(display.SubRegions or {}, other.borders, other.glows, other.texts))
        end
    end
end

---@param id string
---@return Frame?
local function RuntimeFrame(id)
    return CDM.containers[id] or CDM.icons[id] or CDM:GetAuraHost(id)
end

---What a trigger reads: its item, power type or spell.
---@param trigger table
---@return string
local function TriggerSource(trigger)
    if trigger.Type == 'item' then
        if trigger.Item == 'custom' then
            return 'item ' .. tostring(trigger.ItemID)
        end
        return tostring(trigger.Item)
    end

    if trigger.Type == 'power' then
        return tostring(trigger.PowerType or 'primary')
    end

    local spellID = CDM:GetTriggerSpell(trigger)
    return spellID and ('spell ' .. spellID) or '-'
end

-- Summary --

---Why a single display is or isn't on screen, from its load state and runtime frame.
---@param id string
---@return string
local function Verdict(id)
    local state, reason = CDM:GetLoadState(id)
    if state ~= 'loaded' then
        return state .. ': ' .. tostring(reason)
    end

    local frame = RuntimeFrame(id)
    if not frame then
        return 'loaded, but not built'
    end

    local icon = CDM.icons[id]
    if icon and icon.forceHidden then
        return 'loaded, hidden by a Show Display condition'
    end
    if icon and not icon.hasActive then
        return 'loaded, no trigger active'
    end
    return frame:IsShown() and 'shown' or 'loaded and active, but its frame is hidden'
end

---@param id string
---@return string[]
local function ReportedDisplays(id)
    if CDM:IsGroup(id) then
        return CDM:GetLeaves(id)
    end

    return { id }
end

---This session's NorskenUI errors from BugGrabber's list, newest first; our own reports left out.
---@param lines string[]
local function ErrorLines(lines)
    local db, session = BugGrabber:GetDB(), BugGrabber:GetSessionId()
    local found = {}
    for n = #db, 1, -1 do
        local entry = db[n]
        local message = type(entry) == 'table' and entry.session == session and entry.message
        if type(message) == 'string' and message:find('NorskenUI', 1, true)
            and not message:find('NorskenUI CDM debug report', 1, true) then
            found[#found + 1] = entry
        end
    end

    lines[#lines + 1] = format('NorskenUI errors this session (%d)', #found)
    if not found[1] then
        lines[#lines + 1] = '  none'
    end

    for n = 1, min(3, #found) do
        local entry = found[n]
        local first = entry.message:match('^[^\n]*'):sub(1, 200)
        lines[#lines + 1] = format('  %dx %s', entry.counter or 1, first)
    end
end

-- Report --

---One display's report as sections: a heading line, then its indented rows. Answers first, details after.
---@param id string
---@return string[]
local function DebugLines(id)
    local display = CDM:Get(id)
    local lines = {}
    if not display then
        return lines
    end

    local _, build = GetBuildInfo()
    local specIndex = GetSpecialization()
    local specName = specIndex and select(2, GetSpecializationInfo(specIndex))
    local _, instanceType, _, difficultyName = GetInstanceInfo()
    lines[#lines + 1] = 'NorskenUI CDM debug report'
    lines[#lines + 1] = '  Time: ' .. date('%Y-%m-%d %H:%M:%S')
    lines[#lines + 1] = format('  Version: %s, build %s', tostring(NRSKNUI.Version), tostring(build))
    lines[#lines + 1] = format('  Player: %s, %s', tostring(NRSKNUI.MyClassLocale), tostring(specName or 'no spec'))
    lines[#lines + 1] = format('  Instance: %s%s', tostring(instanceType), difficultyName and difficultyName ~= '' and (', ' .. difficultyName) or '')
    lines[#lines + 1] = format('  Combat: %s, restriction %d, auras secret %s, cooldowns secret %s', YesNo(NRSKNUI:InCombat()),
        NRSKNUI:GetRestrictionState(), YesNo(NRSKNUI:AreAurasSecret()), YesNo(NRSKNUI:AreCooldownsSecret()))
    lines[#lines + 1] = format('  Module: enabled %s, options open %s (previews show displays regardless)', YesNo(CDM.db.Enabled), YesNo(CDM.previewing))
    lines[#lines + 1] = format('  Cooldown Manager: essential %d, utility %d, buffs %d, bars %d, viewer CVar %s',
        #CDM.Catalogue:GetList(Category.Essential), #CDM.Catalogue:GetList(Category.Utility), #CDM.Catalogue:GetList(Category.TrackedBuff),
        #CDM.Catalogue:GetList(Category.TrackedBar), tostring(GetCVar('cooldownViewerEnabled')))

    local isGroup = CDM:IsGroup(id)
    local reported = ReportedDisplays(id)
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Verdict'
    if not reported[1] then
        lines[#lines + 1] = '  the group is empty'
    end
    for _, key in ipairs(reported) do
        lines[#lines + 1] = isGroup and format('  %s (%s): %s', CDM:GetName(key), key, Verdict(key)) or ('  ' .. Verdict(key))
    end

    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Warnings'
    local warned = false
    for _, key in ipairs(isGroup and { id, unpack(reported) } or reported) do
        for _, warning in ipairs(CDM:GetWarnings(key)) do
            warned = true
            lines[#lines + 1] = (isGroup and key ~= id) and format('  %s: %s', CDM:GetName(key), warning) or ('  ' .. warning)
        end
    end
    if not warned then
        lines[#lines + 1] = '  none'
    end

    if BugGrabber then
        lines[#lines + 1] = ''
        ErrorLines(lines)
    end

    local state, reason = CDM:GetLoadState(id)
    lines[#lines + 1] = ''
    lines[#lines + 1] = format('Display: %s (%s)', CDM:GetName(id), id)
    lines[#lines + 1] = '  Type: ' .. display.type
    lines[#lines + 1] = '  Enabled: ' .. YesNo(display.Enabled)
    lines[#lines + 1] = '  Load: ' .. state .. (reason and (', ' .. reason) or '')
    lines[#lines + 1] = '  Preview: ' .. (PREVIEW_NAMES[CDM:GetPreview(id)] or '?')

    local container, icon = CDM.containers[id], CDM.icons[id]
    local frame = RuntimeFrame(id)
    if not frame then
        lines[#lines + 1] = '  Frame: not built'
        return lines
    end

    lines[#lines + 1] = format('  Frame: %s, strata %s, level %s', frame:IsShown() and 'shown' or 'hidden', frame:GetFrameStrata(), tostring(frame:GetFrameLevel()))

    if container then
        lines[#lines + 1] = '  Container: ' .. (container.isChain and 'chain' or (container.IterateActive and 'dynamic' or 'static'))
        local children = CDM:GetChildren(id)
        lines[#lines + 1] = ''
        lines[#lines + 1] = format('Children (%d)', #children)
        if not children[1] then
            lines[#lines + 1] = '  none'
        end
        for _, child in ipairs(children) do
            local childFrame = RuntimeFrame(child.key)
            lines[#lines + 1] = format('  %s (%s, %s): frame %s', child.text, child.key, CDM:Get(child.key).type,
                childFrame and (childFrame:IsShown() and 'shown' or 'hidden') or 'not built')
        end
    elseif icon then
        lines[#lines + 1] = format('  State: loaded %s, has active %s, force hidden %s', YesNo(icon.shown), YesNo(icon.hasActive), YesNo(icon.forceHidden))
        for i, trigger in ipairs(display.Triggers or {}) do
            local layer = icon.layers[i]
            local triggerType = CDM.TriggerTypes[trigger.Type]
            local triggerState
            if not triggerType then
                triggerState = 'unknown type'
            elseif triggerType.Secret then
                triggerState = 'secret'
            else
                triggerState = (layer ~= nil and triggerType.IsActive(layer, trigger)) and 'active' or 'inactive'
            end

            lines[#lines + 1] = ''
            lines[#lines + 1] = format('Trigger %d: %s', i, CDM:GetTriggerName(trigger) or trigger.Type)
            lines[#lines + 1] = format('  Type: %s (%s)', trigger.Type, TriggerSource(trigger))
            lines[#lines + 1] = '  Known: ' .. YesNo(triggerType and triggerType.IsKnown(trigger))
            lines[#lines + 1] = '  State: ' .. triggerState
            lines[#lines + 1] = format('  Layer: %s%s', layer ~= nil and layer:IsShown() and 'shown' or 'hidden',
                layer ~= nil and layer == icon.activeLayer and ', active layer' or '')
            if trigger.Type == 'aura' or trigger.Type == 'auraoverlay' then
                AuraLayerLines(lines, icon, display, i)
            end
            if layer and triggerType and triggerType.DebugLines then
                triggerType.DebugLines(lines, layer)
            end
        end
    end

    return lines
end

---@param lines string[]
local function PrintLines(lines)
    local accent = NRSKNUI.Theme.accent
    for n, line in ipairs(lines) do
        if n == 1 then
            NRSKNUI:Print(line)
        elseif line:find('^%S') then
            print(NRSKNUI:ColorText(line, accent))
        elseif line ~= '' then
            print(line)
        end
    end
end

---One display's live state for the Information tab: into BugSack when it's installed, so it can be copied and sent, otherwise to chat.
---@param id string
function CDM:PrintDebug(id)
    local lines = DebugLines(id)
    if not lines[1] then return end

    if BugGrabber then
        lines[#lines + 1] = ''
        lines[#lines + 1] = 'Settings string'
        local exported = self:Export(id)
        if not exported then
            lines[#lines + 1] = '  export failed'
        end
        for i = 1, exported and #exported or 0, 100 do -- BugSack's tooltip never wraps a line; import strips the breaks again
            lines[#lines + 1] = exported:sub(i, i + 99)
        end

        geterrorhandler()(tconcat(lines, '\n'), true) -- BugGrabber's simple entry: the message alone, no stack or locals
        NRSKNUI:Print(format(L['Debug report for %s saved to BugSack.'], self:GetName(id)))
    else
        lines[#lines + 1] = ''
        lines[#lines + 1] = 'Settings string'
        lines[#lines + 1] = '  too long for chat; right-click the display and pick Export'
        PrintLines(lines)
    end
end

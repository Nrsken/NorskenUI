---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

local GetPhysicalScreenSize = GetPhysicalScreenSize
local pairs, ipairs = pairs, ipairs
local CreateFrame = CreateFrame
local format = string.format
local tostring = tostring
local type = type
local wipe = wipe

local GetSpellCooldown = C_Spell.GetSpellCooldown
local GetSpellCharges = C_Spell.GetSpellCharges
local IsSpellUsable = C_Spell.IsSpellUsable
local GetTime = GetTime
local GetSpellName = C_Spell and C_Spell.GetSpellName

-- Dev commands --

---Seed one dynamic group per Blizzard cooldown category from the known spells it lists.
local function Seed()
    local Category = Enum.CooldownViewerCategory
    local yOffset = -180
    for _, category in ipairs({ Category.Essential, Category.Utility }) do
        local groupId = CDM:CreateGroup(category == Category.Essential and 'Essential' or 'Utility', true)
        CDM:Get(groupId).Position.YOffset = yOffset
        yOffset = yOffset - 50

        for _, cooldownID in ipairs(CDM.Catalogue:GetList(category)) do
            local info = CDM.Catalogue:GetEntry(cooldownID)
            if info and info.isKnown and info.spellID then
                CDM:CreateIcon(GetSpellName(info.spellID) or tostring(info.spellID),
                    { Type = 'spell', SpellID = info.spellID, CooldownID = cooldownID }, groupId)
            end
        end
    end
end

---@param value any
---@return string
local function ProbeText(value)
    if NRSKNUI:IsSecretValue(value) then return '?' end
    if type(value) == 'number' then return (format('%.3f', value):gsub('%.?0+$', '')) end
    return tostring(value)
end

local probeFrame

---Print what the cooldown API reports for one spell on every SPELL_UPDATE_COOLDOWN; again turns it off.
---@param spellID number?
local function ProbeCooldown(spellID)
    probeFrame = probeFrame or CreateFrame('Frame')
    if probeFrame.spellID or not spellID then
        probeFrame:UnregisterAllEvents()
        probeFrame.spellID = nil
        NRSKNUI:Print('Cooldown probe off')
        return
    end
    probeFrame.spellID = spellID
    probeFrame:SetScript('OnEvent', function(self, _, eventSpell, baseSpell, _, category)
        local cooldown = GetSpellCooldown(self.spellID)
        local charges = GetSpellCharges(self.spellID)
        local usable, noPower = IsSpellUsable(self.spellID)
        print(format('%s ev=%s/%s cat=%s | active=%s gcd=%s enabled=%s activeCat=%s dur=%s rec=%s | charges=%s usable=%s/%s',
            ProbeText(GetTime()), ProbeText(eventSpell), ProbeText(baseSpell), ProbeText(category),
            ProbeText(cooldown and cooldown.isActive), ProbeText(cooldown and cooldown.isOnGCD), ProbeText(cooldown and cooldown.isEnabled),
            ProbeText(cooldown and cooldown.activeCategory), ProbeText(cooldown and cooldown.duration),
            ProbeText(cooldown and cooldown.timeUntilEndOfStartRecovery),
            charges and ProbeText(charges.currentCharges) .. '/' .. ProbeText(charges.maxCharges) or '-', ProbeText(usable), ProbeText(noPower)))
    end)
    probeFrame:RegisterEvent('SPELL_UPDATE_COOLDOWN')
    NRSKNUI:Print(format('Cooldown probe on %s (%d)', GetSpellName(spellID) or '?', spellID))
end

local PREVIEW_NAMES = { [0] = 'off', [1] = 'selected', [2] = 'pinned' }

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
    return out[1] and table.concat(out, ', ') or 'none'
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
    lines[#lines + 1] = format('  Pandemic: colour %s, border alpha %s', YesNo(color), refs and refs.pandemic and format('%.2f', refs.pandemic:GetAlpha()) or '-')
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

---@param trigger table
---@return string
local function TriggerSource(trigger)
    if trigger.Type == 'item' then
        if trigger.Item == 'custom' then return 'item ' .. tostring(trigger.ItemID) end
        return tostring(trigger.Item)
    end
    if trigger.Type == 'power' then return tostring(trigger.PowerType or 'primary') end
    local spellID = CDM:GetTriggerSpell(trigger)
    return spellID and ('spell ' .. spellID) or '-'
end

---Why a single display is or isn't on screen, from its load state and runtime frame.
---@param id string
---@return string
local function Verdict(id)
    local state, reason = CDM:GetLoadState(id)
    if state ~= 'loaded' then return state .. ': ' .. tostring(reason) end
    local frame = RuntimeFrame(id)
    if not frame then return 'loaded, but not built' end
    local icon = CDM.icons[id]
    if icon and icon.forceHidden then return 'loaded, hidden by a Show Display condition' end
    if icon and not icon.hasActive then return 'loaded, no trigger active' end
    return frame:IsShown() and 'shown' or 'loaded and active, but its frame is hidden'
end

---@param id string
---@return string[]
local function ReportedDisplays(id)
    if CDM:IsGroup(id) then return CDM:GetLeaves(id) end
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
    if not found[1] then lines[#lines + 1] = '  none' end
    for n = 1, math.min(3, #found) do
        local entry = found[n]
        local first = entry.message:match('^[^\n]*'):sub(1, 200)
        lines[#lines + 1] = format('  %dx %s', entry.counter or 1, first)
    end
end

---One display's report as sections: a heading line, then its indented rows. Answers first, details after.
---@param id string
---@return string[]
local function DebugLines(id)
    local display = CDM:Get(id)
    local lines = {}
    if not display then return lines end

    local _, build = GetBuildInfo()
    local specIndex = GetSpecialization()
    local specName = specIndex and select(2, GetSpecializationInfo(specIndex))
    local _, instanceType, _, difficultyName = GetInstanceInfo()
    local Category = Enum.CooldownViewerCategory
    lines[#lines + 1] = 'NorskenUI CDM debug report'
    lines[#lines + 1] = '  Time: ' .. date('%Y-%m-%d %H:%M:%S')
    lines[#lines + 1] = format('  Version: %s, build %s', tostring(NRSKNUI.Version), tostring(build))
    lines[#lines + 1] = format('  Player: %s, %s', tostring(NRSKNUI.MyClassLocale), tostring(specName or 'no spec'))
    lines[#lines + 1] = format('  Instance: %s%s', tostring(instanceType), difficultyName and difficultyName ~= '' and (', ' .. difficultyName) or '')
    lines[#lines + 1] = format('  Combat: %s, restriction %d, auras secret %s, cooldowns secret %s', YesNo(NRSKNUI:InCombat()),
        NRSKNUI:GetRestrictionState(), YesNo(NRSKNUI:AreAurasSecret()), YesNo(NRSKNUI:AreCooldownsSecret()))
    lines[#lines + 1] = format('  Module: enabled %s, options open %s (previews show displays regardless)', YesNo(CDM.db.Enabled), YesNo(CDM.previewing))
    lines[#lines + 1] = format('  Cooldown Manager: essential %d, utility %d, buffs %d, bars %d, viewer CVar %s, hide Blizzard %s',
        #CDM.Catalogue:GetList(Category.Essential), #CDM.Catalogue:GetList(Category.Utility), #CDM.Catalogue:GetList(Category.TrackedBuff),
        #CDM.Catalogue:GetList(Category.TrackedBar), tostring(GetCVar('cooldownViewerEnabled')), YesNo(CDM.db.HideBlizzard))

    local isGroup = CDM:IsGroup(id)
    local reported = ReportedDisplays(id)
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Verdict'
    if not reported[1] then lines[#lines + 1] = '  the group is empty' end
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
    if not warned then lines[#lines + 1] = '  none' end

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
        if not children[1] then lines[#lines + 1] = '  none' end
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
            if trigger.Type == 'aura' or trigger.Type == 'auraoverlay' then AuraLayerLines(lines, icon, display, i) end
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
        if not exported then lines[#lines + 1] = '  export failed' end
        for i = 1, exported and #exported or 0, 100 do -- BugSack's tooltip never wraps a line; import strips the breaks again
            lines[#lines + 1] = exported:sub(i, i + 99)
        end
        geterrorhandler()(table.concat(lines, '\n'), true) -- BugGrabber's simple entry: the message alone, no stack or locals
        NRSKNUI:Print(format(L['Debug report for %s saved to BugSack.'], self:GetName(id)))
    else
        lines[#lines + 1] = ''
        lines[#lines + 1] = 'Settings string'
        lines[#lines + 1] = '  too long for chat; right-click the display and pick Export'
        PrintLines(lines)
    end
end

---@param args string
function CDM:HandleCommand(args)
    local probeSpell = args:match('^cd%s*(%d*)$')
    if probeSpell then return ProbeCooldown(tonumber(probeSpell)) end

    if args == 'dump' then
        self.Catalogue:Dump()
    elseif args == 'seed' then
        Seed()
        self.db.Enabled = true
        NRSKNUI:ToggleModule('CDM', true)
        self:ApplySettings()
    elseif args == 'px' then
        -- Physical-pixel edges of the shown icons in each dynamic group, to see where a gap renders wider.
        local _, physicalHeight = GetPhysicalScreenSize()
        local scale = UIParent:GetEffectiveScale()
        local toPixels = scale * physicalHeight / 768
        NRSKNUI:Print(format('UIParent scale %.4f, perfect %.4f, 1 unit = %.4f px', scale, 768 / physicalHeight, toPixels))
        for id, container in pairs(self.containers) do
            if container.IterateActive and container:IsShown() then
                local line, previousRight = self:GetName(id) .. (container.isChain and ' (chain):' or ':'), nil
                for _, child in container:IterateActive() do
                    local left, right = child:GetLeft(), child:GetRight()
                    if not child:IsShown() then
                        -- a chain lists its unloaded icons too
                    elseif left == nil or NRSKNUI:IsSecretValue(left) or NRSKNUI:IsSecretValue(right) then
                        line, previousRight = line .. ' [?]', nil
                    else
                        left, right = left * toPixels, right * toPixels
                        if previousRight then line = line .. format(' gap %.2f |', left - previousRight) end
                        line = line .. format(' [%.2f-%.2f]', left, right)
                        previousRight = right
                    end
                end
                print(line)
            end
        end
    elseif args == 'aura' then
        local lines = { 'Aura layers' }
        for id, frame in pairs(self.icons) do
            local display = self:Get(id)
            for i, trigger in ipairs(display and display.Triggers or {}) do
                if trigger.Type == 'aura' or trigger.Type == 'auraoverlay' then
                    lines[#lines + 1] = format('%s: trigger %d (%s)', self:GetName(id), i, trigger.Type)
                    AuraLayerLines(lines, frame, display, i)
                end
            end
        end
        PrintLines(lines)
    elseif args == 'chain' then
        -- Where each chain group's frames really are, ? where the engine made a value secret.
        local function Num(value)
            if value == nil or NRSKNUI:IsSecretValue(value) then return '?' end
            return format('%.1f', value)
        end
        for id, container in pairs(self.containers) do
            if container.isChain and container:IsShown() then
                ---@cast container CDMChainGroup
                local chain = container.chain
                print(format('%s: group L %s W %s | chain L %s W %s', self:GetName(id), Num(container:GetLeft()), Num(container:GetWidth()),
                    Num(chain:GetLeft()), Num(chain:GetWidth())))
                for _, record in ipairs(container.order) do
                    print(format('  %s shown=%s loaded=%s logic=%s L %s W %s', self:GetName(record.key), tostring(record.slot:IsShown()),
                        tostring(record.loaded), tostring(record.logic), Num(record.slot:GetLeft()), Num(record.slot:GetWidth())))
                end
            end
        end
    elseif args == 'wipe' then
        for id in pairs(self.db.Displays) do self:Release(id) end
        wipe(self.db.Displays)
    else
        NRSKNUI:Print("/nui cdm dump | seed | wipe | px | aura | chain | cd <spellID>")
    end
end

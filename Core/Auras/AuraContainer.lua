---@class NRSKNUI
local NRSKNUI = select(2, ...)

local UnitCanAssist, UnitIsVisible = UnitCanAssist, UnitIsVisible
local UnitIsPlayerControlledOrGroupMember = UnitIsPlayerControlledOrGroupMember
local C_Timer, GetTime = C_Timer, GetTime
local min, huge, ceil = math.min, math.huge, math.ceil
local GenerateClosure = GenerateClosure
local CreateFrame = CreateFrame
local CopyTable = CopyTable
local ipairs, pairs = ipairs, pairs
local Mixin = Mixin
local type = type

local AuraFilterTokens = AuraUtil.AuraFilters

-- An empty include map matches nothing, and unlike a filter string it survives an untrusted unit.
local NEVER_MATCH_CANDIDATES = { includeDispelTypes = {} }

-- Element-wide defaults copied onto the container. Group/slot options override them per group.
local ELEMENT_OPTIONS = {
    'size', 'width', 'height',
    'maxFrameCount', 'sortMethod', 'sortDirection',
    'elementSpacing', 'lineSpacing', 'groupSpacing', 'groupLineSpacing',
    'forceNewLine', 'elementWidth', 'elementHeight',
    'disableCooldown', 'drawSwipe', 'drawEdge', 'reverseSwipe',
    'showApplicationCount', 'applicationCountFormatter',
    'showDurationText', 'durationTextFormatter', 'durationTextColorCurve',
    'showBuffBorder', 'showDebuffBorder', 'showWithoutDispelType', 'borderStyle',
    'customDispelColorMap', 'customDispelColorCurve',
    'showBuffDispelIcon', 'showDebuffDispelIcon', 'dispelIconSize',
    'disableMouse', 'cancelAuraButtons', 'borderColor',
    'tooltipAnchorPoint', 'tooltipOffsetX', 'tooltipOffsetY', 'tooltipHideInCombat',
    'hidePermanent',
    'fontDB', 'stackFont', 'durationFont',
}

-- Subset of ELEMENT_OPTIONS that belongs in a flow layout table.
local LAYOUT_OPTIONS = {
    'elementSpacing', 'lineSpacing', 'groupSpacing', 'groupLineSpacing',
    'forceNewLine', 'elementWidth', 'elementHeight',
}

---Resolve a button option: per-group options win, then the element-wide default, then the fallback.
---@param options table
---@param container table
---@param key string
---@param fallback any?
---@return any
local function Opt(options, container, key, fallback)
    local value = options[key]
    if value == nil then value = container[key] end
    if value == nil then return fallback end
    return value
end

---Resolve a growth direction to the AnchorUtil.FlowDirection value the flow layout expects.
---Accepts a FlowDirection value directly or one of 'LEFT'/'RIGHT'/'UP'/'DOWN'.
---@param direction string|number|nil
---@param default number
---@return number
local function ResolveGrowthDirection(direction, default)
    if type(direction) == 'number' then return direction end

    local flow = AnchorUtil.FlowDirection
    if direction == 'LEFT' then
        return flow.Left
    elseif direction == 'RIGHT' then
        return flow.Right
    elseif direction == 'UP' then
        return flow.Up
    elseif direction == 'DOWN' then
        return flow.Down
    end

    return default
end

---Extent of the largest grid a config can lay out.
---@param config table .size, .perRow, .elementSpacing and .lineSpacing
---@param count number most buttons that can be placed
---@return number width
---@return number height
function NRSKNUI:GetAuraGridSize(config, count)
    local columns = min(config.perRow, count)
    local rows = ceil(count / config.perRow)

    return columns * config.size + (columns - 1) * config.elementSpacing, rows * config.size + (rows - 1) * config.lineSpacing
end

-- Check what type of duration text coloring is enabled in the global media settings.
local function GetGlobalDurationColorMode()
    local media = NRSKNUI.db.profile.globalMedia
    local useBreakpointColors = media and media.durationBreakpointColors
    local useCurveColors = media and media.durationCurveColors
    local useSingleColor = media and media.durationSingleColor
    local singleColor = media and media.durationSingleColorValue

    -- Mode precedence, single color > breakpoint colors > curve colors.
    if useSingleColor then
        useBreakpointColors = false
        useCurveColors = false
    elseif useBreakpointColors then
        useCurveColors = false
    end

    -- If no mode is selected, keep curve mode on.
    if not useSingleColor and not useBreakpointColors and not useCurveColors then
        useCurveColors = true
    end

    return useBreakpointColors, useCurveColors, useSingleColor, singleColor
end

---Shared aura button constructor.
---@param container table AuraContainer element
---@param options table group/slot options (carries size/font/toggle overrides)
---@param button table native AuraButton
function NRSKNUI:SkinAuraButton(container, options, button)
    options = options or {}

    -- Size the button and add a backdrop for border. The backdrop takes no settings and is anchored to
    -- the button, so a re-skinned preview dummy keeps the one it already has.
    local size = Opt(options, container, 'size', 24)
    button:SetSize(Opt(options, container, 'width', size), Opt(options, container, 'height', size))
    button:EnableMouse(not Opt(options, container, 'disableMouse'))
    if not button.backdropBackground then -- the field CreateBackdrop sets, injected methods do not reach an AuraButton
        NRSKNUI:CreateBackdrop(button, nil, 0)
    end

    -- Tooltip anchor and combat hiding. The native button handles the tooltip itself, we just tell it where to go.
    button:SetTooltipAnchorPoint(
        Opt(options, container, 'tooltipAnchorPoint', 'ANCHOR_BOTTOMLEFT'),
        Opt(options, container, 'tooltipOffsetX', 0),
        Opt(options, container, 'tooltipOffsetY', 0)
    )
    button:SetHideTooltipInCombat(Opt(options, container, 'tooltipHideInCombat') == true)

    -- Icon, trimmed and inset inside the 1px backdrop border.
    local icon = button:CreateTexture(nil, 'ARTWORK')
    icon:NUISetPixelInside(button, 1, 1)
    icon:NUISetZoom()
    button.Icon = icon
    button:SetIcon(icon)

    -- Cooldown spiral over the icon.
    local cooldown
    if not Opt(options, container, 'disableCooldown') then
        -- Reused when already there, which only a preview dummy does: the container skins a button once.
        cooldown = button.Cooldown or CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
        cooldown:SetAllPoints(icon)
        cooldown:SetDrawEdge(Opt(options, container, 'drawEdge', false))
        cooldown:SetDrawBling(false)
        cooldown:SetDrawSwipe(Opt(options, container, 'drawSwipe', false))
        cooldown:SetReverse(Opt(options, container, 'reverseSwipe', false))
        cooldown:SetHideCountdownNumbers(true) -- we render our own duration text
        cooldown:SetSwipeColor(0, 0, 0, 0.7)
        button.Cooldown = cooldown
        button:SetDurationCooldown(cooldown)
    end

    local showApplicationCount = Opt(options, container, 'showApplicationCount')
    local showDurationText = Opt(options, container, 'showDurationText')
    local showBuffDispelIcon = Opt(options, container, 'showBuffDispelIcon')
    local showDebuffDispelIcon = Opt(options, container, 'showDebuffDispelIcon')

    -- Create a overlay frame to hold the optional regions, so they can be stacked above the cooldown and icon.
    local overlay = button
    if cooldown and (showApplicationCount or showDurationText or showBuffDispelIcon or showDebuffDispelIcon) then
        overlay = button.nuiAuraOverlay or CreateFrame('Frame', nil, button)
        overlay:SetAllPoints()
        overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)
        button.nuiAuraOverlay = overlay
    end

    local fontDB = Opt(options, container, 'fontDB')
    local stackFont = Opt(options, container, 'stackFont')
    local durationFont = Opt(options, container, 'durationFont')

    -- Count text setup
    if showApplicationCount then
        local pos = stackFont and stackFont.Position
        local count = overlay:CreateFontString(nil, 'OVERLAY')
        count:SetFontStyle(fontDB, stackFont and stackFont.FontSize or 10, nil, nil, true)
        count:SetFontJustify(stackFont or 'BOTTOMRIGHT', button, pos and pos.XOffset or -1, pos and pos.YOffset or 1, true)
        button.Count = count
        button:SetApplicationCount(count, {
            formatter = Opt(options, container, 'applicationCountFormatter'),
        })
    end

    -- Duration text setup w/ custom formatter and coloring.
    if showDurationText then
        local pos = durationFont and durationFont.Position
        local time = overlay:CreateFontString(nil, 'OVERLAY')
        time:SetFontStyle(fontDB, durationFont and durationFont.FontSize or 12, nil, nil, true)
        time:SetFontJustify(durationFont or 'CENTER', button, pos and pos.XOffset or 0, pos and pos.YOffset or 0, true)
        button.Time = time

        local useBreakpointColors, useCurveColors, useSingleColor, singleColor = GetGlobalDurationColorMode()
        local configuredCurve = Opt(options, container, 'durationTextColorCurve')
        local colorCurve = (configuredCurve == true) and NRSKNUI.curves.AuraDurationColor or configuredCurve

        button:SetDurationText(time, {
            textFormatter = Opt(options, container, 'durationTextFormatter')
                or NRSKNUI:GetAuraDurationFormatter(useBreakpointColors, (useSingleColor and singleColor) or nil),
            textColor = (useCurveColors and colorCurve) and {
                curve = colorCurve,
                property = Enum.DurationTextBindingProperty.RemainingDuration,
            } or nil,
        })
    end

    -- Optional border for weapon-enchant buttons.
    local borderColor = Opt(options, container, 'borderColor')
    if borderColor then
        local enchantBorder = overlay:CreateTexture(nil, 'OVERLAY')
        enchantBorder:SetTexture('Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\AuraOverlay.png') -- Use our own border texture.
        enchantBorder:NUISetPixelSnap()
        enchantBorder:NUISetPixelInside(button)
        enchantBorder:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    end

    -- Dispel-colored border overlay, coloring is handled natively from the dispel color map/curve.
    local showBuffBorder = Opt(options, container, 'showBuffBorder')
    local showDebuffBorder = Opt(options, container, 'showDebuffBorder')
    if showBuffBorder or showDebuffBorder then
        local border = overlay:CreateTexture(nil, 'OVERLAY')
        border:SetTexture('Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\AuraOverlay.png') -- Use our own border texture.
        border:NUISetPixelSnap()
        border:NUISetPixelInside(button)
        button.Border = border
        button:AddDispelTypeTexture(border, {
            style = Opt(options, container, 'borderStyle', Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset),
            showWhenHelpful = showBuffBorder == true,
            showWhenHarmful = showDebuffBorder == true,
            showWithoutDispelType = Opt(options, container, 'showWithoutDispelType') == true,
            customDispelColorMap = Opt(options, container, 'customDispelColorMap', NRSKNUI.Colors.dispel),
            customDispelColorCurve = Opt(options, container, 'customDispelColorCurve'),
        })
    end

    -- Native dispel type icon in the corner.
    local dispelIconSize = Opt(options, container, 'dispelIconSize')
    if showBuffDispelIcon or showDebuffDispelIcon then
        local dispelIcon = overlay:CreateTexture(nil, 'OVERLAY')
        dispelIcon:SetPoint('TOPRIGHT', button, 'TOPRIGHT', -2, -2)
        dispelIcon:SetSize(dispelIconSize, dispelIconSize)
        button.DispelIcon = dispelIcon
        button:AddDispelTypeTexture(dispelIcon, {
            style = Enum.CustomAuraButtonDispelTypeTextureStyle.Icon,
            showWhenHelpful = showBuffDispelIcon == true,
            showWhenHarmful = showDebuffDispelIcon == true,
        })
    end

    -- Right-click cancelaura.
    local cancelAuraButtons = Opt(options, container, 'cancelAuraButtons')
    if cancelAuraButtons then
        button:SetCancelAuraButtons(cancelAuraButtons)
    end

    -- Post-create hook for any additional skinning the caller wants to do.
    -- This is called after all the regions are created and assigned to the button.
    if container.PostCreateButton then
        container:PostCreateButton(button, options)
    end
end

---Push the container-level flow layout settings.
---Shared by creation and :ApplyLayout, since every one of these can be changed on a live container.
---@param container table
---@param config table
local function ApplyFlowLayout(container, config)
    local defaults = CustomAuraContainerLayoutDefaults
    local pad = config.padding or 0
    local horizontalGrowth = ResolveGrowthDirection(config.horizontalGrowthDirection, defaults.horizontalGrowthDirection)
    local verticalGrowth = ResolveGrowthDirection(config.verticalGrowthDirection, defaults.verticalGrowthDirection)

    container:SetFlowLayoutAxis(config.layoutAxis or defaults.axis)
    container:SetFlowLayoutAnchorPoint(config.anchorPoint or defaults.anchorPoint)
    container:SetFlowLayoutGrowthDirection(horizontalGrowth, verticalGrowth)
    container:SetFlowLayoutPadding(config.paddingLeft or pad, config.paddingRight or pad, config.paddingTop or pad, config.paddingBottom or pad)
    container:SetFlowLayoutMaximumLineSize(config.maximumLineSize) -- nil means unbounded
end

---Pad a group/enchant layout table with the container's element-wide layout defaults.
---@param container table
---@param layout table?
---@return table
local function ResolveLayout(container, layout)
    layout = layout or {}

    for _, key in ipairs(LAYOUT_OPTIONS) do
        if layout[key] == nil then
            layout[key] = container[key]
        end
    end

    return layout
end

-- Convenience mixin applied to every container created through frame:CreateAuraContainer.
-- This mirrors oUF's element API so unit-frame and standalone code read the same.
local ContainerMixin = {}

---Pad group/slot options with the container's element-wide defaults and install the NorskenUI skin.
---@param container table
---@param options table
local function ResolveDisplayOptions(container, options)
    options.sortMethod = options.sortMethod or container.sortMethod or AuraContainerSortMethod.ExpirationOnly
    options.sortDirection = options.sortDirection or container.sortDirection or AuraContainerSortDirection.Normal

    if not options.initializeFrame then
        options.initializeFrame = GenerateClosure(NRSKNUI.SkinAuraButton, NRSKNUI, container, options)
    end
end

---Which identity verdict a display's spellID matching hangs on, nil when the client never voids it.
---@param filterString string
---@param candidateFilters table?
---@return boolean?
local function ResolveIdentityDependence(filterString, candidateFilters)
    if not NRSKNUI.AuraFilters:HasSpellIDCandidates(candidateFilters) then return nil end

    local anySecret = false
    for spellId in pairs(candidateFilters.includeSpellIDs) do
        if NRSKNUI:IsSpellAuraSecret(spellId) then
            anySecret = true
            break
        end
    end
    if not anySecret then return nil end

    for component in filterString:gmatch('[^| ]+') do
        if component == AuraFilterTokens.Helpful then return true end
        if component == AuraFilterTokens.Harmful then return false end
    end

    return nil
end

---Does this filter string carry anything the client can drop? A bare base token has nothing to lose.
---@param filterString string
---@return boolean
local function IsFilterStringNarrowing(filterString)
    local seen = false
    for _ in filterString:gmatch('[^| ]+') do
        if seen then return true end
        seen = true
    end

    return false
end

---Mirrors AuraContainerUtil.CanApplyIdentityCandidateFilters: a spellID list is voided for harmful
---auras on assistable units and helpful auras on the rest, group members excepted.
---@param container table
---@param identity boolean? this display's ResolveIdentityDependence verdict
---@param assistOnly boolean? the display belongs on units the player can help, whatever it matches
---@param narrowing boolean? this display's IsFilterStringNarrowing verdict
---@return boolean
local function IsGated(container, identity, assistOnly, narrowing)
    if narrowing and container.unitInvisible then return true end
    if assistOnly and container.unitCanAssist == false then return true end
    if identity == nil then return false end
    if identity == true and container.unitAlwaysHelpful then return false end
    if container.unitCanAssist == nil then return false end

    return identity ~= container.unitCanAssist
end

---What a group's frame cap should be right now.
---@param container table
---@param slot number
---@return number
local function ResolveMaxFrameCount(container, slot)
    if container.parkedSlots and container.parkedSlots[slot] then return 0 end

    local identity = container.groupIdentity and container.groupIdentity[slot]
    local narrowing = container.groupNarrowing and container.groupNarrowing[slot]
    if IsGated(container, identity, nil, narrowing) then return 0 end

    return container.maxFrameCount or huge
end

---Sole writer of a group's frame cap, so the value it caches can never go stale behind another path.
---@param container table
---@param slot number
---@param key string
local function PushGroupCap(container, slot, key)
    local cap = ResolveMaxFrameCount(container, slot)
    local pushed = container.groupCaps

    if pushed[slot] == cap then return end
    pushed[slot] = cap

    container:SetAuraGroupMaxFrameCount(key, cap)
end

---Sole writer of a slot's candidate filters, see PushGroupCap. The gate cannot use the slot's filter
---string: a non-visible unit is exactly where the client stops honouring one.
---@param container table
---@param index number
---@param key string
local function PushSlotCandidates(container, index, key)
    local filters = NEVER_MATCH_CANDIDATES
    if container.slotShown[index] and
        not IsGated(container, container.slotIdentity[index], container.slotAssistOnly[index], container.slotNarrowing[index]) then
        filters = container.slotCandidates[index] -- may be nil, meaning this slot filters on tokens alone
    end

    local pushed = container.slotPushed
    if pushed[index] == filters then return end
    pushed[index] = filters

    container:SetAuraSlotCandidateFilters(key, filters)
end

local SampleWatcher -- lives with the watchers below

---Mark that this container gates on the canAssist axis. Sticky, it can only ever over-read.
---@param container table
local function MarkNeedsAssist(container)
    if container.needsAssist then return end
    container.needsAssist = true

    local watcher = container.gateWatcher
    if not watcher then return end

    watcher.assistCount = watcher.assistCount + 1
    if watcher.canAssist == nil then SampleWatcher(watcher) end -- never sampled before now
end

---Mark that this container has a display whose filter string can be dropped. Sticky, as above.
---@param container table
local function MarkNeedsVisible(container)
    if container.needsVisible then return end
    container.needsVisible = true

    local watcher = container.gateWatcher
    if not watcher then return end

    watcher.visibleCount = watcher.visibleCount + 1
    SampleWatcher(watcher)
end

---Register a group of auras, can be called multiple times.
---@param filter string aura filter string ('HELPFUL', 'HARMFUL', ...)
---@param options table? optional per-group options
---@return string key
---@return number slot
function ContainerMixin:AddGroup(filter, options)
    options = options or {}

    options.maxFrameCount = options.maxFrameCount or self.maxFrameCount
    options.layout = ResolveLayout(self, options.layout)
    ResolveDisplayOptions(self, options)

    self.groupIndex = (self.groupIndex or 0) + 1
    local key = (self:GetDebugName() or 'NRSKNUIAuraContainer') .. 'Group' .. self.groupIndex
    self:AddAuraGroup(key, filter, options)

    -- Remembered so :ApplyLayout can re-push per-group settings without the caller tracking keys.
    self.groupKeys = self.groupKeys or {}
    self.groupIdentity = self.groupIdentity or {}
    self.groupNarrowing = self.groupNarrowing or {}
    local slot = #self.groupKeys + 1
    self.groupKeys[slot] = key
    self.groupIdentity[slot] = ResolveIdentityDependence(filter, options.candidateFilters)
    if self.groupIdentity[slot] ~= nil then MarkNeedsAssist(self) end

    self.groupNarrowing[slot] = IsFilterStringNarrowing(filter) or nil
    if self.groupNarrowing[slot] then MarkNeedsVisible(self) end

    -- A group added while its gate is shut would otherwise come up live.
    PushGroupCap(self, slot, key)

    return key, slot
end

---Compiled branches for a trigger, always at least one so a binding never ends up with no groups.
---@param trigger table?
---@return table[] branches
local function ResolveBranches(trigger)
    local branches = NRSKNUI:GetTriggerBranches(trigger)
    if branches and branches[1] then return branches end
    return { { filterString = AuraFilterTokens.Harmful } }
end

---Point a binding's groups at its trigger's current branches.
---@param container table
---@param binding table
local function SyncBinding(container, binding)
    local branches = ResolveBranches(binding.trigger)
    container.parkedSlots = container.parkedSlots or {}
    container.groupIdentity = container.groupIdentity or {}
    container.groupNarrowing = container.groupNarrowing or {}

    for index, branch in ipairs(branches) do
        container:EnsureProcessAuraPolicy(branch.candidateFilters)

        local key = binding.keys[index]
        if key then
            container:SetAuraGroupFilterString(key, branch.filterString)
            container:SetAuraGroupCandidateFilters(key, branch.candidateFilters)
        else
            -- AddGroup mutates the options it is given, so each group gets its own copy.
            local groupOptions = binding.options and CopyTable(binding.options) or {}
            groupOptions.candidateFilters = branch.candidateFilters
            binding.keys[index], binding.slots[index] = container:AddGroup(branch.filterString, groupOptions)
        end

        local slot = binding.slots[index]
        container.groupIdentity[slot] = ResolveIdentityDependence(branch.filterString, branch.candidateFilters)
        if container.groupIdentity[slot] ~= nil then MarkNeedsAssist(container) end

        container.groupNarrowing[slot] = IsFilterStringNarrowing(branch.filterString) or nil
        if container.groupNarrowing[slot] then MarkNeedsVisible(container) end
        container.parkedSlots[slot] = nil
        PushGroupCap(container, slot, binding.keys[index])
    end

    for index = #branches + 1, #binding.keys do
        container.parkedSlots[binding.slots[index]] = true
        PushGroupCap(container, binding.slots[index], binding.keys[index])
    end
end

---Register an inline trigger, can be called multiple times.
---@param trigger table? an inline trigger (see Core/Auras/AuraTriggers.lua)
---@param options table? optional per-group options (candidateFilters is filled in from each branch)
---@return string[]
function ContainerMixin:AddFilteredGroup(trigger, options)
    local binding = { trigger = trigger, keys = {}, slots = {}, options = options }

    self.filterBindings = self.filterBindings or {}
    self.filterBindings[#self.filterBindings + 1] = binding

    SyncBinding(self, binding)

    return binding.keys
end

---Turn on the ProcessAura policy when a filter asks to match on processedAuraType.
---@param candidateFilters table? the resolved candidate filter table (may be nil)
function ContainerMixin:EnsureProcessAuraPolicy(candidateFilters)
    if not (candidateFilters and candidateFilters.processedAuraType) then return end
    if self.processAuraPolicy then return end

    self:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.ProcessAura, self.__processAuraPolicyOptions)
    self.processAuraPolicy = true
end

---Re-push everything the native container lets us change after creation.
---@param config table? the same table accepted by frame:CreateAuraContainer
function ContainerMixin:ApplyLayout(config)
    config = config or {}

    ApplyFlowLayout(self, config)

    for _, key in ipairs(ELEMENT_OPTIONS) do
        self[key] = config[key]
    end

    for slot, key in ipairs(self.groupKeys or {}) do
        self:SetAuraGroupLayout(key, ResolveLayout(self, nil))
        PushGroupCap(self, slot, key)
        self:SetAuraGroupSortMethod(key, self.sortMethod or AuraContainerSortMethod.ExpirationOnly, self.sortDirection or AuraContainerSortDirection.Normal)
    end
end

---Reapply every binding registered through :AddFilteredGroup
function ContainerMixin:ReapplyFilters()
    if not self.filterBindings then return end

    NRSKNUI:RunWhenSafe(function()
        for _, binding in ipairs(self.filterBindings) do
            SyncBinding(self, binding)
        end
    end)
end

---Point every binding registered through :AddFilteredGroup at a different trigger and reapply.
---Used when the GUI edits or replaces the trigger a display runs.
---@param trigger table? an inline trigger (see Core/Auras/AuraTriggers.lua)
function ContainerMixin:RebindFilteredGroups(trigger)
    if not self.filterBindings then return end

    for _, binding in ipairs(self.filterBindings) do
        binding.trigger = trigger
    end

    self:ReapplyFilters()
end

---Register a single-aura slot (this can be called multiple times).
---@param filter string aura filter string
---@param options table? optional per-slot options (.assistOnly keeps the slot to units the player can help)
---@return table? slot
---@return string key
---@return number index
function ContainerMixin:AddSlot(filter, options)
    options = options or {}

    -- Ours rather than the client's, so it comes back out before the table crosses over.
    local assistOnly = options.assistOnly
    options.assistOnly = nil

    self:EnsureProcessAuraPolicy(options.candidateFilters)
    ResolveDisplayOptions(self, options)

    self.slotIndex = (self.slotIndex or 0) + 1
    local key = (self:GetDebugName() or 'NRSKNUIAuraContainer') .. 'Slot' .. self.slotIndex

    local index = self.slotIndex
    self.slotKeys[index] = key
    self.slotCandidates[index] = options.candidateFilters
    self.slotShown[index] = true
    self.slotIdentity[index] = ResolveIdentityDependence(filter, options.candidateFilters)
    self.slotAssistOnly[index] = assistOnly or nil
    if self.slotIdentity[index] ~= nil or assistOnly then MarkNeedsAssist(self) end

    self.slotNarrowing[index] = IsFilterStringNarrowing(filter) or nil
    if self.slotNarrowing[index] then MarkNeedsVisible(self) end

    local slot = self:AddAuraSlot(key, filter, options)

    self.slotPushed[index] = options.candidateFilters -- AddAuraSlot has just installed these

    -- A slot added while its gate is shut would otherwise come up live.
    PushSlotCandidates(self, index, key)

    return slot, key, index
end

---Show or hide a slot, which the gate can still override.
---@param index number the third return of :AddSlot
---@param shown boolean
function ContainerMixin:SetSlotShown(index, shown)
    local key = self.slotKeys[index]
    if not key then return end

    self.slotShown[index] = shown
    PushSlotCandidates(self, index, key)
end

local UNIT_GATE_EVENTS = {
    'UNIT_FLAGS', 'UNIT_TARGETABLE_CHANGED',
    'UNIT_FACTION', -- The canAssist axis, UNIT_FLAGS alone misses reaction changes
    'UNIT_IN_RANGE_UPDATE', 'UNIT_DISTANCE_CHECK_UPDATE',
    'UNIT_PHASE', 'UNIT_AREA_CHANGED',
    'UNIT_NAME_UPDATE' -- Fires when the client learns a unit, the nearest entering-visibility signal
}

local GATE_EVENTS = {
    'PLAYER_ENTERING_WORLD', 'ZONE_CHANGED_NEW_AREA', -- visibility
    'GROUP_ROSTER_UPDATE',                            -- UnitIsPlayerControlledOrGroupMember
    'ZONE_CHANGED', 'ZONE_CHANGED_INDOORS',
    'GROUP_ROSTER_UPDATE', 'PARTY_MEMBER_ENABLE',
    'PARTY_MEMBER_DISABLE', 'PLAYER_FLAGS_CHANGED',
    'CINEMATIC_START', 'CINEMATIC_STOP', 'PLAY_MOVIE', 'STOP_MOVIE', -- no UNIT_* event marks either edge
    'PLAYER_DEAD', 'PLAYER_ALIVE', 'PLAYER_UNGHOST'                  -- quieter than the UNIT_HEALTH other units need
}

-- Item enchants need a re-push after a loading screen, which outlasts a frame.
local SETTLE_EVENTS = {
    PLAYER_ENTERING_WORLD = true
}

local SETTLE_DELAY = 0.5

-- One watcher per unit token: the four containers a unit frame builds all want the same verdict.
---@type table<string, Frame>
local watchers = {}
local globalWatcher

---@type table<table, true> containers holding item enchants
local enchantContainers = {}

---Push a watcher's verdict onto one container.
---@param container table
---@param watcher Frame
---@return boolean changed
local function ApplyGate(container, watcher)
    local canAssist, alwaysHelpful, invisible
    if container.needsAssist then
        canAssist = watcher.canAssist
        alwaysHelpful = watcher.alwaysHelpful
    end
    if container.needsVisible then
        invisible = watcher.invisible
    end

    if container.unitCanAssist == canAssist and container.unitAlwaysHelpful == alwaysHelpful
        and container.unitInvisible == invisible then
        return false
    end

    container.unitCanAssist = canAssist
    container.unitAlwaysHelpful = alwaysHelpful
    container.unitInvisible = invisible

    for slot, key in ipairs(container.groupKeys or {}) do PushGroupCap(container, slot, key) end
    for index, key in ipairs(container.slotKeys or {}) do PushSlotCandidates(container, index, key) end

    return true
end

---Re-read a watcher's unit into its cached verdict.
---@param watcher Frame
function SampleWatcher(watcher)
    watcher.sampled = GetTime()

    if watcher.assistCount > 0 then
        -- Both reads mirror CanApplyIdentityCandidateFilters, including its two canAssist overrides.
        watcher.canAssist = UnitCanAssist('player', watcher.unit, true, true)
        watcher.alwaysHelpful = UnitIsPlayerControlledOrGroupMember and UnitIsPlayerControlledOrGroupMember(watcher.unit) or nil
    else
        watcher.canAssist, watcher.alwaysHelpful = nil, nil
    end

    watcher.invisible = watcher.visibleCount > 0 and not UnitIsVisible(watcher.unit) or nil
end

---Re-read a watcher's unit and push the result to every container on it.
---@param watcher Frame
local function RefreshWatcher(watcher)
    if not watcher.unit then return end
    SampleWatcher(watcher)

    -- UNIT_FLAGS and friends fire constantly in group content but almost never move the verdict.
    for container in pairs(watcher.containers) do
        if ApplyGate(container, watcher) then
            container:UpdateAllAuras()
        end
    end
end

local function RefreshAll()
    for _, watcher in pairs(watchers) do
        if watcher.count > 0 then
            RefreshWatcher(watcher)
        end
    end
end

local function SettleAll()
    RefreshAll()

    -- Item enchants sit outside the gate, so a verdict that never moved leaves them dead after a loading screen.
    for container in pairs(enchantContainers) do
        container:UpdateAllAuras()
    end
end

---Re-read next frame and again after SETTLE_DELAY, since a load screen outlasts a frame.
---@param frame Frame
---@param callback fun()
local function ScheduleSettle(frame, callback)
    frame:NUIScheduleUpdate()

    if frame.settling then return end
    frame.settling = true

    C_Timer.After(SETTLE_DELAY, function()
        frame.settling = nil
        callback()
    end)
end

---@param watcher Frame
local function OnGateEvent(watcher)
    RefreshWatcher(watcher)
end

---@param _ Frame
---@param event string
local function OnGlobalGateEvent(_, event)
    RefreshAll()

    if SETTLE_EVENTS[event] then
        ScheduleSettle(globalWatcher, SettleAll)
    end
end

---@param watcher Frame
local function RegisterWatcher(watcher)
    local unit = watcher.unit

    -- An unrecognised token turns every RegisterUnitEvent into a unitless one, firing for the whole roster.
    if not NRSKNUI:IsValidUnitToken(unit) then return end

    for _, event in ipairs(UNIT_GATE_EVENTS) do
        watcher:RegisterUnitEvent(event, unit, unit ~= 'player' and 'player' or nil)
    end
end

---The shared watcher for a unit, built on first use.
---@param unit string
---@return Frame watcher
local function GetWatcher(unit)
    local watcher = watchers[unit]
    if watcher then return watcher end

    watcher = CreateFrame('Frame')
    watcher.unit = unit
    watcher.containers = {}
    watcher.count = 0
    watcher.assistCount = 0
    watcher.visibleCount = 0
    watcher:SetScript('OnEvent', OnGateEvent)
    watcher:NUISetScheduledUpdate(RefreshWatcher)
    watchers[unit] = watcher

    if not globalWatcher then
        globalWatcher = CreateFrame('Frame')
        globalWatcher:SetScript('OnEvent', OnGlobalGateEvent)
        globalWatcher:NUISetScheduledUpdate(RefreshAll)
        for _, event in ipairs(GATE_EVENTS) do globalWatcher:RegisterEvent(event) end
    end

    return watcher
end

---Move a container onto the shared watcher for a unit, dropping the one it was on.
---@param container table
---@param unit string
---@return Frame watcher
local function WatchUnit(container, unit)
    local current = container.gateWatcher

    if current then
        current.containers[container] = nil
        current.count = current.count - 1
        if container.needsAssist then current.assistCount = current.assistCount - 1 end
        if container.needsVisible then current.visibleCount = current.visibleCount - 1 end

        -- Frames cannot be destroyed, so an idle watcher is kept for reuse but stops listening.
        if current.count == 0 then current:UnregisterAllEvents() end
    end

    local watcher = GetWatcher(unit)
    if watcher.count == 0 then RegisterWatcher(watcher) end

    watcher.containers[container] = true
    watcher.count = watcher.count + 1
    if container.needsAssist then watcher.assistCount = watcher.assistCount + 1 end
    if container.needsVisible then watcher.visibleCount = watcher.visibleCount + 1 end
    container.gateWatcher = watcher

    SampleWatcher(watcher)

    return watcher
end

---Reapply this container's gate for its current unit.
---@return boolean changed true when the verdict moved and the filters were reapplied
function ContainerMixin:UpdateUnitGate()
    local unit = self:GetUnit()
    if not unit then return false end

    local watcher = self.gateWatcher
    if not watcher or watcher.unit ~= unit then
        watcher = WatchUnit(self, unit)
    elseif watcher.sampled ~= GetTime() then
        SampleWatcher(watcher) -- once per frame, however many containers on the unit ask
    end

    return ApplyGate(self, watcher)
end

---Register a temporary weapon-enchant frame (main/off-hand).
---@param slot number AuraContainerItemEnchantmentSlot value (MainHand / OffHand / Ranged)
---@param options table? optional per-frame options (.hidePermanent, .templateNames, ...)
---@return table? enchant
function ContainerMixin:AddItemEnchant(slot, options)
    options = options or {}

    if options.borderColor == nil then options.borderColor = NRSKNUI.Colors.enchantColor end
    if options.hidePermanent == nil then options.hidePermanent = self.hidePermanent end
    if not options.initializeFrame then options.initializeFrame = GenerateClosure(NRSKNUI.SkinAuraButton, NRSKNUI, self, options) end

    enchantContainers[self] = true

    return self:AddItemEnchantment(slot, options)
end

---Set the flow layout for the item-enchant group, padded with the container's layout defaults.
---@param options table? optional layout overrides (.placement, .elementSpacing, .groupSpacing, .layoutIndex, ...)
function ContainerMixin:SetItemEnchantLayout(options)
    self:SetItemEnchantmentLayout(ResolveLayout(self, options))
end

---Create a native aura container parented to this frame and return it with the NorskenUI convenience API mixed.
---@param config table?
---@return table? container
local function CreateAuraContainer(self, config)
    config = config or {}

    local container = CreateFrame('AuraContainer', nil, self, 'CustomAuraContainerTemplate')

    ApplyFlowLayout(container, config)

    -- Carry element-wide skin/layout defaults so AddGroup/AddSlot and the skin can read them.
    for _, key in ipairs(ELEMENT_OPTIONS) do
        container[key] = config[key]
    end

    -- Kept addon-side, the container's own processAuraPolicyOptions live in the restricted environment.
    container.__processAuraPolicyOptions = config.processAuraPolicyOptions

    -- Last value PushGroupCap / PushSlotFilter handed the client, so an idempotent re-push stays addon-side.
    container.groupCaps = {}
    container.slotPushed = {}
    container.slotKeys = {}
    container.slotCandidates = {}
    container.slotShown = {}
    container.slotIdentity = {}
    container.slotNarrowing = {}
    container.slotAssistOnly = {}

    local policy = config.auraProcessingPolicy
    if policy then
        local isProcessAura = policy == CustomAuraContainerAuraProcessingPolicy.ProcessAura
        container:SetAuraProcessingPolicy(policy, isProcessAura and config.processAuraPolicyOptions or nil)
        container.processAuraPolicy = isProcessAura
    end

    if config.itemEnchantmentSortMethod then
        container:SetItemEnchantmentSortMethod(config.itemEnchantmentSortMethod, config.itemEnchantmentSortDirection or AuraContainerSortDirection.Normal)
    end

    return Mixin(container, ContainerMixin)
end

NRSKNUI:InjectAPI(CreateFrame('Frame'), { CreateAuraContainer = CreateAuraContainer })
NRSKNUI:InjectAPI(CreateFrame('Button'), { CreateAuraContainer = CreateAuraContainer })

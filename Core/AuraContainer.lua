---@class NRSKNUI
local NRSKNUI = select(2, ...)

local CreateFrame = CreateFrame
local Mixin = Mixin
local GenerateClosure = GenerateClosure
local CopyTable = CopyTable
local ipairs = ipairs
local type = type
local huge = math.huge

-- Read from the live client rather than hardcoded, these tokens can change between patches.
local AuraFilterTokens = AuraUtil.AuraFilters

--[[

Option names in this file mirror Blizzard_AuraContainer 1:1 so config tables can be read straight against the source:

* Blizzard_AuraContainerShared.lua:
    * CustomAuraContainerLayoutDefaults
    * CustomAuraContainerGroupDefaultOptions
    * CustomAuraContainerGroupLayoutDefaultOptions
    * CustomAuraContainerItemEnchantment
    * CustomAuraContainerProcessAuraPolicyDefaultOptions

* Blizzard_CustomAuraButton.lua:
    * Set/AddDispelTypeTexture
    * SetApplicationCount
    * SetDurationText
    * SetDurationCooldown

* Blizzard_AuraButton.lua:
    * SetTooltipAnchorPoint
    * SetHideTooltipInCombat
    * SetCancelAuraButtons

* Native enums/constants, globals provided by Blizzard_AuraContainer:
    * AuraContainerSortMethod / AuraContainerSortDirection
    * AuraContainerItemEnchantmentSlot / AuraContainerItemEnchantmentSortMethod
    * CustomAuraContainerAuraProcessingPolicy / CustomAuraContainerItemEnchantmentPlacement
    * Enum.CustomAuraButtonDispelTypeTextureStyle

--]]

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

--[[

API: NRSKNUI:SkinAuraButton(container, options, button)

Shared aura button constructor.
Passed to the native container as `initializeFrame`, called for every aura button created by the container.

Runs inside the container's securecallfunction context, so creating and anchoring regions on the
forbidden button is permitted. We attach regions and hand them to the button's native Set methods.
Tooltips, mouse handling and duration text are all driven natively.

* container - the AuraContainer element
* options   - the group/slot options (carries size/font/toggle overrides)
* button    - the native AuraButton

--]]
---@param container table
---@param options table
---@param button table
function NRSKNUI:SkinAuraButton(container, options, button)
    options = options or {}

    -- Size the button and add a backdrop for border.
    local size = Opt(options, container, 'size', 24)
    button:SetSize(Opt(options, container, 'width', size), Opt(options, container, 'height', size))
    button:EnableMouse(not Opt(options, container, 'disableMouse'))
    NRSKNUI:CreateBackdrop(button, nil, 0)

    -- Tooltip anchor and combat hiding. The native button handles the tooltip itself, we just tell it where to go.
    button:SetTooltipAnchorPoint(
        Opt(options, container, 'tooltipAnchorPoint', 'ANCHOR_BOTTOMLEFT'),
        Opt(options, container, 'tooltipOffsetX', 0),
        Opt(options, container, 'tooltipOffsetY', 0)
    )
    button:SetHideTooltipInCombat(Opt(options, container, 'tooltipHideInCombat') == true)

    -- Icon, trimmed and inset inside the 1px backdrop border.
    local icon = button:CreateTexture(nil, 'ARTWORK')
    icon:SetPixelInside(button, 1, 1)
    icon:SetZoom()
    button.Icon = icon
    button:SetIcon(icon)

    -- Cooldown spiral over the icon.
    local cooldown
    if not Opt(options, container, 'disableCooldown') then
        cooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
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
        overlay = CreateFrame('Frame', nil, button)
        overlay:SetAllPoints()
        overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)
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
                or NRSKNUI:GetAuraDurationFormatter(useBreakpointColors, useSingleColor and singleColor or nil),
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
        enchantBorder:SetPixelSnap()
        enchantBorder:SetPixelInside(button)
        enchantBorder:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    end

    -- Dispel-colored border overlay, coloring is handled natively from the dispel color map/curve.
    local showBuffBorder = Opt(options, container, 'showBuffBorder')
    local showDebuffBorder = Opt(options, container, 'showDebuffBorder')
    if showBuffBorder or showDebuffBorder then
        local border = overlay:CreateTexture(nil, 'OVERLAY')
        border:SetTexture('Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\AuraOverlay.png') -- Use our own border texture.
        border:SetPixelSnap()
        border:SetPixelInside(button)
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

---Push the container-level flow layout settings. Shared by creation and :ApplyLayout, since every one of these can be changed on a live container.
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

--[[

API: container:AddGroup(filter[, options])

Register a group of auras, can be called multiple times.
Pads options with element-wide defaults and installs the NorskenUI skin as the default button constructor.

* filter  - aura filter string ('HELPFUL', 'HARMFUL', ...)
* options - optional per-group options

Returns the generated group key and its slot in __groupKeys. The key is derived from GetDebugName,
which is a secret once another addon has tainted us, so it can be passed on but never compared or used as a table key.
Anything that needs to find a group again must remember the slot.
--]]
---@param filter string
---@param options table?
---@return string key
---@return number slot
function ContainerMixin:AddGroup(filter, options)
    options = options or {}

    options.maxFrameCount = options.maxFrameCount or self.maxFrameCount
    options.layout = ResolveLayout(self, options.layout)
    ResolveDisplayOptions(self, options)

    self.__groupIndex = (self.__groupIndex or 0) + 1
    local key = (self:GetDebugName() or 'NRSKNUIAuraContainer') .. 'Group' .. self.__groupIndex
    self:AddAuraGroup(key, filter, options)

    -- Remembered so :ApplyLayout can re-push per-group settings without the caller tracking keys.
    self.__groupKeys = self.__groupKeys or {}
    local slot = #self.__groupKeys + 1
    self.__groupKeys[slot] = key

    return key, slot
end

---Compiled branches for a name, always at least one so a binding never ends up with no groups.
---@param filterName string?
---@return table[] branches
local function ResolveBranches(filterName)
    local branches = NRSKNUI:GetAuraFilter(filterName)
    if branches and branches[1] then return branches end
    return { { filterString = AuraFilterTokens.Harmful } }
end

---Point a binding's groups at its filter's current branches: rebind the groups it already owns,
---grow for branches it has no group for, and park the surplus.
---
---Groups cannot be removed from a live container, so a branch that goes away leaves its group behind with maxFrameCount 0,
---which drops it on the first refresh pass without it ever claiming a frame. Parked groups are tracked by slot, since group keys
---are secret strings and cannot be compared (see :AddGroup).
---@param container table
---@param binding table
local function SyncBinding(container, binding)
    local branches = ResolveBranches(binding.name)
    container.__parkedSlots = container.__parkedSlots or {}

    for index, branch in ipairs(branches) do
        container:EnsureProcessAuraPolicy(branch.candidateFilters)

        local key = binding.keys[index]
        if key then
            container:SetAuraGroupFilterString(key, branch.filterString)
            container:SetAuraGroupCandidateFilters(key, branch.candidateFilters)
            container:SetAuraGroupMaxFrameCount(key, container.maxFrameCount or huge) -- may be un-parking
        else
            -- AddGroup mutates the options it is given, so each group gets its own copy. Going through
            -- the same call the binding was created with keeps a live-added branch identical to an
            -- original one (skin, layout, sort).
            local groupOptions = binding.options and CopyTable(binding.options) or {}
            groupOptions.candidateFilters = branch.candidateFilters
            binding.keys[index], binding.slots[index] = container:AddGroup(branch.filterString, groupOptions)
        end

        container.__parkedSlots[binding.slots[index]] = nil
    end

    for index = #branches + 1, #binding.keys do
        container:SetAuraGroupMaxFrameCount(binding.keys[index], 0)
        container.__parkedSlots[binding.slots[index]] = true
    end
end

--[[

API: container:AddFilteredGroup(filterName[, options])

Register a named filter from db.global.AuraFilters, can be called multiple times.

The filter's branches become one aura group each, so a filter that ORs several conditions together
still lays out as a single grid. maxFrameCount applies per branch.

* filterName - key into db.global.AuraFilters (may be nil)
* options    - optional per-group options (candidateFilters is filled in from each branch)

Returns the generated group keys, one per branch.
--]]
---@param filterName string?
---@param options table?
---@return string[]
function ContainerMixin:AddFilteredGroup(filterName, options)
    local binding = { name = filterName, keys = {}, slots = {}, options = options }

    self.__filterBindings = self.__filterBindings or {}
    self.__filterBindings[#self.__filterBindings + 1] = binding

    SyncBinding(self, binding)

    return binding.keys
end

--[[

API: container:EnsureProcessAuraPolicy(candidateFilters)

Turn on the ProcessAura policy when a filter asks to match on processedAuraType.
Candidate filtering on that field hides every aura under any other policy, so this has to be on before the filter is applied.

* candidateFilters - the resolved candidate filter table (may be nil)

--]]
---@param candidateFilters table?
function ContainerMixin:EnsureProcessAuraPolicy(candidateFilters)
    if not (candidateFilters and candidateFilters.processedAuraType) then return end
    if self.__processAuraPolicy then return end

    self:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.ProcessAura, self.__processAuraPolicyOptions)
    self.__processAuraPolicy = true
end

--[[

API: container:ApplyLayout(config)

Re-push everything the native container lets us change after creation:
e.g the flow layout and each group's layout / frame cap / sort order.

Button appearance (size, font, widget toggles, cooldown options) is baked in by initializeFrame when
the button is created and Blizzard does not expose ClearAuraGroups, so those need a fresh container
(i.e. a reload) to take effect. Callers should treat this as "layout is live, looks are not".

* config - the same table accepted by frame:CreateAuraContainer

--]]
---@param config table?
function ContainerMixin:ApplyLayout(config)
    config = config or {}

    ApplyFlowLayout(self, config)

    for _, key in ipairs(ELEMENT_OPTIONS) do
        self[key] = config[key]
    end

    local parked = self.__parkedSlots
    for slot, key in ipairs(self.__groupKeys or {}) do
        self:SetAuraGroupLayout(key, ResolveLayout(self, nil))
        if not (parked and parked[slot]) then -- parked groups outlived their branch, leave them at 0
            self:SetAuraGroupMaxFrameCount(key, self.maxFrameCount or huge)
        end
        self:SetAuraGroupSortMethod(key,
            self.sortMethod or AuraContainerSortMethod.ExpirationOnly,
            self.sortDirection or AuraContainerSortDirection.Normal)
    end
end

--[[

API: container:ReapplyFilters()

Reapply every binding registered through :AddFilteredGroup, picking up branches added or removed
since the container was built. Deferred out of combat, since growing a binding creates groups.

--]]
function ContainerMixin:ReapplyFilters()
    if not self.__filterBindings then return end

    NRSKNUI:RunWhenSafe(function()
        for _, binding in ipairs(self.__filterBindings) do
            SyncBinding(self, binding)
        end
    end)
end

--[[

API: container:RebindFilteredGroups(filterName)

Point every binding registered through :AddFilteredGroup at a different named filter and reapply.
Used when the GUI switches which filter a module runs.

* filterName - key into db.global.AuraFilters (may be nil)

--]]
---@param filterName string?
function ContainerMixin:RebindFilteredGroups(filterName)
    if not self.__filterBindings then return end

    for _, binding in ipairs(self.__filterBindings) do
        binding.name = filterName
    end

    self:ReapplyFilters()
end

--[[

API: container:AddSlot(filter[, options])

Register a single-aura slot (this can be called multiple times).
Slots take no part in the flow layout, anchor them yourself.

* filter  - aura filter string
* options - optional per-slot options

Returns the created slot frame.

--]]
---@param filter string
---@param options table?
---@return table? slot
function ContainerMixin:AddSlot(filter, options)
    options = options or {}

    self:EnsureProcessAuraPolicy(options.candidateFilters)
    ResolveDisplayOptions(self, options)

    self.__slotIndex = (self.__slotIndex or 0) + 1
    local key = (self:GetDebugName() or 'NRSKNUIAuraContainer') .. 'Slot' .. self.__slotIndex
    return self:AddAuraSlot(key, filter, options)
end

--[[

API: container:AddItemEnchant(slot[, options])

Register a temporary weapon-enchant frame (main/off-hand).
Uses the shared skin, marked with a purple border by default.

* slot    - AuraContainerItemEnchantmentSlot value (MainHand / OffHand / Ranged)
* options - optional per-frame options (.hidePermanent, .templateNames, ...)

Returns the created enchant frame.

--]]
---@param slot number
---@param options table?
---@return table? enchant
function ContainerMixin:AddItemEnchant(slot, options)
    options = options or {}

    if options.borderColor == nil then
        options.borderColor = { 0.6, 0, 1 } -- purple marks a weapon enchant --TODO Add DB
    end

    if options.hidePermanent == nil then
        options.hidePermanent = self.hidePermanent
    end

    if not options.initializeFrame then
        options.initializeFrame = GenerateClosure(NRSKNUI.SkinAuraButton, NRSKNUI, self, options)
    end

    return self:AddItemEnchantment(slot, options)
end

--[[

API: container:SetItemEnchantLayout([options])

Set the flow layout for the item-enchant group, padded with the container's layout defaults.

* options - optional layout overrides (.placement, .elementSpacing, .groupSpacing, .layoutIndex, ...)

--]]
---@param options table?
function ContainerMixin:SetItemEnchantLayout(options)
    self:SetItemEnchantmentLayout(ResolveLayout(self, options))
end

--[[

API: frame:CreateAuraContainer([config])

Create a native aura container parented to this frame and return it with the NorskenUI convenience API mixed in, e.g:
API: :AddGroup / :AddSlot

Aura containers cannot be created in combat, so callers must invoke this out of combat so we wrap in NRSKNUI:RunWhenSafe.
Drive it by calling container:SetUnit(unit), once a group/slot exists the container self-registers for UNIT_AURA and updates itself.

Config keys carry Blizzard's own option names, defaults are Blizzard's unless noted.

* config - flow layout (CustomAuraContainerLayoutDefaults)
*   .layoutAxis                - AnchorUtil.FlowLayoutAxis, defaults to Horizontal (number?)
*   .anchorPoint               - layout anchor point, defaults to 'TOPLEFT' (string?)
*   .horizontalGrowthDirection - AnchorUtil.FlowDirection value or 'LEFT'/'RIGHT', defaults to Right (string|number?)
*   .verticalGrowthDirection   - AnchorUtil.FlowDirection value or 'UP'/'DOWN', defaults to Down (string|number?)
*   .maximumLineSize           - wrap size along the primary axis (width on Horizontal, height on Vertical), defaults to infinite (number?)

* layout padding (number?)
*   .padding
*   .paddingLeft
*   .paddingRight
*   .paddingTop
*   .paddingBottom
*
* config - group defaults (CustomAuraContainerGroupDefaultOptions / GroupLayoutDefaultOptions)
*   .maxFrameCount                  - max buttons per group; defaults to infinite (number?)
*   .sortMethod                     - AuraContainerSortMethod; defaults to ExpirationOnly (number?)
*   .sortDirection                  - AuraContainerSortDirection; defaults to Normal (number?)
*   .elementSpacing                 - spacing between buttons along the primary axis (number?)
*   .lineSpacing                    - spacing between button rows/columns (number?)
*   .groupSpacing                   - spacing between groups along the primary axis (number?)
*   .groupLineSpacing               - spacing between group rows/columns (number?)
*   .forceNewLine                   - break to a new row/column between groups (boolean?)
*   .elementWidth / .elementHeight  - override the size used for layout only (number?)
*   (.layoutIndex is per-group only, pass it in the group's own .layout table)
*
* config - aura processing (CustomAuraContainerProcessAuraPolicyDefaultOptions)
*   .auraProcessingPolicy       - CustomAuraContainerAuraProcessingPolicy; AddFilteredGroup turns ProcessAura on by itself when a filter needs it (number?)
*   .processAuraPolicyOptions   - ProcessAura options (.ignoreBuffs, .ignoreDebuffs, .ignoreDispelDebuffs, .displayOnlyDispellableDebuffs) (table?)
*
* config - item enchantments (CustomAuraContainerItemEnchantment*)
*   .hidePermanent                  - treat enchants without an expiration as inactive (boolean?)
*   .itemEnchantmentSortMethod      - AuraContainerItemEnchantmentSortMethod; defaults to Slot (number?)
*   .itemEnchantmentSortDirection   - AuraContainerSortDirection; defaults to Normal (number?)
*
* config - buttons (CustomAuraButton* option tables)
*   .size / .width / .height                                    - button size, defaults to 24 (number?)
*   .disableMouse / .disableCooldown                            - drop mouse handling / the cooldown spiral (boolean?)
*   .drawSwipe / .drawEdge / .reverseSwipe                      - cooldown spiral options (boolean?)
*   .showApplicationCount                                       - render the stack count (boolean?)
*   .applicationCountFormatter                                  - NumericFormatter for the stack count (object?)
*   .showDurationText                                           - render the remaining duration (boolean?)
*   .durationTextFormatter                                      - NumericFormatter override; defaults to the global duration color mode (object?)
*   .durationTextColorCurve                                     - color curve object, or true for NRSKNUI.curves.AuraDurationColor; only applies in curve mode (object|boolean?)
*   .showBuffBorder / .showDebuffBorder                         - dispel-colored border for helpful/harmful auras (boolean?)
*   .showWithoutDispelType                                      - keep the border visible on auras with no dispel type (boolean?)
*   .borderStyle                                                - Enum.CustomAuraButtonDispelTypeTextureStyle; defaults to PreserveAsset (number?)
*   .customDispelColorMap                                       - dispel name -> color, defaults to NRSKNUI.Colors.dispel (table?)
*   .customDispelColorCurve                                     - color curve sampled per dispel type instead of the map (object?)
*   .showBuffDispelIcon / .showDebuffDispelIcon                 - native dispel type icon in the corner (boolean?)
*   .tooltipAnchorPoint / .tooltipOffsetX / .tooltipOffsetY     - tooltip anchor, defaults to 'ANCHOR_BOTTOMLEFT' (string?/number?)
*   .tooltipHideInCombat                                        - suppress the tooltip while in combat (boolean?)
*   .cancelAuraButtons                                          - click tokens that cancel the aura, e.g. 'RightButtonUp' (string?)
*   .borderColor                                                - static border tint, used to mark weapon enchants (table?)
*   .fontDB / .fontSize / .fontOutline                          - button font (NorskenUI)

--]]
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

    local policy = config.auraProcessingPolicy
    if policy then
        local isProcessAura = policy == CustomAuraContainerAuraProcessingPolicy.ProcessAura
        container:SetAuraProcessingPolicy(policy, isProcessAura and config.processAuraPolicyOptions or nil)
        container.__processAuraPolicy = isProcessAura
    end

    if config.itemEnchantmentSortMethod then
        container:SetItemEnchantmentSortMethod(config.itemEnchantmentSortMethod, config.itemEnchantmentSortDirection or AuraContainerSortDirection.Normal)
    end

    return Mixin(container, ContainerMixin)
end

NRSKNUI:InjectAPI(CreateFrame('Frame'), { CreateAuraContainer = CreateAuraContainer }) -- Inject in all frames so we can call frame:CreateAuraContainer() from anywhere.

---@class NRSKNUI
local NRSKNUI = select(2, ...)

local CreateFrame = CreateFrame
local Mixin = Mixin
local GenerateClosure = GenerateClosure

--[[

Native aura enums/constants (globals provided by Blizzard_AuraContainer):
* AuraButtonBorderStyle
* AuraContainerSortMethod
* AuraContainerSortDirection

--]]

---Convert a growth direction string to the numeric AnchorUtil.FlowDirection the container expects.
---Left/Down map to -1, everything else to 1.
---@param dir string?
---@param negative string the direction keyword that means -1
---@return number
local function GrowthDir(dir, negative)
    return (dir == negative) and -1 or 1
end

--[[

? NRSKNUI:SkinAuraButton(container, options, button)

Shared aura button constructor.
Passed to the native container as `initializeFrame`, called for every aura button created by the container.

Runs inside the container's securecallfunction context, so creating and anchoring regions on the
forbidden button is permitted. We attach regions and hand them to the button's native Set* methods.
Tooltips, mouse handling, and duration text are all driven natively.

* container - the AuraContainer element
* options   - the group/slot options (carries size/font/toggle overrides)
* button    - the native AuraButton

--]]
---@param container table
---@param options table
---@param button table
function NRSKNUI:SkinAuraButton(container, options, button)
    options = options or {}

    local width = options.width or options.size or container.width or container.size or 24
    local height = options.height or options.size or container.height or container.size or width
    button:SetSize(width, height)
    button:EnableMouse(not (options.disableMouse or container.disableMouse))
    NRSKNUI:CreateBackdrop(button, nil, 0)

    -- Optional border tint, e.g. weapon-enchant buttons use this to mark themselves.
    local borderColor = options.borderColor or container.borderColor
    if borderColor then
        local enchantBorder = button:CreateTexture(nil, 'OVERLAY')
        enchantBorder:SetTexture('Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\AuraOverlay.png') -- Use our own border texture.
        enchantBorder:SetPixelSnap()
        enchantBorder:SetPixelInside(button)
        enchantBorder:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    end

    -- Icon, trimmed and inset inside the 1px backdrop border.
    local icon = button:CreateTexture(nil, 'ARTWORK')
    icon:SetPixelInside(button, 1, 1)
    icon:SetZoom()
    button.Icon = icon
    button:SetIcon(icon)

    local showSwipe = options.showSwipe or container.showSwipe
    local reverseSwipe = options.reverseSwipe or container.reverseSwipe
    local showEdge = options.showEdge or container.showEdge

    -- Cooldown spiral over the icon.
    local cooldown
    if not (options.disableCooldown or container.disableCooldown) then
        cooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
        if not borderColor then
            cooldown:SetAllPoints(icon)
        else
            cooldown:SetPixelInside(icon, 1, 1)
        end
        cooldown:SetDrawEdge(showEdge)
        cooldown:SetDrawBling(false)
        cooldown:SetDrawSwipe(showSwipe)
        cooldown:SetReverse(reverseSwipe)
        cooldown:SetHideCountdownNumbers(true) -- we render our own duration text
        cooldown:SetSwipeColor(0, 0, 0, 0.7)
        button.Cooldown = cooldown
        button:SetDurationCooldown(cooldown)
    end

    local showCount = options.showCount
    if showCount == nil then showCount = container.showCount end
    local showDuration = options.showDuration
    if showDuration == nil then showDuration = container.showDuration end

    -- Text needs to render above the cooldown swipe.
    local textParent = button
    if cooldown and (showCount or showDuration) then
        textParent = CreateFrame('Frame', nil, button)
        textParent:SetAllPoints()
        textParent:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    end

    local fontDB = options.fontDB or container.fontDB
    local fontSize = options.fontSize or container.fontSize or 12
    local fontOutline = options.fontOutline or container.fontOutline

    --TODO: Add DB for positioning of count/duration text.
    if showCount then
        local count = textParent:CreateFontString(nil, 'OVERLAY')
        count:SetFontStyle(fontDB, fontSize, fontOutline, nil, true)
        count:SetJustifyH('RIGHT')
        count:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -1, 1)
        button.Count = count
        button:SetApplicationCount(count)
    end

    if showDuration then
        local time = textParent:CreateFontString(nil, 'OVERLAY')
        time:SetFontStyle(fontDB, fontSize, fontOutline, nil, true)
        time:SetJustifyH('CENTER')
        time:SetPoint('CENTER', button, 'CENTER', 0, 0)
        button.Time = time
        local colorCurve = options.durationColorCurve or container.durationColorCurve
        button:SetDurationText(time, {
            textFormatter = options.durationFormatter or container.durationFormatter or NRSKNUI:GetAuraDurationFormatter(),
            -- textColor carries the curve now, and both of its fields are non-nilable.
            textColor = colorCurve and {
                curve = colorCurve,
                property = Enum.DurationTextBindingProperty.RemainingDuration,
            } or nil,
        })
    end

    -- Dispel-colored border overlay, coloring is handled by the container's native SetAuraBorder method.
    local showBuffBorder = options.showBuffBorder
    if showBuffBorder == nil then showBuffBorder = container.showBuffBorder end
    local showDebuffBorder = options.showDebuffBorder
    if showDebuffBorder == nil then showDebuffBorder = container.showDebuffBorder end

    if showBuffBorder or showDebuffBorder then
        local border = button:CreateTexture(nil, 'OVERLAY')
        border:SetTexture('Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\AuraOverlay.png') -- Use our own border texture.
        border:SetPixelSnap()
        border:SetPixelInside(button)
        button.Border = border
        button:SetAuraBorder(border, {
            style = AuraButtonBorderStyle.Color,
            showIcon = false,
            showWhenHelpful = not not showBuffBorder,
            showWhenHarmful = not not showDebuffBorder,
        })
    end

    local hideTooltipInCombat = options.hideTooltipInCombat
    if hideTooltipInCombat == nil then hideTooltipInCombat = container.hideTooltipInCombat end
    if hideTooltipInCombat then
        button:SetHideTooltipInCombat(true)
    end

    -- Right-click cancelaura.
    local cancelButton = options.cancelButton or container.cancelButton
    if cancelButton then
        button:SetCancelAuraButtons(cancelButton)
    end

    if container.PostCreateButton then
        container:PostCreateButton(button, options)
    end
end

---Pad a group/enchant layout table with the container's element-wide spacing defaults.
---The native flow layout is axis-relative rather than X/Y: elementSpacing/groupSpacing run along
---the primary axis, lineSpacing/groupLineSpacing along the cross axis.
---@param container table
---@param layout table?
---@return table
local function ResolveLayout(container, layout)
    layout = layout or {}

    local vertical = container.__axis == AnchorUtil.FlowLayoutAxis.Vertical
    local spacingPrimary = vertical and (container.spacingY or container.spacing) or (container.spacingX or container.spacing)
    local spacingCross = vertical and (container.spacingX or container.spacing) or (container.spacingY or container.spacing)
    local gapPrimary = vertical and (container.gapY or container.gap) or (container.gapX or container.gap)
    local gapCross = vertical and (container.gapX or container.gap) or (container.gapY or container.gap)

    layout.elementSpacing = layout.elementSpacing or spacingPrimary
    layout.lineSpacing = layout.lineSpacing or spacingCross
    layout.groupSpacing = layout.groupSpacing or gapPrimary
    layout.groupLineSpacing = layout.groupLineSpacing or gapCross

    return layout
end

-- Convenience mixin applied to every container created through frame:CreateAuraContainer.
-- This mirrors oUF's element API so unit-frame and standalone code read the same.
local ContainerMixin = {}

--[[

? container:AddGroup(filter[, options])

Register a group of auras (this can be called multiple times).
Pads options with element-wide defaults and installs the NorskenUI skin as the default button constructor.

* filter  - aura filter string ('HELPFUL', 'HARMFUL', ...)
* options - optional per-group options

Returns the generated group key.
--]]
---@param filter string
---@param options table?
---@return string
function ContainerMixin:AddGroup(filter, options)
    options = options or {}

    options.maxFrameCount = options.maxFrameCount or options.num or self.num

    options.layout = ResolveLayout(self, options.layout)

    options.sortMethod = options.sortMethod or self.sortMethod or AuraContainerSortMethod.ExpirationOnly
    options.sortDirection = options.sortDirection or self.sortDirection or AuraContainerSortDirection.Normal

    if not options.initializeFrame then
        options.initializeFrame = GenerateClosure(NRSKNUI.SkinAuraButton, NRSKNUI, self, options)
    end

    self.__groupIndex = (self.__groupIndex or 0) + 1
    local key = (self:GetDebugName() or 'NRSKNUIAuraContainer') .. 'Group' .. self.__groupIndex
    self:AddAuraGroup(key, filter, options)

    return key
end

--[[

? container:AddFilteredGroup(filterName[, options])

Register a group of auras using a named filter from db.global.AuraFilters (this can be called multiple times).

* filterName - key into db.global.AuraFilters (may be nil)
* options    - optional per-group options (candidateFilters is filled in from the filter)

Returns the generated group key.
--]]
---@param filterName string?
---@param options table?
---@return string
function ContainerMixin:AddFilteredGroup(filterName, options)
    options = options or {}

    local filterString, candidateFilters = NRSKNUI:GetAuraFilter(filterName)
    options.candidateFilters = candidateFilters

    local key = self:AddGroup(filterString or 'HARMFUL', options)

    self.__filterBindings = self.__filterBindings or {}
    self.__filterBindings[key] = filterName

    return key
end

--[[

? container:ReapplyFilters()

Reapply the filter strings for every group registered through :AddFilteredGroup.

--]]
---@return boolean applied true if every binding was fully applied live
function ContainerMixin:ReapplyFilters()
    if not self.__filterBindings then return true end

    local applied = true
    for key, filterName in pairs(self.__filterBindings) do
        local filterString, candidateFilters = NRSKNUI:GetAuraFilter(filterName)

        if self.SetAuraGroupFilterString then
            self:SetAuraGroupFilterString(key, filterString or 'HARMFUL')
        else
            applied = false -- parse-string change (e.g. token edit) needs a rebuild on this client
        end

        self:SetAuraGroupCandidateFilters(key, candidateFilters)
    end
    return applied
end

--[[

? container:AddSlot(filter[, options])

Register a single-aura slot (this can be called multiple times).

* filter  - aura filter string
* options - optional per-slot options

Returns the created slot frame.

--]]
---@param filter string
---@param options table?
---@return table? slot
function ContainerMixin:AddSlot(filter, options)
    options = options or {}

    options.sortMethod = options.sortMethod or self.sortMethod or AuraContainerSortMethod.ExpirationOnly
    options.sortDirection = options.sortDirection or self.sortDirection or AuraContainerSortDirection.Normal

    if not options.initializeFrame then
        options.initializeFrame = GenerateClosure(NRSKNUI.SkinAuraButton, NRSKNUI, self, options)
    end

    self.__slotIndex = (self.__slotIndex or 0) + 1
    local key = (self:GetDebugName() or 'NRSKNUIAuraContainer') .. 'Slot' .. self.__slotIndex
    return self:AddAuraSlot(key, filter, options)
end

--[[

? container:AddItemEnchant(slot[, options])

Register a temporary weapon-enchant frame (main/off-hand).
Uses the shared skin, marked with a purple border by default.

* slot    - AuraContainerItemEnchantmentSlot value (MainHand / OffHand / Ranged)
* options - optional per-frame options

Returns the created enchant frame.

--]]
---@param slot number
---@param options table?
---@return table? enchant
function ContainerMixin:AddItemEnchant(slot, options)
    options = options or {}

    if options.borderColor == nil then
        options.borderColor = { 0.6, 0, 1 } -- purple marks a weapon enchant
    end

    if not options.initializeFrame then
        options.initializeFrame = GenerateClosure(NRSKNUI.SkinAuraButton, NRSKNUI, self, options)
    end

    return self:AddItemEnchantment(slot, options)
end

--[[

? container:SetItemEnchantLayout([options])

Set the flow layout for the item-enchant group, padded with the container's spacing defaults.

* options - optional layout overrides (.placement, .elementSpacing, .groupSpacing, .layoutIndex, ...)

--]]
---@param options table?
function ContainerMixin:SetItemEnchantLayout(options)
    self:SetItemEnchantmentLayout(ResolveLayout(self, options))
end

--[[

? frame:CreateAuraContainer([config])

Create a native aura container parented to this frame and return it with the NorskenUI convenience API (:AddGroup / :AddSlot) mixed in.

Aura containers cannot be created in combat, so callers must invoke this out of combat so we wrap in NRSKNUI:RunWhenSafe.
Drive it by calling container:SetUnit(unit), once a group/slot exists the container self-registers for UNIT_AURA and updates itself.

* config
*   .axis          - AnchorUtil.FlowLayoutAxis; defaults to Horizontal (rows) (number?)
*   .maxWidth      - wrap size along the primary axis (width on Horizontal, height on Vertical); defaults to infinite (number?)
*   .initialAnchor - layout anchor point; defaults to 'TOPLEFT' (string?)
*   .growthX       - 'LEFT' or 'RIGHT' (default RIGHT)
*   .growthY       - 'UP' or 'DOWN' (default UP)
*   .padding / .paddingLeft/Right/Top/Bottom - layout padding (number?)
*   .size/.width/.height, .spacing/.spacingX/.spacingY, .gap/.gapX/.gapY, .num - button/layout defaults
*   .enchantPlacement - CustomAuraContainerItemEnchantmentPlacement (Before/AfterAuraGroups) (number?)
*   .showCount/.showDuration/.showBuffBorder/.showDebuffBorder - default button widget toggles
*   .fontDB/.fontSize/.fontOutline - default button font

--]]
---@param config table?
---@return table? container
local function CreateAuraContainer(self, config)
    config = config or {}

    local pad = config.padding or 0
    local container = CreateFrame('AuraContainer', nil, self, 'CustomAuraContainerTemplate')

    container.__axis = config.axis or AnchorUtil.FlowLayoutAxis.Horizontal
    container:SetFlowLayoutAxis(container.__axis)
    container:SetFlowLayoutAnchorPoint(config.initialAnchor or 'TOPLEFT')
    container:SetFlowLayoutGrowthDirection(GrowthDir(config.growthX, 'LEFT'), GrowthDir(config.growthY, 'DOWN'))
    container:SetFlowLayoutPadding(config.paddingLeft or pad, config.paddingRight or pad, config.paddingTop or pad, config.paddingBottom or pad)
    container:SetFlowLayoutMaximumLineSize(config.maxWidth) -- nil means unbounded

    -- Carry element-wide skin/layout defaults so AddGroup/AddSlot and the skin can read them.
    container.size = config.size
    container.width = config.width
    container.height = config.height
    container.spacing = config.spacing
    container.spacingX = config.spacingX
    container.spacingY = config.spacingY
    container.gap = config.gap
    container.gapX = config.gapX
    container.gapY = config.gapY
    container.num = config.num
    container.showCount = config.showCount
    container.showDuration = config.showDuration
    container.showSwipe = config.showSwipe
    container.reverseSwipe = config.reverseSwipe
    container.showEdge = config.showEdge
    container.showBuffBorder = config.showBuffBorder
    container.showDebuffBorder = config.showDebuffBorder
    container.disableCooldown = config.disableCooldown
    container.disableMouse = config.disableMouse
    container.cancelButton = config.cancelButton
    container.durationFormatter = config.durationFormatter
    container.durationColorCurve = config.durationColorCurve
    container.fontDB = config.fontDB
    container.fontSize = config.fontSize
    container.fontOutline = config.fontOutline
    container.hideTooltipInCombat = config.hideTooltipInCombat

    return Mixin(container, ContainerMixin)
end

NRSKNUI:InjectAPI(CreateFrame('Frame'), { CreateAuraContainer = CreateAuraContainer }) -- Inject in all frames so we can call frame:CreateAuraContainer() from anywhere.

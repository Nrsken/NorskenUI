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
    NRSKNUI:CreateBackdrop(button)

    -- Optional border tint, e.g. weapon-enchant buttons use this to mark themselves.
    local borderColor = options.borderColor or container.borderColor
    if borderColor then
        button:SetBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    end

    -- Icon, trimmed and inset inside the 1px backdrop border.
    local icon = button:CreateTexture(nil, 'ARTWORK')
    icon:SetPixelInside(button, 2, 2)
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
        cooldown:SetAllPoints(icon)
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
        button:SetDurationText(time, {
            formatter = options.durationFormatter or container.durationFormatter or NRSKNUI:GetAuraDurationFormatter(),
            textColorCurve = options.durationColorCurve or container.durationColorCurve,
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
        border:SetPixelInside(button)
        button.Border = border
        button:SetAuraBorder(border, {
            style = AuraButtonBorderStyle.Color,
            showIcon = false,
            showWhenHelpful = not not showBuffBorder,
            showWhenHarmful = not not showDebuffBorder,
        })
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

    local layout = options.layout or {}
    layout.elementSpacingX = layout.elementSpacingX or self.spacingX or self.spacing
    layout.elementSpacingY = layout.elementSpacingY or self.spacingY or self.spacing
    layout.gapX = layout.gapX or self.gapX or self.gap
    layout.gapY = layout.gapY or self.gapY or self.gap
    options.layout = layout

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

? container:AddSlot(filter[, options])

Register a single-aura slot (this can be called multiple times).

* filter  - aura filter string
* options - optional per-slot options

Returns the created slot frame.

--]]
---@param filter string
---@param options table?
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

? frame:CreateAuraContainer([config])

Create a native aura container parented to this frame and return it with the NorskenUI convenience API (:AddGroup / :AddSlot) mixed in.

Aura containers cannot be created in combat, so callers must invoke this out of combat so we wrap in NRSKNUI:RunWhenSafe.
Drive it by calling container:SetUnit(unit), once a group/slot exists the container self-registers for UNIT_AURA and updates itself.

* config
*   .maxWidth      - row wrap width; defaults to infinite (number?)
*   .initialAnchor - layout anchor point; defaults to 'TOPLEFT' (string?)
*   .growthX       - 'LEFT' or 'RIGHT' (default RIGHT)
*   .growthY       - 'UP' or 'DOWN' (default UP)
*   .padding / .paddingLeft/Right/Top/Bottom - layout padding (number?)
*   .size/.width/.height, .spacing/.spacingX/.spacingY, .gap/.gapX/.gapY, .num - button/layout defaults
*   .showCount/.showDuration/.showBuffBorder/.showDebuffBorder - default button widget toggles
*   .fontDB/.fontSize/.fontOutline - default button font

--]]
---@param config table?
---@return table? container
local function CreateAuraContainer(self, config)
    config = config or {}

    local pad = config.padding or 0
    local container = CreateFrame('AuraContainer', nil, self, 'CustomAuraContainerTemplate')

    container:SetAuraLayoutRowWidth(config.maxWidth)
    container:SetAuraLayoutAnchorPoint(config.initialAnchor or 'TOPLEFT')
    container:SetAuraLayoutGrowthDirection(GrowthDir(config.growthX, 'LEFT'), GrowthDir(config.growthY, 'DOWN'))
    container:SetAuraLayoutPadding(config.paddingLeft or pad, config.paddingRight or pad, config.paddingTop or pad, config.paddingBottom or pad)

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

    return Mixin(container, ContainerMixin)
end

NRSKNUI:InjectAPI(CreateFrame('Frame'), { CreateAuraContainer = CreateAuraContainer }) -- Inject in all frames so we can call frame:CreateAuraContainer() from anywhere.

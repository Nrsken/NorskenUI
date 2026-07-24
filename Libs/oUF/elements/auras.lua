--[[
# Element: Auras

Handles creation of [aura containers](https://warcraft.wiki.gg/wiki/UIOBJECT_AuraContainer), groups,
slots, and [buttons](https://warcraft.wiki.gg/wiki/UIOBJECT_AuraButton).

## Notes

This is not a traditional element; similar to Tags it only exposes meta functions.

The options detailed below are attributes on the element returned from the meta function, see each
method documented further down for additional options. These options are shared across all buttons,
groups and slots for each element.

## Options (for buttons)

> Note: these options can be set on either the element or within the options table for groups and slots

.size                   - Aura button size. Defaults to 16 (number?)
.width                  - Aura button width. Takes priority over `size` (number?)
.height                 - Aura button height. Takes priority over `size` (number?)
.showBuffBorder         - Show dispel border texture when it's a buff (boolean?)
.showDebuffBorder       - Show dispel border texture when it's a debuff (boolean?)
.showDefaultBorder      - Whether to show the border even when there's no dispel type (boolean?)
.showBorderIcon         - Show dispel type icon on the border texture. Not applicable if the border style is not Atlas (boolean?)
.borderStyle            - Which style to use for the border, one of Enum.CustomAuraButtonBorderStyle (number?)
.showCount              - Show Count fontstring representing aura applications (boolean?)
.countFormatter         - Formatter used to adjust the text displayed on the Count fontstring ([NumericFormatter](https://warcraft.wiki.gg/wiki/ScriptObject_NumericFormatter)?)
.showDuration           - Show Duration fontstring representing time remaining of the aura (boolean?)
.durationFormatter      - Formatter used to adjust the text displayed on the Duration fontstring ([NumericFormatter](https://warcraft.wiki.gg/wiki/ScriptObject_NumericFormatter)?)
.durationFormat         - Plain text format for the text displayed on the Duration fontstring. `durationFormatter` takes presedence (string?)
.durationColorCurve     - Curve used to color the text displayed on the Duration fontstring ([ColorCurve](https://warcraft.wiki.gg/wiki/ScriptObject_ColorCurveObject)?)
.durationModifier       - Duration binding time modifier ([Enum.DurationTimeModifer](https://warcraft.wiki.gg/wiki/Enum.DurationTimeModifier)?)
.durationUpdateInterval - Interval of updates for the text displayed on the Duration fontstring (number?)
.durationExpiredText    - Text used on the Duration fontstring when it has expired. Defaults to an empty string (string?)
.durationZeroText       - Text used on the Duration fontstring when it has no duration. Defaults to an empty string (string?)
.disableMouse           - Disables mouse events (boolean?)
.disableCooldown        - Disables the provided cooldown spiral frame (boolean?)
.cancelButton           - A list of mouse buttons and actions used to cancel the aura, if possible ([string](https://warcraft.wiki.gg/wiki/API_Button_RegisterForClicks)?)

## Options (for groups and slots)

> Note: these options must be set within the options table for groups or slots

.spacing  - Spacing between each button. Defaults to 0 (number)
.spacingX - Horizontal spacing between each button. Takes priority over `spacing` (number)
.spacingY - Vertical spacing between each button. Takes priority over `spacing` (number)

## Options (for groups only)

> Note: these options must be set within the options table for groups

.num  - Number of auras to display. Defaults to an infinite number (number)
.gap  - Gap between each aura group. Defaults to 0 (number)
.gapX - Horizontal gap between each button. Takes priority over `gap` (number)
.gapY - Vertical gap between each button. Takes priority over `gap` (number)

## Options (for slots only)

> Note: these options must be set within the options table for slots

.maxCols - Maximum number of aura button columns before wrapping to a new row. Defaults to element width divided by aura button size (number)

## Examples

  -- Initialize
  local Container = self:CreateAura()
  Container.num = 10 -- per-group option

  -- Position and size
  Container:SetPoint('TOP', self, 'BOTTOM')

  -- Enable some sub-widgets
  Container.showCount = true
  Container.showBuffBorder = true

  -- Register a group using a filter and some options
  Container:AddGroup('HELPFUL', {
    maxFrameCount = 20, -- overrides Container.num
    initializeFrame = PostCreateAuraButton, -- overrides CreateButton override
    showDebuffBorder = true, -- group-specific option for its buttons
  })

  -- Register another group using a different filter and no options
  Container:AddGroup('HARMFUL')

  -- Register a slot with a filter to only include Mark of the Wild
  Container:AddSlot('HELPFUL', {
    candidateFilters = {
      includeSpellIDs = {
        [1126] = true,
      }
    }
  })

--]]
local _, ns = ...
local oUF = ns.oUF

local Private = oUF.Private
local argcheck = Private.argcheck
local GetOrCreateAuraContainer = Private.GetOrCreateAuraContainer

local STATE = {}

local function SetSlotPosition(element, button, options)
	local width = options.width or options.size or element.width or element.size or 16
	local height = options.height or options.size or element.height or element.size or 16
	local sizeX = width + (options.spacingX or options.spacing or element.spacingX or element.spacing or 0)
	local sizeY = height + (options.spacingY or options.spacing or element.spacingY or element.spacing or 0)
	local anchor = options.initialAnchor or element.initialAnchor or 'TOPLEFT'
	local growthX = (options.growthX or element.growthX == 'LEFT' and -1) or 1
	local growthY = (options.growthY or element.growthY == 'DOWN' and -1) or 1
	local cols = options.maxCols or element.maxCols or math.floor(element:GetAuraLayoutRowWidth() / sizeX + 0.5)

	local col = (options.slotIndex - 1) % cols
	local row = math.floor((options.slotIndex - 1) / cols)

	button:ClearAllPoints()
	button:SetPoint(anchor, element, anchor, col * sizeX * growthX, row * sizeY * growthY)
end

local function CreateButton(element, options, button)
	local width = options.width or options.size or element.width or element.size or 16
	local height = options.height or options.size or element.height or element.size or 16
	button:SetSize(width, height)
	button:EnableMouse(not (options.disableMouse or element.disableMouse))

	if(not (options.disableCooldown or element.disableCooldown)) then
		local cd = CreateFrame('Cooldown', '$parentCooldown', button, 'CooldownFrameTemplate')
		cd:SetAllPoints()
		button.Cooldown = cd
		button:SetDurationCooldown(cd)
	end

	local icon = button:CreateTexture(nil, 'BORDER')
	icon:SetAllPoints()
	button.Icon = icon
	button:SetIcon(icon)

	local textParent
	if((options.showCount or element.showCount) or (options.showDuration or element.showDuration)) then
		if(options.disableCooldown or element.disableCooldown) then
			textParent = button
		else
			-- raise frame level to render text above cooldown
			textParent = CreateFrame('Frame', nil, button)
			textParent:SetAllPoints()
			textParent:SetFrameLevel(button.Cooldown:GetFrameLevel() + 1)
		end
	end

	if(options.showCount or element.showCount) then
		local count = textParent:CreateFontString(nil, 'OVERLAY', 'NumberFontNormal')
		count:SetPoint('BOTTOMRIGHT', -1, 0)
		button.Count = count
		button:SetApplicationCount(count, {
			formatter = options.countFormatter or element.countFormatter,
		})
	end

	if((options.showBuffBorder or element.showBuffBorder) or (options.showDebuffBorder or element.showDebuffBorder)) then
		local border = button:CreateTexture(nil, 'OVERLAY')
		border:SetAllPoints()
		button.Border = border
		button:SetAuraBorder(border, {
			style = options.borderStyle or element.borderStyle,
			showIcon = options.showBorderIcon or element.showBorderIcon,
			showWhenHarmful = options.showDebuffBorder or element.showDebuffBorder,
			showWhenHelpful = options.showBuffBorder or element.showBuffBorder,
			showWithoutDispelType = options.showDefaultBorder or element.showDefaultBorder,
			customDispelColorMap = element.__owner.colors.dispel,
		})
	end

	if(options.showDuration or element.showDuration) then
		local time = textParent:CreateFontString(nil, 'OVERLAY', 'NumberFontNormal')
		time:SetPoint('TOPLEFT', 1, 0) -- TBD
		button.Time = time
		button:SetDurationText(time, {
			formatter = options.durationFormatter or element.durationFormatter,
			textFormat = options.durationFormat or element.durationFormat,
			textColorCurve = options.durationColorCurve or element.durationColorCurve,
			timeModifier = options.durationModifier or element.durationModifier,
			updateInterval = options.durationUpdateInterval or element.durationUpdateInterval,
			expiredText = options.durationExpiredText or element.durationExpiredText or '',
			zeroDurationText = options.durationZeroText or element.durationZeroText or '',
		})
	end

	if(options.cancelButton or element.cancelButton) then
		button:SetCancelAuraButtons(options.cancelButton or element.cancelButton)
	end

	if(options.slotIndex) then
		--[[ Override: Auras:SetSlotPosition(button, options)
		Used to anchor aura slots.  
		Called when new aura buttons have been created.

		* self    - the element used to represent the aura buttons (AuraContainer)
		* button  - the aura button (AuraButton)
		* options - the aura group/slot options passed through to CreateButton (table)
		--]]
		(options.SetSlotPosition or element.SetSlotPosition or SetSlotPosition) (element, button, options)
	end

	--[[ Callback: Auras:PostCreateButton(button)
	Called after a new aura button has been created.

	* self    - the element used to represent the aura buttons (AuraContainer)
	* button  - the aura button (AuraButton)
	* options - the aura group/slot options passed through to CreateButton (table)
	--]]
	if(element.PostCreateButton) then element:PostCreateButton(button, options) end
end

local elementMixin = {}
--[[ Auras: auras:AddGroup(filter[, options])
Defines a group of auras to display on the element.  
This can be defined multiple times.

* filter  - aura filter for this group ([AuraFilter](https://warcraft.wiki.gg/wiki/API_type/AuraFilters))
* options - options for this group (TODO: link to wiki)

## Notes

* Many of the options will fall back to element-wide options unless specified.
* All of the button-specific options can be set in the group options to override the
element-provided values
* The groupKey is an arbitrary string used to identify the aura group after creation, and is derived
from the element's inherited name, suffixed by a growing integer.

## Returns

* groupKey - unique identifier for this specific aura group (string)
--]]
function elementMixin:AddGroup(filter, options)
	argcheck(filter, 2, 'string')
	argcheck(options, 3, 'table', 'nil')

	-- we use this to pad the options provided (if any) with familiar defaults from
	-- element attributes like we've been doing for years.
	if(not options) then
		options = {}
	end

	-- default num to nil to get blizz defaults (math.huge)
	options.maxFrameCount = options.maxFrameCount or options.num or self.num

	-- layout attributes inherited from the element
	local layout = options.layout or {}
	layout.elementSpacingX = layout.elementSpacingX or self.spacingX or self.spacing
	layout.elementSpacingY = layout.elementSpacingY or self.spacingY or self.spacing
	layout.gapX = layout.gapX or self.gapX or self.gap
	layout.gapY = layout.gapY or self.gapY or self.gap
	options.layout = layout

	-- some nice shorthands for stuff that might be shared across groups, with more familiar defaults
	options.sortMethod = options.sortMethod or self.sortMethod or AuraContainerSortMethod.ExpirationOnly
	options.sortDirection = options.sortDirection or self.sortDirection or AuraContainerSortDirection.Normal

	if(not options.initializeFrame) then
		-- we want to provide a default set of widgets for buttons, and we load it late so we can
		-- pass group-specific options to it

		--[[ Override: Auras:CreateButton(options, button)
		Used to initialize an aura button.

		* self    - the element used to represent the aura buttons (AuraContainer)
		* options - options passed through from auras:AddGroup and auras:AddSlot
		* button  - the aura button (AuraButton)
		--]]
		options.initializeFrame = GenerateClosure(self.CreateButton or CreateButton, self, options)
	end

	-- keep track of how many groups we've created, for key generation purposes
	local frame = self.__owner
	local index = (STATE[frame].groupIndex or 0) + 1
	STATE[frame].groupIndex = index

	local key = 'Group' .. index
	STATE[frame].containerGroups[self][key] = filter -- TODO: need to hook the method too
	self:AddAuraGroup(key, filter, options)

	return key
end

--[[ Auras: auras:AddSlot(filter[, options])
Defines a slot for a single buff or debuff to create from the element.  
The slot can be manually positioned if necessary.  
This can be defined multiple times.

* filter  - aura filter for this group ([AuraFilter](https://warcraft.wiki.gg/wiki/API_type/AuraFilters))
* options - options for this group (TODO: link to wiki)

## Notes

* Many of the options will fall back to element-wide options unless specified.
* All of the button-specific options can be set in the group options to override the
element-provided values
* Slots will be automatically positioned with each other, this can be overridden with ClearAllPoints
and SetPoint.
* The slotKey is an arbitrary string used to identify the aura slot after creation, and is derived
from the element's inherited name, suffixed by a growing integer.

## Returns

* slotKey - unique identifier for this specific aura slot (string)
--]]
function elementMixin:AddSlot(filter, options)
	argcheck(filter, 2, 'string')
	argcheck(options, 3, 'table', 'nil')

	-- we use this to pad the options provided (if any) with familiar defaults from
	-- element attributes like we've been doing for years.
	if(not options) then
		options = {}
	end

	if(not options.initializeFrame) then
		-- we want to provide a default set of widgets for buttons
		options.initializeFrame = GenerateClosure(self.CreateButton or CreateButton, self, options)
	end

	-- keep track of how many groups we've created, for key generation purposes
	local frame = self.__owner
	local index = (STATE[frame].slotIndex or 0) + 1
	STATE[frame].slotIndex = index

	-- need to inject index into options so we can position the slot on creation
	options.slotIndex = index

	local key = 'Slot' .. index
	STATE[frame].containerSlots[self][key] = filter -- TODO: need to hook the method too
	self:AddAuraSlot(key, filter, options)

	return key
end

--[[ Auras: auras:ForceUpdate()
Forcefully update all auras within groups and slots on the element.
--]]
function elementMixin:ForceUpdate()
	self:UpdateAllAuras()
end

local function hookFilterChange(tbl, container, key, filter)
	if filter ~= 'HELPFUL|HARMFUL' then -- noone should need to do this
		STATE[container.__owner][tbl][container][key] = filter
	end
end

--[[ Auras: frame:CreateAuras([options])
Create and return a aura element.

* self     - the unit frame on which to create the element
* options  - extra options to provide to the element

## Options

All of these options are provided as a convenience, and can be applied after creation through
methods on the element.

.maxWidth      - Max width of the element. Defaults to the parent's width (number?)
.initialAnchor - Anchor point for the element. Defaults to 'TOPLEFT' (string?)
.growthX       - Horizontal growth direction. Defaults to 'RIGHT' (string?)
.growthY       - Vertical growth direction. Defaults to 'UP' (string?)
.padding       - Padding around the element. Defaults to 0 (number?)
.paddingLeft   - Padding on the left side of the element. Takes priority over `padding` (number?)
.paddingRight  - Padding on the right side of the element. Takes priority over `padding` (number?)
.paddingTop    - Padding on the top side of the element. Takes priority over `padding` (number?)
.paddingBottom - Padding on the bottom side of the element. Takes priority over `padding` (number?)
.policies      - Policy for how auras should be processed by the container. See CustomAuraContainerProcessAuraPolicyDefaultOptions (table?)

## Returns

* auras - the element used to represent the aura buttons (AuraContainer)
--]]
local function Create(self, options)
	local element = GetOrCreateAuraContainer(self)
	if(not element) then
		return
	end

	element.__owner = self

	-- keep a local state of each container created for each frame
	if(not STATE[self]) then
		STATE[self] = {
			-- we need to keep track of containers in order for UAE to update them
			containers = {},
			-- we also need to keep track of each individual group and slot for each container
			containerGroups = {},
			containerSlots = {},
		}
	end

	-- inject this container into the state table
	table.insert(STATE[self].containers, element)

	-- inject this container into each group/slot state table
	STATE[self].containerGroups[element] = {}
	STATE[self].containerSlots[element] = {}

	-- hook filter methods so we can keep the aformentioned tables updated with the current filters
	hooksecurefunc(element, 'SetAuraGroupFilterString', GenerateClosure(hookFilterChange, 'containerGroups'))
	hooksecurefunc(element, 'SetAuraSlotFilterString', GenerateClosure(hookFilterChange, 'containerSlots'))

	-- element-wide options we'll just set directly from options
	element:SetAuraLayoutRowWidth(options.maxWidth or self:GetWidth())
	element:SetAuraLayoutAnchorPoint(options.initialAnchor or 'TOPLEFT')

	local growthX = (options.growthX == 'LEFT' and -1) or 1
	local growthY = (options.growthY == 'DOWN' and -1) or 1
	element:SetAuraLayoutGrowthDirection(growthX, growthY)

	local paddingLeft = options.paddingLeft or options.padding or 0
	local paddingRight = options.paddingRight or options.padding or 0
	local paddingTop = options.paddingTop or options.padding or 0
	local paddingBottom = options.paddingBottom or options.padding or 0
	element:SetAuraLayoutPadding(paddingLeft, paddingRight, paddingTop, paddingBottom)

	if(options.policies) then
		-- just expose it easily for layouts in case they want to use it
		element:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.ProcessAura, options.policies)
	end

	return Mixin(element, elementMixin)
end

local function Update(self)
	if(STATE[self] and STATE[self].containers) then
		for _, container in next, STATE[self].containers do
			if container:GetUnit() ~= self.unit then
				container:SetUnit(self.unit) -- triggers a full update
			else
				container:ForceUpdate()
			end
		end
	end
end

local function Enable(self)
	if(STATE[self] and STATE[self].containers) then
		for _, container in next, STATE[self].containers do
			-- when enabling a container we have to also reset the filters for each group and slot
			-- to their last known state
			for groupKey, filter in next, STATE[self].containerGroups[container] do
				container:SetAuraGroupFilterString(groupKey, filter)
			end

			for slotKey, filter in next, STATE[self].containerSlots[container] do
				container:SetAuraSlotFilterString(slotKey, filter)
			end

			container:SetEnabled(true) -- triggers a full update
		end
	end

	return true
end

local function Disable(self)
	if(STATE[self] and STATE[self].containers) then
		for _, container in next, STATE[self].containers do
			container:SetEnabled(false)

			-- disabling a container does not "reset" the groups and slots within, so we have to
			-- temporarily disable them ourselves. there are however no methods to simply disable groups
			-- and slots. the best workaround is to set invalid/conflicting filters that would always
			-- result in no aura buttons

			for groupKey in next, STATE[self].containerGroups[container] do
				container:SetAuraGroupFilterString(groupKey, 'HELPFUL|HARMFUL')
			end

			for slotKey in next, STATE[self].containerSlots[container] do
				container:SetAuraSlotFilterString(slotKey, 'HELPFUL|HARMFUL')
			end
		end
	end
end

oUF:AddMetaElement('Auras', Create, Update, Enable, Disable)

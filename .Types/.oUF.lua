---@meta

-- Annotations for the embedded oUF unit frame framework (Libs/oUF).
-- The addon sets `## X-oUF: NorskenUF`, so the framework is reachable both as the
-- global `NorskenUF` and as `NRSKNUI.oUF` (see Core/Init.lua). `NorskenUF` is the
-- global oUF object; `oUF.UnitFrame` is the object passed as `self` to style functions.

-- Global object --

---@class NorskenUF : oUF
---@field version string oUF version string
---@field objects oUF.UnitFrame[] All unit frames created by `:Spawn`
---@field headers oUF.Header[] All group headers created by `:SpawnHeader`
---@field colors oUF.Colors Shared color table (also copied onto every frame as `.colors`)
---@field Tags oUF.Tags The tag system tables (Methods/Events/Vars/SharedEvents)
---@field Enum oUF.Enum oUF-provided enums (DispelType, SelectionType)
---@field Private table Internal helpers; not intended for layouts

---@class oUF
local oUF

--- Register a style with oUF. Also sets the active style if none is set yet.
---@param name string Name of the style
---@param func fun(self: oUF.UnitFrame, unit: string, isSingle: boolean)|table Style function(s)
function oUF:RegisterStyle(name, func) end

--- Set the active style used by subsequent `:Spawn`/`:SpawnHeader` calls.
---@param name string Name of a registered style
function oUF:SetActiveStyle(name) end

--- Get the currently active style name.
---@return string
function oUF:GetActiveStyle() end

--- Returns an iterator over all registered styles.
---@return fun(_, n: string?): string?
function oUF.IterateStyles() end

--- Add a function to be run on every unit frame/header initialization.
---@param func fun(object: oUF.UnitFrame)
function oUF:RegisterInitCallback(func) end

--- Make a function (or table of functions) available on all unit frames.
---@param name string Unique name of the function
---@param func function|table<string, function>
function oUF:RegisterMetaFunction(name, func) end

--- Register a new element with oUF.
---@param name string Unique element name
---@param update? fun(self: oUF.UnitFrame, event: string, unit: string) Update function
---@param enable fun(self: oUF.UnitFrame, unit: string): boolean? Enable function
---@param disable fun(self: oUF.UnitFrame, unit: string) Disable function
function oUF:AddElement(name, update, enable, disable) end

--- Create a single unit frame and apply the active style.
---@param unit string The frame's unit token
---@param overrideName? string Global name override
---@return oUF.UnitFrame
function oUF:Spawn(unit, overrideName) end

--- Create a group header and apply the active style.
---@param overrideName? string Global name override
---@param template? string Header template. Defaults to `'SecureGroupHeaderTemplate'`
---@param ... any Attribute name/value pairs, or a single associative table
---@return oUF.Header
function oUF:SpawnHeader(overrideName, template, ...) end

--- Create nameplates and apply the active style.
---@param namePrefix? string Prefix for nameplate global names
---@return oUF.NamePlateDriver
function oUF:SpawnNamePlates(namePrefix) end

--- Disable and hide the default Blizzard unit frame(s) for the given unit.
---@param unit string
function oUF:DisableBlizzard(unit) end

--- Create a ColorMixin-based object extended with atlas/curve helpers.
--- RGB values may be normalized (0-1) or bytes (0-255).
---@param r number
---@param g number
---@param b number
---@param a? number
---@return oUF.Color
function oUF:CreateColor(r, g, b, a) end

-- Colors --

--- A ColorMixin-based color object, extended by oUF with atlas and curve support.
---@class oUF.Color : ColorMixin
local color

--- Associate an atlas with the color.
---@param atlas string
function color:SetAtlas(atlas) end

---@return string? atlas
function color:GetAtlas() end

--- Set a color curve from a table of `[position] = ColorMixin` pairs, or from
--- alternating position/color varargs. Pass nothing to clear.
---@param ... table<number, ColorMixin>|number
function color:SetCurve(...) end

---@return any? curve
function color:GetCurve() end

---@class oUF.Colors
---@field health oUF.Color
---@field disconnected oUF.Color
---@field tapped oUF.Color
---@field runes oUF.Color[] Indexed by spec (blood/frost/unholy)
---@field selection table<number, oUF.Color> Keyed by `oUF.Enum.SelectionType`
---@field class table<string, oUF.Color> Keyed by class token
---@field dispel table<number, oUF.Color> Keyed by `oUF.Enum.DispelType`
---@field reaction table<number, oUF.Color> Keyed by reaction index
---@field power table<string|number, oUF.Color|oUF.Color[]> Keyed by power token or id
---@field threat table<number, oUF.Color> Keyed by threat status (0-3)

-- Enums --

---@class oUF.Enum
---@field DispelType table<string, number>
---@field SelectionType table<string, number>

-- Tags --

---@class oUF.Tags
---@field Methods table<string, fun(unit: string, realUnit: string?, ...): any> Tag definitions
---@field Events table<string, string> Space-separated events per tag
---@field SharedEvents table<string, boolean> Events with no unit in their payload
---@field Vars table<string, any> Extra vars exposed to the tag environment
---@field RefreshMethods fun(self: oUF.Tags, tag: string) Recompile tag functions for a tag
---@field RefreshEvents fun(self: oUF.Tags, tag: string) Re-register events for a tag

---@class _ENV
_ENV = _G._ENV

---@param r number|table
---@param g number|nil
---@param b number|nil
---@return string
function Hex(r, g, b) end

-- Group header --

---@class oUF.Header : Frame
---@field visibility string The current visibility macro conditional
---@field style string The style applied to the header's children
---@field prefix string Name prefix used for the header's children
local header

--- Set the macro conditional(s) that control when the header is shown.
--- Accepts space/comma group tokens (raid40/raid/party/solo...) or `"custom <conditional>"`.
---@param visibility string
function header:SetVisibility(visibility) end

--- Set how many aura containers to pre-create per child (default 3).
---@param numContainers number
function header:SetNumAuraContainers(numContainers) end

-- Nameplate driver --

---@class oUF.NamePlateDriver : Frame
---@field style string
---@field prefix string
local nameplates

--- Callback fired when a nameplate is targeted. Payload: `(nameplate, event, unit)`.
---@param callback? fun(nameplate: oUF.UnitFrame, event: string, unit: string)
function nameplates:SetTargetCallback(callback) end

--- Callback fired when a nameplate is added. Payload: `(nameplate, event, unit)`.
---@param callback? fun(nameplate: oUF.UnitFrame, event: string, unit: string)
function nameplates:SetAddedCallback(callback) end

--- Callback fired when a nameplate is removed. Payload: `(nameplate, event, unit)`.
---@param callback? fun(nameplate: oUF.UnitFrame, event: string, unit: string)
function nameplates:SetRemovedCallback(callback) end

--- Set the size for all nameplates. Height defaults to width. Defaults: 200x30.
---@param width number
---@param height? number
function nameplates:SetSize(width, height) end

--- Toggle interactibility of enemy nameplates (interactible by default).
---@param state boolean
function nameplates:SetEnemyInteractible(state) end

--- Toggle interactibility of friendly nameplates (interactible by default).
---@param state boolean
function nameplates:SetFriendlyInteractible(state) end

--- Set console variables from a key/value table or from name/value varargs.
---@param ... table<string, any>|string
function nameplates:SetCVars(...) end

--- Set how many aura containers to pre-allocate per nameplate (default 3).
---@param numContainers number
function nameplates:SetNumAuraContainers(numContainers) end

-- Unit frame (the `self` passed to style functions) --

---@alias oUF.ToggleWidget oUF.Castbar|oUF.Power|oUF.Health|oUF.RaidTargetIndicator|oUF.LeaderIndicator|oUF.Element|Frame|Texture|StatusBar

---@class oUF.UnitFrame : Button
---@field unit string The frame's unit token
---@field id string? The frame's unit id when part of a header
---@field style string The active style name
---@field colors oUF.Colors Copy of the shared color table
---@field PreUpdate? fun(self: oUF.UnitFrame, event: string) Called before the frame updates
---@field PostUpdate? fun(self: oUF.UnitFrame, event: string) Called after the frame updates
--- Elements (assigned in the style function to enable them)
---@field Health? oUF.Health
---@field Power? oUF.Power
---@field AdditionalPower? oUF.AdditionalPower
---@field AlternativePower? oUF.AlternativePower
---@field Castbar? oUF.Castbar
---@field ClassPower? oUF.ClassPower
---@field Runes? oUF.Runes
---@field Stagger? oUF.Stagger
---@field Totems? oUF.Totems
---@field Portrait? oUF.Portrait
---@field PrivateAuras? oUF.PrivateAuras
---@field Range? oUF.Range
---@field HealthPrediction? oUF.HealthPrediction Deprecated; use Health sub-widgets
---@field PowerPrediction? oUF.PowerPrediction Deprecated; use Power sub-widgets
---@field AssistantIndicator? oUF.AssistantIndicator
---@field CombatIndicator? oUF.CombatIndicator
---@field GroupRoleIndicator? oUF.GroupRoleIndicator
---@field LeaderIndicator? oUF.LeaderIndicator
---@field PhaseIndicator? oUF.PhaseIndicator
---@field PvPIndicator? oUF.PvPIndicator
---@field PvPClassificationIndicator? oUF.PvPClassificationIndicator
---@field QuestIndicator? oUF.QuestIndicator
---@field RaidRoleIndicator? oUF.RaidRoleIndicator
---@field RaidTargetIndicator? oUF.RaidTargetIndicator
---@field ReadyCheckIndicator? oUF.ReadyCheckIndicator
---@field RestingIndicator? oUF.RestingIndicator
---@field ResurrectIndicator? oUF.ResurrectIndicator
---@field SummonIndicator? oUF.SummonIndicator
---@field ThreatIndicator? oUF.ThreatIndicator
---@field Auras? table<string, table> NorskenUI: native aura containers keyed by display name
--- Activate an element for the given unit frame.
---@field EnableElement fun(self: oUF.UnitFrame, name: string, unit?: string)
--- Deactivate an element for the given unit frame.
---@field DisableElement fun(self: oUF.UnitFrame, name: string, unit?: string)
--- Check if an element is enabled on the frame.
---@field IsElementEnabled fun(self: oUF.UnitFrame, name: string): boolean?
--- Toggle visibility based on unit existence (wraps RegisterUnitWatch).
---@field Enable fun(self: oUF.UnitFrame, asState?: boolean)
--- UnregisterUnitWatch and hide the frame.
---@field Disable fun(self: oUF.UnitFrame)
--- Whether the frame is registered with the unit existence monitor.
---@field IsEnabled fun(self: oUF.UnitFrame): boolean
--- Update all enabled elements on the frame.
---@field UpdateAllElements fun(self: oUF.UnitFrame, event: string)
--- Register the frame for a game event and add a handler. Multiple handlers per
--- event are supported. OnUpdate-polled frames cannot register events.
---@field RegisterEvent fun(self: oUF.UnitFrame, event: string, func: fun(self: oUF.UnitFrame, event: string, ...), unitless?: boolean)
--- Remove a handler for a game event; unregisters the event if it was the last one.
---@field UnregisterEvent fun(self: oUF.UnitFrame, event: string, func?: fun(self: oUF.UnitFrame, event: string, ...))
--- Register a tag string on a font string.
---@field Tag fun(self: oUF.UnitFrame, fs: FontString, ts: string, ...: string)
--- Unregister a tag from a font string.
---@field Untag fun(self: oUF.UnitFrame, fs: FontString)
--- Update all tags registered on the frame.
---@field UpdateTags fun(self: oUF.UnitFrame)
--- Create and return an aura container element.
---@field CreateAuras fun(self: oUF.UnitFrame, options?: oUF.AuraOptions): oUF.AuraContainer
--- Update all aura containers created on the frame.
---@field UpdateAllAuras fun(self: oUF.UnitFrame)
local frame

-- Element base --

---@class oUF.Element
---@field __owner oUF.UnitFrame The parent unit frame
---@field ForceUpdate fun(self) Force an update of the element
---@field Override? fun(self: oUF.UnitFrame, event: string, ...) Completely override the element's update

-- Health --

---@class oUF.Health : StatusBar, oUF.Element
--- Sub-widgets
---@field TempLoss? StatusBar Temporary max-health reduction
---@field HealingAll? StatusBar Incoming heals from all sources
---@field HealingPlayer? StatusBar Incoming heals from the player
---@field HealingOther? StatusBar Incoming heals from others
---@field OverHealIndicator? Texture Incoming healing exceeds configured limits
---@field DamageAbsorb? StatusBar Damage absorbs
---@field OverDamageAbsorbIndicator? Texture Damage absorb exceeds configured limits
---@field HealAbsorb? StatusBar Heal absorbs
---@field OverHealAbsorbIndicator? Texture Heal absorb exceeds configured limits
--- Options
---@field considerSelectionInCombatHostile? boolean Treat selection as hostile while in combat with the player
---@field smoothing? number StatusBar smoothing method (Enum.StatusBarInterpolation)
---@field maximumHealthClampMode? number Enum.UnitMaximumHealthMode
---@field damageAbsorbClampMode? number Enum.UnitDamageAbsorbClampMode
---@field healAbsorbClampMode? number Enum.UnitHealAbsorbClampMode
---@field healAbsorbMode? number Enum.UnitHealAbsorbMode
---@field incomingHealClampMode? number Enum.UnitIncomingHealClampMode
---@field incomingHealOverflow? number Max overflow past the bar end; 1 disables it. Defaults to 1.05
--- Color options (checked in priority order)
---@field colorDisconnected? boolean
---@field colorTapping? boolean
---@field colorThreat? boolean
---@field colorClass? boolean
---@field colorClassNPC? boolean
---@field colorClassPet? boolean
---@field colorSelection? boolean
---@field colorReaction? boolean
---@field colorSmooth? boolean
---@field colorHealth? boolean
--- Callbacks / overrides
---@field PreUpdate? fun(self: oUF.Health, unit: string)
---@field PostUpdate? fun(self: oUF.Health, unit: string, cur: number, max: number, lossPerc: number)
---@field PostUpdateColor? fun(self: oUF.Health, unit: string, color: oUF.Color?)
---@field UpdateColor? fun(self: oUF.UnitFrame, event: string, unit: string)
---@field nuiForeground? StatusBar

-- Power --

---@class oUF.Power : StatusBar, oUF.Element
---@field CostPrediction? StatusBar Spell power cost on top of the Power bar
--- Options
---@field frequentUpdates? boolean Use UNIT_POWER_FREQUENT instead of UNIT_POWER_UPDATE
---@field displayAltPower? boolean Show alternative power when the unit has one
---@field considerSelectionInCombatHostile? boolean
---@field smoothing? number
--- Color options (checked in priority order)
---@field colorDisconnected? boolean
---@field colorTapping? boolean
---@field colorThreat? boolean
---@field colorPower? boolean
---@field colorPowerAtlas? boolean Requires colorPower
---@field colorPowerSmooth? boolean Requires colorPower
---@field colorClass? boolean
---@field colorClassNPC? boolean
---@field colorClassPet? boolean
---@field colorSelection? boolean
---@field colorReaction? boolean
--- Callbacks / overrides
---@field PreUpdate? fun(self: oUF.Power, unit: string)
---@field PostUpdate? fun(self: oUF.Power, unit: string, cur: number, min: number, max: number)
---@field PostUpdateColor? fun(self: oUF.Power, unit: string, color: oUF.Color?, altR: number?, altG: number?, altB: number?)
---@field PreUpdatePrediction? fun(self: oUF.Power, unit: string)
---@field PostUpdatePrediction? fun(self: oUF.Power, unit: string, cost: number)
---@field GetDisplayPower? fun(self: oUF.Power, unit: string): number?, number?
---@field UpdateColor? fun(self: oUF.UnitFrame, event: string, unit: string)
---@field nuiColor? oUF.Color

-- Additional / Alternative power --

---@class oUF.AdditionalPower : StatusBar, oUF.Element
---@field CostPrediction? StatusBar
---@field frequentUpdates? boolean
---@field displayPairs? table
---@field smoothing? number
---@field colorPower? boolean
---@field colorPowerSmooth? boolean Requires colorPower
---@field cur? number
---@field max? number
---@field PreUpdate? fun(self: oUF.AdditionalPower, unit: string)
---@field PostUpdate? fun(self: oUF.AdditionalPower, cur: number, max: number)
---@field PostUpdateColor? fun(self: oUF.AdditionalPower, color: oUF.Color?)

---@class oUF.AlternativePower : StatusBar, oUF.Element
---@field smoothing? number
---@field colorPower? boolean
---@field colorPowerSmooth? boolean Requires colorPower
---@field PreUpdate? fun(self: oUF.AlternativePower)
---@field PostUpdate? fun(self: oUF.AlternativePower, unit: string, cur: number, min: number, max: number)
---@field PostUpdateColor? fun(self: oUF.AlternativePower, unit: string, color: oUF.Color?)
---@field UpdateTooltip? fun(self: oUF.AlternativePower)

-- Castbar --

---@class oUF.Castbar : StatusBar, oUF.Element
--- Sub-widgets
---@field Icon? Texture Spell icon
---@field SafeZone? Texture Latency
---@field Shield? Texture Non-interruptible marker
---@field Spark? Texture Bar edge
---@field Text? FontString Spell name
---@field Time? FontString Spell duration
--- Options
---@field timeToHold? number Seconds to stay visible after a _FAILED/_INTERRUPTED. Defaults to 0
---@field hideTradeSkills? boolean Ignore crafting casts
---@field smoothing? number
--- Attributes (set by the element while a cast is active)
---@field castID? number
---@field casting? boolean
---@field channeling? boolean
---@field empowering? boolean
---@field notInterruptible? boolean
---@field spellID? number
---@field spellName? string
--- Callbacks / overrides
---@field PostCastStart? fun(self: oUF.Castbar, unit: string)
---@field PostCastUpdate? fun(self: oUF.Castbar, unit: string)
---@field PostCastStop? fun(self: oUF.Castbar, unit: string, empowerComplete: boolean?)
---@field PostCastFail? fun(self: oUF.Castbar, unit: string)
---@field PostCastInterrupted? fun(self: oUF.Castbar, unit: string, interruptedBy: string?)
---@field PostCastInterruptible? fun(self: oUF.Castbar, unit: string)
---@field PostUpdatePips? fun(self: oUF.Castbar, stages: number)
---@field ShouldShow? fun(self: oUF.Castbar, unit: string): boolean
---@field CreatePip? fun(self: oUF.Castbar, stage: number): Frame
---@field UpdatePips? fun(self: oUF.Castbar, stages: number)
---@field CustomDelayText? fun(self: oUF.Castbar, duration: number)
---@field CustomTimeText? fun(self: oUF.Castbar, duration: number)

-- ClassPower / Runes / Stagger --

---@class oUF.ClassPower : oUF.Element
---@field [integer] StatusBar
---@field PreUpdate? fun(self: oUF.ClassPower, event: string)
---@field PostUpdate? fun(self: oUF.ClassPower, cur: number, max: number, hasMaxChanged: boolean, powerType: string)
---@field PostUpdateColor? fun(self: oUF.ClassPower, r: number, g: number, b: number)
---@field UpdateColor? fun(self: oUF.UnitFrame, event: string, ...)

---@class oUF.Runes : oUF.Element
---@field [integer] StatusBar
---@field colorSpec? boolean Use `self.colors.runes[specID]` for the bar color
---@field sortOrder? "asc"|"desc" Sort by remaining cooldown
---@field PostUpdate? fun(self: oUF.Runes, runeID: number, start: number, duration: number, runeReady: boolean)
---@field PostUpdateColor? fun(self: oUF.Runes, color: oUF.Color?)
---@field UpdateColor? fun(self: oUF.UnitFrame, event: string, ...)

---@class oUF.Stagger : StatusBar, oUF.Element
---@field smoothing? number
---@field cur? number
---@field max? number
---@field PreUpdate? fun(self: oUF.Stagger)
---@field PostUpdate? fun(self: oUF.Stagger, cur: number, max: number)
---@field PostUpdateColor? fun(self: oUF.Stagger, color: oUF.Color?)

-- Totems --

---@class oUF.Totem : Button
---@field Icon? Texture
---@field Cooldown? Cooldown
---@field UpdateTooltip? fun(self: oUF.Totem)

---@class oUF.Totems : oUF.Element
---@field [integer] oUF.Totem
---@field PreUpdate? fun(self: oUF.Totems, slot: number)
---@field PostUpdate? fun(self: oUF.Totems, slot: number, haveTotem: boolean, name: string, start: number, duration: number, icon: number, durationObj: any)

-- Portrait --

---@class oUF.Portrait : PlayerModel, oUF.Element
---@field showClass? boolean Show the unit's class icon (2D texture portraits)
---@field guid string?
---@field state boolean?
---@field PreUpdate? fun(self: oUF.Portrait, unit: string)
---@field PostUpdate? fun(self: oUF.Portrait, unit: string, hasStateChanged: boolean)

-- Auras --

---@class oUF.AuraOptions
---@field maxWidth? number Max width. Defaults to the parent's width
---@field initialAnchor? string Anchor point. Defaults to 'TOPLEFT'
---@field growthX? "LEFT"|"RIGHT" Horizontal growth. Defaults to 'RIGHT'
---@field growthY? "UP"|"DOWN" Vertical growth. Defaults to 'UP'
---@field padding? number
---@field paddingLeft? number
---@field paddingRight? number
---@field paddingTop? number
---@field paddingBottom? number
---@field policies? table

--- The aura element returned from `frame:CreateAuras`. Configure button-, group- and
--- slot-level options via fields, then register filters with `:AddGroup`/`:AddSlot`.
---@class oUF.AuraContainer : Frame
--- Button options
---@field size? number Defaults to 16
---@field width? number Takes priority over size
---@field height? number Takes priority over size
---@field showBuffBorder? boolean
---@field showDebuffBorder? boolean
---@field showBorderSymbol? boolean
---@field borderStyle? number Enum.CustomAuraButtonDispelTypeTextureStyle (AuraButtonBorderStyle is deprecated in 12.1)
---@field showCount? boolean
---@field countFormatter? any NumericFormatter
---@field showDuration? boolean
---@field durationFormatter? any NumericFormatter
---@field durationFormat? string
---@field durationColorCurve? any ColorCurve
---@field durationModifier? number Enum.DurationTimeModifier
---@field durationUpdateInterval? number
---@field durationExpiredText? string
---@field durationZeroText? string
---@field disableMouse? boolean
---@field disableCooldown? boolean
---@field cancelButton? string
--- Group/slot spacing
---@field spacing? number Defaults to 0
---@field spacingX? number Takes priority over spacing
---@field spacingY? number Takes priority over spacing
--- Group options
---@field num? number Number of auras to display. Defaults to infinite
---@field gap? number
---@field gapX? number
---@field gapY? number
--- Slot options
---@field maxCols? number
--- Overrides
---@field CreateButton? fun(self: oUF.AuraContainer, options: table, button: any)
local auras

--- Define a group of auras to display, using an aura filter.
---@param filter string Aura filter (e.g. 'HELPFUL', 'HARMFUL')
---@param options? table Group options (fall back to element-wide options)
---@return string groupKey Unique identifier for the group
function auras:AddGroup(filter, options) end

--- Define a slot for a single aura, using an aura filter.
---@param filter string Aura filter
---@param options? table Slot options
---@return string slotKey Unique identifier for the slot
function auras:AddSlot(filter, options) end

-- PrivateAuras --

---@class oUF.PrivateAuras : Frame, oUF.Element
---@field disableCooldown? boolean
---@field disableCooldownText? boolean
---@field size? number Defaults to 16
---@field width? number
---@field height? number
---@field spacing? number
---@field spacingX? number
---@field spacingY? number
---@field growthX? "LEFT"|"RIGHT" Defaults to 'RIGHT'
---@field growthY? "UP"|"DOWN" Defaults to 'UP'
---@field initialAnchor? string Defaults to 'BOTTOMLEFT'
---@field num? number Defaults to 6
---@field maxCols? number
---@field borderScale? number
---@field PostCreateAura? fun(self: oUF.PrivateAuras, aura: Frame, auraIndex: number)
---@field CreateAura? fun(self: oUF.PrivateAuras, auraIndex: number): Frame
---@field SetPosition? fun(self: oUF.PrivateAuras, aura: Frame, auraIndex: number)

-- Deprecated prediction elements --

---@class oUF.HealthPrediction : oUF.Element
---@field healingAll? StatusBar
---@field healingPlayer? StatusBar
---@field healingOther? StatusBar
---@field overHealIndicator? Texture
---@field damageAbsorb? StatusBar
---@field overDamageAbsorbIndicator? Texture
---@field healAbsorb? StatusBar
---@field overHealAbsorbIndicator? Texture
---@field damageAbsorbClampMode? number
---@field healAbsorbClampMode? number
---@field healAbsorbMode? number
---@field incomingHealClampMode? number
---@field incomingHealOverflow? number Defaults to 1.05
---@field PostUpdate? fun(self: oUF.HealthPrediction, unit: string, ...)

---@class oUF.PowerPrediction : oUF.Element
---@field mainBar? StatusBar
---@field altBar? StatusBar
---@field PreUpdate? fun(self: oUF.PowerPrediction, unit: string)
---@field PostUpdate? fun(self: oUF.PowerPrediction, unit: string, ...)

-- Range fader --

---@class oUF.Range : oUF.Element
---@field insideAlpha? number Opacity in range. Defaults to 1
---@field outsideAlpha? number Opacity out of range. Defaults to 0.55
---@field PreUpdate? fun(self: oUF.Range)
---@field PostUpdate? fun(self: oUF.Range, object: oUF.UnitFrame, inRange: boolean, isEligible: boolean)

-- Indicators --

---@class oUF.AssistantIndicator : Texture, oUF.Element
---@field PreUpdate? fun(self: oUF.AssistantIndicator)
---@field PostUpdate? fun(self: oUF.AssistantIndicator, isAssistant: boolean)

---@class oUF.CombatIndicator : Texture, oUF.Element
---@field PreUpdate? fun(self: oUF.CombatIndicator)
---@field PostUpdate? fun(self: oUF.CombatIndicator, inCombat: boolean)

---@class oUF.GroupRoleIndicator : Texture, oUF.Element
---@field useAtlasSize? boolean
---@field PreUpdate? fun(self: oUF.GroupRoleIndicator)
---@field PostUpdate? fun(self: oUF.GroupRoleIndicator, role: string)

---@class oUF.LeaderIndicator : Texture, oUF.Element
---@field useAtlasSize? boolean
---@field PreUpdate? fun(self: oUF.LeaderIndicator)
---@field PostUpdate? fun(self: oUF.LeaderIndicator, isLeader: boolean, isInLFGInstance: boolean)

---@class oUF.PhaseIndicator : Frame, oUF.Element
---@field Icon? Texture
---@field reason? number
---@field PreUpdate? fun(self: oUF.PhaseIndicator)
---@field PostUpdate? fun(self: oUF.PhaseIndicator, isInSamePhase: boolean, phaseReason: number?)
---@field UpdateTooltip? fun(self: oUF.PhaseIndicator)

---@class oUF.PvPIndicator : Texture, oUF.Element
---@field Badge? Texture
---@field PreUpdate? fun(self: oUF.PvPIndicator, unit: string)
---@field PostUpdate? fun(self: oUF.PvPIndicator, unit: string, status: string?)

---@class oUF.PvPClassificationIndicator : Texture, oUF.Element
---@field useAtlasSize? boolean
---@field PreUpdate? fun(self: oUF.PvPClassificationIndicator, unit: string)
---@field PostUpdate? fun(self: oUF.PvPClassificationIndicator, unit: string, class: number?)

---@class oUF.QuestIndicator : Texture, oUF.Element
---@field PreUpdate? fun(self: oUF.QuestIndicator)
---@field PostUpdate? fun(self: oUF.QuestIndicator, isQuestBoss: boolean)

---@class oUF.RaidRoleIndicator : Texture, oUF.Element
---@field useAtlasSize? boolean
---@field PreUpdate? fun(self: oUF.RaidRoleIndicator)
---@field PostUpdate? fun(self: oUF.RaidRoleIndicator, role: string?)

---@class oUF.RaidTargetIndicator : Texture, oUF.Element
---@field PreUpdate? fun(self: oUF.RaidTargetIndicator)
---@field PostUpdate? fun(self: oUF.RaidTargetIndicator, index: number?)

---@class oUF.ReadyCheckIndicator : Texture, oUF.Element
---@field finishedTime? number Defaults to 10
---@field fadeTime? number Defaults to 1.5
---@field useAtlasSize? boolean
---@field status? string 'ready'|'notready'|'waiting'
---@field PreUpdate? fun(self: oUF.ReadyCheckIndicator)
---@field PostUpdate? fun(self: oUF.ReadyCheckIndicator, status: string?)
---@field PostUpdateFadeOut? fun(self: oUF.ReadyCheckIndicator)

---@class oUF.RestingIndicator : Texture, oUF.Element
---@field PreUpdate? fun(self: oUF.RestingIndicator)
---@field PostUpdate? fun(self: oUF.RestingIndicator, isResting: boolean)

---@class oUF.ResurrectIndicator : Texture, oUF.Element
---@field PreUpdate? fun(self: oUF.ResurrectIndicator)
---@field PostUpdate? fun(self: oUF.ResurrectIndicator, incomingResurrect: boolean)

---@class oUF.SummonIndicator : Texture, oUF.Element
---@field useAtlasSize? boolean
---@field PreUpdate? fun(self: oUF.SummonIndicator)
---@field PostUpdate? fun(self: oUF.SummonIndicator, status: number)

---@class oUF.ThreatIndicator : Texture, oUF.Element
---@field feedbackUnit? string
---@field PreUpdate? fun(self: oUF.ThreatIndicator, unit: string)
---@field PostUpdate? fun(self: oUF.ThreatIndicator, unit: string, status: number, color: oUF.Color?)

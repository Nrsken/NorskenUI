---@meta

-- Concrete module classes. Methods are defined in each module's own file.

---@class CombatTimer : NRSKNUI.Module, NRSKNUI.AceEvent
---@class Gateway : NRSKNUI.Module, NRSKNUI.AceEvent
---@class PotionReady : NRSKNUI.Module, NRSKNUI.AceEvent
---@class RangeChecker : NRSKNUI.Module, NRSKNUI.AceEvent
---@class Skinning : NRSKNUI.Module, NRSKNUI.AceEvent
---@class Tooltips : NRSKNUI.Module, NRSKNUI.AceEvent
---@class Minimap : NRSKNUI.Module, NRSKNUI.AceEvent
---@class BurningRush : NRSKNUI.Module, NRSKNUI.AceEvent
---@class AuctionHouseFilter : NRSKNUI.Module, NRSKNUI.AceEvent
---@class Automation : NRSKNUI.Module, NRSKNUI.AceEvent, NRSKNUI.AceHook
---@class Tweaks : NRSKNUI.Module, NRSKNUI.AceEvent, NRSKNUI.AceHook

-- Typed accessors. Overloads dispatch on the literal module name.

---@type NRSKNUI
local NRSKNUI

--- Fetch a registered module by name.
---@overload fun(self: NRSKNUI, name: "CombatTimer", silent?: boolean): CombatTimer
---@overload fun(self: NRSKNUI, name: "Gateway", silent?: boolean): Gateway
---@overload fun(self: NRSKNUI, name: "PotionReady", silent?: boolean): PotionReady
---@overload fun(self: NRSKNUI, name: "RangeChecker", silent?: boolean): RangeChecker
---@overload fun(self: NRSKNUI, name: "Skinning", silent?: boolean): Skinning
---@overload fun(self: NRSKNUI, name: "Tooltips", silent?: boolean): Tooltips
---@overload fun(self: NRSKNUI, name: "Minimap", silent?: boolean): Minimap
---@overload fun(self: NRSKNUI, name: "BurningRush", silent?: boolean): BurningRush
---@overload fun(self: NRSKNUI, name: "AuctionHouseFilter", silent?: boolean): AuctionHouseFilter
---@overload fun(self: NRSKNUI, name: "Automation", silent?: boolean): Automation
---@overload fun(self: NRSKNUI, name: "Tweaks", silent?: boolean): Tweaks
---@param name string
---@param silent? boolean
---@return NRSKNUI.Module
function NRSKNUI:GetModule(name, silent) end

--- Register a new module. Trailing args are embedded library names (e.g. "AceEvent-3.0").
---@overload fun(self: NRSKNUI, name: "CombatTimer", ...: string): CombatTimer
---@overload fun(self: NRSKNUI, name: "Gateway", ...: string): Gateway
---@overload fun(self: NRSKNUI, name: "PotionReady", ...: string): PotionReady
---@overload fun(self: NRSKNUI, name: "RangeChecker", ...: string): RangeChecker
---@overload fun(self: NRSKNUI, name: "Skinning", ...: string): Skinning
---@overload fun(self: NRSKNUI, name: "Tooltips", ...: string): Tooltips
---@overload fun(self: NRSKNUI, name: "Minimap", ...: string): Minimap
---@overload fun(self: NRSKNUI, name: "BurningRush", ...: string): BurningRush
---@overload fun(self: NRSKNUI, name: "AuctionHouseFilter", ...: string): AuctionHouseFilter
---@overload fun(self: NRSKNUI, name: "Automation", ...: string): Automation
---@overload fun(self: NRSKNUI, name: "Tweaks", ...: string): Tweaks
---@param name string
---@param ... string
---@return NRSKNUI.Module
function NRSKNUI:NewModule(name, ...) end

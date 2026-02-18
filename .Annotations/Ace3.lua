---@meta

-- Extend the existing AceAddon-3.0 class with missing methods
---@class AceAddon-3.0
-- @param ... — List of libraries to embed into the addon
---@field NewModule fun(self: AceAddon-3.0, name: string, ...: string): AceModule
---@field GetModule fun(self: AceAddon-3.0, name: string, silent?: boolean): AceModule
---@field EnableModule fun(self: AceAddon-3.0, name: string)
---@field DisableModule fun(self: AceAddon-3.0, name: string)
---@field IterateModules fun(self: AceAddon-3.0): fun(): string, AceModule
---@field GetName fun(self: AceAddon-3.0): string
---@field SetDefaultModuleLibraries fun(self: AceAddon-3.0, ...: string)
---@field SetDefaultModuleState fun(self: AceAddon-3.0, state: boolean)
---@field SetDefaultModulePrototype fun(self: AceAddon-3.0, prototype: table)
---@field SetEnabledState fun(self: AceAddon-3.0, state: boolean)
---@field IsEnabled fun(self: AceAddon-3.0): boolean

---@class AceEvent-3.0
---@field RegisterEvent fun(self: any, event: string, callbackOrMethod?: string|function)
---@field UnregisterEvent fun(self: any, event: string)
---@field UnregisterAllEvents fun(self: any)

---@class AceModule: AceAddon-3.0, AceEvent-3.0
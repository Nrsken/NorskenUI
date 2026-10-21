---@meta

---@class NRSKNUI.MySpecData
---@field id number
---@field role string
---@field position string
---@field talents string

---@class NRSKNUI.Libraries
---@field AceDB AceDB-3.0
---@field LSM LibSharedMedia-3.0
---@field LCG LibCustomGlow-1.0
---@field LS LibSpecialization
---@field LRC LibRangeCheck-3.0
---@field AS AceSerializer-3.0
---@field AL table<string, string>
---@field LD LibDeflate
---@field LDB LibDataBroker-1.1
---@field LDBIcon LibDBIcon-1.0
---@field LDS LibDualSpec-1.0
---@field KAJI LibKaji-1.0

---@class LibDualSpec-1.0
---@field currentSpec number 0 until the character has a specialization

---@class NRSKNUI.ModuleBase
---@field SetEnabledState fun(self: NRSKNUI.ModuleBase, state: boolean)
---@field db table
---@field Defaults table? profile defaults; ModulePrototype:OnInitialize registers a namespace for them
---@field dbKey string? the profile key the settings used to sit under, when it isn't the module name
---@field namespace AceDBObject-3.0? the module's own namespace inside NorskenUIDB
---@field IsEnabled fun(self: NRSKNUI.ModuleBase): boolean
---@field SetEnabledState fun(self: NRSKNUI.ModuleBase, state: boolean)

---@class AceModule : NRSKNUI.ModuleBase
---@field ApplySettings fun(self: AceModule)

---@class NRSKNUI.AuraModule
---@field ApplyFilter fun(self: NRSKNUI.AuraModule)
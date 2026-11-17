---@meta

---@class NRSKNUI.MySpecData
---@field id number
---@field role string
---@field position string
---@field talents string

---@class NRSKNUI.Libraries : NorskenCore.Libraries
---@field AceDB AceDB-3.0
---@field LRC LibRangeCheck-3.0
---@field AS AceSerializer-3.0
---@field AL table<string, string>
---@field LD LibDeflate
---@field LDB LibDataBroker-1.1
---@field LDS LibDualSpec-1.0

---@class LibDualSpec-1.0
---@field currentSpec number 0 until the character has a specialization

---@class NRSKNUI.AuraModule
---@field ApplyFilter fun(self: NRSKNUI.AuraModule)

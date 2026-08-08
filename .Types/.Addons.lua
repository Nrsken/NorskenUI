---@meta

---@class HidingBarAddon : Frame, table
---@field addToIgnoreFrameList fun(self: HidingBarAddon, frame: Frame|string)

---@class BugSack : Frame, table
---@field UpdateDisplay fun(self: BugSack)
---@field GetErrors fun(self: BugSack, sessionId: number): table

---@class BugGrabber : Frame, table
---@field GetSessionId fun(self: BugGrabber): number

---One of Details' windows. Instances take the Details table as their metatable.
---@class DetailsInstance : table
---@field row_info table
---@field titlebar_height number
---@field baseframe Frame
---@field GetId fun(self: DetailsInstance): number
---@field IsShown fun(self: DetailsInstance): boolean

---@class DetailsAddon : table
---@field GetInstance fun(self: DetailsAddon, id: number): DetailsInstance?
---@field RegisterEvent fun(self: DetailsAddon, object: table, event: string, func: fun(event: string, instance: DetailsInstance?))

---@class _G
---@field HidingBarAddon HidingBarAddon
---@field BugSack BugSack
---@field BugGrabber BugGrabber
---@field Details DetailsAddon
---@field NorskenUI NRSKNUI
---@field NorskenUF NorskenUF

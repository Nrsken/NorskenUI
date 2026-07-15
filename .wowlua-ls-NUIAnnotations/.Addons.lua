---@meta

---@class HidingBarAddon : Frame, table
---@field addToIgnoreFrameList fun(self: HidingBarAddon, frame: Frame|string)

---@class BugSack : Frame, table
---@field UpdateDisplay fun(self: BugSack)
---@field GetErrors fun(self: BugSack, sessionId: number): table

---@class BugGrabber : Frame, table
---@field GetSessionId fun(self: BugGrabber): number

---@class _G
---@field HidingBarAddon HidingBarAddon
---@field BugSack BugSack
---@field BugGrabber BugGrabber

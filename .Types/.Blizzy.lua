---@meta


---Returns a string with 'prefix' and 'suffix' joined to 'infix' iif 'infix' is not an empty string. Else, an empty string is returned.
---
---[Documentation](https://warcraft.wiki.gg/wiki/API_C_StringUtil.WrapString)
---@param infix stringView|number
---@param prefix? stringView
---@param suffix? stringView
---@return string text
function C_StringUtil.WrapString(infix, prefix, suffix) end


---@class Frame ---@diagnostic disable-line: class-shadows-builtin
local Frame

---Sets the roleset tags for this frame, used by the UI mode system to gate visibility. Supports
---comma-separated names to assign multiple rolesets. Pass nil to clear.
---
---Added in 12.1. The names come from the modes registered in `Blizzard_UIModes`, e.g. `unitFrames`,
---`actionBars`, `buffs`, `statusBars`, `encounterUI`, `microMenu`, `chat`. Protected function.
---@param rolesets string?
function Frame:SetRolesets(rolesets) end

---Returns the roleset tags assigned to this frame. Returns a list containing 'roleless' if none are
---assigned. Unprotected, unlike SetRolesets.
---@return string[] rolesets
function Frame:GetRolesetNames() end

---Returns whether this frame is hidden because of its rolesets being filtered. Unprotected.
---@return boolean isRolesetFiltered
function Frame:IsRolesetFiltered() end

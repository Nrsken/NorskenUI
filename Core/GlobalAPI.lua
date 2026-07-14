---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Global API functions

local IsAddonLoaded = C_AddOns and C_AddOns.IsAddOnLoaded

---Check if ElvUI is loaded use ElvUI skinning is enabled
function NRSKNUI:ShouldNotLoadModule()
    return IsAddonLoaded("ElvUI") and NRSKNUI.db.profile.UseElvUI.Enabled
end

---Check if Blizzard Edit Mode is currently active
function NRSKNUI:IsEditModeActive()
    return EditModeManagerFrame and EditModeManagerFrame:IsShown()
end

---Get justification based on anchor point
---@param anchorPoint string
---@return string
function NRSKNUI:GetJustifyFromAnchor(anchorPoint)
    if not anchorPoint then return "CENTER" end
    if anchorPoint == "RIGHT" or anchorPoint == "TOPRIGHT" or anchorPoint == "BOTTOMRIGHT" then
        return "RIGHT"
    elseif anchorPoint == "LEFT" or anchorPoint == "TOPLEFT" or anchorPoint == "BOTTOMLEFT" then
        return "LEFT"
    end
    return "CENTER"
end

---Check if a specific class is present in the current group.
---@param classFilenameToCheck 'WARRIOR'|'HUNTER'|'ROGUE'|'MAGE'|'PRIEST'|'WARLOCK'|'DRUID'|'SHAMAN'|'PALADIN'|'DEATHKNIGHT'|'MONK'|'DEMONHUNTER'
function NRSKNUI:IsClassInGroup(classFilenameToCheck)
    local numMembers = GetNumGroupMembers()
    local prefix = (IsInRaid() and 'raid') or 'party'
    local maxCheck = (IsInRaid() and numMembers) or (numMembers - 1)
    for i = 1, maxCheck do
        local unit = prefix .. i
        local classFilename = select(2, UnitClass(unit))
        if classFilename == classFilenameToCheck then
            return true
        end
    end
    return false
end

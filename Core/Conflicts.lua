---@class NRSKNUI
local NRSKNUI = _G.NorskenUI

-- other UI addons that own something NorskenUI would otherwise do

local IsAddonLoaded = C_AddOns.IsAddOnLoaded

-- Addons that bring their own oUF copy.
local ConflictingUFAddons = { 'ElvUI', 'UnhaltedUnitFrames', 'EllesmereUIUnitFrames' }

-- Addons that set UIParent's scale themselves.
local ConflictingScaleAddons = { 'ElvUI', 'UnhaltedUnitFrames', 'EllesmereUI' }

---@param addons string[]
---@return string|nil
local function FirstLoaded(addons)
    for i = 1, #addons do
        if IsAddonLoaded(addons[i]) then
            return addons[i]
        end
    end
    return nil
end

---Check if ElvUI is loaded and ElvUI skinning is enabled, so a module should skip its own load.
---@return boolean
function NRSKNUI:ShouldNotLoadModule()
    return IsAddonLoaded('ElvUI') and NRSKNUI.db.profile.UseElvUI.Enabled
end

---Name of the loaded addon that owns the unit frames, if any.
---Only meaningful from PLAYER_LOGIN onwards, addons sorted after us have not loaded before that.
---@return string|nil
function NRSKNUI:GetConflictingUFAddon()
    return FirstLoaded(ConflictingUFAddons)
end

---Name of the loaded addon that owns UIParent's scale, if any. Same timing rule as above.
---@return string|nil
function NRSKNUI:GetConflictingScaleAddon()
    return FirstLoaded(ConflictingScaleAddons)
end

---Check if another UI addon owns the unit frames, so the UnitFrames module must not load at all.
---@return boolean
function NRSKNUI:ShouldNotLoadUF()
    if not self.db.profile.UseOtherUF.Enabled then return false end

    return self:GetConflictingUFAddon() ~= nil
end

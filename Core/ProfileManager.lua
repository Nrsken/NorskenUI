-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- For easy debuging, prints are added for all "failed" attempts, prob unnecessary amount but w/e
-- Module fully documented with annotations for luals checks
-- First iteration and first time i deal with profiles so prob not a perfect module

-- Profile Manager Module
local ProfileManager = {}
NRSKNUI.ProfileManager = ProfileManager

-- Libraries
local AceSerializer = LibStub("AceSerializer-3.0")
local LibDeflate = LibStub("LibDeflate")

-- Constants
local EXPORT_PREFIX = "!NRSKNUI1!"
local DEFAULT_PROFILE = "Default"

-- Localization
local pairs = pairs
local type = type
local time = time
local wipe = wipe
local tostring = tostring

--- Get list of all available profiles
---@return table List of profile names
function ProfileManager:GetProfiles()
    local profiles = {}
    if NRSKNUI.db then NRSKNUI.db:GetProfiles(profiles) end
    return profiles
end

--- Get the current active profile name
---@return string Current profile name
function ProfileManager:GetCurrentProfile()
    if NRSKNUI.db then return NRSKNUI.db:GetCurrentProfile() end
    return DEFAULT_PROFILE
end

--- Switch to a different profile
---@param profileName string The profile name to switch to
---@return boolean success, string|nil error
function ProfileManager:SetProfile(profileName)
    if not profileName or profileName == "" then return false, "Invalid profile name" end
    if not NRSKNUI.db then return false, "Database not initialized" end

    -- SetProfile handles creation if profile doesn't exist
    NRSKNUI.db:SetProfile(profileName)
    self:RefreshAllModules()

    return true
end

--- Create a new profile with default values
---@param profileName string The name for the new profile
---@return boolean success, string|nil error
function ProfileManager:CreateProfile(profileName)
    if not profileName or profileName == "" then return false, "Profile name cannot be empty" end
    if not NRSKNUI.db then return false, "Database not initialized" end

    -- Check if profile with the same name already exists
    local profiles = self:GetProfiles()
    for _, name in pairs(profiles) do
        if name == profileName then
            return false, "Profile '" .. profileName .. "' already exists"
        end
    end

    -- Create by setting to it
    local currentProfile = self:GetCurrentProfile()
    NRSKNUI.db:SetProfile(profileName)

    -- Reset to defaults
    NRSKNUI.db:ResetProfile()

    -- Switch back to original profile
    NRSKNUI.db:SetProfile(currentProfile)

    return true
end

--- Copy settings from one profile to another
---@param sourceProfile string Source profile name
---@param targetProfile string|nil Target profile name (current if nil)
---@return boolean success, string|nil error
function ProfileManager:CopyProfile(sourceProfile, targetProfile)
    if not sourceProfile or sourceProfile == "" then return false, "Source profile name cannot be empty" end
    if not NRSKNUI.db then return false, "Database not initialized" end

    targetProfile = targetProfile or self:GetCurrentProfile()

    -- Check if source profile exists
    local profiles = self:GetProfiles()
    local sourceExists = false
    for _, name in pairs(profiles) do
        if name == sourceProfile then
            sourceExists = true
            break
        end
    end

    if not sourceExists then return false, "Source profile '" .. sourceProfile .. "' does not exist" end

    -- AceDB's CopyProfile copies TO the current profile FROM the source
    local currentProfile = self:GetCurrentProfile()

    -- If target is not current, switch to target first
    if targetProfile ~= currentProfile then NRSKNUI.db:SetProfile(targetProfile) end

    NRSKNUI.db:CopyProfile(sourceProfile)

    -- Switch back if needed
    if targetProfile ~= currentProfile then NRSKNUI.db:SetProfile(currentProfile) end

    self:RefreshAllModules()
    return true
end

--- Delete a profile
---@param profileName string The profile name to delete
---@return boolean success, string|nil error
function ProfileManager:DeleteProfile(profileName)
    if not profileName or profileName == "" then return false, "Profile name cannot be empty" end
    if not NRSKNUI.db then return false, "Database not initialized" end
    -- Cannot delete active profile
    if profileName == self:GetCurrentProfile() then return false, "Cannot delete the active profile" end

    -- Check if profile exists
    local profiles = self:GetProfiles()
    local exists = false
    for _, name in pairs(profiles) do
        if name == profileName then
            exists = true
            break
        end
    end

    -- Check if profile we wnant to delete even exists
    if not exists then return false, "Profile '" .. profileName .. "' does not exist" end

    -- Check if this is the global profile
    if NRSKNUI.db.global and NRSKNUI.db.global.UseGlobalProfile then
        if NRSKNUI.db.global.GlobalProfile == profileName then
            -- Reset global profile to Default
            NRSKNUI.db.global.GlobalProfile = DEFAULT_PROFILE
        end
    end

    NRSKNUI.db:DeleteProfile(profileName)
    return true
end

--- Rename a profile
---@param oldName string Current profile name
---@param newName string New profile name
---@return boolean success, string|nil error
function ProfileManager:RenameProfile(oldName, newName)
    if not oldName or oldName == "" then return false, "Current name cannot be empty" end
    if not newName or newName == "" then return false, "New name cannot be empty" end
    if oldName == newName then return false, "Names are identical" end
    if not NRSKNUI.db then return false, "Database not initialized" end

    -- Check if old profile exists
    local profiles = self:GetProfiles()
    local oldExists = false
    for _, name in pairs(profiles) do
        if name == oldName then
            oldExists = true
        end
        if name == newName then
            return false, "Profile '" .. newName .. "' already exists"
        end
    end

    if not oldExists then return false, "Profile '" .. oldName .. "' does not exist" end

    local isCurrentProfile = (oldName == self:GetCurrentProfile())
    local isGlobalProfile = NRSKNUI.db.global and NRSKNUI.db.global.GlobalProfile == oldName

    -- Create new profile with old profile's data
    NRSKNUI.db:SetProfile(newName)

    -- Copy from old profile
    NRSKNUI.db:CopyProfile(oldName)

    -- If old was current, stay on new; otherwise switch back
    if not isCurrentProfile then NRSKNUI.db:SetProfile(self:GetCurrentProfile()) end

    -- Delete old profile
    NRSKNUI.db:DeleteProfile(oldName)

    -- Update global profile reference if needed
    if isGlobalProfile then NRSKNUI.db.global.GlobalProfile = newName end

    self:RefreshAllModules()
    return true
end

--- Reset current profile to defaults
---@return boolean success
function ProfileManager:ResetProfile()
    if not NRSKNUI.db then return false end

    NRSKNUI.db:ResetProfile()
    self:RefreshAllModules()
    return true
end

--- Enable or disable global profile mode
---@param enabled boolean Whether to use global profile
---@return boolean success
function ProfileManager:SetUseGlobalProfile(enabled)
    if not NRSKNUI.db or not NRSKNUI.db.global then return false end
    NRSKNUI.db.global.UseGlobalProfile = enabled

    -- Switch to global profile
    if enabled then
        local globalProfile = NRSKNUI.db.global.GlobalProfile or DEFAULT_PROFILE
        NRSKNUI.db:SetProfile(globalProfile)
    end

    self:RefreshAllModules()
    return true
end

--- Get whether global profile mode is enabled
---@return boolean
function ProfileManager:GetUseGlobalProfile()
    if NRSKNUI.db and NRSKNUI.db.global then return NRSKNUI.db.global.UseGlobalProfile or false end
    return false
end

--- Set which profile to use as global
---@param profileName string The profile name to use globally
---@return boolean success, string|nil error
function ProfileManager:SetGlobalProfile(profileName)
    if not profileName or profileName == "" then return false, "Profile name cannot be empty" end
    if not NRSKNUI.db or not NRSKNUI.db.global then return false, "Database not initialized" end

    NRSKNUI.db.global.GlobalProfile = profileName

    -- If global mode is active, switch to this profile
    if NRSKNUI.db.global.UseGlobalProfile then
        NRSKNUI.db:SetProfile(profileName)
        self:RefreshAllModules()
    end

    return true
end

--- Get the name of the global profile
---@return string
function ProfileManager:GetGlobalProfile()
    if NRSKNUI.db and NRSKNUI.db.global then return NRSKNUI.db.global.GlobalProfile or DEFAULT_PROFILE end
    return DEFAULT_PROFILE
end

--- Export a profile to a string
---@param profileName string|nil Profile to export (current if nil)
---@return string|nil exportString, string|nil error
function ProfileManager:ExportProfile(profileName)
    profileName = profileName or self:GetCurrentProfile()

    if not NRSKNUI.db then return nil, "Database not initialized" end

    local profileData = NRSKNUI.db.profiles[profileName]
    if not profileData then return nil, "Profile '" .. profileName .. "' not found" end

    -- Create export package with metadata
    local exportData = {
        _v = 1,           -- Version
        _n = profileName, -- Original profile name
        _t = time(),      -- Timestamp
        d = profileData   -- Profile data
    }

    -- Serialize
    local serialized = AceSerializer:Serialize(exportData)
    if not serialized then return nil, "Serialization failed" end

    -- Compress
    local compressed = LibDeflate:CompressDeflate(serialized, { level = 9 })
    if not compressed then return nil, "Compression failed" end

    -- Encode for copy
    local encoded = LibDeflate:EncodeForPrint(compressed)
    if not encoded then return nil, "Encoding failed" end

    return EXPORT_PREFIX .. encoded
end

--- Import a profile from a string
---@param importString string The export string
---@param targetName string|nil Name for the imported profile (uses embedded name if nil)
---@return boolean success, string|nil nameOrError
function ProfileManager:ImportProfile(importString, targetName)
    if not importString or importString == "" then return false, "Import string is empty" end
    -- Validate prefix
    if importString:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then return false, "Invalid format (missing or wrong prefix)" end
    if not NRSKNUI.db then return false, "Database not initialized" end

    -- Remove prefix
    local encoded = importString:sub(#EXPORT_PREFIX + 1)

    -- Decode
    local compressed = LibDeflate:DecodeForPrint(encoded)
    if not compressed then return false, "Decoding failed" end

    -- Decompress
    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then return false, "Decompression failed" end

    -- Deserialize
    local success, exportData = AceSerializer:Deserialize(serialized)
    if not success then return false, "Deserialization failed: " .. tostring(exportData) end

    -- Validate structure
    if type(exportData) ~= "table" or not exportData.d then return false, "Invalid data structure" end

    -- Determine target profile name
    local finalName = targetName or exportData._n or "Imported"

    -- Check if profile exists and generate unique name if needed
    local profiles = self:GetProfiles()
    local baseName = finalName
    local counter = 1
    local nameExists = true

    while nameExists do
        nameExists = false
        for _, name in pairs(profiles) do
            if name == finalName then
                nameExists = true
                counter = counter + 1
                finalName = baseName .. " (" .. counter .. ")"
                break
            end
        end
    end

    -- Create the profile
    local currentProfile = self:GetCurrentProfile()

    -- Switch to new profile (creates it)
    NRSKNUI.db:SetProfile(finalName)

    -- Copy imported data to profile
    local profileRef = NRSKNUI.db.profile
    if profileRef then
        -- Wipe existing and copy new data
        wipe(profileRef)
        for k, v in pairs(exportData.d) do
            profileRef[k] = v
        end
    end

    -- Switch back to original profile
    NRSKNUI.db:SetProfile(currentProfile)

    return true, finalName
end

--- Refresh all enabled modules to apply new settings
function ProfileManager:RefreshAllModules()
    local NorskenUI = _G.NorskenUI
    if not NorskenUI then return end

    -- Stop previews before refreshing anything
    if NRSKNUI.PreviewManager then NRSKNUI.PreviewManager:StopAllPreviews() end

    -- Refresh module DB's and apply settings, this way no reload should be needed tho needs testing
    for _, module in NorskenUI:IterateModules() do
        if module.UpdateDB then module:UpdateDB() end
        if module:IsEnabled() and module.ApplySettings then module:ApplySettings() end
    end

    -- Refresh theme
    if NRSKNUI.RefreshTheme then NRSKNUI:RefreshTheme() end

    -- Refresh GUI frame if open
    if NRSKNUI.GUIFrame and NRSKNUI.GUIFrame.ApplyThemeColors then NRSKNUI.GUIFrame:ApplyThemeColors() end

    -- Start previews again
    if NRSKNUI.PreviewManager then NRSKNUI.PreviewManager:StartAllPreviews() end
end

---@class NRSKNUI
local NRSKNUI = select(2, ...)
local ProfileManager = {}
NRSKNUI.ProfileManager = ProfileManager
local AceSerializer = NRSKNUI.Libs.AS
local LibDeflate = NRSKNUI.Libs.LD
local L = NRSKNUI.Libs.AL
local LDS = NRSKNUI.Libs.LDS

-- Globally exposed API table for WagoUI Packs & profile installer addons.
local NorskenUIAPI = _G.NorskenUIAPI

local geterrorhandler, error = geterrorhandler, error
local type, next, wipe, time = type, next, wipe, time
local GetSpecializationRole = GetSpecializationRole
local pcall, xpcall = pcall, xpcall
local pairs, ipairs = pairs, ipairs
local format = string.format
local tostring = tostring
local sort = table.sort
local rawget = rawget

local GetNumSpecializationsForClassID = C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID
local GetSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
local DecompressString = C_EncodingUtil and C_EncodingUtil.DecompressString
local DeserializeCBOR = C_EncodingUtil and C_EncodingUtil.DeserializeCBOR
local CompressString = C_EncodingUtil and C_EncodingUtil.CompressString
local SerializeCBOR = C_EncodingUtil and C_EncodingUtil.SerializeCBOR
local EncodeBase64 = C_EncodingUtil and C_EncodingUtil.EncodeBase64
local DecodeBase64 = C_EncodingUtil and C_EncodingUtil.DecodeBase64
local after = C_Timer and C_Timer.After

local optimizeForSizeEnum = Enum and Enum.CompressionLevel and Enum.CompressionLevel.OptimizeForSize
local deflateEnum = Enum and Enum.CompressionMethod and Enum.CompressionMethod.Deflate

local EXPORT_PREFIX = '!NRSKNUI2!' -- C_EncodingUtil: CBOR + Deflate + Base64
local LEGACY_PREFIX = '!NRSKNUI1!' -- AceSerializer + LibDeflate, still decoded so old strings import
local DEFAULT_PROFILE = 'Default'
local suppressDepth = 0
local promptMuteDepth = 0
local promptsReady = false
local reloadPrompted = false

---@param fn fun()
local function WithoutRefresh(fn)
    suppressDepth = suppressDepth + 1
    local ok, err = pcall(fn)
    suppressDepth = suppressDepth - 1
    if not ok then
        error(err, 0)
    end
end

---@param src table
---@return table|nil
local function DeepCopy(src)
    if type(src) ~= 'table' then
        return src
    end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

-- Role sets --

-- A module's settings for one role sit in its own namespace under a hidden profile key. The core db
-- never has that key, so role sets stay out of the profile list.
local ROLE_SEP = '\1'
local ROLES = { TANK = true, HEALER = true, DAMAGER = true }
local roleKnown = false
local OWN = '' -- in editRoles: the namespace's own settings; no role is named this
local editRoles = {} ---@type table<string, string> role the options window edits per namespace, OWN = its own

---@param profileName string
---@param role string
---@return string
local function RoleKey(profileName, role)
    return profileName .. ROLE_SEP .. role
end

---The role the player's spec plays. The spec can't be trusted before login, so the last role seen stands in.
---@return string|nil
local function CurrentRole()
    local char = NRSKNUI.db.char
    if not roleKnown then
        return char.LastRole
    end

    local spec = GetSpecialization()
    local role = spec and GetSpecializationRole(spec)
    if role and ROLES[role] then
        char.LastRole = role
    end
    return char.LastRole
end

---Point every namespace at its settings for role, falling back to the profile's own where it has none.
---A module open in the options window shows the role being edited there instead.
---@param role string|nil nil points every namespace at the profile's own settings
---@return boolean moved
local function PointNamespaces(role)
    local db = NRSKNUI.db
    local profileName = db.keys.profile
    local moved = false
    for name, ns in pairs(db.children or {}) do
        local nsRole = role
        local edited = editRoles[name]
        if role and edited ~= nil then
            -- its own settings, which nil already means here
            if edited == OWN then
                nsRole = nil
            else
                nsRole = edited
            end
        end
        local key = profileName
        if nsRole and rawget(ns.profiles, RoleKey(profileName, nsRole)) then
            key = RoleKey(profileName, nsRole)
        end
        if ns.keys.profile ~= key then
            -- namespaces get no SetProfile of their own, AceDB switches them with this same function
            db.SetProfile(ns, key)
            -- logout only strips a profile AceDB has built
            local _ = ns.profile
            moved = true
        end
    end
    return moved
end

---Run fn with every namespace on the profile's own settings. AceDB's copy and reset reach a namespace
---through the key it points at, which would write into a role set.
---@param fn fun()
local function WithoutRoles(fn)
    PointNamespaces(nil)
    local ok, err = pcall(fn)
    PointNamespaces(CurrentRole())
    if not ok then
        error(err, 0)
    end
end

---Call fn(profiles, key, role, name) for every role set saved under a profile, loaded modules or not.
---@param profileName string
---@param fn fun(profiles: table, key: string, role: string, name: string)
local function EachRoleSet(profileName, fn)
    for name, saved in pairs(NRSKNUI.db.sv.namespaces or {}) do
        for role in pairs(ROLES) do
            local key = RoleKey(profileName, role)
            if saved.profiles and saved.profiles[key] then
                fn(saved.profiles, key, role, name)
            end
        end
    end
end

---@param profileName string
local function DropRoleSets(profileName)
    EachRoleSet(profileName, function(profiles, key) profiles[key] = nil end)
end

---@param source string
---@param target string
local function CopyRoleSets(source, target)
    DropRoleSets(target)
    EachRoleSet(source, function(profiles, key, role)
        profiles[RoleKey(target, role)] = DeepCopy(profiles[key])
    end)
end

---@param oldName string
---@param newName string
local function MoveRoleSets(oldName, newName)
    EachRoleSet(oldName, function(profiles, key, role)
        profiles[RoleKey(newName, role)] = profiles[key]
        profiles[key] = nil
    end)
end

---Run fn on another profile, then come back to the active one quietly.
---SetProfile strips the defaults out of the profile it leaves in place. Modules keep reading the
---active one's tables without an UpdateDB, so that hop goes without defaults to leave it whole.
---@param profileName string
---@param fn fun()
local function OnProfile(profileName, fn)
    local db = NRSKNUI.db
    local currentProfile = db:GetCurrentProfile()
    local dbs = { db }
    for _, child in pairs(db.children or {}) do
        dbs[#dbs + 1] = child
    end

    WithoutRefresh(function()
        local defaults = {}
        for i, each in ipairs(dbs) do
            defaults[i] = each.defaults
            each.defaults = nil
        end
        -- a db left without defaults would write every default into the save at logout
        local ok, err = pcall(db.SetProfile, db, profileName)
        for i, each in ipairs(dbs) do
            each.defaults = defaults[i]
        end
        if not ok then
            error(err, 0)
        end

        fn()
        db:SetProfile(currentProfile)

        -- logout strips only a profile AceDB has built again, which reading a cached table never does
        for _, each in ipairs(dbs) do
            local _ = each.profile
        end

        -- coming back put every namespace on the profile's own settings
        PointNamespaces(CurrentRole())
    end)
end

---WagoUI reloads once itself after its setup.
---@param fn fun()
local function WithoutPrompt(fn)
    promptMuteDepth = promptMuteDepth + 1
    local ok, err = pcall(fn)
    promptMuteDepth = promptMuteDepth - 1
    if not ok then error(err, 0) end
end

local function ErrorHandler(err)
    local handler = geterrorhandler()
    if handler then
        return handler(err)
    end
end

---Run one module's refresh step in isolation.
---@param aceModule table
---@param method string
local function SafeCall(aceModule, method, ...)
    local fn = aceModule[method]
    if not fn then return end
    xpcall(fn, ErrorHandler, aceModule, ...)
end

---Open the reload prompt after a profile change. A refresh re-reads every setting, but anything
---already built (frames, hooks, skins) only fully matches the new profile once the UI reloads.
function ProfileManager:PromptReload()
    if suppressDepth > 0 or promptMuteDepth > 0 or not promptsReady or reloadPrompted then return end
    reloadPrompted = true
    NRSKNUI:RunWhenSafe(function()
        NRSKNUI:CreateReloadPrompt(L['Profile changed. A UI reload is recommended to fully apply all settings.'])
    end)
end

---Opened by the boot sequence. Login runs LibDualSpec's first profile swap, which must not prompt.
function ProfileManager:SetPromptsReady()
    promptsReady = true
end

---Turn per-spec profiles on or off, preserving the assignments.
---@param enabled boolean
---@return boolean success
function ProfileManager:SetSpecProfilesEnabled(enabled)
    local db = NRSKNUI.db
    if not db or not db.SetDualSpecEnabled then return false end

    local numSpecs = GetNumSpecializationsForClassID(NRSKNUI.MyClassID) or 0

    if not enabled then
        -- Snapshot before the library wipes it.
        local saved = {}
        for spec = 1, numSpecs do saved[spec] = db:GetDualSpecProfile(spec) end
        db.char.SpecProfiles = saved
        db:SetDualSpecEnabled(false)
        return true
    end

    db:SetDualSpecEnabled(true)

    local saved = db.char.SpecProfiles
    if not saved then return true end

    -- A remembered profile could have been deleted while the feature was off.
    local exists = {}
    for _, name in pairs(self:GetProfiles()) do exists[name] = true end

    for spec = 1, numSpecs do
        local name = saved[spec]
        if name and exists[name] then db:SetDualSpecProfile(name, spec) end
    end

    return true
end

---Get list of all available profiles
---@return table List of profile names
function ProfileManager:GetProfiles()
    local profiles = {}
    if NRSKNUI.db then
        NRSKNUI.db:GetProfiles(profiles)
    end
    return profiles
end

---Get the current active profile name
---@return string Current profile name
function ProfileManager:GetCurrentProfile()
    if NRSKNUI.db then
        return NRSKNUI.db:GetCurrentProfile()
    end
    return DEFAULT_PROFILE
end

---Switch to a different profile
---@param profileName string The profile name to switch to
---@return boolean success
---@return string|nil error
function ProfileManager:SetProfile(profileName)
    if not profileName or profileName == '' then
        return false, L['Invalid profile name']
    end
    if not NRSKNUI.db then
        return false, L['Database not initialized']
    end

    -- SetProfile handles creation if profile doesn't exist and fires OnProfileChanged for the refresh.
    NRSKNUI.db:SetProfile(profileName)

    return true
end

---Create a new profile, with default values or as a copy of another profile
---@param profileName string The name for the new profile
---@param sourceProfile string|nil Profile to copy the settings from, defaults when nil
---@return boolean success
---@return string|nil error
function ProfileManager:CreateProfile(profileName, sourceProfile)
    if not profileName or profileName == '' then
        return false, L['Profile name cannot be empty']
    end
    if not NRSKNUI.db then
        return false, L['Database not initialized']
    end

    -- Check if profile with the same name already exists
    local profiles = self:GetProfiles()
    for _, name in pairs(profiles) do
        if name == profileName then
            return false, format(L['Profile: %s, already exists'], profileName)
        end
    end

    OnProfile(profileName, function() NRSKNUI.db:ResetProfile() end)

    if sourceProfile then
        return self:CopyProfile(sourceProfile, profileName)
    end
    return true
end

---Copy settings from one profile to another
---@param sourceProfile string Source profile name
---@param targetProfile string|nil Target profile name (current if nil)
---@return boolean success
---@return string|nil error
function ProfileManager:CopyProfile(sourceProfile, targetProfile)
    if not sourceProfile or sourceProfile == '' then
        return false, L['Source profile name cannot be empty']
    end
    if not NRSKNUI.db then
        return false, L['Database not initialized']
    end

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

    if not sourceExists then
        return false, format(L['Source profile: %s, does not exist'], sourceProfile)
    end

    -- AceDB's CopyProfile copies TO the current profile FROM the source
    if targetProfile == self:GetCurrentProfile() then
        -- Copying into the active profile, OnProfileCopied drives the refresh, after the role sets are in place.
        WithoutRoles(function()
            CopyRoleSets(sourceProfile, targetProfile)
            NRSKNUI.db:CopyProfile(sourceProfile)
        end)
    else
        -- Copying into an inactive profile changes nothing we are looking at, so stay quiet.
        OnProfile(targetProfile, function() NRSKNUI.db:CopyProfile(sourceProfile) end)
        CopyRoleSets(sourceProfile, targetProfile)
    end

    return true
end

---Delete a profile
---@param profileName string The profile name to delete
---@return boolean success
---@return string|nil error
function ProfileManager:DeleteProfile(profileName)
    if not profileName or profileName == '' then
        return false, L['Profile name cannot be empty']
    end
    if not NRSKNUI.db then
        return false, L['Database not initialized']
    end
    if profileName == self:GetCurrentProfile() then
        return false, L['Cannot delete the active profile']
    end

    -- Check if profile exists
    local profiles = self:GetProfiles()
    local exists = false
    for _, name in pairs(profiles) do
        if name == profileName then
            exists = true
            break
        end
    end

    -- Check if profile we want to delete even exists
    if not exists then
        return false, format(L['Profile: %s, does not exist'], profileName)
    end

    if NRSKNUI.db.global.GlobalProfile == profileName then NRSKNUI.db.global.GlobalProfile = DEFAULT_PROFILE end

    -- Drop spec assignments first, while the profile still exists to be compared against.
    self:RemapDualSpecProfile(profileName, nil)

    NRSKNUI.db:DeleteProfile(profileName)
    DropRoleSets(profileName) -- AceDB only deletes the exact name
    return true
end

---Repoint LibDualSpec's per-spec assignments away from a profile that is being renamed or deleted,
---so a spec change cannot try to activate a profile that no longer exists.
---@param oldName string
---@param newName string|nil nil clears the assignment back to the active profile
function ProfileManager:RemapDualSpecProfile(oldName, newName)
    if not NRSKNUI.db or not NRSKNUI.db.GetDualSpecProfile or not NRSKNUI.db.SetDualSpecProfile then return end

    local numSpecs = GetNumSpecializationsForClassID(NRSKNUI.MyClassID)
    if not numSpecs then return end

    for spec = 1, numSpecs do
        -- Unassigned specs report the active profile, which is never oldName by the time we run.
        if NRSKNUI.db:GetDualSpecProfile(spec) == oldName then
            NRSKNUI.db:SetDualSpecProfile(newName or self:GetCurrentProfile(), spec)
        end
    end

    -- Snapshot taken when spec profiles were switched off.
    local saved = NRSKNUI.db.char.SpecProfiles
    if not saved then return end

    for spec = 1, numSpecs do
        if saved[spec] == oldName then saved[spec] = newName end
    end
end

---Rename a profile
---@param oldName string Current profile name
---@param newName string New profile name
---@return boolean success
---@return string|nil error
function ProfileManager:RenameProfile(oldName, newName)
    if not oldName or oldName == '' then
        return false, L['Current name cannot be empty']
    end
    if not newName or newName == '' then
        return false, L['New name cannot be empty']
    end
    if oldName == newName then
        return false, L['Names are identical']
    end
    if not NRSKNUI.db then
        return false, L['Database not initialized']
    end

    -- Check if old profile exists
    local profiles = self:GetProfiles()
    local oldExists = false
    for _, name in pairs(profiles) do
        if name == oldName then
            oldExists = true
        end
        if name == newName then
            return false, format(L['Profile: %s, already exists'], newName)
        end
    end

    if not oldExists then
        return false, format(L['Profile: %s, does not exist'], oldName)
    end

    local originalProfile = self:GetCurrentProfile()
    local isCurrentProfile = (oldName == originalProfile)
    local isGlobalProfile = NRSKNUI.db.global and NRSKNUI.db.global.GlobalProfile == oldName

    -- Renaming is copy-to-new then delete-old, which means hopping profiles. Capture the profile we
    -- started on first, reading it back mid-rename returns newName and the switch back is lost.
    WithoutRefresh(function()
        -- If old was current, stay on new, otherwise return to where we started
        if isCurrentProfile then
            NRSKNUI.db:SetProfile(newName)
            NRSKNUI.db:CopyProfile(oldName)
        else
            OnProfile(newName, function() NRSKNUI.db:CopyProfile(oldName) end)
        end

        -- Repoint every character before DeleteProfile sends them to "Default"; SetDualSpecProfile would switch mid-rename.
        local sv = NRSKNUI.db.sv
        for charKey, name in pairs(sv.profileKeys) do
            if name == oldName then sv.profileKeys[charKey] = newName end
        end
        local dualSpec = sv.namespaces and sv.namespaces['LibDualSpec-1.0']
        for _, specs in pairs(dualSpec and dualSpec.char or {}) do
            for spec, name in pairs(specs) do
                if name == oldName then specs[spec] = newName end
            end
        end
        for _, char in pairs(sv.char or {}) do
            if char.OwnProfile == oldName then char.OwnProfile = newName end
            for spec, name in pairs(char.SpecProfiles or {}) do
                if name == oldName then char.SpecProfiles[spec] = newName end
            end
        end

        MoveRoleSets(oldName, newName) -- AceDB's copy and delete only see the exact name
        NRSKNUI.db:DeleteProfile(oldName)
    end)

    if isGlobalProfile then NRSKNUI.db.global.GlobalProfile = newName end

    -- Only the active profile being renamed changes what is on screen.
    if isCurrentProfile then self:RefreshAllModules() end
    return true
end

---Reset a profile to defaults
---@param profileName string|nil the active profile when nil
---@return boolean success
function ProfileManager:ResetProfile(profileName)
    if not NRSKNUI.db then return false end

    -- defaults have no role sets
    local currentProfile = self:GetCurrentProfile()
    if not profileName or profileName == currentProfile then
        WithoutRoles(function()
            DropRoleSets(currentProfile)
            NRSKNUI.db:ResetProfile() -- OnProfileReset drives the refresh
        end)
        return true
    end

    OnProfile(profileName, function() NRSKNUI.db:ResetProfile() end)
    DropRoleSets(profileName)
    return true
end

-- Profile mode --

---Join or leave the global profile; the character's own profile and spec profiles are parked in db.char meanwhile.
function ProfileManager:SyncGlobalProfile()
    local db = NRSKNUI.db
    local char = db.char

    if db.global.UseGlobalProfile then
        if not char.GlobalProfileJoined then
            char.OwnProfile = db:GetCurrentProfile()
            local dualSpec = db:GetNamespace('LibDualSpec-1.0', true)
            char.OwnSpecProfiles = dualSpec and dualSpec.char.enabled or nil -- IsDualSpecEnabled() is false at login
            if char.OwnSpecProfiles then self:SetSpecProfilesEnabled(false) end
            char.GlobalProfileJoined = true
        end
        db:SetProfile(db.global.GlobalProfile)
    elseif char.GlobalProfileJoined then
        if char.OwnSpecProfiles then
            self:SetSpecProfilesEnabled(true)
        elseif char.OwnProfile and db.profiles[char.OwnProfile] then
            db:SetProfile(char.OwnProfile)
        end
        char.GlobalProfileJoined, char.OwnProfile, char.OwnSpecProfiles = nil, nil, nil
    end
end

---@return 'char'|'spec'|'global'
function ProfileManager:GetProfileMode()
    local db = NRSKNUI.db
    if db.global.UseGlobalProfile then return 'global' end
    if db:IsDualSpecEnabled() then return 'spec' end
    return 'char'
end

---@return boolean
function ProfileManager:CanUseSpecProfiles()
    return LDS.currentSpec > 0 -- no specialization yet
end

---@param mode 'char'|'spec'|'global'
function ProfileManager:SetProfileMode(mode)
    local db = NRSKNUI.db
    local before = db:GetCurrentProfile()

    WithoutRefresh(function()
        db.global.UseGlobalProfile = mode == 'global'
        self:SyncGlobalProfile()
        if mode ~= 'global' and db:IsDualSpecEnabled() ~= (mode == 'spec') then
            self:SetSpecProfilesEnabled(mode == 'spec')
        end
    end)

    if db:GetCurrentProfile() ~= before then
        self:RefreshAllModules()
        self:PromptReload()
    end
end

---Activate a profile the way the current mode assigns profiles.
---@param profileName string
function ProfileManager:UseProfile(profileName)
    local mode = self:GetProfileMode()
    if mode == 'global' then
        self:SetGlobalProfile(profileName)
    elseif mode == 'spec' then
        NRSKNUI.db:SetDualSpecProfile(profileName) -- current spec
    else
        NRSKNUI.db:SetProfile(profileName)
    end
end

---Who points at each profile across the account: "Name - Realm" per character, plus the global profile.
---@return table<string, string[]>
function ProfileManager:GetProfileUsers()
    local db = NRSKNUI.db
    local sv = db.sv
    local users = {} ---@type table<string, string[]>
    local seen = {}
    local function Add(profile, who)
        if seen[profile .. '\0' .. who] then return end
        seen[profile .. '\0' .. who] = true
        users[profile] = users[profile] or {}
        users[profile][#users[profile] + 1] = who
    end

    if db.global.UseGlobalProfile then Add(db.global.GlobalProfile, L['Global Profile']) end
    for charKey, name in pairs(sv.profileKeys) do Add(name, charKey) end

    local dualSpec = sv.namespaces and sv.namespaces['LibDualSpec-1.0']
    for charKey, specs in pairs(dualSpec and dualSpec.char or {}) do
        if specs.enabled then
            for spec, name in pairs(specs) do
                if type(spec) == 'number' then Add(name, charKey) end
            end
        end
    end

    return users
end

---Get whether global profile mode is enabled
---@return boolean
function ProfileManager:GetUseGlobalProfile()
    if NRSKNUI.db and NRSKNUI.db.global then
        return NRSKNUI.db.global.UseGlobalProfile or false
    end
    return false
end

---Set which profile to use as global
---@param profileName string The profile name to use globally
---@return boolean success
---@return string|nil error
function ProfileManager:SetGlobalProfile(profileName)
    if not profileName or profileName == '' then
        return false, L['Profile name cannot be empty']
    end
    if not NRSKNUI.db or not NRSKNUI.db.global then
        return false, L['Database not initialized']
    end

    NRSKNUI.db.global.GlobalProfile = profileName

    -- If global mode is active, switch to this profile, SetProfile drives the refresh.
    if NRSKNUI.db.global.UseGlobalProfile then NRSKNUI.db:SetProfile(profileName) end
    return true
end

---Get the name of the global profile
---@return string
function ProfileManager:GetGlobalProfile()
    if NRSKNUI.db and NRSKNUI.db.global then
        return NRSKNUI.db.global.GlobalProfile or DEFAULT_PROFILE
    end
    return DEFAULT_PROFILE
end

-- Roles --

---The spec is known from login on. Settles every module on its role's settings before modules build frames.
function ProfileManager:SettleRole()
    roleKnown = true
    if not PointNamespaces(CurrentRole()) then return end

    for _, aceModule in NRSKNUI:IterateModules() do
        SafeCall(aceModule, 'UpdateDB')
    end
end

---Modules with settings for the new spec's role switch to them.
---Points every module at the current role's settings; a no-op when the role didn't change.
local function ApplyRole()
    if not PointNamespaces(CurrentRole()) then return end
    ProfileManager:RefreshAllModules()
    ProfileManager:PromptReload()
end

function ProfileManager:OnSpecChanged()
    -- a frame later, so a LibDualSpec swap on the same change has already re-pointed everything in its
    -- refresh; a change that lands in combat waits for it to end, the refresh rebuilds secure frames
    after(0, function()
        NRSKNUI:RunWhenSafe(ApplyRole)
    end)
end

---Roles with their own settings for a module in the active profile.
---@param name string namespace
---@return table<string, boolean>
function ProfileManager:GetRoleSets(name)
    local db = NRSKNUI.db
    local ns = db.children and db.children[name]
    local sets = {}
    if not ns then
        return sets
    end

    for role in pairs(ROLES) do
        if rawget(ns.profiles, RoleKey(db.keys.profile, role)) then
            sets[role] = true
        end
    end
    return sets
end

---Give a role its own settings for a module, starting from what fromRole uses (the module's own when nil).
---@param name string namespace
---@param role string
---@param fromRole string?
---@return boolean added
function ProfileManager:AddRoleSet(name, role, fromRole)
    local db = NRSKNUI.db
    local ns = db.children and db.children[name]
    if not ns or not ROLES[role] then return false end

    local sets = self:GetRoleSets(name)
    if sets[role] then return false end
    -- three roles, so two role sets at most: one role always keeps the module's own settings
    local count = 0
    for _ in pairs(sets) do
        count = count + 1
    end
    if count >= 2 then return false end

    local profileName = db.keys.profile
    local key = RoleKey(profileName, role)
    local fromKey = fromRole and sets[fromRole] and RoleKey(profileName, fromRole) or profileName
    ns.profiles[key] = DeepCopy(ns.profiles[fromKey] or {})

    -- the copy holds the defaults AceDB filled in, a hop onto it and back strips them like a profile switch does
    local current = ns.keys.profile
    db.SetProfile(ns, key)
    local _ = ns.profile
    db.SetProfile(ns, current)
    _ = ns.profile

    if PointNamespaces(CurrentRole()) then
        self:RefreshAllModules()
    end
    return true
end

---The role goes back to the module's own settings.
---@param name string namespace
---@param role string
---@return boolean removed
function ProfileManager:RemoveRoleSet(name, role)
    local db = NRSKNUI.db
    local ns = db.children and db.children[name]
    if not ns or not self:GetRoleSets(name)[role] then return false end

    local key = RoleKey(db.keys.profile, role)
    local shown = ns.keys.profile == key
    if shown then
        db.SetProfile(ns, db.keys.profile)
        local _ = ns.profile
    end
    ns.profiles[key] = nil
    if editRoles[name] == role then
        editRoles[name] = nil
    end

    if shown then
        self:RefreshAllModules()
    end
    return true
end

---The role whose settings a module shows right now, nil when it shows its own.
---@param name string namespace
---@return string|nil
function ProfileManager:GetShownRole(name)
    local role = editRoles[name]
    if role == OWN then return nil end

    if role == nil then
        role = CurrentRole()
    end
    if not role then return nil end

    if self:GetRoleSets(name)[role] then
        return role
    end
    return nil
end

---Put a module back to its defaults: the set it shows now or, with everything, its own settings with every
---role set gone. Enabled stays as it was, a reset never turns a module on or off.
---@param name string namespace
---@param everything boolean
function ProfileManager:ResetModule(name, everything)
    local db = NRSKNUI.db
    local ns = db.children and db.children[name]
    if not ns then return end

    local enabled = ns.profile.Enabled
    if everything then
        for role in pairs(self:GetRoleSets(name)) do
            self:RemoveRoleSet(name, role)
        end
    end
    -- the namespace points at the shown set; the table is wiped in place so modules keep their reference
    ns:ResetProfile(nil, true)
    ns.profile.Enabled = enabled
    self:RefreshAllModules()
end

---Switch a module on or off for every role. Enabled sits in each role set too, so all of them get it
---and a spec swap never turns the module back on or off.
---@param name string namespace
---@param enabled boolean
function ProfileManager:SetModuleEnabled(name, enabled)
    local db = NRSKNUI.db
    local ns = db.children and db.children[name]
    if not ns then return end

    local profileName = db.keys.profile
    ns.profiles[profileName] = ns.profiles[profileName] or {}
    ns.profiles[profileName].Enabled = enabled
    for role in pairs(self:GetRoleSets(name)) do
        ns.profiles[RoleKey(profileName, role)].Enabled = enabled
    end
end

---The player's role, from their spec.
---@return string|nil
function ProfileManager:GetPlayerRole()
    return CurrentRole()
end

---While the options window edits a module, it shows (and edits) that role's settings. nil = the module's own.
---@param name string namespace
---@param role string|nil
function ProfileManager:SetEditRole(name, role)
    editRoles[name] = role or OWN
    if PointNamespaces(CurrentRole()) then
        self:RefreshAllModules()
    end
end

---Every module back on the player's own role: the options window left the module or closed.
function ProfileManager:ClearEditRoles()
    if next(editRoles) == nil then return end

    wipe(editRoles)
    if PointNamespaces(CurrentRole()) then
        self:RefreshAllModules()
    end
end

-- Namespaces --

local namespaces = {} ---@type table<string, AceDBObject-3.0>

---Where a namespace's settings sit inside a profile: the place they were saved before the namespace
---existed, which every export string still uses. Remembered, so it's known while the module isn't loaded.
---@param name string
---@return string[]
local function OldPath(name)
    local stored = NRSKNUI.db.global.NamespacePaths[name]
    if not stored then
        return { name }
    end

    local path = {}
    for key in stored:gmatch('[^.]+') do
        path[#path + 1] = key
    end
    return path
end

---Remove and return the value at path, dropping the tables it leaves empty.
---@param data table
---@param path string[]
---@param depth integer?
---@return any
local function Take(data, path, depth)
    depth = depth or 1
    local key = path[depth]
    local value = data[key]
    if depth == #path then
        data[key] = nil
        return value
    end
    if type(value) ~= 'table' then return nil end

    local taken = Take(value, path, depth + 1)
    if next(value) == nil then
        data[key] = nil
    end
    return taken
end

---Set value at path in an export copy, copying the tables on the way so the saved profile stays untouched.
---@param data table
---@param path string[]
---@param value any
local function Put(data, path, value)
    for depth = 1, #path - 1 do
        local copy = {}
        for k, v in pairs(data[path[depth]] or {}) do
            copy[k] = v
        end
        data[path[depth]] = copy
        data = copy
    end
    data[path[#path]] = value
end

---Namespace names ordered by how deep their old path sits. Skinning.ActionBars sits inside Skinning, so an
---export fills Skinning in before ActionBars and an import takes ActionBars out before Skinning takes the rest.
---@param map table<string, any>
---@param deepestFirst boolean?
---@return string[]
local function ByPathDepth(map, deepestFirst)
    local names, depth = {}, {}
    for name in pairs(map) do
        names[#names + 1] = name
        depth[name] = #OldPath(name)
    end
    sort(names, function(a, b)
        if depth[a] == depth[b] then
            return a < b
        end
        if deepestFirst then
            return depth[a] > depth[b]
        end
        return depth[a] < depth[b]
    end)
    return names
end

---Shared settings left the profile: the old values only stay in the saved one as a way back. The skinning
---namespace sharing their key isn't one of them.
---@param data table
local function DropSharedSettings(data)
    local media = data.globalMedia
    local fonts = type(media) == 'table' and media.blizzardFonts
    data.globalMedia = fonts and { blizzardFonts = fonts } or nil
    data.Colors = nil
    data._shared = nil
end

---The shared settings a string carries: its _shared block, or where a profile held them in older strings.
---@param data table
---@return table|nil block
local function SharedBlock(data)
    local block = type(data._shared) == 'table' and data._shared or data
    if not NRSKNUI:HoldsSharedSettings(block) then return nil end

    return { globalMedia = block.globalMedia, Colors = block.Colors }
end

---Goes after everything else in an import that can fail: an error here would leave the account half changed.
---Modules and colors refresh with the profile switch, registered fonts only hear about real ones.
---@param block table
local function ApplyShared(block)
    NRSKNUI:ApplySharedSettings(block)
    NRSKNUI:DeferUntilUnrestricted(0, function() NRSKNUI:RefreshFontStyles() end)
end

---An imported profile carries every module's settings inside it at their old path, so hand them over.
---The import replaces the whole profile, so a namespace it carries nothing for starts over.
---@param profileName string
local function ImportIntoNamespaces(profileName)
    local db = NRSKNUI.db
    local data = db.profiles[profileName]

    -- the refill below lands in the profile's own tables; the old role sets go with the old profile
    if profileName == db:GetCurrentProfile() then
        PointNamespaces(nil)
    end
    DropRoleSets(profileName)

    -- role sets ride along as _roles[namespace][role], straight into the save so unloaded modules get theirs too
    local roles = data._roles
    data._roles = nil
    if type(roles) == 'table' then
        db.sv.namespaces = db.sv.namespaces or {}
        for name, sets in pairs(roles) do
            if type(name) == 'string' and type(sets) == 'table' then
                local saved = db.sv.namespaces[name] or {}
                db.sv.namespaces[name] = saved
                saved.profiles = saved.profiles or {}
                -- the pasted string is untrusted: known roles only and one role always left on the module's own settings
                local count = 0
                for role, set in pairs(sets) do
                    if ROLES[role] and type(set) == 'table' and count < 2 then
                        saved.profiles[RoleKey(profileName, role)] = set
                        count = count + 1
                    end
                end
            end
        end
    end

    -- modules that aren't loaded pick their part up from the profile once they register
    for name, saved in pairs(db.sv.namespaces or {}) do
        if not namespaces[name] and saved.profiles then
            saved.profiles[profileName] = nil
        end
    end

    for _, name in ipairs(ByPathDepth(namespaces, true)) do
        local ns = namespaces[name]
        local saved = Take(data, OldPath(name))
        if profileName == db:GetCurrentProfile() then
            -- AceDB keeps serving its own table for the active profile, so refill that one.
            wipe(ns.profile)
            for k, v in pairs(saved or {}) do
                ns.profile[k] = v
            end
            ns:RegisterDefaults(ns.defaults)
        else
            ns.profiles[profileName] = saved
        end
    end
end

---A module's own AceDB namespace inside NorskenUIDB. Profile switches, copies, resets and deletes reach it through AceDB.
---@param name string
---@param defaults table profile defaults
---@param oldPath string? where the settings sat in the profile when that isn't `name`, e.g. 'Miscellaneous.XPBar'
---@return AceDBObject-3.0
function ProfileManager:RegisterNamespace(name, defaults, oldPath)
    local db = NRSKNUI.db
    local sv = db.sv
    db.global.NamespacePaths[name] = oldPath

    -- Settings saved inside the profile move before AceDB builds the namespace, so it fills
    -- in defaults the same way it did there and the saved data comes out unchanged.
    sv.namespaces = sv.namespaces or {}
    local saved = sv.namespaces[name] or {}
    sv.namespaces[name] = saved
    local path = OldPath(name)
    for profileName, data in pairs(db.profiles) do
        local value = Take(data, path)
        if value then
            saved.profiles = saved.profiles or {}
            saved.profiles[profileName] = value
        end
    end

    -- a path that starts inside another namespace (Skinning.ActionBars) moves out of that one's save,
    -- role sets included since they're profiles of it too
    local outer = #path > 1 and sv.namespaces[path[1]]
    if outer and outer ~= saved and outer.profiles then
        for profileName, data in pairs(outer.profiles) do
            local value = Take(data, path, 2)
            if value then
                saved.profiles = saved.profiles or {}
                saved.profiles[profileName] = value
            end
        end
    end

    local ns = db:RegisterNamespace(name, { profile = defaults })
    namespaces[name] = ns
    PointNamespaces(CurrentRole()) -- before the module's UpdateDB reads it
    return ns
end

---A profile with every namespace folded back in at its old path, the layout export strings have always used.
---@param profileName string
---@param includeShared boolean|nil
---@return table|nil
local function ExportData(profileName, includeShared)
    local db = NRSKNUI.db
    local data = db.profiles[profileName]
    if not data then return end

    local out = {}
    for k, v in pairs(data) do
        out[k] = v
    end
    DropSharedSettings(out)

    local saved = db.sv.namespaces or {}
    for _, name in ipairs(ByPathDepth(saved)) do
        local nsData = saved[name].profiles and saved[name].profiles[profileName]
        if nsData then
            Put(out, OldPath(name), nsData)
        end
    end

    -- left out entirely when there are none, so those strings come out exactly as before
    EachRoleSet(profileName, function(profiles, key, role, name)
        out._roles = out._roles or {}
        out._roles[name] = out._roles[name] or {}
        out._roles[name][role] = profiles[key]
    end)

    if includeShared then
        local shared = NRSKNUI:GetSharedSettings()
        out._shared = { globalMedia = shared.globalMedia, Colors = shared.Colors } -- Language stays the reader's own
    end

    return out
end

---Export a profile to a string
---@param profileName string|nil Profile to export (current if nil)
---@param includeShared boolean|nil Add the shared fonts, textures and colors
---@return string|nil exportString
---@return string|nil error
function ProfileManager:ExportProfile(profileName, includeShared)
    profileName = profileName or self:GetCurrentProfile()

    if not NRSKNUI.db then
        return nil, L['Database not initialized']
    end

    local profileData = ExportData(profileName, includeShared)
    if not profileData then
        return nil, format(L['Profile: %s, not found'], profileName)
    end

    -- Create export package with metadata
    local exportData = {
        _v = 4,           -- Version
        _n = profileName, -- Original profile name
        _t = time(),      -- Timestamp
        d = profileData   -- Profile data
    }

    local ok, encoded = pcall(function()
        local serialized = SerializeCBOR(exportData)
        local compressed = CompressString(serialized, deflateEnum, optimizeForSizeEnum)
        return EncodeBase64(compressed)
    end)

    if not ok or not encoded then
        return nil, L['Export failed']
    end

    return EXPORT_PREFIX .. encoded
end

---TODO: Remove after some time/releases.
---Decode an export string produced by the AceSerializer + LibDeflate format (prefix !NRSKNUI1!).
---Kept so strings shared before the C_EncodingUtil switch still import.
---@param encoded string payload with the prefix already stripped
---@return table|nil exportData
---@return string|nil error
local function DecodeLegacy(encoded)
    local compressed = LibDeflate:DecodeForPrint(encoded)
    if not compressed then
        return nil, L['Decoding failed']
    end

    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then
        return nil, L['Decompression failed']
    end

    local success, exportData = AceSerializer:Deserialize(serialized)
    if not success then
        return nil, format(L['Deserialization failed: %s'], tostring(exportData))
    end
    if type(exportData) ~= 'table' then
        return nil, L['Invalid data structure']
    end

    return exportData
end

---Decode an export string produced by C_EncodingUtil (prefix !NRSKNUI2!).
---@param encoded string payload with the prefix already stripped
---@return table|nil exportData
---@return string|nil error
local function DecodeCurrent(encoded)
    -- The whole chain runs on untrusted pasted text, and these natives raise rather than return nil.
    local ok, exportData = pcall(function()
        local compressed = DecodeBase64(encoded)
        if not compressed then return nil end

        local serialized = DecompressString(compressed, deflateEnum)
        if not serialized then return nil end

        return DeserializeCBOR(serialized)
    end)

    -- A crafted string can deserialize cleanly into a scalar, so reject anything that is not a table here rather than downstream.
    if not ok or type(exportData) ~= 'table' then
        return nil, L['Decoding failed']
    end
    return exportData
end

---@param importString string
---@return table|nil exportData
---@return string|nil error
local function DecodeImport(importString)
    -- Route on the prefix so strings from either format still import.
    local exportData, decodeError
    if importString:sub(1, #EXPORT_PREFIX) == EXPORT_PREFIX then
        exportData, decodeError = DecodeCurrent(importString:sub(#EXPORT_PREFIX + 1))
    elseif importString:sub(1, #LEGACY_PREFIX) == LEGACY_PREFIX then
        exportData, decodeError = DecodeLegacy(importString:sub(#LEGACY_PREFIX + 1))
    else
        return nil, L['Invalid format (missing or wrong prefix)']
    end

    if not exportData then
        return nil, decodeError or L['Decoding failed']
    end

    -- Both decoders guarantee a table, so only the payload itself is left to check.
    if type(exportData.d) ~= 'table' then
        return nil, L['Invalid data structure']
    end
    return exportData
end

---Whether importing this string would ask about the shared settings.
---@param importString string
---@return boolean
function ProfileManager:CarriesSharedSettings(importString)
    local exportData = DecodeImport(importString)
    return exportData ~= nil and SharedBlock(exportData.d) ~= nil
end

---Import a profile from a string
---@param importString string The export string
---@param targetName string|nil Name for the imported profile (uses embedded name if nil)
---@param activate boolean|nil Make the imported profile the one in use
---@param applyShared boolean|nil Take on the shared settings the string carries
---@return boolean success
---@return string|nil nameOrError
function ProfileManager:ImportProfile(importString, targetName, activate, applyShared)
    if not importString or importString == '' then
        return false, L['Import string is empty']
    end
    if not NRSKNUI.db then
        return false, L['Database not initialized']
    end

    local exportData, decodeError = DecodeImport(importString)
    if not exportData then
        return false, decodeError
    end

    -- older strings still carry the load conditions Enable toggle and the Combat pair
    local version = exportData._v or 0
    if version < 3 then
        NRSKNUI.LoadConditions:DropEnableToggle(exportData.d)
    end
    if version < 4 then
        NRSKNUI.LoadConditions:MoveCombatToState(exportData.d)
    end

    -- Determine target profile name
    local finalName = targetName or exportData._n or 'Imported'

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
                finalName = baseName .. ' (' .. counter .. ')'
                break
            end
        end
    end

    local block = applyShared and SharedBlock(exportData.d)
    DropSharedSettings(exportData.d)

    NRSKNUI.db.profiles[finalName] = exportData.d -- new name, so no profile hop or refresh to write it
    ImportIntoNamespaces(finalName)
    if block then
        ApplyShared(block)
    end
    if activate then
        self:UseProfile(finalName)
    end

    return true, finalName
end

---Whether the new profile wants this module running.
---@param aceModule table
---@return boolean
local function ShouldRun(aceModule)
    local flag = aceModule.db and aceModule.db.Enabled
    if flag == nil then return aceModule:IsEnabled() end
    if aceModule.IsBlocked and aceModule:IsBlocked() then return false end
    return flag and true or false
end

---Re-point every module at the active profile, sync which ones run and apply the new settings.
---Fired by AceDB's profile callbacks, called directly only for changes AceDB does not announce.
function ProfileManager:RefreshAllModules()
    if suppressDepth > 0 then return end

    -- a profile switch drags every namespace onto the profile's own settings
    PointNamespaces(CurrentRole())

    -- Shared state the modules read during ApplySettings.
    SafeCall(NRSKNUI, 'LoadCustomColors')
    SafeCall(NRSKNUI, 'RefreshCurves')
    SafeCall(NRSKNUI, 'RefreshAuraDurationFormatter')

    -- Every module points at the new profile before anything is allowed to read a module db.
    -- AceDB strips default-valued keys out of the old profile table in place during SetProfile, so a
    -- module still holding the old table reads empty sub-tables and nil fields.
    for _, aceModule in NRSKNUI:IterateModules() do
        SafeCall(aceModule, 'UpdateDB')
    end

    -- Only now, on the new db. HidePreview runs a module's normal apply path, so stopping previews
    -- any earlier applies the old profile's stripped table.
    if NRSKNUI.PreviewManager then SafeCall(NRSKNUI.PreviewManager, 'StopAllPreviews') end

    -- The new profile decides which modules run. Enabling one applies its settings via OnEnable,
    -- so only modules that were already running need an explicit ApplySettings. A module that was
    -- disabled here keeps whatever it could not undo, that is accepted, a reload clears it.
    for name, aceModule in NRSKNUI:IterateModules() do
        local wasEnabled = aceModule:IsEnabled()
        local shouldRun = ShouldRun(aceModule)

        if shouldRun and not wasEnabled then
            xpcall(NRSKNUI.EnableModule, ErrorHandler, NRSKNUI, name)
        elseif wasEnabled and not shouldRun then
            xpcall(NRSKNUI.DisableModule, ErrorHandler, NRSKNUI, name)
        elseif shouldRun then
            SafeCall(aceModule, 'ApplySettings')
        end
    end

    -- Refresh GUI and previews if needed.
    SafeCall(NRSKNUI.GUI, 'ApplyTheme') -- profile-scoped, so it re-resolves after the UpdateDB pass
    if NRSKNUI.GUIFrame then SafeCall(NRSKNUI.GUIFrame, 'ApplyThemeColors') end
    if NRSKNUI.PreviewManager then SafeCall(NRSKNUI.PreviewManager, 'Refresh') end
end

-- WagoUI Integration API --

--* Global API table for WagoUI Packs compatibility
--* https://github.com/methodgg/Wago-Creator-UI/blob/main/WagoUI_Libraries/LibAddonProfiles/ImplementationGuide.lua

---Export a profile by key
---@param profileKey string The profile name to export
---@return string The encoded profile string
function NorskenUIAPI:ExportProfile(profileKey)
    if not NRSKNUI.db then return '' end

    local profileData = ExportData(profileKey, true)
    if not profileData then
        return ''
    end

    local serialized = SerializeCBOR(profileData)
    local compressed = CompressString(serialized, Enum.CompressionMethod.Deflate,
        Enum.CompressionLevel.OptimizeForSize)
    local encoded = EncodeBase64(compressed)
    return encoded or ''
end

---Import a profile from string.
---@param profileString string|table The encoded profile string, or self on a method-style call
---@param profileKey string|nil Profile name, or the string on a method-style call
---@param methodKey string|nil Profile name on a method-style call
function NorskenUIAPI.ImportProfile(profileString, profileKey, methodKey)
    if type(profileString) == 'table' then profileString, profileKey = profileKey, methodKey end -- colon call
    if type(profileString) ~= 'string' or profileString == '' then return end
    if not NRSKNUI.db then return end

    -- Prefixed strings carry the metadata envelope, so they need the full import path.
    if profileString:sub(1, #EXPORT_PREFIX) == EXPORT_PREFIX
        or profileString:sub(1, #LEGACY_PREFIX) == LEGACY_PREFIX then
        local success, nameOrError
        WithoutPrompt(function()
            success, nameOrError = ProfileManager:ImportProfile(profileString, profileKey, true, true)
        end)
        return success, nameOrError
    end

    local profileData = NorskenUIAPI:DecodeProfileString(profileString)
    if not next(profileData) then return end

    local block = SharedBlock(profileData)
    DropSharedSettings(profileData)

    -- WagoUI re-imports into the same key on every pack update, so the key is used as given.
    profileKey = (type(profileKey) == 'string' and profileKey ~= '') and profileKey or 'Imported'

    WithoutPrompt(function()
        local db = NRSKNUI.db
        local isActive = db:GetCurrentProfile() == profileKey
        if isActive then
            -- AceDB keeps serving its own table for the active profile, so refill that one.
            wipe(db.profile)
            for k, v in pairs(profileData) do
                db.profile[k] = v
            end
            db:RegisterDefaults(db.defaults)
        else
            db.profiles[profileKey] = profileData
        end
        ImportIntoNamespaces(profileKey)
        if block then
            ApplyShared(block)
        end
        if isActive then
            ProfileManager:RefreshAllModules()
        end
        ProfileManager:UseProfile(profileKey)
    end)
end

---Decode a profile string without importing
---@param profileString string The profile string to decode
---@return table The decoded profile data
function NorskenUIAPI:DecodeProfileString(profileString)
    if not profileString or profileString == '' then return {} end

    local decoded = DecodeBase64(profileString)
    if not decoded then return {} end

    local decompressed = DecompressString(decoded, Enum.CompressionMethod.Deflate)
    if not decompressed then return {} end

    local profileData = DeserializeCBOR(decompressed)
    if profileData and type(profileData) == 'table' then
        return profileData
    end

    return {}
end

---Set the active profile
---@param profileKey string The profile to activate
function NorskenUIAPI:SetProfile(profileKey)
    if not profileKey or profileKey == '' then return end
    if not NRSKNUI.db then return end

    -- AceDB no-ops (and fires nothing) when asked for the profile already active, so refresh that
    -- case by hand: WagoUI calls this right after writing profile data and expects it applied.
    WithoutPrompt(function()
        local wasCurrent = NRSKNUI.db:GetCurrentProfile() == profileKey
        ProfileManager:UseProfile(profileKey)
        if wasCurrent then ProfileManager:RefreshAllModules() end
    end)
end

---Which profile each character uses, keyed "Name - Realm". WagoUI restores alts from it.
---@return table<string, string>|nil
function NorskenUIAPI:GetProfileAssignments()
    return NRSKNUI.db and NRSKNUI.db.sv.profileKeys
end

---Get all profile keys
---@return table<string, boolean> Profile keys in format [key] = true
function NorskenUIAPI:GetProfileKeys()
    local keys = {}
    if NRSKNUI.db and NRSKNUI.db.profiles then
        for key in pairs(NRSKNUI.db.profiles) do
            keys[key] = true
        end
    end
    if not next(keys) then
        keys['Default'] = true
    end
    return keys
end

---Get current profile key
---@return string The current profile name
function NorskenUIAPI:GetCurrentProfileKey()
    if NRSKNUI.db then
        return NRSKNUI.db:GetCurrentProfile() or 'Default'
    end
    return 'Default'
end

---Open config panel
function NorskenUIAPI:OpenConfig()
    NRSKNUI:OpenOptions()
end

---Close config panel
function NorskenUIAPI:CloseConfig()
    if NRSKNUI.GUIFrame and NRSKNUI.GUIFrame.Hide then
        NRSKNUI.GUIFrame:Hide()
    end
end

-- Profile Installer API --

--[[ Example usage:

*    local profileString = 'YOUR_PROFILE_STRING_HERE' -- Should look like '!NRSKNUI2!...' or '!NRSKNUI1!...'
*    local targetProfileName = 'MyImportedProfile'    -- Optional, can be nil to use the embedded name

*    NorskenUIAPI.ImportProfile(profileString, targetProfileName)

* Profile imports done by a profile installer switch to the imported profile the way the user's profile mode assigns
* profiles: this character, the current specialization, or the global profile.
]]

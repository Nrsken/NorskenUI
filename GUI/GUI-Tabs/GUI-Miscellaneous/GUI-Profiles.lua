---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local pairs = pairs
local ipairs = ipairs
local format = string.format
local GetNumSpecializations = GetNumSpecializations
local GetSpecializationInfo = GetSpecializationInfo
local GetSpecialization = GetSpecialization

local function BuildProfileOptions()
    local PM = NRSKNUI.ProfileManager
    local options = {}
    if not PM then return options end
    for _, name in pairs(PM:GetProfiles()) do
        options[name] = name
    end
    return options
end

local function GetSpecInfo()
    local specs = {}
    local numSpecs = GetNumSpecializations()
    local currentSpec = GetSpecialization()
    for i = 1, numSpecs do
        local _, name = GetSpecializationInfo(i)
        specs[i] = { index = i, name = name, isCurrent = (i == currentSpec) }
    end
    return specs
end

-- Profiles tab.
local function BuildProfilesTab(page, PM)
    local db = NRSKNUI.db
    local hasSpecFeature = db and db.IsDualSpecEnabled

    page:SetCondition('notGlobal', function() return not PM:GetUseGlobalProfile() end)
    page:SetCondition('globalOn', function() return PM:GetUseGlobalProfile() end)
    page:SetCondition('specOn', function() return hasSpecFeature and db:IsDualSpecEnabled() or false end)
    page:SetCondition('notSpec', function() return not (hasSpecFeature and db:IsDualSpecEnabled()) end)

    -- Current profile
    local currentCard = page:Card(L['Current Profile'])
    currentCard:Row(rowHL, 0):Dropdown(L['Active Profile'], {
        width = 1,
        conditions = { 'notGlobal', 'notSpec' },
        options = BuildProfileOptions(),
        value = PM:GetCurrentProfile(),
        -- No reload prompt here: ProfileManager raises one for any change to the active profile,
        -- including the resets, copies and spec swaps that never passed through this page.
        callback = function(key)
            if key == PM:GetCurrentProfile() then return end
            local success, err = PM:SetProfile(key)
            if not success then
                NRSKNUI:Print(format(L['Failed to switch profile: %s'], err or L['Unknown error']))
            end
        end,
    })

    -- Global profile.
    local globalCard = page:Card(L['Global Profile'])
    local globalRow = globalCard:Row(rowHL, 0)
    globalRow:Checkbox(L['Use Global Profile'], {
        width = 0.5,
        value = PM:GetUseGlobalProfile(),
        callback = function(checked)
            if not PM:SetUseGlobalProfile(checked) then return end
            page:Refresh()
            NRSKNUI:Print(checked and L['Global profile mode enabled.'] or L['Global profile mode disabled'])
        end,
    })
    globalRow:Dropdown(L['Global Profile'], {
        width = 0.5,
        conditions = { 'globalOn' },
        options = BuildProfileOptions(),
        value = PM:GetGlobalProfile(),
        callback = function(key)
            local success, err = PM:SetGlobalProfile(key)
            if not success then
                NRSKNUI:Print(format(L['Failed to set global profile: %s'], err or L['Unknown error']))
            else
                NRSKNUI:Print(format(L['Global profile set to: %s'], key))
            end
        end,
    })

    -- Specialization profiles
    if hasSpecFeature then
        local specCard = page:Card(L['Specialization Profiles'])
        local toggleRow = specCard:Row(rowH)
        toggleRow:Checkbox(L['Enable Spec Profiles'], {
            width = 0.5,
            conditions = { 'notGlobal' },
            value = db:IsDualSpecEnabled(),
            callback = function(checked)
                PM:SetSpecProfilesEnabled(checked)
                page:Refresh()
            end,
        })

        specCard:Separator()

        local specs = GetSpecInfo()
        local numSpecs = #specs
        local widthPerSpec = numSpecs == 2 and 0.5 or (numSpecs == 3 and (1 / 3) or 0.25)
        local specRow = specCard:Row(rowHL, 0)
        for _, spec in ipairs(specs) do
            local label = spec.isCurrent and (spec.name .. " " .. L['(Active)']) or spec.name
            specRow:Dropdown(label, {
                width = widthPerSpec,
                conditions = { 'notGlobal', 'specOn' },
                options = BuildProfileOptions(),
                value = db:GetDualSpecProfile(spec.index),
                callback = function(key)
                    db:SetDualSpecProfile(key, spec.index)
                end,
            })
        end
    end
end

-- Profile management tab: create, copy, rename, delete.
local function BuildManageTab(page, PM)
    local optionDropdowns = {}
    local resetCard

    local function RefreshProfiles()
        local options = BuildProfileOptions()
        for _, dropdown in ipairs(optionDropdowns) do dropdown:SetOptions(options) end
        if resetCard then resetCard:Rebuild() end
    end

    -- Reset
    resetCard = page:Card(L['Reset Profile'])
    resetCard:Rebuild(function(card)
        local row = card:Row(rowHL - 9, 0)
        row:Text(L['Current Profile: '] .. NRSKNUI:ColorTextByTheme(PM:GetCurrentProfile()), {
            width = 0.5,
            height = rowHL - 9,
            bgMode = 'hide',
            yOffset = -6,
        })
        row:Button(L['Reset to Defaults'], {
            width = 0.5,
            height = 30,
            yOffset = -2,
            callback = function()
                NRSKNUI:CreatePrompt({
                    title = L['Reset Profile'],
                    text = L['Reset all settings in current profile to defaults?\nThis cannot be undone.'],
                    onAccept = function()
                        if not PM:ResetProfile() then NRSKNUI:Print(L['Failed to reset profile']) end
                    end,
                    acceptText = L['Reset'],
                    cancelText = L['Cancel'],
                })
            end,
        })
    end)

    -- Create
    local createCard = page:Card(L['Create New Profile'])
    local createRow = createCard:Row(rowHL, 0)
    local newProfileInput = createRow:EditBox(L['Profile Name'], { width = 0.5, value = "" })
    createRow:Button(L['Create'], {
        width = 0.5,
        height = 24,
        yOffset = -14,
        callback = function()
            local name = newProfileInput:GetValue()
            if not name or name == "" then
                NRSKNUI:Print(L['Please enter a profile name'])
                return
            end
            local success, err = PM:CreateProfile(name)
            if success then
                NRSKNUI:Print(format(L['Created profile: %s'], name))
                newProfileInput:SetValue("")
                RefreshProfiles()
            else
                NRSKNUI:Print(format(L['Failed to create profile: %s'], err or L['Unknown error']))
            end
        end,
    })

    -- Copy
    local copyCard = page:Card(L['Copy Profile'])
    local copyRow = copyCard:Row(rowHL, 0)
    local copyDropdown = copyRow:Dropdown(L['Source Profile'], {
        width = 0.5,
        options = BuildProfileOptions(),
        value = "",
    })
    optionDropdowns[#optionDropdowns + 1] = copyDropdown
    copyRow:Button(L['Copy'], {
        width = 0.5,
        height = 24,
        yOffset = -14,
        callback = function()
            local source = copyDropdown:GetValue()
            if not source or source == "" then
                NRSKNUI:Print(L['Please select a source profile'])
                return
            end
            NRSKNUI:CreatePrompt({
                title = L['Copy Profile'],
                text = format(L["Copy all settings from '%s' to current profile?\nThis will overwrite your current settings."], source),
                onAccept = function()
                    local success, err = PM:CopyProfile(source)
                    if not success then NRSKNUI:Print(format(L['Failed to copy profile: %s'], err or L['Unknown error'])) end
                end,
                acceptText = L['Copy'],
                cancelText = L['Cancel'],
            })
        end,
    })

    -- Rename
    local renameCard = page:Card(L['Rename Profile'])
    local renameDropdown = renameCard:Row(rowH):Dropdown(L['Profile to Rename'], {
        width = 1,
        options = BuildProfileOptions(),
        value = "",
    })
    optionDropdowns[#optionDropdowns + 1] = renameDropdown
    local renameRow = renameCard:Row(rowHL, 0)
    local newNameInput = renameRow:EditBox(L['New Name'], { width = 0.5, value = "" })
    renameRow:Button(L['Rename'], {
        width = 0.5,
        height = 24,
        yOffset = -14,
        callback = function()
            local oldName = renameDropdown:GetValue()
            local newName = newNameInput:GetValue()
            if not oldName or oldName == "" then
                NRSKNUI:Print(L['Please select a profile to rename'])
                return
            end
            if not newName or newName == "" then
                NRSKNUI:Print(L['Please enter a new name'])
                return
            end
            local success, err = PM:RenameProfile(oldName, newName)
            if success then
                NRSKNUI:Print(format(L["Renamed '%s' to '%s'"], oldName, newName))
                newNameInput:SetValue("")
                RefreshProfiles()
            else
                NRSKNUI:Print(format(L['Failed to rename: %s'], err or L['Unknown error']))
            end
        end,
    })

    -- Delete
    local deleteCard = page:Card(L['Delete Profile'])
    local deleteRow = deleteCard:Row(rowHL, 0)
    local deleteDropdown = deleteRow:Dropdown(L['Profile to Delete'], {
        width = 0.5,
        options = BuildProfileOptions(),
        value = "",
    })
    optionDropdowns[#optionDropdowns + 1] = deleteDropdown
    deleteRow:Button(L['Delete'], {
        width = 0.5,
        height = 24,
        yOffset = -14,
        callback = function()
            local toDelete = deleteDropdown:GetValue()
            if not toDelete or toDelete == "" then
                NRSKNUI:Print(L['Please select a profile to delete'])
                return
            end
            if toDelete == PM:GetCurrentProfile() then
                NRSKNUI:Print(L['Cannot delete the active profile'])
                return
            end
            NRSKNUI:CreatePrompt({
                title = L['Delete Profile'],
                text = format(L["Are you sure you want to delete '%s'?\nThis cannot be undone."], toDelete),
                onAccept = function()
                    local success, err = PM:DeleteProfile(toDelete)
                    if success then
                        NRSKNUI:Print(format(L['Deleted profile: %s'], toDelete))
                        RefreshProfiles()
                    else
                        NRSKNUI:Print(format(L['Failed to delete profile: %s'], err or L['Unknown error']))
                    end
                end,
                acceptText = L['Delete'],
                cancelText = L['Cancel'],
            })
        end,
    })
end

-- Profile sharing tab: import/export.
local function BuildSharingTab(page, PM)
    -- Export
    local exportCard = page:Card(L['Export Profile'])
    exportCard:Row(rowHL - 9, 0):Button(L['Export Current Profile'], {
        width = 1,
        height = 30,
        yOffset = -2,
        callback = function()
            local exportString, err = PM:ExportProfile()
            if exportString then
                NRSKNUI:CreateCopyDialog(L['Export Profile'], exportString, L['Copy the string above (Ctrl+C)'])
                NRSKNUI:Print(L['Export Success'])
            else
                NRSKNUI:Print(format(L['Export failed: %s'], err or L['Unknown error']))
            end
        end,
    })

    -- Import
    local importCard = page:Card(L['Import Profile'])
    importCard:Row(rowHL - 9, 0):Button(L['Import from String'], {
        width = 1,
        height = 30,
        yOffset = -2,
        callback = function()
            NRSKNUI:CreatePrompt({
                title = L['Import Profile'],
                text = "",
                editBox = true,
                editBoxLabel = L['Paste import string'],
                onAccept = function(importString)
                    if not importString or importString == "" then return end
                    NRSKNUI:CreatePrompt({
                        title = L['Profile Name'],
                        text = "",
                        editBox = true,
                        editBoxLabel = L['Enter profile name (leave empty for original)'],
                        onAccept = function(profileName)
                            local targetName = (profileName and profileName ~= "") and profileName or nil
                            local success, nameOrErr = PM:ImportProfile(importString, targetName)
                            if success then
                                NRSKNUI:Print(format(L['Imported profile: %s'], nameOrErr))
                            else
                                NRSKNUI:Print(format(L['Import failed: %s'], nameOrErr or L['Unknown error']))
                            end
                        end,
                        acceptText = L['Import'],
                        cancelText = L['Cancel'],
                    })
                end,
                acceptText = L['Next'],
                cancelText = L['Cancel'],
            })
        end,
    })
end

GUI:RegisterPage('profilePage', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'profiles', text = L['Profiles'] },
        { id = 'manage',   text = L['Manage'] },
        { id = 'sharing',  text = L['Import/Export'] },
    },
    build = function(page, tabId)
        local PM = NRSKNUI.ProfileManager
        if not PM then
            page:Card(L['Profiles']):Row(rowH, 0):Text(L['Error'], {
                width = 1,
                text = L['Profile manager is not available.'],
                height = rowH,
                bgMode = 'hide',
            })
            return
        end

        if tabId == 'profiles' then
            BuildProfilesTab(page, PM)
        elseif tabId == 'manage' then
            BuildManageTab(page, PM)
        elseif tabId == 'sharing' then
            BuildSharingTab(page, PM)
        end
    end,
})

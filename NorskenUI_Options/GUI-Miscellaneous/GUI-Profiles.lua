---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local pairs = pairs
local ipairs = ipairs
local format = string.format
local sort = table.sort
local rad = math.rad
local strtrim = strtrim
local GetNumSpecializations = GetNumSpecializations
local GetSpecializationInfo = GetSpecializationInfo
local GetSpecialization = GetSpecialization

local BUTTON_ROW_HEIGHT = 30
local SPEC_ROW_HEIGHT = 30
local SPEC_ICON_SIZE = 22
local RADIO_ROW_HEIGHT = 32
local RADIO_INDENT = 22 -- the dot plus its gap, so nested rows line up under the option title
local GROUP_GAP = 12
local TEX = 'Interface\\AddOns\\NorskenCore\\Media\\GUITextures\\'
local DELETE_COLOR = { 1, 0, 0 }

local MODES = {
    { id = 'char',   text = L['This Character'],     hint = L['This character uses one profile in every specialization.'] },
    { id = 'spec',   text = L['Per Specialization'], hint = L['Changing specialization switches to its profile.'] },
    { id = 'global', text = L['Global Profile'],     hint = L['Every character uses the same profile.'] },
}

---@param exclude? table<string, true>
---@return table<string, string>
local function BuildProfileOptions(exclude)
    local options = {}
    for _, name in pairs(NRSKNUI.ProfileManager:GetProfiles()) do
        if not (exclude and exclude[name]) then options[name] = name end
    end
    return options
end

---Reset, rename and delete icons on every profile row; delete is greyed out while anything uses the profile.
---@param PM table
---@param rebuildAll fun()
---@return fun(name: string): KajiGUIDropdownItemAction[]
local function ProfileActions(PM, rebuildAll)
    return function(name)
        local users = PM:GetProfileUsers()[name]
        local usedBy
        if users then
            local chars = NRSKNUI.db.sv.char
            usedBy = { L['In use by:'] }
            sort(users)
            for _, who in ipairs(users) do
                local charName = who:match('^(.-) %- ') -- "Name - Realm"; the global profile entry has no realm
                local class = charName and chars and chars[who] and chars[who].Class
                usedBy[#usedBy + 1] = class and NRSKNUI:ColorTextByClass(charName, class) or charName or who
            end
        end

        return {
            {
                icon = TEX .. 'profile-reset.png',
                tooltip = L['Reset Profile'],
                onClick = function()
                    NRSKNUI:CreatePrompt({
                        title = L['Reset Profile'],
                        text = format(L["Reset all settings in '%s' to defaults?\nThis cannot be undone."], name),
                        onAccept = function() PM:ResetProfile(name) end,
                        acceptText = L['Reset'],
                        cancelText = L['Cancel'],
                    })
                end,
            },
            {
                icon = TEX .. 'profile-rename.png',
                tooltip = L['Rename Profile'],
                onClick = function()
                    NRSKNUI:CreatePrompt({
                        title = L['Rename Profile'],
                        text = name,
                        editBox = true,
                        editBoxLabel = L['New Name'],
                        onAccept = function(newName)
                            newName = strtrim(newName or '')
                            if newName == '' or newName == name then return end
                            local ok, err = PM:RenameProfile(name, newName)
                            if not ok then
                                NRSKNUI:Print(format(L['Failed to rename: %s'], err or L['Unknown error']))
                                return
                            end
                            rebuildAll()
                        end,
                        acceptText = L['Rename'],
                        cancelText = L['Cancel'],
                    })
                end,
            },
            {
                icon = TEX .. 'NorskenCustomCrossv3.png', -- same cross, tint and rotation as skinned close buttons
                color = DELETE_COLOR,
                rotation = rad(45),
                tooltip = L['Delete Profile'],
                tooltipText = usedBy,
                disabled = users ~= nil,
                onClick = function()
                    NRSKNUI:CreatePrompt({
                        title = L['Delete Profile'],
                        text = format(L["Are you sure you want to delete '%s'?\nThis cannot be undone."], name),
                        onAccept = function()
                            local ok, err = PM:DeleteProfile(name)
                            if not ok then
                                NRSKNUI:Print(format(L['Failed to delete profile: %s'], err or L['Unknown error']))
                                return
                            end
                            rebuildAll()
                        end,
                        acceptText = L['Delete'],
                        cancelText = L['Cancel'],
                    })
                end,
            },
        }
    end
end

---@param card KajiGUIFluentCard
---@param PM table
---@param rebuildAll fun()
local function BuildActiveCard(card, PM, rebuildAll)
    local db = NRSKNUI.db
    local mode = PM:GetProfileMode()
    local currentSpec = GetSpecialization()
    local actions = ProfileActions(PM, rebuildAll)

    local previous
    for i, info in ipairs(MODES) do
        local selected = mode == info.id
        local isLast = i == #MODES
        local radio = card:Row(RADIO_ROW_HEIGHT, isLast and not selected and 0 or nil):Radio(info.text, {
            width = 1,
            description = info.hint,
            selected = selected,
            linkTo = previous,
            callback = function()
                local function Apply()
                    PM:SetProfileMode(info.id)
                    rebuildAll()
                end
                if info.id ~= 'global' and mode ~= 'global' then return Apply() end

                NRSKNUI:CreatePrompt({
                    title = L['Global Profile'],
                    text = info.id == 'global'
                        and format(L['Use %s on every character?\nOther characters switch the next time they log in.'], PM:GetGlobalProfile())
                        or L['Turn off the global profile?\nEvery character goes back to its own choice.'],
                    onAccept = Apply,
                    onCancel = function() card:Rebuild() end, -- the clicked option already drew itself selected
                    acceptText = L['Confirm'],
                    cancelText = L['Cancel'],
                })
            end,
        }) --[[@as KajiGUIRadio]]
        if info.id == 'spec' and not PM:CanUseSpecProfiles() then radio:SetEnabled(false) end
        previous = radio

        if selected then
            local gap = isLast and 0 or GROUP_GAP
            if mode == 'char' then
                card:Row(rowHL, gap, RADIO_INDENT):Dropdown(L['Profile'], {
                    width = 0.5,
                    options = BuildProfileOptions(),
                    value = PM:GetCurrentProfile(),
                    itemActions = actions,
                    callback = function(key)
                        PM:SetProfile(key)
                        rebuildAll()
                    end,
                })
            elseif mode == 'global' then
                card:Row(rowHL, gap, RADIO_INDENT):Dropdown(L['Profile for All Characters'], {
                    width = 0.5,
                    options = BuildProfileOptions(),
                    value = PM:GetGlobalProfile(),
                    itemActions = actions,
                    callback = function(key)
                        PM:SetGlobalProfile(key)
                        rebuildAll()
                    end,
                })
            else
                local numSpecs = GetNumSpecializations()
                for spec = 1, numSpecs do
                    local _, name, _, icon = GetSpecializationInfo(spec)
                    if spec == currentSpec then
                        name = NRSKNUI:ColorTextByTheme(name) .. ' ' .. NRSKNUI:ColorText(L['(Active)'], Theme.textMuted)
                    end
                    local row = card:Row(SPEC_ROW_HEIGHT, spec == numSpecs and gap or nil, RADIO_INDENT)
                    row:Dropdown(nil, {
                        width = 0.5,
                        yOffset = 14 - (SPEC_ROW_HEIGHT - 24) / 2, -- no label, so lift the box level with the icon
                        options = BuildProfileOptions(),
                        value = db:GetDualSpecProfile(spec),
                        itemActions = actions,
                        callback = function(key)
                            db:SetDualSpecProfile(key, spec)
                            rebuildAll()
                        end,
                    })
                    row:Icon({
                        width = 0.5,
                        size = SPEC_ICON_SIZE,
                        yOffset = -(SPEC_ROW_HEIGHT - SPEC_ICON_SIZE) / 2, -- Icon sizes to itself and sits at the row top
                        texture = icon,
                        text = { text = name, position = 'RIGHT' },
                    })
                end
            end
        end
    end
end

---@param card KajiGUIFluentCard
---@param PM table
---@param rebuildAll fun()
local function BuildCreateCard(card, PM, rebuildAll)
    local profiles = BuildProfileOptions()
    local newName, source = '', ''
    local createButton

    local row = card:Row(rowH)
    row:EditBox(L['Profile Name'], {
        width = 0.5,
        onTextChanged = function(text)
            newName = strtrim(text)
            createButton:SetEnabled(newName ~= '' and not profiles[newName])
        end,
    })
    local startFrom = BuildProfileOptions()
    startFrom[''] = L['Defaults']
    row:Dropdown(L['Start From'], {
        width = 0.5,
        options = startFrom,
        value = '',
        callback = function(key) source = key end,
    })

    createButton = card:Row(BUTTON_ROW_HEIGHT, 0):Button(L['Create'], {
        width = 1,
        height = BUTTON_ROW_HEIGHT - 4,
        callback = function()
            local ok, err = PM:CreateProfile(newName, source ~= '' and source or nil)
            if not ok then
                NRSKNUI:Print(format(L['Failed to create profile: %s'], err or L['Unknown error']))
                return
            end
            rebuildAll()
        end,
    }) --[[@as KajiGUIButton]]
    createButton:SetEnabled(false)
end

---@param card KajiGUIFluentCard
---@param PM table
local function BuildCopyCard(card, PM)
    local from, to = nil, PM:GetCurrentProfile()
    local copyButton
    local function UpdateButton() copyButton:SetEnabled(from ~= nil and from ~= to) end

    local row = card:Row(rowH)
    row:Dropdown(L['Copy From'], {
        width = 0.5,
        options = BuildProfileOptions(),
        callback = function(key)
            from = key
            UpdateButton()
        end,
    })
    row:Dropdown(L['Copy Into'], {
        width = 0.5,
        options = BuildProfileOptions(),
        value = to,
        callback = function(key)
            to = key
            UpdateButton()
        end,
    })

    copyButton = card:Row(BUTTON_ROW_HEIGHT, 0):Button(L['Copy'], {
        width = 1,
        height = BUTTON_ROW_HEIGHT - 4,
        callback = function()
            NRSKNUI:CreatePrompt({
                title = L['Copy Profile'],
                text = format(L["Copy all settings from '%s' into '%s'?\nThis overwrites every setting in '%s'."], from, to, to),
                onAccept = function()
                    local ok, err = PM:CopyProfile(from, to)
                    if not ok then NRSKNUI:Print(format(L['Failed to copy profile: %s'], err or L['Unknown error'])) end
                end,
                acceptText = L['Copy'],
                cancelText = L['Cancel'],
            })
        end,
    }) --[[@as KajiGUIButton]]
    copyButton:SetEnabled(false)
end

local function BuildProfilesTab(page, PM)
    local activeCard, createCard, copyCard
    local function RebuildAll()
        activeCard:Rebuild()
        createCard:Rebuild()
        copyCard:Rebuild()
    end

    activeCard = page:Card(L['Active Profile']):Rebuild(function(card) BuildActiveCard(card, PM, RebuildAll) end)
    createCard = page:Card(L['Create Profile']):Rebuild(function(card) BuildCreateCard(card, PM, RebuildAll) end)
    copyCard = page:Card(L['Copy Profile']):Rebuild(function(card) BuildCopyCard(card, PM) end)
end

local includeShared = true

local function ImportString(PM, importString, targetName, applyShared)
    local success, nameOrErr = PM:ImportProfile(importString, targetName, true, applyShared)
    if success then
        NRSKNUI:Print(format(L['Imported profile: %s'], nameOrErr))
    else
        NRSKNUI:Print(format(L['Import failed: %s'], nameOrErr or L['Unknown error']))
    end
end

-- Profile sharing tab: import/export.
local function BuildSharingTab(page, PM)
    -- Export
    local exportCard = page:Card(L['Export Profile'])
    exportCard:Row(rowH):Checkbox(L['Include Shared Settings'], {
        width = 1,
        value = includeShared,
        tooltip = L['Adds your fonts, textures and colors to the string.'],
        callback = function(checked)
            includeShared = checked
        end,
    })
    exportCard:Row(rowHL - 9, 0):Button(L['Export Current Profile'], {
        width = 1,
        height = 30,
        yOffset = -2,
        callback = function()
            local exportString, err = PM:ExportProfile(nil, includeShared)
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
                            if not PM:CarriesSharedSettings(importString) then
                                ImportString(PM, importString, targetName, false)
                                return
                            end

                            -- closing this one keeps them: the import was already confirmed, the settings weren't
                            NRSKNUI:CreatePrompt({
                                title = L['Shared Settings'],
                                text = L['This string also holds fonts, textures and colors. Use them for every Norsken addon?'],
                                onAccept = function() ImportString(PM, importString, targetName, true) end,
                                onCancel = function() ImportString(PM, importString, targetName, false) end,
                                acceptText = L['Use Them'],
                                cancelText = L['Keep Mine'],
                            })
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
        elseif tabId == 'sharing' then
            BuildSharingTab(page, PM)
        end
    end,
})

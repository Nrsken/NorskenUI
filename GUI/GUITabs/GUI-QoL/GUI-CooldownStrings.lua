---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local table_insert = table.insert
local pairs, ipairs = pairs, ipairs
local GetNumSpecializationsForClassID = C_SpecializationInfo.GetNumSpecializationsForClassID
local GetSpecializationInfoForClassID = GetSpecializationInfoForClassID
local GetNumClasses = GetNumClasses
local GetClassInfo = GetClassInfo
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local C_Timer = C_Timer

local SIDEBAR_WIDTH = 192
local ITEM_HEIGHT = 34
local BUTTON_HEIGHT = 28
local LIST_PADDING = 4

local function BuildSpecList()
    local specs = {}
    for classID = 1, GetNumClasses() do
        local className, classFile = GetClassInfo(classID)
        if className and classFile then
            local numSpecs = GetNumSpecializationsForClassID(classID)
            for specIndex = 1, numSpecs do
                local specID, specName, _, specIcon = GetSpecializationInfoForClassID(classID, specIndex)
                if specID then
                    table_insert(specs, {
                        key = specID,
                        text = className .. " - " .. specName,
                        class = classFile,
                        icon = specIcon,
                    })
                end
            end
        end
    end
    table.sort(specs, function(a, b) return a.text < b.text end)
    return specs
end

local selectedProfileName = nil

GUIFrame:RegisterPanel("CooldownStrings", function(container)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.CooldownStrings
    if not db then return end
    if not db.Profiles then db.Profiles = {} end

    local mod = NRSKNUI:GetModule("CooldownStrings", true)

    local allSpecList = BuildSpecList()
    local allWidgets = {}

    local function ApplyModuleState(enabled)
        if not mod then return end
        mod.db.Enabled = enabled
        if enabled then
            NRSKNUI:EnableModule("CooldownStrings")
        else
            NRSKNUI:DisableModule("CooldownStrings")
        end
    end

    local function RefreshContent()
        C_Timer.After(0.05, function()
            GUIFrame:RefreshContent()
        end)
    end

    local function SyncWithModule()
        if mod and mod.RefreshPanel then
            mod:RefreshPanel()
        end
    end

    local function UpdateAllWidgetStates()
        local mainEnabled = db.Enabled ~= false
        for _, widget in ipairs(allWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(mainEnabled)
            end
        end
    end

    if selectedProfileName and not db.Profiles[selectedProfileName] then
        selectedProfileName = nil
    end
    if not selectedProfileName then
        for name in pairs(db.Profiles) do
            selectedProfileName = name
            break
        end
    end

    local function GetAllProfiles()
        local profiles = {}
        for name, profileData in pairs(db.Profiles) do
            local specInfo = mod and profileData.SpecID and mod.GetSpecInfoByID(profileData.SpecID)
            local className = specInfo and specInfo.class or "ZZZZZ"
            table_insert(profiles, { key = name, name = name, data = profileData, className = className, specInfo = specInfo })
        end
        table.sort(profiles, function(a, b)
            if a.className ~= b.className then
                return a.className < b.className
            end
            return a.name < b.name
        end)
        return profiles
    end

    local function GetSpecDropdownOptions()
        local options = {}
        for _, spec in ipairs(allSpecList) do
            local color = spec.class and RAID_CLASS_COLORS[spec.class]
            table_insert(options, { key = spec.key, text = spec.text, color = color })
        end
        return options
    end

    local miniSidebar = NRSKNUI.GUI.CreateMiniSidebar(container, {
        sidebarWidth = SIDEBAR_WIDTH,
        listPadding = LIST_PADDING,
        itemHeight = ITEM_HEIGHT,

        getItems = GetAllProfiles,
        getItemKey = function(item) return item.name end,

        renderItem = function(btn, item, isSelected)
            local specInfo = item.specInfo
            if specInfo and specInfo.icon then
                btn._icon:SetTexture(specInfo.icon)
                btn._icon:SetZoom()
            else
                btn._icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            btn._label:SetText(item.name)
            if specInfo and specInfo.class and RAID_CLASS_COLORS[specInfo.class] then
                local cc = RAID_CLASS_COLORS[specInfo.class]
                local alpha = isSelected and 1 or 0.7
                btn._label:SetTextColor(cc.r, cc.g, cc.b, alpha)
            else
                if isSelected then
                    btn._label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                else
                    btn._label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
                end
            end
        end,

        onItemSelected = function(item)
            selectedProfileName = item.name
            RefreshContent()
        end,

        buttonArea = {
            buttonHeight = BUTTON_HEIGHT,
            buttons = {
                {
                    text = "New Profile",
                    onClick = function()
                        NRSKNUI:CreatePrompt({
                            title = "New CDM Profile",
                            text = "",
                            editBox = true,
                            editBoxLabel = "Enter a name for this profile",
                            onAccept = function(inputText)
                                if inputText and inputText ~= "" then
                                    if db.Profiles[inputText] then
                                        NRSKNUI:Print("Profile '" .. inputText .. "' already exists.")
                                        return
                                    end
                                    db.Profiles[inputText] = {
                                        String = "",
                                        Created = nil,
                                        SpecID = nil,
                                    }
                                    selectedProfileName = inputText
                                    SyncWithModule()
                                    RefreshContent()
                                end
                            end,
                            acceptText = "Create",
                            cancelText = "Cancel",
                        })
                    end,
                },
            },
        },
    })

    miniSidebar.SelectItem(selectedProfileName)
    miniSidebar.RefreshList()

    local contentChild = miniSidebar.contentArea.scrollChild
    local selectedProfile = selectedProfileName and db.Profiles[selectedProfileName]

    local yOffset = Theme.paddingSmall

    local card1 = GUIFrame:CreateCard(contentChild, "CDM Profile Strings", yOffset)
    miniSidebar.contentArea.RegisterCard(card1)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable CDM Profile Strings", {
        value = db.Enabled ~= false,
        callback = function(checked)
            db.Enabled = checked
            ApplyModuleState(checked)
            UpdateAllWidgetStates()
        end,
        msgPopup = true, msgText = "CDM Profile Strings", msgOn = "On", msgOff = "Off"
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    if selectedProfile then
        local card2 = GUIFrame:CreateCard(contentChild, "Profile Editor", yOffset)
        miniSidebar.contentArea.RegisterCard(card2)
        table_insert(allWidgets, card2)

        local nameRow = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
        local nameEdit = GUIFrame:CreateEditBox(nameRow, "Profile Name", {
            value = selectedProfileName,
            callback = function(text)
                if text and text ~= "" and text ~= selectedProfileName then
                    if db.Profiles[text] then
                        NRSKNUI:Print("Profile '" .. text .. "' already exists.")
                        return
                    end
                    db.Profiles[text] = db.Profiles[selectedProfileName]
                    db.Profiles[selectedProfileName] = nil
                    selectedProfileName = text
                    SyncWithModule()
                    RefreshContent()
                end
            end
        })
        nameRow:AddWidget(nameEdit, 1)
        table_insert(allWidgets, nameEdit)
        card2:AddRow(nameRow, Theme.rowHeight)

        local specRow = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
        local specDropdown = GUIFrame:CreateDropdown(specRow, "Specialization", {
            options = GetSpecDropdownOptions(),
            value = selectedProfile.SpecID,
            callback = function(key)
                if selectedProfileName and db.Profiles[selectedProfileName] then
                    db.Profiles[selectedProfileName].SpecID = key
                    SyncWithModule()
                    RefreshContent()
                end
            end,
            searchable = true
        })
        specRow:AddWidget(specDropdown, 1)
        table_insert(allWidgets, specDropdown)
        card2:AddRow(specRow, Theme.rowHeight)

        local sepRow = GUIFrame:CreateRow(card2.content, Theme.rowHeightSeparator)
        local sepWidget = GUIFrame:CreateSeparator(sepRow)
        sepRow:AddWidget(sepWidget, 1)
        card2:AddRow(sepRow, Theme.rowHeightSeparator)

        local stringRow = GUIFrame:CreateRow(card2.content)
        local stringEdit = GUIFrame:CreateMultiLineEditBox(stringRow, "Profile String (paste CDM export)", {
            value = selectedProfile.String or "",
            height = 140,
            tooltip = "CTRL+V to paste, CTRL+A to select all",
            callback = function(text)
                if selectedProfileName and db.Profiles[selectedProfileName] then
                    db.Profiles[selectedProfileName].String = text
                    SyncWithModule()
                end
            end,
        })
        stringRow:AddWidget(stringEdit, 1)
        table_insert(allWidgets, stringEdit)
        card2:AddRow(stringRow, stringEdit.rowHeight)

        local btnRow = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
        local applyBtn = GUIFrame:CreateButton(btnRow, "Apply to CDM", {
            height = 38,
            callback = function()
                if not mod then return end
                mod.ApplyProfileToCDM(selectedProfile.String or "", selectedProfileName, {
                    onConflict = function(proceed)
                        NRSKNUI:CreatePrompt({
                            title = "Replace CDM Profile",
                            text = "'" .. selectedProfileName .. "' exists in CDM. Replace?",
                            onAccept = proceed,
                            acceptText = "Replace",
                            cancelText = "Cancel",
                        })
                    end,
                    onLayoutsFull = function()
                        NRSKNUI:Print("CDM layout limit reached.")
                    end,
                })
            end,
        })
        btnRow:AddWidget(applyBtn, 0.5)
        table_insert(allWidgets, applyBtn)

        local deleteBtn = GUIFrame:CreateButton(btnRow, "Delete", {
            height = 38,
            callback = function()
                NRSKNUI:CreatePrompt({
                    title = "Delete Profile",
                    text = "Delete '" .. selectedProfileName .. "'?",
                    onAccept = function()
                        db.Profiles[selectedProfileName] = nil
                        selectedProfileName = nil
                        for n in pairs(db.Profiles) do
                            selectedProfileName = n
                            break
                        end
                        SyncWithModule()
                        RefreshContent()
                    end,
                    acceptText = "Delete",
                    cancelText = "Cancel",
                })
            end,
        })
        btnRow:AddWidget(deleteBtn, 0.5)
        table_insert(allWidgets, deleteBtn)
        card2:AddRow(btnRow, Theme.rowHeightLast, 0)

        yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall
    else
        local card2 = GUIFrame:CreateCard(contentChild, "Profile Editor", yOffset)
        miniSidebar.contentArea.RegisterCard(card2)
        card2:AddLabel("No profiles. Click '+ New Profile' to create one.")
        yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall
    end

    miniSidebar.contentArea.SetContentHeight(yOffset)
    C_Timer.After(0, function()
        miniSidebar.contentArea.UpdateScrollBarVisibility()
        miniSidebar.contentArea.UpdateCardWidths()
    end)

    UpdateAllWidgetStates()

    return miniSidebar.panel
end)

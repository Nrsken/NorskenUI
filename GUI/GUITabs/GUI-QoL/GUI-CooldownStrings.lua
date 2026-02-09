-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization
local table_insert = table.insert
local pairs, ipairs = pairs, ipairs
local CreateFrame = CreateFrame
local time = time

-- Get module reference
local function GetModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("CooldownStrings", true)
    end
    return nil
end

-- Persistent selected profile across refreshes
local selectedProfileName = nil

-- Register CooldownStrings tab content
GUIFrame:RegisterContent("CooldownStrings", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.CooldownStrings
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Ensure Profiles table exists
    if not db.Profiles then db.Profiles = {} end

    local allWidgets = {}

    local function ApplyModuleState(enabled)
        local mod = GetModule()
        if not mod then return end
        mod.db.Enabled = enabled
        if enabled then
            NRSKNUI.Addon:EnableModule("CooldownStrings")
        else
            NRSKNUI.Addon:DisableModule("CooldownStrings")
        end
    end

    local function RefreshContent()
        C_Timer.After(0.1, function()
            GUIFrame:RefreshContent()
        end)
    end

    local function SyncWithModule()
        local mod = GetModule()
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

    -- Build profile dropdown list
    local function GetProfileList()
        local list = {}
        for name, data in pairs(db.Profiles) do
            table_insert(list, {
                key = name,
                text = name,
            })
        end
        -- Sort alphabetically
        table.sort(list, function(a, b) return a.text < b.text end)
        return list
    end

    -- Validate selected profile still exists
    if selectedProfileName then
        if not db.Profiles[selectedProfileName] then
            selectedProfileName = nil
        end
    end

    -- Get selected profile data
    local selectedProfile = selectedProfileName and db.Profiles[selectedProfileName] or nil

    ----------------------------------------------------------------
    -- Card 1: Enable CDM Profile Strings
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "CDM Profile Strings", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable CDM Profile Strings", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplyModuleState(checked)
            UpdateAllWidgetStates()
        end,
        true, "CDM Profile Strings", "On", "Off"
    )
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, 36)

    -- Separator
    card1:AddSeparator()

    -- Description text
    local textRowSize = 50
    local rowDesc = GUIFrame:CreateRow(card1.content, textRowSize)
    local descText = GUIFrame:CreateText(rowDesc,
        NRSKNUI:ColorTextByTheme("How It Works"),
        (NRSKNUI:ColorTextByTheme("• ") .. "Opens automatically when Blizzard's Cooldown Manager settings open\n" ..
            NRSKNUI:ColorTextByTheme("• ") .. "Save and backup your CDM profile strings in savedVariables"),
        textRowSize, "hide")
    rowDesc:AddWidget(descText, 1)
    table_insert(allWidgets, descText)
    card1:AddRow(rowDesc, textRowSize)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Profile Management (Create + Dropdown)
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Profile Management", yOffset)
    table_insert(allWidgets, card2)

    local row2a = GUIFrame:CreateRow(card2.content, 36)

    -- Create New Profile button
    local createBtn = GUIFrame:CreateButton(row2a, "Create New", {
        width = 120,
        callback = function()
            NRSKNUI:CreatePrompt(
                "New CDM Profile",
                "Enter a name for this profile:",
                true,
                nil,
                false,
                nil, nil, nil, nil,
                function(inputText)
                    if inputText and inputText ~= "" then
                        -- Check if profile already exists
                        if db.Profiles[inputText] then
                            NRSKNUI:Print("A profile named '" .. inputText .. "' already exists.")
                            return
                        end

                        -- Create new profile
                        db.Profiles[inputText] = {
                            String = "",
                            Created = time(),
                        }
                        selectedProfileName = inputText
                        NRSKNUI:Print("Created new CDM profile: " .. inputText)

                        -- Sync with attached panel
                        SyncWithModule()
                        RefreshContent()
                    end
                end,
                nil,
                "Create",
                "Cancel"
            )
        end,
    })
    row2a:AddWidget(createBtn, 0.4, nil, 0, -2)
    table_insert(allWidgets, createBtn)

    -- Profile dropdown
    local profileList = GetProfileList()
    if #profileList > 0 then
        local currentSelection = selectedProfileName or profileList[1].key
        if not selectedProfileName then
            selectedProfileName = profileList[1].key
            selectedProfile = db.Profiles[selectedProfileName]
        end

        local profileDropdown = GUIFrame:CreateDropdown(row2a, "Edit Profile", profileList, currentSelection, 70,
            function(key)
                selectedProfileName = key
                RefreshContent()
            end)
        row2a:AddWidget(profileDropdown, 0.6)
        table_insert(allWidgets, profileDropdown)
    end

    card2:AddRow(row2a, 36)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Selected Profile Editor
    ----------------------------------------------------------------
    if selectedProfile then
        local card3 = GUIFrame:CreateCard(scrollChild, "Profile Settings", yOffset)
        table_insert(allWidgets, card3)

        -- Row 1: Profile name + Delete button
        local row3a = GUIFrame:CreateRow(card3.content, 42)

        -- Profile name label
        local nameLabel = row3a:CreateFontString(nil, "OVERLAY")
        nameLabel:SetPoint("LEFT", row3a, "LEFT", 4, 0)
        nameLabel:SetFont(STANDARD_TEXT_FONT, Theme.fontSizeLarge or 12, "OUTLINE")
        nameLabel:SetText("Editing: |cFFFFFFFF" .. selectedProfileName .. "|r")
        nameLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        nameLabel:SetShadowOffset(0, 0)

        -- Container for label
        local nameLabelContainer = CreateFrame("Frame", nil, row3a)
        nameLabelContainer:SetHeight(36)
        nameLabel:SetParent(nameLabelContainer)
        nameLabel:ClearAllPoints()
        nameLabel:SetPoint("LEFT", nameLabelContainer, "LEFT", 0, 8)

        row3a:AddWidget(nameLabelContainer, 0.7)

        -- Delete button
        local deleteBtn = GUIFrame:CreateButton(row3a, "Delete", {
            width = 80,
            callback = function()
                NRSKNUI:CreatePrompt(
                    "Delete Profile",
                    "Are you sure you want to delete '" .. selectedProfileName .. "'?\n\nThis cannot be undone.",
                    false, nil, false, nil, nil, nil, nil,
                    function()
                        local deletedName = selectedProfileName
                        if deletedName then
                            db.Profiles[deletedName] = nil
                        end
                        deletedName = nil

                        -- Select next available profile
                        for profileName, _ in pairs(db.Profiles) do
                            deletedName = profileName
                            break
                        end

                        NRSKNUI:Print("Deleted CDM profile: " .. deletedName)
                        SyncWithModule()
                        RefreshContent()
                    end,
                    nil,
                    "Delete",
                    "Cancel"
                )
            end,
        })
        row3a:AddWidget(deleteBtn, 0.3)
        table_insert(allWidgets, deleteBtn)

        card3:AddRow(row3a, 42)

        -- Separator
        --card3:AddSeparator()

        -- Row 2: Profile String EditBox (multiline)
        local row3b = GUIFrame:CreateRow(card3.content, 140)

        -- Create a multiline editbox container
        local editContainer = CreateFrame("Frame", nil, row3b, "BackdropTemplate")
        editContainer:SetHeight(130)
        editContainer:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        editContainer:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
        editContainer:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

        -- Border animation state
        local borderR, borderG, borderB = Theme.border[1], Theme.border[2], Theme.border[3]
        local borderAnimGroup = editContainer:CreateAnimationGroup()
        local borderAnim = borderAnimGroup:CreateAnimation("Animation")
        borderAnim:SetDuration(0.18)

        local borderColorFrom = {}
        local borderColorTo = {}

        local function AnimateBorder(toAccent)
            borderAnimGroup:Stop()
            borderColorFrom.r = borderR
            borderColorFrom.g = borderG
            borderColorFrom.b = borderB

            if toAccent then
                borderColorTo.r = Theme.accent[1]
                borderColorTo.g = Theme.accent[2]
                borderColorTo.b = Theme.accent[3]
            else
                borderColorTo.r = Theme.border[1]
                borderColorTo.g = Theme.border[2]
                borderColorTo.b = Theme.border[3]
            end
            borderAnimGroup:Play()
        end

        borderAnimGroup:SetScript("OnUpdate", function(self)
            local progress = self:GetProgress() or 0
            local r = borderColorFrom.r + (borderColorTo.r - borderColorFrom.r) * progress
            local g = borderColorFrom.g + (borderColorTo.g - borderColorFrom.g) * progress
            local b = borderColorFrom.b + (borderColorTo.b - borderColorFrom.b) * progress
            editContainer:SetBackdropBorderColor(r, g, b, 1)
            borderR, borderG, borderB = r, g, b
        end)

        borderAnimGroup:SetScript("OnFinished", function()
            editContainer:SetBackdropBorderColor(borderColorTo.r, borderColorTo.g, borderColorTo.b, 1)
            borderR, borderG, borderB = borderColorTo.r, borderColorTo.g, borderColorTo.b
        end)

        -- Label above editbox
        local editLabel = editContainer:CreateFontString(nil, "OVERLAY")
        editLabel:SetPoint("TOPLEFT", editContainer, "TOPLEFT", 3, 16)
        NRSKNUI:ApplyThemeFont(editLabel, "small")
        editLabel:SetText("Profile String (paste your CDM export here):")
        editLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)

        -- Scroll frame for editbox
        local scrollFrame = CreateFrame("ScrollFrame", nil, editContainer, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", editContainer, "TOPLEFT", 4, -4)
        scrollFrame:SetPoint("BOTTOMRIGHT", editContainer, "BOTTOMRIGHT", -22, 4)

        -- Style scrollbar
        if scrollFrame.ScrollBar then
            scrollFrame.ScrollBar:ClearAllPoints()
            scrollFrame.ScrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 2, -16)
            scrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 2, 16)
            scrollFrame.ScrollBar:SetWidth(10)
        end

        -- EditBox
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        NRSKNUI:ApplyThemeFont(editBox, "normal")
        editBox:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        editBox:SetPoint("TOPLEFT", 2, -2)
        editBox:SetPoint("TOPRIGHT", -2, -2)
        editBox:EnableMouse(true)
        scrollFrame:SetScrollChild(editBox)

        -- Set width after scroll child is set
        editBox:SetWidth(scrollFrame:GetWidth() - 8 > 0 and scrollFrame:GetWidth() - 8 or 200)

        -- Set initial text
        editBox:SetText(selectedProfile.String or "")
        editBox:SetCursorPosition(0)

        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)

        editBox:SetScript("OnTextChanged", function(self, userInput)
            if userInput and selectedProfileName and db.Profiles[selectedProfileName] then
                db.Profiles[selectedProfileName].String = self:GetText()
                -- Sync with attached panel if open
                SyncWithModule()
            end
        end)

        -- Focus highlight
        editBox:SetScript("OnEditFocusGained", function(self)
            editContainer:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            borderR, borderG, borderB = Theme.accent[1], Theme.accent[2], Theme.accent[3]
        end)

        editBox:SetScript("OnEditFocusLost", function(self)
            editContainer:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
            borderR, borderG, borderB = Theme.border[1], Theme.border[2], Theme.border[3]
        end)

        -- Hover animation on editbox
        editBox:SetScript("OnEnter", function(self)
            if not self:HasFocus() then
                AnimateBorder(true)
            end
        end)

        editBox:SetScript("OnLeave", function(self)
            if not self:HasFocus() then
                AnimateBorder(false)
            end
        end)

        -- Make entire container clickable to focus editbox
        editContainer:EnableMouse(true)
        editContainer:SetScript("OnMouseDown", function()
            editBox:SetFocus()
        end)
        editContainer:SetScript("OnEnter", function()
            if not editBox:HasFocus() then
                AnimateBorder(true)
            end
        end)
        editContainer:SetScript("OnLeave", function()
            if not editBox:HasFocus() then
                AnimateBorder(false)
            end
        end)

        -- Make scroll frame clickable to focus editbox
        scrollFrame:EnableMouse(true)
        scrollFrame:SetScript("OnMouseDown", function()
            editBox:SetFocus()
        end)

        row3b:AddWidget(editContainer, 1)
        table_insert(allWidgets, editContainer)

        card3:AddRow(row3b, 140)

        -- Helper text
        local row3c = GUIFrame:CreateRow(card3.content, 28)
        local helperText = row3c:CreateFontString(nil, "OVERLAY")
        helperText:SetPoint("LEFT", row3c, "LEFT", 4, 0)
        helperText:SetFont(STANDARD_TEXT_FONT, Theme.fontSizeSmall or 10, "OUTLINE")
        helperText:SetText("CTRL+C to copy, CTRL+V to paste, CTRL+A to select all")
        helperText:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        helperText:SetShadowOffset(0, 0)

        -- Container for helper text
        local helperContainer = CreateFrame("Frame", nil, row3c)
        helperContainer:SetHeight(28)
        helperText:SetParent(helperContainer)
        helperText:ClearAllPoints()
        helperText:SetPoint("LEFT", helperContainer, "LEFT", 0, 0)

        row3c:AddWidget(helperContainer, 1)
        table_insert(allWidgets, helperContainer)

        card3:AddRow(row3c, 28)

        yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall
    else
        -- No profile selected message
        local card3 = GUIFrame:CreateCard(scrollChild, "Profile Editor", yOffset)
        table_insert(allWidgets, card3)
        card3:AddLabel("No profiles configured. Click 'Create New' to create one.")
        yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall
    end

    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 3)
    return yOffset
end)

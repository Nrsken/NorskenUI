-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization
local table_insert = table.insert
local pairs, ipairs = pairs, ipairs
local tonumber = tonumber
local tostring = tostring
local CreateFrame = CreateFrame
local C_Spell = C_Spell
local C_Item = C_Item

-- Get module reference
local function GetModule()
    if NRSKNUI.Addon then
        return NRSKNUI.Addon:GetModule("BuffIcons", true)
    end
    return nil
end

-- Persistent selected tracker across refreshes
local selectedTrackerIndex = nil

-- Track if preview is active (persists across refreshes)
local isPreviewActive = false

-- Helper to create an icon with spell name and ID labels
local function CreateIconWithLabels(parent, spellOrItemID, isItem, size)
    size = size or 32
    -- Container frame - will stretch to fill available space
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(size)

    -- Icon frame inside container
    local iconFrame = CreateFrame("Frame", nil, container)
    iconFrame:SetSize(size, size)
    iconFrame:SetPoint("LEFT", container, "LEFT", 4, 0)

    -- Icon texture
    iconFrame.texture = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.texture:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
    iconFrame.texture:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)

    -- Zoom for icons
    local zoom = 0.3
    local texMin = 0.25 * zoom
    local texMax = 1 - 0.25 * zoom
    iconFrame.texture:SetTexCoord(texMin, texMax, texMin, texMax)

    -- Get texture and name based on type
    local texture, spellName
    if isItem then
        texture = C_Item.GetItemIconByID(spellOrItemID)
        local itemInfo = C_Item.GetItemInfo(spellOrItemID)
        spellName = itemInfo or "Unknown Item"
    else
        texture = C_Spell.GetSpellTexture(spellOrItemID)
        local spellInfo = C_Spell.GetSpellInfo(spellOrItemID)
        spellName = spellInfo and spellInfo.name or "Unknown Spell"
    end

    if texture then
        iconFrame.texture:SetTexture(texture)
    else
        iconFrame.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    -- Border
    local borderTop = iconFrame:CreateTexture(nil, "OVERLAY")
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", iconFrame, "TOPRIGHT", 0, 0)
    borderTop:SetColorTexture(0, 0, 0, 1)

    local borderBottom = iconFrame:CreateTexture(nil, "OVERLAY")
    borderBottom:SetHeight(1)
    borderBottom:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetColorTexture(0, 0, 0, 1)

    local borderLeft = iconFrame:CreateTexture(nil, "OVERLAY")
    borderLeft:SetWidth(1)
    borderLeft:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMLEFT", 0, 0)
    borderLeft:SetColorTexture(0, 0, 0, 1)

    local borderRight = iconFrame:CreateTexture(nil, "OVERLAY")
    borderRight:SetWidth(1)
    borderRight:SetPoint("TOPRIGHT", iconFrame, "TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0, 0)
    borderRight:SetColorTexture(0, 0, 0, 1)

    -- Spell name label (right of icon)
    local nameLabel = container:CreateFontString(nil, "OVERLAY")
    nameLabel:SetPoint("LEFT", iconFrame, "RIGHT", 5, 6)
    nameLabel:SetFont(STANDARD_TEXT_FONT, Theme.fontSizeSmall, "OUTLINE")
    nameLabel:SetShadowOffset(0, 0)
    nameLabel:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3], 1)
    nameLabel:SetText(spellName)

    -- Spell/Item ID label (below name)
    local typeLabel = isItem and "Item" or "Spell"
    local idLabel = container:CreateFontString(nil, "OVERLAY")
    idLabel:SetPoint("LEFT", iconFrame, "RIGHT", 5, -6)
    idLabel:SetFont(STANDARD_TEXT_FONT, Theme.fontSizeSmall, "OUTLINE")
    idLabel:SetShadowOffset(0, 0)
    idLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    idLabel:SetText(typeLabel .. " ID: " .. (spellOrItemID or 0))

    return container
end

-- Register Buff Icons tab content
GUIFrame:RegisterContent("BuffIcons", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.CustomBuffs and NRSKNUI.db.profile.CustomBuffs.Icons
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Ensure tables exist
    if not db.Trackers then db.Trackers = {} end
    if not db.Defaults then db.Defaults = {} end
    if not db.Position then db.Position = {} end

    local allWidgets = {}

    local function ApplySettings()
        local mod = GetModule()
        if mod and mod.ApplySettings then
            mod:ApplySettings()
        end
        -- Re-show preview if it was active
        if isPreviewActive and mod and mod.PreviewAll then
            mod:PreviewAll()
        end
    end

    local function ApplyPosition()
        local mod = GetModule()
        if mod and mod.ApplyPosition then
            mod:ApplyPosition()
        end
    end

    local function RefreshContent()
        C_Timer.After(0.1, function()
            GUIFrame:RefreshContent()
        end)
    end

    -- Register cleanup callback to hide previews when GUI closes
    GUIFrame.contentCleanupCallbacks = GUIFrame.contentCleanupCallbacks or {}
    GUIFrame.contentCleanupCallbacks["BuffIcons"] = function()
        isPreviewActive = false
        local mod = GetModule()
        if mod and mod.HideAll then
            mod:HideAll()
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

    -- Build tracker dropdown list
    local function GetTrackerList()
        local list = {}
        for index, tracker in pairs(db.Trackers) do
            if tracker.SpellID then
                local name
                if tracker.Type == "Item" then
                    local itemInfo = C_Item.GetItemInfo(tracker.SpellID)
                    name = itemInfo or "Unknown Item"
                else
                    local spellInfo = C_Spell.GetSpellInfo(tracker.SpellID)
                    name = spellInfo and spellInfo.name or "Unknown Spell"
                end
                local typeLabel = tracker.Type == "Item" and "Item" or "Spell"
                table_insert(list, {
                    key = tostring(index),
                    text = name .. " (" .. typeLabel .. ": " .. tracker.SpellID .. ")",
                })
            end
        end
        table.sort(list, function(a, b) return tonumber(a.key) < tonumber(b.key) end)
        return list
    end

    -- Validate selected tracker still exists
    if selectedTrackerIndex then
        if not db.Trackers[selectedTrackerIndex] then
            selectedTrackerIndex = nil
        end
    end

    -- Get selected tracker data
    local selectedTracker = selectedTrackerIndex and db.Trackers[selectedTrackerIndex] or nil

    ----------------------------------------------------------------
    -- Card 1: Enable Buff Icons
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Custom Buff Icons", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Buff Icons", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end,
        true, "Buff Icons", "On", "Off"
    )
    row1:AddWidget(enableCheck, 0.5)

    -- Preview button
    local previewBtn = GUIFrame:CreateButton(row1, "Preview All", {
        width = 100,
        callback = function()
            isPreviewActive = true
            local mod = GetModule()
            if mod and mod.PreviewAll then
                mod:PreviewAll()
            end
        end,
    })
    row1:AddWidget(previewBtn, 0.5)
    table_insert(allWidgets, previewBtn)

    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Add New Tracker + Dropdown
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Tracker Selection", yOffset)
    table_insert(allWidgets, card2)

    local row2a = GUIFrame:CreateRow(card2.content, 36)

    -- Add Tracker button
    local addBtn = GUIFrame:CreateButton(row2a, "Add New Tracker", {
        width = 140,
        callback = function()
            -- Find next available index
            local nextIndex = 1
            for i = 1, 100 do
                if not db.Trackers[i] then
                    nextIndex = i
                    break
                end
            end

            -- Add new tracker with defaults
            db.Trackers[nextIndex] = {
                Enabled = true,
                SpellID = 0,
                Duration = 10,
            }

            selectedTrackerIndex = nextIndex
            ApplySettings()
            RefreshContent()
        end,
    })
    row2a:AddWidget(addBtn, 0.5, nil, 0, -2)
    table_insert(allWidgets, addBtn)

    -- Tracker dropdown
    local trackerList = GetTrackerList()
    if #trackerList > 0 then
        local currentSelection = selectedTrackerIndex and tostring(selectedTrackerIndex) or trackerList[1].key
        if not selectedTrackerIndex then
            selectedTrackerIndex = tonumber(trackerList[1].key)
            selectedTracker = db.Trackers[selectedTrackerIndex]
        end

        local trackerDropdown = GUIFrame:CreateDropdown(row2a, "Edit Tracker", trackerList, currentSelection, 70,
            function(key)
                selectedTrackerIndex = tonumber(key)
                RefreshContent()
            end)
        row2a:AddWidget(trackerDropdown, 0.5)
        table_insert(allWidgets, trackerDropdown)
    end

    card2:AddRow(row2a, 36)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Selected Tracker Settings
    ----------------------------------------------------------------
    if selectedTracker then
        local card3 = GUIFrame:CreateCard(scrollChild, "Tracker Settings", yOffset)
        table_insert(allWidgets, card3)

        -- Row 1: Icon with name/ID labels
        local row3a = GUIFrame:CreateRow(card3.content, 40)

        -- Spell/Item icon display with name and ID labels
        local isItem = selectedTracker.Type == "Item"
        local iconWidget = CreateIconWithLabels(row3a, selectedTracker.SpellID or 0, isItem, 36)
        row3a:AddWidget(iconWidget, 0.5)

        -- Enable toggle
        local trackerEnableCheck = GUIFrame:CreateCheckbox(row3a, "Enabled", selectedTracker.Enabled ~= false,
            function(checked)
                selectedTracker.Enabled = checked
                ApplySettings()
            end)
        row3a:AddWidget(trackerEnableCheck, 0.2)
        table_insert(allWidgets, trackerEnableCheck)

        -- Delete button with confirmation
        local deleteBtn = GUIFrame:CreateButton(row3a, "Delete", {
            width = 70,
            callback = function()
                NRSKNUI:CreatePrompt(
                    "Delete Tracker",
                    "Are you sure you want to delete this tracker?",
                    false, nil, false, nil, nil, nil, nil,
                    function()
                        db.Trackers[selectedTrackerIndex] = nil
                        selectedTrackerIndex = nil
                        ApplySettings()
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

        card3:AddRow(row3a, 40)

        -- Separator
        card3:AddSeparator()

        -- Row 2: Type + Spell/Item ID + Duration
        local row3b = GUIFrame:CreateRow(card3.content, 36)

        local typeOptions = {
            { key = "Spell", text = "Spell" },
            { key = "Item",  text = "Item" },
        }
        local typeDropdown = GUIFrame:CreateDropdown(row3b, "Type", typeOptions, selectedTracker.Type or "Spell", 40,
            function(key)
                selectedTracker.Type = key
                ApplySettings()
                RefreshContent()
            end)
        row3b:AddWidget(typeDropdown, 0.3)
        table_insert(allWidgets, typeDropdown)

        local idLabel = (selectedTracker.Type == "Item") and "Item ID" or "Spell ID"
        local spellIDInput = GUIFrame:CreateEditBox(row3b, idLabel, tostring(selectedTracker.SpellID or ""),
            function(text)
                local newID = tonumber(text)
                if newID and newID > 0 then
                    selectedTracker.SpellID = newID
                    ApplySettings()
                    RefreshContent()
                end
            end)
        spellIDInput.editBox:SetNumeric(true)
        row3b:AddWidget(spellIDInput, 0.35)
        table_insert(allWidgets, spellIDInput)

        local durationInput = GUIFrame:CreateEditBox(row3b, "Duration (sec)", tostring(selectedTracker.Duration or 10),
            function(text)
                local newDur = tonumber(text)
                if newDur and newDur > 0 then
                    selectedTracker.Duration = newDur
                    ApplySettings()
                end
            end)
        durationInput.editBox:SetNumeric(true)
        row3b:AddWidget(durationInput, 0.35)
        table_insert(allWidgets, durationInput)

        card3:AddRow(row3b, 36)

        yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall
    else
        -- No tracker selected message
        local card3 = GUIFrame:CreateCard(scrollChild, "Tracker Settings", yOffset)
        table_insert(allWidgets, card3)
        card3:AddLabel("No trackers configured. Click 'Add New Tracker' to create one.")
        yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall
    end

    ----------------------------------------------------------------
    -- Card 4: Default Icon Settings
    ----------------------------------------------------------------
    local card4 = GUIFrame:CreateCard(scrollChild, "General Icon Settings", yOffset)
    table_insert(allWidgets, card4)
    local defaults = db.Defaults or {}

    local row4a = GUIFrame:CreateRow(card4.content, 40)
    local defaultIconSizeSlider = GUIFrame:CreateSlider(row4a, "Icon Size", 20, 80, 1, defaults.IconSize or 40, 60,
        function(val)
            db.Defaults.IconSize = val
            ApplySettings()
        end)
    row4a:AddWidget(defaultIconSizeSlider, 0.5)
    table_insert(allWidgets, defaultIconSizeSlider)

    local defaultCountdownSlider = GUIFrame:CreateSlider(row4a, "Countdown Size", 10, 30, 1, defaults.CountdownSize or 18,
        60,
        function(val)
            db.Defaults.CountdownSize = val
            ApplySettings()
        end)
    row4a:AddWidget(defaultCountdownSlider, 0.5)
    table_insert(allWidgets, defaultCountdownSlider)
    card4:AddRow(row4a, 40)

    local row4b = GUIFrame:CreateRow(card4.content, 36)
    local defaultShowTextCheck = GUIFrame:CreateCheckbox(row4b, "Show Cooldown Text", defaults.ShowCooldownText ~= false,
        function(checked)
            db.Defaults.ShowCooldownText = checked
            ApplySettings()
        end)
    row4b:AddWidget(defaultShowTextCheck, 0.5)
    table_insert(allWidgets, defaultShowTextCheck)

    local defaultBorderColorPicker = GUIFrame:CreateColorPicker(row4b, "Border Color",
        defaults.BorderColor or { 0, 0, 0, 1 },
        function(r, g, b, a)
            db.Defaults.BorderColor = { r, g, b, a }
            ApplySettings()
        end)
    row4b:AddWidget(defaultBorderColorPicker, 0.5)
    table_insert(allWidgets, defaultBorderColorPicker)
    card4:AddRow(row4b, 36)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 5: Position & Growth
    ----------------------------------------------------------------
    local posCard, newYOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        title = "Position & Growth",
        db = db,
        showAnchorFrameType = true,
        showStrata = false,
        sliderRange = { -1000, 1000 },
        onChangeCallback = function()
            ApplyPosition()
        end,
    })
    table_insert(allWidgets, posCard)
    yOffset = newYOffset

    -- Growth direction row (add after position card)
    local growthCard = GUIFrame:CreateCard(scrollChild, "Growth Direction", yOffset)
    table_insert(allWidgets, growthCard)

    local growthRow = GUIFrame:CreateRow(growthCard.content, 36)

    local growthOptions = {
        { key = "RIGHT",  text = "Right" },
        { key = "LEFT",   text = "Left" },
        { key = "UP",     text = "Up" },
        { key = "DOWN",   text = "Down" },
        { key = "CENTER", text = "Center (Horizontal)" },
    }
    local growthDropdown = GUIFrame:CreateDropdown(growthRow, "Growth Direction", growthOptions,
        db.GrowthDirection or "RIGHT", 100,
        function(key)
            db.GrowthDirection = key
            ApplySettings()
        end)
    growthRow:AddWidget(growthDropdown, 0.5)
    table_insert(allWidgets, growthDropdown)

    local spacingSlider = GUIFrame:CreateSlider(growthRow, "Spacing", 0, 20, 1, db.Spacing or 2, 60,
        function(val)
            db.Spacing = val
            ApplySettings()
        end)
    growthRow:AddWidget(spacingSlider, 0.5)
    table_insert(allWidgets, spacingSlider)

    growthCard:AddRow(growthRow, 36)

    yOffset = yOffset + growthCard:GetContentHeight() + Theme.paddingSmall

    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 3)
    return yOffset
end)

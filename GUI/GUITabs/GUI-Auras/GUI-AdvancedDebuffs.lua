---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AdvancedDebuffs
local AdvancedDebuffs = NRSKNUI:GetModule("AdvancedDebuffs", true)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local pairs = pairs
local type = type
local tostring = tostring
local tinsert = tinsert
local tonumber = tonumber
local CreateFrame = CreateFrame
local unpack = unpack

GUIFrame:RegisterContent("advancedDebuffs", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.AdvancedDebuffs
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local manager = GUIFrame:CreateWidgetStateManager()

    manager:SetCondition("borderColor", function() return db.BorderColorMode == "custom" end)
    manager:SetCondition("borderTypes", function() return db.BorderColorMode == "dispel" end)
    manager:SetCondition("swipeOn", function() return db.Swipe end)

    local function ApplySettings()
        if AdvancedDebuffs and AdvancedDebuffs:IsEnabled() and AdvancedDebuffs.ApplySettings then
            AdvancedDebuffs:ApplySettings()
        end
    end

    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    -- Card 1: Enable
    local card1 = GUIFrame:CreateCard(scrollChild, "Advanced Debuff Frame", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Advanced Debuff Frame", {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if AdvancedDebuffs then
                AdvancedDebuffs.db.Enabled = checked
                if checked then
                    NRSKNUI:EnableModule("AdvancedDebuffs")
                else
                    NRSKNUI:DisableModule("AdvancedDebuffs")
                end
            end
            UpdateAllWidgetStates()
            NRSKNUI:CreateReloadPrompt("Enabling/Disabling this module requires a reload.")
        end,
        msgPopup = true,
        msgText = "Custom Debuff Frame",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Icon Settings
    local card2 = GUIFrame:CreateCard(scrollChild, "Icon Settings", yOffset)
    manager:Register(card2, "all")

    local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local iconSizeSlider = GUIFrame:CreateSlider(row2a, "Icon Size", {
        min = 16,
        max = 80,
        step = 1,
        value = db.IconSize,
        callback = function(value)
            db.IconSize = value
            ApplySettings()
        end
    })
    row2a:AddWidget(iconSizeSlider, 0.5)
    manager:Register(iconSizeSlider, "all")

    local iconSpacingSlider = GUIFrame:CreateSlider(row2a, "Icon Spacing", {
        min = -10,
        max = 10,
        step = 1,
        value = db.IconSpacing,
        callback = function(value)
            db.IconSpacing = value
            ApplySettings()
        end
    })
    row2a:AddWidget(iconSpacingSlider, 0.5)
    manager:Register(iconSpacingSlider, "all")
    card2:AddRow(row2a, Theme.rowHeight)

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local iconsPerRowSlider = GUIFrame:CreateSlider(row2b, "Icons Per Row", {
        min = 1,
        max = 20,
        step = 1,
        value = db.IconsPerRow,
        callback = function(value)
            db.IconsPerRow = value
            ApplySettings()
        end
    })
    row2b:AddWidget(iconsPerRowSlider, 0.5)
    manager:Register(iconsPerRowSlider, "all")

    local maxRowsSlider = GUIFrame:CreateSlider(row2b, "Max Rows", {
        min = 1,
        max = 10,
        step = 1,
        value = db.MaxRows,
        callback = function(value)
            db.MaxRows = value
            ApplySettings()
        end
    })
    row2b:AddWidget(maxRowsSlider, 0.5)
    manager:Register(maxRowsSlider, "all")
    card2:AddRow(row2b, Theme.rowHeight)

    local sep2 = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sep2, Theme.rowHeightSeparator)

    local row2c = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local growHList = {
        { key = "LEFT",  text = "Left" },
        { key = "RIGHT", text = "Right" },
    }
    local growHDropdown = GUIFrame:CreateDropdown(row2c, "Grow Horizontal", {
        options = growHList,
        value = db.GrowHorizontal or "LEFT",
        callback = function(key)
            db.GrowHorizontal = key
            ApplySettings()
        end
    })
    row2c:AddWidget(growHDropdown, 0.5)
    manager:Register(growHDropdown, "all")

    local growVList = {
        { key = "UP",   text = "Up" },
        { key = "DOWN", text = "Down" },
    }
    local growVDropdown = GUIFrame:CreateDropdown(row2c, "Then Vertical", {
        options = growVList,
        value = db.GrowVertical or "DOWN",
        callback = function(key)
            db.GrowVertical = key
            ApplySettings()
        end
    })
    row2c:AddWidget(growVDropdown, 0.5)
    manager:Register(growVDropdown, "all")
    card2:AddRow(row2c, Theme.rowHeight)

    local separator3b = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(separator3b, Theme.rowHeightSeparator)

    local rowSwipe = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local swipeCheck = GUIFrame:CreateCheckbox(rowSwipe, "Enable Swipe", {
        value = db.Swipe,
        callback = function(checked)
            db.Swipe = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    rowSwipe:AddWidget(swipeCheck, 0.5)
    manager:Register(swipeCheck, "all")

    local reverseCheck = GUIFrame:CreateCheckbox(rowSwipe, "Reverse Swipe", {
        value = db.Reverse,
        callback = function(checked)
            db.Reverse = checked
            ApplySettings()
        end
    })
    rowSwipe:AddWidget(reverseCheck, 0.5)
    manager:Register(reverseCheck, "all", "swipeOn")
    card2:AddRow(rowSwipe, Theme.rowHeight)

    local separator3c = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(separator3c, Theme.rowHeightSeparator)

    local rowInteraction = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local tooltipCheck = GUIFrame:CreateCheckbox(rowInteraction, "Show Tooltips", {
        tooltip = "Show tooltips when hovering over debuff icons.",
        value = db.ShowTooltips,
        callback = function(checked)
            db.ShowTooltips = checked
            ApplySettings()
        end
    })
    rowInteraction:AddWidget(tooltipCheck, 0.5)
    manager:Register(tooltipCheck, "all")
    card2:AddRow(rowInteraction, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Visual Settings
    local card3 = GUIFrame:CreateCard(scrollChild, "Visual Settings", yOffset)
    manager:Register(card3, "all")

    local row3a = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local borderModeList = {
        { key = "custom", text = "Custom Color" },
        { key = "dispel", text = "Dispel Type" },
    }
    local borderModeDropdown = GUIFrame:CreateDropdown(row3a, "Border Color Mode", {
        options = borderModeList,
        value = db.BorderColorMode or "custom",
        callback = function(key)
            db.BorderColorMode = key
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row3a:AddWidget(borderModeDropdown, 0.5)
    manager:Register(borderModeDropdown, "all")

    local borderColorPicker = GUIFrame:CreateColorPicker(row3a, "Border Color", {
        color = db.BorderColor,
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row3a:AddWidget(borderColorPicker, 1)
    manager:Register(borderColorPicker, "all", "borderColor")
    card3:AddRow(row3a, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card 4: Filtering Options
    local card4 = GUIFrame:CreateCard(scrollChild, "Filtering Options", yOffset)
    manager:Register(card4, "all")

    db.Filters = db.Filters or {}

    local filterRowSize = 34
    local infoFilterRow = GUIFrame:CreateRow(card4.content, filterRowSize)
    local infoTextFilter = GUIFrame:CreateText(infoFilterRow, NRSKNUI:ColorTextByTheme("Filter Info"), {
        text = NRSKNUI:ColorTextByTheme("• ") ..
            "Select filter(s) that you want to remove from tracking.",
        height = filterRowSize,
        bgMode = "hide"
    })
    infoFilterRow:AddWidget(infoTextFilter, 1)
    manager:Register(infoTextFilter, "all")
    card4:AddRow(infoFilterRow, filterRowSize)

    local filtersep1 = GUIFrame:CreateSeparator(card4.content)
    card4:AddRow(filtersep1, Theme.rowHeightSeparator)

    local row4b = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local playerFilterCheck = GUIFrame:CreateCheckbox(row4b, "PLAYER", {
        tooltip = "Filters out debuffs applied by the player, for example Brewmaster Stagger and cheat death effects.",
        value = db.Filters.PLAYER == true,
        callback = function(checked)
            db.Filters.PLAYER = checked
            ApplySettings()
        end
    })
    row4b:AddWidget(playerFilterCheck, 0.5)
    manager:Register(playerFilterCheck, "all")

    local raidFilterCheck = GUIFrame:CreateCheckbox(row4b, "RAID", {
        tooltip =
        "Filters out certain debuffs that only show up on raid frames, e.g. most debuffs that are relevant in a raid context.",
        value = db.Filters.RAID == true,
        callback = function(checked)
            db.Filters.RAID = checked
            ApplySettings()
        end
    })
    row4b:AddWidget(raidFilterCheck, 0.5)
    manager:Register(raidFilterCheck, "all")
    card4:AddRow(row4b, Theme.rowHeight)

    local row4d = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local ccCheck = GUIFrame:CreateCheckbox(row4d, "CROWD_CONTROL", {
        tooltip = "Filters out crowd control effects.",
        value = db.Filters.CROWD_CONTROL == true,
        callback = function(checked)
            db.Filters.CROWD_CONTROL = checked
            ApplySettings()
        end
    })
    row4d:AddWidget(ccCheck, 0.5)
    manager:Register(ccCheck, "all")

    local importantCheck = GUIFrame:CreateCheckbox(row4d, "IMPORTANT", {
        tooltip = "Filters out debuffs that pass the IsSpellImportant check.",
        value = db.Filters.IMPORTANT == true,
        callback = function(checked)
            db.Filters.IMPORTANT = checked
            ApplySettings()
        end
    })
    row4d:AddWidget(importantCheck, 0.5)
    manager:Register(importantCheck, "all")
    card4:AddRow(row4d, Theme.rowHeight)

    local row4e = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
    local dispellableCheck = GUIFrame:CreateCheckbox(row4e, "RAID_PLAYER_DISPELLABLE", {
        tooltip = "Filters out auras with a dispel type the player can dispel.",
        value = db.Filters.RAID_PLAYER_DISPELLABLE == true,
        callback = function(checked)
            db.Filters.RAID_PLAYER_DISPELLABLE = checked
            ApplySettings()
        end
    })
    row4e:AddWidget(dispellableCheck, 0.5)
    manager:Register(dispellableCheck, "all")

    local nameplateCheck = GUIFrame:CreateCheckbox(row4e, "INCLUDE_NAME_PLATE_ONLY", {
        tooltip = "Filters out auras that should be shown on nameplates.",
        value = db.Filters.INCLUDE_NAME_PLATE_ONLY == true,
        callback = function(checked)
            db.Filters.INCLUDE_NAME_PLATE_ONLY = checked
            ApplySettings()
        end
    })
    row4e:AddWidget(nameplateCheck, 0.5)
    manager:Register(nameplateCheck, "all")
    card4:AddRow(row4e, Theme.rowHeightLast, 0)

    yOffset = card4:GetNextOffset()

    -- Card 5: Blocklist
    local card5 = GUIFrame:CreateCard(scrollChild, "Blocklist", yOffset)
    manager:Register(card5, "all")

    db.Blocklist = db.Blocklist or {}

    local selectedSpellId = nil
    local blocklistDropdown, spellIdInput, labelInput
    local spellIconFrame, spellIconTexture, spellIconBorder, spellNameLabel
    local enabledToggle, deleteBtn

    local function GetSortedBlocklist()
        local sorted = {}
        for spellId, entry in pairs(db.Blocklist) do
            local label
            if type(entry) == "table" then
                label = entry.label or tostring(spellId)
            elseif type(entry) == "string" then
                label = entry
            else
                label = tostring(spellId)
            end
            tinsert(sorted, { spellId = spellId, label = label, entry = entry })
        end
        table.sort(sorted, function(a, b) return a.label < b.label end)
        return sorted
    end

    local function BuildDropdownOptions()
        local options = {}
        for spellId, entry in pairs(db.Blocklist) do
            local label
            if type(entry) == "table" then
                label = entry.label or tostring(spellId)
            elseif type(entry) == "string" then
                label = entry
            else
                label = tostring(spellId)
            end
            local isDisabled = type(entry) == "table" and not entry.enabled
            local text = label .. " (" .. spellId .. ")"
            if isDisabled then
                text = "|cff666666" .. text .. "|r"
            end
            options[tostring(spellId)] = text
        end
        return options
    end

    local function GetFirstSpellId()
        local sorted = GetSortedBlocklist()
        if #sorted > 0 then
            return sorted[1].spellId
        end
        return nil
    end

    local function UpdateSpellDisplay()
        if not selectedSpellId or not db.Blocklist[selectedSpellId] then
            spellIconFrame:Hide()
            spellNameLabel:SetText("")
            return
        end

        spellIconFrame:Show()

        local entry = db.Blocklist[selectedSpellId]
        local isDefault = type(entry) == "table" and entry.default
        local isEnabled = type(entry) == "table" and entry.enabled ~= false or entry == true or type(entry) == "string"
        local label = type(entry) == "table" and entry.label or (type(entry) == "string" and entry or "")

        local spellInfo = C_Spell.GetSpellInfo(selectedSpellId)
        local spellName = spellInfo and spellInfo.name or "Unknown Spell"
        local spellIcon = spellInfo and spellInfo.iconID or 134400

        spellIconTexture:SetTexture(spellIcon)
        spellNameLabel:SetText(spellName)
        spellIdInput:SetValue(tostring(selectedSpellId))
        labelInput:SetValue(label)
        enabledToggle.toggle:SetValue(isEnabled)

        if isDefault then
            deleteBtn:SetEnabled(false)
        else
            deleteBtn:SetEnabled(true)
        end
    end

    local function SelectSpell(spellId)
        selectedSpellId = spellId
        UpdateSpellDisplay()
    end

    local textRowSize = 34
    local infoRow = GUIFrame:CreateRow(card5.content, textRowSize)
    local infoText = GUIFrame:CreateText(infoRow, NRSKNUI:ColorTextByTheme("Blocklist Filter Info"), {
        text = NRSKNUI:ColorTextByTheme("• ") ..
            "Only possible to add auras that have been made non secret by Blizzard, for example all the Bloodlust ID's.",
        height = textRowSize,
        bgMode = "hide"
    })
    infoRow:AddWidget(infoText, 1)
    manager:Register(infoText, "all")
    card5:AddRow(infoRow, textRowSize)

    local sep1 = GUIFrame:CreateSeparator(card5.content)
    card5:AddRow(sep1, Theme.rowHeightSeparator)

    local selectRow = GUIFrame:CreateRow(card5.content, Theme.rowHeight)

    blocklistDropdown = GUIFrame:CreateDropdown(selectRow, "Select Entry", {
        options = BuildDropdownOptions(),
        value = tostring(GetFirstSpellId()),
        callback = function(key)
            if key then
                SelectSpell(tonumber(key))
            end
        end
    })
    selectRow:AddWidget(blocklistDropdown, 0.5)
    manager:Register(blocklistDropdown, "all")

    enabledToggle = GUIFrame:CreateCheckbox(selectRow, "Enabled", {
        value = true,
        callback = function(checked)
            if selectedSpellId and db.Blocklist[selectedSpellId] then
                local entry = db.Blocklist[selectedSpellId]
                if type(entry) == "table" then
                    entry.enabled = checked
                else
                    db.Blocklist[selectedSpellId] = { label = type(entry) == "string" and entry or nil, enabled = checked }
                end
                blocklistDropdown:SetOptions(BuildDropdownOptions())
                blocklistDropdown:SetValue(tostring(selectedSpellId))
                ApplySettings()
            end
        end
    })
    selectRow:AddWidget(enabledToggle, 0.5)
    manager:Register(enabledToggle, "all")
    card5:AddRow(selectRow, Theme.rowHeight)

    local sep2a = GUIFrame:CreateSeparator(card5.content)
    card5:AddRow(sep2a, Theme.rowHeightSeparator)

    local detailRow = GUIFrame:CreateRow(card5.content, Theme.rowHeight)
    local spellInfoContainer = CreateFrame("Frame", nil, detailRow)
    spellInfoContainer:SetHeight(Theme.rowHeight)
    detailRow:AddWidget(spellInfoContainer, 0.5)

    spellIconFrame = CreateFrame("Frame", nil, spellInfoContainer)
    spellIconFrame:SetSize(34, 34)
    spellIconFrame:SetPoint("LEFT", spellInfoContainer, "LEFT", 0, 0)
    spellIconFrame:EnableMouse(true)

    spellIconTexture = spellIconFrame:CreateTexture(nil, "ARTWORK")
    spellIconTexture:SetPoint("TOPLEFT", 1, -1)
    spellIconTexture:SetPoint("BOTTOMRIGHT", -1, 1)
    spellIconTexture:SetTexture(134400)
    spellIconTexture:SetZoom()

    spellIconBorder = CreateFrame("Frame", nil, spellIconFrame, "BackdropTemplate")
    spellIconBorder:SetAllPoints()
    spellIconBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    spellIconBorder:SetBackdropBorderColor(1, 0, 0, 1)

    spellIconFrame:SetScript("OnEnter", function(self)
        if selectedSpellId then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 30, 0)
            GameTooltip:SetSpellByID(selectedSpellId)
            GameTooltip:Show()
        end
    end)
    spellIconFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    spellNameLabel = spellInfoContainer:CreateFontString(nil, "OVERLAY")
    spellNameLabel:SetPoint("LEFT", spellIconFrame, "RIGHT", 6, 0)
    spellNameLabel:SetPoint("RIGHT", spellInfoContainer, "RIGHT", -4, 0)
    spellNameLabel:SetJustifyH("LEFT")
    NRSKNUI:ApplyThemeFont(spellNameLabel, "normal")
    spellNameLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)

    spellIdInput = GUIFrame:CreateEditBox(detailRow, "Spell ID", {
        value = "",
        callback = function(text)
            local newSpellId = tonumber(text)
            if newSpellId and selectedSpellId and newSpellId ~= selectedSpellId then
                local entry = db.Blocklist[selectedSpellId]
                if entry then
                    db.Blocklist[newSpellId] = entry
                    db.Blocklist[selectedSpellId] = nil
                    selectedSpellId = newSpellId
                    blocklistDropdown:SetOptions(BuildDropdownOptions())
                    blocklistDropdown:SetValue(tostring(newSpellId))
                    UpdateSpellDisplay()
                    ApplySettings()
                end
            end
        end
    })
    detailRow:AddWidget(spellIdInput, 0.25)
    manager:Register(spellIdInput, "all")

    labelInput = GUIFrame:CreateEditBox(detailRow, "Label", {
        value = "",
        callback = function(text)
            if selectedSpellId and db.Blocklist[selectedSpellId] then
                local entry = db.Blocklist[selectedSpellId]
                if type(entry) == "table" then
                    entry.label = (text and text ~= "") and text or nil
                else
                    db.Blocklist[selectedSpellId] = { label = (text and text ~= "") and text or nil, enabled = true }
                end
                blocklistDropdown:SetOptions(BuildDropdownOptions())
                blocklistDropdown:SetValue(tostring(selectedSpellId))
            end
        end
    })
    detailRow:AddWidget(labelInput, 0.25)
    manager:Register(labelInput, "all")
    card5:AddRow(detailRow, Theme.rowHeight)

    local buttonSep = GUIFrame:CreateSeparator(card5.content)
    card5:AddRow(buttonSep, Theme.rowHeightSeparator)

    local buttonRow = GUIFrame:CreateRow(card5.content, Theme.rowHeightLast)
    local addBtn = GUIFrame:CreateButton(buttonRow, "Add New Entry", {
        height = 24,
        callback = function()
            local entryNum = 1
            local function labelExists(num)
                local testLabel = "Entry " .. num
                for _, entry in pairs(db.Blocklist) do
                    local lbl = type(entry) == "table" and entry.label or (type(entry) == "string" and entry)
                    if lbl == testLabel then return true end
                end
                return false
            end
            while labelExists(entryNum) do
                entryNum = entryNum + 1
            end
            local newLabel = "Entry " .. entryNum
            local newSpellId = -1
            while db.Blocklist[newSpellId] do
                newSpellId = newSpellId - 1
            end

            db.Blocklist[newSpellId] = {
                label = newLabel,
                enabled = true
            }

            blocklistDropdown:SetOptions(BuildDropdownOptions())
            blocklistDropdown:SetValue(tostring(newSpellId))
            SelectSpell(newSpellId)
            ApplySettings()
        end
    })
    buttonRow:AddWidget(addBtn, 0.5)

    deleteBtn = GUIFrame:CreateButton(buttonRow, "Delete Entry", {
        height = 24,
        callback = function()
            if selectedSpellId and db.Blocklist[selectedSpellId] then
                local entry = db.Blocklist[selectedSpellId]
                if type(entry) == "table" and entry.default then
                    return
                end
                db.Blocklist[selectedSpellId] = nil
                blocklistDropdown:SetOptions(BuildDropdownOptions())
                local nextSpell = GetFirstSpellId()
                if nextSpell then
                    blocklistDropdown:SetValue(tostring(nextSpell))
                    SelectSpell(nextSpell)
                else
                    selectedSpellId = nil
                    spellIdInput:SetValue("")
                    labelInput:SetValue("")
                    UpdateSpellDisplay()
                end
                ApplySettings()
            end
        end
    })
    buttonRow:AddWidget(deleteBtn, 0.5)
    card5:AddRow(buttonRow, Theme.rowHeightLast - 14, 0)

    local firstSpell = GetFirstSpellId()
    if firstSpell then
        SelectSpell(firstSpell)
    else
        spellIconFrame:Hide()
    end

    yOffset = card5:GetNextOffset()

    -- Card 6: Text Positions
    local card6 = GUIFrame:CreateCard(scrollChild, "Text Positions", yOffset)
    manager:Register(card6, "all")

    local textAnchorOptions = {
        { key = "TOPLEFT",     text = "Top Left" },
        { key = "TOP",         text = "Top" },
        { key = "TOPRIGHT",    text = "Top Right" },
        { key = "LEFT",        text = "Left" },
        { key = "CENTER",      text = "Center" },
        { key = "RIGHT",       text = "Right" },
        { key = "BOTTOMLEFT",  text = "Bottom Left" },
        { key = "BOTTOM",      text = "Bottom" },
        { key = "BOTTOMRIGHT", text = "Bottom Right" },
    }

    db.TimerPosition = db.TimerPosition or {}
    db.StackPosition = db.StackPosition or
        { AnchorFrom = "BOTTOMRIGHT", AnchorTo = "BOTTOMRIGHT", XOffset = -1, YOffset = 1 }

    local row6a = GUIFrame:CreateRow(card6.content, Theme.rowHeight)
    local timerAnchorDropdown = GUIFrame:CreateDropdown(row6a, "Timer Anchor", {
        options = textAnchorOptions,
        value = db.TimerPosition.AnchorFrom or "CENTER",
        callback = function(key)
            db.TimerPosition.AnchorFrom = key
            db.TimerPosition.AnchorTo = key
            ApplySettings()
        end
    })
    row6a:AddWidget(timerAnchorDropdown, 1 / 3)
    manager:Register(timerAnchorDropdown, "all")

    local timerXSlider = GUIFrame:CreateSlider(row6a, "Timer X", {
        min = -50,
        max = 50,
        step = 1,
        value = db.TimerPosition.XOffset or 0,
        callback = function(value)
            db.TimerPosition.XOffset = value
            ApplySettings()
        end
    })
    row6a:AddWidget(timerXSlider, 1 / 3)
    manager:Register(timerXSlider, "all")

    local timerYSlider = GUIFrame:CreateSlider(row6a, "Timer Y", {
        min = -50,
        max = 50,
        step = 1,
        value = db.TimerPosition.YOffset or 0,
        callback = function(value)
            db.TimerPosition.YOffset = value
            ApplySettings()
        end
    })
    row6a:AddWidget(timerYSlider, 1 / 3)
    manager:Register(timerYSlider, "all")
    card6:AddRow(row6a, Theme.rowHeight)

    local textSettingSep = GUIFrame:CreateSeparator(card6.content)
    card6:AddRow(textSettingSep, Theme.rowHeightSeparator)

    local row6b = GUIFrame:CreateRow(card6.content, Theme.rowHeightLast)
    local stackAnchorDropdown = GUIFrame:CreateDropdown(row6b, "Stack Anchor", {
        options = textAnchorOptions,
        value = db.StackPosition.AnchorFrom,
        callback = function(key)
            db.StackPosition.AnchorFrom = key
            db.StackPosition.AnchorTo = key
            ApplySettings()
        end
    })
    row6b:AddWidget(stackAnchorDropdown, 1 / 3)
    manager:Register(stackAnchorDropdown, "all")

    local stackXSlider = GUIFrame:CreateSlider(row6b, "Stack X", {
        min = -50,
        max = 50,
        step = 1,
        value = db.StackPosition.XOffset,
        callback = function(value)
            db.StackPosition.XOffset = value
            ApplySettings()
        end
    })
    row6b:AddWidget(stackXSlider, 1 / 3)
    manager:Register(stackXSlider, "all")

    local stackYSlider = GUIFrame:CreateSlider(row6b, "Stack Y", {
        min = -50,
        max = 50,
        step = 1,
        value = db.StackPosition.YOffset,
        callback = function(value)
            db.StackPosition.YOffset = value
            ApplySettings()
        end
    })
    row6b:AddWidget(stackYSlider, 1 / 3)
    manager:Register(stackYSlider, "all")
    card6:AddRow(row6b, Theme.rowHeightLast, 0)

    yOffset = card6:GetNextOffset()

    -- Card 7: Font Settings
    local fontCard, fontOffset, fontWidgets = GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, {
        title = "Font Settings",
        db = db,
        dbKeys = { fontFace = "FontFace", fontOutline = "FontOutline" },
        fontSizes = {
            { label = "Count Size", dbKey = "FontSize" },
            { label = "Timer Size", dbKey = "TimerFontSize" },
        },
        fontSizeRange = { 8, 32 },
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
    manager:Register(fontCard, "all")
    manager:RegisterGroup(fontWidgets, "all")

    yOffset = fontOffset

    -- Card 8: Position
    local posCard, posOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = true,
        showStrata = true,
        disableAnchorFrom = true,
        onChangeCallback = function()
            if AdvancedDebuffs and AdvancedDebuffs.ApplyPosition then
                AdvancedDebuffs:ApplyPosition()
            end
        end,
    })
    manager:Register(posCard, "all")

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)

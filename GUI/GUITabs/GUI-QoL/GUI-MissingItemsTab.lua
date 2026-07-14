---@class NRSKNUI
local NRSKNUI = select(2, ...)

local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local pairs, ipairs = pairs, ipairs
local table_insert = table.insert
local table_sort = table.sort
local table_remove = table.remove
local tContains = tContains
local C_Item = C_Item

local SIDEBAR_WIDTH = 180
local ITEM_HEIGHT = 34
local LIST_PADDING = 4

local selectedItem = "General"
local specFilterExpandedClasses = {}

local function GetModule()
    if NRSKNUI then
        return NRSKNUI:GetModule("MissingItems", true)
    end
    return nil
end

local function GetNextTempItemID(items)
    local maxTemp = 0
    for itemID in pairs(items) do
        if itemID < 0 and itemID < maxTemp then
            maxTemp = itemID
        end
    end
    return maxTemp - 1
end

GUIFrame:RegisterPanel("missingItems", function(container)
    local db = NRSKNUI.db and NRSKNUI.db.profile.MissingItems
    if not db then return nil end

    db.Groups = db.Groups or {}
    db.Items = db.Items or {}
    db.Display = db.Display or {}
    db.ActiveGroup = db.ActiveGroup or db.Groups[1]

    local function ApplySettings()
        local mod = GetModule()
        if mod and mod.ApplySettings then mod:ApplySettings() end
    end

    local function Refresh()
        local mod = GetModule()
        if mod and mod.Refresh then mod:Refresh() end
    end

    local function RefreshContent()
        C_Timer.After(0.05, function()
            GUIFrame:RefreshContent()
        end)
    end

    local function SetActiveGroup(groupName)
        db.ActiveGroup = groupName
        local mod = GetModule()
        if mod and mod.SetActiveGroup then mod:SetActiveGroup(groupName) end
    end

    local manager = GUIFrame:CreateWidgetStateManager()

    local function UpdateAllWidgetStates()
        manager:UpdateAll(db.Enabled)
    end

    local function GetGroupOptions()
        local options = {}
        for _, name in ipairs(db.Groups) do
            table_insert(options, { key = name, text = name })
        end
        return options
    end

    local function GetSidebarItems()
        local items = {}
        local order = 1

        local activeGroup = db.ActiveGroup
        if not activeGroup or not tContains(db.Groups, activeGroup) then
            activeGroup = db.Groups[1]
            db.ActiveGroup = activeGroup
        end

        if activeGroup then
            table_insert(items, {
                key = "sep_group",
                name = activeGroup,
                order = order,
                type = "separator",
            })
            order = order + 1

            local itemList = {}
            for itemID, settings in pairs(db.Items) do
                table_insert(itemList, { itemID = itemID, settings = settings })
            end

            table_sort(itemList, function(a, b) return a.itemID > b.itemID end)

            for _, itemData in ipairs(itemList) do
                local itemID = itemData.itemID
                local itemName = C_Item.GetItemNameByID(itemID)
                local itemIcon = C_Item.GetItemIconByID(itemID)

                if not itemName and itemID > 0 then
                    local item = Item:CreateFromItemID(itemID)
                    item:ContinueOnItemLoad(function()
                        C_Timer.After(0.05, function()
                            GUIFrame:RefreshContent()
                        end)
                    end)
                end

                table_insert(items, {
                    key = "item_" .. itemID,
                    name = (itemID < 0 and "New Item") or itemName or ("Item " .. itemID),
                    icon = itemIcon,
                    order = order,
                    type = "item",
                    itemID = itemID,
                    settings = itemData.settings,
                })
                order = order + 1
            end

            table_insert(items, {
                key = "action_new_item",
                name = "+ New Item",
                order = order,
                type = "action",
            })
            order = order + 1
        end

        return items
    end

    local miniSidebar = NRSKNUI.GUI.CreateMiniSidebar(container, {
        sidebarWidth = SIDEBAR_WIDTH,
        listPadding = LIST_PADDING,
        itemHeight = ITEM_HEIGHT,
        activeItem = true,

        getItems = GetSidebarItems,
        getItemKey = function(item) return item.key end,

        renderItem = function(btn, item, isSelected)
            if item.type == "action" then
                btn._iconBorder:Hide()
                btn._icon:Hide()
                btn._label:SetPoint("LEFT", btn, "LEFT", 8, 0)
                btn._label:SetText(item.name)
                btn._label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                return
            end

            btn._iconBorder:Show()
            btn._icon:Show()
            btn._label:ClearAllPoints()
            btn._label:SetPoint("LEFT", btn._iconBorder, "RIGHT", 6, 0)
            btn._label:SetPoint("RIGHT", btn, "RIGHT", -4, 0)

            if item.icon then
                btn._icon:SetTexture(item.icon)
                btn._icon:SetZoom()
            else
                btn._icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end

            btn._label:SetShadowColor(0, 0, 0, 0)
            btn._label:SetText(item.name)

            if item.settings and item.settings.enabled == false then
                btn._label:SetTextColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)
            elseif isSelected then
                btn._label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            else
                btn._label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
            end
        end,

        onItemSelected = function(item)
            if item.type == "action" and item.key == "action_new_item" then
                local activeGroup = db.ActiveGroup
                if not activeGroup then
                    NRSKNUI:Print("Create a group first")
                    return
                end
                local tempID = GetNextTempItemID(db.Items)
                db.Items[tempID] = {
                    threshold = 10,
                    enabled = true,
                    groups = { activeGroup },
                }
                selectedItem = "item_" .. tempID
                Refresh()
                RefreshContent()
                return
            end

            selectedItem = item.key
            RefreshContent()
        end,

        buttonArea = {
            layout = "horizontal",
            buttonHeight = ITEM_HEIGHT,
            spacing = LIST_PADDING,
            rowSpacing = 2,
            rows = {
                {
                    {
                        text = "Settings",
                        onClick = function()
                            selectedItem = "General"; RefreshContent()
                        end
                    },
                    {
                        text = "Loadouts",
                        onClick = function()
                            selectedItem = "Groups"; RefreshContent()
                        end
                    },
                },
            },
        },
    })

    miniSidebar.SelectItem(selectedItem)
    miniSidebar.RefreshList()

    local contentChild = miniSidebar.contentArea.scrollChild
    local yOffset = Theme.paddingSmall

    local itemData = nil
    local sidebarItems = GetSidebarItems()
    for _, item in ipairs(sidebarItems) do
        if item.key == selectedItem then
            itemData = item
            break
        end
    end

    if selectedItem == "General" then
        local card1 = GUIFrame:CreateCard(contentChild, "Missing Items", yOffset)
        miniSidebar.contentArea.RegisterCard(card1)

        local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
        local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Missing Items", {
            value = db.Enabled ~= false,
            callback = function(checked)
                db.Enabled = checked
                local mod = GetModule()
                if mod then
                    if checked then
                        NRSKNUI:EnableModule("MissingItems")
                    else
                        NRSKNUI:DisableModule("MissingItems")
                    end
                end
                UpdateAllWidgetStates()
            end,
            msgPopup = true,
            msgText = "Missing Items",
        })
        row1:AddWidget(enableCheck, 1)
        card1:AddRow(row1, Theme.rowHeight)

        local sep1 = GUIFrame:CreateSeparator(card1.content)
        card1:AddRow(sep1, Theme.rowHeightSeparator)

        local row2a = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
        local lineSpacingSlider = GUIFrame:CreateSlider(row2a, "Line Spacing", {
            min = -10,
            max = 20,
            step = 1,
            value = db.Display.LineSpacing or 4,
            callback = function(val)
                db.Display.LineSpacing = val
                ApplySettings()
            end
        })
        row2a:AddWidget(lineSpacingSlider, 1)
        manager:Register(lineSpacingSlider, "all")
        card1:AddRow(row2a, Theme.rowHeightLast, 0)

        yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

        local fontCard
        fontCard, yOffset = GUIFrame:CreateFontSettingsCard(contentChild, yOffset, {
            title = "Text Settings",
            db = db.Display,
            fontSizeRange = { 8, 32 },
            includeSoftOutline = true,
            onChangeCallback = ApplySettings,
            globalOverride = {},
        })
        miniSidebar.contentArea.RegisterCard(fontCard)
        manager:Register(fontCard, "all")

        db.Display.Position = db.Display.Position or {}
        local positionCard
        positionCard, yOffset = GUIFrame:CreatePositionCard(contentChild, yOffset, {
            title = "Position Settings",
            db = db.Display,
            defaults = {
                selfPoint = "CENTER",
                anchorPoint = "CENTER",
                xOffset = 0,
                yOffset = -200,
            },
            showAnchorFrameType = false,
            showStrata = false,
            onChangeCallback = ApplySettings,
        })
        miniSidebar.contentArea.RegisterCard(positionCard)
        manager:Register(positionCard, "all")

        UpdateAllWidgetStates()
    elseif selectedItem == "Groups" then
        local card0 = GUIFrame:CreateCard(contentChild, "Active Loadout", yOffset)
        miniSidebar.contentArea.RegisterCard(card0)

        local row0 = GUIFrame:CreateRow(card0.content, Theme.rowHeightLast)
        local groupDropdown = GUIFrame:CreateDropdown(row0, "Active Loadout", {
            options = GetGroupOptions(),
            value = db.ActiveGroup,
            callback = function(key)
                SetActiveGroup(key)
                C_Timer.After(0.2, function()
                    Refresh()
                    RefreshContent()
                end)
            end
        })
        row0:AddWidget(groupDropdown, 1)
        card0:AddRow(row0, Theme.rowHeightLast, 0)

        yOffset = yOffset + card0:GetContentHeight() + Theme.paddingSmall

        local card1 = GUIFrame:CreateCard(contentChild, "Create Loadout", yOffset)
        miniSidebar.contentArea.RegisterCard(card1)

        local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
        local newGroupInput = GUIFrame:CreateEditBox(row1, "Group Name", {
            value = "",
        })
        row1:AddWidget(newGroupInput, 0.7)

        local createBtn = GUIFrame:CreateButton(row1, "Create", {
            height = 24,
            callback = function()
                local name = newGroupInput:GetValue()
                if name and name ~= "" and not tContains(db.Groups, name) then
                    table_insert(db.Groups, name)
                    newGroupInput:SetValue("")
                    SetActiveGroup(name)
                    Refresh()
                    RefreshContent()
                end
            end
        })
        row1:AddWidget(createBtn, 0.3, nil, 0, -14)
        card1:AddRow(row1, Theme.rowHeightLast, 0)

        yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

        if #db.Groups > 0 then
            local deleteOptions = {}
            for _, name in ipairs(db.Groups) do
                table_insert(deleteOptions, { key = name, text = name })
            end

            local card2 = GUIFrame:CreateCard(contentChild, "Delete Loadout", yOffset)
            miniSidebar.contentArea.RegisterCard(card2)

            local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
            local deleteDropdown = GUIFrame:CreateDropdown(row2, "Select Loadout", {
                options = deleteOptions,
                value = db.Groups[1],
                labelWidth = 100,
            })
            row2:AddWidget(deleteDropdown, 0.7)

            local deleteBtn = GUIFrame:CreateButton(row2, "Delete", {
                height = 24,
                callback = function()
                    local groupToDelete = deleteDropdown:GetValue()
                    if not groupToDelete then return end
                    if #db.Groups <= 1 then
                        NRSKNUI:Print("Cannot delete the last loadout.")
                        return
                    end
                    NRSKNUI:CreatePrompt({
                        title = "Delete Loadout",
                        text = "Are you sure you want to delete: " .. groupToDelete .. "?",
                        onAccept = function()
                            local mod = GetModule()
                            if mod and mod.DeleteGroup then mod:DeleteGroup(groupToDelete) end
                            if db.ActiveGroup == groupToDelete then
                                db.ActiveGroup = db.Groups[1]
                            end
                            Refresh()
                            RefreshContent()
                        end,
                        acceptText = "Delete",
                        cancelText = "Cancel",
                    })
                end
            })
            row2:AddWidget(deleteBtn, 0.3, nil, 0, -14)
            card2:AddRow(row2, Theme.rowHeightLast, 0)

            yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall
        end

        local card3 = GUIFrame:CreateCard(contentChild, "Import / Export", yOffset)
        miniSidebar.contentArea.RegisterCard(card3)

        local exportOptions = {}
        for _, name in ipairs(db.Groups) do
            table_insert(exportOptions, { key = name, text = name })
        end

        local row3 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
        local exportDropdown = GUIFrame:CreateDropdown(row3, "Export Loadout", {
            options = exportOptions,
            value = db.ActiveGroup or db.Groups[1],
            labelWidth = 100,
        })
        row3:AddWidget(exportDropdown, 0.7)

        local exportBtn = GUIFrame:CreateButton(row3, "Export", {
            height = 24,
            callback = function()
                local groupToExport = exportDropdown:GetValue()
                if groupToExport then
                    local mod = GetModule()
                    if mod and mod.ExportGroup then
                        local exportString, err = mod:ExportGroup(groupToExport)
                        if exportString then
                            NRSKNUI:CreateCopyDialog("Export: " .. groupToExport, exportString,
                                "Copy this string to share your loadout")
                        else
                            NRSKNUI:Print("Export failed: " .. (err or "Unknown error"))
                        end
                    end
                end
            end
        })
        row3:AddWidget(exportBtn, 0.3, nil, 0, -14)
        card3:AddRow(row3, Theme.rowHeight)

        local sep3 = GUIFrame:CreateSeparator(card3.content)
        card3:AddRow(sep3, Theme.rowHeightSeparator)

        local importRow = 26
        local row4 = GUIFrame:CreateRow(card3.content, importRow)
        local importBtn = GUIFrame:CreateButton(row4, "Import Loadout", {
            height = 24,
            callback = function()
                NRSKNUI:CreatePrompt({
                    title = "Import Loadout",
                    text = "",
                    editBox = true,
                    editBoxLabel = "Paste import string",
                    onAccept = function(inputText)
                        local mod = GetModule()
                        if mod and mod.ImportGroup then
                            local success, result = mod:ImportGroup(inputText)
                            if success then
                                NRSKNUI:Print("Import successful: " .. result)
                                if mod.Refresh then mod:Refresh() end
                                RefreshContent()
                            else
                                NRSKNUI:Print("Import failed: " .. (result or "Unknown error"))
                            end
                        end
                    end,
                    acceptText = "Import",
                    cancelText = "Cancel",
                })
            end
        })
        row4:AddWidget(importBtn, 1)
        card3:AddRow(row4, importRow)

        yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall
    elseif itemData and itemData.type == "item" then
        local itemID = itemData.itemID
        local settings = db.Items[itemID]

        manager:SetCondition("loaded", function() return settings.enabled end)

        if not settings then
            miniSidebar.contentArea.SetContentHeight(yOffset)
            return miniSidebar.panel
        end

        local itemName = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
        local cardTitle = itemID < 0 and "New Item" or itemName

        local card1 = GUIFrame:CreateCard(contentChild, cardTitle, yOffset)
        miniSidebar.contentArea.RegisterCard(card1)
        manager:Register(card1, "all")

        local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
        local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Tracking", {
            value = settings.enabled ~= false,
            callback = function(checked)
                settings.enabled = checked
                Refresh()
                UpdateAllWidgetStates()
                miniSidebar.RefreshList()
            end
        })
        row1:AddWidget(enableCheck, 0.7)
        manager:Register(enableCheck, "all")

        local deleteItemBtn = GUIFrame:CreateButton(row1, "Delete", {
            height = 30,
            callback = function()
                db.Items[itemID] = nil
                selectedItem = "General"
                Refresh()
                RefreshContent()
            end
        })
        row1:AddWidget(deleteItemBtn, 0.3, nil, 0, -6)
        card1:AddRow(row1, Theme.rowHeight)

        local sep1 = GUIFrame:CreateSeparator(card1.content)
        card1:AddRow(sep1, Theme.rowHeightSeparator)

        local row2 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
        local thresholdSlider = GUIFrame:CreateSlider(row2, "Warning Threshold", {
            min = 0,
            max = 200,
            step = 1,
            value = settings.threshold or 10,
            callback = function(val)
                settings.threshold = val
                Refresh()
            end
        })
        row2:AddWidget(thresholdSlider, 0.5)
        manager:Register(thresholdSlider, "all", "loaded")

        local colorPicker = GUIFrame:CreateColorPicker(row2, "Text Color", {
            color = settings.color or db.Display.DefaultColor,
            callback = function(r, g, b, a)
                settings.color = { r, g, b, a }
                Refresh()
            end
        })
        row2:AddWidget(colorPicker, 0.5)
        manager:Register(colorPicker, "all", "loaded")
        card1:AddRow(row2, Theme.rowHeight)

        local row3 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
        local buyQtySlider = GUIFrame:CreateSlider(row3, "Auctionator Buy Quantity", {
            min = 0,
            max = 200,
            step = 1,
            value = settings.buyQuantity or 0,
            callback = function(val)
                settings.buyQuantity = val
            end
        })
        row3:AddWidget(buyQtySlider, 1)
        manager:Register(buyQtySlider, "all", "loaded")
        card1:AddRow(row3, Theme.rowHeightLast, 0)

        yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

        settings.variants = settings.variants or {}
        settings.trackMode = settings.trackMode or "exact"

        local allItems = {}
        if itemID > 0 then
            table_insert(allItems, { itemID = itemID, rank = 1 })
        end
        for i, variantID in ipairs(settings.variants) do
            table_insert(allItems, { itemID = variantID, rank = i + 1 })
        end

        local cardIDs
        cardIDs, yOffset = GUIFrame:CreateItemBrowserCard(contentChild, yOffset, {
            title = "Item IDs",
            items = allItems,
            trackingMode = settings.trackMode,
            onTrackingModeChange = function(newMode)
                settings.trackMode = newMode
                if newMode == "exact" then
                    settings.variants = {}
                end
                Refresh()
                RefreshContent()
            end,
            onItemRemove = function(_, rank)
                if rank == 1 then
                    local tempID = GetNextTempItemID(db.Items)
                    db.Items[tempID] = settings
                    db.Items[itemID] = nil
                    settings.variants = {}
                    selectedItem = "item_" .. tempID
                    Refresh()
                    RefreshContent()
                else
                    table.remove(settings.variants, rank - 1)
                    Refresh()
                    RefreshContent()
                end
            end,
            onItemAdd = function(newID)
                local function DoRefresh()
                    Refresh()
                    RefreshContent()
                end

                local function EnsureItemLoadedThenRefresh()
                    local item = Item:CreateFromItemID(newID)
                    item:ContinueOnItemLoad(DoRefresh)
                end

                if itemID < 0 then
                    db.Items[newID] = settings
                    db.Items[itemID] = nil
                    selectedItem = "item_" .. newID
                    EnsureItemLoadedThenRefresh()
                elseif settings.trackMode == "exact" then
                    local oldSettings = db.Items[itemID]
                    db.Items[itemID] = nil
                    db.Items[newID] = oldSettings
                    selectedItem = "item_" .. newID
                    EnsureItemLoadedThenRefresh()
                elseif settings.trackMode == "auto" then
                    local oldSettings = db.Items[itemID]
                    db.Items[itemID] = nil
                    oldSettings.variants = {}
                    db.Items[newID] = oldSettings
                    selectedItem = "item_" .. newID
                    EnsureItemLoadedThenRefresh()
                else
                    local variantItem = Item:CreateFromItemID(newID)
                    variantItem:ContinueOnItemLoad(function()
                        table_insert(settings.variants, newID)
                        Refresh()
                        RefreshContent()
                    end)
                end
            end,
        })
        miniSidebar.contentArea.RegisterCard(cardIDs)
        manager:Register(cardIDs, "all", "loaded")

        settings.groups = settings.groups or {}

        local card3 = GUIFrame:CreateCard(contentChild, "Track in Loadouts", yOffset)
        miniSidebar.contentArea.RegisterCard(card3)
        manager:Register(card3, "all", "loaded")

        for i, groupName in ipairs(db.Groups) do
            local isInGroup = tContains(settings.groups, groupName)
            local isActive = groupName == db.ActiveGroup
            local isLast = (i == #db.Groups)
            local rowHeight = isLast and Theme.rowHeightLast or Theme.rowHeight

            local displayName = isActive and (groupName .. " (Active)") or groupName

            local groupRow = GUIFrame:CreateRow(card3.content, rowHeight)
            local groupCheck = GUIFrame:CreateCheckbox(groupRow, displayName, {
                value = isInGroup,
                callback = function(checked)
                    if checked then
                        if not tContains(settings.groups, groupName) then
                            table_insert(settings.groups, groupName)
                        end
                    else
                        for j, name in ipairs(settings.groups) do
                            if name == groupName then
                                table_remove(settings.groups, j)
                                break
                            end
                        end
                    end
                    Refresh()
                    RefreshContent()
                end
            })
            groupRow:AddWidget(groupCheck, 1)
            manager:Register(groupCheck, "all", "loaded")

            if isLast then
                card3:AddRow(groupRow, Theme.rowHeightLast, 0)
            else
                card3:AddRow(groupRow, rowHeight)
                local sep = GUIFrame:CreateSeparator(card3.content)
                card3:AddRow(sep, Theme.rowHeightSeparator)
            end
        end

        yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

        settings.loadSpecs = settings.loadSpecs or {}

        local specCard
        specCard, yOffset = GUIFrame:CreateSpecFilterCard(contentChild, yOffset, {
            title = "Specialization Filter",
            db = settings,
            dbKeys = {
                enabled = "loadSpecEnabled",
                specs = "loadSpecs",
            },
            expandedClasses = specFilterExpandedClasses,
            onChangeCallback = function()
                Refresh()
                RefreshContent()
            end,
            onRefreshCallback = RefreshContent,
        })
        miniSidebar.contentArea.RegisterCard(specCard)
        manager:Register(specCard, "all", "loaded")

        UpdateAllWidgetStates()
    end

    miniSidebar.contentArea.SetContentHeight(yOffset)
    C_Timer.After(0, function()
        if miniSidebar.panel:IsShown() then
            miniSidebar.contentArea.UpdateScrollBarVisibility()
            miniSidebar.contentArea.UpdateCardWidths()
        end
    end)

    return miniSidebar.panel
end)
---@class NRSKNUI
local NRSKNUI = select(2, ...)

local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local table_insert = table.insert

local SIDEBAR_WIDTH = 192
local ITEM_HEIGHT = 34
local LIST_PADDING = 4

local selectedItem = 'General'

local SIDEBAR_ITEMS = {
    { key = 'ObjectiveTracker', name = 'Objective Tracker', order = 1 },
}

GUIFrame:RegisterPanel('BlizzardElementsTab', function(container)
    if NRSKNUI:ShouldNotLoadModule() then return nil end
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.BlizzardElements
    if not db then return nil end

    local function RefreshContent()
        C_Timer.After(0.05, function()
            GUIFrame:RefreshContent()
        end)
    end

    local manager = GUIFrame:CreateWidgetStateManager()

    local function UpdateAllWidgetStates()
        manager:UpdateAll(db.Enabled)
    end

    local function GetSidebarItems()
        local items = {}
        for _, item in ipairs(SIDEBAR_ITEMS) do
            table_insert(items, {
                key = item.key,
                name = item.name,
                order = item.order,
            })
        end
        table.sort(items, function(a, b) return a.order < b.order end)
        return items
    end

    local miniSidebar = NRSKNUI.GUI.CreateMiniSidebar(container, {
        sidebarWidth = SIDEBAR_WIDTH,
        listPadding = LIST_PADDING,
        itemHeight = ITEM_HEIGHT,

        getItems = GetSidebarItems,
        getItemKey = function(item) return item.key end,

        renderItem = function(btn, item, isSelected)
            btn._icon:SetTexture('Interface\\Icons\\INV_Misc_Note_01')
            btn._icon:SetZoom()

            btn._label:SetShadowColor(0, 0, 0, 0)
            btn._label:SetText(item.name)

            if isSelected then
                btn._label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            else
                btn._label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
            end
        end,

        onItemSelected = function(item)
            selectedItem = item.key
            RefreshContent()
        end,

        buttonArea = {
            buttonHeight = ITEM_HEIGHT,
            hideSeparator = false,
            listSpacing = 8,
            buttons = {
                {
                    text = 'General Settings',
                    onClick = function()
                        selectedItem = 'General'
                        RefreshContent()
                    end,
                },
            },
        },
    })

    miniSidebar.SelectItem(selectedItem)
    miniSidebar.RefreshList()

    local contentChild = miniSidebar.contentArea.scrollChild
    local yOffset = Theme.paddingSmall


    if selectedItem == 'General' then
        local function ApplyFrameSettings()
            local bf = NRSKNUI:GetModule('Skinning', true)
            if bf and bf.ApplySettings then bf:ApplySettings() end
        end

        -- Card 1: Enable Toggle
        local card1 = GUIFrame:CreateCard(contentChild, 'Blizzard Elements', yOffset)
        miniSidebar.contentArea.RegisterCard(card1)

        local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
        local enableCheck = GUIFrame:CreateCheckbox(row1, 'Enable Blizzard Elements Skinning', {
            value = db.Enabled ~= false,
            callback = function(checked)
                db.Enabled = checked
                if checked then
                    NRSKNUI:EnableModule('BlizzObjectiveTracker')
                    NRSKNUI:EnableModule('Skinning')
                else
                    NRSKNUI:DisableModule('BlizzObjectiveTracker')
                    NRSKNUI:DisableModule('Skinning')
                    NRSKNUI:CreateReloadPrompt(
                        'Restoring default Blizzard elements requires a reload to take full effect.')
                end
                local mod = NRSKNUI:GetModule('BlizzObjectiveTracker', true)
                if mod and mod.ApplySettings then mod:ApplySettings() end
                ApplyFrameSettings()
                UpdateAllWidgetStates()
                RefreshContent()
            end,
            msgPopup = true,
            msgText = 'Blizzard Elements Skinning',
        })
        row1:AddWidget(enableCheck, 1)
        card1:AddRow(row1, Theme.rowHeightLast, 0)

        yOffset = card1:GetNextOffset()

        -- Card 2: Skin Colors
        local COLOR_MODES = {
            { key = 'Theme',  text = 'Theme Color' },
            { key = 'Class',  text = 'Class Color' },
            { key = 'Custom', text = 'Custom Color' },
        }

        manager:SetCondition('customAccent', function() return db.General.AccentMode == 'Custom' end)

        local card2 = GUIFrame:CreateCard(contentChild, 'Skin Colors', yOffset)
        miniSidebar.contentArea.RegisterCard(card2)
        manager:Register(card2, 'all')

        local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
        local borderPicker = GUIFrame:CreateColorPicker(row2, 'Border Color', {
            color = db.General.BorderColor,
            callback = function(r, g, b, a)
                db.General.BorderColor = { r, g, b, a }
                ApplyFrameSettings()
            end
        })
        row2:AddWidget(borderPicker, 0.5)
        manager:Register(borderPicker, 'all')

        local backgroundPicker = GUIFrame:CreateColorPicker(row2, 'Background Color', {
            color = db.General.BackgroundColor,
            callback = function(r, g, b, a)
                db.General.BackgroundColor = { r, g, b, a }
                ApplyFrameSettings()
            end
        })
        row2:AddWidget(backgroundPicker, 0.5)
        manager:Register(backgroundPicker, 'all')
        card2:AddRow(row2, Theme.rowHeight)

        local sep2 = GUIFrame:CreateSeparator(card2.content)
        card2:AddRow(sep2, Theme.rowHeightSeparator)
        manager:Register(sep2, 'all')

        local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
        local accentModeDropdown = GUIFrame:CreateDropdown(row2b, 'Accent Mode', {
            options = COLOR_MODES,
            value = db.General.AccentMode or 'Theme',
            labelWidth = 80,
            callback = function(key)
                db.General.AccentMode = key
                UpdateAllWidgetStates()
                ApplyFrameSettings()
            end
        })
        row2b:AddWidget(accentModeDropdown, 0.5)
        manager:Register(accentModeDropdown, 'all')

        local accentPicker = GUIFrame:CreateColorPicker(row2b, 'Custom Accent', {
            color = db.General.CustomAccentColor,
            callback = function(r, g, b, a)
                db.General.CustomAccentColor = { r, g, b, a }
                ApplyFrameSettings()
            end
        })
        row2b:AddWidget(accentPicker, 0.5)
        manager:Register(accentPicker, 'all', 'customAccent')
        card2:AddRow(row2b, Theme.rowHeightLast, 0)

        yOffset = card2:GetNextOffset()

        -- Card4: Font Settings
        local fontCard, fontOffset, fontWidgets = GUIFrame:CreateFontSettingsCard(contentChild, yOffset, {
            db = db,
            includeSoftOutline = false,
            onChangeCallback = ApplyFrameSettings,
            globalOverride = {},
            fontSizes = {
                { label = 'Tab Text Size', dbKey = 'FontTabSize' },
                { label = 'Normal Text', dbKey = 'TextSize' },
                { label = 'Small Text',  dbKey = 'TextSmallSize' },
            },
        })
        manager:Register(fontCard, 'all')
        manager:RegisterGroup(fontWidgets, 'all')

        yOffset = fontOffset

        -- Card 3: Skinned Frames
        local FRAME_TOGGLES = {
            { key = 'CharacterFrame', label = 'Character Frame' },
            { key = 'InspectFrame',   label = 'Inspect Frame' },
            { key = 'PlayerSpells',   label = 'Spellbook & Talents' },
        }

        local card3 = GUIFrame:CreateCard(contentChild, 'Skinned Frames', yOffset)
        miniSidebar.contentArea.RegisterCard(card3)
        manager:Register(card3, 'all')

        local row3 = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
        for _, toggle in ipairs(FRAME_TOGGLES) do
            local check = GUIFrame:CreateCheckbox(row3, toggle.label, {
                value = db.Frames[toggle.key] ~= false,
                callback = function(checked)
                    db.Frames[toggle.key] = checked
                    if checked then
                        ApplyFrameSettings()
                    else
                        NRSKNUI:CreateReloadPrompt(
                            'Restoring the default ' .. toggle.label .. ' requires a reload to take full effect.')
                    end
                end
            })
            row3:AddWidget(check, 0.33)
            manager:Register(check, 'all')
        end
        card3:AddRow(row3, Theme.rowHeightLast, 0)

        yOffset = card3:GetNextOffset()
        UpdateAllWidgetStates()
    elseif selectedItem == 'ObjectiveTracker' then
        local objDb = db.ObjectiveTracker
        local objMod = NRSKNUI:GetModule('BlizzObjectiveTracker', true)
        manager:SetCondition('objEnabled', function() return objDb.Enabled end)
        manager:SetCondition('fontEnabled', function() return objDb.FontStyling end)

        local function ApplyObjSettings()
            if objMod and objMod.ApplySettings then objMod:ApplySettings() end
        end

        -- Card 1: Enable Toggle
        local card1 = GUIFrame:CreateCard(contentChild, 'Objective Tracker', yOffset)
        miniSidebar.contentArea.RegisterCard(card1)

        local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
        local enableCheck = GUIFrame:CreateCheckbox(row1, 'Enable Objective Tracker Skinning', {
            value = objDb.Enabled,
            callback = function(checked)
                objDb.Enabled = checked
                ApplyObjSettings()
                UpdateAllWidgetStates()
                NRSKNUI:CreateReloadPrompt('Objective Tracker skinning changes require a reload to take full effect.')
            end
        })
        row1:AddWidget(enableCheck, 1)
        card1:AddRow(row1, Theme.rowHeightLast, 0)

        yOffset = card1:GetNextOffset()

        -- Card 2: Visual Styling
        local card2 = GUIFrame:CreateCard(contentChild, 'Visual Styling', yOffset)
        miniSidebar.contentArea.RegisterCard(card2)
        manager:Register(card2, 'all', 'objEnabled')

        local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
        local headersCheck = GUIFrame:CreateCheckbox(row2, 'Skin Headers', {
            value = objDb.SkinHeaders,
            callback = function(checked)
                objDb.SkinHeaders = checked
                NRSKNUI:CreateReloadPrompt('Header styling changes require a reload to take effect.')
            end
        })
        row2:AddWidget(headersCheck, 0.5)
        manager:Register(headersCheck, 'all', 'objEnabled')

        local progressCheck = GUIFrame:CreateCheckbox(row2, 'Skin Progress Bars', {
            value = objDb.SkinProgressBars,
            callback = function(checked)
                objDb.SkinProgressBars = checked
                NRSKNUI:CreateReloadPrompt('Progress bar styling changes require a reload to take effect.')
            end
        })
        row2:AddWidget(progressCheck, 0.5)
        manager:Register(progressCheck, 'all', 'objEnabled')
        card2:AddRow(row2, Theme.rowHeight)

        local sep2 = GUIFrame:CreateSeparator(card2.content)
        card2:AddRow(sep2, Theme.rowHeightSeparator)
        manager:Register(sep2, 'all', 'objEnabled')

        local row3 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
        local minimizeCheck = GUIFrame:CreateCheckbox(row3, 'Skin Minimize Button', {
            value = objDb.SkinMinimizeButton,
            callback = function(checked)
                objDb.SkinMinimizeButton = checked
                NRSKNUI:CreateReloadPrompt('Minimize button styling changes require a reload to take effect.')
            end
        })
        row3:AddWidget(minimizeCheck, 0.5)
        manager:Register(minimizeCheck, 'all', 'objEnabled')

        local iconsCheck = GUIFrame:CreateCheckbox(row3, 'Skin Quest Icons', {
            value = objDb.SkinQuestIcons,
            callback = function(checked)
                objDb.SkinQuestIcons = checked
                NRSKNUI:CreateReloadPrompt('Quest icon styling changes require a reload to take effect.')
            end
        })
        row3:AddWidget(iconsCheck, 0.5)
        manager:Register(iconsCheck, 'all', 'objEnabled')
        card2:AddRow(row3, Theme.rowHeightLast, 0)

        yOffset = card2:GetNextOffset()

        -- Card 3: Color Settings
        local COLOR_MODES = {
            { key = 'Theme',  text = 'Theme Color' },
            { key = 'Class',  text = 'Class Color' },
            { key = 'Custom', text = 'Custom Color' },
        }

        manager:SetCondition('customColor', function() return objDb.ColorMode == 'Custom' end)

        local card3 = GUIFrame:CreateCard(contentChild, 'Color', yOffset)
        miniSidebar.contentArea.RegisterCard(card3)
        manager:Register(card3, 'all', 'objEnabled')

        local row3a = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
        local colorModeDropdown = GUIFrame:CreateDropdown(row3a, 'Color Mode', {
            options = COLOR_MODES,
            value = objDb.ColorMode or 'Theme',
            labelWidth = 70,
            callback = function(key)
                objDb.ColorMode = key
                UpdateAllWidgetStates()
                ApplyObjSettings()
            end
        })
        row3a:AddWidget(colorModeDropdown, 0.5)
        manager:Register(colorModeDropdown, 'all', 'objEnabled')

        local customColorPicker = GUIFrame:CreateColorPicker(row3a, 'Custom Color', {
            color = objDb.CustomColor or { 0, 1, 0.17, 1 },
            callback = function(r, g, b, a)
                objDb.CustomColor = { r, g, b, a }
                ApplyObjSettings()
            end
        })
        row3a:AddWidget(customColorPicker, 0.5)
        manager:Register(customColorPicker, 'all', 'objEnabled', 'customColor')
        card3:AddRow(row3a, Theme.rowHeightLast, 0)

        yOffset = card3:GetNextOffset()

        -- Card 4: Font Styling
        local card4 = GUIFrame:CreateCard(contentChild, 'Font Styling', yOffset)
        miniSidebar.contentArea.RegisterCard(card4)
        manager:Register(card4, 'all', 'objEnabled')

        local row4 = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
        local fontEnableCheck = GUIFrame:CreateCheckbox(row4, 'Enable Font Styling', {
            value = objDb.FontStyling,
            callback = function(checked)
                objDb.FontStyling = checked
                ApplyObjSettings()
                UpdateAllWidgetStates()
            end
        })
        row4:AddWidget(fontEnableCheck, 1)
        manager:Register(fontEnableCheck, 'all', 'objEnabled')
        card4:AddRow(row4, Theme.rowHeight)

        local sep4 = GUIFrame:CreateSeparator(card4.content)
        card4:AddRow(sep4, Theme.rowHeightSeparator)
        manager:Register(sep4, 'all', 'objEnabled', 'fontEnabled')

        local row5 = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
        local titleSlider = GUIFrame:CreateSlider(row5, 'Quest Title Size', {
            min = 8,
            max = 20,
            step = 1,
            value = objDb.QuestTitleSize,
            labelWidth = 90,
            callback = function(val)
                objDb.QuestTitleSize = val
                ApplyObjSettings()
            end
        })
        row5:AddWidget(titleSlider, 0.5)
        manager:Register(titleSlider, 'all', 'objEnabled', 'fontEnabled')

        local textSlider = GUIFrame:CreateSlider(row5, 'Quest Text Size', {
            min = 8,
            max = 20,
            step = 1,
            value = objDb.QuestTextSize,
            labelWidth = 90,
            callback = function(val)
                objDb.QuestTextSize = val
                ApplyObjSettings()
            end
        })
        row5:AddWidget(textSlider, 0.5)
        manager:Register(textSlider, 'all', 'objEnabled', 'fontEnabled')
        card4:AddRow(row5, Theme.rowHeightLast, 0)

        yOffset = card4:GetNextOffset()
        UpdateAllWidgetStates()
    end

    miniSidebar.contentArea.SetContentHeight(yOffset)
    C_Timer.After(0, function()
        miniSidebar.contentArea.UpdateScrollBarVisibility()
        miniSidebar.contentArea.UpdateCardWidths()
    end)

    return miniSidebar.panel
end)

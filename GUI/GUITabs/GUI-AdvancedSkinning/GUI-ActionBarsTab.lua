---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

local table_insert = table.insert
local ipairs = ipairs
local pairs = pairs
local CreateFrame = CreateFrame

local SIDEBAR_WIDTH = 192
local ITEM_HEIGHT = 34
local LIST_PADDING = 4
local TAB_BAR_HEIGHT = 30

local selectedKey = "Bar1"
local barSubTab = "general"

local BAR_SUB_TABS = {
    { id = "general",  text = "Layout" },
    { id = "texts",    text = "Texts" },
    { id = "backdrop", text = "Style" },
}

local BAR_LIST = {
    { key = "Bar1",      name = "Action Bar 1" },
    { key = "Bar2",      name = "Action Bar 2" },
    { key = "Bar3",      name = "Action Bar 3" },
    { key = "Bar4",      name = "Action Bar 4" },
    { key = "Bar5",      name = "Action Bar 5" },
    { key = "Bar6",      name = "Action Bar 6" },
    { key = "Bar7",      name = "Action Bar 7" },
    { key = "Bar8",      name = "Action Bar 8" },
    { key = "PetBar",    name = "Pet Bar" },
    { key = "StanceBar", name = "Stance Bar" },
}

local BAR_LIST_KV = {}
for _, bar in ipairs(BAR_LIST) do
    BAR_LIST_KV[bar.key] = bar.name
end

local SIDEBAR_ITEMS = {}
for i, bar in ipairs(BAR_LIST) do
    table_insert(SIDEBAR_ITEMS, { key = bar.key, name = bar.name, order = i })
end

local ANCHOR_OPTIONS = {
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



local function GetCurrentBarKey()
    if selectedKey == "Global" then return nil end
    return selectedKey
end

local function GetCurrentBarDB()
    local db = NRSKNUI.db.profile.Skinning.ActionBars
    if not db or selectedKey == "Global" then return nil end
    return db.Bars[selectedKey]
end

local function ApplyFonts()
    local ACB = NRSKNUI:GetModule("ActionBars", true)
    if ACB then ACB:UpdateSettings("fonts") end
end

local function ApplyProfTextures()
    local ACB = NRSKNUI:GetModule("ActionBars", true)
    if ACB then ACB:UpdateSettings("profTextures") end
end

local function ApplyBarSettings()
    local ACB = NRSKNUI:GetModule("ActionBars", true)
    local curEdit = GetCurrentBarKey()
    if ACB and curEdit then
        ACB:UpdateSettings("layout", curEdit)
        ACB:UpdateSettings("positions", curEdit)
        ACB:UpdateSettings("mouseover", curEdit)
        ACB:UpdateSettings("fonts")
        ACB:UpdateSettings("backdrops", curEdit)
    end
end

local function ApplyAllBars()
    local ACB = NRSKNUI:GetModule("ActionBars", true)
    if ACB then ACB:UpdateSettings("all") end
end

GUIFrame:RegisterPanel("ActionBars", function(container)
    local db = NRSKNUI.db.profile.Skinning.ActionBars
    if not db then return nil end

    if GUIFrame.pendingContext then
        local contextBar = GUIFrame.pendingContext
        if BAR_LIST_KV[contextBar] then
            selectedKey = contextBar
            barSubTab = "general"
        end
        GUIFrame.pendingContext = nil
    end

    local function RefreshContent() C_Timer.After(0.05, function() GUIFrame:RefreshContent() end) end
    local manager = GUIFrame:CreateWidgetStateManager()

    manager:SetCondition("bar", function()
        local barDB = GetCurrentBarDB()
        return barDB and barDB.Enabled ~= false
    end)

    local function GetSidebarItems()
        local items = {}
        for _, item in ipairs(SIDEBAR_ITEMS) do
            table_insert(items, {
                key = item.key,
                name = item.name,
                type = item.type,
                order = item.order,
            })
        end
        table.sort(items, function(a, b) return a.order < b.order end)
        return items
    end

    local RenderContent
    local contentArea

    local miniSidebar = NRSKNUI.GUI.CreateMiniSidebar(container, {
        sidebarWidth = SIDEBAR_WIDTH,
        listPadding = LIST_PADDING,
        itemHeight = ITEM_HEIGHT,
        itemSpacing = 2,

        getItems = GetSidebarItems,
        getItemKey = function(item) return item.key end,

        renderItem = function(btn, item, isSelected)
            btn._icon:SetColorTexture(0.15, 0.15, 0.15, 1)

            if not btn._numberText then
                local numberText = btn:CreateFontString(nil, "OVERLAY")
                numberText:SetAllPoints(btn._icon)
                numberText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
                numberText:SetJustifyH("CENTER")
                numberText:SetJustifyV("MIDDLE")
                numberText:SetShadowColor(0, 0, 0, 0)
                numberText:SetShadowOffset(0, 0)
                btn._numberText = numberText
            end

            local displayText = item.key:match("Bar(%d)") or (item.key == "PetBar" and "P") or
                (item.key == "StanceBar" and "S") or "?"
            btn._numberText:SetText(displayText)

            local barDb = db.Bars[item.key]
            local isBarEnabled = barDb and barDb.Enabled ~= false

            if not isBarEnabled then
                btn._icon:SetAlpha(0.5)
                btn._numberText:SetAlpha(0.5)
                btn._label:SetAlpha(0.5)
            else
                btn._icon:SetAlpha(1)
                btn._numberText:SetAlpha(1)
                btn._label:SetAlpha(1)
            end

            btn._label:SetText(item.name)
            btn._label:SetShadowColor(0, 0, 0, 0)

            if isSelected then
                btn._label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                btn._numberText:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            else
                if isBarEnabled then
                    btn._numberText:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3], 1)
                    btn._label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
                else
                    btn._numberText:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3], 0.5)
                    btn._label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.5)
                end
            end
        end,

        onItemSelected = function(item)
            local wasGlobal = (selectedKey == "Global")
            selectedKey = item.key
            if wasGlobal then
                RefreshContent()
            else
                RenderContent()
            end
        end,

        buttonArea = {
            buttonHeight = ITEM_HEIGHT,
            hideSeparator = false,
            listSpacing = 8,
            buttons = {
                {
                    text = "Global Settings",
                    onClick = function()
                        local wasGlobal = (selectedKey == "Global")
                        selectedKey = "Global"
                        if not wasGlobal then
                            RefreshContent()
                        end
                    end,
                },
            },
        },

        contentType = selectedKey ~= "Global" and "tabbed" or "basic",
        tabs = selectedKey ~= "Global" and BAR_SUB_TABS or nil,
        tabBarHeight = TAB_BAR_HEIGHT,
        defaultTab = barSubTab,
        onTabChanged = function(tabId)
            barSubTab = tabId
            RenderContent()
        end,
    })

    contentArea = miniSidebar.contentArea
    local isTabbed = (selectedKey ~= "Global")
    local scrollChild = contentArea.scrollChild
    local activeCards = contentArea.activeCards or {}

    if selectedKey ~= "Global" then
        miniSidebar.SelectItem(selectedKey)
    end
    miniSidebar.RefreshList()

    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do fontList[name] = name end
    else
        fontList["Friz Quadrata TT"] = "Friz Quadrata TT"
    end

    local function RenderGlobalContent(scrollChild, yOffset)
        -- Card 1
        local card1 = GUIFrame:CreateCard(scrollChild, "Action Bars", yOffset)
        table_insert(activeCards, card1)

        local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
        local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Action Bars Skinning", {
            value = db.Enabled ~= false,
            callback = function(checked)
                db.Enabled = checked
                if checked then
                    NRSKNUI:EnableModule("ActionBars")
                else
                    NRSKNUI:DisableModule("ActionBars")
                end
                manager:UpdateAll(checked)
                NRSKNUI:CreateReloadPrompt("Enabling/Disabling Action Bars requires a reload to take full effect.")
            end,
            msgPopup = true,
            msgText = "Action Bars",
            msgOn = "On",
            msgOff = "Off"
        })
        row1:AddWidget(enableCheck, 1)
        card1:AddRow(row1, Theme.rowHeight)

        yOffset = card1:GetNextOffset()

        -- Card 2
        local card2 = GUIFrame:CreateCard(scrollChild, "General Settings", yOffset)
        table_insert(activeCards, card2)
        manager:Register(card2, "main")

        local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
        local hideProfCheck = GUIFrame:CreateCheckbox(row2, "Hide Profession Texture", {
            value = db.HideProfTexture == true,
            callback = function(checked)
                db.HideProfTexture = checked
                ApplyProfTextures()
            end
        })
        row2:AddWidget(hideProfCheck, 0.5)
        manager:Register(hideProfCheck, "main")

        local hideMacroCheck = GUIFrame:CreateCheckbox(row2, "Hide Macro Text", {
            value = db.HideMacroText == true,
            callback = function(checked)
                db.HideMacroText = checked
                ApplyFonts()
            end
        })
        row2:AddWidget(hideMacroCheck, 0.5)
        manager:Register(hideMacroCheck, "main")
        card2:AddRow(row2, Theme.rowHeight)

        local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
        local hideKeybindCheck = GUIFrame:CreateCheckbox(row2b, "Hide Keybind Text", {
            value = db.HideKeybindText == true,
            callback = function(checked)
                db.HideKeybindText = checked
                ApplyFonts()
            end
        })
        row2b:AddWidget(hideKeybindCheck, 0.5)
        manager:Register(hideKeybindCheck, "main")

        local hideChargeCheck = GUIFrame:CreateCheckbox(row2b, "Hide Charge Text", {
            value = db.HideChargeText == true,
            callback = function(checked)
                db.HideChargeText = checked
                ApplyFonts()
            end
        })
        row2b:AddWidget(hideChargeCheck, 0.5)
        manager:Register(hideChargeCheck, "main")
        card2:AddRow(row2b, Theme.rowHeight)

        local sepRowColor = GUIFrame:CreateSeparator(card2.content)
        card2:AddRow(sepRowColor, Theme.rowHeightSeparator)

        local rowColor = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
        local RangeOverlayColor = GUIFrame:CreateColorPicker(rowColor, "Range Overlay", {
            color = db.RangeOverlayColor,
            callback = function(r, g, b, a)
                db.RangeOverlayColor = { r, g, b, a }
                local ACB = NRSKNUI:GetModule("ActionBars", true)
                if ACB then ACB:UpdateSettings("rangeOverlay") end
            end
        })
        rowColor:AddWidget(RangeOverlayColor, 1)
        manager:Register(RangeOverlayColor, "main")
        card2:AddRow(rowColor, Theme.rowHeightLast, 0)

        yOffset = card2:GetNextOffset()

        -- Card 3
        local card3 = GUIFrame:CreateCard(scrollChild, "Global Font Settings", yOffset)
        table_insert(activeCards, card3)
        manager:Register(card3, "main")

        manager:SetCondition("globalFontOverride", function() return db.UseGlobalFont == false end)

        local row3override = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
        local useGlobalFontCheck = GUIFrame:CreateCheckbox(row3override, "Use Global Font", {
            value = db.UseGlobalFont ~= false,
            callback = function(checked)
                db.UseGlobalFont = checked
                manager:UpdateAll(db.Enabled ~= false)
                ApplyFonts()
            end
        })
        row3override:AddWidget(useGlobalFontCheck, 1)
        manager:Register(useGlobalFontCheck, "main")
        card3:AddRow(row3override, Theme.rowHeight)

        local row3sepOverride = GUIFrame:CreateRow(card3.content, Theme.rowHeightSeparator)
        row3sepOverride:AddWidget(GUIFrame:CreateSeparator(row3sepOverride), 1)
        card3:AddRow(row3sepOverride, Theme.rowHeightSeparator)

        local row3a = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
        local fontDropdown = GUIFrame:CreateDropdown(row3a, "Font", {
            options = fontList,
            value = db.FontFace,
            callback = function(key)
                db.FontFace = key
                ApplyFonts()
            end,
            searchable = true,
            isFontPreview = true
        })
        row3a:AddWidget(fontDropdown, 0.5)
        manager:Register(fontDropdown, "main", "globalFontOverride")

        local outlineList = {
            ["NONE"] = "None",
            ["OUTLINE"] = "Outline",
            ["THICKOUTLINE"] = "Thick",
            ["SLUG"] = "Slug",
            ["SLUG,OUTLINE"] = "Slug Outline"
        }
        local outlineDropdown = GUIFrame:CreateDropdown(row3a, "Outline", {
            options = outlineList,
            value = db.FontOutline,
            callback = function(key)
                db.FontOutline = key
                ApplyFonts()
            end
        })
        row3a:AddWidget(outlineDropdown, 0.5)
        manager:Register(outlineDropdown, "main")
        card3:AddRow(row3a, Theme.rowHeight)

        local row3sep = GUIFrame:CreateRow(card3.content, Theme.rowHeightSeparator)
        row3sep:AddWidget(GUIFrame:CreateSeparator(row3sep), 1)
        card3:AddRow(row3sep, Theme.rowHeightSeparator)

        local row3b = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
        local keybindSize = GUIFrame:CreateSlider(row3b, "Keybind Size", {
            min = 6,
            max = 24,
            step = 1,
            value = db.FontSizes.KeybindSize,
            callback = function(val)
                db.FontSizes.KeybindSize = val
                ApplyFonts()
            end
        })
        row3b:AddWidget(keybindSize, 0.5)
        manager:Register(keybindSize, "main")

        local cooldownSize = GUIFrame:CreateSlider(row3b, "Cooldown Size", {
            min = 6,
            max = 24,
            step = 1,
            value = db.FontSizes.CooldownSize,
            callback = function(val)
                db.FontSizes.CooldownSize = val
                ApplyFonts()
            end
        })
        row3b:AddWidget(cooldownSize, 0.5)
        manager:Register(cooldownSize, "main")
        card3:AddRow(row3b, Theme.rowHeight)

        local row3c = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
        local chargeSize = GUIFrame:CreateSlider(row3c, "Charge Size", {
            min = 6,
            max = 24,
            step = 1,
            value = db.FontSizes.ChargeSize,
            callback = function(val)
                db.FontSizes.ChargeSize = val
                ApplyFonts()
            end
        })
        row3c:AddWidget(chargeSize, 0.5)
        manager:Register(chargeSize, "main")

        local macroSize = GUIFrame:CreateSlider(row3c, "Macro Size", {
            min = 6,
            max = 24,
            step = 1,
            value = db.FontSizes.MacroSize,
            callback = function(val)
                db.FontSizes.MacroSize = val
                ApplyFonts()
            end
        })
        row3c:AddWidget(macroSize, 0.5)
        manager:Register(macroSize, "main")
        card3:AddRow(row3c, Theme.rowHeight)

        yOffset = card3:GetNextOffset()

        -- Card 4
        local card4 = GUIFrame:CreateCard(scrollChild, "Global Mouseover Settings", yOffset)
        table_insert(activeCards, card4)
        manager:Register(card4, "main")

        local row4a = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
        local globalMouseoverCheck = GUIFrame:CreateCheckbox(row4a, "Enable Global Mouseover", {
            value = db.Mouseover and db.Mouseover.Enabled == true,
            callback = function(checked)
                db.Mouseover = db.Mouseover or {}
                db.Mouseover.Enabled = checked
                ApplyAllBars()
            end
        })
        row4a:AddWidget(globalMouseoverCheck, 0.5)
        manager:Register(globalMouseoverCheck, "main")

        local mouseoverOverrideCheck = GUIFrame:CreateCheckbox(row4a, "Override When Mounted/Vehicle", {
            value = db.MouseoverOverride == true,
            callback = function(checked)
                db.MouseoverOverride = checked
                local ACB = NRSKNUI:GetModule("ActionBars", true)
                if ACB then ACB:UpdateBonusBarOverride() end
            end
        })
        row4a:AddWidget(mouseoverOverrideCheck, 0.5)
        manager:Register(mouseoverOverrideCheck, "main")
        card4:AddRow(row4a, Theme.rowHeight)

        local row4sep = GUIFrame:CreateRow(card4.content, Theme.rowHeightSeparator)
        row4sep:AddWidget(GUIFrame:CreateSeparator(row4sep), 1)
        card4:AddRow(row4sep, Theme.rowHeightSeparator)

        local row4b = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
        local globalAlpha = GUIFrame:CreateSlider(row4b, "Fade Out Alpha", {
            min = 0,
            max = 1,
            step = 0.05,
            value = db.Mouseover and db.Mouseover.Alpha,
            callback = function(val)
                db.Mouseover = db.Mouseover or {}
                db.Mouseover.Alpha = val
                ApplyAllBars()
            end
        })
        row4b:AddWidget(globalAlpha, 1)
        manager:Register(globalAlpha, "main")
        card4:AddRow(row4b, Theme.rowHeight)

        local row4c = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
        local fadeIn = GUIFrame:CreateSlider(row4c, "Fade In Duration", {
            min = 0,
            max = 2,
            step = 0.1,
            value = db.Mouseover and db.Mouseover.FadeInDuration,
            callback = function(val)
                db.Mouseover = db.Mouseover or {}
                db.Mouseover.FadeInDuration = val
                ApplyAllBars()
            end
        })
        row4c:AddWidget(fadeIn, 0.5)
        manager:Register(fadeIn, "main")

        local fadeOut = GUIFrame:CreateSlider(row4c, "Fade Out Duration", {
            min = 0,
            max = 2,
            step = 0.1,
            value = db.Mouseover and db.Mouseover.FadeOutDuration,
            callback = function(val)
                db.Mouseover = db.Mouseover or {}
                db.Mouseover.FadeOutDuration = val
                ApplyAllBars()
            end
        })
        row4c:AddWidget(fadeOut, 0.5)
        manager:Register(fadeOut, "main")
        card4:AddRow(row4c, Theme.rowHeight)

        yOffset = card4:GetNextOffset()

        -- Card 5
        local card5 = GUIFrame:CreateCard(scrollChild, "Bar Enable/Disable", yOffset)
        table_insert(activeCards, card5)
        manager:Register(card5, "main")

        local barIndex = 1
        while barIndex <= #BAR_LIST do
            local rowHeight = 40
            local row = GUIFrame:CreateRow(card5.content, rowHeight)

            local bar1 = BAR_LIST[barIndex]
            if bar1 then
                local barDB1 = db.Bars[bar1.key]
                local check1 = GUIFrame:CreateCheckbox(row, bar1.name, {
                    value = barDB1 and barDB1.Enabled ~= false,
                    callback = function(checked)
                        if db.Bars[bar1.key] then
                            db.Bars[bar1.key].Enabled = checked
                            local ACB = NRSKNUI:GetModule("ActionBars", true)
                            if ACB then ACB:UpdateSettings("enabled", bar1.key) end
                            if checked then
                                NRSKNUI:CreateReloadPrompt("Enabling bars requires a reload to take full effect.")
                            end
                            miniSidebar.RefreshList()
                        end
                    end
                })
                row:AddWidget(check1, 0.5)
                manager:Register(check1, "main")
            end

            barIndex = barIndex + 1
            local bar2 = BAR_LIST[barIndex]
            if bar2 then
                local barDB2 = db.Bars[bar2.key]
                local check2 = GUIFrame:CreateCheckbox(row, bar2.name, {
                    value = barDB2 and barDB2.Enabled ~= false,
                    callback = function(checked)
                        if db.Bars[bar2.key] then
                            db.Bars[bar2.key].Enabled = checked
                            local ACB = NRSKNUI:GetModule("ActionBars", true)
                            if ACB then ACB:UpdateSettings("enabled", bar2.key) end
                            if checked then
                                NRSKNUI:CreateReloadPrompt("Enabling bars requires a reload to take full effect.")
                            end
                            miniSidebar.RefreshList()
                        end
                    end
                })
                row:AddWidget(check2, 0.5)
                manager:Register(check2, "main")
            else
                row:AddWidget(CreateFrame("Frame", nil, row), 0.5)
            end

            card5:AddRow(row, rowHeight)
            barIndex = barIndex + 1
        end

        yOffset = card5:GetNextOffset()

        return yOffset
    end

    local function RenderBarGeneralTab(scrollChild, yOffset)
        local curEdit = GetCurrentBarKey()
        local barDB = GetCurrentBarDB()
        if not curEdit or not barDB then return yOffset end

        -- Card 1: Layout
        local card1 = GUIFrame:CreateCard(scrollChild, "Layout", yOffset)
        table_insert(activeCards, card1)
        manager:Register(card1, "main", "bar")

        local row1a = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
        local buttonSizeSlider = GUIFrame:CreateSlider(row1a, "Button Size", {
            min = 20,
            max = 80,
            step = 1,
            value = barDB.ButtonSize,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb then bdb.ButtonSize = val end
                ApplyBarSettings()
            end
        })
        row1a:AddWidget(buttonSizeSlider, 0.5)
        manager:Register(buttonSizeSlider, "main", "bar")

        local spacingSlider = GUIFrame:CreateSlider(row1a, "Spacing", {
            min = -10,
            max = 20,
            step = 1,
            value = barDB.Spacing,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb then bdb.Spacing = val end
                ApplyBarSettings()
            end
        })
        row1a:AddWidget(spacingSlider, 0.5)
        manager:Register(spacingSlider, "main", "bar")
        card1:AddRow(row1a, Theme.rowHeight)

        local row1b = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
        local totalButtonsSlider = GUIFrame:CreateSlider(row1b, "Total Buttons", {
            min = 1,
            max = 12,
            step = 1,
            value = barDB.TotalButtons,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb then bdb.TotalButtons = val end
                ApplyBarSettings()
            end
        })
        row1b:AddWidget(totalButtonsSlider, 0.5)
        manager:Register(totalButtonsSlider, "main", "bar")

        local buttonsPerLineSlider = GUIFrame:CreateSlider(row1b, "Buttons Per Line", {
            min = 1,
            max = 12,
            step = 1,
            value = barDB.ButtonsPerLine,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb then bdb.ButtonsPerLine = val end
                ApplyBarSettings()
            end
        })
        row1b:AddWidget(buttonsPerLineSlider, 0.5)
        manager:Register(buttonsPerLineSlider, "main", "bar")
        card1:AddRow(row1b, Theme.rowHeight)

        local row1c = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
        local layoutList = { ["HORIZONTAL"] = "Horizontal", ["VERTICAL"] = "Vertical" }
        local layoutDropdown = GUIFrame:CreateDropdown(row1c, "Layout Direction", {
            options = layoutList,
            value = barDB.Layout,
            callback = function(key)
                local bdb = GetCurrentBarDB()
                if bdb then bdb.Layout = key end
                ApplyBarSettings()
            end
        })
        row1c:AddWidget(layoutDropdown, 0.5)
        manager:Register(layoutDropdown, "main", "bar")

        local growthList = { ["RIGHT"] = "Grow Right", ["LEFT"] = "Grow Left" }
        local growthDropdown = GUIFrame:CreateDropdown(row1c, "Growth Direction", {
            options = growthList,
            value = barDB.GrowthDirection,
            callback = function(key)
                local bdb = GetCurrentBarDB()
                if bdb then bdb.GrowthDirection = key end
                ApplyBarSettings()
            end
        })
        row1c:AddWidget(growthDropdown, 0.5)
        manager:Register(growthDropdown, "main", "bar")
        card1:AddRow(row1c, Theme.rowHeight)

        -- Flyout direction
        if curEdit:match("^Bar%d$") then
            local row1d = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
            local flyoutList = {
                ["AUTO"] = "Auto",
                ["UP"] = "Up",
                ["DOWN"] = "Down",
                ["LEFT"] = "Left",
                ["RIGHT"] = "Right"
            }
            local flyoutDropdown = GUIFrame:CreateDropdown(row1d, "Flyout Direction", {
                options = flyoutList,
                value = barDB.FlyoutDirection or "AUTO",
                callback = function(key)
                    local bdb = GetCurrentBarDB()
                    if bdb then bdb.FlyoutDirection = key end
                    local ACB = NRSKNUI:GetModule("ActionBars", true)
                    if ACB then ACB:UpdateSettings("flyout", curEdit) end
                end
            })
            row1d:AddWidget(flyoutDropdown, 1)
            manager:Register(flyoutDropdown, "main", "bar")
            card1:AddRow(row1d, Theme.rowHeightLast, 0)
        end

        yOffset = card1:GetNextOffset()

        -- Card 2: Position (using edge-relative AnchorPoint)
        local card2 = GUIFrame:CreateCard(scrollChild, "Position", yOffset)
        table_insert(activeCards, card2)
        manager:Register(card2, "main", "bar")

        -- Ensure Position table exists
        barDB.Position = barDB.Position or {}

        local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
        local anchorDropdown = GUIFrame:CreateDropdown(row2a, "Screen Anchor", {
            options = ANCHOR_OPTIONS,
            value = barDB.Position.AnchorPoint or "BOTTOM",
            callback = function(key)
                local bdb = GetCurrentBarDB()
                if bdb and bdb.Position then
                    bdb.Position.AnchorPoint = key
                end
                ApplyBarSettings()
            end
        })
        row2a:AddWidget(anchorDropdown, 1)
        manager:Register(anchorDropdown, "main", "bar")
        card2:AddRow(row2a, Theme.rowHeight)

        local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
        local xSlider = GUIFrame:CreateSlider(row2b, "X Offset", {
            min = -2000,
            max = 2000,
            step = 1,
            value = barDB.Position.XOffset or 0,
            labelWidth = 55,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb and bdb.Position then
                    bdb.Position.XOffset = val
                end
                ApplyBarSettings()
            end
        })
        row2b:AddWidget(xSlider, 0.5)
        manager:Register(xSlider, "main", "bar")

        local ySlider = GUIFrame:CreateSlider(row2b, "Y Offset", {
            min = -2000,
            max = 2000,
            step = 1,
            value = barDB.Position.YOffset or 0,
            labelWidth = 55,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb and bdb.Position then
                    bdb.Position.YOffset = val
                end
                ApplyBarSettings()
            end
        })
        row2b:AddWidget(ySlider, 0.5)
        manager:Register(ySlider, "main", "bar")
        card2:AddRow(row2b, Theme.rowHeight)

        yOffset = card2:GetNextOffset()

        -- Card 3: Mouseover
        local card3 = GUIFrame:CreateCard(scrollChild, "Mouseover", yOffset)
        table_insert(activeCards, card3)
        manager:Register(card3, "main", "bar")

        barDB.Mouseover = barDB.Mouseover or {}

        manager:SetCondition("barMouseoverGlobal", function() return not barDB.Mouseover.GlobalOverride ~= false end)
        manager:SetCondition("barMouseoverPerBar", function() return barDB.Mouseover.Enabled ~= false end)

        local row3a = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
        local useGlobalMouseoverCheck = GUIFrame:CreateCheckbox(row3a, "Use Global Mouseover Settings", {
            value = barDB.Mouseover.GlobalOverride == true,
            callback = function(checked)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.Mouseover = bdb.Mouseover or {}
                    bdb.Mouseover.GlobalOverride = checked
                end
                ApplyBarSettings()
                RenderContent()
            end
        })
        row3a:AddWidget(useGlobalMouseoverCheck, 0.5)
        manager:Register(useGlobalMouseoverCheck, "main", "bar")

        local barMouseoverCheck = GUIFrame:CreateCheckbox(row3a, "Enable Mouseover", {
            value = barDB.Mouseover.Enabled == true,
            callback = function(checked)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.Mouseover = bdb.Mouseover or {}
                    bdb.Mouseover.Enabled = checked
                end
                ApplyBarSettings()
                RenderContent()
            end
        })
        row3a:AddWidget(barMouseoverCheck, 0.5)
        manager:Register(barMouseoverCheck, "main", "bar", "barMouseoverGlobal")
        card3:AddRow(row3a, Theme.rowHeight)

        local row3sep = GUIFrame:CreateRow(card3.content, Theme.rowHeightSeparator)
        row3sep:AddWidget(GUIFrame:CreateSeparator(row3sep), 1)
        card3:AddRow(row3sep, Theme.rowHeightSeparator)

        local row3b = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
        local barAlpha = GUIFrame:CreateSlider(row3b, "Fade Out Alpha", {
            min = 0,
            max = 1,
            step = 0.05,
            value = barDB.Mouseover.Alpha,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.Mouseover = bdb.Mouseover or {}
                    bdb.Mouseover.Alpha = val
                end
                ApplyBarSettings()
            end
        })
        row3b:AddWidget(barAlpha, 1)
        manager:Register(barAlpha, "main", "bar", "barMouseoverGlobal", "barMouseoverPerBar")
        card3:AddRow(row3b, Theme.rowHeightLast, 0)

        yOffset = card3:GetNextOffset()

        return yOffset
    end

    local function RenderBarTextsTab(scrollChild, yOffset)
        local curEdit = GetCurrentBarKey()
        local barDB = GetCurrentBarDB()
        if not curEdit or not barDB then return yOffset end

        barDB.FontSizes = barDB.FontSizes or {}
        barDB.TextPositions = barDB.TextPositions or {}

        manager:SetCondition("barTextGlobal", function() return not barDB.FontSizes.GlobalOverride ~= false end)
        manager:SetCondition("barPosGlobal", function() return not barDB.TextPositions.GlobalOverride ~= false end)

        -- Card 2: Font Sizes
        local card2 = GUIFrame:CreateCard(scrollChild, "Font Sizes", yOffset)
        table_insert(activeCards, card2)
        manager:Register(card2, "main", "bar")

        local row1a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
        local useGlobalFontCheck = GUIFrame:CreateCheckbox(row1a, "Use Global Font Sizes", {
            value = barDB.FontSizes.GlobalOverride == true,
            callback = function(checked)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.FontSizes = bdb.FontSizes or {}
                    bdb.FontSizes.GlobalOverride = checked
                end
                ApplyBarSettings()
                RenderContent()
            end
        })
        row1a:AddWidget(useGlobalFontCheck, 1)
        manager:Register(useGlobalFontCheck, "main", "bar")
        card2:AddRow(row1a, Theme.rowHeight)

        local sepRow1a = GUIFrame:CreateSeparator(card2.content)
        card2:AddRow(sepRow1a, Theme.rowHeightSeparator)

        local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
        local barKeybindSize = GUIFrame:CreateSlider(row2a, "Keybind Size", {
            min = 6,
            max = 24,
            step = 1,
            value = barDB.FontSizes.KeybindSize,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.FontSizes = bdb.FontSizes or {}
                    bdb.FontSizes.KeybindSize = val
                end
                ApplyBarSettings()
            end
        })
        row2a:AddWidget(barKeybindSize, 0.5)
        manager:Register(barKeybindSize, "main", "bar", "barTextGlobal")

        local barCooldownSize = GUIFrame:CreateSlider(row2a, "Cooldown Size", {
            min = 6,
            max = 24,
            step = 1,
            value = barDB.FontSizes.CooldownSize,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.FontSizes = bdb.FontSizes or {}
                    bdb.FontSizes.CooldownSize = val
                end
                ApplyBarSettings()
            end
        })
        row2a:AddWidget(barCooldownSize, 0.5)
        manager:Register(barCooldownSize, "main", "bar", "barTextGlobal")
        card2:AddRow(row2a, Theme.rowHeight)

        local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
        local barChargeSize = GUIFrame:CreateSlider(row2b, "Charge Size", {
            min = 6,
            max = 24,
            step = 1,
            value = barDB.FontSizes.ChargeSize,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.FontSizes = bdb.FontSizes or {}
                    bdb.FontSizes.ChargeSize = val
                end
                ApplyBarSettings()
            end
        })
        row2b:AddWidget(barChargeSize, 0.5)
        manager:Register(barChargeSize, "main", "bar", "barTextGlobal")

        local barMacroSize = GUIFrame:CreateSlider(row2b, "Macro Size", {
            min = 6,
            max = 24,
            step = 1,
            value = barDB.FontSizes.MacroSize,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.FontSizes = bdb.FontSizes or {}
                    bdb.FontSizes.MacroSize = val
                end
                ApplyBarSettings()
            end
        })
        row2b:AddWidget(barMacroSize, 0.5)
        manager:Register(barMacroSize, "main", "bar", "barTextGlobal")
        card2:AddRow(row2b, Theme.rowHeightLast, 0)

        yOffset = card2:GetNextOffset()

        -- Card 3: Text Positions
        local card3 = GUIFrame:CreateCard(scrollChild, "Text Positions", yOffset)
        table_insert(activeCards, card3)
        manager:Register(card3, "main", "bar")

        local row1ab = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
        local useGlobalPosCheck = GUIFrame:CreateCheckbox(row1ab, "Use Global Text Positions", {
            value = barDB.TextPositions.GlobalOverride == true,
            callback = function(checked)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.TextPositions = bdb.TextPositions or {}
                    bdb.TextPositions.GlobalOverride = checked
                end
                ApplyBarSettings()
                RenderContent()
            end
        })
        row1ab:AddWidget(useGlobalPosCheck, 1)
        manager:Register(useGlobalPosCheck, "main", "bar")
        card3:AddRow(row1ab, Theme.rowHeight)

        local sepRow1ab = GUIFrame:CreateSeparator(card3.content)
        card3:AddRow(sepRow1ab, Theme.rowHeightSeparator)

        local tp = barDB.TextPositions

        local row3a = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
        local keybindAnchor = GUIFrame:CreateDropdown(row3a, "Keybind Anchor", {
            options = ANCHOR_OPTIONS,
            value = tp.KeybindAnchor,
            labelWidth = 80,
            callback = function(key)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.TextPositions = bdb.TextPositions or {}
                    bdb.TextPositions.KeybindAnchor = key
                end
                ApplyBarSettings()
            end
        })
        row3a:AddWidget(keybindAnchor, 0.34)
        manager:Register(keybindAnchor, "main", "bar", "barPosGlobal")

        local keybindX = GUIFrame:CreateSlider(row3a, "X", {
            min = -20,
            max = 20,
            step = 1,
            value = tp.KeybindXOffset,
            labelWidth = 30,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.TextPositions = bdb.TextPositions or {}
                    bdb.TextPositions.KeybindXOffset = val
                end
                ApplyBarSettings()
            end
        })
        row3a:AddWidget(keybindX, 0.33)
        manager:Register(keybindX, "main", "bar", "barPosGlobal")

        local keybindY = GUIFrame:CreateSlider(row3a, "Y", {
            min = -20,
            max = 20,
            step = 1,
            value = tp.KeybindYOffset,
            labelWidth = 30,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.TextPositions = bdb.TextPositions or {}
                    bdb.TextPositions.KeybindYOffset = val
                end
                ApplyBarSettings()
            end
        })
        row3a:AddWidget(keybindY, 0.33)
        manager:Register(keybindY, "main", "bar", "barPosGlobal")
        card3:AddRow(row3a, Theme.rowHeight)

        local row3sep1 = GUIFrame:CreateRow(card3.content, Theme.rowHeightSeparator)
        row3sep1:AddWidget(GUIFrame:CreateSeparator(row3sep1), 1)
        card3:AddRow(row3sep1, Theme.rowHeightSeparator)

        local row3b = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
        local chargeAnchor = GUIFrame:CreateDropdown(row3b, "Charge Anchor", {
            options = ANCHOR_OPTIONS,
            value = tp.ChargeAnchor,
            labelWidth = 80,
            callback = function(key)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.TextPositions = bdb.TextPositions or {}
                    bdb.TextPositions.ChargeAnchor = key
                end
                ApplyBarSettings()
            end
        })
        row3b:AddWidget(chargeAnchor, 0.34)
        manager:Register(chargeAnchor, "main", "bar", "barPosGlobal")

        local chargeX = GUIFrame:CreateSlider(row3b, "X", {
            min = -20,
            max = 20,
            step = 1,
            value = tp.ChargeXOffset,
            labelWidth = 30,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.TextPositions = bdb.TextPositions or {}
                    bdb.TextPositions.ChargeXOffset = val
                end
                ApplyBarSettings()
            end
        })
        row3b:AddWidget(chargeX, 0.33)
        manager:Register(chargeX, "main", "bar", "barPosGlobal")

        local chargeY = GUIFrame:CreateSlider(row3b, "Y", {
            min = -20,
            max = 20,
            step = 1,
            value = tp.ChargeYOffset,
            labelWidth = 30,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.TextPositions = bdb.TextPositions or {}
                    bdb.TextPositions.ChargeYOffset = val
                end
                ApplyBarSettings()
            end
        })
        row3b:AddWidget(chargeY, 0.33)
        manager:Register(chargeY, "main", "bar", "barPosGlobal")
        card3:AddRow(row3b, Theme.rowHeight)

        local row3sep2 = GUIFrame:CreateRow(card3.content, Theme.rowHeightSeparator)
        row3sep2:AddWidget(GUIFrame:CreateSeparator(row3sep2), 1)
        card3:AddRow(row3sep2, Theme.rowHeightSeparator)

        local row3c = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
        local macroAnchor = GUIFrame:CreateDropdown(row3c, "Macro Anchor", {
            options = ANCHOR_OPTIONS,
            value = tp.MacroAnchor,
            labelWidth = 80,
            callback = function(key)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.TextPositions = bdb.TextPositions or {}
                    bdb.TextPositions.MacroAnchor = key
                end
                ApplyBarSettings()
            end
        })
        row3c:AddWidget(macroAnchor, 0.34)
        manager:Register(macroAnchor, "main", "bar", "barPosGlobal")

        local macroX = GUIFrame:CreateSlider(row3c, "X", {
            min = -20,
            max = 20,
            step = 1,
            value = tp.MacroXOffset,
            labelWidth = 30,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.TextPositions = bdb.TextPositions or {}
                    bdb.TextPositions.MacroXOffset = val
                end
                ApplyBarSettings()
            end
        })
        row3c:AddWidget(macroX, 0.33)
        manager:Register(macroX, "main", "bar", "barPosGlobal")

        local macroY = GUIFrame:CreateSlider(row3c, "Y", {
            min = -20,
            max = 20,
            step = 1,
            value = tp.MacroYOffset,
            labelWidth = 30,
            callback = function(val)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.TextPositions = bdb.TextPositions or {}
                    bdb.TextPositions.MacroYOffset = val
                end
                ApplyBarSettings()
            end
        })
        row3c:AddWidget(macroY, 0.33)
        manager:Register(macroY, "main", "bar", "barPosGlobal")
        card3:AddRow(row3c, Theme.rowHeight)

        yOffset = card3:GetNextOffset()

        -- Card 4: Text Visibility
        local card4 = GUIFrame:CreateCard(scrollChild, "Text Visibility", yOffset)
        table_insert(activeCards, card4)
        manager:Register(card4, "main", "bar")

        barDB.TextVisibility = barDB.TextVisibility or {}

        manager:SetCondition("barVisGlobal", function() return not barDB.TextVisibility.GlobalOverride ~= false end)

        local row4a = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
        local useGlobalVisCheck = GUIFrame:CreateCheckbox(row4a, "Use Global Text Visibility", {
            value = barDB.TextVisibility.GlobalOverride == true,
            callback = function(checked)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.TextVisibility = bdb.TextVisibility or {}
                    bdb.TextVisibility.GlobalOverride = checked
                end
                ApplyBarSettings()
                RenderContent()
            end
        })
        row4a:AddWidget(useGlobalVisCheck, 1)
        manager:Register(useGlobalVisCheck, "main", "bar")
        card4:AddRow(row4a, Theme.rowHeight)

        local sepRow4 = GUIFrame:CreateSeparator(card4.content)
        card4:AddRow(sepRow4, Theme.rowHeightSeparator)

        local row4b = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
        local hideKeybindCheck = GUIFrame:CreateCheckbox(row4b, "Hide Keybind Text", {
            value = barDB.TextVisibility.HideKeybindText == true,
            callback = function(checked)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.TextVisibility = bdb.TextVisibility or {}
                    bdb.TextVisibility.HideKeybindText = checked
                end
                ApplyBarSettings()
            end
        })
        row4b:AddWidget(hideKeybindCheck, 0.5)
        manager:Register(hideKeybindCheck, "main", "bar", "barVisGlobal")

        local hideMacroCheck = GUIFrame:CreateCheckbox(row4b, "Hide Macro Text", {
            value = barDB.TextVisibility.HideMacroText == true,
            callback = function(checked)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.TextVisibility = bdb.TextVisibility or {}
                    bdb.TextVisibility.HideMacroText = checked
                end
                ApplyBarSettings()
            end
        })
        row4b:AddWidget(hideMacroCheck, 0.5)
        manager:Register(hideMacroCheck, "main", "bar", "barVisGlobal")
        card4:AddRow(row4b, Theme.rowHeight)

        local row4c = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
        local hideChargeCheck = GUIFrame:CreateCheckbox(row4c, "Hide Charge Text", {
            value = barDB.TextVisibility.HideChargeText == true,
            callback = function(checked)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.TextVisibility = bdb.TextVisibility or {}
                    bdb.TextVisibility.HideChargeText = checked
                end
                ApplyBarSettings()
            end
        })
        row4c:AddWidget(hideChargeCheck, 0.5)
        manager:Register(hideChargeCheck, "main", "bar", "barVisGlobal")

        local hideProfCheck = GUIFrame:CreateCheckbox(row4c, "Hide Profession Texture", {
            value = barDB.TextVisibility.HideProfTexture == true,
            callback = function(checked)
                local bdb = GetCurrentBarDB()
                if bdb then
                    bdb.TextVisibility = bdb.TextVisibility or {}
                    bdb.TextVisibility.HideProfTexture = checked
                end
                ApplyProfTextures()
            end
        })
        row4c:AddWidget(hideProfCheck, 0.5)
        manager:Register(hideProfCheck, "main", "bar", "barVisGlobal")
        card4:AddRow(row4c, Theme.rowHeight)

        yOffset = card4:GetNextOffset()

        return yOffset
    end

    local function RenderBarBackdropTab(scrollChild, yOffset)
        local curEdit = GetCurrentBarKey()
        local barDB = GetCurrentBarDB()
        if not curEdit or not barDB then return yOffset end

        -- Card 1: Backdrop
        local card1 = GUIFrame:CreateCard(scrollChild, "Backdrop", yOffset)
        table_insert(activeCards, card1)
        manager:Register(card1, "main", "bar")

        local row1a = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
        local hideEmptyCheck = GUIFrame:CreateCheckbox(row1a, "Hide Empty Backdrops", {
            value = barDB.HideEmptyBackdrops == true,
            callback = function(checked)
                local bdb = GetCurrentBarDB()
                if bdb then bdb.HideEmptyBackdrops = checked end
                ApplyBarSettings()
            end
        })
        row1a:AddWidget(hideEmptyCheck, 1)
        manager:Register(hideEmptyCheck, "main", "bar")
        card1:AddRow(row1a, Theme.rowHeight)

        local row1sep = GUIFrame:CreateRow(card1.content, Theme.rowHeightSeparator)
        row1sep:AddWidget(GUIFrame:CreateSeparator(row1sep), 1)
        card1:AddRow(row1sep, Theme.rowHeightSeparator)

        local row1b = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
        local backdropColor = GUIFrame:CreateColorPicker(row1b, "Backdrop Color", {
            color = barDB.BackdropColor,
            callback = function(r, g, b, a)
                local bdb = GetCurrentBarDB()
                if bdb then bdb.BackdropColor = { r, g, b, a } end
                ApplyBarSettings()
            end
        })
        row1b:AddWidget(backdropColor, 0.5)
        manager:Register(backdropColor, "main", "bar")

        local borderColor = GUIFrame:CreateColorPicker(row1b, "Border Color", {
            color = barDB.BorderColor,
            callback = function(r, g, b, a)
                local bdb = GetCurrentBarDB()
                if bdb then bdb.BorderColor = { r, g, b, a } end
                ApplyBarSettings()
            end
        })
        row1b:AddWidget(borderColor, 0.5)
        manager:Register(borderColor, "main", "bar")
        card1:AddRow(row1b, Theme.rowHeight)

        yOffset = card1:GetNextOffset()

        return yOffset
    end

    RenderContent = function()
        if isTabbed then
            contentArea:ClearContent()
        else
            contentArea.ClearContent()
        end
        manager:Clear()

        manager:SetCondition("bar", function()
            local barDB = GetCurrentBarDB()
            return barDB and barDB.Enabled ~= false
        end)

        local yOffset = Theme.paddingSmall

        if selectedKey == "Global" then
            yOffset = RenderGlobalContent(scrollChild, yOffset)
        else
            if barSubTab == "general" then
                yOffset = RenderBarGeneralTab(scrollChild, yOffset)
            elseif barSubTab == "texts" then
                yOffset = RenderBarTextsTab(scrollChild, yOffset)
            elseif barSubTab == "backdrop" then
                yOffset = RenderBarBackdropTab(scrollChild, yOffset)
            end
        end

        if isTabbed then
            contentArea:SetContentHeight(yOffset)
        else
            contentArea.SetContentHeight(yOffset)
        end
        manager:UpdateAll(db.Enabled ~= false)
    end

    RenderContent()

    return miniSidebar.panel
end)

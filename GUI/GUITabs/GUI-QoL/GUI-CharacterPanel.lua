---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

GUIFrame:RegisterContent("CharacterPanel", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.CharacterPanel
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    ---@type CharacterPanel?
    local CharacterPanel = NRSKNUI:GetModule("CharacterPanel", true)
    local manager = GUIFrame:CreateWidgetStateManager()

    manager:SetCondition("gemUtil", function() return db.GemSocketHelper.Enabled end)
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    -- Card 1: Enable + Recommended
    local card1 = GUIFrame:CreateCard(scrollChild, "Character Panel", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Character Panel Improvements", {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if CharacterPanel then
                if checked then NRSKNUI:EnableModule("CharacterPanel") else NRSKNUI:DisableModule("CharacterPanel") end
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = "Character Panel",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeight)

    local sep1 = GUIFrame:CreateSeparator(card1.content)
    card1:AddRow(sep1, Theme.rowHeightSeparator)

    local recHeight = 130
    local recRow = GUIFrame:CreateRow(card1.content, recHeight)
    local recText = GUIFrame:CreateText(recRow, NRSKNUI:ColorTextByTheme("Recommended"), {
        text = ("BetterCharacterPanel by |cffC41E3AGrim|r" ..
            "\nAdds additional info to the character panel.\n\n" ..
            NRSKNUI:ColorTextByTheme("Features") .. "\n" ..
            NRSKNUI:ColorTextByTheme("• ") .. "Shows ilvl information\n" ..
            NRSKNUI:ColorTextByTheme("• ") .. "Shows enchant information\n" ..
            NRSKNUI:ColorTextByTheme("• ") .. "Shows gem information\n"),
        height = recHeight,
        bgMode = "hide"
    })
    recRow:AddWidget(recText, 0.6)
    manager:Register(recText, "all")

    local recBtn = GUIFrame:CreateButton(recRow, "Get Addon Here", {
        callback = function()
            NRSKNUI:CreateCopyDialog(
                "BetterCharacterPanel by |cffC41E3AGrim|r",
                "https://www.curseforge.com/wow/addons/bettercharacterpanel",
                "Copy to clipboard by pressing CTRL + C"
            )
        end,
        width = 100,
        height = 36,
    })
    recRow:AddWidget(recBtn, 0.4)
    manager:Register(recBtn, "all")
    card1:AddRow(recRow, recHeight, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: Display Options
    local card2 = GUIFrame:CreateCard(scrollChild, "Display Options", yOffset)
    manager:Register(card2, "all")

    local row2 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local decimalCheck = GUIFrame:CreateCheckbox(row2, "Show Decimal Item Level", {
        value = db.DecimalItemLevel,
        callback = function(checked)
            db.DecimalItemLevel = checked
            if CharacterPanel and CharacterPanel.UpdateItemLevelText then
                CharacterPanel:UpdateItemLevelText()
            end
        end,
        tooltip = "Shows your average item level with 2 decimals instead of a rounded value",
    })
    row2:AddWidget(decimalCheck, 1)
    manager:Register(decimalCheck, "all")
    card2:AddRow(row2, Theme.rowHeight)

    local sep2 = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sep2, Theme.rowHeightSeparator)
    manager:Register(sep2, "all")

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local raceTextCheck = GUIFrame:CreateCheckbox(row2b, "Show Race Text", {
        value = db.ShowRaceText,
        callback = function(checked)
            db.ShowRaceText = checked
            if CharacterPanel then
                if checked then
                    CharacterPanel:ShowRaceText()
                else
                    CharacterPanel:HideRaceText()
                end
            end
        end,
        tooltip = "Shows your character's race below the level text on the character panel",
    })
    row2b:AddWidget(raceTextCheck, 1)
    manager:Register(raceTextCheck, "all")
    card2:AddRow(row2b, Theme.rowHeight)

    local sep2b = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sep2b, Theme.rowHeightSeparator)
    manager:Register(sep2b, "all")

    local trackDb = db.TrackIndicators
    local row2c = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local trackEnableCheck = GUIFrame:CreateCheckbox(row2c, "Show Item Track Letters", {
        value = trackDb.Enabled,
        callback = function(checked)
            trackDb.Enabled = checked
            if CharacterPanel then
                if checked then
                    CharacterPanel:UpdateAllTrackIndicators()
                else
                    CharacterPanel:HideAllTrackIndicators()
                end
            end
        end,
        tooltip = "Shows M/H/C/V/A letters on gear slots indicating Myth/Hero/Champion/Veteran/Adventurer tracks",
    })
    row2c:AddWidget(trackEnableCheck, 1)
    manager:Register(trackEnableCheck, "all")
    card2:AddRow(row2c, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Gem Socket Helper
    local gemDb = db.GemSocketHelper
    local card3 = GUIFrame:CreateCard(scrollChild, "Gem Socket Helper", yOffset)
    manager:Register(card3, "all")

    local row3 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local gemEnableCheck = GUIFrame:CreateCheckbox(row3, "Enable Gem Socket Helper", {
        value = gemDb.Enabled,
        callback = function(checked)
            gemDb.Enabled = checked
            if CharacterPanel then
                if checked then
                    CharacterPanel:SetupGemSocketHelper()
                    CharacterPanel:RefreshSocketButtons()
                else
                    CharacterPanel:DisableGemSocketHelper()
                end
            end
            UpdateAllWidgetStates()
        end,
        tooltip = "Shows equipped gem sockets on the character panel with quick gem replacement",
    })
    row3:AddWidget(gemEnableCheck, 1)
    card3:AddRow(row3, Theme.rowHeight)

    local sep3 = GUIFrame:CreateSeparator(card3.content)
    card3:AddRow(sep3, Theme.rowHeightSeparator)

    local row4 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local sizeSlider = GUIFrame:CreateSlider(row4, "Socket Button Size", {
        min = 16,
        max = 48,
        step = 1,
        value = gemDb.SocketButtonSize,
        callback = function(val)
            gemDb.SocketButtonSize = val
            if CharacterPanel and CharacterPanel.RefreshSocketButtons then
                CharacterPanel:RefreshSocketButtons()
            end
        end,
    })
    row4:AddWidget(sizeSlider, 0.5)
    manager:Register(sizeSlider, "all", "gemUtil")

    local spacingSlider = GUIFrame:CreateSlider(row4, "Button Spacing", {
        min = 0,
        max = 10,
        step = 1,
        value = gemDb.SocketButtonSpacing,
        callback = function(val)
            gemDb.SocketButtonSpacing = val
            if CharacterPanel and CharacterPanel.RefreshSocketButtons then
                CharacterPanel:RefreshSocketButtons()
            end
        end,
    })
    row4:AddWidget(spacingSlider, 0.5)
    manager:Register(spacingSlider, "all", "gemUtil")
    card3:AddRow(row4, Theme.rowHeight)

    local row5 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
    local emptyOnlyCheck = GUIFrame:CreateCheckbox(row5, "Show Only Empty Sockets", {
        value = gemDb.ShowOnlyEmpty,
        callback = function(checked)
            gemDb.ShowOnlyEmpty = checked
            if CharacterPanel and CharacterPanel.RefreshSocketButtons then
                CharacterPanel:RefreshSocketButtons()
            end
        end,
        tooltip = "Only show sockets that don't have a gem equipped",
    })
    row5:AddWidget(emptyOnlyCheck, 1)
    manager:Register(emptyOnlyCheck, "all", "gemUtil")
    card3:AddRow(row5, Theme.rowHeight)

    local row6 = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local enchantCheck = GUIFrame:CreateCheckbox(row6, "Show Enchant Helper Button", {
        value = gemDb.EnchantHelper,
        callback = function(checked)
            gemDb.EnchantHelper = checked
            if CharacterPanel and CharacterPanel.RefreshSocketButtons then
                CharacterPanel:RefreshSocketButtons()
            end
        end,
        tooltip = "Adds a button to quickly apply enchants from your bags to equipped items",
    })
    row6:AddWidget(enchantCheck, 1)
    manager:Register(enchantCheck, "all", "gemUtil")
    card3:AddRow(row6, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card 4: Font Settings
    local fontCard, fontYOffset, fontWidgets = GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, {
        title = "Font Settings",
        db = db,
        dbKeys = {
            fontFace = "FontFace",
            fontOutline = "FontOutline",
        },
        fontSizes = {
            { label = "Stats Size",      dbKey = "StatsFontSize" },
            { label = "Level Text Size", dbKey = "LevelTextSize" },
            { label = "Name Text Size",  dbKey = "NameTextSize" },
            { label = "Category Size",   dbKey = "CategoryFontSize" },
            { label = "Ilvl Value Size", dbKey = "IlvlValueSize" },
        },
        fontSizeRange = { 8, 24 },
        includeSoftOutline = true,
        onChangeCallback = function()
            if CharacterPanel then
                CharacterPanel:ApplySettings()
            end
        end,
        globalOverride = {},
    })
    manager:Register(fontCard, "all")
    for _, widget in ipairs(fontWidgets) do
        manager:Register(widget, "all")
    end
    yOffset = fontYOffset

    UpdateAllWidgetStates()

    return yOffset
end)

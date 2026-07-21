---@class NRSKNUI
local NRSKNUI = select(2, ...)

local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

local pairs = pairs
local ipairs = ipairs
local table_insert = table.insert

local SIDEBAR_WIDTH = 192
local ITEM_HEIGHT = 34
local LIST_PADDING = 4

local selectedItem = "Global"

local GLOBAL_SENTINEL = "__GLOBAL"

local ANCHOR_POINTS = {
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

-- Per-special GUI metadata, the entries themselves live in NRSKNUI.SpecialFonts
local SPECIAL_META = {
    ZoneText     = { sizeRange = { 8, 100 }, position = true, hide = "Hide Zone Texts", preview = "PreviewZone" },
    SubZoneText  = { sizeRange = { 8, 100 }, preview = "PreviewZone" },
    PvPZoneText  = { sizeRange = { 8, 100 }, preview = "PreviewZone" },
    ErrorText    = { sizeRange = { 8, 24 }, position = true, hide = "Hide Error Messages", preview = "PreviewUIErrors" },
    ActionStatus = { sizeRange = { 8, 24 }, position = true, hide = "Hide Action Status", preview = "PreviewActionStatus" },
    ChatBubbles  = { sizeRange = { 6, 18 } },
    Nameplates   = { note = "Applies to nameplate names and castbar text. Sizes stay native." },
    CombatText   = { note = "Scrolling combat text (requires the Blizzard combat text feature)." },
    CombatFont   = { note = "Floating damage text. Requires a relog to fully apply or revert.", noOutline = true },
    NameFont     = { note = "Unit names in the world. Requires a relog to fully apply or revert.", noOutline = true },
}

GUIFrame:RegisterPanel("global_fonts", function(container)
    local media = NRSKNUI.db and NRSKNUI.db.profile.globalMedia
    if not media then return nil end

    local fontDB = media.profileFont
    local blizzDB = media.blizzardFonts
    local specials = blizzDB.Specials

    local mod = NRSKNUI:GetModule("BlizzardMessages", true)
    local function RefreshContent() C_Timer.After(0.05, function() GUIFrame:RefreshContent() end) end
    local manager = GUIFrame:CreateWidgetStateManager()
    local function UpdateAllWidgetStates() manager:UpdateAll(media.Enabled) end

    local function GetSidebarItems()
        local items = {}
        for order, entry in ipairs(NRSKNUI.SpecialFonts) do
            table_insert(items, {
                key = entry.key,
                name = entry.label,
                order = order,
            })
        end
        return items
    end

    local miniSidebar = NRSKNUI.GUI.CreateMiniSidebar(container, {
        sidebarWidth = SIDEBAR_WIDTH,
        listPadding = LIST_PADDING,
        itemHeight = ITEM_HEIGHT,

        getItems = GetSidebarItems,
        getItemKey = function(item) return item.key end,

        renderItem = function(btn, item, isSelected)
            btn._icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
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
                    text = "Global Settings",
                    onClick = function()
                        selectedItem = "Global"
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

    if selectedItem == "Global" then
        manager:SetCondition("globFontON", function() return fontDB.Enabled end)
        manager:SetCondition("blizzFontsON", function() return blizzDB.Enabled end)

        -- Card 1: Global Font
        local GlobalFontCard = GUIFrame:CreateCard(contentChild, "Global Font", yOffset)
        miniSidebar.contentArea.RegisterCard(GlobalFontCard)

        local row1 = GUIFrame:CreateRow(GlobalFontCard.content, Theme.rowHeightLast)
        local globalFontToggle = GUIFrame:CreateCheckbox(row1, "Use Global Font", {
            value = fontDB.Enabled,
            callback = function(checked)
                fontDB.Enabled = checked
                UpdateAllWidgetStates()
                NRSKNUI:ApplyToAllModules()
                NRSKNUI:RefreshFontStyles()
            end,
            msgPopup = true,
            msgText = "Global Font",
        })
        row1:AddWidget(globalFontToggle, 0.5)

        local fontList = {}
        if LSM then
            for name in pairs(LSM:HashTable("font")) do
                fontList[name] = name
            end
        end

        local fontDropdown = GUIFrame:CreateDropdown(row1, "Font", {
            options = fontList,
            value = fontDB.FontFace,
            callback = function(key)
                fontDB.FontFace = key
                NRSKNUI:ApplyToAllModules()
                NRSKNUI:RefreshFontStyles()
                NRSKNUI:ApplyBlizzardFonts()
            end,
            searchable = true,
            isFontPreview = true
        })
        row1:AddWidget(fontDropdown, 0.5)
        manager:Register(fontDropdown, "all", "globFontON")
        GlobalFontCard:AddRow(row1, Theme.rowHeightLast, 0)

        yOffset = GlobalFontCard:GetNextOffset()

        -- Card 2: Blizzard UI Font
        local BlizzardFontCard = GUIFrame:CreateCard(contentChild, "Blizzard UI Font", yOffset)
        miniSidebar.contentArea.RegisterCard(BlizzardFontCard)

        local bRow1 = GUIFrame:CreateRow(BlizzardFontCard.content, Theme.rowHeight)
        local blizzToggle = GUIFrame:CreateCheckbox(bRow1, "Style Blizzard Fonts", {
            value = blizzDB.Enabled,
            callback = function(checked)
                blizzDB.Enabled = checked
                UpdateAllWidgetStates()
                NRSKNUI:ApplyBlizzardFonts(true)
            end,
            msgPopup = true,
            msgText = "Blizzard UI Font",
            tooltip =
            "Apply your global font face across Blizzard's UI, adding an outline where it reads cleanly. Big display text and unsafe fonts keep their native outline.",
        })
        bRow1:AddWidget(blizzToggle, 0.5)

        local outlineOptions = {}
        for _, option in ipairs(NRSKNUI.FontOutlines) do
            local value = option.value
            if type(value) == "table" then value = value[1] end
            if not value:find("SLUG") then
                table_insert(outlineOptions, { key = value, text = option.label })
            end
        end

        local blizzOutline = GUIFrame:CreateDropdown(bRow1, "Outline", {
            options = outlineOptions,
            value = blizzDB.Outline,
            callback = function(key)
                blizzDB.Outline = key
                NRSKNUI:ApplyBlizzardFonts()
            end,
        })
        bRow1:AddWidget(blizzOutline, 0.5)
        manager:Register(blizzOutline, "all", "blizzFontsON")
        BlizzardFontCard:AddRow(bRow1, Theme.rowHeight)

        local bRowSlug = GUIFrame:CreateRow(BlizzardFontCard.content, Theme.rowHeight)
        local blizzSlug = GUIFrame:CreateCheckbox(bRowSlug, "Use Slug Rendering", {
            value = blizzDB.Slug,
            callback = function(checked)
                blizzDB.Slug = checked
                NRSKNUI:ApplyBlizzardFonts()
            end,
            tooltip = "Higher-quality glyph rendering on supported fonts, combined with the outline above where enabled.",
        })
        bRowSlug:AddWidget(blizzSlug, 0.5)
        manager:Register(blizzSlug, "all", "blizzFontsON")

        local blizzHideShadow = GUIFrame:CreateCheckbox(bRowSlug, "Hide Shadows", {
            value = blizzDB.HideShadow,
            callback = function(checked)
                blizzDB.HideShadow = checked
                NRSKNUI:ApplyBlizzardFonts()
            end,
            tooltip = "Remove the drop shadow from styled fonts for a flatter look. Native shadows return when unchecked.",
        })
        bRowSlug:AddWidget(blizzHideShadow, 0.5)
        manager:Register(blizzHideShadow, "all", "blizzFontsON")
        BlizzardFontCard:AddRow(bRowSlug, Theme.rowHeight)

        local function AddFamilySlider(row, famKey, label)
            local slider = GUIFrame:CreateSlider(row, label, {
                min = -8,
                max = 8,
                step = 1,
                value = blizzDB.Families[famKey] or 0,
                callback = function(val)
                    blizzDB.Families[famKey] = val
                    NRSKNUI:ApplyBlizzardFonts(true)
                end,
            })
            row:AddWidget(slider, 0.5)
            manager:Register(slider, "all", "blizzFontsON")
        end

        local bRow2 = GUIFrame:CreateRow(BlizzardFontCard.content, Theme.rowHeight)
        AddFamilySlider(bRow2, "small", "Small Size")
        AddFamilySlider(bRow2, "medium", "Medium Size")
        BlizzardFontCard:AddRow(bRow2, Theme.rowHeight)

        local bRow3 = GUIFrame:CreateRow(BlizzardFontCard.content, Theme.rowHeightLast)
        AddFamilySlider(bRow3, "large", "Large Size")
        AddFamilySlider(bRow3, "huge", "Huge Size")
        BlizzardFontCard:AddRow(bRow3, Theme.rowHeightLast, 0)

        yOffset = BlizzardFontCard:GetNextOffset()
        UpdateAllWidgetStates()
    else
        local entry
        for _, e in ipairs(NRSKNUI.SpecialFonts) do
            if e.key == selectedItem then
                entry = e
                break
            end
        end

        if entry then
            local meta = SPECIAL_META[entry.key] or {}
            local sdb = specials[entry.key]

            local function Apply()
                NRSKNUI:ApplySpecialFonts()
                if (meta.position or meta.hide) and mod then
                    mod:ApplySettings()
                end
            end

            manager:SetCondition("spEnabled", function() return sdb.Enabled end)

            -- Card 1: font settings
            local card1 = GUIFrame:CreateCard(contentChild, entry.label, yOffset)
            miniSidebar.contentArea.RegisterCard(card1)

            local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
            local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable", {
                value = sdb.Enabled,
                callback = function(checked)
                    sdb.Enabled = checked
                    Apply()
                    UpdateAllWidgetStates()
                end,
                msgPopup = true,
                msgText = entry.label .. " Font",
            })
            row1:AddWidget(enableCheck, meta.preview and (2 / 3) or 1)

            if meta.preview then
                local previewBtn = GUIFrame:CreateButton(row1, "Preview", {
                    callback = function()
                        if mod and mod[meta.preview] then mod[meta.preview](mod) end
                    end,
                    height = 30,
                })
                row1:AddWidget(previewBtn, (1 / 3), nil, 0, -6)
                manager:Register(previewBtn, "all", "spEnabled")
            end
            card1:AddRow(row1, Theme.rowHeight)

            local sep1 = GUIFrame:CreateSeparator(card1.content)
            card1:AddRow(sep1, Theme.rowHeightSeparator)
            manager:Register(sep1, "all", "spEnabled")

            -- Font face: nil in the db means "use the global font".
            local row2 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
            local fontDropdownRef

            local customFontCheck = GUIFrame:CreateCheckbox(row2, "Custom Font", {
                value = sdb.FontFace ~= nil,
                callback = function(checked)
                    if checked then
                        sdb.FontFace = fontDB.FontFace
                    else
                        sdb.FontFace = nil
                    end
                    if fontDropdownRef and fontDropdownRef.SetEnabled then
                        fontDropdownRef:SetEnabled(checked)
                    end
                    Apply()
                end,
                tooltip = "Override the global font for this element only.",
            })
            row2:AddWidget(customFontCheck, 0.5)
            manager:Register(customFontCheck, "all", "spEnabled")

            local fontList = {}
            if LSM then
                for name in pairs(LSM:HashTable("font")) do
                    fontList[name] = name
                end
            end

            local fontDropdown = GUIFrame:CreateDropdown(row2, "Font", {
                options = fontList,
                value = sdb.FontFace or fontDB.FontFace,
                callback = function(key)
                    sdb.FontFace = key
                    Apply()
                end,
                searchable = true,
                isFontPreview = true,
            })
            row2:AddWidget(fontDropdown, 0.5)
            manager:Register(fontDropdown, "all", "spEnabled")
            fontDropdownRef = fontDropdown
            if fontDropdown.SetEnabled then
                fontDropdown:SetEnabled(sdb.FontFace ~= nil)
            end
            card1:AddRow(row2, Theme.rowHeight)

            -- Outline: nil in the db means "use the global outline".
            if not meta.noOutline then
                local row3 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)

                local outlineOptions = { { key = GLOBAL_SENTINEL, text = "Global" } }
                for _, option in ipairs(NRSKNUI.FontOutlines) do
                    local value = option.value
                    if type(value) == "table" then value = value[1] end
                    table_insert(outlineOptions, { key = value, text = option.label })
                end

                local outlineDropdown = GUIFrame:CreateDropdown(row3, "Outline", {
                    options = outlineOptions,
                    value = sdb.Outline or GLOBAL_SENTINEL,
                    callback = function(key)
                        sdb.Outline = key ~= GLOBAL_SENTINEL and key or nil
                        Apply()
                    end,
                })
                row3:AddWidget(outlineDropdown, meta.sizeRange and 0.5 or 1)
                manager:Register(outlineDropdown, "all", "spEnabled")

                if meta.sizeRange then
                    local sizeSlider = GUIFrame:CreateSlider(row3, "Font Size", {
                        min = meta.sizeRange[1],
                        max = meta.sizeRange[2],
                        step = 1,
                        value = sdb.Size,
                        callback = function(val)
                            sdb.Size = val
                            Apply()
                        end,
                    })
                    row3:AddWidget(sizeSlider, 0.5)
                    manager:Register(sizeSlider, "all", "spEnabled")
                end
                card1:AddRow(row3, Theme.rowHeight)
            end

            if meta.hide then
                local rowHide = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
                local hideCheck = GUIFrame:CreateCheckbox(rowHide, meta.hide, {
                    value = sdb.Hide,
                    callback = function(checked)
                        sdb.Hide = checked
                        Apply()
                        UpdateAllWidgetStates()
                    end,
                })
                rowHide:AddWidget(hideCheck, 1)
                manager:Register(hideCheck, "all", "spEnabled")
                card1:AddRow(rowHide, Theme.rowHeight)
            end

            if meta.note then
                local noteHeight = 40
                local rowNote = GUIFrame:CreateRow(card1.content, noteHeight)
                local noteText = GUIFrame:CreateText(rowNote, "", {
                    text = meta.note,
                    height = noteHeight,
                    bgMode = "hide",
                })
                rowNote:AddWidget(noteText, 1)
                card1:AddRow(rowNote, noteHeight, 0)
            else
                -- Rows above used rowHeight; close the card cleanly.
                local rowPad = GUIFrame:CreateRow(card1.content, Theme.rowHeightSeparator)
                card1:AddRow(rowPad, Theme.rowHeightSeparator, 0)
            end

            yOffset = card1:GetNextOffset()

            -- Card 2: Position (BlizzardMessages-backed elements)
            if meta.position then
                local card2 = GUIFrame:CreateCard(contentChild, "Position", yOffset)
                miniSidebar.contentArea.RegisterCard(card2)
                manager:Register(card2, "all", "spEnabled")

                local row4 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
                local anchorDropdown = GUIFrame:CreateDropdown(row4, "Anchor", {
                    options = ANCHOR_POINTS,
                    value = sdb.Position.Anchor,
                    labelWidth = 50,
                    callback = function(key)
                        sdb.Position.Anchor = key
                        Apply()
                    end,
                })
                row4:AddWidget(anchorDropdown, 1)
                manager:Register(anchorDropdown, "all", "spEnabled")
                card2:AddRow(row4, Theme.rowHeight)

                local sep2 = GUIFrame:CreateSeparator(card2.content)
                card2:AddRow(sep2, Theme.rowHeightSeparator)
                manager:Register(sep2, "all", "spEnabled")

                local row5 = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
                local xSlider = GUIFrame:CreateSlider(row5, "X Offset", {
                    min = -500,
                    max = 500,
                    step = 1,
                    value = sdb.Position.X,
                    labelWidth = 50,
                    callback = function(val)
                        sdb.Position.X = val
                        Apply()
                    end,
                })
                row5:AddWidget(xSlider, 0.5)
                manager:Register(xSlider, "all", "spEnabled")

                local ySlider = GUIFrame:CreateSlider(row5, "Y Offset", {
                    min = -500,
                    max = 500,
                    step = 1,
                    value = sdb.Position.Y,
                    labelWidth = 50,
                    callback = function(val)
                        sdb.Position.Y = val
                        Apply()
                    end,
                })
                row5:AddWidget(ySlider, 0.5)
                manager:Register(ySlider, "all", "spEnabled")
                card2:AddRow(row5, Theme.rowHeightLast, 0)

                yOffset = card2:GetNextOffset()
            end

            UpdateAllWidgetStates()
        end
    end

    miniSidebar.contentArea.SetContentHeight(yOffset)
    C_Timer.After(0, function()
        miniSidebar.contentArea.UpdateScrollBarVisibility()
        miniSidebar.contentArea.UpdateCardWidths()
    end)

    return miniSidebar.panel
end)

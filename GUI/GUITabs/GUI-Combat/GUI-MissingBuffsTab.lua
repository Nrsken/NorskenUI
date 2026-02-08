-- NorskenUI namespace
local _, NRSKNUI = ...

-- Locals
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.LSM

-- Localization Setup
local table_insert = table.insert
local table_sort = table.sort
local wipe = wipe
local CreateFrame = CreateFrame
local ipairs, pairs = ipairs, pairs
local type = type

-- Store current sub-tab
local currentSubTab = "raidBuffs"

-- Cached tab bar reference
local cachedTabBar = nil
local cachedTabButtons = nil

local allWidgets = {}

-- Sub-tab definitions
local SUB_TABS = {
    { id = "raidBuffs",   text = "Raid & General Buffs" },
    { id = "stances",     text = "Stance & Spec Buffs" },
    { id = "stanceTexts", text = "Stance Texts" },
}

-- Tab bar height constant
local TAB_BAR_HEIGHT = 28

-- Get module reference
local function GetModule()
    return NRSKNUI.Addon:GetModule("MissingBuffs", true)
end

-- Load database settings
local function GetMissingBuffsDB()
    if not NRSKNUI.db or not NRSKNUI.db.profile then return nil end
    return NRSKNUI.db.profile.MissingBuffs
end

-- Helper to apply settings
local function ApplySettings()
    local mod = GetModule()
    if mod and mod.ApplySettings then
        mod:ApplySettings()
    end
end

-- Helper to refresh module
local function Refresh()
    local mod = GetModule()
    if mod and mod.Refresh then
        mod:Refresh()
    end
end

-- Comprehensive widget state update
local function UpdateAllWidgetStates()
    local db = GetMissingBuffsDB()
    if not db then return end
    local mainEnabled = db.Enabled ~= false

    -- Apply main enable state to ALL widgets
    for _, widget in ipairs(allWidgets) do
        if widget.SetEnabled then
            widget:SetEnabled(mainEnabled)
        end
    end
end

-- Register cleanup callback once
if not GUIFrame._missingBuffsCleanupRegistered then
    GUIFrame._missingBuffsCleanupRegistered = true

    -- Register callback for when GUI closes
    GUIFrame:RegisterOnCloseCallback("missingBuffs", function()
        Refresh()
    end)
end

-- Category icons
local CATEGORY_ICONS = {
    Flask = 1235110,    -- Alchemical Chaos flask
    Food = 104280,      -- Well Fed (Pandaren food buff for generic food icon)
    MHEnchant = 180608, -- Windfury Weapon
    OHEnchant = 180608, -- Same
    Rune = 1264426,     -- Augment Rune
    RaidBuffs = 1126,   -- Mark of the Wild
}

-- Class icons
local CLASS_ICONS = {
    WARRIOR = { atlas = "classicon-warrior" },
    PALADIN = { atlas = "classicon-paladin" },
    DRUID   = { atlas = "classicon-druid" },
    PRIEST  = { atlas = "classicon-priest" },
    EVOKER  = { atlas = "classicon-evoker" },
}

-- Spec icons (texture IDs for each spec's stance/form)
local SPEC_ICONS = {
    WARRIOR = {
        Arms = { textureId = 132355 },       -- Battle Stance
        Fury = { textureId = 132347 },       -- Berserker Stance
        Protection = { textureId = 132341 }, -- Defensive Stance
    },
    PALADIN = {
        Holy = { textureId = 135920 },        -- Devotion Aura
        Protection = { textureId = 236264 },  -- Devotion Aura
        Retribution = { textureId = 535595 }, -- Crusader Aura
    },
    DRUID = {
        Balance = { textureId = 136096 },  -- Moonkin Form
        Feral = { textureId = 132115 },    -- Cat Form
        Guardian = { textureId = 132276 }, -- Bear Form
    },
    PRIEST = {
        Shadow = { textureId = 136207 }, -- Shadowform
    },
    EVOKER = {
        Augmentation = { textureId = 5198700 }, -- Black Attunement
    },
}

-- Load condition options
local LOAD_CONDITIONS = {
    { key = "ALWAYS",   text = "Always" },
    { key = "ANYGROUP", text = "Any Group" },
    { key = "PARTY",    text = "In Party" },
    { key = "RAID",     text = "In Raid" },
    { key = "NOGROUP",  text = "No Group" },
}

-- Helper to create a fixed-size icon widget
-- TODO: Move into its own file and make re usable
local function CreateIconWidget(parent, iconData, size)
    size = size or 40
    -- Container frame that won't stretch
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(size + 8, size) -- Add small padding
    container.fixedWidth = size + 8   -- Mark as fixed width

    -- Icon frame inside container
    local iconFrame = CreateFrame("Frame", nil, container)
    iconFrame:SetSize(size, size)
    iconFrame:SetPoint("LEFT", container, "LEFT", 4, 0)

    -- Icon texture
    iconFrame.texture = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.texture:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
    iconFrame.texture:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)

    -- Determine icon type and set texture
    if type(iconData) == "table" then
        if iconData.atlas then
            iconFrame.texture:SetAtlas(iconData.atlas)
        elseif iconData.textureId then
            -- Direct texture ID with zoom
            local zoom = 0.3
            local texMin = 0.25 * zoom
            local texMax = 1 - 0.25 * zoom
            iconFrame.texture:SetTexCoord(texMin, texMax, texMin, texMax)
            iconFrame.texture:SetTexture(iconData.textureId)
        elseif iconData.spellId then
            -- Use spell texture with zoom
            local zoom = 0.3
            local texMin = 0.25 * zoom
            local texMax = 1 - 0.25 * zoom
            iconFrame.texture:SetTexCoord(texMin, texMax, texMin, texMax)

            local texture = C_Spell.GetSpellTexture(iconData.spellId)
            if texture then
                iconFrame.texture:SetTexture(texture)
            else
                iconFrame.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
        end
    elseif type(iconData) == "number" then
        local zoom = 0.3
        local texMin = 0.25 * zoom
        local texMax = 1 - 0.25 * zoom
        iconFrame.texture:SetTexCoord(texMin, texMax, texMin, texMax)

        local texture = C_Spell.GetSpellTexture(iconData)
        if texture then
            iconFrame.texture:SetTexture(texture)
        else
            iconFrame.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
    else
        iconFrame.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    -- Border stuff
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

    return container
end

-- Helper to create a category row with icon, checkbox, and load dropdown
local function CreateCategoryRow(card, categoryKey, label, iconSpellId, db, isFirst)
    -- Add separator if not first row
    if not isFirst then
        local sepRow = GUIFrame:CreateRow(card.content, 8)
        local sep = GUIFrame:CreateSeparator(sepRow)
        sepRow:AddWidget(sep, 1)
        table_insert(allWidgets, sep)
        card:AddRow(sepRow, 8)
    end

    local row = GUIFrame:CreateRow(card.content, 40)

    -- Icon widget
    local iconWidget = CreateIconWidget(row, iconSpellId, 40)
    row:AddWidget(iconWidget, 0.1)

    -- Enable checkbox
    local enableCheck = GUIFrame:CreateCheckbox(row, label, db[categoryKey] and db[categoryKey].Enabled ~= false,
        function(checked)
            db[categoryKey] = db[categoryKey] or {}
            db[categoryKey].Enabled = checked
            Refresh()
        end)
    row:AddWidget(enableCheck, 0.5)
    table_insert(allWidgets, enableCheck)

    -- Load condition dropdown
    local loadDropdown = GUIFrame:CreateDropdown(row, "Load", LOAD_CONDITIONS,
        (db[categoryKey] and db[categoryKey].LoadCondition) or "ALWAYS", 60,
        function(key)
            db[categoryKey] = db[categoryKey] or {}
            db[categoryKey].LoadCondition = key
            Refresh()
        end)
    row:AddWidget(loadDropdown, 0.4)
    table_insert(allWidgets, loadDropdown)

    card:AddRow(row, 40)
end

----------------------------------------------------------------
-- Sub-Tab 2: Raid & General Buffs
----------------------------------------------------------------
local function RenderRaidBuffsTab(scrollChild, yOffset, activeCards)
    local db = GetMissingBuffsDB()
    if not db then return yOffset end

    ----------------------------------------------------------------
    -- Card 1: Enable + Preview
    ----------------------------------------------------------------
    local card1a = GUIFrame:CreateCard(scrollChild, "Missing Buffs", yOffset)
    table_insert(activeCards, card1a)

    local row1a = GUIFrame:CreateRow(card1a.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1a, "Enable Missing Buffs", db.Enabled ~= false,
        function(checked)
            db.Enabled = checked
            Refresh()
            UpdateAllWidgetStates()
        end,
        true, "Missing Buffs", "On", "Off"
    )
    row1a:AddWidget(enableCheck, 0.5)
    card1a:AddRow(row1a, 36)

    yOffset = yOffset + card1a:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 1: Low Duration Warning
    ----------------------------------------------------------------
    --[[
    local card1 = GUIFrame:CreateCard(scrollChild, "Low Duration Warning", yOffset)
    table_insert(activeCards, card1)
    table_insert(allWidgets, card1)

    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local lowDurCheck = GUIFrame:CreateCheckbox(row1, "Warn Before Expiry", db.NotifyLowDuration ~= false,
        function(checked)
            db.NotifyLowDuration = checked
            ApplySettings()
        end)
    row1:AddWidget(lowDurCheck, 0.5)
    table_insert(allWidgets, lowDurCheck)

    local thresholdSlider = GUIFrame:CreateSlider(row1, "Minutes Left", 1, 60, 1, db.LowDurationThreshold or 5, 60,
        function(val)
            db.LowDurationThreshold = val
            ApplySettings()
        end)
    row1:AddWidget(thresholdSlider, 0.5)
    table_insert(allWidgets, thresholdSlider)
    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall
    --]]

    ----------------------------------------------------------------
    -- Card 2: Consumable & Buff Tracking
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Consumable & Buff Tracking", yOffset)
    table_insert(activeCards, card2)
    table_insert(allWidgets, card2)
    db.Consumables = db.Consumables or {}

    -- Flask row
    CreateCategoryRow(card2, "Flask", "Flask", CATEGORY_ICONS.Flask, db.Consumables, true)

    -- Food row
    CreateCategoryRow(card2, "Food", "Food Buff", CATEGORY_ICONS.Food, db.Consumables, false)

    -- MH Enchant row
    CreateCategoryRow(card2, "MHEnchant", "Main Hand Enchant", CATEGORY_ICONS.MHEnchant, db.Consumables, false)

    -- OH Enchant row
    CreateCategoryRow(card2, "OHEnchant", "Off Hand Enchant", CATEGORY_ICONS.OHEnchant, db.Consumables, false)

    -- Rune row
    CreateCategoryRow(card2, "Rune", "Augment Rune", CATEGORY_ICONS.Rune, db.Consumables, false)

    -- Raid Buffs row
    CreateCategoryRow(card2, "RaidBuffs", "Raid Buffs", CATEGORY_ICONS.RaidBuffs, db.Consumables, false)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 3: Display Settings
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Display Settings", yOffset)
    table_insert(activeCards, card3)
    table_insert(allWidgets, card3)
    db.RaidBuffDisplay = db.RaidBuffDisplay or {}

    -- Icon Size + Spacing
    local row3a = GUIFrame:CreateRow(card3.content, 36)
    local iconSizeSlider = GUIFrame:CreateSlider(row3a, "Icon Size", 24, 96, 1,
        db.RaidBuffDisplay.IconSize or db.IconSize or 48, 60,
        function(val)
            db.RaidBuffDisplay.IconSize = val
            ApplySettings()
        end)
    row3a:AddWidget(iconSizeSlider, 0.5)
    table_insert(allWidgets, iconSizeSlider)

    local iconSpacingSlider = GUIFrame:CreateSlider(row3a, "Icon Spacing", 0, 32, 1,
        db.RaidBuffDisplay.IconSpacing or db.IconSpacing or 8, 60,
        function(val)
            db.RaidBuffDisplay.IconSpacing = val
            ApplySettings()
        end)
    row3a:AddWidget(iconSpacingSlider, 0.5)
    table_insert(allWidgets, iconSpacingSlider)
    card3:AddRow(row3a, 36)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Position Settings
    ----------------------------------------------------------------
    db.RaidBuffDisplay.Position = db.RaidBuffDisplay.Position or {}

    local positionCard
    positionCard, yOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        title = "Position Settings",
        db = db.RaidBuffDisplay,
        dbKeys = {
            selfPoint = "AnchorFrom",
            anchorPoint = "AnchorTo",
            xOffset = "XOffset",
            yOffset = "YOffset",
        },
        defaults = {
            selfPoint = "CENTER",
            anchorPoint = "CENTER",
            xOffset = 0,
            yOffset = 200,
        },
        showAnchorFrameType = false,
        showStrata = false,
        onChangeCallback = ApplySettings,
    })
    table_insert(activeCards, positionCard)

    if positionCard.positionWidgets then
        for _, widget in ipairs(positionCard.positionWidgets) do
            table_insert(allWidgets, widget)
        end
    end
    table_insert(allWidgets, positionCard)

    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 4)
    return yOffset
end

-- Stance data for dropdowns
local STANCE_OPTIONS = {
    WARRIOR = {
        Arms = {
            { key = "386164", text = "Battle Stance" },
            { key = "386196", text = "Berserker Stance" },
            { key = "386208", text = "Defensive Stance" },
        },
        Fury = {
            { key = "386164", text = "Battle Stance" },
            { key = "386196", text = "Berserker Stance" },
            { key = "386208", text = "Defensive Stance" },
        },
        Protection = {
            { key = "386164", text = "Battle Stance" },
            { key = "386196", text = "Berserker Stance" },
            { key = "386208", text = "Defensive Stance" },
        },
    },
    PALADIN = {
        Holy = {
            { key = "465",    text = "Devotion Aura" },
            { key = "317920", text = "Concentration Aura" },
            { key = "32223",  text = "Crusader Aura" },
        },
        Protection = {
            { key = "465",    text = "Devotion Aura" },
            { key = "317920", text = "Concentration Aura" },
            { key = "32223",  text = "Crusader Aura" },
        },
        Retribution = {
            { key = "465",    text = "Devotion Aura" },
            { key = "317920", text = "Concentration Aura" },
            { key = "32223",  text = "Crusader Aura" },
        },
    },
    DRUID = {
        Balance = {
            { key = "24858", text = "Moonkin Form" },
            { key = "768",   text = "Cat Form" },
            { key = "5487",  text = "Bear Form" },
        },
        Feral = {
            { key = "768",   text = "Cat Form" },
            { key = "24858", text = "Moonkin Form" },
            { key = "5487",  text = "Bear Form" },
        },
        Guardian = {
            { key = "5487",  text = "Bear Form" },
            { key = "768",   text = "Cat Form" },
            { key = "24858", text = "Moonkin Form" },
        },
    },
    EVOKER = {
        Augmentation = {
            { key = "403264", text = "Black Attunement" },
            { key = "403265", text = "Bronze Attunement" },
        },
    },
    -- PRIEST handled separately
}

-- Helper to create a class stance card with spec-specific options
local function CreateClassStanceCard(scrollChild, yOffset, classKey, title, iconData, db, activeCards)
    db[classKey] = db[classKey] or {}

    local card = GUIFrame:CreateCard(scrollChild, title, yOffset)
    table_insert(activeCards, card)
    table_insert(allWidgets, card)

    -- Track widgets that need enable/disable updates
    local specWidgets = {}

    -- Header row with icon and enable checkbox
    local headerRow = GUIFrame:CreateRow(card.content, 40)

    -- Icon widget
    local iconWidget = CreateIconWidget(headerRow, iconData, 40)
    headerRow:AddWidget(iconWidget, 0.1)

    -- Function to update all spec widget states based on class enable state
    local function UpdateSpecWidgetStates()
        local classEnabled = db[classKey].Enabled ~= false
        for specName, widgets in pairs(specWidgets) do
            local specEnabledKey = specName .. "Enabled"
            local specEnabled = db[classKey][specEnabledKey] == true

            -- Toggle is disabled if class is disabled
            if widgets.toggle and widgets.toggle.SetEnabled then
                widgets.toggle:SetEnabled(classEnabled)
            end

            -- Dropdown is disabled if class is disabled OR spec toggle is off
            if widgets.dropdown and widgets.dropdown.SetEnabled then
                widgets.dropdown:SetEnabled(classEnabled and specEnabled)
            end
        end
    end

    -- Enable checkbox - warns if ANY stance/form is missing
    local enableCheck = GUIFrame:CreateCheckbox(headerRow, "Warn if no stance active", db[classKey].Enabled ~= false,
        function(checked)
            db[classKey].Enabled = checked
            UpdateSpecWidgetStates()
            Refresh()
        end)
    headerRow:AddWidget(enableCheck, 0.9)
    table_insert(allWidgets, enableCheck)
    card:AddRow(headerRow, 40)

    -- Get spec options for this class
    local specOptions = STANCE_OPTIONS[classKey]
    local specIcons = SPEC_ICONS[classKey]

    -- Add spec-specific rows if available
    if specOptions then
        -- Separator between main toggle and spec options
        local sepRow = GUIFrame:CreateRow(card.content, 8)
        local sep = GUIFrame:CreateSeparator(sepRow)
        sepRow:AddWidget(sep, 1)
        table_insert(allWidgets, sep)
        card:AddRow(sepRow, 8)

        for specName, options in pairs(specOptions) do
            local specRow = GUIFrame:CreateRow(card.content, 40)

            -- Spec icon
            local specIconId = specIcons and specIcons[specName]
            local specIconWidget = CreateIconWidget(specRow, specIconId or 134400, 32)
            specRow:AddWidget(specIconWidget, 0.1)

            -- Specific stance toggle
            local specEnabledKey = specName .. "Enabled"
            local specToggle = GUIFrame:CreateCheckbox(specRow, specName .. ": Require specific",
                db[classKey][specEnabledKey] == true,
                function(checked)
                    db[classKey][specEnabledKey] = checked
                    UpdateSpecWidgetStates()
                    Refresh()
                end)
            specRow:AddWidget(specToggle, 0.5)
            table_insert(allWidgets, specToggle)

            -- Preferred stance dropdown
            local specDropdown = GUIFrame:CreateDropdown(specRow, "Required", options,
                db[classKey][specName] or options[1].key, 80,
                function(key)
                    db[classKey][specName] = key
                    Refresh()
                end)
            specRow:AddWidget(specDropdown, 0.4)
            table_insert(allWidgets, specDropdown)

            -- Store widgets for enable/disable management
            specWidgets[specName] = { toggle = specToggle, dropdown = specDropdown }

            card:AddRow(specRow, 40)
        end

        -- Apply initial enable states
        C_Timer.After(0, UpdateSpecWidgetStates)
    end

    return yOffset + card:GetContentHeight() + Theme.paddingSmall
end

----------------------------------------------------------------
-- Sub-Tab 3: Stance & Spec Buffs
----------------------------------------------------------------
local function RenderStancesTab(scrollChild, yOffset, activeCards)
    local db = GetMissingBuffsDB()
    if not db then return yOffset end
    db.Stances = db.Stances or {}

    ----------------------------------------------------------------
    -- Card 1: Info Card
    ----------------------------------------------------------------
    local infoCard = GUIFrame:CreateCard(scrollChild, "Stance & Form Tracking", yOffset)
    table_insert(activeCards, infoCard)
    table_insert(allWidgets, infoCard)

    local infoTextHeight = 50
    local infoRow = GUIFrame:CreateRow(infoCard.content, infoTextHeight)
    local infoText = GUIFrame:CreateText(infoRow,
        NRSKNUI:ColorTextByTheme("How it works"),
        (NRSKNUI:ColorTextByTheme("• ") .. "Main toggle: Warns if you have no stance/form active at all\n" ..
            NRSKNUI:ColorTextByTheme("• ") .. "Per-spec toggles: When enabled, requires a specific stance for that spec"),
        infoTextHeight, "hide")
    infoRow:AddWidget(infoText, 1)
    table_insert(allWidgets, infoText)
    infoCard:AddRow(infoRow, infoTextHeight)

    yOffset = yOffset + infoCard:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Class Cards
    ----------------------------------------------------------------

    -- Warrior
    yOffset = CreateClassStanceCard(scrollChild, yOffset, "WARRIOR", "Warrior Stances",
        CLASS_ICONS.WARRIOR, db.Stances, activeCards)

    -- Paladin
    yOffset = CreateClassStanceCard(scrollChild, yOffset, "PALADIN", "Paladin Auras",
        CLASS_ICONS.PALADIN, db.Stances, activeCards)

    -- Druid
    yOffset = CreateClassStanceCard(scrollChild, yOffset, "DRUID", "Druid Forms",
        CLASS_ICONS.DRUID, db.Stances, activeCards)

    -- Evoker
    yOffset = CreateClassStanceCard(scrollChild, yOffset, "EVOKER", "Evoker Attunements",
        CLASS_ICONS.EVOKER, db.Stances, activeCards)

    -- Priest, simple single toggle, no class toggle or dropdown needed
    db.Stances.PRIEST = db.Stances.PRIEST or {}
    local priestCard = GUIFrame:CreateCard(scrollChild, "Shadow Priest Shadowform", yOffset)
    table_insert(activeCards, priestCard)
    table_insert(allWidgets, priestCard)

    local priestRow = GUIFrame:CreateRow(priestCard.content, 40)
    local priestIcon = CreateIconWidget(priestRow, SPEC_ICONS.PRIEST.Shadow, 40)
    priestRow:AddWidget(priestIcon, 0.1)

    local priestToggle = GUIFrame:CreateCheckbox(priestRow, "Require Shadowform", db.Stances.PRIEST.ShadowEnabled == true,
        function(checked)
            db.Stances.PRIEST.ShadowEnabled = checked
            Refresh()
        end)
    priestRow:AddWidget(priestToggle, 0.9)
    table_insert(allWidgets, priestToggle)
    priestCard:AddRow(priestRow, 40)

    yOffset = yOffset + priestCard:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Display Settings Card
    ----------------------------------------------------------------
    local card3 = GUIFrame:CreateCard(scrollChild, "Display Settings", yOffset)
    table_insert(activeCards, card3)
    table_insert(allWidgets, card3)
    db.StanceDisplay = db.StanceDisplay or {}

    -- Icon Size
    local row3a = GUIFrame:CreateRow(card3.content, 36)
    local iconSizeSlider = GUIFrame:CreateSlider(row3a, "Icon Size", 24, 96, 1,
        db.StanceDisplay.IconSize or 48, 60,
        function(val)
            db.StanceDisplay.IconSize = val
            ApplySettings()
        end)
    row3a:AddWidget(iconSizeSlider, 1)
    table_insert(allWidgets, iconSizeSlider)
    card3:AddRow(row3a, 36)

    yOffset = yOffset + card3:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 4: Position Settings
    ----------------------------------------------------------------
    db.StanceDisplay.Position = db.StanceDisplay.Position or {}
    local positionCard
    positionCard, yOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        title = "Position Settings",
        db = db.StanceDisplay,
        dbKeys = {
            selfPoint = "AnchorFrom",
            anchorPoint = "AnchorTo",
            xOffset = "XOffset",
            yOffset = "YOffset",
        },
        defaults = {
            selfPoint = "CENTER",
            anchorPoint = "CENTER",
            xOffset = 0,
            yOffset = 150,
        },
        showAnchorFrameType = false,
        showStrata = false,
        onChangeCallback = ApplySettings,
    })
    table_insert(activeCards, positionCard)

    if positionCard.positionWidgets then
        for _, widget in ipairs(positionCard.positionWidgets) do
            table_insert(allWidgets, widget)
        end
    end
    table_insert(allWidgets, positionCard)

    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 4)
    return yOffset
end

----------------------------------------------------------------
-- Sub-Tab 4: Stance Texts
----------------------------------------------------------------

-- Stance text data
local STANCE_TEXT_DATA = {
    WARRIOR = {
        { key = "386164", text = "Battle Stance",    textureId = 132349 },
        { key = "386196", text = "Berserker Stance", textureId = 132275 },
        { key = "386208", text = "Defensive Stance", textureId = 132341 },
    },
    PALADIN = {
        { key = "465",    text = "Devotion Aura",      textureId = 135893 },
        { key = "317920", text = "Concentration Aura", textureId = 135933 },
        { key = "32223",  text = "Crusader Aura",      textureId = 135890 },
    },
}

-- Helper to create a stance text card with per-stance settings
local function CreateStanceTextCard(scrollChild, yOffset, classKey, title, iconData, db, activeCards)
    db[classKey] = db[classKey] or {}

    local card = GUIFrame:CreateCard(scrollChild, title, yOffset)
    table_insert(activeCards, card)
    table_insert(allWidgets, card)

    local stances = STANCE_TEXT_DATA[classKey]
    if not stances then
        return yOffset + card:GetContentHeight() + Theme.paddingSmall
    end

    local isFirst = true
    for _, stance in ipairs(stances) do
        -- Add separator if not first row
        if not isFirst then
            local sepRow = GUIFrame:CreateRow(card.content, 8)
            local sep = GUIFrame:CreateSeparator(sepRow)
            sepRow:AddWidget(sep, 1)
            table_insert(allWidgets, sep)
            card:AddRow(sepRow, 8)
        end
        isFirst = false

        db[classKey][stance.key] = db[classKey][stance.key] or {}
        if not db[classKey][stance.key].Text then
            db[classKey][stance.key].Text = stance.text
        end

        local row = GUIFrame:CreateRow(card.content, 40)

        -- Stance icon
        local iconWidget = CreateIconWidget(row, { textureId = stance.textureId }, 36)
        row:AddWidget(iconWidget, 0.1)

        -- Enable toggle
        local enableToggle = GUIFrame:CreateCheckbox(row, "Show",
            db[classKey][stance.key].Enabled == true,
            function(checked)
                db[classKey][stance.key].Enabled = checked
                Refresh()
            end)
        row:AddWidget(enableToggle, 0.15)
        table_insert(allWidgets, enableToggle)

        -- Color picker
        local colorPicker = GUIFrame:CreateColorPicker(row, "Color",
            db[classKey][stance.key].Color or { 1, 1, 1, 1 },
            function(r, g, b, a)
                db[classKey][stance.key].Color = { r, g, b, a }
                ApplySettings()
            end)
        row:AddWidget(colorPicker, 0.25)
        table_insert(allWidgets, colorPicker)

        -- Text input
        local textInput = GUIFrame:CreateEditBox(row, "Text",
            db[classKey][stance.key].Text or stance.text,
            function(text)
                db[classKey][stance.key].Text = text
                ApplySettings()
            end)
        row:AddWidget(textInput, 0.5)
        table_insert(allWidgets, textInput)

        card:AddRow(row, 40)
    end

    return yOffset + card:GetContentHeight() + Theme.paddingSmall
end

local function RenderStanceTextsTab(scrollChild, yOffset, activeCards)
    local db = GetMissingBuffsDB()
    if not db then return yOffset end
    db.StanceText = db.StanceText or {}

    -- Build font list
    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do
            table_insert(fontList, { key = name, text = name })
        end
        table_sort(fontList, function(a, b) return a.text < b.text end)
    else
        table_insert(fontList, { key = "Friz Quadrata TT", text = "Friz Quadrata TT" })
    end

    local outlineList = {
        { key = "NONE",         text = "None" },
        { key = "OUTLINE",      text = "Outline" },
        { key = "THICKOUTLINE", text = "Thick" },
    }

    ----------------------------------------------------------------
    -- Card 1: Enable
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Stance Text Display", yOffset)
    table_insert(activeCards, card1)
    table_insert(allWidgets, card1)

    local row1 = GUIFrame:CreateRow(card1.content, 36)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Stance Text", db.StanceText.Enabled == true,
        function(checked)
            db.StanceText.Enabled = checked
            Refresh()
            UpdateAllWidgetStates()
        end)
    row1:AddWidget(enableCheck, 1)
    table_insert(allWidgets, enableCheck)
    card1:AddRow(row1, 36)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Warrior Stances
    ----------------------------------------------------------------
    yOffset = CreateStanceTextCard(scrollChild, yOffset, "WARRIOR", "Warrior Stance Texts",
        CLASS_ICONS.WARRIOR, db.StanceText, activeCards)

    ----------------------------------------------------------------
    -- Card 3: Paladin Auras
    ----------------------------------------------------------------
    yOffset = CreateStanceTextCard(scrollChild, yOffset, "PALADIN", "Paladin Aura Texts",
        CLASS_ICONS.PALADIN, db.StanceText, activeCards)

    ----------------------------------------------------------------
    -- Card 4: Font Settings
    ----------------------------------------------------------------
    local card4 = GUIFrame:CreateCard(scrollChild, "Font Settings", yOffset)
    table_insert(activeCards, card4)
    table_insert(allWidgets, card4)

    -- Font and Outline
    local row4a = GUIFrame:CreateRow(card4.content, 36)
    local fontDropdown = GUIFrame:CreateDropdown(row4a, "Font", fontList,
        db.StanceText.Font or "Friz Quadrata TT", 120,
        function(key)
            db.StanceText.Font = key
            ApplySettings()
        end)
    row4a:AddWidget(fontDropdown, 0.5)
    table_insert(allWidgets, fontDropdown)

    local outlineDropdown = GUIFrame:CreateDropdown(row4a, "Outline", outlineList,
        db.StanceText.FontOutline or "OUTLINE", 80,
        function(key)
            db.StanceText.FontOutline = key
            ApplySettings()
        end)
    row4a:AddWidget(outlineDropdown, 0.5)
    table_insert(allWidgets, outlineDropdown)
    card4:AddRow(row4a, 36)

    -- Font Size
    local row4b = GUIFrame:CreateRow(card4.content, 36)
    local fontSizeSlider = GUIFrame:CreateSlider(row4b, "Font Size", 8, 32, 1,
        db.StanceText.FontSize or 14, 60,
        function(val)
            db.StanceText.FontSize = val
            ApplySettings()
        end)
    row4b:AddWidget(fontSizeSlider, 1)
    table_insert(allWidgets, fontSizeSlider)
    card4:AddRow(row4b, 36)

    yOffset = yOffset + card4:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 5: Position Settings
    ----------------------------------------------------------------
    db.StanceText.Position = db.StanceText.Position or {}
    local positionCard
    positionCard, yOffset = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        title = "Position Settings",
        db = db.StanceText,
        dbKeys = {
            anchorFrameType = "anchorFrameType",
            anchorFrameFrame = "ParentFrame",
            selfPoint = "AnchorFrom",
            anchorPoint = "AnchorTo",
            xOffset = "XOffset",
            yOffset = "YOffset",
            strata = "Strata",
        },
        defaults = {
            anchorFrameType = "UIPARENT",
            selfPoint = "CENTER",
            anchorPoint = "CENTER",
            xOffset = 0,
            yOffset = 100,
            strata = "HIGH",
        },
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })
    table_insert(activeCards, positionCard)

    if positionCard.positionWidgets then
        for _, widget in ipairs(positionCard.positionWidgets) do
            table_insert(allWidgets, widget)
        end
    end
    table_insert(allWidgets, positionCard)

    UpdateAllWidgetStates()
    yOffset = yOffset - (Theme.paddingSmall * 4)
    return yOffset
end

----------------------------------------------------------------
-- Create Missing Buffs Panel
----------------------------------------------------------------
local function CreateMissingBuffsPanel(container)
    -- Full-size frame to take over content area
    local panel = CreateFrame("Frame", nil, container)
    panel:SetAllPoints()

    -- Tab bar at top
    local tabBar = CreateFrame("Frame", nil, panel)
    tabBar:SetHeight(TAB_BAR_HEIGHT)
    tabBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    tabBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)

    -- Tab bar background
    local tabBarBg = tabBar:CreateTexture(nil, "BACKGROUND")
    tabBarBg:SetAllPoints()
    tabBarBg:SetColorTexture(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], 1)

    -- Tab bar bottom border
    local tabBarBorder = tabBar:CreateTexture(nil, "ARTWORK")
    tabBarBorder:SetHeight(1)
    tabBarBorder:SetPoint("BOTTOMLEFT", tabBar, "BOTTOMLEFT", 0, 0)
    tabBarBorder:SetPoint("BOTTOMRIGHT", tabBar, "BOTTOMRIGHT", 0, 0)
    tabBarBorder:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    -- Cache tab bar
    cachedTabBar = tabBar

    -- Scroll frame below tab bar
    local scrollbarWidth = Theme.scrollbarWidth or 16
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -1)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

    -- Style scrollbar
    if scrollFrame.ScrollBar then
        local sb = scrollFrame.ScrollBar
        sb:ClearAllPoints()
        sb:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -(TAB_BAR_HEIGHT + Theme.paddingSmall + 13))
        sb:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -3, Theme.paddingSmall + 13)
        sb:SetWidth(scrollbarWidth - 4)

        -- Hide default scrollbar decorations
        if sb.Background then sb.Background:Hide() end
        if sb.Top then sb.Top:Hide() end
        if sb.Middle then sb.Middle:Hide() end
        if sb.Bottom then sb.Bottom:Hide() end
        if sb.trackBG then sb.trackBG:Hide() end
        if sb.ScrollUpButton then sb.ScrollUpButton:Hide() end
        if sb.ScrollDownButton then sb.ScrollDownButton:Hide() end
        -- Hide thumb when not needed
        sb:SetAlpha(0)

        -- Force scroll values to snap to whole screen pixels
        local isSnapping = false
        local PIXEL_STEP = 8 / 15
        sb:HookScript("OnValueChanged", function(self, value)
            if isSnapping then return end
            local scale = scrollFrame:GetEffectiveScale()
            local screenPixels = value * scale
            local snappedPixels = math.floor(screenPixels / PIXEL_STEP + 0.5) * PIXEL_STEP
            local snappedValue = snappedPixels / scale
            if math.abs(value - snappedValue) > 0.001 then
                isSnapping = true
                self:SetValue(snappedValue)
                isSnapping = false
            end
        end)
    end

    -- Scroll child
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    -- Track scrollbar visibility state
    local scrollbarVisible = false
    local baseWidth = Theme.contentWidth

    -- Update scrollChild width based on scrollbar visibility
    local function UpdateScrollChildWidth()
        if scrollbarVisible then
            scrollChild:SetWidth(baseWidth - scrollbarWidth)
        else
            scrollChild:SetWidth(baseWidth)
        end
    end

    -- Show/hide scrollbar and adjust content width based on content height
    local function UpdateScrollBarVisibility()
        if scrollFrame.ScrollBar then
            local contentHeight = scrollChild:GetHeight()
            local frameHeight = scrollFrame:GetHeight()
            local needsScrollbar = contentHeight > frameHeight

            scrollbarVisible = needsScrollbar
            scrollFrame.ScrollBar:SetAlpha(needsScrollbar and 1 or 0)
            UpdateScrollChildWidth()
        end
    end

    -- Initial width setup
    UpdateScrollChildWidth()

    -- Hook events for visibility updates
    scrollFrame:HookScript("OnScrollRangeChanged", UpdateScrollBarVisibility)
    scrollChild:HookScript("OnSizeChanged", UpdateScrollBarVisibility)
    scrollFrame:HookScript("OnSizeChanged", UpdateScrollBarVisibility)

    -- Also update on show
    scrollFrame:HookScript("OnShow", function()
        C_Timer.After(0, UpdateScrollBarVisibility)
    end)

    -- Track cards for width updates
    local activeCards = {}

    -- Update all card widths when scrollChild resizes
    local function UpdateCardWidths()
        local newWidth = scrollChild:GetWidth()
        for _, card in ipairs(activeCards) do
            if card and card.SetWidth then
                card:SetWidth(newWidth)
            end
        end
    end

    -- Hook scrollChild resize to update card widths
    scrollChild:HookScript("OnSizeChanged", function(self, width, height)
        UpdateCardWidths()
    end)

    -- Render content into scroll child
    local function RenderContentIntoScrollChild(tabId)
        -- Clear widget tracking
        wipe(allWidgets)

        -- Clear active cards tracking
        wipe(activeCards)

        -- Clear all existing children
        for _, child in ipairs({ scrollChild:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end

        -- Clear any regions
        for _, region in ipairs({ scrollChild:GetRegions() }) do
            if region:GetObjectType() == "FontString" or region:GetObjectType() == "Texture" then
                region:Hide()
            end
        end

        local yOffset = Theme.paddingMedium

        -- Render selected tab content
        if tabId == "raidBuffs" then
            yOffset = RenderRaidBuffsTab(scrollChild, yOffset, activeCards)
        elseif tabId == "stances" then
            yOffset = RenderStancesTab(scrollChild, yOffset, activeCards)
        elseif tabId == "stanceTexts" then
            yOffset = RenderStanceTextsTab(scrollChild, yOffset, activeCards)
        end

        -- Update scroll child height
        scrollChild:SetHeight(yOffset + Theme.paddingLarge)
    end

    -- Helper to update tab button visuals
    local function UpdateTabVisuals(buttons, selectedId)
        for _, btn in ipairs(buttons) do
            if btn.tabId == selectedId then
                btn.label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                btn.underline:Show()
                btn.selectedOverlay:Show()
            else
                btn.label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
                btn.underline:Hide()
                btn.selectedOverlay:Hide()
            end
        end
    end

    -- Create tab buttons
    local tabButtons = {}
    local minPadding = Theme.paddingMedium * 2
    local totalTextWidth = 0

    for i, tabDef in ipairs(SUB_TABS) do
        local btn = CreateFrame("Button", nil, tabBar)
        btn:SetHeight(TAB_BAR_HEIGHT)
        btn.tabId = tabDef.id
        btn.tabIndex = i

        -- Background
        local hoverBg = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
        hoverBg:SetAllPoints()
        hoverBg:SetColorTexture(1, 1, 1, 0.05)
        hoverBg:Hide()
        btn.hoverBg = hoverBg

        -- Selected overlay
        local selectedOverlay = btn:CreateTexture(nil, "BACKGROUND", nil, 2)
        selectedOverlay:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        selectedOverlay:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        selectedOverlay:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.1)
        selectedOverlay:Hide()
        btn.selectedOverlay = selectedOverlay

        -- Label
        local label = btn:CreateFontString(nil, "OVERLAY")
        label:SetPoint("CENTER", btn, "CENTER", 0, 0)
        if NRSKNUI.ApplyThemeFont then
            NRSKNUI:ApplyThemeFont(label, "small")
        else
            label:SetFontObject("GameFontNormalSmall")
        end
        label:SetText(tabDef.text)
        label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        btn.label = label

        -- Measure text width for proportional layout
        local textWidth = label:GetStringWidth()
        btn.textWidth = textWidth
        totalTextWidth = totalTextWidth + textWidth

        -- Underline
        local underline = btn:CreateTexture(nil, "OVERLAY")
        underline:SetHeight(2)
        underline:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
        underline:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        underline:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        underline:Hide()
        btn.underline = underline

        -- Mouse events
        btn:SetScript("OnEnter", function(self)
            if currentSubTab ~= self.tabId then
                self.hoverBg:Show()
            end
        end)

        btn:SetScript("OnLeave", function(self)
            self.hoverBg:Hide()
        end)

        btn:SetScript("OnClick", function(self)
            if currentSubTab ~= self.tabId then
                currentSubTab = self.tabId
                UpdateTabVisuals(cachedTabButtons, currentSubTab)
                RenderContentIntoScrollChild(currentSubTab)
            end
        end)

        table_insert(tabButtons, btn)
    end

    -- Cache tab buttons for callbacks
    cachedTabButtons = tabButtons

    -- Function to layout tabs proportionally based on text width
    local function LayoutTabs(barWidth)
        if barWidth <= 0 then return end

        local numTabs = #tabButtons
        local totalMinWidth = totalTextWidth + (minPadding * numTabs)

        -- Calculate extra space to distribute
        local extraSpace = math.max(0, barWidth - totalMinWidth)
        local extraPerTab = extraSpace / numTabs

        local xOffset = 0
        for _, btn in ipairs(tabButtons) do
            local tabWidth = btn.textWidth + minPadding + extraPerTab

            btn:ClearAllPoints()
            btn:SetPoint("TOP", tabBar, "TOP", 0, 0)
            btn:SetPoint("BOTTOM", tabBar, "BOTTOM", 0, 0)
            btn:SetPoint("LEFT", tabBar, "LEFT", xOffset, 0)
            btn:SetWidth(tabWidth)

            xOffset = xOffset + tabWidth
        end
    end

    -- Initial layout
    LayoutTabs(tabBar:GetWidth())

    -- Update tab positions when tabBar size changes
    tabBar:SetScript("OnSizeChanged", function(self, width, height)
        LayoutTabs(width)
    end)

    -- Initial tab selection and visuals
    UpdateTabVisuals(tabButtons, currentSubTab)

    -- Render initial content
    RenderContentIntoScrollChild(currentSubTab)

    UpdateAllWidgetStates()
    return panel
end

----------------------------------------------------------------
-- Register Panel (full control of content area)
----------------------------------------------------------------
GUIFrame:RegisterPanel("missingBuffs", CreateMissingBuffsPanel)

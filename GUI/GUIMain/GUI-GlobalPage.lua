---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

local pairs = pairs
local min = math.min

-- { key, label } specs drive the color-picker grids below. key indexes db.profile.Colors.<category>.
local PowerColorSpecs = {
    { key = 0,  label = 'Mana' },
    { key = 1,  label = 'Rage' },
    { key = 2,  label = 'Focus' },
    { key = 3,  label = 'Energy' },
    { key = 6,  label = 'Runic Power' },
    { key = 8,  label = 'Lunar Power' },
    { key = 11, label = 'Maelstrom' },
    { key = 13, label = 'Insanity' },
    { key = 17, label = 'Fury' },
    { key = 18, label = 'Pain' },
}

local ReactionColorSpecs = {
    { key = 1, label = 'Hated' },
    { key = 2, label = 'Hostile' },
    { key = 3, label = 'Unfriendly' },
    { key = 4, label = 'Neutral' },
    { key = 5, label = 'Friendly' },
    { key = 6, label = 'Honored' },
    { key = 7, label = 'Revered' },
    { key = 8, label = 'Exalted' },
}

local ClassColorSpecs = {
    { key = 'DEATHKNIGHT', label = 'Death Knight' },
    { key = 'DEMONHUNTER', label = 'Demon Hunter' },
    { key = 'DRUID',       label = 'Druid' },
    { key = 'EVOKER',      label = 'Evoker' },
    { key = 'HUNTER',      label = 'Hunter' },
    { key = 'MAGE',        label = 'Mage' },
    { key = 'MONK',        label = 'Monk' },
    { key = 'PALADIN',     label = 'Paladin' },
    { key = 'PRIEST',      label = 'Priest' },
    { key = 'ROGUE',       label = 'Rogue' },
    { key = 'SHAMAN',      label = 'Shaman' },
    { key = 'WARLOCK',     label = 'Warlock' },
    { key = 'WARRIOR',     label = 'Warrior' },
}

local StatusColorSpecs = {
    { key = 'Tapped',       label = 'Tapped' },
    { key = 'Disconnected', label = 'Disconnected' },
    { key = 'Dead',         label = 'Dead' },
}

GUIFrame:RegisterContent('GlobalPage', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.globalMedia
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local barDB = db.profileBar

    local manager = GUIFrame:CreateWidgetStateManager()

    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    manager:SetCondition('globBarON', function() return barDB.Enabled end)

    local function ApplyToAllModules()
        for _, module in NRSKNUI:IterateModules() do
            if module:IsEnabled() and module.ApplySettings then
                module:ApplySettings()
            end
        end
    end

    local GlobalBarCard = GUIFrame:CreateCard(scrollChild, 'Global Bar', yOffset)
    local row2 = GUIFrame:CreateRow(GlobalBarCard.content, Theme.rowHeightLast)
    local globalBarToggle = GUIFrame:CreateCheckbox(row2, 'Use Global Bar Texture', {
        value = barDB.Enabled,
        callback = function(checked)
            barDB.Enabled = checked
            UpdateAllWidgetStates()
            ApplyToAllModules()
        end,
        msgPopup = true,
        msgText = 'Global Bar',
    })
    row2:AddWidget(globalBarToggle, 0.5)

    local statusbarList = {}
    if LSM then
        for name in pairs(LSM:HashTable('statusbar')) do
            statusbarList[name] = name
        end
    end

    local barDropdown = GUIFrame:CreateDropdown(row2, 'Global Bar Texture', {
        options = statusbarList,
        value = barDB.statusBar,
        callback = function(key)
            barDB.statusBar = key
            ApplyToAllModules()
        end,
        searchable = true,
    })
    row2:AddWidget(barDropdown, 0.5)
    manager:Register(barDropdown, 'all', 'globBarON')
    GlobalBarCard:AddRow(row2, Theme.rowHeightLast, 0)

    yOffset = GlobalBarCard:GetNextOffset()

    local uiDB = NRSKNUI.db.global.UIScale
    local uiManager = GUIFrame:CreateWidgetStateManager()
    local function UpdateUIScaleStates()
        uiManager:UpdateAll(uiDB.Enabled)
    end

    local UIScaleCard = GUIFrame:CreateCard(scrollChild, 'UI Scale', yOffset)

    local uiRow1 = GUIFrame:CreateRow(UIScaleCard.content, Theme.rowHeight)
    local enableScaleToggle = GUIFrame:CreateCheckbox(uiRow1, 'Enable UI Scale', {
        value = uiDB.Enabled,
        callback = function(checked)
            uiDB.Enabled = checked
            UpdateUIScaleStates()
            NRSKNUI:SetUIScale()
        end,
        msgPopup = true,
        msgText = 'UI Scale',
        tooltip = 'Disable scaling in other addons to avoid conflicts.',
    })
    uiRow1:AddWidget(enableScaleToggle, 0.5)

    local scaleSlider = GUIFrame:CreateSlider(uiRow1, 'Scale', {
        min = 0.4,
        max = 1.15,
        step = 0.01,
        value = uiDB.Scale,
        callback = function(val)
            uiDB.Scale = val
            NRSKNUI:SetScaleValue(uiDB.Scale)
        end,
        callbackOnRelease = true,
    })

    uiRow1:AddWidget(scaleSlider, 0.5)
    uiManager:Register(scaleSlider, 'all')
    UIScaleCard:AddRow(uiRow1, Theme.rowHeight, 0)

    local uiRow2 = GUIFrame:CreateRow(UIScaleCard.content, Theme.rowHeightLast)
    local autoScaleToggle = GUIFrame:CreateButton(uiRow2, 'Auto (Pixel Perfect)', {
        height = 30,
        callback = function()
            UpdateUIScaleStates()
            NRSKNUI:SetScaleValue()
        end,
        tooltip = 'Automatically match your resolution (768 / screen height).',
    })
    uiRow2:AddWidget(autoScaleToggle, (1 / 3), nil, 0, -6)
    uiManager:Register(autoScaleToggle, 'all')

    local tenEigthyP = GUIFrame:CreateButton(uiRow2, '1080p Scale', {
        height = 30,
        callback = function()
            UpdateUIScaleStates()
            NRSKNUI:SetScaleValue(NRSKNUI.TenEigthyPixel)
        end,
        tooltip = 'Set UI scale for 1080p resolution.',
    })
    uiRow2:AddWidget(tenEigthyP, (1 / 3), nil, 0, -6)
    uiManager:Register(tenEigthyP, 'all')

    local fourteenFortyP = GUIFrame:CreateButton(uiRow2, '1440p Scale', {
        height = 30,
        callback = function()
            UpdateUIScaleStates()
            NRSKNUI:SetScaleValue(NRSKNUI.FourteenFortyPixel)
        end,
        tooltip = 'Set UI scale for 1440p resolution.',
    })
    uiRow2:AddWidget(fourteenFortyP, (1 / 3), nil, 0, -6)
    uiManager:Register(fourteenFortyP, 'all')
    UIScaleCard:AddRow(uiRow2, Theme.rowHeightLast, 0)

    yOffset = UIScaleCard:GetNextOffset()

    -- Custom colors, shared palette pushed into oUF.colors / NRSKNUI.Colors on every change.
    local colorsDB = NRSKNUI.db.profile.Colors

    local function RefreshColors()
        NRSKNUI:LoadCustomColors()
        ApplyToAllModules()
    end

    -- Build one card of color pickers laid out three per row from a { key, label } spec list.
    local function BuildColorCard(title, dbTable, specs, storeAlpha)
        local card = GUIFrame:CreateCard(scrollChild, title, yOffset)
        local count = #specs
        for i = 1, count, 3 do
            local isLast = (i + 2) >= count
            local rowHeight = isLast and Theme.rowHeightLast or Theme.rowHeight
            local row = GUIFrame:CreateRow(card.content, rowHeight)
            for j = i, min(i + 2, count) do
                local spec = specs[j]
                local picker = GUIFrame:CreateColorPicker(row, spec.label, {
                    color = dbTable[spec.key],
                    callback = function(r, g, b, a)
                        dbTable[spec.key] = storeAlpha and { r, g, b, a } or { r, g, b }
                        RefreshColors()
                    end,
                })
                row:AddWidget(picker, 1 / 3)
            end
            card:AddRow(row, rowHeight, isLast and 0 or nil)
        end
        yOffset = card:GetNextOffset()
    end

    BuildColorCard('Power Colors', colorsDB.Power, PowerColorSpecs, false)
    BuildColorCard('Reaction Colors', colorsDB.Reaction, ReactionColorSpecs, false)
    BuildColorCard('Class Colors', colorsDB.Class, ClassColorSpecs, false)
    BuildColorCard('Status Colors', colorsDB.Status, StatusColorSpecs, true)

    UpdateAllWidgetStates()
    UpdateUIScaleStates()

    return yOffset
end)

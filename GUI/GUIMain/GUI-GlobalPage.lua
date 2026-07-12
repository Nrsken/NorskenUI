---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

local pairs = pairs

GUIFrame:RegisterContent('GlobalPage', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.globalMedia
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local fontDB = db.profileFont
    local barDB = db.profileBar

    local manager = GUIFrame:CreateWidgetStateManager()

    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    manager:SetCondition('globFontON', function() return fontDB.Enabled end)
    manager:SetCondition('globBarON', function() return barDB.Enabled end)

    local function ApplyToAllModules()
        for _, module in NRSKNUI:IterateModules() do
            if module:IsEnabled() and module.ApplySettings then
                module:ApplySettings()
            end
        end
    end

    local GlobalFontCard = GUIFrame:CreateCard(scrollChild, 'Global Font', yOffset)
    local row1 = GUIFrame:CreateRow(GlobalFontCard.content, Theme.rowHeightLast)
    local globalFontToggle = GUIFrame:CreateCheckbox(row1, 'Use Global Font', {
        value = fontDB.Enabled,
        callback = function(checked)
            fontDB.Enabled = checked
            UpdateAllWidgetStates()
            ApplyToAllModules()
            NRSKNUI:RefreshFontStyles()
        end,
        msgPopup = true,
        msgText = 'Global Font',
    })
    row1:AddWidget(globalFontToggle, 0.5)

    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable('font')) do
            fontList[name] = name
        end
    end

    local fontDropdown = GUIFrame:CreateDropdown(row1, 'Font', {
        options = fontList,
        value = fontDB.FontFace,
        callback = function(key)
            fontDB.FontFace = key
            ApplyToAllModules()
            NRSKNUI:RefreshFontStyles()
        end,
        searchable = true,
        isFontPreview = true
    })
    row1:AddWidget(fontDropdown, 0.5)
    manager:Register(fontDropdown, 'all', 'globFontON')
    GlobalFontCard:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = GlobalFontCard:GetNextOffset()

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

    UpdateAllWidgetStates()
    UpdateUIScaleStates()

    return yOffset
end)

---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local rowHLast = Theme.rowHeightLast
local rowH = Theme.rowHeight

GUIFrame:RegisterContent('global_uiscale', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.global.UIScale
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local manager = GUIFrame:CreateWidgetStateManager()
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    local UIScaleCard = GUIFrame:CreateCard(scrollChild, 'UI Scale', yOffset)

    local uiRow1 = GUIFrame:CreateRow(UIScaleCard.content, rowH)
    local enableScaleToggle = GUIFrame:CreateCheckbox(uiRow1, 'Enable UI Scale', {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            UpdateAllWidgetStates()
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
        value = db.Scale,
        callback = function(val)
            db.Scale = val
            NRSKNUI:SetScaleValue(db.Scale)
        end,
        callbackOnRelease = true,
    })

    uiRow1:AddWidget(scaleSlider, 0.5)
    manager:Register(scaleSlider, 'all')
    UIScaleCard:AddRow(uiRow1, rowH, 0)

    local uiRow2 = GUIFrame:CreateRow(UIScaleCard.content, rowHLast)
    local autoScaleToggle = GUIFrame:CreateButton(uiRow2, 'Auto (Pixel Perfect)', {
        height = 30,
        callback = function()
            UpdateAllWidgetStates()
            NRSKNUI:SetScaleValue()
        end,
        tooltip = 'Automatically match your resolution (768 / screen height).',
    })
    uiRow2:AddWidget(autoScaleToggle, (1 / 3), nil, 0, -6)
    manager:Register(autoScaleToggle, 'all')

    local tenEigthyP = GUIFrame:CreateButton(uiRow2, '1080p Scale', {
        height = 30,
        callback = function()
            UpdateAllWidgetStates()
            NRSKNUI:SetScaleValue(NRSKNUI.TenEigthyPixel)
        end,
        tooltip = 'Set UI scale for 1080p resolution.',
    })
    uiRow2:AddWidget(tenEigthyP, (1 / 3), nil, 0, -6)
    manager:Register(tenEigthyP, 'all')

    local fourteenFortyP = GUIFrame:CreateButton(uiRow2, '1440p Scale', {
        height = 30,
        callback = function()
            UpdateAllWidgetStates()
            NRSKNUI:SetScaleValue(NRSKNUI.FourteenFortyPixel)
        end,
        tooltip = 'Set UI scale for 1440p resolution.',
    })
    uiRow2:AddWidget(fourteenFortyP, (1 / 3), nil, 0, -6)
    manager:Register(fourteenFortyP, 'all')
    UIScaleCard:AddRow(uiRow2, rowHLast, 0)

    yOffset = UIScaleCard:GetNextOffset()

    UpdateAllWidgetStates()

    return yOffset
end)

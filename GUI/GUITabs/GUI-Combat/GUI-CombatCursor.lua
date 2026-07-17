---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CursorCircle
local CursorCircle = NRSKNUI:GetModule('CursorCircle')
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local table_insert = table.insert
local CreateFrame = CreateFrame
local ipairs = ipairs
local math_min = math.min

local buttonSize = 51

local function CreateTextureSelector(parent, textures, currentTexture, getColorFunc, onSelect)
    local container = CreateFrame('Frame', nil, parent)

    local buttons = {}
    local spacing = Theme.paddingMedium

    -- Keep our own height so AddWidget doesn't stretch us to the row height
    container.explicitHeight = true
    container:SetPixelHeight(buttonSize)

    for _, texData in ipairs(textures) do
        local btn = CreateFrame('Button', nil, container, 'BackdropTemplate')
        btn:SetPixelSize(buttonSize, buttonSize)
        btn:SetBackdrop({
            bgFile = 'Interface\\BUTTONS\\WHITE8X8',
            edgeFile = 'Interface\\BUTTONS\\WHITE8X8',
            edgeSize = 1,
        })
        btn:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)

        local tex = btn:CreateTexture(nil, 'ARTWORK')
        tex:SetPixelPoint('TOPLEFT', 8, -8)
        tex:SetPixelPoint('BOTTOMRIGHT', -8, 8)
        tex:SetTexture(texData.path)
        tex:SetPixelSnap()
        btn.tex = tex
        btn.textureKey = texData.key

        local function UpdateVisuals()
            local isSelected = currentTexture == btn.textureKey
            local r, g, b, a = 1, 1, 1, 1
            if getColorFunc then r, g, b, a = getColorFunc() end

            if btn.disabled then
                btn:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 0.6)
                tex:SetVertexColor(r * 0.3, g * 0.3, b * 0.3)
                tex:SetAlpha(0.5)
            elseif isSelected then
                btn:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                tex:SetVertexColor(r, g, b)
                tex:SetAlpha(a)
            elseif btn.hover then
                btn:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                tex:SetVertexColor(r * 0.8, g * 0.8, b * 0.8)
                tex:SetAlpha(a * 0.9)
            else
                btn:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
                tex:SetVertexColor(r * 0.6, g * 0.6, b * 0.6)
                tex:SetAlpha(a * 0.8)
            end
        end
        btn.UpdateVisuals = UpdateVisuals

        btn:SetScript('OnEnter', function(self)
            self.hover = true
            UpdateVisuals()
        end)

        btn:SetScript('OnLeave', function(self)
            self.hover = false
            UpdateVisuals()
            GameTooltip:Hide()
        end)

        btn:SetScript('OnClick', function(self)
            if self.disabled then return end
            currentTexture = self.textureKey
            for _, b in ipairs(buttons) do b.UpdateVisuals() end
            if onSelect then onSelect(self.textureKey) end
        end)

        UpdateVisuals()
        table_insert(buttons, btn)
    end

    local function LayoutButtons(width)
        local count = #buttons
        if count == 0 or not width or width <= 0 then return end
        local size = math_min(buttonSize, (width - (count - 1) * spacing) / count)
        if size < 1 then size = 1 end
        for i, btn in ipairs(buttons) do
            btn:SetPixelSize(size, size)
            btn:ClearAllPoints()
            if i == 1 then
                btn:SetPixelPoint('LEFT', container, 'LEFT', 0, -Theme.paddingSmall)
            else
                btn:SetPixelPoint('LEFT', buttons[i - 1], 'RIGHT', spacing, 0)
            end
        end
    end

    container:SetScript('OnSizeChanged', function(_, width) LayoutButtons(width) end)
    LayoutButtons(container:GetWidth())

    function container:SetEnabled(enabled)
        for _, btn in ipairs(buttons) do
            btn.disabled = not enabled
            btn:EnableMouse(enabled)
            btn.UpdateVisuals()
        end
    end

    function container:SetValue(textureKey)
        currentTexture = textureKey
        for _, btn in ipairs(buttons) do btn.UpdateVisuals() end
    end

    function container:RefreshColors()
        for _, btn in ipairs(buttons) do btn.UpdateVisuals() end
    end

    container.buttons = buttons
    return container
end

GUIFrame:RegisterContent('cursorCircle', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.CursorCircle
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local gcd = db.GCD
    local textureSelector, gcdTextureSelector
    local buttonRowHeight = buttonSize + Theme.paddingSmall + 1

    local manager = GUIFrame:CreateWidgetStateManager()
    local function ApplySettings()
        CursorCircle:ApplySettings()
        if textureSelector then textureSelector:RefreshColors() end
        if gcdTextureSelector then gcdTextureSelector:RefreshColors() end
    end
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end

    manager:SetCondition('colorMode', function() return db.ColorMode == 'custom' end)
    manager:SetCondition('gcdEnabled', function() return gcd.Mode ~= 'disabled' end)
    manager:SetCondition('gcdSeparate', function() return gcd.Mode == 'separate' end)
    manager:SetCondition('gcdSwipeCustom', function() return gcd.SwipeColorMode == 'custom' end)
    manager:SetCondition('gcdRingCustom', function() return gcd.RingColorMode == 'custom' end)

    local function GetEffectiveColor() return NRSKNUI:GetAccentColor(db.ColorMode, db.Color) end
    local function GetGCDEffectiveColor() return NRSKNUI:GetAccentColor(gcd.RingColorMode, gcd.RingColor) end

    -- Card 1: Enable
    local card1 = GUIFrame:CreateCard(scrollChild, 'Cursor Circle', yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, 'Enable Cursor Circle', {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule('CursorCircle')
            else
                NRSKNUI:DisableModule('CursorCircle')
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = 'Cursor Circle',
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2: General Settings
    local card2 = GUIFrame:CreateCard(scrollChild, 'General Settings', yOffset)
    manager:Register(card2, 'all')

    local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local gcdModeDropdown = GUIFrame:CreateDropdown(row2a, 'GCD Mode', {
        options = CursorCircle.GCDModeOptions,
        value = gcd.Mode,
        callback = function(key)
            gcd.Mode = key
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row2a:AddWidget(gcdModeDropdown, 0.5)
    manager:Register(gcdModeDropdown, 'all')

    local visModeDropdown = GUIFrame:CreateDropdown(row2a, 'Visibility', {
        options = CursorCircle.VisibilityModeOptions,
        value = db.VisibilityMode,
        callback = function(key)
            db.VisibilityMode = key
            ApplySettings()
        end
    })
    row2a:AddWidget(visModeDropdown, 0.5)
    manager:Register(visModeDropdown, 'all')
    card2:AddRow(row2a, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    -- Card 3: Main Ring Settings
    local card3 = GUIFrame:CreateCard(scrollChild, 'Main Ring Settings', yOffset)
    manager:Register(card3, 'all')

    local row3a = GUIFrame:CreateRow(card3.content, buttonRowHeight)
    textureSelector = CreateTextureSelector(row3a, CursorCircle.Textures, db.Texture, GetEffectiveColor, function(key)
        db.Texture = key
        ApplySettings()
    end)
    row3a:AddWidget(textureSelector, 0.5)
    manager:Register(textureSelector, 'all')

    local sizeSlider = GUIFrame:CreateSlider(row3a, 'Size', {
        min = 20,
        max = 150,
        step = 1,
        value = db.Size,
        callback = function(val)
            db.Size = val
            ApplySettings()
        end
    })
    row3a:AddWidget(sizeSlider, 0.5, nil, nil, -15)
    manager:Register(sizeSlider, 'all')
    card3:AddRow(row3a, buttonRowHeight)

    local sep3main = GUIFrame:CreateSeparator(card3.content)
    card3:AddRow(sep3main, Theme.rowHeightSeparator)

    local row3c = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
    local colorModeDropdown = GUIFrame:CreateDropdown(row3c, 'Color Mode', {
        options = NRSKNUI.ColorModeOptions,
        value = db.ColorMode,
        callback = function(key)
            db.ColorMode = key
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row3c:AddWidget(colorModeDropdown, 0.5)
    manager:Register(colorModeDropdown, 'all')

    local colorPicker = GUIFrame:CreateColorPicker(row3c, 'Custom Color', {
        color = db.Color,
        callback = function(r, g, b, a)
            db.Color = { r, g, b, a }
            ApplySettings()
        end
    })
    row3c:AddWidget(colorPicker, 0.5)
    manager:Register(colorPicker, 'all', 'colorMode')
    card3:AddRow(row3c, Theme.rowHeightLast, 0)

    yOffset = card3:GetNextOffset()

    -- Card 4: GCD Settings
    local card4 = GUIFrame:CreateCard(scrollChild, 'GCD Settings', yOffset)
    manager:Register(card4, 'all', 'gcdEnabled')

    local row4a = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local gcdSwipeColorModeDropdown = GUIFrame:CreateDropdown(row4a, 'Swipe Color Mode', {
        options = NRSKNUI.ColorModeOptions,
        value = gcd.SwipeColorMode,
        callback = function(key)
            gcd.SwipeColorMode = key
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row4a:AddWidget(gcdSwipeColorModeDropdown, 0.5)
    manager:Register(gcdSwipeColorModeDropdown, 'all', 'gcdEnabled')

    local gcdSwipeColorPicker = GUIFrame:CreateColorPicker(row4a, 'Custom Color', {
        color = gcd.SwipeColor,
        callback = function(r, g, b, a)
            gcd.SwipeColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row4a:AddWidget(gcdSwipeColorPicker, 0.5)
    manager:Register(gcdSwipeColorPicker, 'all', 'gcdEnabled', 'gcdSwipeCustom')
    card4:AddRow(row4a, Theme.rowHeight)

    local row4b = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local reverseCheck = GUIFrame:CreateCheckbox(row4b, 'Reverse Swipe', {
        value = gcd.Reverse,
        callback = function(checked)
            gcd.Reverse = checked
            ApplySettings()
        end
    })
    row4b:AddWidget(reverseCheck, 1)
    manager:Register(reverseCheck, 'all', 'gcdEnabled')
    card4:AddRow(row4b, Theme.rowHeight)

    local row4ba = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
    local hideOOCCheck = GUIFrame:CreateCheckbox(row4ba, 'Only In Combat', {
        value = gcd.HideOutOfCombat,
        callback = function(checked)
            gcd.HideOutOfCombat = checked
            ApplySettings()
        end
    })
    row4ba:AddWidget(hideOOCCheck, 1)
    manager:Register(hideOOCCheck, 'all', 'gcdEnabled')
    card4:AddRow(row4ba, Theme.rowHeight)

    local sep4a = GUIFrame:CreateSeparator(card4.content)
    card4:AddRow(sep4a, Theme.rowHeightSeparator - 3)

    local row4c = GUIFrame:CreateRow(card4.content, buttonRowHeight)
    gcdTextureSelector = CreateTextureSelector(row4c, CursorCircle.Textures, gcd.Texture, GetGCDEffectiveColor, function(key)
        gcd.Texture = key
        ApplySettings()
    end)
    row4c:AddWidget(gcdTextureSelector, 0.5)
    manager:Register(gcdTextureSelector, 'all', 'gcdSeparate')

    local gcdSizeSlider = GUIFrame:CreateSlider(row4c, 'Ring Size', {
        min = 10,
        max = 150,
        step = 1,
        value = gcd.Size,
        callback = function(val)
            gcd.Size = val
            ApplySettings()
        end
    })
    row4c:AddWidget(gcdSizeSlider, 0.5, nil, nil, -15)
    manager:Register(gcdSizeSlider, 'all', 'gcdSeparate')
    card4:AddRow(row4c, buttonRowHeight)

    local sep3gcd = GUIFrame:CreateSeparator(card4.content)
    card4:AddRow(sep3gcd, Theme.rowHeightSeparator)

    local row4e = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
    local gcdRingColorModeDropdown = GUIFrame:CreateDropdown(row4e, 'Ring Color Mode', {
        options = NRSKNUI.ColorModeOptions,
        value = gcd.RingColorMode,
        callback = function(key)
            gcd.RingColorMode = key
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row4e:AddWidget(gcdRingColorModeDropdown, 0.5)
    manager:Register(gcdRingColorModeDropdown, 'all', 'gcdSeparate')

    local gcdRingColorPicker = GUIFrame:CreateColorPicker(row4e, 'Custom Color', {
        color = gcd.RingColor,
        callback = function(r, g, b, a)
            gcd.RingColor = { r, g, b, a }
            ApplySettings()
        end
    })
    row4e:AddWidget(gcdRingColorPicker, 0.5)
    manager:Register(gcdRingColorPicker, 'all', 'gcdSeparate', 'gcdRingCustom')
    card4:AddRow(row4e, Theme.rowHeightLast, 0)

    yOffset = card4:GetNextOffset()

    UpdateAllWidgetStates()

    return yOffset
end)

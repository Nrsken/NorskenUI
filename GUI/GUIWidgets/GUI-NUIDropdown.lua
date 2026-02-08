-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local tostring = tostring
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local math_max, math_min = math.max, math.min
local UIParent = UIParent
local type = type
local table_insert, table_sort, table_remove = table.insert, table.sort, table.remove
local wipe = wipe
local IsMouseButtonDown = IsMouseButtonDown
local ipairs = ipairs
local pairs = pairs

-- Configuration constants
local DROPDOWN_HEIGHT = 24
local ITEM_HEIGHT = 24
local MAX_DROPDOWN_HEIGHT = 400
local ANIMATION_DURATION = 0.12
local ARROW_SIZE = 16
local ARROW_TEX = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\collapse.tga"
local ENABLE_ANIMATIONS = true

-- Cached backdrop tables
local DROPDOWN_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}
local SCROLLBAR_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}
local BORDER_ONLY_BACKDROP = {
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local globalMouseChecker = CreateFrame("Frame", nil, UIParent)
globalMouseChecker:Hide()
globalMouseChecker.activeDropdown = nil
globalMouseChecker.wasMouseDown = false

globalMouseChecker:SetScript("OnUpdate", function(self)
    local dropdown = self.activeDropdown
    if not dropdown then
        self:Hide()
        return
    end

    local isDown = IsMouseButtonDown("LeftButton")
    if self.wasMouseDown and not isDown then
        local dropdownList = dropdown._dropdownList
        local dropdownButton = dropdown._dropdownButton
        if dropdownList and dropdownButton then
            if not dropdownList:IsMouseOver() and not dropdownButton:IsMouseOver() then
                if dropdown._closeDropdown then
                    dropdown._closeDropdown()
                end
            end
        end
    end
    self.wasMouseDown = isDown
end)

local itemButtonPool = {}

local function AcquireItemButton(parent)
    local btn = table_remove(itemButtonPool)
    if btn then
        btn:SetParent(parent)
        btn:Show()
        return btn
    end

    -- Create new button with hover texture
    btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(ITEM_HEIGHT)

    -- Hover background texture
    local hoverBg = btn:CreateTexture(nil, "BACKGROUND")
    hoverBg:SetAllPoints()
    hoverBg:SetColorTexture(
        Theme.accentHover[1],
        Theme.accentHover[2],
        Theme.accentHover[3],
        Theme.accentHover[4] or 0.25
    )
    hoverBg:Hide()
    btn._hoverBg = hoverBg

    -- Text
    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetPoint("LEFT", btn, "LEFT", 8, 0)
    btnText:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    btnText:SetJustifyH("LEFT")
    NRSKNUI:ApplyThemeFont(btnText, "normal")
    btn._text = btnText

    return btn
end

local function ReleaseItemButton(btn)
    btn:Hide()
    btn:SetParent(nil)
    btn:SetScript("OnClick", nil)
    btn:SetScript("OnEnter", nil)
    btn:SetScript("OnLeave", nil)
    btn._hoverBg:Hide()
    btn._itemValue = nil
    btn._itemText = nil
    btn._updateColor = nil
    table_insert(itemButtonPool, btn)
end

function GUIFrame:CreateDropdown(parent, labelText, options, selected, labelWidth, callback)
    local tooltip = nil
    local sorting = nil
    local customHeight = nil

    -- CREATE ROW CONTAINER
    local rowHeight = customHeight or 34
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(rowHeight)

    -- Label
    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    NRSKNUI:ApplyThemeFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    row.label = label

    -- Main dropdown button
    local dropdownButton = CreateFrame("Button", nil, row, "BackdropTemplate")
    dropdownButton:SetHeight(DROPDOWN_HEIGHT)
    dropdownButton:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -14)
    dropdownButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -14)
    dropdownButton:SetBackdrop(DROPDOWN_BACKDROP)
    dropdownButton:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], 1)
    dropdownButton:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    -- Selected text
    local selectedText = dropdownButton:CreateFontString(nil, "OVERLAY")
    selectedText:SetPoint("LEFT", dropdownButton, "LEFT", Theme.paddingSmall, 0)
    selectedText:SetPoint("RIGHT", dropdownButton, "RIGHT", -24, 0)
    selectedText:SetJustifyH("LEFT")
    NRSKNUI:ApplyThemeFont(selectedText, "normal")
    selectedText:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    dropdownButton.selectedText = selectedText

    -- Arrow icon
    local arrow = dropdownButton:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    arrow:SetPoint("RIGHT", dropdownButton, "RIGHT", -Theme.paddingSmall, 0)
    arrow:SetTexture(ARROW_TEX)
    arrow:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    arrow:SetTexelSnappingBias(0)
    arrow:SetSnapToPixelGrid(false)
    arrow:SetRotation(-math.pi / 2)

    -- Normalize options and preserve order if provided as array
    local normalizedOptions = {}
    local orderedKeys = nil
    if type(options) == "table" then
        if options[1] and type(options[1]) == "table" and (options[1].value or options[1].key) then
            orderedKeys = {}
            for _, opt in ipairs(options) do
                local optKey = opt.value or opt.key
                normalizedOptions[optKey] = opt.text
                table_insert(orderedKeys, optKey)
            end
        else
            local isSequentialArray = options[1] ~= nil and type(options[1]) == "string"
            if isSequentialArray then
                for _, v in ipairs(options) do
                    normalizedOptions[v] = v
                end
            else
                for k, v in pairs(options) do
                    normalizedOptions[k] = v
                end
            end
        end
    end
    if sorting and type(sorting) == "table" then
        orderedKeys = sorting
    end

    -- State variables
    local isOpen = false
    local currentValue = selected
    local itemButtons = {}
    local itemsCreated = false
    local startHeight = 0
    local targetHeight = 0
    local scrollHold = false

    -- Dropdown list
    local dropdownList = CreateFrame("Frame", nil, row, "BackdropTemplate")
    dropdownList:SetHeight(1)
    dropdownList:SetBackdrop(DROPDOWN_BACKDROP)
    dropdownList:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], 1)
    dropdownList:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    dropdownList:SetFrameStrata("TOOLTIP")
    dropdownList:SetClipsChildren(true)
    dropdownList:Hide()

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, dropdownList)
    scrollFrame:SetPoint("TOPLEFT", dropdownList, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", dropdownList, "BOTTOMRIGHT", 0, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)

    -- Scrollbar components
    local scrollbar = nil
    local thumb = nil
    local thumbBorder = nil

    local function EnsureScrollbar()
        if scrollbar then return end

        scrollbar = CreateFrame("Slider", nil, dropdownList, "BackdropTemplate")
        scrollbar:SetPoint("TOPRIGHT", dropdownList, "TOPRIGHT", 0, 0)
        scrollbar:SetPoint("BOTTOMRIGHT", dropdownList, "BOTTOMRIGHT", 0, 0)
        scrollbar:SetWidth(12)
        scrollbar:SetBackdrop(SCROLLBAR_BACKDROP)
        scrollbar:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
        scrollbar:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
        scrollbar:SetOrientation("VERTICAL")
        local pxlPerfStep = NRSKNUI:PixelBestSize()
        scrollbar:SetValueStep(pxlPerfStep)
        scrollbar:SetMinMaxValues(0, 100)
        scrollbar:SetValue(0)
        scrollbar:Hide()

        scrollbar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
        scrollbar:SetScript("OnValueChanged", function(_, value)
            scrollFrame:SetVerticalScroll(value)
        end)

        scrollbar:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then
                scrollHold = true
            end
        end)
        scrollbar:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then
                C_Timer.After(0.1, function()
                    scrollHold = false
                end)
            end
        end)

        thumb = scrollbar:GetThumbTexture()
        thumb:SetSize(12, 30)
        thumb:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.8)

        thumbBorder = CreateFrame("Frame", nil, scrollbar, "BackdropTemplate")
        thumbBorder:SetPoint("TOPLEFT", thumb, 0, 0)
        thumbBorder:SetPoint("BOTTOMRIGHT", thumb, 0, 0)
        thumbBorder:SetBackdrop(BORDER_ONLY_BACKDROP)
        thumbBorder:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

        thumb:HookScript("OnShow", function() thumbBorder:Show() end)
        thumb:HookScript("OnHide", function() thumbBorder:Hide() end)
    end

    -- Animation groups
    local animGroup, arrowAnimGroup, arrowRotation

    if ENABLE_ANIMATIONS then
        animGroup = dropdownList:CreateAnimationGroup()
        local heightAnim = animGroup:CreateAnimation("Animation")
        heightAnim:SetDuration(ANIMATION_DURATION)

        arrowAnimGroup = arrow:CreateAnimationGroup()
        arrowRotation = arrowAnimGroup:CreateAnimation("Rotation")
        arrowRotation:SetDuration(ANIMATION_DURATION)
        arrowRotation:SetOrigin("CENTER", 0, 0)
        arrowRotation:SetSmoothing("IN_OUT")

        arrowAnimGroup:SetScript("OnFinished", function()
            arrow:SetRotation(isOpen and 0 or -math.pi / 2)
        end)
    end

    -- Border hover animation
    local hoverAnimGroup, hoverAnim
    local borderColorFrom = { r = Theme.border[1], g = Theme.border[2], b = Theme.border[3] }
    local borderColorTo = { r = Theme.border[1], g = Theme.border[2], b = Theme.border[3] }

    if ENABLE_ANIMATIONS then
        hoverAnimGroup = dropdownButton:CreateAnimationGroup()
        hoverAnim = hoverAnimGroup:CreateAnimation("Animation")
        hoverAnim:SetDuration(0.15)

        hoverAnimGroup:SetScript("OnUpdate", function(self)
            local progress = self:GetProgress() or 0
            local r = borderColorFrom.r + (borderColorTo.r - borderColorFrom.r) * progress
            local g = borderColorFrom.g + (borderColorTo.g - borderColorFrom.g) * progress
            local b = borderColorFrom.b + (borderColorTo.b - borderColorFrom.b) * progress
            dropdownButton:SetBackdropBorderColor(r, g, b, 1)
        end)

        hoverAnimGroup:SetScript("OnFinished", function()
            dropdownButton:SetBackdropBorderColor(borderColorTo.r, borderColorTo.g, borderColorTo.b, 1)
        end)
    end

    local function SetBorderHover(hovered)
        if ENABLE_ANIMATIONS and hoverAnimGroup then
            hoverAnimGroup:Stop()

            local currentR, currentG, currentB = dropdownButton:GetBackdropBorderColor()
            borderColorFrom.r = currentR
            borderColorFrom.g = currentG
            borderColorFrom.b = currentB

            if hovered then
                borderColorTo.r = Theme.accent[1]
                borderColorTo.g = Theme.accent[2]
                borderColorTo.b = Theme.accent[3]
            else
                borderColorTo.r = Theme.border[1]
                borderColorTo.g = Theme.border[2]
                borderColorTo.b = Theme.border[3]
            end

            hoverAnimGroup:Play()
        else
            -- Instant fallback
            if hovered then
                dropdownButton:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            else
                dropdownButton:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
            end
        end
    end

    -- Close dropdown function
    local function CloseDropdown(instant)
        if scrollHold then return end
        if not isOpen then return end

        isOpen = false

        -- Force instant if animations disabled
        if not ENABLE_ANIMATIONS then
            instant = true
        end

        if instant then
            dropdownList:SetHeight(1)
            dropdownList:Hide()

            if dropdownList._logicalParent then
                dropdownList:SetParent(dropdownList._logicalParent)
                dropdownList._logicalParent = nil
            end

            arrow:SetRotation(-math.pi / 2)
            if animGroup then animGroup:Stop() end
            if arrowAnimGroup then arrowAnimGroup:Stop() end
        else
            startHeight = dropdownList:GetHeight()
            targetHeight = 1
            if arrowAnimGroup then
                arrowAnimGroup:Stop()
                arrowRotation:SetRadians(-math.pi / 2)
                arrowAnimGroup:Play()
            end
            if animGroup then
                animGroup:Stop()
                animGroup:Play()
            end
        end

        -- Unregister from global mouse checker
        if globalMouseChecker.activeDropdown == row then
            globalMouseChecker.activeDropdown = nil
            globalMouseChecker:Hide()
        end

        if GUIFrame.activeDropdown == dropdownButton then
            GUIFrame.activeDropdown = nil
        end
    end

    -- Update scroll state
    local function UpdateScroll()
        local contentHeight = scrollChild:GetHeight()
        local scrollFrameHeight = scrollFrame:GetHeight()
        local needsScrollbar = contentHeight > scrollFrameHeight and scrollFrameHeight > 0

        if needsScrollbar then
            EnsureScrollbar()
            if scrollbar then
                scrollbar:Show()
                scrollbar:SetMinMaxValues(0, contentHeight - scrollFrameHeight)
                scrollbar:SetValue(0)
            end
            scrollFrame:SetPoint("BOTTOMRIGHT", dropdownList, "BOTTOMRIGHT", -11, 0)
        else
            if scrollbar then
                scrollbar:Hide()
                scrollbar:SetMinMaxValues(0, 0)
            end
            scrollFrame:SetVerticalScroll(0)
            scrollFrame:SetPoint("BOTTOMRIGHT", dropdownList, "BOTTOMRIGHT", 0, 0)
        end

        scrollChild:SetWidth(scrollFrame:GetWidth())

        -- Position buttons using stored index
        for _, btn in ipairs(itemButtons) do
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(btn._index - 1) * ITEM_HEIGHT)
            btn:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
        end
    end

    -- Animation scripts
    if ENABLE_ANIMATIONS and animGroup then
        animGroup:SetScript("OnUpdate", function(self)
            local progress = self:GetProgress() or 0
            local smoothProgress = progress * progress * (3 - 2 * progress)
            local newHeight = startHeight + (targetHeight - startHeight) * smoothProgress
            dropdownList:SetHeight(newHeight)

            if isOpen and newHeight < targetHeight then
                dropdownList:SetClipsChildren(false)
            end
        end)

        animGroup:SetScript("OnFinished", function()
            dropdownList:SetHeight(targetHeight)

            if not isOpen then
                dropdownList:Hide()

                if dropdownList._logicalParent then
                    dropdownList:SetParent(dropdownList._logicalParent)
                    dropdownList._logicalParent = nil
                end
            else
                dropdownList:SetClipsChildren(true)
            end
        end)
    end

    -- Create item buttons
    local function CreateItemButtons()
        -- Release existing buttons back to pool
        for _, btn in ipairs(itemButtons) do
            ReleaseItemButton(btn)
        end
        wipe(itemButtons)

        local sortedKeys
        if orderedKeys then
            sortedKeys = orderedKeys
        else
            sortedKeys = {}
            for k in pairs(normalizedOptions) do
                table_insert(sortedKeys, k)
            end
            table_sort(sortedKeys, function(a, b)
                return tostring(a) < tostring(b)
            end)
        end

        for i, key in ipairs(sortedKeys) do
            local displayText = normalizedOptions[key]

            local btn = AcquireItemButton(scrollChild)
            btn._itemValue = key
            btn._itemText = displayText
            btn._index = i -- Store index directly on button
            btn._text:SetText(displayText or key)

            -- Update color function
            local function UpdateItemColor()
                if currentValue == btn._itemValue then
                    btn._text:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                else
                    btn._text:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
                end
            end
            btn._updateColor = UpdateItemColor
            UpdateItemColor()

            btn:SetScript("OnClick", function()
                currentValue = btn._itemValue
                selectedText:SetText(btn._itemText or btn._itemValue)

                for _, itemBtn in ipairs(itemButtons) do
                    if itemBtn._updateColor then
                        itemBtn._updateColor()
                    end
                end

                CloseDropdown()

                if callback then
                    callback(btn._itemValue)
                end
            end)

            btn:SetScript("OnEnter", function()
                btn._hoverBg:Show()
                btn._text:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3], 1)
            end)

            btn:SetScript("OnLeave", function()
                btn._hoverBg:Hide()
                UpdateItemColor()
            end)

            btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ITEM_HEIGHT)
            btn:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)

            table_insert(itemButtons, btn)
        end

        scrollChild:SetHeight(#sortedKeys * ITEM_HEIGHT)
        itemsCreated = true
    end

    -- Mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        if scrollbar and scrollbar:IsShown() then
            local current = scrollbar:GetValue()
            local minVal, maxVal = scrollbar:GetMinMaxValues()
            local newValue = current - (delta * ITEM_HEIGHT)
            newValue = math_max(minVal, math_min(maxVal, newValue))
            scrollbar:SetValue(newValue)
        end
    end)

    -- Toggle dropdown
    local function ToggleDropdown()
        if isOpen then
            CloseDropdown()
        else
            if not itemsCreated then
                CreateItemButtons()
            end

            dropdownList._logicalParent = dropdownList:GetParent()
            dropdownList:SetParent(NRSKNUI.GUIOverlay)
            dropdownList:ClearAllPoints()
            dropdownList:SetPoint("TOPLEFT", dropdownButton, "BOTTOMLEFT", 0, -2)
            dropdownList:SetPoint("TOPRIGHT", dropdownButton, "BOTTOMRIGHT", 0, -2)

            local contentHeight = #itemButtons * ITEM_HEIGHT
            local maxHeight = math_min(contentHeight, MAX_DROPDOWN_HEIGHT)

            startHeight = 1
            targetHeight = maxHeight

            dropdownList:SetHeight(targetHeight)
            scrollChild:SetWidth(scrollFrame:GetWidth())
            UpdateScroll()
            dropdownList:Show()
            dropdownList:SetHeight(startHeight)

            isOpen = true

            -- Close other open dropdown
            if GUIFrame.activeDropdown and GUIFrame.activeDropdown ~= dropdownButton then
                if GUIFrame.activeDropdown.closeDropdown then
                    GUIFrame.activeDropdown.closeDropdown()
                end
            end
            GUIFrame.activeDropdown = dropdownButton

            -- Animate or instant
            if ENABLE_ANIMATIONS and animGroup and arrowAnimGroup then
                arrowAnimGroup:Stop()
                arrowRotation:SetRadians(math.pi / 2)
                arrowAnimGroup:Play()
                animGroup:Play()
            else
                -- Instant open
                arrow:SetRotation(0)
                dropdownList:SetHeight(targetHeight)
            end

            -- Register with global mouse checker
            row._dropdownList = dropdownList
            row._dropdownButton = dropdownButton
            row._closeDropdown = CloseDropdown
            globalMouseChecker.activeDropdown = row
            globalMouseChecker.wasMouseDown = false
            globalMouseChecker:Show()
        end
    end

    -- Button scripts
    dropdownButton:SetScript("OnClick", ToggleDropdown)

    dropdownButton:SetScript("OnEnter", function()
        SetBorderHover(true)
        if tooltip then
            GameTooltip:SetOwner(dropdownButton, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)

    dropdownButton:SetScript("OnLeave", function()
        SetBorderHover(false)
        GameTooltip:Hide()
    end)

    -- Set initial selected text
    if selected and normalizedOptions[selected] then
        selectedText:SetText(normalizedOptions[selected])
        currentValue = selected
    elseif selected ~= nil then
        selectedText:SetText(tostring(selected))
        currentValue = selected
    else
        selectedText:SetText("Select...")
        currentValue = nil
    end

    -- Hide handlers
    dropdownList:SetScript("OnHide", function()
        if isOpen then
            isOpen = false
        end
    end)

    dropdownButton:SetScript("OnHide", function()
        CloseDropdown(true)
        if GUIFrame.activeDropdown == dropdownButton then
            GUIFrame.activeDropdown = nil
        end
    end)

    -- Public API
    function row:SetValue(value, silent)
        currentValue = value
        if normalizedOptions[value] then
            selectedText:SetText(normalizedOptions[value])
        else
            selectedText:SetText(tostring(value))
        end

        -- Only update colors if items exist
        if itemsCreated then
            for _, btn in ipairs(itemButtons) do
                if btn._updateColor then
                    btn._updateColor()
                end
            end
        end

        if callback and not silent then
            callback(value)
        end
    end

    function row:SetSelected(value, silent)
        return row:SetValue(value, silent)
    end

    function row:GetValue()
        return currentValue
    end

    function row:GetSelected()
        return currentValue
    end

    function row:SetEnabled(enabled)
        if enabled then
            dropdownButton:Enable()
            dropdownButton:SetAlpha(1)
            label:SetAlpha(1)
        else
            dropdownButton:Disable()
            dropdownButton:SetAlpha(0.5)
            label:SetAlpha(0.5)
            if isOpen then
                CloseDropdown()
            end
        end
    end

    function row:UpdateOptions(newOptions)
        normalizedOptions = {}
        orderedKeys = nil
        if type(newOptions) == "table" then
            if newOptions[1] and type(newOptions[1]) == "table" and (newOptions[1].key or newOptions[1].value) then
                orderedKeys = {}
                for _, opt in ipairs(newOptions) do
                    local optKey = opt.key or opt.value
                    normalizedOptions[optKey] = opt.text
                    table_insert(orderedKeys, optKey)
                end
            else
                local isSequentialArray = newOptions[1] ~= nil and type(newOptions[1]) == "string"
                if isSequentialArray then
                    for _, v in ipairs(newOptions) do
                        normalizedOptions[v] = v
                    end
                else
                    for k, v in pairs(newOptions) do
                        normalizedOptions[k] = v
                    end
                end
            end
        end

        -- Recreate items if they were already created
        if itemsCreated then
            CreateItemButtons()
            if isOpen then
                UpdateScroll()
            end
        end
    end

    function row:SetOptions(newOptions)
        return row:UpdateOptions(newOptions)
    end

    dropdownButton.closeDropdown = CloseDropdown
    row.dropdown = dropdownButton

    return row
end

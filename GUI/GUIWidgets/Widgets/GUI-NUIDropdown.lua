---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local NUIDropdownMixin = {}

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
local strlower = string.lower
local strfind = string.find
local Mixin = Mixin

local DROPDOWN_HEIGHT = 24
local ITEM_HEIGHT = 24
local MAX_DROPDOWN_HEIGHT = 400

local SEARCH_BOX_HEIGHT = 24
local SEARCH_PADDING = 6
local SEARCH_INPUT_RIGHT_PADDING = 16
local FONT_PREVIEW_SIZE = 12

local ARROW_TEX = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\collapse.tga"
local ARROW_SIZE = 16

local STANDARD_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, }
local BORDER_ONLY_BACKDROP = { edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, }
local HOVER_DURATION = 0.12

local function SafeApplyPreviewFont(fontString, fontPath, size)
    if not fontString or not fontPath then return false end
    fontString:SetShadowColor(0, 0, 0, 0)
    local success = fontString:SetFont(fontPath, size or FONT_PREVIEW_SIZE, "OUTLINE")
    if not success then fontString:SetFontObject("GameFontHighlightSmall") end
    return success
end

---@param value any
---@param silent? boolean
function NUIDropdownMixin:SetValue(value, silent)
    self._currentValue = value
    if self._normalizedOptions[value] then
        self._selectedText:SetText(self._normalizedOptions[value])
    else
        self._selectedText:SetText(tostring(value))
    end

    local optionColor = self._optionColors and self._optionColors[value]
    if optionColor then
        self._selectedText:SetTextColor(optionColor.r or optionColor[1], optionColor.g or optionColor[2],
            optionColor.b or optionColor[3], 1)
    else
        self._selectedText:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    end

    if self._isFontPreview then
        local fontPath = NRSKNUI:GetFontPath(value)
        SafeApplyPreviewFont(self._selectedText, fontPath, FONT_PREVIEW_SIZE)
    end

    for _, btn in ipairs(self._itemButtons) do if btn._updateColor then btn._updateColor() end end

    if self._callback and not silent then self._callback(value) end
end

---@param value any
---@param silent? boolean
function NUIDropdownMixin:SetSelected(value, silent) return self:SetValue(value, silent) end

---@return any
function NUIDropdownMixin:GetValue() return self._currentValue end

---@return any
function NUIDropdownMixin:GetSelected() return self._currentValue end

---@param enabled boolean
function NUIDropdownMixin:SetEnabled(enabled)
    if enabled then
        self.dropdown:Enable()
        self.dropdown:SetAlpha(1)
        self.label:SetAlpha(1)
    else
        self.dropdown:Disable()
        self.dropdown:SetAlpha(0.5)
        self.label:SetAlpha(0.5)
        if self._isOpen then
            self._closeDropdown()
        end
    end
end

---@param newOptions table
function NUIDropdownMixin:UpdateOptions(newOptions)
    self._normalizedOptions = {}
    self._optionColors = {}
    self._optionTooltips = {}
    self._orderedKeys = nil
    if type(newOptions) == "table" then
        if newOptions[1] and type(newOptions[1]) == "table" and (newOptions[1].key or newOptions[1].value) then
            self._orderedKeys = {}
            for _, opt in ipairs(newOptions) do
                local optKey = opt.key or opt.value
                self._normalizedOptions[optKey] = opt.text
                if opt.color then
                    self._optionColors[optKey] = opt.color
                end
                if opt.tooltip then
                    self._optionTooltips[optKey] = opt.tooltip
                end
                table_insert(self._orderedKeys, optKey)
            end
        else
            local isSequentialArray = newOptions[1] ~= nil and type(newOptions[1]) == "string"
            if isSequentialArray then
                for _, v in ipairs(newOptions) do self._normalizedOptions[v] = v end
            else
                for k, v in pairs(newOptions) do self._normalizedOptions[k] = v end
            end
        end
    end

    if self._itemsCreated then
        self._createItemButtons()
        if self._isOpen then self._updateScroll() end
    end
end

---@param newOptions table
function NUIDropdownMixin:SetOptions(newOptions) return self:UpdateOptions(newOptions) end

function NUIDropdownMixin:UpdateColors()
    self.label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    self.dropdown:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], 1)
    self.dropdown:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    self._selectedText:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    self._dropdownList:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], 1)
    self._dropdownList:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    local arrow = self.dropdown.arrow
    if arrow then
        arrow:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    end

    if self._scrollbar then
        self._scrollbar:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
        self._scrollbar:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
        if self._thumb then
            self._thumb:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.8)
        end
        if self._thumbBorder then
            self._thumbBorder:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
        end
    end

    if self._searchContainer then
        self._searchContainer:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
        self._searchContainer:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    end
    if self._searchEditBox then
        self._searchEditBox:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    end
    if self._emptyLabel then
        self._emptyLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    end

    for _, btn in ipairs(self._itemButtons) do
        if btn._updateColor then
            btn._updateColor()
        end
    end
end

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
        btn._hoverBg:SetColorTexture(1, 1, 1, 0.05)
        btn._hoverBg:SetAlpha(0)
        btn._hoverTarget = 0
        NRSKNUI:ApplyThemeFont(btn._text, "normal")
        btn:Show()
        return btn
    end

    btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(ITEM_HEIGHT)

    local hoverBg = btn:CreateTexture(nil, "BACKGROUND")
    hoverBg:SetAllPoints()
    hoverBg:SetColorTexture(1, 1, 1, 0.05)
    hoverBg:SetAlpha(0)
    btn._hoverBg = hoverBg
    btn._hoverTarget = 0

    btn:SetScript("OnUpdate", function(self, elapsed)
        local current = self._hoverBg:GetAlpha()
        if math.abs(current - self._hoverTarget) > 0.01 then
            local speed = elapsed / HOVER_DURATION
            if self._hoverTarget > current then
                self._hoverBg:SetAlpha(math.min(current + speed, self._hoverTarget))
            else
                self._hoverBg:SetAlpha(math.max(current - speed, self._hoverTarget))
            end
        end
    end)

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetPoint("LEFT", btn, "LEFT", 8, 0)
    btnText:SetPoint("RIGHT", btn, "RIGHT", -24, 0)
    btnText:SetJustifyH("LEFT")
    NRSKNUI:ApplyThemeFont(btnText, "normal")
    btn._text = btnText

    local indicator = btn:CreateFontString(nil, "OVERLAY")
    indicator:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    NRSKNUI:ApplyThemeFont(indicator, "large")
    indicator:SetText("•")
    indicator:Hide()
    btn._indicator = indicator

    return btn
end

local function ReleaseItemButton(btn)
    btn:Hide()
    btn:SetParent(nil)
    btn:SetScript("OnClick", nil)
    btn:SetScript("OnEnter", nil)
    btn:SetScript("OnLeave", nil)
    btn._hoverBg:SetAlpha(0)
    btn._hoverTarget = 0
    btn._itemValue = nil
    btn._itemText = nil
    btn._updateColor = nil
    btn._index = nil
    if btn._indicator then btn._indicator:Hide() end
    table_insert(itemButtonPool, btn)
end

---@class NUIDropdown : Frame
---@field label FontString
---@field dropdown Button
---@field SetValue fun(self: NUIDropdown, value: any, silent?: boolean)
---@field SetSelected fun(self: NUIDropdown, value: any, silent?: boolean)
---@field GetValue fun(self: NUIDropdown): any
---@field GetSelected fun(self: NUIDropdown): any
---@field SetEnabled fun(self: NUIDropdown, enabled: boolean)
---@field UpdateOptions fun(self: NUIDropdown, newOptions: table)
---@field SetOptions fun(self: NUIDropdown, newOptions: table)
---@field UpdateColors fun(self: NUIDropdown)

---@class NUIDropdownConfig
---@field options table
---@field value? any
---@field callback? fun(value: any)
---@field searchable? boolean
---@field isFontPreview? boolean
---@field theme? number[]

---Dropdown with optional search and font preview
---```lua
---config = {
---    options = table,         -- Key-value pairs or array of {key, text} (required)
---    value = any,             -- Initial selected key
---    callback = function,     -- Called when selection changes
---    searchable = boolean,    -- Enable search/filter input (default: false)
---    isFontPreview = boolean, -- Show font preview in dropdown items (default: false)
---}
---```
---@param parent Frame
---@param labelText string
---@param config NUIDropdownConfig
---@return NUIDropdown
function GUIFrame:CreateDropdown(parent, labelText, config)
    config = config or {}
    local options = config.options
    local selected = config.value
    local callback = config.callback
    local searchable = config.searchable == true
    local isFontPreview = config.isFontPreview
    local theme = config.theme or Theme.bgMedium

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(34)
    row._optionTooltips = {}

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    NRSKNUI:ApplyThemeFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    row.label = label

    local dropdownButton = CreateFrame("Button", nil, row, "BackdropTemplate")
    dropdownButton:SetHeight(DROPDOWN_HEIGHT)
    dropdownButton:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -14)
    dropdownButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -14)
    dropdownButton:SetBackdrop(STANDARD_BACKDROP)
    dropdownButton:SetBackdropColor(theme[1], theme[2], theme[3], 1)
    dropdownButton:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    local selectedText = dropdownButton:CreateFontString(nil, "OVERLAY")
    selectedText:SetPoint("LEFT", dropdownButton, "LEFT", Theme.paddingSmall, 0)
    selectedText:SetPoint("RIGHT", dropdownButton, "RIGHT", -24, 0)
    selectedText:SetJustifyH("LEFT")
    NRSKNUI:ApplyThemeFont(selectedText, "normal")
    selectedText:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    dropdownButton.selectedText = selectedText

    local arrow = dropdownButton:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    arrow:SetPoint("RIGHT", dropdownButton, "RIGHT", -Theme.paddingSmall, 0)
    arrow:SetTexture(ARROW_TEX)
    arrow:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    arrow:SetTexelSnappingBias(0)
    arrow:SetSnapToPixelGrid(false)
    arrow:SetRotation(-math.pi / 2)
    dropdownButton.arrow = arrow

    row._normalizedOptions = {}
    row._optionColors = {}
    row._optionIndicators = {}
    row._orderedKeys = nil
    if type(options) == "table" then
        if options[1] and type(options[1]) == "table" and (options[1].value or options[1].key) then
            row._orderedKeys = {}
            for _, opt in ipairs(options) do
                local optKey = opt.value or opt.key
                row._normalizedOptions[optKey] = opt.text
                if opt.color then
                    row._optionColors[optKey] = opt.color
                end
                if opt.tooltip then
                    row._optionTooltips[optKey] = opt.tooltip
                end
                if opt.indicator then
                    row._optionIndicators[optKey] = opt.indicator
                end
                table_insert(row._orderedKeys, optKey)
            end
        else
            local isSequentialArray = options[1] ~= nil and type(options[1]) == "string"
            if isSequentialArray then
                for _, v in ipairs(options) do row._normalizedOptions[v] = v end
            else
                for k, v in pairs(options) do row._normalizedOptions[k] = v end
            end
        end
    end

    row._isOpen = false
    row._currentValue = selected
    row._itemButtons = {}
    row._itemsCreated = false
    row._isFontPreview = isFontPreview
    row._callback = callback
    row._selectedText = selectedText
    local startHeight = 0
    local targetHeight = 0
    local scrollHold = false
    local filteredKeys = {}
    local searchText = ""
    local firstVisibleKey = nil

    local dropdownList = CreateFrame("Frame", nil, row, "BackdropTemplate")
    dropdownList:SetHeight(1)
    dropdownList:SetBackdrop(STANDARD_BACKDROP)
    dropdownList:SetBackdropColor(theme[1], theme[2], theme[3], 1)
    dropdownList:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    dropdownList:SetFrameStrata("TOOLTIP")
    dropdownList:SetClipsChildren(true)
    dropdownList:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", nil, dropdownList)
    scrollFrame:SetPoint("TOPLEFT", dropdownList, "TOPLEFT", 0, searchable and -(SEARCH_BOX_HEIGHT + SEARCH_PADDING) or 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", dropdownList, "BOTTOMRIGHT", 0, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)

    local searchContainer = nil
    local searchEditBox = nil
    local emptyLabel = nil

    local scrollbar = nil
    local thumb = nil
    local thumbBorder = nil

    local function EnsureScrollbar()
        if scrollbar then return end

        scrollbar = CreateFrame("Slider", nil, dropdownList, "BackdropTemplate")
        scrollbar:SetPoint("TOPRIGHT", dropdownList, "TOPRIGHT", 0, 0)
        scrollbar:SetPoint("BOTTOMRIGHT", dropdownList, "BOTTOMRIGHT", 0, 0)
        scrollbar:SetWidth(12)
        scrollbar:SetBackdrop(STANDARD_BACKDROP)
        scrollbar:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
        scrollbar:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
        scrollbar:SetOrientation("VERTICAL")
        local pxlPerfStep = NRSKNUI:GetBestPixelSize()
        scrollbar:SetValueStep(pxlPerfStep)
        scrollbar:SetMinMaxValues(0, 100)
        scrollbar:SetValue(0)
        scrollbar:Hide()

        scrollbar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
        scrollbar:SetScript("OnValueChanged", function(_, value) scrollFrame:SetVerticalScroll(value) end)
        scrollbar:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then scrollHold = true end end)
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

        row._scrollbar = scrollbar
        row._thumb = thumb
        row._thumbBorder = thumbBorder
    end

    local animGroup = dropdownList:CreateAnimationGroup()
    animGroup:CreateAnimation("Animation"):SetDuration(Theme.animDuration)

    local arrowAnimGroup = arrow:CreateAnimationGroup()
    local arrowRotation = arrowAnimGroup:CreateAnimation("Rotation")
    arrowRotation:SetDuration(Theme.animDuration)
    arrowRotation:SetOrigin("CENTER", 0, 0)
    arrowRotation:SetSmoothing("IN_OUT")

    arrowAnimGroup:SetScript("OnFinished", function() arrow:SetRotation(row._isOpen and 0 or -math.pi / 2) end)

    local SetBorderHover = NRSKNUI.Animations:CreateHoverColorAnimator(
        dropdownButton,
        function(r, g, b, a) dropdownButton:SetBackdropBorderColor(r, g, b, a) end,
        Theme.border,
        Theme.accent,
        Theme.animDuration
    )

    local function CloseDropdown(instant)
        if scrollHold then return end
        if not row._isOpen then return end

        row._isOpen = false

        if instant then
            dropdownList:SetHeight(1)
            dropdownList:Hide()

            if dropdownList._logicalParent then
                dropdownList:SetParent(dropdownList._logicalParent)
                dropdownList._logicalParent = nil
            end

            arrow:SetRotation(-math.pi / 2)
            animGroup:Stop()
            arrowAnimGroup:Stop()
        else
            startHeight = dropdownList:GetHeight()
            targetHeight = 1
            arrowAnimGroup:Stop()
            arrowRotation:SetRadians(-math.pi / 2)
            arrowAnimGroup:Play()
            animGroup:Stop()
            animGroup:Play()
        end

        if globalMouseChecker.activeDropdown == row then
            globalMouseChecker.activeDropdown = nil
            globalMouseChecker:Hide()
        end

        if GUIFrame.activeDropdown == dropdownButton then GUIFrame.activeDropdown = nil end
    end

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

        for _, btn in ipairs(row._itemButtons) do
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(btn._index - 1) * ITEM_HEIGHT)
            btn:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
        end
    end

    animGroup:SetScript("OnUpdate", function(anim)
        local progress = anim:GetProgress() or 0
        local smoothProgress = progress * progress * (3 - 2 * progress)
        local newHeight = startHeight + (targetHeight - startHeight) * smoothProgress
        dropdownList:SetHeight(newHeight)

        if row._isOpen and newHeight < targetHeight then dropdownList:SetClipsChildren(false) end
    end)

    animGroup:SetScript("OnFinished", function()
        dropdownList:SetHeight(targetHeight)

        if not row._isOpen then
            dropdownList:Hide()

            if dropdownList._logicalParent then
                dropdownList:SetParent(dropdownList._logicalParent)
                dropdownList._logicalParent = nil
            end
        else
            dropdownList:SetClipsChildren(true)
        end
    end)

    local function BuildFilteredKeys()
        wipe(filteredKeys)
        firstVisibleKey = nil

        local sortedKeys
        if row._orderedKeys then
            sortedKeys = row._orderedKeys
        else
            sortedKeys = {}
            for k in pairs(row._normalizedOptions) do table_insert(sortedKeys, k) end
            table_sort(sortedKeys, function(a, b) return tostring(a) < tostring(b) end)
        end

        local searchLower = strlower(tostring(searchText or ""))
        for _, key in ipairs(sortedKeys) do
            local displayText = row._normalizedOptions[key]
            local haystack = strlower(tostring(displayText or key or ""))
            if searchLower == "" or strfind(haystack, searchLower, 1, true) then
                table_insert(filteredKeys, key)
                if not firstVisibleKey then
                    firstVisibleKey = key
                end
            end
        end
    end

    local function SelectValue(value)
        row._currentValue = value
        if row._normalizedOptions[value] then
            row._selectedText:SetText(row._normalizedOptions[value])
        else
            row._selectedText:SetText(tostring(value))
        end

        local optionColor = row._optionColors and row._optionColors[value]
        if optionColor then
            row._selectedText:SetTextColor(optionColor.r or optionColor[1], optionColor.g or optionColor[2],
                optionColor.b or optionColor[3], 1)
        else
            row._selectedText:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        end

        if row._isFontPreview then
            local fontPath = NRSKNUI:GetFontPath(value)
            SafeApplyPreviewFont(row._selectedText, fontPath, FONT_PREVIEW_SIZE)
        end

        CloseDropdown()

        if row._callback then row._callback(value) end
    end

    local function CreateItemButtons()
        for _, btn in ipairs(row._itemButtons) do ReleaseItemButton(btn) end
        wipe(row._itemButtons)

        BuildFilteredKeys()

        for i, key in ipairs(filteredKeys) do
            local displayText = row._normalizedOptions[key]

            local btn = AcquireItemButton(scrollChild)
            btn._itemValue = key
            btn._itemText = displayText
            btn._index = i
            btn._text:SetText(displayText or key)

            if row._isFontPreview then
                local fontPath = NRSKNUI:GetFontPath(key)
                SafeApplyPreviewFont(btn._text, fontPath, FONT_PREVIEW_SIZE)
            end

            local optionColor = row._optionColors and row._optionColors[key]
            local function UpdateItemColor()
                local isSelected = row._currentValue == btn._itemValue
                if optionColor then
                    local alpha = isSelected and 1 or 0.7
                    btn._text:SetTextColor(optionColor.r or optionColor[1], optionColor.g or optionColor[2],
                        optionColor.b or optionColor[3], alpha)
                elseif isSelected then
                    btn._text:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                else
                    btn._text:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
                end
            end
            btn._updateColor = UpdateItemColor
            UpdateItemColor()

            local indicatorColor = row._optionIndicators and row._optionIndicators[key]
            if indicatorColor and btn._indicator then
                btn._indicator:SetTextColor(indicatorColor[1], indicatorColor[2], indicatorColor[3], 1)
                btn._indicator:Show()
            elseif btn._indicator then
                btn._indicator:Hide()
            end

            btn:SetScript("OnClick", function() SelectValue(btn._itemValue) end)

            btn:SetScript("OnEnter", function(self)
                self._hoverTarget = 1
                self._text:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3], 1)
                local tooltip = row._optionTooltips[self._itemValue]
                if tooltip then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:ClearLines()
                    GameTooltip:AddLine(self._itemText or self._itemValue, Theme.accent[1], Theme.accent[2],
                        Theme.accent[3], false)
                    GameTooltip:AddLine(tooltip, Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3],
                        true)
                    GameTooltip:Show()
                end
            end)

            btn:SetScript("OnLeave", function(self)
                self._hoverTarget = 0
                UpdateItemColor()
                GameTooltip:Hide()
            end)

            btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ITEM_HEIGHT)
            btn:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)

            table_insert(row._itemButtons, btn)
        end

        if emptyLabel then emptyLabel:SetShown(#filteredKeys == 0) end

        scrollChild:SetHeight(#filteredKeys > 0 and (#filteredKeys * ITEM_HEIGHT) or ITEM_HEIGHT)
        row._itemsCreated = true
    end

    if searchable then
        searchContainer = CreateFrame("Frame", nil, dropdownList, "BackdropTemplate")
        searchContainer:SetHeight(SEARCH_BOX_HEIGHT)
        searchContainer:SetPoint("TOPLEFT", dropdownList, "TOPLEFT", SEARCH_PADDING, -SEARCH_PADDING)
        searchContainer:SetPoint("TOPRIGHT", dropdownList, "TOPRIGHT", -SEARCH_INPUT_RIGHT_PADDING, -SEARCH_PADDING)
        searchContainer:SetBackdrop(STANDARD_BACKDROP)
        searchContainer:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
        searchContainer:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
        searchContainer:Hide()

        searchEditBox = CreateFrame("EditBox", nil, searchContainer)
        searchEditBox:SetPoint("TOPLEFT", searchContainer, "TOPLEFT", 6, -4)
        searchEditBox:SetPoint("BOTTOMRIGHT", searchContainer, "BOTTOMRIGHT", -6, 4)
        searchEditBox:SetFontObject("GameFontNormal")
        searchEditBox:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        searchEditBox:SetAutoFocus(false)
        searchEditBox:SetText("")

        searchEditBox:SetScript("OnTextChanged", function(self, userInput)
            if not userInput then return end
            searchText = self:GetText() or ""
            CreateItemButtons()
            UpdateScroll()
        end)

        searchEditBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            CloseDropdown()
        end)

        searchEditBox:SetScript("OnEnterPressed", function(self)
            if firstVisibleKey ~= nil then
                SelectValue(firstVisibleKey)
            else
                self:ClearFocus()
                CloseDropdown()
            end
        end)

        emptyLabel = scrollChild:CreateFontString(nil, "OVERLAY")
        emptyLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, 0)
        emptyLabel:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -8, 0)
        emptyLabel:SetHeight(ITEM_HEIGHT)
        emptyLabel:SetJustifyH("LEFT")
        NRSKNUI:ApplyThemeFont(emptyLabel, "normal")
        emptyLabel:SetText("No matches found")
        emptyLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        emptyLabel:Hide()
    end

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

    local function ToggleDropdown()
        if row._isOpen then
            CloseDropdown()
        else
            dropdownList._logicalParent = dropdownList:GetParent()
            local overlayParent = NRSKNUI.GUIOverlay or UIParent
            dropdownList:SetParent(overlayParent)
            dropdownList:SetFrameStrata("TOOLTIP")
            dropdownList:ClearAllPoints()
            dropdownList:SetPoint("TOPLEFT", dropdownButton, "BOTTOMLEFT", 0, -2)

            if searchable then
                searchText = ""
                if searchContainer then searchContainer:Show() end
                if searchEditBox then searchEditBox:SetText("") end
            end

            CreateItemButtons()
            local extraHeight = searchable and (SEARCH_BOX_HEIGHT + SEARCH_PADDING * 2) or 0
            local contentHeight = (#filteredKeys > 0 and (#filteredKeys * ITEM_HEIGHT) or ITEM_HEIGHT) + extraHeight
            local maxHeight = math_min(contentHeight, MAX_DROPDOWN_HEIGHT)
            local needsScrollbar = contentHeight > MAX_DROPDOWN_HEIGHT

            startHeight = 1
            targetHeight = maxHeight

            local buttonWidth = dropdownButton:GetWidth()
            if buttonWidth and buttonWidth > 0 then
                dropdownList:SetWidth(buttonWidth)
                scrollChild:SetWidth(buttonWidth - (needsScrollbar and 12 or 0))
            end

            if needsScrollbar then
                EnsureScrollbar()
                if scrollbar then
                    scrollbar:Show()
                    scrollbar:SetMinMaxValues(0, contentHeight - maxHeight)
                    scrollbar:SetValue(0)
                end
            elseif scrollbar then
                scrollbar:Hide()
            end

            dropdownList:SetHeight(targetHeight)
            dropdownList:Show()
            dropdownList:SetHeight(startHeight)

            row._isOpen = true

            if GUIFrame.activeDropdown and GUIFrame.activeDropdown ~= dropdownButton then
                if GUIFrame.activeDropdown.closeDropdown then GUIFrame.activeDropdown.closeDropdown() end
            end
            GUIFrame.activeDropdown = dropdownButton

            arrowAnimGroup:Stop()
            arrowRotation:SetRadians(math.pi / 2)
            arrowAnimGroup:Play()
            animGroup:Play()

            globalMouseChecker.activeDropdown = row
            globalMouseChecker.wasMouseDown = false
            globalMouseChecker:Show()

            if searchable and searchEditBox then
                C_Timer.After(0, function()
                    if row._isOpen and searchEditBox:IsShown() then
                        searchEditBox:SetFocus()
                        searchEditBox:HighlightText(0, 0)
                    end
                end)
            end
        end
    end

    dropdownButton:SetScript("OnClick", ToggleDropdown)
    dropdownButton:SetScript("OnEnter", function() SetBorderHover(true) end)
    dropdownButton:SetScript("OnLeave", function() SetBorderHover(false) end)

    if selected and row._normalizedOptions[selected] then
        row._selectedText:SetText(row._normalizedOptions[selected])
        row._currentValue = selected
        local optionColor = row._optionColors[selected]
        if optionColor then
            row._selectedText:SetTextColor(optionColor.r or optionColor[1], optionColor.g or optionColor[2],
                optionColor.b or optionColor[3], 1)
        end
        if row._isFontPreview then
            local fontPath = NRSKNUI:GetFontPath(selected)
            SafeApplyPreviewFont(row._selectedText, fontPath, FONT_PREVIEW_SIZE)
        end
    elseif selected ~= nil then
        row._selectedText:SetText(tostring(selected))
        row._currentValue = selected
        local optionColor = row._optionColors[selected]
        if optionColor then
            row._selectedText:SetTextColor(optionColor.r or optionColor[1], optionColor.g or optionColor[2],
                optionColor.b or optionColor[3], 1)
        end
        if row._isFontPreview then
            local fontPath = NRSKNUI:GetFontPath(selected)
            SafeApplyPreviewFont(row._selectedText, fontPath, FONT_PREVIEW_SIZE)
        end
    else
        row._selectedText:SetText("Select...")
        row._currentValue = nil
    end

    dropdownList:SetScript("OnHide", function()
        row._isOpen = false
        if searchable then
            searchText = ""

            if searchEditBox then
                searchEditBox:SetText("")
                searchEditBox:ClearFocus()
            end

            if searchContainer then searchContainer:Hide() end
            if emptyLabel then emptyLabel:Hide() end
        end
    end)

    dropdownButton:SetScript("OnHide", function()
        CloseDropdown(true)
        if GUIFrame.activeDropdown == dropdownButton then GUIFrame.activeDropdown = nil end
    end)

    row._closeDropdown = CloseDropdown
    row._createItemButtons = CreateItemButtons
    row._updateScroll = UpdateScroll
    row._dropdownList = dropdownList
    row._dropdownButton = dropdownButton

    row._scrollbar = scrollbar
    row._thumb = thumb
    row._thumbBorder = thumbBorder
    row._searchContainer = searchContainer
    row._searchEditBox = searchEditBox
    row._emptyLabel = emptyLabel

    dropdownButton.closeDropdown = CloseDropdown
    row.dropdown = dropdownButton

    Mixin(row, NUIDropdownMixin)

    self:RegisterSearchableWidget(row, labelText)
    ---@cast row NUIDropdown
    return row
end

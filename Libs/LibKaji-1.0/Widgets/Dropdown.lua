--[[
# Dropdown

* A dropdown with optional search, font/media preview and colorized options.
* The dropdown can be populated with:
* - a simple key -> text table
* - an array of strings
* - an array of {value/key, text, color?, tooltip?, indicator?}

* The value-changed callback fires only after the close animation finishes,
* so a callback that rebuilds the tab never interrupts the dropdown mid-close.

## Example

    row:Dropdown('Style', {
        value = db.Mode,
        options = ModeOptions,
        callback = function(v)
            db.Mode = v
        end
    })

    row:Dropdown('Font', {
        media = 'font',
        value = db.Font,
        callback = function(v)
            db.Font = v
        end
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local Animations = lib.Animations
local safecall = lib.safecall
local pixel = lib.Pixel
local LSM = LibStub("LibSharedMedia-3.0", true)

local tostring = tostring
local CreateFrame = CreateFrame
local type = type
local ipairs, pairs = ipairs, pairs
local wipe = wipe
local abs = math.abs
local max, min = math.max, math.min
local strlower, strfind = string.lower, string.find
local tinsert, tsort, tremove = table.insert, table.sort, table.remove
local IsMouseButtonDown = IsMouseButtonDown
local Mixin = Mixin
local pcall = pcall

local C_Timer = C_Timer
local UIParent = UIParent
local pi = math.pi
local GetAtlasInfo = C_Texture and C_Texture.GetAtlasInfo

local WIDGET_TYPE = "Dropdown"
local DROPDOWN_HEIGHT = 24
local ITEM_HEIGHT = 24
local MAX_DROPDOWN_HEIGHT = 400
local SEARCH_BOX_HEIGHT = 24
local SEARCH_PADDING = 6
local SEARCH_INPUT_RIGHT_PADDING = 16
local PREVIEW_SIZE = 12
local ARROW_SIZE = 16
local HOVER_DURATION = 0.12

local STANDARD_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }
local BORDER_ONLY_BACKDROP = { edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

local function ClearPreviewFont(gui, fontString)
    if not fontString then return end

    gui:ApplyFont(fontString, "normal")

    local path, size, flags = gui:GetThemeFont("normal")
    if path then pcall(fontString.SetFont, fontString, path, size, flags) end
end

local function ApplyPreviewFont(gui, fontString, fontPath, size)
    if not fontString then return end
    fontString:SetShadowColor(0, 0, 0, 0)

    local ok, valid
    if fontPath then
        ok, valid = pcall(fontString.SetFont, fontString, fontPath, size or PREVIEW_SIZE, "OUTLINE")
    end
    if not ok or not valid then
        ClearPreviewFont(gui, fontString)
    end
end

-- A media value can be an atlas name rather than a file path, and SetTexture cannot draw
-- an atlas, so the preview swatch picks the setter that matches what LSM handed back.
local function ApplyPreviewTexture(texture, value)
    if not texture then return end
    if type(value) == "string" and GetAtlasInfo and GetAtlasInfo(value) then
        texture:SetAtlas(value)
    else
        texture:SetTexture(value)
    end
end

-- One shared watcher closes whichever dropdown is open when you click outside it.
local mouseChecker = CreateFrame("Frame", nil, UIParent)
mouseChecker:Hide()
mouseChecker:SetScript("OnUpdate", function(self)
    local dropdown = self.activeDropdown
    if not dropdown then
        self:Hide()
        return
    end
    local isDown = IsMouseButtonDown("LeftButton")
    if self.wasMouseDown and not isDown then
        local list, button = dropdown._dropdownList, dropdown._dropdownButton
        if list and button and not list:IsMouseOver() and not button:IsMouseOver() then
            if dropdown._closeDropdown then dropdown._closeDropdown() end
        end
    end
    self.wasMouseDown = isDown
end)

-- Item button pool --

local function AcquireItemButton(gui, parent)
    local pool = gui._dropdownPool
    local btn = tremove(pool)
    if btn then
        btn:SetParent(parent)
        btn._hoverBg:SetAlpha(0)
        btn._hoverTarget = 0
        ClearPreviewFont(gui, btn._text)
        btn:Show()
        return btn
    end

    btn = CreateFrame("Button", nil, parent)
    pixel.SetPixelHeight(btn, ITEM_HEIGHT)

    local previewBar = btn:CreateTexture(nil, "BACKGROUND", nil, -2)
    previewBar:SetAllPoints()
    previewBar:Hide()
    btn._previewBar = previewBar

    local hoverBg = btn:CreateTexture(nil, "BACKGROUND")
    hoverBg:SetAllPoints()
    hoverBg:SetColorTexture(1, 1, 1, 0.05)
    hoverBg:SetAlpha(0)
    btn._hoverBg = hoverBg
    btn._hoverTarget = 0

    btn:SetScript("OnUpdate", function(self, elapsed)
        local current = self._hoverBg:GetAlpha()
        if abs(current - self._hoverTarget) > 0.01 then
            local speed = elapsed / HOVER_DURATION
            if self._hoverTarget > current then
                self._hoverBg:SetAlpha(min(current + speed, self._hoverTarget))
            else
                self._hoverBg:SetAlpha(max(current - speed, self._hoverTarget))
            end
        end
    end)

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(btnText, "LEFT", btn, "LEFT", 8, 0)
    pixel.SetPixelPoint(btnText, "RIGHT", btn, "RIGHT", -24, 0)
    btnText:SetJustifyH("LEFT")
    gui:ApplyFont(btnText, "normal")
    btn._text = btnText

    local indicator = btn:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(indicator, "RIGHT", btn, "RIGHT", -8, 0)
    gui:ApplyFont(indicator, "large")
    indicator:SetText("•")
    indicator:Hide()
    btn._indicator = indicator

    return btn
end

local function ReleaseItemButton(gui, btn)
    btn:Hide()
    -- Parked on the pool host rather than orphaned, matching Pool.lua.
    btn:SetParent(gui._poolHost)
    btn:SetScript("OnClick", nil)
    btn:SetScript("OnEnter", nil)
    btn:SetScript("OnLeave", nil)
    btn._hoverBg:SetAlpha(0)
    btn._hoverTarget = 0
    btn._itemValue = nil
    btn._itemText = nil
    btn._updateColor = nil
    btn._index = nil
    if btn._previewBar then btn._previewBar:Hide() end
    if btn._indicator then btn._indicator:Hide() end
    tinsert(gui._dropdownPool, btn)
end

-- Mixin (public API) --

---@class KajiGUIDropdownMixin : Frame
---@field gui KajiGUIInstance
---@field label FontString
---@field dropdown Button
---@field _mediaType? string
---@field _searchable boolean
---@field _isFontPreview boolean
---@field _isStatusbarPreview boolean
---@field _callback? fun(value: any)
---@field _currentValue any
---@field _multiSelect boolean
---@field _selectedSet? table<any, boolean>
---@field _isOpen boolean
---@field _itemButtons table[]
local DropdownMixin = {}

--- Normalizes an options table into keyed lookups + an ordered key list.
local function NormalizeOptions(row, options)
    row._normalizedOptions = {}
    row._optionColors = {}
    row._optionTooltips = {}
    row._optionIndicators = {}
    row._orderedKeys = nil
    if type(options) ~= "table" then return end

    if options[1] and type(options[1]) == "table" and (options[1].value or options[1].key) then
        row._orderedKeys = {}
        for _, opt in ipairs(options) do
            local optKey = opt.value or opt.key
            row._normalizedOptions[optKey] = opt.text
            if opt.color then row._optionColors[optKey] = opt.color end
            if opt.tooltip then row._optionTooltips[optKey] = opt.tooltip end
            if opt.indicator then row._optionIndicators[optKey] = opt.indicator end
            tinsert(row._orderedKeys, optKey)
        end
    elseif options[1] ~= nil and type(options[1]) == "string" then
        for _, v in ipairs(options) do row._normalizedOptions[v] = v end
    else
        for k, v in pairs(options) do row._normalizedOptions[k] = v end
    end
end

--- Rebuilds the membership lookup a multi-select uses, from its array of chosen values.
local function RebuildSelectedSet(row)
    local set = {}
    if row._multiSelect and type(row._currentValue) == "table" then
        for _, value in ipairs(row._currentValue) do set[value] = true end
    end
    row._selectedSet = set
end

--- True when a value is part of the current selection, whichever mode the dropdown is in.
local function IsValueSelected(row, value)
    if row._multiSelect then
        return row._selectedSet ~= nil and row._selectedSet[value] == true
    end
    return row._currentValue == value
end

---In multi-select mode `value` is an array of chosen values and is stored as given, so a caller keeps
---whatever order it built. Single-select is unchanged.
---@param value any
---@param silent? boolean
function DropdownMixin:SetValue(value, silent)
    self._currentValue = value
    RebuildSelectedSet(self)
    self._applySelected(value)
    for _, btn in ipairs(self._itemButtons) do
        if btn._updateColor then btn._updateColor() end
    end
    if not silent then safecall(self._callback, value) end
end

DropdownMixin.SetSelected = DropdownMixin.SetValue

function DropdownMixin:GetValue()
    return self._currentValue
end

DropdownMixin.GetSelected = DropdownMixin.GetValue

---@param enabled boolean
function DropdownMixin:SetEnabled(enabled)
    if enabled then
        self.dropdown:Enable()
        self.dropdown:SetAlpha(1)
        self.label:SetAlpha(1)
    else
        self.dropdown:Disable()
        self.dropdown:SetAlpha(0.5)
        self.label:SetAlpha(0.5)
        if self._isOpen then self._closeDropdown() end
    end
end

---@param newOptions table
function DropdownMixin:UpdateOptions(newOptions)
    NormalizeOptions(self, newOptions)
    if self._itemsCreated then
        self._createItemButtons()
        if self._isOpen then self._updateScroll() end
    end
end

DropdownMixin.SetOptions = DropdownMixin.UpdateOptions

-- Constructor --

---@class KajiGUIDropdownConfig
---@field options? table key→text, array of strings, or array of {value/key, text, color?, tooltip?, indicator?}
---@field media? "font"|"statusbar"|"sound"|"border"|"background" auto-populate + preview from LSM; explicit options are kept in front
---@field value? any
---@field callback? fun(value: any)
---@field searchable? boolean
---@field multiSelect? boolean toggle several options at once; value becomes an array and the list stays open on click
---@field tooltip? string

---@param parent Frame
---@param labelText string
---@param config KajiGUIDropdownConfig
---@return KajiGUIDropdown
---Media mode: a sorted option list straight from LSM, with any explicit options kept in
---front (e.g. an inherit sentinel like 'Global (...)'). HashTable is nil until something
---registers under the type, custom ones included.
---@param mediaType? string
---@param options? table
---@return table? options
local function ResolveMediaOptions(mediaType, options)
    local mediaHash = mediaType and LSM and LSM:HashTable(mediaType)
    if not mediaHash then return options end

    local names = {}
    for name in pairs(mediaHash) do names[#names + 1] = name end
    tsort(names, function(a, b) return strlower(a) < strlower(b) end)

    local merged = {}
    if options then
        for _, opt in ipairs(options) do merged[#merged + 1] = opt end
    end
    for _, name in ipairs(names) do merged[#merged + 1] = { value = name, text = name } end
    return merged
end

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local theme = gui.theme
    gui._dropdownPool = gui._dropdownPool or {}

    local row = CreateFrame("Frame", nil, gui._poolHost)
    pixel.SetPixelHeight(row, 34)
    row.gui = gui
    -- Defaults only; OnAcquire decides these per use.
    row._isFontPreview = false
    row._isStatusbarPreview = false
    row._searchable = false

    local label = row:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    gui:ApplyFont(label, "small")
    label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    row.label = label

    local dropdownButton = CreateFrame("Button", nil, row, "BackdropTemplate")
    pixel.SetPixelHeight(dropdownButton, DROPDOWN_HEIGHT)
    pixel.SetPixelPoint(dropdownButton, "TOPLEFT", row, "TOPLEFT", 0, -14)
    pixel.SetPixelPoint(dropdownButton, "TOPRIGHT", row, "TOPRIGHT", 0, -14)
    dropdownButton:SetBackdrop(STANDARD_BACKDROP)
    dropdownButton:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], 0.9)
    dropdownButton:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
    pixel.SetPixelSnap(dropdownButton)

    -- Preview bar behind the selected text (statusbar media mode).
    local selectedBar = dropdownButton:CreateTexture(nil, "BACKGROUND", nil, -1)
    pixel.SetPixelPoint(selectedBar, "TOPLEFT", dropdownButton, "TOPLEFT", 1, -1)
    pixel.SetPixelPoint(selectedBar, "BOTTOMRIGHT", dropdownButton, "BOTTOMRIGHT", -20, 1)
    pixel.SetPixelSnap(selectedBar)
    selectedBar:Hide()

    local selectedText = dropdownButton:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(selectedText, "LEFT", dropdownButton, "LEFT", theme.paddingSmall, 0)
    pixel.SetPixelPoint(selectedText, "RIGHT", dropdownButton, "RIGHT", -24, 0)
    selectedText:SetJustifyH("LEFT")
    gui:ApplyFont(selectedText, "normal")
    selectedText:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    dropdownButton.selectedText = selectedText
    row._selectedText = selectedText

    local arrow = dropdownButton:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelSize(arrow, ARROW_SIZE, ARROW_SIZE)
    pixel.SetPixelPoint(arrow, "RIGHT", dropdownButton, "RIGHT", -theme.paddingSmall, 0)
    arrow:SetTexture(theme.stepperTexture)
    arrow:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    pixel.SetPixelSnap(arrow)
    arrow:SetRotation(-pi / 2)
    dropdownButton.arrow = arrow

    NormalizeOptions(row, options)

    row._isOpen = false
    row._currentValue = selected
    row._itemButtons = {}
    row._itemsCreated = false

    local startHeight, targetHeight = 0, 0
    local scrollHold = false
    local filteredKeys = {}
    local searchText = ""
    local firstVisibleKey = nil

    local function ApplySelected(value)
        if row._multiSelect then
            -- Only a lone pick is named. Listing every one of them outgrew the button, and the label
            -- reshuffled itself as the user toggled things on and off, so past one they collapse.
            local count, firstName = 0, nil
            for _, key in ipairs(row._orderedKeys or {}) do
                if IsValueSelected(row, key) then
                    count = count + 1
                    firstName = firstName or row._normalizedOptions[key] or tostring(key)
                end
            end

            local text = "Select..."
            if count == 1 then
                text = firstName
            elseif count > 1 then
                text = "Multiple Selected"
            end

            selectedText:SetText(text)
            gui:ApplyFont(selectedText, "normal")
            selectedText:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            selectedBar:Hide()
            return
        end

        if row._normalizedOptions[value] then
            selectedText:SetText(row._normalizedOptions[value])
        else
            selectedText:SetText(value ~= nil and tostring(value) or "Select...")
        end

        local optionColor = row._optionColors and row._optionColors[value]
        if optionColor then
            selectedText:SetTextColor(optionColor.r or optionColor[1], optionColor.g or optionColor[2], optionColor.b or optionColor[3], 1)
        else
            selectedText:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        end

        -- Font and bar are independent: a statusbar dropdown recycled from a font one still
        -- needs the font put back, so neither preview may live in the other's else branch.
        if row._isFontPreview and value then
            ApplyPreviewFont(gui, selectedText, gui:ResolveMedia("font", value), PREVIEW_SIZE)
        else
            ClearPreviewFont(gui, selectedText)
        end

        if row._isStatusbarPreview and value then
            ApplyPreviewTexture(selectedBar, gui:ResolveMedia(row._mediaType, value))
            selectedBar:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.4)
            selectedBar:Show()
        else
            selectedBar:Hide()
        end
    end
    row._applySelected = ApplySelected

    local dropdownList = CreateFrame("Frame", nil, row, "BackdropTemplate")
    pixel.SetPixelHeight(dropdownList, 1)
    dropdownList:SetBackdrop(STANDARD_BACKDROP)
    dropdownList:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], 0.9)
    dropdownList:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
    dropdownList:SetFrameStrata("TOOLTIP")
    dropdownList:SetClipsChildren(true)
    dropdownList:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", nil, dropdownList)
    pixel.SetPixelPoint(scrollFrame, "TOPLEFT", dropdownList, "TOPLEFT", 0, 0)
    pixel.SetPixelPoint(scrollFrame, "BOTTOMRIGHT", dropdownList, "BOTTOMRIGHT", 0, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)

    local searchContainer, searchEditBox, emptyLabel
    local scrollbar, thumb, thumbBorder

    local function EnsureScrollbar()
        if scrollbar then return end
        scrollbar = CreateFrame("Slider", nil, dropdownList, "BackdropTemplate")
        pixel.SetPixelPoint(scrollbar, "TOPRIGHT", dropdownList, "TOPRIGHT", 0, 0)
        pixel.SetPixelPoint(scrollbar, "BOTTOMRIGHT", dropdownList, "BOTTOMRIGHT", 0, 0)
        pixel.SetPixelWidth(scrollbar, 12)
        scrollbar:SetBackdrop(STANDARD_BACKDROP)
        scrollbar:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
        scrollbar:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], 0.9)
        scrollbar:SetOrientation("VERTICAL")
        scrollbar:SetValueStep(pixel.GetMult())
        scrollbar:SetMinMaxValues(0, 100)
        scrollbar:SetValue(0)
        scrollbar:Hide()
        scrollbar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
        -- Snap scroll offsets to whole pixels; a fractional offset shifts the whole list off-grid.
        local isSnapping = false
        scrollbar:SetScript("OnValueChanged", function(bar, value)
            scrollFrame:SetVerticalScroll(pixel.ToPixelGrid(value))
            if isSnapping then return end
            local snappedValue = pixel.ToPixelGrid(value)
            if abs(value - snappedValue) > 0.001 then
                isSnapping = true
                bar:SetValue(snappedValue)
                isSnapping = false
            end
        end)
        scrollbar:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then scrollHold = true end end)
        scrollbar:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then C_Timer.After(0.1, function() scrollHold = false end) end
        end)

        thumb = scrollbar:GetThumbTexture()
        pixel.SetPixelSize(thumb, 12, 30)
        thumb:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.8)

        thumbBorder = CreateFrame("Frame", nil, scrollbar, "BackdropTemplate")
        pixel.SetPixelPoint(thumbBorder, "TOPLEFT", thumb, 0, 0)
        pixel.SetPixelPoint(thumbBorder, "BOTTOMRIGHT", thumb, 0, 0)
        thumbBorder:SetBackdrop(BORDER_ONLY_BACKDROP)
        thumbBorder:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
        thumb:HookScript("OnShow", function() thumbBorder:Show() end)
        thumb:HookScript("OnHide", function() thumbBorder:Hide() end)
    end

    local animGroup = dropdownList:CreateAnimationGroup()
    animGroup:CreateAnimation("Animation"):SetDuration(theme.animDuration)

    local arrowAnimGroup = arrow:CreateAnimationGroup()
    local arrowRotation = arrowAnimGroup:CreateAnimation("Rotation")
    arrowRotation:SetDuration(theme.animDuration)
    arrowRotation:SetOrigin("CENTER", 0, 0)
    arrowRotation:SetSmoothing("IN_OUT")
    arrowAnimGroup:SetScript("OnFinished", function() arrow:SetRotation(row._isOpen and 0 or -pi / 2) end)

    local SetBorderHover, SetBorderHoverSync = Animations:CreateHoverColorAnimator(dropdownButton,
        function(r, g, b, a) dropdownButton:SetBackdropBorderColor(r, g, b, a) end,
        theme.border, theme.accent, theme.animDuration)

    local function CloseDropdown(instant)
        if scrollHold then return end
        if not row._isOpen then return end
        row._isOpen = false

        if instant then
            pixel.SetPixelHeight(dropdownList, 1)
            dropdownList:Hide()
            if dropdownList._logicalParent then
                dropdownList:SetParent(dropdownList._logicalParent)
                dropdownList._logicalParent = nil
            end
            arrow:SetRotation(-pi / 2)
            animGroup:Stop()
            arrowAnimGroup:Stop()
        else
            startHeight = dropdownList:GetHeight()
            targetHeight = 1
            arrowAnimGroup:Stop()
            arrowRotation:SetRadians(-pi / 2)
            arrowAnimGroup:Play()
            animGroup:Stop()
            animGroup:Play()
        end

        if mouseChecker.activeDropdown == row then
            mouseChecker.activeDropdown = nil
            mouseChecker:Hide()
        end
        if gui._activeDropdown == dropdownButton then gui._activeDropdown = nil end
    end
    row._closeDropdown = CloseDropdown

    local function UpdateScroll()
        local contentHeight = scrollChild:GetHeight()
        local scrollFrameHeight = scrollFrame:GetHeight()
        local needsScrollbar = contentHeight > scrollFrameHeight and scrollFrameHeight > 0

        if needsScrollbar then
            EnsureScrollbar()
            scrollbar:Show()
            scrollbar:SetMinMaxValues(0, pixel.ToPixelGrid(contentHeight - scrollFrameHeight))
            scrollbar:SetValue(0)
            pixel.SetPixelPoint(scrollFrame, "BOTTOMRIGHT", dropdownList, "BOTTOMRIGHT", -11, 0)
        else
            if scrollbar then
                scrollbar:Hide()
                scrollbar:SetMinMaxValues(0, 0)
            end
            scrollFrame:SetVerticalScroll(0)
            pixel.SetPixelPoint(scrollFrame, "BOTTOMRIGHT", dropdownList, "BOTTOMRIGHT", 0, 0)
        end

        pixel.SetPixelWidth(scrollChild, scrollFrame:GetWidth())
        for _, btn in ipairs(row._itemButtons) do
            btn:ClearAllPoints()
            pixel.SetPixelPoint(btn, "TOPLEFT", scrollChild, "TOPLEFT", 0, -(btn._index - 1) * ITEM_HEIGHT)
            pixel.SetPixelPoint(btn, "RIGHT", scrollChild, "RIGHT", 0, 0)
        end
    end
    row._updateScroll = UpdateScroll

    animGroup:SetScript("OnUpdate", function(anim)
        local progress = anim:GetProgress() or 0
        local smooth = progress * progress * (3 - 2 * progress)
        local newHeight = startHeight + (targetHeight - startHeight) * smooth
        pixel.SetPixelHeight(dropdownList, newHeight)
        if row._isOpen and newHeight < targetHeight then dropdownList:SetClipsChildren(false) end
    end)

    -- Callback is deferred to here: firing it instantly lets it rebuild the dropdown mid-close.
    animGroup:SetScript("OnFinished", function()
        pixel.SetPixelHeight(dropdownList, targetHeight)
        if not row._isOpen then
            dropdownList:Hide()
            if dropdownList._logicalParent then
                dropdownList:SetParent(dropdownList._logicalParent)
                dropdownList._logicalParent = nil
            end
            if row._hasPending then
                local value = row._pendingValue
                row._hasPending, row._pendingValue = false, nil
                safecall(row._callback, value)
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
            for k in pairs(row._normalizedOptions) do tinsert(sortedKeys, k) end
            tsort(sortedKeys, function(a, b) return tostring(a) < tostring(b) end)
        end

        local searchLower = strlower(tostring(searchText or ""))
        for _, key in ipairs(sortedKeys) do
            local haystack = strlower(tostring(row._normalizedOptions[key] or key or ""))
            if searchLower == "" or strfind(haystack, searchLower, 1, true) then
                tinsert(filteredKeys, key)
                if not firstVisibleKey then firstVisibleKey = key end
            end
        end
    end

    local function SelectValue(value)
        if row._multiSelect then
            -- Toggling keeps the list open, so the callback fires now rather than being deferred to the
            -- close animation. A multi-select callback must therefore not rebuild its own widget.
            local values = type(row._currentValue) == "table" and row._currentValue or {}
            local removed = false

            for index, existing in ipairs(values) do
                if existing == value then
                    tremove(values, index)
                    removed = true
                    break
                end
            end
            if not removed then tinsert(values, value) end

            row._currentValue = values
            RebuildSelectedSet(row)
            ApplySelected(values)
            for _, btn in ipairs(row._itemButtons) do
                if btn._updateColor then btn._updateColor() end
            end

            safecall(row._callback, values)
            return
        end

        row._currentValue = value
        ApplySelected(value)
        row._pendingValue = value
        row._hasPending = true
        CloseDropdown()
    end

    local function CreateItemButtons()
        for _, btn in ipairs(row._itemButtons) do ReleaseItemButton(gui, btn) end
        wipe(row._itemButtons)

        BuildFilteredKeys()

        for i, key in ipairs(filteredKeys) do
            local displayText = row._normalizedOptions[key]
            local btn = AcquireItemButton(gui, scrollChild)
            btn._itemValue = key
            btn._itemText = displayText
            btn._index = i
            btn._text:SetText(displayText or key)

            -- Independent, not an if/elseif chain: a pooled button carries whichever preview the dropdown
            -- it last served applied, so each one has to be either set or cleared on every acquire.
            if row._isFontPreview then
                ApplyPreviewFont(gui, btn._text, gui:ResolveMedia("font", key), PREVIEW_SIZE)
            else
                ClearPreviewFont(gui, btn._text)
            end

            if row._isStatusbarPreview then
                ApplyPreviewTexture(btn._previewBar, gui:ResolveMedia(row._mediaType, key))
                btn._previewBar:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.4)
                btn._previewBar:Show()
            else
                btn._previewBar:Hide()
            end

            local optionColor = row._optionColors and row._optionColors[key]
            local function UpdateItemColor()
                local isSelected = IsValueSelected(row, btn._itemValue)
                if optionColor then
                    btn._text:SetTextColor(optionColor.r or optionColor[1], optionColor.g or optionColor[2], optionColor.b or optionColor[3], isSelected and 1 or 0.7)
                elseif isSelected then
                    btn._text:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
                else
                    btn._text:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
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
                self._text:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
                local tooltip = row._optionTooltips[self._itemValue]
                if tooltip then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:ClearLines()
                    GameTooltip:AddLine(self._itemText or self._itemValue, theme.accent[1], theme.accent[2], theme.accent[3], false)
                    GameTooltip:AddLine(tooltip, theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], true)
                    GameTooltip:Show()
                end
            end)
            btn:SetScript("OnLeave", function(self)
                self._hoverTarget = 0
                UpdateItemColor()
                GameTooltip:Hide()
            end)

            pixel.SetPixelPoint(btn, "TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ITEM_HEIGHT)
            pixel.SetPixelPoint(btn, "RIGHT", scrollChild, "RIGHT", 0, 0)
            tinsert(row._itemButtons, btn)
        end

        if emptyLabel then emptyLabel:SetShown(#filteredKeys == 0) end
        pixel.SetPixelHeight(scrollChild, #filteredKeys > 0 and (#filteredKeys * ITEM_HEIGHT) or ITEM_HEIGHT)
        row._itemsCreated = true
    end
    row._createItemButtons = CreateItemButtons

    -- Built unconditionally and shown only when the dropdown is searchable: creating it
    -- per config would leave a recycled dropdown without a search box.
    do
        searchContainer = CreateFrame("Frame", nil, dropdownList, "BackdropTemplate")
        pixel.SetPixelHeight(searchContainer, SEARCH_BOX_HEIGHT)
        pixel.SetPixelPoint(searchContainer, "TOPLEFT", dropdownList, "TOPLEFT", SEARCH_PADDING, -SEARCH_PADDING)
        pixel.SetPixelPoint(searchContainer, "TOPRIGHT", dropdownList, "TOPRIGHT", -SEARCH_INPUT_RIGHT_PADDING, -SEARCH_PADDING)
        searchContainer:SetBackdrop(STANDARD_BACKDROP)
        searchContainer:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], 0.9)
        searchContainer:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
        searchContainer:Hide()

        searchEditBox = CreateFrame("EditBox", nil, searchContainer)
        pixel.SetPixelPoint(searchEditBox, "TOPLEFT", searchContainer, "TOPLEFT", 6, -4)
        pixel.SetPixelPoint(searchEditBox, "BOTTOMRIGHT", searchContainer, "BOTTOMRIGHT", -6, 4)
        searchEditBox:SetFontObject("GameFontNormal")
        searchEditBox:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
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
        pixel.SetPixelPoint(emptyLabel, "TOPLEFT", scrollChild, "TOPLEFT", 8, 0)
        pixel.SetPixelPoint(emptyLabel, "TOPRIGHT", scrollChild, "TOPRIGHT", -8, 0)
        pixel.SetPixelHeight(emptyLabel, ITEM_HEIGHT)
        emptyLabel:SetJustifyH("LEFT")
        gui:ApplyFont(emptyLabel, "normal")
        emptyLabel:SetText("No matches found")
        emptyLabel:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
        emptyLabel:Hide()
    end

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        if scrollbar and scrollbar:IsShown() then
            local minVal, maxVal = scrollbar:GetMinMaxValues()
            scrollbar:SetValue(max(minVal, min(maxVal, scrollbar:GetValue() - (delta * ITEM_HEIGHT))))
        end
    end)

    local function ToggleDropdown()
        if row._isOpen then
            CloseDropdown()
            return
        end

        dropdownList._logicalParent = dropdownList:GetParent()
        dropdownList:SetParent(gui.overlay or UIParent)
        dropdownList:SetFrameStrata("TOOLTIP")
        dropdownList:ClearAllPoints()
        pixel.SetPixelPoint(dropdownList, "TOPLEFT", dropdownButton, "BOTTOMLEFT", 0, -2)

        if row._searchable then
            searchText = ""
            searchContainer:Show()
            searchEditBox:SetText("")
        end

        CreateItemButtons()
        local extraHeight = row._searchable and (SEARCH_BOX_HEIGHT + SEARCH_PADDING * 2) or 0
        local contentHeight = (#filteredKeys > 0 and (#filteredKeys * ITEM_HEIGHT) or ITEM_HEIGHT) + extraHeight
        local maxHeight = min(contentHeight, MAX_DROPDOWN_HEIGHT)
        local needsScrollbar = contentHeight > MAX_DROPDOWN_HEIGHT

        startHeight = 1
        targetHeight = maxHeight

        local buttonWidth = dropdownButton:GetWidth()
        if buttonWidth and buttonWidth > 0 then
            pixel.SetPixelWidth(dropdownList, buttonWidth)
            pixel.SetPixelWidth(scrollChild, buttonWidth - (needsScrollbar and 12 or 0))
        end

        if needsScrollbar then
            EnsureScrollbar()
            scrollbar:Show()
            scrollbar:SetMinMaxValues(0, contentHeight - maxHeight)
            scrollbar:SetValue(0)
        elseif scrollbar then
            scrollbar:Hide()
            scrollbar:SetMinMaxValues(0, 0)
        end

        -- A ScrollFrame keeps its offset when its scroll child shrinks, and a pooled dropdown
        -- carries that offset into its next life: one that was scrolled while holding a long list
        -- would open a short one scrolled clean past every item, showing an empty list.
        scrollFrame:SetVerticalScroll(0)

        pixel.SetPixelHeight(dropdownList, targetHeight)
        dropdownList:Show()
        pixel.SetPixelHeight(dropdownList, startHeight)
        row._isOpen = true

        if gui._activeDropdown and gui._activeDropdown ~= dropdownButton then
            if gui._activeDropdown.closeDropdown then gui._activeDropdown.closeDropdown() end
        end
        gui._activeDropdown = dropdownButton

        arrowAnimGroup:Stop()
        arrowRotation:SetRadians(pi / 2)
        arrowAnimGroup:Play()
        animGroup:Play()

        mouseChecker.activeDropdown = row
        mouseChecker.wasMouseDown = false
        mouseChecker:Show()

        if row._searchable then
            C_Timer.After(0, function()
                if row._isOpen and searchEditBox:IsShown() then
                    searchEditBox:SetFocus()
                    searchEditBox:HighlightText(0, 0)
                end
            end)
        end
    end

    dropdownButton:SetScript("OnClick", ToggleDropdown)
    dropdownButton:SetScript("OnEnter", function()
        SetBorderHover(true)
        if not row._isOpen then lib.ShowTooltip(row) end
    end)
    dropdownButton:SetScript("OnLeave", function()
        SetBorderHover(false)
        lib.HideTooltip()
    end)

    -- Re-anchors the list contents for the searchable / plain layouts. Called per acquire
    -- because the search strip changes where the scroll area starts.
    row._applySearchLayout = function()
        scrollFrame:ClearAllPoints()
        pixel.SetPixelPoint(scrollFrame, "TOPLEFT", dropdownList, "TOPLEFT", 0,
            row._searchable and -(SEARCH_BOX_HEIGHT + SEARCH_PADDING) or 0)
        pixel.SetPixelPoint(scrollFrame, "BOTTOMRIGHT", dropdownList, "BOTTOMRIGHT", 0, 0)
        searchContainer:Hide()
        if emptyLabel then emptyLabel:Hide() end
    end

    -- The placeholder is not a font name, and it is the one OnAcquire path that never
    -- reaches ApplySelected, so it restores the theme font itself.
    row._setSelectedPlaceholder = function()
        selectedText:SetText("Select...")
        gui:ApplyFont(selectedText, "normal")
    end

    dropdownList:SetScript("OnHide", function()
        row._isOpen = false
        searchText = ""
        searchEditBox:SetText("")
        searchEditBox:ClearFocus()
        searchContainer:Hide()
        if emptyLabel then emptyLabel:Hide() end
    end)

    dropdownButton:SetScript("OnHide", function()
        CloseDropdown(true)
        if gui._activeDropdown == dropdownButton then gui._activeDropdown = nil end
    end)

    dropdownButton.closeDropdown = CloseDropdown
    row._dropdownList = dropdownList
    row._dropdownButton = dropdownButton
    row.dropdown = dropdownButton
    row._selectedTextRegion = selectedText

    -- Dropdown paints its chrome directly rather than through lib.SetBackdrop, so the
    -- re-tint is written once here and replayed by UpdateColors.
    row._restyle = function()
        local active = row.gui.theme
        dropdownButton:SetBackdropColor(active.bgMedium[1], active.bgMedium[2], active.bgMedium[3], 0.9)
        dropdownButton:SetBackdropBorderColor(active.border[1], active.border[2], active.border[3], 1)
        dropdownList:SetBackdropColor(active.bgMedium[1], active.bgMedium[2], active.bgMedium[3], 0.9)
        dropdownList:SetBackdropBorderColor(active.border[1], active.border[2], active.border[3], 1)
        row.label:SetTextColor(active.textSecondary[1], active.textSecondary[2], active.textSecondary[3], 1)

        searchContainer:SetBackdropColor(active.bgDark[1], active.bgDark[2], active.bgDark[3], 0.9)
        searchContainer:SetBackdropBorderColor(active.border[1], active.border[2], active.border[3], 1)
        searchEditBox:SetTextColor(active.accent[1], active.accent[2], active.accent[3], 1)
        if emptyLabel then
            emptyLabel:SetTextColor(active.textSecondary[1], active.textSecondary[2], active.textSecondary[3], 1)
        end

        arrow:SetVertexColor(active.textSecondary[1], active.textSecondary[2], active.textSecondary[3], 1)
        SetBorderHoverSync(active.border[1], active.border[2], active.border[3], active.border[4] or 1)

        -- Repaint the selection so its own option color (or the accent default) follows.
        if row._currentValue ~= nil then row._applySelected(row._currentValue) end
    end

    ---Hands every live item button back to the shared pool.
    row._releaseItemButtons = function()
        for _, btn in ipairs(row._itemButtons) do ReleaseItemButton(row.gui, btn) end
        wipe(row._itemButtons)
        row._itemsCreated = false
    end

    return Mixin(row, DropdownMixin)
end)

function DropdownMixin:ReleaseItemButtons()
    self._releaseItemButtons()
end

function DropdownMixin:UpdateColors()
    self._restyle()
end

---@param parent Frame
---@param labelText? string
---@param config table
function DropdownMixin:OnAcquire(parent, labelText, config)
    local mediaType = config.media

    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelHeight(self, 34)

    self._mediaType = mediaType
    self._isFontPreview = mediaType == "font"
    -- Every media type that is not a font or a sound previews as a texture swatch, so
    -- custom types registered by the host (sparks, borders) get a preview for free.
    self._isStatusbarPreview = mediaType ~= nil and not self._isFontPreview and mediaType ~= "sound"
    self._searchable = config.searchable == true
    self._multiSelect = config.multiSelect == true

    self.label:SetText(labelText or "")
    lib.SetTooltip(self, self.gui, labelText, config.tooltip)

    NormalizeOptions(self, ResolveMediaOptions(mediaType, config.options))
    self._applySearchLayout()

    -- Seeded before the callback is attached, so filling in a recycled dropdown never
    -- looks like the user just picked something.
    self._callback = nil
    self._currentValue = config.value
    RebuildSelectedSet(self)
    if config.value ~= nil then
        self._applySelected(config.value)
    else
        self._setSelectedPlaceholder()
    end
    self._callback = config.callback

    self:SetEnabled(true)
    self:SetAlpha(1)
    self:UpdateColors()
    self:Show()

    self.gui:RegisterSearchableWidget(self, labelText)
end

function DropdownMixin:OnRelease()
    -- Closing first matters most: an open list is reparented to the overlay and is driven
    -- by the shared mouseChecker, which would otherwise keep poking a recycled widget.
    if self._closeDropdown then self._closeDropdown(true) end
    if mouseChecker.activeDropdown == self then
        mouseChecker.activeDropdown = nil
        mouseChecker:Hide()
    end
    if self.gui._activeDropdown == self._dropdownButton then
        self.gui._activeDropdown = nil
    end

    self:ReleaseItemButtons()

    self._callback = nil
    self._currentValue = nil
    self._multiSelect = false
    self._selectedSet = nil
    self._mediaType = nil
    self._hasPending, self._pendingValue = false, nil
    self.label:SetText("")
    lib.ClearTooltip(self)
end

---@class KajiGUIDropdown : KajiGUIDropdownMixin

---@param parent Frame
---@param labelText? string
---@param config? KajiGUIDropdownConfig
---@return KajiGUIDropdown
function InstanceMixin:CreateDropdown(parent, labelText, config)
    return self:BuildWidget(WIDGET_TYPE, parent, labelText, config)
end

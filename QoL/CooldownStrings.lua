-- NorskenUI namespace
local _, NRSKNUI = ...
local Theme = NRSKNUI.Theme

-- Check for addon object
if not NRSKNUI.Addon then
    error("CooldownStrings: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local CS = NRSKNUI.Addon:NewModule("CooldownStrings", "AceEvent-3.0")

-- Localization
local CreateFrame = CreateFrame
local _G = _G
local pairs = pairs
local ipairs = ipairs
local table_insert = table.insert
local wipe = wipe
local IsMouseButtonDown = IsMouseButtonDown
local tostring = tostring

-- Module variables
CS.attachedFrame = nil
CS.isShown = false
CS.selectedProfile = nil

-- Dropdown configuration constants
local DROPDOWN_HEIGHT = 24
local ITEM_HEIGHT = 24
local MAX_DROPDOWN_HEIGHT = 200
local ANIMATION_DURATION = 0.12
local ARROW_SIZE = 16
local ARROW_TEX = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\collapse.tga"

-- Cached backdrop tables
local CARD_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

-- Module init
function CS:OnInitialize()
    self.db = NRSKNUI.db.profile.Miscellaneous.CooldownStrings
    self:SetEnabledState(false)
end

-- Create the attached panel for CooldownViewerSettings
function CS:CreateFrame()
    if self.attachedFrame then return end

    -- Create main container frame
    local frame = CreateFrame("Frame", "NRSKNUI_CooldownStringsPanel", UIParent, "BackdropTemplate")
    frame:SetSize(280, 180)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)

    -- Card backdrop
    frame:SetBackdrop(CARD_BACKDROP)
    frame:SetBackdropColor(Theme.bgLight[1], Theme.bgLight[2], Theme.bgLight[3], Theme.bgLight[4])
    frame:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4])

    -- Header
    local headerHeight = 32
    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetHeight(headerHeight)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetBackdrop(CARD_BACKDROP)
    header:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])
    header:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4])

    -- Title text
    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetPoint("LEFT", header, "LEFT", Theme.paddingMedium, 0)
    NRSKNUI:ApplyThemeFont(title, "large")
    title:SetText("CDM Profile Strings")
    title:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    frame.titleText = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(14, 14)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -Theme.paddingMedium, 0)
    local closeTex = closeBtn:CreateTexture(nil, "ARTWORK")
    closeTex:SetAllPoints()
    closeTex:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomCrossv3.png")
    closeTex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    closeTex:SetRotation(math.rad(45))
    closeTex:SetTexelSnappingBias(0)
    closeTex:SetSnapToPixelGrid(true)
    closeBtn:SetNormalTexture(closeTex)

    -- BUtton scripts
    closeBtn:SetScript("OnEnter", function()
        closeTex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeTex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    end)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Content area
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", Theme.paddingMedium, -headerHeight - Theme.paddingMedium)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -Theme.paddingMedium, Theme.paddingMedium)

    -- Store references
    frame.header = header
    frame.content = content
    frame.closeBtn = closeBtn

    -- Initially hidden
    frame:Hide()

    self.attachedFrame = frame
    self:BuildUI()
end

-- Create a NorskenUI-styled dropdown for the panel
function CS:CreatePanelDropdown(parent, labelText, options, selected, callback)
    local rowHeight = 34
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
    dropdownButton:SetBackdrop(CARD_BACKDROP)
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

    -- State variables
    local isOpen = false
    local currentValue = selected
    local itemButtons = {}
    local itemsCreated = false
    local startHeight = 0
    local targetHeight = 0

    -- Dropdown list
    local dropdownList = CreateFrame("Frame", nil, row, "BackdropTemplate")
    dropdownList:SetHeight(1)
    dropdownList:SetBackdrop(CARD_BACKDROP)
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

    -- Animation group
    local animGroup = dropdownList:CreateAnimationGroup()
    local heightAnim = animGroup:CreateAnimation("Animation")
    heightAnim:SetDuration(ANIMATION_DURATION)

    local arrowAnimGroup = arrow:CreateAnimationGroup()
    local arrowRotation = arrowAnimGroup:CreateAnimation("Rotation")
    arrowRotation:SetDuration(ANIMATION_DURATION)
    arrowRotation:SetOrigin("CENTER", 0, 0)
    arrowRotation:SetSmoothing("IN_OUT")

    arrowAnimGroup:SetScript("OnFinished", function()
        arrow:SetRotation(isOpen and 0 or -math.pi / 2)
    end)

    -- Close dropdown function
    local function CloseDropdown(instant)
        if not isOpen then return end
        isOpen = false

        if instant then
            dropdownList:SetHeight(1)
            dropdownList:Hide()
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
    end

    -- Animation scripts
    animGroup:SetScript("OnUpdate", function(self)
        local progress = self:GetProgress() or 0
        local smoothProgress = progress * progress * (3 - 2 * progress)
        local newHeight = startHeight + (targetHeight - startHeight) * smoothProgress
        dropdownList:SetHeight(newHeight)
    end)

    animGroup:SetScript("OnFinished", function()
        dropdownList:SetHeight(targetHeight)
        if not isOpen then
            dropdownList:Hide()
        else
            dropdownList:SetClipsChildren(true)
        end
    end)

    -- Create item buttons
    local function CreateItemButtons()
        for _, btn in ipairs(itemButtons) do
            btn:Hide()
            btn:SetParent(nil)
        end
        wipe(itemButtons)

        local sortedKeys = {}
        for k in pairs(options) do
            table_insert(sortedKeys, k)
        end
        table.sort(sortedKeys, function(a, b)
            return tostring(a) < tostring(b)
        end)

        for i, key in ipairs(sortedKeys) do
            local displayText = options[key]

            local btn = CreateFrame("Button", nil, scrollChild)
            btn:SetHeight(ITEM_HEIGHT)
            btn._itemValue = key
            btn._itemText = displayText

            -- Hover background
            local hoverBg = btn:CreateTexture(nil, "BACKGROUND")
            hoverBg:SetAllPoints()
            hoverBg:SetColorTexture(Theme.accentHover[1], Theme.accentHover[2], Theme.accentHover[3], Theme.accentHover[4] or 0.25)
            hoverBg:Hide()
            btn._hoverBg = hoverBg

            -- Text
            local btnText = btn:CreateFontString(nil, "OVERLAY")
            btnText:SetPoint("LEFT", btn, "LEFT", 8, 0)
            btnText:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
            btnText:SetJustifyH("LEFT")
            NRSKNUI:ApplyThemeFont(btnText, "normal")
            btnText:SetText(displayText or key)
            btn._text = btnText

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

    -- Toggle dropdown
    local function ToggleDropdown()
        if isOpen then
            CloseDropdown()
        else
            if not itemsCreated then
                CreateItemButtons()
            end

            dropdownList:ClearAllPoints()
            dropdownList:SetPoint("TOPLEFT", dropdownButton, "BOTTOMLEFT", 0, -2)
            dropdownList:SetPoint("TOPRIGHT", dropdownButton, "BOTTOMRIGHT", 0, -2)

            local contentHeight = #itemButtons * ITEM_HEIGHT
            local maxHeight = math.min(contentHeight, MAX_DROPDOWN_HEIGHT)

            startHeight = 1
            targetHeight = maxHeight

            dropdownList:SetHeight(targetHeight)
            scrollChild:SetWidth(scrollFrame:GetWidth())
            dropdownList:Show()
            dropdownList:SetHeight(startHeight)

            isOpen = true

            arrowAnimGroup:Stop()
            arrowRotation:SetRadians(math.pi / 2)
            arrowAnimGroup:Play()
            animGroup:Play()
        end
    end

    -- Global mouse checker for closing dropdown
    local mouseChecker = CreateFrame("Frame", nil, UIParent)
    mouseChecker:Hide()

    mouseChecker:SetScript("OnUpdate", function(self)
        if not isOpen then
            self:Hide()
            return
        end

        local isDown = IsMouseButtonDown("LeftButton")
        if self.wasMouseDown and not isDown then
            if not dropdownList:IsMouseOver() and not dropdownButton:IsMouseOver() then
                CloseDropdown()
            end
        end
        self.wasMouseDown = isDown
    end)

    -- Button scripts
    dropdownButton:SetScript("OnClick", function()
        ToggleDropdown()
        if isOpen then
            mouseChecker.wasMouseDown = false
            mouseChecker:Show()
        end
    end)

    dropdownButton:SetScript("OnEnter", function()
        dropdownButton:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    end)

    dropdownButton:SetScript("OnLeave", function()
        dropdownButton:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    end)

    -- Set initial selected text
    if selected and options[selected] then
        selectedText:SetText(options[selected])
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
    end)

    -- Public API
    function row:SetValue(value, silent)
        currentValue = value
        if options[value] then
            selectedText:SetText(options[value])
        else
            selectedText:SetText(tostring(value))
        end

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

    function row:GetValue()
        return currentValue
    end

    function row:UpdateOptions(newOptions)
        options = newOptions
        itemsCreated = false
        wipe(itemButtons)

        -- Update current selection text
        if currentValue and options[currentValue] then
            selectedText:SetText(options[currentValue])
        elseif not currentValue or not options[currentValue] then
            -- Select first option
            for k, v in pairs(options) do
                currentValue = k
                selectedText:SetText(v)
                break
            end
            if not currentValue then
                selectedText:SetText("No profiles")
            end
        end

        if callback and currentValue then
            callback(currentValue)
        end
    end

    row.dropdown = dropdownButton
    return row
end

-- Build the UI components
function CS:BuildUI()
    if not self.attachedFrame then return end
    local content = self.attachedFrame.content
    local db = self.db

    -- Clear existing content
    for _, child in ipairs({ content:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    local yOffset = 0

    -- Build profile options for dropdown
    local profileOptions = {}
    local profiles = db.Profiles or {}
    for name, _ in pairs(profiles) do
        profileOptions[name] = name
    end

    -- Create styled dropdown
    local dropdownRow = self:CreatePanelDropdown(content, "Select Profile", profileOptions, self.selectedProfile,
        function(value)
            self.selectedProfile = value
            self:UpdateEditBox()
        end)
    dropdownRow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
    dropdownRow:SetPoint("RIGHT", content, "RIGHT", 0, 0)

    self.dropdownRow = dropdownRow

    -- Select first profile if none selected
    if not self.selectedProfile then
        for name, _ in pairs(profiles) do
            self.selectedProfile = name
            dropdownRow:SetValue(name, true)
            break
        end
    end

    yOffset = yOffset + 42

    -- Edit box label
    local editLabel = content:CreateFontString(nil, "OVERLAY")
    editLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
    NRSKNUI:ApplyThemeFont(editLabel, "small")
    editLabel:SetText("Copy String (read-only):")
    editLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)

    yOffset = yOffset + 16

    -- Edit box background
    local editBg = CreateFrame("Frame", nil, content, "BackdropTemplate")
    editBg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
    editBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    editBg:SetBackdrop(CARD_BACKDROP)
    editBg:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
    editBg:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    -- Border animation state
    local borderR, borderG, borderB = Theme.border[1], Theme.border[2], Theme.border[3]
    local borderAnimGroup = editBg:CreateAnimationGroup()
    local borderAnim = borderAnimGroup:CreateAnimation("Animation")
    borderAnim:SetDuration(0.18)

    local borderColorFrom = {}
    local borderColorTo = {}

    local function AnimateBorder(toAccent)
        borderAnimGroup:Stop()
        borderColorFrom.r = borderR
        borderColorFrom.g = borderG
        borderColorFrom.b = borderB

        if toAccent then
            borderColorTo.r = Theme.accent[1]
            borderColorTo.g = Theme.accent[2]
            borderColorTo.b = Theme.accent[3]
        else
            borderColorTo.r = Theme.border[1]
            borderColorTo.g = Theme.border[2]
            borderColorTo.b = Theme.border[3]
        end
        borderAnimGroup:Play()
    end

    borderAnimGroup:SetScript("OnUpdate", function(self)
        local progress = self:GetProgress() or 0
        local r = borderColorFrom.r + (borderColorTo.r - borderColorFrom.r) * progress
        local g = borderColorFrom.g + (borderColorTo.g - borderColorFrom.g) * progress
        local b = borderColorFrom.b + (borderColorTo.b - borderColorFrom.b) * progress
        editBg:SetBackdropBorderColor(r, g, b, 1)
        borderR, borderG, borderB = r, g, b
    end)

    borderAnimGroup:SetScript("OnFinished", function()
        editBg:SetBackdropBorderColor(borderColorTo.r, borderColorTo.g, borderColorTo.b, 1)
        borderR, borderG, borderB = borderColorTo.r, borderColorTo.g, borderColorTo.b
    end)

    -- Scroll frame for edit box
    local scrollFrame = CreateFrame("ScrollFrame", nil, editBg)
    scrollFrame:SetPoint("TOPLEFT", editBg, "TOPLEFT", 6, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", editBg, "BOTTOMRIGHT", -6, 4)

    -- Edit box
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    NRSKNUI:ApplyThemeFont(editBox, "normal")
    editBox:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    editBox:SetPoint("TOPLEFT", 0, 0)
    editBox:SetPoint("TOPRIGHT", 0, 0)
    editBox:EnableMouse(true)
    scrollFrame:SetScrollChild(editBox)

    -- Set width after scroll child is set
    editBox:SetWidth(scrollFrame:GetWidth() > 0 and scrollFrame:GetWidth() or 200)

    -- Make read-only: prevent text changes
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local profiles = db.Profiles or {}
            if CS.selectedProfile and profiles[CS.selectedProfile] then
                self:SetText(profiles[CS.selectedProfile].String or "")
            end
        end
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- Select all on click for easy copying
    editBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
        editBg:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        borderR, borderG, borderB = Theme.accent[1], Theme.accent[2], Theme.accent[3]
    end)

    editBox:SetScript("OnEditFocusLost", function(self)
        editBg:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
        borderR, borderG, borderB = Theme.border[1], Theme.border[2], Theme.border[3]
    end)

    -- Hover animation on editbox
    editBox:SetScript("OnEnter", function(self)
        if not self:HasFocus() then
            AnimateBorder(true)
        end
    end)

    editBox:SetScript("OnLeave", function(self)
        if not self:HasFocus() then
            AnimateBorder(false)
        end
    end)

    -- Make entire container clickable to focus editbox
    editBg:EnableMouse(true)
    editBg:SetScript("OnMouseDown", function()
        editBox:SetFocus()
    end)
    editBg:SetScript("OnEnter", function()
        if not editBox:HasFocus() then
            AnimateBorder(true)
        end
    end)
    editBg:SetScript("OnLeave", function()
        if not editBox:HasFocus() then
            AnimateBorder(false)
        end
    end)

    -- Make scroll frame clickable to focus editbox
    scrollFrame:EnableMouse(true)
    scrollFrame:SetScript("OnMouseDown", function()
        editBox:SetFocus()
    end)

    self.editBox = editBox
    self.scrollFrame = scrollFrame

    -- Update UI based on current selection
    self:UpdateEditBox()
end

-- Update the dropdown options
function CS:UpdateDropdown()
    if not self.dropdownRow then return end

    local db = self.db
    local profiles = db.Profiles or {}

    -- Build new options
    local profileOptions = {}
    for name, _ in pairs(profiles) do
        profileOptions[name] = name
    end

    -- Update the dropdown
    self.dropdownRow:UpdateOptions(profileOptions)

    -- Update selected profile reference
    if self.dropdownRow.GetValue then
        self.selectedProfile = self.dropdownRow:GetValue()
    end
end

-- Update the edit box with selected profile's string
function CS:UpdateEditBox()
    if not self.editBox then return end

    local db = self.db
    local profiles = db.Profiles or {}

    if self.selectedProfile and profiles[self.selectedProfile] then
        self.editBox:SetText(profiles[self.selectedProfile].String or "")
        self.editBox:SetCursorPosition(0)
    else
        self.editBox:SetText("")
    end
end

-- Position the frame next to CooldownViewerSettings
function CS:PositionFrame()
    if not self.attachedFrame then return end

    local cdmFrame = _G["CooldownViewerSettings"]
    if cdmFrame and cdmFrame:IsShown() then
        self.attachedFrame:ClearAllPoints()
        self.attachedFrame:SetPoint("TOPLEFT", cdmFrame, "BOTTOMLEFT", 1, -2)
    end
end

-- Hook into CooldownViewerSettings show/hide
function CS:HookCDMFrame()
    local cdmFrame = _G["CooldownViewerSettings"]
    if not cdmFrame then
        -- Frame not available yet, try again later
        C_Timer.After(1, function()
            self:HookCDMFrame()
        end)
        return
    end

    -- Hook OnShow
    cdmFrame:HookScript("OnShow", function()
        if CS.db.Enabled then
            CS:ShowFrame()
        end
    end)

    -- Hook OnHide
    cdmFrame:HookScript("OnHide", function()
        if CS.attachedFrame then
            CS.attachedFrame:Hide()
        end
    end)
end

-- Show the attached frame
function CS:ShowFrame()
    if not self.attachedFrame then
        self:CreateFrame()
    end

    self:PositionFrame()
    self:UpdateDropdown()
    self:UpdateEditBox()
    self.attachedFrame:Show()
    self.isShown = true
end

-- Hide the attached frame
function CS:HideFrame()
    if self.attachedFrame then
        self.attachedFrame:Hide()
    end
    self.isShown = false
end

-- Refresh the panel, called from GUI when profiles change
function CS:RefreshPanel()
    if not self.attachedFrame or not self.attachedFrame:IsShown() then return end

    -- Re-validate selected profile
    local db = self.db
    local profiles = db.Profiles or {}
    if self.selectedProfile and not profiles[self.selectedProfile] then
        self.selectedProfile = nil
        for name, _ in pairs(profiles) do
            self.selectedProfile = name
            break
        end
    end

    self:UpdateDropdown()
    self:UpdateEditBox()
end

-- Module OnEnable
function CS:OnEnable()
    if not self.db.Enabled then return end

    self:CreateFrame()
    self:HookCDMFrame()

    -- If CDM frame is already open, show our frame
    local cdmFrame = _G["CooldownViewerSettings"]
    if cdmFrame and cdmFrame:IsShown() then
        self:ShowFrame()
    end
end

-- Module OnDisable
function CS:OnDisable()
    self:HideFrame()
end

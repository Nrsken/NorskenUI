-- NorskenUI namespace
local _, NRSKNUI = ...

-- Localization
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local pairs = pairs
local ipairs = ipairs
local GetCursorPosition = GetCursorPosition
local SetCursor = SetCursor
local IsShiftKeyDown = IsShiftKeyDown
local tonumber = tonumber
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT
local UIParent = UIParent

-- EditMode module
local EditMode = {}
NRSKNUI.EditMode = EditMode

-- State
EditMode.isActive = false
EditMode.registeredElements = {}
EditMode.overlayFrames = {}
EditMode.selectedElementKey = nil
EditMode.nudgeFrame = nil
EditMode.isShiftFaded = false

-- Constants
local BORDER_SIZE = 2
local FILL_ALPHA = 0.25
local TEXT_FONT_SIZE = 14
local SHIFT_FADE_ALPHA = 0.1

-- Register a moveable UI element
-- Define the registration config
--[[
Usage example:
local config = {
    key = "PetTexts",
    displayName = "PET TEXTS",
    frame = self.frame,
    -- getPosition must be a function that returns the table
    getPosition = function()
        return self.db.Position
    end,
    -- setPosition must be a function that saves the data and moves the frame
    setPosition = function(pos)
        self.db.Position.AnchorFrom = pos.AnchorFrom
        self.db.Position.AnchorTo = pos.AnchorTo
        self.db.Position.XOffset = pos.XOffset
        self.db.Position.YOffset = pos.YOffset

        self.frame:ClearAllPoints()
        self.frame:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset, pos.YOffset)
    end,
    -- OPTIONAL: getParentFrame returns the frame this element is anchored to
    -- If not provided, defaults to UIParent. Required for correct drag behavior
    -- when anchored to frames other than UIParent
    getParentFrame = function()
        return _G[self.db.ParentFrame] or UIParent
    end,
    -- OPTIONAL: guiPath for "Open Settings" button navigation
    -- This is the sidebar item ID from SidebarConfig, for example "combatTimer", "Minimap", "ActionBars")
    guiPath = "combatTimer",
}
NRSKNUI.EditMode:RegisterElement(config)
--]]
function EditMode:RegisterElement(config)
    if not config or not config.key then return end
    if not config.frame and not config.frameName then return end
    if not config.getPosition or not config.setPosition then return end

    self.registeredElements[config.key] = {
        key = config.key,
        displayName = config.displayName or config.key,
        frame = config.frame,
        frameName = config.frameName,
        getPosition = config.getPosition,
        setPosition = config.setPosition,
        getParentFrame = config.getParentFrame,
        guiPath = config.guiPath,
        guiContext = config.guiContext, -- Specific item to select in the GUI, using this for actionbars and details backdrops
    }

    -- If edit mode is already active, create overlay for this element
    if self.isActive then self:CreateOverlayForElement(config.key) end
end

-- Remove an element from edit mode
function EditMode:UnregisterElement(key)
    if not key then return end

    -- Remove overlay if it exists
    if self.overlayFrames[key] then
        self.overlayFrames[key]:Hide()
        self.overlayFrames[key] = nil
    end
    self.registeredElements[key] = nil
end

-- Resolve frame reference for an element
function EditMode:GetElementFrame(element)
    if element.frame then
        return element.frame
    elseif element.frameName then
        return _G[element.frameName]
    end
    return nil
end

-- Create a themed overlay frame for an element
function EditMode:CreateOverlayFrame(element)
    local targetFrame = self:GetElementFrame(element)
    if not targetFrame then return nil end

    local Theme = NRSKNUI.Theme
    local accent = Theme.accent or { 0.898, 0.063, 0.224, 1 }

    -- Create overlay frame
    local overlay = CreateFrame("Frame", "NRSKNUI_EditMode_" .. element.key, UIParent, "BackdropTemplate")
    overlay:SetFrameStrata("TOOLTIP")
    overlay:SetFrameLevel(1000)

    -- Set backdrop with border
    overlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = BORDER_SIZE,
        insets = { left = BORDER_SIZE, right = BORDER_SIZE, top = BORDER_SIZE, bottom = BORDER_SIZE },
    })

    -- Apply colors
    overlay:SetBackdropColor(accent[1], accent[2], accent[3], FILL_ALPHA)
    overlay:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)

    -- Create identifier text
    local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    text:SetText(element.displayName)
    text:SetFont(NRSKNUI.FONT or STANDARD_TEXT_FONT, TEXT_FONT_SIZE, "OUTLINE")
    text:SetShadowOffset(0, 0)
    text:SetShadowColor(0, 0, 0, 0)
    text:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.2)
    overlay.text = text

    -- Store element reference
    overlay.element = element

    -- Setup drag handling
    self:SetupDragHandlers(overlay, element)

    return overlay
end

-- Position overlay to match target frame
function EditMode:UpdateOverlayPosition(overlay)
    local element = overlay.element
    local targetFrame = self:GetElementFrame(element)

    if not targetFrame then
        overlay:Hide()
        return
    end

    -- Match target frame size and position
    overlay:ClearAllPoints()
    overlay:SetAllPoints(targetFrame)
    overlay:Show()
end

-- Create overlay for a specific element
function EditMode:CreateOverlayForElement(key)
    local element = self.registeredElements[key]
    if not element then return end

    -- Don't recreate if already exists
    if self.overlayFrames[key] then
        self:UpdateOverlayPosition(self.overlayFrames[key])
        return
    end

    local overlay = self:CreateOverlayFrame(element)
    if overlay then
        self.overlayFrames[key] = overlay
        self:UpdateOverlayPosition(overlay)
    end
end

-- Setup mouse drag behavior for overlay
function EditMode:SetupDragHandlers(overlay, element)
    overlay:EnableMouse(true)
    overlay:SetMovable(true)
    overlay:RegisterForDrag("LeftButton")

    local isDragging = false
    local didDrag = false
    local startX, startY = 0, 0
    local frameStartX, frameStartY = 0, 0

    overlay:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end

        local targetFrame = EditMode:GetElementFrame(element)
        if not targetFrame then return end

        isDragging = true
        didDrag = true

        -- Get cursor start position
        local scale = UIParent:GetEffectiveScale()
        startX, startY = GetCursorPosition()
        startX, startY = startX / scale, startY / scale

        -- Get frame start position
        local left, bottom, width, height = targetFrame:GetRect()
        if left and bottom and width and height then
            frameStartX = left + width / 2
            frameStartY = bottom + height / 2
        end

        -- Visual feedback
        self:SetAlpha(0.7)
    end)

    overlay:SetScript("OnDragStop", function(self)
        if not isDragging then return end
        isDragging = false
        self:SetAlpha(1)

        local targetFrame = EditMode:GetElementFrame(element)
        if not targetFrame then return end

        -- Get the current position/anchor settings from the module's DB
        local currentPos = element.getPosition()
        local anchorFrom = currentPos.AnchorFrom or "CENTER"
        local anchorTo = currentPos.AnchorTo or "CENTER"

        -- Get the parent frame
        local parentFrame = UIParent
        if element.getParentFrame then
            parentFrame = element.getParentFrame() or UIParent
        end

        -- Calculate cursor delta
        local scale = UIParent:GetEffectiveScale()
        local curX, curY = GetCursorPosition()
        curX, curY = curX / scale, curY / scale

        local deltaX = curX - startX
        local deltaY = curY - startY

        -- Calculate the new center based on movement
        local newCenterX = frameStartX + deltaX
        local newCenterY = frameStartY + deltaY

        -- Get parent frame position and dimensions for offset calculation
        local parentLeft, parentBottom, parentWidth, parentHeight = parentFrame:GetRect()
        if not parentLeft then
            parentLeft, parentBottom = 0, 0
            parentWidth, parentHeight = UIParent:GetWidth(), UIParent:GetHeight()
        end

        local finalX, finalY

        -- Horizontal Calculation
        if anchorTo:find("LEFT") then
            finalX = newCenterX - (targetFrame:GetWidth() / 2) - parentLeft
        elseif anchorTo:find("RIGHT") then
            finalX = newCenterX + (targetFrame:GetWidth() / 2) - (parentLeft + parentWidth)
        else -- CENTER
            finalX = newCenterX - (parentLeft + parentWidth / 2)
        end

        -- Vertical Calculation
        if anchorTo:find("TOP") then
            finalY = newCenterY + (targetFrame:GetHeight() / 2) - (parentBottom + parentHeight)
        elseif anchorTo:find("BOTTOM") then
            finalY = newCenterY - (targetFrame:GetHeight() / 2) - parentBottom
        else -- CENTER
            finalY = newCenterY - (parentBottom + parentHeight / 2)
        end

        -- Save using the ORIGINAL anchors, edit mode does not change anchor points
        -- That is all the GUI and is why we have a open settings button on the nudge tool
        local newPos = {
            AnchorFrom = anchorFrom,
            AnchorTo = anchorTo,
            XOffset = finalX,
            YOffset = finalY,
        }

        element.setPosition(newPos)
        C_Timer.After(0, function()
            EditMode:UpdateOverlayPosition(self)

            -- Select the dragged element in the nudge tool
            EditMode:SelectElement(element.key)

            -- Refresh GUI if open so position values update
            if NRSKNUI.GUIFrame and NRSKNUI.GUIFrame:IsShown() then
                NRSKNUI.GUIFrame:RefreshContent()
            end
        end)
    end)

    -- Update position while dragging
    overlay:SetScript("OnUpdate", function(self)
        if not isDragging then return end

        local targetFrame = EditMode:GetElementFrame(element)
        if not targetFrame then return end

        local scale = UIParent:GetEffectiveScale()
        local curX, curY = GetCursorPosition()
        curX, curY = curX / scale, curY / scale
        local deltaX = curX - startX
        local deltaY = curY - startY

        -- Move visually using BOTTOMLEFT as a screen-coordinate proxy
        targetFrame:ClearAllPoints()
        targetFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", frameStartX + deltaX, frameStartY + deltaY)

        self:ClearAllPoints()
        self:SetAllPoints(targetFrame)
    end)

    -- Cursor changes
    overlay:SetScript("OnEnter", function(self) SetCursor("Interface\\CURSOR\\UI-Cursor-Move") end)
    overlay:SetScript("OnLeave", function(self) SetCursor(nil) end)

    -- Reset drag flag on mouse down
    overlay:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            didDrag = false
        end
    end)

    -- Click to select for nudge tool (only if we didn't drag)
    overlay:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and not didDrag then
            EditMode:SelectElement(element.key)
        end
    end)
end

-- Activate edit mode
function EditMode:Enter()
    if self.isActive then return end
    if InCombatLockdown() then
        NRSKNUI:Print("Cannot enter edit mode during combat.")
        return
    end

    self.isActive = true

    -- Create overlays for all registered elements
    for key, element in pairs(self.registeredElements) do
        self:CreateOverlayForElement(key)
    end

    self:ShowNudgeFrame()
    if NRSKNUI.PreviewManager then NRSKNUI.PreviewManager:SetEditModeActive(true) end
    self:SetupEscapeHandler()
    self:SetupShiftHandler()
    self:SetupCombatHandler()
    NRSKNUI:Print(
        "Edit Mode |cff00ff00enabled|r. Drag elements to reposition. Hold Shift to see through overlay. Press ESC or type /nui lock to exit.")
end

-- Deactivate edit mode
function EditMode:Exit()
    if not self.isActive then return end
    self.isActive = false
    -- Hide nudge frame
    self:HideNudgeFrame()
    -- Notify PreviewManager that edit mode is inactive
    if NRSKNUI.PreviewManager then
        NRSKNUI.PreviewManager:SetEditModeActive(false)
    end
    -- Hide and destroy all overlays
    for key, overlay in pairs(self.overlayFrames) do
        if overlay then
            overlay:Hide()
        end
    end
    self.overlayFrames = {}
    self:RemoveEscapeHandler()
    self:RemoveShiftHandler()
    self:RemoveCombatHandler()
    NRSKNUI:Print("Edit Mode |cffff0000disabled|r.")
end

-- Toggle edit mode on/off
function EditMode:Toggle()
    if self.isActive then
        self:Exit()
    else
        self:Enter()
    end
end

-- Check if edit mode is active
function EditMode:IsActive()
    return self.isActive
end

-- Register ESC key to exit edit mode
function EditMode:SetupEscapeHandler()
    if self.escapeFrame then return end

    self.escapeFrame = CreateFrame("Frame", "NRSKNUI_EditModeEscape", UIParent)
    self.escapeFrame:EnableKeyboard(true)
    self.escapeFrame:SetPropagateKeyboardInput(true)

    self.escapeFrame:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then
            self.escapeFrame:SetPropagateKeyboardInput(false)
            EditMode:Exit()
        end
    end)
end

-- Unregister ESC handler
function EditMode:RemoveEscapeHandler()
    if self.escapeFrame then
        self.escapeFrame:SetScript("OnKeyDown", nil)
        self.escapeFrame:EnableKeyboard(false)
        self.escapeFrame:Hide()
        self.escapeFrame = nil
    end
end

-- Setup Shift key handler for fading selected overlay
function EditMode:SetupShiftHandler()
    if self.shiftFrame then return end
    self.shiftFrame = CreateFrame("Frame", "NRSKNUI_EditModeShift", UIParent)
    local wasShiftDown = false
    self.shiftFrame:SetScript("OnUpdate", function()
        if not EditMode.isActive then return end
        local isShiftDown = IsShiftKeyDown()

        -- Detect state change
        if isShiftDown and not wasShiftDown then
            EditMode:ApplyShiftFade(true)
        elseif not isShiftDown and wasShiftDown then
            EditMode:ApplyShiftFade(false)
        end

        wasShiftDown = isShiftDown
    end)
end

-- Remove Shift key handler
function EditMode:RemoveShiftHandler()
    if self.shiftFrame then
        self.shiftFrame:SetScript("OnUpdate", nil)
        self.shiftFrame:Hide()
        self.shiftFrame = nil
    end
    -- Ensure we restore alpha if edit mode is closed while Shift is held
    if self.isShiftFaded then
        self:ApplyShiftFade(false)
    end
end

-- Apply or remove Shift fade effect on selected overlay
function EditMode:ApplyShiftFade(fade)
    self.isShiftFaded = fade

    -- Only affect the selected element
    if not self.selectedElementKey then return end

    local overlay = self.overlayFrames[self.selectedElementKey]
    if not overlay then return end
    local Theme = NRSKNUI.Theme
    local accent = Theme.accent or { 0.898, 0.063, 0.224, 1 }

    if fade then
        -- Fade to very low alpha
        overlay:SetBackdropColor(accent[1], accent[2], accent[3], SHIFT_FADE_ALPHA * FILL_ALPHA)
        overlay:SetBackdropBorderColor(1, 1, 1, SHIFT_FADE_ALPHA)
        if overlay.text then
            overlay.text:SetAlpha(SHIFT_FADE_ALPHA)
        end
    else
        -- Restore normal alpha
        overlay:SetBackdropColor(accent[1], accent[2], accent[3], FILL_ALPHA)
        overlay:SetBackdropBorderColor(1, 1, 1, 1)
        if overlay.text then
            overlay.text:SetAlpha(1)
        end
    end
end

-- Auto-exit edit mode when entering combat
function EditMode:SetupCombatHandler()
    if self.combatFrame then return end

    self.combatFrame = CreateFrame("Frame")
    self.combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.combatFrame:SetScript("OnEvent", function()
        if EditMode.isActive then
            NRSKNUI:Print("Edit Mode closed due to entering combat.")
            EditMode:Exit()
        end
    end)
end

-- Unregister combat handler
function EditMode:RemoveCombatHandler()
    if self.combatFrame then
        self.combatFrame:UnregisterAllEvents()
        self.combatFrame:SetScript("OnEvent", nil)
        self.combatFrame = nil
    end
end

-- Update overlay styling after theme change
function EditMode:RefreshOverlays()
    if not self.isActive then return end
    local Theme = NRSKNUI.Theme
    local accent = Theme.accent or { 0.898, 0.063, 0.224, 1 }

    for key, overlay in pairs(self.overlayFrames) do
        if overlay then
            overlay:SetBackdropColor(accent[1], accent[2], accent[3], FILL_ALPHA)
            overlay:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
        end
    end

    -- Update nudge frame styling if it exists
    if self.nudgeFrame then
        self:UpdateNudgeFrameTheme()
    end
end

-- Select an element for nudging
function EditMode:SelectElement(key)
    local Theme = NRSKNUI.Theme
    local accent = Theme.accent or { 0.898, 0.063, 0.224, 1 }

    -- Deselect previous
    if self.selectedElementKey and self.overlayFrames[self.selectedElementKey] then
        local prevOverlay = self.overlayFrames[self.selectedElementKey]

        -- Restore to normal state
        prevOverlay:SetBackdropColor(accent[1], accent[2], accent[3], FILL_ALPHA)
        prevOverlay:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
        if prevOverlay.text then
            prevOverlay.text:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.2)
        end
    end

    -- Select new element
    self.selectedElementKey = key

    if key and self.overlayFrames[key] then
        local overlay = self.overlayFrames[key]

        -- Check if Shift is currently held
        if self.isShiftFaded and IsShiftKeyDown() then
            overlay:SetBackdropColor(accent[1], accent[2], accent[3], SHIFT_FADE_ALPHA * FILL_ALPHA)
            overlay:SetBackdropBorderColor(1, 1, 1, SHIFT_FADE_ALPHA)
            if overlay.text then
                overlay.text:SetTextColor(1, 1, 1, 1)
                overlay.text:SetAlpha(SHIFT_FADE_ALPHA)
            end
        else
            -- Highlight selected with white border at full alpha
            overlay:SetBackdropBorderColor(1, 1, 1, 1)
            if overlay.text then
                overlay.text:SetTextColor(1, 1, 1, 1)
            end
        end
    else
        -- No element selected, clear shift fade state
        self.isShiftFaded = false
    end

    -- Update nudge frame display
    self:UpdateNudgeFrameInfo()
end

-- Create the nudge frame with D-pad controls
function EditMode:CreateNudgeFrame()
    if self.nudgeFrame then return self.nudgeFrame end

    local Theme = NRSKNUI.Theme
    local accent = Theme.accent or { 0.898, 0.063, 0.224, 1 }
    local arrowTexture = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\collapse.tga"

    -- Main frame
    local frame = CreateFrame("Frame", "NRSKNUI_EditModeNudge", UIParent, "BackdropTemplate")
    frame:SetSize(160, 220)
    frame:SetPoint("CENTER", UIParent, "CENTER", 400, 0)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(1001)

    -- Make it movable
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(Theme.bgLight[1], Theme.bgLight[2], Theme.bgLight[3], 1)
    frame:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -6)
    title:SetFont(NRSKNUI.FONT or STANDARD_TEXT_FONT, 16, "OUTLINE")
    title:SetShadowColor(0, 0, 0, 0)
    title:SetShadowOffset(0, 0)
    title:SetText("Nudge Tool")
    title:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    frame.title = title

    -- Selected element name
    local selectedText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selectedText:SetPoint("TOP", title, "BOTTOM", 0, -2)
    selectedText:SetFont(NRSKNUI.FONT or STANDARD_TEXT_FONT, 12, "OUTLINE")
    selectedText:SetShadowColor(0, 0, 0, 0)
    selectedText:SetShadowOffset(0, 0)
    selectedText:SetText("Click to select")
    selectedText:SetTextColor(accent[1], accent[2], accent[3], 1)
    frame.selectedText = selectedText

    -- Helper to create editbox for position values
    local function CreatePosEditBox(parent, labelText, yOffset)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(140, 22)
        row:SetPoint("TOP", parent, "TOP", 0, yOffset)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", row, "LEFT", 0, 0)
        label:SetFont(NRSKNUI.FONT or STANDARD_TEXT_FONT, 12, "OUTLINE")
        label:SetShadowColor(0, 0, 0, 0)
        label:SetShadowOffset(0, 0)
        label:SetText(labelText)
        label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)

        local container = CreateFrame("Frame", nil, row, "BackdropTemplate")
        container:SetSize(70, 20)
        container:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        container:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        container:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
        container:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

        local editBox = CreateFrame("EditBox", nil, container)
        editBox:SetPoint("TOPLEFT", 4, -2)
        editBox:SetPoint("BOTTOMRIGHT", -4, 2)
        editBox:SetFontObject("GameFontNormal")
        editBox:SetFont(NRSKNUI.FONT or STANDARD_TEXT_FONT, 12, "OUTLINE")
        editBox:SetShadowColor(0, 0, 0, 0)
        editBox:SetShadowOffset(0, 0)
        editBox:SetTextColor(accent[1], accent[2], accent[3], 1)
        editBox:SetJustifyH("CENTER")
        editBox:SetAutoFocus(false)
        editBox:SetText("--")

        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        editBox:SetScript("OnEditFocusGained", function(self)
            container:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
            self:HighlightText()
        end)

        editBox:SetScript("OnEditFocusLost", function(self)
            container:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
            self:HighlightText(0, 0)
        end)

        -- Hover animation
        local hoverR, hoverG, hoverB = Theme.border[1], Theme.border[2], Theme.border[3]
        local animGroup = container:CreateAnimationGroup()
        local anim = animGroup:CreateAnimation("Animation")
        anim:SetDuration(0.15)
        local colorFrom, colorTo = {}, {}

        local function AnimateBorder(toAccent)
            if editBox:HasFocus() then return end
            animGroup:Stop()
            colorFrom.r, colorFrom.g, colorFrom.b = hoverR, hoverG, hoverB
            if toAccent then
                colorTo.r, colorTo.g, colorTo.b = accent[1], accent[2], accent[3]
            else
                colorTo.r, colorTo.g, colorTo.b = Theme.border[1], Theme.border[2], Theme.border[3]
            end
            animGroup:Play()
        end

        animGroup:SetScript("OnUpdate", function(self)
            local progress = self:GetProgress() or 0
            local r = colorFrom.r + (colorTo.r - colorFrom.r) * progress
            local g = colorFrom.g + (colorTo.g - colorFrom.g) * progress
            local b = colorFrom.b + (colorTo.b - colorFrom.b) * progress
            container:SetBackdropBorderColor(r, g, b, 1)
            hoverR, hoverG, hoverB = r, g, b
        end)

        animGroup:SetScript("OnFinished", function()
            container:SetBackdropBorderColor(colorTo.r, colorTo.g, colorTo.b, 1)
            hoverR, hoverG, hoverB = colorTo.r, colorTo.g, colorTo.b
        end)

        editBox:SetScript("OnEnter", function() AnimateBorder(true) end)
        editBox:SetScript("OnLeave", function() AnimateBorder(false) end)

        row.editBox = editBox
        row.container = container
        return row
    end

    -- X position row
    local xRow = CreatePosEditBox(frame, "X Offset:", -42)
    frame.xEditBox = xRow.editBox

    -- Y position row
    local yRow = CreatePosEditBox(frame, "Y Offset:", -66)
    frame.yEditBox = yRow.editBox

    -- Anchor display
    local anchorRow = CreateFrame("Frame", nil, frame)
    anchorRow:SetSize(140, 18)
    anchorRow:SetPoint("TOP", frame, "TOP", 0, -90)

    -- EditBox submit handlers
    local function ApplyPositionFromEditBoxes()
        if not EditMode.selectedElementKey then return end
        local element = EditMode.registeredElements[EditMode.selectedElementKey]
        if not element then return end

        local currentPos = element.getPosition()
        if not currentPos then return end

        local newX = tonumber(frame.xEditBox:GetText())
        local newY = tonumber(frame.yEditBox:GetText())

        if not newX or not newY then
            EditMode:UpdateNudgeFrameInfo()
            return
        end

        local newPos = {
            AnchorFrom = currentPos.AnchorFrom,
            AnchorTo = currentPos.AnchorTo,
            XOffset = newX,
            YOffset = newY,
        }

        element.setPosition(newPos)

        if EditMode.overlayFrames[EditMode.selectedElementKey] then
            C_Timer.After(0, function()
                EditMode:UpdateOverlayPosition(EditMode.overlayFrames[EditMode.selectedElementKey])
            end)
        end

        if NRSKNUI.GUIFrame and NRSKNUI.GUIFrame:IsShown() then
            NRSKNUI.GUIFrame:RefreshContent()
        end
    end

    frame.xEditBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        ApplyPositionFromEditBoxes()
    end)

    frame.yEditBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        ApplyPositionFromEditBoxes()
    end)

    -- D-Pad settings
    local btnSize = 22
    local dpadCenterY = -105

    -- Create arrow button with animated hover
    local function CreateArrowButton(parent, direction, xOff, yOff, rotation)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(btnSize, btnSize)
        btn:SetPoint("TOP", parent, "TOP", xOff, yOff)

        local container = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        container:SetAllPoints(btn)
        container:SetFrameLevel(btn:GetFrameLevel() + 1)
        container:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        container:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
        container:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

        -- Arrow icon
        local icon = container:CreateTexture(nil, "OVERLAY")
        icon:SetAllPoints()
        icon:SetTexture(arrowTexture)
        icon:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        icon:SetRotation(math.rad(rotation))
        icon:SetTexelSnappingBias(0)
        icon:SetSnapToPixelGrid(false)
        container.icon = icon

        -- Track current color for animation
        local curR, curG, curB = Theme.accent[1], Theme.accent[2], Theme.accent[3]

        -- Hover animation
        local animGroup = btn:CreateAnimationGroup()
        local anim = animGroup:CreateAnimation("Animation")
        anim:SetDuration(0.15)

        local colorFrom = {}
        local colorTo = {}

        local function AnimateColor(toAccent)
            animGroup:Stop()
            colorFrom.r, colorFrom.g, colorFrom.b = curR, curG, curB

            if toAccent then
                colorTo.r, colorTo.g, colorTo.b = Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3]
            else
                colorTo.r, colorTo.g, colorTo.b = accent[1], accent[2], accent[3]
            end
            animGroup:Play()
        end

        animGroup:SetScript("OnUpdate", function(self)
            local progress = self:GetProgress() or 0
            local r = colorFrom.r + (colorTo.r - colorFrom.r) * progress
            local g = colorFrom.g + (colorTo.g - colorFrom.g) * progress
            local b = colorFrom.b + (colorTo.b - colorFrom.b) * progress
            icon:SetVertexColor(r, g, b, 1)
            curR, curG, curB = r, g, b
        end)

        animGroup:SetScript("OnFinished", function()
            icon:SetVertexColor(colorTo.r, colorTo.g, colorTo.b, 1)
            curR, curG, curB = colorTo.r, colorTo.g, colorTo.b
        end)

        btn:SetScript("OnEnter", function()
            AnimateColor(true)
        end)

        btn:SetScript("OnLeave", function()
            AnimateColor(false)
        end)

        btn.direction = direction
        return btn
    end

    -- D-Pad buttons positioned
    local spacing = btnSize + 4
    frame.btnUp = CreateArrowButton(frame, "UP", 0, dpadCenterY, 180)
    frame.btnDown = CreateArrowButton(frame, "DOWN", 0, dpadCenterY - (spacing * 2), 0)
    frame.btnLeft = CreateArrowButton(frame, "LEFT", -spacing, dpadCenterY - spacing, -90)
    frame.btnRight = CreateArrowButton(frame, "RIGHT", spacing, dpadCenterY - spacing, 90)

    -- Setup nudge click handlers
    frame.btnUp:SetScript("OnClick", function() EditMode:NudgeSelectedElement(0, 1) end)
    frame.btnDown:SetScript("OnClick", function() EditMode:NudgeSelectedElement(0, -1) end)
    frame.btnLeft:SetScript("OnClick", function() EditMode:NudgeSelectedElement(-1, 0) end)
    frame.btnRight:SetScript("OnClick", function() EditMode:NudgeSelectedElement(1, 0) end)

    -- Settings button
    local settingsBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    settingsBtn:SetSize(140, 22)
    settingsBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
    settingsBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    settingsBtn:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
    settingsBtn:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    local settingsBtnText = settingsBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    settingsBtnText:SetPoint("CENTER")
    settingsBtnText:SetFont(NRSKNUI.FONT or STANDARD_TEXT_FONT, 12, "OUTLINE")
    settingsBtnText:SetShadowColor(0, 0, 0, 0)
    settingsBtnText:SetShadowOffset(0, 0)
    settingsBtnText:SetText("Open Settings")
    settingsBtnText:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    frame.settingsBtn = settingsBtn
    frame.settingsBtnText = settingsBtnText

    -- Settings button hover animation
    local settingsBtnR, settingsBtnG, settingsBtnB = Theme.border[1], Theme.border[2], Theme.border[3]
    local settingsAnimGroup = settingsBtn:CreateAnimationGroup()
    local settingsAnim = settingsAnimGroup:CreateAnimation("Animation")
    settingsAnim:SetDuration(0.15)
    local settingsColorFrom, settingsColorTo = {}, {}

    local function AnimateSettingsBtn(toAccent)
        settingsAnimGroup:Stop()
        settingsColorFrom.r, settingsColorFrom.g, settingsColorFrom.b = settingsBtnR, settingsBtnG, settingsBtnB
        if toAccent then
            settingsColorTo.r, settingsColorTo.g, settingsColorTo.b = accent[1], accent[2], accent[3]
        else
            settingsColorTo.r, settingsColorTo.g, settingsColorTo.b = Theme.border[1], Theme.border[2], Theme.border[3]
        end
        settingsAnimGroup:Play()
    end

    settingsAnimGroup:SetScript("OnUpdate", function(self)
        local progress = self:GetProgress() or 0
        local r = settingsColorFrom.r + (settingsColorTo.r - settingsColorFrom.r) * progress
        local g = settingsColorFrom.g + (settingsColorTo.g - settingsColorFrom.g) * progress
        local b = settingsColorFrom.b + (settingsColorTo.b - settingsColorFrom.b) * progress
        settingsBtn:SetBackdropBorderColor(r, g, b, 1)
        settingsBtnR, settingsBtnG, settingsBtnB = r, g, b
    end)

    settingsAnimGroup:SetScript("OnFinished", function()
        settingsBtn:SetBackdropBorderColor(settingsColorTo.r, settingsColorTo.g, settingsColorTo.b, 1)
        settingsBtnR, settingsBtnG, settingsBtnB = settingsColorTo.r, settingsColorTo.g, settingsColorTo.b
    end)

    settingsBtn:SetScript("OnEnter", function() AnimateSettingsBtn(true) end)
    settingsBtn:SetScript("OnLeave", function() AnimateSettingsBtn(false) end)

    settingsBtn:SetScript("OnClick", function()
        EditMode:OpenElementSettings()
    end)

    self.nudgeFrame = frame
    return frame
end

-- Update nudge frame info display
function EditMode:UpdateNudgeFrameInfo()
    if not self.nudgeFrame then return end

    local frame = self.nudgeFrame
    local Theme = NRSKNUI.Theme
    local accent = Theme.accent or { 0.898, 0.063, 0.224, 1 }

    if not self.selectedElementKey then
        frame.selectedText:SetText("Click to select")
        frame.selectedText:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        frame.xEditBox:SetText("--")
        frame.yEditBox:SetText("--")
        frame.xEditBox:SetEnabled(false)
        frame.yEditBox:SetEnabled(false)
        frame.settingsBtn:SetEnabled(false)
        frame.settingsBtn:SetAlpha(0.4)
        return
    end

    local element = self.registeredElements[self.selectedElementKey]
    if not element then return end

    frame.selectedText:SetText(element.displayName)
    frame.selectedText:SetTextColor(accent[1], accent[2], accent[3], 1)
    frame.xEditBox:SetEnabled(true)
    frame.yEditBox:SetEnabled(true)
    frame.settingsBtn:SetEnabled(true)
    frame.settingsBtn:SetAlpha(1)

    local pos = element.getPosition()
    if pos then
        frame.xEditBox:SetText(string.format("%.1f", pos.XOffset or 0))
        frame.yEditBox:SetText(string.format("%.1f", pos.YOffset or 0))
    end
end

-- Open the GUI settings for the selected element
function EditMode:OpenElementSettings()
    if not self.selectedElementKey then
        NRSKNUI:Print("No element selected.")
        return
    end

    local element = self.registeredElements[self.selectedElementKey]
    if not element then return end

    local GUIFrame = NRSKNUI.GUIFrame
    if not GUIFrame then return end

    -- guiPath is the sidebar item ID
    local itemId = element.guiPath

    if not itemId then
        -- No guiPath defined, just open GUI
        if not GUIFrame:IsShown() then
            GUIFrame:Show()
        end
        return
    end

    -- Find the parent section ID containing this item
    local sectionId = nil
    local config = GUIFrame.SidebarConfig["systems"]
    if config then
        for _, section in ipairs(config) do
            if section.type == "header" and section.items then
                for _, item in ipairs(section.items) do
                    if item.id == itemId then
                        sectionId = section.id
                        break
                    end
                end
            end
            if sectionId then break end
        end
    end

    -- Use OpenPage which properly handles showing, expanding section, and selecting item
    -- Pass guiContext as third parameter for granular navigation
    GUIFrame:OpenPage(itemId, sectionId, element.guiContext)
end

-- Update nudge frame theme colors
function EditMode:UpdateNudgeFrameTheme()
    if not self.nudgeFrame then return end
    local Theme = NRSKNUI.Theme

    -- Update main frame backdrop
    self.nudgeFrame:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 0.95)
    self.nudgeFrame:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    -- Refresh the info display with new colors
    self:UpdateNudgeFrameInfo()
end

-- Nudge the selected element by X/Y pixels
function EditMode:NudgeSelectedElement(deltaX, deltaY)
    if not self.selectedElementKey then
        NRSKNUI:Print("No element selected. Click an overlay to select it.")
        return
    end

    local element = self.registeredElements[self.selectedElementKey]
    if not element then return end
    local currentPos = element.getPosition()
    if not currentPos then return end

    -- Calculate new position
    local newPos = {
        AnchorFrom = currentPos.AnchorFrom,
        AnchorTo = currentPos.AnchorTo,
        XOffset = (currentPos.XOffset or 0) + deltaX,
        YOffset = (currentPos.YOffset or 0) + deltaY,
    }

    -- Save and apply
    element.setPosition(newPos)

    -- Update overlay position
    if self.overlayFrames[self.selectedElementKey] then
        C_Timer.After(0, function()
            self:UpdateOverlayPosition(self.overlayFrames[self.selectedElementKey])
        end)
    end

    -- Update nudge frame display
    self:UpdateNudgeFrameInfo()

    -- Refresh GUI if open
    if NRSKNUI.GUIFrame and NRSKNUI.GUIFrame:IsShown() then
        NRSKNUI.GUIFrame:RefreshContent()
    end
end

-- Show nudge frame
function EditMode:ShowNudgeFrame()
    if not self.nudgeFrame then
        self:CreateNudgeFrame()
    end
    self.nudgeFrame:Show()
    self:UpdateNudgeFrameInfo()
end

-- Hide nudge frame
function EditMode:HideNudgeFrame()
    if self.nudgeFrame then
        self.nudgeFrame:Hide()
    end
    self.selectedElementKey = nil
end

-- Start updating overlay positions
function EditMode:StartPositionUpdates()
    if self.updateFrame then return end

    self.updateFrame = CreateFrame("Frame")
    self.updateFrame:SetScript("OnUpdate", function()
        if not self.isActive then return end

        for key, overlay in pairs(self.overlayFrames) do
            if overlay and not overlay.isDragging then
                self:UpdateOverlayPosition(overlay)
            end
        end
    end)
end

-- Stop updating overlay positions
function EditMode:StopPositionUpdates()
    if self.updateFrame then
        self.updateFrame:SetScript("OnUpdate", nil)
        self.updateFrame = nil
    end
end

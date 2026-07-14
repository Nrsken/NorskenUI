---@class NRSKNUI
local NRSKNUI = select(2, ...)
local Theme = NRSKNUI.Theme

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local pairs = pairs
local ipairs = ipairs
local GetCursorPosition = GetCursorPosition
local IsShiftKeyDown = IsShiftKeyDown
local tonumber = tonumber
local IsMouseButtonDown = IsMouseButtonDown
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT
local UIParent = UIParent
local math_floor = math.floor

local EditMode = {}
NRSKNUI.EditMode = EditMode

EditMode.isActive = false
EditMode.registeredElements = {}
EditMode.overlayFrames = {}
EditMode.selectedElementKey = nil
EditMode.nudgeFrame = nil
EditMode.isShiftFaded = false

local BORDER_SIZE = 2
local FILL_ALPHA = 0.8
local TEXT_FONT_SIZE = 14
local SHIFT_FADE_ALPHA = 0.1
local SNAP_RANGE = 10

local isDragging = false
local dragOverlay = nil
local dragElement = nil
local dragStartX, dragStartY = 0, 0
local frameStartX, frameStartY = 0, 0
local newCenterX, newCenterY = 0, 0
local dragStartOffsetX, dragStartOffsetY = 0, 0

local gridFrame = nil
local gridCenterX, gridCenterY = 0, 0
local GRID_SIZE = 32

local function CreateGrid()
    if gridFrame then return gridFrame end

    gridFrame = CreateFrame("Frame", "NRSKNUI_EditModeGrid", UIParent)
    gridFrame:SetFrameStrata("BACKGROUND")
    gridFrame:SetAllPoints(UIParent)
    gridFrame.lines = {}

    gridFrame:Hide()
    return gridFrame
end

local function BuildGridLines()
    local width, height = UIParent:GetSize()
    width, height = math_floor(width), math_floor(height)

    for _, line in pairs(gridFrame.lines) do line:Hide() end

    local lineIndex = 0
    local function GetLine()
        lineIndex = lineIndex + 1
        if not gridFrame.lines[lineIndex] then
            gridFrame.lines[lineIndex] = gridFrame:CreateTexture(nil, "BACKGROUND")
        end
        local line = gridFrame.lines[lineIndex]
        line:Show()
        return line
    end

    local halfW = width * 0.5
    local halfH = height * 0.5

    -- Vertical lines from center outward
    for i = 1, math_floor(halfW / GRID_SIZE) do
        local offset = i * GRID_SIZE
        -- Right of center
        local line = GetLine()
        line:SetColorTexture(0, 0, 0, 0.3)
        line:ClearAllPoints()
        line:SetPoint("TOP", gridFrame, "TOP", offset, 0)
        line:SetPoint("BOTTOM", gridFrame, "BOTTOM", offset, 0)
        line:SetWidth(1)
        -- Left of center
        line = GetLine()
        line:SetColorTexture(0, 0, 0, 0.3)
        line:ClearAllPoints()
        line:SetPoint("TOP", gridFrame, "TOP", -offset, 0)
        line:SetPoint("BOTTOM", gridFrame, "BOTTOM", -offset, 0)
        line:SetWidth(1)
    end

    -- Horizontal lines from center outward
    for i = 1, math_floor(halfH / GRID_SIZE) do
        local offset = i * GRID_SIZE
        -- Above center
        local line = GetLine()
        line:SetColorTexture(0, 0, 0, 0.3)
        line:ClearAllPoints()
        line:SetPoint("LEFT", gridFrame, "LEFT", 0, offset)
        line:SetPoint("RIGHT", gridFrame, "RIGHT", 0, offset)
        line:SetHeight(1)
        -- Below center
        line = GetLine()
        line:SetColorTexture(0, 0, 0, 0.3)
        line:ClearAllPoints()
        line:SetPoint("LEFT", gridFrame, "LEFT", 0, -offset)
        line:SetPoint("RIGHT", gridFrame, "RIGHT", 0, -offset)
        line:SetHeight(1)
    end

    -- Center vertical line
    local centerX = GetLine()
    centerX:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.6)
    centerX:ClearAllPoints()
    centerX:SetPoint("TOP", gridFrame, "TOP", 0, 0)
    centerX:SetPoint("BOTTOM", gridFrame, "BOTTOM", 0, 0)
    centerX:SetWidth(2)

    -- Center horizontal line
    local centerY = GetLine()
    centerY:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.6)
    centerY:ClearAllPoints()
    centerY:SetPoint("LEFT", gridFrame, "LEFT", 0, 0)
    centerY:SetPoint("RIGHT", gridFrame, "RIGHT", 0, 0)
    centerY:SetHeight(2)
end

local function ShowGrid()
    if not gridFrame then CreateGrid() end
    local width, height = UIParent:GetSize()
    gridCenterX = width / 2
    gridCenterY = height / 2
    BuildGridLines()
    gridFrame:Show()
end

local dragUpdateFrame = CreateFrame("Frame")
dragUpdateFrame:Hide()

local function UpdateDragPosition()
    if not isDragging or not dragOverlay or not dragElement then return end

    local targetFrame = EditMode:GetElementFrame(dragElement)
    if not targetFrame then return end

    local scale = UIParent:GetEffectiveScale()
    local curX, curY = GetCursorPosition()
    curX, curY = curX / scale, curY / scale

    newCenterX = frameStartX + (curX - dragStartX)
    newCenterY = frameStartY + (curY - dragStartY)

    -- Snap to center lines, hold Shift to disable
    if not IsShiftKeyDown() then
        if math.abs(newCenterX - gridCenterX) < SNAP_RANGE then
            newCenterX = gridCenterX
        end
        if math.abs(newCenterY - gridCenterY) < SNAP_RANGE then
            newCenterY = gridCenterY
        end
    end

    targetFrame:ClearAllPoints()
    targetFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", newCenterX, newCenterY)

    dragOverlay:ClearAllPoints()
    dragOverlay:SetAllPoints(targetFrame)
end

dragUpdateFrame:SetScript("OnUpdate", UpdateDragPosition)

local function OnDragStart(overlay)
    if InCombatLockdown() then return end

    local element = overlay.element
    local targetFrame = EditMode:GetElementFrame(element)
    if not targetFrame then return end

    isDragging = true
    dragOverlay = overlay
    dragElement = element
    overlay.didDrag = true

    local scale = UIParent:GetEffectiveScale()
    dragStartX, dragStartY = GetCursorPosition()
    dragStartX, dragStartY = dragStartX / scale, dragStartY / scale

    local left, bottom, width, height = targetFrame:GetRect()
    if left and bottom and width and height then
        frameStartX = left + width / 2
        frameStartY = bottom + height / 2
    end

    -- Store original offsets for delta calculation
    local currentPos = element.getPosition()
    dragStartOffsetX = currentPos.XOffset or 0
    dragStartOffsetY = currentPos.YOffset or 0

    -- Initialize newCenter to current position (in case drag stops before OnUpdate runs)
    newCenterX = frameStartX
    newCenterY = frameStartY

    overlay:SetAlpha(0.7)
    dragUpdateFrame:Show()
end

local function OnDragStop(overlay)
    if not isDragging then return end

    isDragging = false
    dragUpdateFrame:Hide()
    overlay:SetAlpha(1)

    local element = overlay.element
    local targetFrame = EditMode:GetElementFrame(element)
    if not targetFrame then return end

    -- Use frame center delta (newCenterX/Y already has snap applied from UpdateDragPosition)
    local deltaX = newCenterX - frameStartX
    local deltaY = newCenterY - frameStartY

    -- Apply delta to original offsets (same as nudging)
    local currentPos = element.getPosition()
    element.setPosition({
        AnchorFrom = currentPos.AnchorFrom,
        AnchorTo = currentPos.AnchorTo,
        XOffset = math_floor(dragStartOffsetX + deltaX + 0.5),
        YOffset = math_floor(dragStartOffsetY + deltaY + 0.5),
    })

    C_Timer.After(0, function()
        EditMode:UpdateOverlayPosition(overlay)
        EditMode:SelectElement(element.key)
        if NRSKNUI.GUIFrame and NRSKNUI.GUIFrame:IsShown() then NRSKNUI.GUIFrame:RefreshContent() end
    end)

    dragOverlay = nil
    dragElement = nil
end

local function OnOverlayEnter(overlay)
    if isDragging then return end
    local element = overlay.element
    if EditMode.selectedElementKey ~= element.key and overlay.animateBorder then
        overlay.animateBorder(true)
    end
end

local function OnOverlayLeave(overlay)
    if isDragging then return end
    local element = overlay.element
    if EditMode.selectedElementKey ~= element.key and overlay.animateBorder then
        overlay.animateBorder(false)
    end
end

local function OnOverlayMouseDown(overlay, button)
    if button == "LeftButton" then overlay.didDrag = false end
end

local function OnOverlayMouseUp(overlay, button)
    if button == "LeftButton" and not overlay.didDrag then EditMode:SelectElement(overlay.element.key) end
end

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
        getAnchorFrom = config.getAnchorFrom,
        guiPath = config.guiPath,
        guiContext = config.guiContext,
        usesEdgeRelativePositioning = config.usesEdgeRelativePositioning,
    }

    if self.isActive then self:CreateOverlayForElement(config.key) end
end

function EditMode:UnregisterElement(key)
    if not key then return end

    if self.overlayFrames[key] then
        self.overlayFrames[key]:Hide()
        self.overlayFrames[key] = nil
    end
    self.registeredElements[key] = nil
end

function EditMode:RegisterModuleElement(module, config)
    if not config or not config.key then return end
    if not module or not module.db or not module.db.Enabled then return end
    config.module = module
    self:RegisterElement(config)
end

function EditMode:UnregisterModuleElement(key)
    local element = self.registeredElements[key]
    if not element then return end
    if element.module and element.module:IsEnabled() then return end
    self:UnregisterElement(key)
end

-- Insert a space at every camelCase boundary so a key doubles as a display name.
local function SpaceKey(key)
    return (key:gsub("(%l)(%u)", "%1 %2"))
end

---@param module NRSKNUI.Module
---@param config table|string
---@param frame Frame?
---@param guiPath string?
---@param opts table?
function EditMode:Register(module, config, frame, guiPath, opts)
    if not module then return end

    if type(config) == "string" then
        local key = config
        config = opts or {}
        config.key = key
        config.frame = frame or config.frame
        config.guiPath = guiPath or config.guiPath
    end

    if not config or not config.key then return end
    if self.registeredElements[config.key] then return end

    local dbOverride = config.db
    local function ResolveDB() return dbOverride or module.db end
    if not ResolveDB() then return end

    config.module = module
    config.frame = config.frame or module.frame
    config.displayName = config.displayName or SpaceKey(config.key)
    config.guiPath = config.guiPath or config.key

    local posKey = config.positionKey or "Position"

    if not config.getPosition then
        config.getPosition = function() return ResolveDB()[posKey] end
    end

    if not config.setPosition then
        local apply = config.apply
        config.setPosition = function(pos)
            local p = ResolveDB()[posKey]
            p.AnchorFrom = pos.AnchorFrom
            p.AnchorTo = pos.AnchorTo
            p.XOffset = pos.XOffset
            p.YOffset = pos.YOffset

            if type(apply) == "function" then
                apply(module)
            elseif type(apply) == "string" and module[apply] then
                module[apply](module)
            elseif module.ApplyPosition then
                module:ApplyPosition()
            else
                config.frame:ApplyPosition(ResolveDB())
            end
        end
    end

    --TODO: Fix real anchor
    if not config.getParentFrame then
        config.getParentFrame = function()
            local d = ResolveDB()
            return UIParent
        end
    end

    self:RegisterElement(config)
end

function EditMode:GetElementFrame(element)
    if element.frame then
        return element.frame
    elseif element.frameName then
        return _G[element.frameName]
    end
    return nil
end

function EditMode:CreateOverlayFrame(element)
    local targetFrame = self:GetElementFrame(element)
    if not targetFrame then return nil end

    local overlay = CreateFrame("Frame", "NRSKNUI_EditMode_" .. element.key, UIParent, "BackdropTemplate")
    overlay:SetFrameStrata("TOOLTIP")
    overlay:SetFrameLevel(1000)

    overlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = BORDER_SIZE,
        insets = { left = BORDER_SIZE, right = BORDER_SIZE, top = BORDER_SIZE, bottom = BORDER_SIZE },
    })

    overlay:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], FILL_ALPHA)
    overlay:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)

    local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    text:SetText(element.displayName)
    text:SetFont(NRSKNUI.Media.Fonts.Expressway, TEXT_FONT_SIZE, "OUTLINE")
    text:SetShadowOffset(0, 0)
    text:SetShadowColor(0, 0, 0, 0)
    text:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    overlay.text = text

    overlay.element = element
    overlay.didDrag = false

    overlay.animateBorder = NRSKNUI.Animations:CreateHoverColorAnimator(
        overlay,
        function(r, g, b, a) overlay:SetBackdropBorderColor(r, g, b, a) end,
        Theme.accent,
        Theme.textSecondary
    )

    overlay:EnableMouse(true)
    overlay:SetMovable(true)
    overlay:RegisterForDrag("LeftButton")

    overlay:SetScript("OnDragStart", OnDragStart)
    overlay:SetScript("OnDragStop", OnDragStop)
    overlay:SetScript("OnEnter", OnOverlayEnter)
    overlay:SetScript("OnLeave", OnOverlayLeave)
    overlay:SetScript("OnMouseDown", OnOverlayMouseDown)
    overlay:SetScript("OnMouseUp", OnOverlayMouseUp)

    return overlay
end

function EditMode:UpdateOverlayPosition(overlay)
    local element = overlay.element
    local targetFrame = self:GetElementFrame(element)

    if not targetFrame then
        overlay:Hide()
        return
    end

    overlay:ClearAllPoints()
    overlay:SetAllPoints(targetFrame)
    overlay:Show()
end

function EditMode:CreateOverlayForElement(key)
    local element = self.registeredElements[key]
    if not element then return end

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

function EditMode:Enter()
    if self.isActive then return end
    if InCombatLockdown() then
        NRSKNUI:Print("Cannot enter edit mode during combat.")
        return
    end

    self.isActive = true

    for key in pairs(self.registeredElements) do
        self:CreateOverlayForElement(key)
    end

    self:ShowNudgeFrame()
    ShowGrid()
    if NRSKNUI.PreviewManager then NRSKNUI.PreviewManager:SetEditModeActive(true) end
    self:SetupEscapeHandler()
    self:SetupShiftHandler()
    self:SetupCombatHandler()
    self:StartDeselectChecker()

    local EnterMsg =
    "Edit Mode |cff00ff00enabled|r.\nDrag elements to reposition.\nHold Shift to disable snap.\nPress ESC or type /nui edit to exit."
    NRSKNUI:CreateMessagePopup(20, EnterMsg, 14, UIParent, 400, 150)
end

function EditMode:Exit()
    if not self.isActive then return end
    self.isActive = false

    isDragging = false
    dragUpdateFrame:Hide()
    dragOverlay = nil
    dragElement = nil

    self:HideNudgeFrame()
    if gridFrame then gridFrame:Hide() end

    if NRSKNUI.PreviewManager then NRSKNUI.PreviewManager:SetEditModeActive(false) end

    for _, overlay in pairs(self.overlayFrames) do if overlay then overlay:Hide() end end
    self.overlayFrames = {}

    self:RemoveEscapeHandler()
    self:RemoveShiftHandler()
    self:RemoveCombatHandler()
    self:StopDeselectChecker()

    local ExitMsg = "Edit Mode |cffff0000disabled|r."
    NRSKNUI:CreateMessagePopup(1, ExitMsg, 14, UIParent, 400, 150)
end

function EditMode:Toggle()
    if self.isActive then
        self:Exit()
    else
        self:Enter()
    end
end

function EditMode:IsActive()
    return self.isActive
end

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

function EditMode:RemoveEscapeHandler()
    if self.escapeFrame then
        self.escapeFrame:SetScript("OnKeyDown", nil)
        self.escapeFrame:EnableKeyboard(false)
        self.escapeFrame:Hide()
        self.escapeFrame = nil
    end
end

function EditMode:SetupShiftHandler()
    if self.shiftFrame then return end
    self.shiftFrame = CreateFrame("Frame", "NRSKNUI_EditModeShift", UIParent)
    local wasShiftDown = false
    self.shiftFrame:SetScript("OnUpdate", function()
        if not EditMode.isActive then return end
        local isShiftDown = IsShiftKeyDown()

        if isShiftDown and not wasShiftDown then
            EditMode:ApplyShiftFade(true)
        elseif not isShiftDown and wasShiftDown then
            EditMode:ApplyShiftFade(false)
        end

        wasShiftDown = isShiftDown
    end)
end

function EditMode:RemoveShiftHandler()
    if self.shiftFrame then
        self.shiftFrame:SetScript("OnUpdate", nil)
        self.shiftFrame:Hide()
        self.shiftFrame = nil
    end
    if self.isShiftFaded then self:ApplyShiftFade(false) end
end

local function AnimateOverlayAlpha(overlay, duration, fromAlpha, toAlpha, fillAlpha)
    if overlay._fadeFrame then
        overlay._fadeFrame:SetScript("OnUpdate", nil)
    else
        overlay._fadeFrame = CreateFrame("Frame", nil, overlay)
    end

    local elapsed = 0
    overlay._fadeFrame:SetScript("OnUpdate", function(frame, dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / duration, 1)
        local alpha = fromAlpha + (toAlpha - fromAlpha) * t

        overlay:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], alpha * fillAlpha)
        overlay:SetBackdropBorderColor(1, 1, 1, alpha)

        if overlay.text then overlay.text:SetAlpha(alpha) end

        if t >= 1 then frame:SetScript("OnUpdate", nil) end
    end)
end

function EditMode:ApplyShiftFade(fade)
    self.isShiftFaded = fade

    if not self.selectedElementKey then return end

    local overlay = self.overlayFrames[self.selectedElementKey]
    if not overlay then return end

    if fade then
        AnimateOverlayAlpha(overlay, 0.2, 1, SHIFT_FADE_ALPHA, FILL_ALPHA)
    else
        AnimateOverlayAlpha(overlay, 0.2, SHIFT_FADE_ALPHA, 1, FILL_ALPHA)
    end
end

function EditMode:StartDeselectChecker()
    if not self.deselectChecker then
        self.deselectChecker = CreateFrame("Frame", nil, UIParent)
    end

    local wasMouseDown = false
    self.deselectChecker:SetScript("OnUpdate", function()
        if not EditMode.isActive then return end

        local isDown = IsMouseButtonDown("LeftButton")
        if wasMouseDown and not isDown then
            local overAny = false

            if EditMode.nudgeFrame and EditMode.nudgeFrame:IsMouseOver() then
                overAny = true
            end

            if not overAny and NRSKNUI.GUIFrame and NRSKNUI.GUIFrame.mainFrame
                and NRSKNUI.GUIFrame.mainFrame:IsShown()
                and NRSKNUI.GUIFrame.mainFrame:IsMouseOver() then
                overAny = true
            end

            if not overAny then
                for _, overlay in pairs(EditMode.overlayFrames) do
                    if overlay:IsShown() and overlay:IsMouseOver() then
                        overAny = true
                        break
                    end
                end
            end

            if not overAny then
                EditMode:SelectElement(nil)
            end
        end

        wasMouseDown = isDown
    end)
    self.deselectChecker:Show()
end

function EditMode:StopDeselectChecker()
    if self.deselectChecker then
        self.deselectChecker:SetScript("OnUpdate", nil)
        self.deselectChecker:Hide()
    end
end

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

function EditMode:RemoveCombatHandler()
    if self.combatFrame then
        self.combatFrame:UnregisterAllEvents()
        self.combatFrame:SetScript("OnEvent", nil)
        self.combatFrame = nil
    end
end

function EditMode:RefreshOverlays()
    if not self.isActive then return end

    for _, overlay in pairs(self.overlayFrames) do
        if overlay then
            overlay:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], FILL_ALPHA)
            overlay:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        end
    end

    if self.nudgeFrame then self:UpdateNudgeFrameTheme() end
end

function EditMode:SelectElement(key)
    if self.selectedElementKey and self.overlayFrames[self.selectedElementKey] then
        local prevOverlay = self.overlayFrames[self.selectedElementKey]

        prevOverlay:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], FILL_ALPHA)
        prevOverlay:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        if prevOverlay.text then
            prevOverlay.text:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        end
    end

    self.selectedElementKey = key

    if key and self.overlayFrames[key] then
        local overlay = self.overlayFrames[key]

        if self.isShiftFaded and IsShiftKeyDown() then
            overlay:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], SHIFT_FADE_ALPHA * FILL_ALPHA)
            overlay:SetBackdropBorderColor(1, 1, 1, SHIFT_FADE_ALPHA)
            if overlay.text then
                overlay.text:SetTextColor(1, 1, 1, 1)
                overlay.text:SetAlpha(SHIFT_FADE_ALPHA)
            end
        else
            overlay:SetBackdropBorderColor(1, 1, 1, 1)
            if overlay.text then overlay.text:SetTextColor(1, 1, 1, 1) end
        end
    else
        self.isShiftFaded = false
    end

    self:UpdateNudgeFrameInfo()
end

function EditMode:NudgeSelectedElement(deltaX, deltaY)
    if not self.selectedElementKey then
        NRSKNUI:Print("No element selected. Click an overlay to select it.")
        return
    end

    local element = self.registeredElements[self.selectedElementKey]
    if not element then return end

    local currentPos = element.getPosition()
    if not currentPos then return end

    element.setPosition({
        AnchorFrom = currentPos.AnchorFrom,
        AnchorTo = currentPos.AnchorTo,
        XOffset = math_floor((currentPos.XOffset or 0) + deltaX + 0.5),
        YOffset = math_floor((currentPos.YOffset or 0) + deltaY + 0.5),
    })

    if self.overlayFrames[self.selectedElementKey] then
        C_Timer.After(0, function() self:UpdateOverlayPosition(self.overlayFrames[self.selectedElementKey]) end)
    end

    self:UpdateNudgeFrameInfo()

    if NRSKNUI.GUIFrame and NRSKNUI.GUIFrame:IsShown() then NRSKNUI.GUIFrame:RefreshContent() end
end

function EditMode:CreateNudgeFrame()
    if self.nudgeFrame then return self.nudgeFrame end
    local arrowTexture = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\collapse.tga"

    local frame = CreateFrame("Frame", "NRSKNUI_EditModeNudge", UIParent, "BackdropTemplate")
    frame:SetSize(160, 220)
    frame:SetPoint("CENTER", UIParent, "CENTER", 400, 0)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(1001)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(Theme.bgLight[1], Theme.bgLight[2], Theme.bgLight[3], 1)
    frame:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -6)
    title:SetFont(NRSKNUI.Media.Fonts.Expressway, 16, "OUTLINE")
    title:SetShadowColor(0, 0, 0, 0)
    title:SetShadowOffset(0, 0)
    title:SetText("Nudge Tool")
    title:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    frame.title = title

    local selectedText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selectedText:SetPoint("TOP", title, "BOTTOM", 0, -2)
    selectedText:SetFont(NRSKNUI.Media.Fonts.Expressway, 12, "OUTLINE")
    selectedText:SetShadowColor(0, 0, 0, 0)
    selectedText:SetShadowOffset(0, 0)
    selectedText:SetText("Click to select")
    selectedText:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    frame.selectedText = selectedText

    local function CreatePosEditBox(parent, labelText, yOffset)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(140, 22)
        row:SetPoint("TOP", parent, "TOP", 0, yOffset)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", row, "LEFT", 0, 0)
        label:SetFont(NRSKNUI.Media.Fonts.Expressway, 12, "OUTLINE")
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
        editBox:SetFont(NRSKNUI.Media.Fonts.Expressway, 12, "OUTLINE")
        editBox:SetShadowColor(0, 0, 0, 0)
        editBox:SetShadowOffset(0, 0)
        editBox:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        editBox:SetJustifyH("CENTER")
        editBox:SetAutoFocus(false)
        editBox:SetText("--")

        editBox:SetScript("OnEscapePressed", function() editBox:ClearFocus() end)

        editBox:SetScript("OnEditFocusGained", function()
            container:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            editBox:HighlightText()
        end)

        editBox:SetScript("OnEditFocusLost", function()
            container:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
            editBox:HighlightText(0, 0)
        end)

        local hoverR, hoverG, hoverB = Theme.border[1], Theme.border[2], Theme.border[3]
        local animGroup = container:CreateAnimationGroup()
        animGroup:CreateAnimation("Animation"):SetDuration(0.15)
        local colorFrom, colorTo = {}, {}

        local function AnimateBorder(toAccent)
            if editBox:HasFocus() then return end
            animGroup:Stop()
            colorFrom.r, colorFrom.g, colorFrom.b = hoverR, hoverG, hoverB
            if toAccent then
                colorTo.r, colorTo.g, colorTo.b = Theme.accent[1], Theme.accent[2], Theme.accent[3]
            else
                colorTo.r, colorTo.g, colorTo.b = Theme.border[1], Theme.border[2], Theme.border[3]
            end
            animGroup:Play()
        end

        animGroup:SetScript("OnUpdate", function()
            local progress = animGroup:GetProgress() or 0
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

    local xRow = CreatePosEditBox(frame, "X Offset:", -42)
    frame.xEditBox = xRow.editBox

    local yRow = CreatePosEditBox(frame, "Y Offset:", -66)
    frame.yEditBox = yRow.editBox

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

        element.setPosition({
            AnchorFrom = currentPos.AnchorFrom,
            AnchorTo = currentPos.AnchorTo,
            XOffset = math_floor(newX + 0.5),
            YOffset = math_floor(newY + 0.5),
        })

        if EditMode.overlayFrames[EditMode.selectedElementKey] then
            C_Timer.After(0, function()
                EditMode:UpdateOverlayPosition(EditMode.overlayFrames[EditMode.selectedElementKey])
            end)
        end

        if NRSKNUI.GUIFrame and NRSKNUI.GUIFrame:IsShown() then
            NRSKNUI.GUIFrame:RefreshContent()
        end
    end

    frame.xEditBox:SetScript("OnEnterPressed", function()
        frame.xEditBox:ClearFocus()
        ApplyPositionFromEditBoxes()
    end)

    frame.yEditBox:SetScript("OnEnterPressed", function()
        frame.yEditBox:ClearFocus()
        ApplyPositionFromEditBoxes()
    end)

    local btnSize = 22
    local dpadCenterY = -105

    local function CreateArrowButton(parent, xOff, yOff, rotation)
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

        local icon = container:CreateTexture(nil, "OVERLAY")
        icon:SetAllPoints()
        icon:SetTexture(arrowTexture)
        icon:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        icon:SetRotation(math.rad(rotation))
        icon:SetTexelSnappingBias(0)
        icon:SetSnapToPixelGrid(false)
        container.icon = icon

        local curR, curG, curB = Theme.accent[1], Theme.accent[2], Theme.accent[3]
        local animGroup = btn:CreateAnimationGroup()
        animGroup:CreateAnimation("Animation"):SetDuration(0.15)
        local colorFrom, colorTo = {}, {}

        local function AnimateColor(toHover)
            animGroup:Stop()
            colorFrom.r, colorFrom.g, colorFrom.b = curR, curG, curB
            if toHover then
                colorTo.r, colorTo.g, colorTo.b = Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3]
            else
                colorTo.r, colorTo.g, colorTo.b = Theme.accent[1], Theme.accent[2], Theme.accent[3]
            end
            animGroup:Play()
        end

        animGroup:SetScript("OnUpdate", function()
            local progress = animGroup:GetProgress() or 0
            curR = colorFrom.r + (colorTo.r - colorFrom.r) * progress
            curG = colorFrom.g + (colorTo.g - colorFrom.g) * progress
            curB = colorFrom.b + (colorTo.b - colorFrom.b) * progress
            icon:SetVertexColor(curR, curG, curB, 1)
        end)

        animGroup:SetScript("OnFinished", function()
            curR, curG, curB = colorTo.r, colorTo.g, colorTo.b
            icon:SetVertexColor(curR, curG, curB, 1)
        end)

        btn:SetScript("OnEnter", function() AnimateColor(true) end)
        btn:SetScript("OnLeave", function() AnimateColor(false) end)

        return btn
    end

    local spacing = btnSize + 4
    frame.btnUp = CreateArrowButton(frame, 0, dpadCenterY, 180)
    frame.btnDown = CreateArrowButton(frame, 0, dpadCenterY - (spacing * 2), 0)
    frame.btnLeft = CreateArrowButton(frame, -spacing, dpadCenterY - spacing, -90)
    frame.btnRight = CreateArrowButton(frame, spacing, dpadCenterY - spacing, 90)

    frame.btnUp:SetScript("OnClick", function() EditMode:NudgeSelectedElement(0, 1) end)
    frame.btnDown:SetScript("OnClick", function() EditMode:NudgeSelectedElement(0, -1) end)
    frame.btnLeft:SetScript("OnClick", function() EditMode:NudgeSelectedElement(-1, 0) end)
    frame.btnRight:SetScript("OnClick", function() EditMode:NudgeSelectedElement(1, 0) end)

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
    settingsBtnText:SetFont(NRSKNUI.Media.Fonts.Expressway, 12, "OUTLINE")
    settingsBtnText:SetShadowColor(0, 0, 0, 0)
    settingsBtnText:SetShadowOffset(0, 0)
    settingsBtnText:SetText("Open Settings")
    settingsBtnText:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    frame.settingsBtn = settingsBtn
    frame.settingsBtnText = settingsBtnText

    local settingsBtnR, settingsBtnG, settingsBtnB = Theme.border[1], Theme.border[2], Theme.border[3]
    local settingsAnimGroup = settingsBtn:CreateAnimationGroup()
    settingsAnimGroup:CreateAnimation("Animation"):SetDuration(0.15)
    local settingsColorFrom, settingsColorTo = {}, {}

    local function AnimateSettingsBtn(toAccent)
        settingsAnimGroup:Stop()
        settingsColorFrom.r, settingsColorFrom.g, settingsColorFrom.b = settingsBtnR, settingsBtnG, settingsBtnB
        if toAccent then
            settingsColorTo.r, settingsColorTo.g, settingsColorTo.b = Theme.accent[1], Theme.accent[2], Theme.accent[3]
        else
            settingsColorTo.r, settingsColorTo.g, settingsColorTo.b = Theme.border[1], Theme.border[2], Theme.border[3]
        end
        settingsAnimGroup:Play()
    end

    settingsAnimGroup:SetScript("OnUpdate", function()
        local progress = settingsAnimGroup:GetProgress() or 0
        settingsBtnR = settingsColorFrom.r + (settingsColorTo.r - settingsColorFrom.r) * progress
        settingsBtnG = settingsColorFrom.g + (settingsColorTo.g - settingsColorFrom.g) * progress
        settingsBtnB = settingsColorFrom.b + (settingsColorTo.b - settingsColorFrom.b) * progress
        settingsBtn:SetBackdropBorderColor(settingsBtnR, settingsBtnG, settingsBtnB, 1)
    end)

    settingsAnimGroup:SetScript("OnFinished", function()
        settingsBtnR, settingsBtnG, settingsBtnB = settingsColorTo.r, settingsColorTo.g, settingsColorTo.b
        settingsBtn:SetBackdropBorderColor(settingsBtnR, settingsBtnG, settingsBtnB, 1)
    end)

    settingsBtn:SetScript("OnEnter", function() AnimateSettingsBtn(true) end)
    settingsBtn:SetScript("OnLeave", function() AnimateSettingsBtn(false) end)
    settingsBtn:SetScript("OnClick", function() EditMode:OpenElementSettings() end)

    self.nudgeFrame = frame
    return frame
end

function EditMode:UpdateNudgeFrameInfo()
    if not self.nudgeFrame then return end

    local frame = self.nudgeFrame

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
    frame.selectedText:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    frame.xEditBox:SetEnabled(true)
    frame.yEditBox:SetEnabled(true)
    frame.settingsBtn:SetEnabled(true)
    frame.settingsBtn:SetAlpha(1)

    local pos = element.getPosition()
    if pos then
        frame.xEditBox:SetText(string.format("%d", math_floor((pos.XOffset or 0) + 0.5)))
        frame.yEditBox:SetText(string.format("%d", math_floor((pos.YOffset or 0) + 0.5)))
    end
end

function EditMode:OpenElementSettings()
    if not self.selectedElementKey then
        NRSKNUI:Print("No element selected.")
        return
    end

    local element = self.registeredElements[self.selectedElementKey]
    if not element then return end

    local GUIFrame = NRSKNUI.GUIFrame
    if not GUIFrame then return end

    local itemId = element.guiPath

    if not itemId then
        if not GUIFrame:IsShown() then GUIFrame:Show() end
        return
    end

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

    GUIFrame:OpenPage(itemId, sectionId, element.guiContext)
end

function EditMode:UpdateNudgeFrameTheme()
    if not self.nudgeFrame then return end

    self.nudgeFrame:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 0.95)
    self.nudgeFrame:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    self:UpdateNudgeFrameInfo()
end

function EditMode:ShowNudgeFrame()
    if not self.nudgeFrame then self:CreateNudgeFrame() end
    self.nudgeFrame:Show()
    self:UpdateNudgeFrameInfo()
end

function EditMode:HideNudgeFrame()
    if self.nudgeFrame then self.nudgeFrame:Hide() end
    self.selectedElementKey = nil
end

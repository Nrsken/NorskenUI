---@class NRSKNUI
local NRSKNUI = select(2, ...)
local Theme = NRSKNUI.Theme
local Animations = NRSKNUI.Libs.KAJI.Animations
---@class NRSKNUI.Anchors
local Anchors = NRSKNUI.Anchors or {}
NRSKNUI.Anchors = Anchors
Anchors.isActive = false
Anchors.registry = {}
Anchors.overlays = {}
Anchors.selectedKey = nil
Anchors.isShiftFaded = false

local math_floor, math_ceil, math_abs, math_rad = math.floor, math.ceil, math.abs, math.rad
local GetPhysicalScreenSize = GetPhysicalScreenSize
local GetCursorPosition = GetCursorPosition
local IsShiftKeyDown = IsShiftKeyDown
local GetCurrentKeyBoardFocus = GetCurrentKeyBoardFocus
local pairs, ipairs = pairs, ipairs
local CreateFrame = CreateFrame
local format = string.format
local tonumber = tonumber
local type = type

local C_Timer = C_Timer
local UIParent = UIParent

local ARROW_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\collapse.tga'

-- Overlay Config
local FILL_ALPHA = 0.8
local BORDER_SIZE = 2
local TEXT_FONT_SIZE = 14
local SHIFT_FADE_ALPHA = 0.1
local SNAP_RANGE = 10
local FADE_DURATION = 0.25
local UNSELECTED_ALPHA = 0.8 -- The alpha of overlays that are not selected, when a selection exists.
local DRAG_ALPHA = 0.7       -- The alpha of the overlay being dragged.
local STATE_DURATION = 0.25  -- The duration of the selection fade.
local WHITE = { 1, 1, 1 }

-- Grid Config
local gridFrame = nil
local gridCenterX, gridCenterY = 0, 0
local GRID_SIZE = 64
local GRID_LINE_WIDTH = 1
local GRID_COLOR = { 0, 0, 0, 0.4 }
local GRID_CENTER_ALPHA = 0.4
local ShowGrid

-- Fading --

---Creates a function that fades a frame to a target alpha over time.
---@param frame Frame
---@param duration? number defaults to FADE_DURATION
---@return fun(toAlpha: number)
local function CreateFader(frame, duration)
    local group = frame:CreateAnimationGroup()
    group:SetToFinalAlpha(true)

    local anim = group:CreateAnimation('Alpha')
    anim:SetDuration(duration or FADE_DURATION)

    group:SetScript('OnFinished', function()
        local target = anim:GetToAlpha()
        frame:SetAlpha(target)
        if target == 0 then frame:Hide() end
    end)

    return function(toAlpha)
        group:Stop()
        if toAlpha > 0 and not frame:IsShown() then
            frame:SetAlpha(0)
            frame:Show()
        end
        anim:SetFromAlpha(frame:GetAlpha())
        anim:SetToAlpha(toAlpha)
        group:Play()
    end
end

local gridFader
local function CreateGrid()
    if gridFrame then return gridFrame end

    gridFrame = CreateFrame('Frame', 'NRSKNUI_AnchorsGrid', UIParent)
    gridFrame:SetFrameStrata('BACKGROUND')
    gridFrame:SetAllPoints(UIParent)
    gridFrame.lines = {}

    gridFrame:RegisterEvent('UI_SCALE_CHANGED')
    gridFrame:RegisterEvent('DISPLAY_SIZE_CHANGED')
    gridFrame:SetScript('OnEvent', function(self)
        if self:IsShown() then ShowGrid() end
    end)

    gridFrame:Hide()
    gridFader = CreateFader(gridFrame)
    return gridFrame
end

---Pulls a line out of the pool, creating it on first use.
---@param index number
---@param isCenter boolean
---@return Texture
local function GetLine(index, isCenter)
    local line = gridFrame.lines[index]
    if not line then
        line = gridFrame:CreateTexture()
        gridFrame.lines[index] = line
    end

    if isCenter then
        line:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], GRID_CENTER_ALPHA)
        line:SetDrawLayer('BACKGROUND', 1)
    else
        line:SetColorTexture(GRID_COLOR[1], GRID_COLOR[2], GRID_COLOR[3], GRID_COLOR[4])
        line:SetDrawLayer('BACKGROUND', 0)
    end

    line:ClearAllPoints()
    line:Show()
    return line
end

local function BuildGridLines()
    local width, height = UIParent:GetSize()
    local physWidth, physHeight = GetPhysicalScreenSize()
    if not physWidth or physWidth == 0 or physHeight == 0 then return end

    local pixel = width / physWidth
    local step = math_floor(physWidth / GRID_SIZE + 0.5) * pixel
    local lineWidth = GRID_LINE_WIDTH * pixel

    gridCenterX, gridCenterY = math_floor(physWidth * 0.5 + 0.5) * pixel, math_floor(physHeight * 0.5 + 0.5) * pixel

    local index = 0
    local function PlaceVertical(x, isCenter)
        index = index + 1
        local line = GetLine(index, isCenter)
        local thickness = isCenter and lineWidth * 2 or lineWidth
        local left = isCenter and x - lineWidth or x
        line:SetPoint('TOPLEFT', gridFrame, 'TOPLEFT', left, 0)
        line:SetPoint('BOTTOMRIGHT', gridFrame, 'BOTTOMLEFT', left + thickness, 0)
    end

    local function PlaceHorizontal(y, isCenter)
        index = index + 1
        local line = GetLine(index, isCenter)
        local thickness = isCenter and lineWidth * 2 or lineWidth
        local top = isCenter and y - lineWidth or y
        line:SetPoint('TOPLEFT', gridFrame, 'TOPLEFT', 0, -top)
        line:SetPoint('BOTTOMRIGHT', gridFrame, 'TOPRIGHT', 0, -(top + thickness))
    end

    for i = -math_ceil(gridCenterX / step), math_ceil((width - gridCenterX) / step) do
        PlaceVertical(gridCenterX + i * step, i == 0)
    end

    for i = -math_ceil(gridCenterY / step), math_ceil((height - gridCenterY) / step) do
        PlaceHorizontal(gridCenterY + i * step, i == 0)
    end

    for i = index + 1, #gridFrame.lines do
        gridFrame.lines[i]:Hide()
    end
end

function ShowGrid()
    if not gridFrame then CreateGrid() end
    BuildGridLines()
    gridFader(1)
end

local function HideGrid()
    if gridFader then gridFader(0) end
end

-- Descriptor resolution --

---Resolves a descriptor field that may be a literal or a function of the module.
local function Resolve(value, module)
    if type(value) == 'function' then
        return value(module)
    end
    return value
end

---The table the offsets live in, matching PositionCard's getPositionTable.
---@param entry table
---@return table? posTable
---@return table? db
local function GetTables(entry)
    -- Read module.db live rather than capturing it: modules reassign self.db in
    -- UpdateDB() on a profile switch, so a captured table would write to the old profile.
    local db
    if entry.db ~= nil then
        db = Resolve(entry.db, entry.module)
    else
        db = entry.module.db
    end
    if not db then return nil, nil end
    return db[Resolve(entry.positionKey, entry.module) or 'Position'], db
end

---Reads an offset with PositionCard's precedence: position table, then db root, then default.
local function ReadOffset(entry, key)
    local posTable, db = GetTables(entry)
    if posTable and posTable[key] ~= nil then return posTable[key] end
    if db and db[key] ~= nil then return db[key] end
    return 0
end

---@param key string
---@return number x
---@return number y
function Anchors:GetOffsets(key)
    local entry = self.registry[key]
    if not entry then return 0, 0 end
    return ReadOffset(entry, entry.xKey), ReadOffset(entry, entry.yKey)
end

---Writes both offsets and re-applies the module. The only path that touches the DB.
---AnchorFrom/AnchorTo are owned by the GUI's PositionCard and are never written here.
---@param key string
---@param x number
---@param y number
function Anchors:SetOffsets(key, x, y)
    local entry = self.registry[key]
    if not entry then return end

    local posTable, db = GetTables(entry)
    local target = posTable or db
    if not target then return end

    target[entry.xKey] = math_floor(x + 0.5)
    target[entry.yKey] = math_floor(y + 0.5)

    local apply = entry.apply
    if type(apply) == 'function' then
        apply(entry.module)
    elseif entry.module[apply] then
        entry.module[apply](entry.module)
    end

    -- Every offset change flows through here, so this is the one place that keeps the
    -- overlay, the nudge panel and the GUI's PositionCard sliders showing the same value.
    C_Timer.After(0, function() self:UpdateOverlay(key) end)
    self:UpdatePanel()

    local GUI = NRSKNUI.GUI
    if GUI and NRSKNUI.GUIFrame and NRSKNUI.GUIFrame:IsShown() then
        GUI:RefreshPositionCards()
    end
end

---@param entry table
---@return Frame?
local function GetEntryFrame(entry)
    if entry.frame then return entry.frame end
    if entry.frameName then return _G[entry.frameName] end
    return nil
end

-- Registration --

---Registers a frame as a draggable anchor.
---@param module NRSKNUI.ModuleBase
---@param key string Unique anchor key.
---@param frame Frame? The frame to move; defaults to module.frame.
---@param guiPath string? Sidebar item id opened by the panel's Open Settings button.
---@param opts table? db, positionKey, xKey, yKey, apply, displayName, frameName, guiContext
function Anchors:Register(module, key, frame, guiPath, opts)
    if not module or not key then return end
    opts = opts or {}

    frame = frame or opts.frame or module.frame
    if not frame and not opts.frameName then return end

    local entry = self.registry[key]
    if not entry then
        entry = { key = key }
        self.registry[key] = entry
    end

    entry.module = module
    entry.frame = frame
    entry.frameName = opts.frameName
    entry.db = opts.db -- nil means 'read module.db live', see GetTables
    entry.positionKey = opts.positionKey or 'Position'
    entry.xKey = opts.xKey or 'XOffset'
    entry.yKey = opts.yKey or 'YOffset'
    entry.apply = opts.apply or 'ApplySettings'
    entry.displayName = opts.displayName or (key:gsub('(%l)(%u)', '%1 %2'))
    entry.guiPath = guiPath or opts.guiPath
    entry.guiContext = opts.guiContext

    -- What the overlay covers, when that is bigger than what the drag moves:
    -- a group of chained frames is dragged by the one frame that carries the position, but should be grabbable across all of them.
    entry.overlayFrame = opts.overlayFrame

    if type(entry.apply) == 'string' and type(module[entry.apply]) ~= 'function' then
        NRSKNUI:Print(format("Anchor '%s' registered with apply='%s', which the module does not define.", key, entry.apply))
    end

    if self.isActive then self:CreateOverlay(key) end
end

---@param key string
function Anchors:Unregister(key)
    if not key then return end

    local overlay = self.overlays[key]
    if overlay then
        overlay:Hide()
        overlay.entry = nil
        self.overlays[key] = nil
    end

    self.registry[key] = nil
    if self.selectedKey == key then self:Select(nil) end
end

-- Overlays --

local overlayHost = CreateFrame('Frame', 'NRSKNUI_AnchorsOverlays', UIParent)
overlayHost:SetAllPoints(UIParent)
overlayHost:SetFrameStrata('TOOLTIP')
overlayHost:Hide()

local FadeOverlays = CreateFader(overlayHost)

-- Drag --

local isDragging = false
local dragEntry = nil
local dragCursorX, dragCursorY = 0, 0
local dragPoint, dragRelTo, dragRelPoint, dragOriginX, dragOriginY
local dragDBX, dragDBY = 0, 0
local dragDeltaX, dragDeltaY = 0, 0
local dragCenterX, dragCenterY, dragRatio = 0, 0, 1

local dragUpdateFrame = CreateFrame('Frame')
dragUpdateFrame:Hide()

local function UpdateDrag()
    if not isDragging or not dragEntry then return end

    local frame = GetEntryFrame(dragEntry)
    if not frame then return end

    local scale = frame:GetEffectiveScale()
    local curX, curY = GetCursorPosition()
    curX, curY = curX / scale, curY / scale

    local dx = math_floor(curX - dragCursorX + 0.5)
    local dy = math_floor(curY - dragCursorY + 0.5)

    -- Snap the frame's centre to the screen centre lines, hold Shift to disable.
    if not IsShiftKeyDown() then
        local centerX = dragCenterX + dx * dragRatio
        local centerY = dragCenterY + dy * dragRatio
        if math_abs(centerX - gridCenterX) < SNAP_RANGE then
            dx = dx + math_floor((gridCenterX - centerX) / dragRatio + 0.5)
        end
        if math_abs(centerY - gridCenterY) < SNAP_RANGE then
            dy = dy + math_floor((gridCenterY - centerY) / dragRatio + 0.5)
        end
    end

    dragDeltaX, dragDeltaY = dx, dy
    frame:ClearAllPoints()
    frame:SetPoint(dragPoint, dragRelTo, dragRelPoint, dragOriginX + dx, dragOriginY + dy)
end

dragUpdateFrame:SetScript('OnUpdate', UpdateDrag)

local function OnDragStart(overlay)
    -- Overlays stay mouse-live while they fade out, so re-check the session is open.
    if not Anchors.isActive or NRSKNUI:InCombat() then return end

    local entry = overlay.entry
    local frame = GetEntryFrame(entry)
    if not frame then return end

    -- Anchors drives frames positioned by ApplyPosition, which always sets exactly one point.
    if frame:GetNumPoints() ~= 1 then
        NRSKNUI:Print(format("Anchor '%s' has %d anchor points and cannot be dragged.", entry.displayName, frame:GetNumPoints()))
        return
    end

    dragPoint, dragRelTo, dragRelPoint, dragOriginX, dragOriginY = frame:GetPoint(1)
    dragRelTo = dragRelTo or UIParent

    local scale = frame:GetEffectiveScale()
    dragCursorX, dragCursorY = GetCursorPosition()
    dragCursorX, dragCursorY = dragCursorX / scale, dragCursorY / scale

    dragRatio = scale / UIParent:GetEffectiveScale()
    local left, bottom, width, height = frame:GetRect()
    dragCenterX = left and (left + width / 2) * dragRatio or 0
    dragCenterY = bottom and (bottom + height / 2) * dragRatio or 0

    dragDBX, dragDBY = Anchors:GetOffsets(entry.key)
    dragDeltaX, dragDeltaY = 0, 0

    isDragging = true
    dragEntry = entry
    overlay.didDrag = true
    Anchors:RefreshOverlayState(entry.key)
    dragUpdateFrame:Show()
end

local function OnDragStop(overlay)
    if not isDragging then return end

    isDragging = false
    dragUpdateFrame:Hide()

    local entry = dragEntry
    dragEntry = nil
    if not entry then return end

    -- SetOffsets re-syncs the overlay, the panel and the GUI sliders.
    Anchors:SetOffsets(entry.key, dragDBX + dragDeltaX, dragDBY + dragDeltaY)
    Anchors:Select(entry.key)
end

local function OnOverlayEnter(overlay)
    if isDragging then return end
    overlay.isHovered = true
    Anchors:RefreshOverlayState(overlay.entry.key)
end

local function OnOverlayLeave(overlay)
    overlay.isHovered = false
    if isDragging then return end
    Anchors:RefreshOverlayState(overlay.entry.key)
end

local function OnOverlayMouseDown(overlay, button)
    if button == 'LeftButton' then overlay.didDrag = false end
end

local function OnOverlayMouseUp(overlay, button)
    if button == 'LeftButton' and not overlay.didDrag then Anchors:Select(overlay.entry.key) end
end

---@param key string
function Anchors:CreateOverlay(key)
    local entry = self.registry[key]
    if not entry then return end

    if self.overlays[key] then
        self:UpdateOverlay(key)
        return
    end

    local frame = GetEntryFrame(entry)
    if not frame then return end

    local overlay = CreateFrame('Frame', 'NRSKNUI_Anchor_' .. key, overlayHost, 'BackdropTemplate')
    overlay:SetBackdrop({
        bgFile = 'Interface\\Buttons\\WHITE8X8',
        edgeFile = 'Interface\\Buttons\\WHITE8X8',
        edgeSize = BORDER_SIZE,
        insets = { left = BORDER_SIZE, right = BORDER_SIZE, top = BORDER_SIZE, bottom = BORDER_SIZE },
    })
    overlay:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], FILL_ALPHA)
    overlay:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)

    local text = overlay:CreateFontString(nil, 'OVERLAY')
    text:SetPoint('CENTER')
    text:SetFont(NRSKNUI.Media.Fonts.Expressway, TEXT_FONT_SIZE, 'OUTLINE')
    text:SetShadowOffset(0, 0)
    text:SetShadowColor(0, 0, 0, 0)
    text:SetText(entry.displayName)
    text:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    overlay.text = text

    overlay.entry = entry
    overlay.didDrag = false
    overlay.isHovered = false
    overlay.animateBorder = Animations:CreateColorAnimator(
        overlay,
        function(r, g, b, a) overlay:SetBackdropBorderColor(r, g, b, a) end,
        Theme.accent,
        STATE_DURATION
    )
    overlay.fadeTo = CreateFader(overlay, STATE_DURATION)

    overlay:EnableMouse(true)
    overlay:RegisterForDrag('LeftButton')
    overlay:SetScript('OnDragStart', OnDragStart)
    overlay:SetScript('OnDragStop', OnDragStop)
    overlay:SetScript('OnEnter', OnOverlayEnter)
    overlay:SetScript('OnLeave', OnOverlayLeave)
    overlay:SetScript('OnMouseDown', OnOverlayMouseDown)
    overlay:SetScript('OnMouseUp', OnOverlayMouseUp)

    self.overlays[key] = overlay
    self:UpdateOverlay(key)
end

---@param key string
function Anchors:UpdateOverlay(key)
    local overlay = self.overlays[key]
    if not overlay then return end

    local frame = GetEntryFrame(overlay.entry)
    if not frame then
        overlay:Hide()
        return
    end

    -- Only the geometry follows overlayFrame, dragging still reads the entry's own frame, so a chained
    -- group keeps one set of stored offsets. It tracks a live drag because it hangs off that frame.
    overlay:ClearAllPoints()
    overlay:SetAllPoints(overlay.entry.overlayFrame or frame)
    overlay:Show()
end

-- Selection --

---Animates one overlay to the look like its current state calls for.
---@param key string
---@param overlay NRSKNUI.AnchorOverlay
local function ApplyOverlayState(key, overlay)
    local selected = (Anchors.selectedKey == key)

    -- Border colour, selection outranks hover.
    local color = Theme.accent
    if selected then
        color = WHITE
    elseif overlay.isHovered then
        color = Theme.textSecondary
    end
    overlay.animateBorder(color[1], color[2], color[3], 1)

    if selected then
        overlay.text:SetTextColor(1, 1, 1, 1)
    else
        overlay.text:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    end

    -- Alpha, shift makes the selection see-through.
    local alpha = 1
    if isDragging and dragEntry and dragEntry.key == key then
        alpha = DRAG_ALPHA
    elseif selected then
        if Anchors.isShiftFaded then alpha = SHIFT_FADE_ALPHA end
    elseif Anchors.selectedKey then
        alpha = UNSELECTED_ALPHA
    end
    overlay.fadeTo(alpha)
end

---Re-applies the state look to one overlay.
---@param key string
function Anchors:RefreshOverlayState(key)
    local overlay = self.overlays[key]
    if overlay then ApplyOverlayState(key, overlay) end
end

---Re-applies the state look to every live overlay.
function Anchors:RefreshOverlayStates()
    for key, overlay in pairs(self.overlays) do
        ApplyOverlayState(key, overlay)
    end
end

---@param key string?
function Anchors:Select(key)
    self.selectedKey = key
    if not key then self.isShiftFaded = false end

    self:RefreshOverlayStates()
    self:UpdatePanel()
end

---Moves the selected anchor by a whole-number offset delta.
---@param deltaX number
---@param deltaY number
function Anchors:Nudge(deltaX, deltaY)
    if not self.selectedKey then
        NRSKNUI:Print('No anchor selected. Click an overlay to select it.')
        return
    end

    -- SetOffsets re-syncs the overlay, the panel and the GUI sliders.
    local x, y = self:GetOffsets(self.selectedKey)
    self:SetOffsets(self.selectedKey, x + deltaX, y + deltaY)
end

-- Shift fade --

function Anchors:ApplyShiftFade(fade)
    if self.isShiftFaded == fade then return end
    self.isShiftFaded = fade
    if not self.selectedKey then return end

    self:RefreshOverlayState(self.selectedKey)
end

-- Session handlers --

-- Above the nudge panel, its offset boxes take the keyboard the moment an anchor is selected.
local keyHandler = CreateFrame('Frame', 'NRSKNUI_AnchorsKeys', UIParent)
keyHandler:SetFrameStrata('TOOLTIP')
keyHandler:SetFrameLevel(10000)
keyHandler:Hide()
keyHandler:EnableKeyboard(true)
keyHandler:SetPropagateKeyboardInput(true)

local NUDGE_KEYS = {
    LEFT = { -1, 0 },
    RIGHT = { 1, 0 },
    UP = { 0, 1 },
    DOWN = { 0, -1 },
}

keyHandler:SetScript('OnKeyDown', function(self, key)
    -- Typing in an offset box owns the keyboard, arrows move its cursor there.
    if GetCurrentKeyBoardFocus() then
        self:SetPropagateKeyboardInput(true)
        return
    end

    if key == 'ESCAPE' then
        self:SetPropagateKeyboardInput(false)
        if Anchors.selectedKey then
            Anchors:Select(nil)
        else
            Anchors:Exit()
        end
        return
    end

    local delta = NUDGE_KEYS[key]
    if delta and Anchors.selectedKey then
        self:SetPropagateKeyboardInput(false)
        local step = IsShiftKeyDown() and 10 or 1
        Anchors:Nudge(delta[1] * step, delta[2] * step)
        return
    end

    self:SetPropagateKeyboardInput(true)
end)

local eventHandler = CreateFrame('Frame')
eventHandler:SetScript('OnEvent', function(_, event, key)
    if event == 'PLAYER_REGEN_DISABLED' then
        if Anchors.isActive then
            NRSKNUI:Print('Anchors closed due to entering combat.')
            Anchors:Exit()
        end
    elseif event == 'MODIFIER_STATE_CHANGED' then
        if key == 'LSHIFT' or key == 'RSHIFT' then
            Anchors:ApplyShiftFade(IsShiftKeyDown())
        end
    end
end)

-- Lifecycle --

function Anchors:Enter()
    if self.isActive then return end
    if NRSKNUI:InCombat() then
        NRSKNUI:Print('Cannot open Anchors during combat.')
        return
    end

    self.isActive = true

    if NRSKNUI.PreviewManager then
        NRSKNUI.PreviewManager:SetAnchorsActive(true)
    end

    for key in pairs(self.registry) do
        self:CreateOverlay(key)
    end

    self.selectedKey = nil
    self.isShiftFaded = false
    self:RefreshOverlayStates()

    ShowGrid()
    FadeOverlays(1)

    keyHandler:Show()
    keyHandler:SetPropagateKeyboardInput(true)
    eventHandler:RegisterEvent('PLAYER_REGEN_DISABLED')
    eventHandler:RegisterEvent('MODIFIER_STATE_CHANGED')

    self:ShowPanel()
end

function Anchors:Exit()
    if not self.isActive then return end
    self.isActive = false

    isDragging = false
    dragUpdateFrame:Hide()
    dragEntry = nil

    self:Select(nil)
    self.isShiftFaded = false

    HideGrid()
    if NRSKNUI.PreviewManager then NRSKNUI.PreviewManager:SetAnchorsActive(false) end

    FadeOverlays(0)

    keyHandler:Hide()
    eventHandler:UnregisterAllEvents()
    self:HidePanel()
end

function Anchors:Toggle()
    if self.isActive then
        self:Exit()
    else
        self:Enter()
    end
end

function Anchors:IsActive()
    return self.isActive
end

-- Nudge Panel --

local panel
local panelFader
function Anchors:CreatePanel()
    if panel then return panel end

    local GUI = NRSKNUI.GUI
    if not GUI then return nil end

    panel = CreateFrame('Frame', 'NRSKNUI_AnchorsPanel', UIParent, 'BackdropTemplate')
    panel:SetSize(180, 180)
    panel:SetPoint('CENTER', UIParent, 'CENTER', 200, 0)
    panel:SetFrameStrata('FULLSCREEN_DIALOG')
    panel:SetFrameLevel(1001)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag('LeftButton')
    panel:SetScript('OnDragStart', panel.StartMoving)
    panel:SetScript('OnDragStop', panel.StopMovingOrSizing)
    panel:SetBackdrop({
        bgFile = 'Interface\\Buttons\\WHITE8X8',
        edgeFile = 'Interface\\Buttons\\WHITE8X8',
        edgeSize = 1,
    })
    panel:SetBackdropColor(Theme.bgLight[1], Theme.bgLight[2], Theme.bgLight[3], 1)
    panel:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    local title = panel:CreateFontString(nil, 'OVERLAY')
    title:SetPoint('TOP', panel, 'TOP', 0, -6)
    title:SetFont(NRSKNUI.Media.Fonts.Expressway, 16, 'OUTLINE')
    title:SetShadowOffset(0, 0)
    title:SetShadowColor(0, 0, 0, 0)
    title:SetText('Nudge Tool')
    title:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)

    local selected = panel:CreateFontString(nil, 'OVERLAY')
    selected:SetPoint('TOP', title, 'BOTTOM', 0, -2)
    selected:SetFont(NRSKNUI.Media.Fonts.Expressway, 12, 'OUTLINE')
    selected:SetShadowOffset(0, 0)
    selected:SetShadowColor(0, 0, 0, 0)
    selected:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    panel.selected = selected

    local function CommitOffsets()
        if not Anchors.selectedKey then return end
        local x = tonumber(panel.xBox:GetValue())
        local y = tonumber(panel.yBox:GetValue())
        if not x or not y then
            Anchors:UpdatePanel()
            return
        end

        -- SetOffsets re-syncs the overlay, the panel and the GUI sliders.
        Anchors:SetOffsets(Anchors.selectedKey, x, y)
    end

    local xBox = GUI:CreateEditBox(panel, 'X Offset:', { inlineLabel = true, labelWidth = 60, callback = CommitOffsets })
    xBox:SetPoint('TOPLEFT', panel, 'TOPLEFT', 10, -46)
    xBox:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', -10, -46)
    panel.xBox = xBox

    local yBox = GUI:CreateEditBox(panel, 'Y Offset:', { inlineLabel = true, labelWidth = 60, callback = CommitOffsets })
    yBox:SetPoint('TOPLEFT', xBox, 'BOTTOMLEFT', 0, -4)
    yBox:SetPoint('TOPRIGHT', xBox, 'BOTTOMRIGHT', 0, -4)
    panel.yBox = yBox

    -- Left, up, down, right in a single row.
    local ARROWS = {
        { rotation = -90, dx = -1, dy = 0 },
        { rotation = 180, dx = 0,  dy = 1 },
        { rotation = 0,   dx = 0,  dy = -1 },
        { rotation = 90,  dx = 1,  dy = 0 },
    }

    local buttonSize, gap = 26, 4
    local rowWidth = #ARROWS * buttonSize + (#ARROWS - 1) * gap
    panel.arrows = {}

    for index, arrow in ipairs(ARROWS) do
        local button = GUI:CreateButton(panel, '', {
            width = buttonSize,
            height = buttonSize,
            image = ARROW_TEXTURE,
            imageSize = buttonSize - 6,
            imageRotation = math_rad(arrow.rotation),
            imageColor = Theme.accent,
            bgColor = Theme.bgDark,
            callback = function()
                local step = IsShiftKeyDown() and 10 or 1
                Anchors:Nudge(arrow.dx * step, arrow.dy * step)
            end,
        })
        button:SetPoint('TOPLEFT', panel, 'TOP', -rowWidth / 2 + (index - 1) * (buttonSize + gap), -110)
        panel.arrows[index] = button
    end

    local settings = GUI:CreateButton(panel, 'Open Settings', {
        width = 160,
        height = 24,
        bgColor = Theme.bgDark,
        callback = function() Anchors:OpenSelectedSettings() end,
    })
    settings:SetPoint('BOTTOM', panel, 'BOTTOM', 0, 8)
    panel.settings = settings

    panel:Hide()
    panelFader = CreateFader(panel)
    return panel
end

function Anchors:UpdatePanel()
    if not panel then return end

    local entry = self.selectedKey and self.registry[self.selectedKey]

    if not entry then
        panel.selected:SetText('Click to select')
        panel.selected:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        panel.xBox:SetValue('--')
        panel.yBox:SetValue('--')
        panel.xBox:SetEnabled(false)
        panel.yBox:SetEnabled(false)
        panel.settings:SetEnabled(false)
        panel.settings:SetAlpha(0.4)
        for _, arrow in ipairs(panel.arrows) do
            arrow:SetEnabled(false)
            arrow:SetAlpha(0.4)
        end
        return
    end

    panel.selected:SetText(entry.displayName)
    panel.selected:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    panel.xBox:SetEnabled(true)
    panel.yBox:SetEnabled(true)
    panel.settings:SetEnabled(true)
    panel.settings:SetAlpha(1)
    for _, arrow in ipairs(panel.arrows) do
        arrow:SetEnabled(true)
        arrow:SetAlpha(1)
    end

    local x, y = self:GetOffsets(self.selectedKey)
    panel.xBox:SetValue(format('%d', x))
    panel.yBox:SetValue(format('%d', y))
end

function Anchors:ShowPanel()
    if not panel then self:CreatePanel() end
    if not panel then return end
    -- Populate before fading in, so the panel doesn't animate up showing stale values.
    self:UpdatePanel()
    panelFader(1)
end

function Anchors:HidePanel()
    if panelFader then panelFader(0) end
end

function Anchors:OpenSelectedSettings()
    if not self.selectedKey then
        NRSKNUI:Print('No anchor selected.')
        return
    end

    local entry = self.registry[self.selectedKey]
    local GUIFrame = NRSKNUI.GUIFrame
    if not entry or not GUIFrame then return end

    if not GUIFrame:IsShown() then GUIFrame:Show() end
    if not entry.guiPath then return end

    -- ShowPage expects a { tabId, itemKey } target, a bare context names the item.
    local context = entry.guiContext
    if type(context) == 'string' then context = { itemKey = context } end

    -- ShowPage resolves and expands the owning sidebar header itself.
    GUIFrame:ShowPage(entry.guiPath, context)
end

---Called by the GUI (via services.positionSync) when a PositionCard edits a position,
---so the overlay geometry and the panel readout follow the sliders. The module has
---already re-applied by then, so this only re-reads.
function Anchors:OnExternalPositionChange()
    if not self.isActive then return end

    for key in pairs(self.registry) do
        self:UpdateOverlay(key)
    end
    self:UpdatePanel()
end

---Re-themes live overlays and the panel after a theme change.
function Anchors:RefreshTheme()
    if not self.isActive then return end

    for _, overlay in pairs(self.overlays) do
        overlay:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], FILL_ALPHA)
    end
    self:RefreshOverlayStates()

    if panel then
        panel:SetBackdropColor(Theme.bgLight[1], Theme.bgLight[2], Theme.bgLight[3], 1)
        panel:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
        self:UpdatePanel()
    end
end

--[[
# FrameChooser

* A themed on-screen picker: the user hovers any frame in the UI and clicks to hand its name back to whatever asked for it (PositionCard's "Anchored To -> Select Frame").
* Only a frame reachable as `_G[name]` can be picked, since that is how the stored name is resolved again, anonymous frames resolve to their nearest named ancestor.

Access the frame chooser through the `InstanceMixin` of the `LibKaji-1.0` library:
* ns.GUI = _G.LibStub('LibKaji-1.0'):New()  -- Core file
* local GUI = ns.GUI                        -- Usage files calls like this

# FrameChooser APIs

API: GUI:GetFrameChooser()
* Returns the instance's chooser, building it on first use.

API: chooser:Start(callback, initialValue)
* Enters picking mode. The callback fires on every hover as a preview, then once more on confirm or cancel.

API: chooser:Stop(cancelled)
* Leaves picking mode. Called for you on click, only needed to abort from outside.

API: chooser:IsActive()
* Whether picking mode is running.

## Example

    local chooser = GUI:GetFrameChooser()
    chooser:Start(function(name, isPreview)
        if not name then return end
        editBox:SetValue(name)
        if not isPreview then db.ParentFrame = name end
    end, db.ParentFrame)

--]]

---@class LibKaji-1.0
local lib = _G.LibStub and _G.LibStub('LibKaji-1.0', true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel

local _G = _G
local CreateFrame = CreateFrame
local IsMouseButtonDown = IsMouseButtonDown
local GetMouseFoci = GetMouseFoci
local GetMouseFocus = GetMouseFocus
local SetCursor = SetCursor
local ResetCursor = ResetCursor
local UIParent = UIParent
local WorldFrame = WorldFrame
local setmetatable = setmetatable

local WHITE = 'Interface\\Buttons\\WHITE8X8'

local BORDER_SIZE = 2
local FILL_ALPHA = 0.2
local BOX_INSET = 4 -- how far outside the target's edges the highlight sits
local PLATE_PADDING = 10
local PLATE_HEIGHT = 24
local PLATE_GAP = 6
local BANNER_WIDTH = 330
local BANNER_HEIGHT = 74
local BANNER_Y = -140

---Nearest self-or-ancestor reachable as `_G[name]`.
---@param frame Frame?
---@return Frame? named, string? name
local function ResolveNamed(frame)
    while frame do
        local name = frame.GetName and frame:GetName()
        if name and name ~= '' and _G[name] == frame then return frame, name end
        frame = frame.GetParent and frame:GetParent() or nil
    end
end

---@param frame Frame?
---@param root Frame?
---@return boolean
local function IsUnder(frame, root)
    if not root then return false end
    while frame do
        if frame == root then return true end
        frame = frame.GetParent and frame:GetParent() or nil
    end
    return false
end

---@return Frame?
local function MouseFocus()
    if GetMouseFoci then
        local foci = GetMouseFoci()
        return foci and foci[1]
    end
    return GetMouseFocus and GetMouseFocus() or nil
end

---@class KajiGUIFrameChooser
---@field gui KajiGUIInstance
---@field active boolean
local Chooser = {}
local ChooserMeta = { __index = Chooser }

function Chooser:_Build()
    if self.host then return end

    -- Mouse stays off so GetMouseFoci reports the frame underneath; the click reaches it too.
    local host = CreateFrame('Frame', nil, UIParent)
    host:SetAllPoints(UIParent)
    host:SetFrameStrata('TOOLTIP')
    host:SetFrameLevel(100)
    host:EnableMouse(false)
    host:Hide()
    host.chooser = self
    self.host = host

    local box = CreateFrame('Frame', nil, host, 'BackdropTemplate')
    box:SetBackdrop({
        bgFile = WHITE,
        edgeFile = WHITE,
        edgeSize = BORDER_SIZE,
        insets = { left = BORDER_SIZE, right = BORDER_SIZE, top = BORDER_SIZE, bottom = BORDER_SIZE },
    })
    box:Hide()
    self.box = box

    -- Parented to the host, not the box, so the box's translucent fill doesn't dim the label.
    local plate = CreateFrame('Frame', nil, host, 'BackdropTemplate')
    plate:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    pixel.SetPixelHeight(plate, PLATE_HEIGHT)
    plate.text = plate:CreateFontString(nil, 'OVERLAY')
    pixel.SetPixelPoint(plate.text, 'CENTER')
    plate:Hide()
    self.plate = plate

    local banner = CreateFrame('Frame', nil, host, 'BackdropTemplate')
    banner:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    pixel.SetPixelSize(banner, BANNER_WIDTH, BANNER_HEIGHT)
    pixel.SetPixelPoint(banner, 'TOP', host, 'TOP', 0, BANNER_Y)

    banner.title = banner:CreateFontString(nil, 'OVERLAY')
    pixel.SetPixelPoint(banner.title, 'TOP', banner, 'TOP', 0, -8)

    banner.confirm = banner:CreateFontString(nil, 'OVERLAY')
    pixel.SetPixelPoint(banner.confirm, 'TOP', banner.title, 'BOTTOM', 0, -8)

    banner.cancel = banner:CreateFontString(nil, 'OVERLAY')
    pixel.SetPixelPoint(banner.cancel, 'TOP', banner.confirm, 'BOTTOM', 0, -4)
    self.banner = banner

    host:SetScript('OnKeyDown', function(_, key)
        if key ~= 'ESCAPE' then
            host:SetPropagateKeyboardInput(true)
            return
        end
        host:SetPropagateKeyboardInput(false)
        self:Stop(true)
    end)
end

-- Read at Start rather than subscribed to: one pick cannot span a theme change.
function Chooser:_ApplyTheme()
    local gui = self.gui
    local ar, ag, ab = gui:Color('accent')

    self.box:SetBackdropColor(ar, ag, ab, FILL_ALPHA)
    self.box:SetBackdropBorderColor(ar, ag, ab, 1)

    self.plate:SetBackdropColor(gui:Color('bgLight'))
    self.plate:SetBackdropBorderColor(gui:Color('border'))
    gui:ApplyFont(self.plate.text, 'small')

    local banner = self.banner
    banner:SetBackdropColor(gui:Color('bgLight'))
    banner:SetBackdropBorderColor(gui:Color('border'))

    gui:ApplyFont(banner.title, 'large')
    banner.title:SetTextColor(ar, ag, ab, 1)
    banner.title:SetText('Frame Chooser')

    gui:ApplyFont(banner.confirm, 'normal')
    banner.confirm:SetTextColor(gui:Color('textSecondary'))
    banner.confirm:SetText(gui:ColorText('Left-click') .. ' to select the highlighted frame')

    gui:ApplyFont(banner.cancel, 'normal')
    banner.cancel:SetTextColor(gui:Color('textSecondary'))
    banner.cancel:SetText(gui:ColorText('Right-click') .. ' or ' .. gui:ColorText('Esc') .. ' to cancel')
end

---Frames the chooser must never hand back: its own overlay and the window the pick came from.
---@param frame Frame
---@return boolean
function Chooser:_IsBlocked(frame)
    if frame == WorldFrame or IsUnder(frame, self.host) then return true end
    local window = self.gui._window
    if window and IsUnder(frame, window.frame) then return true end
    return IsUnder(frame, self.gui.overlay)
end

---Places the highlight from the target's rect, so the box never joins a protected anchor family.
---@return number? top the box's top edge, in host coordinates
function Chooser:_UpdateBox()
    local target = self.target
    if not target or not target.GetRect then return end

    local left, bottom, width, height = target:GetRect()
    if not left or not width or width <= 0 or height <= 0 then
        self.box:Hide()
        self.plate:Hide()
        return
    end

    local box = self.box
    local scale = target:GetEffectiveScale() / box:GetEffectiveScale()
    local inset = BOX_INSET * pixel.GetBestPixelSize()

    box:ClearAllPoints()
    pixel.SetPixelPoint(box, 'BOTTOMLEFT', self.host, 'BOTTOMLEFT', left * scale - inset, bottom * scale - inset)
    pixel.SetPixelSize(box, width * scale + inset * 2, height * scale + inset * 2)
    box:Show()

    return (bottom + height) * scale + inset
end

---@param focus Frame?
function Chooser:_SetTarget(focus)
    local target, name
    if focus and not self:_IsBlocked(focus) then
        target, name = ResolveNamed(focus)
    end

    -- `exact` is in the key so stepping from an anonymous child onto the named frame restyles.
    local exact = focus == target
    if target == self.target and name == self.targetName and exact == self.exact then return end
    self.target, self.targetName, self.exact = target, name, exact

    if not target then
        self.box:Hide()
        self.plate:Hide()
        return
    end

    -- The box has to be placed before the plate, which picks its side from the box's top edge.
    local top = self:_UpdateBox()
    if not top then return end

    local label = self.plate.text
    label:SetText(name)
    -- Muted when the hover resolved to an ancestor rather than the frame under the cursor.
    label:SetTextColor(self.gui:Color(exact and 'accent' or 'textSecondary'))
    pixel.SetPixelWidth(self.plate, label:GetStringWidth() + PLATE_PADDING * 2)

    self.plate:ClearAllPoints()
    if top + PLATE_HEIGHT + PLATE_GAP > self.host:GetHeight() then
        pixel.SetPixelPoint(self.plate, 'TOP', self.box, 'BOTTOM', 0, -PLATE_GAP)
    else
        pixel.SetPixelPoint(self.plate, 'BOTTOM', self.box, 'TOP', 0, PLATE_GAP)
    end
    self.plate:Show()
end

local function OnUpdate(host)
    local self = host.chooser
    if not self.active then return end

    local left = IsMouseButtonDown('LeftButton')
    local right = IsMouseButtonDown('RightButton')

    -- The press that opened the chooser must not also count as the pick.
    if not self.armed then
        if not left and not right then self.armed = true end
    elseif right then
        self:Stop(true)
        return
    elseif left then
        if self.targetName then self:Stop(false) end
        return
    end

    local focus = MouseFocus()
    if focus ~= self.lastFocus then
        self.lastFocus = focus
        -- Re-applying every frame restarts the cast cursor's glow, which reads as a flicker.
        SetCursor('CAST_CURSOR')
        self:_SetTarget(focus)
        if self.callback then self.callback(self.targetName, true) end
    elseif self.target then
        self:_UpdateBox()
    end
end

---Enters picking mode.
---@param callback fun(frameName: string?, isPreview: boolean)
---@param initialValue? string restored through the callback when the pick is cancelled
function Chooser:Start(callback, initialValue)
    if self.active then self:Stop(true) end

    self:_Build()
    self:_ApplyTheme()

    self.active = true
    self.armed = false
    self.callback = callback
    self.initialValue = initialValue
    self.lastFocus = nil
    self.target = nil
    self.targetName = nil

    -- The window covers most of what is worth picking, so it steps aside until the pick lands.
    local window = self.gui._window
    self.restoreWindow = window and window:IsShown() or false
    if self.restoreWindow then window:Hide() end

    self.box:Hide()
    self.plate:Hide()
    self.host:EnableKeyboard(true)
    self.host:SetPropagateKeyboardInput(true)
    self.host:SetScript('OnUpdate', OnUpdate)
    self.host:Show()

    SetCursor('CAST_CURSOR') -- After the hide, which fires OnLeave on the clicked button and resets it
end

---Leaves picking mode, reporting the pick (or the value it started with) to the callback.
---@param cancelled? boolean
function Chooser:Stop(cancelled)
    if not self.active then return end
    self.active = false

    local host = self.host
    host:SetScript('OnUpdate', nil)
    host:EnableKeyboard(false)
    host:SetPropagateKeyboardInput(true)
    host:Hide()
    self.box:Hide()
    self.plate:Hide()
    ResetCursor()

    local callback = self.callback
    local value = cancelled and self.initialValue or self.targetName
    local restoreWindow = self.restoreWindow

    self.callback = nil
    self.initialValue = nil
    self.lastFocus = nil
    self.target = nil
    self.targetName = nil
    self.restoreWindow = false

    -- Callback first: reopening the window rebuilds its page, which has to read the committed value.
    if callback then callback(value, false) end

    if restoreWindow then
        local window = self.gui._window
        if window then window:Show() end
    end
end

---@return boolean
function Chooser:IsActive()
    return self.active and true or false
end

---The instance's frame chooser, built on first use.
---@return KajiGUIFrameChooser
function InstanceMixin:GetFrameChooser()
    local chooser = self._frameChooser
    if not chooser then
        chooser = setmetatable({ gui = self, active = false }, ChooserMeta)
        self._frameChooser = chooser
    end
    return chooser
end

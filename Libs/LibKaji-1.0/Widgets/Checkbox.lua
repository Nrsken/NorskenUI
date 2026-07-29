--[[
# Checkbox

* An animated on/off toggle with a sliding knob, a label, optional tooltip and an optional flash message on change.

## Example

    row:Checkbox('Enable', {
        width = 0.5,
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
        end,
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local Animations = lib.Animations
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local Mixin = Mixin
local select = select
local type = type
local abs = math.abs

local C_Timer = C_Timer

local WIDGET_TYPE = "Checkbox"
local TOGGLE_WIDTH = 48
local TOGGLE_HEIGHT = 24
local KNOB_SIZE = 22
local KNOB_CROSS = 22
local KNOB_PADDING = 1
local ANIMATION_DURATION = 0.18
local OFF_POSITION = KNOB_PADDING
local ON_POSITION = TOGGLE_WIDTH - KNOB_SIZE - KNOB_PADDING

---@class KajiGUICheckboxMixin : Frame
---@field gui KajiGUIInstance
---@field label FontString
---@field toggle Frame|BackdropTemplate
---@field knob Frame|BackdropTemplate
---@field knobTexture Texture
---@field checkmark Texture
---@field crossmark Texture
---@field button Button
---@field animGroup AnimationGroup
---@field slideAnim Animation
---@field _state boolean
---@field _animating boolean
---@field _targetX number
---@field _callback? fun(checked: boolean, revert?: fun(shouldRevert: boolean))
---@field _msgPopup? boolean
---@field _msgText? string
---@field _msgOn string
---@field _msgOff string
local CheckboxMixin = {}

function CheckboxMixin:UpdateIcons()
    if self._state then
        self.checkmark:Show()
        self.crossmark:Hide()
        self.checkmark:SetVertexColor(1, 1, 1, 1)
    else
        self.checkmark:Hide()
        self.crossmark:Show()
        self.crossmark:SetVertexColor(1, 1, 1, 0.8)
    end
end

---Paints the track and knob for a state, tweening unless `instant`.
---@param toState boolean
---@param instant boolean
function CheckboxMixin:ApplyStateColors(toState, instant)
    local theme = self.gui.theme
    self:UpdateIcons()

    local bgR, bgG, bgB, knobA
    if toState then
        bgR, bgG, bgB, knobA = theme.accent[1] * 0.5, theme.accent[2] * 0.5, theme.accent[3] * 0.5, 1
    else
        bgR, bgG, bgB, knobA = theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], 0.4
    end
    local kr, kg, kb = theme.accent[1], theme.accent[2], theme.accent[3]

    if instant then
        self.toggle:SetBackdropColor(bgR, bgG, bgB, 1)
        self._syncBg(bgR, bgG, bgB)
        self.knobTexture:SetColorTexture(kr, kg, kb, knobA)
        self._syncKnob(kr, kg, kb, knobA)
    else
        self._animateBg(bgR, bgG, bgB)
        self._animateKnob(kr, kg, kb, knobA)
    end
end

---@param toState boolean
---@param instant? boolean
function CheckboxMixin:AnimateToState(toState, instant)
    if self._animating and not instant then return end

    self._animating = true
    self._state = toState

    local targetX = toState and ON_POSITION or OFF_POSITION
    local currentX = select(4, self.knob:GetPoint())
    local deltaX = targetX - currentX
    self._targetX = targetX

    if instant or abs(deltaX) < 1 then
        self.knob:ClearAllPoints()
        pixel.SetPixelPoint(self.knob, "LEFT", self.toggle, "LEFT", targetX, 0)
        self:ApplyStateColors(toState, true)
        self._animating = false
    else
        self:ApplyStateColors(toState, false)

        self.animGroup:Stop()
        self.knob:ClearAllPoints()
        pixel.SetPixelPoint(self.knob, "LEFT", self.toggle, "LEFT", currentX, 0)
        self.slideAnim:SetOffset(deltaX, 0)
        self.animGroup:Play()
    end
end

---@param enabled boolean
function CheckboxMixin:SetEnabled(enabled)
    self.toggle:SetAlpha(enabled and 1 or 0.5)
    self.label:SetAlpha(enabled and 1 or 0.5)
    self.button:EnableMouse(enabled)
end

---@return boolean
function CheckboxMixin:GetValue()
    return self._state
end

---@param value boolean
---@param instant? boolean
function CheckboxMixin:SetValue(value, instant)
    if value == self._state then return end
    self:AnimateToState(value, instant)
    if self._callback and not instant then
        local alive = lib.Generation(self)
        C_Timer.After(ANIMATION_DURATION, function()
            if alive() then safecall(self._callback, value) end
        end)
    end
end

function CheckboxMixin:UpdateColors()
    local theme = self.gui.theme
    lib.RefreshBackdrop(self.toggle)
    lib.RefreshBackdrop(self.knob)
    self.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    self.checkmark:SetTexture(theme.checkTexture)
    self.crossmark:SetTexture(theme.crossTexture)
    -- Repaint from the current state so the track and knob land on the new palette.
    self:ApplyStateColors(self._state, true)
end

---@param parent Frame
---@param labelText? string
---@param config table
function CheckboxMixin:OnAcquire(parent, labelText, config)
    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelHeight(self, 36)

    self.label:SetText(labelText or "")
    self._callback = config.callback
    self._msgPopup = config.msgPopup
    self._msgText = config.msgText
    self._msgOn = config.msgOn or "Enabled"
    self._msgOff = config.msgOff or "Disabled"

    -- The "Default: x" line is only meaningful for a cvar-backed checkbox.
    local spec = config.tooltip
    if type(spec) == "table" and not config.cvartooltip then
        spec = { text = spec.text }
    end
    lib.SetTooltip(self, self.gui, labelText, spec)

    self._animating = false
    self._state = not (config.value or false) -- force AnimateToState to settle the visuals
    self:AnimateToState(config.value or false, true)

    self.button:EnableMouse(true)
    self.toggle:SetAlpha(1)
    self.label:SetAlpha(1)
    self:SetAlpha(1)
    self:UpdateColors()
    self:Show()

    self.gui:RegisterSearchableWidget(self, labelText)
end

function CheckboxMixin:OnRelease()
    -- Stopping the slide matters as much as dropping the callback: a running animation
    -- would finish on top of whatever configures this widget next.
    self.animGroup:Stop()
    self._animating = false
    self._callback = nil
    self._msgPopup = nil
    self._msgText = nil
    self.label:SetText("")
    lib.ClearTooltip(self)
end

---@class KajiGUICheckbox : KajiGUICheckboxMixin

---@class KajiGUICheckboxConfig
---@field value? boolean
---@field callback? fun(checked: boolean, revert?: fun(shouldRevert: boolean))
---@field msgPopup? boolean flash a message on change
---@field msgText? string message prefix
---@field msgOn? string
---@field msgOff? string
---@field tooltip? any
---@field cvartooltip? boolean show the default value in the tooltip

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local theme = gui.theme

    local row = CreateFrame("Frame", nil, gui._poolHost)
    row.gui = gui

    local label = row:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    gui:ApplyFont(label, "small")
    label:SetShadowColor(0, 0, 0, 0)
    row.label = label

    local toggle = CreateFrame("Frame", nil, row, "BackdropTemplate")
    pixel.SetPixelSize(toggle, TOGGLE_WIDTH, TOGGLE_HEIGHT)
    pixel.SetPixelPoint(toggle, "TOPLEFT", row, "TOPLEFT", 0, -14)
    lib.SetBackdrop(toggle, gui, { bg = "bgMedium", bgAlpha = 0.9, border = "border", borderAlpha = 1 })
    row.toggle = toggle

    local knob = CreateFrame("Frame", nil, toggle, "BackdropTemplate")
    pixel.SetPixelSize(knob, KNOB_SIZE, KNOB_SIZE)
    pixel.SetPixelPoint(knob, "LEFT", toggle, "LEFT", OFF_POSITION, 0)
    lib.SetBackdrop(knob, gui, {
        bg = { 0, 0, 0 },
        bgAlpha = 0.9,
        border = "border",
        borderAlpha = 1,
        insets = { left = -1, right = -1, top = 0, bottom = 0 },
    })
    row.knob = knob

    local knobTexture = knob:CreateTexture(nil, "ARTWORK")
    knobTexture:SetAllPoints()
    pixel.SetPixelSnap(knobTexture)
    row.knobTexture = knobTexture

    local checkmark = knob:CreateTexture(nil, "OVERLAY")
    pixel.SetPixelSize(checkmark, KNOB_SIZE, KNOB_SIZE)
    pixel.SetPixelPoint(checkmark, "CENTER", knob, "CENTER", 0, 0)
    checkmark:SetTexture(theme.checkTexture)
    pixel.SetPixelSnap(checkmark)
    checkmark:Hide()
    row.checkmark = checkmark

    local crossmark = knob:CreateTexture(nil, "OVERLAY")
    pixel.SetPixelSize(crossmark, KNOB_CROSS, KNOB_CROSS)
    pixel.SetPixelPoint(crossmark, "CENTER", knob, "CENTER", 0, 0)
    crossmark:SetTexture(theme.crossTexture)
    pixel.SetPixelSnap(crossmark)
    crossmark:Hide()
    row.crossmark = crossmark

    local animGroup = knob:CreateAnimationGroup()
    local slideAnim = animGroup:CreateAnimation("Translation")
    slideAnim:SetDuration(ANIMATION_DURATION)
    slideAnim:SetSmoothing("OUT")
    row.animGroup = animGroup
    row.slideAnim = slideAnim

    -- Track and knob tween separately so each can animate on its own.
    row._animateBg, row._syncBg = Animations:CreateColorAnimator(toggle,
        function(r, g, b) toggle:SetBackdropColor(r, g, b, 1) end,
        { theme.bgDark[1], theme.bgDark[2], theme.bgDark[3] }, ANIMATION_DURATION)
    row._animateKnob, row._syncKnob = Animations:CreateColorAnimator(knob,
        function(r, g, b, a) knobTexture:SetColorTexture(r, g, b, a) end,
        { theme.accent[1], theme.accent[2], theme.accent[3], 0.6 }, ANIMATION_DURATION)

    local button = CreateFrame("Button", nil, toggle)
    button:SetAllPoints(toggle)
    button:RegisterForClicks("LeftButtonUp")
    row.button = button

    Mixin(row, CheckboxMixin)

    animGroup:SetScript("OnFinished", function()
        knob:ClearAllPoints()
        pixel.SetPixelPoint(knob, "LEFT", toggle, "LEFT", row._targetX, 0)
        row._animating = false
        row:UpdateIcons()
    end)

    button:SetScript("OnClick", function()
        if animGroup:IsPlaying() then return end

        local newState = not row._state
        row:AnimateToState(newState, false)

        if row._callback then
            -- The callback lands after the slide finishes, by which time a page change
            -- could have recycled this widget, the guard keeps it off the new owner.
            local alive = lib.Generation(row)
            C_Timer.After(ANIMATION_DURATION, function()
                if not alive() then return end
                safecall(row._callback, newState, function(revert)
                    if revert then row:AnimateToState(not newState, false) end
                end)
            end)
        end

        if row._msgPopup then
            local msgConfig = {
                parent = _G.NorskenUIGUIFrame or UIParent,
                duration = 2,
                size = 14,
                y = _G.NorskenUIGUIFrame and -12 or 400,
                anchorFrom = _G.NorskenUIGUIFrame and "TOP" or "CENTER",
                anchorTo = _G.NorskenUIGUIFrame and "TOP" or "CENTER"
            }
            local suffix = newState and ("|cff4DCC66" .. row._msgOn .. "|r") or ("|cffE64D4D" .. row._msgOff .. "|r")
            row.gui:FlashMessage((row._msgText or "") .. ": " .. suffix, msgConfig)
        end
    end)

    -- One handler per event doing both the knob highlight and the tooltip, rather than
    -- layering the tooltip on top by wrapping these scripts (see lib.SetTooltip).
    button:SetScript("OnEnter", function()
        local accent = row.gui.theme.accent
        local baseA = row._state and 1 or 0.6
        local hr, hg, hb = accent[1] * 1.2, accent[2] * 1.2, accent[3] * 1.2
        knobTexture:SetColorTexture(hr, hg, hb, baseA)
        row._syncKnob(hr, hg, hb, baseA)
        lib.ShowTooltip(row)
    end)
    button:SetScript("OnLeave", function()
        local accent = row.gui.theme.accent
        local a = row._state and 1 or 0.4
        knobTexture:SetColorTexture(accent[1], accent[2], accent[3], a)
        row._syncKnob(accent[1], accent[2], accent[3], a)
        lib.HideTooltip()
    end)

    return row
end)

---@param parent Frame
---@param labelText? string
---@param config? KajiGUICheckboxConfig
---@return KajiGUICheckbox
function InstanceMixin:CreateCheckbox(parent, labelText, config)
    return self:BuildWidget(WIDGET_TYPE, parent, labelText, config)
end

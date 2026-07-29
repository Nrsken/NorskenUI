--[[
# Slider

* A horizontal slider with stepper buttons and an editable value box.

## Examples

    row:Slider('Thickness', {
        width = 0.5,
        min = 3,
        max = 20,
        step = 1,
        value = db.Thickness,
        callback = function(v)
            db.Thickness = v
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

local tostring = tostring
local tonumber = tonumber
local CreateFrame = CreateFrame
local Mixin = Mixin
local GetTime = GetTime
local ipairs = ipairs
local type = type
local rad = math.rad
local floor, max, min = math.floor, math.max, math.min

local C_Timer = C_Timer

local WIDGET_TYPE = "Slider"
local THUMB_WIDTH, THUMB_HEIGHT = 19, 12
local STEPPER_SIZE = 20
local THROTTLE_DELAY = 0.1

---@class KajiGUISliderMixin : Frame
---@field gui KajiGUIInstance
---@field label FontString
---@field slider Slider
---@field sliderBG Frame|BackdropTemplate
---@field fill Texture
---@field thumb Texture
---@field thumbFrame Frame|BackdropTemplate
---@field thumbFrameBG Frame|BackdropTemplate
---@field leftStepper Button
---@field rightStepper Button
---@field valueContainer Frame|BackdropTemplate
---@field valueEdit EditBox
---@field _step number
---@field _callback? fun(value: number)
---@field _callbackOnRelease? boolean
---@field _dragging boolean
---@field _updating boolean
---@field _suppressCallback boolean
---@field _lastUpdate number
---@field _thumbSyncPending boolean
local SliderMixin = {}

---Re-trues the thumb's sub-pixel offset against the pixel grid.
function SliderMixin:UpdateThumbPosition()
    local dx = 0
    local thumbCenter = self.thumb:GetCenter()
    local sliderLeft = self.slider:GetLeft()
    if thumbCenter and sliderLeft then
        local left = (thumbCenter - sliderLeft) - THUMB_WIDTH / 2
        dx = pixel.ToPixelGrid(left) - left
    end
    self.thumbFrameBG:ClearAllPoints()
    self.thumbFrameBG:SetPoint("CENTER", self.thumb, "CENTER", dx, 0)
    self.thumbFrame:ClearAllPoints()
    self.thumbFrame:SetPoint("CENTER", self.thumb, "CENTER", dx, 0)
end

function SliderMixin:UpdateFill()
    local val = self.slider:GetValue()
    local minVal, maxVal = self.slider:GetMinMaxValues()
    if maxVal == minVal then return end

    local pct = (val - minVal) / (maxVal - minVal)
    pixel.SetPixelWidth(self.fill, max(1, (self.slider:GetWidth() - 2) * pct))

    if not self._updating then
        self._updating = true
        self.valueEdit:SetText(tostring(floor(val * 100 + 0.5) / 100))
        self._updating = false
    end
end

---@param toHover boolean
---@param toDrag boolean
function SliderMixin:AnimateThumbColor(toHover, toDrag)
    local theme = self.gui.theme
    if toDrag then
        self._animateThumb(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    elseif toHover then
        self._animateThumb(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    else
        self._animateThumb(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.6)
    end
end

---@param val number
function SliderMixin:FireCallback(val)
    if self._suppressCallback then return end
    safecall(self._callback, val)
end

---@param val number
function SliderMixin:SetValue(val)
    self.slider:SetValue(val)
end

---Updates the displayed value without firing the callback. For syncing a slider
---to a value that was changed elsewhere (e.g. by dragging the frame it controls).
---@param val number
function SliderMixin:SetValueSilent(val)
    self._suppressCallback = true
    self.slider:SetValue(val)
    self._suppressCallback = false
end

---@return number
function SliderMixin:GetValue()
    return self.slider:GetValue()
end

---@param minVal number
---@param maxVal number
function SliderMixin:SetMinMaxValues(minVal, maxVal)
    self.slider:SetMinMaxValues(minVal, maxVal)
    self:UpdateFill()
end

---@param enabled boolean
function SliderMixin:SetEnabled(enabled)
    self:SetAlpha(enabled and 1 or 0.4)
    self.slider:EnableMouse(enabled)
    self.valueEdit:EnableMouse(enabled)
    self.valueContainer:EnableMouse(enabled)
    self.leftStepper:EnableMouse(enabled)
    self.rightStepper:EnableMouse(enabled)
end

---Parses the value box, clamping and wobbling on anything out of range or unparseable.
function SliderMixin:CommitText()
    local num = tonumber(self.valueEdit:GetText())
    if not num then
        Animations:Wobble(self.valueContainer)
        self:UpdateFill()
        return
    end

    local minVal, maxVal = self.slider:GetMinMaxValues()
    local clamped = max(minVal, min(maxVal, num))
    if clamped ~= num then Animations:Wobble(self.valueContainer) end
    self._updating = true
    self.slider:SetValue(clamped)
    self._updating = false
end

function SliderMixin:UpdateColors()
    local theme = self.gui.theme
    lib.RefreshBackdrop(self.sliderBG)
    lib.RefreshBackdrop(self.thumbFrameBG)
    lib.RefreshBackdrop(self.thumbFrame)
    lib.RefreshBackdrop(self.valueContainer)

    self.label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    self.fill:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    self.valueEdit:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)

    for _, stepper in ipairs({ self.leftStepper, self.rightStepper }) do
        stepper.icon:SetTexture(theme.stepperTexture)
        stepper.icon:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    end

    -- Reseat every animator's resting color so the next hover tweens from the new palette.
    self._syncThumb(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.6)
    self._syncLeftStepper(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    self._syncRightStepper(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    self._syncValueBorder(theme.border[1], theme.border[2], theme.border[3], theme.border[4] or 1)
end

---@param parent Frame
---@param labelText? string
---@param config table
function SliderMixin:OnAcquire(parent, labelText, config)
    local sliderMin = config.min or 0
    local sliderMax = config.max or 100
    local step = config.step or 1

    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelHeight(self, 36)

    self.label:SetText(labelText or "")
    self._step = step
    self._callbackOnRelease = config.callbackOnRelease
    self._dragging = false
    self._updating = false
    self._thumbSyncPending = false
    self._lastUpdate = 0

    -- Seeded with the callback suppressed: SetValue fires OnValueChanged, and a fresh
    -- acquire must not look like the user just moved the slider.
    self._callback = nil
    self._suppressCallback = true
    self.slider:SetMinMaxValues(sliderMin, sliderMax)
    self.slider:SetValueStep(step)
    self.slider:SetValue(config.value or sliderMin)
    self._suppressCallback = false
    self._callback = config.callback

    -- The "Default: x" line is only meaningful for a cvar-backed slider.
    local spec = config.tooltip
    if type(spec) == "table" and not config.cvartooltip then
        spec = { text = spec.text }
    end
    lib.SetTooltip(self, self.gui, labelText, spec)

    self:SetEnabled(true)
    self:SetAlpha(1)
    self:UpdateColors()
    self:Show()

    self:UpdateFill()
    local alive = lib.Generation(self)
    C_Timer.After(0, function()
        if not alive() then return end
        self:UpdateFill()
        self:UpdateThumbPosition()
    end)

    self.gui:RegisterSearchableWidget(self, labelText)
end

function SliderMixin:OnRelease()
    self._callback = nil
    self._dragging = false
    self._suppressCallback = false
    self.valueEdit:ClearFocus()
    self.label:SetText("")
    lib.ClearTooltip(self)
end

---@class KajiGUISlider : KajiGUISliderMixin

---@class KajiGUISliderConfig
---@field min? number
---@field max? number
---@field step? number
---@field value? number
---@field callback? fun(value: number)
---@field callbackOnRelease? boolean fire callback only when the drag is released
---@field tooltip? any
---@field cvartooltip? boolean

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local theme = gui.theme

    local row = CreateFrame("Frame", nil, gui._poolHost)
    row.gui = gui

    local label = row:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    gui:ApplyFont(label, "small")
    row.label = label

    local sliderBG = CreateFrame("Frame", nil, row, "BackdropTemplate")
    pixel.SetPixelHeight(sliderBG, 8)
    pixel.SetPixelPoint(sliderBG, "TOPLEFT", row, "TOPLEFT", 68, -22)
    pixel.SetPixelPoint(sliderBG, "TOPRIGHT", row, "TOPRIGHT", -18, -22)
    lib.SetBackdrop(sliderBG, gui, { bg = "bgDark", bgAlpha = 0.9, border = "border", borderAlpha = 1 })
    sliderBG:EnableMouse(false)
    row.sliderBG = sliderBG

    local slider = CreateFrame("Slider", nil, row, "BackdropTemplate")
    pixel.SetPixelHeight(slider, 8)
    pixel.SetPixelPoint(slider, "TOPLEFT", row, "TOPLEFT", 77, -22)
    pixel.SetPixelPoint(slider, "TOPRIGHT", row, "TOPRIGHT", -27, -22)
    slider:SetOrientation("HORIZONTAL")
    slider:SetObeyStepOnDrag(true)
    slider:SetHitRectInsets(-9, -9, -5, -5)
    -- Fully transparent: this frame is only the hit area, sliderBG draws the track.
    lib.SetBackdrop(slider, gui, { bg = { 0, 0, 0 }, bgAlpha = 0, border = { 0, 0, 0 }, borderAlpha = 0 })
    row.slider = slider

    local fill = slider:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelHeight(fill, 6)
    pixel.SetPixelPoint(fill, "LEFT", sliderBG, "LEFT", 1, 0)
    pixel.SetPixelSnap(fill)
    row.fill = fill

    local thumbFrameBG = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    pixel.SetPixelSize(thumbFrameBG, THUMB_WIDTH, THUMB_HEIGHT)
    lib.SetBackdrop(thumbFrameBG, gui, { bg = "bgLight", bgAlpha = 0.9, border = { 0, 0, 0 }, borderAlpha = 1 })
    row.thumbFrameBG = thumbFrameBG

    local thumbFrame = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    pixel.SetPixelSize(thumbFrame, THUMB_WIDTH, THUMB_HEIGHT)
    lib.SetBackdrop(thumbFrame, gui, { bg = "textSecondary", bgAlpha = 0.9, border = { 0, 0, 0 }, borderAlpha = 1 })
    row.thumbFrame = thumbFrame

    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(0, 0, 0, 0)
    slider:SetThumbTexture(thumb)
    row.thumb = thumb

    local function MakeStepper(point, relPoint, rotation)
        local stepper = CreateFrame("Button", nil, row)
        pixel.SetPixelSize(stepper, STEPPER_SIZE, STEPPER_SIZE)
        pixel.SetPixelPoint(stepper, point, sliderBG, relPoint, 0, 0)

        local icon = stepper:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(theme.stepperTexture)
        icon:SetRotation(rad(rotation))
        pixel.SetPixelSnap(icon)
        stepper.icon = icon

        return stepper
    end

    local leftStepper = MakeStepper("RIGHT", "LEFT", -90)
    local rightStepper = MakeStepper("LEFT", "RIGHT", 90)
    row.leftStepper = leftStepper
    row.rightStepper = rightStepper

    local valueContainer = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    pixel.SetPixelSize(valueContainer, 48, 24)
    pixel.SetPixelPoint(valueContainer, "RIGHT", leftStepper, "LEFT", 0, 0)
    lib.SetBackdrop(valueContainer, gui, { bg = "bgDark", bgAlpha = 1, border = "border", borderAlpha = 1 })
    row.valueContainer = valueContainer

    local valueEdit = CreateFrame("EditBox", nil, valueContainer)
    pixel.SetPixelPoint(valueEdit, "TOPLEFT", 0, 0)
    pixel.SetPixelPoint(valueEdit, "BOTTOMRIGHT", 0, 0)
    valueEdit:SetFontObject("GameFontNormal")
    valueEdit:SetJustifyH("CENTER")
    valueEdit:SetAutoFocus(false)
    row.valueEdit = valueEdit

    Mixin(row, SliderMixin)

    row._animateThumb, row._syncThumb = Animations:CreateColorAnimator(thumbFrame,
        function(r, g, b, a) thumbFrame:SetBackdropColor(r, g, b, a) end,
        { theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.6 }, theme.animDuration)

    row._animateLeftStepper, row._syncLeftStepper = Animations:CreateHoverColorAnimator(leftStepper,
        function(r, g, b, a) leftStepper.icon:SetVertexColor(r, g, b, a) end,
        theme.textSecondary, theme.accent, theme.animDuration)

    row._animateRightStepper, row._syncRightStepper = Animations:CreateHoverColorAnimator(rightStepper,
        function(r, g, b, a) rightStepper.icon:SetVertexColor(r, g, b, a) end,
        theme.textSecondary, theme.accent, theme.animDuration)

    row._animateValueBorder, row._syncValueBorder = Animations:CreateHoverColorAnimator(valueContainer,
        function(r, g, b, a) valueContainer:SetBackdropBorderColor(r, g, b, a) end,
        theme.border, theme.accent, theme.animDuration)

    leftStepper:SetScript("OnClick", function()
        local minVal = slider:GetMinMaxValues()
        slider:SetValue(max(minVal, slider:GetValue() - row._step))
    end)
    leftStepper:SetScript("OnEnter", function() row._animateLeftStepper(true); lib.ShowTooltip(row) end)
    leftStepper:SetScript("OnLeave", function() row._animateLeftStepper(false); lib.HideTooltip() end)

    rightStepper:SetScript("OnClick", function()
        local _, maxVal = slider:GetMinMaxValues()
        slider:SetValue(min(maxVal, slider:GetValue() + row._step))
    end)
    rightStepper:SetScript("OnEnter", function() row._animateRightStepper(true); lib.ShowTooltip(row) end)
    rightStepper:SetScript("OnLeave", function() row._animateRightStepper(false); lib.HideTooltip() end)

    slider:SetScript("OnValueChanged", function(_, val)
        row:UpdateFill()
        row:UpdateThumbPosition()
        if row._callbackOnRelease and row._dragging then return end
        local now = GetTime()
        if now - row._lastUpdate < THROTTLE_DELAY then return end
        row._lastUpdate = now
        row:FireCallback(val)
    end)

    -- The thumb re-lays out a frame after the slider resizes, so re-true the sub-pixel
    -- correction once the new geometry has settled.
    slider:SetScript("OnSizeChanged", function()
        row:UpdateFill()
        row:UpdateThumbPosition()
        if row._thumbSyncPending then return end
        row._thumbSyncPending = true
        local alive = lib.Generation(row)
        C_Timer.After(0, function()
            row._thumbSyncPending = false
            if not alive() then return end
            row:UpdateFill()
            row:UpdateThumbPosition()
        end)
    end)

    slider:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local accent = row.gui.theme.accent
        thumbFrame:SetBackdropColor(accent[1], accent[2], accent[3], 1)
        row._syncThumb(accent[1], accent[2], accent[3], 1)
        row._dragging = true
    end)
    slider:SetScript("OnMouseUp", function(sliderFrame, button)
        if button ~= "LeftButton" then return end
        row._dragging = false
        if row._callbackOnRelease then row:FireCallback(sliderFrame:GetValue()) end
        row:AnimateThumbColor(sliderFrame:IsMouseOver(), false)
    end)
    slider:SetScript("OnEnter", function()
        if not row._dragging then row:AnimateThumbColor(true, false) end
        lib.ShowTooltip(row)
    end)
    slider:SetScript("OnLeave", function()
        if not row._dragging then row:AnimateThumbColor(false, false) end
        lib.HideTooltip()
    end)

    valueEdit:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
        row:UpdateFill()
    end)
    valueEdit:SetScript("OnEnterPressed", function(editBox)
        editBox:ClearFocus()
        row:CommitText()
    end)
    valueEdit:SetScript("OnEditFocusGained", function(editBox)
        local accent = row.gui.theme.accent
        valueContainer:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
        editBox:HighlightText()
    end)
    valueEdit:SetScript("OnEditFocusLost", function(editBox)
        local border = row.gui.theme.border
        valueContainer:SetBackdropBorderColor(border[1], border[2], border[3], 1)
        editBox:HighlightText(0, 0)
        row:CommitText()
    end)
    valueEdit:SetScript("OnEnter", function()
        if not valueEdit:HasFocus() then row._animateValueBorder(true) end
        lib.ShowTooltip(row)
    end)
    valueEdit:SetScript("OnLeave", function()
        if not valueEdit:HasFocus() then row._animateValueBorder(false) end
        lib.HideTooltip()
    end)

    -- The value box's frame has no hover styling of its own, so these are its only scripts.
    valueContainer:SetScript("OnEnter", function() lib.ShowTooltip(row) end)
    valueContainer:SetScript("OnLeave", lib.HideTooltip)

    return row
end)

---@param parent Frame
---@param labelText? string
---@param config? KajiGUISliderConfig
---@return KajiGUISlider
function InstanceMixin:CreateSlider(parent, labelText, config)
    return self:BuildWidget(WIDGET_TYPE, parent, labelText, config)
end

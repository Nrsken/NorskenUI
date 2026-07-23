--[[
# Slider

* A horizontal slider with stepper buttons and an editable value box.

## Examples

?   row:AddWidget(GUI:CreateSlider(row, 'Thickness', {
?       min = 3,
?       max = 20,
?       step = 1,
?       value = db.Thickness,
?       callback = function(v)
?           db.Thickness = v
?       end,
?   }))

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local Animations = lib.Animations
local safecall = lib.safecall
local pixel = lib.Pixel

local tostring = tostring
local tonumber = tonumber
local CreateFrame = CreateFrame
local GetTime = GetTime
local type = type
local rad = math.rad
local floor, max, min = math.floor, math.max, math.min

local C_Timer = C_Timer

---@class KajiGUISlider : Frame
---@field label FontString
---@field slider Slider
---@field SetValue fun(self: KajiGUISlider, val: number)
---@field GetValue fun(self: KajiGUISlider): number
---@field SetMinMaxValues fun(self: KajiGUISlider, minVal: number, maxVal: number)
---@field SetEnabled fun(self: KajiGUISlider, enabled: boolean)

---@class KajiGUISliderConfig
---@field min? number
---@field max? number
---@field step? number
---@field value? number
---@field labelWidth? number
---@field callback? fun(value: number)
---@field callbackOnRelease? boolean fire callback only when the drag is released
---@field tooltip? any
---@field cvartooltip? boolean

---@param parent Frame
---@param labelText string
---@param config KajiGUISliderConfig
---@return KajiGUISlider
function InstanceMixin:CreateSlider(parent, labelText, config)
    config = config or {}
    local gui = self
    local theme = self.theme
    local sliderMin = config.min or 0
    local sliderMax = config.max or 100
    local step = config.step or 1
    local value = config.value or sliderMin
    local callback = config.callback
    local tooltip = config.tooltip
    local cvarTooltip = config.cvartooltip
    local callbackOnRelease = config.callbackOnRelease

    -- Create the row frame
    local row = CreateFrame("Frame", nil, parent)
    pixel.SetPixelHeight(row, 36)

    -- Create the label
    local label = row:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    gui:ApplyFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    row.label = label

    -- Create the slider background
    local sliderBG = CreateFrame("Frame", nil, row, "BackdropTemplate")
    pixel.SetPixelHeight(sliderBG, 8)
    pixel.SetPixelPoint(sliderBG, "TOPLEFT", row, "TOPLEFT", 68, -22)
    pixel.SetPixelPoint(sliderBG, "TOPRIGHT", row, "TOPRIGHT", -18, -22)
    sliderBG:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    sliderBG:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], 1)
    sliderBG:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
    sliderBG:EnableMouse(false)

    -- Create the main slider
    local slider = CreateFrame("Slider", nil, row, "BackdropTemplate")
    pixel.SetPixelHeight(slider, 8)
    pixel.SetPixelPoint(slider, "TOPLEFT", row, "TOPLEFT", 77, -22)
    pixel.SetPixelPoint(slider, "TOPRIGHT", row, "TOPRIGHT", -27, -22)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(sliderMin, sliderMax)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(value)
    slider:SetHitRectInsets(-9, -9, -5, -5)
    slider:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    slider:SetBackdropColor(0, 0, 0, 0)
    slider:SetBackdropBorderColor(0, 0, 0, 0)

    -- Create the fill texture for the slider
    local fill = slider:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelHeight(fill, 6)
    pixel.SetPixelPoint(fill, "LEFT", sliderBG, "LEFT", 1, 0)
    fill:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    pixel.SetPixelSnap(fill)

    local THUMB_WIDTH, THUMB_HEIGHT = 19, 12

    -- Create the thumb frame background for the slider
    local thumbFrameBG = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    pixel.SetPixelSize(thumbFrameBG, THUMB_WIDTH, THUMB_HEIGHT)
    thumbFrameBG:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    thumbFrameBG:SetBackdropColor(theme.bgLight[1], theme.bgLight[2], theme.bgLight[3], 1)
    thumbFrameBG:SetBackdropBorderColor(0, 0, 0, 1)

    -- Create the thumb frame and texture for the slider
    local thumbFrame = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    pixel.SetPixelSize(thumbFrame, THUMB_WIDTH, THUMB_HEIGHT)
    thumbFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    thumbFrame:SetBackdropColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.6)
    thumbFrame:SetBackdropBorderColor(0, 0, 0, 1)

    -- Create the thumb texture for the slider
    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(0, 0, 0, 0)
    slider:SetThumbTexture(thumb)

    local function UpdateThumbPosition()
        local dx = 0
        local thumbCenter = thumb:GetCenter()
        local sliderLeft = slider:GetLeft()
        if thumbCenter and sliderLeft then
            local left = (thumbCenter - sliderLeft) - THUMB_WIDTH / 2
            dx = pixel.ToPixelGrid(left) - left
        end
        thumbFrameBG:ClearAllPoints()
        thumbFrameBG:SetPoint("CENTER", thumb, "CENTER", dx, 0)
        thumbFrame:ClearAllPoints()
        thumbFrame:SetPoint("CENTER", thumb, "CENTER", dx, 0)
    end

    C_Timer.After(0, UpdateThumbPosition)

    -- Thumb color tween (rgb + alpha), with syncThumb so the instant drag recolor keeps the animator in step.
    local animateThumb, syncThumb = Animations:CreateColorAnimator(thumbFrame,
        function(r, g, b, a)
            thumbFrame:SetBackdropColor(r, g, b, a)
        end,
        { theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.6 },
        theme.animDuration
    )

    -- Animate the thumb color based on hover and drag state
    local function AnimateThumbColor(toHover, toDrag)
        if toDrag then
            animateThumb(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        elseif toHover then
            animateThumb(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
        else
            animateThumb(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.6)
        end
    end

    local stepperSize = 20

    -- Create the left and right stepper buttons for the slider

    local leftStepper = CreateFrame("Button", nil, row)
    pixel.SetPixelSize(leftStepper, stepperSize, stepperSize)
    pixel.SetPixelPoint(leftStepper, "RIGHT", sliderBG, "LEFT", 0, 0)

    local leftIcon = leftStepper:CreateTexture(nil, "ARTWORK")
    leftIcon:SetAllPoints()
    leftIcon:SetTexture(theme.stepperTexture)
    leftIcon:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    leftIcon:SetRotation(rad(-90))
    pixel.SetPixelSnap(leftIcon)
    leftStepper.icon = leftIcon

    leftStepper:SetScript("OnClick", function()
        local minVal = slider:GetMinMaxValues()
        slider:SetValue(max(minVal, slider:GetValue() - step))
    end)

    local animateLeftStepper = Animations:CreateHoverColorAnimator(leftStepper,
        function(r, g, b, a)
            leftIcon:SetVertexColor(r, g, b, a)
        end,
        theme.textSecondary,
        theme.accent,
        theme.animDuration
    )
    leftStepper:SetScript("OnEnter", function() animateLeftStepper(true) end)
    leftStepper:SetScript("OnLeave", function() animateLeftStepper(false) end)

    local rightStepper = CreateFrame("Button", nil, row)
    pixel.SetPixelSize(rightStepper, stepperSize, stepperSize)
    pixel.SetPixelPoint(rightStepper, "LEFT", sliderBG, "RIGHT", 0, 0)

    local rightIcon = rightStepper:CreateTexture(nil, "ARTWORK")
    rightIcon:SetAllPoints()
    rightIcon:SetTexture(theme.stepperTexture)
    rightIcon:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    rightIcon:SetRotation(rad(90))
    pixel.SetPixelSnap(rightIcon)
    rightStepper.icon = rightIcon

    rightStepper:SetScript("OnClick", function()
        local _, maxVal = slider:GetMinMaxValues()
        slider:SetValue(min(maxVal, slider:GetValue() + step))
    end)

    local animateRightStepper = Animations:CreateHoverColorAnimator(rightStepper,
        function(r, g, b, a)
            rightIcon:SetVertexColor(r, g, b, a)
        end,
        theme.textSecondary,
        theme.accent,
        theme.animDuration
    )
    rightStepper:SetScript("OnEnter", function() animateRightStepper(true) end)
    rightStepper:SetScript("OnLeave", function() animateRightStepper(false) end)

    row.leftStepper = leftStepper
    row.rightStepper = rightStepper

    -- Create the value container for the slider
    local valueContainer = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    pixel.SetPixelSize(valueContainer, 48, 24)
    pixel.SetPixelPoint(valueContainer, "RIGHT", leftStepper, "LEFT", 0, 0)
    valueContainer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    valueContainer:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], 1)
    valueContainer:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)

    local animateEditBoxBorder = Animations:CreateHoverColorAnimator(valueContainer,
        function(r, g, b, a)
            valueContainer:SetBackdropBorderColor(r, g, b, a)
        end,
        theme.border,
        theme.accent,
        theme.animDuration
    )

    -- Create the editable value box for the slider
    local valueEdit = CreateFrame("EditBox", nil, valueContainer)
    pixel.SetPixelPoint(valueEdit, "TOPLEFT", 0, 0)
    pixel.SetPixelPoint(valueEdit, "BOTTOMRIGHT", 0, 0)
    valueEdit:SetFontObject("GameFontNormal")
    valueEdit:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    valueEdit:SetJustifyH("CENTER")
    valueEdit:SetAutoFocus(false)
    valueEdit:SetText(tostring(value))
    row.valueEdit = valueEdit

    local isUpdating = false

    -- Function to update the fill width and value edit text based on the slider value
    local function UpdateFill()
        local val = slider:GetValue()
        local minVal, maxVal = slider:GetMinMaxValues()
        if maxVal == minVal then return end
        local pct = (val - minVal) / (maxVal - minVal)
        pixel.SetPixelWidth(fill, max(1, (slider:GetWidth() - 2) * pct))
        if not isUpdating then
            isUpdating = true
            valueEdit:SetText(tostring(floor(val * 100 + 0.5) / 100))
            isUpdating = false
        end
    end

    local throttleDelay = 0.1
    local lastUpdate = 0
    local curDrag = false

    -- Function to fire the callback and update the nudge frame info if edit mode is active
    local function FireCallback(val)
        safecall(callback, val)
        local editMode = gui.services.editMode
        if editMode and editMode.isActive then editMode:UpdateNudgeFrameInfo() end
    end

    -- Set up the slider's OnValueChanged script to update the fill, thumb position and fire the callback
    slider:SetScript("OnValueChanged", function(_, val)
        UpdateFill()
        UpdateThumbPosition()
        if callbackOnRelease and curDrag then return end
        local now = GetTime()
        if now - lastUpdate < throttleDelay then return end
        lastUpdate = now
        FireCallback(val)
    end)

    -- The thumb re-lays out a frame after the slider resizes, so re-true the sub-pixel
    -- correction once the new geometry has settled.
    local thumbSyncPending = false
    slider:SetScript("OnSizeChanged", function()
        UpdateFill()
        UpdateThumbPosition()
        if not thumbSyncPending then
            thumbSyncPending = true
            C_Timer.After(0, function()
                thumbSyncPending = false
                UpdateFill()
                UpdateThumbPosition()
            end)
        end
    end)

    -- Function to commit the text from the value edit box to the slider value, clamping it within min/max values
    local function CommitText(editBox)
        local num = tonumber(editBox:GetText())
        if num then
            local minVal, maxVal = slider:GetMinMaxValues()
            local clamped = max(minVal, min(maxVal, num))
            if clamped ~= num then Animations:Wobble(valueContainer) end
            isUpdating = true
            slider:SetValue(clamped)
            isUpdating = false
        else
            Animations:Wobble(valueContainer)
            UpdateFill()
        end
    end

    -- Set up the value edit box scripts for handling user input and focus events
    valueEdit:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
        UpdateFill()
    end)
    valueEdit:SetScript("OnEnterPressed", function(editBox)
        editBox:ClearFocus()
        CommitText(editBox)
    end)
    valueEdit:SetScript("OnEditFocusGained", function(editBox)
        valueContainer:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        editBox:HighlightText()
    end)
    valueEdit:SetScript("OnEditFocusLost", function(editBox)
        valueContainer:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
        editBox:HighlightText(0, 0)
        CommitText(editBox)
    end)
    valueEdit:SetScript("OnEnter", function()
        if not valueEdit:HasFocus() then animateEditBoxBorder(true) end
    end)
    valueEdit:SetScript("OnLeave", function()
        if not valueEdit:HasFocus() then animateEditBoxBorder(false) end
    end)

    slider:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            thumbFrame:SetBackdropColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            syncThumb(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            curDrag = true
        end
    end)

    slider:SetScript("OnMouseUp", function(sliderFrame, button)
        if button == "LeftButton" then
            curDrag = false
            if callbackOnRelease then FireCallback(sliderFrame:GetValue()) end
            AnimateThumbColor(sliderFrame:IsMouseOver(), false)
        end
    end)

    slider:SetScript("OnEnter", function()
        if not curDrag then AnimateThumbColor(true, false) end
    end)
    slider:SetScript("OnLeave", function()
        if not curDrag then AnimateThumbColor(false, false) end
    end)

    C_Timer.After(0, UpdateFill)

    -- Define methods for the row to set/get value, set min/max values and enable/disable the slider
    function row:SetValue(val) slider:SetValue(val) end

    function row:GetValue() return slider:GetValue() end

    function row:SetMinMaxValues(minVal, maxVal)
        slider:SetMinMaxValues(minVal, maxVal)
        UpdateFill()
    end

    -- Set the enabled state of the slider and its components
    function row:SetEnabled(enabled)
        row:SetAlpha(enabled and 1 or 0.4)
        slider:EnableMouse(enabled)
        valueEdit:EnableMouse(enabled)
        valueContainer:EnableMouse(enabled)
        leftStepper:EnableMouse(enabled)
        rightStepper:EnableMouse(enabled)
    end

    row.slider = slider

    -- Set up tooltip for the slider and its components if provided
    if tooltip then
        local tooltipText = type(tooltip) == "table" and tooltip.text or tooltip
        local tooltipDefault = type(tooltip) == "table" and tooltip.default

        local function SetupTooltip(frame)
            local oldEnter = frame:GetScript("OnEnter")
            local oldLeave = frame:GetScript("OnLeave")
            frame:SetScript("OnEnter", function(f, ...)
                if oldEnter then oldEnter(f, ...) end
                GameTooltip:SetOwner(row, "ANCHOR_CURSOR_RIGHT", 30, 0)
                GameTooltip:SetText(labelText or "", theme.accent[1], theme.accent[2], theme.accent[3], 1, false)
                GameTooltip:AddLine(tooltipText, theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], false)
                if tooltipDefault ~= nil and cvarTooltip then
                    local defaultStr = type(tooltipDefault) == "boolean" and (tooltipDefault and "On" or "Off") or tostring(tooltipDefault)
                    GameTooltip:AddLine("Default: " .. defaultStr, theme.success[1], theme.success[2], theme.success[3])
                end
                GameTooltip:Show()
            end)
            frame:SetScript("OnLeave", function(f, ...)
                if oldLeave then oldLeave(f, ...) end
                GameTooltip:Hide()
            end)
        end
        SetupTooltip(slider)
        SetupTooltip(valueEdit)
        SetupTooltip(valueContainer)
        SetupTooltip(leftStepper)
        SetupTooltip(rightStepper)
    end

    gui:RegisterSearchableWidget(row, labelText)
    ---@cast row KajiGUISlider
    return row
end

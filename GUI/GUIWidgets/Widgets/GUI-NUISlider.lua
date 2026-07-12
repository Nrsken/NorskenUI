---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local tostring = tostring
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local math_floor, math_max, math_min = math.floor, math.max, math.min
local GetTime = GetTime
local type = type

local STEPPER_TEXTURE = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\collapse.tga"

---@class NUISlider : Frame
---@field label FontString
---@field slider Slider
---@field SetValue fun(self: NUISlider, val: number)
---@field GetValue fun(self: NUISlider): number
---@field SetMinMaxValues fun(self: NUISlider, minVal: number, maxVal: number)
---@field SetEnabled fun(self: NUISlider, enabled: boolean)

---@class NUISliderConfig
---@field min? number
---@field max? number
---@field step? number
---@field value? number
---@field labelWidth? number
---@field callback? fun(value: number)
---@field callbackOnRelease? boolean
---@field tooltip? any
---@field cvartooltip? boolean

---Slider with value input and stepper buttons
---```lua
---config = {
---    min = number,          -- Minimum value
---    max = number,          -- Maximum value
---    step = number,         -- Step increment
---    value = number,        -- Initial value
---    labelWidth = number,   -- Label width (optional)
---    callback = function,   -- Called when value changes
---    tooltip = string,      -- Tooltip text
---    cvartooltip = boolean,  -- Whether to show default value in tooltip
---}
---```
---@param parent Frame
---@param labelText string
---@param config NUISliderConfig
---@return NUISlider
function GUIFrame:CreateSlider(parent, labelText, config)
    config = config or {}
    local min = config.min or 0
    local max = config.max or 100
    local step = config.step or 1
    local value = config.value or min
    local labelWidth = config.labelWidth
    local callback = config.callback
    local tooltip = config.tooltip
    local cvarTooltip = config.cvartooltip
    local callbackOnRelease = config.callbackOnRelease

    local rowHeight = 36
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(rowHeight)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    NRSKNUI:ApplyThemeFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    row.label = label

    local sliderBG = CreateFrame("Frame", nil, row, "BackdropTemplate")
    sliderBG:SetHeight(8)
    sliderBG:SetPoint("TOPLEFT", row, "TOPLEFT", 68, -22)
    sliderBG:SetPoint("TOPRIGHT", row, "TOPRIGHT", -18, -22)
    sliderBG:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    sliderBG:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
    sliderBG:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    sliderBG:EnableMouse(false)

    local slider = CreateFrame("Slider", nil, row, "BackdropTemplate")
    slider:SetHeight(8)
    slider:SetPoint("TOPLEFT", row, "TOPLEFT", 77, -22)
    slider:SetPoint("TOPRIGHT", row, "TOPRIGHT", -27, -22)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(value)
    slider:SetHitRectInsets(-9, -9, -5, -5)

    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    slider:SetBackdropColor(0, 0, 0, 0)
    slider:SetBackdropBorderColor(0, 0, 0, 0)

    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(6)
    fill:SetPoint("LEFT", sliderBG, "LEFT", 1, 0)
    fill:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    fill:SetTexelSnappingBias(0)
    fill:SetSnapToPixelGrid(false)

    local thumbFrameBG = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    thumbFrameBG:SetSize(19, 12)
    thumbFrameBG:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    thumbFrameBG:SetBackdropColor(Theme.bgLight[1], Theme.bgLight[2], Theme.bgLight[3], 1)
    thumbFrameBG:SetBackdropBorderColor(0, 0, 0, 1)

    local thumbFrame = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    thumbFrame:SetSize(19, 12)
    thumbFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    thumbFrame:SetBackdropColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.6)
    thumbFrame:SetBackdropBorderColor(0, 0, 0, 1)

    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(0, 0, 0, 0)
    slider:SetThumbTexture(thumb)

    local function UpdateThumbPosition()
        thumbFrameBG:ClearAllPoints()
        thumbFrameBG:SetPoint("CENTER", thumb, "CENTER", 0, 0)
        thumbFrame:ClearAllPoints()
        thumbFrame:SetPoint("CENTER", thumb, "CENTER", 0, 0)
    end

    C_Timer.After(0, UpdateThumbPosition)

    local hoverAnimGroup = slider:CreateAnimationGroup()
    local hoverAnim = hoverAnimGroup:CreateAnimation("Animation")
    hoverAnim:SetDuration(Theme.animDuration)

    local borderColorFrom = {}
    local borderColorTo = {}
    local thumbR, thumbG, thumbB, thumbA = Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.6

    local function AnimateThumbColor(toHover, toDrag)
        hoverAnimGroup:Stop()
        borderColorFrom.r = thumbR
        borderColorFrom.g = thumbG
        borderColorFrom.b = thumbB
        borderColorFrom.a = thumbA

        if toDrag then
            borderColorTo.r = Theme.accent[1]
            borderColorTo.g = Theme.accent[2]
            borderColorTo.b = Theme.accent[3]
            borderColorTo.a = 1
        elseif toHover then
            borderColorTo.r = Theme.textSecondary[1]
            borderColorTo.g = Theme.textSecondary[2]
            borderColorTo.b = Theme.textSecondary[3]
            borderColorTo.a = 1
        else
            borderColorTo.r = Theme.textSecondary[1]
            borderColorTo.g = Theme.textSecondary[2]
            borderColorTo.b = Theme.textSecondary[3]
            borderColorTo.a = 0.6
        end

        hoverAnimGroup:Play()
    end

    hoverAnimGroup:SetScript("OnUpdate", function(animGroup)
        local progress = animGroup:GetProgress() or 0
        local r = borderColorFrom.r + (borderColorTo.r - borderColorFrom.r) * progress
        local g = borderColorFrom.g + (borderColorTo.g - borderColorFrom.g) * progress
        local b = borderColorFrom.b + (borderColorTo.b - borderColorFrom.b) * progress
        local a = borderColorFrom.a + (borderColorTo.a - borderColorFrom.a) * progress
        thumbFrame:SetBackdropColor(r, g, b, a)
        thumbR, thumbG, thumbB, thumbA = r, g, b, a
    end)

    hoverAnimGroup:SetScript("OnFinished", function()
        thumbFrame:SetBackdropColor(borderColorTo.r, borderColorTo.g, borderColorTo.b, borderColorTo.a)
        thumbR, thumbG, thumbB, thumbA = borderColorTo.r, borderColorTo.g, borderColorTo.b, borderColorTo.a
    end)

    local stepperSize = 20

    local leftStepper = CreateFrame("Button", nil, row)
    leftStepper:SetSize(stepperSize, stepperSize)
    leftStepper:SetPoint("RIGHT", sliderBG, "LEFT", 0, 0)

    local leftIcon = leftStepper:CreateTexture(nil, "ARTWORK")
    leftIcon:SetAllPoints()
    leftIcon:SetTexture(STEPPER_TEXTURE)
    leftIcon:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    leftIcon:SetRotation(math.rad(-90))
    leftIcon:SetTexelSnappingBias(0)
    leftIcon:SetSnapToPixelGrid(false)
    leftStepper.icon = leftIcon

    leftStepper:SetScript("OnClick", function()
        local currentVal = slider:GetValue()
        local minVal = slider:GetMinMaxValues()
        local newVal = math_max(minVal, currentVal - step)
        slider:SetValue(newVal)
    end)

    local animateLeftStepper = NRSKNUI.Animations:CreateHoverColorAnimator(
        leftStepper,
        function(r, g, b, a) leftIcon:SetVertexColor(r, g, b, a) end,
        Theme.textSecondary,
        Theme.accent,
        Theme.animDuration
    )

    leftStepper:SetScript("OnEnter", function() animateLeftStepper(true) end)
    leftStepper:SetScript("OnLeave", function() animateLeftStepper(false) end)

    local rightStepper = CreateFrame("Button", nil, row)
    rightStepper:SetSize(stepperSize, stepperSize)
    rightStepper:SetPoint("LEFT", sliderBG, "RIGHT", 0, 0)

    local rightIcon = rightStepper:CreateTexture(nil, "ARTWORK")
    rightIcon:SetAllPoints()
    rightIcon:SetTexture(STEPPER_TEXTURE)
    rightIcon:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    rightIcon:SetRotation(math.rad(90))
    rightIcon:SetTexelSnappingBias(0)
    rightIcon:SetSnapToPixelGrid(false)
    rightStepper.icon = rightIcon

    rightStepper:SetScript("OnClick", function()
        local currentVal = slider:GetValue()
        local _, maxVal = slider:GetMinMaxValues()
        local newVal = math_min(maxVal, currentVal + step)
        slider:SetValue(newVal)
    end)

    local animateRightStepper = NRSKNUI.Animations:CreateHoverColorAnimator(
        rightStepper,
        function(r, g, b, a) rightIcon:SetVertexColor(r, g, b, a) end,
        Theme.textSecondary,
        Theme.accent,
        Theme.animDuration
    )

    rightStepper:SetScript("OnEnter", function() animateRightStepper(true) end)
    rightStepper:SetScript("OnLeave", function() animateRightStepper(false) end)

    row.leftStepper = leftStepper
    row.rightStepper = rightStepper
    local valueContainer = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    valueContainer:SetSize(48, 24)
    valueContainer:SetPoint("RIGHT", leftStepper, "LEFT", 0, 0)
    valueContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    valueContainer:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
    valueContainer:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    local animateEditBoxBorder = NRSKNUI.Animations:CreateHoverColorAnimator(
        valueContainer,
        function(r, g, b, a) valueContainer:SetBackdropBorderColor(r, g, b, a) end,
        Theme.border,
        Theme.accent,
        Theme.animDuration
    )

    local valueEdit = CreateFrame("EditBox", nil, valueContainer)
    valueEdit:SetPoint("TOPLEFT", 0, 0)
    valueEdit:SetPoint("BOTTOMRIGHT", 0, 0)
    valueEdit:SetFontObject("GameFontNormal")
    valueEdit:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    valueEdit:SetJustifyH("CENTER")
    valueEdit:SetAutoFocus(false)
    valueEdit:SetText(tostring(value))
    row.valueEdit = valueEdit

    local isUpdating = false

    local function UpdateFill()
        local val = slider:GetValue()
        local minVal, maxVal = slider:GetMinMaxValues()
        if maxVal == minVal then return end
        local pct = (val - minVal) / (maxVal - minVal)
        local width = math_max(1, (slider:GetWidth() - 2) * pct)
        fill:SetWidth(width)
        if not isUpdating then
            isUpdating = true
            valueEdit:SetText(tostring(math_floor(val * 100 + 0.5) / 100))
            isUpdating = false
        end
    end

    local throttleDelay = 0.1
    local lastUpdate = 0
    local curDrag = false

    local function FireCallback(val)
        if callback then callback(val) end
        if NRSKNUI.EditMode and NRSKNUI.EditMode.isActive then
            NRSKNUI.EditMode:UpdateNudgeFrameInfo()
        end
    end

    slider:SetScript("OnValueChanged", function(_, val)
        UpdateFill()
        UpdateThumbPosition()
        if callbackOnRelease and curDrag then
            return
        end
        local currentTime = GetTime()
        if currentTime - lastUpdate < throttleDelay then
            return
        end
        lastUpdate = currentTime
        FireCallback(val)
    end)

    slider:SetScript("OnSizeChanged", function()
        UpdateFill()
        UpdateThumbPosition()
    end)

    valueEdit:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
        UpdateFill()
    end)

    valueEdit:SetScript("OnEnterPressed", function(editBox)
        editBox:ClearFocus()
        local num = tonumber(editBox:GetText())
        if num then
            local minVal, maxVal = slider:GetMinMaxValues()
            local clamped = math_max(minVal, math_min(maxVal, num))
            if clamped ~= num then
                NRSKNUI.Animations:Wobble(valueContainer)
            end
            isUpdating = true
            slider:SetValue(clamped)
            isUpdating = false
        else
            NRSKNUI.Animations:Wobble(valueContainer)
            UpdateFill()
        end
    end)

    valueEdit:SetScript("OnEditFocusGained", function(editBox)
        valueContainer:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        editBox:HighlightText()
    end)

    valueEdit:SetScript("OnEditFocusLost", function(editBox)
        valueContainer:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
        editBox:HighlightText(0, 0)
        local num = tonumber(editBox:GetText())
        if num then
            local minVal, maxVal = slider:GetMinMaxValues()
            local clamped = math_max(minVal, math_min(maxVal, num))
            if clamped ~= num then
                NRSKNUI.Animations:Wobble(valueContainer)
            end
            isUpdating = true
            slider:SetValue(clamped)
            isUpdating = false
        else
            NRSKNUI.Animations:Wobble(valueContainer)
            UpdateFill()
        end
    end)

    valueEdit:SetScript("OnEnter", function()
        if not valueEdit:HasFocus() then
            animateEditBoxBorder(true)
        end
    end)

    valueEdit:SetScript("OnLeave", function()
        if not valueEdit:HasFocus() then
            animateEditBoxBorder(false)
        end
    end)

    slider:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            hoverAnimGroup:Stop()
            thumbFrame:SetBackdropColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            thumbR, thumbG, thumbB, thumbA = Theme.accent[1], Theme.accent[2], Theme.accent[3], 1
            curDrag = true
        end
    end)

    slider:SetScript("OnMouseUp", function(sliderFrame, button)
        if button == "LeftButton" then
            curDrag = false
            if callbackOnRelease then
                FireCallback(sliderFrame:GetValue())
            end
            if sliderFrame:IsMouseOver() then
                AnimateThumbColor(true, false)
            else
                AnimateThumbColor(false, false)
            end
        end
    end)

    slider:SetScript("OnEnter", function()
        if not curDrag then
            AnimateThumbColor(true, false)
        end
    end)

    slider:SetScript("OnLeave", function()
        if not curDrag then
            AnimateThumbColor(false, false)
        end
    end)

    C_Timer.After(0, UpdateFill)

    function row:SetValue(val) slider:SetValue(val) end

    function row:GetValue() return slider:GetValue() end

    function row:SetMinMaxValues(minVal, maxVal)
        slider:SetMinMaxValues(minVal, maxVal)
        UpdateFill()
    end

    function row:SetEnabled(enabled)
        if enabled then
            row:SetAlpha(1)
            slider:EnableMouse(true)
            valueEdit:EnableMouse(true)
            valueContainer:EnableMouse(true)
            leftStepper:EnableMouse(true)
            rightStepper:EnableMouse(true)
        else
            row:SetAlpha(0.4)
            slider:EnableMouse(false)
            valueEdit:EnableMouse(false)
            valueContainer:EnableMouse(false)
            leftStepper:EnableMouse(false)
            rightStepper:EnableMouse(false)
        end
    end

    row.slider = slider

    -- Tooltip support
    if tooltip then
        local tooltipText = type(tooltip) == "table" and tooltip.text or tooltip
        local tooltipDefault = type(tooltip) == "table" and tooltip.default

        local function SetupTooltip(frame)
            local oldEnter = frame:GetScript("OnEnter")
            local oldLeave = frame:GetScript("OnLeave")
            frame:SetScript("OnEnter", function(f, ...)
                if oldEnter then oldEnter(f, ...) end
                GameTooltip:SetOwner(row, "ANCHOR_CURSOR_RIGHT", 30, 0)
                GameTooltip:SetText(labelText or "", Theme.accent[1], Theme.accent[2], Theme.accent[3], 1, false)
                GameTooltip:AddLine(tooltipText, Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3],
                    false)
                if tooltipDefault ~= nil and cvarTooltip then
                    local defaultStr = type(tooltipDefault) == "boolean" and (tooltipDefault and "On" or "Off") or
                        tostring(tooltipDefault)
                    GameTooltip:AddLine("Default: " .. defaultStr, Theme.success[1], Theme.success[2], Theme.success[3])
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

    self:RegisterSearchableWidget(row, labelText)
    ---@cast row NUISlider
    return row
end

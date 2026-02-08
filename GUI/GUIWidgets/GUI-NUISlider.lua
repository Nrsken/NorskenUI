-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local tonumber = tonumber
local tostring = tostring
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local math_floor, math_max, math_min = math.floor, math.max, math.min
local GetTime = GetTime

-- Slider widget
function GUIFrame:CreateSlider(parent, labelText, min, max, step, value, labelWidth, callback)
    local tooltip = nil
    local customHeight = nil
    local isPercent = nil
    local stepperTexture = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\collapse.tga"

    -- Ensure min/max are valid numbers
    min = tonumber(min) or 0
    max = tonumber(max) or 100
    step = tonumber(step) or 1
    value = tonumber(value) or min

    -- Row
    local rowHeight = customHeight or 36
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

    -- Slider
    local slider = CreateFrame("Slider", nil, row, "BackdropTemplate")
    slider:SetHeight(8)
    slider:SetPoint("TOPLEFT", row, "TOPLEFT", 77, -22)
    slider:SetPoint("TOPRIGHT", row, "TOPRIGHT", -27, -22) -- Make room for steppers + editbox
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(min or 0, max or 100)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(value or min or 0)
    slider:SetHitRectInsets(-9, -9, -5, -5)

    -- Slider styling
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    slider:SetBackdropColor(0, 0, 0, 0)
    slider:SetBackdropBorderColor(0, 0, 0, 0)

    -- Fill texture
    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(6)
    fill:SetPoint("LEFT", sliderBG, "LEFT", 1, 0)
    fill:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    fill:SetTexelSnappingBias(0)
    fill:SetSnapToPixelGrid(false)

    -- Thumb background frame (solid background layer)
    local thumbFrameBG = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    thumbFrameBG:SetSize(19, 12)
    thumbFrameBG:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    thumbFrameBG:SetBackdropColor(Theme.bgLight[1], Theme.bgLight[2], Theme.bgLight[3], 1)
    thumbFrameBG:SetBackdropBorderColor(0, 0, 0, 1)

    -- Thumb container frame (animated color layer)
    local thumbFrame = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    thumbFrame:SetSize(19, 12)
    thumbFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    thumbFrame:SetBackdropColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.6)
    thumbFrame:SetBackdropBorderColor(0, 0, 0, 1) -- Black border

    -- Use a transparent texture for the actual thumb
    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(0, 0, 0, 0) -- Fully transparent
    slider:SetThumbTexture(thumb)

    -- Hook thumb position to move our custom frames
    slider:HookScript("OnUpdate", function(self)
        local thumbX = self:GetThumbTexture():GetPoint()
        if thumbX then
            -- Position both frames at thumb location
            thumbFrameBG:ClearAllPoints()
            thumbFrameBG:SetPoint("CENTER", thumb, "CENTER", 0, 0)
            thumbFrame:ClearAllPoints()
            thumbFrame:SetPoint("CENTER", thumb, "CENTER", 0, 0)
        end
    end)

    -- Hover fade animation for thumb color
    local hoverAnimGroup = slider:CreateAnimationGroup()
    local hoverAnim = hoverAnimGroup:CreateAnimation("Animation")
    hoverAnim:SetDuration(0.18)

    local borderColorFrom = {}
    local borderColorTo = {}

    -- Track current thumb color (including alpha)
    local thumbR, thumbG, thumbB, thumbA = Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.6

    local function AnimateThumbColor(toHover, toDrag)
        hoverAnimGroup:Stop()

        -- Use tracked color
        borderColorFrom.r = thumbR
        borderColorFrom.g = thumbG
        borderColorFrom.b = thumbB
        borderColorFrom.a = thumbA

        if toDrag then
            -- Dragging = accent color with alpha 1
            borderColorTo.r = Theme.accent[1]
            borderColorTo.g = Theme.accent[2]
            borderColorTo.b = Theme.accent[3]
            borderColorTo.a = 1
        elseif toHover then
            -- Hover = textSecondary with alpha 1
            borderColorTo.r = Theme.textSecondary[1]
            borderColorTo.g = Theme.textSecondary[2]
            borderColorTo.b = Theme.textSecondary[3]
            borderColorTo.a = 1
        else
            -- Normal = textSecondary with alpha 0.6
            borderColorTo.r = Theme.textSecondary[1]
            borderColorTo.g = Theme.textSecondary[2]
            borderColorTo.b = Theme.textSecondary[3]
            borderColorTo.a = 0.6
        end

        hoverAnimGroup:Play()
    end

    hoverAnimGroup:SetScript("OnUpdate", function(self)
        local progress = self:GetProgress() or 0
        local r = borderColorFrom.r + (borderColorTo.r - borderColorFrom.r) * progress
        local g = borderColorFrom.g + (borderColorTo.g - borderColorFrom.g) * progress
        local b = borderColorFrom.b + (borderColorTo.b - borderColorFrom.b) * progress
        local a = borderColorFrom.a + (borderColorTo.a - borderColorFrom.a) * progress
        thumbFrame:SetBackdropColor(r, g, b, a)
        -- Update tracked color
        thumbR, thumbG, thumbB, thumbA = r, g, b, a
    end)

    hoverAnimGroup:SetScript("OnFinished", function()
        thumbFrame:SetBackdropColor(borderColorTo.r, borderColorTo.g, borderColorTo.b, borderColorTo.a)
        -- Update tracked color to final value
        thumbR, thumbG, thumbB, thumbA = borderColorTo.r, borderColorTo.g, borderColorTo.b, borderColorTo.a
    end)

    -- Stepper buttons (left/right arrows)
    local stepperSize = 20

    -- Left stepper (decrement) - arrow points left (rotated 90° clockwise)
    local leftStepper = CreateFrame("Button", nil, row)
    leftStepper:SetSize(stepperSize, stepperSize)
    leftStepper:SetPoint("RIGHT", sliderBG, "LEFT", 0, 0)

    -- Left arrow icon
    local leftIcon = leftStepper:CreateTexture(nil, "ARTWORK")
    leftIcon:SetAllPoints()
    leftIcon:SetTexture(stepperTexture)
    leftIcon:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    leftIcon:SetRotation(math.rad(-90)) -- Rotate to point left
    leftIcon:SetTexelSnappingBias(0)
    leftIcon:SetSnapToPixelGrid(false)
    leftStepper.icon = leftIcon

    -- Click handler
    leftStepper:SetScript("OnClick", function()
        local currentVal = slider:GetValue()
        local minVal = slider:GetMinMaxValues()
        local newVal = math_max(minVal, currentVal - step)
        slider:SetValue(newVal)
    end)

    -- Left stepper hover animation
    local leftAnimGroup = leftStepper:CreateAnimationGroup()
    local leftAnim = leftAnimGroup:CreateAnimation("Animation")
    leftAnim:SetDuration(0.18)

    local leftColorFrom = {}
    local leftColorTo = {}
    local leftR, leftG, leftB = Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3]

    local function AnimateLeftStepperColor(toAccent)
        leftAnimGroup:Stop()
        leftColorFrom.r = leftR
        leftColorFrom.g = leftG
        leftColorFrom.b = leftB

        if toAccent then
            leftColorTo.r = Theme.accent[1]
            leftColorTo.g = Theme.accent[2]
            leftColorTo.b = Theme.accent[3]
        else
            leftColorTo.r = Theme.textSecondary[1]
            leftColorTo.g = Theme.textSecondary[2]
            leftColorTo.b = Theme.textSecondary[3]
        end
        leftAnimGroup:Play()
    end

    leftAnimGroup:SetScript("OnUpdate", function(self)
        local progress = self:GetProgress() or 0
        local r = leftColorFrom.r + (leftColorTo.r - leftColorFrom.r) * progress
        local g = leftColorFrom.g + (leftColorTo.g - leftColorFrom.g) * progress
        local b = leftColorFrom.b + (leftColorTo.b - leftColorFrom.b) * progress
        leftIcon:SetVertexColor(r, g, b, 1)
        leftR, leftG, leftB = r, g, b
    end)

    leftAnimGroup:SetScript("OnFinished", function()
        leftIcon:SetVertexColor(leftColorTo.r, leftColorTo.g, leftColorTo.b, 1)
        leftR, leftG, leftB = leftColorTo.r, leftColorTo.g, leftColorTo.b
    end)

    -- Hover effects
    leftStepper:SetScript("OnEnter", function(self)
        AnimateLeftStepperColor(true)
    end)

    -- Leave effects
    leftStepper:SetScript("OnLeave", function(self)
        AnimateLeftStepperColor(false)
    end)

    -- Right stepper (increment) - arrow points right (rotated 90° counter-clockwise)
    local rightStepper = CreateFrame("Button", nil, row)
    rightStepper:SetSize(stepperSize, stepperSize)
    rightStepper:SetPoint("LEFT", sliderBG, "RIGHT", 0, 0)

    -- Right arrow icon
    local rightIcon = rightStepper:CreateTexture(nil, "ARTWORK")
    rightIcon:SetAllPoints()
    rightIcon:SetTexture(stepperTexture)
    rightIcon:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    rightIcon:SetRotation(math.rad(90)) -- Rotate to point right
    rightIcon:SetTexelSnappingBias(0)
    rightIcon:SetSnapToPixelGrid(false)
    rightStepper.icon = rightIcon

    -- Click handler
    rightStepper:SetScript("OnClick", function()
        local currentVal = slider:GetValue()
        local _, maxVal = slider:GetMinMaxValues()
        local newVal = math_min(maxVal, currentVal + step)
        slider:SetValue(newVal)
    end)

    -- Right stepper hover animation
    local rightAnimGroup = rightStepper:CreateAnimationGroup()
    local rightAnim = rightAnimGroup:CreateAnimation("Animation")
    rightAnim:SetDuration(0.18)

    local rightColorFrom = {}
    local rightColorTo = {}
    local rightR, rightG, rightB = Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3]

    local function AnimateRightStepperColor(toAccent)
        rightAnimGroup:Stop()
        rightColorFrom.r = rightR
        rightColorFrom.g = rightG
        rightColorFrom.b = rightB

        if toAccent then
            rightColorTo.r = Theme.accent[1]
            rightColorTo.g = Theme.accent[2]
            rightColorTo.b = Theme.accent[3]
        else
            rightColorTo.r = Theme.textSecondary[1]
            rightColorTo.g = Theme.textSecondary[2]
            rightColorTo.b = Theme.textSecondary[3]
        end
        rightAnimGroup:Play()
    end

    rightAnimGroup:SetScript("OnUpdate", function(self)
        local progress = self:GetProgress() or 0
        local r = rightColorFrom.r + (rightColorTo.r - rightColorFrom.r) * progress
        local g = rightColorFrom.g + (rightColorTo.g - rightColorFrom.g) * progress
        local b = rightColorFrom.b + (rightColorTo.b - rightColorFrom.b) * progress
        rightIcon:SetVertexColor(r, g, b, 1)
        rightR, rightG, rightB = r, g, b
    end)

    rightAnimGroup:SetScript("OnFinished", function()
        rightIcon:SetVertexColor(rightColorTo.r, rightColorTo.g, rightColorTo.b, 1)
        rightR, rightG, rightB = rightColorTo.r, rightColorTo.g, rightColorTo.b
    end)

    -- Hover effects
    rightStepper:SetScript("OnEnter", function(self)
        AnimateRightStepperColor(true)
    end)

    -- Leave effects
    rightStepper:SetScript("OnLeave", function(self)
        AnimateRightStepperColor(false)
    end)

    -- Store references
    row.leftStepper = leftStepper
    row.rightStepper = rightStepper

    -- Value editbox
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

    -- EditBox border hover animation
    local editBoxAnimGroup = valueContainer:CreateAnimationGroup()
    local editBoxAnim = editBoxAnimGroup:CreateAnimation("Animation")
    editBoxAnim:SetDuration(0.18)

    local editBoxColorFrom = {}
    local editBoxColorTo = {}
    local editBoxR, editBoxG, editBoxB = Theme.border[1], Theme.border[2], Theme.border[3]

    local function AnimateEditBoxBorder(toAccent)
        editBoxAnimGroup:Stop()
        editBoxColorFrom.r = editBoxR
        editBoxColorFrom.g = editBoxG
        editBoxColorFrom.b = editBoxB

        if toAccent then
            editBoxColorTo.r = Theme.accent[1]
            editBoxColorTo.g = Theme.accent[2]
            editBoxColorTo.b = Theme.accent[3]
        else
            editBoxColorTo.r = Theme.border[1]
            editBoxColorTo.g = Theme.border[2]
            editBoxColorTo.b = Theme.border[3]
        end
        editBoxAnimGroup:Play()
    end

    editBoxAnimGroup:SetScript("OnUpdate", function(self)
        local progress = self:GetProgress() or 0
        local r = editBoxColorFrom.r + (editBoxColorTo.r - editBoxColorFrom.r) * progress
        local g = editBoxColorFrom.g + (editBoxColorTo.g - editBoxColorFrom.g) * progress
        local b = editBoxColorFrom.b + (editBoxColorTo.b - editBoxColorFrom.b) * progress
        valueContainer:SetBackdropBorderColor(r, g, b, 1)
        editBoxR, editBoxG, editBoxB = r, g, b
    end)

    editBoxAnimGroup:SetScript("OnFinished", function()
        valueContainer:SetBackdropBorderColor(editBoxColorTo.r, editBoxColorTo.g, editBoxColorTo.b, 1)
        editBoxR, editBoxG, editBoxB = editBoxColorTo.r, editBoxColorTo.g, editBoxColorTo.b
    end)

    -- Editable text box
    local valueEdit = CreateFrame("EditBox", nil, valueContainer)
    valueEdit:SetPoint("TOPLEFT", 0, 0)
    valueEdit:SetPoint("BOTTOMRIGHT", 0, 0)
    valueEdit:SetFontObject("GameFontNormal")
    valueEdit:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    valueEdit:SetJustifyH("CENTER")
    valueEdit:SetAutoFocus(false)
    valueEdit:SetText(tostring(value or min))
    row.valueEdit = valueEdit

    local isUpdating = false

    -- Function to update fill width and editbox text
    local function UpdateFill()
        local val = slider:GetValue()
        local minVal, maxVal = slider:GetMinMaxValues()
        if maxVal == minVal then return end
        local pct = (val - minVal) / (maxVal - minVal)
        local width = math_max(1, (slider:GetWidth() - 2) * pct)
        fill:SetWidth(width)
        if not isUpdating then
            isUpdating = true
            if isPercent then
                -- Display as percentage (e.g., 0.3 -> "30%")
                valueEdit:SetText(math_floor(val * 1000 + 0.5) / 10 .. "%")
            else
                valueEdit:SetText(tostring(math_floor(val * 100 + 0.5) / 100))
            end
            isUpdating = false
        end
    end

    local throttleDelay = 0.1 -- 100ms between updates
    local lastUpdate = 0
    slider:SetScript("OnValueChanged", function(self, val)
        UpdateFill()
        local currentTime = GetTime()
        if currentTime - lastUpdate < throttleDelay then
            return
        end
        lastUpdate = currentTime
        if callback then callback(val) end
    end)

    slider:SetScript("OnSizeChanged", UpdateFill)

    valueEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        UpdateFill()
    end)

    valueEdit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local text = self:GetText()
        -- Handle percentage input (strip % and divide by 100)
        if isPercent then
            text = text:gsub("%%", "")
            local num = tonumber(text)
            if num then
                num = num / 100
                local minVal, maxVal = slider:GetMinMaxValues()
                num = math_max(minVal, math_min(maxVal, num))
                isUpdating = true
                slider:SetValue(num)
                isUpdating = false
            else
                UpdateFill()
            end
        else
            local num = tonumber(text)
            if num then
                local minVal, maxVal = slider:GetMinMaxValues()
                num = math_max(minVal, math_min(maxVal, num))
                isUpdating = true
                slider:SetValue(num)
                isUpdating = false
            else
                UpdateFill()
            end
        end
    end)

    valueEdit:SetScript("OnEditFocusGained", function(self)
        editBoxAnimGroup:Stop()
        valueContainer:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        editBoxR, editBoxG, editBoxB = Theme.accent[1], Theme.accent[2], Theme.accent[3]
        self:HighlightText()
    end)

    valueEdit:SetScript("OnEditFocusLost", function(self)
        editBoxAnimGroup:Stop()
        valueContainer:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
        editBoxR, editBoxG, editBoxB = Theme.border[1], Theme.border[2], Theme.border[3]
        self:HighlightText(0, 0)
        local text = self:GetText()
        -- Handle percentage input (strip % and divide by 100)
        if isPercent then
            text = text:gsub("%%", "")
            local num = tonumber(text)
            if num then
                num = num / 100
                local minVal, maxVal = slider:GetMinMaxValues()
                num = math_max(minVal, math_min(maxVal, num))
                isUpdating = true
                slider:SetValue(num)
                isUpdating = false
            else
                UpdateFill()
            end
        else
            local num = tonumber(text)
            if num then
                local minVal, maxVal = slider:GetMinMaxValues()
                num = math_max(minVal, math_min(maxVal, num))
                isUpdating = true
                slider:SetValue(num)
                isUpdating = false
            else
                UpdateFill()
            end
        end
    end)

    -- Add hover animation for editbox
    valueEdit:SetScript("OnEnter", function(self)
        if not valueEdit:HasFocus() then
            AnimateEditBoxBorder(true)
        end
    end)

    valueEdit:SetScript("OnLeave", function(self)
        if not valueEdit:HasFocus() then
            AnimateEditBoxBorder(false)
        end
    end)

    local curDrag = false

    -- Mouse interaction scripts
    slider:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            hoverAnimGroup:Stop()
            thumbFrame:SetBackdropColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            thumbR, thumbG, thumbB, thumbA = Theme.accent[1], Theme.accent[2], Theme.accent[3], 1
            curDrag = true
        end
    end)

    slider:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            curDrag = false
            -- Check if mouse is still over the slider
            if self:IsMouseOver() then
                -- Still hovering, animate to hover state (textSecondary alpha 1)
                AnimateThumbColor(true, false)
            else
                -- Not hovering, animate to normal state (textSecondary alpha 0.6)
                AnimateThumbColor(false, false)
            end
        end
    end)

    slider:SetScript("OnEnter", function(self)
        if not curDrag then
            -- Hover state (textSecondary alpha 1)
            AnimateThumbColor(true, false)
        end
        if tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)

    slider:SetScript("OnLeave", function(self)
        if not curDrag then
            -- Normal state (textSecondary alpha 0.6)
            AnimateThumbColor(false, false)
        end
        GameTooltip:Hide()
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
    return row
end

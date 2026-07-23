--[[
# Checkbox

* An animated on/off toggle with a sliding knob, a label, optional tooltip and an optional flash message on change.

## Example

?   row:AddWidget(GUI:CreateCheckbox(row, 'Enable', {
?       value = db.Enabled,
?       callback = function(checked)
?           db.Enabled = checked
?       end,
?   }))

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local Animations = lib.Animations
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local select = select
local type = type
local tostring = tostring
local abs = math.abs

local C_Timer = C_Timer

local TOGGLE_WIDTH = 48
local TOGGLE_HEIGHT = 24
local KNOB_SIZE = 22
local KNOB_CROSS = 22
local KNOB_PADDING = 1
local ANIMATION_DURATION = 0.18
local OFF_POSITION = KNOB_PADDING
local ON_POSITION = TOGGLE_WIDTH - KNOB_SIZE - KNOB_PADDING

---@class KajiGUICheckboxToggle : Frame, BackdropTemplate
---@field SetValue fun(self: KajiGUICheckboxToggle, value: boolean, instant?: boolean)
---@field GetValue fun(self: KajiGUICheckboxToggle): boolean

---@class KajiGUICheckbox : Frame
---@field label FontString
---@field toggle KajiGUICheckboxToggle
---@field SetEnabled fun(self: KajiGUICheckbox, enabled: boolean)

---@class KajiGUICheckboxConfig
---@field value? boolean
---@field callback? fun(checked: boolean, revert?: fun(shouldRevert: boolean))
---@field msgPopup? boolean flash a message on change
---@field msgText? string message prefix
---@field msgOn? string
---@field msgOff? string
---@field tooltip? any
---@field cvartooltip? boolean show the default value in the tooltip

---@param parent Frame
---@param labelText string
---@param config KajiGUICheckboxConfig
---@return KajiGUICheckbox
function InstanceMixin:CreateCheckbox(parent, labelText, config)
    config = config or {}
    local gui = self
    local theme = self.theme
    local initialState = config.value or false
    local onValueChanged = config.callback
    local msgPopup = config.msgPopup
    local msgText = config.msgText
    local msgOn = config.msgOn or "Enabled"
    local msgOff = config.msgOff or "Disabled"
    local tooltip = config.tooltip
    local cvarTooltip = config.cvartooltip

    -- Create the row frame that will contain the label and toggle.
    local row = CreateFrame("Frame", nil, parent)
    pixel.SetPixelHeight(row, 36)

    -- Create the label for the checkbox.
    local label = row:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    gui:ApplyFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    label:SetShadowColor(0, 0, 0, 0)
    row.label = label

    -- Create the toggle frame.
    local toggle = CreateFrame("Frame", nil, row, "BackdropTemplate")
    pixel.SetPixelSize(toggle, TOGGLE_WIDTH, TOGGLE_HEIGHT)
    pixel.SetPixelPoint(toggle, "TOPLEFT", row, "TOPLEFT", 0, -14)
    toggle:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    toggle:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], 1)
    toggle:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)

    -- Create the knob that slides left and right to indicate the toggle state.
    local knob = CreateFrame("Frame", nil, toggle, "BackdropTemplate")
    pixel.SetPixelSize(knob, KNOB_SIZE, KNOB_SIZE)
    pixel.SetPixelPoint(knob, "LEFT", toggle, "LEFT", OFF_POSITION, 0)
    knob:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = -1, right = -1, top = 0, bottom = 0 },
    })
    knob:SetBackdropColor(0, 0, 0, 1)
    knob:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)

    -- Create the textures for the knob.
    local knobTexture = knob:CreateTexture(nil, "ARTWORK")
    knobTexture:SetAllPoints()
    knobTexture:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.6)
    pixel.SetPixelSnap(knobTexture)

    -- Checkmark texture for the "on" state.
    local checkmark = knob:CreateTexture(nil, "OVERLAY")
    pixel.SetPixelSize(checkmark, KNOB_SIZE, KNOB_SIZE)
    pixel.SetPixelPoint(checkmark, "CENTER", knob, "CENTER", 0, 0)
    checkmark:SetTexture(theme.checkTexture)
    checkmark:SetVertexColor(1, 1, 1, 1)
    pixel.SetPixelSnap(checkmark)
    checkmark:Hide()

    -- Crossmark texture for the "off" state.
    local crossmark = knob:CreateTexture(nil, "OVERLAY")
    pixel.SetPixelSize(crossmark, KNOB_CROSS, KNOB_CROSS)
    pixel.SetPixelPoint(crossmark, "CENTER", knob, "CENTER", 0, 0)
    crossmark:SetTexture(theme.crossTexture)
    crossmark:SetVertexColor(1, 1, 1, 0.8)
    pixel.SetPixelSnap(crossmark)
    crossmark:Hide()

    -- Create an animation group for the knob sliding animation.
    local animGroup = knob:CreateAnimationGroup()
    local slideAnim = animGroup:CreateAnimation("Translation")
    slideAnim:SetDuration(ANIMATION_DURATION)
    slideAnim:SetSmoothing("OUT")

    -- Color animators for the toggle background and knob. They are separate so they can be animated independently.
    local animateBg, syncBg = Animations:CreateColorAnimator(toggle,
        function(r, g, b)
            toggle:SetBackdropColor(r, g, b, 1)
        end,
        { theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], },
        ANIMATION_DURATION)
    local animateKnob, syncKnob = Animations:CreateColorAnimator(knob,
        function(r, g, b, a)
            knobTexture:SetColorTexture(r, g, b, a)
        end,
        { theme.accent[1], theme.accent[2], theme.accent[3], 0.6 },
        ANIMATION_DURATION)

    local state = initialState or false
    local isAnimating = false

    local function AnyAnimating()
        return animGroup:IsPlaying()
    end

    -- Update the visibility of the checkmark and crossmark based on the current state.
    local function UpdateIcons()
        if state then
            checkmark:Show()
            crossmark:Hide()
            checkmark:SetVertexColor(1, 1, 1, 1)
        else
            checkmark:Hide()
            crossmark:Show()
            crossmark:SetVertexColor(1, 1, 1, 0.8)
        end
    end

    -- Update the colors of the toggle background and knob based on the current state.
    local function UpdateColors(toState, instant)
        UpdateIcons()

        local bgR, bgG, bgB, knobA
        if toState then
            bgR, bgG, bgB, knobA = theme.accent[1] * 0.5, theme.accent[2] * 0.5, theme.accent[3] * 0.5, 1
        else
            bgR, bgG, bgB, knobA = theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], 0.4
        end
        local kr, kg, kb = theme.accent[1], theme.accent[2], theme.accent[3]

        if instant then
            toggle:SetBackdropColor(bgR, bgG, bgB, 1)
            syncBg(bgR, bgG, bgB)
            knobTexture:SetColorTexture(kr, kg, kb, knobA)
            syncKnob(kr, kg, kb, knobA)
        else
            animateBg(bgR, bgG, bgB)
            animateKnob(kr, kg, kb, knobA)
        end
    end

    -- Animate the toggle to the specified state, optionally instantly without animation.
    local function AnimateToState(toState, instant)
        if isAnimating and not instant then return end

        isAnimating = true
        state = toState

        local targetX = toState and ON_POSITION or OFF_POSITION
        local currentX = select(4, knob:GetPoint())
        local deltaX = targetX - currentX

        if instant or abs(deltaX) < 1 then
            knob:ClearAllPoints()
            pixel.SetPixelPoint(knob, "LEFT", toggle, "LEFT", targetX, 0)
            UpdateColors(toState, true)
            isAnimating = false
        else
            UpdateColors(toState, false)

            animGroup:Stop()
            knob:ClearAllPoints()
            pixel.SetPixelPoint(knob, "LEFT", toggle, "LEFT", currentX, 0)

            slideAnim:SetOffset(deltaX, 0)

            animGroup:SetScript("OnFinished", function()
                knob:ClearAllPoints()
                pixel.SetPixelPoint(knob, "LEFT", toggle, "LEFT", targetX, 0)
                isAnimating = false
                UpdateIcons()
            end)

            animGroup:Play()
        end
    end

    AnimateToState(state, true)

    -- Create a button overlay to handle clicks and mouse events for the toggle.
    local button = CreateFrame("Button", nil, toggle)
    button:SetAllPoints(toggle)
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", function()
        if AnyAnimating() then return end

        local newState = not state
        AnimateToState(newState, false)

        if onValueChanged then
            C_Timer.After(ANIMATION_DURATION, function()
                safecall(onValueChanged, newState, function(revert)
                    if revert then
                        AnimateToState(not newState, false)
                    end
                end)
            end)
        end

        if msgPopup then
            local toggleOnOrOff = newState and ("|cff4DCC66" .. msgOn .. "|r") or ("|cffE64D4D" .. msgOff .. "|r")
            gui:FlashMessage(msgText .. ": " .. toggleOnOrOff, { duration = 2, size = 15, y = 400 })
        end
    end)

    -- Handle mouse enter and leave events to change the knob color for visual feedback.
    button:SetScript("OnEnter", function()
        local baseA = state and 1 or 0.6
        local hr, hg, hb = theme.accent[1] * 1.2, theme.accent[2] * 1.2, theme.accent[3] * 1.2
        knobTexture:SetColorTexture(hr, hg, hb, baseA)
        syncKnob(hr, hg, hb, baseA)
    end)
    button:SetScript("OnLeave", function()
        local a = state and 1 or 0.4
        knobTexture:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], a)
        syncKnob(theme.accent[1], theme.accent[2], theme.accent[3], a)
    end)

    -- Set the value of the toggle, optionally instantly without animation.
    toggle.SetValue = function(_, value, instant)
        if value ~= state then
            AnimateToState(value, instant)
            if onValueChanged and not instant then
                C_Timer.After(ANIMATION_DURATION, function()
                    safecall(onValueChanged, value)
                end)
            end
        end
    end

    -- Get the current value of the toggle.
    toggle.GetValue = function()
        return state
    end

    -- Set the enabled state of the checkbox, affecting its appearance and interactivity.
    function row:SetEnabled(enabled)
        toggle:SetAlpha(enabled and 1 or 0.5)
        label:SetAlpha(enabled and 1 or 0.5)
        button:EnableMouse(enabled)
    end

    row.toggle = toggle

    -- Setup tooltip if provided in the config.
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
        SetupTooltip(toggle)
        SetupTooltip(button)
    end

    gui:RegisterSearchableWidget(row, labelText)
    ---@cast row KajiGUICheckbox
    return row
end

---@class NRSKNUI
local NRSKNUI = select(2, ...)
local Theme = NRSKNUI.Theme

local CreateFrame = CreateFrame
local IsControlKeyDown = IsControlKeyDown
local IsMetaKeyDown = IsMetaKeyDown
local UIFrameFadeIn = UIFrameFadeIn
local UIFrameFadeOut = UIFrameFadeOut
local ReloadUI = ReloadUI
local UIParent = UIParent
local C_Timer = C_Timer

local BUTTON_WIDTH = 100
local BUTTON_HEIGHT = 26
local HEADER_HEIGHT = 28
local EDITBOX_HEIGHT = 38
local MESSAGE_POPUP_SIZE = 64
local PADDING = 12

local function CalculateDialogSize(opts, textHeight)
    local width = opts.width or 300
    local height = HEADER_HEIGHT + PADDING

    if opts.editBox then
        height = height + EDITBOX_HEIGHT + 4
        if opts.editBoxLabel then
            height = height + 16
        end
    else
        height = height + (textHeight or 30) + PADDING
    end

    local hasButtons = opts.onAccept or opts.onCancel
    if hasButtons then
        height = height + BUTTON_HEIGHT + PADDING
    else
        height = height + 4
    end

    return width, height
end

local function ApplyBackdrop(frame, bgKey)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    local bg = Theme[bgKey]
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    frame:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
end

local function CreateDialogBase(opts, textHeight)
    local width, height = CalculateDialogSize(opts, textHeight)
    local dialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dialog:SetSize(width, height)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 350)
    dialog:SetFrameStrata("TOOLTIP")
    dialog:SetFrameLevel(100)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    ApplyBackdrop(dialog, "bgLight")
    return dialog
end

local function CreateDialogHeader(dialog, title)
    local header = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -1, -1)
    header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    header:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], 1)

    local bottomBorder = header:CreateTexture(nil, "BORDER")
    bottomBorder:SetHeight(Theme.borderSize or 1)
    bottomBorder:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    bottomBorder:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    bottomBorder:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4] or 1)

    local titleLabel = header:CreateFontString(nil, "OVERLAY")
    titleLabel:SetPoint("CENTER", header, "CENTER", 0, 0)
    if NRSKNUI.ApplyThemeFont then
        NRSKNUI:ApplyThemeFont(titleLabel, "large")
    else
        titleLabel:SetFontObject("GameFontNormalLarge")
    end
    titleLabel:SetText(title or "Confirm")
    titleLabel:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)

    return header
end

local function CreateCloseButton(header, onClose)
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(17, 17)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)

    local closeTex = closeBtn:CreateTexture(nil, "ARTWORK")
    closeTex:SetAllPoints()
    closeTex:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomCross.png")
    closeTex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    closeBtn:SetNormalTexture(closeTex)
    closeTex:SetTexelSnappingBias(0)
    closeTex:SetSnapToPixelGrid(false)

    closeBtn:SetScript("OnEnter", function()
        closeTex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeTex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    end)
    closeBtn:SetScript("OnClick", onClose)

    return closeBtn
end

local function CreateHeaderTexture(header, opts)
    if not opts.texture then return end
    local tex = opts.texture

    local frame = CreateFrame("Button", nil, header)
    frame:SetSize(tex.width or 20, tex.height or 20)
    frame:SetPoint("LEFT", header, "LEFT", 6, 0)

    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexture(tex.path)
    if tex.color then
        texture:SetVertexColor(tex.color.r or 1, tex.color.g or 1, tex.color.b or 1, 1)
    end
    texture:SetTexelSnappingBias(0)
    texture:SetSnapToPixelGrid(false)
end

local function SetupEscapeHandler(dialog, onCancel)
    dialog:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            if onCancel then onCancel() end
            self:Hide()
            NRSKNUI.activePrompt = nil
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    dialog:EnableKeyboard(true)
end

---@param timer number
---@param text string
---@param fontSize number
---@param parentFrame? Frame
---@param xOffset? number
---@param yOffset? number
function NRSKNUI:CreateMessagePopup(timer, text, fontSize, parentFrame, xOffset, yOffset)
    if NRSKNUI.msgContainer then
        NRSKNUI.msgContainer:Hide()
    end

    if not Theme then return end

    local parent = parentFrame or UIParent
    local msgContainer = CreateFrame("Frame", nil, parent)
    msgContainer:SetToplevel(true)
    msgContainer:SetFrameStrata("TOOLTIP")
    msgContainer:SetFrameLevel(150)
    msgContainer:SetSize(MESSAGE_POPUP_SIZE, MESSAGE_POPUP_SIZE)
    msgContainer:SetPoint("CENTER", parent, "CENTER", xOffset or 0, yOffset or 250)

    local msgText = msgContainer:CreateFontString(nil, "OVERLAY")
    msgText:SetPoint("CENTER")
    msgText:SetFontStyle("Expressway", fontSize, "OUTLINE")
    msgText:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    msgText:SetShadowColor(0, 0, 0, 0)
    msgText:SetText(text)

    UIFrameFadeIn(msgText, 0.2, 0, 1)
    msgContainer:Show()

    C_Timer.After(timer, function()
        UIFrameFadeOut(msgText, 1.5, 1, 0)
        C_Timer.After(1.6, function()
            msgContainer:Hide()
        end)
    end)

    NRSKNUI.msgContainer = msgContainer
    return msgContainer
end

---@class PromptOptions
---@field title? string
---@field text? string
---@field width? number
---@field editBox? boolean
---@field editBoxLabel? string
---@field texture? {path: string, width?: number, height?: number, color?: {r: number, g: number, b: number}}
---@field onAccept? function
---@field onCancel? function
---@field acceptText? string
---@field cancelText? string

local function MeasureTextHeight(text, width, fontStyle)
    local measureFrame = CreateFrame("Frame", nil, UIParent)
    measureFrame:SetSize(width, 200)

    local measureLabel = measureFrame:CreateFontString(nil, "OVERLAY")
    measureLabel:SetWidth(width)
    measureLabel:SetPoint("TOPLEFT", measureFrame, "TOPLEFT", 0, 0)
    measureLabel:SetJustifyH("CENTER")
    measureLabel:SetJustifyV("TOP")
    measureLabel:SetWordWrap(true)
    if NRSKNUI.ApplyThemeFont then
        NRSKNUI:ApplyThemeFont(measureLabel, fontStyle or "normal")
    else
        measureLabel:SetFontObject("GameFontNormal")
    end
    measureLabel:SetText(text or "")

    local height = measureLabel:GetStringHeight()
    measureFrame:Hide()
    measureFrame:SetParent(nil)

    return math.max(height + 4, 20)
end

---@param opts PromptOptions
function NRSKNUI:CreatePrompt(opts)
    if NRSKNUI.activePrompt then
        NRSKNUI.activePrompt:Hide()
    end

    if not Theme then return end

    local GUIFrame = NRSKNUI.GUIFrame
    local dialogWidth = opts.width or 280
    local textWidth = dialogWidth - (PADDING * 2)

    local textHeight
    if not opts.editBox and opts.text then
        textHeight = MeasureTextHeight(opts.text, textWidth, "normal")
    end

    local dialog = CreateDialogBase(opts, textHeight)
    local header = CreateDialogHeader(dialog, opts.title)

    local function CloseDialog()
        dialog:Hide()
        NRSKNUI.activePrompt = nil
    end

    CreateCloseButton(header, function()
        if opts.onCancel then opts.onCancel() end
        CloseDialog()
    end)

    CreateHeaderTexture(header, opts)

    local isCopyMode = opts.editBox and not opts.onAccept

    if opts.editBox then
        local editBoxWidget = GUIFrame:CreateEditBox(dialog, opts.editBoxLabel or "", {
            value = opts.text or "",
            autoFocus = true,
        })
        editBoxWidget:SetPoint("TOPLEFT", header, "BOTTOMLEFT", PADDING, -8)
        editBoxWidget:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -PADDING, -8)

        local editBox = editBoxWidget.editBox
        editBox:HighlightText()
        editBox:SetJustifyH("CENTER")

        if isCopyMode then
            editBox:SetScript("OnKeyDown", function(_, key)
                if key == "C" and (IsControlKeyDown() or IsMetaKeyDown()) then
                    NRSKNUI:CreateMessagePopup(2, "Copied to clipboard", 18, UIParent, 0, 350)
                    CloseDialog()
                end
            end)
        else
            editBox:SetScript("OnEnterPressed", function(eb)
                if opts.onAccept then
                    opts.onAccept(eb:GetText())
                end
                CloseDialog()
            end)
        end

        dialog.editBox = editBox
    else
        local messageLabel = dialog:CreateFontString(nil, "OVERLAY")
        messageLabel:SetPoint("TOPLEFT", header, "BOTTOMLEFT", PADDING, -PADDING)
        messageLabel:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -PADDING, -PADDING)
        messageLabel:SetJustifyH("CENTER")
        messageLabel:SetJustifyV("TOP")
        if NRSKNUI.ApplyThemeFont then
            NRSKNUI:ApplyThemeFont(messageLabel, "normal")
        else
            messageLabel:SetFontObject("GameFontNormal")
        end
        messageLabel:SetText(opts.text or "")
        messageLabel:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3], 1)
    end

    if not isCopyMode then
        local buttonContainer = CreateFrame("Frame", nil, dialog)
        buttonContainer:SetHeight(BUTTON_HEIGHT)
        buttonContainer:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", PADDING, PADDING)
        buttonContainer:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -PADDING, PADDING)

        local acceptBtn = GUIFrame:CreateButton(buttonContainer, opts.acceptText or "Accept", {
            width = BUTTON_WIDTH,
            height = BUTTON_HEIGHT,
            callback = function()
                if opts.onAccept then
                    if dialog.editBox then
                        opts.onAccept(dialog.editBox:GetText())
                    else
                        opts.onAccept()
                    end
                end
                CloseDialog()
            end
        })
        acceptBtn:SetPoint("RIGHT", buttonContainer, "CENTER", -4, 0)

        local cancelBtn = GUIFrame:CreateButton(buttonContainer, opts.cancelText or "Cancel", {
            width = BUTTON_WIDTH,
            height = BUTTON_HEIGHT,
            callback = function()
                if opts.onCancel then opts.onCancel() end
                CloseDialog()
            end
        })
        cancelBtn:SetPoint("LEFT", buttonContainer, "CENTER", 4, 0)
        cancelBtn.text:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3], 1)
    end

    SetupEscapeHandler(dialog, opts.onCancel)

    dialog:Show()
    NRSKNUI.activePrompt = dialog

    return dialog
end

---@param title string
---@param text string
---@param label? string
function NRSKNUI:CreateCopyDialog(title, text, label)
    return self:CreatePrompt({
        title = title,
        text = text,
        editBox = true,
        editBoxLabel = label or "CTRL-C to copy",
    })
end

---@param reason? string
function NRSKNUI:CreateReloadPrompt(reason)
    return self:CreatePrompt({
        title = "Reload Required",
        text = reason or "Would you like to reload your UI now?",
        width = 340,
        onAccept = function() ReloadUI() end,
        acceptText = "Reload Now",
        cancelText = "Later",
    })
end

---@param modulePath string ProfileManager module path (e.g., "Skinning.BuffTracking")
---@param moduleName string Display name for the module
---@param promptText? string Custom prompt text
function NRSKNUI:CreateResetModulePrompt(modulePath, moduleName, promptText)
    return self:CreatePrompt({
        title = "Reset Module",
        text = promptText or ("Reset " .. moduleName .. " settings to defaults?"),
        width = 320,
        onAccept = function()
            local success, err = NRSKNUI.ProfileManager:ResetModuleSettings(modulePath, moduleName)
            if success then
                NRSKNUI:CreateReloadPrompt("Settings reset. Reload to apply all changes.")
            else
                NRSKNUI:Print("Reset failed: " .. (err or "unknown error"))
            end
        end,
        acceptText = "Reset",
        cancelText = "Cancel",
    })
end

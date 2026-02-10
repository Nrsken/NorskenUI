-- NorskenUI namespace
local _, NRSKNUI = ...
local Theme = NRSKNUI.Theme

-- Custom dialog frame and message popup frame

-- Localization
local CreateFrame = CreateFrame
local IsControlKeyDown = IsControlKeyDown
local IsMetaKeyDown = IsMetaKeyDown
local StaticPopup_Show = StaticPopup_Show
local UIFrameFadeIn = UIFrameFadeIn
local UIFrameFadeOut = UIFrameFadeOut
local type = type
local ReloadUI = ReloadUI
local UIParent = UIParent
local C_Timer = C_Timer

-- Module locals
local ACCEPT = ACCEPT
local CANCEL = CANCEL

-- UI Constants
local POPUP_WIDTH = 360
local POPUP_HEIGHT = 120
local BUTTON_WIDTH = 100
local BUTTON_HEIGHT = 26
local MESSAGE_POPUP_SIZE = 64

-- Helper: Validate theme colors
local function ValidateThemeColor(color, default)
    if not color or type(color) ~= "table" then return default end
    return color
end

-- Helper: Create Message Popup
function NRSKNUI:CreateMessagePopup(timer, text, fontSize, parentFrame, xOffset, yOffset)
    if NRSKNUI.msgContainer then
        NRSKNUI.msgContainer:Hide()
    end

    local parent = parentFrame or UIParent
    local x = xOffset or 0
    local y = yOffset or 250

    if not Theme then return end

    local msgContainer = CreateFrame("Frame", nil, parent)
    msgContainer:SetToplevel(true)
    msgContainer:SetFrameStrata("TOOLTIP")
    msgContainer:SetFrameLevel(150)
    msgContainer:SetSize(MESSAGE_POPUP_SIZE, MESSAGE_POPUP_SIZE)
    msgContainer:SetPoint("CENTER", parent, "CENTER", x, y)

    local msgText = msgContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    msgText:SetPoint("CENTER")
    msgText:SetText(text)
    msgText:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")

    local accent = ValidateThemeColor(Theme.accent, { 1, 0.82, 0, 1 })
    msgText:SetTextColor(accent[1], accent[2], accent[3], 1)
    msgText:SetShadowColor(0, 0, 0, 0)

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

-- Helper: Create themed button for prompts
local function CreateThemedButton(parent, Theme, labelText, isPrimary)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    local textColor = isPrimary and Theme.accent or Theme.textPrimary
    local bgMedium = ValidateThemeColor(Theme.bgMedium, { 0.1, 0.1, 0.1, 1 })
    local bgLight = ValidateThemeColor(Theme.bgLight, { 0.15, 0.15, 0.15, 1 })
    local border = ValidateThemeColor(Theme.border, { 0.3, 0.3, 0.3, 1 })
    local accent = ValidateThemeColor(Theme.accent, { 1, 0.82, 0, 1 })

    btn:SetBackdropColor(bgMedium[1], bgMedium[2], bgMedium[3], 1)
    btn:SetBackdropBorderColor(border[1], border[2], border[3], 1)

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetPoint("CENTER")
    if NRSKNUI.ApplyThemeFont then
        NRSKNUI:ApplyThemeFont(label, "normal")
    else
        label:SetFontObject("GameFontNormal")
    end
    label:SetText(labelText)
    label:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
    label:SetShadowColor(0, 0, 0, 0)
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(bgLight[1], bgLight[2], bgLight[3], 1)
        self:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(bgMedium[1], bgMedium[2], bgMedium[3], 1)
        self:SetBackdropBorderColor(border[1], border[2], border[3], 1)
    end)

    return btn
end

-- CreatePrompt: Create a themed prompt dialog
-- Could have just made a table for texture stuff but im noob
--[[ Usage:
NRSKNUI:CreatePrompt(
    "Title text, shown on header",
    "Text shown in the dialog frame itself, if showEditBox is set to true, this is the text that gets placed in the editbox",
    showEditBox (true/false, this controls if it's a Editbox dialogframe or normal 2 button + text frame),
    "Editbox label text",
    useTexture (true/false, sets use of texture in the topleft),
    "Interface\\AddOns\\NorskenUI\\Media\\SupportLogos\\Twitchv2W.png" (texture path),
    textureSizeX (texture width),
    textureSizeY (texture height),
    textureColor (texture color),
    onAccept (callback when you click accept button),
    onCancel (callback when you click cancel button),
    acceptText (text on the accept button),
    cancelText (text on the cancel button),
    )
--]]
function NRSKNUI:CreatePrompt(title, text, showEditBox, editBoxLabelText, useTexture, texturePath, textureSizeX,
                              textureSizeY, textureColor, onAccept, onCancel, acceptText, cancelText)
    if not Theme then
        StaticPopupDialogs["NRSKNUI_PROMPT_DIALOG"] = {
            text = text or "",
            button1 = acceptText or ACCEPT,
            button2 = cancelText or CANCEL,
            OnAccept = onAccept,
            OnCancel = onCancel,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        return StaticPopup_Show("NRSKNUI_PROMPT_DIALOG")
    end

    if NRSKNUI.activePrompt then
        NRSKNUI.activePrompt:Hide()
    end

    -- Validate theme colors
    local bgLight = ValidateThemeColor(Theme.bgLight, { 0.15, 0.15, 0.15, 1 })
    local bgMedium = ValidateThemeColor(Theme.bgMedium, { 0.1, 0.1, 0.1, 1 })
    local border = ValidateThemeColor(Theme.border, { 0.3, 0.3, 0.3, 1 })
    local accent = ValidateThemeColor(Theme.accent, { 1, 0.82, 0, 1 })
    local textPrimary = ValidateThemeColor(Theme.textPrimary, { 1, 1, 1, 1 })
    local textSecondary = ValidateThemeColor(Theme.textSecondary, { 0.7, 0.7, 0.7, 1 })

    local dialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dialog:SetSize(POPUP_WIDTH, POPUP_HEIGHT)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    dialog:SetFrameStrata("TOOLTIP")
    dialog:SetFrameLevel(100)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)

    dialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    dialog:SetBackdropColor(bgLight[1], bgLight[2], bgLight[3], bgLight[4] or 1)
    dialog:SetBackdropBorderColor(border[1], border[2], border[3], 1)

    local header = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    header:SetHeight(28)
    header:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -1, -1)
    header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    header:SetBackdropColor(bgMedium[1], bgMedium[2], bgMedium[3], 1)

    local headerbottomBorder = header:CreateTexture(nil, "BORDER")
    headerbottomBorder:SetHeight(Theme.borderSize or 1)
    headerbottomBorder:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    headerbottomBorder:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    headerbottomBorder:SetColorTexture(border[1], border[2], border[3], border[4] or 1)

    local titleLabel = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("CENTER", header, "CENTER", 0, 0)
    titleLabel:SetText(title or "Confirm")
    titleLabel:SetTextColor(accent[1], accent[2], accent[3], accent[4] or 1)
    titleLabel:SetShadowColor(0, 0, 0, 0)

    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(17, 17)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)

    local closeTex = closeBtn:CreateTexture(nil, "ARTWORK")
    closeTex:SetAllPoints()
    closeTex:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomCross.png")
    closeTex:SetVertexColor(textSecondary[1], textSecondary[2], textSecondary[3], 1)
    closeBtn:SetNormalTexture(closeTex)
    closeTex:SetTexelSnappingBias(0)
    closeTex:SetSnapToPixelGrid(false)

    closeBtn:SetScript("OnEnter", function()
        closeTex:SetVertexColor(accent[1], accent[2], accent[3], accent[4] or 1)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeTex:SetVertexColor(textSecondary[1], textSecondary[2], textSecondary[3], 1)
    end)
    closeBtn:SetScript("OnClick", function()
        if onCancel then onCancel() end
        dialog:Hide()
        NRSKNUI.activePrompt = nil
    end)

    if useTexture and texturePath then
        local logoN = CreateFrame("Button", nil, header)
        logoN:SetSize(textureSizeX, textureSizeY)
        logoN:SetPoint("LEFT", header, "LEFT", 6, 0)
        local logoTexture = logoN:CreateTexture(nil, "ARTWORK")
        logoTexture:SetAllPoints()
        logoTexture:SetTexture(texturePath)
        if textureColor then
            logoTexture:SetVertexColor(textureColor.r, textureColor.g, textureColor.b, 1)
        end
        logoTexture:SetTexelSnappingBias(0)
        logoTexture:SetSnapToPixelGrid(false)
    end

    if not showEditBox or onAccept and not dialog.messageLabel then
        local messageLabel = dialog:CreateFontString(nil, "OVERLAY")
        messageLabel:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 12, -12)
        messageLabel:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -12, -12)
        messageLabel:SetJustifyH("CENTER")
        messageLabel:SetJustifyV("TOP")
        if NRSKNUI.ApplyThemeFont then
            NRSKNUI:ApplyThemeFont(messageLabel, "normal")
        else
            messageLabel:SetFontObject("GameFontNormal")
        end
        messageLabel:SetText(text or "")
        messageLabel:SetTextColor(textPrimary[1], textPrimary[2], textPrimary[3], 1)
        messageLabel:SetShadowColor(0, 0, 0, 0)
    end

    if showEditBox and not dialog.editBox then
        local editBox = CreateFrame("EditBox", nil, dialog, "BackdropTemplate")
        editBox:SetSize(dialog:GetWidth() - 24, 24)
        editBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 12, -12)
        editBox:SetAutoFocus(true)
        editBox:SetText("")
        editBox:SetJustifyH("CENTER")

        editBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        editBox:SetBackdropColor(bgMedium[1], bgMedium[2], bgMedium[3], 1)
        editBox:SetBackdropBorderColor(border[1], border[2], border[3], 1)
        if NRSKNUI.ApplyThemeFont then
            NRSKNUI:ApplyThemeFont(editBox, "normal")
        else
            editBox:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        end
        editBox:SetTextColor(textPrimary[1], textPrimary[2], textPrimary[3], 1)
        editBox:SetShadowColor(0, 0, 0, 0)

        if not onAccept then
            editBox:SetScript("OnKeyDown", function(self, key)
                if key == "C" and (IsControlKeyDown() or IsMetaKeyDown()) then
                    NRSKNUI:CreateMessagePopup(2, "Copied to clipboard", 18, UIParent, 0, 350)
                    if onCancel then onCancel() end
                    dialog:Hide()
                    NRSKNUI.activePrompt = nil
                end
            end)
        else
            editBox:SetScript("OnEnterPressed", function(self)
                if onAccept then
                    onAccept(self:GetText())
                    dialog:Hide()
                    NRSKNUI.activePrompt = nil
                end
            end)
        end

        editBox:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
        end)
        editBox:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(border[1], border[2], border[3], 1)
        end)

        local editBoxLabel = dialog:CreateFontString(nil, "OVERLAY")
        editBoxLabel:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 12, -12)
        editBoxLabel:SetPoint("TOPRIGHT", editBox, "BOTTOMRIGHT", -12, -12)
        editBoxLabel:SetJustifyH("CENTER")
        editBoxLabel:SetJustifyV("TOP")
        if NRSKNUI.ApplyThemeFont then
            NRSKNUI:ApplyThemeFont(editBoxLabel, "normal")
        else
            editBoxLabel:SetFontObject("GameFontNormal")
        end
        editBoxLabel:SetText(editBoxLabelText or "")
        editBoxLabel:SetTextColor(textSecondary[1], textSecondary[2], textSecondary[3], 1)
        editBoxLabel:SetShadowColor(0, 0, 0, 0)

        dialog.editBox = editBox
    end

    if dialog.editBox then
        dialog.editBox:SetText(text or "")
        dialog.editBox:HighlightText()
        dialog.editBox:SetAutoFocus(true)
    end

    if not showEditBox or onAccept then
        local buttonContainer = CreateFrame("Frame", nil, dialog)
        buttonContainer:SetHeight(30)
        buttonContainer:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 12, 12)
        buttonContainer:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -12, 12)

        local acceptBtn = CreateThemedButton(buttonContainer, Theme, acceptText or "Accept", true)
        acceptBtn:SetPoint("RIGHT", buttonContainer, "CENTER", -4, 0)
        acceptBtn:SetScript("OnClick", function()
            if onAccept then
                if showEditBox and dialog.editBox then
                    onAccept(dialog.editBox:GetText())
                else
                    onAccept()
                end
            end
            dialog:Hide()
            NRSKNUI.activePrompt = nil
        end)

        local cancelBtn = CreateThemedButton(buttonContainer, Theme, cancelText or "Cancel", false)
        cancelBtn:SetPoint("LEFT", buttonContainer, "CENTER", 4, 0)
        cancelBtn:SetScript("OnClick", function()
            if onCancel then onCancel() end
            dialog:Hide()
            NRSKNUI.activePrompt = nil
        end)
    end

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

    dialog:Show()
    NRSKNUI.activePrompt = dialog

    return dialog
end

-- CreateReloadPrompt: Create a themed reload prompt dialog
-- Usage very simple: NRSKNUI:CreateReloadPrompt("Text that explains why user needs to reload for example")
function NRSKNUI:CreateReloadPrompt(reason)
    local text = reason or "Would you like to reload your UI now?"
    return self:CreatePrompt(
        "Reload Required",
        text,
        false,
        nil,
        false,
        nil,
        nil,
        nil,
        nil,
        function() ReloadUI() end,
        nil,
        "Reload Now",
        "Later"
    )
end

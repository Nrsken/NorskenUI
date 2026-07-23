--[[
# Dialog

* Themed transient messages (FlashMessage) and modal prompts (Prompt / CopyDialog).

## Example

?   GUI:FlashMessage('Combat Cross')
?   GUI:FlashMessage('Saved', {
?       duration = 1,
?       y = 300
?   })

?   GUI:Prompt({
?       title = 'Reload Required',
?       text = 'Reload your UI now?',
?       onAccept = ReloadUI,
?   })

?   GUI:CopyDialog('Export', exportString, 'CTRL-C to copy')

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel


local CreateFrame = CreateFrame
local UIFrameFadeIn = UIFrameFadeIn
local UIFrameFadeOut = UIFrameFadeOut
local IsControlKeyDown = IsControlKeyDown
local IsMetaKeyDown = IsMetaKeyDown
local max = math.max

local After = C_Timer.After

local WHITE = "Interface\\Buttons\\WHITE8X8"

---Flashes an accent-colored message that fades in, holds, then fades out.
---@param text string
---@param opts? { duration?: number, size?: "small"|"normal"|"large"|number, parent?: Frame, x?: number, y?: number }
function InstanceMixin:FlashMessage(text, opts)
    opts = opts or {}

    -- Reuse a single container per instance so rapid toggles don't stack messages.
    local container = self._flashContainer
    if not container then
        container = CreateFrame("Frame", nil, opts.parent or UIParent)
        container:SetToplevel(true)
        container:SetFrameStrata("TOOLTIP")
        container.text = container:CreateFontString(nil, "OVERLAY")
        pixel.SetPixelPoint(container.text, "CENTER")
        self._flashContainer = container
    end

    container:SetParent(opts.parent or UIParent)
    container:ClearAllPoints()
    pixel.SetPixelPoint(container, "CENTER", opts.parent or UIParent, "CENTER", opts.x or 0, opts.y or 250)

    local fontString = container.text
    self:ApplyFont(fontString, opts.size or "large")
    fontString:SetTextColor(self:Color("accent"))
    fontString:SetText(text)

    UIFrameFadeIn(fontString, 0.2, 0, 1)
    container:Show()

    -- Cancel any in-flight fade-out from a previous call, then schedule this one.
    self._flashToken = (self._flashToken or 0) + 1
    local token = self._flashToken
    After(opts.duration or 2, function()
        if self._flashToken ~= token then return end
        UIFrameFadeOut(fontString, 1.5, 1, 0)
        After(1.6, function()
            if self._flashToken == token then
                container:Hide()
            end
        end)
    end)

    return container
end

--[[ Modal prompts -------------------------------------------------------------
A centered, movable dialog with a header, optional edit box or message body and
Accept/Cancel buttons. When an edit box is supplied without an onAccept handler
it becomes a copy dialog (CTRL-C to copy, no buttons). ]]

local BUTTON_WIDTH = 100
local BUTTON_HEIGHT = 26
local HEADER_HEIGHT = 28
local EDITBOX_HEIGHT = 38
local PADDING = 12

---@class KajiPromptOptions
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

    if opts.onAccept or opts.onCancel then
        height = height + BUTTON_HEIGHT + PADDING
    else
        height = height + 4
    end

    return width, height
end

local function CreateDialogBase(theme, opts, textHeight)
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
    dialog:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    dialog:SetBackdropColor(theme.bgLight[1], theme.bgLight[2], theme.bgLight[3], theme.bgLight[4] or 1)
    dialog:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
    return dialog
end

local function CreateDialogHeader(gui, dialog, title)
    local theme = gui.theme
    local header = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -1, -1)
    header:SetBackdrop({ bgFile = WHITE })
    header:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], 1)

    local bottomBorder = header:CreateTexture(nil, "BORDER")
    bottomBorder:SetHeight(theme.borderSize or 1)
    bottomBorder:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    bottomBorder:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    bottomBorder:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], theme.border[4] or 1)

    local titleLabel = header:CreateFontString(nil, "OVERLAY")
    titleLabel:SetPoint("CENTER", header, "CENTER", 0, 0)
    gui:ApplyFont(titleLabel, "large")
    titleLabel:SetText(title or "Confirm")
    titleLabel:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)

    return header
end

local function CreateCloseButton(gui, header, onClose)
    local theme = gui.theme
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(17, 17)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)

    local closeTex = closeBtn:CreateTexture(nil, "ARTWORK")
    closeTex:SetAllPoints()
    closeTex:SetTexture(theme.crossTexture)
    closeTex:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
    closeBtn:SetNormalTexture(closeTex)
    closeTex:SetTexelSnappingBias(0)
    closeTex:SetSnapToPixelGrid(false)

    closeBtn:SetScript("OnEnter", function()
        closeTex:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeTex:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
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

local function MeasureTextHeight(gui, text, width, fontStyle)
    local measureFrame = CreateFrame("Frame", nil, UIParent)
    measureFrame:SetSize(width, 200)

    local measureLabel = measureFrame:CreateFontString(nil, "OVERLAY")
    measureLabel:SetWidth(width)
    measureLabel:SetPoint("TOPLEFT", measureFrame, "TOPLEFT", 0, 0)
    measureLabel:SetJustifyH("CENTER")
    measureLabel:SetJustifyV("TOP")
    measureLabel:SetWordWrap(true)
    gui:ApplyFont(measureLabel, fontStyle or "normal")
    measureLabel:SetText(text or "")

    local height = measureLabel:GetStringHeight()
    measureFrame:Hide()
    measureFrame:SetParent(nil)

    return max(height + 4, 20)
end

local function SetupEscapeHandler(gui, dialog, onCancel)
    dialog:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            if onCancel then onCancel() end
            self:Hide()
            gui._activePrompt = nil
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    dialog:EnableKeyboard(true)
end

---Opens a modal prompt. Only one prompt is active per instance at a time.
---@param opts KajiPromptOptions
---@return Frame
function InstanceMixin:Prompt(opts)
    if self._activePrompt then
        self._activePrompt:Hide()
    end

    local theme = self.theme
    local dialogWidth = opts.width or 280
    local textWidth = dialogWidth - (PADDING * 2)

    local textHeight
    if not opts.editBox and opts.text then
        textHeight = MeasureTextHeight(self, opts.text, textWidth, "normal")
    end

    local dialog = CreateDialogBase(theme, opts, textHeight)
    local header = CreateDialogHeader(self, dialog, opts.title)

    local function CloseDialog()
        dialog:Hide()
        self._activePrompt = nil
    end

    CreateCloseButton(self, header, function()
        if opts.onCancel then opts.onCancel() end
        CloseDialog()
    end)

    CreateHeaderTexture(header, opts)

    local isCopyMode = opts.editBox and not opts.onAccept

    if opts.editBox then
        local editBoxWidget = self:CreateEditBox(dialog, opts.editBoxLabel or "", {
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
                    self:FlashMessage("Copied to clipboard", { duration = 2, size = 18, y = 350 })
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
        self:ApplyFont(messageLabel, "normal")
        messageLabel:SetText(opts.text or "")
        messageLabel:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
    end

    if not isCopyMode then
        local buttonContainer = CreateFrame("Frame", nil, dialog)
        buttonContainer:SetHeight(BUTTON_HEIGHT)
        buttonContainer:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", PADDING, PADDING)
        buttonContainer:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -PADDING, PADDING)

        local acceptBtn = self:CreateButton(buttonContainer, opts.acceptText or "Accept", {
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

        local cancelBtn = self:CreateButton(buttonContainer, opts.cancelText or "Cancel", {
            width = BUTTON_WIDTH,
            height = BUTTON_HEIGHT,
            callback = function()
                if opts.onCancel then opts.onCancel() end
                CloseDialog()
            end
        })
        cancelBtn:SetPoint("LEFT", buttonContainer, "CENTER", 4, 0)
        cancelBtn.text:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
    end

    SetupEscapeHandler(self, dialog, opts.onCancel)

    dialog:Show()
    self._activePrompt = dialog

    return dialog
end

---Opens a copy dialog: a read-only-feel edit box the user copies with CTRL-C.
---@param title string
---@param text string
---@param label? string
---@return Frame
function InstanceMixin:CopyDialog(title, text, label)
    return self:Prompt({
        title = title,
        text = text,
        editBox = true,
        editBoxLabel = label or "CTRL-C to copy",
    })
end

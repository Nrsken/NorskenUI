---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class Chatv2: AceModule, AceEvent-3.0, AceHook-3.0
local CHAT = NRSKNUI:NewModule("Chatv2", "AceEvent-3.0", "AceHook-3.0")

local LSM = NRSKNUI.Libs.LSM
local Theme = NRSKNUI.Theme

local CreateFrame = CreateFrame
local UIParent = UIParent
local GameTooltip = GameTooltip
local _G = _G
local ipairs = ipairs
local pairs = pairs
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local IsCombatLog = IsCombatLog
local IsBuiltinChatWindow = IsBuiltinChatWindow
local IsShiftKeyDown = IsShiftKeyDown
local GetCVar = GetCVar
local GetChatWindowInfo = GetChatWindowInfo
local FCF_GetChatWindowInfo = FCF_GetChatWindowInfo
local GetChannelName = GetChannelName
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local format = format
local IsAltKeyDown = IsAltKeyDown
local Mixin = Mixin
local tinsert = tinsert
local tremove = tremove
local strlower = strlower
local strupper = strupper
local gsub = gsub
local strmatch = strmatch
local time = time
local GetRealmName = GetRealmName
local wipe = wipe
local UNKNOWN = UNKNOWN
local BetterDate = (TimeUtil and TimeUtil.BetterDate) or BetterDate
local AFK = AFK
local DND = DND
local GetServerTime = GetServerTime
local PlaySound = PlaySound

local ChatEditSetLastActiveWindow = (_G.ChatFrameUtil and _G.ChatFrameUtil.SetLastActiveWindow) or
    _G.ChatEdit_SetLastActiveWindow
local SOUND_U_CHAT_SCROLL_BUTTON = SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115

local PANEL_HEIGHT = 250
local EDITBOX_HEIGHT = 22
local PANEL_WIDTH = 450
local PANEL_FRAME_LEVEL = 300
local CHAT_FRAME_LEVEL = 4
local BASE_OFFSET = 35
local PADDING = 5
local H_PADDING = 5
local TAB_HEIGHT = 22
local COPY_FRAME_WIDTH = 700
local COPY_FRAME_HEIGHT = 300

local IGNORE_FRAMES = { [2] = "CombatLog", [3] = "Voice", }
local tconcat = table.concat
local function Lerp(a, b, t) return a + (b - a) * t end
local function NormalizeFontOutline(outline)
    if not outline or outline == "NONE" then return "" end
    return outline
end
local TAB_TEXTURES = { "", "Selected", "Active", "Highlight" }
local BACKDROP_TEMPLATE = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1, }

local TAB_STYLES = {
    NONE   = "%s",
    ARROW  = "%s>|r%s%s<|r",
    ARROW1 = "%s>|r %s %s<|r",
    ARROW2 = "%s<|r%s%s>|r",
    ARROW3 = "%s<|r %s %s>|r",
    BOX    = "%s[|r%s%s]|r",
    BOX1   = "%s[|r %s %s]|r",
    CURLY  = "%s{|r%s%s}|r",
    CURLY1 = "%s{|r %s %s}|r",
    CURVE  = "%s(|r%s%s)|r",
    CURVE1 = "%s(|r %s %s)|r",
}

local HYPERLINK_TYPES = {
    achievement = true,
    apower = true,
    currency = true,
    enchant = true,
    glyph = true,
    instancelock = true,
    item = true,
    keystone = true,
    quest = true,
    spell = true,
    talent = true,
    unit = true,
}

-- Cached values to avoid repeated lookups
local cachedFontPath
local cachedTabAccentColor = { r = 1, g = 0.82, b = 0 }
local cachedThemeAccentColor = { r = 1, g = 1, b = 1 }

local SHORT_CHANNELS = {
    GUILD = "G",
    PARTY = "P",
    RAID = "R",
    OFFICER = "O",
    INSTANCE_CHAT = "I",
}

local SHORT_CHANNEL_NAMES = {
    { global = "CHAT_RAID_WARNING_GET",  short = "RW" },
    { global = "CHAT_INSTANCE_CHAT_GET", short = "I" },
    { global = "CHAT_PARTY_GET",         short = "P" },
    { global = "CHAT_RAID_GET",          short = "R" },
    { global = "CHAT_GUILD_GET",         short = "G" },
    { global = "CHAT_OFFICER_GET",       short = "O" },
}

local SHORT_CHANNEL_PATTERNS
local function BuildShortChannelPatterns()
    if SHORT_CHANNEL_PATTERNS then return end
    SHORT_CHANNEL_PATTERNS = {}

    for _, info in ipairs(SHORT_CHANNEL_NAMES) do
        local formatStr = _G[info.global]
        if formatStr then
            local bracketText = strmatch(formatStr, "(%[.-%])")
            if bracketText then
                local escapedPattern = gsub(bracketText, "([%[%]%-])", "%%%1")
                tinsert(SHORT_CHANNEL_PATTERNS,
                    { pattern = "^" .. escapedPattern, replacement = "[" .. info.short .. "]" })
            end
        end
    end
end

CHAT.ChatWindow = nil
CHAT.ClassNames = {}
CHAT.originalStates = {}


function CHAT:UpdateDB()
    self.db = NRSKNUI.db.profile.Skinning.Chatv2
    local effectiveFont = NRSKNUI:GetEffectiveFont(self.db)
    cachedFontPath = LSM and LSM:Fetch("font", effectiveFont) or STANDARD_TEXT_FONT
    local customColor = self.db.TabTextColor
    if customColor then
        cachedTabAccentColor.r = customColor.r or 1
        cachedTabAccentColor.g = customColor.g or 0.82
        cachedTabAccentColor.b = customColor.b or 0
    end
    cachedThemeAccentColor.r = Theme.accent[1]
    cachedThemeAccentColor.g = Theme.accent[2]
    cachedThemeAccentColor.b = Theme.accent[3]
end

function CHAT:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
    BuildShortChannelPatterns()
end

function CHAT:PlayWhisperSound(soundName)
    if not soundName or soundName == "None" then return end
    local file = LSM:Fetch("sound", soundName)
    NRSKNUI:PlaySound(file)
end

function CHAT:RegisterWhisperSounds()
    local ws = self.db.WhisperSounds
    if not ws or not ws.Enabled then return end
    if self.whisperSoundsRegistered then return end
    self.whisperSoundsRegistered = true

    self:RegisterEvent("CHAT_MSG_WHISPER", function()
        self:PlayWhisperSound(ws.WhisperSound)
    end)
    self:RegisterEvent("CHAT_MSG_BN_WHISPER", function()
        self:PlayWhisperSound(ws.BNetWhisperSound)
    end)
end

local canChangeMessage = function(arg1, id)
    if id and arg1 == "" then return id end
end

function CHAT:MessageIsProtected(message)
    if NRSKNUI:IsSecretValue(message) then return true end
    return message and (message ~= gsub(message, "(:?|?)|K(.-)|k", canChangeMessage))
end

-- Chat Copy Feature
local copyLines = {}

local removeIconFromLine
do
    local raidIconFunc = function(x)
        x = x ~= "" and _G["RAID_TARGET_" .. x]
        return x and ("{" .. strlower(x) .. "}") or ""
    end
    local stripTextureFunc = function(w, x, y)
        if x == "" then return (w ~= "" and w) or (y ~= "" and y) or "" end
    end
    local hyperLinkFunc = function(w, x, y)
        if w ~= "" then return end
        return y
    end
    local fourString = function(v, w, x, y)
        return format("%s%s%s", v, w, (v and v == "1" and x) or y)
    end

    removeIconFromLine = function(text)
        if not text then return "" end
        text = gsub(text, [[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_(%d+):0|t]], raidIconFunc)
        text = gsub(text, "(%s?)(|?)|[TA].-|[ta](%s?)", stripTextureFunc)
        text = gsub(text, "(|?)|H(.-)|h(.-)|h", hyperLinkFunc)
        text = gsub(text, "(%d+)(.-)|4(.-):(.-);", fourString)
        return text
    end
end

local function ColorizeLine(text, r, g, b)
    return format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
end

function CHAT:GetChatLines(frame)
    if not frame or not frame.GetNumMessages then
        return 0
    end

    local numMessages = frame:GetNumMessages()
    if not numMessages or numMessages == 0 then
        return 0
    end

    local index = 1
    for i = 1, numMessages do
        local message, r, g, b = frame:GetMessageInfo(i)
        if message and not self:MessageIsProtected(message) then
            r, g, b = r or 1, g or 1, b or 1
            message = removeIconFromLine(message)
            message = ColorizeLine(message, r, g, b)
            copyLines[index] = message
            index = index + 1
        end
    end
    return index - 1
end

function CHAT:CopyChat(frame)
    if not self.CopyChatFrame then
        self:BuildCopyChatFrame()
    end

    if not self.CopyChatFrame then
        return
    end

    if self.CopyChatFrame:IsShown() then
        self.CopyChatFrameEditBox:SetText("")
        self.CopyChatFrame:Hide()
    else
        local count = self:GetChatLines(frame)
        if count > 0 then
            local text = tconcat(copyLines, " \n", 1, count)
            self.CopyChatFrameEditBox:SetText(text)
        else
            self.CopyChatFrameEditBox:SetText("")
        end
        self.CopyChatFrame:Show()
    end
end

function CHAT:CopyChatEditBox_OnEscapePressed()
    CHAT.CopyChatFrame:Hide()
end

function CHAT:CopyChatEditBox_OnTextChanged(userInput)
    if userInput then return end
    local scrollFrame = CHAT.CopyChatScrollFrame
    local scrollbar = CHAT.CopyChatFrame and CHAT.CopyChatFrame.scrollbar
    if scrollFrame and scrollbar then
        local _, maxValue = scrollbar:GetMinMaxValues()
        if maxValue and maxValue > 0 then
            scrollbar:SetValue(maxValue)
        end
    end
end

function CHAT:CopyChatScrollFrame_OnSizeChanged(width, height)
    if CHAT.CopyChatFrameEditBox then CHAT.CopyChatFrameEditBox:SetSize(width, height) end
end

function CHAT:CopyChatScrollFrame_OnVerticalScroll(offset)
    if CHAT.CopyChatFrameEditBox then
        local editBoxHeight = CHAT.CopyChatFrameEditBox:GetHeight()
        local scrollFrameHeight = self:GetHeight()
        CHAT.CopyChatFrameEditBox:SetHitRectInsets(0, 0, offset, editBoxHeight - offset - scrollFrameHeight)
    end
end

function CHAT:BuildCopyChatFrame()
    if self.CopyChatFrame then return end

    local HEADER_HEIGHT = 32
    local SCROLLBAR_WIDTH = 10
    local CONTENT_PADDING = 8

    local frame = CreateFrame("Frame", "NRSKNUI_CopyChatFrame", UIParent, "BackdropTemplate")
    tinsert(_G.UISpecialFrames, "NRSKNUI_CopyChatFrame")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, })
    frame:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], Theme.bgDark[4])
    frame:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    frame:SetSize(COPY_FRAME_WIDTH, COPY_FRAME_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    frame:Hide()
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetResizable(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    self.CopyChatFrame = frame

    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    header:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame.header = header

    local headerBorder = header:CreateTexture(nil, "BORDER")
    headerBorder:SetHeight(1)
    headerBorder:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    headerBorder:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    headerBorder:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFont(cachedFontPath, 14, "OUTLINE")
    title:SetPoint("LEFT", header, "LEFT", 6, 0)
    title:SetText("Chat Copy")
    title:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    frame.title = title

    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)

    local closeTex = closeBtn:CreateTexture(nil, "ARTWORK")
    closeTex:SetAllPoints()
    closeTex:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomCrossv3.png")
    closeTex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.7)
    closeTex:SetRotation(math.rad(45))
    closeTex:SetTexelSnappingBias(0)
    closeTex:SetSnapToPixelGrid(true)
    closeBtn:SetNormalTexture(closeTex)

    local closeState = { alpha = 0.7 }
    local closeAnim = closeBtn:CreateAnimationGroup()
    closeAnim:CreateAnimation("Animation"):SetDuration(0.15)
    local closeAnimFrom, closeAnimTo = 0.7, 0.7

    closeAnim:SetScript("OnUpdate", function(animGroup)
        local a = Lerp(closeAnimFrom, closeAnimTo, animGroup:GetProgress() or 0)
        closeTex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], a)
        closeState.alpha = a
    end)

    closeAnim:SetScript("OnFinished", function()
        closeTex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], closeAnimTo)
        closeState.alpha = closeAnimTo
    end)

    local function AnimateCloseAlpha(toHover)
        closeAnim:Stop()
        closeAnimFrom = closeState.alpha
        closeAnimTo = toHover and 1 or 0.7
        closeAnim:Play()
    end

    closeBtn:SetScript("OnEnter", function() AnimateCloseAlpha(true) end)
    closeBtn:SetScript("OnLeave", function() AnimateCloseAlpha(false) end)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    frame.closeButton = closeBtn

    local hint = header:CreateFontString(nil, "OVERLAY")
    hint:SetFont(cachedFontPath, 11, "OUTLINE")
    hint:SetPoint("RIGHT", closeBtn, "LEFT", -12, 0)
    hint:SetText("CTRL+A to select all, CTRL+C to copy")
    hint:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.8)
    frame.hint = hint

    local contentArea = CreateFrame("Frame", nil, frame)
    contentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_PADDING, -HEADER_HEIGHT - CONTENT_PADDING)
    contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CONTENT_PADDING, CONTENT_PADDING)
    frame.contentArea = contentArea

    local scrollbar = CreateFrame("Slider", nil, contentArea, "BackdropTemplate")
    scrollbar:SetWidth(SCROLLBAR_WIDTH)
    scrollbar:SetPoint("TOPRIGHT", contentArea, "TOPRIGHT", 0, 0)
    scrollbar:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", 0, 0)
    scrollbar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, })
    scrollbar:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 0.5)
    scrollbar:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetMinMaxValues(0, 1)
    scrollbar:SetValue(0)
    scrollbar:Hide()
    frame.scrollbar = scrollbar

    local thumb = scrollbar:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(SCROLLBAR_WIDTH - 2, 40)
    thumb:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.8)
    scrollbar:SetThumbTexture(thumb)
    scrollbar.thumb = thumb

    local scrollFrame = CreateFrame("ScrollFrame", "NRSKNUI_CopyChatScrollFrame", contentArea)
    scrollFrame:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", 0, 0)
    self.CopyChatScrollFrame = scrollFrame

    local editBox = CreateFrame("EditBox", "NRSKNUI_CopyChatFrameEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(99999)
    editBox:EnableMouse(true)
    editBox:SetAutoFocus(false)
    editBox:SetFont(cachedFontPath, 12, "OUTLINE")
    editBox:SetShadowColor(0, 0, 0, 0)
    editBox:SetShadowOffset(0, 0)
    editBox:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3], 1)
    editBox:SetScript("OnEscapePressed", self.CopyChatEditBox_OnEscapePressed)
    self.CopyChatFrameEditBox = editBox

    scrollFrame:SetScrollChild(editBox)
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetHeight(COPY_FRAME_HEIGHT)

    scrollbar:SetScript("OnValueChanged", function(_, value) scrollFrame:SetVerticalScroll(value) end)

    scrollFrame:SetScript("OnScrollRangeChanged", function(_, _, yRange)
        if yRange and yRange > 0 then
            scrollbar:Show()
            scrollbar:SetMinMaxValues(0, yRange)
            scrollFrame:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", -SCROLLBAR_WIDTH - 4, 0)
        else
            scrollbar:Hide()
            scrollbar:SetMinMaxValues(0, 0)
            scrollFrame:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", 0, 0)
        end
        editBox:SetWidth(scrollFrame:GetWidth())
    end)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(sf, delta)
        local current = scrollbar:GetValue()
        local _, maxVal = scrollbar:GetMinMaxValues()
        local step = 40
        local newVal = current - (delta * step)
        newVal = math.max(0, math.min(maxVal, newVal))
        scrollbar:SetValue(newVal)
    end)

    editBox:SetScript("OnTextChanged", function(_, userInput)
        if userInput then return end
        C_Timer.After(0.01, function()
            local _, maxVal = scrollbar:GetMinMaxValues()
            scrollbar:SetValue(maxVal)
        end)
    end)

    scrollFrame:SetScript("OnSizeChanged", function() editBox:SetWidth(scrollFrame:GetWidth()) end)

    frame:SetScript("OnShow", function()
        editBox:SetWidth(scrollFrame:GetWidth())
    end)

    frame:SetScript("OnKeyDown", function(f, key)
        if key == "ESCAPE" then
            f:SetPropagateKeyboardInput(false)
            f:Hide()
        else
            f:SetPropagateKeyboardInput(true)
        end
    end)
    frame:EnableKeyboard(true)
end

function CHAT:CreateCopyButton(chat)
    if chat.copyButton then return end
    if IsCombatLog and IsCombatLog(chat) then return end

    local db = self.db
    local id = chat:GetID()
    local copyButton = CreateFrame("Frame", format("NRSKNUI_CopyChatButton%d", id), chat)
    copyButton:EnableMouse(true)
    copyButton:SetSize(20, 22)
    copyButton:SetPoint("TOPRIGHT", chat, "TOPRIGHT", 4, 6)
    copyButton:SetFrameLevel(chat:GetFrameLevel() + 5)
    chat.copyButton = copyButton

    local text = copyButton:CreateFontString(nil, "OVERLAY")
    text:SetFont(cachedFontPath, 14, "OUTLINE")
    text:SetPoint("CENTER", copyButton, "CENTER", 0, 0)
    text:SetText("C")
    copyButton.text = text

    local color = db.TabSelectedTextColor
    if not color or not db.TabSelectedTextEnabled then
        color = cachedThemeAccentColor
    end

    text:SetTextColor(color.r, color.g, color.b, 0.5)

    copyButton:SetScript("OnMouseUp", function(btn, mouseBtn)
        if mouseBtn == "LeftButton" then
            local chatFrame = btn:GetParent()
            if chatFrame.isDocked and _G.GeneralDockManager then
                chatFrame = _G.GeneralDockManager.selected or chatFrame
            end
            CHAT:CopyChat(chatFrame)
        end
    end)
    copyButton:SetScript("OnEnter", function() text:SetTextColor(color.r, color.g, color.b, 1) end)
    copyButton:SetScript("OnLeave", function() text:SetTextColor(color.r, color.g, color.b, 0.5) end)
end

function CHAT:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end
    if not self.db.Enabled then return end
    self:UpdateDB()
    self:BuildCopyChatFrame()
    self:CreateChatPanel()
    self:SetupChat()
    self:RegisterEditMode()
    self:SetupBlizzardEditModeLock()
    self:RegisterWhisperSounds()
    self:ForceInlineWhispers()
    self:AddWhisperModeWarning()
    self:RegisterEvent("UPDATE_CHAT_WINDOWS", "SetupChat")
    self:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", "SetupChat")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RefreshDockPosition")
    self:RegisterEvent("CVAR_UPDATE", "OnCVAR_UPDATE")

    if _G.Blizzard_CombatLog_Update_QuickButtons then
        self:SecureHook("Blizzard_CombatLog_Update_QuickButtons", "StyleCombatLog")
    else
        self:RegisterEvent("ADDON_LOADED", function(_, addon)
            if addon == "Blizzard_CombatLog" then
                self:StyleCombatLog()
                if _G.Blizzard_CombatLog_Update_QuickButtons then
                    self:SecureHook("Blizzard_CombatLog_Update_QuickButtons", "StyleCombatLog")
                end
            end
        end)
    end

    if _G.EditModeManagerFrame then self:SecureHook(_G.EditModeManagerFrame, "UpdateLayoutInfo", "OnEditModeLayoutChange") end
end

function CHAT:OnEditModeLayoutChange()
    self:PositionChats()
end

function CHAT:OnCVAR_UPDATE(_, cvar, value)
    if cvar == "chatStyle" then self:UpdateEditboxAnchors() end
    if cvar == "whisperMode" and value ~= "inline" then
        C_Timer.After(0, function() C_CVar.SetCVar("whisperMode", "inline") end)
    end
end

-- Taint protection, forces whisper mode to be inline always
-- Auto opening new tabs while in secret lockdown causes taint errors
function CHAT:ForceInlineWhispers()
    if self.inlineWhispersSetup then return end
    self.inlineWhispersSetup = true

    C_CVar.SetCVar("whisperMode", "inline")
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("VARIABLES_LOADED")
    frame:SetScript("OnEvent", function() C_CVar.SetCVar("whisperMode", "inline") end)
end

-- Adds a warning label w/ tooltip that explains why i need to force inline mode
function CHAT:AddWhisperModeWarning()
    if self.whisperWarningSetup then return end
    self.whisperWarningSetup = true

    local warningFrame = CreateFrame("Frame", nil, UIParent)
    warningFrame:SetSize(200, 20)
    warningFrame:SetFrameStrata("DIALOG")
    warningFrame:Hide()
    warningFrame:EnableMouse(true)

    local text = warningFrame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    text:SetShadowColor(0, 0, 0, 0)
    text:SetText("|cffff6600NorskenUI\nNew Tab disabled|r")

    warningFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("NorskenUI: New Tab Disabled", Theme.accent[1], Theme.accent[2], Theme.accent[3])
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(
            "The 'New Tab' whisper mode causes taint errors when clicking on whisper tabs with secret player names.", 1,
            1, 1,
            true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("NorskenUI forces 'In-line' mode to prevent these errors.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)

    warningFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local function UpdateWarningPosition()
        local settingsPanel = _G.SettingsPanel
        if not settingsPanel or not settingsPanel:IsShown() then
            warningFrame:Hide()
            return
        end

        local scrollBox = settingsPanel.Container and settingsPanel.Container.SettingsList and
            settingsPanel.Container.SettingsList.ScrollBox
        if not scrollBox or not scrollBox.ScrollTarget then
            warningFrame:Hide()
            return
        end

        for _, child in pairs({ scrollBox.ScrollTarget:GetChildren() }) do
            local labelText = child.Text and child.Text:GetText()
            if labelText == "New Whispers" and child:IsShown() then
                warningFrame:SetParent(child)
                warningFrame:ClearAllPoints()
                warningFrame:SetPoint("LEFT", child.Text, "RIGHT", 300, 2)
                warningFrame:Show()
                return
            end
        end

        warningFrame:Hide()
    end

    local function SetupHooks()
        if _G.SettingsPanel then
            hooksecurefunc(_G.SettingsPanel, "Show", UpdateWarningPosition)
            hooksecurefunc(_G.SettingsPanel, "Hide", function() warningFrame:Hide() end)
        end
        if _G.SettingsPanel and _G.SettingsPanel.Container and _G.SettingsPanel.Container.SettingsList then
            hooksecurefunc(_G.SettingsPanel.Container.SettingsList.ScrollBox, "Update", UpdateWarningPosition)
        end
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(_, _, addon)
        if addon == "Blizzard_Settings" or addon == "Blizzard_SettingsDefinitions_Frame" then
            C_Timer.After(0.5, SetupHooks)
        end
    end)

    SetupHooks()
end

function CHAT:OnDisable()
    self:UnregisterEvent("UPDATE_CHAT_WINDOWS")
    self:UnregisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
    self:UnregisterEvent("CVAR_UPDATE")
    self:UnregisterEvent("CHAT_MSG_WHISPER")
    self:UnregisterEvent("CHAT_MSG_BN_WHISPER")
    self:UnhookAll()
    self:RestoreAllChats()
    self:UnregisterEditMode()
    self.hooksSecured = false
    if self.panel then self.panel:Hide() end
end

function CHAT:RegisterEditMode()
    if not NRSKNUI.EditMode then return end

    NRSKNUI.EditMode:RegisterElement({
        key = "Chatv2",
        displayName = "CHAT PANEL",
        frame = self.panel,
        getPosition = function()
            return self.db.Position
        end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom = pos.AnchorFrom
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.XOffset = pos.XOffset
            self.db.Position.YOffset = pos.YOffset

            self.panel:ClearAllPoints()
            self.panel:SetPoint(
                pos.AnchorFrom,
                _G[self.db.ParentFrame] or UIParent,
                pos.AnchorTo,
                pos.XOffset,
                pos.YOffset
            )
        end,
        getParentFrame = function()
            return _G[self.db.ParentFrame] or UIParent
        end,
        guiPath = "Chatv2",
    })
end

function CHAT:UnregisterEditMode()
    if not NRSKNUI.EditMode then return end
    NRSKNUI.EditMode:UnregisterElement("Chatv2")
end

function CHAT:CreateChatPanel()
    if self.panel then
        self.panel:Show()
        if self.panel.backdrop then self.panel.backdrop:Show() end
        self:UpdatePanel()
        return
    end

    local db = self.db
    local panel = CreateFrame("Frame", "NRSKNUI_ChatPanel", UIParent)
    panel:SetFrameStrata("BACKGROUND")
    panel:SetFrameLevel(PANEL_FRAME_LEVEL)
    panel:SetClampedToScreen(true)
    panel:SetSize(db.Width or PANEL_WIDTH, db.Height or PANEL_HEIGHT)
    panel:SetPoint(
        db.Position.AnchorFrom,
        _G[db.ParentFrame] or UIParent,
        db.Position.AnchorTo,
        db.Position.XOffset,
        db.Position.YOffset
    )
    self.panel = panel

    local backdrop = CreateFrame("Frame", "NRSKNUI_ChatPanelBackdrop", panel, "BackdropTemplate")
    backdrop:SetFrameLevel(panel:GetFrameLevel() - 1)
    backdrop:SetAllPoints(panel)
    panel.backdrop = backdrop
    self:ApplyBackdrop(backdrop)

    local tabBackdrop = CreateFrame("Frame", "NRSKNUI_ChatTabBackdrop", panel, "BackdropTemplate")
    tabBackdrop:SetFrameLevel(panel:GetFrameLevel() + 1)
    self.tabBackdrop = tabBackdrop
    self:UpdateTabBackdrop()
end

function CHAT:UpdateTabBackdrop()
    if not self.tabBackdrop then return end

    local db = self.db
    local tabBackdrop = self.tabBackdrop

    tabBackdrop:ClearAllPoints()
    tabBackdrop:SetPoint("TOPLEFT", self.panel, "TOPLEFT", 0, 0)
    tabBackdrop:SetPoint("BOTTOMRIGHT", self.panel, "TOPRIGHT", 0, -TAB_HEIGHT)

    local tabBgColor = db.TabBackdrop and db.TabBackdrop.Color or { 0, 0, 0, 0.5 }
    local tabBorderColor = db.TabBackdrop and db.TabBackdrop.BorderColor or { 0, 0, 0, 1 }
    local tabBackdropEnabled = db.TabBackdrop and db.TabBackdrop.Enabled

    tabBackdrop:SetBackdrop(BACKDROP_TEMPLATE)

    if tabBackdropEnabled then
        tabBackdrop:SetBackdropColor(tabBgColor[1], tabBgColor[2], tabBgColor[3], tabBgColor[4] or 0.5)
        tabBackdrop:SetBackdropBorderColor(tabBorderColor[1], tabBorderColor[2], tabBorderColor[3],
            tabBorderColor[4] or 1)
        tabBackdrop:Show()
    else
        tabBackdrop:Hide()
    end
end

function CHAT:ApplyBackdrop(backdrop)
    local db = self.db

    backdrop:SetBackdrop(BACKDROP_TEMPLATE)

    if db.Backdrop.Enabled ~= false then
        backdrop:SetBackdropColor(db.Backdrop.Color[1], db.Backdrop.Color[2], db.Backdrop.Color[3],
            db.Backdrop.Color[4] or 0.6)
        backdrop:SetBackdropBorderColor(db.Backdrop.BorderColor[1], db.Backdrop.BorderColor[2],
            db.Backdrop.BorderColor[3], db.Backdrop.BorderColor[4] or 1)
        backdrop:Show()
    else
        backdrop:SetBackdropColor(0, 0, 0, 0)
        backdrop:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

function CHAT:GetTab(chat)
    if not chat then return end
    if not chat.tab then chat.tab = _G["ChatFrame" .. chat:GetID() .. "Tab"] end
    return chat.tab
end

function CHAT:GetCombatLog()
    local LOG = _G.COMBATLOG
    if LOG then return LOG, self:GetTab(LOG) end
end

function CHAT:ShouldIgnoreFrame(chat)
    if not chat then return true end
    local id = chat:GetID()
    return IGNORE_FRAMES[id] ~= nil
end

function CHAT:IsChatValid(chat)
    if not chat then return false end
    if self:ShouldIgnoreFrame(chat) then return false end
    if IsCombatLog and IsCombatLog(chat) then return false end
    return true
end

function CHAT:SetupChat()
    if not self.panel then return end

    for _, frameName in ipairs(_G.CHAT_FRAMES) do
        local chat = _G[frameName]
        if chat then
            self:StyleChat(chat)
            if _G.FCFTab_UpdateAlpha then _G.FCFTab_UpdateAlpha(chat) end
        end
    end

    self:PositionChats()
    self:SetupDockManager()
    self:UpdateChatTabs()
    self:UpdateEditboxAnchors()
    self:StyleCombatLog()

    if _G.TextToSpeechButtonFrame then _G.TextToSpeechButtonFrame:Hide() end
    if _G.TextToSpeechButton then _G.TextToSpeechButton:Hide() end
    if _G.QuickJoinToastButton then _G.QuickJoinToastButton:Hide() end
    if _G.ChatFrameMenuButton then _G.ChatFrameMenuButton:Hide() end
    if _G.ChatFrameChannelButton then _G.ChatFrameChannelButton:Hide() end
    if _G.ChatFrameToggleVoiceDeafenButton then _G.ChatFrameToggleVoiceDeafenButton:Hide() end
    if _G.ChatFrameToggleVoiceMuteButton then _G.ChatFrameToggleVoiceMuteButton:Hide() end

    if not self.hooksSecured then
        self:SecureHook("FCF_OpenTemporaryWindow", "SetupChat")
        self:SecureHook("FCF_SavePositionAndDimensions", "OnDockStateChanged")
        self:SecureHook("FCF_DockFrame", "OnDockStateChanged")
        self:SecureHook("FCF_UnDockFrame", "OnDockStateChanged")
        self:SecureHook("FCF_ResetChatWindows", "OnFCF_ResetChatWindows")
        self:SecureHook("FCF_SetButtonSide", "OnFCF_SetButtonSide")
        self:SecureHook("FCF_Close", "OnFCF_Close")
        self:SecureHook("FCF_SetWindowAlpha", "OnFCF_SetWindowAlpha")
        self:SecureHook("FCF_SetChatWindowFontSize", "OnFCF_SetChatWindowFontSize")
        self:SecureHook("FCFTab_UpdateColors", "OnFCFTab_UpdateColors")
        self:SecureHook("FCFDock_SelectWindow", "OnFCFDock_SelectWindow")
        self:SecureHook("FCFDock_ScrollToSelectedTab", "OnFCFDock_ScrollToSelectedTab")
        self:SecureHook("RedockChatWindows", "OnRedockChatWindows")

        if _G.ChatFrameUtil then
            self:SecureHook(_G.ChatFrameUtil, "ActivateChat", "OnChatEdit_ActivateChat")
            self:SecureHook(_G.ChatFrameUtil, "DeactivateChat", "OnChatEdit_DeactivateChat")
            self:SecureHook(_G.ChatFrameUtil, "SetLastActiveWindow", "OnChatEdit_SetLastActiveWindow")
        else
            self:SecureHook("ChatEdit_ActivateChat", "OnChatEdit_ActivateChat")
            self:SecureHook("ChatEdit_DeactivateChat", "OnChatEdit_DeactivateChat")
            self:SecureHook("ChatEdit_SetLastActiveWindow", "OnChatEdit_SetLastActiveWindow")
        end

        ---@diagnostic disable: undefined-field
        if _G.FCFDockOverflowButton_UpdatePulseState then
            self:SecureHook("FCFDockOverflowButton_UpdatePulseState",
                "OnFCFDockOverflowButton_UpdatePulseState")
        end
        if _G.UIDropDownMenu_AddButton then self:SecureHook("UIDropDownMenu_AddButton", "OnUIDropDownMenu_AddButton") end
        if _G.GetPlayerInfoByGUID then self:SecureHook("GetPlayerInfoByGUID", "OnGetPlayerInfoByGUID") end
        if _G.ChatEdit_OnEnterPressed then self:SecureHook("ChatEdit_OnEnterPressed", "OnChatEdit_OnEnterPressed") end
        if _G.ChatEdit_UpdateHeader then self:SecureHook("ChatEdit_UpdateHeader", "OnChatEdit_UpdateHeader") end
        ---@diagnostic enable: undefined-field

        self.hooksSecured = true
    end
end

function CHAT:SetBackgroundVisible(background, show)
    if not background then return end

    if show then
        background.Show = nil
        background:Show()
    else
        background:Hide()
        background.Show = background.Hide
    end
end

function CHAT:GetAnchorParent(anchor, chat)
    if not anchor then return end

    local _, relativeTo = chat:GetPoint()
    if relativeTo == anchor then return anchor:GetParent() end
end

function CHAT:IsFloating(chat, docker)
    if not docker then docker = _G.GeneralDockManager.primary end

    local primaryUndocked = docker ~= self.ChatWindow
    return not chat.isDocked or (primaryUndocked and ((chat == docker) or self:GetAnchorParent(docker, chat)))
end

function CHAT:ClearSnapReference(chat)
    if chat == self.ChatWindow then
        self.ChatWindow = nil
        if self.db then self.db.panelSnapID = nil end
    end
end

function CHAT:ResetPanelSnap()
    self.ChatWindow = nil
    if self.db then self.db.panelSnapID = nil end
end

function CHAT:OnDockStateChanged(chat)
    if self.isPositioning then return end

    self:ClearSnapReference(chat)

    if chat == _G.GeneralDockManager.primary then
        for _, frame in ipairs(_G.GeneralDockManager.DOCKED_CHAT_FRAMES) do self:PositionChat(frame) end
    else
        self:PositionChat(chat)
    end
end

function CHAT:RefreshDockPosition(event, isInitialLogin, isReloadingUi)
    if event == "PLAYER_ENTERING_WORLD" and (isInitialLogin or isReloadingUi) then return end
    local docker = _G.GeneralDockManager and _G.GeneralDockManager.primary
    if docker then self:OnDockStateChanged(docker) end
end

function CHAT:GetPanelAnchoredChat()
    if self.ChatWindow then return self.ChatWindow end

    local docker = _G.GeneralDockManager and _G.GeneralDockManager.primary
    if not docker or not self.db then return end

    local savedSnapID = self.db.panelSnapID

    for index, frameName in ipairs(_G.CHAT_FRAMES) do
        local chat = _G[frameName]
        if chat and ((chat.isDocked and chat == docker) or (not chat.isDocked and chat:IsShown())) then
            -- If we have a saved ID, use that
            if savedSnapID and savedSnapID == index then
                self.ChatWindow = chat
                return chat
                -- Otherwise check overlap OR default to primary docker on initial setup
            elseif not savedSnapID then
                if self:FrameOverlapsPanel(chat) then
                    self.db.panelSnapID = index
                    self.ChatWindow = chat
                    return chat
                elseif chat == docker then
                    -- Initial setup, snap the primary docker
                    self.db.panelSnapID = index
                    self.ChatWindow = chat
                    return chat
                end
            end
        end
    end
end

function CHAT:FrameOverlapsPanel(frame)
    if not frame or not self.panel then return false end

    local frameLeft, frameBottom, frameWidth, frameHeight = frame:GetRect()
    local panelLeft, panelBottom, panelWidth, panelHeight = self.panel:GetRect()

    if not frameLeft or not panelLeft then return false end

    local frameRight = frameLeft + frameWidth
    local frameTop = frameBottom + frameHeight
    local panelRight = panelLeft + panelWidth
    local panelTop = panelBottom + panelHeight

    return frameLeft < panelRight and frameRight > panelLeft and frameBottom < panelTop and frameTop > panelBottom
end

function CHAT:OnFCF_ResetChatWindows()
    self:ResetPanelSnap()
    self:SetupChat()
end

function CHAT:OnFCF_SetButtonSide(chat)
    if chat and self:IsChatValid(chat) then self:PositionButtonFrame(chat) end
end

function CHAT:PostChatClose(chat)
    local tab = CHAT:GetTab(chat)
    if tab then
        tab.whisperName = nil
        tab.classColor = nil
    end
end

function CHAT:OnFCF_Close(chat)
    if not chat then return end
    local id = chat:GetID()
    self.originalStates[id] = nil
    chat.styled = nil
    chat.scriptsSet = nil
    self:PostChatClose(chat)
end

function CHAT:OnFCF_SetWindowAlpha(frame, alpha)
    if not frame then return end
    frame.oldAlpha = alpha or 1
end

function CHAT:OnFCF_SetChatWindowFontSize(_, chatFrame, fontSize)
    if not chatFrame then chatFrame = _G.FCF_GetCurrentChatFrame and _G.FCF_GetCurrentChatFrame() end
    if not chatFrame or not self:IsChatValid(chatFrame) then return end
    if not fontSize then return end

    self:UpdateEditboxFont(chatFrame)
end

function CHAT:OnFCFTab_UpdateColors(tab, selected)
    if not tab then return end

    if tab:GetParent() == _G.ChatConfigFrameChatTabManager then
        if selected then tab.Text:SetTextColor(1, 1, 1) end

        local name = GetChatWindowInfo(tab:GetID())
        if name and NRSKNUI:NotSecretValue(name) then tab.Text:SetText(name) end

        tab:SetAlpha(1)
    else
        local chat = self:GetOwner(tab)
        if not chat then return end

        local db = self.db
        tab.selected = selected

        local name = chat.name or UNKNOWN
        local chatTarget = chat.chatTarget
        local whisper = tab.conversationIcon and chatTarget

        if whisper and not tab.whisperName and NRSKNUI:NotSecretValue(name) then
            local strippedName = self:StripMyRealm(name)
            tab.whisperName = gsub(strippedName, "([%S]-)%-[%S]+", "%1|cFF999999*|r")
        end

        local nameText = tab.whisperName or name
        local nameTextNotSecret = NRSKNUI:NotSecretValue(nameText)

        if selected then
            if nameTextNotSecret then
                local tabSelector = db.TabSelector or "ARROW1"

                if tabSelector == "NONE" then
                    tab:SetFormattedText(TAB_STYLES.NONE, nameText)
                else
                    local selectorColor = db.TabSelectorColor
                    local hexColor = selectorColor and self:RGBToHex(selectorColor.r, selectorColor.g, selectorColor.b) or
                        "|cff4cff4c"
                    tab:SetFormattedText(TAB_STYLES[tabSelector] or TAB_STYLES.ARROW1, hexColor, nameText, hexColor)
                end
            end

            if db.TabSelectedTextEnabled then
                local selectedTextColor = db.TabSelectedTextColor
                if selectedTextColor then
                    tab.Text:SetTextColor(selectedTextColor.r, selectedTextColor.g, selectedTextColor.b)
                else
                    tab.Text:SetTextColor(1, 1, 1)
                end
                return
            end
        end

        if whisper then
            if nameTextNotSecret and not selected then tab:SetText(nameText) end

            local nameLower = not tab.classColor and NRSKNUI:NotSecretValue(name) and strlower(name)
            local classMatch = nameLower and self.ClassNames[nameLower]
            if classMatch then tab.classColor = self:GetClassColor(classMatch) end

            if tab.classColor then
                tab.Text:SetTextColor(tab.classColor.r, tab.classColor.g, tab.classColor.b)
            else
                local whisperInfo = _G.ChatTypeInfo and _G.ChatTypeInfo["WHISPER"]
                if whisperInfo then tab.Text:SetTextColor(whisperInfo.r, whisperInfo.g, whisperInfo.b) end
            end
        else
            if nameTextNotSecret and not selected then tab:SetText(name) end

            local colorMode = db.TabTextColorMode or "custom"
            local customColor = db.TabTextColor or cachedTabAccentColor
            local r, g, b = NRSKNUI:GetAccentColor(colorMode, { customColor.r, customColor.g, customColor.b, 1 })
            tab.Text:SetTextColor(r, g, b)
        end
    end
end

function CHAT:GetOwner(tab)
    if not tab then return end
    if not tab.owner then tab.owner = _G[format("ChatFrame%s", tab:GetID())] end
    return tab.owner
end

function CHAT:OnFCFDock_SelectWindow(_, chatFrame)
    if chatFrame and self:IsChatValid(chatFrame) then self:UpdateEditboxFont(chatFrame) end
end

function CHAT:OnFCFDock_ScrollToSelectedTab(dock)
    if dock ~= _G.GeneralDockManager then return end
    if not self.panel then return end

    local scrollFrame = dock.scrollFrame
    if scrollFrame then
        local logChat, logChatTab = self:GetCombatLog()

        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("RIGHT", dock.overflowButton, "LEFT")

        ---@diagnostic disable-next-line: undefined-field
        local anchorTab = (logChat and logChat.isDocked and logChatTab) or self:GetTab(dock.primary)
        if anchorTab then scrollFrame:SetPoint("TOPLEFT", anchorTab, "TOPRIGHT", 0, 1) end
    end
end

function CHAT:OnRedockChatWindows()
    self:ResetPanelSnap()
    self:SetupChat()
end

function CHAT:OnChatEdit_ActivateChat(editbox)
    if not editbox then return end
    local chatFrame = editbox.chatFrame or editbox:GetParent()
    if chatFrame and self:IsChatValid(chatFrame) then self:UpdateEditboxFont(chatFrame) end
end

function CHAT:OnChatEdit_DeactivateChat(editbox)
    if not editbox then return end
    local style = editbox.chatStyle or GetCVar("chatStyle")
    if style == "im" then editbox:Hide() end
end

function CHAT:OnChatEdit_SetLastActiveWindow(editbox)
    if not editbox then return end
    local style = editbox.chatStyle or GetCVar("chatStyle")
    if style == "im" then editbox:SetAlpha(0.5) end
end

function CHAT:UpdateEditboxFont(chatFrame)
    if not chatFrame then return end

    local style = GetCVar("chatStyle")
    if style == "classic" and self.ChatWindow then chatFrame = self.ChatWindow end

    local docker = _G.GeneralDockManager
    ---@diagnostic disable-next-line: undefined-field
    if docker and chatFrame == docker.primary then
        ---@diagnostic disable-next-line: undefined-field
        chatFrame = docker.selected or chatFrame
    end

    local editbox = chatFrame.editBox
    if not editbox then return end

    local id = chatFrame:GetID()
    local _, fontSize = GetChatWindowInfo(id)
    if fontSize then
        -- Blizzard: fontSize is 0 while the window is still at the default size (14)
        if fontSize == 0 then fontSize = 14 end
        local fontName, _, fontFlags = editbox:GetFont()
        if fontName then editbox:SetFont(fontName, fontSize, fontFlags) end
    end
end

function CHAT:OnFCFDockOverflowButton_UpdatePulseState(btn)
    if not btn or not btn.Texture then return end

    local db = self.db
    if btn.alerting then
        btn:SetAlpha(1)
        if db.TabSelectedTextEnabled and db.TabSelectedTextColor then
            local c = db.TabSelectedTextColor
            btn.Texture:SetVertexColor(c.r, c.g, c.b)
        else
            btn.Texture:SetVertexColor(1, 1, 1)
        end
    elseif not btn:IsMouseOver() then
        local colorMode = db.TabTextColorMode or "custom"
        local customColor = db.TabTextColor or cachedTabAccentColor
        local r, g, b = NRSKNUI:GetAccentColor(colorMode, { customColor.r, customColor.g, customColor.b, 1 })
        btn.Texture:SetVertexColor(r, g, b)
    end
end

local CLOSE_BUTTONS = {}
do
    CLOSE_BUTTONS[_G.CLOSE_CHAT_CONVERSATION_WINDOW or "Close Conversation Window"] = true
    CLOSE_BUTTONS[_G.CLOSE_CHAT_WHISPER_WINDOW or "Close Whisper Window"] = true
    CLOSE_BUTTONS[_G.CLOSE_CHAT_WINDOW or "Close Window"] = true
end

function CHAT:OnUIDropDownMenu_AddButton(info, level)
    if not info or not CLOSE_BUTTONS[info.text] then return end
    if not level then level = 1 end

    local list = _G["DropDownList" .. level]
    if not list then return end

    local index = list.numButtons or 1
    local button = _G[list:GetName() .. "Button" .. index]
    if not button then return end

    if button.func == _G.FCF_PopInWindow then
        button.func = CHAT.FCF_PopInWindow
    elseif button.func == _G.FCF_Close then
        button.func = CHAT.FCF_Close
    end
end

CHAT.GuidCache = {}
CHAT.GuidCacheCount = 0
local GUID_CACHE_MAX = 500

function CHAT:StripMyRealm(name)
    if not name then return name end
    if NRSKNUI:IsSecretValue(name) then return name end
    local myRealm = GetRealmName and GetRealmName()
    if myRealm then
        myRealm = gsub(myRealm, " ", "")
        name = gsub(name, "%-" .. myRealm, "")
    end
    return name
end

function CHAT:RGBToHex(r, g, b)
    r = r <= 1 and r >= 0 and r or 1
    g = g <= 1 and g >= 0 and g or 1
    b = b <= 1 and b >= 0 and b or 1
    return format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

function CHAT:ShortChannel()
    local key = gsub(strupper(self), " ", "_")
    return format("|Hchannel:%s|h[%s]|h", self, SHORT_CHANNELS[key] or gsub(self, "channel:", ""))
end

function CHAT:HandleShortChannels(msg, hide)
    msg = gsub(msg, "|Hchannel:(.-)|h%[(.-)%]|h", hide and "" or CHAT.ShortChannel)
    msg = gsub(msg, "CHANNEL:", "")
    msg = gsub(msg, "^(.-|h) whispers", "%1")
    msg = gsub(msg, "^(.-|h) says", "%1")
    msg = gsub(msg, "^(.-|h) yells", "%1")
    msg = gsub(msg, "<" .. AFK .. ">", "[|cffFF9900AFK|r] ")
    msg = gsub(msg, "<" .. DND .. ">", "[|cffFF3333DND|r] ")

    if SHORT_CHANNEL_PATTERNS then
        for _, info in ipairs(SHORT_CHANNEL_PATTERNS) do msg = gsub(msg, info.pattern, info.replacement) end
    end

    return msg
end

function CHAT:GetDateTime(useLocal)
    return useLocal and time() or GetServerTime()
end

function CHAT:AddMessageEdits(frame, msg, isHistory, historyTime)
    if not msg then return msg end

    local isProtected = self:MessageIsProtected(msg)
    if isProtected then return msg end

    if strmatch(msg, '^%s*$') or strmatch(msg, '^|Hnrsktime|h') then return msg end

    local db = self.db
    local historyTimestamp
    if isHistory == "NorskenUI_ChatHistory" then historyTimestamp = historyTime end
    if db.ShortChannels then msg = self:HandleShortChannels(msg, false) end
    if db.TimestampFormat and db.TimestampFormat ~= "NONE" then
        local timestamp = BetterDate(db.TimestampFormat, historyTimestamp or self:GetDateTime(db.UseLocalTime))
        timestamp = gsub(timestamp, " ", "")
        timestamp = gsub(timestamp, "AM", " AM")
        timestamp = gsub(timestamp, "PM", " PM")
        if db.TimestampColorEnabled and db.TimestampColor then
            local c = db.TimestampColor
            local colorCode = format("|cff%02x%02x%02x", (c.r or 0.6) * 255, (c.g or 0.6) * 255, (c.b or 0.6) * 255)
            msg = format("|Hnrsktime|h%s%s|r|h %s", colorCode, timestamp, msg)
        else
            msg = format("|Hnrsktime|h%s|h %s", timestamp, msg)
        end
    end

    return msg
end

function CHAT:AddMessage(msg, infoR, infoG, infoB, infoID, accessID, typeID, event, eventArgs, msgFormatter, isHistory,
                         historyTime)
    local body = CHAT:AddMessageEdits(self, msg, isHistory, historyTime)
    self.OldAddMessage(self, body, infoR, infoG, infoB, infoID, accessID, typeID, event, eventArgs, msgFormatter)
end

function CHAT:GetClassColor(class)
    if not class then return nil end
    return RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
end

function CHAT:OnGetPlayerInfoByGUID(guid)
    if NRSKNUI:IsSecretValue(guid) then return end

    local data = self.GuidCache[guid]
    if data then
        if data.classColor then data.classColor = self:GetClassColor(data.englishClass) end
        return data
    end

    local ok, localizedClass, englishClass, localizedRace, englishRace, sex, name, realm = pcall(GetPlayerInfoByGUID,
        guid)
    if not ok or not englishClass then return end

    local hasRealm = realm and realm ~= ''
    local nameWithRealm = hasRealm and (name .. "-" .. realm) or nil

    data = {
        localizedClass = localizedClass,
        englishClass = englishClass,
        localizedRace = localizedRace,
        englishRace = englishRace,
        sex = sex,
        name = name,
        realm = hasRealm and realm or nil,
        nameWithRealm = nameWithRealm,
    }

    if name and not NRSKNUI:IsSecretValue(name) then
        self.ClassNames[strlower(name)] = englishClass
    end
    if nameWithRealm and not NRSKNUI:IsSecretValue(nameWithRealm) then
        self.ClassNames[strlower(nameWithRealm)] = englishClass
    end

    if self.GuidCacheCount >= GUID_CACHE_MAX then
        wipe(self.GuidCache)
        wipe(self.ClassNames)
        self.GuidCacheCount = 0
    end

    self.GuidCache[guid] = data
    self.GuidCacheCount = self.GuidCacheCount + 1

    data.classColor = self:GetClassColor(englishClass)

    return data
end

function CHAT:OnChatEdit_OnEnterPressed(editBox)
    if not editBox then return end

    local chatType = editBox:GetAttribute("chatType")
    if not chatType then return end

    local chatFrame = editBox:GetParent()
    if not chatFrame or chatFrame.isTemporary then return end

    local info = _G.ChatTypeInfo and _G.ChatTypeInfo[chatType]
    if info and info.sticky == 1 then editBox:SetAttribute("chatType", "SAY") end
end

function CHAT:OnChatEdit_UpdateHeader(editbox)
    if not editbox then return end

    local chatType = editbox:GetAttribute("chatType")
    if not chatType then return end

    local ChatTypeInfo = _G.ChatTypeInfo
    local info = ChatTypeInfo and ChatTypeInfo[chatType]
    local chanTarget = editbox:GetAttribute("channelTarget")
    local chanIndex = chanTarget and GetChannelName(chanTarget)

    local insetLeft, insetRight, insetTop, insetBottom = editbox:GetTextInsets()
    editbox:SetTextInsets(insetLeft, insetRight + 30, insetTop, insetBottom)
    self:ApplyFrameStyle(editbox, nil, true)

    if chanIndex and chatType == "CHANNEL" then
        if chanIndex == 0 then
            editbox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        else
            info = ChatTypeInfo[chatType .. chanIndex]
            if info then editbox:SetBackdropBorderColor(info.r, info.g, info.b, 1) end
        end
    elseif info and info.r and info.g and info.b then
        editbox:SetBackdropBorderColor(info.r, info.g, info.b, 1)
    end
end

function CHAT.ChatFrameTab_SetAlpha(tab, alpha, skip)
    if skip then return end

    local chat = CHAT:GetOwner(tab)
    local selected = _G.GeneralDockManager.selected

    if chat then
        tab:SetAlpha((not chat.isDocked or chat == selected) and 1 or 0.6, true)
    else
        tab:SetAlpha(1, true)
    end
end

function CHAT:UpdateChatTabs()
    for _, frameName in ipairs(_G.CHAT_FRAMES) do
        local chat = _G[frameName]
        if chat then self:UpdateChatTab(chat) end
    end
end

function CHAT:UpdateChatTab(chat)
    if chat.lastGM then return end

    local tab = self:GetTab(chat)
    if not tab then return end

    local isSnapped = chat == self.ChatWindow
    local parent = isSnapped and self.panel or UIParent

    if not chat.isDocked then tab:SetParent(parent) end
    chat:SetParent(parent)

    if chat.EditModeResizeButton then
        chat.EditModeResizeButton:SetFrameStrata("HIGH")
        chat.EditModeResizeButton:SetFrameLevel(6)
    end
end

function CHAT:UpdateChatTabColors()
    for _, frameName in ipairs(_G.CHAT_FRAMES) do
        local chat = _G[frameName]
        local tab = chat and self:GetTab(chat)
        if tab then self:OnFCFTab_UpdateColors(tab, tab.selected) end
    end
end

function CHAT:FCF_Tab_OnClick(button)
    local chat = self and CHAT:GetOwner(self)
    if not chat then return end

    if button == "RightButton" then
        chat:StopMovingOrSizing()

        _G.CURRENT_CHAT_FRAME_ID = self:GetID()
        _G.FCF_Tab_SetupMenu(self)
    elseif button == "MiddleButton" then
        if not IsBuiltinChatWindow(chat) then
            if not chat.isTemporary then
                CHAT.FCF_PopInWindow(self, chat)
                return
            elseif chat.chatType == "WHISPER" or chat.chatType == "BN_WHISPER" then
                CHAT.FCF_PopInWindow(self, chat)
                return
            elseif chat.chatType == "PET_BATTLE_COMBAT_LOG" then
                CHAT.FCF_Close(chat)
            end
        end
    else
        _G.CloseDropDownMenus()
        _G.SELECTED_CHAT_FRAME = chat

        if chat.isDocked and _G.FCFDock_GetSelectedWindow(_G.GeneralDockManager) ~= chat then
            _G.FCF_SelectDockFrame(chat)
        end

        if GetCVar("chatStyle") ~= "classic" then
            local chatFrame = (chat.isDocked and _G.GeneralDockManager.primary) or chat
            if chatFrame then
                ChatEditSetLastActiveWindow(chatFrame.editBox)
            end
        end

        chat:ResetAllFadeTimes()

        _G.FCF_FadeInChatFrame(chat)
    end
end

function CHAT:Tab_OnClick(button)
    CHAT.FCF_Tab_OnClick(self, button)
    PlaySound(SOUND_U_CHAT_SCROLL_BUTTON)
end

function CHAT:FCF_Close(fallback)
    if fallback then self = fallback end
    if not self or self == CHAT then self = _G.FCF_GetCurrentChatFrame() end
    if self == _G.DEFAULT_CHAT_FRAME then return end

    _G.FCF_UnDockFrame(self)
    self:Hide()
    CHAT:GetTab(self):Hide()

    _G.FCF_FlagMinimizedPositionReset(self)

    if self.minFrame and self.minFrame:IsShown() then
        self.minFrame:Hide()
    end

    if self.isTemporary then
        _G.FCFManager_UnregisterDedicatedFrame(self, self.chatType, self.chatTarget)
        self.isRegistered = false
        self.inUse = false
    end

    if self.RemoveAllMessageGroups then
        self:RemoveAllMessageGroups()
        self:RemoveAllChannels()
        self:ReceiveAllPrivateMessages()
    else
        _G.ChatFrame_RemoveAllMessageGroups(self)
        _G.ChatFrame_RemoveAllChannels(self)
        _G.ChatFrame_ReceiveAllPrivateMessages(self)
    end

    CHAT:PostChatClose(self)
end

function CHAT:FCF_PopInWindow(fallback)
    if fallback then self = fallback end
    if not self or self == CHAT then self = _G.FCF_GetCurrentChatFrame() end
    if self == _G.DEFAULT_CHAT_FRAME then return end

    _G.FCF_RestoreChatsToFrame(_G.DEFAULT_CHAT_FRAME, self)
    CHAT.FCF_Close(self)
end

function CHAT:StripTabTextures(tab)
    if not tab then return end

    local tabName = tab:GetName()
    local glowName = tabName and (tabName .. "Glow")

    for _, region in pairs({ tab:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local regionName = region:GetName()
            local isGlow = regionName and (regionName == glowName or regionName:find("Glow"))
            if not isGlow then
                region:SetTexture()
                if region.SetAtlas then region:SetAtlas("") end
            end
        end
    end

    local textureKeys = {
        "leftTexture", "middleTexture", "rightTexture",
        "Left", "Middle", "Right",
        "ActiveLeft", "ActiveMiddle", "ActiveRight",
        "HighlightLeft", "HighlightMiddle", "HighlightRight",
        "SelectedLeft", "SelectedMiddle", "SelectedRight",
    }

    for _, key in ipairs(textureKeys) do
        local tex = tab[key]
        if tex and tex.SetTexture then tex:SetTexture() end
    end
end

function CHAT:StyleTab(tab, chat)
    if not tab or tab.styled then return end

    local name = chat:GetName()

    self:StripTabTextures(tab)

    for _, texName in pairs(TAB_TEXTURES) do
        local texKey = name .. "Tab"
        local leftKey = texName .. "Left"
        local middleKey = texName .. "Middle"
        local rightKey = texName .. "Right"

        local main = _G[texKey]
        local left = _G[texKey .. leftKey] or (main and main[leftKey])
        local middle = _G[texKey .. middleKey] or (main and main[middleKey])
        local right = _G[texKey .. rightKey] or (main and main[rightKey])

        if left then left:SetTexture() end
        if middle then middle:SetTexture() end
        if right then right:SetTexture() end
    end

    if tab.Text then
        tab.Text:ClearAllPoints()
        tab.Text:SetPoint("CENTER", tab, "CENTER", 0, 0)
        tab.Text:Show()
    end

    if tab.conversationIcon then tab.conversationIcon:Show() end

    if not tab.SetAlphaHooked then
        hooksecurefunc(tab, "SetAlpha", CHAT.ChatFrameTab_SetAlpha)
        tab.SetAlphaHooked = true
    end

    tab:SetHeight(22)

    if tab.conversationIcon then
        tab.conversationIcon:ClearAllPoints()
        tab.conversationIcon:SetPoint("RIGHT", tab.Text, "LEFT", -1, 0)
    end

    tab.styled = true
end

local function SafeSetupTextureCoordinates(frame)
    local width, height = frame:GetSize()
    if width and height and width > 0 and height > 0 then _G.BackdropTemplateMixin.SetupTextureCoordinates(frame) end
end

local function ReplaceSetupTextureCoordinates(frame)
    if frame.SetupTextureCoordinates and frame.SetupTextureCoordinates ~= SafeSetupTextureCoordinates then
        frame.SetupTextureCoordinates = SafeSetupTextureCoordinates
    end
end

local BLANK_TEX = "Interface\\Buttons\\WHITE8x8"

local function GetTemplateColors(template)
    local backdropR, backdropG, backdropB, backdropA = 0.1, 0.1, 0.1, 0.9
    local borderR, borderG, borderB, borderA = 0, 0, 0, 1

    if template == "Transparent" then backdropA = 0.8 end

    return backdropR, backdropG, backdropB, backdropA, borderR, borderG, borderB, borderA
end

function CHAT:ApplyFrameStyle(frame, template, glossTex, ignoreUpdates, forcePixelMode)
    if not frame then return end

    frame.template = template or "Default"
    frame.glossTex = glossTex
    frame.ignoreUpdates = ignoreUpdates
    frame.forcePixelMode = forcePixelMode

    if not frame.SetBackdrop then
        Mixin(frame, _G.BackdropTemplateMixin)
        if frame.OnSizeChanged then frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged) end
    end

    ReplaceSetupTextureCoordinates(frame)
    frame:SetPixelSnap()

    if template == "NoBackdrop" then
        frame:SetBackdrop(nil)
        return
    end

    local db = self.db
    local edgeSize = 1

    frame:SetBackdrop({
        bgFile = glossTex and (type(glossTex) == "string" and glossTex or BLANK_TEX) or BLANK_TEX,
        edgeFile = BLANK_TEX,
        edgeSize = edgeSize,
    })

    local backdropR, backdropG, backdropB, backdropA, borderR, borderG, borderB, borderA = GetTemplateColors(template)

    if db.EditBox then
        local bgColor = db.EditBox.BackdropColor
        local borderColor = db.EditBox.BorderColor
        if bgColor then
            backdropR, backdropG, backdropB, backdropA = bgColor[1], bgColor[2], bgColor[3], bgColor[4] or backdropA
        end
        if borderColor then
            borderR, borderG, borderB, borderA = borderColor[1], borderColor[2], borderColor[3],
                borderColor[4] or borderA
        end
    end

    if frame.callbackBackdropColor then
        frame:callbackBackdropColor()
    else
        frame:SetBackdropColor(backdropR, backdropG, backdropB, frame.customBackdropAlpha or backdropA)
    end

    if frame.forcedBorderColors then borderR, borderG, borderB, borderA = unpack(frame.forcedBorderColors) end

    frame:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
end

function CHAT:EditBoxFocusGained(editbox)
    if not self.panel:IsShown() then
        self.panel.editboxforced = true
        self.panel:Show()
        if self.panel.backdrop then self.panel.backdrop:Show() end
        editbox:Show()
    end
end

function CHAT:EditBoxFocusLost(editbox)
    if self.panel.editboxforced then
        self.panel.editboxforced = nil
        if self.panel:IsShown() then
            editbox:Hide()
        end
    end
end

function CHAT:EditBoxOnTextChanged(editbox)
    if not editbox or not editbox.characterCount then return end

    local text = editbox:GetText()
    local len = text and #text or 0

    if len > 0 then
        editbox.characterCount:SetText(255 - len)
    else
        editbox.characterCount:SetText("")
    end
end

function CHAT:EditBoxOnKeyDown(editbox, key)
    if not editbox then return end

    local lines = editbox.historyLines
    if not lines then return end

    if IsAltKeyDown() then return end

    local maxLines = #lines
    if maxLines == 0 then return end

    if key == "DOWN" then
        editbox.historyIndex = (editbox.historyIndex or 0) - 1

        if editbox.historyIndex < 1 then
            editbox.historyIndex = 0
            editbox:SetText("")
            return
        end
    elseif key == "UP" then
        editbox.historyIndex = (editbox.historyIndex or 0) + 1

        if editbox.historyIndex > maxLines then editbox.historyIndex = maxLines end
    else
        return
    end

    local historyLine = maxLines - (editbox.historyIndex - 1)
    local historyText = lines[historyLine]
    if historyText then editbox:SetText(historyText) end
end

function CHAT:StyleEditbox(editbox)
    if not editbox or editbox.styled then return end

    local db = self.db
    local name = editbox:GetName()

    editbox:SetAltArrowKeyMode(false)
    self:ApplyFrameStyle(editbox, nil, true)

    local charCount = editbox:CreateFontString(nil, "ARTWORK")
    charCount:SetFont(cachedFontPath, 10, db.FontOutline or "")
    charCount:SetTextColor(190 / 255, 190 / 255, 190 / 255, 0.4)
    charCount:SetPoint("TOPRIGHT", editbox, "TOPRIGHT", -5, 0)
    charCount:SetPoint("BOTTOMRIGHT", editbox, "BOTTOMRIGHT", -5, 0)
    charCount:SetJustifyH("CENTER")
    charCount:SetWidth(40)
    editbox.characterCount = charCount

    if name then
        local header = _G[name .. "Header"]
        if header then header:Hide() end

        local headerSuffix = _G[name .. "HeaderSuffix"]
        if headerSuffix then headerSuffix:Hide() end
    end

    if editbox.focusLeft then editbox.focusLeft:SetAlpha(0) end
    if editbox.focusRight then editbox.focusRight:SetAlpha(0) end
    if editbox.focusMid then editbox.focusMid:SetAlpha(0) end

    editbox:HookScript("OnTextChanged", function(eb) CHAT:EditBoxOnTextChanged(eb) end)
    editbox:HookScript("OnEditFocusGained", function(eb) CHAT:EditBoxFocusGained(eb) end)
    editbox:HookScript("OnEditFocusLost", function(eb) CHAT:EditBoxFocusLost(eb) end)
    editbox:HookScript("OnKeyDown", function(eb, key) CHAT:EditBoxOnKeyDown(eb, key) end)

    editbox.historyLines = {}
    editbox.historyIndex = 0

    if editbox.AddHistoryLine and not self:IsHooked(editbox, "AddHistoryLine") then
        self:SecureHook(editbox, "AddHistoryLine", function(eb, text)
            if text and #text > 0 then
                tinsert(eb.historyLines, text)
                while #eb.historyLines > 50 do
                    tremove(eb.historyLines, 1)
                end
            end
        end)
    end

    if editbox.UpdateHeader and not self:IsHooked(editbox, "UpdateHeader") then
        self:SecureHook(editbox, "UpdateHeader", "OnChatEdit_UpdateHeader")
    end

    editbox:Hide()

    editbox.styled = true
end

function CHAT:UpdateEditboxAnchors(cvar, value)
    if not cvar then value = GetCVar("chatStyle") end

    local db = self.db
    local classic = value == "classic"
    local leftChat = classic and self.panel
    local panelHeight = EDITBOX_HEIGHT

    local position = db.EditBoxPosition or "BELOW_CHAT"
    local aboveInside = position == "ABOVE_CHAT_INSIDE"
    local belowInside = position == "BELOW_CHAT_INSIDE"
    local below = position == "BELOW_CHAT"

    local offsetBelow = classic and (belowInside and 1 or 0) or -5
    local offsetAbove = classic and (aboveInside and -1 or 0) or 2

    local belowTopY = classic and 0 or -2
    local belowBottomY = classic and 0 or -2
    local belowTopX = offsetBelow + (belowInside and panelHeight or 0)
    local belowBottomX = offsetBelow + (belowInside and 0 or -panelHeight)

    local aboveTopY = classic and (aboveInside and -1 or 0) or 2
    local aboveBottomY = classic and (aboveInside and 1 or 0) or -2
    local aboveTopX = offsetAbove + (aboveInside and 0 or panelHeight)
    local aboveBottomX = offsetAbove + (aboveInside and -panelHeight or 0)

    for _, frameName in ipairs(_G.CHAT_FRAMES) do
        local chat = _G[frameName]
        local editbox = chat and chat.editBox
        if editbox and self:IsChatValid(chat) then
            editbox.chatStyle = value
            editbox:ClearAllPoints()

            local anchorTo = leftChat or chat
            if below or belowInside then
                editbox:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", belowTopY, belowTopX)
                editbox:SetPoint("BOTTOMRIGHT", anchorTo, "BOTTOMRIGHT", belowBottomY, belowBottomX)
            else
                editbox:SetPoint("TOPRIGHT", anchorTo, "TOPRIGHT", aboveTopY, aboveTopX)
                editbox:SetPoint("BOTTOMLEFT", anchorTo, "TOPLEFT", aboveBottomY, aboveBottomX)
            end
        end
    end
end

function CHAT:StyleChat(chat)
    if not chat then return end

    local db = self.db
    local id = chat:GetID()
    local tab = self:GetTab(chat)

    local _, fontSize = FCF_GetChatWindowInfo(id)
    local fontOutline = NormalizeFontOutline(db.FontOutline)
    chat:SetFont(cachedFontPath, fontSize, fontOutline)

    local shadow = db.FontShadow
    if shadow and shadow.Enabled then
        local shadowColor = shadow.Color or { 0, 0, 0, 1 }
        chat:SetShadowColor(shadowColor[1] or 0, shadowColor[2] or 0, shadowColor[3] or 0, shadowColor[4] or 1)
        chat:SetShadowOffset(shadow.OffsetX or 1, shadow.OffsetY or -1)
    else
        chat:SetShadowOffset(0, 0)
    end

    chat:SetTimeVisible(db.FadeEnabled and db.FadeTime or 120)
    chat:SetMaxLines(db.MaxLines or 500)
    chat:SetFading(db.FadeEnabled ~= false)

    local allowHooks = id and not IGNORE_FRAMES[id]
    if allowHooks and not chat.OldAddMessage then
        chat.OldAddMessage = chat.AddMessage
        chat.AddMessage = self.AddMessage
    end

    if tab and not IsCombatLog(chat) then tab:SetScript("OnClick", CHAT.Tab_OnClick) end

    if tab and tab.Text then
        local tabFontSize = db.TabFontSize or 12
        local tabFontOutline = NormalizeFontOutline(db.FontOutline)
        tab.Text:SetFont(cachedFontPath, tabFontSize, tabFontOutline)

        if shadow and shadow.Enabled then
            local shadowColor = shadow.Color or { 0, 0, 0, 1 }
            tab.Text:SetShadowColor(shadowColor[1] or 0, shadowColor[2] or 0, shadowColor[3] or 0, shadowColor[4] or 1)
            tab.Text:SetShadowOffset(shadow.OffsetX or 1, shadow.OffsetY or -1)
        else
            tab.Text:SetShadowOffset(0, 0)
        end
    end

    if tab and not chat.isDocked and _G.PanelTemplates_TabResize then
        _G.PanelTemplates_TabResize(tab, tab.sizePadding or 0)
    end

    if chat.styled then return end

    if not self.originalStates[id] then
        self.originalStates[id] = {
            parent = chat:GetParent(),
            points = {},
            width = chat:GetWidth(),
            height = chat:GetHeight(),
            frameLevel = chat:GetFrameLevel(),
            timeVisible = chat.GetTimeVisible and chat:GetTimeVisible(),
            maxLines = chat.GetMaxLines and chat:GetMaxLines(),
            fading = chat.GetFading and chat:GetFading(),
        }

        for i = 1, chat:GetNumPoints() do
            local point, relativeTo, relativePoint, xOfs, yOfs = chat:GetPoint(i)
            self.originalStates[id].points[i] = { point, relativeTo, relativePoint, xOfs, yOfs }
        end

        if tab then self.originalStates[id].tabParent = tab:GetParent() end
        if chat.Background then self.originalStates[id].backgroundShown = chat.Background:IsShown() end
    end

    chat:SetFrameLevel(CHAT_FRAME_LEVEL)
    chat:SetClampRectInsets(0, 0, 0, 0)
    chat:SetClampedToScreen(false)

    if tab then self:StyleTab(tab, chat) end

    self:HideChatElements(chat)
    self:SetupChatScripts(chat)

    local editbox = chat.editBox
    if editbox then self:StyleEditbox(editbox) end

    self:CreateCopyButton(chat)

    chat.styled = true
end

local HiddenFrame = CreateFrame("Frame")
HiddenFrame:Hide()

function CHAT:DisableFrame(object)
    if not object then return end

    if object.GetChildren then for _, child in pairs({ object:GetChildren() }) do self:DisableFrame(child) end end
    if object.UnregisterAllEvents then
        object:UnregisterAllEvents()
        object:SetParent(HiddenFrame)
    else
        object.Show = object.Hide
    end
    object:Hide()
end

local BLIZZ_FRAME_KEYS = {
    'Inset', 'inset', 'InsetFrame', 'LeftInset', 'RightInset',
    'NineSlice', 'BG', 'Bg', 'border', 'Border', 'Background',
    'BorderFrame', 'bottomInset', 'BottomInset', 'bgLeft', 'bgRight',
    'FilligreeOverlay', 'PortraitOverlay', 'ArtOverlayFrame',
    'Portrait', 'portrait', 'ScrollFrameBorder',
}

function CHAT:ClearFrameTextures(frame, kill)
    if not frame then return end

    local frameName = frame.GetName and frame:GetName()
    for _, blizz in ipairs(BLIZZ_FRAME_KEYS) do
        local child = frame[blizz] or (frameName and _G[frameName .. blizz])
        if child and child.GetRegions then self:ClearFrameTextures(child, kill) end
    end

    if frame.GetRegions then
        for _, region in pairs({ frame:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                if kill then
                    region:Hide()
                    if region.UnregisterAllEvents then region:UnregisterAllEvents() end
                else
                    region:SetTexture()
                    if region.SetAtlas then region:SetAtlas("") end
                end
            end
        end
    end
end

function CHAT:HideChatElements(chat)
    local name = chat:GetName()

    self:PositionButtonFrame(chat)

    self:ClearFrameTextures(chat, true)

    if chat.ScrollBar then self:DisableFrame(chat.ScrollBar) end
    if chat.ScrollToBottomButton then self:DisableFrame(chat.ScrollToBottomButton) end

    local thumbTexture = _G[name .. "ThumbTexture"]
    if thumbTexture then self:DisableFrame(thumbTexture) end

    local minimize = _G[name .. "MinimizeButton"]
    if minimize then self:DisableFrame(minimize) end

    local editLeft = _G[name .. "EditBoxLeft"]
    if editLeft then self:DisableFrame(editLeft) end

    local editMid = _G[name .. "EditBoxMid"]
    if editMid then self:DisableFrame(editMid) end

    local editRight = _G[name .. "EditBoxRight"]
    if editRight then self:DisableFrame(editRight) end
end

function CHAT:PositionButtonFrame(chat)
    if not chat.buttonFrame then return end
    chat.buttonFrame:ClearAllPoints()
    chat.buttonFrame:SetPoint("TOP", chat, "BOTTOM", 0, -90000)
    chat.buttonFrame:SetClipsChildren(true)
end

local hyperlinkHoveredFrame
function CHAT:OnHyperlinkEnter(frame, refString)
    if InCombatLockdown() then return end
    local linkToken = strmatch(refString, "^([^:]+)")
    if HYPERLINK_TYPES[linkToken] then
        GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(refString)
        GameTooltip:Show()
        hyperlinkHoveredFrame = frame
    end
end

function CHAT:OnHyperlinkLeave()
    if hyperlinkHoveredFrame then
        hyperlinkHoveredFrame = nil
        GameTooltip:Hide()
    end
end

function CHAT:SetupChatScripts(chat)
    if chat.scriptsSet then return end

    local id = chat:GetID()
    local allowHooks = id and not IGNORE_FRAMES[id]

    if not chat.nrsknSetScriptHooked then
        chat.nrsknSetScriptHooked = true
        hooksecurefunc(chat, "SetScript", function(frame, scriptType, handler)
            self:ChatFrame_SetScript(frame, scriptType, handler)
        end)
    end

    -- Replace OnEvent with our handler to prevent taint from secret valuesTable
    if allowHooks and NRSKNUI.ChatMessageHandler then
        chat:SetScript("OnEvent", function(frame, event, ...)
            NRSKNUI.ChatMessageHandler:FloatingChatFrame_OnEvent(frame, event, ...)
        end)
    end

    chat.nrsknSettingMouseWheel = true
    chat:SetScript("OnMouseWheel", function(frame, delta) self:ChatFrame_OnMouseWheel(frame, delta) end)
    chat.nrsknSettingMouseWheel = nil

    if not self:IsHooked(chat, "OnHyperlinkEnter") then self:HookScript(chat, "OnHyperlinkEnter", "OnHyperlinkEnter") end
    if not self:IsHooked(chat, "OnHyperlinkLeave") then self:HookScript(chat, "OnHyperlinkLeave", "OnHyperlinkLeave") end

    chat.scriptsSet = true
end

function CHAT:SetupDockManager()
    local docker = _G.GeneralDockManager
    if not docker then return end

    local primary = docker.primary
    if not primary then return end

    if not self.originalDockState then
        self.originalDockState = { parent = docker:GetParent(), points = {}, }
        for i = 1, docker:GetNumPoints() do
            local point, relativeTo, relativePoint, xOfs, yOfs = docker:GetPoint(i)
            self.originalDockState.points[i] = { point, relativeTo, relativePoint, xOfs, yOfs }
        end
    end

    docker:SetParent(self.panel)
    docker:ClearAllPoints()
    docker:SetPoint("BOTTOMLEFT", primary, "TOPLEFT", 0, 7)
    docker:SetPoint("BOTTOMRIGHT", primary, "TOPRIGHT", 0, 7)
    docker:SetHeight(22)

    local scrollFrame = _G.GeneralDockManagerScrollFrame
    if scrollFrame then scrollFrame:SetHeight(22) end

    if _G.GeneralDockManagerScrollFrameChild then _G.GeneralDockManagerScrollFrameChild:SetHeight(22) end

    self:StyleOverflowButton()
    self:OnFCFDock_ScrollToSelectedTab(docker)
end

local ARROW_TEX = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\collapse.tga"
function CHAT:StyleOverflowButton()
    local btn = _G.GeneralDockManagerOverflowButton
    if not btn then return end

    if _G.GeneralDockManagerOverflowButtonList then
        _G.GeneralDockManagerOverflowButtonList:SetFrameStrata("LOW")
        _G.GeneralDockManagerOverflowButtonList:SetFrameLevel(5)
    end

    btn:ClearAllPoints()
    btn:SetPoint("RIGHT", _G.GeneralDockManager, "RIGHT", -4, 0)

    if not btn.NorskenStyled then
        for _, region in next, { btn:GetRegions() } do
            if region:IsObjectType("Texture") then
                region:SetTexture(nil)
                region:Hide()
            end
        end

        if btn.Texture then
            btn.Texture:SetTexture(nil)
            btn.Texture:Hide()
        end
        if btn.Flash then
            btn.Flash:SetTexture(nil)
            btn.Flash:Hide()
        end
        if btn.FlashBorder then
            btn.FlashBorder:SetTexture(nil)
            btn.FlashBorder:Hide()
        end
        if btn.GlowTexture then
            btn.GlowTexture:SetTexture(nil)
            btn.GlowTexture:Hide()
        end

        local hl = btn:GetHighlightTexture()
        if hl then
            hl:SetTexture(nil)
            hl:Hide()
        end

        local normal = btn:GetNormalTexture()
        if normal then
            normal:SetTexture(nil)
            normal:Hide()
        end

        local pushed = btn:GetPushedTexture()
        if pushed then
            pushed:SetTexture(nil)
            pushed:Hide()
        end

        local arrow = btn:CreateTexture(nil, "ARTWORK")
        arrow:SetTexture(ARROW_TEX)
        arrow:SetTexCoord(0, 1, 0, 1)
        arrow:SetSize(14, 14)
        arrow:SetPoint("CENTER")

        btn.Texture = arrow
        btn.NorskenStyled = true
    end

    local function ApplyInactiveColor()
        if not btn.Texture then return end
        local colorMode = self.db.TabTextColorMode or "custom"
        local customColor = self.db.TabTextColor or cachedTabAccentColor
        local r, g, b = NRSKNUI:GetAccentColor(colorMode, { customColor.r, customColor.g, customColor.b, 1 })
        btn.Texture:SetVertexColor(r, g, b)
    end

    local function ApplySelectedColor()
        if not btn.Texture then return end
        if self.db.TabSelectedTextEnabled and self.db.TabSelectedTextColor then
            local c = self.db.TabSelectedTextColor
            btn.Texture:SetVertexColor(c.r, c.g, c.b)
        else
            btn.Texture:SetVertexColor(1, 1, 1)
        end
    end

    ApplyInactiveColor()

    if not btn.NorskenHooked then
        btn:HookScript("OnEnter", ApplySelectedColor)
        btn:HookScript("OnLeave", ApplyInactiveColor)
        btn.NorskenHooked = true
    end

    if not btn.SetAlphaHooked then
        local origSetAlpha = btn.SetAlpha
        btn.SetAlpha = function(frame, alpha)
            if frame.alerting then
                alpha = 1
            elseif alpha < 0.5 then
                local hooks = CHAT.hooks and CHAT.hooks[_G.GeneralDockManager.primary]
                if not (hooks and hooks.OnEnter) then alpha = 0.5 end
            end
            origSetAlpha(frame, alpha)
        end
        btn.SetAlphaHooked = true
    end
end

function CHAT:PositionChats()
    if not self.panel then return end

    local db = self.db
    local panelWidth = db.Width or PANEL_WIDTH
    local panelHeight = db.Height or PANEL_HEIGHT

    self.panel:SetSize(panelWidth, panelHeight)

    local docker = _G.GeneralDockManager and _G.GeneralDockManager.primary
    if docker then self:PositionChat(docker) end

    for _, frameName in ipairs(_G.CHAT_FRAMES) do
        local chat = _G[frameName]
        if chat and chat ~= docker and self:IsChatValid(chat) then self:PositionChat(chat) end
    end
end

function CHAT:PositionChat(chat)
    if not chat or not self.panel then return end
    if self.isPositioning then return end

    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            self:PositionChat(chat)
        end)
        return
    end

    self.isPositioning = true
    self.ChatWindow = self:GetPanelAnchoredChat()

    local docker = _G.GeneralDockManager.primary
    if chat == docker then
        local chatParent = (chat == self.ChatWindow) and self.panel or UIParent
        _G.GeneralDockManager:SetParent(chatParent)
    end

    self:UpdateChatTab(chat)

    if chat:IsMovable() then chat:SetUserPlaced(true) end

    if chat.FontStringContainer then
        chat.FontStringContainer:ClearAllPoints()
        chat.FontStringContainer:SetPoint("TOPLEFT", chat, "TOPLEFT", -3, 3)
        chat.FontStringContainer:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 3, -3)
    end

    local db = self.db
    local panelWidth = db.Width or PANEL_WIDTH
    local panelHeight = db.Height or PANEL_HEIGHT

    local logOffset = 0
    if IsCombatLog and IsCombatLog(chat) then
        local tabBackdropHeight = self.tabBackdrop and self.tabBackdrop:IsShown() and self.tabBackdrop:GetHeight() or
            TAB_HEIGHT
        logOffset = tabBackdropHeight + 4
    end

    if chat == self.ChatWindow then
        chat:SetParent(self.panel)
        chat:ClearAllPoints()
        chat:SetPoint("BOTTOMLEFT", self.panel, "BOTTOMLEFT", H_PADDING, PADDING)
        chat:SetSize(panelWidth - (H_PADDING * 2), panelHeight - BASE_OFFSET - logOffset)

        local tab = self:GetTab(chat)
        if tab and not chat.isDocked then tab:SetParent(self.panel) end

        self:SetBackgroundVisible(chat.Background, false)
    else
        self:SetBackgroundVisible(chat.Background, self:IsFloating(chat, docker))
    end

    if chat.EditModeResizeButton then
        chat.EditModeResizeButton:SetFrameStrata("HIGH")
        chat.EditModeResizeButton:SetFrameLevel(6)
    end

    self.isPositioning = false
end

function CHAT:StyleCombatLog()
    local bar = _G.CombatLogQuickButtonFrame_Custom
    if not bar then return end

    local combatLog = _G.ChatFrame2

    if bar.SetBackdrop and not bar.styled then
        for _, region in pairs({ bar:GetRegions() }) do
            if region:IsObjectType("Texture") then
                region:SetTexture()
            end
        end

        bar:SetBackdrop(BACKDROP_TEMPLATE)
        bar:SetBackdropColor(0, 0, 0, 0.6)
        bar:SetBackdropBorderColor(0, 0, 0, 1)
        bar.styled = true
    end

    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", combatLog, "TOPLEFT", -3, 2)
    bar:SetPoint("BOTTOMRIGHT", combatLog, "TOPRIGHT", 3, 2)

    local tex = _G.CombatLogQuickButtonFrame_CustomTexture
    if tex then tex:Hide() end
end

function CHAT:ChatFrame_OnMouseWheel(frame, delta)
    if hyperlinkHoveredFrame == frame then
        hyperlinkHoveredFrame = nil
        GameTooltip:Hide()
    end

    local numScrollMessages = self.db.NumScrollMessages or 3

    if delta < 0 then
        if IsShiftKeyDown() then
            frame:ScrollToBottom()
        elseif IsAltKeyDown() then
            frame:ScrollDown()
        else
            for _ = 1, numScrollMessages do frame:ScrollDown() end
        end
    elseif delta > 0 then
        if IsShiftKeyDown() then
            frame:ScrollToTop()
        elseif IsAltKeyDown() then
            frame:ScrollUp()
        else
            for _ = 1, numScrollMessages do frame:ScrollUp() end
        end
    end
end

function CHAT:ChatFrame_SetScript(frame, scriptType)
    if scriptType == "OnMouseWheel" and not frame.nrsknSettingMouseWheel then
        C_Timer.After(0, function()
            if frame and frame.scriptsSet and not frame.nrsknSettingMouseWheel then
                frame.nrsknSettingMouseWheel = true
                frame:SetScript("OnMouseWheel", function(f, delta) self:ChatFrame_OnMouseWheel(f, delta) end)
                frame.nrsknSettingMouseWheel = nil
            end
        end)
    end
end

function CHAT:RestoreAllChats()
    for _, frameName in ipairs(_G.CHAT_FRAMES) do
        local chat = _G[frameName]
        if chat then self:RestoreChat(chat) end
    end

    self:RestoreDockManager()
    self.originalStates = {}
    self.ChatWindow = nil
end

function CHAT:RestoreChat(chat)
    if not chat then return end

    local id = chat:GetID()
    local state = self.originalStates[id]
    if not state then return end

    if state.parent then chat:SetParent(state.parent) end
    if state.points then
        chat:ClearAllPoints()
        for _, pointData in ipairs(state.points) do
            if pointData[2] then
                chat:SetPoint(pointData[1], pointData[2], pointData[3], pointData[4], pointData[5])
            end
        end
    end

    if state.width and state.height then chat:SetSize(state.width, state.height) end
    if state.frameLevel then chat:SetFrameLevel(state.frameLevel) end
    if state.timeVisible then chat:SetTimeVisible(state.timeVisible) end
    if state.maxLines then chat:SetMaxLines(state.maxLines) end
    if state.fading ~= nil then chat:SetFading(state.fading) end
    local tab = self:GetTab(chat)
    if tab and state.tabParent then tab:SetParent(state.tabParent) end
    if chat.Background then
        chat.Background.Show = nil
        if state.backgroundShown then chat.Background:Show() end
    end
    chat.styled = nil
    chat.scriptsSet = nil
end

function CHAT:RestoreDockManager()
    local docker = _G.GeneralDockManager
    if not docker or not self.originalDockState then return end
    if self.originalDockState.parent then docker:SetParent(self.originalDockState.parent) end
    if self.originalDockState.points then
        docker:ClearAllPoints()
        for _, pointData in ipairs(self.originalDockState.points) do
            if pointData[2] then docker:SetPoint(pointData[1], pointData[2], pointData[3], pointData[4], pointData[5]) end
        end
    end
    self.originalDockState = nil
end

function CHAT:UpdatePanel()
    if not self.panel then return end
    local db = self.db

    self.panel:SetSize(db.Width or PANEL_WIDTH, db.Height or PANEL_HEIGHT)
    self.panel:ClearAllPoints()
    self.panel:SetPoint(
        db.Position.AnchorFrom,
        _G[db.ParentFrame] or UIParent,
        db.Position.AnchorTo,
        db.Position.XOffset,
        db.Position.YOffset
    )

    if self.panel.backdrop then self:ApplyBackdrop(self.panel.backdrop) end
    self:UpdateTabBackdrop()
    self:PositionChats()
end

function CHAT:ApplySettings()
    if NRSKNUI:ShouldNotLoadModule() then return end
    if not self.db.Enabled then return end
    self:UpdateDB()
    self:UpdatePanel()

    for _, frameName in ipairs(_G.CHAT_FRAMES) do
        local chat = _G[frameName]
        if chat then
            self:StyleChat(chat)
            if _G.FCFTab_UpdateAlpha then _G.FCFTab_UpdateAlpha(chat) end
        end
    end

    self:UpdateChatTabs()
    self:UpdateChatTabColors()
    self:UpdateEditboxAnchors()
end

-- Blizzard Edit Mode lock functionality
-- Prevents dragging and resizing chat in Blizzard's edit mode and shows helper text
local blizzEditModeLockState = setmetatable({}, { __mode = "k" })

function CHAT:GetBlizzEditModeLockState(selection)
    local state = blizzEditModeLockState[selection]
    if not state then
        state = {}
        blizzEditModeLockState[selection] = state
    end
    return state
end

function CHAT:EnsureBlizzEditModeLockText(selection)
    if not selection then return end
    local state = self:GetBlizzEditModeLockState(selection)
    if state.lockText then return end

    if not state.textOverlay then
        state.textOverlay = CreateFrame("Frame", nil, UIParent)
        state.textOverlay:SetAllPoints(selection)
        state.textOverlay:SetFrameStrata("TOOLTIP")
        state.textOverlay:SetFrameLevel(selection:GetFrameLevel() + 5)
    end

    local text = state.textOverlay:CreateFontString(nil, "OVERLAY")
    text:SetIgnoreParentScale(true)
    text:SetPoint("CENTER")
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(true)
    state.lockText = text
end

function CHAT:SetBlizzEditModeLockText(frame, shown)
    if InCombatLockdown() then return end

    local selection = frame.Selection
    if not selection then return end

    if not shown then
        local state = blizzEditModeLockState[selection]
        if state then
            if state.lockText then state.lockText:Hide() end
            if state.textOverlay then state.textOverlay:Hide() end
        end
        return
    end

    self:EnsureBlizzEditModeLockText(selection)
    local state = self:GetBlizzEditModeLockState(selection)
    local text = state.lockText
    if state.textOverlay then state.textOverlay:Show() end

    text:SetFont(NRSKNUI.Media.Fonts.Expressway, 12, "OUTLINE")
    text:SetShadowColor(0, 0, 0, 0)
    text:SetShadowOffset(0, 0)
    text:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)

    local maxWidth = selection:GetWidth() - 12
    if maxWidth > 0 then text:SetWidth(maxWidth) end

    text:SetText("Edit Mode locked for the chat\nUse |cff00ff00/nui edit|r or |cff00ff00/nui|r -> Chat")
    text:Show()
end

function CHAT:SetupBlizzEditModeLockHandlers(frame)
    if InCombatLockdown() then return end

    local selection = frame.Selection
    if not selection then return end

    local state = self:GetBlizzEditModeLockState(selection)
    if state.handlersSet then return end

    state.handlersSet = true

    selection:HookScript("OnMouseDown", function()
        self:SetBlizzEditModeLockText(frame, true)
        state.lockTextToken = (state.lockTextToken or 0) + 1
        local token = state.lockTextToken
        C_Timer.After(3, function()
            if state.lockTextToken == token then self:SetBlizzEditModeLockText(frame, false) end
        end)
    end)

    selection:HookScript("OnHide", function() self:SetBlizzEditModeLockText(frame, false) end)
end

function CHAT:LockChatInBlizzEditMode(chat)
    if not chat then return end
    if InCombatLockdown() then return end

    local selection = chat.Selection
    if selection then
        selection:SetScript("OnDragStart", nil)
        selection:SetScript("OnDragStop", nil)
        selection:EnableMouse(false)
    end

    if chat.EditModeResizeButton then
        chat.EditModeResizeButton:Hide()
        chat.EditModeResizeButton:EnableMouse(false)
        chat.EditModeResizeButton.Show = chat.EditModeResizeButton.Hide
    end

    self:SetupBlizzEditModeLockHandlers(chat)
    self:SetBlizzEditModeLockText(chat, false)
end

function CHAT:SetupBlizzardEditModeLock()
    if self.blizzEditModeLockSetup then return end

    local function TrySetup()
        local EditModeSystemSettingsDialog = _G.EditModeSystemSettingsDialog
        if not EditModeSystemSettingsDialog then return false end

        local chatFrame = _G.ChatFrame1
        if not chatFrame then return false end

        hooksecurefunc(EditModeSystemSettingsDialog, "AttachToSystemFrame", function(dialog, systemFrame)
            if not systemFrame then return end
            local name = systemFrame:GetName()
            if not name then return end

            if name:match("^ChatFrame%d+$") then
                dialog:Hide()
                self:SetupBlizzEditModeLockHandlers(systemFrame)
                if not self.blizzEditModeChatNoticeShown then
                    NRSKNUI:Print("Chat position is managed by |cff00ff00/nui edit|r or |cff00ff00/nui|r settings.")
                    self.blizzEditModeChatNoticeShown = true
                end
            end
        end)

        for i = 1, 12 do
            local chat = _G["ChatFrame" .. i]
            if chat then
                if chat.SelectSystem then
                    hooksecurefunc(chat, "SelectSystem", function(cf)
                        if EditModeSystemSettingsDialog.attachedToSystem == cf then EditModeSystemSettingsDialog:Hide() end
                        self:SetupBlizzEditModeLockHandlers(cf)
                        if cf.Selection then cf.Selection:EnableMouse(false) end
                        if not self.blizzEditModeChatNoticeShown then
                            NRSKNUI:Print(
                                "Chat position is managed by |cff00ff00/nui edit|r or |cff00ff00/nui|r settings.")
                            self.blizzEditModeChatNoticeShown = true
                        end
                    end)
                end

                if chat.HighlightSystem then
                    hooksecurefunc(chat, "HighlightSystem", function(cf) self:SetupBlizzEditModeLockHandlers(cf) end)
                end
                if chat.ClearHighlight then
                    hooksecurefunc(chat, "ClearHighlight", function(cf) self:SetBlizzEditModeLockText(cf, false) end)
                end

                self:LockChatInBlizzEditMode(chat)
            end
        end

        self.blizzEditModeLockSetup = true
        return true
    end

    if not TrySetup() then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", function() TrySetup() end)
    end
end

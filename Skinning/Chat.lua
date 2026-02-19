-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)
local Theme = NRSKNUI.Theme

-- Check for addon object
if not NorskenUI then
    error("Chat: Addon object not initialized. Check file load order!")
    return
end

-- Create module
---@class Chat: AceModule, AceEvent-3.0
local CHAT = NorskenUI:NewModule("Chat", "AceEvent-3.0")

-- Localization
local next = next
local IsShiftKeyDown = IsShiftKeyDown
local IsControlKeyDown = IsControlKeyDown
local hooksecurefunc = hooksecurefunc
local GetRealmName = GetRealmName
local gsub = gsub
local strsub = strsub
local pairs, ipairs = pairs, ipairs
local tContains = tContains
local CreateFrame = CreateFrame
local pcall = pcall
local getmetatable = getmetatable
local _G = _G
local C_Timer = C_Timer

-- Constants
local TAB_INACTIVE_ALPHA = 0.6
local TAB_ACTIVE_ALPHA = 1
local TAB_AREA_HEIGHT = 25
local DEFAULT_CHAT_FONT_SIZE = 12
local DEFAULT_TAB_FONT_SIZE = 12
local DEFAULT_EDITBOX_FONT_SIZE = 13

-- Tab color lookup table
local TAB_COLOR_DEFAULTS = {
    alert = { 1, 0, 0, 1 },
    active = { 1, 1, 1, 1 },
    whisper = { 1, 0.5, 0.8, 1 },
    inactive = { 0.898, 0.063, 0.224, 1 },
}

-- Helper to get tab colors
local function GetTabColor(colorType)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.Chat
    local tabColors = db and db.TabColors or {}

    if colorType == "inactive" then
        local colorMode = tabColors.InactiveColorMode or "custom"
        local customColor = tabColors.InactiveColor or TAB_COLOR_DEFAULTS.inactive
        if NRSKNUI.GetAccentColor then
            return NRSKNUI:GetAccentColor(colorMode, customColor)
        else
            return customColor[1], customColor[2], customColor[3], customColor[4] or 1
        end
    end

    local colorKey = colorType == "alert" and "AlertColor"
        or colorType == "active" and "ActiveColor"
        or colorType == "whisper" and "WhisperColor"
        or nil

    if colorKey then
        local c = tabColors[colorKey] or TAB_COLOR_DEFAULTS[colorType]
        return c[1], c[2], c[3], c[4] or 1
    end

    return 1, 1, 1, 1
end

-- Tab tracking, we declare these early so UpdateTabColors can access them
local chatTabAlerts = {}
local chatTabIndices = NRSKNUI:T()
local SetTextColor = UIParent:CreateFontString().SetTextColor
local originalSetAlpha = getmetatable(CreateFrame("Frame")).__index.SetAlpha
local updateTabColor

-- Module init bruv
function CHAT:OnInitialize()
    self.db = NRSKNUI.db.profile.Skinning.Chat
    self.backdrops = {}
    self:SetEnabledState(false)
end

-- Backdrop for editbox using BackdropTemplate with edge
local editBoxBackdropInfo = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
    tile = true,
    tileSize = 16,
    edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

-- Create backdrop for editbox
function CHAT:CreateEditBoxBackdrop(parent, alpha, xOffset, yOffset)
    local backdrop = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    local parentLevel = parent:GetFrameLevel()
    backdrop:SetFrameLevel(math.max(0, parentLevel - 1))
    backdrop:SetPoint("TOPLEFT", xOffset or 0, -(yOffset or 0))
    backdrop:SetPoint("BOTTOMRIGHT", -(xOffset or 0), yOffset or 0)
    backdrop:SetBackdrop(editBoxBackdropInfo)
    backdrop:SetBackdropColor(0, 0, 0, alpha or 0.6)
    backdrop:SetBackdropBorderColor(0, 0, 0, alpha or 0.6)

    self.backdrops[parent] = backdrop
    return backdrop
end

-- Create main chat backdrop with pixel-perfect borders
function CHAT:CreateChatBackDrop()
    local db = self.db
    local bgColor = db.Backdrop and db.Backdrop.Color or { 0, 0, 0, 0.8 }
    local borderColor = db.Backdrop and db.Backdrop.BorderColor or { 0, 0, 0, 1 }
    local backdropEnabled = db.Backdrop and db.Backdrop.Enabled ~= false
    local posDB = db.Position

    local backdrop = CreateFrame("Frame", "NRSKNUI_ChatBackdrop", UIParent, "BackdropTemplate")
    backdrop:SetWidth(db.Width)
    backdrop:SetHeight(db.Height)
    backdrop:SetPoint(posDB.AnchorFrom, UIParent, posDB.AnchorTo, posDB.XOffset, posDB.YOffset)
    backdrop:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    backdrop:SetFrameStrata("BACKGROUND")

    -- Apply backdrop color (alpha 0 if disabled so that we can still anchor chatFrame)
    if backdropEnabled then
        backdrop:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    else
        backdrop:SetBackdropColor(0, 0, 0, 0)
    end

    -- Create border container for frame level control
    local borderFrame = CreateFrame("Frame", nil, backdrop)
    borderFrame:SetAllPoints(backdrop)
    borderFrame:SetFrameLevel(backdrop:GetFrameLevel() + 1)

    -- Use shared border helper with borderFrame for frame level control
    local borderAlpha = backdropEnabled and borderColor[4] or 0
    NRSKNUI:AddBorders(backdrop, { borderColor[1], borderColor[2], borderColor[3], borderAlpha }, borderFrame)

    -- Store reference
    self.backdrop = backdrop

    -- Position the dock manager
    if GeneralDockManager then
        GeneralDockManager:ClearAllPoints()
        GeneralDockManager:SetPoint("BOTTOMLEFT", backdrop, "TOPLEFT", 0, 0)
        GeneralDockManager:SetPoint("BOTTOMRIGHT", backdrop, "TOPRIGHT", 0, 0)
        GeneralDockManager:SetHeight(TAB_AREA_HEIGHT)
    end
end

-- Update backdrop colors from DB
function CHAT:UpdateBackdrop()
    if not self.backdrop then return end
    local db = self.db
    local bgColor = db.Backdrop and db.Backdrop.Color or { 0, 0, 0, 0.8 }
    local borderColor = db.Backdrop and db.Backdrop.BorderColor or { 0, 0, 0, 1 }
    local backdropEnabled = db.Backdrop and db.Backdrop.Enabled ~= false
    local posDB = db.Position

    -- Apply backdrop size
    self.backdrop:SetWidth(db.Width)
    self.backdrop:SetHeight(db.Height)

    -- Apply backdrop position
    self.backdrop:ClearAllPoints()
    self.backdrop:SetPoint(posDB.AnchorFrom, UIParent, posDB.AnchorTo, posDB.XOffset, posDB.YOffset)

    -- Apply backdrop color
    if backdropEnabled then
        self.backdrop:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    else
        self.backdrop:SetBackdropColor(0, 0, 0, 0)
    end

    -- Update border colors
    local borderAlpha = backdropEnabled and borderColor[4] or 0
    if self.backdrop.borders then
        self.backdrop:SetBorderColor(borderColor[1], borderColor[2], borderColor[3], borderAlpha)
    end
end

-- Update editbox backdrops from DB
function CHAT:UpdateEditBox()
    local editBoxDB = self.db.EditBox or {}
    local bgColor = editBoxDB.BackdropColor or { 0, 0, 0, 0.8 }
    local borderColor = editBoxDB.BorderColor or { 0, 0, 0, 1 }

    for i = 1, 12 do
        local editBox = _G['ChatFrame' .. i .. 'EditBox']
        if editBox and self.backdrops[editBox] then
            self.backdrops[editBox]:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
            self.backdrops[editBox]:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor
                [4])
        end
    end
end

-- Update tab colors from DB
function CHAT:UpdateTabColors()
    for _, tabIndex in next, chatTabIndices do
        updateTabColor(tabIndex)
    end
end

-- Update fonts from DB
function CHAT:UpdateFonts()
    local db = self.db
    local font = NRSKNUI:GetFontPath(db.FontFace) or NRSKNUI.FONT
    local outline = db.FontOutline or "OUTLINE"
    if outline == "NONE" then outline = "" end
    local editBoxSize = db.EditBoxFontSize or DEFAULT_EDITBOX_FONT_SIZE
    local chatSize = db.ChatFontSize or DEFAULT_CHAT_FONT_SIZE
    local tabSize = db.TabFontSize or DEFAULT_TAB_FONT_SIZE

    -- Update editbox fonts
    if ChatFrame1EditBox then
        ChatFrame1EditBox:SetFont(font, editBoxSize, outline)
        ChatFrame1EditBox:SetShadowOffset(0, 0)
    end
    if ChatFrame1EditBoxHeader then
        ChatFrame1EditBoxHeader:SetFont(font, editBoxSize, outline)
        ChatFrame1EditBoxHeader:SetShadowOffset(0, 0)
    end

    -- Update chat frame and tab fonts
    for i = 1, 20 do
        local chatFrame = _G["ChatFrame" .. i]
        local chatTab = _G["ChatFrame" .. i .. "Tab"]

        if not chatFrame then break end

        if chatFrame._nrsknSkinned then
            chatFrame:SetFont(font, chatSize, outline)
            chatFrame:SetShadowOffset(0, 0)
        end

        if chatTab and chatTab.Text then
            chatTab.Text:SetFont(font, tabSize, outline)
            chatTab.Text:SetShadowOffset(0, 0)
        end
    end
end

-- Main update function (called from GUI)
function CHAT:Update()
    self:UpdateBackdrop()
    self:UpdateFonts()
    self:UpdateEditBox()
    self:UpdateTabColors()
end

-- Function to modify scrolling
local function onChatScroll(chatFrame, direction)
    if direction > 0 then
        if IsShiftKeyDown() then
            chatFrame:ScrollToTop()
        elseif IsControlKeyDown() then
            chatFrame:PageUp()
        else
            chatFrame:ScrollUp()
        end
    else
        if IsShiftKeyDown() then
            chatFrame:ScrollToBottom()
        elseif IsControlKeyDown() then
            chatFrame:PageDown()
        else
            chatFrame:ScrollDown()
        end
    end
end

-- Tab color update
updateTabColor = function(tabIndex)
    local tab = _G['ChatFrame' .. tabIndex .. 'Tab']
    local chatFrame = _G['ChatFrame' .. tabIndex]

    local isWhisper = chatFrame and chatFrame.chatType
        and (chatFrame.chatType == "WHISPER" or chatFrame.chatType == "BN_WHISPER")

    local isSelected = tabIndex == SELECTED_CHAT_FRAME:GetID()

    originalSetAlpha(tab, isSelected and TAB_ACTIVE_ALPHA or TAB_INACTIVE_ALPHA)

    if chatTabAlerts[tabIndex] then
        SetTextColor(tab.Text, GetTabColor("alert"))
    elseif isSelected then
        SetTextColor(tab.Text, GetTabColor("active"))
    elseif isWhisper then
        SetTextColor(tab.Text, GetTabColor("whisper"))
    else
        SetTextColor(tab.Text, GetTabColor("inactive"))
    end
end

-- Setup custom chat friend button
local function SetupChatButtons()
    local friendButton = NRSKNUI:CreateButtonFrame(CHAT.backdrop, 25, 30, "NRSKNUI_ChatFriendButton", {
        text = true,
        btnPoint = "TOPLEFT",
        btnOffset = { 0, 31 },
    })
    friendButton:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    friendButton:SetAlpha(0)

    local function UpdateFriendText()
        friendButton:SetButtonText(QuickJoinToastButton.FriendCount:GetText())
    end

    UpdateFriendText()
    hooksecurefunc(QuickJoinToastButton.FriendCount, "SetText", UpdateFriendText)
    friendButton:SetScript("OnClick", function()
        QuickJoinToastButton:Click()
    end)

    friendButton:SetScript("OnEnter", function()
        UIFrameFadeIn(friendButton, 0.2, friendButton:GetAlpha(), 1)
    end)

    friendButton:SetScript("OnLeave", function(self)
        if not self:IsMouseOver() then
            C_Timer.After(3, function()
                UIFrameFadeOut(friendButton, 3, friendButton:GetAlpha(), 0)
            end)
        end
    end)

    CHAT.friendButton = friendButton
end

-- On tab click function
local function onTabClick(chatTab)
    if chatTabAlerts[chatTab:GetID()] then
        chatTabAlerts[chatTab:GetID()] = false
    end

    for _, tabIndex in next, chatTabIndices do
        updateTabColor(tabIndex)
    end
end

function NRSKNUI:AlertChatTab(tabIndex)
    chatTabAlerts[tabIndex] = true
    updateTabColor(tabIndex)
end

-- Shared tab skinning helper to avoid code duplication
local function SkinChatTab(chatTab, chatIndex, font, outline, tabSize, isSpecialTab)
    if chatTab._nrsknSkinned then return end

    chatTab.Text:SetFont(font, tabSize, outline)
    chatTab.Text:SetShadowOffset(0, 0)

    -- Special tabs that needs word wrap disabled
    if isSpecialTab then
        chatTab.Text:SetWordWrap(false)
        chatTab.Text:SetNonSpaceWrap(false)
    else
        -- Regular tabs, disable middle-click and dragging
        chatTab:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
        chatTab:RegisterForDrag()
    end

    -- Hook events for tabs
    chatTab:HookScript('OnEnter', GenerateClosure(updateTabColor, chatIndex))
    chatTab:HookScript('OnLeave', GenerateClosure(updateTabColor, chatIndex))
    chatTab:HookScript('PostClick', onTabClick)

    -- Track modified tabs
    if not tContains(chatTabIndices, chatIndex) then
        chatTabIndices:insert(chatIndex)
    end

    -- Prevent Blizzard from coloring the tabs
    chatTab.Text.SetTextColor = nop

    -- Override SetAlpha to ignore Blizzard's fade system
    chatTab.SetAlpha = function(self)
        local isSelected = chatIndex == SELECTED_CHAT_FRAME:GetID()
        originalSetAlpha(self, isSelected and TAB_ACTIVE_ALPHA or TAB_INACTIVE_ALPHA)
    end

    chatTab._nrsknSkinned = true
end

-- Hide editbox textures
local function HideEditBoxTextures(editBox)
    local frameName = editBox:GetName()
    local textures = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }
    for _, textureName in ipairs(textures) do
        local texture = editBox[textureName] or (frameName and _G[frameName .. textureName])
        if texture then
            texture:SetTexture(0)
        end
    end
end

local setupPending = false
local function SetupAndSkinChat()
    if setupPending then return end
    setupPending = true
    C_Timer.After(0, function()
        setupPending = false
    end)

    -- Cache font settings
    local db = CHAT.db
    local font = NRSKNUI:GetFontPath(db.FontFace) or NRSKNUI.FONT
    local outline = db.FontOutline or "OUTLINE"
    local chatSize = db.ChatFontSize or DEFAULT_CHAT_FONT_SIZE
    local tabSize = db.TabFontSize or DEFAULT_TAB_FONT_SIZE
    local editBoxSize = db.EditBoxFontSize or DEFAULT_EDITBOX_FONT_SIZE

    -- Ensure dock manager is positioned to our backdrop
    if GeneralDockManager and CHAT.backdrop then
        GeneralDockManager:ClearAllPoints()
        GeneralDockManager:SetPoint("BOTTOMLEFT", CHAT.backdrop, "TOPLEFT", 0, -TAB_AREA_HEIGHT)
        GeneralDockManager:SetPoint("BOTTOMRIGHT", CHAT.backdrop, "TOPRIGHT", 0, -TAB_AREA_HEIGHT)
    end

    -- Enable chat channel stickiness
    ChatTypeInfo.CHANNEL.sticky = 1
    ChatTypeInfo.WHISPER.sticky = 1
    ChatTypeInfo.BN_WHISPER.sticky = 1

    -- Disable default flash tab logic
    if not CHAT._flashDisabled then
        for chatType in next, ChatTypeInfo do
            ChatTypeInfo[chatType].flashTab = false
        end
        CHAT._flashDisabled = true
    end

    -- Override fade behavior cuz blizz fade uggly and buggy
    if not CHAT._fadeHooksInstalled then
        hooksecurefunc("FCF_FadeOutChatFrame", function(chatFrame)
            local frameName = chatFrame:GetName()

            for _, value in pairs(CHAT_FRAME_TEXTURES) do
                local object = _G[frameName .. value]
                if object and object:IsShown() then
                    UIFrameFadeRemoveFrame(object)
                    object:SetAlpha(0)
                end
            end

            if chatFrame == FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) then
                if GENERAL_CHAT_DOCK.overflowButton:IsShown() then
                    UIFrameFadeRemoveFrame(GENERAL_CHAT_DOCK.overflowButton)
                    GENERAL_CHAT_DOCK.overflowButton:SetAlpha(1)
                end
            end

            local chatTab = _G[frameName .. "Tab"]
            UIFrameFadeRemoveFrame(chatTab)
            local isSelected = chatFrame:GetID() == SELECTED_CHAT_FRAME:GetID()
            originalSetAlpha(chatTab, isSelected and TAB_ACTIVE_ALPHA or TAB_INACTIVE_ALPHA)

            if not chatFrame.isDocked then
                UIFrameFadeRemoveFrame(chatFrame.buttonFrame)
                chatFrame.buttonFrame:SetAlpha(0.2)
            end
        end)

        hooksecurefunc("FCFTab_UpdateAlpha", function(chatFrame)
            local chatTab = _G[chatFrame:GetName() .. "Tab"]
            UIFrameFadeRemoveFrame(chatTab)
            local isSelected = chatFrame:GetID() == SELECTED_CHAT_FRAME:GetID()
            originalSetAlpha(chatTab, isSelected and TAB_ACTIVE_ALPHA or TAB_INACTIVE_ALPHA)
        end)

        CHAT._fadeHooksInstalled = true
    end

    -- Set initial alpha for all tabs
    for i = 1, NUM_CHAT_WINDOWS do
        local chatTab = _G[("ChatFrame%dTab"):format(i)]
        if chatTab then
            local isSelected = i == SELECTED_CHAT_FRAME:GetID()
            originalSetAlpha(chatTab, isSelected and TAB_ACTIVE_ALPHA or TAB_INACTIVE_ALPHA)
        end
    end

    -- Remove realm name filter
    if not CHAT._realmFilterInstalled then
        local function RemoveCurrentRealmName(self, event, msg, author, ...)
            local realmName = string.gsub(GetRealmName(), " ", "")
            if msg:find("-" .. realmName) then
                return false, gsub(msg, "%-" .. realmName, ""), author, ...
            end
        end
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", RemoveCurrentRealmName)
        CHAT._realmFilterInstalled = true
    end

    -- Hide chat background textures
    if not CHAT._texturesHidden then
        for _, value in ipairs(CHAT_FRAME_TEXTURES) do
            for i = 1, NUM_CHAT_WINDOWS do
                local tex = _G["ChatFrame" .. i .. value]
                if tex then
                    tex:Hide()
                    tex.Show = nop
                    ---@diagnostic disable-next-line: redundant-parameter
                    tex:SetAlpha(0)
                    tex.SetAlpha = nop
                end
            end
        end

        -- Hide chat button and textures
        NRSKNUI:Hide('QuickJoinToastButton')
        NRSKNUI:Hide('ChatFrameChannelButton')
        NRSKNUI:Hide('ChatFrameMenuButton')
        NRSKNUI:Hide('ChatFrame1EditBoxMid')
        NRSKNUI:Hide('ChatFrame1EditBoxLeft')
        NRSKNUI:Hide('ChatFrame1EditBoxRight')

        CHAT._texturesHidden = true
    end

    -- Iterate through all possible chat frames
    for chatIndex = 1, 12 do
        local chatFrame = _G['ChatFrame' .. chatIndex]
        local chatTab = _G['ChatFrame' .. chatIndex .. 'Tab']
        local editBox = _G['ChatFrame' .. chatIndex .. 'EditBox']

        if not chatFrame then break end

        -- Hide scroll to bottom button
        local btn = chatFrame.ScrollToBottomButton
        if btn and not btn._nrsknHidden then
            btn:Hide()
            btn:SetAlpha(0)
            btn:EnableMouse(false)
            btn.Show = nop
            btn._nrsknHidden = true
        end

        -- One-time element setup per chat frame
        if not chatFrame._nrsknElementsHidden then
            NRSKNUI:Hide(chatFrame, 'buttonFrame')
            NRSKNUI:Hide(chatFrame, 'ScrollBar')

            HideEditBoxTextures(editBox)

            -- Create editbox backdrop
            if not CHAT.backdrops[editBox] then
                local editBoxDB = db.EditBox or {}
                local bgColor = editBoxDB.BackdropColor or { 0, 0, 0, 0.8 }
                local borderColor = editBoxDB.BorderColor or { 0, 0, 0, 1 }
                local backdrop = CHAT:CreateEditBoxBackdrop(editBox, bgColor[4], 0, 5)
                backdrop:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
                backdrop:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            end

            -- Hide all chat frame regions
            for _, region in next, { chatFrame:GetRegions() } do
                NRSKNUI:Hide(region)
            end

            -- Hide all chat tab textures
            for _, region in next, { chatTab:GetRegions() } do
                if region:GetObjectType() == 'Texture' then
                    region:SetTexture(nil)
                end
            end

            chatFrame._nrsknElementsHidden = true
        end

        -- Set editbox font
        if chatIndex == 1 and not CHAT._editBoxFontSet then
            ChatFrame1EditBox:SetFont(font, editBoxSize, outline)
            ChatFrame1EditBox:SetShadowOffset(0, 0)
            ChatFrame1EditBoxHeader:SetFont(font, editBoxSize, outline)
            ChatFrame1EditBoxHeader:SetShadowOffset(0, 0)
            CHAT._editBoxFontSet = true
        end

        -- Handle regular chat frames
        if chatIndex ~= 2 and chatIndex ~= 3 then
            -- Check if frame is actually docked
            local isActuallyDocked = chatFrame.isDocked
            if isActuallyDocked and GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES then
                isActuallyDocked = tContains(GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES, chatFrame)
            end

            if isActuallyDocked then
                pcall(chatFrame.SetClampedToScreen, chatFrame, false)
                chatFrame:SetMovable(true)
                chatFrame:SetUserPlaced(true)

                local function LockPosition(f)
                    if f._nrsknLocking then return end
                    f._nrsknLocking = true
                    f:ClearAllPoints()
                    f:SetPoint("TOPLEFT", CHAT.backdrop, "TOPLEFT", 1, -TAB_AREA_HEIGHT)
                    f:SetPoint("BOTTOMRIGHT", CHAT.backdrop, "BOTTOMRIGHT", -1, 1)
                    f._nrsknLocking = nil
                end

                LockPosition(chatFrame)

                if not chatFrame._nrsknPosHooked then
                    hooksecurefunc(chatFrame, "SetPoint", LockPosition)
                    chatFrame._nrsknPosHooked = true
                end

                editBox:ClearAllPoints()
                editBox:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", -1, 4)
                editBox:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", 1, 4)
            end

            -- Skin chat frame
            if not chatFrame._nrsknSkinned then
                chatFrame:SetMaxLines(10000)
                chatFrame:SetScript('OnMouseWheel', onChatScroll)
                chatFrame:SetFont(font, chatSize, outline)
                chatFrame:SetShadowOffset(0, 0)

                if chatFrame.editBox then
                    chatFrame.editBox:SetAltArrowKeyMode(false)
                end

                chatFrame._nrsknSkinned = true
            end

            -- Skin tab using shared helper
            SkinChatTab(chatTab, chatIndex, font, outline, tabSize, false)
            updateTabColor(chatIndex)
        elseif chatIndex == 2 then
            chatFrame:ClearAllPoints()
            chatFrame:SetPoint("TOPLEFT", CHAT.backdrop, "TOPLEFT", 1, -TAB_AREA_HEIGHT)
            chatFrame:SetPoint("BOTTOMRIGHT", CHAT.backdrop, "BOTTOMRIGHT", -1, 1)

            if CombatLogQuickButtonFrame_Custom then
                CombatLogQuickButtonFrame_Custom:ClearAllPoints()
                CombatLogQuickButtonFrame_Custom:SetPoint("TOPLEFT", CHAT.backdrop, "TOPLEFT", 1, -24)
                CombatLogQuickButtonFrame_Custom:SetPoint("TOPRIGHT", CHAT.backdrop, "TOPRIGHT", -1, -24)
            end

            SkinChatTab(chatTab, chatIndex, font, outline, tabSize, true)
            updateTabColor(chatIndex)
        elseif chatIndex == 3 then
            SkinChatTab(chatTab, chatIndex, font, outline, tabSize, true)
            updateTabColor(chatIndex)
        end
    end
end

-- Remove chat from Edit Mode
local function DisableChatEditMode()
    if GeneralDockManager then
        GeneralDockManager.SetIsInEditMode = nop
        GeneralDockManager.OnEditModeEnter = nop
        GeneralDockManager.OnEditModeExit = nop
        GeneralDockManager.HasActiveChanges = nop
        GeneralDockManager.HighlightSystem = nop
        GeneralDockManager.SelectSystem = nop

        if GeneralDockManager.EditModeSelectionFrame then
            GeneralDockManager.EditModeSelectionFrame:Hide()
            GeneralDockManager.EditModeSelectionFrame:SetParent(nil)
            GeneralDockManager.EditModeSelectionFrame = nil
        end
        if GeneralDockManager.Selection then
            GeneralDockManager.Selection:Hide()
            GeneralDockManager.Selection:SetParent(nil)
            GeneralDockManager.Selection = nil
        end
        if GeneralDockManager.snappedFrames then
            GeneralDockManager.snappedFrames = {}
        end
        GeneralDockManager.system = nil
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame then
            chatFrame.SetIsInEditMode = nop
            chatFrame.OnEditModeEnter = nop
            chatFrame.OnEditModeExit = nop
            chatFrame.HasActiveChanges = nop
            chatFrame.HighlightSystem = nop
            chatFrame.SelectSystem = nop

            if chatFrame.EditModeSelectionFrame then
                chatFrame.EditModeSelectionFrame:Hide()
                chatFrame.EditModeSelectionFrame:SetParent(nil)
                chatFrame.EditModeSelectionFrame = nil
            end
            if chatFrame.Selection then
                chatFrame.Selection:Hide()
                chatFrame.Selection:SetParent(nil)
                chatFrame.Selection = nil
            end
            chatFrame.system = nil
        end
    end

    if EditModeManagerFrame then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
            C_Timer.After(0.1, SetupAndSkinChat)
        end)
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            C_Timer.After(0.1, SetupAndSkinChat)
            C_Timer.After(0.3, SetupAndSkinChat)
            C_Timer.After(0.5, SetupAndSkinChat)
        end)
    end
end

-- Create theme colored clickable links in chat
local function SetupChatLinks()
    local patterns = {
        "(https://%S+%.%S+)",
        "(http://%S+%.%S+)",
        "(www%.%S+%.%S+)",
        "(%d+%.%d+%.%d+%.%d+:?%d*/?%S*)"
    }

    local chatEvents = {
        "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
        "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
        "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM"
    }

    for _, event in ipairs(chatEvents) do
        ChatFrame_AddMessageEventFilter(event, function(_, _, str, ...)
            for _, pattern in ipairs(patterns) do
                local result, match = string.gsub(str, pattern, NRSKNUI:ColorTextByTheme("|Hurl:%1|h[%1]|h"))
                if match > 0 then
                    return false, result, ...
                end
            end
        end)
    end

    local SetHyperlink = _G.ItemRefTooltip.SetHyperlink --[[@as function]]
    function _G.ItemRefTooltip:SetHyperlink(link, ...)
        if link and (strsub(link, 1, 3) == "url") then
            local editbox = ChatEdit_ChooseBoxForSend()
            ChatEdit_ActivateChat(editbox)
            editbox:Insert(string.sub(link, 5))
            editbox:HighlightText()
            return
        end
        SetHyperlink(self, link, ...)
    end
end

-- Module OnEnable
function CHAT:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end -- Skip if ElvUI is loaded, to avoid conflicts
    if not self.db.Enabled then return end

    self:CreateChatBackDrop()
    DisableChatEditMode()

    -- Initial setup with delay
    C_Timer.After(0.1, function()
        SetupAndSkinChat()
        SetupChatLinks()
        SetupChatButtons()
        C_Timer.After(0.2, SetupAndSkinChat)
    end)

    -- Hook for temporary chat windows
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
        for i = 1, NUM_CHAT_WINDOWS do
            local frame = _G["ChatFrame" .. i]
            if frame and frame.isTemporary and not frame.isDocked then
                FCF_DockFrame(frame, #GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES + 1, true)
            end
        end
        FCF_DockUpdate()
        SetupAndSkinChat()
    end)

    -- Lightweight tab color updater
    local function UpdateAllTabColors()
        for _, tabIndex in next, chatTabIndices do
            updateTabColor(tabIndex)
        end
    end

    -- Setup hooks
    hooksecurefunc("FCF_OpenNewWindow", SetupAndSkinChat)
    hooksecurefunc("FCF_SelectDockFrame", UpdateAllTabColors)
    hooksecurefunc("FCF_UnDockFrame", SetupAndSkinChat)
    hooksecurefunc("FCF_DockFrame", SetupAndSkinChat)
    hooksecurefunc("FCF_SetWindowName", SetupAndSkinChat)
    hooksecurefunc("FCF_RestorePositionAndDimensions", SetupAndSkinChat)
    hooksecurefunc("FCFTab_UpdateColors", UpdateAllTabColors)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0.1, SetupAndSkinChat)
    end)

    -- Register with custom edit mode
    local config = {
        key = "ChatModule",
        displayName = "Chat",
        frame = self.backdrop,
        getPosition = function()
            return self.db.Position
        end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom = pos.AnchorFrom
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.XOffset = pos.XOffset
            self.db.Position.YOffset = pos.YOffset

            self.backdrop:ClearAllPoints()
            self.backdrop:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset, pos.YOffset)
        end,
        getParentFrame = function()
            return UIParent
        end,
        guiPath = "Chat",
    }
    NRSKNUI.EditMode:RegisterElement(config)
end

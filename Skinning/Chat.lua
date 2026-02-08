-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("Chat: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local CHAT = NRSKNUI.Addon:NewModule("Chat", "AceEvent-3.0")

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

-- Helper to get tab colors from database
local function GetTabColor(colorType)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.Chat
    local tabColors = db and db.TabColors or {}
    if colorType == "alert" then
        local c = tabColors.AlertColor or { 1, 0, 0, 1 }
        return c[1], c[2], c[3], c[4] or 1
    elseif colorType == "active" then
        local c = tabColors.ActiveColor or { 1, 1, 1, 1 }
        return c[1], c[2], c[3], c[4] or 1
    elseif colorType == "whisper" then
        local c = tabColors.WhisperColor or { 1, 0.5, 0.8, 1 }
        return c[1], c[2], c[3], c[4] or 1
    elseif colorType == "inactive" then
        local colorMode = tabColors.InactiveColorMode or "custom"
        local customColor = tabColors.InactiveColor or { 0.898, 0.063, 0.224, 1 }
        -- Use NRSKNUI:GetAccentColor for theme/class support
        if NRSKNUI.GetAccentColor then
            return NRSKNUI:GetAccentColor(colorMode, customColor)
        else
            return customColor[1], customColor[2], customColor[3], customColor[4] or 1
        end
    end

    return 1, 1, 1, 1
end

-- Store handled edit boxes
local EDIT_BOX_TEXTURES = {
    "Left",
    "Mid",
    "Right",
    "FocusLeft",
    "FocusMid",
    "FocusRight",
}

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

-- Hide specified textures on a frame and store originals
local function HideTextures(frame, textureList)
    local frameName = frame:GetName()
    for _, textureName in ipairs(textureList) do
        local texture = frame[textureName] or (frameName and _G[frameName .. textureName])
        if texture then
            texture:SetTexture(0)
        end
    end
end

-- Backdrop Helpers
local backdropInfo = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
    tile = true,
    tileSize = 16,
    edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

-- Create or update a backdrop for the given parent frame
function CHAT:CreateBackdrop(parent, alpha, xOffset, yOffset)
    local backdrop = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    -- Ensure frame level doesn't go below 0
    local parentLevel = parent:GetFrameLevel()
    backdrop:SetFrameLevel(math.max(0, parentLevel - 1))
    backdrop:SetPoint("TOPLEFT", xOffset or 0, -(yOffset or 0))
    backdrop:SetPoint("BOTTOMRIGHT", -(xOffset or 0), yOffset or 0)
    backdrop:SetBackdrop(backdropInfo)
    backdrop:SetBackdropColor(0, 0, 0, alpha or 0.6)
    backdrop:SetBackdropBorderColor(0, 0, 0, alpha or 0.6)

    -- Store reference for later use
    self.backdrops[parent] = backdrop

    return backdrop
end

-- Create main chat backdrop, we later anchor the chatframe to this backdrop
-- This way i have full control over the chatFrame and can fully disable it in Edit Mode
function CHAT:CreateChatBackDrop()
    local db = self.db
    local bgColor = db.Backdrop and db.Backdrop.Color or { 0, 0, 0, 0.8 }
    local borderColor = db.Backdrop and db.Backdrop.BorderColor or { 0, 0, 0, 1 }
    local backdropEnabled = db.Backdrop and db.Backdrop.Enabled ~= false
    local posDB = db.Position

    local backdrop = CreateFrame("Frame", "ChatBackdrop", UIParent, "BackdropTemplate")
    backdrop:SetWidth(db.Width)
    backdrop:SetHeight(db.Height)
    backdrop:SetPoint(posDB.AnchorFrom, UIParent, posDB.AnchorTo, posDB.XOffset, posDB.YOffset)
    backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })

    -- Apply backdrop color (alpha 0 if disabled so that we can still anchor chatFrame)
    if backdropEnabled then
        backdrop:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    else
        backdrop:SetBackdropColor(0, 0, 0, 0)
    end
    backdrop:SetFrameStrata("BACKGROUND")

    -- Create border container
    local borderFrame = CreateFrame("Frame", nil, backdrop)
    borderFrame:SetAllPoints(backdrop)
    borderFrame:SetFrameLevel(backdrop:GetFrameLevel() + 1)

    -- Border alpha
    local borderAlpha = backdropEnabled and borderColor[4] or 0

    -- Create top border
    local borderTop = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, 0)
    borderTop:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderAlpha)
    borderTop:SetTexelSnappingBias(0)
    borderTop:SetSnapToPixelGrid(false)

    -- Create bottom border
    local borderBottom = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderBottom:SetHeight(1)
    borderBottom:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderAlpha)
    borderBottom:SetTexelSnappingBias(0)
    borderBottom:SetSnapToPixelGrid(false)

    -- Create left border
    local borderLeft = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderLeft:SetWidth(1)
    borderLeft:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, 0)
    borderLeft:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderAlpha)
    borderLeft:SetTexelSnappingBias(0)
    borderLeft:SetSnapToPixelGrid(false)

    -- Create right border
    local borderRight = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderRight:SetWidth(1)
    borderRight:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
    borderRight:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderAlpha)
    borderRight:SetTexelSnappingBias(0)
    borderRight:SetSnapToPixelGrid(false)

    -- Store references
    self.backdrop = backdrop
    self.borders = { borderTop, borderBottom, borderLeft, borderRight }

    -- Position the dock manager (tab container) to our backdrop
    if GeneralDockManager then
        GeneralDockManager:ClearAllPoints()
        GeneralDockManager:SetPoint("BOTTOMLEFT", backdrop, "TOPLEFT", 0, 0)
        GeneralDockManager:SetPoint("BOTTOMRIGHT", backdrop, "TOPRIGHT", 0, 0)
        GeneralDockManager:SetHeight(25)
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

    -- Apply backdrop position (must clear first to avoid multiple anchor points)
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
    if self.borders then
        for _, border in ipairs(self.borders) do
            border:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderAlpha)
        end
    end
end

-- Update editbox backdrops from DB
function CHAT:UpdateEditBox()
    local editBoxDB = self.db.EditBox or {}
    local bgColor = editBoxDB.BackdropColor or { 0, 0, 0, 0.8 }
    local borderColor = editBoxDB.BorderColor or { 0, 0, 0, 1 }

    -- Update all editbox backdrops
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
    local editBoxSize = db.EditBoxFontSize or 13
    local chatSize = db.ChatFontSize or 12
    local tabSize = db.TabFontSize or 12

    -- Update editbox fonts
    if ChatFrame1EditBox then
        ChatFrame1EditBox:SetFont(font, editBoxSize, outline)
        ChatFrame1EditBox:SetShadowOffset(0, 0)
    end
    if ChatFrame1EditBoxHeader then
        ChatFrame1EditBoxHeader:SetFont(font, editBoxSize, outline)
        ChatFrame1EditBoxHeader:SetShadowOffset(0, 0)
    end

    -- Update chat frame and tab fonts (loop through all possible frames including temp windows)
    for i = 1, 20 do
        local chatFrame = _G["ChatFrame" .. i]
        local chatTab = _G["ChatFrame" .. i .. "Tab"]

        if not chatFrame then break end

        -- Update chat frame font if skinned
        if chatFrame._nrsknSkinned then
            chatFrame:SetFont(font, chatSize, outline)
            chatFrame:SetShadowOffset(0, 0)
        end

        -- Update tab font (including whisper tabs that may have been created after initial setup)
        if chatTab and chatTab.Text then
            chatTab.Text:SetFont(font, tabSize, outline)
            chatTab.Text:SetShadowOffset(0, 0)
            -- Let Blizzard handle tab sizing, don't modify width here, tried to do that but was very scuffy :))
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

    -- Check if this is a whisper frame
    local isWhisper = false
    if chatFrame and chatFrame.chatType then
        isWhisper = chatFrame.chatType == "WHISPER" or chatFrame.chatType == "BN_WHISPER"
    end

    local isSelected = tabIndex == SELECTED_CHAT_FRAME:GetID()

    -- Set alpha: 1.0 for selected, 0.6 for non-selected (use original to bypass our override)
    originalSetAlpha(tab, isSelected and 1 or 0.6)

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

-- On tab click function
local function onTabClick(chatTab)
    -- clear alert when selecting tab
    if chatTabAlerts[chatTab:GetID()] then
        chatTabAlerts[chatTab:GetID()] = false
    end

    -- update all tabs to ensure other tabs aren't colored as selected too
    for _, tabIndex in next, chatTabIndices do
        updateTabColor(tabIndex)
    end
end
function NRSKNUI:AlertChatTab(tabIndex)
    chatTabAlerts[tabIndex] = true
    updateTabColor(tabIndex)
end

local setupPending = false
local function SetupAndSkinChat()
    -- Debouncer, if already pending, skip this call
    if setupPending then return end
    setupPending = true
    C_Timer.After(0, function()
        setupPending = false
    end)

    -- Ensure dock manager is positioned to our backdrop
    if GeneralDockManager and CHAT.backdrop then
        GeneralDockManager:ClearAllPoints()
        GeneralDockManager:SetPoint("BOTTOMLEFT", CHAT.backdrop, "TOPLEFT", 0, -25)
        GeneralDockManager:SetPoint("BOTTOMRIGHT", CHAT.backdrop, "TOPRIGHT", 0, -25)
    end

    -- Enable chat channel stickiness (remember last used channel)
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

    -- Override fade behavior
    if not CHAT._fadeHooksInstalled then
        hooksecurefunc("FCF_FadeOutChatFrame", function(chatFrame)
            local frameName = chatFrame:GetName()

            -- Hide chat frame textures/background
            for index, value in pairs(CHAT_FRAME_TEXTURES) do
                local object = _G[frameName .. value]
                if object and object:IsShown() then
                    UIFrameFadeRemoveFrame(object)
                    object:SetAlpha(0)
                end
            end
            if chatFrame == FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) then
                if GENERAL_CHAT_DOCK.overflowButton:IsShown() then
                    UIFrameFadeRemoveFrame(GENERAL_CHAT_DOCK.overflowButton)
                    -- Keep overflow button visible for tab scrolling
                    GENERAL_CHAT_DOCK.overflowButton:SetAlpha(1)
                end
            end

            -- Remove tab from fade system and set proper alpha
            local chatTab = _G[frameName .. "Tab"]
            UIFrameFadeRemoveFrame(chatTab)
            local isSelected = chatFrame:GetID() == SELECTED_CHAT_FRAME:GetID()
            originalSetAlpha(chatTab, isSelected and 1 or 0.6)

            if not chatFrame.isDocked then
                UIFrameFadeRemoveFrame(chatFrame.buttonFrame)
                chatFrame.buttonFrame:SetAlpha(0.2)
            end
        end)

        -- Kill Blizzard's tab alpha updates cuz its bad
        hooksecurefunc("FCFTab_UpdateAlpha", function(chatFrame)
            local chatTab = _G[chatFrame:GetName() .. "Tab"]
            UIFrameFadeRemoveFrame(chatTab)
            local isSelected = chatFrame:GetID() == SELECTED_CHAT_FRAME:GetID()
            originalSetAlpha(chatTab, isSelected and 1 or 0.6)
        end)

        CHAT._fadeHooksInstalled = true
    end

    -- Set initial alpha for all tabs
    for i = 1, NUM_CHAT_WINDOWS do
        local chatTab = _G[("ChatFrame%dTab"):format(i)]
        if chatTab then
            local isSelected = i == SELECTED_CHAT_FRAME:GetID()
            originalSetAlpha(chatTab, isSelected and 1 or 0.6)
        end
    end

    -- Remove realm name filter
    -- This seems to work scuffy, needs re visit
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

    -- Making the chat background invisible
    if not CHAT._texturesHidden then
        for index, value in ipairs(CHAT_FRAME_TEXTURES) do
            for i = 1, NUM_CHAT_WINDOWS, 1 do
                local tex = _G["ChatFrame" .. i .. value]
                if tex then
                    tex:Hide()
                    tex.Show = nop
                    tex:SetAlpha(0)
                    tex.SetAlpha = nop
                end
            end
        end

        -- hide buttons around the chat frame
        NRSKNUI:Hide('QuickJoinToastButton')
        NRSKNUI:Hide('ChatFrameChannelButton')
        NRSKNUI:Hide('ChatFrameMenuButton')

        -- remove texture around the chat edit box
        NRSKNUI:Hide('ChatFrame1EditBoxMid')
        NRSKNUI:Hide('ChatFrame1EditBoxLeft')
        NRSKNUI:Hide('ChatFrame1EditBoxRight')

        CHAT._texturesHidden = true
    end

    -- Iterate through ALL possible chat frames (not just NUM_CHAT_WINDOWS)
    for chatIndex = 1, 12 do
        local chatFrame = _G['ChatFrame' .. chatIndex]
        local chatTab = _G['ChatFrame' .. chatIndex .. 'Tab']
        local editBox = _G['ChatFrame' .. chatIndex .. 'EditBox']
        if not chatFrame then
            break -- No more frames exist
        end

        local btn = chatFrame.ScrollToBottomButton
        if btn and not btn._nrsknHidden then
            btn:Hide()
            btn:SetAlpha(0)
            btn:EnableMouse(false)
            btn.Show = nop -- Prevent Blizzard from re-showing it
            btn._nrsknHidden = true
        end

        -- One-time setup per chat frame
        if not chatFrame._nrsknElementsHidden then
            -- hide chat scroll bar and buttons
            NRSKNUI:Hide(chatFrame, 'buttonFrame')
            NRSKNUI:Hide(chatFrame, 'ScrollBar')

            -- Hide default textures
            HideTextures(editBox, EDIT_BOX_TEXTURES)

            -- Create backdrop only once per editbox
            if not CHAT.backdrops[editBox] then
                local editBoxDB = CHAT.db.EditBox or {}
                local bgColor = editBoxDB.BackdropColor or { 0, 0, 0, 0.8 }
                local borderColor = editBoxDB.BorderColor or { 0, 0, 0, 1 }
                local backdrop = CHAT:CreateBackdrop(editBox, bgColor[4], 0, 5)
                backdrop:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
                backdrop:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
                CHAT.backdrops[editBox] = backdrop
            end

            -- Hide all chat frame regions (background and such)
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

        -- Change edit box font, only needed for ChatFrame1, same editbox is used for all other tabs
        if chatIndex == 1 and not CHAT._editBoxFontSet then
            local db = CHAT.db
            local font = NRSKNUI:GetFontPath(db.FontFace) or NRSKNUI.FONT
            local outline = db.FontOutline or "OUTLINE"
            local editBoxSize = db.EditBoxFontSize or 13
            ChatFrame1EditBox:SetFont(font, editBoxSize, outline)
            ChatFrame1EditBox:SetShadowOffset(0, 0)
            ChatFrame1EditBoxHeader:SetFont(font, editBoxSize, outline)
            ChatFrame1EditBoxHeader:SetShadowOffset(0, 0)
            CHAT._editBoxFontSet = true
        end

        -- Ignore fully skinning combat log and voice log, we skin the tabs only for these
        if chatIndex ~= 2 and chatIndex ~= 3 then
            -- Only reposition frames that are actually in the dock
            -- Check both isDocked flag AND verify it's in the docked frames list
            local isActuallyDocked = chatFrame.isDocked
            if isActuallyDocked and GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES then
                isActuallyDocked = tContains(GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES, chatFrame)
            end

            if isActuallyDocked then
                -- Tell Blizzard we are managing this, chatframe does wierd snapping otherwise
                pcall(chatFrame.SetClampedToScreen, chatFrame, false)
                chatFrame:SetMovable(true)
                chatFrame:SetUserPlaced(true)

                -- Create the "Lock" function for this specific frame
                local function LockPosition(f)
                    if f._nrsknLocking then return end
                    f._nrsknLocking = true

                    f:ClearAllPoints()
                    f:SetPoint("TOPLEFT", CHAT.backdrop, "TOPLEFT", 1, -25)
                    f:SetPoint("BOTTOMRIGHT", CHAT.backdrop, "BOTTOMRIGHT", -1, 1)

                    f._nrsknLocking = nil
                end

                -- Apply the initial position
                LockPosition(chatFrame)

                -- Hook SetPoint so if Blizzard tries to move it, we move it back instantly
                if not chatFrame._nrsknPosHooked then
                    hooksecurefunc(chatFrame, "SetPoint", LockPosition)
                    chatFrame._nrsknPosHooked = true
                end

                -- Position the EditBox
                editBox:ClearAllPoints()
                editBox:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", -1, 4)
                editBox:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", 1, 4)
            end
            -- Only skin once per frame
            if not chatFrame._nrsknSkinned then
                local db = CHAT.db
                local font = NRSKNUI:GetFontPath(db.FontFace) or NRSKNUI.FONT
                local outline = db.FontOutline or "OUTLINE"
                local chatSize = db.ChatFontSize or 12

                -- Increase chat history
                chatFrame:SetMaxLines(10000)

                -- Enable faster chat history scrolling
                chatFrame:SetScript('OnMouseWheel', onChatScroll)

                -- Change chat font
                chatFrame:SetFont(font, chatSize, outline)
                chatFrame:SetShadowOffset(0, 0)

                -- Don't require holding alt key to navigate editbox
                if chatFrame.editBox then
                    chatFrame.editBox:SetAltArrowKeyMode(false)
                end

                chatFrame._nrsknSkinned = true
            end

            -- Check if this is a whisper tab, for color purposes
            local isWhisper = chatFrame.chatType == "WHISPER" or chatFrame.chatType == "BN_WHISPER"
            chatTab._isWhisperTab = isWhisper

            -- Only skin once per tab
            if not chatTab._nrsknSkinned then
                -- Change chat tab font
                local tabFont = NRSKNUI:GetFontPath(CHAT.db.FontFace) or NRSKNUI.FONT
                local tabOutline = CHAT.db.FontOutline or "OUTLINE"
                local tabSize = CHAT.db.TabFontSize or 12
                chatTab.Text:SetFont(tabFont, tabSize, tabOutline)
                chatTab.Text:SetShadowOffset(0, 0)

                -- Disable middle-click on tabs
                chatTab:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

                -- Disable dragging tabs
                chatTab:RegisterForDrag()

                -- Hook events for tabs
                chatTab:HookScript('OnEnter', GenerateClosure(updateTabColor, chatIndex))
                chatTab:HookScript('OnLeave', GenerateClosure(updateTabColor, chatIndex))
                chatTab:HookScript('PostClick', onTabClick)

                -- Keep track of the tabs we modify
                if not tContains(chatTabIndices, chatIndex) then
                    chatTabIndices:insert(chatIndex)
                end

                -- Prevent Blizzard from coloring the tabs
                chatTab.Text.SetTextColor = nop

                -- Override SetAlpha to ignore Blizzard's fade system
                chatTab.SetAlpha = function(self)
                    local isSelected = chatIndex == SELECTED_CHAT_FRAME:GetID()
                    originalSetAlpha(self, isSelected and 1 or 0.6)
                end

                chatTab._nrsknSkinned = true
            end

            -- Always update tab color
            updateTabColor(chatIndex)
        elseif chatIndex == 2 then
            -- Position combat log to fit within backdrop
            chatFrame:ClearAllPoints()
            chatFrame:SetPoint("TOPLEFT", CHAT.backdrop, "TOPLEFT", 1, -25)
            chatFrame:SetPoint("BOTTOMRIGHT", CHAT.backdrop, "BOTTOMRIGHT", -1, 1)

            -- Also constrain the combat log quick button frame (My Actions / What happened to me bar)
            if CombatLogQuickButtonFrame_Custom then
                CombatLogQuickButtonFrame_Custom:ClearAllPoints()
                CombatLogQuickButtonFrame_Custom:SetPoint("TOPLEFT", CHAT.backdrop, "TOPLEFT", 1, -24)
                CombatLogQuickButtonFrame_Custom:SetPoint("TOPRIGHT", CHAT.backdrop, "TOPRIGHT", -1, -24)
            end

            if not chatTab._nrsknSkinned then
                local tabFont = NRSKNUI:GetFontPath(CHAT.db.FontFace) or NRSKNUI.FONT
                local tabOutline = CHAT.db.FontOutline or "OUTLINE"
                local tabSize = CHAT.db.TabFontSize or 12
                chatTab.Text:SetFont(tabFont, tabSize, tabOutline)
                chatTab.Text:SetShadowOffset(0, 0)

                -- Combat log is never a whisper tab, prevent truncation
                chatTab._isWhisperTab = false
                chatTab.Text:SetWordWrap(false)
                chatTab.Text:SetNonSpaceWrap(false)

                -- Hook events for tabs
                chatTab:HookScript('OnEnter', GenerateClosure(updateTabColor, chatIndex))
                chatTab:HookScript('OnLeave', GenerateClosure(updateTabColor, chatIndex))
                chatTab:HookScript('PostClick', onTabClick)

                -- Add to indices so it can be updated
                if not tContains(chatTabIndices, chatIndex) then
                    chatTabIndices:insert(chatIndex)
                end

                -- Prevent Blizzard from coloring the tabs
                chatTab.Text.SetTextColor = nop

                -- Override SetAlpha to ignore Blizzard's fade system
                chatTab.SetAlpha = function(self)
                    local isSelected = chatIndex == SELECTED_CHAT_FRAME:GetID()
                    originalSetAlpha(self, isSelected and 1 or 0.6)
                end

                chatTab._nrsknSkinned = true
            end

            updateTabColor(chatIndex)
        elseif chatIndex == 3 then -- Some other addons i looked at did this, never actually seen voice log tab but w/e
            -- Voice log tab - just skin the tab
            if not chatTab._nrsknSkinned then
                local tabFont = NRSKNUI:GetFontPath(CHAT.db.FontFace) or NRSKNUI.FONT
                local tabOutline = CHAT.db.FontOutline or "OUTLINE"
                local tabSize = CHAT.db.TabFontSize or 12
                chatTab.Text:SetFont(tabFont, tabSize, tabOutline)
                chatTab.Text:SetShadowOffset(0, 0)

                -- Voice log is never a whisper tab, prevent truncation
                chatTab._isWhisperTab = false
                chatTab.Text:SetWordWrap(false)
                chatTab.Text:SetNonSpaceWrap(false)

                chatTab:HookScript('OnEnter', GenerateClosure(updateTabColor, chatIndex))
                chatTab:HookScript('OnLeave', GenerateClosure(updateTabColor, chatIndex))
                chatTab:HookScript('PostClick', onTabClick)

                if not tContains(chatTabIndices, chatIndex) then
                    chatTabIndices:insert(chatIndex)
                end

                chatTab.Text.SetTextColor = nop

                chatTab.SetAlpha = function(self)
                    local isSelected = chatIndex == SELECTED_CHAT_FRAME:GetID()
                    originalSetAlpha(self, isSelected and 1 or 0.6)
                end

                chatTab._nrsknSkinned = true
            end

            updateTabColor(chatIndex)
        end
    end
end

-- Remove chat from Edit Mode and re-apply our settings when Edit Mode changes
-- We have full control over the chat so editmode is not needed
local function DisableChatEditMode()
    -- Remove chat dock from Edit Mode UI
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
        -- Unregister from Edit Mode system
        GeneralDockManager.system = nil
    end

    -- Remove individual chat frames from Edit Mode
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
            -- Unregister from Edit Mode system
            chatFrame.system = nil
        end
    end

    -- Hook to re-apply our settings when Edit Mode enters/exits
    if EditModeManagerFrame then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
            C_Timer.After(0.1, SetupAndSkinChat)
        end)
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            -- Multiple passes to catch Blizzard's delayed resets
            C_Timer.After(0.1, SetupAndSkinChat)
            C_Timer.After(0.3, SetupAndSkinChat)
            C_Timer.After(0.5, SetupAndSkinChat)
        end)
    end
end

-- Create a theme colored clickable link in the chat
local function SetupChatLinks()
    -- Clickable links in the chat
    local patterns = {
        "(https://%S+%.%S+)",
        "(http://%S+%.%S+)",
        "(www%.%S+%.%S+)",
        "(%d+%.%d+%.%d+%.%d+:?%d*/?%S*)"
    }
    for _, event in next, {
        "CHAT_MSG_SAY",
        "CHAT_MSG_YELL",
        "CHAT_MSG_WHISPER",
        "CHAT_MSG_WHISPER_INFORM",
        "CHAT_MSG_GUILD",
        "CHAT_MSG_OFFICER",
        "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID",
        "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_RAID_WARNING",
        "CHAT_MSG_INSTANCE_CHAT",
        "CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_BN_WHISPER",
        "CHAT_MSG_BN_WHISPER_INFORM",
        "CHAT_MSG_CHANNEL",
        "CHAT_MSG_SYSTEM"
    } do
        ChatFrame_AddMessageEventFilter(event, function(_, _, str, ...)
            for _, pattern in pairs(patterns) do
                local result, match = string.gsub(str, pattern, NRSKNUI:ColorTextByTheme("|Hurl:%1|h[%1]|h"))
                if match > 0 then
                    return false, result, ...
                end
            end
        end)
    end
    local SetHyperlink = _G.ItemRefTooltip.SetHyperlink
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
    if not self.db.Enabled then return end
    CHAT:CreateChatBackDrop()
    -- Disable Edit Mode for chat before setting up
    DisableChatEditMode()

    -- Initial setup with delay to ensure chat frames are ready
    C_Timer.After(0.1, function()
        SetupAndSkinChat()
        SetupChatLinks()
        -- Run again after a short delay to catch any late initialization
        C_Timer.After(0.2, SetupAndSkinChat)
    end)

    -- Hook for when new temporary chat windows are added (like whispers, loot, etc.)
    hooksecurefunc("FCF_OpenTemporaryWindow", function(chatType)
        -- Find and force dock any undocked temporary frames
        for i = 1, NUM_CHAT_WINDOWS do
            local frame = _G["ChatFrame" .. i]
            if frame and frame.isTemporary and not frame.isDocked then
                -- Force dock this frame
                FCF_DockFrame(frame, #GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES + 1, true)
            end
        end
        FCF_DockUpdate()
        SetupAndSkinChat()
    end)

    -- Lightweight function to just update tab colors
    local function UpdateAllTabColors()
        for _, tabIndex in next, chatTabIndices do
            updateTabColor(tabIndex)
        end
    end

    -- Setup hooks
    hooksecurefunc("FCF_OpenNewWindow", function() SetupAndSkinChat() end)
    hooksecurefunc("FCF_SelectDockFrame", function() UpdateAllTabColors() end)
    hooksecurefunc("FCF_UnDockFrame", function() SetupAndSkinChat() end)
    hooksecurefunc("FCF_DockFrame", function() SetupAndSkinChat() end)
    hooksecurefunc("FCF_SetWindowName", function() SetupAndSkinChat() end)
    hooksecurefunc("FCF_RestorePositionAndDimensions", function() SetupAndSkinChat() end)
    hooksecurefunc("FCFTab_UpdateColors", function() UpdateAllTabColors() end)
    hooksecurefunc("FCF_OpenTemporaryWindow", function() SetupAndSkinChat() end)

    local playerEnteringWorld = CreateFrame("Frame")
    playerEnteringWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
    playerEnteringWorld:SetScript("OnEvent", function() C_Timer.After(0.1, SetupAndSkinChat) end)

    -- Register with my custom edit mode
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

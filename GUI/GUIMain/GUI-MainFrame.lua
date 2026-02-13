-- NorskenUI namespace
local _, NRSKNUI = ...
NRSKNUI.GUIFrame = NRSKNUI.GUIFrame or {}
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local addonVersion = NRSKNUI.Version

-- GUI state
NRSKNUI.GUIOpen = false

-- Localization
local pcall = pcall
local select = select
local ShowUIPanel = ShowUIPanel
local table_insert = table.insert
local IsMouseButtonDown = IsMouseButtonDown
local tostring = tostring
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local ReloadUI = ReloadUI
local CreateColor = CreateColor
local print = print
local InCombatLockdown = InCombatLockdown
local _G = _G
local C_AddOns = C_AddOns

-- Sidebar Configuration with collapsible sections
GUIFrame.selectedTab = "systems"
GUIFrame.selectedSidebarItem = nil
GUIFrame.sidebarExpanded = GUIFrame.sidebarExpanded or {}
GUIFrame.SidebarConfig = {
    systems = {
        {
            id = "combat_section",
            type = "header",
            text = "• Combat",
            defaultExpanded = true,
            items = {
                { id = "combatTimer",   text = "Combat Timer" },
                { id = "combatCross",   text = "Combat Cross" },
                { id = "battleRes",     text = "Combat Res" },
                { id = "cursorCircle",  text = "Cursor Circle" },
                { id = "combatMessage", text = "Combat Texts" },
                { id = "PetTexts",      text = "Pet Status Texts" },
                { id = "gateway",       text = "Gateway Alert" },
            }
        },
        {
            id = "custom_section",
            type = "header",
            text = "• Custom Buffs",
            defaultExpanded = true,
            items = {
                { id = "BuffIcons", text = "Buff Icons" },
                { id = "BuffBars",  text = "Buff Bars" },
            }
        },
        {
            id = "qol_section",
            type = "header",
            text = "• Quality of Life",
            defaultExpanded = true,
            items = {
                { id = "Automation",      text = "Automation" },
                { id = "CopyAnything",    text = "Copy Anything" },
                { id = "CooldownStrings", text = "CDM Profile Strings" },
                { id = "whisperSounds",   text = "Whisper Sounds" },
                { id = "DragonRiding",    text = "Dragon Riding UI" },
                { id = "FocusCastbar",    text = "Focus Castbar" },
                { id = "missingBuffs",    text = "Missing Buffs" },
                { id = "XPBar",           text = "XP Bar" },
                { id = "Durability",      text = "Durability Util" },
            }
        },
        {
            id = "skinning_section",
            type = "header",
            text = "• Skinning",
            defaultExpanded = true,
            items = {
                { id = "UICleanup",         text = "General UI Cleanup" },
                { id = "Auras",             text = "Buffs, Debuffs & Externals" },
                { id = "Chat",              text = "Chat" },
                { id = "ActionBars",        text = "Action Bars" },
                { id = "Minimap",           text = "Minimap" },
                { id = "MicroMenu",         text = "Micro Menu" },
                { id = "BlizzardMouseover", text = "Blizzard Mouseover" },
                { id = "messages",          text = "Blizzard Texts" },
                { id = "tooltips",          text = "Tooltips" },
                { id = "DetailsBackdrop",   text = "Details Backdrop" },
            }
        },
        {
            id = "cdm_section",
            type = "header",
            text = "• CDM Enhancements",
            defaultExpanded = true,
            items = {
                { id = "CDM",     text = "Aura Overlay & Fonts" },
                { id = "CDMGlow", text = "Hide Proc Animation" },
            }
        },
    },
}

-- Function to refresh fontstrings, part of pixelperf util
local function RefreshAllFontStrings(frame)
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region:GetObjectType() == "FontString" then
            local text = region:GetText()
            if text then
                region:SetText("")
                region:SetText(text)
            end
        end
    end

    -- Recursively refresh child frames
    for i = 1, frame:GetNumChildren() do
        local child = select(i, frame:GetChildren())
        if child then
            RefreshAllFontStrings(child)
        end
    end
end

-- Create Main Frame
function GUIFrame:CreateMainFrame()
    -- Return existing frame if already created
    if self.MainFrame then
        return self.MainFrame
    end

    -- Main window frame
    local frame = CreateFrame("Frame", "NorskenAurasGUIFrame", UIParent, "BackdropTemplate")
    frame:SetSize(810, 900)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(810, 550)
    frame:EnableMouse(true)

    -- Main frame backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = Theme.borderSize,
    })
    frame:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], Theme.bgDark[4])
    frame:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    -- Create a dummy overlay that allows for dropdown to go beyond scrollframe
    NRSKNUI.GUIOverlay = CreateFrame("Frame", nil, UIParent)
    NRSKNUI.GUIOverlay:SetAllPoints(UIParent)
    NRSKNUI.GUIOverlay:SetFrameStrata("TOOLTIP")
    NRSKNUI.GUIOverlay:SetFrameLevel(1)
    NRSKNUI.GUIOverlay:EnableMouse(false)

    -- Create header and footer
    self:CreateHeader(frame)
    self:CreateFooter(frame)
    self:CreateContentArea(frame)
    self:CreateSidebar(frame)
    self:CreateShortcutFrame(frame)

    -- Create border frame
    local borderFrame = CreateFrame("Frame", nil, frame)
    borderFrame:SetAllPoints(frame)
    borderFrame:SetFrameStrata("TOOLTIP")
    borderFrame:SetFrameLevel(frame:GetFrameLevel() + 100)

    -- Create top borderFrame
    local borderTop = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderTop:SetHeight(Theme.borderSize)
    borderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borderTop:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    frame.borderTop = borderTop

    -- Create bottom borderFrame
    local borderBottom = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderBottom:SetHeight(Theme.borderSize)
    borderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    frame.borderBottom = borderBottom

    -- Create left borderFrame
    local borderLeft = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderLeft:SetWidth(Theme.borderSize)
    borderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    borderLeft:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    frame.borderLeft = borderLeft

    -- Create right borderFrame
    local borderRight = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderRight:SetWidth(Theme.borderSize)
    borderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    borderRight:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    frame.borderRight = borderRight

    -- Store border references
    frame.borderFrame = borderFrame

    -- Close on ESC key
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            GUIFrame:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    frame:EnableKeyboard(true)

    -- Ensure frame is on top when shown
    frame:SetToplevel(true)

    -- Update GUI open state on show/hide
    frame:SetScript("OnHide", function()
        if NRSKNUI.GUIOpen then
            -- Save position on hide
            if GUIFrame.SaveFramePosition then
                GUIFrame:SaveFramePosition()
            end

            -- Save session state
            if GUIFrame.SaveSessionState then
                GUIFrame:SaveSessionState()
            end

            -- Fire content cleanup callbacks
            if GUIFrame.contentCleanupCallbacks then
                for _, callback in pairs(GUIFrame.contentCleanupCallbacks) do
                    pcall(callback)
                end
            end

            -- Fire on-close callbacks
            if GUIFrame.FireOnCloseCallbacks then
                GUIFrame:FireOnCloseCallbacks()
            end

            -- Fire old GUIFactory callbacks for backward compatibility
            local GUIFactory = NRSKNUI.GUIFactory
            if GUIFactory and GUIFactory.FireOnCloseCallbacks then
                GUIFactory:FireOnCloseCallbacks()
            end

            -- Run content cleanup callbacks
            if GUIFrame.contentCleanupCallbacks then
                for _, callback in pairs(GUIFrame.contentCleanupCallbacks) do
                    pcall(callback)
                end
            end

            -- Fire on-close callbacks
            if GUIFrame.FireOnCloseCallbacks then
                GUIFrame:FireOnCloseCallbacks()
            end

            -- Update open state and notify preview manager
            NRSKNUI.GUIOpen = false
            if NRSKNUI.PreviewManager then
                NRSKNUI.PreviewManager:SetGUIOpen(false)
            end
        end
    end)
    -- Initially hidden
    frame:Hide()

    -- Store reference
    self.mainFrame = frame
    return frame
end

-- Helper to apply theme coloring to the GUIFrames
function GUIFrame:ApplyThemeColors()
    if not self.mainFrame then return end
    local frame = self.mainFrame
    local selBg = Theme.selectedBg or Theme.accent
    local selText = Theme.selectedText or Theme.accent

    -- Main frame backdrop
    frame:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], Theme.bgDark[4])
    frame:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    -- Header
    if frame.header then
        frame.header:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])
        -- Update logo colors
        if frame.header.logoN then
            frame.header.logoN:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], Theme.accent[4] or 1)
        end
        if frame.header.logoAuras then
            frame.header.logoAuras:SetVertexColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3], 1)
        end
    end

    -- Sidebar
    if self.sidebar then
        self.sidebar:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])
    end

    -- Update sidebar section headers
    if self.sidebarHeaderPool then
        local r, g, b = Theme.accent[1], Theme.accent[2], Theme.accent[3]
        for _, header in ipairs(self.sidebarHeaderPool) do
            if header.inUse then
                -- Update label color
                if header.label then
                    header.label:SetTextColor(r, g, b, 1)
                end
                -- Update arrow color
                if header.arrow then
                    header.arrow:SetVertexColor(r, g, b, 1)
                end
                -- Update hover background gradient
                if header.background then
                    header.background:SetGradient("HORIZONTAL", CreateColor(0.3, 0.3, 0.3, 0.25),
                        CreateColor(0.3, 0.3, 0.3, 0))
                end
                -- Update selection colors
                if header.selectedOverlay then
                    header.selectedOverlay:SetVertexColor(selBg[1], selBg[2], selBg[3], selBg[4] or 0.25)
                end
                if header.selectedBar then
                    header.selectedBar:SetColorTexture(r, g, b, 1)
                end
            end
        end
    end

    -- Update static sidebar items
    if self.staticSidebarItemPool then
        local r, g, b = Theme.accent[1], Theme.accent[2], Theme.accent[3]
        for _, item in ipairs(self.staticSidebarItemPool) do
            -- Update selection overlay gradient
            if item.selectedOverlay then
                item.selectedOverlay:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.25), CreateColor(r, g, b, 0))
            end
            -- Update hover background gradient
            if item.background then
                item.background:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.25), CreateColor(r, g, b, 0))
            end
            if item.selectedBar then
                item.selectedBar:SetColorTexture(selText[1], selText[2], selText[3], selText[4] or 1)
            end
            -- Update text color based on selection
            if item.inUse then
                if item.id == self.selectedSidebarItem then
                    item.label:SetTextColor(selText[1], selText[2], selText[3], selText[4] or 1)
                else
                    item.label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
                end
            end
        end
    end

    -- Content area
    if frame.content then
        frame.content:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], Theme.bgDark[4])
    end

    -- Footer
    if frame.footer then
        frame.footer:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])
        -- Update Twitch button colors
        if frame.footer.logoTwitchTexture then
            frame.footer.logoTwitchTexture:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.7)
        end
        if frame.footer.logoTwitchText then
            frame.footer.logoTwitchText:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2],
                Theme.textSecondary[3], 0.7)
        end
        -- Update Discord button colors
        if frame.footer.logoDiscordTexture then
            frame.footer.logoDiscordTexture:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.7)
        end
        if frame.footer.logoDiscordText then
            frame.footer.logoDiscordText:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2],
                Theme.textSecondary[3], 0.7)
        end
    end

    -- Shortcut dropdown
    if self.shortcutContent then
        self.shortcutContent:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], 1)
        self.shortcutContent:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    end
    if self.shortcutBtn then
        local tex = self.shortcutBtn:GetNormalTexture()
        if tex then
            tex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        end
    end
    -- Update shortcut item button text colors
    if self.shortcutItemButtons then
        for _, btn in ipairs(self.shortcutItemButtons) do
            -- Find the text fontstring (first child fontstring)
            for i = 1, btn:GetNumRegions() do
                local region = select(i, btn:GetRegions())
                if region and region:GetObjectType() == "FontString" then
                    region:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                    break
                end
            end
        end
    end
    -- Update shortcut scrollbar thumb
    if self.shortcutScrollbarThumb then
        self.shortcutScrollbarThumb:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.8)
    end
    if self.shortcutScrollbarBorder then
        self.shortcutScrollbarBorder:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    end
end

-- Shortcut Frame
function GUIFrame:CreateShortcutFrame(parent)
    -- Configuration
    local ITEM_HEIGHT = 24
    local MAX_DROPDOWN_HEIGHT = 400
    local ANIMATION_DURATION = 0.18

    -- Main shortcut button (always visible, top right outside frame)
    local shortcutBtn = CreateFrame("Button", nil, parent)
    shortcutBtn:SetSize(18, 22)
    shortcutBtn:SetPoint("TOPLEFT", parent, "TOPRIGHT", -50, -6)
    shortcutBtn:SetFrameStrata("TOOLTIP")

    -- Shortcut button texture
    local shortcutBtnTex = shortcutBtn:CreateTexture(nil, "ARTWORK")
    shortcutBtnTex:SetAllPoints()
    shortcutBtnTex:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomBurger.png")
    shortcutBtnTex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    shortcutBtn:SetNormalTexture(shortcutBtnTex)
    shortcutBtnTex:SetTexelSnappingBias(0)
    shortcutBtnTex:SetSnapToPixelGrid(true)

    local dropdownList = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    dropdownList:SetHeight(1)
    dropdownList:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    dropdownList:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], 1)
    dropdownList:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    dropdownList:SetFrameStrata("TOOLTIP")
    dropdownList:SetClipsChildren(true)
    dropdownList:Hide()

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, dropdownList)
    scrollFrame:SetPoint("TOPLEFT", dropdownList, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", dropdownList, "BOTTOMRIGHT", -11, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)

    -- Scrollbar
    local scrollbar = CreateFrame("Slider", nil, dropdownList, "BackdropTemplate")
    scrollbar:SetPoint("TOPRIGHT", dropdownList, "TOPRIGHT", 0, 0)
    scrollbar:SetPoint("BOTTOMRIGHT", dropdownList, "BOTTOMRIGHT", 0, 0)
    scrollbar:SetWidth(12)
    scrollbar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    scrollbar:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    scrollbar:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
    scrollbar:SetOrientation("VERTICAL")
    local pxlPerfStep = NRSKNUI:PixelBestSize()
    scrollbar:SetValueStep(pxlPerfStep)
    scrollbar:SetMinMaxValues(0, 100)
    scrollbar:SetValue(0)
    scrollbar:Hide()

    scrollbar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    scrollbar:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value)
    end)

    local scrollHold = false
    scrollbar:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            scrollHold = true
        end
    end)
    scrollbar:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            C_Timer.After(0.1, function()
                scrollHold = false
            end)
        end
    end)

    local thumb = scrollbar:GetThumbTexture()
    thumb:SetSize(12, 30)
    thumb:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.8)

    local thumbBorder = CreateFrame("Frame", nil, scrollbar, "BackdropTemplate")
    thumbBorder:SetPoint("TOPLEFT", thumb, 0, 0)
    thumbBorder:SetPoint("BOTTOMRIGHT", thumb, 0, 0)
    thumbBorder:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    thumbBorder:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    thumb:HookScript("OnShow", function() thumbBorder:Show() end)
    thumb:HookScript("OnHide", function() thumbBorder:Hide() end)

    -- State tracking
    local isOpen = false
    local itemButtons = {}
    local startHeight = 0
    local targetHeight = 0
    local btnTextR, btnTextG, btnTextB = Theme.accent[1], Theme.accent[2], Theme.accent[3]

    local mouseChecker = CreateFrame("Frame", nil, UIParent)
    mouseChecker:Hide()

    -- Animation setup
    local animGroup = dropdownList:CreateAnimationGroup()
    local heightAnim = animGroup:CreateAnimation("Animation")
    heightAnim:SetDuration(ANIMATION_DURATION)

    -- Hover fade animation for border color
    local hoverAnimGroup = shortcutBtn:CreateAnimationGroup()
    local hoverAnim = hoverAnimGroup:CreateAnimation("Animation")
    hoverAnim:SetDuration(0.15)

    local borderColorFrom = {}
    local borderColorTo = {}

    hoverAnimGroup:SetScript("OnUpdate", function(self)
        local progress = self:GetProgress() or 0
        local r = borderColorFrom.btnTextR + (borderColorTo.btnTextR - borderColorFrom.btnTextR) * progress
        local g = borderColorFrom.btnTextG + (borderColorTo.btnTextG - borderColorFrom.btnTextG) * progress
        local b = borderColorFrom.btnTextB + (borderColorTo.btnTextB - borderColorFrom.btnTextB) * progress

        shortcutBtnTex:SetVertexColor(r, g, b, 1)
        btnTextR, btnTextG, btnTextB = r, g, b
    end)

    hoverAnimGroup:SetScript("OnFinished", function()
        shortcutBtnTex:SetVertexColor(borderColorTo.btnTextR, borderColorTo.btnTextG, borderColorTo.btnTextB, 1)
        btnTextR, btnTextG, btnTextB = borderColorTo.btnTextR, borderColorTo.btnTextG, borderColorTo.btnTextB
    end)

    local function AnimateBorderColor(toAccent)
        hoverAnimGroup:Stop()

        btnTextR, btnTextG, btnTextB = shortcutBtnTex:GetVertexColor()
        borderColorFrom.btnTextR = btnTextR
        borderColorFrom.btnTextG = btnTextG
        borderColorFrom.btnTextB = btnTextB

        if toAccent then
            borderColorTo.btnTextR = Theme.accent[1]
            borderColorTo.btnTextG = Theme.accent[2]
            borderColorTo.btnTextB = Theme.accent[3]
        else
            borderColorTo.btnTextR = Theme.textSecondary[1]
            borderColorTo.btnTextG = Theme.textSecondary[2]
            borderColorTo.btnTextB = Theme.textSecondary[3]
        end

        hoverAnimGroup:Play()
    end

    local function CloseDropdown(instant)
        if scrollHold then return end
        if not isOpen then return end

        isOpen = false

        if instant then
            dropdownList:SetHeight(1)
            dropdownList:Hide()
            animGroup:Stop()
        else
            startHeight = dropdownList:GetHeight()
            targetHeight = 1
            animGroup:Stop()
            animGroup:Play()
        end

        mouseChecker:SetScript("OnUpdate", nil)
        mouseChecker:Hide()
    end

    local function UpdateScroll()
        local contentHeight = scrollChild:GetHeight()
        local scrollFrameHeight = scrollFrame:GetHeight()
        local needsScrollbar = contentHeight > scrollFrameHeight and scrollFrameHeight > 0

        if needsScrollbar then
            scrollbar:Show()
            scrollbar:SetMinMaxValues(0, contentHeight - scrollFrameHeight)
            scrollbar:SetValue(0)
            scrollFrame:SetPoint("BOTTOMRIGHT", dropdownList, "BOTTOMRIGHT", -11, 0)
        else
            scrollbar:Hide()
            scrollbar:SetMinMaxValues(0, 0)
            scrollFrame:SetVerticalScroll(0)
            scrollFrame:SetPoint("BOTTOMRIGHT", dropdownList, "BOTTOMRIGHT", 0, 0)
        end

        scrollChild:SetWidth(scrollFrame:GetWidth())

        for _, btn in ipairs(itemButtons) do
            btn:ClearAllPoints()
            local index = 0
            for i, b in ipairs(itemButtons) do
                if b == btn then
                    index = i - 1
                    break
                end
            end
            btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -index * ITEM_HEIGHT)
            btn:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
        end
    end

    animGroup:SetScript("OnUpdate", function(self)
        local progress = self:GetProgress() or 0
        local smoothProgress = progress * progress * (3 - 2 * progress)
        local newHeight = startHeight + (targetHeight - startHeight) * smoothProgress
        dropdownList:SetHeight(newHeight)

        if isOpen and newHeight < targetHeight then
            dropdownList:SetClipsChildren(false)
        end
    end)

    animGroup:SetScript("OnFinished", function()
        dropdownList:SetHeight(targetHeight)

        if not isOpen then
            dropdownList:Hide()
        else
            dropdownList:SetClipsChildren(true)
        end
    end)

    -- Create shortcut items
    local function CreateItemButtons()
        for _, btn in ipairs(itemButtons) do
            btn:Hide()
            btn:SetParent(nil)
        end
        itemButtons     = {}
        -- Addon logos
        local BCDMLogo  = "|TInterface\\AddOns\\NorskenUI\\Media\\AddonLogos\\Logo.png:16:16|t"
        local UUFLogo   = "|TInterface\\AddOns\\NorskenUI\\Media\\AddonLogos\\Logo:11:12|t"
        local MSLogo    = "|TInterface\\AddOns\\NorskenUI\\Media\\AddonLogos\\MinimapStats.png:16:16|t"

        -- Define shortcuts
        local shortcuts = {
            -- ReloadUI shortcut
            { text = "Reload UI", onClick = function() ReloadUI() end },
            {
                text = "Edit Mode",
                onClick = function()
                    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
                        return
                    end
                    ShowUIPanel(EditModeManagerFrame)
                end
            },
            -- Cooldown Manager shortcut
            {
                text = "Cooldown Manager",
                onClick = function()
                    -- Open Blizzard CooldownViewerSettings
                    local frame = _G["CooldownViewerSettings"]
                    if frame then
                        frame:Show()
                        frame:Raise()
                    else
                        NRSKNUI:Print(
                            "CooldownViewerSettings not found. Make sure Cooldown Manager is enabled in Edit Mode.")
                    end
                end
            },
            -- UnhaltedUnitFrames shortcut
            {
                text = UUFLogo .. " " .. "|cFF8080FFUnhalted|r" .. "|cFFFFFFFFUnitFrames|r",
                onClick = function()
                    local addonName = "UnhaltedUnitFrames"
                    if not C_AddOns.IsAddOnLoaded(addonName) then
                        local loaded, reason = C_AddOns.LoadAddOn(addonName)
                        if not loaded then
                            NRSKNUI:Print("UnhaltedUnitFrames is disabled/missing", reason)
                            return
                        end
                    end
                    if SlashCmdList["UUF"] then
                        SlashCmdList["UUF"]("")
                    else
                        NRSKNUI:Print("UUF command not available.")
                    end
                end
            },
            -- BetterCooldownManager shortcut
            {
                text = BCDMLogo .. " " .. "|cFF8080FFBetter|r" .. "|cFFFFFFFFCooldownManager|r",
                onClick = function()
                    local addonName = "BetterCooldownManager"
                    if not C_AddOns.IsAddOnLoaded(addonName) then
                        local loaded, reason = C_AddOns.LoadAddOn(addonName)
                        if not loaded then
                            NRSKNUI:Print("BetterCooldownManager is disabled/missing", reason)
                            return
                        end
                    end
                    if SlashCmdList["BCDM"] then
                        SlashCmdList["BCDM"]("")
                    else
                        NRSKNUI:Print("BCDM command not available.")
                    end
                end
            },
            -- MinimapStats shortcut
            {
                text = MSLogo .. " " .. "|cFF8080FFMinimap|r" .. "|cFFFFFFFFStats|r",
                onClick = function()
                    local addonName = "MinimapStats"
                    if not C_AddOns.IsAddOnLoaded(addonName) then
                        local loaded, reason = C_AddOns.LoadAddOn(addonName)
                        if not loaded then
                            NRSKNUI:Print("MinimapStats is disabled/missing", reason)
                            return
                        end
                    end
                    if SlashCmdList["MINIMAPSTATS"] then
                        SlashCmdList["MINIMAPSTATS"]("")
                    else
                        NRSKNUI:Print("MS command not available.")
                    end
                end
            },
        }

        for i, item in ipairs(shortcuts) do
            local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            btn:SetHeight(ITEM_HEIGHT)
            btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ITEM_HEIGHT)
            btn:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)

            local btnText = btn:CreateFontString(nil, "OVERLAY")
            btnText:SetPoint("LEFT", btn, "LEFT", 8, 0)
            btnText:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
            btnText:SetJustifyH("LEFT")
            NRSKNUI:ApplyThemeFont(btnText, "normal")
            btnText:SetText(item.text)
            btnText:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3])

            btn:SetScript("OnClick", function()
                item.onClick()
                CloseDropdown()
            end)

            btn:SetScript("OnEnter", function()
                btn:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                })
                btn:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
                btn:SetBackdropColor(Theme.accentHover[1], Theme.accentHover[2], Theme.accentHover[3],
                    Theme.accentHover[4] or 0.25)
                btnText:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3], 1)
            end)

            btn:SetScript("OnLeave", function()
                btn:SetBackdrop(nil)
                btnText:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3])
            end)

            table_insert(itemButtons, btn)
        end

        scrollChild:SetHeight(#shortcuts * ITEM_HEIGHT)

        for _, btn in ipairs(itemButtons) do
            btn:Show()
        end
    end

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        if scrollbar:IsShown() then
            local current = scrollbar:GetValue()
            local minVal, maxVal = scrollbar:GetMinMaxValues()
            local newValue = current - (delta * ITEM_HEIGHT)
            newValue = math.max(minVal, math.min(maxVal, newValue))
            scrollbar:SetValue(newValue)
        end
    end)

    local function ToggleDropdown()
        if isOpen then
            CloseDropdown()
        else
            dropdownList:ClearAllPoints()
            dropdownList:SetPoint("TOP", shortcutBtn, "BOTTOM", 132, 28)
            dropdownList:SetWidth(180)

            local contentHeight = #itemButtons * ITEM_HEIGHT
            local maxHeight = math.min(contentHeight, MAX_DROPDOWN_HEIGHT)

            startHeight = 1
            targetHeight = maxHeight

            dropdownList:SetHeight(targetHeight)
            scrollChild:SetWidth(scrollFrame:GetWidth())
            UpdateScroll()
            dropdownList:Show()
            dropdownList:SetHeight(startHeight)

            isOpen = true

            animGroup:Play()

            shortcutBtnTex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)

            local wasMouseDown = false
            mouseChecker:SetScript("OnUpdate", function()
                local isDown = IsMouseButtonDown("LeftButton")
                if wasMouseDown and not isDown then
                    if not dropdownList:IsMouseOver() and not shortcutBtn:IsMouseOver() then
                        CloseDropdown()
                    end
                end
                wasMouseDown = isDown
            end)
            mouseChecker:Show()
        end
    end

    shortcutBtn:SetScript("OnClick", function()
        --ToggleDropdown()
    end)

    shortcutBtn:SetScript("OnEnter", function()
        AnimateBorderColor(true)
        if not isOpen then
            ToggleDropdown()
        end
    end)

    shortcutBtn:SetScript("OnLeave", function()
        AnimateBorderColor(false)
        C_Timer.After(0.1, function()
            if not dropdownList:IsMouseOver() and not shortcutBtn:IsMouseOver() then
                CloseDropdown()
            end
        end)
    end)

    dropdownList:SetScript("OnLeave", function()
        C_Timer.After(0.1, function()
            if not dropdownList:IsMouseOver() then
                CloseDropdown()
            end
        end)
    end)

    dropdownList:SetScript("OnHide", function()
        if isOpen then
            isOpen = false
        end
    end)

    shortcutBtn:SetScript("OnHide", function()
        CloseDropdown(true)
    end)

    -- Initialize
    dropdownList:Show()
    dropdownList:SetHeight(MAX_DROPDOWN_HEIGHT)
    CreateItemButtons()
    dropdownList:SetHeight(1)
    dropdownList:Hide()

    -- Store references
    self.shortcutBtn = shortcutBtn
    self.shortcutContent = dropdownList
    self.shortcutItemButtons = itemButtons
    self.shortcutScrollbarThumb = thumb
    self.shortcutScrollbarBorder = thumbBorder

    return shortcutBtn
end

-- Create Header
function GUIFrame:CreateHeader(parent)
    -- Header frame
    local header = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    header:SetHeight(Theme.headerHeight)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    -- Header background
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    header:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])

    -- Bottom border
    local bottomBorder = header:CreateTexture(nil, "BORDER")
    bottomBorder:SetHeight(Theme.borderSize)
    bottomBorder:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    bottomBorder:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    bottomBorder:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4])

    -- Logo
    local logoContainer = CreateFrame("Frame", nil, header)
    logoContainer:SetSize(180, 32)
    logoContainer:SetPoint("LEFT", header, "LEFT", Theme.paddingLarge, -1)

    -- "N" logo part
    local logoN = logoContainer:CreateTexture(nil, "ARTWORK")
    logoN:SetSize(64, 64)
    logoN:SetPoint("LEFT", logoContainer, "LEFT", -10, 1)
    logoN:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\Logo\\logocookingsPT1128x128OT.png")
    logoN:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.7)
    logoN:SetTexelSnappingBias(0)
    logoN:SetSnapToPixelGrid(false)

    -- "UI" logo part
    local logoAuras = logoContainer:CreateTexture(nil, "ARTWORK")
    logoAuras:SetSize(128, 128)
    logoAuras:SetPoint("LEFT", logoN, "RIGHT", -62, -4)
    logoAuras:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\Logo\\logocookingsPT3128x128OT.png")
    logoAuras:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    logoAuras:SetTexelSnappingBias(0)
    logoAuras:SetSnapToPixelGrid(false)

    -- Current version text
    local fontPath = "Fonts\\FRIZQT__.TTF"
    local fontSize = Theme.fontSizeSmall or 10
    local currentVersionText = header:CreateFontString(nil, "OVERLAY")
    currentVersionText:SetPoint("LEFT", logoAuras, "RIGHT", -45, -3)
    currentVersionText:SetFont(fontPath, fontSize, "")
    currentVersionText:SetText(addonVersion)
    currentVersionText:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    currentVersionText:SetJustifyH("LEFT")
    currentVersionText:SetShadowColor(0, 0, 0, 0)
    -- Create stacked shadow layers for separator
    header.currentVersionTextShadow = NRSKNUI:CreateSoftOutline(currentVersionText, {
        thickness = 1,
        color = { 0, 0, 0 },
        alpha = 0.9,
    })

    -- Header element references
    header.logoContainer = logoContainer
    header.logoN = logoN
    header.logoAuras = logoAuras
    header.currentVersionText = currentVersionText

    -- Close button
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)

    -- Close button texture
    local closeTex = closeBtn:CreateTexture(nil, "ARTWORK")
    closeTex:SetAllPoints()
    closeTex:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomCrossv3.png")
    closeTex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    closeBtn:SetNormalTexture(closeTex)
    closeTex:SetRotation(math.rad(45))
    closeTex:SetTexelSnappingBias(0)
    closeTex:SetSnapToPixelGrid(true)

    -- Close button scripts
    closeBtn:SetScript("OnEnter", function()
        closeTex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], Theme.accent[4])
    end)
    closeBtn:SetScript("OnLeave", function()
        closeTex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    end)
    closeBtn:SetScript("OnClick", function()
        GUIFrame:Hide()
    end)
    header.closeBtn = closeBtn

    -- Theme button
    local themeBtn = CreateFrame("Button", nil, header)
    themeBtn:SetSize(18, 18)
    themeBtn:SetPoint("RIGHT", header, "RIGHT", -81, 0)

    -- Theme button texture
    local themeTex = themeBtn:CreateTexture(nil, "ARTWORK")
    themeTex:SetAllPoints()
    themeTex:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\fill.png")
    themeTex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    themeBtn:SetNormalTexture(themeTex)
    themeTex:SetTexelSnappingBias(0)
    themeTex:SetSnapToPixelGrid(true)

    -- Theme button scripts
    themeBtn:SetScript("OnEnter", function()
        themeTex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], Theme.accent[4])
    end)
    themeBtn:SetScript("OnLeave", function()
        themeTex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    end)
    themeBtn:SetScript("OnClick", function()
        GUIFrame:OpenPage("ThemePage")
    end)
    header.themeBtn = themeBtn

    -- Settings button
    local settingsBtn = CreateFrame("Button", nil, header)
    settingsBtn:SetSize(18, 18)
    settingsBtn:SetPoint("RIGHT", header, "RIGHT", -56, 0)

    -- Settings button texture
    local settingsTex = settingsBtn:CreateTexture(nil, "ARTWORK")
    settingsTex:SetAllPoints()
    settingsTex:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\HomeButtonv2.png")
    settingsTex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    settingsBtn:SetNormalTexture(settingsTex)
    settingsTex:SetTexelSnappingBias(0)
    settingsTex:SetSnapToPixelGrid(true)

    -- Settings button scripts
    settingsBtn:SetScript("OnEnter", function()
        settingsTex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], Theme.accent[4])
    end)
    settingsBtn:SetScript("OnLeave", function()
        settingsTex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    end)
    settingsBtn:SetScript("OnClick", function()
        GUIFrame:OpenPage("HomePage")
    end)
    header.settingsBtn = settingsBtn

    -- Make header draggable for moving the frame
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        parent:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        NRSKNUI:SnapFrameToPixels(parent)
        GUIFrame:SaveFramePosition()
    end)

    parent.header = header
    return header
end

-- Create Content Area
function GUIFrame:CreateContentArea(parent)
    local content = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    -- Fixed width content area anchored to right edge, leaving room for footer
    content:SetWidth(Theme.contentWidth)
    content:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -Theme.headerHeight)
    content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, Theme.footerHeight)

    -- Content background
    content:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    content:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], Theme.bgDark[4])

    -- Scroll frame for content
    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    local scrollbarWidth = Theme.scrollbarWidth or 16
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

    -- Style the scrollbar thumb
    if scrollFrame.ScrollBar then
        local sb = scrollFrame.ScrollBar
        -- Position scrollbar inside the content area on the right edge
        sb:ClearAllPoints()
        sb:SetPoint("TOPRIGHT", content, "TOPRIGHT", -3, -Theme.paddingSmall - 12)
        sb:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -3, Theme.paddingSmall + 12)
        sb:SetWidth(scrollbarWidth - 4)

        -- Custom scrollbar textures
        if sb.Background then sb.Background:Hide() end
        if sb.Top then sb.Top:Hide() end
        if sb.Middle then sb.Middle:Hide() end
        if sb.Bottom then sb.Bottom:Hide() end
        if sb.trackBG then sb.trackBG:Hide() end
        if sb.ScrollUpButton then sb.ScrollUpButton:Hide() end
        if sb.ScrollDownButton then sb.ScrollDownButton:Hide() end
        -- Hide thumb when not needed
        sb:SetAlpha(0)
    end

    -- Scroll child
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    -- Track scrollbar visibility state
    local scrollbarVisible = false

    -- Update scrollChild width based on scrollbar visibility
    local function UpdateScrollChildWidth()
        local baseWidth = Theme.contentWidth
        if scrollbarVisible then
            scrollChild:SetWidth(baseWidth - scrollbarWidth)
        else
            scrollChild:SetWidth(baseWidth)
        end
    end

    -- Show/hide scrollbar and adjust content width based on content height
    local function UpdateScrollBarVisibility()
        if scrollFrame.ScrollBar then
            local contentHeight = scrollChild:GetHeight()
            local frameHeight = scrollFrame:GetHeight()
            local needsScrollbar = contentHeight > frameHeight

            -- Always update visibility, don't track state
            scrollbarVisible = needsScrollbar
            scrollFrame.ScrollBar:SetAlpha(needsScrollbar and 1 or 0)

            --UpdateScrollbar()
            UpdateScrollChildWidth()
        end
    end

    -- Store function for external access
    content.UpdateScrollBarVisibility = UpdateScrollBarVisibility

    -- Initial width setup
    UpdateScrollChildWidth()

    -- Hook multiple events to ensure visibility updates properly
    scrollFrame:HookScript("OnScrollRangeChanged", UpdateScrollBarVisibility)
    scrollChild:HookScript("OnSizeChanged", UpdateScrollBarVisibility)
    scrollFrame:HookScript("OnSizeChanged", UpdateScrollBarVisibility)

    -- Also update on show
    scrollFrame:HookScript("OnShow", function()
        C_Timer.After(0, UpdateScrollBarVisibility)
    end)

    -- Store references
    content.scrollFrame = scrollFrame
    content.scrollChild = scrollChild

    -- Snapping scrollbar to pixel grid for sharper rendering
    if scrollFrame.ScrollBar then
        local sb = scrollFrame.ScrollBar
        local isSnapping = false
        local PIXEL_STEP = NRSKNUI:PixelBestSize()
        local lastValue = 0
        sb:HookScript("OnValueChanged", function(self, value)
            if isSnapping then return end

            local scale = scrollFrame:GetEffectiveScale()
            -- Convert to screen pixels, round to nearest step, convert back
            local screenPixels = value * scale
            local snappedPixels = math.floor(screenPixels / PIXEL_STEP + 0.5) * PIXEL_STEP
            local snappedValue = snappedPixels / scale

            -- Only snap if we're not already at a step boundary
            if math.abs(value - snappedValue) > 0.001 then
                isSnapping = true
                self:SetValue(snappedValue)
                isSnapping = false
            end

            -- Only refresh if scroll actually changed significantly
            if math.abs(value - lastValue) > 0.1 then
                C_Timer.After(0, function()
                    RefreshAllFontStrings(scrollChild)
                end)
                lastValue = value
            end
        end)
    end

    -- Store reference
    parent.content = content
    self.contentArea = content
    return content
end

-- Create Footer
function GUIFrame:CreateFooter(parent)
    -- Footer frame
    local footer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    footer:SetHeight(Theme.footerHeight)
    footer:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    -- Footer background
    footer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    footer:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])

    -- Top border
    local topBorder = footer:CreateTexture(nil, "BORDER")
    topBorder:SetHeight(Theme.borderSize)
    topBorder:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
    topBorder:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
    topBorder:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4])
    footer.topBorder = topBorder

    -- Container frame for all logos
    local supportLogoContainer = CreateFrame("Frame", nil, footer)
    supportLogoContainer:SetSize(180, 32)
    supportLogoContainer:SetPoint("LEFT", footer, "LEFT", 0, 0)

    -- Create Twitch support button
    local logoTwitchSizeX = 21
    local logoTwitchSizeY = 21
    local logoTwitchWidth = 62
    local logoTwitchTextureColor = {
        r = Theme.accent[1],
        g = Theme.accent[2],
        b = Theme.accent[3],
    }

    local logoTwitch = CreateFrame("Button", nil, supportLogoContainer)
    logoTwitch:SetSize(logoTwitchWidth, logoTwitchSizeY)
    logoTwitch:SetPoint("LEFT", supportLogoContainer, "LEFT", Theme.paddingMedium, 0)

    -- Twitch Texture
    local logoTwitchTexture = logoTwitch:CreateTexture(nil, "ARTWORK")
    logoTwitchTexture:SetSize(logoTwitchSizeX, logoTwitchSizeY)
    logoTwitchTexture:SetPoint("LEFT", logoTwitch, "LEFT", 0, 0)
    logoTwitchTexture:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\SupportLogos\\Twitchv2W.png")
    logoTwitchTexture:SetVertexColor(logoTwitchTextureColor.r, logoTwitchTextureColor.g, logoTwitchTextureColor.b, 0.7)
    logoTwitchTexture:SetTexelSnappingBias(0)
    logoTwitchTexture:SetSnapToPixelGrid(false)

    -- Twitch Text
    local logoTwitchText = logoTwitch:CreateFontString(nil, "OVERLAY")
    logoTwitchText:SetPoint("LEFT", logoTwitchTexture, "RIGHT", Theme.paddingSmall, 1)
    if NRSKNUI.ApplyThemeFont then
        NRSKNUI:ApplyThemeFont(logoTwitchText, "normal")
    else
        logoTwitchText:SetFontObject("GameFontNormal")
    end
    logoTwitchText:SetText("Twitch")
    logoTwitchText:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.7)
    logoTwitchText:SetShadowColor(0, 0, 0, 0)

    -- Twitch dialog promt
    logoTwitch:RegisterForClicks("LeftButtonUp")
    logoTwitch:SetScript("OnClick", function()
        NRSKNUI:CreatePrompt(
            "Support My |cff9146FFTwitch|r",
            "www.twitch.tv/norskenwow",
            true,
            "Copy to clipboard by pressing CTRL + C",
            true,
            "Interface\\AddOns\\NorskenUI\\Media\\SupportLogos\\Twitchv2W.png",
            logoTwitchSizeX,
            logoTwitchSizeY,
            { r = Theme.accent[1], g = Theme.accent[2], b = Theme.accent[3] }
        )
    end)

    -- Store Twitch references on footer
    footer.logoTwitchTexture = logoTwitchTexture
    footer.logoTwitchText = logoTwitchText

    -- Twitch Mouseover stuff
    logoTwitch:SetScript("OnEnter", function()
        logoTwitchTexture:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        logoTwitchText:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    end)
    logoTwitch:SetScript("OnLeave", function()
        logoTwitchTexture:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.7)
        logoTwitchText:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.7)
    end)

    -- Create Discord support button
    local logoDiscordSizeX = 21
    local logoDiscordSizeY = 21
    local logoDiscordWidth = 68
    local logoDiscordTextureColor = {
        r = Theme.accent[1],
        g = Theme.accent[2],
        b = Theme.accent[3],
    }

    local logoDiscord = CreateFrame("Button", nil, supportLogoContainer)
    logoDiscord:SetSize(logoDiscordWidth, logoDiscordSizeY)
    logoDiscord:SetPoint("LEFT", logoTwitch, "RIGHT", Theme.paddingMedium, 0)

    -- Discord Texture
    local logoDiscordTexture = logoDiscord:CreateTexture(nil, "ARTWORK")
    logoDiscordTexture:SetSize(logoDiscordSizeX, logoDiscordSizeY)
    logoDiscordTexture:SetPoint("LEFT", logoDiscord, "LEFT", 0, 0)
    logoDiscordTexture:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\SupportLogos\\Discordv2W.png")
    logoDiscordTexture:SetVertexColor(logoDiscordTextureColor.r, logoDiscordTextureColor.g, logoDiscordTextureColor.b,
        0.7)
    logoDiscordTexture:SetTexelSnappingBias(0)
    logoDiscordTexture:SetSnapToPixelGrid(false)

    -- Discord Text
    local logoDiscordText = logoDiscord:CreateFontString(nil, "OVERLAY")
    logoDiscordText:SetPoint("LEFT", logoDiscordTexture, "RIGHT", Theme.paddingSmall, 1)
    if NRSKNUI.ApplyThemeFont then
        NRSKNUI:ApplyThemeFont(logoDiscordText, "normal")
    else
        logoDiscordText:SetFontObject("GameFontNormal")
    end
    logoDiscordText:SetText("Discord")
    logoDiscordText:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.7)
    logoDiscordText:SetShadowColor(0, 0, 0, 0)

    -- Discord dialog promt
    logoDiscord:RegisterForClicks("LeftButtonUp")
    logoDiscord:SetScript("OnClick", function()
        NRSKNUI:CreatePrompt(
            "Join My |cff5865F2Discord|r",
            "https://discord.com/invite/23bS8pHfuX",
            true,
            "Copy to clipboard by pressing CTRL + C",
            true,
            "Interface\\AddOns\\NorskenUI\\Media\\SupportLogos\\Discordv2W.png",
            logoDiscordSizeX,
            logoDiscordSizeY,
            { r = Theme.accent[1], g = Theme.accent[2], b = Theme.accent[3] }
        )
    end)
    -- Store Discord references on footer
    footer.logoDiscordTexture = logoDiscordTexture
    footer.logoDiscordText = logoDiscordText

    -- Discord Mouseover stuff
    logoDiscord:SetScript("OnEnter", function()
        logoDiscordTexture:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        logoDiscordText:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    end)
    logoDiscord:SetScript("OnLeave", function()
        logoDiscordTexture:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.7)
        logoDiscordText:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.7)
    end)

    -- Resize handle
    local handle = CreateFrame("Button", nil, footer)
    handle:SetSize(23, 23)
    handle:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -2, 2)
    handle:EnableMouse(true)

    -- Resize handle textures
    -- Uses my homecooked resize handle texture
    local tex = handle:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomResizeHandle23px.png")
    tex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.6)
    tex:SetTexelSnappingBias(0)
    tex:SetSnapToPixelGrid(false)

    -- Resize handle scripts
    handle:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            tex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            parent:StartSizing("BOTTOMRIGHT")
        end
    end)
    handle:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            tex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.6)
            parent:StopMovingOrSizing()
            if GUIFrame.contentArea and GUIFrame.contentArea.UpdateScrollBarVisibility then
                C_Timer.After(0.05, GUIFrame.contentArea.UpdateScrollBarVisibility)
            end
            -- Also update sidebar scroll
            if GUIFrame.sidebar and GUIFrame.sidebar.UpdateScrollBarVisibility then
                C_Timer.After(0.05, GUIFrame.sidebar.UpdateScrollBarVisibility)
            end
            NRSKNUI:SnapFrameToPixels(parent)
            GUIFrame:SaveFramePosition()
        end
    end)

    -- Hover effects
    handle:SetScript("OnEnter", function()
        tex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    end)
    handle:SetScript("OnLeave", function()
        tex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.6)
    end)

    -- Make footer draggable for moving the frame
    footer:EnableMouse(true)
    footer:RegisterForDrag("LeftButton")
    footer:SetScript("OnDragStart", function()
        parent:StartMoving()
    end)
    footer:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        NRSKNUI:SnapFrameToPixels(parent)
        GUIFrame:SaveFramePosition()
    end)

    -- Footer element references
    footer.resizeHandle = handle
    parent.footer = footer
    parent.resizeHandle = handle
    self.footer = footer
    return footer
end

-- Refresh Content Area
function GUIFrame:RefreshContent()
    if not self.contentArea then return end

    -- Fire any registered content cleanup callbacks
    if self.contentCleanupCallbacks then
        for key, callback in pairs(self.contentCleanupCallbacks) do
            local ok, err = pcall(callback)
            if not ok and NRSKNUI.debug then
                print("|cFFFF0000[NRSKNUI]|r Content cleanup callback '" .. key .. "' failed: " .. tostring(err))
            end
        end
    end

    -- Clean up custom panel if exists
    if self.contentArea._customPanel then
        self.contentArea._customPanel:Hide()
        self.contentArea._customPanel:SetParent(nil)
        self.contentArea._customPanel = nil
    end

    -- Check if there's a panel builder for this item
    local itemId = self.selectedSidebarItem
    if not itemId then
        itemId = "HomePage"
    end

    -- Check for panel builders
    if itemId and self.PanelBuilders and self.PanelBuilders[itemId] then
        if self.contentArea.scrollFrame then
            self.contentArea.scrollFrame:Hide()
        end

        local ok, panel = pcall(self.PanelBuilders[itemId], self.contentArea)
        if ok and panel then
            self.contentArea._customPanel = panel
        elseif not ok then
            if self.contentArea.scrollFrame then
                self.contentArea.scrollFrame:Show()
            end
            local scrollChild = self.contentArea.scrollChild
            local errorCard = self:CreateCard(scrollChild, "Error", Theme.paddingMedium)
            local errorMsg = errorCard:AddLabel("Panel builder failed: " .. tostring(panel))
            errorMsg:SetTextColor(Theme.error[1], Theme.error[2], Theme.error[3], 1)
            scrollChild:SetHeight(errorCard:GetContentHeight() + Theme.paddingLarge)
        end
        return
    end

    -- Show the outer scroll frame
    if self.contentArea.scrollFrame then
        self.contentArea.scrollFrame:Show()
    end

    -- Clear existing content
    local scrollChild = self.contentArea.scrollChild

    -- Clear existing content
    for _, region in ipairs({ scrollChild:GetRegions() }) do
        if region:GetObjectType() == "FontString" or region:GetObjectType() == "Texture" then
            region:Hide()
        end
    end

    -- Clear existing content
    for _, child in ipairs({ scrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    -- Y offset for placing content
    local yOffset = Theme.paddingMedium

    -- Check if there's a registered content builder for this sidebar item
    if itemId and self.ContentBuilders[itemId] then
        local ok, result = pcall(self.ContentBuilders[itemId], scrollChild, yOffset)
        if ok then
            if result then
                yOffset = result
            end
        else
            local errorCard = self:CreateCard(scrollChild, "Error", yOffset)
            local errorMsg = errorCard:AddLabel("Content builder failed: " .. tostring(result))
            errorMsg:SetTextColor(Theme.error[1], Theme.error[2], Theme.error[3], 1)
            errorCard:AddSpacing(Theme.paddingSmall)
            yOffset = yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
        end
    else
        -- No registered builder - show demo/placeholder content
        yOffset = self:BuildDemoContent(scrollChild, yOffset)
    end

    scrollChild:SetHeight(yOffset + Theme.paddingLarge)
    if self.contentArea.UpdateScrollbar then
        self.contentArea.UpdateScrollbar()
    end
end

-- Placeholder card
function GUIFrame:BuildDemoContent(scrollChild, yOffset)
    -- Card 1
    local card1 = GUIFrame:CreateCard(scrollChild, "Coming Soon", yOffset)
    card1:AddLabel("This section is under construction.")
    card1:AddSpacing(Theme.paddingSmall)
    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingMedium
    return yOffset
end

-- Show GUI Frame
function GUIFrame:Show()
    -- Check combat lockdown
    if InCombatLockdown() then
        NRSKNUI:Print("Options will open after combat ends.")
        self.reopenAfterCombat = true
        return
    end

    -- Create main frame if it doesn't exist
    local isFirstCreate = not self.mainFrame
    if isFirstCreate then
        self:CreateMainFrame()
        GUIFrame:InitializeSidebarExpansion()
    end

    -- Restore position if not first create
    self:RestoreFramePosition()
    self.mainFrame:Show()
    self.mainFrame:Raise()
    NRSKNUI.GUIOpen = true

    -- Notify preview manager that GUI is open
    if NRSKNUI.PreviewManager then
        NRSKNUI.PreviewManager:SetGUIOpen(true)
    end

    -- Initialize sidebar and content for current tab
    self:RefreshSidebar()

    if self.shortcutFrame then
        self.shortcutFrame:Show()
    end

    -- Defer a refresh after frame layout completes to ensure correct widths
    C_Timer.After(0, function()
        if self.mainFrame and self.mainFrame:IsShown() then
            -- Force sidebar scrollChild to get correct width
            if self.sidebar then
                local sidebarWidth = self.sidebar:GetWidth()
                if sidebarWidth and sidebarWidth > 0 and self.sidebar.scrollChild then
                    local newWidth = sidebarWidth - Theme.paddingSmall * 2 - 16
                    self.sidebar.scrollChild:SetWidth(newWidth)
                end
            end
            self:RefreshSidebar()
            self:RefreshContent()
            if self.contentArea and self.contentArea.scrollChild then
                RefreshAllFontStrings(self.contentArea.scrollChild)
            end
        end
    end)
end

-- Hide GUI Frame
function GUIFrame:Hide()
    if self.mainFrame then
        self:SaveFramePosition()

        -- Save GUI state to session memory
        if self.SaveSessionState then
            self:SaveSessionState()
        end

        -- Fire content cleanup callbacks
        if self.contentCleanupCallbacks then
            for key, callback in pairs(self.contentCleanupCallbacks) do
                local ok, err = pcall(callback)
                if not ok and NRSKNUI.debug then
                    print("|cFFFF0000[NRSKNUI]|r Content cleanup callback '" .. key .. "' failed: " .. tostring(err))
                end
            end
        end

        if self.shortcutFrame then
            self.shortcutFrame:Hide()
        end

        -- Fire on-close callbacks, for previews registered via RegisterOnCloseCallback
        if self.FireOnCloseCallbacks then
            self:FireOnCloseCallbacks()
        end

        local GUIFactory = NRSKNUI.GUIFactory
        if GUIFactory and GUIFactory.FireOnCloseCallbacks then
            GUIFactory:FireOnCloseCallbacks()
        end

        NRSKNUI.GUIOpen = false
        if NRSKNUI.PreviewManager then
            NRSKNUI.PreviewManager:SetGUIOpen(false)
        end
        self.mainFrame:Hide()
    else
        NRSKNUI.GUIOpen = false
        if NRSKNUI.PreviewManager then
            NRSKNUI.PreviewManager:SetGUIOpen(false)
        end
    end
end

-- Toggle GUI Frame
function GUIFrame:Toggle()
    if self.mainFrame and self.mainFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- Is GUI Frame Shown
function GUIFrame:IsShown()
    return self.mainFrame and self.mainFrame:IsShown()
end

-- Session state
GUIFrame.sessionState = GUIFrame.sessionState or {
    scrollPositions = {},
    selectedTab = "systems",
    selectedSidebarItem = nil,
}

-- Get Session State
function GUIFrame:GetSessionState()
    return self.sessionState
end

-- Save Session State
function GUIFrame:SaveSessionState()
    if not self.mainFrame then return end

    -- Save current scroll position for current tab
    if self.sidebar and self.sidebar.scrollFrame and self.selectedTab then
        local scrollValue = self.sidebar.scrollFrame:GetVerticalScroll()
        self.sessionState.scrollPositions[self.selectedTab] = scrollValue
    end

    -- Save selected tab and sidebar item
    self.sessionState.selectedTab = self.selectedTab
    self.sessionState.selectedSidebarItem = self.selectedSidebarItem
end

-- Restore Session State
function GUIFrame:RestoreSessionState()
    if not self.sessionState then return end

    -- Restore selected tab
    if self.sessionState.selectedTab then
        self.selectedTab = self.sessionState.selectedTab
    end

    -- Restore selected sidebar item
    if self.sessionState.selectedSidebarItem then
        self.selectedSidebarItem = self.sessionState.selectedSidebarItem
    end

    -- Restore scroll position
    C_Timer.After(0.01, function()
        if self.sidebar and self.sidebar.scrollFrame and self.selectedTab then
            local scrollValue = self.sessionState.scrollPositions[self.selectedTab]
            if scrollValue then
                self.sidebar.scrollFrame:SetVerticalScroll(scrollValue)
            end
        end
    end)
end

-- Save Frame Position to SavedVariables
function GUIFrame:SaveFramePosition()
    if not self.mainFrame then return end
    if not NRSKNUI.db or not NRSKNUI.db.global then return end

    local point, _, relPoint, x, y = self.mainFrame:GetPoint()

    -- Save to SavedVariables
    NRSKNUI.db.global.GUIState = NRSKNUI.db.global.GUIState or {}
    NRSKNUI.db.global.GUIState.frame = {
        point = point,
        relativePoint = relPoint,
        xOffset = x,
        yOffset = y,
        width = self.mainFrame:GetWidth(),
        height = self.mainFrame:GetHeight(),
    }

    -- Also keep in memory for session
    self.savedPosition = NRSKNUI.db.global.GUIState.frame

    -- Also save session state
    self:SaveSessionState()
end

-- Restore Frame Position
function GUIFrame:RestoreFramePosition()
    if not self.mainFrame then return end

    -- Try to load from SavedVariables first
    local pos = nil
    if NRSKNUI.db and NRSKNUI.db.global and NRSKNUI.db.global.GUIState and NRSKNUI.db.global.GUIState.frame then
        pos = NRSKNUI.db.global.GUIState.frame
    end

    -- Fall back to in-memory position
    if not pos then
        pos = self.savedPosition
    end

    -- Apply position if we have one
    if pos then
        self.mainFrame:ClearAllPoints()
        self.mainFrame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.xOffset or 0,
            pos.yOffset or 50)
        if pos.width and pos.height then
            self.mainFrame:SetSize(pos.width, pos.height)
        end
    end

    -- Also restore session state
    self:RestoreSessionState()
end

-- Combat handling: Close GUI on entering combat, reopen on leaving combat
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat - force close
        if GUIFrame:IsShown() then
            GUIFrame.reopenAfterCombat = true
            GUIFrame:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Leaving combat - reopen if needed
        if GUIFrame.reopenAfterCombat then
            GUIFrame.reopenAfterCombat = nil
            GUIFrame:Show()
        end
    end
end)

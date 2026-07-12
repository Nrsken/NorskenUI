-- NRSKNUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

NRSKNUI.GUIFrame = NRSKNUI.GUIFrame or {}
---@class GUIFrame
---@field mainFrame (Frame & BackdropTemplate)|nil Main options window, created by CreateMainFrame
---@field sidebar (Frame & BackdropTemplate)|nil Sidebar panel, created in GUI-Sidebar.lua
---@field contentArea Frame|nil Scrollable content area
---@field footer (Frame & BackdropTemplate)|nil Footer bar
---@field sessionState { scrollPositions: table<string, number>, selectedTab: string, selectedSidebarItem: string|nil, sidebarExpanded: table<string, boolean>|nil }
---@field selectedTab string
---@field selectedSidebarItem string|nil
---@field sidebarExpanded table<string, boolean>
---@field reopenAfterCombat boolean|nil Reopen the GUI when combat ends
---@field sidebarRefreshPending boolean|nil
---@field currentBuildingPageId string|nil
---@field _isShowing boolean|nil Guards against re-entrant Show calls
---@field shortcutBtn Button|nil Header shortcut menu toggle
---@field shortcutContent (Frame & BackdropTemplate)|nil Shortcut dropdown frame
---@field shortcutItemButtons (Button & BackdropTemplate)[]|nil
---@field shortcutScrollbarThumb Texture|nil
---@field shortcutScrollbarBorder (Frame & BackdropTemplate)|nil
local GUIFrame = NRSKNUI.GUIFrame

local Theme = NRSKNUI.Theme
local addonVersion = NRSKNUI.Version

NRSKNUI.GUIOpen = false

local pcall = pcall
local select = select
local ShowUIPanel = ShowUIPanel
local tostring = tostring
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local ReloadUI = ReloadUI
local CreateColor = CreateColor
local InCombatLockdown = InCombatLockdown
local _G = _G
local C_AddOns = C_AddOns

GUIFrame.selectedTab = "systems"
GUIFrame.selectedSidebarItem = nil
GUIFrame.sidebarExpanded = GUIFrame.sidebarExpanded or {}

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

    for i = 1, frame:GetNumChildren() do
        local child = select(i, frame:GetChildren())
        if child then
            RefreshAllFontStrings(child)
        end
    end
end

function GUIFrame:CreateMainFrame()
    if self.mainFrame then
        return self.mainFrame
    end

    local frame = CreateFrame("Frame", "NorskenUIGUIFrame", UIParent, "BackdropTemplate")
    frame:SetSize(950, 700)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(false)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(950, 700)
    frame:EnableMouse(true)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = Theme.borderSize,
    })
    frame:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], Theme.bgDark[4])
    frame:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    NRSKNUI.GUIOverlay = CreateFrame("Frame", nil, UIParent)
    NRSKNUI.GUIOverlay:SetAllPoints(UIParent)
    NRSKNUI.GUIOverlay:SetFrameStrata("TOOLTIP")
    NRSKNUI.GUIOverlay:SetFrameLevel(1)
    NRSKNUI.GUIOverlay:EnableMouse(false)

    self:CreateHeader(frame)
    self:CreateFooter(frame)
    self:CreateContentArea(frame)
    self:CreateSidebar(frame)
    self:CreateSearchHeader(frame)

    local borderFrame = CreateFrame("Frame", nil, frame)
    borderFrame:SetAllPoints(frame)
    borderFrame:SetFrameStrata("TOOLTIP")
    borderFrame:SetFrameLevel(frame:GetFrameLevel() + 100)

    local borderTop = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderTop:SetHeight(Theme.borderSize)
    borderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borderTop:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    local borderBottom = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderBottom:SetHeight(Theme.borderSize)
    borderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    local borderLeft = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderLeft:SetWidth(Theme.borderSize)
    borderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    borderLeft:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    local borderRight = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderRight:SetWidth(Theme.borderSize)
    borderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    borderRight:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            GUIFrame:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    frame:EnableKeyboard(true)

    frame:SetToplevel(true)

    frame:SetScript("OnHide", function()
        if NRSKNUI.GUIOpen then
            GUIFrame:SaveFramePosition()
            GUIFrame:SaveSessionState()
            if GUIFrame.contentCleanupCallbacks then
                for _, callback in pairs(GUIFrame.contentCleanupCallbacks) do
                    pcall(callback)
                end
            end
            GUIFrame:FireOnCloseCallbacks()
            NRSKNUI.GUIOpen = false
            if NRSKNUI.PreviewManager then
                NRSKNUI.PreviewManager:SetGUIOpen(false)
            end
        end
    end)
    frame:Hide()

    self.mainFrame = frame
    return frame
end

function GUIFrame:ApplyThemeColors()
    if not self.mainFrame then return end
    local frame = self.mainFrame
    local selBg = Theme.selectedBg or Theme.accent
    local selText = Theme.selectedText or Theme.accent

    frame:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], Theme.bgDark[4])
    frame:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    if frame.header then
        frame.header:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])
        if frame.header.logoN then
            frame.header.logoN:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.7)
        end
        if frame.header.logoUI then
            frame.header.logoUI:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3],
                1)
        end
    end

    if self.sidebar then
        self.sidebar:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])
        if self.sidebar.scrollbar and self.sidebar.scrollbar.ApplyThemeColors then
            self.sidebar.scrollbar:ApplyThemeColors()
        end
    end

    if self.sidebarHeaderPool then
        local r, g, b = Theme.accent[1], Theme.accent[2], Theme.accent[3]
        for _, header in ipairs(self.sidebarHeaderPool) do
            if header.inUse then
                if header.disabled then
                    if header.label then
                        header.label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3],
                            0.35)
                    end
                    if header.arrow then
                        header.arrow:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2],
                            Theme.textSecondary[3], 0.35)
                    end
                else
                    if header.label then
                        header.label:SetTextColor(r, g, b, 1)
                    end
                    if header.arrow then
                        header.arrow:SetVertexColor(r, g, b, 1)
                    end
                end
                if header.background then
                    header.background:SetGradient("HORIZONTAL", CreateColor(0.3, 0.3, 0.3, 0.25),
                        CreateColor(0.3, 0.3, 0.3, 0))
                end
                if header.selectedOverlay then
                    header.selectedOverlay:SetVertexColor(selBg[1], selBg[2], selBg[3], selBg[4] or 0.25)
                end
                if header.selectedBar then
                    header.selectedBar:SetColorTexture(r, g, b, 1)
                end
            end
        end
    end

    if self.staticSidebarItemPool then
        local r, g, b = Theme.accent[1], Theme.accent[2], Theme.accent[3]
        for _, item in ipairs(self.staticSidebarItemPool) do
            if item.selectedOverlay then
                item.selectedOverlay:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.25), CreateColor(r, g, b, 0))
            end
            if item.background then
                item.background:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.25), CreateColor(r, g, b, 0))
            end
            if item.selectedBar then
                item.selectedBar:SetColorTexture(selText[1], selText[2], selText[3], selText[4] or 1)
            end
            if item.inUse then
                if item.disabled then
                    item.label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.35)
                elseif item.id == self.selectedSidebarItem then
                    item.label:SetTextColor(selText[1], selText[2], selText[3], selText[4] or 1)
                else
                    item.label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
                end
            end
        end
    end

    if frame.content then
        frame.content:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], Theme.bgDark[4])
        if frame.content.scrollbar and frame.content.scrollbar.ApplyThemeColors then
            frame.content.scrollbar:ApplyThemeColors()
        end
    end

    if frame.footer then
        frame.footer:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])
        if frame.footer.logoTwitchTexture then
            frame.footer.logoTwitchTexture:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.7)
        end
        if frame.footer.logoTwitchText then
            frame.footer.logoTwitchText:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2],
                Theme.textSecondary[3], 0.7)
        end
        if frame.footer.logoDiscordTexture then
            frame.footer.logoDiscordTexture:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.7)
        end
        if frame.footer.logoDiscordText then
            frame.footer.logoDiscordText:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2],
                Theme.textSecondary[3], 0.7)
        end
    end

    if self.shortcutContent then
        self.shortcutContent:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], 1)
        self.shortcutContent:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    end
    if self.shortcutBtn then
        local tex = self.shortcutBtn:GetNormalTexture()
        if tex then
            tex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.7)
        end
    end
    if self.shortcutItemButtons then
        for _, btn in ipairs(self.shortcutItemButtons) do
            for i = 1, btn:GetNumRegions() do
                local region = select(i, btn:GetRegions())
                if region and region:GetObjectType() == "FontString" then
                    region:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                    break
                end
            end
        end
    end
    if self.shortcutScrollbarThumb then
        self.shortcutScrollbarThumb:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.8)
    end
    if self.shortcutScrollbarBorder then
        self.shortcutScrollbarBorder:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    end
end

function GUIFrame:CreateHeader(parent)
    local header = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    header:SetHeight(Theme.headerHeight)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    header:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])

    local bottomBorder = header:CreateTexture(nil, "BORDER")
    bottomBorder:SetHeight(Theme.borderSize)
    bottomBorder:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    bottomBorder:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    bottomBorder:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4])

    local logoContainer = CreateFrame("Frame", nil, header)
    logoContainer:SetSize(180, 32)
    logoContainer:SetPoint("LEFT", header, "LEFT", Theme.paddingLarge, -1)

    local logoN = logoContainer:CreateTexture(nil, "ARTWORK")
    logoN:SetSize(64, 64)
    logoN:SetPoint("LEFT", logoContainer, "LEFT", -10, 1)
    logoN:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\Logo\\logocookingsPT1128x128OT.png")
    logoN:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.7)
    logoN:SetTexelSnappingBias(0)
    logoN:SetSnapToPixelGrid(false)

    local logoUI = logoContainer:CreateTexture(nil, "ARTWORK")
    logoUI:SetSize(128, 128)
    logoUI:SetPoint("LEFT", logoN, "RIGHT", -62, -4)
    logoUI:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\Logo\\logocookingsPT3128x128OT.png")
    logoUI:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    logoUI:SetTexelSnappingBias(0)
    logoUI:SetSnapToPixelGrid(false)

    local fontPath = "Fonts\\FRIZQT__.TTF"
    local fontSize = Theme.fontSizeSmall or 10
    local currentVersionText = header:CreateFontString(nil, "OVERLAY")
    currentVersionText:SetPoint("LEFT", logoUI, "RIGHT", -45, -3)
    currentVersionText:SetFont(fontPath, fontSize, "")
    currentVersionText:SetText(addonVersion)
    currentVersionText:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    currentVersionText:SetJustifyH("LEFT")
    currentVersionText:SetShadowColor(0, 0, 0, 0)
    NRSKNUI:CreateSoftOutline(currentVersionText, {
        thickness = 1,
        color = { 0, 0, 0 },
        alpha = 0.9,
    })

    header.logoN = logoN
    header.logoUI = logoUI

    -- Search Index Progress Bar
    local progressContainer = CreateFrame("Frame", nil, header, "BackdropTemplate")
    progressContainer:SetSize(200, 10)
    progressContainer:SetPoint("CENTER", header, "CENTER", 0, -8)
    progressContainer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    progressContainer:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 0.8)
    progressContainer:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 0.6)
    progressContainer:Hide()

    local progressBar = progressContainer:CreateTexture(nil, "ARTWORK")
    progressBar:SetPoint("TOPLEFT", progressContainer, "TOPLEFT", 1, -1)
    progressBar:SetPoint("BOTTOMLEFT", progressContainer, "BOTTOMLEFT", 1, 1)
    progressBar:SetWidth(0)
    progressBar:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.9)

    local progressLabel = progressContainer:CreateFontString(nil, "OVERLAY")
    progressLabel:SetPoint("BOTTOM", progressContainer, "TOP", 0, 4)
    NRSKNUI:ApplyThemeFont(progressLabel, "normal")
    progressLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.8)
    progressLabel:SetText("Indexing...")

    header.progressContainer = progressContainer
    header.progressBar = progressBar
    header.progressLabel = progressLabel

    local function Lerp(a, b, t) return a + (b - a) * t end

    local function CreateHeaderButton(config)
        local btn = CreateFrame("Button", nil, header)
        btn:SetSize(config.width or config.size, config.height or config.size)
        btn:SetPoint("RIGHT", header, "RIGHT", config.xOffset, config.yOffset or 0)
        btn:SetFrameStrata(config.strata or "DIALOG")

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(config.texture)
        tex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.7)
        tex:SetTexelSnappingBias(0)
        tex:SetSnapToPixelGrid(true)
        btn:SetNormalTexture(tex)

        if config.rotation then
            tex:SetRotation(math.rad(config.rotation))
        end

        local state = { alpha = 0.7 }
        local anim = btn:CreateAnimationGroup()
        anim:CreateAnimation("Animation"):SetDuration(0.15)
        local animFrom, animTo = 0.7, 0.7

        anim:SetScript("OnUpdate", function(animGroup)
            local a = Lerp(animFrom, animTo, animGroup:GetProgress() or 0)
            tex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], a)
            state.alpha = a
        end)

        anim:SetScript("OnFinished", function()
            tex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], animTo)
            state.alpha = animTo
        end)

        local function AnimateAlpha(toHover)
            anim:Stop()
            animFrom = state.alpha
            animTo = toHover and 1 or 0.7
            anim:Play()
        end

        btn.tex = tex
        btn.AnimateAlpha = AnimateAlpha

        if config.onClick then
            btn:SetScript("OnEnter", function()
                AnimateAlpha(true)
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT", 0, 10)
                GameTooltip:SetText(config.toolTip, Theme.accent[1], Theme.accent[2], Theme.accent[3], 1, false)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function()
                AnimateAlpha(false)
                GameTooltip:Hide()
            end)
            btn:SetScript("OnClick", config.onClick)
        end

        return btn
    end

    CreateHeaderButton({
        size = 22,
        xOffset = -6,
        texture = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomCrossv3.png",
        rotation = 45,
        onClick = function() GUIFrame:Hide() end,
        toolTip = "Close Settings"
    })

    CreateHeaderButton({
        size = 18,
        xOffset = -81,
        texture = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\fill.png",
        onClick = function() GUIFrame:OpenPage("ThemePage") end,
        toolTip = "Open Theme Settings"
    })

    CreateHeaderButton({
        size = 18,
        xOffset = -56,
        texture = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\HomeButtonv2.png",
        onClick = function() GUIFrame:OpenPage("HomePage") end,
        toolTip = "Open Home Page"
    })

    CreateHeaderButton({
        size = 22,
        xOffset = -104,
        texture = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\globe-earth.png",
        onClick = function() GUIFrame:OpenPage("GlobalPage") end,
        toolTip = "Open Global Settings Page"
    })

    CreateHeaderButton({
        size = 22,
        xOffset = -128,
        texture = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\anchor.png",
        onClick = function()
            if NRSKNUI.EditMode then
                NRSKNUI.EditMode:Toggle()
            end
        end,
        toolTip = "Open Anchors"
    })

    -- Shortcut Menu Button
    local ITEM_HEIGHT = 24
    local MAX_HEIGHT = 400

    local shortcutBtn = CreateHeaderButton({
        width = 18,
        height = 22,
        xOffset = -32,
        texture = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomBurger.png",
        strata = "TOOLTIP",
    })

    local dropdown = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    dropdown:SetSize(180, 1)
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    dropdown:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], 1)
    dropdown:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    dropdown:SetFrameStrata("TOOLTIP")
    dropdown:SetClipsChildren(true)
    dropdown:SetPoint("TOP", shortcutBtn, "BOTTOM", 132, 28)
    dropdown:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", nil, dropdown)
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -12, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)

    local scrollbar = NRSKNUI.GUI.CreateScrollbar(scrollFrame, { anchorToScrollFrame = false })
    scrollbar:SetParent(dropdown)
    scrollbar:ClearAllPoints()
    scrollbar:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", 0, 0)
    scrollbar:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", 0, 0)

    local menuState = { isOpen = false, scrollHold = false, startHeight = 0, targetHeight = 0 }
    local itemButtons = {}

    scrollbar:HookScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then menuState.scrollHold = true end
    end)
    scrollbar:HookScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            C_Timer.After(0.1, function() menuState.scrollHold = false end)
        end
    end)

    local dropdownAnim = dropdown:CreateAnimationGroup()
    dropdownAnim:CreateAnimation("Animation"):SetDuration(0.18)

    dropdownAnim:SetScript("OnUpdate", function(anim)
        local p = anim:GetProgress() or 0
        local smooth = p * p * (3 - 2 * p)
        local h = menuState.startHeight + (menuState.targetHeight - menuState.startHeight) * smooth
        dropdown:SetHeight(h)
        if menuState.isOpen and h < menuState.targetHeight then
            dropdown:SetClipsChildren(false)
        end
    end)

    dropdownAnim:SetScript("OnFinished", function()
        dropdown:SetHeight(menuState.targetHeight)
        if not menuState.isOpen then
            dropdown:Hide()
        else
            dropdown:SetClipsChildren(true)
        end
    end)

    local function UpdateScroll()
        local contentH = scrollChild:GetHeight()
        local frameH = scrollFrame:GetHeight()
        local needsScroll = scrollbar:UpdateVisibility(contentH, frameH)
        scrollFrame:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", needsScroll and -12 or 0, 0)
        if needsScroll then scrollbar:SetValue(0) end
        scrollChild:SetWidth(scrollFrame:GetWidth())
        for i, b in ipairs(itemButtons) do
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ITEM_HEIGHT)
            b:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
        end
    end

    local function CloseDropdown(instant)
        if menuState.scrollHold or not menuState.isOpen then return end
        menuState.isOpen = false
        if instant then
            dropdown:SetHeight(1)
            dropdown:Hide()
            dropdownAnim:Stop()
        else
            menuState.startHeight = dropdown:GetHeight()
            menuState.targetHeight = 1
            dropdownAnim:Stop()
            dropdownAnim:Play()
        end
    end

    local function OpenDropdown()
        if menuState.isOpen then return end
        menuState.isOpen = true
        menuState.startHeight = 1
        menuState.targetHeight = math.min(#itemButtons * ITEM_HEIGHT, MAX_HEIGHT)

        dropdown:SetHeight(menuState.targetHeight)
        scrollChild:SetWidth(scrollFrame:GetWidth())
        UpdateScroll()
        dropdown:Show()
        dropdown:SetHeight(menuState.startHeight)
        dropdownAnim:Play()
    end

    local function CreateMenuItem(index, text, onClick)
        local item = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        item:SetHeight(ITEM_HEIGHT)
        item:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(index - 1) * ITEM_HEIGHT)
        item:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)

        local label = item:CreateFontString(nil, "OVERLAY")
        label:SetPoint("LEFT", 8, 0)
        label:SetPoint("RIGHT", -8, 0)
        label:SetJustifyH("LEFT")
        NRSKNUI:ApplyThemeFont(label, "normal")
        label:SetText(text)
        label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3])

        item:SetScript("OnClick", function()
            onClick()
            CloseDropdown()
        end)

        item:SetScript("OnEnter", function()
            item:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            item:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
            item:SetBackdropColor(Theme.accentHover[1], Theme.accentHover[2], Theme.accentHover[3],
                Theme.accentHover[4] or 0.25)
            label:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3], 1)
        end)

        item:SetScript("OnLeave", function()
            item:SetBackdrop(nil)
            label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3])
        end)

        return item
    end

    local function TryOpenAddon(addonName, slashCmd, displayName)
        if not C_AddOns.IsAddOnLoaded(addonName) then
            if not C_AddOns.LoadAddOn(addonName) then
                NRSKNUI:Print(displayName .. " is disabled/missing")
                return
            end
        end
        if SlashCmdList[slashCmd] then
            SlashCmdList[slashCmd]("")
        else
            NRSKNUI:Print(slashCmd .. " command not available.")
        end
    end

    local function BuildMenuItems()
        for _, b in ipairs(itemButtons) do
            b:Hide(); b:SetParent(nil)
        end
        itemButtons = {}

        local function AddonLoaded(name)
            return C_AddOns.IsAddOnLoaded(name)
        end

        local items = {
            { text = "Reload UI", onClick = ReloadUI },
            {
                text = "|cff00AEFFBlizzard|r Edit Mode",
                onClick = function()
                    if not (EditModeManagerFrame and EditModeManagerFrame:IsShown()) then
                        ShowUIPanel(EditModeManagerFrame)
                    end
                end
            },
            {
                text = "|cff00AEFFBlizzard|r CDM",
                onClick = function()
                    local frame = _G["CooldownViewerSettings"]
                    if frame then
                        frame:Show(); frame:Raise()
                    else
                        NRSKNUI:Print(
                            "CooldownViewerSettings not found. Make sure Cooldown Manager is enabled in Edit Mode.")
                    end
                end
            },
        }

        if AddonLoaded("UnhaltedUnitFrames") then
            items[#items + 1] = {
                text = "|cFF8080FFUnhalted|r|cFFFFFFFFUnitFrames|r",
                onClick = function() TryOpenAddon("UnhaltedUnitFrames", "UUF", "UnhaltedUnitFrames") end
            }
        end

        if AddonLoaded("BetterCooldownManager") then
            items[#items + 1] = {
                text = "|cFF8080FFBetter|r|cFFFFFFFFCooldownManager|r",
                onClick = function() TryOpenAddon("BetterCooldownManager", "BCDM", "BetterCooldownManager") end
            }
        end

        if AddonLoaded("MinimapStats") then
            items[#items + 1] = {
                text = "|cFF8080FFMinimap|r|cFFFFFFFFStats|r",
                onClick = function() TryOpenAddon("MinimapStats", "MINIMAPSTATS", "MinimapStats") end
            }
        end

        if AddonLoaded("Ayije_CDM") then
            items[#items + 1] = {
                text = "|cff00FF7FAyije|r CDM",
                onClick = function() TryOpenAddon("Ayije_CDM", "AYIJECDM", "Ayije_CDM") end
            }
        end

        for i, data in ipairs(items) do
            itemButtons[i] = CreateMenuItem(i, data.text, data.onClick)
        end
        scrollChild:SetHeight(#items * ITEM_HEIGHT)
    end

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        if scrollbar:IsShown() then
            local cur = scrollbar:GetValue()
            local minV, maxV = scrollbar:GetMinMaxValues()
            scrollbar:SetValue(math.max(minV, math.min(maxV, cur - delta * ITEM_HEIGHT)))
        end
    end)

    shortcutBtn:SetScript("OnEnter", function()
        shortcutBtn.AnimateAlpha(true)
        if not menuState.isOpen then OpenDropdown() end
    end)

    shortcutBtn:SetScript("OnLeave", function()
        shortcutBtn.AnimateAlpha(false)
        C_Timer.After(0.1, function()
            if not dropdown:IsMouseOver() and not shortcutBtn:IsMouseOver() then
                CloseDropdown()
            end
        end)
    end)

    dropdown:SetScript("OnLeave", function()
        C_Timer.After(0.1, function()
            if not dropdown:IsMouseOver() and not shortcutBtn:IsMouseOver() then
                CloseDropdown()
            end
        end)
    end)

    dropdown:SetScript("OnHide", function() menuState.isOpen = false end)
    shortcutBtn:SetScript("OnHide", function() CloseDropdown(true) end)

    dropdown:Show()
    dropdown:SetHeight(MAX_HEIGHT)
    BuildMenuItems()
    dropdown:SetHeight(1)
    dropdown:Hide()

    self.shortcutBtn = shortcutBtn
    self.shortcutContent = dropdown
    self.shortcutItemButtons = itemButtons
    self.shortcutScrollbarThumb = scrollbar.thumb
    self.shortcutScrollbarBorder = scrollbar.thumbBorder

    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() parent:StartMoving() end)
    header:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        GUIFrame:SaveFramePosition()
    end)

    parent.header = header
    return header
end

function GUIFrame:CreateContentArea(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetWidth(Theme.contentWidth)
    container:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -Theme.headerHeight)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, Theme.footerHeight)

    local area = NRSKNUI.GUI.CreateBasicContentArea(container, {
        contentWidth = Theme.contentWidth,
        noScrollbarOffset = 1,
        scrollbarOptions = {
            width = 16,
            thumbHeight = 40,
            padding = { top = -1, bottom = -1, right = 0 },
            scrollStep = 40,
        },
    })

    local content = area.frame
    content.scrollFrame = area.scrollFrame
    content.scrollChild = area.scrollChild
    content.scrollbar = area.scrollbar

    local baseUpdateVisibility = area.UpdateScrollBarVisibility
    content.UpdateScrollBarVisibility = function()
        if content._customPanel then
            area.scrollbar:Hide()
            return
        end
        baseUpdateVisibility()
    end

    local lastValue = 0
    area.scrollbar.onValueChanged = function(_, value)
        if math.abs(value - lastValue) > 0.1 then
            C_Timer.After(0, function()
                RefreshAllFontStrings(area.scrollChild)
            end)
            lastValue = value
        end
    end

    parent.content = content
    self.contentArea = content
    return content
end

local function CreateSocialButton(parent, config)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(config.width, 21)
    btn:SetPoint(config.point, config.anchor, config.relativePoint, config.offsetX or 0, config.offsetY or 0)

    local texture = btn:CreateTexture(nil, "ARTWORK")
    texture:SetSize(21, 21)
    texture:SetPoint("LEFT", btn, "LEFT", 0, 0)
    texture:SetTexture(config.texturePath)
    texture:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.7)
    texture:SetTexelSnappingBias(0)
    texture:SetSnapToPixelGrid(false)

    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", texture, "RIGHT", Theme.paddingSmall, 1)
    if NRSKNUI.ApplyThemeFont then
        NRSKNUI:ApplyThemeFont(text, "normal")
    else
        text:SetFontObject("GameFontNormal")
    end
    text:SetText(config.text)
    text:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.7)
    text:SetShadowColor(0, 0, 0, 0)

    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnClick", function()
        NRSKNUI:CreatePrompt({
            title = config.promptTitle,
            text = config.link,
            editBox = true,
            editBoxLabel = "CTRL-C to copy",
            texture = {
                path = config.texturePath,
                width = 21,
                height = 21,
                color = { r = Theme.accent[1], g = Theme.accent[2], b = Theme.accent[3] },
            },
        })
    end)

    btn:SetScript("OnEnter", function()
        texture:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        text:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    end)
    btn:SetScript("OnLeave", function()
        texture:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.7)
        text:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.7)
    end)

    return btn, texture, text
end

function GUIFrame:CreateFooter(parent)
    local footer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    footer:SetHeight(Theme.footerHeight)
    footer:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    footer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    footer:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])

    local topBorder = footer:CreateTexture(nil, "BORDER")
    topBorder:SetHeight(Theme.borderSize)
    topBorder:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
    topBorder:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
    topBorder:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4])

    local supportLogoContainer = CreateFrame("Frame", nil, footer)
    supportLogoContainer:SetSize(180, 32)
    supportLogoContainer:SetPoint("LEFT", footer, "LEFT", 0, 0)

    local logoTwitch, logoTwitchTexture, logoTwitchText = CreateSocialButton(supportLogoContainer, {
        text = "Twitch",
        width = 62,
        texturePath = "Interface\\AddOns\\NorskenUI\\Media\\SupportLogos\\twitchv2W.png",
        promptTitle = "Support My |cff9146FFTwitch|r",
        link = "www.twitch.tv/norskenwow",
        point = "LEFT",
        anchor = supportLogoContainer,
        relativePoint = "LEFT",
        offsetX = Theme.paddingMedium,
    })
    footer.logoTwitchTexture = logoTwitchTexture
    footer.logoTwitchText = logoTwitchText

    local logoDiscord, logoDiscordTexture, logoDiscordText = CreateSocialButton(supportLogoContainer, {
        text = "Discord",
        width = 68,
        texturePath = "Interface\\AddOns\\NorskenUI\\Media\\SupportLogos\\discordv2W.png",
        promptTitle = "Join My |cff5865F2Discord|r",
        link = "https://discord.com/invite/23bS8pHfuX",
        point = "LEFT",
        anchor = logoTwitch,
        relativePoint = "RIGHT",
        offsetX = Theme.paddingMedium,
    })
    footer.logoDiscordTexture = logoDiscordTexture
    footer.logoDiscordText = logoDiscordText

    local logoGitHub, logoGitHubTexture, logoGitHubText = CreateSocialButton(supportLogoContainer, {
        text = "GitHub",
        width = 68,
        texturePath = "Interface\\AddOns\\NorskenUI\\Media\\SupportLogos\\github2W.png",
        promptTitle = "Support My |cffffffffGitHub|r",
        link = "https://github.com/Nrsken/NorskenUI",
        point = "LEFT",
        anchor = logoDiscord,
        relativePoint = "RIGHT",
        offsetX = Theme.paddingMedium,
    })
    footer.logoGitHubTexture = logoGitHubTexture
    footer.logoGitHubText = logoGitHubText

    local handle = CreateFrame("Button", nil, footer)
    handle:SetSize(23, 23)
    handle:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -2, 2)
    handle:EnableMouse(true)

    local tex = handle:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomResizeHandle23px.png")
    tex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.6)
    tex:SetTexelSnappingBias(0)
    tex:SetSnapToPixelGrid(false)

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
            if GUIFrame.sidebar and GUIFrame.sidebar.UpdateScrollBarVisibility then
                C_Timer.After(0.05, GUIFrame.sidebar.UpdateScrollBarVisibility)
            end
            GUIFrame:SaveFramePosition()
        end
    end)

    handle:SetScript("OnEnter", function()
        tex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    end)
    handle:SetScript("OnLeave", function()
        tex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.6)
    end)

    footer:EnableMouse(true)
    footer:RegisterForDrag("LeftButton")
    footer:SetScript("OnDragStart", function()
        parent:StartMoving()
    end)
    footer:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        GUIFrame:SaveFramePosition()
    end)

    parent.footer = footer
    self.footer = footer
    return footer
end

function GUIFrame:RefreshContent()
    if not self.contentArea then return end

    if self.contentArea._customPanel then
        self.contentArea._customPanel:Hide()
        self.contentArea._customPanel:SetParent(nil)
        self.contentArea._customPanel = nil
    end

    local itemId = self.selectedSidebarItem
    if not itemId then
        itemId = "HomePage"
    end

    if itemId and self.PanelBuilders and self.PanelBuilders[itemId] then
        if self.contentArea.scrollFrame then
            self.contentArea.scrollFrame:Hide()
        end
        if self.contentArea.scrollbar then
            self.contentArea.scrollbar:Hide()
        end

        local ok, panel = pcall(self.PanelBuilders[itemId], self.contentArea)
        if ok and panel then
            self.contentArea._customPanel = panel
        elseif not ok then
            if self.contentArea.scrollFrame then
                self.contentArea.scrollFrame:Show()
            end
            if self.contentArea.scrollbar then
                self.contentArea.scrollbar:Show()
            end
            local scrollChild = self.contentArea.scrollChild
            local errorCard = self:CreateCard(scrollChild, "Error", Theme.paddingMedium)
            local errorMsg = errorCard:AddLabel("Panel builder failed: " .. tostring(panel))
            errorMsg:SetTextColor(Theme.error[1], Theme.error[2], Theme.error[3], 1)
            scrollChild:SetHeight(errorCard:GetContentHeight() + Theme.paddingLarge)
        end
        return
    end

    if self.contentArea.scrollFrame then
        self.contentArea.scrollFrame:Show()
    end
    if self.contentArea.UpdateScrollBarVisibility then
        self.contentArea.UpdateScrollBarVisibility()
    end

    local scrollChild = self.contentArea.scrollChild

    for _, region in ipairs({ scrollChild:GetRegions() }) do
        if region:GetObjectType() == "FontString" or region:GetObjectType() == "Texture" then
            region:Hide()
        end
    end

    for _, child in ipairs({ scrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    local yOffset = Theme.paddingSmall

    if itemId and self.ContentBuilders[itemId] then
        self:ClearWidgetRegistry(itemId)
        self.currentBuildingPageId = itemId
        local ok, result = pcall(self.ContentBuilders[itemId], scrollChild, yOffset)
        self.currentBuildingPageId = nil
        if ok then
            if result then
                yOffset = result
            end
        else
            for _, child in ipairs({ scrollChild:GetChildren() }) do
                child:Hide()
                child:SetParent(nil)
            end
            yOffset = Theme.paddingSmall

            local errorCard = self:CreateCard(scrollChild, "Error", yOffset)

            local errorLabel = errorCard.content:CreateFontString(nil, "OVERLAY")
            errorLabel:SetPoint("TOPLEFT", errorCard.content, "TOPLEFT", 0, -errorCard.currentY)
            errorLabel:SetPoint("TOPRIGHT", errorCard.content, "TOPRIGHT", 0, -errorCard.currentY)
            errorLabel:SetJustifyH("LEFT")
            errorLabel:SetJustifyV("TOP")
            errorLabel:SetWordWrap(true)
            errorLabel:SetNonSpaceWrap(true)
            errorLabel:SetSpacing(2)
            NRSKNUI:ApplyThemeFont(errorLabel, "normal")
            errorLabel:SetText(tostring(result))
            errorLabel:SetTextColor(Theme.error[1], Theme.error[2], Theme.error[3], 1)

            local textHeight = errorLabel:GetStringHeight() or 20
            errorCard.currentY = errorCard.currentY + textHeight + Theme.paddingMedium
            errorCard.content:SetHeight(errorCard.currentY)
            errorCard:UpdateHeight()

            yOffset = errorCard:GetNextOffset()
        end
    else
        local card = self:CreateCard(scrollChild, "Coming Soon", yOffset)
        card:AddLabel("This section is under construction.")
        card:AddSpacing(Theme.paddingSmall)
        yOffset = card:GetNextOffset()
    end

    scrollChild:SetHeight(yOffset)
    if self.contentArea.UpdateScrollbar then
        self.contentArea.UpdateScrollbar()
    end
end

function GUIFrame:Show()
    if self._isShowing then return end
    self._isShowing = true

    if InCombatLockdown() then
        NRSKNUI:Print("Options will open after combat ends.")
        self.reopenAfterCombat = true
        self._isShowing = false
        return
    end

    local isFirstCreate = not self.mainFrame
    if isFirstCreate then
        self:CreateMainFrame()
        GUIFrame:InitializeSidebarExpansion()
        C_Timer.After(0.1, function()
            self:PreBuildAllPagesForSearch()
        end)
    end

    self:RestoreFramePosition()
    self.mainFrame:Show()
    self.mainFrame:Raise()
    NRSKNUI.GUIOpen = true

    if NRSKNUI.PreviewManager then
        NRSKNUI.PreviewManager:SetGUIOpen(true)
    end

    self:RefreshSidebar()

    if self.shortcutBtn then
        self.shortcutBtn:Show()
    end

    self._isShowing = false

    C_Timer.After(0, function()
        if self.mainFrame and self.mainFrame:IsShown() then
            if self.sidebar then
                local sidebarWidth = self.sidebar:GetWidth()
                if sidebarWidth and sidebarWidth > 0 and self.sidebar.scrollChild then
                    local newWidth = sidebarWidth - Theme.paddingSmall * 2 - 16
                    self.sidebar.scrollChild:SetWidth(newWidth)
                end
            end
            self.sidebarRefreshPending = false
            self:RefreshSidebarImmediate()
            self:RefreshContent()
            if self.contentArea and self.contentArea.scrollChild then
                RefreshAllFontStrings(self.contentArea.scrollChild)
            end
        end
    end)
end

function GUIFrame:Hide()
    if self.mainFrame then
        if self.shortcutBtn then
            self.shortcutBtn:Hide()
        end
        self.mainFrame:Hide()
    else
        NRSKNUI.GUIOpen = false
        if NRSKNUI.PreviewManager then
            NRSKNUI.PreviewManager:SetGUIOpen(false)
        end
    end
end

---Toggles the visibility of the GUI frame.
function GUIFrame:Toggle()
    if self.mainFrame and self.mainFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function GUIFrame:IsShown()
    return self.mainFrame and self.mainFrame:IsShown()
end

GUIFrame.sessionState = GUIFrame.sessionState or {
    scrollPositions = {},
    selectedTab = "systems",
    selectedSidebarItem = nil,
    sidebarExpanded = nil,
}

function GUIFrame:SaveSessionState()
    if not self.mainFrame then return end

    if self.sidebar and self.sidebar.scrollFrame and self.selectedTab then
        local scrollValue = self.sidebar.scrollFrame:GetVerticalScroll()
        self.sessionState.scrollPositions[self.selectedTab] = scrollValue
    end

    self.sessionState.selectedTab = self.selectedTab
    self.sessionState.selectedSidebarItem = self.selectedSidebarItem

    if self.sidebarExpanded then
        self.sessionState.sidebarExpanded = {}
        for sectionId, expanded in pairs(self.sidebarExpanded) do
            self.sessionState.sidebarExpanded[sectionId] = expanded
        end
    end
end

function GUIFrame:RestoreSessionState()
    if not self.sessionState then return end

    if self.sessionState.selectedTab then
        self.selectedTab = self.sessionState.selectedTab
    end

    if self.sessionState.sidebarExpanded then
        for sectionId, expanded in pairs(self.sessionState.sidebarExpanded) do
            self.sidebarExpanded[sectionId] = expanded
        end
    end

    if self.sessionState.selectedSidebarItem then
        self.selectedSidebarItem = self.sessionState.selectedSidebarItem
        self:EnsureParentSectionExpanded(self.selectedSidebarItem)
    end

    C_Timer.After(0.01, function()
        if self.sidebar and self.sidebar.scrollFrame and self.selectedTab then
            local scrollValue = self.sessionState.scrollPositions[self.selectedTab]
            if scrollValue then
                self.sidebar.scrollFrame:SetVerticalScroll(scrollValue)
            end
        end
    end)
end

function GUIFrame:SaveFramePosition()
    if not self.mainFrame then return end
    if not NRSKNUI.db or not NRSKNUI.db.global then return end

    local point, _, relPoint, x, y = self.mainFrame:GetPoint()

    NRSKNUI.db.global.GUIState = NRSKNUI.db.global.GUIState or {}
    NRSKNUI.db.global.GUIState.frame = {
        point = point,
        relativePoint = relPoint,
        xOffset = x,
        yOffset = y,
        width = self.mainFrame:GetWidth(),
        height = self.mainFrame:GetHeight(),
    }
    self:SaveSessionState()
end

function GUIFrame:RestoreFramePosition()
    if not self.mainFrame then return end

    local wasShown = self.mainFrame:IsShown()

    local pos = NRSKNUI.db and NRSKNUI.db.global and NRSKNUI.db.global.GUIState and NRSKNUI.db.global.GUIState.frame
    if pos then
        self.mainFrame:ClearAllPoints()
        self.mainFrame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.xOffset or 0,
            pos.yOffset or 50)
        if pos.width and pos.height then
            self.mainFrame:SetSize(pos.width, pos.height)
        end
    end

    if not wasShown then
        self:RestoreSessionState()
    end
end

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if GUIFrame:IsShown() then
            GUIFrame.reopenAfterCombat = true
            GUIFrame:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if GUIFrame.reopenAfterCombat then
            GUIFrame.reopenAfterCombat = nil
            GUIFrame:Show()
        end
    end
end)

-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization
local math = math
local C_Timer = C_Timer
local ipairs = ipairs
local CreateFrame = CreateFrame
local CreateColor = CreateColor
local wipe = wipe

-- Section header pool
GUIFrame.sidebarHeaderPool = {}
GUIFrame.currentExpandedSection = nil

-- Module locals
local headerHeight = 32
local itemHeight = 28

-- Release section headers
function GUIFrame:ReleaseSectionHeaders()
    for _, header in ipairs(self.sidebarHeaderPool or {}) do
        header.inUse = false
        header:Hide()
        header:ClearAllPoints()
    end
end

-- Create section header
function GUIFrame:CreateSectionHeader()
    local ARROW_SIZE = 16
    local arrowTex = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\collapse.tga"

    local header = CreateFrame("Button", nil, UIParent)
    header:SetHeight(headerHeight)
    header:EnableMouse(true)
    header:RegisterForClicks("LeftButtonUp")

    -- Gradiant Mouseover overlay
    local background = header:CreateTexture(nil, "ARTWORK")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 1)
    background:SetGradient("HORIZONTAL", CreateColor(0.3, 0.3, 0.3, 0.25), CreateColor(0.3, 0.3, 0.3, 0))
    background:SetTexelSnappingBias(0)
    background:SetSnapToPixelGrid(false)
    background:Hide()
    header.background = background

    -- Selected overlay
    local selectedOverlay = header:CreateTexture(nil, "ARTWORK")
    selectedOverlay:SetTexture("Interface\\Buttons\\WHITE8X8")
    selectedOverlay:SetBlendMode("ADD")
    selectedOverlay:SetVertexColor(Theme.selectedBg[1], Theme.selectedBg[2], Theme.selectedBg[3],
        Theme.selectedBg[4] or 0.25)
    selectedOverlay:SetAllPoints()
    selectedOverlay:Hide()
    header.selectedOverlay = selectedOverlay

    -- Selected bar - left accent bar
    local selectedBar = header:CreateTexture(nil, "OVERLAY")
    selectedBar:SetWidth(3)
    selectedBar:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    selectedBar:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    selectedBar:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    selectedBar:Hide()
    header.selectedBar = selectedBar

    -- Label
    local fontPath = "Fonts\\FRIZQT__.TTF"
    local fontSize = Theme.fontSizeLarge or 16
    local label = header:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", header, "LEFT", Theme.paddingSmall, 0)
    label:SetFont(fontPath, fontSize, "OUTLINE")
    label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    label:SetShadowColor(0, 0, 0, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    header.label = label

    -- Arrow icon
    local arrow = header:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    arrow:SetPoint("RIGHT", header, "RIGHT", -Theme.paddingSmall, 0)
    arrow:SetTexture(arrowTex)
    arrow:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    arrow:SetTexelSnappingBias(0)
    arrow:SetSnapToPixelGrid(false)
    header.arrow = arrow

    -- Arrow animation setup
    local arrowAnimGroup = arrow:CreateAnimationGroup()
    --arrow:SetRotation(-math.pi / 2)

    local arrowRotation = arrowAnimGroup:CreateAnimation("Rotation")
    arrowRotation:SetDuration(0.18)
    arrowRotation:SetOrigin("CENTER", 0, 0)
    arrowRotation:SetSmoothing("IN_OUT")
    header.arrowAnimGroup = arrowAnimGroup
    header.arrowRotation = arrowRotation

    header.AnimateArrowOpen = function(self)
        if self.isExpanded then return end
        self.arrowAnimGroup:Stop()
        self.arrowRotation:SetRadians(math.pi / 2)
        self.isExpanded = true
        self.arrowAnimGroup:Play()
    end

    header.AnimateArrowClose = function(self)
        if not self.isExpanded then return end
        self.arrowAnimGroup:Stop()
        self.arrowRotation:SetRadians(-math.pi / 2)
        self.isExpanded = false
        self.arrowAnimGroup:Play()
    end

    arrowAnimGroup:SetScript("OnFinished", function()
        if header.isExpanded then
            arrow:SetRotation(0)
        else
            arrow:SetRotation(-math.pi / 2)
        end
    end)

    header.SetArrowState = function(self, expanded)
        self.arrowAnimGroup:Stop()
        self.isExpanded = expanded

        if expanded then
            self.arrow:SetRotation(0)
        else
            self.arrow:SetRotation(-math.pi / 2)
        end
    end

    -- Hover effects
    header:SetScript("OnEnter", function(self)
        if not header.isExpanded then
            background:Show()
        end
    end)

    header:SetScript("OnLeave", function(self)
        if not header.isExpanded then
            background:Hide()
        end
    end)

    -- Click handler
    header:SetScript("OnClick", function(self)
        GUIFrame:ToggleSection(self.sectionId)
    end)

    return header
end

-- Get section header from pool
function GUIFrame:GetSectionHeader()
    for _, header in ipairs(self.sidebarHeaderPool) do
        if not header.inUse then
            header.inUse = true
            header:Show()
            return header
        end
    end

    local header = self:CreateSectionHeader()
    header.inUse = true
    table.insert(self.sidebarHeaderPool, header)
    return header
end

local initSideBar = false
function GUIFrame:InitializeSidebarExpansion()
    if initSideBar then return end
    wipe(self.sidebarExpanded)

    local config = self.SidebarConfig[self.selectedTab]
    if not config then return end

    for _, section in ipairs(config) do
        if section.type == "header" and section.defaultExpanded then
            self.sidebarExpanded[section.id] = true
        end
    end
    initSideBar = true
end

-- Configure section header
local arrowInitPos = false
function GUIFrame:ConfigureSectionHeader(header, config, yOffset, isExpanded)
    local scrollChild = self.sidebar.scrollChild
    local horizontalPadding = Theme.paddingSmall

    header:SetParent(scrollChild)
    header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", horizontalPadding, -yOffset)
    header:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -horizontalPadding, -yOffset)
    header.sectionId = config.id
    header.label:SetText(config.text or "")

    -- Store expanded state
    header.isExpanded = isExpanded

    -- Set arrow rotation based on expanded state once
    if not arrowInitPos then
        C_Timer.After(0.1, function()
            header:SetArrowState(isExpanded)
            arrowInitPos = true
        end)
    end
    header.background:Hide()
    return header
end

function GUIFrame:GetHeaderBySectionId(sectionId)
    for _, header in ipairs(self.sidebarHeaderPool) do
        if header.inUse and header.sectionId == sectionId then
            return header
        end
    end
end

-- Toggle section expand/collapse (allows multiple sections open)
function GUIFrame:ToggleSection(sectionId)
    local wasExpanded = self.sidebarExpanded[sectionId]

    -- Toggle this section
    if wasExpanded then
        -- Collapse this section
        local header = self:GetHeaderBySectionId(sectionId)
        if header then
            header:AnimateArrowClose()
        end
        self.sidebarExpanded[sectionId] = nil
    else
        -- Expand this section
        local header = self:GetHeaderBySectionId(sectionId)
        if header then
            header:AnimateArrowOpen()
        end

        self.sidebarExpanded[sectionId] = true
    end
    -- Refresh sidebar (rebuilds the visual items)
    C_Timer.After(0.01, function()
        self:RefreshSidebar()
        self:RefreshContent()
    end)
end

-- Static sidebar item pool
GUIFrame.staticSidebarItemPool = {}

-- Get static sidebar item from pool or create new
function GUIFrame:GetStaticSidebarItem()
    for _, item in ipairs(self.staticSidebarItemPool) do
        if not item.inUse then
            item.inUse = true
            item:Show()
            return item
        end
    end

    local item = self:CreateStaticSidebarItem()
    item.inUse = true
    table.insert(self.staticSidebarItemPool, item)
    return item
end

-- Release all static sidebar items back to pool
function GUIFrame:ReleaseStaticSidebarItems()
    for _, item in ipairs(self.staticSidebarItemPool) do
        item.inUse = false
        item:Hide()
        item:ClearAllPoints()
        item.id = nil
        item.selectedOverlay:Hide()
        item.selectedBar:Hide()
    end
end

-- Create a static sidebar item
function GUIFrame:CreateStaticSidebarItem()
    local item = CreateFrame("Button", nil, UIParent)
    item:SetHeight(itemHeight)
    item:EnableMouse(true)
    item:RegisterForClicks("LeftButtonUp")
    local r, g, b = Theme.accent[1], Theme.accent[2], Theme.accent[3]

    -- Gradiant Mouseover overlay
    local background = item:CreateTexture(nil, "ARTWORK")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 1)
    background:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.25), CreateColor(r, g, b, 0))
    background:SetTexelSnappingBias(0)
    background:SetSnapToPixelGrid(false)
    background:Hide()
    item.background = background

    -- Gradiant Overlay Texture
    local selectedOverlay = item:CreateTexture(nil, "ARTWORK")
    selectedOverlay:SetAllPoints()
    selectedOverlay:SetColorTexture(1, 1, 1, 1)
    selectedOverlay:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.25), CreateColor(r, g, b, 0))
    selectedOverlay:SetTexelSnappingBias(0)
    selectedOverlay:SetSnapToPixelGrid(false)
    selectedOverlay:Hide()
    item.selectedOverlay = selectedOverlay

    -- Selected bar - left accent bar
    local selectedBar = item:CreateTexture(nil, "OVERLAY")
    selectedBar:SetWidth(1)
    selectedBar:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 5)
    selectedBar:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, -7)
    selectedBar:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    selectedBar:Hide()
    item.selectedBar = selectedBar

    -- Label - LEFT aligned with extra padding for indent
    local fontPath = "Fonts\\FRIZQT__.TTF"
    local fontSize = Theme.fontSizeNormal or 12
    local label = item:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", item, "LEFT", 12, 0)
    label:SetPoint("RIGHT", item, "RIGHT", -Theme.paddingSmall, 0)
    label:SetFont(fontPath, fontSize, "OUTLINE")
    label:SetShadowColor(0, 0, 0, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    item.label = label

    -- Hover/click handlers
    item:SetScript("OnEnter", function(self)
        if self.id ~= GUIFrame.selectedSidebarItem then
            background:Show()
            self.label:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3], 1)
        end
    end)

    item:SetScript("OnLeave", function(self)
        if self.id ~= GUIFrame.selectedSidebarItem then
            background:Hide()
            self.label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        end
    end)

    item:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            GUIFrame:SelectSidebarItem(self.id)
        end
    end)

    return item
end

-- Create Sidebar
function GUIFrame:CreateSidebar(parent)
    local sidebar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -Theme.headerHeight)
    sidebar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, Theme.footerHeight)
    sidebar:SetPoint("RIGHT", parent.content or parent, "LEFT", 0, 0)
    sidebar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    sidebar:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])

    local rightBorder = sidebar:CreateTexture(nil, "BORDER")
    rightBorder:SetWidth(Theme.borderSize)
    rightBorder:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
    rightBorder:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)
    rightBorder:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4])

    local scrollFrame = CreateFrame("ScrollFrame", nil, sidebar, "UIPanelScrollFrameTemplate")
    scrollFrame:SetFrameLevel(sidebar:GetFrameLevel() + 5)

    local scrollbarWidth = Theme.scrollbarWidth or 16
    scrollFrame:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, -Theme.paddingSmall)
    scrollFrame:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -Theme.borderSize, Theme.paddingSmall)
    scrollFrame:SetClipsChildren(true)
    sidebar.scrollFrameDefaultTop = -Theme.paddingSmall

    if scrollFrame.ScrollBar then
        local sb = scrollFrame.ScrollBar
        sb:ClearAllPoints()
        sb:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -2, -16)
        sb:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -2, 16)
        sb:SetWidth(scrollbarWidth - 4)
        if sb.Background then sb.Background:Hide() end
        if sb.Top then sb.Top:Hide() end
        if sb.Middle then sb.Middle:Hide() end
        if sb.Bottom then sb.Bottom:Hide() end
        if sb.trackBG then sb.trackBG:Hide() end
        if sb.ScrollUpButton then sb.ScrollUpButton:Hide() end
        if sb.ScrollDownButton then sb.ScrollDownButton:Hide() end
        sb:SetAlpha(0)
        local isSnapping = false
        local PIXEL_STEP = 8 / 15
        sb:HookScript("OnValueChanged", function(self, value)
            if isSnapping then return end
            local scale = scrollFrame:GetEffectiveScale()
            local screenPixels = value * scale
            local snappedPixels = math.floor(screenPixels / PIXEL_STEP + 0.5) * PIXEL_STEP
            local snappedValue = snappedPixels / scale
            if math.abs(value - snappedValue) > 0.001 then
                isSnapping = true
                self:SetValue(snappedValue)
                isSnapping = false
            end
        end)
    end
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetHeight(1)
    scrollChild:SetFrameLevel(scrollFrame:GetFrameLevel() + 1)
    scrollFrame:SetScrollChild(scrollChild)
    local sidebarScrollbarVisible = false
    local function UpdateSidebarScrollChildWidth()
        local sidebarActualWidth = sidebar:GetWidth()
        if sidebarActualWidth and sidebarActualWidth > 0 then
            if sidebarScrollbarVisible then
                scrollChild:SetWidth(sidebarActualWidth - Theme.borderSize - scrollbarWidth)
            else
                scrollChild:SetWidth(sidebarActualWidth - Theme.borderSize)
            end
        end
    end
    local function UpdateSidebarScrollBarVisibility()
        if scrollFrame.ScrollBar then
            local contentHeight = scrollChild:GetHeight()
            local frameHeight = scrollFrame:GetHeight()
            local needsScrollbar = contentHeight > frameHeight
            sidebarScrollbarVisible = needsScrollbar
            scrollFrame.ScrollBar:SetAlpha(needsScrollbar and 1 or 0)
            scrollFrame.ScrollBar:EnableMouse(needsScrollbar)
            UpdateSidebarScrollChildWidth()
        end
    end
    sidebar.UpdateScrollBarVisibility = UpdateSidebarScrollBarVisibility
    scrollFrame:HookScript("OnScrollRangeChanged", UpdateSidebarScrollBarVisibility)
    scrollChild:HookScript("OnSizeChanged", UpdateSidebarScrollBarVisibility)
    scrollFrame:HookScript("OnSizeChanged", UpdateSidebarScrollBarVisibility)
    scrollFrame:HookScript("OnShow", function()
        C_Timer.After(0, UpdateSidebarScrollBarVisibility)
    end)
    sidebar:SetScript("OnSizeChanged", function()
        UpdateSidebarScrollChildWidth()
    end)
    scrollChild:SetWidth(Theme.sidebarWidth - Theme.borderSize)
    sidebar.scrollFrame = scrollFrame
    sidebar.scrollChild = scrollChild
    parent.sidebar = sidebar
    self.sidebar = sidebar
    return sidebar
end

-- Select Sidebar Item
function GUIFrame:SelectSidebarItem(itemId)
    self.selectedSidebarItem = itemId
    for _, item in ipairs(self.staticSidebarItemPool) do
        if item.inUse then
            if item.id == itemId then
                item.selectedOverlay:Show()
                item.background:Hide()
                item.label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], Theme.accent[4] or 1)
            else
                item.selectedOverlay:Hide()
                item.background:Hide()
                item.label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
            end
        end
    end
    self:RefreshContent()
end

-- Sidebar state
GUIFrame.sidebarExpanded = GUIFrame.sidebarExpanded or {}
GUIFrame.sidebarRefreshPending = false
GUIFrame.SIDEBAR_THROTTLE = 0.05

-- Throttled refresh
function GUIFrame:RefreshSidebar()
    if self.sidebarRefreshPending then return end
    self.sidebarRefreshPending = true
    C_Timer.After(self.SIDEBAR_THROTTLE, function()
        self.sidebarRefreshPending = false
        self:RefreshSidebarImmediate()
    end)
end

-- Check if a sidebar item's parent section is currently expanded
function GUIFrame:IsItemParentExpanded(itemId)
    if not itemId then return false end
    local config = self.SidebarConfig[self.selectedTab]
    if not config then return false end
    for _, section in ipairs(config) do
        if section.type == "header" and section.items then
            for _, item in ipairs(section.items) do
                if item.id == itemId then
                    -- Found the item, check if its parent section is expanded
                    return self.sidebarExpanded[section.id] == true
                end
            end
        end
    end
    return false
end

-- Immediate refresh
function GUIFrame:RefreshSidebarImmediate()
    if not self.sidebar then return end
    self:ReleaseStaticSidebarItems()
    self:ReleaseSectionHeaders()
    local scrollChild = self.sidebar.scrollChild
    local scrollFrame = self.sidebar.scrollFrame
    for _, region in ipairs({ scrollChild:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            region:Hide()
            region:SetText("")
        end
    end
    local config = self.SidebarConfig[self.selectedTab]
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", self.sidebar, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", self.sidebar, "BOTTOMRIGHT", -Theme.borderSize, Theme.paddingSmall)
    if not config then
        scrollChild:SetHeight(1)
        return
    end
    local yOffset = Theme.paddingSmall
    local itemSpacing = 2
    local sectionSpacing = 2
    local itemIndent = 8
    if self.sidebarEmptyText then
        self.sidebarEmptyText:Hide()
    end
    -- Build sections
    for _, sectionConfig in ipairs(config) do
        if sectionConfig.type == "header" then
            local isExpanded = self.sidebarExpanded[sectionConfig.id]
            local header = self:GetSectionHeader()
            self:ConfigureSectionHeader(header, sectionConfig, yOffset, isExpanded)
            yOffset = yOffset + headerHeight
            if isExpanded and sectionConfig.items then
                for _, itemConfig in ipairs(sectionConfig.items) do
                    local item = self:GetStaticSidebarItem()
                    item:SetParent(scrollChild)
                    local horizontalPadding = Theme.paddingSmall
                    item:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", horizontalPadding + itemIndent, -yOffset)
                    item:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -horizontalPadding, -yOffset)
                    item.id = itemConfig.id
                    item.label:SetText(itemConfig.text or "")
                    item.selectedBar:Show()
                    if itemConfig.id == self.selectedSidebarItem then
                        item.selectedOverlay:Show()
                        item.background:Hide()
                        item.label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], Theme.accent[4] or 1)
                    else
                        item.selectedOverlay:Hide()
                        item.background:Hide()
                        item.label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
                    end
                    yOffset = yOffset + itemHeight + itemSpacing
                end
            end
            yOffset = yOffset + sectionSpacing
        end
    end
    scrollChild:SetHeight(yOffset + Theme.paddingSmall)
end

function GUIFrame:OpenPage(itemId, sectionId, context)
    self:Show()

    if sectionId then
        self.sidebarExpanded[sectionId] = true
        self:RefreshSidebar()
    end

    -- Store context for granular navigation
    -- Content builders can check this and apply it, then clear it
    self.pendingContext = context

    self:SelectSidebarItem(itemId)
end

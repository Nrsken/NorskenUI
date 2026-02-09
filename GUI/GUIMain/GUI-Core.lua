-- NorskenUI namespace
local _, NRSKNUI = ...
NRSKNUI.GUIFrame = NRSKNUI.GUIFrame or {}
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

-- Localization Setup
local type = type
local CreateFrame = CreateFrame
local tostring = tostring
local error = error
local pcall = pcall
local table_insert = table.insert
local wipe = wipe
local pairs = pairs
local print = print
local ipairs = ipairs

-- Content Registry System
GUIFrame.ContentBuilders = {}
GUIFrame.PanelBuilders = {}
GUIFrame.contentCleanupCallbacks = {}

-- RegisterContent: Registers a content builder function for a given sidebar item ID
function GUIFrame:RegisterContent(itemId, builderFunc)
    if type(builderFunc) ~= "function" then
        error("RegisterContent: builderFunc must be a function for item: " .. tostring(itemId))
    end
    self.ContentBuilders[itemId] = builderFunc
end

-- Unregister a content builder
function GUIFrame:UnregisterContent(itemId)
    self.ContentBuilders[itemId] = nil
end

-- Check if content builder exists
function GUIFrame:HasContent(itemId)
    return self.ContentBuilders[itemId] ~= nil
end

function GUIFrame:RegisterPanel(itemId, builderFunc)
    if type(builderFunc) ~= "function" then
        error("RegisterPanel: builderFunc must be a function for item: " .. tostring(itemId))
    end
    self.PanelBuilders[itemId] = builderFunc
end

-- Unregister a panel builder
function GUIFrame:UnregisterPanel(itemId)
    self.PanelBuilders[itemId] = nil
end

-- Check if panel builder exists
function GUIFrame:HasPanel(itemId)
    return self.PanelBuilders[itemId] ~= nil
end

function GUIFrame:RegisterContentCleanup(key, callback)
    if type(key) == "string" and type(callback) == "function" then
        self.contentCleanupCallbacks[key] = callback
    end
end

-- Unregister a cleanup callback
function GUIFrame:UnregisterContentCleanup(key)
    if key then
        self.contentCleanupCallbacks[key] = nil
    end
end

-- Fire all content cleanup callbacks (called before changing content)
GUIFrame.onCloseCallbacks = {}

-- Register an on-close callback
function GUIFrame:RegisterOnCloseCallback(key, callback)
    if type(key) == "string" and type(callback) == "function" then
        self.onCloseCallbacks[key] = callback
    end
end

-- Unregister an on-close callback
function GUIFrame:UnregisterOnCloseCallback(key)
    if key then
        self.onCloseCallbacks[key] = nil
    end
end

-- Fire all on-close callbacks, called from GUIFrame:Hide
function GUIFrame:FireOnCloseCallbacks()
    for key, callback in pairs(self.onCloseCallbacks) do
        local ok, err = pcall(callback)
        if not ok and NRSKNUI.debug then
            print("|cFFFF0000[NRSKNUI]|r On-close callback '" .. key .. "' failed: " .. tostring(err))
        end
    end
end

-- Card widget system
function GUIFrame:CreateCard(parent, title, yOffset, width)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:EnableMouse(false)

    -- Use anchor-based width so cards auto-resize when parent (scrollChild) resizes
    if width then
        card:SetWidth(width)
        card:SetPoint("TOPLEFT", parent, "TOPLEFT", Theme.paddingSmall, -(yOffset or 0) + Theme.paddingSmall)
    else
        -- Anchor both left and right to parent for dynamic width
        card:SetPoint("TOPLEFT", parent, "TOPLEFT", Theme.paddingSmall, -(yOffset or 0) + Theme.paddingSmall)
        card:SetPoint("RIGHT", parent, "RIGHT", -Theme.paddingSmall, 0)
    end

    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = Theme.borderSize,
    })
    card:SetBackdropColor(Theme.bgLight[1], Theme.bgLight[2], Theme.bgLight[3], Theme.bgLight[4])
    card:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4])

    card.contentHeight = 0
    card.rows = {}

    -- Header
    local headerHeight = 0
    if title and title ~= "" then
        headerHeight = 32

        local header = CreateFrame("Frame", nil, card, "BackdropTemplate")
        header:SetHeight(headerHeight)
        header:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0)
        header:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = Theme.borderSize,
        })
        header:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])
        header:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4])
        card.header = header

        local titleText = header:CreateFontString(nil, "OVERLAY")
        titleText:SetPoint("LEFT", header, "LEFT", Theme.paddingMedium, 0)
        NRSKNUI:ApplyThemeFont(titleText, "large")
        titleText:SetText(title)
        titleText:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        card.titleText = titleText
    end
    card.headerHeight = headerHeight

    -- Content container
    local content = CreateFrame("Frame", nil, card)
    content:SetPoint("TOPLEFT", card, "TOPLEFT", Theme.paddingMedium, -headerHeight - Theme.paddingMedium)
    content:SetPoint("TOPRIGHT", card, "TOPRIGHT", -Theme.paddingMedium, -headerHeight - Theme.paddingMedium)
    content:SetHeight(1)
    content:EnableMouse(false)
    card.content = content
    card.currentY = 0

    -- Card Methods
    function card:AddRow(widget, height, spacing)
        height = height or widget:GetHeight() or 24
        spacing = spacing or Theme.paddingSmall

        widget:SetParent(self.content)
        widget:ClearAllPoints()
        widget:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -self.currentY)
        widget:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -self.currentY)

        self.currentY = self.currentY + height + spacing
        table_insert(self.rows, widget)

        self.content:SetHeight(self.currentY)
        self:UpdateHeight()

        return widget
    end

    function card:AddLabel(text, fontObject)
        local label = self.content:CreateFontString(nil, "OVERLAY")
        label:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -self.currentY)
        label:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -self.currentY)
        label:SetJustifyH("LEFT")
        NRSKNUI:ApplyThemeFont(label, "normal")
        label:SetText(text)
        label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)

        local height = label:GetStringHeight() or 14
        self.currentY = self.currentY + height + Theme.paddingSmall
        self.content:SetHeight(self.currentY)
        self:UpdateHeight()

        return label
    end

    function card:AddSeparator()
        local sep = self.content:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(Theme.borderSize)
        sep:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -self.currentY - Theme.paddingSmall)
        sep:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -self.currentY - Theme.paddingSmall)
        sep:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], 0.5)

        self.currentY = self.currentY + Theme.borderSize + Theme.paddingSmall * 2
        self.content:SetHeight(self.currentY)
        self:UpdateHeight()

        return sep
    end

    function card:AddSpacing(amount)
        amount = amount or Theme.paddingMedium
        self.currentY = self.currentY + amount
        self.content:SetHeight(self.currentY)
        self:UpdateHeight()
    end

    function card:UpdateHeight()
        local totalHeight = self.headerHeight + self.currentY + Theme.paddingMedium * 2
        self:SetHeight(totalHeight)
        self.contentHeight = totalHeight
    end

    function card:GetContentHeight()
        return self.contentHeight
    end

    function card:Reset()
        for _, row in ipairs(self.rows) do
            if row.Hide then row:Hide() end
            if row.SetParent then row:SetParent(nil) end
        end
        wipe(self.rows)
        self.currentY = 0
        self.contentHeight = 0
        self.content:SetHeight(1)
        self:SetHeight(self.headerHeight + Theme.paddingMedium * 2)
    end

    function card:SetEnabled(enabled)
        if enabled then
            card:SetAlpha(1)
            card.header:SetAlpha(1)
            card.titleText:SetAlpha(1)
        else
            card:SetAlpha(0.5)
            card.header:SetAlpha(0.5)
            card.titleText:SetAlpha(0.5)
        end
    end

    card:UpdateHeight()
    return card
end

-- Row widget system
function GUIFrame:CreateRow(parent, height)
    height = height or 24
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(height)
    row:EnableMouse(false)
    row.widgets = {}
    row.nextX = 0

    -- Usage: row:AddWidget(widget, 0.5, nil, 5, -2) for 5px right, 2px down offset
    -- If widget has .explicitHeight set, that height is preserved instead of using row height
    function row:AddWidget(widget, widthPct, spacing, xOffset, yOffset)
        widthPct = widthPct or 0.5
        spacing = spacing or Theme.paddingSmall
        xOffset = xOffset or 0
        yOffset = yOffset or 0

        widget:SetParent(self)
        widget:ClearAllPoints()
        widget:SetPoint("TOPLEFT", self, "TOPLEFT", self.nextX + xOffset, yOffset)
        -- Respect explicit height if set, otherwise use row height
        if not widget.explicitHeight then
            widget:SetHeight(height)
        end

        widget._widthPct = widthPct
        widget._spacing = spacing
        widget._xOffset = xOffset
        widget._yOffset = yOffset
        table_insert(self.widgets, widget)
        self.nextX = self.nextX + 10
    end

    row:SetScript("OnSizeChanged", function(self, width)
        local x = 0
        for i, widget in ipairs(self.widgets) do
            local widgetWidth = width * widget._widthPct - (widget._spacing or 0)
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", self, "TOPLEFT", x + (widget._xOffset or 0), widget._yOffset or 0)
            widget:SetWidth(widgetWidth)
            x = x + widgetWidth + (widget._spacing or Theme.paddingSmall)
        end
    end)

    return row
end

function GUIFrame:CreateLabeledRow(card, labelText, controlWidth)
    controlWidth = controlWidth or 200
    local rowHeight = 24

    local row = CreateFrame("Frame", nil, card.content)
    row:SetHeight(rowHeight)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -controlWidth - Theme.paddingSmall, 0)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)
    label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    row.label = label

    local control = CreateFrame("Frame", nil, row)
    control:SetSize(controlWidth, rowHeight)
    control:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.control = control

    return row, label, control
end

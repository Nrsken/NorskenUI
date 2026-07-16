---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local table_insert = table.insert
local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs

local ANCHOR_DIRECTIONS = {
    "TOPLEFT", "TOP", "TOPRIGHT",
    "LEFT", "CENTER", "RIGHT",
    "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"
}

local DIRECTION_NAMES = {
    TOPLEFT = "Top Left",
    TOP = "Top",
    TOPRIGHT = "Top Right",
    LEFT = "Left",
    CENTER = "Center",
    RIGHT = "Right",
    BOTTOMLEFT = "Bottom Left",
    BOTTOM = "Bottom",
    BOTTOMRIGHT = "Bottom Right",
}

local ANCHOR_FRAME_TYPES = {
    { key = "SCREEN",      text = "Screen Center" },
    { key = "UIPARENT",    text = "Screen (UIParent)" },
    { key = "SELECTFRAME", text = "Select Frame" },
}

local function CreateAnchorButtons(parent, labelText, value, callback)
    local buttonSize = 10
    local frameWidth = 101
    local frameHeight = 53
    local titleHeight = 18
    local spacing = 2

    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(frameWidth + buttonSize, frameHeight + buttonSize + titleHeight + spacing + 4)

    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOP", container, "TOP", 0, 2)
    label:SetHeight(titleHeight)
    label:SetJustifyH("CENTER")
    NRSKNUI:ApplyThemeFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    container.label = label

    local background = CreateFrame("Frame", nil, container, "BackdropTemplate")
    background:SetSize(frameWidth, frameHeight)
    background:SetPoint("TOP", container, "TOP", 0, -(titleHeight + spacing))
    background:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 1,
    })
    background:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)
    background:SetBackdropBorderColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)
    container.background = background
    container.value = value or "CENTER"

    local buttons = {}
    for _, direction in ipairs(ANCHOR_DIRECTIONS) do
        local button = CreateFrame("Button", nil, container)
        button:SetSize(buttonSize, buttonSize)
        button:SetPoint("CENTER", background, direction)

        local tex = button:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        tex:SetTexelSnappingBias(0)
        tex:SetSnapToPixelGrid(false)
        button.tex = tex
        button.value = direction

        local function UpdateButtonColor()
            if container.value == direction then
                tex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            else
                tex:SetVertexColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)
            end
        end

        button:SetScript("OnClick", function()
            container.value = direction
            for _, btn in pairs(buttons) do
                if container.value == btn.value then
                    btn.tex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                else
                    btn.tex:SetVertexColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)
                end
            end
            if callback then callback(direction) end
        end)

        button:SetScript("OnEnter", function(self)
            if not container.disabled then
                self.tex:SetVertexColor(Theme.accentHover[1], Theme.accentHover[2], Theme.accentHover[3], 1)
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 4)
            GameTooltip:SetText(DIRECTION_NAMES[direction] or direction, Theme.accent[1], Theme.accent[2], Theme.accent[3], 1, false)
            GameTooltip:Show()
        end)

        button:SetScript("OnLeave", function(self)
            if not container.disabled then
                if container.value == direction then
                    self.tex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                else
                    self.tex:SetVertexColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)
                end
            end
            GameTooltip:Hide()
        end)

        UpdateButtonColor()
        buttons[direction] = button
    end
    container.buttons = buttons

    function container:SetValue(val)
        self.value = val
        for direction, btn in pairs(self.buttons) do
            if val == direction then
                btn.tex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            else
                btn.tex:SetVertexColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)
            end
        end
    end

    function container:GetValue()
        return self.value
    end

    function container:SetEnabled(enabled)
        self.disabled = not enabled
        if enabled then
            self:SetAlpha(1)
            self.label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            self.background:SetBackdropBorderColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)
            for direction, btn in pairs(self.buttons) do
                btn:EnableMouse(true)
                if self.value == direction then
                    btn.tex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                else
                    btn.tex:SetVertexColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)
                end
            end
        else
            self:SetAlpha(1)
            self.label:SetTextColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 0.5)
            self.background:SetBackdropBorderColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 0.3)
            for _, btn in pairs(self.buttons) do
                btn:EnableMouse(false)
                btn.tex:SetVertexColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 0.3)
            end
        end
    end

    return container
end

---9-point anchor selector + offset sliders
---```lua
---config = {
---    title = string,              -- Card header (default: "Position Settings")
---    db = table,                  -- Database table to read/write (required)
---    dbKeys = table,              -- Custom keys for db fields
---    defaults = table,            -- Default position values
---    onChangeCallback = function, -- Called when any value changes
---    showAnchorFrameType = boolean, -- Show anchor type dropdown (default: true)
---    showStrata = boolean,        -- Show strata dropdown (default: false)
---    disableAnchorFrom = boolean, -- Disable "Anchor From" widget (default: false)
---    sliderRange = {min, max},    -- X/Y slider range (default: {-1000, 1000})
---    contextOptions = table,      -- Optional: {{key = "party", text = "Party", positionKey = "PartyPosition"}, ...}
---    defaultContext = string,     -- Optional: default context key (default: first option)
---    splitToggleKey = string,     -- Optional: db key for split positioning toggle (enables toggle + dropdown)
---}
---```
---@param scrollChild Frame
---@param yOffset number
---@param config NUIPositionCardConfig
---@return NUICard card
---@return number newYOffset
---@return NUIWidget[] positionWidgets
function GUIFrame:CreatePositionCard(scrollChild, yOffset, config)
    config = config or {}
    local title = config.title or "Position Settings"
    local db = config.db
    local dbKeys = config.dbKeys or {}
    local defaults = config.defaults or {}
    local onChange = config.onChangeCallback
    local showAnchorFrameType = config.showAnchorFrameType ~= false
    local showStrata = config.showStrata == true
    local sliderRange = config.sliderRange or { -2000, 2000 }
    local contextOptions = config.contextOptions
    local defaultContext = config.defaultContext
    local splitToggleKey = config.splitToggleKey
    local onContextChange = config.onContextChange
    local disableAnchorFrom = config.disableAnchorFrom == true

    local keys = {
        anchorFrameType = dbKeys.anchorFrameType or "anchorFrameType",
        anchorFrameFrame = dbKeys.anchorFrameFrame or "ParentFrame",
        selfPoint = dbKeys.selfPoint or "AnchorFrom",
        anchorPoint = dbKeys.anchorPoint or "AnchorTo",
        xOffset = dbKeys.xOffset or "XOffset",
        yOffset = dbKeys.yOffset or "YOffset",
        strata = dbKeys.strata or "Strata",
    }

    local rootKeys = {
        [keys.anchorFrameType] = true,
        [keys.anchorFrameFrame] = true,
        [keys.strata] = true,
    }

    local currentContext = defaultContext
    local currentPositionKey = "Position"

    if contextOptions and #contextOptions > 0 then
        if not currentContext then
            currentContext = contextOptions[1].key
        end
        for _, opt in ipairs(contextOptions) do
            if opt.key == currentContext then
                currentPositionKey = opt.positionKey
                break
            end
        end
    end

    local function getPositionTable()
        return db[currentPositionKey]
    end

    local function getValue(key, default)
        if rootKeys[key] then
            if db[key] ~= nil then
                return db[key]
            end
            return default
        end
        local posTable = getPositionTable()
        if posTable and posTable[key] ~= nil then
            return posTable[key]
        elseif db[key] ~= nil then
            return db[key]
        end
        return default
    end

    local function setValue(key, val)
        if rootKeys[key] then
            db[key] = val
        else
            local posTable = getPositionTable()
            if posTable then
                posTable[key] = val
            else
                db[key] = val
            end
        end
        if onChange then onChange() end
    end

    local widgets = {}
    local AnchorButtonwidgets = {}
    local card = GUIFrame:CreateCard(scrollChild, title, yOffset)
    local currentType = getValue(keys.anchorFrameType, defaults.anchorFrameType or "SCREEN")

    local selfPointWidget, anchorPointWidget, xSlider, ySlider

    local function refreshPositionWidgets()
        if selfPointWidget then
            selfPointWidget:SetValue(getValue(keys.selfPoint, defaults.selfPoint or "CENTER"))
        end
        if anchorPointWidget then
            anchorPointWidget:SetValue(getValue(keys.anchorPoint, defaults.anchorPoint or "CENTER"))
        end
        if xSlider and xSlider.SetValue then
            xSlider:SetValue(getValue(keys.xOffset, defaults.xOffset or 0))
        end
        if ySlider and ySlider.SetValue then
            ySlider:SetValue(getValue(keys.yOffset, defaults.yOffset or 0))
        end
    end

    if contextOptions and #contextOptions > 0 then
        local contextRow = GUIFrame:CreateRow(card.content, Theme.rowHeight)
        local contextList = {}
        for _, opt in ipairs(contextOptions) do
            table_insert(contextList, { key = opt.key, text = opt.text })
        end

        if splitToggleKey then
            local splitToggle = GUIFrame:CreateCheckbox(contextRow, "Split Positioning", {
                value = db[splitToggleKey],
                callback = function(checked)
                    db[splitToggleKey] = checked
                    if not checked then
                        currentPositionKey = contextOptions[1].positionKey
                        refreshPositionWidgets()
                    end
                    if onChange then onChange() end
                end
            })
            contextRow:AddWidget(splitToggle, 0.5)
            table_insert(widgets, splitToggle)
            card.splitToggle = splitToggle
        end

        local contextDropdown = GUIFrame:CreateDropdown(contextRow, "Configure For", {
            options = contextList,
            value = currentContext,
            callback = function(key)
                currentContext = key
                for _, opt in ipairs(contextOptions) do
                    if opt.key == key then
                        currentPositionKey = opt.positionKey
                        break
                    end
                end
                refreshPositionWidgets()
                if onContextChange then onContextChange(key, currentPositionKey) end
            end
        })
        contextRow:AddWidget(contextDropdown, 0.5)
        table_insert(widgets, contextDropdown)
        card.contextDropdown = contextDropdown

        card:AddRow(contextRow, Theme.rowHeight)

        local contextSep = GUIFrame:CreateSeparator(card.content)
        card:AddRow(contextSep, Theme.rowHeightSeparator)
    end

    if showAnchorFrameType then
        local row1 = GUIFrame:CreateRow(card.content, 40)

        local anchorTypeList = {}
        for _, opt in ipairs(ANCHOR_FRAME_TYPES) do
            anchorTypeList[opt.key] = opt.text
        end

        local anchorTypeDropdown = GUIFrame:CreateDropdown(row1, "Anchored To", {
            options = anchorTypeList,
            value = currentType,
            callback = function(key)
                setValue(keys.anchorFrameType, key)
                C_Timer.After(0.25, function()
                    GUIFrame:RefreshContent()
                end)
            end
        })
        row1:AddWidget(anchorTypeDropdown, 1)
        table_insert(widgets, anchorTypeDropdown)
        card:AddRow(row1, 40)

        if currentType == "SELECTFRAME" then
            local row2 = GUIFrame:CreateRow(card.content, 40)

            local frameInput = GUIFrame:CreateEditBox(row2, "Frame", {
                value = getValue(keys.anchorFrameFrame, ""),
                callback = function(val)
                    setValue(keys.anchorFrameFrame, val ~= "" and val or nil)
                end
            })
            row2:AddWidget(frameInput, 0.5)
            table_insert(widgets, frameInput)

            local selectFrameBtn = GUIFrame:CreateButton(row2, "Select Frame", {
                width = 110,
                height = 24,
                callback = function()
                    if NRSKNUI.FrameChooser then
                        NRSKNUI.FrameChooser:Start(function(frameName, isPreview)
                            if frameName then
                                frameInput:SetValue(frameName)
                                if not isPreview then
                                    setValue(keys.anchorFrameFrame, frameName)
                                end
                            end
                        end, getValue(keys.anchorFrameFrame, ""))
                    end
                end,
            })
            row2:AddWidget(selectFrameBtn, 0.5, nil, 0, -14)
            table_insert(widgets, selectFrameBtn)
            card:AddRow(row2, 40)
        end
    end

    local row3 = GUIFrame:CreateRow(card.content, 80)

    local selfPointValue = getValue(keys.selfPoint, defaults.selfPoint or "CENTER")
    selfPointWidget = CreateAnchorButtons(row3, "Anchor From", selfPointValue, function(val)
        setValue(keys.selfPoint, val)
    end)
    row3:AddWidget(selfPointWidget, 0.5)
    table_insert(widgets, selfPointWidget)
    table_insert(AnchorButtonwidgets, selfPointWidget)
    if disableAnchorFrom then
        selfPointWidget:SetEnabled(false)
    end

    local anchorPointLabel = showAnchorFrameType and
        (currentType == "SELECTFRAME" and "To Frame's" or "To Screen's") or
        "To Frame's"
    local anchorPointValue = getValue(keys.anchorPoint, defaults.anchorPoint or "CENTER")
    anchorPointWidget = CreateAnchorButtons(row3, anchorPointLabel, anchorPointValue, function(val)
        setValue(keys.anchorPoint, val)
    end)
    row3:AddWidget(anchorPointWidget, 0.5)
    table_insert(widgets, anchorPointWidget)
    table_insert(AnchorButtonwidgets, anchorPointWidget)
    card:AddRow(row3, 80)

    local row4 = GUIFrame:CreateRow(card.content, 40)

    xSlider = GUIFrame:CreateSlider(row4, "X Offset", {
        min = sliderRange[1],
        max = sliderRange[2],
        step = 1,
        value = getValue(keys.xOffset, defaults.xOffset or 0),
        labelWidth = 55,
        callback = function(val)
            setValue(keys.xOffset, val)
        end
    })
    row4:AddWidget(xSlider, 0.5)
    table_insert(widgets, xSlider)

    ySlider = GUIFrame:CreateSlider(row4, "Y Offset", {
        min = sliderRange[1],
        max = sliderRange[2],
        step = 1,
        value = getValue(keys.yOffset, defaults.yOffset or 0),
        labelWidth = 55,
        callback = function(val)
            setValue(keys.yOffset, val)
        end
    })
    row4:AddWidget(ySlider, 0.5)
    table_insert(widgets, ySlider)
    card:AddRow(row4, 40, showStrata and nil or 0)

    if showStrata then
        local row5 = GUIFrame:CreateRow(card.content, Theme.rowHeightLast)
        local strataList = {
            { key = "TOOLTIP",           text = "Tooltip" },
            { key = "FULLSCREEN_DIALOG", text = "Fullscreen Dialog" },
            { key = "FULLSCREEN",        text = "Fullscreen" },
            { key = "DIALOG",            text = "Dialog" },
            { key = "HIGH",              text = "High" },
            { key = "MEDIUM",            text = "Medium" },
            { key = "LOW",               text = "Low" },
            { key = "BACKGROUND",        text = "Background" },
        }
        local currentStrata = getValue(keys.strata, defaults.strata or "HIGH")
        local strataDropdown = GUIFrame:CreateDropdown(row5, "Strata", {
            options = strataList,
            value = currentStrata,
            callback = function(key)
                setValue(keys.strata, key)
            end
        })
        row5:AddWidget(strataDropdown, 1)
        table_insert(widgets, strataDropdown)
        card:AddRow(row5, Theme.rowHeightLast, 0)
    end

    card.positionWidgets = widgets
    card.AnchorButtonWidgets = AnchorButtonwidgets
    card.selfPointWidget = selfPointWidget
    card._hasInternalWidgetState = true

    function card:SetEnabled(enabled)
        if enabled then
            self:SetAlpha(1)
            if self.header then self.header:SetAlpha(1) end
            if self.titleText then self.titleText:SetAlpha(1) end
        else
            self:SetAlpha(0.5)
            if self.header then self.header:SetAlpha(0.5) end
            if self.titleText then self.titleText:SetAlpha(0.5) end
        end

        local splitEnabled = not splitToggleKey or db[splitToggleKey]

        for _, widget in ipairs(self.positionWidgets) do
            local widgetEnabled = enabled
            if widget == self.contextDropdown and not splitEnabled then
                widgetEnabled = false
            end
            if widget == self.selfPointWidget and disableAnchorFrom then
                widgetEnabled = false
            end

            if widget.SetEnabled then
                widget:SetEnabled(widgetEnabled)
            elseif widget.SetDisabled then
                widget:SetDisabled(not widgetEnabled)
            end
        end
    end

    function card:SetPositionWidgetsEnabled(enabled)
        self:SetEnabled(enabled)
    end

    function card:SetAnchorsOnlyEnabled(enabled)
        for _, widget in ipairs(self.AnchorButtonWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(enabled)
            end
        end
    end

    return card, card:GetNextOffset(), widgets
end

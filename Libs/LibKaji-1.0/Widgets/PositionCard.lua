--[[
# PositionCard

* Premade card for configuring a frame's position with anchor points and offsets.
* Uses a WA style 9-point anchor selector and sliders for X/Y offsets.

## Examples

    page:PositionCard({
        db = db,
        showStrata = true,
        onChangeCallback = Apply
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local ipairs, pairs = ipairs, pairs
local wipe = wipe
local tinsert = table.insert

local ANCHOR_DIRECTIONS = {
    "TOPLEFT", "TOP", "TOPRIGHT",
    "LEFT", "CENTER", "RIGHT",
    "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
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

local STRATA_LIST = {
    { key = "TOOLTIP",           text = "Tooltip" },
    { key = "FULLSCREEN_DIALOG", text = "Fullscreen Dialog" },
    { key = "FULLSCREEN",        text = "Fullscreen" },
    { key = "DIALOG",            text = "Dialog" },
    { key = "HIGH",              text = "High" },
    { key = "MEDIUM",            text = "Medium" },
    { key = "LOW",               text = "Low" },
    { key = "BACKGROUND",        text = "Background" },
}

-- WA type 9-point anchor selector.
local function CreateAnchorButtons(gui, parent, labelText, value, callback)
    local theme = gui.theme
    local buttonSize, frameWidth, frameHeight, titleHeight, spacing = 10, 100, 52, 18, 2

    local container = CreateFrame("Frame", nil, parent)
    pixel.SetPixelSize(container, frameWidth + buttonSize, frameHeight + buttonSize + titleHeight + spacing + 4)
    pixel.SetPixelSnap(container)

    local label = container:CreateFontString(nil, "OVERLAY")
    pixel.SetPixelPoint(label, "TOP", container, "TOP", 0, 2)
    pixel.SetPixelHeight(label, titleHeight)
    label:SetJustifyH("CENTER")
    gui:ApplyFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    container.label = label

    local background = CreateFrame("Frame", nil, container, "BackdropTemplate")
    pixel.SetPixelSize(background, frameWidth, frameHeight)
    local function AlignBackground()
        local w = container:GetWidth()
        if not w or w <= 0 then return end
        background:ClearAllPoints()
        pixel.SetPixelPoint(background, "TOPLEFT", container, "TOPLEFT", (w - frameWidth) / 2, -(titleHeight + spacing))
    end
    AlignBackground()
    container:SetScript("OnSizeChanged", AlignBackground)
    background:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    background:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], 1)
    background:SetBackdropBorderColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 1)
    pixel.SetPixelSnap(background)
    container.background = background
    container.value = value or "CENTER"

    local buttons = {}
    local function ColorButton(btn)
        if container.value == btn.value then
            btn.tex:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        else
            btn.tex:SetVertexColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 1)
        end
    end

    for _, direction in ipairs(ANCHOR_DIRECTIONS) do
        local button = CreateFrame("Button", nil, container)
        pixel.SetPixelSize(button, buttonSize, buttonSize)
        pixel.SetPixelPoint(button, "CENTER", background, direction)

        local tex = button:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        pixel.SetPixelSnap(tex)
        button.tex = tex
        button.value = direction

        button:SetScript("OnClick", function()
            container.value = direction
            for _, btn in pairs(buttons) do ColorButton(btn) end
            if callback then callback(direction) end
        end)
        button:SetScript("OnEnter", function(self)
            if not container.disabled then
                self.tex:SetVertexColor(theme.accentHover[1], theme.accentHover[2], theme.accentHover[3], 1)
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 4)
            GameTooltip:SetText(DIRECTION_NAMES[direction] or direction, theme.accent[1], theme.accent[2], theme.accent[3], 1, false)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(self)
            if not container.disabled then ColorButton(self) end
            GameTooltip:Hide()
        end)

        buttons[direction] = button
        ColorButton(button)
    end
    container.buttons = buttons

    function container:SetValue(val)
        self.value = val
        for _, btn in pairs(self.buttons) do ColorButton(btn) end
    end

    function container:GetValue() return self.value end

    function container:SetEnabled(enabled)
        self.disabled = not enabled
        self:SetAlpha(1)
        if enabled then
            self.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            self.background:SetBackdropBorderColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 1)
            for _, btn in pairs(self.buttons) do
                btn:EnableMouse(true)
                ColorButton(btn)
            end
        else
            self.label:SetTextColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 0.5)
            self.background:SetBackdropBorderColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 0.3)
            for _, btn in pairs(self.buttons) do
                btn:EnableMouse(false)
                btn.tex:SetVertexColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 0.3)
            end
        end
    end

    return container
end

--- 9-point anchor selector + offset sliders bound to a db table.
---@param scrollChild Frame
---@param yOffset number
---@param config table
---@return KajiGUICard card
---@return number newYOffset
---@return Frame[] positionWidgets
function InstanceMixin:CreatePositionCard(scrollChild, yOffset, config)
    config = config or {}
    local gui = self
    local theme = self.theme

    local title = config.title or "Position Settings"
    local db = config.db
    local dbKeys = config.dbKeys or {}
    local defaults = config.defaults or {}
    local onChange = config.onChangeCallback
    local onContextChange = config.onContextChange
    local showAnchorFrameType = config.showAnchorFrameType ~= false
    local showStrata = config.showStrata == true
    local sliderRange = config.sliderRange or { -2000, 2000 }
    local contextOptions = config.contextOptions
    local splitToggleKey = config.splitToggleKey
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
    local rootKeys = { [keys.anchorFrameType] = true, [keys.anchorFrameFrame] = true, [keys.strata] = true }

    local currentContext = config.defaultContext
    local currentPositionKey = "Position"
    if contextOptions and #contextOptions > 0 then
        currentContext = currentContext or contextOptions[1].key
        for _, opt in ipairs(contextOptions) do
            if opt.key == currentContext then
                currentPositionKey = opt.positionKey
                break
            end
        end
    end

    local function getPositionTable() return db[currentPositionKey] end

    local function getValue(key, default)
        if rootKeys[key] then
            if db[key] ~= nil then return db[key] end
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
            if posTable then posTable[key] = val else db[key] = val end
        end
        if onChange then onChange() end
    end

    local widgets = {}
    local anchorButtonWidgets = {}
    local card = gui:CreateCard(scrollChild, title, yOffset)

    local selfPointWidget, anchorPointWidget, xSlider, ySlider

    local function refreshPositionWidgets()
        if selfPointWidget then selfPointWidget:SetValue(getValue(keys.selfPoint, defaults.selfPoint or "CENTER")) end
        if anchorPointWidget then anchorPointWidget:SetValue(getValue(keys.anchorPoint, defaults.anchorPoint or "CENTER")) end
        if xSlider then xSlider:SetValue(getValue(keys.xOffset, defaults.xOffset or 0)) end
        if ySlider then ySlider:SetValue(getValue(keys.yOffset, defaults.yOffset or 0)) end
    end

    local BuildContent
    -- Rebuilds the card in place when the anchor type changes.
    -- A page provides the hooks to unregister the old widgets, re-register the new ones and reflow.
    local function RebuildContent()
        if card._onBeforeRebuild then card._onBeforeRebuild(widgets) end
        wipe(widgets)
        wipe(anchorButtonWidgets)
        card:Reset()
        BuildContent()
        if card._onAfterRebuild then card._onAfterRebuild(widgets) end
    end

    BuildContent = function()
        local currentType = getValue(keys.anchorFrameType, defaults.anchorFrameType or "SCREEN")
        selfPointWidget, anchorPointWidget, xSlider, ySlider = nil, nil, nil, nil

        if contextOptions and #contextOptions > 0 then
            local contextRow = gui:CreateRow(card.content, theme.rowHeight)
            local contextList = {}
            for _, opt in ipairs(contextOptions) do tinsert(contextList, { key = opt.key, text = opt.text }) end

            if splitToggleKey then
                local splitToggle = gui:CreateCheckbox(contextRow, "Split Positioning", {
                    value = db[splitToggleKey],
                    callback = function(checked)
                        db[splitToggleKey] = checked
                        if not checked then
                            currentPositionKey = contextOptions[1].positionKey
                            refreshPositionWidgets()
                        end
                        if onChange then onChange() end
                    end,
                })
                contextRow:AddWidget(splitToggle, 0.5)
                tinsert(widgets, splitToggle)
                card.splitToggle = splitToggle
            end

            local contextDropdown = gui:CreateDropdown(contextRow, "Configure For", {
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
                end,
            })
            contextRow:AddWidget(contextDropdown, 0.5)
            tinsert(widgets, contextDropdown)
            card.contextDropdown = contextDropdown
            card:AddRow(contextRow, theme.rowHeight)

            card:AddRow(gui:CreateSeparator(card.content), theme.rowHeightSeparator)
        end

        if showAnchorFrameType then
            local row1 = gui:CreateRow(card.content, 40)
            local anchorTypeList = {}
            for _, opt in ipairs(ANCHOR_FRAME_TYPES) do anchorTypeList[opt.key] = opt.text end

            local anchorTypeDropdown = gui:CreateDropdown(row1, "Anchored To", {
                options = anchorTypeList,
                value = currentType,
                callback = function(key)
                    setValue(keys.anchorFrameType, key)
                    RebuildContent()
                end,
            })
            row1:AddWidget(anchorTypeDropdown, 1)
            tinsert(widgets, anchorTypeDropdown)
            card:AddRow(row1, 40)

            if currentType == "SELECTFRAME" then
                local row2 = gui:CreateRow(card.content, 40)
                local frameInput = gui:CreateEditBox(row2, "Frame", {
                    value = getValue(keys.anchorFrameFrame, ""),
                    callback = function(val) setValue(keys.anchorFrameFrame, val ~= "" and val or nil) end,
                })
                row2:AddWidget(frameInput, 0.5)
                tinsert(widgets, frameInput)

                local frameChooser = gui.services.frameChooser
                local selectFrameBtn = gui:CreateButton(row2, "Select Frame", {
                    width = 110,
                    height = 24,
                    callback = function()
                        if frameChooser then
                            frameChooser:Start(function(frameName, isPreview)
                                if frameName then
                                    frameInput:SetValue(frameName)
                                    if not isPreview then setValue(keys.anchorFrameFrame, frameName) end
                                end
                            end, getValue(keys.anchorFrameFrame, ""))
                        end
                    end,
                })
                row2:AddWidget(selectFrameBtn, 0.5, nil, 0, -14)
                tinsert(widgets, selectFrameBtn)
                card:AddRow(row2, 40)
            end
        end

        local row3 = gui:CreateRow(card.content, 80)
        selfPointWidget = CreateAnchorButtons(gui, row3, "Anchor From", getValue(keys.selfPoint, defaults.selfPoint or "CENTER"),
            function(val) setValue(keys.selfPoint, val) end)
        row3:AddWidget(selfPointWidget, 0.5)
        tinsert(widgets, selfPointWidget)
        tinsert(anchorButtonWidgets, selfPointWidget)
        if disableAnchorFrom then selfPointWidget:SetEnabled(false) end
        card.selfPointWidget = selfPointWidget

        local anchorPointLabel = showAnchorFrameType and (currentType == "SELECTFRAME" and "To Frame's" or "To Screen's") or "To Frame's"
        anchorPointWidget = CreateAnchorButtons(gui, row3, anchorPointLabel, getValue(keys.anchorPoint, defaults.anchorPoint or "CENTER"),
            function(val) setValue(keys.anchorPoint, val) end)
        row3:AddWidget(anchorPointWidget, 0.5)
        tinsert(widgets, anchorPointWidget)
        tinsert(anchorButtonWidgets, anchorPointWidget)
        card:AddRow(row3, 80)

        local row4 = gui:CreateRow(card.content, 40)
        xSlider = gui:CreateSlider(row4, "X Offset", {
            min = sliderRange[1],
            max = sliderRange[2],
            step = 1,
            value = getValue(keys.xOffset, defaults.xOffset or 0),
            labelWidth = 55,
            callback = function(val) setValue(keys.xOffset, val) end,
        })
        row4:AddWidget(xSlider, 0.5)
        tinsert(widgets, xSlider)

        ySlider = gui:CreateSlider(row4, "Y Offset", {
            min = sliderRange[1],
            max = sliderRange[2],
            step = 1,
            value = getValue(keys.yOffset, defaults.yOffset or 0),
            labelWidth = 55,
            callback = function(val) setValue(keys.yOffset, val) end,
        })
        row4:AddWidget(ySlider, 0.5)
        tinsert(widgets, ySlider)
        card:AddRow(row4, 40, showStrata and nil or 0)

        if showStrata then
            local row5 = gui:CreateRow(card.content, theme.rowHeightLast)
            local strataDropdown = gui:CreateDropdown(row5, "Strata", {
                options = STRATA_LIST,
                value = getValue(keys.strata, defaults.strata or "HIGH"),
                callback = function(key) setValue(keys.strata, key) end,
            })
            row5:AddWidget(strataDropdown, 1)
            tinsert(widgets, strataDropdown)
            card:AddRow(row5, theme.rowHeightLast, 0)
        end
    end

    BuildContent()

    card.positionWidgets = widgets
    card.anchorButtonWidgets = anchorButtonWidgets
    card._hasInternalWidgetState = true

    function card:SetEnabled(enabled)
        local alpha = enabled and 1 or 0.5
        self:SetAlpha(alpha)
        if self.header then self.header:SetAlpha(alpha) end
        if self.titleText then self.titleText:SetAlpha(alpha) end

        local splitEnabled = not splitToggleKey or db[splitToggleKey]
        for _, widget in ipairs(self.positionWidgets) do
            local widgetEnabled = enabled
            if widget == self.contextDropdown and not splitEnabled then widgetEnabled = false end
            if widget == self.selfPointWidget and disableAnchorFrom then widgetEnabled = false end
            if widget.SetEnabled then
                widget:SetEnabled(widgetEnabled)
            elseif widget.SetDisabled then
                widget:SetDisabled(not widgetEnabled)
            end
        end
    end

    function card:SetAnchorsOnlyEnabled(enabled)
        for _, widget in ipairs(self.anchorButtonWidgets) do
            if widget.SetEnabled then widget:SetEnabled(enabled) end
        end
    end

    return card, card:GetNextOffset(), widgets
end

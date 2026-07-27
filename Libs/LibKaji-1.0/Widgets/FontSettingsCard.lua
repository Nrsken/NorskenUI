--[[
# FontSettingsCard

* Premade card for font face, size, outline and drop-shadow settings.
* Binds to a db table via `dbKeys`, supports multiple named sizes, an optional
* "Use Global Font" override toggle, and shadow controls that grey out when the
* chosen outline can't render a shadow.

## Examples

    page:FontSettingsCard({
        db = db,
        onChangeCallback = Apply
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin

local tinsert = table.insert
local ipairs = ipairs
local strsplit = strsplit
local min = math.min

-- Outlines that draw their own edge and so can't show a separate drop shadow.
local NO_SHADOW_OUTLINES = {
    SOFTOUTLINE = true,
    SLUG = true,
    ["SLUG,OUTLINE"] = true,
}

local DEFAULT_OUTLINE_OPTIONS = {
    { key = "NONE",                    text = "None" },
    { key = "OUTLINE",                 text = "Outline" },
    { key = "THICKOUTLINE",            text = "Thick" },
    { key = "MONOCHROME",              text = "Mono" },
    { key = "MONOCHROME,OUTLINE",      text = "Mono Outline" },
    { key = "MONOCHROME,THICKOUTLINE", text = "Mono Thick" },
    { key = "SLUG",                    text = "Slug" },
    { key = "SLUG,OUTLINE",            text = "Slug Outline" },
}

--- Font face / size / outline / shadow settings bound to a db table.
---@param scrollChild Frame
---@param yOffset number
---@param config table
---@return KajiGUICard card
---@return number newYOffset
---@return Frame[] widgets
function InstanceMixin:CreateFontSettingsCard(scrollChild, yOffset, config)
    config = config or {}
    local gui = self
    local theme = self.theme

    local title = config.title or "Font Settings"
    local db = config.db
    local dbKeys = config.dbKeys or {}
    local onChange = config.onChangeCallback
    local fontSizeRange = config.fontSizeRange or { 8, 72 }
    local fontSizes = config.fontSizes
    local hideFontSize = config.hideFontSize == true
    local searchable = config.searchable ~= false
    local includeSoftOutline = config.includeSoftOutline == true
    local shadowOffsetRange = config.shadowOffsetRange or { -5, 5 }

    local globalOverride = config.globalOverride
    local globalOverrideKey = globalOverride and (globalOverride.dbKey or "UseGlobalFont")
    local globalOverrideLabel = globalOverride and (globalOverride.label or "Use Global Font")

    local keys = {
        fontFace = dbKeys.fontFace or "FontFace",
        fontSize = dbKeys.fontSize or "FontSize",
        fontOutline = dbKeys.fontOutline or "FontOutline",
        shadow = dbKeys.shadow or "FontShadow",
    }

    local shadowKeys = { enabled = "Enabled", color = "Color", offsetX = "OffsetX", offsetY = "OffsetY" }

    db[keys.shadow] = db[keys.shadow] or {}
    local shadowDb = db[keys.shadow]

    local function getValue(key, default)
        if key:find("%.") then
            local current = db
            for _, part in ipairs({ strsplit(".", key) }) do
                if current[part] == nil then return default end
                current = current[part]
            end
            return current
        end
        if db[key] ~= nil then return db[key] end
        return default
    end

    local function setValue(key, val)
        if key:find("%.") then
            local parts = { strsplit(".", key) }
            local current = db
            for i = 1, #parts - 1 do current = current[parts[i]] end
            current[parts[#parts]] = val
        else
            db[key] = val
        end
        if onChange then onChange() end
    end

    local widgets = {}
    local shadowSubWidgets = {}
    local shadowEnableCheck
    local globalOverrideCheck
    local fontDropdownRef

    local function UpdateShadowState()
        local noShadowOutline = NO_SHADOW_OUTLINES[getValue(keys.fontOutline, "OUTLINE")] == true
        local shadowEnabled = shadowDb[shadowKeys.enabled] == true

        if shadowEnableCheck and shadowEnableCheck.SetEnabled then
            shadowEnableCheck:SetEnabled(not noShadowOutline)
        end

        local subEnabled = not noShadowOutline and shadowEnabled
        for _, widget in ipairs(shadowSubWidgets) do
            if widget.SetEnabled then widget:SetEnabled(subEnabled) end
        end
    end

    local function UpdateGlobalOverrideState()
        if not globalOverride then return end
        local useGlobal = db[globalOverrideKey] ~= false -- default true
        if fontDropdownRef and fontDropdownRef.SetEnabled then
            fontDropdownRef:SetEnabled(not useGlobal)
        end
    end

    local card = gui:CreateCard(scrollChild, title, yOffset)

    -- Optional "Use Global Font" toggle.
    if globalOverride then
        local overrideRow = gui:CreateRow(card.content, theme.rowHeight)
        globalOverrideCheck = gui:CreateCheckbox(overrideRow, globalOverrideLabel, {
            value = db[globalOverrideKey] ~= false,
            callback = function(checked)
                db[globalOverrideKey] = checked
                if onChange then onChange() end
                UpdateGlobalOverrideState()
            end
        })
        overrideRow:AddWidget(globalOverrideCheck, 1)
        tinsert(widgets, globalOverrideCheck)
        card:AddRow(overrideRow, theme.rowHeight)
        card:AddRow(gui:CreateSeparator(card.content), theme.rowHeightSeparator)
    end

    -- Font face + outline.
    local row1 = gui:CreateRow(card.content, theme.rowHeight)

    local fontDropdown = gui:CreateDropdown(row1, "Font", {
        media = "font",
        value = getValue(keys.fontFace, "Friz Quadrata TT"),
        searchable = searchable,
        callback = function(key) setValue(keys.fontFace, key) end,
    })
    row1:AddWidget(fontDropdown, 0.5)
    tinsert(widgets, fontDropdown)
    fontDropdownRef = fontDropdown

    local outlineOptions = config.outlineOptions or DEFAULT_OUTLINE_OPTIONS
    if includeSoftOutline then
        outlineOptions = { unpack(outlineOptions) }
        tinsert(outlineOptions, { key = "SOFTOUTLINE", text = "Soft" })
    end

    local outlineDropdown = gui:CreateDropdown(row1, "Outline", {
        options = outlineOptions,
        value = getValue(keys.fontOutline, "OUTLINE"),
        callback = function(key)
            setValue(keys.fontOutline, key)
            UpdateShadowState()
        end
    })
    row1:AddWidget(outlineDropdown, 0.5)
    tinsert(widgets, outlineDropdown)
    card:AddRow(row1, theme.rowHeight)

    -- Font size(s).
    if not hideFontSize then
        if fontSizes and #fontSizes > 0 then
            local perRow = 2
            for i = 1, #fontSizes, perRow do
                local row = gui:CreateRow(card.content, theme.rowHeight)
                local countInRow = min(perRow, #fontSizes - i + 1)
                local widthPct = 1 / countInRow
                for j = i, min(i + perRow - 1, #fontSizes) do
                    local sizeConfig = fontSizes[j]
                    local sizeSlider = gui:CreateSlider(row, sizeConfig.label or "Size", {
                        min = fontSizeRange[1],
                        max = fontSizeRange[2],
                        step = 1,
                        value = getValue(sizeConfig.dbKey, 18),
                        callback = function(val) setValue(sizeConfig.dbKey, val) end
                    })
                    row:AddWidget(sizeSlider, widthPct)
                    tinsert(widgets, sizeSlider)
                end
                card:AddRow(row, theme.rowHeight)
            end
        else
            local row2 = gui:CreateRow(card.content, theme.rowHeight)
            local fontSizeSlider = gui:CreateSlider(row2, "Font Size", {
                min = fontSizeRange[1],
                max = fontSizeRange[2],
                step = 1,
                value = getValue(keys.fontSize, 18),
                labelWidth = 60,
                callback = function(val) setValue(keys.fontSize, val) end
            })
            row2:AddWidget(fontSizeSlider, 1)
            tinsert(widgets, fontSizeSlider)
            card:AddRow(row2, theme.rowHeight)
        end
    end

    card:AddRow(gui:CreateSeparator(card.content), theme.rowHeightSeparator)

    -- Shadow enable + color.
    local row3 = gui:CreateRow(card.content, theme.rowHeight)
    shadowEnableCheck = gui:CreateCheckbox(row3, "Font Shadow", {
        value = shadowDb[shadowKeys.enabled] == true,
        callback = function(checked)
            shadowDb[shadowKeys.enabled] = checked
            if onChange then onChange() end
            UpdateShadowState()
        end
    })
    row3:AddWidget(shadowEnableCheck, 0.5)
    tinsert(widgets, shadowEnableCheck)

    local shadowColorPicker = gui:CreateColorPicker(row3, "Shadow Color", {
        value = shadowDb[shadowKeys.color] or { 0, 0, 0, 1 },
        callback = function(r, g, b, a)
            shadowDb[shadowKeys.color] = { r, g, b, a }
            if onChange then onChange() end
        end
    })
    row3:AddWidget(shadowColorPicker, 0.5)
    tinsert(widgets, shadowColorPicker)
    tinsert(shadowSubWidgets, shadowColorPicker)
    card:AddRow(row3, theme.rowHeight)

    -- Shadow X/Y offsets.
    local row4 = gui:CreateRow(card.content, theme.rowHeightLast)
    local shadowXSlider = gui:CreateSlider(row4, "Shadow X", {
        min = shadowOffsetRange[1],
        max = shadowOffsetRange[2],
        step = 1,
        value = shadowDb[shadowKeys.offsetX] or 1,
        labelWidth = 15,
        callback = function(val)
            shadowDb[shadowKeys.offsetX] = val
            if onChange then onChange() end
        end
    })
    row4:AddWidget(shadowXSlider, 0.5)
    tinsert(widgets, shadowXSlider)
    tinsert(shadowSubWidgets, shadowXSlider)

    local shadowYSlider = gui:CreateSlider(row4, "Shadow Y", {
        min = shadowOffsetRange[1],
        max = shadowOffsetRange[2],
        step = 1,
        value = shadowDb[shadowKeys.offsetY] or -1,
        labelWidth = 15,
        callback = function(val)
            shadowDb[shadowKeys.offsetY] = val
            if onChange then onChange() end
        end
    })
    row4:AddWidget(shadowYSlider, 0.5)
    tinsert(widgets, shadowYSlider)
    tinsert(shadowSubWidgets, shadowYSlider)
    card:AddRow(row4, theme.rowHeightLast, 0)

    card.fontWidgets = widgets
    card.shadowSubWidgets = shadowSubWidgets
    card.shadowEnableCheck = shadowEnableCheck
    card.globalOverrideCheck = globalOverrideCheck
    UpdateShadowState()
    UpdateGlobalOverrideState()

    -- Deferred so SetEnabled runs after the plain inner widgets and its
    -- shadow/global-override derivation wins, instead of racing them in UpdateAll.
    card._hasInternalWidgetState = true

    function card:SetEnabled(enabled)
        local alpha = enabled and 1 or 0.5
        self:SetAlpha(alpha)
        if self.header then self.header:SetAlpha(alpha) end
        if self.titleText then self.titleText:SetAlpha(alpha) end

        for _, widget in ipairs(self.fontWidgets) do
            if widget ~= globalOverrideCheck and widget ~= fontDropdownRef and widget.SetEnabled then
                widget:SetEnabled(enabled)
            end
        end

        -- The global-override toggle stays live so you can flip it back on.
        if globalOverrideCheck and globalOverrideCheck.SetEnabled then
            globalOverrideCheck:SetEnabled(enabled)
        end

        -- The font dropdown follows the override state while the card is enabled.
        if enabled and globalOverride then
            UpdateGlobalOverrideState()
        elseif fontDropdownRef and fontDropdownRef.SetEnabled then
            fontDropdownRef:SetEnabled(enabled)
        end

        if enabled then UpdateShadowState() end
    end

    return card, card:GetNextOffset(), widgets
end

-- Labels this card can surface, for the frameless search harvester (see Search.lua).
lib.premadeCardSearch = lib.premadeCardSearch or {}
function lib.premadeCardSearch.FontSettingsCard(config)
    config = config or {}
    local labels = { config.title or "Font Settings", "Font", "Outline", "Font Shadow", "Shadow Color", "Shadow X", "Shadow Y" }
    if config.globalOverride then labels[#labels + 1] = config.globalOverride.label or "Use Global Font" end
    if not config.hideFontSize then
        if config.fontSizes and #config.fontSizes > 0 then
            for _, size in ipairs(config.fontSizes) do labels[#labels + 1] = size.label or "Size" end
        else
            labels[#labels + 1] = "Font Size"
        end
    end
    return labels
end

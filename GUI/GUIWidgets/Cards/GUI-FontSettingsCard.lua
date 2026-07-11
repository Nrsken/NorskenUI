---@alias NUIWidget NUISlider|NUIDropdown|NUICheckbox|NUIColorPicker|NUISeparator|NUIButton

---@class NUIFontSettingsCard : NUICard
---@field fontWidgets NUIWidget[]
---@field shadowSubWidgets NUIWidget[]
---@field shadowEnableCheck NUICheckbox?
---@field globalOverrideCheck NUICheckbox?
---@field UpdateShadowState fun()
---@field UpdateGlobalOverrideState fun()
---@field _hasInternalWidgetState boolean

---@class NUIFontSettingsCardFontSize
---@field label? string
---@field dbKey string

---@class NUIFontSettingsCardDbKeys
---@field fontFace? string
---@field fontSize? string
---@field fontOutline? string
---@field shadow? string

---@class NUIFontSettingsCardConfig
---@field title? string
---@field db table
---@field dbKeys? NUIFontSettingsCardDbKeys
---@field onChangeCallback? fun()
---@field fontSizeRange? number[]
---@field fontSizes? NUIFontSettingsCardFontSize[]
---@field hideFontSize? boolean
---@field searchable? boolean
---@field includeSoftOutline? boolean
---@field shadowOffsetRange? number[]
---@field globalOverride? table

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

local table_insert = table.insert
local pairs = pairs
local ipairs = ipairs

---Font face, size, outline and shadow settings card
---```lua
---config = {
---    title = string,              -- Card header (default: "Font Settings")
---    db = table,                  -- Database table to read/write (required)
---    dbKeys = table,              -- Custom keys for db fields
---    onChangeCallback = function, -- Called when any value changes
---    fontSizeRange = {min, max},  -- Font size slider range (default: {8, 72})
---    fontSizes = {                -- Multiple font sizes (optional, overrides dbKeys.fontSize)
---        { label = string, dbKey = string },
---    },
---    hideFontSize = boolean,      -- Hide font size slider entirely (default: false)
---    searchable = boolean,        -- Enable font search (default: true)
---    includeSoftOutline = boolean,-- Include SOFTOUTLINE option (default: false)
---    shadowOffsetRange = {min, max}, -- Shadow offset range (default: {-5, 5})
---    globalOverride = {           -- Optional: adds "Use Global Font" toggle at top
---        dbKey = string,          -- Key in db for override value (default: "UseGlobalFont")
---        label = string,          -- Toggle label (default: "Use Global Font")
---    },
---}
---```
---@param scrollChild Frame
---@param yOffset number
---@param config NUIFontSettingsCardConfig
---@return NUIFontSettingsCard card
---@return number newYOffset
---@return NUIWidget[] widgets
function GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, config)
    config = config or {}
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

    local shadowKeys = {
        enabled = "Enabled",
        color = "Color",
        offsetX = "OffsetX",
        offsetY = "OffsetY",
    }

    db[keys.shadow] = db[keys.shadow] or {}
    local shadowDb = db[keys.shadow]

    local function getValue(key, default)
        if key:find("%.") then
            local parts = { strsplit(".", key) }
            local current = db
            for _, part in ipairs(parts) do
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
            for i = 1, #parts - 1 do
                current = current[parts[i]]
            end
            current[parts[#parts]] = val
        else
            db[key] = val
        end
        if onChange then onChange() end
    end

    ---@type NUIWidget[]
    local widgets = {}
    ---@type NUICheckbox?
    local shadowEnableCheck
    ---@type NUIWidget[]
    local shadowSubWidgets = {}

    local function UpdateShadowState()
        local outline = getValue(keys.fontOutline, "OUTLINE")
        local noShadowOutline = outline == "SOFTOUTLINE"
            or outline == "SLUG"
            or outline == "SLUG,OUTLINE"
        local shadowEnabled = shadowDb[shadowKeys.enabled] == true

        if shadowEnableCheck and shadowEnableCheck.SetEnabled then
            shadowEnableCheck:SetEnabled(not noShadowOutline)
        end

        local subEnabled = not noShadowOutline and shadowEnabled
        for _, widget in ipairs(shadowSubWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(subEnabled)
            end
        end
    end

    local card = GUIFrame:CreateCard(scrollChild, title, yOffset) --[[@as NUIFontSettingsCard]]

    ---@type NUICheckbox?
    local globalOverrideCheck

    ---@type NUIDropdown?
    local fontDropdownRef

    local function UpdateGlobalOverrideState()
        if not globalOverride then return end
        local useGlobal = db[globalOverrideKey] ~= false -- default true
        if fontDropdownRef and fontDropdownRef.SetEnabled then
            fontDropdownRef:SetEnabled(not useGlobal)
        end
    end

    if globalOverride then
        local overrideRow = GUIFrame:CreateRow(card.content, Theme.rowHeight)
        globalOverrideCheck = GUIFrame:CreateCheckbox(overrideRow, globalOverrideLabel, {
            value = db[globalOverrideKey] ~= false,
            callback = function(checked)
                db[globalOverrideKey] = checked
                if onChange then onChange() end
                UpdateGlobalOverrideState()
            end
        })
        overrideRow:AddWidget(globalOverrideCheck, 1)
        table_insert(widgets, globalOverrideCheck)
        card:AddRow(overrideRow, Theme.rowHeight)

        local sepRow = GUIFrame:CreateRow(card.content, Theme.rowHeightSeparator)
        local sep = GUIFrame:CreateSeparator(sepRow)
        sepRow:AddWidget(sep, 1)
        card:AddRow(sepRow, Theme.rowHeightSeparator)
    end

    local fontList = {}
    if LSM then
        for name in pairs(LSM:HashTable("font")) do
            fontList[name] = name
        end
    else
        fontList["Friz Quadrata TT"] = "Friz Quadrata TT"
    end

    local row1 = GUIFrame:CreateRow(card.content, Theme.rowHeight)

    local fontDropdown = GUIFrame:CreateDropdown(row1, "Font", {
        options = fontList,
        value = getValue(keys.fontFace, "Friz Quadrata TT"),
        callback = function(key)
            setValue(keys.fontFace, key)
        end,
        searchable = searchable,
        isFontPreview = true
    })
    row1:AddWidget(fontDropdown, 0.5)
    table_insert(widgets, fontDropdown)
    fontDropdownRef = fontDropdown

    -- Render the canonical outline vocabulary (single source of truth in FontStyle.lua).
    -- A value may be a string or a list of equivalents; the first entry is canonical.
    local outlineOptions = {}
    for _, option in ipairs(NRSKNUI.FontOutlines) do
        local value = option.value
        if type(value) == "table" then value = value[1] end
        table_insert(outlineOptions, { key = value, text = option.label })
    end
    if includeSoftOutline then
        -- Legacy pseudo-outline, not part of the font-object vocabulary; only offered
        -- to modules that still drive it through the old styling path.
        table_insert(outlineOptions, { key = "SOFTOUTLINE", text = "Soft" })
    end

    local outlineDropdown = GUIFrame:CreateDropdown(row1, "Outline", {
        options = outlineOptions,
        value = getValue(keys.fontOutline, "OUTLINE"),
        callback = function(key)
            setValue(keys.fontOutline, key)
            UpdateShadowState()
        end
    })
    row1:AddWidget(outlineDropdown, 0.5)
    table_insert(widgets, outlineDropdown)
    card:AddRow(row1, Theme.rowHeight)

    if not hideFontSize then
        if fontSizes and #fontSizes > 0 then
            local maxPerRow = 2
            for i = 1, #fontSizes, maxPerRow do
                local row = GUIFrame:CreateRow(card.content, Theme.rowHeight)
                local countInRow = math.min(maxPerRow, #fontSizes - i + 1)
                local widthPct = 1 / countInRow
                for j = i, math.min(i + maxPerRow - 1, #fontSizes) do
                    local sizeConfig = fontSizes[j]
                    local sizeSlider = GUIFrame:CreateSlider(row, sizeConfig.label or "Size", {
                        min = fontSizeRange[1],
                        max = fontSizeRange[2],
                        step = 1,
                        value = getValue(sizeConfig.dbKey, 18),
                        callback = function(val)
                            setValue(sizeConfig.dbKey, val)
                        end
                    })
                    row:AddWidget(sizeSlider, widthPct)
                    table_insert(widgets, sizeSlider)
                end
                card:AddRow(row, Theme.rowHeight)
            end
        else
            local row2 = GUIFrame:CreateRow(card.content, Theme.rowHeight)
            local fontSizeSlider = GUIFrame:CreateSlider(row2, "Font Size", {
                min = fontSizeRange[1],
                max = fontSizeRange[2],
                step = 1,
                value = getValue(keys.fontSize, 18),
                labelWidth = 60,
                callback = function(val)
                    setValue(keys.fontSize, val)
                end
            })
            row2:AddWidget(fontSizeSlider, 1)
            table_insert(widgets, fontSizeSlider)
            card:AddRow(row2, Theme.rowHeight)
        end
    end

    local rowSep = GUIFrame:CreateRow(card.content, Theme.rowHeightSeparator)
    local sep = GUIFrame:CreateSeparator(rowSep)
    rowSep:AddWidget(sep, 1)
    table_insert(widgets, sep)
    card:AddRow(rowSep, Theme.rowHeightSeparator)

    local row3 = GUIFrame:CreateRow(card.content, Theme.rowHeight)

    shadowEnableCheck = GUIFrame:CreateCheckbox(row3, "Font Shadow", {
        value = shadowDb[shadowKeys.enabled] == true,
        callback = function(checked)
            shadowDb[shadowKeys.enabled] = checked
            if onChange then onChange() end
            UpdateShadowState()
        end
    })
    row3:AddWidget(shadowEnableCheck, 0.5)
    table_insert(widgets, shadowEnableCheck)

    local shadowColorPicker = GUIFrame:CreateColorPicker(row3, "Shadow Color", {
        color = shadowDb[shadowKeys.color] or { 0, 0, 0, 1 },
        callback = function(r, g, b, a)
            shadowDb[shadowKeys.color] = { r, g, b, a }
            if onChange then onChange() end
        end
    })
    row3:AddWidget(shadowColorPicker, 0.5)
    table_insert(widgets, shadowColorPicker)
    table_insert(shadowSubWidgets, shadowColorPicker)
    card:AddRow(row3, Theme.rowHeight)

    local row4 = GUIFrame:CreateRow(card.content, Theme.rowHeightLast)

    local shadowXSlider = GUIFrame:CreateSlider(row4, "Shadow X", {
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
    table_insert(widgets, shadowXSlider)
    table_insert(shadowSubWidgets, shadowXSlider)

    local shadowYSlider = GUIFrame:CreateSlider(row4, "Shadow Y", {
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
    table_insert(widgets, shadowYSlider)
    table_insert(shadowSubWidgets, shadowYSlider)
    card:AddRow(row4, Theme.rowHeightLast, 0)

    card.fontWidgets = widgets
    card.shadowSubWidgets = shadowSubWidgets
    card.shadowEnableCheck = shadowEnableCheck
    card.globalOverrideCheck = globalOverrideCheck
    card.UpdateShadowState = UpdateShadowState
    card.UpdateGlobalOverrideState = UpdateGlobalOverrideState
    card._hasInternalWidgetState = true
    UpdateShadowState()
    if globalOverride then
        UpdateGlobalOverrideState()
    end

    ---@param enabled boolean
    ---@diagnostic disable-next-line: duplicate-set-field
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

        for _, widget in ipairs(self.fontWidgets) do
            if widget ~= globalOverrideCheck and widget ~= fontDropdownRef and widget.SetEnabled then
                widget:SetEnabled(enabled)
            end
        end

        -- Global override toggle always stays enabled
        if globalOverrideCheck and globalOverrideCheck.SetEnabled then
            globalOverrideCheck:SetEnabled(enabled)
        end

        -- Font dropdown respects global override state when card is enabled
        if enabled and globalOverride then
            UpdateGlobalOverrideState()
        elseif fontDropdownRef and fontDropdownRef.SetEnabled then
            fontDropdownRef:SetEnabled(enabled)
        end

        if enabled then
            UpdateShadowState()
        end
    end

    return card, card:GetNextOffset(), widgets
end

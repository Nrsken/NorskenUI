--[[
# FontSettingsCard

* Premade card for font face / size / outline / shadow, bound to a db table.
* Outlines that draw their own edge disable the shadow controls, and an optional
  "Use Global Font" override greys out the font dropdown.

## Examples

    page:FontSettingsCard({
        db = db,
        onChangeCallback = Apply
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end

lib.premadeCards = lib.premadeCards or {}

local tinsert = table.insert
local ipairs = ipairs
local strsplit = strsplit
local unpack = unpack
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
lib.premadeCards.FontSettingsCard = {
    title = "Font Settings",

    ---@param card KajiGUIFluentCard
    ---@param config table
    ---@param gui KajiGUIInstance
    build = function(card, config, gui)
        local theme = gui.theme
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

        local shadowSubWidgets = {}
        local shadowEnableCheck
        local fontDropdown

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
            if fontDropdown and fontDropdown.SetEnabled then
                fontDropdown:SetEnabled(not useGlobal)
            end
        end

        -- Optional "Use Global Font" toggle.
        if globalOverride then
            card:Row(theme.rowHeight):Checkbox(globalOverrideLabel, {
                width = 1,
                value = db[globalOverrideKey] ~= false,
                callback = function(checked)
                    db[globalOverrideKey] = checked
                    if onChange then onChange() end
                    UpdateGlobalOverrideState()
                end,
            })
            card:Separator()
        end

        -- Font face + outline.
        local row1 = card:Row(theme.rowHeight)

        fontDropdown = row1:Dropdown("Font", {
            width = 0.5,
            media = "font",
            value = getValue(keys.fontFace, "Friz Quadrata TT"),
            searchable = searchable,
            callback = function(key) setValue(keys.fontFace, key) end,
        })

        local outlineOptions = config.outlineOptions or DEFAULT_OUTLINE_OPTIONS
        if includeSoftOutline then
            outlineOptions = { unpack(outlineOptions) }
            tinsert(outlineOptions, { key = "SOFTOUTLINE", text = "Soft" })
        end

        row1:Dropdown("Outline", {
            width = 0.5,
            options = outlineOptions,
            value = getValue(keys.fontOutline, "OUTLINE"),
            callback = function(key)
                setValue(keys.fontOutline, key)
                UpdateShadowState()
            end,
        })

        -- Font size(s).
        if not hideFontSize then
            if fontSizes and #fontSizes > 0 then
                local perRow = 2
                for i = 1, #fontSizes, perRow do
                    local row = card:Row(theme.rowHeight)
                    local countInRow = min(perRow, #fontSizes - i + 1)
                    local widthPct = 1 / countInRow
                    for j = i, min(i + perRow - 1, #fontSizes) do
                        local sizeConfig = fontSizes[j]
                        row:Slider(sizeConfig.label or "Size", {
                            width = widthPct,
                            min = fontSizeRange[1],
                            max = fontSizeRange[2],
                            step = 1,
                            value = getValue(sizeConfig.dbKey, 18),
                            callback = function(val) setValue(sizeConfig.dbKey, val) end,
                        })
                    end
                end
            else
                card:Row(theme.rowHeight):Slider("Font Size", {
                    width = 1,
                    min = fontSizeRange[1],
                    max = fontSizeRange[2],
                    step = 1,
                    value = getValue(keys.fontSize, 18),
                    labelWidth = 60,
                    callback = function(val) setValue(keys.fontSize, val) end,
                })
            end
        end

        card:Separator()

        -- Shadow enable + color.
        local row3 = card:Row(theme.rowHeight)
        shadowEnableCheck = row3:Checkbox("Font Shadow", {
            width = 0.5,
            value = shadowDb[shadowKeys.enabled] == true,
            callback = function(checked)
                shadowDb[shadowKeys.enabled] = checked
                if onChange then onChange() end
                UpdateShadowState()
            end,
        })

        shadowSubWidgets[#shadowSubWidgets + 1] = row3:ColorPicker("Shadow Color", {
            width = 0.5,
            value = shadowDb[shadowKeys.color] or { 0, 0, 0, 1 },
            callback = function(r, g, b, a)
                shadowDb[shadowKeys.color] = { r, g, b, a }
                if onChange then onChange() end
            end,
        })

        -- Shadow X/Y offsets.
        local row4 = card:Row(theme.rowHeightLast, 0)
        shadowSubWidgets[#shadowSubWidgets + 1] = row4:Slider("Shadow X", {
            width = 0.5,
            min = shadowOffsetRange[1],
            max = shadowOffsetRange[2],
            step = 1,
            value = shadowDb[shadowKeys.offsetX] or 1,
            labelWidth = 15,
            callback = function(val)
                shadowDb[shadowKeys.offsetX] = val
                if onChange then onChange() end
            end,
        })

        shadowSubWidgets[#shadowSubWidgets + 1] = row4:Slider("Shadow Y", {
            width = 0.5,
            min = shadowOffsetRange[1],
            max = shadowOffsetRange[2],
            step = 1,
            value = shadowDb[shadowKeys.offsetY] or -1,
            labelWidth = 15,
            callback = function(val)
                shadowDb[shadowKeys.offsetY] = val
                if onChange then onChange() end
            end,
        })

        -- The outline choice, the shadow toggle and the global override all decide inner
        -- state that the manager's blanket pass would otherwise flatten, so re-derive after it.
        card:SetEnabledHandler(function(enabled)
            if not enabled then return end
            UpdateGlobalOverrideState()
            UpdateShadowState()
        end)

        UpdateShadowState()
        UpdateGlobalOverrideState()
    end,
}

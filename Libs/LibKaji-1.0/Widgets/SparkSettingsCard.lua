--[[
# SparkSettingsCard

* Premade card for spark settings.
* "Use Global Spark" override toggle, then texture + color, then scale + width.
* The override greys out every local control, not just the texture, because a global spark
* supplies them all together.
* Width is live only while the plain fill (`solidKey`, default "Solid") is selected, since
* every other spark derives its width from the art's own proportions.
* The texture dropdown reads the host's 'spark' LSM media type, so the host must have
* registered at least one spark before this card is built.

## Examples

    page:SparkSettingsCard({
        db = db,
        onChangeCallback = Apply
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin

local tinsert = table.insert
local ipairs = ipairs

--- Spark texture / scale / color settings bound to a db table.
---@param scrollChild Frame
---@param yOffset number
---@param config table
---@return KajiGUICard card
---@return number newYOffset
---@return Frame[] widgets
function InstanceMixin:CreateSparkSettingsCard(scrollChild, yOffset, config)
    config = config or {}
    local gui = self
    local theme = self.theme

    local title = config.title or "Spark Settings"
    local db = config.db
    local dbKeys = config.dbKeys or {}
    local onChange = config.onChangeCallback
    local searchable = config.searchable ~= false
    local scaleRange = config.scaleRange or { 0.5, 4 }
    local widthRange = config.widthRange or { 1, 16 }
    -- Only a plain fill can be stretched: every other spark takes its width from the art's
    -- own proportions. The host names the entry it registered as that fill.
    local solidKey = config.solidKey or "Solid"

    local globalOverride = config.globalOverride
    local globalOverrideKey = globalOverride and (globalOverride.dbKey or "UseGlobalSpark")
    local globalOverrideLabel = globalOverride and (globalOverride.label or "Use Global Spark")

    -- Hosts with a locale table can pass translated widget labels through here.
    local labels = config.labels or {}
    local textureLabel = labels.texture or "Spark Texture"
    local scaleLabel = labels.scale or "Spark Scale"
    local widthLabel = labels.width or "Spark Width"
    local colorLabel = labels.color or "Spark Color"

    -- Defaults match the keys the host's spark resolver reads off a module db.
    local keys = {
        texture = dbKeys.texture or "SparkTexture",
        scale = dbKeys.scale or "SparkScale",
        width = dbKeys.width or "SparkWidth",
        color = dbKeys.color or "SparkColor",
    }

    local function setValue(key, val)
        db[key] = val
        if onChange then onChange() end
    end

    local widgets = {}
    local localWidgets = {} -- everything a global spark supersedes
    local globalOverrideCheck
    local widthSlider

    -- The width slider answers to two conditions at once, so both are settled in one place:
    -- a global spark supersedes every local control, and width only applies to the plain fill.
    local function RefreshEnabledState()
        local localOn = (not globalOverride) or db[globalOverrideKey] == false
        for _, widget in ipairs(localWidgets) do
            if widget.SetEnabled then widget:SetEnabled(localOn) end
        end
        if widthSlider and widthSlider.SetEnabled then
            widthSlider:SetEnabled(localOn and (db[keys.texture] or solidKey) == solidKey)
        end
    end

    local card = gui:CreateCard(scrollChild, title, yOffset)

    -- Optional "Use Global Spark" toggle.
    if globalOverride then
        local overrideRow = gui:CreateRow(card.content, theme.rowHeight)
        globalOverrideCheck = gui:CreateCheckbox(overrideRow, globalOverrideLabel, {
            value = db[globalOverrideKey] ~= false,
            callback = function(checked)
                db[globalOverrideKey] = checked
                if onChange then onChange() end
                RefreshEnabledState()
            end
        })
        overrideRow:AddWidget(globalOverrideCheck, 1)
        tinsert(widgets, globalOverrideCheck)
        card:AddRow(overrideRow, theme.rowHeight)
        card:AddRow(gui:CreateSeparator(card.content), theme.rowHeightSeparator)
    end

    -- Texture + color, then scale + width below, mirroring the host's own global spark card.
    local textureRow = gui:CreateRow(card.content, theme.rowHeight)

    local textureDropdown = gui:CreateDropdown(textureRow, textureLabel, {
        media = "spark",
        value = db[keys.texture] or solidKey,
        searchable = searchable,
        callback = function(key)
            setValue(keys.texture, key)
            RefreshEnabledState() -- width only applies while the plain fill is selected
        end,
    })
    textureRow:AddWidget(textureDropdown, 0.5)
    tinsert(widgets, textureDropdown)
    tinsert(localWidgets, textureDropdown)

    local colorPicker = gui:CreateColorPicker(textureRow, colorLabel, {
        value = db[keys.color] or { 1, 1, 1, 1 },
        callback = function(r, g, b, a)
            setValue(keys.color, { r, g, b, a })
        end
    })
    textureRow:AddWidget(colorPicker, 0.5)
    tinsert(widgets, colorPicker)
    tinsert(localWidgets, colorPicker)
    card:AddRow(textureRow, theme.rowHeight)

    -- Scale + width.
    local styleRow = gui:CreateRow(card.content, theme.rowHeightLast)

    local scaleSlider = gui:CreateSlider(styleRow, scaleLabel, {
        min = scaleRange[1],
        max = scaleRange[2],
        step = 0.05,
        value = db[keys.scale] or 1,
        tooltip = config.scaleTooltip,
        callback = function(val) setValue(keys.scale, val) end,
        callbackOnRelease = true,
    })
    styleRow:AddWidget(scaleSlider, 0.5)
    tinsert(widgets, scaleSlider)
    tinsert(localWidgets, scaleSlider)

    widthSlider = gui:CreateSlider(styleRow, widthLabel, {
        min = widthRange[1],
        max = widthRange[2],
        step = 1,
        value = db[keys.width] or 2,
        tooltip = config.widthTooltip,
        callback = function(val) setValue(keys.width, val) end,
    })
    styleRow:AddWidget(widthSlider, 0.5)
    tinsert(widgets, widthSlider)
    -- Deliberately not in localWidgets: RefreshEnabledState owns it, so the global-override
    -- sweep cannot re-enable it while an art spark is selected.

    card:AddRow(styleRow, theme.rowHeightLast, 0)

    card.sparkWidgets = widgets
    card.globalOverrideCheck = globalOverrideCheck
    RefreshEnabledState()

    -- Deferred so SetEnabled runs after the plain inner widgets and its global-override
    -- derivation wins, instead of racing them in UpdateAll.
    card._hasInternalWidgetState = true

    function card:SetEnabled(enabled)
        local alpha = enabled and 1 or 0.5
        self:SetAlpha(alpha)
        if self.header then self.header:SetAlpha(alpha) end
        if self.titleText then self.titleText:SetAlpha(alpha) end

        for _, widget in ipairs(self.sparkWidgets) do
            if widget ~= globalOverrideCheck and widget.SetEnabled then
                widget:SetEnabled(enabled)
            end
        end

        -- The global-override toggle stays live so you can flip it back on.
        if globalOverrideCheck and globalOverrideCheck.SetEnabled then
            globalOverrideCheck:SetEnabled(enabled)
        end

        -- While the card is on, the override and texture decide the local controls, not this call.
        if enabled then RefreshEnabledState() end
    end

    return card, card:GetNextOffset(), widgets
end

-- Labels this card can surface, for the frameless search harvester (see Search.lua).
lib.premadeCardSearch = lib.premadeCardSearch or {}
function lib.premadeCardSearch.SparkSettingsCard(config)
    config = config or {}
    local given = config.labels or {}
    local labels = {
        config.title or "Spark Settings",
        given.texture or "Spark Texture",
        given.color or "Spark Color",
        given.scale or "Spark Scale",
        given.width or "Spark Width",
    }
    if config.globalOverride then
        labels[#labels + 1] = config.globalOverride.label or "Use Global Spark"
    end
    return labels
end

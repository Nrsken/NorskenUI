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

lib.premadeCards = lib.premadeCards or {}

local ipairs = ipairs

--- Spark texture / scale / color settings bound to a db table.
lib.premadeCards.SparkSettingsCard = {
    title = "Spark Settings",

    ---@param card KajiGUIFluentCard
    ---@param config table
    ---@param gui KajiGUIInstance
    build = function(card, config, gui)
        local theme = gui.theme
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

        local localWidgets = {} -- everything a global spark supersedes
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

        -- Optional "Use Global Spark" toggle. Left out of localWidgets so it stays live.
        if globalOverride then
            card:Row(theme.rowHeight):Checkbox(globalOverrideLabel, {
                width = 1,
                value = db[globalOverrideKey] ~= false,
                callback = function(checked)
                    db[globalOverrideKey] = checked
                    if onChange then onChange() end
                    RefreshEnabledState()
                end,
            })
            card:Separator()
        end

        -- Texture + color, then scale + width below, mirroring the host's own global spark card.
        local textureRow = card:Row(theme.rowHeight)

        localWidgets[#localWidgets + 1] = textureRow:Dropdown(textureLabel, {
            width = 0.5,
            media = "spark",
            value = db[keys.texture] or solidKey,
            searchable = searchable,
            callback = function(key)
                setValue(keys.texture, key)
                RefreshEnabledState() -- width only applies while the plain fill is selected
            end,
        })

        localWidgets[#localWidgets + 1] = textureRow:ColorPicker(colorLabel, {
            width = 0.5,
            value = db[keys.color] or { 1, 1, 1, 1 },
            callback = function(r, g, b, a) setValue(keys.color, { r, g, b, a }) end,
        })

        -- Scale + width.
        local styleRow = card:Row(theme.rowHeightLast, 0)

        localWidgets[#localWidgets + 1] = styleRow:Slider(scaleLabel, {
            width = 0.5,
            min = scaleRange[1],
            max = scaleRange[2],
            step = 0.05,
            value = db[keys.scale] or 1,
            tooltip = config.scaleTooltip,
            callback = function(val) setValue(keys.scale, val) end,
            callbackOnRelease = true,
        })

        -- Deliberately not in localWidgets: RefreshEnabledState owns it, so the global-override
        -- sweep cannot re-enable it while an art spark is selected.
        widthSlider = styleRow:Slider(widthLabel, {
            width = 0.5,
            min = widthRange[1],
            max = widthRange[2],
            step = 1,
            value = db[keys.width] or 2,
            tooltip = config.widthTooltip,
            callback = function(val) setValue(keys.width, val) end,
        })

        -- While the card is on, the override and texture decide the local controls, not the
        -- manager's blanket pass, so re-derive once it has run.
        card:SetEnabledHandler(function(enabled)
            if enabled then RefreshEnabledState() end
        end)

        RefreshEnabledState()
    end,
}

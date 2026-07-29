--[[
# GlowSettingsCard

* Premade card for glow settings: enable, type, color, speed and the per-type params.
* The visible rows depend on the glow type, so changing Type rebuilds the card in place.
* Every control except the enable checkbox follows the glow-enable toggle.

## Examples

    page:GlowSettingsCard({
        db = db,
        onChangeCallback = Apply
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end

lib.premadeCards = lib.premadeCards or {}

local ipairs = ipairs
local tinsert = table.insert

local GLOW_TYPES = {
    { key = "pixel",    text = "Pixel" },
    { key = "autocast", text = "Autocast" },
    { key = "button",   text = "Button" },
    { key = "proc",     text = "Proc" },
}

local GLOW_MODES = {
    { key = "always",     text = "Always Glow" },
    { key = "expiration", text = "Expiration Glow" },
}

-- Types that show the shared "Speed" (frequency) control.
local FREQUENCY_TYPES = { pixel = true, autocast = true, button = true }

---Glow enable / type / color / speed / per-type params bound to a db table.
lib.premadeCards.GlowSettingsCard = {
    title = "Glow Settings",

    ---@param card KajiGUIFluentCard
    ---@param config table
    ---@param gui KajiGUIInstance
    build = function(card, config, gui)
        local theme = gui.theme
        local db = config.db
        local dbKeys = config.dbKeys or {}
        local onChange = config.onChangeCallback
        local showGlowMode = config.showGlowMode
        local allowedTypes = config.glowTypes

        local glowTypeOptions = GLOW_TYPES
        if allowedTypes then
            glowTypeOptions = {}
            for _, glowType in ipairs(GLOW_TYPES) do
                for _, allowed in ipairs(allowedTypes) do
                    if glowType.key == allowed then
                        tinsert(glowTypeOptions, glowType)
                        break
                    end
                end
            end
        end

        local keys = {
            enabled = dbKeys.enabled or "GlowEnabled",
            type = dbKeys.type or "GlowType",
            color = dbKeys.color or "GlowColor",
            lines = dbKeys.lines or "GlowLines",
            frequency = dbKeys.frequency or "GlowFrequency",
            length = dbKeys.length or "GlowLength",
            thickness = dbKeys.thickness or "GlowThickness",
            border = dbKeys.border or "GlowBorder",
            scale = dbKeys.scale or "GlowScale",
            startAnim = dbKeys.startAnim or "GlowStartAnim",
            duration = dbKeys.duration or "GlowDuration",
            glowMode = dbKeys.glowMode or "GlowMode",
        }

        local function setValue(key, val)
            db[key] = val
            if onChange then onChange() end
        end

        -- Everything the glow-enable toggle greys out (i.e. all but the toggle itself).
        local gated = {}
        local function Gate(widget)
            gated[#gated + 1] = widget
            return widget
        end

        local function UpdateGlowState()
            local enabled = db[keys.enabled]
            for _, widget in ipairs(gated) do
                if widget.SetEnabled then widget:SetEnabled(enabled) end
            end
        end

        local glowType = db[keys.type]

        -- Which per-type rows are emitted for the current type.
        local isPixel = glowType == "pixel"
        local isAutocast = glowType == "autocast"
        local isProc = glowType == "proc"
        local showFrequencyRow = showGlowMode and FREQUENCY_TYPES[glowType]

        -- Resolve the last content row so it gets the trailing (spacing = 0) treatment.
        local lastSection
        if isPixel then
            lastSection = "pixel2"
        elseif isAutocast then
            lastSection = "autocast"
        elseif isProc then
            lastSection = "proc"
        elseif showFrequencyRow then
            lastSection = "frequency"
        else
            lastSection = "row2"
        end

        local function Row(id)
            local isLast = id == lastSection
            return card:Row(isLast and theme.rowHeightLast or theme.rowHeight, isLast and 0 or nil)
        end

        -- The type dropdown sits in row 1 or row 2 depending on the layout, but behaves the same.
        local function AddTypeDropdown(row)
            Gate(row:Dropdown("Type", {
                width = 0.5,
                options = glowTypeOptions,
                value = glowType,
                callback = function(val)
                    setValue(keys.type, val)
                    -- Different types show different rows, so rebuild the card.
                    card:Rebuild()
                end,
            }))
        end

        -- Row 1: Enable Glow + (When to Glow | Type)
        local row1 = card:Row(theme.rowHeight)
        row1:Checkbox("Enable Glow", {
            width = 0.5,
            value = db[keys.enabled],
            callback = function(checked)
                setValue(keys.enabled, checked)
                UpdateGlowState()
            end,
        })

        if showGlowMode then
            local storedGlowMode = db[keys.glowMode]
            local validGlowMode = (storedGlowMode == "always" or storedGlowMode == "expiration") and storedGlowMode or
                "always"
            Gate(row1:Dropdown("When to Glow", {
                width = 0.5,
                options = GLOW_MODES,
                value = validGlowMode,
                callback = function(key) setValue(keys.glowMode, key) end,
            }))
        else
            AddTypeDropdown(row1)
        end

        card:Separator()

        -- Row 2: (Type | Speed) + Color
        local row2 = Row("row2")
        if showGlowMode then
            AddTypeDropdown(row2)
        else
            Gate(row2:Slider("Speed", {
                width = 0.5,
                min = 0.05,
                max = 1,
                step = 0.05,
                value = db[keys.frequency],
                callback = function(val) setValue(keys.frequency, val) end,
            }))
        end

        Gate(row2:ColorPicker("Color", {
            width = 0.5,
            value = db[keys.color],
            callback = function(r, g, b, a)
                db[keys.color] = { r, g, b, a }
                if onChange then onChange() end
            end,
        }))

        -- Frequency (full width) - only in glow-mode layout, for types that support it.
        if showFrequencyRow then
            Gate(Row("frequency"):Slider("Speed", {
                width = 1,
                min = 0.05,
                max = 1,
                step = 0.05,
                value = db[keys.frequency],
                callback = function(val) setValue(keys.frequency, val) end,
            }))
        end

        -- Pixel: Lines / Length, then Thickness / Border.
        if isPixel then
            local rowPixel1 = card:Row(theme.rowHeight)
            Gate(rowPixel1:Slider("Lines", {
                width = 0.5,
                min = 1,
                max = 16,
                step = 1,
                value = db[keys.lines],
                callback = function(val) setValue(keys.lines, val) end,
            }))
            Gate(rowPixel1:Slider("Length", {
                width = 0.5,
                min = 1,
                max = 20,
                step = 1,
                value = db[keys.length],
                callback = function(val) setValue(keys.length, val) end,
            }))

            local rowPixel2 = Row("pixel2")
            Gate(rowPixel2:Slider("Thickness", {
                width = 0.5,
                min = 1,
                max = 8,
                step = 1,
                value = db[keys.thickness],
                callback = function(val) setValue(keys.thickness, val) end,
            }))
            Gate(rowPixel2:Checkbox("Border", {
                width = 0.5,
                value = db[keys.border],
                callback = function(checked) setValue(keys.border, checked) end,
            }))
        end

        -- Autocast: Particles / Scale.
        if isAutocast then
            local rowAutocast = Row("autocast")
            Gate(rowAutocast:Slider("Particles", {
                width = 0.5,
                min = 1,
                max = 16,
                step = 1,
                value = db[keys.lines],
                callback = function(val) setValue(keys.lines, val) end,
            }))
            Gate(rowAutocast:Slider("Scale", {
                width = 0.5,
                min = 0.5,
                max = 3,
                step = 0.1,
                value = db[keys.scale],
                callback = function(val) setValue(keys.scale, val) end,
            }))
        end

        -- Proc: Start Animation / Duration.
        if isProc then
            local rowProc = Row("proc")
            Gate(rowProc:Checkbox("Start Animation", {
                width = 0.5,
                value = db[keys.startAnim],
                callback = function(checked) setValue(keys.startAnim, checked) end,
            }))
            Gate(rowProc:Slider("Duration", {
                width = 0.5,
                min = 0.5,
                max = 5,
                step = 0.1,
                value = db[keys.duration],
                callback = function(val) setValue(keys.duration, val) end,
            }))
        end

        -- The glow-enable toggle decides the rest, so re-derive after the manager's
        -- blanket pass. When the card itself is off, that pass has already disabled everything.
        card:SetEnabledHandler(function(enabled)
            if enabled then UpdateGlowState() end
        end)

        UpdateGlowState()
    end,
}

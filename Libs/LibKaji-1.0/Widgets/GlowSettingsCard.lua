--[[
# GlowSettingsCard

* Premade card for a spell/aura glow: enable, glow type, color, speed and the per-type parameters: 
* pixel lines/length/thickness/border, autocast particles/scale,proc start-anim/duration.
* The visible parameter rows depend on the selected type, so changing Type rebuilds the card body in place (no full page refresh).

## Examples

?   page:GlowSettingsCard({
?       title = "Important Spell Glow",
?       db = db.ImportantGlow,
?       glowTypes = { "pixel", "autocast" },
?       onChangeCallback = Apply,
?   })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin

local ipairs = ipairs
local wipe = wipe
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
---@param scrollChild Frame
---@param yOffset number
---@param config table
---@return KajiGUICard card
---@return number newYOffset
---@return Frame[] widgets
function InstanceMixin:CreateGlowSettingsCard(scrollChild, yOffset, config)
    config = config or {}
    local gui = self
    local theme = self.theme

    local title = config.title or "Glow Settings"
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

    local widgets = {}
    local enableCheck
    local card = gui:CreateCard(scrollChild, title, yOffset)

    -- Greys out every widget except the enable checkbox based on the glow-enable toggle.
    local function UpdateGlowState()
        local enabled = db[keys.enabled]
        for _, widget in ipairs(widgets) do
            if widget ~= enableCheck and widget.SetEnabled then
                widget:SetEnabled(enabled)
            end
        end
    end

    local BuildContent
    -- Rebuilds the card in place when the glow type changes (different per-type rows).
    local function RebuildContent()
        if card._onBeforeRebuild then card._onBeforeRebuild(widgets) end
        wipe(widgets)
        enableCheck = nil
        card:Reset()
        BuildContent()
        if card._onAfterRebuild then card._onAfterRebuild(widgets) end
    end

    BuildContent = function()
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

        local function rowHeightFor(id) return id == lastSection and theme.rowHeightLast or theme.rowHeight end
        local function addRow(row, id) card:AddRow(row, rowHeightFor(id), id == lastSection and 0 or nil) end

        -- Row 1: Enable Glow + (When to Glow | Type)
        local row1 = gui:CreateRow(card.content, theme.rowHeight)
        enableCheck = gui:CreateCheckbox(row1, "Enable Glow", {
            value = db[keys.enabled],
            callback = function(checked)
                setValue(keys.enabled, checked)
                UpdateGlowState()
            end
        })
        row1:AddWidget(enableCheck, 0.5)
        tinsert(widgets, enableCheck)

        if showGlowMode then
            local storedGlowMode = db[keys.glowMode]
            local validGlowMode = (storedGlowMode == "always" or storedGlowMode == "expiration") and storedGlowMode or
                "always"
            local glowModeDropdown = gui:CreateDropdown(row1, "When to Glow", {
                options = GLOW_MODES,
                value = validGlowMode,
                callback = function(key) setValue(keys.glowMode, key) end
            })
            row1:AddWidget(glowModeDropdown, 0.5)
            tinsert(widgets, glowModeDropdown)
        else
            local typeDropdown = gui:CreateDropdown(row1, "Type", {
                options = glowTypeOptions,
                value = glowType,
                callback = function(val)
                    setValue(keys.type, val)
                    RebuildContent()
                end
            })
            row1:AddWidget(typeDropdown, 0.5)
            tinsert(widgets, typeDropdown)
        end
        card:AddRow(row1, theme.rowHeight)
        card:AddRow(gui:CreateSeparator(card.content), theme.rowHeightSeparator)

        -- Row 2: (Type | Speed) + Color
        local row2 = gui:CreateRow(card.content, rowHeightFor("row2"))
        if showGlowMode then
            local typeDropdown = gui:CreateDropdown(row2, "Type", {
                options = glowTypeOptions,
                value = glowType,
                callback = function(val)
                    setValue(keys.type, val)
                    RebuildContent()
                end
            })
            row2:AddWidget(typeDropdown, 0.5)
            tinsert(widgets, typeDropdown)
        else
            local freqSlider = gui:CreateSlider(row2, "Speed", {
                min = 0.05,
                max = 1,
                step = 0.05,
                value = db[keys.frequency],
                callback = function(val) setValue(keys.frequency, val) end
            })
            row2:AddWidget(freqSlider, 0.5)
            tinsert(widgets, freqSlider)
        end

        local colorPicker = gui:CreateColorPicker(row2, "Color", {
            value = db[keys.color],
            callback = function(r, g, b, a)
                db[keys.color] = { r, g, b, a }
                if onChange then onChange() end
            end
        })
        row2:AddWidget(colorPicker, 0.5)
        tinsert(widgets, colorPicker)
        addRow(row2, "row2")

        -- Frequency (full width) - only in glow-mode layout, for types that support it.
        if showFrequencyRow then
            local rowFreq = gui:CreateRow(card.content, rowHeightFor("frequency"))
            local freqSlider = gui:CreateSlider(rowFreq, "Speed", {
                min = 0.05,
                max = 1,
                step = 0.05,
                value = db[keys.frequency],
                callback = function(val) setValue(keys.frequency, val) end
            })
            rowFreq:AddWidget(freqSlider, 1)
            tinsert(widgets, freqSlider)
            addRow(rowFreq, "frequency")
        end

        -- Pixel: Lines / Length, then Thickness / Border.
        if isPixel then
            local rowPixel1 = gui:CreateRow(card.content, theme.rowHeight)
            local linesSlider = gui:CreateSlider(rowPixel1, "Lines", {
                min = 1,
                max = 16,
                step = 1,
                value = db[keys.lines],
                callback = function(val) setValue(keys.lines, val) end
            })
            rowPixel1:AddWidget(linesSlider, 0.5)
            tinsert(widgets, linesSlider)

            local lengthSlider = gui:CreateSlider(rowPixel1, "Length", {
                min = 1,
                max = 20,
                step = 1,
                value = db[keys.length],
                callback = function(val) setValue(keys.length, val) end
            })
            rowPixel1:AddWidget(lengthSlider, 0.5)
            tinsert(widgets, lengthSlider)
            card:AddRow(rowPixel1, theme.rowHeight)

            local rowPixel2 = gui:CreateRow(card.content, rowHeightFor("pixel2"))
            local thicknessSlider = gui:CreateSlider(rowPixel2, "Thickness", {
                min = 1,
                max = 8,
                step = 1,
                value = db[keys.thickness],
                callback = function(val) setValue(keys.thickness, val) end
            })
            rowPixel2:AddWidget(thicknessSlider, 0.5)
            tinsert(widgets, thicknessSlider)

            local borderCheck = gui:CreateCheckbox(rowPixel2, "Border", {
                value = db[keys.border],
                callback = function(checked) setValue(keys.border, checked) end
            })
            rowPixel2:AddWidget(borderCheck, 0.5)
            tinsert(widgets, borderCheck)
            addRow(rowPixel2, "pixel2")
        end

        -- Autocast: Particles / Scale.
        if isAutocast then
            local rowAutocast = gui:CreateRow(card.content, rowHeightFor("autocast"))
            local particlesSlider = gui:CreateSlider(rowAutocast, "Particles", {
                min = 1,
                max = 16,
                step = 1,
                value = db[keys.lines],
                callback = function(val) setValue(keys.lines, val) end
            })
            rowAutocast:AddWidget(particlesSlider, 0.5)
            tinsert(widgets, particlesSlider)

            local scaleSlider = gui:CreateSlider(rowAutocast, "Scale", {
                min = 0.5,
                max = 3,
                step = 0.1,
                value = db[keys.scale],
                callback = function(val) setValue(keys.scale, val) end
            })
            rowAutocast:AddWidget(scaleSlider, 0.5)
            tinsert(widgets, scaleSlider)
            addRow(rowAutocast, "autocast")
        end

        -- Proc: Start Animation / Duration.
        if isProc then
            local rowProc = gui:CreateRow(card.content, rowHeightFor("proc"))
            local startAnimCheck = gui:CreateCheckbox(rowProc, "Start Animation", {
                value = db[keys.startAnim],
                callback = function(checked) setValue(keys.startAnim, checked) end
            })
            rowProc:AddWidget(startAnimCheck, 0.5)
            tinsert(widgets, startAnimCheck)

            local durationSlider = gui:CreateSlider(rowProc, "Duration", {
                min = 0.5,
                max = 5,
                step = 0.1,
                value = db[keys.duration],
                callback = function(val) setValue(keys.duration, val) end
            })
            rowProc:AddWidget(durationSlider, 0.5)
            tinsert(widgets, durationSlider)
            addRow(rowProc, "proc")
        end

        UpdateGlowState()
    end

    BuildContent()

    card.glowWidgets = widgets
    card.UpdateGlowState = UpdateGlowState

    -- Deferred so SetEnabled runs after the plain inner widgets and its glow-enable
    -- derivation wins, instead of racing them in UpdateAll.
    card._hasInternalWidgetState = true

    function card:SetEnabled(enabled)
        local alpha = enabled and 1 or 0.5
        self:SetAlpha(alpha)
        if self.header then self.header:SetAlpha(alpha) end
        if self.titleText then self.titleText:SetAlpha(alpha) end

        if enabled then
            if enableCheck and enableCheck.SetEnabled then enableCheck:SetEnabled(true) end
            UpdateGlowState()
        else
            for _, widget in ipairs(self.glowWidgets) do
                if widget.SetEnabled then widget:SetEnabled(false) end
            end
        end
    end

    return card, card:GetNextOffset(), widgets
end

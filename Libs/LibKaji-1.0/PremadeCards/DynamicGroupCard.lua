--[[
# DynamicGroupCard

* Premade card for a dynamic group's layout: grow direction, alignment, spacing,
  grid options and an optional visible-count limit.
* The alignment options and the GRID-only rows depend on the grow direction, so
  changing Grow rebuilds the card in place (no full page refresh).

## Examples

    page:DynamicGroupCard({
        db = db,
        onChangeCallback = Apply
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end

lib.premadeCards = lib.premadeCards or {}

local ipairs = ipairs

-- Grow directions whose cross-axis is horizontal (align uses LEFT/CENTER/RIGHT).
local VERTICAL_GROW = { DOWN = true, UP = true, VERTICAL = true }

local DEFAULT_GROW_OPTIONS = {
    { key = "DOWN",       text = "Down" },
    { key = "UP",         text = "Up" },
    { key = "RIGHT",      text = "Right" },
    { key = "LEFT",       text = "Left" },
    { key = "HORIZONTAL", text = "Horizontal (centered)" },
    { key = "VERTICAL",   text = "Vertical (centered)" },
    { key = "GRID",       text = "Grid" },
}

local ALIGN_OPTIONS_VERTICAL = {
    { key = "LEFT",   text = "Left" },
    { key = "CENTER", text = "Center" },
    { key = "RIGHT",  text = "Right" },
}

local ALIGN_OPTIONS_HORIZONTAL = {
    { key = "TOP",    text = "Top" },
    { key = "CENTER", text = "Center" },
    { key = "BOTTOM", text = "Bottom" },
}

local GRID_TYPES = {
    { key = "RD", text = "Right then Down" },
    { key = "RU", text = "Right then Up" },
    { key = "LD", text = "Left then Down" },
    { key = "LU", text = "Left then Up" },
    { key = "DR", text = "Down then Right" },
    { key = "DL", text = "Down then Left" },
    { key = "UR", text = "Up then Right" },
    { key = "UL", text = "Up then Left" },
}

---Resolve the align option list and a validity lookup for a grow direction.
---@param grow string
---@return { key: string, text: string }[] options, table<string, boolean> valid
local function AlignOptionsFor(grow)
    local options = VERTICAL_GROW[grow] and ALIGN_OPTIONS_VERTICAL or ALIGN_OPTIONS_HORIZONTAL
    local valid = {}
    for _, opt in ipairs(options) do valid[opt.key] = true end
    return options, valid
end

--- Grow / align / spacing / grid / limit controls bound to a db table.
lib.premadeCards.DynamicGroupCard = {
    title = "Dynamic Group",

    ---@param card KajiGUIFluentCard
    ---@param config table
    ---@param gui KajiGUIInstance
    build = function(card, config, gui)
        local theme = gui.theme
        local db = config.db
        local dbKeys = config.dbKeys or {}
        local onChange = config.onChangeCallback
        local showLimit = config.showLimit ~= false
        local growOptions = config.growOptions or DEFAULT_GROW_OPTIONS
        local spacingRange = config.spacingRange or { 0, 20 }
        local gridWidthRange = config.gridWidthRange or { 1, 20 }
        local limitRange = config.limitRange or { 1, 40 }

        local keys = {
            Grow = dbKeys.Grow or "Grow",
            Align = dbKeys.Align or "Align",
            Spacing = dbKeys.Spacing or "Spacing",
            RowSpacing = dbKeys.RowSpacing or "RowSpacing",
            GridType = dbKeys.GridType or "GridType",
            GridWidth = dbKeys.GridWidth or "GridWidth",
            UseLimit = dbKeys.UseLimit or "UseLimit",
            Limit = dbKeys.Limit or "Limit",
        }

        local function getValue(key, default)
            local v = db[key]
            if v ~= nil then return v end
            return default
        end

        local function setValue(key, val)
            db[key] = val
            if onChange then onChange() end
        end

        local limitSlider

        local function UpdateLimitState()
            if limitSlider and limitSlider.SetEnabled then
                limitSlider:SetEnabled(getValue(keys.UseLimit, false) == true)
            end
        end

        local grow = getValue(keys.Grow, "DOWN")
        local isGrid = grow == "GRID"

        -- Row 1: grow direction + (align selector | grid fill).
        local row1 = card:Row(theme.rowHeight)
        row1:Dropdown("Grow Direction", {
            width = 0.5,
            options = growOptions,
            value = grow,
            callback = function(val)
                setValue(keys.Grow, val)
                -- Alignment options and the GRID rows depend on this, so rebuild the card.
                card:Rebuild()
            end,
        })

        if isGrid then
            row1:Dropdown("Grid Fill", {
                width = 0.5,
                options = GRID_TYPES,
                value = getValue(keys.GridType, "RD"),
                callback = function(val) setValue(keys.GridType, val) end,
            })
        else
            local alignOptions, validAlign = AlignOptionsFor(grow)
            local alignValue = getValue(keys.Align, "CENTER")
            if not validAlign[alignValue] then alignValue = "CENTER" end
            row1:Dropdown("Alignment", {
                width = 0.5,
                options = alignOptions,
                value = alignValue,
                callback = function(val) setValue(keys.Align, val) end,
            })
        end

        -- Row 2: spacing (+ row spacing for GRID).
        local spacingLast = not isGrid and not showLimit
        local spacingHeight = spacingLast and theme.rowHeightLast or theme.rowHeight
        local row2 = card:Row(spacingHeight, spacingLast and 0 or nil)
        row2:Slider("Spacing", {
            width = isGrid and 0.5 or 1,
            min = spacingRange[1],
            max = spacingRange[2],
            step = 1,
            value = getValue(keys.Spacing, 1),
            callback = function(val) setValue(keys.Spacing, val) end,
        })

        if isGrid then
            row2:Slider("Row Spacing", {
                width = 0.5,
                min = spacingRange[1],
                max = spacingRange[2],
                step = 1,
                value = getValue(keys.RowSpacing, getValue(keys.Spacing, 1)),
                callback = function(val) setValue(keys.RowSpacing, val) end,
            })
        end

        -- Row 3 (GRID only): grid width / children per run.
        if isGrid then
            local gridLast = not showLimit
            local gridHeight = gridLast and theme.rowHeightLast or theme.rowHeight
            card:Row(gridHeight, gridLast and 0 or nil):Slider("Grid Width", {
                width = 1,
                min = gridWidthRange[1],
                max = gridWidthRange[2],
                step = 1,
                value = getValue(keys.GridWidth, 5),
                callback = function(val) setValue(keys.GridWidth, val) end,
            })
        end

        -- Limit section: cap the number of visible children.
        if showLimit then
            card:Separator()

            local rowLimit = card:Row(theme.rowHeightLast, 0)
            rowLimit:Checkbox("Use Limit", {
                width = 0.5,
                value = getValue(keys.UseLimit, false),
                callback = function(checked)
                    setValue(keys.UseLimit, checked)
                    UpdateLimitState()
                end,
            })

            limitSlider = rowLimit:Slider("Limit", {
                width = 0.5,
                min = limitRange[1],
                max = limitRange[2],
                step = 1,
                value = getValue(keys.Limit, 5),
                callback = function(val) setValue(keys.Limit, val) end,
            })
        end

        -- The limit slider only follows the master enable when Use Limit is on, so it is
        -- re-derived after the manager's blanket pass.
        card:SetEnabledHandler(function(enabled)
            if enabled then UpdateLimitState() end
        end)

        UpdateLimitState()
    end,
}

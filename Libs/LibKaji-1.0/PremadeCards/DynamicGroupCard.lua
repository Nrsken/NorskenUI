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

local L = lib.L
local ipairs = ipairs

-- Grow directions whose cross-axis is horizontal (align uses LEFT/CENTER/RIGHT).
local VERTICAL_GROW = { DOWN = true, UP = true, VERTICAL = true }

---Resolve the align option list and a validity lookup for a grow direction.
---@param grow string
---@return { key: string, text: string }[] options, table<string, boolean> valid
local function AlignOptionsFor(grow)
    local options
    if VERTICAL_GROW[grow] then
        options = {
            { key = "LEFT",   text = L["Left"] },
            { key = "CENTER", text = L["Center"] },
            { key = "RIGHT",  text = L["Right"] },
        }
    else
        options = {
            { key = "TOP",    text = L["Top"] },
            { key = "CENTER", text = L["Center"] },
            { key = "BOTTOM", text = L["Bottom"] },
        }
    end

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
        local growOptions = config.growOptions or {
            { key = "DOWN",       text = L["Down"] },
            { key = "UP",         text = L["Up"] },
            { key = "RIGHT",      text = L["Right"] },
            { key = "LEFT",       text = L["Left"] },
            { key = "HORIZONTAL", text = L["Horizontal (centered)"] },
            { key = "VERTICAL",   text = L["Vertical (centered)"] },
            { key = "GRID",       text = L["Grid"] },
        }
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
        row1:Dropdown(L["Grow Direction"], {
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
            row1:Dropdown(L["Grid Fill"], {
                width = 0.5,
                options = {
                    { key = "RD", text = L["Right then Down"] },
                    { key = "RU", text = L["Right then Up"] },
                    { key = "LD", text = L["Left then Down"] },
                    { key = "LU", text = L["Left then Up"] },
                    { key = "DR", text = L["Down then Right"] },
                    { key = "DL", text = L["Down then Left"] },
                    { key = "UR", text = L["Up then Right"] },
                    { key = "UL", text = L["Up then Left"] },
                },
                value = getValue(keys.GridType, "RD"),
                callback = function(val) setValue(keys.GridType, val) end,
            })
        else
            local alignOptions, validAlign = AlignOptionsFor(grow)
            local alignValue = getValue(keys.Align, "CENTER")
            if not validAlign[alignValue] then alignValue = "CENTER" end
            row1:Dropdown(L["Alignment"], {
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
        row2:Slider(L["Spacing"], {
            width = isGrid and 0.5 or 1,
            min = spacingRange[1],
            max = spacingRange[2],
            step = 1,
            value = getValue(keys.Spacing, 1),
            callback = function(val) setValue(keys.Spacing, val) end,
        })

        if isGrid then
            row2:Slider(L["Row Spacing"], {
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
            card:Row(gridHeight, gridLast and 0 or nil):Slider(L["Grid Width"], {
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
            rowLimit:Checkbox(L["Use Limit"], {
                width = 0.5,
                value = getValue(keys.UseLimit, false),
                callback = function(checked)
                    setValue(keys.UseLimit, checked)
                    UpdateLimitState()
                end,
            })

            limitSlider = rowLimit:Slider(L["Limit"], {
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

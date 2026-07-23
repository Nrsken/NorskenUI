--[[
# DynamicGroupCard

* Premade card for a dynamic group's layout: grow direction, alignment, spacing,
  grid options and an optional visible-count limit.
* The alignment options and the GRID-only rows depend on the grow direction, so
  changing Grow rebuilds the card body in place (no full page refresh).

## Examples

?   page:DynamicGroupCard({
?       db = db,
?       onChangeCallback = Apply
?   })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin

local ipairs = ipairs
local wipe = wipe
local tinsert = table.insert

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
---@param scrollChild Frame
---@param yOffset number
---@param config table
---@return KajiGUICard card
---@return number newYOffset
---@return Frame[] widgets
function InstanceMixin:CreateDynamicGroupCard(scrollChild, yOffset, config)
    config = config or {}
    local gui = self
    local theme = self.theme

    local title = config.title or "Dynamic Group"
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

    local widgets = {}
    local limitSlider
    local card = gui:CreateCard(scrollChild, title, yOffset)

    local function UpdateLimitState()
        if limitSlider and limitSlider.SetEnabled then
            limitSlider:SetEnabled(getValue(keys.UseLimit, false) == true)
        end
    end

    local BuildContent
    -- Rebuilds the card in place when the grow direction changes.
    -- A page provides the hooks to unregister the old widgets, re-register the new ones and reflow.
    local function RebuildContent()
        if card._onBeforeRebuild then card._onBeforeRebuild(widgets) end
        wipe(widgets)
        limitSlider = nil
        card:Reset()
        BuildContent()
        if card._onAfterRebuild then card._onAfterRebuild(widgets) end
    end

    BuildContent = function()
        local grow = getValue(keys.Grow, "DOWN")
        local isGrid = grow == "GRID"

        -- Row 1: grow direction + (align selector | grid fill).
        local row1 = gui:CreateRow(card.content, theme.rowHeight)
        local growDropdown = gui:CreateDropdown(row1, "Grow Direction", {
            options = growOptions,
            value = grow,
            callback = function(val)
                setValue(keys.Grow, val)
                RebuildContent()
            end
        })
        row1:AddWidget(growDropdown, 0.5)
        tinsert(widgets, growDropdown)

        if isGrid then
            local gridTypeDropdown = gui:CreateDropdown(row1, "Grid Fill", {
                options = GRID_TYPES,
                value = getValue(keys.GridType, "RD"),
                callback = function(val) setValue(keys.GridType, val) end
            })
            row1:AddWidget(gridTypeDropdown, 0.5)
            tinsert(widgets, gridTypeDropdown)
        else
            local alignOptions, validAlign = AlignOptionsFor(grow)
            local alignValue = getValue(keys.Align, "CENTER")
            if not validAlign[alignValue] then alignValue = "CENTER" end
            local alignDropdown = gui:CreateDropdown(row1, "Alignment", {
                options = alignOptions,
                value = alignValue,
                callback = function(val) setValue(keys.Align, val) end
            })
            row1:AddWidget(alignDropdown, 0.5)
            tinsert(widgets, alignDropdown)
        end
        card:AddRow(row1, theme.rowHeight)

        -- Row 2: spacing (+ row spacing for GRID).
        local spacingLast = not isGrid and not showLimit
        local spacingHeight = spacingLast and theme.rowHeightLast or theme.rowHeight
        local row2 = gui:CreateRow(card.content, spacingHeight)
        local spacingSlider = gui:CreateSlider(row2, "Spacing", {
            min = spacingRange[1],
            max = spacingRange[2],
            step = 1,
            value = getValue(keys.Spacing, 1),
            callback = function(val) setValue(keys.Spacing, val) end
        })
        row2:AddWidget(spacingSlider, isGrid and 0.5 or 1)
        tinsert(widgets, spacingSlider)

        if isGrid then
            local rowSpacingSlider = gui:CreateSlider(row2, "Row Spacing", {
                min = spacingRange[1],
                max = spacingRange[2],
                step = 1,
                value = getValue(keys.RowSpacing, getValue(keys.Spacing, 1)),
                callback = function(val) setValue(keys.RowSpacing, val) end
            })
            row2:AddWidget(rowSpacingSlider, 0.5)
            tinsert(widgets, rowSpacingSlider)
        end
        card:AddRow(row2, spacingHeight, spacingLast and 0 or nil)

        -- Row 3 (GRID only): grid width / children per run.
        if isGrid then
            local gridLast = not showLimit
            local gridHeight = gridLast and theme.rowHeightLast or theme.rowHeight
            local row3 = gui:CreateRow(card.content, gridHeight)
            local gridWidthSlider = gui:CreateSlider(row3, "Grid Width", {
                min = gridWidthRange[1],
                max = gridWidthRange[2],
                step = 1,
                value = getValue(keys.GridWidth, 5),
                callback = function(val) setValue(keys.GridWidth, val) end
            })
            row3:AddWidget(gridWidthSlider, 1)
            tinsert(widgets, gridWidthSlider)
            card:AddRow(row3, gridHeight, gridLast and 0 or nil)
        end

        -- Limit section: cap the number of visible children.
        if showLimit then
            card:AddRow(gui:CreateSeparator(card.content), theme.rowHeightSeparator)

            local rowLimit = gui:CreateRow(card.content, theme.rowHeightLast)
            local useLimitCheck = gui:CreateCheckbox(rowLimit, "Use Limit", {
                value = getValue(keys.UseLimit, false),
                callback = function(checked)
                    setValue(keys.UseLimit, checked)
                    UpdateLimitState()
                end
            })
            rowLimit:AddWidget(useLimitCheck, 0.5)
            tinsert(widgets, useLimitCheck)

            limitSlider = gui:CreateSlider(rowLimit, "Limit", {
                min = limitRange[1],
                max = limitRange[2],
                step = 1,
                value = getValue(keys.Limit, 5),
                callback = function(val) setValue(keys.Limit, val) end
            })
            rowLimit:AddWidget(limitSlider, 0.5)
            tinsert(widgets, limitSlider)
            card:AddRow(rowLimit, theme.rowHeightLast, 0)
        end

        UpdateLimitState()
    end

    BuildContent()

    card.groupWidgets = widgets
    card.UpdateLimitState = UpdateLimitState

    -- Deferred so SetEnabled runs after the plain inner widgets and its
    -- UpdateLimitState derivation wins, instead of racing them in UpdateAll.
    card._hasInternalWidgetState = true

    function card:SetEnabled(enabled)
        local alpha = enabled and 1 or 0.5
        self:SetAlpha(alpha)
        if self.header then self.header:SetAlpha(alpha) end
        if self.titleText then self.titleText:SetAlpha(alpha) end

        for _, widget in ipairs(self.groupWidgets) do
            if widget.SetEnabled then widget:SetEnabled(enabled) end
        end

        -- The limit slider only follows the master enable when Use Limit is on.
        if enabled then UpdateLimitState() end
    end

    return card, card:GetNextOffset(), widgets
end

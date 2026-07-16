---@class NUIDynamicGroupCard : NUICard
---@field groupWidgets NUIWidget[]
---@field limitSlider NUISlider?
---@field UpdateLimitState fun()
---@field _hasInternalWidgetState boolean

---@class NUIDynamicGroupCardDbKeys
---@field Grow? string
---@field Align? string
---@field Spacing? string
---@field RowSpacing? string
---@field GridType? string
---@field GridWidth? string
---@field UseLimit? string
---@field Limit? string

---@class NUIDynamicGroupCardConfig
---@field title? string
---@field db table
---@field dbKeys? NUIDynamicGroupCardDbKeys
---@field onChangeCallback? fun()
---@field showLimit? boolean
---@field spacingRange? number[]
---@field gridWidthRange? number[]
---@field limitRange? number[]

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local table_insert = table.insert

-- Grow directions whose cross-axis is horizontal (align uses LEFT/CENTER/RIGHT).
local VERTICAL_GROW = { DOWN = true, UP = true, VERTICAL = true }

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
    for _, opt in ipairs(options) do
        valid[opt.key] = true
    end
    return options, valid
end

---DynamicGroup layout settings card: grow direction, alignment, spacing, grid and visible-limit controls.
---The GRID-only rows (row spacing, grid fill, grid width) and the alignment options both depend on the
---current grow direction, so changing Grow rebuilds the panel via RefreshContent.
---```lua
---config = {
---    title = string,              -- Card header (default: "Dynamic Group")
---    db = table,                  -- Database table to read/write (required)
---    dbKeys = table,              -- Custom keys for db fields
---    onChangeCallback = function, -- Called when any value changes
---    showLimit = boolean,         -- Show the "Use Limit" + "Limit" controls (default: true)
---    spacingRange = {min, max},   -- Spacing/row spacing slider range (default: {0, 20})
---    gridWidthRange = {min, max}, -- Grid width slider range (default: {1, 20})
---    limitRange = {min, max},     -- Limit slider range (default: {1, 40})
---}
---```
---@param scrollChild Frame
---@param yOffset number
---@param config NUIDynamicGroupCardConfig
---@return NUIDynamicGroupCard card
---@return number newYOffset
---@return NUIWidget[] widgets
function GUIFrame:CreateDynamicGroupCard(scrollChild, yOffset, config)
    config = config or {}
    local title = config.title or "Dynamic Group"
    local db = config.db
    local dbKeys = config.dbKeys or {}
    local onChange = config.onChangeCallback
    local showLimit = config.showLimit ~= false
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

    local grow = getValue(keys.Grow, "DOWN")
    local isGrid = grow == "GRID"

    ---@type NUIWidget[]
    local widgets = {}
    ---@type NUISlider?
    local limitSlider

    local card = GUIFrame:CreateCard(scrollChild, title, yOffset) --[[@as NUIDynamicGroupCard]]

    local function UpdateLimitState()
        if limitSlider and limitSlider.SetEnabled then
            limitSlider:SetEnabled(getValue(keys.UseLimit, false) == true)
        end
    end

    -- Row 1: Grow direction, paired with the align selector (linear) or grid fill (GRID).
    local row1 = GUIFrame:CreateRow(card.content, Theme.rowHeight)

    local growDropdown = GUIFrame:CreateDropdown(row1, "Grow Direction", {
        options = NRSKNUI.GrowTypes,
        value = grow,
        callback = function(val)
            setValue(keys.Grow, val)
            -- The available align options and the GRID-only rows are structural, so rebuild.
            C_Timer.After(0.25, function()
                GUIFrame:RefreshContent()
            end)
        end
    })
    row1:AddWidget(growDropdown, 0.5)
    table_insert(widgets, growDropdown)

    if isGrid then
        local gridTypeDropdown = GUIFrame:CreateDropdown(row1, "Grid Fill", {
            options = GRID_TYPES,
            value = getValue(keys.GridType, "RD"),
            callback = function(val)
                setValue(keys.GridType, val)
            end
        })
        row1:AddWidget(gridTypeDropdown, 0.5)
        table_insert(widgets, gridTypeDropdown)
    else
        local alignOptions, validAlign = AlignOptionsFor(grow)
        local alignValue = getValue(keys.Align, "CENTER")
        if not validAlign[alignValue] then alignValue = "CENTER" end
        local alignDropdown = GUIFrame:CreateDropdown(row1, "Alignment", {
            options = alignOptions,
            value = alignValue,
            callback = function(val)
                setValue(keys.Align, val)
            end
        })
        row1:AddWidget(alignDropdown, 0.5)
        table_insert(widgets, alignDropdown)
    end
    card:AddRow(row1, Theme.rowHeight)

    -- Row 2: Spacing (+ row spacing for GRID).
    local spacingLast = not isGrid and not showLimit
    local row2 = GUIFrame:CreateRow(card.content, spacingLast and Theme.rowHeightLast or Theme.rowHeight)

    local spacingSlider = GUIFrame:CreateSlider(row2, "Spacing", {
        min = spacingRange[1],
        max = spacingRange[2],
        step = 1,
        value = getValue(keys.Spacing, 1),
        callback = function(val)
            setValue(keys.Spacing, val)
        end
    })
    row2:AddWidget(spacingSlider, isGrid and 0.5 or 1)
    table_insert(widgets, spacingSlider)

    if isGrid then
        local rowSpacingSlider = GUIFrame:CreateSlider(row2, "Row Spacing", {
            min = spacingRange[1],
            max = spacingRange[2],
            step = 1,
            value = getValue(keys.RowSpacing, getValue(keys.Spacing, 1)),
            callback = function(val)
                setValue(keys.RowSpacing, val)
            end
        })
        row2:AddWidget(rowSpacingSlider, 0.5)
        table_insert(widgets, rowSpacingSlider)
    end
    card:AddRow(row2, spacingLast and Theme.rowHeightLast or Theme.rowHeight, spacingLast and 0 or nil)

    -- Row 3 (GRID only): grid width / children per run.
    if isGrid then
        local gridLast = not showLimit
        local row3 = GUIFrame:CreateRow(card.content, gridLast and Theme.rowHeightLast or Theme.rowHeight)
        local gridWidthSlider = GUIFrame:CreateSlider(row3, "Grid Width", {
            min = gridWidthRange[1],
            max = gridWidthRange[2],
            step = 1,
            value = getValue(keys.GridWidth, 5),
            callback = function(val)
                setValue(keys.GridWidth, val)
            end
        })
        row3:AddWidget(gridWidthSlider, 1)
        table_insert(widgets, gridWidthSlider)
        card:AddRow(row3, gridLast and Theme.rowHeightLast or Theme.rowHeight, gridLast and 0 or nil)
    end

    -- Limit section: cap the number of visible children.
    if showLimit then
        local sep = GUIFrame:CreateSeparator(card.content)
        card:AddRow(sep, Theme.rowHeightSeparator)

        local rowLimit = GUIFrame:CreateRow(card.content, Theme.rowHeightLast)
        local useLimitCheck = GUIFrame:CreateCheckbox(rowLimit, "Use Limit", {
            value = getValue(keys.UseLimit, false),
            callback = function(checked)
                setValue(keys.UseLimit, checked)
                UpdateLimitState()
            end
        })
        rowLimit:AddWidget(useLimitCheck, 0.5)
        table_insert(widgets, useLimitCheck)

        limitSlider = GUIFrame:CreateSlider(rowLimit, "Limit", {
            min = limitRange[1],
            max = limitRange[2],
            step = 1,
            value = getValue(keys.Limit, 5),
            callback = function(val)
                setValue(keys.Limit, val)
            end
        })
        rowLimit:AddWidget(limitSlider, 0.5)
        table_insert(widgets, limitSlider)
        card:AddRow(rowLimit, Theme.rowHeightLast, 0)
    end

    card.groupWidgets = widgets
    card.limitSlider = limitSlider
    card.UpdateLimitState = UpdateLimitState
    card._hasInternalWidgetState = true
    UpdateLimitState()

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

        for _, widget in ipairs(self.groupWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(enabled)
            end
        end

        -- The Limit slider only follows the master enable when Use Limit is on.
        if enabled then
            UpdateLimitState()
        end
    end

    return card, card:GetNextOffset(), widgets
end

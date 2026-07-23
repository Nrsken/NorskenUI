--[[
# TextFormatCard

* Premade card for a text label's format string, justification and X/Y offset.
* Binds directly to a db table via `dbKeys`.

## Examples

?   page:TextFormatCard({
?       db = db,
?       onChangeCallback = Apply
?   })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin

local tinsert = table.insert

local TEXT_JUSTIFY_OPTIONS = {
    { key = "LEFT",   text = "Left" },
    { key = "CENTER", text = "Center" },
    { key = "RIGHT",  text = "Right" },
}

--- Format editbox, justify dropdown and X/Y offset sliders bound to a db table.
---@param scrollChild Frame
---@param yOffset number
---@param config table
---@return KajiGUICard card
---@return number newYOffset
---@return Frame[] widgets
function InstanceMixin:CreateTextFormatCard(scrollChild, yOffset, config)
    config = config or {}
    local gui = self
    local theme = self.theme

    local title = config.title or "Text Format"
    local db = config.db
    local dbKeys = config.dbKeys or {}
    local onChange = config.onChangeCallback
    local defaults = config.defaults or {}

    local keys = {
        format = dbKeys.format or "textFormat",
        justify = dbKeys.justify or "textJustify",
        xOffset = dbKeys.xOffset or "textXOffset",
        yOffset = dbKeys.yOffset or "textYOffset",
    }

    local defaultValues = {
        format = defaults.format or "%n",
        justify = defaults.justify or "LEFT",
        xOffset = defaults.xOffset or 4,
        yOffset = defaults.yOffset or 0,
    }

    local xRange = config.xRange or { -100, 100 }
    local yRange = config.yRange or { -20, 20 }

    local widgets = {}
    local card = gui:CreateCard(scrollChild, title, yOffset)

    local row1 = gui:CreateRow(card.content, theme.rowHeight)
    local formatInput = gui:CreateEditBox(row1, "Format", {
        value = db[keys.format] or defaultValues.format,
        callback = function(text)
            db[keys.format] = text
            if onChange then onChange() end
        end
    })
    row1:AddWidget(formatInput, 0.5)
    tinsert(widgets, formatInput)

    local justifyDropdown = gui:CreateDropdown(row1, "Align", {
        options = TEXT_JUSTIFY_OPTIONS,
        value = db[keys.justify] or defaultValues.justify,
        callback = function(key)
            db[keys.justify] = key
            if onChange then onChange() end
        end
    })
    row1:AddWidget(justifyDropdown, 0.5)
    tinsert(widgets, justifyDropdown)
    card:AddRow(row1, theme.rowHeight)

    local row2 = gui:CreateRow(card.content, theme.rowHeightLast)
    local xSlider = gui:CreateSlider(row2, "X Offset", {
        min = xRange[1],
        max = xRange[2],
        step = 1,
        value = db[keys.xOffset] or defaultValues.xOffset,
        labelWidth = 50,
        callback = function(val)
            db[keys.xOffset] = val
            if onChange then onChange() end
        end
    })
    row2:AddWidget(xSlider, 0.5)
    tinsert(widgets, xSlider)

    local ySlider = gui:CreateSlider(row2, "Y Offset", {
        min = yRange[1],
        max = yRange[2],
        step = 1,
        value = db[keys.yOffset] or defaultValues.yOffset,
        labelWidth = 50,
        callback = function(val)
            db[keys.yOffset] = val
            if onChange then onChange() end
        end
    })
    row2:AddWidget(ySlider, 0.5)
    tinsert(widgets, ySlider)
    card:AddRow(row2, theme.rowHeightLast, 0)

    card.textWidgets = widgets

    function card:SetEnabled(enabled)
        self:SetAlpha(enabled and 1 or 0.5)
        for _, widget in ipairs(self.textWidgets) do
            if widget.SetEnabled then widget:SetEnabled(enabled) end
        end
    end

    return card, card:GetNextOffset(), widgets
end

--[[
# TextFormatCard

* Premade card for a text label's format string, justification and X/Y offset.
* Binds directly to a db table via `dbKeys`.

## Examples

    page:TextFormatCard({
        db = db,
        onChangeCallback = Apply
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end

lib.premadeCards = lib.premadeCards or {}

local L = lib.L

--- Format editbox, justify dropdown and X/Y offset sliders bound to a db table.
lib.premadeCards.TextFormatCard = {
    title = "Text Format",

    ---@param card KajiGUIFluentCard
    ---@param config table
    ---@param gui KajiGUIInstance
    build = function(card, config, gui)
        local theme = gui.theme
        local db = config.db
        local dbKeys = config.dbKeys or {}
        local defaults = config.defaults or {}
        local onChange = config.onChangeCallback

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

        local function Set(key, value)
            db[key] = value
            if onChange then onChange() end
        end

        local row1 = card:Row(theme.rowHeight)
        row1:EditBox(L["Format"], {
            width = 0.5,
            value = db[keys.format] or defaultValues.format,
            callback = function(text) Set(keys.format, text) end,
        })
        row1:Dropdown(L["Align"], {
            width = 0.5,
            options = {
                { key = "LEFT",   text = L["Left"] },
                { key = "CENTER", text = L["Center"] },
                { key = "RIGHT",  text = L["Right"] },
            },
            value = db[keys.justify] or defaultValues.justify,
            callback = function(key) Set(keys.justify, key) end,
        })

        local row2 = card:Row(theme.rowHeightLast, 0)
        row2:Slider(L["X Offset"], {
            width = 0.5,
            min = xRange[1],
            max = xRange[2],
            step = 1,
            value = db[keys.xOffset] or defaultValues.xOffset,
            labelWidth = 50,
            callback = function(val) Set(keys.xOffset, val) end,
        })
        row2:Slider(L["Y Offset"], {
            width = 0.5,
            min = yRange[1],
            max = yRange[2],
            step = 1,
            value = db[keys.yOffset] or defaultValues.yOffset,
            labelWidth = 50,
            callback = function(val) Set(keys.yOffset, val) end,
        })
    end,
}

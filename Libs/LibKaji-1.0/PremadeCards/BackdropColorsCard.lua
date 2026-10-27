--[[
# BackdropColorsCard

* Premade card for a module's backdrop and border colors against the host's global ones.
* Two rows, each an override toggle beside its picker: "Use Global Backdrop" + backdrop color,
  "Use Global Border" + border color. A picker is live only while its toggle is off.
* The toggles store `false` when the module keeps its own color, so a missing key follows global.
* `showBackdrop = false` / `showBorder = false` drop a row for modules that only draw one of them.
* `enable = { dbKey = 'Enabled', label = 'Enable Backdrop' }` adds an on/off toggle on top that greys
  out everything below it while off, and refreshes the page so other conditions on it follow.

## Examples

    page:BackdropColorsCard({
        db = db,
        backdropKey = 'BackgroundColor',
        onChangeCallback = Apply,
    }, 'backdrop')

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end

lib.premadeCards = lib.premadeCards or {}

local L = lib.L
local ipairs = ipairs

--- Backdrop + border colors with global override toggles, bound to a db table.
lib.premadeCards.BackdropColorsCard = {
    title = "Colors",

    ---@param card KajiGUIFluentCard
    ---@param config table
    ---@param gui KajiGUIInstance
    build = function(card, config, gui)
        local theme = gui.theme
        local db = config.db
        local onChange = config.onChangeCallback

        -- Hosts with a locale table can pass translated widget labels through here.
        local labels = config.labels or {}

        local rows = {}
        if config.showBackdrop ~= false then
            rows[#rows + 1] = {
                overrideKey = config.backdropOverrideKey or "UseGlobalBackdrop",
                colorKey = config.backdropKey or "BackdropColor",
                overrideLabel = labels.useGlobalBackdrop or L["Use Global Backdrop"],
                colorLabel = labels.backdrop or L["Backdrop Color"],
            }
        end
        if config.showBorder ~= false then
            rows[#rows + 1] = {
                overrideKey = config.borderOverrideKey or "UseGlobalBorder",
                colorKey = config.borderKey or "BorderColor",
                overrideLabel = labels.useGlobalBorder or L["Use Global Border"],
                colorLabel = labels.border or L["Border Color"],
            }
        end

        local enable = config.enable
        local toggles, pickers = {}, {}

        -- Settled here: the manager's blanket pass only knows whether the card is on.
        local function RefreshEnabledState()
            local on = not enable or db[enable.dbKey] and true or false
            for _, toggle in ipairs(toggles) do toggle:SetEnabled(on) end
            for _, entry in ipairs(pickers) do
                entry.picker:SetEnabled(on and db[entry.row.overrideKey] == false)
            end
        end

        if enable then
            card:Row(theme.rowHeight):Checkbox(enable.label or L["Enable Backdrop"], {
                width = 1,
                value = db[enable.dbKey],
                callback = function(checked)
                    db[enable.dbKey] = checked
                    if onChange then onChange() end
                    card.page:Refresh()
                    RefreshEnabledState()
                end,
            })
            card:Separator()
        end

        for i, info in ipairs(rows) do
            local isLast = i == #rows
            local row = card:Row(isLast and theme.rowHeightLast or theme.rowHeight, isLast and 0 or nil)

            toggles[#toggles + 1] = row:Checkbox(info.overrideLabel, {
                width = 0.5,
                value = db[info.overrideKey] ~= false,
                callback = function(checked)
                    db[info.overrideKey] = checked
                    if onChange then onChange() end
                    RefreshEnabledState()
                end,
            })

            pickers[#pickers + 1] = {
                row = info,
                picker = row:ColorPicker(info.colorLabel, {
                    width = 0.5,
                    value = db[info.colorKey],
                    callback = function(r, g, b, a)
                        db[info.colorKey] = { r, g, b, a }
                        if onChange then onChange() end
                    end,
                }),
            }
        end

        card:SetEnabledHandler(function(enabled)
            if enabled then RefreshEnabledState() end
        end)

        RefreshEnabledState()
    end,
}

--[[
# FilterCard

* Premade card for picking a named filter out of a registry the host owns, with a live summary of
* what the selection resolves to.
* The card knows nothing about what a "filter" is: the host supplies the list, the summary text and
* (optionally) a jump to wherever filters are managed. That keeps it usable for aura filters, loot
* filters, or anything else that is "pick a named thing, see what it does".
* Changing the selection rebuilds the card in place, so the page never has to be reopened.
* `describe` may return a heading alongside its lines, which titles the summary in place of
* `summaryTitle`, so the title can state what the current selection resolves to.

## Examples

    page:FilterCard({
        db = db,
        dbKey = 'Filter',
        filters = function() return MyAddon.Filters:GetList() end,
        describe = function(name) return { 'HARMFUL', '3 excluded spells' }, 'Matches:' end,
        onManage = function() window.content:ShowPage('filters') end,
        onChangeCallback = Apply,
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local safecall = lib.safecall

lib.premadeCards = lib.premadeCards or {}

local ipairs = ipairs
local type = type
local tinsert = table.insert

-- Key used for the "no filter" entry. Empty string rather than nil so the dropdown can hold it.
local NONE_KEY = ""

---Resolves a list that may be given as a table or a provider function.
---@param list table|fun(): table
---@return table
local function ResolveList(list)
    if type(list) == "function" then
        return select(2, safecall(list)) or {}
    end
    return list or {}
end

--- Named-filter picker bound to a db key, with a summary of the current selection.
lib.premadeCards.FilterCard = {
    title = "Filter",

    ---@param card KajiGUIFluentCard
    ---@param config table
    ---@param gui KajiGUIInstance
    build = function(card, config, gui)
        local theme = gui.theme
        local db = config.db
        local dbKey = config.dbKey or "Filter"
        local label = config.label or "Filter"
        local title = config.title or "Filter"
        local onChange = config.onChangeCallback
        local searchable = config.searchable ~= false

        local allowNone = config.allowNone ~= false
        local noneText = config.noneText or "None"
        local noneValue = config.noneValue or NONE_KEY
        local describe = config.describe
        local summaryTitle = config.summaryTitle or "Summary"
        -- The summary sizes itself to the description, a host height only sets a floor.
        local summaryHeight = config.summaryHeight or theme.rowHeight
        local emptyText = config.emptyText or "No filters defined yet."

        local onManage = config.onManage
        local manageText = config.manageText or "Manage Filters"

        ---The dropdown option list, with the optional "none" entry pinned to the top.
        local options = {}
        if allowNone then
            tinsert(options, { value = noneValue, text = noneText })
        end
        for _, entry in ipairs(ResolveList(config.filters)) do
            tinsert(options, { value = entry.key, text = entry.text or entry.key })
        end

        -- Only the "none" entry present means the host has no filters to offer yet.
        local isEmpty = #options == (allowNone and 1 or 0)
        local hasSummary = describe ~= nil and not isEmpty

        -- Selection row, sharing space with the manage button when there is one.
        local selectRow = card:Row(theme.rowHeight, (hasSummary or isEmpty) and nil or 0)
        local dropdownWidth = onManage and 0.5 or 1

        selectRow:Dropdown(label, {
            width = dropdownWidth,
            options = options,
            value = db[dbKey] or noneValue,
            searchable = searchable,
            callback = function(key)
                db[dbKey] = (key ~= NONE_KEY) and key or nil
                if onChange then safecall(onChange) end
                -- The summary depends on the selection, so rebuild the card, not the page.
                card:Rebuild()
            end,
        })

        if onManage then
            selectRow:Button(manageText, {
                width = 1 - dropdownWidth,
                height = 24,
                -- Nudged down so the button lines up with the dropdown's control, not its label.
                yOffset = -14,
                callback = function() safecall(onManage) end,
            })
        end

        if isEmpty then
            card:Row(theme.rowHeight, 0):Text(title, {
                width = 1,
                text = emptyText,
                height = theme.rowHeight,
                bgMode = "hide",
            })
            return
        end

        if hasSummary then
            card:Separator()

            -- Resolved live so the summary reflects edits made on the filter's own page. A describe
            -- that returns its own heading titles the block with it, since what a selection resolves
            -- to says more than a static label would.
            local body, heading = select(2, safecall(describe, db[dbKey]))
            card:Row(summaryHeight, 0):Text(heading or summaryTitle, {
                width = 1,
                text = body or "",
                autoHeight = true,
                minHeight = summaryHeight,
                bgMode = "none",
            })
        end
    end,
}

--[[
# FilterCard

* Premade card for picking a named filter out of a registry the host owns, with a live summary of
* what the selection resolves to.
* The card knows nothing about what a "filter" is: the host supplies the list, the summary text and
* (optionally) a jump to wherever filters are managed. That keeps it usable for aura filters, loot
* filters, or anything else that is "pick a named thing, see what it does".
* Changing the selection rebuilds the summary in place, so the page never has to be reopened.
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
local InstanceMixin = lib.InstanceMixin
local safecall = lib.safecall

local ipairs = ipairs
local type = type
local wipe = wipe
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
---@param scrollChild Frame
---@param yOffset number
---@param config table
---@return KajiGUICard card
---@return number newYOffset
---@return Frame[] widgets
function InstanceMixin:CreateFilterCard(scrollChild, yOffset, config)
    config = config or {}
    local gui = self
    local theme = self.theme

    local title = config.title or "Filter"
    local db = config.db
    local dbKey = config.dbKey or "Filter"
    local label = config.label or "Filter"
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

    local card = gui:CreateCard(scrollChild, title, yOffset)
    local widgets = {}

    ---The dropdown option list, with the optional "none" entry pinned to the top.
    local function Options()
        local options = {}
        if allowNone then
            tinsert(options, { value = noneValue, text = noneText })
        end
        for _, entry in ipairs(ResolveList(config.filters)) do
            tinsert(options, { value = entry.key, text = entry.text or entry.key })
        end
        return options
    end

    local BuildContent
    -- The summary depends on the selection, so a change rebuilds the body rather than the page.
    local function RebuildContent()
        if card._onBeforeRebuild then card._onBeforeRebuild(widgets) end
        wipe(widgets)
        card:Reset()
        BuildContent()
        if card._onAfterRebuild then card._onAfterRebuild(widgets) end
    end

    BuildContent = function()
        local selected = db[dbKey] or noneValue
        local options = Options()
        -- Only the "none" entry present means the host has no filters to offer yet.
        local isEmpty = #options == (allowNone and 1 or 0)
        local hasSummary = describe ~= nil and not isEmpty

        -- Selection row, sharing space with the manage button when there is one.
        local selectRow = gui:CreateRow(card.content, theme.rowHeight)
        local dropdownWidth = onManage and 0.5 or 1

        local dropdown = gui:CreateDropdown(selectRow, label, {
            options = options,
            value = selected,
            searchable = searchable,
            callback = function(key)
                db[dbKey] = (key ~= NONE_KEY) and key or nil
                if onChange then safecall(onChange) end
                RebuildContent()
            end,
        })
        selectRow:AddWidget(dropdown, dropdownWidth)
        tinsert(widgets, dropdown)

        if onManage then
            local manage = gui:CreateButton(selectRow, manageText, {
                height = 24,
                callback = function() safecall(onManage) end,
            })
            -- Nudged down so the button lines up with the dropdown's control, not its label.
            selectRow:AddWidget(manage, 1 - dropdownWidth, nil, 0, -14)
            tinsert(widgets, manage)
        end

        card:AddRow(selectRow, theme.rowHeight, (hasSummary or isEmpty) and nil or 0)

        if isEmpty then
            local emptyRow = gui:CreateRow(card.content, theme.rowHeight)
            local text = gui:CreateText(emptyRow, title, { text = emptyText, height = theme.rowHeight, bgMode = "hide" })
            emptyRow:AddWidget(text, 1)
            tinsert(widgets, text)
            card:AddRow(emptyRow, theme.rowHeight, 0)
            return
        end

        if hasSummary then
            card:AddRow(gui:CreateSeparator(card.content), theme.rowHeightSeparator)

            -- Resolved live so the summary reflects edits made on the filter's own page. A describe
            -- that returns its own heading titles the block with it, since what a selection resolves
            -- to says more than a static label would.
            local body, heading = select(2, safecall(describe, db[dbKey]))
            local summaryRow = gui:CreateRow(card.content, summaryHeight)
            local summary = gui:CreateText(summaryRow, heading or summaryTitle, {
                text = body or "",
                autoHeight = true,
                minHeight = summaryHeight,
                bgMode = "none",
            })
            summaryRow:AddWidget(summary, 1)
            tinsert(widgets, summary)
            card:AddRow(summaryRow, summaryHeight, 0)
        end
    end

    BuildContent()

    ---Re-reads the filter list and summary, e.g. after filters were edited elsewhere.
    function card:Refresh()
        RebuildContent()
    end

    function card:SetEnabled(enabled)
        for _, widget in ipairs(widgets) do
            if widget.SetEnabled then widget:SetEnabled(enabled) end
        end
    end

    return card, card:GetNextOffset(), widgets
end

-- Labels this card can surface, for the frameless search harvester (see Search.lua).
lib.premadeCardSearch = lib.premadeCardSearch or {}
function lib.premadeCardSearch.FilterCard(config)
    config = config or {}
    local labels = { config.title or "Filter", config.label or "Filter" }
    if config.onManage then labels[#labels + 1] = config.manageText or "Manage Filters" end
    if config.describe then labels[#labels + 1] = config.summaryTitle or "Summary" end
    return labels
end

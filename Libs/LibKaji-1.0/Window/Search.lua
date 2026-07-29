--[[
# Search

* The sidebar search box (chrome) + a frameless label harvester and query engine.
* Harvest: runs each registered page's fluent `build()` against a collector that mirrors the
* Page/Card/Row surface but creates NO frames — it only records widget label strings. This replaces
* the old dummy-frame pre-index (which was slow because it built real frames). Runs lazily, ~1ms.
* A page descriptor may carry `search = { 'Label', ... }` (extra terms, e.g. for widgets hidden behind
* a structural rebuild) and/or `noHarvest = true` (skip the dry run, rely on `search`).

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs
local type = type
local strfind, strlower = string.find, string.lower

-- Collector: mirrors the fluent surface, records labels, builds nothing --

local WIDGET_METHODS = { "Checkbox", "Slider", "Dropdown", "Button", "ColorPicker", "EditBox", "MultiLineEditBox", "Text", "AnchorPicker" }

-- `ctx` tags each harvested label with the { tabId, itemKey } it was built under, so a widget
-- result can navigate straight to the tab / sidebar item that owns it.
local function MakeRow(labels, ctx)
    local row = {}
    local function record(_, label)
        if type(label) == "string" and label ~= "" then
            labels[#labels + 1] = { text = label, tabId = ctx.tabId, itemKey = ctx.itemKey }
        end
        return row
    end
    for _, m in ipairs(WIDGET_METHODS) do row[m] = record end
    row.Icon = function() return row end
    setmetatable(row, { __index = function() return function() return row end end })
    return row
end

local function MakeCard(labels, ctx)
    local card = {}
    card.Row = function() return MakeRow(labels, ctx) end
    card.Separator = function(self) return self end
    card.Rebuild = function(self, fn)
        if type(fn) == "function" then safecall(fn, self) end
        return self
    end
    setmetatable(card, { __index = function() return function() return card end end })
    return card
end

-- Premade cards build through the same fluent surface as any other card, so running
-- their real builder against the collector records exactly the labels the live page
-- would show — no hand-maintained label lists to drift out of date.
local function RecordPremade(gui, labels, ctx, name, config)
    local card = MakeCard(labels, ctx)
    local def = lib.premadeCards and lib.premadeCards[name]
    if not def then return card end

    config = config or {}
    local title = config.title or def.title
    if type(title) == "string" and title ~= "" then
        labels[#labels + 1] = { text = title, tabId = ctx.tabId, itemKey = ctx.itemKey }
    end

    safecall(def.build, card, config, gui)
    return card
end

local function MakePage(gui, labels, ctx)
    local page = {}
    page.Card = function() return MakeCard(labels, ctx) end
    page.SetEnabled = function(self) return self end
    page.SetCondition = function(self) return self end
    page.Refresh = function(self) return self end
    page.Finish = function() return 0 end

    page.PremadeCard = function(_, name, config) return RecordPremade(gui, labels, ctx, name, config) end
    for name in pairs(lib.premadeCards or {}) do
        page[name] = function(_, config) return RecordPremade(gui, labels, ctx, name, config) end
    end

    setmetatable(page, { __index = function() return function() return page end end })
    return page
end

-- Resolves a sidebar's item list (a table or a `fun():table`), matching ContentArea's SetConfig.
local function ResolveItems(sd)
    local items = sd and sd.items
    if type(items) == "function" then items = select(2, safecall(items)) end
    return items or {}
end

-- Resolves a tabs descriptor's tab list, which a sidebar-outer page derives from the selected item.
local function ResolveTabs(descriptor, itemKey, item)
    local tabs = descriptor.tabs
    if type(tabs) == "function" then tabs = select(2, safecall(tabs, itemKey, item)) end
    return tabs or {}
end

-- Runs `build` against the frameless collector once per tab / sidebar-item combination the real
-- content host would render, so every reachable widget label is harvested and tagged. Mirrors the
-- layout branching in ContentArea (clean / tabs / per-tab sidebar / sidebar-outer).
local function HarvestBuild(gui, descriptor, raw)
    local build = descriptor.build
    if not build then return end
    local mode = descriptor.mode or "clean"
    local sidebar = descriptor.sidebar

    local function run(tabId, itemKey, item)
        local page = MakePage(gui, raw, { tabId = tabId, itemKey = itemKey })
        safecall(build, page, tabId, itemKey, item)
    end

    if mode == "tabs" then
        if sidebar then
            -- Sidebar-outer: the selected item decides which tabs exist.
            for _, item in ipairs(ResolveItems(sidebar)) do
                for _, tab in ipairs(ResolveTabs(descriptor, item.key, item)) do
                    if not tab.disabled then run(tab.id, item.key, item) end
                end
            end
        else
            for _, tab in ipairs(descriptor.tabs or {}) do
                if not tab.disabled then
                    if tab.sidebar then
                        for _, item in ipairs(ResolveItems(tab.sidebar)) do
                            run(tab.id, item.key, item)
                        end
                    else
                        run(tab.id)
                    end
                end
            end
        end
    elseif sidebar then
        -- Clean page with a page-level sidebar: each item drives its own build.
        for _, item in ipairs(ResolveItems(sidebar)) do
            run(nil, item.key, item)
        end
    else
        run()
    end
end

---Returns the cached searchable labels for a page id, harvesting them on first use.
---@param pageId string
---@return table[] entries { text, tabId?, itemKey? }
function InstanceMixin:HarvestSearchLabels(pageId)
    self._searchLabels = self._searchLabels or {}
    local cached = self._searchLabels[pageId]
    if cached then return cached end

    local descriptor = self._pages and self._pages[pageId]
    local raw = {}
    if descriptor then
        if descriptor.search then
            for _, term in ipairs(descriptor.search) do raw[#raw + 1] = { text = term } end
        end
        if not descriptor.noHarvest and descriptor.build then
            HarvestBuild(self, descriptor, raw)
        end
    end

    -- De-duplicate by label text (a `search` term may repeat a harvested label, e.g. a
    -- conditional widget visible in the current state). Keeps the first occurrence's tab context.
    local labels, seen = {}, {}
    for _, entry in ipairs(raw) do
        local key = strlower(entry.text)
        if not seen[key] then
            seen[key] = true; labels[#labels + 1] = entry
        end
    end
    self._searchLabels[pageId] = labels
    return labels
end

---Drops the cached labels for a page (call when its structure may have changed).
---@param pageId? string nil clears all
function InstanceMixin:InvalidateSearchLabels(pageId)
    if not self._searchLabels then return end
    if pageId then self._searchLabels[pageId] = nil else self._searchLabels = {} end
end

-- Query engine --

---Searches a sidebar config (page/section titles) + harvested widget labels.
---@param text string
---@param config table[] the sidebar entry list
---@return table[] results flattened { id, text, sectionText, sectionId?, isPage?/isWidget? }
function InstanceMixin:Search(text, config)
    local results = {}
    if not text or text == "" then return results end
    local q = strlower(text)

    -- Index page/section data and record title matches.
    local pageInfo, pageMatched = {}, {}
    for _, entry in ipairs(config or {}) do
        if entry.type == "item" then
            pageInfo[entry.id] = { id = entry.id, text = entry.text, sectionText = entry.text }
            if strfind(strlower(entry.text or ""), q, 1, true) then pageMatched[entry.id] = true end
        elseif entry.items then
            local sectionHit = strfind(strlower(entry.text or ""), q, 1, true)
            for _, child in ipairs(entry.items) do
                pageInfo[child.id] = { id = child.id, text = child.text, sectionText = entry.text, sectionId = entry.id }
                if sectionHit or strfind(strlower(child.text or ""), q, 1, true) then pageMatched[child.id] = true end
            end
        end
    end

    -- Widget label matches per page.
    local widgetMatches = {}
    for pageId in pairs(pageInfo) do
        for _, entry in ipairs(self:HarvestSearchLabels(pageId)) do
            if strfind(strlower(entry.text), q, 1, true) then
                widgetMatches[pageId] = widgetMatches[pageId] or {}
                widgetMatches[pageId][#widgetMatches[pageId] + 1] = entry
            end
        end
    end

    -- Flatten in config order: page result, then its matching widget results.
    local emitted = {}
    local function emit(pageId)
        if emitted[pageId] then return end
        emitted[pageId] = true
        local info = pageInfo[pageId]
        results[#results + 1] = { id = pageId, text = info.text, sectionText = info.sectionText, sectionId = info.sectionId, isPage = true }
        if widgetMatches[pageId] then
            for _, entry in ipairs(widgetMatches[pageId]) do
                results[#results + 1] = { id = pageId, text = entry.text, sectionText = info.sectionText, sectionId = info.sectionId, isWidget = true, tabId = entry.tabId, itemKey = entry.itemKey }
            end
        end
    end
    for _, entry in ipairs(config or {}) do
        if entry.type == "item" then
            if pageMatched[entry.id] or widgetMatches[entry.id] then emit(entry.id) end
        elseif entry.items then
            for _, child in ipairs(entry.items) do
                if pageMatched[child.id] or widgetMatches[child.id] then emit(child.id) end
            end
        end
    end
    return results
end

local PLACEHOLDER = "Search..."

---Creates a themed search box. Fires opts.onChanged(text) as the user types.
---@param parent Frame
---@param opts table { onChanged: fun(text: string), height?: number }
---@return Frame box
function InstanceMixin:CreateSearchBox(parent, opts)
    opts = opts or {}
    local gui = self
    local theme = self.theme
    local onChanged = opts.onChanged

    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    pixel.SetPixelHeight(box, opts.height or 30)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })

    local inner = CreateFrame("Frame", nil, box)
    pixel.SetPixelPoint(inner, "TOPLEFT", box, "TOPLEFT", 2, -4)
    pixel.SetPixelPoint(inner, "BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 3)

    local clear = CreateFrame("Button", nil, inner)
    pixel.SetPixelSize(clear, 14, 14)
    pixel.SetPixelPoint(clear, "RIGHT", inner, "RIGHT", -2, 0)
    clear:Hide()
    local clearIcon = clear:CreateTexture(nil, "ARTWORK")
    clearIcon:SetAllPoints()
    clearIcon:SetTexture(theme.crossCustomTexture)

    local edit = CreateFrame("EditBox", nil, inner)
    pixel.SetPixelPoint(edit, "TOPLEFT", inner, "TOPLEFT", 6, 0)
    pixel.SetPixelPoint(edit, "BOTTOMRIGHT", clear, "BOTTOMLEFT", -4, 0)
    edit:SetAutoFocus(false)
    gui:ApplyFont(edit, "normal")
    edit:SetText(PLACEHOLDER)

    box.text = ""

    local function ClearIconColor()
        if box.text ~= "" then
            clearIcon:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        else
            clearIcon:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.7)
        end
    end

    local function Restyle()
        box:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], theme.bgMedium[4])
        box:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
        if edit:HasFocus() then
            edit:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        else
            edit:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.6)
        end
        ClearIconColor()
    end
    Restyle()
    gui:OnThemeChanged(Restyle)

    local function Clear()
        box.text = ""
        edit:SetText(PLACEHOLDER)
        edit:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.6)
        clear:Hide()
        if onChanged then safecall(onChanged, "") end
    end
    box.Clear = Clear

    edit:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local t = self:GetText()
        box.text = (t == PLACEHOLDER) and "" or t
        if box.text ~= "" then clear:Show() else clear:Hide() end
        ClearIconColor()
        if onChanged then safecall(onChanged, box.text) end
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if box.text ~= "" then Clear() end
    end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusGained", function(self)
        self:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        if self:GetText() == PLACEHOLDER then self:SetText("") end
    end)
    edit:SetScript("OnEditFocusLost", function(self)
        self:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.6)
        if self:GetText() == "" then self:SetText(PLACEHOLDER) end
    end)

    clear:SetScript("OnEnter", function() clearIcon:SetVertexColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1) end)
    clear:SetScript("OnLeave", ClearIconColor)
    clear:SetScript("OnClick", Clear)

    box.editBox = edit
    return box
end

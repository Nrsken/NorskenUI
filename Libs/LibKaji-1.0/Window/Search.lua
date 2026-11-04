--[[
# Search

* The sidebar search box (chrome) + a frameless label harvester and query engine.
* Harvest: runs each registered page's fluent `build()` against a collector that mirrors the
* Page/Card/Row surface but creates NO frames — it only records widget label strings. This replaces
* the old dummy-frame pre-index (which was slow because it built real frames). Runs lazily, ~1ms.
* A page descriptor may carry `search = { 'Label', ... }` (extra terms, e.g. for widgets hidden behind
* a structural rebuild) and/or `noHarvest = true` (skip the dry run, rely on `search`).
* A `search` entry may also be a table, `{ text = 'Label', tabId? = ..., itemKey? = ... }`, so a
* declared term can name the tab / sidebar item that owns it and the result opens straight there —
* the same context a harvested label carries.

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local Animations = lib.Animations
local safecall = lib.safecall
local pixel = lib.Pixel
local L = lib.L

local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs
local type = type
local strfind, strlower = string.find, string.lower

local FIELD_HEIGHT = 24 -- the EditBox widget's field

-- Collector: mirrors the fluent surface, records labels, builds nothing --

local WIDGET_METHODS = { "Checkbox", "Radio", "Slider", "Dropdown", "Button", "ColorPicker", "EditBox", "MultiLineEditBox", "Text", "AnchorPicker" }

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
    local title = config.title or L[def.title]
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
            -- A term is either a bare label or an entry that already carries its tab/item context.
            for _, term in ipairs(descriptor.search) do
                raw[#raw + 1] = type(term) == "table" and term or { text = term }
            end
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

---A search box's height, its field with a bar inset above and below, for a host that leaves room before making one.
---@param theme table
---@return number
function lib.SearchBoxHeight(theme)
    return FIELD_HEIGHT + theme.barInset * 2
end

---@class KajiGUISearchBox : Frame
---@field text string what's typed, '' while the placeholder shows
---@field editBox EditBox
---@field Clear fun() empties the field and fires onChanged('')

---Creates a themed search box. Fires opts.onChanged(text) as the user types.
---@param parent Frame
---@param opts table { onChanged: fun(text: string), height?: number, fieldTop?: number }
---@return KajiGUISearchBox box
function InstanceMixin:CreateSearchBox(parent, opts)
    opts = opts or {}
    local gui = self
    local theme = self.theme
    local onChanged = opts.onChanged
    local placeholder = L["Search..."]

    -- no ground of its own: the field sits on the panel it tops
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate") --[[@as KajiGUISearchBox]]
    pixel.SetPixelHeight(box, opts.height or lib.SearchBoxHeight(theme))

    -- the EditBox widget's field, so a search reads as the same input as any card's
    local fieldTop = opts.fieldTop or theme.barInset
    local inner = CreateFrame("Frame", nil, box, "BackdropTemplate")
    pixel.SetPixelPoint(inner, "TOPLEFT", box, "TOPLEFT", theme.barInset, -fieldTop)
    pixel.SetPixelPoint(inner, "TOPRIGHT", box, "TOPRIGHT", -theme.barInset, -fieldTop)
    pixel.SetPixelHeight(inner, FIELD_HEIGHT)
    lib.SetBackdrop(inner, gui, { bg = "bgDark", bgAlpha = 0.9, border = "widgetBorder", borderAlpha = 1 })

    local AnimateBorder, SyncBorder = Animations:CreateHoverColorAnimator(inner,
        function(r, g, b, a) inner:SetBackdropBorderColor(r, g, b, a) end,
        theme.widgetBorder, theme.accent, theme.animDuration)

    -- the widget's glow: faint while hovered, full while focused
    local fieldGlow = lib.CreateFrameGlow(inner, gui, lib.FIELD_GLOW_REACH, box)
    local hoverField, hoverClear = false, false
    local edit -- assigned below; the painters only run from its scripts
    local function PaintGlow()
        lib.SetFrameGlow(fieldGlow, gui, edit:HasFocus() and lib.GLOW_ACTIVE or ((hoverField or hoverClear) and lib.GLOW_HOVER or 0))
    end

    local clear = CreateFrame("Button", nil, inner)
    pixel.SetPixelSize(clear, 14, 14)
    pixel.SetPixelPoint(clear, "RIGHT", inner, "RIGHT", -2, 0)
    clear:Hide()
    local clearIcon = clear:CreateTexture(nil, "ARTWORK")
    clearIcon:SetAllPoints()
    clearIcon:SetTexture(theme.crossCustomTexture)

    edit = CreateFrame("EditBox", nil, inner)
    -- the widget's text inset, stopping short of the clear button
    pixel.SetPixelPoint(edit, "TOPLEFT", inner, "TOPLEFT", 6, -4)
    pixel.SetPixelPoint(edit, "BOTTOMRIGHT", inner, "BOTTOMRIGHT", -(2 + 14 + 4), 4)
    edit:SetAutoFocus(false)
    gui:ApplyFont(edit, "normal")
    edit:SetText(placeholder)

    box.text = ""

    local function ClearIconColor()
        if box.text ~= "" then
            clearIcon:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        else
            clearIcon:SetVertexColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 0.7)
        end
    end

    -- typed text is the widget's primary colour; only the placeholder reads muted
    local function PaintText()
        local c = (box.text == "" and not edit:HasFocus()) and theme.textMuted or theme.textPrimary
        edit:SetTextColor(c[1], c[2], c[3], 1)
    end

    ---The border's colour at rest: the accent while focused, the widget's edge otherwise.
    local function PaintBorder()
        local c = edit:HasFocus() and theme.accent or theme.widgetBorder
        SyncBorder(c[1], c[2], c[3], 1)
    end

    -- hover as the widget tracks it, off the text area's enter and leave; the clear button sits on the field,
    -- so the field stays hovered while the cursor is on either
    local function UpdateHover()
        PaintGlow()
        if edit:HasFocus() then return end

        AnimateBorder(hoverField or hoverClear)
    end

    local function Restyle()
        lib.RefreshBackdrop(inner)
        PaintBorder()
        PaintText()
        ClearIconColor()
    end
    Restyle()
    gui:OnThemeChanged(Restyle)

    local function Clear()
        box.text = ""
        if not edit:HasFocus() then
            edit:SetText(placeholder)
        else
            edit:SetText("")
        end
        PaintText()
        clear:Hide()
        if onChanged then safecall(onChanged, "") end
    end
    box.Clear = Clear

    edit:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local t = self:GetText()
        box.text = (t == placeholder) and "" or t
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
        if box.text == "" then
            self:SetText("")
        end
        PaintBorder()
        PaintText()
        PaintGlow()
    end)
    -- the widget drops straight back to its edge colour, hovered or not
    edit:SetScript("OnEditFocusLost", function(self)
        if box.text == "" then
            self:SetText(placeholder)
        end
        PaintBorder()
        PaintText()
        PaintGlow()
    end)
    edit:SetScript("OnEnter", function()
        hoverField = true
        UpdateHover()
    end)
    edit:SetScript("OnLeave", function()
        hoverField = false
        UpdateHover()
    end)

    clear:SetScript("OnEnter", function()
        hoverClear = true
        clearIcon:SetVertexColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
        UpdateHover()
    end)
    clear:SetScript("OnLeave", function()
        hoverClear = false
        ClearIconColor()
        UpdateHover()
    end)
    clear:SetScript("OnClick", Clear)

    box.editBox = edit
    return box
end

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
local InstanceMixin = lib.InstanceMixin
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs
local type = type
local strfind, strlower = string.find, string.lower

-- Collector: mirrors the fluent surface, records labels, builds nothing --

-- A permissive stub so any stray method call / chained widget access during a dry build is harmless.
local function MakeStub()
    local stub = {}
    setmetatable(stub, { __index = function() return function() return stub end end })
    return stub
end

local WIDGET_METHODS = { "Checkbox", "Slider", "Dropdown", "Button", "ColorPicker", "EditBox", "MultiLineEditBox", "Text" }

local function MakeRow(labels)
    local row = {}
    local function record(_, label)
        if type(label) == "string" and label ~= "" then labels[#labels + 1] = label end
        return row
    end
    for _, m in ipairs(WIDGET_METHODS) do row[m] = record end
    row.Icon = function() return row end
    setmetatable(row, { __index = function() return function() return row end end })
    return row
end

local function MakeCard(labels)
    local card = {}
    card.Row = function() return MakeRow(labels) end
    card.Separator = function(self) return self end
    card.Rebuild = function(self, fn)
        if type(fn) == "function" then safecall(fn, self) end
        return self
    end
    setmetatable(card, { __index = function() return function() return card end end })
    return card
end

local function MakePage(labels)
    local page = {}
    page.Card = function() return MakeCard(labels) end
    page.PositionCard = function() return MakeStub() end
    page.SetEnabled = function(self) return self end
    page.SetCondition = function(self) return self end
    page.Refresh = function(self) return self end
    page.Finish = function() return 0 end
    setmetatable(page, { __index = function() return function() return page end end })
    return page
end

---Returns the cached searchable labels for a page id, harvesting them on first use.
---@param pageId string
---@return string[]
function InstanceMixin:HarvestSearchLabels(pageId)
    self._searchLabels = self._searchLabels or {}
    local cached = self._searchLabels[pageId]
    if cached then return cached end

    local descriptor = self._pages and self._pages[pageId]
    local raw = {}
    if descriptor then
        if descriptor.search then
            for _, term in ipairs(descriptor.search) do raw[#raw + 1] = term end
        end
        if not descriptor.noHarvest and descriptor.build then
            safecall(descriptor.build, MakePage(raw))
        end
    end

    -- De-duplicate (a `search` term may repeat a harvested label, e.g. a conditional widget
    -- visible in the current state).
    local labels, seen = {}, {}
    for _, term in ipairs(raw) do
        local key = strlower(term)
        if not seen[key] then
            seen[key] = true; labels[#labels + 1] = term
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
        for _, label in ipairs(self:HarvestSearchLabels(pageId)) do
            if strfind(strlower(label), q, 1, true) then
                widgetMatches[pageId] = widgetMatches[pageId] or {}
                widgetMatches[pageId][#widgetMatches[pageId] + 1] = label
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
            for _, label in ipairs(widgetMatches[pageId]) do
                results[#results + 1] = { id = pageId, text = label, sectionText = info.sectionText, sectionId = info.sectionId, isWidget = true }
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
    pixel.SetPixelPoint(inner, "TOPLEFT", box, "TOPLEFT", 4, -5)
    pixel.SetPixelPoint(inner, "BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 5)

    local clear = CreateFrame("Button", nil, inner)
    pixel.SetPixelSize(clear, 14, 14)
    pixel.SetPixelPoint(clear, "RIGHT", inner, "RIGHT", -2, 0)
    clear:Hide()
    local clearIcon = clear:CreateTexture(nil, "ARTWORK")
    clearIcon:SetAllPoints()
    clearIcon:SetTexture(theme.crossTexture)

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
        box:SetBackdropColor(theme.bgDark[1], theme.bgDark[2], theme.bgDark[3], theme.bgDark[4])
        box:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
        edit:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], edit:HasFocus() and 1 or 0.6)
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
        self:SetTextColor(theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], 1)
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

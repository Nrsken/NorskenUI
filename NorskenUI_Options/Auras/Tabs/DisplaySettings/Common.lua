---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Auras') then return end
local L = NRSKNUI.Libs.AL

local pairs, ipairs = pairs, ipairs
local CopyTable = CopyTable
local type = type
local floor = math.floor

local SUB_INDENT = 12

-- The label is centred in its row and the row keeps the default gap after it, so a heading sits midway between its neighbours.
local HEADING_HEIGHT = 26

local ICON_SOURCES = {
    { value = 'auto',   text = L['Automatic'] },
    { value = 'manual', text = L['Manual'] },
}

local ANCHOR_POINTS = {
    { value = 'TOPLEFT',     text = L['Top Left'] },
    { value = 'TOP',         text = L['Top'] },
    { value = 'TOPRIGHT',    text = L['Top Right'] },
    { value = 'LEFT',        text = L['Left'] },
    { value = 'CENTER',      text = L['Center'] },
    { value = 'RIGHT',       text = L['Right'] },
    { value = 'BOTTOMLEFT',  text = L['Bottom Left'] },
    { value = 'BOTTOM',      text = L['Bottom'] },
    { value = 'BOTTOMRIGHT', text = L['Bottom Right'] },
}

local TEXT_JUSTIFY = {
    { value = 'AUTO',   text = L['Automatic'] },
    { value = 'LEFT',   text = L['Left'] },
    { value = 'CENTER', text = L['Center'] },
    { value = 'RIGHT',  text = L['Right'] },
}

-- Sections and sub-sections start closed, Icon Settings aside; what the user opens or closes holds for the session.
local sectionOpen = { icon = true, bar = true, text = true } -- [section key] = true

local subOpen = {}                              -- [sub-section key] = true

---@class NRSKNUI.CDMDisplayTab
local DisplayTab = {}

NRSKNUI.CDMDisplayTab = DisplayTab

---The centred heading between the Display card's sections.
---@param card table
---@param title string
function DisplayTab.Heading(card, title)
    card:Separator(title, { useLabel = true, centered = true, height = HEADING_HEIGHT })
end

---Write a value at a path, copying nested tables before their first edit so two icons never share one.
---@param target table
---@param path string[]
---@param value any
local function Assign(target, path, value)
    local node = target
    for i = 1, #path - 1 do
        local key = path[i]
        node[key] = CopyTable(node[key] or {})
        node = node[key]
    end
    node[path[#path]] = type(value) == 'table' and CopyTable(value) or value
end

---Two settings read the same, as WA's sameAll: numbers to 2 decimals, colours and other tables key by key, unset as false.
---@param a any
---@param b any
---@return boolean
local function Same(a, b)
    if type(a) == 'table' or type(b) == 'table' then
        if type(a) ~= 'table' or type(b) ~= 'table' then return false end
        for key, value in pairs(a) do
            if not Same(value, b[key]) then return false end
        end
        for key, value in pairs(b) do
            if a[key] == nil and not Same(nil, value) then return false end
        end
        return true
    end
    if type(a) == 'number' and type(b) == 'number' then
        return floor(a * 100 + 0.5) == floor(b * 100 + 0.5)
    end
    return (a or false) == (b or false)
end

---A `mixed(path)` for the widgets of several displays edited together: each one's value at `path` under `read(display)`
---where they disagree, nil where they all match, so the widget shows its empty state and lists them (Kaji SetMixed).
---One display never differs, so it gets a function that always says so.
---A condition gating rows on a setting adds `or mixed(path)`: rows that apply to any of them stay on.
---A setting the widget reads as `x or default` passes that default, so unset compares and lists as what it draws.
---@param displays table[]
---@param read fun(display: table): table? where the path starts: its style, a sub element, the display itself
---@return fun(path: (string|number)[], default: any?): KajiGUIMixedEntry[]?
local function Differ(displays, read)
    if not displays[2] then
        return function() return nil end
    end

    local function At(display, path, default)
        local node = read(display)
        for _, key in ipairs(path) do
            if node == nil then return default end
            node = node[key]
        end
        if node == nil then return default end
        return node
    end

    return function(path, default)
        local base = At(displays[1], path, default)
        local differs = false
        for i = 2, #displays do
            differs = differs or not Same(base, At(displays[i], path, default))
        end
        if not differs then return nil end

        local entries = {}
        for i, display in ipairs(displays) do
            entries[i] = { name = display.name, value = At(display, path, default) }
        end
        return entries
    end
end

---A collapsible WeakAuras-style section, closed until opened. Its rows only exist while it is open.
---@param card table
---@param key string
---@param title string
---@param actions table?
---@return boolean expanded
local function Section(card, key, title, actions)
    local config = {
        key = key,
        collapsed = not sectionOpen[key],
        onToggle = function()
            sectionOpen[key] = not sectionOpen[key] or nil
            card:Rebuild()
        end,
    }
    for name, handler in pairs(actions or {}) do config[name] = handler end
    return card:Section(title, config)
end

DisplayTab.ANCHOR_POINTS = ANCHOR_POINTS
DisplayTab.Assign = Assign
DisplayTab.Differ = Differ
DisplayTab.ICON_SOURCES = ICON_SOURCES
DisplayTab.SUB_INDENT = SUB_INDENT
DisplayTab.Section = Section
DisplayTab.TEXT_JUSTIFY = TEXT_JUSTIFY
DisplayTab.subOpen = subOpen

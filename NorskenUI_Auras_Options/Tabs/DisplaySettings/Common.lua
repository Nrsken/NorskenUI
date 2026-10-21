---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL

local pairs = pairs
local CopyTable = CopyTable
local type = type

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
DisplayTab.ICON_SOURCES = ICON_SOURCES
DisplayTab.SUB_INDENT = SUB_INDENT
DisplayTab.Section = Section
DisplayTab.TEXT_JUSTIFY = TEXT_JUSTIFY
DisplayTab.subOpen = subOpen

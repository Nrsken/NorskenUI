--[[
# TalentTree

* One section of a spec's talents as clickable icons on Blizzard's node grid: `main` (class and spec trees
  side by side), `apex` or `hero` (the hero trees side by side). Every section of a spec shares one scale,
  so a card stacking them under labels keeps one icon size. Read through Blizzard's view loadout so any
  spec can be shown; `lib.TalentTreeSections` lists a spec's sections and `lib.TalentTreeHeight` sizes each row.
* Each talent cycles must have -> must not have -> ignore. The picks live in `config.entries`
  ([C_Traits entryID] = true | false) and every click calls `config.onChange`.

## Example

    for _, section in ipairs(lib.TalentTreeSections(263)) do
        card:Row(lib.TalentTreeHeight(263, width, section)):Widget('TalentTree', nil, { width = 1, specID = 263, section = section, entries = picks, onChange = Apply })
    end

--]]

---@class LibKaji-1.0
local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local safecall = lib.safecall
local pixel = lib.Pixel
local L = lib.L

local CreateFrame = CreateFrame
local Mixin = Mixin
local ipairs, pairs = ipairs, pairs
local min, max, ceil, huge = math.min, math.max, math.ceil, math.huge
local GameTooltip = GameTooltip

local WIDGET_TYPE = "TalentTree"
local UNIT = 600 -- Blizzard's distance between neighbouring talent columns and rows
local CELL = 34 -- pixels per UNIT at full size
local MIN_CELL = 16
local ICON_SHARE = 0.7 -- of a cell, the rest is the gap between icons
local CHOICE_SHARE = 0.75 -- a choice node's two icons, each this share of a full icon, as long as the pair fits its cell
local CHOICE_GAP = 2
local APEX_SHARE = 1.25 -- of a cell: the apex talents are one node's entries, drawn as a row of large icons
local APEX_GAP = 8
local TREE_GAP = 1.5 -- cells between trees side by side
local WHITE = "Interface\\Buttons\\WHITE8X8"
local RED = { 0.95, 0.25, 0.25, 1 }

local function Snap(value) return pixel.ToPixelGrid(value) end
---@param value number
---@return number size the even whole-pixel size at or under value, so a centred icon's edges stay whole
local function Even(value)
    local size = math.floor(value)
    return max(2, size - size % 2)
end

-- Tree data --

local cache = {}
local SECTIONS = { "main", "apex", "hero" }
local entryType = Enum.TraitNodeEntryType
local CAPSTONE = { [entryType.SpendCapstoneCircle or -1] = true, [entryType.SpendCapstoneSquare or -1] = true } -- Blizzard's apex nodes

---@return number
local function MaxLevel()
    return GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 90
end

---The class and spec trees share one Blizzard tree; they're the two sides of its widest gap between columns.
---@param main table
---@return table class, table? spec
local function SplitMain(main)
    local columns, seen = {}, {}
    for _, node in pairs(main.nodes) do
        if not seen[node.x] then
            seen[node.x] = true
            columns[#columns + 1] = node.x
        end
    end
    table.sort(columns)
    local split, widest = nil, UNIT * 2
    for i = 2, #columns do
        local gap = columns[i] - columns[i - 1]
        if gap > widest then split, widest = columns[i], gap end
    end
    if not split then return main end

    local class = { key = "class", entries = {}, nodes = {} }
    local spec = { key = "spec", entries = {}, nodes = {} }
    for nodeID, node in pairs(main.nodes) do (node.x < split and class or spec).nodes[nodeID] = node end
    for _, entry in ipairs(main.entries) do
        local tree = class.nodes[entry.nodeID] and class or spec
        tree.entries[#tree.entries + 1] = entry
    end
    return class, spec
end

---Every talent of a spec, grouped by tree: class, spec, apex, then one per hero subtree, each with its section. Kept for the session.
---@param specID number
---@return table? data { trees = { { key, name?, section, entries = {...}, nodes = {...} } } }
function lib.GetTalentTreeData(specID)
    if cache[specID] then return cache[specID] end

    local configID = Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID
    C_ClassTalents.InitializeViewLoadout(specID, MaxLevel())
    C_ClassTalents.ViewLoadout({})
    local config = C_Traits.GetConfigInfo(configID)
    if not config then return nil end

    local trees, byKey = {}, {}
    local function Tree(key, name)
        local tree = byKey[key]
        if not tree then
            tree = { key = key, name = name, entries = {}, nodes = {} }
            byKey[key] = tree
            trees[#trees + 1] = tree
        end
        return tree
    end
    Tree("main")

    for _, treeID in ipairs(config.treeIDs) do
        for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
            local node = C_Traits.GetNodeInfo(configID, nodeID)
            if node and node.ID ~= 0 and node.isVisible then
                local tree, ox, oy = byKey.main, 0, 0
                if node.subTreeID then
                    local sub = C_Traits.GetSubTreeInfo(configID, node.subTreeID)
                    tree = Tree(node.subTreeID, sub and sub.name)
                    ox, oy = sub and sub.posX or 0, sub and sub.posY or 0
                end
                local spells = {}
                for _, entryID in ipairs(node.entryIDs) do
                    local entry = C_Traits.GetEntryInfo(configID, entryID)
                    if entry and CAPSTONE[entry.type] and tree == byKey.main then tree = Tree("apex") end
                    local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
                    -- overriddenSpellID is the spell a talent replaces; Blizzard's buttons show spellID and overrideIcon.
                    local spellID = definition and definition.spellID
                    if spellID then spells[#spells + 1] = { entryID = entryID, spellID = spellID, icon = definition.overrideIcon } end
                end
                if #spells > 0 then
                    tree.nodes[nodeID] = { x = node.posX - ox, y = node.posY - oy, edges = node.visibleEdges }
                    for index, spell in ipairs(spells) do
                        tree.entries[#tree.entries + 1] = {
                            entryID = spell.entryID, spellID = spell.spellID, icon = spell.icon, nodeID = nodeID,
                            choice = index, choices = #spells,
                        }
                    end
                end
            end
        end
    end

    if #byKey.main.entries == 0 then return nil end -- the view loadout wasn't ready, try again next time
    local class, spec = SplitMain(byKey.main)
    class.section = "main"
    local ordered = { class }
    if spec then
        spec.section = "main"
        ordered[2] = spec
    end
    if byKey.apex then
        byKey.apex.section = "apex"
        ordered[#ordered + 1] = byKey.apex
    end
    for _, tree in ipairs(trees) do
        if tree ~= byKey.main and tree ~= byKey.apex then
            tree.section = "hero"
            ordered[#ordered + 1] = tree
        end
    end
    local data = { trees = ordered }
    cache[specID] = data
    return data
end

---A tree's node bounds in Blizzard units, kept on the tree.
---@param tree table
---@return table bounds { minX, maxX, minY, maxY }
local function Bounds(tree)
    if not tree.bounds then
        local minX, maxX, minY, maxY = huge, -huge, huge, -huge
        for _, node in pairs(tree.nodes) do
            minX, maxX = min(minX, node.x), max(maxX, node.x)
            minY, maxY = min(minY, node.y), max(maxY, node.y)
        end
        tree.bounds = { minX = minX, maxX = maxX, minY = minY, maxY = maxY }
    end
    return tree.bounds
end

---A tree's size in cells, icon extents included.
---@param tree table
---@return number width, number height
local function CellSize(tree)
    local bounds = Bounds(tree)
    if bounds.minX == huge then return 0, 0 end
    return (bounds.maxX - bounds.minX) / UNIT + 1, (bounds.maxY - bounds.minY) / UNIT + 1
end

---A section's trees, side by side.
---@param data table
---@param section string
---@return table[]
local function SectionRow(data, section)
    local row = {}
    for _, tree in ipairs(data.trees) do
        if tree.section == section then row[#row + 1] = tree end
    end
    return row
end

---@param row table[]
---@return number width, number height in cells
local function RowSize(row)
    local width, height = 0, 0
    for i, tree in ipairs(row) do
        local w, h = CellSize(tree)
        width = width + w + (i > 1 and TREE_GAP or 0)
        height = max(height, h)
    end
    return width, height
end

---The cell size that fits the widest section in a width, shared by every section of the spec.
---@param data table
---@param width number
---@return number cell
local function FitCell(data, width)
    local widest = 1
    for _, section in ipairs(SECTIONS) do widest = max(widest, (RowSize(SectionRow(data, section)))) end
    return max(MIN_CELL, math.floor(min(CELL, width / widest)))
end

---The sections a spec has, in order: `main`, then `apex` and `hero` when it has them.
---@param specID number
---@return string[]
function lib.TalentTreeSections(specID)
    local data = lib.GetTalentTreeData(specID)
    local sections = {}
    for _, section in ipairs(SECTIONS) do
        if data and #SectionRow(data, section) > 0 then sections[#sections + 1] = section end
    end
    return sections
end

---Height a section needs at a width, for the row holding it.
---@param specID number
---@param width number
---@param section string
---@return number
function lib.TalentTreeHeight(specID, width, section)
    local data = lib.GetTalentTreeData(specID)
    if not data then return 40 end
    local cell = FitCell(data, width)
    if section == "apex" then return Even(cell * APEX_SHARE) end
    local _, height = RowSize(SectionRow(data, section))
    return ceil(height * cell)
end

-- Widget --

---@class KajiGUITalentTreeMixin : Frame
---@field gui KajiGUIInstance
---@field buttons Button[]
---@field lines Line[]
local TalentTreeMixin = {}

---@param button Button
local function PaintButton(button)
    local state = button.owner._entries and button.owner._entries[button.entryID]
    local theme = button.owner.gui.theme
    local icon = button.icon
    if state == true then
        icon:SetDesaturated(false)
        icon:SetVertexColor(1, 1, 1, 1)
        button:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        button:SetAlpha(1)
    elseif state == false then
        icon:SetDesaturated(false)
        icon:SetVertexColor(1, 0.35, 0.35, 1)
        button:SetBackdropBorderColor(RED[1], RED[2], RED[3], RED[4])
        button:SetAlpha(1)
    else
        icon:SetDesaturated(true)
        icon:SetVertexColor(1, 1, 1, 1)
        button:SetBackdropBorderColor(0, 0, 0, 1)
        button:SetAlpha(0.45)
    end
end

---@param self KajiGUITalentTreeMixin
---@param index number
---@return Button
local function AcquireButton(self, index)
    local button = self.buttons[index]
    if not button then
        button = CreateFrame("Button", nil, self, "BackdropTemplate")
        button.owner = self
        button:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
        local icon = button:CreateTexture(nil, "ARTWORK")
        pixel.SetPixelPoint(icon, "TOPLEFT", button, "TOPLEFT", 1, -1)
        pixel.SetPixelPoint(icon, "BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        lib.SetTextureZoom(icon)
        pixel.SetPixelSnap(icon)
        button.icon = icon
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(clicked, mouse)
            local owner = clicked.owner
            local entries = owner._entries
            if not entries then return end
            local state = entries[clicked.entryID]
            -- Left steps forward, right steps back: ignore -> must have -> must not have -> ignore.
            if mouse == "RightButton" then
                if state == nil then state = false elseif state == false then state = true else state = nil end
            else
                if state == nil then state = true elseif state == true then state = false else state = nil end
            end
            entries[clicked.entryID] = state
            PaintButton(clicked)
            if owner._onChange then safecall(owner._onChange) end
        end)
        button:SetScript("OnEnter", function(hovered)
            GameTooltip:SetOwner(hovered, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(hovered.spellID)
            local theme = hovered.owner.gui.theme
            local state = hovered.owner._entries and hovered.owner._entries[hovered.entryID]
            local text = state == true and L["Must be talented"] or state == false and L["Must not be talented"] or L["Ignored"]
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(text, theme.accent[1], theme.accent[2], theme.accent[3])
            GameTooltip:AddLine(L["Left-click: next state, right-click: previous"], theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3])
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        self.buttons[index] = button
    end
    button:Show()
    return button
end

---@param self KajiGUITalentTreeMixin
---@param index number
---@return Line
local function AcquireLine(self, index)
    local line = self.lines[index]
    if not line then
        line = self:CreateLine(nil, "BACKGROUND")
        pixel.SetPixelSnap(line)
        self.lines[index] = line
    end
    line:SetThickness(pixel.GetMult())
    line:Show()
    return line
end

---@param button Button
---@param entry table
---@param size number
local function PlaceButton(self, button, entry, size, x, y)
    button.entryID, button.spellID = entry.entryID, entry.spellID
    button.icon:SetTexture(entry.icon or C_Spell.GetSpellTexture(entry.spellID))
    button:ClearAllPoints()
    pixel.SetPixelSize(button, size, size)
    pixel.SetPixelPoint(button, "CENTER", self, "TOPLEFT", x, y)
    PaintButton(button)
end

---Lay one tree out from its top-left corner at a cell size: nodes on the cell grid, choice nodes split in two.
---@return number buttonsUsed, number linesUsed
local function LayoutTree(self, tree, left, top, cell, icon, buttonIndex, lineIndex)
    local bounds = Bounds(tree)
    if bounds.minX == huge then return buttonIndex, lineIndex end

    -- Whole-pixel centres with even icon sizes keep every edge on a pixel.
    local centers = {}
    for nodeID, node in pairs(tree.nodes) do
        centers[nodeID] = {
            Snap(left + ((node.x - bounds.minX) / UNIT + 0.5) * cell),
            Snap(top - ((node.y - bounds.minY) / UNIT + 0.5) * cell),
        }
    end
    local muted = self.gui.theme.textSecondary
    local half = pixel.GetMult() / 2 -- a 1px line drawn on a pixel edge would smear across two
    for nodeID, node in pairs(tree.nodes) do
        for _, edge in ipairs(node.edges or {}) do
            local to = centers[edge.targetNode]
            if to then
                lineIndex = lineIndex + 1
                local line = AcquireLine(self, lineIndex)
                local from = centers[nodeID]
                line:SetColorTexture(muted[1], muted[2], muted[3], 0.35)
                line:SetStartPoint("TOPLEFT", self, from[1] + half, from[2] - half)
                line:SetEndPoint("TOPLEFT", self, to[1] + half, to[2] - half)
            end
        end
    end

    local choice = min(Even(icon * CHOICE_SHARE), Even((cell - CHOICE_GAP) / 2))
    for _, entry in ipairs(tree.entries) do
        buttonIndex = buttonIndex + 1
        local center = centers[entry.nodeID]
        if entry.choices > 1 then
            local step = choice + CHOICE_GAP
            local shift = (entry.choice - (entry.choices + 1) / 2) * step
            PlaceButton(self, AcquireButton(self, buttonIndex), entry, choice, center[1] + Snap(shift), center[2])
        else
            PlaceButton(self, AcquireButton(self, buttonIndex), entry, icon, center[1], center[2])
        end
    end
    return buttonIndex, lineIndex
end

---Lay a row of trees out side by side, centred in the width.
local function LayoutRow(self, row, width, top, cell, icon, buttonIndex, lineIndex)
    local rowW = RowSize(row)
    local left = Snap((width - rowW * cell) / 2)
    for _, tree in ipairs(row) do
        buttonIndex, lineIndex = LayoutTree(self, tree, left, top, cell, icon, buttonIndex, lineIndex)
        left = left + Snap((CellSize(tree) + TREE_GAP) * cell)
    end
    return buttonIndex, lineIndex
end

---The apex entries in one centred row, each a large icon.
---@return number buttonsUsed
local function LayoutApex(self, row, width, height, cell, buttonIndex)
    local size = min(Even(cell * APEX_SHARE), Even(height))
    local count = 0
    for _, tree in ipairs(row) do count = count + #tree.entries end
    local step = size + APEX_GAP
    local x = Snap((width - (count * step - APEX_GAP)) / 2 + size / 2)
    for _, tree in ipairs(row) do
        for _, entry in ipairs(tree.entries) do
            buttonIndex = buttonIndex + 1
            PlaceButton(self, AcquireButton(self, buttonIndex), entry, size, x, -size / 2)
            x = x + step
        end
    end
    return buttonIndex
end

function TalentTreeMixin:Layout()
    local width, height = self:GetWidth(), self:GetHeight()
    if not width or width <= 0 or not self._data then return end

    local buttonIndex, lineIndex = 0, 0
    local row = SectionRow(self._data, self._section)
    if self._section == "apex" then
        buttonIndex = LayoutApex(self, row, width, height, FitCell(self._data, width), buttonIndex)
        for i = buttonIndex + 1, #self.buttons do self.buttons[i]:Hide() end
        for i = 1, #self.lines do self.lines[i]:Hide() end
        return
    end
    local _, rowH = RowSize(row)
    -- The row's height was set at build, so a resize since can't grow the icons past it.
    local cell = max(MIN_CELL, min(FitCell(self._data, width), math.floor(height / max(rowH, 1))))
    buttonIndex, lineIndex = LayoutRow(self, row, width, 0, cell, Even(cell * ICON_SHARE), buttonIndex, lineIndex)

    for i = buttonIndex + 1, #self.buttons do self.buttons[i]:Hide() end
    for i = lineIndex + 1, #self.lines do self.lines[i]:Hide() end
end

---@param parent Frame
---@param _ any unused
---@param config table
function TalentTreeMixin:OnAcquire(parent, _, config)
    self:SetParent(parent)
    self:ClearAllPoints()
    self._data = config.specID and lib.GetTalentTreeData(config.specID)
    self._entries = config.entries
    self._onChange = config.onChange
    self._section = config.section or "main"
    self:SetScript("OnSizeChanged", self.Layout)
    self:Show()
    self:Layout()
end

function TalentTreeMixin:OnRelease()
    self:SetScript("OnSizeChanged", nil)
    self._data, self._entries, self._onChange = nil, nil, nil
    for _, button in ipairs(self.buttons) do button:Hide() end
    for _, line in ipairs(self.lines) do line:Hide() end
end

---@class KajiGUITalentTree : KajiGUITalentTreeMixin

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local frame = CreateFrame("Frame", nil, gui._poolHost)
    frame.gui = gui
    frame.buttons = {}
    frame.lines = {}
    return Mixin(frame, TalentTreeMixin)
end)

---@param parent Frame
---@param config table { specID, section?, entries, onChange? }
---@return KajiGUITalentTree
function InstanceMixin:CreateTalentTree(parent, config)
    return self:BuildWidget(WIDGET_TYPE, parent, nil, config)
end

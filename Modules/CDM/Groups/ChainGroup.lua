---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local ipairs, pairs = ipairs, pairs
local CreateFrame = CreateFrame
local tsort = table.sort
local floor = math.floor
local max = math.max
local Mixin = Mixin
local type = type
local _G = _G

local PROBE_TEMPLATE = 'DisableUntrustedLayoutScriptsTemplate' -- anchoring to an aura button needs it

-- Per grow: the group's own anchor, the chain's links, and which axis the spacing pads.
local GROWS = {
    RIGHT      = { point = 'LEFT', first = 'LEFT', link = 'LEFT', to = 'RIGHT', horizontal = true, shift = 0 },
    LEFT       = { point = 'RIGHT', first = 'RIGHT', link = 'RIGHT', to = 'LEFT', horizontal = true, shift = 1 },
    HORIZONTAL = { point = 'CENTER', first = 'LEFT', link = 'LEFT', to = 'RIGHT', horizontal = true, shift = 0.5 },
    DOWN       = { point = 'TOP', first = 'TOP', link = 'TOP', to = 'BOTTOM', horizontal = false, shift = 0 },
    UP         = { point = 'BOTTOM', first = 'BOTTOM', link = 'BOTTOM', to = 'TOP', horizontal = false, shift = 1 },
    VERTICAL   = { point = 'CENTER', first = 'TOP', link = 'TOP', to = 'BOTTOM', horizontal = false, shift = 0.5 },
}
CDM.CHAIN_GROWS = GROWS

---A grow point lined up on the cross axis, as DynamicGroup's GROW_POINTS: TOP + LEFT is TOPLEFT, CENTER + LEFT is LEFT.
---@param point string
---@param grow table
---@param align string?
---@return string
local function Aligned(point, grow, align)
    local onAxis = grow.horizontal and (align == 'TOP' or align == 'BOTTOM') or not grow.horizontal and (align == 'LEFT' or align == 'RIGHT')
    if not onAxis then return point end
    ---@cast align string
    if point == 'CENTER' then return align end
    return grow.horizontal and align .. point or point .. align
end

---Measure a frame from its children's bounds; only the engine sees the result.
---@param frame Frame
local function Measure(frame)
    frame:SetIgnoringChildrenForBounds(false)
    frame:SetSize(0.001, 0.001)
    frame:ResizeToBoundsRect()
    frame:SetIgnoringChildrenForBounds(true)
end
CDM.MeasureBounds = Measure

---@class CDMChainRecord
---@field key string
---@field child CDMIcon
---@field order number
---@field slot Frame
---@field measure Frame
---@field probe Frame
---@field auraProbes table<table, Frame>
---@field width number
---@field height number
---@field loaded boolean? the icon is loaded or previewed
---@field logic boolean? a trigger Lua can see is on show

---@class CDMChainGroup : Frame
---@field isChain true
---@field chain Frame what the engine resizes; its only children are the slots
---@field holder Frame parent of the icons, outside the measured frames
---@field records table<string, CDMChainRecord>
---@field order CDMChainRecord[]
---@field config table
---@field spare Frame[]
local ChainMixin = {}

---@param self CDMChainGroup
---@return number padX, number padY
local function Padding(self)
    local grow = GROWS[self.config.Grow] or GROWS.RIGHT
    local spacing = self.config.Spacing or 1
    if grow.horizontal then return spacing, 0 end
    return 0, spacing
end

---@param self CDMChainGroup
local function Relink(self)
    local order = self.order
    for i = #order, 1, -1 do order[i] = nil end
    for _, record in pairs(self.records) do order[#order + 1] = record end
    tsort(order, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.key < b.key
    end)

    local grow = GROWS[self.config.Grow] or GROWS.RIGHT
    local align = self.config.Align
    local first, link, to = Aligned(grow.first, grow, align), Aligned(grow.link, grow, align), Aligned(grow.to, grow, align)
    local previous
    for _, record in ipairs(order) do
        local slot = record.slot
        slot:ClearAllPoints()
        if previous then
            slot:SetPoint(link, previous, to)
        else
            slot:SetPoint(first, self.chain, first)
        end
        previous = slot
    end
end

---@param self CDMChainGroup
local function PlaceChain(self)
    local grow = GROWS[self.config.Grow] or GROWS.RIGHT
    local padX, padY = Padding(self)
    -- Every slot carries its spacing on its right or bottom, so the anchor takes the leftover gap back.
    local x = grow.horizontal and padX * grow.shift or 0
    local y = grow.horizontal and 0 or -padY * grow.shift
    if grow.shift == 0.5 then
        local total = 0
        for _, record in ipairs(self.order) do
            if record.logic then total = total + (grow.horizontal and record.width + padX or record.height + padY) end
        end
        local half = total / 2
        if grow.horizontal then
            x = floor(x - half + 0.5) + half
        else
            y = -(floor(-y - half + 0.5) + half)
        end
    end
    local point = Aligned(grow.point, grow, self.config.Align)
    self.chain:ClearAllPoints()
    self.chain:SetPoint(point, self, point, x, y)
end

---@param self CDMChainGroup
local function Resize(self)
    local grow = GROWS[self.config.Grow] or GROWS.RIGHT
    local total, cross, count = 0, 0, 0
    for _, record in ipairs(self.order) do
        if record.loaded then
            count = count + 1
            total = total + (grow.horizontal and record.width or record.height)
            cross = max(cross, grow.horizontal and record.height or record.width)
        end
    end
    local spacing = self.config.Spacing or 1
    if count > 1 then total = total + (count - 1) * spacing end
    -- The group's own size is every loaded icon's extent, for its mover and the unit frame anchor; the visible row lives in self.chain.
    if grow.horizontal then
        self:NUISetPixelSize(max(1, total), max(1, cross))
    else
        self:NUISetPixelSize(max(1, cross), max(1, total))
    end
    PlaceChain(self)
end

-- What Lua knows (loaded, a logic trigger on show) is sized here; only an aura's visibility is left to the engine.
---@param record CDMChainRecord
---@param padX number
---@param padY number
local function SizeRecord(record, padX, padY)
    local fits = record.child.fitsText
    if record.logic and not fits then
        record.measure:SetSize(record.width + padX, record.height + padY)
    else
        record.measure:SetSize(0.001, 0.001)
    end
    -- A text sizes itself, so the slot reaches to its far corner plus the spacing.
    local slot = record.slot
    if fits then
        local probe = slot.textProbe or CreateFrame('Frame', nil, slot)
        probe:SetSize(0.001, 0.001)
        probe:ClearAllPoints()
        probe:SetPoint('TOPLEFT', record.child, 'BOTTOMRIGHT', padX, -padY)
        probe:SetShown(record.logic == true)
        slot.textProbe = probe
    elseif slot.textProbe then
        slot.textProbe:Hide()
    end
    if not record.loaded then record.slot:SetSize(0.001, 0.001) end
    record.child.chainPad = { padX, padY }
end

function ChainMixin:SetConfig(config)
    self.config = config or {}
    local padX, padY = Padding(self)
    for _, record in pairs(self.records) do
        SizeRecord(record, padX, padY)
    end
    Relink(self)
    Resize(self)
end

---@param grow string?
---@return string
function ChainMixin:GetResolvedAnchor(grow)
    local info = GROWS[grow or self.config.Grow] or GROWS.RIGHT
    return Aligned(info.point, info, self.config.Align)
end

---Same placement as a DynamicGroup at the top level.
---@param source table
---@param grow string?
function ChainMixin:UpdateGroupPosition(source, grow)
    local position = source.Position
    if not position then return end
    local parent = UIParent
    if source.anchorFrameType == 'SELECTFRAME' and source.ParentFrame then parent = _G[source.ParentFrame] or UIParent end
    self:ClearAllPoints()
    self:NUISetPixelPoint(self:GetResolvedAnchor(grow), parent, position.AnchorTo or 'CENTER', position.XOffset or 0, position.YOffset or 0)
    self:SetFrameStrata(source.Strata or 'MEDIUM')
end

---@param child Frame
---@param key string
---@param order number?
function ChainMixin:AttachChild(child, key, order)
    local record = self.records[key]
    if not record then
        local slot = table.remove(self.spare) or CreateFrame('Frame', nil, self.chain)
        slot:SetCollapsesLayout(true)
        slot:SetIgnoringChildrenForBounds(true)
        slot:Show()

        local measure = slot.measure or CreateFrame('Frame', nil, self.holder)
        measure:SetCollapsesLayout(true)
        measure:ClearAllPoints()
        measure:SetPoint('TOPLEFT', slot, 'TOPLEFT')
        slot.measure = measure

        local probe = slot.probe or CreateFrame('Frame', nil, slot)
        probe:SetSize(0.001, 0.001)
        probe:ClearAllPoints()
        probe:SetPoint('TOPLEFT', measure, 'BOTTOMRIGHT')
        slot.probe = probe

        record = { key = key, slot = slot, measure = measure, probe = probe, auraProbes = slot.auraProbes or {}, width = 1, height = 1 }
        slot.auraProbes = record.auraProbes
        self.records[key] = record
    end
    record.child = child
    record.order = order or 0
    child:SetParent(self.holder)
    child:ClearAllPoints()
    child:SetPoint('TOPLEFT', record.slot, 'TOPLEFT')
    child.chainGroup = self
    local padX, padY = Padding(self)
    SizeRecord(record, padX, padY)
    for _, layer in ipairs(child.layers or {}) do
        for _, slot in pairs(layer.auraSlots or {}) do
            if slot.refs.button then self:WatchAuraButton(key, slot.refs.button) end
        end
    end
    Relink(self)
    Resize(self)
end

---@param childOrKey Frame|string
---@return CDMChainRecord?
function ChainMixin:GetRecord(childOrKey)
    if type(childOrKey) == 'string' then return self.records[childOrKey] end
    for _, record in pairs(self.records) do
        if record.child == childOrKey then return record end
    end
end

---@param childOrKey Frame|string
function ChainMixin:DetachChild(childOrKey)
    local record = self:GetRecord(childOrKey)
    if not record then return end
    self.records[record.key] = nil
    for _, probe in pairs(record.auraProbes) do
        probe:ClearAllPoints()
        probe:Hide()
    end
    for button in pairs(record.auraProbes) do record.auraProbes[button] = nil end
    record.slot:Hide()
    record.slot:ClearAllPoints()
    record.measure:Hide()
    if record.slot.textProbe then
        record.slot.textProbe:ClearAllPoints()
        record.slot.textProbe:Hide()
    end
    self.spare[#self.spare + 1] = record.slot
    local child = record.child
    if child.chainGroup == self then
        child.chainGroup = nil
        child.chainPad = nil
        child:ClearAllPoints() -- still anchored to the slot, its size keeps reading back secret
        child:SetParent(NRSKNUI.HiddenFrame)
    end
    Relink(self)
    Resize(self)
end

---@param childOrKey Frame|string
---@param order number
function ChainMixin:SetChildOrder(childOrKey, order)
    local record = self:GetRecord(childOrKey)
    if not record or record.order == order then return end
    record.order = order
    Relink(self)
end

---@param childOrKey Frame|string
---@param width number
---@param height number
function ChainMixin:NotifyChildResized(childOrKey, width, height)
    local record = self:GetRecord(childOrKey)
    if not record then return end
    record.width, record.height = width, height
    local padX, padY = Padding(self)
    SizeRecord(record, padX, padY)
    Resize(self)
end

---Whether the icon is loaded (its slot exists) and whether a trigger Lua can see is on show.
---@param key string
---@param loaded boolean
---@param logic boolean
function ChainMixin:SetChildVisible(key, loaded, logic)
    local record = self.records[key]
    if not record then return end
    logic = loaded and logic
    if record.loaded == loaded and record.logic == logic then return end
    record.loaded, record.logic = loaded, logic
    -- The slot stays shown at zero size: a hidden one mid-chain makes the engine drop the slots after it from the bounds.
    record.child:SetShown(loaded)
    record.measure:SetShown(logic)
    SizeRecord(record, Padding(self))
    Resize(self)
end

---Measure an aura button too, so the slot opens while the engine shows it.
---@param key string
---@param button table the real aura button, from its initializeFrame
function ChainMixin:WatchAuraButton(key, button)
    local record = self.records[key]
    if not record or record.auraProbes[button] or not NRSKNUI:CanAccessObject(button) then return end
    local probe = CreateFrame('Frame', nil, record.slot, PROBE_TEMPLATE)
    probe:SetSize(0.001, 0.001)
    probe:SetPoint('TOPLEFT', button, 'BOTTOMRIGHT')
    record.auraProbes[button] = probe
end

function ChainMixin:ActivateChild(key) self:SetChildVisible(key, true, true) end

function ChainMixin:DeactivateChild(key) self:SetChildVisible(key, false, false) end

---@return fun(): number?, Frame?
function ChainMixin:IterateActive()
    local i = 0
    return function()
        i = i + 1
        local record = self.order[i]
        if record then return i, record.child end
    end
end

---@param self CDMChainGroup
local function OnUpdate(self)
    for _, record in ipairs(self.order) do
        if record.loaded then Measure(record.slot) end
    end
    Measure(self.chain)
end

---A chained dynamic group for every grow but Grid.
---@return CDMChainGroup
function CDM:CreateChainGroup()
    local group = CreateFrame('Frame', nil, UIParent) --[[@as CDMChainGroup]]
    group.isChain = true
    group.chain = CreateFrame('Frame', nil, group)
    group.chain:SetIgnoringChildrenForBounds(true)
    group.holder = CreateFrame('Frame', nil, group)
    group.holder:SetAllPoints()
    group.records = {}
    group.order = {}
    group.spare = {}
    group.config = {}
    Mixin(group, ChainMixin)
    group:SetScript('OnUpdate', OnUpdate)
    return group
end

---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF
local Anchors = NRSKNUI.Anchors
local L = NRSKNUI.Libs.AL

local UnregisterStateDriver = UnregisterStateDriver
local format, upper = string.format, string.upper
local RegisterStateDriver = RegisterStateDriver
local ipairs, pairs = ipairs, pairs
local CreateFrame = CreateFrame
local concat = table.concat

-- Unit growth within a header, mapped to the attributes SecureGroupHeaders reads.
-- anchor is the corner of the container the header hangs off.
local DIRECTION = {
    DOWN  = { point = 'TOP', x = 0, y = -1, anchor = 'TOPLEFT' },
    UP    = { point = 'BOTTOM', x = 0, y = 1, anchor = 'BOTTOMLEFT' },
    RIGHT = { point = 'LEFT', x = 1, y = 0, anchor = 'TOPLEFT' },
    LEFT  = { point = 'RIGHT', x = -1, y = 0, anchor = 'TOPRIGHT' },
}

local GROUP_ORDER = '1,2,3,4,5,6,7,8'
local CLASS_ORDER = 'DEATHKNIGHT,DEMONHUNTER,DRUID,EVOKER,HUNTER,MAGE,MONK,PALADIN,PRIEST,ROGUE,SHAMAN,WARLOCK,WARRIOR'

---@param key string
---@return string
local function GroupLabel(key)
    return (key:gsub('^%l', upper))
end

---Translate the DB's SortBy into the groupBy/groupingOrder/sortMethod triple.
---@param header Frame
---@param gDB table
local function ApplySorting(header, gDB)
    local sortBy = gDB.SortBy
    local groupBy, groupingOrder, sortMethod

    if sortBy == 'CLASS' then
        groupBy, groupingOrder, sortMethod = 'CLASS', CLASS_ORDER, gDB.SortMethod
    elseif sortBy == 'ROLE' then
        groupBy, groupingOrder, sortMethod = 'ASSIGNEDROLE', concat(gDB.RoleOrder, ',') .. ',NONE', gDB.SortMethod
    elseif sortBy == 'GROUP' then
        groupBy, groupingOrder, sortMethod = 'GROUP', GROUP_ORDER, gDB.SortMethod
    else
        groupingOrder, sortMethod = GROUP_ORDER, sortBy -- INDEX and NAME need no grouping pass
    end

    -- Every SetAttribute re-runs SecureGroupHeader_Update synchronously, so groupBy goes last.
    header:SetAttribute('groupingOrder', groupingOrder)
    header:SetAttribute('sortMethod', sortMethod)
    header:SetAttribute('sortDir', gDB.SortDirection)
    header:SetAttribute('groupBy', groupBy)
end

---Drop every child's anchors.
---@param header Frame
local function ClearChildPoints(header)
    local index = 1
    local child = header:GetAttribute('child' .. index)
    while child do
        child:ClearAllPoints()
        index = index + 1
        child = header:GetAttribute('child' .. index)
    end
end

---The footprint of one full header, used to size the container before any unit exists.
---@param uDB table
---@param dir table
---@param spacing number
---@return number width
---@return number height
local function HeaderExtent(uDB, dir, spacing)
    local count = UF.GROUP_SIZE
    local extent = count * (dir.x ~= 0 and uDB.Width or uDB.Height) + (count - 1) * spacing

    if dir.x ~= 0 then
        return extent, uDB.Height
    end
    return uDB.Width, extent
end

---Re-apply every attribute and re-anchor the header inside its container.
---Touches secure attributes, so callers must be out of combat.
---@param key string config key
function UF:LayoutGroup(key)
    local group = UF.groups[key]
    if not group then return end

    local uDB = UF.GetUnitDB(key)
    local gDB = uDB.Group
    local dir = DIRECTION[gDB.GrowthDirection] or DIRECTION.DOWN
    local spacing = (dir.x ~= 0) and gDB.HorizontalSpacing or gDB.VerticalSpacing

    local container = group.container
    container:NUIApplyPosition(uDB)

    local width, height = HeaderExtent(uDB, dir, spacing)
    container:NUISetPixelSize(width, height)

    local suspended = UF.Preview:SuspendGroup(key)

    local xOffset, yOffset = dir.x * spacing, dir.y * spacing

    for _, header in ipairs(group.headers) do
        -- Anchor before any attribute write: those re-enter SecureGroupHeader_Update and an unanchored header renders its whole column nowhere.
        header:ClearAllPoints()
        if gDB.StartFromCenter then
            -- The header sizes itself to its content, so centring it centres the visible column.
            header:SetPoint('CENTER', container, 'CENTER', 0, 0)
        else
            header:SetPoint(dir.anchor, container, dir.anchor, 0, 0)
        end

        -- Only wipe the children when a positioning attribute is actually changing: that write is
        -- then guaranteed to differ and re-anchor them, so they can never be left floating.
        if header:GetAttribute('point') ~= dir.point
            or header:GetAttribute('xOffset') ~= xOffset
            or header:GetAttribute('yOffset') ~= yOffset then
            ClearChildPoints(header)
        end

        header:SetAttribute('point', dir.point)
        header:SetAttribute('xOffset', xOffset)
        header:SetAttribute('yOffset', yOffset)
        header:SetAttribute('showPlayer', gDB.ShowPlayer)
        header:SetAttribute('oUF-initialConfigFunction', format('self:SetWidth(%d) self:SetHeight(%d)', uDB.Width, uDB.Height))
        ApplySorting(header, gDB)
    end

    if suspended then UF.Preview:ResumeGroup(key) end

    self:ApplyGroupVisibility(key)
end

---Hand the container back to its visibility macro, or take it off screen entirely.
---@param key string config key
function UF:ApplyGroupVisibility(key)
    local group = UF.groups[key]
    if not group then return end

    local container = group.container
    if container.nuiPreviewing then return end -- the preview owns visibility until released

    local uDB = UF.GetUnitDB(key)
    if uDB.Enabled then
        RegisterStateDriver(container, 'visibility', uDB.Group.Visibility)
    else
        UnregisterStateDriver(container, 'visibility')
        container:Hide()
    end
end

---Spawn a group's container and header. Idempotent.
---@param key string config key
---@return UnitFramesGroup?
function UF:SpawnGroup(key)
    if UF.groups[key] then return UF.groups[key] end

    local uDB = UF.GetUnitDB(key)
    if not uDB then return end

    local label = GroupLabel(key)
    local hider = _G[NRSKNUI.oUFPrefix .. '_PetBattleFrameHider'] or UIParent
    local container = CreateFrame('Frame', 'NUF_' .. label, hider, 'SecureHandlerStateTemplate')
    local shown = { showParty = true, showRaid = false, showSolo = true }

    oUF:SetActiveStyle(self.styleName)
    local header = oUF:SpawnHeader('NUF_' .. label .. 'Header', nil,
        'showParty', shown.showParty,
        'showRaid', shown.showRaid,
        'showSolo', shown.showSolo,
        'showPlayer', uDB.Group.ShowPlayer,
        'maxColumns', 1,
        'unitsPerColumn', UF.GROUP_SIZE,
        'oUF-initialConfigFunction',
        format('self:SetWidth(%d) self:SetHeight(%d)', uDB.Width, uDB.Height)
    )

    header.nrsknConfig = key
    header.nuiShown = shown
    header.nuiLabel = L[label]
    header:SetParent(container)
    header:Show()

    local group = { container = container, headers = { header } }
    UF.groups[key] = group

    Anchors:Register(self, 'UnitFrame_' .. key, container, 'unitFrames_' .. key, {
        displayName = L[label],
        db = function() return UF.GetUnitDB(key) end,
        guiContext = 'frame',
    })

    self:LayoutGroup(key)
    return group
end

-- Spawn every group unit. Called from SpawnUnits, so already inside RunWhenSafe.
function UF:SpawnGroups()
    for key in pairs(UF.GroupConfigs) do
        self:SpawnGroup(key)
    end
end

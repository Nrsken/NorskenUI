---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF
local Anchors = NRSKNUI.Anchors

local UnregisterStateDriver = UnregisterStateDriver
local format, upper = string.format, string.upper
local RegisterStateDriver = RegisterStateDriver
local min, max, ceil, floor = math.min, math.max, math.ceil, math.floor
local ipairs, pairs = ipairs, pairs
local CreateFrame = CreateFrame
local tostring = tostring
local concat = table.concat

-- Unit growth within a header, mapped to the attributes SecureGroupHeaders reads.
---@type table<string, UnitFramesGrowth>
local DIRECTION = {
    DOWN  = { point = 'TOP', x = 0, y = -1, anchor = 'TOPLEFT' },
    UP    = { point = 'BOTTOM', x = 0, y = 1, anchor = 'BOTTOMLEFT' },
    RIGHT = { point = 'LEFT', x = 1, y = 0, anchor = 'TOPLEFT' },
    LEFT  = { point = 'RIGHT', x = -1, y = 0, anchor = 'TOPRIGHT' },
}

-- Borrowed when units and subgroups are pointed down the same axis.
---@type table<string, UnitFramesGrowth>
local PERPENDICULAR = { DOWN = DIRECTION.RIGHT, UP = DIRECTION.RIGHT, LEFT = DIRECTION.DOWN, RIGHT = DIRECTION.DOWN }

local GROUP_ORDER = '1,2,3,4,5,6,7,8'
local CLASS_ORDER = 'DEATHKNIGHT,DEMONHUNTER,DRUID,EVOKER,HUNTER,MAGE,MONK,PALADIN,PRIEST,ROGUE,SHAMAN,WARLOCK,WARRIOR'

---@param key string
---@return string
local function GroupLabel(key)
    return (key:gsub('^%l', upper))
end

---Skips no-op writes, every SetAttribute re-runs SecureGroupHeader_Update over the whole header.
---@param header Frame
---@param attr string
---@param value any
local function SetHeaderAttribute(header, attr, value)
    if header:GetAttribute(attr) ~= value then
        header:SetAttribute(attr, value)
    end
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
    SetHeaderAttribute(header, 'groupingOrder', groupingOrder)
    SetHeaderAttribute(header, 'sortMethod', sortMethod)
    SetHeaderAttribute(header, 'sortDir', gDB.SortDirection)
    SetHeaderAttribute(header, 'groupBy', groupBy)
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
---@param dir UnitFramesGrowth
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

---The axis subgroups chain along, forced off the unit axis so the two cross.
---@param gDB table
---@param dir UnitFramesGrowth unit growth
---@return UnitFramesGrowth
local function GroupDirection(gDB, dir)
    local key = DIRECTION[gDB.GroupGrowthDirection] and gDB.GroupGrowthDirection or 'RIGHT'
    local gdir = DIRECTION[key]

    if (gdir.x ~= 0) == (dir.x ~= 0) then
        return PERPENDICULAR[key]
    end
    return gdir
end

---The corner slots are measured from, picked so every growth axis points inward.
---@param dir UnitFramesGrowth
---@param gdir UnitFramesGrowth
---@param wrap UnitFramesGrowth
---@return string
local function GridCorner(dir, gdir, wrap)
    local vertical = (dir.y > 0 or gdir.y > 0 or wrap.y > 0) and 'BOTTOM' or 'TOP'
    local horizontal = (dir.x < 0 or gdir.x < 0 or wrap.x < 0) and 'RIGHT' or 'LEFT'
    return vertical .. horizontal
end

---Attributes every layout shares.
---@param header Frame
---@param uDB table
---@param gDB table
---@param dir UnitFramesGrowth
---@param spacing number
local function ApplyHeaderAttributes(header, uDB, gDB, dir, spacing)
    local xOffset, yOffset = dir.x * spacing, dir.y * spacing

    -- Only wipe children when a positioning attribute changes; that write then re-anchors them.
    if header:GetAttribute('point') ~= dir.point or header:GetAttribute('xOffset') ~= xOffset or header:GetAttribute('yOffset') ~= yOffset then
        ClearChildPoints(header)
    end

    SetHeaderAttribute(header, 'point', dir.point)
    SetHeaderAttribute(header, 'xOffset', xOffset)
    SetHeaderAttribute(header, 'yOffset', yOffset)
    SetHeaderAttribute(header, 'showPlayer', gDB.ShowPlayer)
    SetHeaderAttribute(header, 'oUF-initialConfigFunction', format('self:SetWidth(%d) self:SetHeight(%d)', uDB.Width, uDB.Height))
end

---One header per subgroup on a grid. Party is the one-slot case.
---@param group UnitFramesGroup
---@param uDB table
---@param gDB table
---@param dir UnitFramesGrowth
---@param spacing number
---@param subgroups number[] the subgroup each shown header draws, in slot order
local function LayoutPerGroup(group, uDB, gDB, dir, spacing, subgroups)
    local count = #subgroups
    local headerW, headerH = HeaderExtent(uDB, dir, spacing)
    local gdir = GroupDirection(gDB, dir)
    local wrap = dir -- subgroups wrap back along the unit axis, GroupDirection guarantees it crosses gdir

    local groupSpacing = gDB.GroupSpacing or 0
    local perLine = min(max(gDB.GroupsPerRowColumn or count, 1), count)
    local lines = ceil(count / perLine)
    local slots = min(count, perLine)

    local stepAlong = (gdir.x ~= 0 and headerW or headerH) + groupSpacing
    local stepAcross = (wrap.x ~= 0 and headerW or headerH) + groupSpacing

    local along = slots * stepAlong - groupSpacing
    local across = lines * stepAcross - groupSpacing
    local corner = GridCorner(dir, gdir, wrap)

    local container = group.container
    container:NUISetPixelSize((gdir.x ~= 0) and along or across, (gdir.x ~= 0) and across or along)

    for index, header in ipairs(group.headers) do
        header:SetShown(index <= count)

        if index <= count then
            local slot, line = (index - 1) % perLine, floor((index - 1) / perLine)
            local x = gdir.x * slot * stepAlong + wrap.x * line * stepAcross
            local y = gdir.y * slot * stepAlong + wrap.y * line * stepAcross

            -- Anchor first, attribute writes re-enter the update and an unanchored header draws nowhere.
            header:ClearAllPoints()
            if count == 1 and gDB.StartFromCenter then
                -- The header sizes to its content, so centring it centres the column.
                header:SetPoint('CENTER', container, 'CENTER', 0, 0)
            else
                header:SetPoint(corner, container, corner, x, y)
            end

            ApplyHeaderAttributes(header, uDB, gDB, dir, spacing)
            SetHeaderAttribute(header, 'maxColumns', 1)
            SetHeaderAttribute(header, 'unitsPerColumn', UF.GROUP_SIZE)
            SetHeaderAttribute(header, 'columnSpacing', nil)
            SetHeaderAttribute(header, 'columnAnchorPoint', nil)
            SetHeaderAttribute(header, 'groupFilter', header.nuiGroup and tostring(subgroups[index]) or nil)
            ApplySorting(header, gDB)
        end
    end
end

---Re-apply every attribute and re-anchor a group's headers inside its container.
---Touches secure attributes, so callers must be out of combat.
---@param key string config key
function UF:LayoutGroup(key)
    local group = UF.groups[key]
    if not group then return end

    local uDB = UF.GetUnitDB(key)
    local gDB = uDB.Group
    local dir = DIRECTION[gDB.GrowthDirection] or DIRECTION.DOWN
    local spacing = (dir.x ~= 0) and gDB.HorizontalSpacing or gDB.VerticalSpacing
    local subgroups = UF.ActiveSubgroups(key, gDB)

    group.container:NUIApplyPosition(uDB)
    group.shownGroups = concat(subgroups, ',')

    local suspended = UF.Preview:SuspendGroup(key)

    LayoutPerGroup(group, uDB, gDB, dir, spacing, subgroups)

    if suspended then UF.Preview:ResumeGroup(key) end

    self:ApplyGroupVisibility(key)
end

---Hand the container back to its visibility macro, or take it off screen entirely.
---@param key string config key
function UF:ApplyGroupVisibility(key)
    local group = UF.groups[key]
    if not group then return end

    local container = group.container
    if container.nuiPreviewing then return end -- The preview owns visibility until released

    local uDB = UF.GetUnitDB(key)
    if uDB.Enabled then
        RegisterStateDriver(container, 'visibility', uDB.Group.Visibility)
    else
        UnregisterStateDriver(container, 'visibility')
        container:Hide()
    end
end

---Spawn a group's container and every subgroup header. Idempotent.
---Headers are never destroyed, only shown and hidden, so the count can change in combat.
---@param key string config key
---@return UnitFramesGroup?
function UF:SpawnGroup(key)
    if UF.groups[key] then return UF.groups[key] end

    local uDB = UF.GetUnitDB(key)
    if not uDB then return end

    local label = GroupLabel(key)
    local displayName = UF.UnitLabels[key] or label

    -- oUF 14 dropped its PetBattleFrameHider and gates its own frames through the UI mode system
    -- instead, so the container has to carry the same roleset the headers get from SpawnHeader.
    local container = CreateFrame('Frame', 'NUF_' .. label, UIParent, 'SecureHandlerStateTemplate')
    container:SetRolesets('unitFrames')

    local built = UF.GroupCounts[key] or 1
    local shown = built > 1 and { showParty = false, showRaid = true, showSolo = false } or { showParty = true, showRaid = false, showSolo = true }

    oUF:SetActiveStyle(self.styleName)

    local headers = {}
    for index = 1, built do
        local name = built > 1 and format('NUF_%sHeader%d', label, index) or format('NUF_%sHeader', label)
        local header = oUF:SpawnHeader(name, nil,
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
        header.nuiLabel = displayName
        header.nuiGroup = built > 1 and index or nil -- the subgroup this header filters to
        header:SetParent(container)
        header:Show()

        headers[index] = header
    end

    local group = { container = container, headers = headers }
    UF.groups[key] = group

    -- Build every subgroup's frames now.
    if uDB.Enabled then
        self:PrimeGroupChildren(key)
    end

    Anchors:Register(self, 'UnitFrame_' .. key, container, 'unitFrames_' .. key, {
        displayName = displayName,
        db = function() return UF.GetUnitDB(key) end,
        guiContext = 'frame',
    })

    self:LayoutGroup(key)
    return group
end

---Build the children of a group's visible headers.
---Needs the container visible and the show* attributes intact.
---@param key string config key
function UF:PrimeGroupChildren(key)
    local group = UF.groups[key]
    if not group then return end

    for _, header in ipairs(group.headers) do
        if header:IsVisible() then
            local slots = (header:GetAttribute('unitsPerColumn') or UF.GROUP_SIZE) * (header:GetAttribute('maxColumns') or 1)

            if not header:GetAttribute('child' .. slots) then
                header:SetAttribute('startingIndex', -(slots - 1))
                header:SetAttribute('startingIndex', 1)
            end
        end
    end
end

---Spawn every group unit.
---Called from SpawnUnits, so already inside RunWhenSafe.
function UF:SpawnGroups()
    for key in pairs(UF.GroupConfigs) do
        self:SpawnGroup(key)
    end
end

---Re-derive how many subgroups each auto-counted group shows.
local rosterPending = false
function UF:GROUP_ROSTER_UPDATE()
    -- Blizzard's raid UI may only have loaded by the time the player joins a group.
    self:HideBlizzardRaidFrames()

    if rosterPending then return end
    rosterPending = true

    NRSKNUI:RunWhenSafe(function()
        rosterPending = false

        for key, group in pairs(UF.groups) do
            local gDB = UF.GetUnitDB(key).Group
            if gDB.AutoGroups and concat(UF.ActiveSubgroups(key, gDB), ',') ~= group.shownGroups then
                UF:LayoutGroup(key)
            end
        end
    end)
end

---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_UnitFrames') then return end
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local format = string.format
local tostring = tostring

local function ApplySettings(unit) UF:ApplySettings(unit) end

local GrowthOptions = NRSKNUI.GrowthOptions

local SortByOptions = {
    { value = 'INDEX', text = L['Index'] },
    { value = 'NAME',  text = L['Name'] },
    { value = 'CLASS', text = L['Class'] },
    { value = 'ROLE',  text = L['Role'] },
    { value = 'GROUP', text = L['Group'] },
}

local SortMethodOptions = {
    { value = 'INDEX', text = L['Index'] },
    { value = 'NAME',  text = L['Name'] },
}

local SortDirectionOptions = {
    { value = 'ASC',  text = L['Ascending'] },
    { value = 'DESC', text = L['Descending'] },
}

local RoleOptions = {
    { value = 'TANK',    text = L['Tank'] },
    { value = 'HEALER',  text = L['Healer'] },
    { value = 'DAMAGER', text = L['DPS'] },
}

---@param direction string?
---@return boolean
local function IsHorizontal(direction)
    return direction == 'LEFT' or direction == 'RIGHT'
end

---@param page table
---@param uDB table
---@param unit string
local function BuildGroupSection(page, uDB, unit)
    local gDB = uDB.Group
    local maxGroups = UF.GroupCounts[unit] or 1
    local isRaid = maxGroups > 1
    -- Several choices decide which controls exist at all, so they rebuild the page rather than dim them.
    local function Reload()
        NRSKNUI.GUIFrame.content:ShowPage(UF.GUIPageID(unit), { itemKey = 'group' })
    end

    -- Subgroups must cross the unit growth; a stale parallel value takes the one the layout already uses.
    local unitHorizontal = IsHorizontal(gDB.GrowthDirection)
    if IsHorizontal(gDB.GroupGrowthDirection) == unitHorizontal then
        gDB.GroupGrowthDirection = unitHorizontal and 'DOWN' or 'RIGHT'
    end

    local spacingKey = unitHorizontal and 'HorizontalSpacing' or 'VerticalSpacing'
    local growthConfig = {
        width = 0.5,
        options = GrowthOptions,
        value = gDB.GrowthDirection,
        callback = function(key)
            gDB.GrowthDirection = key
            if IsHorizontal(gDB.GroupGrowthDirection) == IsHorizontal(key) then
                gDB.GroupGrowthDirection = IsHorizontal(key) and 'DOWN' or 'RIGHT'
            end
            ApplySettings(unit)
            Reload() -- the spacing axis and the subgroup choices follow it
        end,
    }
    -- Only the spacing along the growth applies; the gap between subgroups is Group Spacing.
    local spacingConfig = {
        width = 0.5,
        tooltip = L['Gap between one frame and the next.'],
        min = 0,
        max = 50,
        step = 1,
        value = gDB[spacingKey],
        callback = function(val)
            gDB[spacingKey] = val; ApplySettings(unit)
        end,
        callbackOnRelease = true,
    }

    -- Card 1: Layout
    local layoutCard = page:Card(L['Layout'], 'unitOn')
    if not isRaid then
        local growthRow = layoutCard:Row(rowH)
        growthRow:Dropdown(L['Growth Direction'], growthConfig)
        growthRow:Slider(L['Spacing'], spacingConfig)

        -- In a raid the player is always one of the members, so these two only exist for party.
        local partyRow = layoutCard:Row(rowHL, 0)
        partyRow:Checkbox(L['Display Player'], {
            width = 0.5,
            tooltip = L['Include yourself in the party frames.'],
            value = gDB.ShowPlayer,
            callback = function(checked)
                gDB.ShowPlayer = checked; ApplySettings(unit)
            end,
        })
        partyRow:Checkbox(L['Start Near Center'], {
            width = 0.5,
            tooltip = L['Keep the frames centered on the group, growing out from the middle as members join.'],
            value = gDB.StartFromCenter,
            callback = function(checked)
                gDB.StartFromCenter = checked; ApplySettings(unit)
            end,
        })
    else
        local groupOptions = {}
        for _, option in ipairs(GrowthOptions) do
            if IsHorizontal(option.value) ~= unitHorizontal then groupOptions[#groupOptions + 1] = option end
        end

        local directionRow = layoutCard:Row(rowH)
        directionRow:Dropdown(L['Growth Direction'], growthConfig)
        directionRow:Dropdown(L['Group Growth Direction'], {
            width = 0.5,
            tooltip = L['Which way each subgroup sits from the one before it.'],
            options = groupOptions,
            value = gDB.GroupGrowthDirection,
            callback = function(key)
                gDB.GroupGrowthDirection = key; ApplySettings(unit)
            end,
        })

        local spacingRow = layoutCard:Row(rowH)
        spacingRow:Slider(L['Spacing'], spacingConfig)
        spacingRow:Slider(L['Group Spacing'], {
            width = 0.5,
            tooltip = L['Gap between one subgroup and the next.'],
            min = 0,
            max = 50,
            step = 1,
            value = gDB.GroupSpacing,
            callback = function(val)
                gDB.GroupSpacing = val; ApplySettings(unit)
            end,
            callbackOnRelease = true,
        })

        -- Auto is one of the counts rather than a separate toggle beside them.
        local countOptions = { { value = 'auto', text = L['Auto'] } }
        for count = 1, maxGroups do
            countOptions[#countOptions + 1] = { value = count, text = tostring(count) }
        end

        local countRow = layoutCard:Row(rowHL, 0)
        countRow:Slider(L['Groups Per Line'], {
            width = 0.5,
            tooltip = L['How many subgroups fit before the layout wraps onto a new line.'],
            min = 1,
            max = maxGroups,
            step = 1,
            value = gDB.GroupsPerRowColumn,
            callback = function(val)
                gDB.GroupsPerRowColumn = val; ApplySettings(unit)
            end,
            callbackOnRelease = true,
        })
        countRow:Dropdown(L['Groups Shown'], {
            width = 0.5,
            tooltip = L['Auto shows only the subgroups the raid actually fills, updated when you leave combat.'],
            options = countOptions,
            value = gDB.AutoGroups and 'auto' or gDB.NumGroups,
            callback = function(value)
                gDB.AutoGroups = value == 'auto'
                if value ~= 'auto' then gDB.NumGroups = value end
                ApplySettings(unit)
            end,
        })
    end

    -- Card 2: Grouping and order. Index and Name already are an order, so they carry no sort method.
    local sorted = gDB.SortBy ~= 'INDEX' and gDB.SortBy ~= 'NAME'
    local byRole = gDB.SortBy == 'ROLE'
    local column = sorted and 1 / 3 or 0.5

    local sortCard = page:Card(L['Grouping & Sorting'], 'unitOn')
    local sortRow = sortCard:Row(byRole and rowH or rowHL, not byRole and 0 or nil)
    sortRow:Dropdown(L['Group By'], {
        width = column,
        options = SortByOptions,
        value = gDB.SortBy,
        callback = function(key)
            gDB.SortBy = key
            ApplySettings(unit)
            Reload()
        end,
    })
    if sorted then
        sortRow:Dropdown(L['Sort Method'], {
            width = column,
            tooltip = L['How members are ordered inside each group.'],
            options = SortMethodOptions,
            value = gDB.SortMethod,
            callback = function(key)
                gDB.SortMethod = key; ApplySettings(unit)
            end,
        })
    end
    sortRow:Dropdown(L['Sort Direction'], {
        width = column,
        options = SortDirectionOptions,
        value = gDB.SortDirection,
        callback = function(key)
            gDB.SortDirection = key; ApplySettings(unit)
        end,
    })

    if byRole then
        local roleRow = sortCard:Row(rowHL, 0)
        for index = 1, 3 do
            roleRow:Dropdown(format(L['Role Priority %d'], index), {
                width = 1 / 3,
                options = RoleOptions,
                value = gDB.RoleOrder[index],
                callback = function(key)
                    gDB.RoleOrder[index] = key; ApplySettings(unit)
                end,
            })
        end
    end

    -- Card 3: Visibility
    local visCard = page:Card(L['Visibility'], 'unitOn')
    local visRow = visCard:Row(rowHL, 0)
    visRow:EditBox(L['Visibility Macro'], {
        width = 0.75,
        tooltip = L['Macro conditionals deciding when these frames are shown.'],
        value = gDB.Visibility,
        callback = function(val)
            gDB.Visibility = val; ApplySettings(unit)
        end,
    })
    visRow:Button(L['Restore Default'], {
        yOffset = -14,
        height = 24,
        width = 0.25,
        callback = function()
            gDB.Visibility = UF.Defaults.Units[unit].Group.Visibility
            ApplySettings(unit)
            Reload()
        end,
    })
end

UF.GUISections.group = BuildGroupSection

UF.GUIGroupSearch = {
    L['Group'],
    L['Layout'],
    L['Growth Direction'],
    L['Spacing'],
    L['Display Player'],
    L['Start Near Center'],
    L['Group Growth Direction'],
    L['Group Spacing'],
    L['Groups Per Line'],
    L['Groups Shown'],
    L['Grouping & Sorting'],
    L['Group By'],
    L['Sort Method'],
    L['Sort Direction'],
    L['Role Order'],
    L['Visibility'],
    L['Visibility Macro'],
}
